# AGIBOT MB0002 V2 hardware inventory

## Board identity and compute

| Item | Value | Source/confidence |
|---|---|---|
| Product | AGIBOT MB0002 V2 | recovery documentation, high |
| SoC | Rockchip RK3588 | board documentation, high |
| CPU | 4x Cortex-A76 + 4x Cortex-A55 | DTS, high |
| RAM | 16 GiB | recovery documentation, high |
| eMMC | About 233 GiB, `/dev/mmcblk0` | recovery documentation, high |
| Original Linux | Ubuntu 20.04, kernel 5.10.110 vendor BSP | backup, high |
| Android baseline kernel | Linux 6.1, Rockchip RKR6 | selected baseline, high |

## Display

| Interface | Original state | Phase 0 decision |
|---|---|---|
| HDMI0 at `0xfde80000` | enabled and observed working as `HDMI-A-1` | primary display |
| HDMI1 at `0xfdea0000` | disabled | leave disabled |
| DSI0 at `0xfde20000` | vendor tree contains an enabled simple panel | disabled initially |
| DSI1 at `0xfde30000` | vendor tree contains panel state | disabled initially |
| eDP / DP / HDMI RX | disabled or not part of first milestone | disabled |

The first boot milestone should expose one landscape HDMI output and avoid
simultaneous-panel policy questions. DSI timing and power sequencing can be
migrated after HDMI and input work.

## Storage and boot

- Original Rockchip-style eMMC partition map: `uboot`, `misc`, `boot`,
  `recovery`, `backup`, and root filesystem.
- The original root partition used `PARTUUID=614e0000-0000`.
- Android will need its own GPT and partition map; do not reuse the Linux
  command line unchanged.
- The recovery package
  `RK3588-backup/06-image/update-fixed-rk3588-loader.img` remains the emergency
  restore path and is intentionally not copied into this directory.

## Ethernet

The original tree enables dual GMAC nodes. Current inventory identifies:

- GMAC at `0xfe1b0000` and GMAC at `0xfe1c0000`.
- RGMII routing and vendor delay/reset properties are present in the original
  5.10 DTS.
- The newer mainline-oriented DTS already carries useful references, but its
  values must be revalidated against the Android 6.1 Rockchip kernel binding.

Ethernet is preferred over Wi-Fi for source development and ADB debugging.

## Wireless uncertainty

This is a high-priority unresolved item:

- The original decompiled DTS declares `wifi_chip_type = "ap6275p"` and a
  Broadcom-style wireless node.
- The extraction notes name RTL8821CU and RTL Bluetooth.
- A Broadcom 449d PCIe part is also mentioned in older extraction notes.

Do not select an Android Wi-Fi HAL or copy firmware based on the DTS string
alone. Phase 1 must identify the populated module by rail enable state, bus
enumeration, visible chip markings, and a Linux diagnostic boot before making
the Android configuration decision.

## USB, hubs, and input

- RK3588 native USB2/USB3 nodes are present.
- The original 5.10 `hubrst-gpio` node resolves to `GPIO4_D2/D3`, Linux global
  GPIOs 154/155; an on-board test verified the reset pulse. The older
  `GPIO4_D6/GPIO4_D7` interpretation is a stale decoding error.
  `GPIO4_D4/D5` are instead the two Ethernet PHY reset lines.
- USB mouse and keyboard are the first user-input path.
- USB hub reset ordering must be migrated before treating external USB as
  reliable.

## Audio

The original tree contains I2S and an ACM8625P codec. Android audio is deferred
until the product boots; it is not part of the first milestone.

## Other devices

CAN, MIPI CSI, NPU, RTC, IO expander, and robot-specific peripherals are not
first-boot requirements. Their nodes should remain disabled or untouched until
the base image is stable.
