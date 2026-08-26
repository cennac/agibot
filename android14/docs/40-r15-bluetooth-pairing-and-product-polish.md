# Android 14 r15 Bluetooth pairing and product polish

Date: 2026-08-26

## r14 Windows PC test result

The Windows test peer is the current development computer:

- Adapter: `Intel(R) Wireless Bluetooth(R)`
- Computer name: `LAPTOP-BGDHCEIE`
- Controller address: `BC:6E:E2:FB:2C:2C`

Windows Bluetooth APIs explicitly reported both `Discoverable=True` and
`Connectable=True`. Android discovered `LAPTOP-BGDHCEIE` as a computer, which
proved that r14 classic inquiry and remote EIR name reception worked.

Two pairing attempts under different Windows visibility conditions both
failed in the same place. Android transitioned from `BOND_NONE` to
`BOND_BONDING`, then received `HCI_ERR_PAGE_TIMEOUT` and returned to
`BOND_NONE`. Windows never displayed a PIN request. The anonymous Android log
address ended in `2C:2C`, matching the PC and excluding a stale discovery
record. This test must not be repeated without a firmware or address-source
change.

## Address and firmware findings

Android r14 generated and programmed a synthetic address:

```text
persist.service.bdroid.bdaddr=22:22:cd:11:08:00
```

Earlier images generated another `22:22:*` value, while Linux on this exact
board read the controller OTP address as `B0:02:47:43:EA:3B`. The Broadcom
vendor library was built with `USE_CONTROLLER_BDADDR = FALSE`, so the random
framework address overwrote the controller value during firmware setup.

The firmware comparison also found that r14 used an unvalidated 91,900-byte
AP6398 `1100.1189` HCD. r15 replaces it with the 80,602-byte `1012.1017` HCD
already validated with this board under Armbian/LEDE:

```text
SHA-256: 18901a5bef1d418b6895e92d0afae36234f4160b237465dfca3d75e9844e93ef
Version: HBCM43752A2 UART 37.4MHz Ampak AP6398 sLNA iLNA CL1 [1012.1017]
```

The original extracted AP6275P HCD is 59,061 bytes and identifies itself as
`0021.0023`; it remains archived for comparison but is not selected for r15.

## r15 source changes

Replay patches are applied in this order:

1. `0027-vendor-board-validated-bcm4362a2-firmware.patch`
2. `0028-broadcom-preserve-agibot-controller-bdaddr.patch`
3. `0029-settings-format-author-details.patch`
4. `0030-device-preload-support-image.patch`

Patch `0028` does not globally enable controller addresses. Existing products
compiled with `USE_CONTROLLER_BDADDR = TRUE` retain their behavior. With the
default `FALSE` configuration, only `ro.product.device=agibot_mb0002` reads and
preserves the controller OTP address; all other products keep the filesystem
address path.

The Settings author summary now renders as three lines:

```text
Cennac
cennac@163.com
cennac.com
```

The product also packages a landscape support image containing the original
WeChat and Alipay payment-code pixels beneath the separate heading
`欢迎支持一杯咖啡`. A product-specific init rule copies it to
`/data/media/0/Pictures/AGIBOT/support-a-coffee.png` after boot so Gallery apps
index it through shared storage. Copying to a read-only product media directory
alone would not reliably expose it through Gallery's external MediaStore query.

## Remote commits and build

```text
vendor/rockchip/common:     69abf54 bluetooth: use board-validated BCM4362A2 firmware
hardware/broadcom/libbt:    70a220d broadcom: preserve AGIBOT controller OTP address
packages/apps/Settings:     ae18ea7c97 Settings: format AGIBOT author details on separate lines
device/rockchip/rk3588:     8f29491 agibot: preload support image into Gallery storage
```

Targeted build log:

```text
/data/agibot-android14-build/logs/2026-08-26-r15-targeted-build.log
```

The targeted `libbt-vendor` and Settings build completed successfully in 5
minutes 28 seconds. Both 32-bit and 64-bit vendor libraries were linked and
Settings passed AAPT2, R8, signing, and installation.

The full partition and Rockchip packaging flow also completed successfully:

```text
m -j8 vendorimage productimage systemimage systemextimage superimage
./build.sh -u -J8
```

Build log:

```text
/data/agibot-android14-build/logs/2026-08-26-r15-bluetooth-firmware-bdaddr-product-build.log
```

The product output tree contains the support image, init rule, validated HCD,
new vendor library, and rebuilt Settings APK. No `FAILED`, compiler error, or
Ninja stop appears in either log.

Official flash artifact copied back to Windows:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r15-bluetooth-firmware-bdaddr-official\
agibot-mb0002-android14-r15-bluetooth-firmware-bdaddr-official-update.img

Size:    2,136,373,834 bytes
SHA-256: e725d1bc833feac9ed7572ad16fc77bd5cc8ffa420def068a7a9f4c099920b36
```

The hash was calculated independently on the remote build host and Windows and
matched exactly.

## Post-flash acceptance

After r15 is flashed, perform one controlled Windows pairing test only:

1. Confirm the runtime controller address is `B0:02:47:43:EA:3B`.
2. Confirm the r14 LPM-disable log is still present and idle for 30 seconds.
3. Make this Windows computer discoverable and connectable.
4. Start one Android pairing request and require a Windows PIN prompt.
5. Accept only `BOND_BONDED`; collect HCI/logcat once if page timeout remains.
6. Verify no HCI timeout, page timeout, or Bluetooth process crash.
7. Open About device and Gallery to verify the three-line author summary and
   support image.
