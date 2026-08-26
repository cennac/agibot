# SW9200 Loader entry and r1 recovery flash

Date: 2026-08-26

## Scope

This record closes the physical-access recovery test from
`docs/21-maskrom-loader-flash-incident.md`. It validates both the SW9200
U-Boot loader key and a complete write of the known-good r1 Android image.

## SW9200 validation

COM9 was monitored passively at 1,500,000 baud with:

```text
python tools/_boot_watch.py 1800 COM9
```

The board was reset while SW9200 was held. Windows enumerated:

```text
USB\VID_2207&PID_350B\154C3268C6CDEE4E
Rockusb Device
```

RKDevTool v3.37 reported:

```text
发现一个LOADER设备
Loader Ver:1.11
```

This is the first on-device validation of the SW9200 DTS mapping. It proves
that the key survives SPL filtering and reaches U-Boot `setup_download_mode()`.

## Flash input

Only one RKDevTool v3.37 process was kept open. The loaded complete image was:

```text
E:\AIPorject\101\android14-flash\releases\2026-08-25-r1-zh-rknn-validated\agibot-mb0002-android14-r1-zh-rknn-validated-update.img
SHA-256 5BF4260E5FDEF6D40D5675CE334398DC58ACD1806A43889A7FDB695FE3CDE1F4
```

The complete-image upgrade action was used while the board was already in
LOADER mode. No additional Maskrom loader download or storage-switch operation
was required.

## Flash result

RKDevTool completed every preflight and write stage:

```text
测试设备成功
校验芯片成功
获取FlashInfo成功
准备IDB成功
下载IDB成功
下载固件 100%
下载固件成功
```

The board then left Rockusb enumeration and rebooted automatically.

## Boot result

The passive COM9 log reached Android userspace:

```text
Starting kernel
sys.boot_completed=1
rk_gmac-dwmac fe1b0000.ethernet eth1: Link is Up - 1Gbps/Full
```

## Post-flash validation

The complete driver regression check for this recovered r1 boot is recorded in
`docs/24-r1-post-recovery-driver-validation.md`. In summary, the board, wired
network, HDMI display/audio, GPU, eMMC, USB/UVC capture, and RKNN service are
functional, while r1 still lacks CameraService publication, media-engine nodes,
Wi-Fi/BT, RTC, the larger memory mapping, and author metadata.
