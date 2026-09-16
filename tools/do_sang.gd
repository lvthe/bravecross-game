# Hieu ung sang cua ban goc ra dung con so nao tren diem anh?
#
#   godot --path . --script tools/do_sang.gd
#
# PHAI chay CO trinh ve that (khong --headless): trinh ve gia khong dung
# `SubViewport` nen `get_texture()` tra ve null. Vi vay bo nay nam ngoai
# `check.py` — cung ly do voi `do_xam.gd` va `do_tron.gd`.
#
# NGUON SU THAT (doc tu libgame.so, khong suy doan — xem
# `brave-cross/work/shaderghep.py --bang`):
#
#   `setGlow(b)` goi `vfunc_0x158("ShaderPositionTextureColor_Glow")` khi bat,
#   va chuong trinh THUONG khi tat. Ten do tra ra chi so 2 trong bang 18 chuong
#   trinh, chi so 2 dung nguon manh `.rodata 0x7cccd4`:
#
#       float factor = 1.5;
#       vec4 texColor = texture2D(CC_Texture0, v_texCoord);
#       texColor[0] = texColor[0] * factor;   (va 1, 2)
#       gl_FragColor = v_fragmentColor * texColor;
#
# Ba tinh chat PHAI dung, va moi tinh chat duoi day deu duoc DO:
#
#   (1) rgb nhan 1,5 — anh thu (60,120,30) ra (90,180,45), dung 1,50 o ca ba
#       kenh. Kenh nao tran thi bi chan o 255: (100,200,50) ra (150,255,75) chu
#       khong phai (150,300,75).
#   (2) alpha KHONG nhan: than ham chi sua ba kenh 0/1/2, con `texColor[3]` giu
#       nguyen. Do duoc bang anh co alpha 128: ket qua LA MO dung bang mot nua,
#       khong phai dac.
#   (3) mau node VAN nhan vao (`v_fragmentColor` duoc dung that o day, khac
#       `setGray` — shader do khai bao roi bo khong).
#
# Phan A do LUAT CUA GODOT tren dung hai loai node ma vat lieu nay duoc gan vao
# (`TextureRect` = CCSprite/CCButton, `NinePatchRect` = CCScale9Sprite): than ham
# trong `ui/sang.gdshader` ngan hon nguyen van vi `COLOR` dau vao da la
# `anh x modulate`, nen gia dinh do phai duoc do chu khong duoc tin.
#
# Phan B di qua DUONG THAT cua game: node tao bang `_new_node` cua `LuaRuntime`,
# roi goi `setGlow` bang chinh ma Lua ban goc (`lua/cocos.lua`).
extends SceneTree

const SANG := preload("res://ui/sang.gd")

# Ba anh thu. ANH1 co kenh g TRAN de phep chan 255 lo ra; ANH2 khong kenh nao
# tran nen doi chieu duoc dung ti le 1,5; ANH3 co alpha 128 de do tinh chat (2).
const ANH1 := Color8(100, 200, 50, 255)     # 0.392, 0.784, 0.196
const ANH2 := Color8(60, 120, 30, 255)      # 0.235, 0.471, 0.118
const ANH3 := Color8(60, 120, 30, 128)
const NEN := 0.0                            # nen den, de phep tron la phep nhan

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


# ---------------------------------------------------------------- phan A
# Luat cua Godot, do bang mau thu (khong phai shader sang).
func _phan_a() -> void:
	print("--- A. luat cua Godot tren hai loai node co anh ---")

	var c1: Color = await _do_thu("sprite", ANH2, Color(0.5, 1, 1, 1))
	print("  A1  TextureRect,     COLOR = COLOR.r  -> %s" % _c(c1))
	_kl3("A1  TextureRect: `COLOR` dau vao = anh x modulate",
			absf(c1.r - ANH2.r * 0.5) < 0.01)

	var c2: Color = await _do_thu("scale9", ANH2, Color(0.5, 1, 1, 1))
	print("  A2  NinePatchRect,   COLOR = COLOR.r  -> %s" % _c(c2))
	_kl3("A2  NinePatchRect (CCScale9Sprite): cung vay — vat lieu gan len no duoc",
			absf(c2.r - ANH2.r * 0.5) < 0.01)

	var c3: Color = await _do_thu("sprite", ANH2, Color(0.5, 1, 1, 1),
			"COLOR = vec4(1.0, 0.0, 0.0, 1.0);")
	print("  A3  TextureRect,     dat COLOR=do     -> %s" % _c(c3))
	_kl3("A3  ghi COLOR khong bi nhan them lan nao nua (nen bo sung tru 1,5 la du)",
			c3.r > 0.99)
	print("")


# ---------------------------------------------------------------- phan B
func _phan_b() -> void:
	print("--- B. chuong trinh so 2, di qua duong Lua that ---")

	# B1: tat han (setGlow(false)) thi anh phai Y NGUYEN — day la phep doi chung
	# cho ca phan con lai: khong co no thi B2..B5 co the "dat" chi vi moi thu
	# khong co tac dung gi.
	var b1: Color = await _do_sang("sprite", ANH1, Color(1, 1, 1, 1), false)
	_kq("B1  setGlow(false)            -> anh goc", b1,
			Color(ANH1.r, ANH1.g, ANH1.b, b1.a), 0.01)

	var b2: Color = await _do_sang("sprite", ANH1, Color(1, 1, 1, 1), true)
	_kq("B2  setGlow(true), anh (100,200,50)  -> x1,5, kenh g bi chan",
			b2, Color(150.0 / 255.0, 255.0 / 255.0, 75.0 / 255.0, b2.a), 0.01)

	var b3: Color = await _do_sang("sprite", ANH2, Color(1, 1, 1, 1), true)
	_kq("B3  setGlow(true), anh (60,120,30)   -> dung 1,50 o ba kenh",
			b3, Color(90.0 / 255.0, 180.0 / 255.0, 45.0 / 255.0, b3.a), 0.01)

	# Tinh chat (3): mau node van nhan vao. modulate (0,5 / 1 / 1) -> moi kenh
	# nhan them 0,5 — khac han `setGray`, o do mau node bi BO.
	var b4: Color = await _do_sang("sprite", ANH2, Color(0.5, 1, 1, 1), true)
	_kq("B4  setGlow(true) + modulate 0,5 kenh r -> mau node VAN nhan",
			b4, Color(45.0 / 255.0, 180.0 / 255.0, 45.0 / 255.0, b4.a), 0.01)

	# Tinh chat (2): alpha lay tu ANH va KHONG nhan 1,5. Anh alpha 128 -> ket qua
	# mo dung bang 0,502 lan (nen den). Neu alpha cung bi nhan 1,5 thi 192 -> 255
	# va ket qua se DAc, tuc bang dung B3.
	var b5: Color = await _do_sang("sprite", ANH3, Color(1, 1, 1, 1), true)
	_kq("B5  setGlow(true), anh alpha 128    -> van MO (alpha khong nhan)",
			b5, Color(45.17 / 255.0, 90.35 / 255.0, 22.58 / 255.0, b5.a), 0.015)
	if b5.r > 0.3:
		print("HONG  B5 ra %s — alpha da bi nhan 1,5 (dac)!" % _c(b5))
		hong += 1
	else:
		print("dat   B5 khong dac (%.4f, cach B3 %.4f)"
				% [b5.r, absf(b5.r - b3.r)])
		dat += 1

	# Doi chung cho B5: cung anh alpha 128 nhung KHONG bat sang — duong alpha
	# phai giong het, neu khac thi B5 "dat" vi ly do khac.
	var b6: Color = await _do_sang("sprite", ANH3, Color(1, 1, 1, 1), false)
	_kq("B6  khong sang, anh alpha 128       -> doi chung cho B5",
			b6, Color(30.11 / 255.0, 60.23 / 255.0, 15.06 / 255.0, b6.a), 0.015)

	# CCScale9Sprite: cung chuong trinh, tren NinePatchRect.
	var b7: Color = await _do_sang("scale9", ANH2, Color(1, 1, 1, 1), true)
	_kq("B7  NinePatchRect + setGlow(true)   -> y het TextureRect",
			b7, Color(90.0 / 255.0, 180.0 / 255.0, 45.0 / 255.0, b7.a), 0.01)

	# Va khong duoc la shader XAM (doi chieu cheo hai hieu ung tren cung node).
	lua.state.globals["_N"] = lua._new_node("sprite")
	lua.run("N = require('cocos').wrap(_N); N:setGlow(true); N:setGray(false)", "sang roi tat")
	var n: Control = lua.state.globals["_N"]
	_kl3("B8  setGray(false) sau setGlow(true): go ca vat lieu sang",
			n.material == null)
	n.free()
	print("")


# ---------------------------------------------------------------- do diem anh

## Mot o 32x32: nen den, mot node 16x16 o (8,8), doc diem (12,12).
## `bat` = null thi khong gan vat lieu; true/false thi goi `setGlow` bang duong
## Lua that tren chinh node do.
func _do_sang(loai: String, anh: Color, modulate: Color, bat: Variant) -> Color:
	return await _do(loai, anh, modulate, null, bat)


## Nhu tren nhung gan mot vat lieu THU (`mau` = ma fragment) — dung cho phan A.
func _do_thu(loai: String, anh: Color, modulate: Color,
		ma: String = "COLOR = vec4(COLOR.r, 0.0, 0.0, 1.0);") -> Color:
	return await _do(loai, anh, modulate, _shader(ma), null)


func _do(loai: String, anh: Color, modulate: Color, mau: Material,
		bat: Variant) -> Color:
	var vp := SubViewport.new()
	vp.size = Vector2i(32, 32)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var nen := ColorRect.new()
	nen.color = Color(NEN, NEN, NEN)
	nen.size = Vector2(32, 32)
	vp.add_child(nen)

	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(anh)
	# Kieu Variant: `_new_node` tra ve `Control`, ma `texture`/`patch_margin_*`
	# chi co o hai lop con — khai bao kieu Control thi GDScript chan ngay luc dich.
	var node: Variant = lua._new_node(loai)
	node.texture = ImageTexture.create_from_image(img)
	node.size = Vector2(16, 16)
	node.position = Vector2(8, 8)
	node.modulate = modulate
	if loai == "scale9":
		# Cho giua duoc ve (draw_center), va le 2 px: doc diem (12,12) nam trong
		# vung giua nen mau o do la mau nao cung nhu nhau (anh thu mot mau).
		node.patch_margin_left = 2
		node.patch_margin_right = 2
		node.patch_margin_top = 2
		node.patch_margin_bottom = 2
	if mau != null:
		node.material = mau
	vp.add_child(node)

	if bat != null:
		lua.state.globals["_N"] = node
		lua.run("N = require('cocos').wrap(_N); N:setGlow(%s)"
				% ("true" if bat else "false"), "sang")

	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var c := vp.get_texture().get_image().get_pixel(12, 12)
	vp.queue_free()
	return c


func _shader(than: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n%s\n}\n" % than
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _c(c: Color) -> String:
	return "(%.4f, %.4f, %.4f, %.4f)" % [c.r, c.g, c.b, c.a]


## Phep kiem khong co so doi chieu (chi co ket luan).
func _kl3(ten: String, ok: bool) -> void:
	print("%s  %s" % ["dat  " if ok else "HONG ", ten])
	dat += 1 if ok else 0
	hong += 0 if ok else 1


func _kq(ten: String, ra: Color, doi: Color, dung: float) -> void:
	var lech: float = maxf(absf(ra.r - doi.r),
			maxf(absf(ra.g - doi.g), maxf(absf(ra.b - doi.b), absf(ra.a - doi.a))))
	var ok: bool = lech <= dung
	print("%s  %-58s %s  doi %s  lech %.4f"
			% ["dat  " if ok else "HONG ", ten, _c(ra), _c(doi), lech])
	dat += 1 if ok else 0
	hong += 0 if ok else 1
