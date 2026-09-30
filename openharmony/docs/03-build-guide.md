# OpenHarmony 构建手册(66 服务器,2026-10-01 整理)

本文把 2026-09-30 双里程碑(OPi5Plus 基线 P0 + agibot 首版 P1)的完整复现
路径固化为手册。基线锁定见 [../baseline/opc-openharmony-6.0.json](../baseline/opc-openharmony-6.0.json)
与 [../baseline/manifest-locked-6.0.xml](../baseline/manifest-locked-6.0.xml)。

## 0. 前提

- 66 服务器(/data ≥ 150G 空闲),Docker 可用
- 编译窗口期需停 llama 服务腾内存:`sudo systemctl stop llama-server llama-27b5060 llama-embed llama-rerank`(完成后 start 恢复)
- Gitee/GitCode 直连,repo 走清华镜像(REPO_URL)

## 1. 容器

```bash
docker run -d --name oh-build -v /data/openharmony:/data -w /data ubuntu:22.04 sleep infinity
docker exec oh-build bash /data/setup_container.sh   # 见 scripts/env-fixes/
# setup 之后追加的依赖(P0 过程中补齐,重装环境时一并装):
docker exec oh-build bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get install -y -qq \
  autoconf automake libtool libtool-bin pkg-config ruby swig perl \
  lz4 lzop kmod genext2fs libfl-dev openjdk-17-jdk-headless \
  u-boot-tools device-tree-compiler mtools dosfstools squashfs-tools cpio'
docker exec oh-build pip3 install -q -i https://mirrors.aliyun.com/pypi/simple/ json5 pycryptodome
```

## 2. 源码同步(53G,约 1.5h)

```bash
docker exec -d oh-build bash -c 'mkdir -p /data/oh && cd /data/oh && \
  export REPO_URL=https://mirrors.tuna.tsinghua.edu.cn/git/git-repo && \
  repo init -u https://gitee.com/ohos-porting-communities/manifest.git -b OpenHarmony-6.0-Release && \
  repo sync -c -j8 --no-tags --fail-fast'
```

两个 LFS 仓都要拉(漏 soc 仓会在链接期报 `unknown directive: version`):

```bash
docker exec oh-build bash -c 'cd /data/oh/device/board/opc && git lfs install && git lfs pull'
docker exec oh-build bash -c 'cd /data/oh/device/soc/opc && git lfs install && git lfs pull'
docker exec oh-build bash -c 'cd /data/oh/vendor/opc && git lfs install && git lfs pull'
# 验证:board 仓 0001-add-rk.patch 应为 104,336,293 字节
```

## 3. node 统一 20.19.4(三处)

```bash
docker exec oh-build bash -c '
curl -fsSL https://mirrors.aliyun.com/nodejs-release/v20.19.4/node-v20.19.4-linux-x64.tar.xz -o /tmp/n20.tar.xz \
  && tar -xJf /tmp/n20.tar.xz -C /opt \
  && sed -i s/14.21.1/20.19.4/g /data/oh/build.sh \
  && ln -sfn /opt/node-v20.19.4-linux-x64 /data/oh/prebuilts/build-tools/common/nodejs/node-v20.19.4-linux-x64 \
  && ln -sf /opt/node-v20.19.4-linux-x64/bin/{node,npm,npx} /usr/local/bin/ '
```

## 4. 预编译工具链 + SDK

```bash
docker exec oh-build bash -c 'cd /data/oh && bash build/prebuilts_download.sh'
# declgen npm 卡点(若报 lru-cache tracingChannel / rimraf):
docker exec oh-build python3 /data/fix_declgen.py
```

SDK 填装(树内无机制生成,必须手工):下载官方 public SDK
`https://repo.huaweicloud.com/openharmony/os/6.0.0.1-Release/ohos-sdk-windows_linux-public.tar.gz`,
解出 `ohos-sdk/linux/{native,ets,js,toolchains}-linux-x64-6.0.0.48-Release.zip`,
把各 zip 内的组件目录放到 `prebuilts/ohos-sdk/linux/20/{native,ets,js,toolchains}/`,
再跑 `python3 /data/sdk_smart_overlay.py` 增补系统 API 声明。
(半自动参考 `sdk_fill.sh`;正式解为 CI 恢复后取 ohos-sdk-full,见报告第 7 条。)

## 5. 系统 hap 摘除(full SDK 缺失的过渡方案)

```bash
docker exec oh-build python3 /data/remove_haps.py   # 4 个 hap + 还原 component 目录
docker exec oh-build python3 /data/fix_wifi_cfg.py  # portal_login feature
docker exec oh-build python3 /data/rm_portal.py     # wifi bundle 引用
```

## 6. 编译

```bash
# P0 基线(参考板,验证流程):
docker exec oh-build bash -c 'cd /data/oh && ./build.sh --product-name opi5plus --ccache'
# P1 agibot 首版:
docker exec oh-build bash -c 'cd /data/oh && ./build.sh --product-name agibot --ccache'
```

产物:`/data/oh/out/<product>/packages/phone/images/`。
agibot 镜像 SHA256 已归档:`66:/data/openharmony/archive/agibot-images-SHA256SUMS-20260930.txt`。

## 7. agibot 板级层(已就位,重建时)

```bash
docker exec oh-build bash /data/make_agibot_layer.sh   # 由 opi5plus 模板生成
# 三处手工修正(模板坑,脚本未覆盖):
# 1) make-ohos.sh 板表加行:agibot arm64 0xfeb50000 rk3588-agibot-mb0002-v2 Image agibot_oh_defconfig
# 2) build_kernel.sh:./make-ohos.sh agibot enable_ramdisk;DEFCONFIG_FILE=agibot_oh_defconfig
# 3) loader/MiniLoaderAll.bin 换为仓库 flash/rk3588_spl_loader_v1.16.113.bin(487872B)
```

## 8. 坑速查(踩过的全录)

| 症状 | 根因/解 |
|---|---|
| `node: command not found` / 版本 mismatch | build.sh 钉 14.21.1;见第 3 步 |
| `lru-cache ... tracingChannel` SyntaxError | npm6 装了要 node20 的包;rimraf 钉 3.0.2 + node 统一 |
| `lz4: not found`(内核 Image.lz4) | apt lz4 lzop |
| `requires depmod` / `genext2fs: command not found` | apt kmod genext2fs |
| `ruby: No such file`(ark gen.rb) | apt ruby |
| `No module named 'json5'` | pip json5 pycryptodome |
| libnl install.sh 失败 | apt autoconf automake libtool |
| `libbundle_ndk.z.so ... missing` | SDK native 组件未填;见第 4 步 |
| `hvigor ... toolchains:20` | SDK ets/js/toolchains 组件未填 |
| jar/haptobin 构建失败 | apt openjdk-17-jdk-headless |
| `FlexLexer.h` copy 失败 | apt libfl-dev |
| hap 报 `Cannot find module @ohos.app.ability.*` | public SDK 缺系统 API;声明增补/见第 5 步 |
| 链接期 `unknown directive: version` | soc 仓 LFS 未 pull |
| ninja 报 orangepi dtb/defconfig | 板级层三形态改名不全(opi5plus/orangepi5plus/连字符) |
| 双 build 并发写坏内核 out | 断链 docker exec 留孤儿;杀干净单跑,rm -rf out/<p>/kernel 重来 |

## 9. 刷机(android14/docs/16 流程)

RKDevTool 整擦 eMMC 后按 config.cfg/parameter.txt 写 images 目录全部分区。
验收:串口(ttyFIQ0@1500000)OH 启动日志 → HDMI ArkUI 桌面。
已知限制见 [02-p0-report.md](02-p0-report.md) 末节(uboot 板级差异/6 hap 缺失/
音频与 hub-reset 暂缓/AP6275P 固件路径确认)。
