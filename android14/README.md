# AGIBOT MB0002 V2 Android 14 adaptation

This directory tracks the code-only bring-up workspace for adapting Android 14
to the AGIBOT MB0002 V2 RK3588 board. It lives in the same Git repository as
the AGIBOT Armbian and LEDE work, but keeps Android decisions, baselines, and
validation under `android14/`. It intentionally does **not** contain a full
AOSP checkout, prebuilt images, or build outputs.

The initial directory contents were imported from the former standalone
repository at commit `b4ffdcfebcf96b491864d4923533ade7856e7a7c`.

## Current phase

**Phase 0 - pinned baseline and product skeleton**

The selected baseline is Radxa's public Android 14 RK3588 BSP tree, based on
Rockchip Android 14 RKR6 and Linux 6.1. This baseline is source reference only.
No Radxa image is bootable on AGIBOT MB0002 V2 and must not be flashed to this
board.

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
reference/      Board-reference provenance; large source files stay external
tools/          Non-building validation and traceability helpers
```

## Non-goals in this phase

- No full `repo sync`.
- No Android build, kernel build, DTB compilation, or image packaging.
- No flashing, Maskrom operation, or board mutation.
- No claim that the product configuration is bootable yet.

See `docs/00-baseline.md` and `docs/02-port-plan.md` before changing the
baseline.

Armbian and LEDE files remain outside this directory. Keep unrelated board
changes in separate commits from Android baseline, DTS, and product changes.
