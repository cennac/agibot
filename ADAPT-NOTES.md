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
