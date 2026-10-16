# r22 independent Ubuntu peer validation

Date: 2026-08-27

## Purpose

Use an independently verified BR/EDR peer to remove Windows from the critical
path. This round answers two questions:

1. Can a peer that demonstrably exchanges Classic traffic with Windows receive
   the MB0002 controller's Classic advertisement data?
2. Can MB0002 receive Classic Inquiry results from that same peer?

No r22 source payload or image was changed during this investigation.

## Independent peer

The Ubuntu build host `192.168.88.66` uses controller `D8:3B:BF:CC:5D:D9`.
BlueZ reported it powered, discoverable, and pairable with no discoverable
timeout. Its local Classic identity was `Cennac-AI-7C73`.

The peer was validated before relying on it:

- Ubuntu received Windows `LAPTOP-BGDHCEIE` as a Classic Extended Inquiry Result.
- The result included address `BC:6E:E2:FB:2C:2C`, Class `0x2e410c`, RSSI about
  `-75 dBm`, complete name, TX power, and service UUIDs.
- The user subsequently confirmed that Ubuntu and Windows can establish a
  Bluetooth link. Windows is therefore a functional BR/EDR peer, not the cause
  of the MB0002 failure.

The key Ubuntu `btmon` capture is retained as:

```text
E:\AIPorject\101\android14-flash\validation\r22-classic-deep\ubuntu-btmon.log
```

## MB0002 to Ubuntu

Android r22 ran multiple 12.8-second Classic/LE discovery cycles while Ubuntu
remained continuously discoverable. The resulting Android btsnoop capture is:

```text
E:\AIPorject\101\android14-flash\validation\r22-classic-deep\ubuntu-peer-android-scan-btsnoop.log
```

Results were consistent across cycles:

```text
Classic Inquiry Result events: 0
LE results per cycle:          3-6
HCI Inquiry Complete status:   Success
```

Ubuntu's adapter identity and nearby Classic traffic were independently valid,
so the absence of Ubuntu from Android cannot be explained by an undiscoverable
peer or by Android only performing BLE scanning.

## Ubuntu to MB0002

A reverse capture was collected with Ubuntu `btmon` while Android Settings kept
MB0002 discoverable. The capture received neither a Classic Inquiry Result nor
an Extended Inquiry Result for board address `B0:02:47:43:EA:3B`; it did receive
multiple BLE advertisements from other devices in the same interval. This agrees
with the earlier Windows result: the board can be seen at address level by
Windows, but does not present normal EIR/FHS data, and a second independent peer
does not report it.

The reverse evidence is retained as:

```text
E:\AIPorject\101\android14-flash\validation\r22-classic-deep\ubuntu-peer-reverse-btmon-period-btsnoop.log
```

A direct BlueZ pairing command by address was not treated as a Page result:
`pair B0:02:47:43:EA:3B` returned `Device not available` because the device had
not first been created through discovery. The full transcript is in
`ubuntu-direct-pair.log`.

## Isolation tests

The following factors were tested without improving Classic reception:

- Wi-Fi rfkill was blocked and then restored to unblocked.
- The `bcmdhd` kernel module was manually unloaded.
- Three runtime HCD candidates were A/B tested:

```text
agibot-hcd-r15-80602.hcd
  size 80602 bytes
  SHA-256 18901a5bef1d418b6895e92d0afae36234f4160b237465dfca3d75e9844e93ef

agibot-hcd-r19-59061.hcd
  size 59061 bytes
  SHA-256 26ae849bb70e8d8e8e7571ef78c3c516a08dfda114d605d57daacdd72aad6aee

agibot-hcd-r20-73136.hcd
  size 73136 bytes
  SHA-256 3e4a1eddaf80f3e45f99e9c77b3cd84c85f605540da5f4f92300b80bca6d67ec
```

Each candidate kept the controller operational and BLE reception working, but
none restored Classic Inquiry results. The original r22 HCD was restored before
leaving this test branch:

```text
SHA-256 f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3
```

## State restoration

After the isolation tests, `bcmdhd` had been removed at runtime. The board was
rebooted and verified again:

```text
bcmdhd: loaded
wlan0: present, link/ether b0:02:47:43:ea:3a
ADB: online
```

The temporary HCD bind mounts were no longer present. Ubuntu discovery settings
should still be turned off before ending the session if not needed.

## Verdict

This is a board-side BR/EDR failure, not a Windows pairing-policy issue. The
most reliable boundary is now:

- Windows Classic TX/RX to Ubuntu: PASS, independently confirmed.
- MB0002 BLE scan/advertisement path: PASS.
- MB0002 Classic Inquiry reception: FAIL against an independently verified peer.
- MB0002 Classic discoverability/EIR presentation: FAIL or incomplete on two
  independent peers.
- r22 proc-read panic source: fixed and unrelated to BR/EDR RF behavior.

Android framework scan settings, normal scan parameters, one HCD file swap,
Wi-Fi rfkill state, and the loaded `bcmdhd` module have all been excluded as
sole causes.

## Next controlled experiment

The strongest remaining software discriminator is a complete return to the
historical r16 image, followed by the same Ubuntu peer test. Do not read the
unsafe r16 proc nodes while doing so.

- If r16 passes Classic against Ubuntu, a regression was introduced after r16 or
  the prior r16 result depends on hidden build/runtime state; diff r16 through
  r22 first.
- If r16 also fails, the historical usability claim is not reproducible and the
  investigation should prioritize controller configuration, RF front-end, antenna
  path, RF switch control, power supply, and board-specific Bluetooth GPIO/DTS.

## Evidence

```text
E:\AIPorject\101\android14-flash\validation\r22-classic-deep\
```

Key files:

```text
ubuntu-peer-android-scan-btsnoop.log
ubuntu-peer-reverse-btmon-period-btsnoop.log
ubuntu-btmon.log
ubuntu-btmon-wifi-block.log
bcmdhd-unloaded-btsnoop.log
hcd-runtime-ab-final-btsnoop.log
ubuntu-direct-pair.log
ubuntu-independent-bt-final.txt
ubuntu-independent-dmesg.txt
ubuntu-independent-final.png
hcd-candidates\
```
