# Original Ubuntu Bluetooth comparison and r22 TX diagnosis

Date: 2026-08-27

## Scope

This investigation answers whether the backed-up Ubuntu 20.04 image is a known
good Bluetooth reference and separates the remaining r22 receive and transmit
paths without flashing another image.

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

## Verdict

Original Ubuntu was probably not a working board-specific Bluetooth baseline:
its initialization script selects physical UART9 while its Bluetooth node is
wired around UART6.

The current r22 Android problem is no longer supported as a framework scan,
EIR, UART baud-rate, BT_WAKE, or single-HCD hypothesis. Both Classic
discoverability and an explicit BLE advertisement fail in the outbound
direction while the board receives Classic and BLE traffic. The strongest
remaining cause is the AP6275P Bluetooth RF TX path, including module TX/PA
supply, antenna/RF switch path, soldering, or module damage.

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
