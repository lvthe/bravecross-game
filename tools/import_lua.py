"""Bê mã nguồn Lua của bản gốc vào dự án, quy hết về UTF-8.

    python tools/import_lua.py

Nguồn: brave-cross/work/vn/decrypted/assets/sc   (bản VIỆT, cùng bản với
       layout.py lấy bố cục — xem DEFAULT_CONF trong layout.py)
Đích : res://sc/

Thư mục đích có .gdignore nên Godot KHÔNG quét vào. Cần vậy vì addon Lua
đăng ký .lua là một ngôn ngữ script của Godot; để Godot tự nhận thì mỗi file
mã gốc sẽ bị coi là script Godot và báo lỗi. Ta nạp chúng bằng require tự
viết, đọc qua FileAccess (xem game/lua_runtime.gd).

**Mã hoá.** Khoảng 280/973 file là GBK chứ không phải UTF-8 — chú thích và
chuỗi tiếng Trung. Godot đọc file bằng UTF-8, nên để nguyên thì mọi chuỗi đó
thành ký tự hỏng. Chuỗi trong .xgg thì lại là UTF-8 sẵn. Nên phải quy về một
mối, và UTF-8 là mối đó: ở đây giải GBK rồi ghi lại thành UTF-8.

Mã gốc CÓ BẢN QUYỀN — sc/ nằm trong .gitignore, không đẩy lên.
"""
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT.parent / 'brave-cross' / 'work' / 'vn' / 'decrypted' / 'assets' / 'sc'
DST = ROOT / 'sc'

# gb18030 la ban trum cua gbk, nen thu no truoc khi phai thay ky tu hong.
ENCODINGS = ('utf-8', 'gb18030', 'gbk')


def decode(blob: bytes):
    """(chuoi, ten ma hoa). Chi thay ky tu hong khi khong con cach nao."""
    for enc in ENCODINGS:
        try:
            return blob.decode(enc), enc
        except UnicodeDecodeError:
            pass
    return blob.decode('gb18030', 'replace'), 'gb18030+thay'


def main() -> int:
    if not SRC.is_dir():
        print('KHONG thay ma goc o %s' % SRC)
        print('Xem muc "Ban quyen" trong README cua brave-cross.')
        return 1

    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)

    stat = {}
    lines = 0
    n = 0
    for src in sorted(SRC.rglob('*')):
        if src.is_dir():
            continue
        rel = src.relative_to(SRC)
        out = DST / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        if src.suffix.lower() != '.lua':
            shutil.copy2(src, out)
            continue
        text, enc = decode(src.read_bytes())
        out.write_text(text, encoding='utf-8', newline='')
        stat[enc] = stat.get(enc, 0) + 1
        lines += text.count('\n')
        n += 1

    if not n:
        print('HONG: chep xong ma khong co file .lua nao')
        return 1

    (DST / '.gdignore').write_text('', encoding='utf-8')
    print('%d file lua, %d dong -> %s' % (n, lines, DST))
    for enc in sorted(stat):
        print('   nguon %-14s %d file' % (enc, stat[enc]))
    bad = stat.get('gb18030+thay', 0)
    if bad:
        print('   (%d file co byte la, da thay bang ky tu hong)' % bad)
    return 0


if __name__ == '__main__':
    sys.exit(main())
