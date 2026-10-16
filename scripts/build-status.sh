#!/usr/bin/env bash
# build-status.sh — 查看编译进度 / 产物(编译跑起来后另开终端跑)。
# 显示 build.log 尾、编译进程、images/ 产物、kernel clone 进度。
# 用法: bash scripts/build-status.sh
set -uo pipefail
B="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/armbian-build"
LOG="$B/output/build.log"

echo "=== build.log 最后 22 行(去色)==="
tail -22 "$LOG" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
echo
echo "=== 行数 / FINISHED 次数 / mtime ==="
wc -l "$LOG" 2>/dev/null
echo -n "FINISHED_EXIT 出现次数: "; grep -c "FINISHED_EXIT=" "$LOG" 2>/dev/null || echo 0
echo -n "log 最后修改: "; stat -c '%y' "$LOG" 2>/dev/null || echo "(无 log)"
echo
echo "=== 编译相关进程 ==="
ps -ef | grep -iE 'compile.sh|make \[|mmdebstrap|aarch64.*gcc| cc1|debootstrap|fakeroot' | grep -v grep | head -10
echo
echo "=== 产物 images/ ==="
ls -lat "$B/output/images/" 2>/dev/null | head -8
echo
echo "=== kernel 源码 clone 进度 ==="
du -sh "$B"/cache/sources/linux-kernel* 2>/dev/null | head
