# Chay MOT MAN HINH cua ban goc, khong sua mot chu nao trong ma cua no.
#
#   godot --headless --path . --script tools/verify_lua_screen.gd
#
# Buoc truoc (verify_lua_ui.gd) moi chi chung minh doan Lua tro duoc toi node.
# Buoc nay nap that: share/class.lua -> user/Public/CUIPublic.lua ->
# user/UI/CUIAchieve.lua, roi goi CUIAchieve:new() va :onInit().
#
# Nhung bien toan cuc cua khung suon ma minh chua lam (g_CPublic,
# g_CUISubDialog...) duoc thay bang BONG — xem lua/bootstrap.lua. Bong lam sai
# hanh vi, nen day chua phai man hinh chay that; no tra loi dung mot cau:
#
#     ma goc co nap va chay den noi khong, va con thieu chinh xac nhung gi.
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

	# Khung/nen hop thoai nam o bo cuc KHAC (lNormalDlgBackGround).
	var nen := XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
	var path := "res://layout_ref/UI_AchievementTask_960_640.json"
	var root := XggLayout.build(path)
	t("dung duoc bo cuc", root != null)
	if root == null:
		_done()
		return
	if nen != null:
		lua.bind_layout(nen)
	var n := lua.bind_layout(root)
	t("dat duoc bien toan cuc", n > 0, "dat %d" % n)

	# Nap khung suon that, theo dung thu tu ban goc phu thuoc.
	var r = lua.run("""
		local boot = require('bootstrap')
		-- install_cocos truoc install: duong mo hop thoai chay ma THAT, ma ma
		-- that goi GetStringWithKey roi nem thang ket qua vao string.format.
		-- De no la bong thi bong tra ve mot cai bang, va format bao
		-- 'string expected, got table' — loi hien o ma goc chu khong o cho thieu.
		boot.install_cocos()
		boot.install()
		local out = Dictionary()
		for name, res in pairs(boot.boot({'share.Protocol', 'share.AchieveLogic',
				'user.Logical.ClientAchieveLogic', 'user.UI.CUIAchieve'})) do
			out[name] = res
		end
		return out
	""", "nap khung suon")
	if r == null:
		t("nap khung suon", false)
		_done()
		return
	var nbad := 0
	for k in r:
		if String(r[k]) != "ok":
			nbad += 1
			print("  HONG nap %s: %s" % [k, r[k]])
	t("nap ca khung suon ban goc", nbad == 0, "%d/%d module hong" % [nbad, r.size()])
	print("  -> nap %d module cua ban goc" % r.size())

	# Dung doi tuong man hinh va chay vong doi cua no.
	r = lua.run("""
		local out = Dictionary()
		local good, res = pcall(function()
			local ui = CUIAchieve:new()
			return ui
		end)
		out['new'] = good and 'ok' or tostring(res)
		if not good then return out end
		_G._ui = res
		out['rootUIName'] = tostring(res.RootUIName)
		out['uiName'] = tostring(res.UIName)
		local g2, e2 = pcall(function() return _ui:GetRootUI() end)
		out['getRootUI'] = g2 and (e2 ~= nil and 'co' or 'nil') or tostring(e2)
		local g3, e3 = pcall(function() _ui:onInit() end)
		out['onInit'] = g3 and 'ok' or tostring(e3)
		return out
	""", "chay man hinh")
	t("CUIAchieve:new()", r != null and String(r.get("new", "")) == "ok",
			String(r.get("new", "?")) if r != null else "?")
	t("RootUIName dung", r != null
			and String(r.get("rootUIName", "")) == "lAchieveTaskUI",
			String(r.get("rootUIName", "?")) if r != null else "?")
	t("GetRootUI() ra node that", r != null and String(r.get("getRootUI", "")) == "co",
			String(r.get("getRootUI", "?")) if r != null else "?")
	t("onInit() chay het", r != null and String(r.get("onInit", "")) == "ok",
			String(r.get("onInit", "?")) if r != null else "?")

	# Duong MO HOP THOAI cua ban goc: CUINormalDlg:setDialogVisible. No bat lop
	# che, do anh nen bang initWithFile, co gian nen cho vua cua so, dat nut
	# Back, roi goi onVisible(). Truoc day minh tu viet may buoc do; gio de ma
	# goc lo, nen phai co phep kiem giu cho no khoi vo lai.
	var d = lua.run("""
		local out = Dictionary()
		-- Cap mot muc du lieu toi thieu: setDialogVisible goi onVisible, ma
		-- onVisible goi Reflesh — khong co du lieu thi Reflesh hong va ta
		-- khong biet phan CHROME co chay khong.
		local S = rawget(_G, 'AchieveState') or {}
		local L = rawget(_G, 'G_AchieveLogic')
		if L ~= nil then
			L.UserAchieveMap = { ['1'] = {
				AchieveType = 101, AchieveIndex = 1, State = S.Doing or 1,
				Current = 1, Total = 3, Award = {},
			} }
			L.bIsInited = true
		end
		local dlg = rawget(_G, 'g_CUINormalDlg')
		out['co dlg'] = tostring(dlg ~= nil)
		if dlg == nil then return out end
		local ok, err = pcall(function() dlg:setDialogVisible(_ui, true) end)
		out['setDialogVisible'] = ok and 'ok' or tostring(err)
		local bg = rawget(_G, 'lNormalDlgBackGround')
		out['nen hien'] = (bg ~= nil) and tostring(bg:getIsVisible()) or 'khong co node'
		-- Lop che va nut Back: hai buoc con lai cua duong mo hop thoai.
		local m = rawget(_G, 'lNormalDlgMask')
		out['che hien'] = (m ~= nil) and tostring(m:getIsVisible()) or 'khong co node'
		out['che mo dau'] = (m ~= nil) and tostring(m:getOpacity()) or '-'
		out['che mo dich'] = tostring(dlg.MaskOpacity)
		local pn = rawget(_G, 'lDialogControlPanel')
		out['nut Back'] = (pn ~= nil) and tostring(pn:getIsVisible()) or 'khong co node'
		return out
	""", "mo hop thoai")
	t("co g_CUINormalDlg", d != null and String(d.get("co dlg", "")) == "true")
	t("setDialogVisible chay het",
			d != null and String(d.get("setDialogVisible", "")) == "ok",
			String(d.get("setDialogVisible", "?")) if d != null else "?")
	# Lop che khong dat do mo ngay: ma goc cho S_CCFadeTo dua no toi dich trong
	# 0,2 giay, nen phai day thoi gian roi moi hoi.
	#
	# Dich la MaskOpacity cua chinh hop thoai, va CUINormalDlg dat = 0
	# (CUIManager.lua:1538). Tuc lop che cua hop thoai thuong KHONG lam toi man
	# hinh — no chi de nuot cham. Man phia sau bi che bang anh nen dac
	# (ui_background262.jpg) chu khong bang lop mau. Hop thoai long va tooltip
	# thi dat 77, nen phep kiem so voi chinh MaskOpacity chu khong voi mot so
	# minh tu chon.
	for i in range(10):
		lua.tick(0.05)
	var sau = lua.run("""
		local out = Dictionary()
		local m = rawget(_G, 'lNormalDlgMask')
		out['che mo sau'] = (m ~= nil) and tostring(m:getOpacity()) or '-'
		return out
	""", "do mo sau khi chay")
	var mo := float(String(sau.get("che mo sau", "0"))) if sau != null else 0.0
	t("lop che hien len", d != null and String(d.get("che hien", "")) == "true",
			String(d.get("che hien", "?")) if d != null else "?")
	t("lop che bat dau trong suot",
			d != null and absf(float(String(d.get("che mo dau", "-1")))) < 0.5,
			String(d.get("che mo dau", "?")) if d != null else "?")
	var dich := float(String(d.get("che mo dich", "-1"))) if d != null else -1.0
	t("lop che mo dan dung toi MaskOpacity cua ban goc", absf(mo - dich) < 1.0,
			"toi %.1f, ban goc dat %.1f" % [mo, dich])
	t("nut Back duoc bat len", d != null and String(d.get("nut Back", "")) == "true",
			String(d.get("nut Back", "?")) if d != null else "?")
	t("nen hop thoai duoc bat len",
			d != null and String(d.get("nen hien", "")) == "true",
			String(d.get("nen hien", "?")) if d != null else "?")

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
	root.free()
	_done()


func _done() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
