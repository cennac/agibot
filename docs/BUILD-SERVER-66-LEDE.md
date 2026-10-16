# 66 服务器 LEDE 原生编译指南

本文记录在 `192.168.88.66` 的 Ubuntu 26.04 服务器上，为 AGIBOT MB0002 V2 原生编译 LEDE/OpenWrt 固件的流程。编译不使用 Docker，SSH 用户为 `cennac`；密码不要写进仓库或脚本。

## 实测环境

- 系统：Ubuntu 26.04 LTS
- 资源：20 核 CPU、30 GiB 内存
- 仓库：`/home/cennac/agibot-armbian`
- LEDE 源码：`/home/cennac/agibot-armbian/openwrt/lede`
- 代理：`http://192.168.88.128:7897`
- LEDE submodule：`coolsnowwolf/lede@8882f211bb19277d37685456f622caed95e102bd`
- 目标：Rockchip RK3588、AGIBOT MB0002 V2、Linux 6.12

LEDE 是纯交叉编译，不需要 qemu、binfmt、loop 设备或特权容器。

## 本次构建结果（2026-08-20）

- 构建方式：Ubuntu 宿主机原生 `make -j20`，未使用 Docker。
- 最终状态：`FINISHED_EXIT=0`，服务器与本地两次 SHA256 校验全部通过。
- 固件清单：392 个软件包。
- 修复 Perl 后的全量断点续编耗时：20 分 17 秒。
- Perl host 单包重编耗时：79 秒；修复前首次编译已运行约 18 分钟。

| 固件 | 字节数 | 约合 | SHA256 |
|---|---:|---:|---|
| `openwrt-rockchip-armv8-agibot_mb0002-v2-squashfs-sysupgrade.img.gz` | 129,226,472 | 124 MiB | `644f96a20e08e97efe51e32bf2cbd177a581185df1ccbb04dba284045034e91b` |
| `openwrt-rockchip-armv8-agibot_mb0002-v2-ext4-sysupgrade.img.gz` | 166,084,780 | 159 MiB | `92d59f7a8f9e13ec62b500f21cb6738902341a53ea4242eccfa3e91476d6eae2` |

推荐使用 squashfs 镜像，支持 sysupgrade 和恢复出厂设置。服务器产物目录及
`sha256sums`、manifest、buildinfo 已同步到本地
`openwrt/output/server-66/`；该目录被 `.gitignore` 排除，不会提交大体积固件。

## 1. 设置代理

服务器直连 GitHub 不稳定，编译前设置 7897 代理：

```bash
export http_proxy=http://192.168.88.128:7897
export https_proxy=http://192.168.88.128:7897
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export no_proxy='localhost,127.0.0.1,::1,goproxy.cn,mirrors.tuna.tsinghua.edu.cn'
export NO_PROXY="$no_proxy"

# Go 模块优先走国内代理，缺失模块再经 HTTP 代理访问 GitHub。
export GOPROXY='https://goproxy.cn,direct'
export GOSUMDB=off

# 代理偶发 TLS EOF 时，让 OpenWrt 下载脚本重试所有错误并固定 HTTP/1.1。
export CURL_OPTIONS='--retry-all-errors --http1.1'
```

## 2. 安装原生编译依赖

```bash
sudo apt update
sudo apt install -y \
  build-essential gcc g++ binutils make bc bison flex \
  libncurses-dev libssl-dev zlib1g-dev \
  gawk python3 python3-setuptools python3-dev python3-pyelftools \
  git curl wget rsync unzip xz-utils zstd ca-certificates swig \
  perl patch diffutils file e2fsprogs gettext
```

`swig` 是 U-Boot 2026.07 生成 `pylibfdt` 的必需依赖。缺少它时会出现：

```text
error: command 'swig' failed: No such file or directory
ERROR: package/boot/uboot-rockchip failed to build
```

Ubuntu 26.04 使用 GCC 15，默认 C23 模式会让 Perl 5.28 的旧式
`malloc()/free()` 探测误判，随后在 `SDBM_File` 处报类型冲突。仓库中的
`feed-patches/003-perl-gcc15-c23-prototypes.patch` 已将探测改为标准函数原型。
更新补丁后只需清理并续编 Perl host 包：

```bash
cd /home/cennac/agibot-armbian/openwrt/lede
make package/feeds/packages/perl/host/clean
make -j$(nproc) package/feeds/packages/perl/host/compile V=s
make -j$(nproc) V=s
```

## 3. 克隆并装配 LEDE

全新服务器执行：

```bash
cd /home/cennac
git clone https://github.com/cennac/agibot.git agibot-armbian
cd agibot-armbian/openwrt
bash setup-openwrt.sh
```

`setup-openwrt.sh` 会完成以下工作：

1. 初始化 `openwrt/lede` submodule。
2. 恢复干净 LEDE 树并应用 AGIBOT 设备、U-Boot、strace 等补丁。
3. 安装主线风格的 `rk3588-agibot-mb0002-v2.dts`。
4. 更新 packages、LuCI、routing、telephony 和 helloworld feeds。
5. 写入 `config-agibot-openwrt` 并运行 `make defconfig`。

装配后应用 dockerd 的离线版本校验修正：

```bash
python3 patch-dockerd.py
```

## 4. 原生编译

前台编译：

```bash
cd /home/cennac/agibot-armbian/openwrt/lede
make -j$(nproc) V=s 2>&1 | tee build.log
```

需要退出 SSH 后继续运行时：

```bash
cd /home/cennac/agibot-armbian/openwrt
nohup bash -c '
  export http_proxy=http://192.168.88.128:7897
  export https_proxy=http://192.168.88.128:7897
  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$https_proxy"
  export no_proxy="localhost,127.0.0.1,::1,goproxy.cn,mirrors.tuna.tsinghua.edu.cn"
  export NO_PROXY="$no_proxy"
  export GOPROXY="https://goproxy.cn,direct"
  export GOSUMDB=off
  export CURL_OPTIONS="--retry-all-errors --http1.1"

  bash setup-openwrt.sh && python3 patch-dockerd.py || exit $?
  cd lede
  make -j"$(nproc)" V=s 2>&1 | tee build.log
  rc=${PIPESTATUS[0]}
  echo "FINISHED_EXIT=$rc" | tee -a build.log
  exit "$rc"
' > lede-native-build.log 2>&1 < /dev/null &
```

## 5. 查看实时进度

```bash
cd /home/cennac/agibot-armbian/openwrt
tail -f lede-native-build.log
```

查看阶段计数和完成状态：

```bash
cd /home/cennac/agibot-armbian/openwrt
grep -c '^time: tools/' lede/build.log
grep -c '^time: toolchain/' lede/build.log
grep -c '^time: package/' lede/build.log
grep -a 'FINISHED_EXIT' lede/build.log | tail -1
```

`FINISHED_EXIT=0` 表示成功。失败后不要删除以下目录，它们能显著加快续编：

```text
openwrt/lede/build_dir/
openwrt/lede/staging_dir/
openwrt/lede/dl/
```

修正问题后重新运行同一条 `make -j$(nproc)` 即可断点续编。

## 6. dockerd 29.1.1 下载问题

代理偶发 TLS EOF 后，OpenWrt 下载脚本会切换到尚未同步 `dockerd-29.1.1.tar.gz` 的公共镜像，最终得到 404。仓库构建入口已经通过 `CURL_OPTIONS` 启用全错误重试。

如需手工预下载，可执行：

```bash
cd /home/cennac/agibot-armbian/openwrt/lede
curl -fL --http1.1 --connect-timeout 15 --max-time 180 \
  --retry 10 --retry-all-errors --retry-delay 1 \
  -o dl/dockerd-29.1.1.tar.gz \
  'https://codeload.github.com/moby/moby/tar.gz/docker-v29.1.1?/dockerd-29.1.1.tar.gz'

echo '65221f1c70feb1bd1562bb1017b586e4528be877656dc16f5be5659fc9b7e522  dl/dockerd-29.1.1.tar.gz' \
  | sha256sum -c -
```

## 7. 产物与校验

成功产物位于：

```text
/home/cennac/agibot-armbian/openwrt/lede/bin/targets/rockchip/armv8/
```

查找 AGIBOT 整盘镜像：

```bash
find /home/cennac/agibot-armbian/openwrt/lede/bin/targets/rockchip/armv8 \
  -maxdepth 1 -type f -iname '*agibot*sysupgrade.img.gz' -ls
```

校验目录内文件：

```bash
cd /home/cennac/agibot-armbian/openwrt/lede/bin/targets/rockchip/armv8
sha256sum -c sha256sums
```

刷机前将 `*agibot*sysupgrade.img.gz` 解压为整盘 `.img`，再按 `flash/README.md` 使用 AGIBOT 的 RK3588 loader 和 image@0 写入 eMMC。

## 8. 从 Docker 缓存切换到原生编译

如果此前曾用 root 身份的 Docker 容器编译，缓存文件可能归 `root` 所有。切换原生编译前执行：

```bash
sudo chown -R cennac:cennac \
  /home/cennac/agibot-armbian/openwrt/lede \
  /home/cennac/agibot-armbian/openwrt/.tmp \
  /home/cennac/agibot-armbian/.git/modules/openwrt/lede
```

第三个目录是 submodule 的 Git 元数据。只修改工作树而漏掉它，会导致 `git checkout` 报 `dubious ownership`，进而使补丁重复应用失败。

旧缓存内可能还保存了容器挂载路径 `/agibot/openwrt/lede`，以及 Ubuntu 22.04 的 `/usr/bin/python3.10`。原生续编前增加兼容入口并更新 host Python 链接：

```bash
sudo ln -s /home/cennac/agibot-armbian /agibot
cd /home/cennac/agibot-armbian/openwrt/lede
ln -sfn /usr/bin/python3 staging_dir/host/bin/python
ln -sfn /usr/bin/python3 staging_dir/host/bin/python3
```

全新原生编译不会产生这些旧路径，不需要执行本节。
