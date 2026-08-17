#!/usr/bin/env bash
# check-session-fixes.sh — 定向核验本轮修复是否全部进入镜像。
# 用法: wsl bash /mnt/e/AIPorject/101/agibot-armbian/scripts/check-session-fixes.sh <img>
set -uo pipefail
IMG="${1:-/home/cennac/docker-agibot-armbian/armbian-build/output/images/Armbian-unofficial_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
dd if="$IMG" of="$T/v.ext4" bs=1M skip=16 status=none

pass=0; fail=0
ck() { if [ "$2" = OK ]; then echo "  [OK]   $1"; pass=$((pass+1)); else echo "  [FAIL] $1 ($2)"; fail=$((fail+1)); fi; }

KVER=6.1.115-vendor-rk35xx
DTB_IN="/boot/dtb-$KVER/rockchip/rk3588-agibot-mb0002-v2.dtb"

# --- DTB 三处 ---
debugfs -R "dump $DTB_IN $T/dtb" "$T/v.ext4" >/dev/null 2>&1
[ "$(fdtget "$T/dtb" /usbdrd3_0/usb@fc000000 dr_mode 2>/dev/null)" = "peripheral" ] \
  && ck "DTB dr_mode=peripheral(Type-C adb)" OK || ck "DTB dr_mode=peripheral" FAIL
[ "$(fdtget "$T/dtb" /i2c@fec80000/husb311@4e status 2>/dev/null)" = "disabled" ] \
  && ck "DTB husb311=disabled(断依赖环)" OK || ck "DTB husb311=disabled" FAIL
[ "$(fdtget "$T/dtb" /watchdog@feaf0000 status 2>/dev/null)" = "okay" ] \
  && ck "DTB watchdog=okay" OK || ck "DTB watchdog=okay" FAIL
BA="$(fdtget "$T/dtb" /chosen bootargs 2>/dev/null)"
echo "$BA" | grep -q "console=tty1" && echo "$BA" | grep -q "root=/dev/mmcblk0p1" \
  && ck "DTB bootargs(HDMI tty1 + 通用 root)" OK || ck "DTB bootargs" "FAIL: $BA"

# --- 服务 ---
svc_check() { # name wants_dir expect(1/0)
  local n="$1" w="$2" e="$3"
  debugfs -R "stat /etc/systemd/system/$n.service" "$T/v.ext4" >/dev/null 2>&1 || { ck "服务 $n 安装" FAIL; return; }
  local c; c=$(debugfs -R "ls -l /etc/systemd/system/$w.target.wants" "$T/v.ext4" 2>/dev/null | grep -c "$n")
  [ "$c" = "$e" ] && ck "服务 $n 安装+enable链接数=$e" OK || ck "服务 $n enable 链接数" "got=$c want=$e"
}
svc_check agibot-usb-hub-reset  sysinit    1
svc_check agibot-usb-port-power multi-user 1
svc_check agibot-usb-adb       multi-user 0   # 默认关闭(opt-in)
svc_check agibot-bt-attach     multi-user 1
c=$(debugfs -R "ls -l /etc/systemd/system/getty.target.wants" "$T/v.ext4" 2>/dev/null | grep -c "getty@tty1")
[ "$c" = 1 ] && ck "getty@tty1 enable(HDMI 登录)" OK || ck "getty@tty1" "got=$c"

# --- adbd 静态二进制 ---
SZ=$(debugfs -R "stat /usr/local/bin/adbd" "$T/v.ext4" 2>/dev/null | grep -oE "Size: [0-9]+" | head -1 | grep -oE "[0-9]+")
[ "$SZ" = "2106864" ] && ck "adbd 静态二进制(2106864B)" OK || ck "adbd 大小" "got=$SZ"

# --- VPU 用户态库(librga 真名无版本后缀;mpp/vpu 为 .so.0 + customize 重建 .so.1 链) ---
LIBS=$(debugfs -R "ls -l /usr/local/lib" "$T/v.ext4" 2>/dev/null)
for l in librockchip_mpp.so.0 librockchip_vpu.so.0 librga.so; do
  echo "$LIBS" | grep -q "$l" && ck "VPU 库 $l" OK || ck "VPU 库 $l" FAIL
done

# --- ACM8625P:内核补丁 obj-y 内建 → 查 modules.builtin ---
MB=$(mktemp)
debugfs -R "dump /lib/modules/$KVER/modules.builtin $MB" "$T/v.ext4" >/dev/null 2>&1
grep -q "sound/soc/codecs/acm8625p" "$MB" 2>/dev/null \
  && ck "ACM8625P 驱动内建(modules.builtin)" OK || ck "ACM8625P 内建" "not-in-builtin"
ML=$(debugfs -R "cat /etc/modules-load.d/acm8625p.conf" "$T/v.ext4" 2>/dev/null | tr -d "\n")
[ "$ML" = "acm8625p" ] && ck "modules-load acm8625p.conf" OK || ck "acm8625p.conf" "got=$ML"

# --- BT ldisc 服务依赖的 firmware(nvram) ---
FW=$(debugfs -R "ls /lib/firmware/brcm" "$T/v.ext4" 2>/dev/null | grep -c "BCM4362A2")
[ "$FW" -ge 1 ] && ck "BT firmware BCM4362A2" OK || ck "BT firmware" FAIL

echo
echo ">>> 结果: $pass 通过, $fail 失败"
[ "$fail" = 0 ]
