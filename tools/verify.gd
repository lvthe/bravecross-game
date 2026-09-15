# Kiem tra bo nap SngRig ma khong can mo cua so.
#
#   godot --headless --path . --script tools/verify.gd
#
# Doc moi thu muc trong assets_ref/, dung nhan vat, roi doi chieu voi chinh
# file JSON: du bo phan chua, du dong tac chua, do dai va co lap co dung
# khong, co bo phan nao dang le co anh ma khong tim ra file khong.
extends SceneTree

const ROOT := "res://assets_ref/"

var n_pass := 0
var n_fail := 0
var n_static := 0


func _check(ok: bool, desc: String, detail: String = "") -> void:
	if ok:
		n_pass += 1
		print("  dat   ", desc)
	else:
		n_fail += 1
		print("  HONG  ", desc, "" if detail == "" else "  -> " + detail)


func _init() -> void:
	var dir := DirAccess.open(ROOT)
	if dir == null:
		print("khong mo duoc ", ROOT)
		quit(1)
		return

	var names := dir.get_directories()
	if names.is_empty():
		print("assets_ref/ trong — chep vai nhan vat tu game-export vao truoc")
		quit(1)
		return

	for char_name in names:
		# assets_ref/ khong chi chua nhan vat: `scenes/` la anh nen canh. Mot
		# thu muc khong co <Ten>.json thi khong phai nhan vat, bo qua.
		if not FileAccess.file_exists(ROOT + char_name + "/" + char_name + ".json"):
			continue
		print("\n=== ", char_name, " ===")
		var raw = JSON.parse_string(
				FileAccess.get_file_as_string(ROOT + char_name + "/" + char_name + ".json"))

		# Khong phai atlas nao cung la mot rig. EquipGong, EquipJian,
		# EquipQiang, EquipQin, EquipZhang la art trang bi TINH: 12-13 sprite,
		# du file anh, nhung groups rong — khong co dong tac nao. SngRig tu
		# choi chung la dung, nen dem thanh HONG la do nham "du lieu von the"
		# voi "code hong".
		if raw is Dictionary and (raw.get("groups", []) as Array).is_empty():
			n_static += 1
			print("  bo qua  atlas tinh, khong co dong tac nao")
			continue

		var rig := SngRig.build(ROOT + char_name)
		if rig == null:
			_check(false, "dung duoc nhan vat")
			continue

		# --- bo phan
		var want_parts := 0
		for p in raw["parts"]:
			if p["name"] == rig.variant:
				want_parts = (p["children"] as Array).size()
		_check(rig.bones.size() >= want_parts,
				"du bo phan (%d node / %d trong JSON)" % [rig.bones.size(), want_parts])
		# Doi chieu tung bo phan voi bang lien ket xuong->anh cua chinh file
		# .xml. Bo phan nao duoc chi dinh mot anh CO THAT trong atlas thi bat
		# buoc phai thanh Sprite2D. Ba truong hop con lai la dung du lieu:
		#   - khong duoc chi dinh anh nao (bg, Saddle, ten lop Photoshop sot lai)
		#   - anh duoc chi dinh khong co trong atlas (muc kich thuoc 0)
		#   - chi toi mot rig long nhau <Ten>_mc_... (chua rap duoc)
		var lost := []
		var no_art := []
		for p in raw["parts"]:
			if p["name"] != rig.variant:
				continue
			for c in p["children"]:
				var bone: String = c["name"]
				if not rig.bones.has(bone):
					continue
				# Xuong la KHUNG; cac thu no co the hien (anh / rig long) la con,
				# giu trong rig.displays theo chi so anh cua file.
				var co_hien := false
				for d in rig.displays.get(bone, []):
					if d != null:
						co_hien = true
				if co_hien:
					continue
				var part_names := {}
				for p2 in raw["parts"]:
					part_names[String(p2["name"])] = true
				var has_real := false
				var nested := false
				for r in c["sprites"]:
					if raw["spriteFiles"].get(r) != null:
						has_real = true
					elif part_names.has(String(r)):
						# Rig long nhau: mot bien the trung ten. Khong doi dau
						# "_mc_" — ZhangLiao_EquipJian_2 cung la rig long.
						nested = true
				if (has_real or nested) and not rig._is_marker(bone):
					lost.append(bone + ("(rig long)" if nested else ""))
				else:
					no_art.append(bone)
		_check(lost.is_empty(),
				"bo phan duoc chi dinh anh that / rig long thi phai dung duoc",
				", ".join(lost))
		if rig.nested_rigs.size() > 0:
			print("  (%d rig long nhau da rap vao: %s)"
					% [rig.nested_rigs.size(), ", ".join(rig.nested_rigs)])
		if not no_art.is_empty():
			print("  (%d bo phan khong co anh dung duoc, dung du lieu: %s)"
					% [no_art.size(), ", ".join(no_art)])

		# --- anh that su nap duoc
		var n_tex := 0
		var n_null := 0
		for ds in rig.displays.values():
			for b in ds:
				if b is Sprite2D:
					if b.texture == null:
						n_null += 1
					else:
						n_tex += 1
		_check(n_null == 0, "moi Sprite2D deu co texture (%d anh)" % n_tex,
				"%d node khong nap duoc anh" % n_null)

		# --- dong tac
		var grp := {}
		for g in raw["groups"]:
			if g["variant"] == rig.variant:
				grp = g
		var want_anims: Array = grp.get("animations", [])
		_check(rig.animations().size() == want_anims.size(),
				"du dong tac (%d / %d)" % [rig.animations().size(), want_anims.size()])

		var bad_len := []
		var bad_loop := []
		var bad_keys := []
		for a in want_anims:
			var anim := rig.player.get_animation(a["name"])
			if anim == null:
				continue
			var want_len: float = maxf(float(a.get("duration", a["frames"])), 1.0) / SngRig.FPS
			if absf(anim.length - want_len) > 0.0005:
				bad_len.append(a["name"])
			var want_loop: bool = a.get("loop", false)
			if (anim.loop_mode != Animation.LOOP_NONE) != want_loop:
				bad_loop.append(a["name"])
			# moi xuong tham gia: 3 duong (vi tri, xoay, ti le) x so keyframe,
			# cong mot khoa doi anh moi keyframe (duong _dat_khung); cong moi
			# xuong cua rig mot khoa an/hien
			var want_keys := rig.bones.size()
			for b in a["bones"]:
				if rig.bones.has(b["name"]):
					want_keys += (b["keys"] as Array).size() * 4
			var got_keys := 0
			for t in anim.get_track_count():
				got_keys += anim.track_get_key_count(t)
			if got_keys != want_keys:
				bad_keys.append("%s(%d/%d)" % [a["name"], got_keys, want_keys])

		_check(bad_len.is_empty(), "do dai dong tac dung", ", ".join(bad_len))
		_check(bad_loop.is_empty(), "co lap dung", ", ".join(bad_loop))
		_check(bad_keys.is_empty(), "du keyframe tren moi duong", ", ".join(bad_keys))

		# Bo phan khong tham gia dong tac phai bi an, khong duoc de roi ve goc
		# toa do. Doi chieu tung dong tac voi danh sach xuong trong JSON.
		var bad_vis := []
		for a in want_anims:
			var anim := rig.player.get_animation(a["name"])
			if anim == null:
				continue
			var used := {}
			for b in a["bones"]:
				used[b["name"]] = true
			for t in anim.get_track_count():
				var path := anim.track_get_path(t)
				if path.get_subname_count() == 0 or path.get_subname(0) != "visible":
					continue
				var bone := String(path.get_concatenated_names())
				var want: bool = used.has(bone)
				if bool(anim.track_get_key_value(t, 0)) != want:
					bad_vis.append("%s/%s" % [a["name"], bone])
		_check(bad_vis.is_empty(), "an dung cac bo phan khong tham gia",
				", ".join(bad_vis))

		rig.free()

	_dat_khung_theo_dong_tac()
	await _tron_theo_khung()

	if n_static > 0:
		print("%d atlas tinh (khong co dong tac) da bo qua" % n_static)
	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)


## Doi anh theo khung, so voi so DO trong file (anim.py): Player000M03W/Fight,
## xuong eff010 = (-1,8) (0,3) (0,1) (-1,2) — an 8 khung, hien anh 0 bon khung,
## an 2. Keyframe bat dau o tong dur truoc no: khung 0, 8, 11, 12.
func _dat_khung_theo_dong_tac() -> void:
	print("\n=== doi anh theo khung (Player000M03W) ===")
	var rig := SngRig.build(ROOT + "Player000", "Player000M03W")
	if rig == null:
		_check(false, "dung duoc Player000M03W")
		return
	var anim := rig.player.get_animation("Fight")
	var got := []
	if anim != null:
		for t in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_METHOD:
				continue
			for k in anim.track_get_key_count(t):
				var args: Array = anim.method_track_get_params(t, k)
				if args.size() >= 2 and args[0] == "eff010":
					got.append([roundi(anim.track_get_key_time(t, k) * SngRig.FPS), int(args[1])])
	_check(got == [[0, -1], [8, 0], [11, 0], [12, -1]],
			"eff010/Fight doi anh dung khung (-1 @0, 0 @8, 0 @11, -1 @12)", str(got))
	rig._dat_khung("eff010", -1)
	var hien := 0
	for d in rig.displays.get("eff010", []):
		if d != null and d.visible:
			hien += 1
	_check(hien == 0, "_dat_khung(-1) an het cac anh cua xuong", "%d con hien" % hien)
	rig.free()


## Cach tron theo khung. So voi SO DO tu ban goc, khong phai tu ten:
##
##   `UITongYong_ItemLight` — dom xanh o Main. Ca 32 khung deu mang 'screen',
##   va do tren may ao thi no SANG len o moi kenh => phep tron CONG.
##   `DaQuZhanShi` — hinh tuong, khong khung nao mang 'screen', do ra TOI di
##   o kenh g va b => phep tron THUONG.
##
## Phep thu nay khoa ca hai dau: du lieu (chuoi trong JSON) va cach dung
## (vat lieu thuc su gan vao node xuong, co dung BLEND_MODE_ADD khong).
##
## Phai de cho THAT vai khung chay qua: duong phuong thuc cua Godot KHONG chay
## khi goi advance()/seek() — do duoc, `play()` roi `advance(0.5)` thi vat lieu
## van nguyen, ma de `process_frame` vai lan thi doi. Nen rig phai nam trong cay
## va phep thu phai la ham cho (await).
func _tron_theo_khung() -> void:
	print("\n=== cach tron theo khung ===")
	var cong := SngRig.build(ROOT + "UITongYong", "UITongYong_ItemLight")
	if cong == null:
		_check(false, "dung duoc UITongYong_ItemLight")
		return
	# 1. Du lieu: moi khung cua ItemLight phai mang 'screen'. Doc thang tham so
	# cua duong phuong thuc, khong doc vat lieu — luc nay dong tac chua chay.
	var ds_ten := cong.animations()
	var so_screen := 0
	var so_khac := 0
	var vi_du := ""
	for ten_a in ds_ten:
		var an := cong.player.get_animation(ten_a)
		for t in an.get_track_count():
			if an.track_get_type(t) != Animation.TYPE_METHOD:
				continue
			for k in an.track_get_key_count(t):
				var args: Array = an.method_track_get_params(t, k)
				var b := String(args[2]) if args.size() >= 3 else ""
				if b == SngRig.BLEND_CONG:
					so_screen += 1
				else:
					so_khac += 1
					if vi_du == "":
						vi_du = "%s/%s" % [ten_a, args]
	_check(not ds_ten.is_empty() and so_screen > 0 and so_khac == 0,
			"moi khung cua ItemLight mang 'screen'",
			"screen %d, khac %d (%s)" % [so_screen, so_khac, vi_du])

	# 2. Chay that: cho vai khung roi moi doc vat lieu.
	#
	# Kiem tren TUNG Sprite2D chu khong phai node xuong: vat lieu cua node CHA
	# khong truyen xuong Sprite2D con trong Godot 4 (do bang render that, xem
	# chu thich o SngRig._dat_khung). Ban dau phep thu nay kiem node xuong nen
	# van xanh trong khi anh Main khong doi mot diem anh nao.
	root.add_child(cong)
	cong.play(ds_ten[0])
	for _i in 4:
		await process_frame
	var dem_add := 0
	var dem_khac := 0
	var vi_du_sp := ""
	for ten in cong.bones:
		for d in cong.displays.get(ten, []):
			if not (d is Sprite2D):
				continue
			var m: Material = (d as Sprite2D).material
			if m != null and (m as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
				dem_add += 1
			else:
				dem_khac += 1
				if vi_du_sp == "":
					vi_du_sp = "%s/%s -> %s" % [ten, d.name, m]
	_check(dem_khac == 0 and dem_add > 0,
			"chay xong thi moi Sprite2D cua ItemLight mang vat lieu CONG",
			"add %d, khac %d (%s)" % [dem_add, dem_khac, vi_du])

	# Phep tron phai DOI THEO KHUNG, khong phai gan cung cho ca rig: dung mot
	# khung 'normal' roi doi sang khung 'screen' thi vat lieu phai doi theo.
	var xuong := ""
	for ten in cong.bones:
		xuong = ten
		break
	cong._dat_khung(xuong, 0, "normal")
	var truoc := _vat_lieu_cua(cong, xuong)
	cong._dat_khung(xuong, 0, "screen")
	var sau := _vat_lieu_cua(cong, xuong)
	_check(truoc == null and sau != null,
			"cach tron doi theo khung, khong gan cung cho ca rig",
			"%s: normal -> %s, screen -> %s" % [xuong, truoc, sau])
	cong.free()

	var thuong := SngRig.build(ROOT + "DaQuZhanShi", "DaQuZhanShi")
	if thuong == null:
		_check(false, "dung duoc DaQuZhanShi")
		return
	var co_vat_lieu := 0
	for ten in thuong.bones:
		if _vat_lieu_cua(thuong, ten) != null:
			co_vat_lieu += 1
	_check(co_vat_lieu == 0,
			"hinh tuong (DaQuZhanShi) khong Sprite2D nao bi dat tron CONG",
			"%d xuong co vat lieu" % co_vat_lieu)
	thuong.free()


## Vat lieu dang nam tren Sprite2D cua mot xuong; null neu xuong khong co
## Sprite2D nao (diem gan, rig long nhau) hoac dang ve thuong.
func _vat_lieu_cua(rig: SngRig, bone: String) -> Material:
	for d in rig.displays.get(bone, []):
		if d is Sprite2D:
			return (d as Sprite2D).material
	return null
