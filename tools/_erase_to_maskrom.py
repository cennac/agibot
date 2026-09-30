#!/usr/bin/env python
# 抓 U-Boot 提示符 -> mmc erase idbloader -> reset 进 Maskrom。
import serial, sys, time

port = sys.argv[1] if len(sys.argv) > 1 else "COM5"
timeout = float(sys.argv[2]) if len(sys.argv) > 2 else 60
reboot_first = len(sys.argv) > 3 and sys.argv[3] == "reboot"
try:
	s = serial.Serial(port, 1500000, timeout=0.15)
except Exception as e:
	print(f"[!] 打不开 {port}: {e}"); sys.exit(1)
if reboot_first:
	print(">>> 通过串口 SysRq 强制重启(BREAK + b)...")
	s.send_break(0.3)
	time.sleep(0.2)
	s.write(b"b")
	s.flush()
	time.sleep(0.5)
print(f">>> 通过 {port} 抓 U-Boot(Ctrl+C {timeout:g}s),请断电再上电板子...")
deadline = time.time() + timeout; buf = bytearray(); stopped = False
while time.time() < deadline:
    s.write(b"\x03"); time.sleep(0.15)
    data = s.read(4096)
    if data:
        buf += data
        try: sys.stdout.buffer.write(data); sys.stdout.flush()
        except: pass
        if b"=>" in bytes(buf[-300:]):
            stopped = True; break
if not stopped:
    print("\n[!] 没抓到 => (板子可能已在 Maskrom,静默)"); s.close(); sys.exit(1)

print("\n>>> 抓到 U-Boot!擦 idbloader(16MB=0x8000 扇区)+ reset")
time.sleep(0.4); s.reset_input_buffer()
for c in ["mmc dev 0", "mmc erase 0 0x8000", "reset"]:
    s.write((c + "\n").encode()); s.flush()
    time.sleep(1.5)
    data = s.read(8192)
    if data:
        try: sys.stdout.buffer.write(data); sys.stdout.flush()
        except: print(data.decode("utf-8","replace"))
s.close()
print("\n>>> 已发 reset,板子应进 Maskrom(静默)。开 RKDevTool 应显示 MASKROM。")
