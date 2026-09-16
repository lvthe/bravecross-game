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
-- Hut theo TUNG TAG, khong theo tung man. Can vi mot phan lon hut KHONG phai
-- loi: ma goc dung getChildByTag lam phep THU CO MAT ("if item:getChildByTag(tag)
-- then removeChildByTag(tag) end" — CUIPublic.lua:569, CUIHeroListEx.lua:858),
-- lan goi dau tien truot la dung y do. Dem theo tag moi tach duoc nhom do ra
-- khoi hut that; so do tren toan bo luot quet ghi o ROADMAP.
M.tag_miss_theo_tag = {}
M.cell_errors = {}   -- o danh sach dung hong -> de doc ra
-- Lop RIENG theo ten node trong .xgg: node mang ten nay tra ham o bang nay
-- truoc (bang do tu __index ve Node). g_BattleField: lua/san_tran.lua.
M.lop_rieng = {}
-- Lop RIENG theo LOAI node (meta 'type_name', tuc typeName cua .xgg), dung
-- cho nhung lop ma moi node cung loai deu phai xu su nhu engine: hien co
-- CCScrollLayer (lua/cuon.lua). Ten node cu the van thang loai — lop_rieng
-- xet truoc — vi lop_rieng gan chat voi mot node duy nhat.
M.lop_theo_loai = {}
-- Lop CUON (lua/cuon.lua). cocos.lua khong biet gi ve cuon; no chi goi vao
-- day o hai cho: M.cham (nhan truoc, co the nuot) va M.tick (hieu ung nha).
M.cuon = nil

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
		local loai = gd:has_meta('type_name') and tostring(gd:get_meta('type_name')) or nil
		mt.__index = (ten ~= nil and M.lop_rieng[ten])
			or (loai ~= nil and M.lop_theo_loai[loai])
			or Node
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
--
-- TAG LE: ma goc co cho truyen vao mot so KHONG NGUYEN, va tren ban goc no VAN
-- TIM RA. CUIStar.lua:236-249 — 'local nOffsetStar = delta/2' roi
-- 'idx = i + nOffsetStar' — phep chia cua Lua 5.1 LUON ra so thuc, nen
-- getChildByTag nhan 3.5 / 4.5 / 2.5. Binding C++ cua Cocos khai tham so la
-- 'int' va tolua ep bang '(int)tolua_tonumber(...)', tuc CAT VE PHIA 0, nen
-- 3.5 tra ve node tag 3. Do duoc: tag le chiem 228/2132 luot hut (3,5 x72,
-- 4,5 x72, 2,5 x42, 5,5 x42) — va do la hut SAI, khong phai thieu tag: neu
-- that su truot thi 'pOneStar:setIsVisible(true)' khong bao gio chay, tuc ban
-- goc khong bao gio hien ngoi sao nao. Nay cat ve phia 0 y nhu tolua.
function Node:getChildByTag(tag)
	if type(tag) == 'number' and tag % 1 ~= 0 then
		tag = tag > 0 and math.floor(tag) or math.ceil(tag)
	end
	local gd = raw(self)
	M.tag_lookups = M.tag_lookups + 1
	for i = 0, gd:get_child_count() - 1 do
		local c = gd:get_child(i)
		if c:has_meta('tag') and c:get_meta('tag') == tag then
			return wrap(c)
		end
	end
	M.tag_misses = M.tag_misses + 1
	-- `tag` co the la nil: ma goc co vai cho goi getChildByTag() tran (Cocos se
	-- bao loi tolua, con o day thi bo dem theo tag se vo vi khoa nil — da dinh
	-- that: 'cocos.lua:208: table index is nil' lam hong 4 bo kiem). Khong dem
	-- thi van ghi nhat ky nhu thuong.
	if tag ~= nil then
		M.tag_miss_theo_tag[tag] = (M.tag_miss_theo_tag[tag] or 0) + 1
	end
	-- Ghi lai cho truot, kem ten node cha va cac tag no THAT SU co. Khong co
	-- cai nay thi chi biet "co cho hut" chu khong biet hut o dau.
	--
	-- Nhieu node cha KHONG co ten (`?`), va do la lo hong cua chinh nhat ky:
	-- do duoc 204 luot `? hoi tag 4, chi co: 1,2,3` — cho hut lon nhat trong ca
	-- bang — ma khong cach nao biet no o man nao. Nen khi cha khong ten thi di
	-- NGUOC len tim to tien co ten gan nhat va ghi ca duong di.
	local ten = gd:has_meta('xgg_name') and gd:get_meta('xgg_name') or nil
	if not ten then
		local duong, p, sau = {}, gd:get_parent(), 0
		while p ~= nil and sau < 24 do
			local t = p:has_meta('xgg_name') and p:get_meta('xgg_name') or nil
			duong[#duong + 1] = t or '?'
			if t then break end
			p, sau = p:get_parent(), sau + 1
		end
		ten = '?<' .. table.concat(duong, '<') .. '>'
	end
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
	if type(tag) == 'number' and tag % 1 ~= 0 then
		tag = tag > 0 and math.floor(tag) or math.ceil(tag)
	end
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

-- Ban goc hoi bang TEN TAI NGUYEN cua node (truong 'res' trong .xgg), KHONG
-- phai 'cls'. Do tren 267 chuoi ma sc/ hoi bang ham nay (296 bo cuc):
--   * 15 chuoi CHI co o 'res' va khong he co o 'cls' — 'vsInfo', 'rankN',
--     'cellBg', 'exchangeLabel', 'logoSp', 'lookBtn', 'prize01', 'root',
--     'scoreLayer', 'ttfNumIos', 'materialNode'... Vay phep
--     khop theo 'cls' lam 15 cho goi khong bao gio tim thay, tren BAN GOC DA
--     SHIP. Do la loi cua lop gia lap, khong phai lo hong cua game.
--   * 0 chuoi chi co o 'cls' — nen them 'res' khong pha gi.
-- Vi du do duoc: node 'petslist' co res='list', cls='petslist'; node
-- 'selectTab' co res='selectTab', cls='切换标签' (chu thich cua hoa si). Ca hai
-- man deu hong y het nhau vi ta khop 'cls'.
-- Giu 'cls' lam duong du phong: do la cho setStringTag ghi luc chay.
function Node:getChildByStringTag(s)
	local gd = raw(self)
	local n = gd:get_child_count()
	for i = 0, n - 1 do
		local c = gd:get_child(i)
		if c:has_meta('res') and c:get_meta('res') == s then
			return wrap(c)
		end
	end
	for i = 0, n - 1 do
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

-- Ten LUA cua node — ten instance ghi trong .xgg, KHONG phai ten lop. Ban goc
-- de ham nay trong engine C++ chu khong trong Lua: 20 cho goi, khong cho nao
-- dinh nghia. Truoc day no roi vao bo dem `M.missing` (Node __index tra ve ham
-- rong) nen tra nil, va nhu vay thi im lang dung o cho nguy hiem:
-- CUIMainBuildingManager:onTouchEnd_btnBuilding lay
-- `self.tBuildingData[obj:getLuaName()].pTouchFunction` — khoa nil thi
-- `tBuildingData[nil]` la nil, roi `.pTouchFunction` nem loi. Cac cho khac
-- (CPublic.lua:1658, CActionManager.lua:135) co tu chan nil nen khong lo.
--
-- Tra nil khi node KHONG co ten instance, dung nhu ban goc va dung nhu
-- xgg_layout.gd: chi 2.778/33.472 node co ten that, va "khong ten" khong duoc
-- phep hoa thanh ten lop — neu khong thi ten gia trung nhau (xem chu thich
-- 'TEN INSTANCE va TEN LOP' o ui/xgg_layout.gd).
function Node:getLuaName()
	local gd = raw(self)
	if gd:has_meta('xgg_name') then
		return tostring(gd:get_meta('xgg_name'))
	end
	return nil
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
	-- Lop cuon nhan truoc. No co the NUOT pha End: mot lan keo da qua nguong
	-- thi khong tinh la mot cu bam nua, neu khong thi nha vao nut ma keo se
	-- vua cuon vua mo man. Pha Begin thi lop cuon KHONG nuot — nut van phai
	-- nhan Begin thi moi biet duoc nguoi choi dang cham vao dau.
	if M.cuon ~= nil and M.cuon.cham(pha, gd, a, b, c) then
		return true
	end
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
	-- Node DA DANG KY thi nuot cham ke ca khi no khong co ham cho pha nay:
	-- ccTouchBegan cua no tra true (doi tuong khong co onTouchBegin_ thi khong
	-- co gi de goi, nhung cham VAN bi giu) — nen nut o DUOI khong nhan duoc
	-- Begin nao. Do lai bang tools/verify_cham.gd: node B chi co
	-- onTouchEnd_Tren, ma cu bam vao B chi de lai dung 'B End true' — node A
	-- nam duoi khong he nhan Begin.
	--
	-- Da thu nuot CO DIEU KIEN (khong co ham cho pha nay thi tra false) va do
	-- duoc la SAI: ba bo phai chung minh luat nay do xuong — verify_cham.gd
	-- (3 hong), chien dich (Lua) (3 hong), bam that Main -> tran (5 hong).
	-- Ha tang that cua lan do la lop phu lNormalDlgTouchMask cua hop thoai
	-- dang mo phu kin man (960x640 o (0,0)) — no NUOT la dung, hop thoai la
	-- modal; cho can sua la phep do, khong phai luat nuot.
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

-- Cocos: tra ve MANG con (CCArray). Ban goc duyet no bang `#` va chi so 1..n
-- (vd CUICavern:onCreateSceneDecoration ghep trang tri theo tung con). Thieu no
-- thi `#getChildren()` la `#nil` -> vo. Thu tu theo cay Godot, dung thu tu them.
function Node:getChildren()
	local gd = raw(self)
	local out = {}
	for i = 0, gd:get_child_count() - 1 do
		out[#out + 1] = wrap(gd:get_child(i))
	end
	return out
end

-- Xep lai anh em theo zOrder cua Cocos.
--
-- Ham nay TRUOC DAY KHONG HE TON TAI. `_godot_zsort` duoc goi o hai cho nhung
-- khong dinh nghia o dau, nen no roi vao `_G` gia lap -> tra ve mot BONG, va
-- bong thi goi duoc (tra bong) — tuc `setZOrder` va `addChild(c, z)` **ghi meta
-- roi thoi**, khong xep lai gi ca. Dung kieu loi im lang da gap o `setGray`:
-- khong bo dem nao bat duoc, vi khong co loi nao duoc nem ra.
--
-- Cocos ve anh em theo zOrder TANG DAN, cung zOrder thi theo thu tu them. Godot
-- ve theo THU TU MANG CON, nen xep lai mang y het vay. Khong dung `z_index`:
-- ban goc truyen toi 99999 (`CUISubtitle:AddToParent`) con Godot chi nhan
-- +-4096 (xem chu thich o addChild).
--
-- Xep bang `move_child` theo mot luot TANG DAN: khi buoc k thi k-1 phan tu dau
-- da dung cho, nen day phan tu k ve vi tri k-1 chi lam dich cac phan tu CHUA
-- xep — tien to giu nguyen. Node chua tung dat zOrder tinh la 0.
local function _godot_zsort(cha)
	local n = cha:get_child_count()
	if n < 2 then return end
	local ds = {}
	for i = 0, n - 1 do
		local c = cha:get_child(i)
		local z = 0
		if c:has_meta('zorder') then
			local v = c:get_meta('zorder')
			if type(v) == 'number' then z = v end
		end
		ds[#ds + 1] = { c = c, z = z, i = i }
	end
	table.sort(ds, function(a, b)
		if a.z ~= b.z then return a.z < b.z end
		return a.i < b.i
	end)
	local doi = false
	for k = 1, n do
		if ds[k].i ~= k - 1 then
			doi = true
			break
		end
	end
	if not doi then return end
	for k = 1, n do
		cha:move_child(ds[k].c, k - 1)
	end
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

-- Ten khac cua cung mot viec: `removeAllChildrenAndArray` la ban mo rong cua
-- engine nay (lop cuon), y nghia y nguyen — bo het con va don cai mang con.
-- 37 cho goi, deu la "don sach roi dung lai danh sach" (CUICOGRule.lua:64,
-- CUIContestRewards.lua:381, hai man anniversary). Khac `removeChildByTag`:
-- o day khong co be chua nao nhan lai node da go, nen huy han la dung.
Node.removeAllChildrenAndArray = Node.removeAllChildrenWithCleanup

-- Cocos: CCNode::removeChildByTag(tag, cleanup) — tim con DAU TIEN mang tag do
-- roi go no ra khoi cha. 100 cho goi trong sc/.
--
-- KHONG queue_free, va day la cho DE SAI NHAT. Cocos KHONG huy doi tuong o day:
-- 'cleanup' chi dung hanh dong va bo hen gio, con doi tuong song tiep neu con ai
-- giu. Ma CElementPond (sc/user/Public/CElementPond.lua:282-284) go ra roi
-- addChild lai chinh node do sau — do la mot BE CHUA cho cac o danh sach. Goi
-- queue_free o day thi lan addChild lai se cham vao node da bi huy.
--
-- Khong dem vao tag_lookups/tag_misses: ban goc cung khong dem, va o day phep
-- hoi chi la buoc trung gian cua viec xoa, khong phai mot lan ma goc HOI TRUOT.
function Node:removeChildByTag(tag, cleanup)
	local gd = raw(self)
	for i = 0, gd:get_child_count() - 1 do
		local c = gd:get_child(i)
		if c:has_meta('tag') and c:get_meta('tag') == tag then
			gd:remove_child(c)
			-- Mac dinh cua Cocos la cleanup = true; va ta KHONG lam gi voi co do
			-- vi khong co hanh dong hay hen gio nao de dung o day.
			return
		end
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

-- Cocos: CCNode::reorderChild(child, zOrder) — doi zOrder cua MOT con roi xep
-- lai day anh em. Khac setZOrder o cho no nham vao CON chu khong phai chinh no.
-- Ban goc goi 1 cho trong ma (`CUIArmyGroupCampsite.lua:3583`) nhung nam trong
-- vong lap qua toan bo con, nen do ra **1.200 luot** — cho hut lon nhat trong
-- ca bang "API chua lam" cua luot quet 353 man.
function Node:reorderChild(child, z)
	local gd = raw(self)
	local c = unwrap(child)
	if type(c) ~= 'userdata' and type(c) ~= 'Object' then return end
	if c == nil or c:get_parent() ~= gd then return end
	if z ~= nil then c:set_meta('zorder', z) end
	_godot_zsort(gd)
end
-- To XAM nut (nut bi khoa / khong du dieu kien). Ban goc goi 683 cho, va DOC
-- lai trang thai ay 214 cho bang isGray().
--
-- Hai nua. Phan TRANG THAI (co `gray`) da co tu truoc: thieu no thi 'isGray()'
-- ra nil, ma nil trong Lua khong bang false lan bang true, nen moi nhanh re
-- theo no deu di sai huong TRONG IM LANG ('if btn:isGray() == false then' va
-- 'if not btn:isGray()' nguoc nhau).
--
-- Phan HINH: nay da lam cho node VE. Ban goc doi chuong trinh shader cua node
-- sang chuong trinh so 1 — nguon manh `.rodata 0x7ccf00`:
--
--     float alpha = texture2D(CC_Texture0, v_texCoord).a;
--     float grey  = dot(texture2D(CC_Texture0, v_texCoord).rgb,
--                       vec3(0.299, 0.587, 0.114));
--     gl_FragColor = vec4(grey, grey, grey, alpha);
--
-- Doc ra bang `brave-cross/work/shaderghep.py --bang`, va tai hien lai roi do
-- bang `tools/do_xam.gd` (11/11 dat, ke ca bon tinh chat quirks o dau
-- `ui/xam.gdshader`). Vat lieu o `ui/xam.gd`, bac qua `_godot_dat_xam`.
--
-- CHI node VE co ANH moi di duong shader. Ly do tung loai, do chu khong doan:
--
--   * `TextureRect` / `NinePatchRect` (CCSprite / CCScale9Sprite) — CO anh,
--     dung dung chuong trinh tren. Day la loai ma 674 cho goi `setGray` nham
--     toi: quet 120 node bo cuc trong `_G` thi ca 30 node co `setGray` deu la
--     sprite (phep do `--co-gi` cua `brave-cross/work/emu_xam.py`).
--   * `Label` — KHONG. Ban goc to chu bang duong LUA chu khong bang shader:
--     `CUIPublic:SetLableGray` (`sc/user/Public/CUIPublic.lua:390`) luu
--     getColor/getEffectColor goc roi dat setColor(50,50,50) +
--     setEffectColor(190,190,190). Dem duoc: 132 dong goi SetLableGray, trong
--     khi duong `setGray` tu di xuong con (`CPublic:SetObjGray`) chi co 3 cho.
--     Them nua, shader xam doc ANH chu ma atlas chu thi mau TRANG — chu se ra
--     TRANG chu khong ra xam, lai con mat duong vien. Chinh vi vay ma ma goc
--     co nhieu dong `setGray` tren bien nhan da bi COMMENT san
--     (`--pBtnText:setGray(true)`), va `SetLableGray` moi la duong that.
--   * `ColorRect` (CCLayerColorRoundRect) — **CHUA LAM**, va khong doan bua.
--     Trong ma goc co **12 cho** goi `setGray` nhan vao bien ten kieu lop/nen:
--     `lItemBackground` (CUIActivityLoginTurnplate.lua:204/211), `bgview`
--     (CUISign.lua:1006/1020), `upgradeLayer`/`completeLayer`
--     (CUIResearch.lua:419/430/443/461/489), `pOrdinaryBg` va hai con cua no
--     (CUIActivityLoginRewards.lua:328/329/330) — dem bang
--     grep -rn "\(bgview\|upgradeLayer\|completeLayer\|pOrdinaryBg\|lItemBackground\):setGray(".
--     Da xac dinh duoc DUNG MOT cho trong so do: `lItemBackground` la
--     **CCSprite** (CUIActivityLoginTurnplate.lua:186 goi `setDisplayFrame` tren
--     no), nen no di duong TextureRect binh thuong chu khong roi vao day. Sau
--     cho do thi lop that su KHONG co anh: chuong trinh do doc `CC_Texture0`
--     khong duoc gan, nen ket qua la rac cua GL chu khong phai mot mau nao ta
--     suy ra duoc. Gan shader doc anh o day thi Godot se lay anh TRANG mac dinh
--     va lop mau bien thanh TRANG — sai ro rang; con tu tinh luma cua mau nen
--     thi la SUY DOAN y do tac gia, khong phai phep do. Muon biet that thi phai
--     mo ban goc, goi setGray len DUNG node dang duoc VE, roi doi diem anh —
--     xem ROADMAP muc "setGray".
--   * Cac node khac (Control rong, node mang armature) — KHONG. Ban goc chi
--     doi chuong trinh cua CHINH node, ma node do khong tu ve gi: armature ve
--     o cac node CON cua no nen van giu mau. Dat vat lieu len node cha cung
--     khong co tac dung gi (do duoc, xem `ui/xam.gd`), tuc khop voi ban goc.
local function la_node_ve(gd)
	return gd:is_class('TextureRect') or gd:is_class('NinePatchRect')
end

function Node:setGray(b)
	b = b and true or false
	local gd = raw(self)
	gd:set_meta('gray', b)
	if la_node_ve(gd) then
		_godot_dat_xam(gd, b)
	end
end

function Node:isGray()
	local gd = raw(self)
	return gd:has_meta('gray') and gd:get_meta('gray') or false
end

-- Ban goc goi 56 cho, luon luon truyen true. Cocos: BAT thi do mo cua node cha
-- nhan xuong con (mac dinh TAT). Godot thi 'modulate' LUON nhan xuong cay, tuc
-- lop gia lap cua ta da lam san dung cai ma 56 cho kia xin — nen khong lam gi
-- la dung, khong phai la bo qua.
function Node:setCascadeOpacityEnabled(_) end

-- Dung lai MANG CON sau khi doi thu tu / go nham. Ban goc goi 45 cho
-- (CUIHelper:674/720/774). O day khong co mang con nao de dung lai: moi lan
-- getChildByTag deu quet thang con cua node Godot, nen ham nay la no-op DUNG
-- nghia — khong phai chua lam.
function Node:refreshChildArray(_) end

-- Can chu cua nhan. Ban goc goi 8 cho.
--
-- Thu tu enum y nhu truong alignH cua .xgg: 0 trai, 1 giua, 2 phai — va Godot
-- dung dung ba so do cho HORIZONTAL_ALIGNMENT_* (xem ui/xgg_layout.gd:229-233,
-- cho do doc cung bang nay). Nen ghi thang so, khong can ten enum ben Godot.
-- Ngoai 0..1..2 thi lay trai: Cocos cung chi co ba gia tri.
function Node:setHorizontalAlignment(n)
	local gd = raw(self)
	if gd.text == nil or type(n) ~= 'number' then return end
	local k = math.floor(n)
	if k < 0 or k > 2 then k = 0 end
	gd.horizontal_alignment = k
end

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

-- Co chu dang dung. Mot cho goi (`CUINewHandPrivilege.lua:184`): lay co chu cua
-- nhan co san roi truyen xuong `RichLabel:create` de chu con khop chu cha. Tra
-- 0 khi khong phai nhan — chu KHONG doan mot co chu nao, vi 0 la gia tri ma
-- `RichLabel` tu thay bang co chu mac dinh cua no.
function Node:getFontSize()
	local gd = raw(self)
	if gd.text == nil then return 0 end
	return gd:get_theme_font_size('font_size')
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

-- Ma goc DOC lai mau chu va mau vien roi dat lai — hai duong khac nhau, cung
-- mot muc dich:
--   * CUIPublic:SetLableGray (sc/user/Public/CUIPublic.lua:397-426) luu
--     getColor() + getEffectColor() lam gia tri GOC, roi to xam roi tra lai.
--   * CUIAssist.lua:2062-2063 lam y het.
-- Thieu ca ba ham thi khong bao loi: getColor() ra nil, nen
-- 'btnText:setColor(c.r or 255, ...)' ghi 255 (transparent-ish) va
-- 'setEffectColor(nil,nil,nil,nil)' bi setColor chan lai — tuc nut xam KHONG
-- he xam, va lan sau tra lai cung khong biet gia tri goc la gi. Do duoc tren
-- mot man: getColor / setEffectColor / getEffectColor moi thu bi cham 1281 lan.
--
-- getColor tra dung mau ma setColor ghi: lop mau mang mau o 'color', con lai o
-- 'modulate' (xem setColor ngay tren). Mac dinh cua Cocos la trang.
function Node:getColor()
	local gd = raw(self)
	local c = la_lop_mau(gd) and gd.color or gd.modulate
	return math.floor(c.r * 255.0 + 0.5), math.floor(c.g * 255.0 + 0.5),
		math.floor(c.b * 255.0 + 0.5)
end

-- 描边 (vien chu). Ban goc goi ham nay o 9 file, va khong bao giu do day vien
-- o dau ca — no chi la mau. Nen: chi doi MAU vien, con do day giu nguyen neu da
-- co, chua co thi lay dung mac dinh ma enableOutline dang dung (day = 1).
-- Ghi lai mau vao meta de getEffectColor doc lai duoc — do la ca ly do ham do
-- ton tai (luu gia tri goc roi tra lai).
function Node:setEffectColor(r, g, b, a)
	local gd = raw(self)
	if gd.text == nil then return end
	if type(r) ~= 'number' or type(g) ~= 'number' or type(b) ~= 'number' then return end
	local mau = Color(r / 255.0, g / 255.0, b / 255.0, (a or 255) / 255.0)
	gd:set_meta('effect_color', mau)
	gd:add_theme_color_override('font_outline_color', mau)
	if not gd:has_theme_constant_override('outline_size') then
		gd:add_theme_constant_override('outline_size', 2)
	end
end

function Node:getEffectColor()
	local gd = raw(self)
	if gd:has_meta('effect_color') then
		local c = gd:get_meta('effect_color')
		return math.floor(c.r * 255.0 + 0.5), math.floor(c.g * 255.0 + 0.5),
			math.floor(c.b * 255.0 + 0.5), math.floor(c.a * 255.0 + 0.5)
	end
	-- Chua tung dat: Cocos tra ve mau vien dang ap. Chua co vien nao thi tra
	-- (0,0,0,0) — trong suot, tuc "khong vien" — de lan tra lai khong dung ra
	-- mot duong vien khong he co.
	return 0, 0, 0, 0
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

-- Bon ham armature ma ban goc goi nhieu nhat sau _Lua_playAnimation. Ca bon deu
-- hoi node RIG (SngRig) dang nam duoi node nay, va deu phai chiu duoc truong
-- hop node khong phai rig: bo cuc nao cung co the tro nham, va o day tra ve
-- gia tri vo hai con hon nem loi giua mot man 3000 dong.
local function _rig_cua(gd)
	for i = 0, gd:get_child_count() - 1 do
		local r = gd:get_child(i)
		if r:has_method('animations') and r:has_method('play') then
			return r
		end
	end
	return nil
end

-- Thoi luong dong tac (giay) — ma goc hoi 97 lan de biet cho bao lau.
function Node:_lua_getAnimationTime(ten)
	local r = _rig_cua(raw(self))
	if r == nil or not r:has_method('thoi_luong') then return 0.0 end
	return r:thoi_luong(tostring(ten))
end

-- Dung dong tac, giu tu the dang dung (24 cho).
function Node:_lua_stop()
	local r = _rig_cua(raw(self))
	if r ~= nil and r:has_method('dung') then r:dung() end
end

-- He so toc do dong tac (26 cho).
function Node:_lua_setAnimationRate(he_so)
	local r = _rig_cua(raw(self))
	if r ~= nil and r:has_method('dat_toc_do') and type(he_so) == 'number' then
		r:dat_toc_do(he_so)
	end
end

-- Do mo cua armature (2 cho): ban goc dat thang tren node rig.
function Node:_lua_setOpacity(o)
	local r = _rig_cua(raw(self))
	if r ~= nil and type(o) == 'number' then
		r.modulate.a = o / 255.0
	end
end

-- Diem gan cua armature (plug) --------------------------------------------
-- Ba ham, 48 cho goi: _lua_addChildToPlugIn 33, _lua_clearPlugIn 10,
-- _lua_getPlugInPositionInNode 5. Day la cach ban goc treo mot node Lua (nhan
-- chu, bieu tuong) len mot DIEM CO DINH trong xuong — no di theo dong tac.
-- Vi du: ten anh hung bay ra roi dinh vao tay (CUIUnlockHeroAnimation) hay
-- dong "Thoi gian ket thuc" hien dung cho (FBDingJunShanJiaoFei.lua:85).
--
-- So trong ten plug la SO CHU, da kiem bang mot ca khong the trung: armature
-- Gashapon co dung PlugIn_4_Hero / _5_Word / _6_Light / _7_HeroName, va
-- CUIUnlockHeroAnimation.lua:166-169 goi _lua_clearPlugIn dung 4, 5, 6, 7.
-- Bang do day du o rig/sng_rig.gd, ham plug().
--
-- KHONG co plug thi im lang bo qua: ban goc cung khong bao loi (plug la mot
-- xuong; khong tim thay thi khong co gi de gan).

-- Tra ve diem gan (node Godot), hoac nil.
local function _plug_cua(gd, idx)
	local r = _rig_cua(gd)
	if r == nil or not r:has_method('plug') or type(idx) ~= 'number' then
		return nil
	end
	return r:plug(math.floor(idx))
end

-- Tra ve toa do trong he COCOS cua pParent (y huong LEN tu day pParent), chu
-- khong phai he Godot. Bat buoc phai vay, vi nguoi goi luon lam:
--
--     x, y = pNode:_lua_getPlugInPositionInNode(n, pParent)
--     con:setPosition(x + ..., y + ...)      -- so cong thuc cua ban goc
--     pParent:addChild(con)
--
-- (CUIGainHeroAnimation.lua:502-508, CUIMainBuildingManager.lua:466-470,
-- CUILottery.lua:2562.) Cong thuc ay viet theo truc y huong len, nen tra ve he
-- Godot la dao dau moi so cong thuc cua ban goc.
function Node:_lua_getPlugInPositionInNode(idx, pParent)
	local plug = _plug_cua(raw(self), idx)
	local pp = unwrap(pParent)
	if plug == nil or pp == nil then return 0, 0 end
	if not pp:has_method('get_global_transform') then return 0, 0 end
	-- Toa do toan cuc cua diem gan -> ve he cua pParent (Godot, y huong xuong).
	-- `pp` la node Godot TRAN (unwrap da boc vo), nen goi phuong thuc phai dung
	-- ':'. Dieu nay dung cho CA kieu gia tri cua Godot: 'affine_inverse()' viet
	-- bang '.' cung bao loi y nhu tren Transform2D.
	local p = pp:get_global_transform():affine_inverse() * plug.global_position
	return p.x, parent_h(pp) - p.y
end

-- Treo mot node Lua len diem gan. Node duoc go khoi cha cu truoc (ban goc cung
-- vay: mot node chi co mot cha), roi DAT LAI CHO theo he cua PLUG chu khong
-- theo he cha cu.
--
-- Cho dat lai nay la can thiet chu khong phai cho dep: nguoi goi lam
-- 'pText:setPosition(0, 0)' TRUOC khi gan, va luc ay node con nam trong bo cuc
-- nen so 0 duoc doi qua 'to_godot' bang CHIEU CAO CUA CHA CU (thuong 768).
-- Giu nguyen so Godot ay thi node roi xuong duoi diem gan ~768 px. Nay doc lai
-- dung so nguoi goi da viet (to_cocos) roi doi lai theo he cua plug, tuc chieu
-- cao = 0 vi plug la mot DIEM: y_godot = -y_cocos - (1 - ay) * cao.
function Node:_lua_addChildToPlugIn(idx, pNode)
	local plug = _plug_cua(raw(self), idx)
	local con = unwrap(pNode)
	if plug == nil or con == nil then return end
	if type(con) ~= 'userdata' and type(con) ~= 'Object' then return end
	if not con:has_method('get_parent') then return end
	local x, y = to_cocos(con)
	local cu = con:get_parent()
	if cu ~= nil then
		cu:remove_child(con)
	end
	plug:add_child(con)
	local ax, ay = neo_so(con)
	local sz = con.size
	-- Chieu cao de doi truc y: diem gan la mot DIEM, khong co kich thuoc, nen
	-- lay 0 — dung bang gia tri ma parent_h roi ve khi node khong co cha. Phai
	-- dat lai: khong thi con giu nguyen chieu cao cua cha CU (640 voi node tao
	-- luc chay), va getPosition() doc lai se lech dung bang chieu cao do du node
	-- nam dung cho. Duong addChild thuong cung lam viec nay, nhung no chi lam khi
	-- cha MOI la Control — o day cha la mot Marker2D.
	con:set_meta('parent_h', 0.0)
	con.position = Vector2(x - ax * sz.x, -y - (1.0 - ay) * sz.y)
end

-- Go node dang treo o diem gan. Ban goc go node da treo RA khoi cay, khong huy
-- no — nguoi goi giu tham chieu rieng (CUIUnlockHeroAnimation go ra roi moi
-- removeFromParentAndCleanup chinh cai sprite). Nen o day cung chi go ra.
function Node:_lua_clearPlugIn(idx)
	local plug = _plug_cua(raw(self), idx)
	if plug == nil then return end
	for i = plug:get_child_count() - 1, 0, -1 do
		plug:remove_child(plug:get_child(i))
	end
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
	self.goc_y = {}
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
				self.goc_y[#self.cells] = y
				self.theo_so[i] = cell
			end
			y = y + h
		end
	end
	self.cao_tong = y
	self:dat_lai_cho()
end

--[[ Dat lai cho tung o theo do lech dang cuon.

	`ty_le` la ti le NGUOI GOI xin (0..1); `dich` la so pixel suy ra tu no, va
	duoc tinh lai moi lan vi quang cuon duoc phu thuoc ca noi dung lan khung.
	Goi sau MOI lan xep lai: cuon roi ma xep lai thi cac o quay ve y goc, mat
	cho dang xem. Goi ca sau `scrollTo`. ]]
function TableView:dat_lai_cho()
	local view_h = 0.0
	if self.container ~= nil and self.container.getContentSize ~= nil then
		local _, h = self.container:getContentSize()
		view_h = h or 0.0
	end
	local max_off = self.cao_tong - view_h
	if max_off < 0 then max_off = 0 end
	local ty = self.ty_le
	if ty < 0 then ty = 0 end
	if ty > 1 then ty = 1 end
	self.dich = ty * max_off
	for i, c in ipairs(self.cells) do
		local v = raw(c.view or c)
		if v ~= nil then
			v.position = Vector2(self.le_trai, (self.goc_y[i] or 0.0) - self.dich)
		end
	end
end

--[[ Cuon danh sach toi mot ty le.

	`percent` tinh theo QUANG CUON DUOC, khong phai ca be cao noi dung: 0 la
	meo tren, 1 la meo duoi. Do la loi cua chinh ban goc, ghi ro o
	CUISign.lua:905 ("由于tableView的scrollTo是根据 总容器高度-列表可视区域高度
	做偏移比") va khop voi so hoc cua CUIAssist.scrollToItem
	(CUIAssist.lua:1455: nRate = nIndex / (nTotal - nLayerLen/nItemLen)).

	Vi vay KHONG duoc lay `percent` lam so pixel: no la ti le, phai nhan voi
	quang cuon duoc — quang do tinh trong `dat_lai_cho`. Da tung viet sai cho
	nay va phep do bat duoc: `dich` ra 0.08 thay vi 1864.8.

	Tham so thu hai la CO CHAY HIEU UNG hay khong, khong phai "co cuon hay
	khong": CUIGuildTableView:ScrollTo (CUIGuildTableViewList.lua:439) truyen
	false, va CUISBHeroList.lua:119 goi chinh ham do de nhay toi mot muc — neu
	false la "dung cuon" thi ham mang ten ScrollTo da chang lam gi. Lop gia lap
	khong co he chay hieu ung nen dat thang: trang thai cuoi y het nhau.

	Nguoi goi co the truyen nil (CUIInfiniteLevelFirstPassRewards.lua:75: nguoi
	choi moi co BestProsees = 0 nen vong lap khong chay, `fSkipPercent` o lai
	nil). Ban goc truyen thang vao C++ nen nil thanh 0 — o day lam y vay.
]]
function TableView:scrollTo(percent, _)
	self.ty_le = tonumber(percent) or 0
	self:dat_lai_cho()
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
			-- Chieu cao noi dung, y goc tung o, ti le nguoi goi xin va do lech
			-- pixel suy ra tu no. Xem TableView:dat_lai_cho / :scrollTo.
			cao_tong = 0.0, goc_y = {}, ty_le = 0.0, dich = 0.0,
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
	if M.cuon ~= nil then M.cuon.tick() end
	return n + lich.cho()
end

return M
