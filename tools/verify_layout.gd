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
