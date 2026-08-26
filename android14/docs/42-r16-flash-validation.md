# Android 14 r16 flash validation

Date: 2026-08-26

## Image and payload

r16 was flashed with RKDevTool v3.37 and booted normally. The running payload matched the build:

```text
Image:
E:\AIPorject\101\android14-flash\releases\2026-08-26-r16-bluetooth-r14-firmware-otp-official\agibot-mb0002-android14-r16-bluetooth-r14-firmware-otp-official-update.img

Size:    2,136,386,122 bytes
SHA-256: d8b297bd47dcc45a46517cb18de67bc7aa2a55c788bd2fb6e4dac79c2b52ce01

/vendor/etc/firmware/BCM4362A2.hcd
Size:    91,900 bytes
SHA-256: f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3

/vendor/lib64/libbt-vendor.so
SHA-256: 518cbaa3db1e987bd14f03adcbd5fe0d46c30313926a5b8669f9737a1b6610ff

/system_ext/priv-app/Settings/Settings.apk
SHA-256: c0dae190d611c74f33307113b5f215ae13795cd952c1ed8129330667eb1d4823

/product/etc/agibot/support-a-coffee.png
SHA-256: c977e9a01480e5600b6d63fc7ab5ee175ffdc4c9f0ddbda9c14b5b5507300d28
```

This confirms that the r15 80,602-byte HCD regression was removed while the OTP-address, LPM-disable, scan, author, and Gallery changes were retained.

## Platform smoke results

| Area | Result | Evidence |
|---|---|---|
| Boot and ADB | PASS | `sys.boot_completed=1`; USB ADB serial `154c3268c6cdee4e` |
| HDMI display | PASS | 1920x1080 at 60 Hz; `Display State=ON` |
| Ethernet | PASS | `eth1=192.168.88.187/24`; gateway/build-host pings 3/3, 0% loss |
| USB input | PASS | SIGMACHIP USB keyboard enumerated |
| UVC camera | PASS | One camera maps to device `100`; Camera2 opened an active client |
| HDMI audio | PASS (software) | `rockchip-hdmi0` drained 48 kHz stereo S16 LE through `tinyplay` |
| RTC | PASS (online) | RTC and system time both read 2026-08-26 09:18:23 |
| Storage/memory | PASS | 228 GiB shared storage, 227 GiB free; `MemTotal=16326476 KiB` |
| Screen timeout | PASS | `screen_off_timeout=1800000` |
| Author metadata | PASS | Properties/search expose all three Cennac values |
| Gallery image | PASS | MediaStore URI `1000000018`; Gallery resolved the VIEW intent |
| SELinux | PASS (permissive) | Enforcing policy remains future work |

Evidence is retained outside Git at `E:\AIPorject\101\android14-flash\validation\r16-bluetooth-r14-firmware-otp\`. The Settings search indexer normalizes the author summary to one indexed string; the compiled resource remains a literal three-line summary and the About-page screenshot is retained.

## Wi-Fi

The driver initialized `wlan0` with address `B0:02:47:43:EA:3A` and completed an active scan. Android listed six nearby BSSIDs, but the target SSID `cc181003` was absent.

A root `connect-network` request created saved network ID 0 and attempted remembered 2.4 GHz BSSID `dc:d8:7c:52:04:51`. Authentication timed out and `wlan0` never received an address. Windows was then used as an independent RF peer: `netsh wlan show networks mode=bssid` also saw only `HiWiFi_Cennac` on 5 GHz BSSID `dc:d8:7c:52:04:50`, not `cc181003`.

Wi-Fi scanning therefore passes. Association cannot be judged while the target SSID is not broadcasting; retest only after the 2.4 GHz BSSID is visible on an independent device.

## Bluetooth

Bluetooth was enabled from an OFF state. Vendor initialization retained the controller OTP address and disabled LPM:

```text
AGIBOT AP6275P: preserving controller OTP bdaddr
Controller OTP bdaddr B0:02:47:43:EA:3B
AGIBOT AP6275P: controller low-power mode disabled
```

The adapter was left idle for 30 seconds. Windows was explicitly made discoverable and connectable:

```text
Name=LAPTOP-BGDHCEIE
Address=BC:6E:E2:FB:2C:2C
Discoverable=True
Connectable=True
```

One Settings pairing scan rediscovered `LAPTOP-BGDHCEIE` as a computer. This confirms that restoring the r14 91,900-byte HCD fixed the r15 Classic discovery regression.

Two create-bond attempts entered `BOND_STATE_BONDING` and returned to `BOND_STATE_NONE` after about 5.1 seconds:

```text
09:00:30.192 -> 09:00:35.320  HCI_ERR_PAGE_TIMEOUT
09:01:10.065 -> 09:01:15.196  HCI_ERR_PAGE_TIMEOUT
```

Both failures occurred in the `GET_REM_NAME` stage before a PIN prompt. No Windows authorization dialog appeared. The Bluetooth process remained PID `2353`; there was no HCI command timeout, fatal signal, or service restart.

r16 passes initialization, OTP address preservation, idle stability, Classic discovery, and remote EIR reception. Pairing still fails at remote name/paging. Do not repeat the same Windows pairing test without another code or controller-configuration change; the next investigation should compare page timeout, remote-name request, and Windows connectable/ACL behavior rather than scan behavior.
