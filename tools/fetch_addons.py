"""Tai addon Lua GDExtension ve addons/.

    python tools/fetch_addons.py

Addon nang ~200 MB nen khong commit. Day la may ao Lua (LuaJIT, tuc Lua 5.1
— dung doi Lua ma Cocos2d-x dung) de chay THANG ma nguon cua ban goc thay
vi chep tay tung man sang GDScript.

Nguon: https://github.com/gilzoide/lua-gdextension  (MIT)
"""
import io
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = '0.8.2'
URL = ('https://github.com/gilzoide/lua-gdextension/releases/download/'
       '%s/lua-gdextension+luajit.zip' % VERSION)


def main() -> int:
    if (ROOT / 'addons' / 'lua-gdextension' / 'luagdextension.gdextension').exists():
        print('da co addons/lua-gdextension')
        return 0
    print('tai %s ...' % URL)
    with urllib.request.urlopen(URL, timeout=600) as r:
        blob = r.read()
    print('%.1f MB, dang giai...' % (len(blob) / 1e6))
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        z.extractall(ROOT)
    ok = (ROOT / 'addons' / 'lua-gdextension' / 'luagdextension.gdextension')
    if not ok.exists():
        print('HONG: giai xong ma khong thay .gdextension')
        return 1
    print('xong -> %s' % ok.parent)
    return 0


if __name__ == '__main__':
    sys.exit(main())
