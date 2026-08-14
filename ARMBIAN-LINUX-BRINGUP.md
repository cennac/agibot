# AGIBOT MB0002 V2 — Armbian Linux 层 bring-up + 刷机方法

本文档记录 Armbian 路线从「U-Boot 能启动」到「Linux 完整进入系统」之间踩出的
三个 Linux 层问题及最终修复，并固化「下次打包一次成功」所需的关键改动。U-Boot
层的专用 defconfig/DTS 见 [[UBOOT-BRINGUP.md]]。

## 结论(2026-08-14 实测)

Armbian 镜像已能完整启动进入系统。Linux 层一共有 **三个坑**，其中两个是「vendor
内核 vs armbian 框架默认值不匹配」导致的，一个是我自己在调试中绕的弯路。

| # | 现象 | 根因 | 修复 |
|---|---|---|---|
| 1 | `Starting kernel ...` 后无任何串口输出 | vendor 内核控制台是 **ttyFIQ0**(fiq-debugger 独占 uart2)，不是 armbian 默认的 ttyS2 | DTB 保持 `fiq-debugger=okay` + `uart2=disabled`(原始状态本来就对) |
| 2 | initramfs 卡 `PARTUUID=614e0000-0000 does not exist` | DTB `chosen.bootargs` 里 `root=` 是**假的 GPT 分区 GUID** `614e0000-0000` | `root=` 改成真实 UUID 或通用设备名 |
| 3 | 调试中误改 fiq/uart2 | 我曾把 fiq→disabled、uart2→okay(完全搞反) | 恢复原始:fiq=okay、uart2=disabled |

**关键机制(vendor U-Boot 的 cmdline 优先级)**：这块板用的 Radxa vendor U-Boot
(`CONFIG_ANDROID_BOOTLOADER=y`)在 `booti` 时**优先用 DTB 的 `chosen.bootargs`，
忽略 U-Boot env 里的 `bootargs`**。证据:手动 `setenv bootargs "root=/dev/mmcblk0p1
console=ttyFIQ0,1500000"` 后,`/proc/cmdline` 仍是 DTB chosen 的
`root=PARTUUID=... console=ttyFIQ0(无波特率) earlycon=...`。

因此:
- `boot.cmd`/`boot.scr` 里的 `console=ttyS2` **不影响实际控制台**(被 DTB chosen 覆盖)。
- **唯一必须修的 Linux 层文件就是 DTB 的 `chosen.bootargs` 里的 `root=`**。
- fiq=okay、uart2=disabled、console=ttyFIQ0、earlycon 在原始 DTB 里**本来就是对的**,不用改。

## 固化:下次打包一次成功

唯一的持久化改动已经落在仓库:

**`overlay/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb`**(预编二进制 DTB)的
`/chosen/bootargs` 已由:

```
root=PARTUUID=614e0000-0000
```

改为:

```
root=/dev/mmcblk0p1
```

(`/dev/mmcblk0p1` 是通用设备名,不依赖每次构建变化的 UUID。前提:本板 armbian
GPT 是**单分区**,p1=rootfs,`boot` 目录与 rootfs 同分区——见 `config/boards/agibot.conf`。)

该 DTB 由 `customize-image.sh` 第 17-22 行复制进镜像的 `/boot/dtb-*-vendor-rk35xx/rockchip/`,
所以改这个 overlay DTB 即完成固化,下次 `setup.sh && docker-build.sh` 直接产出可启动镜像。

### 验证(下次构建后)

刷入后 COM5 @ 1500000 应看到 `Starting kernel ...` 之后立即出 `[ 0.xxx]` 早期日志
(earlycon 直写 uart2),一路到 `armbian login:`。网络两路 RTL8211F 正常注册、
无 `Failed to reset the dma`(vendor gmac 驱动,与 OpenWrt mainline 内核的死结不同)。

## 刷机方法汇总(loader / maskrom)

OpenWrt 主线版 U-Boot 尚未接入 SW9200；AGIBOT Armbian vendor U-Boot 源码已按
原厂 DTB 接入 SW9200 下载键（交叉编译和完整镜像构建已通过，须刷入新镜像后实机
验收）。旧 eMMC 镜像不会因本机完成编译而改变，未刷入前按键测试必然无效。仍可
通过 U-Boot 命令或擦 idbloader 进入下载模式。
**真 Maskrom 比 Loader 稳**(RKDevTool 标准 BROM+loader 协议,不会「读取 flash
信息失败」)。

### 进 Loader(U-Boot 命令,快)

- **OpenWrt 版 U-Boot**:上电 → `Hit any key to stop autoboot` 按任意键 → `=> rockusb 0 mmc 0`
- **Armbian vendor U-Boot**:上电 → `Hit key to stop autoboot('CTRL+C')` 时按 **Ctrl+C**(发 0x03)→ `=> download`(或 `rockusb 0 mmc 0`)
- RKDevTool 顶部显示 **「发现一个 LOADER 设备」**

> ⚠️ LOADER 模式下用「下载镜像」页的 `Loader@0xCCCCCCCC + image@0x0` 组合会报
> 「读取 flash 信息失败」(rockusb 模拟的 loader 与 BROM loader 下载协议不兼容)。
> LOADER 模式要刷,用两步式:①「高级功能 → 下载 Boot」单独下 loader,设备变 LOADER;
> ②「下载镜像」只加 image@0x0。

### 进 Maskrom(真 BROM,最稳,刷机首选)

进真 Maskrom 的本质是**让 BROM 读不到 idbloader**。三种等价操作(**方法 0 最快**,
完整问答见 [FAQ.md Q1](FAQ.md#q1)):

0. **Linux 里擦,SSH 远程**(能进系统时最快,2026-08-14 实测):
   ```sh
   ssh root@<板子IP>   # 密码 1234
   dd if=/dev/zero of=/dev/mmcblk0 bs=512 count=32768 conv=fsync; sync; reboot -f
   ```
   ⚠️ paramiko 自动化发 `reboot -f` 必须后台化,否则 channel 关闭会杀掉 reboot:
   `c.exec_command("(sleep 1; reboot -f) >/dev/null 2>&1 &")`。
   验证:ping 断(Maskrom 无网络)+ 串口完全静默 + RKDevTool 显示 MASKROM。
   可顺手 `dd ... skip=64 count=1 | hexdump` 校验 RKNS 魔数已清零。
1. **U-Boot 里擦**(当前停在 U-Boot 时):
   ```
   => mmc dev 0
   => mmc erase 0 0x8000      # 擦 eMMC 前 16MiB(idbloader@32KB + u-boot@8MB)
   => reset
   ```
2. **Linux 里擦**(本机接串口/键盘时):
   ```sh
   dd if=/dev/zero of=/dev/mmcblk0 bs=512 count=32768; sync; reboot
   ```

擦完重启后 BROM 找不到 loader 回退 Maskrom,RKDevTool 显示 **「发现一个 MASKROM 设备」**。
然后「下载镜像」页两项(标准流程,兼容):

- **Loader** `@0xCCCCCCCC` → `flash/rk3588_spl_loader_v1.16.113.bin`
- **image** `@0x00000000` → 整盘 `.img`(armbian 或 openwrt)

### SW9200 按钮进 Loader(2026-08-14 实测定论)

- **检测者是 idbloader 里的 rkbin miniloader(闭源)**,不依赖 U-Boot 补丁。
  断电按住 SW9200 再上电 → miniloader 检测到 → 直接枚举 Rockusb(PID 0x350B),
  RKDevTool 显示「LOADER 设备」。
- ⚠️ **不要往 U-Boot DTS 加 adc-keys 节点**:实测(commit c260761 那版)会让
  U-Boot proper 在 console 初始化前挂死——正常启动 BL31 跳 BL33 后串口全静默、
  不进 Linux。已回退(镜像 SHA `2dc05ed4...`,U-Boot hash `S39cd-P9a41`),
  回退后启动正常、SW9200→Loader 依旧可用(miniloader 提供)。
- Linux 启动后仍会把 SW9200 注册为 `adc-keys` 输入设备;这是独立的内核运行时
  功能,不影响上述流程。

## Linux DTB 修复(2026-08-14,稳定 v3)

1. **CPU 一直高频(`no supported OPPs`)**:DTB 的 OPP 表带
   `nvmem-cells + opp-supported-hw` 硬件匹配,本板 OTP 读值与 opp 条目不匹配
   → 全部 OPP 被拒。修法:从 OPP 表删 `nvmem-cells`/`nvmem-cell-names`/
   `rockchip,supported-hw`/`opp-supported-hw`(手术脚本 `_fix_dtb.py`)。
   修后小核 1.2–1.8GHz、大核 1.2–2.2GHz,ondemand 正常调频。
2. **tsadc probe -22(`Failed to find 'trips' node`)**:原厂 DTS 7 个 thermal
   zone 只有 soc-thermal 带 trips,6.1 内核要求每个 zone 都有。给
   bigcore0/1、littlecore、center、gpu、npu 六个 zone 补 trips(passive 75°C +
   critical 115°C)。修后 `tsadc is probed successfully!`,7 个 zone 全部出温度。
3. **rkvenc2 视频编码器 OPP**:DTB 的 rkvenc-core 节点缺 opp 表。照 RK3588
   兄弟板 sige7 移植 `venc-opp-table`(800MHz/800mV,不带 nvmem 匹配),给
   `vdd_vdenc_s0` 加 phandle,两个 core 挂 `operating-points-v2`+`venc-supply`
   (脚本 `_fix_venc.py`)。修后 `mpp-srv probe success`,零 rkvenc OPP 报错。
4. **Linux 下 SW9200 按键阈值**:`1750uV` 过严(按下实测约 17mV),已改为
   30000uV。Linux input 事件的最终按压验收待有人在板旁执行;不影响 miniloader
   的 SW9200→Loader 功能。

稳定 v3 overlay DTB SHA-256:
`007b1b76dc3c221da437e321581423ab889291ef831b042b4aae886943a6f133`。
深度回归:PASS=22/FAIL=0;8 核满载 90 秒最高约 41.6°C;NPU 171.3 FPS;
eMMC 写约 218MB/s;eth1 1Gbps Full;USB hub 正常。

## 显示 DTB v5 事故/当前板端恢复

2026-08-14 在无人可物理复位的条件下,在线覆盖默认 DTB 测试 HDMI/DP 迁移是错误
操作。v4 尚能启动但 DRM 反复 `EPROBE_DEFER(-517)`;v5 合并修改 HDMI PHY clock
provider、旧 clk-port 接线和 VOP OPP 后,板端内核启动挂起,SSH/串口不可操作。
失败 v4/v5 **未提交/未推送**,仓库已经恢复稳定 v3。板端 `/root/dtb.v3-good`
可用于恢复;完整时间线、U-Boot 手动启动命令和后续分阶段修复规则见
**[DISPLAY-DTB-INCIDENT.md](DISPLAY-DTB-INCIDENT.md)**。

## 附:本次调试的关键命令(复用)

```bash
# 串口助手(Windows pyserial,COM5 @ 1500000 8N1)
python _ser.py "命令" 捕获秒数

# 抓 U-Boot 后擦 idbloader 进 Maskrom
python _erase_to_maskrom.py

# fdtput 改 overlay DTB 的 root=(固化时用过一次)
fdtput -t s overlay/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb /chosen bootargs \
  "earlycon=uart8250,mmio32,0xfeb50000 console=ttyFIQ0 irqchip.gicv3_pseudo_nmi=0 root=/dev/mmcblk0p1 rw rootwait"
```
