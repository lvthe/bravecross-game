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
				if rig.bones[bone] is Sprite2D or rig.bones[bone] is SngRig:
					continue
				var has_real := false
				var nested := false
				for r in c["sprites"]:
					if String(r).contains("_mc_"):
						nested = true
					elif raw["spriteFiles"].get(r) != null:
						has_real = true
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
		for b in rig.bones.values():
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
			# moi xuong tham gia: 3 duong (vi tri, xoay, ti le) x so keyframe;
			# cong moi xuong cua rig mot khoa an/hien
			var want_keys := rig.bones.size()
			for b in a["bones"]:
				if rig.bones.has(b["name"]):
					want_keys += (b["keys"] as Array).size() * 3
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

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)
