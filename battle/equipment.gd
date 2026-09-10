## Luat trang bi — ban GDScript cua sim/equipment.py.
##
## Moi he so chep tu ban goc, KHONG tu can bang lai:
##
##   share_EquipmentLogic.lua          cuong hoa, chi phi, pham chat
##   share_EquipmentPropertyLogic.lua  gia tri cuong hoa theo loai chi so
##   share_configManager.lua:3221      trong so quy ra luc chien
##   Protocol.lua:466                  enum PropertyType
##
## Ba ban cai dat cua cung mot mo hinh, doi chieu nhau tung ca:
##   sim/equipment.py              mo hinh goc, Python
##   server/modules/equipment.lua  ban may chu
##   battle/equipment.gd           ban nay (client)
##
## Client tinh de HIEN THI (xem truoc luc chien, gia cuong hoa). Con so that
## van do may chu chot — y nhu cach mo hinh chien dau dang lam.
##
##   var e := Equipment.new(1, Equipment.AP, 100.0)
##   e.intensify = 30
##   print(e.capacity(), " ", e.cost_to_next())
class_name Equipment
extends RefCounted

# ----------------------------------------------------------- Protocol.lua:466
const HP_LIMIT := 1
const REDUCING_DAMAGE := 3
const FIRE_RES := 5
const ICE_RES := 6
const THUNDER_RES := 7
const DP_ADDITION := 8
const CRITICAL_STRIKE := 16
const AP := 20

const PROPERTY_NAME := {
	HP_LIMIT: "HpLimit", REDUCING_DAMAGE: "ReducingDamage",
	FIRE_RES: "FireResistence", ICE_RES: "IceResistence",
	THUNDER_RES: "ThunderResistence", DP_ADDITION: "DpAddtion",
	CRITICAL_STRIKE: "CriticalStrike", AP: "Ap",
}

## Trong so quy tung loai chi so ra LUC CHIEN (share_configManager:3221).
## Bang nay noi len thang thiet ke: 1 diem chi mang dang 50, 1 diem mau dang
## 0.1 — mau di theo hang nghin con chi mang theo phan tram.
const CAPACITY_WEIGHT := {
	HP_LIMIT: 0.1,
	DP_ADDITION: 1.0,
	FIRE_RES: 18.0,
	ICE_RES: 18.0,
	THUNDER_RES: 18.0,
	CRITICAL_STRIKE: 50.0,
	AP: 0.9,
}

# ------------------------------------------------------- share_EquipmentLogic
const APPEND_UNLOCK_LEVEL := 4      ## AppendPropertyUnlockLevel
const APPEND_RANGE_MIN := 0.8       ## AppendPropertyRandomRangeMin
const APPEND_RANGE_MAX := 1.3       ## AppendPropertyRandomRangeMax
const RECAST_ITEM_ID := 97          ## RecastStroeItemID — da tay luyen

## Moi cap cuong hoa nhan them he so nay; qua 200 cap thi gap 2.4 lan.
## Tinh chu khong chep tay: viet tay mot hang so 17 chu so la mot cho de sai
## lang le, ma sai o day thi lech het thang cuong hoa.
static var INTENSIFY_STEP: float = pow(2.4, 1.0 / 200.0)

## Gia tri cuong hoa phu thuoc LOAI chi so: mau so va moc rieng cho tung loai.
## share_EquipmentPropertyLogic:getIntensifyPropertyVal
const _INTENSIFY_BY_TYPE := {
	AP: [35.0, 10],
	HP_LIMIT: [25.0, 50],
	DP_ADDITION: [30.0, 50],
}

# --------------------------------------------------------------- mot mon do
var part: int = 1          ## 1..6: vu khi, giap, day chuyen, nhan, giay, o phu
var level: int = 1         ## cap mon do — tu 4 tro len moi co thuoc tinh phu
var intensify: int = 0     ## cap cuong hoa
var quality: int = 1       ## pham chat
var main_type: int = AP    ## loai chi so chinh
var main_value: float = 0.0
var appends: Array = []    ## [[loai, gia tri], ...]


func _init(p_part: int = 1, p_type: int = AP, p_value: float = 0.0,
		p_level: int = 1, p_intensify: int = 0, p_quality: int = 1,
		p_appends: Array = []) -> void:
	part = p_part
	main_type = p_type
	main_value = p_value
	level = p_level
	intensify = p_intensify
	quality = p_quality
	appends = p_appends.duplicate(true)


# ------------------------------------------------------------- cong thuc goc
## increment = (Val / 25) * (2.4^(1/200))^level
## share_EquipmentLogic:GetIntensifiedIncrementWithLevel
static func intensify_increment(lv: int, value: float) -> float:
	return (value / 25.0) * pow(INTENSIFY_STEP, float(lv))


## Gia tri cuong hoa DUNG DE TINH LUC CHIEN, y het client ban goc.
##
## Ban goc KHONG dung cap cuong hoa o day — no dung mot moc CO DINH rieng cho
## tung loai (Ap moc 10, HpLimit va DpAddtion moc 50). Da kiem: ham co dung cap
## chi duoc goi tu GetIntensifiedIncrement, ma ham do bi comment toan bo trong
## ban phat hanh. Xem intensify_total() cho duong tang that.
static func intensify_property_val(value: float, prop_type: int) -> float:
	if not _INTENSIFY_BY_TYPE.has(prop_type):
		return 0.0
	var spec: Array = _INTENSIFY_BY_TYPE[prop_type]
	return value / float(spec[0]) * pow(INTENSIFY_STEP, float(spec[1]))


## Tong gia tri cuong hoa cong don tu cap 1 den `lv`.
##
## Cong thuc cua chinh tac gia ban goc (GetIntensifiedIncrement) — ham do da bi
## comment het trong ban phat hanh, nen duong tang that nam ben may chu ho, thu
## ta khong co. Day la co so hop ly nhat co duoc.
static func intensify_total(lv: int, base_value: float) -> float:
	var sum := 0.0
	for i in range(1, maxi(lv, 0) + 1):
		sum += intensify_increment(i, base_value)
	return sum


## Chi phi len cap cuong hoa tiep theo. Nhan doi moi 4,5 cap luc dau, gian ra
## 6,5 cap sau cap 31 — ban goc co y lam cham lam phat o khoang giua.
## share_EquipmentLogic:GetResourceForIntensifyWithQualityAndLevel
static func intensify_cost(lv: int) -> float:
	var n := float(lv - 1)
	if n > 30.0:
		return 140.0 * pow(pow(2.0, 1.0 / 6.5), n)
	return 25.0 * pow(pow(2.0, 1.0 / 4.5), n)


## (baseVal/coefficient + 0.3) / quality — share_EquipmentLogic:GetQualityRange
static func quality_range(base_value: float, coefficient: float,
		p_quality: float) -> float:
	if is_zero_approx(coefficient) or is_zero_approx(p_quality):
		return 0.0
	return (base_value / coefficient + 0.3) / p_quality


static func weight_of(prop_type: int) -> float:
	return float(CAPACITY_WEIGHT.get(prop_type, 0.0))


## Gia tri mot thuoc tinh phu: ngau nhien 0,8..1,3 lan gia tri goc.
## `rnd` mang seed rieng de con lap lai duoc.
static func roll_append(base_value: float, rnd: RandomNumberGenerator) -> float:
	return base_value * (APPEND_RANGE_MIN
			+ rnd.randf() * (APPEND_RANGE_MAX - APPEND_RANGE_MIN))


## Trang bi noi vao mo hinh chien dau qua DUNG cai kenh buff ma the tran dang
## dung (xem Fighter._init trong battle/combat.gd) — khong mo duong rieng.
##
## Bon loai chi so co cho tuong ung; ba loai khang he va ReducingDamage thi
## CHUA co he tuong ung ben game moi, nen bo qua co y thuc.
const BUFF_KEY := {
	HP_LIMIT: "hp",
	AP: "ap",
	DP_ADDITION: "dp",
	CRITICAL_STRIKE: "crit",
}


## Gop chi so cua mot dam trang bi thanh bang buff cho mo hinh chien dau.
static func to_buffs(items: Array) -> Dictionary:
	var out := {}
	for e in items:
		var st: Dictionary = e.stats()
		for t in st:
			if not BUFF_KEY.has(int(t)):
				continue
			var k: String = BUFF_KEY[int(t)]
			out[k] = float(out.get(k, 0.0)) + float(st[t])
	return out


## Cong hai bang buff. Trang bi va the tran di chung mot bang, cong don tung
## khoa — nho vay thu tu ap dung khong con quan trong, va ba ban cai dat chac
## chan ra cung mot so.
static func merge_buffs(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for k in b:
		out[k] = float(out.get(k, 0.0)) + float(b[k])
	return out


# ------------------------------------------------------------- mot mon cu the
func append_unlocked() -> bool:
	return level >= APPEND_UNLOCK_LEVEL


## { loai chi so: tong gia tri } sau cuong hoa va thuoc tinh phu.
func stats() -> Dictionary:
	var out := {}
	out[main_type] = float(out.get(main_type, 0.0)) + main_value
	var bonus := intensify_total(intensify, main_value)
	if bonus != 0.0:
		out[main_type] = float(out.get(main_type, 0.0)) + bonus
	if append_unlocked():
		for a in appends:
			var t := int(a[0])
			out[t] = float(out.get(t, 0.0)) + float(a[1])
	return out


## Luc chien: tung chi so nhan trong so cua no roi cong lai.
func capacity() -> float:
	var sum := 0.0
	var st := stats()
	for t in st:
		sum += float(st[t]) * weight_of(int(t))
	return sum


## Luc chien tinh Y HET client ban goc, de doi chieu: dung moc co dinh thay vi
## cong don theo cap, nen KHONG doi theo cap cuong hoa.
## share_EquipmentLogic:CalcEquipFightingCapacity
func capacity_as_original() -> float:
	var out := (main_value + intensify_property_val(main_value, main_type)) \
			* weight_of(main_type)
	if append_unlocked():
		for a in appends:
			out += float(a[1]) * weight_of(int(a[0]))
	return out


func cost_to_next() -> float:
	return intensify_cost(intensify + 1)


## Tong chi phi cuong hoa tu cap hien tai len `target`.
func cost_to_level(target: int) -> float:
	if target <= intensify:
		return 0.0
	var sum := 0.0
	for lv in range(intensify + 1, target + 1):
		sum += intensify_cost(lv)
	return sum


func _to_string() -> String:
	return "Equipment(o %d, %s %.1f, +%d, pham %d, luc chien %.0f)" % [
			part, PROPERTY_NAME.get(main_type, "?"), main_value,
			intensify, quality, capacity()]
