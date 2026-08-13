# agibot

为 **AGIBOT MB0002 V2**(RK3588)打造的可复现 **Armbian** 编译 + 刷机工具链。

`git clone --recursive` → `bash setup.sh` → `bash start-build.sh` → 刷机。板级配置与 WSL2 框架 hack 已全部入库,**干净 clone 即可编译,无需手动改框架源码**;脚本自动适配 Linux / WSL2 / macOS。

> 完整步骤(WSL2 四大坑、5 处框架 hack、镜像验证、刷机、跨平台):见 **[BUILD-GUIDE.md](BUILD-GUIDE.md)**。

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
├── start-build.sh              # 编译入口:代理 / NO_HOST_RELEASE_CHECK / git resilience / 后台(跨平台)
├── config-agibot.conf          # 主编译配置(jammy minimal)
├── config-agibot-desktop.conf  # 桌面版配置(noble + xfce)
├── config-example.conf         # 示例配置
├── config/
│   └── boards/
│       └── agibot.conf         # 板定义(u-boot defconfig / fdtfile / boot)
├── customize-image.sh          # ★ overlay 注入逻辑(chroot 内执行)
├── overlay/                    # 注入 rootfs 的文件
│   ├── etc/{hostname, systemd/system/resize-rootfs.service}
│   ├── boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb   # 设备树,5.10 → 6.1 适配
│   └── lib/firmware/           # Mali / DP / RTL8821CU / BT / regulatory
├── flash/                      # eMMC 刷机工具
│   ├── rk3588_spl_loader_v1.16.113.bin   # ★ 正确的 RK3588 loader(别用 RKDevTool 自带的 MiniLoaderAll)
│   ├── gen-armbian-cfg.py      # 拆分 img → head/rootfs + 生成 config.cfg
│   ├── dump-cfg-any.py         # config.cfg 查看
│   └── README.md               # 完整刷机方案
├── wsl-binfmt-setup.sh         # WSL2 qemu binfmt 注册
├── ADAPT-NOTES.md              # 设备树 5.10 → 6.1 适配记录
├── BUILD-GUIDE.md              # ★ 完整编译教程
└── README.md
```

## 编译

支持 **Linux / WSL2 / macOS**(Linux 需 Ubuntu 22.04+ 或 Debian 12+;macOS 需 Docker Desktop)。脚本自动检测平台,差异见 [BUILD-GUIDE §11](BUILD-GUIDE.md#11-附录在-linux-原生--macos-上编译)。

```bash
# 1. Clone(含 submodule)
git clone --recursive https://github.com/cennac/agibot.git
cd agibot

# 2. 装配:init submodule +(仅 WSL2)apply 框架 hack + 装 userpatches
bash setup.sh                   # 加 --reuse-cache 可复用平级 armbian-build/cache

# 3. 编译(代理 / NO_HOST_RELEASE_CHECK / 后台日志均已内置,按平台自动适配)
bash start-build.sh
tail -f armbian-build/output/build.log
```
产物:`armbian-build/output/images/Armbian_..._Agibot_jammy_vendor_6.1.115_minimal.img`(~1.7G)

桌面版:`./compile.sh agibot-desktop`(见 [BUILD-GUIDE §10](BUILD-GUIDE.md))。

## 刷机(写入 eMMC)
见 **[flash/README.md](flash/README.md)**。要点:RKDevTool「下载镜像」页加两项执行——
- **Loader** `@0xCCCCCCCC` → `flash/rk3588_spl_loader_v1.16.113.bin`
- **image** `@0x00000000` → 整盘 `.img`(等同 `dd`,不必拆分)

⚠️ **别用 RKDevTool 自带的 `MiniLoaderAll.bin`**——多半是 RK356x loader,会报「下载 boot 失败」。用仓库里的 RK3588 loader。

## WSL2 备注
首次需注册 qemu binfmt(否则 chroot 报 `Exec format error`):
```bash
sudo bash wsl-binfmt-setup.sh      # 每次 WSL 重启后重跑
```
其余三个 WSL2 坑(fsync 卡死、代理、overlay 注入)+ 5 处框架 hack 已由 `setup.sh` / `start-build.sh` 处理,见 [BUILD-GUIDE §2](BUILD-GUIDE.md)。Linux 原生 / macOS 见 [§11](BUILD-GUIDE.md#11-附录在-linux-原生--macos-上编译)。

## 备份
板子原厂备份为 RKFW `update.img`(8.73G),可用 RKDevTool 一键刷回。

## 相关仓库
- armbian/build:https://github.com/armbian/build
- RK3588 BSP 内核:https://github.com/armbian/linux-rockchip(branch: rk-6.1-rkr5.1)
