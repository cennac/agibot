# OpenWrt / LEDE for AGIBOT MB0002 V2 (RK3588)

为 **AGIBOT MB0002 V2**(RK3588,双千兆)构建的 **LEDE(Lean's OpenWrt)** 固件,与本仓库的 armbian 路线并列。

底子是 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)(自带 LuCI + passwall/openclash/homeproxy/docker 全家桶)。与 armbian 的本质区别:**用主线内核(6.12)+ rkbin blob 的 ATF**,因此需要一份可编译的主线风格 `.dts`(本目录已提供),而 armbian 用 vendor 6.1 BSP 内核 + 二进制 dtb。

> **关于 ssr-plus**:LEDE 默认把 `luci-app-ssr-plus` 选中 =y,但它硬依赖 `shadowsocks-libev`(本环境所有 feed 均无此包)+ `shadowsocksr-libev`(GCC13 `-Werror=use-after-free` 编译失败)。passwall 已覆盖 SSR/SS/V2Ray/Trojan 全部场景,**故显式关闭 ssr-plus,只用 passwall**。若日后确需 ssr-plus:补 `shadowsocks-libev` 源 + 给 shadowsocksr-libev 加 `TARGET_CFLAGS += -Wno-error=use-after-free`,并放开 config 里对应开关。

## 板级事实(DTS 移植依据,源自 5.10 BSP)

| 项 | 值 |
|---|---|
| SoC | Rockchip RK3588 |
| 以太网 | **双千兆 RGMII**:gmac0(reset GPIO4_D5,tx_delay 0x43,PHY reg 1)+ gmac1(reset GPIO4_D4,tx_delay 0x42,PHY reg 0);PHY 通用 `ethernet-phy-ieee802.3-c22`(无厂商串,主线自动识别) |
| 存储 | 仅 **eMMC**(`sdhci`,8-bit HS400-ES);SD 在 BSP 里 disabled(机器人板无 SD 槽) |
| PMIC | **RK806 在 SPI2**(IRQ GPIO0_A7,少见 —— 多数板在 I2C),完整 21 路电源树;CPU big0/big1 走 i2c0 的 rk8602@42/rk8603@43,NPU 走 i2c1 rk8602@42 |
| 控制台 | **UART2 @ 1.5Mbps**(丢 BSP 的 fiq-debugger,主线用标准 8250) |
| U-Boot | 复用 LEDE 自带 **generic-rk3588** 变体(运行时从 boot 分区加载板级 DTS,无需专用 defconfig) |

## 目录结构

```
openwrt/
├── lede/                      # coolsnowwolf/lede git submodule(锁 commit)
├── files/
│   └── arch/arm64/boot/dts/rockchip/
│       └── rk3588-agibot-mb0002-v2.dts   # ★ 主线精简路由 DTS(电源树照搬 seewo srcm3588-io,双 GMAC 参考 nanopi-r6;
│                                          #   2026-08-17 增补 PCIe 三路:3x4+2x1l0+2x1l2,引脚/供电取自 5.10 BSP,
│                                          #   写法照 sige7;TRNG 经查 LEDE 原生已有(dtsi 节点+驱动+config 全在),
│                                          #   已 &rng 显式启用;主线真正没有的是 rk3588 DMC(DDR 调频)驱动,不移植)
├── patches/
│   ├── 001-rockchip-add-agibot-mb0002-v2-image.patch   # armv8.mk 加 DEVICE 块(UBOOT=generic-rk3588)
│   ├── 002-uboot-rockchip-build-generic-rk3588-agibot.patch  # generic-rk3588 的 BUILD_DEVICES 追加本板
│   └── 003-strace-enable-bundled.patch   # strace 6.6+musl io_uring 断言修复
├── config-agibot-openwrt      # .config 种子(Target/Profile + 全功能选包:LuCI/docker/passwall/sqm)
├── Dockerfile-lede            # LEDE builder 镜像(ubuntu:22.04,纯交叉编译,无 qemu/binfmt)
├── docker-lede-build.sh       # 容器编译入口(WSL 内跑,挂 ext4 仓库;无 -v /dev:/dev)
├── macos-lede-build.sh        # macOS 本机编译入口(不使用 Docker,Homebrew GNU 工具链)
├── setup-openwrt.sh           # 装配:init submodule + apply patch + 装 DTS + helloworld/feed + defconfig
└── README.md                  # 本文件
```

## 编译

支持 **macOS 本机 / WSL2 原生 / Linux 原生 / Docker**。脚本自动检测平台。LEDE 是纯交叉编译 —— 无需 qemu/binfmt、无需 host `/dev`(自带 ptgen 打镜像)。

### macOS 本机编译(不使用 Docker)

完整记录见 [`docs/MACOS-LEDE-BUILD.md`](../docs/MACOS-LEDE-BUILD.md)。要点:

```bash
brew install bash coreutils diffutils findutils gawk gpatch gnu-getopt gnu-sed grep gnu-tar \
  make ncurses openssl@3 perl python@3.12 rsync unzip wget xz zstd gettext pkgconf swig

cd openwrt
bash macos-lede-build.sh                       # 完整编译
bash macos-lede-build.sh target/linux/compile  # 只验证 DTS/内核目标
```

仓库所在卷必须大小写敏感;若 GitHub 直连慢,先 `export http_proxy=http://127.0.0.1:7897` 后重跑。

### Docker 编译(可选)

```bash
# 1. clone(含 submodule)
git clone --recursive https://github.com/cennac/agibot.git
cd agibot/openwrt

# 2. 启动 Docker Desktop → Settings → Resources → WSL Integration → 开 Ubuntu
#    (编译须在 WSL Ubuntu 内跑,让 -v 挂 ext4 而非 9p)

# 3. 完整编译(装配 + make -jN)
bash docker-lede-build.sh

#    只验证 DTS 能否编出 .dtb(快速,bring-up 用):
bash docker-lede-build.sh target/linux/compile
```

产物:`openwrt/lede/bin/targets/rockchip/armv8/*agibot*sysupgrade.img.gz`

### 原生编译(WSL2 / Linux)

66 服务器 Ubuntu 26.04 的完整原生编译实录、代理参数、断点续编和故障处理见 [`docs/BUILD-SERVER-66-LEDE.md`](../docs/BUILD-SERVER-66-LEDE.md)。

```bash
cd openwrt
bash setup-openwrt.sh                 # 装配:submodule + patch + DTS + feeds + defconfig
cd lede && make -j$(nproc) V=s
```

代理:WSL2 自动走 Windows 网关 Clash(7897);Linux/macOS 检测本地 7897 或继承 `http_proxy`。
Docker 下 `DIRECT=1 bash docker-lede-build.sh` 不传代理(feeds 已装 / cache 齐时更稳)。

## 2026-08-20 bring-up 状态

**已在 2026-08-20 旧增量镜像板卡确认**:双 RTL8211F 以太网、SW9200 断电长按进
Loader/Maskrom、HDMI DRM/framebuffer 与 tty1 root shell 进程、RKNPU DRM
render node、CPU DVFS。加压时 policy4/policy6 从 1.2 GHz 升到 2.4 GHz;
RKNPU 有三条 `request region -EBUSY` 日志,这是驱动先尝试 `devm_ioremap_resource`
再回退 `devm_ioremap` 的已知路径,最终 `/dev/dri/renderD128` 绑定 `RKNPU`。

同轮板测也发现旧增量镜像的两个真实问题:

- USB 初始化脚本使用了 `sleep 0.1/0.2/0.5`,LEDE BusyBox `sleep` 不接受小数,
  导致 `/etc/init.d/agibot-usb restart` 返回 1、GPIO154/155 停在 reset。
  板上把脚本热修为整数 `sleep 1` 后,两颗 Genesys hub、USB 键盘和摄像头均枚举,
  PCA9555 `3-0020` offsets 0..11 全部成功拉高——USB-A 数据与 VBUS 硬件路径确认。
- `fe170000/fe190000` PCIe 报 `missing PHY`。主线 6.12 映射分别是
  `combphy1_ps`/`combphy0_ps`;旧板级 DTS 只打开了 `combphy2_psu`,而
  `combphy2_psu` 实际服务 `fcd00000 usb_host2_xhci`,不能挪给 PCIe。

**新增修复已在最终镜像板卡回归**:

- USB 供电/拓扑:最终镜像 `/rom` 中两个脚本全部为 BusyBox 兼容的整数
  `sleep 1`;`/etc/init.d/agibot-usb restart` 返回 0,无 `sleep: invalid number`,
  四组 Genesys hub、USB 键盘和 UVC 摄像头均枚举。首次上电和手动重启时摄像头
  曾各出现一次 `error -71` 后自动恢复,后续可把 VBUS settle 时间再调稳。
- PCIe/USB3 PHY:运行 DTB 中 `fee00000/fee10000/fee20000` 全部 `okay`;
  `fe190000` 以 Gen2 x1 训练成功,枚举 VL805 `1106:3483` 并绑定 `xhci_hcd`;
  `fe170000` 以 Gen1 x1 枚举 AP6275P Wi-Fi `14e4:449d`。空 `fe150000`
  Gen3x4 插槽仍报 `Phy link never came up`,当前按无端点解释。
- SW9201:板级 DTS 加入 RK806 `pmic-reset-func=<1>`,并为主线 6.12 增加
  `rk8xx-core` 补丁以编程 `SYS_CFG3[7:6]`。目标是恢复与 Armbian/原厂一致的
  立即硬复位行为;该键仍不能记录成普通 Linux `gpio-key`。运行 DT 已确认
  属性值为 1,物理轻按复测留待 2026-08-21。
- SW9200 的 U-Boot Loader/Maskrom 路径未改;此前已实测可用,最终镜像路径
  与明天 SW9201 一起回归。

**下一阶段已明确的缺口**:

- NPU 当前是保守固定频:DTS 将 `CLK_NPU_DSU0` 固定在 200 MHz,板上
  `/sys/class/devfreq` 没有 NPU 设备;本仓暂只带 RKNPU DRM/ioctl 驱动,尚未移植
  vendor `rknpu_devfreq.c` 与 OPP/电压表。下一步先补动态调频,再做 RKNN runtime
  实际推理验证。
- AP6275P Wi-Fi 硬件链路已经打通,但 LEDE 镜像未带 `14e4:449d` 驱动和固件,
  因此没有 `wlan0`;蓝牙还需要同步移植 UART/HCI attach 与 `BCM4362A2.hcd`。
  Wi-Fi/蓝牙应作为一个 AP6275P combo 包处理,避免只修 PCIe 不修固件。
- 当前镜像未带 UVC/HID 内核包:摄像头和键盘能 USB 枚举,但无 `/dev/video*`
  与 `/dev/input`;如需在 LEDE 本机使用,加入 `kmod-video-uvc` 与 `kmod-usb-hid`。

## 已构建产物(2026-08-20 USB BusyBox/VL805 修订版,66 服务器原生编译)

| 镜像 | 大小(gz) | 解压 | sha256 |
|---|---|---|---|
| `openwrt-rockchip-armv8-agibot_mb0002-v2-squashfs-sysupgrade.img.gz` | 124 MiB | 2.13 GiB | `c9be967159258571bea1452b7603af164f07fe8d8bdc11b66f7c302fcf39d64a` |
| `openwrt-rockchip-armv8-agibot_mb0002-v2-ext4-sysupgrade.img.gz` | 159 MiB | 2.13 GiB | `cc557909b34a6ded35099a0b2683392e86547abd665bba4ae1664c46fc214003` |

本地归档:`../../artifacts/lede-usb-busybox-vl805-20260820/`
(包含 manifest/buildinfo、板卡 DTB、U-Boot DTB、idbloader、U-Boot ITB 和三份 66 构建
日志;sysupgrade/manifest/buildinfo 均已按 `sha256sums` 在本机复验)。远端构建
`FINISHED_EXIT=0`;最终镜像已在 2026-08-20 整板回归,关键结果见上文。

⚠️ 本目录 ext4 的 `.gz` 若时间戳是 08-14 且带 `_STALE-*.txt` 标记,是旧构建被
Windows 进程锁住删不掉——用同目录解压版 `.img`(08-15)或 WSL `~/lede/bin/...` 的新 gz。

**推荐 squashfs**(官方惯例:支持 sysupgrade + 恢复出厂;rootfs 用 squashfs xz,剩余空间给 overlay/docker)。ext4 为可扩容全盘分区(2 GB),两者分区布局一致。

**已含(见同目录 `.manifest`)**:`luci-app-passwall 26.4.6`(+shadowsocks-rust-sslocal/ssserver + ipt2socks + v2ray-plugin,不含 simple-obfs)+ `luci-app-openclash` + `luci-app-homeproxy` + `dockerd/docker-compose` + LuCI 中文 + `luci-app-sqm`。

**2026-08-15 增补(完善版)**:
- 网络诊断:iperf3 / ethtool / bash / jq / bc / lsof / strace / uuid
- 监控:luci-app-ttyd(Web 终端)/ netdata / nlbwmon(流量统计)/ statistics(collectd 图形)
- DNS:luci-app-smartdns(mosdns 留注释按需)
- 运维:luci-app-ddns(+ddns-scripts)/ watchcat(断网重连)/ wol / autoreboot
- 健康:lm-sensors / smartmontools;文件:rsync;维护:advanced-reboot / ramfree
- 修复:strace 6.6+musl 编译失败(io_uring 断言),补丁 `patches/003-strace-enable-bundled.patch`

## 从零重建(2026-08-14 实测,代理环境)

`setup-openwrt.sh` 只做装配;本环境(国内 + Windows Clash 代理 + WSL)还有 **3 个必须的手动前置**,顺序如下:

```bash
# 0. 装配(submodule + patch + DTS + feeds)
bash setup-openwrt.sh

# 1. helloworld feed 必须用 src-link(不能用 src-git:git+gnutls 过 Clash 代理握手崩)
bash helloworld-srclink.sh
#    —— curl 下 tarball → 解压到 openwrt/.tmp/helloworld-feed → feeds.conf 写 src-link
#      → feeds update/install(passwall 核心 shadowsocks-rust/ipt2socks 等来自这里)

# 2. docker/dockerd 的 git-short-commit.sh 网络校验会卡死/失败,打补丁跳过
python3 patch-dockerd.py

# 2.5 strace 6.6+musl io_uring 断言修复(干净树由 setup 的 003 补丁自动打;
#      已在用的 ~/lede 可手动 python3 patch-strace.py)
python3 patch-strace.py

# 3. 编译(内置代理 env + GOPROXY=goproxy.cn;GOPROXY 不设会走 proxy.golang.org 国内挂)
bash build-make.sh
```

`build-make.sh` 内部还会:剥掉 WSL 继承的 Windows PATH(含括号,否则 u-boot binman `bash -c` 报 syntax error)、`make defconfig` 落 .config、`make -j$(nproc)`、拷 sysupgrade 回本目录。**注意** `build-make.sh` 依赖 `~/lede` 软链(本机 `~/lede → /home/cennac/lede`),从零 clone 时改成实际路径。

## 刷机(写 eMMC,复用 `flash/`)

实测镜像布局(MBR 整盘,自包含可启动):

| 位置 | 内容 | 证据 |
|---|---|---|
| 32 KB | idbloader | `RKNS` 魔数 |
| 8 MB | u-boot.itb (FIT) | `d00dfeed` 魔数 |
| 32 MB | boot 分区 (ext4,卷名 `kernel`,64 MB) | MBR p1 + superblock |
| 128 MB | rootfs (2 GB,squashfs 或 ext4) | MBR p2 + `hsqs`/`53ef` |

RKDevTool「下载镜像」页加两项(**两项都要,只加 image 会报「固件中存在分区定义过小,镜像过大」**):

1. **Loader** `@0xCCCCCCCC` → `flash/rk3588_spl_loader_v1.16.113.bin`
2. **image** `@0x00000000` → `gzip -dk openwrt-...-squashfs-sysupgrade.img.gz` 解压后的 `.img`(整盘)

⚠️ 别用 RKDevTool 自带的 `MiniLoaderAll.bin`(多半是 RK356x loader,会报「下载 boot 失败」);完整方案见 [`flash/README.md`](../flash/README.md)。eMMC ≥ 4 GB 即可(镜像 2.13 GiB)。

### 启动后

- **串口**:UART2 `1500000` 波特率,`console=ttyS2`。首启见 U-Boot → OpenWrt 内核日志。
- **网络**:默认 LAN `192.168.1.1`(eth0/eth1 由 dts 的 ethernet0/1 alias 决定),LuCI 访问 `http://192.168.1.1`。
- **LAN/WAN 规划**:两个 gmac 均在 dts 里 enable,`/etc/config/network` 里把 wan 指到第二个口即可。

## 验证(成功标准)

1. **串口**:UART2 接 USB-TTL(`console=ttyS2,1500000`),见 U-Boot → 内核 → OpenWrt 启动日志。
2. **网络**:`ip link` 见 eth0/eth1,载波 up;WAN 口 DHCP 拿到地址能上网。
3. **LuCI**:浏览器访问 `192.168.1.1`(默认 LAN),Web 界面 + 中文主题。
4. **全功能**:LuCI 里 passwall2 / openclash / docker / SQM 插件可用。

## DTS bring-up 风险与回退

- **首要风险是 PMIC/console**。RK806 在 SPI2 略少见,电源树已照搬同构的 seewo;console 改主线 uart2。串口看早期日志是关键。
- **eMMC-only**:无 SD 救援启动;失败走 **Maskrom + RKDevTool 回刷**(不损坏,与 armbian 一致)。
- **PHY 通用无厂商串**:主线自动识别,几乎无风险;若某口起不来,启动后 `ls /sys/bus/mdio_devices` 读 PHY ID 补 `ethernet-phy-idXXXX` compatible。
- 若 DTS 编译报某个 `&label` 未定义(如 `&mdio0`),编译会明确指出,在 DTS 里改用对应节点即可 —— 单独验证用 `docker-lede-build.sh target/linux/compile`。

## 与 armbian 路线对比

| | armbian 路线 | LEDE 路线(本目录) |
|---|---|---|
| 用途 | 通用 Linux(开发/桌面) | 路由/网关(双 GbE) |
| 内核 | vendor 6.1 BSP(rk-6.1-rkr5.1) | **主线 6.12** |
| 设备树 | 二进制 dtb(fdtput 改) | **可编译主线 .dts** |
| U-Boot | armbian 框架构建 | LEDE generic-rk3588(rkbin blob) |
| 产物 | Armbian .img(整盘) | LEDE sysupgrade.img.gz(整盘) |
| 刷机 | RKDevTool Loader+image@0 | **同左**(复用 flash/) |
| 编译 | docker-build.sh | docker-lede-build.sh |
