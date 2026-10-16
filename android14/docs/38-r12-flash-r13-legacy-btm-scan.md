# Android 14 r12 flash and r13 legacy BTM scan fix

Date: 2026-08-26

## r12 flash verification

RKDevTool v3.37 reported 100% and `下载固件成功`. Android booted with the exact
r12 payload:

- APEX SHA-256: `F958D7FD5D75C49AC646C0FF9D13B6B2DD696BAC2448DF5F797D80006502FA36`
- JNI SHA-256: `574F891580ED39ACC2549F70450A42592A9084A765753315C5E2AB42E276F7D0`

Both r12 clamp messages appeared. Runtime properties confirmed:

```text
mNumOfOffloadedScanFilterSupported = 0
mOffloadedScanResultStorageBytes = 0
mIsActivityAndEnergyReporting = false
mTotNumOfTrackableAdv = 0
mIsExtendedScanSupported = false
mIsDebugLogSupported = false
```

No `0xfd57` or `0xfd59` failure occurred.

## Remaining failure and corrected root cause

Settings discovery still timed out on `0x2041`; Bluetooth PID changed from
2320 to 2475. The active sender was not GD `LeScanningManager`. Legacy BTM
functions `btm_send_hci_set_scan_params()` and
`btm_send_hci_scan_enable()` select extended scan commands whenever the
controller supports standard extended advertising. That assumption is false
for AP6275P: extended advertising works, while extended scanning does not.

## r13 change

Patch `0025` forces only the legacy BTM scan parameter and enable operations to
Bluetooth 4.x legacy commands. It does not disable or alter extended
advertising.

Acceptance requires two 30-second Settings scans with one stable Bluetooth
PID, no HCI timeout/fatal signal, and actual device discovery.

## r13 build artifact

The remote build and official Rockchip image packaging completed successfully
on `192.168.88.66` under `/data/agibot-android14-build/aosp`. The build log is:

```text
/data/agibot-android14-build/logs/2026-08-26-r13-bluetooth-legacy-btm-scan-build.log
```

The final artifact was archived locally as:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-26-r13-bluetooth-legacy-btm-scan-official\agibot-mb0002-android14-r13-bluetooth-legacy-btm-scan-official-update.img
```

- Image size: `2134964810` bytes
- Image SHA-256: `E74DB06F6AD97A48AEEAFF9661DD03AEB880BCDFCF6EB38852F308FA7116879E`
- APEX SHA-256: `7A917B280C8E31D69F2A9ACA0BB243FFB70A2FFC86EECB07BF2C1A4763F95715`
- JNI SHA-256: `0200DDC044213132B7AF525366AB16681B3730DBA83D021E3FED8EC1EFB330F1`

The image SHA-256 was calculated independently on the build server and again
after transfer to Windows; both values matched.

## r13 flash verification

RKDevTool v3.37 completed the r13 flash at 100% and reported `下载固件成功`.
Android completed boot and both installed payload hashes matched the build:

- Installed APEX SHA-256: `7A917B280C8E31D69F2A9ACA0BB243FFB70A2FFC86EECB07BF2C1A4763F95715`
- Installed JNI SHA-256: `0200DDC044213132B7AF525366AB16681B3730DBA83D021E3FED8EC1EFB330F1`

The first real Settings pairing scan confirmed that patch `0025` changed the
command from extended `0x2041` to legacy `0x200b`. However, the controller also
failed to respond to `LE_SET_SCAN_PARAMETERS (0x200b)`. After the five-second
HCI timeout, the Bluetooth process aborted and restarted from PID `2321` to
PID `2507`:

```text
Timed out waiting for 0x200b (LE_SET_SCAN_PARAMETERS)
assertion 'false' failed - Done waiting for debug information after HCI timeout
Fatal signal 6 (SIGABRT)
```

No `0xfd57`, `0xfd59`, or `0x2041` failure occurred. r13 is therefore a useful
diagnostic build but does not pass Bluetooth discovery acceptance. The next
change must investigate why AP6275P does not complete either standard scan
parameter command instead of selecting another scan opcode.
