# Kiem he action va viec gan anh cua lop gia lap Cocos.
#
#   godot --headless --path . --script tools/verify_lua_actions.gd
#
# Hai thu nay ma sai thi moi man hinh deu sai, nhung sai LANG LE: node dung
# yen hoac hien nham anh, khong bao loi gi. Nen phai kiem bang so.
#
# Cac con so thoi luong o day deu do MINH dat ra cho phep kiem, khong phai cua
# ban goc. Cai duoc kiem la NGU NGHIA: MoveTo di tu cho hien tai toi dich,
# Sequence chay lan luot, Spawn chay song song, RepeatForever khong bao gio
# xong, CallFunc goi dung method theo ten.
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
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return

	# Mot node don, khong can bo cuc.
	var n := TextureRect.new()
	n.size = Vector2(100, 50)
	n.set_meta("xgg_name", "thu")
	n.set_meta("cocos", Vector4(0, 0, 0, 0))
	n.set_meta("parent_h", 640.0)

	lua.run("local c = require('cocos'); require('bootstrap').install_cocos()", "cai")
	lua.state.globals["_n"] = n
	lua.run("thu = require('cocos').wrap(_n)", "boc node")

	_kiem_action(lua, n)
	_kiem_anh(lua, n)

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	n.free()
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _kiem_action(lua: LuaRuntime, n: Control) -> void:
	print("=== he action ===")

	# MoveTo: di tu cho dang dung toi dich, khong nhay ngay.
	lua.run("thu:setPosition(0, 0); thu:runAction(S_CCMoveTo:create(1.0, 100, 0))", "moveTo")
	var x0 := n.position.x
	lua.tick(0.5)
	var x1 := n.position.x
	lua.tick(0.5)
	var x2 := n.position.x
	t("MoveTo di dan chu khong nhay", x0 < x1 and x1 < x2, "%.1f -> %.1f -> %.1f" % [x0, x1, x2])
	t("MoveTo toi dung dich", absf(x2 - 100.0) < 0.5, "x=%.2f" % x2)
	t("xong thi khong con chay", lua.tick(0.1) == 0)

	# Sequence: lan luot, khong song song.
	lua.run("""
		thu:setPosition(0, 0)
		thu:runAction(S_CCSequence:create(
			S_CCDelayTime:create(1.0),
			S_CCMoveTo:create(1.0, 50, 0)))
	""", "sequence")
	lua.tick(0.5)
	t("Sequence: con dang cho thi chua nhuc nhich", absf(n.position.x) < 0.01,
			"x=%.2f" % n.position.x)
	lua.tick(0.5)      # het cho
	lua.tick(1.0)      # xong doan di
	t("Sequence: xong thi toi dich", absf(n.position.x - 50.0) < 0.5,
			"x=%.2f" % n.position.x)

	# Spawn: hai viec cung luc.
	lua.run("""
		thu:setPosition(0, 0); thu:setScale(1)
		thu:runAction(S_CCSpawn:create(
			S_CCMoveTo:create(1.0, 80, 0),
			S_CCScaleTo:create(1.0, 2.0)))
	""", "spawn")
	lua.tick(0.5)
	t("Spawn: ca hai cung chay", n.position.x > 1.0 and n.scale.x > 1.05,
			"x=%.1f scale=%.2f" % [n.position.x, n.scale.x])
	lua.tick(0.6)
	t("Spawn: cung ve dich", absf(n.position.x - 80.0) < 0.5 and absf(n.scale.x - 2.0) < 0.02)

	# RepeatForever: khong bao gio xong.
	lua.run("""
		thu:stopAllActions()
		thu:runAction(S_CCRepeatForever:create(S_CCMoveBy:create(0.2, 1, 0)))
	""", "lap mai")
	var con := 0
	for i in range(20):
		con = lua.tick(0.1)
	t("RepeatForever chay mai", con > 0, "con %d" % con)
	lua.run("thu:stopAllActions()", "dung")
	t("stopAllActions dung that", lua.tick(0.1) == 0)

	# CallFunc: goi method theo TEN, dung cach ban goc dung.
	lua.run("""
		_dem = { so = 0 }
		function _dem:Tang() self.so = self.so + 1 end
		thu:runAction(S_CCSequence:create(
			S_CCDelayTime:create(0.5),
			S_CCCallFunc:create(_dem, "Tang")))
	""", "callfunc")
	lua.tick(0.2)
	var r1 = lua.run("return _dem.so", "dem 1")
	t("CallFunc chua toi luc thi chua goi", int(r1) == 0, "so=%s" % r1)
	lua.tick(0.5)
	var r2 = lua.run("return _dem.so", "dem 2")
	t("CallFunc goi dung mot lan", int(r2) == 1, "so=%s" % r2)

	# Show / Hide
	lua.run("thu:runAction(S_CCHide:create())", "hide")
	lua.tick(0.1)
	t("Hide an that", not n.visible)
	lua.run("thu:runAction(S_CCShow:create())", "show")
	lua.tick(0.1)
	t("Show hien lai", n.visible)


func _kiem_anh(lua: LuaRuntime, n: Control) -> void:
	print("=== gan anh ===")
	# Lay mot ten khung CO THAT trong ui_ref de khoi phu thuoc mot ten cu the.
	var ten := ""
	var d := DirAccess.open("res://ui_ref")
	if d != null:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".png"):
				ten = f
				break
			f = d.get_next()
	if ten.is_empty():
		print("  BO QUA: chua co ui_ref (chay uiart.py)")
		return

	(n as TextureRect).texture = null
	var r = lua.run("""
		local f = S_CCSpriteFrameCache:spriteFrameByName('%s')
		thu:setDisplayFrame(f)
		return f ~= nil
	""" % ten, "setDisplayFrame")
	t("spriteFrameByName tra ve khung", r != null and bool(r))
	t("setDisplayFrame gan duoc anh that", (n as TextureRect).texture != null,
			"ten=%s" % ten)
	if (n as TextureRect).texture != null:
		t("kich thuoc node theo anh",
				n.size == (n as TextureRect).texture.get_size(),
				"%s vs %s" % [n.size, (n as TextureRect).texture.get_size()])

	# TRUNG TEN. Co 536 ten anh xuat hien o nhieu thu muc khac nhau, va anh
	# khac han nhau. `ui_background176` vua co ban `png/book/` (152x155) vua co
	# ban `sngSplitData/v6/` (76x77). Bo cuc ghi ro `v6/...`, nen tra cuu ma rut
	# ve ten tran la lay nham ban to: o thanh tuu phinh gap doi roi de len nhan
	# ten ben canh. Hai trieu chung, mot nguyen nhan.
	var k_v6 := UiFrames.key_of("v6/ui_background176.png")
	var k_tran := UiFrames.key_of("ui_background176")
	t("ten co duong dan tra dung ban v6", k_v6.contains("v6/"), k_v6)
	t("ten tran va ten co duong dan la HAI ban khac nhau", k_v6 != k_tran,
			"%s vs %s" % [k_v6, k_tran])
	var tex_v6 := UiFrames.get_frame("v6/ui_background176.png")
	t("ban v6 dung kich thuoc thiet ke 76x77",
			tex_v6 != null and tex_v6.get_size() == Vector2(76, 77),
			str(tex_v6.get_size()) if tex_v6 != null else "khong co")
