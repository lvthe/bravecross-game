-- He action cua Cocos2d-x, lam lai bang Lua thuan.
--
-- Ban goc dung rat nhieu: S_CCSequence 659 lan, S_CCCallFunc 559,
-- S_CCDelayTime 486, S_CCScaleTo 297, S_CCMoveTo 280... Thieu he nay thi moi
-- man hinh deu dung hinh — khong hien ra, khong tat di, khong chay gi.
--
-- KHONG dung Tween cua Godot. Tween doi node phai nam trong scene tree, ma
-- ta con dung node ngoai tree (dung bo cuc roi kiem, chup anh). Va Cocos co
-- nhung thu Tween khong co san: CCSpawn chay song song roi cho tat ca xong,
-- CCRepeatForever, va CCCallFunc goi method theo TEN. Tu lam thi khop dung
-- ngu nghia goc, va de doc khi so voi ma goc.
--
-- Moi action deu co mot giao dien:
--     a:tien(node, dt) -> xong chua
--     a:dat_lai()
-- Nen xep chuoi, chay song song hay lap lai deu chi la boc lai cai khac.

return function(C)
	local raw = C.raw
	local M = {}

	-- Nhung action dang chay: { node = <node Godot>, a = <action> }
	local dang_chay = {}
	M.dang_chay = dang_chay

	-- Bo phan tu thu i khoi hang doi: doi cho voi phan tu CUOI roi cat duoi,
	-- KHONG don het ve truoc.
	--
	-- Day dung la ccArrayRemoveObjectAtIndex cua Cocos2d-x, va la thu lam cho
	-- vong lap cua M.tick dung duoc khi hang doi bi doi ngay giua chung: mot
	-- ham tien goi stopAllActions/runAction se lam hang doi doi ngay trong luc
	-- dang duyet. Truoc day cho nay dung table.remove (don het ve truoc) va do
	-- la loi THAT, do duoc bang tools/verify_cuon.gd:
	--
	--   CPublic:SetMaskIsEnable('lNormalDlgMask', false) dat len lop phu mot
	--   chuoi CCFadeTo(0.2,0) + CCHide; chuoi do bi cat ngay trong chinh khung
	--   no duoc dat (khong chay lan nao, khong ghi loi nao), nen lop phu dong
	--   hop thoai ket thuc o vis=true op=0 va NUOT moi cu cham sau do.
	--   Do la 3 phep kiem hong cua bo do cuon lop thanh pho.
	local function bo_tai_cho(i)
		local cuoi = #dang_chay
		dang_chay[i] = dang_chay[cuoi]
		dang_chay[cuoi] = nil
	end

	-- Action co ban ---------------------------------------------------------

	local function co_ban(d)
		return {
			d = d or 0, t = 0, bat_dau = false,
			dat_lai = function(self)
				self.t = 0
				self.bat_dau = false
			end,
			tien = function(self, node, dt)
				if not self.bat_dau then
					self.bat_dau = true
					if self.khoi then self:khoi(node) end
				end
				self.t = self.t + dt
				local p = 1.0
				if self.d > 0 then
					p = self.t / self.d
					if p > 1 then p = 1 end
				end
				if self.giam_toc then p = self.giam_toc(p) end
				if self.chay then self:chay(node, p) end
				return self.t >= self.d
			end,
		}
	end

	local function lam(d, khoi, chay)
		local a = co_ban(d)
		a.khoi, a.chay = khoi, chay
		return a
	end

	-- Di chuyen, co gian, xoay, mo dan ---------------------------------------

	local function moveTo(d, x, y)
		return lam(d,
			function(self, n) self.x0, self.y0 = C.Node.getPosition(n) end,
			function(self, n, p)
				C.Node.setPosition(n, self.x0 + (x - self.x0) * p,
				                      self.y0 + (y - self.y0) * p)
			end)
	end

	local function moveBy(d, dx, dy)
		return lam(d,
			function(self, n) self.x0, self.y0 = C.Node.getPosition(n) end,
			function(self, n, p)
				C.Node.setPosition(n, self.x0 + dx * p, self.y0 + dy * p)
			end)
	end

	local function scaleTo(d, sx, sy)
		sy = sy or sx
		return lam(d,
			function(self, n)
				self.a0, self.b0 = C.Node.getScaleX(n), C.Node.getScaleY(n)
			end,
			function(self, n, p)
				C.Node.setScaleX(n, self.a0 + (sx - self.a0) * p)
				C.Node.setScaleY(n, self.b0 + (sy - self.b0) * p)
			end)
	end

	local function rotateTo(d, deg)
		return lam(d,
			function(self, n) self.r0 = C.Node.getRotation(n) end,
			function(self, n, p)
				C.Node.setRotation(n, self.r0 + (deg - self.r0) * p)
			end)
	end

	local function rotateBy(d, deg)
		return lam(d,
			function(self, n) self.r0 = C.Node.getRotation(n) end,
			function(self, n, p) C.Node.setRotation(n, self.r0 + deg * p) end)
	end

	-- Cocos dung do mo 0..255.
	local function fadeTo(d, o)
		return lam(d,
			function(self, n) self.o0 = C.Node.getOpacity(n) end,
			function(self, n, p)
				C.Node.setOpacity(n, self.o0 + (o - self.o0) * p)
			end)
	end

	-- Ghep ------------------------------------------------------------------

	local function sequence(ds)
		local a = { i = 1, ds = ds }
		function a:dat_lai()
			self.i = 1
			for _, x in ipairs(self.ds) do x:dat_lai() end
		end
		function a:tien(node, dt)
			while self.i <= #self.ds do
				if self.ds[self.i]:tien(node, dt) then
					self.i = self.i + 1
					dt = 0      -- phan con lai cua khung nay khong don sang
				else
					return false
				end
			end
			return true
		end
		return a
	end

	local function spawn(ds)
		local a = { ds = ds }
		function a:dat_lai()
			self.xong = nil
			for _, x in ipairs(self.ds) do x:dat_lai() end
		end
		function a:tien(node, dt)
			self.xong = self.xong or {}
			local het = true
			for k, x in ipairs(self.ds) do
				if not self.xong[k] then
					if x:tien(node, dt) then self.xong[k] = true else het = false end
				end
			end
			return het
		end
		return a
	end

	local function lap(x, n)
		local a = { x = x, con = n, dau = n }
		function a:dat_lai() self.con = self.dau; self.x:dat_lai() end
		function a:tien(node, dt)
			if self.x:tien(node, dt) then
				if self.con == nil then           -- lap mai
					self.x:dat_lai()
					return false
				end
				self.con = self.con - 1
				if self.con <= 0 then return true end
				self.x:dat_lai()
			end
			return false
		end
		return a
	end

	-- Goi ham theo TEN: S_CCCallFunc:create(doi_tuong, "TenHam", thamso)
	local function callFunc(doi_tuong, ten, tham)
		local a = co_ban(0)
		a.chay = function(self, node)
			if self.da_goi then return end
			self.da_goi = true
			if doi_tuong == nil or ten == nil then return end
			local f = doi_tuong[ten]
			if type(f) == 'function' then
				-- GHI loi lai, dung nuot: hop thoai cua ban goc ket thuc hoat
				-- canh mo bang CCCallFunc(OnShowAnimationFinish), va ham do chi
				-- PopAnimation o CUOI (CUIManager.lua:951). Loi o giua ma nuot
				-- thi hang doi hoat canh ket mai, moi Show sau im lang khong mo.
				local ok, loi = pcall(f, doi_tuong, tham ~= nil and tham or node)
				if not ok and C.loi_hen then
					C.loi_hen[#C.loi_hen + 1] = 'CCCallFunc ' .. tostring(ten) .. ': ' .. tostring(loi)
				end
			end
		end
		local dat_lai_cu = a.dat_lai
		a.dat_lai = function(self) self.da_goi = false; dat_lai_cu(self) end
		return a
	end

	-- Giam toc ---------------------------------------------------------------

	local function boc_giam_toc(x, f)
		-- Boc mot action co san: chi doi cach thoi gian troi, khong doi dich.
		x.giam_toc = f
		return x
	end

	local vao      = function(p) return p * p end
	local ra       = function(p) return 1 - (1 - p) * (1 - p) end
	local vao_ra   = function(p)
		if p < 0.5 then return 2 * p * p end
		return 1 - 2 * (1 - p) * (1 - p)
	end

	-- Dang ky vao bien toan cuc --------------------------------------------
	-- Ban goc goi qua cac thuc the S_CC*, vi du:
	--     S_CCSequence:create(S_CCDelayTime:create(0.5), S_CCFadeOut:create(0.3))

	-- NHAN cua action. Ban goc danh dau hoat canh mo/dong hop thoai bang
	-- setTag(5564) roi sau do huy dung cai do bang stopActionByTag — neu huy
	-- het thi giet ca nhung hoat canh khac dang chay tren cung node.
	local function gan_nhan(a)
		if type(a) ~= 'table' or a.setTag ~= nil then return a end
		a.setTag = function(self, t) self.tag = t end
		a.getTag = function(self) return self.tag or -1 end
		-- Dem tham chieu cua Cocos: Godot tu lo doi song, chi can khong hong.
		a.retain = function(self) return self end
		a.release = function() end
		a.autorelease = function(self) return self end
		return a
	end

	local function thuc_the(tao)
		local f = function(_, ...) return gan_nhan(tao(...)) end
		return { create = f, actionWithDuration = f, actionWithAction = f,
		         action = f, release = function() end }
	end

	local function gom(...)
		local ds = {}
		for _, x in ipairs({ ... }) do
			if type(x) == 'table' and x.tien then ds[#ds + 1] = x end
		end
		return ds
	end

	function M.install()
		S_CCDelayTime   = thuc_the(function(d) return co_ban(d) end)
		S_CCMoveTo      = thuc_the(moveTo)
		S_CCMoveBy      = thuc_the(moveBy)
		S_CCScaleTo     = thuc_the(scaleTo)
		S_CCScaleBy     = thuc_the(function(d, sx, sy) return scaleTo(d, sx, sy) end)
		S_CCRotateTo    = thuc_the(rotateTo)
		S_CCRotateBy    = thuc_the(rotateBy)
		S_CCFadeTo      = thuc_the(fadeTo)
		S_CCFadeIn      = thuc_the(function(d) return fadeTo(d, 255) end)
		S_CCFadeOut     = thuc_the(function(d) return fadeTo(d, 0) end)
		S_CCWhiteFadeTo = thuc_the(fadeTo)
		S_CCShow        = thuc_the(function()
			return lam(0, nil, function(_, n) C.Node.setIsVisible(n, true) end)
		end)
		S_CCHide        = thuc_the(function()
			return lam(0, nil, function(_, n) C.Node.setIsVisible(n, false) end)
		end)
		S_CCCallFunc    = thuc_the(callFunc)
		S_CCSequence    = thuc_the(function(...) return sequence(gom(...)) end)
		S_CCSpawn       = thuc_the(function(...) return spawn(gom(...)) end)
		S_CCRepeatForever = thuc_the(function(x) return lap(x, nil) end)
		S_CCRepeat      = thuc_the(function(x, n) return lap(x, n) end)

		for ten, f in pairs({ S_CCEaseIn = vao, S_CCEaseOut = ra,
		                      S_CCEaseInOut = vao_ra,
		                      S_CCEaseSineIn = vao, S_CCEaseSineOut = ra,
		                      S_CCEaseSineInOut = vao_ra,
		                      S_CCEaseExponentialIn = vao,
		                      S_CCEaseExponentialOut = ra,
		                      S_CCEaseExponentialInOut = vao_ra,
		                      S_CCEaseBackIn = vao, S_CCEaseBackOut = ra,
		                      S_CCEaseBackInOut = vao_ra,
		                      S_CCEaseElasticIn = vao, S_CCEaseElasticOut = ra,
		                      S_CCEaseElasticInOut = vao_ra,
		                      S_CCEaseBounceIn = vao, S_CCEaseBounceOut = ra,
		                      S_CCEaseBounceInOut = vao_ra }) do
			_G[ten] = thuc_the(function(x) return boc_giam_toc(x, f) end)
		end
	end

	-- Chay ------------------------------------------------------------------

	function M.runAction(node, a)
		if a == nil or type(a) ~= 'table' or a.tien == nil then
			return a
		end
		a:dat_lai()
		dang_chay[#dang_chay + 1] = { node = node, a = a }
		return a
	end

	function M.stopAllActions(node)
		local gd = raw(node)
		for i = #dang_chay, 1, -1 do
			if raw(dang_chay[i].node) == gd then
				bo_tai_cho(i)
			end
		end
	end

	-- Chi huy action MANG DUNG NHAN do. Ban goc dung de cat hoat canh mo hop
	-- thoai dang do (CUIManager.lua:801, 1330, 1356) ma khong dung cac hoat
	-- canh khac tren cung node.
	function M.stopActionByTag(node, tag)
		local gd = raw(node)
		for i = #dang_chay, 1, -1 do
			local m = dang_chay[i]
			if raw(m.node) == gd and m.a.tag == tag then
				bo_tai_cho(i)
			end
		end
	end

	function M.getActionByTag(node, tag)
		local gd = raw(node)
		for i = 1, #dang_chay do
			local m = dang_chay[i]
			if raw(m.node) == gd and m.a.tag == tag then return m.a end
		end
		return nil
	end

	-- Tam dung / chay lai ----------------------------------------------------
	-- Ten `pauseActions`/`resumeActions` trong ban goc KHONG chi dung action:
	-- `CCNode::pauseActions` goi `pauseSchedulerAndActions` cua Cocos, tuc la
	-- dung CA bo quan ly action LAN bo hen gio cua node. Do duoc trong
	-- `libgame.so` (in lai bang `brave-cross/work/binder.py --nut`):
	--   +0xdc = bo quan ly action   (runAction/stopAllActions/stopActionByTag/
	--                                getActionByTag/numberOfRunningActions deu
	--                                doc dung o nay)
	--   +0xd8 = bo hen gio          (khong mot ham action nao doc no)
	--   +0xe0 = m_bRunning, va ca runAction lan schedule truyen `!m_bRunning`
	--           xuong (`ldrb r3,[r0,#0xe0]` roi `eor r3,r3,#1`) — nhan ra duoc
	--           nho chinh phep phu dinh do, dung chu ky cua Cocos.
	-- `pauseActions` (0x4aeb88) va `resumeActions` (0x4aeacc) goi CA HAI o.
	-- Phan hen gio nam o `lich` trong cocos.lua; o day lam phan action.
	--
	-- Danh dau TUNG MUC dang chay chu khong bo khoi danh sach, va khung hinh
	-- tam dung KHONG cong don thoi gian — nho vay luc chay lai khong nhay mot
	-- buoc. Chi danh dau muc DANG CO: action chay sau khi da tam dung thi chay
	-- binh thuong, dung nhu Cocos (`pauseTarget` khong doi `m_bRunning`).
	function M.pauseActions(node)
		local gd = raw(node)
		local n = 0
		for i = 1, #dang_chay do
			local m = dang_chay[i]
			if raw(m.node) == gd then
				m.tam_dung = true
				n = n + 1
			end
		end
		return n
	end

	function M.resumeActions(node)
		local gd = raw(node)
		local n = 0
		for i = 1, #dang_chay do
			local m = dang_chay[i]
			if raw(m.node) == gd and m.tam_dung then
				m.tam_dung = nil
				n = n + 1
			end
		end
		return n
	end

	-- Goi moi khung hinh tu GDScript. Tra ve so action con dang chay.
	function M.tick(dt)
		local i = 1
		while i <= #dang_chay do
			local m = dang_chay[i]
			local gd = raw(m.node)
			-- is_instance_valid la ham TOAN CUC cua Godot, khong phai phuong
			-- thuc cua node. Goi kieu gd:is_instance_valid(gd) thi Lua bao
			-- 'attempt to call a nil value' va ca he action dung im.
			-- Van kiem tra ca khi dang tam dung: muc cua node da bi xoa van
			-- phai duoc don, khong thi o lai trong danh sach mai.
			local bo = gd == nil or not is_instance_valid(gd)
			if (not bo) and not m.tam_dung then
				local ok, xong = pcall(m.a.tien, m.a, m.node, dt)
				bo = (not ok) or xong
				if not ok and C.loi_hen then
					C.loi_hen[#C.loi_hen + 1] = 'action: ' .. tostring(xong)
				end
			end
			if bo then
				bo_tai_cho(i)
				-- KHONG tang i: phan tu cuoi vua bi doi xuong cho i, no chua
				-- duoc xet trong khung nay.
			else
				i = i + 1
			end
		end
		return #dang_chay
	end

	return M
end
