# r7 flash and full runtime validation

Date: 2026-08-26

## Image and flash

- Image: `E:\AIPorject\101\android14-flash\releases\2026-08-26-r7-bluetooth-camera-orientation-official\agibot-mb0002-android14-r7-bluetooth-camera-orientation-official-update.img`
- Size: 2,134,977,098 bytes
- SHA-256: `47E1B15642587049DF93D0A7C5B023CB6E2514ADDFB74F3EE34789D1B5329B5B`
- Device: `154c3268c6cdee4e` (`MB0002 V2`)
- Storage detected by RKDevTool: eMMC, 238552 MB

The first 11:46 attempt has a super-write start but no completion record and
the tool was restarted at 11:48. The manually completed retry began at 11:53:36,
wrote the sparse super image at offset `0x1fd400`, and logged
`下载固件成功` at 11:54:48. The repeated `IsDharaImage` error is triggered by
probing the intentionally tiny 4096-byte `vbmeta.img`; writing then continued
normally, so it is diagnostic noise rather than the flash failure.

The device booted from the new image and USB ADB remained available throughout
runtime validation.

## Result summary

| Item | Result | Evidence / limitation |
| --- | --- | --- |
| Boot and ADB | PASS | `sys.boot_completed=1`; device serial `154c3268c6cdee4e`; root ADB stable. |
| Default language | PASS | Global configuration is `[zh_CN]`; Settings and Camera2 UI are Chinese. |
| Author information | PASS | Properties expose `Cennac`, `cennac@163.com`, and `cennac.com`. |
| Screen timeout | PASS | `settings get system screen_off_timeout` returns `1800000` (30 minutes). |
| HDMI display | PASS | 1920x1080 landscape at 60 Hz; connector state is connected/enabled. |
| HDMI audio | PASS (software route) | Card 0 is `rockchip-hdmi0`; `tinyplay` drained a 44.1 kHz, 2-channel, 16-bit WAV. A 5-second MP4 also routed MediaPlayer playback to HDMI device 9. Physical audibility still needs a listener at the display. |
| Ethernet | PASS | `eth1` restored and acquired `192.168.88.166/24`; forced IP and DNS pings had 0% loss. |
| Wi-Fi | PASS | Connected to `cc181003` at `192.168.88.184`, Wi-Fi 6, RSSI -56 dBm, network `VALIDATED`; forced IP and DNS pings had 0% loss. |
| Bluetooth ON | PASS | UART opens `/dev/ttyS6`, HCI initialization completes, and adapter reaches stable `STATE_ON`. The r6 three-second HCI startup timeout is fixed. |
| Bluetooth discovery/pairing | FAIL | Real Settings “与新设备配对” reproducibly times out on HCI opcode `0xfd57` (`LE_ADV_FILTER`) and aborts `com.android.bluetooth`; the service restarts and returns to ON. |
| Camera preview/open-close | PASS | External camera ID 100 reopens after visiting Home; preview is active in Camera2. Metadata now reports `Facing: Front`, `Orientation: 270`. |
| Camera still capture | PASS | Camera2 produced `/sdcard/Pictures/IMG_20260826_040312.jpg`; pulled size 180,263 bytes, JPEG header valid, decoded dimensions 1920x1080. |
| Camera orientation | PASS (software evidence) | The vendor config and camera metadata both changed from 90 to 270 degrees. The local preview/capture artifacts are retained for final scene-level visual confirmation. |
| Camera video recording | NOT TESTED | Camera characteristics advertise video sizes through 1920x1080, but this Camera2 UI exposes no video/recording mode and no MP4 was produced. |
| AVC encode/playback | PASS | `screenrecord` produced a valid 5,121,625-byte MP4; a generated 1080p AVC/AAC clip played through `android.rk.RockVideoPlayer`, MediaPlayer started on HDMI device 9, and ended normally. |
| Hardware codec inventory | PASS | Rockchip C2 AVC/HEVC/VP9/AV1 decoders and AVC/HEVC encoders are registered as hardware-accelerated. |
| USB enumeration | PASS | USB2/USB3 hubs, keyboard `1c4f:0002`, and UVC camera `1bcf:0b09` enumerate. |
| GPU | PASS | Mali-G610 reports OpenGL ES 3.2 through SurfaceFlinger; `/dev/mali0` and render node 128 exist. |
| NPU | PASS (driver node) | RKNPU driver v0.9.8 and `/dev/dri/renderD129` are present. No RKNN workload was run in r7. |
| eMMC/data | PASS | Android `/data` reports 228 GiB total and 227 GiB available; a 256 MiB fsync write completed at 229 MB/s. |
| RTC | PASS (online) | RTC and system time both report 2026-08-26; HYM8563 remains bound. Power-loss retention was not retested. |
| Loader/Maskrom recovery | NOT RETESTED | Runtime validation deliberately did not reboot the board into a download mode. |

## Network isolation evidence

Both interfaces are up after testing:

```text
eth1  192.168.88.166/24  1Gbps/full, forced IP/DNS pings 0% loss
wlan0 192.168.88.184/24  Wi-Fi 6, RSSI -56 dBm, VALIDATED
```

Forced-route checks:

```text
ping -I eth1  -c 4 223.5.5.5     # 4/4, 0% loss
ping -I wlan0 -c 4 223.5.5.5     # 4/4, 0% loss
ping -I eth1  -c 3 www.baidu.com # 3/3, DNS resolved, 0% loss
ping -I wlan0 -c 3 www.baidu.com # 3/3, DNS resolved, 0% loss
```

`eth1` had been administratively lowered only to isolate the Wi-Fi test and was
restored before validation ended.

## Bluetooth fix and remaining blocker

r7 contains the expected vendor library:

```text
/vendor/lib64/libbt-vendor.so
SHA-256 3dd5e82642cd08ce9136970145553c75ce94125ca11cc5e3d14a81afac33c74b
```

Bluetooth startup now opens `/dev/ttyS6`, completes HIDL/HCI initialization in
about 1.9 seconds, and remains `STATE_ON`. This proves that disabling UART
`CRTSCTS` fixed the r6 flow-control deadlock; that patch must be retained.

A second, independent controller/stack mismatch appears when Settings starts
real discovery. The process changed from PID 3924 to 4152 during the repeated
test, and the stable sequence is:

```text
on_apcf_read_extended_features_complete:
  LE_ADV_FILTER status INVALID_HCI_COMMAND_PARAMETERS
Unhandled vendor specific event of type 0x57
Timed out waiting for 0xfd57 (LE_ADV_FILTER)
assertion 'false' failed - Done waiting for debug information after HCI timeout
```

The crash auto-restarts and Bluetooth returns to ON. The next repair should
disable or correctly cap LE advertising-filter/APCF offload in the Android
Bluetooth scanning path instead of reverting the UART flow-control change.

## Camera and media artifacts

Local artifacts retained outside Git:

```text
E:\AIPorject\101\_tmp\r7-camera-ready.png
E:\AIPorject\101\_tmp\r7-camera-after-capture.png
E:\AIPorject\101\_tmp\r7-camera-reopen.png
E:\AIPorject\101\_tmp\r7-camera-capture.jpg
E:\AIPorject\101\_tmp\r7-avc-aac-test.mp4
E:\AIPorject\101\_tmp\r7-about-settings.png
```

On-device media:

```text
/sdcard/Pictures/IMG_20260826_040312.jpg
/sdcard/Movies/r7-display-codec-test.mp4
/sdcard/Movies/r7-avc-aac-test.mp4
```

The JPEG header starts with `FF D8 FF E1`, contains EXIF, and decodes as a
1920x1080 image. The camera was closed to Home and reopened successfully; the
second preview screenshot is 1,379,827 bytes.

## Follow-up work

1. Patch the Bluetooth LE scanning/APCF path so unsupported `LE_ADV_FILTER`
   offload is not requested, then repeat enable, discovery, and pairing.
2. Add or use a Camera2 video-capable test client; the current first-party UI
   does not expose a recording mode even though the external camera reports
   video sizes.
3. Run an RKNN inference workload and loader/Maskrom recovery regression after
   the Bluetooth blocker is fixed.
4. Have a person at the display confirm audible HDMI audio and perform the
   final scene-level camera orientation sign-off.
