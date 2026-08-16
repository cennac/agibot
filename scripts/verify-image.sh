#!/usr/bin/env bash
# verify-image.sh — 验证编译产物镜像(无需启动板子)。
# 用 debugfs 直接读 ext4 rootfs,检查 dtb / firmware / service / hostname 都进了镜像,
# 以及 dtb 5.10→6.1 适配是否生效。对应 BUILD-GUIDE §7。
#
# 用法:
#   bash scripts/verify-image.sh                # 自动找最新 Armbian-*.img
#   bash scripts/verify-image.sh <path-to.img>
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMG="${1:-}"
if [ -z "$IMG" ]; then
	IMG=$(ls -t "$ROOT"/armbian-build/output/images/Armbian-*.img 2>/dev/null | head -1)
fi
[ -n "$IMG" ] && [ -f "$IMG" ] || { echo "未找到镜像。用法: bash scripts/verify-image.sh <path-to.img>"; exit 1; }
echo ">>> 镜像: $IMG ($(du -h "$IMG" | cut -f1))"

command -v debugfs >/dev/null 2>&1 || { echo "缺 debugfs: sudo apt install e2fsprogs"; exit 1; }
command -v fdtget >/dev/null 2>&1 || { echo "缺 fdtget: sudo apt install device-tree-compiler"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo ">>> 提取 rootfs(16MiB offset)到 $TMP/v.ext4 ..."
dd if="$IMG" of="$TMP/v.ext4" bs=1M skip=16 status=none

pass=0; fail=0
check() { if [ "$2" = OK ]; then echo "  [OK]   $1"; pass=$((pass+1)); else echo "  [FAIL] $1"; fail=$((fail+1)); fi; }

echo ">>> (1) agibot dtb 是否进了内核 dtb 目录"
DTB_DIR=$(debugfs -R "ls boot/" "$TMP/v.ext4" 2>/dev/null | grep -oE 'dtb-[0-9.]+-vendor-rk35xx' | head -1)
if [ -n "$DTB_DIR" ] && debugfs -R "ls boot/$DTB_DIR/rockchip" "$TMP/v.ext4" 2>/dev/null | grep -q agibot; then
	check "agibot dtb 在镜像(boot/$DTB_DIR/rockchip/)" OK
else
	check "agibot dtb 在镜像" FAIL
fi

echo ">>> (2) dtb 适配是否生效(5.10→6.1 compatible 字符串)"
if [ -n "$DTB_DIR" ]; then
	debugfs -R "dump boot/$DTB_DIR/rockchip/rk3588-agibot-mb0002-v2.dtb $TMP/v.dtb" "$TMP/v.ext4" 2>/dev/null
	[ -f "$TMP/v.dtb" ] && [ "$(fdtget "$TMP/v.dtb" /iommu@fdca0000 compatible 2>/dev/null)" = "rockchip,iommu-av1d" ] \
		&& check "iommu-av1d 适配" OK || check "iommu-av1d 适配" FAIL
else
	check "dtb 目录定位(无法验证适配)" FAIL
fi

echo ">>> (3) firmware / service / hostname / armbianEnv"
debugfs -R "stat lib/firmware/mali_csffw.bin" "$TMP/v.ext4" 2>/dev/null | grep -q Inode && check "mali_csffw firmware" OK || check "mali_csffw firmware" FAIL
debugfs -R "cat usr/lib/systemd/system/armbian-resize-filesystem.service" "$TMP/v.ext4" 2>/dev/null | head -1 | grep -q . && check "armbian-resize-filesystem.service" OK || check "armbian-resize-filesystem.service" FAIL
echo -n "  hostname: "; debugfs -R "cat etc/hostname" "$TMP/v.ext4" 2>/dev/null
echo -n "  fdtfile:  "; debugfs -R "cat boot/armbianEnv.txt" "$TMP/v.ext4" 2>/dev/null | grep fdtfile || echo "(无 fdtfile 行)"

echo
echo ">>> 结果: $pass 通过, $fail 失败"
[ "$fail" = 0 ] && echo "[OK] 镜像验证通过" || { echo "[FAIL] 有失败项,见上"; exit 1; }
