"""Bê mã nguồn Lua của bản gốc vào dự án.

    python tools/import_lua.py

Nguồn: brave-cross/work/decrypted/assets/sc  (và conf/ cho .xgg)
Đích : res://sc/

Thư mục đích có .gdignore nên Godot KHÔNG quét vào. Cần vậy vì addon Lua
đăng ký .lua là một ngôn ngữ script; để Godot tự nhận thì mỗi file mã gốc
sẽ bị coi là script Godot và báo lỗi. Ta nạp chúng bằng require tự viết,
đọc qua FileAccess (xem lua/loader.gd).

Mã gốc CÓ BẢN QUYỀN — sc/ nằm trong .gitignore, không đẩy lên.
"""
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT.parent / 'brave-cross' / 'work' / 'decrypted' / 'assets'
DST = ROOT / 'sc'


def main() -> int:
    src = SRC / 'sc'
    if not src.is_dir():
        print('KHONG thay ma goc o %s' % src)
        print('Xem muc "Ban quyen" trong README cua brave-cross.')
        return 1

    if DST.exists():
        shutil.rmtree(DST)
    shutil.copytree(src, DST)

    files = sorted(DST.rglob('*.lua'))
    if not files:
        print('HONG: chep xong ma khong co file .lua nao')
        return 1

    (DST / '.gdignore').write_text('', encoding='utf-8')
    lines = sum(f.read_text('utf-8', 'ignore').count('\n') for f in files)
    print('%d file lua, %d dong -> %s' % (len(files), lines, DST))
    return 0


if __name__ == '__main__':
    sys.exit(main())
