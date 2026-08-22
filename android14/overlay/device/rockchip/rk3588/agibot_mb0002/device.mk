# AGIBOT MB0002 V2 device policy.

DEVICE_PACKAGE_OVERLAYS += \
    device/rockchip/rk3588/agibot_mb0002/overlay

PRODUCT_CHARACTERISTICS := tablet
PRODUCT_AAPT_PREF_CONFIG := xhdpi

# Initial landscape/HDMI policy. Verify names against the RKR6 SurfaceFlinger
# implementation after the source checkout.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.hwrotation=0 \
    ro.surface_flinger.primary_display_orientation=ORIENTATION_0 \

# USB input is required for first boot on monitors/TVs.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml

# Placeholder for later vendor integration. It must not be enabled until the
# populated module is identified and its firmware/license path is approved.
# PRODUCT_PROPERTY_OVERRIDES += wifi.interface=wlan0
