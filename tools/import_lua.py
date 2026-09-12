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

    # Lop offline — thay may chu da chet — la ma CUA MINH, nam o
    # brave-cross/work/offline. Tren may that no nam o sc/offline/ va nap bang
    # require("offline.init"); o day chep vao dung cho do de require tim thay.
    offline = ROOT.parent / 'brave-cross' / 'work' / 'offline' / 'sc' / 'offline'
    n_off = 0
    if offline.is_dir():
        for src in sorted(offline.rglob('*.lua')):
            out = DST / 'offline' / src.relative_to(offline)
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, out)
            n_off += 1
    else:
        print('   (khong thay lop offline o %s)' % offline)

    # Hai file thiet lap mac dinh cua ban goc: engine.lua:238 chep set_org.xgg
    # thanh set.xgg luc khoi dong, va set.lua:83 tron default.xgg vao. Lua doc
    # chung qua LGG_GetPathWithFileName('conf/...') -> res://data_ref/conf/.
    # Tai nguyen goc — data_ref/ nam trong .gitignore.
    conf_goc = SRC.parent / 'conf'
    conf_dich = ROOT / 'data_ref' / 'conf'
    n_set = 0
    for ten in ('set_org.xgg', 'default.xgg'):
        if (conf_goc / ten).is_file():
            conf_dich.mkdir(parents=True, exist_ok=True)
            shutil.copy2(conf_goc / ten, conf_dich / ten)
            n_set += 1

    (DST / '.gdignore').write_text('', encoding='utf-8')
    print('%d file lua, %d dong -> %s' % (n, lines, DST))
    print('   + %d file lop offline -> sc/offline' % n_off)
    print('   + %d file thiet lap mac dinh -> data_ref/conf' % n_set)
    if vet:
        print('   %d cho vet dich nguoc (so dinh tu khoa) da chen lai dau cach'
              % vet)
    for enc in sorted(stat):
        print('   nguon %-14s %d file' % (enc, stat[enc]))
    bad = stat.get('gb18030+thay', 0)
    if bad:
        print('   (%d file co byte la, da thay bang ky tu hong)' % bad)
    n_nil = ghi_bien_nil()
    if n_nil >= 0:
        print('   + %d bien toan cuc chac chan nil -> data_ref/bien_nil.json' % n_nil)
    return 0


# BIEN TOAN CUC CHAC CHAN NIL tren may that.
#
# Lop bong (lua/bootstrap.lua) thay moi bien toan cuc chua co bang mot bong
# — ma bong KHAC nil, nen moi cho ma goc viet 'if X == nil', 'if X then',
# 'X and X()' deu di nhanh sai. Da dinh: ISSERVER (ma dung chung di nhanh
# may chu), RECHARGESIGN_OPENMONTH (chuoi vao game chet), sngUtil_getIDFV...
#
# Ten nao ma goc KIEM nil ma KHONG AI DAT duoc thi tren may that no la nil:
#   * khong co dong gan / dinh nghia nao trong Lua (ke ca _G.X, rawset, tham
#     so, bien local, bien vong lap — loai het cho chac);
#   * khong co trong chuoi cua libgame.so va classes.dex — C++ va Java muon
#     dat bien toan cuc Lua thi phai co chuoi ten do.
# Ten node trong .xgg (lMainBtnLayer...) cung roi vao day: tren may that
# chung nil TOI KHI file bo cuc duoc nap. Lop bong chi tra nil khi khoa VANG
# MAT, nen nap xong thi chung van ra node that.
#
# Do lai moi lan import vi phu thuoc sc/ va hai file nhi phan cua APK.
ID = r'[A-Za-z_][A-Za-z0-9_]*'
KW = set('and break do else elseif end false for function if in local nil not '
         'or repeat return then true until while self'.split())
LUA_STD = set('_G _VERSION assert collectgarbage dofile error getfenv getmetatable '
              'ipairs load loadfile loadstring module next pairs pcall print rawequal '
              'rawget rawset require select setfenv setmetatable tonumber tostring type '
              'unpack xpcall coroutine debug io math os package string table bit jit '
              'newproxy gcinfo'.split())


def ghi_bien_nil():
    apk = ROOT.parent / 'brave-cross' / 'work' / 'apk'
    so_p = apk / 'lib' / 'armeabi-v7a' / 'libgame.so'
    dex_p = apk / 'classes.dex'
    if not so_p.is_file() or not dex_p.is_file():
        print('   (khong thay libgame.so / classes.dex — bo qua bien_nil.json)')
        return -1
    src = {}
    for f in SRC.rglob('*.lua'):
        src[f] = f.read_bytes().decode('utf-8', 'replace')
    gan = set()
    for s in src.values():
        for p in (r'(?m)^\s*(?:local\s+)?function\s+(' + ID + r')\s*\(',
                  r'(?m)^\s*(?:local\s+)?(' + ID + r')\s*=(?!=)',
                  r'(?m)^\s*(?:local\s+)?(' + ID + r')\s*,',
                  r'_G\s*(?:\.\s*|\[\s*["\'])(' + ID + ')'):
            gan.update(m.group(1) for m in re.finditer(p, s))
        for p in (r'\blocal\s+([^=\n]+)', r'function\s*[^(]*\(([^)]*)\)',
                  r'\bfor\s+([^=\n]+?)\s+(?:in|=)'):
            for m in re.finditer(p, s):
                gan.update(re.findall(ID, m.group(1)))
    kiem = set()
    pats = [re.compile(r'(?<![\w.:])(' + ID + r')\s*[=~]=\s*nil\b'),
            re.compile(r'\bnil\s*[=~]=\s*(' + ID + r')(?![\w.:(])'),
            re.compile(r'\bif\s+(?:not\s+)?(' + ID + r')\s+(?:then|and|or)\b'),
            re.compile(r'(?<![\w.:])(' + ID + r')\s+and\s+\1\s*\(')]
    for s in src.values():
        for line in s.split('\n'):
            if line.lstrip().startswith('--'):
                continue
            for p in pats:
                for m in p.finditer(line):
                    kiem.add(m.group(1))
    so, dex = so_p.read_bytes(), dex_p.read_bytes()
    ten = []
    for n_ in sorted(kiem - gan - KW - LUA_STD):
        r = re.compile(rb'(?<![A-Za-z0-9_])' + n_.encode() + rb'(?![A-Za-z0-9_])')
        if not r.search(so) and not r.search(dex):
            ten.append(n_)
    import json
    out = ROOT / 'data_ref' / 'bien_nil.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({
        'ghi_chu': 'tools/import_lua.py sinh — bien toan cuc ma goc kiem nil, '
                   'khong ai dat duoc (khong trong Lua, libgame.so, classes.dex)',
        'ten': ten,
    }, ensure_ascii=False, indent=1), encoding='utf-8')
    return len(ten)


if __name__ == '__main__':
    sys.exit(main())
