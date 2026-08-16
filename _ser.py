#!/usr/bin/env python
# 串口助手:python _ser.py "<命令>" [捕获秒数,默认4] [端口,默认COM7]
# 1500000 8N1,发命令后抓 N 秒输出。
import serial, sys, time

cmd = sys.argv[1] if len(sys.argv) > 1 else ""
wait = float(sys.argv[2]) if len(sys.argv) > 2 else 4.0
port = sys.argv[3] if len(sys.argv) > 3 else "COM7"

try:
    s = serial.Serial(port, 1500000, timeout=0.1)
except Exception as e:
    print(f"[!] 打不开 {port}: {e}")
    print(f"    -> 串口助手可能还占着 {port},先关掉它。")
    sys.exit(1)

time.sleep(0.15)
s.reset_input_buffer()
if cmd:
    s.write((cmd + "\n").encode())
    s.flush()
end = time.time() + wait
buf = bytearray()
while time.time() < end:
    data = s.read(4096)
    if data:
        buf += data
s.close()
try:
    sys.stdout.buffer.write(buf)
    sys.stdout.flush()
except Exception:
    print(buf.decode("utf-8", "replace"))
