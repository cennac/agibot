# MiniCPM-V 4.7-1B on the RK3588 NPU (RKLLM 1.3.1): porting notes and benchmark

Date: 2026-10-15 (Asia/Shanghai)

## Scope

After the CPU benchmark (doc 61) and 66ops quality suite run (doc 62), the same
MiniCPM-V 4.7-1B was ported to the RK3588 NPU via Rockchip's RKLLM stack and
benchmarked against the CPU results. Text-only inference (the NPU path does not
cover the vision tower).

## Environments used

- **Conversion host**: 192.168.88.66 (`/data/rkllm-convert/`) — Python 3.12 venv
  (via `uv`, 26.04 system python is 3.14 which rkllm-toolkit does not support),
  torch 2.6.0 CPU wheel + toolkit deps from tuna mirror,
  `rkllm_toolkit-1.3.1-cp312` wheel from the rknn-llm release tarball.
  The local Windows box was explicitly ruled out by the user (disk pressure);
  its WSL was used briefly for toolchain evaluation and then unregistered.
- **Target**: board `agibot` 192.168.88.89 — `/root/rkllm/` holds
  `librkllmrt.so` + `rkllm.h` (v1.3.1, aarch64), `llm_demo` (stock) and
  `llm_bench` (one-shot timed variant written for this test,
  `E:\AIPorject\101\_tmp\rkllm\llm_bench.cpp`), and
  `minicpmv47_1b_w8a8.rkllm` (1.30 GB).

## Conversion recipe (gotchas that cost time)

```python
llm = RKLLM()
llm.load_huggingface(model="model47/", device="cpu")   # minicpmv4_7 loads directly
llm.build(do_quantization=True, quantized_dtype="w8a8", quantized_algorithm="normal",
          target_platform="rk3588", num_npu_core=3,
          dataset="calib.json", max_context=4096)
llm.export_rkllm("minicpmv47_1b_w8a8.rkllm")
```

1. **Calibration JSON format** (doc page 17): `[{"input": "...", "target": "..."}]`
   — the answer key is `target`, NOT `output`; plain-text or wrong-key datasets
   fail with `the dataset format is incorrect`.
2. **Export requires `vision_config.spatial_merge_size`**: the wrapper config is
   `minicpmv4_7` with interleaved MRoPE; export refuses with "mrope is detected,
   but spatial_merge_size ... cannot be found" unless the field exists. Adding
   `"spatial_merge_size": 1` to `vision_config` is sufficient (vision is not
   exported; the check is config validation only).
3. rkllm-toolkit ships wheels for py3.10/3.11/3.12 only, and its declared
   dependencies are incomplete — `colorlog`, `flatbuffers`, `jsonlines` had to
   be added manually.
4. The hybrid-attention (linear+full) backbone loads without `flash-linear-attention`
   / `causal-conv1d` installed; those only accelerate the torch fast path
   during conversion.
5. `pkill -f <pattern>` inside a remote one-liner whose own command line
   contains the pattern kills the invoking shell — use script files.

## Board runtime facts

```text
rkllm-runtime 1.3.1, rknpu driver 0.9.8 (board shipped 0.9.8 — exact match), platform RK3588
model_dtype W8A8, npu_core_num 3, max_context_limit 4096
runtime pinned its helper threads to cpus [4,5,6,7] (A76 cluster) automatically
"Using mrope" — the interleaved-MRoPE text backbone is supported end to end
```

NPU device access goes through the DRM node (`/dev/dri/card1`, driver bound at
`fdab0000.npu`); `/sys/kernel/debug/rknpu/load` shows per-core utilization.

## Results (same board, same model family member)

| Metric | CPU llama.cpp Q4_K_M (doc 61) | NPU RKLLM w8a8 (this doc) |
|---|---|---|
| Text generation | 19.4–23.5 tok/s (drops to ~13–19 at long ctx) | **25.1 tok/s sustained** (300-token run); 18.6 tok/s on a 25-token answer |
| Prompt processing | 53.8 tok/s (text) | not measured separately (short prompts) |
| Compute occupancy | 8/8 cores at 100% | 3 NPU cores at ~53–76%; CPU ~idle |
| Model RAM | ~5.1 GB peak (incl. mmproj + KV) | ~1.3 GB weights + runtime KV |
| Vision | supported (mmproj, ~90 s/image) | not in the initial text-only run (see multimodal follow-up below) |
| Quality suite | 33.3/100 (doc 62) | not yet run |

The evaluation given before measuring — decode is bandwidth-bound, so the 6 TOPS
NPU buys roughly 1–1.3× decode speed over CPU for a 1B model, while freeing the
whole CPU — matched the outcome. The real wins are CPU offload (robot control
loops keep all 8 cores), lower power, and much lighter memory footprint.

## Reproduce on the board

```bash
cd /root/rkllm
LD_LIBRARY_PATH=. ./llm_bench ./minicpmv47_1b_w8a8.rkllm 300 4096 "你的提问"
cat /sys/kernel/debug/rknpu/load   # watch per-core NPU utilization
```

Chat-template thinking: the NPU runtime applies the model's chat template;
answers came out directly without a visible `<think>` block in these runs.

## Not done / follow-ups

- 66ops quality suite has not been rerun on the NPU path (needs the
  `rkllm_server` OpenAI-compatible demo or a small HTTP wrapper around
  `llm_bench`); w8a8 quantization may shift the 33.3/100 score either way.
- The 8B model (4.5) would need a ~4.5 GB w8a8 conversion on 66 — expected
  ~3–5 tok/s decode on NPU per the same bandwidth math.

## Multimodal follow-up (same day)

完整的故障、修复和验证记录见
[64-npu-multimodal-minicpmv47-fix-20261015.md](./64-npu-multimodal-minicpmv47-fix-20261015.md)。

The first NPU run was text-only because the vision tower had not yet been
wired into the RKLLM demo.  The missing piece was in
`_tmp/rkllm/mm_demo_example/deploy/src/main.cpp`:

- MiniCPM-V 4.7's RKNN vision input must be resized to the full tensor size
  (`1008x1008`).  The merger reduces the embedding sequence afterwards; it
  must not be used as the input resize size.
- RKLLM's `image_width`/`image_height` fields are the post-downsample canvas,
  so they must be `252x252` for this model.  Passing `1008x1008` makes the
  runtime calculate a `72x72` patch grid and reject it against the 324 output
  tokens (`patch_h * patch_w != n_image_tokens`).

After rebuilding `mm_deploy/build/demo`, the following command completed on
the board and returned a correct description of `data/demo.jpg`:

```bash
cd /root/rkllm/mm_deploy/build
export LD_LIBRARY_PATH=/root/rkllm:/root/rkllm/mm_deploy/build:$LD_LIBRARY_PATH
printf '<image>这张图片中有什么？\nexit\n' | ./demo \
  /root/rkllm/mm_demo_example/data/demo.jpg \
  /root/rkllm/vision_m47_fp16.rknn '' '' \
  /root/rkllm/minicpmv47_1b_w8a8.rkllm 96 4096 3 rk3588 \
  '<|vision_start|>' '<|vision_end|>' '<|image_pad|>'
```

The vision encoder took about 23.4 s on three NPU cores; the generated answer
identified the astronaut, the moon scene, and the green bottle.  The RKLLM
text-only benchmark above remains unchanged.
