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


class Equipment(object):
    """Mot mon trang bi."""

    __slots__ = ('part', 'level', 'intensify', 'quality', 'main', 'appends')

    def __init__(self, part, main, level=1, intensify=0, quality=1, appends=None):
        self.part = part
        self.level = level
        self.intensify = intensify
        self.quality = quality
        self.main = main                      # (prop_type, value)
        self.appends = list(appends or [])    # [(prop_type, value), ...]

    # --------------------------------------------------------------- chi so
    def append_unlocked(self):
        return self.level >= APPEND_UNLOCK_LEVEL

    def stats(self):
        """{loai chi so: tong gia tri} sau khi cong cuong hoa va thuoc tinh phu."""
        out = {}
        ptype, pval = self.main
        out[ptype] = out.get(ptype, 0.0) + pval
        # Chi so THAT: dung duong cong don theo cap (cong thuc goc cua tac gia).
        bonus = intensify_total(self.intensify, pval)
        if bonus:
            out[ptype] = out.get(ptype, 0.0) + bonus
        if self.append_unlocked():
            for t, v in self.appends:
                out[t] = out.get(t, 0.0) + v
        return out

    def capacity(self):
        """Luc chien: tung chi so nhan trong so cua no roi cong lai."""
        return sum(v * weight_of(t) for t, v in self.stats().items())

    def capacity_as_original(self):
        """Luc chien tinh Y HET client ban goc, de doi chieu.

        Khac capacity() o cho dung intensify_property_val (moc co dinh) thay vi
        intensify_total (cong don theo cap) — nen KHONG doi theo cap cuong hoa.
        share_EquipmentLogic:CalcEquipFightingCapacity
        """
        ptype, pval = self.main
        total = pval + intensify_property_val(pval, ptype)
        out = total * weight_of(ptype)
        if self.append_unlocked():
            out += sum(v * weight_of(t) for t, v in self.appends)
        return out

    # --------------------------------------------------------------- nuoi
    def cost_to_next(self):
        return intensify_cost(self.intensify + 1)

    def cost_to_level(self, target):
        """Tong chi phi cuong hoa tu cap hien tai len `target`."""
        if target <= self.intensify:
            return 0.0
        return sum(intensify_cost(lv) for lv in range(self.intensify + 1, target + 1))

    def __repr__(self):
        return 'Equipment(part=%d, %s=%.1f, +%d, q%d, luc chien %.0f)' % (
            self.part, PROPERTY_NAME.get(self.main[0], '?'), self.main[1],
            self.intensify, self.quality, self.capacity())


def roll_append(base_value, rand):
    """Gia tri mot thuoc tinh phu: ngau nhien 0.8..1.3 lan gia tri goc.

    `rand` la ham tra ve so trong [0,1) — truyen vao de con dat hat giong,
    dung kieu cua sim/battle.py.
    """
    return base_value * (APPEND_RANGE_MIN
                         + rand() * (APPEND_RANGE_MAX - APPEND_RANGE_MIN))


# --------------------------------------------------------------- doi chieu
# Bo ca dung chung cho ca ba ban cai dat. Python sinh ra ky vong, Lua va
# GDScript tinh lai tung ca roi so — lech mot so la biet ngay ben nao sai.
# Y het cach mo hinh chien dau dang duoc kiem (xem sim/export_stats.py).
REF_TYPES = (AP, HP_LIMIT, DP_ADDITION, CRITICAL_STRIKE)
REF_BASES = (100.0, 375.5)
REF_INTENSIFY = (0, 1, 5, 30, 31, 60, 200)
REF_LEVELS = (3, 4, 10)


def reference_cases():
    """Danh sach ca doi chieu, moi ca kem ket qua Python tinh duoc."""
    out = []
    for ptype in REF_TYPES:
        for base in REF_BASES:
            for lv in REF_LEVELS:
                for iv in REF_INTENSIFY:
                    e = Equipment(part=1, main=(ptype, base), level=lv,
                                  intensify=iv, quality=2,
                                  appends=[(CRITICAL_STRIKE, 0.05),
                                           (HP_LIMIT, 120.0)])
                    out.append({
                        'prop': ptype, 'base': base, 'level': lv,
                        'intensify': iv, 'quality': 2,
                        'increment': intensify_increment(iv, base),
                        'propVal': intensify_property_val(base, ptype),
                        'total': intensify_total(iv, base),
                        'cost': intensify_cost(max(1, iv)),
                        'costTo': e.cost_to_level(iv + 5),
                        'qualityRange': quality_range(base, 10.0, 2.0),
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
