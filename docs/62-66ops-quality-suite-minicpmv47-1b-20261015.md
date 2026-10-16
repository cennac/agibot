# 66ops quality suite result: MiniCPM-V 4.7-1B on the AGIBOT board

Date: 2026-10-15 (Asia/Shanghai)

## Scope

The 66ops local objective quality regression suite
(`static/pages/test/quality-data.js`, suite v5, id `local-objective-v5-20260826`,
30 items, exact-match 0/100 scoring) was executed against **MiniCPM-V 4.7-1B
(Q4_K_M)** running on the AGIBOT board `agibot` (192.168.88.89, RK3588, CPU
only) — the same model benchmarked for throughput in document 61. This is the
first time the suite has been run against an on-device small model instead of
the GPU-hosted models on 192.168.88.66.

No change to the 66ops platform itself; the suite protocol was replicated
exactly in a driver script so the board's llama-server could serve the items.

## Execution protocol (identical to the 66ops frontend)

- Endpoint: `http://192.168.88.89:8811/v1/chat/completions` (llama-server,
  `-c 12288 -t 8`, model `m47-1b-q4km.gguf`, no mmproj needed — suite is text-only).
- Per item: system prompt `你正在参加可复现的客观能力测试。独立求解题目，严格遵守题目指定的最终输出格式。`,
  `temperature 0`, `seed 20260819`, `max_tokens 10000` (suite default).
- Grading: exact port of `quality.js` — `<think>` stripped, last `答案=...`
  line extracted, normalized (fullwidth punctuation → `,`, case-folded);
  instruction items validated structurally (JSON parse, exact strings);
  `finish_reason=length` scores 0 (`输出达到max_tokens，结果无效`).
- Driver: `E:\AIPorject\101\_tmp\quality_minicpmv_1b.py` (resumable);
  full per-item results: `E:\AIPorject\101\_tmp\quality_result_minicpmv47_1b.json`.

## Result

**Total score: 33.3 / 100** (10 of 30 items passed; runtime ~64 min)

| Category | Items | Score |
|---|---|---|
| reasoning 推理 | 6 | **0.0** |
| code 代码 | 6 | **50.0** |
| math 数学 | 6 | **66.7** |
| instruction 指令遵循 | 6 | **16.7** |
| chinese 中文理解 | 6 | **33.3** |

Speed metrics: median 22.5 tok/s, mean 21.35 tok/s, weighted 16.06 tok/s
(dragged down by two 10000-token capped runs).

## Observations

- **Math is the surprise strength (4/6, all three solvable hard items
  correct)**: 29/44 probability, derangement 44, CRT x≡23 — the thinking
  model earns its keep on math; the two misses were a counting problem
  (3024 vs 2296) and a 10000-token runaway on the hypergeometric draw.
- **Reasoning is a clean 0/6** — Wason selection failed (`A 和 4` vs `A,7`),
  truth-liar puzzle concluded the wrong person, and one item ran to the
  10000-token cap. One item (排列) had *correct* reasoning but formatted the
  answer as `[乙, 甲, 丁, 丙]` — exact-match scored it 0.
- **Format strictness, not knowledge, drives several losses**: 4 chinese items
  (25/27/29/30) picked the *correct* option but wrote the full option text
  (e.g. `B. 把时间先后当作因果`) instead of the bare letter. A lenient scorer
  would put the model around 43-47; the suite's strictness is by design.
- **Instruction following is weak (1/6)**: JSON key-order and compact-format
  items failed; notably the *prompt-injection resistance* item (难) passed.
- **Two items hit the 10000-token cap** (Q5, Q14), both scoring 0 by rule —
  at ~14-19 tok/s a runaway costs ~12 min each, worth remembering when
  scheduling on-device runs.
- For comparison against GPU-hosted models, run the same suite from the
  66ops quality page (add the board as an upstream channel in the gateway,
  or load the model on 66). The result JSON contains everything needed to
  backfill a run row (`quality_test_runs`/`quality_test_items` schema).

## Board state after test

llama-server on :8811 was stopped after the run. Restart with:

```bash
cd /root/llama.cpp && nohup ./build/bin/llama-server \
  -m /root/models/m47-1b-q4km.gguf -c 12288 -t 8 --port 8811 --host 0.0.0.0 \
  > /root/srv_quality.log 2>&1 &
```
