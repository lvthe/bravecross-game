# Trang thai dung chung giua cac man (autoload `Game`).
#
# Doi man bang change_scene_to_file() thi moi node cu bi huy, nen phien choi va
# tien do phai nam ngoai cac man. Day la cho do.
#
#     Game.chapter = 3
#     get_tree().change_scene_to_file("res://battle/battle.tscn")
extends Node

## Cua vao that: man Main cua BAN GOC (chuoi Login -> Main cua lop Lua).
##
## `battle.gd:520` va bon man kia (equip/formation/roster/tasks) tro ve day khi
## bam Back. Vi runtime Lua song trong chinh autoload nay (xem `lua`), ve day la
## TUC THI — khong chay lai chuoi ~5 giay.
const MENU := "res://ui/vao_game.tscn"

## Tran cho `--shot` doi chuoi khoi dong. Do duoc ~5 giay may ranh / 7-15 giay khi
## chay nang may ao Android; de rong de may cham khong lam mat anh, ma ket that
## thi van bao ra roi chup.
const CHO_VAO_MS := 60000

## Man chu scaffold (Label + Button mac dinh, khong art). Tu luot nay KHONG con
## la cua vao, va cung khong con la cua ngo vao roster/formation/equip/tasks/
## battle — nam man do chi con vao duoc bang duong dan tuong minh:
##     godot --path . ui/menu.tscn
## Giu hang so lai vi no la man DUY NHAT con lien ket toi nam man kia; noi lai
## duoc chung vao nut cua Main that la viec ghi o ROADMAP.md.
const MENU_CHU := "res://ui/menu.tscn"
const ROSTER := "res://ui/roster.tscn"
const FORMATION := "res://ui/formation.tscn"
const EQUIP := "res://ui/equip.tscn"
const TASKS := "res://ui/tasks.tscn"
const BATTLE := "res://battle/battle.tscn"

var session: PlayerSession = null
var combat: Combat = null

## Runtime cua canh Main cua ban goc. Nam o DAY chu khong o man cua vao: man bi
## `change_scene_to_file` huy moi lan doi man, con runtime thi phai song qua
## hang chuc lan doi man (moi lan bam Back ve Main). Doi lai, ca chuoi khoi dong
## Login -> Main (do duoc 3499/3630/3957 ms tren may ranh — xem `ui/vao_game.gd`)
## chi chay MOT lan cho ca phien.
var lua: LuaRuntime = null

## Lop chua san khau Lua. Xem `layer = -1` o `_ready()`.
var lop_lua: CanvasLayer = null

## Chuoi Login -> Main da chay xong chua. Trong luc con `false`, `Tien` cua man
## cua vao dang tu tick lay — nen `_process` o day PHAI khong tick. Tick chong
## thi so khung Lua chay gap doi, va moi thu bam theo so khung (vi tri nhan
## vat, dong ho canh) lech het, khong mot dong loi nao.
var da_vao := false

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
	# KHONG dat `root.theme = null` de chieu long lop Lua: bon man GDScript ma
	# nguoi choi di toi ngay sau do (roster/formation/equip/tasks) song nho no.
	# San khau Lua tu rut ra khoi theme nay — xem `ui/vao_game.gd`.
	var th := UiTheme.build()
	if th != null:
		get_tree().root.theme = th
	# Lop chua san khau Lua. `layer = -1` de no LUON ve duoi moi man: autoload
	# duoc them vao root TRUOC man hien tai nen cay cua no von da ve duoi, va
	# layer am khoa dieu do lai ke ca khi thu tu ay doi. (Duong `--script` cu
	# gan san khau thang vao `root`, tuc la NOI len tren — o do khong co man
	# hien tai nen chua lo ra.)
	lop_lua = CanvasLayer.new()
	lop_lua.name = "LopLua"
	lop_lua.layer = -1
	add_child(lop_lua)
	# Noi cham dat o DAY, khong o man cua vao: `window_input` thuoc ve Window va
	# song lau hon moi man, nen mot lambda nop tu trong man se thanh callback
	# tren vat da giai phong, moi khi doi man.
	get_tree().root.window_input.connect(_su_kien_cua_so)
	_maybe_shot()


## Chuyen toa do diem anh cua cua so ve toa do canvas roi dua cho lop Lua.
##
## `window_input` phat TRUOC khi GUI cua Godot xu ly, nen node .xgg khong nuot
## mat cu bam. Nhung no mang toa do DIEM ANH cua cua so; `stretch` =
## canvas_items (project.godot) thi phai doi ve toa do canvas, khong thi phong
## to cua so la bam lech. Phep doi PHAI dung phep bien doi cua root — khong
## phai cua viewport con nao, cung khong phai cua san khau.
##
## Gac theo `lop_lua.visible` chu khong chi theo `lua`: lop Lua song qua moi lan
## doi man, nen dang o man tran ma khong gac thi no van hit-test cu cham — bam
## mot nut cua man tran se bam luon vao nut Main nam duoi.
func _su_kien_cua_so(e: InputEvent) -> void:
	if lua == null or lop_lua == null or not lop_lua.visible:
		return
	lua.touch(e.xformed_by(get_tree().root.get_final_transform().affine_inverse()))


## Canh Main cua ban goc tu chay theo tung khung cua no.
##
## Chi tick khi chuoi khoi dong da xong (`da_vao`); luc dang khoi dong thi
## `Tien` tick lay. Xem chum o `da_vao`.
func _process(dt: float) -> void:
	if lua != null and da_vao:
		lua.tick(dt)


## Chup mot khung roi thoat, dung cho moi man:
##   godot --path . <man> -- --shot=D:/tmp/x.png --at=5
## Dat o autoload nen man nao cung dung duoc, khoi moi man mot ban.
##
## `--at` dem tu luc VAO DUOC Main, khong phai tu luc mo cua so — xem
## `_doi_vao_game`.
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
	await _doi_vao_game()
	await get_tree().create_timer(at).timeout
	await RenderingServer.frame_post_draw
	var e := get_viewport().get_texture().get_image().save_png(path)
	print("chup %s -> %s" % [path, "ok" if e == OK else "loi %d" % e])
	get_tree().quit()


## Cho chuoi khoi dong Login -> Main xong TRUOC khi bat dau dem `--at`.
##
## `--at` phai nghia la "may giay SAU KHI da vao duoc Main", chu khong phai "may
## giay sau khi mo cua so". Lan dau cho ~5 giay (may ranh: `nap` 1,3 s + chuoi
## 3,5 s) va 7-15 giay khi chay nang may ao Android — nen moc dem tu luc mo cua
## so thi `--at` MAC DINH 6 giay se chup vao GIUA chuoi, ra anh nua voi ma khong
## mot loi nao. Do la loai sai im lang, nen cho han.
##
## Man KHONG phai cua vao (`battle.tscn`, `tools/shot_*.tscn`, `ui/menu.tscn`)
## thi `da_vao` khong bao gio bat: gap chung thi thoi doi NGAY, khong thi
## `--shot` o nam man kia bi treo them ca tran.
func _doi_vao_game() -> void:
	var t0 := Time.get_ticks_msec()
	while not da_vao:
		var man := get_tree().current_scene
		if man != null and man.scene_file_path != MENU:
			return
		if Time.get_ticks_msec() - t0 > CHO_VAO_MS:
			push_warning("chup anh: chuoi khoi dong chua xong sau %d ms" % CHO_VAO_MS)
			return
		await get_tree().process_frame


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
