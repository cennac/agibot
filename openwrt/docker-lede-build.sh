#!/usr/bin/env bash
# docker-lede-build.sh — 在 Ubuntu 容器内编译 LEDE/OpenWrt(ext4 卷映射,避开 WSL2 9p 坑)。
#
# 与 armbian 的 docker-build.sh 同思路,但 LEDE 是纯交叉编译:
#   - 无需 binfmt/qemu(不 chroot arm64 rootfs)
#   - 无需 -v /dev:/dev(用自带 ptgen 打镜像,不依赖 host losetup)
#   - 无需 --privileged(ptgen 只 trunc+dd 文件,不建 loop 设备)
#
# 必须在 WSL Ubuntu 内跑(Windows 端跑会让 -v 过 9p,慢且有坑)。
# 前置(一次性):启动 Docker Desktop → Settings → Resources → WSL Integration → 开 Ubuntu。
#
# 用法(在仓库根或 openwrt/ 下均可):
#   cd ~/docker-agibot-armbian/openwrt
#   bash docker-lede-build.sh                       # 完整编译(装配 + make -jN)
#   bash docker-lede-build.sh target/linux/compile  # 只编内核/DTS(快速验证 DTS,bring-up 用)
#   bash docker-lede-build.sh --shell               # 进容器交互 shell(调试)
#   PROXY_HOST=192.168.88.128 PROXY_PORT=7897 bash docker-lede-build.sh
#                                                     # Linux 服务器代理不在 Docker 宿主机本机时指定
#   DIRECT=1 bash docker-lede-build.sh              # 不传代理(feeds 已装/cache 齐时用)
set -euo pipefail

# 仓库根 = openwrt/ 的上一级
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMG="agibot-lede-builder"
MNT="/agibot"                 # 容器内挂载点 = 仓库根
WD="$MNT/openwrt"             # 工作目录 = openwrt/(含 lede/ 子树)
PROXY_PORT="${PROXY_PORT:-7897}"
PROXY_HOST="${PROXY_HOST:-host.docker.internal}"
NP="localhost,127.0.0.1,::1"
DIRECT="${DIRECT:-0}"

# 0. 前置检查
command -v docker >/dev/null 2>&1 || {
	echo "[!] WSL 里没有 docker。启动 Docker Desktop → Settings → Resources →"
	echo "    WSL Integration → 开启 Ubuntu,然后重试。"
	exit 1
}
docker info >/dev/null 2>&1 || { echo "[!] docker daemon 未就绪,启动 Docker Desktop 后重试。"; exit 1; }

# 1. 构建 builder 镜像(Dockerfile-lede 无 COPY,用空 context stdin build,快)
echo ">>> 构建/更新 builder 镜像 $IMG ..."
docker build -t "$IMG" - < "$SCRIPT_DIR/Dockerfile-lede"

# 2. 容器通用参数
#    --add-host host.docker.internal:host-gateway :容器经此访问 host 的 Clash(feeds 拉 github)
#    -it 仅在有 tty 时加(后台/CI 无 tty 加 -it 会报错)
INTERACTIVE=()
[ -t 0 ] && INTERACTIVE=(-it)
PROXY_ENV=()
if [ "$DIRECT" = 1 ]; then
	echo ">>> DIRECT=1:不传代理(feeds 已装 / cache 齐时用)"
else
	PROXY_ENV=(
		-e http_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
		-e https_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
		-e no_proxy="$NP" -e NO_PROXY="$NP"
		-e HTTP_PROXY="http://${PROXY_HOST}:${PROXY_PORT}"
		-e HTTPS_PROXY="http://${PROXY_HOST}:${PROXY_PORT}"
	)
fi
COMMON=(
	--rm
	"${INTERACTIVE[@]}"
	--add-host host.docker.internal:host-gateway
	-v "$ROOT":"$MNT" -w "$WD"
	-e TERM="${TERM:-xterm}"
	"${PROXY_ENV[@]}"
)

# 3. 进容器
ARG="${1:-}"
if [ "$ARG" = "--shell" ]; then
	echo ">>> 进容器交互 shell($WD),手动操作..."
	exec docker run "${COMMON[@]}" "$IMG"
fi

# make 目标:默认全量;传位置参数则只编该目标(如 target/linux/compile 验 DTS)
if [ -n "$ARG" ]; then
	MAKE="make $ARG V=s"
	echo ">>> 只编 make 目标 [$ARG](快速验证,不做 sysupgrade img)"
else
	MAKE="make -j\$(nproc) V=s"
	echo ">>> 完整编译(装配 + $MAKE)"
fi

echo ">>> 挂载 $ROOT → $MNT,工作目录 $WD"
# safe.directory:容器 root 访问 ext4 上 host 用户拥有的 submodule 触发 git dubious ownership
docker run "${COMMON[@]}" "$IMG" bash -c "
	git config --global --add safe.directory '*' &&
	cd openwrt && bash setup-openwrt.sh &&
	cd lede && $MAKE 2>&1 | tee build.log; rc=\${PIPESTATUS[0]};
	echo FINISHED_EXIT=\$rc >> build.log; exit \$rc
"
echo ""
echo ">>> 完成。产物:$ROOT/openwrt/lede/bin/targets/rockchip/armv8/*agibot*sysupgrade.img.gz"
