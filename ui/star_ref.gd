# So do HIEU UNG SAO theo cap sao cua tuong (data_ref/star_ref.json).
#
# Sinh bang `python ../brave-cross/work/star_ref.py` tu `map/global_config.xml`
# (khoi `<star>`) va doi chieu voi `map/StarLevelEffect.xml`.
#
# THAT (doc tu cau hinh goc):
#   * Khoa cau hinh la `lsStarLevelEffect_<cap>`; moi khoa liet ke cac ten BIEN
#     THE cua armature hieu ung. Cap 2 chi co `StarLevelEffect_2Up`; cap 3..7 co
#     du `..._NUp` va `..._NDown` (phan tren nguoi va phan duoi chan — do hinh
#     hoc: `_NUp` 7..11 xuong, y −231,3..0; `_NDown` 1..5 xuong, y −113,5..+13).
#   * **CAP 1 KHONG CO HIEU UNG** — khoi `<star>` bat dau tu `_2`. Do cung la ly
#     do `NumberUtils.Range(HeroGrowthFactor or 1, 1, 7)` tra 1 thi khong thay gi.
#   * Moi bien the HIEU UNG co DUNG MOT dong tac, ten `PluginPlay` (do tren ca 23
#     bien the cua file armature, khong phai suy tu mot mau). 12 bien the con lai
#     trong file ten `StarLevelEffect_mc_*` la RIG LONG NHAU, dong tac `Play` —
#     bang so lieu ghi ro tung loai o truong `loai`.
#
# Phia ma may: `_Lua_addStarLevelEffect` = `libgame.so` 0x41ba6c (ten ham o
# `.rodata 0x7b50d9`, hai bang bind tro toi cung dia chi 0x41ba6d). Trong do:
# `snprintf(buf, 63, "lsStarLevelEffect_%d", n)` (0x41b9ec / 0x20261c) roi tao
# node THEO KHOA do, dat ten moi node la `StarLevelEffect_` (+0x120), va khi co
# co thi goi `0x418628(self, "StarLevelEffect_")` de XOA cai cu truoc.
#
# KHONG KHOI PHUC DUOC (ghi ra, khong bia):
#   * Node nao la CHA cua cac armature hieu ung. Ma may cho thay chung duoc tao
#     theo khoa cau hinh roi dat ten, nhung khong doc ra cho gan. Ban dung gan
#     vao chinh node tuong (xem `lua/cocos.lua`, `Node:_Lua_addStarLevelEffect`).
#   * Thu tu VE cua `_Up` so voi `_Down`. Ban dung giu dung thu tu trong cau
#     hinh; chua do duoc ben nao ve tren.
class_name StarRef
extends RefCounted

const DUONG := "res://data_ref/star_ref.json"

## Dong tac duy nhat cua moi bien the hieu ung sao — do tren ca 23 bien the cua
## `map/StarLevelEffect.xml` (11 hieu ung `PluginPlay` + 12 rig long nhau `Play`).
const DONG_TAC := "PluginPlay"

## Khoang cap sao co muc trong cau hinh. Cap 1 khong co gi; tren 7 cung khong.
const CAP_MIN := 2
const CAP_MAX := 7

static var _d: Dictionary = {}
static var _da_doc := false


static func _doc() -> void:
	if _da_doc:
		return
	_da_doc = true
	var f := FileAccess.open(DUONG, FileAccess.READ)
	if f == null:
		push_warning("StarRef: chua co %s — chay: python ../brave-cross/work/star_ref.py --json ../../bravecross-game/%s"
				% [DUONG, DUONG])
		return
	var v = JSON.parse_string(f.get_as_text())
	if v is Dictionary:
		_d = v


## Danh sach ten armature cho mot cap sao. Tra [] khi cap khong co muc nao —
## ke ca cap 1, va ca khi `cap` khong phai so (ma goc: `NumberUtils.Range(...,1,7)`
## nen gia tri that luon nam trong 1..7).
static func dongtac(cap) -> Array:
	_doc()
	if typeof(cap) != TYPE_INT and typeof(cap) != TYPE_FLOAT:
		return []
	var n := int(cap)
	if n < CAP_MIN or n > CAP_MAX:
		return []
	var b: Dictionary = _d.get("dongtac", {})
	return (b.get(str(n), []) as Array).duplicate()


static func co_hieu_ung(cap) -> bool:
	return not dongtac(cap).is_empty()


## Ten nay co phai bien the HIEU UNG khong (duoc khoi `<star>` cua cau hinh goi
## ten, dong tac `PluginPlay`)? Tra false cho 12 ten `StarLevelEffect_mc_*` —
## do la rig LONG NHAU, dong tac cua chung ten `Play` va chung khong bao gio
## duoc cau hinh goi thang.
static func la_hieu_ung(ten: String) -> bool:
	_doc()
	var b: Dictionary = _d.get("bien_the", {})
	if b.has(ten):
		return String((b[ten] as Dictionary).get("loai", "")) == "hieu_ung"
	return false


## So xuong cua mot bien the — de phep kiem doi chieu voi so do cua file JSON
## (bay nghiem trong: chon nham bien the trong cung file armature thi so xuong
## lech ngay, `StarLevelEffect_3Up` 7 xuong con `_3Down` 1 xuong).
static func so_xuong(ten: String) -> int:
	_doc()
	var b: Dictionary = _d.get("bien_the", {})
	if b.has(ten):
		return int((b[ten] as Dictionary).get("so_xuong", 0))
	return 0


static func co_bang() -> bool:
	_doc()
	return not _d.is_empty()
