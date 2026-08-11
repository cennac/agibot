#!/bin/bash
# Agibot MB0002 V2 (RK3588) rootfs 定制脚本 —— 在 chroot 内执行
# 参数: $1=RELEASE $2=LINUXFAMILY $3=BOARD $4=BUILD_DESKTOP $5=ARCH
#
# 关键机制：armbian 把 userpatches/overlay 只读 bind-mount 到 /tmp/overlay，
# 但【不会自动复制到 rootfs】—— 必须在这里显式 cp。
set -e

OVER=/tmp/overlay

# 1) 复制 overlay 的 etc / lib 到根（hostname、resize-rootfs.service、firmware）
cp -a "$OVER"/etc/. /etc/ 2>/dev/null || true
cp -a "$OVER"/lib/. /lib/ 2>/dev/null || true

# 2) 把适配 6.1 的 agibot dtb 放进内核 dtb 目录
#    /boot/dtb 是指向 dtb-<ver>-vendor-rk35xx 的 symlink，解析真实路径后写入
DTB_REAL="$(readlink -f /boot/dtb 2>/dev/null || true)"
[ -z "$DTB_REAL" ] && DTB_REAL="$(ls -d /boot/dtb-*-vendor-rk35xx 2>/dev/null | head -1)"
if [ -n "$DTB_REAL" ] && [ -f "$OVER/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb" ]; then
	mkdir -p "$DTB_REAL/rockchip"
	cp -v "$OVER/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb" "$DTB_REAL/rockchip/"
fi

# 3) 启用首次启动 rootfs 扩容
systemctl enable resize-rootfs.service 2>/dev/null || true

# 4) 清理备份文件（不该进镜像）
find /boot -name '*.510-orig' -delete 2>/dev/null || true

exit 0
