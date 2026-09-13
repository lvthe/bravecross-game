-- DFDramaScriptSystem gia: chay KICH BAN TRAN cua ban goc (sc/plot/drama_*.lua).
--
-- Kich ban goc la mot COROUTINE: dang ky bang AddMoitor / SetGameStartMoitor,
-- than ham goi hang loat g_DramaSystem:... roi coroutine.yield() de doi. Engine
-- C++ (DFDramaScriptSystem) danh thuc lai khi dieu kien "di tiep" thoa: het gio
-- cho (DelayTimeThenGoNext), nguoi choi cham thoai (ShowDialogue), gap quan
-- (EncounterArmyBegin), nhan thong bao tu tran (Notification_*), tuong thuc
-- tinh xong (HeroWakeEnd)...
--
-- File nay lam PHAN DIEU KHIEN do: chay coroutine, giu dieu kien di tiep, va
-- buoc theo thoi gian tran. Ghi lai chuoi thoai va moi loi goi. Cac loi goi
-- DAN CANH (tao NPC, camera, hieu ung, dien anh) thi GHI LAI roi bo qua — tra
-- ve mot "hinh nhan" nuot moi loi goi tiep de coroutine khong chet giua chung.
--
-- DAT, khong phai ban goc:
--   * Hieu ung dan canh (CreateNpcAndMoveTo, AddPlugin, camera, ColorLayer...)
--     chi GHI, khong dung — luat that nam trong C++ DFDramaScriptSystem.
--   * Cho thoai: ban goc doi nguoi choi CHAM; o day tu di tiep sau CHO_THOAI
--     giay (probe khong co UI cham). di_tiep() ep qua ngay.
--   * Cho thong bao / thuc tinh: neu tran gia khong bao trong CHO_TOI_DA giay
--     thi tu di tiep, de kich ban khong treo. Danh dau bang '(qua gio)'.
--
-- Xem sc/plot/drama_L_N_01_01.lua (huong dan tan thu) va drama_L_N_01_03.lua.

return function(c)
	local M = {}

	-- Hinh nhan: nuot moi loi goi va tro thuoc tinh, tra ve chinh no. Khac
	-- 'bong' cua bootstrap o cho khong dem gioi han va khong ghi ghost —
	-- kich ban tao rat nhieu NPC/hieu ung, khong the de moi cai thanh bong.
	local hinh_nhan = {}
	setmetatable(hinh_nhan, {
		__index = function() return hinh_nhan end,
		__call = function() return hinh_nhan end,
		__newindex = function() end,
		__concat = function(a, b) return tostring(a) .. tostring(b) end,
		__tostring = function() return '<hinh nhan kich ban>' end,
	})

	local CHO_THOAI = 0.4      -- giay tu di tiep sau mot cau thoai (probe)
	local CHO_TOI_DA = 6.0     -- giay cho toi da mot thong bao truoc khi bo qua

	local KB = {}
	KB.__index = function(t, k)
		local v = rawget(KB, k)
		if v ~= nil then return v end
		-- Truong trang thai (_cho, _co, _tre...) chua dat thi la nil that, KHONG
		-- tra ham — neu khong 'if self._cho' se luon dung va self._cho.kieu chet.
		if type(k) == 'string' and k:sub(1, 1) == '_' then return nil end
		-- Phuong thuc dan canh chua lam: ghi lai roi tra HAM nuot-tat-ca. Ham
		-- do tra hinh_nhan de 'local x = ds:CreateNpc...(); x:setIsVisible()'
		-- khong chet.
		return function(self, ...)
			if type(self) == 'table' and rawget(self, '_nhat_ky') then
				self._nhat_ky[#self._nhat_ky + 1] = tostring(k)
			end
			return hinh_nhan
		end
	end

	function M.new()
		return setmetatable({
			_thoai = {},        -- {ten, loi} theo thu tu
			_npc = {},          -- ten/sprite -> dac ta NPC kich ban tao (de nhap tran)
			_nhat_ky = {},      -- moi ten phuong thuc da goi
			_co = nil,          -- coroutine dang chay
			_cho = nil,         -- dieu kien di tiep hien tai
			_tre = 0.0,         -- giay con lai (DelayTimeThenGoNext / thoai)
			_doi = 0.0,         -- giay da cho mot thong bao (de bo qua khi qua gio)
			_start = nil,       -- ten routine chay luc bat dau tran
			_boss = {},         -- boss -> ten routine (SetEncounterBossMoitor)
			_finish = nil,
			_xong = false,      -- FinishGame da goi
			_loi = nil,         -- loi coroutine (neu co)
		}, KB)
	end

	-- --- dang ky routine ------------------------------------------------------
	-- AddMoitor(ten, trigger): trigger < 0 la moc BAT DAU tran (01_01 dung -2).
	function KB:AddMoitor(ten, trigger)
		self._nhat_ky[#self._nhat_ky + 1] = 'AddMoitor ' .. tostring(ten)
		if type(trigger) == 'number' and trigger < 0 then self._start = ten end
	end
	function KB:SetGameStartMoitor(ten) self._start = ten end
	function KB:SetEncounterBossMoitor(boss, ten) self._boss[tostring(boss)] = ten end
	function KB:SetGameFinishMoitor(ten) self._finish = ten end
	function KB:SetSkipFunc() end
	function KB:BookDramaSprite() end

	-- --- tao / cho don vi kich ban nhap tran --------------------------------
	-- Kich ban tao NPC (dong minh Lang Thong / Trieu Van, hay dich) roi cho
	-- nhap tran. Ta GHI dac ta luc tao, va THEM don vi that luc TakeUnitJoinBattle.
	-- Chi so lay tu NPC config that (GetNpcConfigWithNpcId) theo dataKey
	-- "<NpcID>-<Level>". Nho vay ai co kich ban thang duoc DUNG cach ban goc.
	local function ghi_npc(self, sprite, doi, ten, data_key)
		local spec = { sprite = tostring(sprite or ''), doi = tonumber(doi) or 0,
			data_key = tostring(data_key or '') }
		if ten ~= nil and ten ~= '' then self._npc[tostring(ten)] = spec end
		if spec.sprite ~= '' then self._npc[spec.sprite] = spec end
		self._nhat_ky[#self._nhat_ky + 1] = 'TaoNpc ' .. spec.sprite
		return hinh_nhan
	end
	-- CreateNpcAndMoveTo(sprite, side, offY, x, time, walk, standby, zorder,
	--   name, dataKey, equip, ...)
	function KB:CreateNpcAndMoveTo(sprite, side, _oy, _x, _t, _w, _s, _z, ten, data_key)
		return ghi_npc(self, sprite, side, ten, data_key)
	end
	-- CreateNpcWithAppear(sprite, side, name, dataKey, ...)
	function KB:CreateNpcWithAppear(sprite, side, ten, data_key)
		return ghi_npc(self, sprite, side, ten, data_key)
	end
	-- AddHero(sprite, x, side, id) — chua co dataKey; ghi theo sprite.
	function KB:AddHero(sprite, _x, side, _id)
		return ghi_npc(self, sprite, side, nil, nil)
	end

	-- TakeUnitJoinBattle(nameOrSprite, side, ...): THEM don vi vao tran.
	function KB:TakeUnitJoinBattle(khoa, side, ...)
		local spec = self._npc[tostring(khoa)]
		if spec == nil then
			self._nhat_ky[#self._nhat_ky + 1] = 'JoinBattle ' .. tostring(khoa) .. ' (khong co spec)'
			return
		end
		local npc_id = tonumber((spec.data_key or ''):match('^(%d+)'))
		local cfg = nil
		if npc_id ~= nil and rawget(_G, 'G_ConfigManager') ~= nil then
			local ok, t = pcall(function()
				return G_ConfigManager:GetNpcConfigWithNpcId(npc_id) end)
			cfg = ok and t or nil
		end
		if type(cfg) ~= 'table' then
			self._nhat_ky[#self._nhat_ky + 1] = 'JoinBattle ' .. tostring(khoa)
				.. ' (khong co cfg npc ' .. tostring(npc_id) .. ')'
			return
		end
		-- tran_nut la doi tuong GDScript; phuong thuc cua no khong phai kieu Lua
		-- 'function' (la userdata goi duoc), nen KHONG kiem type — cu pcall.
		local tran = require('cocos').tran_nut
		if tran == nil then
			self._nhat_ky[#self._nhat_ky + 1] = 'JoinBattle ' .. tostring(khoa) .. ' (khong co tran)'
			return
		end
		local ok, js = pcall(cjson.encode, cfg)
		if not ok then
			self._nhat_ky[#self._nhat_ky + 1] = 'JoinBattle ' .. tostring(khoa) .. ' (encode loi)'
			return
		end
		local doi = tonumber(side) or spec.doi or 0
		local okd, kq = pcall(function() return tran:dua_dong_minh(spec.sprite, doi, js) end)
		self._nhat_ky[#self._nhat_ky + 1] = 'JoinBattle ' .. tostring(khoa)
			.. ' -> ' .. tostring(okd and kq)
	end
	-- TakeUnitExpeBattle: dua vao "cho" (dung im); o day coi nhu nhap tran luon.
	KB.TakeUnitExpeBattle = KB.TakeUnitJoinBattle

	-- MakeUnitToPlotSprite(sprite, side, ...): danh dau don vi thanh do KICH BAN
	-- dieu khien — rut khoi giao tranh thuong. Ben dich (boss Lu Bo) rut ra thi
	-- ben ta don sach dam con lai. Khop theo ten armature (sprite).
	function KB:MakeUnitToPlotSprite(sprite, side, ...)
		self._nhat_ky[#self._nhat_ky + 1] = 'PlotSprite ' .. tostring(sprite)
		local tran = require('cocos').tran_nut
		if tran ~= nil then
			local ok, n = pcall(function()
				return tran:xoa_theo_hinh(tostring(sprite), tonumber(side) or 1) end)
			self._nhat_ky[#self._nhat_ky + 1] = 'PlotSprite xoa ' .. tostring(ok and n)
		end
		return hinh_nhan
	end

	-- --- chay coroutine -------------------------------------------------------
	local function than(ten)
		local f = rawget(_G, ten)
		return type(f) == 'function' and f or nil
	end

	-- Bat dau routine ten `ten` (coroutine). Tra true neu co routine.
	function KB:_chay(ten)
		local f = than(ten)
		if f == nil then return false end
		self._co = coroutine.create(f)
		self:_tiep()
		return true
	end

	-- Danh thuc coroutine mot buoc (toi yield ke tiep). Sau khi ham dan canh
	-- giua hai yield co the dat lai _cho / _tre.
	function KB:_tiep()
		if self._co == nil or coroutine.status(self._co) == 'dead' then
			self._co = nil
			return
		end
		self._cho = nil
		self._doi = 0.0
		local ok, err = coroutine.resume(self._co)
		if not ok then
			self._loi = tostring(err)
			self._nhat_ky[#self._nhat_ky + 1] = 'LOI ' .. self._loi:sub(1, 200)
			self._co = nil
		elseif coroutine.status(self._co) == 'dead' then
			self._co = nil
		end
	end

	-- Lop phu HUONG DAN tan thu (g_CGuideLogical) ve nut sang, hop meo, o chu:
	-- can node UI cua man huong dan ma tran khong dung len. Bit thanh no-op de
	-- kich ban chay tiep — hieu ung chi dan la ĐẶT (khong ve). Giu lai
	-- GetCharacter* / SetSceneCanTouch vi kich ban doc gia tri tu chung.
	local GUIDE_UI = {
		'ShowTipsDialog', 'RemoveTipsDialog', 'SetHighlightBattle', 'RemoveHighlight',
		'ShowPromptBox', 'DeletePromptBox', 'ShowPromBox', 'ShowGuideDialog',
	}
	function KB:vo_hieu_guide()
		local g = rawget(_G, 'g_CGuideLogical')
		if g == nil then return end
		for _, ten in ipairs(GUIDE_UI) do
			g[ten] = function() end
		end
		-- Am thanh chi dan: ham toan cuc, khong can UI.
		if type(rawget(_G, 'g_PlayGuideVoice')) ~= 'function' then
			g_PlayGuideVoice = function() end
		end
	end

	-- Chay moc bat dau tran (goi tu san_tran khi _Lua_StartGame co kich ban).
	function KB:bat_dau_kich_ban()
		self:vo_hieu_guide()
		if self._start ~= nil then return self:_chay(self._start) end
		return false
	end

	function KB:ExecutePlot(ten)
		self._nhat_ky[#self._nhat_ky + 1] = 'ExecutePlot ' .. tostring(ten)
		self:_chay(ten)
	end

	-- BeginPlot / StartGame: yield ngay sau chung se di tiep o khung ke tiep.
	-- Goi mot phuong thuc cua tran co hinh (tran_nut) an toan.
	local function goi_tran(ham, ...)
		local tran = require('cocos').tran_nut
		if tran == nil then return end
		local args = { ... }
		pcall(function() tran[ham](tran, table.unpack(args)) end)
	end

	function KB:BeginPlot() self._cho = { kieu = 'ngay' } end
	function KB:StartGame()
		self._cho = { kieu = 'ngay' }
		goi_tran('theo_lai')      -- camera bam quan tro lai sau canh mo
	end

	-- Tuyet chieu theo kich ban: SetRoleChangeFight(sprite, side, form, action).
	-- Trieu Van "that tien that xuat" (action "Wake") -> AoE len dich; boss thi
	-- chi dien. so_don = 3 la DAT (hieu ung that trong C++), sat thuong moi don
	-- dung chi so + cong thuc THAT.
	function KB:SetRoleChangeFight(sprite, side, _form, action)
		self._nhat_ky[#self._nhat_ky + 1] = 'ChangeFight ' .. tostring(sprite)
			.. ' ' .. tostring(action)
		goi_tran('tuyet_chieu', tostring(sprite), tonumber(side) or 0,
			tostring(action or ''), 3)
		self._wake_xong = true
		return hinh_nhan
	end

	-- CameraMoveBy(huong, giay): lia camera canh dien anh. SetCameraScale: chua
	-- lam (thu phong lam lech toa do cham) — ghi lai.
	function KB:CameraMoveBy(huong)
		self._nhat_ky[#self._nhat_ky + 1] = 'CameraMoveBy ' .. tostring(huong)
		goi_tran('lia_camera', tonumber(huong) or 0)
		return hinh_nhan
	end
	function KB:SetInPlotAndShowDiag() end

	function KB:FinishGame(r)
		self._xong = true
		self._nhat_ky[#self._nhat_ky + 1] = 'FinishGame ' .. tostring(r)
		-- Ket qua tran: san_tran quyet dinh thang/thua thuc su; day chi danh dau.
	end
	KB.EndPlot = KB.FinishGame

	function KB:SkipCurrentPlot()
		-- Chay het coroutine ngay, bo qua moi cho. Tran nao da qua thi ban goc
		-- bo kich ban (CUIGame goi day). Gioi han vong de khong treo.
		self._nhat_ky[#self._nhat_ky + 1] = 'SkipCurrentPlot'
		local n = 0
		while self._co ~= nil and n < 500 do
			self._cho = nil
			self:_tiep()
			n = n + 1
		end
	end

	-- --- thoai ----------------------------------------------------------------
	function KB:ShowDialogue(ten, loi, ...)
		self._thoai[#self._thoai + 1] = { ten = tostring(ten), loi = tostring(loi) }
		self._cho = { kieu = 'thoai' }
		self._tre = CHO_THOAI
	end

	-- --- dieu kien di tiep ----------------------------------------------------
	function KB:DelayTimeThenGoNext(t)
		self._cho = { kieu = 'tre' }
		self._tre = tonumber(t) or 0.0
	end

	function KB:EnableGoNextWhenReceiveNotification(ten, bat)
		if bat then self._cho = { kieu = 'tin', ten = tostring(ten) }
		elseif self._cho and self._cho.kieu == 'tin' then self._cho = nil end
	end
	function KB:EnableGoNextWhenEncounterArmyBegin(bat)
		if bat then self._cho = { kieu = 'quan' }
		elseif self._cho and self._cho.kieu == 'quan' then self._cho = nil end
	end
	function KB:EnableGoNextWhenHeroWakeEnd(bat)
		if bat then
			-- Neu tuyet chieu vua dien xong thi di tiep nhanh (0,3 s) thay vi
			-- cho het gio 6 s.
			if self._wake_xong then
				self._wake_xong = false
				self._cho = { kieu = 'tre' }
				self._tre = 0.3
			else
				self._cho = { kieu = 'thuc_tinh' }
			end
		elseif self._cho and (self._cho.kieu == 'thuc_tinh' or self._cho.kieu == 'tre') then
			self._cho = nil
		end
	end
	function KB:EnableGoNextWhenPutSoldiers(bat)
		if bat then self._cho = { kieu = 'dat_linh' }
		elseif self._cho and self._cho.kieu == 'dat_linh' then self._cho = nil end
	end

	-- --- tin hieu tu tran -----------------------------------------------------
	function KB:bao_tin(ten)
		if self._cho and self._cho.kieu == 'tin' and self._cho.ten == ten then self:_tiep() end
	end
	function KB:gap_quan()
		if self._cho and self._cho.kieu == 'quan' then self:_tiep() end
	end
	function KB:thuc_tinh_xong()
		if self._cho and self._cho.kieu == 'thuc_tinh' then self:_tiep() end
	end
	function KB:dat_linh_xong()
		if self._cho and self._cho.kieu == 'dat_linh' then self:_tiep() end
	end
	-- Ep qua cau thoai hien tai (probe / nguoi choi cham).
	function KB:di_tiep()
		if self._cho and (self._cho.kieu == 'thoai' or self._cho.kieu == 'ngay') then self:_tiep() end
	end

	-- --- buoc theo thoi gian tran --------------------------------------------
	function KB:buoc(dt)
		if self._co == nil then return end
		local ch = self._cho
		if ch == nil then return end
		if ch.kieu == 'ngay' then
			self:_tiep()
		elseif ch.kieu == 'tre' or ch.kieu == 'thoai' then
			self._tre = self._tre - dt
			if self._tre <= 0.0 then self:_tiep() end
		else
			-- Cho su kien tran (tin / quan / thuc_tinh / dat_linh). Neu tran gia
			-- khong bao trong CHO_TOI_DA giay thi tu qua, danh dau qua gio.
			self._doi = self._doi + dt
			if self._doi >= CHO_TOI_DA then
				self._nhat_ky[#self._nhat_ky + 1] = 'qua gio ' .. tostring(ch.kieu)
				self:_tiep()
			end
		end
	end

	-- --- do / kiem ------------------------------------------------------------
	function KB:dang_chay() return self._co ~= nil end
	function KB:so_thoai() return #self._thoai end
	function KB:loi() return self._loi end
	function KB:nhat_ky() return table.concat(self._nhat_ky, ' > ') end
	function KB:chuoi_thoai()
		local o = {}
		for i, t in ipairs(self._thoai) do o[i] = t.ten .. ': ' .. t.loi end
		return table.concat(o, ' | ')
	end

	return M
end
