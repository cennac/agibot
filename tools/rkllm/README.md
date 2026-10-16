# MiniCPM-V 4.7-1B 在 66 上一键转换

入口：`convert_multimodal_once_66.sh`。这套脚本针对 MiniCPM-V 4.7-1B 和 RK3588，
使用 66 已装好的两个 Python 环境，串联文本与视觉转换。它不负责下载模型、安装
转换工具或部署板端程序。

将本目录的五个脚本复制到 66 的 `/data/rkllm-convert/one-shot/`，然后运行：

```bash
bash /data/rkllm-convert/one-shot/convert_multimodal_once_66.sh
```

每次创建 `/data/rkllm-convert/runs/<UTC时间戳>/`，包含转换日志、校准集、ONNX
及其 external data、两份部署模型、golden 输入输出及 `manifest.txt`。运行目录
已存在时会报错退出。原来的模型和部署产物不被覆盖。

## 66 上使用的环境

Python 均为 3.12.14。模型路径为 `/data/rkllm-convert/model47`。

| 环境 | 实测版本 |
|---|---|
| `/data/rkllm-convert/venv` | rkllm-toolkit 1.3.1，torch 2.6.0+cpu，transformers 5.8.0，numpy 1.26.4 |
| `/data/rkllm-convert/venv-vision` | rknn-toolkit2 2.5.0，torch 2.9.1+cpu，transformers 5.19.0，onnx 1.18.0，onnxruntime 1.26.0，numpy 2.5.4 |

`config.json` 必须有 `vision_config.spatial_merge_size = 1`。入口脚本会检查，
缺少或不一致时停止，避免错误的视觉 token 配置进入转换。

可通过环境变量指定路径：

| 变量 | 默认值/用途 |
|---|---|
| `RKLLM_CONVERT_ROOT` | `/data/rkllm-convert`，模型、环境和 runs 的默认根目录 |
| `RKLLM_MODEL` | 根目录下的 `model47` |
| `RKLLM_TEXT_PY` | 根目录下的 `venv/bin/python` |
| `RKLLM_VISION_PY` | 根目录下的 `venv-vision/bin/python` |
| `RKLLM_RUN_ID` | UTC 时间戳，仅使用简单目录名 |

## 流程及校验

1. `make_calib.py`：生成 25 条带 `input` 和 `target` 的校准记录。
2. `convert.py`：RKLLM W8A8，RK3588，3 个 NPU 核心，4096 context。
3. `export_vision_m47_folds.py`：eager attention，将 attention scale 折叠进
   `q_proj`，导出 opset 17 ONNX，再合并 external data。与官方 PyTorch 输出
   比较，并执行 ONNX Runtime 误差校验。
4. `rknn_convert_m47.py`：构建 FP16 RKNN，在 x86 模拟器中与 golden 比较，
   要求形状一致、输出有限、最大绝对误差小于 golden 峰值的 2%。
5. 入口检查关键文件非空，golden 形状为 `(1, 324, 1024)`，输出 manifest。
   全部成功才打印 `CONVERSION_OK`。

ONNX 的 golden 输入已按 `(pixels - 127.5) / 127.5` 归一化。RKNN 模拟器输入
使用 0–255 范围的浮点像素，转换配置会自动进行相同归一化。两者不能直接复用
同一个已归一化数组，否则会归一化两次，使误差检查失真。

部署时使用 `minicpmv47_1b_w8a8.rkllm` 和 `vision_m47_fp16.rknn`；RKNN 图像
输入为 1008×1008，RKLLM 图像画布为 252×252，视觉 token 数为 324。

2026-10-15 已在 66 的全新输出目录 `runs/20261015-131943/` 完整实跑通过，
北京时间 21:19:43 开始、21:37:04 完成，耗时约 17 分 21 秒。模拟器最大绝对
误差为 `0.0465`，占 golden 峰值的 `1.711%`；文本和视觉产物分别为
1,299,631,892 字节和 1,546,439,108 字节。

详细故障记录和板端 token 测试见
[64 号记录](../../docs/64-npu-multimodal-minicpmv47-fix-20261015.md)。

## 35B-A3B 独立实验

`prepare_35ba3b_les.sh` 与 `bench_35ba3b.py` 用于官方混合量化 GGUF 的 CPU/LES
板端测试，与上面的 1B RKLLM 转换流程分别使用。硬件、具体模型、编译补丁、
命令和实测结果见 [65 号记录](../../docs/65-minicpmv47-35ba3b-rk3588-20261015.md)。
