# Android 14 Maskrom Loader flash incident

Date: 2026-08-25

## Current board state

- Board: AGIBOT MB0002 V2 / RK3588
- UART: COM9, 1500000 baud, available for passive logging
- USB Rockusb: offline after the latest attempt
- ADB and Ethernet: offline
- No successful partition write occurred during this incident
- Physical access is required before another flash attempt

The active COM9 watcher that transmitted Ctrl+C every 80 ms was stopped. Do
not run an active U-Boot catcher while Rockchip Loader storage commands are in
progress. Use passive serial capture during flashing.

## Observed failure

RKDevTool v3.37 accepted the Android 14 image but failed before partition
download:

```text
正在下载EMMC固件
切换EMMC存储失败
```

RKDevTool v2.86 could download the selected loader to RAM, but its follow-up
protocol test failed:

```text
下载Boot成功
等待Maskrom成功
测试设备失败
```

UART proved that DDR and eMMC hardware initialization completed:

```text
LPDDR4, 2112MHz
Boot1 Release Time: Oct 17 2023 17:09:54, version: 1.11
SdmmcInit=2 0
BootCapSize=100000
UserCapSize=238552MB
UsbBoot
```

Therefore the immediate failure is the Loader-to-host USB protocol transition,
not an eMMC detection failure. The Android partitions were not reached.

## Image and loader evidence

The latest camera/author image originally carried this outer loader:

```text
SHA-256 7341BAB67073E9F36B124DA529BDB7266B315654C5DCC520A627B09120B786F0
```

For diagnosis, the outer RKFW loader was replaced with the board-validated
RK3588 SPL v1.16.113 loader:

```text
SHA-256 4CC43C2FF29E08B5491B4D52528346AA7DA6948128C17E670FF8A000029C9408
```

Repacked diagnostic image:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-25-r3-camera-author-unverified\agibot-mb0002-android14-r3-camera-author-v116113-unverified-update.img
SHA-256 4524793F9EBF78C3497A3B3BAB7130207C578E67C809467DEF9DEB98BFFF0E0B
```

Reverse unpacking confirmed that its outer loader matches v1.16.113 and that
the inner Android firmware payload remained byte-identical:

```text
firmware.img SHA-256 91E772D12F801F5730D8B40B565823F2B460C21B3D97025A437101B290FC06D6
```

The protocol test still failed, so the new build/package is not yet proven to
be the only cause. USB re-enumeration, the host driver/filter stack and the
physical connection remain in scope.

## Known-good recovery image

This image was flashed successfully twice on the same board from Maskrom and
booted Android 14 successfully:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-25-r1-zh-rknn-validated\agibot-mb0002-android14-r1-zh-rknn-validated-update.img
SHA-256 5BF4260E5FDEF6D40D5675CE334398DC58ACD1806A43889A7FDB695FE3CDE1F4
```

It is the first image to use for an A/B recovery test. It contains the default
Chinese locale and RKNN integration, but predates the external-camera and
author-information fixes.

## Next physical-access procedure

1. Keep COM9 connected for passive 1500000-baud logging only.
2. Power-cycle the board and reconnect the flash USB cable directly to a host
   USB port, without a hub.
3. Confirm Windows reports `VID_2207&PID_350B` as `Rockusb Device`.
4. Close all duplicate RKDevTool processes and detach any usbipd/WSL claim.
5. First attempt the SHA-256-pinned known-good Android image above.
6. If the old image also fails before partition download, investigate the USB
   cable/port and Windows Rockusb filter stack; do not rebuild Android again.
7. If the old image succeeds, boot and validate it, then rebuild the latest
   package using the known-good image's exact loader and packaging structure.
