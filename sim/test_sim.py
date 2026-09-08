# -*- coding: utf-8 -*-
"""Test cho bo mo phong.

Mo phong khong co "dap an dung" de doi chieu — cong thuc la tu dat. Nen test o
day khong kiem tra CON SO, ma kiem tra nhung tinh chat ma bat ky mo hinh nao
cung phai co, neu khong thi ket luan rut ra tu no vo nghia:

    - chay lai cung seed phai ra cung ket qua
    - tuong tu danh voi chinh no khong duoc thien vi ben nao
    - manh hon moi mat thi phai thang
    - so tran thang + thua + hoa phai bang so tran da chay
    - sat thuong khong bao gio am

    python test_sim.py
"""
import os, sys, copy, random

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from tables import Heroes, Armies, TableError, DEFAULT_CONFIG
from battle import Rules, Fighter, duel, match, round_robin

nPass = nFail = 0


def check(cond, desc, detail=None):
    global nPass, nFail
    if cond:
        nPass += 1
        print('  dat   %s' % desc)
    else:
        nFail += 1
        print('  HONG  %s%s' % (desc, '' if detail is None else '  -> %s' % (detail,)))


cfg = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CONFIG
try:
    heroes = Heroes(cfg)
    armies = Armies(cfg)
except TableError as e:
    sys.exit(str(e))

print('=== 1. doc bang ===')
check(len(heroes) == 92, 'doc du 92 tuong', len(heroes))
check(len(armies) == 91, 'doc du 91 quan chung', len(armies))
for k in ('HpBase', 'MinApBase', 'MaxApBase', 'DpBase', 'AttackInterval'):
    check(k in heroes.base, 'khoi chi so goc co %s' % k)
check(heroes.spread('QualityFactor') == {1: 92},
      'QualityFactor van bang 1 o ca 92 tuong (nen mo hinh bo qua no)',
      heroes.spread('QualityFactor'))
check(all(r['TypeFactor'] == r['HeroJobType'] for r in heroes.rows),
      'TypeFactor trung khit HeroJobType tren ca 92 tuong')

print('\n=== 2. moi cot *Rates deu la cong them, khong phai nhan ===')
# 72/91 quan chung co InjuryRates = 0. Neu doc la he so nhan thi chung gay 0
# sat thuong — vo ly. Day la can cu cho cach doc "x (1 + rate)" trong battle.py.
zero = sum(1 for r in armies.rows if r['InjuryRates'] == 0)
check(zero > 0, 'co quan chung InjuryRates = 0 (%d/%d) nen khong the la he so nhan'
      % (zero, len(armies)))
check(min(r['InjuryRates'] for r in heroes.rows) > 0,
      'khong tuong nao co InjuryRates = 0')

print('\n=== 3. chay lai cung seed ra cung ket qua ===')
a, b = heroes.get('MaChao'), heroes.get('LiuBei')
r1 = match(a, b, heroes.base, 200, seed=7)
r2 = match(a, b, heroes.base, 200, seed=7)
check(r1 == r2, 'cung seed -> cung ket qua', '%s vs %s' % (r1, r2))
r3 = match(a, b, heroes.base, 200, seed=8)
check(r1 != r3 or r1[0] in (0, 200), 'doi seed thi ket qua doi (tru khi mot chieu tuyet doi)')

print('\n=== 4. tong so tran khop ===')
w, l, d = match(a, b, heroes.base, 137, seed=3)
check(w + l + d == 137, 'thang + thua + hoa = so tran', (w, l, d))

print('\n=== 5. tu danh voi chinh minh khong thien vi ben nao ===')
w, l, d = match(a, copy.deepcopy(a), heroes.base, 400, seed=11)
check(abs(w - l) <= max(20, 0.15 * (w + l)) or (w + l) == 0,
      'tuong danh voi chinh no: thang va thua xap xi nhau',
      'thang %d, thua %d, hoa %d' % (w, l, d))

print('\n=== 6. manh hon moi mat thi phai thang ===')
strong = dict(a)
strong['HeroSprite'] = 'MANH'
strong['AttackCapability'] = 8
strong['Viability'] = 8
strong['InjuryRates'] = 3.0
weak = dict(a)
weak['HeroSprite'] = 'YEU'
weak['AttackCapability'] = 2
weak['Viability'] = 2
weak['InjuryRates'] = 0.4
w, l, d = match(strong, weak, heroes.base, 200, seed=5)
check(w == 200, 'manh hon moi mat thang 200/200', (w, l, d))
w2, l2, d2 = match(weak, strong, heroes.base, 200, seed=5)
check(l2 == 200, 'doi cho van thua 200/200 — khong co loi thien vi ben trai', (w2, l2, d2))

print('\n=== 7. sat thuong khong bao gio am hay bang 0 ===')
rules = Rules()
fa = Fighter(weak, heroes.base, rules)     # cong thap nhat
fb = Fighter(strong, heroes.base, rules)   # thu cao nhat
rng = random.Random(0)
lo = min(fa.strike(fb, rng, rules)[0] for _ in range(500))
check(lo >= 1.0, 'don yeu nhat vao muc thu cao nhat van >= 1', lo)

print('\n=== 8. moi bien the cong thuc deu chay duoc ===')
rows = [heroes.get(n) for n in ('MaChao', 'LiuBei', 'ZhuGeLiangYoung')]
for label, r in (('tru', Rules(mitigation='subtract')),
                 ('chia k=100', Rules(mitigation='divide')),
                 ('chia k=300', Rules(mitigation='divide', defence_k=300.0)),
                 ('co GrowthFactor', Rules(use_growth=True))):
    score, total = round_robin(rows, heroes.base, 50, seed=1, rules=r)
    ok = (total == 150
          and all(s['win'] + s['lose'] + s['draw'] == s['games']
                  for s in score.values()))
    check(ok, 'cong thuc %s cho ket qua hop le' % label, total)

print('\n=== 9. tran khong bao gio chay vo han ===')
# Hai tuong thu cuc cao, cong cuc thap: phai dung lai o moc thoi gian, tinh hoa.
tank = dict(a)
tank['HeroSprite'] = 'TRAU'
tank['AttackCapability'] = 2
tank['Viability'] = 8
tank['InjuryRates'] = 0.0
w, l, d = match(tank, dict(tank), heroes.base, 20, seed=2)
check(w + l + d == 20, 'tran ben nhau van ket thuc', (w, l, d))

print('\n===== dat %d, hong %d =====' % (nPass, nFail))
sys.exit(0 if nFail == 0 else 1)
