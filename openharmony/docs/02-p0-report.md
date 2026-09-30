# P0 基线流程验证报告 — OpenHarmony 6.0 / OPi5Plus

- 日期:2026-09-30
- 环境:66 服务器,Docker 容器 `oh-build`(ubuntu:22.04),源码树 `/data/openharmony/oh`
- 状态:**✅ P0 完成** — 36865/36865 目标全部通过,完整镜像组产出
  (system.img 1.6G / vendor.img 268M / boot_linux.img 67M / uboot.img /
  ramdisk / updater / userdata / sys_prod / chip_prod / MiniLoaderAll.bin /
  resource.img / parameter.txt / config.cfg),ninja 8797s(20 线程)

## 结论

流程验证通过:OPC OpenHarmony-6.0-Release + OH 官方 linux-6.6 内核 + 104MB
Rockchip vendor 补丁 + 板级层,可在 66 容器内可复现编译。P1(agibot 板级)
板级层已就位,同日启动首版构建。

## 实测勘误(相对 docs/00-evaluation.md)

1. **内核不是 5.10**:OPC 的 OpenHarmony-6.0-Release 路线,opi5plus 实际用
   **OH 官方 kernel/linux/linux-6.6** + 板级仓 104MB Rockchip vendor 补丁
   (Git LFS)+ 板级 dts/defconfig。manifest 里的 `linux_5.10_opi` 是遗留条目
   (5.10.160,无 bcmdhd,build_kernel.sh 不引用)。对 agibot 是利好:dts 移植
   目标从"5.10 重放"变为"vendor 6.1 → 6.6 微调",同族更近。
2. **5.x manifest 已删**:OPC gitee manifest 仓仅存 6.0/6.1 分支,评估期选的
   5.1.0R 无法一键 init,故基线定版 **6.0 Release**(板级四仓的 5.1.0 分支仍在,
   可作回退)。
3. **WiFi 模块同款实锤**:OPi5Plus 板级 dts `wifi_chip_type = "ap6275p"`,与
   agibot 相同;defconfig 含 9 处 BCMDHD/BRCM 配置。评估风险 #1 基本解除,
   剩余验证点 = 104MB vendor 补丁内 bcmdhd 驱动形态(LFS 拉取后 grep)。

## 流程实测记录

| 步骤 | 结果 |
|---|---|
| repo init(sync gitee,REPO_URL 走清华镜像) | ✅ |
| repo sync -c -j8 --no-tags(53GB,~1.5h) | ✅ rc=0 |
| `device/board/opc` git lfs pull(0001-add-rk.patch 104,336,293B) | ✅ |
| common patches 001–005 | 4 个 SKIP(opc fork 已内置,manifest 换仓所致)、003 APPLIED;与 5.0 时代博客"三处必改"结论不同,6.0 已收敛 |
| 容器依赖 | git/python3.10/编译链 + mkimage/dtc/mtools/cpio + **node 14.21.1**(build.sh 强制版本) |
| `build/prebuilts_download.sh` | ✅(clang_ohos 工具链等,npm 阶段两处修复见下) |
| `./build.sh --product-name opi5plus --ccache` | ✅ 36865/36865,镜像组齐全 |
| 编译窗口内存 | 停 4 个 llama-*.service 腾至 39G 可用(链路峰值 ~24G),**编译后已全部恢复** |

## 环境修复清单(容器 oh-build,均已落 baseline json)

1. **node 统一 20.19.4**:build.sh 版本检查 sed + prebuilts nodejs 目录软链 +
   /usr/local/bin 三件套。根因:declgen_ts2sts 等 hap 工具链依赖漂移
   (rimraf@6/lru-cache@11 需 node20),而 opc fork 仍钉 14.21.1;node14 的
   npm6 无视 engines 装新包后在运行时崩。
2. **declgen_ts2sts 钉 rimraf 3.0.2**(devDependencies)。
3. **sysroot/SDK 手工填装**:public SDK(6.0.0.1-Release
   ohos-sdk-windows_linux-public.tar.gz)解出 native/ets/js/toolchains →
   `prebuilts/ohos-sdk/linux/20/`;构建系统期望该目录但树内无任何机制生成它
   (`download_sdk` handler 在 opc fork 与上游 6.0 的脚本中均未实现,
   CI 端点 ci.openharmony.cn 当日 502/504,代理亦不通)。
4. **SDK 声明增补**(api 目录 smart-additive 329 个树内系统 API d.ts,
   同词干不覆盖避免 .d.ts/.d.ets 双声明):解决 power_dialog 等 hap 的
   "Cannot find module @ohos.app.ability.ServiceExtensionAbility" 类错误。
5. **apt 增补**:autoconf automake libtool(libnl install.sh)、ruby(ark
   gen.rb)、lz4 lzop(kernel Image.lz4)、kmod genext2fs(depmod/镜像)、
   libfl-dev(FlexLexer.h)、openjdk-17(packing_tool jar)、json5+pycryptodome
   (pip,compile_app.py)、u-boot-tools/device-tree-compiler/mtools/
   squashfs-tools/cpio。
6. **LFS 全量拉取**:`device/soc/opc` 仓也要 `git lfs pull`(librga.z.so 等
   预编译库,漏拉会在链接期报 "unknown directive: version")。
7. **5+1 个系统 hap 摘除**(bundle.json 引用行删除 + JSON 修复;portal_login
   另加 feature false):power_dialog、dlp_manager、permission_manager、
   user_certificate_manager、ams_system_dialog、portal_login。根因:系统级
   ArkTS 应用需版本匹配的 ohos-sdk-**full**(含系统 API 声明),当前 CI 不可达
   无法获取;增补声明层修不平其与 6.0.0.1 SDK 编译器的版本咬合。
   **代价**:镜像缺权限弹窗 UI/系统对话框等,DLP/证书管理入口缺失——首启验证
   可用,日用需在 CI 恢复后取 full SDK 并回滚这 6 处摘除。
8. 竞态教训:断链的 docker exec 会留孤儿进程导致双 build 并发(记忆坑
   "绝不能并发 make" 再验证);孤儿 apt 也会自己装完。

## 66 服务器资源实况

- 磁盘:源码+out+缓存 ≈ 75G(/data 充足);ccache 13.4G 可复用于 agibot
- 内存:停 llama 后 39G 可用,链接峰值 ~24G 通过;**编译后 llama 已恢复**
- 代理:192.168.88.128:7897 对 github.com 可用(CI 仍 502)

## AGIBOT 移植侧产物(已完成)

- `openharmony/dts/rk3588-agibot-mb0002-v2.dts` — RFC 草案,以 android14
  vendor-6.1 dts 为事实源、opi5plus dts 为语法模板,首启范围与暂缓项见文件头
- `openharmony/docs/01-dts-port-notes.md` — 编译前逐项验证清单(V1–V6)、
  与 6.1 差异清单、固件来源(仓库内 `overlay/lib/firmware/ap6275p/`)、
  P1 板级层落盘清单
- `openharmony/baseline/opc-openharmony-6.0.json` — 基线勘误与锁定(旧
  5.1.0 基线文件作废删除)

## 下一步(P1,待 P0 编译通过)

1. LFS 补丁内验证 bcmdhd/V2 项;
2. `device/board/opc/agibot` + `vendor/opc/agibot` 板级层(拷 opi5plus 模板);
3. dts 标签验证 + 首版 agibot 镜像;
4. maskrom 刷机(android14/docs/16 流程),串口+HDMI 验收 ArkUI。
