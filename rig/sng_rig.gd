# Nap mot nhan vat da xuat tu ban goc (JSON + PNG roi) thanh cay Node2D
# co AnimationPlayer chay duoc ngay.
#
# Nguon du lieu la thu muc do work/export.py sinh ra:
#
#     <Ten>/
#         <Ten>.json      bo xuong, bien the, dong tac, keyframe
#         sprites/*.png   tung bo phan mot file
#
# Cach dung:
#
#     var rig := SngRig.build("res://assets_ref/Archer")
#     add_child(rig)
#     rig.play("Walk")
#
# Mot file JSON chua NHIEU BIEN THE (variant). Vd Archer co:
#     Archer                 bo xuong chinh, 19 dong tac
#     Archer_Dong/Evil/Shi   cung bo xuong, khac bo sprite  -> trang phuc
#     Archer_WeaponNormal    bo xuong rieng cua vu khi, 1 dong tac
# build() lay bien the nhieu dong tac nhat neu khong chi dinh.
@tool
class_name SngRig
extends Node2D

## Doi dau toa do Y. Cocos2d dung truc Y huong LEN nen tuong la phai doi,
## nhung dung thu thi nhan vat lon nguoc — dau duoi chan tren. Toa do trong
## .xml da o he Y huong XUONG san, giong Godot. Giu false.
const FLIP_Y := false
## Goc xoay di theo truc Y, khong doi dau thi thoi.
const NEGATE_ROT := false
## Thu tu trong "children" la tu SAU ra TRUOC (phan tu dau nam sau lung).
const CHILDREN_BACK_TO_FRONT := true

## So khung moi giay. Ban goc KHONG luu truong nay o dau trong .xml — day la
## phong doan. Doi so nay neu hoat anh chay nhanh hay cham hon ban goc.
const FPS := 24.0

## Bo phan khong co anh: diem gan, vung cham. Van tao node de gan hieu ung
## hay hitbox vao, chi la khong co Sprite2D.
const MARKER_PREFIXES := ["PlugIn", "Collision", "ShootPoint", "Bone", "Effect"]

## Ten cach tron trong truong "blend" cua khung, ung voi phep tron CONG.
##
## Ban goc KHONG co mot che do tron chung cho armature: cach tron nam trong
## TUNG KHUNG (anim.py, +0x38 cua ban ghi khung), nen cung mot bien the co the
## vua ve thuong vua ve cong — `UIWuDaoHui_HeroLightFront` co 6 khung 'screen'
## lan trong 19 khung 'normal'. Dat dai additive cho moi SngRig la SAI.
##
## Doi chieu hai duong doc lap, khop nhau:
##
##   * do tren ban goc chay trong may ao (`work/emu_dom.py`): hieu ung nao co
##     khung 'screen' thi sang len o MOI kenh (chi tron cong lam duoc the),
##     hieu ung khong co thi toi di o kenh nao do (tron cong khong bao gio lam
##     toi) — 9/9 bien the dung nhu du lieu noi;
##   * ham phan nhanh trong `libgame.so`, 0x25d476..0x25d4ce — doc thang cap
##     he so ra: 'screen' -> (0x302, 1) = GL_SRC_ALPHA, GL_ONE = phep tron CONG.
##     ('' / 'normal' -> (1, 0x303); 'multiply' -> (0x306, 0x303).)
##
## Ten la tra ve MIX KHONG phai lam au: chinh ham cua ban goc lam vay — chuoi
## khac 'screen'/'multiply' roi vao nhanh 0x25d4c6, tuc che do mac dinh. Do tren
## 418 file .xml / 644.623 khung: 'normal' 462.413, rong 157.033, 'screen'
## 22.083, con lai 9 khung ten rac. KHONG co khung 'multiply' nao.
const BLEND_CONG := "screen"

## Bo phan la ve tich cua file goc: ten lop Photoshop con sot lai, hoac lop
## hieu ung logic. Chung khong thuoc dang nguoi va nam rat xa than —
## MaChao/Fight co "Layer006" cach goc 436 px, to hon ca nhan vat.
##
## Ban goc chi loe chung vai khung roi tat. Duong doi anh theo khung nay da giai
## (chi so anh `d` cua khung, anim.py) va SngRig da lam theo; bo loc van giu
## cho man tran vi chua do lai xem con lop nao cua nhom nay hien sai. Trinh xem
## rig de tat de con nhin thay het.
##
## CHI LOC O TANG NGOAI CUNG, khong truyen xuong rig long nhau. Danh sach bo
## phan cua mot nhan vat dat ten co nghia (Head, Body, ArmLeft), nen ten Layer*
## o do dung la ve tich. Con rig long nhau la mot ban ve rieng, bo phan cua no
## dat ten Photoshop la binh thuong: CaoCao_mc_Head co dung 4 bo phan va CA
## BON deu ten Layer*. Truyen co nay xuong la mat sach dau va than — da dinh
## dung the, CaoCao tu 23 bo phan con 17 va chi con moi thanh kiem.
const CLUTTER_PREFIXES := ["Layer", "LayerName", "Logic_", "图层"]

var data: Dictionary = {}
var variant: String = ""
var source_dir: String = ""
var bones: Dictionary = {}
var player: AnimationPlayer = null
var missing_sprites: PackedStringArray = []
## Bo phan tro toi mot rig long nhau (<Ten>_mc_...) chu khong phai anh.
var nested_rigs: PackedStringArray = []
var hide_clutter := false
var _chain: Dictionary = {}
## Dung chung cho MOI xuong cua rig nay: vai tram node tro cung mot vat lieu,
## khong phai moi xuong mot cai.
var _vat_lieu_cong: CanvasItemMaterial = null
## 'multiply' co dinh nghia trong engine nhung KHONG xuat hien trong du lieu
## nao ca (0 tren 644.623 khung). Canh bao mot lan, dung im lang roi ve sai.
var _da_canh_bao_multiply := false


## Dung nhan vat tu thu muc da xuat. Tra ve null neu doc khong duoc.
static func build(dir_path: String, want_variant: String = "",
		no_clutter := false) -> SngRig:
	var char_name := dir_path.get_file()
	var json_path := dir_path.path_join(char_name + ".json")
	if not FileAccess.file_exists(json_path):
		push_error("SngRig: khong thay %s" % json_path)
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SngRig: %s khong phai JSON hop le" % json_path)
		return null

	var rig := _make(parsed, dir_path, char_name, want_variant, {}, no_clutter)
	if rig == null:
		push_error("SngRig: %s khong co bien the nao co dong tac" % char_name)
	return rig


## Dung mot bien the. `chain` giu cac bien the dang nam tren duong dung, de
## rig long nhau khong goi vong lai chinh no.
static func _make(src: Dictionary, dir_path: String, node_name: String,
		want_variant: String, chain: Dictionary, no_clutter := false) -> SngRig:
	var rig := SngRig.new()
	rig.hide_clutter = no_clutter
	rig.data = src
	rig.source_dir = dir_path
	rig.name = node_name
	rig.variant = want_variant if want_variant != "" else rig._richest_variant()
	if rig.variant == "":
		return null
	rig._chain = chain.duplicate()
	rig._chain[rig.variant] = true
	rig._build_bones()
	rig._build_animations()
	rig._san_sang_tieng()
	return rig


## Cac bien the co dong tac (trang phuc, vu khi...).
func variants() -> PackedStringArray:
	var out := PackedStringArray()
	for g in data.get("groups", []):
		out.append(g.get("variant", ""))
	return out


## Ten cac dong tac cua bien the dang dung.
func animations() -> PackedStringArray:
	var out := PackedStringArray()
	if player:
		for a in player.get_animation_list():
			out.append(a)
	return out


func play(anim_name: String) -> bool:
	if player == null or not player.has_animation(anim_name):
		return false
	player.play(anim_name)
	return true


## Thoi luong mot dong tac, tinh bang GIAY. Ma goc hoi cai nay 97 lan
## (`_lua_getAnimationTime`) roi lay do lam do tre: no phai cho dong tac dien
## xong moi chay buoc ke tiep (man ket thuc tran, chuong trinh mo cong trinh).
## Thieu thi tra 0,0: cho 0 giay = di tiep ngay, va do cung la gia tri vo hai
## nhat — khong do duoc ban goc tra gi khi dong tac khong ton tai, ma moi gia
## tri <= 0,001 thi Cocos deu coi la "khong cho".
func thoi_luong(anim_name: String) -> float:
	if player == null:
		return 0.0
	if not player.has_animation(anim_name):
		return 0.0
	return player.get_animation(anim_name).length


## Dung dong tac dang chay, GIU nguyen tu the dang dung. Cocos
## `stopAnimation` khong dua ve khung 0 — ma vai cho goi no roi doi node im
## nguyen o tu the vua chay (`spBuilding:_lua_stop()`, 24 cho).
func dung() -> void:
	if player != null:
		player.stop(true)


## He so chay nhanh/cham. Ma goc goi 26 cho (`_lua_setAnimationRate`).
## `speed_scale` cua Godot chay muot theo khung, khac Cocos o cho toc do doi
## ngay lap tuc — nhung do lech chi thay trong vai khung dau, va khong co so do
## nao noi ban goc doi luc nao, nen lay duong muot.
func dat_toc_do(he_so: float) -> void:
	if player != null:
		player.speed_scale = he_so


## Diem gan (plug) cua ban goc. Bo phan trong .xml dat ten "PlugIn_<n>" hoac
## "PlugIn_<n>_<gi>" — hau to chi la chu thich cua nguoi thiet ke, khong nam
## trong so. Do tren 418 file .xml / 587 bien the co plug: PlugIn_1 (558),
## _2 (513), _3 (512), roi _30 (130), _31 (50), _11 (48), _40 (21), _5 (16),
## _60 (16), _6 (8), _32 (7), _4 (5), _20 (3), _50 (2), _102 (1), _7 (1).
##
## Khop theo SO chu khong theo thu tu xuat hien, va dieu do da kiem bang mot
## ca khong the trung: Gashapon co dung PlugIn_4_Hero, PlugIn_5_Word,
## PlugIn_6_Light, PlugIn_7_HeroName — va CUIUnlockHeroAnimation.lua:166-169
## goi _lua_clearPlugIn dung bon so 4, 5, 6, 7. UIZhanYiFuBen thi moi bien the
## chi co PlugIn_6_Text, dung cho FBDingJunShanJiaoFei.lua:85 (so 6).
func plug(idx: int) -> Node2D:
	var dau := "PlugIn_%d" % idx
	for ten in bones:
		var t := String(ten)
		if t == dau or t.begins_with(dau + "_"):
			return bones[ten]
	return null


# ------------------------------------------------------------------ noi bo

func _richest_variant() -> String:
	var best := ""
	var best_n := -1
	for g in data.get("groups", []):
		var n: int = (g.get("animations", []) as Array).size()
		if n > best_n:
			best_n = n
			best = g.get("variant", "")
	return best


## Nhom dong tac cua bien the. TRANG PHUC (Defender_VampirE, Archer_Dong...) la
## mot BO ANH cho cung bo xuong, KHONG co nhom dong tac rieng: dung dong tac cua
## nhom co ten la TIEN TO dai nhat. Do tren ca assets_ref: 76 bo phan cap cao
## khong co nhom rieng, 75 co nhom goc la tien to; xuong cua trang phuc trung
## xuong ma dong tac nhom goc dieu khien, trung vi 100%. Ca con lai
## (PlayerEquM001 trong PlayerM) lay nhom nhieu dong tac nhat.
##
## Truoc day tra ve rong: linh Defender_VampirE tren san tran KHONG co dong tac
## nao, dung im o anh dau cua moi xuong — ca xuong hieu ung chi loe khi danh —
## thanh mot mang vuot do bam theo ca tran.
func _group() -> Dictionary:
	var gs := {}
	for g in data.get("groups", []):
		gs[String(g.get("variant", ""))] = g
	if gs.has(variant):
		return gs[variant]
	var s := variant
	while s.contains("_"):
		s = s.substr(0, s.rfind("_"))
		if gs.has(s):
			return gs[s]
	var dai := ""
	for k in gs:
		if variant.begins_with(k) and String(k).length() > dai.length():
			dai = k
	if dai != "":
		return gs[dai]
	var giau := _richest_variant()
	return gs.get(giau, {})


## Thu tu ve: lay tu "parts". Bo phan chi xuat hien trong dong tac thi xep sau.
## Tra ve mang {name, sprites} — sprites la danh sach anh do CHINH FILE .xml
## chi dinh cho bo phan do.
func _ordered_parts() -> Array:
	var out: Array = []
	for p in data.get("parts", []):
		if p.get("name", "") == variant:
			out = (p.get("children", []) as Array).duplicate()
			break
	if not CHILDREN_BACK_TO_FRONT:
		out.reverse()
	var seen := {}
	for c in out:
		seen[c.get("name", "")] = true
	for a in _group().get("animations", []):
		for b in a.get("bones", []):
			var bn: String = b.get("name", "")
			if bn != "" and not seen.has(bn):
				seen[bn] = true
				out.append({"name": bn, "sprites": []})
	return out


## Chon anh cho mot bo phan.
##
## Khong doan theo ten. File .xml co san bang LIEN KET XUONG -> ANH (mang o
## header 0x4c), va export.py ghi no ra thanh truong "sprites" cua tung bo
## phan. Doan theo ten se sai voi nhung nhan vat dat ten anh kieu khac:
## CaoCao co "face1", "touguan", "toufa0013_instant", va LeftArm cua no dung
## lai anh "CaoCao_res-RightArm".
##
## Mot bo phan co the tro toi NHIEU anh — Archer/Head co 5 net mat, Effect co
## 6 khung. Moi keyframe chon mot anh bang chi so `d` (xem displays,
## _doi_anh); ham nay tim anh cho MOT ten.
##
## Ten bat dau bang "<Ten>_mc_" khong phai anh ma la MOT RIG LONG NHAU (bien
## the khac trong cung file). Chua rap duoc, tam bo qua — xem nested_rigs.
func _sprite_for(refs: Array) -> Dictionary:
	var files: Dictionary = data.get("spriteFiles", {})
	for r in refs:
		var key := String(r)
		if files.has(key) and files[key] != null:
			return files[key]
		if files.has(key + ".png") and files[key + ".png"] != null:
			return files[key + ".png"]
	return {}


## Ten bien the ma bo phan nay tro toi, neu do la mot rig long nhau.
##
## Quy tac la CO MOT BIEN THE TRUNG TEN trong file, chu khong phai ten co chua
## "_mc_". Phan lon rig long nhau ten kieu <Ten>_mc_Head that, nhung khong phai
## tat ca: ZhangLiao_EquipJian_2, JiaXu_EquipJian_2, ZhuGeLiangYoung_Base_Zhang
## deu la bien the that ma khong mang dau do — doi dung "_mc_" thi ba tuong ay
## mat vu khi.
##
## Goi sau _sprite_for() nen neu mot ten vua la anh vua la bien the thi anh
## duoc uu tien.
func _nested_variant(refs: Array) -> String:
	for r in refs:
		var key := String(r)
		if _chain.has(key):
			continue
		for p in data.get("parts", []):
			if p.get("name", "") == key:
				return key
	return ""


func _is_clutter(bone: String) -> bool:
	for p in CLUTTER_PREFIXES:
		if bone.begins_with(p):
			return true
	return false


func _is_marker(bone: String) -> bool:
	for p in MARKER_PREFIXES:
		if bone.begins_with(p):
			return true
	return false


func _load_texture(rel: String) -> Texture2D:
	var path := source_dir.path_join(rel)
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is Texture2D:
			return res
	# Chua qua buoc import cua Godot, hoac nam ngoai res:// — doc thang file.
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


func _make_sprite(info: Dictionary) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = _load_texture(info.get("png", ""))
	spr.centered = true
	# offX/offY la do lech tam anh so voi tam khung goc, theo dung nghia
	# "offset" cua plist Cocos2d. Phan lon bang 0 nhung co the len toi 78 px;
	# bo qua thi cac manh to nam lech han.
	spr.offset = Vector2(float(info.get("offX", 0.0)),
			-float(info.get("offY", 0.0)) if FLIP_Y else float(info.get("offY", 0.0)))
	return spr


## Moi xuong -> danh sach CAC THU NO CO THE HIEN, dung thu tu bang lien ket
## xuong -> anh cua file (header 0x4c): Sprite2D, SngRig long nhau, hoac null
## (anh khong co trong atlas). Keyframe chon mot o bang chi so `d` (anim.py,
## +0x2C cua khung); -1 la an. Truoc day moi xuong chi co anh DAU TIEN va hien
## suot — hieu ung chi loe vai khung (eff010 cua Player000 khi Fight) thanh ra
## bam theo nhan vat ca tran.
var displays: Dictionary = {}


func _build_bones() -> void:
	var z := 0
	for part in _ordered_parts():
		var bone: String = part.get("name", "")
		if hide_clutter and _is_clutter(bone):
			continue
		var refs: Array = part.get("sprites", [])
		var node: Node2D = null
		var ds: Array = []
		if not _is_marker(bone):
			# KHUNG xuong: mang bien doi cua xuong; cac thu co the hien la con.
			node = Node2D.new()
			var co := false
			for r in refs:
				var d := _display_for(String(r), bone)
				ds.append(d)
				if d != null:
					d.visible = false
					node.add_child(d)
					co = true
			if not co:
				missing_sprites.append(bone)
		if node == null:
			node = Marker2D.new()
		node.name = bone
		node.z_index = z
		z += 1
		add_child(node)
		bones[bone] = node
		displays[bone] = ds
		# Chua dong tac nao chon thi hien o dau, nhu truoc.
		_dat_khung(bone, 0)


## Mot thu co the hien cua xuong: anh trong atlas, hoac CA MOT RIG KHAC nam
## trong cung file — dau cua CaoCao, than cua ZhuGeLiang deu vay. Rig long nhau
## dung de quy va chay dong tac dau cua no.
func _display_for(ref: String, bone: String) -> Node2D:
	var info := _sprite_for([ref])
	if not info.is_empty():
		return _make_sprite(info)
	var nested := _nested_variant([ref])
	if nested == "":
		return null
	# KHONG truyen hide_clutter xuong: xem chu thich o CLUTTER_PREFIXES.
	var child := _make(data, source_dir, nested, nested, _chain, false)
	if child == null:
		return null
	var names := child.animations()
	if not names.is_empty():
		child.player.play(names[0])
	if not nested_rigs.has(bone):
		nested_rigs.append(bone)
	return child


## Hien o thu `idx` cua xuong, an cac o khac; -1 an het. Chi so ngoai bang
## (BingYing.xml, XSJiYouHeTiJi.xml — bo cuc khung khac, xem anim.py) thi giu
## o dau nhu cach cu, khong doan.
##
## Dat luon CACH TRON cua khung: vat lieu gan vao TUNG Sprite2D dang hien.
##
## KHONG gan len node xuong: vat lieu cua node CHA khong truyen xuong Sprite2D
## con trong Godot 4 — do bang diem anh that (`tools/do_tron.gd`: Sprite2D xam
## 0.392 tren nen 0.235 ra dung 0.3882 khi node cha mang vat lieu ADD, y het luc
## khong co vat lieu; gan truc tiep len Sprite2D thi ra 0.6235 = 0.235+0.392).
## Gan len node xuong thi phep thu van xanh ma man hinh khong doi mot diem anh
## nao — dung cai bay da mac.
##
## Bo phan la mot rig long nhau (dau CaoCao, than ZhuGeLiang) thi BO QUA: rig
## con co khung rieng cua no, dat de len la hai ben gianh nhau. Do tren ca
## assets_ref: khong xuong nao vua la rig long nhau vua co khung 'screen'.
func _dat_khung(bone: String, idx: int, blend := "") -> void:
	_dat_tron(bone, blend)
	var ds: Array = displays.get(bone, [])
	if ds.is_empty():
		return
	if idx < -1 or idx >= ds.size():
		idx = 0
	for i in ds.size():
		if ds[i] != null:
			ds[i].visible = i == idx


## Vat lieu cho mot ten cach tron. MIX tra ve null (mac dinh cua Godot, khong
## gan gi) de cay node khong phai mang them vat lieu nao.
func _vat_lieu_theo(ten: String) -> CanvasItemMaterial:
	if ten != BLEND_CONG:
		if ten == "multiply" and not _da_canh_bao_multiply:
			_da_canh_bao_multiply = true
			push_warning(("SngRig: khung mang cach tron 'multiply' — ban goc dung "
					+ "(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA), Godot khong co che do "
					+ "tuong ung nen ve tam bang MIX. Chua tung gap trong du lieu "
					+ "goc; gap thi phai viet shader rieng."))
		return null
	if _vat_lieu_cong == null:
		_vat_lieu_cong = CanvasItemMaterial.new()
		_vat_lieu_cong.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _vat_lieu_cong


func _dat_tron(bone: String, ten: String) -> void:
	var vat := _vat_lieu_theo(ten)
	for d in displays.get(bone, []):
		if d is Sprite2D:
			(d as Sprite2D).material = vat


func _build_animations() -> void:
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	var lib := AnimationLibrary.new()

	for a in _group().get("animations", []):
		var anim := Animation.new()
		var frames: int = int(a.get("frames", 1))
		var dur: int = int(a.get("duration", frames))
		# Do dai tinh bang khung; khung cuoi van phai duoc hien nen dung dur.
		anim.length = maxf(float(dur), 1.0) / FPS
		anim.loop_mode = Animation.LOOP_LINEAR if a.get("loop", false) else Animation.LOOP_NONE

		# Moi dong tac chi dung MOT PHAN bo phan. Vd Archer khi Standby thi
		# khong co Arrow / Effect / Effect2 — dung ra la phai an chung di.
		# Neu de nguyen, chung nam lai o goc toa do (duoi chan nhan vat) va
		# hien ra lo lo: mui ten nam duoi dat.
		var used := {}
		for b in a.get("bones", []):
			used[b.get("name", "")] = true
		for bone_name in bones:
			var t_vis := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(t_vis, NodePath("%s:visible" % bone_name))
			anim.value_track_set_update_mode(t_vis, Animation.UPDATE_DISCRETE)
			anim.track_insert_key(t_vis, 0.0, used.has(bone_name))

		for b in a.get("bones", []):
			var bone: String = b.get("name", "")
			if not bones.has(bone):
				continue
			# Doi anh theo khung: MOT duong goi _dat_khung cho MOI xuong. Dung
			# chung mot duong thi hai xuong co keyframe cung luc se ghi de nhau
			# (track_insert_key cung thoi diem thay khoa cu) — do duoc: Standby
			# cua nhan vat dau tien con 537/675 khoa.
			var t_anh := anim.add_track(Animation.TYPE_METHOD)
			anim.track_set_path(t_anh, NodePath("."))
			var t_pos := _add_track(anim, bone, "position")
			var t_rot := _add_track(anim, bone, "rotation")
			var t_scl := _add_track(anim, bone, "scale")
			# Keyframe BAT DAU o tong so khung giu cua cac keyframe truoc no
			# (dur, +0x40 cua khung — xem anim.py). Truoc day moi keyframe cach
			# nhau dung 1 khung: Weapon/Walk cua Player000 giu 3,3,3,2,1 khung
			# ma bi don vao 5 khung dau. JSON cu chua co dur thi van 1 khung.
			# Chi tin dur / d khi dung bat bien DO DUOC: xuong >= 2 keyframe thi
			# tong dur = do dai dong tac (95.416 / 95.431 xuong, anim.py). 15 xuong
			# sai deu o BingYing.xml — bo cuc khung khac, dur va d o do la rac —
			# thi quay ve cach cu: moi keyframe 1 khung, anh dau.
			var ks: Array = b.get("keys", [])
			var tong := 0
			for k in ks:
				tong += int(k.get("dur", 0))
			var tin := ks.size() < 2 or tong == dur or tong == frames
			var f := 0
			for k in ks:
				var t := float(f) / FPS
				f += maxi(1, int(k.get("dur", 1))) if tin else 1
				var y: float = float(k.get("y", 0.0))
				var r: float = float(k.get("rot", 0.0))
				anim.track_insert_key(t_pos, t, Vector2(
						float(k.get("x", 0.0)), -y if FLIP_Y else y))
				anim.track_insert_key(t_rot, t, deg_to_rad(-r if NEGATE_ROT else r))
				anim.track_insert_key(t_scl, t, Vector2(
						float(k.get("sx", 1.0)), float(k.get("sy", 1.0))))
				anim.track_insert_key(t_anh, t,
						{"method": "_dat_khung", "args": [bone,
							int(k.get("d", 0)) if tin else 0,
							String(k.get("blend", ""))]})

		lib.add_animation(a.get("name", "?"), anim)

	player.add_animation_library("", lib)
	player.root_node = NodePath("..")


func _add_track(anim: Animation, bone: String, prop: String) -> int:
	var idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath("%s:%s" % [bone, prop]))
	anim.value_track_set_update_mode(idx, Animation.UPDATE_CONTINUOUS)
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	return idx


# --------------------------------------------------------------- tieng dong

## Tieng theo KHUNG HOAT DONG cua `sound_config.xml` (xem game/tieng_dong.gd).
##
## Ban goc phat chung o tang C++ khi armature chay toi khung, khong qua Lua —
## nen khong co duong nao "chay ma goc" cho phan nay.
##
## Gan vao `AnimationPlayer.animation_started` chu KHONG gan trong `play()`:
## dong tac con duoc choi bang duong khac — `BattleUnit._play_lai` goi thang
## `player.play()` + `seek` (battle/unit.gd:156-162) de danh lai tu dau moi don.
##
## Do tren bang goc: 276 armature co tieng, 685 tieng, nhung 149/165 dong tac
## `Fight` chi co DUNG MOT tieng va khong dong tac `Walk`/`Standby` nao co
## tieng (tru 7 tieng `loop="1"`), nen khong co chuyen tieng buoc chan lam ngap
## 12 kenh khi ca tran cung di.
var _tiet_tau: Array = []       ## [{giay, su_kien, lap}] da sap theo giay
var _tiet_i := 0                ## tieng ke tiep chua phat
var _tiet_lap := 0              ## chi so tieng `lap` dau tien, = size neu khong co
var _vi_tri_truoc := 0.0


func _san_sang_tieng() -> void:
	if player == null:
		return
	player.animation_started.connect(_dong_moi)


func _dong_moi(_ten: StringName) -> void:
	_tiet_tau = []
	_tiet_i = 0
	_tiet_lap = 0
	_vi_tri_truoc = 0.0
	# Khong co ai doi tieng (chua mo khung suon Lua, hoac dang o trong trinh
	# xem rig cua Godot): khong doc bang, khong bat `_process`.
	if TiengDong.am == null or player == null:
		set_process(false)
		return
	var ten := player.current_animation
	# Tra theo ten BIEN THE truoc (do la ten armature that trong
	# `sound_config.xml`), roi moi den ten thu muc — co file ma hai ten do khac
	# nhau, va bo qua buoc thu hai thi nhung rig do cam.
	var td := TiengDong.moi()
	var ten_arm := _ten_armature()
	var ds := td.nhip(ten_arm, String(ten))
	if ds.is_empty() and ten_arm != String(name):
		ds = td.nhip(String(name), String(ten))
	if ds.is_empty():
		set_process(false)
		return
	for m in ds:
		# `khung` la chi so khung cua dong tac, va truc thoi gian cua dong tac
		# duoc dung bang chinh FPS nay (`anim.length = dur / FPS`).
		_tiet_tau.append({"giay": float(m["khung"]) / FPS,
				"su_kien": String(m["su_kien"]), "lap": bool(m["lap"])})
	_tiet_tau.sort_custom(func(a, b): return float(a["giay"]) < float(b["giay"]))
	_tiet_lap = _tiet_tau.size()
	for i in _tiet_tau.size():
		if _tiet_tau[i]["lap"]:
			_tiet_lap = i
			break
	set_process(true)


## Ten armature de tra bang tieng: `variant` khi rig nay la mot BIEN THE trong
## file khac (`ArcherN_Weapon_Normal` nam trong `ArcherN`), khong thi ten thu
## muc. Bang `sound_config.xml` khoa theo ten armature that.
func _ten_armature() -> String:
	return variant if variant != "" else String(name)


func _process(_delta: float) -> void:
	if _tiet_i >= _tiet_tau.size() and _tiet_lap >= _tiet_tau.size():
		set_process(false)
		return
	if player == null or TiengDong.am == null:
		return
	var vt := player.current_animation_position
	if vt < _vi_tri_truoc:
		# Dong tac quay vong: chi nhung tieng `loop="1"` moi phat lai (7 tieng
		# tren toan bo bang, vd `WakeLoop` cua Gia Xu).
		_tiet_i = _tiet_lap
	_vi_tri_truoc = vt
	while _tiet_i < _tiet_tau.size() \
			and float(_tiet_tau[_tiet_i]["giay"]) <= vt:
		var m: Dictionary = _tiet_tau[_tiet_i]
		_tiet_i += 1
		TiengDong.am.phat(String(m["su_kien"]))
