# Phase 2 AGIBOT U-Boot and package record

## Scope and safety

Phase 2 replaces the generic `rk3588-evb` early-boot identity in U-Boot with a
minimal AGIBOT MB0002 V2 device tree, keeps eMMC as the production boot device,
and regenerates the release containers. It does not flash any device, enter
Maskrom, unlock the bootloader, or write to the AGIBOT board.

The authoritative package remains under:

```text
/data/agibot-android14-build/aosp/rockdev/Image-agibot_mb0002
```

The Phase 1 final containers and bootloader components were preserved under:

```text
/data/agibot-android14-build/artifacts/phase1-final
```

## Design

RKR6 `rk3588_defconfig` enables both `CONFIG_ROCKCHIP_HWID_DTB` and
`CONFIG_USING_KERNEL_DTB_V2`. The kernel device tree is therefore loaded from
`resource.img`, but early SPL storage, UART, and boot-order policy still come
from the U-Boot device tree. A board-specific U-Boot tree is useful without
duplicating the Linux 6.1 DTS.

The Phase 2 U-Boot tree intentionally contains only:

- AGIBOT root model and compatibility strings.
- UART2 console inherited from the common RK3588 U-Boot include.
- eMMC `sdhci` and SD `sdmmc` early-boot policy.

The resolved boot order is:

```text
/mmc@fe2e0000 /mmc@fe2c0000
```

`fe2e0000.mmc` is eMMC and remains first. SD stays as a conservative recovery
fallback. Wireless, cameras, robot peripherals, PMIC policy, display policy,
and other Linux-oriented nodes are not copied into U-Boot.

The USB hub reset pulse remains in Linux because the kernel has the validated
AGIBOT GPIO driver. U-Boot fastboot/Maskrom download paths have not been
validated on hardware, so no speculative GPIO pulse was added to Phase 2.

## Source changes

Remote source commits:

| Project | Branch | Commit |
|---|---|---|
| `u-boot` | `agibot/android14-rkr6` | `45e6d7f261` |
| `device/rockchip/rk3588` | `agibot/android14-rkr6` | `7170c81` |

Canonical metadata files:

```text
android14/overlay/u-boot/configs/rk3588-agibot-mb0002.config
android14/overlay/u-boot/arch/arm/dts/rk3588-agibot-mb0002-v2.dts
android14/patches/0001-u-boot-agibot-early-boot.patch
android14/patches/0002-u-boot-agibot-of-list.patch
```

The product now selects:

```make
PRODUCT_UBOOT_CONFIG := rk3588_defconfig rk3588-agibot-mb0002.config
```

The configuration fragment sets:

```text
CONFIG_BASE_DEFCONFIG="rk3588_defconfig"
CONFIG_DEFAULT_DEVICE_TREE="rk3588-agibot-mb0002-v2"
CONFIG_OF_LIST="rk3588-agibot-mb0002-v2"
```

Keeping `rk3588_defconfig` as the base preserves Rockchip RKR6 FIT, loader,
trust, AVB, storage, and USB policy. Only the board DT identity and FIT DT list
are overridden.

## U-Boot build

The first direct build log is:

```text
/data/agibot-android14-build/logs/2026-08-24-phase2-uboot-build.log
```

It compiled the AGIBOT DTB but failed while creating `u-boot.img` because the
base RK3588 configuration still had `CONFIG_OF_LIST="rk3588-evb"`. Rockchip's
FIT rule therefore tried to open the removed `rk3588-evb.dtb`. The fragment was
corrected to set the AGIBOT OF list; this is preserved as patch 0002.

The successful retry log is:

```text
/data/agibot-android14-build/logs/2026-08-24-phase2-uboot-retry1.log
```

Bounded direct-build commands:

```text
cd /data/agibot-android14-build/aosp/u-boot
make distclean
make rk3588_defconfig rk3588-agibot-mb0002.config
PATH=/data/agibot-android14-build/tools-bin:/data/agibot-android14-build/tools:$PATH ./make.sh
```

The build completed with:

```text
Platform RK3588 is build OK, with exist .config
```

`fdtget` verified the compiled DTB:

```text
/chosen/u-boot,spl-boot-order = /mmc@fe2e0000 /mmc@fe2c0000
/model = AGIBOT MB0002 V2
/compatible = agibot,mb0002-v2 rockchip,rk3588
```

`mkimage -l uboot.img` reports FIT configuration:

```text
Configuration 0 (conf)
  Description: rk3588-agibot-mb0002-v2
```

The independent `trust.img` was regenerated from the locked RK3588 trust INI
with the same bounded `rkbin/scripts/atf.sh` procedure used in Phase 1. Its
hash is unchanged from Phase 1.

## Rockdev and release containers

Rockdev regeneration log:

```text
/data/agibot-android14-build/logs/2026-08-24-phase2-rockdev-build.log
```

The first Phase 2 update-package attempt completed tool-wise but was rejected:
it used the RKTools directory left over from the Phase 1 GPT conversion, where
`super.img` had already become a 3.1 GiB raw image. It produced an oversized
3,375,575,626-byte transient package and was not promoted. The log remains at:

```text
/data/agibot-android14-build/logs/2026-08-24-phase2-update-image.log
```

The Rockdev sparse image and Phase 2 bootloader files were then explicitly
copied into RKTools. `file` confirmed:

```text
Image/super.img: Android sparse image, version: 1.0
```

Final update package log:

```text
/data/agibot-android14-build/logs/2026-08-24-phase2-update-image-final.log
```

Final GPT package log:

```text
/data/agibot-android14-build/logs/2026-08-24-phase2-gpt-image-final.log
```

`android-gpt.sh` converted the sparse super image, copied partition contents,
and completed the GPT. `parted` reports partitions `security` through
`userdata`.

## Final package inventory

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `update.img` | 2,054,738,506 | `d89efcc0a9ef0356616fb90eb4e266978071eb9e545a0c0f89fb0ebac9053351` |
| `gpt.img` | 4,337,452,544 | `dcf6bce5f461707cf3c34dfa3769b91658855e128505e88d8e6a656d47be1430` |
| `uboot.img` | 4,194,304 | `f2f0e9bbce10ee1a1417a9e61ad1de41d5f1adb42af09dc0e3ae546bbbf6e8fa` |
| `trust.img` | 4,194,304 | `a249f9e3f7cbbfad30f6b7baeceb50cdea8a3089330be780a382897e632ad35e` |
| `MiniLoaderAll.bin` | 487,872 | `ff1962b2bd95f2bcf97aa5b2f88429ba132abbe9eaa62491a70b7781056af6dd` |
| `idbloader.img` | 317,440 | `c50ed48f2cb3278ea17776f90620310962f6ab9794b032ba9098a84ba792702d` |
| `resource.img` | 352,256 | `3e6a8267d933bbff67d33be73ac1e3a3dcc53e4479398a7fb566cdcbf122d3cc` |
| `parameter.txt` | 661 | `6fd01c0b09129a4792e6102fe4ebebcae8c6f93f59c5aa2203068437bf8f3856` |

`resource_tool --print` lists `rk-kernel.dtb` plus the Rockchip battery and
logo resources. Unpacking and `fdtget` verified the embedded kernel DTB root:

```text
AGIBOT MB0002 V2
agibot,mb0002-v2 rockchip,rk3588
```

## Partition-layout review

The Phase 1 `parameter.txt` was retained without modification. All partitions
through `frp` start on 1 MiB boundaries. `baseparameter`, `super`, and the grow
`userdata` partition start at 512 KiB boundaries:

| Partition | Start sector | Start offset |
|---|---:|---:|
| `baseparameter` | 2,083,840 | 1017.5 MiB |
| `super` | 2,085,888 | 1018.5 MiB |
| `userdata` | 8,459,264 | 4130.5 MiB |

This explains the `parted` optimal-alignment warnings. It is a Rockchip layout
risk to review against the physical eMMC before any write, not a Phase 2 code
change. Repacking the layout only to silence `parted` would move every later
partition and invalidate the known update container.

## Status and remaining review

Phase 2 is source-complete and package-complete, but it is not a validated
board release:

- No image has been flashed and no boot log has been captured.
- U-Boot USB hub reset behavior remains intentionally unimplemented.
- `baseparameter`, `super`, and `userdata` 512 KiB alignment remains open.
- AVB is disabled and the package uses Rockchip's unsigned default vbmeta.
- Wireless, cameras, sensors, PCIe/VL805, and other ambiguous peripherals
  remain disabled.
- A future hardware-validation phase must decide whether `gpt.img` or
  `update.img` is appropriate and must perform any write explicitly.
