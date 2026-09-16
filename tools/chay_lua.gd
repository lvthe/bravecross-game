# Chay MOT doan Lua bat ky BEN TRONG phien da dang nhap (chuoi Login -> Main
# qua lop offline), roi in gia tri no tra ve.
#
#   godot --headless --path . --script tools/chay_lua.gd -- <duong dan file .lua>
#
# Dung khi can DOC TRANG THAI LUC CHAY ma khong doc ra duoc tu ma nguon: mot
# bien toan cuc la node that hay la bong, mot bang du lieu da duoc dien chua,
# mot ham tra ve gi. Khac han tools/do_mot_man.gd: no do MOT MAN, con cai nay do
# BAT KY thu gi ma doan Lua hoi duoc — mien la cau hoi ay chi doc, khong ghi.
#
# Doan Lua chay SAU khi da vao Main va TRONG CUNG mot may ao voi phien do, nen
# no thay dung nhung gi ma goc thay. Vi du da dung that: hoi thang
# `_G['lVIPRightUI']` va `getmetatable` cua no de phan biet "node khong ton tai"
# voi "node la bong" — cau tra loi do khong doc ra duoc tu file .lua nao.
#
# Doan Lua tu in lay bang print; gia tri `return` duoc in them o dong "KET QUA".
extends SceneTree

const VaoMain := preload("res://tools/vao_main.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		print("can dung mot tham so: duong dan file .lua")
		quit(1)
		return
	var ma := FileAccess.get_file_as_string(args[0])
	if ma.is_empty():
		print("khong doc duoc file: %s" % args[0])
		quit(1)
		return
	var lua := LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return
	var san := Control.new()
	san.size = lua.cua_so_engine
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
	if r == null:
		print("LUA HONG: %s" % ", ".join(lua.errors))
	else:
		print("KET QUA: %s" % r)
	quit()
