import os
import sys
import numpy as np
import torch
import torch.nn as nn
from transformers import AutoModelForImageTextToText

ROOT = os.environ.get("RKLLM_CONVERT_ROOT", "/data/rkllm-convert")
MODEL = os.environ.get("RKLLM_MODEL", os.path.join(ROOT, "model47"))
GRID = 72
OUT = os.path.join(ROOT, "vision_m47_fold.onnx")
PACKED = os.path.join(ROOT, "vision_m47_fold_packed.onnx")
DATA = os.path.join(ROOT, "vision_m47_fold.data")

print("loading full model (fp32, eager)...", flush=True)
model = AutoModelForImageTextToText.from_pretrained(
    MODEL, torch_dtype=torch.float32, attn_implementation="eager"
)
model.eval()

# ---- fold attention scale into q_proj (weight & bias) so the exported graph
# contains NO Mul(scale) after the QK MatMul (rknn 2.5.0 fuse rules crash on it)
folded = 0
for name, mod in model.named_modules():
    if "self_attn" not in name:
        continue
    s = None
    for attr in ("scale", "scaling"):
        v = getattr(mod, attr, None)
        if isinstance(v, float):
            s = v
            break
        if torch.is_tensor(v) and v.numel() == 1:
            s = float(v.reshape(-1)[0])
            break
    if s is None or s == 1.0:
        continue
    with torch.no_grad():
        mod.q_proj.weight.mul_(s)
        if mod.q_proj.bias is not None:
            mod.q_proj.bias.mul_(s)
    for attr in ("scale", "scaling"):
        if getattr(mod, attr, None) is not None:
            setattr(mod, attr, 1.0 if isinstance(getattr(mod, attr), float) else torch.ones_like(torch.tensor(0.0)))
    folded += 1
    print(f"  folded scale {s:.6f} into {name}.q_proj", flush=True)
print("folded modules:", folded, flush=True)
assert folded > 0, "no attention scale found to fold"

class VisionExport(nn.Module):
    def __init__(self, m, grid):
        super().__init__()
        self.vision_tower = m.model.vision_tower
        self.merger = m.model.merger
        self.grid = grid

    def forward(self, pixel_values):
        ts = torch.tensor([[self.grid, self.grid]], dtype=torch.int64)
        out = self.vision_tower(pixel_values, target_sizes=ts, use_vit_merger=True)
        feats = self.merger(out.last_hidden_state, ts // 2)
        return feats[0].unsqueeze(0)

wrap = VisionExport(model, GRID)

rng = np.random.default_rng(0)
px = rng.random((1, 3, GRID * 14, GRID * 14), dtype=np.float32)
px_t = torch.from_numpy((px / 0.5 - 1.0).astype(np.float32))

with torch.no_grad():
    # reference from a pristine reload to prove folding is exact
    ref_model = AutoModelForImageTextToText.from_pretrained(
        MODEL, torch_dtype=torch.float32, attn_implementation="eager")
    ref_model.eval()
    ts = torch.tensor([[GRID, GRID]], dtype=torch.int64)
    with torch.no_grad():
        vo = ref_model.get_image_features(px_t, target_sizes=ts)
        ref = vo.pooler_output[0].unsqueeze(0)
    ours = wrap(px_t)
diff = (ref - ours).abs().max().item()
print(f"folded-vs-official max abs diff: {diff:.6f}  shape: {tuple(ours.shape)}", flush=True)
assert diff < 1e-3, "fold changed numerics too much"
T = ours.shape[1]
print("image tokens per image:", T, flush=True)

print("exporting ONNX (dynamo=False)...", flush=True)
torch.onnx.export(
    wrap, (px_t,), OUT,
    input_names=["pixel_values"], output_names=["image_embeds"],
    dynamic_axes=None, opset_version=17, do_constant_folding=True, dynamo=False,
)
print("ONNX saved:", OUT, flush=True)

# pack external data into the .data file and verify via ORT
import onnx
m = onnx.load(OUT)
onnx.save_model(m, PACKED,
                save_as_external_data=True, location=os.path.basename(DATA),
                size_threshold=0, convert_attribute=False)
import onnxruntime as ort
sess = ort.InferenceSession(PACKED,
                            providers=["CPUExecutionProvider"])
ort_out = sess.run(None, {"pixel_values": px_t.numpy()})[0]
odiff = np.abs(ort_out - ref.numpy()).max()
rel = odiff / max(float(np.abs(ref.numpy()).max()), 1e-9)
print(f"ort-vs-torch max abs diff: {odiff:.6f} (rel {rel:.6f})", flush=True)
assert rel < 1e-4
print("FOLD_EXPORT_OK", flush=True)
