# r6 Loader flash and camera validation

Date: 2026-08-26

## Image

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r6-camera-ap6275p-bluetooth-official\agibot-mb0002-android14-r6-camera-ap6275p-bluetooth-official-update.img
SHA-256: 0205411E4E3623B1F56A1704877A8AB619D71CEE15D653B83DDD0E776EB97B96
```

## Flash

The running r5 installation was online through ADB. The board entered RockUSB
Loader with:

```text
adb reboot bootloader
USB\VID_2207&PID_350B\154C3268C6CDEE4E
```

RKDevTool v3.37 detected one Loader device and identified Android 14, Loader
1.11 and RK3588. The complete-image Upgrade Firmware path completed:

```text
测试设备成功
校验芯片成功
获取FlashInfo成功
准备IDB成功
下载IDB成功
正在下载固件(100%)
下载固件成功
```

The board exited Loader automatically. ADB returned and
`sys.boot_completed=1` was observed.

## Camera

The external provider is now running:

```text
android.hardware.camera.provider-V1-external-service-rk
```

CameraService reports:

```text
Number of camera devices: 1
Number of normal camera devices: 1
Device 0 maps to "100"
Camera Provider HAL android.hardware.camera.provider.ICameraProvider/external/0-0
```

Camera2 was opened with:

```text
am start -W -n com.android.camera2/com.android.camera.CameraActivity
```

After completing the first-run page, the live preview displayed valid UVC
frames. CameraService showed Camera2 as an active client of camera ID 100.

Observed issue: the live image is inverted for the physical camera mounting.
The provider currently publishes the external camera with sensor orientation
90. Orientation correction remains a follow-up item; it does not block capture
or streaming.

## Initial regression checks

| Check | Result | Evidence |
| --- | --- | --- |
| Android boot | PASS | `sys.boot_completed=1` |
| Locale | PASS | `zh-CN` |
| Screen timeout | PASS | `1800000` ms |
| External camera enumeration | PASS | one public device, ID 100 |
| Camera live preview | PASS | Camera2 active client and visible UVC frames |
| AP6275P Wi-Fi driver | PASS (interface) | `wlan0` exists with MAC `b0:02:47:43:ea:3a` |
| Bluetooth UART permission | PASS | `/dev/ttyS6` is `0660 bluetooth system` |

Wi-Fi scanning/association, Bluetooth enable/pairing and the remaining driver
regression matrix are still to be tested.
