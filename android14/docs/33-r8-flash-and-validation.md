# r8 flash and runtime validation

Date: 2026-08-26

## Image under test

- Image: `E:\AIPorject\101\android14-flash\releases\2026-08-26-r8-bluetooth-apcf-fallback-official\agibot-mb0002-android14-r8-bluetooth-apcf-fallback-official-update.img`
- Size: 2,134,977,098 bytes
- SHA-256: `E1832A06C336B79ABEFE86F39AD837908B97A2CF79EA98B1AB890DE1F063134E`
- Device: `154c3268c6cdee4e` (`MB0002 V2`)
- Flash result: user completed the Loader upgrade; Android booted and ADB returned.

## Result summary

| Item | Result | Evidence / limitation |
| --- | --- | --- |
| Boot and ADB | PASS | `sys.boot_completed=1`; USB ADB remained stable. |
| r8 Bluetooth payload | PASS | Active `/apex/com.android.btservices` matches the built APEX hash; active library contains the new fallback string. |
| Default language | PASS | `ro.product.locale=zh-CN`; Settings and Camera UI are Chinese. |
| Author information | PASS | Properties expose `Cennac`, `cennac@163.com`, and `cennac.com`. |
| Screen timeout | PASS | `screen_off_timeout=1800000` (30 minutes). |
| HDMI display | PASS | 1920x1080 landscape at 60 Hz; connector is connected and enabled. |
| HDMI audio | PASS (software route) | `tinyplay` drained 44.1 kHz, two-channel, 16-bit PCM on card 0. Physical audibility still needs a listener. |
| Ethernet | PASS | `eth1` acquired `192.168.88.176/24`; forced IP ping had 0% loss and was restored after Wi-Fi isolation. |
| Wi-Fi | PASS | Connected to `cc181003` at `192.168.88.184`, Wi-Fi 6, RSSI -56 dBm, `VALIDATED`; IP and DNS pings had 0% loss. |
| Bluetooth enable | PASS | UART opens `/dev/ttyS6`; HCI initialization completes; adapter reaches stable `STATE_ON`. |
| APCF downgrade code | PASS | Runtime log reports `INVALID_HCI_COMMAND_PARAMETERS; disabling APCF support`. |
| Bluetooth discovery/pairing | FAIL | Real Settings discovery reproducibly aborts on HCI opcode `0xfd57`; service restarts and returns ON. |
| External camera metadata | PASS | Camera ID 100 reports `Facing: Front`, `Orientation: 270`. |
| Camera still capture | PASS | Cold launch completed first-run pages; captured a valid 209,575-byte EXIF JPEG at 1920x1080. |
| AVC encode | PASS | `screenrecord` produced a valid 3,445,580-byte MP4. |
| Codec inventory | PASS | Rockchip AVC/HEVC/VP9/AV1 decoders and AVC/HEVC encoders are registered. |
| GPU | PASS | Mali-G610 reports OpenGL ES 3.2; Mali and DRM render nodes exist. |
| NPU | PASS (driver node) | RKNPU driver v0.9.8 and render node 129 are present; no inference workload in this round. |
| USB enumeration | PASS | USB2/USB3 hubs, keyboard `1c4f:0002`, and UVC camera `1bcf:0b09` enumerate. |
| eMMC/data | PASS | `/data` is 228 GiB; a 128 MiB fsync write completed at 211 MB/s. |
| RTC | PASS (online) | RTC and system time agree; power-loss retention not retested. |
| Loader/Maskrom recovery | NOT RETESTED | No download-mode reboot was performed during runtime validation. |

## r8 payload identity

```text
/system/apex/com.android.btservices.apex
SHA256 f9336206aa4f889a39603766e79b17f8c4c38a7874535683aa5c0b15b022275f

/apex/com.android.btservices/lib64/libbluetooth_jni.so
SHA256 6d82373b0784191de8b8511728bd4e2e5cf3c794b40b913fba9f8e6e36b8725c
```

The active library contains `disabling APCF support`. The failure is therefore
in the selected repair strategy, not a stale image or failed flash.

## Bluetooth failure detail

Enable follows the expected path:

```text
userial vendor open: opening /dev/ttyS6
initialization complete with status: 0
LE_ADV_FILTER status INVALID_HCI_COMMAND_PARAMETERS; disabling APCF support
STATE_ON
```

The fallback callback therefore executes. Starting Settings discovery still
produces the original pending-command failure:

```text
BTA_DM_API_SEARCH_EVT
Timed out waiting for 0xfd57 (LE_ADV_FILTER)
Unhandled vendor specific event of type 0x57
assertion 'false' failed - Done waiting for debug information after HCI timeout
```

Two controlled reproductions changed the Bluetooth process:

```text
2364 -> 2585
3193 -> 3311
```

After each automatic restart, Bluetooth returned to `STATE_ON` and again logged
the APCF downgrade. The response reaches the LeScanningManager callback, but the
HCI command queue/timer for the initial vendor command is not cleared correctly.
Consequently, clearing capability flags after the response is too late and does
not prevent the later abort.

## r9 requirement

Do not issue the initial `LeAdvFilterReadExtendedFeatures` command on AP6275P.
The next patch must force `is_filter_supported_` false before the startup
capability probe, ideally with a board/product property, so all APCF commands
are skipped from the beginning. Keep the UART `CRTSCTS` fix unchanged.

## Camera and media artifacts

Local artifacts retained outside Git:

```text
E:\AIPorject\101\_tmp\r8-camera-preview.png
E:\AIPorject\101\_tmp\r8-camera-after-capture.png
E:\AIPorject\101\_tmp\r8-camera-capture.jpg
E:\AIPorject\101\_tmp\r8-display-codec-test.mp4
```

On-device media:

```text
/sdcard/Pictures/IMG_20260826_045520.jpg
/sdcard/Movies/r8-display-codec-test.mp4
```
