# Media driver and SW9200 Loader repair

## Scope

Driver validation round 1 proved that codec capability enumeration was present,
but real H.264 and HEVC playback failed because the deployed kernel device tree
left the RK3588 media engines disabled. This change enables the complete
Rockchip media node group in the AGIBOT kernel DTS.

The same review also confirms that SW9200 is the board's hardware Loader key
and can be used to enter a mode suitable for flashing an Android image.

## Media DTS repair

The following nodes are enabled as a coherent set, following Rockchip's
`rk3588-evb.dtsi` integration:

```text
MPP service
AV1 decoder and MMU
AVS decoder
IEP and MMU
JPEG decoder and MMU
four JPEG encoder cores, CCU and MMUs
RGA3 core 0/1 and MMUs
RGA2
RKVDEC CCU, core 0/1 and MMUs
RKVENC CCU, core 0/1 and MMUs
RK video tunnel
VDPU and MMU
VEPU
```

Both RKVENC cores retain the RK806 `vdd_vdenc_s0` and
`vdd_vdenc_mem_s0` supplies. Enabling only the decode cores is insufficient:
Android playback and screen recording also depend on MPP, RGA, IOMMU and video
post-processing paths.

After deployment, the minimum acceptance checks are:

```text
/dev/vcodec_service exists
/dev/rga exists
mpp-srv probe success appears in dmesg
real 1920x1080 H.264 playback succeeds
real 3840x2160 HEVC playback succeeds
screenrecord produces a non-empty playable MP4
```

## SW9200 Loader behavior

The Android U-Boot board DTS contains an `adc-keys` node on SARADC channel 1.
SW9200 is mapped to `KEY_VOLUMEUP` and labeled `SW9200 loader`. Both the key
node and its child carry `u-boot,dm-spl`, so they survive U-Boot's DT filtering.
The generated U-Boot DT source was inspected and contains this node.

Expected operation:

1. Fully power the board off.
2. Hold SW9200.
3. Apply power while continuing to hold the key.
4. Wait for RKDevTool to report `LOADER` or `MASKROM`, then release the key.

U-Boot proper detects the key in `setup_download_mode()`. It normally starts
RockUSB Loader mode. If the USB gadget path cannot start, Rockchip U-Boot may
fall back through `rbrom` to Maskrom. Both states are recoverable and can be
used to deploy Android, but their RKDevTool procedures differ.

### Flashing Android from Loader

Do not place `Loader@0xCCCCCCCC` and the complete image in the same Download
Image operation while the device is already in U-Boot RockUSB Loader mode; that
combination can fail while reading flash information.

Use this sequence instead:

1. In RKDevTool Advanced Functions, download the known RK3588 boot loader.
2. Confirm that the device re-enumerates as Loader.
3. In Download Image, select only the complete Android image at address 0.
4. Start the write and wait for the success result before removing power.

For Maskrom, the standard complete-image upgrade path remains preferred and
has already been regression-tested twice. The known image is:

```text
E:\AIPorject\101\android14-flash\full-zh-rknn-20260825\agibot-mb0002-android14-zh-rknn-20260825.img
SHA-256: 5bf4260e5fdef6d40d5675ce334398dc58acd1806a43889a7fdb695fe3cde1f4
```

Do not erase the existing IDB loader merely to test SW9200. The button path can
be validated non-destructively by a cold power-on with the key held.

## Build author identity

The product publishes immutable author metadata for diagnostics and support:

```text
ro.build.author.name=Cennac
ro.build.author.email=cennac@163.com
ro.build.author.website=cennac.com
```

Settings also shows a non-interactive, copyable `System author` / `系统作者`
entry under About device with `Cennac · cennac@163.com · cennac.com`. The
English and Simplified Chinese titles are both supplied; the identity string is
intentionally not translated.

## Source revisions

The changes were committed independently in the remote Android source trees so
their ownership and replay order remain explicit:

```text
kernel-6.1:            4f979f576613 arm64: dts: enable AGIBOT RK3588 media engines
device/rockchip/rk3588: ea485c7      agibot: publish system author metadata
packages/apps/Settings: c9c95055b0  Settings: show AGIBOT system author information
```

The repository carries replay patches `0007` and `0008` for the kernel media
nodes and Settings author entry. The product property change is part of the
board overlay copied into the Android tree by the documented source setup.

## Build result

The remote host at `cennac@192.168.88.66` built the kernel, external Wi-Fi and
camera modules, DTB, kernel boot image, and resource image successfully with:

```bash
cd /data/agibot-android14-build/aosp
./build.sh -K -J8
```

Build log:

```text
/data/agibot-android14-build/logs/2026-08-25-media-kernel.log
```

Result hashes:

```text
a65ba556fc76484ea89281adbf42afa6aabd7ff0dd8d62b46bc41aed0f53fdde  kernel-6.1/arch/arm64/boot/dts/rockchip/rk3588-agibot-mb0002-v2.dtb
5d42ea0202876b53bcff33a1fe22aa32e461d588f12f75a719f7dacb568a58c6  kernel-6.1/boot.img
0fb6935bf5664262ae6a149f75a9957f4b7224288742a0b0454183d302ec221d  kernel-6.1/resource.img
```

After those outputs completed, the wrapper entered Android Soong
`bootimage`. On the 30 GiB build host, `soong_build` consumed roughly
17-21 GiB RAM plus about 17 GiB swap while creating the Bazel symlink forest.
It made no bounded progress for over an hour, so the process group was stopped
to avoid continued swap pressure. This does not invalidate the kernel outputs,
but the final Android `bootimage` packaging and the Settings/system image build
remain pending. Do not flash these incremental outputs as a complete image.

## SSD swap retest

The first retry was stopped again after roughly five hours with no log progress
past `Creating Bazel symlink forest`. Storage inspection showed that `/data`
and its 32 GiB swap file were on the 2.7 TiB rotational disk (`/dev/sdb1`),
while the SSD was the root filesystem (`/dev/sda2`).

A dedicated 48 GiB swap file was created on the SSD:

```text
/var/lib/soong-swap-48g.img
UUID: 7a883d4e-d2d9-4feb-bc6f-27b15fbfc80f
priority: 10
```

It was added to `/etc/fstab` so it survives a reboot. The old `/data` swap file
was not listed in `/etc/fstab`. An attempt to disable it immediately exposed
about 6.8 GiB of randomly distributed pages and would have taken hours on the
rotational disk, so the migration was interrupted. For this boot it remains at
lower priority than both SSD swap areas; after a reboot only the SSD swap files
will activate, and the old file can then be deleted to reclaim 32 GiB.

The first nohup retry omitted the Android lunch environment and selected the
default `aosp_arm` target; it failed immediately at `kernel-`. This was a launch
environment error, not a swap result, and is recorded in:

```text
/data/agibot-android14-build/logs/2026-08-25-media-kernel-ssd-retry.log
```

The corrected retry sources `build/envsetup.sh`, selects
`agibot_mb0002-userdebug`, and reruns the original `./build.sh -K -J8` command
in the original AOSP path:

```text
/data/agibot-android14-build/logs/2026-08-25-media-kernel-ssd-retry2.log
/data/agibot-android14-build/logs/2026-08-25-media-kernel-ssd-retry2.pid
```

This second retry selected the correct product, but its clean nohup PATH had no
`python` command. Kernel compilation reached the final Rockchip DTB packaging
step and then failed before Soong. This was another launch-environment issue,
not an SSD-swap failure.

The successful third retry added a private PATH alias:
`/tmp/agibot-build-bin/python -> /usr/bin/python3`, selected
`agibot_mb0002-userdebug`, and reran the original command in the original AOSP
path:

```text
/data/agibot-android14-build/logs/2026-08-25-media-kernel-ssd-retry3.log
/data/agibot-android14-build/logs/2026-08-25-media-kernel-ssd-retry3.pid
```

Soong completed the formerly blocked Bazel symlink-forest/build-graph phase in
about 8 minutes 20 seconds. During the run it was observed at about 22.7 GiB
RSS while the new SSD swap area absorbed about 13.7 GiB. The Android bootimage
Ninja phase completed in 18 minutes 20 seconds, and the complete wrapper
finished with `Make image ok!` after about 28 minutes 30 seconds.

The regenerated release image was packed with the existing Rockchip tool path:
`./mkupdate.sh rk3588 Image emmc`. Its log is:

```text
/data/agibot-android14-build/logs/2026-08-25-media-ssd-update-image.log
```

The complete eMMC update image is:

```text
/data/agibot-android14-build/aosp/RKTools/linux/Linux_Pack_Firmware/rockdev/update.img
```

Final artifact hashes:

```text
0df6a7baad87afc6d10a9e06d58ca87513ec7ce79be0f07d6b0730acd24dcb97  boot.img
b507a56215d2dd997ae736060db8284957a0f47b8220f3f5b0c489dfc73154d2  boot-debug.img
a65ba556fc76484ea89281adbf42afa6aabd7ff0dd8d62b46bc41aed0f53fdde  dtb.img
0fb6935bf5664262ae6a149f75a9957f4b7224288742a0b0454183d302ec221d  resource.img
cb5d13050fa8b78bd86fc41aedf62ba6eb6775d690b380109d8d088eedfc9ee0  super.img
5ba82d5da663ff55710f0999e8dc0916794ef5fa9a49305736666092a136311e  update.img
```

This update image has not been flashed. It combines the newly built media-engine
kernel boot/resource images with the existing 07:19 `super.img` that already
contains the author metadata and Settings entry.
