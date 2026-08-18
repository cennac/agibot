# Agibot-Armbian for AGIBOT MB0002

Agibot-Armbian 是面向 AGIBOT MB0002 V2（RK3588）机器人主板维护的
Armbian 定制系统。它基于 Armbian Build Framework 和 Rockchip vendor
内核构建，补齐该板的启动、设备树、外设驱动、固件及板端验证工具。

## 发行信息

- 发行者：Agibot-Armbian
- 板卡：AGIBOT MB0002 V2
- 维护者：cennac
- 联系邮箱：cennac@163.com
- 源码：https://github.com/cennac/agibot
- 系统：Ubuntu Jammy minimal / Ubuntu Noble XFCE
- 内核：Rockchip vendor 6.1.115

这是由维护者构建和验证的社区定制镜像，不是 Armbian 官方发布镜像，
也不代表 AGIBOT 厂商官方固件。名称中的 Armbian 表示其构建基础和上游来源。

## 开发历程

### 2026-08-14：构建、启动与恢复链路

- 建立可复现的 WSL2、Docker 和原生 Linux 构建流程，补齐依赖、缓存和补丁装配。
- 创建 AGIBOT 专用板卡配置、U-Boot defconfig、Jammy minimal 和 Noble XFCE 目标。
- 适配 RK3588 vendor 6.1 内核及板级 DTB，使系统从 eMMC 启动到登录界面。
- 验证 Rockchip Loader 模式、SW9200 下载键和整盘镜像刷写恢复流程。
- 建立 LEDE/OpenWrt 并行构建路线及板端非破坏性测试工具。

### 2026-08-15：发行固化与 OpenWrt 增强

- 重编稳定 Armbian 镜像并记录 SHA-256、刷写方法和恢复基线。
- 扩展 LEDE 软件包、LuCI、容器、网络工具和硬件支持。

### 2026-08-16：显示、USB、无线与音频

- 修复 HDMI PHY 时钟依赖、EDID 自动模式、HDMI 登录终端和板载音频拓扑。
- 恢复 USB-A 端口供电，改用 Armbian 官方 rootfs 自动扩容服务。
- 完成 AP6275P（BCM43752）PCIe Wi-Fi 和 UART 蓝牙初始化。
- 加入 ACM8625P 功放驱动，恢复 I2C/I2S 声卡注册和 PCM 播放通路。

### 2026-08-17：板级外设与加速单元

- 启用硬件看门狗，加入 Rockchip MPP、VPU 和 RGA 用户态库并验证硬解码。
- 复刻原厂 USB Hub 复位时序，消除 GPIO 浮空导致的随机枚举问题。
- 恢复 Type-C ADB，同时因 root shell 风险将其保持为默认关闭、按需启用。
- 修复 DMC/DFI，固化 RKNN Runtime、模型和 NPU 测试工具。
- 完成 PCIe、USB、I2C、SPI、UART、CAN、GPIO、GPU、NPU 和音视频驱动审计。

### 2026-08-18：网络、DSP、NPU 与构建收尾

- 通过真实设备枚举确认三路 PCIe：Broadcom Wi-Fi、VIA USB3 控制器和空 Gen3x4 插槽。
- 为 RTL8211F 首次自协商异常加入按需 PHY 自愈，五次连续重启均恢复千兆链路。
- 将 RK3588 GMAC 的旧式 `mac_clk_rx`、`mac_clk_tx`、`clk_mac_speed`
  请求改为可选时钟 API，消除错误级时钟日志且不影响其他 Rockchip SoC。
- 两个 `rgmii-rxid` 网口显式设置 `rx_delay = <0>`，消除属性缺失和
  `0xffffffff` fallback，同时保持 PHY 提供 RX 时延的真实拓扑。
- 加入 ACM8625P 的 90 字节默认 DSP 寄存器表，并同步进入 rootfs 和 initramfs。
- 改进 NPU 首启安装：系统包提供 Python 依赖，本地 ABI 匹配 wheel 提供 RKNNLite；
  成功后只禁用一次性安装服务，NPU 设备继续工作。
- 加入 GitHub 限流 fallback、APT 分流、镜像内容校验和完整会话回归脚本。

## 最终验证基线

- 第一网口：RTL8211F，1000 Mb/s，全双工，收发错误及丢包为 0。
- 网络重启：连续 5 次重启均取得 DHCP 地址并连通网关。
- NPU：RKNN 推理通路正常，最终回归为 142.8 FPS。
- 音频：ACM8625P DSP 文件哈希正确，两个播放 PCM 正常枚举。
- 镜像离线检查：DTB、固件、initramfs、服务和文档全部通过。
- systemd：最终实机检查无 failed unit。

## 日志说明

已经真实修复的日志包括 GMAC 三个旧式时钟请求、`rx_delay` 属性缺失、
`rx_delay=0xffffffff` fallback 和 ACM8625P DSP 固件缺失。

仍可能看到以下 vendor 可选资源探测日志：

- `Looking up phy-supply ... failed`：debug 级属性探测。
- `supply phy not found, using dummy regulator`：PHY 固定供电未在 DT 建模。
- `IRQ eth_lpi not found`：未提供可选 EEE/LPI 独立中断。

没有为消除日志而添加虚假 regulator 或 IRQ。只有取得原理图并确认真实硬件连接后，
才应补充这些设备树资源。

## 常用检查

```bash
ip -br addr
ethtool eth0
aplay -l
python3 /root/npu_test/npu_test.py
systemctl --failed
dmesg -x | grep -iE 'rx_delay|mac_clk|phy-supply|eth_lpi|acm8625|rknpu'
```

仓库中保留了构建说明、刷机方法、硬件验收记录及完整提交历史；遇到问题时，
请同时提供镜像文件名、SHA-256、启动日志和复现步骤，并联系维护者。
