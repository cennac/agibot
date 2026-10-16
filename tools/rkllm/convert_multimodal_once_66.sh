#!/usr/bin/env bash
set -euo pipefail

# One-command MiniCPM-V 4.7-1B conversion for the 66 conversion host.
# The vision path intentionally uses the folded-attention workaround required
# by rknn-toolkit2 2.5.0; the plain ONNX path crashes in RKNN graph fusion.

ROOT="${RKLLM_CONVERT_ROOT:-/data/rkllm-convert}"
MODEL="${RKLLM_MODEL:-$ROOT/model47}"
TEXT_PY="${RKLLM_TEXT_PY:-$ROOT/venv/bin/python}"
VISION_PY="${RKLLM_VISION_PY:-$ROOT/venv-vision/bin/python}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ID="${RKLLM_RUN_ID:-$(date -u +%Y%m%d-%H%M%S)}"
RUN_DIR="$ROOT/runs/$RUN_ID"

if [[ -e "$RUN_DIR" ]]; then
  echo "run directory already exists: $RUN_DIR" >&2
  exit 2
fi
mkdir -p "$RUN_DIR"
exec > >(tee "$RUN_DIR/convert.log") 2>&1

echo "== MiniCPM-V one-shot conversion =="
echo "root:  $ROOT"
echo "model: $MODEL"
echo "run:   $RUN_DIR"
echo "date:  $(date -Is)"

for exe in "$TEXT_PY" "$VISION_PY"; do
  [[ -x "$exe" ]] || { echo "missing executable: $exe" >&2; exit 3; }
done
[[ -d "$MODEL" ]] || { echo "missing model directory: $MODEL" >&2; exit 4; }

# RKLLM 1.3.1 requires this field for MiniCPM-V 4.7. Do not silently convert
# a model with a different merger setting because that changes token geometry.
"$TEXT_PY" - "$MODEL" <<'PY'
import json, sys
p = sys.argv[1] + "/config.json"
d = json.load(open(p, encoding="utf-8"))
v = d.get("vision_config", {})
assert v.get("spatial_merge_size") == 1, (
    f"{p}: vision_config.spatial_merge_size must be 1, got {v.get('spatial_merge_size')!r}"
)
print("config check: spatial_merge_size=1")
PY

export RKLLM_CONVERT_ROOT="$RUN_DIR"
export RKLLM_MODEL="$MODEL"
export RKLLM_CALIB="$RUN_DIR/calib.json"
export RKLLM_OUT="$RUN_DIR/minicpmv47_1b_w8a8.rkllm"

echo "== 1/4 calibration =="
"$TEXT_PY" "$SCRIPT_DIR/make_calib.py"

echo "== 2/4 text RKLLM =="
"$TEXT_PY" "$SCRIPT_DIR/convert.py"

echo "== 3/4 folded vision ONNX =="
"$VISION_PY" "$SCRIPT_DIR/export_vision_m47_folds.py"

echo "== 4/4 RKNN =="
"$VISION_PY" "$SCRIPT_DIR/rknn_convert_m47.py"

echo "== output validation =="
for f in \
  "$RUN_DIR/minicpmv47_1b_w8a8.rkllm" \
  "$RUN_DIR/vision_m47_fp16.rknn" \
  "$RUN_DIR/vision_m47_fold.onnx" \
  "$RUN_DIR/vision_m47_fold.data" \
  "$RUN_DIR/vision_m47_foldrk.onnx" \
  "$RUN_DIR/vision_m47_foldrk.data" \
  "$RUN_DIR/vision_golden_output.npy"; do
  [[ -s "$f" ]] || { echo "missing/empty output: $f" >&2; exit 20; }
  stat -c '%s %n' "$f"
done

"$VISION_PY" - "$RUN_DIR/vision_golden_output.npy" <<'PY'
import numpy as np, sys
x = np.load(sys.argv[1])
assert x.ndim == 3 and x.shape[0] == 1 and x.shape[1] == 324, x.shape
print("golden output shape:", tuple(x.shape), "(324 image tokens)")
PY

cat > "$RUN_DIR/manifest.txt" <<EOF
model=$MODEL
run_dir=$RUN_DIR
text=$RUN_DIR/minicpmv47_1b_w8a8.rkllm
vision=$RUN_DIR/vision_m47_fp16.rknn
vision_tokens=324
input_pixels=1008x1008
rkllm_image_canvas=252x252
EOF
echo "CONVERSION_OK $RUN_DIR"
