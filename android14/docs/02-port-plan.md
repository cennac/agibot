# Android 14 port plan

## Milestone 0 - code skeleton

- [x] Pin the public Android 14 RK3588 source baseline.
- [x] Create a normal Android product skeleton.
- [x] Record HDMI0-first and landscape policy.
- [x] Record the wireless-module ambiguity.
- [x] Keep firmware and images outside Git.

No compilation or board mutation occurs in this milestone.

## Milestone 1 - source integration, still no board write

- Sync the locked Android source on a separate build host.
- Verify every logical project against `baseline/radxa-android14-rkr6.json`.
- Copy the product skeleton under `device/rockchip/rk3588/agibot_mb0002`.
- Create a vendor-kernel DTS include named `rk3588-agibot-mb0002-v2.dts`.
- Preserve UART2 at 1500000 baud as the early console.
- Enable eMMC, PMIC rails, HDMI0, native USB host, hub reset, I2C3, and only
  the twelve development USB VBUS outputs on PCA9555 address `0x20`.
- Keep DSI, camera, CAN, NPU, and audio disabled.
- Run `dt-validate` or the SDK's DTS syntax checks only; still do not package.

## Milestone 2 - build validation

Only after milestone 1 review:

- Build `agibot_mb0002-userdebug` for `arm64`.
- Treat successful compilation as a build check, not boot readiness.
- Inspect the generated DTB, boot image headers, Android DTBO, and partition
  table before any flash decision.
- Document all differences from the locked baseline.

## Milestone 3 - recovery-safe first boot

- Confirm the known-good AGIBOT rescue image and loader path.
- Attach serial console and preserve complete logs.
- Boot from a non-eMMC path if practical; otherwise use a minimal eMMC layout
  with a documented restore procedure.
- Success criteria: U-Boot log, kernel handoff, Android init, ADB over USB or
  Ethernet, HDMI EDID detection, one landscape display, and USB HID input.

## Milestone 4 - core peripheral bring-up

Recommended order:

1. Ethernet and ADB stability.
2. GPU rendering and SurfaceFlinger.
3. Video decode/encode policy.
4. Audio.
5. Wireless after the module is physically identified.
6. Recovery and OTA layout.
7. DSI and advanced display combinations.
8. Robot-specific buses and sensors.

## Change discipline

Every hardware enablement commit must state the source node and binding, why the
GPIO/regulator/clock differs from ROCK 5C, which original AGIBOT artifact
supports the change, whether it can be safely disabled at runtime, and the
expected serial-log signature.
