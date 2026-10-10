# Chay MOT doan Lua bat ky roi KET XUAT CA CAY NODE tren san khau (kem toa do
# that va anh dang gan), de nhin bang so thay vi bang mat.
#
#   godot --headless --path . --script tools/do_man_lua.gd -- --lua=C:/tmp/x.lua --ra=C:/tmp/cay.txt
#   godot --path . --script tools/do_man_lua.gd -- --lua=C:/tmp/x.lua --chup=C:/tmp/cay.png --khung=45
#
# Khac `tools/chay_lua.gd` (chi in gia tri Lua tra ve) va khac
# `tools/do_doanh_trai.gd` (chi do rieng man Doanh Trai): o day doan Lua do
# NGUOI GOI viet, con cay node thi do tu NODE GOC cua san khau — nen dung duoc
# cho bat ky man nao ma khong phai sua cong cu.
extends SceneTree

const VaoMain := preload("res://tools/vao_main.gd")

var _lua_tep := ""
var _ra := "C:/tmp/cay.txt"
var _chup := ""
var _khung := 45
var _stage: Control = null
var _lua: LuaRuntime = null
var _dem := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lua="):
			_lua_tep = a.substr(6)
		elif a.begins_with("--ra="):
			_ra = a.substr(5)
		elif a.begins_with("--chup="):
			_chup = a.substr(7)
		elif a.begins_with("--khung="):
			_khung = int(a.substr(8))
	if _lua_tep == "":
		print("thieu --lua=<file .lua>")
		quit(1)
		return
	var ma := FileAccess.get_file_as_string(_lua_tep)
	if ma.is_empty():
		print("khong doc duoc %s" % _lua_tep)
		quit(1)
		return

	var lua := LuaRuntime.new()
	lua.cua_so_engine = Vector2(960, 640)
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return
	_lua = lua
	XggLayout.respect_visible = true

	var san := Control.new()
	san.size = Vector2(960, 640)
	lua.set_stage(san)
	lua.set_touch_root(san)

	if lua.run(VaoMain._NAP, "nap") == null:
		print("nap hong")
		quit(1)
		return
	var d := VaoMain.chay(lua)
	if d["dung"] != "":
		print("KHONG vao duoc Main: %s" % d["dung"])
		quit(1)
		return

	var r = lua.run(ma, "doan Lua")
	print("doan Lua tra ve: %s" % r)

	var dong := []
	for c in san.get_children():
		_xuat(c, dong, 0)
	var f := FileAccess.open(_ra, FileAccess.WRITE)
	for s in dong:
		f.store_line(s)
	f.close()
	print("ghi %d dong vao %s" % [dong.size(), _ra])

	if _chup != "":
		san.size = Vector2(960, 640)
		root.add_child(san)
		_stage = san
		print("cho %d khung roi chup %s" % [_khung, _chup])
		return
	quit()


func _process(_dt: float) -> bool:
	if _stage == null:
		return false
	_lua.tick(_dt)
	_dem += 1
	if _dem >= _khung:
		var img := root.get_texture().get_image()
		var e := img.save_png(_chup)
		print("chup %s (%dx%d) loi=%d" % [_chup, img.get_width(), img.get_height(), e])
		return true
	return false


## In mot node thanh mot dong; de quy xuong con. Giong `do_doanh_trai.gd`.
func _xuat(n: Node, ra: Array, sau: int) -> void:
	var d := "  ".repeat(sau)
	var ten := String(n.name)
	var tn := String(n.get_meta("type_name", "")) if n.has_meta("type_name") else ""
	var tag := ("#%s" % str(n.get_meta("tag"))) if n.has_meta("tag") else ""
	var lop := n.get_class()
	var vt := ""
	var co := ""
	if n is Control:
		var c := n as Control
		var r := c.get_global_rect()
		vt = "g=(%.2f,%.2f) o=%.2fx%.2f" % [r.position.x, r.position.y, r.size.x, r.size.y]
		co = " neo=%s" % str(c.get_meta("cocos", Vector4.ZERO)) if c.has_meta("cocos") else ""
	elif n is Node2D:
		var o := (n as Node2D).get_global_transform().origin
		vt = "g=(%.2f,%.2f)" % [o.x, o.y]
	var hien := "hien=%s" % str((n as CanvasItem).visible) if n is CanvasItem else ""
	var anh := ""
	if n.has_meta("img") and String(n.get_meta("img")) != "":
		anh = " img=%s%s" % [String(n.get_meta("img")),
				" [da gan]" if n.get_meta("img_applied", false) else " [KHONG GAN]"]
	var chu := ""
	if n is Label:
		chu = " chu=%s" % JSON.stringify((n as Label).text)
	elif n is TextureRect:
		chu = " anh=%s" % _anh((n as TextureRect).texture)
	elif n is NinePatchRect:
		chu = " anh=%s" % _anh((n as NinePatchRect).texture)
	var sc := ""
	if n is CanvasItem and not (n as CanvasItem).scale.is_equal_approx(Vector2.ONE):
		sc = " scale=%s" % str((n as CanvasItem).scale)
	ra.append("%s%-30s tag=%-6s %s <%s> %s%s%s%s%s%s" % [d, ten, tag, tn, lop, vt, co, hien, sc, anh, chu])
	for c in n.get_children():
		_xuat(c, ra, sau + 1)


func _anh(t: Texture2D) -> String:
	if t == null:
		return "khong"
	var rp := t.resource_path
	if rp == "":
		rp = "?(khong co duong dan)"
	rp = rp.replace("res://assets_ref/", "")
	return "%s %dx%d" % [rp, t.get_width(), t.get_height()]
