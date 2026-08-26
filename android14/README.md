# AGIBOT MB0002 V2 Android 14 adaptation

This directory tracks the code-only bring-up workspace for adapting Android 14
to the AGIBOT MB0002 V2 RK3588 board. It lives in the same Git repository as
the AGIBOT Armbian and LEDE work, but keeps Android decisions, baselines, and
validation under `android14/`. It intentionally does **not** contain a full
AOSP checkout, prebuilt images, or build outputs.

The initial directory contents were imported from the former standalone
repository at commit `b4ffdcfebcf96b491864d4923533ade7856e7a7c`.

## Current phase

**r18 flashed and stable; r19 AP6275P firmware correction in progress**

The selected baseline is Radxa's public Android 14 RK3588 BSP tree, based on
Rockchip Android 14 RKR6 and Linux 6.1. Phase 1 completed the AGIBOT product,
kernel DTS, Android build, and conservative package. Phase 2 replaced the
generic RK3588 U-Boot identity with a minimal AGIBOT early-boot tree and put
eMMC before SD. Hardware fix round 1 added GMAC/USB/RKNN repairs and Simplified
Chinese as the factory default, deployed a complete image through Maskrom, and
revalidated the serial U-Boot-to-Maskrom rescue path. See
`docs/14-hardware-fix-round1.md`, `docs/15-default-locale.md`, and
`docs/16-maskrom-full-flash.md`. Runtime driver validation is recorded in
`docs/17-driver-validation.md`; it identifies the media DTS, Android UVC camera
HAL, and unused Wi-Fi/Bluetooth integration as the next repair targets.
The full stack has since reached r18. r18 retains the controller OTP address,
disabled controller LPM, legacy scan path, vendor BLE offload clamps,
three-line author information, and Gallery support image. It also keeps
BT_WAKE asserted and uses standard, wider Classic inquiry/page scan windows.
Runtime HCI validation proves those scan parameters reach the controller, but
Android receives no Classic Inquiry results from independently visible peers
and direct Windows pairing still ends in `HCI_ERR_PAGE_TIMEOUT`.

r19 replaces the mismatched 91,900-byte AP6398-labelled HCD with the original
59,061-byte AP6275P firmware extracted from the MB0002 vendor reference system.
The diagnosis and single-variable repair are recorded in
`docs/45-r19-ap6275p-reference-firmware.md`.

## Product target

- Normal Android 14 tablet/desktop form factor, not Android TV.
- Primary display is HDMI0, landscape by default.
- DSI panels are documented but disabled for the first boot milestone.
- USB mouse/keyboard and Ethernet are first-class bring-up peripherals.
- A TV launcher can be added later as an optional product variant.

## Directory layout

```text
baseline/       Pinned upstream source information
docs/           Decisions, inventory, plan, and risk register
dts/            Candidate device-tree fragments and conversion notes
overlay/        Files intended to be copied into the Android source tree
patches/        Reviewable source patches applied to the remote AOSP projects
reference/      Board-reference provenance; large source files stay external
tools/          Non-building validation and traceability helpers
```

## Non-goals in this phase

- The full source checkout is complete on the remote build host; do not duplicate
  it in WSL or commit its contents.
- No flashing, Maskrom operation, bootloader unlock, or board mutation.
- No full Android source checkout or large generated image is committed here.
- No claim that the product configuration is bootable yet.

See `docs/00-baseline.md` and `docs/02-port-plan.md` before changing the
baseline.

The full source checkout is hosted in the remote workspace described in
`docs/07-remote-build-host.md`. Do not duplicate that checkout in WSL or commit
its contents to this repository.

The download process, network-route decisions, and cleanup rules are recorded in
`docs/08-source-download.md`. Update that log whenever the remote sync strategy
or verification status changes.

Armbian and LEDE files remain outside this directory. Keep unrelated board
changes in separate commits from Android baseline, DTS, and product changes.
