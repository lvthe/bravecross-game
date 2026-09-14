# Di duong chien dich cua ban goc tu canh Main, tung buoc, va DO xem no can
# gi: loi goi may chu nao da di, cai nao lop offline chua co handler, loi nao
# cua ma goc.
#
#   godot --headless --path . --script tools/do_chien_dich.gd
#
# Choi thu mot tran (co cua so, KHONG --headless): tu di toi luc tran bat dau
# roi giao cho nguoi choi — bam nut linh, nut thuc tinh, xem man ket thuc:
#
#   godot --path . --script tools/do_chien_dich.gd -- --xem
#
# Moi buoc goi DUNG ham ma nut goi (nhu vao_main.gd lam voi Login):
#   nut tan cong o Main   CUIMain:onTouchEnd_btnMainExtraUIAttack (CUIMain.lua:2778)
#     -> Show(SelectLevel)
#   bam mot ai            CUISelectLevel:onTouchEnd_OnSelectLevel -> GoNextCallback
#     -> Show("ChapterInfo")                                    (CUISelectLevel.lua:1304)
#   bam "Di"              CUIChapterInfo:onTouchEnd_OnGo        (CUIChapterInfo.lua:2581)
#   bam tan cong          CUIBattleDeploy:onTouchEnd_OnChapterListAttack (:2828)
#     -> enterBattle -> SetChapterBegin -> G_ChapterLogic:ChapterBegin
#     -> CallServer ClientChapterBegin -> OnServerChapterBegin -> RepaleceScene("Battle")
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0

## [ten buoc, viec lam (Lua), so khung cho sau do]
const BUOC := [
	# Hinh dang du lieu ma handler ClientChapterBegin / Complete phai dung:
	# truong cau hinh ai (ChapterEx lay tu dau), cau hinh NPC, va doi tuong
	# giu du lieu nguoi choi (de chep nguoc ve kho offline).
	["xem cau hinh ai L_N_01_01",
		"""local o = {}
		for k, v in pairs(G_ConfigManager:GetChapterConfig('L_N_01_01') or {}) do
			o[#o + 1] = k .. '=' .. (type(v) == 'table' and ('{' .. #v .. '}') or tostring(v))
		end
		table.sort(o)
		local n = {}
		for k, v in pairs(G_ConfigManager:GetChapterNpcConfig('L_N_01_01') or {}) do
			n[#n + 1] = tostring(k) .. ':' .. type(v)
		end
		table.sort(n)
		local dm = rawget(_G, 'G_DataManager')
		return 'CFG ' .. table.concat(o, ' ') .. ' || NPC ' .. table.concat(n, ' ')
			.. ' || G_DataManager ' .. tostring(dm ~= nil and type(dm.userData))""", 1],
	["mo man chon ai",
		"g_CUINormalDlg:Show(g_CUISelectLevel:GetUIName(), {}) return true", 90],
	["chon ai (mac dinh: dau tien dang mo; AI_CHON: dung ten do)",
		"""local L = g_CUISelectLevel
		local ds = {}
		local chon = rawget(_G, 'AI_CHON')
		for i, v in ipairs(L.tChapterData or {}) do
			ds[#ds + 1] = tostring(v.ChapterKey) .. '=' .. tostring(v.BattleStatus)
			if chon ~= nil and chon ~= '' then
				if tostring(v.ChapterKey) == tostring(chon) and v.BattleStatus ~= 0 then
					L.nSubChapter = i
				end
			elseif v.BattleStatus ~= 0 and L.nSubChapter == nil then
				L.nSubChapter = i
			end
		end
		if L.nSubChapter == nil then
			return 'khong mo duoc ai (' .. tostring(chon or 'dau') .. '); ds: ' .. table.concat(ds, ' ')
		end
		L:GoNextCallback()
		return 'chon ' .. tostring(L.tChapterData[L.nSubChapter].ChapterKey) .. ' | ds: ' .. table.concat(ds, ' ')""", 60],
	["bam 'Di'",
		"g_CUIChapterInfo:onTouchEnd_OnGo(nil, true) return true", 90],
	# Nguoi choi moi chua co danh sach xuat tran (GetFightHeroListByType ra
	# rong) nen InitDefaultHeroSprite khong xep san ai: nguoi choi bam vao
	# tuong. Goi y het cach InitDefaultHeroSprite goi (CUIBattleDeploy.lua
	# :2803-2819): getItemByHeroID roi OnTouchAllHerosEnd(item, tuong, true).
	["xep tuong dang mo vao doi",
		"""local D = g_CUIBattleDeploy
		-- Dung danh sach tuong da mo (D.tAllUnlockHerosData) chi day khi man bo
		-- tri go tab chon tuong (refreshHerosScrollLayerUI, CUIBattleDeploy:1746).
		-- Cong cu khong bam tab do nen phai goi tay, khong thi danh sach rong va
		-- tuong chieu mo khong len duoc doi.
		pcall(function() D:refreshHerosScrollLayerUI(1) end)
		local n = 0
		for _, h in ipairs(D.tAllUnlockHerosData or {}) do
			if h.UserHeroID == nil and type(h[1]) == 'table' then h = h[1] end
			local _, it = D:getItemByHeroID(h.UserHeroID)
			local _, du_lieu = G_HeroLogic:GetHeroWithID(h.UserHeroID)
			D:OnTouchAllHerosEnd(it, du_lieu, true)
			n = n + 1
			if n >= 5 then break end
		end
		return n""", 30],
	# Dung ngay khi tran co hinh bat dau: con kip dua linh ra truoc khi tran xong.
	["bam tan cong",
		"g_CUIBattleDeploy:onTouchEnd_OnChapterListAttack(nil, true) return true", 300,
		"return require('cocos').tran_nut ~= nil"],
	# Dua linh ra tran bang DUNG DUONG cua ban goc: CUIGame:TouchArrmy(n) ->
	# tArmyIcons[n]:dispatch() (CUIGame.lua:4055); nguoi choi bam nut thi
	# engine goi cung dispatch do. Ba lan: Troop_1 ton 3 thong soai, co 6 ->
	# hai toan x4 nguoi, lan thu ba phai bi tu choi.
	["dua linh ra tran",
		"""local bf = g_BattleField
		local nut = require('cocos').tran_nut
		local q0 = nut:so_quan()
		local l0 = bf:_thong_soai()
		g_CUIGame:TouchArrmy(1)
		g_CUIGame:TouchArrmy(1)
		g_CUIGame:TouchArrmy(1)
		local q1 = nut:so_quan()
		local l1, lm = bf:_thong_soai()
		nk.dua = { q0, q1, l0, l1, lm }
		return 'quan ' .. q0 .. ' -> ' .. q1 .. ', thong soai ' .. tostring(l0) .. ' -> '
			.. tostring(l1) .. ' / ' .. tostring(lm)""", 1],
	# Canh Battle: g_BattleField la node CCLayer trong BattleField_<canh>
	# _960_640.xgg (nap vao g_BattleFieldLayer); tran thi engine C++ danh.
	["trong canh Battle",
		"""local bf = rawget(_G, 'g_BattleField')
		local G = g_CUIGame
		return 'g_BattleField=' .. tostring(bf ~= nil)
			.. ' g_BattleFieldLayer=' .. tostring(rawget(_G, 'g_BattleFieldLayer') ~= nil)
			.. ' g_MapZero=' .. tostring(rawget(_G, 'g_MapZero') ~= nil)
			.. ' ChapterObj=' .. tostring(G.ChapterObj ~= nil)
			.. ' ai=' .. tostring(G.tChapterInfo and G.tChapterInfo.ChapterKey)
			.. ' nArmysNum=' .. tostring(G.nArmysNum)
			.. ' bGameFinish=' .. tostring(G.bGameFinish)
			.. ' onEnter=' .. tostring(G.bOnMainUI)
			.. ' isLoading=' .. tostring(g_CSceneManager.isLoading)
			-- Loi cua coroutine doi canh (CSceneManager.lua:500, :533) chi bi
			-- in ra; _NAP cua vao_main.gd gom loi chet vao loi_chet.
			.. ' || loi_chet: ' .. table.concat(loi_chet or {}, ' ## '):sub(1, 1500)""", 30],
	# Hinh du lieu ma engine nhan qua setSendTroops / setLevelData
	# (CUIGame.lua:924-925, cjson.encode) — g_BattleField gia phai doc dung no.
	["du lieu tran (quan ta / quan dich)",
		"""local G = g_CUIGame
		local function khoa(t, sau)
			if type(t) ~= 'table' then return tostring(t) end
			local o = {}
			for k, v in pairs(t) do
				if type(v) == 'table' and sau > 0 then
					o[#o + 1] = tostring(k) .. '{' .. khoa(v, sau - 1) .. '}'
				else
					o[#o + 1] = tostring(k) .. '=' .. tostring(v):sub(1, 24)
				end
			end
			table.sort(o)
			return table.concat(o, ' ')
		end
		return 'QUAN TA: ' .. khoa(G.tArmysData, 3):sub(1, 2500)
			.. ' || QUAN DICH: ' .. khoa(G.tLevelData, 3):sub(1, 2500)
			.. ' || SOLDIERS TA: ' .. khoa(G.tArmysData and G.tArmysData.Sprite
				and G.tArmysData.Sprite.Troop, 3):sub(1, 1200)
			.. ' || GROUPS DICH: ' .. khoa(G.tLevelData and G.tLevelData.Groups, 3):sub(1, 2500)
			-- Thong soai (dua linh ra tran): con so engine nhan.
			.. ' || THONG SOAI: LeaderShip=' .. tostring(G.tArmysData.Sprite.Chapter.LeaderShip)
			.. ' LeaderShipResume=' .. tostring(G.tArmysData.Sprite.Chapter.LeaderShipResume)
			.. ' ArmyList{' .. khoa(G.tArmysData.Sprite.ArmyList, 1) .. '}'
			.. ' Troop_1.BaseInfo{' .. khoa(G.tArmysData.Sprite.Troop_1 and G.tArmysData.Sprite.Troop_1.BaseInfo, 2) .. '}'
			.. ' Troop_1{Name=' .. tostring(G.tArmysData.Sprite.Troop_1 and G.tArmysData.Sprite.Troop_1.Name)
			.. ' HP=' .. tostring(G.tArmysData.Sprite.Troop_1 and G.tArmysData.Sprite.Troop_1.HP)
			.. ' Location=' .. tostring(G.tArmysData.Sprite.Troop_1 and G.tArmysData.Sprite.Troop_1.Location)
			.. ' IsLocked=' .. tostring(G.tArmysData.Sprite.Troop_1 and G.tArmysData.Sprite.Troop_1.IsLocked) .. '}'
			-- Thuc tinh: du lieu ky nang cua tuong ma engine nhan.
			.. ' || THUC TINH Hero_25: WakeSkill=' .. tostring(G.tArmysData.Sprite.Hero_25.WakeSkill)
			.. ' AngerRecovery=' .. tostring(G.tArmysData.Sprite.Hero_25.AngerRecovery)
			.. ' AttackAwakening=' .. tostring(G.tArmysData.Sprite.Hero_25.AttackAwakening)
			.. ' GethitAwakening=' .. tostring(G.tArmysData.Sprite.Hero_25.GethitAwakening)
			.. ' SkillInjuryRates=' .. tostring(G.tArmysData.Sprite.Hero_25.SkillInjuryRates)
			.. ' SkillInjuryTimer=' .. tostring(G.tArmysData.Sprite.Hero_25.SkillInjuryTimer)
			.. ' Skills{' .. khoa(G.tArmysData.Sprite.Hero_25.Skills, 4) .. '}'""", 1],
	# g_BattleField gia (lua/san_tran.lua) bao ket qua sau thoi gian tran (toi
	# da vai giay), roi chuoi cua ban goc: GameFinish -> OnEnd ->
	# ClientChapterComplete* -> man ket thuc.
	# Tran co hinh chay theo thoi gian that: cho toi khi co ket qua (toi da
	# 300 giay tran = ChapterGameTime), roi them chut cho may chu va man ket
	# thuc. Phan tu thu tu la dieu kien Lua de ngung cho.
	["cho tran xong", "return 'cho'", 9000, "return require('cocos').tran_cuoi ~= nil"],
	["sau tran",
		"""local o = {}
		local r = require('cocos').tran_cuoi
		o[#o + 1] = r and string.format('tran: thang=%s giay=%.1f song=%s loi=%s',
			tostring(r.thang), tonumber(r.giay) or 0, tostring(r.song), tostring(r.loi)) or 'tran: chua danh'
		local function lay(f)
			local ok, a, b = pcall(f)
			return tostring(ok and (b ~= nil and b or a))
		end
		o[#o + 1] = 'vang=' .. lay(function() return G_UserLogic:GetGold() end)
		o[#o + 1] = 'the luc=' .. lay(function() return G_UserLogic:GetFatigueValue() end)
		o[#o + 1] = 'cap=' .. lay(function() return G_UserLogic:GetLevel() end)
		local okr, _, bc = pcall(function() return G_ChapterLogic:GetBattleReportsData('L_N_01_01') end)
		o[#o + 1] = 'chien bao=' .. ((okr and type(bc) == 'table')
			and ('BattleStatus ' .. tostring(bc.BattleStatus) .. ' PassMissionCount ' .. tostring(bc.PassMissionCount))
			or 'nil')
		local kho = OfflineStore.data and OfflineStore.data.GameUserBaseInfo
		o[#o + 1] = 'kho: vang=' .. tostring(kho and kho.Gold) .. ' the luc=' .. tostring(kho and kho.FatigueValue)
		local okm, ten = pcall(function() return g_CUIBattleDlg:GetCurrentUIName() end)
		o[#o + 1] = 'man=' .. tostring(okm and ten)
		o[#o + 1] = 'bGameFinish=' .. tostring(g_CUIGame.bGameFinish)
			.. ' bAutoRun=' .. tostring(g_CUITestAutoRun and g_CUITestAutoRun.bAutoRun)
		o[#o + 1] = 'nhat ky san tran: ' .. table.concat(require('cocos').nhat_ky_tran or {}, ' > ')
		return table.concat(o, ' | ')""", 30],
]


func _init() -> void:
	var lua := LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			_chup = a.substr(7)
		elif a.begins_with("--khung="):
			_khung_chup = maxi(1, int(a.substr(8)))
		elif a == "--xem":
			_xem = true
		elif a.begins_with("--thoat="):
			_thoat = int(a.substr(8))
		elif a.begins_with("--ai="):
			_ai = a.substr(5)
		elif a == "--giu":
			_giu = true
		elif a.begins_with("--chieu-mo="):
			_chieu_mo = maxi(0, int(a.substr(11)))
	var san := Control.new()
	san.size = lua.cua_so_engine
	san.scale = Vector2.ONE * (vp.y / lua.cua_so_engine.y)
	lua.set_stage(san)
	lua.set_touch_root(san)
	# --giu: giu ban luu (khong xoa) de thu tien trinh chien dich qua nhieu ai.
	# Phai dat TRUOC _NAP vi _CHUAN_BI (trong _NAP) doc co nay de bo qua wipe.
	if _giu:
		lua.run("GIU_SAVE = true", "giu ban luu")
	if lua.run(VM._NAP, "nap") == null:
		print("nap hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	var d := VM.chay(lua)
	if str(d["dung"]) != "":
		print("KHONG toi duoc Main, dung o: %s" % d["dung"])
		quit(1)
		return
	print("toi Main.")
	lua.run(_BAT, "bat nhat ky")
	var da_in := lua.errors.size()
	# --kiem: tu kiem ca chuoi (check.py goi). Gom moi loi goi may chu va moi
	# dong nhat ky offline qua cac buoc de xet o cuoi.
	var kiem := "--kiem" in OS.get_cmdline_user_args() or "--kiem" in OS.get_cmdline_args()
	# --kichban: bat co cho kich ban tran chay (san_tran doc G_KICHBAN), roi do
	# rieng chuoi thoai. Bat TRUOC khi vao tran (bam tan cong goi _Lua_StartGame).
	var kichban := "--kichban" in OS.get_cmdline_user_args() or "--kichban" in OS.get_cmdline_args()
	# Choi thu (--xem) chay CA kich ban: nguoi choi xem thoai, dong minh nhap
	# tran, boss rut -> trai nghiem tron ai 1 thang duoc. --kiem KHONG bat (giu
	# 16/16 vi kich ban an nut / dung tran, dap len phep kiem dua linh).
	if kichban:
		lua.run("G_KICHBAN = true", "bat kich ban")
	# --ai=KEY: chon dung ai do o man chon ai (mac dinh: ai dau tien dang mo).
	if _ai != "":
		lua.run("AI_CHON = '%s'" % _ai, "chon ai")
	# --chieu-mo=N: rut N lan bang vang (them vang truoc cho du) de co kho tuong
	# roi dua vao doi hinh — thu chuoi 'chieu mo -> len doi hinh -> thang ai sau'.
	if _chieu_mo > 0:
		lua.run("G_UserLogic:AddGold(%d, 'test')" % (_chieu_mo * 40000 + 100000), "them vang")
		var so_tuong0 := int(lua.run(_DEM_TUONG, "dem tuong truoc"))
		for i in _chieu_mo:
			lua.run("G_LotteryLogic:ServerPlayLottery(LOTTERY_TYPE.GOLD_ONCE, false)", "chieu mo")
			lua.tick(KHUNG)
		var so_tuong1 := int(lua.run(_DEM_TUONG, "dem tuong sau"))
		print("chieu mo %d lan: kho tuong %d -> %d" % [_chieu_mo, so_tuong0, so_tuong1])
	var may_chu := ""
	var offline := ""
	var canh_sau_tan_cong := ""
	for b in BUOC:
		print("\n== %s" % b[0])
		var r = lua.run("local ok, v = pcall(function() %s end) return tostring(ok) .. ' ' .. tostring(v)" % b[1], b[0])
		print("  ket qua: %s" % str(r))
		var cho_den := String(b[3]) if b.size() > 3 else ""
		# --chup: dung ngay khi tran co hinh vua bat dau (trong buoc tan cong)
		# de chup GIUA tran, khong phai luc da xong.
		if (_chup != "" or _xem) and b[0] == "bam tan cong":
			cho_den = "return require('cocos').tran_nut ~= nil"
		for i in range(int(b[2])):
			lua.tick(KHUNG)
			if cho_den != "" and i % 30 == 29 and lua.run(cho_den, "cho") == true:
				print("  (xong sau %d khung)" % (i + 1))
				for k in 90:
					lua.tick(KHUNG)
				break
		var bao = lua.run(_RUT, "rut")
		if bao != null:
			for k in bao:
				print("  %-10s %s" % [k, bao[k]])
				if str(k) == "may chu":
					may_chu += " " + str(bao[k])
				elif str(k).begins_with("offline"):
					offline += " | " + str(bao[k])
			if b[0] == "bam tan cong":
				canh_sau_tan_cong = str(bao.get("canh", ""))
		# --xem: tran vua bat dau thi giao cho nguoi choi. Cua so giu nguyen,
		# chuot di vao ma goc qua touch() — y nhu vao_main.gd --xem.
		if _xem and b[0] == "bam tan cong":
			_lua = lua
			_san = san
			_da_in_xem = lua.errors.size()
			root.add_child(san)
			root.window_input.connect(func(e: InputEvent):
				lua.touch(e.xformed_by(root.get_final_transform().affine_inverse())))
			print("\ndang mo tran — bam nut linh (duoi giua), nut thuc tinh (duoi trai),"
					+ " dong cua so de thoat")
			return
		# --kichban: tran da bat dau (kich ban tu chay khi G_KICHBAN bat). Buoc
		# them nhieu khung de kich ban dien het (thoai tu di tiep), roi do thoai.
		if kichban and b[0] == "bam tan cong":
			for i in 3000:
				lua.tick(KHUNG)
				# Nguoi choi cung dua linh nhu binh thuong: du 3 thong soai thi bam.
				# Cong dong minh kich ban + boss bi rut -> ben ta don sach.
				if i % 30 == 15 and int(lua.run("return (g_BattleField:_thong_soai())", "ts")) >= 3:
					lua.run("g_CUIGame:TouchArrmy(1)", "dua linh")
				# Nguoi choi that con BAM THUC TINH khi no day — day la mot phan cua cach
				# thang ai 1 chu khong phai meo cua bo do. Bam bang DUONG THAT: cham
				# vao nut tren thanh ky nang cua CUIGame.
				if i % 30 == 25 and str(lua.run(_NO_TUONG, "no")).contains("\"day\":true"):
					var nt = lua.run("return require('cocos').raw(g_CUIGame.tSkillIcons[1])", "nut tt")
					if nt is Control:
						var ct: Control = nt
						var pt: Vector2 = LuaRuntime._bien_doi(ct) * (ct.size * 0.5)
						lua.touch_at("Begin", pt)
						lua.touch_at("End", pt)
				if i > 60 and lua.run("local k=g_DramaSystem return not (k and k.dang_chay and k:dang_chay())", "xong kb") == true:
					print("  (kich ban het sau %d khung)" % (i + 1))
					break
			var kb = lua.run(_KICH_BAN, "do kich ban")
			var so := int(kb.get("so", 0)) if kb != null else 0
			var loikb := str(kb.get("loi", "?")) if kb != null else "khong doc duoc"
			print("  so thoai: %d" % so)
			print("  chuoi thoai: %s" % (str(kb.get("thoai", "")) if kb != null else ""))
			print("  nhat ky kich ban: %s" % (str(kb.get("nk", "")) if kb != null else ""))
			print("  loi kich ban: %s" % loikb)
			# Dong minh nhap tran chua (JoinBattle trong nhat ky), va tran ket
			# thuc ra sao: kich ban keo boss ra thi ben ta don sach -> thang.
			print("  quan luc kich ban xong: %s" % str(lua.run("return require('cocos').tran_nut:ds_quan()", "ds")))
			var co_dong_minh := str(kb.get("nk", "")).contains("JoinBattle")
			for i in 9000:
				lua.tick(KHUNG)
				if i % 30 == 29 and lua.run("return require('cocos').tran_cuoi ~= nil", "cho") == true:
					break
			var tc = lua.run(_KB_TRAN, "tran cuoi")
			var thang := str(tc.get("thang", "?")) if tc != null else "?"
			print("  dong minh nhap tran: %s | tran: thang=%s (%s)" % [co_dong_minh, thang,
					str(tc.get("chi_tiet", "")) if tc != null else ""])
			# Dat khi: kich ban dien het (thoai, khong loi), dong minh nhap tran, ai
			# thang duoc (boss bi rut + linh + dong minh don sach), VA moi lenh canh
			# dien anh deu toi duoc san tran.
			var nk := str(kb.get("nk", "")) if kb != null else ""
			# Goi thang cac lenh dien anh de khoa duong di cua chung. Ten hieu ung /
			# mat la THAT: bien the cua armature DramaDialog va Face, doc tu chinh
			# sc/plot/drama_*.lua.
			var da: String = str(lua.run("""
				local t = require('cocos').tran_nut
				local a = t:hieu_ung_tai_o('DramaDialog_SmokeWhite', 10, 0, 'PluginPlay', 3)
				t:phu_mau(0, 0.5, 1)
				t:rung_man(3, 0.5)
				return tostring(a) .. ' | ' .. t:do_dien_anh()
			""", "dien anh"))
			print("  dien anh: %s" % da)
			var dskb := [
				["kich ban dien het thoai", so > 0, str(so)],
				["kich ban khong loi", loikb == "nil", loikb],
				["dong minh nhap tran", co_dong_minh, nk.substr(0, 80)],
				["ai 1 thang duoc dung cach ban goc", thang == "true", thang],
				["duong di: MoveThenDoAction toi san tran", nk.contains("MoveThenDo"), nk],
				["dong tac: DoAction toi san tran", nk.contains("DoAction"), nk],
				["lenh trang thai tran duoc ghi (SetArmyWaiting)", nk.contains("SetArmyWaiting"), nk],
				["hieu ung ban do dung armature that (DramaDialog_SmokeWhite)",
						da.begins_with("true"), da],
				["lop phu mau va rung man dang chay", da.contains("phu ") and
						not da.ends_with("rung 0.00"), da],
			]
			var dat := 0
			for e in dskb:
				if bool(e[1]):
					dat += 1
					print("  dat   %s" % e[0])
				else:
					print("  HONG: %s  (%s)" % [e[0], e[2]])
			print("
dat %d, hong %d" % [dat, dskb.size() - dat])
			san.free()
			quit(0 if dat == dskb.size() else 1)
			return
		# --kiem: BAM THAT vao nut binh chung (touch_at -> ten cham DuaLinh ->
		# dispatch), khong qua TouchArrmy. Cho thong soai hoi du 3 roi bam tam nut.
		if kiem and b[0] == "dua linh ra tran":
			# Thuc tinh TRUOC: luc tuong ta con song.
			_bam_tt = _bam_thuc_tinh(lua)
			print("  bam that vao nut thuc tinh: %s" % _bam_tt)
			_bam_nut = _bam_nut_linh(lua)
			print("  bam that vao nut: %s" % _bam_nut)
			# Camera: bam mot quan dau gia o x = 3000 (30 o) trong 20 giay.
			_cam_thu = str(lua.run("return require('cocos').tran_nut:_thu_camera(3000, 20)", "thu camera"))
			print("  camera sau 20 giay bam x=3000: %s" % _cam_thu)
		# --chup=<png>: chup GIUA TRAN. Phai chay khong --headless; san khau gan
		# vao cua so, roi _process buoc Lua va chup sau vai giay.
		if _chup != "" and b[0] == "dua linh ra tran":
			print("  khung san: %s" % str(lua.run("return require('cocos').tran_nut:khung()", "khung")))
			# Cho nut thuc tinh sang trong anh (dat no bang tay, xem _bam_thuc_tinh).
			lua.run("require('cocos').tran_nut:_dat_no(25, 100)", "dat no")
			# --cam=X: cho camera bam quan dau gia o x truoc khi chup, de thay nen
			# troi theo parallax (o L_N_01_01 quan ta it khi di qua 0,8 man).
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--cam="):
					print("  camera: %s" % str(lua.run(
							"return require('cocos').tran_nut:_thu_camera(%s, 20)" % a.substr(6), "cam")))
			_lua = lua
			_san = san
			root.add_child(san)
			return
		while da_in < lua.errors.size():
			print("  loi Lua  %s" % str(lua.errors[da_in]).substr(0, 400))
			da_in += 1
	# Ham Cocos / g_BattleField ma ma goc goi nhung lop gia lap chua lam —
	# danh sach viec cua buoc dung tran.
	var miss := lua.missing()
	var mk := []
	for k in miss:
		mk.append([int(miss[k]), String(k)])
	mk.sort_custom(func(a, b): return a[0] > b[0])
	print("\n  API chua lam (%d loai):" % mk.size())
	for e in mk.slice(0, 40):
		print("      %-40s x%d" % [e[1], e[0]])
	var bad := 0
	if kiem:
		bad = _kiem(lua, may_chu, offline, canh_sau_tan_cong, miss)
	san.free()
	quit(1 if bad > 0 else 0)


var _chup := ""
var _khung_chup := 90          ## --khung=N: chup o khung thu N sau khi dua linh
var _cam_thu := ""             ## camera() sau _thu_camera — xem _kiem
var _xem := false              ## --xem: giao tran cho nguoi choi
var _thoat := 0                ## --thoat=N: thoat sau N khung (de kiem --xem)
var _ai := ""                  ## --ai=KEY: chon dung ai do (mac dinh ai dau mo)
var _giu := false              ## --giu: giu ban luu (khong wipe) de thu tien trinh
var _chieu_mo := 0             ## --chieu-mo=N: rut N tuong truoc khi vao chien dich
const _DEM_TUONG := "local ok,m=pcall(function() return select(2, G_DataManager:GetUserDataWithName('GameUserHero')) end) local c=0 if type(m)=='table' then for _ in pairs(m) do c=c+1 end end return c"
var _da_in_xem := 0
var _lua: LuaRuntime = null
var _san: Control = null
var _dem := 0
var _bam_nut := ""
var _bam_tt := ""


## Cho tuong ta DAY NO, bam that vao tam nut thuc tinh dau tien, roi cho don ky
## nang. Tra "day A tung B->C": A = so khung cho day no tu nhien, 0 neu phai
## dat no bang tay (_dat_no), -1 neu khong co tuong nao.
const _NO_TUONG := "local ok, s = pcall(function() return require('cocos').tran_nut:no_tuong() end) return ok and s or ''"


func _bam_thuc_tinh(lua: LuaRuntime) -> String:
	const NO := "local ok, s = pcall(function() return require('cocos').tran_nut:no_tuong() end) return ok and s or ''"
	# Cho NGAN: o L_N_01_01, voi mo hinh cua ta, tuong ta chet truoc khi du 4
	# don de day no (do duoc: sau 450 khung no_tuong ra "song":false). Nen dat
	# no bang tay LUC TUONG CON SONG de van kiem duoc duong nut.
	var day := -1
	var s := ""
	for i in 30:
		lua.tick(KHUNG)
		if i % 15 == 14:
			s = str(lua.run(NO, "no"))
			if s.contains("\"day\":true"):
				day = i + 1
				break
	if day < 0:
		print("  no chua day sau 30 khung (no_tuong=%s) — dat no bang tay" % s)
		var id := int(lua.run("return g_CUIGame.tSkillIcons and require('cocos').raw(g_CUIGame.tSkillIcons[1]):get_meta('tt_id', 0) or 0", "id tuong"))
		if id == 0 or lua.run("return require('cocos').tran_nut:_dat_no(%d, 100)" % id, "dat no") != true:
			return "day -1 tung 0->0"
		day = 0
		for i in 3:
			lua.tick(KHUNG)
	else:
		print("  no tu nhien day sau %d khung" % day)
	var nut = lua.run("return require('cocos').raw(g_CUIGame.tSkillIcons[1])", "nut thuc tinh")
	if not (nut is Control):
		return "khong co nut thuc tinh"
	var c: Control = nut
	var p: Vector2 = LuaRuntime._bien_doi(c) * (c.size * 0.5)
	var t0 := int(lua.run("return require('cocos').tran_nut:so_thuc_tinh()", "tt"))
	lua.touch_at("Begin", p)
	lua.touch_at("End", p)
	var t1 := t0
	for i in 300:
		lua.tick(KHUNG)
		t1 = int(lua.run("return require('cocos').tran_nut:so_thuc_tinh()", "tt"))
		if t1 > t0:
			break
	return "day %d tung %d->%d" % [day, t0, t1]


## Bam that vao tam nut binh chung dau tien. Tra "quan X->Y thong soai A->B".
## Diem cham theo cung he voi LuaRuntime._bien_doi — xem verify_cham.gd.
func _bam_nut_linh(lua: LuaRuntime) -> String:
	for i in 600:
		if int(lua.run("return (g_BattleField:_thong_soai())", "thong soai")) >= 3:
			break
		lua.tick(KHUNG)
	var nut = lua.run("return require('cocos').raw(g_CUIGame.tArmyIcons[1])", "nut linh")
	if not (nut is Control):
		return "khong co nut"
	var c: Control = nut
	var p: Vector2 = LuaRuntime._bien_doi(c) * (c.size * 0.5)
	var q0 := int(lua.run("return require('cocos').tran_nut:so_quan()", "so quan"))
	var l0 := int(lua.run("return (g_BattleField:_thong_soai())", "thong soai"))
	lua.touch_at("Begin", p)
	lua.touch_at("End", p)
	var q1 := int(lua.run("return require('cocos').tran_nut:so_quan()", "so quan"))
	var l1 := int(lua.run("return (g_BattleField:_thong_soai())", "thong soai"))
	return "quan %d->%d thong soai %d->%d" % [q0, q1, l0, l1]


## Luc chup: cai gi dang tren san khau. Node toi do sau 3 (hien THAT — ca
## chuoi cha — va o tren man), sau hon thi chi ColorRect dang hien, gan duc,
## rong hon 400 px: lop che phu kin man. Kem o cua nut tran va mot quan.
func _ta_san() -> void:
	print("  san: size %s scale %s, %d con" % [_san.size, _san.scale, _san.get_child_count()])
	var ds: Array = [[_san, 0]]
	var in_ra := 0
	while not ds.is_empty() and in_ra < 120:
		var p: Array = ds.pop_back()
		var n: Node = p[0]
		var d: int = p[1]
		for ch in n.get_children():
			ds.append([ch, d + 1])
		if not (n is Control) or n == _san:
			continue
		var c: Control = n
		var hien := _hien_that(c)
		var lop_che := c is ColorRect and hien and (c as ColorRect).color.a > 0.5 and c.size.x > 400.0
		if d > 3 and not lop_che:
			continue
		var o := LuaRuntime._bien_doi(c) * Rect2(Vector2.ZERO, c.size)
		var mau := (" mau %s" % (c as ColorRect).color) if c is ColorRect else ""
		print("  %s%s [%s] hien=%s o=%s%s" % ["  ".repeat(mini(d, 6)),
				String(c.get_meta("xgg_name", c.name)), c.get_class(), hien, o, mau])
		in_ra += 1
	var nut = _lua.run("return require('cocos').tran_nut", "nut tran")
	if nut is Node2D:
		var t: Node2D = nut
		print("  nut tran: hien=%s goc tren man=%s, %d con" % [_hien_that(t),
				LuaRuntime._bien_doi(t) * Vector2.ZERO, t.get_child_count()])
		if t.get_child_count() > 0:
			var u: Node2D = t.get_child(0)
			print("  quan dau: o tren man=%s" % (LuaRuntime._bien_doi(t) * u.position))
		print("  quan luc chup: %s" % str(t.call("ds_quan")))
	# Nut thuc tinh: lop chua va tung nut (hien THAT, o tren man, ti le).
	for ten in ["lGameUIWakeSkill", "lBattleSkill"]:
		var n = _lua.run("local n = rawget(_G, '%s') return n and require('cocos').raw(n)" % ten, ten)
		if n is Control:
			var c: Control = n
			print("  %s: hien=%s o=%s scale=%s con=%d" % [ten, _hien_that(c),
					LuaRuntime._bien_doi(c) * Rect2(Vector2.ZERO, c.size), c.scale, c.get_child_count()])
	for i in range(1, 6):
		var n = _lua.run("local t = g_CUIGame.tSkillIcons return t and t[%d] and require('cocos').raw(t[%d])" % [i, i], "nut tt")
		if n is Control:
			var c: Control = n
			print("  nut thuc tinh %d: hien=%s (tu no %s) o=%s scale=%s cha=%s" % [i, _hien_that(c),
					c.visible, LuaRuntime._bien_doi(c) * Rect2(Vector2.ZERO, c.size), c.scale,
					String(c.get_parent().get_meta("xgg_name", c.get_parent().name)) if c.get_parent() else "-"])


static func _hien_that(n: Node) -> bool:
	var p := n
	while p != null:
		if p is CanvasItem and not (p as CanvasItem).visible:
			return false
		p = p.get_parent()
	return true


func _process(dt: float) -> bool:
	if _lua == null:
		return false
	_lua.tick(dt)
	_dem += 1
	if _xem:
		# Loi Lua moi (bam nut ma ma goc hong) in ra ngay de con biet.
		while _da_in_xem < _lua.errors.size():
			print("  loi Lua: %s" % str(_lua.errors[_da_in_xem]).substr(0, 400))
			_da_in_xem += 1
		if _thoat > 0 and _dem >= _thoat:
			quit(0)
		return false
	if _dem == _khung_chup:
		_ta_san()
		print("  camera: %s" % str(_lua.run("return require('cocos').tran_nut:camera()", "camera")))
		var img := root.get_texture().get_image()
		img.save_png(_chup)
		print("da chup %s (%dx%d)" % [_chup, img.get_width(), img.get_height()])
		quit(0)
	return false


## Kiem ca chuoi chien dich cua ban goc, tu nut tan cong o Main toi man ket
## thuc. In "dat X, hong Y" (check.py doc dong nay).
func _kiem(lua: LuaRuntime, may_chu: String, offline: String, canh: String,
		miss: Dictionary) -> int:
	var ok := 0
	var bad := 0
	var cuoi = lua.run(_TRANG_THAI_CUOI, "trang thai cuoi")
	var ds := [
		["bam tan cong doi sang canh Battle", canh == "Battle", canh],
		["di qua ClientChapterBegin", may_chu.contains("ClientChapterBegin"), may_chu],
		["het tran goi ClientChapterComplete*", may_chu.contains("ClientChapterComplete"), may_chu],
		["handler chien dich khong thieu", not offline.contains("THIEU G_ChapterLogic.ClientChapter"),
				offline.substr(0, 200)],
		["handler chien dich khong loi", not offline.contains("handler ClientChapter"),
				offline.substr(0, 200)],
		["g_BattleField gia du ham (khong con _Lua_StartGame trong API thieu)",
				not miss.has("_Lua_StartGame") and not miss.has("setSendTroops"), str(miss.keys())],
	]
	if cuoi != null:
		print("  quan tren san: %s, armature thieu: [%s]" % [cuoi["so quan"], cuoi["rig thieu"]])
		print("  khung san: %s" % str(lua.run("return require('cocos').tran_nut:khung()", "khung")))
		print("  minimap: %s" % str(lua.run("""
			local c = g_CUIGame
			if c == nil then return 'khong co g_CUIGame' end
			local o = c.ChapterObj
			if o == nil then return 'khong co ChapterObj' end
			local b = o.GetMinimapBoardObj and o:GetMinimapBoardObj() or nil
			local l = o.GetMinimapObj and o:GetMinimapObj() or nil
			local function ta(n)
				if n == nil then return 'nil' end
				local w, h = n:getContentSize()
				local x, y = n:getPosition()
				return string.format('%dx%d @(%d,%d) hien=%s', w, h, x, y, tostring(n:getIsVisible()))
			end
			return 'board ' .. ta(b) .. ' | layer ' .. ta(l)
		""", "minimap")))
		ds.append(["co quan tren san (BattleUnit)", int(cuoi["so quan"]) >= 2, str(cuoi["so quan"])])
		var mm: String = str(lua.run("return require('cocos').tran_nut:do_minimap()", "minimap"))
		print("  minimap ve: %s" % mm)
		ds.append(["minimap: ve cham vao dung nut cua bo cuc goc (510x40)",
				mm.begins_with("nut 510x40") and not mm.contains("cham 0/"), mm])
		# "quan 19->23 thong soai 3->0": 5 phan (chu "thong soai" co dau cach).
		var bn := _bam_nut.split(" ")
		var bam_ok := bn.size() == 5 and bn[0] == "quan" and bn[2] == "thong"
		if bam_ok:
			var qq := bn[1].split("->")
			var ll := bn[4].split("->")
			bam_ok = int(qq[1]) - int(qq[0]) == 4 and int(ll[0]) - int(ll[1]) == 3
		ds.append(["bam that vao nut binh chung: them 4 quan, tru 3 thong soai", bam_ok, _bam_nut])
		# "day A tung B->C"
		var tt := _bam_tt.split(" ")
		var tt_ok := tt.size() == 4 and tt[0] == "day" and int(tt[1]) >= 0
		if tt_ok:
			var bc := tt[3].split("->")
			tt_ok = int(bc[1]) > int(bc[0])
		ds.append(["bam that vao nut thuc tinh khi day no: tuong tung ky nang", tt_ok, _bam_tt])
		ds.append(["nut thuc tinh sang khi day no, bao NoticeCastSkill",
				str(cuoi["tt nhat ky"]) == "true", str(cuoi["tt nhat ky"])])
		# SetCameraScale: ham engine 0x366c7c so `giay` voi 0.001 — duoi nguong
		# thi dat ty le NGAY, tren thi chay dan bang CCScaleTo. Ca bon cho goi
		# trong sc/plot/drama_L_XSGK.lua deu truyen 0.5 giay.
		var z0: String = str(lua.run(
				"local t = require('cocos').tran_nut t:dat_thu_phong(1.5, 300, 0, 0) return t:do_thu_phong()",
				"phong ngay"))
		var z0p := z0.split(" ")
		ds.append(["thu phong duoi nguong 0.001 giay: ap NGAY",
				z0p.size() == 3 and absf(float(z0p[1]) - 1.5) < 0.01 and z0p[2] == "ngay", z0])
		var z1: String = str(lua.run(
				"local t = require('cocos').tran_nut t:dat_thu_phong(1.0, 300, 0, 0.5) return t:do_thu_phong()",
				"phong dan"))
		var z1p := z1.split(" ")
		ds.append(["thu phong 0.5 giay: CHAY DAN, node chua toi muc tieu ngay",
				z1p.size() == 3 and absf(float(z1p[0]) - 1.0) < 0.01
						and absf(float(z1p[1]) - 1.5) < 0.01 and z1p[2] == "dan", z1])
		# Chay du 0.5 giay thi toi noi.
		var z2: String = str(lua.run(
				"local t = require('cocos').tran_nut t:_buoc_thu_phong(0.6) return t:do_thu_phong()",
				"phong xong"))
		var z2p := z2.split(" ")
		ds.append(["chay du giay thi toi dung ty le muc tieu",
				z2p.size() == 3 and absf(float(z2p[1]) - 1.0) < 0.01 and z2p[2] == "ngay", z2])
		# Tra ve nguyen trang cho cac phep do sau.
		lua.run("require('cocos').tran_nut:dat_thu_phong(1.0, 300, 0, 0)", "phong lai")
		ds.append(["dua linh: 2 toan x4 nguoi, thong soai 6 -> 0 (lan 3 bi tu choi)",
				int(cuoi["dua q"]) == 8 and str(cuoi["dua ld"]) == "6/0/6",
				"them %s quan, thong soai truoc/sau/toi da %s" % [cuoi["dua q"], cuoi["dua ld"]]])
		# "cam X max M dung false | gb0_0:1.40/D ...": camera toi dich (bi chan
		# o M), MOI lop troi dung he so x camera, va co it nhat mot lop he so
		# khac 1 (nen parallax nap duoc tu bo cuc).
		var cs := _cam_thu.split(" | ")
		var cam_ok := cs.size() == 2
		if cam_ok:
			var h := cs[0].split(" ")
			var cx := float(h[1])
			var co_parallax := false
			cam_ok = h.size() >= 4 and cx > 100.0 and float(h[3]) > 0.0
			for m in cs[1].split(" "):
				var p := m.split(":")
				if p.size() != 2:
					continue
				var rd := p[1].split("/")
				if absf(float(rd[1]) - float(rd[0]) * cx) > 2.0:
					cam_ok = false
				if absf(float(rd[0]) - 1.0) > 0.01:
					co_parallax = true
			cam_ok = cam_ok and co_parallax
		ds.append(["camera bam quan, moi lop nen troi theo he so parallax", cam_ok, _cam_thu])
		ds.append(["man ket thuc CUIGameFinish mo", str(cuoi["man"]) == "CUIGameFinish", str(cuoi["man"])])
		ds.append(["tran do TranGoc danh, khong loi", str(cuoi["tran"]) == "", str(cuoi["tran"])])
		ds.append(["chien bao L_N_01_01 da ghi (BattleStatus > 0)", int(cuoi["chien bao"]) > 0,
				str(cuoi["chien bao"])])
		# Ai 1 co 10 con ra tran (Num: 3 + 3 + 1 + 3; nhom dau Num = 0 nen
		# khong tinh). Moi con mot ma, va so mon roi phai khop so muc trong
		# DropConfig — hai ben sinh cung mot luot.
		ds.append(["danh sach roi do phu dung 10 con ra tran",
				int(cuoi.get("roi ma", -1)) == 10, "%s ma" % cuoi.get("roi ma", "?")])
		# Mon roi phai VAO TUI, khong chi hien tren man ket thuc. Tui cua
		# nguoi choi moi tinh rong, nen so muc trong tui phai bang so mon da
		# roi. Bang 0 cung dat: quay truot ca 10 con la chuyen binh thuong.
		# Mon roi phai VAO TUI, khong chi hien tren man ket thuc. Tui cua nguoi
		# choi moi tinh rong, nen so muc trong tui phai bang so mon da roi —
		# ke ca bang 0 (quay truot ca 10 con la chuyen binh thuong).
		# Moi LOAI phan thuong roi cua ai 1 deu phat duoc. Phep kiem nay xac
		# dinh (khong phu thuoc lan quay), va no do dung cai dang so: duong
		# SetDataWithPrizeData -> AddItem / ChangeArmySoul / AddGold.
		ds.append(["moi muc roi cua ai 1 deu phat thuong duoc",
				int(cuoi.get("phat duoc", -1)) == int(cuoi.get("phat thu", -2))
					and int(cuoi.get("phat thu", 0)) > 0,
				"%s/%s muc" % [cuoi.get("phat duoc", "?"), cuoi.get("phat thu", "?")]])
		ds.append(["so mon roi khop so muc trong DropConfig",
				int(cuoi.get("roi mon", -1)) == int(cuoi.get("roi cfg", -2)),
				"%s mon / %s muc" % [cuoi.get("roi mon", "?"),
					cuoi.get("roi cfg", "?")]])
		ds.append(["kho offline khop client (vang, the luc)", str(cuoi["kho"]) == str(cuoi["client"]),
				"kho %s / client %s" % [cuoi["kho"], cuoi["client"]]])
	else:
		ds.append(["doc trang thai cuoi", false, ", ".join(lua.errors)])
	for e in ds:
		if e[1]:
			ok += 1
		else:
			bad += 1
			print("  HONG: %s  (%s)" % [e[0], str(e[2]).substr(0, 300)])
	print("\ndat %d, hong %d" % [ok, bad])
	return bad


## Do kich ban tran: so cau thoai, chuoi thoai (ten: loi), va loi coroutine.
const _KICH_BAN := """
	local out = Dictionary()
	local k = rawget(_G, 'g_DramaSystem')
	out['so'] = (k and k.so_thoai) and k:so_thoai() or 0
	out['thoai'] = (k and k.chuoi_thoai) and k:chuoi_thoai():sub(1, 1500) or ''
	out['nk'] = (k and k.nhat_ky) and k:nhat_ky():sub(1, 1500) or ''
	out['loi'] = tostring(k and k.loi and k:loi())
	return out
"""


## Ket qua tran sau kich ban: thang/thua + so quan con hai ben.
const _KB_TRAN := """
	local out = Dictionary()
	local r = require('cocos').tran_cuoi
	out['thang'] = tostring(r and r.thang)
	out['chi_tiet'] = r and ('song ' .. tostring(r.song) .. ' giay ' .. string.format('%.0f', tonumber(r.giay) or 0)) or 'chua xong'
	return out
"""


const _TRANG_THAI_CUOI := """
	local out = Dictionary()
	local okm, ten = pcall(function() return g_CUIBattleDlg:GetCurrentUIName() end)
	out['man'] = tostring(okm and ten)
	local r = require('cocos').tran_cuoi
	out['tran'] = r == nil and 'chua danh' or tostring(r.loi or '')
	local nkt = table.concat(require('cocos').nhat_ky_tran or {}, ' > ')
	out['tt nhat ky'] = tostring(nkt:find('SetSkillButtonLighten', 1, true) ~= nil
		and nkt:find('NoticeCastSkill', 1, true) ~= nil)
	local d = nk.dua or {}
	out['dua q'] = (tonumber(d[2]) or 0) - (tonumber(d[1]) or 0)
	out['dua ld'] = tostring(d[3]) .. '/' .. tostring(d[4]) .. '/' .. tostring(d[5])
	local nut = require('cocos').tran_nut
	local okq, sq = pcall(function() return nut:so_quan() end)
	out['so quan'] = okq and sq or 0
	local okt, th = pcall(function() return nut:thieu_rig() end)
	out['rig thieu'] = okt and th or '?'
	-- Roi do: danh sach sinh o ClientChapterBegin (tu DropData cua tung NPC
	-- trong KDBGameNpcConfig), loc theo con da giet, roi man ket thuc doc.
	local okd, tD = pcall(function()
		return g_CUIGame and g_CUIGame.tChapterInfo and g_CUIGame.tChapterInfo.DropList
	end)
	local nMa, nMon = 0, 0
	if okd and type(tD) == 'table' and type(tD.Drop) == 'table' then
		for ma, ds in pairs(tD.Drop) do
			-- Bo qua khoa 'DropList': CHINH client chen no vao Drop, va man
			-- ket thuc cung bo qua (CUIGameFinish.lua:1885 'if k ~= "DropList"').
			if ma ~= 'DropList' then
				nMa = nMa + 1
				if type(ds) == 'table' then nMon = nMon + #ds end
			end
		end
	end
	out['roi ma'] = nMa
	out['roi mon'] = nMon
	local nCfg = 0
	if okd and type(tD) == 'table' and type(tD.DropConfig) == 'table' then
		for _ in pairs(tD.DropConfig) do nCfg = nCfg + 1 end
	end
	out['roi cfg'] = nCfg
	-- Khong phai mon roi nao cung thanh mot muc trong tui: SetDataWithPrizeData
	-- re theo PrizeResType — Prop thanh vat pham, Resource cong thang vao vang
	-- / kim cuong / danh vong. Dem rieng loai "vao tui" de so cho dung.
	local nVao = 0
	if okd and type(tD) == 'table' and type(tD.DropConfig) == 'table' then
		for _, c in pairs(tD.DropConfig) do
			local pd = type(c) == 'table' and c.PrizeData or nil
			if type(pd) == 'table' and tonumber(pd.PrizeResType) ~= PrizeResType.Resource then
				nVao = nVao + 1
			end
		end
	end
	out['roi vao tui'] = nVao
	-- Mon roi co VAO TUI khong. Luat goc tu lam: chapterVictoryHandle gọi
	-- SetDataWithDropList (share_ChapterLogic.lua:4028 — hàm này CÓ được ship),
	-- ghi thẳng vào GameUserItem. Người chơi mới tinh có túi rỗng, nên đếm
	-- cuối ván là đủ.
	local function dem(t)
		local n = 0
		if type(t) == 'table' then for _ in pairs(t) do n = n + 1 end end
		return n
	end
	-- Mon roi di vao HAI bang khac nhau tuy loai phan thuong: vat pham vao
	-- GameUserItem, trang bi vao GameUserEquipment (SetDataWithPrizeData re
	-- theo PrizeResType). Dem ca hai, va dem ca hai phia: luat goc ghi vao du
	-- lieu client truoc, kho offline chi soi lai khi syncFromClient chay.
	out['roi vao tui'] = nVao
	-- Mon roi co VAO TUI khong. Luat goc tu lam: chapterVictoryHandle gọi
	-- SetDataWithDropList (share_ChapterLogic.lua:4028 — hàm này CÓ được ship),
	-- ghi thẳng vào GameUserItem. Người chơi mới tinh có túi rỗng, nên đếm
	-- cuối ván là đủ.
	local function dem(t)
		local n = 0
		if type(t) == 'table' then for _ in pairs(t) do n = n + 1 end end
		return n
	end
	-- Mon roi di vao HAI bang khac nhau tuy loai phan thuong: vat pham vao
	-- GameUserItem, trang bi vao GameUserEquipment (SetDataWithPrizeData re
	-- theo PrizeResType). Dem ca hai, va dem ca hai phia: luat goc ghi vao du
	-- lieu client truoc, kho offline chi soi lai khi syncFromClient chay.
	-- Thu phat MOI muc roi co the co cua ai 1, tung cai mot. Khac phep do
	-- theo tui: khong phu thuoc lan quay, va chi thang vao ham that
	-- (SetDataWithPrizeData -> AddItem / ChangeArmySoul / AddGold).
	local nThu, nDuoc = 0, 0
	do
		local c = G_ConfigManager:GetChapterConfig('L_N_01_01') or {}
		local info = type(c.ChapterInfo) == 'table' and c.ChapterInfo or nil
		for _, g in ipairs(info and info.Groups or {}) do
			for _, sd in ipairs(g.Soldiers or {}) do
				if (tonumber(sd.Num) or 0) > 0 then
					local npc = G_ConfigManager:GetNpcConfigWithNpcId(tostring(sd.NpcID))
					local dsr = npc and npc.DropData
					if type(dsr) == 'string' then
						local okj, t = pcall(cjson.decode, dsr)
						dsr = okj and t or nil
					end
					for _, muc in ipairs(dsr or {}) do
						nThu = nThu + 1
						local okp, tra = pcall(function()
							return G_ChapterLogic:SetDataWithPrizeData(muc.PrizeData, 1, 'do')
						end)
						if okp and tra == true then nDuoc = nDuoc + 1 end
					end
				end
			end
		end
	end
	out['phat thu'] = nThu
	out['phat duoc'] = nDuoc
	local okr, _, bc = pcall(function() return G_ChapterLogic:GetBattleReportsData('L_N_01_01') end)
	out['chien bao'] = (okr and type(bc) == 'table' and tonumber(bc.BattleStatus)) or 0
	local _, vang = G_UserLogic:GetGold()
	local _, tl = G_UserLogic:GetFatigueValue()
	out['client'] = tostring(vang) .. '/' .. tostring(tl)
	local kho = OfflineStore.data and OfflineStore.data.GameUserBaseInfo or {}
	out['kho'] = tostring(kho.Gold) .. '/' .. tostring(kho.FatigueValue)
	return out
"""


## Ghi lai tu day tro di: moi loi goi may chu, moi dong nhat ky offline khong
## phai 'info', moi loi ma goc bao qua KDebug.PrintError — khong gioi han nhu
## loi_goc cua vao_main.
const _BAT := """
	nk = { sv = {}, off = {}, loi = {} }
	local goc_dispatch = OfflineNet.dispatch
	OfflineNet.dispatch = function(self, m, o, f, ...)
		nk.sv[#nk.sv + 1] = (o ~= '' and o .. '.' or '') .. tostring(f)
		return goc_dispatch(self, m, o, f, ...)
	end
	local goc_ghi = OfflineLog.write
	OfflineLog.write = function(self, tag, msg)
		if tag ~= 'info' then nk.off[#nk.off + 1] = tostring(tag) .. ' ' .. tostring(msg):sub(1, 300) end
		return goc_ghi(self, tag, msg)
	end
	-- onShow cua ChapterInfo co that su chay khong: CurrentUIName dat ngay luc
	-- Show (CUIManager.lua:307), con onShow chi chay khi hang doi hoat canh mo
	-- toi luot — 'man tren' dung ma man chua dung la chuyen co that.
	nk.show = {}
	-- Ham cua lop nam trong vtbl rieng (share/class.lua): DOC qua lop ra nil,
	-- phai doc qua doi tuong; GHI vao lop thi di vao vtbl (__newindex).
	-- Cung cach do cho duong KET THUC tran: engine goi onLevelOver /
	-- onLevelComplete -> GameFinish -> ChapterObj:OnEnd ->
	-- OnLevelCompleteCallServer -> G_ChapterLogic:ChapterComplete*.
	for _, m in ipairs({
		{ 'CUIChapterInfo', 'g_CUIChapterInfo', 'onShow' },
		{ 'CUIBattleDeploy', 'g_CUIBattleDeploy', 'onShow' },
		{ 'CUISelectLevel', 'g_CUISelectLevel', 'onShow' },
		{ 'CUIGame', 'g_CUIGame', 'onLevelOver' },
		{ 'CUIGame', 'g_CUIGame', 'onLevelComplete' },
		{ 'CUIGame', 'g_CUIGame', 'GameFinish' },
		{ 'CUIGame', 'g_CUIGame', 'OnLevelCompleteCallServer' },
		{ 'ClientChapterLogic', 'G_ChapterLogic', 'ChapterCompleteFaild' },
		{ 'ClientChapterLogic', 'G_ChapterLogic', 'ChapterCompleteSuccess' },
	}) do
		local lop, dt, ham = rawget(_G, m[1]), rawget(_G, m[2]), m[3]
		local goc = dt and dt[ham]
		if lop and type(goc) == 'function' then
			lop[ham] = function(...)
				local ok, r = pcall(goc, ...)
				nk.show[#nk.show + 1] = m[1] .. ':' .. ham .. '(' .. tostring((select(2, ...))) .. ')'
					.. (ok and (' ra ' .. tostring(r)) or (' LOI ' .. tostring(r):sub(1, 250)))
				if not ok then error(r, 0) end
				return r
			end
		end
	end
	local goc_loi = KDebug.PrintError
	KDebug.PrintError = function(...)
		local t = {}
		for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end
		if #nk.loi < 200 then nk.loi[#nk.loi + 1] = table.concat(t, ' '):sub(1, 300) end
		return goc_loi(...)
	end
	return true
"""

const _RUT := """
	local out = Dictionary()
	out['may chu'] = table.concat(nk.sv, ', ')
	for i, s in ipairs(nk.off) do if i <= 10 then out['offline ' .. i] = s end end
	for i, s in ipairs(nk.loi) do if i <= 8 then out['loi goc ' .. i] = s end end
	out['so loi goc'] = tostring(#nk.loi)
	-- Loi nem ra trong hen gio (S_CCSchedule, CCCallFunc) va trong o danh sach
	-- cuon bi pcall giu lai o cocos.lua chu khong len toi day.
	local c = require('cocos')
	nk.hen_da = nk.hen_da or 0
	for i = nk.hen_da + 1, #c.loi_hen do
		if i - nk.hen_da <= 6 then out['loi hen ' .. i] = tostring(c.loi_hen[i]):sub(1, 300) end
	end
	nk.hen_da = #c.loi_hen
	nk.o_da = nk.o_da or 0
	for i = nk.o_da + 1, #(c.cell_errors or {}) do
		if i - nk.o_da <= 4 then out['loi o ' .. i] = tostring(c.cell_errors[i]):sub(1, 300) end
	end
	nk.o_da = #(c.cell_errors or {})
	local okm, ten = pcall(function() return g_CUINormalDlg:GetCurrentUIName() end)
	out['man tren'] = tostring(okm and ten)
	-- Show() bat khoa nay truoc khi mo va chi tat khi hoat canh mo chay xong;
	-- con bat thi moi Show sau bi bo qua, chi co mot PrintWarning (CUIManager
	-- .lua:275).
	out['khoa ui'] = tostring(g_CUINormalDlg.IsUILock)
	out['hoat canh cho'] = tostring(#(g_CUINormalDlg.AnimationList or {}))
	out['onShow'] = table.concat(nk.show, ' | ')
	nk.show = {}
	out['canh'] = tostring(g_CSceneManager.CurrentScene) .. (g_CSceneManager.isLoading and ' (dang doi)' or '')
	local L = g_CUISelectLevel
	out['so ai'] = tostring(L.tChapterData and #L.tChapterData)
	out['ai chon'] = tostring(g_CUIChapterInfo.tLevelData and g_CUIChapterInfo.tLevelData.ChapterKey)
	local D = g_CUIBattleDeploy
	out['deploy'] = tostring(D.tChapterData and D.tChapterData.ChapterKey)
	-- onTouchEnd_OnChapterListAttack hoi xac nhan (g_messageBox) khi so tuong
	-- da xep it hon so tuong dang mo (CUIBattleDeploy.lua:2867-2889).
	local o = {}
	for k, v in pairs(D.tSelectedHerosItemConfig or {}) do
		if v.ItemTag and v.ItemTag ~= '' then o[#o + 1] = k .. '=' .. tostring(v.ItemTag) end
	end
	table.sort(o)
	out['tuong'] = 'da xep ' .. tostring(D.nSelectedHeros) .. ' / dang mo '
		.. tostring(D.tAllUnlockHerosData and #D.tAllUnlockHerosData) .. ' [' .. table.concat(o, ' ') .. ']'
	nk.sv, nk.off, nk.loi = {}, {}, {}
	return out
"""


## Dem so mon dang co trong tui, de cuoi van so chenh lech.

