#!/usr/bin/env python3
# 只读 SARADC 8 通道监控(不碰任何 GPIO,安全),只在变化时打印。
import time, os
base = "/sys/bus/iio/devices/iio:device0"

def read_adc():
    out = {}
    for ch in range(8):
        try:
            with open(f"{base}/in_voltage{ch}_raw") as f:
                out[ch] = int(f.read())
        except Exception:
            out[ch] = None
    return out

t0 = time.time()
DUR = float(os.environ.get("DUR", "30"))
base_a = None
while time.time() - t0 < DUR:
    a = read_adc()
    if base_a is None:
        base_a = a
        print(f"[t=0.0] ADC baseline: {a}")
    elif a != base_a:
        chg = [f"ch{c}:{base_a[c]}->{a[c]}" for c in a if base_a[c] != a[c]]
        print(f"[t={time.time()-t0:.1f}] ADC CHANGE: {', '.join(chg)}")
        base_a = a
    time.sleep(0.05)
print("DONE")
