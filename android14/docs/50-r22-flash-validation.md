# r22 刷后验证记录

日期：2026-08-27  
设备：MB0002 V2  ��� ADB `154c3268c6cdee4e`

## 启动与内核

- `sys.boot_completed=1`
- `sys.boot.reason=reboot,factory_reset`
- Linux `6.1.99 #13 SMP PREEMPT Thu Aug 27 00:47:53 CST 2026 aarch64`
- 设备保持在线，未发生自动重启。

## 蓝牙 proc 安全性

执行：

```text
cat /proc/bluetooth/sleep/btwrite
cat /proc/bluetooth/sleep/lpm
```

结果：两个节点均返回 `Permission denied`，没有触发 kernel panic；`/sys/fs/pstore` 未出现本轮新增的崩溃记录。普通 shell 用户没有读取权限，因此暂不能验证 root 读取时的 `unsupported to read` 文本。

## 蓝牙服务

通过 `svc bluetooth enable` 启用成功：

- 状态：`ON`
- 地址：`B0:02:47:43:EA:3B`
- 名称：`MB0002 V2`
- `Bluetooth crashed 0 times`
- A2dp、Avrcp、Headset、HidHost、Gatt、Pan 等 profile 已启动
- BREDR 和 BLE 状态机均完成启动

本轮未进行配对和音频连接，避免把外部设备因素混入内核验证。

## 网络与硬件枚举

- `eth1` 已连接，地址 `192.168.88.188/24`
- `wlan0` 已枚举，当前为 DOWN（扫描命令被 Android shell 权限拒绝）
- HDMI 声卡 `rockchiphdmi0` 已枚举
- 摄像头服务发现 1 个外部设备，Camera ID `100`
- `/data` 可用约 227 GB
- 屏幕息屏超时 `1800000 ms`（30 分钟）

## 待现场确认

1. 使用系统设置执行 Wi‑Fi 扫描并连接 `cc181003`，确认 DHCP 和联网。
2. 使用系统蓝牙界面扫描附近经典蓝牙设备及 BLE 设备，确认发现列表。
3. 打开相机完成预览和拍照，检查新 JPEG 是否写入 MediaStore。
4. 播放媒体后确认音频输出设备为 HDMI。

