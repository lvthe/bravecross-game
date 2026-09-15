# Lop cuon CCScrollLayer (lua/cuon.lua) — do tren canh Main THAT.
#
#   godot --headless --path . --script tools/verify_cuon.gd
#
# Do cai gi: g_MainUIScrollLayer la CCScrollLayer 1366x768 chua mot
# CCParallaxNode 2300x768 dat o x = -100 (doc thang tu
# layout_ref/UI_Main_960_640.json). Keo lop do phai doi cho lop con dung bang
# quang duong ngon tay, phai bi kep lai o bien, phai nha ve bien khi
# setIsElastic(true), va phai dua duoc btnMainEvilCastle (x = 1583,90 trong
# khong gian lop — NGOAI khung 1152) vao trong khung. Cuoi cung: mot cu BAM
# (khong di chuyen) van phai den duoc ham cham cua node, con mot lan KEO thi
# khong — neu khong thi vua cuon vua mo man.
#
# Con so bien duoc TINH LAI DOC LAP trong file nay tu chinh kich thuoc doc ra
# tu cay Godot, chu khong lay hang so cua lua/cuon.lua — hai ben tinh khac
# duong ma phai ra cung so.
extends SceneTree

const VM := preload("res://tools/vao_main.gd")

const LE := -50.0        # g_MainUIScrollLayer:setMarginSpace(-50) — CUIMain.lua:153
const KHUNG := 1152.0    # be rong san khau o 960x640 (768 * 960/640)

var ok := 0
var bad := 0
var lua: LuaRuntime
var san: Control


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


func _init() -> void:
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	var cua_so := Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	lua = LuaRuntime.new()
	lua.cua_so_engine = cua_so
	if not lua.open():
		t("mo Lua", false, ", ".join(lua.errors))
		_ket()
		return
	XggLayout.respect_visible = true
	san = Control.new()
	san.size = cua_so
	san.scale = Vector2.ONE * (vp.y / cua_so.y)
	lua.set_stage(san)
	lua.set_touch_root(san)

	if lua.run(VM._NAP, "nap") == null:
		t("nap game", false, ", ".join(lua.errors))
		_ket()
		return
	var d := VM.chay(lua)
	if d["dung"] != "":
		t("chuoi Login -> Main", false, str(d["dung"]))
		_ket()
		return
	t("chuoi Login -> Main", true)
	# Hop thoai CHO ("lCommonLoadingDialog", ten cham ClickBackground) con nam
	# de man vai chuc khung dau — do duoc: o khung 0 no la node TREN CUNG duoi
	# ngon tay, tu khung 30 tro di khong con. Trong luc no con thi moi cu cham
	# deu bi no nuot, dung nhu ban goc. Phai cho no tan roi moi do cuon.
	_tick(40)

	var lop := _tim(san, "g_MainUIScrollLayer")
	if lop == null:
		t("thay g_MainUIScrollLayer", false)
		_ket()
		return
	t("thay g_MainUIScrollLayer", true)
	_do(lop)

	_ket()


func _ket() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _tim(goc: Node, ten: String) -> Node:
	var ds: Array = [goc]
	while not ds.is_empty():
		var n: Node = ds.pop_back()
		if String(n.get_meta("xgg_name", "")) == ten:
			return n
		for c in n.get_children():
			ds.append(c)
	return null


## Diem cham (toa do canvas) cua mot diem trong khong gian Cocos cua san khau.
func _p(cx: float, cy: float) -> Vector2:
	return LuaRuntime._bien_doi(san) * Vector2(cx, san.size.y - cy)


func _cham(pha: String, p: Vector2) -> void:
	lua.touch_at(pha, p)


## Do lech dang ap, doc tu trong Lua (khong doc bien cua ta). Tra ve mot SO
## chu khong tra bang: gia tri Lua tra ve GDScript khong phai Array that.
func _lech() -> float:
	var r = lua.run("""
		local o = g_MainUIScrollLayer:getContentOffset()
		if math.abs(o.x) > 0.001 then return o.x end
		return o.y
	""", "do lech")
	if r == null:
		return NAN
	return float(str(r))


## Nhat ky ham cham da goi, doc tu lua/cocos.lua.
func _nhat_ky() -> String:
	return str(lua.run("return table.concat(require('cocos').nhat_ky_cham, '|')", "nhat ky"))


func _xoa_nhat_ky() -> void:
	lua.run("require('cocos').nhat_ky_cham = {} return true", "xoa nhat ky")


## Co mot ham onTouchEnd_ nao do duoc goi khong. KHONG doi hoi dung lop cuon:
## node nhan cham la node TREN CUNG duoi ngon tay, co the la mot nha.
func _co_end() -> bool:
	return _nhat_ky().contains("onTouchEnd_")


## Mot lan keo: Begin tai (x0,y0) roi Move/End tung quang `buoc` px.
func _keo(x0: float, y0: float, buoc: float, so_buoc: int = 4) -> void:
	_cham("Begin", _p(x0, y0))
	for i in range(1, so_buoc + 1):
		_cham("Move", _p(x0 + buoc * i / so_buoc, y0))
	_cham("End", _p(x0 + buoc, y0))


## Tam cua mot node trong khong gian Cocos cua san khau (goc duoi-trai, y len).
## Goc cua node trong Godot la goc TREN-trai, nen phai doi chieu y.
func _tam_cocos(n: Control) -> Vector2:
	var g := LuaRuntime._bien_doi(n) * Vector2.ZERO
	var x := g.x / san.scale.x
	var y := san.size.y - g.y / san.scale.y
	return Vector2(x + n.size.x * 0.5, y - n.size.y * 0.5)


## Cac node nhan cham duoc duoi mot diem trong khong gian Cocos cua san khau.
func _ung_vien(cx: float, cy: float) -> Array:
	var p := LuaRuntime._bien_doi(san) * Vector2(cx, san.size.y - cy)
	var ds: Array = []
	lua._ung_vien(san, p, ds)
	return ds


func _co_ung_vien(p: Vector2, nut: Node) -> bool:
	var id := nut.get_instance_id()
	for n in _ung_vien(p.x, p.y):
		if n.get_instance_id() == id:
			return true
	return false


func _ten_ung_vien(p: Vector2) -> String:
	var ten: Array = []
	for n in _ung_vien(p.x, p.y):
		ten.append("%s[%s]" % [n.get_meta("touch", "?"), n.get_meta("xgg_name", n.name)])
	return ", ".join(ten)


func _do(lop: Node) -> void:
	# 1. Hinh dang — doc thang tu .xgg, khong lay tu lua/cuon.lua.
	t("lop la Control", lop is Control)
	t("lop 1366x768", lop.size == Vector2(1366, 768), str(lop.size))
	t("lop co 1 con", lop.get_child_count() == 1, str(lop.get_child_count()))
	if lop.get_child_count() != 1:
		return
	var content := lop.get_child(0) as Control
	t("con la CCParallaxNode 2300x768",
			content != null
			and String(content.get_meta("type_name", "")) == "CCParallaxNode"
			and content.size == Vector2(2300, 768),
			"%s %s" % [content.get_meta("type_name", "?") if content != null else "?",
					content.size if content != null else "?"])
	if content == null:
		return
	var x_goc: float = content.position.x
	print("  content: cocos=%s godot=%s" % [content.get_meta("cocos", "?"), content.position])

	# 2. Lop cuon da duoc dang ky: getContentOffset chi co o lua/cuon.lua.
	var off := _lech()
	t("getContentOffset doc duoc (lop cuon da dang ky)", not is_nan(off), str(off))
	t("luc dau chua lech", is_equal_approx(off, 0.0), str(off))

	# 3. Keo 200 px sang trai -> noi dung doi dung 200 px.
	_keo(600, 200, -200.0)
	off = _lech()
	t("keo -200 thi lech = -200", absf(off + 200.0) < 0.5, str(off))
	t("noi dung doi dung 200 px",
			absf(content.position.x - (x_goc - 200.0)) < 0.5, str(content.position.x))

	# 4. resetContentLayerPos -> ve cho goc.
	lua.run("g_MainUIScrollLayer:resetContentLayerPos() return true", "reset")
	off = _lech()
	t("resetContentLayerPos ve 0", is_equal_approx(off, 0.0), str(off))
	t("noi dung ve cho goc", absf(content.position.x - x_goc) < 0.5, str(content.position.x))

	# 5. Bien duoc TINH LAI DOC LAP tu kich thuoc doc ra tu cay Godot.
	#    lech = 0 la goc; keo xa nhat ve phia truoc khi mep sau noi dung cham
	#    mep lop (le tru 50 px, tuc phai lui vao 50):
	#        biên_thấp = W - (x_goc + rộng) - LẼ
	var bien := 1366.0 - (x_goc + content.size.x) - LE
	print("  bien tinh doc lap: %.1f" % bien)

	# 6. Nut nha: truoc khi cuon phai NGOAI khung, sau khi cuon het phai TRONG
	#    — va phai BAM DUOC, do bang chinh bo loc cham cua engine.
	var nut := _tim(lop, "btnMainEvilCastle")
	if nut == null:
		t("thay btnMainEvilCastle", false)
	else:
		var tam := _tam_cocos(nut as Control)
		# Ngoai khung = khong co diem man hinh nao o do, nen khong the cham toi
		# du bo loc cham (bo loc KHONG cat theo khung — no chi cat theo o cua
		# node va clip_contents). Vi vay phep kiem "luc dau" la: tam nam NGOAI
		# be rong san khau, VA diem cham duoc cuoi cung ben phai cung cung khong
		# toi duoc no.
		var mep := Vector2(san.size.x - 1.0, tam.y)
		t("btnMainEvilCastle ngoai khung luc dau", tam.x > KHUNG,
				"tam=%.1f khung=%.0f" % [tam.x, KHUNG])
		t("luc dau cham sat mep phai cung KHONG toi duoc nha", not _co_ung_vien(mep, nut),
				_ten_ung_vien(mep))

		_tick(2)
		_keo(600, 200, -2000.0)
		_tick(20)   # 12 khung nha ve = 0.2 giay, cho du
		off = _lech()
		t("kep vao bien", absf(off - bien) < 0.5, "lech=%s bien=%.1f" % [off, bien])
		var tam_sau := _tam_cocos(nut as Control)
		print("  btnMainEvilCastle: tam truoc=%.1f, sau=%.1f (lech %.1f)" % [
				tam.x, tam_sau.x, tam_sau.x - tam.x])
		t("btnMainEvilCastle vao trong khung", tam_sau.x < KHUNG and tam_sau.x > 0.0,
				"tam=%.1f" % tam_sau.x)
		t("sau khi cuon thi BAM duoc vao nha", _co_ung_vien(tam_sau, nut),
				_ten_ung_vien(tam_sau))

	# 7. Bam thi phai co nguoi nhan End; keo thi KHONG AI nhan End.
	#    Node nhan cham la node TREN CUNG duoi ngon tay (co the la mot nha chu
	#    khong phai lop cuon), nen phep kiem hoi "co ai nhan End khong", khong
	#    hoi "co dung lop cuon khong".
	lua.run("g_MainUIScrollLayer:resetContentLayerPos() return true", "reset")
	_xoa_nhat_ky()
	_cham("Begin", _p(600, 200))
	_cham("End", _p(600, 200))
	var nk_bam := _nhat_ky()
	t("bam khong di chuyen -> co node nhan End", _co_end(), nk_bam)
	t("bam -> khong cuon", is_equal_approx(_lech(), 0.0), str(_lech()))

	_xoa_nhat_ky()
	_cham("Begin", _p(600, 200))
	_cham("Move", _p(500, 200))
	_cham("Move", _p(400, 200))
	_cham("End", _p(400, 200))
	var nk_keo := _nhat_ky()
	t("keo qua nguong -> KHONG ai nhan End", not _co_end(), nk_keo)
	t("keo van cuon", absf(_lech() + 200.0) < 0.5, str(_lech()))

	# 8. Keo duoi nguong thi van la mot cu bam.
	lua.run("g_MainUIScrollLayer:resetContentLayerPos() return true", "reset")
	_xoa_nhat_ky()
	_cham("Begin", _p(600, 200))
	_cham("Move", _p(594, 200))
	_cham("End", _p(594, 200))
	t("keo 6 px (duoi nguong 12) van la cu bam", _co_end(), _nhat_ky())
	t("keo 6 px khong cuon", is_equal_approx(_lech(), 0.0), str(_lech()))

	# 9. Lop cuon tat (enableScroll(false)) thi khong cuon.
	_tick(2)
	lua.run("g_MainUIScrollLayer:resetContentLayerPos() return true", "reset")
	lua.run("g_MainUIScrollLayer:enableScroll(false) return true", "tat cuon")
	_keo(600, 200, -200.0)
	t("enableScroll(false) thi khong cuon", is_equal_approx(_lech(), 0.0), str(_lech()))
	lua.run("g_MainUIScrollLayer:enableScroll(true) return true", "bat cuon")

	print("  loi Lua: %d" % lua.errors.size())
	for e in lua.errors.slice(0, 6):
		print("     %s" % str(e).substr(0, 220))


func _tick(n: int) -> void:
	for i in range(n):
		lua.tick(1.0 / 60.0)
