# agibot

为 **AGIBOT MB0002 V2**(RK3588,双千兆)打造的可复现编译 + 刷机工具链,含两条并列路线:

- **Armbian**(通用 Linux / 桌面,vendor 6.1 BSP 内核)—— 本 README 主体
- **OpenWrt / LEDE**(路由 / 网关,主线 6.12 内核 + 双 GbE)—— 见 **[`openwrt/README.md`](openwrt/README.md)**

两条路线刷机方式相同(RKDevTool 整盘写 eMMC,复用 `flash/`)。

## 发行身份

- **发行者**:`Agibot-Armbian`
- **板卡**:`AGIBOT MB0002 V2`
- **维护者**:`cennac`
- **联系邮箱**:`cennac@163.com`

这是由维护者构建和验证的社区定制镜像，不是 Armbian 或 AGIBOT 厂商官方发布。
完整开发历程和最终验证基线见
[`overlay/usr/share/doc/agibot/README.md`](overlay/usr/share/doc/agibot/README.md)；
构建后该文档安装到系统的 `/usr/share/doc/agibot/README.md`，并可从
`/root/README.md` 直接访问。

## 欢迎支持一杯咖啡

如果这个项目对你有帮助，欢迎通过微信或支付宝支持一杯咖啡。感谢你的支持。

<p align="center">
  <img src="assets/support/wechat-payment.jpg" alt="微信收款码" width="320">
  &nbsp;&nbsp;
  <img src="assets/support/alipay-payment.jpg" alt="支付宝收款码" width="320">
</p>

`git clone --recursive` → `bash scripts/install-deps.sh` → `bash setup.sh` → `bash start-build.sh` → 刷机。板级配置与 WSL2 框架 hack 已全部入库,**干净 clone 即可编译,无需手动改框架源码**;脚本自动适配 Linux / WSL2 / macOS。

> 完整步骤(WSL2 四大坑、5 处框架 hack、镜像验证、刷机、跨平台):见 **[BUILD-GUIDE.md](docs/BUILD-GUIDE.md)**。
> OpenWrt/LEDE 路线见 **[§13 / openwrt/README.md](openwrt/README.md)**。
> 板子怎么进 Maskrom/Loader、怎么刷、按键干嘛的、调试怎么不崩板……常见操作问答见 **[FAQ.md](docs/FAQ.md)**。
> 镜像 SHA、离线/实机验收状态及废弃版本见 **[RELEASES.md](docs/RELEASES.md)**。
> 显示 DTB 实验事故、当前板端恢复步骤和后续 HDMI/DP 分阶段规则见 **[DISPLAY-DTB-INCIDENT.md](docs/DISPLAY-DTB-INCIDENT.md)**。

## 板卡 3D 标注图

仓库内置 AGIBOT MB0002 V2 的交互式 3D 标注图，包含接口、按键及已验证功能说明。
下载或 clone 仓库后，无需安装依赖和编译，直接双击
**[`board-3d/dist/index.html`](board-3d/dist/index.html)** 即可离线打开。
需要修改源码时，开发和重新打包方法见 [`board-3d/README.md`](board-3d/README.md)。

## 板子规格
- **SoC**:Rockchip RK3588
- **板子**:AGIBOT MB0002 V2(IP: 192.168.88.101)
- **内核**:Vendor 6.1 BSP(rk-6.1-rkr5.1)
- **基板**:armbian/build,基于 rock-5b 配置
- **版本**:Ubuntu 22.04(jammy)minimal / Ubuntu 24.04(noble)桌面

## 目录结构
```
├── armbian-build/              # armbian/build 框架(git submodule @ 70a242f)
├── patches/
│   └── wsl2-build-hacks.patch  # 5 处 WSL2 框架 hack(仅 WSL2 apply;sync/git/mmdebstrap/fchmod/9p)
├── setup.sh                    # 装配:init submodule + apply patch + 装 userpatches(跨平台)
├── start-build.sh              # 原生编译入口:代理 / NO_HOST_RELEASE_CHECK / git resilience / 后台(跨平台)
├── Dockerfile                  # Docker 编译:ubuntu:22.04 builder 镜像(§12)
├── docker-build.sh             # Docker 编译入口:WSL 内跑,挂载 ext4 仓库进容器(§12)
├── .dockerignore               # docker build context 排除大目录
├── config-agibot.conf          # 主编译配置(jammy minimal)
├── config-agibot-desktop.conf  # 桌面版配置(noble + xfce)
├── config-example.conf         # 示例配置
├── config/
│   └── boards/
│       └── agibot.conf         # 板定义(u-boot defconfig / fdtfile / boot)
├── customize-image.sh          # ★ overlay 注入逻辑(chroot 内执行)
├── kernel/
│   └── rk35xx-vendor-6.1/      # ACM8625P 扬声器 codec 内核补丁
├── overlay/                    # 注入 rootfs 的文件
│   ├── etc/{hostname,systemd/system/agibot-usb-port-power.service}
│   ├── usr/local/sbin/agibot-usb-port-power
│   ├── usr/share/doc/agibot/README.md           # 发行信息、开发历程和验证基线
│   ├── boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb   # 设备树,5.10 → 6.1 适配
│   └── lib/firmware/           # Mali / AP6275P WiFi+BT / ACM8625P DSP / regulatory
├── board-3d/                   # 板卡交互式 3D 标注图(含可直接打开的 dist/index.html)
├── flash/                      # eMMC 刷机 + 板端回归测试
│   ├── rk3588_spl_loader_v1.16.113.bin   # ★ 正确的 RK3588 loader(别用 RKDevTool 自带的 MiniLoaderAll)
│   ├── gen-armbian-cfg.py      # 拆分 img → head/rootfs + 生成 config.cfg
│   ├── dump-cfg-any.py         # config.cfg 查看
│   ├── postflash-test.sh       # 板端回归测试(CAN/UART/GPIO/watchdog/NPU/温度)
│   ├── npu_test.py             # RKNN resnet18 smoke + FPS
│   └── README.md               # 完整刷机方案
├── scripts/                    # 辅助脚本(install-deps / preflight / build-status / verify-image)
│   └── README.md               # 各脚本用法
├── openwrt/                    # 【另一条路线】OpenWrt/LEDE 路由固件(主线 6.12 内核 + 双 GbE)
│   ├── lede/                   #   coolsnowwolf/lede git submodule
│   ├── files/.../rk3588-agibot-mb0002-v2.dts   #   主线精简路由 DTS
│   ├── patches/                #   armv8.mk DEVICE 块 + generic-rk3588 u-boot
│   ├── config-agibot-openwrt   #   .config 种子(全功能:LuCI/docker/passwall/sqm)
│   ├── Dockerfile-lede / docker-lede-build.sh / macos-lede-build.sh / setup-openwrt.sh
│   └── README.md               #   LEDE 编译/刷机/验证
├── wsl-binfmt-setup.sh         # WSL2 qemu binfmt 注册
├── docs/                       # ★ 全部专题文档(互链同级)
│   ├── BUILD-GUIDE.md          #   完整编译教程(WSL2 四大坑/5 处框架 hack/跨平台)
│   ├── FAQ.md                  #   板子操作问答(进 Maskrom/刷机/按键/调试安全)
│   ├── RELEASES.md             #   镜像 SHA/验收状态/废弃版本
│   ├── ARMBIAN-LINUX-BRINGUP.md #  内核 bring-up 全记录(UART/BT/USB/HDMI…)
│   ├── UBOOT-BRINGUP.md        #   U-Boot bring-up 记录
│   ├── ADAPT-NOTES.md          #   设备树 5.10 → 6.1 适配记录
│   └── DISPLAY-DTB-INCIDENT.md #   显示 DTB 事故记录/U-Boot 恢复/后续规则
├── tools/                      # bring-up 期调试工具(串口 _ser.py / 抹 eMMC 进 Maskrom /
│                               #   U-Boot 捕获 / HDMI testboot / ADC 监控 / DTB 手术等)
└── scratch/                    # 本地工作残留(gitignored,不入库)
```

## 编译

支持 **Linux / WSL2 / macOS**(Linux 需 Ubuntu 22.04+ 或 Debian 12+;macOS 需 Docker Desktop)。脚本自动检测平台,差异见 [BUILD-GUIDE §11](docs/BUILD-GUIDE.md#11-附录在-linux-原生--macos-上编译)。

```bash
# 1. Clone(含 submodule)
git clone --recursive https://github.com/cennac/agibot.git
cd agibot

# 2. 装依赖(每台机器一次,跨平台:WSL2 / Linux / macOS)
bash scripts/install-deps.sh

# 3. 装配:init submodule +(仅 WSL2)apply 框架 hack + 装 userpatches
bash setup.sh                   # 加 --reuse-cache 可复用平级 armbian-build/cache

# 4. 编译(代理 / NO_HOST_RELEASE_CHECK / 后台日志均已内置,按平台自动适配)
bash start-build.sh
tail -f armbian-build/output/build.log        # 或 bash scripts/build-status.sh
```
产物:`armbian-build/output/images/Armbian_..._Agibot_jammy_vendor_6.1.115_minimal.img`(~1.7G)

桌面版:`./compile.sh agibot-desktop`(见 [BUILD-GUIDE §10](docs/BUILD-GUIDE.md))。

### Docker 编译(可选,[§12](docs/BUILD-GUIDE.md#12-附录docker-容器编译可选统一三平台))
不想在 host 装 apt 依赖 / 统一三平台环境?仓库 clone 到 WSL ext4(`~/docker-agibot-armbian`),`bash docker-build.sh` 起容器编译——容器内 ext4 自动避开 WSL2 的 9p 坑(fsync/fchmod),无需那 5 处 patch。前置:启动 Docker Desktop + 开 WSL 集成。

```bash
bash docker-build.sh                   # 编 minimal(agibot / jammy,默认)
bash docker-build.sh agibot-desktop    # 编桌面版(noble + xfce)
bash docker-build.sh --shell           # 进容器交互 shell 调试
```

## 刷机(写入 eMMC)
先让板子进 **Maskrom**(能 SSH 时最快:`dd` 擦 eMMC 头部再 `reboot -f`,见 [FAQ Q1](docs/FAQ.md#q1)),
然后见 **[flash/README.md](flash/README.md)**。要点:RKDevTool「下载镜像」页加两项执行——
- **Loader** `@0xCCCCCCCC` → `flash/rk3588_spl_loader_v1.16.113.bin`
- **image** `@0x00000000` → 整盘 `.img`(等同 `dd`,不必拆分)

⚠️ **别用 RKDevTool 自带的 `MiniLoaderAll.bin`**——多半是 RK356x loader,会报「下载 boot 失败」。用仓库里的 RK3588 loader。

## WSL2 备注
首次需注册 qemu binfmt(否则 chroot 报 `Exec format error`):
```bash
sudo bash wsl-binfmt-setup.sh      # 每次 WSL 重启后重跑
```
其余三个 WSL2 坑(fsync 卡死、代理、overlay 注入)+ 5 处框架 hack 已由 `setup.sh` / `start-build.sh` 处理,见 [BUILD-GUIDE §2](docs/BUILD-GUIDE.md)。Linux 原生 / macOS 见 [§11](docs/BUILD-GUIDE.md#11-附录在-linux-原生--macos-上编译)。

## OpenWrt / LEDE 构建(另一条路线)

除上面的 armbian 路线,本仓库还为这块**双千兆**板子提供了一条 **OpenWrt/LEDE 路由固件**路线(主线 6.12 内核 + LuCI + passwall/openclash/docker 全家桶)。完整步骤见 **[openwrt/README.md](openwrt/README.md)**,要点:

```bash
cd openwrt
bash macos-lede-build.sh                        # macOS 本机完整编译(不使用 Docker)
bash macos-lede-build.sh target/linux/compile   # macOS 本机只验证 DTS/内核目标
bash docker-lede-build.sh                       # Docker 完整编译(可选)
```

产物 `openwrt/lede/bin/targets/rockchip/armv8/*agibot*sysupgrade.img.gz` 是整盘镜像,**刷机方式与 armbian 完全相同**(RKDevTool Loader@0xCCCCCCCC + image@0,复用 `flash/`)。与 armbian 的本质差异:用**主线内核 + 可编译主线 .dts**(armbian 用 vendor 6.1 BSP + 二进制 dtb)。

## 备份
板子原厂备份为 RKFW `update.img`(8.73G),可用 RKDevTool 一键刷回。

## 相关仓库
- armbian/build:https://github.com/armbian/build
- RK3588 BSP 内核:https://github.com/armbian/linux-rockchip(branch: rk-6.1-rkr5.1)
