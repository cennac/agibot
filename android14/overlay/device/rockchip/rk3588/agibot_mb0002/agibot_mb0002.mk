# AGIBOT MB0002 V2 Android 14 product definition.
#
# This file is deliberately minimal until the locked Radxa/Rockchip source tree
# is synced and the exact vendor product inheritance chain can be verified.

$(call inherit-product, device/rockchip/rk3588/agibot_mb0002/device.mk)

PRODUCT_NAME := agibot_mb0002
PRODUCT_DEVICE := agibot_mb0002
PRODUCT_BRAND := AGIBOT
PRODUCT_MANUFACTURER := Agibot
PRODUCT_MODEL := MB0002 V2

PRODUCT_CHARACTERISTICS := tablet

# Userdebug is exposed through COMMON_LUNCH_CHOICES. A shippable variant is
# deferred until recovery and rollback behavior are defined.
