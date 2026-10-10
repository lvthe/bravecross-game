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


# ---------------------------------------------------------------------------
# 24 truong `s*` — ten armature HIEN TUONG cua don thuc tinh.
#
# Khoi `<fight>` ten `fight_<X>Wake` mang 24 truong chuoi bat dau bang `s`
# (da dem: 24, khong thieu truong nao trong bang). Chung KHONG cung mot loai,
# va du lieu tu noi len su chia do:
#
#   * 14 truong SINH HIEN — gia tri la mot armature RIENG, ve them mot doi
#     tuong nua tai cho tuong dung (vong tron, chu, khien, hieu ung trung).
#     Do: 14 truong nay mang 37 cap (truong, gia tri) = 23 TEN RIENG, va 22/23
#     tra ra duoc armature. Ca 22 deu co dong tac `PluginPlay`, tru hai ten cua
#     `sWakeEffect` (`SunLuBan_WakeEffect`, `SiMaYi_WakeEffect`) chay bo
#     `Wake`/`WakeLoop`/`WakeEnd`. Ten con lai, `Coma` (`sStatusNextWake`),
#     khong tra ra — no la TEN TRANG THAI, khong phai art.
#
#   * 10 truong TU THAN — gia tri la mot BIEN THE CUA CHINH RIG TUONG, khong
#     phai doi tuong rieng. Do: 74 cap (truong, gia tri) = 40 TEN RIENG; 35
#     chua chu `Weapon`, 4 la dang `pause_*`. Dong tac cua chung la `Walk`/
#     `Fight`/`Born`/`Standby` — dong tac cua THAN, khong ten nao co
#     `PluginPlay`. Vd `CaoCao_WeaponWake` la bien the cua rig `CaoCao` ma
#     `Layer000` mang `CaoCao_mc_Body323`: SINH no ra la ve mot CaoCao thu hai
#     moc giua san — dung cai bay ma `hieu_ung_tai_o` da phai chan bang
#     `chinh_xac`. Viec cua nhom nay `tuyet_chieu` da lam roi: `u._play_lai`.
#
# Su chia nay la DANG dat nguoi doc: ban goc ghep no trong ~80 lop C++
# `CDFSpriteFight*Wake`. No KHONG phai suy dien suong — hai dau mut deu do
# duoc — nhung no co dung MOT cho lech, ghi ra day chu khong im:
# `sWeaponWake` cua Tu Ma Y tro vao `SiMaYi_WakeEffect`, mot bien the 13 lop
# chay `Wake/WakeLoop/WakeEnd` tuc la hieu ung THAT, khong phai dong tac than.
# No nam trong nhom TU THAN nen KHONG duoc sinh; `verify_thuc_tinh.gd` khang
# dinh dung cai lech ay lai bang so, de ngay nao sua thi phep kiem bat duoc.
# Duong ra cua no la `sWakeHit` + `sWakeBuff` (hai ten VAN duoc sinh).
const TRUONG_SINH: Array[String] = [
	"sWakeEff", "sWakeEffTxt", "sWakeEffect", "sWakeEffectUp",
	"sWakeEffect_1", "sWakeEffect_2", "sWakeHit", "sWakeCircle",
	"sWakeCircleEffect", "sWakeBuff", "sWakeWakeBuff", "sPluginWake",
	"sShakeWake", "sStatusNextWake",
]

## 10 truong KHONG sinh doi tuong rieng — xem khoi chu thich tren. Giu danh
## sach nay de phep kiem khang dinh chung KHONG bi sinh ra, chu khong phai de
## bo qua: mot ngay nao do chung thanh hieu ung that thi dong kiem se bat duoc.
const TRUONG_TU_THAN: Array[String] = [
	"sWeaponWake", "sWeaponWake1", "sWeaponWake2", "sWeaponWake3",
	"sWeaponWakeFight", "sWeaponWakeFight2",
	"sPauseWake_1", "sPauseWake_2", "sPauseWake_3", "sPauseWake_4",
]


## Danh sach hieu ung can SINH cho don thuc tinh cua `ten`: [[truong, ten_hinh],
## ...] theo dung thu tu `TRUONG_SINH`. Bo qua truong rong. Khong tra art o day —
## nguoi goi tu hoi `SngRig.tim_thu_muc` va dem cai nao tra ra.
static func hieu_ung(ten: String) -> Array:
	var e := _lay(ten)
	var ds: Array = []
	if e.is_empty():
		return ds
	for t in TRUONG_SINH:
		var v := String(e.get(t, "")).strip_edges()
		if v != "":
			ds.append([t, v])
	return ds


## `ten` tra ra thu muc armature nao — hoi dung luat cua engine
## (`SngRig.tim_thu_muc`), khong tu doan theo ten. Tra "" khi khong ra. Nguoi goi
## dung no de chia so KHONG dung duoc thanh hai nguyen nhan khac han nhau.
static func tra_thu_muc(ten: String) -> String:
	return String(SngRig.tim_thu_muc(ten)[0])


## Moi truong `s*` co trong bang kem so lan xuat hien — de phep kiem doi chieu
## rang 24 truong cua `TRUONG_SINH` + `TRUONG_TU_THAN` dung bang so truong that.
static func ds_truong() -> Dictionary:
	_doc()
	var dem := {}
	for k in _d:
		var e = _d[k]
		if not (e is Dictionary):
			continue
		for kk in e:
			if String(kk).begins_with("s") and String(e[kk]).strip_edges() != "":
				dem[kk] = int(dem.get(kk, 0)) + 1
	return dem
