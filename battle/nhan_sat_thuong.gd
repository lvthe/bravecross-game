# So sat thuong NOI cua tran co hinh — sau loai nhan cua ban goc.
#
# Ban dung TRUOC day khong co duong nay: khong mot dong ma nao ve so sat thuong.
# Du lieu thi du: khoi `<label>` cua `map/global_config.xml` cho sau loai, moi
# loai mot HE SO PHONG va mot TRAN SO NHAN, con `assets/fonts` co bay bo phong
# bitmap chi gom chu so (xem `ui/nhan_ref.gd`, `brave-cross/work/fontart.py`).
#
# VI SAO PHAI CO PHEP DEM, khong phai chi "chay khong loi": mot nhan khong ve
# duoc thi KHONG nem loi nao — `load()` tra null, `Label` khong co phong thi van
# ton tai, van `queue_free()` binh thuong. Nen `dem()` la kenh do that, dung loi
# `dem_tieng()` cua `san_tran_ve.gd`: dem so ve duoc, so bi bo, va VI SAO.
#
# DAT (khong phai ban goc — ghi ro tung cho):
#   * y nghia cua `fRiseLabel_*`. Ten khoa noi "Rise", nen o day no nhan vao
#     QUANG DUONG BAY LEN (va ti le thoi gian bay). No cung co the la he so CO
#     CHU — sau gia tri deu <= 1,0 (0,7..1,0) nen hai cach doc deu vua. Chua
#     phan biet duoc: muon biet thi phai moc ban goc luc chay (`work/emu_*.py`).
#     Doi cho nay thi doi mot cho, khong phai sua bang du lieu.
#   * Khi TRAN NHAN (数量限制) bi cham thi BO NHAN CU NHAT cua cung loai, giu cai
#     moi. Cach doc khac la khong ve cai moi. Chon the nay vi cai moi la thong
#     tin nguoi choi dang can; so bi bo VAN duoc dem (`bo`).
#   * Quang bay 64 px, thoi gian 0,9 giay, do lech ngang 14 px: DEP, khong co
#     so do nao trong du lieu.
#   * Thu tu ve: nhan nam o `z_index` cao hon quan, nhung thap hon lop phu
#     (`phu_mau` dung 900).
class_name NhanSatThuong
extends Node2D

## Loai nhan — dung ten khoa cua ban goc. Thu tu o `NhanRef.LOAI`.
const FOE := "Foe"
const TROOP := "Troop"
const CRITICAL := "Critical"
const INCREASE := "Increase"
const BONUS := "Bonus"
const SHIELD := "Shield"

## Cao than nguoi — khop `BODY` cua `battle.gd` / `san_tran_ve.gd`. Nhan noi
## len tu duong dat, nen phai nhac qua dau.
const CAO_DAU := 56.0
## Quang bay len (px) va thoi gian bay (giay), nhan voi `fRiseLabel_*`.
const BAY_PX := 64.0
const BAY_GIAY := 0.9
## Do lech ngang moi dau (px), de nhieu nhan cung luc khong chong khit len nhau.
const LECH_X := 14.0
const Z := 800

## Ten phong -> Font da nap. Nap mot lan cho ca phien: `load()` cua Godot da co
## cache, nhung giu day de biet phong nao da hoi va phong nao thieu.
static var _phong: Dictionary = {}


## Loai nhan cho mot don danh vao `u_chiu` — HAM THUAN, khong dung node nao, nen
## phep kiem goi thang duoc.
##
## Thu tu luat: TRUNG DON thang truoc (no la su kien dang chu y nhat, va ban goc
## co phong rieng ten dung `CriticalFont`); con lai chia theo BEN CUA NGUOI CHIU.
##
## DAT, va la cho DAT nang nhat cua tep nay: `Foe` / `Troop` chia theo ben la mot
## SUY DOAN. Cach doc khac la chia theo LOAI DON VI (tuong / linh) chu khong theo
## ben — hai ten khoa deu khong noi gi, va khong co du lieu nao phan biet. Ta
## chon theo BEN vi do la thu duy nhat mo hinh tran cua ta phan biet duoc
## (`BattleUnit.team`), va vi nguoi choi can phan biet "don vao ta" voi "don vao
## dich" hon la "don vao tuong" voi "don vao linh".
##
## `Bonus` va `Shield` KHONG BAO GIO ra o day, va do khong phai thieu sot:
##   * `Shield` — `combat.gd` khong co chi so chan nao (`strike()` tra
##     `{damage, skill, crit}`, khong co `absorb`), nen khong co so nao de hien.
##   * `Bonus` — khong co loai sat thuong cong them nao tach khoi don thuong;
##     phan `bu` cua tuyet chieu da nam trong `damage`. Muon co thi phai co mot
##     luat sinh ra no truoc.
## Ca hai van co phong rieng trong `PHONG_DAT` de ngay nao co luat thi chi viec
## goi `hien()` — khong phai sua bang.
static func loai_theo_duoi(team_chiu: int, crit: bool) -> String:
	if crit:
		return CRITICAL
	return FOE if team_chiu == 1 else TROOP

## [node, loai, x, y, tu_x, tu_y, den_y, con, tong]
var _nhan: Array = []
## Bo sinh so cua TRAN (`Combat.Rng` — LCG cua chinh ban dung, KHONG phai
## `RandomNumberGenerator` cua Godot). Kieu de trong la co y: `Combat.Rng` chi co
## `roll()` / `roll_range()`, khong phai lop cua engine.
var _rng = null

var _ve := 0
var _bo := 0
var _theo_loai: Dictionary = {}
var _im: Dictionary = {}


## RNG de lech ngang (`Combat.Rng` cua tran). Khong dat thi khong lech — phep
## kiem can so xac dinh, va mot bo sinh so toan cuc thi moi lan chay mot khac.
func dat_rng(r) -> void:
	_rng = r


## Ve mot nhan so tai toa do CUC BO cua nut nay (px, cung he voi `BattleUnit.sx/sy`).
##
## `so` la so sat thuong THUC da tru (goi y: hieu `hp` truoc/sau). Tra `true` neu
## co nhan duoc ve.
func hien(loai: String, so: float, x: float, y: float) -> bool:
	var n := int(round(so))
	if n <= 0:
		# 0 sat thuong thi khong co gi de noi. Dem rieng, khong lan vao "thieu phong".
		_im["so-0"] = int(_im.get("so-0", 0)) + 1
		return false
	var ten := NhanRef.phong_cua(loai)
	var duong := NhanRef.duong_fnt(ten)
	if duong == "":
		# Hai duong im khac nhau, phai tach: loai khong co trong bang ghep, hay
		# bang ghep co nhung ban goc khong ship phong ay.
		var k := "loai-la" if ten == "" else "thieu-phong:" + ten
		_im[k] = int(_im.get(k, 0)) + 1
		return false
	var f := _nap(duong)
	if f == null:
		# `NhanRef` bao co ma `load()` khong ra: `.fnt` chua duoc xuat, hoac
		# trang PNG cua no khong nam canh. Ca hai deu la loi XUAT, khong phai loi
		# du lieu goc — nen phai hien ra chu khong duoc nuot.
		_im["khong-nap-duoc:" + ten] = int(_im.get("khong-nap-duoc:" + ten, 0)) + 1
		return false

	# TRAN cua ban goc: dem so nhan CUNG LOAI dang song. Cham tran thi bo cai cu
	# nhat cua chinh loai do (xem dau tep).
	var tran := NhanRef.tran(loai)
	if tran > 0:
		var cung := 0
		for i in range(_nhan.size() - 1, -1, -1):
			if String(_nhan[i][1]) == loai:
				cung += 1
				if cung >= tran:
					var cu: Array = _nhan[i]
					_nhan.remove_at(i)
					if is_instance_valid(cu[0]):
						(cu[0] as Node).queue_free()
					_bo += 1
					break

	var he := NhanRef.he_so(loai)
	var giay := BAY_GIAY * maxf(0.05, he)
	var den := y - CAO_DAU - BAY_PX * maxf(0.05, he)

	var lb := Label.new()
	lb.text = _chu(loai, n, ten)
	var ls := LabelSettings.new()
	ls.font = f
	lb.label_settings = ls
	lb.z_index = Z
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lx := x
	if _rng != null:
		lx += _rng.roll_range(-LECH_X, LECH_X)
	lb.position = Vector2(lx, y - CAO_DAU)
	add_child(lb)
	_nhan.append([lb, loai, lx, y - CAO_DAU, den, giay, giay])
	_ve += 1
	_theo_loai[loai] = int(_theo_loai.get(loai, 0)) + 1
	return true


## Chu cua nhan. Chi chu so, tru khi phong CO glyph `+` va day la luong CONG VAO
## (`Increase` = hoi mau) — do bo glyph chu khong doan: `ImpactGreen`/`Blue`/
## `Yellow` co `'+'`, `ImpactRed`/`White`/`ShieldWhite` khong, `CriticalFont` co
## `'!'` nhung khong co `'+'`. Dua `+` vao mot phong khong co glyph ay thi Godot
## ve O TRONG — im lang.
func _chu(loai: String, n: int, ten: String) -> String:
	if loai == INCREASE and String(NhanRef.phong(ten).get("ma", "")).contains("+"):
		return "+%d" % n
	return str(n)


static func _nap(duong: String) -> Font:
	if _phong.has(duong):
		return _phong[duong]
	var f = load(duong)
	_phong[duong] = f
	return f


## Bay len roi mo dan. Buoc bang nhip cua Lua (`san_tran_ve.buoc`), KHONG bang
## `_process`: cong cu do chay khong cua so va san khau khong nam trong cay
## canh, nen `_process` khong chay — cung ly do da ghi o dau `san_tran_ve.gd`.
func buoc(dt: float) -> void:
	for i in range(_nhan.size() - 1, -1, -1):
		var a: Array = _nhan[i]
		a[5] = float(a[5]) - dt
		var n = a[0]
		if not is_instance_valid(n):
			_nhan.remove_at(i)
			continue
		var k := 1.0 - maxf(0.0, float(a[5])) / maxf(0.001, float(a[6]))
		n.position = Vector2(float(a[2]), lerpf(float(a[3]), float(a[4]), k))
		# Mo dan trong NUA SAU duong bay: hien ngay tu dau thi chu nhoe khi
		# nhieu nhan chong nhau, ma mat som thi khong kip doc.
		n.modulate.a = 1.0 - maxf(0.0, (k - 0.5) * 2.0)
		if float(a[5]) > 0.0:
			continue
		_nhan.remove_at(i)
		(n as Node).queue_free()


## So nhan dang bay — de phep kiem doi chieu voi TRAN cua ban goc.
func dang_bay() -> int:
	return _nhan.size()


## So nhan dang bay CUA MOT LOAI, de kiem tran theo tung loai (tran cua sau loai
## khac nhau: Foe 30, Critical 40, Troop 50, Increase 100, Bonus 30, Shield 50).
func dang_bay_loai(loai: String) -> int:
	var n := 0
	for a in _nhan:
		if String(a[1]) == loai:
			n += 1
	return n


## Kenh do — dung loi `dem_tieng()`. `ve` + `bo` la so lan `hien()` duoc goi va
## tra ve; `im_vi_sao` chia so lan KHONG ve duoc theo nguyen nhan.
func dem() -> String:
	return JSON.stringify({"ve": _ve, "bo": _bo, "theo_loai": _theo_loai, "im_vi_sao": _im})


## Xoa het nhan ngay (tran xong). Khong dem vao `bo`: day khong phai cham tran.
func xoa_het() -> void:
	for a in _nhan:
		if is_instance_valid(a[0]):
			(a[0] as Node).queue_free()
	_nhan.clear()
