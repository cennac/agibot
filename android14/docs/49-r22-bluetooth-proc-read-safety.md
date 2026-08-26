# Android 14 r22 Bluetooth proc-read safety fix

Date: 2026-08-27

## Scope

r21 proved that a routine validation read of
`/proc/bluetooth/sleep/btwrite` could panic the kernel. r22 therefore changes
only the two unsafe Rockchip proc read handlers:

```text
/proc/bluetooth/sleep/lpm
/proc/bluetooth/sleep/btwrite
```

Both previously passed the user-space buffer directly to `sprintf()`. They now
return the same fixed message through the kernel-provided
`simple_read_from_buffer()` helper, which performs the required user-copy
handling and honors the file offset/count. The existing `powerupkey` handler
already used `copy_to_user()` and remains unchanged.

No Bluetooth firmware, HAL, scan property, device tree, audio, camera, display,
or power-policy variable is changed in r22.

## Source control

Remote kernel commit:

```text
0592db10e0b9ea373a94e1efde66418a9ef8c143
rfkill: safely handle Bluetooth proc reads
```

Reviewable replay patch:

```text
android14/patches/0039-kernel-fix-bluetooth-proc-read.patch
SHA-256: 8e7f5cdd6c2751f9a75075afa69f48cc2f49d47364fb1db059d08007198c21f4
```

The first local replay used the wrong symbol
`simple_read_to_buffer`; the kernel build caught it as an undeclared function.
The patch was corrected to `simple_read_from_buffer`, the unpushed remote
commit was amended, and both the failed attempt and retry remain in the r22
build log. This is intentional audit history, not a hidden clean rebuild.

## Build

The standard flow is:

```bash
source build/envsetup.sh
lunch agibot_mb0002-userdebug
./build.sh -K -J8
m -j8 vendorimage systemimage systemextimage odmimage superimage
./build.sh -u -J8
```

Build log:

```text
/data/agibot-android14-build/logs/2026-08-27-r22-bluetooth-proc-read-safety-build.log
```

The package must continue to use the official Rockchip `build.sh -u -J8` flow.
No custom repacker is permitted.

## Post-flash acceptance

1. Confirm the image contains kernel commit `0592db10e0b9`.
2. Read both proc nodes repeatedly with `cat`; they must return
   `unsupported to read` without rebooting or creating a new pstore Oops.
3. Confirm pstore does not grow a new `dmesg-ramoops` record for the read.
4. Re-run Bluetooth enable/disable and one scan; the proc fix must not alter
   firmware identity, OTP address, or wake behavior.
5. Re-check boot, display, Ethernet, Wi-Fi, UVC camera, HDMI audio, storage,
   Chinese locale, and the 30-minute screen timeout.
