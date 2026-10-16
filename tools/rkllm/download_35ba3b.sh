#!/usr/bin/env bash
set -euo pipefail
ROOT=${MINICPM35_ROOT:-/root/models/minicpmv47-35ba3b}
PROXY=${MINICPM35_PROXY:-http://192.168.88.128:7897}
BASE=https://huggingface.co/openbmb/MiniCPM-V-4.7-35B-A3B-gguf/resolve/main
mkdir -p -- "$ROOT"
cd -- "$ROOT"
fetch() {
  local name=$1 hash=$2
  if test -f "$name"; then
    printf '%s  %s\n' "$hash" "$name" | sha256sum --check -
    return
  fi
  aria2c --all-proxy="$PROXY" --continue=true --auto-file-renaming=false \
    --max-connection-per-server=8 --split=8 --min-split-size=16M \
    --file-allocation=none --check-integrity=true --checksum="sha-256=$hash" \
    --max-tries=5 --retry-wait=3 --summary-interval=15 --console-log-level=warn \
    --download-result=full -o "$name.part" "$BASE/$name?download=true"
  mv -- "$name.part" "$name"
}
fetch MiniCPM-V-4_7-35B-A3B-mix_q3gud_im.gguf 51e32201f0ddaf87dbb9689ceef9e3aa1a1543a1366706aa2abbf3aabb34df6b
fetch mmproj-model-f16.gguf bff3b688e14c300eca273092c37c50a0ddfcc2054e079af1a0480edeed5d20f1
echo MODEL_DOWNLOAD_OK
