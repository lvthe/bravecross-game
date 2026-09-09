# Trang thai dung chung giua cac man (autoload `Game`).
#
# Doi man bang change_scene_to_file() thi moi node cu bi huy, nen phien choi va
# tien do phai nam ngoai cac man. Day la cho do.
#
#     Game.chapter = 3
#     get_tree().change_scene_to_file("res://battle/battle.tscn")
extends Node

const MENU := "res://ui/menu.tscn"
const ROSTER := "res://ui/roster.tscn"
const BATTLE := "res://battle/battle.tscn"

var session: PlayerSession = null
var combat: Combat = null

## Chuong sap danh. 0 = tran tap, khong tinh diem.
var chapter := 0
## Ket qua tran vua roi, de man menu bao lai. {} neu chua danh tran nao.
var last_fight: Dictionary = {}

var _chapters: Array = []
var _url := ""


func _ready() -> void:
	combat = Combat.new()
	var err := combat.load_data()
	if err != "":
		push_error(err)
	_maybe_shot()


## Chup mot khung roi thoat, dung cho moi man:
##   godot --path . <man> -- --shot=D:/tmp/x.png --at=5
## Dat o autoload nen man nao cung dung duoc, khoi moi man mot ban.
func _maybe_shot() -> void:
	var path := ""
	var at := 6.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7)
		elif a.begins_with("--at="):
			at = float(a.substr(5))
	if path == "":
		return
	await get_tree().create_timer(at).timeout
	await RenderingServer.frame_post_draw
	var e := get_viewport().get_texture().get_image().save_png(path)
	print("chup %s -> %s" % [path, "ok" if e == OK else "loi %d" % e])
	get_tree().quit()


## Dam bao da dang nhap. Goi nhieu lan cung duoc; chi dang nhap mot lan.
func ensure_session() -> PlayerSession:
	if session != null and is_instance_valid(session):
		return session
	session = PlayerSession.new()
	add_child(session)
	# Doc --url tu dong lenh, de con chi sang may chu khac khi thu nghiem.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--url="):
			_url = a.substr(6)
	await session.start(_url)
	return session


## Danh sach chuong. `force` de nap lai sau khi vua qua mot chuong.
func chapters(force := false) -> Array:
	if not force and not _chapters.is_empty():
		return _chapters
	await ensure_session()
	if not session.online:
		_chapters = []
		return _chapters
	var r := await session.client.call_rpc("bx.chapters", {})
	if not r.ok:
		_chapters = []
		return _chapters
	_chapters = r.data.get("chapters", [])
	return _chapters


func goto(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


## Ten cac tuong dung duoc, lay tu bo du lieu chien dau.
func hero_names() -> PackedStringArray:
	return combat.order if combat != null else PackedStringArray()


func roster() -> Array:
	if session == null:
		return []
	return session.data.get("roster", [])
