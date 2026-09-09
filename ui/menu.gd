# Man chinh: chon chuong.
#
# Chuong khoa thi khong bam duoc. Luat "chi mo chuong ke tiep" nam o MAY CHU
# (bx.fight tu choi chuong chua mo), o day chi la hien thi — client co bi sua
# de bam duoc het thi may chu van tu choi.
extends Control

@onready var _list: VBoxContainer = $Scroll/List
@onready var _title: Label = $Title
@onready var _status: Label = $Status


func _ready() -> void:
	$Buttons/Roster.pressed.connect(_on_roster)
	$Buttons/Practice.pressed.connect(_on_practice)
	_title.text = "BraveCross"
	_status.text = "dang dang nhap..."
	await _refresh()


func _refresh() -> void:
	var ses := await Game.ensure_session()
	_status.text = ses.status_line()

	if not Game.last_fight.is_empty():
		var f: Dictionary = Game.last_fight
		var verdict: String = ["THANG", "THUA", "HOA"][int(f.get("result", 2))]
		var line := "Chuong %d: %s" % [int(f.get("chapter", 0)), verdict]
		if bool(f.get("unlockedNext", false)):
			line += "   —  mo duoc chuong tiep theo"
		_title.text = "BraveCross      %s" % line
		Game.last_fight = {}

	for c in _list.get_children():
		c.queue_free()

	if not ses.online:
		var l := Label.new()
		l.text = ("Khong noi duoc may chu nen chua co chuong nao.\n"
				+ "Bat may chu:  cd server  &&  docker compose up -d\n"
				+ "Van bam duoc \"Danh tap\" de xem tran.")
		_list.add_child(l)
		return

	var chapters := await Game.chapters(true)
	for ch in chapters:
		_list.add_child(_row(ch))


func _row(ch: Dictionary) -> Control:
	var n := int(ch.get("n", 0))
	var unlocked := bool(ch.get("unlocked", false))
	var cleared := bool(ch.get("cleared", false))

	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 38)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not unlocked
	var mark := "[xong]" if cleared else ("      " if unlocked else "[khoa]")
	b.text = "  %s  Chuong %-3d   dich manh x%.2f   %s" % [
			mark, n, float(ch.get("power", 1.0)),
			", ".join(ch.get("enemies", []))]
	if unlocked:
		b.pressed.connect(_on_chapter.bind(n))
	return b


func _on_chapter(n: int) -> void:
	Game.chapter = n
	Game.goto(Game.BATTLE)


func _on_practice() -> void:
	Game.chapter = 0
	Game.goto(Game.BATTLE)


func _on_roster() -> void:
	Game.goto(Game.ROSTER)
