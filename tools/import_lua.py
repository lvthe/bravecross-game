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
import re
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


# VET CUA BO DICH NGUOC, khong phai loi cua ban goc.
#
# Trinh dich nguoc doi khi nuot mat dau cach giua mot so va tu khoa theo sau,
# nen file ra khong con la Lua hop le. Luat sua la mot luat CHUNG va hep: chi
# chen lai dau cach giua chu so va mot tu khoa, khong dong vao gi khac.
#
# Hien chi mot cho trong ca 973 file dinh phai: apr/CUIAPRCommon.lua:412
# 'nPointLevel >= 17then' — ca module apr khong nap duoc vi no.
KEYWORDS = ('then', 'do', 'end', 'and', 'or', 'not', 'else', 'elseif')
SUA_SO_DINH_TU_KHOA = re.compile(
    r'(?<![\w.])(\d+)(' + '|'.join(KEYWORDS) + r')(?![\w])')


def va_dau_cach(text):
    """Tra (chuoi da sua, so cho da sua)."""
    return SUA_SO_DINH_TU_KHOA.subn('\g<1> \g<2>', text)


def main() -> int:
    if not SRC.is_dir():
        print('KHONG thay ma goc o %s' % SRC)
        print('Xem muc "Ban quyen" trong README cua brave-cross.')
        return 1

    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)

    stat = {}
    vet = 0
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
        text, nsua = va_dau_cach(text)
        vet += nsua
        out.write_text(text, encoding='utf-8', newline='')
        stat[enc] = stat.get(enc, 0) + 1
        lines += text.count('\n')
        n += 1

    if not n:
        print('HONG: chep xong ma khong co file .lua nao')
        return 1

    (DST / '.gdignore').write_text('', encoding='utf-8')
    print('%d file lua, %d dong -> %s' % (n, lines, DST))
    if vet:
        print('   %d cho vet dich nguoc (so dinh tu khoa) da chen lai dau cach'
              % vet)
    for enc in sorted(stat):
        print('   nguon %-14s %d file' % (enc, stat[enc]))
    bad = stat.get('gb18030+thay', 0)
    if bad:
        print('   (%d file co byte la, da thay bang ky tu hong)' % bad)
    return 0


if __name__ == '__main__':
    sys.exit(main())
