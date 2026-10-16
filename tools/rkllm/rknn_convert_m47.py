import os
import numpy as np
import onnx

# 1) consolidate the 458 per-tensor external files into one .data file
ROOT = os.environ.get("RKLLM_CONVERT_ROOT", "/data/rkllm-convert")
src = os.path.join(ROOT, "vision_m47_fold_packed.onnx")
dst = os.path.join(ROOT, "vision_m47_foldrk.onnx")
rk_path = os.path.join(ROOT, "vision_m47_fp16.rknn")
golden_input = os.path.join(ROOT, "vision_golden_input.npy")
golden_output = os.path.join(ROOT, "vision_golden_output.npy")
m = onnx.load(src)  # pulls in external tensor files automatically
for init in m.graph.initializer:
    init.ClearField("external_data")
    init.data_location = 0
onnx.save_model(
    m, dst,
    save_as_external_data=True,
    location="vision_m47_foldrk.data",
    size_threshold=0,
    convert_attribute=False,
)
print("packed ONNX saved:", dst, flush=True)

# 2) golden reference for later numeric check (same input as export validation)
rng = np.random.default_rng(0)
px = rng.random((1, 3, 1008, 1008), dtype=np.float32)
px = (px / 0.5 - 1.0).astype(np.float32)
np.save(golden_input, px)
import onnxruntime as ort
sess = ort.InferenceSession(dst, providers=["CPUExecutionProvider"])
ref = sess.run(None, {"pixel_values": px})[0]
np.save(golden_output, ref)
print("golden saved:", ref.shape, flush=True)

# 3) RKNN conversion (fp16, no quantization for the vision tower)
from rknn.api import RKNN
rknn = RKNN(verbose=False)
rknn.config(
    mean_values=[[127.5, 127.5, 127.5]],
    std_values=[[127.5, 127.5, 127.5]],
    target_platform="rk3588",
    quantized_dtype="w8a8",
    quantized_method="channel",
    optimization_level=0,
)
ret = rknn.load_onnx(model=dst)
print("load_onnx:", ret, flush=True)
assert ret == 0
ret = rknn.build(do_quantization=False)
print("build:", ret, flush=True)
assert ret == 0
ret = rknn.export_rknn(rk_path)
print("export_rknn:", ret, flush=True)
assert ret == 0
print("RKNN_SAVED", flush=True)

# 4) simulator sanity check vs golden
ret = rknn.init_runtime()  # x86 simulator
print("init_runtime(sim):", ret, flush=True)
if ret == 0:
    # RKNN applies the configured (x - 127.5) / 127.5 preprocessing.
    # The ONNX golden input is already normalized; pass pixel values here.
    pixels = ((px + 1.0) * 127.5).astype(np.float32)
    outs = rknn.inference(inputs=[pixels], data_format="nchw")
    out = np.asarray(outs[0])
    assert out.shape == ref.shape, (out.shape, ref.shape)
    assert np.isfinite(out).all(), "non-finite simulator output"
    denom = max(np.abs(ref).max(), 1e-6)
    rel = np.abs(out - ref).max() / denom
    print(f"simulator-vs-golden: max_abs={np.abs(out - ref).max():.4f} rel={rel:.5f} shape={out.shape}", flush=True)
    assert rel < 0.02, f"FP16 simulator error exceeds 2% of golden peak: {rel}"
    print("SIM_CHECK_DONE", flush=True)
else:
    raise RuntimeError(f"simulator init failed: {ret}")
rknn.release()
print("ALL_DONE", flush=True)
