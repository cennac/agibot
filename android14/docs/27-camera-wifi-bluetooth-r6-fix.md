# Android 14 r6 camera, Wi-Fi and Bluetooth fix

Date: 2026-08-26

## Scope

- Publish the USB external camera through Android CameraService.
- Build AP6275P/Broadcom `14e4:449d` Wi-Fi for PCIe only.
- Allow the Bluetooth HAL to open AP6275P UART `/dev/ttyS6`.
- Keep the r5 RTC, Chinese locale, author metadata and 30-minute screen timeout changes.

## r5 diagnosis

- `/dev/video0` and `/dev/video1` existed, but `dumpsys media.camera` reported zero cameras.
- `BOARD_CAMERA_SUPPORT_EXT := true` was ineffective because `BOARD_CAMERA_SUPPORT := false` prevented `camera_aidl.mk` from being inherited.
- The AP6275P PCIe endpoint enumerated as `14e4:449d`, but the existing `bcmdhd` module initialized its SDIO path and failed with `-19`.
- Bluetooth firmware and configuration were present, but `/dev/ttyS6` was `0600 root root`, so the Bluetooth HAL could not open it.

## Source changes

- `0014-device-package-external-camera-provider.patch`
  - Enables the aggregate camera packaging switch. Internal ISP sensors remain disabled by the board DTS.
- `0015-common-bluetooth-ttyS6-permission.patch`
  - Adds `/dev/ttyS6 0660 bluetooth system` to Rockchip ueventd rules.
- `0016-wifi-ap6275p-pcie-driver.patch`
  - Enables `CONFIG_BCMDHD_PCIE` and explicitly disables the inherited SDIO/USB bus selections.

Remote source commits:

- Device: `56f55a8 agibot:package-external-camera-provider`
- Common: `9c03bd48 ueventd:grant-bluetooth-access-to-ttyS6`
- Wi-Fi: `b5eb7bb bcmdhd:build-AP6275P-PCIe-driver`
- Wi-Fi bus exclusivity: `450d955 bcmdhd:build-AP6275P-PCIe-only`

## Build record

Build host and tree:

```text
192.168.88.66
/data/agibot-android14-build/aosp
```

The first kernel image step failed because `/usr/bin/env python` was unavailable. The host now has the global compatibility link:

```text
/usr/local/bin/python -> /usr/bin/python3
Python 3.14.4
```

The clean kernel build then completed. The first external Wi-Fi build exposed simultaneous PCIe and SDIO selections; after making the buses mutually exclusive, the AP6275P module built successfully with `dhd_pcie.o`, `dhd_pcie_linux.o` and `pcie_core.o`, and without the `dhd_sdio` implementation.

The Android partitions were built with:

```bash
m -j8 vendorimage systemimage systemextimage odmimage superimage
```

The build completed successfully in 8 minutes 56 seconds. Official packaging used:

```bash
./build.sh -u -J8
```

## Output verification

The staged vendor tree contains:

```text
vendor/bin/hw/android.hardware.camera.provider-V1-external-service-rk
vendor/etc/init/android.hardware.camera.provider-V1-external-service-rk.rc
vendor/etc/vintf/manifest/android.hardware.camera.provider-V1-external-service.xml
vendor/etc/permissions/android.hardware.camera.external.xml
vendor/etc/external_camera_config.xml
vendor/lib64/android.hardware.camera.provider-V1-external-impl-rk.so
```

Bluetooth output rule:

```text
/dev/ttyS6 0660 bluetooth system
```

Packaged Wi-Fi module:

```text
vendor_dlkm/lib/modules/bcmdhd.ko
SHA-256: 66c53fb28ac3f3f152750df7eb7cd4946e7f7400976cf6803e7db3aa8fcf23e7
```

Normalized Windows release:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r6-camera-ap6275p-bluetooth-official\agibot-mb0002-android14-r6-camera-ap6275p-bluetooth-official-update.img
Size: 2134977098 bytes
SHA-256: 0205411E4E3623B1F56A1704877A8AB619D71CEE15D653B83DDD0E776EB97B96
```

The remote and Windows hashes match.

## Post-flash test plan

1. Confirm boot completion and CameraService publication.
2. Open Camera2 with `am start -n com.android.camera2/com.android.camera.CameraActivity` only after at least one external camera is enumerated.
3. Test preview, still capture and video recording.
4. Verify `wlan0`, scan and association.
5. Verify Bluetooth adapter enable, scan and pairing.
6. Regress Ethernet, HDMI display/audio, RTC, USB, media decode and the 30-minute screen timeout.
