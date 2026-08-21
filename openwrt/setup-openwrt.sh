#!/usr/bin/env bash
# setup-openwrt.sh — 把 cennac/agibot 的 openwrt/ 树装配成可编译的 LEDE 工作区。
#
# 做五件事:
#   1. 初始化 openwrt/lede submodule(coolsnowwolf/lede)
#   2. 重置 lede 树到干净状态(幂等,支持反复 apply)
#   3. apply 设备定义补丁(armv8.mk + uboot-rockchip)+ 安装板级 DTS
#   4. 准备 helloworld src-link feed + feeds update/install(补 passwall 核心包),并应用 feed 补丁
#   5. cp .config 种子 → make defconfig 补全依赖
#
# 之后 `cd lede && make -j$(nproc)` / `gmake -j$(sysctl -n hw.ncpu)` 或脚本编译。
#
# 跨平台:WSL2 / Linux 原生 / macOS / Docker 容器。容器内(/.dockerenv)按 linux,
# 代理走继承(docker-lede-build.sh 经 host.docker.internal 注入),不自动探测。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEDE="lede"
DTS_REL="target/linux/rockchip/files/arch/arm64/boot/dts/rockchip"
ROOTFS_FILES_REL="files"
RKNPU_PACKAGE_REL="package/kernel/rknpu"
AP6275P_FIRMWARE_PACKAGE_REL="package/firmware/ap6275p-firmware"
AGIBOT_BT_ATTACH_PACKAGE_REL="package/agibot/agibot-bt-attach"
RKNN_RUNTIME_PACKAGE_REL="package/agibot/rknn-runtime"
GCOMPAT_PACKAGE_REL="package/libs/gcompat"
ACM8625P_KERNEL_PATCH_REL="target/linux/rockchip/patches-6.12/0120-asoc-add-acm8625p-amplifier.patch"

# ---- 平台检测 ----
detect_platform() {
	[ -f /.dockerenv ] && { echo linux; return; }
	case "$(uname -s)" in
		Linux*)  grep -qi microsoft /proc/version 2>/dev/null && echo wsl || echo linux ;;
		Darwin*) echo macos ;;
		*)       echo unknown ;;
	esac
}
PLATFORM="${PLATFORM:-$(detect_platform)}"
echo ">>> 平台: $PLATFORM"

# ---- macOS:优先使用 Homebrew GNU 工具 ----
setup_macos_path() {
	[ "$PLATFORM" = macos ] || return 0
	local brew_prefix
	brew_prefix="$(brew --prefix 2>/dev/null || true)"
	[ -n "$brew_prefix" ] || return 0
	for d in \
		"$brew_prefix/bin" \
		"$brew_prefix/opt/coreutils/libexec/gnubin" \
		"$brew_prefix/opt/findutils/libexec/gnubin" \
		"$brew_prefix/opt/gawk/libexec/gnubin" \
		"$brew_prefix/opt/gpatch/libexec/gnubin" \
		"$brew_prefix/opt/gnu-getopt/bin" \
		"$brew_prefix/opt/gnu-sed/libexec/gnubin" \
		"$brew_prefix/opt/grep/libexec/gnubin" \
		"$brew_prefix/opt/gnu-tar/libexec/gnubin" \
		"$brew_prefix/opt/make/libexec/gnubin" \
		"$brew_prefix/opt/gettext/bin" \
		"$brew_prefix/opt/ncurses/bin" \
		"$brew_prefix/opt/openssl@3/bin" \
		"$brew_prefix/opt/python@3.12/libexec/bin" \
		"$brew_prefix/opt/unzip/bin"; do
		[ -d "$d" ] && PATH="$d:$PATH"
	done
	export PATH
}
setup_macos_path

if [ "$PLATFORM" = macos ]; then
	MAKE_BIN="${MAKE_BIN:-gmake}"
else
	MAKE_BIN="${MAKE_BIN:-make}"
fi
export MAKE_BIN

# ---- 代理(feeds update 要从 github clone coolsnowwolf feeds)----
setup_proxy() {
	if [ "$PLATFORM" = wsl ]; then
		GW=$(ip route show default | awk '{print $3; exit}')
		export http_proxy="http://${GW}:7897" https_proxy="http://${GW}:7897"
		export no_proxy="localhost,127.0.0.1,::1"
		echo ">>> proxy: WSL 网关 ${GW}:7897"
	elif [ "$PLATFORM" = macos ] && [ -z "${http_proxy:-}" ] && curl -s --max-time 1 -o /dev/null http://127.0.0.1:7897 2>/dev/null; then
		export http_proxy="http://127.0.0.1:7897" https_proxy="http://127.0.0.1:7897"
		export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"
		export no_proxy="localhost,127.0.0.1,::1"
		export NO_PROXY="$no_proxy"
		echo ">>> proxy: macOS 检测到本地 127.0.0.1:7897"
	elif [ -n "${http_proxy:-}" ]; then
		echo ">>> proxy: 继承 http_proxy=$http_proxy"
	else
		echo ">>> proxy: 无(feeds update 若慢,export http_proxy=... 后重跑)"
	fi
}

# 0. 依赖自检
command -v git >/dev/null 2>&1 || { echo "[!] 缺 git"; exit 1; }
if [ "$PLATFORM" = macos ]; then
	command -v brew >/dev/null 2>&1 || { echo "[!] macOS 原生编译需要 Homebrew"; exit 1; }
	command -v "$MAKE_BIN" >/dev/null 2>&1 || {
		echo "[!] 缺 $MAKE_BIN。先安装 macOS 原生依赖:"
		echo "    brew install bash coreutils diffutils findutils gawk gpatch gnu-getopt gnu-sed grep gnu-tar make ncurses openssl@3 perl python@3.12 rsync unzip wget xz zstd gettext pkgconf swig"
		exit 1
	}
	CASE_TEST_DIR="$SCRIPT_DIR/.case-sensitive-test"
	rm -rf "$CASE_TEST_DIR"
	mkdir -p "$CASE_TEST_DIR"
	touch "$CASE_TEST_DIR/a"
	if [ -e "$CASE_TEST_DIR/A" ]; then
		rm -rf "$CASE_TEST_DIR"
		echo "[!] 当前目录所在文件系统大小写不敏感,OpenWrt/LEDE 原生编译容易失败。"
		echo "    建议把仓库放到大小写敏感 APFS 卷或 sparsebundle 后重试。"
		exit 1
	fi
	rm -rf "$CASE_TEST_DIR"
fi

# 1. 初始化 submodule(注意 .git 是文件指针,用 -e)
if [ ! -e "$LEDE/.git" ]; then
	if [ ! -f "$REPO_ROOT/.gitmodules" ]; then
		echo "[!] 未找到 $REPO_ROOT/.gitmodules —— 先在仓库根执行:"
		echo "    git submodule add https://github.com/coolsnowwolf/lede openwrt/lede"
		exit 1
	fi
	echo ">>> [1/5] 初始化 submodule $LEDE(首次 clone,约 600M)..."
	git -C "$REPO_ROOT" submodule update --init "$SCRIPT_DIR/$LEDE"
else
	echo ">>> [1/5] submodule $LEDE 已存在,跳过 init"
fi

# 2. 重置 lede 树到干净状态(支持反复 apply)
echo ">>> [2/5] 重置 lede 树到干净状态..."
git -C "$LEDE" checkout -- .
# 清掉可能残留的 DTS(下次 cp 重装)
rm -f "$LEDE/$DTS_REL/rk3588-agibot-mb0002-v2.dts"
# 清掉本项目安装的 rootfs overlay 文件(下次 cp 重装)
rm -f "$LEDE/$ROOTFS_FILES_REL/etc/inittab"
rm -f "$LEDE/$ROOTFS_FILES_REL/usr/sbin/agibot-usb-hub-reset"
rm -f "$LEDE/$ROOTFS_FILES_REL/usr/sbin/agibot-usb-port-power"
rm -f "$LEDE/$ROOTFS_FILES_REL/etc/init.d/agibot-usb"
rm -f "$LEDE/$ROOTFS_FILES_REL/lib/firmware/arm/mali/arch10.8/mali_csffw.bin"
rm -f "$LEDE/$ROOTFS_FILES_REL/lib/firmware/acm8625p_dsp_stereo_btl_48khz.bin"
rm -rf "$LEDE/$RKNPU_PACKAGE_REL"
# checkout 不会清补丁 007 新增的未跟踪文件;保留 build 输出,只移除这个已知残留
rm -f "$LEDE/package/boot/uboot-rockchip/patches/112-pylibfdt-python3-api.patch"
rm -f "$LEDE/package/boot/uboot-rockchip/patches/211-agibot-rk3588-sw9200-loader.patch"
rm -f "$LEDE/target/linux/rockchip/patches-6.12/0091-agibot-stmmac-dma-debug.patch"
rm -f "$LEDE/target/linux/rockchip/patches-6.12/0100-agibot-rk806-pmic-reset-func.patch"
rm -f "$LEDE/target/linux/rockchip/patches-6.12/0110-agibot-rockchip-canfd-rk3588.patch"
rm -f "$LEDE/target/linux/rockchip/patches-6.12/0141-brcmfmac-optional-firmware-nowarn.patch"
rm -rf "$LEDE/$AP6275P_FIRMWARE_PACKAGE_REL"
rm -rf "$LEDE/$AGIBOT_BT_ATTACH_PACKAGE_REL"
rm -rf "$LEDE/$RKNN_RUNTIME_PACKAGE_REL"
rm -rf "$LEDE/$GCOMPAT_PACKAGE_REL"
rm -f "$LEDE/$ACM8625P_KERNEL_PATCH_REL"

# 3. apply 补丁 + 安装 DTS
echo ">>> [3/5] apply 设备定义补丁 + 安装板级 DTS..."
shopt -s nullglob
for p in patches/*.patch; do
	# These two patches were macOS-host workarounds. LEDE master has since
	# rearranged tools/Makefile, while all supported builds now run on 66.
	case "$(basename "$p")" in
	004-tools-skip-elfutils-host-on-darwin.patch|\
	006-tools-skip-coreutils-host-on-darwin.patch)
		echo "    skip Darwin-only patch $(basename "$p")"
		continue
		;;
	esac
	echo "    apply $(basename "$p")"
	git -C "$LEDE" apply --ignore-whitespace "$SCRIPT_DIR/$p"
done
for p in uboot-patches/*.patch; do
	echo "    install U-Boot patch $(basename "$p")"
	cp "$p" "$LEDE/package/boot/uboot-rockchip/patches/"
done
# target modules.mk is not part of package/kernel/linux Makefile's metadata
# dependencies, so invalidate its cached dump after changing module KCONFIG.
rm -f "$LEDE/tmp/info/.packageinfo-kernel_linux"
mkdir -p "$LEDE/$DTS_REL"
cp "files/arch/arm64/boot/dts/rockchip/rk3588-agibot-mb0002-v2.dts" "$LEDE/$DTS_REL/"
mkdir -p "$LEDE/$ROOTFS_FILES_REL/etc"
install -m 0644 "files/etc/inittab" "$LEDE/$ROOTFS_FILES_REL/etc/inittab"
install -d "$LEDE/$ROOTFS_FILES_REL/usr/sbin" "$LEDE/$ROOTFS_FILES_REL/etc/init.d"
install -m 0755 "files/usr/sbin/agibot-usb-hub-reset" "$LEDE/$ROOTFS_FILES_REL/usr/sbin/agibot-usb-hub-reset"
install -m 0755 "files/usr/sbin/agibot-usb-port-power" "$LEDE/$ROOTFS_FILES_REL/usr/sbin/agibot-usb-port-power"
install -m 0755 "files/etc/init.d/agibot-usb" "$LEDE/$ROOTFS_FILES_REL/etc/init.d/agibot-usb"
install -d "$LEDE/$ROOTFS_FILES_REL/lib/firmware/arm/mali/arch10.8"
install -m 0644 "files/lib/firmware/arm/mali/arch10.8/mali_csffw.bin" \
	"$LEDE/$ROOTFS_FILES_REL/lib/firmware/arm/mali/arch10.8/mali_csffw.bin"
mkdir -p "$LEDE/$(dirname "$RKNPU_PACKAGE_REL")"
cp -a "$RKNPU_PACKAGE_REL" "$LEDE/$RKNPU_PACKAGE_REL"
mkdir -p "$LEDE/$(dirname "$AP6275P_FIRMWARE_PACKAGE_REL")"
cp -a "$AP6275P_FIRMWARE_PACKAGE_REL" "$LEDE/$AP6275P_FIRMWARE_PACKAGE_REL"
mkdir -p "$LEDE/$(dirname "$AGIBOT_BT_ATTACH_PACKAGE_REL")"
cp -a "$AGIBOT_BT_ATTACH_PACKAGE_REL" "$LEDE/$AGIBOT_BT_ATTACH_PACKAGE_REL"
mkdir -p "$LEDE/$(dirname "$RKNN_RUNTIME_PACKAGE_REL")"
cp -a "$RKNN_RUNTIME_PACKAGE_REL" "$LEDE/$RKNN_RUNTIME_PACKAGE_REL"
mkdir -p "$LEDE/$(dirname "$GCOMPAT_PACKAGE_REL")"
cp -a "$GCOMPAT_PACKAGE_REL" "$LEDE/$GCOMPAT_PACKAGE_REL"
install -d "$LEDE/$RKNN_RUNTIME_PACKAGE_REL/files"
install -m 0755 "$REPO_ROOT/overlay/usr/lib/librknnrt.so" \
	"$LEDE/$RKNN_RUNTIME_PACKAGE_REL/files/librknnrt.so"
install -m 0644 "$REPO_ROOT/overlay/root/npu_test/mobilenet_v1.rknn" \
	"$LEDE/$RKNN_RUNTIME_PACKAGE_REL/files/mobilenet_v1.rknn"
install -m 0644 "$REPO_ROOT/overlay/root/npu_test/resnet18.rknn" \
	"$LEDE/$RKNN_RUNTIME_PACKAGE_REL/files/resnet18.rknn"
install -m 0644 "$REPO_ROOT/kernel/rk35xx-vendor-6.1/0001-ASoC-add-ACM8625P-amplifier.patch" \
	"$LEDE/$ACM8625P_KERNEL_PATCH_REL"
install -d "$LEDE/$ROOTFS_FILES_REL/lib/firmware"
install -m 0644 "$REPO_ROOT/overlay/lib/firmware/acm8625p_dsp_stereo_btl_48khz.bin" \
	"$LEDE/$ROOTFS_FILES_REL/lib/firmware/acm8625p_dsp_stereo_btl_48khz.bin"

# 4. feeds
echo ">>> [4/5] feeds update/install(coolsnowwolf 全家桶)..."
setup_proxy
HELLOWORLD_FEEDS_ONLY=1 bash "$SCRIPT_DIR/helloworld-srclink.sh"
( cd "$LEDE" && ./scripts/feeds update -a )
for p in feed-patches/*.patch; do
	case "$(basename "$p")" in
	001-golang-darwin-external-linker.patch|\
	002-docker-darwin-gnu-date.patch)
		if [ "$PLATFORM" != macos ]; then
			echo "    skip Darwin-only feed patch $(basename "$p")"
			continue
		fi
		;;
	esac
	echo "    apply feed patch $(basename "$p")"
	if git -C "$LEDE" apply --reverse --check "$SCRIPT_DIR/$p" >/dev/null 2>&1; then
		echo "      已应用,跳过"
	else
		git -C "$LEDE" apply --ignore-whitespace "$SCRIPT_DIR/$p"
	fi
done
( cd "$LEDE" && ./scripts/feeds install -a )

# 5. .config 种子 + defconfig
echo ">>> [5/5] 装配 .config 种子 + $MAKE_BIN defconfig..."
cp config-agibot-openwrt "$LEDE/.config"
( cd "$LEDE" && "$MAKE_BIN" defconfig )

echo ""
echo "✓ 装配完成。编译:"
if [ "$PLATFORM" = macos ]; then
	echo "    cd $LEDE && $MAKE_BIN -j\$(sysctl -n hw.ncpu) V=s"
else
	echo "    cd $LEDE && $MAKE_BIN -j\$(nproc) V=s   # 或 bash docker-lede-build.sh"
fi
echo "  产物: $LEDE/bin/targets/rockchip/armv8/*agibot*sysupgrade.img.gz"
echo "  刷机: 解压后整盘写 eMMC,复用 flash/(Loader@0xCCCCCCCC + image@0)"
