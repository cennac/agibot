#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
    echo "Usage: ${0##*/} [SOURCE_DIR]" >&2
    exit 2
fi

SOURCE_DIR=${1:-/data/agibot-android14-build/aosp}
MANIFEST="$SOURCE_DIR/.repo/manifests/Android14_Radxa_u1_rk6.xml"
TAG_OBJECT=cd99dbe8b79005f8fcda159e996211e3f019dd57
PEELED_COMMIT=92e2a80095695a40fa854fff44268e0bc333c154

if [[ ! -f "$MANIFEST" ]]; then
    echo "Missing Radxa manifest: $MANIFEST" >&2
    exit 1
fi

old_count=$(grep -F -c "revision=\"$TAG_OBJECT\"" "$MANIFEST" || true)
new_count=$(grep -F -c "revision=\"$PEELED_COMMIT\"" "$MANIFEST" || true)

if [[ "$new_count" -eq 1 && "$old_count" -eq 0 ]]; then
    echo "prebuilts/sdk manifest repair already present"
    exit 0
fi

if [[ "$old_count" -ne 1 || "$new_count" -ne 0 ]]; then
    echo "Unexpected prebuilts/sdk revision state: old=$old_count new=$new_count" >&2
    exit 1
fi

sed -i "s/revision=\"$TAG_OBJECT\"/revision=\"$PEELED_COMMIT\"/" "$MANIFEST"

if ! grep -F -q "revision=\"$PEELED_COMMIT\"" "$MANIFEST"; then
    echo "Failed to apply prebuilts/sdk manifest repair" >&2
    exit 1
fi

echo "Repaired prebuilts/sdk revision: $TAG_OBJECT -> $PEELED_COMMIT"
echo "The manifests checkout now intentionally contains this one-line local diff."
