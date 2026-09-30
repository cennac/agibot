# AGIBOT → OpenHarmony DTS 移植核对单

配套 `openharmony/dts/rk3588-agibot-mb0002-v2.dts`（RFC 草案，未编译）。
基线事实源与证据规则沿用 `android14/docs/06-phase1-dts-port-map.md`。

## 内核基线事实（P0 勘误）

- OPC 的 OpenHarmony-6.0-Release 路线，opi5plus 实际内核是
  **kernel/linux/linux-6.6**（OH 官方 6.6）+ 板级仓 `kernel_patch/0001-add-rk.patch`
  （**Git LFS，实体 104MB**，Rockchip vendor 层）+ 板级 dts/defconfig。
- manifest 里的 `linux_5.10_opi`（5.10.160）在 6.0 分支是遗留条目：
  树内 broadcom 目录只有 b43/brcm80211，无 bcmdhd。
- 因此 dts 语法基准 = "OH 6.6 + rk vendor 补丁" 树（与 android14 的 vendor 6.1 同族），
  **不是** 5.10。

## LFS 拉取后必须逐项验证（编译前 gate）

| # | 检查 | 期望 |
|---|---|---|
| V1 | `device/board/opc` git lfs pull 后 `0001-add-rk.patch` 字节数 | ≈104,336,293（非 134B 指针） |
| V2 | rk vendor 补丁内的 `bcmdhd` 驱动与 `wlan-platdata`/`bluetooth-platdata` 绑定存在 | grep 补丁文件 |
| V3 | 内核树 dtsi：`rk3588.dtsi`、`rk3588-rk806-single.dtsi`、`rk3588-linux.dtsi` 由 vendor 补丁提供 | include 可解析 |
| V4 | `rk3588-linux.dtsi` 的 chosen/console 内容（是否已带 earlycon/console，agibot dts 的 chosen 是否与之冲突） | 决定 bootargs 保留或去掉 ttyFIQ0 |
| V5 | 标签存在性：`vdd_cpu_lit_s0`/`vdd_log_s0`/`vcc_1v8_s0`（rk806-single 提供）、`gmac0_clkinout`/`gmac1_clkinout`、`uart2m0_xfer`、`i2c0m2_xfer`/`i2c1m2_xfer`/`i2c3m4_xfer`/`i2c6m0_xfer`、`uart6m1_rtsn` | dtc 编译即验 |
| V6 | `orangepi5plus_oh_defconfig` 中 BCMDHD/BRCM 配置项照搬到 `agibot_oh_defconfig` | 已有 9 处命中 |

## 与 android14 (vendor 6.1) dts 的差异清单

1. include：去掉 `rk3588-android.dtsi`，改为 `rk3588-linux.dtsi`（OH 惯例，见 opi5plus）。
2. 显式使能 `&uart2`（console，M02 要求）；6.1 版靠 android dtsi 隐含。
3. 媒体引擎（rkvdec/rkvenc/rga/jpege…）首批全部不显式使能——OH 首启目标是
   ArkUI 桌面（GPU+VOP+HDMI 足够），按 M11 纪律一次一个子系统恢复。
4. `agibot_usb_hub_reset` 节点暂不写（驱动未移植；代价是 Genesys hub 下的 USB
   设备可能不枚举，P1.5 移植 `agibot-hub-reset.c` + PCA9555 上电时序后恢复）。
5. ACM8625P 音频节点暂不写（codec 驱动移植目标改为 6.6 ASoC，参考 LEDE 树内
   mainline 版实现，P2）。
6. `rknpu` 暂不使能（RKNN on OH 未验证；vdd_npu 轨先保留定义）。

## AP6275P 固件来源（P1 落盘到 board/agibot/firmware/）

| 文件 | 来源 |
|---|---|
| `fw_bcm43752a2_pcie_ag.bin` | **仓库内 `overlay/lib/firmware/ap6275p/`**（Armbian 路线已验证在用） |
| `nvram_AP6275P.txt` | 同上（vendid=0x14e4 devid=0x449d） |
| `BCM4362A2.hcd` + `clm_bcm43752a2_pcie_ag.blob` | 同上；BT attach 走 uart6（ttyS6），注意 doc 58：原厂镜像用 ttyS9 是错误配置 |

## P1 板级层落盘清单（device/board/opc/agibot + vendor/opc/agibot）

- 拷贝 `opi5plus/` 为模板，改 `DEVICE_NAME=agibot`、`DEFCONFIG_FILE=agibot_oh_defconfig`
- `kernel/dts/` 换成本 dts；`kernel/configs/` 以 orangepi5plus_oh_defconfig 为底本
- `firmware/` 放 AP6275P 三件套；`loader/`（idbloader/uboot）复用仓库 `flash/` 的 AGIBOT SPL
- `vendor/opc/agibot/config.json`：product_name=agibot，wifi 配置抄 opi5plus
  （`wifi_feature_non_hdf_driver = true`）
- 分区表（image_conf）按 agibot eMMC 容量核对
