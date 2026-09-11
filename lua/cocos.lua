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
		mt.__index = Node
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

local function anchor_of(gd)
	if gd:has_meta('cocos') then
		local c = gd:get_meta('cocos')
		return c.z, c.w
	end
	return 0.0, 0.0
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

local function to_godot(gd, x, y)
	local ax, ay = anchor_of(gd)
	local sz = gd.size
	return x - ax * sz.x, parent_h(gd) - (y - ay * sz.y) - sz.y
end

local function to_cocos(gd)
	local ax, ay = anchor_of(gd)
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
	if p ~= nil then
		p:remove_child(c)
	end
	raw(self):add_child(c)
	if tag ~= nil then
		c:set_meta('tag', tag)
	end
	if z ~= nil then
		c.z_index = z
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

function Node:setAnchorPoint(x, y)
	if y == nil then
		x, y = x.x, x.y
	end
	local gd = raw(self)
	local cx, cy = to_cocos(gd)
	gd:set_meta('cocos', Vector4(cx, cy, x, y))
	self:setPosition(cx, cy)
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

function Node:setColor(c)
	local gd = raw(self)
	local m = gd.modulate
	gd.modulate = Color(c.r / 255.0, c.g / 255.0, c.b / 255.0, m.a)
end

function Node:setOpacity(o)
	local gd = raw(self)
	local m = gd.modulate
	gd.modulate = Color(m.r, m.g, m.b, o / 255.0)
end

function Node:setZOrder(z) raw(self).z_index = z end
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

local Frame = {}
Frame.__index = Frame

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
}

-- Danh sach cuon ------------------------------------------------------------
-- G_CTableViewMgr cua ban goc. CUIGuildTableView goi:
--    CreateTableView(khung, doi_tuong_uy_quyen)
--    CreateTableViewCell(ten, node_mau)
--    tableView:resetNumberOfCellsInTableView(n, ...)  /  :reloadData()
-- roi engine hoi nguoc lai qua tableCellSizeForIndex / tableCellAtIndex.

local Cell = {}
Cell.__index = Cell

function Cell:getView()
	return self.view
end

local TableView = {}
TableView.__index = TableView

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
		local cell = self.delegate:tableCellAtIndex(self, i)
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
			end
			y = y + h
		end
	end
end

function TableView:dequeueCell(_)
	return nil          -- luon tao moi; dung nhung cham hon, khong sai
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
			count = 0, cells = {}, le_trai = 0.0,
		}, TableView)
	end,
	CreateTableViewCell = function(_, _, mau)
		local ban_sao = wrap(_godot_copy(raw(mau)))
		return setmetatable({ view = ban_sao }, Cell)
	end,
}

return M
