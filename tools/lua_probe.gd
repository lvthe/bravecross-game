# Thu xem may ao Lua co chay trong Godot khong.
#
#   godot --headless --path . --script tools/lua_probe.gd
extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("LuaState"):
		print("HONG: khong nap duoc LuaState")
		quit(1); return
	var lua = ClassDB.instantiate("LuaState")
	lua.open_libraries()
	var r = lua.do_string("""
		local t = {}
		for i = 1, 5 do t[i] = i * i end
		return { ban = _VERSION, tong = t[1]+t[2]+t[3]+t[4]+t[5] }
	""")
	print("ban Lua : ", r["ban"])
	print("tong    : ", r["tong"])
	# Goi nguoc tu Lua ve GDScript — day la thu lop gia lap se can.
	lua.globals["tu_godot"] = func(x): return "godot nhan: %s" % x
	print(lua.do_string("return tu_godot('xin chao')"))
	quit(0)
