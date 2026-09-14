## Toc do di chuyen THAT cua tung sprite, doc tu map/*_config.xml cua ban goc.
##
## Vi sao khong dung truong `MovingSpeed` cua bang chi so tran: no KHONG HE co
## trong libgame.so. Quet bang ten chi so cua engine (quanh 0x7b42f0) thi thay
## `AttackInterval`, `InjuryRates`, `MaxAttackDistance`, `NpcSize`,
## `ClosePressing`, `Jump`... ma khong co `MovingSpeed`; client cung chi dung no
## lam chi so HIEN THI (`PropertyType.MovingSpeed = 21`, cho trang bi va man
## thong tin tuong). Tuc engine khong lay toc do tu do.
##
## Cho that: moi sprite co `<sMove>` tro toi mot khoi `<move>`, va khoi do ghi
##     <ptVector>{1.3,0}</ptVector>       -- di
##     <ptRunVector>{3,0}</ptRunVector>   -- chay
## don vi O, va 1 o = 100 px ("单位:格 100pix", chu thich trong hero_config.xml).
##
## Bang sinh bang: python ../brave-cross/work/move_speed.py
class_name MoveRef
extends RefCounted

const DUONG := "res://data_ref/move_ref.json"

static var _bang: Dictionary = {}
static var _da_nap := false
static var _thieu: Dictionary = {}


static func _nap() -> void:
	if _da_nap:
		return
	_da_nap = true
	if not FileAccess.file_exists(DUONG):
		push_warning("MoveRef: chua co %s — chay: python ../brave-cross/work/move_speed.py"
				% DUONG)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(DUONG))
	if d is Dictionary and d.has("sprites"):
		_bang = d["sprites"]


## Toc do DI, px/giay. 0 neu khong biet sprite do.
static func di(ten: String) -> float:
	return _lay(ten, "di")


## Toc do CHAY, px/giay. 0 neu khong biet.
static func chay(ten: String) -> float:
	return _lay(ten, "chay")


static func _lay(ten: String, truong: String) -> float:
	_nap()
	if ten == "" or not _bang.has(ten):
		if ten != "":
			_thieu[ten] = true
		return 0.0
	var e = _bang[ten]
	return float(e.get(truong, 0.0)) if e is Dictionary else 0.0


## Nhung ten sprite da hoi ma bang khong co — de biet con thieu gi.
static func thieu() -> Array:
	return _thieu.keys()
