#!/usr/bin/env bash
# ACM8625P 内核补丁验证:在本地完整内核树应用补丁 + 编译驱动模块(外置 M= 不污染内核树)
#
# 用法:
#   1. 前置:已 WSL 内浅克隆 armbian/linux-rockchip rk-6.1-rkr5.1 到 ~/kbuild/linux
#   2. 设好 arm64 的 .config(同板上 running config,存于 ~/kbuild/_acm_kconfig)
#   3. 复刻 armbian family 补丁(见 ARMBIAN-LINUX-BRINGUP.md)
#   4. 跑本脚本(在 WSL 里执行):
#        bash /mnt/e/AIPorject/101/agibot-armbian/kernel/_acm_build.sh
#   产物:~/kbuild/acm-mod/acm8625p.ko(vermagic 应为 6.1.115-vendor-rk35xx ...)
#
set -e
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
cd ~/kbuild/linux
P=/mnt/e/AIPorject/101/agibot-armbian/kernel/rk35xx-vendor-6.1/0001-ASoC-add-ACM8625P-amplifier.patch

# 1) 应用 ACM 补丁(幂等)
if ! grep -q acm8625p sound/soc/codecs/Makefile; then
  echo "== apply ACM patch =="
  patch -p1 --fuzz=0 < "$P"
fi

# 2) 确保 .config 是 arm64 真 config(olddefconfig 会同步 CONFIG_CC_VERSION_TEXT)
if ! grep -q '^CONFIG_ARM64=y' .config; then
  echo "== restore arm64 config =="
  cp /mnt/e/AIPorject/101/agibot-armbian/_acm_kconfig .config
  make olddefconfig >/dev/null 2>&1
fi

# 3) 生成 headers
make prepare >/dev/null 2>&1 || { echo "PREPARE-FAIL"; exit 1; }

# 4) 单目标编译(证明补丁内建可用)+ 外置 M= 产 .ko
echo "== single-obj (in-tree) =="
make sound/soc/codecs/acm8625p.o 2>&1 | grep -iE 'acm8625|error' | head -5
mkdir -p ~/kbuild/acm-mod
cp sound/soc/codecs/acm8625p.c ~/kbuild/acm-mod/
printf 'obj-m := acm8625p.o\n' > ~/kbuild/acm-mod/Makefile
echo "== external M= build =="
make M=~/kbuild/acm-mod modules 2>&1 | tail -3

echo "== modinfo =="
modinfo ~/kbuild/acm-mod/acm8625p.ko | grep -E 'name|vermagic|depends'
echo "DONE: 上板步骤见 ARMBIAN-LINUX-BRINGUP.md ## ACM8625P"
