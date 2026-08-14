#!/usr/bin/env bash
# 绕开 git(gnutls 过 Clash 代理崩):curl 下 helloworld tarball,改用 src-link 本地 feed。
set -uo pipefail
cd ~/lede || exit 1
git config --global --add safe.directory '*'
export PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE '^/mnt/[a-zA-Z]/' | paste -sd:)"
GW=$(ip route | awk '/^default/{print $3; exit}')
export http_proxy="http://${GW}:7897" https_proxy="http://${GW}:7897"
export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"
export no_proxy="goproxy.cn,mirrors.tuna.tsinghua.edu.cn,127.0.0.1,localhost"
export NO_PROXY="$no_proxy"

HW=/home/cennac/helloworld-feed

echo "=== [1] 清掉 feeds.conf 里失败的 src-git helloworld 行 ==="
sed -i '/src-git helloworld/d' feeds.conf
rm -rf feeds/helloworld feeds/helloworld.tmp feeds/helloworld.index 2>/dev/null
echo "  已清"

echo
echo "=== [2] curl 下 helloworld tarball(走代理;试 main→master)==="
rm -rf "$HW" /tmp/hw.tar.gz 2>/dev/null
ok=0
for BR in main master; do
  URL="https://codeload.github.com/fw876/helloworld/tar.gz/refs/heads/$BR"
  echo "  试 $BR ..."
  if curl -sSL -m 90 -o /tmp/hw.tar.gz "$URL" && [ -s /tmp/hw.tar.gz ] && tar tzf /tmp/hw.tar.gz >/dev/null 2>&1; then
    echo "  ✓ $BR 下载成功($(du -h /tmp/hw.tar.gz|cut -f1))"; ok=1; break
  fi
done
[ "$ok" = 1 ] || { echo "  ✗ 两个分支都下载失败"; exit 1; }
mkdir -p "$HW"
tar xzf /tmp/hw.tar.gz -C "$HW" --strip-components=1
echo "  解压到 $HW ($(ls "$HW" | wc -l) 顶层条目)"
ls "$HW" | head

echo
echo "=== [3] feeds.conf 改用 src-link ==="
echo "src-link helloworld $HW" >> feeds.conf
grep -n helloworld feeds.conf

echo
echo "=== [4] feeds update + install(src-link 不走 git)==="
./scripts/feeds update helloworld 2>&1 | tail -3
./scripts/feeds install -a 2>&1 | grep -iE 'passwall|conflict|already defined' | head
echo "INSTALL done"

echo
echo "=== [5] 代理核心包是否补齐 ==="
for pkg in shadowsocks-rust-sslocal shadowsocks-rust-ssserver v2ray-plugin ipt2socks simple-obfs-client hysteria naiveproxy tuic-client shadow-tls xray-plugin; do
  if find package/feeds -name Makefile -exec grep -l "Package/$pkg " {} \; 2>/dev/null | grep -q .; then
    echo "  ✓ $pkg"
  else
    echo "  ✗ $pkg 仍缺"
  fi
done

echo
echo "=== [6] passwall 同名冲突?(coolsnowwolf/luci vs helloworld)==="
find package/feeds -path '*luci-app-passwall*' -maxdepth 4 2>/dev/null
echo "HELLOWORLD_SRCLINK_DONE"
