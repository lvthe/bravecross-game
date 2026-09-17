# So do BONG (shadow) cua ban goc (data_ref/bong_ref.json).
#
# Sinh bang `python ../brave-cross/work/bong_ref.py` tu `map/global_config.xml`
# va sau file `map/{hero,heroex,player,sprite,boss,evil}_config.xml`.
#
# THAT (doc tu cau hinh goc):
#   * `fShadowScaleRate` — ti le bong. Mac dinh 0,9, ghi ngay duoi chu thich
#     阴影 trong khoi `<stage>` cua `global_config.xml` (`<fShadowScaleRate>0.9`).
#     Sprite nao ghi rieng thi lay so rieng: 7 cho — 0,7 x3 (Hoplite, FengYaoJi,
#     BaiHuZi), 0,8 x2 (ZhangLiangBao, DongZhuoEvil), 0,76 (MaYuanYi), 1,0
#     (ElephantSoldier).
#   * `fShadowOpacity` — do dam. Chi 2 sprite ghi: DragonFlight, BatFlight, deu
#     0,8. Chu thich trong evil_config.xml ghi ro "阴影不透明度".
#   * Anh bong la MOT anh dung chung: duong tao bong cua engine
#     (`libgame.so` 0x419668) nap thang chuoi "Shadow.png" (0x7beccd), khong
#     theo ten sprite. Anh that: `png/ribbon/Shadow.pkm`, 164x22, xuat ra
#     `assets_ref/bong/Shadow.png`. Do lai tren chinh file PNG: alpha giua
#     112/255 = 0,439 va PHANG trong long hinh — elip dac vien cung noi tiep
#     trong o (hang giua 164 diem, hang dau = hang cuoi = 66), KHONG phai
#     gradient mem. Nen do dam nam o CHINH ANH, con `fShadowOpacity` nhan them
#     len tren (`modulate.a` nhan vao alpha cua texture).
#   * `sShadow` — ten tai nguyen bong rieng cua tung armature, LUON la
#     `<Ten>Shadow` va luon nam trong khoi `<limbs>` ten `limbs_<Ten>`
#     (120 khoi: hero 6, heroex 1, player 113; mau le: DaQiao → `DaQiaoReplica`).
#     Tai nguyen ay KHONG duoc ship: khong file .xml nao ten do, khong plist nao
#     chua no. Tra cuu thi tra, nhung ve thi phai ve bang chinh `Shadow.png` —
#     dung nhu duong tao bong cua engine.
#
# KHONG KHOI PHUC DUOC (ghi ra, khong bia):
#   * `nShadowSize` anh xa sang ti le nao. Ca 7 cho dat no deu la `2`. Bo doc
#     cau hinh cua engine doc khoa bang CHI SO TEN chu khong bang dia chi chuoi
#     (quet ca file khong co cho nao tro toi dia chi chuoi 'nShadowSize'), nen
#     khong lan ra bang tinh duoc. Vi vay ban dung KHONG dung toi `nShadowSize`,
#     va cung khong dung `fSmallShadowScale` 0,6 / `fBigShadowScale` 1,5 — hai
#     so do di voi viec phan loai nho/lon ma khong biet tieu chi.
#   * `fShadowOffsetRate` nhan voi cai gi. 8 sprite ghi (0,017…0,235); KHONG ap,
#     chi giu trong bang de con doi chieu.
class_name BongRef
extends RefCounted

const DUONG := "res://data_ref/bong_ref.json"

## Anh bong dung chung — xem chu thich dau file.
const ANH := "res://assets_ref/bong/Shadow.png"

## Ti le mac dinh khi sprite khong ghi rieng. Lay tu chinh file cau hinh goc,
## khong phai so cua ban dung.
const TI_LE_MAC_DINH := 0.9

static var _d: Dictionary = {}
static var _da_doc := false
static var _thieu: Dictionary = {}


static func _doc() -> void:
	if _da_doc:
		return
	_da_doc = true
	var f := FileAccess.open(DUONG, FileAccess.READ)
	if f == null:
		push_warning("BongRef: chua co %s — chay: python ../brave-cross/work/bong_ref.py --json %s"
				% [DUONG, DUONG])
		return
	var v = JSON.parse_string(f.get_as_text())
	if v is Dictionary:
		_d = v


## Muc cua mot ten sprite. Tra {} neu khong co. Ten la `sName` cua ban ghi
## trong `map/*_config.xml`; rig dat ten theo armature nen thu ca ten rut ngan
## dan (`Player004M03F` → `Player004`), cung luat voi SngRig._group().
##
## Ten nao khong co muc nao thi ghi vao `_thieu` — do la tin hieu that: 19
## sprite co so do bong, con lai khong khai gi nen an mac dinh.
static func _muc(ten: String) -> Dictionary:
	_doc()
	var bang: Dictionary = _d.get("muc", {})
	if ten == "":
		return {}
	if bang.has(ten):
		return bang[ten]
	var s := ten
	while s.contains("_"):
		s = s.substr(0, s.rfind("_"))
		if bang.has(s):
			return bang[s]
	_thieu[ten] = true
	return {}


## Ti le bong cua sprite: `fShadowScaleRate` rieng, khong co thi mac dinh 0,9.
static func ti_le(ten: String) -> float:
	_doc()
	var m := _muc(ten)
	if m.has("fShadowScaleRate"):
		return float(m["fShadowScaleRate"])
	return float(_d.get("toan_cuc", {}).get("fShadowScaleRate", TI_LE_MAC_DINH))


## Do dam cua bong: `fShadowOpacity`, khong co thi 1,0 (khong sprite nao khac
## ghi truong nay, nen 1,0 la "khong doi gi").
static func do_mo(ten: String) -> float:
	var m := _muc(ten)
	return float(m.get("fShadowOpacity", 1.0)) if m.has("fShadowOpacity") else 1.0


## `fShadowOffsetRate` — GIU LAI de doi chieu, KHONG dung de ve (chua biet nhan
## voi cai gi). 0,0 = sprite khong ghi.
static func do_lech(ten: String) -> float:
	var m := _muc(ten)
	return float(m["fShadowOffsetRate"]) if m.has("fShadowOffsetRate") else 0.0


## Ten tai nguyen bong ma ban goc tro toi (`sShadow`, vd "YuJinShadow"). Tra ""
## neu armature do khong khai. Tai nguyen nay KHONG duoc ship — xem dau file.
static func ten_bong(ten: String) -> String:
	_doc()
	var vai: Dictionary = _d.get("vai", {})
	if ten == "":
		return ""
	if vai.has(ten):
		return String(vai[ten])
	var s := ten
	while s.contains("_"):
		s = s.substr(0, s.rfind("_"))
		if vai.has(s):
			return String(vai[s])
	return ""


## Cac ten da hoi ma bang khong co — de phep kiem in ra, khong de doan bua.
static func thieu() -> Array:
	return _thieu.keys()


static func co_bang() -> bool:
	_doc()
	return not _d.is_empty()
