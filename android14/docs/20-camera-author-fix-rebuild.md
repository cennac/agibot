# External camera and full dynamic-partition rebuild

## Scope

Runtime validation of the 2026-08-25 image identified three actionable items:

1. Linux enumerated the UVC camera but CameraService reported zero devices.
2. The image reused an old `super.img`, so author properties and the Settings
   author row were absent.
3. Rockchip's common `up_eth0` init service was rejected because init cannot
   transition to `/system/bin/busybox`.

The suspected NPU regression was also resolved during diagnosis. The installed
RKNN files match the known-good hashes; the shell-launched vendor demo requires
`LD_LIBRARY_PATH=/system/lib64:/vendor/lib64`. With that environment, 100
ResNet18 iterations passed at approximately 159-240 FPS using runtime 2.3.0 and
driver 0.9.8.

## Source changes

The AGIBOT product now sets `BOARD_CAMERA_SUPPORT_EXT := true` before inheriting
Rockchip product makefiles. This selects the existing RKR6 AIDL external camera
provider, service, VINTF declaration, external-camera feature permission and
`external_camera_config.xml`. Internal ISP camera support and EVS remain off.

Android EthernetService already manages interface state. The invalid BusyBox
`up_eth0` service was removed from the common init file.

Remote source commits:

```text
device/rockchip/rk3588: 05ee2dc agibot: enable external USB camera provider
device/rockchip/common: d07c4d57 init: let Android manage Ethernet interface state
```

Replay patches:

```text
android14/patches/0009-device-agibot-enable-external-camera.patch
android14/patches/0010-common-remove-up-eth0-service.patch
```

## Rebuild

Remote source root:

```text
/data/agibot-android14-build/aosp
```

Build command:

```bash
source build/envsetup.sh
lunch agibot_mb0002-userdebug
m -j8 systemimage vendorimage systemextimage odmimage superimage
./build.sh -K -J8
```

Build log:

```text
/data/agibot-android14-build/logs/2026-08-25-camera-author-full-rebuild.log
```

The dynamic partitions are deliberately rebuilt before packaging. This ensures
that the external provider, init RC update, `ro.build.author.*` properties and
Settings author row are all present in the new `super.img`; reusing the 07:19
image is not acceptable for this fix.

Build completion, artifact hashes, flash actions and post-flash CameraService,
author-property and boot-log results will be appended after each stage passes.
