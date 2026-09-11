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

	var path := "res://layout_ref/UI_AchievementTask_960_640.json"
	var root := XggLayout.build(path)
	t("dung duoc bo cuc", root != null)
	if root == null:
		_done()
		return
	var n := lua.bind_layout(root)
	t("dat duoc bien toan cuc", n > 0, "dat %d" % n)

	# Nap khung suon that, theo dung thu tu ban goc phu thuoc.
	var r = lua.run("""
		local boot = require('bootstrap')
		boot.install()
		local out = Dictionary()
		for name, res in pairs(boot.boot({'user.UI.CUIAchieve'})) do
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
