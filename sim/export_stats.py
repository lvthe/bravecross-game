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
import os, re, sys, json, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from tables import (Heroes, Talents, Armies, Formations, EquipSynthesis,
                    ExclusiveEquip, EquipQuality, WeaponSkills, Items,
                    Achievements, TableError, DEFAULT_CONFIG)
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

# ------------------------------------------------- thanh tuu va nhiem vu ngay
# Chi dua vao nhung loai ma game moi DO DUOC tien do. Ban goc co 50 loai; phan
# lon can he thong game moi chua co (dau truong, hang dong, bang hoi, cap tai
# khoan, thu tuong). Dua vao ma khong do duoc thi no nam mai o "dang lam".
#
# loai -> (ho, cach do). `cach do` la nhanh trong task_progress() cua
# server/modules/battle.lua, moi nhanh ung voi mot ham kiem cua ban goc
# (AchieveCheckLogic.lua).
TASK_KINDS = collections.OrderedDict([
    (6, ('achieve', 'chapter')),            # getChapterPassProgress: qua man L_N_<chuong>_<man>
    (9, ('achieve', 'heroLevelCount')),     # getHeroLevelCountProgress: N tuong dat cap L
    (11, ('achieve', 'maxEquipQuality')),   # getEquipQualityProgress: pham chat cao nhat tung dat
    (14, ('achieve', 'heroLevelTo')),       # getSomeHeroLevelToProgress: 5 tuong dat cap X
    (16, ('achieve', 'equipLevelCount')),   # getWeaponLevelCountProgress
    (17, ('achieve', 'equipLevelCount')),   # getDefenderLevelCountProgress
    (18, ('achieve', 'equipLevelCount')),   # getJewelryLevelCountProgress
    (103, ('daily', 'counter')),            # thang 10 tran bat ky trong ngay
    (113, ('daily', 'counter')),            # luyen tuong 1 lan trong ngay
])
# O trang bi ma moi loai dem — dung HeroEquipPart ma ham kiem cua ban goc doc.
TASK_PARTS = {16: [1], 17: [2, 3], 18: [4, 5]}
# Ten bien dem cua ban goc. Loai 103 ghi ten ngay trong dieu kien; loai 113
# thi ten nam trong ham kiem (getPracticeHeroProgress).
TASK_COUNTER = {113: 'PracticeHeroCountDaily'}

# Nhiem vu ngay CUA GAME MOI — khong co trong bang goc. Ban goc co 13 loai nhiem
# vu ngay nhung 11 loai can he thong chua co (dau truong, hang dong, bang hoi...);
# con lai 2 loai thi ruong nang dong (5 diem) khong bao gio voi toi. Nguoi dung
# chon them nhiem vu dua tren he thong da co.
#
# Dat o khoang 151.. de khong dung loai nao cua ban goc: sau nay lam dung loai
# 106 (hang dong) thi khong vuong.
#
# Co can cu: loai 151 dung ten bien dem THAT cua ban goc
# (IntensifyEquipmentCountDaily, trong Statistics.lua) va ham kiem that
# (getIntensifyEquipmentCountProgress) — ban goc tung gan ham nay cho loai 106
# roi bo khoi bang. Phan thuong lay dung PrizeID cua nhiem vu ngay goc.
# Con so lan phai lam (3, 1, 1, 1) la cua ta.
GAME_DAILY = [
    # (loai, bien dem, so lan, PrizeID goc)
    (151, 'IntensifyEquipmentCountDaily', 3, 10601),   # cuong hoa — PrizeID cua loai 106
    (152, 'RefineEquipmentCountDaily', 1, 11301),      # tinh luyen
    (153, 'DismantleItemCountDaily', 1, 11301),        # phan giai vat pham
    (154, 'SynthesizeEquipmentCountDaily', 1, 11301),  # ghep do
]
# Game moi co 12 chuong (CHAPTERS trong battle.lua) va tuong toi da cap 40.
# Buoc nao doi hon the thi khong bao gio dat duoc — bo di, khong de no treo.
MAX_CHAPTER = 12
MAX_HERO_LEVEL = 40

# Ma loai phan thuong cua ban goc (Protocol.lua: PrizeResType, ResourceType).
PRIZE_ITEM, PRIZE_RESOURCE, PRIZE_USER, PRIZE_MATERIAL = 2, 3, 4, 8
CURRENCY_GOLD, CURRENCY_CONCENTRATE, CURRENCY_DIAMOND = 1, 8, 20
ITEM_DIAMOND = 3        # vat pham "钻石" — kim cuong duoi dang vat pham


def convert_prize(parts):
    """Doi phan thuong ban goc sang thu game moi co.

    Vang va tinh hoa giu NGUYEN so: he trang bi ben game moi dung dung thang
    vang cua ban goc (ghep do 10 -> 10 000 000), nen phan thuong cung phai o
    cung thang do moi mua duoc gi.

    Vat pham vao tui y nguyen, ke ca loai game moi chua co cho dung (dan kinh
    nghiem, dan pham chat) — do la phan thuong that cua ban goc, va se co
    cong dung khi co he thong tuong ung.

    Thu KHONG co cho chua (kim cuong, kinh nghiem tai khoan, the luc) thi ghi
    vao `notGranted` chu khong doi bua sang thu khac.
    """
    out = collections.OrderedDict([
        ('gold', 0), ('goldPerLevel', 0), ('concentrate', 0),
        ('items', []), ('notGranted', []),
    ])
    items = collections.OrderedDict()
    for x in parts:
        kind = int(x.get('PrizeResType', 0))
        count = int(x.get('PrizeResCount', 0))
        if kind in (PRIZE_ITEM, PRIZE_MATERIAL):
            pid = int(x.get('PropID', 0))
            if pid == ITEM_DIAMOND:
                out['notGranted'].append('kim cuong x%d' % count)
            elif count > 0:
                items[pid] = items.get(pid, 0) + count
        elif kind == PRIZE_RESOURCE:
            cur = int(x.get('CurrencyType', 0))
            if cur == CURRENCY_GOLD:
                out['gold'] += count
            elif cur == CURRENCY_CONCENTRATE:
                out['concentrate'] += count
            elif cur == CURRENCY_DIAMOND:
                out['notGranted'].append('kim cuong x%d' % count)
            else:
                out['notGranted'].append('tai nguyen %d x%d' % (cur, count))
        elif kind == PRIZE_USER:
            prop = str(x.get('UserProperty', ''))
            val = int(x.get('PrizeProperty', 0))
            if prop == 'AddGoldInLevel':
                # "Vang theo cap": PrizeProperty x cap nguoi choi, tinh luc trao.
                out['goldPerLevel'] += val
            elif prop == 'UserEx':
                out['notGranted'].append('kinh nghiem tai khoan x%d' % val)
            elif prop == 'AddFatigue':
                out['notGranted'].append('the luc x%d' % val)
            else:
                out['notGranted'].append('%s x%d' % (prop, val))
        else:
            out['notGranted'].append('loai thuong %d' % kind)
    out['items'] = [[k, v] for k, v in items.items()]
    return out


def task_step(achieve_type, kind, step):
    """Mot buoc cua chuoi, doi sang dang may chu doc. None = bo (khong dat duoc)."""
    c = step['condition']
    arg = c.get('ConditionArg') or []
    out = collections.OrderedDict([('index', step['index'])])
    if kind == 'chapter':
        m = re.match(r'L_N_(\d+)_(\d+)$', str(arg[0] if arg else ''))
        if m is None:
            raise TableError('loai %d buoc %d: khoa chuong la %r'
                             % (achieve_type, step['index'], arg))
        chapter, stage = int(m.group(1)), int(m.group(2))
        if chapter > MAX_CHAPTER:
            return None
        # Mot "chuong" ben game moi la mot tran; qua no nghia la qua het cac
        # man cua chuong do ben ban goc — ca bon moc cua chuong cung dat.
        out['target'] = chapter
        out['arg'] = stage
    elif kind == 'heroLevelCount':
        out['target'] = int(c['HeroCount'])
        out['arg'] = int(c['Level'])
    elif kind == 'heroLevelTo':
        lv = int(arg[0])
        if lv > MAX_HERO_LEVEL:
            return None
        out['target'] = int(c['ConditionVal'])
        out['arg'] = lv
    elif kind == 'equipLevelCount':
        out['target'] = int(c['ConditionVal'])
        out['arg'] = int(arg[0])
    elif kind in ('maxEquipQuality', 'counter'):
        out['target'] = int(c['ConditionVal'])
    else:
        raise TableError('khong biet cach do %r' % kind)
    return out


def task_doc(ach):
    """Khoi `achieve` cho ca hai file so lieu, kem tap id vat pham phan thuong can."""
    types = collections.OrderedDict()
    order = []
    dropped = collections.OrderedDict()
    item_ids = set()
    for t, (family, kind) in TASK_KINDS.items():
        chain = ach.chain(t)
        steps = []
        for step in chain:
            s = task_step(t, kind, step)
            if s is None:
                continue
            s['prize'] = convert_prize(ach.prize_parts(step['award']))
            item_ids.update(i for i, _n in s['prize']['items'])
            steps.append(s)
        if not steps:
            raise TableError('loai %d: khong con buoc nao' % t)
        # Buoc bi bo phai nam o DUOI chuoi: may chu dung so buoc lam chi so
        # mang, bo mot buoc o giua la moi buoc sau do lech het.
        if [s['index'] for s in steps] != list(range(1, len(steps) + 1)):
            raise TableError('loai %d: buoc bi bo khong nam o cuoi chuoi' % t)
        if len(chain) > len(steps):
            dropped[str(t)] = len(chain) - len(steps)
        d = collections.OrderedDict([('type', t), ('family', family), ('kind', kind)])
        if t in TASK_PARTS:
            d['parts'] = TASK_PARTS[t]
        if kind == 'counter':
            arg = chain[0]['condition'].get('ConditionArg') or []
            d['counter'] = str(arg[0]) if arg else TASK_COUNTER[t]
        if family == 'daily':
            d['liveness'] = ach.liveness(t)
        d['steps'] = steps
        types[str(t)] = d
        order.append(t)

    # Nhiem vu ngay cua game moi: cung dang voi nhiem vu ngay goc, them co
    # `origin` de noi ro la cua ta.
    for t, counter, target, pid in GAME_DAILY:
        if ach.chain(t):
            raise TableError('loai %d cua game moi trung mot loai cua ban goc' % t)
        prize = convert_prize(ach.prize_parts([pid]))
        item_ids.update(i for i, _n in prize['items'])
        types[str(t)] = collections.OrderedDict([
            ('type', t), ('family', 'daily'), ('kind', 'counter'),
            ('origin', 'game'), ('counter', counter),
            ('liveness', ach.liveness(t)),
            ('steps', [collections.OrderedDict([
                ('index', 1), ('target', target), ('prize', prize)])]),
        ])
        order.append(t)

    chest = []
    for band in ach.chest():
        lst = []
        for e in band.get('LivenessList', []):
            p = convert_prize(ach.prize_parts([e['PrizeID']]))
            item_ids.update(i for i, _n in p['items'])
            lst.append(collections.OrderedDict([('need', int(e['Liveness'])),
                                                ('prize', p)]))
        chest.append(collections.OrderedDict([('beginLevel', int(band['BeginLevel'])),
                                              ('list', lst)]))
    doc = collections.OrderedDict([('order', order), ('types', types),
                                   ('chest', chest), ('dropped', dropped)])
    return doc, item_ids


# Ky tu PHAI thoat trong chuoi Lua nhay kep. Ngoai ba cai nay va cac ky tu
# dieu khien, moi thu khac di thang qua duoc — ke ca dau ngoac va chu Han.
LUA_ESCAPE = {'\\': '\\\\', '"': '\\"', '\n': '\\n', '\r': '\\r', '\t': '\\t'}


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
    """Chuoi Lua nhay kep, thoat dung nhung gi Lua doi hoi.

    Truoc day cho la moi chuoi di qua day deu la ten tuong / ten cot / ten quy
    tac nen toan ky tu an toan, va chan bang mot danh sach cho phep rat hep.
    Du lieu goc phu nhan dieu do: co ten kieu 'Archer(new)', co ten chuong bang
    chu Han ('九伐中原', 'Đổng quân nhập xâm'), co ca dau ngoac full-width ')'.
    Nhung thu do KHONG can thoat trong chuoi Lua — chi \\ " va ky tu dieu khien
    moi can. Danh sach cho phep hep chi lam vo pipeline moi lan gap ten moi.

    Van giu tinh than cu: khong bao gio am tham sinh ra Lua hong. Chi khac la
    gio thoat that thay vi bao loi.
    """
    out = []
    for c in v:
        if c in LUA_ESCAPE:
            out.append(LUA_ESCAPE[c])
        elif ord(c) < 0x20 or ord(c) == 0x7F:
            out.append('\\%d' % ord(c))     # ky tu dieu khien -> \ddd
        else:
            out.append(c)                   # ke ca UTF-8, Lua giu nguyen byte
    return '"%s"' % ''.join(out)


LUA_KEYWORDS = frozenset(
    'and break do else elseif end false for function goto if in local nil not '
    'or repeat return then true until while'.split())

_LUA_IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*\Z')


def lua_identifier(k):
    """Khoa co viet tran duoc dang  key = ...  khong?

    KHONG dung str.isidentifier() cua Python o day. Python theo quy tac Unicode
    nen coi '海王boss' va 'Đổng' la dinh danh hop le, con Lua thi chi nhan ASCII
    — sinh ra la loi cu phap. No cung coi 'end' la dinh danh, ma 'end = {...}'
    thi Lua cung khong nuot.
    """
    return bool(_LUA_IDENT.match(k)) and k not in LUA_KEYWORDS


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
            key = k if lua_identifier(k) else '[%s]' % lua_str(k)
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
        ('equipSynthesis', doc['equipSynthesis']),
        ('exclusiveEquip', doc['exclusiveEquip']),
        ('equipQuality', doc['equipQuality']),
        ('weaponSkills', doc['weaponSkills']),
        ('items', doc['items']),
        ('achieve', doc['achieve']),
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
        # --all nghia la ca nhung thu CHUA CO ART, ke ca quan chung. Truoc
        # day cai co nay chi ap cho tuong, con quan chung van bi loc — nen
        # sinh lai bang so tren mot may thieu art la doi ca thanh phan quan
        # cua tung chuong, va doi hinh dang thang bong thua sach. Da dinh.
        if art and not a.all and name not in art:
            continue
        cur = best.get(name)
        if cur is None or int(x['HpBase']) < int(cur['HpBase']):
            best[name] = x
    army_rows = [collections.OrderedDict((k, best[n][k]) for k in ARMY_FIELDS)
                 for n in sorted(best)]

    form_order, form_map = formation_doc(forms)

    # Bang ghep do. Khoa "<loai>_<cap>" vi qua JSON thi khoa nao cung thanh
    # chuoi — de nguyen dang do cho ca ba ban doc giong nhau.
    syn = EquipSynthesis(a.config)
    syn_out = collections.OrderedDict()
    for (t, lv) in sorted(syn.by_key):
        syn_out['%d_%d' % (t, lv)] = syn.by_key[(t, lv)]

    # Trang bi chuyen thuoc. `forge` khoa theo "<heroID>_<part>" vi cung ly do
    # nhu tren; `purify` la mang 5 o x 21 bac.
    exc = ExclusiveEquip(a.config)
    forge_out = collections.OrderedDict()
    for hid in sorted(exc.forge, key=lambda x: int(x)):
        for part in sorted(exc.forge[hid], key=lambda x: int(x)):
            row = exc.forge[hid][part]
            forge_out['%s_%s' % (hid, part)] = collections.OrderedDict([
                ('purifyLevel', int(row.get('PurifyLevel', 5))),
                ('materials', [[int(m['ItemID']), int(m['Count'])]
                               for m in row.get('ItemList', [])]),
            ])
    # Nang pham chat: khoa la PHAM DICH (2..6).
    qual = EquipQuality(a.config)
    qual_out = collections.OrderedDict(
        (str(k), qual.by_quality[k]) for k in sorted(qual.by_quality))

    # Bang vat pham. Chi xuat nhung loai thuc su duoc nhac toi o dau do —
    # nguyen lieu ghep do / nang pham / ren chuyen thuoc, da tay luyen — cong
    # them loai co the roi ra. Xuat ca 619 dong thi phan lon la thu game moi
    # chua co cho dung.
    # Thanh tuu va nhiem vu ngay. Lam TRUOC bang vat pham: phan thuong co vat
    # pham, ma vat pham nao khong xuat ra thi may chu khong nhan vao tui duoc.
    ach = Achievements(a.config)
    task_out, task_items = task_doc(ach)

    items = Items(a.config)
    used = set()
    for row in syn.by_key.values():
        for mid, _n in row['materials']:
            used.add(int(mid))
    for row in qual.by_quality.values():
        for mid, _n in row['materials']:
            used.add(int(mid))
    for hid in exc.forge:
        for part in exc.forge[hid]:
            for m in exc.forge[hid][part].get('ItemList', []):
                used.add(int(m['ItemID']))
    used.add(97)          # da tay luyen
    missing = sorted(i for i in task_items if items.get(i) is None)
    if missing:
        sys.exit('phan thuong thanh tuu tro toi vat pham khong co trong bang: %s'
                 % missing)
    used |= task_items
    item_out = collections.OrderedDict()
    for i in sorted(used):
        row = items.get(i)
        if row is not None:
            item_out[str(i)] = row

    # Ky nang VU KHI chuyen thuoc, theo tung tuong. Ban goc goi mot bang
    # khong ton tai (ExclusiveWeaponSkillConfig), anh xa that nam trong engine
    # o map/heroex_config.xml + map/quality_config.xml.
    wsk = WeaponSkills(a.config)
    wsk_out = collections.OrderedDict()
    for hero in sorted(wsk.hero_skill):
        name, fields = wsk.fields_of(hero)
        wsk_out[hero] = collections.OrderedDict([
            ('skill', name),
            ('fields', collections.OrderedDict(sorted(fields.items()))),
        ])

    exc_out = collections.OrderedDict([
        ('heroes', [int(x) for x in exc.heroes]),
        ('forge', forge_out),
        ('purify', [[collections.OrderedDict([
            ('need', int(r['NeedConcentrate'])), ('percent', int(r['AddPrecent']))])
            for r in slot] for slot in exc.purify]),
    ])

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
            ('maxLevel', MAX_HERO_LEVEL),
        ])),
        ('heroes', rows),
        ('armies', army_rows),
        ('formationOrder', form_order),
        ('formations', form_map),
        ('reference', ref),
        # Bang ghep do: khoa "<loai>_<cap>" vi qua JSON thi khoa phai la
        # chuoi. Cot heroLevel vua la dieu kien cap tuong, vua la HE SO CAP
        # dung de tinh chi so chinh — xem sim/equipment.py.
        ('equipSynthesis', syn_out),
        ('exclusiveEquip', exc_out),
        ('equipQuality', qual_out),
        ('weaponSkills', wsk_out),
        ('items', item_out),
        ('achieve', task_out),
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
    print('  %d quan chung%s' % (len(army_rows),
          '' if a.all else ' co art'))
    print('  %d the tran (%s...)' % (len(form_order), ', '.join(form_order[:3])))
    fam = collections.Counter(d['family'] for d in task_out['types'].values())
    print('  %d chuoi thanh tuu (%d buoc), %d nhiem vu ngay; bo buoc khong dat duoc: %s'
          % (fam['achieve'],
             sum(len(d['steps']) for d in task_out['types'].values()
                 if d['family'] == 'achieve'),
             fam['daily'],
             ', '.join('loai %s: %d' % kv for kv in task_out['dropped'].items()) or '0'))
    print('  %d cap doi chieu, %d tran moi cap' % (len(ref), a.battles))
    for e in ref:
        print('     %-20s vs %-20s  %5.1f%% thang, %4.1f%% hoa'
              % (e['a'], e['b'], e['winPctA'], e['drawPct']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
