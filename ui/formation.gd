# Man the tran: chon the tran, nang cap no, va dat cho dung cho tung tuong.
#
# The tran la mot trong so it he thong cua ban goc con NGUYEN CA SO LIEU:
# KDBGameFormationConfig.xgg ghi ro moi cap cua moi the tran tang gi, bao nhieu,
# cho CHO DUNG nao (PlacementType 1/2/3 = hang truoc/giua/sau). Nen con so hien
# o day la cua ban goc, khong phai do ta dat.
#
# Cho dung khong phai trang tri: no quyet ca vi tri tren san (hang sau thi lau
# bi danh hon) lan buff nao cua the tran ap vao tuong do.
#
# Moi viec kiem deu o MAY CHU: bx.set_formation tu choi the tran chua mo,
# bx.upgrade_formation tu choi khi thieu vang, bx.set_placement tu choi cho
# dung ngoai 1..3. O day chi la giao dien.
extends Control

const TEAM_SIZE := 4

## Ten the tran cua ban goc la phien am Han-Viet. Dich cho de doc; y nghia lay
## tu chinh buff ma no cho, khong phai doan.
const NAME_VI := {
	"jichu": "Co ban",
	"heyi": "Hac Duc",
	"yanyue": "Yen Nguyet",
	"fangyuan": "Phuong Vien",
	"zhuixing": "Truy Tinh",
	"yulin": "Ngu Lam",
	"bagua": "Bat Quai",
	"tiangang": "Thien Cuong",
	"beidou": "Bac Dau",
	"wuxing": "Ngu Hanh",
	"zhenwuqijie": "Chan Vu",
	"ershibaxingxiu": "Nhi Thap Bat Tu",
}

## Ten truong buff -> chu tieng Viet. Chi liet ke cai mo hinh nay dung toi.
const BUFF_VI := {
	"hp": "mau", "hp_pct": "mau %", "ap": "cong", "dp": "giap",
	"dp_pct": "giap %", "dmg_pct": "sat thuong %", "taken_pct": "giam thuong %",
	"lifesteal": "hut mau %", "reflect": "phan don %",
}

@onready var _grid: GridContainer = $Scroll/Grid
@onready var _places: VBoxContainer = $Places
@onready var _status: Label = $Status

var _rows: Array = []


func _ready() -> void:
	var world := UiTheme.tex("ui_background135")
	if world != null:
		$Backdrop.texture = world
	$Buttons/Back.pressed.connect(func(): Game.goto(Game.MENU))
	await Game.ensure_session()
	await _reload()


func _reload() -> void:
	# Danh sach the tran do MAY CHU tra: cai nao da mo, cap may, gia nang tiep.
	# Client khong tu tinh cai nao — no chi ve.
	if Game.session != null and Game.session.online:
		var r := await Game.session.formations()
		_rows = r.data.get("formations", []) if r.ok else []
	else:
		_rows = []
	_build_places()
	_build_list()
	_refresh()


## Bon hang, moi hang mot tuong va ba nut cho dung.
func _build_places() -> void:
	for c in _places.get_children():
		c.queue_free()
	var roster: Array = Game.roster()
	for i in TEAM_SIZE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var who: String = str(roster[i]) if i < roster.size() else "(chua chon)"
		var lb := Label.new()
		lb.custom_minimum_size = Vector2(300, 26)
		lb.text = who
		row.add_child(lb)
		for spot in [1, 2, 3]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(150, 26)
			b.text = ["hang truoc", "hang giua", "hang sau"][spot - 1]
			b.disabled = i >= roster.size()
			b.pressed.connect(_on_place.bind(i, spot))
			row.add_child(b)
		_places.add_child(row)


func _build_list() -> void:
	for c in _grid.get_children():
		c.queue_free()
	if _rows.is_empty():
		var lb := Label.new()
		lb.text = "Chua noi duoc may chu nen chua co the tran."
		_grid.add_child(lb)
		return
	for e in _rows:
		var f: Dictionary = e
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var pick := Button.new()
		pick.custom_minimum_size = Vector2(600, 44)
		pick.text = _label(f)
		pick.disabled = not bool(f.get("owned", false))
		# To sang cai dang dung cho ro, giong man doi hinh.
		pick.modulate = Color(1.25, 1.1, 0.7) if bool(f.get("active", false)) \
				else Color(1, 1, 1)
		pick.pressed.connect(_on_pick.bind(String(f.get("name", ""))))
		row.add_child(pick)

		var up := Button.new()
		up.custom_minimum_size = Vector2(270, 44)
		up.text = _price_label(f)
		up.disabled = not _can_afford(f)
		up.pressed.connect(_on_upgrade.bind(String(f.get("name", ""))))
		row.add_child(up)

		_grid.add_child(row)


## Nhan the tran: ten, cap, va buff cua HANG TRUOC (hai hang kia thuong khac,
## nen ghi them mot dong ngan cho ba hang).
func _label(f: Dictionary) -> String:
	var key := String(f.get("name", ""))
	var vi: String = NAME_VI.get(key, key)
	var lv := int(f.get("level", 0))
	var top := int(f.get("maxLevel", 0))
	var owned := bool(f.get("owned", false))
	if not owned:
		return "%-18s  (chua mo)" % vi
	return "%-18s  cap %d/%d   %s" % [vi, lv, top, _buff_text(f)]


## Buff cua ba hang, gon lai mot dong.
func _buff_text(f: Dictionary) -> String:
	var parts: Array = []
	var keys := ["buffs", "buffs2", "buffs3"]
	for i in keys.size():
		var b: Dictionary = f.get(keys[i], {})
		if b.is_empty():
			continue
		var bits: Array = []
		for name in b:
			var v := float(b[name])
			if is_zero_approx(v):
				continue
			var vi: String = BUFF_VI.get(str(name), str(name))
			# Truong ket thuc bang "%" la phan tram, con lai la cong thang.
			bits.append("%s %s" % [vi, ("+%.1f%%" % (v * 100.0)) if vi.ends_with("%")
					else ("+%d" % int(round(v)))])
		if not bits.is_empty():
			parts.append("h%d: %s" % [i + 1, ", ".join(bits)])
	return "  |  ".join(parts) if not parts.is_empty() else "chua co buff"


func _price_label(f: Dictionary) -> String:
	if not bool(f.get("owned", false)):
		return "Mo: %d vang" % int(f.get("unlockGold", 0))
	if f.get("nextGold") == null:
		return "da toi cap toi da"
	return "Nang cap: %d vang" % int(f.get("nextGold", 0))


func _can_afford(f: Dictionary) -> bool:
	if Game.session == null or not Game.session.online:
		return false
	var cost: int
	if not bool(f.get("owned", false)):
		cost = int(f.get("unlockGold", 0))
	elif f.get("nextGold") == null:
		return false
	else:
		cost = int(f.get("nextGold", 0))
	return Game.session.gold() >= cost


func _on_pick(name: String) -> void:
	var r := await Game.session.set_formation(name)
	if not r.ok:
		_status.text = "Khong chon duoc: %s" % str(r.get("error", ""))
		return
	await _reload()


func _on_upgrade(name: String) -> void:
	var r := await Game.session.upgrade_formation(name)
	if not r.ok:
		_status.text = "Khong nang duoc: %s" % str(r.get("error", ""))
		return
	await _reload()


func _on_place(i: int, spot: int) -> void:
	var spots: Array = []
	for k in TEAM_SIZE:
		spots.append(Game.session.placement_of(k) if Game.session != null else 1)
	spots[i] = spot
	var r := await Game.session.set_placement(spots)
	if not r.ok:
		_status.text = "Khong doi duoc cho dung: %s" % str(r.get("error", ""))
		return
	_refresh()


func _refresh() -> void:
	if Game.session == null:
		_status.text = "chua co phien choi"
		return
	var spots: Array = []
	for k in TEAM_SIZE:
		spots.append(str(Game.session.placement_of(k)))
	var key := Game.session.formation()
	_status.text = "The tran: %s cap %d   |   cho dung: %s   |   %d vang" % [
			NAME_VI.get(key, key), Game.session.formation_level(),
			", ".join(spots), Game.session.gold()]
	# Nut cho dung: to sang cai dang chon cua tung tuong.
	for i in _places.get_child_count():
		var row := _places.get_child(i)
		for j in [1, 2, 3]:
			if row.get_child_count() > j:
				var b := row.get_child(j) as Button
				b.modulate = Color(1.25, 1.1, 0.7) \
						if Game.session.placement_of(i) == j else Color(1, 1, 1)
