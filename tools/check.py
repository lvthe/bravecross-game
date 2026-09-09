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
    p = shutil.which('godot')
    if p:
        return p
    guess = os.path.expandvars(
        r'%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe')
    return guess if os.path.isfile(guess) else None


def server_up(url):
    try:
        import urllib.request
        with urllib.request.urlopen(url + '/healthcheck', timeout=3) as r:
            return r.status == 200
    except Exception:
        return False


def run(godot, kind, path, extra, url, needs_server):
    argv = [godot, '--headless', '--path', ROOT]
    argv += ['--script', path] if kind == 'script' else [path]
    argv += ['--']
    argv += extra
    if needs_server:
        argv += ['--url=' + url]
    try:
        out = subprocess.run(argv, capture_output=True, text=True,
                             encoding='utf-8', errors='replace',
                             timeout=600).stdout or ''
    except subprocess.TimeoutExpired:
        return 'QUA GIO', True
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
    if not godot:
        sys.exit('khong thay godot. Cai bang: winget install GodotEngine.GodotEngine')
    online = server_up(a.url)

    print('\ngodot   : %s' % godot)
    print('may chu : %s  ->  %s\n'
          % (a.url, 'dang chay' if online else 'KHONG noi duoc'))

    rows = []
    failed = 0
    for name, kind, path, needs, extra in SUITES:
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
    if not online:
        print('Xong. Cac bo can may chu bi bo qua.')
        print('Bat may chu:  cd server  &&  docker compose up -d')
        return 0
    print('Tat ca xanh.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
