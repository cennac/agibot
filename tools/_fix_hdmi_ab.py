#!/usr/bin/env python3
# HDMI clk-port 迁移(5.10->6.1):从稳定 v3 DTB 生成 stage A+B 测试 DTB。
# 改动 5 处:两个 hdmiphy 删 clk-port 子节点+补节点级 clock provider;
# display-subsystem 删 hdmi0/1_phy_pll 旧引用;两个 hdmi 控制器的 link_clk
# 由 clk-port phandle 改指向 hdmiphy 节点本身。
import re, subprocess, sys, os

BASE = '/mnt/e/AIPorject/101/agibot-armbian'
DTC = f'{BASE}/armbian-build/cache/sources/u-boot-worktree/u-boot-rockchip64/next-dev-v2024.10/scripts/dtc/dtc'
SRC_DTB = f'{BASE}/overlay/boot/dtb/rockchip/rk3588-agibot-mb0002-v2.dtb'
TMP = f'{BASE}/_hdmi_ab.dts'
OUT = f'{BASE}/_test_ab.dtb'

subprocess.run([DTC, '-I', 'dtb', '-O', 'dts', SRC_DTB], stdout=open(TMP, 'w'), stderr=subprocess.DEVNULL, check=True)
src = open(TMP).read()

# 1) hdmiphy@fed60000: clk-port -> node-level provider
a = '''\t\t#phy-cells = <0x0>;
\t\tstatus = "okay";
\t\tphandle = <0xe4>;

\t\tclk-port {
\t\t\t#clock-cells = <0x0>;
\t\t\tstatus = "okay";
\t\t\tphandle = <0x2d>;
\t\t};'''
b = '''\t\t#phy-cells = <0x0>;
\t\t#clock-cells = <0x0>;
\t\tclock-output-names = "clk_hdmiphy_pixel0";
\t\tstatus = "okay";
\t\tphandle = <0xe4>;'''
assert src.count(a) == 1, f'fed60000 match={src.count(a)}'
src = src.replace(a, b)

# 2) hdmiphy@fed70000(disabled): 同理
a2 = '''\t\t#phy-cells = <0x0>;
\t\tstatus = "disabled";
\t\tphandle = <0x183>;

\t\tclk-port {
\t\t\t#clock-cells = <0x0>;
\t\t\tstatus = "okay";
\t\t\tphandle = <0x2e>;
\t\t};'''
b2 = '''\t\t#phy-cells = <0x0>;
\t\t#clock-cells = <0x0>;
\t\tclock-output-names = "clk_hdmiphy_pixel1";
\t\tstatus = "disabled";
\t\tphandle = <0x183>;'''
assert src.count(a2) == 1, f'fed70000 match={src.count(a2)}'
src = src.replace(a2, b2)

# 3) display-subsystem: 删 hdmi0/1_phy_pll 旧时钟
d3 = '''\t\tports = <0x2c>;
\t\tclocks = <0x2d 0x2e>;
\t\tclock-names = "hdmi0_phy_pll", "hdmi1_phy_pll";
\t\tmemory-region = <0x2f>;'''
e3 = '''\t\tports = <0x2c>;
\t\tmemory-region = <0x2f>;'''
assert src.count(d3) == 1, f'display-subsystem match={src.count(d3)}'
src = src.replace(d3, e3)

# 4) hdmi@fde80000 link_clk arg 0x2d -> hdmiphy@fed60000 phandle 0xe4
assert src.count('0x5 0x2d>') == 1, f'fde80000 match={src.count("0x5 0x2d>")}'
src = src.replace('0x5 0x2d>', '0x5 0xe4>')

# 5) hdmi@fdea0000 link_clk arg 0x2e -> hdmiphy@fed70000 phandle 0x183
assert src.count('0x5 0x2e>') == 1, f'fdea0000 match={src.count("0x5 0x2e>")}'
src = src.replace('0x5 0x2e>', '0x5 0x183>')

open(TMP, 'w').write(src)
r = subprocess.run([DTC, '-I', 'dts', '-O', 'dtb', '-o', OUT, TMP], capture_output=True, text=True)
print('dtc exit', r.returncode)
print(r.stderr[:800])
assert r.returncode == 0, 'dtc failed'
print('WROTE', OUT, os.path.getsize(OUT))
