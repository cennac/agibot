# AGIBOT MB0002 V2 Android 14/RKR6 product definition.

PRODUCT_SHIPPING_API_LEVEL := 34
PRODUCT_DTBO_TEMPLATE := $(LOCAL_PATH)/dt-overlay.in
PRODUCT_SDMMC_DEVICE := fe2c0000.mmc
PRODUCT_BOOT_DEVICE := fe2e0000.mmc
PRODUCT_UBOOT_CONFIG := rk3588_defconfig rk3588-agibot-mb0002.config

# Phase 1 has neither validated cameras nor the RKR6 EVS sample's prebuilt
# dependency set. Set these before Rockchip common defaults are inherited.
ENABLE_EVS_SERVICE := false
ENABLE_EVS_SAMPLE := false

# The board exposes a standard UVC camera through the onboard USB hubs. Set
# this before inheriting Rockchip device.mk so its AIDL external provider,
# VINTF declaration, permissions and external-camera config are packaged.
BOARD_CAMERA_SUPPORT_EXT := true

include device/rockchip/common/build/rockchip/DynamicPartitions.mk
include device/rockchip/rk3588/agibot_mb0002/BoardConfig.mk
include device/rockchip/common/BoardConfig.mk
$(call inherit-product, device/rockchip/rk3588/device.mk)
$(call inherit-product, device/rockchip/common/device.mk)
$(call inherit-product, frameworks/native/build/tablet-10in-xhdpi-2048-dalvik-heap.mk)

DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# The inherited AOSP locale list starts with en_US. Move Simplified Chinese to
# the front so generated build metadata and first-boot setup default to zh-CN,
# while retaining every other locale supported by the base product.
PRODUCT_LOCALES := zh_CN $(filter-out zh_CN,$(PRODUCT_LOCALES))

PRODUCT_NAME := agibot_mb0002
PRODUCT_DEVICE := agibot_mb0002
PRODUCT_BRAND := AGIBOT
PRODUCT_MANUFACTURER := Agibot
PRODUCT_MODEL := MB0002 V2
PRODUCT_CHARACTERISTICS := tablet
PRODUCT_AAPT_PREF_CONFIG := xhdpi

# Keep optional/ambiguous board peripherals out of Phase 1. The external USB
# camera is intentionally enabled above; the unvalidated internal ISP remains
# disabled.
BOARD_CAMERA_SUPPORT := false
BOARD_GRAVITY_SENSOR_SUPPORT := false
BOARD_GYROSCOPE_SENSOR_SUPPORT := false
BOARD_PROXIMITY_SENSOR_SUPPORT := false
BOARD_LIGHT_SENSOR_SUPPORT := false
BOARD_HAVE_BLUETOOTH_AIC_USB := false
BOARD_HAVE_BLUETOOTH_AIC := false

PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=240 \
    ro.sf.hwrotation=0 \
    ro.surface_flinger.primary_display_orientation=ORIENTATION_0 \
    ro.vendor.hdmirotationlock=true \
    vendor.hwc.device.primary=HDMI-A \
    persist.sys.hdmi_dp_audio_output=1

# Expose immutable adaptation ownership for About device and support tooling.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.build.author.name=Cennac \
    ro.build.author.email=cennac@163.com \
    ro.build.author.website=cennac.com

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml
