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
import os, json, collections

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


class Armies(object):
    """91 quan chung. Bang nay co chi so TUYET DOI, khong phai bac."""

    def __init__(self, config_dir=DEFAULT_CONFIG):
        self.rows = load_json(config_dir, 'KDBGameArmyConfig.xgg')
        self.by_id = {r['ArmyTypeID']: r for r in self.rows}
        self.by_sprite = {r['SpriteName']: r for r in self.rows}

    def __len__(self):
        return len(self.rows)


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
