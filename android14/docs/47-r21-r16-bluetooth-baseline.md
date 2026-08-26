# Android 14 r21 exact r16 Bluetooth baseline

Date: 2026-08-26

## Decision

r18 through r20 tested three firmware candidates and two scan-policy changes,
but none restored the Classic receive result proven on r16.  Before making a
new radio change, r21 returns the complete AP6275P runtime to the exact r16
source state:

```text
HCD:                  91,900 bytes, AP6398-labelled r14/r16 payload
Firmware SHA-256:     f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3
Vendor BT_WAKE policy: notify deassert enabled
Product scan policy:   Android defaults, no six r18 override properties
```

This is deliberately a whole-baseline rollback rather than another HCD-only
candidate.  r16 remains the only release with direct HCI evidence that this
board received a Windows Classic Inquiry Result and remote EIR.

## Why the current Windows peer is no longer sufficient

The Windows adapter still reports:

```text
Name:          LAPTOP-BGDHCEIE
Address:       BC:6E:E2:FB:2C:2C
Discoverable:  True
Connectable:   True
```

However, Windows native Inquiry is not currently a trustworthy positive/negative
control.  The original probe passed `IntPtr.Zero` as its radio handle; after
changing it to open and pass the real Intel radio handle, Inquiry returned only
cached entries (`vivo TWS A4` and the cached unknown `B0:02:47:43:EA:3B`
address) and did not obtain a fresh device class or name for MB0002.  Keeping
the Windows Bluetooth settings page in the foreground while Android scanned
still produced no fresh result.  Restarting the Intel radio through WinRT did
not repair it, and a PnP device restart was denied because this shell is at
medium integrity.  Windows System event log also reports `BTHUSB` event 18:
Windows cannot store Bluetooth link keys on the local adapter.

Therefore, a failed Windows-only scan is not strong evidence that an Android
candidate is broken.  It is still useful as a positive control if it starts
returning devices, but acceptance requires an independently verified Classic
peer before declaring failure.

## Source rollback

The remote AOSP projects were left clean and the changes were made with normal
Git reverts, not reset or checkout:

| Project | r21 commit | Result |
|---|---|---|
| `vendor/rockchip/common` | `30c0c09` | Reverts `8052e68` and `19ae713`; restores the r16 91,900-byte HCD |
| `device/rockchip/rk3588/agibot_mb0002` | `bb29246` | Reverts `bd1d16b`; removes all six r18 scan overrides |
| `hardware/broadcom/libbt` | `3dae309` | Restores `BT_WAKE_VIA_PROC_NOTIFY_DEASSERT = TRUE` |

The current remote trees were compared directly with the corresponding r16
commits:

```text
vendor/rockchip/common diff ecc4fa4..HEAD:       empty
agibot device diff 8f29491..HEAD:                 empty
Broadcom libbt diff a59f43d^..HEAD:               empty
```

Replay patches:

```text
android14/patches/0036-vendor-restore-r16-ap6275p-firmware.patch
android14/patches/0037-device-restore-r16-classic-scan-defaults.patch
android14/patches/0038-broadcom-restore-r16-bt-wake-deassert.patch
```

Patch hashes:

```text
0036  d9e1b9e3ade416ecbbf670b17b285353d846cd7a3c9b42e84bc6d7c1a02ba5c0
0037  c433d2aa7b3e2e2cc7632204dcfc49b556ecb935c19a79f763bb6b6fd02ca371
0038  8dffae702328ad5cfba9b60a014974e69c7c63d10158d876ee0f970d8f8b22bb
```

## Build

The build started at 23:27 and rebuilt the affected vendor, product, system,
system-ext, and super partitions before running the official Rockchip
`./build.sh -u -J8` packaging flow.  It completed at 23:35.

The first launch used a PowerShell double-quoted SSH command.  Local expansion
removed the remote log-variable names, so the valid build process wrote its
output to the accidentally named file:

```text
/data/agibot-android14-build/aosp/ 2
```

The build itself was not interrupted.  Its complete output was copied unchanged
to:

```text
/data/agibot-android14-build/logs/2026-08-26-r21-r16-bluetooth-baseline-build.log
```

Build log SHA-256:

```text
96dff526ecea61901e7b81605bb6c29e1284f04caa094baeb9115cfb7a11d100
```

The log contains all four success markers:

```text
Making update.img  OK.
Make update image ok!
Make gpt image ok!
r21 build completed
```

The staged payloads match the intended r16 baseline:

```text
vendor HCD SHA-256:  f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3
32-bit vendor HAL:   762b17f8825a57945933cfd655dbc7d5f9982a9fc4e60dba4f7e6d36eccdb205
64-bit vendor HAL:   518cbaa3db1e987bd14f03adcbd5fe0d46c30313926a5b8669f9737a1b6610ff
```

## Official artifact

The official package was copied through SFTP and independently hashed on
Windows.  Build-host and local values match:

```text
Path:
E:\AIPorject\101\android14-flash\releases\2026-08-26-r21-r16-bluetooth-baseline-official\agibot-mb0002-android14-r21-r16-bluetooth-baseline-official-update.img

Size:    2,136,435,274 bytes
SHA-256: d6d339c8808c79c1adf57e14a5066ed1143ecc378a7a1103cff438c7c74ed03d
```

The release directory also retains the complete official build log and uses
the normalized dated directory/image naming convention.

## Acceptance

1. Verify the flashed HCD is exactly 91,900 bytes with SHA-256 `f7adf144...`.
2. Verify both `libbt-vendor.so` payloads match the r16 hashes from the r21
   build, not the r20 image.
3. Verify none of the six `bluetooth.core.classic.*` product properties exist.
4. Verify `vnd_buildcfg.h` compiled with BT_WAKE deassert notifications enabled
   and observe the r16 GPIO/idle behavior.
5. Confirm Android initialization, OTP address preservation, BLE reception,
   Wi-Fi, display, camera, USB, and RTC remain healthy.
6. Use an independently verified Classic discoverable peer for Classic Inquiry
   and pairing.  Windows is only a positive control until its own scanner sees
   nearby Classic devices again.
