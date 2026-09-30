# Antenna retest after user fitted the SMA antenna

Date: 2026-08-31 (Asia/Shanghai)

## Scope

The user fitted an antenna to the AP6275P RF path and requested the decisive
Bluetooth retest from document 59. The board was running the branded Armbian
candidate `df777c1e`, online as `agibot` at `192.168.88.89`.

Controller state before the test:

```text
hci0 UART, address B0:02:47:43:EA:3B
firmware build 1017 (BCM43752A2 / AP6275P patch)
UP RUNNING PSCAN ISCAN after discoverable was enabled
```

`bluez` and `rfkill` were installed from the Jammy repository for this test
only. No kernel, firmware, device-tree, or service implementation was changed.

## Module marking

The physical module silkscreen observed after the antenna retest reads:

```text
AP6275PPR3
T2144012 2020
```

This confirms the fitted part as an Ampak AP6275P module, hardware revision
PR3, with `T2144012 2020` retained as the production marking for replacement
part matching. The marking does not change the test interpretation: the same
module successfully boots its BCM43752A2 firmware, receives Bluetooth traffic,
and controls Wi-Fi, while its Bluetooth RF output remains absent.

## Observer validation

The Ubuntu peer `192.168.88.66` was offline, so the Windows host
`LAPTOP-BGDHCEIE` was used as the independent receiver. Its radio was proven
working during the same window:

- `bleak` 25-second LE scan: 43 nearby devices received, RSSI -56 to -94 dBm.
- A second synchronized 20-second LE scan: 39 devices received.
- Win32 Classic inquiry: nearby BR/EDR devices returned, including a remembered
  headset and an unknown QCY headphone.

The observer therefore received both LE and BR/EDR traffic throughout.

## DUT transmit result

With the board set to `Discoverable: yes`, `Pairable: yes`, and
`ActiveInstances: 1` under the unique names `MB0002-ANTENNA-TEST` /
`AGIBOT-ARMBIAN-BTTEST` style aliases:

```text
BLE:  no B0:02:47:43:EA:3B, no MB0002-ANTENNA-TEST (two scans)
Classic inquiry: no B0:02:47:43:EA:3B (two inquiries)
```

The Wi-Fi link to `cc181003` remained operational at -54 dBm, close to the
pre-antenna -56 dBm baseline, so the antenna position did not produce an
obvious Wi-Fi RSSI change either.

## State after the test

```text
Alias: agibot
Powered: yes
Discoverable: no
Pairable: no
ActiveInstances: 0
```

The `bluetooth.service` was restarted to clear test advertisement instances;
`agibot-bt-attach.service` remained untouched and hci0 stayed on build 1017.

## Interpretation

Fitting the antenna to its current connector did not change the established
failure signature: the controller accepts discoverable/advertising commands and
the receive path works, but no over-the-air transmission is decoded by a
validated external receiver.

Next physical A/B, in priority order:

1. If only one antenna is fitted, move it to the other SMA connector
   (`ANT6301` first per the `btc_prisel_ant_mask=0x2` chain hypothesis, then
   `ANT6300`) and repeat the same synchronized scan.
2. Fit known-good 2.4 GHz antennas to both connectors and repeat.
3. If both positions still produce zero events, the remaining fault is the
   Bluetooth-specific RF output path (module TX/PA, RF switch, matching network,
   soldering, or module damage) and needs measurement or module-level repair.

No further OS or firmware change is justified by this result.

## Follow-up: antennas with correct connectors (same day)

The user discovered that the original antennas and both on-board SMA connectors
were female, so the first retest had run with an open RF path. Two replacement
cables were fitted to both connectors and the same test sequence was repeated
under the unique name `MB0002-REAL-ANTENNA`.

Evidence that the new cables made real RF contact:

```text
Wi-Fi RSSI to cc181003: -54 dBm before -> -32 dBm after (+22 dB)
```

Bluetooth results after the fix:

```text
BLE advertisement: no hit (45 other devices received in the same 25 s scan)
Classic inquiry: no B0:02:47:43:EA:3B (observer returned nearby headsets)
Board-side BLE receive: 15 devices in 15 s (receive path still working)
```

The Ubuntu DTM peer was offline again during this round, so the packet-counter
test was not repeated; the synchronized visibility result is already conclusive
because the observer provably received both LE and BR/EDR traffic.

## Final interpretation

With genuinely connected antennas on both RF connectors, the Wi-Fi chain gained
22 dB while Bluetooth transmission remained undetectable and Bluetooth
reception kept working. The fault is therefore isolated to the Bluetooth RF
output path of the AP6275P module or its board routing (BT PA, RF switch,
matching network, module pin, or soldering).

Remaining options:

1. Measure 2.4 GHz Bluetooth DTM output at the SMA connectors to localize the
   break (requires a spectrum analyzer or comparable RF instrument).
2. Inspect/rework or replace the AP6275P module (physical part: AP6275P PR3,
   production marking `T2144012 2020`).
3. If working Bluetooth on this specific board is the immediate goal, use a USB
   Bluetooth adapter instead; no on-board software setting can repair this.
