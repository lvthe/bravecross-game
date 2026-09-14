-- g_BattleField gia: dong vai engine tran C++ cua ban goc.
--
-- Ban goc danh tran trong libgame.so. Lua chi dua du lieu vao roi nghe goi
-- nguoc (CUIGame.lua:620-635, :924-1031):
--   g_BattleField:_Lua_LoadMap / set*CallBack / setArmysNum
--   g_BattleField:setSendTroops(cjson quan ta) / setLevelData(cjson quan dich)
--   g_BattleField:_Lua_StartGame(...)
-- roi engine goi nguoc g_CUIGame theo TEN. Ten do lay tu chuoi cua libgame.so
-- (quanh 0x7c0f2a): troopResidue, npcResidue, TotalHpResidue, onLevelComplete,
-- onLevelOver, onQuickResultFinish, OnFinishWave, OnArmyRevive...
--
-- g_BattleField la node CCLayer ten 'g_BattleField' trong BattleField_<canh>
-- _960_640.xgg; bang ham nay gan cho no qua cocos.lua (lop_rieng). Ten ham
-- cung lay tu libgame.so (chuoi quanh 0x7c1258), ke ca ham chi man khac goi.
-- Ham chi nhan co thi GHI LAI; ham phai tra so thi tra so cua tran vua danh.
--
-- Tran CO HINH: battle/san_tran_ve.gd (BattleUnit + SngRig tren chinh san
-- nay), buoc moi khung theo bo hen gio cua Lua. Che do tinh nhanh cua ban goc
-- (setQuickResult) va quickGameFinish thi danh tuc thi (battle/tran_goc.gd).
-- Ca hai dung CHI SO THAT trong du lieu ban goc gui vao; cach gop chi so
-- thanh sat thuong la cua ta. CHUA CO: dua linh ra tran (nguoi choi bam bieu
-- tuong, ton thong soai), ky nang thuc tinh, kich ban (sc/plot/drama_*.lua),
-- (Truoc day chua co bao giet vi khong ro szId; nay da giai: xem
-- battle/tran_goc.gd, ma don vi "<nhom>-<linh>-<ban sao>".)
return function(C)
	local S = setmetatable({}, { __index = C.Node })

	local T
	local function dat_lai()
		T = { cb = {}, ta = '', dich = '', roi = '', hat = 0, dang = false,
		      dung = false, song = 0, kq = nil, tran = nil, hen = nil,
		      ld = 0, ld_max = 0, ld_hoi = 0, ld_dem = 0, ld_chay = false,
		      tt_ds = {}, nut_tt = {}, cho_tt = {} }
	end
	dat_lai()

	local function ghi_loi(s)
		if C.loi_hen then C.loi_hen[#C.loi_hen + 1] = 'san tran: ' .. tostring(s) end
	end

	-- Nhat ky su kien cua san tran — de biet chuoi ket thuc di toi dau.
	C.nhat_ky_tran = {}
	local function ghi(s)
		local nk = C.nhat_ky_tran
		if #nk < 60 then nk[#nk + 1] = s end
	end

	-- Goi g_CUIGame:<ten>(...) nhu engine goi. Loi GHI LAI, khong nuot: day la
	-- noi chuoi ket thuc cua ban goc bat dau (GameFinish -> OnEnd -> may chu).
	local function goi(ten, ...)
		local G = rawget(_G, 'g_CUIGame')
		local f = G and G[ten]
		if type(f) ~= 'function' then
			ghi_loi('g_CUIGame khong co ham ' .. ten)
			return
		end
		ghi('goi g_CUIGame:' .. ten)
		local ok, e = pcall(f, G, ...)
		if not ok then ghi_loi(ten .. ': ' .. tostring(e)) end
	end

	local function nhan_ket_qua(s)
		local okj, r = pcall(cjson.decode, s)
		if not okj or type(r) ~= 'table' then
			ghi_loi('ket qua tran khong giai duoc: ' .. tostring(r))
			return false
		end
		if r.loi ~= nil and r.loi ~= '' then ghi_loi(r.loi) end
		T.kq = r
		T.song = tonumber(r.song) or 0
		C.tran_cuoi = r
		return true
	end

	-- Dung buoc tran co hinh; tran chua co ket qua (het gio, showGameEnd) thi
	-- chot ngay tai cho.
	local function dung_tran(thang)
		if T.hen ~= nil then T.hen:stop(); T.hen = nil end
		if T.tran ~= nil and T.kq == nil then
			local ok, s = pcall(function() return T.tran:chot(thang) end)
			if ok and type(s) == 'string' then nhan_ket_qua(s) end
		end
	end

	-- Thu tu cac lan goi nguoc luc het tran la DAT: chuoi trong libgame.so
	-- chi cho biet TEN. Du lieu con lai (troopResidue/npcResidue) dua truoc,
	-- ket qua sau, vi GameFinish dung chung (CUIGame.lua:1339-1431).
	local function ket_thuc(thang)
		ghi('ket_thuc ' .. tostring(thang) .. (T.dang and '' or ' (bo qua: khong dang danh)'))
		if not T.dang then return end
		T.dang = false
		dung_tran(thang)
		local r = T.kq or {}
		-- Bao GIET tung con, truoc khi bao ket qua. Ban goc: engine C++ goi
		-- setKillEnemyCallBack moi lan mot con chet, va CUIGame gom lai thanh
		-- KillIdList gui ve server; server dung no loc danh sach roi do
		-- (ChapterLogic:filterKillDropList). Ta danh tuc thi nen bao het mot
		-- lan o day — thu tu trong danh sach khong anh huong: luat goc chi
		-- tra cuu theo ma.
		local ten_cb = T.cb['setKillEnemyCallBack']
		if ten_cb ~= nil and type(r.dich_chet) == 'table' then
			for _, ma in ipairs(r.dich_chet) do goi(ten_cb, tostring(ma)) end
		end
		goi('troopResidue', r.ta_con or {})
		goi('npcResidue', r.dich_con or {})
		goi('TotalHpResidue', r.ta_pct or 0, r.dich_pct or 0)
		goi(thang and 'onLevelComplete' or 'onLevelOver')
	end

	-- Thong soai (dua linh ra tran). ENGINE giu con so: tru khi dua linh, hoi
	-- theo thoi gian, bao lai qua updateLeaderShip / updateMaxLeaderShip /
	-- runLeaderShipTimer / NoticeDispatch (ten do trong libgame.so). So lay tu
	-- du lieu ban goc gui vao: Chapter.LeaderShip (toi da; L_N_01_01 = 6),
	-- Chapter.LeaderShipResume (5), Troop_<n>.BaseInfo.LeaderShipForBuild
	-- (Troop_1 = 3). DAT, chua do: vao tran thi day thong soai; hoi 1 diem sau
	-- moi LeaderShipResume giay (dong ho runLeaderShipTimer dem nguoc dung
	-- khoang do).
	local function bat_dau_thong_soai()
		local ok, t = pcall(cjson.decode, T.ta)
		local ch = ok and type(t) == 'table' and type(t.Sprite) == 'table' and t.Sprite.Chapter or {}
		T.ld_max = tonumber(ch.LeaderShip) or 0
		T.ld_hoi = tonumber(ch.LeaderShipResume) or 0
		T.ld, T.ld_dem, T.ld_chay = T.ld_max, 0, false
		goi('updateMaxLeaderShip', T.ld_max)
		goi('updateLeaderShip', T.ld)
	end

	local function hoi_thong_soai(dt)
		if T.ld >= T.ld_max or T.ld_hoi <= 0 then return end
		if not T.ld_chay then
			T.ld_chay, T.ld_dem = true, 0
			goi('runLeaderShipTimer', T.ld_hoi)
		end
		T.ld_dem = T.ld_dem + dt
		if T.ld_dem >= T.ld_hoi then
			T.ld = T.ld + 1
			T.ld_chay = false
			goi('updateLeaderShip', T.ld)
		end
	end

	-- Dua mot toan linh <khoa> (vd 'Troop_1'). mien_phi: linh tang kem
	-- (CUIGame:AttachArmy -> attachedDispatch), khong ton thong soai.
	local function dua_linh(khoa, gia, id, mien_phi)
		if not T.dang or T.tran == nil or T.dung == true then return false end
		gia = tonumber(gia) or 0
		if not mien_phi and T.ld < gia then
			ghi('dua linh ' .. tostring(khoa) .. ': thieu thong soai ' .. T.ld .. '/' .. gia)
			return false
		end
		local ok, n = pcall(function() return T.tran:dua_linh(tostring(khoa)) end)
		if not ok or (tonumber(n) or 0) <= 0 then
			ghi_loi('dua linh ' .. tostring(khoa) .. ': ' .. tostring(n))
			return false
		end
		ghi('dua linh ' .. tostring(khoa) .. ' x' .. tostring(n))
		if not mien_phi then
			T.ld = T.ld - gia
			goi('updateLeaderShip', T.ld)
			goi('NoticeDispatch', tonumber(id) or 0)
		end
		return true
	end

	-- Nut binh chung: btnBattlefieldArmy, lop C++ mang ten node (libgame.so co
	-- setDispatchID / setLeaderShipForBuild / dispatch / attachedDispatch canh
	-- nhau). Node KHONG co ten cham trong .xgg — ban goc de engine bat cham
	-- tren nut — nen o day gan ten cham rieng luc engine nhan setDispatchID.
	-- CUIGame:createArmyIcons nhan ban mau; _copy chep meta nen ban sao cung
	-- mang ten node va cung vao bang nay.
	local Nut = setmetatable({}, { __index = C.Node })
	local bo_cham = {}
	function bo_cham:onTouchEnd_DuaLinh(nut, trong)
		if trong == false then return end
		nut:dispatch()
	end
	function Nut:setDispatchID(i)
		C.raw(self):set_meta('dispatch_id', tonumber(i) or 0)
		self:setLuaTouchName('DuaLinh')
		self:setCallbackLuaObject(bo_cham)
	end
	function Nut:setLeaderShipForBuild(n)
		C.raw(self):set_meta('ld_build', tonumber(n) or 0)
	end
	-- setArmyIcons dat stringTag = "Troop_<ArmyID>" (CUIGame.lua:4174).
	local function khoa_linh(nut)
		local ok, s = pcall(function() return nut:getStringTag() end)
		if ok and type(s) == 'string' and s ~= '' then return s end
		local gd = C.raw(nut)
		return 'Troop_' .. tostring(gd:has_meta('dispatch_id') and gd:get_meta('dispatch_id') or 1)
	end
	function Nut:dispatch()
		local gd = C.raw(self)
		return dua_linh(khoa_linh(self),
			gd:has_meta('ld_build') and gd:get_meta('ld_build') or 0,
			gd:has_meta('dispatch_id') and gd:get_meta('dispatch_id') or 0, false)
	end
	function Nut:attachedDispatch()
		return dua_linh(khoa_linh(self), 0, 0, true)
	end
	C.lop_rieng['btnBattlefieldArmy'] = Nut

	-- Cho cong cu do doc thong soai (khong phai ham cua ban goc).
	function S:_thong_soai() return T.ld, T.ld_max end

	-- Thuc tinh. Nut: spBattleFieldHeroItem nhan ban, tag 1..5
	-- (CUIGame:SetSkillIcons). ENGINE goi InitSkillButton cho tung tuong, doi
	-- trang thai nut (SetSkillButtonLighten / Gray / Normal — ten trong
	-- libgame.so, ham Lua cua CUIGame), bat cham tren nut (node khong co ten
	-- cham trong .xgg) va bao NoticeCastSkill. Ky nang cua tung tuong nam
	-- trong C++ (cac lop CDFSpriteFight*Wake), chua giai: o day don KE TIEP
	-- cua tuong la don ky nang (battle/san_tran_ve.gd thuc_tinh). DAT: nut hien
	-- cho moi tuong ta ra tran; chua day no hoac da chet thi xam; tung xong
	-- thi ve thuong roi xam.
	local function thuc_tinh(id)
		id = tonumber(id) or 0
		if not T.dang or T.tran == nil or T.dung == true then return false end
		if T.cho_tt[id] then return false end      -- da bam, cho don ky nang
		local ok, r = pcall(function() return T.tran:thuc_tinh(id) end)
		if not ok or r ~= true then
			ghi('thuc tinh ' .. id .. ': chua day no')
			return false
		end
		T.cho_tt[id] = true
		ghi('thuc tinh ' .. id)
		goi('NoticeCastSkill', id)
		return true
	end

	local bo_cham_tt = {}
	function bo_cham_tt:onTouchEnd_ThucTinh(nut, trong)
		if trong == false then return end
		local gd = C.raw(nut)
		thuc_tinh(gd:has_meta('tt_id') and gd:get_meta('tt_id') or 0)
	end

	local function bat_dau_thuc_tinh()
		T.tt_ds, T.nut_tt, T.cho_tt = {}, {}, {}
		local ok, t = pcall(cjson.decode, T.ta)
		local sp = ok and type(t) == 'table' and type(t.Sprite) == 'table' and t.Sprite or {}
		local troop = type(sp.Troop) == 'table' and sp.Troop or {}
		local G = rawget(_G, 'g_CUIGame')
		local nut_ds = (G and type(G.tSkillIcons) == 'table') and G.tSkillIcons or {}
		local i = 0
		for _, s in ipairs(type(troop.Soldiers) == 'table' and troop.Soldiers or {}) do
			if s.IsHero and i < #nut_ds then
				i = i + 1
				local h = type(sp[s.Data]) == 'table' and sp[s.Data] or {}
				local id = tonumber(s.ID) or 0
				-- InitSkillButton so HeroID cua ban ghi tuong (CUIGame.lua:3645).
				goi('InitSkillButton', tonumber(h.HeroID) or id, '', i, true)
				local nut = nut_ds[i]
				pcall(function()
					nut:setIsVisible(true)
					C.raw(nut):set_meta('tt_id', id)
					nut:setLuaTouchName('ThucTinh')
					nut:setCallbackLuaObject(bo_cham_tt)
					nut:setEnableLuaTouch(true)
				end)
				T.tt_ds[#T.tt_ds + 1] = { id = id, tag = i }
				goi('SetSkillButtonGray', i)
				T.nut_tt[i] = 'xam'
			end
		end
	end

	local function cap_nhat_thuc_tinh()
		if #T.tt_ds == 0 then return end
		local ok, s = pcall(function() return T.tran:no_tuong() end)
		if not ok or type(s) ~= 'string' then return end
		local okj, ds = pcall(cjson.decode, s)
		if not okj or type(ds) ~= 'table' then return end
		local theo_id = {}
		for _, h in ipairs(ds) do theo_id[tonumber(h.id)] = h end
		for _, n in ipairs(T.tt_ds) do
			local h = theo_id[n.id] or {}
			local moi = h.day == true and 'sang' or 'xam'
			local cu = T.nut_tt[n.tag]
			if moi ~= cu then
				if moi == 'sang' then
					goi('SetSkillButtonLighten', n.tag)
				else
					if cu == 'sang' then goi('SetSkillButtonNormal', n.tag) end
					goi('SetSkillButtonGray', n.tag)
					T.cho_tt[n.id] = nil
				end
				T.nut_tt[n.tag] = moi
			end
			-- Tu thuc tinh: setAutoWake (tu danh cua ban goc) bat thi tung ngay.
			if moi == 'sang' and T.tu_thuc == true then thuc_tinh(n.id) end
		end
	end

	-- Nut btnWake cu (CUIGame:onTouchEnd_btnWake -> setWaking()): thuc tinh
	-- tuong dau tien dang day no.
	function S:setWaking()
		for _, n in ipairs(T.tt_ds) do
			if T.nut_tt[n.tag] == 'sang' and thuc_tinh(n.id) then return end
		end
	end

	-- Nap va chay kich ban tran cua ban goc (sc/plot/drama_<ai>.lua). File
	-- dang ky moc len g_DramaSystem luc require (dong dau file), roi ta chay
	-- moc bat dau. Xoa package.loaded de tran sau nap lai dung g_DramaSystem
	-- hien tai. Thieu file kich ban (ai khong co plot) thi bo qua im lang.
	local function bat_dau_kich_ban(strKey)
		local kb = rawget(_G, 'g_DramaSystem')
		if kb == nil or type(kb.bat_dau_kich_ban) ~= 'function' then return end
		local ten = 'plot.drama_' .. tostring(strKey)
		package.loaded[ten] = nil
		local ok = pcall(require, ten)
		if not ok then return end          -- ai nay khong co kich ban
		pcall(function() kb:bat_dau_kich_ban() end)
	end

	local hen = {}
	-- Moi khung: buoc tran co hinh. Ban goc tam dung (_Lua_PauseGame) thi dung.
	function hen:buoc(dt)
		-- Kich ban tran chay TRUOC va BAT KE tam dung: canh dien anh dung tran
		-- (_Lua_PauseGame) nhung kich ban van tiep. Tin hieu gap_quan bao khi
		-- tran co dich moi de moc EncounterArmyBegin di tiep.
		local kb = rawget(_G, 'g_DramaSystem')
		if kb ~= nil and type(kb.dang_chay) == 'function' and kb:dang_chay() then
			-- Quan dich co san tu dau tran nen "gap quan" la ngay; moc
			-- EncounterArmyBegin vi the di tiep o khung ke.
			pcall(function() kb:gap_quan(); kb:buoc(tonumber(dt) or 0) end)
		end
		if not T.dang or T.tran == nil or T.dung == true then return end
		hoi_thong_soai(tonumber(dt) or 0)
		cap_nhat_thuc_tinh()
		local ok, s = pcall(function() return T.tran:buoc(tonumber(dt) or 0) end)
		if not ok then
			ghi_loi('buoc tran: ' .. tostring(s))
			return
		end
		if type(s) == 'string' and s ~= '' and nhan_ket_qua(s) then
			ket_thuc(T.kq.thang == true)
		end
	end
	function hen:tinh_nhanh()
		ket_thuc(T.kq ~= nil and T.kq.thang == true)
	end

	local function tinh_tuc_thi()
		if _godot_danh_tran == nil then
			ghi_loi('thieu _godot_danh_tran (lua_runtime.gd)')
			return false
		end
		local ok, s = pcall(_godot_danh_tran, T.ta, T.dich, tonumber(T.hat) or 0)
		if not ok or type(s) ~= 'string' then
			ghi_loi('danh tran: ' .. tostring(s))
			return false
		end
		return nhan_ket_qua(s)
	end

	-- Ham chi nhan co / du lieu: ghi vao T[truong] (hoac bo qua neu nil).
	local function nhan(truong)
		return function(_, v)
			if truong then T[truong] = v end
		end
	end
	for ten, truong in pairs({
		setArmysNum = 'so_binh', setRandSeed = 'hat', setReplay = 'phat_lai',
		setTroopFightCapacity = 'luc_ta', setNpcFightCapacity = 'luc_dich',
		setQuickResult = 'nhanh', setAutoWake = 'tu_thuc', setAutoDispatch = 'tu_dua',
		setNpcResidue = 'npc_con', setDropData = 'roi', _Lua_PauseGame = 'dung',
		setShowStarEffect = false, setEnableTouchInAutoWake = false,
		setWakeButtonCount = false, setKeepScreenBright = false,
		setChapterClassifyAttach = false, setChapterFuryAttach = false,
		setFightMode = false, SetGameStatus = false,
		startNextWave = false, setGroupsCreaterCanUpdate = false,
		setCommitTotalResidue = false, setCommitTroopResidue = false,
		setCommitNpcResidue = false, setDropCollectTable = false, addDropData = false,
		addLevelData = false, pauseNode = false, testButton = false,
		_Lua_SetSceneScale = false, _Lua_ReviveArmyHeros = false,
	}) do
		S[ten] = nhan(truong or nil)
	end

	for _, ten in ipairs({ 'setKillEnemyCallBack', 'setDropCallBack',
			'setWaveCallBack', 'setWaveEndCallBack' }) do
		S[ten] = function(_, ham) T.cb[ten] = ham end
	end

	-- Lop den phu man (g_BlackEffectLayer, Game_UI_Control_Panel: 2000x1000,
	-- den, do mo 255, dang HIEN). Lua cua ban goc khong bao gio tat no — dong
	-- tat duy nhat (CUIGame.lua:1148) nam trong khoi da chu thich bo — nen la
	-- viec cua ENGINE: ten no co trong chuoi cua libgame.so, va g_BattleField co
	-- SetLayerDark ma kich ban (plot/drama_*.lua) goi de lam toi man. SUY RA,
	-- khong do: san dung thi tat, SetLayerDark(b) bat/tat.
	local function lop_den(hien)
		local l = rawget(_G, 'g_BlackEffectLayer')
		if l ~= nil then pcall(function() l:setIsVisible(hien == true) end) end
	end
	function S:SetLayerDark(b) lop_den(b) end

	-- Kich ban dung camera truoc doan thoai (plot/drama_L_N_01_03.lua:113).
	function S:StopCamera()
		ghi('StopCamera')
		if T.tran ~= nil then pcall(function() T.tran:dung_camera() end) end
	end

	function S:_Lua_LoadMap(tmx, x, y)
		T.ban_do = tmx
		lop_den(false)
		return true
	end

	function S:setSendTroops(s) T.ta = s ~= nil and tostring(s) or '' end
	function S:setLevelData(s) T.dich = s ~= nil and tostring(s) or '' end

	function S:_Lua_ResetGameData()
		if T.hen ~= nil then T.hen:stop() end
		if T.tran ~= nil then pcall(function() T.tran:queue_free() end) end
		T.dang, T.kq, T.song, T.tran, T.hen = false, nil, 0, nil, nil
	end

	function S:getRandSeedRecord() return T.hat end
	function S:isGaming() return T.dang end
	-- CUIGame:getRating chia so tuong CON SONG cho so tuong ra tran (:2663).
	function S:getHeroNum() return T.song end
	function S:getTroopResidue() return (T.kq and T.kq.ta_con) or {} end
	function S:getNpcResidue() return (T.kq and T.kq.dich_con) or {} end
	function S:GetNpcResidueNum() return #((T.kq and T.kq.dich_con) or {}) end
	-- Nam bang (CUIDamageStatistic.lua:133): tuong ta, linh ta, tuong dich,
	-- linh dich, dem linh. Chi co sat thuong cua tuong ta.
	function S:LuaGetDamageStatistic(_)
		return (T.kq and T.kq.sat_thuong_tuong) or {}, {}, {}, {}, {}
	end
	function S:LuaGetHeroState(_) return nil end

	-- Nut ket thuc nhanh (clGuickGameFinish, CUIGame.lua:2478): tinh not tran.
	function S:quickGameFinish()
		ghi('quickGameFinish')
		if not T.dang then return end
		if T.hen ~= nil then T.hen:stop(); T.hen = nil end
		if tinh_tuc_thi() then ket_thuc(T.kq.thang == true) end
	end
	function S:showGameWin() ghi('showGameWin'); ket_thuc(true) end
	-- Het gio (CUIGame:OnGameTimeOut -> ChapterObj:OnShowGameEnd -> day). Ban
	-- goc con phan xu qua CheckTimeOutVerdict; o day DAT la thua.
	function S:showGameEnd() ghi('showGameEnd'); ket_thuc(false) end
	function S:showGameEndNonStop() ghi('showGameEndNonStop'); ket_thuc(false) end

	function S:_Lua_StartGame(nMain, nSub, strKey, nType, nScenes, nClassify, nSceneClassify, bPlot)
		ghi('_Lua_StartGame ' .. tostring(strKey))
		T.dang, T.kq, T.ai = true, nil, strKey
		-- Che do tinh nhanh cua ban goc (setQuickResult, "快速计算"): khong hinh.
		if T.nhanh == true then
			if tinh_tuc_thi() then C.lich:scheduleOnce(hen, 'tinh_nhanh', 0) end
			return
		end
		if _godot_tao_tran == nil then
			ghi_loi('thieu _godot_tao_tran (lua_runtime.gd)')
			return
		end
		local okt, tran = pcall(_godot_tao_tran, C.raw(self))
		if not okt or tran == nil then
			ghi_loi('tao tran: ' .. tostring(tran))
			return
		end
		local mz = rawget(_G, 'g_MapZero')
		local okb, loi = pcall(function()
			return tran:bat_dau(T.ta, T.dich, tonumber(T.hat) or 0, mz ~= nil and C.raw(mz) or nil)
		end)
		if not okb then
			ghi_loi('bat dau tran: ' .. tostring(loi))
			return
		end
		if loi ~= nil and loi ~= '' then ghi_loi(loi) end
		T.tran = tran
		C.tran_nut = tran
		T.hen = C.lich:schedule(hen, 'buoc', 0)
		bat_dau_thong_soai()
		bat_dau_thuc_tinh()
		-- Kich ban tran chi chay khi BAT co G_KICHBAN. Canh dien anh dung tran,
		-- an nut, tao NPC — dung cho tran that, nhung dap len cac phep kiem cua
		-- do_chien_dich (dua linh / thuc tinh). De mac dinh TAT: do_chien_dich
		-- --kiem giu 16/16; do_chien_dich --kichban bat co de do rieng kich ban.
		if bPlot == true and rawget(_G, 'G_KICHBAN') == true then
			bat_dau_kich_ban(strKey)
		end
	end

	return S
end
