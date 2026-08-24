# 飞牛 fnOS 适配记录：AGIBOT MB0002 V2

本文记录把官方 fnOS Rock 5B 镜像移植到 AGIBOT MB0002 V2(RK3588)的首启方案。
原则是保留 fnOS 官方 rootfs、GPT 和分区 UUID，只替换板级启动链与设备树，把第一刷
变量压到最少。

## 结论

fnOS ARM 版不是完全通用的镜像，但 Rock 5B 版结构对本板很有利：

- fnOS 用户态、内核、模块和服务都在官方 rootfs 内，可直接复用。
- 板差异集中在镜像前 32 MiB 启动区、`fnEnv.txt` 的 `fdtfile`，以及可选的 `/etc/device_info/boot_board`。
- AGIBOT 已实机验证的 U-Boot 能初始化同板 eMMC/DRAM，并保留 SW9200 下载链路。

首版不建议把 fnOS 载荷注入 Armbian，也不建议重打包 rootfs。直接对官方 Rock 5B
镜像做“启动区手术”成功率更高，失败时也容易回滚。

## 官方基线

下载源：

```text
http://thunder.liveupdate.fnnas.com:8080/arm/image/1.2.0302/rock-5b/fnos_Mainland-PE_arm_1.2.0302_rock-5b_2288.img.gz
```

本地已解压基线：

```text
E:\AIPorject\101\_tmp\fnos\fnos-rock-5b.img
MD5: 36ef67cdebb5700d8088cf94d8706d64
```

分区结构：

| 区域 | 偏移 | 大小 | 内容 |
|---|---:|---:|---|
| Rockchip 启动区 | 0 | 32 MiB | GPT、idbloader、U-Boot FIT |
| p1 `BOOT` | 32 MiB | 370 MiB | ext4，boot 分区 |
| p2 `rootfs` | 418 MiB | 3.2 GiB | btrfs，fnOS rootfs |

p1 分区根目录包含 `fnEnv.txt`、`boot.scr`、`vmlinuz-*` 和 `dtb/`。目标机正常挂载时
路径表现为 `/boot/fnEnv.txt`；脚本直接挂载 p1 时这些文件在挂载点根目录。

`boot.cmd` 是通用脚本：加载 `${prefix}dtb/${fdtfile}`，用 `PARTUUID` 找 p2，RK3588
自动启用 `ttyS2,1500000`。因此不需要改 `boot.scr`，也不需要改 rootfs UUID。

## 手术策略

使用 `artifacts/lede-clean-boot-20260821` 中已实机验证的资产：

| 资产 | 写入位置 | 作用 |
|---|---:|---|
| `agibot-rk3588-idbloader.img` | 32 KiB / LBA 64 | AGIBOT DRAM 初始化与 SPL/TPL |
| `agibot-rk3588-u-boot.itb` | 8 MiB / LBA 16384 | AGIBOT U-Boot、eMMC 访问、SW9200 Loader |
| `rk3588-agibot-mb0002-v2.dtb` | `dtb/rockchip/` | AGIBOT 板级外设描述 |

两个启动二进制必须分别写入。不要把其他镜像的整段 32 MiB 启动区覆盖进来，否则会破坏
官方 GPT 和分区 UUID。

生成命令：

```sh
wsl -u root -e bash /mnt/e/AIPorject/101/agibot-armbian/scripts/make-fnos-agibot.sh
```

脚本会：

1. 校验官方 fnOS 镜像与三个 AGIBOT 资产的哈希。
2. 复制官方镜像，保留 GPT、PARTUUID、boot/rootfs UUID。
3. 分别写入 AGIBOT idbloader 和 U-Boot FIT。
4. 把 AGIBOT DTB 复制到官方 `dtb/rockchip/`。
5. 把 `fnEnv.txt` 改为 `fdtfile=rockchip/rk3588-agibot-mb0002-v2.dtb`。
6. 只读检查 ext4 元数据，输出分区表和最终 SHA-256。

产物：

```text
E:\AIPorject\101\_tmp\fnos\fnos-agibot-mb0002-v2.img
E:\AIPorject\101\_tmp\fnos\fnos-agibot-mb0002-v2.img.sha256
SHA-256: 4437fa3dca7facd037bcf5d7a1aaa4095620a9d8021e955d40ca231fdd76cec8
```

独立复核已确认：

- idbloader 与 U-Boot FIT 在目标偏移逐字节匹配源资产。
- DTB 哈希匹配，模型字符串为 `AGIBOT MB0002 V2`。
- `fnEnv.txt` 指向 AGIBOT DTB，内核仍为 `vmlinuz-6.18.18.c951-trim`。
- p1 UUID 仍为 `d1f4756c-d661-4c99-9511-2174ff6e29e7`。
- p2 UUID 仍为 `4ddd2ee5-5306-484b-b2b3-06f7d5dc8a87`。

首版 rootfs 保持零改动，尤其先不要改：

```text
/etc/device_info/boot_board=rock-5b
```

等 eMMC、网络和 fnOS Web 服务确认后，再把 `agibot-mb0002-v2` 作为第二阶段变量测试。

## 刷机与回滚

刷机方式与现有 AGIBOT Linux 镜像相同：

1. 通过 SW9200 或既有救援路径让板子进入 MASKROM/LOADER。
2. RKDevTool 添加 `flash/rk3588_spl_loader_v1.16.113.bin`，地址 `0xCCCCCCCC`。
3. 添加 `fnos-agibot-mb0002-v2.img`，地址 `0x00000000`。
4. 执行写入，完成后重启。

刷机前确认原厂 eMMC 备份和 SW9200/RKDevTool 恢复流程可用。若首启停在 U-Boot 或
rootfs 挂载前，走既有恢复链路，不要连续叠加修改。

## 首启验收

串口接 UART2，参数 `1500000 8N1`。按顺序看：

1. AGIBOT U-Boot 启动并识别 eMMC。
2. `boot.scr` 加载 `rockchip/rk3588-agibot-mb0002-v2.dtb`。
3. fnOS 6.18 内核启动，并按 PARTUUID 挂载 btrfs rootfs。
4. 串口登录或 SSH 可用。
5. 两个 RTL8211F 千兆网口枚举。
6. `triminit`、`trim` 及相关 `trim_*` 服务进入运行状态。
7. fnOS Web 初始化页面可访问。

首次登录后的检查：

```sh
uname -a
cat /proc/device-tree/model
ip -br link
systemctl --no-pager --failed
systemctl --no-pager status trim triminit
journalctl -b 0 --no-pager -p warning
```

## NPU / GPU

官方 fnOS 6.18 内核已经包含 `rknpu.ko`、Rockchip GPU 模块，并启用
`CONFIG_DRM_PANTHOR=m`。本仓库另外保存了针对 fnOS 6.18 重新编译的板级 DTS/DTB：

```text
fnos/rk3588-agibot-mb0002-v2-6.18.dts
fnos/rk3588-agibot-mb0002-v2.6.18.dtb
```

远端 `/data/fnos-3588` 已用该 DTB 生成 `fnos-agibot-mb0002-v4.img`，镜像 SHA-256：

```text
d74608b5b23d69f9b892e362770434083ca3dcba339e546a4c2737bfb6d7fc33
```

说明:v4 首次生成的 `.sha256` 是镜像完全落盘前的旧值,以上为远端和本地重新计算后的最终值。

首启后检查 NPU/GPU：

```sh
dmesg | grep -Ei 'rknpu|npu|panthor|mali'
lsmod | grep -E 'rknpu|rkgpu|panthor'
ls -l /dev/dri/renderD*
```

NPU 设备通常通过 DRM render 节点暴露，不一定存在 `/dev/rknpu`。

## GPU / VPU 修复

2026-08-23 板友反馈 GPU 未运行、硬解不可用。离线对照后确认不是 fnOS 缺驱动：

- fnOS rootfs 没有 `panthor.ko`，实际提供 `rkgpu_bifrost_csf.ko`；该模块匹配
  `rockchip,rk3588-mali-csf` / `arm,mali-valhall`。
- 原主线风格 GPU 节点写的是 `rockchip,rk3588-mali` / `arm,mali-valhall-csf`，
  因此 GPU 模块不会自动 probe。
- fnOS 的 `/usr/trim/lib/mediasrv/ffmpeg` 已启用 `--enable-rkmpp --enable-rkrga`，
  用户态库包含 `librockchip_mpp.so`。
- 硬解还需要 `rk_vcodec.ko` 创建 MPP service；原主线 DTB 缺少 vendor 版
  `mpp-srv`、RKVDEC 双核、AV1/JPEG 解码和 RGA 节点。

修复产物：

```text
fnos/rk3588-agibot-mb0002-v2.6.18-gpu-vpu.dtb
fnos/agibot-gpu-vpu.dtso
fnos/agibot-gpu-vpu.dtbo
```

已在离线 DTB 中确认：

```text
/gpu@fb000000 compatible = "rockchip,rk3588-mali-csf", "arm,mali-valhall"
/mpp-srv compatible = "rockchip,mpp-service"
/rkvdec-core@fdc38000 compatible = "rockchip,rkv-decoder-v2"
/rkvdec-core@fdc48000 compatible = "rockchip,rkv-decoder-v2"
/rga@fdb60000 compatible = "rockchip,rga3_core0"
/rga@fdb70000 compatible = "rockchip,rga3_core1"
/rga@fdb80000 compatible = "rockchip,rga2_core0"
/video-codec@fdc70000 compatible = "rockchip,av1-decoder"
```

Overlay 同时补齐 `vdpu@fdb50400`、JPEGD、AV1D MMU、RKVDEC CCU/双核、
两颗 RGA3 和对应 IOMMU/SRAM。RGA2 主线节点也被改成 fnOS vendor 驱动使用的
`rockchip,rga2_core0`，否则 `librga` 的格式转换/零拷贝路径仍不可用。

板上免重刷安装：

```sh
sudo cp rk3588-agibot-mb0002-v2.6.18-gpu-vpu.dtb \
  /boot/dtb/rockchip/rk3588-agibot-mb0002-v2.6.18-gpu-vpu.dtb
sudo sed -i \
  's#^fdtfile=.*#fdtfile=rockchip/rk3588-agibot-mb0002-v2.6.18-gpu-vpu.dtb#' \
  /boot/fnEnv.txt
sudo reboot
```

重启后验证：

```sh
uname -r
cat /proc/device-tree/model
cat /proc/device-tree/gpu@fb000000/compatible
ls /proc/device-tree/mpp-srv
sudo modprobe rkgpu_bifrost_csf
sudo modprobe rk_vcodec
ls -l /dev/dri/renderD* /dev/mpp_service
lsmod | grep -E 'rkgpu|rk_vcodec'
dmesg | grep -Ei 'mali|rkgpu|mpp|rkvdec|vpu'
ls -l /dev/rga /dev/mpp_service
LD_LIBRARY_PATH=/usr/trim/lib/mediasrv/lib \
  /usr/trim/lib/mediasrv/ffmpeg -decoders 2>/dev/null | grep rkmpp
```

注意：系统升级到 `6.18.18.c963-trim` 后，必须确认新版内核目录里仍有同名模块：

```sh
find /lib/modules/$(uname -r) -type f \
  | grep -E 'rkgpu_bifrost_csf|rk_vcodec|rga3|rknpu'
```

如果模块缺失或 `modinfo -F vermagic` 不是当前 `uname -r`，优先修复 fnOS
内核/模块包同步问题；DTB 只负责让模块 probe，不能替代缺失的 `.ko`。

## 蓝色散热兼容板网口差异

2026-08-24 收到蓝色散热兼容板整盘备份：

```text
E:\AIPorject\101\RK3588-backup\RK3588_蓝色散热_纯净系统_20260816.img.gz
```

直接从 gzip 流中读取 GPT，无需解出整盘：`boot` 分区起点为 LBA 32768
(16 MiB)，长度 64 MiB。该分区是 Rockchip boot FIT，外层 metadata 写明
`fdt data-position=0x800`、`data-size=0x269a0`。按这两个值抽取 FDT：

```text
FDT SHA-256: cc229d9cbeebac4ea936fe39aab66e41c5111f3cc345cda69639f22064b02013
```

该值与 FIT 内 `fdt` image 的 SHA-256 完全一致。它与本仓库既有
`dev-resources/boot/fdt.dtb` 反编译后只差开机 logo 显示模式
(`center` vs `fullscreen`)，两个 GMAC/PHY 配置完全一致，可作为同类硬件
对照证据。

### GMAC 对照

| 属性 | 蓝色板原厂 GMAC0 `fe1b0000` | fnOS v5 GMAC0 | 结论 |
|---|---|---|---|
| `phy-mode` | `rgmii-rxid` | `rgmii-rxid` | 一致 |
| `clock_in_out` | `input` | `output` | 关键差异 |
| `tx_delay` | `0x43` | `0x43` | 一致 |
| `rx_delay` | 缺失 | `0x00` | 等效 |
| PHY 地址 | `1` | `1` | 一致 |
| PHY reset | GPIO4_D5 active-low | GPIO4_D5 active-low | GPIO 一致 |

GMAC1 `fe1c0000` 的 `phy-mode`、`tx_delay=0x42`、PHY 地址 `0`、GPIO4_D4
复位也一致。原厂 GMAC0 为 `"input"`；原厂 GMAC1 写的是拼写错误的
`"intput"`，不是 `"input"`。

fnOS 6.18 `dwmac-rk.c` 只有字符串完全等于 `"input"` 才把
`clock_input=true`；`"output"`、`"intput"` 和其它值都会走
`clock_input=false`。RK3588 驱动据此选择：

- `input`: `RK3588_GMAC_CLK_SELECT_IO`，RGMII 时钟由外部 PHY 输入 MAC；
- 非 `input`: `RK3588_GMAC_CLK_SELECT_CRU`，MAC/CRU 向 PHY 输出时钟。

因此 v5 的 GMAC0 `output` 会把蓝色板原厂按 PHY 供时钟设计的 GMAC0 配成
相反方向，这是目前最强的网口无链路疑点。`rx_delay` 不是根因：`rgmii-rxid`
路径固定调用 `set_to_rgmii(tx_delay, 0)`；DTB 二进制属性 `0x00000000`
用文本工具查看时会像空值，需要用 `fdtget -t x` 或 `hexdump` 确认。

### v6 单变量测试镜像

为避免一次改多个变量，新增 overlay 只把 GMAC0 改回 `"input"`，GMAC1
保持 v5 的 `"output"`，并保留 GPU/VPU 修复：

```text
fnos/agibot-gmac0-rx-clock-input.dtso
fnos/agibot-gmac0-rx-clock-input.dtbo
fnos/rk3588-agibot-mb0002-v2.6.18-gpu-vpu-blue-gmac0-input.dtb
DTB SHA-256: 30c04f24f9b40850ca1d8c02c62e9766ed7a76b34e8f1706a20c3175fce9e29b
```

远端 `/data/fnos-3588/out/fnos-agibot-mb0002-v6-blue-gmac0-input.img`
与本地产物 `E:\AIPorject\101\_tmp\fnos\` 使用同一镜像：

```text
SHA-256: 699ef7bd6b978f2bc27982e27ba854c59087ff4b932aca29e3b02f3541aa0147
```

离线复核已确认：boot 分区 `fnEnv.txt` 指向上述 DTB；DTB 中 GMAC0 为
`input`、GMAC1 为 `output`；idbloader 和 U-Boot FIT 与已验证资产逐字节
一致。当前银色散热板 v5 的 `end0` 已实测 1000 Mb/s 正常，所以 v6 是蓝色板
测试分支，不能反过来证明银色板也应改成 `input`。

蓝色板刷入 v6 后优先采集：

```sh
ip -br link
ip -br addr
dmesg | grep -Ei 'stmmac|dwmac|gmac|mdio|rtl8211|phy|clock input|TX delay|RX delay'
```

若 GMAC0 恢复 carrier/DHCP，根因即可确认。若仍无链路，下一轮只比较复位
时序；若板边网口也失效，再单独做 GMAC1 `"input"` 测试 DTB，不能直接复制
原厂拼写错误的 `"intput"`。

### v6 蓝色板实机结果

2026-08-24 蓝色板刷入 v6 后，接口与控制器映射得到确认：

```text
end0 -> /sys/devices/platform/fe1b0000.ethernet -> GMAC0
end1 -> /sys/devices/platform/fe1c0000.ethernet -> GMAC1
```

远离 HDMI 的物理网口是 `end1` / GMAC1。该口保持 `clock_in_out="output"`，
RTL8211F 正常绑定并多次协商到 `1Gbps/Full`。靠近 HDMI 的 `end0` / GMAC0
虽然也识别到 `RTL8211F Gigabit Ethernet`，但在 v6 的 `input` 模式下失败：

```text
fe1b0000.ethernet: clock input or output? (input)
fe1b0000.ethernet: clock input from PHY
fe1b0000.ethernet end0: PHY [stmmac-0:01] driver [RTL8211F Gigabit Ethernet]
fe1b0000.ethernet end0: Failed to reset the dma
fe1b0000.ethernet end0: stmmac_hw_setup: DMA engine initialization failed
fe1b0000.ethernet end0: __stmmac_open: Hw setup failed
```

这否定了“蓝色板在 fnOS 6.18 下只需把 GMAC0 改成 input”的假设。原厂 5.10
DTB 的 `input` 描述不能直接套用到 fnOS 6.18 的初始化顺序；MAC 打开时没有可用
输入时钟，DMA reset 无法完成。v6 应保留为诊断版本，不作为蓝色板正式镜像。

GMAC1 在 v6 中没有修改，所以远离 HDMI 网口本次恢复不能归因于 GMAC0 overlay。
下一步回到 GMAC0 `output`（v5 已是双 `output`）复测双口，并针对 GMAC0 单独
检查 PHY reset 时序和重复启动稳定性；当前没有证据支持把 GMAC1 改成 `input`。

### v7 双 output / PHY 500 ms 测试镜像

v4 和 v5 成品镜像的实际 boot DTB 已逐项比较：两个版本的 GMAC0/GMAC1 都是
`output`，TX/RX delay 和 PHY 地址相同，内核也同为 `6.18.18.c951-trim`；v5
增加的 GPU/VPU overlay 没有修改 GMAC 节点。鉴于 v5 一次启动双口失效、v6
未修改的 GMAC1 又恢复千兆，按 PHY 上电时序不稳定继续做单变量测试。

v7 以 v5 GPU/VPU DTB 为基础：

```text
GMAC0 clock_in_out = "output"
GMAC1 clock_in_out = "output"
GMAC0 PHY reset-deassert-us = 500000
GMAC1 PHY reset-deassert-us = 500000  # v5 为 100000
```

新增产物：

```text
fnos/agibot-gmac1-reset-500ms.dtso
fnos/agibot-gmac1-reset-500ms.dtbo
fnos/rk3588-agibot-mb0002-v2.6.18-gpu-vpu-gmac-reset-500ms.dtb
DTB SHA-256: ee0d010fcc683414e60179f45ae0c3e4495e8c66d2dde3bda32f6763c0e5e6b3

E:\AIPorject\101\_tmp\fnos\fnos-agibot-mb0002-v7-gmac-reset-500ms.img
SHA-256: 8f96e2338397bf8ee8adde000d13d523333b55d0bdc0c6adadd2927e928d5bde
```

远端和镜像 boot 分区均已复核双 `output`、双 500 ms，GPU/Mali 和 MPP 节点
仍保留。测试时应分别插远离 HDMI 的 `end1` 和靠近 HDMI 的 `end0`，至少执行
三次重启；每轮记录 `ip -br link` 及 GMAC/PHY dmesg，判断是否为重复启动时序问题。

## 风险边界

- 6.18 DTB 已重新编译并完成离线镜像注入验证，但仍需上板确认 NPU 的时钟、电源域和
  OPP 表与 fnOS 驱动完全匹配。
- HDMI、音频、摄像头、蓝牙等非存储功能不作为首刷阻断项；NPU/GPU 以设备节点和 dmesg
  为准做首启回归。
- AGIBOT U-Boot 已在 OpenWrt 镜像验证，fnOS 的 `boot.scr` 路径仍需上板确认；其 RK3588
  eMMC、ext4 和通用发行版启动能力是已知的。
- 首启失败时先保存完整 UART 日志，再只改一个变量，避免把引导、DTB 和 fnOS 服务混在
  同一轮排查里。
