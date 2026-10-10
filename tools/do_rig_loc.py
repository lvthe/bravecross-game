# Do xem bo loc `Layer*` cua SngRig (`rig/sng_rig.gd:CLUTTER_PREFIXES`) an mat
# bao nhieu armature — tuc bao nhieu armature dung ra KHONG CO GI.
#
# Vi sao can phep do nay: bo loc ay co y do rieng cua no (lo Photoshop con sot
# lai trong rig NHAN VAT — xem chu thich CLUTTER_PREFIXES), nhung no chay theo
# TEN xuong nen no khong phan biet duoc "lo thua" voi "xuong that cua mot rig
# ma toan bo xuong deu dat ten kieu Photoshop". Do tren du lieu that de biet
# lop nao trong hai lop do lon hon, thay vi sua mu.
#
# Cach do: voi tung bien the, lay danh sach xuong tu chinh du lieu dong tac
# (groups[].animations[].bones[]), roi xem moi xuong hien duoc gi:
#   * anh trong bang  -> spriteFiles  (duong cua ban goc)
#   * bien the khac   -> NESTED       (rig long nhau, cung file .json)
# Mot bien the ma SAU khi loc khong con xuong nao hien duoc gi tuc la armaturey
# ve ra man hinh trong tron.
#
#   python tools/do_rig_loc.py                 # tong ket
#   python tools/do_rig_loc.py --ke=20         # ke ra 20 bien the dau
#   python tools/do_rig_loc.py --loc=anh       # thu luat "chi loc khi la ANH"
import io
import json
import os
import sys
from collections import Counter

GOC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets_ref")

CLUTTER = ("Layer", "LayerName", "Logic_", "图层")


def la_clutter(ten):
    return ten.startswith(CLUTTER)


def doc_du_lieu():
    """[(ten_thu_muc, data)] cho moi assets_ref/<X>/<X>.json doc duoc."""
    ra = []
    for ten in sorted(os.listdir(GOC)):
        d = os.path.join(GOC, ten)
        f = os.path.join(d, ten + ".json")
        if not os.path.isfile(f):
            continue
        try:
            ra.append((ten, json.load(io.open(f, encoding="utf-8"))))
        except Exception:
            pass        # tep hong thi bo qua: day khong phai phep kiem tep hong
    return ra


def bang_cua(data):
    """(tap ten anh, tap ten bien the) cua mot file armature."""
    anh = set(data.get("spriteFiles", {}))
    bien_the = set(g.get("variant", "") for g in data.get("groups", []))
    return anh, bien_the


def xuong_cua(data, variant):
    """[(ten xuong, [ten hien])] cua mot bien the."""
    # Bo phan cua bien the: trong du lieu nay moi bien the ung dung MOT phan
    # cung ten (da kiem: parts[].name == groups[].variant cho ca 5 file xem tay).
    phan = {}
    for p in data.get("parts", []):
        if p.get("name") == variant:
            phan = p
            break
    hien = {}

    def di(n):
        for s in n.get("sprites", []):
            hien.setdefault(n.get("name", ""), []).append(s)
        for c in n.get("children", []) or []:
            di(c)

    di(phan)
    # Xuong that su la danh sach trong du lieu DONG TAC, chu khong phai moi
    # node trong cay bo phan (co node khong bao gio duoc dong tac cham toi).
    ra = []
    for g in data.get("groups", []):
        if g.get("variant") != variant:
            continue
        for a in g.get("animations", []):
            for b in a.get("bones", []):
                ten = b.get("name", "")
                if ten in hien:
                    ra.append((ten, hien[ten]))
    # Mot xuong co the hien o nhieu dong tac; giu mot lan.
    thay = set()
    loc = []
    for ten, ds in ra:
        if ten in thay:
            continue
        thay.add(ten)
        loc.append((ten, ds))
    return loc


def phan_loai(ds, anh, bien_the):
    """'anh' / 'nested' / 'khong' — xuong do hien duoc gi."""
    co_anh = any(s in anh for s in ds)
    co_nested = any(s in bien_the for s in ds)
    if co_anh:
        return "anh"
    if co_nested:
        return "nested"
    return "khong"


def rong_khi(data, v, anh, bien_the, luat):
    """Bien the nay co ve ra TRONG khong, duoi mot luat loc.

    `luat`:
      'khong'  khong loc gi (muc nen — day la cai ban goc ve ra)
      'ten'    loc theo TEN xuong (luat dang dung: `_is_clutter`)
      'anh'    chi loc khi xuong do hien ANH (luat dang thu)

    Tra ve `None` khi KHONG PHAI lo cua bo loc — tuc la loc hay khong loc thi
    bien the ay van trong. Loai do la chuyen khac (rig diem gan, rig rong that),
    khong duoc lan vao phep do nay.
    """
    giu = []
    for xuong, ds in xuong_cua(data, v):
        loai = phan_loai(ds, anh, bien_the)
        if la_clutter(xuong):
            if luat == "ten":
                continue
            if luat == "anh" and loai == "anh":
                continue
        giu.append(loai)
    return not any(loai != "khong" for loai in giu)


def main():
    ke = 0
    tim = ""
    for a in sys.argv[1:]:
        if a.startswith("--ke="):
            ke = int(a[5:])
        elif a.startswith("--tim="):
            tim = a[6:]

    so_bien_the = 0
    chi_ten, chi_anh = [], []
    so_bang_nhau = 0
    for ten, data in doc_du_lieu():
        anh, bien_the = bang_cua(data)
        for g in data.get("groups", []):
            v = g.get("variant", "")
            so_bien_the += 1
            if tim and (tim in ten or tim in v):
                nen = rong_khi(data, v, anh, bien_the, "khong")
                t = rong_khi(data, v, anh, bien_the, "ten")
                n = rong_khi(data, v, anh, bien_the, "anh")
                print("  %-34s %-34s nen_trong=%s ten_trong=%s anh_trong=%s"
                        % (ten, v, nen, t, n))
                continue
            nen = rong_khi(data, v, anh, bien_the, "khong")
            if nen:
                # Ban goc cung ve ra trong: khong phai chuyen cua bo loc.
                continue
            t = rong_khi(data, v, anh, bien_the, "ten")
            n = rong_khi(data, v, anh, bien_the, "anh")
            if t:
                chi_ten.append((ten, v))
            if n:
                chi_anh.append((ten, v))
            if t == n:
                so_bang_nhau += 1

    print("so thu muc armature doc duoc         : %d" % len(doc_du_lieu()))
    print("so bien the                          : %d" % so_bien_the)
    print("bien the ban goc VE RA TRONG         : (da tru, khong tinh)")
    print("bien the loc theo TEN lam thanh trong: %d" % len(chi_ten))
    print("bien the loc theo ANH lam thanh trong: %d" % len(chi_anh))
    print("  -> luat 'anh' cuu duoc             : %d" % (len(chi_ten) - len(chi_anh)))
    print("  -> luat 'anh' van con bo sot       : %d" % len(chi_anh))
    print("  -> hai luat GIONG NHAU o            : %d bien the" % so_bang_nhau)
    dem = Counter(t for t, _ in chi_ten)
    print("bien the bi loc lam trong thuoc %d armature" % len(dem))
    for t, n in dem.most_common(30):
        con = sum(1 for x, _ in chi_anh if x == t)
        print("    %-34s %3d bien the   (luat 'anh' cuu %d, con %d)"
                % (t, n, n - con, con))
    if ke:
        print("--- %d bien the bi loc lam trong dau tien:" % ke)
        for t, v in chi_ten[:ke]:
            print("    %-30s %s" % (t, v))


if __name__ == "__main__":
    main()
