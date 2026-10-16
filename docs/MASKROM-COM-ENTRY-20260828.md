# COM-entered Maskrom record (2026-08-28)

## Scope

The board was intentionally put into true BootROM Maskrom through COM9 so a new
image can be flashed through the Rockchip USB port. No image was flashed during
this operation.

## Initial state

- Host serial adapter: `USB-SERIAL CH340 (COM9)`.
- Passive 1,500,000-baud capture first received no output.
- Sending the non-destructive U-Boot `download` command exposed an Armbian
  login/password prompt, proving that the serial console was alive and the
  board was in Linux userspace rather than U-Boot.
- Serial login identified the running system as:

```text
Armbian-unofficial 26.08.0-trunk Jammy
AGIBOT MB0002
Linux 6.1.115-vendor-rkxx
IPv4: 192.168.88.89
```

This also resolves the earlier identity ambiguity: `192.168.88.200` was the
separate `ADM`/`adm.lan` host, not this board.

## Maskrom transition

After obtaining the documented root serial shell, the standard rescue sequence
was executed:

```sh
dd if=/dev/zero of=/dev/mmcblk0 bs=512 count=32768 conv=fsync
sync
reboot -f
```

Observed result:

```text
32768+0 records in
32768+0 records out
16777216 bytes (16 MiB) copied
Rebooting.
```

This erases only the 16 MiB boot region (idbloader and U-Boot); the rootfs
begins at LBA 32768 and was not overwritten by this operation.

## Maskrom verification

After reboot:

- `192.168.88.89` stopped responding to ping.
- COM9 remained silent, as expected in BootROM Maskrom.
- Windows enumerated the Rockchip USB device:

```text
USB\VID_2207&PID_350B\7&2D3343A1&0&3
```

The device remained present at 2026-08-28 08:46:04 +08:00. Since the on-media
boot region had just been erased, this is the recoverable true Maskrom state.

## Next flashing rule

Use the validated RK3588 loader and a raw image through the Download Image
flow, or `rkdeveloptool db ...; rkdeveloptool wl 0 ...; rkdeveloptool rd`.
Do not power-cycle the board unnecessarily before flashing: although BootROM
can rediscover the erased boot region, keeping the current USB enumeration
avoids another variable.

## 2026-08-28 RKDevTool "no device" follow-up

RKDevTool initially reported no device even though Windows still enumerated the
MaskROM USB node. The cause was not a lost MaskROM: usbipd had force-shared
bus/port `8-3`, so Windows bound it to the VirtualBox USB filter:

```text
8-3    2207:350b    Rockusb Device    Shared (forced)

FriendlyName : USBIP Shared Device
Service      : VBoxUSB
Status       : OK
```

The `usbipd unbind` operation required administrator approval. Only bus/port
`8-3` was released; the COM9 adapter on `8-1` was not changed.

```text
usbipd unbind --busid 8-3
```

After the unbind, Windows rebound the same instance to the installed Rockusb
driver:

```text
8-3    2207:350b    Rockusb Device    Not shared

FriendlyName : Rockusb Device
Service      : Rockusb
Class        : Rockusb Device
Status       : OK
InstanceId   : USB\VID_2207&PID_350B\7&2D3343A1&0&3
```

RKDevTool v3.37 was then closed and relaunched. Its main window changed from
"no device found" to the discovered MaskROM state, and its partition list
became readable. Host-side evidence is captured in:

```text
E:\AIPorject\101\agibot-releases\armbian\candidates\2026-08-18-branded-df777c1e\evidence\RKDevTool-PrintWindow-20260828.png
E:\AIPorject\101\agibot-releases\armbian\candidates\2026-08-18-branded-df777c1e\evidence\RKDevTool-Status-20260828.png
```

Operational note: do not run `usbipd bind --force` against `8-3` while
flashing. VBoxUSB/usbipd will otherwise take the Rockusb node away from
RKDevTool again.
