#!/usr/bin/env python3
# 持续发 Ctrl+C 抓 U-Boot，同时完整记录冷启动串口；抓到 => 后退出并释放 COM5。
import serial, time, sys

DUR = float(sys.argv[1]) if len(sys.argv) > 1 else 1800
PORT = sys.argv[2] if len(sys.argv) > 2 else "COM5"
LOG = r"E:\AIPorject\101\agibot-armbian\_catch_uboot.log"
s = serial.Serial(PORT, 1500000, timeout=0.08)
s.reset_input_buffer()
print(f">>> 等待板子复位，持续抓 U-Boot {DUR}s；日志 {LOG}")
end = time.time() + DUR
buf = bytearray()
with open(LOG, "wb") as f:
    while time.time() < end:
        s.write(b"\x03")
        time.sleep(0.08)
        d = s.read(8192)
        if d:
            buf += d
            f.write(d); f.flush()
            sys.stdout.buffer.write(d); sys.stdout.flush()
            if b"=>" in buf[-800:]:
                print("\n>>> 已抓到 U-Boot 提示符，COM5 已释放")
                break
s.close()
print(f">>> 捕获 {len(buf)} 字节")
