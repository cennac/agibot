#!/bin/bash
# Agibot MB0002 V2 (RK3588) rootfs 定制脚本 —— 在 chroot 内执行
# 参数: $1=RELEASE $2=LINUXFAMILY $3=BOARD $4=BUILD_DESKTOP $5=ARCH
#
# 关键机制：armbian 把 userpatches/overlay 只读 bind-mount 到 /tmp/overlay，
# 但【不会自动复制到 rootfs】—— 必须在这里显式 cp。
set -e

OVER=/tmp/overlay

# 1) 复制 overlay 的 etc / lib / usr 到根（服务、板级工具、firmware）
cp -a "$OVER"/etc/. /etc/ 2>/dev/null || true
cp -a "$OVER"/lib/. /lib/ 2>/dev/null || true
cp -a "$OVER"/usr/. /usr/ 2>/dev/null || true
chmod 0755 /usr/local/sbin/agibot-usb-port-power 2>/dev/null || true
chmod 0644 /etc/systemd/system/agibot-usb-port-power.service 2>/dev/null || true
chmod 0755 /usr/local/sbin/agibot-bt-attach 2>/dev/null || true
chmod 0644 /etc/systemd/system/agibot-bt-attach.service 2>/dev/null || true

# 2) 把适配 6.1 的 agibot dtb 放进内核 dtb 目录
#    /boot/dtb 是指向 dtb-<ver>-vendor-rk35xx 的 symlink，解析真实路径后写入
DTB_REAL="$(readlink -f /boot/dtb 2>/dev/null || true)"
[ -z "$DTB_REAL" ] && DTB_REAL="$(ls -d /boot/dtb-*-vendor-rk35xx 2>/dev/null | head -1)"
if [ -n "$DTB_REAL" ] && [ -f "$OVER/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb" ]; then
	mkdir -p "$DTB_REAL/rockchip"
	cp -v "$OVER/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb" "$DTB_REAL/rockchip/"
fi

# 3) 让 DRM 按显示器 EDID 自动选择首选模式
# DTB 已把 HDMI PHY PLL 重新接回 display-subsystem,2560x1440@60 的
# VOP dclk 可精确得到 241.5MHz。保留其他 extraargs,清除旧镜像遗留的
# connector 强制参数,避免 DRM 跳过 EDID 首选模式。
if [ -f /boot/armbianEnv.txt ]; then
	EXTRAARGS="$(sed -n 's/^extraargs=//p' /boot/armbianEnv.txt | head -1)"
	NEW_EXTRAARGS=""
	for ARG in $EXTRAARGS; do
		case "$ARG" in
			video=HDMI-A-1:*) continue ;;
		esac
		NEW_EXTRAARGS="${NEW_EXTRAARGS:+$NEW_EXTRAARGS }$ARG"
	done
	sed -i '/^extraargs=/d' /boot/armbianEnv.txt
	printf 'extraargs=%s\n' "$NEW_EXTRAARGS" >> /boot/armbianEnv.txt
fi

# 4) 使用 Armbian 自带的 armbian-resize-filesystem 动态识别根分区
# 清理旧版镜像中写死 /dev/mmcblk0p2 的重复服务。
systemctl disable resize-rootfs.service 2>/dev/null || true
rm -f /etc/systemd/system/resize-rootfs.service

# 5) 启用 USB-A 端口供电、HDMI tty1 登录、蓝牙 hci_uart 挂载
systemctl enable agibot-usb-port-power.service 2>/dev/null || true
systemctl enable getty@tty1.service 2>/dev/null || true
systemctl enable agibot-bt-attach.service 2>/dev/null || true

# 6) VPU 用户态库(rockchip-mpp + librga 预编译产物,来源见 scripts/build-vpu-userland.sh)
#    overlay 只带真身 .so.0(SONAME=.so.1);Windows git 不可靠保存 symlink,
#    dev 链接在此重建 + ldconfig。开机自动 modprobe acm8625p 扬声器驱动。
cd /usr/local/lib
[ -f librockchip_mpp.so.0 ] && {
	ln -sf librockchip_mpp.so.0 librockchip_mpp.so.1
	ln -sf librockchip_mpp.so.1 librockchip_mpp.so
	ln -sf librockchip_vpu.so.0 librockchip_vpu.so.1
	ln -sf librockchip_vpu.so.1 librockchip_vpu.so
}
chmod 0755 /usr/local/bin/*_test /usr/local/bin/vpu_api_test 2>/dev/null || true
ldconfig
mkdir -p /etc/modules-load.d
echo acm8625p > /etc/modules-load.d/acm8625p.conf

# 7) 清理备份文件（不该进镜像）
find /boot -name '*.510-orig' -delete 2>/dev/null || true

exit 0
