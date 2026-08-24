#!/usr/bin/env bash
# Patch the fnOS c951 Rockchip MPP module to defer RKVDEC2 until its CCU probes.
set -euo pipefail

MODULE="${1:?usage: $0 path/to/rk_vcodec.ko}"
EXPECTED_SHA256="f404180965c46620ad214dba35b2968ead3a86ad1820081cc5493cfa7d38691f"
PATCHED_SHA256="23c94e46c848434b358646ab08878bcbf5dcde529971494649c02830832c5617"
OFFSET=$((0x113b4))

actual="$(sha256sum "$MODULE" | awk '{print $1}')"
if [ "$actual" = "$PATCHED_SHA256" ]; then
	echo "Already patched: $MODULE"
	exit 0
fi
[ "$actual" = "$EXPECTED_SHA256" ] || {
	echo "ERROR: unsupported rk_vcodec.ko SHA-256: $actual" >&2
	exit 1
}

bytes="$(od -An -tx1 -j "$OFFSET" -N4 "$MODULE" | tr -d ' \n')"
[ "$bytes" = "60018012" ] || {
	echo "ERROR: unexpected instruction at offset 0x113b4: $bytes" >&2
	exit 1
}

printf '\200\100\200\022' | dd of="$MODULE" bs=1 seek="$OFFSET" conv=notrunc status=none
actual="$(sha256sum "$MODULE" | awk '{print $1}')"
[ "$actual" = "$PATCHED_SHA256" ] || {
	echo "ERROR: patched module SHA-256 mismatch: $actual" >&2
	exit 1
}

echo "Patched RKVDEC2 CCU return value: -ENOMEM -> -EPROBE_DEFER"
sha256sum "$MODULE"
