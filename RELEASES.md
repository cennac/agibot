# AGIBOT Armbian 发布记录

本文只记录可追溯的整盘镜像。大文件不提交 Git;以 SHA-256、构建 commit 和验收状态
识别版本。本地归档位于 `E:\AIPorject\101\agibot-releases\`。

## OpenWrt/LEDE 固件(openwrt/ 路线)

### 2026-08-15 完善版(398 包)

- squashfs:`77660b980df2e184679ff3caaea4c206860b2fa5bf005c2f948957a96f262c56`(136 MB gz / 2.13 GiB)
- ext4:`cb306ccea1fe361bde4ed05dafb1a7cd8a46e10576656a5d42c34e295709d974`(174 MB gz / 2.13 GiB)
- 增补:ttyd/netdata/nlbwmon/statistics/smartdns/ddns/watchcat/wol/autoreboot/
  advanced-reboot/ramfree/iperf3/ethtool/bash/jq/bc/lsof/strace/lm-sensors/
  smartmontools/rsync/uuid
- 修复:strace 6.6+musl 编译失败(patches/003,--enable-bundled=yes)
- 状态:构建成功、manifest 抽查 21/21 新包在镜像、解压盘结构(RKNS/FIT/ext4)验证;
  **未实机刷入**(板子等待显示 v5 事故后物理复位恢复)

### 2026-08-14 初版(352 包,已实机刷入未通过启动验证)

- squashfs:`795d5d1f6ad7d60ad48319576b143cb38e787de1d21554d53e819314add8ca25`
- ext4:`79cf5852b5b072a77c75750019066a516723d60c52a3532efc595fd8748f46f5`
- openwrt/ 目录内时间戳 08-14 的 ext4 .gz 被某 Windows 进程锁住暂无法删除
  (RKDevTool 已关仍锁),带 `_STALE-*.txt` 标记;有效 ext4 用解压版 .img(08-15)

## Armbian 镜像(armbian 路线)

## stable-v3-rebuild-f850f7e8(当前重新打包版,Armbian)

- 构建 commit:`c69e8be`
- 构建完成:2026-08-14 22:13 CST
- 文件:`Armbian-unofficial_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img`
- 大小:1,786,773,504 bytes
- SHA-256:`f850f7e82845b9d93522081f9884e62635bd5e88d107492ec1663644fef27165`
- U-Boot:`2017.09-S39cd-P9a41-Hbe55-Vecf7-B5da4-R448a`
- Kernel:`6.1.115-vendor-rk35xx`
- Userspace:Ubuntu 22.04 jammy minimal
- 本地归档:`E:\AIPorject\101\agibot-releases\stable-v3-rebuild-f850f7e8\`
- 标准输出:`armbian-build\output\images\...minimal.img`(NTFS hard link)
- 刷机目录:`flash\...minimal.img`(NTFS hard link)

### 离线验收

- 构建:`FINISHED_EXIT=0`,fatal/error=0。
- LBA64 `RKNS`,LBA1 `EFI PART`,rootfs ext4 `EF53`。
- U-Boot FIT 和控制 DTB 有效;model=`AGIBOT MB0002 V2`。
- U-Boot DTB 无 `adc-keys`/`loader-key`/`SW9200 loader`。
- 镜像内 Linux DTB 与稳定 overlay 逐字节一致,SHA
  `007b1b76dc3c221da437e321581423ab889291ef831b042b4aae886943a6f133`。
- chosen:`root=/dev/mmcblk0p1`,`console=ttyFIQ0`。
- CPU OPP hardware matching 残留=0;thermal trips=7。
- `venc-opp-table` 存在,两个 rkvenc core 引用存在。
- Linux SW9200 阈值=30000uV。
- ⚠️ **SW9200→Loader 在本镜像上无效**(2026-08-15 确认):该功能依赖 U-Boot
  控制 DTB 的 adc-keys 节点(PID 0x350B 是 U-Boot rockusb 的 PID,非 miniloader);
  本镜像为修启动挂死删了节点。恢复方案见 UBOOT-BRINGUP.md「按键恢复实验」。
  实机结果中的启动/回归项均不含按键验证。
- 失败显示 v4/v5 的 VOP/HDMI PHY 实验属性不存在。
- `flash/armbian-head.img` 与整盘前 16MiB 逐字节一致:
  `63710dedbe23f0e2e13de566222a84674ccbb6b06c48d393234f536954571316`。
- `flash/armbian-rootfs.img` 与整盘其余区间逐字节一致:
  `b8833ffa671f2bbd3cd333b6648232c2b431e194d88b01313c4e765f16abc301`。

### 实机状态

该版与下面的实机验证版使用相同稳定 U-Boot/DTB 配置,但当前板子仍等待显示 v5
事故后的物理复位恢复,因此**本重新打包版尚未单独做实机冷启动验收**。恢复流程见
[DISPLAY-DTB-INCIDENT.md](DISPLAY-DTB-INCIDENT.md)。

## stable-v3-2dc05ed4(实机验证版/回滚基线)

- 构建 commit:`7b41c83` 对应稳定配置
- SHA-256:`2dc05ed4e388cb8187d2c4a92f8cc1de45926c70cd0a4b3a11c6b8cac411da91`
- 本地归档:`E:\AIPorject\101\agibot-releases\stable-v3-2dc05ed4\`
- 状态:**已刷入并实机验证**

实机结果:

- U-Boot→kernel→login→SSH 完整启动。
- postflash:PASS=22,FAIL=0。
- CPU DVFS:小核1.2–1.8GHz,大核1.2–2.2GHz,ondemand。
- 8核满载90秒最高约41.6°C,无崩溃/降频。
- 7个 thermal zone 正常。
- rkvenc MPP probe成功,无rkvenc OPP错误。
- NPU resnet18:171.3 FPS。
- eMMC写约218MB/s;eth1 1000Mb/s Full;USB hub正常。

## 已废弃版本

- `78defab9...`:平级旧 `armbian-build` 工作区镜像;旧工作区已删除。
- `fd2c6b78...`:含 U-Boot adc-keys 节点;正常启动在 BL31→BL33 后串口静默,
  **禁止使用**。
- 显示 DTB v4/v5:仅板端临时实验,未形成发布镜像、未 commit/push;v5 导致内核
  启动挂起,完整事故记录见 [DISPLAY-DTB-INCIDENT.md](DISPLAY-DTB-INCIDENT.md)。
