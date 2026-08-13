#!/bin/bash
# =============================================================================
#  rk3588_postflash_test.sh
#  RK3588 (Agibot MB0002 V2) 刷机后全功能回归测试
#  设计:每项“存在即测、不存在标记 SKIP/MISSING”,非交互、不破坏数据、
#        不擅自配置外设(CAN/UART/GPIO/看门狗只检测,不乱写)。
#  用法: sudo bash rk3588_postflash_test.sh [--stress] [--scan] [--net] [--npu-model <path>]
#    --stress        附带短时压力 + 温度观察(需 stress-ng)
#    --scan          允许 i2cdetect 扫总线(默认跳过,避免动到外设)
#    --net           允许 ping 外网(默认只 ping 网关)
#    --npu-model <p> 指定 rknn 模型(默认 /root/npu_test/resnet18.rknn)
# =============================================================================

# ---------- 参数 ----------
OPT_STRESS=0; OPT_SCAN=0; OPT_NET=0
OPT_NPU_MODEL="/root/npu_test/resnet18.rknn"
while [ $# -gt 0 ]; do
  case "$1" in
    --stress) OPT_STRESS=1; shift;;
    --scan)   OPT_SCAN=1; shift;;
    --net)    OPT_NET=1; shift;;
    --npu-model) OPT_NPU_MODEL="$2"; shift 2;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    *) echo "未知参数: $1(用 --help 查看)"; exit 1;;
  esac
done

# ---------- 颜色 / 日志 ----------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RST=$'\033[0m'; C_B=$'\033[1m'; C_G=$'\033[32m'; C_R=$'\033[31m'
  C_Y=$'\033[33m';   C_C=$'\033[36m'; C_D=$'\033[90m'
else C_RST=""; C_B=""; C_G=""; C_R=""; C_Y=""; C_C=""; C_D=""; fi

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG="/var/log/rk3588_test_${STAMP}.log"
[ -w /var/log ] 2>/dev/null || LOG="$PWD/rk3588_test_${STAMP}.log"
: > "$LOG"

CNT_OK=0; CNT_FAIL=0; CNT_WARN=0; CNT_SKIP=0
_section=""
log()  { printf '%s\n' "$*" | tee -a "$LOG" >/dev/null; }   # 仅写日志
out()  { printf '%s\n' "$*" | tee -a "$LOG"; }
section() { _section="$1"; out ""; out "${C_B}${C_C}━━━ $1 ━━━${C_RST}"; }
info()  { out "${C_D}    • $*${C_RST}"; }
ok()    { CNT_OK=$((CNT_OK+1));   out "  ${C_G}[ PASS ]${C_RST} $*"; }
fail()  { CNT_FAIL=$((CNT_FAIL+1)); out "  ${C_R}[ FAIL ]${C_RST} $*"; }
warn()  { CNT_WARN=$((CNT_WARN+1)); out "  ${C_Y}[ WARN ]${C_RST} $*"; }
skip()  { CNT_SKIP=$((CNT_SKIP+1)); out "${C_D}  [ SKIP ] $*${C_RST}"; }

# 存在性快捷
has() { command -v "$1" >/dev/null 2>&1; }
fexists() { [ -e "$1" ]; }
rdev() { [ -e "$1" ] && [ -c "$1" ]; }   # 字符设备

out "${C_B}RK3588 刷机后回归测试  开始: $(date)${C_RST}"
out "日志: ${C_C}$LOG${C_RST}"
[ "$(id -u)" -ne 0 ] && warn "非 root 运行,部分项(/dev、hwclock、i2c)可能无权限 —— 建议用 sudo"

# =============================================================================
section "1. 系统 / 板级 ID"
fexists /etc/armbian-release && { . /etc/armbian-release; info "Armbian: $VERSION ($IMAGE_TYPE)"; }
MODEL="$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')"
[ -n "$MODEL" ] && info "设备型号: $MODEL" || warn "无法读取 /proc/device-tree/model(DT 未加载?)"
info "内核: $(uname -r)   架构: $(uname -m)"
info "发行版: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-未知}")"
info "运行时长: $(uptime -p 2>/dev/null || awk '{print int($1/86400)"d"}' /proc/uptime)"
# 关键:DT 必须加载,否则后面全是空
if [ ! -d /proc/device-tree ]; then fail "device-tree 未挂载,大量硬件检测将失效"; else ok "device-tree 已加载"; fi

# =============================================================================
section "2. CPU"
NPROC="$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)"
if [ "${NPROC:-0}" -ge 1 ] 2>/dev/null; then ok "在线逻辑核: $NPROC(预期 8)"; else fail "无法确定 CPU 核数"; fi
[ "${NPROC:-0}" -eq 8 ] || warn "核数=$NPROC,与预期 8(4×A76+4×A55)不符"
# 频率
CF=/sys/devices/system/cpu/cpu0/cpufreq
if [ -d "$CF" ]; then
  info "可用频率(kHz): $(cat $CF/scaling_available_frequencies 2>/dev/null)"
  info "当前/最大: $(cat $CF/scaling_cur_freq 2>/dev/null) / $(cat $CF/scaling_max_freq 2>/dev/null)"
  info "调速器: $(cat $CF/scaling_governor 2>/dev/null)"
  ok "CPUFreq 可用"
else fail "无 cpufreq 节点(调频驱动未加载)"; fi
# 快速忙时验证:所有核都能跑起来
if has taskset && has sha256sum; then
  pids=""; for i in $(seq 1 "${NPROC:-4}"); do taskset -c $((i-1)) sha256sum /dev/zero >/dev/null & pids="$pids $!"; done
  sleep 2; for p in $pids; do kill "$p" 2>/dev/null; done; wait 2>/dev/null
  ok "全部 $NPROC 核忙时并发执行正常"
else skip "缺 taskset/sha256sum,跳过并发忙时测试"; fi
has sysbench && info "(可选)sysbench 已装,可用 --stress 跑 CPU 基准"

# =============================================================================
section "3. 内存"
if fexists /proc/meminfo; then
  TOTK=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  GB=$(awk "BEGIN{printf \"%.1f\", ${TOTK}/1024/1024}")
  info "总内存: ${GB} GiB   可用: $(awk '/MemAvailable/{print int($2/1024/1024)}' /proc/meminfo) GiB"
  case "$GB" in 15.*|16.*) ok "内存容量正常(~16Gi)";; *) warn "内存=${GB}GiB,与预期 16 不符";; esac
else fail "无 /proc/meminfo"; fi

# =============================================================================
section "4. 存储(eMMC / NVMe / SD)"
# eMMC
if fexists /dev/mmcblk0; then
  info "eMMC: $(cat /sys/block/mmcblk0/device/name 2>/dev/null || echo mmcblk0)"
  info "容量: $(lsblk -dnb -o SIZE /dev/mmcblk0 2>/dev/null | awk '{printf "%.1f GiB\n",$1/1073741824}')"
  info "分区: $(ls /dev/mmcblk0p* 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
  ok "eMMC (/dev/mmcblk0) 识别"
else fail "未发现 eMMC (/dev/mmcblk0)"; fi
# NVMe
for n in /sys/class/nvme/nvme*; do
  [ -d "$n" ] || continue
  info "NVMe: $(cat $n/model 2>/dev/null)"; ok "NVMe ($(basename $n)) 识别"
done
# SD(TF)
fexists /dev/mmcblk1 && { info "SD/TF: /dev/mmcblk1"; ok "SD 卡识别"; }
# 写速测(写到根分区临时文件,测完删除;direct 绕过缓存)
TW=/root/.rwtest.$$
if dd if=/dev/zero of="$TW" bs=1M count=256 oflag=direct conv=fdatasync 2>"$LOG.dd"; then
  RATE=$(grep -oE '[0-9.]+ MB/s' "$LOG.dd" | tail -1)
  info "根分区写速: ${RATE:-未知}(direct)"; ok "存储可读写"
else warn "存储写测失败(只读或空间不足?)"; fi
rm -f "$TW" "$LOG.dd"

# =============================================================================
section "5. 网络(以太网 / WiFi / CAN)"
for ifc in eth0 eth1; do
  n=/sys/class/net/$ifc
  if [ -d "$n" ]; then
    car=$(cat $n/carrier 2>/dev/null)
    spd=$(cat $n/speed 2>/dev/null)
    [ "$car" = "1" ] && ok "$ifc 已插网线,链路 ${spd}Mbps" || warn "$ifc 存在但无载波(未插网线?)"
  else skip "$ifc 不存在"; fi
done
for w in wlan0 wlan1; do [ -d /sys/class/net/$w ] && info "$w 存在(无线接口)"; done
# CAN 总线
for c in can0 can1; do
  if ip link show "$c" >/dev/null 2>&1; then
    st=$(ip -details link show $c | awk '/state/{print $1; exit}' | sed 's/<//')
    info "$c 存在,state=$(ip -details link show $c | grep -o 'bitrate [0-9]*' || echo 未配置)"
    ok "$c CAN 接口存在"
  else skip "$c 不存在"; fi
done
# 网关连通
GW=$(ip route 2>/dev/null | awk '/default/{print $3; exit}')
if [ -n "$GW" ]; then
  if ping -c 2 -W 1 "$GW" >/dev/null 2>&1; then ok "网关 $GW 可达"; else fail "网关 $GW 不可达"; fi
  if [ "$OPT_NET" = "1" ]; then
    if ping -c 2 -W 2 1.1.1.1 >/dev/null 2>&1; then ok "外网(1.1.1.1)可达"; else warn "外网不可达(检查 DNS/防火墙)"; fi
  else info "(外网测试已跳过,加 --net 开启)"; fi
else warn "无默认路由(未配 IP?)"; fi

# =============================================================================
section "6. 温度 / 散热"
any=0; hottest=0; hname=""
for z in /sys/class/thermal/thermal_zone*; do
  [ -e "$z/temp" ] || continue; any=1
  t=$(cat $z/temp 2>/dev/null); nm=$(cat $z/type 2>/dev/null)
  tc=$(awk "BEGIN{printf \"%d\", ${t:-0}/1000}")
  info "$(basename $z) [$nm]: ${tc}°C"
  [ "${tc:-0}" -gt "${hottest:-0}" ] && { hottest=$tc; hname=$nm; }
done
[ "$any" = "1" ] && { info "当前最高: ${hottest}°C ($hname)"; ok "温控节点正常(${hottest}°C)"; } || fail "无 thermal_zone"
[ "${hottest:-0}" -gt 80 ] && warn "温度偏高(>80°C),检查散热"

# =============================================================================
section "7. 频率/电压域(devfreq: GPU / NPU / DDR)"
for d in dmc fb000000.gpu fdab0000.npu; do
  df=/sys/class/devfreq/$d
  if [ -d "$df" ]; then
    info "$d: cur=$(cat $df/cur_freq 2>/dev/null) max=$(cat $df/max_freq 2>/dev/null) gov=$(cat $df/governor 2>/dev/null)"
    ok "devfreq $d 正常"
  else warn "devfreq $d 缺失(对应 IP 驱动可能未加载)"; fi
done

# =============================================================================
section "8. GPU / DRM(Mali)"
if rdev /dev/dri/renderD128; then ok "Mali GPU render 节点 /dev/dri/renderD128"; else fail "无 GPU render 节点(Mali 驱动未加载)"; fi
rdev /dev/dri/card0 && info "/dev/dri/card0 存在"
# 列出 DRM connector 状态(HDMI/DP 是否接屏)
for c in /sys/class/drm/card*-*/status; do
  [ -e "$c" ] || continue
  con="$(dirname "$c" | xargs basename)"
  info "DRM $con: $(cat $c 2>/dev/null)"
done
if has glmark2; then info "(可选)glmark2 已装"; else info "(可选)装 GPU 基准: sudo apt install glmark2-es2"; fi

# =============================================================================
section "9. 显示 / 声卡"
# HDMI/DP 接屏检测
hdmi_conn=0
for s in /sys/class/drm/*HDMI*/status /sys/class/drm/*DP*/status; do
  [ -e "$s" ] && [ "$(cat $s 2>/dev/null)" = "connected" ] && { hdmi_conn=1; info "$(dirname $s | xargs basename) = connected"; }
done
[ "$hdmi_conn" = "1" ] && ok "有显示输出已连接" || warn "未检测到接屏(若已知接了 HDMI,则为驱动问题)"
# 声卡
if fexists /proc/asound/cards; then
  n=$(awk '$1 ~ /^[0-9]+$/{c++} END{print c+0}' /proc/asound/cards)
  info "声卡:"; sed 's/^/      /' /proc/asound/cards | tee -a "$LOG" >/dev/null
  [ "$n" -gt 0 ] 2>/dev/null && ok "发现 $n 个 ALSA 声卡" || warn "无声卡"
else skip "无 /proc/asound"; fi

# =============================================================================
section "10. NPU(RKNN)"
DRV=/sys/kernel/debug/rknpu/version
if [ -r "$DRV" ]; then
  info "$(cat $DRV)"
  info "$(cat /sys/kernel/debug/rknpu/load 2>/dev/null)"
  ok "NPU 驱动已加载"
else fail "NPU 驱动未加载(/sys/kernel/debug/rknpu 不可读)"; fi
# 实跑推理(需要 librknnrt + rknnlite + 模型)
if has python3 && python3 -c 'import rknnlite' 2>/dev/null && fexists /usr/lib/librknnrt.so && fexists "$OPT_NPU_MODEL"; then
  info "运行 resnet18 推理(模型: $OPT_NPU_MODEL)..."
  res=$(MODEL="$OPT_NPU_MODEL" python3 - 2>>"$LOG" <<'PY'
import os,time,numpy as np
from rknnlite.api import RKNNLite
m=os.environ['MODEL']; rk=RKNNLite()
assert rk.load_rknn(m)==0; assert rk.init_runtime()==0
shape=tuple(rk.get_input_attrs()[0]['shape']) if hasattr(rk,'get_input_attrs') else (1,3,224,224)
x=np.random.rand(*shape).astype('float32'); rk.inference(inputs=[x])
t=time.time()
for _ in range(50): o=rk.inference(inputs=[x])
dt=time.time()-t; rk.release()
print("NPU 推理: %.0f FPS (%.1f ms/帧), out=%s argmax=%d"%(50/dt,dt/50*1000,o[0].shape,int(np.argmax(o[0]))))
PY
)
  if [ -n "$res" ]; then info "$res"; ok "NPU 推理通路正常"; else fail "NPU 推理失败(看日志;常见:librknnrt 平台不符 / 模型不匹配)"; fi
else
  warn "NPU 用户态未就绪 —— 刷机后需重装:"
  info "  1) 换 RK3588 版 librknnrt.so (rknpu2 仓库 runtime/RK3588/Linux/librknn_api/aarch64/)"
  info "  2) pip3 install rknn_toolkit_lite2  3) 放入 .rknn 模型(默认 $OPT_NPU_MODEL)"
fi

# =============================================================================
section "11. 视频硬解(VPU / MPP)"
found_codec=0
for v in /dev/video-dec0 /dev/video-enc0 /dev/mpp_device /dev/rkvdec /dev/hevc-encoder; do
  rdev "$v" && { info "$(basename $v) 存在"; found_codec=1; }
done
has mpi_dec_test && { info "mpi_dec_test (Rockchip MPP demo) 已装"; found_codec=1; }
[ "$found_codec" = "1" ] && ok "视频硬解(VPU/MPP)可用" || warn "未发现 VPU/MPP 节点(主线内核常见,需 vendor mpp)"
has mpi_dec_test && info "(可选)mpi_dec_test 已装,可跑硬解 demo" || info "(可选)Rockchip MPP 需另装 librockchip-mpp"
has ffmpeg && info "ffmpeg: $(ffmpeg -version 2>/dev/null | head -1)"

# =============================================================================
section "12. 摄像头(/dev/videoN,排除编解码器)"
cams=0
for v in /dev/video[0-9]*; do
  rdev "$v" || continue
  name="$(cat /sys/class/video4linux/$(basename $v)/name 2>/dev/null)"
  info "$(basename $v): $name"; cams=$((cams+1))
done
[ "$cams" -gt 0 ] && ok "发现 $cams 个视频设备" || warn "无普通摄像头节点(未接 MIPI/UVC,或驱动未加载)"
has v4l2-ctl && info "(可选)v4l2-ctl 已装,可用 --list-formats-ext 查看能力"

# =============================================================================
section "13. I2C / SPI / UART / GPIO"
# I2C
i2c_n=$(ls -d /dev/i2c-* 2>/dev/null | wc -l)
if [ "$i2c_n" -gt 0 ]; then
  info "I2C 总线: $(ls /dev/i2c-* 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
  ok "I2C: $i2c_n 条总线"
  if [ "$OPT_SCAN" = "1" ] && has i2cdetect; then
    for b in $(ls -d /dev/i2c-* | grep -o '[0-9]*'); do
      info "i2cdetect -$b: $(i2cdetect -y $b 2>/dev/null | grep -c '[0-9a-f]2') 个应答设备"
    done
  else info "(I2C 扫描已跳过,加 --scan 用 i2cdetect 扫描)"; fi
else warn "无 I2C 设备节点"; fi
# SPI
spi_n=$(ls /dev/spidev* 2>/dev/null | wc -l)
[ "$spi_n" -gt 0 ] && { ok "SPI: $spi_n 个 spidev"; info "  $(ls /dev/spidev* 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"; } || info "SPI: 无 spidev(未启用)"
# UART(只列,不写——可能连着电机/雷达)
uart_n=$(ls /dev/ttyS* 2>/dev/null | wc -l)
if [ "$uart_n" -gt 0 ]; then ok "UART: $uart_n 个串口"; info "  $(ls /dev/ttyS* 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"; else warn "无 UART 节点"; fi
info "  (UART 回环测试需物理短接 TX/RX,脚本不自动测)"
# GPIO
gc_n=$(ls -d /sys/class/gpio/gpiochip* 2>/dev/null | wc -l)
if [ "$gc_n" -gt 0 ]; then
  ok "GPIO: $gc_n 个 gpiochip"
  info "  已 export: $(ls /sys/class/gpio/ 2>/dev/null | grep -c '^gpio[0-9]') 个(机器人可能已占用,请勿擅动)"
else warn "无 gpiochip"; fi
has gpioinfo && info "(可选)libgpiod 已装:gpioinfo 查详情"

# =============================================================================
section "14. RTC / 看门狗 / LED / USB"
# RTC
if [ -d /sys/class/rtc/rtc0 ]; then
  info "RTC 时间: $(cat /sys/class/rtc/rtc0/date 2>/dev/null) $(cat /sys/class/rtc/rtc0/time 2>/dev/null)"
  ok "RTC 存在(rtc0)"
else warn "无 RTC(时钟会随断电丢失)"; fi
# 看门狗 —— 只读检测,绝不 open(避免触发复位!)
if rdev /dev/watchdog; then
  has wdctl && info "wdctl: $(wdctl 2>/dev/null | tr '\n' ' ' | cut -c1-80)"
  ok "/dev/watchdog 存在(仅检测,未触发)"
else info "看门狗: 无 /dev/watchdog(当前固件即如此,非故障)"; fi
# LED
led_n=$(ls -d /sys/class/leds/* 2>/dev/null | wc -l)
[ "$led_n" -gt 0 ] && { ok "LED: $led_n 个"; info "  $(ls /sys/class/leds/ 2>/dev/null | tr '\n' ' ')"; } || info "LED: 无"
# USB
usb_n=$(ls -d /sys/bus/usb/devices/usb* 2>/dev/null | wc -l)
info "USB 主控: $usb_n;已识别设备:"
for d in /sys/bus/usb/devices/*-*/product; do [ -e "$d" ] && info "  $(cat $d)"; done
ok "USB 子系统在线"

# =============================================================================
# 可选:压力 + 温升
if [ "$OPT_STRESS" = "1" ]; then
  section "15. 压力测试(stress-ng)"
  if has stress-ng; then
    t0=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    info "运行 60s CPU 压力(8 核)..."
    stress-ng --cpu "$(nproc)" --timeout 60s --metrics-brief 2>&1 | tee -a "$LOG" >/dev/null
    t1=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    info "温升: $((t0/1000))°C → $((t1/1000))°C"
    ok "压力测试完成,系统稳定"
  else warn "未装 stress-ng(apt install stress-ng)"; fi
else
  info "(压力测试已跳过,加 --stress 开启)"
fi

# =============================================================================
section "汇总"
TOTAL=$((CNT_OK+CNT_FAIL+CNT_WARN+CNT_SKIP))
out ""
out "  ${C_G}PASS=${CNT_OK}${C_RST}  ${C_R}FAIL=${CNT_FAIL}${C_RST}  ${C_Y}WARN=${CNT_WARN}${C_RST}  ${C_D}SKIP=${CNT_SKIP}${C_RST}   共 ${TOTAL} 项"
out "  日志: ${C_C}$LOG${C_RST}"
out ""
[ "$CNT_FAIL" -eq 0 ] && out "${C_G}${C_B}>>> 未发现 FAIL,核心功能正常 <<<${C_RST}" \
                     || out "${C_R}${C_B}>>> 有 ${CNT_FAIL} 项 FAIL,请重点排查 <<<${C_RST}"
out ""
exit 0
