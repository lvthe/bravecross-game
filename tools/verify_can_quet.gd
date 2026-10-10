# CAN QUET (扫荡) — hai nut "Quet 1 lan" / "Quet 10 lan" o man thong tin ai.
#
#   godot --headless --path . --script tools/verify_can_quet.gd
#
# Vi sao phai co bo kiem nay: truoc no, lop offline KHONG CO handler nao cho
# `ClientChapterSweepOnce` / `ClientChapterSweepTen`. Do duoc: `offline.log` co
# 20.893 dong THIEU ma KHONG mot dong nao mang chu "Sweep" — tuc la cu cham vao
# nut chua bao gio di toi server gia lap. Cac bo kiem khac khong phu duoc cho
# nay: `do_chien_dich.gd` di duong chien dich khac (khong quet), `verify_chon_ai`
# chi lo man chon ai, `bam_that.gd` chi hoi "co qua duoc buoc khong".
#
# ---------------------------------------------------------------------------
# LUAT DO TU MA GOC, khong suy:
#
#   PHAN THUONG — `chapterSweepHandle` (share_ChapterLogic.lua:2878) la ham
#   server CO duoc ship. No di qua CUNG hai ham nhu duong thang
#   (`SetDataWithDropList` + `saveVictoryReport`), nen `PassMissionCount`
#   (:3148-3152) va chien bao tu khop. Do duoc o day: sau mot lan quet,
#   `daThang` tang dung 1.
#
#   THE LUC — mot lan can quet = MOT tran tron ven. Bon cho cua ban goc khop:
#   `saveChapterBeginStatus` tru `ChapterUserFatigue/6` (:913),
#   `chapterVictoryHandle` tru `ChapterUserFatigue/6*5` (:2714) — cong du
#   `ChapterUserFatigue` — va chinh client ghi gia cua can quet trong chuoi xac
#   nhan DA BI TAT: `ChapterUserFatigue * 1` (:2703) va
#   `ChapterUserFatigue * nMaxSweepCount` (:2839). Bo kiem nay do CUNG mot con
#   so do o ca hai duong (quet 1 va quet 10), chu khong doc lai ma goc.
#
#   SO LAN — `CheckCanSweepCount` (:1662) = min(`getChapterLeftSweepCount`
#   :1712, `getChapterLeftBattleCount` :1759). Tren `L_N_01_01` do duoc
#   `SweepPerDay = 99999999` va `PlayPerDay = 1`, nen ve SAU moi la tran that.
#   `getChapterLeftBattleCount` TU CHOI khi so con lai AM (:1803) — do la cong
#   ma bo kiem nay dung o nhom F.
#   `SweepCount` (trong `GameUserGlobalData`) la so luot MUA BANG KIM CUONG,
#   khong phai so luot da dung: `changeDiamondToSweepCount` (:1206) tieu kim
#   cuong roi goi `ReduceSweepCount`, va `um_event.lua:487/512` dat ten su kien
#   ay la "购买扫荡次数消耗" / "buy_sweep_count". Nguoi choi moi co `SweepCount
#   = 0`, va `ReduceSweepCount` (:1320) TU CHOI o `:1342`
#   (`ProcessError(nCount >= 0)`) — nen lop offline PHAI hoi so du truoc khi
#   goi, khong thi moi luot quet dau tien do mot vet `ProcessError!` gia vao
#   bang dieu khien (nhom G do dung dieu do).
#
#   HINH PHAN HOI — `OnServerChapterSweepOnce` (ClientChapterLogic.lua:509-514)
#   doi `ChapterKey` kieu STRING va `DropList` kieu TABLE, con
#   `OnServerChapterSweepTen` (:583-598) doc mot LIST va `#tRetData >= 5` moi
#   chen danh sach bao hiem `SweepGuaranteeDropList`. Nen MOT lan tu choi cung
#   phai tra du hinh rong: tra `{ErrorCode=1}` lam client ban ra
#   `Arg must be string!` (do duoc). Nhom E va F gac dung dieu nay.
#
#   TRAN 10 — client chan o `CUIChapterInfo.lua:2793-2795` (`if nMaxSweepCount >
#   10 then nMaxSweepCount = 10 end`) NHUNG do chi de hien thi va gac; no goi
#   `ChapterSweepTen(key)` TRAN. Nen tran phai nam trong lop nay, va nhom D do
#   no bang cach nang `PlayPerDay` len 25 (co tra lai nguyen trang).
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0
const CHO := 60
const AI := "L_N_01_01"
const AI_LA := "KHONG_CO_AI_NAY"

var _dat := 0
var _hong := 0
var _da_in := 0
var _lua: LuaRuntime
var _san: Control


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


func _init() -> void:
	_lua = LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	_lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not _lua.open():
		print("KHONG chay duoc: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true
	_san = Control.new()
	_san.size = _lua.cua_so_engine
	_san.scale = Vector2.ONE * (vp.y / _lua.cua_so_engine.y)
	_lua.set_stage(_san)
	_lua.set_touch_root(_san)
	get_root().add_child(_san)
	if _lua.run(VM._NAP, "nap") == null:
		print("nap hong: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	var d := VM.chay(_lua)
	if str(d["dung"]) != "":
		print("KHONG toi duoc Main, dung o: %s" % d["dung"])
		quit(1)
		return

	_may_do()

	print("\n=== A. Hang so cua ai — con so goc, khong bia ===")
	var hs := _bien("g_qcHangSo()")
	print("   %s" % hs)
	_ghi_chu(hs.contains("ChapterUserFatigue=6"), "ChapterUserFatigue = 6")
	_ghi_chu(hs.contains("PlayPerDay=1"), "PlayPerDay = 1")
	_ghi_chu(hs.contains("SweepPerDay=99999999"), "SweepPerDay = 99999999")
	_ghi_chu(hs.contains("SweepCount=0"), "SweepCount = 0 (chua mua luot nao)")
	_ghi_chu(hs.contains("CheckCanSweepCount -> true, 1"),
			"CheckCanSweepCount = min(99999999, 1) = 1")

	print("\n=== B. Quet 10 — duong nut 'Quet 10 lan', luot thach dau con nguyen ===")
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	var tt_truoc := _bien("g_qcTrangThai()")
	print("   truoc: %s" % tt_truoc)
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	_lua.run("G_ChapterLogic:ChapterSweepTen('%s') return true" % AI, "quet 10")
	_nha(CHO)
	var tt_sau := _bien("g_qcTrangThai()")
	print("   sau:   %s" % tt_sau)
	var moc := _moc()
	for dong in moc:
		print("     %s" % dong)
	var e10: Dictionary = _doc_moc(moc, "Ten")
	_ghi_chu(not e10.is_empty(), "co phan hoi OnServerChapterSweepTen")
	if not e10.is_empty():
		_ghi_chu(int(e10.get("soMuc", "")) == 1,
				"danh sach tra ve co DUNG so lan quet duoc (1), khong gop: soMuc=%s" % e10.get("soMuc", ""))
		_ghi_chu(String(e10.get("muc1CkKieu", "")) == "string",
				"muc 1: ChapterKey kieu string (%s)" % e10.get("muc1CkKieu", ""))
		_ghi_chu(String(e10.get("muc1DlKieu", "")) == "table",
				"muc 1: DropList kieu table (%s)" % e10.get("muc1DlKieu", ""))
		_ghi_chu(int(e10.get("muc1SoDonVi", "")) > 0,
				"muc 1: DropList co vat pham that (soDonVi=%s)" % e10.get("muc1SoDonVi", ""))
	_ghi_chu(_the_luc(tt_truoc) - _the_luc(tt_sau) == 6,
			"the luc tru dung 6 = 1 x ChapterUserFatigue (%s -> %s)"
			% [_the_luc(tt_truoc), _the_luc(tt_sau)])
	_ghi_chu(_da_thang(tt_sau) - _da_thang(tt_truoc) == 1,
			"so lan thach dau (PassMissionCount) tang dung 1: %s -> %s"
			% [_da_thang(tt_truoc), _da_thang(tt_sau)])

	print("\n=== C. Quet 1 — duong nut 'Quet 1 lan' ===")
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	tt_truoc = _bien("g_qcTrangThai()")
	print("   truoc: %s" % tt_truoc)
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet 1")
	_nha(CHO)
	tt_sau = _bien("g_qcTrangThai()")
	print("   sau:   %s" % tt_sau)
	moc = _moc()
	for dong in moc:
		print("     %s" % dong)
	var e1: Dictionary = _doc_moc(moc, "Once")
	_ghi_chu(not e1.is_empty(), "co phan hoi OnServerChapterSweepOnce")
	if not e1.is_empty():
		_ghi_chu(String(e1.get("ckKieu", "")) == "string",
				"ChapterKey kieu string (%s)" % e1.get("ckKieu", ""))
		_ghi_chu(String(e1.get("dlKieu", "")) == "table",
				"DropList kieu table (%s)" % e1.get("dlKieu", ""))
		_ghi_chu(int(e1.get("soDonVi", "")) > 0,
				"DropList co vat pham that (soDonVi=%s)" % e1.get("soDonVi", ""))
	_ghi_chu(_the_luc(tt_truoc) - _the_luc(tt_sau) == 6,
			"the luc tru dung 6 = 1 x ChapterUserFatigue (%s -> %s)"
			% [_the_luc(tt_truoc), _the_luc(tt_sau)])

	print("\n=== D. TRAN 10 — nang PlayPerDay len 25 roi quet 10 ===")
	# Client chan o `:2793-2795` nhung chi de HIEN THI; no goi `ChapterSweepTen`
	# TRAN. Nen phai do xem lop nay co tu gac khong. Nang `PlayPerDay` la cach
	# duy nhat lam `CheckCanSweepCount` vuot 10 tren ban luu nay — va tra lai
	# nguyen trang ngay sau do, co kiem chung la da tra lai.
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	var nang := _bien("g_qcNangPlayPerDay(25)")
	print("   %s" % nang)
	_ghi_chu(nang.contains("CheckCanSweepCount -> true, 25"),
			"nang xong thi tran that la 25, tuc tran 10 phai do lop nay gac")
	var tt_truocD := _bien("g_qcTrangThai()")
	print("   truoc: %s" % tt_truocD)
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	_lua.run("G_ChapterLogic:ChapterSweepTen('%s') return true" % AI, "quet 10 khi tran la 25")
	_nha(CHO)
	tt_sau = _bien("g_qcTrangThai()")
	print("   sau:   %s" % tt_sau)
	moc = _moc()
	for dong in moc:
		print("     %s" % dong)
	var eD: Dictionary = _doc_moc(moc, "Ten")
	if not eD.is_empty():
		_ghi_chu(int(eD.get("soMuc", "")) == 10,
				"quet DUNG 10 lan du tran that la 25: soMuc=%s" % eD.get("soMuc", ""))
	else:
		_ghi_chu(false, "khong co phan hoi OnServerChapterSweepTen khi tran la 25")
	_ghi_chu(_the_luc(tt_truocD) - _the_luc(tt_sau) == 60,
			"the luc tru dung 60 = 10 x ChapterUserFatigue (%s -> %s)"
			% [_the_luc(tt_truocD), _the_luc(tt_sau)])
	var tra := _bien("g_qcTraPlayPerDay()")
	print("   %s" % tra)
	_ghi_chu(tra.contains("PlayPerDay=1"), "da tra PlayPerDay ve 1 nguyen trang")
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")

	print("\n=== E. Cong THE LUC — khong du the luc thi khong duoc quet ===")
	_lua.run("g_qcDatTheLuc(5) return true", "dat the luc = 5 (< 6)")
	_nha(CHO)
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet khi thieu the luc")
	_nha(CHO)
	var ttE := _bien("g_qcTrangThai()")
	print("   sau:   %s" % ttE)
	moc = _moc()
	for dong in moc:
		print("     %s" % dong)
	_ghi_chu(_the_luc(ttE) == 5, "the luc KHONG bi tru khi khong du (%s)" % _the_luc(ttE))
	var eE: Dictionary = _doc_moc(moc, "Once")
	if not eE.is_empty():
		_ghi_chu(String(eE.get("ckKieu", "")) == "string" and String(eE.get("dlKieu", "")) == "table",
				"van tra DU HINH rong: ChapterKey string (%s) + DropList table (%s)"
				% [eE.get("ckKieu", ""), eE.get("dlKieu", "")])
		_ghi_chu(int(eE.get("soDonVi", "")) == 0, "khong trao vat pham nao (soDonVi=%s)" % eE.get("soDonVi", ""))
	else:
		_ghi_chu(false, "tu choi ma KHONG tra loi — client se dung cho mai")

	print("\n=== F. Cong SO LUOT — het luot thach dau thi khong duoc quet ===")
	# `getChapterLeftBattleCount` (:1798) lay `PlayPerDay - PassMissionCount` va
	# chi TU CHOI khi hieu AM (:1803 = `ProcessError(nLeftBattleCount >= 0)`).
	# Nen hieu BANG 0 van tra `true` kem tran 0 — do dung the, khong doan. Cong
	# nam o cho lop nay phai TU CHOI khi tran la 0, khong phai o cho luat goc bao
	# loi. Ca AM that su thi do o khoi F2 ngay duoi.
	_lua.run("g_qcDatTheLuc(500) return true", "hoi day the luc")
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	var nangF := _bien("g_qcNangPlayPerDay(0)")
	print("   %s" % nangF)
	_ghi_chu(nangF.contains("CheckCanSweepCount -> true, 0"),
			"hieu = 0 thi CheckCanSweepCount -> true, 0 (tran 0, khong phai loi)")
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	var ttF_truoc := _bien("g_qcTrangThai()")
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet khi het luot")
	_lua.run("G_ChapterLogic:ChapterSweepTen('%s') return true" % AI, "quet 10 khi het luot")
	_nha(CHO)
	var ttF_sau := _bien("g_qcTrangThai()")
	print("   truoc: %s" % ttF_truoc)
	print("   sau:   %s" % ttF_sau)
	moc = _moc()
	for dong in moc:
		print("     %s" % dong)
	_ghi_chu(_the_luc(ttF_sau) == _the_luc(ttF_truoc),
			"the luc khong doi khi het luot (%s)" % _the_luc(ttF_sau))
	_ghi_chu(_da_thang(ttF_sau) == _da_thang(ttF_truoc),
			"PassMissionCount khong tang khi het luot (%s -> %s)"
			% [_da_thang(ttF_truoc), _da_thang(ttF_sau)])
	var eF1: Dictionary = _doc_moc(moc, "Once")
	var eF10: Dictionary = _doc_moc(moc, "Ten")
	_ghi_chu(not eF1.is_empty() and int(eF1.get("soDonVi", -1)) == 0,
			"quet 1 bi tu choi va khong trao gi")
	_ghi_chu(not eF10.is_empty() and int(eF10.get("soMuc", -1)) == 0,
			"quet 10 bi tu choi va tra danh sach rong")
	var traF := _bien("g_qcTraPlayPerDay()")
	print("   %s" % traF)
	_ghi_chu(traF.contains("PlayPerDay=1"), "da tra PlayPerDay ve 1 nguyen trang")

	print("\n=== F2. Cong SO LUOT, hieu AM — duong TU CHOI that cua ban goc (:1803) ===")
	# Hieu am moi la duong loi that su cua `getChapterLeftBattleCount`. Dung no
	# bang cach quet MOT lan cho `PassMissionCount` len 1 roi ha `PlayPerDay`
	# xuong 0 — dung tinh huong "da dung het luot thach dau trong ngay".
	_lua.run("g_qcDatTheLuc(500) return true", "hoi day the luc")
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet 1 cho co chien bao")
	_nha(CHO)
	var amF := _bien("g_qcNangPlayPerDay(0)")
	print("   %s" % amF)
	# Hai vet `ProcessError!` in ngay TREN dong nay la cua CHINH ban goc
	# (`share_ChapterLogic.lua:1803` va `:1684`), do bo do CO Y goi mot phep hoi
	# roi vao nhanh loi ay — khong phai loi do lop offline sinh ra. Khoi I dem
	# rieng hai loai vet cua lop minh.
	print("   (hai vet ProcessError! ngay tren la cua ban goc :1803/:1684, co y goi)")
	_ghi_chu(amF.contains("CheckCanSweepCount -> false, 0"),
			"hieu AM (PassMissionCount > PlayPerDay) thi CheckCanSweepCount TU CHOI")
	var ttF2_truoc := _bien("g_qcTrangThai()")
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet 1 khi hieu am")
	_lua.run("G_ChapterLogic:ChapterSweepTen('%s') return true" % AI, "quet 10 khi hieu am")
	_nha(CHO)
	var ttF2_sau := _bien("g_qcTrangThai()")
	print("   truoc: %s" % ttF2_truoc)
	print("   sau:   %s" % ttF2_sau)
	moc = _moc()
	for dong in moc:
		print("     %s" % dong)
	_ghi_chu(_the_luc(ttF2_sau) == _the_luc(ttF2_truoc),
			"the luc khong doi khi hieu am (%s)" % _the_luc(ttF2_sau))
	_ghi_chu(_da_thang(ttF2_sau) == _da_thang(ttF2_truoc),
			"PassMissionCount khong tang khi hieu am (%s -> %s)"
			% [_da_thang(ttF2_truoc), _da_thang(ttF2_sau)])
	var eF3: Dictionary = _doc_moc(moc, "Once")
	var eF4: Dictionary = _doc_moc(moc, "Ten")
	_ghi_chu(not eF3.is_empty() and int(eF3.get("soDonVi", -1)) == 0,
			"quet 1 khi hieu am bi tu choi va khong trao gi")
	_ghi_chu(not eF4.is_empty() and int(eF4.get("soMuc", -1)) == 0,
			"quet 10 khi hieu am bi tu choi va tra danh sach rong")
	print("   " + _bien("g_qcTraPlayPerDay()"))
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")

	print("\n=== G. So du luot MUA — khong duoc sinh vet ProcessError! gia ===")
	# `ReduceSweepCount` (:1342) tu choi khi `SweepCount` = 0, va `ProcessError`
	# cua chinh ban goc IN RA mot vet loi kem ngan xep moi lan no tra false.
	# Lop nay phai HOI SO DU TRUOC. Do bang cach dem vet loi: truoc day moi luot
	# quet dau tien do mot vet, va ngan xep co chu 'ReduceSweepCount'.
	_lua.run("g_qcDatTheLuc(500) return true", "hoi day the luc")
	_nha(CHO)
	var so_vet_truoc := _dem_vet_reduce()
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet 1")
	_nha(CHO)
	var so_vet_sau := _dem_vet_reduce()
	print("   vet 'ReduceSweepCount' truoc=%d sau=%d" % [so_vet_truoc, so_vet_sau])
	_ghi_chu(so_vet_sau == so_vet_truoc,
			"quet khong sinh them vet ProcessError! nao tu ReduceSweepCount")
	var ttG := _bien("g_qcTrangThai()")
	_ghi_chu(ttG.contains("daQuet=0"),
			"va so du luot mua van nguyen ven: %s" % ttG)

	print("\n=== H. Ai khong co cau hinh — van phai tra du hinh ===")
	_lua.run("g_qcMoc = {} return true", "xoa moc")
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI_LA, "quet ai la")
	_nha(CHO)
	moc = _moc()
	for dong in moc:
		print("     %s" % dong)
	var eH: Dictionary = _doc_moc(moc, "Once")
	if not eH.is_empty():
		_ghi_chu(String(eH.get("ckKieu", "")) == "string" and String(eH.get("dlKieu", "")) == "table",
				"tra du hinh rong: ChapterKey string (%s) + DropList table (%s)"
				% [eH.get("ckKieu", ""), eH.get("dlKieu", "")])
	else:
		_ghi_chu(false, "ai la ma khong tra loi")

	print("\n=== I. Khong co dong loi nao do lop cua minh sinh ra ===")
	var n_arg := _dem_loi_lua("Arg must be string")
	var n_reduce := _dem_loi_lua("ReduceSweepCount")
	print("   loi Lua 'Arg must be string': %d   'ReduceSweepCount': %d" % [n_arg, n_reduce])
	_ghi_chu(n_arg == 0, "khong con dong 'Arg must be string' nao")
	_ghi_chu(n_reduce == 0, "khong con vet 'ReduceSweepCount' nao")

	print("\n=== J. Nhat ky offline.log — handler co that su chay qua duong CallServer ===")
	# Bang chung DOC LAP voi cac nhom tren: chung goi thang `ChapterSweepTen`.
	# Nhat ky chi co dong khi di qua `CallServer` -> `dispatch` -> handler, nen
	# day moi la phep kiem chung minh handler DA DUOC DANG KY.
	var n_quet := 0
	var n_tu_choi := 0
	var n_dau := ""
	for ten in ["ClientChapterSweepOnce", "ClientChapterSweepTen"]:
		n_quet += _dem_nhat_ky(ten)
	for dong in _doc_nhat_ky():
		if dong.contains("khong quet") or dong.contains("khong co gi de tru"):
			n_tu_choi += 1
			if n_dau == "":
				n_dau = dong
	print("   dong nhat ky mang ten handler: %d   dong tu choi: %d" % [n_quet, n_tu_choi])
	if n_dau != "":
		print("     vi du: %s" % n_dau)
	_ghi_chu(n_quet > 0,
			"handler DA DUOC DANG KY: nhat ky co dong cua no (khong con roi vao THIEU)")
	_ghi_chu(n_tu_choi > 0, "va duong tu choi cung duoc ghi lai, khong im lang")

	print("\ndat %d, hong %d" % [_dat, _hong])
	_san.free()
	quit(1 if _hong > 0 else 0)


# ---------------------------------------------------------------------------
# May do phia Lua. Tra ve CHUOI chu khong tra bang: bang Lua qua cau GDScript la
# `LuaTable`, khong phai Array/Dictionary, nen moi phep in tren bang deu ra
# `[LuaTable:0x...]` va khong phep kiem nao doc duoc.
#
# Dung `@AI@` roi `.replace` chu KHONG phai `% [...]`: trong khoi Lua co
# `string.format` cua chinh Lua (`%s` cua no), ma toan tu `%` cua GDScript ap len
# CA chuoi nen hai loai de danh nhau.
# ---------------------------------------------------------------------------
const _MAY_DO := """
		g_qcMoc = {}

		-- Ghi lai phan hoi server. Giu KIEU cua tung truong chu khong chi gia
		-- tri: `OnServerChapterSweepOnce` gac bang `ProcessNotString` /
		-- `ProcessNotTable`, nen kieu moi la thu dang kiem.
		local function ghi(nhan, t)
			local o = { nhan = nhan, kieu = type(t) }
			if type(t) == 'table' then
				o.soMuc = #t
				o.ck = tostring(t.ChapterKey)
				o.ck_kieu = type(t.ChapterKey)
				o.dl_kieu = type(t.DropList)
				local nDonVi = 0
				if type(t.DropList) == 'table' then
					for _ in pairs(t.DropList.Drop or {}) do nDonVi = nDonVi + 1 end
				end
				o.soDonVi = nDonVi
				if type(t[1]) == 'table' then
					local m = t[1]
					o.muc1CkKieu = type(m.ChapterKey)
					o.muc1DlKieu = type(m.DropList)
					local n1 = 0
					if type(m.DropList) == 'table' then
						for _ in pairs(m.DropList.Drop or {}) do n1 = n1 + 1 end
					end
					o.muc1SoDonVi = n1
				end
			end
			g_qcMoc[#g_qcMoc + 1] = o
		end

		local g1 = G_ChapterLogic.OnServerChapterSweepOnce
		G_ChapterLogic.OnServerChapterSweepOnce = function(self, t)
			ghi('Once', t)
			if g1 then return g1(self, t) end
		end
		local g10 = G_ChapterLogic.OnServerChapterSweepTen
		G_ChapterLogic.OnServerChapterSweepTen = function(self, t)
			ghi('Ten', t)
			if g10 then return g10(self, t) end
		end

		-- Cac truong cua moc, noi bang '\\n' de GDScript cat ra tung dong.
		function g_qcDocMoc()
			local o = {}
			for i = 1, #g_qcMoc do
				local m = g_qcMoc[i]
				if m.kieu ~= 'table' then
					o[i] = m.nhan .. ': KHONG phai bang (kieu=' .. m.kieu .. ')'
				else
					-- Moi truong la `khoa=gia tri`, ngan cach bang DAU CACH, va
					-- khong gia tri nao chua dau cach — de GDScript cat ra tung
					-- truong ma khong phai doan. Kieu cua tung truong moi la thu
					-- dang kiem (`ProcessNotString` / `ProcessNotTable`), nen no
					-- phai di ra nhu mot truong rieng.
					o[i] = string.format(
						'%s: soMuc=%s ckKieu=%s dlKieu=%s soDonVi=%s'
						.. ' muc1CkKieu=%s muc1DlKieu=%s muc1SoDonVi=%s',
						m.nhan, tostring(m.soMuc), tostring(m.ck_kieu),
						tostring(m.dl_kieu), tostring(m.soDonVi),
						tostring(m.muc1CkKieu), tostring(m.muc1DlKieu),
						tostring(m.muc1SoDonVi))
				end
			end
			return table.concat(o, '\\n')
		end

		-- Hang so cua ai: doc THANG tu config, de moi con so trong bo kiem co cho doi chieu.
		function g_qcHangSo()
			local o = {}
			local cfg = G_ConfigManager:GetChapterConfig('@AI@')
			o[#o + 1] = 'ChapterUserFatigue=' .. tostring(cfg and cfg.ChapterUserFatigue)
			o[#o + 1] = 'PlayPerDay=' .. tostring(cfg and cfg.PlayPerDay)
			o[#o + 1] = 'ChapterUserEx=' .. tostring(cfg and cfg.ChapterUserEx)
			local g = G_ConfigManager:GetUserGlobalConfig()
			o[#o + 1] = 'SweepPerDay=' .. tostring(g and g.SweepPerDay)
			local okS, nS = G_ChapterDataManager:GetSweepCount()
			o[#o + 1] = 'SweepCount=' .. tostring((okS and nS) or '?')
			local ok, n = G_ChapterLogic:CheckCanSweepCount('@AI@')
			o[#o + 1] = 'CheckCanSweepCount -> ' .. tostring(ok) .. ', ' .. tostring(n)
			return table.concat(o, '  ')
		end

		function g_qcTrangThai()
			local o = {}
			local ok, base = G_UserLogic:GetBaseInfo()
			o[#o + 1] = 'theLuc=' .. tostring((ok and base) and base.FatigueValue or '?')
			local ok2, n = G_ChapterDataManager:GetSweepCount()
			o[#o + 1] = 'daQuet=' .. tostring((ok2 and n) or '?')
			local ok3, bao = G_ChapterLogic:GetBattleReportsData('@AI@')
			if ok3 and type(bao) == 'table' then
				o[#o + 1] = 'daThang=' .. tostring(bao.PassMissionCount)
			else
				o[#o + 1] = 'chua co chien bao'
			end
			return table.concat(o, '  ')
		end

		-- Dat the luc ve dung n. `AddFatigueValue` tu choi khi ket qua am nen
		-- phai cong them truoc khi tru.
		function g_qcDatTheLuc(n)
			local ok, base = G_UserLogic:GetBaseInfo()
			local cur = (ok and base) and tonumber(base.FatigueValue) or 0
			local can = n - cur
			if can == 0 then return true end
			if can > 0 then return G_UserLogic:AddFatigueValue(can, 'verify_can_quet') end
			local ok2, base2 = G_UserLogic:GetBaseInfo()
			local du = (ok2 and base2) and tonumber(base2.FatigueValue) or 0
			if du < -can then G_UserLogic:AddFatigueValue(du, 'verify_can_quet') end
			return G_UserLogic:AddFatigueValue(can, 'verify_can_quet')
		end

		-- Nang PlayPerDay va TRA LAI nguyen trang bang `g_qcTraPlayPerDay`.
		-- Day la cach DUY NHAT lam `CheckCanSweepCount` vuot 10 (hoac ve 0) tren
		-- ban luu nay, va nho vay moi do duoc tran 10 cua lop offline.
		--
		-- KHONG xoa chien bao trong hai ham nay, du truoc day chung xoa: khoi F2
		-- can `PassMissionCount` con nguyen SAU luot quet de hieu ra AM, ma xoa
		-- chien bao la hieu ve 0. Moi khoi tu goi `ResetBattleReports` o cho no
		-- can — xem cac dong `dat lai chien bao`.
		g_qcPdCu = nil
		function g_qcNangPlayPerDay(n)
			local cfg = G_ConfigManager:GetChapterConfig('@AI@')
			if cfg == nil then return 'khong co cau hinh' end
			g_qcPdCu = cfg.PlayPerDay
			cfg.PlayPerDay = n
			local ok, m = G_ChapterLogic:CheckCanSweepCount('@AI@')
			return string.format('PlayPerDay %s -> %s | CheckCanSweepCount -> %s, %s',
				tostring(g_qcPdCu), tostring(n), tostring(ok), tostring(m))
		end
		function g_qcTraPlayPerDay()
			local cfg = G_ConfigManager:GetChapterConfig('@AI@')
			if cfg == nil or g_qcPdCu == nil then return 'khong tra duoc' end
			cfg.PlayPerDay = g_qcPdCu
			-- KHONG hoi `CheckCanSweepCount` o day: luc tra lai thi
			-- `PassMissionCount` co the da vuot `PlayPerDay`, va hoi se ra dung
			-- vet `ProcessError!` cua ban goc — mot dong loi gia do chinh bo do
			-- nay sinh ra, dung thu ma khoi I dang dem.
			return 'PlayPerDay=' .. tostring(cfg.PlayPerDay)
		end
		return true
	"""


func _may_do() -> void:
	_lua.run(_MAY_DO.replace("@AI@", AI), "may do")


## Goi mot bieu thuc Lua va lay chuoi no tra ve. Tham so la CA bieu thuc
## (`g_qcHangSo()`, `g_qcNangPlayPerDay(25)`), khong phai ten ham tran.
func _bien(doan: String) -> String:
	var r: Variant = _lua.run("return tostring(%s)" % doan, doan)
	_xa_loi()
	return str(r)


func _moc() -> Array:
	var s := _bien("g_qcDocMoc()")
	if s == "":
		return []
	return s.split("\n")


## Doc dong moc dau tien cua `nhan`, tra ve Dictionary cac truong `khoa=gia tri`.
func _doc_moc(moc: Array, nhan: String) -> Dictionary:
	for dong in moc:
		var d := String(dong)
		if not d.begins_with(nhan + ": "):
			continue
		var out := {}
		for kv in d.substr(nhan.length() + 2).split(" "):
			var s := String(kv)
			if s.contains("="):
				out[s.get_slice("=", 0)] = s.get_slice("=", 1)
		return out
	return {}


func _the_luc(tt: String) -> int:
	return _so_trong(tt, "theLuc=")


func _da_thang(tt: String) -> int:
	# "chua co chien bao" la 0 tran da thang, KHONG phai mot loi: `ResetBattleReports`
	# xoa chien bao di that, nen truoc moi phep quet no thuong khong co.
	var v := _so_trong(tt, "daThang=")
	return 0 if v == -999999 else v


func _so_trong(tt: String, khoa: String) -> int:
	var i := tt.find(khoa)
	if i < 0:
		return -999999
	return int(tt.substr(i + khoa.length()).split(" ")[0])


## So vet loi Lua co chu `chu` trong ngan xep — dung de do `ProcessError!` gia.
func _dem_vet_reduce() -> int:
	var n := 0
	for e in _lua.errors:
		if String(e).contains("ReduceSweepCount"):
			n += 1
	return n


func _dem_loi_lua(chu: String) -> int:
	var n := 0
	for e in _lua.errors:
		if String(e).contains(chu):
			n += 1
	return n


## Doc `user://offline.log` — bang chung doc lap rang handler chay qua CallServer.
func _doc_nhat_ky() -> PackedStringArray:
	var f := FileAccess.open("user://offline.log", FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var s := f.get_as_text()
	f.close()
	return s.split("\n")


func _dem_nhat_ky(chu: String) -> int:
	var n := 0
	for dong in _doc_nhat_ky():
		if dong.contains(chu):
			n += 1
	return n


func _nha(so: int) -> void:
	for i in so:
		_lua.tick(KHUNG)


## In ra moi loi Lua moi ke tu lan goi truoc — de mot doan Lua hong khong im lang
## bien thanh mot cau tra loi "?".
func _xa_loi() -> void:
	while _da_in < _lua.errors.size():
		print("   loi Lua: %s" % str(_lua.errors[_da_in]).substr(0, 200))
		_da_in += 1
