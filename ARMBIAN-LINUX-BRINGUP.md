# AGIBOT MB0002 V2 — Armbian Linux 层 bring-up + 刷机方法

本文档记录 Armbian 路线从「U-Boot 能启动」到「Linux 完整进入系统」之间踩出的
三个 Linux 层问题及最终修复，并固化「下次打包一次成功」所需的关键改动。U-Boot
层的专用 defconfig/DTS 见 [[UBOOT-BRINGUP.md]]。

## 结论(2026-08-14 实测，2026-08-16 补充 HDMI 控制台)

Armbian 镜像已能完整启动进入系统。Linux 层一共有 **三个坑**，其中两个是「vendor
内核 vs armbian 框架默认值不匹配」导致的，一个是我自己在调试中绕的弯路。

| # | 现象 | 根因 | 修复 |
|---|---|---|---|
| 1 | `Starting kernel ...` 后无任何串口输出 | vendor 内核控制台是 **ttyFIQ0**(fiq-debugger 独占 uart2)，不是 armbian 默认的 ttyS2 | DTB 保持 `fiq-debugger=okay` + `uart2=disabled`(原始状态本来就对) |
| 2 | initramfs 卡 `PARTUUID=614e0000-0000 does not exist` | DTB `chosen.bootargs` 里 `root=` 是**假的 GPT 分区 GUID** `614e0000-0000` | `root=` 改成真实 UUID 或通用设备名 |
| 3 | 调试中误改 fiq/uart2 | 我曾把 fiq→disabled、uart2→okay(完全搞反) | 恢复原始:fiq=okay、uart2=disabled |

**关键机制(vendor U-Boot 的 cmdline 优先级)**：这块板用的 Radxa vendor U-Boot
(`CONFIG_ANDROID_BOOTLOADER=y`)在 `booti` 时**优先用 DTB 的 `chosen.bootargs`，
忽略 U-Boot env 里的 `bootargs`**。证据:手动 `setenv bootargs "root=/dev/mmcblk0p1
console=ttyFIQ0,1500000"` 后,`/proc/cmdline` 仍是 DTB chosen 的
`root=PARTUUID=... console=ttyFIQ0(无波特率) earlycon=...`。

因此:
- `boot.cmd`/`boot.scr` 里的 `console=ttyS2` **不影响实际控制台**(被 DTB chosen 覆盖)。
- 2026-08-14 的启动修复里，必须修改的是 DTB `chosen.bootargs` 的 `root=`。
- HDMI 登录控制台还必须在同一处保留串口并追加 `console=tty1`。
- fiq=okay、uart2=disabled、console=ttyFIQ0、earlycon 在原始 DTB 里**本来就是对的**,不用改。

## HDMI login shell(2026-08-16 实测)

默认 DTB 已加入 `console=ttyFIQ0 console=tty1`，同时保留串口恢复能力和 HDMI
framebuffer 控制台。板级配置设 `DEFAULT_CONSOLE="both"`，`customize-image.sh`
显式启用 `getty@tty1.service`。DTB 将 `display-subsystem` 的
`hdmi0_phy_pll` 接到节点级 HDMI PHY clock provider；VOP 不再用 1188MHz CRU
时钟近似分频。`customize-image.sh` 会删除旧镜像遗留的 connector `video=` 参数，
DRM 按 EDID 自动选择首选模式。控制台字体保持系统默认 8x16。

默认启动实测结果:
- `/sys/class/drm/card0-HDMI-A-1/status` 为 `connected`；
- EDID 自动选择 `2560x1440p60`，`dclk` 与 `real_dclk` 均为精确的 `241500 kHz`；
- `vtcon1` 为已绑定的 `frame buffer device`；
- `getty@tty1.service` 为 `active`；
- `/dev/vcs1` 最后显示 `Armbian ... Jammy tty1` 和 `agibot login:`；
- COM7 的 `ttyFIQ0` 登录保持正常。

当前默认 DTB SHA-256(HDMI 控制台 + PCIe/WiFi + 蓝牙 + 看门狗 + bt-sound 禁用版,2026-08-17):
`cc80bd012a68123709d02d724cf3a2c32bd8317557ea76a82d649a9d935cdd66`。
旧稳定 v3 已在板端备份为 `/root/dtb.v3-pre-hdmi-console`,
PCIe 修复前版本备份为 `/root/dtb.pre-pcie-fix`,
看门狗启用前版本备份为 `/root/dtb.v-pre-watchdog`,
bt-sound 禁用前版本备份为 `/root/dtb.v-pre-btsound-off`。

GPIO137 是 I2S1 `SDO0`。旧 DTB 同时把它错误写成 HDMI `enable-gpios`，导致 HDMI
mode set 把 I2S 引脚强切回 GPIO。默认 DTB 已删除该错误属性，并恢复
`/i2s@fe480000` 和 `/acm8625p-sound`。`kernel/rk35xx-vendor-6.1/` 还加入 GPL-2.0
ACM8625P codec 驱动补丁；外置模块已通过 6.1.115 编译和 vermagic 校验，板端
加载与实际放音测试需在明确授权后执行。

## WiFi:AP6275P(BCM43752 PCIe)(2026-08-16 实测)

- **板载无线不是 RTL8821CU(USB)**，而是 **AP6275P = BCM43752 PCIe 模组**
  (DTB `wireless-wlan` 节点 `wifi_chip_type="ap6275p"`)，挂在
  **pcie2x1l0(fe170000)**，PCI ID `14e4:449d`。fe190000 总线上还枚举出
  VIA VL805 USB3 控制器(`1106:3483`)和两颗 GSW PCIe switch。
- **根因**:原厂 5.10 的 pcie 节点是两段式 `reg-names="pcie-apb","pcie-dbi"`,
  6.1 vendor 驱动要求三段式——缺第三段 **`config`** reg → 三条控制器全部
  `Missing *config* reg space → Failed to initialize host`,PCIe 总线零设备,
  WiFi/USB3 扩展全部枚举不到。
- **修复**(照 vendor 6.1 SDK `rk3588.dtsi`/`rk3588s.dtsi` 标准写法,脚本
  `_fix_pcie.py`):每条 pcie 的 `reg` 补第三段 config 空间、`reg-names` 加
  `"config"`:
  - fe150000(pcie3x4)→ `<0x0 0xf0000000 0x0 0x100000>`
  - fe170000(pcie2x1l0)→ `<0x0 0xf2000000 0x0 0x100000>`
  - fe190000(pcie2x1l2)→ `<0x0 0xf4000000 0x0 0x100000>`
  - (disabled 的 fe160000/fe180000 一并补上,以后启用免再踩)
- **驱动与固件**:内核自带 `bcmdhd.ko`(CONFIG_BCMDHD_PCIE),PCIe 枚举后自动
  加载;固件在 `overlay/lib/firmware/ap6275p/`(`fw_bcm43752a2_pcie_ag.bin`、
  `nvram_AP6275P.txt`、CLM blob、BT `BCM4362A2.hcd`),驱动按芯片类型表自动选名。
  模块加载完是 Android 式「WiFi OFF」待机(WL_REG_ON LOW),
  `ip link set wlan0 up` 触发 dhd_open 上电、加载固件(wl0 18.35.387),
  之后 `iw dev wlan0 scan` 正常出 SSID(实测扫到 8 个)。
- **已知噪声**:dmesg 仍有三条 `dw-pcie ... invalid resource → -22`
  (通用 DW 驱动先 probe 失败),随后 `rk-pcie` 层接管成功——SDK 双驱动层
  怪癖,功能无碍。
- **回归**:默认启动 postflash-test **PASS=25/FAIL=0**;wlan0 扫描 ✅;
  HDMI tty1、声卡无回退。
- **M.2 / pcie3x4(fe150000)状态(2026-08-16,空槽)**:host 侧全部就绪
  (host bridge ranges/iATU/PHY 初始化成功,并实际执行链路训练);LTSSM 停在
  Detect(0x0/0x1)后 `PCIe Link Fail` 是**空槽的正常表现**,非驱动问题。
  插卡后需**重启一次**才枚举(boot 训练失败时 host 不注册总线,不支持运行中
  热插)。M.2 物理走线(fe150000 直连还是 GSW switch 下游口)与槽位供电/PERST
  需实插终验:插卡重启后 `ls /sys/bus/pci/devices/` 出现新设备即确认。

## 蓝牙:AP6275P BT(uart6 + BCM4362A2)(2026-08-16 实测)

- **硬件**:AP6275P 的 BT 部分是 **BCM4362A2 走 uart6(ttyS6)**,HCI UART,ROM
  波特率 115200;`BT_REG_ON=GPIO1_A6`(38,高=上电)、`BT_WAKE=GPIO3_B2`(106)。
  芯片完全健康:裸 tty 发 Reset/Read_Local_Version/Read_BD_ADDR 全 ACK,
  BD 地址 `B0:02:47:43:EA:3B`,subver 0x1111 精确对应 `brcm/BCM4362A2.hcd`。
- **根因(绕了最久的坑)**:本板 BT 的 **ctsn 没接线**。DW apb UART 一旦
  termios 打开 CRTSCTS,AFCE 生效,TX 被**恒为低的 nCTS 门死**——字节留在
  TX FIFO,`/proc/tty/driver/serial` 表现 tx 涨、rx 恒 0,命令超时。实测
  对照:同一进程 CRTSCTS off → 秒 ACK;ON → 零接收;off → 又 ACK。而内核
  `hci_bcm` serdev(`hci_uart_setup` 会 `serdev_device_set_flow_control(true)`)
  和 bluez `btattach` 都会开 CRTSCTS → **Reset(0x0c03)永远 tx timeout**。
  这解释了此前 serdev(v2/v4/v6)与 btattach 全部失败的统一原因。
- **修复(用户态挂载,vendor hciattach 同款思路)**:
  - **DTB**(`_fix_bt_ldisc.py` 生成,已固化进 overlay 默认 DTB):
    ① uart6 `pinctrl-0` 加 `uart6m1-rtsn`(0x1ac),**不加 bluetooth 子节点**
    (ttyS6 保持普通串口);② vendor `wireless-bluetooth` 节点 **disabled**
    (否则 rfkill-bt 抢 GPIO1_A6 并与 uart6 抢 pinctrl);③ gpio1/gpio3 加
    **gpio-hog** 常拉高 BT_REG_ON/BT_WAKE(开机即上电,不依赖用户态时序)。
  - **挂载服务** `overlay/etc/systemd/system/agibot-bt-attach.service` +
    `overlay/usr/local/sbin/agibot-bt-attach`:python 直接
    `TIOCSETD(N_HCI)` + `HCIUARTSETPROTO(HCI_UART_BCM=7)`,termios 全程
    自控 115200 raw **绝不开 CRTSCTS**。ldisc 路线 `bcm_proto` 无
    `oper_speed` → 内核不切速、不发 0xfc18,patchram 由 btbcm 自动加载
    `brcm/BCM4362A2.hcd`(overlay 已带)。
- **ioctl 语义坑(写挂载脚本必看)**:`HCIUARTSETPROTO` 在内核里用的是
  **arg 原值当协议号**(`hci_uart_set_proto(hu, arg)`),python `fcntl.ioctl`
  要**传裸 int**;传 packed buffer 会把指针值当协议号 → 恒
  `EPROTONOSUPPORTED`。而 `TIOCSETD`/`TIOCMGET` 是指针语义,要用 buffer。
- **实测结果**:开机全自动——服务 5.9s 挂载 → patchram 完成 →
  `hci0: BCM43752A2 UART 37.4MHz Ampak AP6398 [Version: 1012.1017]`,
  `btmgmt info`:`powered ssp br/edr le secure-conn`;LE/经典扫描命令均正常
  执行(附近无可扫设备属环境问题)。bluetoothd(active)可直接用 bluetoothctl。
- **回归**:postflash-test **PASS=25/FAIL=0**;WiFi 扫描、HDMI tty1、网口、
  UART(含 ttyS6)无回退。
- **留痕**:serdev 路线(内核自动 probe,无需服务)已验证不可行于本板硬件
  (ctsn 未接线),除非硬件补线。HCI 工作在 115200(足够 BLE/控制类应用;
  若日后需高吞吐 A2DP,可仿 vendor 用 brcm_patchram_plus 两段式升 1500000)。

## 扬声器:ACM8625P 功放(i2c8@0x15 + i2s@fe480000)(2026-08-16 实测,只到声卡)

- **硬件**:ACM8625P 功放在 **i2c8(feaa0000)@0x15**,I2S 音频经
  `i2s@fe480000`(I2S1,GPIO137=SDO0)。DT 已有 `acm8625p@15`(BSP 提供)与
  `acm8625p-sound`(simple-audio-card,name `rockchip,acm8625p-codec`)。板端此前
  deferred 报 `acm8625p-sound asoc-simple-card: parse error`——codec dai 解析
  不到,根因是**驱动未编译**(内核 sound/soc/codecs 无此 codec)。
- **编译路线(已实证)**:本板内核 CONFIG_MODVERSIONS=y → 外置模块必须与
  内核同源码+同 config+**同编译器**才 CRC 匹配。**原内核编译器
  = `aarch64-linux-gnu-gcc (Debian) 14.2.0-19`**(CONFIG_CC_VERSION_TEXT),
  即 armbian build-container **debian-trixie** 自带的 Debian gcc-14 交叉链。
  源码 = `armbian/linux-rockchip` `rk-6.1-rkr5.1`(HEAD 5280f9b43361,2026-07-15)
  + **必须复刻 armbian family 补丁** `rk35xx-vendor-6.1/{001-hid-sony,
  bluetooth-hci-quirk-v6.1-v6.15}`(第二个恰好改到我们 BT 用的 hci_ldisc.c)。
  WSL 本机 Ubuntu 24.04 的 gcc-13 **不行**,必须用 Debian trixie 的
  gcc-14-aarch64-linux-gnu(**版本串逐字一致 14.2.0-19**)。
- **库内补丁**:`kernel/rk35xx-vendor-6.1/0001-ASoC-add-ACM8625P-amplifier.patch`
  在 `sound/soc/codecs/Makefile` 加 `obj-y += acm8625p.o` + 新增 565 行
  acm8625p.c(Wenhao Yang, acme-semi.com;I2C regmap codec,寄存器 REG_PAGE/
  DEVICE_STATE,DEEP_SLEEP/SLEEP/HIZ/PLAY/MUTE)。**建议做成内建**(obj-y),
  这样下次打包镜像直接编进内核,无需再带 .ko。
- **外置模块复用内核构建**:`kernel/_acm_build.sh`(容器内跑)演示完整链路
  ——应用补丁 → `make olddefconfig`(注意必须重放 arm64 真 config,`make prepare`
  会按当前 config 覆盖)→ `make prepare` → 单目标编 acm8625p.o → 外置
  `M=` 产 .ko。**踩坑**:①在 x86 config 下 `make prepare` 会洗掉 arm64 config
  (CONFIG_CPU_SUP_INTEL=y),导致 `-mrecord-mcount` 编译错;②外置 M= 必须
  `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`(否则 MODPOST 在 x86 上下文
  报 `__x86_return_thunk` undefined)。
- **上板(已远程验证)**:`modprobe acm8625p` → I2C probe 成功
  (`acm8625p 1-0015`),DSP 固件 `acm8625p_dsp_stereo_btl_48khz.bin` 缺失为
  非致命 warn(DSP 参数跳过,codec 照常注册)。`/proc/asound/cards` 出
  `2 [rockchipacm8625]`,`/dev/snd/pcmC2D0p/c/d1p`;ASOC 机器
  `rockchip,acm8625p-codec`,dai1 = `fe480000.i2s → acm8625p-hifi`。
  `acm8625p-sound` 从 deferred 消失。**开机自启**:`/etc/modules-load.d/
  acm8625p.conf`(一行 `acm8625p`)。MODALIAS
  `of:Nacm8625pT(null)Cacme,acm8625p` 与驱动 compatible 匹配。
- **放音**:按约定只到「声卡就绪」,**未执行任何 aplay/播放**。用户到场后用
  `aplay -D hw:2,1 /usr/share/sounds/alsa/Front_Center.wav` 试音(注意
  modules-load.d 确保开机即加载)。DSP 固件(acme-semi 提供)若需装载性能参数,
  后续放 /lib/firmware 即可。

## 看门狗:watchdog@feaf0000(2026-08-17 实测)

- **根因**:vendor DT 里 `watchdog@feaf0000`(snps,dw-wdt)被 `status="disabled"`,
  而内核 `dw_wdt` 驱动本来就已内建——一行 DT 改动即激活,无需任何内核工作。
- **修复**:`fdtput -t s <dtb> /watchdog@feaf0000 status okay`(节点自带
  clocks=tclk/pclk、中断,属性完整)。重启后 `/dev/watchdog`、
  `/dev/watchdog0` 出现。注意 CONFIG_WATCHDOG_SYSFS 未开,
  `/sys/class/watchdog/watchdog0/` 下无 identity/timeout 文件属正常。
- **实测**:open + 写 ping + 普通 close(非 magic 'V')→ watchdog core
  释放时停表,板子不重启;`CONFIG_WATCHDOG_NOWAYOUT` 未开,安全。
  用途:systemd WatchdogSec / 关键进程托管 / 刷机防砖场景。
- **回归**:声卡(含 ACM 自动加载)、hci0、bcmdhd、双网口均无回退。

## deferred 噪声清理与剩余已知项(2026-08-17 实测)

- **bt-sound 已禁用**:该 simple-audio-card 的 codec 端指向 `bt-sco`
  (compatible `delta,dfbmcs320`)假 codec——6.1 vendor 内核没有此驱动,
  parse error 永远不消。此路是 BSP 的 BT-PCM 音频专用通路,而我们的蓝牙
  音频走 HCI(uart6),不经它 → `status="disabled"` 纯去噪,无功能损失。
- **dmc(留)**:DDR 调频 probe 依赖 ATF 侧 SIP DRAM 服务
  (`sip_smc_dram`/`ROCKCHIP_SIP_DRAM_FREQ`),Armbian 的 BL31 未实现 →
  probe 从未执行(无日志、手动 bind rc=1)。**内核侧无 bug 可修**,
  DDR 固定频率运行。保留节点:将来若换带 DRAM SIP 的 ATF 可直接生效。
- **mtd_vendor_storage(留)**:设备**不是 DT 创建的**(DT 无节点,无法
  disable),且 `/proc/mtd` 为空——eMMC 走标准 mmc 驱动不产生 MTD 分区,
  它等的东西永远不来。存 MAC 地址用,有 fallback,无功能影响。
- 清理后 `devices_deferred` 仅剩上两条,均为「留痕的已知项」而非 bug。

## VPU/RGA 用户态库:rockchip-mpp + librga(2026-08-16 实测)

- **背景**:内核侧 VPU 一直就绪(`/dev/mpp_service`),缺的只是用户态库;
  Armbian/Jammy 仓库**没有** rockchip-mpp/librga 包,需自取源码/预编译。
- **两个仓库坑**:①`rockchip-linux/mpp` 默认分支是 **develop**(master 404),
  用 codeload tarball 拉(git clone 在板上会 `expected flush` 抽风);
  ②`rockchip-linux/librga` 仓库已 **404**(官方迁到 `airockchip/librga`),
  且新版不再带根 CMakeLists——库以 `libs/Linux/gcc-aarch64/librga.so`
  预编译交付,直接拷即可。
- **板上构建**:`scripts/build-vpu-userland.sh` 有完整命令。产物已固化进
  `overlay/usr/local/{lib,include,bin}`(真身 .so.0 + 测试工具 + 头文件,
  共 ~15MB;symlink 由 customize-image.sh 重建,Windows git 不保符号链接)。
- **实测(真硬解)**:ffmpeg 造 320x240 H.264 → `mpi_dec_test -t 7`:
  **30 帧 14ms,fps 2123.89,峰值内存 1.03MB**——软解不可能的速度,
  RKDVB/RKVDEC 硬解通路全通。`mpp_info_test` 正常(开头两条
  `client 4/12 driver is not ready` 是独立的 vdpu/vepu 服务不存在,主
  mpp_service 工作正常,无害)。

## 全面驱动审计(2026-08-17,DT 节点 vs 实际绑定全量对照)

逐总线遍历 `/sys/bus/{platform,i2c,spi,usb,pci}` 未绑定设备 + dmesg
err/warn 全扫,结论:**无新的可修驱动 bug,全子系统绑定完整**。

- **PCIe(曾疑似三条全挂,实为 3/3 成功)**:dmesg 早期 3 条
  `dw-pcie ... invalid resource/-22` 是 vendor 驱动首次尝试的残影,随后
  rk-pcie host 模式全部接手(三条都打了 host bridge ranges + iATU unroll)。
  实际拓扑:0002 域 RC→`14e4:449d` **AP6275P WiFi**(dhd 绑定,wlan0 就绪,
  probe exit err=0);0004 域 RC→`1106:3483` **VIA VL832 PCIe-USB3**
  (xhci_hcd 绑定,板上 USB3 Hub/U盘全挂它下面);fe150000(Gen3x4)空槽,
  `PCIe Link Fail, LTSSM 0x0` 属正常(无对端设备)。
- **eth0 `NO-CARRIER`/DOWN**:网口本身健康(能报载波状态=PHY 链路监视
  活着),只是没插对端线;eth1 1000Mbps UP(SSH 走它)。dmesg 里 gmac1
  `rx_delay set to 0xffffffff` 是 `rgmii-rxid`(RX 延迟在 PHY 内)的
  正常表达,非 bug。
- **唯一硬件层异常:板载 hub port4 的 FS 设备(已判死刑)**:一个
  full-speed 设备反复 `descriptor read/64, error -32 (EPIPE)` 被内核放弃。
  2026-08-17 三重验证:①用户确认外设仅 U盘(8-1.4 DataTraveler ✓)+
  键盘(9-1.1 ✓),均正常,失败者非用户外设;②重启后问题跟着设备换总线
  (3-1.4→5-1.4),非控制器侧问题;③手动脉冲 hub 复位脚后仍不出现。
  **结论:板内某 USB 外设硬件故障**(焊死在 fc800000/fc880000 EHCI 侧
  hub 的 port4),远程不可修,到场检查。
- **已补:agibot-usb-hub-reset 服务**(2026-08-17):原厂 5.10 DT 有
  `hubrst-gpio` 节点(`compatible="usbhub_rst"`,usbhub1/2 复位脚=
  GPIO4_D2/D3,sysfs 154/155,mux GPIO/pull-none),其私有驱动开机脉冲
  两根脚——**6.1 内核无此驱动,引脚浮空,hub 上电状态随机**(实测一次
  启动 usb3 侧 hub 整片丢失)。已在用户态复刻:`agibot-usb-hub-reset`
  服务(sysinit 阶段,先于 usb-port-power)脉冲 154/155;板上验证
  status=0,脉冲时 U盘/键盘所在 hub 端口干净断开重枚举。
- **余下 dmesg 噪声逐条定性(cosi)**:fiq_debugger IRQ ENXIO(6.1 无 FIQ,
  console 走 ttyS2 正常)、tsadc 缺 `rockchip,grf`(温度照读,7 个 zone
  33-34℃)、`pin 156 already requested by feb80000.serial`(BT 修复的
  rtsn gpio-hog,有意为之)、drm-logo/cubic-lut/KASLR 无 seed/VOP overlay
  plane/opp info/loader memory(HDMI 显示正常工作下的 cosmetic)、
  rk806 无 sleep/dvs pinctrl、spi2 无 high_speed state、cpuinfo id cell
  ——均无功能影响。
- **绑定面抽查**:i2c 8 个 client 全 BOUND(含 acm8625p 1-0015);SPI 仅
  rk806 且 BOUND;USB 17 接口全 BOUND;声卡 3 张、hci0(BCM4362A2 固件
  已打)、can0/1、watchdog、thermal 全就绪。

## Type-C adb:usb@fc000000 peripheral + 原厂 adbd(2026-08-17 实测)

Type-C 口(接电脑)原镜像是 adb 服务口。6.1 下该口**无任何功能**(电脑
不认识设备),根因与修复:

- **根因一:dwc3 不 probe**。`/usbdrd3_0/usb@fc000000` 在 6.1 下报
  `Fixed dependency cycle(s) with /i2c@fec80000/husb311@4e` —— DWC3 的
  device link 经 usb-c-connector 与 `fed80000.phy` 成环,导致 gadget irq
  未就绪,UDC `start -19`。husb311 是 Hynetek Type-C PD 控制器
  (`CONFIG_TYPEC_HUSB311=y`,6.1 能 probe),但**角色检测依赖 PD 协商**;
  peripheral 模式不需要 PD。
- **修法(两处 DTB,板上/仓库已同步)**:
  - `/usbdrd3_0/usb@fc000000` `dr_mode = "peripheral"`(板永远做 USB 设备,
    电脑做 host——正是 adb 形态);
  - `/i2c@fec80000/husb311@4e` `status = "disabled"`(断依赖环;PD 在
    peripheral 场景无用)。
- **用户态装配(复刻原厂 usbdevice 脚本的 adb 部分,与内核 f_adb 解耦)**:
  - `overlay/usr/local/sbin/agibot-usb-adb`:configfs 建 `usb_gadget/agibot`
    (idVendor=0x2207、idProduct=0x0006=adb PID、serialnumber 取自 DTB)、
    `functions/ffs.adb` link 到 `configs/b.1/`、mount functionfs 到
    `/dev/usb-ffs/adb`、`start-stop-daemon` 起 adbd、`echo $UDC > UDC`。幂等/重启清理齐全。
  - `overlay/usr/local/bin/adbd`:原厂静态 aarch64 ELF(2106864B,零依赖,
    原 5.10 rootfs `/usr/bin/adbd`,rockchip.sh 的 `service adbd start`)。
  - `overlay/usr/local/sbin/agibot-usb-adb-stop` + `agibot-usb-adb.service`
    (oneshot,After=systemd-udev-settle,ConditionPathExists=/sys/class/udc)。
  - `customize-image.sh`:chmod + systemctl enable。
- **板上验证(Windows 侧)**:`adb devices` → `SN123 device`;
  `adb shell` 返回 `ADB-OK`/`uname`/`uptime`。
- **安全:默认关闭(opt-in)**。实证 `adb shell id` → `uid=0(root) gid=0(root)`:
  原厂静态 adbd 以 **root** 运行,Type-C 口一旦挂上,任何插线电脑都能
  `adb shell` 拿到整板 root shell(原厂 rockchip.sh 的 adb 启动同样是注释
  掉的,默认不跑)。因此 `customize-image.sh` 只安装服务、**不 enable**;
  需要调试时手动 `systemctl enable --now agibot-usb-adb.service`,
  停用 `systemctl disable --now agibot-usb-adb.service`。未启动时
  dr_mode=peripheral 但无 gadget 装配 → Type-C 口不枚举,电脑侧完全无感。
- **仓库 DTB 固化**:overlay DTB 已带 `dr_mode=peripheral` + `husb311=disabled`。

## 固化:下次打包一次成功


启动与 HDMI 控制台所需的持久化改动已经落在仓库:

**`overlay/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb`**(预编二进制 DTB)的
`/chosen/bootargs` 已包含:

```
root=PARTUUID=614e0000-0000
```

改为:

```
console=ttyFIQ0 console=tty1 root=/dev/mmcblk0p1
```

(`/dev/mmcblk0p1` 是通用设备名,不依赖每次构建变化的 UUID。前提:本板 armbian
GPT 是**单分区**,p1=rootfs,`boot` 目录与 rootfs 同分区——见 `config/boards/agibot.conf`。)

同一 DTB 还固化了两组后续修复(与板上实测一致):
- `/usbdrd3_0/usb@fc000000` `dr_mode="peripheral"` + `/i2c@fec80000/husb311@4e`
  `status="disabled"` —— Type-C 口 adb 功能(见上文 Type-C adb 章节);
- `watchdog@feaf0000` `status="okay"` —— 看门狗。

该 DTB 由 `customize-image.sh` 第 17-22 行复制进镜像的 `/boot/dtb-*-vendor-rk35xx/rockchip/`,
所以改这个 overlay DTB 即完成固化,下次 `setup.sh && docker-build.sh` 直接产出可启动镜像。
镜像产物可离线核验:`scripts/verify-image.sh`(基础)+ `scripts/check-session-fixes.sh`
(本会话全部修复的定向核验,16 项:DTB 三改、服务 enable 状态、adbd、VPU 库、
ACM 内建、BT firmware;2026-08-17 构建实测 16/16 通过)。
随 DTB 一起固化的还有 overlay 服务,均由 `customize-image.sh` 安装:
`agibot-usb-hub-reset.service`(hub 复位,enable)、`agibot-usb-port-power.service`
(USB-A 供电,enable)、`agibot-usb-adb.service`(Type-C adb,**安装但默认不
enable**——原厂 adbd 跑 root,按需 `systemctl enable --now` 打开)。

### 验证(下次构建后)

刷入后 COM5 @ 1500000 应看到 `Starting kernel ...` 之后立即出 `[ 0.xxx]` 早期日志
(earlycon 直写 uart2),一路到 `armbian login:`。网络两路 RTL8211F 正常注册、
无 `Failed to reset the dma`(vendor gmac 驱动,与 OpenWrt mainline 内核的死结不同)。

## 刷机方法汇总(loader / maskrom)

OpenWrt 主线版 U-Boot 尚未接入 SW9200；AGIBOT Armbian vendor U-Boot 源码已按
原厂 DTB 接入 SW9200 下载键（交叉编译和完整镜像构建已通过，须刷入新镜像后实机
验收）。旧 eMMC 镜像不会因本机完成编译而改变，未刷入前按键测试必然无效。仍可
通过 U-Boot 命令或擦 idbloader 进入下载模式。
**真 Maskrom 比 Loader 稳**(RKDevTool 标准 BROM+loader 协议,不会「读取 flash
信息失败」)。

### 进 Loader(U-Boot 命令,快)

- **OpenWrt 版 U-Boot**:上电 → `Hit any key to stop autoboot` 按任意键 → `=> rockusb 0 mmc 0`
- **Armbian vendor U-Boot**:上电 → `Hit key to stop autoboot('CTRL+C')` 时按 **Ctrl+C**(发 0x03)→ `=> download`(或 `rockusb 0 mmc 0`)
- RKDevTool 顶部显示 **「发现一个 LOADER 设备」**

> ⚠️ LOADER 模式下用「下载镜像」页的 `Loader@0xCCCCCCCC + image@0x0` 组合会报
> 「读取 flash 信息失败」(rockusb 模拟的 loader 与 BROM loader 下载协议不兼容)。
> LOADER 模式要刷,用两步式:①「高级功能 → 下载 Boot」单独下 loader,设备变 LOADER;
> ②「下载镜像」只加 image@0x0。

### 进 Maskrom(真 BROM,最稳,刷机首选)

进真 Maskrom 的本质是**让 BROM 读不到 idbloader**。三种等价操作(**方法 0 最快**,
完整问答见 [FAQ.md Q1](FAQ.md#q1)):

0. **Linux 里擦,SSH 远程**(能进系统时最快,2026-08-14 实测):
   ```sh
   ssh root@<板子IP>   # 密码 1234
   dd if=/dev/zero of=/dev/mmcblk0 bs=512 count=32768 conv=fsync; sync; reboot -f
   ```
   ⚠️ paramiko 自动化发 `reboot -f` 必须后台化,否则 channel 关闭会杀掉 reboot:
   `c.exec_command("(sleep 1; reboot -f) >/dev/null 2>&1 &")`。
   验证:ping 断(Maskrom 无网络)+ 串口完全静默 + RKDevTool 显示 MASKROM。
   可顺手 `dd ... skip=64 count=1 | hexdump` 校验 RKNS 魔数已清零。
1. **U-Boot 里擦**(当前停在 U-Boot 时):
   ```
   => mmc dev 0
   => mmc erase 0 0x8000      # 擦 eMMC 前 16MiB(idbloader@32KB + u-boot@8MB)
   => reset
   ```
2. **Linux 里擦**(本机接串口/键盘时):
   ```sh
   dd if=/dev/zero of=/dev/mmcblk0 bs=512 count=32768; sync; reboot
   ```

擦完重启后 BROM 找不到 loader 回退 Maskrom,RKDevTool 显示 **「发现一个 MASKROM 设备」**。
然后「下载镜像」页两项(标准流程,兼容):

- **Loader** `@0xCCCCCCCC` → `flash/rk3588_spl_loader_v1.16.113.bin`
- **image** `@0x00000000` → 整盘 `.img`(armbian 或 openwrt)

### SW9200 按钮进 Loader(2026-08-16 ✅ 恢复成功)

- 检测者是 **U-Boot proper 的 `setup_download_mode()` + DTB adc-keys 节点**
  (PID 0x350B 是 U-Boot 自己的 `CONFIG_ROCKUSB_G_DNL_PID`)。
- **正确写法 = 节点带 `u-boot,dm-spl`**(Radxa rock-3a/e25 同款)。三个坑:
  ① 无标记 → 被 fdtgrep 剥离,节点进不了 u-boot.dtb,按键失效(P9703 实测);
  ② `u-boot,dm-pre-reloc` → console 前绑定探测 → 启动静默挂死(fd2c6b78 实测);
  ③ USB gadget 起不来时 `download` 自动 fallback `rbrom` → Maskrom(按住按键
  上电可能得到 Loader 或 Maskrom,均可用;正式刷机首选 Maskrom)。
- 当前板上 U-Boot hash `S39cd-P986b`(fwver uboot-rmbian-201-08/16/2026),
  由 P9a41 经 SSH dd 引导区就地升级(方法见 UBOOT-BRINGUP.md),
  冷启动/按键/回归 23-0 全部验证。

## Linux DTB 修复(2026-08-14,稳定 v3)

1. **CPU 一直高频(`no supported OPPs`)**:DTB 的 OPP 表带
   `nvmem-cells + opp-supported-hw` 硬件匹配,本板 OTP 读值与 opp 条目不匹配
   → 全部 OPP 被拒。修法:从 OPP 表删 `nvmem-cells`/`nvmem-cell-names`/
   `rockchip,supported-hw`/`opp-supported-hw`(手术脚本 `_fix_dtb.py`)。
   修后小核 1.2–1.8GHz、大核 1.2–2.2GHz,ondemand 正常调频。
2. **tsadc probe -22(`Failed to find 'trips' node`)**:原厂 DTS 7 个 thermal
   zone 只有 soc-thermal 带 trips,6.1 内核要求每个 zone 都有。给
   bigcore0/1、littlecore、center、gpu、npu 六个 zone 补 trips(passive 75°C +
   critical 115°C)。修后 `tsadc is probed successfully!`,7 个 zone 全部出温度。
3. **rkvenc2 视频编码器 OPP**:DTB 的 rkvenc-core 节点缺 opp 表。照 RK3588
   兄弟板 sige7 移植 `venc-opp-table`(800MHz/800mV,不带 nvmem 匹配),给
   `vdd_vdenc_s0` 加 phandle,两个 core 挂 `operating-points-v2`+`venc-supply`
   (脚本 `_fix_venc.py`)。修后 `mpp-srv probe success`,零 rkvenc OPP 报错。
4. **Linux 下 SW9200 按键阈值**:`1750uV` 过严(按下实测约 17mV),已改为
   30000uV。Linux input 事件的最终按压验收待有人在板旁执行;不影响 U-Boot
   的 SW9200→Loader 功能。

稳定 v3 overlay DTB SHA-256:
`007b1b76dc3c221da437e321581423ab889291ef831b042b4aae886943a6f133`。
深度回归:PASS=22/FAIL=0;8 核满载 90 秒最高约 41.6°C;NPU 171.3 FPS;
eMMC 写约 218MB/s;eth1 1Gbps Full;USB hub 正常。

## 显示 DTB v5 事故/当前板端恢复

2026-08-14 在无人可物理复位的条件下,在线覆盖默认 DTB 测试 HDMI/DP 迁移是错误
操作。v4 尚能启动但 DRM 反复 `EPROBE_DEFER(-517)`;v5 合并修改 HDMI PHY clock
provider、旧 clk-port 接线和 VOP OPP 后,板端内核启动挂起,SSH/串口不可操作。
失败 v4/v5 **未提交/未推送**,仓库已经恢复稳定 v3。板端 `/root/dtb.v3-good`
可用于恢复;完整时间线、U-Boot 手动启动命令和后续分阶段修复规则见
**[DISPLAY-DTB-INCIDENT.md](DISPLAY-DTB-INCIDENT.md)**。

## 附:本次调试的关键命令(复用)

```bash
# 串口助手(Windows pyserial,COM5 @ 1500000 8N1)
python _ser.py "命令" 捕获秒数

# 抓 U-Boot 后擦 idbloader 进 Maskrom
python _erase_to_maskrom.py

# fdtput 改 overlay DTB 的 root=(固化时用过一次)
fdtput -t s overlay/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb /chosen bootargs \
  "earlycon=uart8250,mmio32,0xfeb50000 console=ttyFIQ0 irqchip.gicv3_pseudo_nmi=0 root=/dev/mmcblk0p1 rw rootwait"
```

## 附:引脚/串口实测工具箱(2026-08-16 BT 调试沉淀,测其他针脚/按钮前先读)

**安全铁律**:`gpioget`/gpiod 扫 SoC gpiochip 会把未 claimed 的关键输出脚改输入
→ 板子崩(实测过两次)。只准只读:`cat /sys/kernel/debug/gpio`、SARADC
`/sys/bus/iio/devices/iio:device0/in_voltageN_raw`。要常拉电平用 DT `gpio-hog`
(开机即生效),sysfs export 仅限临时调试。

**串口测协议(任何 uart 外设)**:
- 先看 `/proc/tty/driver/serial` 的 **tx/rx 计数**——tx 涨 rx 不涨 = 对面没收到
  或没回,这是硬证据,别先猜协议。
- 必须 `exec 3<>/dev/ttySN` **全程持 fd**:`printf > tty` 发完即关,ACK 毫秒级
  回来被 8250 丢弃,极像"无响应"。
- 设备不存在时 `>/dev/ttySN` 会在 devtmpfs 建普通文件 → od 读回自己的字节 =
  **假 ACK**;先 `ls -l` 确认是字符设备。
- **CRTSCTS 坑**:DW apb uart 开 CRTSCTS 后 TX 被 nCTS 门死(ctsn 未接线则恒死,
  字节卡 FIFO、tx 计数照涨)。测不通查 `tcgetattr` cflag 是否带 0x80000000。
- `TIOCMGET`(0x5415,传 buffer)读 MCR/MSR 活状态:DTR=0x2 RTS=0x4 CTS=0x20
  CD=0x40 DSR=0x100;MSR.CTS 仅在 ctsn mux 成 UART 功能后才有意义。
  /dev/mem 被 STRICT_DEVMEM 拦,读不到,用这个替代。
- python `fcntl.ioctl` 语义:内核用 arg **原值**的(如 HCIUARTSETPROTO
  0x400455C8)必须传裸 int,传 buffer = 指针值当参数;TIOCSETD(0x5423)/
  TIOCMGET 是指针语义,传 buffer。
- 内核驱动调试:dynamic_debug(`echo 'module hci_uart +p' >
  /sys/kernel/debug/dynamic_debug/control`)+ unbind/bind
  `/sys/bus/<bus>/drivers/<drv>/` 免重启重跑 probe。

**BT 引脚硬结论**:

| 引脚 | 全局号 | 功能 | 实测 |
|---|---|---|---|
| GPIO1_A6 | 38 | BT_REG_ON | 高=上电,上电 **50ms 即响应 HCI** |
| GPIO3_B2 | 106 | BT_WAKE | 高=唤醒 |
| GPIO2_C4 | 84 | HOST_WAKE_BT | 模块→主机中断 |
| GPIO1_A2 | 34 | uart6 rtsn | mux 0x1ac 生效 |
| ctsn | — | **未接线** | mux 了 MSR 也恒 0,流控路线全死 |

**phandle↔gpio bank 对照(反编 DTB 用)**:gpio1@fec20000=0x191、
gpio2@fec30000=0x1af、gpio3@fec40000=0xf0、gpio4@fec50000;全局号=bank×32+pin。
⚠️ vendor `wireless-bluetooth` pinctrl `<0x1ac 0x1ad>` 里 **0x1ad 是 bt-gpio 组
(非 ctsn)**,别再当 ctsn 用。
