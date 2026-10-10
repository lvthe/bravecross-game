# Do thanh cong cu ben phai man Main BANG ANH: chup luc dang thu, bam nut mo,
# roi chup lai. Day la phep do nguoi dung nhin thay — "bam nut tren Main thi
# cac nut nen co hien ra ro khong" — chu khong phai mot con so trong log.
#
#   godot --path . --script tools/do_thanh_cong_cu.gd -- --ra=C:/tmp/tcc
#
# Ghi hai tep `<ra>-thu.png` va `<ra>-mo.png`. PHAI chay CO cua so (dung
# `--headless`): che do headless khong ve gi nen anh ra trong tron.
#
# Vi sao bam bang `touch_at` chu khong goi thang `SetToolBarStatus`: nut mo
# thanh cong cu di qua duong cham that cua ban goc (ten cham trong .xgg ->
# `onTouchEnd_<ten>` cua doi tuong nhan), va do moi la duong nguoi choi di.
# Goi thang ham thi bo qua dung cai phan dang nghi (thanh cong cu co nhan cu
# bam khong).
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0

## So khung cho sau cu bam: thanh truot 369 diem voi hieu ung 0.0004 s/diem
## (CUIMainMenuTool.lua:390) nen ~0,15 s, cho 60 khung la du va con thua.
const CHO := 60

var _san: Control
var _lua: LuaRuntime
var _ra := ""
## Anh nen (moi thu dang hien) de `_dem` so vao — lay ngay sau khi tam dung cay.
var _nen: Image


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ra="):
			_ra = a.substr(5)
	if _ra == "":
		print("thieu --ra=<tien to tep anh>")
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
		_lua.tick(KHUNG)

	var nut := _nut_mo()
	if nut == null:
		print("khong tim thay nut mo thanh cong cu")
		quit(1)
		return
	var truoc := _do()
	await _chup("%s-thu.png" % _ra)
	# Bam that: diem cham tinh tu tam node, doi qua `_bien_doi` dung nhu
	# tools/bam_that.gd dang lam.
	var p: Vector2 = LuaRuntime._bien_doi(nut) * (nut.size * 0.5)
	var an := _lua.touch_at("Begin", p)
	var nhan: Node = _lua._dang_cham
	_lua.touch_at("End", p)
	for i in CHO:
		_lua.tick(KHUNG)
	print("bam nut mo o %s -> %s" % [p.round(), _ten(nhan) if an else "KHONG AI NHAN"])
	print("  truoc: %s" % truoc)
	print("  sau  : %s" % _do())
	await _chup("%s-mo.png" % _ra)

	# Phan THANH CONG CU THUC SU HIEN ra man: chup ba anh lien nhau — co thanh,
	# an thanh, hien lai — roi so tung diem anh trong vung cot phai.
	#
	# Vi sao phai lam phep nay chu khong nhin anh: thanh da mo ra (do duoc o
	# tren), nhung trong anh chup thi phan duoi cua no bi vat the thanh pho che
	# khuat. An thanh di roi so lai thi biet CHINH XAC no dong gop bao nhieu
	# diem anh, va dong cuoi cung no con thay la dong nao — neu dong ay nam
	# TRONG long khung thanh chu khong phai mep duoi cua khung thi do la che
	# khuat, khong phai "het anh".
	#
	# Anh thu ba la phep TU KIEM: no phai giong het anh thu nhat. Lech thi giua
	# hai lan chup co hoat anh chay (may, nuoc, dom sang) va phep do mat luc.
	# Tam dung cay truoc ba anh nay: moi lan chup phai cho hai khung de ve xong,
	# ma may nuoc / dom sang / rig cua man Main chay theo khung Godot (khong phai
	# theo `tick` cua Lua), nen khong tam dung thi `a` so voi `c` da lech hang
	# nghin diem anh va phep do mat luc. Do duoc: KHONG tam dung, hai anh cung
	# trang thai lech 17.762 diem anh tren vung 960x500.
	paused = true
	var a := await _chup_anh("%s-a-co.png" % _ra)
	_nen = a
	_lua.run("lMainToolbarRight:setIsVisible(false)", "an thanh cong cu")
	var b := await _chup_anh("%s-b-an.png" % _ra)
	_lua.run("lMainToolbarRight:setIsVisible(true)", "hien thanh cong cu")
	var c := await _chup_anh("%s-c-hien.png" % _ra)
	_so(a, b, c)
	# Cau hoi con lai: VAY cai che no la node nao. Thu tung ung vien: an no di
	# roi so lai. Neu che that thi an no di se lam lo phan thanh cong cu bi che
	# (hieu so voi `a` nam NGAY TRONG long cac o icon), con neu khong che thi
	# hieu so ay bang 0 — va luc do khong phai "do la node kia", ma la ta chua
	# tim ra ai.
	await _an_va_chup("btnMainDen", a, "o Ma Dong")
	await _an_va_chup("g_MainUIScrollLayer", a, "ca lop thanh pho")
	# Cau hoi cuoi: trong DUNG trang thai dang ve ra anh nay, cay noi ai tren ai?
	# Phep do truoc (tools/do_ai_de.gd) goi thang `SetToolBarStatus(true)`, con o
	# day thanh cong cu duoc mo ra bang MOT CU CHAM that — va neu duong cham lam
	# xep lai anh em thi hai trang thai khac nhau, tuc ket luan "cay noi duoi ma
	# anh noi tren" chi la so sanh hai trang thai khac nhau. Nen phai vet ngay
	# tai day.
	_vet_diem(900, 110)
	_vet_diem(900, 280)
	# Thu an tung ung vien nam SAU thanh cong cu trong thu tu ve: neu ke che that
	# nam trong so nay thi an no di se doi diem anh ngay trong long o icon.
	await _an_node("lChattingUI", a, "lChattingUI")
	await _an_node("lGuideUI", a, "lGuideUI")
	await _an_node("UIRootLayer", a, "UIRootLayer")
	await _an_control_la()
	# Ai co z_index KHAC 0 trong ca cay? Day moi la thu pha thu tu ve: Godot xep
	# theo z_index HIEU DUNG trong CA canvas, khong theo tung nhanh — nen mot node
	# trong lop thanh pho mang z=1 se de len moi node z=0, ke ca thanh cong cu.
	_ds_z_khac_khong()
	# PHEP KIEM CHUNG NGUOC cho gia thuyet "z_index cua xuong armature ro ri len
	# tren UI": nang THANG `z_index` cua thanh cong cu len (khong dung
	# `setZOrder` — ham Lua do chi XEP LAI anh em, khong dat z_index, nen no
	# khong chung minh duoc gi ve z). Neu thanh cong cu hien ra tren vat che thi
	# thu pham dung la z_index — mot con so do duoc, khong phai mot loi ke.
	var goc := XggLayout.find_node(_san, "lMainToolbarRightButton")
	goc.z_index = 2000
	var z := await _chup_anh("%s-z-nang.png" % _ra)
	_lua.run("lMainToolbarRight:setIsVisible(false)", "an thanh cong cu (dang z cao)")
	var zan := await _chup_anh("%s-z-nang-an.png" % _ra)
	_lua.run("lMainToolbarRight:setIsVisible(true)", "hien lai")
	print("kiem chung nguoc — z cua thanh cong cu nang len, roi an no di:")
	_dem(z, zan, "z=2000")
	paused = false
	quit(0)


## An theo DUONG trong cay Godot (node khong co ten Lua, vd lop do ma Lua dung
## luc chay sinh ra) roi dem diem anh doi trong long tung o icon.
func _an_node(duong: String, nen: Image, nhan: String) -> void:
	var n := XggLayout.find_node(_san, duong)
	if n == null:
		print("  khong thay node %s" % duong)
		return
	(n as CanvasItem).visible = false
	var im := await _chup_anh("%s-%s.png" % [_ra, duong])
	(n as CanvasItem).visible = true
	_dem(nen, im, nhan)


## Moi `Control` ten `@Control@*` la lop do ma Lua sinh luc chay (khong co ten
## trong .xgg). An tung cai mot — day la cho dang nghi nhat: mot lop nhu the nam
## SAU thanh cong cu trong thu tu ve ma khong co ten nao de goi tu Lua.
func _an_control_la() -> void:
	for n in _moi_node(_san):
		# Bo chinh `_san`: an no la an ca man, phep dem mat het y nghia.
		if n == _san or not (n is Control) or not String(n.name).begins_with("@Control@"):
			continue
		(n as CanvasItem).visible = false
		print("  an %s (%s)" % [n.name, _hop_node(n)])
		var im := await _chup_anh("%s-%s.png" % [_ra, String(n.name).replace("@", "")])
		(n as CanvasItem).visible = true
		_dem(_nen, im, String(n.name))


## Dem diem anh doi trong long tung o icon so voi anh nen `nen`.
func _dem(nen: Image, im: Image, nhan: String) -> void:
	var L := XggLayout.find_node(_san, "lMainToolbarRight")
	var tong := 0
	for c in L.get_children():
		if not (c is Control) or not c.has_meta("tag"):
			continue
		var o := _hop(c)
		var dem := 0
		for y in range(maxi(0, int(o.position.y)), mini(VUNG.end.y, int(o.end.y))):
			for x in range(maxi(0, int(o.position.x)), mini(VUNG.end.x, int(o.end.x))):
				if _khac(nen, im, x, y, 12):
					dem += 1
		tong += dem
		print("     an %s: o tag=%s doi %d/%d diem anh"
				% [nhan, c.get_meta("tag"), dem, int(o.size.x * o.size.y)])
	print("  TONG khi an %s: %d diem anh doi trong cac o icon" % [nhan, tong])


## Vet thu tu VE quanh mot diem khung nhin, ngay trong trang thai dang chup.
func _vet_diem(x: int, y: int) -> void:
	print("thu tu ve tai (%d, %d) — node con o DAU danh sach la TREN CUNG:" % [x, y])
	var ds := []
	_vet(_san, Vector2(x, y), ds)
	for i in range(ds.size()):
		print("  %2d. %s" % [i, ds[i]])


func _vet(n: Node, p: Vector2, ra: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	for c in n.get_children():
		_vet(c, p, ra)
	if n != _san:
		# `has_point` cua Godot kem `assert` khi o am hoac khong huu han (co rig
		# dung sai o chia) — chan truoc, khong thi ca luot vet vo.
		var o := _hop_node(n).abs()
		if o.size.x > 0.0 and o.size.y > 0.0 and is_finite(o.position.x) \
				and is_finite(o.position.y) and o.has_point(p):
			var c := n as CanvasItem
			ra.append("%s [%s] z=%d Z=%d" % [_ten(n), n.get_class(), c.z_index, _z_hieu_dung(n)])


## O cua node tren khung nhin — CUNG luat voi tools/do_ai_de.gd (`_o_cua`).
func _hop_node(n: Node) -> Rect2:
	if n is Control:
		return (n as Control).get_global_rect()
	if n is Sprite2D:
		var s := n as Sprite2D
		if s.texture == null:
			return Rect2()
		var r := s.texture.get_size()
		var g := s.get_global_transform()
		var b := Rect2(g * (-r * 0.5), Vector2.ZERO)
		for c in [Vector2(r.x, -r.y) * 0.5, Vector2(-r.x, r.y) * 0.5, r * 0.5]:
			b = b.expand(g * c)
		return b
	return Rect2()


func _moi_node(n: Node) -> Array:
	var ra := [n]
	for c in n.get_children():
		ra.append_array(_moi_node(c))
	return ra


## Liet ke moi CanvasItem co z_index hieu dung khac 0, kem chuoi to tien — de
## biet z ay den tu chinh node hay tu mot to tien, va no thuoc nhanh nao.
func _ds_z_khac_khong() -> void:
	print("node co z_index hieu dung khac 0 (nguon pha thu tu ve cua cay):")
	var n := 0
	for m in _moi_node(_san):
		if not (m is CanvasItem):
			continue
		var Z := _z_hieu_dung(m)
		if Z == 0:
			continue
		n += 1
		if n <= 40:
			print("  %s [%s] z=%d Z=%d  %s" % [_ten(m), m.get_class(),
					(m as CanvasItem).z_index, Z, _duong(m)])
	print("  tong: %d node" % n)


## Duong to tien (ten + z_index tung cap) tu `_san` xuong node.
func _duong(n: Node) -> String:
	var ds := []
	var m := n
	while m != null and m != _san:
		ds.push_front("%s(z=%d)" % [_ten(m),
				(m as CanvasItem).z_index if m is CanvasItem else 0])
		m = m.get_parent()
	return " < ".join(ds)


## z_index HIEU DUNG (cong don to tien khi `z_as_relative` bat) — day moi la so
## Godot dem ra de xep thu tu ve, va NO khong biet gi ve "cay": mot Sprite2D cua
## rig mang z=5 se de len MOI node z=0 trong cung canvas, ke ca thanh cong cu.
func _z_hieu_dung(n: Node) -> int:
	var t := 0
	var m := n
	while m is CanvasItem:
		var c := m as CanvasItem
		if not c.z_as_relative:
			t = 0
		t += c.z_index
		m = m.get_parent()
	return t


## An mot node, chup, hien lai, roi dem diem anh khac voi `nen` trong long tung o
## icon (toa do khung nhin lay tu `_o_man`).
func _an_va_chup(ten: String, nen: Image, nhan: String) -> Image:
	_lua.run("%s:setIsVisible(false)" % ten, "an %s" % ten)
	var im := await _chup_anh("%s-%s.png" % [_ra, ten])
	_lua.run("%s:setIsVisible(true)" % ten, "hien %s" % ten)
	var L := XggLayout.find_node(_san, "lMainToolbarRight")
	for c in L.get_children():
		if not (c is Control) or not c.has_meta("tag"):
			continue
		var o := _hop(c)
		var dem := 0
		for y in range(maxi(0, int(o.position.y)), mini(VUNG.end.y, int(o.end.y))):
			for x in range(maxi(0, int(o.position.x)), mini(VUNG.end.x, int(o.end.x))):
				if _khac(nen, im, x, y, 12):
					dem += 1
		print("  an %s (%s): %d/%d diem anh doi trong o icon tag=%s hien=%s"
				% [ten, nhan, dem, int(o.size.x * o.size.y), c.get_meta("tag"), c.visible])
	return im


func _hop(c: Control) -> Rect2:
	var a: Vector2 = LuaRuntime._bien_doi(c) * Vector2.ZERO
	var b: Vector2 = LuaRuntime._bien_doi(c) * c.size
	return Rect2(Vector2(mini(a.x, b.x), mini(a.y, b.y)),
			Vector2(absf(b.x - a.x), absf(b.y - a.y)))


## Vung xet: ca man hinh, tu tren xuong duoi day khung thanh. Khung dai 560
## diem nen khi mo no keo tu y=-190,9 xuong y=369,1 (xem `_do()` va
## CUIMainMenuTool.lua:390) — lay 500 dong cho du.
const VUNG := Rect2i(0, 0, 960, 500)


func _so(a: Image, b: Image, c: Image) -> void:
	print("o man cua tung con (toa do khung nhin):")
	print("  %s" % _o_man())
	var n_ab := 0
	var n_ac := 0
	var thap_nhat := -1
	var trai := 99999
	var phai := -1
	var hang := {}
	for y in range(VUNG.position.y, VUNG.end.y):
		var dem := 0
		for x in range(VUNG.position.x, VUNG.end.x):
			if _khac(a, b, x, y, 12):
				dem += 1
			if _khac(a, c, x, y, 12):
				n_ac += 1
		if dem > 0:
			hang[y] = dem
		n_ab += dem
	for x in range(VUNG.position.x, VUNG.end.x):
		var co := false
		for y in range(VUNG.position.y, VUNG.end.y):
			if _khac(a, b, x, y, 12):
				co = true
				break
		if co:
			trai = mini(trai, x)
			phai = maxi(phai, x)
	var ds := hang.keys()
	ds.sort()
	for k in ds:
		thap_nhat = k
	print("thanh cong cu dong gop %d diem anh trong vung %s" % [n_ab, VUNG])
	print("  x: %d..%d   dong cuoi con thay: %d" % [trai, phai, thap_nhat])
	print("  nhieu giua hai lan chup CUNG trang thai (a so c): %d diem anh" % n_ac)
	var vai := []
	for k in ds:
		if k % 10 == 0 or k == ds[ds.size() - 1]:
			vai.append("%d:%d" % [k, hang[k]])
	print("  so diem doi theo tung dong (moi 10 dong): %s" % ", ".join(vai))


## O cua thanh cong cu va cua tung con tren man — de doi chieu voi vet diem anh
## do duoc: con nao nam TRONG long khung ma vet diem anh khong toi do thi con ay
## dang bi che.
func _o_man() -> String:
	var L := XggLayout.find_node(_san, "lMainToolbarRight")
	if L == null:
		return "?"
	var ra := ["khung %s o=%s" % [_o(L), L.size]]
	for c in L.get_children():
		if c is Control and c.has_meta("tag"):
			ra.append("tag=%s %s o=%s hien=%s" % [c.get_meta("tag"), _o(c), c.size, c.visible])
	return " | ".join(ra)


func _o(c: Control) -> String:
	var a: Vector2 = LuaRuntime._bien_doi(c) * Vector2.ZERO
	var b: Vector2 = LuaRuntime._bien_doi(c) * c.size
	return "(x %d..%d, y %d..%d)" % [mini(a.x, b.x), maxi(a.x, b.x), mini(a.y, b.y), maxi(a.y, b.y)]


## Khac nhau qua nguong `q` o BAT KY kenh nao — de bo qua nhieu nen.
func _khac(a: Image, b: Image, x: int, y: int, q: int) -> bool:
	var p := a.get_pixel(x, y)
	var r := b.get_pixel(x, y)
	return absf(p.r - r.r) * 255.0 > q or absf(p.g - r.g) * 255.0 > q \
			or absf(p.b - r.b) * 255.0 > q


func _chup_anh(duong: String) -> Image:
	await _chup(duong)
	return get_root().get_texture().get_image()


## Nut mo thanh cong cu: con mang tag 1 cua `lMainToolbarRightButton` (tag do
## tu may ao — work/tags_cay.json, duong `lMainToolbarRightButton/4`).
func _nut_mo() -> Control:
	var goc := XggLayout.find_node(_san, "lMainToolbarRightButton")
	if goc == null:
		return null
	for c in goc.get_children():
		if c is Control and c.has_meta("tag") and int(c.get_meta("tag")) == 1:
			return c
	return null


## Trang thai de doi chieu bang so, khong chi bang mat: vi tri tam nen, do dai
## truot ma ban goc tinh ra, va nam icon co dang hien khong.
func _do() -> String:
	var r = _lua.run("""
		local L = lMainToolbarRight
		local x, y = L:getPosition()
		local hien = {}
		for i = 1, 5 do
			local c = L:getChildByTag(i)
			if c ~= nil then
				hien[#hien + 1] = i .. '=' .. tostring(c:getIsVisible())
			end
		end
		return string.format('pos=(%s, %s) dai=%s icon[%s]',
			tostring(x), tostring(y),
			tostring(g_CUIMainMenuTool.nRightToolButtonSizeLengh),
			table.concat(hien, ' '))
	""", "do thanh cong cu")
	return "?" if r == null else str(r)


func _ten(n: Node) -> String:
	if n == null:
		return "null"
	return String(n.get_meta("xgg_name", n.get_meta("cls", n.name)))


func _chup(duong: String) -> void:
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(duong)
	print("  da chup %s (%dx%d)" % [duong, img.get_width(), img.get_height()])
