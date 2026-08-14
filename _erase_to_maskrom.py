#!/usr/bin/env python
# 抓 U-Boot 提示符 -> mmc erase idbloader -> reset 进 Maskrom。
import serial, sys, time
try:
    s = serial.Serial("COM5", 1500000, timeout=0.15)
except Exception as e:
    print(f"[!] 打不开 COM5: {e}"); sys.exit(1)
print(">>> 抓 U-Boot(Ctrl+C 40s),请断电再上电板子...")
deadline = time.time() + 40; buf = bytearray(); stopped = False
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
