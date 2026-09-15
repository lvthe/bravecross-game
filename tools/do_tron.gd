# Vat lieu cua node CHA co truyen xuong Sprite2D con khong?
#
#   godot --path . --script tools/do_tron.gd
#
# PHAI chay co trinh ve that (khong --headless): trinh ve gia tao khong dung
# `SubViewport` nen `get_texture()` tra ve null.
#
# Day la phep do da bat mot cai bay that: ban dau `SngRig` gan vat lieu CONG
# len node XUONG (Node2D), phep thu trong `verify.gd` van xanh vi no cung doc
# node xuong — ma anh Main khong doi mot diem anh nao. Doc diem anh that thi ra
# vat lieu cua node cha KHONG truyen xuong Sprite2D con trong Godot 4.
#
# Nen: do bang diem anh, khong bang thuoc tinh. Nen 0.235, anh xam 0.392 alpha
# 1: ve thuong ra 0.392, ve cong ra 0.235 + 0.392 = 0.627.
extends SceneTree

const NEN := 0.235
const ANH := 0.392


func _init() -> void:
	var dat := 0
	var hong := 0

	# 1. Khong vat lieu -> ve thuong.
	var c1: Color = await _do(false, false)
	var ok1: bool = absf(c1.r - ANH) < 0.01
	print("%s  khong vat lieu            -> %.4f (doi %.4f)"
			% ["dat  " if ok1 else "HONG ", c1.r, ANH])
	dat += 1 if ok1 else 0
	hong += 0 if ok1 else 1

	# 2. Vat lieu tren node CHA -> van ve thuong. Day la dieu bat ngo, va la
	#    ly do phai do thay vi tin vao tai lieu.
	var c2: Color = await _do(true, false)
	var ok2: bool = absf(c2.r - ANH) < 0.01
	print("%s  vat lieu o node CHA       -> %.4f (doi %.4f — KHONG truyen xuong)"
			% ["dat  " if ok2 else "HONG ", c2.r, ANH])
	dat += 1 if ok2 else 0
	hong += 0 if ok2 else 1

	# 3. Vat lieu tren chinh Sprite2D -> cong that.
	var c3: Color = await _do(false, true)
	var ok3: bool = absf(c3.r - (NEN + ANH)) < 0.01
	print("%s  vat lieu o chinh Sprite2D -> %.4f (doi %.4f)"
			% ["dat  " if ok3 else "HONG ", c3.r, NEN + ANH])
	dat += 1 if ok3 else 0
	hong += 0 if ok3 else 1

	print("\n===== dat %d, hong %d =====" % [dat, hong])
	quit(0 if hong == 0 else 1)


## Dung mot o 32x32: nen xam, mot anh xam 8x8 o (8,8), doc diem (12,12) — nam
## gon trong anh. `cha_co` dat vat lieu CONG len Node2D cha, `con_co` dat len
## chinh Sprite2D.
func _do(cha_co: bool, con_co: bool) -> Color:
	var vp := SubViewport.new()
	vp.size = Vector2i(32, 32)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var nen := ColorRect.new()
	nen.color = Color(NEN, NEN, NEN)
	nen.size = Vector2(32, 32)
	vp.add_child(nen)

	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(ANH, ANH, ANH, 1.0))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.position = Vector2(8, 8)

	if cha_co:
		var cha := Node2D.new()
		cha.material = _cong()
		vp.add_child(cha)
		cha.add_child(spr)
	else:
		vp.add_child(spr)
	if con_co:
		spr.material = _cong()

	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var c := vp.get_texture().get_image().get_pixel(12, 12)
	vp.queue_free()
	return c


func _cong() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
