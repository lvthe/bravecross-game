# Ai VE DE LEN ai: chi mot diem tren man, liet ke moi node dang ve trung diem do
# theo THU TU VE (cuoi cung = tren cung).
#
#   godot --path . --script tools/do_ai_de.gd -- --diem=900,280
#
# Vi sao can: anh chup chi noi "co mot vat che mat thanh cong cu", khong noi
# duoc vat ay la NODE nao. Do dai chuoi node cha / zOrder cung khong du: trong
# Godot thu tu ve la thu tu CAY (xgg_layout.gd xep lai anh em theo zOrder cua
# Cocos chu khong dat z_index), ma cay nay do ma Lua dung luc chay — 501 file
# giao dien deu chen node vao giua. Nen phai hoi thang cay node.
#
# Diem la toa do KHUNG NHIN (0..960 x 0..640), cung he voi `--chup`.
extends SceneTree

const VM := preload("res://tools/vao_main.gd")

var _san: Control
var _lua: LuaRuntime
var _diem := Vector2.ZERO
var _ds: Array = []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--diem="):
			var p := a.substr(7).split(",")
			if p.size() == 2:
				_diem = Vector2(float(p[0]), float(p[1]))
	if _diem == Vector2.ZERO:
		print("thieu --diem=x,y (toa do khung nhin)")
		quit(1)
		return

	_lua = LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	_lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not _lua.open():
		print("KHONG chay duoc: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true
	_san = Control.new()
	_san.size = _lua.cua_so_engine
	_san.scale = Vector2.ONE * (vp.y / _lua.cua_so_engine.y)
	_lua.set_stage(_san)
	_lua.set_touch_root(_san)
	get_root().add_child(_san)
	if _lua.run(VM._NAP, "nap") == null:
		print("nap hong: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	var d := VM.chay(_lua)
	if str(d["dung"]) != "":
		print("KHONG toi duoc Main, dung o: %s" % d["dung"])
		quit(1)
		return
	for i in 60:
		_lua.tick(1.0 / 30.0)

	# Mo thanh cong cu ra truoc — day chinh la tinh huong dang truy.
	_lua.run("g_CUIMainMenuTool:SetToolBarStatus(true)", "mo thanh cong cu")
	for i in 60:
		_lua.tick(1.0 / 30.0)

	_luot(_san)
	print("diem %s — %d node dang ve trung no, duoi len tren:" % [_diem, _ds.size()])
	# `_luot` ghi theo thu tu SAU (con truoc, cha sau), ma Godot ve con DE LEN
	# cha — nen node con nam DAU danh sach la node TREN CUNG. In tu dau.
	for i in range(_ds.size()):
		print("  %2d. %s" % [i, _ds[i]])
	quit(0)


## Duyet cay theo THU TU VE: con truoc cha sau cung, anh em theo thu tu cay.
## Node nao khong ve gi (khong phai CanvasItem, dang an, rong) thi bo.
func _luot(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	for c in n.get_children():
		_luot(c)
	var o := _o_cua(n)
	# Co node trong cay mang o khong huu han (rig dung sai, o 0 chia) — `has_point`
	# cua Godot kem theo `assert` nen phai chan truoc, khong thi ca luot do vo.
	if o.size != Vector2.ZERO and is_finite(o.position.x) and is_finite(o.position.y) \
			and is_finite(o.size.x) and is_finite(o.size.y) and o.has_point(_diem):
		# `z` la z_index HIEN TAI cua chinh node, va `Z` la z_index hieu dung (tong
		# cua moi to tien khi z_as_relative). Godot ve theo thu tu cay, NHUNG z
		# hieu dung khac 0 thi no de len het moi node z=0 — nen phai in ca hai,
		# neu khong thi "cay noi duoi ma anh noi tren" khong truy duoc.
		_ds.append("%-30s o=(%d..%d, %d..%d) z=%d Z=%d  %s" % [_ten(n),
				o.position.x, o.end.x, o.position.y, o.end.y, _z(n), _Z(n), _lop(n)])
		# Duong day du tu goc cay (kem id): hai node TRUNG TEN o hai nhanh khac
		# nhau la hai vat khac nhau, va day la cach duy nhat nhin ra dieu do —
		# `_lop` chi in ten nen mot ban sao se trong y het ban that.
		print("      path=%s id=%d" % [n.get_path(), n.get_instance_id()])


## O cua node tren khung nhin. Control thi `get_global_rect` (dung cho ca node
## nam trong Control bi phong to); Sprite2D thi hop cua anh da bien doi.
func _o_cua(n: Node) -> Rect2:
	if n is Control:
		return (n as Control).get_global_rect()
	if n is Sprite2D:
		var s := n as Sprite2D
		if s.texture == null:
			return Rect2()
		var r := s.texture.get_size()
		var g := s.get_global_transform()
		var o := g * (-r * 0.5)
		var b := Rect2(o, Vector2.ZERO)
		for c in [Vector2(r.x, -r.y) * 0.5, Vector2(-r.x, r.y) * 0.5, r * 0.5]:
			b = b.expand(g * c)
		return b
	return Rect2()


func _ten(n: Node) -> String:
	var t := String(n.get_meta("xgg_name", ""))
	if t == "":
		t = String(n.get_meta("cls", ""))
	if t == "":
		t = n.name
	return "%s [%s]" % [t, n.get_class()]


## Duong tu goc san khau xuong node, kem zOrder — de biet no thuoc bo cuc nao.
func _duong(n: Node) -> String:
	var ds := []
	var m := n
	while m != null and m != _san:
		var t := String(m.get_meta("xgg_name", ""))
		if t == "":
			var c := String(m.get_meta("cls", ""))
			t = c if c != "" else String(m.name)
		ds.push_front("%s(z=%s)" % [t, m.get_meta("zorder", 0)])
		m = m.get_parent()
	return " < ".join(ds)


## Duong CHI SO con tu goc san khau — day moi la thu tu ve that (Godot ve theo
## thu tu cay; hai node khac nhanh thi nhanh nao dung truoc ve truoc).
func _chi_so(n: Node) -> String:
	var ds := []
	var m := n
	while m != null and m != _san:
		var i := m.get_index()
		if m.get_parent() != null and m.get_parent().has_meta("_xep_lai"):
			i = m.get_meta("_xep_lai")
		ds.push_front("%d" % i)
		m = m.get_parent()
	return "id=%d /%s" % [n.get_instance_id(), "/".join(ds)]


## Chuoi to tien kem LOP GODOT — de bat lop khong ve gi (CanvasLayer) nam giua.
func _lop(n: Node) -> String:
	var ds := []
	var m := n
	while m != null and m != _san:
		ds.push_front("%s:%s#%d" % [m.name, m.get_class(), m.get_instance_id()])
		m = m.get_parent()
	return " < ".join(ds)


## z_index cua chinh node (0 neu khong phai CanvasItem).
func _z(n: Node) -> int:
	return (n as CanvasItem).z_index if n is CanvasItem else 0


## z_index HIEU DUNG: cong don moi to tien khi `z_as_relative` bat (mac dinh).
func _Z(n: Node) -> int:
	var t := 0
	var m := n
	while m is CanvasItem:
		var c := m as CanvasItem
		if not c.z_as_relative:
			t = 0
		t += c.z_index
		m = m.get_parent()
	return t
