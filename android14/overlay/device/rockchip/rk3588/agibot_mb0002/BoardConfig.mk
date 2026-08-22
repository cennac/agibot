# AGIBOT MB0002 V2 board skeleton for the RK3588 Android 14 RKR6 tree.
#
# This is not a bootable board configuration until the kernel DTS and Rockchip
# common board rules are integrated. Values marked TODO must be resolved against
# the synced source rather than copied from ROCK 5C.

TARGET_BOARD_PLATFORM := rk3588
TARGET_BOOTLOADER_BOARD_NAME := agibot_mb0002
TARGET_PRODUCT_DEVICE := agibot_mb0002
TARGET_BOARD_DTS := rk3588-agibot-mb0002-v2

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_VARIANT := cortex-a76
TARGET_CPU_ABI := arm64-v8a

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_VARIANT := cortex-a76
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi

TARGET_USERIMAGES_USE_EXT4 := true
BOARD_USES_GENERIC_AUDIO := false

# Keep the original vendor early console. Android root and partition arguments
# are supplied by the Rockchip boot flow after the partition map is defined.
BOARD_KERNEL_CMDLINE += \
    earlycon=uart8250,mmio32,0xfeb50000 \
    console=ttyFIQ0 \
    androidboot.console=ttyFIQ0 \
    androidboot.hardware=agibot_mb0002

# TODO after source sync: inherit the verified RK3588 common BoardConfig and
# resolve kernel path, DTB path, SELinux, AVB, recovery, and partition values.
# Do not copy ROCK 5C flash offsets into these fields.
