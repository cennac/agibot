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
| U-Boot | 本版使用 **agibot-rk3588** 专用变体:启用 SARADC1 按键检测与 RockUSB,按住 SW9200 上电进入 LOADER |

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
│   ├── 003-strace-enable-bundled.patch   # strace 6.6+musl io_uring 断言修复
│   └── 010-kernel-rk806-pmic-reset-func.patch  # SW9201 通过 RK806 SYS_CFG3 配置立即复位
├── uboot-patches/
│   └── 211-agibot-rk3588-sw9200-loader.patch  # SW9200 先进 RockUSB Loader,再执行通用 boot-mode 检测
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
  立即硬复位行为;该键仍不能记录成普通 Linux `gpio-key`。最终 DTB 已确认
  属性值为 1,物理轻按待上板回归。不要把它与 SW8900 混为一谈:SW8900 是
  未编程 PMIC 也能复位的硬复位路径;SW9201 依赖 RK806 reset function 配置。
- SW9200:旧路径先执行通用 `setup_boot_mode()`,SARADC1 下载键触发 BROM
  download flag 后复位,实际进入真 Maskrom,RKDevTool 因此读取 flash 信息
  失败。本版改为先执行 `agibot_check_loader_key()`,按住 SW9200 上电直接
  进入 `rockusb 0 mmc 0`,RKDevTool 应显示 LOADER;真 Maskrom 仍保留破坏
  idbloader/擦写前 16 MiB 的救援进入方式。

**2026-08-21 NPU / AP6275P 组合补全(待板测)**:

- RKNPU 不再把 `CLK_NPU_DSU0` 固定在 200 MHz。板级 DTS 提供 300–1000 MHz
  OPP/电压表,驱动侧用 generic OPP + devfreq(`simple_ondemand`)绑定
  `clk_npu` 与 `vdd_npu_s0`;busy 统计来自三个 NPU subcore 的硬件
  `total_busy_time`,三核满载按 100% 计算,并随调频同步调压。
- AP6275P Wi-Fi 使用 PCIe `14e4:449d`(BCM43752)。LEDE 当前 mac80211
  backports 已原生支持该 ID,无需重复移植 Armbian 内核 patch;镜像新增
  `brcmfmac43752-pcie.bin/.txt/.clm_blob` 与 `agibot,mb0002-v2` 板级 NVRAM
  链接,并默认安装 `kmod-brcmfmac`。
- AP6275P 蓝牙使用 UART6/ttyS6 + `BCM4362A2.hcd`。因板端 BCM nCTS 未接,
  `hci_bcm` serdev 与 `btattach` 会开启 CRTSCTS 并把 TX 门死;本版改为
  `agibot-bt-attach` 用户态持有 ttyS6、显式关闭 CRTSCTS、设置 N_HCI 后加载
  BCM protocol。`BT_REG_ON=GPIO1_A6`、`BT_WAKE=GPIO3_B2` 在 DTS 中拉高。
- 2026-08-21 板测顺序:NPU 查看
  `/sys/class/devfreq/fdab0000.npu/{governor,cur_freq,available_frequencies}`;
  Wi-Fi 查看 `dmesg | grep -Ei 'brcmfmac|43752|449d'` 并执行 `iw dev wlan0 scan`;
  蓝牙确认 `agibot-bt-attach` 进程、`hci0` 与 `BCM4362A2` firmware 日志。
- 2026-08-21 设备补齐镜像已加入 UVC、RTC HYM8563、Panthor、CAN0/CAN1、
  RGA 与 Hantro VPU;板测 `/dev/video1-2` 为 UVC 摄像头,`/dev/rtc0` 时间同步,
  `can0/can1` 均能 500 kbps loopback 收发。

## 已构建产物(2026-08-21 SW9200 Loader / SW9201 复位 / HID 键盘修订,66 原生编译)

| 镜像 | 大小(gz) | sha256 |
|---|---:|---|
| `openwrt-rockchip-armv8-agibot_mb0002-v2-squashfs-sysupgrade.img.gz` | 126.2 MiB | `ae622728ea330d4a47d659fa6516e7809f911056045d77252c5ed1aa823a4da6` |
| `openwrt-rockchip-armv8-agibot_mb0002-v2-ext4-sysupgrade.img.gz` | 162.2 MiB | `7fbeae31f31a26d205446c177d7a02d3c36cc1cb4b93df43bd159f890b86141e` |

本地归档:`../../artifacts/lede-sw9200-loader-sw9201-hid-20260821/`。
归档包含两份 sysupgrade、idbloader、U-Boot ITB/整块启动二进制、DTB、
HID/RKNPU/AP6275P/BT 关键 ipk、manifest/buildinfo、`sha256sums`、关键补丁
与 66 重试构建日志。远端与本机镜像哈希一致。

本修订内容:

- U-Boot 专用 `agibot-rk3588` 变体加入 SW9200 SARADC1 按键与 RockUSB;
  `board_late_init()` 中先执行 `agibot_check_loader_key()`,再执行
  `setup_boot_mode()`,避免通用下载键逻辑先把板子带进真 Maskrom。
- SW9201 保留 RK806 `pmic-reset-func=<1>`,内核在 RK806 probe 阶段写
  `SYS_CFG3[7:6]=01`;离线反编译最终 DTB 已确认属性存在。
- USB 键盘根因是旧镜像只有 `kmod-hid`,缺少 `kmod-hid-generic`,键盘枚举
  后没有 input 驱动。本版 DEVICE_PACKAGES、`.config` 种子与内核配置补丁均
  固化 `kmod-hid-generic`;ipk 内确认存在非空 ARM64 `hid-generic.ko`。
- 状态:构建与离线校验完成,待上板验证。SW9200 应在 RKDevTool 显示
  LOADER;SW9201 轻按应立即复位;HDMI 登录应可用 USB 键盘输入。

## 已构建产物(2026-08-21 clean boot / 非阻断日志治理修订,66 原生编译)

| 镜像 | 大小(gz) | sha256 |
|---|---:|---|
| `openwrt-rockchip-armv8-agibot_mb0002-v2-squashfs-sysupgrade.img.gz` | 126.2 MiB | `73576559582bfb0f9e97102043c50d170d512f38751183f8882402a847482124` |
| `openwrt-rockchip-armv8-agibot_mb0002-v2-ext4-sysupgrade.img.gz` | 162.2 MiB | `0a6400bbb683e7bbc0c77812694cfa50424264bf9abbbe0e17e8dc2a67d6c85c` |

本地归档:`../../artifacts/lede-clean-boot-20260821/`。66 全量构建成功,
远端 `sha256sums` 与本机重算哈希一致;归档同时保存 DTB、idbloader、U-Boot
ITB、Mali 固件、关键 ipk、manifest/buildinfo、`sha256sums`、
`SHA256SUMS.local` 与构建日志。passwall 依赖 `ipt2socks`、
`shadowsocks-rust-sslocal/ssserver`、`v2ray-plugin` 均已进最终 manifest;
AP6275P ipk 内确认存在 `brcmfmac43752-pcie.agibot,mb0002-v2.bin/.txt`。

本修订针对上一版非阻断日志逐项处理:

- 双 GMAC 增补 `snps,no-vlhash`,避免驱动遍历 VLAN hash filter 造成
  `Timeout accessing MAC_VLAN_Tag_Filter` 与 `failed to kill vid`。
- PCIe3x4 的 64-bit MMIO range 扩为 2 GiB,避免空/复杂端点探测时 BAR 分配
  失败;空 M.2 槽无端点时仍会报 `Phy link never came up`,这是预期保留。
- RNG 节点删除不存在的 clocks,避免 probe 期 `-517`;NPU IOMMU clocks 改为
  `aclk` + `iface`。
- RKNPU 寄存器映射改为直接 `devm_ioremap()`,不再先 `request_mem_region`
  再对 IOMMU 地址洞 fallback,消除 3 条 `request region -EBUSY`。
- Panthor cooling 通过 `CONFIG_DEVFREQ_THERMAL=y` 启用;该选项是 bool,
  最终内核配置已确认生效,Panthor 仍为模块。
- AP6275P 固件补板级 BIN symlink/NVRAM,brcmfmac optional firmware fallback
  改为不告警,避免无板级 txcap 文件时输出 `-2` 噪声。
- 独立 DTB、ext4 boot DTB、squashfs boot DTB 已反编译核对,三项 MD5 一致,
  上述 DTS 修复均在最终镜像内。

状态:**构建与离线校验完成,待上板回归**。刷入后建议先执行:

```sh
dmesg | grep -Ei 'error|failed|fail|warn|ebusy|timeout'
ls -l /dev/hwrng
head -c 32 /dev/hwrng >/dev/null
ls /sys/class/devfreq
ls /sys/class/drm/renderD*
ip link
iw dev wlan0 scan
hciconfig
```

## 已构建产物(2026-08-21 HDMI 登录 + USB/BT 启动修订,66 原生编译)

| 镜像 | 大小(gz) | sha256 |
|---|---:|---|
| `openwrt-rockchip-armv8-agibot_mb0002-v2-squashfs-sysupgrade.img.gz` | 126 MiB | `978f335449e36ff2ce5bcadd973a875f346efd31931fc9c4ce58b83ee187e917` |
| `openwrt-rockchip-armv8-agibot_mb0002-v2-ext4-sysupgrade.img.gz` | 162 MiB | `947a0135d56aa9b5b0bd5245fe0cc0840be60ce48efcc23bf80e932de3be2616` |

本地归档:`../../artifacts/lede-hdmi-login-usb-bt-20260821/`。66 完整构建
退出码 0;`sha256sums` 与本机 `SHA256SUMS.local` 均验证通过。除镜像外归档
包含 DTB、idbloader、U-Boot ITB、Mali 固件与 GPU/NPU/BT/Wi-Fi/CAN 关键 ipk。

本修订内容:

- tty1 从 root shell 改为标准 `/bin/login`;HDMI 登录界面与进程绑定已上板验证。
- USB-A VBUS 初始化等待 4 个 Genesys hub 后增加 3 秒 settle,并用 sysfs GPIO
  `direction=high` 降低切换输出时的低电平毛刺;UVC 启动期 `error -71` 已消失,
  摄像头最终枚举为 HD Camera。保留 board-level hub reset/供电初始化时,启动期
  仍可能看到一次 USB 重枚举,但不再留下 probe error。
- `agibot-bt-attach` 升级到 `1.0.0-2`:attach 成功后自动等待并执行
  `/usr/bin/hciconfig hci0 up`,包依赖显式加入 `bluez-utils`。旧 helper 上手动
  `hciconfig hci0 up` 已验证;新 ipk 待下次整盘刷机做冷启动复核。
- 全量 `dmesg` error 审计当时无新的未解释失败;空 M.2、TRNG 探测、
  NPU/IOMMU fallback、eth0 VLAN filter、Panthor cooling、Wi-Fi 板级
  NVRAM fallback 均为历史版本已验证非阻断噪声。后续 clean boot 修订已逐项
  治理,仅空 M.2 无端点日志预期保留。

## 已构建产物(2026-08-21 设备补齐 + Mali 固件/CAN 工具修订,66 原生编译)

| 镜像 | 大小(gz) | 解压 | sha256 |
|---|---|---|---|
| `openwrt-rockchip-armv8-agibot_mb0002-v2-squashfs-sysupgrade.img.gz` | 127 MiB | 2 GiB | `75be1f955ac56ddd7384f5e232039bcfc052266b709bb34c76a34e84bb821c83` |
| `openwrt-rockchip-armv8-agibot_mb0002-v2-ext4-sysupgrade.img.gz` | 163 MiB | 2 GiB | `2825f5009cc7ab71ee7698ac5f84e822398f35c12b8f5a32315c98231dc36da8` |

本地归档:`../../artifacts/lede-gpu-fw-can-utils-20260821/`。除常规产物外,
包含 `mali_csffw.bin`、`canutils-candump/cansend` ipk、DTB、idbloader、
U-Boot ITB 与 66 构建日志;`sha256sums` 与本机 `SHA256SUMS.local` 均验证通过。

本轮板测结论:

- NPU:`/dev/dri/renderD*` 注册;devfreq 为 `simple_ondemand`,支持
  300/400/500/600/700/800/900/1000 MHz,空闲 300 MHz。
- CPU:8 核均为 `schedutil`,运行时频率可见。
- Wi-Fi:`wlan0` AP 模式可扫描周边 BSS;蓝牙 `hci0` 识别 BCM43752A2,
  firmware build 1017,可 `UP RUNNING`。
- GPU:首个设备补齐镜像缺 `arm/mali/arch10.8/mali_csffw.bin`,Panthor
  probe 返回 `-12`。将 Armbian 固件补入根文件系统后冷启动验证通过,
  CSF FW v1.1.0 注册 `renderD129`;该固件已固化进本修订镜像。
- CAN:`canutils` 元包本身不含工具,需显式加入 `canutils-candump/cansend`;
  两个子包已固化进本修订镜像并完成 can0/can1 loopback。
- 注意:Panthor 不支持运行中 `rmmod` 后重载,会触发 GPU power-domain
  SError;冷启动加载路径稳定,不要把该路径当作常规测试。
-- NPU 驱动启动时的 3 条 `request region ... -EBUSY` 是历史设备补齐镜像的
  已知 fallback 路径;clean boot 修订已改为直接 `devm_ioremap()`,该项待
  上板确认日志消失。

## 已构建产物(2026-08-21 NPU DVFS/AP6275P 修订版,66 服务器原生编译)

| 镜像 | 大小(gz) | 解压 | sha256 |
|---|---|---|---|
| `openwrt-rockchip-armv8-agibot_mb0002-v2-squashfs-sysupgrade.img.gz` | 126 MiB | 2.13 GiB | `25150a665f493e01772db81db03d4e5e913fada9de70ad38ba6101e96df699d3` |
| `openwrt-rockchip-armv8-agibot_mb0002-v2-ext4-sysupgrade.img.gz` | 162 MiB | 2.13 GiB | `d00bcbe5c166297e3d624c2de47252798819e3b559125c9d6c4504ea8b4400f8` |

本地归档:`../../artifacts/lede-npu-devfreq-wifi-bt-20260821/`
(包含 manifest/buildinfo、板卡 DTB、idbloader、U-Boot ITB、关键 ipk 与 66 构建
日志;sysupgrade/manifest/buildinfo 均已按 `sha256sums` 在本机复验,另生成
`SHA256SUMS.local`)。远端完整构建 `FINISHED_EXIT=0`;单包强制重编 RKNPU 后,
模块内确认包含 generic OPP / devfreq 字符串。板卡待测项仍以 NPU 调频、Wi-Fi
扫描、蓝牙 `hci0` 为准。

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
