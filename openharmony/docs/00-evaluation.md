# OpenHarmony 适配评估 — AGIBOT MB0002 V2

> **历史存档(立项前评估)**。P0 实测对本文有 3 处重要勘误:实际基线为
> OpenHarmony 6.0-Release(非 5.1.0R)、内核为 OH 官方 linux-6.6(非 5.10)、
> WiFi 同款风险已实锤解除。以 [02-p0-report.md](02-p0-report.md) 与
> [03-build-guide.md](03-build-guide.md) 为准。

- 日期:2026-09-30
- 结论:**可行,建议立项 P0(基线流程验证),P0 产出后再决策 P1 板级移植**
- 预估工作量:P0 约 1–2 人日,P1 约 2–5 人日,P2 按外设逐项 0.5–2 人日
  (不含编译等待;首次全量编译在 66 服务器 20 线程下预计数小时到半天)

## 1. 术语澄清:能移植的只有 OpenHarmony

"鸿蒙"有两个东西:

| | HarmonyOS NEXT | OpenHarmony(开源鸿蒙) |
|---|---|---|
| 性质 | 华为商用闭源系统 | 开放原子开源基金会开源项目 |
| 能否移植第三方硬件 | **不能**(无源码、不对第三方硬件发布) | **能**(本路线对象) |
| 生态 | 华为移动服务/应用市场 | hap 应用、ArkTS/ArkUI 原生开发 |

预期管理:移植成功后得到的是"OpenHarmony 标准系统"——ArkUI 桌面、系统应用、
hap 安装能力;**不是**手机版鸿蒙,没有华为商用生态。

## 2. 为什么可行

### 2.1 同 SoC 成熟先例(不是从零起步)

- 开源移植社区 **OPC**(ohos-porting-communities,Gitee/GitCode)的兼容性矩阵:
  **Orange Pi 5 Plus(RK3588)** 在 OpenHarmony 4.0R–5.1.0R 上
  显示/GPU/WiFi/USB/音频全部可用(无触摸屏),5.1.0R 蓝牙/软总线/硬解可用;
- Orange Pi 5 Plus / 5B 已于 2024-09 通过 OpenHarmony **兼容性认证**;
- OPC 维护着完整的移植层四仓,且分支跟到 OpenHarmony 6.0-Release
  (6.1R 起迁至 GitCode);触觉智能等厂商亦已把 RK3588 适配到 6.0。

移植层四件套(参考板 Orange Pi 5 Plus):

| 仓库 | 位置 | 作用 |
|---|---|---|
| `vendor_opc` | GitCode | 产品配置(分区、特性、安全配置) |
| `device_board_opc` | GitCode | 板级目录(dts 挂接、烧写配置、补丁) |
| `device_soc_opc` | GitCode | SoC 公共层 |
| `linux_5.10_opi` | Gitee | 内核(Rockchip 5.10 BSP 系,分支含 5.1.0-Release) |

社区实测流程(OPi5Plus, OH 5.0.0):repo sync 后仅三处强制修改即可出镜像——
① `build/` 打 `device/board/opc/common/patches/001-build.diff`;
② `vendor/opc/opi5plus/config.json` 删 `init_feature_loader`;
③ `sanitizer_check_list.gni` 换 hihope 版。刷机必须先整片擦除 eMMC(RKDevTool)。

### 2.2 本板硬件与参考板同源度高

| 部件 | AGIBOT MB0002 V2 | Orange Pi 5 Plus | 复用判断 |
|---|---|---|---|
| SoC | RK3588(4×A76+4×A55, Mali-G610) | RK3588 | 完全一致 |
| PMIC | RK806 | RK806 | 电源树可直接复用 |
| 启动 | eMMC-only,maskrom/RKDevTool | eMMC | 流程本仓库已验证 |
| 以太网 | 双原生 GMAC + RTL8211F(RGMII) | 有 | 5.10 树 dwmac-rk 原生支持 |
| WiFi/BT | AP6275P(BCM43752,PCIe)+BT UART | WiFi6 Broadcom 系模块 | 待 P0 核对;bcmdhd 5.10 社区有 |
| 显示 | HDMI(已验证) | HDMI/DP | 5.10 rockchip-drm + Mali DDK 随参考板验证过 |
| 音频 | ACM8625P(i2c 0x15 + i2s1_8ch) | 通用 | codec 驱动需移植(P2,后置) |

### 2.3 仓库内既有资产(直接复用)

- `android14/`(Radxa RKR6,vendor **6.1**)内已有完整 AGIBOT 内核 DTS
  (`patches/0004`/`0011`)、AGIBOT U-Boot 早期引导(`0001`–`0003`)、
  maskrom 全刷与救砖验证(`docs/16`)、驱动实测记录(`docs/17`);
- `openwrt/` 路线内有主线 6.12 DTS 与 ACM8625P codec 驱动、
  双 GMAC VLAN hash 规避(`snps,no-vlhash`)等硬件结论;
- 本机另有原厂反编译 DTS 与原厂 kernel config(未入库,需要时可入库)。

板级移植的主要工作 = 把 vendor 6.1 DTS 的板级差异**重放**到 OPC 的 5.10 树
(以树内 OPi5Plus dts 为底座替换节点,6.1 DTS 作为参数权威来源,而非直接拷贝)。

## 3. 资源评估(66 服务器)

| 资源 | 需求 | 66 现状 | 判断 |
|---|---|---|---|
| 磁盘 | 300–512 GB | /data 空闲 1.8 TB | 充足 |
| 内存 | 最低 32 GB,链接阶段峰值 ~24 GB,推荐 64 GB | 45 GB(常态被 llama-server 等占 30 GB) | 需编译窗口期停 llama-server,或吃 21 GB swap(变慢) |
| CPU | — | 20 线程 | 首次全量编译数小时~半天 |
| 主机 OS | Ubuntu 20.04/22.04 | Ubuntu 26.04 | 用 Docker ubuntu:22.04 容器(仓库已有同模式先例) |
| 网络 | Gitee/GitCode/GitHub | 直连可用 | 无阻碍 |

## 4. 分期计划

### P0 — 基线流程验证(1–2 人日,不动 AGIBOT 任何代码)

1. 66 上起 ubuntu:22.04 容器,repo sync OpenHarmony 5.1.0 Release + OPC 四仓;
2. 按社区实测打三处强制修改,**原样编译 OPi5Plus 镜像**(产物只验完整性,不刷机);
3. 在源码树内核对两件事:`linux_5.10_opi` 里 OPi5Plus 的 WiFi 模块/驱动形态
   (是否同为 AP6275P/BCM43752,PCIe bcmdhd 还是 SDIO),ACM8625P 所需 ASoC
   接口与 5.10 树差异;
4. 锁定各仓 revision,回填 `baseline/opc-openharmony-5.1.0.json`;
5. 输出 go/no-go 结论。

### P1 — 板级首启(2–5 人日)

- 内核树新增 `rk3588-agibot-mb0002-v2.dts`(6.1→5.10 重放:GMAC delay、
  eMMC、HDMI、USB、PCIe、RK806 电源树;WiFi 节点视 P0 结论);
- `device_board_opc` 以 opi5plus 为模板新增 agibot 产品目录,
  `vendor_opc` 对应配置(分区按 eMMC 容量);
- 出镜像 → maskrom 整擦刷机(流程复用 `android14/docs/16`);
- 验收:串口日志到 init,HDMI 出 ArkUI 桌面(GPU 合成正常)。

### P2 — 外设补全(按需,每项 0.5–2 人日)

- 双 GbE:5.10 树 dwmac-rk + RTL8211F 驱动应已具备,配置 RGMII delay 与
  `snps,no-vlhash` 即可;OpenHarmony 侧以太网由网络管理栈接管;
- ACM8625P 音频:codec 驱动从主线版移植到 5.10 ASoC(仓库内有现成参考实现);
- WiFi/BT:bcmdhd + OpenHarmony WiFi HAL;BT 参考 `openwrt/package/agibot/agibot-bt-attach` 的 UART attach 思路;
- 触摸(若外接触屏)。

### P3 — 进阶(可选)

- 升级 OpenHarmony 6.0/6.1(GitCode 侧分支);
- RKNN NPU 在 OpenHarmony 上启用(参考 `android14/patches/0005` 的 rknn userspace 思路);
- 兼容性认证(无商业需求则跳过)。

## 5. 风险清单

| # | 风险 | 概率 | 缓解 |
|---|---|---|---|
| 1 | WiFi 模块驱动复用不确定(AP6275P=BCM43752 PCIe FullMAC) | 中 | P0 在源码树内核对;最坏情况退化为仅以太网/外接 USB 网卡,不阻塞首启 |
| 2 | DTS vendor 6.1→5.10 语法/驱动差异 | 中 | 以 5.10 树内 OPi5Plus dts 为底座重放节点,逐节点比对 |
| 3 | 链接期内存不足(峰值 ~24 GB) | 中 | 编译窗口停 llama-server;或加 swap 接受变慢;夜间跑 |
| 4 | OpenHarmony 上游/OPC 仓库迁移(6.1R 起迁 GitCode) | 低 | baseline 锁 5.1.0 Release 各仓 revision |
| 5 | ACM8625P codec 驱动 5.10 移植量超预期 | 低 | P2 后置,不阻塞 P0/P1 |
| 6 | 刷机变砖 | 低 | maskrom 救砖路径本仓库已实测(`android14/docs/16`) |
| 7 | 生态预期落差(非 HarmonyOS NEXT) | 认知 | README 顶部已明示 |

## 6. 与既有路线的取舍

- 只要"跑安卓应用/HMI":`android14/` 已到 r22,直接用,无需本路线;
- 要"鸿蒙原生开发/ArkTS/hap/软总线":只有本路线能覆盖;
- 路由/网关用途:仍是 `openwrt/`,OpenHarmony 不具备该定位。

三条路线互补,本路线不挤占既有产物的维护。

## 7. 参考

- [OPC 移植社区组织页(Gitee,含各板兼容性矩阵与仓库迁移公告)](https://gitee.com/ohos-porting-communities)
- [OPC 内核仓 linux_5.10_opi(Gitee,分支至 OpenHarmony 6.0-Release)](https://gitee.com/ohos-porting-communities/linux_5.10_opi)
- [OpenHarmony 5.0.0 移植 Orange Pi 5 Plus 全流程实测(技术生博客)](https://blog.xiaoxiaozhou.top/archives/openharmony-for-orangepi)
- [香橙派玩机指南:OrangePi 5 Plus 上的 OpenHarmony(知乎,OPC 介绍)](https://zhuanlan.zhihu.com/p/13079363567)
- [OrangePi 5 Plus/5B 通过 OpenHarmony 兼容性认证(迅龙软件)](http://www.orangepi.cn/html/news/news-details/news37.html)
- [OHDG OpenHarmony 开发者组(Gitee)](https://gitee.com/openharmony-dg)
- [触觉智能 OpenHarmony 6.0 适配 RK3588 等 SoC(CSDN)](https://blog.csdn.net/Industio_CSDN/article/details/148791363)
