# Android 14 r9 failure and r10 legacy APCF fix

Date: 2026-08-26

## r9 runtime result

r9 booted and its active Bluetooth payload matched the remote build:

- APEX SHA-256: `EB33B4DB6108909A810D7955B54F43E6E6936F2644A3BFA06F4463792DD99587`
- JNI SHA-256: `9A063BCDA298D2D6212EF7B685E0E5100FAC8B19FE1A296B94B765E19B39472C`

Bluetooth reached `STATE_ON`, but Settings discovery still failed:

```text
Timed out waiting for 0xfd57 (LE_ADV_FILTER)
assertion 'false' failed - Done waiting for debug information after HCI timeout
```

The process changed from PID 2299 to PID 2446, proving a crash and service
restart. r9 is therefore `tested-failed` for Bluetooth discovery.

## Corrected root cause

Android 14 contains both GD and legacy BTM APCF implementations. r9 disabled
only `system/gd/hci/le_scanning_manager.cc`. Runtime `dumpsys` still showed the
raw controller capabilities:

```text
filtering_support: 1
max_filter: 16
```

The legacy sender in `system/stack/btm/btm_ble_adv_filter.cc` uses those fields
and sends `HCI_BLE_ADV_FILTER` (`0xfd57`).

## r10 change and acceptance criteria

Patch `0021-bluetooth-clamp-ap6275p-apcf-capability.patch` clears
`filter_support` and `max_filter` immediately after parsing the vendor response.
This prevents legacy filter initialization and makes all its entry points
return `BTM_MODE_UNSUPPORTED` without sending HCI commands.

After r10 is flashed:

1. The log must contain `AGIBOT AP6275P: disabling unsupported APCF offload`.
2. `dumpsys bluetooth_manager` must report zero offloaded scan filters.
3. Two Settings discovery runs must contain no `0xfd57` timeout.
4. The Bluetooth process PID must remain unchanged and scan results must appear.

## r10 build result

- Remote Bluetooth commit: `206af459ec`
- Build log: `/data/agibot-android14-build/logs/2026-08-26-r10-bluetooth-legacy-apcf-build.log`
- Result: `build completed successfully`; `Make update image ok!`
- Local image: `E:\AIPorject\101\android14-flash\releases\2026-08-26-r10-bluetooth-legacy-apcf-official\agibot-mb0002-android14-r10-bluetooth-legacy-apcf-official-update.img`
- Size: `2,134,968,906` bytes
- Image SHA-256: `D86B8824E01DE4D150A20280D40D1EC29B1F9A5D5BCA21FC54EF1B8D0DE023C3`
- APEX SHA-256: `6E0D50CA2BD48C1965E7627784342D586C0E600ED46D3B0C4FB26121DFC9C1E4`
- JNI SHA-256: `95BD68B64801240959A6C380783459CDA5DC1776527E6F0640FBD41CF2756184`

The rebuilt JNI contains the unique capability-clamp diagnostic string.
Flash and runtime validation remain pending.
