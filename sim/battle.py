# -*- coding: utf-8 -*-
"""Vong lap chien dau, khong do hoa.

MUC DICH: tra loi cau hoi dat nhat truoc khi ton mot dong nao cho art —
*bang tuong nay co thu vi khong, hay mot tuong de het?*

CONG THUC O DAY KHONG PHAI CUA BAN GOC
--------------------------------------
Da tim: khong cot nao trong so 46 cot cua bang tuong xuat hien trong 973 file
Lua cua client. Chien dau tinh hoan toan o server, ma server thi khong co
trong tay. Nen cong thuc duoi day la MO HINH TU DAT, chi dung SO THAT.

Nhung diem dua duoc vao du lieu:

* `AttackCapability` 2..8 va `Viability` 2..8 la BAC, khong phai chi so tuyet
  doi. Chi so tuyet doi nam o khoi dung chung: HpBase 1000, ApBase 30..120,
  DpBase 30.

* Moi cot ten `*Rates` la CONG THEM chu khong phai nhan: 72/91 quan chung co
  `InjuryRates = 0`, ma quan chung gay 0 sat thuong thi vo ly. Nen doc la
  `sat thuong x (1 + InjuryRates)`. Cach doc nay cung khop voi ca ho cot cung
  kieu: FinalDamageRates, MeleeDamageRates, ArrowDamageRates — deu mac dinh 0.

* `AngerRecovery` = 30 cho ca 92 tuong, nen no day sau 4 don. `SkillInjuryRates`
  thi khac nhau tung tuong (0..10), do moi la cho tao khac biet.

* `QualityFactor` bang 1 o ca 92 tuong nen bo qua. `TypeFactor` trung khit
  `HeroJobType`, la cung mot cot.

Doi cong thuc bang lop Rules roi chay lai — ket luan CO doi theo cong thuc hay
khong la thong tin dang gia hon ban thang thua tuyet doi.
"""
import math, random, collections


# Ky nang rieng tung tuong.
#
# Ban goc CO du lieu ai co ky nang nao: KDBGameHeroTalentSkill.xgg gan cho moi
# tuong mot ten. Nhung no CHI LUU TEN — hieu ung nam o server, khong co trong
# tay, giong het chuyen cong thuc sat thuong.
#
# Nen bang duoi day la THIET KE CUA TA, dua tren nghia cua cai ten (phien am
# Han-Viet, doan duoc kha chac):
#
#     NuQi      no khi      no day nhanh hon -> ky nang no som
#     GongSu    cong toc    danh nhanh hon
#     ShengMing sinh menh   nhieu mau hon
#     TieBi     thiet bich  nhan it sat thuong hon
#     BaoJi     bao kich    chi mang nhieu hon
#     PoJia     pha giap    bo qua mot phan giap doi phuong
#     FangYu    phong ngu   giap day hon
#     GongJi    cong kich   sat thuong cao hon
#     ShiXue    thi huyet   hut mau theo sat thuong gay ra
#
# Ky nang khong co trong bang thi khong co hieu ung — noi thang la chua lam,
# hon la doan bua roi de nguoi choi tu hieu nham.
SKILLS = {
    'NuQi':      {'anger': 1.6},
    'GongSu':    {'interval': 0.8},
    'ShengMing': {'hp': 1.3},
    'TieBi':     {'taken': 0.8},
    'BaoJi':     {'crit_add': 0.15},
    'PoJia':     {'pierce': 0.5},
    'FangYu':    {'defence': 2.0},
    'GongJi':    {'ap': 1.2},
    'ShiXue':    {'lifesteal': 0.15},
}


class Rules(object):
    """Cac lua chon mo hinh. Doi o day roi chay lai de xem ket luan co vung."""

    def __init__(self, mitigation='divide', defence_k=100.0,
                 use_growth=False, anger_full=100.0, max_seconds=600.0,
                 use_skills=True):
        # 'subtract': dmg = ap - def   (khong can hang so tu bia ra)
        # 'divide'  : dmg = ap * k/(k+def)
        #
        # Mac dinh la 'divide', va can cu nam trong chinh bang goc: quan chung
        # co DpBase 110-200 trong khi MaxApBase cua chung chi 5-100. Doc kieu
        # tru thi ngay o CAP 1 mot top DefenderN (giap 110) da mien nhiem voi
        # moi don vi trong game — ban goc khong the chay nhu the, nen cong thuc
        # cua no phai la kieu ti le.
        #
        # Do duoc bang sim/field.py: kieu tru thi cang len cap cang be tac
        # (18% hoa o cap 1, 53% o cap 12, tran dai 380 giay); kieu chia cho
        # 47-54% can bang, gan nhu khong hoa, tran 53-118 giay.
        self.mitigation = mitigation
        self.defence_k = defence_k
        # GrowthFactor la bac tang truong theo cap. Cach no nhan vao chi so thi
        # khong biet, nen mac dinh TAT — bat len de xem ket luan co doi khong.
        self.use_growth = use_growth
        self.anger_full = anger_full
        self.max_seconds = max_seconds
        # Tat de do xem ky nang doi ket qua bao nhieu.
        self.use_skills = use_skills


def level_growth(row, level):
    """He so tang truong theo cap, CHUAN HOA ve 1.0 o cap 1.

    Bang tuong co GrowthFactor (bac 1..4) va AddGrowthFactor (moi tuong mot
    kieu, 0 den 2.0) — nghia tu nhien la moi cap cong them AddGrowthFactor vao
    bac goc. Chia lai cho bac goc de cap 1 luon bang 1.0, nho vay moi con so
    tham chieu tinh o cap 1 van giu nguyen khi them he cap vao.

    Tuong AddGrowthFactor cao thi len cap an hon nhieu — day la mot canh chon
    doi hinh that, khong phai do ta bia ra.
    """
    g = float(row.get('GrowthFactor', 1)) or 1.0
    add = float(row.get('AddGrowthFactor', 0.0))
    return (g + add * (max(1, int(level)) - 1)) / g


class Fighter(object):
    """Mot tuong da quy ra chi so, san sang danh."""

    def __init__(self, row, base, rules=None, level=1, buffs=None):
        r = rules or Rules()
        self.level = max(1, int(level))
        self.name = row['HeroSprite']
        self.hero_id = row['HeroID']
        self.job = row['HeroJobType']
        self.rarity = row['HeroRarity']
        self.faction = row['HeroFactions']

        g = float(row['GrowthFactor']) if r.use_growth else 1.0
        g *= level_growth(row, self.level)

        self.hp_max = float(base['HpBase']) * float(row['Viability']) * g
        self.ap_min = float(base['MinApBase']) * float(row['AttackCapability']) * g
        self.ap_max = float(base['MaxApBase']) * float(row['AttackCapability']) * g
        self.defence = float(base['DpBase'])
        self.interval = float(base['AttackInterval'])
        self.crit_chance = float(base['CriticalStrikeBase']) / 100.0
        self.crit_mult = float(base['CritDamageDouble'])

        self.hit_rate = 1.0 + float(row['InjuryRates'])
        self.skill_rate = 1.0 + float(row['SkillInjuryRates'])
        self.anger_gain = float(row['AngerRecovery'])

        # --- ky nang rieng
        self.skill = str(row.get('TalentSkill', ''))
        e = SKILLS.get(self.skill, {}) if r.use_skills else {}
        self.hp_max *= e.get('hp', 1.0)
        self.ap_min *= e.get('ap', 1.0)
        self.ap_max *= e.get('ap', 1.0)
        self.defence *= e.get('defence', 1.0)
        self.interval *= e.get('interval', 1.0)
        self.anger_gain *= e.get('anger', 1.0)
        self.crit_chance += e.get('crit_add', 0.0)
        self.taken = e.get('taken', 1.0)          # he so sat thuong PHAI CHIU
        self.pierce = e.get('pierce', 0.0)        # bo qua bao nhieu phan giap
        self.lifesteal = e.get('lifesteal', 0.0)
        self.reflect = 0.0                        # doi lai bao nhieu sat thuong

        # --- the tran (KDBGameFormationConfig cua ban goc)
        #
        # Day la mot trong so it he thong con NGUYEN SO LIEU: moi cap cua moi
        # the tran ghi ro tang gi, bao nhieu, cho CHO DUNG nao (PlacementType
        # 1/2/3 = hang truoc/giua/sau). Nen bang buff duoi day khong phai do ta
        # dat ra — no la cua ban goc, chi doi ten cot.
        #
        # `dmg_pct` nhan thang vao cong thay vi vao sat thuong cuoi: cong thuc
        # giam thuong kieu chia la tuyen tinh theo cong, nen hai cach ra dung
        # cung mot so, ma cach nay khong phai sua ham strike().
        b = buffs or {}
        self.hp_max = (self.hp_max + b.get('hp', 0.0)) * (1.0 + b.get('hp_pct', 0.0))
        gain = 1.0 + b.get('dmg_pct', 0.0)
        self.ap_min = (self.ap_min + b.get('ap', 0.0)) * gain
        self.ap_max = (self.ap_max + b.get('ap', 0.0)) * gain
        self.defence = (self.defence + b.get('dp', 0.0)) * (1.0 + b.get('dp_pct', 0.0))
        self.taken *= 1.0 - b.get('taken_pct', 0.0)
        self.lifesteal += b.get('lifesteal', 0.0)
        self.reflect += b.get('reflect', 0.0)

        self.reset()

    def reset(self):
        self.hp = self.hp_max
        self.anger = 0.0

    @property
    def alive(self):
        return self.hp > 0.0

    def strike(self, target, rng, rules):
        """Mot don. Tra ve (sat thuong, co dung ky nang, co chi mang)."""
        ap = rng.uniform(self.ap_min, self.ap_max)

        self.anger += self.anger_gain
        skill = self.anger >= rules.anger_full
        if skill:
            self.anger = 0.0

        dmg = ap * (self.skill_rate if skill else self.hit_rate)

        # Pha giap: bo qua mot phan giap doi phuong.
        defence = target.defence * (1.0 - self.pierce)
        if rules.mitigation == 'divide':
            k = rules.defence_k
            dmg *= k / (k + defence)
        else:
            dmg -= defence

        # Thiet bich: he so nay thuoc ve BEN CHIU, khong phai ben danh.
        dmg *= target.taken

        crit = rng.random() < self.crit_chance
        if crit:
            dmg *= self.crit_mult

        dmg = max(1.0, dmg)
        target.hp -= dmg
        if self.lifesteal:
            self.hp = min(self.hp_max, self.hp + dmg * self.lifesteal)
        # Phan don: the tran `AllHeroReboundDamagePercent`. Doi lai theo sat
        # thuong DA CHIU, va khong doi tiep lan nua — khong thi hai ben cung co
        # phan don la thanh vong lap.
        if target.reflect:
            self.hp -= dmg * target.reflect
        return dmg, skill, crit


def duel(a, b, rng, rules=None):
    """Mot tran tay doi. Tra ve (ket qua, so don, so giay).

    Ket qua: 1 neu a thang, -1 neu b thang, 0 neu hoa.

    Ca hai danh theo dong thoi gian rieng, nen AttackInterval khac nhau la co
    y nghia (hien ban goc cho moi tuong cung 2.5s). Cung mot moc thoi gian thi
    ca hai cung ra don — co the chet ca hai, tinh la hoa.
    """
    r = rules or Rules()
    a.reset()
    b.reset()
    # Moi ben theo nhip cua CHINH MINH. Truoc day o day la `ta = tb = a.interval`
    # — ca hai danh theo nhip cua ben A. Loi do an suot vi moi tuong deu co
    # AttackInterval = 2.5; ky nang GongSu (danh nhanh hon) tao ra nhip khac
    # nhau lan dau tien va phep doi chieu voi ban Lua bat duoc ngay.
    ta, tb = a.interval, b.interval
    t = 0.0
    hits = 0
    while t < r.max_seconds:
        t = min(ta, tb)
        acts = []
        if ta <= t + 1e-9:
            acts.append(a)
            ta += a.interval
        if tb <= t + 1e-9:
            acts.append(b)
            tb += b.interval
        for who in acts:
            who.strike(b if who is a else a, rng, r)
            hits += 1
        if not a.alive or not b.alive:
            return (1 if a.alive else (-1 if b.alive else 0)), hits, t
    return 0, hits, t        # het gio ma chua ai chet


def match(row_a, row_b, base, n, seed=0, rules=None, stats=None,
          level_a=1, level_b=1):
    """Danh n tran giua hai tuong. Tra ve (thang, thua, hoa) cua tuong a.

    Truyen `stats` (mot dict) de gom them do dai tran — so don va so giay. Tran
    dai bao nhieu la thong tin quan trong khong kem ai thang: mot tran ket thuc
    sau 2 don thi khong con la tran nua, ket qua do chi so quyet dinh het.
    """
    r = rules or Rules()
    a = Fighter(row_a, base, r, level_a)
    b = Fighter(row_b, base, r, level_b)
    rng = random.Random(seed)
    win = lose = draw = 0
    for _ in range(n):
        out, hits, secs = duel(a, b, rng, r)
        if out > 0:
            win += 1
        elif out < 0:
            lose += 1
        else:
            draw += 1
        if stats is not None:
            stats['hits'] = stats.get('hits', 0) + hits
            stats['seconds'] = stats.get('seconds', 0.0) + secs
            stats['battles'] = stats.get('battles', 0) + 1
    return win, lose, draw


def round_robin(rows, base, n_per_pair, seed=0, rules=None, stats=None):
    """Danh vong tron. Tra ve (bang ket qua, tong so tran).

    Bang: ten -> {'win','lose','draw','games'}
    """
    r = rules or Rules()
    score = collections.OrderedDict(
        (x['HeroSprite'], {'win': 0, 'lose': 0, 'draw': 0, 'games': 0})
        for x in rows)
    total = 0
    for i in range(len(rows)):
        for j in range(i + 1, len(rows)):
            w, l, d = match(rows[i], rows[j], base, n_per_pair,
                            seed + i * 1000 + j, r, stats)
            for name, a_win, a_lose in ((rows[i]['HeroSprite'], w, l),
                                        (rows[j]['HeroSprite'], l, w)):
                s = score[name]
                s['win'] += a_win
                s['lose'] += a_lose
                s['draw'] += d
                s['games'] += n_per_pair
            total += n_per_pair
    return score, total
