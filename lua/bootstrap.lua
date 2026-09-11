-- Khoi dong khung suon Lua cua ban goc, du de chay mot man hinh.
--
-- Ban goc khoi dong bang sc/game.lua, nhung file do keo theo ca mang, dang
-- nhap, tai tai nguyen, quang cao... Doan nay chi dung phan toi thieu:
--
--   1. class.lua — he lop thuan Lua, khong dinh engine, nap thang duoc.
--   2. Mot cai BONG cho moi bien toan cuc chua co.
--
-- Ve cai bong: ma goc goi toi hang tram doi tuong toan cuc (g_CPublic,
-- g_CUISubDialog, G_CUIEventStatistics...) do phan C++ hoac phan khoi dong
-- tao ra. Neu de nguyen thi chay toi dong dau la chet, va ta chi biet duoc
-- MOT cai thieu moi lan. Cai bong nhan moi loi goi va GHI LAI, nen chay mot
-- lan la ra het danh sach can lam that.
--
-- Cai bong LAM SAI HANH VI, khong phai giai phap. No tra ve mot bong khac
-- thay vi nil, nen nhung cho viet 'if x == nil then' se di nhanh khac. Dung
-- no de DO xem can gi, roi thay dan bang do that.

local M = {}

M.ghosts = {}     -- "ten.duong.dan" -> so lan cham toi
M.calls = {}      -- "ten.duong.dan" -> so lan goi

local make_ghost

local function note(tbl, key)
	tbl[key] = (tbl[key] or 0) + 1
end

-- Moi duong dan chi MOT bong, dung lai mai. Truoc day moi lan cham lai nan
-- mot bong moi: share/EventManager.lua cham EventManagerBase 110.753 lan va
-- Lua bao 'not enough memory'. Dung chung con lam '==' cu the ra on dinh.
local cache = {}
local so_bong = 0

-- Bong CUT: khong nan them bong con, khong ghi them gi. Dung khi da nan qua
-- nhieu hoac duong dan qua sau.
--
-- Can cai nay vi ma goc co nhung cho cham vao bien toan cuc trong VONG LAP.
-- Moi lan cham lai nan mot bong moi, va moi bong lai nan duoc bong con — Lua
-- bao 'not enough memory' roi ca file khong nap duoc. Da dinh hai lan:
-- share/EventManager.lua (110.753 luot) va user/Public/set.lua.
local CUT_SO = 4000
local CUT_SAU = 6
local CHAM_TOI_DA = 200000
M.cham = 0

-- Cham qua nguong thi NEM LOI chu khong tra ve bong nua. Ly do: co module
-- viet kieu 'while x ~= nil do x = x.next end'; bong luon khac nil nen vong
-- do chay mai — treo han, con te hon het bo nho vi it ra het bo nho thi con
-- bao loi. Nem loi thi pcall ben ngoai bat duoc, module do bao hong, va cac
-- module khac van nap tiep.
local function dem_cham_toi_da()
	M.cham = M.cham + 1
	if M.cham > CHAM_TOI_DA then
		error('bong: cham hon ' .. CHAM_TOI_DA .. ' lan, chac la vong lap vo tan')
	end
end

local bong_cut = {}
setmetatable(bong_cut, {
	__bong = true,
	__index = function() dem_cham_toi_da(); return bong_cut end,
	__newindex = function() end,
	__call = function() dem_cham_toi_da(); return bong_cut end,
	__tostring = function() return '<bong cut>' end,
	__concat = function(a, b) return tostring(a) .. tostring(b) end,
	__len = function() return 0 end,
})
M.bong_cut = bong_cut

local function dem_cham(path)
	local n = 0
	for _ in path:gmatch('%.') do n = n + 1 end
	return n
end

make_ghost = function(path)
	local hit = cache[path]
	if hit ~= nil then return hit end
	if so_bong >= CUT_SO or dem_cham(path) >= CUT_SAU then
		return bong_cut
	end
	so_bong = so_bong + 1
	local g = {}
	setmetatable(g, {
		-- Dau nhan de nhan ra bong. Xem M.la_bong.
		__bong = true,
		__index = function(_, k)
			local sub = path .. '.' .. tostring(k)
			note(M.ghosts, sub)
			return make_ghost(sub)
		end,
		__newindex = function(t, k, v) rawset(t, k, v) end,
		-- Goi bong PHAI ra mot bong khac, khong duoc ra nil. Ma goc day ray
		-- 'if X ~= nil then X():Y()' — bong khong phai nil nen no vao nhanh do,
		-- roi neu X() ra nil thi chet ngay o :Y(). Da dinh dung hai lan:
		-- KDebug.lua:91 va CUIManager.lua:1513.
		__call = function(_, ...)
			note(M.calls, path)
			return make_ghost(path .. '()')
		end,
		__tostring = function() return '<bong ' .. path .. '>' end,
		__concat = function(a, b) return tostring(a) .. tostring(b) end,
		__len = function() return 0 end,
	})
	cache[path] = g
	return g
end

-- Co phai bong khong. Can de phan biet "chua lam" voi "khong he co".
function M.la_bong(v)
	if type(v) ~= 'table' then return false end
	local mt = getmetatable(v)
	return mt ~= nil and rawget(mt, '__bong') == true
end


-- class(super) cua ban goc di nguoc chuoi cha bang
-- 'while typeSuper ~= nil do ... typeSuper = typeSuper.super end'.
-- Bong thi khong bao gio bang nil, nen vong do chay mai.
--
-- Quan trong: trong game THAT, ba lop duoi day co lop cha KHONG TON TAI trong
-- ma da ship — GameUerLogic va EpicBattleLogic khong duoc dinh nghia o bat cu
-- dau trong 973 file, con Login thi nap sau. Tuc la ban goc chay
-- class(nil) va di qua binh thuong; chi co BONG cua ta moi bien cai nil do
-- thanh mot thu khac nil. Nen day khong phai doi hanh vi ban goc, ma la tra
-- lai dung hanh vi cua no.
--
--     ClientUserLogic       = class(GameUerLogic)     ClientLogic.lua:1
--     ClientEpicBattleLogic = class(EpicBattleLogic)  ClientEpicBattleLogic.lua:1
--     ClientLogin           = class(Login)            ClientLogin.lua:2
local da_boc_class = false

function M.bao_ve_class()
	if da_boc_class or type(rawget(_G, 'class')) ~= 'function' then return end
	da_boc_class = true
	local goc = _G.class
	_G.class = function(super)
		if M.la_bong(super) then
			note(M.ghosts, 'class(<bong>)')
			super = nil
		end
		return goc(super)
	end
end


-- Nhung ten KHONG duoc lam bong: de bong len la hong that su.
-- _G va cac ham chuan cua Lua deu da co san, nen chi can chan vai cai bay.
local never = {
	-- ma goc kiem 'if os.dateServer ~= nil' — phai ra nil that
	dateServer = true,
}

-- Dat cac doi tuong toan cuc cua engine ma lop gia lap CO lam that.
-- Phai goi TRUOC install(), khong thi chung bi lam bong va ma goc se goi vao
-- bong roi khong ra gi.
function M.install_cocos()
	local c = require('cocos')
	S_CCSpriteFrameCache = c.spriteFrameCache
	g_CLuaFont = c.luaFont
	g_CNFont = c.luaFont
	G_CTableViewMgr = c.tableViewMgr
	S_CCDirector = c.director
	-- system/engine.lua:159 dat lai hai bien nay tu S_CCDirector cua C++;
	-- sau khi nap ban goc thi chung la bong, phai tra ve so that.
	screenWidth, screenHeight = c.director.getWinSize()
	-- Dat cac thuc the S_CCSequence, S_CCMoveTo... Ban goc goi he action
	-- qua chung: S_CCSequence 659 lan, S_CCCallFunc 559, S_CCDelayTime 486.
	c.actions.install()

	-- Hai ham nay ban goc dinh nghia trong user/Public/set.lua, y nguyen ba
	-- dong duoi day. KHONG nap ca file do: no co vong lap chay mai khi gap
	-- bong, treo han ca lan chay. Chep ba dong thi vua du vua chac.
	function GetStringWithKey(k) return g_CLuaFont:GetStringByKey(k) end
	function GetCNStringWithKey(k) return g_CNFont:GetStringByKey(k) end

	-- Tang cau hinh. Ban goc doc 104 bang cau hinh qua DUNG BA ham nay:
	--   ClientConfigManager:GetConfigTableWithName(ten)
	--     -> JsonFile.Load(LGG_GetPathWithFileName("config/share/<ten>.xgg"))
	-- Lam ba cai nay la ca 5.063 dong ConfigManager cua ban goc tu chay.
	local json = require('json')
	DEFAULT_LANGUAGE = DEFAULT_LANGUAGE or 'vi'

	function LGG_GetPathWithFileName(rel) return rel end

	function LGG_IsFileExist(p) return _godot_co_file(p) end

	-- cjson: ban goc goi 436 lan. Quan trong nhat la JSON LONG TRONG JSON —
	-- vi du PrizeContent cua bang phan thuong la mot chuoi JSON nam trong
	-- mot file JSON, va share_configManager goi cjson.decode de mo lop thu
	-- hai. De cjson thanh bong thi PrizeContent van la bong, va moi cho doc
	-- phan thuong deu hong.
	cjson = {
		decode = function(s)
			local t = json.decode(s)
			return t
		end,
		encode = function(v) return json.encode(v) end,
	}

	-- loadLevelFile: bo nap .xgg cua engine. Ban goc goi qua CLevelLoader:
	--     loader:LoadFiles(tenCanh, self.ResourceXggList, uiRootLayer)
	-- tuc moi man hinh tu khai bao file bo cuc cua no roi tu nap vao
	-- UIRootLayer. Sau khi nap, TEN INSTANCE trong file thanh bien toan cuc —
	-- ma goc viet thang `lAchieveTaskUI`, khong qua bien trung gian nao.
	function loadLevelFile(duong, cha)
		local ds = _godot_load_xgg(duong, cha and c.raw(cha) or nil)
		if ds == nil then return end
		-- Mang cua Godot sang Lua la userdata: ipairs khong chay, phai hoi
		-- size()/get(). Mang xen ke [ten, node, ten, node...].
		local n = ds:size()
		local i = 0
		while i + 1 < n do
			local ten = tostring(ds:get(i))
			_G[ten] = c.wrap(ds:get(i + 1))
			i = i + 2
		end
		-- Ban tin "da nap xong xgg nay". Day la SUY RA, khong doc duoc tu ma
		-- goc, nhung ma goc chi coherent neu engine lam the:
		--
		--   * CUIPublic:ctor dang ky onLoadUIXggFinish cho su kien OnLoadXGG,
		--     va chinh ham do moi goi onInit() cua man hinh.
		--   * Phia Lua, cho duy nhat ban tin do la
		--     CSceneManager:registerPreloadXgg, ma no CHI ban lan dau moi file
		--     — "if lcPreloadXggArr[value] == nil then".
		--   * 193 man khai bao bo cuc, nhung chi 125 file .xgg khac nhau: 68
		--     man dung chung file voi mot man khac. Neu chi co registerPreloadXgg
		--     ban tin thi 68 man do khong bao gio chay onInit — ma trong game
		--     that chung chay binh thuong.
		--   * Trong CLevelLoader.lua, dong PostUIEvent(...OnLoadXGG) con nam do
		--     nhung da bi chu thich lai, tuc viec ban tin da chuyen di cho khac.
		--
		-- onLoadUIXggFinish tu chan bang "if not self.isInit", nen ban lai
		-- nhieu lan khong hai gi.
		local EM = rawget(_G, 'G_EventManager')
		local UE = rawget(_G, 'EventManagerUIEvent')
		if EM ~= nil and type(UE) == 'table' and UE.OnLoadXGG ~= nil then
			pcall(function() EM:PostUIEvent(duong, UE.OnLoadXGG) end)
		end
	end

	-- Cac lop node cua engine, dung de TAO node luc chay. Ban goc goi
	-- Label:new() 14 lan, CCScale9Sprite:new() 9, CCSprite:new() 7,
	-- CCLabelTTF:new() 3 — va system/engine.lua thi khong dinh nghia chung
	-- (chung la lop C++), nen khong cai thi tat ca deu la bong.
	local function lop_node(kieu)
		return { new = function() return c.new_node(kieu) end,
		         create = function() return c.new_node(kieu) end }
	end
	Label = lop_node('label')
	CCLabelTTF = lop_node('label')
	CCSprite = lop_node('sprite')
	CCScale9Sprite = lop_node('scale9')
	CCNode = lop_node('node')

	-- ProtoRPC: doi tuong RPC ben C++ (system/rpc.lua:337 ProtoRPC:new()).
	--
	-- May chu cu da chet, nen day la mot cai ONG KHONG NOI DI DAU: nhan loi
	-- goi, phat mot so thu tu, khong gui gi ca. Phai co that chu khong duoc de
	-- la bong, vi rpc.lua nem so thu tu do thang vao
	-- sngRpcAnalytics:convertTo32UintString, va ham do so no voi 0x100000000 —
	-- bong thi Lua bao 'attempt to compare table with number', va man hinh nao
	-- hoi may chu luc mo deu chet o do (28/353 man).
	--
	-- Day la tang van chuyen, khong phai du lieu game: man hinh van mo ra
	-- rong, dung voi su that la khong co may chu tra loi.
	local rpc_stt = 0
	local function ban_tin()
		local t = {}
		local mt = {
			__index = function(_, k)
				if k:sub(1, 3) == 'Set' then return function() end end
				if k:sub(1, 3) == 'Get' then
					-- GetInt32/GetInt64/GetUInt64 ra so, GetString ra chuoi.
					if k:find('String') then return function() return '' end end
					return function() return 0 end
				end
				return function() end
			end,
		}
		return setmetatable(t, mt)
	end

	ProtoRPC = {
		new = function()
			return {
				CallMethod = function()
					rpc_stt = rpc_stt + 1
					return rpc_stt
				end,
				NewRequest = function() return ban_tin() end,
				NewMessage = function() return ban_tin() end,
				DeleteMessage = function() end,
				ImportProtoFile = function() return true end,
				SetID = function() end,
				GetID = function() return 'GameRPC' end,
				SetProtoFileRootDir = function() end,
				SetRpcID = function() end,
				SetRpcSessionID = function() end,
				StartRPC = function() return false end,
				CheckConnection = function() return false end,
				CleanStackMsg = function() end,
				Close = function() end,
				release = function() end,
			}
		end,
	}

	JsonFile = {
		Load = function(p)
			local txt = _godot_doc_file(p)
			if txt == nil then return false, nil end
			local t, err = json.decode(txt)
			if t == nil then return false, err end
			return true, t
		end,
	}
	return c
end


-- Bon ban KE KHAI cua ban goc, dung thu tu trong sc/game.lua:174-183. Day la
-- danh sach that su cua no chu khong phai danh sach minh chon: 876 module.
M.KE_KHAI = {
	'share.share_public_require',
	'share.share_gameLogic_require',
	'system.s_require',
	'user.require',
}

-- Nap TOAN BO ma goc, theo dung ban ke khai cua no.
--
-- Khac M.boot(): boot() nap mot danh sach ngan do minh chon, nen moi thu
-- khong nam trong do la BONG — va bong thi lam sai hanh vi. Vi du
-- 'local bRet, data = G_ArenaLogic:GetUserArenaData()' : bong goi ra mot gia
-- tri, nen data = nil, va man hinh hong o dong sau voi thong bao nhu la
-- thieu du lieu may chu. Nap that thi G_ArenaLogic la that.
--
-- Cuoi cung PHAI cai lai lop gia lap: system/engine.lua la be mat rang buoc
-- C++ (70 bien S_CC*), nap no vao la de bong len het cac thu ta lam that.
function M.boot_goc()
	local ds = {}
	for _, ten in ipairs(M.KE_KHAI) do
		local duong = ten:gsub('%.', '/')
		local src = _godot_read(duong)
		local nhom = {}
		if src ~= nil then
			for m in src:gmatch('require%s*%(%s*"([%w_%.]+)"%s*%)') do
				nhom[#nhom + 1] = m
			end
		end
		ds[#ds + 1] = nhom
	end
	local bao = { so = 0, nap = 0, hong = {} }
	for _, nhom in ipairs(ds) do
		bao.so = bao.so + #nhom
		for _, m in ipairs(nhom) do
			-- Dat lai bo dem TRUOC TUNG module: bo dem la chung, nen module
			-- dau tien lam trong vong lap vo tan se lam moi module sau do
			-- cung bao loi do, va ta doc nham thanh "ba module hong".
			M.cham = 0
			local ok, err = pcall(function() require(m) end)
			if ok then
				bao.nap = bao.nap + 1
			else
				bao.hong[m] = tostring(err)
			end
		end
		-- Cai lai sau TUNG ban ke khai, khong doi den cuoi: system/engine.lua
		-- nam trong ban thu ba, va cac module cua ban thu tu doc thang
		-- screenWidth ngay luc nap (vi du user/UI/pet/CUIPetCommon.lua:41).
		M.install_cocos()
		M.bao_ve_class()
	end
	return bao
end


function M.install()
	local mt = getmetatable(_G) or {}
	mt.__index = function(_, k)
		if never[k] then return nil end
		note(M.ghosts, tostring(k))
		return make_ghost(tostring(k))
	end
	setmetatable(_G, mt)
end

function M.uninstall()
	local mt = getmetatable(_G)
	if mt then mt.__index = nil end
end

-- Nap mot file ma goc theo ten module. Cac file do khong 'return' gi ca, chung
-- dat bien toan cuc (CUIAchieve = class(CUIPublic)), nen chi can chay la xong.
function M.load(name)
	return require(name)
end

-- Khung suon toi thieu de mo mot man hinh, theo dung thu tu phu thuoc.
--
-- Day deu la file THAT cua ban goc, khong phai do minh viet. Truoc khi co
-- danh sach nay thi chung bi lam bong, va bong tra ve nil nen
-- 'CUIGuildTableView:new()' ra nil roi chet o dong sau.
-- Thu tu o day khong tuy y — no la thu tu KE THUA cua ban goc:
--   EventManager    = class(EventManagerBase)
--   CDlgHeroDropOut = class(CUIPublic)      <- nam trong CUISubDialog.lua
-- Nap sai thu tu thi lop cha thanh bong, va bong khong the lam lop cha.
M.FRAMEWORK = {
	'share.class',                       -- he lop, thuan Lua
	-- Mo rong cho string (string.split...). PHAI co: addon Lua mo ca API
	-- cua Godot, nen 'string.split' khong co thi no roi vao ham split cua
	-- Godot String va tra ve userdata — KDebug goi ipairs len do roi hong,
	-- ma cho hong lai nam trong duong in loi nen rat kho lan.
	'share.public',
	'share.KDebug',                      -- CUIPublic goi khi thieu RootUIName
	'share.EventManagerBase',
	'share.EventManager',                -- G_EventManager + bang loai su kien
	'user.Public.CPublic',               -- g_CPublic
	'user.Public.sngTableViewEventHandle',
	'user.Public.CUIPublic',             -- lop cha cua moi man hinh
	'user.Public.CUISubDialog',
	'user.Public.CUIManager',            -- g_CUISubDialog
	'user.Logical.CUIEventStatistics',   -- G_CUIEventStatistics
	'user.UI.CUIGuildTableViewList',     -- CUIGuildTableView
	-- Tang cau hinh: 104 bang so cua ban goc. G_ConfigManager chi TON TAI
	-- sau khi nap ba file nay; con nap DU LIEU thi goi init_config().
	'share.StarSoul.share_StarSoulLogic',   -- ConfigManager doc hang so o day
	'share.share_configManager',
	'user.Logical.ClientConfigManager',
}

-- Nap du lieu cua 104 bang cau hinh. Tach rieng vi ton ~0,35 giay va
-- khong phai man nao cung can. Chinh ConfigManager cua ban goc lam,
-- minh chi bac cau doc file (xem install_cocos).
function M.init_config()
	local ok, err = pcall(function() G_ConfigManager:Init() end)
	return ok and 'ok' or tostring(err)
end

-- Nap khung suon. Tra ve bang {ten module -> 'ok' hoac loi}, khong nem ra
-- ngoai: mot module hong khong duoc lam chet ca lan chay, vi con phai bao cao.
function M.boot(extra)
	local out = {}
	local list = {}
	for _, m in ipairs(M.FRAMEWORK) do list[#list + 1] = m end
	for _, m in ipairs(extra or {}) do list[#list + 1] = m end
	for _, m in ipairs(list) do
		local good, err = pcall(require, m)
		out[m] = good and 'ok' or tostring(err)
	end
	return out
end

-- Bao cao: ten nao bi cham toi ma minh chua lam. Gom theo goc de de doc —
-- 'g_CPublic.SaveUIOriginalState' va 'g_CPublic.GetUIOriginalState' la cung
-- mot thu can lam.
function M.report()
	local roots = {}
	for k, n in pairs(M.ghosts) do
		local root = k:match('^[^.]+')
		roots[root] = (roots[root] or 0) + n
	end
	return roots
end

return M
