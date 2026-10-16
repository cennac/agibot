# Android 14 r4 official-tools repack

Date: 2026-08-25

## Scope

The r3 camera/author payload was repacked without any self-compiled flashing tool. Only the Rockchip tools bundled with RKDevTool were used:

    RKImageMaker.exe v2.23
    AFPTool.exe v2.28
    E:/AIPorject/101/RKDevTool_v3.37_for_window/bin/

## Source images

Known-good package template:

    E:/AIPorject/101/android14-flash/releases/2026-08-25-r1-zh-rknn-validated/agibot-mb0002-android14-r1-zh-rknn-validated-update.img
    SHA-256 5BF4260E5FDEF6D40D5675CE334398DC58ACD1806A43889A7FDB695FE3CDE1F4

Latest payload source:

    E:/AIPorject/101/android14-flash/releases/2026-08-25-r3-camera-author-unverified/agibot-mb0002-android14-r3-camera-author-unverified-update.img
    SHA-256 3C0CA631B75566CAFAFDDB8F4C93189385D5D08121F910C00B612029B738AAB6

## Comparison result

Official two-stage unpack showed that r1 and r3 have identical package-file, parameter.txt, MiniLoaderAll.bin, uboot.img, trust.img, misc.img, dtbo.img, vbmeta.img, and baseparameter.img. Only these r3 components differ:

| Partition | r3 SHA-256 |
|---|---|
| boot.img | 0BCCC77BA69D64F3FF864A799FE8825E6545E68C029A15B9F66C980C9C9A87F4 |
| recovery.img | 5B124DAEFCDCFBA057B4DEFF33D22846194E1DE7454BF5BF28A24E7B928300AE |
| super.img | 174595AD3D37DF648BAA26AB8BA5CEAFF082820871F7E433C3737BA64E34E1CF |

The r1 and r3 package layouts and loaders are identical, so a changed package layout is unlikely to explain the Maskrom storage-switch failure. A host USB/driver condition remains possible.

## Repack procedure

1. RKImageMaker -unpack extracted the outer RKFW loader and firmware payload from r1 and r3.
2. AFPTool -unpack unpacked both inner firmware payloads.
3. The complete r1 unpack directory was used as the template.
4. Only r3 boot.img, recovery.img, and super.img replaced the r1 files.
5. AFPTool -pack generated the inner firmware image.
6. RKImageMaker -RK3588 wrapped it with the exact r1 outer loader and EMMC storage selection.

## Verification

The final RKFW image was unpacked again with both official tools. All 12 inner files matched the template by SHA-256. The unpacked outer loader matched r1:

    SHA-256 7341BAB67073E9F36B124DA529BDB7266B315654C5DCC520A627B09120B786F0

Final local release:

    E:/AIPorject/101/android14-flash/releases/2026-08-25-r4-camera-author-official-unverified/agibot-mb0002-android14-r4-camera-author-official-unverified-update.img
    SHA-256 C0EA2B515C5FAD3C3151F599BF12BA4E3E05C810EFDBE303DA8761A04EDF1E0C
    Size 2090277450 bytes
