#!/usr/bin/env python3
# Generic config.cfg dumper using the fully-reversed layout (rk3588-flash-cfg memory):
# header 29B; 8 items x 610B; label UTF16@2; path UTF16@82; addr LE@602; sel LE@606
import sys

path = sys.argv[1]
d = open(path, 'rb').read()
print('file size', len(d), 'magic', d[:3])
ITEM_START = 0x1D
ITEM_SIZE = 610
for idx in range(8):
    s0 = ITEM_START + idx * ITEM_SIZE
    item = d[s0:s0 + ITEM_SIZE]
    # UTF-16LE label
    label = item[2:82].decode('utf-16-le', 'ignore').split('\x00')[0]
    # UTF-16LE path
    rawpath = item[82:602]
    p = rawpath.decode('utf-16-le', 'ignore').split('\x00')[0]
    addr = int.from_bytes(item[602:606], 'little')
    sel = int.from_bytes(item[606:610], 'little')
    print(f'[{idx}] label={label!r} sel={sel} addr=0x{addr:08x} ({addr} sectors)')
    print(f'     path={p!r}')
