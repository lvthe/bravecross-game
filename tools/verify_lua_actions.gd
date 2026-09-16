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
	_kiem_tam_dung(lua, n)
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

	# LOP MAU. CCLayerColorRoundRect mang mau cua CHINH no (bon byte R,G,B,A
	# trong ban ghi .xgg), khong phai mot sac nhuom len anh. Neu setOpacity di
	# qua modulate nhu moi node khac thi lop che khong bao gio hien duoc: ban
	# ghi cua no la alpha 0, ma modulate chi NHAN vao mau san.
	var lop := ColorRect.new()
	lop.color = Color8(0, 0, 0, 0)
	lua.state.globals["_lop"] = lop
	lua.run("lop = require('cocos').wrap(_lop)", "boc lop mau")
	lua.run("lop:runAction(S_CCFadeTo:create(0.2, 179))", "mo dan lop mau")
	for i in range(6):
		lua.tick(0.05)
	t("FadeTo lam mo duoc lop mau", absf(lop.color.a * 255.0 - 179.0) < 1.0,
			"a=%.1f" % (lop.color.a * 255.0))
	t("mo lop mau khong dung toi modulate", absf(lop.modulate.a - 1.0) < 0.001)
	lua.run("lop:setColor(255, 0, 0)", "doi mau lop")
	t("setColor doi mau lop ma giu do mo",
			lop.color.r > 0.99 and absf(lop.color.a * 255.0 - 179.0) < 1.0,
			str(lop.color))
	lop.free()

	# Show / Hide
	lua.run("thu:runAction(S_CCHide:create())", "hide")
	lua.tick(0.1)
	t("Hide an that", not n.visible)
	lua.run("thu:runAction(S_CCShow:create())", "show")
	lua.tick(0.1)
	t("Show hien lai", n.visible)


func _kiem_tam_dung(lua: LuaRuntime, n: Control) -> void:
	print("=== tam dung (pauseActions / resumeActions) ===")

	# Ban goc: CCNode::pauseActions goi pauseSchedulerAndActions cua Cocos — dung
	# CA bo quan ly action LAN bo hen gio cua node (do trong libgame.so: +0xdc la
	# bo action, +0xd8 la bo thu hai, va pause/resume cham ca hai; in lai bang
	# `brave-cross/work/binder.py --nut`).
	#
	# Cai DUOC kiem o day, va vi sao no dang kiem: khung hinh tam dung khong
	# duoc cong don thoi gian. Neu cong don thi buoc dau sau khi chay lai da
	# nhay thang toi dich — sai han so voi ban goc.
	#
	# Cac con so thoi luong o day do MINH dat ra cho phep kiem, khong phai cua
	# ban goc. Cai duoc kiem la NGU NGHIA: dung han, khong nhay, khong bi cat.

	lua.run("""
		thu:stopAllActions(); thu:setPosition(0, 0)
		thu:runAction(S_CCMoveTo:create(1.0, 100, 0))
	""", "tam dung: dat")
	for i in range(3):
		lua.tick(0.1)
	var x_truoc := n.position.x
	t("tam dung: chay duoc nua duong", absf(x_truoc - 30.0) < 2.0, "x=%.1f" % x_truoc)

	lua.run("thu:pauseActions()", "tam dung")
	lua.tick(1.0)
	lua.tick(1.0)
	t("tam dung: dung han, khong nhuc nhich",
			absf(n.position.x - x_truoc) < 0.001, "x=%.1f" % n.position.x)
	t("tam dung: action con trong danh sach (bi dung, khong bi cat)",
			int(lua.run("return thu:numberOfRunningActions()", "dem")) == 1,
			"con %s" % lua.run("return thu:numberOfRunningActions()", "dem 2"))

	lua.run("thu:resumeActions()", "chay lai")
	lua.tick(0.05)
	t("chay lai: khung hinh tam dung KHONG cong don thoi gian",
			absf(n.position.x - (x_truoc + 5.0)) < 1.5, "x=%.1f" % n.position.x)
	lua.tick(0.7)
	t("chay lai: di not phan con lai", absf(n.position.x - 100.0) < 0.5,
			"x=%.1f" % n.position.x)

	# Action chay SAU khi da tam dung thi chay binh thuong: Cocos `pauseTarget`
	# khong doi `m_bRunning`, nen action them sau khong bi dinh.
	# Doi bang SCALE chu khong doi cho: hai MoveTo tren cung mot node thi cai
	# sau de len cai truoc (ca hai deu ghi vi tri) — dung nhu Cocos, nhung no
	# lam phep kiem "action cu van dung" do nham ngay tu dau.
	lua.run("""
		thu:stopAllActions(); thu:setPosition(0, 0); thu:setScale(1)
		thu:runAction(S_CCMoveTo:create(1.0, 0, 100))
	""", "them sau: dat")
	lua.tick(0.2)
	var y_truoc := n.position.y
	lua.run("""
		thu:pauseActions()
		thu:runAction(S_CCScaleTo:create(1.0, 2.0))
	""", "them sau: tam dung roi them")
	lua.tick(0.5)
	t("action them SAU khi tam dung thi chay binh thuong",
			absf(n.scale.x - 1.5) < 0.06, "scale=%.3f" % n.scale.x)
	t("action cu van dung", absf(n.position.y - y_truoc) < 0.001,
			"y=%.1f -> %.1f" % [y_truoc, n.position.y])
	lua.run("thu:resumeActions(); thu:stopAllActions(); thu:setScale(1)", "don")

	# Node khac khong bi dinh.
	var n2 := TextureRect.new()
	n2.size = Vector2(100, 50)
	n2.set_meta("xgg_name", "thu2")
	n2.set_meta("cocos", Vector4(0, 0, 0, 0))
	n2.set_meta("parent_h", 640.0)
	lua.state.globals["_n2"] = n2
	lua.run("thu2 = require('cocos').wrap(_n2)", "boc node 2")
	lua.run("""
		thu:setPosition(0, 0); thu2:setPosition(0, 0)
		thu:runAction(S_CCMoveTo:create(1.0, 100, 0))
		thu2:runAction(S_CCMoveTo:create(1.0, 100, 0))
	""", "hai node")
	lua.tick(0.2)
	lua.run("thu:pauseActions()", "tam dung node 1")
	lua.tick(0.5)
	t("tam dung node nay khong dung node khac",
			absf(n.position.x - 20.0) < 2.0 and n2.position.x > 60.0,
			"thu=%.1f thu2=%.1f" % [n.position.x, n2.position.x])
	lua.run("thu:resumeActions(); thu:stopAllActions(); thu2:stopAllActions()", "don")
	n2.free()

	# Hen gio cua CHINH node do cung dung theo. Dua ham vao bang lop rieng theo
	# TEN node — dung co che that cua lop gia lap (cocos.lua `lop_rieng`), chu
	# khong tu them duong tat nao cho phep kiem.
	# Node PHAI duoc boc SAU khi dat lop rieng: `wrap` chot `__index` ngay luc
	# boc (cocos.lua:85), dat sau thi node da tro vao `Node` roi va ten ham roi
	# vao ham rong cua `Node.__index` — hen gio se "chay" ma khong lam gi.
	var n3 := TextureRect.new()
	n3.set_meta("xgg_name", "thu3")
	n3.set_meta("cocos", Vector4(0, 0, 0, 0))
	n3.set_meta("parent_h", 640.0)
	lua.state.globals["_n3"] = n3
	lua.run("""
		_dem = { so = 0 }
		require('cocos').lop_rieng['thu3'] = setmetatable({
			dem = function(self, dt) _dem.so = _dem.so + 1 end },
			{ __index = require('cocos').Node })
	""", "lop rieng truoc khi boc")
	lua.run("thu3 = require('cocos').wrap(_n3)", "boc node 3")
	lua.run("S_CCSchedule:scheduleOnce(thu3, 'dem', 0.3)", "hen gio")
	lua.tick(0.1)
	lua.run("thu3:pauseActions()", "tam dung hen gio")
	lua.tick(1.0)
	t("hen gio cua node bi tam dung thi khong chay",
			int(lua.run("return _dem.so", "dem hen 1")) == 0,
			"so=%s" % lua.run("return _dem.so", "dem hen 1b"))
	lua.run("thu3:resumeActions()", "chay lai hen gio")
	lua.tick(0.15)
	t("chay lai: thoi gian tam dung khong tinh vao hen gio",
			int(lua.run("return _dem.so", "dem hen 2")) == 0,
			"so=%s" % lua.run("return _dem.so", "dem hen 2b"))
	lua.tick(0.10)
	t("chay lai: du gio thi hen chay", int(lua.run("return _dem.so", "dem hen 3")) == 1,
			"so=%s" % lua.run("return _dem.so", "dem hen 3b"))
	n3.free()


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
	# Ca hai dang ten deu phai ra CUNG mot ban, va phai la ban trong
	# sngSplitData — do la khong gian ten cua S_CCSpriteFrameCache (anh giao
	# dien khong nam trong atlas, moi anh la mot .pkm rieng trong
	# sngSplitData/, ten trung khit ten trong section C cua .xgg).
	#
	# Truoc day ten tran ra ban `png/book/` 152x155 — anh roi, chi duoc goi
	# bang duong dan day du qua initWithFile — nen o thanh tuu phinh gap doi.
	t("ten tran cung ra ban trong sngSplitData",
			k_tran.begins_with("sngSplitData/"), k_tran)
	t("hai dang ten ra cung mot ban", k_v6 == k_tran,
			"%s vs %s" % [k_v6, k_tran])
	t("khong lay ban png/book", not k_tran.begins_with("png/"), k_tran)
	var tex_tran := UiFrames.get_frame("ui_background176")
	t("ten tran ra dung kich thuoc 76x77",
			tex_tran != null and tex_tran.get_size() == Vector2(76, 77),
			str(tex_tran.get_size()) if tex_tran != null else "khong co")
	# item_4 la cho lam lo ra chuyen nay: no co ban png/item/ 228x179 va ban
	# sngSplitData/ 79x79. O phan thuong cua man thanh tuu la 79x79 nhu moi
	# icon khac; lay ban to thi no de len ca dong.
	var tex_item := UiFrames.get_frame("item_4.png")
	t("item_4 ra ban icon 79x79",
			tex_item != null and tex_item.get_size() == Vector2(79, 79),
			str(tex_item.get_size()) if tex_item != null else "khong co")
	var tex_v6 := UiFrames.get_frame("v6/ui_background176.png")
	t("ban v6 dung kich thuoc thiet ke 76x77",
			tex_v6 != null and tex_v6.get_size() == Vector2(76, 77),
			str(tex_v6.get_size()) if tex_v6 != null else "khong co")

	# KHOP THEO KICH THUOC. Nhieu tam nen khong ghi ten anh trong ban ghi node
	# — CCScale9Sprite thi 2.586/2.599 node nhu vay. Nhung .xgg co liet ke anh
	# roi (section D) va sprite (section C) cua CHINH man do kem kich thuoc, va
	# danh sach rat ngan. Khop duy nhat thi coi la dung.
	var doc = JSON.parse_string(FileAccess.get_file_as_string(
			"res://layout_ref/UI_AchievementTask_960_640.json"))
	# Duyet TAT CA goc: bo cuc co nhieu goc, va node can tim khong nam o goc
	# dau tien.
	var tim = func(roots: Array, w: float, h: float) -> Dictionary:
		var hang: Array = roots.duplicate()
		while not hang.is_empty():
			var x: Dictionary = hang.pop_back()
			if absf(float(x.get("w", 0)) - w) < 0.5 \
					and absf(float(x.get("h", 0)) - h) < 0.5:
				return x
			for c in x.get("children", []):
				hang.push_back(c)
		return {}
	if doc is Dictionary and doc.get("roots", []).size() > 0:
		var bong: Dictionary = tim.call(doc["roots"], 946, 567)
		var bang: Dictionary = tim.call(doc["roots"], 453, 86)
		t("anh roi 946x567 khop duoc theo kich thuoc",
				String(bong.get("imgFrom", "")) == "size",
				String(bong.get("img", "khong thay")))
		t("bang tieu de 453x86 khop duoc theo kich thuoc",
				String(bang.get("imgFrom", "")) == "size",
				String(bang.get("img", "khong thay")))
