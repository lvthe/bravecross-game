# Kiem bo nap bo cuc XggLayout ma khong can mo cua so.
#
#   godot --headless --path . --script tools/verify_layout.gd
#
# Dung moi file trong layout_ref/ roi doi chieu voi chinh JSON: du node chua,
# doi he toa do co dung khong, cay co dung hinh dang khong.
extends SceneTree

const ROOT := "res://layout_ref/"
const HUD := "Game_UI_Control_Panel_960_640"

var n_pass := 0
var n_fail := 0


func _check(ok: bool, desc: String, detail: String = "") -> void:
	if ok:
		n_pass += 1
		print("  dat   ", desc)
	else:
		n_fail += 1
		print("  HONG  ", desc, "" if detail == "" else "  -> " + detail)


func _count(nd: Dictionary) -> int:
	var n := 1
	for c in nd.get("children", []):
		n += _count(c)
	return n


func _init() -> void:
	var dir := DirAccess.open(ROOT)
	if dir == null:
		print("khong mo duoc ", ROOT,
				" — sinh bang: python ../brave-cross/work/layout.py --all --out layout_ref")
		quit(1)
		return

	# --- 1. doi he toa do, tinh tay tren mot node da biet
	print("\n=== 1. doi he toa do Cocos -> Godot ===")
	var hud_path := ROOT + HUD + ".json"
	if not FileAccess.file_exists(hud_path):
		print("khong thay ", hud_path)
		quit(1)
		return
	var hud := XggLayout.build(hud_path)
	_check(hud != null, "dung duoc HUD man tran")
	if hud == null:
		quit(1)
		return

	# g_GameUILayer: 0,0 960x640, neo (0,0) -> Godot (0,0)
	var rootn := XggLayout.find_node(hud, "g_GameUILayer")
	_check(rootn != null, "tim thay g_GameUILayer")
	if rootn != null:
		_check(rootn.position.is_equal_approx(Vector2.ZERO),
				"lop goc o (0,0)", str(rootn.position))
		_check(rootn.size.is_equal_approx(Vector2(960, 640)),
				"lop goc 960x640", str(rootn.size))

	# spBattleStartTime: Cocos 480,320 150x50, neo (0.5,0.5) trong cha 960x640
	#   trai = 480 - 0.5*150 = 405
	#   y    = 640 - (320 - 0.5*50) - 50 = 640 - 295 - 50 = 295
	var t := XggLayout.find_node(hud, "spBattleStartTime")
	_check(t != null, "tim thay spBattleStartTime")
	if t != null:
		var want := Vector2(405, 295)
		_check(t.position.is_equal_approx(want),
				"node neo giua doi dung toa do", "%s, mong doi %s" % [t.position, want])

	# --- 2. du node tren moi man hinh
	print("\n=== 2. du node tren moi man hinh ===")
	var files := dir.get_files()
	var checked := 0
	var short := []
	var empty := []
	for f in files:
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string(ROOT + f))
		if not doc is Dictionary or not doc.has("roots"):
			continue
		var want := 0
		for r in doc["roots"]:
			want += _count(r)
		var built := XggLayout.build(ROOT + f)
		if built == null:
			empty.append(f)
			continue
		var got := 0
		for c in built.get_children():
			got += _count_nodes(c)
		if got != want:
			short.append("%s(%d/%d)" % [f.get_basename(), got, want])
		built.free()
		checked += 1
	_check(checked > 0, "co man hinh de kiem (%d file)" % checked)
	_check(empty.is_empty(), "man hinh nao cung dung duoc", ", ".join(empty))
	_check(short.is_empty(), "du node tren moi man hinh", ", ".join(short))

	# --- 3. cay dung hinh dang: con nam trong cha
	print("\n=== 3. quan he cha-con ===")
	var deep := XggLayout.find_node(hud, "leftHeroInfoBox")
	_check(deep != null, "tim thay node long sau (leftHeroInfoBox)")
	if deep != null:
		_check(deep.get_child_count() > 0,
				"node long sau co con (%d)" % deep.get_child_count())

	# --- 4. bang ten, dung vai tro cua _G ben ban goc
	print("\n=== 4. bang ten node (thay cho _G) ===")
	var idx := XggLayout.index_of(hud)
	# It hon HAN so node la DUNG: chi node co TEN INSTANCE moi vao bang, dung
	# nhu ban goc — no viet `lAchieveTaskUI`, `sngItemIcon`... chu khong goi node
	# theo ten lop. Tren toan bo 296 man, 30.694/33.472 node khong he co ten
	# instance. Truoc day ta lay ten lop dap vao cho thieu, va cai ten gia do
	# de len ca ten that (mot node khong ten mang lop 'lSubDialogMask' da cuop
	# cho cua chinh lSubDialogMask).
	_check(idx.size() > 40, "co bang chi muc (%d ten tren 629 node)" % idx.size())
	_check(idx.has("g_btnAutoCombat"),
			"tra duoc nut tu dong chien dau bang dung ten cua ban goc")
	var by_index := XggLayout.find_node(hud, "spBattleStartTime")
	_check(by_index != null and by_index == idx.get("spBattleStartTime"),
			"find_node tra ve dung node trong chi muc")

	# --- 5. tra anh theo ten, y het spriteFrameByName
	print("\n=== 5. tra anh theo ten ===")
	var st := UiFrames.stats()
	_check(int(st.get("indexed", 0)) > 5000,
			"chi muc anh co %d muc" % st.get("indexed", 0))
	var tex := UiFrames.get_frame("item_55.png")
	_check(tex != null, "nap duoc mot anh cu the (item_55.png)")
	if tex != null:
		_check(tex.get_size() == Vector2(79, 79),
				"anh dung kich thuoc 79x79", str(tex.get_size()))
	_check(UiFrames.get_frame("v6/ui_background204.png") != null,
			"ten co thu muc dang truoc van tra duoc")
	_check(UiFrames.get_frame("@v6/ui_background204.png") != null,
			"ten co tien to @ van tra duoc")

	# set_frame phai GIU DIEM NEO: node 96x96 neo giua o (200,300) trong cha
	# cao 640 -> goc o (152, 640-300-48=292). Thay anh 79x79 thi tam van o
	# (200,300), goc o thanh (160.5, 640-300-39.5=300.5).
	var probe := TextureRect.new()
	probe.set_meta("cocos", Vector4(200, 300, 0.5, 0.5))
	probe.set_meta("parent_h", 640.0)
	probe.size = Vector2(96, 96)
	if UiFrames.set_frame(probe, "item_55.png"):
		_check(probe.position.is_equal_approx(Vector2(160.5, 300.5)),
				"doi anh thi giu diem neo", str(probe.position))
	else:
		_check(false, "set_frame chay duoc")
	probe.free()

	# Bao nhieu anh cua HUD tra duoc — con so nay noi len do phu that su.
	var doc = JSON.parse_string(FileAccess.get_file_as_string(hud_path))
	var want := 0
	var got := 0
	for s in doc.get("sprites", []):
		if String(s.get("name", "")) == "":
			continue
		want += 1
		if UiFrames.has_frame(String(s["name"])):
			got += 1
	_check(got >= want - 2, "HUD tra duoc %d/%d anh" % [got, want])

	# --- 6. anh da duoc gan vao node
	print("\n=== 6. gan anh vao node ===")
	var no_tex: Array = []
	var tally := _tally(hud, no_tex)
	_check(tally[0] > 100, "co %d node duoc gan anh" % tally[0])
	_check(tally[1] == 0,
			"anh CO trong kho thi phai gan duoc vao node",
			", ".join(no_tex.slice(0, 6)))
	var missing := UiFrames.missing()
	print("  (%d ten anh yeu cau ma khong co file)" % missing.size())
	if missing.size() > 0:
		print("  (%s)" % ", ".join(missing.slice(0, 6)))

	# Kiem duoc vi CUIManager.lua dat zOrder cho tung lop che bang hang so viet
	# ro trong ma, ma ten lop che thi biet san. Neu doc sai truong nay thi
	# khong loi gi ca, chi la lop nay de len lop kia sai cho.
	print("\n=== zOrder (thu tu ve) ===")
	var khung := XggLayout.build(ROOT + "UI_NormalDlg_960_640.json")
	_check(khung != null, "dung duoc khung hop thoai")
	if khung != null:
		var z := func(ten: String) -> int:
			var nd := XggLayout.find_node(khung, ten)
			return int(nd.get_meta("zorder", -1)) if nd != null else -1
		# So voi hang so trong sc/user/Public/CUIManager.lua.
		_check(z.call("lNormalDlgMask") == 20, "lNormalDlgMask = maskZorder 20")
		_check(z.call("lNormalDlgTouchMask") == 21, "lop cham = maskZorder + 1")
		_check(z.call("lSubDialogMask") == 100, "lSubDialogMask = 100")
		_check(z.call("lMessageBoxMask") == 2000, "lMessageBoxMask = 2000")
		_check(z.call("lSystemMask") == 4000, "lSystemMask = 4000")
		_check(z.call("lNetWorkMask") == 6000, "lNetWorkMask = 6000")
		_check(z.call("lDebugBoxMask") == 9000, "lDebugBoxMask = 9000")
		# Nen canh phai nam DUOI lop giao dien, khong thi anh nen phu kin.
		_check(z.call("lSceneBackgroundLayer") < z.call("UIRootLayer"),
				"nen canh nam duoi lop giao dien")
		# Va cay dung ra phai da xep theo do.
		var u := XggLayout.find_node(khung, "UIRootLayer")
		var tang := true
		var truoc := -999999
		for c in u.get_children():
			var zz := int(c.get_meta("zorder", 0))
			if zz < truoc:
				tang = false
			truoc = zz
		_check(tang, "con cua UIRootLayer da xep theo zOrder")

		# Ghep man hinh vao khung: day la cach ban goc bay \u2014 mot cay duy nhat,
		# zOrder sap xep. Man thanh tuu (33) phai nam giua lop che (20) va
		# thanh nut Back (60).
		var man := XggLayout.build(ROOT + "UI_AchievementTask_960_640.json")
		if man != null:
			var da := XggLayout.ghep_vao(khung, man)
			_check(da > 0, "ghep duoc man hinh vao khung")
			var ui := XggLayout.find_node(khung, "lAchieveTaskUI")
			_check(ui != null and ui.get_parent() == u,
					"man hinh thanh anh em cua lop che")
			if ui != null:
				var i_che := u.get_children().find(
						XggLayout.find_node(khung, "lNormalDlgMask"))
				var i_ui := u.get_children().find(ui)
				var i_back := u.get_children().find(
						XggLayout.find_node(khung, "lDialogControlPanel"))
				_check(i_che < i_ui and i_ui < i_back,
						"man hinh ve tren lop che va duoi nut Back")
			_check(absf(u.position.x) < 0.01 and absf(u.position.y) < 0.01,
					"lop giao dien duoc dua ve goc toa do")
			man.free()
		khung.free()


	# --- Ten TRAN bi trung: chon ban nao?
	#
	# 536 ten anh xuat hien o nhieu thu muc. Khi bo cuc ghi ca duong dan thi
	# khong co gi phai chon; khi ma goc goi
	# spriteFrameByName("item_4.png") — mot cai ten tran — thi phai chon.
	#
	# Cham diem bang CHINH BANG SPRITE cua tung man (.xgg section C): no ghi
	# ten KEM KICH THUOC, tuc la cau tra loi do ban goc ghi san. Sai lech 1
	# pixel duoc bo qua: anh .pkm dung ETC1 nen chieu cao duoc dem cho chia
	# het 4 (xem uiart.py).
	print("\n=== chon anh khi ten tran bi trung ===")
	var dung := 0
	var sai := 0
	var vi_du := []
	var d2 := DirAccess.open(ROOT)
	d2.list_dir_begin()
	var f2 := d2.get_next()
	while f2 != "":
		if f2.ends_with(".json"):
			var doc2 = JSON.parse_string(
					FileAccess.get_file_as_string(ROOT + f2))
			if doc2 is Dictionary:
				for r in doc2.get("sprites", []):
					var ten := String(r.get("name", ""))
					if ten == "" or ten.contains("/"):
						continue
					if not UiFrames.is_ambiguous(ten):
						continue
					var tx := UiFrames.get_frame(ten)
					if tx == null:
						continue
					var w := float(r.get("w", 0))
					var h := float(r.get("h", 0))
					if absf(tx.get_size().x - w) <= 1.0 \
							and absf(tx.get_size().y - h) <= 1.0:
						dung += 1
					else:
						sai += 1
						if vi_du.size() < 4:
							vi_du.append("%s: xgg %.0fx%.0f, ta %s"
									% [ten, w, h, tx.get_size()])
		f2 = d2.get_next()
	for e in vi_du:
		print("      lech: %s" % e)
	_check(dung + sai > 100, "co du mau de cham (%d)" % (dung + sai))
	# Luat cu (lay ban dau trong danh sach) chi dung 15/183. Luat moi —
	# uu tien sngSplitData/ roi lay ban nong nhat — dung 178/183.
	_check(dung >= (dung + sai) * 9 / 10,
			"chon dung ban anh: %d/%d" % [dung, dung + sai])

	hud.free()
	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)


func _count_nodes(n: Node) -> int:
	if n.name == "_debug":
		return 0
	var c := 1
	for k in n.get_children():
		c += _count_nodes(k)
	return c

## [so node da gan anh, so node ghi 'verified' ma khong nap duoc anh]
func _tally(n: Node, no_tex: Array) -> Array:
	var applied := 0
	var broken := 0
	if n is Control and n.has_meta("img"):
		var nm := String(n.get_meta("img"))
		if n.get_meta("img_applied", false):
			applied += 1
		elif String(n.get_meta("img_from", "")) == "verified":
			# Phan biet "ban goc khong ship anh do" voi "code khong gan duoc".
			# Chi cai thu hai moi la loi; cai dau la du lieu von the.
			if UiFrames.has_frame(nm):
				broken += 1
				if no_tex.size() < 12:
					no_tex.append(nm)
	for c in n.get_children():
		var r := _tally(c, no_tex)
		applied += r[0]
		broken += r[1]
	return [applied, broken]
