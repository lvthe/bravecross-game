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


func _ready() -> void:
	var thieu := _kiem_du_lieu()
	if thieu != "":
		_note(thieu)
		return

	XggLayout.respect_visible = false
	var root := XggLayout.build("res://layout_ref/UI_AchievementTask_960_640.json")
	if root == null:
		_note("khong dung duoc bo cuc")
		return
	add_child(root)

	# Kiem ngay sau khi dung: XggLayout co gan dung tag khong.
	var top := XggLayout.find_node(root, "lAchieveTemplateTop")
	if top != null:
		var ds := []
		for c in top.get_children():
			ds.append("%s=%s" % [
				String(c.get_meta("xgg_name", c.name)),
				str(c.get_meta("tag")) if c.has_meta("tag") else "-"])
		print("[godot] lAchieveTemplateTop: ", ", ".join(ds))

	var lua := LuaRuntime.new()
	if not lua.open():
		_note("khong mo duoc Lua: %s" % ", ".join(lua.errors))
		return
	lua.bind_layout(root)

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
		'share.AchieveLogic',
		'user.Logical.ClientAchieveLogic',
		'user.UI.CUIGuildTableViewList',
		'user.UI.CUIAchieve',
	})

	local out = Dictionary()
	for ten, kq in pairs(nap) do
		if kq ~= 'ok' then out['NAP ' .. ten] = kq end
	end
	out['GetStringWithKey'] = type(rawget(_G, 'GetStringWithKey'))
	out['thu chu'] = tostring(GetStringWithKey('AchieveUI_Description_101_1'))

	-- Do du lieu vao DUNG CHO ma goc doc. AchieveLogic:GetUserAchieveMap()
	-- tra ve self.UserAchieveMap sau khi Init(); ta dat san roi danh dau da
	-- init, nen ham goc chay nguyen van ma khong can may chu cu.
	local AchieveState = rawget(_G, 'AchieveState') or {}
	local DANG_LAM = AchieveState.Doing or 1
	local XONG     = AchieveState.Done  or 2

	local mau = {
		{ t = 101, i = 1, s = DANG_LAM, cur = 1, tot = 3 },
		{ t = 102, i = 1, s = XONG,     cur = 3, tot = 3 },
		{ t = 103, i = 1, s = DANG_LAM, cur = 4, tot = 10 },
		{ t = 104, i = 1, s = DANG_LAM, cur = 2, tot = 5 },
		{ t = 105, i = 1, s = XONG,     cur = 1, tot = 1 },
		{ t = 106, i = 1, s = DANG_LAM, cur = 0, tot = 1 },
	}
	local bando = {}
	for k, v in ipairs(mau) do
		bando[tostring(k)] = {
			AchieveType = v.t, AchieveIndex = v.i, State = v.s,
			Current = v.cur, Total = v.tot, Award = {},
		}
	end

	local L = rawget(_G, 'G_AchieveLogic')
	if L ~= nil then
		L.UserAchieveMap = bando
		L.bIsInited = true
	end

	local ui
	local ok, err = pcall(function()
		ui = CUIAchieve:new()
		ui:onInit()
	end)
	out['onInit'] = ok and 'ok' or tostring(err)
	if not ok then return out end

	local ok2, err2 = pcall(function() ui:Reflesh() end)
	out['Reflesh'] = ok2 and 'ok' or tostring(err2)

	-- Bao nhieu dong that su duoc dung ra
	local tv = ui.AchieveTableView
	out['co_TableView'] = tostring(tv ~= nil)
	if tv ~= nil then
		out['tv.tableView'] = tostring(tv.tableView)
		out['tv.ItemCellNumber'] = tostring(tv.ItemCellNumber)
		out['tv.tItemData'] = tv.tItemData and tostring(#tv.tItemData) or 'nil'
		out['tv.pCell'] = tostring(tv.pCell)
		local inner = tv.tableView
		out['so_dong'] = (inner ~= nil and inner.cells ~= nil) and #inner.cells or -1
	else
		out['so_dong'] = -1
	end
	out['so_muc_DataList'] = ui.AchieveDataList and tostring(#ui.AchieveDataList) or 'nil'
	for i, d in ipairs(cocos.tag_miss_log) do out['HUT ' .. i] = d end
	out['tag_hoi'] = cocos.tag_lookups
	out['tag_hut'] = cocos.tag_misses
	return out
"""
