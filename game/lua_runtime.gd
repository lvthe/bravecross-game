## May ao Lua + lop gia lap Cocos2d-x, de chay THANG ma nguon cua ban goc.
##
## Vi sao: ban goc co san 952 file Lua / 510.068 dong, trong do rieng giao dien
## la 501 file / ~324.000 dong. Chep tay tung man sang GDScript thi khong bao
## gio xong va khong bao gio giong. Nen ta nap chinh ma do.
##
## Hai thu mac phai lam thu cong, vi Godot khong lam ho:
##
##   * require — ban goc dat package.path = "sc/?.lua" roi require theo ten
##     module. Ta cai mot ham tim tu doc qua FileAccess, vi thu muc sc/ co
##     .gdignore (phai co: addon Lua dang ky .lua la mot ngon ngu script cua
##     Godot, de Godot quet vao thi moi file ma goc bi coi la script Godot).
##
##   * lop gia lap — xem lua/cocos.lua.
class_name LuaRuntime
extends RefCounted

## Thu muc chua ma nguon Lua cua ban goc (bê vao bang tools/import_lua.py).
const SC := "res://sc/"

## Thu muc chua lop gia lap do minh viet.
const SHIM := "res://lua/"

var state: Object = null
var _loaded: Dictionary = {}
var errors: Array[String] = []


## Mo may ao va cai require. Tra ve false neu khong co addon.
func open() -> bool:
	if not ClassDB.class_exists("LuaState"):
		errors.append("khong co LuaState — chay: python tools/fetch_addons.py")
		return false
	state = ClassDB.instantiate("LuaState")
	state.open_libraries()
	state.globals["_godot_read"] = _read
	state.globals["_godot_log"] = func(s): print("[lua] ", s)
	state.globals["_godot_copy"] = _copy
	state.globals["_godot_frame"] = _frame
	state.globals["_godot_text"] = _text
	state.globals["_godot_co_file"] = _co_file
	state.globals["_godot_doc_file"] = _doc_file
	# require tu viet: doi "a.b.c" ra "res://sc/a/b/c.lua", nho ket qua lai
	# dung kieu package.loaded cua Lua that (mot module chi chay mot lan).
	var r = state.do_string("""
		local loaded = {}
		local reading = {}
		function require(name)
			if loaded[name] ~= nil then return loaded[name] end
			if reading[name] then
				error('require vong tron: ' .. name)
			end
			reading[name] = true
			local path = name:gsub('%.', '/')
			local src = _godot_read(path)
			reading[name] = nil
			if src == nil then
				error("khong tim thay module '" .. name .. "'")
			end
			local chunk, err = loadstring(src, '@' .. path .. '.lua')
			if chunk == nil then error(err) end
			local v = chunk()
			if v == nil then v = true end
			loaded[name] = v
			return v
		end
		package = package or {}
		package.loaded = loaded
	""")
	if _is_error(r):
		errors.append("cai require hong: %s" % r)
		return false
	return true


## Doc mot file Lua theo ten module. Tim trong lop gia lap truoc, roi den ma
## goc — de ta de len duoc mot module cua ban goc khi can thay the.
func _read(rel: String) -> Variant:
	for base: String in [SHIM, SC]:
		var p := base + rel + ".lua"
		if FileAccess.file_exists(p):
			return FileAccess.get_file_as_string(p)
	return null


## Nhan ban mot node ke ca cay con. Ban goc nhan mau thanh tung dong danh
## sach, nen thieu cai nay la danh sach rong.
##
## Chep META tuong minh. duplicate() cua Godot khong mang theo metadata, ma
## toan bo cach ma goc tro toi node deu dua vao meta "tag" — ban sao mat tag
## thi getChildByTag tra ve nil va dong nao cung hong ngay dong dau.
func _copy(node: Node) -> Node:
	if node == null:
		return null
	var ban := node.duplicate()
	_copy_meta(node, ban)
	return ban


static func _copy_meta(tu: Node, den: Node) -> void:
	for k in tu.get_meta_list():
		den.set_meta(k, tu.get_meta(k))
	var n: int = mini(tu.get_child_count(), den.get_child_count())
	for i in range(n):
		_copy_meta(tu.get_child(i), den.get_child(i))


## Gan anh theo ten khung. Ban goc gan anh luc CHAY chu khong ghi trong bo
## cuc — day la ly do bo cuc dung khong thi man hinh gan nhu trong tron.
func _frame(node: Control, name: String) -> bool:
	if node == null or name.is_empty():
		return false
	return UiFrames.set_frame(node, name)


## Bang chu tieng Viet cua ban goc (data_ref/text_vi.json, 16.894 khoa).
## Thieu khoa thi tra chinh khoa do, de con nhin thay cho nao chua co chu.
var _strings: Dictionary = {}
var _strings_loaded := false

func _text(key: String) -> String:
	if not _strings_loaded:
		_strings_loaded = true
		var p := "res://data_ref/text_vi.json"
		if FileAccess.file_exists(p):
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				_strings = d
		else:
			push_warning("thieu %s — chay: python ../brave-cross/work/text_table.py" % p)
	return String(_strings.get(key, key))


## Thu muc chua 104 bang cau hinh cua ban goc (bê bang config_tables.py).
const CONFIG := "res://data_ref/"


## Doi duong dan ma goc yeu cau ("config/share/KDBGamePrizeConfig.xgg") thanh
## duong dan that. Ban goc giu nguyen cay thu muc nen chi can gan tien to.
static func _duong(p: String) -> String:
	if p.begins_with("res://"):
		return p
	return CONFIG + p


func _co_file(p: String) -> bool:
	return FileAccess.file_exists(_duong(p))


func _doc_file(p: String) -> Variant:
	var d := _duong(p)
	if not FileAccess.file_exists(d):
		return null
	return FileAccess.get_file_as_string(d)


## Chay mot doan Lua. Tra ve ket qua, hoac null va ghi vao errors.
func run(src: String, name: String = "doan") -> Variant:
	var r = state.do_string(src)
	if _is_error(r):
		errors.append("%s: %s" % [name, r])
		return null
	return r


## Nap lop gia lap Cocos va tra ve bang cua no.
func load_cocos() -> Variant:
	return run("return require('cocos')", "cocos")


## Dua cay node cua mot man hinh (do XggLayout dung) vao Lua, dat moi node co
## TEN thanh bien toan cuc — dung cach ban goc lam. Ma goc cua no viet thang
## `lAchieveTaskUI`, `lAchieveLayer`... khong qua bien trung gian nao.
##
## Tra ve so bien da dat.
func bind_layout(root: Node) -> int:
	var cocos = load_cocos()
	if cocos == null:
		return 0
	state.globals["_root"] = root
	var n := 0
	var names: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c in cur.get_children():
			stack.push_back(c)
		if not cur.has_meta("xgg_name"):
			continue
		var nm := String(cur.get_meta("xgg_name"))
		# Chi dat ten nao dung duoc lam bien Lua.
		if nm.is_empty() or not _is_ident(nm):
			continue
		state.globals["_tmp_node"] = cur
		var r = state.do_string(
				"local c = require('cocos'); %s = c.wrap(_tmp_node)" % nm)
		if _is_error(r):
			errors.append("dat bien %s: %s" % [nm, r])
			continue
		names.append(nm)
		n += 1
	state.globals["_tmp_node"] = null
	return n


## Day thoi gian cho he action cua ban goc. Goi moi khung hinh.
## Tra ve so action con dang chay (0 = da yen).
func tick(dt: float) -> int:
	if state == null:
		return 0
	var r = state.do_string("return require('cocos').tick(%f)" % dt)
	if _is_error(r):
		return 0
	return int(r) if typeof(r) in [TYPE_INT, TYPE_FLOAT] else 0


## Cac API Cocos bi goi ma minh chua lam — dem duoc, de biet con thieu gi.
func missing() -> Dictionary:
	# Dung thang Dictionary cua Godot ben Lua: LuaTable khong co keys(), ma
	# minh can mot Dictionary that de dem ben GDScript.
	var r = state.do_string("""
		local out = Dictionary()
		for k, v in pairs(require('cocos').missing) do out[k] = v end
		return out
	""")
	if _is_error(r) or typeof(r) != TYPE_DICTIONARY:
		return {}
	var d := {}
	for k in r:
		d[String(k)] = int(r[k])
	return d


static func _is_ident(s: String) -> bool:
	if s.is_empty():
		return false
	var c := s.unicode_at(0)
	if not (c == 95 or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)):
		return false
	for i in range(1, s.length()):
		var d := s.unicode_at(i)
		if not (d == 95 or (d >= 48 and d <= 57) or (d >= 65 and d <= 90)
				or (d >= 97 and d <= 122)):
			return false
	return true


static func _is_error(v: Variant) -> bool:
	# do_string tra ve du kieu — chuoi, so, bang, hay LuaError. Goi get_class()
	# tren mot chuoi la loi, nen phai xem kieu truoc.
	return typeof(v) == TYPE_OBJECT and v != null and v.get_class() == "LuaError"
