# RTC, AP6275P wireless, and screen-timeout repair

Date: 2026-08-26

## Scope

This round prepares the next AGIBOT MB0002 V2 Android 14 image after the r1
recovery validation. It enables the board RTC and AP6275P Wi-Fi/Bluetooth
wiring, packages the Bluetooth userspace components, and changes the factory
screen-off default from one minute to 30 minutes. The image is built and
packaged, but the changes in this document are not yet runtime-validated on the
board.

## Wiring provenance

The nodes were reconstructed from the original vendor Linux 5.10 device tree
and cross-checked against the working Armbian/LEDE board definitions:

| Function | Connection |
| --- | --- |
| HYM8563 RTC | I2C6 at `0x51`, interrupt GPIO3_PD2 |
| AP6275P Wi-Fi data | `pcie2x1l0` through `combphy1_ps` |
| PCIe reset | GPIO1_PB4 |
| PCIe 3.3 V enable | GPIO3_PC4 |
| Wi-Fi host wake | GPIO3_PC5 |
| Bluetooth UART | UART6, `/dev/ttyS6` |
| Bluetooth RTS | GPIO1_PA2 |
| Bluetooth reset | GPIO1_PA6 |
| Bluetooth wake | GPIO3_PB2 |
| Bluetooth host wake | GPIO2_PC4 |
| Bluetooth low-speed clock | HYM8563 32.768 kHz output |

The kernel already had `CONFIG_PCIE_ROCKCHIP_HOST`,
`CONFIG_PCIE_DW_ROCKCHIP`, and `CONFIG_RTC_DRV_HYM8563` enabled. The Rockchip
external Wi-Fi build also already produced `bcmdhd.ko`, so no new kernel config
symbol was required.

## Source changes

The board DTS now enables HYM8563, PCIe Wi-Fi power/reset/wake wiring, the
`wlan-platdata` AP6275P node, UART6, and the Rockchip Bluetooth platform-data
node. The device product enables classic Bluetooth and BLE and supplies:

```text
UartPort = /dev/ttyS6
FwPatchFilePath = /vendor/etc/firmware/
```

The SettingsProvider board overlay now contains:

```xml
<integer name="def_screen_off_timeout">1800000</integer>
```

This is a factory/default-database value. A clean flash or cleared Settings
Provider data gets 30 minutes. An upgrade that preserves `/data` retains the
user's existing timeout. The normal Display settings UI remains available for
later changes; the system is not forced permanently awake.

Replay patches:

```text
0011-kernel-agibot-enable-rtc-wireless.patch
0012-device-agibot-enable-ap6275p-bluetooth.patch
0013-device-agibot-default-screen-timeout-30-minutes.patch
```

Remote project commits:

```text
kernel-6.1:                 9a3fc9a48f4c arm64: dts: enable AGIBOT RTC and AP6275P wireless
device/rockchip/rk3588:     55b0a7537aea agibot:enable-AP6275P-Bluetooth
device/rockchip/rk3588:     dbdf095ae45e agibot:set-default-screen-timeout-to-30-minutes
```

## Build record

Host and workspace:

```text
Host: 192.168.88.66
Workspace: /data/agibot-android14-build/aosp
Product: agibot_mb0002-userdebug
Jobs: 8
```

The first kernel attempt did not source Android build configuration, leaving
`KERNEL_VERSION` and `KERNEL_DTS` empty and failing before compilation with
`kernel-: No such file or directory`. The corrected invocation was:

```bash
source build/envsetup.sh
lunch agibot_mb0002-userdebug
./build.sh -K -J8
```

It successfully built the kernel, DTB, external Wi-Fi and camera modules,
`resource.img`, `dtb.img`, `boot.img`, and `boot-debug.img`. The shell wrapper
used for that run had a quoting error in its final `exit` expression, but the
BSP itself reported both build stages successful and `Make image ok!`.

The product partitions were then built explicitly:

```bash
m -j8 vendorimage systemimage systemextimage odmimage superimage
```

This completed successfully in 7 minutes 53 seconds. After changing the screen
timeout, the affected resources and images were rebuilt with:

```bash
m -j8 SettingsProvider systemimage superimage
```

This completed successfully in 5 minutes 21 seconds. `aapt2 dump resources`
against the built `SettingsProvider.apk` reported `def_screen_off_timeout` as
`1800000`.

The complete flash image was produced only with the BSP's official Rockchip
flow:

```bash
./build.sh -u -J8
```

`Android Firmware Package Tool v2.2` reported `Make firmware OK!`, and
`rkImageMaker v2.23` reported `New image generated successfully!`.

## Static product verification

The built DTB contains the following nodes/identifiers:

```text
/i2c@fec80000/rtc@51
wireless-wlan
wireless-bluetooth
ap6275p
```

The product output contains:

```text
vendor/etc/bluetooth/bt_vendor.conf
vendor/etc/firmware/BCM4362A2.hcd
vendor/etc/permissions/android.hardware.bluetooth.xml
vendor/etc/permissions/android.hardware.bluetooth_le.xml
vendor/etc/init/android.hardware.bluetooth@1.0-service.rc
vendor/lib64/libbt-vendor.so
vendor_dlkm/lib/modules/bcmdhd.ko
```

The Broadcom patch RAM file is 91,900 bytes and the packaged board
`bt_vendor.conf` names `/dev/ttyS6`.

## Release artifact

```text
Local directory:
E:\AIPorject\101\android14-flash\releases\2026-08-26-r5-rtc-wireless-timeout30-official

File:
agibot-mb0002-android14-r5-rtc-ap6275p-timeout30-official-update.img

Remote SHA-256:
46CABF0029C2AD2C8D739444AF284045F5D57933B2530F33D6D95A0955848454
```

The local copy is 2,093,460,042 bytes. Its SHA-256 was recalculated after the
transfer and matches the remote hash above.

## RAM conclusion

The kernel System RAM address ranges total approximately 16 GiB. This is not
an Android property or an artificial DTS limit. Advertising 28 GiB in DTS
without the correct DDR initialization blob and confirmed physical capacity
would let the kernel access nonexistent memory and can cause immediate data
corruption or crashes. No memory-size change is made in this round.

## Runtime validation required

After flashing r5, validate at minimum:

1. HYM8563 probe, `/dev/rtc0`, read/write, and time retention across power loss.
2. PCIe enumeration, `bcmdhd` firmware load, `wlan0`, scan, association, DHCP,
   DNS, throughput, suspend, and resume.
3. Bluetooth HCI firmware download on UART6, adapter enable, inquiry, pairing,
   A2DP audio, BLE scan, suspend, and resume.
4. Settings UI timeout selection and the 30-minute default after clean data.
5. Regression checks for HDMI display/audio, Ethernet, USB, camera, media
   engines, GPU, eMMC, and RKNN.

Use SW9200 LOADER mode for recovery and avoid erasing IDB unless LOADER is not
available.
