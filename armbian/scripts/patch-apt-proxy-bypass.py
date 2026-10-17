#!/usr/bin/env python3
"""
patch-apt-proxy-bypass.py — armbian main-config.sh 幂等补丁:容器带 http_proxy 时
阻止 armbian 把 chroot apt 全局劫持进代理(Clash 抖一下 apt 即挂)。

main-config.sh 原逻辑:APT_PROXY_ADDR 未设且有 http_proxy → 推导 APT_PROXY_ADDR
→ runners.sh 给 chroot apt 全局配 Acquire::http::Proxy。补丁:设 AGIBOT_NO_APT_PROXY=1
时跳过推导(chroot apt 直连 DOWNLOAD_MIRROR=china 的清华源)。
host 侧 apt 的直连由 docker-build.sh 写 /etc/apt/apt.conf.d/99agibot-noproxy 实现
(apt conf 优先于 http_proxy env),git/curl/oras 仍走代理 —— 分流完成。
"""
import os
import subprocess
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else (
    "/docker-agibot-armbian/armbian-build" if os.path.isdir("/docker-agibot-armbian")
    else os.path.expanduser("~/docker-agibot-armbian/armbian-build"))
REL = "lib/functions/configuration/main-config.sh"
TARGET = os.path.join(ROOT, REL)
OLD = '\tif [[ -z "${APT_PROXY_ADDR}" && -n "${http_proxy:-${https_proxy:-${HTTP_PROXY:-${HTTPS_PROXY:-}}}}"'
NEW = '\tif [[ -z "${APT_PROXY_ADDR}" && -z "${AGIBOT_NO_APT_PROXY:-}" && -n "${http_proxy:-${https_proxy:-${HTTP_PROXY:-${HTTPS_PROXY:-}}}}"'
MARK = "AGIBOT_NO_APT_PROXY"

def main():
    subprocess.run(["git", "-C", ROOT, "checkout", "--", REL],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    src = open(TARGET, encoding="utf-8").read()
    if MARK in src:
        print("apt-proxy bypass: already patched, skip")
        return 0
    if OLD not in src:
        print("apt-proxy bypass: ANCHOR NOT FOUND — armbian upstream changed?")
        return 1
    open(TARGET, "w", encoding="utf-8", newline="\n").write(src.replace(OLD, NEW, 1))
    print("apt-proxy bypass: PATCHED")
    return 0

if __name__ == "__main__":
    sys.exit(main())
