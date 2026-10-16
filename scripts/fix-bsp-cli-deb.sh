#!/usr/bin/env bash
# fix-bsp-cli-deb.sh — 修复 bsp-cli deb 与 jammy linux-sysctl-defaults 的文件冲突。
#
# 现象(2026-09-28 在 66 上以 26.11.0-trunk 实测):rootfs 装包阶段 dpkg 报
#   "trying to overwrite '/usr/lib/sysctl.d/50-default.conf', which is also in
#    package linux-sysctl-defaults" → "paste subprocess broken pipe" → 构建失败。
# 原因:较新 trunk 的 armbian-bsp-cli 自带 /usr/lib/sysctl.d/50-default.conf,
#   而 jammy 基础 rootfs 的 linux-sysctl-defaults 已提供同名文件。
# 修法:把该文件从 deb 里剔除后重建。本仓库锁定的 submodule(70a242f,26.08
#   trunk)不含此文件,不受影响;**升级 submodule 后首次构建失败出现上述报错时
#   运行本脚本**,然后直接重跑 start-build.sh(rootfs 缓存命中,重试很快)。
#
# 用法:
#   bash scripts/fix-bsp-cli-deb.sh                      # 自动找 output/debs/ 下的 bsp-cli deb
#   bash scripts/fix-bsp-cli-deb.sh <path/to/deb>        # 指定 deb
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEB="${1:-}"

if [ -z "$DEB" ]; then
	DEB=$(ls "$ROOT"/armbian-build/output/debs/armbian-bsp-cli-*.deb 2>/dev/null | head -1 || true)
fi
[ -n "$DEB" ] && [ -f "$DEB" ] || { echo "FATAL: 未找到 bsp-cli deb,请手动指定: bash scripts/fix-bsp-cli-deb.sh <deb路径>"; exit 1; }
echo ">>> 目标 deb: $DEB"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 用 -R(原样解包,保留 DEBIAN/ 控制文件,payload 在顶层)。
# 不要用 dpkg-deb -x 解到子目录再打包 —— 那会多包一层目录前缀,文件全部错位
# (实测会导致 /etc/armbian-release 缺失、distro-agnostic.sh 在 set -e 下挂掉)。
dpkg-deb -R "$DEB" "$WORK/root"

CONFLICT="$WORK/root/usr/lib/sysctl.d/50-default.conf"
if [ ! -f "$CONFLICT" ]; then
	echo "✓ deb 内没有 50-default.conf,无需修复(本已是非冲突版本)"
	exit 0
fi
rm -f "$CONFLICT"

# 该文件的宿主机 dpkg-deb 对非空 conffiles 的重建有校验 bug,清空后再打包
if [ -f "$WORK/root/DEBIAN/conffiles" ]; then
	: > "$WORK/root/DEBIAN/conffiles"
fi

mv "$DEB" "$DEB.bak-conflict"
dpkg-deb -b "$WORK/root" "$DEB"

if dpkg-deb -c "$DEB" | grep -q '50-default\.conf'; then
	echo "FATAL: 重建后仍含冲突文件,已保留备份 $DEB.bak-conflict"
	exit 1
fi
echo "✓ 修复完成: $DEB(原包备份为 $DEB.bak-conflict)"
echo "  现在重跑: bash start-build.sh"
