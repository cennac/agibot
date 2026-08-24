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
