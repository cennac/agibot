# AGIBOT MB0002 V2 (RK3588) Armbian 编译教程

在 **WSL2 Ubuntu** 上为 AGIBOT MB0002 V2(RK3588)编译 Armbian 固件的完整流程。本文档重点记录 **WSL2 环境的四个坑**(binfmt / fsync / 代理 / overlay 注入)及其解决方案——这些是官方文档没有、但实际会卡住你的地方。方法对其他 RK3588 板同样适用。

> 本仓库(`cennac/agibot`)即这份教程的完整产物,`git clone` 后按本文操作即可复现。

---

## 产物

| 项 | 内容 |
|----|------|
| 镜像 | `Armbian_..._Agibot_jammy_vendor_6.1.115_minimal.img`(~1.7G) |
| 内核 | 6.1.115 vendor BSP(branch `rk-6.1-rkr5.1`,NPU/GPU/MPP/编解码全功能) |
| 设备树 | `rk3588-agibot-mb0002-v2.dtb`(从原厂 5.10 fdt.dtb 适配 6.1) |
| 根文件系统 | Ubuntu 22.04 jamy minimal |
| bootloader | idbloader + u-boot SPL(镜像前 16MB,GPT 分区) |

---

## 0. 选型说明

- **框架**:armbian/build(官方构建系统,可重复、可缓存)
- **基板**:rock-5b(Armbian 对 RK3588 支持最成熟的板,AGIBOT 硬件与之高度兼容)
- **内核分支**:`vendor`(Rockchip 6.1 BSP,带 NPU/GPU/MPP;Armbian 已于 2024 年弃用 5.10 BSP,改用 6.1 vendor)
- **不用 Docker**:WSL2 里 Docker Desktop + armbian docker 模式坑更多,直接原生跑

---

## 1. 准备 WSL2 Ubuntu 22.04+

armbian/build 要求 **Ubuntu 22.04 或更新**。WSL2 自带的 20.04 不够。

```powershell
# Windows PowerShell(管理员)
wsl --install -d Ubuntu-22.04 --no-launch
wsl --set-default Ubuntu-22.04
```

资源建议:**20+ 核 CPU、16G+ RAM、60G+ 磁盘**(源码 + 工具链 + 缓存约 20G,首次编译占满 CPU 1~2 小时)。

进入 WSL 后安装基础依赖(armbian 会自动装大部分,但提前装好 git/curl/build 必备):

```bash
sudo apt update && sudo apt install -y git curl ca-certificates
```

---

## 2. ★ WSL2 四大坑(核心,先解决再编译)

### 坑 ①:binfmt_misc —— qemu 交叉编译无法注册

armbian 在 x86 上构建 arm64 rootfs,靠 qemu-user-static + binfmt_misc。但 **WSL2 的 systemd-binfmt 被 `ConditionVirtualization=!wsl` 禁用**,`update-binfmts --enable qemu-aarch64` 会失败,导致 rootfs 阶段 chroot 执行 arm64 二进制时报 `Exec format error`。

**解决(两步,都要做):**

**A. 让 systemd-binfmt 在 WSL 运行**(永久清掉那个条件):

```bash
sudo install -d /etc/systemd/system/systemd-binfmt.service.d
sudo tee /etc/systemd/system/systemd-binfmt.service.d/zzz-enable-binfmt.conf >/dev/null <<'EOF'
[Unit]
ConditionVirtualization=
EOF
# 文件名必须排在 wsl.conf 之后(zz > w),否则被覆盖
```

**B. 装 qemu-user-static + 跑本仓库的注册脚本**(WSL 还会限制 `/proc/sys/fs/binfmt_misc/register`,需挂独立 binfmt_misc):

```bash
sudo apt install -y qemu-user-static binfmt-support

# 用本仓库的脚本(挂载独立 binfmt_misc 并注册 aarch64/arm/riscv64/loongarch64)
sudo bash wsl-binfmt-setup.sh

# 验证
arch-test arm64    # 应输出 OK
ls /proc/sys/fs/binfmt_misc/qemu-aarch64   # 应存在
```

> 每次重启 WSL 后需重跑 `wsl-binfmt-setup.sh`(可放进 `~/.profile` 或 systemd)。

### 坑 ②:fsync() 卡死 —— sync 系统调用 hang

WSL2 的 `sync` 偶发不返回(脏页已为 0,但 syscall 挂起,进程进入 D 态无法 kill)。armbian 的 `wait_for_disk_sync()` 在每个磁盘写入阶段循环调用 `sync`,一旦命中就**无限卡**(日志显示 `fsync taking more than 300s...`)。

**解决:patch 掉 wait_for_disk_sync:**

```bash
cd armbian-build
cp lib/functions/host/host-utils.sh{,.orig}

# 在 wait_for_disk_sync 函数体最前面加一行 return 0
sudo sed -i '/^function wait_for_disk_sync()/a\    return 0  # WSL2 sync bug workaround' \
    lib/functions/host/host-utils.sh

# 验证
sed -n '/function wait_for_disk_sync/,/^}/p' lib/functions/host/host-utils.sh
```

> 脏页在 9p/drvfs 层已落盘,跳过 host sync 不影响产物完整性。若已出现 D-state 进程,`wsl --shutdown`(Windows 端)彻底清掉再重来。

### 坑 ③:代理 —— curl 不继承 env,pip 不能走代理

国内网络下,git/apt/ghcr 需走代理;但有两个陷阱:

1. **armbian 调用的 `curl` 子进程默认不继承代理 env**,直连 `raw.githubusercontent.com` 会偶发无限卡(curl 无 `--max-time`)。必须**显式 export 代理 env 再启动编译**。
2. **pip 走代理会 SSL 报错**(`SSL_ERROR_SYSCALL`)。`no_proxy` 必须排除 pypi。

**解决:编译时这样带代理 env**(假设代理在 Windows 的 `127.0.0.1:7897`,WSL 通过网关访问 `192.168.88.x:7897`,按你实际改):

```bash
# git 全局代理(一次性)
git config --global http.proxy http://<你的代理>:7897
git config --global https.proxy http://<你的代理>:7897

# 编译命令前 export(见第 6 节完整命令)
export http_proxy=http://<你的代理>:7897
export https_proxy=$http_proxy
export HTTP_PROXY=$http_proxy HTTPS_PROXY=$https_proxy
export no_proxy=localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,pypi.org,files.pythonhosted.org
export NO_PROXY=$no_proxy
```

> armbian 会自动从这些 env 推导 APT 代理,apt 也能走代理。

### 坑 ④(最易踩):armbian 不会自动复制 userpatches/overlay

armbian 把 `userpatches/overlay` **只读 bind-mount 到 chroot 的 `/tmp/overlay`,不会自动复制到 rootfs**。如果你的 `customize-image.sh` 不显式 `cp`,**overlay 里的所有文件(dtb/firmware/service)都不会进镜像**——而 `/etc/hostname` 是 armbian 按 BOARD_NAME 自己设的,会让人误以为 overlay 生效了。

**解决:必须有一个真正干活的 `customize-image.sh`**(见第 4 节)。

---

## 3. 获取 armbian/build

```bash
git clone --depth=1 https://github.com/armbian/build armbian-build
cd armbian-build
```

> 首次运行 `compile.sh` 时 armbian 会自动下载工具链 + 源码(~15G),需稳定网络(走代理)。

---

## 4. 配置 userpatches

本仓库的文件直接覆盖到 `armbian-build/userpatches/` 下:

```
userpatches/
├── config-agibot.conf              # 顶层编译参数
├── config/boards/agibot.conf       # 板定义
├── overlay/                        # 要注入 rootfs 的文件
│   ├── etc/hostname
│   ├── etc/systemd/system/resize-rootfs.service
│   ├── lib/firmware/               # GPU/WiFi/DP 固件
│   └── boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb
└── customize-image.sh              # ★ 注入逻辑(必须)
```

### config-agibot.conf(顶层)

```bash
BOARD=agibot
BRANCH=vendor            # Rockchip 6.1 BSP
BUILD_DESKTOP=no
BUILD_MINIMAL=yes
KERNEL_CONFIGURE=no      # 不进内核 menuconfig
COMPRESS_OUTPUTIMAGE=sha,img
RELEASE=jammy            # Ubuntu 22.04
```

### config/boards/agibot.conf(板定义)

```bash
BOARD_NAME="AGIBOT MB0002"
BOARD_VENDOR="agibot"
BOARDFAMILY="rockchip-rk3588"
BOOTCONFIG="rock-5b-rk3588_defconfig"     # 复用 rock-5b 的 u-boot defconfig
KERNEL_TARGET="vendor"
BOOT_FDT_FILE="rockchip/rk3588-agibot-mb0002-v2.dtb"   # ★ 决定 armbianEnv.txt 的 fdtfile
BOOT_SCENARIO="spl-blobs"
BOOT_SUPPORT_SPI="no"                      # ★ AGIBOT 不走 SPI,改 no 否则报 tpl/u-boot-tpl.bin 缺失
IMAGE_PARTITION_TABLE="gpt"
```

> **坑**:`BOOT_SUPPORT_SPI` 默认 yes 会触发 `tools/mkimage: Can't open tpl/u-boot-tpl.bin`。AGIBOT 用 SD/eMMC 启动,设 `no`。

### customize-image.sh(★ 注入逻辑)

这是**最关键的文件**。armbian 在 chroot 内以 `$1=RELEASE $2=LINUXFAMILY $3=BOARD $4=BUILD_DESKTOP $5=ARCH` 调用它。`/tmp/overlay` 是 host 上 `userpatches/overlay` 的只读挂载。

```bash
#!/bin/bash
set -e
OVER=/tmp/overlay

# 1) 复制 overlay 的 etc / lib 到根(hostname、resize-rootfs.service、firmware)
cp -a "$OVER"/etc/. /etc/ 2>/dev/null || true
cp -a "$OVER"/lib/. /lib/ 2>/dev/null || true

# 2) 把适配 6.1 的 agibot dtb 放进内核 dtb 目录
#    /boot/dtb 是指向 dtb-<ver>-vendor-rk35xx 的 symlink,解析真实路径后写入
DTB_REAL="$(readlink -f /boot/dtb 2>/dev/null || true)"
[ -z "$DTB_REAL" ] && DTB_REAL="$(ls -d /boot/dtb-*-vendor-rk35xx 2>/dev/null | head -1)"
if [ -n "$DTB_REAL" ] && [ -f "$OVER/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb" ]; then
    mkdir -p "$DTB_REAL/rockchip"
    cp -v "$OVER/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb" "$DTB_REAL/rockchip/"
fi

# 3) 启用首次启动 rootfs 扩容
systemctl enable resize-rootfs.service 2>/dev/null || true

# 4) 清理备份文件(不该进镜像)
find /boot -name '*.510-orig' -delete 2>/dev/null || true
exit 0
```

> 为什么不直接 `cp -a /tmp/overlay/boot/. /boot/`?因为 `/boot/dtb` 是 symlink,直接 cp 可能因 symlink 冲突漏掉 dtb。显式解析真实目录最稳。

---

## 5. dtb 5.10 → 6.1 适配

原厂 `fdt.dtb` 基于内核 5.10,直接喂给 6.1 内核会有少数 compatible 不匹配。**不需要重新写 dts**,用 `fdtput` 直接改 dtb 即可(节点/寄存器定义保持原厂准确,只改驱动绑定字符串)。

```bash
DTB=userpatches/overlay/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb
cp "$DTB" "$DTB.510-orig"    # 备份

# AV1 视频解码 IOMMU
fdtput "$DTB" /iommu@fdca0000 compatible "rockchip,iommu-av1d"

# CSI 相机 DPHY(csi2-dphy0~5)
for i in 0 1 2 3 4 5; do
    fdtput "$DTB" /csi2-dphy$i compatible "rockchip,rk3588-csi2-dphy" 2>/dev/null || true
done
```

完整改动清单见 [`ADAPT-NOTES.md`](ADAPT-NOTES.md)。其余(GPU/NPU/双网口)5.10 与 6.1 一致,无需改。

> dtc/fdtput/fdtget 由 `sudo apt install device-tree-compiler` 提供。

---

## 6. 编译

```bash
cd armbian-build

# 带代理 env(坑③)
export http_proxy=http://<你的代理>:7897
export https_proxy=$http_proxy HTTP_PROXY=$http_proxy HTTPS_PROXY=$https_proxy
export no_proxy=localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,pypi.org,files.pythonhosted.org
export NO_PROXY=$no_proxy

./compile.sh agibot EXPERT=yes
```

**预期时间(20 核):**
- 首次:下载工具链+源码 ~30min,编译内核+u-boot+rootfs ~1.5h
- 增量(kernel/u-boot/rootfs 都缓存命中):~10–20min

**产物**:`output/images/Armbian_..._Agibot_jammy_vendor_6.1.115_minimal.img`

> ⚠️ **不要用 `nohup ./compile.sh &` 后台跑**——WSL 会话退出时后台进程会被清理。要么前台跑,要么用终端复用器(tmux/screen),或保持宿主进程存活。

---

## 7. 验证镜像(无需启动板子)

镜像 rootfs 在 offset 16MB(sector 32768)。用 `debugfs` 直接读 ext4(WSL2 losetup 不可靠,debugfs 最稳):

```bash
IMG=output/images/Armbian_..._minimal.img
dd if="$IMG" of=/tmp/v.ext4 bs=1M skip=16 2>/dev/null

# ① agibot dtb 是否进了内核 dtb 目录
debugfs -R "ls boot/dtb-6.1.115-vendor-rk35xx/rockchip" /tmp/v.ext4 | grep agibot

# ② dtb 适配是否生效
debugfs -R "dump boot/dtb-6.1.115-vendor-rk35xx/rockchip/rk3588-agibot-mb0002-v2.dtb /tmp/v.dtb" /tmp/v.ext4
fdtget /tmp/v.dtb /iommu@fdca0000 compatible     # → rockchip,iommu-av1d
fdtget /tmp/v.dtb /csi2-dphy0 compatible          # → rockchip,rk3588-csi2-dphy

# ③ firmware / service / hostname / armbianEnv
debugfs -R "stat lib/firmware/mali_csffw.bin" /tmp/v.ext4 | grep Inode
debugfs -R "cat etc/systemd/system/resize-rootfs.service" /tmp/v.ext4 | head -2
debugfs -R "cat etc/hostname" /tmp/v.ext4
debugfs -R "cat boot/armbianEnv.txt" /tmp/v.ext4   # fdtfile=rockchip/rk3588-agibot-mb0002-v2.dtb
```

全部 ✓ 才算构建成功。

---

## 8. 刷机

**建议先烧 SD 卡测试**(不动原 eMMC,零风险):

1. 用 [balenaEtcher](https://etcher.balena.io/) / Rufus / `dd` 把 `.img` 写入 SD 卡
2. 插卡上电。若板子默认从 eMMC 启动,需通过 boot 选择跳线/按键切到 SD,或先擦除 eMMC 前 16MB(原厂 idbloader 所在)
3. 首次启动会自动扩容 rootfs;默认 SSH(`root`/`1234`,首次要求改密)

**板上功能验证:**
```bash
uname -r                              # 6.1.115-vendor-rk35xx
ip link                               # eth0 / eth1
lspci                                 # WiFi(14c3:0608)/USB3(VL805)
dmesg | grep -iE "mali|rknn|gpu"      # GPU / NPU
```

确认全功能后,可用 RKDevTool(Loader 模式)把镜像烧到 eMMC(有原厂 update.img 备份兜底)。

---

## 9. 故障排查

| 现象 | 原因 | 解决 |
|------|------|------|
| `Exec format error`(chroot 阶段) | binfmt 没注册 | 坑①:`wsl-binfmt-setup.sh` + systemd override |
| `fsync taking more than 300s` 卡死 | WSL2 sync hang | 坑②:patch `wait_for_disk_sync` |
| curl 卡在 fetch githubusercontent | curl 无代理 env | 坑③:`export http_proxy` 后再编译 |
| pip `SSL_ERROR_SYSCALL` | pip 走了代理 | `no_proxy` 加 pypi |
| `Can't open tpl/u-boot-tpl.bin` | SPI boot 默认开 | `BOOT_SUPPORT_SPI="no"` |
| 镜像里没有 agibot dtb/firmware | overlay 没被复制 | 坑④:写 `customize-image.sh` 显式 cp |
| `Package manager running in background` | 残留 apt/dpkg 锁 | `fuser -k` dpkg 锁;`pkill mmdebstrap` |
| 重启 WSL 后 binfmt 失效 | binfmt 非持久 | 每次启动重跑 `wsl-binfmt-setup.sh` |
| D-state 进程杀不掉 | fsync hang 残留 | Windows 端 `wsl --shutdown` |

---

## 10. 桌面版（XFCE desktop）

除 minimal 外，再编译一个带 xfce 桌面的版本。

**★ 关键：必须用 noble（24.04），不能用 jammy。** armbian 的桌面包列表（`common.yaml`）含 `pipewire-libcamera`、`gstreamer1.0-libcamera`、`glmark2-es2-x11` 等较新的包，jammy（22.04）仓库没有，安装会在 `create_new_rootfs_cache` 阶段报 `Unable to locate package` 失败。其中 camera 包在 **minimal tier（所有 tier 都装）**，所以换 tier 无用，必须换 release 到 noble。

创建 `userpatches/config-agibot-desktop.conf`：

```bash
BOARD=agibot
BRANCH=vendor
BUILD_DESKTOP=yes
BUILD_MINIMAL=no
DESKTOP_ENVIRONMENT=xfce      # 也可 gnome / kde-plasma / cinnamon / mate / i3-wm
DESKTOP_TIER=mid              # minimal (~500MB) / mid (~1GB) / full (~2.5GB)
KERNEL_CONFIGURE=no
COMPRESS_OUTPUTIMAGE=sha,img
RELEASE=noble                 # ★ 必须 noble，jammy 缺 libcamera/glmark2 包
```

编译（命名 config 机制：`./compile.sh agibot-desktop` 自动读 `config-agibot-desktop.conf`）：

```bash
./compile.sh agibot-desktop EXPERT=yes   # 同样带代理 env（坑③）
```

产物：`Armbian_..._Agibot_noble_vendor_6.1.115_xfce_desktop.img`（~5.4G）
- kernel/u-boot 缓存命中，只重跑 noble rootfs（从头 mmdebstrap）+ 装 xfce
- customize-image.sh 的 overlay 注入对桌面版同样生效（dtb/firmware/service/hostname 都进镜像）
- 首启后 lightdm 自动登录进 xfce 桌面

> 备选桌面环境（jammy+arm64 全支持）：`gnome`、`kde-plasma`、`cinnamon`、`mate`、`i3-wm`。注意 `DESKTOP_ENVIRONMENT_CONFIG_NAME` 已废弃，改用 `DESKTOP_TIER`；不存在 `lxqt`。

两版对照：

| 版本 | release | 大小 | 用途 |
|------|---------|------|------|
| minimal | jammy (22.04) | ~1.7G | 服务器 / AI 推理，无 GUI |
| desktop (xfce) | noble (24.04) | ~5.4G | 带 GUI，接显示器键鼠直接用 |

## 附:文件清单

| 文件 | 作用 |
|------|------|
| `config-agibot.conf` | 顶层编译参数 |
| `config/boards/agibot.conf` | 板定义(u-boot defconfig / fdtfile / boot) |
| `customize-image.sh` | ★ overlay 注入逻辑(必须) |
| `overlay/` | 要注入 rootfs 的 dtb/firmware/service/hostname |
| `wsl-binfmt-setup.sh` | WSL2 qemu binfmt 注册脚本 |
| `ADAPT-NOTES.md` | dtb 5.10→6.1 适配记录 |
| `BUILD-GUIDE.md` | 本文档 |
