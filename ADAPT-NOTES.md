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
