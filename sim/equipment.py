# -*- coding: utf-8 -*-
"""Mo hinh trang bi — chep dung cong thuc cua ban goc.

Nguon (xem brave-cross/work/GAMEPLAY.md, muc "Trang bi"):

    share_EquipmentLogic.lua          1638 dong  — cuong hoa, chi phi, pham chat
    share_EquipmentPropertyLogic.lua   640 dong  — gia tri cuong hoa theo loai
    share_configManager.lua:3221                 — trong so tinh luc chien
    Protocol.lua:466                             — enum PropertyType

KHONG tu can bang lai. Moi he so o day deu lay nguyen tu ma nguon ban goc, vi
do la thang so da qua nguoi choi that nhieu nam.

Mot mon trang bi:

    part            1..6   vu khi, giap, day chuyen, nhan, giay, o phu
    level                  cap mon do
    intensify              cap cuong hoa
    quality                pham chat
    main            (loai chi so, gia tri)
    appends         [(loai, gia tri), ...]  thuoc tinh phu, mo tu cap 4
"""
import math

# --- Protocol.lua:466 ---------------------------------------------------
HP_LIMIT = 1
REDUCING_DAMAGE = 3
FIRE_RES = 5
ICE_RES = 6
THUNDER_RES = 7
DP_ADDITION = 8
CRITICAL_STRIKE = 16
AP = 20

PROPERTY_NAME = {
    HP_LIMIT: 'HpLimit', REDUCING_DAMAGE: 'ReducingDamage',
    FIRE_RES: 'FireResistence', ICE_RES: 'IceResistence',
    THUNDER_RES: 'ThunderResistence', DP_ADDITION: 'DpAddtion',
    CRITICAL_STRIKE: 'CriticalStrike', AP: 'Ap',
}

# --- share_configManager.lua:3221 ---------------------------------------
# Trong so quy doi tung loai chi so ra LUC CHIEN. Bang nay noi len thang thiet
# ke: 1 diem chi mang dang 50, 1 diem mau dang 0.1 — tuc mau di theo hang nghin
# con chi mang theo phan tram.
CAPACITY_WEIGHT = {
    HP_LIMIT: 0.1,
    DP_ADDITION: 1.0,
    FIRE_RES: 18.0,
    ICE_RES: 18.0,
    THUNDER_RES: 18.0,
    CRITICAL_STRIKE: 50.0,
    AP: 0.9,
}

# --- share_EquipmentLogic.lua -------------------------------------------
APPEND_UNLOCK_LEVEL = 4        # AppendPropertyUnlockLevel
APPEND_RANGE_MIN = 0.8         # AppendPropertyRandomRangeMin
APPEND_RANGE_MAX = 1.3         # AppendPropertyRandomRangeMax
RECAST_ITEM_ID = 97            # RecastStroeItemID — da tay luyen

# Moi cap cuong hoa nhan them he so nay; qua 200 cap thi gap 2.4 lan.
INTENSIFY_STEP = math.pow(2.4, 1.0 / 200.0)

# --- Chi so chinh: sinh tu LOAI DO, CAP DO va PHAM CHAT -----------------
# share_EquipmentPropertyLogic:getMainPropertyValWithCoefficient
#
#   Ap        : 20    * (L + 10 + Q*6)^1.45 / (60 - J*6)
#   HpLimit   : 30    * (L + 10 + Q*5)^1.5  / (20 + J*10)
#   DpAddtion : 5     * (L + 10 + Q*6)^1.45 / (20 + J*8)
#
# L khong phai cap mon do ma la HE SO CAP: getEquipLevelCoefficient tra ve
# dung cot HeroLevel cua bang ghep do cho (loai, cap). Tuc bang ghep do vua la
# bang gia, vua la thang suc manh.
#
# EquipmentType = LOAI O * 10 + NGHE (Protocol.lua:322), nghe = type % 10.
EQUIP_CATEGORY_WEAPON = 0
EQUIP_CATEGORY_ARMOR = 20
EQUIP_CATEGORY_SHOES = 30
EQUIP_CATEGORY_NECKLACE = 40
EQUIP_CATEGORY_RING = 50

# EquipMainPropertyTypeMap — o nao cho chi so gi.
MAIN_PROPERTY_BY_CATEGORY = {
    EQUIP_CATEGORY_WEAPON: AP,
    EQUIP_CATEGORY_ARMOR: DP_ADDITION,
    EQUIP_CATEGORY_SHOES: HP_LIMIT,
    EQUIP_CATEGORY_NECKLACE: HP_LIMIT,
    EQUIP_CATEGORY_RING: DP_ADDITION,
}

# MainPropertyCoefficientMap
MAIN_PROPERTY_COEF = {
    HP_LIMIT: 30.0,
    DP_ADDITION: 5.0,
    CRITICAL_STRIKE: 0.0025,
    AP: 20.0,
}

# HeroJobTypeCoefficientMap: Warrior 1, Knight 2, Musicians 3, Master 4, Archer 5
JOB_WARRIOR, JOB_KNIGHT, JOB_MUSICIAN, JOB_MASTER, JOB_ARCHER = 1, 2, 3, 4, 5
JOB_COEF = {1: 1.0, 2: 2.0, 3: 3.0, 4: 4.0, 5: 5.0}


def equip_job(equip_type):
    """Nghe cua mot loai trang bi. share_EquipmentLogic:getEquipmentJobType..."""
    return int(equip_type) % 10


def equip_category(equip_type):
    """Loai o (0 vu khi, 20 giap, 30 giay, 40 day chuyen, 50 nhan)."""
    return int(equip_type) - equip_job(equip_type)


def main_property_type(equip_type):
    return MAIN_PROPERTY_BY_CATEGORY.get(equip_category(equip_type))


def main_property_val(prop_type, level_coef, quality, job):
    """Chi so chinh goc, truoc tinh luyen va cuong hoa.

    `level_coef` la cot HeroLevel cua bang ghep do, KHONG phai cap mon do.

    Chi ba loai chi so co cong thuc. CriticalStrike KHONG co nhanh nao trong
    ham goc — nhanh thu tu la mot ban sao cua DpAddtion, ro rang la loi go cua
    tac gia — nen do (ngua, canh) khong sinh duoc chi so chinh. Trung khop voi
    chuyen bang cuong hoa cung chi co ba loai do.
    """
    coef = MAIN_PROPERTY_COEF.get(prop_type)
    j = JOB_COEF.get(int(job))
    if coef is None or j is None:
        return 0.0
    q = float(quality)
    lc = float(level_coef)
    if prop_type == AP:
        return coef * math.pow(lc + 10.0 + q * 6.0, 1.45) / (60.0 - j * 6.0)
    if prop_type == HP_LIMIT:
        return coef * math.pow(lc + 10.0 + q * 5.0, 1.5) / (20.0 + j * 10.0)
    if prop_type == DP_ADDITION:
        return coef * math.pow(lc + 10.0 + q * 6.0, 1.45) / (20.0 + j * 8.0)
    return 0.0


# --- Tinh luyen (RefineLevel) ------------------------------------------
# Bang lay tu KDBGameCommonConfig, muc ConfigName = "EquipRefineConfig":
# mot mang 5 o, moi o 5 cap, moi cap {NeedConcentrate, AddPrecent}.
#
# Tinh luyen CONG PHAN TRAM vao chi so chinh, khong cong thang mot luong:
#   share_EquipmentPropertyLogic:getMainPropertyVal
#   val = val + val * AddPrecent / 100
MAX_REFINE_LEVEL = 5
REFINE_ADD_PERCENT = (5, 10, 15, 20, 25)
# Vu khi dat hon cac o khac dung mot bac — bang goc ghi the.
REFINE_COST_WEAPON = (40, 80, 160, 320, 640)
REFINE_COST_OTHER = (30, 60, 120, 240, 480)
# Gia tinh bang TINH HOA (Concentrate), ResourceType 8 — mot loai tai nguyen
# rieng cua nguoi choi, khong phai vang. Ban goc cho tinh hoa tu viec phan giai
# vat pham (RPC ClientRefineItem, moi vat pham mot gia tri Concentrate).
VIP_REFINE_DISCOUNT_LEVEL = 10      # HeroLogic:GetUpgradeRefineCost
VIP_REFINE_DISCOUNT = 0.2


# --- Nang pham chat (PromoteQualityEquipment) --------------------------
# Bang: KDBGameCommonConfig / GameEquipQualityPromotionConfig, khoa la PHAM
# DICH (2..6). Moi dong co UnlockLevel (cap tuong doi hoi), GoldCost va
# nguyen lieu.
#
# Pham chat an vao HAI cho, nen len mot pham la manh len ca hai duong:
#   chi so chinh   (L + 10 + Q*6)^1.45
#   thuoc tinh phu (base * Q - 0.3)
MAX_QUALITY = 6


def quality_row(table, quality):
    """Mot dong bang nang pham. `table` la {"<pham>": {...}} da xuat."""
    return (table or {}).get(str(int(quality)))


def quality_ready(table, quality, hero_level):
    """(duoc phep khong, ly do). Chua tinh vang — vang do may chu tru."""
    if int(quality) >= MAX_QUALITY:
        return False, 'da toi pham cao nhat'
    row = quality_row(table, int(quality) + 1)
    if row is None:
        return False, 'khong co cong thuc nang len pham %d' % (int(quality) + 1)
    if int(hero_level) < int(row['unlockLevel']):
        return False, 'can tuong cap %d' % int(row['unlockLevel'])
    return True, ''


# --- Thuoc tinh phu va tay luyen (RecastEquipment) ---------------------
# share_EquipmentPropertyLogic:getAppendPropertyValue
#
#   value = coef * (base * quality - 0.3) * (levelCoef / 20)
#
# `base` la so BOC RA trong dai 0.8..1.3; tay luyen chinh la boc lai no.
# `coef` lay tu AppendPropertyCoefficient (share_EquipmentLogic:68).
AP_MIN = 22
AP_MAX = 23
CRIT_MULT = 25

APPEND_COEF = {
    HP_LIMIT: 40.0,
    AP_MIN: 2.7,
    AP_MAX: 11.8,
    DP_ADDITION: 2.5,
    CRITICAL_STRIKE: 0.1,
    CRIT_MULT: 50.0,
}

# Thuoc tinh phu QUY RA LUC CHIEN theo DAI BOC DUOC, khong phai theo gia tri
# nhan trong so — day la cho de nham nhat trong ca he:
#   CalcEquipFightingCapacity: `if BaseValue > band and score > val`
AAPPEND_SCORE_BANDS = ((1.2, 60), (1.1, 40), (1.0, 30), (0.9, 20), (0.8, 10))

# Ban goc: 10 000 vang, hoac 100 kim cuong, hoac MOT vien da tay luyen
# (vat pham 97) — dung da thi khong ton tien.
RECAST_COST_GOLD = 10000
RECAST_COST_DIAMOND = 100

# Loai chi so phu -> kenh buff, kem he so doi don vi. Chi mang va he so sat
# thuong chi mang cua ban goc tinh theo DIEM PHAN TRAM (CriticalStrikeBase = 1
# nghia la 1%), con mo hinh chien dau ben nay dung phan so — nen chia 100.
APPEND_TO_BUFF = {
    HP_LIMIT: ('hp', 1.0),
    AP_MAX: ('ap', 1.0),
    AP_MIN: ('ap', 1.0),
    DP_ADDITION: ('dp', 1.0),
    CRITICAL_STRIKE: ('crit', 0.01),
    CRIT_MULT: ('crit_mult', 0.01),
}


def append_value(base, prop_type, quality, level_coef):
    """Gia tri mot thuoc tinh phu. getAppendPropertyValue."""
    coef = APPEND_COEF.get(prop_type)
    if coef is None:
        return 0.0
    return coef * (float(base) * float(quality) - 0.3) * (float(level_coef) / 20.0)


def append_score(base):
    """Diem luc chien cua mot thuoc tinh phu, cham theo DAI boc duoc."""
    val = 0
    for band, score in AAPPEND_SCORE_BANDS:
        if float(base) > band and score > val:
            val = score
    return val


def roll_append_base(rand):
    """Boc mot lan: so trong dai 0.8..1.3."""
    return APPEND_RANGE_MIN + rand() * (APPEND_RANGE_MAX - APPEND_RANGE_MIN)


def make_append(prop_type, base, quality, level_coef):
    """(loai, gia tri, base) — giu ca `base` vi luc chien cham theo no."""
    return (prop_type, append_value(base, prop_type, quality, level_coef), base)


# --- Trang bi chuyen thuoc (ExclusiveEquip) ----------------------------
# Mon do thuong tay toi bac 5 (+25%) thi REN len duoc thanh do chuyen thuoc —
# neu tuong do nam trong danh sach 22 tuong co do rieng. Do chuyen thuoc dung
# mot duong tay KHAC HAN: 21 bac (0..20), bat dau ngay o +25% va len toi
# +125%. Tuc no noi tiep dung cho duong thuong dung lai.
#
# Bang: KDBGameExclusiveEquipConfig / ExclusiveEquipPurifyConfig.
MAX_PURIFY_LEVEL = 20

# Ky nang cua do chuyen thuoc (ExclusiveEquipCommonSkillConfig + quality_config
# .xml). O 1 (vu khi) co ky nang RIENG theo tung tuong, khong nam o day.
EXCLUSIVE_SKILL = {
    2: ('ZhuanShuYiFu', 'immune_normal', 0.10),   # 10% mien mot don thuong
    3: ('ZhuanShuXieZi', 'taken_skill', -0.15),   # chiu it hon 15% don ky nang
    4: ('ZhuanShuXiangLian', 'crit', 0.10),       # +10% chi mang
    5: ('ZhuanShuJieZhi', 'crit_mult', 0.25),     # +0.25 he so sat thuong chi mang
}


# Ky nang VU KHI chuyen thuoc, rieng tung tuong (o 1).
#
# Ban goc CO goi GetExclusiveWeaponSkillConfig(heroID), nhung bang do khong
# ton tai trong ban phat hanh — ham luon tra nil. Anh xa that nam ben engine:
# map/heroex_config.xml (<ten>Exclus -> lsSkill) va map/quality_config.xml
# (dinh nghia tung ky nang). Ca hai da duoc xuat ra `weaponSkills`.
#
# Nhieu ky nang la MAY TRANG THAI cua engine — phan don, hoi sinh, gay debuff,
# doi hinh dang — khong quy ra chi so duoc. O day chi lay nhung truong SO ma
# mo hinh chien dau ben nay CO cho nhan; con lai giu ten de biet la co, va
# danh dau modelled = False chu khong bia hanh vi.
WEAPON_SKILL_FIELD = {
    # truong cua ban goc -> (kenh buff, he so doi don vi)
    'fPiercingByLevel': ('pierce', 0.01),        # 10 -> 10% pha giap
    'fAddFuryForHero': ('anger', 1.0),           # cong thang vao no moi don
    'fAddAttackSpeed': ('interval_pct', -1.0),   # nhanh hon = khoang cach ngan lai
    'fAddAttackIntervalPercent': ('interval_pct', 1.0),
    'fAddCritDamageDouble': ('crit_mult', 1.0),
}

# CHI nhung truong duoc liet ke o day moi duoc dung. Khong lay bua moi truong
# so trong bang: nhieu truong co DIEU KIEN hoac NHIP di kem ma mo hinh chien
# dau ben nay khong co cho, ap thang vao la sai han:
#
#   ShenMaoQingLongYanYue  fAddHitDrainsRate 2.5 — nhung chi khi mau duoi 20%
#                          (fHpUnderPercent). Ap vo dieu kien la hut mau 250%.
#   YueShiYinSuoJinLing    fAddFury 13 moi 5 GIAY (fAddFuryInterval), khong
#                          phai moi don danh — mo hinh o day tinh no theo don.
#   ShenQiangLongDan,      phan don / hoi sinh / gay debuff / doi hinh dang:
#   ShenJiFangTian,        deu la may trang thai cua engine.
#   FengBaoZhiLi, ...
#
# Nhung ky nang do van duoc GHI TEN tren mon do — nguoi choi thay minh co gi —
# chi la chua mo phong, va bao ro nhu vay.
WEAPON_SKILL_USE = {
    'ShenQinRaoLiang': ('fPiercingByLevel', 'fAddFuryForHero'),
    'BingJianTianShu': ('fAddAttackSpeed', 'fAddCritDamageDouble'),
    'BingJianGongShu': ('fAddAttackIntervalPercent',),
}


def weapon_skill(table, hero_sprite):
    """(ten ky nang, bang buff, co mo phong duoc khong).

    `table` la khoi `weaponSkills` da xuat. Tuong khong co do rieng thi tra
    (None, {}, False). Co ten ma chua mo phong duoc thi tra (ten, {}, False).
    """
    row = (table or {}).get(str(hero_sprite))
    if row is None:
        return None, {}, False
    name = row.get('skill')
    use = WEAPON_SKILL_USE.get(name)
    if not use:
        return name, {}, False
    fields = row.get('fields') or {}
    buffs = {}
    for k in use:
        if k not in fields:
            continue
        pair = WEAPON_SKILL_FIELD.get(k)
        if pair is None:
            continue
        buffs[pair[0]] = buffs.get(pair[0], 0.0) + float(fields[k]) * pair[1]
    return name, buffs, bool(buffs)


def exclusive_percent(purify_table, part, purify_level):
    """Phan tram cong vao chi so chinh cua do CHUYEN THUOC.

    Khac do thuong o cho no co gia tri ngay tu bac 0 (+25%): ban goc viet
    `bIsExclusive == true and nRefineLevel >= 0`, chu khong phai `> 0`.
    """
    rows = _purify_rows(purify_table, part)
    if not rows:
        return 0.0
    i = max(0, min(int(purify_level), len(rows) - 1))
    return float(rows[i]['AddPrecent'])


def exclusive_cost(purify_table, part, purify_level):
    """Tinh hoa de len bac tay `purify_level` (1..20) cua do chuyen thuoc."""
    rows = _purify_rows(purify_table, part)
    if not rows or not 1 <= int(purify_level) <= len(rows) - 1:
        return 0
    return int(rows[int(purify_level)]['NeedConcentrate'])


def _purify_rows(purify_table, part):
    """Bang tay cua mot o. Ban goc chi co 5 o; o 6 chua co bang rieng."""
    if not purify_table:
        return None
    i = int(part) - 1
    if 0 <= i < len(purify_table):
        return purify_table[i]
    return None


def exclusive_ready(hero_ids, hero_id, part, refine_level, forge_row):
    """(ren duoc khong, ly do). Dieu kien cua ban goc:

      * tuong phai nam trong ExclusiveEquipHeroConfig
      * mon do thuong phai tay toi cap ghi trong ExclusiveEquipForgeConfig
        (mau la 5 — tuc kich toi da cua duong tay thuong)
      * va het nguyen lieu trong ItemList — cho nay game moi chua co he vat
        pham nen chua tru duoc, xem ghi chu trong server/modules/battle.lua
    """
    if int(hero_id) not in [int(x) for x in (hero_ids or [])]:
        return False, 'tuong nay khong co do chuyen thuoc'
    if forge_row is None:
        return False, 'khong co cong thuc ren cho o nay'
    need = int(forge_row.get('PurifyLevel', MAX_REFINE_LEVEL))
    if int(refine_level) < need:
        return False, 'can tinh luyen bac %d' % need
    return True, ''


def refine_percent(refine_level):
    """Phan tram cong them vao chi so chinh o cap tinh luyen nay."""
    if 1 <= refine_level <= MAX_REFINE_LEVEL:
        return float(REFINE_ADD_PERCENT[refine_level - 1])
    return 0.0


def refine_multiplier(refine_level):
    return 1.0 + refine_percent(refine_level) / 100.0


def refine_cost(part, refine_level, vip_level=0):
    """Tinh hoa can de len cap tinh luyen `refine_level` (1..5).

    VIP 10 tro len duoc giam 20%, lam TRON LEN — HeroLogic:GetUpgradeRefineCost.
    """
    if not 1 <= refine_level <= MAX_REFINE_LEVEL:
        return 0
    table = REFINE_COST_WEAPON if part == 1 else REFINE_COST_OTHER
    cost = table[refine_level - 1]
    if vip_level >= VIP_REFINE_DISCOUNT_LEVEL:
        return int(math.ceil(cost * (1.0 - VIP_REFINE_DISCOUNT)))
    return cost


def intensify_increment(level, value):
    """increment = (Val / 25) * (2.4^(1/200))^level

    share_EquipmentLogic:GetIntensifiedIncrementWithLevel
    """
    return (value / 25.0) * math.pow(INTENSIFY_STEP, level)


# Gia tri cuong hoa phu thuoc LOAI chi so: moi loai mot mau so va mot moc rieng.
# share_EquipmentPropertyLogic:getIntensifyPropertyVal
_INTENSIFY_BY_TYPE = {
    AP: (35.0, 10),
    HP_LIMIT: (25.0, 50),
    DP_ADDITION: (30.0, 50),
}


def intensify_property_val(main_value, prop_type, intensify_level=0):
    """Gia tri cuong hoa DUNG DE TINH LUC CHIEN, y het client ban goc.

    Client ban goc KHONG dung intensify_level o day — no dung mot moc CO DINH
    rieng cho tung loai (Ap moc 10, HpLimit va DpAddtion moc 50). Da kiem: cong
    thuc co dung level (GetIntensifiedIncrementWithLevel) chi duoc goi tu
    GetIntensifiedIncrement, ma ham do BI COMMENT TOAN BO trong ban phat hanh
    — tuc la ma chet.

    He qua: o client ban goc, cuong hoa KHONG lam doi luc chien hien thi qua
    duong nay. Duong tang chi so that su do MAY CHU quyet va gui xuong; client
    chi hien lai. Xem intensify_total() cho phan do.
    """
    spec = _INTENSIFY_BY_TYPE.get(prop_type)
    if spec is None:
        return 0.0
    divisor, exponent = spec
    return main_value / divisor * math.pow(INTENSIFY_STEP, exponent)



def intensify_total(intensify_level, base_value):
    """Tong gia tri cuong hoa cong don tu cap 1 den `intensify_level`.

    Day la cong thuc cua CHINH TAC GIA ban goc, trong GetIntensifiedIncrement:

        increment = sum( (Val/25) * step^i  for i in 1..level )

    Nhung ham do da bi comment toan bo trong ban phat hanh, nen duong tang chi
    so that o ban goc nam ben MAY CHU — thu ta khong co. Game moi dung lai cong
    thuc nay vi no la y do goc cua tac gia, va la co so hop ly nhat co duoc.
    Danh dau ro de sau nay biet day KHONG phai hanh vi da quan sat duoc.
    """
    return sum(intensify_increment(i, base_value)
               for i in range(1, intensify_level + 1))

def intensify_cost(intensify_level):
    """Chi phi len cap cuong hoa tiep theo.

    Nhan doi moi 4.5 cap luc dau, gian ra 6.5 cap sau cap 31 — ban goc co y
    lam cham lam phat o khoang giua.

    share_EquipmentLogic:GetResourceForIntensifyWithQualityAndLevel
    """
    n = intensify_level - 1
    if n > 30:
        return 140.0 * math.pow(math.pow(2.0, 1.0 / 6.5), n)
    return 25.0 * math.pow(math.pow(2.0, 1.0 / 4.5), n)


def quality_range(base_value, coefficient, quality):
    """(baseVal/coefficient + 0.3) / quality

    share_EquipmentLogic:GetQualityRange
    """
    if not coefficient or not quality:
        return 0.0
    return (base_value / coefficient + 0.3) / quality


def weight_of(prop_type):
    return CAPACITY_WEIGHT.get(prop_type, 0.0)


# --- Ghep do (SynthesisEquipment) --------------------------------------
# share_EquipmentLogic:SynthesisEquipment — ghep do la NANG CAP MON DO len
# mot cap: tru vang, tru nguyen lieu, roi EquipLevel + 1. Bang gia va dieu
# kien cap tuong nam trong KDBGameEquipmentSynthesisConfig (250 ban ghi).
#
# Chi so chinh duoc tinh LAI theo cap moi, vi he so cap chinh la cot HeroLevel
# cua bang do — nen len mot cap la manh len that, khong phai chi doi icon.
MAX_EQUIP_LEVEL = 10


def synthesis_row(table, equip_type, level):
    """Mot dong bang ghep do. `table` la {"<loai>_<cap>": {...}} da xuat."""
    return (table or {}).get('%d_%d' % (int(equip_type), int(level)))


def synthesis_ready(table, equip_type, level, hero_level):
    """(duoc phep khong, ly do). Chua tinh vang — vang do may chu tru.

    Ban goc CO cot HeroLevel va co doc no, nhung cho kiem lai vo hieu: dieu
    kien viet la `if HeroLevel < need then if ProcessError(bRecode) ...`, ma
    bRecode luc do dang la true nen than lenh khong bao gio chay. Tuc ban phat
    hanh KHONG chan theo cap tuong. O day ta chan — mot dieu kien co trong
    bang ma khong ai kiem thi bang do vo nghia.
    """
    if int(level) >= MAX_EQUIP_LEVEL:
        return False, 'da toi cap cao nhat'
    row = synthesis_row(table, equip_type, int(level) + 1)
    if row is None:
        return False, 'khong co cong thuc ghep cho loai %s cap %d' % (
            equip_type, int(level) + 1)
    if int(hero_level) < int(row['heroLevel']):
        return False, 'can tuong cap %d' % int(row['heroLevel'])
    return True, ''


def level_coefficient(table, equip_type, level):
    """He so cap dung de tinh chi so chinh — chinh la cot HeroLevel.

    share_EquipmentPropertyLogic:getEquipLevelCoefficient
    """
    row = synthesis_row(table, equip_type, level)
    return float(row['heroLevel']) if row else 0.0


def make_equipment(table, equip_type, level, quality, part, **kw):
    """Dung mon do dung kieu ban goc: chi so chinh SINH RA tu loai/cap/pham."""
    ptype = main_property_type(equip_type)
    val = main_property_val(ptype, level_coefficient(table, equip_type, level),
                            quality, equip_job(equip_type))
    return Equipment(part, (ptype, val), level=level, quality=quality,
                     equip_type=equip_type, **kw)


class Equipment(object):
    """Mot mon trang bi."""

    __slots__ = ('part', 'level', 'intensify', 'quality', 'refine',
                 'equip_type', 'exclusive', 'purify', 'purify_percent',
                 'main', 'appends')

    def __init__(self, part, main, level=1, intensify=0, quality=1,
                 appends=None, refine=0, equip_type=0, exclusive=False,
                 purify=0, purify_percent=0.0):
        self.part = part
        # LOAI trang bi cua ban goc = o * 10 + nghe. Quyet ca chi so chinh la
        # gi lan he so nghe dung de tinh no.
        self.equip_type = equip_type
        self.level = level
        self.intensify = intensify
        self.quality = quality
        self.refine = refine                  # 0..5, moi cap cong % chi so chinh
        # Do chuyen thuoc: duong tay RIENG, 21 bac, bat dau ngay o +25%.
        # `purify_percent` la con so DA TRA tu bang — giu san tren mon do de
        # stats()/capacity() khong phai keo theo ca bang di khap noi.
        self.exclusive = bool(exclusive)
        self.purify = purify
        self.purify_percent = purify_percent
        self.main = main                      # (prop_type, value)
        self.appends = list(appends or [])    # [(prop_type, value), ...]

    # --------------------------------------------------------------- chi so
    def append_unlocked(self):
        return self.level >= APPEND_UNLOCK_LEVEL

    def bonus_percent(self):
        """Phan tram cong vao chi so chinh: duong thuong hay duong chuyen thuoc."""
        if self.exclusive:
            return self.purify_percent
        return refine_percent(self.refine)

    def main_value(self):
        """Chi so chinh sau tinh luyen (hoac tay, neu la do chuyen thuoc).

        Ban goc nhan phan tram nay NGAY TRONG getMainPropertyVal, tuc moi thu
        tinh sau do — ke ca cuong hoa — deu dua tren con so da nhan.
        """
        return self.main[1] * (1.0 + self.bonus_percent() / 100.0)

    def stats(self):
        """{loai chi so: tong gia tri} sau tinh luyen, cuong hoa, thuoc tinh phu."""
        out = {}
        ptype = self.main[0]
        pval = self.main_value()
        out[ptype] = out.get(ptype, 0.0) + pval
        # Chi so THAT: dung duong cong don theo cap (cong thuc goc cua tac gia).
        bonus = intensify_total(self.intensify, pval)
        if bonus:
            out[ptype] = out.get(ptype, 0.0) + bonus
        if self.append_unlocked():
            for ap in self.appends:
                t, v = ap[0], ap[1]
                out[t] = out.get(t, 0.0) + v
        return out

    def capacity(self):
        """Luc chien mon do. CalcEquipFightingCapacity:

            chi so chinh * trong so
          + phan cuong hoa * trong so
          + TONG DIEM cua cac thuoc tinh phu

        Thuoc tinh phu KHONG nhan trong so — no cham theo DAI boc duoc
        (0.8 -> 10 diem, 1.2 -> 60 diem). Cho nay de nham nhat trong ca he.
        """
        ptype = self.main[0]
        st = self.stats()
        out = st.get(ptype, 0.0) * weight_of(ptype)
        if self.append_unlocked():
            for ap in self.appends:
                out += append_score(ap[2] if len(ap) > 2 else 1.0)
        return out

    def capacity_as_original(self):
        """Luc chien tinh Y HET client ban goc, de doi chieu.

        Khac capacity() o cho dung intensify_property_val (moc co dinh) thay vi
        intensify_total (cong don theo cap) — nen KHONG doi theo cap cuong hoa.
        share_EquipmentLogic:CalcEquipFightingCapacity
        """
        ptype = self.main[0]
        pval = self.main_value()
        total = pval + intensify_property_val(pval, ptype)
        out = total * weight_of(ptype)
        if self.append_unlocked():
            for ap in self.appends:
                out += append_score(ap[2] if len(ap) > 2 else 1.0)
        return out

    # --------------------------------------------------------------- nuoi
    def cost_to_next(self):
        return intensify_cost(self.intensify + 1)

    def refine_cost_next(self, vip_level=0):
        """Tinh hoa can de tinh luyen len mot cap. Het cap thi 0."""
        if self.refine >= MAX_REFINE_LEVEL:
            return 0
        return refine_cost(self.part, self.refine + 1, vip_level)

    def purify_cost_next(self, purify_table):
        """Tinh hoa de len mot bac tren duong tay cua do chuyen thuoc."""
        if not self.exclusive or self.purify >= MAX_PURIFY_LEVEL:
            return 0
        return exclusive_cost(purify_table, self.part, self.purify + 1)

    def recast(self, rand, level_coef):
        """Tay luyen: boc LAI toan bo thuoc tinh phu.

        Ban goc chi boc lai `BaseValue` roi tinh lai `Value`
        (updateAppendProperty) — loai chi so giu nguyen, chi con so doi.
        """
        out = []
        for ap in self.appends:
            base = roll_append_base(rand)
            out.append(make_append(ap[0], base, self.quality, level_coef))
        self.appends = out
        return out

    def append_score_total(self):
        """Tong diem cac thuoc tinh phu — de so truoc/sau khi tay."""
        if not self.append_unlocked():
            return 0
        return sum(append_score(ap[2] if len(ap) > 2 else 1.0)
                   for ap in self.appends)

    def skills(self):
        """Ky nang mon do cho. Chi do chuyen thuoc moi co.

        O 1 (vu khi) co ky nang rieng theo tung tuong — khong nam trong bang
        chung nen chua dua vao day.
        """
        if not self.exclusive:
            return []
        row = EXCLUSIVE_SKILL.get(self.part)
        return [row] if row else []

    def cost_to_level(self, target):
        """Tong chi phi cuong hoa tu cap hien tai len `target`."""
        if target <= self.intensify:
            return 0.0
        return sum(intensify_cost(lv) for lv in range(self.intensify + 1, target + 1))

    def __repr__(self):
        return 'Equipment(part=%d, %s=%.1f, +%d, tinh luyen %d, q%d, luc chien %.0f)' % (
            self.part, PROPERTY_NAME.get(self.main[0], '?'), self.main[1],
            self.intensify, self.refine, self.quality, self.capacity())


def roll_append(base_value, rand):
    """Gia tri mot thuoc tinh phu: ngau nhien 0.8..1.3 lan gia tri goc.

    `rand` la ham tra ve so trong [0,1) — truyen vao de con dat hat giong,
    dung kieu cua sim/battle.py.
    """
    return base_value * (APPEND_RANGE_MIN
                         + rand() * (APPEND_RANGE_MAX - APPEND_RANGE_MIN))


# Trang bi noi vao mo hinh chien dau qua DUNG cai kenh buff ma the tran dang
# dung (xem Fighter.__init__ trong sim/battle.py) — khong mo duong rieng.
#
# Bon loai chi so co cho tuong ung; ba loai khang he (lua/bang/set) va
# ReducingDamage thi CHUA co he tuong ung ben game moi, nen bo qua co y thuc
# chu khong am tham quy ra thu khac.
BUFF_KEY = {
    HP_LIMIT: 'hp',
    AP: 'ap',
    DP_ADDITION: 'dp',
    CRITICAL_STRIKE: 'crit',
}


def to_buffs(items):
    """Gop chi so cua mot dam trang bi thanh bang buff cho mo hinh chien dau.

    Ke ca ky nang cua do chuyen thuoc: bon ky nang chung deu quy duoc ve kenh
    buff san co hoac gan san co (crit, crit_mult, taken_skill, immune_normal).
    """
    out = {}
    for e in items:
        main_t = e.main[0]
        st = e.stats()
        # Chi so CHINH (da gom cuong hoa) di theo bang BUFF_KEY.
        k = BUFF_KEY.get(main_t)
        if k is not None:
            out[k] = out.get(k, 0.0) + st.get(main_t, 0.0)
        # Thuoc tinh PHU co bang rieng, vi don vi khac (chi mang tinh theo
        # diem phan tram trong bang goc, con mo hinh o day dung phan so).
        if e.append_unlocked():
            for ap in e.appends:
                pair = APPEND_TO_BUFF.get(ap[0])
                if pair is None:
                    continue
                out[pair[0]] = out.get(pair[0], 0.0) + ap[1] * pair[1]
        for _name, key, val in e.skills():
            out[key] = out.get(key, 0.0) + val
    return out


def merge_buffs(a, b):
    """Cong hai bang buff. Trang bi va the tran di chung mot bang, cong don
    tung khoa — nho vay thu tu ap dung khong con quan trong, va ba ban cai dat
    chac chan ra cung mot so."""
    out = dict(a or {})
    for k, v in (b or {}).items():
        out[k] = out.get(k, 0.0) + v
    return out


# --------------------------------------------------------------- doi chieu
# Bo ca dung chung cho ca ba ban cai dat. Python sinh ra ky vong, Lua va
# GDScript tinh lai tung ca roi so — lech mot so la biet ngay ben nao sai.
# Y het cach mo hinh chien dau dang duoc kiem (xem sim/export_stats.py).
REF_TYPES = (AP, HP_LIMIT, DP_ADDITION, CRITICAL_STRIKE)
REF_BASES = (100.0, 375.5)
REF_INTENSIFY = (0, 1, 5, 30, 31, 60, 200)
REF_LEVELS = (3, 4, 10)
# 25 loai trang bi that cua ban goc: o (0/20/30/40/50) + nghe (1..5).
REF_TYPES_EQUIP = tuple(cat + job for cat in (0, 20, 30, 40, 50)
                        for job in (1, 2, 3, 4, 5))


def reference_cases():
    """Danh sach ca doi chieu, moi ca kem ket qua Python tinh duoc."""
    out = []
    for ptype in REF_TYPES:
        for base in REF_BASES:
            for lv in REF_LEVELS:
                for iv in REF_INTENSIFY:
                    # Cap tinh luyen chay vong 0..5 theo thu tu ca, thay vi
                    # nhan them mot chieu nua vao tich Descartes: 168 ca van
                    # phu het 6 cap, ma khong phinh len 1008.
                    rf = len(out) % (MAX_REFINE_LEVEL + 1)
                    # Chay vong ca 5 o lan 5 nghe: 25 loai trang bi that.
                    etype = REF_TYPES_EQUIP[len(out) % len(REF_TYPES_EQUIP)]
                    # O do doi theo ca de phu ca gia vu khi lan gia o khac.
                    part = 1 if len(out) % 2 == 0 else 3
                    # Base cua thuoc tinh phu chay vong qua ca 5 dai cham
                    # diem, de ba ban doi chieu ca phep cham do.
                    abase = (0.85, 0.95, 1.05, 1.15, 1.25)[len(out) % 5]
                    e = Equipment(part=part, main=(ptype, base), level=lv,
                                  intensify=iv, quality=2, refine=rf,
                                  appends=[
                                      make_append(CRITICAL_STRIKE, abase, 2, base),
                                      make_append(HP_LIMIT, abase, 2, base)])
                    out.append({
                        'prop': ptype, 'base': base, 'level': lv,
                        'intensify': iv, 'quality': 2,
                        'part': part, 'refine': rf,
                        'refinePercent': refine_percent(rf),
                        'refineCost': e.refine_cost_next(),
                        'mainValue': e.main_value(),
                        'appendBase': abase,
                        'appendValue': append_value(abase, CRITICAL_STRIKE, 2, base),
                        'appendScore': append_score(abase),
                        'appendTotal': e.append_score_total(),
                        'increment': intensify_increment(iv, base),
                        'propVal': intensify_property_val(base, ptype),
                        'total': intensify_total(iv, base),
                        'cost': intensify_cost(max(1, iv)),
                        'costTo': e.cost_to_level(iv + 5),
                        'qualityRange': quality_range(base, 10.0, 2.0),
                        # Cong thuc chi so chinh: dung `base` lam HE SO CAP de
                        # ca ba ban tinh cung mot con so ma khong can bang.
                        'equipType': etype,
                        'jobOf': equip_job(etype),
                        'categoryOf': equip_category(etype),
                        'mainFormula': main_property_val(
                            main_property_type(etype), base, 2,
                            equip_job(etype)),
                        'capacity': e.capacity(),
                        'capacityOrig': e.capacity_as_original(),
                        'stats': dict((str(k), v) for k, v in e.stats().items()),
                    })
    return out


def _export(path):
    import json
    import os
    doc = {
        'note': 'sinh boi sim/equipment.py --export; dung de doi chieu ba ban',
        'weights': dict((str(k), v) for k, v in CAPACITY_WEIGHT.items()),
        'appendUnlockLevel': APPEND_UNLOCK_LEVEL,
        'appendRange': [APPEND_RANGE_MIN, APPEND_RANGE_MAX],
        'recastItemId': RECAST_ITEM_ID,
        'intensifyStep': INTENSIFY_STEP,
        'cases': reference_cases(),
    }
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fp:
        json.dump(doc, fp, ensure_ascii=False, indent=1)
    print('ghi %s  (%d ca doi chieu)' % (path, len(doc['cases'])))


if __name__ == '__main__':
    import os
    import sys
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--export', nargs='?', const=os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     '..', 'data_ref', 'equipment_ref.json')),
        help='ghi bo ca doi chieu ra JSON cho Lua va GDScript')
    a = ap.parse_args()
    if a.export:
        _export(a.export)
    else:
        ap.print_help()
    sys.exit(0)
