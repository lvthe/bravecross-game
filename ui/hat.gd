## He hat cua ban goc (CCParticleSystemQuad) ve bang GPUParticles2D cua Godot.
##
## Du lieu: `brave-cross/work/hatref.py` xuat 33 dinh nghia `.plist` cua ban goc
## ra `hat_ref/*.json` (giu nguyen moi khoa cua plist, ke ca khoa ta chua dung).
## O day chi DICH tu khoa sang tham so Godot: moi dong duoi day truy ve mot so
## do — hoac mot khoa trong `.plist`, hoac mot lenh trong shader hat cua Godot
## 4.7.2. Chuoi shader do nam nguyen trong `Godot_v4.7.2-stable_win64.exe`
## (vung ~0x7309000-0x730c400); so dia chi ghi theo do.
##
##   var n := HatNode.tao("../map/beachfiresmall.plist")   # theo truong 'res'
##
## Bon cho Cocos va Godot lam KHAC nhau, va cach khop:
##
##   1. THOI GIAN SONG. Cocos rut hai phia, [L-v, L+v]. Godot rut MOT phia:
##      `params.lifetime = (1.0 - lifetime_randomness * rand)` (0x730b0e), tuc
##      song trong [T*(1-r), T]. Dat T = L+v va r = 2v/(L+v) thi khop DUNG; khi
##      v >= L thi r chan o 1, ra [0, L+v] — cung la dai CO HIEU LUC cua Cocos,
##      vi hat song am coi nhu chet ngay. Do cheo: `process_orbit_displacement`
##      nhan `params.lifetime * LIFETIME` lam tong thoi gian song, tuc LIFETIME
##      la nen va params.lifetime la he so rut.
##   2. HUONG. Cocos do goc nguoc chieu kim dong ho tu +x, y huong LEN; Godot y
##      huong XUONG -> lat dau goc. Cung luat ma ui/xgg_layout.gd dung cho 'rot'.
##   3. TRUC Y CUA LUC. `force = gravity` (0x730be92) roi `USERDATA1.xyz +=
##      force * DELTA` — gravity cua Godot la gia toc pixel/giay^2, cung thu
##      nguyen voi gravityx/gravityy -> lat dau gravityy.
##   4. HE TOA DO. He hat cua Cocos chay trong he CUA NODE (ca dam hat dich
##      theo node), nen local_coords = true. Chinh vi vay ma
##      `CPublic:playButtonParticleSystem` cho hat bay theo action cua nut duoc
##      (CPublic.lua:1730: setIsVisible(true) + resetSystem() + runAction).
##
## Con node nay la mot Control de bo cuc dung duoc nguyen ven (size, neo, cham,
## meta, tag), ben trong la mot GPUParticles2D dat tai GOC CUA NODE COCOS.
class_name HatNode
extends Control

const INDEX_PATH := "res://hat_ref/index.json"
const DIR := "res://hat_ref/"

## Khoa dinh nghia -> {"json": ten tep, "texture": khoa anh}.
static var _idx: Dictionary = {}
## Khoa dinh nghia -> noi dung JSON (nap mot lan).
static var _dinh_nghia: Dictionary = {}
static var _nap_xong := false
## Canh bao chi mot lan cho moi thu thieu, de khong lam ngap nhat ky.
static var _da_bao: Dictionary = {}

## Con ve that. Null khi khong co dinh nghia hoac khong co anh.
var hat: GPUParticles2D = null


static func _nap() -> void:
	if _nap_xong:
		return
	_nap_xong = true
	if not FileAccess.file_exists(INDEX_PATH):
		push_warning("HatNode: khong co %s — he hat se khong ve gi" % INDEX_PATH)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if d is Dictionary:
		_idx = d


## Khoa dinh nghia tu truong 'res' cua bo cuc.
##
## Bo cuc ghi duong dan TUONG DOI voi thu muc conf ('../map/beachfiresmall.plist'),
## va hatref.py dat khoa la duong dan trong assets/ bo duoi — nen chi viec bo
## '../' va duoi tep. Do tren 87 node hat cua ca cay: ca 87 deu ghi dang '../'.
## Luu y mot ten co DUOI CACH that trong du lieu goc: '../map/buttonbling .plist'
## (74/87 node) — khoa la 'map/buttonbling ' CO dau cach, con khoa ANH la
## 'map/buttonbling' khong co. Giu nguyen, khong tu sua du lieu goc.
static func khoa_tu_res(res: String) -> String:
	var s := res.replace("\\", "/")
	while s.begins_with("../"):
		s = s.substr(3)
	if s.begins_with("./"):
		s = s.substr(2)
	return s.get_basename()


static func co_hat(res: String) -> bool:
	_nap()
	return _idx.has(khoa_tu_res(res))


static func doc_dinh_nghia(khoa: String) -> Dictionary:
	if _dinh_nghia.has(khoa):
		return _dinh_nghia[khoa]
	var d := {}
	var muc = _idx.get(khoa, null)
	if muc is Dictionary:
		var p := DIR + String((muc as Dictionary).get("json", ""))
		if FileAccess.file_exists(p):
			var j = JSON.parse_string(FileAccess.get_file_as_string(p))
			if j is Dictionary:
				d = j
	_dinh_nghia[khoa] = d
	return d


## Tao node hat tu truong 'res' cua bo cuc. Tra ve null khi khong dich duoc —
## node hat khong co anh thi khong ve duoc gi, va node rong van dung hon node
## ve sai.
static func tao(res: String) -> HatNode:
	_nap()
	var khoa := khoa_tu_res(res)
	var d := doc_dinh_nghia(khoa)
	if d.is_empty():
		_bao_mot_lan("dinh nghia", khoa,
				"HatNode: khong co dinh nghia hat cho '%s'" % res)
		return null
	var muc: Dictionary = _idx[khoa]
	var ten_anh := String(muc.get("texture", ""))
	var tex := UiFrames.get_frame(ten_anh)
	if tex == null:
		_bao_mot_lan("anh", ten_anh,
				"HatNode: khong co anh '%s' trong ui_ref" % ten_anh)
		return null
	var n := HatNode.new()
	n._dung(d, tex)
	return n


static func _bao_mot_lan(loai: String, khoa: String, chu: String) -> void:
	var k := loai + ":" + khoa
	if _da_bao.has(k):
		return
	_da_bao[k] = true
	push_warning(chu)


## Gradient 1D tu danh sach mau. use_hdr = true vi he so mau co the VUOT 1:
## Cocos chan mau o 1,0 (mau hat di vao vertex colour dang BYTE), nhung he so
## thi khong bi chan — xem _he_so_mau().
static func _gradient(mau: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var diem := PackedFloat32Array()
	var sac := PackedColorArray()
	for i in mau.size():
		diem.append(float(i) / float(maxi(mau.size() - 1, 1)))
		sac.append(mau[i])
	g.offsets = diem
	g.colors = sac
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	t.use_hdr = true
	return t


## Mau tuyet doi cua mot moc (startColor / finishColor), gom ca alpha.
static func _mau(d: Dictionary, moc: String) -> Color:
	return Color(
			float(d.get(moc + "Red", 0.0)),
			float(d.get(moc + "Green", 0.0)),
			float(d.get(moc + "Blue", 0.0)),
			float(d.get(moc + "Alpha", 1.0)))


## He so mau luc SINH cho mot kenh: (mau +- phuong sai) / mau.
##
## Shader cua Godot: `params.color = color_value;` roi
## `params.color *= texture(color_initial_ramp, vec2(rand))` (0x730b23) — tuc
## he so NHAN vao mau, va lay MOT so ngau nhien dung chung cho ca ba kenh. Do
## do phan bo cua TUNG kenh van dung (deu trong [m-v, m+v]) nhung ba kenh tuong
## quan voi nhau; ban goc rut rieng tung kenh. Do la mot cho KHONG dich duoc,
## da ghi o ROADMAP.
##
## Chan tren: mau goc bi chan o 1,0 -> he so cao nhat la min(1, m+v)/m, co the
## van > 1 (m = 0,3 thi he so toi 3,33) — nen gradient phai bat use_hdr. Do tren
## 33 dinh nghia: khong kenh nao co m = 0 ma v != 0, nen khong bao gio chia cho 0.
static func _he_so_mau(d: Dictionary, kenh: String, duoi: bool) -> float:
	var m := float(d.get("startColor" + kenh, 0.0))
	var v := float(d.get("startColorVariance" + kenh, 0.0))
	if m == 0.0:
		return 1.0
	var x := (m - v) if duoi else (m + v)
	return clampf(x, 0.0, 1.0) / m


func _dung(d: Dictionary, tex: Texture2D) -> void:
	# Anh. Sau anh hat deu VUONG (do: firefog 256x256, nam anh con lai 64x64)
	# nen he so phong chi can mot truc. Kich thuoc trong .plist tinh bang pixel
	# CUA ANH GOC, Godot phong theo TI LE -> chia cho be rong anh.
	var rong := maxf(float(tex.get_width()), 1.0)
	var s0 := float(d.get("startParticleSize", 0.0))
	var sv := float(d.get("startParticleSizeVariance", 0.0))
	var s1 := float(d.get("finishParticleSize", 0.0))
	var gx := float(d.get("gravityx", 0.0))
	var gy := float(d.get("gravityy", 0.0))
	var toc := float(d.get("speed", 0.0))
	var toc_v := float(d.get("speedVariance", 0.0))
	var song := float(d.get("particleLifespan", 0.0))
	var song_v := float(d.get("particleLifespanVariance", 0.0))
	var bien_x := absf(float(d.get("sourcePositionVariancex", 0.0)))
	var bien_y := absf(float(d.get("sourcePositionVariancey", 0.0)))

	# T = L+v va r = 2v/(L+v): xem chu thich dau tep. Chot chan cho T <= 0 la
	# duong ma tren cay nay KHONG dinh nghia nao roi vao (do: 33/33 co L+v > 0,
	# nho nhat la png/particle/StarTrail 0 + 1,0 = 1,0).
	var t_song := song + song_v
	var r := 0.0
	if t_song <= 0.0:
		t_song = 0.0331
	else:
		r = clampf(2.0 * song_v / t_song, 0.0, 1.0)

	var pm := ParticleProcessMaterial.new()
	# Hop phat: `pos = vec3(rand*2-1, ...) * emission_box_extents` — phan bo deu
	# trong +-extents, dung bang +-sourcePositionVariance cua Cocos.
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(bien_x, bien_y, 0.0)
	# sourcePositionx/y cua Cocos BI BO QUA co chu y (khong phai bo sot): lay no
	# lam do lech thi hai cho trong chinh du lieu se hong thay duoc — tuyet roi
	# o y = 602,2 tren man cao 640 ma ChristmasSnow co sourcePositiony = 320,6
	# (ra ngoai man), va buttonbling co sourcePosition = (194,1; 185,8) trong
	# khi node nam o (5, 55). Xem ROADMAP.
	var a := deg_to_rad(float(d.get("angle", 0.0)))
	pm.direction = Vector3(cos(-a), sin(-a), 0.0)
	pm.spread = float(d.get("angleVariance", 0.0))
	# Van toc: Cocos lay `speed +- speedVariance` nhan voi vector don vi; Godot
	# lay cung vector do nhan mot he so rut tu khoang nay — nen de nguyen dau,
	# khoang am cung dung nghia (lat huong), khong chan o 0.
	pm.initial_velocity_min = toc - toc_v
	pm.initial_velocity_max = toc + toc_v
	pm.gravity = Vector3(gx, -gy, 0.0)
	# Phong: `parameters.scale *= texture(scale_curve, lifetime)` — NHAN, nen
	# duong cong phai la 1,0 -> finish/start de kich thuoc di tu start den finish.
	pm.scale_min = (s0 - sv) / rong
	pm.scale_max = (s0 + sv) / rong
	var ty_le := (s1 / s0) if s0 != 0.0 else 1.0
	pm.scale_curve = _gradient([Color(1, 1, 1), Color(ty_le, ty_le, ty_le)])
	# Xoay: do tren CA 33 dinh nghia, `rotationEnd` luon BANG `rotationStart`,
	# nen hat khong quay trong suot doi no — goc xoay chi la mot hang so ngau
	# nhien, va angular_velocity = 0 la DUNG chu khong phai xap xi. Neu sau nay
	# gap dinh nghia quay that thi phai dich them (va do lai), nen bao ra.
	var r0 := float(d.get("rotationStart", 0.0))
	var rv := float(d.get("rotationStartVariance", 0.0))
	# THU TU DAT CO NGHIA: Godot KEP LAN NHAU hai dau cua moi cap min/max — do
	# bang thu: dat `angle_min = 30` roi `angle_max = -30` thi ra `(-30, -30)`
	# (dau max keo dau min xuong), con dat nguoc lai thi ra `(30, 30)`. Dat dau
	# THAP truoc thi khong bi keo: dau thap chi keo dau cao len khi no vuot qua,
	# ma luc do dau cao con la mac dinh 0 — truong hop `r0 + rv > 0` cung vay,
	# vi `r0 - rv < r0 + rv`.
	pm.angle_min = -(r0 + rv)
	pm.angle_max = -(r0 - rv)
	pm.angular_velocity_min = 0.0
	pm.angular_velocity_max = 0.0
	if absf(float(d.get("rotationEnd", 0.0)) - r0) > 0.001:
		_static_bao("quay", "HatNode: dinh nghia co rotationEnd khac rotationStart — chua dich duoc")
	# Mau: color = TRANG (de phep nhan chinh la mau goc), color_ramp = gradient
	# mau dau -> mau cuoi (tuyet doi), color_initial_ramp = he so tung kenh.
	# Phuong sai mau luc CHET (finishColorVariance*) khong dich duoc: Cocos rut
	# hai lan doc lap (luc sinh va luc chet), con Godot chi rut MOT lan roi di
	# theo duong cong tat dinh — nen luc chet lay gia tri trung binh.
	pm.color = Color.WHITE
	pm.color_ramp = _gradient([_mau(d, "startColor"), _mau(d, "finishColor")])
	pm.color_initial_ramp = _gradient([
			Color(_he_so_mau(d, "Red", true), _he_so_mau(d, "Green", true),
					_he_so_mau(d, "Blue", true), _he_so_mau(d, "Alpha", true)),
			Color(_he_so_mau(d, "Red", false), _he_so_mau(d, "Green", false),
					_he_so_mau(d, "Blue", false), _he_so_mau(d, "Alpha", false))])
	pm.lifetime_randomness = r

	hat = GPUParticles2D.new()
	hat.name = "hat"
	hat.texture = tex
	hat.process_material = pm
	# So hat: Cocos giu toi da `maxParticles` cung song; Godot cung vay, nhip
	# phat hieu luc = amount / lifetime (tai lieu GPUParticles2D.amount) -> dat
	# amount = maxParticles, KHONG phai nhip phat.
	hat.amount = maxi(int(d.get("maxParticles", 8.0)), 1)
	hat.lifetime = t_song
	# `duration`: do tren 33 dinh nghia, 32 cai la -1 va mot cai (map/
	# finishfirework) la -0,55. Cocos coi duration am la VO HAN (hang so
	# kCCParticleDurationInfinity = -1), nen khong co dinh nghia nao phat huu
	# han -> khong dung nhanh cua so phat, va cung khong dung `one_shot`.
	# Rieng -0,55 khong phai dung hang so -1 nen day la mot CACH DOC, khong
	# phai so do: doc nguoc lai (elapsed >= duration ngay khung dau) thi qua
	# phao hoa do khong bao gio phat hat nao, ma no duoc dat o 5 cho.
	hat.one_shot = false
	hat.explosiveness = 0.0
	# Cocos khong co khai niem nay, va mac dinh cua Godot cung la 0: hat sinh
	# deu theo nhip, dung nhu `_emitCounter` cua Cocos.
	hat.randomness = 0.0
	# He hat cua Cocos song trong he toa do cua node: xem chu thich dau tep.
	hat.local_coords = true
	# Khong chay truoc: Cocos bat dau tu rong, va `CPublic:playButtonParticleSystem`
	# da goi resetSystem() khi can day hat.
	hat.preprocess = 0.0
	# Ban goc cong van toc theo TUNG KHUNG VE (`USERDATA1.xyz += force * DELTA`),
	# nen buoc tich phan = nhip ve; de mac dinh 30 cua Godot la buoc to gap doi.
	hat.fixed_fps = 60
	# Thu tu ve theo chi so mang hat. Voi phep tron CONG thi thu tu khong doi
	# ket qua (tru cho bao hoa), va ban goc ve theo thu tu mang cua no — nen lay
	# INDEX thay vi mac dinh LIFETIME (sap theo thoi gian song).
	hat.draw_order = GPUParticles2D.DRAW_ORDER_INDEX
	# Vung ve: Godot CULL theo hinh chu nhat nay, mac dinh chi +-100 quanh goc
	# nen hat bay xa hon se bien mat khi node ra khoi man. Ban goc ve vo dieu
	# kien, nen mo rong theo so cua chinh dinh nghia: (toc do + phuong sai) *
	# thoi gian song + bien do phat + quang duong roi do trong luc.
	var bk := (absf(toc) + absf(toc_v)) * t_song + maxf(bien_x, bien_y) \
			+ 0.5 * absf(gy) * t_song * t_song + 64.0
	hat.visibility_rect = Rect2(Vector2(-bk, -bk), Vector2(2.0 * bk, 2.0 * bk))
	hat.material = _vat_lieu_tron(d)
	add_child(hat)


## Vat lieu tron. Bang doi chieu day du tren 33 dinh nghia:
##
##   (770, 1)   GL_SRC_ALPHA, GL_ONE                25 dinh nghia -> ADD
##   (1, 771)   GL_ONE, GL_ONE_MINUS_SRC_ALPHA       5             -> PREMULT_ALPHA
##   (770, 771) GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA 1             -> MIX
##   (772, 1)   GL_DST_ALPHA, GL_ONE                 1 (finishfirework, dang dung)
##   (775, 1)   GL_SRC_ALPHA_SATURATE, GL_ONE        1 (map/LvBuFireP)
##
## Ba cap dau khop DUNG phep tron cua Godot. Hai cap cuoi Godot khong co, nen
## dung ADD va ghi lai la XAP XI — ca hai deu la dinh nghia ta chua mo man nao
## dung toi (tru finishfirework, da ghi o ROADMAP).
static func _vat_lieu_tron(d: Dictionary) -> CanvasItemMaterial:
	var src := int(d.get("blendFuncSource", 770))
	var dst := int(d.get("blendFuncDestination", 1))
	var v := CanvasItemMaterial.new()
	if src == 1 and dst == 771:
		v.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	elif src == 770 and dst == 771:
		v.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	else:
		if not (src == 770 and dst == 1):
			_static_bao("tron:%d/%d" % [src, dst],
					"HatNode: phep tron (%d,%d) khong co trong Godot — dung ADD" % [src, dst])
		v.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return v


static func _static_bao(khoa: String, chu: String) -> void:
	_bao_mot_lan("khac", khoa, chu)


func _process(_dt: float) -> void:
	# Goc cua node Cocos la DIEM NEO, ma bo cuc dat neo SAU khi tao node
	# (ui/xgg_layout.gd:294) va Godot khong phat tin hieu nao khi pivot_offset
	# doi — nen dong bo o day. Mot phep so sanh moi khung, khong dang ke.
	if hat != null and hat.position != pivot_offset:
		hat.position = pivot_offset


## Cocos `stopSystem()`: `_active = false`, `_elapsed = _duration`,
## `_emitCounter = 0`. Hat dang bay thi BAY NOT roi chet (vong cap nhat hat cua
## Cocos khong nghi khi `_active == false`), nen `emitting = false` cua Godot
## dung y vay — khong xoa ngay.
func stopSystem() -> void:
	if hat != null:
		hat.emitting = false


## Cocos `resetSystem()`: `_active = true`, `_elapsed = 0`, moi hat dang song bi
## giet (`timeToLive = 0`). `restart()` cua Godot lam dung the: xoa het hat cu
## roi phat lai. Do tren sc/: `resetSystem()` 9 cho goi, `stopSystem()` 13.
func resetSystem() -> void:
	if hat != null:
		hat.restart()


## Cocos `isActive()` tra ve `_active` — dung bang co phat hat. Do tren sc/:
## khong cho nao goi, nhung anh xa nay dung y nghia nen van de.
func isActive() -> bool:
	return hat != null and hat.emitting
