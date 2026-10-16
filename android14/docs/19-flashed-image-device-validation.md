# Flashed Android 14 device validation (2026-08-25)

## Test target

```text
Board: MB0002 V2 / RK3588
ADB serial: 154c3268c6cdee4e
Build: agibot_mb0002-userdebug Android 14
Kernel: 6.1.99 #5 Tue Aug 25 14:03:39 CST 2026
Image SHA-256: 5ba82d5da663ff55710f0999e8dc0916794ef5fa9a49305736666092a136311e
Locale: zh-CN
```

The checks below were run after the complete image was flashed by the user.
They describe the observed runtime state, not only the presence of build files.

## Result summary

| Area | Result | Evidence / limitation |
| --- | --- | --- |
| Boot and ADB | PASS | `sys.boot_completed=1`; root ADB available |
| HDMI display | PASS | Connected, 1920x1080 at 60 Hz, landscape, HWC display 0 |
| H.264 decode/display | PASS | RK MPP first frame and changing t=2/t=4 screenshots |
| 4K HEVC decode/display | PASS | 3840x2160 buffers, RK MPP first frame, non-black screenshot |
| H.264 encode | PASS | `screenrecord` used `c2.rk.avc.encoder`, output file valid |
| HDMI PCM playback | PASS at driver level | `tinyplay` completed 48 kHz stereo PCM write and drain; audible output needs a human check |
| Ethernet eth1 | PASS | 1 Gbit/s full duplex, DHCP address 192.168.88.237, gateway ping 0% loss |
| Ethernet eth0 | NOT TESTED | Driver interface exists but PHY has no carrier/cable |
| USB host/hubs | PASS | USB2/USB3 hubs, keyboard, and UVC camera enumerate |
| USB keyboard | PASS | Main, consumer-control, and system-control input devices registered |
| UVC Linux layer | PASS | `/dev/video0`, `/dev/video1`, `/dev/media0` present |
| Android Camera HAL | FAIL | CameraService reports zero camera devices |
| NPU inference | PASS | 100 ResNet18 iterations completed at about 159-240 FPS |
| GPU/media nodes | PASS (enumeration) | DRM render nodes, RGA and MPP service nodes present |
| Wi-Fi | FAIL / likely absent hardware | No `wlan0`; `bcmdhd` repeatedly fails to power up |
| Bluetooth | FAIL / likely absent hardware | OFF, null address, service not connected |
| RTC | FAIL | No `/dev/rtc*`; time service cannot open `/dev/rtc0` |
| Author identity | FAIL | all three `ro.build.author.*` properties are empty |
| SELinux | DEVELOPMENT ONLY | System is Permissive with multiple AVC denials |

## HDMI display and media

The HDMI connector reported `connected`. Android selected 1920x1080 at 60 Hz
with rotation 0. An apparent loss of HDMI output during testing was Android
entering `Dozing`: DisplayManager and HWC were both OFF. `KEYCODE_WAKEUP`
restored DisplayManager/HWC to ON. The test session then used a 30-minute screen
timeout and stay-awake-on-power to avoid contaminating media results.

H.264 hardware decode produced changing rendered frames at two and four seconds:

```text
tests/h264-t2.png
tests/h264-t4.png
HWMpiDecoder: mpp output first frame(pts: 0)
MediaSync V:00005007 ... E:00005010
```

The 4K HEVC sample also rendered a real frame. The allocator created 3840x2192
AFBC YUV buffers for a 3840x2160 source and MPP logged its first output frame:

```text
tests/hevc4k-t3.png
HWMpiDecoder: mpp output first frame(pts: 0)
```

The earlier black captures were caused by display sleep and test sequencing,
not a missing media-engine DT node. H.264 encode was separately confirmed with
`screenrecord`, which allocated `c2.rk.avc.encoder` and completed successfully.

## Audio

Only HDMI playback is exposed by ALSA:

```text
card 0: rockchip-hdmi0
PCM 00-00: playback 1
```

A generated five-second 1 kHz, 48 kHz, two-channel, signed-16-bit WAV was played
directly with `tinyplay -D 0 -d 0`. The PCM device opened, accepted 960000 bytes,
and drained without an error. This proves the kernel/ALSA playback path; confirm
that the television actually emitted the tone before calling the acoustic path
fully validated.

## NPU validation

The NPU server is running and DRM render nodes exist. Directly invoking the
vendor demo without a library search path crashes in `rknn_init()` because this
shell-launched vendor executable falls outside the normal Android linker
namespace. This is a test invocation error, not an RKNN ABI mismatch.

The correct invocation is:

```text
LD_LIBRARY_PATH=/system/lib64:/vendor/lib64 \
/vendor/bin/rknn_create_mem_demo \
  /data/local/tmp/resnet18.rknn \
  /data/local/tmp/dog_224x224.jpg 100
```

This completed all 100 iterations. Runtime 2.3.0 reported NPU driver 0.9.8;
measured throughput was approximately 159-240 FPS and Top-5 output remained
stable. The installed demo and both RKNN libraries also match the previously
validated `rknn-hwfix1` SHA-256 hashes.

## Confirmed defects to fix

1. Add Rockchip external-camera provider/HAL configuration so the working UVC
   V4L2 nodes are published to CameraService.
2. Rebuild `system`, `system_ext`, and `super.img` so the author properties and
   Settings author row from commits `ea485c7` and `c9c95055b0` reach the image.
3. Fix or remove the `up_eth0` init service. It cannot transition from init when
   executing `/system/bin/busybox`, even while SELinux is Permissive.
4. Confirm the board BOM. If Wi-Fi/Bluetooth hardware is absent, remove those
   product packages/services and the failing `bcmdhd` load instead of emitting
   continuous readiness errors. If fitted, correct power, bus and firmware data.
5. Add/enable the actual RTC device in DTS, or explicitly document network-only
   timekeeping if the board has no RTC hardware.
6. Resolve AVC denials and move the production build to SELinux Enforcing.

## Additional boot log issues

The following remain reproducible and should be triaged after the hardware
blockers above: stale cgroup task profiles referencing `/dev/stune`, missing
optional audio HAL service names, missing `update_verifier_nonencrypted`, and
Rockit access to the absent `/dev/video_state` performance-control interface.

## Preserved evidence

Local test artifacts are under:

```text
E:\AIPorject\101\android14-flash\validation\r2-media-author\tests
```

Important files include `hdmi-restored.png`, `h264-t2.png`, `h264-t4.png`,
`hevc4k-t3.png`, the two source videos, and `hdmi-1khz.wav`.
