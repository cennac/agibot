# Android 14 r9 Bluetooth APCF probe fix

Date: 2026-08-26

## Root cause

The MB0002 V2 uses an AP6275P controller. Its static controller capability
table reports `LE_ADV_FILTER`, but the controller rejects the startup
`READ_EXTENDED_FEATURES` command (`0xfd57`) with
`INVALID_HCI_COMMAND_PARAMETERS`. In r7 and r8, the rejection was handled
asynchronously. Settings discovery could enqueue another APCF command before
the downgrade state was effective, causing an HCI timeout and a
`com.android.bluetooth` restart.

## r9 source change

Patch `0020-bluetooth-skip-apcf-probe-agibot.patch` changes
`system/gd/hci/le_scanning_manager.cc` so this AGIBOT target initializes
`is_filter_supported_` to `false` and does not enqueue the APCF capability
probe. Existing unsupported branches skip APCF filter commands. Legacy and
extended ordinary LE scanning are unchanged. The r8 runtime downgrade
callback remains as defensive handling for any unexpected response.

Remote Bluetooth commit:

```text
c37750b004 bluetooth: skip APCF probe for AGIBOT AP6275P
```

## Verification plan

1. Apply patches in order and run `git apply --check` before the build.
2. Build the official update image on `192.168.88.66` under
   `/data/agibot-android14-build/aosp` and record the complete log.
3. Verify the rebuilt `com.android.btservices.apex`, JNI library, and image
   SHA-256 values before copying the image to the local release directory.
4. After flashing, enable Bluetooth and run Settings discovery twice. The
   HCI log must contain no `LE_ADV_FILTER`/`0xfd57`, the Bluetooth process PID
   must remain stable, and ordinary scan results must be observed.

## Build result

- Build host: `cennac@192.168.88.66`
- Build log: `/data/agibot-android14-build/logs/2026-08-26-r9-bluetooth-apcf-probe-build.log`
- Result: `build completed successfully`; `Make update image ok!`
- Remote image: `/data/agibot-android14-build/aosp/rockdev/Image-agibot_mb0002/update.img`
- Local image: `E:\AIPorject\101\android14-flash\releases\2026-08-26-r9-bluetooth-apcf-probe-official\agibot-mb0002-android14-r9-bluetooth-apcf-probe-official-update.img`
- Size: `2,134,964,810` bytes
- SHA-256: `0CD4122CB940889A32187EC854BDA834A31E5B8A94B2548A018F24180ACB63DF`

## Status

Source patch is committed and pushed, and the official r9 image built and
verified. It has not been flashed yet; Bluetooth runtime validation is
pending.
