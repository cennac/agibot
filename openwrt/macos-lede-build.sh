#!/usr/bin/env bash
# macos-lede-build.sh — macOS 本机编译 LEDE/OpenWrt,不使用 Docker。
#
# 用法:
#   cd openwrt
#   bash macos-lede-build.sh                       # 完整编译
#   bash macos-lede-build.sh target/linux/compile  # 只编内核/DTS
#   JOBS=6 bash macos-lede-build.sh                # 限制并发
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ "$(uname -s)" != Darwin ]; then
	echo "[!] 这个脚本只用于 macOS 本机编译。Linux/WSL 请用 setup-openwrt.sh 后 make。"
	exit 1
fi

command -v brew >/dev/null 2>&1 || {
	echo "[!] 缺 Homebrew。先安装 Homebrew 后重试。"
	exit 1
}

BREW_PREFIX="$(brew --prefix)"
for d in \
	"$BREW_PREFIX/bin" \
	"$BREW_PREFIX/opt/coreutils/libexec/gnubin" \
	"$BREW_PREFIX/opt/findutils/libexec/gnubin" \
	"$BREW_PREFIX/opt/gawk/libexec/gnubin" \
	"$BREW_PREFIX/opt/gpatch/libexec/gnubin" \
	"$BREW_PREFIX/opt/gnu-getopt/bin" \
	"$BREW_PREFIX/opt/gnu-sed/libexec/gnubin" \
	"$BREW_PREFIX/opt/grep/libexec/gnubin" \
	"$BREW_PREFIX/opt/gnu-tar/libexec/gnubin" \
	"$BREW_PREFIX/opt/make/libexec/gnubin" \
	"$BREW_PREFIX/opt/gettext/bin" \
	"$BREW_PREFIX/opt/ncurses/bin" \
	"$BREW_PREFIX/opt/openssl@3/bin" \
	"$BREW_PREFIX/opt/python@3.12/libexec/bin" \
	"$BREW_PREFIX/opt/unzip/bin"; do
	[ -d "$d" ] && PATH="$d:$PATH"
done
export PATH
export MAKE_BIN="${MAKE_BIN:-gmake}"

DEPS=(
	bash coreutils diffutils findutils gawk gpatch gnu-getopt gnu-sed grep gnu-tar
	make ncurses openssl@3 perl python@3.12 rsync unzip wget xz zstd gettext pkgconf swig
)
MISSING=()
for dep in "${DEPS[@]}"; do
	brew list --versions "$dep" >/dev/null 2>&1 || MISSING+=("$dep")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
	echo "[!] 缺 Homebrew 依赖:"
	printf '    %s\n' "${MISSING[@]}"
	echo "    安装命令:"
	echo "    brew install ${MISSING[*]}"
	exit 1
fi

command -v "$MAKE_BIN" >/dev/null 2>&1 || {
	echo "[!] 缺 $MAKE_BIN,请确认 brew install make 已完成。"
	exit 1
}

CASE_TEST_DIR="$SCRIPT_DIR/.case-sensitive-test"
rm -rf "$CASE_TEST_DIR"
mkdir -p "$CASE_TEST_DIR"
touch "$CASE_TEST_DIR/a"
if [ -e "$CASE_TEST_DIR/A" ]; then
	rm -rf "$CASE_TEST_DIR"
	echo "[!] 当前仓库所在文件系统大小写不敏感。"
	echo "    OpenWrt/LEDE 原生编译建议放到大小写敏感 APFS 卷或 sparsebundle。"
	exit 1
fi
rm -rf "$CASE_TEST_DIR"

if [ -z "${http_proxy:-}" ] && curl -s --max-time 1 -o /dev/null http://127.0.0.1:7897 2>/dev/null; then
	export http_proxy="http://127.0.0.1:7897"
	export https_proxy="$http_proxy"
	export HTTP_PROXY="$http_proxy"
	export HTTPS_PROXY="$https_proxy"
	export no_proxy="localhost,127.0.0.1,::1"
	export NO_PROXY="$no_proxy"
	echo ">>> proxy: macOS 检测到本地 127.0.0.1:7897"
elif [ -n "${http_proxy:-}" ]; then
	echo ">>> proxy: 继承 http_proxy=$http_proxy"
else
	echo ">>> proxy: 无。若 GitHub/feeds 慢,先 export http_proxy=http://127.0.0.1:端口"
fi
export GOPROXY="${GOPROXY:-https://goproxy.cn,direct}"
echo ">>> go: GOPROXY=$GOPROXY"

ensure_pyelftools() {
	local python_site="$SCRIPT_DIR/.tmp/python-site"
	local host_python="$SCRIPT_DIR/lede/staging_dir/host/bin/python3"
	local python_bin

	if [ -x "$host_python" ]; then
		python_bin="$host_python"
	else
		python_bin="$(command -v python3)"
	fi

	mkdir -p "$python_site"
	export PYTHONPATH="$python_site${PYTHONPATH:+:$PYTHONPATH}"
	if ! "$python_bin" -c 'import elftools' >/dev/null 2>&1; then
		echo ">>> python: 安装 pyelftools 到 $python_site ..."
		"$python_bin" -m pip install --target "$python_site" pyelftools
	fi
}

echo ">>> 装配 LEDE 工作区..."
bash setup-openwrt.sh
ensure_pyelftools

TARGET="${1:-}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
cd lede
if [ -n "$TARGET" ]; then
	echo ">>> 编译 make 目标 [$TARGET] ..."
	"$MAKE_BIN" "$TARGET" V=s 2>&1 | tee build.log
else
	echo ">>> 完整编译 -j$JOBS ..."
	"$MAKE_BIN" -j"$JOBS" V=s 2>&1 | tee build.log
fi
rc=${PIPESTATUS[0]}
echo "FINISHED_EXIT=$rc" >> build.log
exit "$rc"
