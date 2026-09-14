# Cham: bam vao node thi ham xu ly CUA BAN GOC chay.
#
#   godot --headless --path . --script tools/verify_cham.gd
#
# Ba phan:
#   1. Du lieu: ten cham va doi tuong nhan cham doc tu .xgg (+0x0C / +0x14)
#      co mat trong layout_ref.
#   2. Luat phan phoi, tren mot cay gia: node tren cung an, giu cham khi tay
#      truot ra, tat/an thi khong an, khong co doi tuong thi khong nuot, doi
#      tuong tra theo ten bien toan cuc cua file, toa do doi sang Cocos.
#   3. Man that: mo AchieveUI bang duong Show cua ban goc, bam nut nhan
#      thuong, va CUIAchieve:onTouchEnd_OnAhchieveButtonClick chay.
extends SceneTree

const MAN := preload("res://tools/verify_lua_screen.gd")

var ok := 0
var bad := 0


func t(name: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [name, ("  (%s)" % note) if note else ""])


func _init() -> void:
	_du_lieu()
	_gia_lap()
	_man_that()
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# 1. Du lieu ---------------------------------------------------------------

func _dem(nd: Dictionary, dem: Dictionary) -> void:
	var ten := String(nd.get("touch", ""))
	if ten != "":
		dem["tong"] += 1
		if ten == "OnAhchieveButtonClick" and String(nd.get("touchObj", "")) == "g_CUIAchieve":
			dem["nut"] += 1
	for c in nd.get("children", []):
		_dem(c, dem)


func _du_lieu() -> void:
	var dem := {"tong": 0, "nut": 0}
	var d = JSON.parse_string(FileAccess.get_file_as_string(
			"res://layout_ref/UI_AchievementTask_960_640.json"))
	for r in (d.get("roots", []) if d is Dictionary else []):
		_dem(r, dem)
	# Ca ba nut 'canget' cua man thanh tuu, do bang tay trong file .xgg.
	t("UI_AchievementTask: 3 nut OnAhchieveButtonClick -> g_CUIAchieve",
			dem["nut"] == 3, str(dem["nut"]))

	var tong := {"tong": 0, "nut": 0}
	var so_file := 0
	for f in DirAccess.get_files_at("res://layout_ref"):
		if not f.ends_with(".json"):
			continue
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://layout_ref/" + f))
		if j is Dictionary:
			so_file += 1
			for r in j.get("roots", []):
				_dem(r, tong)
	# work/xgg.py doc duoc 2.005 node co ten cham tren 296 file. Chua co la
	# layout_ref dung bang layout.py cu — chay lai no (roi emu_join --ghi).
	t("layout_ref co ten cham", tong["tong"] >= 1900,
			"%d node / %d file" % [tong["tong"], so_file])
	print("  -> %d node co ten cham trong %d bo cuc" % [tong["tong"], so_file])


# 2. Luat phan phoi --------------------------------------------------------

func _o(cha: Control, r: Rect2) -> Control:
	var n := Control.new()
	n.position = r.position
	n.size = r.size
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cha.add_child(n)
	return n


func _nhat(lua: LuaRuntime) -> String:
	var s = lua.run("local s = table.concat(nhat, '|'); nhat = {}; return s", "nhat")
	return str(s)


func _bam(lua: LuaRuntime, p: Vector2, tha: Vector2 = Vector2.INF) -> bool:
	var an := lua.touch_at("Begin", p)
	var q := p if tha == Vector2.INF else tha
	if q != p:
		lua.touch_at("Move", q)
	lua.touch_at("End", q)
	return an


func _gia_lap() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		t("mo Lua", false, ", ".join(lua.errors))
		return
	var goc := Control.new()
	goc.size = Vector2(960, 640)
	var a := _o(goc, Rect2(100, 100, 200, 100))
	var b := _o(goc, Rect2(150, 120, 100, 50))     # ve sau A nen nam tren
	var k := _o(goc, Rect2(600, 100, 100, 100))    # co ten cham, khong doi tuong
	var f := _o(goc, Rect2(600, 300, 100, 100))    # doi tuong theo ten trong file
	f.set_meta("touch", "TuFile")
	f.set_meta("touch_obj", "g_ThuCham")
	lua.set_touch_root(goc)
	lua.state.globals["_A"] = a
	lua.state.globals["_B"] = b
	lua.state.globals["_K"] = k
	var r = lua.run(_DAT, "dat")
	t("dat doi tuong nhan cham", r == true, ", ".join(lua.errors))
	if r != true:
		goc.free()
		return

	t("bam A: Begin roi End(trong o), sender dung la A",
			_bam(lua, Vector2(120, 110)) and _nhat(lua) == "A Begin true|A End true")
	var s := ""
	_bam(lua, Vector2(200, 140))
	s = _nhat(lua)
	t("bam cho B de len A: B an, A khong", s == "B End true", s)
	# Toa do Cocos: goc duoi-trai, y len: canvas (250, 300) -> (250, 340).
	_bam(lua, Vector2(120, 110), Vector2(250, 300))
	s = _nhat(lua)
	t("truot ra ngoai: Move(ngoai, x, y Cocos) roi End(false)",
			s == "A Begin true|A Move false 250 340|A End false", s)

	lua.run("B:setEnableLuaTouch(false)", "tat B")
	_bam(lua, Vector2(200, 140))
	s = _nhat(lua)
	t("tat B (setEnableLuaTouch): cham roi xuong A", s == "A Begin true|A End true", s)
	var tat = lua.run("return B:getEnableLuaTouch()", "hoi B")
	t("getEnableLuaTouch doc lai false", tat == false, str(tat))
	lua.run("B:setEnableLuaTouch(true)", "bat B")

	b.visible = false
	_bam(lua, Vector2(200, 140))
	s = _nhat(lua)
	t("an B: cham roi xuong A", s == "A Begin true|A End true", s)
	b.visible = true

	t("ten cham ma khong co doi tuong: khong nuot cham",
			not _bam(lua, Vector2(650, 150)) and _nhat(lua) == "")
	_bam(lua, Vector2(650, 350))
	s = _nhat(lua)
	t("doi tuong tra theo ten bien toan cuc (meta touch_obj)", s == "file End true", s)
	t("cho trong: khong ai an", not _bam(lua, Vector2(900, 600)))

	# THU PHONG. Kich ban tran goi g_BattleField:SetCameraScale, va truoc day
	# ta khong lam voi ly do "thu phong lam lech toa do cham". Kiem lai cho ra
	# nhe: phep phan phoi di tron chuoi bien doi CanvasItem roi nghich dao
	# (LuaRuntime._bien_doi), nen mot node CHA bi phong to van cham dung.
	#
	# Phong doi len 2 lan quanh goc: o A (100,100 rong 200x100) chuyen thanh
	# (200,200 rong 400x200), nen diem (240,220) phai trung A, con diem cu
	# (120,110) thi khong con.
	goc.scale = Vector2(2, 2)
	_bam(lua, Vector2(240, 220))
	s = _nhat(lua)
	t("phong to 2x: bam theo toa do da phong thi van trung",
			s == "A Begin true|A End true", s)
	t("phong to 2x: diem cu khong con trung", not _bam(lua, Vector2(120, 110)))
	goc.scale = Vector2.ONE
	_bam(lua, Vector2(120, 110))
	s = _nhat(lua)
	t("ve ty le 1: bam lai binh thuong", s == "A Begin true|A End true", s)

	var hoi = lua.run(
			"return A:getLuaTouchName() == 'Nut' and A:getCallbackLuaObject() == O",
			"hoi A")
	t("getLuaTouchName / getCallbackLuaObject doc lai dung", hoi == true, str(hoi))
	goc.free()


const _DAT := """
	local c = require('cocos')
	A, B, K = c.wrap(_A), c.wrap(_B), c.wrap(_K)
	nhat = {}
	local function ghi(s) nhat[#nhat + 1] = s end
	O = {}
	function O:onTouchBegin_Nut(s) ghi('A Begin ' .. tostring(s == A)) end
	function O:onTouchMove_Nut(s, trong, x, y)
		ghi(string.format('A Move %s %d %d', tostring(trong), x, y))
	end
	function O:onTouchEnd_Nut(s, trong) ghi('A End ' .. tostring(trong)) end
	local P = {}
	function P:onTouchEnd_Tren(s, trong) ghi('B End ' .. tostring(trong)) end
	g_ThuCham = {}
	function g_ThuCham:onTouchEnd_TuFile(s, trong) ghi('file End ' .. tostring(trong)) end
	A:setCallbackLuaObject(O)
	A:setLuaTouchName('Nut')
	B:setCallbackLuaObject(P)
	B:setLuaTouchName('Tren')
	K:setLuaTouchName('KhongAi')
	return true
"""


# 3. Man that --------------------------------------------------------------

## Node dang hien (ca chuoi cha deu hien) mang ten cham nay.
func _tim_hien(n: Node, ten: String, ds: Array) -> void:
	if n is CanvasItem and not n.visible:
		return
	if n is Control and String(n.get_meta("touch", "")) == ten:
		ds.append(n)
	for c in n.get_children():
		_tim_hien(c, ten, ds)


func _man_that() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		t("mo Lua", false, ", ".join(lua.errors))
		return
	XggLayout.respect_visible = true
	var nen := XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
	if nen == null:
		t("dung khung hop thoai", false)
		return
	lua.bind_layout(nen)
	var goc := XggLayout.find_node(nen, "UIRootLayer")
	goc.position = Vector2.ZERO
	lua.set_ui_root(goc)
	lua.set_touch_root(nen)
	if lua.run(MAN._NAP, "nap") == null:
		t("nap ma goc", false, ", ".join(lua.errors))
		nen.free()
		return
	var d = lua.run(MAN._SHOW, "mo AchieveUI")
	t("mo AchieveUI bang Show cua ban goc",
			d != null and str(d.get("Show", "")) == "ok",
			str(d.get("Show", "?")) if d != null else ", ".join(lua.errors))
	for i in range(20):
		lua.tick(0.05)

	var nut: Array = []
	_tim_hien(nen, "OnAhchieveButtonClick", nut)
	t("co nut nhan thuong dang hien", not nut.is_empty(), str(nut.size()))
	if nut.is_empty():
		nen.free()
		return
	var n: Control = nut[0]
	var tam := LuaRuntime._bien_doi(n) * (n.size * 0.5)
	var an := _bam(lua, tam)
	var r = lua.run("""
		local c = require('cocos')
		local out = Dictionary()
		out['goi'] = table.concat(c.nhat_ky_cham, '|')
		out['loi'] = table.concat(c.loi_cham, ' || ')
		return out
	""", "doc nhat ky")
	var goi := str(r.get("goi", "")) if r != null else ""
	t("bam nut: engine gia goi dung ham cua ban goc", an
			and goi.contains("onTouchEnd_OnAhchieveButtonClick"), goi)
	var loi := str(r.get("loi", "")) if r != null else "?"
	t("ham cua ban goc chay khong loi", loi == "", loi)
	print("  -> bam nut '%s' tai %s: %s" % [n.name, tam, goi])
	nen.free()
