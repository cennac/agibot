#!/usr/bin/env python
# HDMI 分阶段测试启动器:reboot → COM6 打断 U-Boot → 测试 DTB 启动 → 串口里程碑。
# 用法: python _hdmi_testboot.py <测试dtb路径> [捕获秒数=75]
import serial, time, sys, threading
import paramiko

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
TEST_DTB_BOARD = sys.argv[1] if len(sys.argv) > 1 else "/boot/dtb-6.1.115-vendor-rk35xx/rockchip/rk3588-agibot-test.dtb"
CAPTURE = float(sys.argv[2]) if len(sys.argv) > 2 else 75
LOG = r"E:\AIPorject\101\agibot-armbian\_hdmi_testboot.log"

MILESTONES = [b"U-Boot 2017", b"=>", b"Starting kernel",
              b"hdptx", b"hdmiphy", b"failed to register clock",
              b"rockchip-drm", b"display-subsystem", b"hdmi0_phy_pll",
              b"drm", b"login:", b"Kernel panic", b"not syncing"]

# 1) SSH 重启
c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("192.168.88.88", username="root", password="1234", timeout=10)
c.exec_command("(sleep 1; reboot) >/dev/null 2>&1 &", timeout=5)
c.close()
print(">>> reboot 已发,等待 U-Boot 窗口...")

# 2) 打开 COM6,spam Ctrl+C 直到抓到 => (最长 45s)
s = serial.Serial("COM6", 1500000, timeout=0.05)
s.reset_input_buffer()
buf = bytearray()
deadline = time.time() + 45
prompt = False
while time.time() < deadline and not prompt:
    s.write(b"\x03")
    d = s.read(4096)
    if d:
        buf += d
        if b"=>" in bytes(buf[-400:]):
            prompt = True
if not prompt:
    s.close()
    print(f"!!! 未抓到 U-Boot 提示符(捕获 {len(buf)}B)。板子可能已按默认 DTB 正常启动,")
    print("    或需要人工 SSCOM HEX 03 打断后重跑本脚本第二段。日志前 300B:")
    print(bytes(buf[:300]))
    sys.exit(2)
print(f">>> 抓到 U-Boot 提示符(t={45-(deadline-time.time()):.1f}s 剩余)")

# 3) 执行测试启动
def cmd(c_, wait):
    s.write((c_ + "\n").encode()); s.flush(); time.sleep(wait)
cmd("mmc dev 0", 1.5)
cmd("ext4load mmc 0:1 ${ramdisk_addr_r} /boot/uInitrd-6.1.115-vendor-rk35xx", 3)
cmd("ext4load mmc 0:1 ${kernel_addr_r} /boot/vmlinuz-6.1.115-vendor-rk35xx", 4)
cmd(f"ext4load mmc 0:1 ${{fdt_addr_r}} {TEST_DTB_BOARD}", 2)
cmd("fdt addr ${fdt_addr_r}", 1)
print(">>> booti(测试 DTB)...")
s.write(b"booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}\n"); s.flush()

# 4) 捕获串口
seen = set()
end = time.time() + CAPTURE
while time.time() < end:
    d = s.read(8192)
    if d:
        buf += d
        for kw in MILESTONES:
            if kw in d and kw not in seen:
                seen.add(kw)
                print(f"[t={CAPTURE-(end-time.time()):.0f}s] * {kw.decode(errors='replace')}")
    if b"login:" in bytes(buf) or b"Kernel panic" in bytes(buf):
        break
s.close()
open(LOG, "wb").write(bytes(buf))
print(f">>> 捕获 {len(buf)}B -> {LOG}")
