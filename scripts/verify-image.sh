#!/usr/bin/env bash
# verify-image.sh — 验证编译产物镜像(无需启动板子)。
# 用 debugfs 直接读 ext4 rootfs,检查 dtb / firmware / service / hostname 都进了镜像,
# 以及 dtb 5.10→6.1 适配是否生效。对应 BUILD-GUIDE §7。
#
# 用法:
#   bash scripts/verify-image.sh                # 自动找最新 *_Agibot_*.img
#   bash scripts/verify-image.sh <path-to.img>
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMG="${1:-}"
if [ -z "$IMG" ]; then
	IMG=$(ls -t "$ROOT"/armbian-build/output/images/*_Agibot_*.img 2>/dev/null | head -1)
fi
[ -n "$IMG" ] && [ -f "$IMG" ] || { echo "未找到镜像。用法: bash scripts/verify-image.sh <path-to.img>"; exit 1; }
echo ">>> 镜像: $IMG ($(du -h "$IMG" | cut -f1))"

command -v debugfs >/dev/null 2>&1 || { echo "缺 debugfs: sudo apt install e2fsprogs"; exit 1; }
command -v fdtget >/dev/null 2>&1 || { echo "缺 fdtget: sudo apt install device-tree-compiler"; exit 1; }
command -v cpio >/dev/null 2>&1 || { echo "缺 cpio: sudo apt install cpio"; exit 1; }

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
	for node in fe1b0000 fe1c0000; do
		[ "$(fdtget -t x "$TMP/v.dtb" "/ethernet@$node" rx_delay 2>/dev/null)" = "0" ] \
			&& check "ethernet@$node rx_delay=0" OK || check "ethernet@$node rx_delay=0" FAIL
	done
else
	check "dtb 目录定位(无法验证适配)" FAIL
fi

echo ">>> (3) firmware / service / hostname / armbianEnv"
case "$(basename "$IMG")" in
	Agibot-Armbian_*) check "镜像文件名品牌 Agibot-Armbian" OK ;;
	*) check "镜像文件名品牌 Agibot-Armbian" FAIL ;;
esac
debugfs -R "stat lib/firmware/mali_csffw.bin" "$TMP/v.ext4" 2>/dev/null | grep -q Inode && check "mali_csffw firmware" OK || check "mali_csffw firmware" FAIL
ACM_FW="$TMP/acm8625p_dsp_stereo_btl_48khz.bin"
ACM_SHA256="9a8d3d5542e2a32cada1716ad99efbba661ca31037e6590c2c32419f61ba4ac4"
debugfs -R "dump lib/firmware/acm8625p_dsp_stereo_btl_48khz.bin $ACM_FW" "$TMP/v.ext4" >/dev/null 2>&1
if [ -f "$ACM_FW" ] && [ "$(wc -c < "$ACM_FW")" -eq 90 ] && \
	[ "$(sha256sum "$ACM_FW" | cut -d' ' -f1)" = "$ACM_SHA256" ]; then
	check "ACM8625P DSP firmware (90B, SHA-256)" OK
else
	check "ACM8625P DSP firmware (90B, SHA-256)" FAIL
fi
if [ -n "$DTB_DIR" ]; then
	KVER="${DTB_DIR#dtb-}"
	INITRD="$TMP/initrd.img-$KVER"
	INITRD_ROOT="$TMP/initrd-root"
	mkdir -p "$INITRD_ROOT"
	debugfs -R "dump boot/initrd.img-$KVER $INITRD" "$TMP/v.ext4" >/dev/null 2>&1
	if [ -f "$INITRD" ]; then
		(cd "$INITRD_ROOT" && gzip -dc "$INITRD" | cpio -id --quiet \
			"usr/lib/firmware/acm8625p_dsp_stereo_btl_48khz.bin") 2>/dev/null
	fi
	ACM_INITRD_FW="$INITRD_ROOT/usr/lib/firmware/acm8625p_dsp_stereo_btl_48khz.bin"
	if [ -f "$ACM_INITRD_FW" ] && [ "$(wc -c < "$ACM_INITRD_FW")" -eq 90 ] && \
		[ "$(sha256sum "$ACM_INITRD_FW" | cut -d' ' -f1)" = "$ACM_SHA256" ]; then
		check "ACM8625P DSP firmware in initramfs" OK
	else
		check "ACM8625P DSP firmware in initramfs" FAIL
	fi
else
	check "ACM8625P DSP firmware in initramfs" FAIL
fi
debugfs -R "cat usr/lib/systemd/system/armbian-resize-filesystem.service" "$TMP/v.ext4" 2>/dev/null | head -1 | grep -q . && check "armbian-resize-filesystem.service" OK || check "armbian-resize-filesystem.service" FAIL
IMAGE_README="$TMP/agibot-README.md"
debugfs -R "dump usr/share/doc/agibot/README.md $IMAGE_README" "$TMP/v.ext4" >/dev/null 2>&1
if [ -f "$IMAGE_README" ] && grep -q '^# Agibot-Armbian for AGIBOT MB0002' "$IMAGE_README" && \
	grep -q 'cennac@163.com' "$IMAGE_README"; then
	check "镜像内开发历程 README 与作者邮箱" OK
else
	check "镜像内开发历程 README 与作者邮箱" FAIL
fi
debugfs -R "cat etc/issue" "$TMP/v.ext4" 2>/dev/null | grep -q '^Agibot-Armbian ' \
	&& check "/etc/issue 发行者 Agibot-Armbian" OK || check "/etc/issue 发行者 Agibot-Armbian" FAIL
debugfs -R "stat root/README.md" "$TMP/v.ext4" 2>/dev/null | grep -q '/usr/share/doc/agibot/README.md' \
	&& check "/root/README.md 文档入口" OK || check "/root/README.md 文档入口" FAIL
echo -n "  hostname: "; debugfs -R "cat etc/hostname" "$TMP/v.ext4" 2>/dev/null
echo -n "  fdtfile:  "; debugfs -R "cat boot/armbianEnv.txt" "$TMP/v.ext4" 2>/dev/null | grep fdtfile || echo "(无 fdtfile 行)"

echo
echo ">>> 结果: $pass 通过, $fail 失败"
[ "$fail" = 0 ] && echo "[OK] 镜像验证通过" || { echo "[FAIL] 有失败项,见上"; exit 1; }
