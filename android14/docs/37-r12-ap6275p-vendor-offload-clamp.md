# Android 14 r12 AP6275P vendor offload clamp

Date: 2026-08-26

## Evidence from r11

r11 successfully removed both earlier scan failures:

- no `LE_ADV_FILTER` (`0xfd57`) command or timeout;
- no `LE_SET_EXTENDED_SCAN_PARAMETERS` (`0x2041`) command or timeout.

The first Settings discovery exposed another false controller capability:

```text
Timed out waiting for 0xfd59 (LE_ENERGY_INFO)
assertion 'false' failed - Done waiting for debug information after HCI timeout
```

Bluetooth PID changed from 2311 to 2466. The legacy sender is gated by
`cmn_ble_vsc_cb.energy_support`, which the controller incorrectly reports as
enabled.

## r12 strategy

AP6275P has now demonstrated that multiple scan-related Android vendor
extensions do not satisfy Android 14's command-complete contract. Patch `0024`
therefore clamps the related fields in both capability consumers:

- batch scan result storage;
- advertising packet content filtering and filter count;
- activity/energy reporting;
- vendor extended scan support;
- controller debug logging;
- offloaded advertisement tracking count.

This is intentionally broader than disabling only `energy_support`: it keeps
later framework calls from selecting another untrusted vendor opcode. Standard
legacy LE discovery and normal Bluetooth profiles are retained.

## Acceptance criteria

1. Active r12 APEX and JNI hashes match the build.
2. Runtime logs contain both r12 capability-clamp messages.
3. Framework capabilities report zero filters and no activity-energy support.
4. Two 30-second Settings discovery rounds keep one Bluetooth PID.
5. No `0xfd57`, `0x2041`, `0xfd59`, HCI timeout, or fatal signal occurs.
6. At least one nearby Bluetooth device is discovered, followed by a pairing
   attempt when a suitable test peripheral is available.

## Build result

- Remote Bluetooth commit: `02452c9d05`
- Build log: `/data/agibot-android14-build/logs/2026-08-26-r12-bluetooth-vendor-offload-clamp-build.log`
- Result: `build completed successfully`; `Make update image ok!`
- Local image: `E:\AIPorject\101\android14-flash\releases\2026-08-26-r12-bluetooth-vendor-offload-clamp-official\agibot-mb0002-android14-r12-bluetooth-vendor-offload-clamp-official-update.img`
- Size: `2,134,968,906` bytes
- Image SHA-256: `73CF1ADCB2BF85CC80F42767A999F107CACC982F44B495710C4501F89CF2BF9C`
- APEX SHA-256: `F958D7FD5D75C49AC646C0FF9D13B6B2DD696BAC2448DF5F797D80006502FA36`
- JNI SHA-256: `574F891580ED39ACC2549F70450A42592A9084A765753315C5E2AB42E276F7D0`

Both capability parsers were recompiled, and the JNI contains both unique r12
diagnostic strings. Flash and runtime validation are pending.
