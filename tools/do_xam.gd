# Ban goc lam xam mot node bang shader NAO, va Godot tai hien duoc dung den dau?
#
#   godot --path . --script tools/do_xam.gd
#
# PHAI chay CO trinh ve that (khong --headless): trinh ve gia khong dung
# `SubViewport` nen `get_texture()` tra ve null. Vi vay bo nay nam ngoai
# `check.py` (moi bo o do chay bang --headless) — cung ly do voi `do_tron.gd`.
#
# NGUON SU THAT (do tu libgame.so, khong suy doan — xem
# `brave-cross/work/shaderghep.py --bang`):
#
#   `setGray(b)` goi `vfunc_0x158("ShaderPositionTextureColor_Gray")`. Ten do
#   tra ra chi so 1 trong bang 18 chuong trinh, va chi so 1 dung nguon manh
#   `.rodata 0x7ccf00`:
#
#       varying vec4 v_fragmentColor;      // KHAI BAO NHUNG KHONG DUNG
#       varying vec2 v_texCoord;
#       uniform sampler2D CC_Texture0;
#       void main() {
#           float alpha = texture2D(CC_Texture0, v_texCoord).a;
#           float grey  = dot(texture2D(CC_Texture0, v_texCoord).rgb,
#                             vec3(0.299, 0.587, 0.114));
#           gl_FragColor = vec4(grey, grey, grey, alpha);
#       }
#
# Bon dieu rut ra tu chinh doan do, va moi dieu duoi day deu duoc DO:
#
#   (1) he so la Rec.601 (0.299/0.587/0.114), khong phai Rec.709
#       (0.2126/0.7152/0.0722 cua `ccPositionTexture_GrayScale_frag`).
#       Anh thu (100,200,50): Rec.601 ra 153, Rec.709 ra 168 — hai so khac han
#       nhau, nen mot phep kiem chat loai duoc cai sai.
#   (2) mau node (`v_fragmentColor`) BI BO: `setColor(255,0,0)` roi lam xam thi
#       ket qua VAN xam, khong he do.
#   (3) do mo cua node CUNG bi bo, vi alpha lay tu ANH (`texture2D(...).a`) chu
#       khong tu `v_fragmentColor.a`. `setOpacity(128)` roi lam xam thi ket qua
#       VAN dac.
#   (4) mau THUA KE tu node cha cung bi bo: nguon dinh N[8] (`0x7ca769`) chi co
#       `v_fragmentColor = a_color`, ma trong cocos2d-x `a_color` la mau HIEN
#       THI cua node — da gom san mau/do mo cua cha (`_displayedColor`).
#
# Bon dieu nay la quirks that cua ban goc, khong phai loi cua ban dung lai. Va
# chung KHOP SAN voi Godot, do duoc chu khong phai suy doan: `COLOR` dau vao cua
# fragment la `anh x modulate` (A2), va ket qua ghi ra KHONG bi nhan them lan nao
# nua (A1, A3). Nghia la ghi de `COLOR` la BO LUON ca `modulate` cua chinh node
# LAN cua cha — dung bang hanh vi tren. Vi vay shader duoi day bo thang vao duoc,
# khong phai bu tru gi.
extends SceneTree

# Anh thu: ba kenh khac nhau va khong kenh nao bang luma, de phep chieu len truc
# xam lo ra ca ba huong lech (kenh nao lon hon luma thi TOI di, nho hon thi SANG).
const ANH := Color8(100, 200, 50, 255)      # 0.392, 0.784, 0.196
const NEN := 0.0                            # nen den, de phep tron la phep nhan

# Luma cua ANH theo hai cong thuc, tinh san: 0.299*100+0.587*200+0.114*50 = 153
const XAM601 := 153.0 / 255.0               # 0.6000
const XAM709 := 167.91 / 255.0              # 0.6585 — cai PHAI KHONG ra

var dat := 0
var hong := 0


func _init() -> void:
	print("anh thu %s  nen %.2f\n" % [ANH, NEN])

	# ---------------------------------------------------------------- phan A
	# Luat cua Godot, do bang mau thu (khong phai shader xam): `COLOR` dau vao
	# bang gi, va ket qua co bi nhan them lan nao nua khong.
	print("--- A. luat cua Godot (mau thu, khong phai shader xam) ---")
	var c_a1: Color = await _do(_shader("COLOR = vec4(1.0, 0.0, 0.0, 1.0);"),
			Color(0.5, 1, 1, 1))
	print("  A1  dat COLOR=do tinh, modulate.r=0.5  -> %s" % _c(c_a1))
	var c_a2: Color = await _do(
			_shader("COLOR = vec4(COLOR.r, 0.0, 0.0, 1.0);"), Color(0.5, 1, 1, 1))
	print("  A2  COLOR = COLOR.r (doc lai dau vao)  -> %s" % _c(c_a2))
	var c_a3: Color = await _do(_shader("COLOR = vec4(1.0, 0.0, 0.0, 1.0);"),
			Color(1, 1, 1, 1))
	print("  A3  dat COLOR=do tinh, modulate=trang  -> %s" % _c(c_a3))
	# 1,00 nghia la hang so dat vao duoc giu nguyen; 0,50 la bi nhan them modulate.
	_kl3("A1  ghi COLOR  ->  ket qua KHONG bi nhan them voi modulate", c_a1.r > 0.99)
	_kl3("A2  `COLOR` dau vao = anh x modulate",
			absf(c_a2.r - ANH.r * 0.5) < 0.01)
	_kl3("A3  anh KHONG tu nhan vao ket qua cua fragment", c_a3.r > 0.99)

	# A4: modulate cua node CHA. Nguon dinh `v_fragmentColor = a_color` (N[8]
	# 0x7ca769) va trong cocos2d-x `a_color` da gom san mau hien thi cua cha
	# (`_displayedColor`), nen ban goc lam xam la BO LUON ca phan thua ke. Godot
	# cung gom modulate cua cha vao `COLOR` dau vao — do xem co giong khong.
	var c_a4: Color = await _do(_xam(), Color(1, 1, 1, 1), Color(0.5, 0.5, 0.5, 0.5))
	print("  A4  xam, node CHA modulate 0.5         -> %s" % _c(c_a4))
	_kl3("A4  bo luon ca mau thua ke tu node cha (0,60 chu khong 0,30)",
			absf(c_a4.r - XAM601) < 0.01)
	print("")

	# ---------------------------------------------------------------- phan B
	# Sau dieu PHAI dung: ba tinh chat (1) (2) (3) o dau file.
	print("--- B. ba tinh chat cua ban goc ---")

	# (1) Rec.601. Khong vat lieu, de doi chieu anh goc truoc da.
	var b1: Color = await _do(null, Color(1, 1, 1, 1))
	_kq("B1  khong xam, khong to        -> anh goc", b1,
			Color(ANH.r, ANH.g, ANH.b, 1.0), 0.01)

	var b2: Color = await _do(_xam(), Color(1, 1, 1, 1))
	_kq("B2  xam                       -> luma Rec.601", b2,
			Color(XAM601, XAM601, XAM601, 1.0), 0.01)

	# (2) mau node bi bo. Day la phep quyet dinh: neu mau node con tac dung thi
	# kenh g va b se tut ve 0.
	var b3: Color = await _do(_xam(), Color(1, 0, 0, 1))
	_kq("B3  xam + setColor(255,0,0)   -> VAN xam (bo mau node)", b3,
			Color(XAM601, XAM601, XAM601, 1.0), 0.01)

	# (3) do mo cua node bi bo. Neu do mo con tac dung thi ket qua nhan doi.
	var b4: Color = await _do(_xam(), Color(1, 1, 1, 0.5))
	_kq("B4  xam + setOpacity(128)     -> VAN dac (bo do mo)", b4,
			Color(XAM601, XAM601, XAM601, 1.0), 0.01)

	# Doi chung: khong xam thi mau va do mo VAN chay binh thuong. Thieu hai
	# phep nay thi B3/B4 co the "dat" chi vi ca hai deu khong co tac dung gi.
	var b5: Color = await _do(null, Color(1, 0, 0, 1))
	_kq("B5  khong xam + setColor do   -> do that", b5,
			Color(ANH.r, 0.0, 0.0, 1.0), 0.01)
	var b6: Color = await _do(null, Color(1, 1, 1, 0.5))
	_kq("B6  khong xam + setOpacity    -> mo that", b6,
			Color(ANH.r * 0.5, ANH.g * 0.5, ANH.b * 0.5, 1.0), 0.02)

	# Loai han cong thuc kia: neu ban dung dung Rec.709 thi B2 se ra 0.6585.
	if absf(b2.r - XAM709) < 0.02:
		print("HONG  B2 ra luma Rec.709 (%.4f) — SAI cong thuc" % b2.r)
		hong += 1
	else:
		print("dat   B2 khong phai Rec.709 (%.4f cach xa %.4f)"
				% [absf(b2.r - XAM709), XAM709])
		dat += 1

	print("\n===== dat %d, hong %d =====" % [dat, hong])
	quit(0 if hong == 0 else 1)


## Mot o 32x32: nen `NEN`, mot anh 8x8 o (8,8) trong mot node cha, doc diem (12,12).
## Anh luon nam trong node cha (du `cha` la trang) de moi phep do di cung mot
## duong — neu khong thi A4 do duong khac cac phep kia va ket qua khong so duoc.
func _do(mau: Material, modulate: Color, cha := Color(1, 1, 1, 1)) -> Color:
	var vp := SubViewport.new()
	vp.size = Vector2i(32, 32)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var nen := ColorRect.new()
	nen.color = Color(NEN, NEN, NEN)
	nen.size = Vector2(32, 32)
	vp.add_child(nen)

	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(ANH)
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.position = Vector2(8, 8)
	spr.modulate = modulate
	if mau != null:
		spr.material = mau
	var me := Node2D.new()
	me.modulate = cha
	me.add_child(spr)
	vp.add_child(me)

	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var c := vp.get_texture().get_image().get_pixel(12, 12)
	vp.queue_free()
	return c


func _xam() -> ShaderMaterial:
	return _shader("""
	vec4 t = texture(TEXTURE, UV);
	float g = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(g, g, g, t.a);
	""")


func _shader(than: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n%s\n}\n" % than
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _c(c: Color) -> String:
	return "(%.4f, %.4f, %.4f, %.4f)" % [c.r, c.g, c.b, c.a]


func _kl(ok: bool) -> String:
	return "dung" if ok else "KHAC"


## Phep kiem khong co so doi chieu (dung cho phan A, chi co ket luan).
func _kl3(ten: String, ok: bool) -> void:
	print("%s  %s" % ["dat  " if ok else "HONG ", ten])
	dat += 1 if ok else 0
	hong += 0 if ok else 1


func _kq(ten: String, ra: Color, doi: Color, dung: float) -> void:
	var lech: float = maxf(absf(ra.r - doi.r),
			maxf(absf(ra.g - doi.g), maxf(absf(ra.b - doi.b), absf(ra.a - doi.a))))
	var ok: bool = lech <= dung
	print("%s  %-42s %s  doi %s  lech %.4f"
			% ["dat  " if ok else "HONG ", ten, _c(ra), _c(doi), lech])
	dat += 1 if ok else 0
	hong += 0 if ok else 1
