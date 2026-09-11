-- Lop gia lap Cocos2d-x cho ma nguon Lua cua ban goc.
--
-- Ban goc chay tren Cocos2d-x doi cu (goi setIsVisible chu khong phai
-- setVisible, tuc la nhanh 1.x). Thay vi chep tay 324.000 dong giao dien sang
-- GDScript, ta cho chinh ma do chay, va dich tung loi goi sang node Godot.
--
-- Moi node Cocos o day la mot BAN BOC: mot bang Lua giu tham chieu toi Control
-- cua Godot trong truong _gd. Phai boc vi Godot dua object sang Lua duoi dang
-- userdata co san metatable rieng, khong gan them phuong thuc vao duoc.
--
-- Truc toa do: Cocos lay goc o DUOI-TRAI, y huong len, va x/y la DIEM NEO.
-- Godot lay goc TREN-TRAI, y huong xuong, va vi tri la goc tren-trai cua o.
-- Moi cho doi qua lai deu di qua to_godot()/to_cocos() duoi day.

local M = {}

local Node = {}
Node.__index = Node
M.Node = Node

-- Bang boc dung chung, khoa yeu theo gia tri de node bi huy thi don duoc.
local boxed = setmetatable({}, { __mode = 'v' })

local function wrap(gd)
	if gd == nil then
		return nil
	end
	local id = gd:get_instance_id()
	local w = boxed[id]
	if w == nil then
		w = setmetatable({ _gd = gd }, Node)
		boxed[id] = w
	end
	return w
end
M.wrap = wrap

local function unwrap(v)
	if type(v) == 'table' and v._gd ~= nil then
		return v._gd
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

-- (x, y) Cocos -> vi tri goc tren-trai cua Godot
local function to_godot(gd, x, y)
	local ax, ay = anchor_of(gd)
	local sz = gd.size
	return x - ax * sz.x, parent_h(gd) - (y - ay * sz.y) - sz.y
end

-- vi tri Godot -> (x, y) Cocos
local function to_cocos(gd)
	local ax, ay = anchor_of(gd)
	local sz = gd.size
	local p = gd.position
	return p.x + ax * sz.x, parent_h(gd) - p.y - sz.y + ay * sz.y
end

-- Cay node -----------------------------------------------------------------

-- Tag THAT, do tu chinh engine ban goc. Tag khong nam trong file .xgg —
-- engine sinh ra luc nap — nen phai chay ban goc trong may ao roi hoi tung
-- so mot. Xem work/emu_tags.py va work/emu_join.py.
--
-- Node nao khong co tag la node engine khong tra ve: getChildByTag chi tra
-- ve cai DAU TIEN mang tag do, nen anh em trung tag thi nhung cai sau bi
-- khuat — va ma goc cung khong voi toi chung.
--
-- Van dem tim hut, de biet con man nao thieu du lieu do.
M.tag_lookups = 0
M.tag_misses = 0

function Node:getChildByTag(tag)
	local gd = self._gd
	M.tag_lookups = M.tag_lookups + 1
	for i = 0, gd:get_child_count() - 1 do
		local c = gd:get_child(i)
		if c:has_meta('tag') and c:get_meta('tag') == tag then
			return wrap(c)
		end
	end
	M.tag_misses = M.tag_misses + 1
	return nil
end

function Node:getChildByStringTag(s)
	local gd = self._gd
	for i = 0, gd:get_child_count() - 1 do
		local c = gd:get_child(i)
		if c:has_meta('cls') and c:get_meta('cls') == s then
			return wrap(c)
		end
	end
	return nil
end

function Node:getStringTag()
	local gd = self._gd
	if gd:has_meta('cls') then
		return gd:get_meta('cls')
	end
	return ''
end

function Node:setStringTag(s)
	self._gd:set_meta('cls', s)
end

function Node:getTag()
	local gd = self._gd
	if gd:has_meta('tag') then
		return gd:get_meta('tag')
	end
	return -1
end

function Node:setTag(t)
	self._gd:set_meta('tag', t)
end

function Node:getParent()
	return wrap(self._gd:get_parent())
end

function Node:getChildrenCount()
	return self._gd:get_child_count()
end

function Node:addChild(child, z, tag)
	local c = unwrap(child)
	local p = c:get_parent()
	if p ~= nil then
		p:remove_child(c)
	end
	self._gd:add_child(c)
	if tag ~= nil then
		c:set_meta('tag', tag)
	end
	if z ~= nil then
		c.z_index = z
	end
end

function Node:removeFromParentAndCleanup(_)
	local gd = self._gd
	local p = gd:get_parent()
	if p ~= nil then
		p:remove_child(gd)
	end
	gd:queue_free()
end

function Node:removeAllChildrenWithCleanup(_)
	local gd = self._gd
	for i = gd:get_child_count() - 1, 0, -1 do
		local c = gd:get_child(i)
		gd:remove_child(c)
		c:queue_free()
	end
end

-- Hien / an ----------------------------------------------------------------

function Node:setIsVisible(v)
	self._gd.visible = v and true or false
end

function Node:getIsVisible()
	return self._gd.visible
end

-- Vi tri, kich thuoc, bien doi ---------------------------------------------

function Node:setPosition(x, y)
	if y == nil then           -- goi kieu setPosition(CCPoint)
		x, y = x.x, x.y
	end
	local gx, gy = to_godot(self._gd, x, y)
	self._gd.position = Vector2(gx, gy)
end

function Node:getPosition()
	local x, y = to_cocos(self._gd)
	return x, y
end

function Node:setPositionX(x)
	local _, y = to_cocos(self._gd)
	self:setPosition(x, y)
end

function Node:setPositionY(y)
	local x, _ = to_cocos(self._gd)
	self:setPosition(x, y)
end

function Node:getPositionX()
	local x, _ = to_cocos(self._gd)
	return x
end

function Node:getPositionY()
	local _, y = to_cocos(self._gd)
	return y
end

-- Tra HAI gia tri, khong phai mot bang. Da dem tren ca ma goc: 742 cho viet
-- 'local w, h = node:getContentSize()', 0 cho dung '.width'. Ban dau lam ra
-- bang nen moi cho do deu nhan w = bang, h = nil.
function Node:getContentSize()
	local s = self._gd.size
	return s.x, s.y
end

function Node:setContentSize(w, h)
	if h == nil then
		w, h = w.width, w.height
	end
	self._gd.size = Vector2(w, h)
end

function Node:setAnchorPoint(x, y)
	if y == nil then
		x, y = x.x, x.y
	end
	local gd = self._gd
	local cx, cy = to_cocos(gd)
	gd:set_meta('cocos', Vector4(cx, cy, x, y))
	self:setPosition(cx, cy)
end

function Node:setScaleX(s)
	self._gd.scale = Vector2(s, self._gd.scale.y)
end

function Node:setScaleY(s)
	self._gd.scale = Vector2(self._gd.scale.x, s)
end

function Node:setScale(s)
	self._gd.scale = Vector2(s, s)
end

function Node:getScaleX()
	return self._gd.scale.x
end

function Node:getScaleY()
	return self._gd.scale.y
end

function Node:setRotation(deg)
	self._gd.rotation_degrees = -deg    -- Cocos quay nguoc chieu Godot
end

function Node:getRotation()
	return -self._gd.rotation_degrees
end

function Node:setColor(c)
	local m = self._gd.modulate
	self._gd.modulate = Color(c.r / 255.0, c.g / 255.0, c.b / 255.0, m.a)
end

function Node:setOpacity(o)
	local m = self._gd.modulate
	self._gd.modulate = Color(m.r, m.g, m.b, o / 255.0)
end

function Node:setZOrder(z)
	self._gd.z_index = z
end

-- Chu ----------------------------------------------------------------------

function Node:setString(s)
	local gd = self._gd
	if gd.text ~= nil then
		gd.text = tostring(s)
	end
end

function Node:getString()
	local gd = self._gd
	if gd.text ~= nil then
		return gd.text
	end
	return ''
end

-- Chua lam -----------------------------------------------------------------
-- Cac API con lai (runAction, setDisplayFrame, CCTableView, he cat canh...)
-- se bu dan. Bat chung o day de bao LOI RO RANG thay vi 'attempt to call a
-- nil value' o giua mot file 3000 dong, va de dem duoc con thieu nhung gi.

M.missing = {}

setmetatable(Node, {
	__index = function(_, name)
		return function(...)
			M.missing[name] = (M.missing[name] or 0) + 1
			return nil
		end
	end,
})

return M
