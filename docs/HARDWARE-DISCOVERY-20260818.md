# AGIBOT MB0002 V2 hardware discovery matrix (2026-08-18)

This report combines the vendor image, decompiled device tree, core-board pin
diagram, board photographs, recovered robot files and read-only tests on
`192.168.88.89`. It distinguishes a physical device from an enabled SoC block:

- **Confirmed**: physical inspection plus electrical or behavioral test.
- **Strong**: two or more independent sources agree, but the physical signal
  path has not completed an end-to-end test.
- **Candidate**: a plausible lead that still needs continuity or waveform data.
- **SoC only**: present in the RK3588/core-board design, with no proof that the
  MB0002 baseboard exposes or populates it.

## Most important findings

1. The vendor boot chain really runs
   `/etc/rc.local -> /home/.qc/robot.sh -> USB_Monitor.sh`. That script exposes
   five board controls that are not represented by the current DT:
   `AUDIO`, `PCIE30X4`, `LIDAR`, `4G` and `HDMI_PWR_EN`.
2. J2600 is more than a RockUSB/ADB port. The HUSB311 at I2C6 address `0x4e`
   physically responds with VID:PID `2e99:0311`; the vendor DT describes dual
   data/power roles, 5 V source/sink PDOs and DP Alt Mode SVID `0xff01`.
3. The original robot used four USB Berxel iHawk100 depth cameras. CSI/DSI
   controllers in the vendor DTS are disabled and have no populated sensor
   endpoint, so the old claim of six active MIPI cameras was incorrect.
4. The J970x electrical measurements support a CAN hypothesis, but do not
   prove it. About 2.5 V common mode and about 120 ohm termination also fit an
   RS-485-style differential network, and every external SocketCAN loop test
   failed. The connector must remain a differential-bus candidate until the
   U970x transceiver marking or an oscilloscope waveform identifies it.
5. J7002 should not be called a high-confidence dual-USB harness. Its `70xx`
   designator and placement in the ACM8625P/audio area are contrary evidence.

## Board-level control lines

The old global GPIO numbers resolve to PCA9555 offsets as follows. Current
levels were sampled without changing direction or output state.

| PCA9555 | Offset | Vendor name | Vendor boot action | Current state | Assessment |
|---|---:|---|---|---|---|
| `3-0020` | 0..11 | HUB1/HUB2/HUB3/HUB20 ports | output high | output high | Confirmed USB downstream VBUS enables |
| `3-0020` | 12 | AUDIO | output high | input, level 0 | Strong amplifier/power enable; missing from current initialization |
| `3-0020` | 13 | PCIE30X4 | code commented out | input, level 1 | Named reservation only; do not treat as vendor-default enable |
| `3-0020` | 14 | LIDAR | output high | input, level 0 | Strong external lidar power/enable; lidar model unknown |
| `3-0020` | 15 | 4G | output high | input, level 0 | Strong external cellular-module power/enable |
| `3-0021` | 13 | HDMI_PWR_EN | output high | input, level 1 | Strong HDMI auxiliary power enable; J5000 already works at this level |

The chip/offset split is now confirmed by the original 5.10 system rather than
inferred from probe order: its live bases were `3-0021=477` and `3-0020=493`.
Thus vendor gpio490 is `3-0021.off13`, while gpio493..508 are
`3-0020.off0..15`. All scripted lines except the commented PCIE30X4 line were
observed as output-high after vendor boot.

The current direction/value combination explains why USB and HDMI work while
the external audio/lidar/4G domains can remain off. These lines must be tested
one at a time with current observation; they should not all be asserted just to
make the boot log look cleaner.

## Physical connector matrix

| Connector | Best current identification | Evidence level | Remaining uncertainty |
|---|---|---|---|
| Dual RJ45/J6700 area | HDMI-side: eth1/fe1b0000; board-edge leftmost: eth0/fe1c0000; both RTL8211F 1000BASE-T | Confirmed | Both have negotiated 1000M/full; eth1 passed DHCP and 20 pings with 0% loss, while eth0 had carrier and zero RX/TX errors/drops on 2026-08-19 |
| J5000 | HDMI0 output | Confirmed | CEC/audio and long-duration display test |
| USB3000, J3000, J2900, J2901 | Six USB 3.0 Type-A host ports through Genesys hubs | Confirmed | None for basic USB; per-port power-offset mapping remains |
| J3300..J3600 | Four USB 3.0 Type-C host ports through VL805 | Confirmed | No evidence for PD or video on these four ports |
| J9200 (`4G`) | USB 2.0 host, intended external modem path | Confirmed USB / strong 4G role | Measure VBUS/CC before connecting another host |
| J2600 | RockUSB/ADB plus dormant PD, DRD and DP Alt Mode hardware | Confirmed device mode / strong dormant roles | Current HUSB311 disabled to avoid a 6.1 dependency loop |
| J9304 | On-board USB-to-UART2 debug console, 1.5 Mbaud | Confirmed | USB bridge chip marking |
| J8900 | SWDIO/SWCLK/GND header | Confirmed by silk | Logic voltage and target domain |
| J8901 | UART0 TX/RX/GND | Confirmed loopback | Line also carried a 12 V telemetry message; shared endpoint unknown |
| J2500 | Standard-shaped dual USB 2.0 internal header | Strong | Confirm pins 7/8 ground and map it to `fc880000` by insertion test |
| J8600 | Empty PCIe Gen3 x4 M.2 slot | Strong | NVMe endpoint, lane width, power and performance test |
| J7000/J7001 | ACM8625P stereo BTL speaker outputs | Strong | AUDIO enable, left/right and polarity, actual listening test |
| J7002 | Unknown 2x4 connector in the `70xx` audio region | Candidate | Continuity to ACM8625P/I2S/power components; retract prior USB claim |
| J9400 | Unknown 2x5 robot harness candidate | Candidate | Pin voltage/continuity and original cable tracing |
| J9701/J9702 | Same terminated differential pair plus GND; J9701 adds +12 V | Confirmed topology / candidate protocol | CAN vs RS-485, polarity, controller mapping |
| J9703 | Independent terminated differential pair plus GND | Confirmed electrical shape / candidate protocol | CAN vs RS-485, polarity, controller mapping |
| J5001/J9303 | One GND plus one high-impedance low-level signal each | Confirmed electrical shape | Function unknown; do not inject voltage |
| J9301 | Two-wire 5 V fan supply, remains powered after virtual poweroff | Confirmed | Whether a load switch exists; this record does not distinguish running/off voltage |
| J2000 | Main input: center positive, inner negative, third pin unknown | Partially confirmed | Input range/current and third-pin function |
| ANT6300/ANT6301 | Two RF antenna connectors for the AP6275P-class module | Confirmed | Antenna-chain assignment |

## Devices and functions found on the board

| Device/function | Evidence | Status |
|---|---|---|
| Broadcom `14e4:449d` Wi-Fi | PCIe endpoint, vendor firmware and live scans | Working; HE/802.11ax capability reported |
| BCM43752A2/BCM4362A2 Bluetooth | UART6 traffic and firmware patch | HCI working; Bluetooth SCO ALSA card absent |
| VIA VL805 `1106:3483` | PCIe endpoint driving J3300..J3600 | Working |
| ACM8625P | I2C1 `0x15`, ALSA card and DSP firmware | Digital path working; external AUDIO enable and speakers need test |
| HUSB311 | I2C6 `0x4e`, live ID `2e99:0311` | Physically present, current DT deliberately disabled |
| HYM8563 RTC | I2C6 `0x51`, `rtc0`, `wakeup-source` | Working; board battery populated |
| PCA9555 x2 | I2C3 `0x20/0x21` | Working; 12 USB lines initialized, five other controls omitted |
| RK8602/RK8603 regulators | I2C0/I2C1 clients | Working; NPU rail is one consumer |
| Two CAN controllers | `fea50000` and `fea60000`, internal loopback | SoC/driver path working; no proved connector mapping |
| RTC/PMIC power key/ADC key | input events and button behavior | Working for SW9202 and SW9200 paths |
| Hardware crypto/TRNG, GPU, NPU, VPU | driver nodes and behavioral tests | Working; not external connectors |

## Original robot peripherals inferred from software

- The latest recovered 2023-04-05 logs show four Berxel iHawk100 depth-camera
  roles: front-wide `HK100RB3518P1B846`, front-bottom `...P1B862`, left
  `...P1B882`, right `...P1B414`. An earlier log maps three serials
  differently, proving that role assignment followed physical USB-port order
  and was not a permanent serial-number identity. The startup script also
  supports Orbbec/Astra cameras as an alternative.
- The vendor rootfs contains `quectel-CM` and PPP configuration for
  `/dev/ttyUSB3` at 115200 baud, APN `3gnet`. Together with J9200 and the `4G`
  enable line, this is strong evidence for an external Quectel USB modem.
- `LIDAR` is a real board enable name, but no vendor/model driver was recovered.
  Generic `LaserScan` and `depthimage_to_laserscan` packages are not proof of a
  physical lidar; depth cameras can generate the same ROS topic.
- Robot messages describe front, power, bottom and rear MCU/SCU firmware,
  wheel encoders, bumper/collision, left/right ultrasonic distance, BMS,
  charge state, water level, pressure, temperature, brushes, pumps and fans.
  These are whole-robot functions behind an MCU/CAN/serial aggregation path,
  not evidence that every sensor connects directly to an RK3588 header.

## Live UVC camera result

The camera inserted on 2026-08-18 enumerated as `1bcf:0b09`, manufacturer
`SYX-230524-J`, product `HD Camera`, at:

```text
fc400000.usb -> Genesys USB2 hub 9-1 -> port 3 (9-1.3)
```

This is the USB2 companion path of the already mapped J2901 upper port. It
created `/dev/video0`, `/dev/video1` and `/dev/media0`. `/dev/video0` advertises
MJPEG and YUYV at 640x480, 1280x720 and 1920x1080. A dependency-free V4L2 mmap
test read 30 frames in 1.473 s (20.36 FPS); all 30 SHA-256 prefixes differed,
with compressed frame sizes from 99,706 to 272,147 bytes. `/dev/video1` is the
same camera's auxiliary metadata node, not a second image sensor.

## 2026-08-19 regression snapshot

The following checks were run on the Armbian `6.1.115-vendor-rk35xx` boot that
began at 00:09 local board time:

- No systemd units were failed. HYM8563 `rtc0` tracked NTP-synchronized system
  time. The 233 GiB eMMC read 512 MiB sequentially in 1.649 s (about 325 MiB/s).
- The J2901-upper UVC camera streamed 120 MJPEG frames at 720p without frame
  errors; `v4l2-ctl` reported about 23.70 FPS. The nominal camera format remains
  30 FPS, so this measures the current camera/link, not a changed controller.
- The HDMI-side port was physically confirmed as `eth1` / `fe1b0000`; the
  board-edge leftmost port is `eth0` / `fe1c0000`. `eth1` acquired DHCP address
  `192.168.88.88/24`, negotiated RTL8211F
  1000 Mb/s full duplex, reached its gateway with 20/20 pings (0% loss, average
  0.604 ms), and showed zero RX/TX drops/errors and zero relevant PHY counters.
- After moving the cable to the board-edge leftmost port, `eth0` acquired
  `192.168.88.89/24`, negotiated 1000 Mb/s full duplex with carrier, and showed
  zero RX/TX errors and drops.
- The original 5.10.110 system independently confirmed the same physical
  mapping. Its HDMI-side `eth1/fe1b0000` acquired `192.168.88.69`; after the
  cable was moved, board-edge `eth0/fe1c0000` acquired `192.168.88.97`, passed
  20/20 gateway pings (0% loss, 0.688 ms average), and retained zero RX/TX,
  CRC, carrier, FIFO and fatal-bus errors. The original kernel prints the same
  optional GMAC clock and `eth_lpi` messages while both links operate normally.
- With `wlan0` temporarily up, the AP6275P Wi-Fi path scanned nine BSS/SSID
  entries; the interface was restored DOWN afterward. UART Bluetooth `hci0`
  loaded the BCM4362A2 patch and enumerated through ttyS6.
- Both `can0` and `can1` passed classic-CAN internal-loopback send/receive tests
  at 500 kbit/s (`0x123/AGB-C0` and `0x456/AGB-C1`) and were restored DOWN.
- On the original 5.10.110 system, direct J9702↔J9703 loopback failed at
  125/250/500/1000 kbit/s in both differential polarities. Controlled 500 kbit/s
  transmission plus a multimeter showed only a weak can0→J9703 differential shift
- ACM8625P remained card 1 with both PCM devices and its Master control at 75%.
  No speaker was connected, so this is still a digital-path check only.
- The NPU runtime loaded the preinstalled ResNet18 RKNN model and completed 100
  inferences in 0.70 s (142.9 FPS, single-core fallback by model configuration).

## Capabilities that must not be advertised as baseboard interfaces

- All six MIPI CSI hosts, CSI DPHYs and ISP paths are disabled in both the
  vendor and current runtime DT; no sensor endpoint is populated.
- DSI0/DSI1 parent controllers are disabled. Two child panel templates and
  init sequences remain under disabled parents, and no FPC display connector
  is visible on the baseboard.
- SATA, HDMI1, HDMI RX, eDP, extra PWM/SPI blocks and many alternate UART/I2C
  muxes exist in RK3588/core-board definitions but have no proved MB0002
  connector. CN9800 routing alone does not make them user-accessible.

## Highest-value next tests

1. Identify U9700/U9701 markings or probe J9702/J9703 with an oscilloscope while
   can0/can1 transmits. This resolves CAN vs RS-485, polarity and mapping in one
   controlled test.
2. Insert a USB device through a checked J2500 adapter to map `fc880000` and its
   two candidate ports.
3. Use a Type-C analyzer on J2600 before enabling HUSB311; develop PD/DRD/DP in
   a separate experimental DT, preserving the stable ADB DT.
4. With current monitoring, assert only `AUDIO`, then test J7000/J7001 at low
   volume. Test `4G` and `LIDAR` separately only when the matching module is
   connected.
5. Insert NVMe in J8600 and verify endpoint, Gen3 x4 negotiation, PERST#, power,
   temperature and sustained I/O.
6. Trace J7002, J9400, J5001, J9303 and J2000 pin 3 with power removed. Do not
   infer protocols from connector shape alone.
7. Completed on 2026-08-19: SW9201 and SW8900 both produce the same externally
   visible hard-reset chain in Armbian and the original system. Electrical
   reset-net identity remains unproven. SW8901/SW8902 produced no input event
   on short press in either system; holding each across reset for about ten
   seconds still booted the original image with `androidboot.mode=normal`.
   SW9202 reports PMIC `KEY_POWER`; original userspace maps short press to a
   currently failing Wi-Fi-blocked suspend and a three-second hold to clean
   `poweroff`/BL31 virtual poweroff.
8. J9301 measured 5 V with a multimeter on 2026-08-19. Continue tracing with
   power removed to determine whether a load-switch/MOSFET enable exists.
