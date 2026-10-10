# MAN CHIEN DICH (`CUIActivityMode`, 战役) — cac the hoat dong BEN TRONG, va hai
# lop chon do kho.
#
#   godot --headless --path . --script tools/verify_the_hoat_dong.gd
#
# Vi sao phai co bo kiem nay: `verify_nut_chien_dich.gd` da lo phan MO man nay tu
# nut tren Main (`btnMainUIAttackActivity`). Nhung BEN TRONG man thi khong bo nao
# hoi: `do_chien_dich.gd` di duong chien dich khac, con `bam_that.gd` chi hoi
# "co qua duoc buoc khong". The hoat dong lay tu CONFIG chu khong tu du lieu nguoi
# choi, nen "tren ban luu offline khong vao duoc loai nao" la ket qua CO THE DUNG
# — phai do xem cong nao chan, chu khong duoc doan.
#
# ---------------------------------------------------------------------------
# LUAT DO TU MA GOC (`CUIActivityMode.lua`), khong suy:
#
#   `onTouchEnd_OnInfoButtonClick` (:1394) — THU TU cac cong la ca cau tra loi:
#     :1424  self.nSelectedChapterType = tonumber(sender:getStringTag())
#            -> lay tu `getStringTag()`, KHONG phai meta `tag` cua node. Do duoc:
#               the mang meta tag=2 nhung dat nSelectedChapterType = 5.
#     :1432  tSelectChapterTypeData = ChapterTypeDataList[tostring(type)]
#     :1437  getChapterDataWithDifficulty(self.nDifficulty1, tSelectChapterTypeData)
#     :1438  nUserLevel < tChapterData.ChapterOpenNeedCharacterLevel -> tip
#            `BattleTranscript_NeedHeroLevelOpenChapter` kem so cap do, ROI THANG
#     :1446  not tChapterData.IsOpen and type ~= FB_Epic -> tip
#            `Chapter_Activity_NotOpen`, roi thang
#   CONG CAP DO DUNG TRUOC CONG `IsOpen`. Nen mot loai `IsOpen == false` ma nguoi
#   choi chua du cap thi tip phai noi ve CAP DO, khong phai "chua mo" — do la phep
#   kiem PHAN BIET duoc hai thu tu, chu khong phai doc lai ma goc. (`FB_Epic` duoc
#   mien cong `IsOpen` o :1447, nhung khong duoc mien cong cap do.)
#
#   `initLuaName` (:117) — `pHJDifficultyLayer = lActivityModeUI:getChildByTag(2)`,
#   `pCommonDifficultyLayer = ...getChildByTag(3)`. Trong
#   `layout_ref/UI_ActivityMode_960_640.json`, `lActivityModeUI` (960x640) co dung
#   hai con do: tag=2 "黄巾入侵难度选择面板" va tag=3 "通用难度选择面板", ca hai
#   715x335 va `visible: false`. Bo kiem nay do CA HAI dau: phia Lua lay duoc node
#   theo tag, va phia CAY GODOT hai node ay that su dang an.
#
#   CONG DOC SO TU DAU — `:1437` goi `getChapterDataWithDifficulty(nDifficulty1, …)`
#   roi `:1438` so `tChapterData.ChapterOpenNeedCharacterLevel`. Ham do (`:764-805`)
#   duyet HET roi GIU MUC CUOI khop `ChapterDifficulty == nDifficulty`, nen
#   `tSelectChapterTypeData[1]` KHONG phai muc cong doc. Do duoc: loai 5 co
#   `[1]` doi cap 50 trong khi cong doc 22 — va tip tra ra dung so 22. Nen moi con
#   so trong bo kiem nay lay tu CHINH ham do (`so_lech` in ra so loai bi lech), va
#   phep kiem noi tip voi cong chu khong doc lai `[1]`.
#
#   HAI LOP DO KHO MO BANG DUONG NAO — khong phai do cu cham the. `_showDifficultyUI`
#   (`:1577`) chi duoc goi tu `OnGetPassMissionCountList` (`:1567`), tuc la tu buoc
#   tra loi `GetPassMissionCountList`. Duong do KHONG can may chu that:
#   `ClientChapterLogic:GetPassMissionCountList` (`sc/user/Logical/ClientChapterLogic.lua:200`)
#   goi `getPassMissionCountList` roi `S_CCSchedule:scheduleOnce(self,
#   "OnServerGetPassMissionCountList")` (`:210`) — hen chay LAI TRONG MAY. Do duoc
#   o nhom I: nang cap trong bo nho len 99 roi cham the loai 5 thi
#   `pCommonDifficultyLayer` (tag=3) bat `visible = true`. Con luc chua du cap thi
#   hai lop dung yen — nen "lop do kho khong bao gio mo" moi la ket luan sai.
#
#   `lToolTipMask` (`layout_ref/UI_NormalDlg_960_640.json`) — 1366x768, zOrder
#   2800, `touch: "OnClose"`, `touchObj: "g_CUITipsDlg"`, `visible: false`. Tuc la
#   khi mot tip dang hien thi thi cu cham ke tiep bi CHINH TIP nuot, khong roi
#   xuong the. Day la thiet ke cua ban goc (co trong bo cuc), khong phai loi cua
#   ban dung — nen bo kiem khoa lai, de sau nay khong ai "sua" no thanh xuyen qua.
#
# ---------------------------------------------------------------------------
# HAI LOI DO CUA CHINH TOI, ghi lai de dung mac lai (moi loi tung cho ra mot ket
# luan SAI truoc khi biet):
#
#   1. `tostring(ok and v or '?')` — khi `v` la `false` thi `ok and v` ra `false`,
#      roi `false or '?'` ra `'?'`. Nen mot gia tri `false` hien ra y nhu mot LOI.
#      Muon phan biet "ham nem loi" voi "ham tra false" thi phai tach hai nhanh.
#   2. Do do hien thi bang phuong thuc cua Lua (`isVisible`) va bang truong cua cay
#      Godot (`visible`) la HAI duong khac nhau. Cho nao ket luan duoc thi ket luan
#      bang cay Godot. Day cung la ly do khoi B chay TRUOC moi cu cham: mot cu cham
#      lam tip hien len, va tip lam trang thai doc ra khac di.
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0
## So khung cho sau moi cu cham — du cho hoat canh `DelayTime(0)` cua man chay.
const CHO := 45
const MAN := "BattleActivityMode"
const THE := "OnInfoButtonClick"
const MASK := "lToolTipMask"

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
		print("nap hong")
		quit(1)
		return
	var d := VM.chay(_lua)
	if str(d["dung"]) != "":
		print("KHONG toi duoc Main: %s" % d["dung"])
		quit(1)
		return

	print("\n=== A. Mo man va bang du lieu cua no ===")
	_lua.run("g_CUINormalDlg:Show('%s', {}) return true" % MAN, "mo man")
	_nha(CHO)
	# May ghi tip: `onTouchEnd_OnInfoButtonClick` noi LY DO tu choi bang
	# `g_CUIToolTips:AddTipsWithString` (:1440 cho cong cap do, :1447 cho cong
	# chua mo). Ghi lai loi goi do la cach DUY NHAT biet cong nao da chan — neu
	# chi nhin "khong co gi mo ra" thi khong phan biet duoc voi mot handler chet.
	var moc: Variant = _lua.run("""
		g_mocTip = {}
		if g_CUIToolTips == nil then return 'khong' end
		local goc = g_CUIToolTips.AddTipsWithString
		g_CUIToolTips.AddTipsWithString = function(self, s)
			g_mocTip[#g_mocTip + 1] = tostring(s)
			return goc(self, s)
		end
		return 'dat'
	""", "dat may ghi tip")
	_ghi_chu(str(moc) == "dat", "dat duoc may ghi tip (`g_CUIToolTips:AddTipsWithString`)")
	var a := _doc_man()
	_ghi_chu(a["man"] == MAN, "man mo ra la %s (do: %s)" % [MAN, a["man"]])
	_ghi_chu(a["co_activity"] == "co",
			"g_CUIActivityMode co mat (khong phai bang ma cua bootstrap)")
	_ghi_chu(a["khoa_rong"] == "khong",
			"moi loai deu co ChapterKey — du lieu den tu config, khong phai tu nguoi choi")
	var so_loai := int(a["so_loai"])
	# KHONG khoa con so 8: danh sach hoat dong la danh sach XOAY VONG, do duoc bang
	# hai luot lien tiep — cung o `loai 5` ma luot truoc tro `FB_F_SYZLB` (doi cap
	# 61), luot sau tro `FB_E_SYZLB` (doi cap 22), va cap do de vao nhat cua ca
	# danh sach doi tu 22 xuong 31. Nen phep kiem khoa BAT BIEN (co loai, loai nao
	# cung co khoa, so the khop so loai, moi loai doi cap > cap nguoi choi) chu
	# khong khoa mot con so se thanh do o luot sau.
	_ghi_chu(so_loai >= 6, "ChapterTypeDataList co %d loai hoat dong (>= 6)" % so_loai)

	print("\n=== B. Hai lop chon do kho: co that, va dang AN (chay TRUOC moi cu cham) ===")
	var lua_lop := _doc_lop_lua()
	_ghi_chu(lua_lop["hj"] == "co" and lua_lop["common"] == "co",
			"phia Lua: getChildByTag(2) va (3) deu ra node that"
			+ " (pHJDifficultyLayer / pCommonDifficultyLayer)")
	var cay := _lop_theo_tag()
	_ghi_chu(cay["hj_tag"] and cay["common_tag"],
			"phia cay Godot: lActivityModeUI co dung con tag=2 (%s, %d con)"
			% [cay["hj_ten"], cay["hj_con"]]
			+ " va tag=3 (%s, %d con)" % [cay["common_ten"], cay["common_con"]])
	_ghi_chu(cay["hj_o"] == "715x335" and cay["common_o"] == "715x335",
			"hai lop do kho deu 715x335 (do: %s / %s)" % [cay["hj_o"], cay["common_o"]])
	_ghi_chu(not cay["hj_hien"] and not cay["common_hien"],
			"hai lop do kho dang AN khi vua vao man (hien: %s / %s)"
			% [str(cay["hj_hien"]), str(cay["common_hien"])])
	_ghi_chu(not _mask_hien(),
			"`%s` dang AN khi chua co tip nao" % MASK)

	print("\n=== C. The hoat dong: node cham that ===")
	var the := _tim(THE)
	_ghi_chu(the.size() == so_loai,
			"co dung %d the mang ten cham `%s`, khop so loai trong bang (do: %d)"
			% [so_loai, THE, the.size()])
	if the.is_empty():
		print("\ndat %d, hong %d" % [_dat, _hong])
		_xa_loi()
		quit(1 if _hong > 0 else 0)
		return

	print("\n=== D. Cham THAT the dau tien -> chon duoc mot loai ===")
	# Cham khi CHUA co tip nao (khoi B vua xac nhan mask dang an), neu khong thi
	# `lToolTipMask` se nuot cu cham — xem khoi G.
	var cu := _cham(the[0])
	_nha(CHO)
	var e := _doc_the()
	_ghi_chu(String(cu[1]) != "KHONG AI NHAN",
			"the dau tien nhan duoc cu cham (nhan: %s, o %s)" % [cu[1], cu[0]])
	var loai: String = e["loai"]
	_ghi_chu(loai != "nil" and loai != "0",
			"cham xong dat nSelectedChapterType = %s (theo getStringTag, khong theo meta tag)" % loai)
	_ghi_chu(e["so_ai"] != "0" and e["so_ai"] != "nil",
			"tSelectChapterTypeData tro dung danh sach cua loai %s (%s ai)" % [loai, e["so_ai"]])
	_ghi_chu(e["tip"] != "",
			"co tip hien ra: '%s'" % e["tip"])
	_ghi_chu(_mask_hien(),
			"`%s` HIEN khi tip dang hien thi" % MASK)

	print("\n=== E. Cong CAP DO dung truoc cong IsOpen ===")
	var lv := int(a["cap_do"])
	_ghi_chu(lv >= 1, "G_UserLogic:GetLevel() = %d" % lv)
	print("  (muc [1] khac lop ma cong doc o %s loai — nen moi so duoi day lay tu cong)"
			% a["so_lech"])
	_ghi_chu(int(a["cap_thap_nhat"]) > lv,
			"loai de vao nhat doi cap %s > %d — nen tren ban luu offline nay khong loai"
			% [a["cap_thap_nhat"], lv] + " nao vao duoc, va do la DUNG luat (khong phai loi)")
	# Cu cham THAT o nhom D: tip phai chua DUNG so ma cong so sanh. Thieu phep kiem
	# nay thi doc sai lop du lieu bao nhieu cung khong lo ra — no la cho noi tip voi
	# ma goc, chu khong phai doc lai ma goc.
	var e2 := _doc_the()
	var tip_d: String = e2["tip"]
	var need_d: String = e2["need_cong"]
	_ghi_chu(tip_d != "" and tip_d != "?" and need_d != "" and need_d != "?"
			and tip_d.contains(need_d),
			"tip '%s' cua loai %s chua dung so cap ma cong so sanh (:1438): %s"
			% [tip_d, e2["loai"], need_d])
	var loai_dong: String = a["loai_dong"]
	if loai_dong == "":
		# Danh sach hoat dong xoay vong giua cac luot chay, nen co luot khong loai nao
		# dang dong. Bo qua chu KHONG bao do — bao do o day la bao do theo may.
		print("BO QUA: luot nay khong loai nao co IsOpen == false (danh sach xoay vong)")
	else:
		var cap_can: String = a["cap_cua_loai_dong"]
		_ghi_chu(cap_can != "" and cap_can != "?",
				"loai %s dang dong (IsOpen == false) va doi cap %s" % [loai_dong, cap_can])
		var i := _the_cua_loai(int(loai_dong))
		if i < 0:
			_ghi_chu(false, "khong cham ra duoc the nao ung voi loai %s" % loai_dong)
		else:
			var f := _doc_the()
			var tip: String = f["tip"]
			# Tip ve cap do chua dung so cap do; tip "chua mo" thi khong. Nen phep
			# kiem nay phan biet duoc cong nao chay truoc, khong chi doc lai ma goc.
			_ghi_chu(tip != "" and tip.contains(cap_can),
					"the loai %s (IsOpen=false) ra tip ve CAP DO '%s' — dung so cap %s,"
					% [loai_dong, tip, cap_can]
					+ " tuc cong cap do (:1438) chay TRUOC cong IsOpen (:1446)")

	print("\n=== F. Bi tu choi thi khong mo gi ===")
	var g := _doc_man()
	_ghi_chu(g["man"] == MAN, "van o man %s (do: %s)" % [MAN, g["man"]])
	_ghi_chu(g["canh"] == "Main", "canh van la Main, khong vao tran (do: %s)" % g["canh"])
	var cay2 := _lop_theo_tag()
	_ghi_chu(not cay2["hj_hien"] and not cay2["common_hien"],
			"lop do kho VAN an — bi tu choi thi khong bat lop nao (hien: %s / %s)"
			% [str(cay2["hj_hien"]), str(cay2["common_hien"])])

	print("\n=== G. Tip dang hien thi thi nuot cu cham ke tiep (thiet ke ban goc) ===")
	var g1 := _cham(the[0])
	_nha(CHO)
	_ghi_chu(String(g1[1]) == MASK,
			"cu cham vao the trong luc co tip bi `%s` nuot (nhan: %s)" % [MASK, g1[1]])
	var g2 := _cham(the[0])
	_nha(CHO)
	_ghi_chu(String(g2[1]) != MASK,
			"cu cham ngay sau do xuong duoc the tro lai (nhan: %s)" % g2[1])

	print("\n=== H. Gat tip di duoc, va mask an lai ===")
	var gat := _tat_tip()
	_ghi_chu(gat, "cham vao `%s` thi tip tat (mask an: %s)" % [MASK, str(not _mask_hien())])

	print("\n=== I. Qua cong cap do roi thi lop do kho MO ra that ===")
	# Bo do o nhom nay NANG CAP TRONG BO NHO (`SetLevel`, `UserLogicDataManager.lua:124`)
	# — khong ghi gi xuong ban luu, tien trinh chet la het. Phai co no vi tren ban luu
	# that nguoi choi la cap 1 (chinh bang `GameUserBaseInfoReset` cua ban goc trong
	# `KDBGameCommonConfig.xgg`: "Level":1), ma moi loai doi cap >= 22 — nen khong cu
	# cham nao qua duoc cong that, va "lop do kho khong bao gio mo" se la ket luan
	# khong kiem chung duoc.
	var nang: Variant = _lua.run("""
		local ok, e = pcall(function() G_UserLogicDataManager:SetLevel(99) end)
		if not ok then return 'LOI: ' .. tostring(e) end
		return tostring(select(2, G_UserLogic:GetLevel()))
	""", "nang cap")
	var lv2 := int(str(nang))
	_ghi_chu(lv2 >= 99, "nang cap trong bo nho: GetLevel() = %s" % str(nang))
	if lv2 >= 99:
		_nha(CHO)
		# Du lieu: o cap 99 thi KHONG loai nao bi cong cap do chan nua. Neu mot luot
		# xoay vong nao do co loai doi cap > 99 thi phep kiem nay do truoc, va no noi
		# ro vi sao phep kiem ngay duoi khong ket luan duoc.
		var cao: Variant = _lua.run("""
			local A = g_CUIActivityMode
			local cao = 0
			for _, v in pairs(A.ChapterTypeDataList or {}) do
				local ok, g = A:getChapterDataWithDifficulty(A.nDifficulty1, v)
				if ok and g ~= nil then
					local c = tonumber(g.ChapterOpenNeedCharacterLevel) or 0
					if c > cao then cao = c end
				end
			end
			return tostring(cao)
		""", "cap cao nhat")
		_ghi_chu(int(str(cao)) <= 99,
				"loai doi cap cao nhat la %s <= 99 — nen o cap 99 khong loai nao bi cong cap do chan"
				% str(cao))
		var con_tip_cap: Array = []
		var toi_the := 0
		var da_mo: Array = []
		for t in the:
			if _mask_hien():
				_tat_tip()
			_lua.run("g_mocTip = {} return true", "xoa moc tip")
			var p: Vector2 = LuaRuntime._bien_doi(t) * (t.size * 0.5)
			var an := _lua.touch_at("Begin", p)
			var nhan: Node = _lua._dang_cham
			_lua.touch_at("End", p)
			_nha(CHO)
			# Chi xet cu cham NAO THUC SU toi the: the dau tien mo ra mot man khac thi
			# man do nam tren, cac cu cham sau bi no nhan thay — khong phai loi.
			if not (an and nhan != null and _la_the(nhan)):
				continue
			toi_the += 1
			var k := _doc_the()
			var tip3: String = k["tip"]
			var need3: String = k["need_cong"]
			if tip3 != "" and need3 != "" and need3 != "?" and tip3.contains(need3):
				con_tip_cap.append("loai %s: '%s'" % [k["loai"], tip3])
			var man3 := str(_lua.run("return tostring(g_CUINormalDlg:GetCurrentUIName())",
					"man"))
			var cay3 := _lop_theo_tag()
			var mo3: String = man3
			if cay3["hj_hien"]:
				mo3 += " + lop HJ (tag=2)"
			if cay3["common_hien"]:
				mo3 += " + lop thuong (tag=3)"
			if not da_mo.has(mo3):
				da_mo.append(mo3)
		_ghi_chu(toi_the >= 1, "co %d cu cham thuc su toi the (trong %d the)"
				% [toi_the, the.size()])
		_ghi_chu(con_tip_cap.is_empty(),
				"qua cap do roi thi khong the nao con ra tip ve CAP DO (con: %s)"
				% str(con_tip_cap))
		# In ra chu khong khang dinh: cai MO RA phu thuoc loai nao roi vao luot xoay
		# vong nay (do duoc: loai 5 -> lop thuong, loai 4 -> CUIActivityModeDetailInfo,
		# loai 9 -> CUIEpicChapter).
		print("  (mo ra: %s)" % str(da_mo))

	print("\ndat %d, hong %d" % [_dat, _hong])
	_xa_loi()
	_san.free()
	quit(1 if _hong > 0 else 0)


## Bao cao ve bang du lieu cua man, dung tu phia Lua. Mot luot Lua nhieu cau hoi
## de moi cau tra loi roi vao CUNG mot khung hinh.
func _doc_man() -> Dictionary:
	var r: Variant = _lua.run("""
		local A = g_CUIActivityMode
		local o = {}
		local function ghi(k, v) o[#o + 1] = k .. '=' .. tostring(v) end
		local function dem(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
		ghi('man', g_CUINormalDlg:GetCurrentUIName())
		ghi('canh', g_CSceneManager:GetCurrentSceneName())
		if A == nil then ghi('co_activity', 'khong') else ghi('co_activity', 'co') end
		ghi('cap_do', select(2, G_UserLogic:GetLevel()))
		ghi('so_loai', dem(A.ChapterTypeDataList))
		-- MOI con so o day doc tu CHINH ham ma cong dung (`getChapterDataWithDifficulty`,
		-- goi o `:1424`), KHONG doc `v[1]`. Ham do (`:764-805`) duyet het roi GIU MUC
		-- CUOI khop `ChapterDifficulty == nDifficulty`, nen `v[1]` la muc khac han.
		-- Do duoc: loai 5 co `[1]` doi cap 50 trong khi cong doc 22 — va tip tra ra
		-- dung so 22. Doc `[1]` la phep kiem do/xanh theo may, khong theo ma goc.
		local thap, loaidong, capdong = nil, '', ''
		local thieu_khoa, lech = false, 0
		for k, v in pairs(A.ChapterTypeDataList or {}) do
			if type(v) == 'table' and v[1] ~= nil then
				if v[1].ChapterKey == nil then thieu_khoa = true end
				for _, m in ipairs(v) do
					local c = tonumber(m.ChapterOpenNeedCharacterLevel) or 0
					if thap == nil or c < thap then thap = c end
				end
				local ok, g = A:getChapterDataWithDifficulty(A.nDifficulty1, v)
				if ok and g ~= nil then
					if tostring(g.ChapterOpenNeedCharacterLevel)
							~= tostring(v[1].ChapterOpenNeedCharacterLevel) then
						lech = lech + 1
					end
					if g.IsOpen == false and loaidong == '' then
						loaidong = tostring(k)
						capdong = tostring(g.ChapterOpenNeedCharacterLevel)
					end
				end
			else
				thieu_khoa = true
			end
		end
		ghi('cap_thap_nhat', thap or 0)
		ghi('so_lech', lech)
		ghi('loai_dong', loaidong)
		ghi('cap_cua_loai_dong', capdong)
		ghi('khoa_rong', thieu_khoa and 'co' or 'khong')
		return table.concat(o, '\\n')
	""", "doc man")
	return _tach(r, ["man", "canh", "co_activity", "cap_do", "so_loai",
			"cap_thap_nhat", "so_lech", "loai_dong", "cap_cua_loai_dong", "khoa_rong"])


## Trang thai sau mot cu cham vao the: loai nao duoc chon, bao nhieu ai, tip gi.
func _doc_the() -> Dictionary:
	var r: Variant = _lua.run("""
		local A = g_CUIActivityMode
		local o = {}
		local function ghi(k, v) o[#o + 1] = k .. '=' .. tostring(v) end
		local t = A.nSelectedChapterType
		ghi('loai', t == nil and 'nil' or t)
		local ds = (t ~= nil and t ~= 0) and A.ChapterTypeDataList[tostring(t)] or nil
		ghi('so_ai', type(ds) == 'table' and #ds or 0)
		-- So ma cong `:1438` thuc su so sanh: lay tu cung ham `:1424`, khong tu `[1]`.
		local ok, g = A:getChapterDataWithDifficulty(A.nDifficulty1, ds or {})
		ghi('need_cong', (ok and g ~= nil) and tostring(g.ChapterOpenNeedCharacterLevel) or '')
		ghi('isopen_cong', (ok and g ~= nil) and tostring(g.IsOpen) or '')
		local tip = ''
		if type(g_mocTip) == 'table' and #g_mocTip > 0 then tip = tostring(g_mocTip[1]) end
		ghi('tip', tip)
		return table.concat(o, '\\n')
	""", "doc the")
	return _tach(r, ["loai", "so_ai", "need_cong", "isopen_cong", "tip"])


## Hai lop do kho doc tu phia Lua.
func _doc_lop_lua() -> Dictionary:
	var r: Variant = _lua.run("""
		local A = g_CUIActivityMode
		local function co(n)
			if n == nil then return 'khong' end
			local ok = pcall(function() return n:getName() end)
			return ok and 'co' or 'khong'
		end
		return 'hj=' .. co(A.pHJDifficultyLayer)
			.. '\\ncommon=' .. co(A.pCommonDifficultyLayer)
	""", "doc lop lua")
	return _tach(r, ["hj", "common"])


## Chia ket qua Lua thanh Dictionary. Thieu khoa nao thi ghi '?' — de cau hoi sau
## khong no ra loi truy cap khoa, che mat loi that.
func _tach(r: Variant, khoa: Array) -> Dictionary:
	var d := {}
	for dong in str(r).split("\n"):
		var p := dong.split("=", true, 1)
		if p.size() == 2:
			d[p[0]] = p[1]
	for k in khoa:
		if not d.has(k):
			d[k] = "?"
	return d


## Hai lop do kho doc tu CAY GODOT: tim con theo meta `tag` cua `lActivityModeUI`,
## roi doc truong `visible` cua engine (khong qua phuong thuc cua Lua).
func _lop_theo_tag() -> Dictionary:
	var d := {
		"hj_tag": false, "common_tag": false,
		"hj_ten": "?", "common_ten": "?",
		"hj_o": "?", "common_o": "?",
		"hj_con": 0, "common_con": 0,
		"hj_hien": true, "common_hien": true,
	}
	var goc: Array = []
	_gom_ten(_san, "lActivityModeUI", goc)
	if goc.is_empty():
		return d
	for con in (goc[0] as Control).get_children():
		var cc: Control = con
		var tg := int(cc.get_meta("tag", -1))
		var o := "%dx%d" % [int(cc.size.x), int(cc.size.y)]
		if tg == 2:
			d["hj_tag"] = true
			d["hj_ten"] = String(cc.name)
			d["hj_o"] = o
			d["hj_con"] = cc.get_child_count()
			d["hj_hien"] = cc.visible
		elif tg == 3:
			d["common_tag"] = true
			d["common_ten"] = String(cc.name)
			d["common_o"] = o
			d["common_con"] = cc.get_child_count()
			d["common_hien"] = cc.visible
	return d


## Chi so (trong danh sach `the`) cua the ung voi mot loai hoat dong. Tra -1 neu
## khong the nao ra loai do. Moi cu cham deu de lai mot tip, ma tip thi nuot cu
## cham ke tiep — nen khi nao co tip thi phai gat no di truoc khi cham the sau.
func _the_cua_loai(loai: int) -> int:
	if _mask_hien():
		_tat_tip()
	var the := _tim(THE)
	for i in the.size():
		_lua.run("g_mocTip = {} return true", "xoa moc tip")
		_cham(the[i])
		_nha(CHO)
		if int(_doc_the()["loai"]) == loai:
			return i
		if _mask_hien():
			_tat_tip()
	return -1


## Cu cham co thuc su toi mot THE khong — node nhan cham la the, hay con cua the.
## Dung o nhom I: the dau tien mo ra mot man khac thi man do nam tren, cac cu cham
## sau bi no nhan thay; bo qua chu khong tinh thanh "the khong ra tip".
func _la_the(n: Node) -> bool:
	var cur: Node = n
	while cur != null:
		if cur is Control and cur.has_meta("touch") and String(cur.get_meta("touch")) == THE:
			return true
		cur = cur.get_parent()
	return false


## Node `lToolTipMask` dang co trong cay va dang hien khong.
func _mask_hien() -> bool:
	var ds: Array = []
	_gom_ten(_san, MASK, ds)
	for n in ds:
		if (n as Control).visible:
			return true
	return false


## Cham vao tam `lToolTipMask` de gat tip. Tra true neu sau do mask da an.
func _tat_tip() -> bool:
	var ds: Array = []
	_gom_ten(_san, MASK, ds)
	if ds.is_empty():
		return false
	_cham(ds[0])
	_nha(CHO)
	return not _mask_hien()


func _nha(so: int) -> void:
	for i in so:
		_lua.tick(KHUNG)


## Cham vao tam mot node bang dung duong cham cua ban goc (`touch_at` -> ten cham
## trong .xgg -> `onTouchEnd_<ten>` cua doi tuong nhan). Tra [toa do, ten node
## nhan] — goi thang ham thi bo qua dung cai phan dang nghi (node do co nhan cu
## cham khong).
func _cham(c: Control) -> Array:
	var p: Vector2 = LuaRuntime._bien_doi(c) * (c.size * 0.5)
	var an := _lua.touch_at("Begin", p)
	var nhan: Node = _lua._dang_cham
	_lua.touch_at("End", p)
	var ten := "KHONG AI NHAN"
	if an and nhan != null:
		ten = String(nhan.get_meta("xgg_name", nhan.get_meta("cls", nhan.name)))
	return [p.round(), ten]


## Node dang hien (ca chuoi cha) mang ten cham `ten`, theo thu tu cay.
func _tim(ten: String) -> Array:
	var ds: Array = []
	_gom(_san, ten, ds)
	return ds


func _gom(n: Node, ten: String, ds: Array) -> void:
	# Nhanh bi an thi bo ca nhanh — `lua_runtime.gd:_ung_vien` cung bo, nen node
	# dang an khong bao gio la ung vien that.
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control and n.has_meta("touch") and String(n.get_meta("touch")) == ten:
		ds.append(n)
	for c in n.get_children():
		_gom(c, ten, ds)


## Node mang meta `xgg_name` = `ten`, du dang an hay hien (lop do kho dang an nen
## `_gom` se bo qua chung).
func _gom_ten(n: Node, ten: String, ds: Array) -> void:
	if n is Control and String(n.get_meta("xgg_name", "")) == ten:
		ds.append(n)
	for c in n.get_children():
		_gom_ten(c, ten, ds)


## In ra moi loi Lua moi ke tu lan goi truoc — de mot doan Lua hong khong im lang
## bien thanh mot cau tra loi "?".
func _xa_loi() -> void:
	while _da_in < _lua.errors.size():
		print("   loi Lua: %s" % str(_lua.errors[_da_in]).substr(0, 200))
		_da_in += 1
