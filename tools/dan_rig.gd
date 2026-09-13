# Dan rig: ve mot LOAT armature tran cung luc, moi cai chay Fight (hoac Standby
# neu khong co Fight), roi chup thanh MOT anh luoi de soi nhanh xem con rig nao
# hong: thieu bo phan, sai tu the, hay dom sang (eff). Khong thay the choi tran
# that; day la kinh soi hinh.
#
#   godot --path . --script tools/dan_rig.gd -- --chup=dan.png
#   ... -- --chup=dan.png --dong=Standby   (doi dong tac)
#   ... -- --chup=dan.png --khung=40        (chup o khung thu N -> chon the danh)
extends SceneTree

# Curated: linh, xa thu, ky binh, khi gioi, va vai boss/tuong dau chien dich.
const DS := [
	"DefenderN", "Defender", "ArcherN", "Archer", "Cavalry", "ArmorCavalry",
	"ShieldMaster", "Flagman", "Artillery", "Catapult", "ElephantSoldier",
	["Player000", "Player000M03W"],
	"LvBu", "GuanYu", "ZhaoYun", "MaChao", "DianWei", "CaoCao",
	"ZhangFei", "XiahouDun", "GongSunZan", "HuangZhong",
]

const COT := 6
const O_W := 210.0
const O_H := 230.0
const LE := 20.0

var _dem := 0
var _khung := 45
var _dong := "Fight"
var _chup := "dan.png"
var _vp: SubViewport = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			_chup = a.substr(7)
		elif a.begins_with("--khung="):
			_khung = maxi(1, int(a.substr(8)))
		elif a.begins_with("--dong="):
			_dong = a.substr(7)

	var hang := int(ceil(float(DS.size()) / COT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(COT * O_W + LE * 2), int(hang * O_H + LE * 2))
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	# Nen xam de thay ro vien va cho trong (bo phan thieu).
	var nen := ColorRect.new()
	nen.color = Color(0.16, 0.18, 0.22)
	nen.size = Vector2(_vp.size)
	_vp.add_child(nen)

	var i := 0
	for muc in DS:
		var ten: String = muc[0] if muc is Array else muc
		var bien: String = muc[1] if muc is Array else ""
		var cx := LE + (i % COT) * O_W + O_W * 0.5
		# Rig lay goc o CHAN; ha xuong duoi o mot chut de nguoi nam gon trong o.
		var cy := LE + (i / COT) * O_H + O_H * 0.78
		_them(ten, bien, Vector2(cx, cy))
		i += 1


func _them(ten: String, bien: String, tam: Vector2) -> void:
	var dir := "res://assets_ref/%s" % ten
	var rig := SngRig.build(dir, bien, true)
	if rig == null and bien != "":
		rig = SngRig.build(dir, "", true)
	var nhan := Label.new()
	nhan.text = (bien if bien != "" else ten)
	nhan.position = tam + Vector2(-O_W * 0.5 + 6.0, -O_H * 0.72)
	nhan.add_theme_font_size_override("font_size", 15)
	nhan.add_theme_color_override("font_color", Color(1, 1, 1))
	_vp.add_child(nhan)
	if rig == null:
		var x := Label.new()
		x.text = "(NULL)"
		x.position = tam
		x.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		_vp.add_child(x)
		return
	rig.position = tam
	# Thu nho neu rig qua to (boss) cho vua o.
	rig.scale = Vector2(0.5, 0.5)
	_vp.add_child(rig)
	# Doi sang dong tac gan nhat co that (Flagman chi co Walk).
	var uu := [_dong, "Fight", "Standby", "Walk", "Run"]
	for d in uu:
		if rig.play(d):
			break
	# Bao them so bo phan thieu anh (neu co) ben duoi nhan.
	if not rig.missing_sprites.is_empty():
		var m := Label.new()
		m.text = "thieu:%d" % rig.missing_sprites.size()
		m.position = tam + Vector2(-O_W * 0.5 + 6.0, -O_H * 0.72 + 18.0)
		m.add_theme_font_size_override("font_size", 12)
		m.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		_vp.add_child(m)


func _process(_dt: float) -> bool:
	_dem += 1
	if _dem == _khung:
		var img := _vp.get_texture().get_image()
		img.save_png(_chup)
		print("da chup %s (%dx%d), %d rig" % [_chup, img.get_width(), img.get_height(), DS.size()])
		return true
	return false
