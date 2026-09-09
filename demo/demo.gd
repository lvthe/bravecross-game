# Man xem thu: nap mot nhan vat, chay lan luot cac dong tac.
#
#   mui ten trai/phai   doi dong tac
#   mui ten len/xuong   doi bien the (trang phuc)
#   [ / ]               doi nhan vat
#   space               tam dung
#
# Chay tu dong lenh de chup mot khung roi thoat (dung de kiem tra chieu xoay):
#
#   godot --path . -- --shot=user://shot.png --char=Archer --anim=Standby
extends Node2D

const ROOT := "res://assets_ref/"

## Danh sach nhan vat = moi thu muc trong assets_ref/, quet luc chay nen
## chep them nhan vat vao la dung duoc ngay, khong phai sua code.
var CHARS: PackedStringArray = []

var rig: SngRig = null
var char_i := 0
var zoom := 3.0
var _clutter := false
var anim_i := 0
var var_i := 0
var label: Label = null


func _ready() -> void:
	label = $Info
	var dir := DirAccess.open(ROOT)
	CHARS = dir.get_directories() if dir else PackedStringArray()
	if CHARS.is_empty():
		label.text = "assets_ref/ trong — chep nhan vat tu game-export vao"
		return
	var opts := _cli()
	if opts.has("clutter"):
		_clutter = opts["clutter"] != "0"
	if opts.has("zoom"):
		zoom = float(opts["zoom"])
	if opts.has("char"):
		char_i = maxi(0, CHARS.find(opts["char"]))
	_load_char()
	if opts.has("anim"):
		var names := rig.animations()
		var found := names.find(opts["anim"])
		if found >= 0:
			anim_i = found
			_play_current()
	if opts.has("strip"):
		_strip(opts.get("anim", "Walk"), int(opts.get("n", "6")))
	if opts.has("shot"):
		await _shoot(opts["shot"])


## Bay N ban sao cua nhan vat canh nhau, moi ban dung o mot thoi diem khac
## trong cung mot dong tac — nhin mot anh la thay ca chu ky.
func _strip(anim_name: String, n: int) -> void:
	if rig:
		rig.queue_free()
		remove_child(rig)
		rig = null
	var probe := SngRig.build(ROOT + CHARS[char_i])
	var length: float = probe.player.get_animation(anim_name).length
	probe.free()
	var vw := get_viewport_rect().size.x
	for i in n:
		var r := SngRig.build(ROOT + CHARS[char_i])
		r.position = Vector2(vw * (i + 0.5) / n, get_viewport_rect().size.y * 0.66)
		r.scale = Vector2(zoom, zoom)
		add_child(r)
		r.player.play(anim_name)
		r.player.seek(length * i / n, true)
		r.player.pause()
	label.text = "%s  —  %s, %d thoi diem trong %.2fs" % [
			CHARS[char_i], anim_name, n, length]


func _cli() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


func _load_char() -> void:
	if rig:
		rig.queue_free()
		remove_child(rig)
	# --clutter=1 de xem dung nhu man tran (bo cac lop hieu ung), 0 de xem het.
	rig = SngRig.build(ROOT + CHARS[char_i], "", _clutter)
	if rig == null:
		return
	# Nhan vat goc dung o goc toa do cua no; day xuong giua man cho de nhin.
	rig.position = get_viewport_rect().size * Vector2(0.5, 0.62)
	rig.scale = Vector2(zoom, zoom)
	add_child(rig)
	anim_i = 0
	var_i = maxi(0, Array(rig.variants()).find(rig.variant))
	_play_current()


func _play_current() -> void:
	var names := rig.animations()
	if names.is_empty():
		return
	anim_i = wrapi(anim_i, 0, names.size())
	rig.play(names[anim_i])
	_refresh_label()


func _refresh_label() -> void:
	if label == null or rig == null:
		return
	var names := rig.animations()
	var a := rig.player.get_animation(names[anim_i])
	label.text = "%s  /  %s\ndong tac %d/%d: %s   %.2fs  %s\nbo phan: %d   thieu anh: %d" % [
		CHARS[char_i], rig.variant,
		anim_i + 1, names.size(), names[anim_i], a.length,
		"lap" if a.loop_mode != Animation.LOOP_NONE else "mot lan",
		rig.bones.size(), rig.missing_sprites.size(),
	]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_RIGHT: anim_i += 1; _play_current()
		KEY_LEFT: anim_i -= 1; _play_current()
		KEY_UP, KEY_DOWN:
			var vs := rig.variants()
			var_i = wrapi(var_i + (1 if e.keycode == KEY_UP else -1), 0, vs.size())
			var keep := var_i
			rig.queue_free()
			remove_child(rig)
			rig = SngRig.build(ROOT + CHARS[char_i], vs[keep])
			rig.position = get_viewport_rect().size * Vector2(0.5, 0.62)
			rig.scale = Vector2(zoom, zoom)
			add_child(rig)
			var_i = keep
			anim_i = 0
			_play_current()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			char_i = wrapi(char_i + (1 if e.keycode == KEY_BRACKETRIGHT else -1),
					0, CHARS.size())
			_load_char()
		KEY_SPACE:
			rig.player.speed_scale = 0.0 if rig.player.speed_scale > 0.0 else 1.0


func _shoot(path: String) -> void:
	# Cho vai khung cho texture ve xong roi moi chup.
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("chup %s -> %s" % [path, "ok" if err == OK else "loi %d" % err])
	get_tree().quit()
