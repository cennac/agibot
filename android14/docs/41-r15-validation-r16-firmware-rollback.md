# Android 14 r15 validation and r16 firmware rollback

Date: 2026-08-26

## r15 runtime payload

r15 was flashed with RKDevTool v3.37 and booted successfully. The running
payload hashes matched the build output:

```text
/vendor/etc/firmware/BCM4362A2.hcd
18901a5bef1d418b6895e92d0afae36234f4160b237465dfca3d75e9844e93ef

/vendor/lib64/libbt-vendor.so
518cbaa3db1e987bd14f03adcbd5fe0d46c30313926a5b8669f9737a1b6610ff

/system_ext/priv-app/Settings/Settings.apk
c0dae190d611c74f33307113b5f215ae13795cd952c1ed8129330667eb1d4823

/product/etc/agibot/support-a-coffee.png
c977e9a01480e5600b6d63fc7ab5ee175ffdc4c9f0ddbda9c14b5b5507300d28
```

The support image was copied to
`/data/media/0/Pictures/AGIBOT/support-a-coffee.png`, retained the same hash,
and was indexed by MediaStore as `image/png` under `Pictures/AGIBOT/`.

The vendor init copy produced permissive SELinux denials when reading the
product file. The current image runs SELinux permissive, so the copy completed;
an explicit label/allow rule is still required before an enforcing build.

## Bluetooth address result

The controller address change passed completely. Vendor initialization logged:

```text
AGIBOT AP6275P: preserving controller OTP bdaddr
Controller OTP bdaddr B0:02:47:43:EA:3B
```

After Bluetooth was enabled, both `dumpsys bluetooth_manager` and Settings
reported `B0:02:47:43:EA:3B`. The stale synthetic
`persist.service.bdroid.bdaddr=22:22:*` property no longer overwrote the
controller.

## Windows discovery regression

The Windows peer was explicitly configured and verified as:

```text
Name=LAPTOP-BGDHCEIE
Address=BC:6E:E2:FB:2C:2C
Discoverable=True
Connectable=True
```

Android completed two classic inquiry cycles with `HCI_SUCCESS`, but both
returned zero classic results. LE scanning remained healthy and returned five
and six results respectively. No HCI timeout, fatal signal, or Bluetooth
process restart occurred. Because the PC was not discovered, no pairing request
was issued.

This is a direct regression from r14, where the same PC and Windows API setup
were discovered by name and type. The only r15 change capable of altering radio
behavior before discovery was the 80,602-byte `1012.1017` HCD. Validation under
Linux was therefore insufficient evidence that this HCD matches the Android
UART/vendor stack configuration.

Raw evidence is retained outside Git at:

```text
E:\AIPorject\101\android14-flash\validation\r15-bluetooth-firmware-bdaddr\
```

## r16 decision

r16 keeps every proven fix:

- AGIBOT-only OTP controller address preservation
- controller LPM disabled
- legacy scan command path
- vendor BLE offload clamps
- Settings author formatting and Gallery support image

It reverts only the r15 HCD change and restores the 91,900-byte firmware that
r14 proved could discover this Windows PC:

```text
Size:    91,900 bytes
SHA-256: f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3
```

Remote source commit:

```text
ecc4fa4 Revert "bluetooth: use board-validated BCM4362A2 firmware"
```

Replay patch:

```text
android14/patches/0031-vendor-revert-r15-bcm4362a2-firmware.patch
```

r16 requires one post-flash Windows test: confirm PC discovery, issue one
pairing request, and require a Windows PIN prompt plus `BOND_BONDED`.

## r16 build result

The remote build on `cennac@192.168.88.66` completed successfully on
2026-08-26. The log records `Making update.img OK` and `Make update image ok!`:

```text
/data/agibot-android14-build/logs/2026-08-26-r16-bluetooth-r14-firmware-otp-build.log
```

Both the source firmware and final product staging file were verified before
copying the image:

```text
Size:    91,900 bytes
SHA-256: f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3
```

The official image was copied to:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r16-bluetooth-r14-firmware-otp-official\agibot-mb0002-android14-r16-bluetooth-r14-firmware-otp-official-update.img
```

Image verification matched on the build host and Windows workstation:

```text
Size:    2,136,386,122 bytes
SHA-256: d8b297bd47dcc45a46517cb18de67bc7aa2a55c788bd2fb6e4dac79c2b52ce01
```

## Accidental r15 reflash smoke test

The board presented for the next validation still contained the r15 HCD
(`18901a5b...`), so it was not treated as an r16 Bluetooth result. The smoke
test nevertheless confirmed ADB, 1920x1080 at 60 Hz display, USB keyboard,
external 1080p camera enumeration, 30-minute screen timeout, OTP Bluetooth
address, Settings APK, and Gallery support image. Wi-Fi enabled and created
`wlan0`, but command-line association did not complete; it remains pending for
the r16 post-flash test. SELinux remains permissive.
