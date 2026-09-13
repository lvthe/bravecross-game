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
    ('ma Lua ban goc',      'script', 'tools/verify_lua_ui.gd',  False, []),
    ('man hinh Lua ban goc','script', 'tools/verify_lua_screen.gd', False, []),
    ('action + anh (Lua)',  'script', 'tools/verify_lua_actions.gd', False, []),
    ('cham (Lua)',          'script', 'tools/verify_cham.gd',    False, []),
    ('canh Main (Lua)',     'script', 'tools/verify_main.gd',    False, []),
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
]

SCORE = re.compile(r'dat (\d+), hong (\d+)')


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
