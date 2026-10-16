#!/usr/bin/env bash
set -euo pipefail
ROOT=${MINICPM35_ROOT:-/root/models/minicpmv47-35ba3b}
OMNI=${LLAMA_OMNI_ROOT:-/root/llama.cpp-omni-les}
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OUT=${MINICPM35_RESULTS:?Set MINICPM35_RESULTS to a new output directory}
test -s "$ROOT/mmproj-model-f16.gguf"
test -s "$ROOT/experts-mixq3/manifest.json"
# CPU backend lacks the fork's alloc-only buffer interface for stripped GGUFs.
# Full GGUF + no-mmap keeps expert metadata while allocating only virtual slots.
python3 "$HERE/bench_35ba3b.py" \
  --binary "$OMNI/build/bin/llama-cli" \
  --model "$ROOT/MiniCPM-V-4_7-35B-A3B-mix_q3gud_im.gguf" \
  --projector "$ROOT/mmproj-model-f16.gguf" \
  --experts "$ROOT/experts-mixq3" --no-mmap \
  --image /root/rkllm/mm_demo_example/data/demo.jpg --out "$OUT" "$@"
