# Armbian 内置硬件诊断工具方案(2026-08-28)

## 背景

几天实机调试暴露出一个模式:内核和固件链路已经能工作,但最小镜像缺少现场
排查命令,导致每次测试都要先拷工具或临时改脚本。例如:

- `wlan0` 能扫描和联网,但没有 `iperf3` 做吞吐对比。
- `hci0` 能由 `agibot-bt-attach` 挂出,但最小镜像没有 BlueZ 用户态。
- I2C 设备节点存在,但没有 `i2cdetect`。
- PCIe 端点能绑定驱动,但没有 `lspci`。
- 摄像头节点存在,但没有 `v4l2-ctl` 查看格式和采集。
- 回归脚本的 stress 分支因缺 `stress-ng` 只能降级为临时 hash 压测。

同时发现一个构建配置错误:顶层配置里的
`PACKAGE_LIST_ADDITIONAL="can-utils"` 在当前 Armbian 构建框架中是废弃变量,
没有安装进镜像。板级包必须写在 `config/boards/agibot.conf` 的
`PACKAGE_LIST_BOARD`。

## 内置包清单

```text
alsa-utils bluez can-utils device-tree-compiler edid-decode i2c-tools
iperf3 libdrm-tests lm-sensors mmc-utils nvme-cli pciutils rfkill
stress-ng usbutils v4l-utils
```

| 包 | 主要命令/用途 |
|---|---|
| `alsa-utils` | `amixer`、`aplay`、`speaker-test`,音频链路检查 |
| `bluez` | `hciconfig`、`hcitool`、`bluetoothctl`,蓝牙用户态 |
| `can-utils` | `candump`、`cansend`、`cangen`,CAN 收发验证 |
| `device-tree-compiler` | `fdtget`、`fdtput`、`dtc`,运行时 DT 排查 |
| `edid-decode` | HDMI/DP EDID 解析 |
| `i2c-tools` | `i2cdetect`、`i2cget`、`i2cset`,I2C/传感器/PMIC 排查 |
| `iperf3` | 有线/WiFi 吞吐测试 |
| `libdrm-tests` | `modetest`,DRM/KMS 连接器和模式检查 |
| `lm-sensors` | `sensors`,统一温度/电压读数 |
| `mmc-utils` | `mmc`,eMMC/extcsd 信息 |
| `nvme-cli` | `nvme`,M.2 设备与健康状态 |
| `pciutils` | `lspci`,WiFi/NVMe/USB PCIe 端点排查 |
| `rfkill` | 无线/蓝牙硬阻塞排查 |
| `stress-ng` | CPU/内存/IO 压力测试 |
| `usbutils` | `lsusb`,USB 枚举排查 |
| `v4l-utils` | `v4l2-ctl`,UVC 格式、帧率、采集测试 |

这些包在 Jammy 源中均存在。它们会同时作用于 minimal 和 desktop 构建;
desktop 使用的 Noble 源包名相同,后续构建仍需通过离线镜像检查复核。

## 刻意不默认内置

- `network-manager`:当前 minimal 使用 systemd-networkd/Netplan,引入第二个
  网络管理器容易造成回归。
- `tcpdump`、`nmap`:安全敏感且体积较大,需要时再安装。
- `fio`、`sysbench`、`glmark2-es2`:偏重基准测试,不适合作为默认诊断集。

## 验证要求

每次新镜像构建后,`scripts/verify-image.sh` 必须检查上述包已安装,上板后
直接运行内置回归命令:

```sh
agibot-test --scan --net --stress
```

本文件先记录方案与配置修正;对应镜像尚未重新构建,不能把 `df777c1e`
旧镜像的测试结果等效为新包清单的验证结果。
