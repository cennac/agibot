# r22 reflash validation and image identity check

Date: 2026-08-27

## Scope

The board was reflashed while the intended controlled experiment was a return to
the historical r16 image. Runtime payload checks showed that the board actually
booted r22 again. This record separates that image-identity fact from the
Bluetooth retest, so the result is not mislabeled as an r16 result.

No source payload was changed during this validation.

## Actual image identity

The Android build fingerprint is not a reliable r16/r22 discriminator because
the product fingerprint did not version every later repack. Kernel and partition
hashes were therefore checked directly.

Running identity:

```text
ADB serial:                 154c3268c6cdee4e
sys.boot_completed:         1
Linux:                      6.1.99 #13 SMP PREEMPT Thu Aug 27 00:47:53 CST 2026
screen_off_timeout:         1800000
ro.product.locale:          zh-CN
```

The runtime boot partition was copied with `dd`:

```text
/data/local/tmp/boot-current.img
size    39,800,832 bytes
SHA-256 499a04147235d83188c503c617d18e68ff221fa271ec03a6e0458f61172bbbc0
```

The official r22 image was unpacked with the bundled Rockchip
`RKImageMaker`/`AFPTool` tools. Its embedded `boot.img` had the same size and
SHA-256, and `fc /b` reported no byte difference:

```text
r22 update.img:
E:\AIPorject\101\android14-flash\releases\2026-08-27-r22-bluetooth-proc-read-safety-official\
agibot-mb0002-android14-r22-bluetooth-proc-read-safety-official-update.img

r22 embedded boot.img SHA-256:
499a04147235d83188c503c617d18e68ff221fa271ec03a6e0458f61172bbbc0
```

For comparison, the intended r16 image was unpacked under the same official
tool path:

```text
r16 update.img:
E:\AIPorject\101\android14-flash\releases\2026-08-26-r16-bluetooth-r14-firmware-otp-official\
agibot-mb0002-android14-r16-bluetooth-r14-firmware-otp-official-update.img

r16 embedded boot.img:
size    39,800,832 bytes
SHA-256 8c11394c81d473ca1a01bff78681006402c5a3568a0af62cf1a2ca7c6107ba7f
```

Therefore the current boot partition is exactly r22, not r16. RKDevTool's log
shows a successful complete write at 07:58-07:59, but it does not identify the
selected source image; the runtime hash is authoritative.

The runtime Bluetooth payloads also match both r16 and r21/r22, because r21
deliberately restored the r16 Bluetooth payload:

```text
/vendor/etc/firmware/BCM4362A2.hcd
91,900 bytes
SHA-256 f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3

/vendor/lib/libbt-vendor.so
SHA-256 762b17f8825a57945933cfd655dbc7d5f9982a9fc4e60dba4f7e6d36eccdb205

/vendor/lib64/libbt-vendor.so
SHA-256 518cbaa3db1e987bd14f03adcbd5fe0d46c30313926a5b8669f9737a1b6610ff
```

The r22-specific proc-read fix remains present: reading
`/proc/bluetooth/sleep/lpm` and `/proc/bluetooth/sleep/btwrite` as the Android
shell user returns `Permission denied` without rebooting. No new pstore record
was created for these reads.

## Platform state

- ADB remained online and `sys.boot_completed=1`.
- Display 0 was ON at 1920x1080@60, rotation 0.
- `bcmdhd` was loaded and `wlan0` enumerated with address
  `b0:02:47:43:ea:3a`; Wi-Fi remained disabled by default.
- Ethernet passed: `eth1` was UP at `192.168.88.88/24` with the LAN gateway and
  DNS configured.
Storage and memory remained healthy: `/data` reported about 227 GiB free and
  `MemTotal` was about 16 GiB.
- The factory-default locale remained Simplified Chinese and the screen timeout
  remained 30 minutes.

## Android-to-Ubuntu Inquiry

Ubuntu controller `D8:3B:BF:CC:5D:D9` was kept powered, discoverable, and
pairable. Android Settings' `Pair new device` screen was used rather than a
raw shell shortcut. Its UI showed the local address
`B0:02:47:43:EA:3B`, and Bluetooth framework state was:

```text
state:      STATE_ON
address:    B0:02:47:43:EA:3B
name:       MB0002 V2
ScanMode:   SCAN_MODE_CONNECTABLE_DISCOVERABLE
crashes:    0
```

The system scan ran multiple automatic 12.8-second BR/EDR inquiry periods. The
resulting Android HCI capture was copied out as:

```text
E:\AIPorject\101\android14-flash\validation\r22-reflash-20260827\
r22-ui-scan-btsnoop.log

size    16,292 bytes
SHA-256 cc7f9dcec0714d818d1948efb70d8b2779e2af5954ce7695ce5c1c937059eeb6
```

Packet counting found:

```text
HCI Inquiry Complete events:       3
Classic Inquiry Result events:     0
Classic Extended Inquiry events:   0
LE Meta events:                    100
```

Thus the controller accepted and completed inquiry while receiving BLE
advertisements in the same capture, but no independently discoverable Ubuntu
Classic result reached Android.

## Ubuntu-to-Android reverse scan

Android was left connectable and discoverable. A privileged Ubuntu `btmon`
capture and a BlueZ 20-second scan ran simultaneously. The resulting capture:

```text
E:\AIPorject\101\android14-flash\validation\r22-reflash-20260827\
ubuntu-reverse-btmon.log

size    24,968 bytes
SHA-256 4d3c7092ac8122adea6193a6acfedfedaa6bf18fc04776e0f487ee0de591dc34
```

BlueZ output:

```text
E:\AIPorject\101\android14-flash\validation\r22-reflash-20260827\
ubuntu-reverse-bluetoothctl.log

SHA-256 f7c08ba57bc599cedb1cc7c306f39a2fa48cd157f6bbd4828290d578312b53d9
```

The capture completed two 10.2-second inquiry periods. It received Windows
`LAPTOP-BGDHCEIE` at `BC:6E:E2:FB:2C:2C` as a complete Extended Inquiry Result
with name and class, proving the peer receiver was active during the test. It
received no Classic or Extended Inquiry Result for `B0:02:47:43:EA:3B`.

After the test, Ubuntu discovery and discoverable mode were disabled. Android
returned to `SCAN_MODE_CONNECTABLE` with `Discovering: false`.

## Verdict

This retest reproduces the previous r22 result:

- r22 boot and proc-read safety: PASS.
- BLE receive path: PASS.
- Bluetooth process stability: PASS.
- Classic Inquiry from Android to an independently verified Ubuntu peer: FAIL.
- Ubuntu reverse Classic discovery of Android: FAIL, while Windows was visible
  in the same capture.

This round does **not** answer the planned r16 regression question because the
board was still running r22. The historical r16 experiment remains pending.

## Next action

Before the next flash, RKDevTool's selected firmware path must be confirmed as
the r16 file above and the tool's upgrade log should be started with a local
trace that records that exact path. After boot, verify that the boot partition
SHA-256 is `8c11394c81d473ca1a01bff78681006402c5a3568a0af62cf1a2ca7c6107ba7f`
before any Bluetooth result is accepted as r16 evidence.

## Evidence

```text
E:\AIPorject\101\android14-flash\validation\r22-reflash-20260827\
```

Key files:

```text
r22-ui-scan-btsnoop.log
ubuntu-reverse-btmon.log
ubuntu-reverse-bluetoothctl.log
bt-ui-before.xml
bt-scan.xml
bt-scan-after.xml
bt-scan.png
bt-scan-after.png
```
