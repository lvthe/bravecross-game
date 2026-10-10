# Hieu ung THUC TINH — 24 truong `s*` cua khoi `fight_<X>Wake`.
#
#   godot --headless --path . --script tools/verify_thuc_tinh.gd
#
# VI SAO BO NAY PHAI CO: `tuyet_chieu` truoc day chi goi `u._play_lai(action)` —
# tuc la chi doi dong tac cua CHINH tuong. 14 truong `s*` tro toi nhung armature
# RIENG (vong tron CaiWenJi, chu ZhaoYun, khien SuperThunderDragon, hieu ung
# trung SiMaYi...) va khong duong nao cham toi chung. Va cung nhu moi duong khac
# cua an xa: mot armature khong dung duoc **khong nem mot dong loi nao**, nen
# "chay khong loi" khong noi len gi — phep kiem phai DEM.
#
# Sau tang:
#   A. Bang so lieu: dung 24 truong `s*` co gia tri, va 14 + 10 danh sach o day
#      phu kin 24 truong ay, khong giao nhau. Hai ve doc lap: `WakeRef.ds_truong`
#      dem tu json, con so o day BOC TAY tu json.
#   B. Nhom SINH HIEN: 37 cap (truong, gia tri) = 23 ten rieng; 22/23 tra ra
#      duoc armature. Ten con lai la `Coma` — TEN TRANG THAI, khong phai art.
#   C. Nhom TU THAN **khong bi sinh**: khang dinh thang, va neu dich danh cho
#      lech duy nhat (`sWeaponWake` cua Tu Ma Y tro vao `SiMaYi_WakeEffect`, mot
#      hieu ung THAT) de ngay nao sua thi dong nay bat duoc.
#   D. Dong tac: moi ten sinh duoc phai co `PluginPlay` hoac bo `Wake*`; 20/22
#      dung `PluginPlay`.
#   E. Duong tran THAT: `tuyet_chieu("ZhaoYun", 0, "Wake", 1, 2)` tren nut that,
#      dem that. Va `form` 1 (`Fight`) KHONG duoc sinh hieu ung nao.
#   F. Hai luat chan cua `hieu_ung_tai_o`: ten khong tra ra art, va armature co
#      art nhung KHONG co dong tac hieu ung — ca hai phai TU CHOI va KHONG de
#      lai mot rig dung im nao tren san. Do dai (`giay = 0`) lay tu chinh dong
#      tac.
extends SceneTree

const WR := preload("res://battle/wake_ref.gd")
const STV := preload("res://battle/san_tran_ve.gd")

## 14 truong SINH HIEN va 10 truong TU THAN — BOC TAY tu `data_ref/wake_ref.json`
## (ban vn 1.26), khong doc lai tu `WakeRef`. Day la ve thu hai cua phep do.
const SINH := ["sWakeEff", "sWakeEffTxt", "sWakeEffect", "sWakeEffectUp",
		"sWakeEffect_1", "sWakeEffect_2", "sWakeHit", "sWakeCircle",
		"sWakeCircleEffect", "sWakeBuff", "sWakeWakeBuff", "sPluginWake",
		"sShakeWake", "sStatusNextWake"]
const TU_THAN := ["sWeaponWake", "sWeaponWake1", "sWeaponWake2", "sWeaponWake3",
		"sWeaponWakeFight", "sWeaponWakeFight2",
		"sPauseWake_1", "sPauseWake_2", "sPauseWake_3", "sPauseWake_4"]

## Do 2026-09-21 tren `data_ref/wake_ref.json` (247 muc):
const SO_TRUONG := 24
const CAP_SINH := 37
const TEN_SINH := 23
const TRA_RA_SINH := 22
const TEN_TU_THAN := 40
## Tra ra thu muc KHONG co nghia la DUNG DUOC: `SngRig.build` voi
## `chinh_xac = true` con phai tim thay bien the co dong tac. Do 2026-09-21:
## 22/23 tra ra thu muc, nhung chi **18** dung duoc. Bon ten khong dung duoc
## (`SuperThunderDragonHero_Shield`, `CaiWenJiWakeBuff`, `SiMaYi_WakeBuff`,
## `ThunderDragon_ShakeWake`) nam trong so 6 ten ma `SngRig.build` da ghi la
## "khong co art rieng" — truoc 2026-09-21 phep lui ve con ve ra THAN cua tuong
## (mot bong tuong thu hai moc giua san); `chinh_xac` chan dung cho nay.
const DUNG_SINH := 18
## Trong 18 ten dung duoc: 16 chay `PluginPlay`, 1 chay bo `Wake*`
## (`SunLuBan_WakeEffect`), 1 dung duoc nhung KHONG co dong tac hieu ung
## (`SuperThunderDragon_Shield` — nhom cua no la `Born/Standby/Hit/...`, dong
## tac cua mot con rong danh nhau, khong phai mot hieu ung mot lan).
const PLUGINPLAY := 16
const KHONG_DONG_TAC := "SuperThunderDragon_Shield"
## Ten NAM TRONG nhom TU THAN nhung la hieu ung THAT — cho lech duy nhat cua
## luat chia, ghi ra chu khong im.
const LECH := "SiMaYi_WakeEffect"

var ok := 0
var bad := 0


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


## Quan ta toi thieu, dung hinh dang ban goc gui xuong. `SpriteName` phai la
## mot armature CO THAT (`ZhaoYun`) chu khong phai ten chung: phep kiem tang E
## can `u.rig` dung duoc, va mot ten khong co art thi `hieu_ung_thuc_tinh` im.
static func _ta() -> Dictionary:
	return {
		"Sprite": {
			"Troop": {"PosY": 0, "PosX": 3.83, "Soldiers": []},
			"Troop_1": {
				"Name": "ZhaoYun", "SpriteName": "ZhaoYun", "ArmyTypeID": 1001,
				"Location": 1, "NpcSize": 0.83, "MaxUnit": 2,
				"HP": 100000, "DP": 10, "MinAp": 10, "MaxAp": 20,
				"AttackInterval": 1.5, "MaxAttackDistance": 30,
				"BaseInfo": {"MaxUnit": 2},
			},
		},
		"Chapter": {"ChapterGameTime": 300},
	}


func _init() -> void:
	# Thieu bang du lieu thi bao BO QUA chu khong bao HONG: `wake_ref.json` nam
	# trong `.gitignore` (sinh tu cay goc). Xem `tools/check.py`.
	if not FileAccess.file_exists(WR.DUONG):
		print("BO QUA: khong co %s" % WR.DUONG)
		print("  sinh bang: python ../brave-cross/work/wake_ref.py")
		quit(0)
		return

	# --- A. Bang so lieu -----------------------------------------------------
	print("A. 24 truong `s*` (WakeRef.ds_truong + hai danh sach boc tay):")
	var ds: Dictionary = WR.ds_truong()
	t("json co dung %d truong `s*` co gia tri" % SO_TRUONG, ds.size() == SO_TRUONG,
			str(ds.size()))
	t("hai danh sach o day phu kin %d truong" % SO_TRUONG,
			SINH.size() + TU_THAN.size() == SO_TRUONG,
			"%d + %d" % [SINH.size(), TU_THAN.size()])
	var giao: Array = []
	for f in SINH:
		if TU_THAN.has(f):
			giao.append(f)
	t("hai danh sach KHONG giao nhau", giao.is_empty(), str(giao))
	var thieu: Array = []
	for f in ds:
		if not SINH.has(f) and not TU_THAN.has(f):
			thieu.append(f)
	t("khong truong nao nam ngoai hai danh sach", thieu.is_empty(), str(thieu))
	t("moi truong trong hai danh sach deu co gia tri trong json",
			ds.size() == SO_TRUONG and thieu.is_empty())

	# --- B. Nhom SINH HIEN ---------------------------------------------------
	print("\nB. Nhom SINH HIEN — 14 truong, %d cap, %d ten rieng:" % [CAP_SINH, TEN_SINH])
	var cap := 0
	var ten_sinh := {}
	var bang := _doc()
	for k in bang:
		var e = bang[k]
		if not (e is Dictionary):
			continue
		for f in SINH:
			var v := String(e.get(f, "")).strip_edges()
			if v == "":
				continue
			cap += 1
			ten_sinh[v] = true
	t("%d cap (truong, gia tri)" % CAP_SINH, cap == CAP_SINH, str(cap))
	t("%d ten rieng" % TEN_SINH, ten_sinh.size() == TEN_SINH, str(ten_sinh.size()))
	var ra := 0
	var khong_ra: Array = []
	for v in ten_sinh:
		if WR.tra_thu_muc(v) != "":
			ra += 1
		else:
			khong_ra.append(v)
	t("%d/%d ten tra ra duoc thu muc armature" % [TRA_RA_SINH, TEN_SINH],
			ra == TRA_RA_SINH, "%d, khong ra: %s" % [ra, str(khong_ra)])
	t("ten KHONG tra ra la `Coma` — ten TRANG THAI, khong phai art",
			khong_ra == ["Coma"], str(khong_ra))
	# Tra ra thu muc KHONG co nghia la DUNG DUOC: `SngRig.build` voi
	# `chinh_xac = true` con phai tim thay bien the co dong tac. Do rieng, vi
	# hai con so nay lech nhau va do la cho de tu khen nham.
	var dung := 0
	var khong_dung: Array = []
	for v in ten_sinh:
		if _build(v) != null:
			dung += 1
		elif WR.tra_thu_muc(v) != "":
			khong_dung.append(v)
	t("%d/%d ten DUNG DUOC rig (tra ra thu muc chua du)" % [DUNG_SINH, TEN_SINH],
			dung == DUNG_SINH, "%d, khong dung: %s" % [dung, str(khong_dung)])

	# --- C. Nhom TU THAN khong bi sinh ---------------------------------------
	print("\nC. Nhom TU THAN — 10 truong, %d ten rieng, KHONG duoc sinh:" % TEN_TU_THAN)
	var ten_tt := {}
	for k in bang:
		var e2 = bang[k]
		if not (e2 is Dictionary):
			continue
		for f in TU_THAN:
			var v := String(e2.get(f, "")).strip_edges()
			if v != "":
				ten_tt[v] = true
	t("%d ten rieng" % TEN_TU_THAN, ten_tt.size() == TEN_TU_THAN, str(ten_tt.size()))
	# Khang dinh thang tren TOAN BO bang: khong mot truong TU THAN nao lot vao
	# danh sach sinh, du gia tri cua no co tra ra art di nua.
	var lot: Array = []
	for k in bang:
		var e3 = bang[k]
		if not (e3 is Dictionary):
			continue
		var s := {}
		for c in WR.hieu_ung(String(k)):
			s[String(c[1])] = true
		for f in TU_THAN:
			var v := String(e3.get(f, "")).strip_edges()
			if v != "" and s.has(v):
				lot.append("%s/%s" % [k, v])
	t("khong gia tri nao cua TU_THAN bi sinh", lot.is_empty(), str(lot))
	t("so truong TU_THAN co gia tri la 10", ten_tt.size() == TEN_TU_THAN)
	# Cho lech duy nhat: `SiMaYi_WakeEffect` nam trong `sWeaponWake` nhung LA
	# hieu ung that (13 lop, dong tac `Wake`). No KHONG duoc sinh — khang dinh
	# dung cai lech, de ngay nao sua thi dong nay bat duoc.
	t("lech da biet: `%s` KHONG duoc sinh" % LECH,
			not _co_trong(WR.hieu_ung("SiMaYi"), LECH), str(WR.hieu_ung("SiMaYi")))
	# Va do la cho lech CO THAT chu khong phai loi ke: `SiMaYi_WakeEffect` nam
	# trong `sWeaponWake` nhung chay bo `Wake*` — dung dong tac cua mot HIEU UNG.
	var rig_lech := _build(LECH)
	t("nhung `%s` dung duoc rig va chay bo `Wake*` — tuc la hieu ung THAT" % LECH,
			rig_lech != null and STV._dong_tac_cua(rig_lech).begins_with("Wake"),
			STV._dong_tac_cua(rig_lech) if rig_lech != null else "khong dung duoc")
	if rig_lech != null:
		rig_lech.free()
	# Tu Ma Y VAN co hieu ung duoc sinh — khong phai khong co gi. (`sWakeBuff`
	# nam tren mot muc KHAC, `SiMaYi_WakeEffect`, khong phai tren `SiMaYi`.)
	t("Tu Ma Y van co hieu ung duoc sinh (`SiMaYi_WakeHit`)",
			_co_trong(WR.hieu_ung("SiMaYi"), "SiMaYi_WakeHit"),
			str(WR.hieu_ung("SiMaYi")))

	# --- D. Dong tac ---------------------------------------------------------
	print("\nD. Dong tac cua tung armature hieu ung:")
	var dem_pp := 0
	var khong_dong: Array = []
	for v in ten_sinh:
		var rig := _build(v)
		if rig == null:
			continue
		var d := STV._dong_tac_cua(rig)
		if d == "PluginPlay":
			dem_pp += 1
		elif not d.begins_with("Wake"):
			khong_dong.append("%s->%s" % [v, d])
		rig.free()
	t("%d/%d ten dung duoc chay `PluginPlay`" % [PLUGINPLAY, DUNG_SINH],
			dem_pp == PLUGINPLAY, str(dem_pp))
	# Dung MOT ten dung duoc ma khong co dong tac hieu ung — neu danh sach nay
	# doi thi luat chia da doi, va do la thu can biet.
	t("ten dung duoc ma khong co dong tac hieu ung dung la `%s`" % KHONG_DONG_TAC,
			khong_dong == ["%s->" % KHONG_DONG_TAC], str(khong_dong))

	# --- E. Duong tran that --------------------------------------------------
	print("\nE. Duong tran that (san_tran_ve.tuyet_chieu):")
	var tr := STV.new()
	var loi: String = tr.bat_dau(JSON.stringify(_ta()), "{}", 7, null)
	t("tran dung duoc tu du lieu toi thieu", loi == "", loi)
	var n_linh: int = tr.dua_linh("Troop_1")
	t("co quan ta de chieu", n_linh > 0, str(n_linh))
	var u: BattleUnit = tr._doi[0][0] if not tr._doi[0].is_empty() else null
	t("don vi ta dung duoc rig (`visual`)", u != null and u.visual)
	var r_zy := WR.hieu_ung("ZhaoYun")
	t("Trieu Van co hieu ung trong bang", r_zy.size() == 2, str(r_zy))
	t("so quan ta co mat = so don vi `Troop_1` dua ra",
			tr._doi[0].size() == n_linh, "%d / %d" % [tr._doi[0].size(), n_linh])
	# form 2 = bien than. Day moi la duong sinh hieu ung.
	var so: int = tr.tuyet_chieu("ZhaoYun", 0, "Wake", 1, 2)
	t("tuyet chieu tim ra dung so quan ta", so == n_linh, str(so))
	var dtt: String = tr.dem_thuc_tinh()
	t("hieu ung thuc tinh VE duoc (moi quan mot lan tung ten)",
			_so(dtt, "ve") == n_linh * r_zy.size(),
			"ve %d, doi %d x ten %d" % [_so(dtt, "ve"), n_linh, r_zy.size()])
	t("khong hieu ung nao bi tu choi", dtt.find("\"im_vi_sao\":{}") > 0, dtt)
	# Doi TU THE (form 1) thi KHONG co hieu ung thuc tinh nao.
	var ve_truoc := _so(dtt, "ve")
	tr.tuyet_chieu("ZhaoYun", 0, "Fight", 1, 1)
	t("doi TU THE (form 1) khong sinh hieu ung thuc tinh",
			_so(tr.dem_thuc_tinh(), "ve") == ve_truoc, tr.dem_thuc_tinh())

	# --- F. Hai luat chan cua hieu_ung_tai_o ---------------------------------
	print("\nF. Luat chan cua `hieu_ung_tai_o`:")
	var con_truoc := tr.get_child_count()
	t("ten khong co art bi tu choi", not tr.hieu_ung_tai_o("Coma", 0.0, 0.0, "", 0.0))
	# `CaoCao_WeaponWake` CO art that (bien the cua rig CaoCao) nhung dong tac
	# cua no la `Walk` — dong tac cua THAN. Sinh no ra la ve mot CaoCao thu hai
	# moc giua san, dung cai bay ma `chinh_xac` phai chan.
	t("armature co art nhung khong co dong tac hieu ung cung bi tu choi",
			not tr.hieu_ung_tai_o("CaoCao_WeaponWake", 0.0, 0.0, "", 0.0))
	# `SuperThunderDragon_Shield` dung duoc rig nhung nhom cua no khong co dong
	# tac hieu ung — phai bi tu choi y het, chu khong ve mot con rong dung im.
	t("armature dung duoc nhung khong co dong tac hieu ung cung bi tu choi",
			not tr.hieu_ung_tai_o(KHONG_DONG_TAC, 0.0, 0.0, "", 0.0))
	t("bi tu choi thi KHONG de lai rig dung im nao",
			tr.get_child_count() == con_truoc,
			"%d -> %d" % [con_truoc, tr.get_child_count()])
	# Do dai: `giay = 0` = lay tu chinh dong tac (`PluginPlay` cua ZhaoYun_Wake).
	t("hieu ung tu quyet do dai (giay = 0)",
			tr.hieu_ung_tai_o("ZhaoYun_Wake", 0.0, 0.0, "", 0.0))
	var h: Array = tr._hieu_ung[tr._hieu_ung.size() - 1]
	var rig_zy := h[0] as SngRig
	t("do dai lay tu chinh dong tac, khong phai so cung",
			rig_zy != null and is_equal_approx(float(h[1]), rig_zy.thoi_luong("PluginPlay"))
			and float(h[1]) > 0.2,
			"%.3f giay" % float(h[1]))
	tr.free()

	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


## Dung rig cho mot ten y het duong ma `hieu_ung_tai_o` di (`no_clutter` +
## `chinh_xac`), de con so o tang D va hanh vi that la cung mot phep do. Tra
## null khi khong dung duoc — nguoi goi phai `free()`.
static func _build(ten: String) -> SngRig:
	var r: Array = STV._thu_muc_hieu_ung(ten)
	if r[0] == "":
		return null
	return SngRig.build(r[0], r[1], true, true)


static func _co_trong(ds: Array, ten: String) -> bool:
	for c in ds:
		if String(c[1]) == ten:
			return true
	return false


static func _so(json_chuoi: String, khoa: String) -> int:
	var v = JSON.parse_string(json_chuoi)
	if not (v is Dictionary):
		return -1
	return int(v.get(khoa, -1))


static func _doc() -> Dictionary:
	var f := FileAccess.open(WR.DUONG, FileAccess.READ)
	if f == null:
		return {}
	var v = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}
