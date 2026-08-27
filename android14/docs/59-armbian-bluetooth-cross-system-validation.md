# Armbian Bluetooth cross-system validation

Date: 2026-08-27 (Asia/Shanghai)

## Purpose

Use the known Armbian rollback image to determine whether the Bluetooth discovery problem is specific to Android r22 or is below the operating-system layer.

## Image and test hosts

- DUT: AGIBOT MB0002 V2, `192.168.88.89`
- Image: `Armbian-unofficial_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img`
- Image SHA-256: `2dc05ed4e388cb8187d2c4a92f8cc1de45926c70cd0a4b3a11c6b8cac411da91`
- Kernel: `6.1.115-vendor-rk35xx`
- Peer: Ubuntu `Cennac-AI-7C73`, `192.168.88.66`, controller `D8:3B:BF:CC:5D:D9`
- Windows peer: `LAPTOP-BGDHCEIE`, `BC:6E:E2:FB:2C:2C`

The minimal image did not include BlueZ user-space utilities. `bluez` and `rfkill` were installed from the configured Jammy repositories for this validation. No kernel, firmware, device-tree, or Bluetooth attach implementation was changed.

## Controller initialization

The custom attach service started successfully on UART6:

```text
agibot-bt-attach.service: active (running)
hci_uart BCM attached on /dev/ttyS6
```

Kernel and firmware state:

```text
Bluetooth: hci0: BCM4362A2
Bluetooth: hci0: BCM4362A2 'brcm/BCM4362A2.hcd' Patch
Bluetooth: hci0: BCM43752A2 UART 37.4MHz Ampak AP6398 sLNA iLNA CL1 [Version: 1012.1017]
Bluetooth: hci0: BCM4362A2 (000.017.017) build 1017
gpio-38  (|bt-reg-on)   out hi
gpio-106 (|bt-dev-wake) out hi
```

The controller was enumerated as:

```text
BD Address: B0:02:47:43:EA:3B
Bus: UART
UP RUNNING PSCAN ISCAN
HCI Version: 5.1
Manufacturer: Broadcom Corporation (15)
RX errors: 0
TX errors: 0
```

There were no failed systemd units.

## Receive test

Armbian ran both `bluetoothctl scan on` and `btmgmt find`. It received multiple nearby LE advertisements, including public and random addresses. A later 25-second `btmgmt find` received at least 12 devices, with RSSI values from approximately -76 to -105 dBm, and resolved `HUAWEI Band 9-37E`.

Result: controller initialization, UART receive, HCI event delivery, and BlueZ discovery are functional.

## Transmit test

The DUT was configured as follows:

```text
Alias: AGIBOT-ARMBIAN-BTTEST
Powered: yes
Discoverable: yes
Pairable: yes
BR/EDR: enabled
LE: enabled
Advertising: enabled
```

`btmgmt` confirmed `Set Advertising complete`; the controller simultaneously reported `connectable`, `discoverable`, `br/edr`, `le`, and `advertising` in its current settings.

The independent Ubuntu peer then stopped its old discovery session and performed a fresh all-transport `btmgmt find`. During the same scan it received:

- at least 16 LE devices;
- the Windows Classic device `LAPTOP-BGDHCEIE` at about -79 dBm;
- no event for DUT address `B0:02:47:43:EA:3B`;
- no event for name `AGIBOT-ARMBIAN-BTTEST`.

Result: a known-good independent receiver detected both LE and BR/EDR traffic but did not detect the DUT while the DUT controller reported successful Classic discoverability and LE advertising.

## Cold-ROM firmware A/B

The normal Armbian HCD was identified before testing:

```text
Size: 80602 bytes
SHA-256: 18901a5bef1d418b6895e92d0afae36234f4160b237465dfca3d75e9844e93ef
Patched build: 1017
```

Merely restarting the attach service did not reset controller RAM, so a real cold A/B was performed. The HCD was temporarily moved aside, the board was rebooted, and the kernel confirmed that the controller remained at `build 0000` with no patch file loaded. The HCD was immediately restored on disk before the RF test.

The ROM controller accepted the same connectable, Classic discoverable, and LE advertising configuration under alias `AGIBOT-COLD-ROM-BTTEST`. During the peer scan, Ubuntu again received the Windows Classic device (this time about -71 dBm) and multiple LE devices, but neither the DUT address nor alias appeared.

After the A/B, the board was rebooted normally. The service is active, the HCD SHA-256 is unchanged, and the controller is back on build 1017.

Result: the 80602-byte HCD and its build-1017 runtime patch are not the cause of the missing over-the-air transmission.

## Conclusion

The failure is reproduced on both Android r22 and Armbian with the same physical controller. It is therefore not credibly explained by Android framework, Android permissions, or the Android Bluetooth stack.

The current discriminator result is:

- Bluetooth power, UART6, HCI transport, firmware download, and receive path: working.
- Controller command path for Classic inquiry/page scan and LE advertising: accepted without HCI errors.
- Detectable RF transmission from the board: not observed by a validated external receiver.

The fault domain is now the DUT transmit side below the host Bluetooth stack. Candidates include RF front-end power, reference clock quality under transmit, RF switch/antenna-chain control, module soldering or damage, and the passive antenna path. The absence of external SMA antennas is not sufficient by itself to explain the fault: the Ubuntu peer is on the same desk and is detectable without an added external antenna. An antenna A/B remains useful when physical access is available, but it is not treated as the established root cause.

Do not spend another Android build cycle changing BlueZ/framework settings or swapping HCD files. The next software-accessible work should target controller vendor RF state and board GPIO/regulator state; the next physical work should measure 2.4 GHz TX or compare the RF/antenna path with a known-good board.

## Follow-up repair attempts

The following runtime A/B tests were performed from Armbian after the initial discriminator. Every temporary file change used a backup and an automatic restore path.

### Direct Test Mode

The DUT accepted the standard LE Transmitter Test command on channel 20 (2442 MHz), 37-byte PRBS9 payload:

```text
LE Transmitter Test, opcode 0x201e: status 0x00
LE Test End, opcode 0x201f: status 0x00
```

The test ran for eight seconds twice. The Intel AX201 peer rejected both legacy and enhanced receiver-test commands with `Command Disallowed (0x0c)`, so that peer could not provide a valid packet counter. This test proves that the Broadcom controller enters its internal TX test state, but it does not prove that RF leaves the module.

### Wi-Fi power and coexistence

Keeping `wlan0` powered and initialized did not change Bluetooth visibility. Wi-Fi scanned at least eight access points before the external Bluetooth scan.

The actual AP6275P Wi-Fi NVRAM was then reloaded with each of these temporary changes:

```text
btc_mode=0
btc_prisel_ant_mask=0x1
```

The baseline is `btc_mode=1` and `btc_prisel_ant_mask=0x2`. Neither disabling PTA coexistence nor selecting the alternate priority antenna made the DUT visible to the Ubuntu peer. The original NVRAM was restored after each test.

### Wi-Fi transmit discriminator

The DUT successfully completed WPA2 association to `cc181003` on 2412 MHz. Live link statistics showed:

```text
signal: -56 dBm
RX: 3 packets
TX: 57 packets
TX bitrate: 270.5 Mbit/s
```

This is important because WPA association requires over-the-air transmission. AP6275P module power, its 2.4 GHz reference, and at least one RF transmit chain therefore work. The remaining failure is specific to the Bluetooth TX path or its RF routing, rather than a total module RF/power failure.

### GPIO comparison

The decoded vendor device tree and both adapted operating systems agree on the Bluetooth wiring:

```text
BT_REG_ON:   GPIO1_A6, active high
BT_WAKE:     GPIO3_B2, active high
HOST_WAKE:   GPIO2_C4, active high
UART6 RTS:   GPIO1_A2
```

There is no evidence of a swapped wake/reset pin or polarity in the adapted DTS.

### Updated repair boundary

No tested software setting restored Bluetooth transmission, so none of these experimental changes should be included in a release image. The board was left on build 1017 with the original HCD and NVRAM restored.

The highest-probability remaining causes are inside the Bluetooth-specific RF output path: module-internal BT RF switching/calibration, the BT-side matching network, soldering, or the path from the module to the relevant antenna connector. A spectrum analyzer or a known-good-board voltage/RF comparison is now more discriminating than another OS build.

## Confirmed module and controller identity

The wireless hardware identity is now confirmed at three independent layers:

```text
Module:                 AMPAK AP6275P
Wi-Fi PCIe vendor:      0x14e4 (Broadcom)
Wi-Fi PCIe device:      0x449d (BCM43752 family)
Bluetooth ROM identity: BCM4362A2
Bluetooth patch banner: BCM43752A2 UART 37.4MHz Ampak AP6275P
Bluetooth manufacturer: Broadcom, HCI manufacturer 15
Bluetooth address:      B0:02:47:43:EA:3B
```

`BCM4362A2` and `BCM43752A2` are two identification layers of the same combo
controller, not two Bluetooth devices. The former is the ROM/HCI identity and
firmware filename used by Linux; the latter is the silicon/patch family printed
by the loaded firmware.

## Live coexistence parameter A/B

A small ARM64 `dhdutil` was built from the LineageOS Broadcom WLAN sources so
the running BCM43752 Wi-Fi firmware could be queried directly. The initial
version contained an argument-validation error in the indexed IOVAR handler;
after correcting it, the deployed binary was:

```text
SHA-256: 69d4a62dbe7eb5129bfecfb0914c909f15e953b7ff15b2a5a893daab7de83282
```

The real runtime baseline was read back as:

```text
btc_mode=1
btc_params[1]=15000 (0x3a98)
btc_params[8]=45000 (0xafc8)
btc_params[50]=5932 (0x172c)
```

The Cypress reference timing values were then written and read back before the
RF test:

```text
btc_params[1]=30000 (0x7530)
btc_params[8]=20000 (0x4e20)
btc_params[50]=38700 (0x972c)
```

The DUT remained connectable, discoverable, and advertising. A fresh Ubuntu
all-transport scan detected the Windows BR/EDR controller and multiple LE
devices, but neither the DUT address nor its alias. The three original values
were restored and read back after the test.

The driver source also defines `btc_mode=4` as parallel operation for separate
antennas. This mode was applied and read back in a separate A/B, but Ubuntu
again detected Windows and nearby LE devices without detecting the DUT. The
mode was restored to `1` and read back. No experimental coexistence value was
left active.

## Real cold AP6275P HCD validation

Later testing proved that restarting the attach service does not clear the
controller's patch RAM. This made the earlier runtime HCD swaps insufficient
evidence that each candidate had really executed. The original Ubuntu
59,061-byte AP6275P HCD was therefore tested with a real board reboot:

```text
Candidate SHA-256: 26ae849bb70e8d8e8e7571ef78c3c516a08dfda114d605d57daacdd72aad6aee
Cold ROM:           BCM4362A2 build 0000
Loaded firmware:    BCM43752A2 UART 37.4MHz Ampak AP6275P [0021.0023]
Loaded build:       0023
```

This is materially different from the normal 80,602-byte build-1017 banner,
which identifies an AP6398 configuration. After build 23 was confirmed in RAM,
the normal build-1017 HCD was immediately restored on disk. The controller was
then made connectable, discoverable, bondable, and LE advertising under alias
`AGIBOT-AP6275P-B23`.

Ubuntu received the Windows BR/EDR device at about -68 dBm and multiple LE
devices, but it did not receive the DUT address or alias. Therefore a correctly
identified AP6275P patch does not restore the missing transmit path.

## Complete Wi-Fi removal discriminator

While the DUT was still running the confirmed AP6275P build 23, Wi-Fi was
disabled below the network-manager level:

```text
wlan0: absent
bcmdhd: unloaded
Wi-Fi rfkill devices: absent
Bluetooth rfkill: unblocked
```

Bluetooth remained connectable, discoverable, and advertising as
`AGIBOT-B23-WIFI-OFF`. A fresh Ubuntu scan received more than twenty LE events
and the Windows BR/EDR controller at about -76 dBm, but no DUT event. This
excludes active Wi-Fi firmware, the PCIe Wi-Fi driver, and PTA/coexistence
traffic as the cause.

After the test, `bcmdhd` and `wlan0` were restored. The board was rebooted and
verified on the normal HCD SHA-256, build 1017, active attach and Bluetooth
services, unblocked Wi-Fi, and an operational `wlan0` interface.

## Valid cross-controller DTM result

The earlier Intel receiver-test rejection was caused by controller state, not
by a lack of DTM support. Ubuntu's BlueZ service was runtime-masked, the Intel
controller was brought down and up, and HCI Reset was issued before starting a
legacy LE Receiver Test on channel 20 (2442 MHz). The command completed with
status `0x00`.

The DUT was independently reset at HCI level and entered the matching LE
Transmitter Test with a 37-byte PRBS9 payload. A duplicate start returned
`Command Disallowed`, confirming that the first transmitter test remained
active. After the test interval:

```text
DUT LE Test End:    status 0x00, controller field 0x85e1
Peer LE Test End:   status 0x00, received packets 0
```

The packet-count field is only normative for receiver mode, so the DUT's
`0x85e1` field is not treated as a calibrated transmitted-packet count. The
peer result is valid: the Intel controller remained in receiver mode until a
successful Test End and decoded zero DUT packets on the matching channel.

This is the first direct cross-controller RF result. It is stronger evidence
than ordinary discovery because it removes names, EIR, scan policy, BlueZ, and
Android from the path.

## Explicit maximum-power advertising

With BlueZ stopped, standard Bluetooth 5.1 extended-advertising commands were
sent directly to the DUT. The host requested `+20 dBm`; `LE Set Extended
Advertising Parameters` returned status `0x00` and selected `+15 dBm`. The
controller then accepted the `AGIBOT-MAX` advertising data and enable command,
both with status `0x00`.

After the Ubuntu peer was power-cycled at HCI management level to restore both
LE and BR/EDR reception, it detected multiple LE devices and the Windows
Classic controller but did not detect `B0:02:47:43:EA:3B` or `AGIBOT-MAX`.
Therefore the failure is not caused by a low default advertising-power choice.

## Build 41, Wi-Fi-off, maximum-power combination

The most favorable remaining software combination was tested with another
real cold boot:

```text
HCD SHA-256: 3e4a1eddaf80f3e45f99e9c77b3cd84c85f605540da5f4f92300b80bca6d67ec
Firmware:    BCM43752A2 UART 37.4MHz Ampak AP6275P [0034.0041]
Build:       0041
Wi-Fi:       bcmdhd unloaded, wlan0 absent
LE power:    controller-selected +15 dBm
```

All extended-advertising commands succeeded. Ubuntu again received multiple LE
devices and Windows BR/EDR at about -70 dBm, but no DUT event. The build-1017
HCD had already been restored on disk before this RF test. The board was then
rebooted and verified on build 1017 with active Bluetooth services, unblocked
Wi-Fi, and `wlan0` up. Ubuntu's runtime Bluetooth-service mask was also removed
and its service verified active and enabled.

## Final repair boundary

The repository's MB0002 board photograph shows the AP6275P beside two external
RF connectors, `ANT6300` and `ANT6301`, with no antennas attached in that
reference setup. An open antenna path is now a strong practical explanation:
high-power Wi-Fi can still work through near-field leakage while lower-power
Bluetooth transmission remains below a receiver's threshold. The photograph
does not replace inspection of this exact physical unit, so the next decisive
test is to attach known-good 2.4 GHz antennas to both ports or measure Bluetooth
DTM output at each connector.

No remaining evidence supports another Android framework, HCD, UART, Wi-Fi
coexistence, scan-policy, or transmit-power change. The valid DTM zero-packet
result and the failed `+15 dBm` test make the antenna, matching network, module
soldering, or module-internal BT RF output the repair boundary. The next action
must be a known-good antenna on both ports or a 2.4 GHz measurement at the
connectors; further software-only changes would not be evidence-based.

## Armbian follow-up: DT ownership and runtime TX confirmation (2026-08-27)

The board was rechecked after the image-archive cleanup on the current Armbian
system (`192.168.88.89`). The result is useful for separating a missing platform
GPIO driver from the actual RF path:

```text
/proc/device-tree/wireless-bluetooth/status: disabled
gpio1_A6 (BT_REG_ON): output, active-high, [used], high
gpio3_B2 (BT_WAKE):   output, active-high, [used], high
gpio1_A0/A1/A2:       UART6 TX/RX/RTS muxed and claimed by feb90000.serial
gpio2_C4 (HOST_WAKE): mux unclaimed; this is module-to-host input, not TX enable
hym8563:              32768 Hz, enable_count=1, prepare_count=1
```

The disabled Bluetooth platform node is intentional in this Armbian route: its
vendor platform driver is not loaded, while the custom `agibot-bt-attach` service
holds `ttyS6` with H4/BCM and no CRTSCTS. Enabling the node would reintroduce the
known CTS/serdev conflict; it is not a safe TX repair. The two power/wake lines
are already provided by DT gpio-hogs, so there is no unowned SoC-side `BT_TX_EN`
GPIO to enable.

An additional local advertisement test set the name to `AGIBOT-TX-VERIFY` and
enabled legacy advertising. HCI TX bytes increased from about 83.5 KiB to 84.9
KiB in three seconds; the peer at `192.168.88.66` simultaneously received other
LE devices and Windows BR/EDR but no DUT event. This confirms that the host and
controller are sending HCI advertising commands even though no over-the-air
packet is decoded by the peer.

The only untested *combination* (`btc_mode=0` plus
`btc_prisel_ant_mask=0x2`) cannot be applied live on this PCIe bcmdhd build:
`dhdutil` reads `btc_mode=1`, but both writes return `Operation not supported`.
The attempted write therefore changed no state; the original value remains
`btc_mode=1`. Rebuilding or rebooting solely for this rejected iovar is not
justified by the existing DTM result.

This follow-up leaves the repair boundary unchanged: attach known-good 2.4 GHz
antennas to both `ANT6300`/`ANT6301`, then repeat the DTM test; if packet count
remains zero, measure each connector with a spectrum analyzer or inspect/replace
the AP6275P module and its matching network.
