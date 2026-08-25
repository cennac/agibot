# Driver validation round 1

## Scope

This document records non-destructive runtime validation of the complete
Android 14 image after the successful Maskrom deployment. Tests were run on
2026-08-25 through ADB against serial `154c3268c6cdee4e`.

Tested build:

```text
product: agibot_mb0002
Android: 14 / API 34
kernel: 6.1.99
fingerprint: AGIBOT/agibot_mb0002/agibot_mb0002:14/UQ1A.240205.004.B1/eng.cennac.20260825.030102:userdebug/release-keys
locale: zh-CN
```

## Result summary

| Area | Result | Runtime evidence |
| --- | --- | --- |
| CPU and DVFS | PASS | Eight cores present; `schedutil`; all cores reached their configured top frequencies under load |
| Memory | PASS | 16,327,872 kB reported |
| HDMI display | PASS | 1920x1080 at 60 Hz, rotation 0, landscape |
| Mali GPU | PASS | Mali probe, DRM render nodes, Vulkan device creation and active GPU accounting |
| RKNPU / RKNN | PASS | Driver 0.9.8, services running, ResNet18 100-iteration inference completed |
| Ethernet eth1 | PASS | 1 Gbps full duplex; bidirectional TCP about 112 MB/s; LAN, DNS and Internet reachable |
| Ethernet eth0 | PARTIAL | GMAC probes, but there is no carrier on the currently unconnected port |
| eMMC / F2FS | PASS | 512 MiB write 252 MB/s, cold read 164 MB/s, F2FS healthy |
| USB host | PASS | USB 3 and USB 2 hubs, UVC camera and keyboard enumerated |
| UVC V4L2 | PASS | 1280x720 MJPEG capture, 60 frames, no V4L2 error |
| Android Camera API | FAIL | CameraService reports zero devices; no CameraProvider HAL is installed |
| HDMI audio | PASS | 48 kHz, stereo, 16-bit WAV completed through `tinyplay` |
| Video codec enumeration | PASS | Rockchip AVC/HEVC codecs advertise hardware acceleration and 8K limits |
| Hardware video decode | FAIL | Both H.264 1080p and HEVC 4K select MPP but cannot initialize a decoder device |
| Screen recording | FAIL | Hardware AVC encoder opens, then SurfaceFlinger rejects layer stack `-1` |
| Thermal | PASS | Thermal HAL ready; idle about 30-32 C, CPU load peak about 40 C |
| Wi-Fi | FAIL / unused | DHD cannot power the generic adapter; no usable WLAN interface |
| Bluetooth | FAIL / unused | Framework starts without a Bluetooth HCI HAL and aborts after timeout |
| Sensors | NOT PRESENT | SensorService intentionally reports no sensors in Phase 1 |
| Battery | NOT PRESENT | Board reports no battery or charger source |

## Passed runtime tests

### CPU, memory, GPU and thermal

The RK3588 topology contains four Cortex-A55 and four Cortex-A76 CPUs. Every
CPU uses `schedutil`. During an eight-process SHA-256 load, CPU0-3 reached
1.8 GHz and CPU4-7 reached 2.256 GHz. The hottest thermal zones rose from
about 30 C to about 40 C without throttling or errors.

Devfreq was present for all important accelerators:

```text
dmc                 528000000 Hz
fb000000.gpu        300000000 Hz (idle sample)
fdab0000.npu       1000000000 Hz
fdd90000.vop        500000000 Hz
```

The Mali GPU owns DRM render nodes and Android GPU accounting reports active
work, 135,000,064 bytes of global GPU memory and successful Vulkan device
creation. This validates the graphics driver and userspace stack, but is not a
long-duration 3D stability test.

RKNPU is stronger than an enumeration-only result: the v0.9.8 driver and RKNN
services ran 100 ResNet18 inferences successfully. The final samples were
approximately 4.52-5.51 ms per frame (181-221 FPS) with stable Top-5 output.

### Ethernet

`eth1` negotiated 1000 Mbps full duplex with carrier. A 1 GiB TCP stream was
sent in each direction between the board and `192.168.88.66`:

```text
board -> host: 112.22 MB/s
host -> board: 112.48 MB/s
gateway ping: 0% loss, 1.124 ms average
Internet IP: 0% loss
DNS hostname: resolved and reachable
```

This is effectively line-rate gigabit performance. `eth0` is enabled and its
GMAC probes, but remains `NO-CARRIER`; move the cable to the second RJ45 port
before judging its PHY and board routing.

### eMMC storage

The 256 GB-class eMMC identifies as `A3A564`, manufacturer `0x0000d6`, dated
12/2023. Its lifetime and pre-EOL values are both in the normal first stage.
`/data` is F2FS and has about 227 GiB free.

A 512 MiB direct functional test with an explicit sync measured:

```text
write: 252 MB/s
read after page-cache drop: 164 MB/s
```

The scheduler is `mq-deadline`. The temporary test file was removed after the
test.

### USB and UVC camera

Both Genesys Logic USB 3 hubs run at 5 Gbps and both USB 2 companion hubs run
at 480 Mbps. The camera (`1bcf:0b09`) is on the USB 2 path at 480 Mbps. The
keyboard (`1c4f:0002`) is also functional and produces Android input nodes.

The UVC kernel path exposes `/dev/video0`, `/dev/video1` and `/dev/media0`.
`/dev/video0` supports MJPEG up to 1920x1080 at 30 FPS and YUYV up to
1920x1080 at 5 FPS. A 1280x720 MJPEG mmap capture completed 60 frames and
wrote 3,662,525 bytes. The observed 19-22 FPS is below the descriptor's 30 FPS
and should be investigated separately; the USB 2 attachment is confirmed.

### HDMI audio

The `rockchip-hdmi0` ALSA card accepts stereo 32-48 kHz playback. A generated
48 kHz, two-channel, 16-bit, three-second WAV completed through `tinyplay` with
return code zero and a clean drain. This validates the kernel and HAL playback
path; audible confirmation at the connected display remains a physical check.

## Failed or incomplete paths

### Video Processing Unit

Codec discovery alone was misleading. Rockchip Codec2 entries advertise
hardware AVC/HEVC decode and encode, including 7680x4320. Real playback was
therefore tested with:

```text
H.264: 1920x1080, 30 FPS, 6 seconds
HEVC: 3840x2160, 30 FPS, 10 seconds, yuv420p
```

RockVideoPlayer recognized each stream and selected `rk_mpp`, but both failed:

```text
open vcodec_service failed
mpp_dev_init failed ret: -1
mpp_hal_init hal h264d_rkdec / h265d_rkdec init failed
MediaPlayer error (100, 0)
```

The cause is in the deployed device tree. Although the kernel has
`CONFIG_ROCKCHIP_MPP_RKVDEC`, `RKVDEC2`, `VDPU1`, `VDPU2` and `IEP2`, the
following live-DT nodes are disabled and no `/dev/vcodec_service` exists:

```text
rkvdec-ccu@fdc30000
rkvdec-core@fdc38000
rkvdec-core@fdc48000
vdpu@fdb50400
vepu@fdb50000
rga@fdb60000
rga@fdb70000
rga@fdb80000
```

The AGIBOT DTS does not enable the media blocks that reference RK3588 EVB/PC
trees enable. The next kernel fix must enable the required MPP server, decoder,
encoder, MMU and RGA nodes as a consistent set, then retest real H.264/HEVC
decode and hardware encode.

### Android Camera HAL

The UVC kernel capture path is good, but Android reports:

```text
Number of camera devices: 0
```

There is no CameraProvider process, VINTF camera declaration or camera HAL
binary in the deployed vendor image. Only `/vendor/etc/uvc_enc_cfg.conf` is
present. Add an external-camera provider product package, its VINTF fragment,
init service, permissions and external camera configuration. This is a vendor
product integration issue, not a UVC kernel failure.

### Screen recording

`screenrecord` opens `c2.rk.avc.encoder`, but SurfaceFlinger immediately logs:

```text
Invalid layer stack -1
ERROR: INVALID_LAYER_STACK
```

Explicit display ID 0, wake-up, 1920x1080 and 1280x720 all fail with zero-byte
output. DisplayManager reports display ID and layer stack 0, so the failure is
in the physical-display-to-virtual-display handoff, not codec enumeration.
Retest after the media/RGA DTS repair, then inspect the Rockchip
SurfaceFlinger screenrecord integration if it remains.

### Wi-Fi and Bluetooth

Wi-Fi is not required for the current Ethernet-first product, but the image
still starts an incompatible connectivity stack. DHD repeatedly reports:

```text
rfkill-wlan driver has not Successful initialized
failed to power up DHD generic adapter
Failed to load driver max retry reached
```

Bluetooth is declared in `/vendor/etc/vintf/manifest.xml`, but no matching HCI
HAL is installed. Enabling Bluetooth starts `com.android.bluetooth`, which
aborts after waiting for the HAL:

```text
No supported HAL version
Unable to get a Bluetooth service after 500ms
```

For this board revision, either integrate the actual Wi-Fi/BT module, power,
firmware and HAL, or remove both features and their manifests/packages so the
system does not advertise hardware it cannot provide.

## Follow-up order

1. Enable the complete RK3588 MPP/RKVDEC/VDPU/RGA node set in the AGIBOT DTS.
2. Build and deploy the kernel/resource change, then repeat real H.264, HEVC,
   encoder and screenrecord tests.
3. Integrate Android's external UVC CameraProvider and verify Camera2 API
   enumeration plus preview/capture.
4. Disable unused Wi-Fi/Bluetooth framework features or integrate the actual
   module and HAL.
5. Move the Ethernet cable to the other RJ45 connector and validate `eth0`.
6. Run a longer GPU/Vulkan stress workload and investigate UVC frame rate.

## Cleanup

Large storage and failed screenrecord files were removed. Bluetooth was
returned to the disabled state. Small media samples were retained on the host
under `E:\AIPorject\101\driver-tests` for repeatable codec testing and are not
tracked by Git.
