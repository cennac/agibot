# Android 14 r8 Bluetooth APCF fallback

Date: 2026-08-26

## Problem

r7 proved that the AP6275P UART path is functional: `/dev/ttyS6` opens, HCI
initialization completes, and the adapter stays in `STATE_ON`. Starting a real
scan from Settings then exposed a separate controller/stack mismatch.

The static vendor-capability response says advertising packet content filtering
is available, but the first `LE_ADV_FILTER` `READ_EXTENDED_FEATURES` subcommand
returns `INVALID_HCI_COMMAND_PARAMETERS`. The stack only logged that response
and retained `is_filter_supported_ = true`. When Settings entered
“与新设备配对”, it consequently issued another APCF command:

```text
Timed out waiting for 0xfd57 (LE_ADV_FILTER)
assertion 'false' failed - Done waiting for debug information after HCI timeout
```

`com.android.bluetooth` aborted and restarted. The failure was reproduced more
than once while Bluetooth always returned to ON afterward.

## Fix

Patch:

```text
android14/patches/0019-bluetooth-disable-apcf-after-controller-reject.patch
```

In `LeScanningManager::on_apcf_read_extended_features_complete`, both a
malformed response and a non-SUCCESS status now clear:

```text
is_filter_supported_
is_transport_discovery_data_filter_supported_
is_ad_type_filter_supported_
```

This turns the first controller rejection into a runtime capability downgrade.
Subsequent `ScanFilterEnable`, filter parameter, and filter-add calls take the
existing unsupported path without transmitting another APCF opcode. Ordinary LE
scan commands remain unchanged, and the verified r7 UART `CRTSCTS` fix is not
touched.

Applied remote commit:

```text
packages/modules/Bluetooth 6dfe9801e3
bluetooth: disable APCF after controller rejection
```

## Expected r8 validation

1. Bluetooth reaches and remains in `STATE_ON`.
2. The startup log still shows the controller rejecting APCF extended features.
3. The next line must report APCF support being disabled.
4. Entering Settings discovery must not issue another `0xfd57` command and must
   not restart `com.android.bluetooth`.
5. LE advertising reports should still arrive through the ordinary scan path.
6. Pair one real BLE or classic device if one is available.

## Build

Remote build completed successfully on 2026-08-26. The incremental Android
build took 7 minutes 20 seconds; the official update package was completed at
12:38 CST.

Build host:

```text
192.168.88.66
/data/agibot-android14-build/aosp
```

Build log:

```text
/data/agibot-android14-build/logs/2026-08-26-r8-bluetooth-apcf-build.log
```

Output checks:

```text
rockdev/Image-agibot_mb0002/update.img
Size:   2134977098 bytes
SHA256: E1832A06C336B79ABEFE86F39AD837908B97A2CF79EA98B1AB890DE1F063134E

system/apex/com.android.btservices.apex
SHA256: f9336206aa4f889a39603766e79b17f8c4c38a7874535683aa5c0b15b022275f

apex/com.android.btservices/lib64/libbluetooth_jni.so
SHA256: 6d82373b0784191de8b8511728bd4e2e5cf3c794b40b913fba9f8e6e36b8725c
```

The new `libbluetooth_jni.so` contains the two expected
`disabling APCF support` log strings. The build log has no fatal build error
and records `Making update.img OK`, `Make update image ok!`, and
`Make gpt image ok!`.

Normalized local release:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r8-bluetooth-apcf-fallback-official\agibot-mb0002-android14-r8-bluetooth-apcf-fallback-official-update.img
```

`SHA256SUMS.txt` is stored beside the image. Flashing and runtime validation
remain pending.
