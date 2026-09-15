-- LuaTableView_create / LuaTableViewCell_create — bang danh sach cua engine.
--
-- VI SAO CAN. Hai ham nay do engine C++ dang ky (khong file Lua nao dinh nghia
-- chung, ca 973 file), dung ra CCTableView / CCTableViewCell cua Cocos2d-x.
-- Thieu chung thi `LuaTableView_create` roi vao bo dem bong cua
-- `Node.__index` (cocos.lua), tra ve mot BONG, va moi thu doc so tu bong deu
-- chet: 'cocos.lua:391: diem neo khong phai so (nil, nil) cua
-- <bong LuaTableView_create()>' — do duoc o CUIPetIllustrated.
--
-- HOP DONG lay tu chinh ban goc, khong suy dien:
--   * CUITableViewZ.lua:166-316 — lop bao quanh: init() goi
--     `LuaTableView_create(self, w, h)` roi sngRetainMgr:retainObj, setDirection,
--     setPosition, setIsVisible, container:addChild; refresh() goi
--     resetNumberOfCellsInTableView + reloadData; uninit() goi setTouchEnabled(false)
--     + removeFromParentAndCleanup(true) + sngRetainMgr:releaseObj.
--   * sngTableViewEventHandle.lua:33-110 — nguyen mau ham uy quyen VA ban DEMO
--     day du nhat cua API engine (LuaTableView_create(obj, w, h),
--     LuaTableViewCell_create("abc"), setIsEnableScroll, setDirection,
--     resetNumberOfCellsInTableView, insertCellAtIndex, removeCellAtIndex,
--     reloadData, scrollTo, cell:getView/setView/getIdx, dequeueCell(tag),
--     dequeueAllUnUseCell, dequeueAllUseCell).
--   * CUITableViewZ_Helper.getOrCreateCell (:84-106) — duong dung that: hoi
--     `dequeueCell(stringTag)` truoc, khong co thi `LuaTableViewCell_create`
--     + `lCellTemplate:copy()` + `cell:setView(view)`.
--   * CUIXingHunBook.lua:186-216 va CUIXingHunTable.lua:22-62 — hai nguoi dung
--     that (dau la mot luoi 4 cot: `countPerCell = 4`, `math.ceil(count / 4)`).
--
-- TRUC. `setDirection(1)` = truc DOC, `setDirection(0)` = truc NGANG. Do khong
-- phai suy tu ten: CUIBookHeroCombTable.lua:39-47 goi `setDirection(1)` roi
-- `nCell = math.ceil((#data) / 2)` — hai muc mot hang, tuc truc cuon phai la
-- truc DOC; CElementPond.lua:316 va CUITableViewZ.lua:187 (`scrollMode or 1`)
-- cung truyen 1, va 17/19 cho goi di qua CUITableViewZ. Hai cho truyen 0
-- (CUISign.lua:1034 va CUIPetAquariumShop.lua:160) la danh sach nam ngang.
--
-- O DANH SACH. O la mot node THAT (Control), khong phai bang Lua: ban goc co
-- `cell:getView():getChildByTag(tag)` (CUIBackPackList.lua:486),
-- `cell:setPosition` (2 cho), `cell:addChild` (1 cho), `cell:setIsVisible` (5
-- cho) — tat ca deu la phuong thuc cua CCNode, va `dequeueAllUseCell` phai tra
-- ve mot BANG LUA that (`KDebug.ProcessNotTable(tCellList)` o
-- CUIBackPackList.lua:480 roi `for k, cell in pairs(...)`).
--
-- KHONG LAM, noi ro:
--   * KHONG ao hoa o. Cocos chi dung o dang nhin thay; o day dung HET. Vi
--     `hop_noi_dung` cua lop cuon tinh bien cuon tu HOP CAC CON, thieu o ngoai
--     khung thi bien sai han. Danh sach trong game vai chuc o, khong nang.
--   * `tableCellHighlight` / `tableCellUnhighlight` / `tableCellWillRecycle`:
--     co trong nguyen mau nhung KHONG lop nao trong 973 file dinh nghia lai
--     (da dem: 1 file cho moi cai, chinh file nguyen mau), nen khong goi.
--   * `tableViewMove` thi CO 14 lop dinh nghia lai, nhung ban goc goi no luc
--     engine cuon — su kien do o day do lop cuon (lua/cuon.lua) giu, va no
--     khong bao ra ngoai. Chua noi vao; ghi lai de lan sau do lai.

return function(C)

	-- Bang (CCTableView) KE THUA lop cuon: keo, bien, dan hoi, le, nha ve bien
	-- deu la cua lua/cuon.lua. O day chi them phan RIENG cua bang: so o, xep o,
	-- kho o dung lai, va cac ham dieu khien cua CCTableView.
	local B = setmetatable({}, { __index = C.cuon })
	-- O (CCTableViewCell) ke thua Node: do la CCNode that trong ban goc.
	local O = setmetatable({}, { __index = C.Node })

	local tt = {}      -- id bang -> trang thai
	local idx_o = {}   -- id o -> chi so trong bang (cho getIdx)
	local view_o = {}  -- id o -> userdata view
	-- id o -> cho COCOS ma o duoc dat vao. Giu rieng vi phep tim o bi bam nhan
	-- toa do COCOS (lop cuon bao ra — xem lua/cuon.lua, `moc_bam`), con
	-- `og.position` la toa do GODOT (y huong xuong, va da doi theo `neo_so`).
	-- Doi chieu lung tung hai thu do thi moi cu bam lech dung mot o: do duoc
	-- o thu 5 thanh o thu 1 trong tools/verify_bang.gd.
	local cc_o = {}

	--[[ Vi sao giu view theo id o chu khong nhet vao meta cua node: `setView`
	-- nhan mot USERDATA cua Lua (ket qua cua `luaT_newproxy`), khong phai mot
	-- gia tri Variant cua Godot, nen khong dat duoc vao meta. Giu o day thi
	-- phai giu MANH: `boxed` cua cocos.lua la bang YEU (`__mode = 'v'`), nen
	-- view khong con ai giu se bi don va `cell:getView()` tra nil — trong khi
	-- ma goc van cam no de dat chu vao tung o (CUIBackPackList.lua:486).
	-- Don sach luc bang bi huy — xem `don_bang`. ]]

	local function ghi_loi(s)
		C.cell_errors[#C.cell_errors + 1] = s
	end

	local function lay(gd)
		local id = gd:get_instance_id()
		local t = tt[id]
		if t == nil then
			t = {
				gd = gd,
				id = id,
				uy_quyen = nil, -- doi tuong nhan su kien (CUITableViewZ hoac man)
				dem = 0,        -- so o, tu resetNumberOfCellsInTableView
				dang_dung = {}, -- o dang nam trong bang, theo thu tu chi so
				kho = {},       -- { {o = userdata}, ... } o da thu hoi
				theo_so = {},   -- chi so -> o (cellAtIndex)
				ty_le = nil,    -- ti le scrollTo da xin; nil = chua ai xin
			}
			tt[id] = t
		end
		return t
	end

	------------------------------------------------------------------ tao node

	-- Node Control rong cua engine gia lap. type_name la CHIA KHOA DINH TUYEN
	-- cua cocos.wrap: no quyet dinh node nay duoc boc bang lop nao (xem
	-- `M.lop_theo_loai`), va lop cuon doc lai chinh chuoi do de biet mot node
	-- co phai lop cuon khong (lua/cuon.lua, `la_cuon`).
	local function node_moi(kieu, ten_cham)
		local gd = _godot_new_node('')
		gd:set_meta('type_name', kieu)
		if ten_cham ~= nil then gd:set_meta('touch', ten_cham) end
		return gd
	end

	--[[ LuaTableView_create(doiTuongNhan, w, h).

		Tra ve mot node THAT, kich thuoc (w, h), cat phan tran ra ngoai khung.
		`doiTuongNhan` la doi tuong ma engine hoi nguoc lai
		(`tableCellSizeForIndex` / `tableCellAtIndex` / `tableCellTouched`).

		KHONG them vao cay o day: CUITableViewZ:init:190 tu goi
		`container:addChild(tv)` sau khi dat setPosition (0,0) — dung thu tu cua
		ban goc.
	]]
	local function tao(doi_tuong_nhan, w, h)
		local gd = node_moi('CCTableView', 'tableView')
		gd.size = Vector2(tonumber(w) or 0.0, tonumber(h) or 0.0)
		-- O nam ngoai khung phai bi cat: vua de ve dung, vua de BO LOC CHAM
		-- biet (LuaRuntime._ung_vien coi clip_contents la bien cua o).
		gd.clip_contents = true
		local u = C.wrap(gd)
		local t = lay(gd)
		t.uy_quyen = doi_tuong_nhan
		-- Dang ky lam DOI TUONG CHAM: mot node da dang ky thi NUOT pha Begin ke
		-- ca khi no khong co ham cho pha do (cocos.lua, M.cham). Thieu buoc nay
		-- thi cu bam vao vung trong cua bang khong di den dau ca, va
		-- LuaRuntime.touch_at khong dat `_dang_cham` — nen ca keo lan nha deu
		-- khong den duoc lop cuon (no chi nhan Move/End sau khi Begin da co chu).
		--
		-- Nut nam TRONG o khong bi anh huong: _ung_vien duyet con TRUOC cha
		-- (lua_runtime.gd:642-661), nen nut duoc thu Begin truoc bang va nuot
		-- lay thi bang khong thay gi.
		C.Node.setCallbackLuaObject(u, doi_tuong_nhan)
		return u
	end

	-- LuaTableViewCell_create(stringTag). O la CCNode that trong ban goc nen
	-- ngoai setView/getView/getIdx no con phai co day du phuong thuc Node.
	local function tao_o(string_tag)
		local gd = node_moi('CCTableViewCell', nil)
		if string_tag ~= nil then gd:set_meta('cls', tostring(string_tag)) end
		return C.wrap(gd)
	end

	------------------------------------------------------------------ xep o

	-- Thu hoi moi o dang dung ve kho. KHONG huy o: `dequeueCell` se lay lai.
	-- Phai go khoi CAY chu khong chi an: `hop_noi_dung` cua lop cuon tinh bien
	-- tu hop cac CON, o an nam trong cay se lam bien sai.
	local function thu_hoi(t)
		for i = 1, #t.dang_dung do
			local o = t.dang_dung[i]
			local og = C.raw(o)
			if og ~= nil then
				local p = og:get_parent()
				if p ~= nil and p:get_instance_id() == t.id then p:remove_child(og) end
				idx_o[og:get_instance_id()] = nil
				t.kho[#t.kho + 1] = { o = o }
			end
		end
		t.dang_dung = {}
		t.theo_so = {}
	end

	-- Xoa sach trang thai cua mot bang da bi huy khoi cay.
	local function don_bang(gd)
		local t = tt[gd:get_instance_id()]
		if t == nil then return end
		for i = 1, #t.dang_dung do
			local og = C.raw(t.dang_dung[i])
			if og ~= nil then view_o[og:get_instance_id()] = nil end
		end
		for i = 1, #t.kho do
			local og = C.raw(t.kho[i].o)
			if og ~= nil then
				view_o[og:get_instance_id()] = nil
				cc_o[og:get_instance_id()] = nil
				idx_o[og:get_instance_id()] = nil
				-- O trong kho KHONG con la con cua bang, nen huy bang khong
				-- giai phong duoc chung — phai huy tay, khong thi ro ri ca mot
				-- danh sach o moi lan man mo/dong.
				og:queue_free()
			end
		end
		tt[gd:get_instance_id()] = nil
	end

	-- Dat cho mot o theo toa do COCOS. Dung thang Node:setPosition — no doi sang
	-- khong gian Godot theo `neo_so` cua chinh o va `parent_h` da co tu addChild.
	-- Ghi lai cho COCOS de phep tim o bi bam khong phai do nguoc tu `position`.
	local function dat_cho(o, cx, cy)
		C.Node.setPosition(o, cx, cy)
		cc_o[C.raw(o):get_instance_id()] = Vector2(cx, cy)
	end

	--[[ Dat lai cho VIEW trong o theo kich thuoc MOI BIET cua o.

		Can buoc nay vi thu tu cua ban goc: `getOrCreateCell` goi `setView(view)`
		TRONG `tableCellAtIndex`, tuc luc kich thuoc o con la (0, 0) — ma kich
		thuoc do chi den tu `tableCellSizeForIndex`. Node Godot dat cho theo
		CHIEU CAO CHA (`parent_h`), nen view se nam sai cho neu khong dat lai.

		Ban goc khong co van de nay: Cocos dat con theo goc duoi-trai, khong
		phu thuoc kich thuoc cha. O day `addChild` doc lai vi tri Cocos cua view
		roi doi sang Godot voi `parent_h` moi, nen goi lai la dung — khong tich
		luy sai so.

		KHONG dung `setView` lai: lam the se tao mot ban sao view moi moi lan xep.
	]]
	local function dat_cho_view(o)
		local v = view_o[C.raw(o):get_instance_id()]
		if v ~= nil then C.Node.addChild(o, v) end
	end

	--[[ Xep lai toan bo o.

		Toa do tinh trong KHONG GIAN COCOS (goc duoi-trai, y huong len) roi de
		`Node:setPosition` doi sang Godot — lop cuon giu do lech trong khong gian
		Godot nen ket qua moi la thu ma no doc. O thu 0 o mep TREN: do la thu tu
		cua CCTableView (`kCCTableViewFillTopDown`, mac dinh), va cung la thu tu
		ma `_cfgArr[data.cellIndex + 1]` cua CUIXingHunBook.lua:225 doi hoi.
	]]
	local function xep_lai(self, gd, t)
		local uq = t.uy_quyen
		if uq == nil then return end

		-- Giu nguyen cho dang cuon qua lan xep lai: Cocos xep lai roi tra
		-- content ve cho cu (CCTableView::reloadData goi setContentOffset voi
		-- do lech doc ra TRUOC khi xep). Neu nguoi goi da xin mot ti le bang
		-- `scrollTo` thi ti le do thang, vi no moi la y dinh moi nhat.
		local lech_cu = 0.0
		if t.ty_le == nil then
			local off = C.cuon.getContentOffset(self)
			lech_cu = C.cuon.getVerticalDirection(self) and off.y or off.x
		end

		thu_hoi(t)

		local node = C.wrap(gd)
		local doc = C.cuon.getVerticalDirection(self)
		local y, x = gd.size.y, 0.0
		for idx = 0, t.dem - 1 do
			-- Mot o hong KHONG duoc lam chet ca danh sach: ghi lai roi di tiep.
			-- Ban goc goi thang vao C++ nen mot o nem loi se bo luon cac o sau.
			local okw, w, h = pcall(function() return uq:tableCellSizeForIndex(node, idx) end)
			if not okw then
				ghi_loi('bang o ' .. idx .. ': tableCellSizeForIndex nem loi: ' .. tostring(w))
				w, h = nil, nil
			end
			w, h = tonumber(w) or 0.0, tonumber(h) or 0.0
			local oko, o = pcall(function() return uq:tableCellAtIndex(node, idx) end)
			if not oko then
				ghi_loi('bang o ' .. idx .. ': tableCellAtIndex nem loi: ' .. tostring(o))
				o = nil
			end
			local og = o ~= nil and C.raw(o) or nil
			if og == nil then
				ghi_loi('bang o ' .. idx .. ': uy quyen khong tra ve o nao')
			else
				-- O phai co KICH THUOC: lop cuon tinh bien cuon tu hop cac con,
				-- ma o trong ban goc khong tu mang kich thuoc — `tableCellSizeForIndex`
				-- moi la cho noi kich thuoc (CCTableView xep o theo so do do).
				og.size = Vector2(w, h)
				self:addChild(o)
				dat_cho_view(o)
				if doc then
					y = y - h
					dat_cho(o, 0.0, y)
				else
					dat_cho(o, x, gd.size.y - h)
					x = x + w
				end
				local ido = og:get_instance_id()
				idx_o[ido] = idx
				t.dang_dung[#t.dang_dung + 1] = o
				t.theo_so[idx] = o
			end
		end

		-- Tra content ve cho cu. `resetContentLayerPos` dat do lech THEO PIXEL,
		-- `dat_theo_ty_le` theo TI LE cua quang cuon duoc (xem lua/cuon.lua).
		if t.ty_le ~= nil then
			C.cuon.dat_theo_ty_le(self, t.ty_le)
		else
			C.cuon.resetContentLayerPos(self, lech_cu)
			C.cuon.stopMove(self)
		end
	end

	------------------------------------------------------------ phuong thuc bang

	function B:setDirection(d)
		local doc = (tonumber(d) or 1) ~= 0
		C.cuon.setVerticalDirection(self, doc)
		-- CCTableView chi co MOT truc: tat phep thu truc kia cua lop cuon, neu
		-- khong mot o rong hon khung se lam ca danh sach cuon NGANG trong khi
		-- cac o xep doc (xem lua/cuon.lua, `dat_mot_truc`).
		C.cuon.dat_mot_truc(self, true)
	end

	function B:getDirection()
		return C.cuon.getVerticalDirection(self) and 1 or 0
	end

	function B:setIsEnableScroll(b)
		C.cuon.enableScroll(self, b)
	end

	function B:getIsEnableScroll()
		return C.cuon.getEnableScroll(self)
	end

	-- setTouchEnabled cua CCTableView tat ca viec nhan cham lan cuon.
	function B:setTouchEnabled(b)
		C.cuon.enableScroll(self, b)
		C.Node.setEnableLuaTouch(self, b)
	end

	function B:setIsTouchEnabled(b)
		C.Node.setEnableLuaTouch(self, b)
	end

	--[[ resetNumberOfCellsInTableView(soO, ...).

		Hai tham so sau cua ban goc (`bReload`, `bKeepPos`?) khong doi HINH DANG
		ket qua — CUITableViewZ:230-236 va CUISign.lua:1046 luon truyen
		(true, true) — nen bo qua va luon xep lai, dung nhu mock cua
		G_CTableViewMgr da lam.
	]]
	function B:resetNumberOfCellsInTableView(n, _, _)
		local t = lay(C.raw(self))
		t.dem = math.max(0, math.floor(tonumber(n) or 0))
		xep_lai(self, C.raw(self), t)
	end

	function B:reloadData()
		local t = lay(C.raw(self))
		xep_lai(self, C.raw(self), t)
	end

	-- Them / bot mot o. Ban goc lam viec nay tren chinh CCTableViewCell, nhung
	-- ca hai cho goi trong 973 file deu nam trong chu thich cua ban demo
	-- (sngTableViewEventHandle.lua:110-112), nen o day chi chinh SO O roi xep
	-- lai — dung ket qua cuoi, khong bia chi tiet chua do duoc.
	function B:insertCellAtIndex(_)
		local t = lay(C.raw(self))
		t.dem = t.dem + 1
		xep_lai(self, C.raw(self), t)
	end

	function B:removeCellAtIndex(_)
		local t = lay(C.raw(self))
		if t.dem > 0 then t.dem = t.dem - 1 end
		xep_lai(self, C.raw(self), t)
	end

	-- O thu idx (danh so tu 0, nhu CCTableView).
	function B:cellAtIndex(idx)
		return lay(C.raw(self)).theo_so[tonumber(idx) or 0]
	end

	--[[ Lay mot o tu kho dung lai.

		Ban goc (CCTableView::dequeueCell): khong co `tag` thi tra ve o trong
		dau tien; co `tag` thi doi `getReuseIdentifier` khop. `tag` o day la
		`stringTag` ma nguoi goi dua vao `LuaTableViewCell_create`, va
		CUITableViewZ_Helper.getOrCreateCell:89 goi bang `stringTag` cua chinh
		no — co noi truyen nil (CUIXingHunBook.lua:204).

		Tra nil khi kho rong: nguoi goi se tu tao o moi. Do la duong dung that,
		khong phai duong lui.
	]]
	function B:dequeueCell(tag)
		local t = lay(C.raw(self))
		local ten = tostring(tag or '')
		for i = 1, #t.kho do
			local o = t.kho[i].o
			local og = C.raw(o)
			local cua = ''
			if og ~= nil and og:has_meta('cls') then cua = tostring(og:get_meta('cls')) end
			if ten == '' or cua == ten then
				table.remove(t.kho, i)
				return o
			end
		end
		return nil
	end

	function B:dequeueAllUseCell()
		local t = lay(C.raw(self))
		local ra = {}
		for i = 1, #t.dang_dung do ra[i] = t.dang_dung[i] end
		return ra
	end

	function B:dequeueAllUnUseCell()
		local t = lay(C.raw(self))
		local ra = {}
		for i = 1, #t.kho do ra[i] = t.kho[i].o end
		return ra
	end

	--[[ scrollTo(tiLe, chayHieuUng).

		`tiLe` la ti le cua QUANG CUON DUOC (0 = mep dau, 1 = mep cuoi), khong
		phai ti le cua be cao noi dung — loi cua chinh ban goc, ghi ro o
		CUISign.lua:905 va khop voi CUIAssist.scrollToItem (CUIAssist.lua:1455).
		Quang do chi biet duoc SAU khi xep o, nen ti le duoc nho lai de ap o lan
		xep ke tiep (CUIInfiniteLevelFirstPassRewards.lua:75 xin ti le truoc khi
		danh sach co o nao).

		Tham so thu hai la CO CHAY HIEU UNG, khong phai "co cuon hay khong":
		CUIGuildTableViewList.lua:441 truyen false, va CUIXingHun.lua:339 truyen
		thang xuong tu mot ham ten `ScrollTo`.
	]]
	function B:scrollTo(percent, _)
		local t = lay(C.raw(self))
		t.ty_le = tonumber(percent) or 0.0
		C.cuon.dat_theo_ty_le(self, t.ty_le)
	end

	-- Do lech dang cuon, theo PIXEL. Ban goc tra CCPoint; lop cuon tra Vector2
	-- (co .x/.y) — xem lua/cuon.lua `getContentOffset`.
	function B:getContentOffset()
		return C.cuon.getContentOffset(self)
	end

	function B:setContentOffset(x, y)
		local t = lay(C.raw(self))
		t.ty_le = nil
		if type(x) == 'table' or (type(x) == 'userdata' and x.x ~= nil) then
			x, y = x.x, x.y
		end
		local v = C.cuon.getVerticalDirection(self) and (y or 0.0) or (x or 0.0)
		C.cuon.resetContentLayerPos(self, tonumber(v) or 0.0)
	end

	-- Huy bang: tra het o ve kho (de xoa `view_o`) roi moi huy that.
	function B:removeFromParentAndCleanup(b)
		don_bang(C.raw(self))
		C.Node.removeFromParentAndCleanup(self, b)
	end

	------------------------------------------------------------- phuong thuc o

	function O:setView(v)
		local ido = C.raw(self):get_instance_id()
		local cu = view_o[ido]
		if cu ~= nil and cu ~= v then
			local c = C.raw(cu)
			if c ~= nil then
				local p = c:get_parent()
				if p ~= nil and p:get_instance_id() == ido then p:remove_child(c) end
				-- Ban goc (CCTableViewCell::setView) tra view cu ve cho quan ly
				-- bo nho. O day khong ai giu no nua thi phai huy tay.
				c:queue_free()
			end
		end
		if v == nil then
			view_o[ido] = nil
			return
		end
		view_o[ido] = v
		-- Di qua Node:addChild chu khong `gd:add_child`: no doi toa do sang
		-- khong gian Godot theo `parent_h`, va luc nay kich thuoc o con la
		-- (0, 0) — `dat_cho_view` se dat lai khi biet kich thuoc that.
		C.Node.addChild(self, v)
	end

	function O:getView()
		return view_o[C.raw(self):get_instance_id()]
	end

	function O:getIdx()
		return idx_o[C.raw(self):get_instance_id()]
	end

	----------------------------------------------------------- cu bam vao bang

	C.cuon.dang_ky_bam(function(lop, node_bat, x, y)
		local t = tt[lop:get_instance_id()]
		if t == nil or t.uy_quyen == nil then return end
		-- Chi khi phuong thuc Begin den DUOC chinh bang: cu bam vao mot nut
		-- trong o da co nguoi nhan rieng, goi them `tableCellTouched` nua la
		-- lam hai viec cho mot cu bam.
		if node_bat == nil or node_bat:get_instance_id() ~= lop:get_instance_id() then return end
		local o = nil
		for i = 1, #t.dang_dung do
			local og = C.raw(t.dang_dung[i])
			local cc = og ~= nil and cc_o[og:get_instance_id()] or nil
			if cc ~= nil then
				if x >= cc.x and x <= cc.x + og.size.x
						and y >= cc.y and y <= cc.y + og.size.y then
					o = t.dang_dung[i]
					break
				end
			end
		end
		if o == nil then return end
		local uq = t.uy_quyen
		pcall(function() uq:tableCellTouched(C.wrap(lop), o) end)
	end)

	return { B = B, O = O, tao = tao, tao_o = tao_o }
end
