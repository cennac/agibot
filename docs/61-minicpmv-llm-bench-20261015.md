# MiniCPM-V LLM benchmark on the AGIBOT board (llama.cpp, CPU-only)

Date: 2026-10-15 (Asia/Shanghai)

## Scope

The user asked to run the MiniCPM-V model family (per
`https://github.com/OpenBMB/MiniCPM-V/blob/main/README_zh.md`) on the AGIBOT
controller — online as `agibot` at `192.168.88.89` — and measure generation
throughput and memory usage. This is a pure-userspace benchmark: no kernel,
device-tree, firmware, or boot configuration was touched.

Board state at test time:

```text
Armbian jammy, kernel 6.1.115-vendor-rk35xx aarch64, uptime 10 min (fresh boot)
CPU: RK3588, 8 cores — cpu0-3 Cortex-A55 @1.8 GHz, cpu4-7 Cortex-A76 @2.208 GHz
RAM: 15 GiB total; eMMC mmcblk0 228 G (rootfs, 224 G free)
NPU: not used (llama.cpp CPU path only)
```

## Environment setup

Toolchain was missing on the fresh system and installed from the Jammy
repository: `build-essential cmake git libcurl4-openssl-dev pkg-config time`.

llama.cpp was built from master (`ggml-org/llama.cpp`, depth-1 clone,
2026-10-15) at `/root/llama.cpp`:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON \
      -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_BUILD_SERVER=ON
cmake --build build --config Release -j 6    # rc=0
```

Two MiniCPM-V models were used, both official OpenBMB GGUF releases fetched
from HuggingFace:

| Model | Files in `/root/models/` | Size |
|---|---|---|
| MiniCPM-V 4.7-1B | `m47-1b-q4km.gguf` (MiniCPM-V-4_7-1B-Q4_K_M) | 672 MB |
| | `m47-1b-mmproj-f16.gguf` (mmproj-model-f16) | 1.11 GB |
| MiniCPM-V 4.5 8B | `m45-q4km.gguf` (MiniCPM-V-4_5-Q4_K_M) | 5.03 GB |
| | `m45-mmproj-f16.gguf` (mmproj-model-f16) | 1.10 GB |

The README flagship MiniCPM-V 4.7-35B-A3B was **not** run in this benchmark:
the Q4 releases considered here are ~20 GB and exceed the 15 GiB board RAM
for full residency. The official mixed Q3 release (~15.5 GB) and LES expert
streaming offer other paths; see the subsequent [35B-A3B experiment](./65-minicpmv47-35ba3b-rk3588-20261015.md).

## Network notes (for reproduction)

The board cannot reach `huggingface.co` or Wikimedia directly. `hf-mirror.com`
works for small files but stalls on multi-GB LFS objects, and a direct
`git clone` of GitHub fails with `curl 16 HTTP2 framing layer` and then crawls.
The reliable route used for all downloads was the Windows host Clash proxy:

```bash
curl -x http://192.168.88.128:7897 ...        # HF LFS downloads, fast
git -c http.version=HTTP/1.1 -c http.proxy=http://192.168.88.128:7897 clone ...
```

## Benchmark method

`llama-server` (from the build above) with the model + `--mmproj`, `-c 4096`,
`-t 8`, then two requests per model against the OpenAI-compatible endpoint:

1. **Image request** — a 320×200 synthetic BMP (blue/green/red regions)
   base64-inlined, prompt `用中文详细描述这张图片`, `max_tokens 128`, temp 0.
2. **Text request** — prompt `用中文介绍一下你自己`, `max_tokens 128`, temp 0.

Timings were taken from the server's `slot print_timing` log lines (prompt
eval includes vision-encoder time for image requests). Peak memory was read
from `/proc/<pid>/status VmHWM` (wrapping `/usr/bin/time -v` proved unreliable
because killing the wrapper loses its report).

## Results

| Metric | MiniCPM-V 4.7-1B (Q4_K_M) | MiniCPM-V 4.5 8B (Q4_K_M) |
|---|---|---|
| Text generation | **23.2–23.5 tok/s** | **3.38–3.45 tok/s** |
| Text prompt eval | 53.8 tok/s (18.6 ms/tok) | 7.8 tok/s (128 ms/tok) |
| Image prompt eval (incl. ViT) | 89.9 s / 80 tokens (0.89 tok/s) | 19.4 s / 82 tokens (4.22 tok/s) |
| Peak RSS (VmHWM) | **~5.1 GB** | **~10.3 GB** |

Raw numbers from the server logs:

```text
# 4.7-1B, image request
prompt eval time = 89918.36 ms /   80 tokens (1123.98 ms/token,  0.89 tok/s)
       eval time =  5215.70 ms /  122 tokens (  43.10 ms/token, 23.20 tok/s)
# 4.7-1B, text request
prompt eval time =   260.18 ms /   14 tokens ( 18.58 ms/token, 53.81 tok/s)
       eval time =  3909.32 ms /   93 tokens ( 42.49 ms/token, 23.53 tok/s)

# 4.5-8B, image request
prompt eval time = 19411.36 ms /   82 tokens (236.72 ms/token,  4.22 tok/s)
       eval time = 37533.65 ms /  128 tokens (295.54 ms/token,  3.38 tok/s)
# 4.5-8B, text request
prompt eval time =  1407.26 ms /   11 tokens (127.93 ms/token,  7.82 tok/s)
       eval time = 24950.81 ms /   87 tokens (290.13 ms/token,  3.45 tok/s)

VmHWM: 10772040 kB   (4.5-8B, image request, llama-server)
VmHWM:  5395356 kB   (4.7-1B, image request, llama-mtmd-cli)
```

Both models produced coherent Chinese descriptions of the test image;
1B output includes a visible `<think>` block followed by the answer.

## Observations

- **4.7-1B is the practical choice for real-time interaction on this board**:
  ~23 tok/s generation is reading-speed, ~5.1 GB peak fits comfortably.
- **4.5-8B runs but is at the board's limit**: 10.3 GB peak (⅔ of RAM),
  ~3.4 tok/s means a 100-character answer takes ~30 s. Larger quants (Q8/F16)
  exceed this board's full-residency budget. The 35B-A3B requires a separate
  assessment of mixed quantization, paging, or expert streaming (see record 65).
- **MiniCPM-V 4.5 emits `<think>` reasoning by default**: with
  `max_tokens 128` the entire budget was consumed by the reasoning phase
  (`finish_reason: length`, empty `content`, answer accumulated in
  `reasoning_content`). Real deployments need `max_tokens ≥ 300` or the
  template flag to disable thinking.
- **Vision-encode cost is architecture-dependent, not size-dependent**: the
  1B's mmproj took ~90 s to encode one image while the 8B's took ~19 s, so
  per-frame image queries on the 1B are dominated by the encoder, not the LLM.
- The 6 TOPS NPU was unused. A follow-up with airockchip `rknn-llm` (RKLLM
  format) is the obvious next step for higher throughput; `/root/npu_test/`
  holds earlier NPU experiments on this board.

## Artifacts left on the board

```text
/root/llama.cpp/         llama.cpp master build (build/bin/llama-server, llama-mtmd-cli, ...)
/root/models/            4 GGUF files listed above (7.9 GB total)
/root/test.bmp           benchmark test image
/root/srv_t1b.log /root/srv_t8b.log /root/srv_rss.log   server logs
/root/resp_img_t1b.json /root/resp_img_t8b.json /root/resp_txt_*.json
```

No changes were made to the Armbian system beyond apt packages listed above;
all test processes were stopped and RAM was back to 281 MiB used at the end.
