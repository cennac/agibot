#!/bin/bash
# start-build.sh — Armbian 编译入口(WSL2)。
# 已内置:代理(Clash Verge 经 WSL 网关)、NO_HOST_RELEASE_CHECK、git resilience、后台运行。
# 前置:先跑过 `bash setup.sh`(装配 submodule + apply patch + 装 userpatches)。
#
# 用法(在 WSL Ubuntu 内):
#   cd /mnt/e/AIPorject/101/agibot-armbian
#   bash setup.sh && bash start-build.sh
#   tail -f armbian-build/output/build.log
set -e

# 脚本相对定位 armbian-build submodule
cd "$(dirname "$(readlink -f "$0")")/armbian-build" \
	|| { echo "FATAL: armbian-build/ 不存在或未 init,先跑 bash setup.sh"; exit 1; }

mkdir -p output
rm -f output/build.log

# PREFER_DOCKER=no:WSL2 里直接原生编译,不走 docker(更省坑)
export PREFER_DOCKER=no
# WSL Ubuntu 是 noble(24.04,armbian 支持),但 host-release gate 会误拦,显式跳过
export NO_HOST_RELEASE_CHECK=yes

# 代理:Clash Verge mixed-port 7897 在 Windows host,WSL2 经 NAT 网关可达(allow-lan 已开)
GW=$(ip route show default | awk '{print $3; exit}')
export http_proxy="http://${GW}:7897" https_proxy="http://${GW}:7897" \
	ftp_proxy="http://${GW}:7897" all_proxy="http://${GW}:7897"
# github.armbian.com 直连 200、走代理 502,必须排除;其余是国内镜像,直连更快
export no_proxy="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,.tuna.tsinghua.edu.cn,.bfsu.edu.cn,.aliyun.com,.ustc.edu.cn,github.armbian.com"
echo "===== proxy via ${GW}:7897 (Clash Verge) ====="

# Git resilience:大 kernel clone 经代理时 TLS 握手会偶发丢包,放宽超时避免长传输中断
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999
git config --global http.postBuffer 1048576000
git config --global http.version HTTP/1.1
# /mnt/e 是 Windows mount 混合所有权,让 root 能操作缓存的 git 仓库
git config --global --add safe.directory '*'

# 后台编译(setsid 脱离会话,WSL 退出不被清理);日志写 output/build.log
setsid bash -c './compile.sh agibot EXPERT=yes DOWNLOAD_MIRROR=china > output/build.log 2>&1; echo "FINISHED_EXIT=$?" >> output/build.log' \
	< /dev/null > /dev/null 2>&1 &
disown

sleep 6
echo "===== launched @ $(date) EUID=$(id -u) ====="
echo "===== build.log 前 25 行 ====="
head -25 output/build.log 2>/dev/null
echo ""
echo "===== 编译进程 ====="
ps -ef | grep -iE 'compile.sh|make|mmdebstrap|gcc' | grep -v grep | head -8
echo ""
echo "跟踪日志:tail -f $(pwd)/output/build.log"
