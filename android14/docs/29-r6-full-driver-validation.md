# r6 full device and driver validation

Date: 2026-08-26

## Image under test

- Image: `agibot-mb0002-android14-r6-camera-ap6275p-bluetooth-official-update.img`
- SHA-256: `0205411E4E3623B1F56A1704877A8AB619D71CEE15D653B83DDD0E776EB97B96`
- Device: `154c3268c6cdee4e` (`MB0002 V2`)
- Android: 14, locale `zh-CN`
- Kernel: 6.1.99, build `#10 Wed Aug 26 10:22:05 CST 2026`
- SELinux: permissive
- RAM reported by kernel: 15.57 GiB (`MemTotal: 16327856 kB`)

## Result summary

| Item | Result | Evidence / limitation |
| --- | --- | --- |
| Boot and ADB | PASS | `sys.boot_completed=1`; USB ADB remained stable. |
| Default language | PASS | Settings UI is Chinese and locale is `zh-CN`. |
| Author information | PASS | Settings shows `Cennac · cennac@163.com · cennac.com`. |
| Screen timeout | PASS | `screen_off_timeout=1800000` (30 minutes). |
| HDMI display | PASS | Connector is connected at 1920x1080p60; UI is visible and stable. |
| HDMI audio | PASS (software path) | Card 0 `rockchip-hdmi0`; `tinyplay` completed a 2-channel, 48 kHz, 16-bit test tone. Physical audibility still needs a person at the display to confirm. |
| Ethernet | PASS | `eth1` acquired `192.168.88.64/24` before the Wi-Fi isolation test. |
| Wi-Fi | PASS | Connected to `cc181003`, DHCP `192.168.88.184`, Wi-Fi 6, RSSI -56 dBm; IP and DNS pings had 0% loss. |
| Bluetooth | FAIL | Enable request succeeds but adapter remains OFF. HCI opens `/dev/ttyS6`, then Framework binding times out and the Bluetooth service dies. |
| USB enumeration | PASS | USB 2/3 hubs, keyboard `1c4f:0002`, and camera `1bcf:0b09` enumerate. No USB mass-storage device was connected, so media read/write was not tested. |
| Camera preview | PARTIAL | External provider exposes camera ID 100 and continuously returns frames; preview has an image. The image is upside down (`Facing: Front`, `Orientation: 90`). |
| Camera still capture | FAIL | Camera2 shutter test did not create a JPEG under `/sdcard/DCIM`. |
| Camera video recording | NOT TESTED | Still capture and orientation must be fixed first. |
| GPU | PASS | SurfaceFlinger actively reports Mali-G610, OpenGL ES 3.2; `/dev/mali0` and render node 128 are present. |
| NPU | PARTIAL | `/dev/dri/renderD129` exists and reports RKNPU driver v0.9.8. No RKNN test model/runtime binary was present for an inference test. |
| Hardware codecs | PARTIAL | Rockchip C2 AVC/HEVC/VP9/AV1 decoders and AVC/HEVC encoders are declared. No known media test clip was available for end-to-end decode/encode. |
| eMMC/data | PASS | Android data storage reports 228 GiB total, 227 GiB available; normal system writes and screenshots succeeded. |
| RTC | PASS (online) | RTC and system time agree on 2026-08-26; HYM8563 driver is bound. Power-loss retention was not tested. |
| Loader/Maskrom recovery | NOT RETESTED | Rebooting into recovery modes was deliberately excluded from a runtime driver test. |

## Wi-Fi validation

Android Settings displayed this policy while Ethernet was active:

```text
如要切换网络，请拔出以太网网线
```

The earlier `cmd wifi connect-network` failure was therefore not an AP6275P
driver or password failure. USB ADB was active, so `eth1` was temporarily
disabled and the saved network was selected from Settings. The result was:

```text
SSID: cc181003
BSSID: dc:d8:7c:52:04:51
IPv4: 192.168.88.184/24
Security: WPA2-PSK
Wi-Fi standard: 6
RSSI: -56 dBm
Tx link: 146 Mbps
Rx link: 258 Mbps
NetworkCapabilities: INTERNET, VALIDATED
```

Forced-interface connectivity:

```text
ping -I wlan0 -c 3 223.5.5.5     # 3/3, 0% loss
ping -I wlan0 -c 3 www.baidu.com # DNS resolved, 3/3, 0% loss
```

After testing, `eth1` was restored.

## Bluetooth failure details

The UART node and legacy HAL process exist:

```text
/dev/ttyS6  bluetooth:system 0660
android.hardware.bluetooth@1.0-service running
```

The failure sequence is:

```text
BluetoothManagerService: binding Bluetooth service
bt_userial_vendor: opening /dev/ttyS6
BluetoothManagerService: MESSAGE_TIMEOUT_BIND
BluetoothDeathRecipient::serviceDied
Could not find android.hardware.bluetooth.IBluetoothHci/default in the VINTF manifest
```

This points to an Android Bluetooth HAL/VINTF and Framework binding mismatch,
not to a missing UART node. The next image should align the declared Bluetooth
HCI HAL version/instance with the Framework expectation, then repeat firmware
download, adapter enable, scan and pairing tests.

## Camera failure details

Provider and streaming evidence:

```text
Number of camera devices: 1
Device 0 maps to "100"
Facing: Front
Orientation: 90
ExtCamDevSsn: processCaptureResult (continuous frames)
```

Required follow-up:

1. Correct the external-camera orientation metadata or transform for this board's physical mounting.
2. Diagnose Camera2 still-capture submission and JPEG output; no file was generated in `DCIM`.
3. After still capture passes, verify video recording, playback, audio synchronization and repeated open/close cycles.

## Artifacts

- Author screenshot: `E:\AIPorject\101\_tmp\r6-author-settings.png`
- Camera preview screenshot: `E:\AIPorject\101\_tmp\r6-camera-screen2.png`
- Wi-Fi connected screenshot: `E:\AIPorject\101\_tmp\r6-wifi-connected.png`

