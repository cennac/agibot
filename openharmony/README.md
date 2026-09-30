# OpenHarmony(开源鸿蒙)适配路线 — AGIBOT MB0002 V2

> 状态:**评估完成,待立项**(2026-09-30)。本目录暂不含任何已验证产物,
> 完整评估见 **[docs/00-evaluation.md](docs/00-evaluation.md)**。

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

## 评估结论(TL;DR)

**可行,建议先做 P0(基线流程验证),再决定是否投入板级移植。**

- 参考板 **Orange Pi 5 Plus**(同为 RK3588 + RK806)在开源移植社区 OPC 的
  兼容矩阵里 4.0R–5.1.0R 显示/GPU/WiFi/USB/音频全部可用,并已通过 OpenHarmony
  兼容性认证;
- 移植层是现成的四件套仓库(`vendor_opc` / `device_board_opc` /
  `device_soc_opc` / `linux_5.10_opi`),社区实测"改三个文件即可出镜像";
- 本板硬件与参考板高度同源,且本仓库 `android14/`(vendor 6.1)内已有完整
  AGIBOT 内核 DTS 与 maskrom 刷机/救砖验证,板级工作主要是 DTS 降级重放。

分期:P0 流程验证(1–2 人日)→ P1 板级首启(2–5 人日)→ P2 外设补全(按需)。
工作量与风险明细见评估文档。

## 目录结构(规划)

```
openharmony/
├── README.md                       # 本文件
├── docs/00-evaluation.md           # 适配评估(2026-09-30)
├── baseline/                       # 基线锁定(RFC,P0 锁 revision)
├── dts/                            # P1:linux-5.10 树的 AGIBOT DTS
├── patches/                        # P1:对 OPC 四仓的板级补丁
└── scripts/                        # P0+:容器同步/编译脚本
```

与 `android14/` 相同的约定:只入库代码与文档,**不**包含完整 OpenHarmony
源码检出、预编译镜像或编译产物。

## 参考链接

- [OPC 移植社区(Gitee 组织页,含兼容性矩阵)](https://gitee.com/ohos-porting-communities)
- [OpenHarmony 5.0.0 移植 Orange Pi 5 Plus 实测教程(技术生博客)](https://blog.xiaoxiaozhou.top/archives/openharmony-for-orangepi)
- [香橙派 5 Plus/5B 通过 OpenHarmony 兼容性认证(迅龙软件)](http://www.orangepi.cn/html/news/news-details/news37.html)
- [OHDG 开发者组(Gitee)](https://gitee.com/openharmony-dg)
