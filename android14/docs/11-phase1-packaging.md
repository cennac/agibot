# Phase 1 bootloader and release package record

## Scope and safety

This stage builds and packages the Rockchip boot chain after the successful
Android 14 `m` build. It does not flash any device, enter Maskrom, or write to
the AGIBOT board. The outputs are files under the remote build tree only.

Remote package directory:

```text
/data/agibot-android14-build/aosp/rockdev/Image-agibot_mb0002
```

## U-Boot build

Log and process ID:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-uboot-retry1.log
/data/agibot-android14-build/logs/2026-08-24-phase1-uboot-retry1.pid
```

The RKR6 common build entry was used:

```text
source build/envsetup.sh
lunch agibot_mb0002-userdebug
device/rockchip/common/build/rockchip/build.sh -U
```

Ubuntu 26.04 has no `python2`, while the old U-Boot packaging script hard-codes
`PYTHON=python2`. A private build-only link was created:

```text
/data/agibot-android14-build/tools-bin/python2 -> /usr/bin/python3
```

No system package was installed or modified. The U-Boot build completed and
produced the FIT boot chain, loader, and resource image.

Important limitation: `PRODUCT_UBOOT_CONFIG` is currently the generic
`rk3588_defconfig`. Its default device tree is `rk3588-evb`, not a dedicated
AGIBOT MB0002 U-Boot DTS. This is acceptable for a conservative package build,
but board-specific bootloader validation is required before any flashing
decision.

## Independent trust image

The FIT `uboot.img` already contains ATF and OP-TEE components. The generated
Rockchip parameter still defines a separate `trust` partition, so an
independent `trust.img` was also packed.

Running `u-boot/make.sh trust` directly exited with status 1 in FIT mode. Trace
showed that empty SHA/RSA platform variables became incomplete `--sha --rsa
--size` arguments. The equivalent bounded invocation was:

```text
cd rkbin
../u-boot/scripts/atf.sh --ini /data/agibot-android14-build/aosp/rkbin/RKTRUST/RK3588TRUST.ini
mv trust.img ../u-boot/trust.img
```

This produced a valid 4 MiB `trust.img` from the locked RK3588 trust INI and
prebuilt ATF/OP-TEE blobs.

## Rockchip image directory

Packaging logs:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-rockdev-package-retry1.log
/data/agibot-android14-build/logs/2026-08-24-phase1-rockdev-package-retry2.log
```

Retry 1 completed the image directory before `trust.img` was available. Retry 2
rerun `device/rockchip/common/mkimage.sh` after packing trust and copied it into
the release directory.

The package contains `uboot.img`, `trust.img`, `MiniLoaderAll.bin`,
`idbloader.img`, `resource.img`, `parameter.txt`, `boot.img`,
`boot-debug.img`, `recovery.img`, `dtbo.img`, `vbmeta.img`, `misc.img`,
`baseparameter.img`, and `super.img`.

The common flashing helper expected
`device/rockchip/common/build/rockchip/config.cfg`, which is absent in this
locked source tree. This does not prevent `update.img` creation, but the release
directory does not include a tool-specific flash config.

## update.img

Log:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-update-image-retry1.log
/data/agibot-android14-build/logs/2026-08-24-phase1-update-image-final.log
```

The existing static RKR6 tools were used from:

```text
RKTools/linux/Linux_Pack_Firmware/rockdev
```

The package list was generated from `parameter.txt`. The completed package
includes bootloader, parameter, uboot, trust, misc, dtbo, vbmeta, boot,
recovery, baseparameter, super, and backup metadata. It was created for eMMC
with:

```text
./mkupdate.sh rk3588 Image emmc
```

## gpt.img

Logs:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-gpt-image-retry1.log
/data/agibot-android14-build/logs/2026-08-24-phase1-gpt-image-retry2.log
/data/agibot-android14-build/logs/2026-08-24-phase1-gpt-image-final.log
```

Retry 1 stopped because the host PATH had no `simg2img`; it only renamed the
temporary copied `super.img` in the pack-tool directory. That temporary name
was restored, and retry 2 prefixed the AOSP host tool directory:

```text
/data/agibot-android14-build/aosp/out/host/linux-x86/bin
```

Retry 2 converted the sparse super image, created the GPT, copied partition
contents, and completed successfully. `parted` reported partitions from security
through userdata. It also warned that several Rockchip-defined partition start
sectors are not 1 MiB aligned. This comes from the generated parameter layout
and was not modified in Phase 1.

## Final regeneration

The first `build.sh -U` background wrapper continued after U-Boot completed and
later ran its final `mkimage.sh` pass. Because `mkimage.sh` recreates
`rockdev/Image-agibot_mb0002`, that delayed pass removed the first transient
`update.img` and `gpt.img` after they had been generated. No source or base
partition image was lost. After confirming the wrapper had exited, both release
containers were regenerated from the final image directory.

The final logs are:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-update-image-final.log
/data/agibot-android14-build/logs/2026-08-24-phase1-gpt-image-final.log
```

The component hashes remain authoritative for reproducibility. The final
`update.img` and `gpt.img` hashes below identify this generated artifact set;
container metadata and generated GPT identity can differ between package runs.

## Package inventory

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `update.img` | 2,054,738,506 | `f1dfe87ce40bb6f59767daad416002f958999e8f84ce652a313c7ce60204a285` |
| `gpt.img` | 4,337,452,544 | `3ae8a3410a7ce9bee561002592a88ea59ff3ca3aa6593cce4ddbcd75ca5dbad3` |
| `MiniLoaderAll.bin` | 487,872 | `d733d6e1d208db3a0bb940e1007a6698dd7f8c50711f6c3e90400a48cb8c154e` |
| `idbloader.img` | 317,440 | `c50ed48f2cb3278ea17776f90620310962f6ab9794b032ba9098a84ba792702d` |
| `uboot.img` | 4,194,304 | `19abbb834042b4a307068ba710348f7073728c3e8dd9f7bb059324bb2ba446f2` |
| `trust.img` | 4,194,304 | `a249f9e3f7cbbfad30f6b7baeceb50cdea8a3089330be780a382897e632ad35e` |
| `resource.img` | 352,256 | `3e6a8267d933bbff67d33be73ac1e3a3dcc53e4479398a7fb566cdcbf122d3cc` |
| `parameter.txt` | 661 | `6fd01c0b09129a4792e6102fe4ebebcae8c6f93f59c5aa2203068437bf8f3856` |

`file` identifies `gpt.img` as a GPT-protected disk image and verifies its
partition table. `uboot.img` is a FIT/device-tree image. `update.img`,
`trust.img`, and `resource.img` are Rockchip binary container formats and are
reported as generic data by `file`.

## Status and required review

The Android image set, generic RK3588 boot chain, `update.img`, and `gpt.img`
now build reproducibly from the recorded source revisions. They are not yet a
validated board release:

- U-Boot still uses `rk3588-evb`, not an AGIBOT-specific bootloader DTS.
- The wireless module, cameras, sensors, PCIe/VL805, and other disabled
  peripherals remain outside Phase 1.
- AVB is disabled and the package uses Rockchip's default unsigned vbmeta file.
- Partition alignment warnings and eMMC capacity/layout must be reviewed against
  the physical board before any write operation.
- No flashing, Maskrom, bootloader unlock, or board write has been performed.
