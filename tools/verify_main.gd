# Canh Main: dong vao canh cua ban goc chay qua het phan ENGINE.
#
#   godot --headless --path . --script tools/verify_main.gd
#
# Ba phan:
#   1. Bo hen gio (S_CCSchedule) dung ngu nghia ban goc tu ghi
#      (CTimerManager.lua:102-117).
#   2. convertToWorldSpace / convertToNodeSpace: y huong len, tinh ca phong to.
#   3. g_CSceneManager:RepaleceScene('Main') — dong cua ClientActivitiesLogic
#      .lua:104 — nap canh, khung hop thoai, 13 file chung cua sngPreLoad, roi
#      chay InitUI. Chua co trang thai nguoi choi nen InitUI con dung o cho doi
#      du lieu (CUIMain.lua:201, G_UserLogic:GetLevel() ra nil); phep kiem nay
#      chi doi KHONG CO loi chet nao nam trong lop gia lap.
extends SceneTree

const VM := preload("res://tools/vao_main.gd")

var ok := 0
var bad := 0


func t(name: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [name, ("  (%s)" % note) if note else ""])


func _init() -> void:
	_hen_gio()
	_toa_do()
	_canh()
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# 1. Hen gio ---------------------------------------------------------------

func _nhat(lua: LuaRuntime) -> String:
	return str(lua.run("local s = table.concat(nhat, '|'); nhat = {}; return s", "nhat"))


func _hen_gio() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		t("mo Lua", false, ", ".join(lua.errors))
		return
	var r = lua.run("""
		local L = require('cocos').lich
		nhat = {}
		O = {}
		function O:mot() nhat[#nhat + 1] = 'mot' end
		function O:nhip() nhat[#nhat + 1] = 'nhip' end
		function O:ke() nhat[#nhat + 1] = 'ke'; L:scheduleOnce(O, 'sau') end
		function O:sau() nhat[#nhat + 1] = 'sau' end
		function O:update() nhat[#nhat + 1] = 'up' end
		L:scheduleOnce(O, 'mot')
		H = L:schedule(O, 'nhip', 0.1)
		return true
	""", "dat hen")
	t("dat hen", r == true, ", ".join(lua.errors))
	lua.tick(0.05)
	var s := _nhat(lua)
	t("scheduleOnce chay o khung ke; schedule 0,1 s chua toi", s == "mot", s)
	lua.tick(0.05)
	s = _nhat(lua)
	t("du 0,1 s thi schedule chay, scheduleOnce khong chay lai", s == "nhip", s)
	lua.run("H:stop()", "dung")
	lua.tick(0.2)
	s = _nhat(lua)
	t("stop() thi het chay", s == "", s)
	# Hen dat TRONG luc goi thi chay o khung sau — coroutine doi canh can the.
	lua.run("require('cocos').lich:scheduleOnce(O, 'ke')", "ke")
	lua.tick(0.01)
	s = _nhat(lua)
	t("hen dat trong luc goi chua chay ngay", s == "ke", s)
	lua.tick(0.01)
	s = _nhat(lua)
	t("... ma chay o khung sau", s == "sau", s)
	lua.run("U = require('cocos').lich:scheduleUpdate(O); U:pause()", "update")
	lua.tick(0.01)
	s = _nhat(lua)
	t("pause() thi scheduleUpdate khong goi", s == "", s)
	lua.run("U:resume()", "resume")
	lua.tick(0.01)
	s = _nhat(lua)
	t("resume() thi goi obj:update", s == "up", s)


# 2. Doi toa do ------------------------------------------------------------

func _toa_do() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		return
	var goc := Control.new()
	goc.size = Vector2(960, 640)
	var cha := Control.new()
	cha.position = Vector2(100, 100)
	cha.size = Vector2(400, 300)
	goc.add_child(cha)
	var con := Control.new()
	con.position = Vector2(50, 60)
	con.size = Vector2(80, 40)
	cha.add_child(con)
	lua.state.globals["_cha"] = cha
	lua.state.globals["_con"] = con
	var r = lua.run("""
		local c = require('cocos')
		local C, K = c.wrap(_cha), c.wrap(_con)
		local out = Dictionary()
		local x0, y0 = K:convertToWorldSpace(0, 0)
		local x1, y1 = K:convertToWorldSpace(10, 10)
		out['dx'] = x1 - x0
		out['dy'] = y1 - y0
		local bx, by = K:convertToNodeSpace(x1, y1)
		out['ve'] = string.format('%.2f,%.2f', bx, by)
		-- Goc duoi-trai cua con, nhin tu cha: x = 50, y = 300 - (60 + 40).
		local cx, cy = C:convertToNodeSpace(x0, y0)
		out['trong cha'] = string.format('%.2f,%.2f', cx, cy)
		_cha:set_scale(Vector2(2, 2))
		local x2, y2 = K:convertToWorldSpace(10, 10)
		local x3, y3 = K:convertToWorldSpace(0, 0)
		out['dx phong'] = x2 - x3
		return out
	""", "doi toa do")
	t("doi toa do chay", r != null, ", ".join(lua.errors))
	if r != null:
		t("y huong LEN: +10 trong node la +10 o the gioi",
				float(r["dx"]) == 10.0 and float(r["dy"]) == 10.0,
				"%s, %s" % [r["dx"], r["dy"]])
		t("convertToNodeSpace dao nguoc convertToWorldSpace", str(r["ve"]) == "10.00,10.00",
				str(r["ve"]))
		t("goc duoi-trai cua con nhin tu cha = (50, 200)",
				str(r["trong cha"]) == "50.00,200.00", str(r["trong cha"]))
		t("cha phong 2 lan thi khoang cach o the gioi gap doi",
				absf(float(r["dx phong"]) - 20.0) < 0.01, str(r["dx phong"]))
	goc.free()


# 3. Canh that ------------------------------------------------------------

func _canh() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		t("mo Lua", false, ", ".join(lua.errors))
		return
	XggLayout.respect_visible = true
	var san := Control.new()
	san.size = Vector2(960, 640)
	lua.set_stage(san)
	lua.state.globals["_san"] = san
	if lua.run(VM._NAP, "nap") == null:
		t("nap ma goc", false, ", ".join(lua.errors))
		san.free()
		return
	# Ca chuoi cua ban goc: Login -> dang nhap -> chon may chu -> vao game.
	var d := VM.chay(lua)
	t("chuoi vao game cua ban goc chay toi Main", str(d["dung"]) == "",
			"dung o: %s — da qua: %s" % [d["dung"], ", ".join(d["qua"])])
	# Canh THAT SU dang tren san khau — CurrentScene dat truoc InitUI
	# (CSceneManager.lua:617), con replaceScene chi chay khi InitUI xong (:633).
	var dang = lua.run("""
		local c = require('cocos')
		if c.canh_dang_chay == nil then return '' end
		return tostring(c.raw(c.canh_dang_chay):get_meta('xgg_name'))
	""", "canh dang chay")
	t("InitUI chay het, replaceScene dua g_MainUIScene len san khau",
			str(dang) == "g_MainUIScene", str(dang))
	var r = lua.run(_KIEM, "kiem canh")
	if r == null:
		t("kiem canh", false, ", ".join(lua.errors))
		san.free()
		return
	t("g_CSceneManager.CurrentScene = 'Main'", str(r["CurrentScene"]) == "Main",
			str(r["CurrentScene"]))
	t("coroutine doi canh chay het (isLoading = false)", str(r["isLoading"]) == "false")
	t("g_MainUIScene nam tren san khau", str(r["main tren san"]) == "true")
	t("UIRootLayer nap vao trong g_MainUIScene", str(r["ui trong main"]) == "true")
	t("sngPreLoad nap khung dieu khien (lMainBtnLayer)", str(r["lMainBtnLayer"]) == "true")
	# emu_join nay so theo ti le co cha: engine noi lop phu 1366 -> 1429.
	t("lCommonLoadingDialog:getChildByTag(4) co that",
			str(r["tag 4"]) == "true", str(r["tag 4"]))
	t("khong loi chet nao nam trong lop gia lap", str(r["chet o gia lap"]) == "",
			str(r["chet o gia lap"]))
	print("  -> loi chet dau tien: %s" % r.get("loi chet", "(khong)"))
	san.free()


const _KIEM := """
	local c = require('cocos')
	local out = Dictionary()
	out['CurrentScene'] = tostring(g_CSceneManager.CurrentScene)
	out['isLoading'] = tostring(g_CSceneManager.isLoading)
	local m = rawget(_G, 'g_MainUIScene')
	local id_san = _san:get_instance_id()
	out['main tren san'] = tostring(m ~= nil and c.raw(m):get_parent() ~= nil
		and c.raw(m):get_parent():get_instance_id() == id_san)
	local trong = false
	local u = rawget(_G, 'UIRootLayer')
	if m ~= nil and u ~= nil then
		local id_m = c.raw(m):get_instance_id()
		local p = c.raw(u):get_parent()
		while p ~= nil do
			if p:get_instance_id() == id_m then trong = true break end
			p = p:get_parent()
		end
	end
	out['ui trong main'] = tostring(trong)
	out['lMainBtnLayer'] = tostring(rawget(_G, 'lMainBtnLayer') ~= nil)
	local d = rawget(_G, 'lCommonLoadingDialog')
	out['tag 4'] = tostring(d ~= nil and d:getChildByTag(4) ~= nil)
	local chet = {}
	for _, e in ipairs(loi_chet) do
		if e:find('cocos.lua', 1, true) or e:find('bootstrap.lua', 1, true)
				or e:find('actions.lua', 1, true) then
			chet[#chet + 1] = e
		end
	end
	out['chet o gia lap'] = table.concat(chet, ' || ')
	out['loi chet'] = loi_chet[1] or '(khong)'
	return out
"""
