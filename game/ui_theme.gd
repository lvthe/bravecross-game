# Theme dung art giao dien cua ban goc.
#
# Dung bang MA chu khong phai file .tres: theme nay chi la mot phep noi giua
# ten control cua Godot va ten file art, viet ra ma thi doc duoc lien va sua
# duoc bang mot dong. File .tres cho viec nay chi tho hon.
#
# Art lay tu assets/png/background cua ban goc (work/scenes.py --raw). Cac tam
# nay la anh mot mieng, khong phai 9-patch san, nen bien duoc dat bang tay —
# xem BORDERS ben duoi.
#
# Khong co art thi theme tra ve null va game dung giao dien mac dinh cua Godot.
class_name UiTheme
extends RefCounted

const DIR := "res://assets_ref/ui/"

## Khung go co nen giay, 111x62 — dung la mot cai nut.
## (Da thu ui_background188 truoc: hoa ra chi la mot dai xam mo, keo ra thanh
## vach mong chu khong ra hinh nut nao.)
const BTN := "ui_background134"
## Cuon giay 688x800, dung lam nen bang danh sach.
const PANEL := "ui_background62"

## Bien 9-patch (ngang, doc). Dat bang tay sau khi nhin anh: khung go cua nut
## day khoang 14 px, con hai truc cuon giay thi to hon nhieu.
const BTN_BORDER := Vector2i(16, 14)
const PANEL_BORDER := Vector2i(58, 72)


static func tex(name: String) -> Texture2D:
	var p := DIR + name + ".png"
	if not ResourceLoader.exists(p):
		return null
	var t := ResourceLoader.load(p)
	return t if t is Texture2D else null


static func _box(name: String, border: Vector2i, tint: Color) -> StyleBoxTexture:
	var t := tex(name)
	if t == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = border.x
	s.texture_margin_right = border.x
	s.texture_margin_top = border.y
	s.texture_margin_bottom = border.y
	# Chua noi dung cach mep mot chut, khong thi chu dinh vao vien.
	s.content_margin_left = border.x + 6
	s.content_margin_right = border.x + 6
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.modulate_color = tint
	return s


## Tra ve theme, hoac null neu chua xuat art giao dien.
static func build() -> Theme:
	if tex(BTN) == null:
		return null
	var th := Theme.new()

	var normal := _box(BTN, BTN_BORDER, Color(1, 1, 1))
	var hover := _box(BTN, BTN_BORDER, Color(1.25, 1.2, 1.1))
	var pressed := _box(BTN, BTN_BORDER, Color(0.8, 0.78, 0.75))
	# Chuong khoa: xam han di de nhin phat la biet chua bam duoc.
	var disabled := _box(BTN, BTN_BORDER, Color(0.45, 0.45, 0.5, 0.75))
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed],
			["disabled", disabled], ["focus", hover]]:
		if pair[1] != null:
			th.set_stylebox(pair[0], "Button", pair[1])

	# Nen nut la giay sang, nen chu phai TOI. Dung mau kem nhu chu tren nen
	# tranh thi khong doc noi.
	th.set_color("font_color", "Button", Color(0.24, 0.15, 0.07))
	th.set_color("font_hover_color", "Button", Color(0.12, 0.08, 0.03))
	th.set_color("font_pressed_color", "Button", Color(0.24, 0.15, 0.07))
	th.set_color("font_disabled_color", "Button", Color(0.42, 0.36, 0.30))
	th.set_font_size("font_size", "Button", 15)

	var panel := _box(PANEL, PANEL_BORDER, Color(1, 1, 1, 0.97))
	if panel != null:
		th.set_stylebox("panel", "Panel", panel)
		th.set_stylebox("panel", "PanelContainer", panel)

	# Chu tren nen tranh: khong co vien thi doc rat met.
	th.set_color("font_color", "Label", Color(1, 0.97, 0.9))
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 5)
	th.set_font_size("font_size", "Label", 15)
	return th
