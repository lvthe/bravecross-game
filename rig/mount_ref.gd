# Ngua MAC DINH cua tung tuong (data_ref/mount_ref.json).
#
# Sinh bang `python ../brave-cross/work/mount_ref.py` tu khoa `<sDefaultMount>`
# cua `map/*.xml`. Do 2026-09-21 tren cay VN 1.26: quet CA 434 tep `map/*.xml`,
# khoa nay co DUNG **1** muc — `LvBuGod` -> `PonyChiTuGod`, trong khoi
# `<limited>` cua `heroex_config.xml`.
#
# Lua **0 dong** doc khoa nay trong `sc/`: engine C++ doc theo TEN, dung nhu
# `ptLayout` (`+0x460`).
#
# Ten o day la ten MON DO cua bang do (`map/gear_config.xml`), kieu `node_con` /
# `loai = Mount` — KHONG phai ten xuong. Nen gan no bang dung duong `setGear`
# (`SngRig.dat_do`), chu khong phai bang cach tu gan xuong nao.
#
# Vi sao phai co: `<sDefaultMount>` la nua con lai cua loi phan nan "tuong co
# ngua thi khong hien hinh". Duong tran da goi duong gan do, nhung chi gan nhung
# mon ma KICH BAN dua ra; con luat "tuong nay mac dinh cuoi con gi" thi chua ai
# doc, nen Lu Bo (man huong dan) vao tran khong co ngua.
class_name MountRef
extends RefCounted

const DUONG := "res://data_ref/mount_ref.json"

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


## Ngua mac dinh cua tuong `ten` (ten armature, vd "LvBuGod"). "" neu khong co.
##
## Tra theo TEN CHINH XAC truoc; khong co thi thu cac TIEN TO cua no (cung loi
## voi `SngRig.tim_thu_muc`): mot so don vi vao tran mang ten bien the
## (`LvBuGod_...`) chu khong phai ten muc cau hinh. Khong doan them gi khac.
static func mac_dinh(ten: String) -> String:
	_doc()
	var bang: Dictionary = _d.get("mac_dinh", {})
	if ten == "" or bang.is_empty():
		return ""
	if bang.has(ten):
		return String(bang[ten])
	var s := ten
	while s.contains("_"):
		s = s.substr(0, s.rfind("_"))
		if bang.has(s):
			return String(bang[s])
	_thieu[ten] = true
	return ""


## Ten da hoi ma khong co trong bang — de phep kiem in ra.
static func thieu() -> Array:
	return _thieu.keys()


## Ngua CAN gan THEM cho mot don vi; "" khi khong can.
##
## Ham THUAN (khong dung node nao) nen kiem tinh duoc. Hai luat, theo thu tu:
##
##   1. `do_ls` (danh sach do KICH BAN dua ra) da co mon ngua nao -> khong gan
##      gi them: do kich ban la y muon cua kich ban, va luat mac dinh khong duoc
##      de len no.
##   2. Chua co -> hoi `mac_dinh(hinh)`, `hinh` la ten ARMATURE cua don vi.
##
## Phep hoi "da co ngua chua" phai di qua BANG DO (`GearRef.la_mount`) chu khong
## doan theo ten: mot mon ngua khac co the mang ten bat ky, va doan theo ten thi
## trai `Pony*` se lot luoi (10 mon ngua cua bang gom ca `mount_169..176`).
static func ngua_can_gan(do_ls: Array, hinh: String) -> String:
	for ten in do_ls:
		if GearRef.la_mount(String(ten)):
			return ""
	return mac_dinh(hinh)
