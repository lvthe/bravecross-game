# -*- coding: utf-8 -*-
"""Doi chieu tran dan tran voi NAKAMA THAT (khong phai ban gia cua lupa).

    python tools/verify_field_live.py
    python tools/verify_field_live.py --url http://127.0.0.1:7350

TAI SAO PHAI CO RIENG BAI NAY. tools/test_server_lua.py chay module Lua qua
`lupa`, ma lupa nhung mot ban Lua co SO NGUYEN 64 bit. Runtime cua Nakama la
gopher-lua, giu MOI so duoi dang float64 — chi bieu dien chinh xac so nguyen
toi 2^53. Hai runtime do co the tinh mot phep nhan ra hai ket qua khac nhau,
va lupa se khong bao gio phat hien ra.

Do chinh la ly do bo sinh so doi sang Park-Miller: he so cu 1103515245 lam
tich cham 2,4e18, qua 2^53. He so 16807 giu tich duoi 3,6e13 nen ca ba noi —
Lua that, Python, GDScript — tinh ra dung cung mot so.

Bai nay chung minh dieu do tren may chu that: cung seed thi phai cung ket qua,
cung so nguoi con song, cung so giay.
"""
import os, sys, json, argparse, urllib.request, urllib.error, base64, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'sim'))

DEFAULT_URL = 'http://127.0.0.1:7350'
# Khoa may chu mac dinh cua Nakama, dung lam Basic auth cho phan dang nhap.
SERVER_KEY = 'defaultkey'

n_pass = n_fail = 0


def check(cond, desc, detail=None):
    global n_pass, n_fail
    if cond:
        n_pass += 1
        print('  dat   %s' % desc)
    else:
        n_fail += 1
        print('  HONG  %s%s' % (desc, '' if detail is None else '  -> %s' % (detail,)))


def post(url, body, headers):
    data = json.dumps(body).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers=headers, method='POST')
    with urllib.request.urlopen(req, timeout=30) as fp:
        return json.loads(fp.read().decode('utf-8'))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--url', default=DEFAULT_URL)
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    from battle import Rules
    import field as F

    doc_path = os.path.join(ROOT, 'data_ref', 'battle_data.json')
    if not os.path.isfile(doc_path):
        sys.exit('thieu %s — sinh bang:  python sim/export_stats.py' % doc_path)
    with open(doc_path, encoding='utf-8') as fp:
        doc = json.load(fp)

    basic = base64.b64encode((SERVER_KEY + ':').encode()).decode()
    dev = 'field-%d' % int(time.time() * 1000)
    try:
        tok = post('%s/v2/account/authenticate/device?create=true' % a.url,
                   {'id': dev},
                   {'Content-Type': 'application/json',
                    'Authorization': 'Basic %s' % basic})
    except urllib.error.URLError as e:
        print('khong noi duoc %s: %s' % (a.url, e))
        print('\nCan Nakama that:  cd server && docker compose up -d')
        return 1
    session = tok['token']
    hdr = {'Content-Type': 'application/json',
           'Authorization': 'Bearer %s' % session}

    print('may chu: %s\nma thiet bi: %s\n' % (a.url, dev))
    print('=== tran dan tran: Nakama that khop mo hinh Python tung tran ===')
    raw = post('%s/v2/rpc/bx.fieldtest' % a.url, '', hdr)
    got = json.loads(raw['payload'])
    mine, theirs = got['mine'], got['theirs']

    hero_by_name = {r['HeroSprite']: r for r in doc['heroes']}
    rules = Rules(mitigation=doc['rules']['mitigation'],
                  defence_k=doc['rules']['defenceK'],
                  anger_full=doc['rules']['angerFull'],
                  max_seconds=doc['rules']['maxSeconds'],
                  use_skills=doc['rules']['useSkills'])

    for e in got['battles']:
        seed = int(e['seed'])
        res, secs, aa, bb = F.lua_battle(hero_by_name, doc['armies'], doc['base'],
                                         rules, mine, theirs, seed, seed)
        same = (int(e['result']) == res and int(e['aliveA']) == aa
                and int(e['aliveB']) == bb
                and abs(float(e['seconds']) - secs) < 0.05)
        check(same,
              'seed %d: ket qua %d, con song %d-%d, %.1f giay'
              % (seed, res, aa, bb, secs),
              'Nakama %s/%s-%s/%.2fs  vs  Python %s/%s-%s/%.2fs'
              % (e['result'], e['aliveA'], e['aliveB'], e['seconds'],
                 res, aa, bb, secs))

    print('\n===== dat %d, hong %d =====' % (n_pass, n_fail))
    return 0 if n_fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
