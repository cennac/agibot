import json
import os

texts = [
    "大家好，今天我们来聊一聊人工智能技术在日常生活中的应用。",
    "Artificial intelligence has rapidly become part of everyday software.",
    "机器人操作系统需要同时处理感知、规划与控制三个层面的任务。",
    "The weather today is sunny with a light breeze from the southeast.",
    "嵌入式设备的资源有限，因此模型量化成为在端侧部署大模型的关键技术。",
    "请问如何使用C语言实现一个简单的链表结构并进行遍历操作？",
    "The quick brown fox jumps over the lazy dog while the cat sleeps.",
    "在做系统设计时，需要权衡性能、可维护性与开发成本之间的关系。",
    "机器学习模型的训练需要大量数据、合适的损失函数以及优化方法。",
    "Linux系统管理员经常使用命令行工具来查看日志和分析系统状态。",
    "ARM架构的处理器因为功耗低、生态完善而被广泛应用于移动设备。",
    "自然语言处理技术让计算机能够理解并生成人类的语言文字。",
    "深度学习框架提供了自动微分功能，大大简化了模型开发流程。",
    "在部署边缘计算方案时，延迟、带宽与隐私是最重要的考虑因素。",
    "The robot navigated through the warehouse avoiding all obstacles.",
    "操作系统内核负责管理硬件资源，并为应用程序提供运行环境。",
    "量化后的模型体积更小、推理更快，但可能带来一定精度损失。",
    "数据结构与算法是计算机科学的基础，值得反复练习与思考。",
    "现代编译器能够自动进行指令调度和寄存器分配等底层优化。",
    "The meeting is scheduled for three o'clock in the afternoon.",
    "大语言模型的推理过程分为预填充与解码两个阶段，各有不同的性能瓶颈。",
    "函数式编程强调纯函数与不可变数据，减少了程序中的副作用。",
    "The NPU accelerator executes quantized integer operations in parallel.",
    "计算机网络中的TCP协议通过确认与重传机制保证数据可靠传输。",
    "语义分割任务需要为图像中的每一个像素预测其所属的类别标签。",
]
out = os.environ.get("RKLLM_CALIB", "/data/rkllm-convert/calib.json")
with open(out, "w", encoding="utf-8") as f:
    # rkllm-toolkit 1.3.1 validates both fields.  The target is only used as
    # the calibration response, so a short stable response is sufficient.
    json.dump([{"input": t, "target": "好的。"} for t in texts],
              f, ensure_ascii=False, indent=1)
print("CALIB_JSON_DONE", len(texts))
