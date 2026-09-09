# -*- coding: utf-8 -*-
"""Xuat bo so chien dau cho Godot va cho module Nakama.

Ba ban cai dat cua cung mot mo hinh, mot nguon so lieu duy nhat:

    sim/battle.py               mo hinh goc, Python
    battle/combat.gd            ban GDScript (client)
    server/modules/battle.lua   ban Lua (may chu Nakama)

    data_ref/battle_data.json     so lieu cho client
    server/modules/hero_data.lua  so lieu cho may chu

Trong ca hai file so lieu deu co khoi `reference`: ti le thang cua mot so cap
tuong do CHINH mo phong Python tinh. Hai ban kia danh lai cac cap do roi doi
chieu — lech nhau la biet ngay.

    python export_stats.py
    python export_stats.py --battles 4000
"""
import os, sys, json, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from tables import (Heroes, Talents, Armies, Formations, TableError,
                    DEFAULT_CONFIG)
from battle import Rules, match

DEFAULT_OUT = os.path.normpath(os.path.join(HERE, '..', 'data_ref', 'battle_data.json'))
DEFAULT_LUA = os.path.normpath(os.path.join(HERE, '..', 'server', 'modules', 'hero_data.lua'))
DEFAULT_ART = os.path.normpath(os.path.join(HERE, '..', 'assets_ref'))

# Cac cot mo hinh thuc su dung. Khong xuat ca 46 cot: cai gi khong dung thi
# khong xuat, de sau nay nhin file so lieu la biet mo hinh an vao dau.
FIELDS = ['HeroID', 'HeroSprite', 'HeroJobType', 'HeroRarity', 'HeroFactions',
          'AttackCapability', 'Viability', 'GrowthFactor',
          'InjuryRates', 'SkillInjuryRates', 'AngerRecovery', 'TalentSkill',
          'AddGrowthFactor']

BASE_FIELDS = ['HpBase', 'MinApBase', 'MaxApBase', 'DpBase', 'AttackInterval',
               'CriticalStrikeBase', 'CritDamageDouble', 'MovingSpeed']

# Quan chung. Khac tuong o cho bang nay co CHI SO TUYET DOI san, khong phai bac.
#
#   MaxUnit           2..4, moi quan chung la mot TOP linh chu khong phai mot nguoi
#   Location          1 hang truoc, 2 hang giua, 3 hang sau
#   MaxAttackDistance 30 = can chien, 300..500 = ban xa, 700..800 = cong thanh
#   MinAttackDistance 30/80 o vai loai — khong danh duoc muc tieu qua gan
ARMY_FIELDS = ['ArmyTypeID', 'SpriteName', 'MaxUnit', 'Location', 'AttackLocation',
               'HpBase', 'MinApBase', 'MaxApBase', 'DpBase', 'AttackInterval',
               'MovingSpeed', 'MaxAttackDistance', 'MinAttackDistance',
               'CriticalStrike', 'CritDamageDouble', 'InjuryRates',
               # Chi so o tren la cua CAP 1, va o cap 1 quan linh yeu hon tuong
               # ca chuc lan (cong 5-100 so voi 180-720) — danh nhau ca ba phut
               # ma khong ai chet. Bang goc co san cot tang moi cap; dung chung
               # de keo quan linh ve cung thang voi tuong.
               'HpGrowthValue', 'MinApGrowthValue', 'MaxApGrowthValue',
               'DpGrowthValue']

# Cap doi chieu: chon de trai deu tu mot chieu tuyet doi toi gan can bang.
REFERENCE_PAIRS = [
    ('MaChao', 'ZhuGeLiangYoung'),
    ('LvBuGod', 'HuaXiong'),
    ('GanNing', 'LiuBei'),
    ('LvBu', 'LvBuGod'),
    ('GuYong', 'JiaXu'),
    ('CaoCao', 'DengAi'),
]

# Gia the tran cua ban goc tinh bang tram nghin toi hang trieu vang, con nen
# kinh te o day moi chuong cho 60 vang. Chia cho 1000 de vua tui nguoi choi ma
# van giu nguyen TI LE giua cac the tran: jichu (100 vang moi cap dau) la cai
# de vao nhat, yanyue (7500) la cai phai danh lau moi voi toi.
FORMATION_GOLD_DIV = 1000.0

SAFE = set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-. ')


def formation_doc(forms):
    """The tran, da doi gia ve nen kinh te cua game nay.

    Gia tri buff giu NGUYEN so cua ban goc — chung deu la phan tram hoac cong
    them vao chi so goc, ma chi so goc o day cung la chi so goc cua ban goc
    (HpBase 1000), nen chung van dung thang.

    `unlockGold` la gia mo the tran, lay dung bang gia cap 1 cua chinh no. Nho
    vay cai manh thi dat, khong can bang mo khoa rieng: cai gia da la cai cong.
    """
    out = collections.OrderedDict()
    order = []
    for name in forms.names:
        top = forms.max_level(name)
        levels = []
        for lv in range(top + 1):
            levels.append(collections.OrderedDict([
                ('gold', int(round(forms.gold(name, lv) / FORMATION_GOLD_DIV))),
                ('buffs', collections.OrderedDict(
                    (str(k), forms.buffs(name, lv)[k]) for k in (1, 2, 3))),
            ]))
        unlock = int(round(forms.gold(name, 1) / FORMATION_GOLD_DIV))
        out[name] = collections.OrderedDict([
            ('name', name),
            ('maxLevel', top),
            # jichu la the tran vao cua: mien phi, co san tu dau.
            ('unlockGold', 0 if name == 'jichu' else unlock),
            ('levels', levels),
        ])
        order.append(name)
    return order, out



def lua_str(v):
    """Chuoi Lua.

    Moi chuoi di qua day deu la ten tuong, ten cot, hoac ten quy tac — toan ky
    tu an toan. Chan lai bang assert thay vi viet bo thoat ky tu: neu mot ngay
    nao do co chuoi la, no phai bao loi chu khong duoc am tham sinh ra Lua hong.
    """
    bad = [c for c in v if c not in SAFE]
    assert not bad, 'chuoi co ky tu can thoat, chua ho tro: %r trong %r' % (bad, v)
    return '"%s"' % v


def lua_value(v, indent=0):
    """Do mot gia tri Python ra cu phap Lua."""
    pad = ' ' * indent
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, (list, tuple)):
        if not v:
            return '{}'
        return '{ %s }' % ', '.join(lua_value(x, indent + 2) for x in v)
    if isinstance(v, dict):
        if not v:
            return '{}'
        lines = []
        for k, val in v.items():
            key = k if k.isidentifier() else '[%s]' % lua_str(k)
            lines.append('%s  %s = %s,' % (pad, key, lua_value(val, indent + 2)))
        return '{' + os.linesep.join([''] + lines) + os.linesep + pad + '}'
    return 'nil'


def write_lua(path, doc):
    """Bang so cho module Nakama.

    Module Lua tu chua so lieu chu khong doc file: runtime Lua cua Nakama
    khong hua hen mot API doc file nao, con `require` mot module tra ve bang
    thi chac chan chay duoc.
    """
    out = collections.OrderedDict([
        ('base', doc['base']),
        ('rules', doc['rules']),
        ('order', [r['HeroSprite'] for r in doc['heroes']]),
        ('heroes', collections.OrderedDict(
            (r['HeroSprite'], r) for r in doc['heroes'])),
        ('armyOrder', [r['SpriteName'] for r in doc['armies']]),
        ('armies', collections.OrderedDict(
            (r['SpriteName'], r) for r in doc['armies'])),
        ('formationOrder', doc['formationOrder']),
        ('formations', doc['formations']),
        ('reference', doc['reference']),
    ])
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as fp:
        fp.write('-- Sinh tu sim/export_stats.py - dung sua tay.\n')
        fp.write('-- So lieu goc co ban quyen, khong duoc dua vao repo.\n')
        fp.write('return %s\n' % lua_value(out))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--config', default=DEFAULT_CONFIG)
    ap.add_argument('--out', default=DEFAULT_OUT)
    ap.add_argument('--lua-out', default=DEFAULT_LUA,
                    help='bang so cho module Nakama (Lua)')
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
        talents = Talents(a.config)
        armies = Armies(a.config)
        forms = Formations(a.config)
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
        row = collections.OrderedDict()
        for k in FIELDS:
            # TalentSkill khong nam trong bang tuong ma o bang ky nang rieng.
            row[k] = talents.get(r['HeroID']) if k == 'TalentSkill' else r[k]
        rows.append(row)

    # Quan chung: chi lay loai co art, va moi sprite lay ban CO BAN (bang goc co
    # nhieu bac cua cung mot sprite — Defender co ba muc mau: 50, 750, 6000).
    # Lay ban manh nhat thi tran keo dai le the: da do, trung binh 170 giay.
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
    army_rows = [collections.OrderedDict((k, best[n][k]) for k in ARMY_FIELDS)
                 for n in sorted(best)]

    form_order, form_map = formation_doc(forms)

    rules = Rules()
    by_name = {r['HeroSprite']: r for r in rows}
    ref = []
    for x, y in REFERENCE_PAIRS:
        # Dung ban ghi DA CO TalentSkill, khong phai ban ghi tho — neu khong
        # thi ti le tham chieu tinh ra khong co ky nang, con hai ban kia thi co.
        ra, rb = by_name.get(x), by_name.get(y)
        if ra is None or rb is None:
            continue
        w, l, d = match(ra, rb, heroes.base, a.battles, seed=1234, rules=rules)
        ref.append(collections.OrderedDict([
            ('a', x), ('b', y), ('battles', a.battles),
            ('winPctA', round(100.0 * w / a.battles, 2)),
            ('drawPct', round(100.0 * d / a.battles, 2)),
        ]))

    doc = collections.OrderedDict([
        ('note', 'Sinh tu sim/export_stats.py - dung sua tay. '
                 'So lieu goc co ban quyen, khong duoc dua vao repo.'),
        ('base', collections.OrderedDict(
            (k, heroes.base[k]) for k in BASE_FIELDS if k in heroes.base)),
        ('rules', collections.OrderedDict([
            ('mitigation', rules.mitigation),
            ('defenceK', rules.defence_k),
            ('useGrowth', rules.use_growth),
            ('angerFull', rules.anger_full),
            ('maxSeconds', rules.max_seconds),
            ('useSkills', rules.use_skills),
            # Cap toi da o pham chat 1, lay tu GameHeroMaxLevelConfig.
            ('maxLevel', 40),
        ])),
        ('heroes', rows),
        ('armies', army_rows),
        ('formationOrder', form_order),
        ('formations', form_map),
        ('reference', ref),
    ])

    out_dir = os.path.dirname(a.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(a.out, 'w', encoding='utf-8') as fp:
        json.dump(doc, fp, ensure_ascii=False, indent=1)

    write_lua(a.lua_out, doc)

    print('ghi %s' % a.out)
    print('ghi %s' % a.lua_out)
    print('  %d tuong%s' % (len(rows),
          '' if not skipped else ' (bo %d tuong chua co art: %s)'
          % (len(skipped), ', '.join(skipped[:5]))))
    print('  %d quan chung co art' % len(army_rows))
    print('  %d the tran (%s...)' % (len(form_order), ', '.join(form_order[:3])))
    print('  %d cap doi chieu, %d tran moi cap' % (len(ref), a.battles))
    for e in ref:
        print('     %-20s vs %-20s  %5.1f%% thang, %4.1f%% hoa'
              % (e['a'], e['b'], e['winPctA'], e['drawPct']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
