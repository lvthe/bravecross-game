# -*- coding: utf-8 -*-
"""Tran dan tran: hai doi quan co vi tri, khong phai hai tuong tay doi.

`battle.py` xu mot tran TAY DOI — dung de can bang bang tuong. Nhung man choi
that thi giong ban goc: moi ben bon tuong cong ba top quan linh dan theo ba
hang, ai cung co toa do, tam danh va toc do rieng.

File nay la ban Python cua dung mo hinh do, va no la BAN CHUAN: `battle/`
(client, GDScript) va `server/modules/battle.lua` (may chu) phai ra cung ket
qua. Co ban o day thi do duoc nhanh — 400 tran chay vai giay thay vi muoi phut
qua Godot — nen moi con so can, cap quan linh, deu do o day truoc.

    python field.py --sim 400 --mirror
    python field.py --sweep

MOT BUOC CHIA HAI PHA, va do la co y. Lam mot pha — duyet doi 0 roi doi 1 —
thi voi hai doi hinh GIONG HET NHAU doi phai thang 76%: doi 0 di truoc nen khi
doi 1 do khoang cach thi doi thu da tien lai gan, doi 1 vao tam truoc va ra don
truoc. Nen pha 1 moi don vi doc vi tri tu MOT BAN CHUP, pha 2 gom moi don ra
cung luc.
"""
import os, sys, math, random, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from tables import Heroes, Talents, Armies, TableError, DEFAULT_CONFIG
from battle import Rules, Fighter

TEAM_SIZE = 4


class Lcg(object):
    """Ban sao cua `Rng` trong server/modules/battle.lua.

    Cung mot seed phai cho ra cung mot chuoi o ca hai ben — nho vay hai ban cai
    dat doi chieu duoc TUNG TRAN, khong chi ti le thang tren nhieu tran.
    """

    def __init__(self, seed=0):
        s = int(seed) % 2147483647
        if s <= 0:
            s += 2147483646
        self.s = s

    def next(self):
        self.s = (self.s * 16807) % 2147483647
        return self.s

    def float(self):
        return self.next() / 2147483647.0

    def uniform(self, lo, hi):
        return lo + (hi - lo) * self.float()

    def random(self):
        return self.float()

    def int(self, n):
        return (self.next() % n) + 1


# Vach dan quan. Phai khop battle/battle.gd — hai ban cai dat cung mot san.
LEFT_X, RIGHT_X = 190.0, 770.0
MID_Y = 340.0
ROW_BACK = 96.0
ROW_GAP = 74.0
SQUAD_SPREAD = 48.0
BODY = 56.0
LANE_PULL = 0.35
LANE_WEIGHT = 4.0
STEP = 0.033


def make_army(row, rules, level=1):
    """Mot top linh, chi so da keo theo cap.

    Bang goc luu chi so CAP 1 cua quan linh, va o cap 1 quan linh yeu hon tuong
    ca chuc lan. Cot *GrowthValue la muc cong moi cap; dung no de keo quan linh
    ve cung thang voi tuong.
    """
    a = row
    n = float(max(1, int(level)) - 1)
    f = Fighter({
        'HeroSprite': a['SpriteName'], 'HeroID': 0, 'HeroJobType': 0,
        'HeroRarity': 0, 'HeroFactions': 0,
        'Viability': 1, 'AttackCapability': 1,
        'GrowthFactor': 1, 'AddGrowthFactor': 0,
        'InjuryRates': float(a.get('InjuryRates', 0)),
        'SkillInjuryRates': 0, 'AngerRecovery': 0, 'TalentSkill': '',
    }, {
        'HpBase': float(a['HpBase']) + float(a.get('HpGrowthValue', 0)) * n,
        'MinApBase': float(a['MinApBase']) + float(a.get('MinApGrowthValue', 0)) * n,
        'MaxApBase': float(a['MaxApBase']) + float(a.get('MaxApGrowthValue', 0)) * n,
        'DpBase': float(a['DpBase']) + float(a.get('DpGrowthValue', 0)) * n,
        'AttackInterval': float(a['AttackInterval']),
        'CriticalStrikeBase': float(a.get('CriticalStrike', 0)),
        'CritDamageDouble': float(a.get('CritDamageDouble', 1.5)),
        'MovingSpeed': float(a.get('MovingSpeed', 30)),
    }, rules)
    f.reach = float(a.get('MaxAttackDistance', 30))
    f.min_reach = float(a.get('MinAttackDistance', 0))
    f.move_speed = float(a.get('MovingSpeed', 30))
    f.battle_row = int(a.get('Location', 1))
    f.units = max(1, int(a.get('MaxUnit', 1)))
    return f


class Unit(object):
    """Mot don vi tren san: chi so + toa do."""

    def __init__(self, fighter, team, x, y):
        self.f = fighter
        self.team = team
        self.x, self.y = x, y
        # Tam danh 30 cua quan can chien nho hon khoang cach than (BODY = 56)
        # nen ho khong bao gio cham duoc nhau — nang san len vua qua than nguoi.
        r = getattr(fighter, 'reach', 0.0)
        self.reach = max(r, 62.0) if r > 0.0 else 58.0
        self.min_reach = getattr(fighter, 'min_reach', 0.0)
        # Toc do goc (20-80) qua cham cho man 960px; nhan len nhung van giu
        # chenh lech giua ky binh (80) va voi (20).
        self.speed = max(28.0, getattr(fighter, 'move_speed', 30.0) * 1.5)
        # Don dau tien roi vao luc hoi chieu xong, giong mo phong tay doi.
        self.cooldown = fighter.interval
        self.target = None

    def alive(self):
        return self.f.alive

    def nearest(self, enemies, snap):
        """Gan nhat, nhung lech LAN bi phat nang nen doi thu cung hang duoc uu
        tien. Nho vay tran thanh may cap danh nhau theo hang."""
        best, best_d = None, float('inf')
        hx, hy = snap[id(self)]
        for e in enemies:
            if not e.alive():
                continue
            ex, ey = snap[id(e)]
            dx, dy = ex - hx, ey - hy
            cost = dx * dx + (dy * LANE_WEIGHT) ** 2
            if cost < best_d:
                best_d, best = cost, e
        return best

    def advance(self, delta, enemies, snap):
        """Pha 1: chon muc tieu, tien len. Tra ve muc tieu neu ra don."""
        if not self.alive():
            return None
        if self.target is None or not self.target.alive():
            self.target = self.nearest(enemies, snap)
        if self.target is None:
            return None

        hx, hy = snap[id(self)]
        tx, ty = snap[id(self.target)]
        dx, dy = tx - hx, ty - hy
        dist = math.sqrt(dx * dx + dy * dy)

        # Qua gan thi lui ra: Artillery/Catapult co MinAttackDistance nen khong
        # danh duoc muc tieu ap sat.
        if self.min_reach > 0.0 and dist < self.min_reach:
            k = self.speed * delta * 0.6 / max(dist, 0.001)
            self.x, self.y = hx - dx * k, hy - dy * k
            return None

        if dist > self.reach:
            # Di theo LAN: chay thang theo truc x, doi lan thi cham hon nhieu.
            # Cho di thang toi muc tieu thi ca tam don vi don ve mot diem giua
            # san roi chong len nhau thanh mot dong.
            step_y = self.speed * LANE_PULL * delta
            if dx > 0:
                self.x = hx + self.speed * delta
            elif dx < 0:
                self.x = hx - self.speed * delta
            else:
                self.x = hx
            self.y = hy + max(-step_y, min(step_y, dy))
            return None

        self.cooldown -= delta
        if self.cooldown <= 0.0:
            self.cooldown += self.f.interval
            return self.target
        return None


def separate(units):
    """Day cac don vi ra khoi nhau. Cong don luc day roi ap MOT LAN.

    Day tung cap ngay lap tuc thi cap xet sau nhin thay vi tri da doi — ma doi
    0 luon duoc duyet truoc. Dung loai bat doi xung da tung lam ben phai thang
    76%. Voi 4 don vi thi khong thay, voi hai doi quan hai chuc nguoi thi thay.
    """
    live = [u for u in units if u.alive()]
    shove = {}
    for i in range(len(live)):
        a = live[i]
        for j in range(i + 1, len(live)):
            b = live[j]
            dx, dy = b.x - a.x, b.y - a.y
            dist = math.sqrt(dx * dx + dy * dy)
            if dist >= BODY or dist < 0.001:
                continue
            k = (BODY - dist) * 0.5 / dist
            px, py = dx * k, dy * k
            sa = shove.setdefault(id(a), [0.0, 0.0])
            sb = shove.setdefault(id(b), [0.0, 0.0])
            sa[0] -= px
            sa[1] -= py
            sb[0] += px
            sb[1] += py
    for u in live:
        s = shove.get(id(u))
        if s:
            u.x += s[0]
            u.y += s[1]


def place(team, row, slot, of):
    back = (row - 1) * ROW_BACK
    x = (LEFT_X - back) if team == 0 else (RIGHT_X + back)
    y = MID_Y + (float(slot) - (of - 1) * 0.5) * SQUAD_SPREAD
    return x, y


def field(teams, rng, rules, max_seconds=None):
    """Chay mot tran. Tra ve (ket qua, so giay). 0/1 la doi thang, 2 la hoa."""
    limit = rules.max_seconds if max_seconds is None else max_seconds
    for side in teams:
        for u in side:
            u.f.reset()
    elapsed = 0.0
    every = teams[0] + teams[1]
    while True:
        elapsed += STEP
        snap = {}
        for u in every:
            snap[id(u)] = (u.x, u.y)
        strikes = []
        for t in (0, 1):
            for u in teams[t]:
                if not u.alive():
                    continue
                v = u.advance(STEP, teams[1 - t], snap)
                if v is not None:
                    strikes.append((u, v))
        separate(every)
        for u, v in strikes:
            u.f.strike(v.f, rng, rules)

        a = sum(1 for u in teams[0] if u.alive())
        b = sum(1 for u in teams[1] if u.alive())
        if a > 0 and b > 0:
            if elapsed >= limit:
                return 2, elapsed
            continue
        if a > 0:
            return 0, elapsed
        if b > 0:
            return 1, elapsed
        return 2, elapsed


# ---------------------------------------------------------------- dung doi hinh

def armies_in_row(army_rows, r):
    return [a for a in army_rows if int(a.get('Location', 1)) == r]


def pick_armies(army_rows, seed_value):
    """Mot quan chung cho moi hang, boc theo seed."""
    r = random.Random(seed_value)
    out = []
    for row in (1, 2, 3):
        pool = armies_in_row(army_rows, row)
        if pool:
            out.append(pool[r.randrange(len(pool))])
    return out


def build_teams(hero_rows_by_name, army_rows, roster, rules,
                seed_value=1, army_level=6, chapter=0, mirrored=False,
                hero_level=1):
    """Dung ca hai doi: bon tuong + ba top quan linh moi ben."""
    teams = [[], []]
    for t in (0, 1):
        side = 0 if mirrored else t
        for a in pick_armies(army_rows, seed_value * 31 + side * 7 + chapter):
            proto = make_army(a, rules, army_level)
            for k in range(proto.units):
                f = make_army(a, rules, army_level)
                x, y = place(t, proto.battle_row, k, proto.units)
                teams[t].append(Unit(f, t, x, y))
        names = roster[t]
        for i, name in enumerate(names):
            f = Fighter(hero_rows_by_name[name], BASE[0], rules, level=hero_level)
            f.reach = 0.0
            f.min_reach = 0.0
            f.move_speed = float(BASE[0].get('MovingSpeed', 30))
            y = MID_Y + (float(i) - (len(names) - 1) * 0.5) * ROW_GAP
            x = (LEFT_X + 52.0) if t == 0 else (RIGHT_X - 52.0)
            teams[t].append(Unit(f, t, x, y))
    return teams


## Cap goc cua quan linh. Phai KHOP ARMY_BASE_LEVEL trong
## server/modules/battle.lua va battle/battle.gd.
ARMY_BASE_LEVEL = 6

## Cho dung mac dinh cua bon tuong khi ban luu chua ghi gi: hai truoc, hai sau.
DEFAULT_PLACEMENT = [1, 1, 2, 3]


def formation_buffs(doc, name, level, place):
    """Buff cua the tran `name` o cap `level` cho cho dung `place` (1/2/3).

    `doc` la battle_data.json da doc. Khong co the tran do, hoac cap ngoai
    bang, thi khong buff gi — im lang tra bang rong chu khong doan.
    """
    f = (doc.get('formations') or {}).get(name)
    if f is None:
        return {}
    levels = f.get('levels') or []
    lv = max(0, min(int(level), len(levels) - 1))
    if lv < 0 or not levels:
        return {}
    return (levels[lv].get('buffs') or {}).get(str(int(place)), {}) or {}


def lua_pick_armies(army_rows, seed_value):
    """Boc quan chung y het pick_armies() trong battle.lua (dung LCG chung)."""
    r = Lcg(seed_value)
    out = []
    for row in (1, 2, 3):
        pool = armies_in_row(army_rows, row)
        if pool:
            out.append(pool[r.int(len(pool)) - 1])
    return out


def lua_battle(hero_by_name, army_rows, base, rules, mine, theirs,
               seed, chapter, power=1.0, levels=None, placement=None,
               formation='', formation_level=0, doc=None):
    """Ban Python cua army_battle() trong battle.lua, dung tung buoc mot.

    Dung de doi chieu: cung seed thi hai ben phai ra cung ket qua, cung so
    giay, cung so nguoi con song.
    """
    levels = levels or {}
    army_lv = ARMY_BASE_LEVEL + max(0, chapter)
    teams = [[], []]
    roster = [mine, theirs]
    place_of = list(placement or DEFAULT_PLACEMENT)
    buffs_doc = doc or {}
    for t in (0, 1):
        for a in lua_pick_armies(army_rows, seed * 31 + t * 7 + chapter):
            proto = make_army(a, rules, army_lv)
            for k in range(proto.units):
                x, y = place(t, proto.battle_row, k, proto.units)
                teams[t].append(Unit(make_army(a, rules, army_lv), t, x, y))
        names = roster[t]
        for i, name in enumerate(names):
            lv = (levels.get(name, 1) if t == 0 else 1)
            # Cho dung quyet ca hai thu: dung o dau tren san, va an buff nao
            # cua the tran. Chi doi cua NGUOI CHOI co the tran.
            place = place_of[i] if i < len(place_of) else 1
            bf = (formation_buffs(buffs_doc, formation, formation_level, place)
                  if t == 0 and formation else {})
            f = Fighter(hero_by_name[name], base, rules, level=lv, buffs=bf)
            f.reach = 0.0
            f.min_reach = 0.0
            f.move_speed = float(base['MovingSpeed'])
            # Tuong dung nhinh len truoc top linh cung hang.
            back = (place - 1) * ROW_BACK
            y = MID_Y + (float(i) - (len(names) - 1) * 0.5) * ROW_GAP
            x = (LEFT_X + 52.0 - back) if t == 0 else (RIGHT_X - 52.0 + back)
            teams[t].append(Unit(f, t, x, y))
    rng = Lcg(seed)
    res, secs = field(teams, rng, rules)
    a = sum(1 for u in teams[0] if u.alive())
    b = sum(1 for u in teams[1] if u.alive())
    return res, secs, a, b


BASE = [None]      # khoi chi so goc, dat mot lan trong main()


def rosters(order, seed_value, mirror=False):
    pool = list(order)
    r = random.Random(seed_value)
    for i in range(len(pool) - 1, 0, -1):
        j = r.randint(0, i)
        pool[i], pool[j] = pool[j], pool[i]
    left = [pool[i % len(pool)] for i in range(TEAM_SIZE)]
    right = left[:] if mirror else [pool[(i + TEAM_SIZE) % len(pool)]
                                    for i in range(TEAM_SIZE)]
    return [left, right]


def run(hero_by_name, order, army_rows, n, rules, mirror=False,
        army_level=6, chapter=0, seed=20260908):
    """n tran, moi tran mot doi hinh. Tra ve (thang trai, thang phai, hoa, giay tb)."""
    w = l = d = 0
    total_t = 0.0
    for i in range(n):
        rs = rosters(order, i + 1, mirror)
        teams = build_teams(hero_by_name, army_rows, rs, rules,
                            seed_value=i + 1, army_level=army_level,
                            chapter=chapter, mirrored=mirror)
        rng = random.Random(seed + i)
        res, secs = field(teams, rng, rules)
        total_t += secs
        if res == 0:
            w += 1
        elif res == 1:
            l += 1
        else:
            d += 1
    return w, l, d, total_t / max(1, n)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--config', default=DEFAULT_CONFIG)
    ap.add_argument('--sim', type=int, default=200)
    ap.add_argument('--mirror', action='store_true')
    ap.add_argument('--army-level', type=int, default=6)
    ap.add_argument('--chapter', type=int, default=0)
    ap.add_argument('--mitigation', default='subtract', choices=('subtract', 'divide'))
    ap.add_argument('--k', type=float, default=100.0)
    ap.add_argument('--art', default=os.path.normpath(os.path.join(HERE, '..', 'assets_ref')))
    ap.add_argument('--sweep', action='store_true',
                    help='quet cong thuc giam thuong x cap quan linh')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    try:
        heroes = Heroes(a.config)
        talents = Talents(a.config)
        armies = Armies(a.config)
    except TableError as e:
        sys.exit(str(e))

    art = set(os.listdir(a.art)) if os.path.isdir(a.art) else set()
    hero_by_name, order = {}, []
    for r in heroes.rows:
        if art and r['HeroSprite'] not in art:
            continue
        row = dict(r)
        row['TalentSkill'] = talents.get(r['HeroID'])
        hero_by_name[r['HeroSprite']] = row
        order.append(r['HeroSprite'])

    # Quan chung: moi sprite lay ban CO BAN (bang goc co nhieu bac cua cung mot
    # sprite — Defender co ba muc mau: 50, 750, 6000).
    best = {}
    for x in armies.rows:
        name = x.get('SpriteName', '')
        if not name or int(x.get('MaxUnit', 0)) <= 0:
            continue
        if art and name not in art:
            continue
        cur = best.get(name)
        if cur is None or int(x['HpBase']) < int(cur['HpBase']):
            best[name] = x
    army_rows = [best[n] for n in sorted(best)]

    BASE[0] = heroes.base

    if a.sweep:
        print('quet: cong thuc giam thuong x cap quan linh  (%d tran moi o, guong)'
              % a.sim)
        print('%-14s %5s %7s %7s %7s %8s' % ('cong thuc', 'cap', 'trai', 'phai', 'hoa', 'giay tb'))
        for mit, k in (('subtract', 0.0), ('divide', 100.0), ('divide', 300.0)):
            for lv in (1, 4, 8, 12):
                rules = Rules(mitigation=mit, defence_k=k)
                w, l, d, t = run(hero_by_name, order, army_rows, a.sim, rules,
                                 mirror=True, army_level=lv)
                tag = mit if mit == 'subtract' else '%s k=%g' % (mit, k)
                print('%-14s %5d %6.1f%% %6.1f%% %6.1f%% %8.1f'
                      % (tag, lv, 100.0 * w / a.sim, 100.0 * l / a.sim,
                         100.0 * d / a.sim, t))
        return 0

    rules = Rules(mitigation=a.mitigation, defence_k=a.k)
    w, l, d, t = run(hero_by_name, order, army_rows, a.sim, rules,
                     mirror=a.mirror, army_level=a.army_level, chapter=a.chapter)
    print('%d tran%s  cong thuc %s%s, quan linh cap %d'
          % (a.sim, ' (doi hinh guong)' if a.mirror else '', a.mitigation,
             '' if a.mitigation == 'subtract' else ' k=%g' % a.k, a.army_level))
    print('  doi trai thang : %d  (%.1f%%)' % (w, 100.0 * w / a.sim))
    print('  doi phai thang : %d  (%.1f%%)' % (l, 100.0 * l / a.sim))
    print('  hoa            : %d  (%.1f%%)' % (d, 100.0 * d / a.sim))
    print('  tran trung binh: %.1f giay' % t)
    return 0


if __name__ == '__main__':
    sys.exit(main())
