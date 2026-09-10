# -*- coding: utf-8 -*-
"""Doc bang so cua ban goc.

Cac file trong assets/config/share/ mang duoi .xgg nhung KHONG phai dinh dang
nhi phan sngXgg — chung la JSON thuan. Doc thang bang json.load.

Ba bang dung o day:

    KDBGameHero.xgg              92 tuong, 46 cot he so rieng
    KDBGameHeroCommonConfig.xgg  chi so goc dung chung cho moi tuong
    KDBGameArmyConfig.xgg        91 quan chung, 73 cot — bang day du nhat

Bang tuong KHONG chua chi so tuyet doi. No chua BAC:

    AttackCapability  2..8    bac cong
    Viability         2..8    bac thu
    GrowthFactor      1..4    bac tang truong
    QualityFactor     1       (bang nhau ca 92 tuong — khong dung)
    TypeFactor        1..5    trung khit HeroJobType, la cung mot thu

Chi so tuyet doi nam o GameHeroFightPropertyConfig: HpBase 1000, MinApBase 30,
MaxApBase 120, DpBase 30, AttackInterval 2.5.
"""
import os, re, json, collections

# Mac dinh tro sang repo dich nguoc nam canh. Du lieu do CO BAN QUYEN va khong
# nam trong repo nay.
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CONFIG = os.path.normpath(os.path.join(
    HERE, '..', '..', 'brave-cross', 'work', 'vn', 'decrypted',
    'assets', 'config', 'share'))


class TableError(Exception):
    pass


def load_json(config_dir, name):
    p = os.path.join(config_dir, name)
    if not os.path.isfile(p):
        raise TableError(
            'khong thay %s\n'
            'Bang so cua ban goc khong nam trong repo nay. Dung --config de tro\n'
            'toi thu muc assets/config/share da giai ma, hoac chay lai\n'
            'brave-cross/work/unpack.py de tao no.' % p)
    with open(p, encoding='utf-8') as fp:
        return json.load(fp)


class Heroes(object):
    """92 tuong cong voi khoi chi so goc dung chung."""

    def __init__(self, config_dir=DEFAULT_CONFIG):
        self.dir = config_dir
        self.rows = load_json(config_dir, 'KDBGameHero.xgg')
        common = load_json(config_dir, 'KDBGameHeroCommonConfig.xgg')
        base = None
        for e in common:
            if e.get('ConfigName') == 'GameHeroFightPropertyConfig':
                base = e.get('ConfigContent')
        if base is None:
            raise TableError('khong thay GameHeroFightPropertyConfig')
        if isinstance(base, str):
            base = json.loads(base)
        self.base = base
        self.by_id = {r['HeroID']: r for r in self.rows}
        self.by_sprite = {r['HeroSprite']: r for r in self.rows}

    def __len__(self):
        return len(self.rows)

    def get(self, key):
        """Tra ve ban ghi tuong theo HeroID hoac theo HeroSprite."""
        if key in self.by_sprite:
            return self.by_sprite[key]
        try:
            return self.by_id[int(key)]
        except (ValueError, KeyError):
            raise TableError('khong co tuong %r' % (key,))

    def names(self):
        return [r['HeroSprite'] for r in self.rows]

    def spread(self, col):
        """Pho gia tri mot cot — de soi bang truoc khi tin no."""
        return dict(sorted(collections.Counter(
            r[col] for r in self.rows).items(), key=lambda kv: str(kv[0])))


class Talents(object):
    """Ky nang rieng tung tuong.

    KDBGameHeroTalentSkill.xgg: 280 dong (HeroID, HeroQuality) -> ten ky nang.
    Mot tuong co nhieu dong vi len pham chat thi doi ky nang; o day lay dong
    PHAM CHAT THAP NHAT, tuc ky nang goc.

    Ban goc CHI LUU TEN. Hieu ung cua tung ky nang nam o server, khong co trong
    tay — xem sim/battle.py de biet o day dat hieu ung gi.
    """

    def __init__(self, config_dir=DEFAULT_CONFIG):
        rows = load_json(config_dir, 'KDBGameHeroTalentSkill.xgg')
        best = {}
        for r in rows:
            hid = int(r['HeroID'])
            q = int(r.get('HeroQuality', 0))
            if hid not in best or q < best[hid][0]:
                best[hid] = (q, str(r['TalentSkill']))
        self.by_id = {k: v[1] for k, v in best.items()}
        self.rows = rows

    def get(self, hero_id, default=''):
        return self.by_id.get(int(hero_id), default)

    def spread(self):
        return dict(sorted(collections.Counter(self.by_id.values()).items(),
                           key=lambda kv: -kv[1]))


class Armies(object):
    """91 quan chung. Bang nay co chi so TUYET DOI, khong phai bac."""

    def __init__(self, config_dir=DEFAULT_CONFIG):
        self.rows = load_json(config_dir, 'KDBGameArmyConfig.xgg')
        self.by_id = {r['ArmyTypeID']: r for r in self.rows}
        self.by_sprite = {r['SpriteName']: r for r in self.rows}

    def __len__(self):
        return len(self.rows)


class Formations(object):
    """The tran: KDBGameFormationConfig.xgg.

    Day la mot trong so it he thong cua ban goc con NGUYEN CA SO LIEU. Ky nang
    rieng cua tuong thi bang goc chi luu cai TEN (hieu ung nam o server, khong
    co trong tay) — con o day moi cap cua moi the tran ghi ro tang cai gi, tang
    bao nhieu, cho HANG NAO.

    12 the tran, moi cai mot so cap:

        jichu, wuxing, zhenwuqijie, ershibaxingxiu   cap 0..20
        bagua, tiangang, beidou                      cap 0..30
        heyi, yanyue, fangyuan, zhuixing, yulin      cap 0..50

    `PlacementType` 1/2/3 chinh la `Location` 1/2/3 cua bang quan chung — hang
    truoc, hang giua, hang sau. Nghia la the tran buff THEO HANG, khop dung voi
    cach dan quan da dung o sim/field.py.

    Bon kieu tri so, doc tu chinh so lieu:

        Promote             cong thang         (HP +200 moi cap o jichu)
        PromotePercent      he so kieu 1.003   (tang 0,3%)
        PromotePercentZero  phan tu 0: 0.003   (tang 0,3%)
        PromoteRates        diem phan tram: 5  (tang 5%)
    """

    # Ten buff cua ban goc -> ten trong mo hinh nay, kem cach doc tri so.
    #
    # Nhung loai KHONG doi duoc thi khong doi, chu khong doan bua:
    #   AllHeroReducingControl        mo hinh nay khong co hieu ung khong che
    #   *Melee/Arrow/Magic*           mo hinh nay khong chia loai sat thuong
    # Chung van duoc xuat ra de sau nay lam tiep, chi la khong dung toi.
    MAP = {
        'AllHeroHpPromote':                      ('hp', 'add'),
        'AllHeroHpPromotePercent':               ('hp_pct', 'pct'),
        'AllHeroApPromote':                      ('ap', 'add'),
        'AllHeroDpPromote':                      ('dp', 'add'),
        'AllHeroDpPromotePercent':               ('dp_pct', 'pct'),
        'AllHeroFinalDamagePercent':             ('dmg_pct', 'pct'),
        'AllHeroFinalReducingDamageRatesPercent': ('taken_pct', 'pct'),
        'AllHeroAttackDrainsRatePercent':        ('lifesteal', 'pct'),
        'AllHeroReboundDamagePercent':           ('reflect', 'pct'),
    }

    def __init__(self, config_dir=DEFAULT_CONFIG):
        rows = load_json(config_dir, 'KDBGameFormationConfig.xgg')
        self.rows = rows
        self.names = []
        self.by_name = collections.OrderedDict()
        for r in rows:
            n = r['Name']
            if n not in self.by_name:
                self.by_name[n] = {}
                self.names.append(n)
            self.by_name[n][int(r['Level'])] = r

    def max_level(self, name):
        return max(self.by_name[name])

    def gold(self, name, level):
        r = self.by_name[name].get(int(level))
        return int(r['CostGold']) if r else 0

    def buffs(self, name, level):
        """Buff cua mot the tran o mot cap, gom theo hang.

        Tra ve {1: {...}, 2: {...}, 3: {...}} voi khoa la ten trong mo hinh.
        Cac muc cong don duoc cong lai; cac muc phan tram cung vay (chung deu
        nho, va ban goc liet ke nhieu dong cung loai cho cung mot hang).
        """
        out = {1: {}, 2: {}, 3: {}}
        r = self.by_name.get(name, {}).get(int(level))
        if r is None:
            return out
        for sk in json.loads(r['SkillList']):
            m = self.MAP.get(sk.get('Type'))
            if m is None:
                continue
            key, kind = m
            place = int(sk.get('PlacementType', 1))
            if place not in out:
                continue
            if kind == 'add':
                v = float(sk.get('Promote', 0.0))
            else:
                # Ba ten truong khac nhau cho cung mot y: phan tang them.
                # PromotePercent ghi kieu 1.003 nen phai tru 1; hai cai kia da
                # la phan tu 0. PromoteRates tinh bang diem phan tram.
                if 'PromotePercent' in sk:
                    # Truong nay ghi kieu 1.003 (tang 0,3%) nen phai tru 1.
                    # Nhung so 0 o day KHONG phai he so 0 — no la "chua co buff"
                    # (cap 0 cua jichu ghi 0 o moi dong phan tram). Tru 1 cho no
                    # thanh -1.0, tuc la nhan giap voi 0: tuong hang truoc mat
                    # sach giap ngay khi vao game.
                    raw = float(sk['PromotePercent'])
                    v = 0.0 if raw == 0.0 else raw - 1.0
                elif 'PromotePercentZero' in sk:
                    v = float(sk['PromotePercentZero'])
                else:
                    v = float(sk.get('PromoteRates', 0.0)) / 100.0
            if v:
                out[place][key] = out[place].get(key, 0.0) + v
        return out


class EquipSynthesis(object):
    """Bang ghep do: KDBGameEquipmentSynthesisConfig.xgg — 250 ban ghi.

    Khoa la (EquipmentType, EquipLevel). EquipmentType = LOAI O * 10 + NGHE:
    vu khi 1..5, giap 21..25, giay 31..35, day chuyen 41..45, nhan 51..55
    (Protocol.lua:322). Nghe 1..5 = Warrior/Knight/Musicians/Master/Archer.

    Moi ban ghi:
        HeroLevel   cap tuong doi hoi — VA cung la HE SO CAP dung de tinh chi
                    so chinh (getEquipLevelCoefficient tra ve dung cot nay)
        GoldCost    vang de ghep len cap do
        MaterialID1..5 / Count1..5   nguyen lieu
    """

    def __init__(self, config_dir=DEFAULT_CONFIG):
        rows = load_json(config_dir, 'KDBGameEquipmentSynthesisConfig.xgg')
        self.by_key = {}
        for r in rows:
            t, lv = int(r['EquipmentType']), int(r['EquipLevel'])
            mats = []
            for i in (1, 2, 3, 4, 5):
                n = int(r.get('Count%d' % i, 0) or 0)
                if n > 0:
                    mats.append((int(r['MaterialID%d' % i]), n))
            self.by_key[(t, lv)] = collections.OrderedDict([
                ('heroLevel', int(r['HeroLevel'])),
                ('gold', int(r['GoldCost'])),
                ('materials', mats),
            ])
        self.types = sorted(set(t for t, _ in self.by_key))
        self.max_level = max(lv for _, lv in self.by_key)

    def get(self, equip_type, level):
        return self.by_key.get((int(equip_type), int(level)))

    def __len__(self):
        return len(self.by_key)


class Items(object):
    """Bang vat pham: KDBGameItemConfig.xgg — 619 dong.

    Cot dung toi:
        ItemID, ItemName        ten con la tieng Trung; giao dien dung ICON
        ItemType                1 tieu hao, 2 nguyen lieu, 3 dan duoc,
                                4 goi qua, 5 ruong, 6 nguyen lieu than binh,
                                8 goi chon, 9 anh dai dien  (Protocol.lua)
        MaxCount                gioi han moi loai trong tui (AddItem cat o day)
        Price                   gia BAN ra vang (GetItemSalePrice)
        Concentrate             phan giai ra bao nhieu tinh hoa (CUIRefineItem)
        Quality                 pham chat, dung de to mau icon
    """

    FIELDS = ('ItemID', 'ItemName', 'ItemType', 'MaxCount', 'Price',
              'Concentrate', 'Quality', 'Value')

    def __init__(self, config_dir=DEFAULT_CONFIG):
        rows = load_json(config_dir, 'KDBGameItemConfig.xgg')
        self.by_id = {}
        for r in rows:
            i = int(r['ItemID'])
            self.by_id[i] = collections.OrderedDict([
                ('name', str(r.get('ItemName', ''))),
                ('type', int(r.get('ItemType', 0))),
                ('maxCount', int(r.get('MaxCount', 0))),
                ('price', int(r.get('Price', 0))),
                ('concentrate', int(r.get('Concentrate', 0))),
                ('quality', int(r.get('Quality', 1))),
                ('value', int(r.get('Value', 0))),
            ])

    def get(self, item_id):
        return self.by_id.get(int(item_id))

    def __len__(self):
        return len(self.by_id)


class WeaponSkills(object):
    """Ky nang VU KHI chuyen thuoc, theo tung tuong.

    Ban goc co goi GetExclusiveWeaponSkillConfig(heroID) nhung bang do KHONG
    ton tai trong ban phat hanh — ham luon tra nil. Anh xa that nam trong
    engine, o hai file map/:

        heroex_config.xml    <ten>Exclus -> lsSkill  (13 tuong)
        quality_config.xml   dinh nghia tung ky nang, muc <exclusive>

    Nhieu ky nang la MAY TRANG THAI cua engine (phan don, hoi sinh, gay
    debuff) — khong quy ra chi so duoc. O day chi doc ten va cac truong SO;
    ben nao dung duoc thi dung, con lai giu ten de con biet.
    """

    SKILL_DIR = os.path.join('vn', 'decrypted', 'assets', 'map')

    def __init__(self, config_dir=DEFAULT_CONFIG):
        # map/ nam canh config/share/, lui hai bac.
        root = os.path.dirname(os.path.dirname(config_dir))
        self.hero_skill = {}
        self.skill_fields = {}
        hx = self._read(os.path.join(root, 'map', 'heroex_config.xml'))
        for m in re.finditer(r'<lsSkill>(.*?)</lsSkill>', hx, re.S):
            names = re.findall(r'<item>(\w+)</item>', m.group(1))
            before = re.findall(r'<sName>(\w+)</sName>', hx[:m.start()])
            var = before[-1] if before else ''
            if var.endswith('Exclus') and names:
                self.hero_skill[var[:-len('Exclus')]] = names[0]

        qc = self._read(os.path.join(root, 'map', 'quality_config.xml'))
        for blk in re.findall(r'<plug>(.*?)</plug>', qc, re.S):
            m = re.search(r'<sName>(\w+)</sName>', blk)
            if not m:
                continue
            fields = collections.OrderedDict()
            for k, v in re.findall(r'<([a-zA-Z]\w*)>([^<]*)</\1>', blk):
                v = v.strip()
                if k in ('sName',) or not v:
                    continue
                try:
                    fields[k] = float(v)
                except ValueError:
                    pass
            self.skill_fields[m.group(1)] = fields

    @staticmethod
    def _read(path):
        raw = open(path, 'rb').read()
        for enc in ('utf-8', 'gbk', 'gb18030'):
            try:
                return raw.decode(enc)
            except UnicodeDecodeError:
                continue
        return raw.decode('utf-8', 'replace')

    def fields_of(self, hero_sprite):
        name = self.hero_skill.get(hero_sprite)
        return name, self.skill_fields.get(name, {})

    def __len__(self):
        return len(self.hero_skill)


class EquipQuality(object):
    """Nang pham chat trang bi.

    KDBGameCommonConfig, muc ConfigName = "GameEquipQualityPromotionConfig":
    khoa la PHAM CHAT DICH (2..6), moi dong co UnlockLevel (cap tuong doi
    hoi), GoldCost, va toi da 4 cap (MaterialID, Count).

    Pham chat an vao HAI cho: chi so chinh (Q trong (L + 10 + Q*6)^1.45) va
    thuoc tinh phu (base * Q). Nen len mot pham la manh len ca hai duong.
    """

    def __init__(self, config_dir=DEFAULT_CONFIG):
        rows = load_json(config_dir, 'KDBGameCommonConfig.xgg')
        cfg = {}
        for e in rows:
            if e.get('ConfigName') == 'GameEquipQualityPromotionConfig':
                cfg = json.loads(e['ConfigContent'])
        self.by_quality = {}
        for k, r in cfg.items():
            mats = []
            for i in (1, 2, 3, 4, 5):
                n = int(r.get('Count%d' % i, 0) or 0)
                if n > 0:
                    mats.append((int(r['MaterialID%d' % i]), n))
            self.by_quality[int(k)] = collections.OrderedDict([
                ('unlockLevel', int(r.get('UnlockLevel', 1))),
                ('gold', int(r.get('GoldCost', 0))),
                ('materials', mats),
            ])
        self.max_quality = max(self.by_quality) if self.by_quality else 1

    def get(self, quality):
        return self.by_quality.get(int(quality))

    def __len__(self):
        return len(self.by_quality)


class ExclusiveEquip(object):
    """Trang bi chuyen thuoc: KDBGameExclusiveEquipConfig.xgg.

    Bon bang trong mot file:

        ExclusiveEquipHeroConfig        22 HeroID co do chuyen thuoc
        ExclusiveEquipForgeConfig       [heroID][partID] -> {ItemList, PurifyLevel}
                                        PurifyLevel = cap TINH LUYEN doi hoi
                                        cua mon do thuong truoc khi ren len
        ExclusiveEquipPurifyConfig      5 o x 21 cap {NeedConcentrate, AddPrecent}
                                        — duong tay RIENG, bat dau +25%
        ExclusiveEquipCommonSkillConfig o 2..5 -> ky nang chung
    """

    def __init__(self, config_dir=DEFAULT_CONFIG):
        rows = load_json(config_dir, 'KDBGameExclusiveEquipConfig.xgg')
        by = {}
        for e in rows:
            by[e['ConfigName']] = json.loads(e['ConfigContent'])
        self.heroes = [int(x) for x in by.get('ExclusiveEquipHeroConfig', [])]
        self.forge = by.get('ExclusiveEquipForgeConfig', {})
        self.purify = by.get('ExclusiveEquipPurifyConfig', [])
        self.skills = by.get('ExclusiveEquipCommonSkillConfig', {})

    def forge_of(self, hero_id, part):
        return (self.forge.get(str(int(hero_id))) or {}).get(str(int(part)))


def _json_field(v, strict=True):
    """Cot kieu JSON-nam-trong-chuoi cua ban goc. Chuoi rong nghia la khong co."""
    if not isinstance(v, str):
        return v
    if not v.strip():
        return None
    try:
        return json.loads(v)
    except ValueError:
        if strict:
            raise
        return v


class Achievements(object):
    """Thanh tuu va nhiem vu ngay: KDBGameAchieveConfig.xgg (357 dong).

    Mot bang cho NAM ho nhiem vu, phan biet bang khoang AchieveType
    (AchieveLogic.lua cua ban goc, ham ctor):

        0          diem danh — Award la 12 phan thuong, moi thang mot cai
        1..99      thanh tuu
        100..999   nhiem vu ngay
        1000..1999 nhiem vu huong dan
        2000..2999 nhiem vu bay ngay

    Moi loai la mot CHUOI buoc AchieveIndex 1..n.

    Cot AchieveCondition KHONG co o cac dong diem danh. Doc ten cot tu dong
    dau tien (la mot dong diem danh) se tuong bang nay khong co dieu kien —
    da nham dung the mot lan.

    Award la danh sach PrizeID tro sang KDBGamePrizeConfig.xgg (2341 dong).
    Diem nang dong va ruong nam trong KDBGameCommonConfig.xgg
    (DailyTaskLiveness, LivenessPrizeConfig).
    """

    def __init__(self, config_dir=DEFAULT_CONFIG):
        self.by_type = collections.OrderedDict()
        for r in load_json(config_dir, 'KDBGameAchieveConfig.xgg'):
            t = int(r['AchieveType'])
            self.by_type.setdefault(t, []).append(collections.OrderedDict([
                ('index', int(r['AchieveIndex'])),
                ('condition', _json_field(r.get('AchieveCondition')) or {}),
                ('award', [int(x) for x in (_json_field(r.get('Award')) or [])]),
            ]))
        for steps in self.by_type.values():
            steps.sort(key=lambda s: s['index'])

        self.prize = {}
        for p in load_json(config_dir, 'KDBGamePrizeConfig.xgg'):
            self.prize[int(p['PrizeID'])] = _json_field(p.get('PrizeContent')) or []

        # Bang chung co ca nhung dong khong phai JSON — doc long tay.
        self.common = {}
        for e in load_json(config_dir, 'KDBGameCommonConfig.xgg'):
            self.common[e.get('ConfigName')] = _json_field(
                e.get('ConfigContent'), strict=False)

    def chain(self, achieve_type):
        return self.by_type.get(int(achieve_type), [])

    def prize_parts(self, prize_ids):
        """Gop noi dung cua nhieu PrizeID thanh mot danh sach."""
        out = []
        for pid in prize_ids:
            if int(pid) not in self.prize:
                raise TableError('PrizeID %s khong co trong KDBGamePrizeConfig' % pid)
            out.extend(self.prize[int(pid)])
        return out

    def liveness(self, achieve_type):
        """Diem nang dong khi nhan mot nhiem vu ngay (DailyTaskLiveness).

        Loai khong co trong bang thi ban goc mac dinh 1. Loai 107 (the luc mien
        phi luc an trua / toi) khong cong diem nao — AwardAchieve bo qua han no.
        """
        if int(achieve_type) == 107:
            return 0
        table = self.common.get('DailyTaskLiveness') or {}
        return int(table.get(str(int(achieve_type)), 1))

    def chest(self):
        """LivenessPrizeConfig: [{BeginLevel, LivenessList: [{Liveness, PrizeID}]}]."""
        return self.common.get('LivenessPrizeConfig') or []


if __name__ == '__main__':
    import sys
    sys.stdout.reconfigure(encoding='utf-8')
    cfg = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CONFIG
    h = Heroes(cfg)
    a = Armies(cfg)
    print('%d tuong, %d quan chung, doc tu %s' % (len(h), len(a), cfg))
    print('\nchi so goc dung chung:')
    for k in ('HpBase', 'MinApBase', 'MaxApBase', 'DpBase', 'AttackInterval',
              'CriticalStrikeBase', 'CritDamageDouble'):
        print('   %-20s %s' % (k, h.base.get(k)))
    print('\npho cac cot bac:')
    for c in ('AttackCapability', 'Viability', 'GrowthFactor', 'QualityFactor',
              'AngerRecovery'):
        print('   %-20s %s' % (c, h.spread(c)))
