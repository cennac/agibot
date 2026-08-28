# AGIBOT MB0002 V2 public research
Date: 2026-08-28

## Executive conclusion

AGIBOT MB0002 V2 should be treated as a custom robot compute board from the
AgiBot/Zhiyuan commercial cleaning-robot program. The best current identity is:

```text
board silk/model: AGIBOT MB0002 V2 / CL_PCBA_MB0002_V5
SoC:              Rockchip RK3588
software family:  AgiBot scrubber / clean_msgs v0.25.3
likely product:   Zhiyuan Juechen C5 commercial cleaning robot
```

The exact product correlation is assessed as medium-high confidence, not
absolute proof. There is no public page or document found that directly maps
`MB0002 V2` or `CL_PCBA_MB0002_V5` to a named commercial product. The evidence
nevertheless lines up strongly:

- The original rootfs calls its application family `AgiBot/scrubber`.
- The extracted ROS package metadata uses a maintainer address in the
  `zhiyuan-robot.com` domain, directly linking the software to Zhiyuan/AgiBot.
- The original application includes `clean_msgs`, `scrubber_common`, CAN/chassis
  interfaces, four Berxel iHawk100 camera roles, LIDAR power control, 4G, and
  workstation/supply/task interfaces.
- Zhiyuan publicly sells the Juechen C5, described as a commercial robot that
  combines sweeping, scrubbing, and dust mopping, with laser-vision localization,
  point-cloud/image fusion, and a workstation for charging and water handling.

It is therefore more accurate to call this a commercial cleaning/scrubbing robot
board than a household vacuum-cleaner board.

## Evidence matrix

| Claim | Evidence | Confidence |
| --- | --- | --- |
| Board identity is AGIBOT MB0002 V2 | board photo/silk, original DTB and recovery documentation | high |
| PCBA reference is `CL_PCBA_MB0002_V5` | board marking recorded in the 3D interface map | high |
| Compute is RK3588 | original DTB, U-Boot, live Linux/Android enumeration | high |
| Original product software is AgiBot scrubber | `/app/agibot`, `scrubber_common`, `clean_msgs`, user history | high |
| Vendor is Zhiyuan/AgiBot | original ROS package maintainer domain `zhiyuan-robot.com`; public AgiBot identity | high |
| Likely public product line is Juechen C5 | feature match between local scrubber stack and official C5 description | medium-high |
| Exact MB0002-to-C5 revision mapping | no public direct statement found | unconfirmed |
| Public schematic/board manual exists | no credible public hit found | not found |

## Direct local evidence

The following local records remain the authoritative source for this board:

- `board-3d/README.md`: connector map, button/power/USB/CAN/camera findings.
- `android14/docs/01-hardware-inventory.md`: core hardware inventory.
- `docs/HARDWARE-DISCOVERY-20260818.md` and validation records.
- Extracted original DTB/U-Boot and the original Ubuntu backup.
- The isolated original-runtime analysis in the workspace outside this Git
  repository; it records the `/app/agibot` and GitLab provenance without
  redistributing proprietary binaries or private credentials.

Important original-system fingerprints:

```text
/app/agibot version: v0.25.3, git commit 8d66073c
GitLab module path:   code.agibot.com/agibot-scrubber/edge_gateway
ROS packages:         clean_msgs, scrubber_common, berxel_camera_ros2
DDS:                  CycloneDDS
robot actuator model: upper RK3588 controller + SCU/lower controller
```

The `code.agibot.com` host resolves only to a private RFC1918 address and is not
a public source repository. No attempt should be made to probe or authenticate
against that internal service. The public absence of its source is expected and
does not invalidate the local provenance.

## Public references checked

### Zhiyuan / AgiBot and C5

- Zhiyuan official site: <https://www.agibot.com.cn/>
- Zhiyuan company identity page: <https://www.agibot.com.cn/about_Zhiyuan>
- Juechen C5 product page: <https://www.agibot.com.cn/products/C5>
- English C5 page: <https://www.agibot.com/products/C5>

The official C5 page describes:

- sweeping, scrubbing, and dust mopping in one machine;
- 90 L water tank and 550 mm washing width;
- laser-vision fusion localization;
- point-cloud/image fusion perception;
- vehicle/mobile/cloud control;
- workstation automation for charging, water refill/drain, and sewage-tank
  cleaning.

These overlap closely with the original MB0002 software: four depth-camera
roles, robot/CAN chassis commands, LIDAR power, workstation/supply services,
and cloud/REST/MQTT interfaces.

Domain collision warning: <https://agibot.cn/> is an unrelated surgical-robot
site. It should not be used as a source for this board.

### Rockchip RK3588 and boot flow

- RK3588 product page: <https://www.rock-chips.com/a/cn/product/RK35xilie/2022/0926/1656.html>
- Rockchip open-source wiki: <https://opensource.rock-chips.com/wiki_Main_Page>
- Rockusb mode: <https://opensource.rock-chips.com/wiki_Rockusb>
- Boot options and eMMC write offsets: <https://opensource.rock-chips.com/wiki_Boot_option>
- Rockchip BSP kernel: <https://github.com/rockchip-linux/kernel>

The Rockchip page confirms the RK3588 feature set used during adaptation:
4x Cortex-A76 plus 4x Cortex-A55, Mali-G610 MC4, 6 TOPS NPU, 8K multimedia,
PCIe/USB3/RGMII and multi-camera ISP capabilities.

The Rockusb document distinguishes MaskROM, USB plug, miniloader Rockusb, and
U-Boot Rockusb modes. This matches the local incident history: MaskROM is the
last-resort BootROM path, while loader mode depends on a bootable loader. The
public document also confirms why a MaskROM image needs DRAM initialization
before large writes.

### AMPAK AP6275P wireless module

- AMPAK official AP6275P page: <https://www.ampak.com.tw/cn/product/WiFi-Bluetooth/Stamp-Type-2T2R/AP6275P>
- Distributor summary: <https://www.edomtech.com.cn/product-detail/ap6275p-wifi-bluetooth-5-3-module/>

AMPAK publicly specifies:

```text
module:       AP6275P
radio:        2T2R Wi-Fi 6 + Bluetooth 5.3
form factor:  15 x 13 mm stamp module
Wi-Fi bus:    PCIe
Bluetooth:    UART + PCM
drivers:      Linux and Android
temperature:  -30 to 85 C
```

This independently supports the board's PCIe Wi-Fi enumeration and UART
Bluetooth wiring. It does not resolve the board-specific antenna or RF-TX defect
under investigation; those remain board-level questions.

### ACM8625P audio amplifier

ACM8625P is an I2S digital-input Class-D audio amplifier with I2C control. A
public secondary product page is available at:

<http://www.chisic-ic.com/en/acm8625p.html>

The useful public facts are:

- PVDD 4.5--21 V, DVDD/IO 3.3 or 1.8 V;
- stereo 2x33 W or mono 1x51 W modes;
- I2C control and I2S/left-justified/right-justified/TDM audio;
- integrated BQ/DRC tuning and protection.

This page is not treated as a vendor-primary datasheet. Exact registers and
firmware tuning still come from the extracted firmware and live I2C/ALSA tests.

### Berxel depth cameras

- Berxel product site: <https://www.berxel.com/cn/camera.html>
- English product page: <https://www.berxel.com/camera.html>

Berxel publicly identifies itself as Berxel Photonics and publishes mHawk/iHawk
3D camera lines. The public pages currently show iHawk 100Q and P100Q variants,
but no public iHawk100 datasheet or `berxel_camera_ros2` repository was found.

The local original launch files and 2023 logs nevertheless confirm four
iHawk100 devices were once mapped as:

```text
front_wide, front_bottom, left, right
```

The Berxel SDK and original camera binaries are proprietary. They must not be
copied into an open source image or repository without written authorization.

### Similar public RK3588 board material

- Radxa ROCK 5B documentation: <https://docs.radxa.com/en/rock5/rock5b>
- Radxa BSP kernel: <https://github.com/radxa/kernel>
- Armbian build framework: <https://github.com/armbian/build>

These are useful for comparing U-Boot, display, PCIe, USB, and kernel bring-up,
not for copying board wiring. MB0002 has its own power tree, GPIO expander,
VL805 hub, camera topology, CAN routing, and AP6275P UART wiring.

## Search coverage and negative results

The following terms were checked through Bing, DuckDuckGo, GitHub repository
search, Sourcegraph's public page, and direct vendor sites:

```text
"AGIBOT MB0002"
"CL_PCBA_MB0002"
"CL_PCBA_MB0002_V5"
"rk3588-agibot-mb0002-v2"
"agibot-scrubber"
"code.agibot.com"
"zhiyuan-robot scrubber"
"Berxel iHawk100"
"berxel_camera_ros2"
Chinese variants for Juechen/C5/cleaning robot
```

GitHub repository search returned no public repository for:

```text
agibot rk3588
MB0002
agibot-scrubber
berxel_camera_ros2
```

This is consistent with an internal commercial product. The missing public
result is not evidence against the Zhiyuan identification.

## Practical adaptation consequences

1. Treat the extracted MB0002 DTB, original loader, photographs, serial logs,
   and live enumeration as the board primary.
2. Use Rockchip and generic RK3588 board material only as secondary references.
3. Never infer MB0002 wiring from a generic RK3588 EVB. The original wireless
   script's `ttyS9` assumption is already disproved by this board: working
   Bluetooth attachment uses UART6 `/dev/ttyS6`.
4. Keep robot actuator control disabled by default. CAN/J970x protocol,
   polarity, safety interlocks, and SCU behavior remain unconfirmed.
5. Do not redistribute the original edge gateway, Berxel SDK, scrubber
   binaries, private GitLab data, or credentials.
6. For complete hardware documentation, the realistic route is official vendor
   support with board photographs/serial numbers, or a genuine product-service
   manual. A public schematic is unlikely to appear through normal web search.

## Recommended next research steps

- Ask Zhiyuan/C5 product support whether an MB0002 service manual, PCBA
  schematic, or partition map is available for maintenance use.
- Ask Berxel for an authorized iHawk100 SDK and current Linux driver package.
- Keep monitoring the public AgiBot document center and C5 page for manuals or
  software packages.
- If another scrapped C5/scrubber mainboard becomes available, photograph and
  compare board revision, connectors, EEPROM/GPT identity, and wireless module
  markings. A second physical sample is the simplest way to verify the C5
  correlation.

## Final assessment

The adaptation work should continue to use the repository's independently
verified hardware map rather than waiting for an unlikely public MB0002 manual.
The public research now establishes enough provenance to describe the project
accurately as a community system port for an AgiBot/Zhiyuan commercial
cleaning-robot controller, with the C5 product line as the leading candidate.
