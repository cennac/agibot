# AGIBOT MB0002 V2 — 显示 DTB v5 事故记录与恢复手册

> 状态日期:2026-08-16。**事故已恢复；HDMI DRM + tty1 login 已通过默认启动验证。**
> 本文保留完整时间线(前段记录一次未提交、未推送的显示设备树实验导致板端启动
> 失败的过程),以及 2026-08-16 实战验证的恢复流程。仓库 `main` 始终是稳定版本。

## 2026-08-16 恢复实录(最终事实,修正前期误判)

1. **真实故障形态(修正)**:v5 DTB 下**内核能正常启动**,但 init(systemd)
   被 SIGSEGV 干掉(`Kernel panic - not syncing: Attempted to kill init!
   exitcode=0x0000000b`),约 4.5s 即崩。前期「内核启动挂起/无输出」是误判——
   panic 后停在死机画面不再打印,而监控挂晚了看不到已滚过的日志。
   **rootfs 并没有损坏**(同内核+同 rootfs 换 v3 DTB 直接正常启动)。
2. **串口输入(修正)**:vendor U-Boot 的 stdin 是好的。前期 pyserial 脚本连发
   Ctrl+C 五次(含冷启动)都没打断,一度误判「U-Boot stdin 失效」;最终人工用
   **SSCOM 勾 HEX 发送、内容 `03`、循环 100ms** 一次命中打断 autoboot(方法
   详见 FAQ Q13)。板子串口 RX 输入脚曾疑似烧坏(换线无效),换适配器/USB 口后
   枚举为 COM6 恢复。
3. **恢复步骤(实测版)**:
   - SSCOM 打断 U-Boot → `=>`;
   - 手动 `ext4load` 真实文件名(`vmlinuz-6.1.115-vendor-rk35xx`、
     `uInitrd-6.1.115-vendor-rk35xx`,**别用符号链接** `/boot/Image`)加载
     kernel/initramfs/`/root/dtb.v3-good` → `booti`;
   - SSH(本次 IP 192.168.88.88)进系统后
     `cp /root/dtb.v3-good /boot/dtb-.../rk3588-agibot-mb0002-v2.dtb && sync`;
   - `reboot` 验证全自主启动链 ✓;回归 `postflash-test.sh` **PASS=23 FAIL=0**。
4. **未走 Maskrom 重刷**——eMMC 短接方案备而未用。

## 一句话结论(历史)

CPU 压力测试没有把板子跑坏。直接原因是为了修 HDMI/DP 错误而在线替换了 `/boot`
DTB 并重启;显示 v5 实验与本板 vendor 6.1 驱动不兼容,内核起来后 init 崩溃。

## 当前状态(重要)

### 仓库/构建侧:安全

- GitHub `main` 的稳定提交:`7b41c83`。
- 当前默认 overlay DTB:
  `overlay/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb`
  - SHA-256:`9f1c04daa5667013450aca47ac6bfc07dcef1a987f1063987086245ccb3ea135`
    (2026-08-16 在 HDMI 版基础上追加 PCIe 三段式 reg 修复,AP6275P WiFi 可用)
  - HDMI-A-1 connected、DRM fb0、fbcon 和 `getty@tty1` 已验证。
  - `/chosen/bootargs` 同时保留 `console=ttyFIQ0 console=tty1`。
  - PCIe/WiFi 详情见 [ARMBIAN-LINUX-BRINGUP.md](ARMBIAN-LINUX-BRINGUP.md)。
- 已验证启动镜像(实机回滚基线):
  `E:\AIPorject\101\agibot-releases\armbian\validated\2026-08-14-stable-v3-2dc05ed4\Armbian-unofficial_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img`
  - SHA-256:`2dc05ed4e388cb8187d2c4a92f8cc1de45926c70cd0a4b3a11c6b8cac411da91`
  - 已归档:`E:\AIPorject\101\agibot-releases\armbian\validated\2026-08-14-stable-v3-2dc05ed4\`
- 历史重新打包版 `f850f7e8...` 的本地实体已于 2026-08-27 确认失配，隔离到
  `agibot-releases\armbian\quarantine\2026-08-14-rebuild-label-mismatch-c28f0b70\`，
  **禁止刷入**；详见 [RELEASES.md](RELEASES.md)。
- 失败的显示 v4/v5 二进制和手术脚本已从工作区删除,没有 commit/push。
- `git status` 除 armbian/build submodule 的 WSL 符号链接噪声外应为干净。

### 板端:已恢复(2026-08-16)

- `/boot/.../rk3588-agibot-mb0002-v2.dtb` 已恢复为稳定 v3
  (SHA-256:`007b1b76dc3c221da437e321581423ab889291ef831b042b4aae886943a6f133`)。
- eMMC 仍保留两个备份:`/root/dtb.v3-good`(首选)和 `/root/dtb.v4`。
- 全自主启动链验证 ✓,回归 PASS=23/FAIL=0。
- 串口:换适配器后工作在 **COM6**,输入输出均正常(SSCOM HEX 03 打断法见 FAQ Q13)。

## 恢复步骤(下次有人到板旁)

### 方案 A:U-Boot 手动加载稳定 DTB(首选,不重刷)

1. Windows 先启动自动抓 U-Boot:
   ```sh
   python -X utf8 tools/_catch_uboot.py 1800
   ```
   工具打开 COM5@1500000,持续发 Ctrl+C,抓到 `=>` 后释放串口。
2. 轻按一次 **SW9201 或 SW8900**。不要按住 SW9200(避免误触下载键路径)。
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

## HDMI 推进记录(2026-08-16)

### 已解决:A 阶段 hdmiphy clock provider(-12)

- **根因**:DTB 的 hdmiphy 节点沿用 5.10 的 `clk-port` 子节点作时钟 provider,
  6.1 驱动 `phy-rockchip-samsung-hdptx-hdmi.c` 的 `rockchip_hdptx_phy_clk_register()`
  用 `of_property_read_string(np,"clock-output-names",&init.name)`,clk-port 写法下
  `init.name=NULL` → `devm_clk_register` 里 `kstrdup_const(NULL)` → **-ENOMEM(-12)**。
- **修复(实测生效)**:①hdmiphy@fed60000 删 `clk-port` 子节点,节点级补
  `#clock-cells=<0>` + `clock-output-names="clk_hdmiphy_pixel0"`(fed70000 同理);
  ②display-subsystem 删 `clocks/clock-names`(hdmi0/1_phy_pll);③hdmi@fde80000 /
  fdea0000 的 `link_clk` 由 clk-port phandle(0x2d/0x2e)改指 hdmiphy 节点本身
  (0xe4/0x183)。对应 sige7 6.1 写法。脚本 `tools/_fix_hdmi_ab.py`,测试 DTB `_test_ab.dtb`。
- **验证**:U-Boot 手动加载测试 DTB 启动,`rockchip-hdptx-phy-hdmi fed60000.hdmiphy:
  hdptx phy init success`,原 `failed to register clock: -12` 消失。
- **测试基建坑(重要)**:`tools/_hdmi_testboot.py` 里 ext4load 的 DTB 路径两次踩坑:
  ①MSYS/Git-Bash 把 `/boot/...` 转成 `D:/DTools/PortableGit/boot/...`(用
  `MSYS_NO_PATHCONV=1` 且走脚本内置默认路径);②脚本参数顺序 arg1=路径 arg2=秒数,
  误传 `75` 被当路径。两次都导致 fdt 没加载、内核悄悄用了默认 DTB,测试结果无效。
  现在脚本默认路径可直接 `python tools/_hdmi_testboot.py` 无参运行。

### 已解决:C/D 阶段 DRM master 与 HDMI tty1

- DP0 按 6.1 sige7 绑定补 `hdcp` 时钟，消除 `dw-dp` 的缺时钟错误。
- HDMI0 的单段 `reg=<fde80000 0x20000>` 拆成控制器和 HDCP 1.4 memory 两段；
  QP 驱动随后能取得 `resource[1]`，DRM master 正常绑定。
- 实测 `/sys/class/drm` 出现 `card0-HDMI-A-1`，状态 `connected`，创建 DRM fb0，
  输出 2560x1440；无需修改 VOP 时钟/OPP。
- DTB `chosen.bootargs` 追加 `console=tty1`，镜像显式启用 `getty@tty1`。
  默认重启后 `/dev/vcs1` 显示 `agibot login:`，串口 ttyFIQ0 同时可用。
- 237.6MHz 的根因是 Stage A+B 误删了 `display-subsystem` 的 `hdmi0_phy_pll`，
  VOP 退回 1188MHz CRU 近似分频。改为引用节点级 HDMI PHY clock provider 后，
  默认启动按 EDID 自动输出 2560x1440@60，`dclk=real_dclk=241.5MHz`；不再固定 1080p。
- GPIO137 冲突来自 HDMI 节点错误的 `enable-gpios=<&gpio4 9 ...>`，该脚实际是
  I2S1 `SDO0`。删除错误 HDMI GPIO 后，恢复 `/i2s@fe480000` 和
  `/acm8625p-sound`；USB/HDMI/tty1 默认重启回归均通过。

## 文件整理结论

正式构建树是仓库内 `agibot-armbian/armbian-build/`(submodule)。平级旧目录
`E:/AIPorject/101/armbian-build/` 是相同 commit 的历史工作区:

- 旧镜像 SHA `78defab9...`,已被稳定镜像 `2dc05ed4...` 取代;
- 旧 `armbian-flash/` 已迁移为仓库 `flash/`;
- cache/output 约占 3.5GB;
- **已于 2026-08-14 经用户确认后删除整个平级旧目录**;
- 正式仓库 submodule `agibot-armbian/armbian-build/` 和稳定镜像 `2dc05ed4...`
  已在删除后复核存在。
