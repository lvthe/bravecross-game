# Chuyen sac chu cua ban goc ra dung con so nao tren diem anh?
#
#   godot --path . --script tools/do_chuyen_sac.gd
#
# PHAI chay CO trinh ve that (khong --headless): trinh ve gia khong dung
# `SubViewport` nen `get_texture()` tra ve null. Vi vay bo nay nam ngoai
# `check.py` — cung ly do voi `do_xam.gd` / `do_sang.gd` / `do_tron.gd`.
#
# NGUON SU THAT (doc tu libgame.so, khong suy doan — xem
# `brave-cross/work/shaderghep.py --bang` va `--nguon 11`):
#
#   chuong trinh so 8, ten `ShaderLabel_Gradual`, nguon manh `.rodata 0x7cbcac`:
#
#       float a = abs(v_texCoord.y - v_coordYRange.x) / abs(v_coordYRange.y - v_coordYRange.x);
#       resultColor.rgb = v_colorBegin.rgb*a + v_colorEnd.rgb*(1-a);
#       resultColor.a = texColor.a;
#       gl_FragColor = v_fragmentColor*resultColor;
#
# Bon dieu PHAI dung, moi dieu duoi day deu duoc DO chu khong phai doc ma suy ra:
#
#   (1) `a` chay theo chieu DOC cua CHINH O NODE (khong phai toa do khung ve,
#       khong phai UV cua atlas chu), va `a = 0` o DAU o. Do bang cach doi chieu
#       tung diem anh voi cong thuc tai CHINH y cuc bo cua no, voi node nam lech
#       cho (8,8) — va bang mot luot chup nua o cho lech them 16 diem anh: dai
#       phai Y NGUYEN.
#   (2) `mau_cuoi` la mau o DAU o, `mau_dau` la mau o CUOI o — nen kenh do TANG
#       dan theo y khi dau la do va cuoi la xanh. Do bang hai dau mut.
#   (3) `v_fragmentColor` nhan vao CA rgb lan alpha: `setColor` doi mau dai,
#       `setOpacity` doi do dam, va do phu cua net chu khong bi doi.
#   (4) `chieu_cao` dung la mau so, va no theo o khi o doi.
#
# Cach do: khong dung nen (viewport trong suot), nen diem anh doc ra la
# `(mau * do_phu, do_phu)` — chia kenh rgb cho alpha la ra DUNG mau cua dai, ke
# ca o diem anh vien (noi do phu < 1). Nho vay do duoc ca bon dieu tren cung mot
# luot chup, khong phai chup hai lan.
extends SceneTree

const CS := preload("res://ui/chuyen_sac.gd")

const O := 80                                   # o viewport (phai du cao cho luot chup lech cho)
const LECH := Vector2(8, 8)                     # node nam lech cho, khong o goc
const LECH_XA := 16.0                           # luot chup thu hai lech them chung nay
const CO_CHU := 40                              # co chu, du lon de net chu ro
const SAI_SO := 0.02                            # luong tu 8 bit chia cho do phu
const DO_PHU := 0.9                             # chi lay diem anh gan dac

var dat := 0
var hong := 0
var lua: LuaRuntime


func _init() -> void:
	lua = LuaRuntime.new()
	if not lua.open():
		print("KHONG mo duoc Lua: %s" % ", ".join(lua.errors))
		quit(1)
		return
	lua.run("local c = require('cocos'); require('bootstrap').install_cocos()", "cai")

	await _phan_a()
	await _phan_b()

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	print("\n===== dat %d, hong %d =====" % [dat, hong])
	quit(0 if hong == 0 else 1)


# ------------------------------------------------------- A. cong thuc

func _phan_a() -> void:
	print("--- A. cong thuc cua dai (nhan that, node lech cho) ---")
	var a := await _chup("M", Color8(255, 0, 0), Color8(0, 0, 255), Color(1, 1, 1))
	var cao: float = a["cao"]
	var o: Image = a["anh"]
	print("  nhan: o cao %.1f diem anh, lech %.0f,%.0f" % [cao, LECH.x, LECH.y])
	# Co toi thieu cua nhan chi dung sau khi node vao cay (xem `_chup`), nen day
	# cung la phep kiem buoc cho do.
	t("o chu duoc dat dung co that (khong phai so cu truoc khi vao cay)",
			cao >= 30.0, "o cao %.1f" % cao)

	var hang := _hang_dac(o)
	if hang.is_empty():
		print("HONG  khong co diem anh nao duoc ve — font hay shader co van de")
		hong += 1
		return
	print("  hang co net chu: %d..%d (trong %d hang)" % [hang[0], hang[-1], o.get_height()])
	t("co net chu duoc ve", hang.size() >= 4, "chi %d hang" % hang.size())
	# Net chu phai NAM TRONG o cua no — tran ra ngoai la dau hieu o bi dat sai co.
	t("net chu nam gon trong o cua nhan (dau o = %.0f)"
			% LECH.y, LECH.y <= hang[0] and hang[-1] < LECH.y + cao,
			"hang %d..%d, o %d..%d" % [hang[0], hang[-1], LECH.y, LECH.y + cao])
	# Va khong duoc cham mep KHUNG VE: bi cat bot thi so hang tut xuong va phep
	# kiem (5) ben duoi bao "net chu doi hinh" — mot loi o PHEP DO, khong phai o
	# code, va rat kho doan ra. Do duoc mot lan: khung 64 voi buoc lech 16 lam
	# net chu tran ra ngoai, 29 hang con 26.
	t("net chu khong cham mep khung ve", hang[0] > 0 and hang[-1] < o.get_height() - 1,
			"hang %d..%d trong khung %d" % [hang[0], hang[-1], o.get_height()])

	# (1) Tung diem anh phai khop cong thuc tai CHINH y cuc bo cua no.
	var khop := 0
	var lech_nhat := 0.0
	var lech_y := -1
	for y in hang:
		var m := _tai(o, y)
		if m.is_empty():
			continue
		var doi := Color8(0, 0, 255).lerp(Color8(255, 0, 0), (float(y) - LECH.y) / cao)
		var lech: float = maxf(absf(m["mau"].r - doi.r), maxf(absf(m["mau"].g - doi.g),
				absf(m["mau"].b - doi.b)))
		if lech <= SAI_SO:
			khop += 1
		elif lech > lech_nhat:
			lech_nhat = lech
			lech_y = y
	t("moi hang khop cong thuc a = y_CUC_BO / chieu_cao (ke ca node lech cho)",
			khop == hang.size(), "%d/%d hang, lech nhat %.4f o hang %d"
			% [khop, hang.size(), lech_nhat, lech_y])

	# (2) Chieu: kenh do tang dan theo y (dau = do nam DUOI, cuoi = xanh nam TREN).
	var tren := _tai(o, hang[0])
	var duoi := _tai(o, hang[-1])
	if not tren.is_empty() and not duoi.is_empty():
		print("  hang %d (tren): %s" % [hang[0], _c(tren["mau"])])
		print("  hang %d (duoi): %s" % [hang[-1], _c(duoi["mau"])])
		t("dau o (do) nam DUOI, cuoi o (xanh) nam TREN",
				duoi["mau"].r > tren["mau"].r + 0.3 and tren["mau"].b > duoi["mau"].b + 0.3)

	# (3) Do phu cua net chu khong bi dai ghi de: vien chu phai co alpha < 1.
	var vien := 0
	for y in o.get_height():
		for x in o.get_width():
			var c := o.get_pixel(x, y)
			if c.a > 0.02 and c.a < DO_PHU:
				vien += 1
	t("vien chu van mo (alpha < 1), dai khong de len do phu", vien > 0,
			"%d diem anh vien" % vien)

	# (4) `chieu_cao` dung la mau so: doi tham so di 2 lan thi dai gian ra dung 2
	# lan. Day la phep kiem cho phan NOI DAY (tham so nap tu `UiChuyenSac`), va no
	# bat duoc loi "lay nham chieu cao cua o khac".
	var b := await _chup("M", Color8(255, 0, 0), Color8(0, 0, 255), Color(1, 1, 1), 2.0)
	var ob: Image = b["anh"]
	var hang_b := _hang_dac(ob)
	var khop_b := 0
	var lech_b := 0.0
	for y in hang:
		var m2 := _tai(ob, y)
		if m2.is_empty():
			continue
		# Cung y, nhung mau so gap doi -> a nho di mot nua.
		var doi2 := Color8(0, 0, 255).lerp(Color8(255, 0, 0),
				(float(y) - LECH.y) / (cao * 2.0))
		var l2: float = maxf(absf(m2["mau"].r - doi2.r), maxf(absf(m2["mau"].g - doi2.g),
				absf(m2["mau"].b - doi2.b)))
		if l2 <= SAI_SO:
			khop_b += 1
		else:
			lech_b = maxf(lech_b, l2)
	t("chieu_cao gap doi: dai gian ra dung gap doi (mau so la tham so do)",
			khop_b == hang.size(), "%d/%d hang, lech nhat %.4f (o cao van %.1f)"
			% [khop_b, hang.size(), lech_b, float(b["cao"])])

	# (5) Dai KHONG duoc lech theo cho node dung. Cung mot nhan, doi cho di 16
	# diem anh: net chu doi cho y nguyen (cung so hang, lech dung 16) va mau o
	# cung mot HANG CUC BO phai khong doi.
	#
	# Day la phep kiem bat dung cai bay da mac mot lan: `VERTEX` doc trong
	# `fragment()` cua Godot 4.7 la toa do KHUNG VE chu khong phai toa do node,
	# nen luc do dai lech dung bang cho node dung. Do duoc truoc khi sua: lech
	# nhat 1,1807 tren hang 47 (doi 8 diem anh la ra 0,15 sai). Khong co phep
	# kiem nay thi loi do chi hien ra o lan dau tien co node nhan khong nam o goc
	# khung ve — tuc la o man hinh that, khong phai o day.
	var xa := await _chup("M", Color8(255, 0, 0), Color8(0, 0, 255), Color(1, 1, 1),
			1.0, LECH + Vector2(0, LECH_XA))
	var hang_xa := _hang_dac(xa["anh"])
	if hang_xa.size() != hang.size():
		t("doi cho node 16 diem anh: net chu khong doi hinh", false,
				"%d hang so voi %d" % [hang_xa.size(), hang.size()])
	else:
		var mx := _tai(xa["anh"], hang_xa[0])
		var mc := _tai(o, hang[0])
		print("  hang dau cua net chu: %d -> %d, mau %s -> %s"
				% [hang[0], hang_xa[0], _c(mc["mau"]), _c(mx["mau"])])
		t("doi cho node 16 diem anh: net chu doi dung 16, dai Y NGUYEN "
				+ "(a tinh trong O node, khong phai khung ve)",
				hang_xa[0] - hang[0] == int(LECH_XA)
				and absf(mx["mau"].r - mc["mau"].r) <= SAI_SO
				and absf(mx["mau"].b - mc["mau"].b) <= SAI_SO,
				"hang %d -> %d" % [hang[0], hang_xa[0]])
	print("")


# ------------------------------------------------------- B. mau node

func _phan_b() -> void:
	print("--- B. mau node nhan vao dai (v_fragmentColor) ---")

	var chuan := await _chup("M", Color8(255, 0, 0), Color8(0, 0, 255), Color(1, 1, 1))
	var o: Image = chuan["anh"]
	var hang := _hang_dac(o)
	if hang.is_empty():
		print("HONG  khong co net chu — bo qua phan B")
		hong += 1
		return
	var y: int = hang[hang.size() / 2]
	var g0 := _tai(o, y)

	# setColor: kenh r nhan 0,5 thi ca dai nhan 0,5; hai kenh kia khong doi.
	var to := await _chup("M", Color8(255, 0, 0), Color8(0, 0, 255), Color(0.5, 1, 1))
	var g1 := _tai(to["anh"], y)
	if g0.is_empty() or g1.is_empty():
		t("setColor: do duoc diem anh (o giua net chu)", false, "khong tim thay diem dac")
	else:
		print("  modulate (0,5 / 1 / 1): r %.4f -> %.4f, g %.4f -> %.4f"
				% [g0["mau"].r, g1["mau"].r, g0["mau"].g, g1["mau"].g])
		t("setColor: kenh r cua dai nhan 0,5",
				absf(g1["mau"].r - g0["mau"].r * 0.5) <= SAI_SO)
		t("setColor: kenh g khong doi", absf(g1["mau"].g - g0["mau"].g) <= SAI_SO)

	# setOpacity: do dam nhan 0,5, con mau (rgb/alpha) khong doi.
	#
	# Doc dung DIEM ANH cua luot chuan chu khong di tim diem dac: do phu luc nay
	# nho nhat la 0,5 nen nguong "gan dac" khong con dung duoc. (Ban dau bo nay di
	# tim diem dac o luot nay, khong thay gi, va IM LANG bo qua ca hai phep kiem —
	# nen gio khong con duong nao de lot.)
	var mo := await _chup("M", Color8(255, 0, 0), Color8(0, 0, 255), Color(1, 1, 1, 0.5))
	var g2 := _doc(mo["anh"], g0["x"], y)
	if g0.is_empty() or g2.is_empty():
		t("setOpacity: do duoc diem anh", false, "diem anh tat han")
	else:
		print("  modulate.a 0,5: alpha %.4f -> %.4f, r %.4f -> %.4f"
				% [g0["a"], g2["a"], g0["mau"].r, g2["mau"].r])
		t("setOpacity: do dam nhan 0,5", absf(g2["a"] - g0["a"] * 0.5) <= SAI_SO)
		t("setOpacity: mau cua dai khong doi",
				absf(g2["mau"].r - g0["mau"].r) <= SAI_SO
				and absf(g2["mau"].b - g0["mau"].b) <= SAI_SO)

	# Hai node hai dai khac nhau: vat lieu la CUA TUNG NODE, nen khong the lay
	# nham cua nhau (neu dung chung mot vat lieu thi cho nay lat nguoc).
	var lat := await _chup("M", Color8(0, 0, 255), Color8(255, 0, 0), Color(1, 1, 1))
	var g3 := _tai(lat["anh"], y)
	if g0.is_empty() or g3.is_empty():
		t("doi cho hai dau dai: do duoc diem anh", false, "khong tim thay diem dac")
	else:
		print("  doi cho hai mau: r %.4f -> %.4f, b %.4f -> %.4f"
				% [g0["mau"].r, g3["mau"].r, g0["mau"].b, g3["mau"].b])
		t("doi cho hai dau dai: dai lat nguoc dung nhu vay",
				absf(g3["mau"].r - g0["mau"].b) <= SAI_SO
				and absf(g3["mau"].b - g0["mau"].r) <= SAI_SO)

	# Node khong bat chuyen sac: chu phai ve mau THUONG (trang) — phep doi chung
	# cho ca phan tren, thieu no thi "dat" co the chi vi moi thu deu bi doi mau.
	var khong := await _chup("M", Color8(255, 0, 0), Color8(0, 0, 255), Color(1, 1, 1), 0.0)
	var g4 := _tai(khong["anh"], y)
	if g4.is_empty():
		t("khong bat chuyen sac: do duoc diem anh", false, "khong tim thay diem dac")
	else:
		print("  khong bat: %s" % _c(g4["mau"]))
		t("khong bat chuyen sac: chu ve mau thuong (trang), khong co dai",
				g4["mau"].r > 0.98 and g4["mau"].g > 0.98 and g4["mau"].b > 0.98)
	print("")


# ------------------------------------------------------- chup

## Chup mot nhan mot chu voi dai chuyen sac.
##
## `nhan_so` la he so nhan vao `chieu_cao` SAU khi `enableGradual` dat no — dung
## de kiem chinh cai mau so do (1,0 = dung nhu luc chay; 2,0 = gian dai ra gap
## doi; 0,0 = KHONG bat chuyen sac, de doi chung).
##
## THU TU O DAY LA CO Y, va no phai nhu vay: `Control.get_minimum_size()` cua
## nhan chi dung sau khi node THAT SU nam trong cay. Do duoc: lan tao nhan dau
## tien trong tien trinh, `get_minimum_size()` tra 23 diem anh (font mac dinh
## chua nap) trong khi luc ve, co chu 40 ra khoi chu 55 diem anh — nhan bi dat o
## 23 nen net chu TRAN RA NGOAI o, va phep do nao dua vao co o cung sai theo. Qua
## mot khung roi moi doc lai thi dung, va `resized` ban ra nen `chieu_cao` trong
## shader cung theo kip.
func _chup(chu: String, dau: Color, cuoi: Color, modulate: Color,
		nhan_so := 1.0, lech := LECH) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(O, O)
	vp.transparent_bg = true          # nen trong suot: xem dau file, muc "cach do"
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var node: Variant = lua._new_node("label")
	node.add_theme_font_size_override("font_size", CO_CHU)
	node.text = chu
	node.modulate = modulate
	node.position = lech
	vp.add_child(node)
	await process_frame
	node.size = node.get_minimum_size()
	await process_frame

	var r: Dictionary = {"cao": node.size.y}
	if nhan_so > 0.0:
		lua.state.globals["_N"] = node
		lua.run("N = require('cocos').wrap(_N); N:enableGradual(%d, %d, %d, %d, %d, %d)"
				% [_255(dau.r), _255(dau.g), _255(dau.b),
					_255(cuoi.r), _255(cuoi.g), _255(cuoi.b)], "chuyen sac")
		var m := node.material as ShaderMaterial
		if m == null:
			print("HONG  node khong mang vat lieu chuyen sac (%s)" % str(node.material))
			hong += 1
		elif not is_equal_approx(nhan_so, 1.0):
			# Ghi thang tham so: phep kiem (4) o phan A do mau so nay, va no phai
			# doi duoc tu ngoai chu khong bi khoa cung trong shader. Dat SAU khi o
			# da on dinh, khong thi hook `resized` ghi de mat.
			m.set_shader_parameter("chieu_cao", r["cao"] * nhan_so)

	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img = Image.create_from_data(img.get_width(), img.get_height(), false,
			img.get_format(), img.get_data())     # ban sao, vi viewport sap bi xoa
	vp.queue_free()
	r["anh"] = img
	return r


func _255(v: float) -> int:
	return int(round(v * 255.0))


# ------------------------------------------------------- doc diem anh

## Cac hang co it nhat mot diem anh gan dac.
func _hang_dac(o: Image) -> Array:
	var ra: Array = []
	for y in o.get_height():
		for x in o.get_width():
			if o.get_pixel(x, y).a >= DO_PHU:
				ra.append(y)
				break
	return ra


## Diem anh DUNG NHAT trong hang `y`: mau cua DAI (rgb chia alpha) va do phu.
func _tai(o: Image, y: int) -> Dictionary:
	var x_max := -1
	var a_max := 0.0
	for x in o.get_width():
		var a := o.get_pixel(x, y).a
		if a > a_max:
			a_max = a
			x_max = x
	if x_max < 0 or a_max < DO_PHU:
		return {}
	return _doc(o, x_max, y)


## Mau cua dai tai mot diem anh: `(mau * do_phu, do_phu)` chia nguoc lai.
func _doc(o: Image, x: int, y: int) -> Dictionary:
	var c := o.get_pixel(x, y)
	if c.a <= 0.004:
		return {}
	return {"mau": Color(c.r / c.a, c.g / c.a, c.b / c.a), "a": c.a, "x": x, "y": y}


func _c(c: Color) -> String:
	return "(%.4f, %.4f, %.4f)" % [c.r, c.g, c.b]


## Phep kiem khong co so doi chieu (chi co ket luan).
func t(ten: String, ok: bool, note: String = "") -> void:
	print("%s  %s%s" % ["dat  " if ok else "HONG ", ten,
			("  (%s)" % note) if note else ""])
	dat += 1 if ok else 0
	hong += 0 if ok else 1
