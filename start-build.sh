#!/usr/bin/env bash
# start-build.sh — Armbian 编译入口(跨平台:WSL2 / Linux / macOS)。
#
# 按平台自动适配:
#   - 代理:WSL2 自动走 Windows 网关 Clash(7897);Linux/macOS 继承 http_proxy 或检测本地 7897
#   - Docker:macOS 走 Docker(binfmt/qemu 在 macOS 上不工作);WSL/Linux 原生编译
#   - NO_HOST_RELEASE_CHECK、git resilience、后台运行(setsid 或 macOS 回退 nohup)
#
# 前置:先跑 `bash setup.sh`(装配 submodule + patch + userpatches)。
# 用法:
#   bash setup.sh && bash start-build.sh                  # 默认编 minimal(agibot / jammy)
#   bash setup.sh && bash start-build.sh agibot-desktop   # 编桌面版(noble + xfce)
#   tail -f armbian-build/output/build.log
set -e

# 脚本相对定位(POSIX,三平台兼容;不用 readlink -f 因 macOS 无)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/armbian-build" \
	|| { echo "FATAL: armbian-build/ 不存在或未 init,先跑 bash setup.sh"; exit 1; }

# 编译目标:agibot(minimal,jammy)或 agibot-desktop(noble + xfce 桌面)
BOARD="${1:-agibot}"
export BOARD   # setsid/nohup 子 shell 是单引号串,内层从环境取 $BOARD
echo "===== 目标: $BOARD ====="

# 平台检测
case "$(uname -s)" in
	Linux*)  if grep -qi microsoft /proc/version 2>/dev/null; then PLATFORM=wsl; else PLATFORM=linux; fi ;;
	Darwin*) PLATFORM=macos ;;
	*)       PLATFORM=unknown ;;
esac
# 容器内按 linux:代理走继承(docker-build.sh 经 host.docker.internal 传入),
# PREFER_DOCKER=no(容器内原生编,不嵌套),且不 setsid 后台(见下方容器前台分支)
[ -f /.dockerenv ] && PLATFORM=linux

mkdir -p output
rm -f output/build.log

# ---- Docker 策略:macOS 必须用 Docker;WSL/Linux 原生编译 ----
if [ "$PLATFORM" = macos ]; then
	export PREFER_DOCKER=yes
	if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
		echo "FATAL: macOS 需要 Docker Desktop 运行(交叉编译 arm64 rootfs 靠 docker 内的 qemu)。" >&2
		echo "       装好 Docker Desktop 并启动后重试。" >&2
		exit 1
	fi
	echo "===== macOS: PREFER_DOCKER=yes(Docker 已就绪)====="
else
	export PREFER_DOCKER=no
fi
export NO_HOST_RELEASE_CHECK=yes   # host-release gate 对 WSL noble / 各发行版偶发误拦

# ---- 代理策略 ----
setup_proxy() {
	if [ "$PLATFORM" = wsl ]; then
		# WSL2:Clash Verge mixed-port 7897 在 Windows host,经 NAT 网关可达(allow-lan 已开)
		GW=$(ip route show default | awk '{print $3; exit}')
		export http_proxy="http://${GW}:7897" https_proxy="http://${GW}:7897" \
			ftp_proxy="http://${GW}:7897" all_proxy="http://${GW}:7897"
		# github.armbian.com 直连 200、走代理 502,必须排除;其余国内镜像直连更快
		export no_proxy="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,.tuna.tsinghua.edu.cn,.bfsu.edu.cn,.aliyun.com,.ustc.edu.cn,github.armbian.com"
		echo "===== proxy: WSL 网关 ${GW}:7897 (Clash Verge) ====="
	else
		# Linux / macOS:优先用用户已有的 http_proxy;否则检测本地 7897;否则直连
		if [ -n "${http_proxy:-}" ]; then
			echo "===== proxy: 继承环境 http_proxy=$http_proxy ====="
		elif curl -s --max-time 1 -o /dev/null http://127.0.0.1:7897 2>/dev/null; then
			export http_proxy="http://127.0.0.1:7897" https_proxy="http://127.0.0.1:7897"
			export no_proxy="localhost,127.0.0.1,::1,github.armbian.com"
			echo "===== proxy: 检测到本地 127.0.0.1:7897 ====="
		else
			echo "===== proxy: 无(直连)。国内下 kernel 慢可 export http_proxy=... 后重跑 ====="
		fi
	fi
}
setup_proxy

# ---- binfmt 预检(Linux 原生;qemu 没装会在 chroot 阶段 Exec format error)----
if [ "$PLATFORM" = linux ]; then
	if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
		echo "⚠️  qemu-aarch64 binfmt 未注册,chroot 阶段会报 Exec format error。装一下:"
		echo "    sudo apt install -y qemu-user-static binfmt-support && sudo systemctl restart systemd-binfmt"
	fi
fi

# ---- git resilience: only for this build, without changing the user's global git config ----
export GIT_CONFIG_COUNT=5
export GIT_CONFIG_KEY_0=http.lowSpeedLimit
export GIT_CONFIG_VALUE_0=0
export GIT_CONFIG_KEY_1=http.lowSpeedTime
export GIT_CONFIG_VALUE_1=999999
export GIT_CONFIG_KEY_2=http.postBuffer
export GIT_CONFIG_VALUE_2=1048576000
export GIT_CONFIG_KEY_3=http.version
export GIT_CONFIG_VALUE_3=HTTP/1.1
export GIT_CONFIG_KEY_4=safe.directory
export GIT_CONFIG_VALUE_4="$SCRIPT_DIR/armbian-build"

# ---- 容器内:前台编译(容器 PID1 退出会杀后台进程,不能 setsid)----
if [ -f /.dockerenv ]; then
	echo "===== [容器] 前台编译(实时输出 + 写 output/build.log)====="
	set +e
	./compile.sh "$BOARD" EXPERT=yes DOWNLOAD_MIRROR=china 2>&1 | tee output/build.log
	rc=${PIPESTATUS[0]}
	echo "FINISHED_EXIT=$rc" >> output/build.log
	echo "===== [容器] 编译结束 exit=$rc ====="
	exit $rc
fi

# ---- 后台编译(host:macOS 无 setsid → 回退 nohup;日志写 output/build.log)----
if command -v setsid >/dev/null 2>&1; then
	setsid bash -c './compile.sh "$BOARD" EXPERT=yes DOWNLOAD_MIRROR=china > output/build.log 2>&1; echo "FINISHED_EXIT=$?" >> output/build.log' \
		< /dev/null > /dev/null 2>&1 &
else
	nohup bash -c './compile.sh "$BOARD" EXPERT=yes DOWNLOAD_MIRROR=china > output/build.log 2>&1; echo "FINISHED_EXIT=$?" >> output/build.log' \
		< /dev/null > /dev/null 2>&1 &
fi
disown 2>/dev/null || true

sleep 6
echo "===== launched @ $(date)  EUID=$(id -u)  PLATFORM=$PLATFORM  DOCKER=${PREFER_DOCKER} ====="
echo "===== build.log 前 25 行 ====="
head -25 output/build.log 2>/dev/null
echo ""
echo "跟踪日志: tail -f $(pwd)/output/build.log"
