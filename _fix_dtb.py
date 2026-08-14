#!/usr/bin/env python3
# DTB 手术脚本(在 WSL 跑):剥 OPP nvmem/supported-hw 匹配 + 补 thermal trips
import re, sys

src = open('/tmp/agibot.dts').read()

# 1) 剥 OPP 匹配机制(任意缩进,逐行匹配这些属性)
drop_lines = [
    re.compile(r'^\s*nvmem-cells = <[^>]*>;\s*$'),
    re.compile(r'^\s*nvmem-cell-names = <[^>]*>;\s*$'),
    re.compile(r'^\s*rockchip,supported-hw;\s*$'),
    re.compile(r'^\s*opp-supported-hw = <[^>]*>;\s*$'),
]
counts = [0, 0, 0, 0]
out = []
for line in src.splitlines(True):
    dropped = False
    for i, p in enumerate(drop_lines):
        if p.match(line):
            counts[i] += 1
            dropped = True
            break
    if not dropped:
        out.append(line)
src = ''.join(out)
print(f"dropped: nvmem-cells={counts[0]} names={counts[1]} rockchip-supported-hw={counts[2]} opp-supported-hw={counts[3]}")

# 2) 补 thermal trips(块级正则,在 zone 的关闭括号前插入)
TRIPS = (
    "\t\t\ttrips {\n"
    "\t\t\t\ttrip-point-0 {\n"
    "\t\t\t\t\ttemperature = <0x124f8>;\n"
    "\t\t\t\t\thysteresis = <0x7d0>;\n"
    "\t\t\t\t\ttype = \"passive\";\n"
    "\t\t\t\t};\n"
    "\t\t\t\tzone-crit {\n"
    "\t\t\t\t\ttemperature = <0x1c138>;\n"
    "\t\t\t\t\thysteresis = <0x7d0>;\n"
    "\t\t\t\t\ttype = \"critical\";\n"
    "\t\t\t\t};\n"
    "\t\t\t};\n"
)
count = [0]
def add_trips(m):
    block = m.group(0)
    if 'trips' in block:
        return block
    count[0] += 1
    # 去掉末尾的 "\t\t};\n",插入 trips 再补回
    tail = "\t\t};\n"
    assert block.endswith(tail), repr(block[-30:])
    return block[:-len(tail)] + TRIPS + tail
src = re.sub(r'\t\t\w[\w-]*-thermal \{.*?\n\t\t\};\n', add_trips, src, flags=re.S)
print(f"zones patched: {count[0]}")

open('/tmp/agibot_fixed.dts', 'w').write(src)
print("written /tmp/agibot_fixed.dts")
