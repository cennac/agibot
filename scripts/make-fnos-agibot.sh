#!/usr/bin/env bash
# Build an AGIBOT MB0002 V2 image from the official fnOS Rock 5B image.
# Run from WSL/Linux: bash scripts/make-fnos-agibot.sh [source.img] [output.img]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOT_ASSETS="${FNOS_BOOT_ASSETS:-$ROOT/../artifacts/lede-clean-boot-20260821}"
DEFAULT_SOURCE="$ROOT/../_tmp/fnos/fnos-rock-5b.img"
DEFAULT_OUTPUT="$ROOT/../_tmp/fnos/fnos-agibot-mb0002-v2.img"

SOURCE_IMG="${1:-$DEFAULT_SOURCE}"
OUTPUT_IMG="${2:-$DEFAULT_OUTPUT}"
IDBLOADER="$BOOT_ASSETS/agibot-rk3588-idbloader.img"
UBOOT_ITB="$BOOT_ASSETS/agibot-rk3588-u-boot.itb"
BOARD_DTB="$BOOT_ASSETS/rk3588-agibot-mb0002-v2.dtb"
DTB_PATH="rockchip/rk3588-agibot-mb0002-v2.dtb"

# Expected hashes for the 1.2.0302 Mainland-PE Rock 5B baseline and the
# 2026-08-21 clean-boot AGIBOT bootloader assets. Each can be overridden via
# an environment variable of the same name (e.g. a DTB rebuilt against the
# fnOS 6.18 kernel tree).
SOURCE_MD5="${SOURCE_MD5:-36ef67cdebb5700d8088cf94d8706d64}"
IDBLOADER_SHA256="${IDBLOADER_SHA256:-8e7a5385da15d48b38714814246925054bea3c4b16a294364cd0dfe67ad8eca4}"
UBOOT_SHA256="${UBOOT_SHA256:-308dd983423c6f769138aaf888e412124f723eb312fb5f9e0d336723ce2d08f2}"
DTB_SHA256="${DTB_SHA256:-1589009e63066e4506568574fe64b44618c922eb7d02bf2d4b3da2eac15015e8}"

LOOP_DEV=""
BOOT_MNT=""

cleanup() {
  set +e
  if [ -n "$BOOT_MNT" ] && mountpoint -q "$BOOT_MNT"; then
    umount "$BOOT_MNT"
  fi
  if [ -n "$LOOP_DEV" ]; then
    losetup -d "$LOOP_DEV"
  fi
  [ -n "$BOOT_MNT" ] && rmdir "$BOOT_MNT" 2>/dev/null
}
trap cleanup EXIT INT TERM

usage_path() {
  local value="$1"
  case "$value" in
    [A-Za-z]:\\*|[A-Za-z]:/*)
      local drive="${value:0:1}"
      local rest="${value:3}"
      drive="${drive,,}"
      rest="${rest//\\//}"
      printf '/mnt/%s/%s' "$drive" "$rest"
      ;;
    *) printf '%s' "$value" ;;
  esac
}

check_file() {
  local file="$1" label="$2"
  [ -f "$file" ] || { echo "ERROR: missing $label: $file" >&2; exit 1; }
}

check_hash() {
  local file="$1" expected="$2" algorithm="$3" actual
  if [ "$algorithm" = md5 ]; then
    actual="$(md5sum "$file" | awk '{print $1}')"
  else
    actual="$(sha256sum "$file" | awk '{print $1}')"
  fi
  [ "$actual" = "$expected" ] || {
    echo "ERROR: $algorithm mismatch for $file" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  }
}

SOURCE_IMG="$(usage_path "$SOURCE_IMG")"
OUTPUT_IMG="$(usage_path "$OUTPUT_IMG")"

for tool in cp dd losetup mount umount sha256sum md5sum sgdisk sed awk e2fsck install mktemp mountpoint od; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: required tool not found: $tool" >&2
    exit 1
  }
done

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root, for example: wsl -u root -e bash scripts/make-fnos-agibot.sh" >&2
  exit 1
fi

check_file "$SOURCE_IMG" "official fnOS Rock 5B image"
check_file "$IDBLOADER" "AGIBOT idbloader"
check_file "$UBOOT_ITB" "AGIBOT U-Boot ITB"
check_file "$BOARD_DTB" "AGIBOT DTB"

echo ">>> Verifying inputs"
check_hash "$SOURCE_IMG" "$SOURCE_MD5" md5
check_hash "$IDBLOADER" "$IDBLOADER_SHA256" sha256
check_hash "$UBOOT_ITB" "$UBOOT_SHA256" sha256
check_hash "$BOARD_DTB" "$DTB_SHA256" sha256

mkdir -p "$(dirname "$OUTPUT_IMG")"
if [ -e "$OUTPUT_IMG" ]; then
  echo "ERROR: output already exists: $OUTPUT_IMG" >&2
  exit 1
fi

echo ">>> Copying official image (sparse copy when supported)"
cp --sparse=always --reflink=auto "$SOURCE_IMG" "$OUTPUT_IMG"

echo ">>> Installing AGIBOT bootloader"
# Rockchip RK3588 layout: idbloader at LBA64 (32 KiB), U-Boot FIT at LBA16384 (8 MiB).
dd if="$IDBLOADER" of="$OUTPUT_IMG" bs=512 seek=64 conv=notrunc,fsync status=none
dd if="$UBOOT_ITB" of="$OUTPUT_IMG" bs=512 seek=16384 conv=notrunc,fsync status=none

magic="$(dd if="$OUTPUT_IMG" bs=4 skip=8192 count=1 status=none)"
[ "$magic" = "RKNS" ] || { echo "ERROR: idbloader RKNS magic not found at 32 KiB" >&2; exit 1; }
magic="$(dd if="$OUTPUT_IMG" bs=4 skip=2097152 count=1 status=none | od -An -tx1 | tr -d ' \n')"
[ "$magic" = "d00dfeed" ] || { echo "ERROR: U-Boot FIT magic not found at 8 MiB" >&2; exit 1; }

echo ">>> Mounting boot partition"
LOOP_DEV="$(losetup -f --show -P "$OUTPUT_IMG")"
BOOT_DEV="${LOOP_DEV}p1"
[ -b "$BOOT_DEV" ] || { echo "ERROR: partition node not found: $BOOT_DEV" >&2; exit 1; }
BOOT_MNT="$(mktemp -d)"
mount -t ext4 "$BOOT_DEV" "$BOOT_MNT"

[ -f "$BOOT_MNT/fnEnv.txt" ] || { echo "ERROR: fnEnv.txt missing in BOOT partition" >&2; exit 1; }
[ -f "$BOOT_MNT/boot.scr" ] || { echo "ERROR: boot.scr missing in BOOT partition" >&2; exit 1; }
[ -d "$BOOT_MNT/dtb/rockchip" ] || { echo "ERROR: dtb/rockchip missing in BOOT partition" >&2; exit 1; }

install -m 0644 "$BOARD_DTB" "$BOOT_MNT/dtb/$DTB_PATH"
sed -i -E "s#^fdtfile=.*#fdtfile=$DTB_PATH#" "$BOOT_MNT/fnEnv.txt"
if ! grep -qx "fdtfile=$DTB_PATH" "$BOOT_MNT/fnEnv.txt"; then
  printf '\nfdtfile=%s\n' "$DTB_PATH" >> "$BOOT_MNT/fnEnv.txt"
fi

echo ">>> Patched fnEnv.txt"
grep -E '^(fdtfile|kernelfile)=' "$BOOT_MNT/fnEnv.txt"

sync
umount "$BOOT_MNT"
rmdir "$BOOT_MNT"
BOOT_MNT=""

echo ">>> Checking ext4 metadata without making changes"
e2fsck -fn "$BOOT_DEV" || {
  echo "ERROR: boot partition failed e2fsck -fn" >&2
  exit 1
}

losetup -d "$LOOP_DEV"
LOOP_DEV=""

echo ">>> Final partition table"
sgdisk -p "$OUTPUT_IMG"

echo ">>> Writing SHA-256"
sha256sum "$OUTPUT_IMG" > "$OUTPUT_IMG.sha256"

echo ">>> Done: $OUTPUT_IMG"
cat "$OUTPUT_IMG.sha256"
