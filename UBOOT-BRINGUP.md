# AGIBOT MB0002 V2 U-Boot bring-up

## 结论

AGIBOT 不能继续直接使用 `rock-5b-rk3588_defconfig`。实机日志证明旧镜像能完成
DDR 和 BL31，但在 BL31 跳转 BL33 (`0x00200000`) 后没有可见 U-Boot 输出。
旧配置同时启用了 `CONFIG_DISABLE_CONSOLE=y`，掩盖了 U-Boot 阶段的故障。

当前构建改为：

- `BOOTCONFIG=agibot-rk3588_defconfig`
- U-Boot DTB: `rk3588-agibot-mb0002-v2.dtb`
- UART: UART2 M0, `0xfeb50000`, 1500000 baud
- eMMC: `0xfe2e0000`, 8-bit, HS400, enhanced strobe
- 启动等待: 3 秒，控制台保持开启

## 原厂依据

节点来自原厂 `RK3588-backup/dev-resources/boot/fdt.dtb` 的反编译结果。原文件
SHA-256 为 `511E6A45561056D3FF7B1B7C2868F351FEDDDF48D1CFFFCB390AA525FAB66C42`：

| 功能 | 原厂定义 | U-Boot 处理 |
|---|---|---|
| 调试串口 | FIQ debugger `serial-id = 2`, UART2 M0 | 明确选择 `uart2m0_xfer` |
| eMMC | `mmc@fe2e0000`, 8-bit HS400 ES | 在 `&sdhci` 中保持相同能力 |
| 主输入 | 12 V always-on | `vcc12v_dcin` |
| 系统电源 | 5 V always-on, 由 12 V 输入 | `vcc5v0_sys` |
| PMIC | SPI2 上单颗 RK806 | 不在最小 U-Boot DTS 重复编程，由 preloader 初始化 |

U-Boot DTS 有意只保留启动必需节点。完整外设继续由 Linux 的
`rk3588-agibot-mb0002-v2.dtb` 描述。

## CPU 信息显示策略

当前保持：

```text
# CONFIG_DISPLAY_CPUINFO is not set
```

这不是 AGIBOT 配置遗漏。Radxa vendor RK3588 U-Boot 的 Rock 5B、Rock 5 ITX
及多个 ArmSoM defconfig 同样关闭了该选项。开启 `CONFIG_DISPLAY_CPUINFO=y`
后，`common/board_f.c` 会在早期 `init_sequence_f` 中调用 `print_cpuinfo()`；
该 RK3588 代码路径没有实现这个函数，因此构建会链接失败：

```text
undefined reference to `print_cpuinfo'
```

该选项只控制 U-Boot 启动日志中的 CPU 信息，不负责 CPU 初始化、调频或 Linux
启动。当前已有 U-Boot 版本、Model、DRAM 和 MMC 等输出，所以它不是 bring-up
的必要条件。尤其不应在早期阶段为了显示频率或芯片分档而依赖 OTP、clock、
SCMI 或 Driver Model，这些子系统此时可能尚未完成初始化。

待专用 U-Boot 在实机上稳定启动后，可用独立补丁增加无外设依赖的最小
`print_cpuinfo()`：只读取 `MIDR_EL1`，显示 ARM implementer、part、variant 和
revision，并标识 RK3588 的 Cortex-A55/Cortex-A76 CPU 拓扑。不要在该函数中
读取 OTP、温度、实时频率或芯片 binning。实现后必须重新做 ARM64 交叉编译和
实机启动验证，再启用 `CONFIG_DISPLAY_CPUINFO=y`。

## 构建接线

`setup.sh` 将仓库的 `u-boot/` 复制到 `armbian-build/userpatches/u-boot/`。
补丁位于：

```text
u-boot/legacy/u-boot-radxa-rk35xx-v2024.10/board_agibot/
```

Armbian 会先应用 RK3588 family 补丁，再应用 `board_agibot` 补丁，加入专用
DTS 和 defconfig。

## 分阶段验收

首次测试只验证新启动链，不要把“编译成功”视为实机启动成功。

1. 保留已验证的原厂完整恢复文件。
2. 编译新的 `BOARD=agibot BRANCH=vendor` 镜像。
3. 运行 `python flash/gen-armbian-cfg.py --img <新镜像>`，必须通过板型检查。
4. 先记录新镜像前 16 MiB 的 SHA-256。
5. 刷入后用 COM5、1500000 8N1 验收。

第一阶段必须看到：

```text
U-Boot 2017.09
Model: AGIBOT MB0002 V2
```

随后确认：

```text
mmc 0
ext4ls mmc 0:1 /boot
```

只有 U-Boot 能稳定访问 eMMC 和 rootfs 后，才继续验证 Linux DTB、网络、USB、
HDMI 和其他外设。

## 回滚

若仍停在 BL31 或 U-Boot 无法访问 eMMC，进入 MASKROM 后按
`RK3588-backup/06-image/FINAL-RECOVERY-GUIDE-2026-08-13.md` 完整恢复。
不要把旧 Rock 5B 镜像重新写入 LBA0。
