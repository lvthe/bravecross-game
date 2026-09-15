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
	-- Nen snappy: engine goc co, engine cua ta KHONG. Ma goc kiem truoc MOI
	-- lan dung (sngRpcAnalytics.lua:212, :217 — hai cho dung duy nhat) va khi
	-- nil thi gui khong nen. De bong thi no 'co', ma goc dem bong di ma hoa va
	-- initGameConfig chet o sngRpcAnalytics.lua:232.
	-- (sngHttpRequestWithData thi KHAC: rpc.lua:305 goi thang khong kiem, tuc
	-- engine luon co — lam that trong install_cocos, khong ep nil.)
	sngUtil_snappyCompress = true,
}

-- Bien toan cuc ma ban goc KIEM nil (== nil, ~= nil, if X then) nhung trong
-- client da ship thi KHONG AI DAT: khong co dong gan nao trong 973 file Lua
-- (ke ca _G.X =, _G["X"] =, rawset), khong co trong chuoi cua libgame.so, va
-- khong co trong classes.dex — tuc C++ va Java cung khong dat duoc. Vay tren
-- may that chung la nil. De thanh bong thi chung thanh "dung" va ma goc di
-- nhanh khac han:
--   * ISSERVER — ma dung chung (share/) di nhanh MAY CHU; bong bi cham 357 lan.
--   * RECHARGESIGN_OPENMONTH — share/Setting.lua:52 con dong gan nhung BI CHU
--     THICH; bong lam ClientRechargeSignLogic.lua:80 so so voi nil, va chuoi
--     vao game (OnServerEnterGame) chet o do.
--
-- Danh sach DO LAI moi lan chay tools/import_lua.py (data_ref/bien_nil.json):
-- moi ten ma goc kiem nil ma khong co dong gan nao trong Lua, va khong co
-- trong chuoi cua libgame.so lan classes.dex. Lan do 12/09/2026: 144 ten —
-- gom ca G_DataCenterManager (doi tuong chi co o may chu; ma dung chung goi
-- sau 'if G_DataCenterManager then') va ten node .xgg nhu lMainBtnLayer (nil
-- toi khi nap bo cuc; nap xong khoa CO MAT nen van ra node that).
-- Ten CO trong libgame.so (74 ten, vd sngUtil_getIDFV) thi engine dang ky
-- that — khong ep nil duoc, phai lam that trong install_cocos.
local function nap_bien_nil()
	if _godot_doc_file == nil then return 0 end
	local s = _godot_doc_file('bien_nil.json')
	if s == nil then return 0 end
	local ok, t = pcall(function() return require('json').decode(s) end)
	if not ok or type(t) ~= 'table' or type(t.ten) ~= 'table' then return 0 end
	for _, ten in ipairs(t.ten) do never[ten] = true end
	return #t.ten
end
M.so_bien_nil = nap_bien_nil()

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
	-- Bo hen gio that (xem cocos.lua, muc "Hen gio"). Khong co no thi coroutine
	-- doi canh cua CSceneManager dung o lan yield dau tien.
	S_CCSchedule = c.lich
	-- San tran: node g_BattleField (BattleField_<canh>_960_640.xgg) dong vai
	-- engine tran C++ cua ban goc. Phai dang ky TRUOC khi nap canh Battle —
	-- loadLevelFile boc node ngay luc nap (_G[ten] = c.wrap(...)).
	c.lop_rieng['g_BattleField'] = require('san_tran')(c)
	-- Lop CUON cua engine (typeName 'CCScrollLayer'): lop thanh pho o Main va
	-- 314 node nua trong 296 file bo cuc. Cung phai dang ky TRUOC khi nap canh
	-- dau tien — wrap() chot __index ngay lan boc node dau.
	c.cuon = require('cuon')(c)
	c.lop_theo_loai['CCScrollLayer'] = c.cuon
	-- DFDramaScriptSystem: lop C++ chay kich ban tran (sc/plot/drama_*.lua).
	-- khoi_dong_game (d.235) goi DFDramaScriptSystem:new() -> g_DramaSystem.
	DFDramaScriptSystem = require('kich_ban')(c)
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

	-- Thu muc GHI duoc cua game (noi dat set.xgg). Lop offline luu tien trinh
	-- va nhat ky vao day. Tren may that la thu muc ngoai cua app; o day la
	-- user:// cua Godot, doi ra duong dan that vi Lua mo file bang io.open.
	function LGG_GetSetFilePath() return _godot_thu_muc_ghi or '' end

	-- Do dai ten de thu nho chu (CPublic.lua:697, :728 — ten nhan vat va ten
	-- tuong; o danh sach xep tuong goi no cho TUNG o). Ham co that trong
	-- libgame.so, ngay sau LGG_GetUtf8Len. Thieu thi ra bong (bang), dong
	-- 'nNameLen > nMaxNameSize' nem 'compare number with table' va man bo
	-- tri quan khong dung duoc o tuong nao.
	--
	-- DAT, KHONG DO: cach dem cua ban goc chua giai duoc (can dich nguoc ma
	-- may). O day dem KY TU UTF-8. Chi anh huong ti le thu nho cua ten dai
	-- hon 10 ky tu (tieng Viet), khong cham luat choi.
	function LGG_GetUtf8WordLen(s)
		if type(s) ~= 'string' then return 0 end
		local n = 0
		for i = 1, #s do
			local b = s:byte(i)
			if b < 0x80 or b >= 0xC0 then n = n + 1 end
		end
		return n
	end

	-- sc/game.lua:40-42 — file khoi dong ma ta KHONG chay (boot_goc nap ban ke
	-- khai thay no):
	--     if os.dateServer ~= nil then
	--         os.dateOrg = os.date; os.date = os.dateServer
	--     end
	-- os.dateServer la phan mo rong cua engine goc (ngay theo mui gio server).
	-- Tren may that no co, nen os.dateOrg luon co — local_notification.lua:64
	-- va :107 goi thang no. Lam lai phan CHAC CHAN cua ba dong do: dateOrg la
	-- os.date goc. os.date thi giu nguyen: khong biet mui gio server VN nen
	-- khong dung duoc dateServer ma khong bia.
	if os ~= nil and os.dateOrg == nil then
		os.dateOrg = os.date
	end

	-- io.open cua LuaJIT tren Windows goi fopen voi trang ma ANSI, nen khong mo
	-- duoc duong dan ngoai ASCII — ma thu muc user:// cua du an nay co dau gach
	-- dai ("BraveCross — game moi"): lop offline khong ghi duoc file luu nao. Mo
	-- that truoc; chi khi hong VA duong dan co byte ngoai ASCII moi di qua
	-- FileAccess cua Godot. Du cho nhung gi lop offline dung: doc '*a', ghi,
	-- flush, close.
	if io ~= nil and not M.da_boc_io then
		M.da_boc_io = true
		local mo_goc, xoa_goc = io.open, os.remove
		local function ngoai_ascii(p)
			return type(p) == 'string' and p:find('[\128-\255]') ~= nil
		end
		io.open = function(p, che_do)
			local f, e = mo_goc(p, che_do)
			if f ~= nil or not ngoai_ascii(p) then return f, e end
			che_do = che_do or 'r'
			if che_do:sub(1, 1) == 'r' then
				local s = _godot_doc_ngoai(p)
				if s == nil then return nil, e end
				return {
					read = function() return s end,
					close = function() return true end,
				}
			end
			-- 'w' xoa file o lan ghi dau; 'a' thi noi. Cac lan sau luon noi.
			local noi, da_ghi, dem = che_do:sub(1, 1) == 'a', false, {}
			local fp = {}
			function fp:write(...)
				for i = 1, select('#', ...) do dem[#dem + 1] = tostring((select(i, ...))) end
				return self
			end
			function fp:flush()
				if #dem > 0 or not da_ghi then
					_godot_ghi_ngoai(p, table.concat(dem), noi or da_ghi)
					dem, da_ghi = {}, true
				end
				return true
			end
			function fp:close() return self:flush() end
			return fp
		end
		os.remove = function(p)
			local ok, e = xoa_goc(p)
			if ok or not ngoai_ascii(p) then return ok, e end
			if _godot_xoa_ngoai(p) then return true end
			return nil, e
		end
	end

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

	-- LuaXML: engine goc rang buoc no thanh bien toan cuc 'xml'. Kho thiet lap
	-- set.xgg (g_SetGame, g_xmlSet) doc/ghi qua no — xem lua/luaxml.lua.
	xml = require('luaxml')

	-- Ham file cua engine goc, dung de dung set.xgg (system/engine.lua:238,
	-- user/Public/set.lua:86-96). Nguon tuong doi ('conf/set_org.xgg') la tai
	-- nguyen ban goc — import_lua.py chep vao data_ref/conf/.
	function is_file_exist(p) return xml.doc(p) ~= nil end
	function LGG_CopyFile(tu, den)
		local s = xml.doc(tu)
		if s == nil then return false end
		local f = io.open(den, 'w')
		if f == nil then return false end
		f:write(s)
		f:close()
		return true
	end
	-- engine.lua:238 goi copy_file_absolute_path(set_org, set.xgg, false) MOI
	-- lan khoi dong. Neu tham so thu ba la 'ghi de' thi thiet lap cua nguoi
	-- choi mat sau moi lan mo game — nen hieu false la KHONG ghi de khi da co.
	-- Day la SUY RA tu cach dung, khong doc duoc tu engine.
	function copy_file_absolute_path(tu, den, ghi_de)
		if not ghi_de and is_file_exist(den) then return true end
		return LGG_CopyFile(tu, den)
	end
	function LGG_IsXmlValid(p) return xml.load(p) ~= nil end

	-- sngUtil_getIDFV: ma dinh danh thiet bi. Ten nay CO trong libgame.so nen
	-- tren may that engine dang ky no — khong ep nil duoc (xem bien_nil).
	-- Device.lua:274 va :293 dem ket qua di string.find, nen bong (mot bang)
	-- lam chuoi ket noi chet o g_CUIGameRPCManager:OnConnected. Khong co thiet
	-- bi that thi khong co ma: tra chuoi rong, va Device.lua tu 'break' ra.
	function sngUtil_getIDFV() return '' end

	-- Armature theo ten (engine C++): nha cua canh Main, hieu ung, tuong trong
	-- giao dien. Lam bang SngRig tren du lieu armature cua ban goc — xem
	-- LuaRuntime._tao_rig.
	function getSpriteFromSpriteCatch(ten)
		return c.wrap(_godot_tao_rig(tostring(ten)))
	end
	getUIAnimFromSpriteCatch = getSpriteFromSpriteCatch

	-- sngHttpRequestWithData(url, du_lieu, kieu, obj_ok, ham_ok, obj_hong,
	-- ham_hong, so_lan_thu): engine goc LUON co — rpc.lua:305 goi thang khong
	-- kiem. Engine cua ta khong co mang ra ngoai: moi yeu cau deu hong, va bao
	-- ve ham 'hong' o KHUNG SAU, dung nhu mot may mat mang. Hai ham hong cua ma
	-- goc chi dem va ghi log, khong thu lai (rpc.lua:189,
	-- sngRpcAnalytics.lua:341). Ma loi -1 la ta DAT.
	function sngHttpRequestWithData(url, _, _, _, _, obj_hong, ham_hong)
		if type(obj_hong) == 'string' and type(ham_hong) == 'string' then
			local cho = {}
			function cho:goi()
				local o = rawget(_G, obj_hong)
				if type(o) == 'table' and type(o[ham_hong]) == 'function' then
					o[ham_hong](o, url, -1)
				end
			end
			c.lich:scheduleOnce(cho, 'goi')
		end
		return true
	end

	-- Nap nhieu file roi goi obj:ten_ham() — CLevelLoader.lua:132, la duong
	-- nap cua ca doi canh lan sngPreLoad. Phai goi lai o KHUNG SAU chu khong
	-- goi ngay: ham goi lai (CLevelLoader:sngLoadFinish) resume chinh coroutine
	-- dang goi toi day, ma coroutine dang chay thi khong resume duoc.
	function loadLevelFileAsync(ds, cha, obj, ten_ham)
		if type(ds) == 'string' then ds = { ds } end
		for _, duong in ipairs(ds or {}) do loadLevelFile(duong, cha) end
		if obj ~= nil and ten_ham ~= nil then c.lich:scheduleOnce(obj, ten_ham) end
	end

	-- Kho xgg cua engine. Doi canh goi popXgg cho tung file cua canh cu
	-- (CLevelLoader:UnloadFile). Ta chi QUEN file do de lan sau nap lai duoc —
	-- chua giai phong node, vi chua theo doi node nao den tu file nao.
	function sngXggMgrPool_pushXgg(_) end
	function sngXggMgrPool_popXgg(duong)
		if _godot_bo_xgg ~= nil then _godot_bo_xgg(duong) end
	end
	function sngXggMgrPool_popUnuseTexture() end

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
	-- CCLayer:new() 7 cho, CCLayerColorRoundRect:new(...) 6 cho — ca hai la
	-- lop C++ (libgame.so co 'lua_CCLayerColorRoundRect'), thieu thi ra bong.
	-- CUISubtitle:AddToParent (CUISubtitle.lua:52-54) tao mot cai lam khung
	-- phu de roi addChild vao canh Battle: bong di vao addChild la
	-- CUIGame:InitUI chet ngay dong 379, truoc ca initBattle.
	CCLayer = lop_node('lop')
	-- Doi so (r, g, b, a, rong, cao): thu tu cua CCLayerColor::create(ccColor4B,
	-- w, h) ben Cocos — suy tu ten lop, KHONG do. Ma goc goi (0, 255, 0, 0, w, h):
	-- xanh la voi do mo 0, tuc mot khung trong suot.
	local function lop_mau(_, r, g, b, a, w, h)
		local n = c.new_node('mau')
		local gd = c.raw(n)
		gd.color = Color((tonumber(r) or 0) / 255.0, (tonumber(g) or 0) / 255.0,
			(tonumber(b) or 0) / 255.0, (tonumber(a) or 0) / 255.0)
		if type(w) == 'number' and type(h) == 'number' then
			n:setContentSize(w, h)
		end
		return n
	end
	CCLayerColorRoundRect = { new = lop_mau, create = lop_mau }
	-- system/engine.lua:41 dat 'S_CCSprite = CCSprite:new()' — mot THE HIEN
	-- dung lam nha may, roi ma goc goi S_CCSprite:new() (61 cho). Voi lop gia
	-- lap, CCSprite:new() da ra mot node, nen S_CCSprite:new() roi vao stub va
	-- tra nil: dung cho do coroutine doi canh chet (CUILoad.lua:137,
	-- CUIArmyGroupCampsiteChatting.lua:439). Tro thang ve nha may.
	S_CCSprite = CCSprite
	S_CCOnlineImageSprite = CCSprite
	-- Tao sprite theo TEN KHUNG — ham cua engine ('spriteWithSpriteFrameName'
	-- o 0x7ad2c1 trong libgame.so), 6 file goi. CUISelectLevel.lua:1667 goi no
	-- trong OnShowAnimationFinish: thieu thi loi o do lam hang doi hoat canh
	-- hop thoai ket mai, va man thong tin ai khong bao gio mo.
	function CCSprite.spriteWithSpriteFrameName(_, ten)
		local n = c.new_node('sprite')
		n:initWithSpriteFrameName(ten)
		return n
	end

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


-- Ten toan cuc ma ma goc DA TUNG GAN, ke ca gan nil. Bong chi duoc thay cho
-- bien ma ma goc KHONG BAO GIO dat; bien da gan la bien that, vang thi phai
-- doc ra nil.
--
-- Can vi ma goc hay quen 'local'. AchieveCheckLogic.lua:1010-1012:
--     bRetCode,nCount = G_UserLogic:GetStatisticsCommonData(...)
--     if nCount == nil then nCount = 0 end
-- Nguoi choi moi thi ham tra nil, 'nCount = nil' khong tao muc nao trong _G,
-- va lan doc sau roi vao __index — ra BONG chu khong ra nil, phep kiem truot,
-- roi AchieveLogic.lua:1448 so bong voi so va ca chuoi vao game chet. Ban goc
-- khong co bong nen o day ra nil va di tiep binh thuong.
local da_gan = {}
M.da_gan = da_gan

function M.install()
	local mt = getmetatable(_G) or {}
	mt.__index = function(_, k)
		if never[k] or da_gan[k] then return nil end
		note(M.ghosts, tostring(k))
		return make_ghost(tostring(k))
	end
	-- Chi chay khi khoa CHUA co trong _G — dung luc can ghi nhan.
	mt.__newindex = function(t, k, v)
		da_gan[k] = true
		rawset(t, k, v)
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

-- Phan con lai cua sc/game.lua SAU G_ConfigManager:Init() (d.215) — cac loi goi
-- khoi dong thuan Lua, dung thu tu cua no. Ta khong chay game.lua (no mo mang,
-- tai tai nguyen, nap am thanh FMOD, dung canh Logo), nen phai lam lai tung
-- buoc. Thieu buoc nao thi thieu trang thai ma ban goc tin la luon co — vi du
-- XGEvent:Init (d.227) la noi DUY NHAT dat XGEvent.m_GameParams, va thieu no
-- thi CUILogin:OnServerEnterGame chet o xg_event.lua:375.
--
-- BO QUA, co y: am thanh (d.238, 340-347 — engine), bo tai (242-247 — mang),
-- sngPatch va kiem phien ban (252-314 — xoa file roi khoi dong lai game),
-- sngHttMgr (488 — HTTP), va canh Logo (498 tro di).
--
-- Tra ve (so buoc chay duoc, bang {nhan -> loi} cua buoc hong).
function M.khoi_dong_game()
	local buoc = {
		{ 'initGameConfig (d.220)', function() initGameConfig() end },
		{ 'XGAnalytics START (d.222)', function()
			XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.START) end },
		{ 'UMEvent:Init (d.225)', function() UMEvent:Init() end },
		{ 'XGEvent:Init (d.227)', function() XGEvent:Init() end },
		{ 'plot.string_gb + g_DramaSystem (d.233-235)', function()
			require('plot.string_gb')
			g_DramaSystem = DFDramaScriptSystem:new()
		end },
		{ '__twoYearCheckInit (d.318)', function()
			if g_CUIMainTheme and g_CUIMainTheme.__twoYearCheckInit ~= nil then
				g_CUIMainTheme:__twoYearCheckInit()
			end
		end },
		{ 'math.randomseed (d.337)', function() math.randomseed(os.time()) end },
		{ 'g_CUIOptions:InitGameInfo (d.352)', function() g_CUIOptions:InitGameInfo() end },
		{ 'RECONNECT_COUNT (d.355)', function() USER_GLOBAL.RECONNECT_COUNT = 3 end },
		-- Co thu nghiem cua ban goc: chi bat khi set.xgg ghi DebugTestMode.
		-- Thieu buoc nay thi G_DEBUG_TEST_MODE chua ai gan nen ra BONG (dung),
		-- va CUIGame.lua:1276 hen GameFinishTimer -> GameFinish(true) sau 2
		-- giay: tran nao cung THANG, du san tran bao gi.
		{ 'G_DEBUG_TEST_MODE (d.363-366)', function()
			G_DEBUG_TEST_MODE = g_SetGame:GetString('DebugTestMode') == 'true'
			if G_DEBUG_TEST_MODE then
				g_CGameFuncOpeningManager.IsTest = true
			end
		end },
		{ 'g_CUILoad:InitUI (d.452)', function() g_CUILoad:InitUI() end },
		{ 'CloseGuide / OpenAllGameFun (d.457-467)', function()
			g_CUIMain.bIgnoreGuide = g_SetGame:GetString('CloseGuide') == 'true'
			if g_SetGame:GetString('OpenAllGameFun') == 'true' then
				g_CGameFuncOpeningManager.IsTest = true
			end
		end },
		{ 'co khoi dong (d.472-481)', function()
			g_bShowServerKickedMsg = false
			g_bSngSceneLoadAsync = false
			g_CUIGame.bTestButton = false
			g_CUIGame.bRepeatPlot = false
		end },
		{ 'XGAnalytics LOADCONFIG (d.485)', function()
			XGAnalytics:logEventByID(XGAnalytics.EVENT_ID.LOADCONFIG) end },
	}
	local n, hong = 0, {}
	for _, b in ipairs(buoc) do
		M.cham = 0
		local ok, err = pcall(b[2])
		if ok then n = n + 1 else hong[b[1]] = tostring(err) end
	end
	return n, hong, #buoc
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
