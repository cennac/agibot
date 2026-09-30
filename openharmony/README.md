# OpenHarmony(开源鸿蒙)适配路线 — AGIBOT MB0002 V2

> 状态:**P0+P1 编译双通过(2026-09-30),agibot 首版镜像组已产出,待刷机实机验证**
> 快速上手 → **[docs/03-build-guide.md](docs/03-build-guide.md)**(66 容器全流程复现手册)

## 这条路线是什么

与 `armbian-build/`(通用 Linux)、`openwrt/`(路由固件)、`android14/`(安卓)并列的
第四条 OS 路线:把 **OpenHarmony 标准系统**(开源鸿蒙,ArkUI 界面)移植到
AGIBOT MB0002 V2(RK3588)。

需要先澄清一个容易踩的预期差:

- **HarmonyOS NEXT**(华为商用闭源版)**不可能**移植到第三方硬件,本路线与它无关;
- 能移植的是 **OpenHarmony** 开源版:可启动 ArkUI 桌面、安装 hap 应用、验证
  鸿蒙原生开发,但**没有**华为移动服务/应用市场等商用生态。

定位:带屏智能终端 / HMI / ArkTS 原生应用开发验证板。**不替代** `openwrt/`
路由用途(OpenHarmony 不是路由系统,无 nftables/透明代理生态)。

## 当前成果(2026-09-30)

| 里程碑 | 结果 |
|---|---|
| P0 参考板基线(OPi5Plus) | ✅ 36865/36865 目标,全镜像组,ninja 8797s |
| P1 agibot 首版 | ✅ 70890 目标(AGIBOT4 rc=0),`rk3588-agibot-mb0002-v2.dts` 一次通过 dtc |
| 产物 | 66:`/data/openharmony/oh/out/agibot/packages/phone/images/`(SHA256 清单在 66 `/data/openharmony/archive/`) |
| 实机验证 | ⏳ 待 maskrom 刷机(android14/docs/16 流程) |

基线 = OpenHarmony 6.0-Release + **OH 官方 linux-6.6 内核** + OPC 104MB
Rockchip vendor 补丁(Git LFS)+ agibot 板级层。loader 混合方案:agibot 原厂
SPL v1.16.113(DDR 正确)+ OPC OH 版 u-boot。

## 目录结构

```
openharmony/
├── README.md                       # 本文件
├── docs/
│   ├── 00-evaluation.md            # 适配评估(2026-09-30,历史结论存档)
│   ├── 01-dts-port-notes.md        # dts 移植核对单(V1-V6)与固件来源
│   ├── 02-p0-report.md             # P0/P1 报告:实测勘误、8 条环境修复、已知限制
│   └── 03-build-guide.md           # 构建手册:66 容器零起步复现 + 坑速查表
├── baseline/
│   ├── opc-openharmony-6.0.json    # 基线锁定(仓 revision + 环境修复清单)
│   └── manifest-locked-6.0.xml     # repo manifest -r 快照(469 行)
├── dts/
│   └── rk3588-agibot-mb0002-v2.dts # AGIBOT OH dts(dtc 已验证;实机未验)
└── scripts/env-fixes/              # 环境复现与一次性修复脚本(13 个,带 README)
```

与 `android14/` 相同的约定:只入库代码与文档,**不**包含完整 OpenHarmony
源码检出、预编译镜像或编译产物(产物与完整日志归档在 66 服务器
`/data/openharmony/archive/`)。

## 已知限制(详单见 02 报告末节)

- 6 个系统 hap 摘除(权限弹窗/系统对话框等):待 ci.openharmony.cn 恢复后取
  ohos-sdk-full 回滚;
- u-boot 为 OPi5Plus 版(SPL 已管 DDR,但 uboot 阶段板级外设参数如有异常需换
  agibot 自编译版,素材在仓库 `u-boot/` + android14 patches);
- ACM8625P 音频(P2 移植 codec 驱动)与 USB hub reset(P1.5)按纪律暂缓。

## 参考链接

- [OPC 移植社区(Gitee 组织页,含兼容性矩阵)](https://gitee.com/ohos-porting-communities)
- [OpenHarmony 5.0.0 移植 Orange Pi 5 Plus 实测教程(技术生博客)](https://blog.xiaoxiaozhou.top/archives/openharmony-for-orangepi)
- [香橙派 5 Plus/5B 通过 OpenHarmony 兼容性认证(迅龙软件)](http://www.orangepi.cn/html/news/news-details/news37.html)
- [OHDG 开发者组(Gitee)](https://gitee.com/openharmony-dg)
