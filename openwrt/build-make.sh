#!/usr/bin/env bash
# 全量构建:在 ext4 ~/lede(缓存 toolchain/内核)上 make -jN 出 sysupgrade.img.gz。
# 走代理:WSL 网关上的 Windows Clash:7897,2026-08-14 验证已对 github/proxy.golang.org 可达(200)。
# 编完定位镜像 + 拷回仓库。
set -uo pipefail
cd /home/cennac/lede || { echo "no ~/lede"; exit 1; }
git config --global --add safe.directory '*'

# 修复:剥掉 WSL 继承的 Windows PATH(含 "Program Files (x86)" 的括号,
# 会让 u-boot binman 的 `bash -c "...PATH=..."` 报 syntax error near '(' )。
# host 须装 python3-pyelftools(binman 读 BL31.elf 需要 elftools 模块)。
export PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE '^/mnt/[a-zA-Z]/' | paste -sd:)"

# 代理:Windows Clash 经 WSL 默认网关。之前该代理会 reset github,2026-08-14 已修复(200)。
# 用途:① Go 模块 goproxy.cn 没覆盖时的 direct(github)回退;② 任何 github 直链下载。
# goproxy.cn / 清华源走直连更快(且国内可达),用 no_proxy 排除不走代理。
GW=$(ip route | awk '/^default/{print $3; exit}')
export http_proxy="http://${GW}:7897"
export https_proxy="http://${GW}:7897"
export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"
export no_proxy="goproxy.cn,mirrors.tuna.tsinghua.edu.cn,pypi.tuna.tsinghua.edu.cn,127.0.0.1,localhost"
export NO_PROXY="$no_proxy"

# Go 模块:goproxy.cn 为主(直连快),缺的回退 direct(经上面代理走 github)。
# LEDE golang feed 不设 GOPROXY,默认 proxy.golang.org 国内直连挂 → 此处显式指定。
export GOPROXY="https://goproxy.cn,direct"
export GOSUMDB=off

echo "=== [1] 重新应用修正后的种子 + defconfig(确保 .config 与种子一致)==="
cp /mnt/e/AIPorject/101/agibot-armbian/openwrt/config-agibot-openwrt .config
make defconfig >/dev/null 2>&1
echo "defconfig done"

echo
echo "=== [2] make -j$(nproc) 全量编译(包 + rootfs + 镜像)~1-2h ==="
N=$(nproc)
make -j"$N" 2>&1 | tee /home/cennac/lede_build.log
RC=${PIPESTATUS[0]}
echo "MAKE_EXIT=$RC"

echo
echo "=== [3] 定位产物 ==="
find bin/targets/rockchip/armv8 -iname "*agibot*" -ls 2>/dev/null
echo "--- 目录 ---"
ls -la bin/targets/rockchip/armv8/ 2>/dev/null

echo
echo "=== [4] 拷 sysupgrade 镜像回仓库 ==="
DEST=/mnt/e/AIPorject/101/agibot-armbian/openwrt
for f in bin/targets/rockchip/armv8/*agibot*sysupgrade.img.gz; do
  [ -f "$f" ] && cp -v "$f" "$DEST/" && echo "copied: $(basename "$f")"
done

echo "BUILD_MAKE_DONE rc=$RC"
