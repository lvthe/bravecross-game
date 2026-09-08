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
from tables import Heroes, TableError, DEFAULT_CONFIG
from battle import Rules, match

DEFAULT_OUT = os.path.normpath(os.path.join(HERE, '..', 'data_ref', 'battle_data.json'))
DEFAULT_LUA = os.path.normpath(os.path.join(HERE, '..', 'server', 'modules', 'hero_data.lua'))
DEFAULT_ART = os.path.normpath(os.path.join(HERE, '..', 'assets_ref'))

# Cac cot mo hinh thuc su dung. Khong xuat ca 46 cot: cai gi khong dung thi
# khong xuat, de sau nay nhin file so lieu la biet mo hinh an vao dau.
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

SAFE = set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-. ')


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
        ])),
        ('heroes', rows),
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
    print('  %d cap doi chieu, %d tran moi cap' % (len(ref), a.battles))
    for e in ref:
        print('     %-20s vs %-20s  %5.1f%% thang, %4.1f%% hoa'
              % (e['a'], e['b'], e['winPctA'], e['drawPct']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
