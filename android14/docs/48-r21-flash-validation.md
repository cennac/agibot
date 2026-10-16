# Android 14 r21 flash validation

Date: 2026-08-26/27

## Image and flash

r21 was flashed with the official Rockchip update image:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r21-r16-bluetooth-baseline-official\agibot-mb0002-android14-r21-r16-bluetooth-baseline-official-update.img

Size:    2,136,435,274 bytes
SHA-256: d6d339c8808c79c1adf57e14a5066ed1143ecc378a7a1103cff438c7c74ed03d
```

RKDevTool recorded a complete write and the board booted Android normally.
The running payload was verified from the filesystem, not inferred from the
build fingerprint:

```text
BCM4362A2.hcd SHA-256:  f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3
32-bit HAL SHA-256:     762b17f8825a57945933cfd655dbc7d5f9982a9fc4e60dba4f7e6d36eccdb205
64-bit HAL SHA-256:     518cbaa3db1e987bd14f03adcbd5fe0d46c30313926a5b8669f9737a1b6610ff
```

None of the six r18 `bluetooth.core.classic.*` overrides are present.

## Functional matrix

| Area | Result | Evidence |
|---|---|---|
| Boot/ADB | PASS | `sys.boot_completed=1`; ADB serial `154c3268c6cdee4e` |
| Display | PASS | 1920x1080 landscape, display state ON |
| Ethernet | PASS | `eth1` active and reachable on the build LAN |
| Wi-Fi radio/association | PASS | `cc181003` visible; when Ethernet was temporarily down, WPA2 connected, obtained IP, and NetworkCapabilities reported VALIDATED |
| Ethernet/Wi-Fi selection | EXPECTED | With both networks up Android keeps the lower-cost wired default; it did not issue a Wi-Fi ClientMode request |
| USB | PASS | USB2/USB3 hubs, keyboard, and UVC camera enumerate |
| UVC camera | PASS | Camera ID 100, active 1920x1080 preview, 1021+ frames, JPEG capture |
| MediaStore | PASS | Captured URI `content://media/external/images/media/1000000028`; file `Pictures/IMG_20260826_160249.jpg`, 235196 bytes |
| Gallery support image | PASS | `Pictures/AGIBOT/support-a-coffee.png`, 2800x2140, 1404965 bytes, indexed |
| HDMI audio | PASS | MUSIC/SYSTEM routed to `AUDIO_DEVICE_OUT_HDMI`; AudioFlinger output is 48kHz stereo and records non-silent PCM power history |
| RTC | PASS | RTC and system time remained aligned |
| Memory/storage | PASS | 16 GiB visible; 228 GiB userdata available |
| Factory locale | PASS | `persist.sys.locale=zh-CN` |
| Screen timeout | PASS | `screen_off_timeout=1800000` |
| Bluetooth initialization | PASS | OTP address `B0:02:47:43:EA:3B`; no Bluetooth process crashes |
| BLE reception | PASS | Android-initiated scans produced LE reports |
| Classic Inquiry receive | UNRESOLVED | Four inquiry commands completed with `HCI_SUCCESS` but zero Classic result events |

Evidence directory:

```text
E:\AIPorject\101\android14-flash\validation\r21-r16-bluetooth-baseline\
```

Important added evidence:

```text
pstore\dmesg-ramoops-1
pstore\console-ramoops-0
camera-active-capture.txt
camera-preview3.png
IMG_20260826_160249.jpg
audio-flinger-hdmi.txt
mediastore-images.txt
power-30min.txt
network-final.txt
```

## Kernel panic root cause

One reboot during validation was recorded as:

```text
sys.boot.reason=kernel_panic,oops:_fatal_exception
```

The complete pstore record proves this was not a Windows pairing failure or an
HCI firmware crash. A validation command used `cat` to read:

```text
/proc/bluetooth/sleep/btwrite
```

The Rockchip proc handler incorrectly called `sprintf()` directly on the
user-space destination pointer. Under ARM64 PAN, that write from kernel mode
caused a level-3 permission fault:

```text
Unable to handle kernel access to user memory outside uaccess routines
Internal error: Oops: 000000009600004f
CPU: 6 PID: 2997 Comm: cat
pc : bluesleep_read_proc_btwrite+0x14/0x20
Call trace:
 bluesleep_read_proc_btwrite+0x14/0x20
 vfs_read
 ksys_read
 __arm64_sys_read
Kernel panic - not syncing: Oops: Fatal exception
```

The sibling `lpm` read handler contains the identical bug. The existing
`powerupkey` handler already uses `copy_to_user()` correctly. Accordingly, the
direct `cat` result is not a Bluetooth radio symptom, and no Windows pairing
conclusion can be drawn from the reboot that followed it.

## HDMI audio interpretation

`tinyplay` was not used for final acceptance because direct access attempts to
open an output already owned by AudioFlinger. The service-level evidence is
stronger: the selected output is HDMI, the HAL accepted 48kHz stereo writes,
and AudioFlinger's signal-power history contains real non-silent samples during
boot/notification and camera-shutter playback. This validates routing and the
ALSA output path without disrupting the framework.

## Remaining issue

r21 restores the r16 runtime exactly, but it still does not restore the r16
Classic Inquiry receive behavior. Android can send inquiry commands, and the
controller returns successful inquiry-complete events with no Classic results.
Windows remains an unsuitable negative control because its own native Inquiry
currently returns only cached entries. The next independent test peer must be
a device whose simultaneous discoverability is externally verified.

The proc-read kernel defect must also be fixed before treating any future
long-running Bluetooth validation as stable. That fix is tracked as r22.
