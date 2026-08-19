# AGIBOT MB0002 V2 3D 接口地图

本地交互式 3D 板卡接口标注。资料来源包括：

- `../RK3588-backup/dev-resources/boot/fdt.dtb`
- `../RK3588-backup/dev-resources/README-dev.md`
- `../图/` 实拍照片与用户提供的补充图片
- `../agibot.dts` 与 `../AGIBOT-原厂程序分析.md`、`../AGIBOT-引脚与架构深度分析.md`
- 2026-08-11 对 `192.168.88.101` 的只读实机核对
- 2026-08-12 对 J9200 进行 HUB + U 盘逐口插拔核对：物理口确认为 USB 主机口，设备链路为 `fc800000.usb/usb1/1-1/1-1.3/1-1.3.4`
- 用户确认的 J2600、J9304 与 J2000 接线信息
- 可切换照片贴图与无贴图纯 3D 模型，纯 3D 模式包含主要接口、散热器、风扇、CN9800 与 J8600 M.2 体块
- 3D 热点与板面标签直接显示已验证速率：J9200 为 `USB 2.0 / 480 Mbps`，J3300–J3600 为 `USB 3.0 / 5 Gbps`
- 纯 3D 位置以 `../图/IMG_20260811_130702.jpg` 裸板正俯视图为统一基准；经板框透视校正，并用 USB-A、USB-C 标准外壳宽度交叉换算，板框暂估为 `190 × 110 mm`（约 `1.73:1`）
- J3300–J3600 与相邻五个镀金孔按照片逐点定位；J2500、J8900、J8901 和六按键阵列按实际行列重建；J8901 位于板边外侧，J8900 位于内侧
- 线束座显示可见针脚数量，J2000 三针座在模型中标出 `- / + / X`；未知线束仍不推测具体信号
- `IMG_20260812_114650.jpg` 确认主电源区域的器件顺序为 J7001、J7000、J9703、J9702、J2000。J9703/J9702 是两个上下相邻的 `1×3` 排针，组合外观为 `2×3`；紧靠 J7000 白色座的上排为 J9703，下排为 J9702。2026-08-18 电压、通断和终端电阻实测只确认两组带约 120Ω 终端的差分网络；原厂 DT 和机器人 `canclient` 支持 CAN 假设，但外部回环失败，协议尚未定案
- 两个白色扬声器座已拆分：靠 J2000 主电源的一只为 J7000，另一只为 J7001；两者均为 BTL 输出，左右声道和正负针序仍待确认
- 开发资源未包含板框机械毫米尺寸；`190 × 110 mm` 是照片测算值，最终机械尺寸仍应以卡尺实测或板框 DXF/STEP 为准

直接使用（无需安装 Node.js 或编译）：

```text
双击 dist/index.html
```

`dist/` 是刻意提交到 Git 的便携版成品，资源使用相对路径，支持从 `file://` 直接打开。

开发运行：

```powershell
npm.cmd run dev
```

重新生成便携版：

```powershell
npm.cmd install
npm.cmd run build
```

标为“待确认”的线束座没有足够证据支持逐针定义，不应直接接线或上电。

## J9200 USB 实测

- 首轮外接 HUB：`05e3:0610 Genesys USB2.0 Hub`，sysfs `1-1.3`，协商 `480 Mbit/s`
- 首轮 U 盘：`abcd:1234 General UDisk`，sysfs `1-1.3.4`，协商 `480 Mbit/s`
- 复测 USB 3 HUB：同一只 Genesys 双总线 HUB 在 J3300–J3600 可枚举 `05e3:0612 / 5000 Mbit/s`；插到 J9200 后只出现 `05e3:0610`、sysfs `1-1.3`、`480 Mbit/s`
- 复测 USB 3 U 盘：Kingston DataTraveler 3.0 `0951:1666`，sysfs `1-1.3.1`，协商 `480 Mbit/s`，块设备 `/dev/sda`，序列号 `E0D55EA573CE1671187A10D3`
- 板载上游 HUB：`05e3:0610 Genesys USB2.1 Hub`，sysfs `1-1`
- 主控制器：`/sys/devices/platform/fc800000.usb`，Linux 驱动 `ehci-platform`
- 设备树：`usb@fc800000`，`compatible = "rockchip,rk3588-ehci", "generic-ehci"`，`status = "okay"`，只引用 `usb2-phy`

因此，J9200 的数据功能可确认是 USB 2.0 High-Speed 主机路径，控制器与实际协商上限均为 `480 Mbit/s`。使用已在其他四个 Type-C 口验证为 USB 3.0 的同一套 HUB、U 盘和线材复测后，J9200 仍没有出现 SuperSpeed 枚举。Type-C 的 CC、PD、SBU 和供电能力仍不能仅凭数据枚举下结论。

## J3300 USB 实测

- USB 3 路径：外接 Genesys HUB `05e3:0612` 位于 `6-1`，Kingston DataTraveler 3.0 `0951:1666` 位于 `6-1.1`；两者均协商 `5000 Mbit/s`
- USB 2 伴随路径：板载 VIA HUB `2109:3431` 位于 `5-1`，外接 Genesys HUB `05e3:0610` 位于 `5-1.1`，均为 `480 Mbit/s`
- U 盘块设备：`/dev/sda`，序列号 `E0D55EA573CE1671187A10D3`
- 控制器：PCI `0004:41:00.0`，VIA VL805 `1106:3483`，驱动 `xhci_hcd`
- SoC 上游设备树：`pcie@fe190000`，`status = "okay"`，该节点承载 VL805 PCIe 控制器

因此 J3300 已确认具备 USB 3.0 / SuperSpeed Gen 1 数据能力，本次总线协商速率为 `5000 Mbit/s`。

## J3400 USB 实测

- USB 3 路径：外接 Genesys HUB `05e3:0612` 位于 `6-2`，Kingston DataTraveler 3.0 `0951:1666` 位于 `6-2.1`；两者均协商 `5000 Mbit/s`
- USB 2 伴随路径：板载 VIA HUB `2109:3431` 位于 `5-1`，外接 Genesys HUB `05e3:0610` 位于 `5-1.2`，均为 `480 Mbit/s`
- U 盘块设备：`/dev/sda`，序列号 `E0D55EA573CE1671187A10D3`
- 控制器仍为 PCI `0004:41:00.0` 的 VIA VL805 `1106:3483`，驱动 `xhci_hcd`

J3400 对应 VL805 的第 2 个下行端口；与 J3300 的第 1 个下行端口相互独立。本次确认 J3400 具备 USB 3.0 / SuperSpeed Gen 1 数据能力。

## J3500 USB 实测

- USB 3 路径：外接 Genesys HUB `05e3:0612` 位于 `6-3`，Kingston DataTraveler 3.0 `0951:1666` 位于 `6-3.1`；两者均协商 `5000 Mbit/s`
- USB 2 伴随路径：板载 VIA HUB `2109:3431` 位于 `5-1`，外接 Genesys HUB `05e3:0610` 位于 `5-1.3`，均为 `480 Mbit/s`
- U 盘块设备：`/dev/sda`，序列号 `E0D55EA573CE1671187A10D3`
- 控制器仍为 PCI `0004:41:00.0` 的 VIA VL805 `1106:3483`，驱动 `xhci_hcd`

J3500 对应 VL805 的第 3 个下行端口。本次确认 J3300、J3400、J3500 与 VL805 端口 1、2、3 按物理顺序一一对应。

## J3600 USB 实测

- USB 3 路径：外接 Genesys HUB `05e3:0612` 位于 `6-4`，Kingston DataTraveler 3.0 `0951:1666` 位于 `6-4.1`；两者均协商 `5000 Mbit/s`
- USB 2 伴随路径：板载 VIA HUB `2109:3431` 位于 `5-1`，外接 Genesys HUB `05e3:0610` 位于 `5-1.4`，均为 `480 Mbit/s`
- U 盘块设备：`/dev/sda`，序列号 `E0D55EA573CE1671187A10D3`
- 控制器仍为 PCI `0004:41:00.0` 的 VIA VL805 `1106:3483`，驱动 `xhci_hcd`

J3600 对应 VL805 的第 4 个下行端口。至此底边四个 USB-C 已完整确认：`J3300 → Port 1`、`J3400 → Port 2`、`J3500 → Port 3`、`J3600 → Port 4`，四口均具备 USB 3.0 / SuperSpeed Gen 1 数据能力。

## USB3000 USB-A 实测

- 物理位置：HDMI J5000 旁的单层蓝色 USB-A
- Kingston DataTraveler 3.0 `0951:1666`：sysfs `8-1.2`，协商 `5000 Mbit/s`，块设备 `/dev/sda`，序列号 `E0D55EA573CE1671187A10D3`
- 板载上游 HUB：Genesys USB3.2 Hub `05e3:0620`，sysfs `8-1`，协商 `5000 Mbit/s`
- 主控制器：`/sys/devices/platform/usbhost3_0/fcd00000.usb`，驱动 `xhci-hcd`
- 设备树：`usbhost3_0/usb@fcd00000`，`dr_mode = "host"`，`status = "okay"`，使用 `usb3-phy`

USB3000 已确认具备 USB 3.0 / SuperSpeed Gen 1 数据能力，本次协商速率为 `5000 Mbit/s`。该口不经过底边四个 Type-C 使用的 VIA VL805；右侧双层 USB-A 按物理上下层继续逐口测试。

## J3000 下层 USB-A 实测

- 物理位置：J9200 旁第一组双层蓝色 USB-A，丝印 `J3000`，本次测试下层口
- Kingston DataTraveler 3.0 `0951:1666`：sysfs `8-1.4`，协商 `5000 Mbit/s`，块设备 `/dev/sda`，序列号 `E0D55EA573CE1671187A10D3`
- 板载上游 HUB：Genesys USB3.2 Hub `05e3:0620`，sysfs `8-1`，协商 `5000 Mbit/s`
- 主控制器：`/sys/devices/platform/usbhost3_0/fcd00000.usb`，驱动 `xhci-hcd`

J3000 下层口已确认具备 USB 3.0 / SuperSpeed Gen 1 数据能力。

## J3000 上层 USB-A 实测

- 物理位置：J9200 旁第一组双层蓝色 USB-A，丝印 `J3000`，本次测试上层口
- Kingston DataTraveler 3.0 `0951:1666`：sysfs `8-1.1`，协商 `5000 Mbit/s`，块设备 `/dev/sda`，序列号 `E0D55EA573CE1671187A10D3`
- 板载上游 HUB：Genesys USB3.2 Hub `05e3:0620`，sysfs `8-1`
- 主控制器：`/sys/devices/platform/usbhost3_0/fcd00000.usb`，驱动 `xhci-hcd`

J3000 双层座已完整确认：上层为 `8-1.1`，下层为 `8-1.4`，两口均为 USB 3.0 / SuperSpeed Gen 1 `5000 Mbit/s`。

## J2900 上层 USB-A 实测

- 物理位置：J3000 旁第二组双层蓝色 USB-A，丝印 `J2900`，本次测试上层口
- Kingston DataTraveler 3.0 `0951:1666`：sysfs `10-1.1`，协商 `5000 Mbit/s`，块设备 `/dev/sda`
- 板载上游 HUB：Genesys USB3.2 Hub `05e3:0620`，sysfs `10-1`
- 主控制器：`/sys/devices/platform/usbdrd3_1/fc400000.usb`，驱动 `xhci-hcd`
- 设备树：`usbdrd3_1/usb@fc400000`，`dr_mode = "host"`，`status = "okay"`

J2900 上层口已确认具备 USB 3.0 / SuperSpeed Gen 1 `5000 Mbit/s`。它使用 `fc400000.usb`，与 J3000 上下层使用的 `fcd00000.usb` 不同。

## J2900 下层 USB-A 实测

- 物理位置：J3000 旁第二组双层蓝色 USB-A，丝印 `J2900`，本次测试下层口
- Kingston DataTraveler 3.0 `0951:1666`：sysfs `10-1.4`，协商 `5000 Mbit/s`，序列号 `E0D55EA573CE1671187A10D3`
- 板载上游 HUB：Genesys USB3.2 Hub `05e3:0620`，sysfs `10-1`
- 主控制器：`/sys/devices/platform/usbdrd3_1/fc400000.usb`，驱动 `xhci-hcd`
- 设备树：`usbdrd3_1/usb@fc400000`，`dr_mode = "host"`，`status = "okay"`

J2900 双层座已完整确认：上层为 `10-1.1`，下层为 `10-1.4`，两口均为 USB 3.0 / SuperSpeed Gen 1 `5000 Mbit/s`。

## J2901 下层 USB-A 实测

- 物理位置：J2900 旁最右侧双层蓝色 USB-A，丝印 `J2901`，本次测试下层口
- Kingston DataTraveler 3.0 `0951:1666`：sysfs `10-1.2`，协商 `5000 Mbit/s`，序列号 `E0D55EA573CE1671187A10D3`
- 板载上游 HUB：Genesys USB3.2 Hub `05e3:0620`，sysfs `10-1`
- 主控制器：`/sys/devices/platform/usbdrd3_1/fc400000.usb`，驱动 `xhci-hcd`
- 设备树：`usbdrd3_1/usb@fc400000`，`dr_mode = "host"`，`status = "okay"`

J2901 下层口已确认具备 USB 3.0 / SuperSpeed Gen 1 `5000 Mbit/s`，对应 Hub Port 2。

## J2901 上层 USB-A 实测

- 物理位置：J2900 旁最右侧双层蓝色 USB-A，丝印 `J2901`，本次测试上层口
- Kingston DataTraveler 3.0 `0951:1666`：sysfs `10-1.3`，协商 `5000 Mbit/s`，序列号 `E0D55EA573CE1671187A10D3`
- 板载上游 HUB：Genesys USB3.2 Hub `05e3:0620`，sysfs `10-1`
- 主控制器：`/sys/devices/platform/usbdrd3_1/fc400000.usb`，驱动 `xhci-hcd`
- 设备树：`usbdrd3_1/usb@fc400000`，`dr_mode = "host"`，`status = "okay"`

J2901 双层座已完整确认：下层为 `10-1.2`，上层为 `10-1.3`，两口均为 USB 3.0 / SuperSpeed Gen 1 `5000 Mbit/s`。至此，三组双层 USB-A 的六个物理端口均已完成逐口实测。

## 后续 USB 逐口测试

每个接口尽量使用同一套 HUB、U 盘和线材；如更换设备，必须同时记录 VID:PID 和序列号。本轮已使用过 `2401231003040431846631` 与 `E0D55EA573CE1671187A10D3` 两只 U 盘。插入后依次保存：

```sh
lsusb -t
lsusb
cat /sys/bus/usb/devices/*/{busnum,devpath,speed,idVendor,idProduct,product} 2>/dev/null
readlink -f /sys/class/block/sda/device
dmesg | grep -iE 'usb|xhci|ehci|uas|storage' | tail -n 80
```

记录“物理接口 → Bus-Port → 控制器父节点 → HUB 速率 → U 盘速率”。USB 3.x HUB 通常同时枚举 USB 2.0 与 SuperSpeed 两条路径，不能只看 HUB 名称，也不能把 `480/5000 Mbit/s` 直接当成文件读写速度。

## 设备树 + 实机补全的端口

> 2026-08-12 在 `192.168.88.101` 上以 `lsusb -t` / `lspci` / `ip -br link` / `ls /sys/class/udc` / `dmesg` 实测，并与 `../agibot.dts`（`fdt.dtb` 反编译）的节点 `status` 交叉。补全上文 USB 逐口实测之外、软件可枚举的全部端口。

### USB 主控制器（共 5 个启用，补全控制器→物理口映射）

| 控制器（dts） | sysfs 总线 | 已测物理口 | 实测状态 |
|---|---|---|---|
| `fc800000` EHCI + `fc840000` OHCI（USB2 host2） | Bus 01 / 03 | **J9200**（Type-C，480M） | ✓ 挂 Genesys 4 口 HUB |
| `fc880000` EHCI + `fc8c0000` OHCI（USB2 host1） | Bus 02 / 04 | **尚未完成物理映射；J2500 候选** | ⚠️ 已启用、当前空载；空排针不会枚举设备 |
| `fcd00000` dwc3（usbhost3_0，host） | Bus 08（USB3）/ 09（USB2） | USB3000 + J3000 上/下 | ✓ Genesys `05e3:0620` |
| `fc400000` dwc3（usbdrd3_1，host） | Bus 10（USB3）/ 07（USB2） | J2900 上/下 + J2901 上/下 | ✓ |
| VL805（PCIe `fe190000`） | Bus 06（USB3）/ 05（USB2） | J3300 / J3400 / J3500 / J3600 | ✓ |
| `fc000000` dwc3（usbdrd3_0，**OTG**） | `/sys/class/udc/fc000000.usb` | **未测（非 host）** | 🆕 **gadget / 设备模式**（`rockchip` configfs，板子作为 USB 设备一侧，即 USB adb 那条路径） |

即：除上文 10 个 host 口外，板子另有①一个当前空载的 USB2 host（`fc880000`，可能接 J2500 或内部 Hub）；②一个设备模式的 OTG 口（`fc000000`，跑 adb gadget）。

### PCIe（3 条启用，其中一条 4×Gen3 空着可扩展）

| PCIe（dts） | 通道 / 速率 | status | 实测设备 |
|---|---|---|---|
| `fe150000` | **4× Gen3** | okay | ⚠️ **空**（`lspci` 无设备）→ 未占用的 **M.2 M-key 4 通道 Gen3 插槽**（对应 J8600 / CN9800 体块），可上 NVMe SSD 或 AI 加速卡 |
| `fe160000` | 2× Gen3 | disabled | — |
| `fe170000` | 1× Gen2 | okay | ✅ **Broadcom 449d**（WiFi 6E） |
| `fe180000` | 1× Gen2 | disabled | — |
| `fe190000` | 1× Gen2 | okay | ✅ VIA **VL805**（4×USB3，即 J3300–J3600） |

当前存储为 eMMC（`mmcblk0` 233G，2026-08-19 512MiB 顺序读约 325MiB/s），无 NVMe。

### 以太网（2 个口）

| GMAC 控制器（dts） | Linux 接口 | 物理位置 | phy-mode / status | 实测 |
|---|---|---|---|---|
| `fe1b0000` | `eth1` | 靠 HDMI | rgmii-rxid / okay | 2026-08-19：DHCP `192.168.88.88`，RTL8211F 千兆全双工，20 次 ping 0 丢包，RX/TX 错误计数为 0 |
| `fe1c0000` | `eth0` | 靠板边（左数第一个） | rgmii-rxid / okay | 2026-08-19：DHCP `192.168.88.89`，RTL8211F 千兆全双工，carrier=1，RX/TX errors 与 dropped 均为 0 |

物理映射由 2026-08-19 现场换线确认。设备树中的 gmac0/gmac1 名称与 Linux 的 eth0/eth1 枚举次序不能直接等同，排障时应以控制器地址和物理位置为准。

### CAN 控制器（2 路启用，物理接口尚未映射）

`rockchip_canfd` 在 `fea50000 / fea60000` 注册 **can0 / can1**，内部回环已通过。机器人软件确实通过 CAN 与下位机通信，但这不能证明 J970x 就是对应物理口；其协议和控制器映射仍需 U970x 丝印或示波器波形定案。

2026-08-19 原版系统复测：J9702↔J9703 外部回环在 125/250/500/1000 kbit/s、两种极性下均失败。受控发送加万用表仅观察到 `can0→J9703` 出现约 `-0.03V↔0.01V` 的微弱差分变化；`can0→J9702`、`can1→J9702`、`can1→J9703` 均未见可见变化。因此只能记为 `can0` 疑似对应 J9703，不能当作已确认映射。

U9700/U9701 顶面被三防漆覆盖，无法读取丝印；最终确认仍需示波器或 USB-CAN 分析仪。

### 无线

PCIe `fe170000` 上的 **Broadcom 449d**（WiFi 6E）当前枚举 `wlan0`；2026-08-19 临时拉起扫描到 9 个 BSS，测试后已恢复 DOWN。UART 侧 `hci0` 已加载 BCM4362A2 patch。

### SATA：未启用

`sata@fe210000 / fe220000 / fe230000` 在设备树中**全部 `status = "disabled"`**，实机无 `ata_port`、无 AHCI 模块、无 SATA 盘。combphy 已分配给 PCIe / USB3，板子不走 SATA。

### 其它（dts 已有，上文或引脚文档已覆盖）

- 显示：`hdmi0` fde80000、`hdmi1` fdea0000、`edp0/1`、`dp0/1`
- UART：`serial0` fd890000（debug）+ `serial1`–`serial9`（feb40000–febc0000），共 10 路

### 端口全貌速查

| 类别 | 数量 / 情况 | 来源 |
|---|---|---|
| USB host 口 | 10 个已逐口实测（J9200 + 4×Type-C + 6×USB-A） | 上文 USB 实测 |
| USB host 控制器（当前空载） | `fc880000`（Bus 02 空），J2500 候选上游 | dts + 实机；待插设备映射 |
| USB OTG / device | `fc000000`（adb gadget 设备口） | 实机 UDC |
| PCIe | 3 条启用：VL805 / Broadcom WiFi / **空 4×Gen3 M.2 槽** | lspci |
| 以太网 | **2 口**；2026-08-19 eth1 DHCP/千兆/0 丢包，eth0 空载 | ip + dts + ethtool |
| CAN 控制器 | **2 路**（can0 / can1） | 内部回环实机；尚未证明对应 J970x |
| WiFi / 蓝牙 | Broadcom 449d（当前 wlan0）+ hci0 | lspci / sysfs / dmesg |
| SATA | 3 节点全 disabled，未用 | dts + 实机 |
| 显示 | HDMI0 已实测；DP0 为 J2600 的休眠 Alt Mode 能力 | dts + 实机；HDMI1/eDP/DSI 未作为板级接口启用 |
| UART | ttyS0/1/3/4/6/7/9 + UART2 调试控制台 | dts + 实机；UART5 引脚冲突不可用 |

### 仍需原理图 / 实测确认（软件枚举够不着）

`J2000` 三针主电源的第三针，以及扬声器 `J7000 / J7001` 的左右声道与正负针序仍需原理图或电气实测。J9701/J9702 的并联关系、J9703 独立性、约 2.5V 共模和约 120Ω 终端均已确认，但这些特征同时符合 CAN 与部分 RS-485 网络；外部 SocketCAN 回环全部失败，因此协议、极性和 can0/can1 对应关系均未定案。J8900/J8901 已由丝印确认：从上到下分别为 `SWDIO/SWCLK/GND` 与 `TX/RX/GND`。2026-08-18 J8901 短接回环进一步确认其为 `UART0 / ttyS0`（TX=`GPIO0_C5`，RX=`GPIO0_C4`）；测试时还收到 `the vol_12v is :11.74V`，说明线路可能并接电压监测控制器，不能长期短接。

### 隐藏硬件与摄像头补测（2026-08-18）

- 原厂 `/etc/rc.local` 会调用 `/home/.qc/USB_Monitor.sh`。PCA9555 `3-0020` 除 12 路 USB VBUS 外，还命名了 `AUDIO`、`PCIE30X4`、`LIDAR`、`4G`；`3-0021` 另有 `HDMI_PWR_EN`。当前只初始化 12 路 USB，实测其余电平为 `0/1/0/0/1`。其中 `PCIE30X4` 的输出代码在原厂脚本中被注释，不能标成原厂默认使能。
  - **2026-08-19 原系统实机定案**：原厂 5.10 启动后的实际 base 为 `3-0021=477`、`3-0020=493`，因此 `gpio490=3-0021.off13=HDMI_PWR_EN`，`gpio493..508=3-0020.off0..15=HUB/AUDIO/PCIE30X4/LIDAR/4G`。原厂现场方向/电平与上段映射一致；先前按假定 probe 顺序进行的反向切分已被实机证伪。
- J2600 的 HUSB311 在 I2C6 `0x4e` 实读标准 ID 为 `2e99:0311`。原厂 DT 定义双数据角色、双电源角色、5V PDO 与 DP Alt Mode；当前为保证 ADB 稳定而禁用 TCPC。
- 新插入的 `1bcf:0b09 SYX-230524-J HD Camera` 位于 J2901 上层的 USB2 伴随路径 `9-1.3`。`/dev/video0` 支持 MJPEG/YUYV 的 640×480、1280×720、1920×1080；V4L2 mmap 连读 30 帧约 20.36 FPS，帧哈希全部不同。`video1` 是辅助元数据节点。
- 2026-08-19 原厂系统同一路径连续采集 60 帧成功并收敛到约 26 FPS；Wi-Fi 扫描 9 个 BSS。原厂 `rkwifibt` 错用 ttyS9，服务虽 active 但没有 hci0，反而证明当前 Armbian 改用本板 UART6/ttyS6 的修复是必要的。
- 原机器人使用四路 USB Berxel iHawk100 深度相机，并兼容 Orbbec/Astra。原厂和当前 DT 的六路 CSI、DSI 父控制器均为 disabled；残留 panel 模板不等于已装 MIPI 屏或相机。
- 完整证据分级和后续测试顺序见 `../docs/HARDWARE-DISCOVERY-20260818.md`。

## 六按键阵列实物确认（2026-08-12）

六个轻触按键为 **2 行 × 3 列**，按照片顶部到底部、从左到右排列：

| 行 | 左 | 中 | 右 |
|---|---|---|---|
| 第一行 | `SW8902` | `SW8901` | `SW8900` |
| 第二行 | `SW9202` | `SW9200`（LOADER） | `SW9201` |

`SW9200` 已由实物操作确认是 LOADER 按键；2026-08-19 原版系统运行态短按还在 `event2` 产生 `KEY_VOLUMEUP`（code 115）的按下/释放事件，约 310 ms。`SW9201` 已由两套系统实测确认是硬复位/重启按键，按下后系统重新启动。

`SW9202` 是 RK805 PMIC 电源键，产生 `KEY_POWER`（code 116）。Armbian 于 2026-08-18 短按后进入 `virtual poweroff`，再次短按完成全新启动。原版系统策略不同：`HandlePowerKey=ignore`，由 triggerhappy 调用 `/usr/bin/power-key.sh`；短按执行 `pm-suspend`，但 AP6275P 的 `dhdpcie_pci_suspend` 返回 -1，挂起失败并恢复；按住超过 3 秒执行完整 systemd `poweroff` 并进入 BL31 `virtual poweroff`，再次短按正常开机。两套系统关机后风扇所在 5V 常供电轨仍保持工作。

同日复测 `SW8902`：在 125 秒内联合监听 COM7、SSH、Linux `event1/event2` 与 SARADC ch0–ch7，短按前后未重启、未关机，SSH 与 boot ID 保持不变，串口接收 0 字节，input 事件计数为 0，也没有与按键同步的干净 ADC 阶跃。2026-08-19 原版系统再次得到 0 个 input 事件；按住它并用 SW9201 复位、继续保持约 10 秒后，系统仍以 `androidboot.mode=normal` 从 eMMC 启动。该结果只能确认已测试的软件与启动阶段不可见，不能据此断定其未连接或没有其他硬件功能。

随后以同一方法复测 `SW8901`：boot ID 前后均为 `6779efa8-8ecb-4145-ba4e-86b508d5526c`，SSH 未断、COM7 接收 0 字节、input 事件计数为 0；ch0–ch5 最大相邻跳变仅 4–32 个 ADC 计数，未发现按键阶跃，ch6/ch7 仍为已知浮空噪声。2026-08-19 原版系统短按和复位启动保持约 10 秒也均为 0 个 input 事件，启动模式保持 normal。当前只能确认已测试路径没有可见事件或电源动作。

同日短按 `SW8900` 后，COM7 立即重新出现 DDR 初始化、SPL、BL31、U-Boot、`Starting kernel` 与 Armbian 登录提示，过程中没有 systemd 关机序列；boot ID 从 `6779efa8-8ecb-4145-ba4e-86b508d5526c` 更新为 `af39a85c-d38b-4cb9-b489-f9a27521e57a`，eth0 随后恢复连接。2026-08-19 原版系统复测也出现 SSH 离线/上线和新 boot ID `7990d6dd-...`，确认它是发行版无关的硬复位/重启键。所有未知功能均不按编号猜测。

2026-08-19 已完成 `SW9201` 复测：轻按后 COM7 立即出现 DDR、SPL、BL31、U-Boot、`Starting kernel` 和登录提示，U-Boot `reboot reason` 为 `(none)`，没有 systemd 关机序列，boot ID 更新且 eth0 恢复；原版系统两次用于启动保持测试时也得到相同行为。确认它是硬复位/重启键。它与 `SW8900` 外部行为一致，但是否同一电气复位网络仍未证明。

### J9301 风扇关机联动结论（2026-08-18）

SW9202 触发 virtual poweroff 后，系统网络和串口均停止，但 J9301 上的两线风扇继续转动。原厂 `agibot.dts` 与当前运行 DT 均无风扇节点，16 路 PWM 全部为 `disabled`；板端也没有 PWM 平台设备、`pwm-fan`、风扇 hwmon 或 cooling device。因此当前固件没有可用于关机联动的风扇控制接口，不能靠增加一条关机脚本可靠解决。

2026-08-19 现场万用表实测风扇电压为 5V（本次记录未区分运行/关机态读数）。下一步应在断电状态追线确认是否存在负载开关/MOSFET 使能脚。若 J9301 直接连接常供电轨，需要增加 GPIO/PMIC 控制的负载开关或 MOSFET；若板上已有使能脚，再将其建模为 DT `gpio-fan`/regulator 或 `pwm-fan`，并配置关机默认关闭。严禁为找风扇控制脚盲目切换未占用 GPIO。

## 未知连接器功能推导(2026-08-17,现场会话沉淀)

> 依据:agibot.dts 使能清单(7 路可用对外 UART、CAN0/1、I2S8 功放、PWM 全禁)、
> 原厂架构分析(执行器由下位机 SCU 控制、4 路 Berxel 相机)、连接器位置邻域、
> 2026-08-17 实测 USB 拓扑(hub B 口3 `8-1.3` 与 hub C 口 1/2/4 无外部连接器对应)。
> **均为推断,针级定义仍需万用表/追线确认。**

| 座子 | 形态/位置 | 推断 | 置信度 |
|---|---|---|---|
| J7000 / J7001 | 白色 2 针 ×2,电源区 | 喇叭输出(ACM8625P 立体声 BTL) | ✅ 已实证 |
| J9400 | 2×5=10 针,右缘主电源上方 | 机器人主线束候选，可能含 UART/差分总线/电源检测 | 中；无针级证据 |
| J7002 | 2×4=8 针,`70xx` 音频区 | 音频/I2S/测试/扩展候选；撤回原“双 USB”判断 | 低 |
| J9701 | 1×4 白座,右上 | 带 +12V 的差分总线 A 候选；前三针与 J9702 逐针直连 | 供电/并联已实测；协议未确认 |
| J9303 | 2 针,双网口与 HDMI 之间 | GND + 高阻未知信号 | 电气已测，用途低置信 |
| J5001 | 2 针,USB3000 与「4G」J9200 之间 | GND + 高阻未知信号 | 电气已测，用途低置信 |
| J9702 | 1×3,喇叭/电源区 | 差分总线 A 候选；2.42V / 2.52V / GND，与 J9701 并联，118.8Ω | 拓扑/终端已实测；CAN/RS-485 未定 |
| J9703 | 1×3,紧靠 J7000 | 独立差分总线 B 候选；2.49V / 2.49V / GND，120.7Ω | 拓扑/终端已实测；CAN/RS-485 未定 |
| J2500 | 2×5 缺 9 脚=9 针,左侧天线座下 | **高度确认为双口 USB 2.0 内置排针**：1/2 针实测 +5V，缺 9 脚防呆，旁有 ED2500 ESD 与成组电阻；3–8 按标准 USB 针序推定，10 脚板级定义待确认 | 用途高；1/2、缺针已实测 |

### 本轮新增拓扑事实(实测)

- **J9200(丝印 4G)= hub C(fc800000 EHCI)口 3**,USB2-only;hub C 口 1/2/4 无外部连接器 → 推断走主线束
- **hub B(fcd00000)口 3(`8-1.3`)为隐藏内部去向**(其余 1/2/4 口被 USB3000/J3000 双层座占满)
- **fc880000 EHCI 当前空载**，不能再定性为未引出；它是 J2500 的候选上游之一
- **J2500 高度符合双口 USB2 内置排针**；可能承接 fc880000 或板载 Hub 的两个未映射下游口，空口不会在 Linux 中枚举，需插设备后按 Bus-Port 定案
- **J970x 只确认是两组终端差分网络**：CAN 假设得到原厂 DT、canclient 与 2.5V 共模支持，但 RS-485 也可有 120Ω 终端，且四档波特率/两种极性的 SocketCAN 外部回环全部失败。先识别 U970x 或看波形，再命名协议
- **uart5 原厂即不可用**:TX/RX 球位(GPIO4_D4/D5)被 gmac PHY 复位实际占用(gmac 后 probe 抢走),原厂"8 串口"实际 7 路可用
- 用户的 USB-C 一体式扩展坞内部芯片会产生幽灵低速 EPIPE 设备,测口时忽略或避开

### 验证方法(下次动手)

1. **万用表分类**:上电测各针电压(5V/3V3/悬空),GND 用通断档对螺丝孔
2. **UART 零风险定位**:只接 GND + 板侧 TX → USB-TTL 的 RX,板上 `echo test > /dev/ttyS1`(逐路),看哪个座出波形
3. **CAN**:接上线束后 `candump can0` + 触发机体动作看报文
4. **J9400/J7002 若有原车线束**:直接追线颜色对针
5. **J9701/J9702/J9703**：优先识别 U970x 收发器丝印；随后让 can0/can1 受控发送并用示波器定位波形，确认 CAN/RS-485、极性及控制器映射。严禁短接 J9701 的 3 脚 GND 与 4 脚 +12V
