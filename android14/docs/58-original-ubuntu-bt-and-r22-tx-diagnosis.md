# Original Ubuntu Bluetooth comparison and r22 TX diagnosis

Date: 2026-08-27

## Scope

This investigation answers whether the backed-up Ubuntu 20.04 image is a known
good Bluetooth reference and separates the remaining r22 receive and transmit
paths without flashing another image.

## Blue-heatsink image recheck (2026-08-27)

The user-supplied source was checked read-only:

```text
E:\AIPorject\101\RK3588-backup\RK3588_蓝色散热_纯净系统_20260816.img.gz
size:    3,519,106,194 bytes
SHA-256: 3A43E1D3879284EF30DE1891F8EFED343511D10FCFB6FBBD298C95D61401C6E9
```

The inspected files were retained under
`E:\AIPorject\101\_tmp\blue-heatsink-clean-20260816\extracted`.

The gzip stream contains a GPT-partitioned 116.2 GiB rootfs image. The
rootfs filesystem is ext4, volume UUID
`437f3cc1-d86d-41ca-9362-03370b4299b6`, and identifies itself as:

```text
Ubuntu 20.04.6 LTS (Focal Fossa)
```

The image has both `bluetooth.service` and `rkwifibt.service` enabled. Its
Broadcom/Rockchip bundle is substantial and is therefore a useful firmware
reference, but not proof of a working board configuration:

| File | Image size | Image SHA-256 | Current Armbian size |
| --- | ---: | --- | ---: |
| `system/etc/firmware/BCM4362A2.hcd` | 59,061 | `26ae849bb70e8d8e8e7571ef78c3c516a08dfda114d605d57daacdd72aad6aee` | 80,602 |
| `system/etc/firmware/nvram_AP6275P.txt` | 7,335 | `9179ab100182d1f572916e6c90bfc2a3dbc509951d36c6546c3807e4a45890c4` | 7,458 |
| `system/etc/firmware/fw_bcm43752a2_pcie_ag.bin` | 857,142 | `bfcdc3ecb5274745f3c3551abd0d9b11ede89b305837241364a055fefbf09de7` | 936,074 |

The image NVRAM is the older `AP6275P_NVRAM_V1.1_20200702` variant and is
byte-identical to the previously archived vendor reference. It contains the
expected AP6275P identifiers (`vendid=0x14e4`, `devid=0x449d`), both RF
chains enabled, and `xtalfreq=37400`.

The decisive configuration problem remains in
`/etc/init.d/rkwifibt.sh`: for `rk3588|rk3588s` it executes
`rk_wifi_init /dev/ttyS9`. The board's Bluetooth platform wiring and all
successful MB0002 tests use UART6, `/dev/ttyS6`; UART9 is a different pin
group. The script also loads `/system/etc/firmware/BCM4362A2.hcd`, so the
presence of the correct-looking HCD does not compensate for the wrong UART.

Conclusion: this blue-heatsink file is an Ubuntu vendor image with a more
complete firmware archive, not a confirmed working Bluetooth baseline for
this MB0002 board. The 59,061-byte HCD and old NVRAM can be retained as
controlled A/B firmware candidates, but the image should not be restored just
to test Bluetooth until the UART6 startup path is corrected.

## S9 A/B attempt status (2026-08-27)

Changing the current MB0002 configuration from `ttyS6` to `ttyS9` was not
executed or flashed. The only reachable host, `192.168.88.66`, is an x86
Ubuntu workstation with an Intel USB Bluetooth adapter, not the RK3588 board;
the local machine had no `COM9` and `adb devices` returned no board. The
MB0002 DTS still maps the AP6275P Bluetooth path to UART6 and maps UART9 to a
different pin group, so an S9 image change would be an unverified destructive
experiment rather than a supported fix. A live S9 test can be run later only
when the board is reachable through its serial/ADB/network interface, with a
reversible port parameter and before any image write.

After this note was drafted, the local USB-serial adapter re-enumerated as
`USB-SERIAL CH340 (COM9)`. A 60-second passive capture at 1,500,000 baud
received zero bytes and the modem status inputs remained low, so COM9 is
present but the board is not currently producing UART output. No characters
were transmitted during this check.

## Current board reachability check (2026-08-27)

The board-side connection was rechecked after the user reported that only the
COM console, the Type-C flashing/ADB port, and wired Ethernet were connected.
The local ADB server was restarted; no USB Android or Rockchip device
enumerated. COM9 remained present as `USB-SERIAL CH340`.

The address `192.168.88.200` replied to four ICMP probes with 4--17 ms
latency and ARP resolved it to `84-7B-57-95-BD-66`. TCP connections to SSH
(`22`), ADB-over-network (`5555`), and HTTP test ports timed out. This means
the IP layer and at least one network interface are alive, but no remote
userspace service is currently reachable. A 60-second passive COM9 capture
also received zero bytes.

Previous validated Android r22 and Armbian boots had Ethernet and ADB/userspace
available, so this observation does not identify a source commit that broke
the network. The combination of a live ping, no TCP services, and a blinking
screen cursor is more consistent with an incomplete/stalled userspace boot or
a different image than with a dead GMAC link. No network, boot, or image
configuration was changed during this check.

The later identity check resolved `192.168.88.200` to reverse-DNS name
`adm.lan`; NetBIOS also reported host name `ADM` with the same MAC
`84-7B-57-95-BD-66`. Therefore `.200` is a separate management/NAS host, not
the MB0002 Armbian board. It must not be used as evidence of the board's
network or Bluetooth state.

## Original Ubuntu is not a known-good Bluetooth baseline

The original image uses Ubuntu 20.04.6 and Linux 5.10.110. Static extraction
found several reasons not to treat its Bluetooth state as known good:

1. `/etc/init.d/rkwifibt.sh` launches `rk_wifi_init /dev/ttyS9` on RK3588.
2. The vendor DTB enables both UART6 and UART9, but the Bluetooth platform node
   uses UART6 RTS and the UART6 GPIO group:

   ```text
   UART6 TX/RX: GPIO1_A0 / GPIO1_A1
   UART6 RTS:   GPIO1_A2
   UART9 TX/RX: GPIO3_D4 / GPIO3_D5
   ```

   UART9 is therefore not an alias for the same physical pins. The original
   startup program and Bluetooth GPIO/pinctrl description disagree.
3. The original `/var/lib/bluetooth/` contains only adapter directories
   `70:F7:54:E2:28:4C` and `70:F7:54:E2:31:52`; it contains no directory for
   the board AP6275P address `B0:02:47:43:EA:3B`.
4. Its 59,061-byte `BCM4362A2.hcd` is byte-identical to the firmware already
   tested in Android r19. That firmware initialized the controller but did not
   repair Classic discovery.

`strings` inspection of `/usr/bin/rk_wifi_init` shows that the original path
uses `brcm_patchram_plus1` at 1.5 Mbit/s and toggles rfkill and `btwrite`, but
this cannot compensate for opening the wrong physical UART.

The static evidence therefore indicates that original Ubuntu Bluetooth was
likely incomplete or unused on this particular MB0002 board. A destructive
Ubuntu restore is not justified merely to obtain a presumed good baseline.

## r22 state before the new discriminator

After the user's board-side repair, unchanged r22 had already proved:

- AP6275P initialization and OTP address: PASS.
- Android HCI transport on UART6: PASS.
- Classic Inquiry reception from Windows: PASS.
- BLE scanning reception: PASS.
- Wi-Fi scanning reception: PASS.
- Ubuntu Classic discovery of MB0002: FAIL.

The unresolved distinction was whether the failure was specific to Classic
Inquiry Response/EIR or affected Bluetooth RF transmission generally.

## Live BLE transmission discriminator

A temporary APK outside the Git repository started a connectable legacy BLE
advertisement with:

```text
name:     MB0002-R22-TXTEST
mode:     low latency
TX power: high
result:   AdvertiseCallback.onStartSuccess
```

The first attempt correctly returned `ADVERTISE_FAILED_DATA_TOO_LARGE` because
the legacy 31-byte payload contained a name, TX-power field, and manufacturer
data. After reducing the payload to the unique name, Android displayed:

```text
Advertising: MB0002-R22-TXTEST
```

The Android HCI snoop contains the unique advertising name and the controller
configuration sequence:

```text
E:\AIPorject\101\_tmp\ble-tx-diagnostic\ble-tx-btsnoop.log
size:    50,352 bytes
SHA-256: e84f5e3cebb90dfcca57e8b93e72232c971cae5e81d4e56837ca4fecc86cefbc
```

Ubuntu `192.168.88.66` then ran a fresh 25-second LE scan after restarting its
BlueZ service. It received many independent advertisers, including a Huawei
Band 9 and XIBERIA MC20, with observed RSSI values from -71 to -100 dBm. It
never received the unique MB0002 advertisement name or a new device correlated
with the test.

```text
E:\AIPorject\101\_tmp\ble-tx-diagnostic\ubuntu-ble-scan-3.log
size:    10,246 bytes
SHA-256: 1f77838be771038ec5eed4788ed33565e71dd51ff9264d6158481323f8630478
```

This reproduces the earlier Classic reverse-discovery failure with a separate
LE transmitter path. The controller accepts host advertising and Classic scan
enable commands, but no externally detectable Bluetooth transmission is
observed.

## Post-repair BT_WAKE A/B

The r17 permanent-high wake experiment predated the user's board-side repair,
so the same state was tested once against the new explicit BLE TX discriminator.
The running r22 baseline initially showed:

```text
GPIO3_B2 / bt_default_wake: out low
```

Writing `1` to `/proc/bluetooth/sleep/btwrite` changed the live GPIO to
`out high`. Android again started `MB0002-R22-TXTEST` successfully, including
advertiser ID 0 and controller status 0. A fresh 25-second Ubuntu LE scan still
received many independent advertisers but no MB0002 advertisement.

```text
E:\AIPorject\101\_tmp\ble-tx-diagnostic\ubuntu-ble-scan-btwake-high.log
size:    12,955 bytes
SHA-256: 70b30318efc19f34d83a27dcb0a6e118deece2632ef0550cb5f9e5ef4ee2a8c5
```

BT_WAKE was restored low after the test. Keeping it high is therefore not an
r23 repair for the remaining TX failure.

## Antenna-path finding

The archived MB0002 top-side board photograph shows both SMA connectors beside
the shielded AP6275P module, `ANT6300` and `ANT6301`, with no antennas fitted.
The hardware inventory had previously identified both as the module's RF
connectors but did not resolve their chain assignment.

The board AP6275P NVRAM supplies additional evidence:

```text
aa2g=3
txchain=3
rxchain=3
btc_prisel_ant_mask=0x2
btc_mode=1
```

Both Wi-Fi chains are enabled. The Bluetooth coexistence priority mask selects
the second chain bit, making the connector associated with chain 1 the first
antenna path to inspect. The current files do not prove whether chain 1 is the
silkscreened `ANT6300` or `ANT6301`, so this must be resolved by continuity,
module documentation, or a safe antenna-swap A/B rather than assumption.

The highest-value physical test is to fit known-good 50-ohm dual-band antennas
to both SMA ports. If only one antenna is available, test `ANT6301` first based
on the chain-mask hypothesis, then move the same antenna to `ANT6300` and repeat
the identical BLE advertisement scan. An open, damaged, or wrong-chain antenna
path can explain weak nearby reception combined with an undetectable TX signal.

## Verdict

Original Ubuntu was probably not a working board-specific Bluetooth baseline:
its initialization script selects physical UART9 while its Bluetooth node is
wired around UART6.

The current r22 Android problem is no longer supported as a framework scan,
EIR, UART baud-rate, BT_WAKE, or single-HCD hypothesis. Both Classic
discoverability and an explicit BLE advertisement fail in the outbound
direction while the board receives Classic and BLE traffic. The strongest
remaining cause is the AP6275P Bluetooth RF TX path, including module TX/PA
supply, missing/wrong antenna, antenna/RF switch path, soldering, or module
damage.

Do not create r23 by repeating the previously tested framework properties,
HCD swaps, or BT_WAKE variants. The next useful action is a board-level TX
measurement or module/antenna-path repair, followed by rerunning this exact BLE
advertising discriminator before any new Android image build.

## Cleanup

- The temporary diagnostic APK was uninstalled.
- Android Bluetooth name was restored to `MB0002 V2` and verified through
  Settings storage and `dumpsys bluetooth_manager`.
- Ubuntu Bluetooth remained powered and was restored to `Discoverable: no`.
- No Android partition, source checkout, or image was modified.
