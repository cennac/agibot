# r22 release candidate after board repair

Date: 2026-08-27

## Decision

The user reported that the board-side wireless problem was repaired. Inspection
of the remote build tree found no later source change: the relevant projects are
clean and remain on the validated r22 baseline.

Therefore no r23 source revision or rebuild is warranted. The already-built,
officially packaged r22 artifact is the correct release candidate for validating
the repaired board.

## Remote source state

```text
kernel-6.1
0592db10e0b9 rfkill: safely handle Bluetooth proc reads

device/rockchip/rk3588
bb29246 agibot: restore r16 Classic scan defaults

vendor/rockchip/common
30c0c09 bluetooth: restore r16 AP6275P firmware baseline

hardware/broadcom/libbt
3dae309 broadcom: restore AP6275P BT_WAKE deassert
```

The project worktrees reported no uncommitted changes.

## Artifact

```text
Remote:
/data/agibot-android14-build/aosp/rockdev/Image-agibot_mb0002/update.img

Local:
E:\AIPorject\101\android14-flash\releases\2026-08-27-r22-bluetooth-proc-read-safety-official\
agibot-mb0002-android14-r22-bluetooth-proc-read-safety-official-update.img

size:    2,157,001,290 bytes
SHA-256: 137a8e08e5c64397aa0598389f319c818b97bc39662ae6b3d2beb5192adb55c1
```

The remote and local SHA-256 values matched. The retained official build log
contains:

```text
Making update.img  OK.
Make update image ok!
Make gpt image ok!
```

The package uses the official Rockchip `build.sh -u -J8` flow. No custom
repacker was used.

## Post-repair validation required before release

Flash r22, confirm the boot identity, and then verify:

1. Bluetooth initialization and OTP address `B0:02:47:43:EA:3B`.
2. Classic discovery against Ubuntu `D8:3B:BF:CC:5D:D9` and reverse discovery.
3. Repeated reads of both r22 proc nodes without panic.
4. Wi-Fi association, Ethernet, HDMI display/audio, UVC camera, USB, RTC,
   storage, Chinese locale, 30-minute timeout, author metadata, and Gallery.

Do not claim the board repair is complete until both directions of Classic
discovery pass with an independent peer.
