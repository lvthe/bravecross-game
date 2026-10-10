# Dem so diem anh khac nhau giua hai anh PNG.
#
#   python tools/lech_anh.py a.png b.png            # chi bao
#   python tools/lech_anh.py a.png b.png --giong    # doi GIONG HET, khac la loi
#   python tools/lech_anh.py a.png b.png --doi      # doi PHAI KHAC (chung nguoc)
#
# Vi sao can: `tools/check.py` chay headless nen khong ve gi ca, con cau hoi
# "man Main dung ra co giong khong" thi CHI diem anh tra loi duoc. Mot khac biet
# ve thuoc tinh (theme, thu tu layer, co san khau) co the khong doi mot diem anh
# nao — va nguoc lai, doi mot diem anh co the la do pha hoat hinh chu khong do
# cai vua sua. Nen phai in ca HOP BAO cua vung khac va MUC LECH LON NHAT, de con
# quy nguyen nhan chu khong chi doc mot con so.
import sys

from PIL import Image, ImageChops


## Chi ke la "khac" khi lech > 8 muc (1/32 cua 0..255): bo qua nhieu lam tron
## cua trinh ve, thuong chi 1-2 muc.
NGUONG_KE = 8


def _vung(s: str) -> tuple:
    """`y0:y1` -> (y0, y1). Dung de bo mot dai nhieu ra khoi phep so."""
    a, b = s.split(":")
    return int(a), int(b)


def main(argv: list) -> int:
    doi = "--doi" in argv
    giong = "--giong" in argv
    # `--cat=y0:y1`: chi so phan nay cua anh. Can that khi mot dai nao do cua
    # khung hinh NHIEU giua hai lan chay (hoat hinh, hat) — dem ca dai ay thi
    # khong con phan biet duoc khac biet that voi nhieu.
    cat = None
    for a in argv[1:]:
        if a.startswith("--cat="):
            cat = _vung(a[6:])
    duong = [a for a in argv[1:] if not a.startswith("--")]
    if len(duong) != 2:
        print("dung: python tools/lech_anh.py <a.png> <b.png> [--giong|--doi] [--cat=y0:y1]")
        return 2

    a = Image.open(duong[0]).convert("RGBA")
    b = Image.open(duong[1]).convert("RGBA")
    if a.size != b.size:
        print("KHAC CO ANH: %s vs %s" % (a.size, b.size))
        return 1
    if cat is not None:
        a = a.crop((0, cat[0], a.size[0], cat[1]))
        b = b.crop((0, cat[0], b.size[0], cat[1]))

    # Lech cua moi diem anh = muc lech LON NHAT trong bon kenh.
    r, g, bl, al = ImageChops.difference(a, b).split()
    m = ImageChops.lighter(ImageChops.lighter(r, g), ImageChops.lighter(bl, al))
    hist = m.histogram()
    w, h = a.size
    tong = w * h
    khac = sum(hist[1:])
    khac_manh = sum(hist[NGUONG_KE + 1:])
    lech_lon_nhat = max(i for i, v in enumerate(hist) if v)

    print("%s  vs  %s" % (duong[0], duong[1]))
    print("  co anh        %dx%d = %d diem%s" % (w, h, tong,
            "" if cat is None else "  (cat y %d..%d)" % cat))
    print("  khac          %d diem (%.4f%%)" % (khac, 100.0 * khac / tong))
    print("  khac > %-2d muc %d diem" % (NGUONG_KE, khac_manh))
    print("  lech lon nhat %d" % lech_lon_nhat)
    if khac:
        # Hop bao lay tren vung khac MANH, khong phai vung lech 1 muc: vung lech
        # 1 muc thuong la ca khung hinh va khong chi duoc gi.
        hb = m.point(lambda v: 255 if v > NGUONG_KE else 0).getbbox()
        print("  hop bao (manh) %s" % (hb,))
        print("  KHAC NHAU")
    else:
        print("  GIONG HET — 0 diem anh khac")

    if giong and khac:
        return 1
    if doi and khac == 0:
        print("  PHEP KIEM KHONG CO LUC: doi khac ma ra 0 diem")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
