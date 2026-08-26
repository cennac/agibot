# Android 14 r10 failure and r11 legacy scan fix

Date: 2026-08-26

## r10 verified result

The flashed payload matched the r10 build hashes and contained the capability
clamp diagnostic. Runtime evidence confirmed the APCF fix:

```text
AGIBOT AP6275P: disabling unsupported APCF offload
mMaxScanFilters: 0
mNumOfOffloadedScanFilterSupported = 0
```

No `0xfd57` command or timeout occurred during Settings discovery.

## Newly exposed failure

The first real scan then failed on another controller capability mismatch:

```text
Timed out waiting for 0x2041 (LE_SET_EXTENDED_SCAN_PARAMETERS)
assertion 'false' failed - Done waiting for debug information after HCI timeout
```

Bluetooth PID changed from 2313 to 2466. r10 is therefore `tested-failed` for
discovery, although its APCF correction is validated and must be retained.

## r11 correction

Patch `0022-bluetooth-force-legacy-le-scan-ap6275p.patch` selects
`ScanApiType::LEGACY` for MB0002/AP6275P. Discovery will use standard legacy LE
scan parameter and enable commands rather than the controller's non-working
extended scanning implementation.

Acceptance requires two Settings discovery rounds with a stable Bluetooth PID,
no `0xfd57` or `0x2041` timeout, and visible scan results.
