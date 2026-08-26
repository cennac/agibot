# Android 14 complete Maskrom flash and recovery regression

## Scope

On 2026-08-25 the complete AGIBOT MB0002 V2 Android 14 image was deployed to
eMMC through Rockchip Maskrom mode. The image contains:

- the phase-2 AGIBOT boot chain;
- the hardware-fix-round-1 kernel DTS and product integration;
- working RKNN userspace and the RK3588 NNAPI HAL;
- Simplified Chinese as the product's factory-default locale.

The critical recovery requirement was also tested: after the first complete
flash, UART could still interrupt U-Boot, erase the IDB loader, and return the
board to Maskrom. The same complete image then restored the board successfully.

## Image provenance

Incremental build records:

```text
/data/agibot-android14-build/logs/2026-08-25-default-locale-systemimage.log
/data/agibot-android14-build/logs/2026-08-25-default-locale-superimage.log
/data/agibot-android14-build/logs/2026-08-25-default-locale-update-image.log
```

Build results:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `system.img` | 1,264,054,272 | `6c91df680b956fd4c9538e84822e6945db1c6c6135c81985ec1f2125d830c8c1` |
| `super.img` | 1,977,793,564 | `cb5d13050fa8b78bd86fc41aedf62ba6eb6775d690b380109d8d088eedfc9ee0` |
| complete `update.img` | 2,090,250,826 | `5bf4260e5fdef6d40d5675ce334398dc58acd1806a43889a7fdb695fe3cde1f4` |

The local preservation copy is:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-25-r1-zh-rknn-validated\agibot-mb0002-android14-r1-zh-rknn-validated-update.img
```

Its local SHA-256 matched the build host. The system `build.prop` reports:

```text
ro.product.locale=zh-CN
```

The remote device project remained at:

```text
device/rockchip/rk3588
agibot/android14-rkr6
a512f711f28f3b2c514527c9d26ac279cf7b432f
```

## Entering Maskrom

The validated board UART was `COM9` at 1,500,000 baud. The sequence was:

```text
python tools/_catch_uboot.py 60 COM9
python tools/_erase_to_maskrom.py COM9 10
```

The second script stopped autoboot and issued:

```text
mmc dev 0
mmc erase 0 0x8000
reset
```

`mmc erase 0 0x8000` erases 32,768 eMMC blocks, covering the first 16 MiB and
therefore the IDB loader. After reset, Windows enumerated:

```text
USB VID 2207, PID 350B, Rockusb Device
```

This operation is destructive. It must only be used when a known-good complete
image such as the SHA-256-pinned file above is available.

## First complete flash

RKDevTool v3.37 detected `MASKROM`. The complete image was selected on the
`升级固件` tab and written with the `升级` action. The local tool log is:

```text
E:\AIPorject\101\RKDevTool_v3.37_for_window\Log\Log2026-08-25.txt
```

The tool tested the chip and eMMC, rebuilt/downloaded a new IDB, and wrote:

```text
uboot, trust, misc, dtbo, vbmeta, boot, recovery, baseparameter, super
```

The update reported a total of 3,374,675,456 bytes. The sparse `super` payload
represented 3,263,168,512 logical bytes. The complete download completed
successfully in about 54 seconds:

```text
07:29:00 058  Start to download super
07:29:54 536  下载固件成功
```

RKDevTool printed one non-fatal `IsDharaImage` error while inspecting the
4,096-byte `vbmeta.img`; this check is unrelated to Android vbmeta handling and
did not stop either flash.

## Recovery regression

After the first complete flash, Android booted normally. The board was then
rebooted and `tools/_catch_uboot.py` again captured the AGIBOT U-Boot prompt on
`COM9`. U-Boot still accepted Ctrl+C interruption and exposed the same MMC
commands.

The same `mmc erase 0 0x8000` sequence successfully returned the newly flashed
board to Maskrom. RKDevTool again detected `MASKROM`, and the same complete
image was flashed a second time. The second pass also completed successfully in
about 54 seconds. This closes the recovery loop:

```text
complete flash
  -> normal Android boot
  -> UART interrupt U-Boot
  -> erase IDB loader
  -> Maskrom
  -> same complete image restored
```

Future bootloader or boot-partition changes must preserve this serial
interruption and `mmc erase` path before being considered releasable.

## Final validation

After the second restore:

```text
sys.boot_completed          = 1
ro.product.locale           = zh-CN
system_locales              = null
init.svc.vendor.rknn-1-0    = running
```

`system_locales=null` is significant: no user locale override was present, so
the displayed Chinese UI came from the product default rather than a persisted
manual preference.

The RKNN userspace remained operational:

```text
root    rknn_server
system  rockchip.hardware.neuralnetworks@1.0-service
```

A 100-iteration ResNet18 native inference completed with exit code 0. Its final
iterations took about 4.52-5.51 ms/frame, or 181-221 FPS, with the same stable
Top-5 classes as hardware-fix round 1.

Other final checks:

- Display 0 was ON at 1920x1080@60 with rotation 0.
- `eth1` obtained `192.168.88.196/24`; five gateway pings returned success.
- RKNPU driver v0.9.8 and `/dev/dri/renderD129` were present.
- `/dev/video0`, `/dev/video1`, and `/dev/media0` were present.
- Both `05e3:0620` USB3 hubs and both `05e3:0610` USB2 hubs enumerated.
- The `1bcf:0b09` camera and `1c4f:0002` keyboard remained present.

The existing follow-up work is unchanged: expose the external USB camera through
an Android camera HAL, stop the unsupported Wi-Fi/Bluetooth startup noise, test
the second physical Ethernet port, and complete sustained interactive 4K HEVC
playback.
