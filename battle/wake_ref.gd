# So lieu ky nang THUC TINH cua ban goc (data_ref/wake_ref.json).
#
# Sinh bang `python ../brave-cross/work/wake_ref.py` tu cac khoi `<fight>` ten
# `fight_<Sprite>Wake` cua `map/hero_config.xml` + `map/sprite_config.xml`.
#
# THAT (doc tu cau hinh goc):
#   * so don   = 1 + so truong `fSectionIntervalWake_F<n>`, chan tren boi
#                `nAttackSectionLimitWake`. Trieu Van 1 don, Quan Vu 6, Tao Thuc 3.
#   * `fDamageBonusWake` = he so sat thuong THEM cua don thuc tinh.
#   * `nSplitWake`  = so muc tieu ma sat thuong duoc CHIA DEU. Nghia cua
#     "split" doc tu chinh ban goc: `global_config.xml` ghi
#     `<nSplitNumForAOE>6</nSplitNumForAOE>` ngay duoi chu thich "群攻分摊个数"
#     = "so muc tieu don danh dien rong chia deu sat thuong". Vay no KHONG phai
#     so don — gia thuyet cu da bi bac bo.
#   * `fSplitFloorWake` = muc san cua he so chia.
#
# DAT (luat GHEP nam trong ~80 lop C++ `CDFSpriteFight*Wake`, khong khoi phuc
# duoc tu du lieu):
#   * `fDamageBonusWake` ap theo kieu `dmg * (1 + bonus)`.
#   * he so chia = clamp(nSplitWake / <so muc tieu>, fSplitFloorWake, 1).
class_name WakeRef
extends RefCounted

const DUONG := "res://data_ref/wake_ref.json"

static var _d: Dictionary = {}
static var _da_doc := false
static var _thieu: Dictionary = {}


static func _doc() -> void:
	if _da_doc:
		return
	_da_doc = true
	if not FileAccess.file_exists(DUONG):
		return
	var f := FileAccess.open(DUONG, FileAccess.READ)
	if f == null:
		return
	var v = JSON.parse_string(f.get_as_text())
	if v is Dictionary:
		_d = v


static func _lay(ten: String) -> Dictionary:
	_doc()
	if ten == "":
		return {}
	if _d.has(ten):
		return _d[ten]
	if _d.has("fight_%sWake" % ten):
		return _d["fight_%sWake" % ten]
	_thieu[ten] = true
	return {}


## So don cua don thuc tinh. 0 = khong biet sprite do (nguoi goi tu quyet).
static func so_don(ten: String) -> int:
	var e := _lay(ten)
	return int(e.get("_so_don", 0))


## He so sat thuong them (`fDamageBonusWake`). 0 = khong co.
static func them(ten: String) -> float:
	return float(_lay(ten).get("fDamageBonusWake", 0.0))


## He so chia sat thuong khi danh `n` muc tieu. 1 = khong chia.
static func chia(ten: String, n: int) -> float:
	var e := _lay(ten)
	var so := float(e.get("nSplitWake", 0.0))
	if so <= 0.0 or n <= 0:
		return 1.0
	return clampf(so / float(n), float(e.get("fSplitFloorWake", 0.0)), 1.0)


## Sprite da hoi ma khong co trong bang — de phep kiem in ra.
static func thieu() -> Array:
	return _thieu.keys()
