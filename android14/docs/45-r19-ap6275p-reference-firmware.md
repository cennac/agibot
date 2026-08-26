# Android 14 r19 AP6275P reference firmware correction

Date: 2026-08-26

## r18 failure isolation

r18 boots normally and applies all six standard Classic scan properties. HCI
snoop proves `Inquiry Scan Activity` and `Page Scan Activity` are
`0x0400/0x0100`, `Write Scan Enable` is `0x03`, and every command completes
successfully. `bt_default_wake` also stays high.

Windows independently discovers `ROSE OpenFeel`, while Android shows no peer.
With the Windows adapter explicitly set to `Discoverable=True` and
`Connectable=True`, Android still receives zero Classic Inquiry events:

```text
Inquiry Result (0x02):          0
Inquiry Result with RSSI (0x22): 0
Extended Inquiry Result (0x2f):  0
```

BLE reception remains active. The HCI log repeatedly contains the Windows
controller address `BC:6E:E2:FB:2C:2C`, proving that the antenna, UART receive
path, and LE receiver are operational.

A temporary test application called public `BluetoothDevice.createBond()` for
that known Windows address. It entered `BOND_BONDING`, then returned to
`BOND_NONE` after approximately 5.13 seconds with HCI reason `0x04`
(`HCI_ERR_PAGE_TIMEOUT`). The temporary application was uninstalled after the
test.

## BT_WAKE A/B result

The r17 permanent-high BT_WAKE policy was tested as a possible regression.
During an active Android pairing-page scan, `/proc/bluetooth/sleep/btwrite`
was explicitly deasserted and GPIO confirmed `bt_default_wake=LOW`. Five HCI
Inquiry commands completed, BLE still received the Windows address 30 times,
and all three Classic Inquiry result event types remained at zero.

BT_WAKE was restored high after the test. This excludes the r17 wake policy as
the cause of the Classic discovery failure, so r19 does not revert it.

Evidence:

```text
E:\AIPorject\101\android14-flash\validation\r18-classic-scan-compat\btsnoop_hci-r18-btwake-low-ab.log
E:\AIPorject\101\android14-flash\validation\r18-classic-scan-compat\btsnoop_hci-r18-direct-windows-pair.log
E:\AIPorject\101\android14-flash\validation\r18-classic-scan-compat\logcat-r18-direct-windows-pair.log
```

## Firmware mismatch

The selected r18 HCD is 91,900 bytes and identifies a different Ampak module:

```text
BCM43752A2 UART 37.4MHz Ampak AP6398 sLNA iLNA CL1 [Version: 1100.1189]
SHA-256: f7adf14413063f14b0204684fb67ddcd2ae6bca3120343cb9a5cab86a1a545c3
```

The original MB0002 vendor reference system contains a board-matching image:

```text
BCM43752A2 UART 37.4MHz Ampak AP6275P sLNA iLNA [Version: 0021.0023]
Size:    59,061 bytes
SHA-256: 26ae849bb70e8d8e8e7571ef78c3c516a08dfda114d605d57daacdd72aad6aee
```

Source provenance:

```text
E:\AIPorject\101\agibot-mb0002-analysis\vendor-reference\raw\rootfs\system\etc\firmware\BCM4362A2.hcd
```

Patch `0034-vendor-ap6275p-reference-firmware.patch` changes only this HCD.
The remote vendor repository commit is `8052e68`. r18 framework, OTP address,
LPM, BT_WAKE, scan compatibility, author, and product changes are retained.

## Build and official image

The incremental partition build and standard Rockchip packaging flow completed
successfully. The log contains `Making update.img OK`, `Make update image ok`,
and `Make gpt image ok`:

```text
/data/agibot-android14-build/logs/2026-08-26-r19-ap6275p-reference-firmware-build.log
```

The final product staging file was checked after the build and retained the
AP6275P reference firmware hash. The official image was copied to:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r19-ap6275p-reference-firmware-official\agibot-mb0002-android14-r19-ap6275p-reference-firmware-official-update.img
```

The build-host and Windows hashes match exactly:

```text
Size:    2,136,402,506 bytes
SHA-256: fd3b071b0bd653fb885aabfce81322491392e29e023615858229260d33eeada9
```

## Acceptance

1. Firmware download must complete and Bluetooth must remain ON.
2. Runtime firmware identification must contain `AP6275P` and `0021.0023`.
3. Android must discover `ROSE OpenFeel` or another independently visible
   Classic peer and receive at least one Classic Inquiry result event.
4. A Windows pairing request must progress past remote-name/page handling,
   produce a PIN prompt, and reach `BOND_BONDED`.
5. BLE scanning, Wi-Fi, and BT_WAKE stability must not regress.
