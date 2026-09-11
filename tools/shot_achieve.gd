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
	-- Nap TOAN BO ma goc theo dung bon ban ke khai cua no (876 module). Danh
	-- sach ngan minh tung chon thi moi thu ngoai do la bong, ma bong goi ra
	-- MOT gia tri, nen 'local bRet, data = G_XLogic:GetY()' cho data = nil.
	local bao = boot.boot_goc()

	local out = Dictionary()
	-- Nap 104 bang cau hinh cua ban goc (~0,4 giay). Khong co no thi
	-- G_PrizeLogic:GetPrizeWithID tra ve nil, va o phan thuong van la anh
	-- thiet ke chu khong phai anh that.
	out['cau hinh'] = boot.init_config()
	out['nap module'] = bao.nap .. '/' .. bao.so
	for m, e in pairs(bao.hong) do out['NAP HONG ' .. m] = e end

	-- Ban goc luon dang o trong MOT CANH, va CLevelLoader ghi ten xgg da nap
	-- vao danh sach cua canh do; ten canh la nil thi registerPreloadXgg bo
	-- qua, khong ban tin OnLoadXGG, va onInit cua man hinh khong bao gio chay.
	-- Ta chua dung canh Main (thanh cong cu, ban do thi tran) nen dat la
	-- "Test" — mot canh co that cua ban goc. Do cung la ly do nhanh
	-- RefreshMainUIControlPanel khong chay: no doi ten canh == "Main".
	g_CSceneManager.CurrentScene = 'Test'

	-- Du lieu thanh tuu lay tu CHINH BANG CAU HINH cua ban goc
	-- (KDBGameAchieveConfig, 357 muc), khong phai so minh bia. Truoc day minh
	-- dat AchieveType = 101..106 va Award = {1..6}; ca hai deu sai kieu — loai
	-- that la so nho (0..21, va 101/102), con Award la danh sach ma phan thuong
	-- 3 chu so tro len ([401], [501], [601]). Bia sai thi
	-- CUIPrizeResHelper:getPrizeResInfo tra ve nil va ca dong hong.
	--
	-- Bo loai 0 va 1 (Reflesh bo qua), va 3/7/12/15 (nhung loai do con hoi
	-- g_CGameFuncOpeningManager xem tinh nang da mo chua).
	local BO_QUA = { [0] = true, [1] = true, [3] = true, [7] = true,
		[12] = true, [15] = true }
	local bando = {}
	local dem = 0
	-- Hoi tung muc mot bang dung ham tra cuu cua ban goc,
	-- GetAchieveConfig(loai, chi so). Bang tra ve co the long nhieu tang tuy
	-- ban, nen di thang bang ham chac hon la tu duyet.
	for loai = 2, 21 do
		if dem >= 6 then break end
		if not BO_QUA[loai] then
			-- Bang cau hinh duoc bam theo CHUOI:
			-- achieveConfig[tostring(loai)][tostring(chi so)]
			-- (share_configManager.lua:1034). Truyen so thi tra ve nil.
			local cfg = G_ConfigManager:GetAchieveConfig(tostring(loai), '1')
			if type(cfg) == 'table' and cfg.Award ~= nil then
				local aw = cfg.Award
				if type(aw) == 'string' then aw = cjson.decode(aw) end
				-- Chi nhan muc nao co phan thuong TRA CUU DUOC. Vai ma phan
				-- thuong trong bang tro toi loai vat pham can them du lieu
				-- may chu (vi du anh hung theo PrizeProperty), va ma goc thi
				-- tra nil roi hong o CUIRewardLayer:739. Day la chon du lieu
				-- kiem, khong phai che gia tri.
				local dung = false
				if type(aw) == 'table' and aw[1] ~= nil then
					-- pcall: vai ma phan thuong lam ham tra cuu nem loi chu
					-- khong chi tra nil.
					pcall(function()
						local b1, pc = G_PrizeLogic:GetPrizeWithID(aw[1])
						if b1 and type(pc) == 'table'
								and type(pc.PrizeContent) == 'table'
								and type(pc.PrizeContent[1]) == 'table' then
							-- Phai tra cuu duoc MOI muc trong PrizeContent,
							-- khong chi muc dau: CUIAchieve.lua:499 duyet het.
							dung = true
							for _, muc in ipairs(pc.PrizeContent) do
								local b2, ti = g_CUIPrizeResHelper:getPrizeResInfo(muc)
								if b2 ~= true or type(ti) ~= 'table' then
									dung = false
									break
								end
							end
						end
					end)
				end
				if dung then
					dem = dem + 1
					bando[tostring(dem)] = {
						AchieveType = loai, AchieveIndex = 1,
						State = (dem % 2 == 0) and AchieveState.Done
								or AchieveState.Doing,
						Current = 1, Total = 3, Award = { aw[1] },
					}
				end
			end
		end
	end
	out['so muc lay tu cau hinh'] = dem
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
