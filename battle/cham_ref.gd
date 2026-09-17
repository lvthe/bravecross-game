# HOP CHAM cua armature (data_ref/cham_ref.json).
#
# Sinh bang `python ../brave-cross/work/cham_ref.py --json <duong dan>` tu 418
# file `map/*.xml`. Tra bang `ChamRef.ho_cham(<ten bien the>)`.
#
# CONG THUC (da do, khong phai suy doan):
#
#     hop = (w*sx*|cos rot1| + h*sy*|sin rot1| ,
#            h*sy*|cos rot2| + w*sx*|sin rot2|)
#
#   * `w, h` la `sourceSize` cua BAN GHI `.plist` — cap float thu 12, 13 cua ban
#     ghi 60 byte, o `+0x34` (`sngxml.py` doc ra duoi ten `sourceSize`). Do la o
#     cua sprite theo dung nghia engine dung (`CCSpriteFrame::getOriginalSize`).
#     Tai lieu nay TUNG noi "khung cua ban ghi sprite trong .xml" — SAI, va phep
#     so dung de ket luan ay khong phan biet duoc gi: `Hoplite_res-44` co `.xml`
#     3x3 va plist 1x1, nhung `sourceSize` cua chinh anh ay CUNG la 3x3. Ba phep
#     do tren may ao moi tach duoc hai nguon, va ca ba deu noi `sourceSize`:
#     BatFlight 145,00999450684 x 120 (= 1 x 145,01; `.xml` doi ra 290,02),
#     DragonFlight 175 x 145 (`.xml` 350 x 290), DragonFlight `Head` 64 x 64
#     (`.xml` 65 x 64).
#   * `sx, sy, rot1, rot2` la KHOA 0 cua xuong `Collision` cua bien the.
#   * `|cos|` chu khong phai `cos`: hinh chu nhat quay goc 180 (co lat) cho
#     `cos = -1`, de nguyen dau thi be cao ra AM.
#   * Goc tinh bang DO. Voi goc bang 0 thi cong thuc thoan hoa thanh `w*sx`,
#     `h*sy`.
#
# CACH TIM RA: bang bind cua lop armature o `.data` 0x937350 (81 ban ghi 12
# byte, KHONG nam trong 132 lop cua `binder.py`) tro toi `0x2ab932`, than ham
# doc hai float roi `lua_pushnumber` HAI lan — mot CAP so, khong phai mot so.
# No goi `0x2ab860`, ma `.symtab` goi dung ten
# `std::map<int, CDFColliderBoneInfo>::operator[]` — tuc cap so nam trong mot
# ban ghi tren chinh armature o `+0x27c`, khoa 0.
#
# DO CHINH XAC, noi dung muc:
#   * `rot = 0` — khop TUNG BIT voi ban goc (7 phep do tren may ao, lech
#     <= 4e-12, tuc chi con sai so bieu dien float32).
#   * `rot = 180` — cung khop tung bit, va khong phai trung ngau nhien:
#     `|cos 180| = 1`, `|sin 180| = 0` nen khong co duong luong giac nao chay.
#     Quet ca 590 bien the thi chi co DUNG BA gia tri goc: 0, 180, va ba rig
#     duoi day — nen 587/590 bien the roi vao hai ca khop bit.
#   * Goc nho khac 0 — CHI 3/590 bien the (`YuJin`, `MaYuanYi`, `GongSunZan`,
#     |rot| <= 0,08 do): lech toi da 2,2e-4 diem anh. Da thu mo hinh hoa phan
#     lech nay (coi nhu sai so cua chinh goc, suy nguoc tu so do) va no KHONG
#     theo mot luat nao — ghi lai la CHUA RO, khong gan cho mot nguyen nhan nao.
#     Anh huong: duoi 0,0002 diem anh, khong nhin thay duoc.
#
# BANG CO 590 DONG, khong phai 592: hai bien the `LvBuZhanShi_A2` va
# `LvBuZhanShi_Weapon1` dung anh `LvBuZhanShi_res-44`, ma `sourceSize` cua anh
# ay la `0 x 0` nen hop bang khong. (Hai bien the ay khong do duoc tren may ao —
# `getSpriteFromSpriteCatch("LvBuZhanShi_A2")` tra `nil` — nen gia tri `0 x 0`
# cua chung la SUY theo cung mot luat; rig `LvBuZhanShi` thi do duoc va tra dung
# `0 x 0`.)
#
# TRA `(0, 0)` khi armature KHONG co xuong `Collision` — do la so ban goc tra
# ve (do tren `DaQuZhanShi`), chu khong phai mot mac dinh cua ta. Luu y
# `getContentSize()` la mot DAI LUONG KHAC, khong phai ham nay (DaQuZhanShi:
# getContentSize 104,78 x 123,24 con hop cham la 0 x 0).
#
# KHOA CUA BANG LA TEN BIEN THE, khong phai ten file: mot file `.xml` chua
# NHIEU armature (`CaoCao_WeaponWake`, `ZhangLiangBao_ZhangLiang`... la nhung
# hinh tuong RIENG, co rieng), va `SngRig` chi biet bien the no dung ra. Ten
# bien the hoac trung ten file (`Archer`) hoac la `<File>_<Hau to>`.
class_name ChamRef
extends RefCounted

const DUONG := "res://data_ref/cham_ref.json"

static var _d: Dictionary = {}
static var _da_doc := false
static var _thieu: Dictionary = {}


static func _doc() -> void:
	if _da_doc:
		return
	_da_doc = true
	var f := FileAccess.open(DUONG, FileAccess.READ)
	if f == null:
		push_warning("ChamRef: chua co %s — chay: python ../brave-cross/work/cham_ref.py --json %s"
				% [DUONG, DUONG])
		return
	var v = JSON.parse_string(f.get_as_text())
	if v is Dictionary:
		_d = v


static func co_bang() -> bool:
	_doc()
	return not _d.is_empty()


static func so_bien_the() -> int:
	_doc()
	return int(_d.get("so_bien_the", 0))


## Muc day du cua mot bien the (rong, cao, va ca thanh phan dung ra chung) —
## de phep kiem tinh lai cong thuc tu chinh cac thanh phan ay. {} neu khong co.
static func muc(bien_the: String) -> Dictionary:
	_doc()
	var bang: Dictionary = _d.get("cham", {})
	if bien_the == "":
		return {}
	if bang.has(bien_the):
		return bang[bien_the]
	_thieu[bien_the] = true
	return {}


## Hop cham cua mot bien the. `Vector2.ZERO` khi bang khong co muc nao — dung
## nhu ban goc tra (0, 0) cho armature khong co xuong `Collision`.
static func ho_cham(bien_the: String) -> Vector2:
	var m := muc(bien_the)
	if m.is_empty():
		return Vector2.ZERO
	return Vector2(float(m["rong"]), float(m["cao"]))


## Cac ten da hoi ma bang khong co — de phep kiem in ra, khong de doan bua.
static func thieu() -> Array:
	return _thieu.keys()


## Cong thuc hop bao cua mot hinh chu nhat quay goc, tach ra de dung CHUNG mot
## cho: bang `cham_ref.json` giu CAP SO da tinh (nen phep kiem tinh lai duoc doc
## lap voi Python), con `SngRig.hop_xuong` goi ham nay cho xuong BAT KY —
## `_lua_getBoneRectInNode` khong chi hoi xuong `Collision`.
static func tinh(wh: Vector2, rot1: float, rot2: float, sx: float, sy: float) -> Vector2:
	var a1 := deg_to_rad(rot1)
	var a2 := deg_to_rad(rot2)
	var w := wh.x * sx
	var h := wh.y * sy
	return Vector2(w * absf(cos(a1)) + h * absf(sin(a1)),
			h * absf(cos(a2)) + w * absf(sin(a2)))
