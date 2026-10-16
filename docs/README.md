# AGIBOT 文档索引

本目录存放全部专题文档。成品镜像与模型下载见
**[GitHub Release board-assets-20261016](https://github.com/cennac/agibot/releases/tag/board-assets-20261016)**;
仓库总览见 **[根 README](../README.md)**。

## 编译与刷机

- [BUILD-GUIDE.md](BUILD-GUIDE.md) — Armbian 编译教程(WSL2 四大坑 / 5 处框架 hack / 跨平台 / Docker)
- [BUILD-SERVER-66.md](BUILD-SERVER-66.md) — 66 服务器 Armbian 编译指南
- [BUILD-SERVER-66-LEDE.md](BUILD-SERVER-66-LEDE.md) — 66 服务器 LEDE 原生编译指南
- [MACOS-LEDE-BUILD.md](MACOS-LEDE-BUILD.md) — macOS 本机编译 LEDE/OpenWrt 记录
- [FAQ.md](FAQ.md) — 板子常见操作问答(进 Maskrom / 刷机 / 按键 / 调试安全)
- [RELEASES.md](RELEASES.md) — 镜像 SHA / 验收状态 / 废弃版本
- [IMAGE-ARCHIVE.md](IMAGE-ARCHIVE.md) — 本地镜像归档规范

## Bring-up 与硬件

- [ARMBIAN-LINUX-BRINGUP.md](ARMBIAN-LINUX-BRINGUP.md) — Armbian Linux 层 bring-up 全记录 + 刷机方法
- [UBOOT-BRINGUP.md](UBOOT-BRINGUP.md) — U-Boot bring-up
- [ADAPT-NOTES.md](ADAPT-NOTES.md) — 设备树 5.10 → 6.1 适配说明
- [DISPLAY-DTB-INCIDENT.md](DISPLAY-DTB-INCIDENT.md) — 显示 DTB v5 事故记录与恢复手册
- [HARDWARE-DISCOVERY-20260818.md](HARDWARE-DISCOVERY-20260818.md) — 硬件发现矩阵
- [HARDWARE-VALIDATION-20260818.md](HARDWARE-VALIDATION-20260818.md) — 硬件与驱动验收
- [BUILT-IN-DIAGNOSTICS-20260828.md](BUILT-IN-DIAGNOSTICS-20260828.md) — Armbian 内置硬件诊断工具方案
- [MASKROM-COM-ENTRY-20260828.md](MASKROM-COM-ENTRY-20260828.md) — 串口进入 Maskrom 实录
- [ARMBIAN-DF777C1E-BOARD-VALIDATION-20260828.md](ARMBIAN-DF777C1E-BOARD-VALIDATION-20260828.md) — df777c1e 版整板验收
- [AGIBOT-MB0002-PUBLIC-RESEARCH.md](AGIBOT-MB0002-PUBLIC-RESEARCH.md) — 板卡背景公开资料调研

## OS 路线(文档在各自子目录)

- 飞牛 fnOS:[FNOS-ADAPTATION.md](FNOS-ADAPTATION.md) 适配全记录;DTS / overlay 在 [`../fnos/`](../fnos/)
- Android 14:[../android14/README.md](../android14/README.md);阶段记录 `../android14/docs/00`–`60`
- OpenHarmony:[../openharmony/README.md](../openharmony/README.md);评估与 P0/P1 报告在 `../openharmony/docs/`
- OpenWrt / LEDE:[../openwrt/README.md](../openwrt/README.md)

## 板端运行记录(编号系列)

- [61 — MiniCPM-V CPU 基准(llama.cpp)](61-minicpmv-llm-bench-20261015.md)
- [62 — MiniCPM-V 4.7-1B 66ops 质量测试](62-66ops-quality-suite-minicpmv47-1b-20261015.md)
- [63 — RKLLM NPU 移植与基准](63-npu-rkllm-minicpmv47-1b-20261015.md)
- [64 — RKLLM 带图推理故障修复、66 一键转换与 token 测试](64-npu-multimodal-minicpmv47-fix-20261015.md)
- [65 — MiniCPM-V 4.7-35B-A3B:RK3588 可行性与 token 实测](65-minicpmv47-35ba3b-rk3588-20261015.md)

模型转换/部署脚本见 [`../tools/rkllm/`](../tools/rkllm/README.md)。
