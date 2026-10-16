#!/bin/bash
# WSL2 qemu binfmt registration script
# Run this after WSL starts, before running armbian/build compile.sh
# WSL2 disables systemd-binfmt (ConditionVirtualization=!wsl) and restricts
# /proc/sys/fs/binfmt_misc/register, so we mount a separate binfmt_misc and
# register qemu handlers through it.

BINFMT_MNT="/tmp/binfmt-qemu"

if ! mountpoint -q "$BINFMT_MNT" 2>/dev/null; then
    mkdir -p "$BINFMT_MNT"
    mount -t binfmt_misc none "$BINFMT_MNT"
fi

register_qemu() {
    local name=$1 magic=$2 mask=$3 interpreter=$4
    if [[ -e "/proc/sys/fs/binfmt_misc/${name}" ]]; then
        echo "qemu-${name}: already registered, skipping"
        return 0
    fi
    echo ":${name}:M::${magic}:${mask}:${interpreter}:OCF" > "$BINFMT_MNT/register" 2>/dev/null
    if [[ -e "/proc/sys/fs/binfmt_misc/${name}" ]]; then
        echo "qemu-${name}: registered successfully"
    else
        echo "qemu-${name}: FAILED to register"
    fi
}

# aarch64 (ARM64)
register_qemu "qemu-aarch64" \
    "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00" \
    "\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff" \
    "/usr/bin/qemu-aarch64-static"

# arm (ARM32)
register_qemu "qemu-arm" \
    "\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00" \
    "\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff" \
    "/usr/bin/qemu-arm-static"

# riscv64
register_qemu "qemu-riscv64" \
    "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xf3\x00" \
    "\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff" \
    "/usr/bin/qemu-riscv64-static"

# loongarch64
register_qemu "qemu-loongarch64" \
    "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x02\x01" \
    "\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff" \
    "/usr/bin/qemu-loongarch64-static"

echo ""
echo "=== Verification ==="
for arch in arm64 arm riscv64; do
    result=$(arch-test $arch 2>&1)
    echo "arch-test $arch: $result"
done
