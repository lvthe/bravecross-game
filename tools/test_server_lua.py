# -*- coding: utf-8 -*-
"""Chay module Lua cua may chu ma khong can Docker.

    python tools/test_server_lua.py

Nakama chay module Lua trong runtime cua no. O day dung `lupa` (Lua nhung
trong Python) cong mot ban `nakama` GIA: register_rpc chi giu lai ham, storage
la mot bang trong bo nho, json_encode/json_decode la ham dong nhat (bai test
kiem LOGIC, khong kiem JSON).

Nho vay cac RPC goi duoc thang tu Python, va luat choi — mo chuong dan, doi
dich co dinh theo chuong, khong nhay coc — kiem duoc ngay ca khi may chu chua
chay.

DAY KHONG THAY THE tools/verify_rpc.gd. Ban gia khong co phan quyen cua Nakama,
nen phan "client khong ghi duoc ban luu" van phai chay voi may chu that.
"""
import os, sys, io, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

try:
    import lupa
except ImportError:
    sys.exit('thieu lupa:  pip install lupa')

# `nakama` gia. Giu dung nhung ham ma battle.lua dung toi.
STUB = r'''
local rpcs, hooks, store = {}, {}, {}
local nk = {}

function nk.register_rpc(fn, id) rpcs[id] = fn end
function nk.register_req_after(fn, id) hooks[id] = fn end

-- Bai test kiem logic chu khong kiem JSON: cho hai ham nay di qua nguyen ban.
function nk.json_encode(v) return v end
function nk.json_decode(v) if type(v) == "table" then return v end return {} end

function nk.storage_read(reqs)
	local out = {}
	for _, r in ipairs(reqs) do
		local k = r.user_id .. "/" .. r.collection .. "/" .. r.key
		if store[k] ~= nil then
			out[#out + 1] = { collection = r.collection, key = r.key,
					user_id = r.user_id, value = store[k] }
		end
	end
	return out
end

function nk.storage_write(writes)
	for _, w in ipairs(writes) do
		store[w.user_id .. "/" .. w.collection .. "/" .. w.key] = w.value
	end
	return {}
end

package.preload["nakama"] = function() return nk end
return { rpcs = rpcs, hooks = hooks, store = store }
'''

n_pass = n_fail = 0


def check(cond, desc, detail=None):
    global n_pass, n_fail
    if cond:
        n_pass += 1
        print('  dat   %s' % desc)
    else:
        n_fail += 1
        print('  HONG  %s%s' % (desc, '' if detail is None else '  -> %s' % (detail,)))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--module', default=os.path.join(ROOT, 'server', 'modules', 'battle.lua'))
    ap.add_argument('--data', default=os.path.join(ROOT, 'server', 'modules', 'hero_data.lua'))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    if not os.path.isfile(a.data):
        sys.exit('thieu %s — sinh bang:  python sim/export_stats.py' % a.data)

    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    env = L.execute(STUB)

    # hero_data la mot module tra ve bang. Dat preload NGAY TRONG LUA: gan mot
    # ham Python vao package.preload thi `require` cua Lua khong nhan.
    L.execute('''
        local src = ...
        package.preload["hero_data"] = function()
            return assert(load(src, "hero_data"))()
        end
    ''', io.open(a.data, encoding='utf-8').read())

    L.execute(io.open(a.module, encoding='utf-8').read())
    rpcs = env['rpcs']

    print('=== 1. module dang ky du RPC ===')
    for name in ('bx.chapters', 'bx.set_roster', 'bx.fight', 'bx.selftest'):
        check(rpcs[name] is not None, 'co %s' % name)
    check(env['hooks']['AuthenticateDevice'] is not None,
          'co hook sau dang nhap (tao san ban luu do may chu so huu)')

    ctx = L.table(user_id='u-test')

    print('\n=== 2. chuong: chi mo dan tung cai ===')
    ch = rpcs['bx.chapters'](ctx, None)
    check(int(ch['total']) == 12, 'co 12 chuong', ch['total'])
    check(int(ch['cleared']) == 0, 'nguoi choi moi chua qua chuong nao')
    unlocked = sum(1 for i in range(1, 13) if ch['chapters'][i]['unlocked'])
    check(unlocked == 1, 'moi mo chuong 1', unlocked)
    p1 = float(ch['chapters'][1]['power'])
    p12 = float(ch['chapters'][12]['power'])
    check(p12 > p1, 'chuong sau manh hon', '%.2f -> %.2f' % (p1, p12))

    print('\n=== 3. doi dich cua mot chuong la co dinh ===')
    def enemies(doc, n):
        e = doc['chapters'][n]['enemies']
        return [e[i] for i in range(1, len(e) + 1)]
    ch2 = rpcs['bx.chapters'](ctx, None)
    check(enemies(ch, 5) == enemies(ch2, 5), 'hoi hai lan ra cung doi dich',
          '%s vs %s' % (enemies(ch, 5), enemies(ch2, 5)))
    check(enemies(ch, 5) != enemies(ch, 6), 'chuong khac nhau thi doi dich khac')

    print('\n=== 4. khong nhay coc duoc ===')
    for n, why in ((3, 'chuong chua mo'), (0, 'chuong 0'), (99, 'chuong khong ton tai')):
        ok = True
        try:
            rpcs['bx.fight'](ctx, L.table(chapter=n))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'tu choi %s (chuong %d)' % (why, n))

    print('\n=== 5. qua chuong moi mo chuong sau ===')
    # Doi hinh manh nhat co the, de chuong 1 chac thang.
    rpcs['bx.set_roster'](ctx, L.table(roster=L.table(
        'LvBuGod', 'MaChao', 'LvBu', 'GanNing')))
    r = rpcs['bx.fight'](ctx, L.table(chapter=1))
    result = int(r['result'])
    cleared = int(r['save']['cleared'])
    check(result in (0, 1, 2), 'ket qua la 0/1/2', result)
    if result == 0:
        check(cleared == 1, 'thang chuong 1 thi cleared = 1', cleared)
        check(bool(r['unlockedNext']), 'bao la vua mo chuong moi')
        r2 = rpcs['bx.fight'](ctx, L.table(chapter=1))
        check(int(r2['save']['cleared']) == 1,
              'danh lai chuong da qua khong mo them chuong', r2['save']['cleared'])
        # Nhung van phai co vang, khong thi ket o mot chuong la het duong go.
        if int(r2['result']) == 0:
            check(int(r2['goldGained']) > 0,
                  'thang chuong da qua van duoc it vang', r2['goldGained'])
            check(int(r2['goldGained']) < int(r['goldGained']),
                  'nhung it hon lan dau qua chuong do',
                  '%s vs %s' % (r2['goldGained'], r['goldGained']))
    else:
        check(cleared == 0, 'khong thang thi khong mo them', cleared)
        check(not bool(r['unlockedNext']), 'khong bao mo chuong moi')

    print('\n=== 5b. vang va nang cap ===')
    save = rpcs['bx.chapters'](ctx, None)['save']
    gold = int(save['gold'])
    check(gold >= 0, 'ban luu co truong vang', gold)

    # Nang cap khi chua co vang phai bi tu choi, khong duoc am tham cho qua.
    poor = L.table(user_id='u-ngheo')
    rpcs['bx.chapters'](poor, None)
    ok = True
    try:
        rpcs['bx.level_up'](poor, L.table(hero='MaChao'))
        ok = False
    except lupa.LuaError:
        pass
    check(ok, 'thieu vang thi khong nang cap duoc')

    ok = True
    try:
        rpcs['bx.level_up'](ctx, L.table(hero='KhongCoAi'))
        ok = False
    except lupa.LuaError:
        pass
    check(ok, 'tu choi tuong khong ton tai')

    if gold > 0:
        before_lv = 1
        r_lv = rpcs['bx.level_up'](ctx, L.table(hero='MaChao'))
        check(int(r_lv['level']) == before_lv + 1, 'len dung 1 cap',
              r_lv['level'])
        check(int(r_lv['save']['gold']) == gold - int(r_lv['cost']),
              'tru dung so vang', '%d - %d' % (gold, int(r_lv['cost'])))
        check(int(r_lv['save']['levels']['MaChao']) == 2, 'ban luu ghi cap moi')
    else:
        print('  (chua co vang de thu nang cap — bo qua)')

    print('\n=== 5c. len cap thi manh len that ===')
    # He so tang truong chuan hoa ve 1.0 o cap 1, nen cap 1 phai giu nguyen
    # moi con so cu, con cap cao hon thi phai hon han.
    lg = L.eval('''function(row, lv)
        local g = row.GrowthFactor or 1
        if g == 0 then g = 1 end
        local add = row.AddGrowthFactor or 0
        return (g + add * (math.max(1, math.floor(lv)) - 1)) / g
    end''')
    hero_data = L.eval('require("hero_data")')
    row = hero_data['heroes']['MaChao']
    check(abs(float(lg(row, 1)) - 1.0) < 1e-9, 'cap 1 = he so 1.0', lg(row, 1))
    check(float(lg(row, 20)) > float(lg(row, 1)), 'cap 20 manh hon cap 1',
          '%.2f -> %.2f' % (lg(row, 1), lg(row, 20)))
    # Moi tuong len cap mot kieu — do la mot canh chon doi hinh that.
    a_g = float(lg(hero_data['heroes']['MaChao'], 40))
    b_g = float(lg(hero_data['heroes']['GuYong'], 40))
    check(abs(a_g - b_g) > 0.5, 'cac tuong len cap khac nhau',
          'MaChao %.2f vs GuYong %.2f' % (a_g, b_g))

    print('\n=== 6. doi hinh: may chu kiem ten ===')
    for roster, why in (
            (('KhongCoAi', 'LiuBei', 'GanNing', 'GuYong'), 'ten khong co'),
            (('MaChao',), 'thieu nguoi')):
        ok = True
        try:
            rpcs['bx.set_roster'](ctx, L.table(roster=L.table(*roster)))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'tu choi doi hinh co %s' % why)

    print('\n=== 7. mo hinh Lua khop mo hinh Python ===')
    st = rpcs['bx.selftest'](ctx, None)
    pairs = st['pairs']
    for i in range(1, len(pairs) + 1):
        e = pairs[i]
        lua, py = float(e['winPctLua']), float(e['winPctPython'])
        # Hai bo sinh so khac nhau; so sanh trong sai so lay mau, san 3 diem.
        p = min(max(py / 100.0, 0.0), 1.0)
        sd = (max(p * (1 - p), 0.0001) / 4000.0) ** 0.5
        tol = max(3.0, 600.0 * sd)
        check(abs(lua - py) <= tol,
              '%-18s vs %-18s  Lua %6.2f%%  Python %6.2f%%  (lech %.2f, cho phep %.2f)'
              % (e['a'], e['b'], lua, py, abs(lua - py), tol))

    print('\n=== 8. tran DAN TRAN: Lua khop Python tung tran ===')
    # Khac muc 7 o cho day so TUNG TRAN chu khong so ti le tren 4000 tran.
    # Hai ban dung chung mot bo LCG nen cung seed phai ra dung cung ket qua,
    # cung so giay, cung so nguoi con song — lech mot don vi la mot ben tinh
    # sai. Day la phan bat duoc loi that ma phep so ti le bo qua.
    sys.path.insert(0, os.path.join(ROOT, 'sim'))
    import json as _json
    from battle import Rules
    import field as F

    doc = _json.load(io.open(os.path.join(ROOT, 'data_ref', 'battle_data.json'),
                             encoding='utf-8'))
    hero_by_name = {r['HeroSprite']: r for r in doc['heroes']}
    army_rows = doc['armies']
    base = doc['base']
    rules = Rules(mitigation=doc['rules']['mitigation'],
                  defence_k=doc['rules']['defenceK'],
                  anger_full=doc['rules']['angerFull'],
                  max_seconds=doc['rules']['maxSeconds'],
                  use_skills=doc['rules']['useSkills'])

    ft = rpcs['bx.fieldtest'](ctx, None)
    mine = [ft['mine'][i] for i in range(1, 5)]
    theirs = [ft['theirs'][i] for i in range(1, 5)]
    got = ft['battles']
    for i in range(1, len(got) + 1):
        e = got[i]
        seed = int(e['seed'])
        res, secs, a, b = F.lua_battle(hero_by_name, army_rows, base, rules,
                                       mine, theirs, seed, seed)
        same = (int(e['result']) == res and int(e['aliveA']) == a
                and int(e['aliveB']) == b
                and abs(float(e['seconds']) - secs) < 0.05)
        check(same,
              'seed %d: ket qua %d, con song %d-%d, %.1f giay'
              % (seed, res, a, b, secs),
              'Lua %s/%s-%s/%.2fs  vs  Python %s/%s-%s/%.2fs'
              % (e['result'], e['aliveA'], e['aliveB'], e['seconds'],
                 res, a, b, secs))

    print('\n===== dat %d, hong %d =====' % (n_pass, n_fail))
    return 0 if n_fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
