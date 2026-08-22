# Phase 1 DTS port map

This map is the pre-flight contract for moving AGIBOT MB0002 V2 hardware facts
from the vendor 5.10 tree into the locked Android 14 RKR6 Linux 6.1 tree. It is
not a drop-in patch. No entry below may be applied until the RKR6 source is
synced, its labels and bindings are inspected, and `tools/verify-source-baseline.sh`
passes.

## Evidence rules

1. The original 5.10 DTS is authoritative for board wiring, supplies, and reset
   lines.
2. The RKR6 Linux 6.1 source is authoritative for binding syntax and labels.
3. The newer mainline-oriented DTS is regression evidence only; its 6.12 HDMI
   and PHY bindings must not be copied blindly into the vendor 6.1 tree.
4. A ROCK 5C board DTS may explain vendor syntax, but never supplies AGIBOT pin,
   rail, connector, or partition facts.

The original decompiled DTS expresses phandles as numbers. When writing source,
replace those numbers with the labels exported by the RKR6 base DTS and use the
Rockchip GPIO macros rather than global GPIO numbers.

## First-boot map

| ID | Subsystem | Board fact from the original tree | RKR6 migration action | Gate |
|---|---|---|---|---|
| M01 | Board identity | `Rockchip RK3588 AGIBOT MB0002 V2 Board`; original compatibles are `rockchip,rk3588-agibot-mb0002-v2` and `rockchip,rk3588` | Create a dedicated `rk3588-agibot-mb0002-v2.dts`; retain the original identity strings until Android device policy is reviewed | Source label check |
| M02 | Debug console | UART2 at `0xfeb50000`, alias `serial2`, early console at 1500000 baud; original boot also selects `ttyFIQ0` | Enable UART2 and its selected pin group; preserve earlycon. Verify whether RKR6 uses the FIQ debugger or plain `ttyS2`, then set one console only | RKR6 serial/FIQ driver check |
| M03 | eMMC | `0xfe2e0000`, 8-bit, non-removable, no SD/SDIO, HS400 at 1.8 V plus enhanced strobe | Map to the RKR6 `sdhci` label and preserve the controller mode properties; do not copy the Linux root `PARTUUID` command line | RKR6 `rk3588.dtsi` label check |
| M04 | Core power | RK806 on SPI2 CS0, IRQ GPIO0_A7; RK8602/RK8603 CPU-big rails on I2C0; NPU rail on I2C1; little cores, GPU, logic, DDR and board rails from RK806 | Reproduce the regulator tree and CPU/GPU supplies with RKR6 names. Keep PCIe/audio/lidar/4G auxiliary enables off | Binding and rail-name diff |
| M05 | HDMI0 | HDMI0 at `0xfde80000` is the only original enabled HDMI route; J5000 is a verified Type-A output | Enable HDMI0, its PHY, VOP route, HPD/I2C pins and connector. Keep DSI0/DSI1/HDMI1 disabled | RKR6 vendor binding generation check |
| M06 | Ethernet | GMAC0 `0xfe1b0000`: RTL8211F at MDIO address 1, `rgmii-rxid`, `tx_delay=0x43`, reset GPIO4_D5. GMAC1 `0xfe1c0000`: PHY address 0, delay `0x42`, reset GPIO4_D4 | Preserve values, but use the reset property accepted by RKR6 stmmac. The original GMAC1 string `intput` is a typo for `input` | RKR6 stmmac binding check |
| M07 | USB hub reset | Vendor `hubrst-gpio` node uses raw GPIO4 offsets `0x1a/0x1b`, i.e. GPIO4_D2/D3, Linux global 154/155; the private 5.10 driver pulses both lines low then high | Implement an RKR6 kernel or early-init pulse; a static high GPIO hog alone does not reproduce reset. GPIO4_D4/D5 are Ethernet resets and must not be touched | RKR6 GPIO/sysfs availability and ordering review |
| M08 | USB VBUS | I2C3 exposes PCA9555 at addresses `0x20` and `0x21`; offsets 0..11 on `0x20` gate twelve USB-A VBUS lines; I2C3 uses the GPIO4_D0/D1 mux | Enable I2C3 and both expanders only after labels are verified. Initialize offsets 0..11 high for development; leave audio, PCIe, lidar, 4G and HDMI auxiliary lines untouched | Expander driver and Android SELinux review |
| M09 | Native USB | Original enabled OTG DWC3 at `fc000000`, host paths around `fc800000/fc840000`, `fc880000/fc8c0000`, `fcd00000`, and `fc400000` | Map addresses to RKR6 labels and enable only the paths needed for HID and ADB first. Keep PCIe/VL805 expansion for a later phase | Connector-to-controller test plan |
| M10 | Wireless | DTS says AP6275P, extracted files include RTL8821CU, and older notes mention Broadcom 449d | Keep Wi-Fi and Bluetooth disabled; no HAL, firmware copy, or rail enable until the populated module is identified | Physical/runtime identification |
| M11 | Deferred hardware | DSI, camera, CAN, robot buses, audio codec/amplifier, NPU policy, HDMI1 and PCIe/VL805 expansion | Leave disabled or absent from the first AGIBOT DTS; add one subsystem per reviewed commit after base boot | First-boot success |

## GPIO decoding anchor

GPIO4 has Linux base 128 in the reference trees. Therefore:

| Raw GPIO4 offset | Name | Global number in reference boot | Current meaning |
|---:|---|---:|---|
| `0x1a` / 26 | GPIO4_D2 | 154 | Genesys hub 1 reset |
| `0x1b` / 27 | GPIO4_D3 | 155 | Genesys hub 2 reset |
| `0x1c` / 28 | GPIO4_D4 | 156 | GMAC1 PHY reset, active low |
| `0x1d` / 29 | GPIO4_D5 | 157 | GMAC0 PHY reset, active low |

The old `GPIO4_D6/D7` interpretation is rejected. Reusing those pins would
leave both hubs floating and could make USB HID or ADB appear randomly at boot.

## USB sequencing requirement

The working 6.1 reference pulses GPIO4_D2/D3 low for about 150 ms, releases
them high, waits about one second, and only then cycles PCA9555 VBUS enables.
Android must preserve this order or document a better kernel-managed equivalent.
The first implementation may use an early Android init service only if the
RKR6 kernel exposes the required GPIO/I2C controls and SELinux permits that
narrow operation.

Do not assert all PCA9555 lines merely to simplify initialization. Besides USB
VBUS, the expanders control audio, PCIe, lidar, cellular and HDMI auxiliary
power domains. Those outputs must remain at their inherited state until each
subsystem has its own bring-up and rollback notes.

## Post-sync checklist

1. Run `tools/verify-source-baseline.sh /root/src/agibot-android14`.
2. Locate the RKR6 RK3588 base DTS, pincontrol header, RK806, stmmac, USB and
   HDMI definitions.
3. Record the exact label corresponding to every address in the table above.
4. Create the full AGIBOT DTS from the RKR6 include chain; do not assemble a
   hybrid of the 5.10 and 6.12 trees.
5. Compare regulator states, suspend states, pinctrl groups and power domains
   line by line before enabling any node.
6. Add the product and DTS changes as separate reviewable commits, with serial
   log expectations recorded for every enabled node.

Until those steps complete, `dts/agibot-display-bringup.dtsi` remains the only
candidate fragment and is intentionally not connected to a board DTS.
