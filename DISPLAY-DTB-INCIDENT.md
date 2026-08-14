# AGIBOT MB0002 V2 — 显示 DTB v5 事故记录与恢复手册

> 状态日期:2026-08-14。本文记录一次**未提交、未推送**的显示设备树实验导致板端
> 启动挂起的过程、当前边界和恢复步骤。仓库 `main` 仍是已验证的稳定版本。

## 一句话结论

CPU 压力测试没有把板子跑坏。直接原因是为了修 HDMI/DP 错误而在线替换了 `/boot`
DTB 并重启;显示 v5 实验与本板 vendor 6.1 驱动不兼容,内核启动阶段挂起,网络和串口
均未进入可操作状态。需要有人轻按一次 SW9201/SW8900,截停 U-Boot 后用 eMMC 上的
`/root/dtb.v3-good` 启动并恢复 `/boot` DTB。**不需要重刷整盘镜像。**

## 当前状态(重要)

### 仓库/构建侧:安全

- GitHub `main` 的稳定提交:`7b41c83`。
- 稳定 overlay DTB:
  `overlay/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb`
  - SHA-256:`007b1b76dc3c221da437e321581423ab889291ef831b042b4aae886943a6f133`
- 已验证启动镜像(实机回滚基线):
  `armbian-build/output/images/Armbian-unofficial_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img`
  - SHA-256:`2dc05ed4e388cb8187d2c4a92f8cc1de45926c70cd0a4b3a11c6b8cac411da91`
  - 已归档:`E:\AIPorject\101\agibot-releases\stable-v3-2dc05ed4\`
- 当前重新打包版(离线验收通过,尚待实机冷启动):
  - SHA-256:`f850f7e82845b9d93522081f9884e62635bd5e88d107492ec1663644fef27165`
  - 已归档:`E:\AIPorject\101\agibot-releases\stable-v3-rebuild-f850f7e8\`
  - 与稳定 overlay/U-Boot 组合一致;详见 [RELEASES.md](RELEASES.md)。
- 失败的显示 v4/v5 二进制和手术脚本已从工作区删除,没有 commit/push。
- `git status` 除 armbian/build submodule 的 WSL 符号链接噪声外应为干净。

### 板端:等待一次物理复位

- `/boot/.../rk3588-agibot-mb0002-v2.dtb` 当前是失败 v5
  (当时 SHA-256:`7115d2bb597cddfcc464387c694f8bb5d8b7441e61432bda39ab1c3541d3abea`)。
- eMMC 已保留两个可启动备份:
  - `/root/dtb.v3-good` — **首选**,完整回归通过。
  - `/root/dtb.v4` — 能启动,但 DRM 反复 `EPROBE_DEFER`,不推荐长期用。
- 当前 `.89` 无 SSH;40 次重连全超时。串口 SysRq、CH340 DTR/RTS 均无法远程复位;
  CH340 控制线没有接板子 reset。
- 结论:远程没有剩余重启通道,必须轻按 SW9201/SW8900 一次。

## 恢复步骤(下次有人到板旁)

### 方案 A:U-Boot 手动加载稳定 DTB(首选,不重刷)

1. Windows 先启动自动抓 U-Boot:
   ```sh
   python -X utf8 _catch_uboot.py 1800
   ```
   工具打开 COM5@1500000,持续发 Ctrl+C,抓到 `=>` 后释放串口。
2. 轻按一次 **SW9201 或 SW8900**。不要按住 SW9200(它会进 miniloader LOADER)。
3. U-Boot `=>` 下依次执行:
   ```text
   mmc dev 0
   printenv kernel_addr_r ramdisk_addr_r fdt_addr_r
   ext4load mmc 0:1 ${ramdisk_addr_r} /boot/uInitrd
   ext4load mmc 0:1 ${kernel_addr_r} /boot/Image
   ext4load mmc 0:1 ${fdt_addr_r} /root/dtb.v3-good
   fdt addr ${fdt_addr_r}
   booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
   ```
   稳定 DTB 自带 `root=/dev/mmcblk0p1 console=ttyFIQ0` chosen bootargs;vendor U-Boot
   即使用 DTB chosen 覆盖 env bootargs,这里也能正确启动。
4. Linux 登录/SSH 恢复后永久写回:
   ```sh
   cp /root/dtb.v3-good \
     /boot/dtb-6.1.115-vendor-rk35xx/rockchip/rk3588-agibot-mb0002-v2.dtb
   sync
   reboot
   ```
5. 回归:
   ```sh
   bash /root/postflash-test.sh
   dmesg | grep -iE 'no supported OPPs|failed to init opp|tsadc|rkvenc'
   ```
   预期 `PASS=22 FAIL=0`,CPU DVFS 正常、`tsadc is probed successfully!`、rkvenc
   无 OPP 错误。

### 方案 B:SW9200 进 LOADER 后重刷稳定镜像(兜底)

若方案 A 无法截停 U-Boot:断电按住 SW9200 再上电 → RKDevTool 显示 LOADER;
按 [FAQ Q3/Q4](FAQ.md#q3) 两步式刷稳定镜像 `2dc05ed4...`。这会重写整盘,
所以只作兜底。

## 事故时间线与根因边界

1. 稳定 v3 已启动并完成深度回归:
   - `postflash-test.sh`:PASS=22,FAIL=0。
   - 8 核满载 90 秒:小核 1.8GHz/大核 2.2GHz,最高约 41.6°C,无降频/崩溃。
   - NPU resnet18:171.3 FPS(5.8ms/frame),结果有效。
   - eMMC 顺序写约 218MB/s;eth1 1000Mb/s Full;USB hub 枚举正常。
   因此**不是 CPU 负载、过热、供电过载或 eMMC 压测导致**。
2. 深度 dmesg 发现待适配项:
   - HDMI PHY:`failed to register clock: -12`。
   - DP:`failed to get hdcp clock`。
   - PCIe fe150000/fe170000/fe190000 全部 host init 失败(是否有实物端点待确认)。
3. 显示 v4 实验(板端能启动):
   - 给 HDMI PHY 补节点级 clock provider,DP 补 hdcp clock。
   - 原始 `-12/-2` 消失,但 DRM 反复 `failed to get hdmi*_phy_pll: -517`
     (`EPROBE_DEFER`),说明 5.10 的 `clk-port` 旧接线与 6.1 新接线混用。
4. 显示 v5 实验(失败):
   - 删除 `display-subsystem` 旧 PLL 引用和两个 PHY 的 `clk-port` 子节点;
   - 补 VOP OPP 表并调整 VOP ACLK。
   - DTB 静态编译通过,但重启后没有网络/可交互串口。偶有单个 ping 回包,
     SSH 40 次均超时。最可能是显示时钟/PHY/SCMI/DRM 依赖在内核早期死锁或
     deferred-probe 风暴;需恢复后读取 pstore 才能最终归因。

## 后续显示修复规则(防止复发)

1. **没有物理复位/串口/U-Boot 恢复窗口时,禁止再在线替换显示 DTB。**
2. 一次只改一个绑定差异;每次重启后完整保存 dmesg/pstore,不要合并 PHY+DP+VOP。
3. 先在独立 DTB 文件名上测试,不要直接覆盖默认文件。建议:
   - 在 `/boot/dtb-.../rockchip/` 放 `rk3588-agibot-test.dtb`;
   - U-Boot 手动 `ext4load` test DTB 启动;
   - 验证通过后才改默认 DTB。
4. HDMI/DP 下一轮顺序:
   - A:只修 hdmiphy clock provider,不动 VOP;
   - B:只修 display-subsystem 旧 clk-port 引用;
   - C:只补 DP hdcp clock;
   - D:最后单独处理 VOP OPP/overlay planes。
5. PCIe 在确认板上是否真的接出插槽/端点前不修改。无硬件端点时 host init 失败可记录
   为 WARN,不要为消日志盲配 reset/power GPIO。

## 文件整理结论

正式构建树是仓库内 `agibot-armbian/armbian-build/`(submodule)。平级旧目录
`E:/AIPorject/101/armbian-build/` 是相同 commit 的历史工作区:

- 旧镜像 SHA `78defab9...`,已被稳定镜像 `2dc05ed4...` 取代;
- 旧 `armbian-flash/` 已迁移为仓库 `flash/`;
- cache/output 约占 3.5GB;
- **已于 2026-08-14 经用户确认后删除整个平级旧目录**;
- 正式仓库 submodule `agibot-armbian/armbian-build/` 和稳定镜像 `2dc05ed4...`
  已在删除后复核存在。
