# r22 经典蓝牙问题诊断

日期：2026-08-27

## 结论

> 更新：本节中“Windows 端也没有发现 MB0002 V2”的原始判断已被
> `docs/52-r22-bluetooth-deep-analysis.md` 和
> `docs/53-r22-independent-ubuntu-peer-validation.md` 修正。Windows 实时
> Inquiry 能看到板卡地址 `B0:02:47:43:EA:3B`，但名称和 Class of Device
> 为空；Ubuntu 也能与 Windows 建立 Classic 连接，因此 Windows 不是
> MB0002 Classic 失败的根本原因。

r22 的 Android Bluetooth HAL、适配器初始化和 BLE 路径正常，但 BR/EDR
经典蓝牙发现仍未打通。适配器可稳定进入 `STATE_ON`，不过 framework 当前
显示 `Discovering: false`，Windows 端也没有发现 `MB0002 V2`。

## 已排除项

- Bluetooth 服务未启动：排除，A2DP、HID、GATT 等 profile 均已启动。
- 服务崩溃：排除，`Bluetooth crashed 0 times`。
- proc 节点读取导致 panic：r22 已修复，普通 shell 读取仅返回权限拒绝。
- 单纯 Android 扫描窗口配置：r18 的宽窗口和 r16 默认值均已验证，均无 Classic Inquiry 结果。
- 单纯 HCD 文件版本：r16 原始 HCD、AP6275P 59,061-byte 固件及 0034.0041 固件均已验证，均未恢复 BR/EDR。

## 下一步修复方向

问题应继续在 AP6275P 控制器固件/初始化时序、UART6 RTS/BT_WAKE 电气链路
和真实 HCI event 抓包层处理，而不是继续调整 Settings 或 framework 参数。
下一版应在 UART6 上抓取 `Inquiry Command Complete`、`Inquiry Result`
和 `Command Status`，并与原厂 Android 镜像逐字节对比；只有确认控制器实际
返回 Classic Inquiry Result 后，才进入 Windows 配对验证。

## 当前版本处理

本轮不生成无依据的 framework 补丁，也不刷写设备。r22 保持为当前稳定基线，
避免再次引入已修复的内核崩溃。
