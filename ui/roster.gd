# Man chon doi hinh: bam 4 tuong.
#
# Danh sach tuong lay tu bo du lieu chien dau (data_ref), khong phai tu thu muc
# art — de client va may chu luon noi ve cung mot tap tuong.
#
# Viec kiem tra nam o MAY CHU: bx.set_roster tu choi ten khong co va tu choi
# doi hinh khong du 4 nguoi. O day chi la giao dien.
extends Control

const TEAM_SIZE := 4
## Phai khop LEVEL_COST va maxLevel ben server/modules/battle.lua. May chu van
## la ben kiem; hai so nay chi de ve nut cho dung.
const LEVEL_COST := 40
const MAX_LEVEL := 40

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
	for hero_name in Game.hero_names():
		# Moi tuong mot hang: nut chon (rong) + nut nang cap (nho).
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var b := Button.new()
		# Mot cot cho de doc: 690 + 4 + 96 = 790, vua khung cuon rong 800.
		b.custom_minimum_size = Vector2(690, 46)
		b.toggle_mode = true
		b.button_pressed = _picked.has(hero_name)
		b.text = _label(hero_name)
		_mark(b, b.button_pressed)
		b.toggled.connect(_on_toggle.bind(hero_name, b))
		row.add_child(b)

		var up := Button.new()
		up.custom_minimum_size = Vector2(96, 46)
		up.text = "+%d vang" % _price(hero_name)
		up.disabled = not _can_afford(hero_name)
		up.pressed.connect(_on_level_up.bind(hero_name))
		row.add_child(up)

		_grid.add_child(row)
	_refresh()


## Gia nang mot cap. May chu moi la ben quyet dinh; o day chi de hien nut.
func _price(hero_name: String) -> int:
	return LEVEL_COST * _level(hero_name)


func _level(hero_name: String) -> int:
	return Game.session.level_of(hero_name) if Game.session != null else 1


func _can_afford(hero_name: String) -> bool:
	if Game.session == null or not Game.session.online:
		return false
	if _level(hero_name) >= MAX_LEVEL:
		return false
	return Game.session.gold() >= _price(hero_name)


func _on_level_up(hero_name: String) -> void:
	var r := await Game.session.level_up(hero_name)
	if not r.ok:
		_picked_label.text = "Khong nang cap duoc: %s" % str(r.get("error", ""))
		return
	_build()


## Ky nang rieng, dich sang tieng Viet cho de chon. Ban goc chi luu TEN ky
## nang (phien am Han-Viet); hieu ung la thiet ke cua ta — xem sim/battle.py.
const SKILL_VI := {
	"NuQi": "no khi: ky nang no som",
	"GongSu": "cong toc: danh nhanh",
	"ShengMing": "sinh menh: nhieu mau",
	"TieBi": "thiet bich: chiu it don",
	"BaoJi": "bao kich: chi mang cao",
	"PoJia": "pha giap: xuyen giap",
	"FangYu": "phong ngu: giap day",
	"GongJi": "cong kich: don manh",
	"ShiXue": "thi huyet: hut mau",
}


## Nhan tuong: ten, hai bac quan trong nhat, va ky nang rieng.
func _label(hero_name: String) -> String:
	var row: Dictionary = Game.combat.heroes.get(hero_name, {})
	var sk := String(row.get("TalentSkill", ""))
	# Ky nang chua dat hieu ung thi ghi ten tran, khong bia nghia cho no.
	var note: String = SKILL_VI.get(sk, sk if sk != "" else "-")
	return "%-20s Lv%-3d  cong %d  thu %d   %s" % [
			hero_name, _level(hero_name), int(row.get("AttackCapability", 0)),
			int(row.get("Viability", 0)), note]


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
	# Cot so la bac cong/thu.
	_picked_label.text = "Da chon %d/%d:   %s      |      %d vang" % [
			_picked.size(), TEAM_SIZE, ", ".join(_picked),
			Game.session.gold() if Game.session != null else 0]
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
