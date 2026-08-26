# Android 14 r18 AP6275P Classic scan compatibility

Date: 2026-08-26

## r17 result

r17 successfully kept the MB0002 AP6275P `BT_WAKE` output asserted.  Runtime
GPIO inspection after more than ten minutes showed:

```text
bt_default_reset      out hi
bt_default_wake       out hi
bt_default_wake_host  in  lo IRQ
bt_default_rts        out lo
```

Android remained `SCAN_MODE_CONNECTABLE_DISCOVERABLE`.  HCI snoop also proved
that `Write Scan Enable (0x0C1A)` was sent with parameter `0x03` and completed
successfully.  Windows still did not list `MB0002 V2`, so r17 fixed its intended
wake defect but did not complete Classic inbound discovery acceptance.

## HCI parameter finding

The r17 controller initialization used Android's default Classic values:

```text
Inquiry Scan Activity: interval=0x0800, window=0x0012
Page Scan Activity:    interval=0x0400, window=0x0012
Inquiry Scan Type:     0x01 (Interlaced)
Page Scan Type:        0x01 (Interlaced)
```

The controller returned success for these commands, but successful command
completion does not prove correct over-the-air operation.  Older
Broadcom/Cypress firmware can advertise interlaced support while behaving
unreliably in that mode.  The default 0x0012 window also gives a very low scan
duty cycle.

## Live validation before source change

The following properties were applied temporarily on the running r17 device,
then Bluetooth was power-cycled and made discoverable again:

```text
bluetooth.core.classic.inq_scan_type=0
bluetooth.core.classic.inq_scan_interval=1024
bluetooth.core.classic.inq_scan_window=256
bluetooth.core.classic.page_scan_type=0
bluetooth.core.classic.page_scan_interval=1024
bluetooth.core.classic.page_scan_window=256
```

The resulting HCI snoop confirmed:

```text
Inquiry Scan Activity (0x0C1E): 00 04 00 01  # 0x0400 / 0x0100
Page Scan Activity    (0x0C1C): 00 04 00 01  # 0x0400 / 0x0100
Write Scan Enable     (0x0C1A): 03
```

No `Write Inquiry Scan Type=1` or `Write Page Scan Type=1` command appeared
after the restart, leaving the reset-default Standard scan type active.  All
commands completed without HCI timeout or Bluetooth process restart, and
`bt_default_wake` stayed high.

Evidence:

```text
E:\AIPorject\101\android14-flash\validation\r17-bt-wake-inbound-fix\btsnoop_hci-r18-live-tune.log
```

## r18 source change

Patch `0033-device-ap6275p-classic-scan-compat.patch` adds the six properties
to the MB0002 product.  It changes only this board and retains the r16 firmware,
r15 OTP address handling, and r17 BT_WAKE behavior.

## Official image

The r18 Android build and Rockchip `update.img` packaging completed
successfully on the build server.  The verified local release artifact is:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r18-classic-scan-compat-official\agibot-mb0002-android14-r18-classic-scan-compat-official-update.img
```

Artifact metadata:

```text
Size:    2,136,435,274 bytes
SHA-256: 068a33c66d5dfcef4f1db7235af3916a3cf415cdd5847372cb9489e3f2d018f7
```

The local SHA-256 was checked after SFTP transfer and exactly matches the
build-server artifact.  Build log:

```text
/data/agibot-android14-build/logs/2026-08-26-r18-classic-scan-compat-build.log
```

## Acceptance

1. Confirm the six properties exist in the flashed r18 build.
2. Confirm HCI activity is `0x0400/0x0100`, scan enable is `0x03`, and no
   interlaced scan-type write occurs after Bluetooth initialization.
3. Scan from a second independently verified Bluetooth device for at least
   30 seconds and require `MB0002 V2` to appear.
4. Pair once and require `BOND_BONDED`, with no `HCI_ERR_PAGE_TIMEOUT`.

The current Windows scanner showed no nearby devices at all even after its
Bluetooth radio was toggled off and on.  It is therefore retained as a future
test peer but is not accepted as the sole r18 over-the-air verdict.

## Flash validation

The official r18 image was flashed and booted on 2026-08-26.  The six product
properties were present with the intended values, and Android reported:

```text
Bluetooth: enabled / ON
Name:      MB0002 V2
Address:   B0:02:47:43:EA:3B
ScanMode:  SCAN_MODE_CONNECTABLE_DISCOVERABLE
```

The post-flash HCI snoop proved that the properties reached the controller:

```text
Inquiry Scan Activity: 0x0400 / 0x0100, Command Complete status 0x00
Page Scan Activity:    0x0400 / 0x0100, Command Complete status 0x00
Write Scan Enable:     0x03, Command Complete status 0x00
Inquiry Scan Type=1:   not sent
Page Scan Type=1:      not sent
```

GPIO state remained correct while the pairing page was open:

```text
bt_default_reset      out hi
bt_default_wake       out hi
bt_default_wake_host  in  lo IRQ
bt_default_rts        out lo
```

Evidence was saved at:

```text
E:\AIPorject\101\android14-flash\validation\r18-classic-scan-compat\btsnoop_hci-r18.log
```

The HDMI connector reported `connected`, the HDMI ALSA playback device and
Android HDMI audio route were present, and `/dev/video0` plus `/dev/video1`
were registered.  Wi-Fi and Bluetooth were both disabled by default after the
clean flash; Bluetooth was enabled explicitly for this validation.

Over-the-air acceptance remains unresolved.  Android found no nearby peer
during a 15-second pairing-page scan.  Windows Add Device also listed no
device at all during a separate 30-second scan, including no unrelated nearby
devices.  Therefore this Windows result cannot distinguish an MB0002 receive
fault from the already observed Windows scanner fault.  Acceptance items 3
and 4 still require a known-good independently verified peer.
