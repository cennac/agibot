# Android 14 build validation log

## Environment

- Build host: `cennac@192.168.88.66`
- AOSP root: `/data/agibot-android14-build/aosp`
- Logs: `/data/agibot-android14-build/logs/`
- Product: `agibot_mb0002-userdebug`
- Manifest: `ac6785b31865b06223ae262c8ed42b14b11f5aaa`
- Source checkout: 1236 projects, about 674 GiB
- `/data` free space before Android build: about 2.0 TiB

The host is a newer Ubuntu release than the BSP's commonly documented 20.04 or
22.04 environment. Host packages have so far been sufficient, with one command
compatibility fix documented below.

## Product configuration

The product parses successfully with:

```bash
cd /data/agibot-android14-build/aosp
source build/envsetup.sh
lunch agibot_mb0002-userdebug
```

This validates the lunch choice, product inheritance chain, board configuration,
and the `rk3588-agibot-mb0002-v2` DTS setting.

## Kernel and DTB validation

The first kernel build produced the DTB but failed while compiling the new USB
hub reset driver because `device_property_read_u32()` was used without including
`<linux/property.h>`. The include was added and committed to the remote kernel
branch.

Rockchip's resource packaging script invokes `python`, while this Ubuntu host
only provides `python3`. A build-only compatibility link was created:

```text
/data/agibot-android14-build/tools-bin/python -> python3
```

The retry put that directory first on `PATH`; no system Python alias was
changed.

The kernel retry succeeded and produced:

| Artifact | Size | SHA-256 |
|---|---:|---|
| `kernel-6.1/arch/arm64/boot/Image` | 36M | `8b37059b3a5e1b4bbca631d3a290d09f631afa2abdc82160234234be1e495f0d` |
| `kernel-6.1/arch/arm64/boot/dts/rockchip/rk3588-agibot-mb0002-v2.dtb` | 258K | `a61d56d11ae216d121cd8703e1189923fb801f17931d8a60f56a0df30bd99851` |
| `kernel-6.1/boot.img` | 37M | `14d7a94feb0f81675b8b46c0a73365583e015a913665030bd35081a980a9aee8` |
| `kernel-6.1/resource.img` | 295K | `29f1795800eda2b9d66fde3e9ac6a173fa38a4c84b74de93f5f34dfb0396cc4a` |
| `kernel-6.1/zboot.img` | 18M | `cb585b5b8d96b6176a3c5c0dfcf612f63ef803b52706330e192896bf647a1db7` |

The DTB compile emits the existing RKR6 warning about the leading-zero
`vendor-storage-rm@00000000` unit address. The node comes from the shared
`rk3588-android.dtsi`; it was not modified by this port.

## Full Android build, attempt 1

Command shape:

```bash
cd /data/agibot-android14-build/aosp
source build/envsetup.sh
lunch agibot_mb0002-userdebug
m -j8
```

Log:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full.log
```

Soong bootstrap and Android.bp analysis reached 100%, then failed because the
locked Radxa source combination lacks `.latest` API tracking filegroups for
`framework-pdf` and `framework-photopicker`. The two errors identify the missing
`framework-pdf.api.public.latest` and `framework-photopicker.api.public.latest`
families of files.

The cause was verified from the manifest: MediaProvider is pinned to
`android-14.0-mid-rkr6` commit
`0ee07aa90b21e547c4a266145689104a7e26fe21` (December 2024), while the public
Radxa override pins `prebuilts/sdk` to `android-14.0.0_r27` commit
`92e2a80095695a40fa854fff44268e0bc333c154` (October 2023). The SDK predates
both APEX framework libraries.

The bounded workaround is committed as MediaProvider commit
`f0e2b49e94df52a3989644041196cbca5b9ec5ce`. It disables latest-version API
tracking only for those two modules.

## Full Android build, retry 1

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry1.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry1.pid
```

The retry was started with `m -j8` and the compatibility `python` link first in
`PATH`. It passed the previously failing MediaProvider API analysis, consumed
about 17.8 GiB while rebuilding the Soong graph, and then failed after 5 minutes
56 seconds in `packages/services/Car`.

The new error was:

```text
module "libassimp" ... source path
"packages/services/Car/cpp/evs/apps/default/res/rkrender/lib64/libassimp.so"
does not exist
```

Inspection of Car commit `cecee6aa41` showed that the upstream RKAVM change
committed the other renderer binaries but omitted this file. The public branch
tip remained `d3e96db43f635b1cbbaecb2ba4ee6a9916de702d` with no follow-up.

Because AGIBOT Phase 1 disables camera/EVS, the bounded response was:

- product commit `6609e77cf6b3d7ae9d19331ce3257b530e981bab`, setting
  `ENABLE_EVS_SERVICE=false` and `ENABLE_EVS_SAMPLE=false`;
- Car commit `58083a560aa994a5feaa0f3559e3dcd13b47c3cc`, disabling the
  incomplete EVS sample module chain rather than adding a fake library.

## Full Android build, retry 2

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry2.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry2.pid
```

The host has only about 30 GiB RAM and a 4 GiB swap. Retry 1 survived Soong graph
generation close to that limit, so retry 2 uses `m -j4`. This trades build time
for lower memory pressure during the actual compile stage.

Retry 2 completed Soong analysis and Kati packaging-rule generation. It reached
the main Ninja stage after 31 minutes 25 seconds, proving that both preceding
Soong source-combination failures were resolved.

Main Ninja then failed immediately because Rockchip's Bluetooth module requires
`$(TARGET_DEVICE_DIR)/bt_vendor.conf` when `BOARD_BLUETOOTH_SUPPORT` is true.
The AGIBOT wireless module is not yet identified, so Bluetooth must remain off;
adding an unverified vendor configuration would be misleading.

Device commit `7925ab8e8d22d39b6eb9827be45a240a97b4fdb3` explicitly sets:

```make
BOARD_BLUETOOTH_SUPPORT := false
BOARD_HAVE_BLUETOOTH := false
BOARD_BLUETOOTH_LE_SUPPORT := false
```

## Full Android build, retry 3

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry3.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry3.pid
```

The retry continued with `m -j4` and the temporary 32 GiB build swap active.
It completed Soong glob generation, Kati rule generation, and reached the main
Ninja stage in 3 minutes 2 seconds.

Main Ninja failed immediately because Rockchip's common RK3588 `device.mk`
unconditionally copies `$(TARGET_DEVICE_DIR)/media_profiles_default.xml` to
`vendor/etc/media_profiles_V1_0.xml`, but the new AGIBOT device directory did
not yet contain that file:

```text
FAILED: ninja: 'device/rockchip/rk3588/agibot_mb0002/media_profiles_default.xml',
needed by 'out/target/product/agibot_mb0002/vendor/etc/media_profiles_V1_0.xml',
missing and no known rule to make it
```

The available RK3588 profiles were compared. `rk3588_s`, `rk3588_t`, and
`rk3588_u` are identical; the Radxa ROCK 5C file differs only by enabling two
720p camcorder profiles. Since AGIBOT Phase 1 disables cameras and the common
codec capability declarations are otherwise identical, the full-RK3588 baseline
`rk3588_s/media_profiles_default.xml` was copied unchanged.

The file SHA-256 is:

```text
1b35323555744b441eab024a9f5ce1e8f1142cb909cb8a472b579cd211349fa2
```

Device commit `b37aba2aef0dc54c361c54bef2379e68f760be24` adds this exact file.

## Full Android build, retry 4

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry4.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry4.pid
```

The retry was started with `m -j4` after adding the media profile. Ninja
recognized the new file and regenerated only the affected build graph. It then
resumed Kati/packaging-rule generation and reached main Ninja after 1 minute 52
seconds.

Main Ninja then exposed a second Bluetooth dependency in the recovery factory
test:

```text
FAILED: ninja: 'device/rockchip/rk3588/agibot_mb0002/bt_vendor.conf',
needed by 'out/target/product/agibot_mb0002/recovery/root/pcba/bt_vendor.conf',
missing and no known rule to make it
```

This path is independent of `BOARD_BLUETOOTH_SUPPORT`. It comes from
`device/rockchip/common/modules/pcba.mk`, which is active only when
`TARGET_ROCKCHIP_PCBATEST` is true; Rockchip's common BoardConfig defaults that
variable to true. AGIBOT Phase 1 does not validate or use the recovery PCBA
factory test, so carrying a guessed Bluetooth vendor file there would be unsafe.

Device commit `6e5f8cbbcfc7a622defbfe5c9c859fac83dd87e1` therefore sets:

```make
TARGET_ROCKCHIP_PCBATEST := false
```

## Full Android build, retry 5

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry5.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry5.pid
```

The retry was started with `m -j4` after disabling recovery PCBA. Build-graph
regeneration completed and main Ninja started after 1 minute 46 seconds. It then
failed on:

```text
FAILED: ninja: 'device/rockchip/rk3588/agibot_mb0002/dtbo.img',
needed by 'out/target/product/agibot_mb0002/recovery.img',
missing and no known rule to make it
```

The product had set `PRODUCT_DTBO_TEMPLATE` and supplied `dt-overlay.in`, but it
did not include Rockchip's `AndroidBoard.mk` generation rules. Consequently the
common BoardConfig retained its default prebuilt path
`$(TARGET_DEVICE_DIR)/dtbo.img`, and no rule generated that file from the
template.

Device commit `886d61f93f3876840890172a8c4bac6e4856caad` adds the same board
artifact includes used by the RK3588 reference products:

```make
-include device/rockchip/common/build/rockchip/RebuildFstab.mk
-include device/rockchip/common/build/rockchip/RebuildDtboImg.mk
-include device/rockchip/common/build/rockchip/RebuildParameter.mk
```

## Full Android build, retry 6

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry6.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry6.pid
```

The retry was started with `m -j4` after wiring fstab, DTBO, and parameter
generation. Build-graph regeneration was still in progress when this entry was
written.

## Full Android build, retry 6 result

Retry 6 completed all product configuration and entered the 160,833-task Ninja
compile. It stopped in the legacy RenderScript clang tool because Ubuntu 26.04
does not ship the old ABI 5 libraries required by clang 3.8:

```text
clang.real: error while loading shared libraries: libncurses.so.5: cannot open shared object file
```

The missing `libtinfo.so.5` dependency was also confirmed with `ldd`. No source
or system package was changed. Ubuntu 18.04-compatible `libncurses5` and
`libtinfo5` packages were downloaded and unpacked under:

```text
/data/agibot-android14-build/compat-libs/ncurses5/
```

The old clang was verified with `LD_LIBRARY_PATH` pointing only to that private
directory. The downloaded package files and compatibility path remain outside
Git.

## Full Android build, retry 7

Retry 7 will reuse the completed Ninja graph with this environment prefix:

```text
LD_LIBRARY_PATH=/data/agibot-android14-build/compat-libs/ncurses5/lib/lib/x86_64-linux-gnu
```

Retry 7 showed Ninja's failed RenderScript nodes were not automatically
invalidated, and therefore did not rebuild the missing outputs. Touching the
four affected RenderScript source files forced those exact nodes to rerun.
Passing `LD_LIBRARY_PATH` through `m` was also insufficient because Soong
sanitizes the environment for child Ninja commands. The old clang binary has an
`$ORIGIN/../lib64` RPATH, so private symlinks to the downloaded ABI-5 libraries
were placed in its own `lib64` directory on the build host.

## Full Android build, retry 9

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry9.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry9.pid
```

The clang compatibility check passed and retry 9 reached ordinary compilation:
over 5,000 of 160,513 Ninja tasks were complete at the last observation, with
no RenderScript loader error. The private symlinks and downloaded libraries are
build-host state only and are not source changes.

## Full Android build, retry 10

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry10.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry10.pid
```

Retry 10 resumed after retry 9 reached 31%. It passed the earlier RenderScript
stage and advanced to 37% of the remaining graph. The next failure was another
legacy host executable, `out/host/linux-x86/bin/bcc_strip_attr`, which also
requires `libncurses.so.5` and `libtinfo.so.5`. Private ABI-5 library symlinks
were added to the host output `lib64` directory searched by that executable's
RUNPATH. No system package or Android source file was modified.

## Full Android build, retry 11

Log and process ID files:

```text
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry11.log
/data/agibot-android14-build/logs/2026-08-24-phase1-android-full-retry11.pid
```

After `bcc_strip_attr` was fixed, retry 10 stopped while validating the
prebuilt Rockchip Chromium package because `Chromium.apk` was only a 134-byte
Git LFS pointer. The pointer identifies SHA-256:

```text
921e0d0e2c7509781430f6fee0bb40dc16e820d095e3d6ebda1ca85fb98faa38
```

The exact LFS object was fetched with:

```text
git lfs pull --include=apps/Chromium/Chromium.apk
```

The resulting 248 MiB file matches that SHA-256 and is recognized as an Android
APK. It is the only Git LFS object in that vendor project. Retry 11 was then
started with `m -j4` to continue from the completed graph.

## Retry 11 completion and artifacts

Retry 11 completed successfully at 2026-08-24 16:49:41 +0800 after 2 hours,
37 minutes, and 42 seconds. The final log line was:

```text
#### build completed successfully (02:37:42 (hh:mm)) ####
```

Two Bazel messages named APEX staging directories as outputs, and `lpmake`
printed sparse-header diagnostics while composing `super.img`; neither stopped
the build. The final target `super.img` was written successfully.

Build fingerprint:

```text
AGIBOT/agibot_mb0002/agibot_mb0002:14/UQ1A.240205.004.B1/cennac08241412:userdebug/release-keys
```

Artifact inventory and SHA-256 values:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `boot.img` | 39,747,584 | `8fa97599b4f6e18a903a726f2bcea3c4ee032ee3ac80d3b1db220d4aeb6d2811` |
| `boot-debug.img` | 39,938,048 | `79c97bdda675aef74f131ee32bc3090e31633bef5be11af83cbde336db837ad7` |
| `dtb.img` | 263,388 | `a61d56d11ae216d121cd8703e1189923fb801f17931d8a60f56a0df30bd99851` |
| `rebuild-dtbo.img` | 4,194,304 | `da9d0f815c6199bd0b4fef765862fee0e6a98c42c314b5daf4c53ab057aa57a6` |
| `recovery.img` | 57,991,168 | `a69cdbc7098e1c1ebe2d4e84bb19759605a204f86b32d970e99f6865057442ac` |
| `super.img` | 1,942,330,340 | `12e873c308baad0c9c249b55574b27385e7a912f24d2d6081d8b252eabbf46e1` |
| `system.img` | 1,263,710,208 | `8f0230713dbf7b5732896f786dd9d019584409fdd8f369d07a306b1cec7cfa41` |
| `system_ext.img` | 183,652,352 | `f51120308fcd61404ddbab226c2941e14a366a1b7cb2b4462ee5cc903d1b736f` |
| `product.img` | 281,063,424 | `56bda54bf842c3fa28f6beb312c09b988287d0c1e00e78de78dde0c952ed843a` |
| `vendor.img` | 216,973,312 | `a57d68be65a33e479b2bc756832111ac4caf1b5d39776703acbe523b0756c586` |
| `vendor_dlkm.img` | 5,894,144 | `6bfa02caebb5b987a3d47616f1cb3524885b7b2adeebdcee5bdf4ae5822c7ac5` |
| `odm.img` | 815,104 | `9f0fb769505d98444110b16a060efb1d6e469837a920284f43aa42767549264b` |
| `odm_dlkm.img` | 262,144 | `73f9609e4cebb0ff5dc01d542587604b186aba64c69ac75030b0b3799ee30359` |
| `system_dlkm.img` | 262,144 | `71374bcf827db52d16d9177f663ebee16870b42c5c6c2e18a27bc1c4c6da445e` |
| `cache.img` | 57,492 | `1e3c9632880cecc12b7e1ef1fc8eb473fc558d4ff38c4f53a7c1653870438085` |

The source revisions used by the successful build were:

| Project | Commit |
|---|---|
| `device/rockchip/rk3588` | `886d61f93f3876840890172a8c4bac6e4856caad` |
| `device/rockchip/common` | `7e6116f5fe4f29e97d242115f8fd1ddf4a3363da` |
| `kernel-6.1` | `d8544d7cb7ed2d2d6a0584dc9cb33fd29716cea8` |
| `packages/providers/MediaProvider` | `f0e2b49e94df52a3989644041196cbca5b9ec5ce` |
| `packages/services/Car` | `58083a560aa994a5feaa0f3559e3dcd13b47c3cc` |
| `vendor/rockchip/common` | `13bbb25125ce0aea9e988aaa2b31c3f8e159af30` |
| `vendor/rockchip/hardware` | `90dfdbc85a4a2e787f1541ce1f3fc1bbb8b6b49d` |
| `u-boot` | `fba0c8f28039e0f253ada4a71613ae1dd401c864` |

This validates the AOSP `m` target for the Phase 1 product. It does not yet
build/package the Rockchip bootloader chain and must not be interpreted as a
flash-ready distribution. No image has been written to the board.

## Temporary build swap and cleanup

Retry 2's Soong graph generator again approached the memory limit. With about
29 GiB RAM in use and the system 4 GiB swap full, a temporary 32 GiB swap file
was provisioned at:

```text
/data/agibot-android14-build/swapfile-32g
```

`android14/tools/ensure-build-swap.sh` records the reproducible provisioning and
cleanup procedure. The interactive sudo credential was not stored in Git, the
script, or this log.

The first interactive provisioning attempt was mangled by local PowerShell
expansion of a remote shell variable. It created and enabled a 32 GiB file at
the exact unintended path `/home/cennac/\`. The versioned script then enabled the
intended `/data` swap, switched off the unintended swap, and removed that exact
file. Verification reported `BAD_SWAP_FILE_REMOVED`; no other home-directory
entry was modified. Current swap is the original system `/swap.img` plus the
build-owned 32 GiB file under `/data`.
