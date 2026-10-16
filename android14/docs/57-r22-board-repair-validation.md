# r22 board repair validation

Date: 2026-08-27

## Scope

The user repaired the board-side wireless path and reflashed the unchanged r22
official image. This validation separates three Classic Bluetooth requirements:

1. MB0002 can receive BR/EDR Inquiry Results.
2. A remote peer can discover MB0002.
3. A complete Classic pairing/page can be established.

Pairing was not attempted because the second requirement still failed and a
remote user was not available to accept a pairing dialog.

## Image identity

The board booted normally with:

```text
ADB serial:         154c3268c6cdee4e
sys.boot_completed: 1
Linux:              6.1.99 #13 SMP PREEMPT Thu Aug 27 00:47:53 CST 2026
locale:             zh-CN
screen timeout:     1800000 ms
```

The boot partition is 67,108,864 bytes physically. Its embedded r22 payload
length is 39,800,832 bytes. Reading exactly that prefix produced:

```text
SHA-256 499a04147235d83188c503c617d18e68ff221fa271ec03a6e0458f61172bbbc0
```

This matched the r22 package's embedded `boot.img`, and `fc /b` reported no
difference. Hashing the entire 64 MiB partition includes unrelated trailing
space and must not be compared with the shorter package payload.

The Bluetooth payload remained the intended r16 baseline restored by r21:

```text
/vendor/etc/firmware/BCM4362A2.hcd
91,900 bytes
SHA-256 f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3

/vendor/lib/libbt-vendor.so
SHA-256 762b17f8825a57945933cfd655dbc7d5f9982a9fc4e60dba4f7e6d36eccdb205

/vendor/lib64/libbt-vendor.so
SHA-256 518cbaa3db1e987bd14f03adcbd5fe0d46c30313926a5b8669f9737a1b6610ff
```

## Platform state

- ADB stayed online throughout the test.
- Display 0 was ON at 1920x1080@60.
- Ethernet was UP at `192.168.88.216/24`.
- `wlan0` enumerated with address `b0:02:47:43:ea:3a`.
- Author properties exposed `Cennac`, `cennac@163.com`, and `cennac.com`.
- Bluetooth initialized at OTP address `B0:02:47:43:EA:3B` as `MB0002 V2`;
  Bluetooth crashed zero times.
- The r22 proc nodes returned `Permission denied` instead of panicking when read
  by the Android shell user.

## Android Classic receive result: PASS

Ubuntu controller `D8:3B:BF:CC:5D:D9` was powered, discoverable, and pairable.
Android Settings' `Pair new device` screen ran repeated inquiry cycles.

Final HCI evidence:

```text
E:\AIPorject\101\android14-flash\validation\r22-board-repair-20260827\
r22-repair-android-scan-final-btsnoop.log

size:    35,464 bytes
SHA-256: 2e3db5857fe4a18bf115e8216e3e9353950b5c9cf01a16b9a580db8f7a09ff91
```

Packet counts:

```text
HCI Inquiry commands:              12
HCI Inquiry Complete events:       11
LE Meta events:                    330
Classic Extended Inquiry Results:  1
```

The Classic result was:

```text
address: BC:6E:E2:FB:2C:2C
name:    LAPTOP-BGDHCEIE
class:   0x00041c / computer
```

Android Settings displayed `LAPTOP-BGDHCEIE` under available devices. This is a
direct improvement over exact r16 and pre-repair r22, which received zero
Classic results under the same peer conditions.

Ubuntu itself did not appear in the Android UI during this run. Windows remained
the independently known Classic positive peer and proved that the repaired board
can now receive a complete Extended Inquiry Result.

## Ubuntu reverse discovery: FAIL

Android was left in `SCAN_MODE_CONNECTABLE_DISCOVERABLE`. Ubuntu ran a
privileged `btmon` capture and a 20-second BlueZ scan.

```text
E:\AIPorject\101\android14-flash\validation\r22-board-repair-20260827\
ubuntu-reverse-btmon.log

size:    46,288 bytes
SHA-256: 6809617711cad58e1d523154eb880f950685dc065ce3d927478b97731cfda6eb
```

Capture counts:

```text
Inquiry commands:                    2
Inquiry Complete events:             2
Windows Extended Inquiry Results:    2
MB0002 address references:           0
```

Ubuntu received Windows `LAPTOP-BGDHCEIE` twice with complete name and class,
but received no Classic or Extended Inquiry Result for
`B0:02:47:43:EA:3B`. Therefore the reverse discoverable/EIR path remains
broken even though the Android framework reported discoverable mode.

## Wi-Fi scan

Wi-Fi was enabled and a fresh scan returned seven nearby networks, including
`HiWiFi_Cennac` at 5320 MHz with RSSI -46 dBm. This proves the Wi-Fi scan RF
path is operational.

The target 2.4 GHz SSID `cc181003` was not broadcasting in the scan, so
association was not judged. Wi-Fi was disabled again after the test.

## Verdict

The board repair produced real progress:

- Android Classic Inquiry reception: PASS.
- BLE reception: PASS.
- Wi-Fi scan: PASS.
- r22 proc-read safety: PASS.
- Reverse Classic discoverability from MB0002: FAIL.
- Pairing/page: NOT TESTED because reverse discoverability failed.

Do not declare Bluetooth fully repaired. The remaining symptom is now narrowly
isolated to the board's outgoing Classic discoverable/EIR (and likely page)
transmission path, while incoming Classic reception and BLE work.

## Next investigation

Measure or inspect the AP6275P RF transmit path and control lines rather than
changing Android scan properties:

1. Compare BT RF switch/antenna path control states during discoverable mode.
2. Verify module TX supply and PA rail stability during Inquiry response/page.
3. Capture UART6 RTS/CTS and BT_WAKE during an incoming inquiry.
4. Compare the vendor reference image's firmware configuration and RF NVRAM if
   available.
5. Retest Ubuntu reverse discovery and then pairing only after MB0002 is visible
   as a named Classic device.

## Evidence

```text
E:\AIPorject\101\android14-flash\validation\r22-board-repair-20260827\
```

Key files:

```text
r22-repair-android-scan-btsnoop.log
r22-repair-android-scan-final-btsnoop.log
ubuntu-reverse-btmon.log
ubuntu-reverse-bluetoothctl.log
bt-after.xml
bt-after.png
bt-later.xml
bt-later.png
bt-final.png
```
