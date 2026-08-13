#!/usr/bin/env python3
# gen-armbian-cfg.py — 生成 RKDevTool「下载镜像」页用的 config.cfg(方法二:拆分写)。
#
# 自包含:自动找上层 armbian-build 产出的整盘 img,拆成 head(16MiB)+rootfs,
# 再写出 config.cfg(Loader + head@0x0 + rootfs@0x8000 三项)。
# config.cfg 里的路径强制转成 Windows 格式(E:\...)——RKDevTool 是 Windows 程序,
# 所以在 WSL 里跑本脚本也能得到 RKDevTool 可用的路径。
#
# ⚠️ 方法一(整盘写,主推)**不需要本脚本**——直接在 RKDevTool 手动加
#    Loader@0xCCCCCCCC + image@0x00000000 两项即可。详见 README.md。
#
# config.cfg 二进制布局(逆向自 RKDevTool, 与 oneshot 配置对齐):
#   29B header: "CFG" + 19B 零 + [22]=item 槽位数 + [23..28]=固定尾缀 1d 00 00 00 62 02
#   8 x 610B item: label UTF16-LE@[2:82], path UTF16-LE@[82:602](520B),
#                  addr LE@602, sel LE@606
# 头部尾缀缺失 → RKDevTool 读到 itemcount=0 → 导入即崩溃, 必须保留。
import os, struct, sys, glob, re

# Windows 中文系统 stdout 默认 GBK, ⚠/→/✓ 等 BMP 符号编不了会 UnicodeEncodeError 崩溃;
# 强制 UTF-8 输出(errors='replace' 双保险), 这样在任意 locale 下脚本都不会因打印而崩。
try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

FLASH = os.path.dirname(os.path.abspath(__file__))   # flash/ 自身
LOADER = os.path.join(FLASH, 'rk3588_spl_loader_v1.16.113.bin')
HEAD   = os.path.join(FLASH, 'armbian-head.img')
ROOTFS = os.path.join(FLASH, 'armbian-rootfs.img')
CFG    = os.path.join(FLASH, 'config.cfg')
HEAD_SECTORS = 32768            # 0x8000 = 16 MiB(head/rootfs 分界)
HEAD_BYTES   = HEAD_SECTORS * 512

def to_win(p):
    """config.cfg 给 Windows 版 RKDevTool 用, 路径须 Windows 格式。
    WSL 下 os.path 给 /mnt/e/.. → E:\\..; Windows 下已是 E:\\.. 原样返回。"""
    m = re.match(r'^/mnt/([a-zA-Z])/(.*)$', p.replace('\\', '/'))
    if m:
        return m.group(1).upper() + ':\\' + m.group(2).replace('/', '\\')
    return p

def find_img(cli_arg):
    if cli_arg:
        if os.path.isfile(cli_arg): return os.path.abspath(cli_arg)
        sys.exit(f'--img 指定的文件不存在: {cli_arg}')
    # 默认:上层 armbian-build/output/images/ 下最新的 Armbian img
    img_dir = os.path.join(FLASH, '..', 'armbian-build', 'output', 'images')
    cands = sorted(glob.glob(os.path.join(img_dir, 'Armbian-*.img')), key=os.path.getmtime)
    return os.path.abspath(cands[-1]) if cands else None

def split_img(img):
    """整盘 img 拆成 head(前 16MiB) + rootfs(剩余), 分块写, 不整块读入内存。"""
    want_root = os.path.getsize(img) - HEAD_BYTES
    if (os.path.isfile(HEAD) and os.path.isfile(ROOTFS)
            and os.path.getsize(HEAD) == HEAD_BYTES and os.path.getsize(ROOTFS) == want_root):
        print('拆分文件已存在且大小匹配, 跳过拆分')
        return
    print(f'拆分 {os.path.basename(img)} -> head(16MiB) + rootfs ...')
    bs = 4 * 1024 * 1024
    with open(img, 'rb') as fi, open(HEAD, 'wb') as fh, open(ROOTFS, 'wb') as fr:
        left = HEAD_BYTES
        while left > 0:
            chunk = fi.read(min(bs, left))
            if not chunk: sys.exit('img 小于 16MiB, 文件异常')
            fh.write(chunk); left -= len(chunk)
        while True:
            chunk = fi.read(bs)
            if not chunk: break
            fr.write(chunk)
    print(f'  head   = {os.path.getsize(HEAD):,} bytes')
    print(f'  rootfs = {os.path.getsize(ROOTFS):,} bytes')

def enc_path(p, size=520):
    b = p.encode('utf-16-le')
    assert len(b) <= size, f'path too long: {p}'
    return b + b'\x00' * (size - len(b))

def main():
    if not os.path.isfile(LOADER):
        sys.exit(f'缺失 loader: {LOADER}')
    img_arg = None
    if '--img' in sys.argv:
        i = sys.argv.index('--img')
        img_arg = sys.argv[i+1] if i+1 < len(sys.argv) else None
    img = find_img(img_arg)
    if not img:
        sys.exit('未找到整盘 img。\n'
                 '  用法: python gen-armbian-cfg.py --img <Armbian-*.img 路径>\n'
                 '  或编译后默认从 ../armbian-build/output/images/ 自动找最新 Armbian-*.img')
    print(f'整盘 img: {img}')
    split_img(img)

    items = [
        ('Loader', LOADER, 0xCCCCCCCC, 1),
        ('head',   HEAD,   0x00000000, 1),
        ('rootfs', ROOTFS, 0x00008000, 1),
        ('misc', '', 0, 0), ('recovery', '', 0, 0), ('backup', '', 0, 0),
        ('uboot', '', 0, 0), ('trust', '', 0, 0),
    ]
    hdr = b'CFG' + b'\x00' * 19 + bytes([len(items)]) + b'\x1d\x00\x00\x00\x62\x02'
    assert len(hdr) == 29
    out = bytearray(hdr)
    for label, path, addr, sel in items:
        item = bytearray(610)
        item[2:82]   = label.encode('utf-16-le')[:80].ljust(80, b'\x00')
        item[82:602] = enc_path(to_win(path))    # 写 Windows 路径给 RKDevTool
        struct.pack_into('<I', item, 602, addr)
        struct.pack_into('<I', item, 606, sel)
        out += item
    with open(CFG, 'wb') as fp:
        fp.write(out)
    assert len(out) == 4909, len(out)
    print(f'\n[OK] written {CFG} ({len(out)} bytes)')
    print(f'  header[22:29] = {" ".join(f"{b:02x}" for b in out[22:29])}  (期望 08 1d 00 00 00 62 02)')
    print(f'  Loader path(Windows) = {to_win(LOADER)}')
    print('\n导入: RKDevTool「下载镜像」页 -> 选择配置文件 -> 选 config.cfg -> 勾选三项 -> 执行')

if __name__ == '__main__':
    main()
