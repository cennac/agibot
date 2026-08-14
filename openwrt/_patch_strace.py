#!/usr/bin/env python3
# strace 6.6 + musl: io_uring CHECK_TYPE_SIZE static assert 失败,
# 上游建议 --enable-bundled=yes(用自带 linux 头)。写进 lede 包 Makefile。
import sys

p = '/home/cennac/lede/package/devel/strace/Makefile'
s = open(p).read()
if '--enable-bundled=yes' in s:
    print('already patched')
    sys.exit(0)
old = '\t--enable-mpers=no \\\n'
new = '\t--enable-mpers=no \\\n\t--enable-bundled=yes \\\n'
n = s.count(old)
assert n == 1, f'match={n}'
open(p, 'w').write(s.replace(old, new))
print('patched OK')
