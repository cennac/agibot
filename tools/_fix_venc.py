#!/usr/bin/env python3
# rkvenc OPP 手术(在 WSL 跑):给 vdd_vdenc_s0 加 phandle、插入 venc-opp-table、
# 两个 rkvenc-core 挂 operating-points-v2 + venc/mem-supply。
import re

src = open('/tmp/agibot_fixed.dts').read()

# 1) DCDC_REG4 (vdd_vdenc_s0) 加 phandle 0x300
old = '''\t\t\t\t\tregulator-ramp-delay = <0x30d4>;
\t\t\t\t\tregulator-name = "vdd_vdenc_s0";

\t\t\t\t\tregulator-state-mem {
\t\t\t\t\t\tregulator-off-in-suspend;
\t\t\t\t\t};
\t\t\t\t};'''
new = '''\t\t\t\t\tregulator-ramp-delay = <0x30d4>;
\t\t\t\t\tregulator-name = "vdd_vdenc_s0";
\t\t\t\t\tphandle = <0x300>;

\t\t\t\t\tregulator-state-mem {
\t\t\t\t\t\tregulator-off-in-suspend;
\t\t\t\t\t};
\t\t\t\t};'''
assert src.count(old) == 1, f"vdenc node match={src.count(old)}"
src = src.replace(old, new)

# 2) 在 rkvenc-core@fdbd0000 前插入 venc-opp-table (phandle 0x301)
OPP = '''\tvenc-opp-table {
\t\tcompatible = "operating-points-v2";
\t\tphandle = <0x301>;

\t\topp-800000000 {
\t\t\topp-hz = <0x0 0x2faf0800>;
\t\t\topp-microvolt = <0xc3500 0xc3500 0xcf850 0xc3500 0xc3500 0xcf850>;
\t\t};
\t};

\trkvenc-core@fdbd0000 {'''
assert src.count('\trkvenc-core@fdbd0000 {') == 1
src = src.replace('\trkvenc-core@fdbd0000 {', OPP)

# 3) 两个 rkvenc-core 节点挂 opp + supply (在各自 power-domains 行后插)
pat = re.compile(r'(\trkvenc-core@fd(bd|be)0000 \{.*?power-domains = <[^>]*>;\n)', re.S)
n = [0]
def hook(m):
    n[0] += 1
    return m.group(1) + '\t\toperating-points-v2 = <0x301>;\n\t\tvenc-supply = <0x300>;\n\t\tmem-supply = <0x300>;\n'
src = pat.sub(hook, src)
assert n[0] == 2, f"core nodes matched={n[0]}"

open('/tmp/agibot_fixed.dts', 'w').write(src)
print(f"OK: vdenc phandle + opp table + {n[0]} core nodes patched")
