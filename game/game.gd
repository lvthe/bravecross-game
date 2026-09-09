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

## Nen canh cua ban goc, xuat bang work/scenes.py. Moi chuong mot canh; het
## thi quay vong. Ban goc co bo cuc ghep tu 45 manh nho (BattleField_*.xgg)
## nhung TEXTURE cua nhung manh do khong co trong APK lan OBB — chung duoc tai
## ve luc chay. Bu lai cac lop nen day man thi con du, va dung duoc ngay.
const SCENES := [
	"plain/plain_a01", "plain/plain_a02", "plain/plain_a03", "plain/plain_a04",
	"siege/siege01", "siege/siege02", "zizhulin/zizhulin_background_a",
	"lava/lava_02_01a", "lava/lava_05_01a", "devil/devil_02_01a",
	"CBZZ/CBZZ-04-01", "tongtianta/tongtianta_background",
]
const SCENE_DIR := "res://assets_ref/scenes/"
const MENU_SCENE := "main3/mainscene3_background_a"

## Ban do tung chuong, lay tu art giao dien cua ban goc. Ban goc dung dung
## kieu nay cho man chon chuong.
const CHAPTER_MAPS := [
	"ui_background_chapter_prairie", "ui_background_chapter_forest",
	"ui_background_chapter_desert", "ui_background_chapter_valley",
	"ui_background_chapter_snow", "ui_background_chapter_battle",
	"ui_background_chapter_guandu", "ui_background_chapter_purplebamboo",
	"ui_background_chapter_cemetery", "ui_background_chapter_lava",
	"ui_background_chapter_devil", "ui_background_chapter_cebi",
]


## Anh ban do cua mot chuong, de lam hinh nho tren nut.
func chapter_map(chapter: int) -> Texture2D:
	if chapter <= 0:
		return null
	return UiTheme.tex(CHAPTER_MAPS[(chapter - 1) % CHAPTER_MAPS.size()])


## Anh nen cho mot chuong. chapter <= 0 (danh tap) thi lay canh dau.
func backdrop(chapter: int) -> Texture2D:
	var i: int = 0 if chapter <= 0 else (chapter - 1) % SCENES.size()
	return load_backdrop(SCENES[i])


func load_backdrop(rel: String) -> Texture2D:
	var path := SCENE_DIR + rel + ".png"
	if ResourceLoader.exists(path):
		var t := ResourceLoader.load(path)
		if t is Texture2D:
			return t
	# Chua xuat nen thi thoi, khong phai loi — man van choi duoc.
	return null


func _ready() -> void:
	combat = Combat.new()
	var err := combat.load_data()
	if err != "":
		push_error(err)
	# Theme dung art cua ban goc, ap cho ca cay node nen man nao cung theo.
	var th := UiTheme.build()
	if th != null:
		get_tree().root.theme = th
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
	# Khoa nhap lieu trong lan chup: cua so game gianh focus, va mot phim lac
	# tu ban phim se bam vao nut dang duoc focus roi nhay sang man khac. Da
	# dinh mot lan: dinh chup menu ma ra man tran.
	get_tree().root.gui_disable_input = true
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
