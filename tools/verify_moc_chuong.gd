# QUA MOC CHUONG (阶段目标) — thanh tuu loai 3000, moc "the luc da tieu".
#
#   godot --headless --path . --script tools/verify_moc_chuong.gd
#
# Vi sao phai co bo kiem nay: `CUILevelTarget` (阶段目标) doc tien do moc bang
# `G_UserLogic:GetStatisticsCommonData("ConsumFatigueValue")` roi so voi
# `data.AchieveCondition.ConditionVal`. Quet ca `sc/` truoc luot nay: 21 cho goi
# `SetStatisticsCommonData` nhung KHONG cho nao dung chuoi "ConsumFatigueValue".
# Do duoc: the luc roi THAT (120 -> 114 sau mot luot quet) ma thong ke van `nil`,
# tien do van 0, `CheckAchievement` van false — nen moc khong bao gio sang `Done`
# va qua cua no khong bao gio phat. Khong bo kiem nao khac phu cho nay: bo `can
# quet` chi lo duong can quet (no do the luc roi dung 6, khong hoi thong ke).
#
# ---------------------------------------------------------------------------
# LUAT DO TU MA GOC, va mot cho PHAI SUY — noi ro ra:
#
#   KHOA GHI — khong phai suy: ban ghi thanh tuu 3000 o lop nay mang
#   `DataEventList = { "GameUserGlobalData.Sta_ConsumFatigueValue" }` (nhom A do
#   nguyen chuoi nay). `SetStatisticsCommonData("ConsumFatigueValue", n)` chay
#   qua `SetCommonData` roi `strSaveKey = "Sta_" .. strKey`, va phat
#   `PostDataEvent` dung bang `GameUserGlobalData` — tuc la phat ra CHINH chuoi
#   ma ban ghi dang nghe. Khoa da dung san; chi thieu NGUON GHI.
#
#   CHO GHI — cho DUY NHAT phai suy: nua ghi cua ban goc nam phia server, khong
#   duoc ship — dung kieu voi nguoi goi `ReduceSweepCount` (xem dau
#   `tools/verify_can_quet.gd`). Lop nay ghi tai `tru_the_luc`
#   (offline/handlers/chapter.lua), noi DUY NHAT trong lop offline tieu the luc:
#   grep `AddFatigueValue` tren ca `sc/offline/` ra dung mot tep, chinh tep ay.
#
#   GHI NET, khong ghi gop — do duoc, khong doan: ba cho hoan the luc
#   (`tru_the_luc(-...)`) deu chay khi luot quet KHONG ra phan thuong nao. Nhom D
#   dung bo do chan `chapterSweepHandle` de ep ba duong ay chay that, roi doi
#   thong ke phai LUI dung bang phan the luc duoc tra lai. Ghi gop thi mot nguoi
#   choi quet mai mot ai luon that bai se day duoc moc ma khong mat gi.
#
#   DAY CHUYEN — da co san, khong phai viet them: `SetStatisticsCommonData`
#   phat su kien du lieu, client tu goi `CallReachAchieve`, va
#   `offline/handlers/achieve.lua` (co tu truoc luot nay) tra loi bang
#   `ReachAchieve`. Nhom E chung minh bang cach ghi thang 850 va doi `State`
#   nhay 1 (Doing) -> 2 (Done) — bo do KHONG he goi `ReachAchieve`, nen cu nhay
#   ay la bang chung duong that da chay.
#
#   CON SO — `AddFatigueValue` tra ve `(bResult, nFatigueValue)`; khi nhan
#   `nTru < 0` va tra true thi so the luc DA TIEU dung bang `-nTru`, khong can
#   doc lai the luc truoc/sau (chinh no tu goi `RefreshFatigueValue` truoc, nen
#   hai lan doc se dinh khoang nghi). Nhom B doi HAI con so doc tu HAI duong
#   khac nhau (`GetBaseInfo` va `GetStatisticsCommonData`) phai khop nhau.
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0
const CHO := 60
const AI := "L_N_01_01"
const MOC := 850

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
	var n_loi_truoc := _dem_loi_lua("ConsumFatigueValue")

	print("\n=== A. Hinh dang that cua moc 3000 — do tu BAN GHI, khong doc ma ===")
	var a := _tt("A")
	print("   %s" % a)
	_ghi_chu(a.contains("loaiMoc=3000"), "ConsumFatigueValueAchive = 3000")
	_ghi_chu(a.contains("banGhi=co"), "lop offline CO ban ghi thanh tuu 3000")
	_ghi_chu(a.contains("achType=3000"), "AchieveType = 3000")
	_ghi_chu(a.contains("cond=%d" % MOC), "ConditionVal = %d (moc that, khong phai 3000)" % MOC)
	_ghi_chu(a.contains("state=1"), "State = 1 = Doing (chua dat)")
	_ghi_chu(a.contains("soEvt=1"), "ban ghi nghe DUNG MOT su kien du lieu")
	_ghi_chu(a.contains("evt=GameUserGlobalData.Sta_ConsumFatigueValue"),
			"su kien ay la GameUserGlobalData.Sta_ConsumFatigueValue — dung khoa se ghi")
	_ghi_chu(a.contains("tk=nil"), "truoc luot nay thong ke CHUA ai ghi (nil)")
	_ghi_chu(a.contains("prog=0/"), "tien do moc = 0")
	_ghi_chu(a.contains("check=false"), "CheckAchievement = false")

	print("\n=== B. Quet 1 lan — nguon ghi co that, hai duong phai khop ===")
	var b_truoc := _tt("B truoc")
	print("   truoc: %s" % b_truoc)
	var tl0 := int(_truong(b_truoc, "tl"))
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet 1")
	_nha(CHO)
	var b_sau := _tt("B sau")
	print("   sau:   %s" % b_sau)
	var tl1 := int(_truong(b_sau, "tl"))
	var tk1 := int(_truong(b_sau, "tk"))
	print("   the luc %d -> %d (roi %d)   thong ke -> %d" % [tl0, tl1, tl0 - tl1, tk1])
	_ghi_chu(tl0 == 120, "the luc dau = 120 (mau cua ban luu moi)")
	_ghi_chu(tl0 - tl1 == 6, "mot luot quet tieu dung 6 the luc")
	_ghi_chu(tk1 == tl0 - tl1,
			"thong ke = 6, KHOP dung so the luc da tieu — hai duong doc doc lap")
	_ghi_chu(b_sau.contains("prog=6/%d" % MOC), "tien do moc = 6/%d" % MOC)

	print("\n=== C. Quet 10 voi tran 1 — dem theo so lan QUET THAT ===")
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	_lua.run("G_ChapterLogic:ChapterSweepTen('%s') return true" % AI, "quet 10 khi tran 1")
	_nha(CHO)
	var c := _tt("C")
	print("   %s" % c)
	var tl2 := int(_truong(c, "tl"))
	var tk2 := int(_truong(c, "tk"))
	print("   the luc %d -> %d (roi %d)   thong ke -> %d" % [tl1, tl2, tl1 - tl2, tk2])
	_ghi_chu(tl1 - tl2 == 6,
			"tran la 1 nen chi quet 1 lan: the luc chi roi 6, khong phai 60")
	_ghi_chu(tk2 - tk1 == tl1 - tl2,
			"thong ke tang dung 6 theo so lan quet THAT, khong theo so lan xin")

	print("\n=== D. Ghi NET — luot quet khong ra thuong thi thong ke phai LUI ===")
	print("   (bo do chan chapterSweepHandle de ep ba duong hoan the luc chay that)")
	var ttD_truoc := _tt("D truoc")
	var tlD := int(_truong(ttD_truoc, "tl"))
	var tkD := int(_truong(ttD_truoc, "tk"))
	print("   truoc: the luc %d   thong ke %d" % [tlD, tkD])
	_lua.run("g_mcChan(0) return true", "chan het moi luot quet")
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet 1, bi tu choi")
	_nha(CHO)
	var d1 := _tt("D1")
	print("   D1 (Once, tu choi het): %s" % d1)
	_ghi_chu(int(_truong(d1, "tl")) == tlD,
			"the luc VE NGUYEN: luot quet khong ra thuong thi khong tieu the luc")
	_ghi_chu(int(_truong(d1, "tk")) == tkD,
			"thong ke cung VE NGUYEN — ghi GOP se de lai +6 o day")

	print("   D2 (Ten tran 3, chi luot DAU ra thuong):")
	_lua.run("g_mcChan(1) return true", "chi cho luot quet dau qua")
	var nang := _bien("g_mcPlayPerDay(3)")
	print("     %s" % nang)
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	_lua.run("G_ChapterLogic:ChapterSweepTen('%s') return true" % AI, "quet 10 khi tran 3")
	_nha(CHO)
	var d2 := _tt("D2")
	print("     %s" % d2)
	var tlD2 := int(_truong(d2, "tl"))
	var tkD2 := int(_truong(d2, "tk"))
	print("     the luc %d -> %d (roi %d)   thong ke %d -> %d (tang %d)"
			% [tlD, tlD2, tlD - tlD2, tkD, tkD2, tkD2 - tkD])
	_ghi_chu(tlD - tlD2 == 6,
			"xin 3 lan, chi 1 lan ra thuong: the luc chi roi 6 (2 lan kia duoc hoan)")
	_ghi_chu(tkD2 - tkD == 6,
			"thong ke cung chi tang 6 — dung phan the luc KHONG duoc hoan")
	_ghi_chu(not nang.contains("khong co cau hinh"), "nang duoc PlayPerDay cua ai do")
	var tra := _bien("g_mcTra()")
	print("     %s" % tra)
	_ghi_chu(tra.contains("conNguyen=true"), "tra lai duoc chapterSweepHandle goc")
	_lua.run("g_mcTraPlayPerDay() return true", "tra PlayPerDay")

	print("\n=== E. Day chuyen moc — ghi thong ke la client TU chay toi Done ===")
	print("   (bo do KHONG goi ReachAchieve; cu nhay State la bang chung duong that)")
	var e850 := _tt("E 850")
	_lua.run("g_mcDatTk(%d) return true" % MOC, "ghi thang %d" % MOC)
	_nha(CHO)
	e850 = _tt("E sau 850")
	print("   ghi %d: %s" % [MOC, e850])
	_ghi_chu(e850.contains("state=2"),
			"State nhay 1 -> 2 = Done: client nghe su kien roi tu goi CallReachAchieve")
	_ghi_chu(e850.contains("check=true"), "CheckAchievement = true")
	_ghi_chu(e850.contains("prog=%d/%d" % [MOC, MOC]), "tien do = %d/%d" % [MOC, MOC])
	var n_tu_choi := _dem_nhat_ky_hai("ClientReachAchieve", "tu choi")
	print("   nhat ky 'ClientReachAchieve ... tu choi': %d" % n_tu_choi)
	_ghi_chu(n_tu_choi == 0, "luat goc KHONG tu choi lan dat moc nao")

	var e849 := _bien("g_mcDatTk(849)")
	print("   %s" % e849)
	_nha(CHO)
	e849 = _tt("E sau 849")
	print("   ghi 849: %s" % e849)
	_ghi_chu(e849.contains("check=false"), "lui xuong 849 thi CheckAchievement = false lai")
	_ghi_chu(e849.contains("state=2"),
			"nhung State VAN la 2: client chi di Doing -> Done, khong lui (do duoc)")

	print("\n=== F. Hoan the luc khi thong ke dang 0 — khong duoc thanh so am ===")
	var f0 := _bien("g_mcDatTk(0)")
	print("   %s" % f0)
	_lua.run("g_mcChan(0) return true", "chan het moi luot quet")
	_lua.run("G_ChapterLogic:ResetBattleReports() return true", "dat lai chien bao")
	_nha(CHO)
	_lua.run("G_ChapterLogic:ChapterSweepOnce('%s') return true" % AI, "quet 1, bi tu choi")
	_nha(CHO)
	var f := _tt("F")
	print("   %s" % f)
	_ghi_chu(int(_truong(f, "tk")) == 0, "thong ke = 0, khong am")
	print("   (nhanh KEP am khong chay o day: moi luot hoan deu co luot tru di kem")
	print("    trong CUNG mot lan goi handler, nen duong that khong voi toi no —")
	print("    nhom I moi goi thang qua pheu de ep nhanh kep chay)")
	_lua.run("g_mcTra() return true", "tra lai chapterSweepHandle goc")

	print("\n=== H. Phễu — đường TRẬN cũng phải được đếm, không chỉ đường quét ===")
	print("   (vì sao ghi ở phễu `AddFatigueValue` chứ không ở handler càn quét:")
	print("    `saveChapterBeginStatus`:915 và `chapterVictoryHandle`:2717 cũng đi qua nó)")
	var h_gan := _bien("g_mcGan()")
	print("   %s" % h_gan)
	_ghi_chu(h_gan.contains("gan=true"), "bọc được phễu thể lực lúc khởi động")
	_ghi_chu(h_gan.contains("dungHamTa=true"),
			"`G_UserLogic.AddFatigueValue` HIỆN LÀ hàm bọc của lớp này")

	_lua.run("g_mcChan(0) return true", "giu nguyen: khong cho luot quet nao qua")
	_lua.run("g_mcTra() return true", "tra lai chapterSweepHandle goc")
	var h_truoc := _tt("H truoc")
	var tlH := int(_truong(h_truoc, "tl"))
	var tkH := int(_truong(h_truoc, "tk"))
	print("   truoc: the luc %d   thong ke %d" % [tlH, tkH])

	var h_vao := _bien("g_mcVaoTran(true)")
	print("   %s" % h_vao)
	_nha(CHO)
	var h1 := _tt("H1")
	print("   H1 (vao tran, co HeroList): %s" % h1)
	var tlH1 := int(_truong(h1, "tl"))
	var tkH1 := int(_truong(h1, "tk"))
	print("   the luc %d -> %d (roi %d)   thong ke %d -> %d (tang %d)"
			% [tlH, tlH1, tlH - tlH1, tkH, tkH1, tkH1 - tkH])
	_ghi_chu(tlH - tlH1 == 1,
			"vao tran tru 1/6 the luc = 1 (L_N_01_01 co ChapterUserFatigue = 6)")
	_ghi_chu(tkH1 - tkH == 1,
			"thong ke cung tang 1 — duong TRAN duoc dem, day la ly do ghi o PHEU")

	# Thieu HeroList thi `saveChapterBeginStatus` tu choi ngay
	# (`ProcessNotTable(tData.HeroList)`, :858, ma ParamError = 4) TRUOC khi tru
	# the luc — nen khong duoc dem gi. Luot do dau tien cua bo do nay thieu truong
	# ay nen doc ra 'ma 4'; ghi lai de lan sau khong tuong do la loi san pham.
	var h_khong := _bien("g_mcVaoTran(false)")
	print("   %s" % h_khong)
	_nha(CHO)
	var h2 := _tt("H2")
	print("   H2 (thieu HeroList, bi tu choi): %s" % h2)
	_ghi_chu(int(_truong(h2, "tl")) == tlH1,
			"luot vao tran BI TU CHOI khong tru the luc")
	_ghi_chu(int(_truong(h2, "tk")) == tkH1,
			"va cung khong lam thong ke nhuc nhich")

	print("\n=== I. Số DƯƠNG — chỉ nguồn hoàn mới được trừ, tăng thật thì không ===")
	var i_truoc := _tt("I truoc")
	var tlI := int(_truong(i_truoc, "tl"))
	var tkI := int(_truong(i_truoc, "tk"))
	print("   truoc: the luc %d   thong ke %d" % [tlI, tkI])

	var i_mua := _bien("g_mcThem(5, 'mua-the-luc')")
	print("   %s" % i_mua)
	_nha(CHO)
	var i1 := _tt("I1")
	print("   I1 (tang that, khong phai nguon hoan): %s" % i1)
	_ghi_chu(int(_truong(i1, "tl")) == tlI + 5, "the luc TANG that 5")
	_ghi_chu(int(_truong(i1, "tk")) == tkI,
			"thong ke KHONG doi — mua the luc khong phai la 'da tieu'")

	var i_hoan := _bien("g_mcDatTk(10)")
	print("   %s" % i_hoan)
	var i_hoan2 := _bien("g_mcThem(5, 'ClientChapterSweepOnce-hoan')")
	print("   %s" % i_hoan2)
	_nha(CHO)
	var i2 := _tt("I2")
	print("   I2 (nguon hoan, hau to -hoan): %s" % i2)
	_ghi_chu(int(_truong(i2, "tl")) == tlI + 10, "the luc hoan lai 5 nua")
	_ghi_chu(int(_truong(i2, "tk")) == 5,
			"thong ke LUI dung 5 theo hau to -hoan — day la luat ghi NET")

	# Kẹp ở 0: hoàn nhiều hơn số đang có. Đường THẬT không với tới nhánh này (mọi
	# lượt hoàn đều có lượt trừ đi kèm trong cùng một lần gọi handler), nhưng gọi
	# thẳng qua phễu thì tới được — nên khẳng định được nhánh kẹp ĐÃ CHẠY, chứ
	# không phải suông.
	_lua.run("g_mcDatTk(2) return true", "dat thong ke = 2")
	var i_kep := _bien("g_mcThem(5, 'ClientChapterSweepTen-hoan')")
	print("   %s" % i_kep)
	_nha(CHO)
	var i3 := _tt("I3")
	print("   I3 (hoan 5 khi thong ke chi con 2): %s" % i3)
	_ghi_chu(int(_truong(i3, "tk")) == 0, "thong ke KEP o 0, khong thanh so am")

	print("\n=== G. Khong sinh vet loi nao do lop cua minh ===")
	var n_loi := _dem_loi_lua("ConsumFatigueValue") - n_loi_truoc
	var n_set := _dem_loi_lua("SetStatisticsCommonData")
	print("   loi Lua mang 'ConsumFatigueValue': %d   'SetStatisticsCommonData': %d"
			% [n_loi, n_set])
	_ghi_chu(n_loi == 0, "ghi thong ke khong lam Lua bao loi")
	_ghi_chu(n_set == 0, "va khong co vet nao cua chinh ham ghi")

	print("\ndat %d, hong %d" % [_dat, _hong])
	_xa_loi()
	_san.free()
	quit(1 if _hong > 0 else 0)


# ---------------------------------------------------------------------------
# May do phia Lua. Tra ve CHUOI chu khong tra bang: bang Lua qua cau GDScript la
# `LuaTable`, khong phai Array/Dictionary.
#
# Moi truong ngan cach bang DAU CACH, va khong gia tri nao chua dau cach. Dung
# `@AI@` + `.replace` chu KHONG phai `% [...]`: trong khoi Lua co `string.format`
# cua chinh Lua (`%s` cua no), ma toan tu `%` cua GDScript ap len CA chuoi.
# ---------------------------------------------------------------------------
const _MAY_DO := """
		-- Trang thai moc + the luc + thong ke, mot chuoi phang 'khoa=gia tri'.
		function g_mcTrangThai()
			local o = {}
			o[#o + 1] = 'loaiMoc=' .. tostring(G_AchieveLogic.ConsumFatigueValueAchive)
			local b, d = G_AchieveLogic:getAllAchieveWithType(G_AchieveLogic.ConsumFatigueValueAchive)
			if not b or type(d) ~= 'table' then
				o[#o + 1] = 'banGhi=khong co'
				return table.concat(o, ' ')
			end
			o[#o + 1] = 'banGhi=co'
			o[#o + 1] = 'achType=' .. tostring(d.AchieveType)
			o[#o + 1] = 'state=' .. tostring(d.State)
			o[#o + 1] = 'cond=' .. tostring(d.AchieveCondition and d.AchieveCondition.ConditionVal)
			local nEvt, strEvt = 0, ''
			if type(d.DataEventList) == 'table' then
				for _, v in ipairs(d.DataEventList) do
					nEvt = nEvt + 1
					strEvt = strEvt .. tostring(v)
				end
			end
			o[#o + 1] = 'soEvt=' .. nEvt
			o[#o + 1] = 'evt=' .. strEvt
			local _, nS = G_UserLogic:GetStatisticsCommonData('ConsumFatigueValue')
			o[#o + 1] = 'tk=' .. tostring(nS)
			local _, nP, nC = G_AchieveLogic:getConsumFatigueValueProgress(d)
			o[#o + 1] = 'prog=' .. tostring(nP) .. '/' .. tostring(nC)
			local _, rC = G_AchieveLogic:CheckAchievement(d)
			o[#o + 1] = 'check=' .. tostring(rC)
			local _, bi = G_UserLogic:GetBaseInfo()
			o[#o + 1] = 'tl=' .. tostring(bi and bi.FatigueValue)
			return table.concat(o, ' ')
		end

		function g_mcDatTk(n)
			local ok = G_UserLogic:SetStatisticsCommonData('ConsumFatigueValue', n)
			return 'datTk ' .. tostring(n) .. ' -> ok=' .. tostring(ok)
		end

		-- Chan `chapterSweepHandle` de ep duong 'luot quet khong ra thuong' chay
		-- that. `nChoQua` = so lan dau tien con cho di qua; het thi tra TU CHOI
		-- dung hinh ban goc (`false, ma loi, nil`), va `mot_lan_quet` doc ra nil.
		g_mcGoc = nil
		g_mcCho = 0
		function g_mcChan(nChoQua)
			if g_mcGoc == nil then
				g_mcGoc = G_ChapterLogic.chapterSweepHandle
			end
			if g_mcGoc == nil then
				return 'khong lay duoc ham goc'
			end
			g_mcCho = nChoQua
			G_ChapterLogic.chapterSweepHandle = function(self, cfg, nEx, tRoi, nSao, bSweep, strFrom)
				if g_mcCho > 0 then
					g_mcCho = g_mcCho - 1
					return g_mcGoc(self, cfg, nEx, tRoi, nSao, bSweep, strFrom)
				end
				return false, 999, nil
			end
			return 'chan nChoQua=' .. tostring(nChoQua)
		end

		function g_mcTra()
			local bDaChan = (g_mcGoc ~= nil)
			if bDaChan then
				G_ChapterLogic.chapterSweepHandle = g_mcGoc
				g_mcGoc = nil
			end
			return 'conNguyen=' .. tostring(G_ChapterLogic.chapterSweepHandle ~= nil)
		end

		g_mcPdCu = nil
		function g_mcPlayPerDay(n)			local cfg = G_ConfigManager:GetChapterConfig('@AI@')
			if cfg == nil then return 'khong co cau hinh' end
			g_mcPdCu = cfg.PlayPerDay
			cfg.PlayPerDay = n
			return 'PlayPerDay ' .. tostring(g_mcPdCu) .. ' -> ' .. tostring(n)
		end
		function g_mcTraPlayPerDay()
			local cfg = G_ConfigManager:GetChapterConfig('@AI@')
			if cfg == nil or g_mcPdCu == nil then return 'khong tra duoc' end
			cfg.PlayPerDay = g_mcPdCu
			g_mcPdCu = nil
			return 'PlayPerDay=' .. tostring(cfg.PlayPerDay)
		end

		-- Pheu the luc da duoc boc chua, va co dung la ham boc CUA TA khong.
		function g_mcGan()
			local ok = OfflineThongKe:dam_bao()
			return 'gan=' .. tostring(ok)
				.. ' hamGoi=' .. tostring(OfflineThongKe.ham_goi ~= nil)
				.. ' dungHamTa=' .. tostring(G_UserLogic.AddFatigueValue == OfflineThongKe.ham_goi)
		end

		-- Doi the luc truc tiep qua pheu, de thu rieng luat dau cua ham boc.
		function g_mcThem(n, strNguon)
			local ok, nMoi = G_UserLogic:AddFatigueValue(n, strNguon)
			return 'them n=' .. tostring(n) .. ' nguon=' .. tostring(strNguon)
				.. ' ok=' .. tostring(ok) .. ' tlMoi=' .. tostring(nMoi)
		end

		-- Vao tran that. `coHero` = false de do duong BI TU CHOI: thieu
		-- `HeroList` thi `saveChapterBeginStatus` tra ParamError TRUOC khi tru
		-- the luc (share_ChapterLogic.lua:858).
		function g_mcVaoTran(coHero)
			local t = { ChapterKey = '@AI@' }
			if coHero then t.HeroList = {} end
			local ok = G_ChapterLogic:ChapterBegin(t)
			return 'vaoTran coHero=' .. tostring(coHero) .. ' -> ' .. tostring(ok)
		end
		return true
	"""


func _may_do() -> void:
	_lua.run(_MAY_DO.replace("@AI@", AI), "may do")


func _bien(doan: String) -> String:
	var r = _lua.run("return tostring(%s)" % doan, "probe")
	if r == null:
		return "<LUA TRA NULL: %s>" % ", ".join(_lua.errors)
	return str(r)


func _tt(nhan: String) -> String:
	return _bien("g_mcTrangThai()")


func _truong(dong: String, khoa: String) -> String:
	for phan in dong.split(" ", false):
		if phan.begins_with(khoa + "="):
			return phan.substr(khoa.length() + 1)
	return ""


func _dem_loi_lua(chu: String) -> int:
	var n := 0
	for e in _lua.errors:
		if String(e).contains(chu):
			n += 1
	return n


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


## Dem dong nhat ky chua CA HAI chuoi. Dung cho `ClientReachAchieve ... tu choi`:
## dem rieng "ClientReachAchieve" se ke ca dong KHONG tu choi, va mot phep dem
## luon ra 0 thi khong gac duoc gi.
func _dem_nhat_ky_hai(chu1: String, chu2: String) -> int:
	var n := 0
	for dong in _doc_nhat_ky():
		if dong.contains(chu1) and dong.contains(chu2):
			n += 1
	return n


func _nha(so: int) -> void:
	for i in so:
		_lua.tick(KHUNG)


## In ra moi loi Lua moi ke tu lan goi truoc — de mot doan Lua hong khong im lang
## bien thanh mot cau tra loi "?".
func _xa_loi() -> void:
	while _da_in < _lua.errors.size():
		print("   [loi Lua] %s" % _lua.errors[_da_in])
		_da_in += 1
