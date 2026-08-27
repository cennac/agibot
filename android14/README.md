# AGIBOT MB0002 V2 Android 14 adaptation

This directory tracks the code-only bring-up workspace for adapting Android 14
to the AGIBOT MB0002 V2 RK3588 board. It lives in the same Git repository as
the AGIBOT Armbian and LEDE work, but keeps Android decisions, baselines, and
validation under `android14/`. It intentionally does **not** contain a full
AOSP checkout, prebuilt images, or build outputs.

The initial directory contents were imported from the former standalone
repository at commit `b4ffdcfebcf96b491864d4923533ade7856e7a7c`.

## Current phase

**r22 validated; independent peers narrow Bluetooth failure to board-side BR/EDR**

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

r19 replaced the mismatched 91,900-byte AP6398-labelled HCD with the original
59,061-byte AP6275P firmware extracted from the MB0002 vendor reference system.
The firmware initialized reliably, but Classic Inquiry and Page still failed.
Runtime tests also excluded the powered-off Wi-Fi dongle, loaded `bcmdhd`
module, and r18 scan-window properties as the primary cause.

r20 updates only the Bluetooth HCD to the newer AP6275P `0034.0041` firmware
published for the Khadas VIM4. The candidate provenance, runtime isolation,
and build acceptance criteria are recorded in
`docs/46-r20-ap6275p-0034-0041-firmware.md`.

Post-flash HCI validation shows that r20 preserves stable initialization, OTP
address, BLE reception, Wi-Fi, and the rest of the platform, but it does not
restore BR/EDR. Both the r18 wide scan configuration and the r16 defaults
produce zero Classic results, and Windows cannot discover Android in the
reverse direction. Do not make another HCD-only revision.

r21 is a controlled whole-baseline rollback to the only known Classic-receive
source state.  It restores the r16 91,900-byte HCD, removes the six r18 scan
overrides, and restores the r16 BT_WAKE deassert policy.  Post-flash validation
confirms boot, display, Ethernet, Wi-Fi, USB, UVC camera, MediaStore, HDMI
audio, RTC, Chinese locale, and the 30-minute timeout.  It also identified a
Rockchip kernel proc-read defect that can panic the board when validation reads
`/proc/bluetooth/sleep/btwrite`; the complete evidence and root cause are in
`docs/48-r21-flash-validation.md`.  r22 changes only those unsafe proc read
handlers, so future Bluetooth testing cannot be invalidated by the debug command
itself.

r22 is flashed and stable. Its proc-read fix prevents the Bluetooth debug path
from panicking the kernel, but BR/EDR Classic remains broken. Independent peer
testing in `docs/52-r22-bluetooth-deep-analysis.md` and
`docs/53-r22-independent-ubuntu-peer-validation.md` shows that Windows and
Ubuntu can exchange valid Classic traffic, while MB0002 receives zero Classic
Inquiry results and does not present complete EIR/FHS data. Wi-Fi rfkill,
`bcmdhd`, and three HCD variants were also excluded. The next discriminator is
to reflash the SHA-256-pinned historical r16 image and repeat the Ubuntu peer
test before making another source change.

A later attempted r16 return actually booted r22 again; the boot-partition
identity check and repeated peer test are recorded in
`docs/54-r22-reflash-validation-and-identity-check.md`. The r16 discriminator
is still pending, and any future flash must verify the embedded boot hash
before interpreting Bluetooth behavior.

The exact r16 image was subsequently restored and verified by its embedded boot
hash. It still received zero Classic results from Ubuntu and was not visible in
Ubuntu's reverse capture while Windows appeared as the positive control. This
closes the r16 regression theory; see
`docs/55-r16-ubuntu-peer-discriminator.md`. Further work should prioritize the
AP6275P controller/RF/board path rather than another Android scan-property
revision.

After the reported board-side repair, the unchanged r22 source tree remains the
release candidate. Reuse the already-built official r22 artifact rather than
creating an artificial r23 rebuild; see
`docs/56-r22-release-candidate-after-board-repair.md`.

Post-repair r22 validation found real progress but not a complete Bluetooth
fix: Android now receives a complete Windows Classic Extended Inquiry Result,
while Ubuntu still cannot discover MB0002 in the reverse direction. See
`docs/57-r22-board-repair-validation.md`. The remaining work is the board's
outgoing Classic discoverable/EIR/page path, not another framework scan change.

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
- No untracked board mutation; flashing and rescue operations must use the
  documented Loader/Maskrom workflow and be recorded in `docs/`.
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
