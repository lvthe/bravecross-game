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
