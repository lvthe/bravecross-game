# Do ba ham "diem gan" (plug) cua armature: _lua_addChildToPlugIn,
# _lua_clearPlugIn, _lua_getPlugInPositionInNode.
#
#   godot --headless --path . --script tools/verify_plug.gd
#
# Ba ham nay co 48 cho goi trong ma goc va truoc luot nay KHONG HE TON TAI o lop
# gia lap: ten khong co trong bang Node nen roi vao __index, tra ve mot ham dem
# lai roi tra nil. Nghia la khong bao loi, chi la khong co gi duoc treo — cung
# kieu voi _godot_zsort (xem ROADMAP).
#
# Cai phai do khong phai "ham co chay khong" ma la "SO trong ten plug co dung la
# so chu khong". Doan sai thi moi thu van chay, chi la nhan chu treo vao SAI
# XUONG — khong co loi nao de doc ra. Nen phep do nay so vi tri do duoc LUC CHAY
# voi vi tri ghi trong chinh file armature (`assets_ref/Gashapon/Gashapon.json`),
# tuc hai duong doc lap.
#
# Chon armature Gashapon va dong tac Star1 vi mot ly do do duoc: trong Star1 ca
# BON diem gan deu chi co MOT khoa (do tren file: dur 53 / 7 / 7 / 45, nhung
# mot khoa thi SngRig chi dat mot moc o t = 0), nen vi tri cua chung la HANG SO
# trong suot dong tac — khong phai dung lai thuat toan cong don `dur` moi biet
# cho doi.
#
#   PlugIn_4_Hero      ( 0.00,  115.54)
#   PlugIn_5_Word      (51.48,  253.23)
#   PlugIn_6_Light     ( 1.51,    1.43)
#   PlugIn_7_HeroName  ( 5.01, -171.39)
#
# Bon so khac nhau hoan toan, nen mot lan gan sai xuong la lech hang tram px.
#
# Ca khong the trung thu hai, doc thang tu ma goc: armature Gashapon co dung bon
# diem gan ten PlugIn_4_Hero / _5_Word / _6_Light / _7_HeroName, va
# sc/user/Public/CUIUnlockHeroAnimation.lua:166-169 goi _lua_clearPlugIn dung bon
# so 4, 5, 6, 7.
extends SceneTree

const ART := "res://assets_ref/Gashapon"
const BIEN_THE := "Gashapon"
const DONG_TAC := "Star1"
const PLUG := [4, 5, 6, 7]
## Sai so cho phep, tinh bang px. Vi tri trong file ghi 2 chu so thap phan.
const LECH := 0.01

## Node treo thu: co kich thuoc va neo KHAC 0 de phep do bat duoc ca loi dao
## dau truc y lan loi tinh neo. Dat ca hai bang 0 thi moi cong thuc sai deu ra
## ket qua giong nhau.
const CON_X := 30.0
const CON_Y := 40.0
const CON_W := 40.0
const CON_H := 20.0
const CON_AX := 0.5
const CON_AY := 0.5

## Nen tran, giong tools/quet_show.gd --tho: khong dang nhap, khong nguoi choi.
## Day khong phai phep do man hinh nen chang can du lieu nguoi choi; nhung van
## phai nap du ma goc, vi getSpriteFromSpriteCatch nam trong bootstrap.
const _BOOT := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	boot.boot_goc()
	boot.init_config()
	g_CSceneManager.CurrentScene = 'Test'
	return true
"""

## Dung armature trong CAY that (qua `_SAN`, do bind_layout dat `_root`), cho no
## chay Star1, roi treo mot node len diem gan 4.
##
## Phai nam trong cay: `AnimationPlayer` chi ap track khi o trong cay, ma khong
## ap thi moi xuong con o (0, 0) — luc do bon diem gan trung nhau va phep do
## khong phan biet duoc gi.
const _LUA_DUNG := """
	local c = require('cocos')
	_G['_SAN'] = c.wrap(_root)
	local cha = c.new_node('layer')
	_SAN:addChild(cha)
	_G['_CHA'] = cha
	local spA = getSpriteFromSpriteCatch('Gashapon')
	cha:addChild(spA)
	_G['_SPA'] = spA
	spA:setPosition(0, 0)
	spA:_Lua_playAnimation('Star1')
	return true
"""

## Doc vi tri bon diem gan, roi treo thu mot node len diem gan 4.
##
## Tra ve SAU o: bon vi tri diem gan; vi tri node treo doc lai; va node co cha
## khong. Chua go ra — phep do ben GDScript (so vi tri TOAN CUC cua node voi goc
## diem gan) phai chay truoc khi no bi go.
const _LUA_DOC := """
	local c = require('cocos')
	local cha = _G['_CHA']
	local spA = _G['_SPA']
	local ra = {}
	for _, n in ipairs({4, 5, 6, 7}) do
		local x, y = spA:_lua_getPlugInPositionInNode(n, cha)
		ra[#ra + 1] = string.format('%.2f,%.2f', x, y)
	end
	-- Nguoi goi that luon dat (x, y) TRUOC khi gan (FBDingJunShanJiaoFei.lua:85:
	-- pText:setPosition(0, 0) roi moi gan), va doc lai PHAI ra dung so ay —
	-- trong he cua diem gan. Neu buoc doi he sai thi so doc lai lech dung bang
	-- chieu cao cua cha cu (640 voi node tao luc chay), hoac lech dau neu quen
	-- dao truc y.
	local con = c.new_node('sprite')
	con:setContentSize(40, 20)
	con:setAnchorPoint(0.5, 0.5)
	con:setPosition(30, 40)
	spA:_lua_addChildToPlugIn(4, con)
	_G['_CON'] = con
	local cx, cy = con:getPosition()
	ra[#ra + 1] = string.format('%.2f,%.2f', cx, cy)
	ra[#ra + 1] = tostring(con:getParent() ~= nil)
	return table.concat(ra, ';')
"""

## Go node ra khoi diem gan 4, roi hoi mot diem gan khong co that.
const _LUA_XOA := """
	local spA = _G['_SPA']
	local con = _G['_CON']
	spA:_lua_clearPlugIn(4)
	local ra = {}
	-- Node phai roi khoi cay va KHONG bi huy: nguoi goi giu tham chieu rieng
	-- (CUIUnlockHeroAnimation go ra roi moi huy sprite).
	ra[#ra + 1] = tostring(con:getParent() ~= nil)
	-- Diem gan khong co that (so 99): im lang bo qua, khong nem loi.
	local x99, y99 = spA:_lua_getPlugInPositionInNode(99, _G['_CHA'])
	ra[#ra + 1] = string.format('%.2f,%.2f', x99, y99)
	return table.concat(ra, ';')
"""

var _dat := 0
var _hong := 0
## Rig cua phan A, giu lai qua cac khung cho.
var _rig_a: SngRig = null


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


## Vi tri ghi trong file armature: khoa DUY NHAT cua xuong trong dong tac nay.
## Tra ve {ten xuong: Vector2}, hoac {} neu hinh dang file khac dieu dang cho.
func _vi_tri_goc() -> Dictionary:
	var p := ART.path_join(BIEN_THE + ".json")
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	for g in d.get("groups", []):
		if String(g.get("variant", "")) != BIEN_THE:
			continue
		for a in g.get("animations", []):
			if String(a.get("name", "")) != DONG_TAC:
				continue
			var ra := {}
			for b in a.get("bones", []):
				var ten := String(b.get("name", ""))
				var ks: Array = b.get("keys", [])
				if ten.begins_with("PlugIn_") and ks.size() == 1:
					ra[ten] = Vector2(float(ks[0].get("x", 0.0)),
							float(ks[0].get("y", 0.0)))
			return ra
	return {}


## Doi ten PlugIn_<n> thuc te (co the co hau to) tu mot danh sach ten.
func _ten_theo_so(goc: Dictionary, so: int) -> String:
	var dau := "PlugIn_%d" % so
	for k in goc:
		var t := String(k)
		if t == dau or t.begins_with(dau + "_"):
			return t
	return ""


func _tim_rig(n: Node) -> SngRig:
	for c in n.get_children():
		if c is SngRig:
			return c
		var s := _tim_rig(c)
		if s != null:
			return s
	return null


func _init() -> void:
	# --- Vi tri goc, doc tu chinh file armature ----------------------------
	var goc := _vi_tri_goc()
	if goc.size() != PLUG.size():
		print("KHONG doc duoc vi tri goc tu %s (duoc %d xuong co dung mot khoa, doi %d)"
				% [ART, goc.size(), PLUG.size()])
		quit(1)
		return
	print("vi tri goc trong %s/%s, doc tu chinh file .json:" % [BIEN_THE, DONG_TAC])
	var ten := {}
	for so in PLUG:
		ten[so] = _ten_theo_so(goc, so)
		if ten[so] == "":
			print("   thieu xuong PlugIn_%d" % so)
			quit(1)
			return
		print("   %-20s %s" % [ten[so], goc[ten[so]]])

	# --- Phan A: tang rig, do thang bang SngRig ---------------------------
	var nen := Node2D.new()
	root.add_child(nen)
	_rig_a = SngRig.build(ART, BIEN_THE)
	if _rig_a == null:
		print("   SngRig.build tra ve null")
		quit(1)
		return
	nen.add_child(_rig_a)
	if not _rig_a.play(DONG_TAC):
		print("   khong co dong tac %s" % DONG_TAC)
		quit(1)
		return

	# --- Phan B: lop gia lap Lua ------------------------------------------
	var lua := LuaRuntime.new()
	# Cua so cua ENGINE — giong tools/quet_show.gd: cao co dinh 768, rong theo
	# ti le man. Canh cua ban goc dung dung co do.
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not lua.open():
		print("KHONG mo duoc Lua: %s" % ", ".join(lua.errors))
		quit(1)
		return
	var san := Control.new()
	san.size = lua.cua_so_engine
	lua.set_stage(san)
	lua.set_touch_root(san)
	root.add_child(san)
	# bind_layout dat `_root` cho Lua — do la duong de doan Lua voi toi cay that,
	# va phai co cay that thi AnimationPlayer moi ap track.
	lua.bind_layout(san)
	lua.set_ui_root(san)
	if lua.run(_BOOT, "boot") == null:
		print("boot hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	if lua.run(_LUA_DUNG, "dung armature") == null:
		print("dung armature hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	# Cho AnimationPlayer that su ap track. Duong PHUONG THUC cua no khong chay
	# khi goi seek()/advance() — da mac bay nay mot lan (xem CLAUDE.md, muc "Dom
	# xanh o Main"), nen phai de khung that chay qua.
	for _i in range(4):
		await process_frame

	var r = lua.run(_LUA_DOC, "doc diem gan")
	if r == null:
		print("   doan Lua hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	var phan := (r as String).split(";")
	if phan.size() != 6:
		print("   ket qua la: %s" % r)
		quit(1)
		return

	# --- A: vi tri tung xuong so voi file ----------------------------------
	# In tieu de o day chu khong phai luc dung rig: phai cho khung chay qua thi
	# AnimationPlayer moi ap track, nen ca hai phan deu do sau buoc cho.
	print("\nA. SngRig.plug() — tra dung xuong theo SO trong ten:")
	for i in PLUG.size():
		var m := _rig_a.plug(PLUG[i])
		if m == null:
			_ghi_chu(false, "plug(%d) khong tim thay xuong nao" % PLUG[i])
			continue
		var lech := (m.position - (goc[ten[PLUG[i]]] as Vector2)).length()
		_ghi_chu(lech < LECH, "plug(%d) -> %s, vi tri %s, lech %.3f px so voi file"
				% [PLUG[i], m.name, m.position, lech])

	# --- B: _lua_getPlugInPositionInNode, do bang HIEU hai diem gan ---------
	# Tra ve o he COCOS cua cha (y huong LEN), con file ghi o he xuong (y huong
	# XUONG, giong Godot — SngRig.FLIP_Y = false). Nen hieu hai diem gan doc ra
	# phai bang hieu trong file voi truc y DAO DAU. Hieu so khong dinh gi toi
	# chieu cao cha hay diem neo, nen phep do nay sach.
	print("\nB. Ba ham Lua cua lop gia lap:")
	var g6: Vector2 = goc[ten[6]]
	var p6 := (phan[2] as String).split(",")
	for i in PLUG.size():
		if PLUG[i] == 6:
			continue
		var p := (phan[i] as String).split(",")
		var doc := Vector2(p[0].to_float() - p6[0].to_float(),
				p[1].to_float() - p6[1].to_float())
		var mong := goc[ten[PLUG[i]]] as Vector2
		var doi := Vector2(mong.x - g6.x, -(mong.y - g6.y))
		_ghi_chu((doc - doi).length() < LECH,
				"plug %d so voi plug 6: doc ra %s, file noi %s" % [PLUG[i], doc, doi])

	# --- B: _lua_addChildToPlugIn ------------------------------------------
	var con_pos := (phan[4] as String).split(",")
	var doc_con := Vector2(con_pos[0].to_float(), con_pos[1].to_float())
	var mong_con := Vector2(CON_X, CON_Y)
	_ghi_chu((doc_con - mong_con).length() < LECH,
			"con dat (%s) roi gan vao plug 4 -> getPosition() = %s (doi y nguyen)"
			% [mong_con, doc_con])
	_ghi_chu((phan[5] as String) == "true",
			"con dang nam duoi plug 4 (doc ra %s, doi true)" % phan[5])

	# Kiem doc lap ben GDScript, khong qua Lua: con phai nam DUNG goc cua diem
	# gan, lech di mot doan bang so nguoi goi viet, doi qua he cua chinh diem gan.
	var rig_b := _tim_rig(san)
	if rig_b == null:
		_ghi_chu(false, "khong tim thay rig trong cay de do vi tri con")
	else:
		var plug4 := rig_b.plug(4)
		var con: Node = null
		if plug4 != null and plug4.get_child_count() > 0:
			con = plug4.get_child(0)
		if con == null:
			_ghi_chu(false, "plug 4 khong co con nao")
		else:
			var them := Vector2(CON_X - CON_AX * CON_W, -CON_Y - (1.0 - CON_AY) * CON_H)
			var lech: float = (con.global_position - (plug4.global_position + them)).length()
			_ghi_chu(lech < LECH,
					"con toan cuc %s = goc diem gan %s + %s, lech %.3f px"
					% [con.global_position, plug4.global_position, them, lech])

	# --- B: go ra ----------------------------------------------------------
	var r2 = lua.run(_LUA_XOA, "go diem gan")
	if r2 == null:
		print("   doan Lua hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	var xoa := (r2 as String).split(";")
	if xoa.size() != 2:
		print("   ket qua la: %s" % r2)
		quit(1)
		return
	_ghi_chu((xoa[0] as String) == "false",
			"sau _lua_clearPlugIn(4) con khong con cha (doc ra %s, doi false)" % xoa[0])
	_ghi_chu((xoa[1] as String) == "0.00,0.00",
			"plug 99 (khong co that) tra %s, doi 0.00,0.00 va khong nem loi" % xoa[1])

	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)
