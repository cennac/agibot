#!/usr/bin/env bash
# preflight.sh — 编译前置 / 状态检查(编译前或卡住时跑)。
# 确认 WSL2 patch 是否 apply、上次 build.log 失败阶段、各类缓存命中情况、shellcheck 直连。
# 用法: bash scripts/preflight.sh
set -uo pipefail
B="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/armbian-build"

echo "=== fsync 补丁确认(host-utils.sh 的 wait_for_disk_sync 函数体)==="
awk '/^function wait_for_disk_sync/,/^}/' "$B/lib/functions/host/host-utils.sh" 2>&1 | head -20
echo
echo "=== 上次失败具体阶段(build.log: shellcheck/SSL/uboot/FAILED)==="
grep -nE "shellcheck|SSL_ERROR|compile_uboot|Downloading|uboot|FAILED|\[ error" "$B/output/build.log" 2>&1 | tail -20
echo
echo "=== 内核源码缓存(决定编译时长)==="
ls -d "$B"/cache/sources/linux-* 2>&1
find "$B/cache" -maxdepth 3 -name "*.deb" 2>/dev/null | grep -iE "linux-image|linux-dtb|linux-u-boot" | head
echo "=== u-boot worktree ==="
ls -d "$B"/cache/sources/u-boot-worktree/* 2>&1 | head
echo "=== rootfs 缓存(jammy/noble)==="
find "$B/cache/rootfs" -maxdepth 3 \( -name "*.lz4" -o -name "*.tar.zst" -o -name "*.tar" \) 2>/dev/null | head
echo "=== memoize(已编译产物缓存)==="
ls "$B/cache/memoize" 2>&1 | head
echo
echo "=== shellcheck github releases 直连测试(代理是否生效)==="
curl -sS -m 12 -o /dev/null -w 'HTTP=%{http_code} time=%{time_total}s\n' -L \
	https://github.com/koalaman/shellcheck/releases/download/v0.9.0/shellcheck-v0.9.0.linux.x86_64.tar.xz 2>&1 | head -2
echo "DONE"
