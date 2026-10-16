# Hardware fix round 1

## Scope

This round addresses the three kernel-level failures found during the first
Android 14 hardware validation:

- dual GMAC DMA reset timeout;
- missing RKNPU platform device;
- onboard USB hubs held in reset and missing their PCA9555 power enables.

The running board was used only for reversible diagnostics. Source changes
were built on `cennac@192.168.88.66`; no image from this round has been flashed
yet.

## Root causes and fixes

### Dual GMAC

The decompiled Android DTB had five pinctrl entries on each GMAC. The working
vendor and Armbian DTB has six. Android omitted `gmac0_clkinout` and
`gmac1_clkinout`, even though both controllers use an external RGMII clock from
their PHY. Both clock input groups are now present.

This directly addresses the observed `Failed to reset the dma` error. Link and
traffic still require a flash-time hardware regression.

### RKNPU

The NPU regulator was present, but the final Android DTB retained
`npu@fdab0000 { status = "disabled"; }`. The board DTS now enables `rknpu` and
`rknpu_mmu` and connects both NPU supply properties to `vdd_npu_s0`.

### USB hubs

Two independent defects were confirmed:

1. PCA9555 `3-0020` offsets 0 through 11, the vendor-verified HUB/USB enables,
   were never driven high.
2. Reset GPIOs are active-low, but the custom driver used logical low then
   logical high. It physically drove high then low and left both hubs asserted
   in reset while logging that they had been released.

A reversible live test drove the 12 verified PCA9555 outputs high, asserted
GPIO4_D2/D3 physically low, and released them physically high. Four Genesys
hubs immediately enumerated:

```text
05e3:0620 (two USB 3 hubs)
05e3:0610 (two USB 2 hubs)
```

The keyboard `1c4f:0002` and camera `1bcf:0b09` behind the hubs also appeared.
The driver now owns the 12 enable GPIOs, which makes probe defer until PCA9555
is ready, then performs power enable, delay, reset release, and settle delay in
that order.

## Version control

Remote kernel branch and commit:

```text
project: kernel-6.1
branch:  agibot/android14-rkr6
commit:  240668f1c05dabe717a40573aba2a7b2b1bd57d1
subject: arm64: dts: fix AGIBOT hardware bring-up
```

Local replay patch:

```text
android14/patches/0004-kernel-agibot-hardware-bringup-fixes.patch
```

## Build record

The first invocation incorrectly replaced the remote PATH and failed before
kernel compilation. It is retained at:

```text
/data/agibot-android14-build/logs/2026-08-24-hwfix1-kernel.log
```

The corrected build used an explicit product lunch and full host PATH. Kernel,
external modules, resource packaging, and Android bootimage all completed:

```text
/data/agibot-android14-build/logs/2026-08-24-hwfix1-kernel-retry1.log
```

Artifact hashes:

| Artifact | SHA-256 |
|---|---|
| board DTB | `d307bb245ab45eb5ad8c32dce499039952217c0a6dbd50f22d9a7cc32912fe5b` |
| `kernel-6.1/boot.img` | `ed507896a54e07f8713dfefe4819a389a4ba9ac89edaa761e8190823da35ca2d` |
| `kernel-6.1/resource.img` | `fd91318b1c4e6765dd46dbe7847dca117033931b5e40084a83edb2e12a83a747` |
| rockdev `boot.img` | `03ced3781e65c917b92238831263f7617ab6f58b7774f2b36b0fe58bb89afd32` |
| rockdev `resource.img` | `fd91318b1c4e6765dd46dbe7847dca117033931b5e40084a83edb2e12a83a747` |

The compiled DTB was decompiled and checked. Both GMAC nodes have six pinctrl
phandles, RKNPU is `okay`, and the USB reset node contains all 12 enable GPIOs.

## Required flash regression

After packaging and flashing the next image:

1. Confirm both GMACs open without DMA reset errors, obtain link, and pass
   traffic independently.
2. Confirm `/dev/dri/renderD129` or the BSP-equivalent RKNPU node, driver bind,
   and a real RKNN inference.
3. Confirm four `05e3` hubs and their downstream devices enumerate on every
   cold boot and normal reboot.
4. Reconfirm HDMI, GPU, eMMC, Codec2, normal reboot, UART U-Boot interruption,
   and Maskrom recovery behavior.

## Post-flash follow-up: RKNN userspace

The kernel RKNPU probe is now healthy, but the flashed Android filesystem has
no NNAPI/RKNN userspace.  `dumpsys neuralnetworks` reports that the service is
missing and a board-side RKNN demo cannot run yet.

Root cause:

```text
device/rockchip/rk3588/BoardConfig.mk sets BOARD_RKNN_SUPPORT := false
```

The AGIBOT board config included that file and did not restore the setting.  It
now sets `BOARD_RKNN_SUPPORT := true` after the include, enabling the Rockchip
packages declared by `device/rockchip/common/modules/rknn.mk`, including the
NNAPI HAL/service, `rknn_server`, public RKNN libraries, and demos.

Build record:

```text
2026-08-24-hwfix1-rknn-userspace.log
targets: rockchip.hardware.neuralnetworks@1.0-service
         librknn_api_android
         rknn_create_mem_demo
```

The first graph regeneration after changing board configuration entered Soong
Bazel mixed-build mode.  It spent more than two hours creating the Bazel symlink
forest and writing a very large `out/soong/build.ninja`.  The process continued
to consume CPU, change RSS, and append to the Ninja file, so it was not treated
as hung.  `BUILD_BROKEN_DISABLE_BAZEL=true` was identified as the supported
fallback if a later graph regeneration needs to bypass this expensive path.

### Completion and validation

The first target build completed successfully in 2:59:37.  Soong generated a
2,975,560,006-byte Ninja graph, then Kati and the targeted compile completed.
Two follow-up targets were also built incrementally:

```text
rockchip.hardware.neuralnetworks@1.0-impl  38 seconds
librknnhal_bridge.rockchip                 1 minute 19 seconds
```

Important outputs:

| Output | SHA-256 |
|---|---|
| `vendor/bin/rknn_create_mem_demo` | `a2829dec06bc32dc6ad77fa8b6b0dadee67908576fb50338e57d6a1428e7d5fd` |
| `vendor/bin/hw/rockchip.hardware.neuralnetworks@1.0-service` | `721c4b6d618b8362cc481206446f0d05382af219a5769049b23896a9460f2d77` |
| `vendor/lib64/librknn_api_android.so` | `b13232a4134fdf4e5e853341c168b0c17d50f2596d47f887ed353397cec10a91` |
| `vendor/lib64/librknnrt.so` | `10cc1c06910e0dfc252724e7ae4fe8aaad60bd7d288f6375143fc2f600506734` |
| `vendor/lib64/rockchip.hardware.neuralnetworks@1.0.so` | `2bd94a7e0819ea2c737f19e827a49ffcd530c94dbf77e7aafabc43fbe7cd2df8` |
| `vendor/lib64/hw/rockchip.hardware.neuralnetworks@1.0-impl.so` | `e39db662ecdb15d8632c9c8f3215ab7931240338dc40ed0f960df04114612fe5` |
| `system/lib64/librknnhal_bridge.rockchip.so` | `1a8c465af4f0bc45954ce30c125a894278d3250541e0240f8bcc8468ec4d8095` |

The minimal live deployment used `adb remount`/overlayfs and survived a reboot.
The current boot policy does not yet contain the RKNN service domain, so init
parsed the new RC but refused its domain transition.  Starting the standard
service manually from a root shell succeeded and registered:

```text
rockchip.hardware.neuralnetworks@1.0::IRKNeuralnetworks/default
```

The complete client/HIDL/passthrough/runtime/NPU path then passed with the local
RK3588 ResNet18 model.  Reported versions:

```text
RKNN runtime: 2.3.0 (c949ad889d, 2024-11-07)
NPU driver:   0.9.8
```

Two runs were recorded.  A 20-iteration smoke test returned 0 and measured about
161-200 FPS.  A 500-iteration run also returned 0; its final ten iterations took
4.36-4.57 ms/frame (about 219-229 FPS).  Concurrent debugfs sampling observed
Core0 load rising from 45% to 87%, confirming execution on the NPU.  The Top-5
result was stable across both runs.

Remote device project version:

```text
project: device/rockchip/rk3588
branch:  agibot/android14-rkr6
commit:  4c1b31c4ede938aaf6ffb377d90ce5c18cf39e4e
subject: agibot: enable RKNN userspace support
```

Replay patch:

```text
android14/patches/0005-device-agibot-enable-rknn-userspace.patch
```

### Final image integration

The regenerated filesystem images were packaged on 2026-08-25:

| Image | Size | SHA-256 |
|---|---:|---|
| `system.img` | 1,264,025,600 | `cb0c4630ede89844acc4115aee873a0be38d4a2ee6e1e3d8fd71395f7a7d30c8` |
| `vendor.img` | 231,231,488 | `68f9dec1388c2ed13e393225a4f88c18f906bf6d307f6ab3aebb0cb93069f1d4` |
| `odm.img` | 819,200 | `f103d9ab498e52ed31d7dda67a6fb7a2ca1900d23a69ae92b70e5a068afca337` |

Build records:

```text
2026-08-25-hwfix1-rknn-images.log
2026-08-25-hwfix1-rknn-odmimage.log
```

The first fastbootd pass flashed only `system` and `vendor`.  The RKNN files and
file contexts were present, but init still rejected the new domains because this
Rockchip configuration stores the actually loaded precompiled policy in:

```text
/odm/etc/selinux/precompiled_sepolicy
```

The old ODM policy did not know `rknn_server` or `vendor-rknn-hal`.  Rebuilding
and flashing `odm.img` fixed the policy mapping.  A forced boot-image rebuild
produced byte-for-byte the existing boot image, confirming that boot was not the
policy carrier and was not changed in this step.

Final fastbootd writes:

```text
system: 5 sparse chunks, 43.475 s, OKAY
vendor: 225812 KB, 7.806 s, OKAY
odm:    800 KB, 0.125 s, OKAY
```

After the final normal reboot:

```text
init.svc.vendor.rknn-1-0 = running
u:r:rknn_server:s0           rknn_server
u:r:vendor-rknn-hal:s0       rockchip.hardware.neuralnetworks@1.0-service
```

`lshal` again reports the binderized
`rockchip.hardware.neuralnetworks@1.0::IRKNeuralnetworks/default` interface.

The shell-invoked native demo needs an explicit search path because it uses a
vendor executable outside an Android app linker namespace:

```text
LD_LIBRARY_PATH=/system/lib64:/vendor/lib64
/vendor/bin/rknn_create_mem_demo <model.rknn> <input.jpg> 20
```

The post-reboot image test returned 0.  A 500-iteration run measured 4.36-5.07
ms/frame for its final iterations and debugfs sampled Core0 at 86-87%.  A second
20-iteration post-reboot smoke test also returned 0 at about 161-191 FPS with
the same stable Top-5 output.

Other repaired subsystems remained healthy after the final reboot:

- `eth1` negotiated 1000 Mb/s and obtained `192.168.88.181/24`; five gateway
  pings passed with 0% loss and 0.756-0.980 ms RTT.
- Both `05e3:0620` USB3 hubs and both `05e3:0610` USB2 hubs enumerated.
- The `1bcf:0b09` camera and `1c4f:0002` keyboard remained present.
- `/dev/video0`, `/dev/video1`, and `/dev/media0` remained present.
- RKNPU driver v0.9.8 and `/dev/dri/renderD129` remained present.

The remaining unrelated work is external USB camera HAL exposure, disabling the
unsupported Wi-Fi/Bluetooth startup, testing `eth0` with the cable moved to that
physical port, and completing an interactive sustained 4K HEVC playback test.
