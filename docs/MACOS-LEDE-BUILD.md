# macOS 本机编译 LEDE/OpenWrt 记录

本文记录在 macOS 上为 AGIBOT MB0002 V2 编译 `openwrt/` 下 LEDE 固件的步骤。此路线不使用 Docker,依赖 Homebrew 提供 GNU 工具链。

## 1. 前置要求

- macOS 主机,建议 Apple Silicon 也使用原生 arm64 Homebrew(`/opt/homebrew`)。
- 仓库所在卷必须大小写敏感。OpenWrt/LEDE 源码和 package 名称可能只靠大小写区分,APFS 默认大小写不敏感时容易失败。
- 需要能访问 GitHub。首次会拉 `openwrt/lede` submodule、feeds 和源码包。
- 建议预留 50 GB 以上空间。

## 2. 安装 Homebrew 依赖

```bash
brew install bash coreutils diffutils findutils gawk gpatch gnu-getopt gnu-sed grep gnu-tar \
  make ncurses openssl@3 perl python@3.12 rsync unzip wget xz zstd gettext pkgconf swig
```

这些包的 GNU 版本不会默认全部覆盖 macOS 系统工具,编译脚本会自动把 Homebrew 的 `gnubin`/`bin` 目录放到 `PATH` 前面,并使用 `gmake`。

U-Boot `binman` 还需要 Python 模块 `pyelftools`。`macos-lede-build.sh` 会把它安装到 `openwrt/.tmp/python-site` 并通过 `PYTHONPATH` 使用,不修改 macOS 系统 Python、Homebrew Python 或 uv 管理的 Python。

## 3. 代理

如果 GitHub 直连不稳定,先在当前 shell 里显式设置代理:

```bash
export http_proxy=http://127.0.0.1:7897
export https_proxy=$http_proxy
export HTTP_PROXY=$http_proxy
export HTTPS_PROXY=$https_proxy
export no_proxy=localhost,127.0.0.1,::1
export NO_PROXY=$no_proxy
```

`openwrt/setup-openwrt.sh` 和 `openwrt/macos-lede-build.sh` 会继承这些变量;如果未设置且本机 `127.0.0.1:7897` 可达,脚本会自动使用它。

Go 模块下载建议使用国内代理。`macos-lede-build.sh` 默认设置:

```bash
export GOPROXY="${GOPROXY:-https://goproxy.cn,direct}"
```

如需改用公司内网或自建代理,在运行脚本前自行覆盖 `GOPROXY` 即可。

## 4. 编译

从仓库根执行:

```bash
cd openwrt
bash macos-lede-build.sh
```

快速验证 DTS/内核目标:

```bash
cd openwrt
bash macos-lede-build.sh target/linux/compile
```

限制并发:

```bash
cd openwrt
JOBS=6 bash macos-lede-build.sh
```

脚本内部流程:

1. 检查 Homebrew 依赖和大小写敏感文件系统。
2. 调用 `setup-openwrt.sh` 初始化 `openwrt/lede` submodule、应用 `openwrt/patches/`、复制 AGIBOT DTS、更新 feeds、生成 `.config`。
3. `helloworld-srclink.sh` 下载 `fw876/helloworld` tarball 到 `openwrt/.tmp/helloworld-feed`,用 `src-link` 补齐 passwall 核心包。
4. 进入 `openwrt/lede` 执行 `gmake -j$(sysctl -n hw.ncpu) V=s`。

产物位置:

```text
openwrt/lede/bin/targets/rockchip/armv8/*agibot*sysupgrade.img.gz
```

## 5. 大小写敏感编译盘

如果仓库在 macOS 默认大小写不敏感 APFS 卷上,脚本会直接退出。可创建一个 sparsebundle 编译盘:

```bash
cd /Volumes/MacData/Codes/agibot
hdiutil create -size 80g -type SPARSEBUNDLE -fs 'Case-sensitive APFS' \
  -volname AGIBOT_LEDE _macos-lede-build.sparsebundle
hdiutil attach _macos-lede-build.sparsebundle
rsync -a --delete --exclude _macos-lede-build.sparsebundle ./ /Volumes/AGIBOT_LEDE/agibot/
cd /Volumes/AGIBOT_LEDE/agibot/openwrt
bash macos-lede-build.sh
```

`_macos-lede-build.sparsebundle` 位于仓库根且匹配现有 `/_*` ignore 规则,不会进入 Git。

## 6. 本机执行记录

时间:2026-08-18  
主机:macOS Darwin 25.6.0 arm64  
Docker:未用于编译;误启动的 Docker 构建已中止。

已执行:

```bash
brew install bash coreutils diffutils findutils gawk gpatch gnu-getopt gnu-sed grep gnu-tar \
  make ncurses openssl@3 perl python@3.12 rsync unzip wget xz zstd gettext pkgconf swig
hdiutil create -size 80g -type SPARSEBUNDLE -fs 'Case-sensitive APFS' \
  -volname AGIBOT_LEDE _macos-lede-build.sparsebundle
hdiutil attach _macos-lede-build.sparsebundle
rsync -a --delete --exclude _macos-lede-build.sparsebundle ./ /Volumes/AGIBOT_LEDE/agibot/
cd /Volumes/AGIBOT_LEDE/agibot/openwrt
bash macos-lede-build.sh
```

本次全量续编使用的核心环境:

```bash
cd /Volumes/AGIBOT_LEDE/agibot/openwrt/lede
env GOPROXY=https://goproxy.cn,direct \
  PYTHONPATH=/Volumes/AGIBOT_LEDE/agibot/openwrt/.tmp/python-site \
  PATH=/opt/homebrew/bin:/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/opt/findutils/libexec/gnubin:/opt/homebrew/opt/gawk/libexec/gnubin:/opt/homebrew/opt/gpatch/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/opt/gnu-sed/libexec/gnubin:/opt/homebrew/opt/grep/libexec/gnubin:/opt/homebrew/opt/gnu-tar/libexec/gnubin:/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gettext/bin:/opt/homebrew/opt/ncurses/bin:/opt/homebrew/opt/openssl@3/bin:/opt/homebrew/opt/python@3.12/libexec/bin:/opt/homebrew/opt/unzip/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  gmake -j10 V=s
```

本次纯 macOS 原生全量编译已完成,产物生成于:

```text
/Volumes/AGIBOT_LEDE/agibot/openwrt/lede/bin/targets/rockchip/armv8/
```

关键产物:

```text
openwrt-rockchip-armv8-agibot_mb0002-v2-squashfs-sysupgrade.img.gz  123M
openwrt-rockchip-armv8-agibot_mb0002-v2-ext4-sysupgrade.img.gz      158M
openwrt-rockchip-armv8-agibot_mb0002-v2.manifest                    11K
sha256sums                                                           706B
```

manifest 核验:

- 已包含 `docker`、`dockerd`、`docker-compose`、`luci-app-dockerman`。
- 已包含 `smartdns`、`luci-app-smartdns`。
- 未包含 `netdata`、`luci-app-netdata`。

已通过:

- `openwrt/lede` submodule checkout 到 `8882f211bb19277d37685456f622caed95e102bd`。
- AGIBOT 三个补丁已 apply。
- `packages` / `luci` / `routing` / `telephony` feeds 已 update。
- `helloworld-srclink.sh` 已改为跨平台,macOS 下下载到 `openwrt/.tmp/helloworld-feed`。
- AGIBOT 设备定义已设为 `DEVICE_TYPE := basic`,避免 LEDE `DEFAULT_PACKAGES.router` 默认拉入 `luci-app-ssr-plus`。
- `helloworld-srclink.sh` 核验逻辑已按 feed 基础包目录检查;`shadowsocks-rust` 的 `sslocal/ssserver` 是 Makefile 动态生成的子包。
- `package/boot/uboot-rockchip` 已通过 macOS 本机编译,`generic-rk3588-idbloader.img` 和 `generic-rk3588-u-boot.itb` 已安装到 staging image 目录。
- `golang` host 编译已通过 macOS 本机编译。`feed-patches/001-golang-darwin-external-linker.patch` 仅在 Darwin 的 Go 1.17/1.20 bootstrap 阶段注入 `GO_LDFLAGS="-linkmode external"`,修复 bootstrap 二进制缺少 `LC_UUID` 导致的 `dyld` 启动失败。
- `docker` / `dockerd` / `containerd` 已通过 macOS 本机交叉编译。`feed-patches/002-docker-darwin-gnu-date.patch` 修复 Docker CLI 构建脚本在 Darwin 下遇到 GNU `date` 时仍调用 `date -jf` 的问题。
- `smartdns` 主包和 Web UI 源码已在 macOS 本机重试后下载并编译通过。
- `netdata` 默认已关闭。它只是监控扩展,不是 AGIBOT 基础固件必需项;本次 macOS 原生构建中 `netdata-v1.33.1.tar.gz` 下载长期卡住,为保证全量固件可复现产出,默认配置改为不选 `luci-app-netdata` / `netdata`。如需启用,在 `openwrt/config-agibot-openwrt` 中重新打开后再编译。

已修复的阻断:

```text
Build dependency: Please install GNU 'patch'
```

解决:安装 Homebrew `gpatch`,并把 `/opt/homebrew/opt/gpatch/libexec/gnubin` 加到脚本 PATH。

```text
error: command 'swig' failed: No such file or directory
```

触发点:`package/boot/uboot-rockchip` 构建 `u-boot-2026.07` 时生成 `scripts/dtc/pylibfdt`。  
解决:安装 Homebrew `swig`,并把 Homebrew `bin` 加到脚本 PATH。

```text
Undefined symbols for architecture arm64: _PyArg_UnpackTuple ...
```

触发点:`u-boot-2026.07` 构建 `scripts/dtc/pylibfdt/_libfdt.so`。  
解决:补丁 `007-uboot-rockchip-pylibfdt-python3-api.patch` 在 macOS 下把 U-Boot 的 `LDSHARED` 改为 `-bundle -undefined dynamic_lookup`,并把旧 Python 2 C API 替换为 Python 3 API。

```text
binman: Failed to read ELF file: Python: No module named 'elftools'
```

触发点:`u-boot-2026.07` 的 `BINMAN .binman_stamp` 阶段。  
解决:把 `pyelftools` 安装到 `openwrt/.tmp/python-site`,并导出 `PYTHONPATH`。脚本已自动处理:

```bash
python3 -m pip install --target openwrt/.tmp/python-site pyelftools
export PYTHONPATH="$PWD/openwrt/.tmp/python-site${PYTHONPATH:+:$PYTHONPATH}"
```

重新执行:

```bash
cd /Volumes/AGIBOT_LEDE/agibot/openwrt
bash macos-lede-build.sh
```

```text
go1.17.13: dyld: missing LC_UUID load command
```

触发点:feeds `golang` package 在 Darwin host 上执行 bootstrap Go 二进制。  
解决:`feed-patches/001-golang-darwin-external-linker.patch` 只对 Go 1.17/1.20 bootstrap 阶段启用 external linker,保留后续 Go 1.22/1.24/final 阶段的默认链接方式。

```text
date: invalid option -- 'j'
```

触发点:`feeds/packages/utils/docker` 构建 Docker CLI `.variables`。  
原因:macOS 原生构建为了 OpenWrt 优先使用 GNU 工具,`date` 实际来自 Homebrew coreutils,而 Docker CLI 的 Darwin 分支假设是 BSD `date -jf`。  
解决:`feed-patches/002-docker-darwin-gnu-date.patch` 增加 Docker CLI 源码内补丁,在 GNU `date` 可用时改用 `date -d`。

```text
curl: (28) SSL connection timeout
```

触发点:源码包下载阶段。  
解决:通常为临时网络问题,OpenWrt `download.pl` 会重试;Go 模块下载使用 `GOPROXY=https://goproxy.cn,direct` 后已通过 `v2ray-plugin`、`xray-core`、`geoview` 等包。

```text
netdata-v1.33.1.tar.gz 下载长期停滞
```

触发点:`luci-app-netdata` 依赖 `netdata` 源码包。  
解决:默认配置关闭 `luci-app-netdata` / `netdata`,保留 `luci-app-nlbwmon`、`luci-app-statistics` 等轻量监控组件。需要 netdata 时可单独打开并重试下载/编译。
