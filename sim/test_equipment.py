# -*- coding: utf-8 -*-
"""Test cho mo hinh trang bi.

Cong thuc lay tu ban goc nen o day kiem HAI thu:

  1. Con so khop dung ma nguon goc — tinh tay ra bao nhieu thi phai ra bay nhieu
  2. Cac tinh chat ma bat ky mo hinh nuoi nao cung phai co: cang cuong hoa cang
     manh, cang cuong hoa cang dat, khong bao gio am

    python test_equipment.py
"""
import os
import sys
import math
import random

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import equipment as E

nPass = nFail = 0


def check(cond, desc, detail=None):
    global nPass, nFail
    if cond:
        nPass += 1
        print('  dat   %s' % desc)
    else:
        nFail += 1
        print('  HONG  %s%s' % (desc, '' if detail is None else '  -> %s' % (detail,)))


def close(a, b, eps=1e-9):
    return abs(a - b) <= eps * max(1.0, abs(a), abs(b))


print('=== 1. he so lay dung tu ban goc ===')
check(close(E.INTENSIFY_STEP, math.pow(2.4, 1.0 / 200.0)),
      'buoc cuong hoa = 2.4^(1/200)')
check(E.APPEND_UNLOCK_LEVEL == 4, 'thuoc tinh phu mo tu cap 4')
check((E.APPEND_RANGE_MIN, E.APPEND_RANGE_MAX) == (0.8, 1.3),
      'dai ngau nhien thuoc tinh phu 0.8-1.3')
check(E.RECAST_ITEM_ID == 97, 'da tay luyen la vat pham id 97')
check(E.CAPACITY_WEIGHT[E.CRITICAL_STRIKE] == 50.0
      and E.CAPACITY_WEIGHT[E.HP_LIMIT] == 0.1
      and E.CAPACITY_WEIGHT[E.AP] == 0.9,
      'trong so luc chien dung bang share_configManager')

print('\n=== 2. cong thuc tinh tay ===')
# increment(level, Val) = (Val/25) * step^level
check(close(E.intensify_increment(0, 100.0), 4.0),
      'increment cap 0 = 100/25 = 4', E.intensify_increment(0, 100.0))
check(close(E.intensify_increment(200, 100.0), 4.0 * 2.4),
      'increment cap 200 = 4 * 2.4 (buoc luy thua tron 200 cap)')
# chi phi: 25 * (2^(1/4.5))^(level-1)
check(close(E.intensify_cost(1), 25.0), 'chi phi cap 1 = 25')
check(close(E.intensify_cost(1 + 4.5), 50.0, 1e-9),
      'chi phi nhan doi sau dung 4.5 cap', E.intensify_cost(5.5))
# quality_range = (base/coef + 0.3)/quality
check(close(E.quality_range(100.0, 10.0, 2.0), (10.0 + 0.3) / 2.0),
      'quality_range dung cong thuc')
check(E.quality_range(100.0, 0, 2) == 0.0, 'he so 0 thi tra ve 0, khong chia 0')

print('\n=== 3. chi phi tang dan va co diem gay o cap 31 ===')
costs = [E.intensify_cost(i) for i in range(1, 60)]
check(all(costs[i] < costs[i + 1] for i in range(len(costs) - 1)),
      'chi phi luon tang theo cap')
# Truoc cap 31 nhan doi moi 4.5 cap, sau do moi 6.5 cap -> nhip cham lai
before = E.intensify_cost(20) / E.intensify_cost(15)
after = E.intensify_cost(50) / E.intensify_cost(45)
check(after < before, 'sau cap 31 chi phi tang CHAM hon truoc do',
      'truoc %.3f, sau %.3f' % (before, after))

print('\n=== 4. cuong hoa lam manh len, don dieu ===')
w = E.Equipment(part=1, main=(E.AP, 100.0))
caps = []
for lv in range(0, 201, 20):
    w.intensify = lv
    caps.append(w.capacity())
check(all(caps[i] < caps[i + 1] for i in range(len(caps) - 1)),
      'luc chien tang don dieu theo cap cuong hoa')
check(caps[0] > 0, 'cap 0 van co luc chien', caps[0])

print('\n=== 5. ban goc: luc chien KHONG doi theo cap cuong hoa ===')
# Day la hanh vi that cua client ban goc — ham co dung level la ma chet.
a = E.Equipment(1, (E.AP, 100.0), intensify=0).capacity_as_original()
b = E.Equipment(1, (E.AP, 100.0), intensify=200).capacity_as_original()
check(close(a, b), 'capacity_as_original giu nguyen qua moi cap', (a, b))

print('\n=== 6. thuoc tinh phu ===')
e = E.Equipment(1, (E.AP, 100.0), level=3, appends=[(E.CRITICAL_STRIKE, 0.05)])
check(not e.append_unlocked(), 'cap 3 chua mo thuoc tinh phu')
without = e.capacity()
e.level = 4
check(e.append_unlocked(), 'cap 4 mo thuoc tinh phu')
check(e.capacity() > without, 'mo roi thi luc chien cao hon')

rnd = random.Random(1)
vals = [E.roll_append(100.0, rnd.random) for _ in range(400)]
check(all(80.0 <= v <= 130.0 for v in vals),
      'gia tri phu luon nam trong 0.8-1.3 lan goc',
      (min(vals), max(vals)))

print('\n=== 6b. tinh luyen ===')
# Bang lay tu KDBGameCommonConfig / EquipRefineConfig: 5 cap, +5% moi cap,
# gia nhan doi moi cap, vu khi dat hon o khac mot bac.
check(E.MAX_REFINE_LEVEL == 5, 'co 5 cap tinh luyen')
check([E.refine_percent(i) for i in range(1, 6)] == [5.0, 10.0, 15.0, 20.0, 25.0],
      'moi cap cong them 5%', [E.refine_percent(i) for i in range(1, 6)])
check(E.refine_percent(0) == 0.0 and E.refine_percent(6) == 0.0,
      'ngoai khoang 1..5 thi khong cong gi')
check([E.refine_cost(1, i) for i in range(1, 6)] == [40, 80, 160, 320, 640],
      'gia tinh luyen vu khi', [E.refine_cost(1, i) for i in range(1, 6)])
check([E.refine_cost(3, i) for i in range(1, 6)] == [30, 60, 120, 240, 480],
      'gia tinh luyen o khac', [E.refine_cost(3, i) for i in range(1, 6)])
check(E.refine_cost(1, 3) > E.refine_cost(2, 3), 'vu khi dat hon o khac')
check(all(E.refine_cost(1, i + 1) == E.refine_cost(1, i) * 2 for i in range(1, 5)),
      'gia nhan doi moi cap')
# VIP 10 giam 20%, lam tron LEN.
check(E.refine_cost(1, 1, vip_level=10) == 32, 'VIP10 giam 20%',
      E.refine_cost(1, 1, vip_level=10))
check(E.refine_cost(3, 1, vip_level=10) == 24, 'VIP10 tren o khac',
      E.refine_cost(3, 1, vip_level=10))
check(E.refine_cost(3, 1, vip_level=9) == 30, 'VIP9 chua duoc giam')
check(E.refine_cost(1, 0) == 0 and E.refine_cost(1, 6) == 0,
      'ngoai khoang thi khong co gia')

# Tinh luyen nhan vao CHI SO CHINH, va moi thu sau do dua tren so da nhan.
r0 = E.Equipment(1, (E.AP, 100.0), level=5, intensify=10, refine=0)
r5 = E.Equipment(1, (E.AP, 100.0), level=5, intensify=10, refine=5)
check(close(r0.main_value(), 100.0), 'chua tinh luyen thi giu nguyen',
      r0.main_value())
check(close(r5.main_value(), 125.0), 'tinh luyen 5 thi chi so chinh +25%',
      r5.main_value())
check(r5.capacity() > r0.capacity(), 'luc chien tang theo tinh luyen',
      '%.1f -> %.1f' % (r0.capacity(), r5.capacity()))
# Cuong hoa tinh TREN chi so da tinh luyen, nen hai truc nhan nhau chu khong
# cong roi ra. Kiem bang cach so phan cuong hoa cong them.
add0 = r0.stats()[E.AP] - r0.main_value()
add5 = r5.stats()[E.AP] - r5.main_value()
check(close(add5 / add0, 1.25, 1e-9),
      'phan cuong hoa cung duoc nhan theo tinh luyen',
      '%.4f vs %.4f' % (add5 / add0, 1.25))

caps = []
for r in range(0, 6):
    caps.append(E.Equipment(1, (E.AP, 100.0), refine=r).capacity())
check(all(caps[i] < caps[i + 1] for i in range(5)),
      'luc chien tang don dieu theo cap tinh luyen', caps)

w3 = E.Equipment(1, (E.AP, 100.0), refine=0)
check(w3.refine_cost_next() == 40, 'gia cap ke khi chua tinh luyen',
      w3.refine_cost_next())
w3.refine = 5
check(w3.refine_cost_next() == 0, 'het cap thi khong con gia',
      w3.refine_cost_next())

print('\n=== 6c. chi so chinh sinh tu loai/cap/pham ===')
# share_EquipmentPropertyLogic:getMainPropertyValWithCoefficient
check(E.equip_job(1) == 1 and E.equip_job(25) == 5 and E.equip_job(53) == 3,
      'nghe = loai chia lay du 10')
check(E.equip_category(1) == 0 and E.equip_category(25) == 20
      and E.equip_category(53) == 50, 'o = loai - nghe')
check(E.main_property_type(1) == E.AP, 'vu khi cho Cong')
check(E.main_property_type(21) == E.DP_ADDITION, 'giap cho Giap')
check(E.main_property_type(31) == E.HP_LIMIT, 'giay cho Mau')
check(E.main_property_type(41) == E.HP_LIMIT, 'day chuyen cho Mau')
check(E.main_property_type(51) == E.DP_ADDITION, 'nhan cho Giap')

# Tinh tay: Ap = 20 * (L + 10 + Q*6)^1.45 / (60 - J*6)
want = 20.0 * math.pow(1 + 10 + 1 * 6, 1.45) / (60.0 - 1 * 6)
check(close(E.main_property_val(E.AP, 1, 1, 1), want),
      'cong thuc Cong khop tinh tay', E.main_property_val(E.AP, 1, 1, 1))
want = 30.0 * math.pow(20 + 10 + 3 * 5, 1.5) / (20.0 + 4 * 10)
check(close(E.main_property_val(E.HP_LIMIT, 20, 3, 4), want),
      'cong thuc Mau khop tinh tay')
want = 5.0 * math.pow(20 + 10 + 2 * 6, 1.45) / (20.0 + 2 * 8)
check(close(E.main_property_val(E.DP_ADDITION, 20, 2, 2), want),
      'cong thuc Giap khop tinh tay')
# Chi mang khong co nhanh nao trong ham goc — nhanh thu tu la ban sao cua
# DpAddtion, ro rang la loi go. Ta tra 0 chu khong bia mot cong thuc.
check(E.main_property_val(E.CRITICAL_STRIKE, 20, 2, 2) == 0.0,
      'chi mang khong sinh duoc chi so chinh (ban goc thieu nhanh)')

# He so cap va pham deu lam manh len; nghe khac nhau cho so khac nhau.
check(E.main_property_val(E.AP, 40, 1, 1) > E.main_property_val(E.AP, 20, 1, 1),
      'he so cap cao hon thi manh hon')
check(E.main_property_val(E.AP, 20, 3, 1) > E.main_property_val(E.AP, 20, 1, 1),
      'pham chat cao hon thi manh hon')
check(E.main_property_val(E.AP, 20, 1, 5) > E.main_property_val(E.AP, 20, 1, 1),
      'cung ngan may thi cung thu manh hon chien binh ve Cong')

print('\n=== 6d. ghep do ===')
TAB = {
    '1_1': {'heroLevel': 1, 'gold': 10, 'materials': [[24, 1], [51, 2]]},
    '1_2': {'heroLevel': 10, 'gold': 110, 'materials': [[24, 1], [51, 2]]},
    '1_3': {'heroLevel': 20, 'gold': 3700, 'materials': [[25, 3], [52, 5]]},
}
check(E.synthesis_row(TAB, 1, 2)['gold'] == 110, 'tra dung dong bang')
check(E.synthesis_row(TAB, 1, 9) is None, 'khong co dong thi tra None')
check(E.level_coefficient(TAB, 1, 3) == 20.0,
      'he so cap chinh la cot HeroLevel', E.level_coefficient(TAB, 1, 3))

ok, why = E.synthesis_ready(TAB, 1, 1, 10)
check(ok, 'du cap tuong thi ghep duoc', why)
ok, why = E.synthesis_ready(TAB, 1, 2, 5)
check(not ok and 'cap 20' in why, 'thieu cap tuong thi tu choi, va noi can bao nhieu', why)
ok, why = E.synthesis_ready(TAB, 1, 10, 999)
check(not ok and 'cao nhat' in why, 'het cap thi tu choi', why)
ok, why = E.synthesis_ready(TAB, 99, 1, 999)
check(not ok, 'loai khong co trong bang thi tu choi')

# Len cap la manh len THAT, khong phai chi doi icon.
e1 = E.make_equipment(TAB, 1, 1, 1, 1)
e2 = E.make_equipment(TAB, 1, 2, 1, 1)
e3 = E.make_equipment(TAB, 1, 3, 1, 1)
check(e1.main[0] == E.AP, 'vu khi ra chi so Cong')
check(e2.main[1] > e1.main[1] and e3.main[1] > e2.main[1],
      'moi cap ghep la chi so chinh tang',
      '%.1f -> %.1f -> %.1f' % (e1.main[1], e2.main[1], e3.main[1]))
check(e3.capacity() > e1.capacity(), 'luc chien tang theo')
check(e1.equip_type == 1, 'mon do nho loai cua no')

print('\n=== 7. chi phi cong don ===')
w2 = E.Equipment(1, (E.AP, 100.0), intensify=0)
step = sum(E.intensify_cost(i) for i in range(1, 11))
check(close(w2.cost_to_level(10), step), 'cost_to_level = tong tung cap')
check(w2.cost_to_level(0) == 0.0, 'khong lui cap thi khong ton gi')
w2.intensify = 10
check(w2.cost_to_level(10) == 0.0, 'da o cap do thi khong ton gi')
check(close(w2.cost_to_next(), E.intensify_cost(11)), 'cost_to_next dung cap ke')

print('\n=== 8. khong bao gio am ===')
bad = []
for lv in (0, 1, 50, 200):
    for t in (E.AP, E.HP_LIMIT, E.DP_ADDITION, E.CRITICAL_STRIKE):
        e = E.Equipment(1, (t, 100.0), intensify=lv)
        if e.capacity() < 0 or any(v < 0 for v in e.stats().values()):
            bad.append((lv, t))
check(not bad, 'moi chi so va luc chien deu khong am', bad)

print('\n===== dat %d, hong %d =====' % (nPass, nFail))
sys.exit(0 if nFail == 0 else 1)
