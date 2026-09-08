# -*- coding: utf-8 -*-
"""Xuat bo so chien dau sang JSON cho Godot doc.

Man tran trong Godot phai danh bang DUNG bo so ma mo phong Python dung, khong
duoc chep tay sang GDScript roi troi dat. File nay la mot nguon duy nhat:

    sim/battle.py   -> mo hinh goc, chay bang Python
    data_ref/battle_data.json  -> so lieu, sinh ra tu day
    battle/combat.gd -> ban cai dat GDScript, doc file tren

Trong file JSON co san khoi `reference`: ti le thang cua mot so cap tuong do
CHINH mo phong Python tinh. tools/verify_battle.gd danh lai cac cap do bang
GDScript roi doi chieu — hai ban cai dat lech nhau la biet ngay.

    python export_stats.py
    python export_stats.py --out ../data_ref/battle_data.json --battles 400
"""
import os, sys, json, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from tables import Heroes, TableError, DEFAULT_CONFIG
from battle import Rules, match

DEFAULT_OUT = os.path.normpath(os.path.join(HERE, '..', 'data_ref', 'battle_data.json'))
DEFAULT_ART = os.path.normpath(os.path.join(HERE, '..', 'assets_ref'))

# Cac cot mo hinh thuc su dung. Khong xuat ca 46 cot: cai gi khong dung thi
# khong xuat, de sau nay nhin JSON la biet mo hinh an vao dau.
FIELDS = ['HeroID', 'HeroSprite', 'HeroJobType', 'HeroRarity', 'HeroFactions',
          'AttackCapability', 'Viability', 'GrowthFactor',
          'InjuryRates', 'SkillInjuryRates', 'AngerRecovery']

BASE_FIELDS = ['HpBase', 'MinApBase', 'MaxApBase', 'DpBase', 'AttackInterval',
               'CriticalStrikeBase', 'CritDamageDouble', 'MovingSpeed']

# Cap doi chieu: chon de trai deu tu mot chieu tuyet doi toi gan can bang.
REFERENCE_PAIRS = [
    ('MaChao', 'ZhuGeLiangYoung'),
    ('LvBuGod', 'HuaXiong'),
    ('GanNing', 'LiuBei'),
    ('LvBu', 'LvBuGod'),
    ('GuYong', 'JiaXu'),
    ('CaoCao', 'DengAi'),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--config', default=DEFAULT_CONFIG)
    ap.add_argument('--out', default=DEFAULT_OUT)
    ap.add_argument('--art', default=DEFAULT_ART,
                    help='chi xuat tuong co atlas trong thu muc nay')
    ap.add_argument('--all', action='store_true',
                    help='xuat ca 92 tuong ke ca tuong chua co art')
    ap.add_argument('--battles', type=int, default=400,
                    help='so tran cho moi cap doi chieu')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    try:
        heroes = Heroes(a.config)
    except TableError as e:
        sys.exit(str(e))

    art = set()
    if os.path.isdir(a.art):
        art = set(os.listdir(a.art))

    rows = []
    skipped = []
    for r in heroes.rows:
        if not a.all and art and r['HeroSprite'] not in art:
            skipped.append(r['HeroSprite'])
            continue
        rows.append(collections.OrderedDict((k, r[k]) for k in FIELDS))

    rules = Rules()
    ref = []
    for x, y in REFERENCE_PAIRS:
        try:
            ra, rb = heroes.get(x), heroes.get(y)
        except TableError:
            continue
        w, l, d = match(ra, rb, heroes.base, a.battles, seed=1234, rules=rules)
        ref.append(collections.OrderedDict([
            ('a', x), ('b', y), ('battles', a.battles),
            ('winPctA', round(100.0 * w / a.battles, 2)),
            ('drawPct', round(100.0 * d / a.battles, 2)),
        ]))

    doc = collections.OrderedDict([
        ('note', 'Sinh tu sim/export_stats.py — dung sua tay. '
                 'So lieu goc co ban quyen, khong duoc dua vao repo.'),
        ('base', collections.OrderedDict(
            (k, heroes.base[k]) for k in BASE_FIELDS if k in heroes.base)),
        ('rules', collections.OrderedDict([
            ('mitigation', rules.mitigation),
            ('defenceK', rules.defence_k),
            ('useGrowth', rules.use_growth),
            ('angerFull', rules.anger_full),
            ('maxSeconds', rules.max_seconds),
        ])),
        ('heroes', rows),
        ('reference', ref),
    ])

    out_dir = os.path.dirname(a.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(a.out, 'w', encoding='utf-8') as fp:
        json.dump(doc, fp, ensure_ascii=False, indent=1)

    print('ghi %s' % a.out)
    print('  %d tuong%s' % (len(rows),
          '' if not skipped else ' (bo %d tuong chua co art: %s)'
          % (len(skipped), ', '.join(skipped[:5]))))
    print('  %d cap doi chieu, %d tran moi cap' % (len(ref), a.battles))
    for e in ref:
        print('     %-20s vs %-20s  %5.1f%% thang, %4.1f%% hoa'
              % (e['a'], e['b'], e['winPctA'], e['drawPct']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
