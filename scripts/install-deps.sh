#!/usr/bin/env bash
# install-deps.sh — 装编译 Armbian 的 host 依赖(跨平台:WSL2 / Linux / macOS)。
# setup.sh 检测到缺失时提示跑本脚本;也可手动跑一次(每台机器一次)。
#
# 用法: bash scripts/install-deps.sh
set -euo pipefail

case "$(uname -s)" in
	Linux*)  grep -qi microsoft /proc/version 2>/dev/null && PLATFORM=wsl || PLATFORM=linux ;;
	Darwin*) PLATFORM=macos ;;
	*) echo "不支持的平台: $(uname -s)"; exit 1 ;;
esac
echo ">>> 平台: $PLATFORM"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUDO=""; [ "$(id -u)" != 0 ] && SUDO=sudo

# ---------- macOS:Docker 模式 ----------
if [ "$PLATFORM" = macos ]; then
	echo ">>> macOS: armbian 走 Docker,host 只需 git + Docker Desktop"
	command -v git >/dev/null 2>&1 || echo "    (建议 brew install git)"
	if ! docker info >/dev/null 2>&1; then
		echo "    [FAIL] Docker Desktop 未运行: https://www.docker.com/products/docker-desktop"
		exit 1
	fi
	echo "[OK] Docker 已就绪"
	exit 0
fi

# ---------- WSL / Linux:apt 装编译依赖 ----------
echo ">>> apt 装编译依赖..."
PKGS=(git curl ca-certificates build-essential qemu-user-static binfmt-support device-tree-compiler)
$SUDO apt update
$SUDO apt install -y "${PKGS[@]}"

# ---------- binfmt 注册(交叉编译 arm64 rootfs 必需)----------
if [ "$PLATFORM" = wsl ]; then
	echo ">>> WSL: 注册 qemu binfmt + systemd-binfmt override(BUILD-GUIDE 坑①)"
	if [ -f "$ROOT/wsl-binfmt-setup.sh" ]; then
		$SUDO bash "$ROOT/wsl-binfmt-setup.sh"
	else
		echo "    [warn] 缺 wsl-binfmt-setup.sh(应在仓库根)"
	fi
	# WSL2 的 systemd-binfmt 被 ConditionVirtualization=!wsl 禁用,永久清掉
	if [ ! -f /etc/systemd/system/systemd-binfmt.service.d/zzz-enable-binfmt.conf ]; then
		$SUDO install -d /etc/systemd/system/systemd-binfmt.service.d
		$SUDO tee /etc/systemd/system/systemd-binfmt.service.d/zzz-enable-binfmt.conf >/dev/null <<'EOF'
[Unit]
ConditionVirtualization=
EOF
	fi
else
	echo ">>> Linux: 启用 systemd-binfmt"
	$SUDO systemctl restart systemd-binfmt 2>/dev/null || $SUDO update-binfmts --enable 2>/dev/null || true
fi

if [ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
	echo "[OK] qemu-aarch64 binfmt 已注册"
else
	echo "[warn] binfmt 未注册,重启 WSL/系统后重试,或查 /proc/sys/fs/binfmt_misc"
fi
echo ""
echo "[OK] 依赖安装完成。下一步: bash setup.sh && bash start-build.sh"
