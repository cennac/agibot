include $(TOPDIR)/rules.mk

PKG_NAME:=rknn-runtime
PKG_VERSION:=2.3.2
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/rknn-runtime
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Rockchip RKNN userspace runtime for AGIBOT RK3588
  DEPENDS:=@TARGET_rockchip_armv8 +libstdcpp +gcompat
endef

define Package/rknn-runtime/description
  RKNN userspace runtime library and known-good test models for RK3588.
endef

define Build/Compile
endef

define Package/rknn-runtime/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) ./files/librknnrt.so $(1)/usr/lib/librknnrt.so
	$(STAGING_DIR_HOST)/bin/patchelf --add-needed libgcompat.so.0 \
		$(1)/usr/lib/librknnrt.so
	$(INSTALL_DIR) $(1)/usr/share/agibot/npu-test
	$(INSTALL_DATA) ./files/mobilenet_v1.rknn $(1)/usr/share/agibot/npu-test/
	$(INSTALL_DATA) ./files/resnet18.rknn $(1)/usr/share/agibot/npu-test/
endef

$(eval $(call BuildPackage,rknn-runtime))
