include $(TOPDIR)/rules.mk

PKG_NAME:=agibot-bt-attach
PKG_VERSION:=1.0.0
PKG_RELEASE:=2
PKG_LICENSE:=GPL-2.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/agibot-bt-attach
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=AGIBOT MB0002 V2 Bluetooth attach helper
  DEPENDS:=@TARGET_rockchip_armv8 +kmod-bluetooth +kmod-hci-uart +bluez-utils
endef

define Package/agibot-bt-attach/description
  Attach AP6275P BCM4362A2 Bluetooth to ttyS6 using the HCI UART BCM protocol
  without CRTSCTS. The board's BCM nCTS input is unwired, so generic serdev and
  btattach flow-control paths permanently gate TX.
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CPPFLAGS) $(TARGET_CFLAGS) \
		-o $(PKG_BUILD_DIR)/agibot-bt-attach ./src/agibot-bt-attach.c \
		$(TARGET_LDFLAGS)
endef

define Package/agibot-bt-attach/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/agibot-bt-attach \
		$(1)/usr/sbin/agibot-bt-attach
	$(INSTALL_BIN) ./files/agibot-bt-attach.init \
		$(1)/etc/init.d/agibot-bt-attach
endef

$(eval $(call BuildPackage,agibot-bt-attach))
