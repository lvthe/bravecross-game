# Man thanh tuu va nhiem vu ngay.
#
# Luat nam o MAY CHU (server/modules/battle.lua: bx.tasks, bx.claim_task,
# bx.claim_liveness). Man nay chi hien lai va gui yeu cau nhan — may chu kiem
# lai dieu kien luc nhan, client bao "da dat" cung vo ich.
#
# Kich thuoc va anh lay tu dong mau cua ban goc (lAchieveTemplate,
# lDailyTaskTemplate: 760x105, o icon ui_background176/179, nut ui_button10).
# KHONG dung XggLayout de nhan ban dong mau: cay cha-con cua hai file .xgg nay
# dung lai SAI — ca khung man hinh (lAchieveLayer, lop cuon, bang danh sach)
# lot vao BEN TRONG dong mau, nhan ban ra thi moi dong mang theo mot ban sao
# ca man. Nen dung dong bang tay, theo dung so do cua dong mau.
#
# Nhu ban goc (CUIAchieve.Reflesh, CUIDailyTask.Reflesh): chi hien chuoi DANG
# LAM va DA DAT; chuoi da nhan het thi an; da dat xep len dau.
#
#   godot --path . ui/tasks.tscn -- --fake        xem bo cuc khong can may chu
extends Control

## Trang thai cua ban goc (Protocol.lua, AchieveState).
const DOING := 1
const DONE := 2
const CLEARED := 3

## Khung cua ban goc: lAchieveTaskUI / lDailyTaskUI, 840x520 dat o (110, 30)
## theo he Cocos — tuc (110, 90) ben Godot.
const FRAME := Rect2(110, 90, 840, 520)
const ROW := Vector2(760, 105)
const ROW_GAP := 6

## Mau chu cua ban goc (TTF_Content_Text_Special_Task_*): dang lam thi ten vang,
## mo ta nau; da dat thi ca hai sang.
const COL_NAME := Color8(255, 200, 92)
const COL_DESC := Color8(149, 131, 106)
const COL_DONE := Color8(253, 251, 186)
const COL_NOTE := Color(0.62, 0.62, 0.62)

## Icon tai nguyen (CUIPrizeResHelper cua ban goc). Vat pham la item_<id>.png.
const ICON_GOLD := "v6/ui_jinbi02.png"
const ICON_CONCENTRATE := "v6/ui_ronglujingyan02.png"

const PART_TEXT := {16: "vu khi", 17: "giap hoac giay", 18: "day chuyen hoac nhan"}

## Nhiem vu ngay dem so lan: [ten, mo ta]. 151-154 la cua game moi (xem
## GAME_DAILY trong sim/export_stats.py).
const COUNTER_TEXT := {
	103: ["Chinh chien", "Thang %d tran trong ngay"],
	113: ["Luyen tuong", "Nang cap tuong %d lan trong ngay"],
	151: ["Cuong hoa", "Cuong hoa trang bi %d lan trong ngay"],
	152: ["Tinh luyen", "Tinh luyen trang bi %d lan trong ngay"],
	153: ["Phan giai", "Phan giai vat pham %d lan trong ngay"],
	154: ["Ghep do", "Ghep do %d lan trong ngay"],
}

var tab := "achieve"
var payload: Dictionary = {}
var _busy := false
var _frame: Control = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _chest_box: Control = null
var _chest_label: Label = null
var _chest_bar: ProgressBar = null
var _chest_btn: Button = null

@onready var _header: Label = $Header
@onready var _tips: Label = $Tips


func _ready() -> void:
	var world := UiTheme.tex("ui_background135")
	if world != null:
		$Backdrop.texture = world
	$Back.pressed.connect(func(): Game.goto(Game.MENU))
	$TabAch.pressed.connect(func(): set_tab("achieve"))
	$TabDaily.pressed.connect(func(): set_tab("daily"))
	_build()
	if "--fake" in OS.get_cmdline_user_args():
		set_data(fake_data())
		return
	# Bo test dat co nay truoc khi gan man vao cay: khong dong toi mang.
	if has_meta("no_session"):
		return
	await Game.ensure_session()
	await _reload()


func _reload() -> void:
	if Game.session == null or not Game.session.online:
		payload = {}
		_tips.text = "Chua noi duoc may chu — thanh tuu va nhiem vu ngay do may chu giu."
		_refresh()
		return
	var r := await Game.session.tasks()
	if not r.ok:
		_tips.text = "Khong tai duoc: %s" % str(r.get("error", ""))
		return
	set_data(r.data)


func set_data(d: Dictionary) -> void:
	payload = d
	_refresh()


func set_tab(t: String) -> void:
	tab = t
	_refresh()


# ------------------------------------------------------------------ dung khung
func _build() -> void:
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.position = FRAME.position
	_frame.size = FRAME.size
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	move_child(_frame, 2)            # tren nen, duoi chu va nut
	_frame.add_child(_backing(FRAME.size))

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.custom_minimum_size = Vector2(ROW.x, 0)
	_list.add_theme_constant_override("separation", ROW_GAP)
	_scroll.add_child(_list)

	# Thanh nang dong + ruong, chi o bang nhiem vu ngay. Ban goc: thanh 280x28
	# ui_blood_05 va ruong ui_treasure03_01 trong khoi progress cua lDailyTaskUI.
	_chest_box = Control.new()
	_chest_box.name = "Chest"
	_chest_box.position = Vector2(40, 420)
	_chest_box.size = Vector2(ROW.x, 90)
	_frame.add_child(_chest_box)
	_chest_label = _label(_chest_box, "ChestLabel", "", Rect2(0, 4, 520, 30),
			COL_NAME, 18)
	_chest_bar = ProgressBar.new()
	_chest_bar.name = "ChestBar"
	_chest_bar.show_percentage = false
	_chest_bar.position = Vector2(0, 42)
	_chest_bar.size = Vector2(520, 24)
	_chest_box.add_child(_chest_bar)
	_chest_btn = Button.new()
	_chest_btn.name = "ChestButton"
	_chest_btn.position = Vector2(580, 6)
	_chest_btn.size = Vector2(180, 78)
	_art(_chest_box, "v6/ui_treasure03_01.png", Rect2(580, 0, 180, 90))
	_chest_btn.pressed.connect(_on_chest)
	_chest_box.add_child(_chest_btn)


## Nen bo tron — ban goc ve nen bang CCLayerColorRoundRect ngay trong Lua, nen
## file bo cuc khong co; dung lai dung kieu do nhu man trang bi.
func _backing(sz: Vector2, tint := Color(0.07, 0.08, 0.10, 0.88)) -> Panel:
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.set_corner_radius_all(10)
	box.set_border_width_all(2)
	box.border_color = Color(0.42, 0.35, 0.22, 0.9)
	var pn := Panel.new()
	pn.name = "_backing"
	pn.size = sz
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.add_theme_stylebox_override("panel", box)
	return pn


# ---------------------------------------------------------------- danh sach
## Cac muc hien o bang dang mo, dung thu tu hien.
func rows() -> Array:
	var src = payload.get("daily" if tab == "daily" else "achievements", [])
	var out: Array = []
	if not src is Array:
		return out
	for v in src:
		if not v is Dictionary:
			continue
		var st := int(v.get("state", DOING))
		if st == DOING or st == DONE:
			out.append(v)
	out.sort_custom(_row_before)
	return out


## Da dat len truoc, roi theo so loai — dung ham sap xep cua CUIAchieve.
func _row_before(a: Dictionary, b: Dictionary) -> bool:
	var sa := int(a.get("state", DOING))
	var sb := int(b.get("state", DOING))
	if sa != sb:
		return sa == DONE
	return int(a.get("type", 0)) < int(b.get("type", 0))


func _refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var daily := tab == "daily"
	_scroll.position = Vector2(40, 20)
	_scroll.size = Vector2(ROW.x + 14, 390.0 if daily else 480.0)
	_chest_box.visible = daily

	var shown := rows()
	for v in shown:
		_list.add_child(_row(v))
	if shown.is_empty():
		var msg := "Chua co du lieu."
		if not payload.is_empty():
			msg = "Da xong nhiem vu hom nay." if daily \
					else "Da nhan het cac chuoi thanh tuu dang co."
		_label(_list, "Empty", msg, Rect2(0, 0, ROW.x, 40), COL_NOTE, 18)

	if daily:
		_header.text = "Nhiem vu ngay — lam moi sau %s" % _hm(int(payload.get("resetIn", 0)))
		_refresh_chest()
	else:
		var n_done := 0
		var n_doing := 0
		var n_clear := 0
		var src = payload.get("achievements", [])
		for v in (src if src is Array else []):
			match int(v.get("state", DOING)):
				DONE: n_done += 1
				CLEARED: n_clear += 1
				_: n_doing += 1
		_header.text = "Thanh tuu — %d cho nhan, %d dang lam, %d chuoi da xong" \
				% [n_done, n_doing, n_clear]


## Mot dong, theo so do cua dong mau 760x105 (toa do Cocos da doi sang Godot).
func _row(v: Dictionary) -> Control:
	var t := int(v.get("type", 0))
	var st := int(v.get("state", DOING))
	var done := st == DONE
	var row := Control.new()
	row.name = "Row%d" % t
	row.custom_minimum_size = ROW
	row.size = ROW
	row.set_meta("type", t)
	row.set_meta("state", st)
	row.add_child(_backing(ROW, Color(0.13, 0.11, 0.07, 0.92) if done
			else Color(0.07, 0.08, 0.10, 0.88)))

	# O icon: nen 179 + khung 176 cua ban goc, anh phan thuong dau tien o giua.
	var prize = v.get("prize", {})
	if not prize is Dictionary:
		prize = {}
	var parts := _prize_parts(prize)
	_art(row, "v6/ui_background179.png", Rect2(20, 14, 76, 77))
	if not parts.is_empty():
		_art(row, parts[0]["icon"], Rect2(30, 24, 56, 56))
	_art(row, "v6/ui_background176.png", Rect2(20, 14, 76, 77))

	_label(row, "Name", _title(v), Rect2(110, 7, 200, 40),
			COL_DONE if done else COL_NAME, 20)
	_label(row, "Desc", _desc(v), Rect2(310, 7, 330, 40),
			COL_DONE if done else COL_DESC, 16)
	# Tien do "(dang co/can)" nhu ban goc; da dat thi thay bang nut nhan.
	if not done:
		_label(row, "Progress", "(%d/%d)" % [int(v.get("current", 0)),
				int(v.get("total", 1))], Rect2(110, 55, 95, 30), COL_DESC, 16)

	# Phan thuong: toi da 3 o nhu ban goc (reward1..3).
	var x := 210.0
	for i in mini(parts.size(), 3):
		var p: Dictionary = parts[i]
		_art(row, p["icon"], Rect2(x, 50, 40, 40))
		_label(row, "Reward%d" % (i + 1), "X%d" % int(p["count"]),
				Rect2(x + 44, 55, 90, 30), COL_DONE if done else COL_DESC, 15)
		x += 140.0
	var ng = prize.get("notGranted", [])
	if ng is Array and not ng.is_empty():
		_label(row, "NotGranted", "chua trao: " + ", ".join(ng),
				Rect2(110, 86, 520, 18), COL_NOTE, 12)

	# Nut nhan chi hien khi da dat — CUIAchieve an btnGetAchieve khi Doing.
	if done:
		var b := Button.new()
		b.name = "Claim"
		b.text = "Nhan"
		b.position = Vector2(640, 27)
		b.size = Vector2(101, 51)
		_button_art(b, "v6/ui_button10.png")
		b.pressed.connect(_on_claim.bind(t))
		row.add_child(b)
	return row


## Ten nhiem vu. Chu ban goc (AchieveUI_Name_*) co ban quyen nen khong dua vao;
## ten o day sinh tu chinh dieu kien cua buoc.
func _title(v: Dictionary) -> String:
	var t := int(v.get("type", 0))
	match String(v.get("kind", "")):
		"chapter":
			return "Chinh phuc chuong %d" % int(v.get("target", 0))
		"heroLevelCount":
			return "Tuong cap %d" % int(v.get("arg", 0))
		"heroLevelTo":
			return "Luyen binh cap %d" % int(v.get("arg", 0))
		"maxEquipQuality":
			return "Pham chat trang bi"
		"equipLevelCount":
			return "Ren %s" % PART_TEXT.get(t, "trang bi")
		"counter":
			if COUNTER_TEXT.has(t):
				return COUNTER_TEXT[t][0]
	return "Nhiem vu %d" % t


func _desc(v: Dictionary) -> String:
	var t := int(v.get("type", 0))
	var target := int(v.get("target", 0))
	var arg := int(v.get("arg", 0))
	match String(v.get("kind", "")):
		"chapter":
			return "Qua chuong %d (moc %d, buoc %d/%d)" % [target, arg,
					int(v.get("index", 1)), int(v.get("steps", 1))]
		"heroLevelCount", "heroLevelTo":
			return "%d tuong dat cap %d" % [target, arg]
		"maxEquipQuality":
			return "Co mot mon trang bi pham %d" % target
		"equipLevelCount":
			return "%d mon %s dat cap %d" % [target, PART_TEXT.get(t, "trang bi"), arg]
		"counter":
			if COUNTER_TEXT.has(t):
				return COUNTER_TEXT[t][1] % target
	return ""


## Phan thuong -> [{icon, count}]. Vang tinh ca phan "vang theo cap" bang cap
## nguoi choi ma may chu vua bao — dung so se vao tui.
func _prize_parts(prize: Dictionary) -> Array:
	var out: Array = []
	var gold := int(prize.get("gold", 0)) \
			+ int(prize.get("goldPerLevel", 0)) * int(payload.get("playerLevel", 1))
	if gold > 0:
		out.append({"icon": ICON_GOLD, "count": gold})
	var c := int(prize.get("concentrate", 0))
	if c > 0:
		out.append({"icon": ICON_CONCENTRATE, "count": c})
	var items = prize.get("items", [])
	if items is Array:
		for pair in items:
			if pair is Array and pair.size() >= 2:
				out.append({"icon": "item_%d.png" % int(pair[0]), "count": int(pair[1])})
	return out


# --------------------------------------------------------------------- ruong
func _refresh_chest() -> void:
	var c = payload.get("chest", {})
	if not c is Dictionary:
		c = {}
	var live := int(c.get("liveness", 0))
	if bool(c.get("done", false)) or c.get("need") == null:
		_chest_label.text = "Nang dong %d — hom nay da nhan ruong" % live
		_chest_bar.max_value = 1
		_chest_bar.value = 1
		_chest_btn.disabled = true
		_chest_btn.text = "Da nhan"
		return
	var need := int(c.get("need", 1))
	_chest_label.text = "Nang dong %d/%d" % [live, need]
	_chest_bar.max_value = need
	_chest_bar.value = mini(live, need)
	var ready := bool(c.get("ready", false))
	_chest_btn.disabled = not ready
	_chest_btn.text = "Mo ruong" if ready else "Chua du"
	_chest_btn.modulate = Color(1, 1, 1) if ready else Color(0.65, 0.65, 0.65)
	# Noi thang khi ruong khong the voi toi: moi nhiem vu ngay cho 1 diem, ma
	# so nhiem vu ngay lam duoc con it hon so diem can.
	var src = payload.get("daily", [])
	var most := 0
	for v in (src if src is Array else []):
		most += int(v.get("liveness", 0))
	if most < need:
		_tips.text = ("Moi co %d nhiem vu ngay, ruong can %d diem nang dong — "
				+ "hom nay chua the mo.") % [most, need]


# -------------------------------------------------------------------- nhan
func _on_claim(t: int) -> void:
	if _busy or Game.session == null:
		return
	_busy = true
	var r := await Game.session.claim_task(t)
	_busy = false
	if not r.ok:
		_tips.text = "Khong nhan duoc: %s" % str(r.get("error", ""))
		return
	_tips.text = "Da nhan: " + _granted_text(r.data.get("granted", {}))
	await _reload()


func _on_chest() -> void:
	if _busy or Game.session == null:
		return
	_busy = true
	var r := await Game.session.claim_liveness()
	_busy = false
	if not r.ok:
		_tips.text = "Khong mo duoc ruong: %s" % str(r.get("error", ""))
		return
	_tips.text = "Mo ruong: " + _granted_text(r.data.get("granted", {}))
	await _reload()


## Cai THUC SU vao tui, do may chu tra ve — khong tu tinh lai.
func _granted_text(g) -> String:
	if not g is Dictionary:
		return "khong co gi"
	var bits: Array = []
	if int(g.get("gold", 0)) > 0:
		bits.append("+%d vang" % int(g["gold"]))
	if int(g.get("concentrate", 0)) > 0:
		bits.append("+%d tinh hoa" % int(g["concentrate"]))
	var items = g.get("items", [])
	for it in (items if items is Array else []):
		if int(it.get("count", 0)) > 0:
			bits.append("vat pham %d x%d" % [int(it.get("id", 0)), int(it.get("count", 0))])
	var lost = g.get("lost", [])
	for it in (lost if lost is Array else []):
		bits.append("tui day, mat vat pham %d x%d" % [int(it.get("id", 0)),
				int(it.get("count", 0))])
	var ng = g.get("notGranted", [])
	if ng is Array and not ng.is_empty():
		bits.append("chua trao: " + ", ".join(ng))
	return ", ".join(bits) if not bits.is_empty() else "khong co gi"


# ----------------------------------------------------------------- tien ich
func _art(parent: Control, frame: String, rect: Rect2) -> TextureRect:
	var tex := UiFrames.get_frame(frame)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = rect.position
	tr.size = rect.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## Nut mang anh cua ban goc lam nen. Godot ve chu CUA CHINH nut, nen dat anh
## vao stylebox chu khong them node con — node con se de len chu.
func _button_art(b: Button, frame: String) -> void:
	var tex := UiFrames.get_frame(frame)
	if tex == null:
		return
	for s in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _label(parent: Control, nm: String, text: String, rect: Rect2, col: Color,
		font_size: int) -> Label:
	var lb := Label.new()
	lb.name = nm
	lb.text = text
	lb.position = rect.position
	lb.size = rect.size
	lb.custom_minimum_size = rect.size if parent is BoxContainer else Vector2.ZERO
	lb.clip_text = true
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_font_size_override("font_size", font_size)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lb)
	return lb


func _hm(sec: int) -> String:
	sec = maxi(0, sec)
	return "%d gio %02d phut" % [sec / 3600, (sec % 3600) / 60]


## Mot ban tra loi bx.tasks bia ra, chi de xem bo cuc va cho bo test.
static func fake_data() -> Dictionary:
	return {
		"achievements": [
			{"type": 6, "family": "achieve", "kind": "chapter", "index": 5,
				"steps": 48, "state": DOING, "current": 0, "total": 1,
				"target": 2, "arg": 3,
				"prize": {"gold": 0, "goldPerLevel": 0, "concentrate": 0,
					"items": [[14, 20], [4, 2]], "notGranted": []}},
			{"type": 9, "family": "achieve", "kind": "heroLevelCount", "index": 3,
				"steps": 3, "state": DONE, "current": 3, "total": 3,
				"target": 3, "arg": 10,
				"prize": {"gold": 0, "goldPerLevel": 0, "concentrate": 0,
					"items": [[24, 1], [51, 5]], "notGranted": []}},
			{"type": 14, "family": "achieve", "kind": "heroLevelTo", "index": 2,
				"steps": 8, "state": DOING, "current": 3, "total": 5,
				"target": 5, "arg": 10,
				"prize": {"gold": 10000, "goldPerLevel": 0, "concentrate": 0,
					"items": [], "notGranted": ["kim cuong x50"]}},
			{"type": 16, "family": "achieve", "kind": "equipLevelCount", "index": 10,
				"steps": 10, "state": CLEARED, "current": 0, "total": 1,
				"parts": [1]},
		],
		"daily": [
			{"type": 103, "family": "daily", "kind": "counter",
				"counter": "AnyChapterPassCountDaily", "liveness": 1, "index": 1,
				"steps": 1, "state": DOING, "current": 4, "total": 10, "target": 10,
				"prize": {"gold": 0, "goldPerLevel": 200, "concentrate": 0,
					"items": [], "notGranted": ["kinh nghiem tai khoan x50"]}},
			{"type": 113, "family": "daily", "kind": "counter",
				"counter": "PracticeHeroCountDaily", "liveness": 1, "index": 1,
				"steps": 1, "state": DONE, "current": 1, "total": 1, "target": 1,
				"prize": {"gold": 0, "goldPerLevel": 200, "concentrate": 0,
					"items": [], "notGranted": ["kinh nghiem tai khoan x20"]}},
		],
		"chest": {"liveness": 1, "claimed": 0, "need": 5, "ready": false,
			"done": false},
		"playerLevel": 12,
		"resetIn": 5 * 3600 + 12 * 60,
	}
