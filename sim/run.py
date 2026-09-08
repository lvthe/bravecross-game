# -*- coding: utf-8 -*-
"""Chay mo phong roi bao cao ti le thang.

    python run.py                       5 tuong mac dinh, 10000 tran
    python run.py --all                 ca 92 tuong
    python run.py ZhaoYun LuBu GuanYu   chi dinh tuong
    python run.py --sensitivity         chay lai voi cac cong thuc khac nhau
    python run.py --duel ZhaoYun LuBu   ke tung don cua mot tran

Cau hoi can tra loi: co tuong nao de het khong. Muc do de duoc do bang
KHOANG CACH ti le thang giua tuong manh nhat va yeu nhat.
"""
import os, sys, argparse, collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tables import Heroes, TableError, DEFAULT_CONFIG
from battle import Rules, Fighter, duel, round_robin
import random

# Nam tuong mac dinh: chon trai deu tren pho bac cong/thu chu khong phai chon
# theo so thich, de bang ket qua noi duoc dieu gi do.
DEFAULT_PICKS = ['MaChao', 'LiuBei', 'ZhuGeLiangYoung', 'SunShangXiangYoung', 'GanNing']


def bar(pct, width=28):
    n = int(round(pct / 100.0 * width))
    return '#' * n + '.' * (width - n)


def report(score, total, title):
    print('\n%s' % title)
    print('%-24s %7s %7s %7s   %s' % ('tuong', 'thang', 'thua', 'hoa', 'ti le thang'))
    rows = sorted(score.items(), key=lambda kv: -kv[1]['win'] / max(1, kv[1]['games']))
    for name, s in rows:
        pct = 100.0 * s['win'] / max(1, s['games'])
        print('%-24s %7d %7d %7d   %5.1f%% %s' % (
            name, s['win'], s['lose'], s['draw'], pct, bar(pct)))
    best = 100.0 * rows[0][1]['win'] / max(1, rows[0][1]['games'])
    worst = 100.0 * rows[-1][1]['win'] / max(1, rows[-1][1]['games'])
    print('\n%d tran. Manh nhat %s %.1f%%, yeu nhat %s %.1f%%, khoang cach %.1f diem.'
          % (total, rows[0][0], best, rows[-1][0], worst, best - worst))
    return best - worst


def breakdown(score, rows, col, label, names=None):
    """Ti le thang gom theo mot cot cua bang tuong.

    Quan trong voi cau hoi can bang: neu chenh lech bam theo DO HIEM thi do la
    thiet ke gacha co y, khong phai loi can bang. Neu no bam theo NGHE hay
    khong bam theo gi ca thi moi la van de.
    """
    by = collections.defaultdict(lambda: {'win': 0, 'games': 0, 'n': 0})
    for r in rows:
        s = score[r['HeroSprite']]
        g = by[r[col]]
        g['win'] += s['win']
        g['games'] += s['games']
        g['n'] += 1
    print('\n  ti le thang theo %s:' % label)
    for k in sorted(by):
        g = by[k]
        pct = 100.0 * g['win'] / max(1, g['games'])
        tag = (names or {}).get(k, str(k))
        print('    %-16s n=%-3d  %5.1f%% %s' % (tag, g['n'], pct, bar(pct, 20)))
    return by


def length_note(stats):
    """Do dai tran trung binh.

    Quan trong ngang ti le thang: mot tran ket thuc sau 2 don thi khong con la
    tran nua — ket qua do chi so quyet dinh het, nguoi choi khong lam gi duoc,
    va cung khong con cho nao de nhet ky nang hay chien thuat vao.
    """
    n = stats.get('battles', 0)
    if not n:
        return ''
    hits = stats['hits'] / float(n)
    secs = stats['seconds'] / float(n)
    note = ''
    if hits <= 6:
        note = ('  <- QUA NGAN. Chua du cho de ky nang hay chien thuat co y'
                ' nghia; can ha sat thuong hoac tang mau.')
    return 'Tran trung binh: %.1f don (ca hai ben), %.1f giay.%s' % (hits, secs, note)


def verdict(gap):
    if gap >= 80:
        return 'MOT TUONG DE HET — bang nay khong choi duoc nhu dang co.'
    if gap >= 50:
        return 'Lech nang. Con vai tuong khong ai chon.'
    if gap >= 25:
        return 'Co bac ro rang nhung van con lua chon.'
    return 'Kha can bang.'


def cmd_duel(heroes, a_name, b_name, seed, rules):
    """Ke tung don mot tran — de kiem tra vong lap co hop ly khong."""
    a = Fighter(heroes.get(a_name), heroes.base, rules)
    b = Fighter(heroes.get(b_name), heroes.base, rules)
    print('%s  HP %.0f  AP %.0f-%.0f  don x%.2f  ky nang x%.2f'
          % (a.name, a.hp_max, a.ap_min, a.ap_max, a.hit_rate, a.skill_rate))
    print('%s  HP %.0f  AP %.0f-%.0f  don x%.2f  ky nang x%.2f\n'
          % (b.name, b.hp_max, b.ap_min, b.ap_max, b.hit_rate, b.skill_rate))
    a.reset()
    b.reset()
    rng = random.Random(seed)
    ta = tb = a.interval
    t = 0.0
    n = 0
    while t < rules.max_seconds and a.alive and b.alive:
        t = min(ta, tb)
        acts = []
        if ta <= t + 1e-9:
            acts.append(a)
            ta += a.interval
        if tb <= t + 1e-9:
            acts.append(b)
            tb += b.interval
        for who in acts:
            other = b if who is a else a
            dmg, skill, crit = who.strike(other, rng, rules)
            n += 1
            print('%6.1fs  %-22s -%7.0f%s%s   %s con %.0f' % (
                t, who.name, dmg,
                ' KYNANG' if skill else '       ',
                ' CHIMANG' if crit else '        ',
                other.name, max(0.0, other.hp)))
    print('\n%d don. Thang: %s' % (n, a.name if a.alive else (b.name if b.alive else 'hoa')))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('names', nargs='*', help='ten tuong (HeroSprite)')
    ap.add_argument('--config', default=DEFAULT_CONFIG)
    ap.add_argument('--all', action='store_true', help='dung ca 92 tuong')
    ap.add_argument('--battles', type=int, default=10000, help='tong so tran')
    ap.add_argument('--seed', type=int, default=0)
    ap.add_argument('--growth', action='store_true',
                    help='nhan them GrowthFactor vao chi so')
    ap.add_argument('--mitigation', choices=['subtract', 'divide'], default='subtract')
    ap.add_argument('--sensitivity', action='store_true',
                    help='chay lai voi cac cong thuc khac de xem ket luan co doi')
    ap.add_argument('--duel', nargs=2, metavar=('A', 'B'),
                    help='ke tung don cua mot tran')
    ap.add_argument('--list', action='store_true', help='liet ke tuong')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    try:
        heroes = Heroes(a.config)
    except TableError as e:
        sys.exit(str(e))

    if a.list:
        for r in sorted(heroes.rows, key=lambda r: (-r['HeroRarity'], r['HeroSprite'])):
            print('  %-24s do hiem %d  job %d  cong %d  thu %d  don x%.2f  ky nang x%.2f'
                  % (r['HeroSprite'], r['HeroRarity'], r['HeroJobType'],
                     r['AttackCapability'], r['Viability'],
                     1 + r['InjuryRates'], 1 + r['SkillInjuryRates']))
        return 0

    rules = Rules(mitigation=a.mitigation, use_growth=a.growth)

    if a.duel:
        cmd_duel(heroes, a.duel[0], a.duel[1], a.seed, rules)
        return 0

    if a.all:
        rows = heroes.rows
    elif a.names:
        rows = [heroes.get(n) for n in a.names]
    else:
        rows = [heroes.get(n) for n in DEFAULT_PICKS]

    n_pairs = len(rows) * (len(rows) - 1) // 2
    if n_pairs == 0:
        sys.exit('can it nhat 2 tuong')
    per_pair = max(1, a.battles // n_pairs)

    print('%d tuong, %d cap, %d tran moi cap' % (len(rows), n_pairs, per_pair))
    print('cong thuc: giam sat thuong = %s, GrowthFactor = %s'
          % (rules.mitigation, 'co' if rules.use_growth else 'khong'))

    stats = {}
    score, total = round_robin(rows, heroes.base, per_pair, a.seed, rules, stats)
    gap = report(score, total, 'KET QUA')
    print(verdict(gap))
    print(length_note(stats))

    if len(rows) >= 10:
        breakdown(score, rows, 'HeroRarity', 'do hiem',
                  {0: 'thuong (0)', 1: 'hiem (1)', 2: 'cuc hiem (2)'})
        breakdown(score, rows, 'HeroJobType', 'nghe')
        breakdown(score, rows, 'AttackCapability', 'bac cong')
        breakdown(score, rows, 'Viability', 'bac thu')

    if a.sensitivity:
        print('\n' + '=' * 62)
        print('DO NHAY: ket luan co doi theo cong thuc khong?')
        print('=' * 62)
        base_order = [k for k, _ in sorted(
            score.items(), key=lambda kv: -kv[1]['win'] / max(1, kv[1]['games']))]
        for label, r in (
                ('giam theo phep chia (k=100)', Rules(mitigation='divide')),
                ('giam theo phep chia (k=300)', Rules(mitigation='divide', defence_k=300.0)),
                ('co nhan GrowthFactor', Rules(mitigation='subtract', use_growth=True)),
                ('chia + GrowthFactor', Rules(mitigation='divide', use_growth=True))):
            s2, t2 = round_robin(rows, heroes.base, per_pair, a.seed, r)
            g2 = report(s2, t2, '--- %s ---' % label)
            order2 = [k for k, _ in sorted(
                s2.items(), key=lambda kv: -kv[1]['win'] / max(1, kv[1]['games']))]
            print('thu tu %s so voi mo hinh mac dinh.  %s'
                  % ('GIU NGUYEN' if order2 == base_order else 'DOI', verdict(g2)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
