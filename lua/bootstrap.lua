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

make_ghost = function(path)
	local hit = cache[path]
	if hit ~= nil then return hit end
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
}

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
