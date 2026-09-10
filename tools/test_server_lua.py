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

PRELOAD_EQUIP = """
    local src = ...
    package.preload["equipment"] = function()
        return assert(load(src, "equipment"))()
    end
"""

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

    # battle.lua require("equipment") nen phai preload TRUOC khi nap no.
    L.execute(PRELOAD_EQUIP,
              io.open(os.path.join(ROOT, 'server', 'modules', 'equipment.lua'),
                      encoding='utf-8').read())

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

    print('\n=== 7b. the tran ===')
    # The tran la he thong cua ban goc con nguyen ca so lieu: moi cap ghi ro
    # tang gi, bao nhieu, cho CHO DUNG nao. Phan kiem o day la LUAT — mo roi
    # moi dung duoc, du vang moi nang duoc, cho dung phai la 1/2/3 — chu khong
    # kiem con so buff (con so la cua ban goc, khong phai cua ta).
    fm = rpcs['bx.formations'](ctx, None)
    flist = fm['formations']
    n_form = len(flist)
    check(n_form == 12, 'co 12 the tran', n_form)
    by = {}
    for i in range(1, n_form + 1):
        by[flist[i]['name']] = flist[i]
    check('jichu' in by, 'co the tran vao cua jichu')
    check(bool(by['jichu']['owned']), 'jichu co san tu dau')
    check(bool(by['jichu']['active']), 'jichu la the tran dang dung')
    check(int(by['jichu']['unlockGold']) == 0, 'jichu mien phi mo',
          by['jichu']['unlockGold'])
    locked = [n for n in by if not by[n]['owned']]
    check(len(locked) == n_form - 1, 'nhung the tran khac deu chua mo',
          len(locked))

    # Cai manh phai dat hon cai vao cua — do la ca su can bang cua he nay.
    check(int(by['yanyue']['unlockGold']) > int(by['jichu']['unlockGold']),
          'the tran manh thi dat hon', '%s vs %s'
          % (by['yanyue']['unlockGold'], by['jichu']['unlockGold']))

    # Chua mo thi khong chon duoc, va khong co vang thi khong mo duoc.
    for fn, why in (('yanyue', 'the tran chua mo'), ('KhongCoTran', 'ten khong co')):
        ok = True
        try:
            rpcs['bx.set_formation'](ctx, L.table(formation=fn))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'tu choi chon %s' % why)

    broke = L.table(user_id='u-ngheo-tran')
    rpcs['bx.chapters'](broke, None)
    ok = True
    try:
        rpcs['bx.upgrade_formation'](broke, L.table(formation='yanyue'))
        ok = False
    except lupa.LuaError:
        pass
    check(ok, 'thieu vang thi khong mo duoc the tran')

    # Nang jichu: cap 1 phai tru dung vang va buff phai manh len that.
    # Kiem gia the tran thi phai co du vang that: danh lai chuong 1 vai lan.
    # (Gia jichu cap 1 la 100, con qua mot chuong duoc 60 — nen day cung la
    # phep thu rang duong go bang danh lai co thuc su di toi dau.)
    for _ in range(20):
        if int(rpcs['bx.chapters'](ctx, None)['save']['gold']) >= 100:
            break
        rpcs['bx.fight'](ctx, L.table(chapter=1))
    save_now = rpcs['bx.chapters'](ctx, None)['save']
    gold_now = int(save_now['gold'])
    check(gold_now >= 100, 'danh lai du lau thi mua duoc the tran', gold_now)
    b0 = rpcs['bx.formations'](ctx, None)
    hp0 = 0
    for i in range(1, n_form + 1):
        if b0['formations'][i]['name'] == 'jichu':
            hp0 = float(b0['formations'][i]['buffs']['hp'] or 0)
    if gold_now > 0:
        r_up = rpcs['bx.upgrade_formation'](ctx, L.table(formation='jichu'))
        check(int(r_up['level']) == 1, 'jichu len cap 1', r_up['level'])
        check(int(r_up['save']['gold']) == gold_now - int(r_up['cost']),
              'tru dung so vang', '%d - %d' % (gold_now, int(r_up['cost'])))
        b1 = rpcs['bx.formations'](ctx, None)
        hp1 = 0
        for i in range(1, n_form + 1):
            if b1['formations'][i]['name'] == 'jichu':
                hp1 = float(b1['formations'][i]['buffs']['hp'] or 0)
        check(hp1 > hp0, 'len cap thi buff manh len that',
              '%s -> %s' % (hp0, hp1))
    else:
        print('  (chua co vang de nang the tran — bo qua)')

    # Cho dung: 1/2/3 thi nhan, ngoai khoang thi tu choi.
    r_pl = rpcs['bx.set_placement'](ctx, L.table(placement=L.table(3, 2, 1, 1)))
    check([r_pl['placement'][i] for i in range(1, 5)] == [3, 2, 1, 1],
          'nhan cho dung hop le')
    saved = rpcs['bx.chapters'](ctx, None)['save']
    check([saved['placement'][i] for i in range(1, 5)] == [3, 2, 1, 1],
          'cho dung song sot trong ban luu')
    for bad, why in (((0, 1, 1, 1), 'cho dung 0'), ((1, 1, 1, 9), 'cho dung 9')):
        ok = True
        try:
            rpcs['bx.set_placement'](ctx, L.table(placement=L.table(*bad)))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'tu choi %s' % why)

    # Va tran van danh duoc sau khi doi the tran lan cho dung.
    r_f = rpcs['bx.fight'](ctx, L.table(chapter=1))
    check(int(r_f['result']) in (0, 1, 2), 'van danh duoc tran sau khi doi',
          r_f['result'])

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

    # Nam tran nua voi trang bi tren doi ta. Muc nay do cho NOI: buff trang bi
    # co vao tran dung cach khong, va hai ban co gop buff giong nhau khong.
    eq_got = ft['equipBattles']
    eq_buffs = {}
    for name in ft['equipBuffs']:
        eq_buffs[str(name)] = dict(ft['equipBuffs'][name])
    check(len(eq_buffs) == 4 and all(b for b in eq_buffs.values()),
          'may chu gui ve buff trang bi cua ca 4 tuong', list(eq_buffs))
    for i in range(1, len(eq_got) + 1):
        e = eq_got[i]
        seed = int(e['seed'])
        res, secs, a, b = F.lua_battle(hero_by_name, army_rows, base, rules,
                                       mine, theirs, seed, seed,
                                       equips=eq_buffs)
        same = (int(e['result']) == res and int(e['aliveA']) == a
                and int(e['aliveB']) == b
                and abs(float(e['seconds']) - secs) < 0.05)
        check(same,
              'co trang bi, seed %d: ket qua %d, con song %d-%d, %.1f giay'
              % (seed, res, a, b, secs),
              'Lua %s/%s-%s/%.2fs  vs  Python %s/%s-%s/%.2fs'
              % (e['result'], e['aliveA'], e['aliveB'], e['seconds'],
                 res, a, b, secs))

    print('\n=== 9. TRANG BI: Lua khop Python tung ca ===')
    # Cho nay khong co ngau nhien nen doi hoi chat hon muc 8: hai ban cung
    # float64, cung thu tu phep tinh, phai ra dung mot so. Nguong 1e-9 chi de
    # bo qua sai so lam tron.
    import equipment as EQ

    # Module luat trang bi da preload o dau main() — battle.lua require no.
    LE = L.eval('(require("equipment"))')

    check(abs(float(LE.INTENSIFY_STEP) - EQ.INTENSIFY_STEP) < 1e-15,
          'buoc cuong hoa khop', '%r vs %r' % (LE.INTENSIFY_STEP, EQ.INTENSIFY_STEP))
    check(int(LE.APPEND_UNLOCK_LEVEL) == EQ.APPEND_UNLOCK_LEVEL,
          'cap mo thuoc tinh phu khop')
    check(int(LE.RECAST_ITEM_ID) == EQ.RECAST_ITEM_ID, 'id da tay luyen khop')
    w_bad = [t for t, v in EQ.CAPACITY_WEIGHT.items()
             if abs(float(LE.weight_of(t)) - v) > 1e-12]
    check(not w_bad, '%d trong so luc chien khop' % len(EQ.CAPACITY_WEIGHT), w_bad)

    def lclose(a, b):
        return abs(a - b) <= 1e-9 * max(1.0, abs(a), abs(b))

    cases = EQ.reference_cases()
    fields = ('increment', 'propVal', 'total', 'cost', 'costTo',
              'qualityRange', 'capacity', 'capacityOrig',
              'refinePercent', 'refineCost', 'mainValue',
              'jobOf', 'categoryOf', 'mainFormula',
              'appendValue', 'appendScore', 'appendTotal')
    bad = dict((f, []) for f in fields)
    bad_stats = []
    for c in cases:
        # Dung DUNG cach ban Python dung: make_append (giu ca `base`), vi luc
        # chien cham theo `base` chu khong theo gia tri.
        appends = L.table(
            LE.make_append(EQ.CRITICAL_STRIKE, c['appendBase'], 2, c['base']),
            LE.make_append(EQ.HP_LIMIT, c['appendBase'], 2, c['base']))
        e = LE.make(c['part'], c['prop'], c['base'], L.table(
            level=c['level'], intensify=c['intensify'], quality=2,
            refine=c['refine'], appends=appends))
        got = {
            'increment': LE.intensify_increment(c['intensify'], c['base']),
            'propVal': LE.intensify_property_val(c['base'], c['prop']),
            'total': LE.intensify_total(c['intensify'], c['base']),
            'cost': LE.intensify_cost(max(1, c['intensify'])),
            'costTo': LE.cost_to_level(e, c['intensify'] + 5),
            'qualityRange': LE.quality_range(c['base'], 10.0, 2.0),
            'capacity': LE.capacity(e),
            'capacityOrig': LE.capacity_as_original(e),
            'refinePercent': LE.refine_percent(c['refine']),
            'jobOf': LE.equip_job(c['equipType']),
            'categoryOf': LE.equip_category(c['equipType']),
            'mainFormula': LE.main_property_val(
                LE.main_property_type(c['equipType']), c['base'], 2,
                LE.equip_job(c['equipType'])),
            'refineCost': LE.refine_cost_next(e),
            'mainValue': LE.main_value(e),
            'appendValue': LE.append_value(c['appendBase'], EQ.CRITICAL_STRIKE,
                                           2, c['base']),
            'appendScore': LE.append_score(c['appendBase']),
            'appendTotal': LE.append_score_total(e),
        }
        for f in fields:
            if not lclose(float(got[f]), c[f]):
                bad[f].append('loai %d goc %.1f cap %d +%d tinh luyen %d o %d: '
                              'Lua %.10f vs Python %.10f'
                              % (c['prop'], c['base'], c['level'],
                                 c['intensify'], c['refine'], c['part'],
                                 got[f], c[f]))
        st = dict(LE.stats(e))
        want = dict((int(k), v) for k, v in c['stats'].items())
        if set(st) != set(want) or any(not lclose(float(st[k]), want[k]) for k in want):
            bad_stats.append('loai %d +%d: %s vs %s'
                             % (c['prop'], c['intensify'], st, want))

    for f in fields:
        check(not bad[f], '%-13s khop ca %d ca' % (f, len(cases)),
              '%d ca lech; %s' % (len(bad[f]), bad[f][0] if bad[f] else ''))
    check(not bad_stats, '%-13s khop ca %d ca' % ('stats', len(cases)),
          '%d ca lech; %s' % (len(bad_stats), bad_stats[0] if bad_stats else ''))

    print('\n=== 10. TRANG BI: ban luu va RPC ===')
    u = L.table(user_id='u-trangbi')
    e0 = rpcs['bx.equipment'](u, None)
    check(len(dict(e0['equipment'])) == 0, 'nguoi choi moi chua co mon nao')
    check(float(e0['capacity']) == 0.0, 'luc chien trang bi bang 0', e0['capacity'])

    rpcs['bx.set_roster'](u, L.table(roster=L.table(
        'LvBuGod', 'MaChao', 'LvBu', 'GanNing')))
    drop = None
    for _ in range(80):
        rr = rpcs['bx.fight'](u, L.table(chapter=1))
        d = rr['drop']
        if d is not None and bool(d['kept']):
            drop = d
            break
    check(drop is not None, 'danh du lau thi co do roi ra')
    if drop is None:
        print('  (khong co do roi — bo qua phan con lai cua muc 10)')
    else:
        hero, part = str(drop['hero']), int(drop['part'])
        check(1 <= part <= 6, 'o hop le', part)
        check(float(drop['capacity']) > 0, 'mon roi ra co luc chien',
              drop['capacity'])

        e1 = rpcs['bx.equipment'](u, None)
        owned = dict(e1['equipment'])
        check(hero in owned, 'mon vua roi nam trong ban luu', list(owned))
        check(float(e1['capacity']) > 0.0, 'luc chien tong > 0', e1['capacity'])
        # Buff phai la thu mo hinh chien dau hieu, khong phai ten chi so goc.
        bf = dict(dict(e1['buffs'])[hero])
        check(bf and all(k in ('hp', 'ap', 'dp', 'crit') for k in bf),
              'buff dung khoa cua mo hinh chien dau', list(bf))

        print('\n=== 10b. cuong hoa: may chu tinh gia va tru vang ===')
        item = None
        for it in owned[hero].values():
            if int(it['part']) == part:
                item = it
        check(item is not None, 'doc lai duoc dung mon do')
        cost = int(item['nextCost'])
        check(cost == 25, 'gia cuong hoa cap dau la 25', cost)

        gold = int(e1['gold'])
        cap_before = float(item['capacity'])
        r_in = rpcs['bx.intensify'](u, L.table(hero=hero, part=part))
        check(int(r_in['intensify']) == 1, 'len cuong hoa cap 1',
              r_in['intensify'])
        check(int(r_in['save']['gold']) == gold - cost, 'tru dung so vang',
              '%d - %d vs %s' % (gold, cost, r_in['save']['gold']))
        check(float(r_in['capacity']) > cap_before, 'luc chien tang len that',
              '%.3f -> %.3f' % (cap_before, float(r_in['capacity'])))
        check(int(r_in['nextCost']) > cost, 'cap sau dat hon cap truoc',
              '%d -> %s' % (cost, r_in['nextCost']))

        # Cuong hoa xong thi tran sau phai thay chi so moi.
        e2 = rpcs['bx.equipment'](u, None)
        check(float(e2['capacity']) > float(e1['capacity']),
              'ban luu giu cap cuong hoa moi',
              '%s -> %s' % (e1['capacity'], e2['capacity']))

        print('\n=== 10c. tu choi cai phai tu choi ===')
        for args, why in (
                (dict(hero='KhongCoAi', part=1), 'tuong khong ton tai'),
                (dict(hero=hero, part=0), 'o so 0'),
                (dict(hero=hero, part=99), 'o so 99')):
            ok = True
            try:
                rpcs['bx.intensify'](u, L.table(**args))
                ok = False
            except lupa.LuaError:
                pass
            check(ok, 'tu choi %s' % why)

        # O trong thi khong cuong hoa duoc.
        empty_part = None
        for pp in range(1, 7):
            if not any(int(it['part']) == pp for it in owned[hero].values()):
                empty_part = pp
                break
        if empty_part is not None:
            ok = True
            try:
                rpcs['bx.intensify'](u, L.table(hero=hero, part=empty_part))
                ok = False
            except lupa.LuaError:
                pass
            check(ok, 'tu choi cuong hoa o con trong')

        # Khong co vang thi khong cuong hoa duoc.
        poor = L.table(user_id='u-ngheo-trangbi')
        rpcs['bx.chapters'](poor, None)
        ok = True
        try:
            rpcs['bx.intensify'](poor, L.table(hero=hero, part=part))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'thieu vang / chua co do thi khong cuong hoa duoc')
        print('\n=== 10e. tinh luyen: ton tinh hoa, khong ton vang ===')
        # Tinh hoa CHI den tu do THUA: mon roi vao mot o DA CO do, roi thua
        # cuoc so sanh. Luot roi dau tien thi 24 o (4 tuong x 6 o) con trong
        # het nen khong the co tinh hoa — phai danh tiep cho den khi trung o.
        conc = 0
        for _ in range(200):
            eq_now = rpcs['bx.equipment'](u, None)
            conc = int(eq_now['concentrate'])
            if conc > 0:
                break
            rpcs['bx.fight'](u, L.table(chapter=1))
        eq_now = rpcs['bx.equipment'](u, None)
        conc = int(eq_now['concentrate'])
        check(conc > 0, 'danh du lau thi do thua phan giai ra tinh hoa', conc)
        check(int(eq_now['maxRefine']) == 5, 'co 5 cap tinh luyen',
              eq_now['maxRefine'])

        owned2 = dict(eq_now['equipment'])
        item2 = None
        for it in owned2[hero].values():
            if int(it['part']) == part:
                item2 = it
        check(int(item2['refine']) == 0, 'mon moi roi thi chua tinh luyen')
        want_cost = 40 if part == 1 else 30
        check(int(item2['nextRefineCost']) == want_cost,
              'gia tinh luyen cap 1 dung bang goc (%d cho o %d)' % (want_cost, part),
              item2['nextRefineCost'])

        # Danh tiep cho du tinh hoa ma tinh luyen that — day moi la phep
        # quan trong nhat cua muc nay, khong duoc de no bi bo qua.
        for _ in range(600):
            if conc >= want_cost:
                break
            rpcs['bx.fight'](u, L.table(chapter=1))
            conc = int(rpcs['bx.equipment'](u, None)['concentrate'])
        eq_now = rpcs['bx.equipment'](u, None)
        conc = int(eq_now['concentrate'])
        for it in dict(eq_now['equipment'])[hero].values():
            if int(it['part']) == part:
                item2 = it
        gold_before = int(eq_now['gold'])
        if conc >= want_cost:
            cap_b = float(item2['capacity'])
            r_rf = rpcs['bx.refine'](u, L.table(hero=hero, part=part))
            check(int(r_rf['refine']) == 1, 'len tinh luyen cap 1', r_rf['refine'])
            check(float(r_rf['refinePercent']) == 5.0, 'cap 1 cong 5%',
                  r_rf['refinePercent'])
            check(int(r_rf['concentrate']) == conc - want_cost,
                  'tru dung so tinh hoa',
                  '%d - %d vs %s' % (conc, want_cost, r_rf['concentrate']))
            check(int(r_rf['save']['gold']) == gold_before,
                  'KHONG dong den vang', r_rf['save']['gold'])
            check(float(r_rf['capacity']) > cap_b, 'luc chien tang len that',
                  '%.2f -> %.2f' % (cap_b, float(r_rf['capacity'])))
            check(int(r_rf['nextRefineCost']) == want_cost * 2,
                  'cap sau dat gap doi', r_rf['nextRefineCost'])
        else:
            print('  (chua du tinh hoa de thu tinh luyen — bo qua)')

        for args, why in (
                (dict(hero='KhongCoAi', part=1), 'tuong khong ton tai'),
                (dict(hero=hero, part=0), 'o so 0')):
            ok = True
            try:
                rpcs['bx.refine'](u, L.table(**args))
                ok = False
            except lupa.LuaError:
                pass
            check(ok, 'tu choi tinh luyen: %s' % why)

        broke2 = L.table(user_id='u-ngheo-tinhhoa')
        rpcs['bx.chapters'](broke2, None)
        ok = True
        try:
            rpcs['bx.refine'](broke2, L.table(hero=hero, part=part))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'khong co do / khong co tinh hoa thi khong tinh luyen duoc')

        print('\n=== 10f. ghep do: len cap, ton vang, doi cap tuong ===')
        eq3 = rpcs['bx.equipment'](u, None)
        item3 = None
        for it in dict(eq3['equipment'])[hero].values():
            if int(it['part']) == part:
                item3 = it
        check(int(item3['equipType']) > 0, 'mon do co LOAI cua ban goc',
              item3['equipType'])
        # Loai = o * 10 + nghe, nen nghe phai khop nghe cua chinh tuong do.
        hero_row = hero_data['heroes'][hero]
        check(int(item3['equipType']) % 10 == int(hero_row['HeroJobType']),
              'loai do khop nghe cua tuong',
              '%s vs %s' % (item3['equipType'], hero_row['HeroJobType']))

        syn = item3['synthesis']
        check(syn is not None, 'co thong tin ghep buoc ke tiep')
        if syn is not None:
            need_lv = int(syn['needHeroLevel'])
            gold_now = int(eq3['gold'])
            cost = int(syn['gold'])
            check(int(syn['nextLevel']) == int(item3['level']) + 1,
                  'buoc ke la cap +1')
            check(cost > 0, 'co gia vang', cost)
            check(len(list(syn['materials'])) > 0,
                  'gui ca nguyen lieu cua ban goc de client con thay')

            if not bool(syn['ready']):
                # Chua du cap tuong: phai TU CHOI, va noi ro can cap bao nhieu.
                ok = True
                try:
                    rpcs['bx.synthesize'](u, L.table(hero=hero, part=part))
                    ok = False
                except lupa.LuaError:
                    pass
                check(ok, 'chua du cap tuong thi tu choi ghep (can cap %d)' % need_lv)
                check('cap' in str(syn['reason']), 'noi ro ly do', syn['reason'])
            else:
                lv_b = int(item3['level'])
                cap_b = float(item3['capacity'])
                main_b = float(item3['mainValue'])
                if gold_now >= cost:
                    r_sy = rpcs['bx.synthesize'](u, L.table(hero=hero, part=part))
                    check(int(r_sy['level']) == lv_b + 1, 'len dung mot cap',
                          r_sy['level'])
                    check(int(r_sy['save']['gold']) == gold_now - cost,
                          'tru dung so vang')
                    check(float(r_sy['mainValue']) > main_b,
                          'chi so chinh tinh lai theo cap moi, manh hon',
                          '%.2f -> %.2f' % (main_b, float(r_sy['mainValue'])))
                    check(float(r_sy['capacity']) > cap_b, 'luc chien tang')
                else:
                    print('  (chua du vang de ghep — bo qua)')

        for args, why in (
                (dict(hero='KhongCoAi', part=1), 'tuong khong ton tai'),
                (dict(hero=hero, part=0), 'o so 0')):
            ok = True
            try:
                rpcs['bx.synthesize'](u, L.table(**args))
                ok = False
            except lupa.LuaError:
                pass
            check(ok, 'tu choi ghep: %s' % why)

        # Ghep THAT. Cay du cap tuong bang cach danh vai tram tran thi lau va
        # bap benh, nen dung thang mot ban luu: tuong cap 40, mot mon vu khi
        # cap 1 loai 1 (chien binh), va thua vang. Day la duong ma nguoi choi
        # se di, chi la ta dat san diem xuat phat.
        rich = 'u-ghep-do'
        env['store'][rich + '/player/save'] = L.table(
            version=7, gold=1000000, concentrate=0,
            levels=L.table(MaChao=40),
            roster=L.table('MaChao', 'LvBu', 'GanNing', 'GuYong'),
            equipment=L.table(MaChao=L.table(
                L.table(part=1, level=1, intensify=3, quality=2, refine=1,
                        equipType=1, main=L.table(type=20, value=22.5)))))
        rc = L.table(user_id=rich)
        eq4 = rpcs['bx.equipment'](rc, None)
        it4 = list(dict(eq4['equipment'])['MaChao'].values())[0]
        syn4 = it4['synthesis']
        check(bool(syn4['ready']), 'tuong cap 40 thi ghep duoc cap 2',
              syn4['reason'])
        check(int(syn4['gold']) == 110, 'gia ghep cap 2 dung bang goc',
              syn4['gold'])
        lv_b = int(it4['level'])
        main_b = float(it4['mainValue'])
        cap_b = float(it4['capacity'])
        gold_b = int(eq4['gold'])
        r4 = rpcs['bx.synthesize'](rc, L.table(hero='MaChao', part=1))
        check(int(r4['level']) == lv_b + 1, 'len dung mot cap', r4['level'])
        check(int(r4['save']['gold']) == gold_b - 110, 'tru dung 110 vang',
              r4['save']['gold'])
        check(float(r4['mainValue']) > main_b,
              'chi so chinh tinh lai theo cap moi',
              '%.2f -> %.2f' % (main_b, float(r4['mainValue'])))
        check(float(r4['capacity']) > cap_b, 'luc chien tang theo')
        # Cuong hoa va tinh luyen KHONG mat khi ghep — ca hai nhan vao chi so
        # chinh moi, do la ca cai loi cua viec ghep.
        check(int(r4['item']['intensify']) == 3, 'giu nguyen cap cuong hoa',
              r4['item']['intensify'])
        check(int(r4['item']['refine']) == 1, 'giu nguyen cap tinh luyen',
              r4['item']['refine'])

        # Thieu vang thi tu choi, du du cap tuong.
        env['store']['u-ngheo-ghep/player/save'] = L.table(
            version=7, gold=5, levels=L.table(MaChao=40),
            equipment=L.table(MaChao=L.table(
                L.table(part=1, level=1, intensify=0, quality=2, refine=0,
                        equipType=1, main=L.table(type=20, value=22.5)))))
        ok = True
        try:
            rpcs['bx.synthesize'](L.table(user_id='u-ngheo-ghep'),
                                  L.table(hero='MaChao', part=1))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'du cap tuong ma thieu vang thi van tu choi')

        print('\n=== 10g. do chuyen thuoc ===')
        # ZhaoYun (HeroID 13) nam trong danh sach 22 tuong co do rieng.
        exc_u = 'u-chuyen-thuoc'
        def mk_save(refine, exclusive=False, purify=0):
            return L.table(
                version=8, gold=100000, concentrate=100000,
                levels=L.table(ZhaoYun=40),
                roster=L.table('ZhaoYun', 'MaChao', 'LvBu', 'GanNing'),
                equipment=L.table(ZhaoYun=L.table(
                    L.table(part=4, level=3, intensify=0, quality=2,
                            refine=refine, equipType=42, exclusive=exclusive,
                            purify=purify,
                            main=L.table(type=1, value=100.0)))))

        # Chua tay du bac 5 thi khong ren duoc.
        env['store'][exc_u + '/player/save'] = mk_save(2)
        ec = L.table(user_id=exc_u)
        e5 = rpcs['bx.equipment'](ec, None)
        it5 = list(dict(e5['equipment'])['ZhaoYun'].values())[0]
        info5 = it5['exclusiveReady']
        check(info5 is not None and not bool(info5['ready']),
              'tay bac 2 thi chua ren duoc')
        check(int(info5['needRefine']) == 5, 'bang goc doi tay bac 5',
              info5['needRefine'])
        check(len(list(info5['materials'])) > 0, 'co danh sach nguyen lieu')
        ok = True
        try:
            rpcs['bx.forge_exclusive'](ec, L.table(hero='ZhaoYun', part=4))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'may chu tu choi ren khi chua du bac tay')

        # Tuong KHONG co trong danh sach thi khong bao gio ren duoc.
        env['store']['u-khong-chuyen/player/save'] = L.table(
            version=8, gold=100000, concentrate=100000,
            levels=L.table(GuYong=40),
            equipment=L.table(GuYong=L.table(
                L.table(part=4, level=3, intensify=0, quality=2, refine=5,
                        equipType=42, main=L.table(type=1, value=100.0)))))
        e6 = rpcs['bx.equipment'](L.table(user_id='u-khong-chuyen'), None)
        it6 = list(dict(e6['equipment'])['GuYong'].values())[0]
        check(not bool(it6['exclusiveReady']['ready']),
              'tuong ngoai danh sach thi du tay bac 5 cung khong ren duoc')

        # Du dieu kien: ren that.
        env['store'][exc_u + '/player/save'] = mk_save(5)
        e7 = rpcs['bx.equipment'](ec, None)
        it7 = list(dict(e7['equipment'])['ZhaoYun'].values())[0]
        check(bool(it7['exclusiveReady']['ready']), 'tay bac 5 thi ren duoc')
        cap_b = float(it7['capacity'])
        r7 = rpcs['bx.forge_exclusive'](ec, L.table(hero='ZhaoYun', part=4))
        check(bool(r7['exclusive']), 'mon do thanh do chuyen thuoc')
        check(float(r7['purifyPercent']) == 25.0,
              'bac 0 cua duong tay rieng da la +25%', r7['purifyPercent'])
        # Luc chien KHONG doi ngay luc ren, va do la dung thiet ke: duong tay
        # rieng bat dau o dung +25% ma duong thuong ket thuc. Cai duoc la ky
        # nang mon do cho, va tran nha tu +25% len +125%.
        check(abs(float(r7['capacity']) - cap_b) < 1e-9,
              'ren xong luc chien giu nguyen (bac 0 = dung +25% cua tay bac 5)',
              '%.2f -> %.2f' % (cap_b, float(r7['capacity'])))
        # O 4 (day chuyen) cho ky nang chi mang.
        check(str(r7['skill']) == 'ZhuanShuXiangLian', 'cho dung ky nang cua o',
              r7['skill'])
        bf7 = dict(r7['buffs'])
        check(abs(float(bf7.get('crit', 0)) - 0.10) < 1e-9,
              'ky nang do quy ra buff chi mang +10%', bf7)
        check(int(r7['nextPurifyCost']) == 50,
              'gia len bac 1 cua o nay dung bang goc', r7['nextPurifyCost'])

        # Ren hai lan thi tu choi.
        ok = True
        try:
            rpcs['bx.forge_exclusive'](ec, L.table(hero='ZhaoYun', part=4))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'da la do chuyen thuoc thi khong ren lai')

        # Tay tiep: gio di duong 21 bac chu khong phai 5.
        r8 = rpcs['bx.refine'](ec, L.table(hero='ZhaoYun', part=4))
        check(int(r8['purify']) == 1, 'len bac tay 1', r8['purify'])
        check(float(r8['refinePercent']) == 30.0, 'bac 1 la +30%',
              r8['refinePercent'])
        check(int(r8['nextPurifyCost']) == 100, 'gia bac 2', r8['nextPurifyCost'])

        # Len het 20 bac: phai toi +125% roi dung lai.
        for _ in range(19):
            r8 = rpcs['bx.refine'](ec, L.table(hero='ZhaoYun', part=4))
        check(int(r8['purify']) == 20, 'len duoc toi bac 20', r8['purify'])
        check(float(r8['refinePercent']) == 125.0, 'bac 20 la +125%',
              r8['refinePercent'])
        ok = True
        try:
            rpcs['bx.refine'](ec, L.table(hero='ZhaoYun', part=4))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'het bac thi dung lai')

        print('\n=== 10h. tay luyen ===')
        rec_u = 'u-tay-luyen'
        # Du vang cho ca 30 lan tay o duoi: 10 000 mot lan.
        env['store'][rec_u + '/player/save'] = L.table(
            version=8, gold=10000000, concentrate=0,
            levels=L.table(MaChao=40),
            equipment=L.table(MaChao=L.table(
                L.table(part=1, level=5, intensify=0, quality=2, refine=0,
                        equipType=1,
                        main=L.table(type=20, value=100.0),
                        appends=L.table(
                            L.table(type=1, value=68.0, base=0.85),
                            L.table(type=16, value=0.17, base=0.85))))))
        rec = L.table(user_id=rec_u)
        e9 = rpcs['bx.equipment'](rec, None)
        it9 = list(dict(e9['equipment'])['MaChao'].values())[0]
        check(int(it9['appendScore']) == 20,
              'hai thuoc tinh base 0.85 -> 10 + 10 = 20 diem', it9['appendScore'])
        check(int(it9['recastCost']) == 10000, 'gia tay luyen 10 000 vang',
              it9['recastCost'])

        gold9 = int(e9['gold'])
        r9 = rpcs['bx.recast'](rec, L.table(hero='MaChao', part=1))
        check(int(r9['save']['gold']) == gold9 - 10000, 'tru dung 10 000 vang',
              r9['save']['gold'])
        after = [r9['after'][i] for i in range(1, len(r9['after']) + 1)]
        check(len(after) == 2, 'van du hai dong thuoc tinh phu', len(after))
        check([int(a['type']) for a in after] == [1, 16],
              'loai chi so GIU NGUYEN, chi con so doi',
              [int(a['type']) for a in after])
        check(all(0.8 <= float(a['base']) <= 1.3 for a in after),
              'base moi nam trong dai 0.8-1.3',
              [float(a['base']) for a in after])
        # Gia tri phai khop dung cong thuc theo base moi.
        lc9 = float(LE.level_coefficient(env['store'] is not None
                    and L.eval('(require("hero_data"))')['equipSynthesis'], 1, 5))
        bad9 = [a for a in after
                if abs(float(a['value'])
                       - float(LE.append_value(float(a['base']), int(a['type']),
                                               2, lc9))) > 1e-9]
        check(not bad9, 'gia tri tinh lai dung theo base moi', bad9)

        # Tay nhieu lan thi diem len xuong — do la ca canh bac.
        seen_scores = set()
        for _ in range(30):
            rpcs['bx.equipment'](rec, None)
            rr = rpcs['bx.recast'](rec, L.table(hero='MaChao', part=1))
            seen_scores.add(int(rr['scoreAfter']))
        check(len(seen_scores) > 1, 'tay lai cho diem khac nhau',
              sorted(seen_scores))

        # Chua toi cap 4 thi khong co thuoc tinh phu ma tay.
        env['store']['u-tay-som/player/save'] = L.table(
            version=8, gold=100000, levels=L.table(MaChao=40),
            equipment=L.table(MaChao=L.table(
                L.table(part=1, level=2, intensify=0, quality=2, refine=0,
                        equipType=1, main=L.table(type=20, value=100.0)))))
        ok = True
        try:
            rpcs['bx.recast'](L.table(user_id='u-tay-som'),
                              L.table(hero='MaChao', part=1))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'chua mo thuoc tinh phu thi khong tay duoc')

        # Thieu vang thi tu choi.
        env['store']['u-ngheo-tay/player/save'] = L.table(
            version=8, gold=100, levels=L.table(MaChao=40),
            equipment=L.table(MaChao=L.table(
                L.table(part=1, level=5, intensify=0, quality=2, refine=0,
                        equipType=1, main=L.table(type=20, value=100.0),
                        appends=L.table(
                            L.table(type=1, value=68.0, base=0.85))))))
        ok = True
        try:
            rpcs['bx.recast'](L.table(user_id='u-ngheo-tay'),
                              L.table(hero='MaChao', part=1))
            ok = False
        except lupa.LuaError:
            pass
        check(ok, 'thieu vang thi khong tay duoc')


    print('\n=== 10d. ban luu ban thi bo mon do, khong sua cho lanh ===')
    # Ban luu la du lieu ben ngoai. Nhet vao vai mon vo ly roi doc lai.
    bad_user = 'u-banluu-ban'
    env['store'][bad_user + '/player/save'] = L.table(
        version=5, gold=1000,
        equipment=L.table(
            MaChao=L.table(
                L.table(part=1, level=1, intensify=0, quality=1,
                        main=L.table(type=20, value=10.0)),        # hop le
                L.table(part=1, level=1, intensify=0, quality=1,
                        main=L.table(type=20, value=99.0)),        # trung o
                L.table(part=99, level=1, intensify=0, quality=1,
                        main=L.table(type=20, value=10.0)),        # o khong co
                L.table(part=2, level=1, intensify=0, quality=1,
                        main=L.table(type=777, value=10.0)),       # loai la
                L.table(part=3, level=1, intensify=999999, quality=1,
                        main=L.table(type=20, value=10.0)),        # cuong hoa vo ly
                L.table(part=4, level=1, intensify=0, quality=1,
                        main=L.table(type=20, value=-5.0))),       # gia tri am
            KhongCoAi=L.table(
                L.table(part=1, level=1, intensify=0, quality=1,
                        main=L.table(type=20, value=10.0)))))
    eb = rpcs['bx.equipment'](L.table(user_id=bad_user), None)
    got = dict(eb['equipment'])
    check('KhongCoAi' not in got, 'bo trang bi cua tuong khong ton tai',
          list(got))
    items = list(dict(got.get('MaChao', L.table())).values()) if 'MaChao' in got else []
    parts = sorted(int(it['part']) for it in items)
    check(parts == [1, 3], 'chi giu mon hop le, moi o mot mon', parts)
    kept = dict((int(it['part']), it) for it in items)
    check(float(kept[1]['main']['value']) == 10.0,
          'o trung thi giu mon dau, khong phai mon sau',
          kept[1]['main']['value'])
    check(int(kept[3]['intensify']) == 200,
          'cuong hoa vo ly bi keo ve tran 200', kept[3]['intensify'])

    print('\n===== dat %d, hong %d =====' % (n_pass, n_fail))
    return 0 if n_fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
