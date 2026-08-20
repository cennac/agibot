include $(TOPDIR)/rules.mk

PKG_NAME:=ap6275p-firmware
PKG_VERSION:=20260820
PKG_RELEASE:=1
PKG_LICENSE:=Proprietary

include $(INCLUDE_DIR)/package.mk

define Package/ap6275p-firmware
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=AMPAK AP6275P Wi-Fi/BT firmware
  DEPENDS:=@TARGET_rockchip_armv8
endef

define Package/ap6275p-firmware/description
  AMPAK AP6275P module firmware for its BCM43752 PCIe Wi-Fi and BCM4362A2
  UART Bluetooth controllers. Installed under the mainline brcmfmac/btbcm names.
endef

define Build/Compile
	true
endef

define Package/ap6275p-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/brcm
	$(INSTALL_DATA) ./files/brcm/* $(1)/lib/firmware/brcm/
	$(LN) brcmfmac43752-pcie.txt \
		$(1)/lib/firmware/brcm/brcmfmac43752-pcie.agibot,mb0002-v2.txt
endef

$(eval $(call BuildPackage,ap6275p-firmware))
