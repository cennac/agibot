#!/usr/bin/env python
# 刷机后串口监工:持续抓 COM5 @1500000,把输出写文件并打印关键里程碑。
# 用法: python _boot_watch.py [持续秒数,默认600]
import serial, time, sys

DUR = float(sys.argv[1]) if len(sys.argv) > 1 else 600
LOG = r"E:\AIPorject\101\agibot-armbian\_boot_watch.log"
MILESTONES = [
    b"U-Boot 2017.09",          # U-Boot banner (v1 应回归)
    b"Model: AGIBOT",           # 板型
    b"Hit key",                 # autoboot 提示
    b"Starting kernel",         # 转内核
    b"armbian login",           # 登录提示
    b"download key pressed",    # (不应出现!)
    b"entering download",       # (不应出现!)
]
seen = set()
buf_total = bytearray()

try:
    s = serial.Serial("COM5", 1500000, timeout=0.2)
except Exception as e:
    print(f"[!] COM5 打不开: {e}"); sys.exit(1)

print(f">>> 监工开始 {DUR}s, 日志 -> {LOG}")
t0 = time.time()
with open(LOG, "wb") as lf:
    while time.time() - t0 < DUR:
        d = s.read(8192)
        if d:
            buf_total += d
            lf.write(d); lf.flush()
            for kw in MILESTONES:
                if kw in d and kw not in seen:
                    seen.add(kw)
                    print(f"[t={time.time()-t0:.1f}] ★ {kw.decode()}")
s.close()
print(f">>> 结束, 共 {len(buf_total)} 字节")
if b"armbian login" in bytes(buf_total):
    print("★★★ 启动成功: 已到 login 提示 ★★★")
elif b"Starting kernel" in bytes(buf_total):
    print("★ 内核已启动(未见 login,看日志)")
elif b"U-Boot 2017.09" in bytes(buf_total):
    print("★ U-Boot banner 出现(未进内核?)")
else:
    print("✗ 无 U-Boot banner —— 仍异常")
