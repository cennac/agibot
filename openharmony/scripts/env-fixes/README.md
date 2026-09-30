# env-fixes — 66 容器环境复现脚本(2026-09-30 实测归档)

这些脚本在 66 服务器 `oh-build` 容器(ubuntu:22.04)里把 OPC OpenHarmony-6.0
基线从零跑到全镜像产出。按 [docs/03-build-guide.md](../docs/03-build-guide.md)
的顺序使用;单独执行时注意容器内 `/data` = 宿主机 `/data/openharmony`。

## 流程脚本

| 脚本 | 阶段 | 说明 |
|---|---|---|
| `setup_container.sh` | ①环境 | apt 依赖(git/python3/编译链/…)+ repo 工具 + git 身份 + REPO_URL 清华镜像 |
| `p0_chain.sh` | ②同步 | 等 repo sync 完成 → `device/board/opc` git lfs pull → 应用 common patches → build.sh |
| `apply_common_patches.sh` | ②同步 | common/patches 001–005 应用到对应系统仓(6.0 下 4 个已内置于 opc fork 会自动 SKIP) |
| `p0_chain2.sh` | ③预编译 | prebuilts_download.sh → build.sh(npm 卡点修复后重跑用) |
| `sdk_fill.sh` | ④SDK | 下载官方 public SDK → 抽 native 组件 → `prebuilts/ohos-sdk/linux/20/` |

## 一次性修复脚本(按问题触发,勿盲跑)

| 脚本 | 修复的问题 |
|---|---|
| `fix_declgen.py` | declgen_ts2sts 钉 rimraf 6.0.1→3.0.2(node14/npm6 装新包运行时崩) |
| `sdk_smart_overlay.py` | SDK api 目录智能增补树内系统 API 声明(329 个,同词干不覆盖,避免 .d.ts/.d.ets 双声明) |
| `fix_config.py` | vendor 产品 config 追加 powermgr feature(power_dialog 关闭尝试) |
| `fix_bundle.py` | 修复 sed 摘除 dialog_hap 后 bundle.json 的悬空逗号 |
| `remove_haps.py` | 摘除 4 个系统 hap 引用(dlp/permission/user_cert/ams_system_dialog)+ 还原 SDK component 目录 |
| `fix_wifi_cfg.py` | vendor config wifi features 追加 portal_login=false |
| `rm_portal.py` | wifi bundle.json 摘除 portal_login_hap 引用 |
| `make_agibot_layer.sh` | 由 opi5plus 模板生成 `device/board/opc/agibot` + `vendor/opc/agibot`(含三形态改名) |

## 配套手工操作(脚本未能覆盖的部分)

见 build-guide 第 5-7 步:node 20.19.4 三处统一、soc 仓 lfs pull、
ets/js/toolchains SDK 组件补装、apt 追加包(lz4/ruby/JDK17/libfl-dev/kmod/
genext2fs/autoconf 等)、make-ohos.sh 板表加 agibot 行。

## 服务器侧归档

- 完整构建日志:`66:/data/openharmony/archive/oh-build-logs-20260930.tar.gz`(4.2M)
- agibot 镜像 SHA256 清单:`66:/data/openharmony/archive/agibot-images-SHA256SUMS-20260930.txt`
