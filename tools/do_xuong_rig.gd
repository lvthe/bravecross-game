# Bo do TAM: in trang thai TUNG XUONG cua mot armature luc dang chay — vi tri,
# co hien khong, va thu dang hien la Sprite2D nao (duong dan + co anh).
#
#   godot --path . --script tools/do_xuong_rig.gd -- --ten=DefenderN --dong=Fight
#
# VI SAO PHAI CO. `do_doanh_trai.gd` in CAY NODE nhung KHONG in duoc anh cua
# Sprite2D trong rig (no chi in cho TextureRect/NinePatchRect), va no in `g=`
# cua node xuong — ma moi xuong deu la Node2D dat tai goc rig, nen moi dong ra
# CUNG MOT toa do. Nhin bang ay khong tra loi duoc cau hoi "xuong Than nam o dau
# va dang ve anh gi". Bo do nay in dung hai thu ay.
#
# Chay CO trinh ve (khong --headless) va doi khung THAT: duong phuong thuc cua
# AnimationPlayer khong chay khi goi advance()/seek() (da ghi o CLAUDE.md).
extends SceneTree

var _ten := "DefenderN"
var _dong := "Fight"
var _khung := 45
var _dem := 0
var _vp: SubViewport = null
var _rig: SngRig = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ten="):
			_ten = a.substr(6)
		elif a.begins_with("--dong="):
			_dong = a.substr(7)
		elif a.begins_with("--khung="):
			_khung = maxi(1, int(a.substr(8)))

	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 640)
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	_rig = SngRig.build("res://assets_ref/%s" % _ten, "", true)
	if _rig == null:
		print("KHONG dung duoc rig %s" % _ten)
		return
	_rig.position = Vector2(480, 520)
	_vp.add_child(_rig)
	print("rig=%s  bien the=%s  so xuong=%d" % [_ten, _rig.variant, _rig.bones.size()])
	print("dong tac co: %s" % ", ".join(_rig.animations()))
	var ok := _rig.play(_dong)
	print("play(%s) -> %s   (dang chay: %s)" % [_dong, ok,
			_rig.player.current_animation if _rig.player else "(khong co player)"])


func _process(_dt: float) -> bool:
	_dem += 1
	if _dem < _khung:
		return false
	if _rig == null:
		return true
	var p := _rig.player
	print("")
	print("sau %d khung: dong tac=%s  vi tri=%.3f giay  dang chay=%s" % [_dem,
			p.current_animation, p.current_animation_position, p.is_playing()])
	print("")
	print("%-16s %-8s %-18s %-24s %s" % ["XUONG", "hien", "pos / goc quay", "anh dang hien", "mo ta"])
	var so_hien := 0
	for ten in _rig.bones:
		var n: Node2D = _rig.bones[ten]
		var ds: Array = _rig.displays.get(ten, [])
		var con_hien := 0
		var mo := []
		for d in ds:
			if d == null:
				continue
			if d is Sprite2D:
				var s := d as Sprite2D
				var t := s.texture
				if s.visible:
					con_hien += 1
					mo.append("%s %dx%d" % [t.resource_path.get_file() if t else "(null)",
							t.get_width() if t else 0, t.get_height() if t else 0])
			elif d is SngRig:
				if d.visible:
					con_hien += 1
					mo.append("RIG LONG %s (%d xuong)" % [(d as SngRig).variant,
							(d as SngRig).bones.size()])
		if con_hien:
			so_hien += 1
		# Goc quay CUA CHINH XUONG, do bang do, lay tu node luc dang chay — tuc la
		# gia tri AnimationPlayer da ap. Them cot nay vi mot loi that: xuong
		# `Weapon` cua `Player000W03W` mang `rot` trong du lieu (Standby:
		# -27,8 / -19,03 / -17,27 do) nhung ban ve ra lai DUNG THANG, nen phai
		# doc so chu khong the nhin `pos` ma suy ra.
		print("%-16s %-8s %-18s %-24s %s" % [ten, str(n.visible),
				"(%.0f,%.0f) r=%.1f" % [n.position.x, n.position.y,
						rad_to_deg(n.rotation)],
				"%d/%d o hien" % [con_hien, ds.size()],
				"; ".join(mo) if mo else "(khong o nao hien)"])
	print("")
	print("TONG: %d/%d xuong co o dang hien" % [so_hien, _rig.bones.size()])
	print("thieu anh: %s" % str(_rig.missing_sprites))
	print("rig long: %s" % str(_rig.nested_rigs))
	return true
