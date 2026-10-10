# Bang NHAN SAT THUONG NOI cua ban goc (data_ref/nhan_ref.json).
#
# Sinh bang `python ../brave-cross/work/nhan_ref.py` tu khoi `<label>` cua
# `map/global_config.xml`, kem bo glyph cua tung phong doc thang tu `.fnt`.
#
# THAT — sau loai, moi loai mot HE SO PHONG va mot TRAN SO NHAN (khong hon):
#
#     loai       he so   tran        loai       he so   tran
#     Foe        0.825     30        Increase   0.710    100
#     Troop      1.000     50        Bonus      0.700     30
#     Critical   1.000     40        Shield     0.700     50
#
# Phep tra khoa: **BANG TEN**, khong phai bang chi so — va do la cho phai noi
# ro vi no la mot ngo cut. `libgame.so` (ban vn) khong co MOT word 4 byte nao
# tro vao vung chuoi 0x7b8000..0x7b81c0 (12 khoa nhan) hay 0x7c0e16..0x7c0e70
# (ten `.fnt`): da quet ca file, ca hai chieu, ke ca bang dich chuyen REL. Cung
# loi voi `PosX` o `0x7bc0b7` — `CLAUDE.md` da ghi. Lua thi **0 dong** doc
# `RiseLabel` (quet 1013 tep `sc/*.lua`), nen khong co duong nao tu du lieu
# nguoc ra cach ghep. Xem `PHONG_DAT` duoi day.
#
# Mot dieu DO duoc va co ich (2026-09-21): nam ten trang `fonts/Impact*_0.png`
# nam lien nhau trong mot bang con tro o **file offset 0x8694d8**, thu tu
# White, Yellow, Red, Green, Blue. Nhung bang ay la mot danh sach TAI NGUYEN
# NAP SAN chu khong phai bang tra theo loai — ngay sau nam cai ten ay la
# `map/PonyBlue.png`, `map/Triones.png`, `map/SuperHalo.png`, `map/BuffHalo.png`,
# va truoc chung la `png/ribbon/Shadow.png`, `sngSplitData/SmallIcon/…`,
# `map/ItemLight.png`. Nen thu tu ay **khong** noi len thu tu loai nao, va no
# khong khop voi thu tu nao cua khoi `<label>`. Ghi lai de lan sau khong ai
# tuong no la bang ghep.
class_name NhanRef
extends RefCounted

const DUONG := "res://data_ref/nhan_ref.json"

## Sau loai, theo DUNG thu tu cua khoi `<fRiseLabel_*>` trong cau hinh.
const LOAI: Array[String] = ["Foe", "Troop", "Critical", "Increase", "Bonus", "Shield"]

## Loai -> ten phong bitmap. **DAT.**
##
## Khong co duong nao khoi phuc duoc phep ghep nay (xem dau tep), nen day la
## MOT SUY DOAN co ghi ro can cu, khong phai so lieu:
##
##   * `Critical` -> `CriticalFont`, `Shield` -> `ShieldWhite`: can cu MANH NHAT
##     — TEN KHOA TRUNG TEN PHONG. Bon loai con lai khong co gi nhu vay.
##   * Bon loai con lai trai tren nam phong `Impact*`. `Increase` -> green vi
##     y nghia "hoi mau" di voi mau xanh, va `ImpactGreen` CO glyph `+` (do:
##     bo glyph `'!+-0123456789'`) dung cho mot luong cong vao. `Foe` -> red vi
##     day la con so sat thuong danh vao DICH. `Bonus` -> yellow, `Troop` ->
##     white de cho het luot.
##   * **`ImpactBlue` KHONG duoc dung.** Sau loai, bay phong so — mot cai thua.
##     Noi ra cho nguoi doc biet, chu khong nhet no vao mot loai de "du cho".
##   * Thu tu khac cung chap nhan duoc: `Troop` -> blue thay vi white. Hai
##     phong ay cung ho glyph 10/11 ky tu, nen **khong co du lieu nao phan biet**
##     duoc chung. Doi lai khong co can cu nao moi.
##
## Sua bang cach nao: neu sau nay moc duoc ban goc (`work/emu_*.py`) thi doc
## node nhan luc chay roi doi chieu — luc do sua thang bang nay va giu nguyen
## phan do duoc cua json.
const PHONG_DAT := {
	"Foe": "ImpactRed",
	"Troop": "ImpactWhite",
	"Critical": "CriticalFont",
	"Increase": "ImpactGreen",
	"Bonus": "ImpactYellow",
	"Shield": "ShieldWhite",
}

## Ho phong cua nhan sat thuong: chi chu so, dau tru, dau cong, dau cham than.
## Do 2026-09-21 — bay phong thoa man, ba phong con lai la ho CHU (95 glyph
## ASCII hoac chu CJK). Truong `ho` cua json do tu bo glyph chu khong doan.
const HO_SO := "so"

static var _d: Dictionary = {}
static var _da_doc := false


static func _doc() -> void:
	if _da_doc:
		return
	_da_doc = true
	var f := FileAccess.open(DUONG, FileAccess.READ)
	if f == null:
		push_warning("NhanRef: chua co %s — chay: python ../brave-cross/work/nhan_ref.py" % DUONG)
		return
	var v = JSON.parse_string(f.get_as_text())
	if v is Dictionary:
		_d = v


## He so phong cua mot loai. 0.0 neu khong co (goi ben ngoai nen coi la "khong ve").
static func he_so(loai: String) -> float:
	_doc()
	var b: Dictionary = _d.get("he_so", {})
	return float(b.get(loai, 0.0))


## Tran SO NHAN cung luc cua mot loai. 0 neu khong co (khong chan gi).
static func tran(loai: String) -> int:
	_doc()
	var b: Dictionary = _d.get("tran", {})
	return int(b.get(loai, 0))


## Ten phong bitmap cua mot loai — **DAT**, xem `PHONG_DAT`.
static func phong_cua(loai: String) -> String:
	return String(PHONG_DAT.get(loai, ""))


## Duong `.fnt` da xuat cho mot ten phong. "" neu phong khong co trong ban goc.
##
## Duong nay chi tra ve khi TEN PHONG CO THAT trong json — khong tu bia duong
## dan, vi mot `.fnt` khong ton tai thi `load()` tra `null` va nhan ra chu
## KHONG, im lang.
static func duong_fnt(ten: String) -> String:
	_doc()
	var b: Dictionary = _d.get("phong", {})
	if not b.has(ten):
		return ""
	return "res://assets_ref/fonts/%s.fnt" % ten


## Bo glyph cua mot phong trong ban goc (do tu `.fnt`), {} neu khong co.
static func phong(ten: String) -> Dictionary:
	_doc()
	var b: Dictionary = _d.get("phong", {})
	return b.get(ten, {})


## Moi ten phong doc duoc tu ban goc, sap theo ten.
static func ds_phong() -> Array:
	_doc()
	var b: Dictionary = _d.get("phong", {})
	var r := b.keys()
	r.sort()
	return r


## Cac loai THIEU du lieu (khong he so, khong tran, hoac phong khong co). De phep
## kiem in ra theo ten chu khong de no lang le thieu.
static func thieu() -> Array:
	_doc()
	var r: Array = []
	for k in LOAI:
		if he_so(k) <= 0.0 or tran(k) <= 0 or duong_fnt(phong_cua(k)) == "":
			r.append(k)
	return r
