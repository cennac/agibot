# Phase 1 Android 14 integration record

## Scope

Phase 1 adapts AGIBOT MB0002 V2 as a normal Android 14 tablet-form product for
an HDMI monitor or television. It intentionally does not use the Android TV
product characteristics. The first-boot goal is conservative: eMMC, HDMI0 in
landscape, USB HID/ADB, dual RTL8211F Gigabit Ethernet paths, UART2/FIQ console,
and the minimum RK3588/RK806 power tree.

No image has been flashed to the board and no Maskrom operation is authorized by
this phase. The outputs are source integration and build validation only.

## Locked source and adaptation commits

The source tree remains based on Radxa manifest commit
`ac6785b31865b06223ae262c8ed42b14b11f5aaa`. Important baseline revisions are:

| Project | Locked baseline |
|---|---|
| `device/rockchip/rk3588` | `4e9794df017bd56f50d8835f95dfdb8b39abf90f` |
| `device/rockchip/common` | `7e6116f5fe4f29e97d242115f8fd1ddf4a3363da` |
| `vendor/rockchip/common` | `13bbb25125ce0aea9e988aaa2b31c3f8e159af30` |
| `vendor/rockchip/hardware` | `90dfdbc85a4a2e787f1541ce1f3fc1bbb8b6b49d` |
| `u-boot` | `fba0c8f28039e0f253ada4a71613ae1dd401c864` |
| `kernel-6.1` | `aaf1830c6647a51523704d5e21c39a7705d3e79d` |

Adaptation commits on the remote build tree:

| Project | Branch | Commit | Subject |
|---|---|---|---|
| `device/rockchip/rk3588` | `agibot/android14-rkr6` | `fba88481033ad21c84362666712a0c233fa9642c` | `agibot: add MB0002 V2 Android 14 product` |
| `device/rockchip/rk3588` | `agibot/android14-rkr6` | `6609e77cf6b3d7ae9d19331ce3257b530e981bab` | `agibot: disable EVS sample for Phase 1` |
| `device/rockchip/rk3588` | `agibot/android14-rkr6` | `7925ab8e8d22d39b6eb9827be45a240a97b4fdb3` | `agibot: disable Bluetooth for Phase 1` |
| `device/rockchip/rk3588` | `agibot/android14-rkr6` | `b37aba2aef0dc54c361c54bef2379e68f760be24` | `agibot: add RK3588 media profiles` |
| `device/rockchip/rk3588` | `agibot/android14-rkr6` | `6e5f8cbbcfc7a622defbfe5c9c859fac83dd87e1` | `agibot: disable PCBA test for Phase 1` |
| `device/rockchip/rk3588` | `agibot/android14-rkr6` | `886d61f93f3876840890172a8c4bac6e4856caad` | `agibot: generate board packaging artifacts` |
| `kernel-6.1` | `agibot/android14-rkr6` | `d8544d7cb7ed2d2d6a0584dc9cb33fd29716cea8` | `arm64: dts: add AGIBOT MB0002 V2 support` |
| `packages/providers/MediaProvider` | `agibot/android14-rkr6` | `f0e2b49e94df52a3989644041196cbca5b9ec5ce` | `mediaprovider: tolerate missing RKR6 API snapshots` |
| `packages/services/Car` | `agibot/android14-rkr6` | `58083a560aa994a5feaa0f3559e3dcd13b47c3cc` | `evs: disable incomplete RKAVM sample modules` |

The local repository stores the source of truth under `android14/overlay/`.
`android14/tools/apply-agibot-phase1.py` applies the small in-place edits that
cannot be represented by copying a new overlay file: product registration,
DTS/USB-driver Makefile registration, kernel fragment wiring, and the two
MediaProvider API-tracking workarounds. The script is idempotent and expects to
run from the AOSP top directory.

## Metadata mapping

| Metadata file | Remote destination |
|---|---|
| `android14/overlay/device/rockchip/rk3588/agibot_mb0002/agibot_mb0002.mk` | `device/rockchip/rk3588/agibot_mb0002/agibot_mb0002.mk` |
| `android14/overlay/device/rockchip/rk3588/agibot_mb0002/AndroidBoard.mk` | `device/rockchip/rk3588/agibot_mb0002/AndroidBoard.mk` |
| `android14/overlay/device/rockchip/rk3588/agibot_mb0002/BoardConfig.mk` | `device/rockchip/rk3588/agibot_mb0002/BoardConfig.mk` |
| `android14/overlay/device/rockchip/rk3588/agibot_mb0002/dt-overlay.in` | `device/rockchip/rk3588/agibot_mb0002/dt-overlay.in` |
| `android14/overlay/device/rockchip/rk3588/agibot_mb0002/media_profiles_default.xml` | `device/rockchip/rk3588/agibot_mb0002/media_profiles_default.xml` |
| `android14/overlay/device/rockchip/rk3588/agibot_mb0002/overlay/...` | `device/rockchip/rk3588/agibot_mb0002/overlay/...` |
| `android14/overlay/kernel-6.1/arch/arm64/boot/dts/rockchip/rk3588-agibot-mb0002-v2.dts` | `kernel-6.1/arch/arm64/boot/dts/rockchip/rk3588-agibot-mb0002-v2.dts` |
| `android14/overlay/kernel-6.1/kernel/configs/agibot.config` | `kernel-6.1/kernel/configs/agibot.config` |
| `android14/overlay/kernel-6.1/drivers/usb/misc/agibot-hub-reset.c` | `kernel-6.1/drivers/usb/misc/agibot-hub-reset.c` |

Product registration is deliberately made in the existing remote
`device/rockchip/rk3588/AndroidProducts.mk`, rather than adding a second
`AndroidProducts.mk` below the product directory. The obsolete local product
`AndroidProducts.mk` and `device.mk` were removed for that reason.

## Board integration decisions

- The board uses the full `rk3588.dtsi` include chain, not `rk3588s.dtsi`.
- CPU/GPU/NPU supplies follow the RKR6 `rk3588-rk806-single.dtsi` power tree and
  retain the board's RK8602/RK8603 regulators on I2C0/I2C1.
- eMMC is 8-bit, non-removable, HS400 at 1.8 V, and uses enhanced strobe.
- HDMI0 is routed from VP0 and enabled with its HDMI PHY and I2S audio path.
  The Android product forces landscape `ORIENTATION_0`, density 240, and the
  primary HDMI display policy. DSI, HDMI1, and CEC remain disabled.
- GMAC0 keeps RTL8211F MDIO address 1, `rgmii-rxid`, `tx_delay=0x43`, and reset
  GPIO4_D5. GMAC1 keeps PHY address 0, corrected `clock_in_out="input"`,
  `rgmii-rxid`, `tx_delay=0x42`, and reset GPIO4_D4.
- GPIO4_D2/GPIO4_D3 are driven by the new explicit USB hub reset driver. It
  asserts both active-low resets, releases them, and waits 100 ms. A static GPIO
  hog would not reproduce the required pulse.
- Both PCA9555 expanders on I2C3 are instantiated as GPIO expanders only. No
  output is forced because many pins control unrelated power domains. USB VBUS
  management remains a later, reviewed change.
- UART2/FIQ uses the RKR6 Android console include with `console=ttyFIQ0` and the
  original 0xfeb50000 earlycon address.
- U-Boot remains on the generic `rk3588_defconfig`/`rk3588-evb` configuration
  for the first package build. A dedicated AGIBOT bootloader DTS is deferred
  until the kernel brings up the board and bootloader hardware assumptions can
  be validated.
- Wi-Fi/Bluetooth, cameras, DSI, sensors, CAN, PCIe/VL805, and other ambiguous
  peripherals stay disabled until hardware identity and wiring are confirmed.
- Bluetooth board support, including its vendor config requirement, is explicitly
  disabled. `BOARD_HAVE_BLUETOOTH_AIC*` alone is insufficient because Rockchip
  common defaults `BOARD_BLUETOOTH_SUPPORT` to true.
- The product sets `ENABLE_EVS_SERVICE=false` and `ENABLE_EVS_SAMPLE=false`. The
  incomplete RKAVM sample modules are also disabled in Soong because camera/EVS
  is outside Phase 1.

## Known source-tree workaround

Radxa's public RKR6 manifest combines `android-14.0-mid-rkr6` MediaProvider
sources from December 2024 with the October 2023 public
`android-14.0.0_r27` prebuilt SDK. The newer `framework-pdf` and
`framework-photopicker` modules therefore request `.latest` API tracking
filegroups that do not exist in that SDK snapshot.

The bounded workaround sets `unsafe_ignore_missing_latest_api: true` on exactly
those two SDK libraries. It does not disable compatibility tracking globally and
should be replaced if Radxa publishes a matching RKR6 SDK snapshot.

The RKR6 Car tip `d3e96db43f635b1cbbaecb2ba4ee6a9916de702d` added RKAVM
renderers and committed OpenCV plus `lib_render_3d.so`, but omitted the referenced
`res/rkrender/lib64/libassimp.so`. No later ref was available on the public
remote. AGIBOT does not use EVS in Phase 1, so no placeholder binary is
synthesized: the product excludes the EVS sample and the incomplete module chain
is disabled pending a source-based assimp integration or an upstream fix.
