# Android 14 source baseline

## Decision

Use the public Radxa ROCK 5C Android 14 RK3588 BSP as the initial source
baseline. The relevant manifest branch is based on
`Rockchip_Android14.0_SDK_RELEASE` with Rockchip RKR6 revisions and a Linux 6.1
kernel.

This choice gives the project a public, inspectable RK3588 Android 14 tree that
already includes Rockchip device configuration, vendor HALs, U-Boot, kernel, and
display/multimedia integration. It avoids starting from generic AOSP, which
would not contain the required RK3588 board support.

## Locked revisions

The authoritative values are stored in `baseline/radxa-android14-rkr6.json`.
The important initial values are:

| Item | Revision |
|---|---|
| Manifest branch | `Android14-rkr6-rock5c` |
| Manifest commit | `ac6785b31865b06223ae262c8ed42b14b11f5aaa` |
| Release tag | `radxa-rock5c-android14-20250811` |
| Release tag commit | `d8d506fa25d14a1639f0f4b06292656e212bb317` |
| RK3588 device | `4e9794df017bd56f50d8835f95dfdb8b39abf90f` |
| Rockchip common SDK | `7e6116f5fe4f29e97d242115f8fd1ddf4a3363da` |
| Rockchip vendor common | `13bbb25125ce0aea9e988aaa2b31c3f8e159af30` |
| Rockchip vendor hardware | `90dfdbc85a4a2e787f1541ce1f3fc1bbb8b6b49d` |
| U-Boot | `fba0c8f28039e0f253ada4a71613ae1dd401c864` |
| Linux 6.1 kernel | `aaf1830c6647a51523704d5e21c39a7705d3e79d` |

`repository_hint` fields are convenience hints, not substitutes for repo manifest
resolution. The manifest can remap repository names; use the logical path and
revision when validating a future full checkout.

## What the baseline does not provide

The Radxa ROCK 5C image and board configuration are not directly usable on
AGIBOT MB0002 V2. At minimum, AGIBOT needs a separate product definition,
vendor-kernel DTS, power-tree verification, eMMC partition layout, HDMI0 route,
PHY configuration, USB hub reset sequencing, Ethernet reset/delays, and wireless
identification.

## Code-only policy

Phase 0 intentionally does not sync or build. When a writable source machine is
allocated later, the expected source initialization is:

```bash
repo init \
  -u https://github.com/radxa/manifests.git \
  -b Android14-rkr6-rock5c \
  -m rockchip-u1-release.xml
repo sync -c -j8
```

Before using that checkout, verify the manifest commit and each pinned project
revision against this directory's baseline JSON. Do not substitute the release
image for source integration.
