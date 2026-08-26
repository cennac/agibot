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

## First r11 build correction

The first build correctly reached `le_scanning_manager.cc` but stopped because
the forced legacy policy left two extended-scan default constants unused and
the module builds with `-Werror`. Patch `0023` removes those two constants; no
runtime behavior is changed. The build is rerun from the failed target.

## r11 build result

- Bluetooth commits: `87f5ec71a8`, `def2652e32`
- Successful retry log: `/data/agibot-android14-build/logs/2026-08-26-r11-bluetooth-legacy-scan-retry.log`
- Local image: `E:\AIPorject\101\android14-flash\releases\2026-08-26-r11-bluetooth-legacy-scan-official\agibot-mb0002-android14-r11-bluetooth-legacy-scan-official-update.img`
- Size: `2,134,968,906` bytes
- Image SHA-256: `7EED6D93387C479DEB2A988FD13EA7A1B0D4FCC368621392D00079E846D80295`
- APEX SHA-256: `83D64A45653E11F9D43448DEB8366B8353202CA7AE5646DFD1AB73977991D772`
- JNI SHA-256: `09EB4D671328CC0F12E8DDB65F789A49FFF39C35239BB95BE2E4A196219420F7`

The retry completed successfully and produced the official update image.
Flash and runtime discovery validation remain pending.
