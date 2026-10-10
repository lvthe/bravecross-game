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
    # Chuoi tho (r'...') chu khong phai '...': '\g' khong phai escape hop le nen
    # Python 3.12 in SyntaxWarning moi lan chay — mot dong canh bao gia o dau ra
    # cua buoc cai dat, dung cho de lan voi canh bao that.
    return SUA_SO_DINH_TU_KHOA.subn(r'\g<1> \g<2>', text)


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

    n_131, trung_131, dung_131 = be_lop_mang_131(DST)

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
    print('   + %d file lop mang 1.31 -> sc/ (%d file da y nguyen)'
          % (n_131, trung_131))
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
    n_gan = ghi_bien_gan()
    if n_gan >= 0:
        print('   + %d bien toan cuc do CHINH Lua ban goc dat -> data_ref/bien_gan.json'
              % n_gan)

    # Dung NGAY SAU khi chep xong chu khong chan truoc: luat chi-them nen chay
    # lai la vo hai, con dung truoc thi mot tep dung ten lam ca luot import
    # khong chay — keo theo ca sc/ khong duoc dung lai.
    if dung_131:
        print('')
        print('DUNG: %d file 1.31 trung ten ma KHAC noi dung voi cay VN:'
              % len(dung_131))
        for r in dung_131:
            print('   %s' % r)
        print('Khong ghi de. Day la quyet dinh cua NGUOI, khong phai cua luat:')
        print('muon thay that thi bo sung ten vao THU_MUC_131 / TEP_131_LE.')
        return 1
    return 0


# LOP MANG 1.31 — xem ROADMAP.md, muc "pb".
#
# `pb` la mo-dun C (lua-protobuf), khong bao gio chay duoc o port: Lua o day la
# addon Godot nen `require("pb")` khong giai ra ma C. Lop mang 1.31 goi no o sau
# tep (`Framework/Network/pb/protoc.lua`), con `lua/pb.lua` la ban viet lai bang
# Lua thuan thay cho no.
#
# Nguon la cay CN 1.31, KHONG phai cay VN 1.26 — giong loi da co cho `offline/`
# o tren. Do TRUOC khi viet luat nay: cay VN khong co thu muc `Framework/`,
# `def/` hay `ide/` nao ca (0 tep moi thu muc), nen ba thu muc ay chep sang la
# 0 kha nang dung ten. Rieng `system/` thi nguoc lai: CN 23 tep, VN 19, va
# **18 trong 19 tep trung ten KHAC noi dung** — chep ca thu muc la de len nen
# du lieu VN ma khong phep kiem nao bat. Nen chi lay DUNG MOT tep cua `system/`.
#
# `ide/**` (4 tep) de ngoai: `ide/XRpc.lua` chi la `AccountRpc = AccountRpc:new()`
# va doi lop `AccountRpc` cua man dang nhap 1.31 — ngoai lop mang.
#
# Va 23 tep ay chep sang la TRO voi cay hien tai, khong chi "0 trung ten": quet
# ca cay VN thi `require("Framework...")`, `require("def...")` va
# `require("system.LoadProto")` deu **0 lan**. Nghia la khong module VN nao doi
# hanh vi vi chung xuat hien — muon lop 1.31 chay that thi phai co mot cho goi
# no, va cho do chua co (xem `system/LoadProto.lua` ben duoi).
#
# `system/LoadProto.lua` chep sang nhung CON NAM IM: no la cho vao cua lop 1.31,
# ma `s_require.lua` cua cay VN **khong** require no (do lai: 0 lan trong 19
# dong require) con ban CN thi co (`s_require.lua:26`). Muon no chay that thi
# phai lay ca `s_require.lua` cua CN — ma do la tep VN da co va KHAC noi dung,
# tuc dung cho luat nay tu choi. Do la quyet dinh cua nguoi, khong phai cua luat.
THU_MUC_131 = ('Framework', 'def')
TEP_131_LE = ('system/LoadProto.lua',)

# CHEP NGUYEN BYTE, KHONG va vet dich nguoc. Do tren dung 22 tep se chep: ca 22
# da la UTF-8 san, va ca 22 chi co DUNG MOT cho khop luat `va_dau_cach` — cho do
# nam TRONG MOT CHUOI LUA, giua blob descriptor.proto nhung trong
# `Framework/Network/pb/protoc.lua` (`\3end`). Ap luat vao do thi no thanh
# `\3 end`: ten truong `end` cua `DescriptorProto.ExtensionRange` am tham thanh
# ` en`, ma `pb.load` VAN THANH CONG — dung loai hong im lang khong phep kiem nao
# bat. Hau qua da thay that: cay thu co protoc.lua 33400 byte, cay CN 33399.


def be_lop_mang_131(dst):
    """Chep lop mang 1.31 vao `sc/`. Tra (so them, so da y nguyen, ds dung).

    LUAT CHI-THEM, va day khong phai chuyen hinh thuc: `sc/` sinh lai tu cay VN
    moi lan chay, nen mot lan de len la doi nen du lieu VN ngay bay gio, roi bi
    lan import sau xoa di — tuc cai sai o lai con dau vet thi mat. Gap dich da
    ton tai va KHAC noi dung thi DUNG va BAO, khong ghi.
    """
    nguon = (ROOT.parent / 'bravecross-source' / 'cn131' / 'decrypted'
             / 'assets' / 'sc')
    if not nguon.is_dir():
        print('   (khong thay cay CN 1.31 o %s)' % nguon)
        return 0, 0, []
    can = []
    for ten in THU_MUC_131:
        can += [p for p in sorted((nguon / ten).rglob('*')) if p.is_file()]
    can += [nguon / t for t in TEP_131_LE if (nguon / t).is_file()]
    them, trung, dung = 0, 0, []
    for src in can:
        rel = src.relative_to(nguon)
        out = dst / rel
        if out.is_file():
            if out.read_bytes() == src.read_bytes():
                trung += 1
            else:
                dung.append(str(rel).replace('\\', '/'))
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, out)
        them += 1
    return them, trung, dung


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


# BIEN TOAN CUC DO CHINH LUA BAN GOC DAT — khong bao gio duoc lam bong.
#
# Lop bong thay moi ten CHUA CO bang mot bong, ke ca nhung ten ma chinh Lua ban
# goc se tu dat. Do la cho sai: voi nhung ten do, ban goc doc ra nil (chua gan
# thi la nil), con ta doc ra mot bang truthy — moi phep kiem 'if x then' va moi
# vong 'pairs(x)' di mot duong khac han.
#
# Do duoc mot cho that: `sc/user/Public/RichLabel.lua:710` viet
#
#     failed = true            -- :672, khi mot the bi tach sai
#     ...
#     if failed then return self:defaultResult(originalStr) end   -- :710
#
# Lan goi DAU TIEN thi `failed` chua he duoc gan, nen ban goc di tiep va tach
# duoc chuoi co the; ta doc ra mot BONG (truthy) nen `parseString_` tra ve
# nguyen chuoi lam MOT doan — tuc RichLabel khong bao gio tach the nao ca, va
# moi chuoi dang '[fontColor=...]chu[/fontColor]' hien nguyen ca the ra man
# hinh. Ten `failed` nam trong libgame.so va classes.dex (chi la mot chu tieng
# Anh xuat hien trong chuoi), nen phep thu "co trong file nhi phan" — dung cho
# bien_nil — KHONG dung duoc o chieu nay: no se mien nham cho gan het tu thong
# dung.
#
# Ten nao ma ban goc GAN (khong 'local') thi no la bien cua Lua, va vang mat
# thi phai doc ra nil. Bong chi con lai cho nhung ten KHONG file Lua nao gan —
# tuc be mat engine (C++/Java) chua lam xong, dung y nghia ban dau cua no.
#
# NHUNG con mot duong nua ma luat "Lua co gan" khong nhin thay: ban goc doi khi
# BOC mot ham cua ENGINE chu khong phai dinh nghia moi. Do duoc o
# `sc/user/Logical/Device.lua:249`:
#
#     local pRawFunc_LGG_Device_UUID = LGG_Device_UUID   -- :249, DOC truoc
#     LGG_Device_UUID = function () ... pRawFunc_LGG_Device_UUID() ... end
#
# `LGG_Device_UUID` la ham C++ cua engine (co trong bang ten ham toan cuc cua
# `libgame.so`, .rodata 0x7af167..0x7af4eb: `LGG_Device_Init`, `LGG_Device_UUID`,
# `KGuide_*`, `LGG_App_*`...). Ban goc doc no ra truoc khi gan, nen phep gan do
# la BOC, khong phai dinh nghia — ep nil thi `pRawFunc_...` = nil va loi o
# `:251` (`attempt to call upvalue 'pRawFunc_LGG_Device_UUID' (a nil value)`).
# Do la loi THAT da gap khi chay `tools/vao_main.gd`: khong vao duoc Main.
#
# Nen them mot phep thu nua: ten nao co CHUOI RIENG `\0TEN\0` trong
# libgame.so / classes.dex thi engine CO lo ra ten do — khong duoc ep nil.
#
# Vi sao phai doi `\0` hai dau chu khong tim tran: `failed` xuat hien 311 lan
# trong hai file nhi phan (chi la chu tieng Anh trong chuoi), nhung `\0failed\0`
# **0 lan**; con `LGG_Device_UUID` la **1** lan — dung mot chuoi dang ky. Do la
# phep thu phan biet duoc "engine lo ra ten nay" voi "chuoi nay co chu do".
# Gia phai tra da do: `data` co 2 chuoi rieng nen van la bong (khong doi gi so
# voi truoc — no von da la bong).
#
# Do lai tren luot quet 353 man (tools/quet_show.gd): 143 ten bi lam bong luc
# vao Main, trong do 22 ten thuoc nhom nay. Xem so sanh truoc/sau o ROADMAP.
#
# Quet CHAT (khac `gan` cua ghi_bien_nil, thu do co y gom ca local/tham so/bien
# vong lap vi no chi dung de TRU di cho chac): o day gom thua mot ten thi chi
# mat mot chan doan, con gom thieu mot ten thi van con loi bong — nen quet chat
# theo dau cau lenh, va them ca dang viet noi tren cung dong ('; x = 1').
def ghi_bien_gan():
    gan = set()
    for f in SRC.rglob('*.lua'):
        s = f.read_bytes().decode('utf-8', 'replace')
        gan.update(quet_gan(s))
        for m in re.finditer(r'_G\s*(?:\.\s*|\[\s*["\'])(' + ID + ')', s):
            gan.add(m.group(1))
    gan -= KW | LUA_STD
    # Ten trong bien_nil.json da co luat rieng (`never`, tra nil) — de rieng ra
    # thi hai danh sach khong chong nhau va doc ra biet cai nao vi cai nao.
    nil_p = ROOT / 'data_ref' / 'bien_nil.json'
    if nil_p.is_file():
        import json
        try:
            gan -= set(json.loads(nil_p.read_text(encoding='utf-8'))['ten'])
        except Exception:
            pass
    # Ten nao engine CO lo ra (chuoi rieng `\0TEN\0`) thi bo ra: phep gan cua
    # Lua o nhung ten do la BOC ham engine, khong phai dinh nghia (xem dau muc).
    apk = ROOT.parent / 'brave-cross' / 'work' / 'apk'
    blob = b''
    for p in (apk / 'lib' / 'armeabi-v7a' / 'libgame.so', apk / 'classes.dex'):
        if p.is_file():
            blob += p.read_bytes() + b'\x00'
    giu_lai, bo_ra = [], []
    for n in sorted(gan):
        b = n.encode()
        if blob and blob.count(b'\x00' + b + b'\x00') > 0:
            bo_ra.append(n)
        else:
            giu_lai.append(n)
    ten = giu_lai
    import json
    out = ROOT / 'data_ref' / 'bien_gan.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({
        'ghi_chu': 'tools/import_lua.py sinh — bien toan cuc do chinh Lua ban goc '
                   'gan (dau cau lenh, khong local), TRU nhung ten engine co lo '
                   'ra (chuoi rieng \\0TEN\\0 trong libgame.so/classes.dex). Lop '
                   'bong khong duoc thay nhung ten nay: ban goc doc ra nil.',
        'ten': ten,
        'bo_ra_vi_engine_co': bo_ra,
    }, ensure_ascii=False, indent=1), encoding='utf-8')
    return len(ten)


# Vi sao khong quet bang bieu thuc chinh quy theo DONG: ban dau toi lam dung
# the ('^[ \t]*(ten)[ \t]*='), va no bat luon KHOA CUA BANG nam tren dong rieng
# — `CUITab.lua:17` co dong `\t\tLabel = 1,` trong mot bang, the la ten `Label`
# (lop engine that) bi ghi nham la bien cua Lua. Dem duoc: trong 10.594 ten cua
# luat cu co ca `A`, `Add`, `Count`, `Color`, `Content`, `Class`... — toan khoa
# bang. Moi ten nham nhu vay la mot chan doan bi mat, va te hon la mot lop
# engine co the bi ep nil.
#
# Nen phai di theo TOKEN va theo DO SAU ngoac: mot ten la bien toan cuc khi no
# dung o CAP CAU LENH (ngoai moi {}, (), []) va dung sau mot moc cau lenh —
# dau file, dau dong, ';', 'then', 'else', 'do', 'end'. Chinh phep kiem moc do
# loai luon `local x = 1` (truoc `x` la `local`), `t.k = 1` (truoc `k` la `.`),
# va `f(x = 1)` (trong ngoac).
def quet_gan(text):
    out = set()
    i, n = 0, len(text)
    sau = 0            # do sau {}, (), []
    moc = True         # dang o moc cau lenh (chua co gi tren dong nay)
    while i < n:
        c = text[i]
        # chu thich dai --[[ ]] / --[=[ ]=] va chuoi dai [[ ]] / [=[ ]=]
        if c == '-' and text.startswith('--', i):
            m = re.match(r'--\[(=*)\[', text[i:])
            if m:
                ket = ']' + m.group(1) + ']'
                j = text.find(ket, i + m.end())
                i = n if j < 0 else j + len(ket)
                continue
            j = text.find('\n', i)
            i = n if j < 0 else j + 1
            moc = (sau == 0)
            continue
        if c == '[':
            m = re.match(r'\[(=*)\[', text[i:])
            if m:
                ket = ']' + m.group(1) + ']'
                j = text.find(ket, i + m.end())
                i = n if j < 0 else j + len(ket)
                moc = False
                continue
        if c in '"\'':
            j = i + 1
            while j < n:
                if text[j] == '\\':
                    j += 2
                    continue
                if text[j] == c or text[j] == '\n':
                    break
                j += 1
            i = j + 1 if j < n and text[j] == c else j
            moc = False
            continue
        if c in '{[(':
            sau += 1
            i += 1
            moc = False
            continue
        if c in '}])':
            sau = max(0, sau - 1)
            i += 1
            moc = False
            continue
        if c == '\n':
            i += 1
            if sau == 0:
                moc = True
            continue
        if c in ' \t\r':
            i += 1
            continue
        if c == ';' and sau == 0:
            i += 1
            moc = True
            continue
        if (c.isalpha() or c == '_'):
            j = i
            while j < n and (text[j].isalnum() or text[j] == '_'):
                j += 1
            tu = text[i:j]
            k = j
            while k < n and text[k] in ' \t':
                k += 1
            gan = k < n and text[k] == '=' and not text.startswith('==', k)
            # `local x =`: tu ngay truoc la `local` thi khong phai bien toan cuc
            if moc and gan and tu not in KW:
                truoc = text[:i].rstrip()
                if not truoc.endswith('local'):
                    out.add(tu)
            moc = tu in ('then', 'else', 'do', 'end', 'local')
            i = j
            continue
        i += 1
        moc = False
    return out


if __name__ == '__main__':
    sys.exit(main())
