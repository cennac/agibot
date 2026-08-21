# AGIBOT Armbian 发布记录

本文只记录可追溯的整盘镜像。大文件不提交 Git;以 SHA-256、构建 commit 和验收状态
识别版本。本地归档位于 `E:\AIPorject\101\agibot-releases\`。

## OpenWrt/LEDE 固件(openwrt/ 路线)

### 2026-08-21 SW9200 Loader / SW9201 复位 / HID 键盘修订

- squashfs.gz:`ae622728ea330d4a47d659fa6516e7809f911056045d77252c5ed1aa823a4da6`
  (132,343,795 bytes)
- ext4.gz:`7fbeae31f31a26d205446c177d7a02d3c36cc1cb4b93df43bd159f890b86141e`
  (170,050,808 bytes)
- 本地归档:`E:\AIPorject\101\artifacts\lede-sw9200-loader-sw9201-hid-20260821\`
- 内容:SW9200 按住上电改为进入 U-Boot RockUSB Loader;SW9201 通过
  RK806 `pmic-reset-func=<1>` 与主线 `rk8xx-core` 补丁恢复立即复位;
  USB/HDMI 登录键盘补入 `kmod-hid-generic` 并固化 `CONFIG_HID_GENERIC=m`。
- 根因与行为:旧 U-Boot 先执行通用 `setup_boot_mode()`,SARADC1 下载键被
  置 BROM download flag 后复位,后续自定义 Loader 分支不可达,因此按住
  SW9200 实际落入真 Maskrom,RKDevTool 读取 eMMC flash 信息失败。本版把
  `agibot_check_loader_key()` 提前,检测到 SW9200 时直接执行
  `rockusb 0 mmc 0`,RKDevTool 应识别为 LOADER。若确需 Maskrom,仍要走
  破坏 idbloader/擦写前 16 MiB 的既有救援路径。
- 构建验证:66 重试全量构建退出码 0;U-Boot 源码确认调用顺序为
  `agibot_check_loader_key()` → `setup_boot_mode()`;最终 DTB 反编译确认
  `pmic-reset-func = <0x01>`;manifest 含
  `kmod-hid-generic - 6.12.100-1`,ipk 内 `hid-generic.ko` 为 5,720 字节
  ARM64 ELF。镜像哈希已在 66 与本机双端复核。
- 上板:待刷新验证。重点测试按住 SW9200 上电 RKDevTool 显示 LOADER、
  SW9201 轻按立即复位、HDMI 登录界面键盘 Caps/Num/Scroll LED 与密码输入。

### 2026-08-21 clean boot / 非阻断日志治理修订

- squashfs.gz:`73576559582bfb0f9e97102043c50d170d512f38751183f8882402a847482124`
  (132,345,154 bytes)
- ext4.gz:`0a6400bbb683e7bbc0c77812694cfa50424264bf9abbbe0e17e8dc2a67d6c85c`
  (170,050,485 bytes)
- 本地归档:`E:\AIPorject\101\artifacts\lede-clean-boot-20260821\`
- 内容:在 HDMI/USB/BT 修订基础上治理启动日志——双 GMAC 增补
  `snps,no-vlhash`,PCIe3x4 64-bit MMIO range 扩为 2 GiB,RNG 节点移除
  无效 clocks,NPU IOMMU 使用 `aclk`/`iface`,RKNPU 改用直接
  `devm_ioremap()`,AP6275P 固件补板级 BIN 并关闭 optional firmware
  fallback 告警;GPU 侧显式启用 `CONFIG_DEVFREQ_THERMAL=y` 以注册
  Panthor cooling device。
- 构建验证:66 通过代理恢复 helloworld feed/passwall 依赖并完成全量构建;
  `ipt2socks`、`shadowsocks-rust-sslocal/sserver`、`v2ray-plugin` 已进
  manifest;镜像 SHA-256 在 66 与本机双端验证通过。独立 DTB、ext4 boot DTB、
  squashfs boot DTB 内容一致,并确认双 GMAC/RNG/NPU IOMMU/PCIe range 修复
  已编入最终 DTB。
- 预期效果:上一版记录的 GMAC VLAN filter timeout、PCIe BAR assign failed、
  RNG `-517`、NPU IOMMU clock、NPU `request region -EBUSY`、Panthor cooling、
  AP6275P 板级 BIN/NVRAM fallback 告警应消失。空 M.2 插槽的 PCIe
  `Phy link never came up` 仍会保留,这是无端点时的真实物理状态。
- 上板:尚未刷入回归。重点看全量
  `dmesg | grep -Ei 'error|failed|fail|warn|ebusy|timeout'`、RNG 读数、
  devfreq、双网口、Wi-Fi/BT 与 render node。

### 2026-08-21 HDMI 登录 + USB/BT 启动修订

- squashfs.gz:`978f335449e36ff2ce5bcadd973a875f346efd31931fc9c4ce58b83ee187e917`
- ext4.gz:`947a0135d56aa9b5b0bd5245fe0cc0840be60ce48efcc23bf80e932de3be2616`
- 本地归档:`E:\AIPorject\101\artifacts\lede-hdmi-login-usb-bt-20260821\`
- 内容:在设备补齐修订基础上,把 tty1 改为标准 `/bin/login`;USB 供电初始化
  增加 hub settle 且用 sysfs GPIO `direction=high` 避免切输出时低电平毛刺;
  `agibot-bt-attach` 升级到 `1.0.0-2`,attach 后自动执行 `hciconfig hci0 up`,
  并显式依赖 `bluez-utils`。
- 上板:HDMI 登录进程与界面已验证;USB 摄像头启动期 `-71` 消失,最终枚举为
  HD Camera。蓝牙自动 up 的旧进程已手动验证可行,新 ipk 已进镜像,待下次刷机
  做冷启动复核。
- 已知非阻断日志(历史版本状态):空 M.2 插槽 PCIe link/BAR、TRNG 时钟探测、
  NPU IOMMU 时钟、NPU/IOMMU 地址重叠 EBUSY fallback、eth0 VLAN filter、
  Panthor cooling device、Wi-Fi板级 NVRAM fallback。其中除空 M.2 无端点外,
  其余已由后续 clean boot 修订处理。

### 2026-08-21 设备补齐修订(Mali 固件 + CAN 工具)

- squashfs.gz:`75be1f955ac56ddd7384f5e232039bcfc052266b709bb34c76a34e84bb821c83`
- ext4.gz:`2825f5009cc7ab71ee7698ac5f84e822398f35c12b8f5a32315c98231dc36da8`
- 内容:UVC、HYM8563 RTC、Panthor、CAN0/CAN1、RGA、Hantro、NPU DVFS、
  AP6275P Wi-Fi/BT;新增根文件系统固件 `mali_csffw.bin` 与
  `canutils-candump/cansend` 子包。
- 上板:前一级镜像已验证 RTC/UVC/CAN/GPU 固件热修复、NPU/CPU 动态频率、
  Wi-Fi 扫描与蓝牙 HCI;CAN0/CAN1 500 kbps loopback 收发通过。本修订整盘
  镜像完成构建与 SHA 校验,待下一轮刷入回归。
- 已知非阻断(历史版本状态):NPU 寄存器与 IOMMU 重叠导致 3 条 EBUSY
  fallback 日志;Panthor 禁止运行中卸载重载(会触发 power-domain SError),
  冷启动路径正常。clean boot 修订已处理 EBUSY 噪声。

### 2026-08-18 全功能重编(PCIe + TRNG 增补)

- squashfs.gz:`f98fa9d747ebe4d7f2c5da465c6e81ca750597c3e2f573491c189c0719411b21`(136 MB gz;解压整盘 `.img` 2.13 GiB 同目录,刷机用它)
- DTS 增补:**PCIe 三路**(3x4 + 2x1l0 + 2x1l2,引脚/供电取自 5.10 BSP:gpio4_PB6 / gpio1_PB4 / gpio3_PD1,vcc3v3_pcie30=GPIO3_C4)+ **&rng 显式启用**(LEDE 原生 trngv1 支持,此前"主线无 TRNG"系误判)
- 状态:构建成功(rc=0)、dts 链验证(pcie3x4=2 / trngv1=1 / vcc3v3×5 编进内核树);**未实机刷入**

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

### 2026-08-18 Agibot-Armbian 品牌与系统内开发历程版

- 文件:`Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img`
- 大小:`1,832,910,848` bytes（1.71 GiB）
- SHA-256:`df777c1e917174cd94fd779fcbbad3555d68c2a56edc5eb5898453408bb47ffa`
- 本地刷机目录:`flash/agibot-armbian/`
- 发行元数据:`Vendor: Agibot-Armbian`，`Maintainer: cennac <cennac@163.com>`；
  文件名、`/etc/issue` 和构建指纹三处一致。
- 系统文档:`/usr/share/doc/agibot/README.md`，并提供 `/root/README.md` 入口；
  内容归纳 2026-08-14 至 2026-08-18 的构建、启动、显示、USB、无线、音频、
  VPU/NPU、双网口和日志治理历程。
- 离线验收:`verify-image.sh` 12/12，`check-session-fixes.sh` 22/22；DTB、
  GMAC `rx_delay=0`、ACM8625P DSP、initramfs、服务、发行身份与文档全部通过。
- 状态:**构建和镜像内容验证完成，尚未单独刷入本品牌版**。其硬件功能内容与
  已上板验证的 `rx-delay-clean` 版一致，仅增加发行身份和系统内 README。

### 2026-08-18 重编(DMC 修复 + NPU 固化 + 全部当日修复,构建 commit 19ed37f)

- minimal(jammy):`89b5b2fad67778ab10d1215c61e3561000ca06f16882ea0c6084bd47e5e996fa`(1.71 GiB,`armbian-build/output/images/`)
- desktop(noble+xfce):`2e175a049573eda927c3233003f6e8f0867b22184d962e2c4ff0a62094ad92d4`(5.43 GiB)
- 内容(两镜像均镜像内 fdtget/ls 实证):**DMC/DFI 修复**(dfi 4×pclk_ddr_mon → devfreq/dmc)、
  **pcie3x4 ranges 5.10 残留清理**、**NPU 开箱即用**(librknnrt 1.5.2 + mobilenet/resnet18
  双模型 + cp310/cp312 wheels + agibot-npu-setup 首启自装 rknnlite 服务,enabled)、
  既有全部修复(uart5 禁用/Type-C adb opt-in/BT attach 等)
- 构建流水线修复(11 次迭代):ref2info git-bare 兜底 + apt 代理分流 + ldconfig 容错
  (见 docker-build.sh 头注释与 scripts/patch-*.py)
- 状态:构建成功、镜像内容验证;**未实机刷入**(刷机方式同旧版:Loader@0xCCCCCCCC + img@0)

### 2026-08-16 板载 U-Boot P986b(按键恢复版,就地上板)

- U-Boot hash:`2017.09-S39cd-P986b-Hbe55-Vecf7-B5da4-R448a`(fwver uboot-rmbian-201-08/16/2026)
- adc-keys 节点带 `u-boot,dm-spl` → **SW9200 下载键恢复**(按住上电进 Loader/Maskrom)
- 上板方式:SSH dd 引导区就地升级(备份在板 `/root/bootregion-pre-btn.bak`),
  非整盘重刷;rootfs/kernel 仍为 f850 系稳定件
- 验证:不按键冷启动 ✓、按键进下载模式 ✓、回归 PASS=23/FAIL=0
- deb:`armbian-build/output/debs/linux-u-boot-agibot-vendor_...S39cd-P986b...deb`
- 注意:同日 P9703 版(无标记节点)已弃用——fdtgrep 会剥掉无标记节点,按键无效

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
