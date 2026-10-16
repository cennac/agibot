# MiniCPM-V 4.7-1B RKLLM 带图推理故障修复记录

日期：2026-10-15（Asia/Shanghai）

## 问题

RK3588 板端已经可以加载 MiniCPM-V 4.7-1B 的 RKLLM 文本模型和 RKNN
视觉模型，但执行带图请求时出现两类问题：

1. 图像描述内容明显错误，视觉特征疑似损坏。
2. 将图像尺寸按视觉 token 尺寸处理后，RKLLM 报错：

   ```text
   For image input, patch_h * patch_w should be equal to n_image_tokens,
   but got patch_h[72] * patch_w[72] != n_image_tokens[324]!
   ```

## 根因

MiniCPM-V 4.7-1B 的 RKNN 视觉输入张量为：

```text
[1, 1008, 1008, 3], FP16
```

视觉塔内部的下采样和 merger 才会把特征变成 324 个图像 token。原代码把
输入图像直接缩放为 `1008 / 4 = 252`，导致 RKNN 读取错误大小的图像缓冲区，
产生无效 embedding。

同时，RKLLM API 的 `image_width` 和 `image_height` 表示下采样后的 patch
画布，而不是 RKNN 输入像素尺寸。对本模型必须传 `252×252`，这样运行时得到
`18×18 = 324` 个 patch，与视觉 embedding 数量一致。

## 之前转换失败的原因

转换阶段的失败和板端带图推理失败是两件不同的事：

1. 文本 RKLLM 实际已经能够导出；`rkllm-toolkit 1.3.1` 要求校准集每条记录
   同时包含 `input` 和 `target`。整理一键流程时误用仅生成 `input` 的旧脚本，
   实跑报 `the dataset format is incorrect`；已改为生成正确的二字段 JSON。
2. 视觉模型直接导出时权重被拆成 ONNX external tensors，初版合并文件会出现
   `Cannot parse data from external tensors` 或 `INVALID_PROTOBUF`。
3. 即使 external data 修好，66 上的 `rknn-toolkit2 2.5.0` 在 attention 的
   `MatMul + Add/Mul + Softmax + MatMul` 融合规则中处理一维 scale 常量会触发
   `TypeError: only 0-dimensional arrays can be converted to Python scalars`。

当前视觉流程先把 attention scale 精确折叠进 `q_proj`，再导出和打包 ONNX，
最后交给 RKNN 2.5.0。折叠后的 PyTorch 对照最大误差约 `7e-6`，ONNX Runtime
对照相对误差约 `4e-6`。

## 修复

文件：

```text
_tmp/rkllm/mm_demo_example/deploy/src/main.cpp
```

修复后的尺寸关系：

```text
RKNN 输入 resize：1008×1008
RKLLM image_width：252
RKLLM image_height：252
视觉 token：324
```

并增加了图像读取失败检查，避免空图像进入 `cvtColor` 和 RKNN 推理。

## 板端验证

板端：`agibot`（192.168.88.89）

重新编译：

```bash
cd /root/rkllm/mm_deploy/build
cmake --build . --target demo -j4
```

带图运行：

```bash
cd /root/rkllm/mm_deploy/build
export LD_LIBRARY_PATH=/root/rkllm:/root/rkllm/mm_deploy/build:$LD_LIBRARY_PATH
printf '<image>这张图片中有什么？\nexit\n' | ./demo \
  /root/rkllm/mm_demo_example/data/demo.jpg \
  /root/rkllm/vision_m47_fp16.rknn '' '' \
  /root/rkllm/minicpmv47_1b_w8a8.rkllm 96 4096 3 rk3588 \
  '<|vision_start|>' '<|vision_end|>' '<|image_pad|>'
```

验证结果：

- RKNN 视觉编码完成，耗时约 23.4 秒（三个 NPU 核心）。
- RKLLM 不再报 patch 数量错误。
- 模型正确识别出宇航员、月球场景和绿色瓶装饮料。
- 独立 `imgenc` 测试生成 `img_vec.bin`，大小为 1,327,104 字节。
- 测试结束后无残留 `demo` 或 `imgenc` 进程。

## 66 一键转换

现在可以在 66 上一次串联完成文本和视觉转换。脚本位于
`/data/rkllm-convert/one-shot/convert_multimodal_once_66.sh`，每次使用独立运行目录，
不会覆盖已有成功产物：

```bash
bash /data/rkllm-convert/one-shot/convert_multimodal_once_66.sh
```

每次运行依次执行：生成校准集、导出 `minicpmv47_1b_w8a8.rkllm`、折叠 attention
并导出视觉 ONNX、转换 `vision_m47_fp16.rknn`，最后检查文件大小和
`(1, 324, 1024)` 的视觉 golden 输出。成功时日志末尾会打印：

```text
CONVERSION_OK /data/rkllm-convert/runs/<UTC时间戳>
```

本次实跑使用 Python 3.12、`rkllm-toolkit 1.3.1`、`rknn-toolkit2 2.5.0`。

可复用脚本已保存到项目级目录
[`tools/rkllm`](../tools/rkllm/README.md)，完整环境版本和路径参数见该目录的 README。

数值校验需要注意：ONNX golden 输入已经归一化；RKNN 配置含 mean/std，会自动
执行归一化，所以模拟器必须接收还原后的 0–255 像素。初版模拟器检查直接复用
已归一化数组，错误地得到相对峰值误差 `0.36133`，这个数值不代表转换精度。
修正后增加了输出形状、有限值和相对峰值误差小于 2% 的断言，超限则停止流程。

### 完整实跑验收

2026-10-15 在 66 的独立目录
`/data/rkllm-convert/runs/20261015-131943/` 从头运行入口命令，中途无需人工修改。
文本、ONNX、RKNN 和模拟器检查全部完成，日志末尾为：

```text
load ret: 0
build ret: 0
export ret: 0
folded-vs-official max abs diff: 0.000007  shape: (1, 324, 1024)
ort-vs-torch max abs diff: 0.000012 (rel 0.000004)
build: 0
export_rknn: 0
simulator-vs-golden: max_abs=0.0465 rel=0.01711 shape=(1, 324, 1024)
SIM_CHECK_DONE
CONVERSION_OK /data/rkllm-convert/runs/20261015-131943
```

| 部署产物 | 字节数 |
|---|---:|
| `minicpmv47_1b_w8a8.rkllm` | 1,299,631,892 |
| `vision_m47_fp16.rknn` | 1,546,439,108 |

模拟器误差 `0.01711` 的定义是最大绝对误差除以 golden 输出的最大绝对值，
约为峰值的 1.71%，低于 2% 验收阈值。本次数值检查使用固定随机种子的一组
输入，属于转换正确性检查；本次新产物尚未替换板端已验证的部署文件。

原始完整日志和产物记录已归档：

- [转换日志（gzip）](../artifacts/rkllm-convert66-20261015.log.gz)
- [产物 manifest](../artifacts/rkllm-convert66-20261015.manifest.txt)
- [产物 SHA-256 与完成时间](../artifacts/rkllm-convert66-20261015.sha256.txt)

## Token 数与速度测试

为避免把 UTF-8 文本块误当成 token，`_tmp/rkllm/llm_bench.cpp` 已改为优先
读取 `RKLLMResult.perf.generate_tokens`。回调次数可能比该值多 1，这是结束
token 的回调，不作为生成 token 数使用。

| 场景 | prefill tokens | generate tokens | 生成耗时 | 生成速度 |
|---|---:|---:|---:|---:|
| 纯文本，`用一句话介绍你自己` | 16 | 25 | 0.99 s | 25.3 tok/s |
| 纯文本，能源类型及优缺点，max 300 | 20 | 299 | 12.11 s | 24.7 tok/s |
| 带图，一句话描述图片 | 343 | 18 | 0.85 s | 21.2 tok/s |

带图请求另外耗时约 23.3 s 完成视觉编码；该时间不计入上表的 RKLLM
生成速度。短文本端到端耗时约 1.36 s，实际生成 token 数为 25。

## 相关记录

- [NPU RKLLM 基准与部署说明](./63-npu-rkllm-minicpmv47-1b-20261015.md)
- [MiniCPM-V CPU 带图基准](./61-minicpmv-llm-bench-20261015.md)
- [MiniCPM-V 66ops 质量测试](./62-66ops-quality-suite-minicpmv47-1b-20261015.md)
