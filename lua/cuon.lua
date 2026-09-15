-- CCScrollLayer gia: lop CUON cua engine (typeName 'CCScrollLayer', type 7
-- trong .xgg; 315 node trong 296 file bo cuc).
--
-- VI SAO CAN. Lop thanh pho o Main — g_MainUIScrollLayer — la lop nay, va bon
-- ham cham/cuon ma CUIMain dang ky (CUIMain.lua:1682-1695) deu la BONG RONG,
-- trong chi co mot dong chu thich:
--
--   function CUIMain:onTouchBegin_slMainUIScrollLayer(obj) --KDebug.PrintDebug("滑动层点击 开始") end
--   function CUIMain:onScrollLayerBegin()                  --KDebug.PrintDebug("滑动开始") end
--
-- Nghia la viec cuon thanh pho nam HOAN TOAN ben engine: Lua chi bao engine
-- bat cuon (CUIMain.lua:154-155 setMarginSpace/setIsElastic/setLuaCallbackForDrag)
-- chu khong tu lam. Khong co lop nay thi thanh pho dung yen, va vi vay KHONG
-- VOI TOI DUOC cac nha ben phai — trong do co ai vo tan.
--
-- SO DO LAY TU DAU. Bang dang ky phuong thuc cua chinh engine nam o .data
-- 0x93386c (32 muc, 12 byte/muc: {ten, ham, word3}), ban sao thu hai o
-- 0x9354e4. Con tro ham mang BIT THUMB (le), phai `& ~1` truoc khi dich. Moi
-- con so duoi day doc tu vung/apk/lib/armeabi-v7a/libgame.so (md5
-- 245edda25e1b211b42312c08d19d2849) bang work/armdis.py:
--
--   setMarginSpace       0x2c01d6   self[+0x1bc] = (float)luaL_checknumber(L,1)
--   setIsCropDraw         0x2c0464   self[+0x1b0] = lua_toboolean(L,1)
--   setVerticalDirection 0x2c04e6   self[+0x1af] = ...
--   setIsElastic         0x2c0448   goi ao vtable+0x2d4
--   setBerthAnchor       0x2c01b8   self[+0x1b4] = (float)
--   resetContentLayerPos 0x2c1b68   core(self, luaL_checknumber(L,1)) — khong
--                                   truyen tham so thi 0 (0x23bf40 = lua_gettop
--                                   chan truoc, xem 0x2c1b74..0x2c1b94)
--   resetContent         0x2c1bb4   core(self, 0.0f) roi 0x2c0a8c(self, 1)
--   core                 0x2c1ab8   content[axis] = percent + f
--
-- `core` doc them hai cho nua: +0x1dc = node CONTENT (lop con giu moi muc),
-- +0x245 = co cho tinh be rong cuon, +0x1af = co truc DOC. Khi +0x245 TAT thi
-- f = 0.0f (literal o 0x2c1b64, xem 0x2c1b36), tuc `content[axis] = percent` —
-- va `resetContentLayerPos()` khong tham so dua content ve 0 theo dung truc do.
-- Do la co so cho cach lam `resetContentLayerPos` o day.
--
-- CAI GI KHONG DOC DUOC (dung bia):
--   * `f` trong core khi +0x245 BAT: no la co lop tru `self[+0x1bc]` (le) tru
--     `0x2c18da(self, x, 1.0f)`. Ham `0x2c18da` chua giai het trong dot nay,
--     nen nhanh do KHONG duoc dung lai — o day chi lam nhanh `f = 0`, dung
--     nhanh ma ty le lon cac lop roi vao.
--   * He BERTH (setBerthAnchor/setBerthScale/getBerthNumber/autoArrange/
--     unfoldMoveTo/autoMoveBy): da dem tren ca ma Lua goc — 0 cho goi cho tung
--     cai — nen khong dung tới.
--   * Vat ly luc nha tay (elastic): khong doc duoc hang so. Xem ĐẶT duoi day.
--
-- HE TRUC. Ta giu gia tri cuon (`lech`) trong KHONG GIAN GODOT cua lop (goc
-- tren-trai, y huong xuong) vi `position` cua con cung o khong gian do — khoi
-- doi qua doi lai. Truc DOC thi chieu lech nguoc voi Cocos (Cocos y huong len),
-- nen dau cua le o truc doc bi lat: xem `mien`.

--[[ ĐẶT — ba cho khong doc duoc tu ban goc, ghi ro de lan sau do lai:

  1. NGUONG KEO = 12 px (cocos). Duoi nguong thi van la mot cu BAM: nut duoc
     an nhu thuong. Ban goc chia tay bam voi tay keo o dau thi nam trong C++
     (khong co trong bang phuong thuc), nen con so nay la cua ta. Chon 12 vi no
     lon hon rung tay khi bam ma nho hon mot lan keo that.
  2. THOI GIAN NHA VE = 0.2 giay khi `setIsElastic(true)` va da keo qua bien.
     Ban goc chay hieu ung nha (khong dat ngay) nhung hang so nam trong
     `0x2c0d34`/`0x2c18da` — chua giai. Ta noi suy 0.2 giay kieu ease-out, 12
     khung o 60 Hz.
  3. MAC DINH TRUC = NGANG. Bon cho goi `setVerticalDirection` trong ca ma goc
     deu noi ro y dinh (CUIEpicChapter/CUIEpicScienceLayer/CUIEpicSel/CUIZF),
     con lai khong goi. Suy ra: lop thanh pho o Main khong he goi ham do ma
     cuon NGANG, nen mac dinh cua engine la ngang. Them mot luat chong hut:
     neu truc dang chon khong co gi de cuon ma truc kia co, thi doi truc —
     luat nay chi chay khi truc mac dinh cuon duoc 0 px, nen khong the lam hong
     mot lop dang cuon duoc.
]]

-- CHUA LAM, noi ro: `setIsCropDraw` MOI GHI CO, khong cat hinh that. Bat
-- `clip_contents` tren Control se doi CA BO LOC CHAM — LuaRuntime._ung_vien
-- (game/lua_runtime.gd:640) coi `clip_contents` la bien cua o, nen moi thu ve
-- tran ra ngoai o do se tro thanh khong bam duoc. 12 cho goi
-- setIsCropDraw(true) trong ma goc; doi hanh vi cham cua 12 man mot luc thi
-- phai do rieng, khong gop vao dot nay.

return function(C)
	local S = setmetatable({}, { __index = C.Node })

	local NGUONG = 12.0
	-- 12 khung o 60 Hz = 0.2 giay (ĐẶT 2).
	local SO_KHUNG_NHA = 12

	-- Trang thai theo tung lop, khoa theo instance_id cua node Godot. Node UI
	-- song gan het phien, va so lop cuon bi cham trong mot phien chi vai tram,
	-- nen khong don rac.
	local tt = {}
	local keo = nil     -- lan keo dang dien ra (mot cai mot luc)

	-- Diem moc goi khi mot cu BAM ket thuc (Begin + End, khong keo qua nguong)
	-- tren mot lop cuon. Lop cuon khong biet gi ve o danh sach, nen phan
	-- `tableCellTouched` cua CCTableView do lua/bang.lua gan vao day.
	local moc_bam = {}

	local function lay(gd)
		local id = gd:get_instance_id()
		local t = tt[id]
		if t == nil then
			t = {
				gd = gd,
				id = id,
				bat = true,       -- enableScroll; mac dinh BAT (xem ĐẶT 3)
				doc = false,      -- setVerticalDirection; mac dinh NGANG
				doc_that = false, -- truc dang dung (co the doi — xem chon_truc)
				mot_truc = false, -- tat phep thu truc kia (xem dat_mot_truc)
				le = 0.0,         -- setMarginSpace
				neo = 0.0,        -- setBerthAnchor (chi ghi co)
				cat = false,      -- setIsCropDraw (chi ghi co)
				dan = false,      -- setIsElastic
				ten_bat = '',     -- setLuaCallbackForDrag: ham luc bat dau keo
				ten_ket = '',     -- setLuaCallbackForDrag: ham luc nha tay
				lech = 0.0,       -- do lech dang ap, theo truc dang dung
				goc = {},         -- id con -> vi tri GOC luc chua cuon (Godot)
				dang_nha = false,
				dem_nha = 0,
				dau_nha = 0.0,
				dich = 0.0,
			}
			tt[id] = t
		end
		return t
	end

	local function so_con(gd) return gd:get_child_count() end
	local function con_tai(gd, i) return gd:get_child(i) end

	--[[ LOP CON GIAO DIEN (content layer) cua ban goc.

		Ban goc khong cuon tung muc rieng le: no giu mot lop con lam "content
		layer" (+0x1dc — xem `core` o 0x2c1ad6 va 0x2c1b4a) roi doi cho lop do.
		O day nhan ra no bang luat: LOP CON DUY NHAT.

		Vi sao luat do dung: o Main, g_MainUIScrollLayer co dung mot con —
		CCParallaxNode 2300x768 chua ca 32 lop canh va 18 nut nha. Cuon lop con
		do chinh la cuon thanh pho. Con voi mot danh sach do Lua dung luc chay
		(280/315 lop CCScrollLayer trong .xgg KHONG co con nao, moi muc do Lua
		them vao sau), ban goc boc chung vao content layer cua no — ta khong boc,
		nen truong hop do cuon thang tung con.

		`muc_tieu` = node bi doi cho; `berth` = danh sach muc de danh so.
	]]
	local function muc_tieu(gd, ra)
		local n = so_con(gd)
		if n == 1 then
			ra[1] = con_tai(gd, 0)
			return 1
		end
		for i = 1, n do ra[i] = con_tai(gd, i - 1) end
		return n
	end

	-- Danh sach muc de danh so (ImmediateMoveTo/autoMoveTo). Xem `muc_tieu`.
	local function berth(gd, ra)
		local n = so_con(gd)
		local goc = (n == 1) and con_tai(gd, 0) or gd
		local m = so_con(goc)
		for i = 1, m do ra[i] = con_tai(goc, i - 1) end
		return m
	end

	-- Vi tri GOC cua con: giu lai lan dau nhin thay, TRUOC khi co do lech nao.
	-- Lua goc co the tu dat lai cho mot con sau do (vd xep lai danh sach), nen
	-- moi lan doc ta kiem: vi tri hien tai co dung bang goc + lech khong, khong
	-- thi lay vi tri hien tai lam goc moi. Nho vay khong con nao bi "nhay ve"
	-- vi mot phep dat lai cua Lua.
	--
	-- PHAI goi bang do lech DANG AP (t.lech), khong phai do lech sap dat: day
	-- lech moi xuong roi moi so sanh thi phep kiem luon thay lech va tu nhan vi
	-- tri vua dat lam goc moi — goc troi moi lan nha ve bien. Vi vay
	-- `day_lech(gd, t, moi)` doc goc TRUOC roi moi ghi `t.lech = moi`.
	local function goc_cua(t, c)
		local lech = t.lech
		-- Chi MOT truc bi doi, truc kia dung yen — so sanh ca hai truc voi cung
		-- mot do lech thi truc dung yen bao lech sai moi lan va goc tu doi moi
		-- lan doc.
		local dx = t.doc_that and 0.0 or lech
		local dy = t.doc_that and lech or 0.0
		local id = c:get_instance_id()
		local g = t.goc[id]
		if g == nil then
			g = { x = c.position.x, y = c.position.y }
			t.goc[id] = g
			return g
		end
		if math.abs(c.position.x - (g.x + dx)) > 0.5
				or math.abs(c.position.y - (g.y + dy)) > 0.5 then
			g.x = c.position.x - dx
			g.y = c.position.y - dy
		end
		return g
	end

	-- Hop cua NOI DUNG (hop cua cac node bi doi cho), trong khong gian Godot
	-- cua lop. Tra ve nil neu lop khong co con nao.
	local function hop_noi_dung(t, gd)
		local ds = {}
		local n = muc_tieu(gd, ds)
		if n == 0 then return nil end
		local x0, y0 = math.huge, math.huge
		local x1, y1 = -math.huge, -math.huge
		for i = 1, n do
			local c = ds[i]
			local g = goc_cua(t, c)
			if g.x < x0 then x0 = g.x end
			if g.y < y0 then y0 = g.y end
			if g.x + c.size.x > x1 then x1 = g.x + c.size.x end
			if g.y + c.size.y > y1 then y1 = g.y + c.size.y end
		end
		return x0, y0, x1, y1
	end

	-- Khoang lech hop le theo mot truc, hoac nil neu truc do khong cuon duoc.
	-- Cong thuc: mep noi dung khong duoc roi khoi mep lop qua mot khoang `le`.
	-- Le +0x1bc la so COCOS; truc ngang thi Cocos voi Godot cung chieu, truc
	-- doc thi nguoc (Cocos y huong len) — nen o truc doc lat dau.
	local function mien(t, gd, doc)
		local x0, y0, x1, y1 = hop_noi_dung(t, gd)
		if x0 == nil then return nil end
		local o0, o1, dai, le
		if doc then
			o0, o1, dai, le = y0, y1, gd.size.y, -t.le
		else
			o0, o1, dai, le = x0, x1, gd.size.x, t.le
		end
		-- Noi dung khong lon hon o thi khong co gi de cuon.
		if o1 - o0 <= dai + 0.001 then return nil end
		-- lech = 0 la vi tri GOC; keo ve phia truoc (lech am) toi khi mep sau
		-- cham mep lop, keo ve phia sau (lech duong) toi khi mep truoc cham.
		local thap = dai - o1 - le
		local cao = -o0 + le
		if thap > cao then return nil end
		return thap, cao
	end

	local function kep(x, thap, cao)
		if x < thap then return thap end
		if x > cao then return cao end
		return x
	end

	-- Chon truc: truc da dat, nhung neu truc do khong cuon duoc thi thu truc
	-- kia (xem ĐẶT 3).
	local function chon_truc(gd, t)
		t.doc_that = t.doc
		if t.mot_truc then return end
		if mien(t, gd, t.doc_that) == nil and mien(t, gd, not t.doc_that) ~= nil then
			t.doc_that = not t.doc
		end
	end

	-- Day do lech `moi` xuong cac node bi doi cho, roi moi ghi nhan no. Tra ve
	-- so node da day. Goc doc TRUOC khi ghi — xem `goc_cua`.
	local function day_lech(gd, t, moi)
		local ds = {}
		local n = muc_tieu(gd, ds)
		local doc = t.doc_that
		for i = 1, n do
			local c = ds[i]
			local g = goc_cua(t, c)
			local x, y = g.x, g.y
			if doc then y = y + moi else x = x + moi end
			c.position = Vector2(x, y)
		end
		t.lech = moi
		return n
	end

	-- Goi ham Lua da dang ky bang setLuaCallbackForDrag. Doi tuong nhan la DOI
	-- TUONG CHAM cua chinh lop (CUIMain cho g_MainUIScrollLayer) — cung doi
	-- tuong ma engine goi <doi tuong>:onTouchEnd_<ten cham> tren do.
	local function goi_lai(gd, ten)
		if ten == nil or ten == '' then return end
		local obj = C.doi_tuong_cham[gd:get_instance_id()]
		if type(obj) ~= 'table' then return end
		local f = obj[ten]
		if type(f) ~= 'function' then return end
		local ok, err = pcall(f, obj, C.wrap(gd))
		if not ok then
			C.loi_hen[#C.loi_hen + 1] = 'cuon ' .. ten .. ': ' .. tostring(err)
		end
	end

	-- Doi diem cocos trong khong gian cua GOC CHAM sang khong gian cua lop.
	-- `_cham_goc` do LuaRuntime.touch_at dat (game/lua_runtime.gd). Thieu no
	-- (phep kiem goi thang M.cham) thi coi nhu cung mot khong gian — dung cho
	-- truong hop khong co phep phong to nao o giua.
	local function doi_vao(gd, x, y)
		local goc = rawget(_G, '_cham_goc')
		if goc == nil then return x, y end
		if not goc:is_class('Control') then return x, y end
		local w = _godot_ra_the_gioi(goc, x, y)
		local q = _godot_vao_node(gd, w.x, w.y)
		return q.x, q.y
	end

	local function la_con_cua(gd, lop_id)
		local n = gd
		while n ~= nil do
			if n:get_instance_id() == lop_id then return true end
			n = n:get_parent()
		end
		return false
	end

	--[[ Node nao la LOP CUON.

		Hai nguon: lop CCScrollLayer nap tu .xgg, va node do `LuaTableView_create`
		dung LUC CHAY (lua/bang.lua) — node do khong den tu file bo cuc nen khong
		co typeName nao ca, ta tu dat 'CCTableView' cho no.

		Phai nhan ca hai: thieu ve thu hai thi `tim_lop` di tiep len tren va cuon
		NHAM lop cuon ben ngoai — mot man vua co lop cuon vua co bang thi keo
		danh sach se lam ca man chay.
	]]
	local function la_cuon(n)
		if not n:has_meta('type_name') then return false end
		local tn = tostring(n:get_meta('type_name'))
		return tn == 'CCScrollLayer' or tn == 'CCTableView'
	end

	-- Lop cuon gan nhat bao quanh gd (ke ca chinh gd) ma dang bat cuon.
	local function tim_lop(gd)
		local n = gd
		while n ~= nil do
			if la_cuon(n) then
				local t = lay(n)
				chon_truc(n, t)
				if t.bat and mien(t, n, t.doc_that) ~= nil then return n end
			end
			n = n:get_parent()
		end
		return nil
	end

	-- Buoc cua hieu ung nha tay. cocos.lua goi vao day moi khung (xem M.tick).
	local function buoc_nha()
		for _, t in pairs(tt) do
			if t.dang_nha then
				t.dem_nha = t.dem_nha + 1
				local ty = math.min(1.0, t.dem_nha / SO_KHUNG_NHA)
				-- ease-out: 1 - (1 - t)^2. Noi suy thang tu diem dau, khong
				-- cong don theo gia tri truoc (cong don thi troi).
				local k = 1.0 - (1.0 - ty) * (1.0 - ty)
				day_lech(t.gd, t, t.dau_nha + (t.dich - t.dau_nha) * k)
				if t.dem_nha >= SO_KHUNG_NHA then
					t.dang_nha = false
					day_lech(t.gd, t, t.dich)
					goi_lai(t.gd, t.ten_ket)
				end
			end
		end
	end
	S.tick = buoc_nha

	-- Cham: cocos.lua goi vao day TRUOC khi goi ham cham cua node. Tra ve true
	-- nghia la NUOT pha nay.
	--
	-- Vi sao phai tim LOP CHA chu khong chi chinh node: khi nguoi choi dat ngon
	-- tay len mot nha roi keo, node nhan cham la NUT cua nha (con cua lop) chu
	-- khong phai lop. Ban goc cung hanh xu nhu vay — do la ly do CUIMain dang
	-- ky ca onTouchBegin_slMainUIScrollLayer lan setLuaCallbackForDrag.
	function S.cham(pha, gd, a, b, c)
		if pha == 'Begin' then
			keo = nil
			local lop = tim_lop(gd)
			if lop == nil then return false end
			local t = lay(lop)
			local x, y = doi_vao(lop, a, b)
			keo = { lop = lop, id = t.id, t = t, x = x, y = y, dau = false,
				goc = t.lech, node = gd }
			-- Tra ve false: de ham cham cua node van chay (nut van nhan Begin).
			-- Chi khi da keo qua nguong thi pha End moi bi nuot.
			return false
		end
		if keo == nil then return false end
		local t = keo.t
		if gd:get_instance_id() ~= keo.node:get_instance_id()
				and not la_con_cua(gd, keo.id) then
			if pha == 'End' then keo = nil end
			return false
		end
		if pha == 'Move' then
			-- Nguoi choi cham lai giua luc dang nha: dung hieu ung lai.
			t.dang_nha = false
			local x, y = doi_vao(keo.lop, b, c)
			-- DAU CUA QUANG KEO. `doi_vao` tra toa do COCOS cua lop (y huong LEN,
			-- xem `convertToNodeSpace` o cocos.lua), con `goc`/`day_lech`/`mien`
			-- lam viec trong khong gian GODOT cua lop (y huong XUONG). Truc NGANG
			-- thi hai khong gian cung chieu, truc DOC thi NGUOC — nen chi truc doc
			-- phai lat dau.
			--
			-- Thieu phep lat nay thi truc doc CHAY NGUOC: keo len lam noi dung
			-- chay xuong, va vi moi do lech am nam ngoai mien (mien cua danh sach
			-- o goc la [am, 0]) nen no bi KEP ve 0 — danh sach dung yen hoan toan.
			-- Do duoc: tools/verify_bang.gd, "keo len 100 thi lech = -100" ra 0.0.
			local d = t.doc_that and (keo.y - y) or (x - keo.x)
			if not keo.dau then
				if math.abs(d) < NGUONG then return false end
				keo.dau = true
				goi_lai(keo.lop, t.ten_bat)
			end
			local moi = keo.goc + d
			if not t.dan then
				local m1, m2 = mien(t, keo.lop, t.doc_that)
				if m1 ~= nil then moi = kep(moi, m1, m2) end
			end
			day_lech(keo.lop, t, moi)
			return true
		end
		-- End
		local da_keo = keo.dau
		local lop = keo.lop
		local node_bat = keo.node
		keo = nil
		if not da_keo then
			-- MOT CU BAM (khong keo): bao cho lop nao da dang ky. Lop cuon
			-- khong biet gi ve o danh sach, nhung CCTableView thi phai goi
			-- `tableCellTouched(tableView, cell)` cua uy quyen — xem
			-- lua/bang.lua. Toa do o day la TOA DO COCOS CUA LOP (y huong len,
			-- goc o duoi-trai lop) chu khong phai `position` cua Godot — do la
			-- thu ma mot danh sach kieu Cocos can de tim ra o bi bam, va no cung
			-- la thu ma `doi_vao` tra ve san.
			local bx, by = doi_vao(lop, b, c)
			for _, f in ipairs(moc_bam) do f(lop, node_bat, bx, by) end
			return false
		end
		local m1, m2 = mien(t, lop, t.doc_that)
		local dich = t.lech
		if m1 ~= nil then dich = kep(t.lech, m1, m2) end
		if math.abs(dich - t.lech) < 0.5 then
			day_lech(lop, t, dich)
			goi_lai(lop, t.ten_ket)
		else
			-- ĐẶT 2: nha ve trong 0.2 giay (ban goc cung chay dan, khong dat ngay).
			t.dau_nha = t.lech
			t.dich = dich
			t.dang_nha = true
			t.dem_nha = 0
		end
		-- NUOT pha End: da la mot lan keo thi khong tinh la mot cu bam nua.
		-- Khong nuot thi nha vao nut ma keo se vua cuon vua mo man.
		return true
	end

	-- Phuong thuc cua lop ---------------------------------------------------

	-- enableScroll(bat): 73 cho goi (39 true / 34 false — 34 lan false la
	-- CGuideScheme tat cuon luc dang huong dan). Mac dinh BAT — xem ĐẶT 3.
	function S:enableScroll(b)
		lay(C.raw(self)).bat = (b == nil) or (b ~= false)
	end

	function S:getEnableScroll()
		return lay(C.raw(self)).bat
	end

	-- setMarginSpace(le): self[+0x1bc] la mot float (0x2c01ee: vstr s14,[r4,#0x1bc]
	-- ngay sau luaL_checknumber). 13 cho goi.
	function S:setMarginSpace(v)
		lay(C.raw(self)).le = tonumber(v) or 0.0
	end

	function S:getMarginSpace()
		return lay(C.raw(self)).le
	end

	function S:setIsElastic(b)
		lay(C.raw(self)).dan = (b ~= false)
	end

	function S:getIsElastic()
		return lay(C.raw(self)).dan
	end

	function S:setVerticalDirection(b)
		local t = lay(C.raw(self))
		t.doc = (b == nil) or (b ~= false)
		t.doc_that = t.doc
	end

	function S:getVerticalDirection()
		return lay(C.raw(self)).doc
	end

	--[[ Bat che do MOT TRUC: khong thu truc kia khi truc da dat khong cuon duoc.

		Lop CCScrollLayer cua .xgg khong biet truc nao co gi de cuon nen phai
		thu ca hai (ĐẶT 3). CCTableView thi BIET: no chi cuon theo truc da dat
		bang setDirection. Thieu co nay thi mot o RONG HON khung lam mien truc
		dong tra ve nil, va ca danh sach quay sang cuon NGANG trong khi cac o
		xep doc — sai hanh vi ma khong bao loi gi.

		Chi lua/bang.lua goi.
	]]
	function S:dat_mot_truc(b)
		local t = lay(C.raw(self))
		t.mot_truc = (b ~= false)
		t.doc_that = t.doc
	end

	--[[ Dat do lech noi dung theo TI LE cua quang cuon duoc (0 = dau, 1 = cuoi).

		KHONG phai ti le cua be cao noi dung: do la loi cua chinh ban goc, ghi ro
		o CUISign.lua:905 ("由于tableView的scrollTo是根据 总容器高度-列表可视区域高度
		做偏移比") va khop voi so hoc cua CUIAssist.scrollToItem (CUIAssist.lua:1455:
		nRate = nIndex / (nTotal - nLayerLen/nItemLen)). Quang cuon duoc = be cao
		noi dung tru be cao khung, va chi biet duoc SAU khi xep xong cac o — nen
		`reloadData` cua bang goi lai ham nay bang ti le da xin truoc do.

		Ban goc lam ham nay trong C++ (khong co trong bang phuong thuc 0x93386c),
		nen day la ham cua lop gia lap, khong phai ban chep.
	]]
	function S:dat_theo_ty_le(ty)
		local gd = C.raw(self)
		local t = lay(gd)
		chon_truc(gd, t)
		local x0, y0, x1, y1 = hop_noi_dung(t, gd)
		if x0 == nil then return end
		local k = tonumber(ty) or 0.0
		if k < 0 then k = 0 end
		if k > 1 then k = 1 end
		local xa
		if t.doc_that then
			xa = (y1 - y0) - gd.size.y
		else
			xa = (x1 - x0) - gd.size.x
		end
		if xa < 0 then xa = 0 end
		t.dang_nha = false
		day_lech(gd, t, -k * xa)
	end

	-- Ghi danh mot ham nhan cu BAM (xem `moc_bam`).
	function S.dang_ky_bam(f)
		moc_bam[#moc_bam + 1] = f
	end

	-- setIsCropDraw: MOI GHI CO, khong cat hinh — xem chu thich dau file.
	function S:setIsCropDraw(b)
		lay(C.raw(self)).cat = (b == nil) or (b ~= false)
	end

	function S:getIsCropDraw()
		return lay(C.raw(self)).cat
	end

	-- setBerthAnchor: self[+0x1b4], float. Mot cho goi trong ma goc
	-- (CUILoginServerList.lua:345) va ta khong lam he berth, nen chi ghi lai.
	function S:setBerthAnchor(v)
		lay(C.raw(self)).neo = tonumber(v) or 0.0
	end

	function S:getBerthAnchor()
		return lay(C.raw(self)).neo
	end

	-- setLuaCallbackForDrag(tenBat, tenKet): 10 cho goi. Ten ham duoc goi tren
	-- DOI TUONG CHAM cua lop, luc bat dau keo (qua nguong) va luc nha tay.
	function S:setLuaCallbackForDrag(a, b)
		local t = lay(C.raw(self))
		t.ten_bat = tostring(a or '')
		t.ten_ket = tostring(b or '')
	end

	function S:getLuaCallbackForDrag()
		local t = lay(C.raw(self))
		return t.ten_bat, t.ten_ket
	end

	-- resetContentLayerPos(percent): 158 cho goi — nhieu nhat trong ca lop.
	-- Ban goc: `core(self, percent)`, va o nhanh +0x245 TAT thi `core` lam dung
	-- `content[axis] = percent`; khong truyen tham so thi `lua_gettop(L)` chan
	-- lai nen percent = 0 (0x2c1b74..0x2c1b94). Nghia la: DAT do lech noi dung
	-- bang `percent`, mac dinh 0.
	--
	-- Do lech noi dung chu khong phai chi so muc — doi chieu
	-- CUIEpicChapter.lua:630 truyen `self.__dwChapterPos`, ma gia tri do lay tu
	-- `pContentNode:getPosition()` (dong :85). CUIStateWarGloryListDlg.lua:450
	-- truyen ca mot NODE; ban goc `luaL_checknumber` se bao loi, o day coi nhu
	-- 0 — dung y dinh cua cho goi do (xep lai danh sach roi dua ve dau).
	--
	-- Ham nay khong the lam hong mot man dang dung yen: lech dang la 0 thi dat
	-- ve 0 khong doi gi.
	function S:resetContentLayerPos(percent)
		local gd = C.raw(self)
		local t = lay(gd)
		chon_truc(gd, t)
		t.dang_nha = false
		day_lech(gd, t, tonumber(percent) or 0.0)
	end

	-- resetContent: ban goc dua content ve 0 roi moc lai danh sach (0x2c0a8c).
	-- O day: ve goc, roi XOA so goc da nho de lan sau doc lai vi tri hien tai —
	-- Lua goc hay dat lai cho cac con sau khi danh sach doi.
	function S:resetContent()
		local gd = C.raw(self)
		local t = lay(gd)
		t.dang_nha = false
		day_lech(gd, t, 0.0)
		t.goc = {}
	end

	-- stopMove: 9 cho goi, luon ngay truoc mot autoMoveTo/ImmediateMoveTo —
	-- de dung hieu ung dang chay. Nha ve bien neu dang qua bien.
	function S:stopMove()
		local gd = C.raw(self)
		local t = lay(gd)
		t.dang_nha = false
		local m1, m2 = mien(t, gd, t.doc_that)
		if m1 ~= nil and (t.lech < m1 or t.lech > m2) then
			day_lech(gd, t, kep(t.lech, m1, m2))
		end
	end

	--[[ ImmediateMoveTo / autoMoveTo: nhay toi muc thu `i` (danh so tu 1).

		VI SAO DOC THAM SO DAU LA CHI SO MUC: 19 + 15 cho goi, va cac vi du doc
		duoc deu la chi so — CGuideScheme huong dan
		`g_MainUIScrollLayer:autoMoveTo(30)` trong khi thanh pho co 32 con
		(CGuideScheme.lua:1576, :1659); `CUIContestFinalMatchList.lua:319`
		truyen `#tBattleReport`; `CUIComboBox.lua:55` truyen
		`nItemsNumber - nSelectIndex + 1`; `CUIMainSysOpenPreview.lua:75` truyen
		`self.curIndex`.

		HAI cho goi ro rang truyen TI LE chu khong phai chi so (CUIAssist.lua:1448
		`1 - nRateOfContent`, CGuideScheme.lua:4435 `fScrollSize`) — hai cai do se
		nhay sai cho. Ca hai deu bi KEP vao mien hop le ngay duoi day, nen sai
		cho chi la "cuon toi mot cho khac trong bien", khong the day noi dung ra
		ngoai o. Do la ly do ta dam lam ham nay trong khi chua giai het hinh hoc
		berth cua ban goc.

		autoMoveTo/ unfoldMoveTo chay dan (hang so thoi gian khong doc duoc — lay
		0.2 giay nhu ĐẶT 2); ImmediateMoveTo dat ngay. Ba co con lai cua
		ImmediateMoveTo (bBat, giay, bFlag) khong doi TRANG THAI CUOI — ban goc
		dung chung cho bon kieu goi khac nhau — nen bo qua.
	]]
	local function nhay_toi(self, i, chay_dan)
		local gd = C.raw(self)
		local t = lay(gd)
		if not t.bat then return end
		chon_truc(gd, t)
		local idx = tonumber(i)
		if idx == nil then return end
		local ds = {}
		local m = berth(gd, ds)
		if m == 0 then return end
		local k = math.floor(idx)
		if k < 1 then k = 1 end
		if k > m then k = m end
		local g = goc_cua(t, ds[k])
		local dich = t.doc_that and (-g.y) or (-g.x)
		local m1, m2 = mien(t, gd, t.doc_that)
		if m1 ~= nil then dich = kep(dich, m1, m2) end
		if not chay_dan then
			t.dang_nha = false
			day_lech(gd, t, dich)
			return
		end
		t.dau_nha = t.lech
		t.dich = dich
		t.dang_nha = true
		t.dem_nha = 0
	end

	function S:ImmediateMoveTo(i) nhay_toi(self, i, false) end
	function S:autoMoveTo(i) nhay_toi(self, i, true) end
	function S:unfoldMoveTo(i) nhay_toi(self, i, true) end

	-- Do trang thai cuon ra cho phep kiem doc lai. Tra ve CCPoint nhu ban goc.
	function S:getContentOffset()
		local t = lay(C.raw(self))
		if t.doc_that then return Vector2(0.0, t.lech) end
		return Vector2(t.lech, 0.0)
	end

	function S:getBerthNumber()
		local ds = {}
		return berth(C.raw(self), ds)
	end

	return S
end
