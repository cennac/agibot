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
| HDMI / DP | J5000 热插拔已识别 2560×1440p60，TMDS 241.5MHz，HDMI PHY lane locked；拔出后正常回到 disconnected | EDID、时序与驱动链路已实测，屏幕实际画面待人工确认 |
| CAN | can0=`fea50000`、can1=`fea60000`，均由 `rockchip_canfd` 注册；500 kbit/s 内部回环均通过；`can-utils` 已安装并加入固件包列表 | 控制器、驱动及 pinmux 已确认，J970x 与控制器的物理映射仍待查 |
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
| J2500 | 2×5 缺 9 脚，共 9 针；1/2 针实测 +5V，外形与 ED2500/成组电阻高度符合双口 USB 2.0 内置排针 | 用途高可信；3–8 标准针序及 10 脚仍待电气实测 |
| J9400/J7002 | CAN/UART/USB/电源线束候选 | 功能仍属推断，禁止按猜测接线 |
| J9701 | 1×4 带 +12V 的 CAN-A 接口；从上到下：1=2.42V、2=2.52V、3=GND/0V、4=+12V | 前三针与 J9702 逐针直连，功能和并联关系已实测确认；CANH/CANL 极性待定 |
| J8900 | 1×3 SWD；从上到下 SWDIO / SWCLK / GND | 丝印确认，逻辑电平待测 |
| J8901 | 1×3 UART0/ttyS0；从上到下 TX(GPIO0_C5) / RX(GPIO0_C4) / GND | 短接回环确认；线路另有 12V 电压遥测文本，禁止长期短接 |
| J9702 | 1×3 CAN-A；左→右 2.42V / 2.52V / GND，信号脚间 118.8Ω | 与 J9701 1/2/3 逐针通断为 0Ω/0Ω/0.03Ω，确认同一路 CAN |
| J9703 | 1×3 CAN-B；左→右 2.49V / 2.49V / GND，信号脚间 120.7Ω | 第二路独立 CAN 已确认；极性及 can0/can1 映射待确认 |
| J2000 主电源 | 三针；中间为 VIN+，靠近 301 标记的一针为 VIN-，余下一针功能未知 | 正负极按实物确认，第三针待定 |
| J5001 | 1×2；靠 USB3000=GND，靠 J9200=高阻未知 | 断电 0.01Ω/OL、两针间 OL；上电空闲 0V/0.01V，HDMI 热插拔时 0V/0.16V，排除当前常供 5V/12V，用途待追线 |
| J9303 | 1×2；靠网口=GND，靠 HDMI=高阻未知 | 断电 0.01Ω/OL、两针间 OL；上电空闲 0V/0.03V，HDMI 热插拔时 0V/0.29V；主板已有板载电池，RTC 外接电池假设降级，暂列高阻辅助控制/检测接口，禁止未确认前注入电压 |

USB 的 Bus 编号会随启动和设备插拔改变，长期记录应以物理丝印、控制器地址和
Hub port 为主，不能仅凭某次启动的 Bus 号修改接口映射。

J9200 的原厂 DT 路径是 `fc800000` USB2 Host，PHY 供电指向 5000mV 的
`vcc5v0_host`；实机 regulator summary 也显示该轨为 5000mV。但由于存在“实物可能
非标准带 12V”的外部报告，在 Type-C 测试板实测 VBUS/CC 前，不得直接连接笔记本。
J2600 刷机口才是 HUSB311 控制的 `fc000000` OTG Type-C，其 DTS Source PDO 为 5V/3A，
不应将该配置误套到 J9200。

## 尚需现场完成

1. eth1 插网线，核对 1000 Mbps、双向 iperf3 和稳定性。
2. HDMI 接显示器，验证分辨率、热插拔、tty1 和 HDMI 音频。
3. J8600 插 NVMe，核对 `lspci -vv` / `nvme list`、Gen3 x4 和读写温度。
4. J7000/J7001 接匹配扬声器，使用 S32_LE/48 kHz 小音量听音并确认左右声道。
5. J9701/J9702 并联及两路约 120Ω 终端已经确认；can0/can1 内部回环通过，但 J9702↔J9703 外部回环在两种差分极性下均失败。下一步需检查 97xx 收发器使能/静默控制，或用示波器分别观察 can0/can1 受控发送时哪个物理座出现波形；UART 各接口短接 TX/RX 后逐口测试。
6. 接入目标相机，核对 UVC/MIPI 节点、格式、帧率和连续采集。
7. 核对 J9400/J7002 的原理图或用示波器逐针测量。J970x 应先完成断电通断/电阻测试，再用示波器或 CAN 分析仪确认 CANH/CANL、can0/can1 与真实波特率。

### J970x CAN 区交叉分析（2026-08-18）

- 电气实测：J9701 前三针与 J9702 三针均为 `2.42 / 2.52 / 0V`；J9703 为 `2.49 / 2.49 / 0V`。两信号脚约 2.5V、第三脚接地符合 CAN 物理层，且 J9701 额外提供 +12V。
- 断电实测：J9701 1/2/3 与 J9702 左/中/右分别为 `0Ω / 0Ω / 0.03Ω`，确认逐针并联；J9702 两信号脚间 `118.8Ω`，J9703 两信号脚间 `120.7Ω`，确认两条独立且各带约 120Ω 终端的 CAN 总线。
- 设备树：原厂 DT 启用 `can@fea50000`、`can@fea60000`，禁用第三路 `can@fea70000`；pinctrl 分别使用 GPIO0_C0/GPIO0_B7 与 GPIO4_B2/GPIO4_B3。
- 当前系统：`can0`、`can1` 分别绑定 `fea50000.can`、`fea60000.can`，驱动为 `rockchip_canfd`，99 MHz 时钟；当前均 DOWN/STOPPED、未配置 bitrate，不能从空闲状态读取原厂波特率。
- 机器人软件：ROS 消息 `WorkStationCmd` 明确注释 `from dm to canclient`，架构资料显示 CAN/串口连接前面板、电源板、底板、后面板四块 SCU/MCU，支持主板确实需要多路 CAN 的判断。
- 照片：J9701/J9702/J9703 同属 97xx 编号，J9702/J9703 紧邻并处于同一组接口/收发器外围器件区，排除了先前“功放辅助或普通测试点”的低证据猜测。

已确认拓扑：J9701 与 J9702 为同一路 CAN-A 的带电/不带电两个出口，J9703 为独立 CAN-B。尚未确认的是 CANH/CANL 顺序、CAN-A/CAN-B 分别对应 can0 还是 can1，以及原厂实际波特率。

#### CAN 控制器与外部回环结果

- 当前板上安装 `can-utils 2020.11.0-1`；minimal/jammy 和 desktop/noble 构建配置均加入 `PACKAGE_LIST_ADDITIONAL="can-utils"`，后续新固件默认自带 `candump`、`cansend`、`cangen` 等工具。
- pinmux 实机确认：can0 使用 GPIO0_B7/GPIO0_C0，can1 使用 GPIO4_B2/GPIO4_B3，均被对应控制器正确 claim。
- 500 kbit/s 内部回环：can0 收到 `456#A1A2A3A4`，can1 收到 `654#B1B2B3B4`，两路均保持 ERROR-ACTIVE，证明控制器、驱动和 SocketCAN 路径正常。
- J9702↔J9703 外部回环：同向和交换差分线两种接法下，`can0→can1` 与 `can1→can0` 均超时。2026-08-18 又显式使用 `loopback off` 在 125/250/500/1000 kbit/s 四种常见速率上双向复测，仍全部超时并进入 ERROR-PASSIVE；每轮结束均恢复为 DOWN/STOPPED。
- SocketCAN 的内部自环标志会在接口 DOWN 后保留；外部回环前必须显式执行 `ip link set canX type can bitrate <rate> loopback off`，否则控制器不会驱动物理总线，超时结果无效。
- 原厂 DTB 反编译的 `can@fea50000` / `can@fea60000` 只包含控制器、时钟、复位和 pinctrl，没有 CAN PHY、`standby-gpios` 或 `enable-gpios` 描述；因此暂时不能通过设备树直接解锁 97xx 区域的收发器。
- 因此不能仅凭“两路控制器 + 两个 CAN 物理座”就断言一一对应。剩余可能包括 97xx 区域收发器的 standby/silent 使能未打开、物理座接到板载 MCU/不同 CAN 域，或还存在未识别的收发路径。下一步应做受控发送波形定位，而不是继续盲目交换线序。

### J9701 误短接记录（2026-08-18）

测量中曾瞬时短接 J9701 的 3 脚 GND 与 4 脚 +12V。事后板卡仍在线、未重启，根文件系统保持可写，eth0 正常，内核日志未见欠压、brownout、稳压器故障或热关机。该结果只说明当时未观察到即时故障，不能证明接口无损；应复查插座和线材是否变色、异味或发热，确认电源限流/保险状态，并重新确认 4 脚仍约为 12V。严禁再次短接。

在这些现场项目完成前，准确结论是“当前已连接硬件与核心驱动无 FAIL”，而不是
“所有外部接口均已通过”。
