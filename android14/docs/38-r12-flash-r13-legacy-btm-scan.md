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
