# r1 post-recovery driver validation

Date: 2026-08-26

## Scope

This is the driver regression check after recovering the board with SW9200
LOADER mode and writing the known-good r1 complete image. The board was tested
through the COM9 console at 1,500,000 baud. No image was changed during this
validation.

## Test target

```text
Board: AGIBOT MB0002 V2 / RK3588
Android: 14, userdebug
Kernel: 6.1.99 #2, Mon Aug 24 21:56:28 CST 2026
Fingerprint: AGIBOT/agibot_mb0002/agibot_mb0002:14/UQ1A.240205.004.B1/eng.cennac.20260825.030102:userdebug/release-keys
Boot: sys.boot_completed=1
Locale: zh-CN
Image: agibot-mb0002-android14-r1-zh-rknn-validated-update.img
Image SHA-256: 5BF4260E5FDEF6D40D5675CE334398DC58ACD1806A43889A7FDB695FE3CDE1F4
```

## Result summary

| Area | Result | Evidence / limitation |
| --- | --- | --- |
| Boot and locale | PASS | Android userspace reached, `sys.boot_completed=1`, `ro.product.locale=zh-CN`. |
| CPU/thermal | PASS | 8 CPUs online; CPU/GPU/SOC temperatures were about 29-31 C with thermal status 0. |
| Memory | PARTIAL | Kernel exposed 16,327,872 KiB RAM, not the intended larger mapping. ZRAM was 8 GiB with minimal use. |
| eMMC and /data | PASS | `mmcblk0` partitions complete, health `0x01 0x00`; F2FS `/data` mounted rw with 228 G total. 32 MiB write: 203 MiB/s; cached read: 2.8 GiB/s. |
| Ethernet | PASS | eth1 UP at 192.168.88.186/24, zero RX/TX errors, gateway 5/5 replies, 223.5.5.5 3/3 replies. ConnectivityService marked the network VALIDATED. |
| DNS shell test | OBSERVATION | Android had gateway DNS and VALIDATED state, but toybox `ping www.baidu.com` failed hostname lookup. IP connectivity itself worked. |
| HDMI display | PASS | Connector connected; wakeup restored 1920x1080@60, VOP enabled, HDMI TMDS 148.5 MHz, and HDMI PHY locked. |
| GPU/HWC | PASS | SurfaceFlinger reported Mali-G610 OpenGL ES 3.2 and an active 60 Hz DRM/HWC display. |
| HDMI audio | PASS | Playing the bundled OGG opened PCM0 as 48 kHz stereo S16 LE, generated a started MediaPlayer event, and routed to HDMI. |
| USB host | PASS | USB2/USB3 hubs, UVC camera, and USB keyboard enumerated. |
| USB keyboard | PASS | Main, consumer-control, and system-control keyboard input nodes registered. |
| UVC camera Linux layer | PASS | `/dev/video0` and `/dev/video1`; root `v4l2-ctl` listed MJPG/YUYV modes. Three 1280x720 MJPG frames were captured successfully (171 KiB total). |
| Android CameraService | FAIL | CameraService reports `Number of camera devices: 0`; the r1 image predates the external-camera provider integration. |
| NPU/RKNN | PASS | `rknn_server` and Rockchip NNAPI HAL were running. The prior r1 on-device ResNet18 test completed 20/20 loops. |
| Hardware media nodes | FAIL | `/dev/vcodec_service`, `/dev/rga`, and `/dev/mpp_service` are absent in this r1 kernel. |
| H.264 encode test | FAIL | `screenrecord` selected `c2.rk.avc.encoder`, but MPP could not open `vcodec_service`; `mpp_init` failed and ScreenRecord returned 235 with a zero-byte file. |
| Wi-Fi | FAIL | No `wlan0`; bcmdhd repeatedly powered the bus up/down without a device and the IWifi HAL did not register. |
| Bluetooth | FAIL | No Bluetooth kernel class/device or usable adapter was exposed. |
| RTC | FAIL | No `/dev/rtc*`; `hwclock` cannot open `/dev/rtc0`. |
| Network ADB | NOT AVAILABLE | `adbd` runs, but neither `service.adb.tcp.port` nor TCP 5555 is enabled. |
| Author metadata | NOT IN r1 | The three `ro.build.author.*` properties are empty. |
| SELinux | DEVELOPMENT ONLY | Boot is permissive and generated shell/app AVC denials during reads. |

## Display and audio evidence

The first display query happened while Android had dozed:
DisplayManager/HWC were OFF and DRM Video Port 0 was disabled. Sending
`KEYCODE_WAKEUP` restored the display and produced:

```text
rockchip-vop2: Update mode to 1920x1080p60 ... if:HDMI0
rockchip-hdptx-phy-hdmi: hdptx phy pll locked!
dwhdmi-rockchip: final tmdsclk = 148500000
DisplayDeviceInfo ... state ON, committedState ON
```

The HDMI connector also advertised 3840x2160 and 4096x2160 modes in addition to
the active 1080p60 mode.

For audio, Android Music played
`/product/media/audio/notifications/Tinkerbell.ogg`. The ALSA playback stream
was active with:

```text
access: RW_INTERLEAVED
format: S16_LE
channels: 2
rate: 48000
```

`dumpsys audio` logged `player piid ... event:started`, a 48 kHz format update,
and an HDMI device update.

## UVC camera evidence

Root access was needed because the console shell lacks camera-device access.
The camera exposed MJPG and YUYV at 640x480, 1280x720, and 1920x1080. The
actual stream command was:

```text
su 0 v4l2-ctl -d /dev/video0 \
  --set-fmt-video=width=1280,height=720,pixelformat=MJPG \
  --stream-mmap --stream-count=3 \
  --stream-to=/data/local/tmp/camera-test.mjpg
```

It produced a non-zero file and normal exposure/white-balance controls. The
temporary file was removed. Therefore the camera hardware and UVC kernel path
work; only publication to Android CameraService is missing.

## Media failure evidence

Although Codec2 lists Rockchip H.264/HEVC components, every hardware encoder
attempt fails before it can access the missing kernel service:

```text
vcodec_service: open vcodec_service (null) failed
hal_h264e_vepu541_init mpp_dev_init failed. ret: -1
mpp_enc_hal_init could not found coding type 7
C2RKMpiEnc: failed to mpp_init, err -1
ScreenRecord: failed
```

This is consistent with r1 predating the media-engine device-tree enablement
round. It is not evidence that the RK3588 VPU hardware itself is defective.

## Temporary test changes

Only transient files under `/data/local/tmp` were created and then removed:

```text
.driver-test
driver-test.mp4
camera-test.mjpg
```

No partition, image, or persistent Android setting was changed by this test.

## Conclusion

The r1 recovery boot, board essentials, display, audio, storage, wired network,
GPU, USB, UVC Linux capture path, and RKNN service are healthy. The board is
not yet fully driver-complete for daily Android use because Android camera
publication, media-engine nodes, Wi-Fi/BT, RTC, the larger memory mapping, and
author metadata remain unresolved in this image.

The unverified r4 package is the next intended comparison build. It should be
flashed only after explicit confirmation, using SW9200 LOADER mode rather than
erasing IDB to Maskrom.
