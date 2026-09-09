# Man chon doi hinh: bam 4 tuong.
#
# Danh sach tuong lay tu bo du lieu chien dau (data_ref), khong phai tu thu muc
# art — de client va may chu luon noi ve cung mot tap tuong.
#
# Viec kiem tra nam o MAY CHU: bx.set_roster tu choi ten khong co va tu choi
# doi hinh khong du 4 nguoi. O day chi la giao dien.
extends Control

const TEAM_SIZE := 4

@onready var _grid: GridContainer = $Scroll/Grid
@onready var _picked_label: Label = $Picked
@onready var _save: Button = $Buttons/Save

var _picked: Array = []


func _ready() -> void:
	var world := UiTheme.tex("ui_background135")
	if world != null:
		$Backdrop.texture = world
	_save.pressed.connect(_on_save)
	$Buttons/Back.pressed.connect(func(): Game.goto(Game.MENU))
	await Game.ensure_session()
	_picked = Game.roster().duplicate()
	_build()


func _build() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for name in Game.hero_names():
		var b := Button.new()
		b.custom_minimum_size = Vector2(258, 46)
		b.toggle_mode = true
		b.button_pressed = _picked.has(name)
		b.text = _label(name)
		_mark(b, b.button_pressed)
		b.toggled.connect(_on_toggle.bind(name, b))
		_grid.add_child(b)
	_refresh()


## Nhan tuong: ten kem hai bac quan trong nhat, de con biet duong ma chon.
func _label(hero_name: String) -> String:
	var row: Dictionary = Game.combat.heroes.get(hero_name, {})
	return "%-20s cong %d  thu %d" % [
			hero_name, int(row.get("AttackCapability", 0)),
			int(row.get("Viability", 0))]


## Nut bam roi va nut chua bam chi khac nhau chut mau, nhin khong ra dang chon
## ai. To sang han len cho ro.
func _mark(b: Button, on: bool) -> void:
	b.modulate = Color(1.25, 1.1, 0.7) if on else Color(1, 1, 1)


func _on_toggle(pressed: bool, hero_name: String, b: Button) -> void:
	if pressed:
		if _picked.size() >= TEAM_SIZE:
			b.button_pressed = false     # da du 4, bo bot roi hay chon
			return
		if not _picked.has(hero_name):
			_picked.append(hero_name)
	else:
		_picked.erase(hero_name)
	_mark(b, b.button_pressed)
	_refresh()


func _refresh() -> void:
	_picked_label.text = "Da chon %d/%d:   %s" % [
			_picked.size(), TEAM_SIZE, ", ".join(_picked)]
	_save.disabled = _picked.size() != TEAM_SIZE


func _on_save() -> void:
	_save.disabled = true
	_save.text = "dang luu..."
	var r := await Game.session.set_roster(_picked)
	if r.ok:
		Game.goto(Game.MENU)
		return
	_picked_label.text = "Khong luu duoc: %s" % str(r.get("error", ""))
	_save.text = "Luu"
	_save.disabled = false
