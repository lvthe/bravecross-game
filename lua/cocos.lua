-- Lop gia lap Cocos2d-x cho ma nguon Lua cua ban goc.
--
-- Ban goc chay tren Cocos2d-x doi cu (goi setIsVisible chu khong phai
-- setVisible, tuc la nhanh 1.x). Thay vi chep tay 324.000 dong giao dien sang
-- GDScript, ta cho chinh ma do chay, va dich tung loi goi sang node Godot.
--
-- NODE LA USERDATA, khong phai bang. Ban goc kiem kieu that su: KDebug
-- .ProcessNotUserdata duoc goi 3.786 lan, va no tu choi bat cu thu gi khong
-- phai userdata. Lua 5.1 / LuaJIT co newproxy(true) — tao userdata rong kem
-- mot metatable rieng — nen boc duoc dung kieu.
--
-- Truc toa do: Cocos lay goc o DUOI-TRAI, y huong len, va x/y la DIEM NEO.
-- Godot lay goc TREN-TRAI, y huong xuong, va vi tri la goc tren-trai cua o.
-- Moi cho doi qua lai deu di qua to_godot()/to_cocos() duoi day.
--
-- Ben GDScript bac vai cay cau vao day (xem game/lua_runtime.gd):
--   _godot_copy(node)          nhan ban mot node ke ca cay con
--   _godot_frame(node, ten)    gan anh theo ten khung
--   _godot_text(khoa)          tra chu theo khoa, tu bang chu tieng Viet

local M = {}

M.missing = {}        -- API bi goi ma chua lam -> so lan
M.tag_lookups = 0
M.tag_misses = 0
M.tag_miss_log = {}
M.cell_errors = {}   -- o danh sach dung hong -> de doc ra
-- Lop RIENG theo ten node trong .xgg: node mang ten nay tra ham o bang nay
-- truoc (bang do tu __index ve Node). g_BattleField: lua/san_tran.lua.
M.lop_rieng = {}

local function note(name)
	M.missing[name] = (M.missing[name] or 0) + 1
end

-- Boc node ---------------------------------------------------------------

local Node = {}
M.Node = Node

-- API nao chua lam thi bao LOI RO RANG bang cach dem lai, thay vi de Lua
-- bao 'attempt to call a nil value' o giua mot file 3000 dong.
setmetatable(Node, {
	__index = function(_, name)
		return function()
			note(name)
			return nil
		end
	end,
})

local gd_of = setmetatable({}, { __mode = 'k' })   -- userdata -> node Godot
local boxed = setmetatable({}, { __mode = 'v' })   -- id -> userdata

local function raw(u)
	return gd_of[u]
end
M.raw = raw

local function wrap(gd)
	if gd == nil then
		return nil
	end
	local id = gd:get_instance_id()
	local u = boxed[id]
	if u == nil then
		u = newproxy(true)
		local mt = getmetatable(u)
		local ten = gd:has_meta('xgg_name') and tostring(gd:get_meta('xgg_name')) or nil
		mt.__index = (ten ~= nil and M.lop_rieng[ten]) or Node
		mt.__tostring = function() return '<CCNode>' end
		gd_of[u] = gd
		boxed[id] = u
	end
	return u
end
M.wrap = wrap

local function unwrap(v)
	if type(v) == 'userdata' and gd_of[v] ~= nil then
		return gd_of[v]
	end
	return v
end
M.unwrap = unwrap

-- Doi toa do ---------------------------------------------------------------
-- XggLayout gan san meta "cocos" = (x, y, anchorX, anchorY) va "parent_h".
-- Giu lai nguyen ban Cocos nhu vay thi doi qua lai khong bi troi so.

-- CCLayer dat isRelativeAnchorPoint = false trong init cua chinh no, nen DIEM
-- NEO khong doi cho dat cua lop — no chi la tam de phong to / xoay. CCSprite
-- thi nguoc lai (mac dinh cua CCNode la true). Ban goc khong goi
-- setIsRelativeAnchorPoint o dau ca, nen phai theo mac dinh cua tung lop.
--
-- Can dung cai nay vi hoat canh mo hop thoai goi rootUI:setAnchorPoint(0.5,0.5)
-- roi KHONG tra lai (CUIDialogAnimation.lua:238) — cot de phong to tu giua.
-- Neu coi neo la doi cho thi ca hop thoai nhay xuong goc trai-duoi.
--
-- Bo nap .xgg thi khac: no da dung neo trong file de tinh ra cho dat roi
-- (lSubDialogMask 960x640 ghi neo 0,5 va toa do 480,320 — chi phu kin man neu
-- tinh theo neo). Nen XggLayout van dung neo luc dung cay; chi luc CHAY thi
-- lop moi coi toa do la goc o.
local function la_lop(gd)
	if not gd:has_meta('type_name') then return false end
	local t = tostring(gd:get_meta('type_name'))
	return t:sub(1, 7) == 'CCLayer' or t:sub(1, 7) == 'CCScene'
end

local function neo_that(gd)
	if gd:has_meta('cocos') then
		local c = gd:get_meta('cocos')
		return c.z, c.w
	end
	return 0.0, 0.0
end

local function anchor_of(gd)
	if la_lop(gd) then return 0.0, 0.0 end
	return neo_that(gd)
end

local function parent_h(gd)
	if gd:has_meta('parent_h') then
		return gd:get_meta('parent_h')
	end
	local p = gd:get_parent()
	if p ~= nil and p.size ~= nil then
		return p.size.y
	end
	return 0.0
end

-- Diem neo phai la HAI SO. Khong phai thi van nem loi (khong bia hanh vi cho
-- engine) nhung kem cho goi: loi trong coroutine doi canh chi con lai mot
-- dong ('sngLoadingNext : cocos.lua:140: ... ax (a table value)') va khong ai
-- biet node nao, ai goi.
local function neo_so(gd)
	local ax, ay = anchor_of(gd)
	if type(ax) ~= 'number' or type(ay) ~= 'number' then
		error(string.format('diem neo khong phai so (%s, %s) cua %s%s', type(ax), type(ay),
			tostring(gd), debug.traceback('', 3)), 3)
	end
	return ax, ay
end

local function to_godot(gd, x, y)
	local ax, ay = neo_so(gd)
	local sz = gd.size
	return x - ax * sz.x, parent_h(gd) - (y - ay * sz.y) - sz.y
end

local function to_cocos(gd)
	local ax, ay = neo_so(gd)
	local sz = gd.size
	local p = gd.position
	return p.x + ax * sz.x, parent_h(gd) - p.y - sz.y + ay * sz.y
end

-- Cay node -----------------------------------------------------------------

-- Tag THAT, do tu chinh engine ban goc chay trong may ao: tag khong nam trong
-- file .xgg, engine sinh ra luc nap. Xem work/emu_tags.py.
--
-- Node khong co tag la node engine khong tra ve: getChildByTag chi tra ve cai
-- DAU TIEN mang tag do, nen anh em trung tag thi nhung cai sau bi khuat — va
-- ma goc cung khong voi toi chung.
function Node:getChildByTag(tag)
	local gd = raw(self)
	M.tag_lookups = M.tag_lookups + 1
	for i = 0, gd:get_child_count() - 1 do
		local c = gd:get_child(i)
		if c:has_meta('tag') and c:get_meta('tag') == tag then
			return wrap(c)
		end
	end
	M.tag_misses = M.tag_misses + 1
	-- Ghi lai cho truot, kem ten node cha va cac tag no THAT SU co. Khong co
	-- cai nay thi chi biet "co cho hut" chu khong biet hut o dau.
	local ten = gd:has_meta('xgg_name') and gd:get_meta('xgg_name') or '?'
	local codo = {}
	for i = 0, gd:get_child_count() - 1 do
		local c = gd:get_child(i)
		codo[#codo + 1] = c:has_meta('tag') and tostring(c:get_meta('tag')) or '-'
	end
	M.tag_miss_log[#M.tag_miss_log + 1] =
		ten .. ' hoi tag ' .. tostring(tag) .. ', chi co: ' .. table.concat(codo, ',')
	return nil
end

function Node:getChildByTagInAllChildren(tag)
	local goc = raw(self)
	local hang = { goc }
	while #hang > 0 do
		local n = table.remove(hang, 1)
		for i = 0, n:get_child_count() - 1 do
			local c = n:get_child(i)
			if c:has_meta('tag') and c:get_meta('tag') == tag then
				return wrap(c)
			end
			hang[#hang + 1] = c
		end
	end
	return nil
end

function Node:getChildByStringTag(s)
	local gd = raw(self)
	for i = 0, gd:get_child_count() - 1 do
		local c = gd:get_child(i)
		if c:has_meta('cls') and c:get_meta('cls') == s then
			return wrap(c)
		end
	end
	return nil
end

function Node:getStringTag()
	local gd = raw(self)
	if gd:has_meta('cls') then
		return gd:get_meta('cls')
	end
	return ''
end

function Node:setStringTag(s)
	raw(self):set_meta('cls', s)
end

-- Cham ---------------------------------------------------------------------
-- Engine ban goc goi ham xu ly theo khuon ten co san trong chinh libgame.so:
-- 'onTouchEnd_%s', 'onTouchBegin_%s', 'onTouchMove_%s', va '%s_%s' ghep voi
-- 'onTouchEndEx' (chuoi o 0x7b10fd..0x7b1130). Ten cham va doi tuong nhan
-- den tu hai cho:
--   * ban ghi node trong .xgg (+0x0C ten cham, +0x14 TEN BIEN TOAN CUC cua
--     doi tuong — xem work/xgg.py), 2.005 node; XggLayout gan thanh meta
--     'touch' va 'touch_obj';
--   * luc chay: setLuaTouchName (318 cho) va setCallbackLuaObject (325 cho).
--
-- Doi so, dem tu chu ky ham trong ma goc:
--   onTouchBegin_X(node)                 203 ham
--   onTouchMove_X(node, bTrongO, x, y)    11 ham
--   onTouchEnd_X(node, bTouchInSide)     cap tren 1.500 ham
--   onTouchEndEx_X(node, x, y)            68 ham
-- EndEx KHONG goi sau End: 33/66 ham EndEx tu goi lai End(node, false) cua
-- chinh no (vd CUIAchieve.lua:597) — neu engine goi ca hai thi End chay hai
-- lan. Nen EndEx la loi ra khi cham bi tuot mat (danh sach cuon cuop cham),
-- khong phai khi tha tay. Ta chua co cuon bang cham nen chua goi EndEx.
--
-- Gia tri tra ve cua Begin KHONG quyet dinh co nhan cham hay khong: ham End
-- tu kiem lai dung dieu kien ma Begin da kiem (CUIAchieve.lua:532 va :569),
-- va 42 lop chi co Begin ma khong co End.

M.doi_tuong_cham = {}   -- id node Godot -> doi tuong Lua (gan luc chay)
M.nhat_ky_cham = {}     -- ten ham da goi (toi da 64), de phep kiem doc lai
M.loi_cham = {}

local function doi_tuong_cua(gd)
	local o = M.doi_tuong_cham[gd:get_instance_id()]
	if o ~= nil then return o end
	if gd:has_meta('touch_obj') then
		local ten = tostring(gd:get_meta('touch_obj'))
		-- rawget: bien chua co thi la nil that, khong phai bong.
		if ten ~= '' then return rawget(_G, ten) end
	end
	return nil
end

function Node:setCallbackLuaObject(obj)
	M.doi_tuong_cham[raw(self):get_instance_id()] = obj
end

function Node:getCallbackLuaObject()
	return doi_tuong_cua(raw(self))
end

function Node:setLuaTouchName(ten)
	raw(self):set_meta('touch', tostring(ten or ''))
end

function Node:getLuaTouchName()
	local gd = raw(self)
	return gd:has_meta('touch') and tostring(gd:get_meta('touch')) or ''
end

function Node:setEnableLuaTouch(b)
	raw(self):set_meta('lua_touch', b ~= false)
end

-- Mac dinh la BAT: 187 lan ma goc goi setEnableLuaTouch, gan het la de TAT
-- tam roi bat lai (CUIGame.lua: false d.97, true d.258).
function Node:getEnableLuaTouch()
	local gd = raw(self)
	if gd:has_meta('lua_touch') then return gd:get_meta('lua_touch') end
	return true
end

-- Goi tu GDScript (LuaRuntime.touch_at) khi node gd bi cham. Tra ve true neu
-- node co doi tuong nhan — tuc engine co dang ky no — du doi tuong co ham cho
-- pha nay hay khong: node da dang ky thi nuot cham, nen nut o duoi khong an.
function M.cham(pha, gd, a, b, c)
	local ten = gd:has_meta('touch') and tostring(gd:get_meta('touch')) or ''
	if ten == '' then return false end
	local obj = doi_tuong_cua(gd)
	if type(obj) ~= 'table' then return false end
	local k = 'onTouch' .. pha .. '_' .. ten
	-- pcall: lop cua ban goc co the dat __index nem loi khi thieu khoa.
	local co, f = pcall(function() return obj[k] end)
	if co and type(f) == 'function' then
		local sender = wrap(gd)
		local ok, err
		if pha == 'Begin' then
			ok, err = pcall(f, obj, sender)
		elseif pha == 'Move' then
			ok, err = pcall(f, obj, sender, a, b, c)
		elseif pha == 'End' then
			ok, err = pcall(f, obj, sender, a)
		else
			ok, err = pcall(f, obj, sender, a, b)
		end
		if #M.nhat_ky_cham >= 64 then table.remove(M.nhat_ky_cham, 1) end
		M.nhat_ky_cham[#M.nhat_ky_cham + 1] = k
		if not ok then
			M.loi_cham[#M.loi_cham + 1] = k .. ': ' .. tostring(err)
		end
	end
	return true
end

function Node:getTag()
	local gd = raw(self)
	if gd:has_meta('tag') then
		return gd:get_meta('tag')
	end
	return -1
end

function Node:setTag(t)
	raw(self):set_meta('tag', t)
end

function Node:getParent()
	return wrap(raw(self):get_parent())
end

function Node:getChildrenCount()
	return raw(self):get_child_count()
end

function Node:addChild(child, z, tag)
	local c = unwrap(child)
	local p = c:get_parent()
	-- Cocos: addChild KHONG doi toa do cua node — van la (x, y) tuong doi voi
	-- cha, goc duoi-trai. O Godot toa do phu thuoc CHIEU CAO CHA (parent_h),
	-- nen phai doi lai. Truoc day node tao luc chay (_new_node) giu
	-- parent_h = 640 mai: nha cua canh Main (armature, addChild vao nut nha roi
	-- setPosition(rong/2, 0) — day nut) roi thap hon ~480 px, ra ngoai khung.
	local la_o = c:is_class('Control')
	local cx, cy
	if la_o then cx, cy = to_cocos(c) end
	if p ~= nil then
		p:remove_child(c)
	end
	local cha = raw(self)
	cha:add_child(c)
	if la_o and cha:is_class('Control') then
		c:set_meta('parent_h', cha.size.y)
		local gx, gy = to_godot(c, cx, cy)
		c.position = Vector2(gx, gy)
	end
	if tag ~= nil then
		c:set_meta('tag', tag)
	end
	-- zOrder cua Cocos: XEP LAI anh em nhu setZOrder, khong dat z_index. Ban goc
	-- truyen toi 99999 (CUISubtitle:AddToParent) ma Godot chi nhan +-4096.
	if z ~= nil then
		c:set_meta('zorder', z)
		_godot_zsort(cha)
	end
end

function Node:removeFromParentAndCleanup(_)
	local gd = raw(self)
	local p = gd:get_parent()
	if p ~= nil then
		p:remove_child(gd)
	end
	gd:queue_free()
end

function Node:removeAllChildrenWithCleanup(_)
	local gd = raw(self)
	for i = gd:get_child_count() - 1, 0, -1 do
		local c = gd:get_child(i)
		gd:remove_child(c)
		c:queue_free()
	end
end

-- Nhan ban ca cay con. Ban goc dung de nhan mau thanh tung dong danh sach:
-- CUIGuildTableView:createCell() nhan ban lAchieveTemplate cho moi thanh tuu.
function Node:copy()
	return wrap(_godot_copy(raw(self)))
end

-- Hien / an ----------------------------------------------------------------

function Node:setIsVisible(v)
	raw(self).visible = v and true or false
end

function Node:getIsVisible()
	return raw(self).visible
end

-- Vi tri, kich thuoc, bien doi ---------------------------------------------

function Node:setPosition(x, y)
	if y == nil then
		-- setPosition(so, nil): ma goc tinh ra y = nil. Van nem loi (khong
		-- bia hanh vi cho engine), nhung kem cho goi — loi trong coroutine doi
		-- canh chi con lai mot dong, khong co stack.
		if type(x) ~= 'table' then
			error('setPosition(' .. tostring(x) .. ', nil)' .. debug.traceback('', 2), 2)
		end
		x, y = x.x, x.y
	end
	local gd = raw(self)
	local gx, gy = to_godot(gd, x, y)
	gd.position = Vector2(gx, gy)
end

function Node:getPosition()
	return to_cocos(raw(self))
end

function Node:setPositionX(x)
	local _, y = to_cocos(raw(self))
	self:setPosition(x, y)
end

function Node:setPositionY(y)
	local x = to_cocos(raw(self))
	self:setPosition(x, y)
end

function Node:getPositionX()
	local x = to_cocos(raw(self))
	return x
end

function Node:getPositionY()
	local _, y = to_cocos(raw(self))
	return y
end

-- Doi toa do giua khong gian node va the gioi. Ma goc goi 237 lan, LUON voi
-- hai so (x, y) va LUON nhan ve hai so (211 cho gan 'x, y = ...'), nen chi
-- lam dang do. Thieu hai ham nay thi ket qua la nil, va CUIMain:InitUI chet
-- o CUIChatting.lua:279 — btnChatting:setPositionY(nil).
function Node:convertToWorldSpace(x, y)
	local v = _godot_ra_the_gioi(raw(self), x, y)
	return v.x, v.y
end

function Node:convertToNodeSpace(x, y)
	local v = _godot_vao_node(raw(self), x, y)
	return v.x, v.y
end

-- Tra HAI gia tri, khong phai mot bang. Da dem tren ca ma goc: 742 cho viet
-- 'local w, h = node:getContentSize()', 0 cho dung '.width'.
function Node:getContentSize()
	local s = raw(self).size
	return s.x, s.y
end

function Node:setContentSize(w, h)
	if h == nil then
		w, h = w.width, w.height
	end
	raw(self).size = Vector2(w, h)
end

-- Tra HAI gia tri, giong getContentSize. Thieu no thi CUIHelper:920 lam
-- 'local fParentAnchorX, fParentAnchorY = parent:getAnchorPoint()' ra nil roi
-- nhan voi chieu rong — va 30/353 man chet o do hoac o setAnchorPoint(nil).
function Node:getAnchorPoint()
	return neo_that(raw(self))
end

-- Dem tham chieu cua Cocos. Godot tu lo doi song node, nen day chi can khong
-- hong: sngRetainMgr goi retain()/release() tren node that.
function Node:retain() return self end
function Node:release() end
function Node:autorelease() return self end

function Node:setAnchorPoint(x, y)
	if y == nil then
		if type(x) ~= 'table' and type(x) ~= 'userdata' then return end
		x, y = x.x, x.y
	end
	if type(x) ~= 'number' or type(y) ~= 'number' then return end
	local gd = raw(self)
	local cx, cy = to_cocos(gd)
	gd:set_meta('cocos', Vector4(cx, cy, x, y))
	-- Tam phong to / xoay. Cocos giu DIEM NEO dung yen khi phong to; Godot
	-- phong quanh pivot_offset, ma truc y thi nguoc nhau.
	local sz = gd.size
	gd.pivot_offset = Vector2(x * sz.x, (1.0 - y) * sz.y)
	if not la_lop(gd) then
		self:setPosition(cx, cy)
	end
end

function Node:setScaleX(s) local g = raw(self); g.scale = Vector2(s, g.scale.y) end
function Node:setScaleY(s) local g = raw(self); g.scale = Vector2(g.scale.x, s) end
function Node:setScale(s)  raw(self).scale = Vector2(s, s) end
function Node:getScaleX()  return raw(self).scale.x end
function Node:getScaleY()  return raw(self).scale.y end

function Node:setRotation(deg)
	raw(self).rotation_degrees = -deg    -- Cocos quay nguoc chieu Godot
end

function Node:getRotation()
	return -raw(self).rotation_degrees
end

-- Nhan BA SO ROI: ban goc goi setColor(r, g, b) — hon 300 cho. Ban dau lam ra
-- nhan mot bang {r,g,b} nen moi cho do deu bao 'arithmetic on field r'.
-- Van nhan ca dang bang, vi co vai cho truyen tColor.
function Node:setColor(r, g, b)
	if type(r) == 'table' then
		r, g, b = r.r or r.R or r[1], r.g or r.G or r[2], r.b or r.B or r[3]
	end
	if type(r) ~= 'number' or type(g) ~= 'number' or type(b) ~= 'number' then
		return
	end
	local gd = raw(self)
	if gd:is_class('ColorRect') then
		local c = gd.color
		gd.color = Color(r / 255.0, g / 255.0, b / 255.0, c.a)
		return
	end
	local m = gd.modulate
	gd.modulate = Color(r / 255.0, g / 255.0, b / 255.0, m.a)
end

-- Lop mau (CCLayerColorRoundRect) mang mau CUA CHINH NO, khong phai mot sac
-- do nhuom len anh — nen phai dat vao color chu khong phai modulate. Lam
-- nhuong thi lop che khong bao gio hien: ban ghi cua no la (0,0,0, A=0), ma
-- modulate chi NHAN vao mau san, nen 0 nhan gi cung ra 0.
local function la_lop_mau(gd)
	return gd:is_class('ColorRect')
end

function Node:setOpacity(o)
	local gd = raw(self)
	if la_lop_mau(gd) then
		local c = gd.color
		gd.color = Color(c.r, c.g, c.b, o / 255.0)
		return
	end
	local m = gd.modulate
	gd.modulate = Color(m.r, m.g, m.b, o / 255.0)
end

function Node:getOpacity()
	local gd = raw(self)
	if la_lop_mau(gd) then return gd.color.a * 255.0 end
	return gd.modulate.a * 255.0
end

-- zOrder cua Cocos la THU TU VE giua anh em, va ban goc dung toi 9000
-- (lDebugBoxMask) trong khi Godot chi nhan z_index trong khoang +-4096. Nen
-- dat lai thu tu con that su, chu khong dat z_index.
--
-- Day la duong ma goc dua hop thoai len tren lop che: SetOpenZorder goi
-- setZOrder(self.OpenZorder) — 50 voi hop thoai thuong, tren lop che (20) va
-- duoi thanh nut Back (60).
function Node:setZOrder(z)
	local gd = raw(self)
	gd:set_meta('zorder', z)
	local cha = gd:get_parent()
	if cha ~= nil then _godot_zsort(cha) end
end

function Node:getZOrder()
	local gd = raw(self)
	if gd:has_meta('zorder') then return gd:get_meta('zorder') end
	return 0
end
function Node:setGray(_) end          -- lam mo: chua lam, khong hong gi

-- Chu ----------------------------------------------------------------------

function Node:setString(s)
	local gd = raw(self)
	if gd.text ~= nil then
		gd.text = tostring(s)
	end
end

function Node:getString()
	local gd = raw(self)
	if gd.text ~= nil then
		return gd.text
	end
	return ''
end

-- Anh ----------------------------------------------------------------------
-- Ban goc gan anh luc CHAY, khong phai trong file bo cuc:
--    node:setDisplayFrame(S_CCSpriteFrameCache:spriteFrameByName("abc.png"))
-- Day la ly do bo cuc dung khong thi man hinh gan nhu trong tron.

-- Node tao LUC CHAY ------------------------------------------------------
-- Ban goc tao node ngoai bo cuc o 33 cho. Nhieu nhat la RichLabel: no cat
-- chuoi thanh tung doan theo dinh dang roi lam mot Label cho moi doan.

function M.new_node(kieu)
	return wrap(_godot_new_node(kieu))
end

-- Chu tao luc chay.
function Node:createWithTTF(txt, _font, size)
	local gd = raw(self)
	if gd.text ~= nil then
		gd.text = tostring(txt)
		if type(size) == 'number' and size > 0 then
			gd:add_theme_font_size_override('font_size', size)
		end
		gd.size = gd:get_minimum_size()
	end
	return self
end

Node.initWithString = Node.createWithTTF
Node.setFontSize = function(self, size)
	local gd = raw(self)
	if type(size) == 'number' and size > 0 then
		gd:add_theme_font_size_override('font_size', size)
	end
end

-- Bong do va vien chu: Godot lam duoc ca hai qua theme override.
function Node:enableShadow(r, g, b, a, ox, oy)
	local gd = raw(self)
	if gd.text == nil then return end
	gd:add_theme_color_override('font_shadow_color',
		Color((r or 0) / 255, (g or 0) / 255, (b or 0) / 255, (a or 255) / 255))
	gd:add_theme_constant_override('shadow_offset_x', math.floor(ox or 2))
	-- Truc y nguoc chieu nhau.
	gd:add_theme_constant_override('shadow_offset_y', -math.floor(oy or -2))
end

function Node:enableOutline(r, g, b, a, day)
	local gd = raw(self)
	if gd.text == nil then return end
	gd:add_theme_color_override('font_outline_color',
		Color((r or 0) / 255, (g or 0) / 255, (b or 0) / 255, (a or 255) / 255))
	gd:add_theme_constant_override('outline_size', math.floor((day or 1) * 2))
end

-- CHUA LAM: ban goc lay TUNG CHU cua mot label ra lam mot sprite rieng roi
-- tu xep cho (RichLabel:createSprite_). Godot khong cho voi vao tung chu nhu
-- vay, va lam lai bang tay thi phai tu do tung chu mot. Tra 0 nghia la khong
-- co chu nao de lay: doan chu VAN HIEN (Label da duoc addChild o dong tren),
-- chi khong duoc xep lai tung chu.
function Node:getLimitShowCount()
	note('getLimitShowCount')
	return 0
end

function Node:getLetterEx(_, _)
	note('getLetterEx')
	return nil
end

local Frame = {}
Frame.__index = Frame

-- Dem tham chieu cua Cocos, tren cac doi tuong KHONG phai node (khung anh, o
-- danh sach...). Godot tu lo doi song, nen chi can khong hong: CElementPond
-- gom lai roi goi sngRetainMgr:retainObj(obj), va ham do goi obj:retain().
function Frame:retain() return self end
function Frame:release() end
function Frame:autorelease() return self end

M.frames = setmetatable({}, { __mode = 'v' })

local function frame(name)
	local f = M.frames[name]
	if f == nil then
		f = setmetatable({ name = name }, Frame)
		M.frames[name] = f
	end
	return f
end

function Node:setDisplayFrame(f)
	if f == nil then
		return
	end
	local ten = (type(f) == 'table' and f.name) or tostring(f)
	_godot_frame(raw(self), ten)
end

-- Gan anh theo DUONG DAN TEP, khac voi setDisplayFrame (theo ten khung trong
-- atlas). Ban goc dung 82 lan, dang chu yeu la anh nen kho lon:
--    lNormalDlgBackGround:initWithFile("png/background/v6/ui_background262.jpg")
function Node:initWithFile(path)
	if path == nil or path == '' then
		return false
	end
	return _godot_frame(raw(self), tostring(path))
end

-- Phat mot dong tac cua armature (hop do _godot_tao_rig tao, con la SngRig).
-- Ma goc goi 440 lan, vd nha cua canh Main: pDeco:_Lua_playAnimation("Play").
function Node:_Lua_playAnimation(ten)
	local gd = raw(self)
	for i = 0, gd:get_child_count() - 1 do
		local r = gd:get_child(i)
		if r:has_method('animations') and r:has_method('play') then
			return r:play(tostring(ten))
		end
	end
	return false
end

-- Gan anh theo TEN KHUNG (giong setDisplayFrame(spriteFrameByName(ten))). Ma
-- goc goi 69 lan luc vao canh Main: khung chon, chan dung, tab, bieu tuong.
function Node:initWithSpriteFrameName(ten)
	if ten == nil or ten == '' then
		return false
	end
	return _godot_frame(raw(self), tostring(ten))
end

M.spriteFrameCache = {
	spriteFrameByName = function(_, name) return frame(name) end,
	addSpriteFramesWithFile = function() end,
}

-- Bang chu -----------------------------------------------------------------
-- GetStringWithKey(key) -> g_CLuaFont:GetStringByKey(key). Bang chu tieng
-- Viet cua ban goc nam trong conf/text_vi.xgg (JSON thuan, 16.894 khoa).

M.luaFont = {
	GetStringByKey = function(_, key)
		if key == nil then return '' end
		return _godot_text(tostring(key))
	end,
	-- initGameConfig (set.lua:505) goi g_CLuaFont:LoadFile("conf/text_vi.xgg").
	-- Bang chu nay DA nap san tu data_ref/text_vi.json — do text_table.py dung
	-- tu chinh file do — nen chi can bao thanh cong. Thieu ham nay thi
	-- initGameConfig chet ngay dong do, bo do phan con lai cua no.
	LoadFile = function() return true end,
}

-- Danh sach cuon ------------------------------------------------------------
-- G_CTableViewMgr cua ban goc. CUIGuildTableView goi:
--    CreateTableView(khung, doi_tuong_uy_quyen)
--    CreateTableViewCell(ten, node_mau)
--    tableView:resetNumberOfCellsInTableView(n, ...)  /  :reloadData()
-- roi engine hoi nguoc lai qua tableCellSizeForIndex / tableCellAtIndex.

local Cell = {}
Cell.__index = Cell
-- Dem tham chieu cua Cocos: bay man goi sngRetainMgr:retainObj(self.tableView)
-- va ham do goi obj:retain(). Godot tu lo doi song nen chi can khong hong.
function Cell:retain() return self end
function Cell:release() end
function Cell:autorelease() return self end

function Cell:getView()
	return self.view
end

local TableView = {}
TableView.__index = TableView
-- Dem tham chieu cua Cocos: bay man goi sngRetainMgr:retainObj(self.tableView)
-- va ham do goi obj:retain(). Godot tu lo doi song nen chi can khong hong.
function TableView:retain() return self end
function TableView:release() end
function TableView:autorelease() return self end

function TableView:resetNumberOfCellsInTableView(n, _, _)
	self.count = n or 0
	self:reloadData()
end

function TableView:reloadData()
	local khung = raw(self.container)
	-- Don o cu
	for _, c in ipairs(self.cells) do
		local v = raw(c.view)
		if v ~= nil and v:get_parent() ~= nil then
			v:get_parent():remove_child(v)
		end
	end
	self.cells = {}
	self.theo_so = {}
	if self.delegate == nil then
		return
	end

	-- Cat phan tran ra ngoai khung, dung nhu danh sach cuon cua ban goc.
	khung.clip_contents = true

	-- Xep tu TREN xuong. Cocos xep tu duoi len, nhung danh sach cua ban goc
	-- hien ra thu tu tu tren xuong, nen o day xep theo cai nhin thay.
	--
	-- Giu nguyen le TRAI cua node mau: mau khong dat o x=0 ma thut vao mot
	-- doan, va moi thu ben trong dong deu do theo do. Dat ve 0 thi ca dong
	-- truot sang trai va ten bi cat mat.
	local y = 0.0
	for i = 0, self.count - 1 do
		local w, h = self.delegate:tableCellSizeForIndex(self, i)
		h = h or 0
		-- Dung o nao hong thi GHI LAI roi di tiep, dung de chet ca danh sach.
		-- Ma goc dung mot ham callback cho tung o; mot o thieu du lieu se nem
		-- loi, va neu de no chay len tren thi nhung o SAU do khong bao gio
		-- duoc dung, danh sach ngan di ma khong ai biet tai sao.
		local okc, cell = pcall(function()
			return self.delegate:tableCellAtIndex(self, i)
		end)
		if not okc then
			M.cell_errors[#M.cell_errors + 1] = 'o ' .. i .. ': ' .. tostring(cell)
			cell = nil
		end
		if cell ~= nil then
			local v = raw(cell.view or cell)
			if v ~= nil then
				if v:get_parent() ~= nil then
					v:get_parent():remove_child(v)
				end
				khung:add_child(v)
				v.position = Vector2(self.le_trai, y)
				v.visible = true
				self.cells[#self.cells + 1] = cell
				self.theo_so[i] = cell
			end
			y = y + h
		end
	end
end

function TableView:dequeueCell(_)
	return nil          -- luon tao moi; dung nhung cham hon, khong sai
end

-- O thu idx (tinh tu 0, nhu CCTableView) — hoac nil neu o do chua dung.
-- CUIGuildTableView:GetItem (CUIGuildTableViewList.lua:376) tru 1 tu chi so
-- Lua roi goi day, lay :getView(); man xep tuong (CUIBattleDeploy
-- :getItemByHeroID) di qua cho nay moi khi bam vao mot tuong.
function TableView:cellAtIndex(idx)
	return self.theo_so[idx]
end

function TableView:getContentOffset() return 0, 0 end
function TableView:setContentOffset() end

M.tableViewMgr = {
	CreateTableView = function(_, container, delegate)
		-- Le trai = 0. Da thu lay theo vi tri cua node mau: KHONG dung, vi
		-- node mau khong nam trong khung cuon nen toa do cua no tinh theo
		-- goc khac — lay sang thi ca danh sach truot thang sang phai.
		return setmetatable({
			container = container, delegate = delegate,
			count = 0, cells = {}, theo_so = {}, le_trai = 0.0,
		}, TableView)
	end,
	CreateTableViewCell = function(_, _, mau)
		local ban_sao = wrap(_godot_copy(raw(mau)))
		return setmetatable({ view = ban_sao }, Cell)
	end,
}

-- He action ------------------------------------------------------------------
-- Tach ra lua/actions.lua cho de doc: ca he chay/xep chuoi/lap nam gon mot cho.

-- CCDirector. Ban goc goi 9 phuong thuc, va mot nua la viec cua engine ma ta
-- khong co (doi canh, gui tin cho cua so). Cai duy nhat can that la
-- getWinSize; cleanTimeAccum thi duong Show goi ngay giua chung
-- (CUIManager.lua:909) nen khong the de la bong.
-- Chup lai kich thuoc cua so NGAY LUC NAY. Ban goc co
-- system/engine.lua:159 'screenWidth, screenHeight = S_CCDirector:getWinSize()'
-- va ca file do la be mat rang buoc C++ ma ta khong co — nap no vao thi 70
-- bien S_CC* thanh bong het. Ta nap lai lop gia lap DE LEN sau khi nap ban
-- goc, nen phai nho san so dung, khong thi doc lai chinh cai bong vua de len.
local WIN_W = rawget(_G, 'screenWidth') or 960
local WIN_H = rawget(_G, 'screenHeight') or 640
M.win_w, M.win_h = WIN_W, WIN_H

M.director = {
	getWinSize = function() return WIN_W, WIN_H end,
	cleanTimeAccum = function() end,
	setIsTimeAccumEnable = function() end,
	setDispatchEvents = function() end,
	setIsCleanLuaStack = function() end,
	getNoTouchTime = function() return 0 end,
	-- Thay canh dang chay. 8 cho trong ma goc, quan trong nhat la
	-- CSceneManager:OnLoadNextScene (d.633). Canh nam tren SAN KHAU cua
	-- LuaRuntime (set_stage); thay canh = chi hien canh do.
	replaceScene = function(_, canh)
		M.canh_dang_chay = canh
		if _godot_replace_scene ~= nil then _godot_replace_scene(M.raw(canh)) end
	end,
	getRunningScene = function() return M.canh_dang_chay end,
	release = function() end,
}

M.actions = require('actions')(M)

function Node:runAction(a)
	return M.actions.runAction(self, a)
end

function Node:stopAllActions()
	M.actions.stopAllActions(self)
end

function Node:stopActionByTag(tag)
	M.actions.stopActionByTag(self, tag)
end

function Node:getActionByTag(tag)
	return M.actions.getActionByTag(self, tag)
end

function Node:numberOfRunningActions()
	local gd = raw(self)
	local n = 0
	for _, m in ipairs(M.actions.dang_chay) do
		if raw(m.node) == gd then n = n + 1 end
	end
	return n
end

-- Hen gio (S_CCSchedule) ----------------------------------------------------
-- system/engine.lua:22 'S_CCSchedule = CCSchedule:new()' la lop C++, nen
-- khong cai thi ca bo hen gio la bong va moi thu chay theo nhip dung im:
-- CSceneManager doi canh bang mot coroutine chi di tiep khi scheduleOnce goi
-- lai sngLoadingNext, va CTimerManager:BeginTimer (CTimerManager.lua:128) dat
-- nhip 1/24 giay cho moi hen gio cua ma goc. Ma goc goi scheduleOnce 106 lan,
-- schedule 57, scheduleUpdate 12.
--
-- Ngu nghia theo chu thich cua chinh ban goc (CTimerManager.lua:102-117):
--   timer = schedule(obj, ten_ham, khoang = 0, dung = false)
--   timer = schedule(ten_ham_toan_cuc, khoang = 0, dung = false)
--   timer = scheduleUpdate(obj, uu_tien = 0, dung = false)  -> obj:update(dt)
--   timer:pause() / resume() / stop()
-- Khoang 0 la moi khung hinh. Nhu CCTimer cua Cocos 1.x: du khoang thi goi
-- MOT lan roi dem lai tu 0, khong goi bu.
local lich = { ds = {} }
M.lich = lich
M.loi_hen = {}

local function goi_hen(h, dt)
	local f, obj
	if type(h.obj) == 'string' then
		f = rawget(_G, h.obj)
	else
		obj = h.obj
		local co, v = pcall(function() return obj[h.ham] end)
		f = co and v or nil
	end
	if type(f) ~= 'function' then return end
	local ok, err
	if obj ~= nil then ok, err = pcall(f, obj, dt) else ok, err = pcall(f, dt) end
	if not ok then
		if #M.loi_hen >= 64 then table.remove(M.loi_hen, 1) end
		M.loi_hen[#M.loi_hen + 1] = tostring(h.ham or h.obj) .. ': ' .. tostring(err)
	end
end

local Hen = {}
Hen.__index = Hen
function Hen:pause() self.dung = true end
function Hen:resume() self.dung = false end
function Hen:stop() self.het = true end
function Hen:retain() return self end
function Hen:release() end

local function them(obj, ham, khoang, dung, mot_lan)
	local h = setmetatable({ obj = obj, ham = ham, khoang = tonumber(khoang) or 0,
		dung = dung == true, mot_lan = mot_lan, da_qua = 0 }, Hen)
	lich.ds[#lich.ds + 1] = h
	return h
end

function lich:schedule(obj, ham, khoang, dung)
	if type(obj) == 'string' then return them(obj, nil, ham, khoang, false) end
	return them(obj, ham, khoang, dung, false)
end

function lich:scheduleUpdate(obj, _, dung)
	return them(obj, 'update', 0, dung, false)
end

-- Goi MOT lan, o khung hinh SAU du tre = 0. CSceneManager dua vao dung dieu
-- nay de nhuong coroutine: goi lai ngay thi no resume chinh coroutine dang
-- chay, va Lua bao 'cannot resume non-suspended coroutine'.
function lich:scheduleOnce(obj, ham, tre)
	if type(obj) == 'string' then return them(obj, nil, ham, nil, true) end
	return them(obj, ham, tre, nil, true)
end

function lich:release() end

-- So hen MOT LAN con cho: canh dang doi, man hinh dang doi goi lai.
function lich.cho()
	local n = 0
	for _, h in ipairs(lich.ds) do
		if h.mot_lan and not h.het then n = n + 1 end
	end
	return n
end

function lich.tick(dt)
	-- Chup danh sach truoc: hen dat trong luc goi thi chay tu khung sau.
	local ds = lich.ds
	lich.ds = {}
	local con = {}
	for _, h in ipairs(ds) do
		if not h.het and not h.dung then
			h.da_qua = h.da_qua + dt
			if h.da_qua >= h.khoang then
				goi_hen(h, h.da_qua)
				h.da_qua = 0
				if h.mot_lan then h.het = true end
			end
		end
		if not h.het then con[#con + 1] = h end
	end
	for _, h in ipairs(lich.ds) do con[#con + 1] = h end
	lich.ds = con
end

-- Goi moi khung hinh tu GDScript. Action truoc, hen gio sau — dung thu tu
-- cua CCScheduler (bo quan ly action la mot hen gio uu tien cao hon).
-- Tra ve so viec con dang do: action dang chay + hen mot lan con cho.
function M.tick(dt)
	local n = M.actions.tick(dt) or 0
	lich.tick(dt)
	return n + lich.cho()
end

return M
