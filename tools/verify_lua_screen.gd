# Mo MOT MAN HINH cua ban goc bang DUNG DUONG CUA NO, khong sua mot chu nao
# trong ma cua no.
#
#   godot --headless --path . --script tools/verify_lua_screen.gd
#
# Truoc day phep kiem nay tu dung bo cuc, tu goi onInit, tu goi setDialogVisible
# — tuc minh dong vai bo nap. Nay chi lam dung mot viec cua engine (dung khung
# chung UI_NormalDlg_960_640, vi no la thu duy nhat co san truoc moi thu khac),
# roi goi MOT dong:
#
#     g_CUISubDialog:Show('AchieveUI')
#
# va ca chuoi con lai la ma goc: nap bo cuc bang loadLevelFile, onInit, hoat
# canh mo, onShow, setDialogVisible, onVisible, Reflesh.
#
# Nhung bien toan cuc cua khung suon ma minh chua lam (g_CUIHelper,
# G_SoundManager...) van la BONG — xem lua/bootstrap.lua. Bong lam sai hanh vi,
# nen bao cao cuoi bai liet ke chung ra.
extends SceneTree

var ok := 0
var bad := 0


func t(name: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [name, ("  (%s)" % note) if note else ""])


func _init() -> void:
	if not FileAccess.file_exists("res://sc/share/class.lua"):
		print("thieu ma nguon ban goc — chay: python tools/import_lua.py")
		quit(1)
		return
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return

	# Ton trong co hien/an cua file: gio ma goc tu bat len.
	XggLayout.respect_visible = true
	# Khung chung cua hop thoai. Bo cuc cua CHINH man thanh tuu thi khong dung
	# o day — ban goc tu nap no qua loadLevelFile.
	var nen := XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
	t("dung duoc khung hop thoai", nen != null)
	if nen == null:
		_done()
		return
	var n := lua.bind_layout(nen)
	t("dat duoc bien toan cuc", n > 0, "dat %d" % n)
	var goc := XggLayout.find_node(nen, "UIRootLayer")
	t("co UIRootLayer", goc != null)
	if goc == null:
		_done()
		return
	goc.position = Vector2.ZERO
	lua.set_ui_root(goc)

	# Nap khung suon that, theo dung thu tu ban goc phu thuoc.
	var r = lua.run(_NAP, "nap khung suon")
	if r == null:
		t("nap khung suon", false)
		_done()
		return
	var nbad := 0
	for k in r:
		if str(r[k]) != "ok":
			nbad += 1
			print("  HONG nap %s: %s" % [k, r[k]])
	t("nap ca khung suon ban goc", nbad == 0, "%d/%d module hong" % [nbad, r.size()])
	print("  -> nap %d module cua ban goc" % r.size())

	# MOT DONG. Tu day tro di khong con dong nao cua minh.
	var d = lua.run(_SHOW, "mo man hinh")
	t("Show() chay het", d != null and str(d.get("Show", "")) == "ok",
			str(d.get("Show", "?")) if d != null else "?")
	if d == null:
		_done()
		return
	t("loadLevelFile nap bo cuc cua man hinh",
			str(d.get("nap bo cuc", "")) == "true", str(d.get("nap bo cuc", "?")))
	t("bo cuc duoc nap vao UIRootLayer",
			str(d.get("nam trong UIRootLayer", "")) == "true",
			str(d.get("nam trong UIRootLayer", "?")))
	# onInit chi chay khi su kien OnLoadXGG ban ra — tuc khi CLevelLoader ghi
	# ten xgg vao danh sach cua canh dang choi. Day la cho de hong nhat: ten
	# canh la nil thi ca chuoi im lang, khong bao gi.
	t("onInit() da chay (ScrollLayer duoc dat)",
			str(d.get("onInit", "")) == "true", str(d.get("onInit", "?")))
	t("onShow() da chay va bat goc man hinh len",
			str(d.get("IsUiShow", "")) == "true", str(d.get("IsUiShow", "?")))

	# Hoat canh mo keo 0,19 giay (PopUp 0,15 + lui 0,04). Phai day thoi gian
	# roi moi hoi — chinh no goi nguoc ve OnShowAnimationFinish.
	for i in range(20):
		lua.tick(0.05)
	var sau = lua.run(_SAU, "sau hoat canh")
	if sau == null:
		_done()
		return
	t("hoat canh mo xong thi setDialogVisible chay",
			str(sau.get("IsUiVisible", "")) == "true",
			str(sau.get("IsUiVisible", "?")))
	t("goc man hinh ve dung cho cu sau hoat canh",
			str(sau.get("vi tri", "")) == "110,30", str(sau.get("vi tri", "?")))
	t("ty le ve 1 sau hoat canh",
			str(sau.get("ty le", "")) == "1,1", str(sau.get("ty le", "?")))
	# SetOpenZorder: 150 la CUISubDialog.OpenZorder (CUIManager.lua:1847).
	t("goc man hinh len dung z = OpenZorder",
			str(sau.get("zOrder", "")) == str(sau.get("OpenZorder", "x")),
			"%s / %s" % [sau.get("zOrder", "?"), sau.get("OpenZorder", "?")])
	t("lop che cua hop thoai con hien len",
			str(sau.get("che hien", "")) == "true", str(sau.get("che hien", "?")))
	# Khac han hop thoai thuong: CUINormalDlg dat MaskOpacity = 0 (khong lam
	# toi man), con hop thoai con khong dat gi nen CPublic dung 179.
	var mo := float(str(sau.get("che mo", "0")))
	t("lop che mo dan toi 179", absf(mo - 179.0) < 1.0, "%.1f" % mo)
	t("Reflesh() dung ra du so dong", int(sau.get("so dong", -1)) == 6,
			str(sau.get("so dong", "?")))

	# Bao cao: con thieu nhung gi.
	var ghosts = lua.run("""
		local boot = require('bootstrap')
		local out = Dictionary()
		for k, v in pairs(boot.report()) do out[k] = v end
		return out
	""", "bao cao bong")
	if ghosts != null:
		var keys := []
		for k in ghosts:
			keys.append([int(ghosts[k]), String(k)])
		keys.sort_custom(func(a, b): return a[0] > b[0])
		print("\n  Bien toan cuc cua khung suon ma minh CHUA LAM (%d cai):"
				% keys.size())
		for e in keys:
			print("      %-34s x%d" % [e[1], e[0]])

	var miss := lua.missing()
	print("\n  API Cocos bi goi ma CHUA LAM (%d loai):" % miss.size())
	var mk := []
	for k in miss:
		mk.append([int(miss[k]), String(k)])
	mk.sort_custom(func(a, b): return a[0] > b[0])
	for e in mk:
		print("      %-34s x%d" % [e[1], e[0]])

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	nen.free()
	_done()


func _done() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


## Nap khung suon, ke ca ba module cua duong Show.
const _NAP := """
	local boot = require('bootstrap')
	-- install_cocos truoc install: duong Show chay ma THAT, ma ma that goi
	-- GetStringWithKey roi nem thang ket qua vao string.format. De no la bong
	-- thi bong tra ve mot cai bang, va format bao 'string expected, got table'
	-- — loi hien o ma goc chu khong o cho thieu.
	boot.install_cocos()
	boot.install()
	local out = Dictionary()
	for name, res in pairs(boot.boot({
			'share.Protocol', 'share.PrizeLogic', 'user.Public.CUIPrizeResHelper',
			'user.UI.CUIRewardLayer', 'user.Public.CUIHelper',
			'share.AchieveLogic', 'user.Logical.ClientAchieveLogic',
			'user.UI.CUIGuildTableViewList',
			-- Ba cai nay LA duong Show:
			--   CSceneManager      ten canh dang choi + so xgg da nap
			--   CLevelLoader       goi loadLevelFile
			--   CUIDialogAnimation hoat canh mo, roi goi nguoc ve
			'user.Public.CSceneManager', 'user.Public.CLevelLoader',
			'user.Public.CUIDialogAnimation',
			'user.UI.CUIAchieve'})) do
		out[name] = res
	end
	out['cau hinh'] = boot.init_config()
	return out
"""


## Do du lieu vao roi goi DUNG MOT dong cua ban goc.
const _SHOW := """
	local out = Dictionary()
	-- Ban goc luon dang o trong MOT CANH, va CLevelLoader ghi ten xgg da nap
	-- vao danh sach cua canh do; ten canh la nil thi registerPreloadXgg bo
	-- qua, khong ban tin OnLoadXGG, va onInit khong bao gio chay. Ta chua
	-- dung canh Main nen dat la "Test" — mot canh co that cua ban goc.
	g_CSceneManager.CurrentScene = 'Test'

	local S = rawget(_G, 'AchieveState') or {}
	local mau = {
		{ t = 101, s = S.Doing or 1, cur = 1, tot = 3 },
		{ t = 102, s = S.Done  or 2, cur = 3, tot = 3 },
		{ t = 103, s = S.Doing or 1, cur = 4, tot = 10 },
		{ t = 104, s = S.Doing or 1, cur = 2, tot = 5 },
		{ t = 105, s = S.Done  or 2, cur = 1, tot = 1 },
		{ t = 106, s = S.Doing or 1, cur = 0, tot = 1 },
	}
	local bando = {}
	for k, v in ipairs(mau) do
		bando[tostring(k)] = { AchieveType = v.t, AchieveIndex = 1, State = v.s,
			Current = v.cur, Total = v.tot, Award = { k } }
	end
	local L = rawget(_G, 'G_AchieveLogic')
	if L ~= nil then
		L.UserAchieveMap = bando
		L.bIsInited = true
	end

	local ok, err = pcall(function() g_CUISubDialog:Show('AchieveUI') end)
	out['Show'] = ok and 'ok' or tostring(err)

	local g = rawget(_G, 'lAchieveTaskUI')
	out['nap bo cuc'] = tostring(g ~= nil)
	if g ~= nil then
		local cha = require('cocos').raw(g):get_parent()
		out['nam trong UIRootLayer'] = tostring(
			cha ~= nil and tostring(cha:get_meta('xgg_name')) == 'UIRootLayer')
	end
	local ui = g_CUISubDialog.UI['AchieveUI']
	out['onInit'] = tostring(ui ~= nil and ui.ScrollLayer ~= nil)
	out['IsUiShow'] = tostring(ui ~= nil and ui.IsUiShow == true)
	return out
"""


## Sau khi day het hoat canh mo.
const _SAU := """
	local out = Dictionary()
	local ui = g_CUISubDialog.UI['AchieveUI']
	local g = ui:GetRootUI()
	out['IsUiVisible'] = tostring(ui:IsUIVisible())
	local px, py = g:getPosition()
	out['vi tri'] = px .. ',' .. py
	out['ty le'] = g:getScaleX() .. ',' .. g:getScaleY()
	out['zOrder'] = tostring(g:getZOrder())
	out['OpenZorder'] = tostring(g_CUISubDialog.OpenZorder)
	out['che hien'] = tostring(lSubDialogMask:getIsVisible())
	out['che mo'] = tostring(lSubDialogMask:getOpacity())
	local tv = ui.AchieveTableView
	local inner = tv and tv.tableView
	out['so dong'] = (inner ~= nil and inner.cells ~= nil) and #inner.cells or -1
	return out
"""
