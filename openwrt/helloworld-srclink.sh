#!/usr/bin/env bash
# helloworld-srclink.sh — 用 src-link 本地 feed 补齐 passwall 代理核心包。
#
# 直接 git clone fw876/helloworld 在部分代理环境会 TLS/gnutls 握手失败,因此这里用
# codeload tarball 下载后解压成本地 feed,再写入 lede/feeds.conf。
#
# 用法:
#   cd openwrt && bash helloworld-srclink.sh
#   HELLOWORLD_FEEDS_ONLY=1 bash helloworld-srclink.sh   # 只准备 src-link,不 update/install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEDE="${LEDE:-$SCRIPT_DIR/lede}"
HW="${HELLOWORLD_DIR:-$SCRIPT_DIR/.tmp/helloworld-feed}"
TARBALL="${TMPDIR:-/tmp}/agibot-helloworld.tar.gz"
HW_NEW="${TMPDIR:-/tmp}/agibot-helloworld-feed.$$"
FEEDS_ONLY="${HELLOWORLD_FEEDS_ONLY:-0}"

setup_macos_path() {
	[ "$(uname -s)" = Darwin ] || return 0
	local brew_prefix
	brew_prefix="$(brew --prefix 2>/dev/null || true)"
	[ -n "$brew_prefix" ] || return 0
	for d in \
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

setup_proxy() {
	if [ -n "${http_proxy:-}" ]; then
		echo ">>> proxy: 继承 http_proxy=$http_proxy"
	elif [ "$(uname -s)" = Darwin ] && curl -s --max-time 1 -o /dev/null http://127.0.0.1:7897 2>/dev/null; then
		export http_proxy="http://127.0.0.1:7897"
		export https_proxy="$http_proxy"
		export HTTP_PROXY="$http_proxy"
		export HTTPS_PROXY="$https_proxy"
		export no_proxy="localhost,127.0.0.1,::1"
		export NO_PROXY="$no_proxy"
		echo ">>> proxy: macOS 检测到本地 127.0.0.1:7897"
	elif [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
		GW="$(ip route show default | awk '{print $3; exit}')"
		export http_proxy="http://${GW}:7897"
		export https_proxy="$http_proxy"
		export HTTP_PROXY="$http_proxy"
		export HTTPS_PROXY="$https_proxy"
		export no_proxy="goproxy.cn,mirrors.tuna.tsinghua.edu.cn,127.0.0.1,localhost"
		export NO_PROXY="$no_proxy"
		echo ">>> proxy: WSL 网关 ${GW}:7897"
	else
		echo ">>> proxy: 无。若 codeload 慢,先 export http_proxy=..."
	fi
}

[ -d "$LEDE" ] || { echo "[!] 未找到 LEDE 树: $LEDE"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "[!] 缺 curl"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "[!] 缺 tar"; exit 1; }

setup_proxy

cd "$LEDE"
git config --global --add safe.directory '*' 2>/dev/null || true
[ -f feeds.conf ] || cp feeds.conf.default feeds.conf

echo "=== [1] 清掉 feeds.conf 里旧 helloworld 行 ==="
sed -i.bak '/src-git helloworld/d;/src-link helloworld/d' feeds.conf
rm -f feeds.conf.bak
rm -rf feeds/helloworld feeds/helloworld.tmp feeds/helloworld.index

if [ -f "$HW/shadowsocks-rust/Makefile" ] && [ -f "$HW/ipt2socks/Makefile" ]; then
	echo
	echo "=== [2] 复用已有 helloworld feed: $HW ==="
else
	echo
	echo "=== [2] curl 下载 fw876/helloworld tarball(main→master) ==="
	rm -rf "$TARBALL" "$HW_NEW"
	mkdir -p "$(dirname "$HW")" "$HW_NEW"
	ok=0
	for BR in main master; do
		URL="https://codeload.github.com/fw876/helloworld/tar.gz/refs/heads/$BR"
		echo "  试 $BR ..."
		if curl -fL --http1.1 --connect-timeout 20 --retry 5 --retry-all-errors -m 180 -o "$TARBALL" "$URL" \
			&& [ -s "$TARBALL" ] && tar tzf "$TARBALL" >/dev/null 2>&1; then
			echo "  ✓ $BR 下载成功($(du -h "$TARBALL" | awk '{print $1}'))"
			ok=1
			break
		fi
	done
	[ "$ok" = 1 ] || { rm -rf "$HW_NEW"; echo "  ✗ helloworld tarball 下载失败"; exit 1; }

	tar xzf "$TARBALL" -C "$HW_NEW" --strip-components=1
	rm -rf "$HW"
	mv "$HW_NEW" "$HW"
	echo "  解压到 $HW ($(find "$HW" -maxdepth 1 -mindepth 1 | wc -l | awk '{print $1}') 顶层条目)"
fi

echo
echo "=== [3] feeds.conf 写入 src-link helloworld ==="
echo "src-link helloworld $HW" >> feeds.conf
grep -n helloworld feeds.conf

if [ "$FEEDS_ONLY" = 1 ]; then
	echo "HELLOWORLD_SRCLINK_READY"
	exit 0
fi

echo
echo "=== [4] feeds update/install ==="
./scripts/feeds update helloworld
./scripts/feeds install -a

echo
echo "=== [5] 代理核心包检查 ==="
missing=0
for pkg in shadowsocks-rust v2ray-plugin ipt2socks simple-obfs; do
	if [ -e "package/feeds/helloworld/$pkg" ]; then
		echo "  ✓ $pkg"
	else
		echo "  ✗ $pkg 仍缺"
		missing=1
	fi
done
[ "$missing" = 0 ] || exit 1
echo "HELLOWORLD_SRCLINK_DONE"
