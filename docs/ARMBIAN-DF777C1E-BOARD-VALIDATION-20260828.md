# Agibot-Armbian df777c1e board validation (2026-08-28)

## Image and boot

- Image: `Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img`
- SHA-256: `df777c1e917174cd94fd779fcbbad3555d68c2a56edc5eb5898453408bb47ffa`
- Local archive: `E:\AIPorject\101\agibot-releases\armbian\candidates\2026-08-18-branded-df777c1e\`
- Boot result: the board came online as `agibot` at `192.168.88.89`.
- Runtime identity:

```text
AGIBOT MB0002 V2
Agibot-Armbian 26.08.0-trunk Jammy
Linux 6.1.115-vendor-rkxx
```

The branded identity and `/usr/share/doc/agibot/README.md` were present on the
running rootfs.

## Regression result

Command:

```sh
bash /root/postflash-test.sh --scan --net --stress
```

Result:

```text
PASS=34  FAIL=0  WARN=3  SKIP=0
```

Raw log archived as:

```text
E:\AIPorject\101\agibot-releases\armbian\candidates\2026-08-18-branded-df777c1e\BOARD-TEST-20260828.log
```

Validated subsystems include:

- Device tree, 8 CPUs, CPUFreq and all-core concurrency.
- 15.6 GiB RAM and zram swap.
- 233 GiB eMMC, root-filesystem direct write at about 216 MB/s.
- Intel 16 GiB NVMe endpoint and driver binding.
- Eth1 1000 Mb/s full-duplex link.
- AP6275P Wi-Fi PCIe endpoint and `wlan0`.
- BCM UART Bluetooth attach and `hci0`.
- CAN0/CAN1 device nodes.
- Seven thermal zones and CPU/GPU/NPU/DMC devfreq.
- Mali render nodes, connected/enabled 1080p HDMI, and three ALSA cards.
- RKNPU driver and ResNet18 inference at 137 FPS.
- Rockchip MPP service/VPU demo binary.
- UVC camera nodes, USB hubs, keyboard, RTC, watchdog, LED, GPIO and UART.

## Wi-Fi connection

`wlan0` was configured persistently with Netplan/networkd for SSID
`cc181003`; the passphrase is intentionally not copied into this repository.

Observed link:

```text
SSID: cc181003
BSSID: dc:d8:7c:52:04:51
IPv4: 192.168.88.184/24
signal: -56 dBm
RX/TX rate: 172/146 Mbps
```

Connectivity checks:

- ICMP to `223.5.5.5` via `wlan0`: 3/3 packets, average about 20.4 ms.
- DNS resolution via `wlan0`: successful.
- HTTPS to Baidu and Tsinghua mirror via `wlan0`: successful HTTP/2 or 200.

The router did not answer four ICMP echo packets addressed to `192.168.88.1`
over WLAN, while routed internet, DNS and HTTPS all worked. This is treated as
router/AP ICMP policy rather than a board Wi-Fi failure.

## Additional stress check

Eight concurrent 30-second hash workloads were run to cover all CPUs:

```text
thermal_zone0: 30.5 C -> 38.8 C
maximum reported zone after stress: 39.8 C
little cores: 1.8 GHz
big cores: 2.208 GHz
```
The board remained responsive over SSH and no systemd services entered a failed
state.

## Regression warnings

1. `eth0` had no carrier because no cable was attached to that port.
2. The script tests internet with `1.1.1.1`, which did not answer ICMP on this
   network. Direct tests through both `eth1` and `wlan0` to `223.5.5.5` and
   HTTPS endpoints succeeded.
3. The minimal image does not include `stress-ng`; the custom all-core test
   above was used instead.
4. `i2cdetect` is not installed in the minimal image, so the optional I2C
   address scan could not run even though all seven I2C buses were enumerated.

## Not covered

This was a driver/connectivity/regression validation. It did not perform
Bluetooth pairing, USB serial loopback, CAN bus loopback, audio playback, or a
long-duration thermal soak.
