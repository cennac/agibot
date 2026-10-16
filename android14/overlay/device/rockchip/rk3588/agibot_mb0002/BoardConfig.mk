BUILD_WITH_GO_OPT := false
BOARD_USES_AB_IMAGE := false
BOARD_BUILD_GKI := false

TARGET_BOARD_CPU := RK3588
BOARD_BLUETOOTH_SUPPORT := true
BOARD_HAVE_BLUETOOTH := true
BOARD_BLUETOOTH_LE_SUPPORT := true
BOARD_SUPPORT_HDMI_CEC := false
BOARD_HAVE_BLUETOOTH_AIC_USB := false
BOARD_HAVE_BLUETOOTH_AIC := false
TARGET_ROCKCHIP_PCBATEST := false

PRODUCT_KERNEL_DTS := rk3588-agibot-mb0002-v2
PRODUCT_KERNEL_CONFIG += rockchip_defconfig android-14.config agibot.config
BOARD_CAMERA_SUPPORT_EXT := true
BOARD_HS_ETHERNET := true

include device/rockchip/rk3588/BoardConfig.mk

# The common RK3588 config disables RKNN by default. Enable the complete
# Rockchip Android runtime/HAL after including it so the setting is not reset.
BOARD_RKNN_SUPPORT := true
