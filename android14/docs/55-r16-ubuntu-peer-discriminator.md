# r16 Ubuntu peer discriminator

Date: 2026-08-27

## Purpose

The previous r22 tests left one unresolved software discriminator: whether the
historical r16 release still worked against an independently verified BR/EDR
peer. The board was therefore manually reflashed with the pinned r16 image and
tested against Ubuntu controller `D8:3B:BF:CC:5D:D9`.

r16 predates the r22 proc-read safety fix. The unsafe
`/proc/bluetooth/sleep/lpm` and `/proc/bluetooth/sleep/btwrite` nodes were not
read during this round.

## Exact image identity

The source image was:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r16-bluetooth-r14-firmware-otp-official\
agibot-mb0002-android14-r16-bluetooth-r14-firmware-otp-official-update.img
```

The complete update image was previously verified as:

```text
size    2,136,386,122 bytes
SHA-256 d8b297bd47dcc45a46517cb18de67bc7aa2a55c788bd2fb6e4dac79c2b52ce01
```

The boot partition is larger than the embedded r16 `boot.img`, so identity was
checked by copying exactly the embedded image length:

```text
embedded length:       39,751,680 bytes
runtime exact prefix:  39,751,680 bytes
SHA-256:               8c11394c81d473ca1a01bff78681006402c5a3568a0af62cf1a2ca7c6107ba7f
```

This matched the r16 package exactly. The full 39,800,832-byte partition read
had SHA-256 `322125d2c68ed0ff8c5234cf1ddad97ecceea36543b14b75683714977bfee8e8`;
the difference is trailing partition padding, not a different payload.

The running kernel was:

```text
Linux 6.1.99 #10 SMP PREEMPT Wed Aug 26 10:22:05 CST 2026
```

This is expected for r16: the later Bluetooth changes in the r14-r16 sequence
were userspace/firmware changes, while the r22 proc fix was the later kernel
change.

Runtime Bluetooth payloads matched the intended r16 baseline:

```text
/vendor/etc/firmware/BCM4362A2.hcd
91,900 bytes
SHA-256 f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3

/vendor/lib/libbt-vendor.so
SHA-256 762b17f8825a57945933cfd655dbc7d5f9982a9fc4e60dba4f7e6d36eccdb205

/vendor/lib64/libbt-vendor.so
SHA-256 518cbaa3db1e987bd14f03adcbd5fe0d46c30313926a5b8669f9737a1b6610ff
```

## Initial state

The board booted normally with:

```text
ADB serial:         154c3268c6cdee4e
sys.boot_completed: 1
locale:             zh-CN
screen timeout:     1800000 ms
```

`bcmdhd` was loaded, `wlan0` enumerated, and Ethernet was UP at
`192.168.88.113/24`. Bluetooth enabled cleanly:

```text
state:      STATE_ON
address:    B0:02:47:43:EA:3B
name:       MB0002 V2
crashes:    0
```

Ubuntu was independently verified as powered, discoverable, and pairable before
the scan.

## Android-to-Ubuntu

Android Settings' `Pair new device` screen was used so that the normal framework
discovery path issued the inquiry commands. The capture was retained as:

```text
E:\AIPorject\101\android14-flash\validation\r16-ubuntu-peer-20260827\
r16-android-scan-btsnoop.log

size    17,846 bytes
SHA-256 d7bc13bdd54e140d628674a0cf14b99494aca914e5000dec9fed61ab3b281df9
```

Packet counting found:

```text
HCI Inquiry commands:              5
HCI Inquiry Complete events:       4
Classic Inquiry Result events:     0
Classic Extended Inquiry events:   0
LE Meta events:                    116
```

The Settings UI showed no available remote device. Android therefore completed
real inquiry cycles and received BLE advertisements, but still did not receive
the independently discoverable Ubuntu peer.

## Ubuntu-to-Android

Android remained connectable and discoverable while Ubuntu ran a privileged
`btmon` capture and a 20-second BlueZ scan. Evidence:

```text
E:\AIPorject\101\android14-flash\validation\r16-ubuntu-peer-20260827\
ubuntu-reverse-btmon.log

size    51,004 bytes
SHA-256 6bdcbd1605bf579772bd07da7bf8cb9860510ec27e1f56b537bf9acc2fc9d687

ubuntu-reverse-bluetoothctl.log
SHA-256 25cf3db7adca713cf536893da841c69580ea376d592db38a56f91260d68bef0f
```

The capture contained:

```text
Inquiry commands:                    2
Inquiry Complete events:             1 before capture timeout
Windows Extended Inquiry Results:    2
Ubuntu references to MB0002 address: 0
```

Both Windows results identified `BC:6E:E2:FB:2C:2C` as
`LAPTOP-BGDHCEIE`, proving that the Ubuntu receiver and Classic inquiry path
were operational. No Classic or Extended Inquiry Result for
`B0:02:47:43:EA:3B` appeared.

After the test, Ubuntu scanning and discoverable mode were disabled. Android
returned to `SCAN_MODE_CONNECTABLE` with `Discovering: false` and remained
online over ADB.

## Verdict

The exact pinned r16 image does **not** reproduce usable Classic Bluetooth
against the independently verified Ubuntu peer:

- r16 boot and ADB: PASS.
- r16 Bluetooth initialization and OTP address: PASS.
- r16 BLE reception: PASS.
- r16 Classic Inquiry reception from Ubuntu: FAIL.
- Ubuntu reverse Classic discovery of r16: FAIL, while Windows appeared twice
  in the same capture.

This invalidates the assumption that r21/r22 introduced the Classic failure.
The historical r16 Windows success is either no longer reproducible or depended
on a peer/time-specific condition that did not exercise the same board-side
path. Since normal framework settings, HCD selection, Wi-Fi coexistence state,
Windows, Ubuntu, and now exact r16 have been excluded, the remaining priorities
are controller bring-up configuration, BR/EDR RF front-end/antenna/switch path,
module power, and board-specific GPIO/DTS wiring.

No additional r23 framework scan-property change is justified by this evidence.

## Evidence

```text
E:\AIPorject\101\android14-flash\validation\r16-ubuntu-peer-20260827\
```

Key files:

```text
r16-android-scan-btsnoop.log
ubuntu-reverse-btmon.log
ubuntu-reverse-bluetoothctl.log
bt-before.xml
bt-after.xml
bt-after.png
bt-final.png
```
