## Chay TRON man thanh tuu cua ban goc, roi chup.
##
##   godot --path . tools/shot_achieve.tscn -- --shot=C:/tmp/x.png --at=2
##
## Khac voi shot_lua_screen.gd (chi dung bo cuc roi chay onInit), canh nay
## chay ca vong doi: onInit -> do du lieu -> Reflesh. Tuc la ma goc tu dien
## chu, tu nhan ban tung dong, tu bat/tat trang thai.
##
## Du lieu thanh tuu lay tu BANG CUA MINH chu khong tu may chu cu — may chu cu
## chet roi. Nhung phan HIEN THI thi van la ma goc: CUIAchieve:RefleshItem
## chay nguyen van, tro toi node bang getChildByTag, doc chu bang
## GetStringWithKey.
extends Control


var _lua: LuaRuntime = null


## Day thoi gian cho he action cua ban goc. Khong co cai nay thi moi hieu ung
## deu dung im o khung dau.
func _process(dt: float) -> void:
	if _lua != null:
		_lua.tick(dt)


func _ready() -> void:
	var thieu := _kiem_du_lieu()
	if thieu != "":
		_note(thieu)
		return

	# TON TRONG co hien/an cua file. Truoc day phai hien het de con nhin thay
	# gi, vi ban goc an san gan nhu moi thu roi moi bat len luc chay. Nay
	# duong Show cua chinh no lam viec do: onShow -> SetVisible(true) bat goc
	# man hinh, SetMaskIsEnable bat lop che, SetBackButtonIsVisible bat nut
	# Back. De hien het thi lFeedsDlgMask va lDebugBoxMask — hai lop den
	# 125/255 — phu kin man hinh.
	XggLayout.respect_visible = true

	# Chi dung KHUNG CHUNG. Bo cuc cua chinh man thanh tuu KHONG dung o day
	# nua: ban goc tu khai bao no trong ResourceXggList roi tu nap vao
	# UIRootLayer qua loadLevelFile. Xem lua/bootstrap.lua.
	var nen := XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
	if nen == null:
		_note("khong dung duoc khung hop thoai")
		return
	add_child(nen)

	var lua := LuaRuntime.new()
	_lua = lua
	if not lua.open():
		_note("khong mo duoc Lua: %s" % ", ".join(lua.errors))
		return
	lua.bind_layout(nen)
	var goc := XggLayout.find_node(nen, "UIRootLayer")
	goc.position = Vector2.ZERO
	lua.set_ui_root(goc)

	var r = lua.run(_KICH_BAN, "man thanh tuu")
	if r == null:
		_note("Lua hong: %s" % ", ".join(lua.errors))
		return
	print("[lua] ket qua: ", r)
	for k in r:
		print("   %s = %s" % [k, r[k]])

	var miss := lua.missing()
	print("\nAPI Cocos bi goi ma chua lam (%d loai):" % miss.size())
	var ds := []
	for k in miss:
		ds.append([int(miss[k]), String(k)])
	ds.sort_custom(func(a, b): return a[0] > b[0])
	for e in ds:
		print("   %-30s x%d" % [e[1], e[0]])


func _kiem_du_lieu() -> String:
	if not FileAccess.file_exists("res://sc/share/class.lua"):
		return "thieu ma goc — chay: python tools/import_lua.py"
	if not FileAccess.file_exists("res://data_ref/text_vi.json"):
		return "thieu bang chu — chay: python ../brave-cross/work/text_table.py"
	return ""


func _note(msg: String) -> void:
	var lb := Label.new()
	lb.text = msg
	lb.position = Vector2(14, 14)
	add_child(lb)
	push_warning(msg)


## Dat rieng ra cho de doc. Day la doan DUY NHAT minh viet; phan con lai deu
## la ma goc chay nguyen van.
const _KICH_BAN := """
	local boot = require('bootstrap')
	local cocos = boot.install_cocos()
	boot.install()
	local nap = boot.boot({
		-- AchieveState nam trong day. Thieu no thi Reflesh loc sach danh
		-- sach: no so State voi AchieveState.Doing, ma bong thi khong bang
		-- gi ca, nen moi thanh tuu deu bi bo.
		'share.Protocol',
		-- Ba cai nay lo anh phan thuong: PrizeLogic tra cau hinh phan thuong,
		-- CUIRewardLayer gan anh vao o, CUIHelper dat mau chu.
		'share.PrizeLogic',
		'user.Public.CUIPrizeResHelper',
		'user.UI.CUIRewardLayer',
		'user.Public.CUIHelper',
		'share.AchieveLogic',
		'user.Logical.ClientAchieveLogic',
		'user.UI.CUIGuildTableViewList',
		-- Ba cai nay la DUONG SHOW cua ban goc:
		--   CSceneManager      giu ten canh dang choi, va dang ky xgg da nap
		--   CLevelLoader       goi loadLevelFile de nap bo cuc cua man hinh
		--   CUIDialogAnimation chay hoat canh mo roi goi nguoc ve
		--                      OnShowAnimationFinish -> setDialogVisible
		'user.Public.CSceneManager',
		'user.Public.CLevelLoader',
		'user.Public.CUIDialogAnimation',
		'user.UI.CUIAchieve',
	})

	local out = Dictionary()
	-- Nap 104 bang cau hinh cua ban goc (~0,4 giay). Khong co no thi
	-- G_PrizeLogic:GetPrizeWithID tra ve nil, va o phan thuong van la anh
	-- thiet ke chu khong phai anh that.
	out['cau hinh'] = boot.init_config()
	for ten, kq in pairs(nap) do
		if kq ~= 'ok' then out['NAP ' .. ten] = kq end
	end

	-- Ban goc luon dang o trong MOT CANH, va CLevelLoader ghi ten xgg da nap
	-- vao danh sach cua canh do; ten canh la nil thi registerPreloadXgg bo
	-- qua, khong ban tin OnLoadXGG, va onInit cua man hinh khong bao gio chay.
	-- Ta chua dung canh Main (thanh cong cu, ban do thi tran) nen dat la
	-- "Test" — mot canh co that cua ban goc. Do cung la ly do nhanh
	-- RefreshMainUIControlPanel khong chay: no doi ten canh == "Main".
	g_CSceneManager.CurrentScene = 'Test'

	-- Do du lieu vao DUNG CHO ma goc doc. AchieveLogic:GetUserAchieveMap()
	-- tra ve self.UserAchieveMap sau khi Init(); ta dat san roi danh dau da
	-- init, nen ham goc chay nguyen van ma khong can may chu cu.
	local AchieveState = rawget(_G, 'AchieveState') or {}
	local DANG_LAM = AchieveState.Doing or 1
	local XONG     = AchieveState.Done  or 2

	local mau = {
		{ t = 101, i = 1, s = DANG_LAM, cur = 1, tot = 3, aw = 1 },
		{ t = 102, i = 1, s = XONG,     cur = 3, tot = 3, aw = 2 },
		{ t = 103, i = 1, s = DANG_LAM, cur = 4, tot = 10, aw = 3 },
		{ t = 104, i = 1, s = DANG_LAM, cur = 2, tot = 5, aw = 4 },
		{ t = 105, i = 1, s = XONG,     cur = 1, tot = 1, aw = 5 },
		{ t = 106, i = 1, s = DANG_LAM, cur = 0, tot = 1, aw = 6 },
	}
	local bando = {}
	for k, v in ipairs(mau) do
		bando[tostring(k)] = {
			AchieveType = v.t, AchieveIndex = v.i, State = v.s,
			Current = v.cur, Total = v.tot, Award = { v.aw },
		}
	end

	local L = rawget(_G, 'G_AchieveLogic')
	if L ~= nil then
		L.UserAchieveMap = bando
		L.bIsInited = true
	end

	-- DUONG SHOW CUA BAN GOC, mot dong. Tu day tro di khong co dong nao cua
	-- minh nua:
	--
	--   CUISubDialog:Show -> CUIManager:Show
	--     -> SetMaskIsEnable        bat lop che (lSubDialogMask, mo dan toi 179)
	--     -> objUI:OnShow           CLevelLoader:LoadFiles -> loadLevelFile
	--                               nap UI_AchievementTask_960_640 vao UIRootLayer
	--     -> onLoadUIXggFinish      (qua su kien OnLoadXGG) -> onInit
	--     -> OnloadUI -> OnShow -> RunOpenAnimation
	--          OnShowAnimationBegin  -> onShow -> SetVisible(true)
	--          <cho het hoat canh>
	--          OnShowAnimationFinish -> setDialogVisible -> onVisible -> Reflesh
	--     -> SetOpenZorder          dat goc man hinh len z = 150
	--
	-- Man thanh tuu la HOP THOAI CON: chinh no dang ky voi g_CUISubDialog
	-- (CUIAchieve.lua:9), khong phai g_CUINormalDlg. Khac han: hop thoai con
	-- khong do anh nen toan man, no chi lam toi man phia sau bang lop che.
	local ok, err = pcall(function() g_CUISubDialog:Show('AchieveUI') end)
	out['Show'] = ok and 'ok' or tostring(err)

	local ui = g_CUISubDialog.UI['AchieveUI']
	out['co man hinh'] = tostring(ui ~= nil)
	if ui == nil then return out end
	out['nap bo cuc'] = tostring(rawget(_G, 'lAchieveTaskUI') ~= nil)
	for i, d in ipairs(cocos.tag_miss_log) do out['HUT ' .. i] = d end
	out['tag_hoi'] = cocos.tag_lookups
	out['tag_hut'] = cocos.tag_misses
	return out
"""
