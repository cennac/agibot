#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
sed -i 's|//.*archive.ubuntu.com|//mirrors.aliyun.com|; s|//.*security.ubuntu.com|//mirrors.aliyun.com|' /etc/apt/sources.list
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  git git-lfs curl zip unzip tar xz-utils python3 python3-pip python3-requests python3-pexpect \
  build-essential gcc g++ make bison flex gperf texinfo bc rsync gawk ccache m4 \
  zlib1g-dev libssl-dev libxml2-dev libexpat1-dev lib32z1-dev lib32ncurses5-dev \
  libx11-dev x11proto-core-dev libgl1-mesa-dev libxml2-utils xsltproc gnupg
pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/ -q || true
apt-get install -y -qq repo 2>/dev/null || curl -sSL -o /usr/local/bin/repo https://mirrors.tuna.tsinghua.edu.cn/git/git-repo
chmod +x /usr/local/bin/repo 2>/dev/null || true
git config --global user.name "Cennac"
git config --global user.email "cennac@163.com"
git config --global color.ui auto
echo "export REPO_URL=https://mirrors.tuna.tsinghua.edu.cn/git/git-repo" >> /root/.bashrc
git lfs install --skip-repo || true
echo SETUP_DONE
repo --version 2>&1 | head -2 || /usr/local/bin/repo --version 2>&1 | head -2
