# Android 14 hardware validation

## Test scope

This record covers the first hardware validation after flashing the AGIBOT
MB0002 V2 Android 14 image. Tests were run on 2026-08-24 through root ADB. No
partitions were written during validation. One 4K HEVC sample was copied to
`/data/local/tmp/stress-hevc-4k.mp4`.

Device identity:

```text
ADB serial:          154c3268c6cdee4e
Product:             agibot_mb0002
Model:               MB0002 V2
Android:             14 / API 34
Kernel:              Linux 6.1.99
Build fingerprint:   AGIBOT/agibot_mb0002/agibot_mb0002:14/UQ1A.240205.004.B1/eng.cennac.20260824.095903:userdebug/release-keys
```

## Result summary

| Subsystem | Result | Evidence |
|---|---|---|
| Boot and ADB | PASS | `sys.boot_completed=1`; root ADB works |
| Normal reboot | PASS | Returned to a complete Android boot and root ADB in about 24 seconds |
| eMMC and `/data` | PASS | 233 GiB eMMC; about 227 GiB available on `/data` |
| HDMI display | PASS | Connected, 1920x1080 at 60 Hz, rotation 0, density 240, state ON |
| HDMI audio | PASS | `rockchip-hdmi0` and Android HDMI output are present |
| GPU | PASS | `/dev/mali0`, DRM render node, Mali CSF firmware and Vulkan device are present |
| CPU DVFS and thermal | PASS | Three cpufreq policies and seven thermal zones are present |
| Hardware Codec2 | PARTIAL PASS | Rockchip Codec2 HAL runs and `c2.rk.hevc.decoder` was instantiated; unattended 4K playback was blocked by the player's first-run permission UI |
| NPU | FAIL | `rknpu` module and driver exist, but no platform device is bound and no `/dev/rknpu*` node exists |
| Ethernet | FAIL | Both GMACs find their PHY, then fail DMA reset and remain DOWN |
| Board USB hub | FAIL | Reset driver probes, but no Genesys `05e3:*` hub enumerates; only SoC root hubs are visible |
| Camera | NOT PRESENT | Camera service reports zero devices; no `/dev/video*` or `/dev/media*` nodes |
| Wi-Fi/Bluetooth | FAIL / unwanted | Wi-Fi HAL remains running without a usable adapter; Bluetooth native service crashes repeatedly |

## Boot, display, storage, GPU, and thermal

Android boots from eMMC and reports the correct board DT model:

```text
AGIBOT MB0002 V2
```

The 256 GB nominal eMMC exposes about 233 GiB. `/data` has about 227 GiB free
on a fresh system. The display returns after a normal reboot as 1920x1080 at
60 Hz in landscape orientation. GPU character and render nodes are stable
across reboot:

```text
/dev/mali0
/dev/dri/card0
/dev/dri/renderD128
```

No boot-critical failure was observed in storage, display, GPU, cpufreq, or
thermal-zone initialization.

## Video codec

Android 14 uses the Codec2 HAL on this build. The absence of a legacy
`media.codec` Binder service is not itself a defect. The following services
are running:

```text
android.hardware.media.c2@1.1-service
media.swcodec
```

System media processing instantiated `c2.rk.hevc.decoder` and logged the
Rockchip hardware Codec2 memory summary. This proves component discovery and
allocation, but not a complete sustained 4K decode test. Launching Rockchip
Video Player over ADB stopped at its Android 14 first-run storage permission
screen. A later interactive regression must grant the permission and verify
picture, audio, dropped frames, temperature, and decoder errors for the full
sample.

## NPU failure

The kernel contains the `rknpu` module and registers a platform driver:

```text
/sys/module/rknpu
/sys/bus/platform/drivers/RKNPU
```

There is no bound device under the driver, no live NPU node in the flattened
device tree, and no `/dev/rknpu*`. The NPU is therefore unavailable. The next
kernel DTS revision must enable the RK3588 NPU node, its IOMMU, power domain,
clocks, resets, and operating points, then verify creation of `/dev/rknpu` and
run an RKNN model rather than stopping at node detection.

## Ethernet failure

Both controllers probe and both RTL8211 PHY paths respond. Opening either
interface fails after one second:

```text
rk_gmac-dwmac fe1b0000.ethernet: Failed to reset the dma
rk_gmac-dwmac fe1b0000.ethernet eth1: DMA engine initialization failed
rk_gmac-dwmac fe1c0000.ethernet: Failed to reset the dma
rk_gmac-dwmac fe1c0000.ethernet eth0: DMA engine initialization failed
```

The failure is reproducible after a cold Android boot and after `adb reboot`.
It is below Android network configuration and must be fixed in the kernel DT,
clock/reset/GRF setup, or GMAC driver integration. The current random MAC
addresses also change after reboot because vendor MAC storage reads fail.

The product init service `up_eth0` is independently invalid because it tries
to start `/system/bin/busybox` without a valid SELinux domain transition. Fix
or remove that service after the kernel-level DMA failure is resolved.

## USB hub failure

All enabled SoC USB host controllers register root hubs. The AGIBOT-specific
reset helper also runs:

```text
agibot-hub-reset usb-hub-reset: released 2 USB hub reset GPIOs after 20000 us
```

No downstream Genesys hub (`05e3:*`) appears in `lsusb`. Reset alone is not
sufficient. Before changing GPIO values, correlate the vendor Armbian DTS and
board schematic with the PCA9555 outputs to identify the exact hub power,
VBUS, and enable bits. Do not drive all expander outputs high.

## Wireless and Bluetooth cleanup

The intended product configuration did not fully disable wireless. Both
`vendor.wifi_hal_legacy` and `wificond` run while the DHD adapter cannot power
up. The Bluetooth process aborts in `bt_stack_manage` and is restarted before
crashing again. Unless the installed wireless module is identified and
supported, remove Wi-Fi and Bluetooth HAL packages, init services, feature
declarations, and kernel auto-start from the product.

## Other observations

- SELinux is permissive and produces many AVC records; enforcing mode is not
  ready.
- AVB remains disabled.
- Legacy `/dev/stune/*` task-profile paths are absent and generate warnings.
- Camera service is healthy but reports zero attached cameras.
- The system generates random Ethernet MAC addresses on every boot.

## Fix order and regression gates

1. Repair both GMAC clock/reset/GRF definitions and prove link plus traffic on
   each physical port.
2. Enable and bind the NPU, then run a real RKNN inference test.
3. Identify the PCA9555 USB power controls and make the onboard hub enumerate.
4. Remove unsupported Wi-Fi/Bluetooth startup or add the correct module
   integration.
5. Complete sustained H.264 and HEVC decode/encode testing after granting the
   player permission.
6. Clean init, cgroup, and SELinux policy before considering a production
   build.

Every repaired image must repeat the normal reboot test and confirm that the
UART U-Boot interruption and Maskrom recovery paths remain available.
