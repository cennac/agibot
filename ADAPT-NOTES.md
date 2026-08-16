# AGIBOT MB0002 V2 DTB 5.10 → 6.1 适配说明

## 适配方法
基于原厂 5.10 BSP dtb(fdt.dtb),用 fdtput 修改 7 处 compatible,
其余硬件定义(电源/时钟/DDR/PMIC)保持原厂准确。

## 改动清单
| 节点 | 5.10 compatible | 6.1 compatible | 说明 |
|------|----------------|----------------|------|
| /iommu@fdca0000 | rockchip,iommu-av1 | rockchip,iommu-av1d | AV1视频解码IOMMU,节点已启用 |
| /csi2-dphy0~5 | rockchip,rk3568-csi2-dphy | rockchip,rk3588-csi2-dphy | CSI相机DPHY(节点disabled,接相机时还需补phys引用) |

## 未改动(已验证兼容)
- NPU: rockchip,rk3588-rknpu (5.10/6.1一致)
- GPU: arm,mali-bifrost (5.10/6.1一致;6.1的valhall-csf节点本就disabled)
- 网口: ethernet@fe1b0000 + fe1c0000 (双网口,5.10/6.1地址一致)
- 根节点: rockchip,rk3588-agibot-mb0002-v2\0rockchip,rk3588 (有fallback)

## 验证基准
对比 armbian 官方 6.1 BSP 的 rock-5b dtb(linux-dtb-vendor-rk35xx 6.1.115)
两者 168 个 compatible 中 ~85% 相同,差异点已全部处理。

## 核心板兼容性(备选参考)

AGIBOT 核心板兼容 **Firefly ITX-3588J**(RK3588**J** 工业级,-40~85°C,核心配置同 RK3588)。Armbian 的 `firefly-itx-3588j.csc` 与本板 `agibot.conf` 在 7 个关键字段里**仅 `BOOT_FDT_FILE` 不同**(详见 BUILD-GUIDE §0 选型佐证)。

- **u-boot / loader / 刷机方案通用**:共用 `rock-5b-rk3588_defconfig`,当前 `flash/rk3588_spl_loader_v1.16.113.bin` 对该核心板适用
- **设备树板级专属**:本表的自适配 dtb(`rk3588-agibot-mb0002-v2.dtb`)是正解;但若某节点适配卡壳,内核自带的 `rk3588-firefly-itx-3588j.dtb`(`arch/arm64/boot/dts/rockchip/`)可作为**核心板部分(DDR / PMIC / clock)的有效对照基准**

## USB-A 端口供电

两组 Genesys Hub 的枚举和 GPIO154/155 复位不能单独打开 USB-A VBUS。
原厂 rootfs 还通过 `/home/.qc/USB_Monitor.sh` 将 PCA9555 `3-0020`
的 offset 0..11（旧内核全局 GPIO493..504）设置为输出高，分别使能
HUB1/HUB2/HUB3/HUB20 的端口电源开关。

6.1 镜像使用 `agibot-usb-port-power.service` 在启动时按 GPIO chip label
动态查找 base，再拉高这 12 路。不要把全局 GPIO 编号写死，也不要复制
原厂脚本中 HDMI、音频、雷达和 4G 的无关使能。

实机验证：Kingston `0951:1666` 以 5000 Mbps 枚举为 `/dev/sda`，
SiGma Micro 键盘 `1c4f:0002` 绑定 `usbhid`。

## HDMI 自动分辨率与板载扬声器

- `/display-subsystem` 使用节点级 HDMI PHY provider 作为 `hdmi0_phy_pll`，让
  2560x1440@60 的 VOP pixel clock 精确为 241.5MHz。
- 镜像不再写死 `video=HDMI-A-1:1920x1080@60e`，启动和热插拔按 EDID 选模。
- 删除 `/hdmi@fde80000` 错误的 `enable-gpios=<&gpio4 9 ...>`；GPIO4_B1
  （Linux GPIO137）专用于 I2S1 `SDO0`。
- `/i2s@fe480000` 与 `/acm8625p-sound` 恢复为 `okay`。6.1 内核通过
  `kernel/rk35xx-vendor-6.1/0001-ASoC-add-ACM8625P-amplifier.patch` 加入 codec 驱动。

## 根文件系统扩容

使用 Armbian 自带的 `armbian-resize-filesystem.service`，由它根据 `/` 的挂载源
动态识别磁盘和分区。不要另建写死 `/dev/mmcblk0p2` 的扩容服务：本板 eMMC 根分区
实际为 `/dev/mmcblk0p1`。官方服务实测已将 256GB eMMC 扩展到 99%，并按设计保留
1% 空间用于闪存磨损均衡。
