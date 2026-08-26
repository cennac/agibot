# r5 Loader flash and smoke test

Date: 2026-08-26

## Flash target

```text
Board: AGIBOT MB0002 V2 / RK3588
Serial console: COM9, 1500000 baud
Rockusb serial: 154C3268C6CDEE4E
Tool: RKDevTool v3.37
Image: agibot-mb0002-android14-r5-rtc-ap6275p-timeout30-official-update.img
SHA-256: 46CABF0029C2AD2C8D739444AF284045F5D57933B2530F33D6D95A0955848454
```

## Recovery-mode entry

The running r1 image exposed working ADB. `adb reboot bootloader` changed the
USB device to:

```text
USB\VID_2207&PID_350B\154C3268C6CDEE4E
Rockusb Device
```

RKDevTool reported one LOADER device. The complete-image upgrade path works in
this state, so IDB was not erased merely to force Maskrom. This preserves the
validated SW9200/Loader recovery path.

## Flash result

RKDevTool identified Android 14, Loader 1.11, and RK3588, then completed:

```text
测试设备成功
校验芯片成功
获取FlashInfo成功
准备IDB成功
下载IDB成功
正在下载固件(100%)
下载固件成功
```

The board left Rockusb, rebooted automatically, reappeared over ADB, and
reported `sys.boot_completed=1`.

## r5 identity checks

| Check | Result | Evidence |
| --- | --- | --- |
| Kernel | PASS | Linux 6.1.99, build `#8`, 2026-08-26 09:01:08 CST. |
| Default screen timeout | PASS | `settings get system screen_off_timeout` returned `1800000`. |
| Locale | PASS | `ro.product.locale=zh-CN`. |
| Author metadata | PASS | `Cennac`, `cennac@163.com`, `cennac.com`. |
| RTC | PASS (initial) | `/dev/rtc0` exists and is backed by `rtc-hym8563 6-0051`. Power-loss retention is not yet tested. |
| Ethernet | PASS (initial) | `eth1` is UP with carrier. |
| PCIe AP6275P | PASS | PCI function `0002:21:00.0` enumerated; Bluetooth detection reports Broadcom `14e4:449d` and AP6275P. |
| Wi-Fi interface | FAIL | No `wlan0`; Android leaves Wi-Fi disabled after HAL/driver initialization failure. |
| Bluetooth adapter | FAIL | Enable request succeeds at framework level, but adapter remains OFF and unconnected. |

## Wi-Fi failure evidence

The AP6275P PCIe endpoint is present, so the DTS controller/power path is much
closer to correct than the missing-interface result alone suggests. The loaded
bcmdhd driver nevertheless takes its SDIO platform path:

```text
dhd_wlan_init_gpio: WL_HOST_WAKE=-1
dhd_wlan_init_gpio: WL_REG_ON=-1
wifi_platform_bus_enumerate device present 1
Card detection to detect SDIO card!
failed to power up DHD generic adapter
_dhd_module_init: Exit err=-19
```

The next repair must select/build the Broadcom PCIe bcmdhd path for AP6275P
instead of relying only on the `wifi_chip_type` DTS string.

## Bluetooth failure evidence

The userspace integration reaches the correct board-specific stage:

```text
found device pid:vid :14e4:449d
PCIE WIFI identify sucess
check_wifi_chip_type_string : AP6275P
Attempt to load conf from /vendor/etc/bluetooth/bt_vendor.conf
userial vendor open: opening /dev/ttyS6
```

Firmware and configuration are present:

```text
/vendor/etc/firmware/BCM4362A2.hcd (91900 bytes)
UartPort = /dev/ttyS6
```

The immediate failure is:

```text
/dev/ttyS6: root root 0600
userial vendor open: unable to open /dev/ttyS6
Open: fd_count 0 is invalid
```

The next repair must add the correct ueventd ownership/mode for UART6 and then
retest reset/wake GPIO handling and firmware download.

## Conclusion

r5 flashed and boots reliably, and it validates the 30-minute default, Chinese
locale, author metadata, HYM8563 RTC, and AP6275P PCIe enumeration. Wi-Fi and
Bluetooth are not yet usable, but their failures are now reduced to specific
driver-bus selection and UART device-permission problems rather than unknown
board wiring.
