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

## 风险边界

- 当前 AGIBOT DTB 来自 OpenWrt 6.12 树。运行时 DTB 不要求与内核版本完全一致，但个别
  新节点仍可能不匹配；首通标准只看 eMMC、串口、双网口和 fnOS 服务。
- HDMI、NPU、音频、摄像头、蓝牙等非存储功能不作为首刷阻断项。需要时再用 fnOS 6.18
  内核源码重编 AGIBOT DTS。
- AGIBOT U-Boot 已在 OpenWrt 镜像验证，fnOS 的 `boot.scr` 路径仍需上板确认；其 RK3588
  eMMC、ext4 和通用发行版启动能力是已知的。
- 首启失败时先保存完整 UART 日志，再只改一个变量，避免把引导、DTB 和 fnOS 服务混在
  同一轮排查里。
