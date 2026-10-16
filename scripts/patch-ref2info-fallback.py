#!/usr/bin/env python3
"""
patch-ref2info-fallback.py (v3 通用版) — armbian git-ref2info.sh 幂等补丁:
raw.githubusercontent.com 拉取失败(Clash 出口被 GitHub 429 全局限流)时,按
org/repo/sha 从本地 git-bare 缓存直接取 Makefile。覆盖 u-boot 与 linux-rockchip
(git-bare 里仅此两仓);其余 repo 照旧走网络。

用法: python3 patch-ref2info-fallback.py [<armbian-build 根>]
docker-build.sh 在 setup.sh 后、start-build.sh 前调用(armbian 流程可能 reset
submodule,每次构建前重打;先 git checkout 还原旧补丁再插,保证幂等)。
"""
import os
import subprocess
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else (
    "/docker-agibot-armbian/armbian-build" if os.path.isdir("/docker-agibot-armbian")
    else os.path.expanduser("~/docker-agibot-armbian/armbian-build"))
REL = "lib/functions/general/git-ref2info.sh"
TARGET = os.path.join(ROOT, REL)
MARK = "agibot local hack"
ANCHOR = '\t\t\tdisplay_alert "Failed to fetch Makefile from URL" "${1}" "warn"'

def main():
    # 幂等:先还原(submodule 文件可安全丢),再重打
    subprocess.run(["git", "-C", ROOT, "checkout", "--", REL],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    src = open(TARGET, encoding="utf-8").read()
    if MARK in src:
        print("ref2info fallback: already patched, skip")
        return 0
    if ANCHOR not in src:
        print("ref2info fallback: ANCHOR NOT FOUND — armbian upstream changed?")
        return 1
    fb = (
        f'\t\t\t\t# {MARK} v3: raw.githubusercontent 429 -> local git-bare cache\n'
        '\t\t\t\tdeclare _rest="${1#*raw.githubusercontent.com/}"\n'
        '\t\t\t\tdeclare _repo="${_rest#*/}"; _repo="${_repo%%/*}"\n'
        '\t\t\t\tdeclare _sha="${_rest#*/${_repo}/}"; _sha="${_sha%%/*}"\n'
        '\t\t\t\tdeclare _gd=""\n'
        '\t\t\t\tcase "${_repo}" in\n'
        f'\t\t\t\t\tu-boot)          _gd="{ROOT}/cache/git-bare/u-boot/.git" ;;\n'
        f'\t\t\t\t\tlinux-rockchip)  _gd="{ROOT}/cache/git-bare/kernel/.git" ;;\n'
        '\t\t\t\tesac\n'
        '\t\t\t\tif [[ -n "${_gd}" ]]; then\n'
        '\t\t\t\t\tdeclare _body=""\n'
        '\t\t\t\t\t_body="$(git --git-dir="${_gd}" show "${_sha}:Makefile" 2>/dev/null || true)"\n'
        '\t\t\t\t\tif [[ -n "${_body}" ]]; then\n'
        '\t\t\t\t\t\tdisplay_alert "Makefile via local git-bare fallback" "${_repo}@${_sha:0:8}" "info"\n'
        '\t\t\t\t\t\tmakefile_body="${_body}"\n'
        '\t\t\t\t\t\treturn 0\n'
        '\t\t\t\t\tfi\n'
        '\t\t\t\tfi\n'
    )
    open(TARGET, "w", encoding="utf-8", newline="\n").write(src.replace(ANCHOR, fb + ANCHOR, 1))
    print("ref2info fallback v3: PATCHED")
    return 0

if __name__ == "__main__":
    sys.exit(main())
