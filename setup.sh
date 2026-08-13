#!/usr/bin/env bash
# setup.sh — 把 cennac/agibot 装配成可编译状态(跨平台:WSL2 / Linux / macOS)。
#
# 做三件事:
#   1. 初始化 armbian-build submodule(若未初始化)
#   2. 框架 hack 补丁 —— 仅 WSL2 需 apply;原生 Linux / macOS 用干净框架(见下)
#   3. 把仓库根的板级配置装配到 armbian-build/userpatches/
#
# 之后直接跑 `bash start-build.sh` 编译。
# 用法:
#   bash setup.sh                  # 标准装配
#   bash setup.sh --reuse-cache    # 额外:从平级旧副本 armbian-build/cache 复用编译缓存
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
SUB="armbian-build"

# 平台检测(决定是否 apply WSL2 专用 patch)
detect_platform() {
	# 容器内一律按 linux 处理:卷映射走 ext4/virtiofs,无 WSL2 的 9p 坑,
	# 那 5 处 WSL2 patch(尤其 fchmod)在 ext4 上反而有害 → 不 apply。
	[ -f /.dockerenv ] && { echo linux; return; }
	case "$(uname -s)" in
		Linux*)  grep -qi microsoft /proc/version 2>/dev/null && echo wsl || echo linux ;;
		Darwin*) echo macos ;;
		*)       echo unknown ;;
	esac
}
PLATFORM="${PLATFORM:-$(detect_platform)}"
echo ">>> 检测到平台: $PLATFORM"

# 0. 关键依赖自检(git 用于 submodule;其余编译依赖见 scripts/install-deps.sh)
if ! command -v git >/dev/null 2>&1; then
	echo ">>> [!] 缺 git。先装依赖: bash scripts/install-deps.sh"
	exit 1
fi
if [ "$PLATFORM" != macos ] && [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
	echo ">>> [提醒] qemu-aarch64 binfmt 未注册 —— 编译到 rootfs 阶段会报 'Exec format error'"
	echo "         首次请先跑: bash scripts/install-deps.sh"
fi

# 1. 初始化 submodule(armbian/build @ 70a242f)
if [ ! -d "$SUB/.git" ]; then
	echo ">>> [1/3] 初始化 submodule $SUB(首次会从 github clone,约 15G 源码/工具链)..."
	git submodule update --init --recursive "$SUB"
else
	echo ">>> [1/3] submodule $SUB 已存在,跳过 init"
fi

# 2. 框架 hack 补丁(平台分流)
#    5 处 hack(sync/git/mmdebstrap/fchmod/9p)是 WSL2 的 9p 文件系统 + 代理特化的。
#    原生 Linux(ext4)/ macOS(apfs)文件系统正常,其中 fchmod hack 反而有害 → 仅 WSL2 apply。
echo ">>> [2/3] 框架 hack 补丁..."
if [ "$PLATFORM" = wsl ]; then
	echo "    [WSL2] apply patches/wsl2-build-hacks.patch(5 处 9p/sync/代理 hack)"
	git -C "$SUB" checkout -- . 2>/dev/null || true   # 幂等:先重置回 70a242f 再 apply
	git -C "$SUB" apply "$ROOT/patches/wsl2-build-hacks.patch"
else
	echo "    [$PLATFORM] 用干净 armbian/build @ 70a242f,跳过 WSL2 patch"
	echo "             (9p/sync/fchmod hack 在 ext4/apfs 不需要,部分有害)"
fi

# 3. 装配 userpatches(板级配置 → armbian-build/userpatches/)
#    这些文件在本仓库根,userpatches/ 被 armbian/build 自身 .gitignore,不会污染 submodule。
echo ">>> [3/3] 装配 userpatches..."
UP="$SUB/userpatches"
mkdir -p "$UP/config"
cp -r config/. "$UP/config/"
cp config-agibot.conf config-agibot-desktop.conf config-example.conf "$UP/"
cp customize-image.sh "$UP/"
cp -r overlay "$UP/"

# 可选:复用平级旧副本的编译缓存(避免重新下载 ~15G)
if [ "${1:-}" = "--reuse-cache" ]; then
	OLD_CACHE="$ROOT/../armbian-build/cache"
	if [ -d "$OLD_CACHE" ]; then
		echo ">>> [bonus] 复用旧副本 cache: $OLD_CACHE -> $SUB/cache"
		cp -al "$OLD_CACHE" "$SUB/cache" 2>/dev/null || cp -r "$OLD_CACHE" "$SUB/cache"
	else
		echo ">>> [bonus] --reuse-cache 但未找到 $OLD_CACHE,跳过"
	fi
fi

echo ""
echo "✓ 装配完成。下一步:bash start-build.sh"
echo "  (编译入口已含代理 / NO_HOST_RELEASE_CHECK / git resilience,直接跑即可)"
