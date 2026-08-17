# AGIBOT MB0002 V2 硬件与驱动验收(2026-08-18)

测试对象:Rockchip RK3588 AGIBOT MB0002 V2，Armbian 26.08.0-trunk，
内核 `6.1.115-vendor-rk35xx`。本报告严格区分“驱动已加载”“设备已枚举”和
“物理接口已带外设测试”，未接外设的接口不记为通过。

## 自动回归结果

更新版 `flash/postflash-test.sh` 实跑结果 `PASS=29 FAIL=0 WARN=4 SKIP=0`，日志为
`/var/log/rk3588_test_20260818_013109.log`。其中一个 WARN 是 vendor `wl` 驱动不提供
脚本原先查找的 sysfs driver 软链接造成的假告警，已改用 `ethtool -i` 检测；其余
WARN 对应未接显示器、第二网口无载波和没有摄像头。NPU 已由脚本自动选择实际存在
的 MobileNet 模型并成功推理。

| 子系统 | 2026-08-18 状态 | 结论 |
|---|---|---|
| CPU / CPUFreq | 8 核在线，调频正常 | 已实测 |
| 内存 | 15.6 GiB | 已实测 |
| eMMC | 233 GiB，临时 256 MiB direct 写约 231 MB/s | 已实测 |
| 千兆网口 | eth0 1000 Mbps Full，网关可达；eth1 无线缆 | eth0 已实测，eth1 仅驱动 |
| Wi-Fi | `14e4:449d`，`wl` 驱动；扫描到 12 个 BSS | 已实测，测试后恢复 DOWN |
| 蓝牙 | `hci0`，uart6/ttyS6，BCM4362A2 固件加载 | 内核/HCI 已实测，缺管理工具 |
| GPU | Mali DRM `/dev/dri/renderD128` | 驱动与节点已确认 |
| NPU | rknpu 0.9.8；本轮 MobileNet 50 次约 196 FPS / 5.1 ms | 推理已实测 |
| VPU/MPP | MPP 节点和工具存在；历史硬解 30 帧测试通过 | 驱动已确认，当前轮未重跑码流 |
| 音频 | ACM8625P `i2c 1-0015`；S32_LE/48 kHz/双声道无声 PCM 写入成功 | 数字通路已实测，仍需扬声器听音 |
| HDMI / DP | DRM connector 与 HDMI/DP 声卡存在，当前 disconnected | 驱动已确认，未接屏 |
| CAN | can0/can1，`rockchip_canfd` | 驱动已确认，未接收发器回环 |
| UART | 7 个 ttyS；UART2 为调试控制台 | 驱动已确认，未逐口回环 |
| I2C | 7 条 `/dev/i2c-*`，已绑定 RTC/PMIC/功放等 | 已确认；本轮未冒险扫描 |
| GPIO | 8 个 gpiochip | 仅存在性确认，禁止裸扫 |
| RTC / watchdog | rtc0 与 watchdog 节点存在 | 驱动已确认，watchdog 未触发 |
| 摄像头 | 未发现普通摄像头节点 | 当前无相机，不能判驱动失败 |
| SPI | 无 spidev | 多为 DT 安全策略，不能判 SPI 控制器失败 |

## PCIe 与 M.2 定案

启动日志早期的 `dw-pcie ... invalid resource` 是旧驱动探测噪声，随后板级
`rk-pcie` 驱动成功接管两条有端点的链路。不能再写成“PCIe 三路全挂”。

| 控制器 | 链路 / 端点 | 状态 |
|---|---|---|
| `fe170000` | Gen1 x1，Broadcom `14e4:449d`，驱动 `pcieh` | 板载 Wi-Fi 正常 |
| `fe190000` | Gen2 x1，VIA `1106:3483`，驱动 `xhci_hcd` | 底边四口 USB 3 正常 |
| `fe150000` | Gen3 x4，J8600 M.2 | 当前空槽，LTSSM 0x0 属预期 |

当前最小系统未安装 `lspci`，但 `/sys/bus/pci/devices` 已证明两个端点及驱动绑定。
M.2 只有插入 NVMe 后才能验收供电、参考时钟、PERST#、链路宽度和实际速率。

## 主板接口与驱动对应

| 物理接口 | 软件路径 / 能力 | 验证状态 |
|---|---|---|
| J9200 Type-C(丝印 4G) | `fc800000` EHCI，USB 2.0 High-Speed 480 Mbps | HUB + U 盘实测 |
| J3300/J3400/J3500/J3600 | VIA VL805，USB 3.0 Gen1 5 Gbps | 四口逐口实测 |
| USB3000 | `fcd00000.usb` + Genesys Hub，5 Gbps | U 盘实测 |
| J3000 上/下 | `fcd00000.usb` + Genesys Hub，5 Gbps | 两口实测 |
| J2900 上/下、J2901 上/下 | `fc400000.usb` + Genesys Hub，5 Gbps | 四口实测 |
| J2600 刷机 Type-C | `fc000000.usb` UDC，ADB/RockUSB gadget 路径 | 刷机实测 |
| J9304 TTL USB | UART2/ttyFIQ0，1500000 8N1 | 控制台实测 |
| J8600 M.2 | PCIe `fe150000`，预期 Gen3 x4 | 槽位确认，空槽未验收 |
| J7000/J7001 | ACM8625P 立体声 BTL 输出 | 驱动确认，针序/听音待测 |
| J9400/J7002/J9701 | CAN/UART/USB/电源线束候选 | 功能仍属推断，禁止按猜测接线 |
| J9702/J9703、J8900/J8901 | 调试/扩展排针 | 仅位置与针数确认，针定义未知 |
| J2000 主电源 | 三针；中间为 VIN+，靠近 301 标记的一针为 VIN-，余下一针功能未知 | 正负极按实物确认，第三针待定 |

USB 的 Bus 编号会随启动和设备插拔改变，长期记录应以物理丝印、控制器地址和
Hub port 为主，不能仅凭某次启动的 Bus 号修改接口映射。

## 尚需现场完成

1. eth1 插网线，核对 1000 Mbps、双向 iperf3 和稳定性。
2. HDMI 接显示器，验证分辨率、热插拔、tty1 和 HDMI 音频。
3. J8600 插 NVMe，核对 `lspci -vv` / `nvme list`、Gen3 x4 和读写温度。
4. J7000/J7001 接匹配扬声器，使用 S32_LE/48 kHz 小音量听音并确认左右声道。
5. CAN0/CAN1 接收发器做双通道回环；UART 各接口短接 TX/RX 后逐口测试。
6. 接入目标相机，核对 UVC/MIPI 节点、格式、帧率和连续采集。
7. 核对 J9400/J7002/J9701/J9702/J9703 的原理图或用示波器逐针测量。

在这些现场项目完成前，准确结论是“当前已连接硬件与核心驱动无 FAIL”，而不是
“所有外部接口均已通过”。
