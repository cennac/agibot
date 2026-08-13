#!/usr/bin/env bash
# setup.sh — 把 cennac/agibot 装配成可编译状态。
#
# 做三件事:
#   1. 初始化 armbian-build submodule(若未初始化)
#   2. apply WSL2 框架 hack 补丁(patches/wsl2-build-hacks.patch,幂等)
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

# 1. 初始化 submodule(armbian/build @ 70a242f)
if [ ! -d "$SUB/.git" ]; then
	echo ">>> [1/3] 初始化 submodule $SUB(首次会从 github clone,约 15G 源码/工具链)..."
	git submodule update --init --recursive "$SUB"
else
	echo ">>> [1/3] submodule $SUB 已存在,跳过 init"
fi

# 2. 幂等 apply 框架 hack 补丁
#    先把 tracked 文件重置回 70a242f(清掉之前 apply 的改动),再重新 apply,
#    保证反复跑 setup.sh 结果一致。
echo ">>> [2/3] apply WSL2 框架 hack 补丁..."
git -C "$SUB" checkout -- . 2>/dev/null || true
git -C "$SUB" apply "$ROOT/patches/wsl2-build-hacks.patch"

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
