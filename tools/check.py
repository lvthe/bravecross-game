# -*- coding: utf-8 -*-
"""Chay het bo kiem tra roi bao mot bang tom tat.

    python tools/check.py
    python tools/check.py --url http://127.0.0.1:7399    # may chu gia

Bo nao can may chu ma khong noi duoc thi bao BO QUA chu khong bao hong — de
con phan biet "chua bat Nakama" voi "code hong".

Viet bang Python chu khong phai PowerShell vi may nay chan chay file .ps1
(ExecutionPolicy), va do la thiet lap bao mat khong nen doi chi de chay test.
"""
import os, re, sys, shutil, argparse, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# (ten, kieu, file, can_may_chu, tham so them)
SUITES = [
    ('rig nhan vat',         'script', 'tools/verify.gd',         False, []),
    ('mo hinh chien dau',    'script', 'tools/verify_battle.gd',  False, []),
    ('bo cuc man hinh',     'script', 'tools/verify_layout.gd',  False, []),
    # Chinh sach co gian cua so: cai dat du an phai la `expand` (khong phai mac
    # dinh `keep` cua Godot), cong thuc hai nhanh cua ban goc
    # (`CSceneManager:SetWHScaleToWinSize`) van con trong `sc/`, va hai duong
    # tinh ra CUNG ket qua tren dai ti le 1,0 -> 2,5. Bo do bang cua so that
    # (`tools/do_co_gian.gd`) nam ngoai check.py vi `--headless` khong doi duoc
    # do phan giai; bo nay giu phan kiem duoc ma khong can cua so.
    ('co gian cua so',      'script', 'tools/verify_co_gian.gd', False, []),
    ('ma Lua ban goc',      'script', 'tools/verify_lua_ui.gd',  False, []),
    ('man hinh Lua ban goc','script', 'tools/verify_lua_screen.gd', False, []),
    ('action + anh (Lua)',  'script', 'tools/verify_lua_actions.gd', False, []),
    ('cham (Lua)',          'script', 'tools/verify_cham.gd',    False, []),
    ('canh Main (Lua)',     'script', 'tools/verify_main.gd',    False, []),
    # Lop CUON CCScrollLayer (lua/cuon.lua) tren canh Main that: do lech, bien,
    # nha ve bien, va nut nha ben phai (ai vo tan) co bam duoc sau khi cuon.
    ('cuon lop thanh pho',  'script', 'tools/verify_cuon.gd',    False, []),
    # BANG danh sach cua engine (lua/bang.lua): LuaTableView_create. Do tung
    # con so cua hop dong CCTableView tren mot uy quyen gia (xep o, kho o dung
    # lai, bien cuon, scrollTo theo ti le, mot cu bam ra dung chi so), roi mo
    # hai man THAT da chet o <bong LuaTableView_create()>.
    ('bang danh sach',      'script', 'tools/verify_bang.gd',    False, []),
    # Main -> chon ai -> bo tri quan -> tran (g_BattleField gia) -> man ket
    # thuc, qua lop offline: ca chuoi chien dich cua ban goc.
    ('chien dich (Lua)',    'script', 'tools/do_chien_dich.gd',  False, ['--kiem']),
    # Cung duong do nhung BANG CU BAM THAT vao tung nut (touch_at, nhu chuot
    # cua --xem): lop phu nao con hien ma nuot cu bam la lo ngay.
    ('bam that Main -> tran', 'script', 'tools/bam_that.gd',     False, []),
    # Kich ban tran: nap sc/plot/drama_<ai>.lua, chay coroutine, do chuoi thoai.
    ('kich ban tran (Lua)',  'script', 'tools/do_chien_dich.gd', False, ['--kichban']),
    ('tang cau hinh (Lua)', 'script', 'tools/verify_lua_config.gd', False, []),
    ('trang bi (GDScript)',  'script', 'tools/verify_equipment.gd', False, []),
    ('man trang bi',         'scene',  'tools/verify_equip.tscn', False, []),
    ('man nhiem vu',         'scene',  'tools/verify_tasks.tscn', False, []),
    ('thien vi san',         'scene',  'battle/battle.tscn',      False,
     ['--sim=300', '--mirror']),
    ('giao van mang',        'script', 'tools/verify_net.gd',     True,  []),
    ('phien choi',           'script', 'tools/verify_session.gd', True,  []),
    ('RPC / chong gian lan', 'script', 'tools/verify_rpc.gd',     True,  []),
    # Cau hoi quan trong nhat cua man tran: cai chieu tren man co DUNG la tran
    # may chu da xu khong. Can may chu that.
    ('phat lai dung tran',   'scene',  'battle/battle.tscn',      True,
     ['--replaycheck']),
    # Am thanh boc tu .bank cua ban goc: tung file .ogg phai nap duoc bang
    # AudioStreamOggVorbis va do dai phai BANG so_mau/rate cua FSB5 — do dai
    # dung moi chung minh khoi setup, so kenh va granule trang cuoi deu dung.
    # Kem theo: bang tra event:/... -> file phai tra ra file that cho bay
    # tieng ma chinh SoundManager.lua cua ban goc dung, VA phan cuoi di dung
    # duong Lua (khung suon -> G_SoundManager -> kenh phat) — truoc day cac
    # ten do la BONG nen moi tieng bam nut deu cam.
    ('am thanh',             'script', 'tools/verify_am.gd',     False, []),
    # Ba ham DIEM GAN cua armature (_lua_addChildToPlugIn / _lua_clearPlugIn /
    # _lua_getPlugInPositionInNode, 48 cho goi trong ma goc). Truoc day chung
    # KHONG TON TAI: ten khong co trong bang Node nen roi vao __index, tra ve
    # mot ham dem lai roi tra nil — khong bao loi, chi la khong co gi duoc treo.
    # Do bang cach so vi tri do duoc LUC CHAY voi vi tri ghi trong chinh file
    # armature Gashapon (PlugIn_4..7, dong tac Star1 — ca bon chi co mot khoa,
    # nen vi tri la hang so).
    ('diem gan armature',    'script', 'tools/verify_plug.gd',   False, []),
    # To xam (shader so 1 cua ban goc, `.rodata 0x7ccf00`). Kiem PHAN NOI DAY:
    # node VE nao doi sang vat lieu xam, node nao khong (nhan di duong Lua,
    # lop mau chua lam), vat lieu dung chung, va cong thuc trong file
    # .gdshader — he so sai o do la loi IM LANG nen phai doc file ra kiem.
    # Phan HINH do bang `tools/do_xam.gd`, chay CO trinh ve that nen khong nam
    # trong bang nay.
    ('to xam (Lua)',         'script', 'tools/verify_xam.gd',    False, []),
    # Hieu ung sang (shader so 2 cua ban goc, `.rodata 0x7cccd4`): cung ho
    # "ten -> chuong trinh" voi `setGray`. Kiem phan NOI DAY — ba lop CO ANH
    # (CCSprite / CCButton / CCScale9Sprite) doi sang vat lieu sang, nhan va lop
    # mau thi khong, hai node dung chung mot vat lieu, va luat kho nhat: hai hieu
    # ung dung CUNG mot o chuong trinh cua node nen tat cai nay la tra ve chuong
    # trinh THUONG, tuc xoa luon cai kia. Cong thuc (rgb x1,5, alpha khong nhan)
    # doc tu chinh file `.gdshader`; phan HINH do bang `tools/do_sang.gd`.
    ('to sang (Lua)',        'script', 'tools/verify_sang.gd',   False, []),
    # Chuyen sac chu (shader so 8 cua ban goc, `.rodata 0x7cbcac`). Bon ham nay
    # CHI co o lop 12 `Label` — bang bind quet ca 132 lop chi ra dung bon ban ghi,
    # va `CCLabelTTF` trong .xgg lai LA lop 12 luc chay (do duoc: goi duoc
    # `setDimensions` — API chi lop 12 moi co — len node nhan cua mot file .xgg
    # that). Nen phep kiem "node nao" khong the la `type_name == 'Label'`. Kiem
    # ca ba tang: cong thuc trong file `.gdshader` (tron nguoc chieu la loi IM
    # LANG), phan noi day (vat lieu theo TUNG node, chieu cao theo o, co khoi tao
    # 0), va duong ma man hinh dung — `g_CUIPublic:SetEnableGradualLableGray`,
    # noi khoa luon thu tu sau gia tri vi no "lam phang" dai bang bo ba THU HAI.
    # Phan HINH do bang `tools/do_chuyen_sac.gd` (can trinh ve that).
    ('chuyen sac chu (Lua)', 'script', 'tools/verify_chuyen_sac.gd', False, []),
    # He HAT cua ban goc (ui/hat.gd + lua/hat.lua). Du lieu: 33 dinh nghia
    # .plist boc bang brave-cross/work/hatref.py; bo cuc dung 87 node, 7 dinh
    # nghia. Bo kiem tinh LAI tung tham so tu file JSON roi doi chieu voi vat
    # lieu ma ui/hat.gd dat ra — hai duong khac nhau phai ra cung so, va bon
    # khang dinh trong chu thich (duration am ca 33, rotationEnd == rotationStart
    # ca 33, L+v > 0 ca 33, khong kenh mau nao 0 kem phuong sai) thanh phep kiem
    # chu khong con la cau chu.
    ('he hat',               'script', 'tools/verify_hat.gd',    False, []),
    # RichLabel: chu co the mau (bien `failed` ma CHINH Lua ban goc gan — truoc
    # day la bong nen `parseString_` tra nguyen chuoi lam mot doan, moi chuoi co
    # the hien nguyen the ra man hinh) va che do tach TUNG KY TU
    # (`getLimitShowCount` / `getLetterEx` tung tra 0/nil nen moi doan chu nam im
    # o (0,0) thay vi duoc xep cho). Do bang so tren chuoi that co dau.
    ('RichLabel',            'script', 'tools/verify_richlabel.gd', False, []),
    # O CHU cua nhan: ban goc giu BA truong rieng (o +0x2c4/+0x2c8, cap tra loi
    # +0x5c/+0x60, co autoFix +0x21c), nen `getContentSize` khong phai kich thuoc
    # node. Do bang cach chay DUNG chuoi buoc cua `brave-cross/work/emu_nhan.py`
    # tren ban goc that (may ao Android, bon luot) roi doi chieu LUAT — diem anh
    # khong so duoc vi font cua ta khac tahoma. Gom ca ba cho tung sai: co "ban"
    # bi cong theo `gd.size` (nen `setDimensions(w,0)` roi `setString` tra so CU),
    # `autoFixSize` khi o cao 0 (ban goc ra 0, nhan bien mat), va `setContentSize`
    # khong xoa co "ban" nen lan doc dau van bo cuc lai.
    ('o chu / autoFixSize',  'script', 'tools/verify_dimensions.gd', False, []),
    # Thanh / vong tien do cua ban goc (ui/tien_do.gd + lua/tien_do.lua, 325
    # node trong 73 bo cuc). Truoc day chung la node 'layer' co anh nen bi coi
    # la SPRITE va ve day dac o moi phan tram. Bo kiem chay bon tang: neo va
    # tinh CAT cua thanh, hinh hoc quat (nam gon trong o, dung chieu, khong vat
    # bon goc), noi day tu bo cuc THAT (o lay theo BAN GHI chu khong theo anh —
    # g_ptWarSoulTBar o 71x297 ma anh 102x324), va duong Lua (setPercentage /
    # setType phai doi dung node, con setOrange phai CON dem duoc la thieu).
    ('tien do',              'script', 'tools/verify_tien_do.gd', False, []),

    # O NHAP CHU (CCEditBox, 40 node trong 22 bo cuc). Truoc luot nay
    # ui/xgg_layout.gd xep chung vao kind 'label' nen chung thanh NHAN CHU, va
    # bay phuong thuc cua ma goc roi vao bo dem M.missing ma khong mot loi nao.
    # Bon tang: du lieu .xgg (40 node / 22 file; ban ghi o nhap khong co
    # text/alignH/alignV, anh nen 30x30 dung cho o 150x30..410x45 nen ban goc CO
    # GIAN anh theo o), nam phuong thuc cua CCEditBox doi chieu voi lop Node,
    # duong nguoi choi (cham -> tieu diem -> go phim that -> bon su kien began /
    # changed / ended / return ban ra ham Lua da dang ky), va thu tu tren-duoi
    # giua o nhap voi node co ten cham.
    ('o nhap',               'script', 'tools/verify_o_nhap.gd',  False, []),
]

SCORE = re.compile(r'dat (\d+), hong (\d+)')
SKIP = re.compile(r'^BO QUA: *(.+)$', re.M)


def find_godot():
    """Tim Godot, ke ca khi winget khong tao duoc alias.

    Cai bang winget MA KHONG co quyen admin thi no bao "Successfully installed"
    nhung KHONG tao duoc symlink trong WinGet\\Links — exe nam nguyen trong
    WinGet\\Packages\\<id>\\Godot_vX.Y.Z-stable_win64.exe. Truoc day chi tim
    'godot' tren PATH va cai alias do, nen may nao cai kieu ay la coi nhu
    khong co Godot.
    """
    p = shutil.which('godot') or shutil.which('godot_console')
    if p:
        return p

    guess = os.path.expandvars(
        r'%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe')
    if os.path.isfile(guess):
        return guess

    pkgs = os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\WinGet\Packages')
    if os.path.isdir(pkgs):
        # Ban moi nhat truoc, va uu tien ban _console vi tren Windows no moi
        # chac chan do stdout ve cho tien trinh goi.
        found = []
        for d in os.listdir(pkgs):
            if 'Godot' not in d:
                continue
            for f in os.listdir(os.path.join(pkgs, d)):
                if f.startswith('Godot_v') and f.endswith('.exe'):
                    found.append(os.path.join(pkgs, d, f))
        if found:
            found.sort(key=lambda f: ('_console' not in f, f), reverse=False)
            found.sort(key=lambda f: os.path.basename(f).split('-')[0], reverse=True)
            return found[0]

    for env in ('GODOT', 'GODOT4'):
        p = os.environ.get(env)
        if p and os.path.isfile(p):
            return p
    return None


def server_up(url):
    try:
        import urllib.request
        with urllib.request.urlopen(url + '/healthcheck', timeout=3) as r:
            return r.status == 200
    except Exception:
        return False


SCRIPT_ERR = re.compile(
    r'^(?:SCRIPT ERROR|ERROR|USER SCRIPT ERROR)[:.] *(.+)$', re.M)


def first_script_error(out):
    """Dong loi dau tien cua Godot, hoac '' neu khong co.

    Dung de phan biet 'chay lau' voi 'crash roi treo'. Godot khong thoat khi
    script loi trong che do --script, nen khong co cai nay thi ca hai truong
    hop deu ra QUA GIO nhu nhau.
    """
    m = SCRIPT_ERR.search(out or '')
    return m.group(1).strip()[:70] if m else ''


def run(godot, kind, path, extra, url, needs_server):
    argv = [godot, '--headless', '--path', ROOT]
    argv += ['--script', path] if kind == 'script' else [path]
    argv += ['--']
    argv += extra
    if needs_server:
        argv += ['--url=' + url]
    # Gop stderr vao stdout. Godot do 'SCRIPT ERROR' ra stderr; truoc day
    # capture_output bat rieng roi vut di, nen mot bo crash xong TREO chi hien
    # ra thanh 'QUA GIO' — dung y het mot bo chay lau, va loi that bi che.
    try:
        out = subprocess.run(argv, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True,
                             encoding='utf-8', errors='replace',
                             timeout=600).stdout or ''
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ''
        if isinstance(out, bytes):
            out = out.decode('utf-8', 'replace')
        err = first_script_error(out)
        return ('QUA GIO sau khi loi: %s' % err) if err else 'QUA GIO', True

    err = first_script_error(out)
    if err and not SCORE.search(out):
        return 'LOI SCRIPT: %s' % err, True
    # BO QUA khac HONG: bo am thanh can am thanh cua ban goc, ma thu muc do
    # khong commit duoc (xem .gitignore). Tren may khong co APK thi no phai la
    # "bo qua", khong phai "do".
    m_skip = SKIP.search(out)
    if m_skip:
        return 'BO QUA (%s)' % m_skip.group(1).strip(), False
    m = SCORE.search(out)
    if m:
        ok, bad = int(m.group(1)), int(m.group(2))
        return '%d dat, %d hong' % (ok, bad), bad > 0
    if 'san khong thien vi' in out:
        return 'dat', False
    if 'THIEN VI' in out:
        return 'HONG: san thien vi mot ben', True
    return 'KHONG DOC DUOC KET QUA', True


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--url', default='http://127.0.0.1:7350')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    godot = find_godot()
    online = server_up(a.url)

    print('\ngodot   : %s' % (godot or 'KHONG thay'))
    print('may chu : %s  ->  %s\n'
          % (a.url, 'dang chay' if online else 'KHONG noi duoc'))

    # Bo ca doi chieu trang bi la thu SINH RA duoc (cong thuc thuan, khong
    # can bang so nao cua ban goc), ma data_ref/ thi khong commit — nen tu
    # sinh khi thieu, thay vi de bo test bao hong tren mot ban clone moi.
    eq_ref = os.path.join(ROOT, 'data_ref', 'equipment_ref.json')
    if not os.path.isfile(eq_ref):
        print('  ... sinh %s' % os.path.relpath(eq_ref, ROOT), flush=True)
        subprocess.run([sys.executable, os.path.join(ROOT, 'sim', 'equipment.py'),
                        '--export'], capture_output=True, text=True, timeout=120)

    # Cung loai: bien_gan.json la danh sach 6.901 ten ma CHINH Lua ban goc gan
    # (tools/import_lua.py: ghi_bien_gan). Thieu no thi boot.la_bong() tra ve
    # sai cho dung nhung ten do — RichLabel lai tra nguyen chuoi lam mot doan,
    # tuc la bo RichLabel bao hong vi mot file thieu, chu khong vi code hong.
    # Sinh lai duoc tu sc/ nen tu sinh, y nhu tren.
    gan_ref = os.path.join(ROOT, 'data_ref', 'bien_gan.json')
    if not os.path.isfile(gan_ref):
        print('  ... sinh %s (tools/import_lua.py)'
              % os.path.relpath(gan_ref, ROOT), flush=True)
        subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'import_lua.py')],
                       capture_output=True, text=True, timeout=900)
        if not os.path.isfile(gan_ref):
            print('  (khong sinh duoc — thieu ma goc sc/: xem README brave-cross)')

    # Am thanh thi KHAC: no la du lieu cua ban goc, khong sinh ra duoc — chi
    # boc lai duoc tu APK. Khong co APK thi bo do am thanh tu bao BO QUA (xem
    # tren), con co thi boc luon cho tien: 1498 file .ogg, vai chuc giay.
    bank_py = os.path.join(os.path.dirname(ROOT), 'brave-cross', 'work', 'bank.py')
    apk_banks = os.path.join(os.path.dirname(ROOT), 'brave-cross', 'work', 'vn',
                             'apk', 'assets', 'banks')
    am_kem = os.path.join(ROOT, 'assets_ref', 'audio', 'bank_ref.json')
    if not os.path.isfile(am_kem) and os.path.isdir(apk_banks):
        print('  ... boc am thanh (bank.py --all)', flush=True)
        subprocess.run([sys.executable, bank_py, '--all', '--out',
                        os.path.join(ROOT, 'assets_ref', 'audio')],
                       capture_output=True, text=True, timeout=600)
        subprocess.run([sys.executable, os.path.join(os.path.dirname(bank_py),
                                                     'event_ref.py')],
                       capture_output=True, text=True, timeout=600)

    rows = []
    failed = 0
    # Nap project mot lan truoc khi chay bo Godot nao. Ten lop toan cuc
    # (class_name) nam trong .godot/global_script_class_cache.cfg — gitignore,
    # nen pull code co lop moi ve ma chua import thi moi script tro toi lop
    # do bao "not declared", nhin y nhu code hong nang. Da gap: bon bo hong
    # mot luc chi vi thieu buoc nay (README, "Lan dau tren mot may moi").
    print('  ... nap project (godot --import)', flush=True)
    try:
        subprocess.run([godot, '--headless', '--path', ROOT, '--import'],
                       capture_output=True, timeout=900)
    except subprocess.TimeoutExpired:
        print('  (godot --import qua gio — van chay tiep)')

    for name, kind, path, needs, extra in SUITES:
        # Thieu Godot thi BO QUA cac bo can Godot, khong thoat han: hai bo
        # Python o duoi (96 kiem tra) chay duoc ma khong can Godot, va tren
        # may chi chay phan may chu thi van muon do chung.
        if not godot:
            rows.append((name, 'BO QUA (khong co godot)'))
            continue
        if needs and not online:
            rows.append((name, 'BO QUA (can may chu)'))
            continue
        print('  ... %s' % name, flush=True)
        text, bad = run(godot, kind, path, extra, a.url, needs)
        rows.append((name, text))
        failed += 1 if bad else 0

    # Ba bo chay bang Python. Hai bo dau khong can gi; bo thu ba can may chu
    # THAT — no do dung cai ma ban gia cua lupa khong do duoc: runtime cua
    # Nakama giu moi so duoi dang float64, con lupa thi co so nguyen 64 bit.
    py_steps = [('mo phong Python', os.path.join('sim', 'test_sim.py'), False),
                ('trang bi', os.path.join('sim', 'test_equipment.py'), False),
                ('luat may chu (Lua)', os.path.join('tools', 'test_server_lua.py'), False),
                ('tran dan tran (may chu that)',
                 os.path.join('tools', 'verify_field_live.py'), True)]
    for name, rel, needs_server in py_steps:
        if needs_server and not online:
            rows.append((name, 'bo qua (khong co may chu)'))
            continue
        print('  ... %s' % name, flush=True)
        try:
            argv = [sys.executable, os.path.join(ROOT, rel)]
            if needs_server:
                argv += ['--url', a.url]
            out = subprocess.run(argv,
                                 capture_output=True, text=True, encoding='utf-8',
                                 errors='replace', timeout=600).stdout or ''
            m = SCORE.search(out)
            if m:
                rows.append((name, '%s dat, %s hong' % m.groups()))
                failed += 1 if int(m.group(2)) else 0
            else:
                rows.append((name, 'KHONG DOC DUOC KET QUA'))
                failed += 1
        except Exception as e:
            rows.append((name, 'LOI: %s' % e))
            failed += 1

    width = max(len(r[0]) for r in rows)
    print()
    for name, text in rows:
        print('  %-*s   %s' % (width, name, text))
    print()

    if failed:
        print('%d bo co van de.' % failed)
        return 1
    if not godot:
        print('Xong. Cac bo can Godot bi bo qua.')
        print('Cai Godot:  winget install GodotEngine.GodotEngine')
    if not online:
        print('Xong. Cac bo can may chu bi bo qua.')
        print('Bat may chu:  cd server  &&  docker compose up -d')
    if godot and online:
        print('Tat ca xanh.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
