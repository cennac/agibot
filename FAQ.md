# FAQ — 板子常见操作问答

按场景找答案。每条给出最快路径 + 详细的坑。刷机总方案见 [flash/README.md](flash/README.md),
Linux bring-up 见 [ARMBIAN-LINUX-BRINGUP.md](ARMBIAN-LINUX-BRINGUP.md)。

## 目录

- [Q1 板子怎么进 Maskrom?(最稳刷机模式)](#q1)
- [Q2 板子怎么进 Loader?](#q2)
- [Q3 Maskrom 和 Loader 有什么区别?该用哪个?](#q3)
- [Q4 刷机完整步骤是什么?](#q4)
- [Q5 RKDevTool 报「下载 boot 失败 / Loading firmware err=-5」?](#q5)
- [Q6 串口(COM5)没输出?](#q6)
- [Q7 板上的按键都是干嘛的?](#q7)
- [Q8 怎么判断板子是软重启还是硬复位?](#q8)
- [Q9 怎么安全地监控/测试 GPIO 和按键?](#q9)
- [Q10 NPU 怎么测试?](#q10)
- [Q11 板子 SSH 怎么连?](#q11)

---

<a name="q1"></a>
## Q1 板子怎么进 Maskrom?(最稳刷机模式)

进 Maskrom 的本质是**让 BROM 读不到 idbloader**(擦掉 eMMC 头部即可)。按手头条件选:

### 方法 A:能 SSH 进系统(最快,推荐)

```sh
ssh root@192.168.88.89        # 密码 1234(当前 DHCP 分配的 IP)
# 擦前 16MiB = idbloader(32KB 起)+ u-boot(8MB 起);rootfs 在 LBA 32768 起,不受影响
dd if=/dev/zero of=/dev/mmcblk0 bs=512 count=32768 conv=fsync
sync
reboot -f
```

⚠️ **坑(2026-08-14 实测)**:用 paramiko `exec_command("reboot -f")` 发命令,SSH channel
关闭会把 reboot 杀掉,**板子实际没重启**(uptime 连续、ping 一直通)。必须后台化:

```python
c.exec_command("(sleep 1; reboot -f) >/dev/null 2>&1 &")
```

或交互 shell 里直接敲 `reboot -f`(没问题,只有「发完立刻断 channel」的自动化才中招)。

验证:ping 不通(Maskrom 无网络栈)+ 串口完全静默 + RKDevTool 显示 **MASKROM**。

### 方法 B:板子停在 U-Boot(有串口)

```sh
python _ser.py "mmc dev 0" 3        # COM5 @ 1500000
python _ser.py "mmc erase 0 0x8000" 5
python _ser.py "reset" 3
```

或直接用现成脚本 `python _erase_to_maskrom.py`(自动抓 U-Boot 提示符 → 擦 → reset)。

### 方法 C:U-Boot 命令直接进(不擦片)

- OpenWrt 版 U-Boot:`Hit any key` 按任意键 → `rockusb 0 mmc 0`
- Armbian vendor U-Boot:`CTRL+C` 打断 → `download`

⚠️ 这进的是 **LOADER**(U-Boot 模拟),不是真 Maskrom,刷机兼容性差,见 Q3。

<a name="q2"></a>
## Q2 板子怎么进 Loader?

- **串口**:上电时按提示打断(U-Boot `Hit key('CTRL+C')` 时发 0x03),再 `download`
- **SW9200 按键**(2026-08-14 实测可用):断电后**按住 SW9200 再上电**,保持到 RKDevTool
  显示「LOADER 设备」即可松手。**检测者是 idbloader 里的 rkbin miniloader**(闭源件,
  USB 枚举 PID 0x350B),不依赖任何 U-Boot 补丁——别再往 U-Boot DTS 加 adc-keys:
  实测该节点会让 U-Boot proper 在 console 初始化前挂死(BL31 后串口全静默),
  2026-08-14 已回退(镜像 SHA `2dc05ed4...`)。

<a name="q3"></a>
## Q3 Maskrom 和 Loader 有什么区别?该用哪个?

| | 真 Maskrom(BROM) | LOADER(U-Boot 模拟) |
|---|---|---|
| 进入方式 | 擦掉 idbloader 后上电(Q1 A/B) | U-Boot `rockusb`/`download`(Q1 C) |
| RKDevTool 显示 | MASKROM | LOADER |
| 标准刷机流程(Loader@0xCC + image@0) | ✅ 兼容 | ❌ 报「读取 flash 信息失败」 |
| 救砖 | ✅ 只要 BROM 活着就行 | ❌ 依赖 U-Boot 能启动 |

**结论:刷机一律用真 Maskrom。** LOADER 模式要刷,用两步式:
①「高级功能 → 下载 Boot」单独下 loader;②「下载镜像」只留 image@0x0。

<a name="q4"></a>
## Q4 刷机完整步骤是什么?

1. 进 Maskrom(见 Q1,推荐方法 A)
2. RKDevTool「下载镜像」页加两项:
   - **Loader** `@0xCCCCCCCC` → `flash/rk3588_spl_loader_v1.16.113.bin`
   - **image** `@0x00000000` → 整盘 `.img`(armbian 或 openwrt,等同 dd,不必拆分)
3. 「执行」,等进度走完,板子自动重启进新系统
4. 板端回归测试:`flash/postflash-test.sh`

使用 `python flash/gen-armbian-cfg.py --img <新镜像>` 的拆分方式时，每次都会重新生成
`armbian-head.img` 和 `armbian-rootfs.img`。不要手工复用旧拆分件：不同构建的整盘镜像
经常大小完全相同，仅按大小判断会把旧 U-Boot 再次刷回板子。

详见 [flash/README.md](flash/README.md)。

<a name="q5"></a>
## Q5 RKDevTool 报「下载 boot 失败 / Loading firmware err=-5」?

**九成是 loader 型号错了**,不是 USB 线问题(历史误判,见记忆)。
`cfg_build\MiniLoaderAll.bin`(160078 字节)是 **RK356x** loader;RKDevTool 自带的也常错。
必须用 `flash/rk3588_spl_loader_v1.16.113.bin`(487872 字节)。
RKDevTool v3.37 比 v2.86 稳。raw img 别走「升级固件」页(要 RKFW/RKAF 包),走「下载镜像」页。

<a name="q6"></a>
## Q6 串口(COM5)没输出?

- 波特率必须 **1500000** 8N1(不是 115200)
- 系统跑起来后控制台是 **ttyFIQ0**(fiq-debugger 独占 uart2),不是 ttyS2——这是正常状态,别改 DTB
- Maskrom 下串口**完全静默是正常的**(BROM 不说话)
- 工具:`python _ser.py "命令" [捕获秒数]`(仓库根,pyserial)

<a name="q7"></a>
## Q7 板上的按键都是干嘛的?

2026-08-14 实测(armbian 上逐键验证):

| 按键 | 行为 | 接线 |
|---|---|---|
| **SW9200** | 上电长按进 loader(U-Boot adc-keys 检测) | SARADC **ch1** → `adc-keys`(Linux input1) |
| **SW9201** | **硬复位**(瞬时断电重启,无软件日志) | 硬件复位线 |
| **SW9202** | **关机**(systemd 关停 + BL31 virtual poweroff) | PMIC PWRON → `rk805 pwrkey`(input2) |
| **SW8900** | **重启**(轻触即重启) | 复位/重启线 |
| **SW8901** | 无重启、无 ADC 事件、不在 I2C 扩展器 | 无 Linux 可见功能(疑空焊/占位) |
| **SW8902** | 不重启;无干净 ADC 事件 | 未知 |

Linux 只注册 3 个输入键:bt-powerkey、adc-keys(SW9200)、rk805-pwrkey(SW9202)。

<a name="q8"></a>
## Q8 怎么判断板子是软重启还是硬复位?

- **软重启/关机**:有 systemd 关停序列日志 + BL31 `virtual poweroff` 日志
- **硬复位(SW9201/SW8900)**:无任何软件日志、瞬时断电重启
- 板上 armbian `/var/log` 在 zram、journald 不持久化 → 重启后啥都看不到,
  要**先**起磁盘 trace 监控(append + sync 到 /root/*.txt)再触发

<a name="q9"></a>
## Q9 怎么安全地监控/测试 GPIO 和按键?

✅ **只准用只读手段**:
- SARADC:`cat /sys/bus/iio/devices/iio:device0/in_voltageN_raw`(N=0..7;
  现成工具 `_adc_mon.py`,8 通道只读监控)
- GPIO 状态:读 `/sys/kernel/debug/gpio`

❌ **禁止 gpioget 扫 SoC GPIO 芯片(gpiochip0-4)**:会把未被驱动 claimed 的关键输出脚
(电源使能/复位控制)临时改成输入,方向翻转产生毛刺,**板子直接崩/重启**。
2026-08-14 两次实测崩板(且曾因此把「SW8902 会重启」归因错——是扫描崩的,不是按键)。

SARADC 通道底噪(空载参考):干净通道 ch0≈4080、ch3≈2748、ch5≈375;
**ch6/ch7 是 ~10Hz 高速振荡的噪声/浮空通道**,别拿它们判断按键;
ch2/ch4 有缓慢漂移。SW9200 按下时 ch1 从 ~4090 掉到 ~39。

<a name="q10"></a>
## Q10 NPU 怎么测试?

- rknpu 驱动是 **DRM 形态**(节点 `/dev/dri/renderD128`,不是旧 misc `/dev/rknpu`——没有后者不是故障)
- 用户态:`flash/npu_test.py`(RKNNLite + resnet18,三核 init_runtime)
- 2026-08-14 实测:124.7 FPS(armbian vendor 6.1 + librknnrt v1.5.2)
- 坑:armbian minimal 无 pip3,先 `apt-get install -y python3-pip`;
  pip 走清华源 `-i https://pypi.tuna.tsinghua.edu.cn/simple`

<a name="q11"></a>
## Q11 板子 SSH 怎么连?

- 当前 armbian:`root` / `1234`,IP 看 DHCP(2026-08-14 是 192.168.88.89)
- 旧原厂系统(已不在):192.168.88.101,root/tyzc,另有 adb:5555 root shell
- Python paramiko 注意:Windows 控制台 GBK,要 `python -X utf8` +
  `sys.stdout.reconfigure(encoding="utf-8", errors="replace")`,否则 print 中文/box 字符崩溃
  会 SIGPIPE 断掉板端 tee;循环重开 exec_command 会连接抖动,长任务用单 exec_command 板端循环
