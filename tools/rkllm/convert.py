import os
import sys, traceback
ROOT = os.environ.get("RKLLM_CONVERT_ROOT", "/data/rkllm-convert")
MODEL = os.environ.get("RKLLM_MODEL", os.path.join(ROOT, "model47"))
CALIB = os.environ.get("RKLLM_CALIB", os.path.join(ROOT, "calib.json"))
OUT = os.environ.get("RKLLM_OUT", os.path.join(ROOT, "minicpmv47_1b_w8a8.rkllm"))
from rkllm.api import RKLLM

print("== load_huggingface ==", flush=True)
rkllm = RKLLM()
ret = rkllm.load_huggingface(model=MODEL, model_lora=None, device="cpu")
print("load ret:", ret, flush=True)
if ret != 0:
    sys.exit(10)

print("== build ==", flush=True)
ret = rkllm.build(
    do_quantization=True,
    optimization_level=1,
    quantized_dtype="w8a8",
    quantized_algorithm="normal",
    target_platform="rk3588",
    num_npu_core=3,
    dataset=CALIB,
    hybrid_rate=0,
    max_context=4096,
)
print("build ret:", ret, flush=True)
if ret != 0:
    sys.exit(11)

print("== export ==", flush=True)
ret = rkllm.export_rkllm(OUT)
print("export ret:", ret, flush=True)
if ret != 0:
    sys.exit(12)
print("CONVERT_DONE", flush=True)
