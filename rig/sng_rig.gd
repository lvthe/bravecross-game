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

## Bo phan la ve tich cua file goc: ten lop Photoshop con sot lai, hoac lop
## hieu ung logic. Chung khong thuoc dang nguoi va nam rat xa than —
## MaChao/Fight co "Layer006" cach goc 436 px, to hon ca nhan vat.
##
## Ban goc chi loe chung vai khung roi tat, bang duong doi anh theo khung ma ta
## CHUA GIAI DUOC. O day anh dau tien duoc giu suot, nen chung thanh nhung vat
## the bay lo lung. Man tran bat co nay de bo qua; trinh xem rig de tat de con
## nhin thay het.
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


func _group() -> Dictionary:
	for g in data.get("groups", []):
		if g.get("variant", "") == variant:
			return g
	return {}


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
## 6 khung. Ban goc doi anh theo dien bien tran dau; duong doi anh do chua
## giai duoc, nen o day lay anh dau tien.
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


## Ten bien the ma bo phan nay tro toi, neu no la mot rig long nhau va bien
## the do co that trong file (va chua nam tren duong dung).
func _nested_variant(refs: Array) -> String:
	for r in refs:
		var key := String(r)
		if not key.contains("_mc_") or _chain.has(key):
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


func _build_bones() -> void:
	var z := 0
	for part in _ordered_parts():
		var bone: String = part.get("name", "")
		if hide_clutter and _is_clutter(bone):
			continue
		var refs: Array = part.get("sprites", [])
		var node: Node2D = null
		if not _is_marker(bone):
			var info := _sprite_for(refs)
			var nested := ""
			if not info.is_empty():
				node = _make_sprite(info)
			else:
				# Bo phan nay co the khong phai mot anh ma la CA MOT RIG KHAC
				# nam trong cung file — dau cua CaoCao, than cua ZhuGeLiang
				# deu vay. Dung de quy roi treo vao dung cho; xuong cha van
				# dieu khien no y het mot Sprite2D.
				nested = _nested_variant(refs)
				if nested != "":
					var child := _make(data, source_dir, bone, nested, _chain,
							hide_clutter)
					if child != null:
						var names := child.animations()
						if not names.is_empty():
							child.player.play(names[0])
						nested_rigs.append(bone)
						node = child
			if node == null and nested == "":
				missing_sprites.append(bone)
		if node == null:
			node = Marker2D.new()
		node.name = bone
		node.z_index = z
		z += 1
		add_child(node)
		bones[bone] = node


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
			var t_pos := _add_track(anim, bone, "position")
			var t_rot := _add_track(anim, bone, "rotation")
			var t_scl := _add_track(anim, bone, "scale")
			var i := 0
			for k in b.get("keys", []):
				var t := float(i) / FPS
				var y: float = float(k.get("y", 0.0))
				var r: float = float(k.get("rot", 0.0))
				anim.track_insert_key(t_pos, t, Vector2(
						float(k.get("x", 0.0)), -y if FLIP_Y else y))
				anim.track_insert_key(t_rot, t, deg_to_rad(-r if NEGATE_ROT else r))
				anim.track_insert_key(t_scl, t, Vector2(
						float(k.get("sx", 1.0)), float(k.get("sy", 1.0))))
				i += 1

		lib.add_animation(a.get("name", "?"), anim)

	player.add_animation_library("", lib)
	player.root_node = NodePath("..")


func _add_track(anim: Animation, bone: String, prop: String) -> int:
	var idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath("%s:%s" % [bone, prop]))
	anim.value_track_set_update_mode(idx, Animation.UPDATE_CONTINUOUS)
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	return idx
