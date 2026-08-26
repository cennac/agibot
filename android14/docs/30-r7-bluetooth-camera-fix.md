# Android 14 r7 Bluetooth and camera fix

Date: 2026-08-26

## Scope

This source-only change prepares r7 to fix the two remaining r6 driver issues:

1. AP6275P Bluetooth initialization crashes because UART6 CTS is not wired.
2. The external USB camera preview is rotated 180 degrees from its physical mounting.

The patches were first prepared and checked without a build. After both checks
passed, they were applied to the remote SDK and an r7 build was started.

## Bluetooth root cause

The r6 image correctly exposes `/dev/ttyS6` as `0660 bluetooth system`, starts
`android.hardware.bluetooth@1.0-service`, powers the controller through the
Rockchip RFKill driver and opens the UART. The Android Bluetooth process then
aborts after its three-second stack initialization deadline:

```text
HciHalHidl: Trying to find a HIDL interface
bt_userial_vendor: opening /dev/ttyS6
assertion 'init_status == std::future_status::ready' failed
Can't start stack, last instance: starting HciHalHidl
```

The board's existing Linux validation established that the AP6275P Bluetooth
controller is a BCM4362A2 and responds immediately to raw HCI commands at
115200 baud only when `CRTSCTS` is disabled. UART6 CTS is not routed on the
MB0002 V2. With hardware flow control enabled, DesignWare UART transmission is
gated indefinitely and no HCI response reaches the HAL.

Rockchip's Android Broadcom library unconditionally did this in
`hardware/broadcom/libbt/src/userial_vendor.c`:

```c
vnd_userial.termios.c_cflag |= (CRTSCTS | stop_bits);
```

Patch `0017-broadcom-bt-disable-uart-flow-control.patch` explicitly clears
`CRTSCTS` while retaining the configured stop bits. Apply it from the
`hardware/broadcom/libbt` Git repository.

## Camera correction

r6 proves that the AIDL external provider streams frames and encodes JPEG:

```text
Camera ID: 100
createJpegLocked: encoded JPEG (ret:0) with Q:90 max size: 3145728
Image with uri: content://media/external/images/media/1000000024 was published
/sdcard/Pictures/IMG_20260826_032031.jpg (189902 bytes)
```

The earlier r6 report checked only `DCIM`; Camera2 writes this build's images to
`Pictures`. Still capture is therefore working and the report was corrected.

Patch `0018-common-external-camera-orientation.patch` changes the external
camera metadata from 90 to 270 degrees, applying the required 180-degree
correction. Apply it from `device/rockchip/common`.

## Patch application

```bash
cd /data/agibot-android14-build/aosp/hardware/broadcom/libbt
git am /path/to/0017-broadcom-bt-disable-uart-flow-control.patch

cd /data/agibot-android14-build/aosp/device/rockchip/common
git am /path/to/0018-common-external-camera-orientation.patch
```

Applied remote commits:

```text
hardware/broadcom/libbt: 3d60c85 broadcom: disable UART hardware flow control for AGIBOT
device/rockchip/common:   22a82285 camera: correct AGIBOT external camera orientation
```

Both patches passed `git apply --check` before `git am`.

## r7 build

Build host and source tree:

```text
192.168.88.66
/data/agibot-android14-build/aosp
```

Build command:

```bash
source build/envsetup.sh
lunch agibot_mb0002-userdebug
m -j8 vendorimage superimage
./build.sh -u -J8
```

Build log:

```text
/data/agibot-android14-build/logs/2026-08-26-r7-bluetooth-camera-build.log
```

The build started in the background at 2026-08-26 11:24 CST. The vendor and
super image stage completed successfully in 7 minutes 31 seconds, followed by
successful official `update.img` packaging.

Output checks:

```text
vendor/etc/external_camera_config.xml: Orientation degree="270"
vendor/lib64/libbt-vendor.so SHA-256:
3dd5e82642cd08ce9136970145553c75ce94125ca11cc5e3d14a81afac33c74b
```

Normalized Windows release:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r7-bluetooth-camera-orientation-official\agibot-mb0002-android14-r7-bluetooth-camera-orientation-official-update.img
Size: 2134977098 bytes
SHA-256: 47E1B15642587049DF93D0A7C5B023CB6E2514ADDFB74F3EE34789D1B5329B5B
```

The remote and local image hashes matched. At this point flashing and runtime
validation were still pending; source and image construction alone cannot prove
controller behavior.

## Validation update

The image was flashed manually through RKDevTool after an interrupted first
attempt. Full runtime results are recorded in
`31-r7-flash-full-validation.md`. In summary, UART/HCI startup, camera metadata,
still capture, network, display, media, GPU, USB, RTC, and eMMC passed. Real
Bluetooth discovery still fails on the separate `LE_ADV_FILTER` opcode timeout.

## Required r7 validation

1. Confirm Bluetooth reaches `STATE_ON` in less than three seconds without a native crash.
2. Confirm controller address `B0:02:47:43:EA:3B`, firmware completion, BLE scan and classic scan.
3. Pair and reconnect one real Bluetooth device if one is available nearby.
4. Confirm Camera2 preview is upright in the landscape UI.
5. Capture a JPEG and verify a non-zero file under `Pictures` or `DCIM`.
6. Record and play back a short video, including audio if the camera exposes a microphone.
7. Re-run Wi-Fi, HDMI, Ethernet, USB, GPU and RTC regression checks.
