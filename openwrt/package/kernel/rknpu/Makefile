include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=rknpu
PKG_VERSION:=0.9.8
PKG_RELEASE:=2
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/rknpu
  SUBMENU:=Other modules
  TITLE:=Rockchip RK3588 NPU driver for RKNN Runtime
  DEPENDS:=@TARGET_rockchip_armv8 +kmod-drm
  FILES:=$(PKG_BUILD_DIR)/rknpu.ko
  AUTOLOAD:=$(call AutoProbe,rknpu)
endef

define KernelPackage/rknpu/description
  Rockchip rknpu 0.9.8 DRM render-node driver, ported to the LEDE 6.12
  kernel while retaining the ioctl ABI required by RKNN Runtime.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	+$(KERNEL_MAKE) M=$(PKG_BUILD_DIR) modules
endef

$(eval $(call KernelPackage,rknpu))
