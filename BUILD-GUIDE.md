# AGIBOT MB0002 V2 (RK3588) Armbian 编译教程

在 **WSL2 Ubuntu** 上为 AGIBOT MB0002 V2(RK3588)编译 Armbian 固件的完整流程。本文档重点记录 **WSL2 环境的四个坑**(binfmt / fsync / 代理 / overlay 注入)及其解决方案——这些是官方文档没有、但实际会卡住你的地方。方法对其他 RK3588 板同样适用。

> 本仓库(`cennac/agibot`)即这份教程的完整产物。本文以 **WSL2** 为主线(坑最多);`setup.sh` / `start-build.sh` 已自动适配 **Linux 原生 / macOS**(见 [§11](#11-附录在-linux-原生--macos-上编译))。流程:`git clone --recursive` → `bash setup.sh` → `bash start-build.sh`。

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

进入 WSL 后安装编译依赖。本仓库有一键脚本(跨平台,装 git/curl/build-essential/qemu-user-static/binfmt-support/device-tree-compiler,并注册 binfmt + systemd override —— 即下文坑①的两步一次性做完):

```bash
bash scripts/install-deps.sh      # 跨平台;每台机器跑一次即可
```

> 不想用脚本也可手动 `sudo apt install -y git curl ca-certificates`,但 binfmt(坑①)还得单独配。

---

## 2. ★ WSL2 四大坑(核心,先解决再编译)

> **★ 框架预处理(5 处 hack,已固化为 patch)**
>
> 除下面四个环境坑外,armbian/build 框架源码本身在 WSL2 + 9p + 代理下还有 **5 处必须改**,否则编到中途必挂(均为实战踩过的失败点):
>
> | # | 文件 | 问题 | 改法 |
> |---|------|------|------|
> | 1 | `host/host-utils.sh` | `wait_for_disk_sync()` 调 sync 命中 WSL2 hang,D-state 卡死(即坑②) | 函数直接 `return 0` |
> | 2 | `general/git.sh` | git clone 大仓库(kernel)经代理偶发 SHA1/EOF | 失败重试 + 放宽超时 |
> | 3 | `rootfs/rootfs-create.sh` | mmdebstrap 默认源在 WSL 偶发 403 | 切 salsa.debian.org |
> | 4 | `rootfs/distro-specific.sh` | apt 在 9p 上 `fchmod` 报 EPERM 中断 | 绕过该 fchmod |
> | 5 | `rootfs/apt-install.sh` | 9p 的 fchmod 告警刷屏干扰日志 | 告警降级 |
>
> 这 5 处已打成 **`patches/wsl2-build-hacks.patch`**(基于 submodule 锁定的 commit `70a242f`)。**不用手改**——`bash setup.sh`(第 3 节)自动 `git apply`。仅脱离 setup.sh 手工装配时才需:
> ```bash
> cd armbian-build && git apply ../patches/wsl2-build-hacks.patch
> ```

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

**解决:patch 掉 wait_for_disk_sync** ★ 此步即框架预处理 #1,已含在 `patches/wsl2-build-hacks.patch`,`bash setup.sh` 自动 apply。下面 sed 仅供理解原理 / 脱离 setup.sh 手工装配时参考:

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

## 3. 装配仓库(submodule + patch + userpatches)

本仓库已把 armbian/build 纳为 **git submodule**(锁定 commit `70a242f`),5 处框架 hack 打成 patch,板级配置放仓库根。一条命令装配:

```bash
# 在编译主机(WSL/Linux/macOS),仓库根(cennac/agibot, 即本目录)
bash setup.sh
```

`setup.sh` 做三件事(**幂等**,可重复跑,见 [`setup.sh`](setup.sh)):
1. `git submodule update --init --recursive armbian-build` —— 拉官方 armbian/build @ 70a242f(首次约 15G 源码+工具链,走代理)
2. `git apply patches/wsl2-build-hacks.patch` —— 打 5 处 WSL2 框架 hack(见 §2 框架预处理;先 `git checkout -- .` 重置再 apply,保证可重复)
3. 把 `config-*.conf` / `config/` / `customize-image.sh` / `overlay/` 装进 `armbian-build/userpatches/`

> 首次装配下载耗时长。若平级目录有旧副本 `../armbian-build/cache`,`bash setup.sh --reuse-cache` 可复用约 15G 缓存省下载。
>
> 装完即可跳到 [第 6 节](#6-编译)编译。userpatches 的具体内容见第 4 节(原理说明,setup.sh 已自动装好)。

---

## 4. 配置 userpatches(原理;setup.sh 已自动装配)

> `bash setup.sh`(§3)已把下列文件自动装进 `armbian-build/userpatches/`。本节仅说明各文件作用,正常编译无需手动操作。

本仓库根的这些文件,对应装进 `armbian-build/userpatches/` 下:

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

> `start-build.sh` 按平台自动适配(WSL2 / Linux / macOS,差异见 [§11](#11-附录在-linux-原生--macos-上编译))。

装配完(§3)直接跑编译入口脚本——已内置代理 / `NO_HOST_RELEASE_CHECK` / git resilience / 后台日志,**不用手 export 任何 env**:

```bash
# 仓库根
bash start-build.sh
# 跟踪日志(另开终端)
tail -f armbian-build/output/build.log
# 或用仓库脚本:去色 + 进程 + images/ 产物 + kernel clone 进度,一步到位
bash scripts/build-status.sh
```

`start-build.sh` 替你做了(见 [`start-build.sh`](start-build.sh)):
- **代理 env**:自动探测 WSL 网关 → `http://<网关>:7897`(Clash Verge mixed-port);`no_proxy` 排除 `github.armbian.com`(该域直连 200、走代理 502)及国内镜像
- **`NO_HOST_RELEASE_CHECK=yes`**:WSL Ubuntu 实为 noble(24.04,armbian 支持),但框架的 host-release gate 会误拦,显式跳过
- **git resilience**:`http.lowSpeedLimit=0` / `postBuffer=1G` / `HTTP/1.1`,避免大 kernel clone 经代理时 TLS 中断(配合框架预处理 #2)
- **`setsid` 后台 + `output/build.log`**:脱离 WSL 会话,关终端不被清理

**预期时间(20 核):**
- 首次:下载工具链+源码 ~30min,编译内核+u-boot+rootfs ~1.5h
- 增量(kernel/u-boot/rootfs 缓存命中):~10–20min

**产物**:`armbian-build/output/images/Armbian_..._Agibot_jammy_vendor_6.1.115_minimal.img`

> 桌面版见 [第 10 节](#10-桌面版xfce-desktop);编译中途的 5 类失败见 §2 框架预处理 + §9 故障排查。

---

## 7. 验证镜像(无需启动板子)

> ★ 已脚本化:`bash scripts/verify-image.sh` 一键跑完下面全部检查(自动找最新 img,打印 OK/FAIL 汇总)。下面是手动原理,排查具体问题时用。

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

### 先烧 SD 卡测试(零风险,不动 eMMC)

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

> 仓库回归脚本,刷完跑全套:**`flash/postflash-test.sh`**(CAN/UART/GPIO/watchdog/NPU/温度,非破坏性,日志写 `/var/log`)和 **`flash/npu_test.py`**(RKNN resnet18 smoke + FPS 采样)。用法见 [flash/README.md](flash/README.md)。

### 写入 eMMC

SD 卡上功能正常后,把镜像烧进板载 eMMC。**完整方案见 [`flash/README.md`](flash/README.md)**,要点:

- **主推:整盘写**。RKDevTool「下载镜像」页加两项 —— Loader `@0xCCCCCCCC`(用本仓库 `flash/rk3588_spl_loader_v1.16.113.bin`)+ 整盘 img `@0x00000000`,一次执行。等同整盘 dd,**不必拆分**。
- **备选:拆分写**(整盘单文件写报错时)。`python flash/gen-armbian-cfg.py` 自动从 img 拆 head/rootfs + 生成 config.cfg,导入 RKDevTool。
- ⚠️ **必须用正确的 RK3588 loader**(`flash/rk3588_spl_loader_v1.16.113.bin`,SHA256 `4cc43c2f...`)。**别用 RKDevTool 自带的 `MiniLoaderAll.bin`**——多为 RK356x,会报「下载 boot 失败 / Sent(0)」,这是刷不动的头号原因(不是 USB 线)。
- 刷 eMMC 前确保有原厂 update.img 备份兜底。

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
| git clone kernel 报 SHA1 / EOF 中断 | 代理 TLS 握手丢包 | 框架预处理 #2(patch)+ start-build.sh git resilience |
| mmdebstrap 源 403 / 下载失败 | WSL 里默认 debian 源不稳 | 框架预处理 #3(patch,切 salsa) |
| apt 阶段 `Operation not permitted`(fchmod) | 9p 不支持 fchmod | 框架预处理 #4(patch,绕过) |
| `github.armbian.com` 502 | 该域走代理会 502 | `no_proxy` 含 github.armbian.com(start-build.sh 已带) |
| host release gate 拦截 / `Unsupported host` | 框架误判 WSL noble | `NO_HOST_RELEASE_CHECK=yes`(start-build.sh 已带) |

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

## 11. 附录:在 Linux 原生 / macOS 上编译

`setup.sh` / `start-build.sh` 已自动检测平台(`uname` + `/proc/version`),三平台都能跑。与 WSL2 主线(§1–§10)的差异:

| | WSL2(主线) | Linux 原生 | macOS |
|---|---|---|---|
| 框架 hack patch | apply 5 处(§2) | **不 apply**(ext4 正常,fchmod hack 有害) | **不 apply** |
| binfmt(qemu) | `wsl-binfmt-setup.sh`(坑①) | `apt install qemu-user-static` + `systemctl restart systemd-binfmt` | 不需要(Docker 内) |
| Docker | `PREFER_DOCKER=no` | `PREFER_DOCKER=no` | **`PREFER_DOCKER=yes`**(macOS 无 binfmt) |
| 代理 | 自动走 Windows 网关 7897 | 继承 `http_proxy` 或检测本地 7897(脚本自动) | 同 Linux |
| 后台 | `setsid` | `setsid` | `nohup`(脚本自动回退) |
| 路径定位 | `readlink -f` | `readlink -f` | POSIX `cd`+`pwd`(脚本已兼容) |

### Linux 原生(Ubuntu 22.04+ / Debian 12+)
```bash
sudo apt install -y git curl ca-certificates qemu-user-static binfmt-support
sudo systemctl restart systemd-binfmt      # 注册 qemu-aarch64(start-build.sh 会预检)
bash setup.sh                               # 自动跳过 WSL patch
bash start-build.sh                         # 代理:先 export http_proxy=... 或脚本检测本地 7897
```
> 若脚本检测不到 `http_proxy` 也没本地 7897,会直连(国内下 kernel 慢,建议 `export http_proxy=http://127.0.0.1:7897` 后再跑)。

### macOS
- **必须装 Docker Desktop 并启动**——交叉编译 arm64 rootfs 靠 Docker 内的 qemu,macOS 本机跑不了 binfmt。`start-build.sh` 检测不到 Docker 会直接退出提示。
- 仓库若放在**大小写不敏感**的卷(APFS 默认),部分内核源码可能冲突;建议放 case-sensitive 卷或 Docker volume。
```bash
bash setup.sh                                # 自动跳过 WSL patch
bash start-build.sh                          # 自动设 PREFER_DOCKER=yes
```
> macOS 首次编译在 Docker 内进行,拉镜像 + 工具链较慢。

### 三平台共用
产物路径 `armbian-build/output/images/`、刷机(`flash/`,§8)、镜像验证(§7)三平台完全一致。`setup.sh --reuse-cache` 也都可用(复用平级 `armbian-build/cache`)。

---

## 附:文件清单

| 文件 | 作用 |
|------|------|
| `config-agibot.conf` | 顶层编译参数 |
| `config/boards/agibot.conf` | 板定义(u-boot defconfig / fdtfile / boot) |
| `customize-image.sh` | ★ overlay 注入逻辑(必须) |
| `overlay/` | 要注入 rootfs 的 dtb/firmware/service/hostname |
| `wsl-binfmt-setup.sh` | WSL2 qemu binfmt 注册脚本 |
| `ADAPT-NOTES.md` | dtb 5.10→6.1 适配记录 |
| `.gitmodules` + `armbian-build/` | armbian/build 官方框架(submodule @ 70a242f) |
| `patches/wsl2-build-hacks.patch` | ★ 5 处 WSL2 框架 hack(§2) |
| `setup.sh` | ★ 装配自动化:init submodule + apply patch + 装 userpatches(§3) |
| `start-build.sh` | ★ 编译入口:代理 / NO_HOST_RELEASE_CHECK / git resilience / 后台(§6) |
| `flash/` | 刷机:loader + gen-armbian-cfg.py + dump-cfg-any.py + postflash-test + npu_test + README(§8) |
| `scripts/` | 辅助脚本:install-deps / preflight / build-status / verify-image(见 [scripts/README.md](scripts/README.md)) |
| `BUILD-GUIDE.md` | 本文档 |
