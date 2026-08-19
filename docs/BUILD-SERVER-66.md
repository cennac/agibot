# 66 服务器 Armbian 编译指南

本文记录在 `192.168.88.66` 的 Ubuntu 26.04 服务器上编译 AGIBOT Armbian 镜像的可复现流程。示例假设 SSH 用户为 `cennac`；请使用自己的认证方式，不要把密码写进仓库。

## 实测环境

- 服务器：Ubuntu 26.04 LTS，20 核 CPU，30 GiB 内存
- 编译目录：`/home/cennac/agibot-armbian`
- Armbian 框架：submodule 提交 `70a242faa308c57be5ed636897dfee77de350773`
- 仓库基准：`cennac/agibot@78e2875d329ec8156e0e3180fed9ded47b29a758`
- 代理：`http://192.168.88.128:7897`
- GHCR 镜像：`nju`

2026-08-20 的成功构建耗时 49 分 43 秒，产物为：

```text
Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img
SHA256: 00b4a79e520803a188d79045a937272881328d141ca512e5d2e77bf6cfc53569
```

## 1. 使用代理克隆仓库

```bash
cd ~
export http_proxy=http://192.168.88.128:7897
export https_proxy=http://192.168.88.128:7897
export ftp_proxy=http://192.168.88.128:7897
export all_proxy=http://192.168.88.128:7897
export no_proxy='localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,.tuna.tsinghua.edu.cn,.bfsu.edu.cn,.aliyun.com,.ustc.edu.cn,github.armbian.com'
export NO_PROXY="$no_proxy"

git clone https://github.com/cennac/agibot.git agibot-armbian
cd agibot-armbian
```

这台服务器直连 GitHub 会超时，走上面的代理可用。`no_proxy` 需要保留本地网段和国内软件源，避免局域网与镜像站流量绕代理。

## 2. 安装编译依赖

Ubuntu 26.04 上 `qemu-user-static` 已变成过渡/虚拟包，实际应安装 `qemu-user-binfmt`：

```bash
sudo apt update
sudo apt install -y \
  git curl ca-certificates build-essential \
  qemu-user-binfmt binfmt-support device-tree-compiler \
  e2fsprogs cpio
sudo systemctl restart systemd-binfmt
test -f /proc/sys/fs/binfmt_misc/qemu-aarch64
```

最后的 `test` 必须成功；否则后续 arm64 rootfs chroot 会报 `Exec format error`。

## 3. 装配仓库并启动编译

```bash
cd ~/agibot-armbian
bash setup.sh
```

服务器是原生 Linux ext4 路径，`setup.sh` 会初始化锁定的 Armbian submodule、跳过 WSL2 专用补丁，并装配板级 userpatches。

用 root 环境启动编译，避免脚本进入后台后，loop 设备、挂载和 chroot 操作再触发无终端的 `sudo` 密码提示：

```bash
sudo env \
  http_proxy=http://192.168.88.128:7897 \
  https_proxy=http://192.168.88.128:7897 \
  ftp_proxy=http://192.168.88.128:7897 \
  all_proxy=http://192.168.88.128:7897 \
  no_proxy='localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,.tuna.tsinghua.edu.cn,.bfsu.edu.cn,.aliyun.com,.ustc.edu.cn,github.armbian.com' \
  NO_PROXY='localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,.tuna.tsinghua.edu.cn,.bfsu.edu.cn,.aliyun.com,.ustc.edu.cn,github.armbian.com' \
  bash start-build.sh
```

`start-build.sh` 会在后台执行下面命令，并把完整日志写入 `output/build.log`：

```bash
./compile.sh agibot EXPERT=yes DOWNLOAD_MIRROR=china
```

## 4. 跟踪编译进度

```bash
cd ~/agibot-armbian/armbian-build
tail -f output/build.log
```

常用完成检查：

```bash
grep -a FINISHED_EXIT output/build.log
find output/images -maxdepth 1 -type f -printf '%s %f\n' | sort -nr
```

`FINISHED_EXIT=0` 表示成功。如果非 0，优先查看 `output/build.log` 尾部和 `output/logs/` 下对应的 UUID 日志；不要删除 `cache/`，内核与 rootfs 缓存会让重试快很多。

## 5. 校验并取回产物

在服务器上先做 SHA 校验和镜像内容验证：

```bash
cd ~/agibot-armbian/armbian-build/output/images
sha256sum -c Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img.sha

cd ~/agibot-armbian
bash scripts/verify-image.sh \
  armbian-build/output/images/Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img
```

2026-08-20 构建通过了 SHA 校验，并通过全部 12 项镜像内容检查，包括 Agibot DTB、6.1 DT 适配、rootfs 与 initramfs 中的 ACM8625P 固件、扩容服务、主机名和品牌信息。

在另一台 Linux 机器上取回产物，并显示实时传输进度：

```bash
rsync -av --partial --info=progress2 \
  cennac@192.168.88.66:/home/cennac/agibot-armbian/armbian-build/output/images/Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img \
  cennac@192.168.88.66:/home/cennac/agibot-armbian/armbian-build/output/images/Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img.sha \
  cennac@192.168.88.66:/home/cennac/agibot-armbian/armbian-build/output/images/Agibot-Armbian_26.08.0-trunk_Agibot_jammy_vendor_6.1.115_minimal.img.txt \
  ./
```

下载完成后，先按 `.sha` 文件校验，再写入存储介质。

## 仓库状态说明

这次成功构建除使用上述仓库基准外，还同步了两个本地修正：`start-build.sh` 导出 `core.filemode=false`，`overlay/etc/issue` 以 `Agibot-Armbian` 开头。这两个修正已在后续提交 `4d80e09d323a44dc016afe5245fdf87889451847` 入库；从该提交之后全新 clone 可直接编译并通过品牌检查。`core.filemode=false` 主要针对 Windows/DrvFs 检出，在服务器 ext4 上无副作用。
