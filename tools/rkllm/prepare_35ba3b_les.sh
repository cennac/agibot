#!/usr/bin/env bash
# Input must already have passed the official SHA256 check.
set -euo pipefail
ROOT=${MINICPM35_ROOT:-/root/models/minicpmv47-35ba3b}
OMNI=${LLAMA_OMNI_ROOT:-/root/llama.cpp-omni-les}
MODEL="$ROOT/MiniCPM-V-4_7-35B-A3B-mix_q3gud_im.gguf"
EXPERTS="$ROOT/experts-mixq3"
RESIDENT="$ROOT/resident-mixq3.gguf"
test -s "$MODEL"
test ! -e "$EXPERTS"
test ! -e "$RESIDENT"
date -Is
python3 "$OMNI/tools/moe/experts.py" extract --model "$MODEL" --out-dir "$EXPERTS"
python3 "$OMNI/tools/moe/experts.py" verify --model "$MODEL" --experts "$EXPERTS"
python3 "$OMNI/tools/moe/strip_experts.py" --model "$MODEL" --experts "$EXPERTS" --out "$RESIDENT"
stat -c '%n %s bytes' "$MODEL" "$RESIDENT" "$EXPERTS/manifest.json"
date -Is
echo LES_PREPARE_OK
