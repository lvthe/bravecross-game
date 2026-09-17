# Do hai ham XUONG cua armature: `_lua_getBonePosInNode` va
# `_lua_getBoneRectInNode`.
#
#   godot --headless --path . --script tools/verify_xuong.gd
#
# Hai ham nay khac moi API con thieu khac o cho: cho goi chung KHONG im lang.
# `sc/user/UI/CUIHeroInfoFightSoulUI.lua:3098` (man gan MAT len DAU nhan vat) gac
# bang `if spHero._lua_getBonePosInNode ~= nil then` — ma `__index` cua lop gia lap
# tra ve mot ham cho MOI ten, nen phep gac ay luon dung; roi hai so tra ve la
# `nil` va `facePosX = headBoneX + offsetX` nem **loi Lua that**.
#
# Cai phai do la BON tang doc lap, khong phai "co tra ve so khong":
#
#   A. BAN GHI. `SngRig.diem_xuong` phai tra DUNG cap `+0x08` (`v2`, `v3`) cua
#      khoa 0 — doc lai tu chinh file `.json` bang GDScript o day, khong tin
#      `SngRig` tu bao.
#   B. MAY AO. Nam phep do `work/emu_xuong.py` muc (A)/(B)/(D), ghi thang so vao
#      day: `_lua_getBonePosInNode` tra `(v2, -v3)`, tuc cap trong file DAO DAU
#      truc y. Ca nam la nam so khac nhau, nen mot phep doi dau sai la lo ra ngay.
#   C. O CUA ANH. `hop_xuong` phai tinh lai duoc tu `rot`/`rot2`/`sx`/`sy` cua
#      chinh file va `sourceSize` cua ANH xuong dang ve — va bang `ho_cham()` khi
#      xuong la `Collision` (do tren ba rig: YuJin, Gashapon, Hoplite).
#   D. DUONG LUA. Dung armature that qua `getSpriteFromSpriteCatch` roi goi hai
#      ham, ke ca hai tham so: bo trong (ban goc tra thang cap da luu), truyen
#      node dich (doi khong gian), ten xuong khong co, va node khong phai rig.
#
# Phep do phan biet that la LUAT DOI KHONG GIAN, chu khong phai "ham chay duoc":
# doi node dich tu cocos `(-40, 7)` len `(100, 50)` thi ket qua phai doi dung
# `-(140, 43)` — may ao do duoc dung con so ay. Mot ban dung sai kieu "tra ve toa
# do toan cuc" thi hai lan tra ra HAI so khac nhau han, con mot ban quen doi dau
# truc y thi hieu ra `-(140, -43)`, tuc sai dau o dung mot truc.
extends SceneTree

## Nam phep do tren may ao (`work/emu_xuong.py`, ban goc chay trong Android):
## ten dem hoi `getSpriteFromSpriteCatch` -> (ten xuong, cap `_lua_getBonePosInNode`
## tra ve). Cap tra ve la `(v2, -v3)` cua ban ghi khung, tuc cap trong file DAO
## DAU truc y — doi chieu doc lap duoc bang cach doc chinh file (phan A lam viec do).
##
## O thu tu la xuong dem do HOP (khac xuong dem do DIEM voi YuJin): phep do diem
## tren may ao chon xuong nao cung duoc, nen YuJin do bang `Head` — no la xuong
## that cua nhan vat ay. Con phep do hop so `_lua_getBoneRectInNode` voi
## `_lua_CollisionSize` thi BUOC phai cung xuong `Collision`, neu khong la dem hai
## thu khac nhau ra so sanh (bai hoc vua mac: `Head` ra 114,7442 x 92,28953 con
## `Collision` ra 140,00547790527 x 179,98643493652).
const DO_XUONG := {
	"ZhangLiangBao": ["Collision", -88.0, 227.0, "Collision"],
	"ElephantSoldier": ["Collision", -103.0, 115.0, "Collision"],
	"YuJin": ["Head", 1.0, 127.0, "Collision"],
	"Gashapon": ["Collision", -132.0, 196.0, "Collision"],
	"Hoplite": ["Collision", -77.0, 162.0, "Collision"],
}

## Ba rig ma may ao do ca `_lua_getBoneRectInNode` lan `_lua_CollisionSize` va
## thay hai so BANG NHAU khi xuong la `Collision`.
const DO_HOP_BANG := ["YuJin", "Gashapon", "Hoplite"]

## Hai lan dat node dich, don vi COCOS, va hieu ma may ao do duoc. Phep do nay
## chot "day la doi khong gian kieu convertToNodeSpace voi ti le 1", chu khong
## phai "tra ve toa do toan cuc".
const DICH_TRUOC := Vector2(-40.0, 7.0)
const DICH_SAU := Vector2(100.0, 50.0)
const DICH_HIEU := Vector2(-140.0, -43.0)

## Do tren may ao khi dich LA ARMATURE: hieu chi con `-(137,255, 42,157)` — nho
## hon dung `1/1,02`, va `rect` ra `178,5 x 232,04899597168` = `175 x 227,5` nhan
## `1,02`. Ban dung KHONG nhan he so ay (xem chu thich dau `lua/cocos.lua`): khong
## biet 1,02 thuoc node nao, va ca `getScale` lan `setScale` deu giet ca tien
## trinh do nen khong do duoc chu so huu. In ra chu KHONG khang dinh.
const DO_AMATURE_HIEU := Vector2(-137.255, -42.157)
const DO_AMATURE_HOP := Vector2(178.5, 232.04899597168)

## Do dai dong tac cua phan A. Sai so rong hon cac phep kiem khac vi `hop_xuong`
## tinh tu so DA LAM TRON 4 chu so thap phan trong `.json`, ma `sx` co the len toi
## ~180: mot buoc lam tron la 5e-5 * 180 = 0,009 px.
const LECH_HOP := 1e-2

const _BOOT := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	boot.boot_goc()
	boot.init_config()
	g_CSceneManager.CurrentScene = 'Test'
	return true
"""

## Do nam xuong. Moi dong: ten | pos-nil | pos-self | rect-nil | collision |
## pos-ten-sai. `pos-self` truyen CHINH rig lam node dich — dung ca may ao da do,
## va khi ay chieu cao cha la 0 nen phai bang `pos-nil`.
const _LUA_DO := """
	local c = require('cocos')
	_G['_SAN'] = c.wrap(_root)
	local cha = c.new_node('layer')
	_SAN:addChild(cha)
	_G['_CHA'] = cha
	_G['_SP'] = {}
	local ra = {}
	local ds = {
		{'ZhangLiangBao','Collision','Collision'},
		{'ElephantSoldier','Collision','Collision'},
		{'YuJin','Head','Collision'},
		{'Gashapon','Collision','Collision'}, {'Hoplite','Collision','Collision'},
	}
	for _, m in ipairs(ds) do
		local sp = getSpriteFromSpriteCatch(m[1])
		cha:addChild(sp)
		_G['_SP'][m[1]] = sp
		local x1, y1 = sp:_lua_getBonePosInNode(m[2])
		local con = sp:getChildren()
		local rig = con[1]
		local x2, y2 = sp:_lua_getBonePosInNode(m[2], rig)
		local rx, ry = sp:_lua_getBoneRectInNode(m[3])
		local cx, cy = sp:_lua_CollisionSize()
		local zx, zy = sp:_lua_getBonePosInNode('KhongCoXuongNay')
		ra[#ra + 1] = string.format('%s|%.4f,%.4f|%.4f,%.4f|%.4f,%.4f|%.4f,%.4f|%.4f,%.4f',
			m[1], x1, y1, x2, y2, rx, ry, cx, cy, zx, zy)
	end
	local sp = _G['_SP']['ZhangLiangBao']
	-- Node dich la mot node Cocos THUONG: dat hai lan, xem ket qua doi bao nhieu.
	local dich = c.new_node('sprite')
	dich:setContentSize(40, 20)
	dich:setAnchorPoint(0.5, 0.5)
	cha:addChild(dich)
	_G['_DICH'] = dich
	dich:setPosition(-40, 7)
	local a1, b1 = sp:_lua_getBonePosInNode('Collision', dich)
	local e1, f1 = sp:_lua_getBoneRectInNode('Collision', dich)
	dich:setPosition(100, 50)
	local a2, b2 = sp:_lua_getBonePosInNode('Collision', dich)
	local e2, f2 = sp:_lua_getBoneRectInNode('Collision', dich)
	ra[#ra + 1] = string.format('DICH|%.4f,%.4f|%.4f,%.4f|%.4f,%.4f|%.4f,%.4f',
		a1, b1, a2, b2, e1, f1, e2, f2)
	-- Cung hai lan dat ay nhung dich LA ARMATURE, de in ra phan con lech 1,02.
	--
	-- Phai la mot armature KHAC: truyen chinh rig dang hoi lam dich thi phep nghich
	-- dao khu luon do doi cua chinh no va luon ra (0, 0) — do duoc, va do la loi cua
	-- phep do chu khong phai cua ban dung.
	--
	-- Dat cho armature bang THANG toa do Godot: duong `setPosition` cua lop gia lap
	-- doi node co `size` (de doi neo va lat truc y), ma node armature o day la
	-- `Node2D` khong co o — goi vao la loi `attempt to index local 'sz'`. Do doi thi
	-- KHONG can o: cocos `(-40, 7)` -> `(100, 50)` la `+140` theo x va `+43` theo y
	-- cocos, tuc `(140, -43)` trong he Godot (y huong xuong), y het moi node khac.
	local sp2 = getSpriteFromSpriteCatch('Hoplite')
	cha:addChild(sp2)
	local rig2 = sp2:getChildren()[1]
	local gd2 = c.raw(rig2)
	gd2.position = Vector2(0, 0)
	local g1, h1 = sp:_lua_getBonePosInNode('Collision', rig2)
	local i1, j1 = sp:_lua_getBoneRectInNode('Collision', rig2)
	gd2.position = Vector2(140, -43)
	local g2, h2 = sp:_lua_getBonePosInNode('Collision', rig2)
	local i2, j2 = sp:_lua_getBoneRectInNode('Collision', rig2)
	-- In hieu cua DIEM nhung in GIA TRI cua HOP: hop la mot KICH THUOC nen doi cho
	-- node dich khong doi no (da khang dinh o tren), cai doi khi dich la armature la
	-- chinh kich thuoc ay — may ao do 178,5 x 232,04899597168.
	ra[#ra + 1] = string.format('RIG|%.4f,%.4f|%.4f,%.4f|%.4f,%.4f',
		g2 - g1, h2 - h1, i2, j2, i1, j1)
	-- Node KHONG phai rig: im lang tra (0, 0), khong nem loi.
	local thuong = c.new_node('layer')
	cha:addChild(thuong)
	local nx, ny = thuong:_lua_getBonePosInNode('Collision')
	local mx, my = thuong:_lua_getBoneRectInNode('Collision')
	ra[#ra + 1] = string.format('THUONG|%.4f,%.4f|%.4f,%.4f', nx, ny, mx, my)
	return table.concat(ra, ';')
"""

var _dat := 0
var _hong := 0


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


## Khoa 0 cua xuong `ten` doc THANG tu file `.json` — duong doc lap voi `SngRig`.
## `{}` khi thieu (khong co file, khong co nhom trung ten, khong co xuong, khong
## co khoa nao, hoac ten anh khong co trong ca `spriteFiles` lan `sourceSize`).
func _trong_file(ten: String, xuong: String) -> Dictionary:
	var p := "res://assets_ref/%s/%s.json" % [ten, ten]
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var bang_anh := {}
	_gom_anh(d.get("parts", []), bang_anh)
	for g in d.get("groups", []):
		if String(g.get("variant", "")) != ten:
			continue
		for a in g.get("animations", []):
			for b in a.get("bones", []):
				if String(b.get("name", "")) != xuong:
					continue
				var ks: Array = b.get("keys", [])
				if ks.is_empty():
					return {}
				var k: Dictionary = ks[0]
				var ra := {
					"v2": float(k.get("v2", 0.0)), "v3": float(k.get("v3", 0.0)),
					"rot": float(k.get("rot", 0.0)), "rot2": float(k.get("rot2", 0.0)),
					"sx": float(k.get("sx", 1.0)), "sy": float(k.get("sy", 1.0)),
					"d": int(k.get("d", -1)), "anh": "", "w": 0.0, "h": 0.0,
				}
				var refs: Array = bang_anh.get(xuong, [])
				if ra["d"] >= 0 and ra["d"] < refs.size():
					ra["anh"] = String(refs[ra["d"]])
					var info = (d.get("spriteFiles", {}) as Dictionary).get(ra["anh"], null)
					if info is Dictionary and not (info as Dictionary).is_empty():
						ra["w"] = float(info.get("srcW", 0.0))
						ra["h"] = float(info.get("srcH", 0.0))
					else:
						# `spriteFiles[anh] = null` = sprite do khong cat duoc PNG
						# (o 0x0 trong atlas) — o CUA no van o ban do `sourceSize`.
						var ss: Array = (d.get("sourceSize", {}) as Dictionary).get(ra["anh"], [])
						if ss.size() >= 2:
							ra["w"] = float(ss[0])
							ra["h"] = float(ss[1])
				return ra
	return {}


## Bang LIEN KET XUONG -> ANH cua chinh file, di het cac bo phan LONG NHAU (bo
## phan cap cao chua bo phan con — `Hoplite_VampirE` chua `Collision`).
func _gom_anh(parts: Array, ra: Dictionary) -> void:
	for p in parts:
		var ten := String(p.get("name", ""))
		if not ra.has(ten):
			ra[ten] = p.get("sprites", [])
		_gom_anh(p.get("children", []), ra)


## Cong thuc doc lap: GDScript tu tinh, khong goi `ChamRef.tinh`.
func _tinh_hop(w: float, h: float, rot1: float, rot2: float, sx: float, sy: float) -> Vector2:
	var a1 := deg_to_rad(rot1)
	var a2 := deg_to_rad(rot2)
	var ww := w * sx
	var hh := h * sy
	return Vector2(ww * absf(cos(a1)) + hh * absf(sin(a1)),
			hh * absf(cos(a2)) + ww * absf(sin(a2)))


func _cap(s: String) -> Vector2:
	var p := s.split(",")
	if p.size() != 2:
		return Vector2(NAN, NAN)
	return Vector2(p[0].to_float(), p[1].to_float())


func _init() -> void:
	# --- A+B+C: tang SngRig, doi chieu voi chinh file ----------------------
	print("A. SngRig.doc xuong, doi chieu voi ban ghi trong file .json:")
	var nen := Node2D.new()
	root.add_child(nen)
	for ten in DO_XUONG:
		var muc: Array = DO_XUONG[ten]
		var xuong := String(muc[0])
		var f := _trong_file(ten, xuong)
		if f.is_empty():
			_ghi_chu(false, "%s: khong doc duoc khoa 0 cua xuong '%s' tu file" % [ten, xuong])
			continue
		var rig := SngRig.build("res://assets_ref/%s" % ten)
		if rig == null:
			_ghi_chu(false, "%s: SngRig.build tra ve null" % ten)
			continue
		nen.add_child(rig)

		var diem := rig.diem_xuong(xuong)
		_ghi_chu(diem == Vector2(f["v2"], f["v3"]),
				"%-16s diem_xuong('%s') = %s — file ghi (v2, v3) = (%s, %s)"
				% [ten, xuong, diem, f["v2"], f["v3"]])
		# Phep doi dau: ban goc tra `(v2, -v3)`. Hai so nay khac dau nhau nen mot
		# ban quen dao truc y se ra dung cap cua file va truot phep kiem nay.
		var do_may_ao := Vector2(float(muc[1]), float(muc[2]))
		_ghi_chu(Vector2(diem.x, -diem.y) == do_may_ao,
				"%-16s (v2, -v3) = %s — may ao do %s"
				% [ten, Vector2(diem.x, -diem.y), do_may_ao])
		_ghi_chu(rig.co_xuong(xuong) and not rig.co_xuong("KhongCoXuongNay"),
				"%-16s co_xuong('%s') = true, co_xuong(ten bia) = false" % [ten, xuong])
		_ghi_chu(rig.diem_xuong("KhongCoXuongNay") == Vector2.ZERO
				and rig.hop_xuong("KhongCoXuongNay") == Vector2.ZERO,
				"%-16s ten xuong khong co -> diem (0, 0) va hop (0, 0), khong nem loi" % ten)
		# `spriteFiles[anh] = null` voi anh `_res-44` (o 0x0 trong atlas): o CUA no
		# nam o ban do `sourceSize`. Thieu duong lui ay thi hop ra (0, 0) — bon
		# trong nam rig o day dung dung anh ay.
		_ghi_chu(rig.anh_xuong(xuong) != "" and rig.khung_xuong(xuong) != Vector2.ZERO,
				"%-16s anh_xuong('%s') = '%s', khung_xuong = %s (khac (0, 0))"
				% [ten, xuong, rig.anh_xuong(xuong), rig.khung_xuong(xuong)])

		# C: `hop_xuong` tinh lai tu chinh cac thanh phan cua file.
		var mong := _tinh_hop(f["w"], f["h"], f["rot"], f["rot2"], f["sx"], f["sy"])
		var hop := rig.hop_xuong(xuong)
		_ghi_chu((hop - mong).length() <= LECH_HOP,
				"%-16s hop_xuong = %s — tinh lai tu (w,h,rot,rot2,sx,sy) = %s (w,h = %s x %s)"
				% [ten, hop, mong, f["w"], f["h"]])
		# Va khi xuong la `Collision` thi phai bang `ho_cham()` — ba rig nay do tren
		# may ao thay hai so BANG NHAU. `ho_cham()` lay `(w, h)` tu `cham_ref.json`
		# con `hop_xuong` lay tu ban do `sourceSize` cua JSON rig, nen phep kiem nay
		# doi chieu HAI duong du lieu chu khong phai mot duong tinh hai lan.
		if DO_HOP_BANG.has(ten):
			var xuong_hop := String(muc[3])
			var hop_c := rig.hop_xuong(xuong_hop)
			_ghi_chu((hop_c - rig.ho_cham()).length() <= LECH_HOP,
					"%-16s hop_xuong('%s') = %s = ho_cham() = %s — may ao do bang nhau"
					% [ten, xuong_hop, hop_c, rig.ho_cham()])

	# --- D: duong Lua ------------------------------------------------------
	print("\nD. lua/cocos.lua — hai ham xuong:")
	var lua := LuaRuntime.new()
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
	lua.bind_layout(san)
	lua.set_ui_root(san)
	if lua.run(_BOOT, "boot") == null:
		print("boot hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	var r = lua.run(_LUA_DO, "do hai ham xuong")
	if r == null:
		print("   doan Lua hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	var dong := (r as String).split(";")
	var thay := {}
	var dong_dich := ""
	var dong_rig := ""
	var dong_thuong := ""
	for d in dong:
		var p := (d as String).split("|")
		if (p[0] as String) == "DICH":
			dong_dich = d
		elif (p[0] as String) == "RIG":
			dong_rig = d
		elif (p[0] as String) == "THUONG":
			dong_thuong = d
		else:
			thay[p[0]] = p

	for ten in DO_XUONG:
		var muc: Array = DO_XUONG[ten]
		var xuong := String(muc[0])
		var do_may_ao := Vector2(float(muc[1]), float(muc[2]))
		if not thay.has(ten):
			_ghi_chu(false, "%s: doan Lua khong tra ve dong nao" % ten)
			continue
		var p: Array = thay[ten]
		if p.size() != 6:
			_ghi_chu(false, "%s: dong tra ve co %d o, phai la 6" % [ten, p.size()])
			continue
		var pos_nil := _cap(p[1])
		var pos_self := _cap(p[2])
		var rect_nil := _cap(p[3])
		var cham := _cap(p[4])
		var ten_sai := _cap(p[5])
		_ghi_chu((pos_nil - do_may_ao).length() <= 1e-6,
				"%-16s _lua_getBonePosInNode('%s') = %s — may ao do %s"
				% [ten, xuong, pos_nil, do_may_ao])
		_ghi_chu((pos_self - do_may_ao).length() <= 1e-6,
				"%-16s  ... truyen chinh rig lam node dich = %s (may ao: pos-self == pos-nil)"
				% [ten, pos_self])
		var xuong_hop := String(muc[3])
		_ghi_chu((rect_nil - cham).length() <= LECH_HOP,
				"%-16s _lua_getBoneRectInNode('%s') = %s, _lua_CollisionSize() = %s"
				% [ten, xuong_hop, rect_nil, cham])
		_ghi_chu(ten_sai == Vector2.ZERO,
				"%-16s ten xuong khong co -> %s (may ao: (0, 0), khong nem loi)" % [ten, ten_sai])

	# LUAT DOI KHONG GIAN. Day la phep do phan biet that: mot ban tra toa do toan
	# cuc se ra hieu khac han, con mot ban quen dao truc y se sai dau o truc y.
	if dong_dich == "":
		_ghi_chu(false, "doan Lua khong tra ve dong DICH")
	else:
		var p := (dong_dich as String).split("|")
		var truoc := _cap(p[1])
		var sau := _cap(p[2])
		var hieu := sau - truoc
		_ghi_chu((hieu - DICH_HIEU).length() <= 1e-3,
				"node dich Cocos %s -> %s: ket qua doi %s — may ao do %s (hieu = -(dich sau - dich truoc))"
				% [DICH_TRUOC, DICH_SAU, hieu, DICH_HIEU])
		# Hop la mot KICH THUOC nen dich chi TRUOT thi no khong doi — cung so ma
		# may ao do duoc khi dich la node Cocos thuong (175 x 227,5 cua
		# ZhangLiangBao, dung bang `_lua_CollisionSize`).
		var h1 := _cap(p[3])
		var h2 := _cap(p[4])
		_ghi_chu((h2 - h1).length() <= 1e-3,
				"  hop voi dich la node Cocos thuong: %s roi %s — khong doi (dich chi truot)"
				% [h1, h2])
		if thay.has("ZhangLiangBao"):
			var cham_zlb := _cap((thay["ZhangLiangBao"] as Array)[4])
			_ghi_chu((h1 - cham_zlb).length() <= LECH_HOP,
					"  hop ay = %s = _lua_CollisionSize() cua ZhangLiangBao = %s — may ao do bang nhau"
					% [h1, cham_zlb])
		else:
			_ghi_chu(false, "  thieu dong cua ZhangLiangBao de doi chieu hop")

	if dong_rig == "":
		_ghi_chu(false, "doan Lua khong tra ve dong RIG")
	else:
		# KHONG khang dinh — in ra de nguoi doc thay. Chua biet chu so 1,02 thuoc node
		# nao: `getScale`/`setScale` tren may ao deu giet ca tien trinh do (pcall khong
		# bat duoc SIGSEGV cua ma native), nen khong do duoc.
		var q := (dong_rig as String).split("|")
		var hieu := _cap(q[1])
		var hop_am := _cap(q[2])
		var hop_thuong := _cap(q[3])
		print("   GHI CHU  dich LA ARMATURE: diem doi %s, may ao ra %s — ti le %s"
				% [hieu, DO_AMATURE_HIEU, hieu / DO_AMATURE_HIEU])
		print("            hop = %s, may ao ra %s — ti le %s (dich thuong: %s)"
				% [hop_am, DO_AMATURE_HOP, hop_am / DO_AMATURE_HOP, hop_thuong])
		print("            (hai ti le NGUOC CHIEU nhau, nen 1,02 khong phai mot ti le"
				+ " nam tren node dich; chu so huu CHUA RO — xem chu thich dau lua/cocos.lua)")

	if dong_thuong == "":
		_ghi_chu(false, "doan Lua khong tra ve dong THUONG")
	else:
		var p := (dong_thuong as String).split("|")
		_ghi_chu(_cap(p[1]) == Vector2.ZERO and _cap(p[2]) == Vector2.ZERO,
				"node khong phai rig -> pos %s, hop %s (phai la (0, 0)), khong nem loi"
				% [_cap(p[1]), _cap(p[2])])

	# Phep kiem "ham co that": ten khong co trong bang Node thi roi vao `__index`
	# va bi dem vao `M.missing` — khong mot loi nao.
	var miss := lua.missing()
	for ham in ["_lua_getBonePosInNode", "_lua_getBoneRectInNode"]:
		_ghi_chu(not miss.has(ham),
				"%s KHONG nam trong bo dem M.missing%s"
				% [ham, "" if not miss.has(ham) else " (=%d)" % miss[ham]])

	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)
