#!/usr/bin/env bash
# docker-build.sh — 在 Ubuntu 容器内编译 armbian(ext4 卷映射,避开 WSL2 9p 坑)。
#
# 前置(一次性,Windows 端):
#   1. 启动 Docker Desktop
#   2. Docker Desktop → Settings → Resources → WSL Integration → 开启 Ubuntu
#   之后 WSL Ubuntu 内 `docker` 可用、且 -v 映射 ext4 路径不走 9p。
#
# 必须在 WSL Ubuntu 内跑(Windows 端跑会让 -v 过 9p,慢且有 fsync/fchmod 坑)。
# 用法:
#   cd ~/docker-agibot-armbian              # 仓库 clone 到 ext4 的位置(见 BUILD-GUIDE §Docker)
#   bash docker-build.sh                    # 构建镜像 + 进容器:编 minimal(agibot / jammy)
#   bash docker-build.sh agibot-desktop     # 编桌面版(noble + xfce);默认 agibot(minimal)
#   bash docker-build.sh --shell            # 只进容器开交互 shell(调试/手动跑)
#   PROXY_PORT=7890 bash docker-build.sh    # 改代理端口(默认 7897 = Clash Verge mixed-port)
#   DIRECT=1 bash docker-build.sh           # 不传代理(apt 直连清华;cache 已齐时用,避免 Clash 抖动挂 apt)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG="agibot-armbian-builder"
MNT="/docker-agibot-armbian"
PROXY_PORT="${PROXY_PORT:-7897}"
NP="localhost,127.0.0.1,::1,github.armbian.com"
# DIRECT=1:不向容器传代理 env → armbian 的 apt 直连清华镜像(更稳)。
#   原因:armbian main-config.sh 会从 http_proxy 推导全局 APT_PROXY_ADDR(runners.sh 设
#   Acquire::http::Proxy),把所有 apt(含清华镜像)全劫持进 Clash;Clash 抖一下 apt 即挂。
#   适合:cache/ 已齐(无需再从 github 拉 kernel/u-boot/rootfs)的重复 / 桌面编译。
# 默认(未设 DIRECT):传代理,首次编译需经代理从 github 拉资产。
DIRECT="${DIRECT:-0}"

# 0. 前置检查
command -v docker >/dev/null 2>&1 || {
	echo "[!] WSL 里没有 docker。请:启动 Docker Desktop → Settings → Resources →"
	echo "    WSL Integration → 开启 Ubuntu,然后重试。"
	exit 1
}
docker info >/dev/null 2>&1 || { echo "[!] docker daemon 未就绪,启动 Docker Desktop 后重试。"; exit 1; }

# 1. 构建 builder 镜像(Dockerfile 改动后会自动重建)
echo ">>> 构建/更新 builder 镜像 $IMG ..."
docker build -t "$IMG" "$ROOT"

# 2. binfmt:容器内交叉编 arm64 rootfs(chroot)需 binfmt_misc 触发 qemu。
#    Docker Desktop 4.x+ 默认在其 kernel 注册 multiarch binfmt —— 容器虽看不到
#    /proc/sys/fs/binfmt_misc/qemu-aarch64,但 arm64 执行仍经 kernel 全局 binfmt 自动走 qemu
#    (已实测:容器内跑 arm64 二进制 exit=42)。host /proc 有 qemu-aarch64 则基本可放心。
#    若 armbian rootfs 阶段报 Exec format error,手动注册:
#       docker run --rm --privileged tonistiigi/binfmt --install arm64
if [ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
	echo ">>> binfmt: host qemu-aarch64 已注册 ✓(容器 binfmt 由 Docker Desktop kernel 提供)"
else
	echo ">>> binfmt: host 未检测到,尝试注册(docker.io 拉取失败可忽略)..."
	docker run --rm --privileged tonistiigi/binfmt --install arm64 2>/dev/null \
		|| echo "    (注册镜像拉取失败 —— 若编译报 Exec format error 再手动跑上面那条)"
fi

# 3. 容器通用参数
#    --privileged                :armbian rootfs 阶段要 losetup/mount/chroot
#    --add-host host.docker.internal:host-gateway :容器经此访问 host 的 Clash(三平台统一)
#    -e http_proxy=host.docker.internal:PROXY_PORT :传给 start-build.sh 的 linux 分支继承
# -it 仅在有 tty 时加(交互式终端);后台/CI 无 tty 时加 -it 会让 docker 报
#   "cannot attach stdin to a TTY-enabled container because stdin is not a terminal" 直接退出
INTERACTIVE=()
[ -t 0 ] && INTERACTIVE=(-it)
# 代理 env:仅非 DIRECT 模式注入(armbian 会把 http_proxy 当 apt 全局代理)
PROXY_ENV=()
if [ "$DIRECT" = 1 ]; then
	echo ">>> DIRECT=1:不传代理(apt 直连清华镜像,需 cache 已齐)"
else
	PROXY_ENV=(
		-e http_proxy="http://host.docker.internal:${PROXY_PORT}"
		-e https_proxy="http://host.docker.internal:${PROXY_PORT}"
		-e no_proxy="$NP" -e NO_PROXY="$NP"
		-e HTTP_PROXY="http://host.docker.internal:${PROXY_PORT}"
		-e HTTPS_PROXY="http://host.docker.internal:${PROXY_PORT}"
	)
fi

COMMON=(
	--rm --privileged
	"${INTERACTIVE[@]}"
	-v /dev:/dev                # 打包 img 阶段 losetup -P 建的分区节点 /dev/loopXp1 需共享 host /dev 才在容器可见
	--add-host host.docker.internal:host-gateway
	-v "$ROOT":"$MNT" -w "$MNT"
	-e TERM="${TERM:-xterm}"
	"${PROXY_ENV[@]}"
)

# 4. 进容器
ARG="${1:-}"
if [ "$ARG" = "--shell" ]; then
	echo ">>> 进容器交互 shell($MNT),手动操作..."
	exec docker run "${COMMON[@]}" "$IMG"
fi

# 目标:agibot(minimal,jammy)或 agibot-desktop(noble + xfce);默认 agibot
TARGET="${ARG:-agibot}"
echo ">>> 启动容器编译 [$TARGET]:挂载 $ROOT → $MNT"
echo ">>> 容器内执行 setup.sh + start-build.sh $TARGET(前台编译,日志实时输出)..."
# 先设 safe.directory:容器以 root 跑,访问 ext4 上 host 用户拥有的仓库会触发 git dubious ownership
# 补丁管线(setup 后、编译前,幂等重打——armbian 流程会 reset submodule):
#   ①ref2info-fallback:raw.githubusercontent 被 Clash 出口 429 限流时,u-boot/kernel
#     Makefile 从本地 git-bare 缓存取;②apt-proxy-bypass:AGIBOT_NO_APT_PROXY=1 阻止
#     armbian 把 chroot apt 劫持进代理。host apt 直连由 apt.conf.d 显式 DIRECT 实现
#     (apt conf 优先于 http_proxy env);git/curl/oras 仍走代理 —— 分流:apt 直连、其余走代理。
docker run "${COMMON[@]}" -e AGIBOT_NO_APT_PROXY=1 "$IMG" bash -c "git config --global --add safe.directory '*' && printf 'Acquire::http::Proxy \"DIRECT\";\nAcquire::https::Proxy \"DIRECT\";\n' > /etc/apt/apt.conf.d/99agibot-noproxy && bash setup.sh && python3 $MNT/scripts/patch-ref2info-fallback.py $MNT/armbian-build && python3 $MNT/scripts/patch-apt-proxy-bypass.py $MNT/armbian-build && bash start-build.sh $TARGET"
echo ""
echo ">>> 完成。产物:$ROOT/armbian-build/output/images/"
