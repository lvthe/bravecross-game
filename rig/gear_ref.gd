# Bang DO (trang bi) cua armature — doc `data_ref/gear_ref.json`.
#
# Sinh bang `python ../brave-cross/work/gear_ref.py --json ../../bravecross-game/data_ref/gear_ref.json`
# tu `map/gear_config.xml` (201 muc `<Gear>`), doi chieu nguoc voi `assets_ref`.
#
# VI SAO CO TEP NAY
# -----------------
# Ban goc gan do bang ham TOAN CUC `setGear(pRole, value)` — 10 cho goi THAT
# trong `sc/` (quet ca 1013 file .lua: 19 dong chua chu "setGear", 8 dong la
# `setLevelGear`, 1 dong bi chu thich), goi tu
# `ClientPaperDoll:ChangePaperDollHelper`:
#
#     for key,value in pairs(tSkinMap) do setGear(pRole, value) end
#
# `setGear` khong phai phuong thuc cua lop nao, va `__index` cua lop gia lap tra
# ham cho MOI ten — nen thieu no thi moi loi goi di vao HU KHONG va **khong mot
# dong loi**. Hau qua do duoc: xuong `Weapon` cua nhan vat chinh con nguyen anh
# MAC DINH cua armature (`Player000_Eff-EquipQin_5`, cap 5) trong khi du lieu
# noi cap 0 (chi tiet ben duoi).
#
# **Nhan vat chinh dung BIEN THE NAO** — do tu du lieu, khong suy: `HeroID 25`
# cua `battle_data.json` (`heroes`) co `HeroSprite = "Player000M03W"`, tuc dung
# bang ten bien the. Bon bien the `Player000W03W` / `W03F` / `M03W` / `M03F` deu
# mang `Player000_Eff-EquipQin_5` o xuong `Weapon` (29/29/31/31 xuong), nen cap
# 5 la MAC DINH cua armature chu khong phai do ai dat. **Bay do duong**: bien the
# ten tran `Player000` (30 xuong) co xuong `Weapon` **RONG** (0 o hien) — do
# `SngRig.build(..., "Player000", ...)` ra mot rig khac han nhan vat chinh, va
# mot phep do tren no se ket luan sai la "khong co dan".
#
# Nam kieu cua `nShowType`, nguyen van tu chu thich trong chinh file bang:
#
#     1 doi texture · 2 doi ARM cua khop · 3 doi hat ·
#     4 doi NODE CON · 5 doi vu khi nem
#
# Do duoc bon dang muc LA:
#
#     equip_3_0     Weapon 2  sBone Weapon  sArmtureName EquipQin_1
#     equip_3_7..10 Weapon 2  sBone Weapon  sArmtureName EquipQin_6  (chan tren)
#     equip_3_999   Weapon 2  sBone Weapon  sArmtureName EquipQin_0  <- O TRONG
#     wing_1_5      Wing   4               sPropertyName EquipWing_05
#
# BANG CO **NAM LOAI MUC** trong 201 `<Gear>` (do theo TRUONG, khong theo ten):
#
#   * LA (115 muc, co `nShowType`): 88 kieu 2 (87 Weapon + 1 Effect) va 27 kieu
#     4 (17 Wing + 10 Mount). **Khong muc nao kieu 1, 3 hay 5** — nen kieu 1 va
#     kieu 2 chi con la hai nhanh cua duong DU PHONG, khong phai muc trong bang.
#   * BUNDLE (70 muc, co `lsGear`): mot danh sach ten do khac. `DefenderN_lv1`
#     -> 4 ten la. Ten bundle la TEN DON VI + CAP (`ArcherN_lv7`), nen no thuoc
#     duong `setLevelGear` — ham anh em cua `setGear`, va co **3 cho goi THAT
#     trong `sc/`** (`CUIBarracksMain.lua:1036`, `CUIBarracksArmyInfo.lua:272` —
#     hai man DOANH TRAI — va `CUIPopUpBox.lua:723`), KHONG thuoc 10 cho goi
#     `setGear`. Truoc luot nay cho nay ghi "0 cho goi": SAI, do phuong phap
#     (chi quet `setGear` roi suy ra cho ham anh em).
#   * PARTS (7 muc, co `lsParts`): `SpearmenN_Spear_lvN` -> hai muc `<Parts>`.
#   * BASEITEM (3 muc): chuyen tiep sang do khac, `Witch_lv7` -> `Witch_lv6`.
#   * LIST (6 muc): chon theo cap, `equip_Exclusive_10_List` ->
#     `sGear_lv5plus = equip_Exclusive_10_5`.
#
# `<Parts>` la bang RIENG (14 muc nam LAN trong `<Gears>`, xen giua cac `<Gear>`):
#
#     SpearmenN_Spear_lv1_Texture  nPartsType 1  sBone Spear
#                                  sTextureName SpearmenN_res-Spear_lv1
#     SpearmenN_Spear_lv1_Throw    nPartsType 5  sWeaponFight SpearmenN_Weapon_Lv1
#
# `nPartsType` dung LAI dung bo ma cua `nShowType` (1 = texture, 5 = nem).
#
# LUAT DU PHONG khi ten khong co trong bang (nguyen van tu file bang):
#
#     Neu <sGear>DefenderN_Sword_lv1</sGear> khong tim thay cau hinh tuong ung
#     thi mac dinh tach ten ra va dung cach doi TEXTURE. Vi du
#     DefenderN_Sword_lv1 se dung texture DefenderN_res-Sword_lv1 de thay
#     texture cua khop Sword. Chi co hai tham so thi chi ghep hai tham so.
#
# Do het 201 ten la do 70 bundle sinh ra (7 co muc san, 201 di du phong):
#
#     179  -> texture THAT theo dung cong thuc tren
#      21  -> `_Hide`: AN xuong `<doan 2>` (moi xuong ay deu co that, do ca 21)
#       1  -> khong ra: `CavalryAlpaca_ABody_lv1_lv4` — hau to cap lap, va
#             `CavalryAlpaca` khong co xuong `ABody`. Loi du lieu goc.
#
# Nen luat du phong la HAI nhanh, khong phai mot. `_Hide` KHONG phai ten texture
# hong — no la lenh AN, va do la cach bundle tat phu kien (mu, vai, toc).
#
# **Cong thuc nay duoc CHINH FILE xac nhan.** Bang `<Parts>` khai ket qua cua
# cung phep doi ay tuong minh: 7/7 muc `<Parts>` `nPartsType 1` co
# `(sBone, sTextureName)` TRUNG KHIT cong thuc du phong tinh tu ten cua chung.
# Hai cho doc lap trong cung mot file, cung mot dap so.
#
# BA DIEU DE DOC NHAM (do duoc, dung suy lai):
#
#   * **`equip_3_999` moi la "khong co do", khong phai cap 0.** `EquipQin_0` la
#     o TRONG: moi anh cua no 1x1 (`EquipQin_res-44`, do tu `spriteFiles`).
#     Trong ca 201 muc chi dung MOT muc ra trong, va 88 muc con lai deu co anh
#     that. Cap 0 la do THAT (`EquipQin_1`).
#   * **Cap bi CHAN TREN**: 7..10 deu tro ve `EquipQin_6`; art chi co 1..6. Nen
#     dung theo bang, dung tu suy "cap N -> ten co hau to N".
#   * **Khong suy duoc ten armature tu ten do.** `equip_4_5` -> `EquipZhang_5`
#     (QUAT), trong khi anh `Zither_res-equip_4_5_client` nam trong atlas
#     `EquipQin`; con `equip_3_5` -> `EquipQin_5` (DAN). Phai doc bang.
#
# CHUA LAM (ghi ra, khong im lang): kieu 1 (doi texture), 3 (doi hat) va 5 (doi
# vu khi nem) chua co trong ban dung. Bang chi co 1 muc kieu 3 va khong muc nao
# kieu 5; kieu 1 va kieu 2 la hai nhanh cua duong DU PHONG.
class_name GearRef
extends RefCounted

const DUONG := "res://data_ref/gear_ref.json"

## `nShowType` — so khop hang so trong `map/gear_config.xml`.
const KIEU_TEXTURE := 1   # doi texture cua xuong `sBone`
const KIEU_ARMATURE := 2  # doi ARM cua khop `sBone`  — vu khi
const KIEU_HAT := 3       # doi he hat
const KIEU_NODE_CON := 4  # doi NODE CON             — canh / mount
const KIEU_NEM := 5       # doi vu khi nem

## Ten cua tung kieu, de thong bao loi doc ra duoc LY DO chu khong chi mot so.
const KIEU_TEN := {
	1: "texture",
	2: "armature",
	3: "hat",
	4: "node_con",
	5: "nem",
}

## Ten do du phong: `<arm>_<xuong>_lv<N>` -> texture `<arm>_res-<xuong>_lv<N>`.
const NGAN := "_res-"

## Duoi cua nhanh AN trong ten do phu kien: `<arm>_<xuong>_Hide`.
const AN := "Hide"

static var _d: Dictionary = {}
static var _da_doc := false


static func _doc() -> void:
	if _da_doc:
		return
	_da_doc = true
	var f := FileAccess.open(DUONG, FileAccess.READ)
	if f == null:
		push_warning("GearRef: chua co %s — chay: python ../brave-cross/work/gear_ref.py --json ../../bravecross-game/%s"
				% [DUONG, DUONG])
		return
	var v = JSON.parse_string(f.get_as_text())
	if v is Dictionary:
		_d = v


static func co_bang() -> bool:
	_doc()
	return not _d.is_empty()


## Muc cua mot ten do, hoac {} khi khong co. Tra ve ban SAO: noi goi hay ghi
## them truong (vd `trong`) vao ket qua ma khong lam ban bang dung chung.
static func muc(ten: String) -> Dictionary:
	_doc()
	var b: Dictionary = _d.get("do", {})
	if b.has(ten):
		return (b[ten] as Dictionary).duplicate(true)
	return {}


static func co(ten: String) -> bool:
	return not muc(ten).is_empty()


## `nShowType`, hoac 0 khi ten khong co trong bang (0 = khong co muc nao, tuc
## phai di duong DU PHONG).
static func kieu(ten: String) -> int:
	var m := muc(ten)
	if m.is_empty():
		return 0
	var n = m.get("nShowType")
	if typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT:
		return int(n)
	return 0


## Do nay KHONG ve gi (o trong 1x1). Chi dung mot muc trong ca bang:
## `equip_3_999`. Doc nham cho nay thi cap 0 ra hinh trong.
static func trong(ten: String) -> bool:
	return bool(muc(ten).get("trong", false))


## Xuong mang do (kieu 2 va 1), "" cho kieu 4 (node con khong gan theo xuong).
static func xuong(ten: String) -> String:
	return String(muc(ten).get("sBone", ""))


## Ten armature thay vao (kieu 2), hoac "" neu muc nay khong phai kieu 2.
static func armature(ten: String) -> String:
	return String(muc(ten).get("sArmtureName", ""))


## Ten node con / thuoc tinh thay vao (kieu 4), hoac "".
static func node_con(ten: String) -> String:
	return String(muc(ten).get("sPropertyName", ""))


## `ten` co phai mot mon NGUA khong (`loai = Mount`). Do 2026-09-21: bang do co
## dung **10** mon nhu vay — 8 mon `mount_169..176` cong hai ten tran
## `PonyChiTuGod` va `PonyBlue`, tren tong 201 muc.
##
## Dung cho luat NGUA MAC DINH (`rig/mount_ref.gd`): chi gan ngua mac dinh khi
## don vi CHUA co mon ngua nao, va phep hoi "da co ngua chua" phai hoi bang bang
## do chu khong bang cach doan ten (mot mon ngua khac co the mang ten bat ky).
static func la_mount(ten: String) -> bool:
	return String(muc(ten).get("loai", "")) == "Mount"


## LUAT DU PHONG cua chinh file bang, HAI nhanh, cho ten KHONG co trong bang:
##
##     <arm>_<xuong>_lv<N>  -> {kieu = "texture", xuong, texture =
##                              "<arm>_res-<xuong>_lv<N>"}
##     <arm>_<xuong>_Hide   -> {kieu = "an", xuong}
##
## Tra {} khi ten khong tach duoc (can it nhat hai doan, doan nao cung khac
## rong).
##
## Dung luat nay thay vi doan ten armature tu ten do — chinh file bang noi ro
## "mac dinh tach ten ra va dung cach doi TEXTURE", va do la duong duy nhat con
## lai khi bang khong co muc nao. `_Hide` la lenh AN chu khong phai ten texture
## hong: do la 21/201 ten la do bundle sinh ra, va moi xuong chung an deu CO
## THAT trong armature (do).
static func du_phong(ten: String) -> Dictionary:
	var phan := ten.split("_")
	if phan.size() < 2 or phan[0] == "" or phan[1] == "":
		return {}
	if phan[phan.size() - 1] == AN:
		return {"kieu": "an", "xuong": phan[1]}
	return {
		"kieu": "texture",
		"xuong": phan[1],
		"texture": phan[0] + NGAN + "_".join(phan.slice(1)),
	}


## Muc nay la BUNDLE khong (co `lsGear`, khong co `nShowType`)? Ten bundle la
## ten DON VI + cap (`DefenderN_lv1`), thuoc duong `setLevelGear` chu khong
## phai 10 cho goi `setGear`.
static func la_bundle(ten: String) -> bool:
	var m := muc(ten)
	return not m.is_empty() and m.has("lsGear")


## Danh sach ten do con cua mot bundle; [] khi khong phai bundle.
static func ls_gear(ten: String) -> Array:
	var m := muc(ten)
	return (m.get("lsGear", []) as Array).duplicate()


## Danh sach ten muc `<Parts>` cua mot muc PARTS; [] khi khong phai.
## Moi ten tra tiep bang `part()`.
static func ls_parts(ten: String) -> Array:
	var m := muc(ten)
	return (m.get("lsParts", []) as Array).duplicate()


## Muc nay la LIST khong (co `sGear_lv5plus` / `sGear_lv6plus`, khong co
## `nShowType`)? Do la muc CHON THEO CAP (`equip_Exclusive_10_List` ->
## `equip_Exclusive_10_5`), va `setGear(pRole, ten)` cua ban goc KHONG truyen
## cap — nen khong cho goi nao trong 10 cho goi THAT voi toi 6 muc dang nay.
## Do la ly do no phai la mot nhanh DEM DUOC, khong phai mot lan roi vao
## "kieu 0 (?) chua lam" (kieu 0 nghia la "khong co muc nao trong bang", ma muc
## thi CO — doc sai y nghia cua chinh loi bao loi).
static func la_list(ten: String) -> bool:
	var m := muc(ten)
	if m.is_empty():
		return false
	return String(m.get("sGear_lv5plus", "")) != "" \
			or String(m.get("sGear_lv6plus", "")) != ""


## Muc trong bang `<Parts>` (14 muc) — bang RIENG, khong phai truong cua `<Gear>`.
## `nPartsType` dung LAI bo ma cua `nShowType`: 1 = doi texture xuong `sBone`,
## 5 = doi vu khi nem theo `sWeaponFight`.
static func part(ten: String) -> Dictionary:
	_doc()
	var b: Dictionary = _d.get("parts", {})
	if b.has(ten):
		return (b[ten] as Dictionary).duplicate(true)
	return {}


## Do chuyen tiep: `Witch_lv7` -> `Witch_lv6` (`sBaseItem`), hoac muc LIST chon
## theo cap (`equip_Exclusive_10_List` -> `equip_Exclusive_10_5` khi du cap 5).
## Tra "" khi muc khong co ca hai. `cap` = 0 nghia la khong biet cap.
static func chuyen_tiep(ten: String, cap: int = 0) -> String:
	var m := muc(ten)
	if m.is_empty():
		return ""
	if cap >= 6 and m.get("sGear_lv6plus", "") != "":
		return String(m["sGear_lv6plus"])
	if cap >= 5 and m.get("sGear_lv5plus", "") != "":
		return String(m["sGear_lv5plus"])
	return String(m.get("sBaseItem", ""))
