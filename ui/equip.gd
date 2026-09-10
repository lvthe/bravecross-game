# Man trang bi — dung DUNG bo cuc man UI_Equipment cua ban goc.
#
# Khong uom tay theo anh chup: toa do, kich thuoc, diem neo va anh deu doc tu
# UI_Equipment.xgg (qua layout_ref/UI_Equipment_960_640.json). Bo cuc goc chia
# man lam hai:
#
#   lEquipmentMainUI     panel TRAI  — mot mon do: ten, cap, pham, chi so chinh,
#                                      thuoc tinh phu, luc chien
#   lEquipmentChildUI    panel PHAI  — bang hanh dong; trong do
#     lEquipmentIntensifyUI            cuong hoa: chi so hien tai / sau khi
#                                      cuong hoa, gia vang, nut bam
#
# Hai mui ten hai ben (btnHeroEquipUIToLeft / ToRight) la cua chinh ban goc —
# o day dung de chuyen giua 6 o do cua mot tuong.
#
# Ba mang khac cua ban goc (tinh luyen, ren, tay luyen, chuyen thuoc) co san
# trong bo cuc nhung CHUA co luat ben game moi, nen de an — hien nut ra ma bam
# khong lam gi thi te hon la khong hien.
#
# Moi con so deu do MAY CHU chot: bx.equipment cho biet co gi, bx.intensify tru
# vang va cuong hoa. Cho nay chi hien lai, va tinh truoc mot buoc de nguoi choi
# thay "sau khi cuong hoa duoc gi" — dung cong thuc trong battle/equipment.gd,
# ba ban da doi chieu nhau tung ca nen con so xem truoc khong the lech.
extends Control

const LAYOUT := "res://layout_ref/UI_Equipment_960_640.json"

## O do -> ten tieng Viet. Thu tu khop EQUIP_MAIN ben server/modules/battle.lua.
const PART_NAME := {
	1: "Vu khi", 2: "Giap", 3: "Day chuyen",
	4: "Nhan", 5: "Giay", 6: "O phu",
}

## Loai chi so -> chu hien. Chi liet ke loai ma game moi thuc su dung.
const PROP_NAME := {
	Equipment.AP: "Cong",
	Equipment.HP_LIMIT: "Mau",
	Equipment.DP_ADDITION: "Giap",
	Equipment.CRITICAL_STRIKE: "Chi mang",
}

## Ten node cua ban goc ma man nay tro toi. Day la HOP DONG voi file bo cuc:
## thieu mot cai la bo cuc doi hoac file sai, va phai bao to — mot man hinh
## thieu nut ma van chay la kieu hong kho tim nhat.
const NEED := [
	"lEquipmentUI", "lEquipmentChildUI", "lEquipmentMainUI",
	"lEquipmentIntensifyUI", "snsEquipIntensify",
	"btnHeroEquipUIToLeft", "btnHeroEquipUIToRight",
	"bmfEquipMainUIName", "bmfEquipMainUILevel", "ttfEquipMainUIQuality",
	"bmfEquipMainUIProperty", "bmfEquipMainUIPropertyAdd",
	"ttfEquipMainUIFightingCapacity", "ttfEquipMainUIRank",
	"ttfEquipMainUIRefine",
]

## Cac nhan khong co ten instance — ban goc dat ten LOP thanh chu mo ta. Do la
## cach duy nhat tro toi chung ma khong phai dem chi so con.
const CLS_AFTER_MAIN := "主属性"          # chi so chinh SAU khi cuong hoa
const CLS_AFTER_LEVEL := "装备等级"        # cap do, cot phai
const CLS_AFTER_ADD := "附加的值"          # phan cong them
const CLS_NOW_MAIN := "当前-主属性"        # chi so chinh HIEN TAI
const CLS_NOW_LEVEL := "当前-装备等级"
const CLS_NOW_ADD := "当前-附加的值"
const CLS_NOW_BOX := "当前属性的Layer"     # khoi "hien tai"
const CLS_AFTER_BOX := "强化后的属性Layer"   # khoi "sau khi cuong hoa"
## Ca hai khoi deu co mot nhan ten CUNG TEN LOP nay — phai tim trong tung khoi.
const CLS_TITLE := "名字(这个位置决定了其他3个元素的位置)"
const CLS_COST := "强化消耗"               # khoi gia vang
const CLS_MAXED := "强化到达最高级"          # bao da toi cap cao nhat

## Man nay lam viec duoc ma khong can may chu: set_data() nhan thang du lieu.
## Nho vay bo test chay duoc khong can Nakama (xem tools/verify_equip.gd).
var payload: Dictionary = {}
var heroes: Array = []
var hero_i := 0
var part := 1
var gold := 0
var max_intensify := 200

var ui: Control = null
var _busy := false

@onready var _header: Label = $Header
@onready var _tips: Label = $Tips


func _ready() -> void:
	$Bg.color = Color(0.106, 0.118, 0.145)
	$Back.pressed.connect(func(): Game.goto(Game.MENU))
	$PrevHero.pressed.connect(func(): _step_hero(-1))
	$NextHero.pressed.connect(func(): _step_hero(1))
	_build()
	# Xem thu man hinh ma khong can may chu:
	#   godot --path . ui/equip.tscn -- --fake
	# Dung de chup anh va soi bo cuc; du lieu la mon do bia ra.
	if "--fake" in OS.get_cmdline_user_args():
		set_data(_fake(), ["MaChao", "GanNing"])
		return
	await _reload()


## Mot ban tra loi bx.equipment bia ra, chi de xem bo cuc.
func _fake() -> Dictionary:
	var mk := func(part: int, prop: int, v: float, lv: int, iv: int,
			aps: Array) -> Dictionary:
		var e := Equipment.new(part, prop, v, lv, iv, 2)
		var out: Array = []
		for a in aps:
			e.appends.append(a)
			out.append({"type": a[0], "value": a[1]})
		return {"part": part, "level": lv, "intensify": iv, "quality": 2,
				"main": {"type": prop, "value": v}, "appends": out,
				"capacity": e.capacity(),
				"nextCost": ceili(Equipment.intensify_cost(iv + 1))}
	return {
		"gold": 1240, "maxIntensify": 200,
		"equipment": {
			"MaChao": [
				mk.call(1, Equipment.AP, 118.4, 7, 12,
						[[Equipment.CRITICAL_STRIKE, 0.0132]]),
				mk.call(2, Equipment.HP_LIMIT, 264.0, 5, 3, []),
			],
			"GanNing": [mk.call(1, Equipment.AP, 41.2, 6, 0, [])],
		},
	}


# ------------------------------------------------------------------ bo cuc
func _build() -> void:
	ui = XggLayout.build(LAYOUT)
	if ui == null:
		_tips.text = ("Chua co %s — sinh bang:\n" % LAYOUT
				+ "python ../brave-cross/work/layout.py --all --out layout_ref")
		return
	add_child(ui)
	move_child(ui, 1)          # tren nen, duoi cac nut cua ta

	var missing: Array = []
	for n in NEED:
		if XggLayout.find_node(ui, n) == null:
			missing.append(n)
	if not missing.is_empty():
		push_error("man trang bi: bo cuc thieu node %s" % str(missing))
		_tips.text = "bo cuc thieu node: %s" % ", ".join(missing)
		return

	# Ban goc an gan het roi de Lua bat dung cai can. Bat ba lop ta dung, va
	# CHI ba lop do — bat het thi 5 bang hanh dong ve chong len nhau.
	for n in ["lEquipmentUI", "lEquipmentMainUI", "lEquipmentChildUI",
			"lEquipmentIntensifyUI"]:
		var node := XggLayout.find_node(ui, n)
		if node != null:
			XggLayout.show_branch(node, ui)

	# Ban goc dat VI TRI cua chinh hop thoai tu Lua; trong file bo cuc no nam o
	# x = -2, nen mui ten trai bi cat mat mot nua. Day sang phai cho du.
	var dlg := XggLayout.find_node(ui, "lEquipmentUI")
	if dlg != null:
		dlg.position.x += 40.0

	# Nen hai panel. KHONG co trong file bo cuc: ban goc ve nen bang
	# CCLayerColorRoundRect ngay trong ma Lua (339 cho tren 296 man), mau va do
	# trong la tham so truyen luc chay. Dung lai dung co che do — mot khoi bo
	# tron toi — chu khong di muon mot tam anh khac roi bao la cua ban goc.
	_backing(XggLayout.find_node(ui, "lEquipmentMainUI"))
	_backing(XggLayout.find_node(ui, "lEquipmentIntensifyUI"))

	# Anh cua nut nam san trong bo cuc nhung DE AN: ban goc bat dung trang thai
	# can luc chay. Ta chi dung mot trang thai nen bat len la du.
	for n in ["snsEquipIntensify", "btnHeroEquipUIToLeft", "btnHeroEquipUIToRight"]:
		_show_art(XggLayout.find_node(ui, n))
	_button_art(XggLayout.find_node(ui, "snsEquipIntensify"), "v6/ui_button01.png")

	_click(XggLayout.find_node(ui, "btnHeroEquipUIToLeft"), func(): _step_part(-1))
	_click(XggLayout.find_node(ui, "btnHeroEquipUIToRight"), func(): _step_part(1))
	_click(XggLayout.find_node(ui, "snsEquipIntensify"), _on_intensify)
	# Tay luyen tu dong la he chua co luat — an di thay vi de nut cho co.
	var auto := XggLayout.find_node(ui, "snsEquipAutoIntensify")
	if auto != null:
		auto.visible = false


## Nen bo tron dat SAU mot panel cua bo cuc.
func _backing(node: Control, tint := Color(0.07, 0.08, 0.10, 0.88)) -> void:
	if node == null or node.has_node("_backing"):
		return
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.border_width_left = 2
	box.border_width_right = 2
	box.border_width_top = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.42, 0.35, 0.22, 0.9)
	var pn := Panel.new()
	pn.name = "_backing"
	pn.size = node.size
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.add_theme_stylebox_override("panel", box)
	node.add_child(pn)
	node.move_child(pn, 0)


## Bat anh cua mot nut len. Trong bo cuc, nut la mot Control tron con anh nam
## o node con va bi an san.
func _show_art(node: Control) -> void:
	if node == null:
		return
	for c in node.get_children():
		if c is TextureRect and (c as TextureRect).texture != null:
			c.visible = true


## Dat anh cho mot nut ma bo cuc KHONG mang anh.
##
## Ban goc gan anh nut luc chay (573 cho goi setDisplayFrame), nen file bo cuc
## chi con cai khung rong. Chon theo dung kich thuoc: nut 143x61 cua ban goc
## la v6/ui_button01.png, dung bang be rong tung pixel.
func _button_art(node: Control, frame: String) -> void:
	if node == null or node.has_node("_art"):
		return
	var tex := UiFrames.get_frame(frame)
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.name = "_art"
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = node.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(tr)
	node.move_child(tr, 0)


## Bat mot node cua bo cuc thanh bam duoc. Bo cuc tra ve node MOUSE_FILTER
## IGNORE het (chung chi la hinh), nen phai mo tung cai ta thuc su dung.
func _click(node: Control, fn: Callable) -> void:
	if node == null:
		return
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			fn.call())


## Mot so nhan trong bo cuc goc khong noi duoc chung la nhan: truong "lop" cua
## chung la chu tieng Trung mo ta ("当前-主属性"), khong phai CCLabelTTF, nen
## XggLayout dung ra Control tron. Gan mot Label vao lam con — chi mot lan.
func _ensure_label(node: Control) -> Label:
	if node == null:
		return null
	if node is Label:
		return node
	for c in node.get_children():
		if c is Label and c.name == "_text":
			return c
	var lb := Label.new()
	lb.name = "_text"
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nhan goc thuong rong 0 (co gian theo chu) nen khong the neo theo o cha.
	lb.position = Vector2.ZERO
	node.add_child(lb)
	return lb


func _label(node: Control, txt: String, center := false) -> void:
	if node == null:
		return
	if not (node is Label):
		var lb := _ensure_label(node)
		if lb != null:
			lb.text = txt
			lb.visible = txt != ""
			node.visible = true
			# Node cha rong 0 nen chinh no khong bu duoc gi cho diem neo —
			# lay so neo cua cha ma dat cho nhan.
			_fit(lb, node, center)
		return
	if node is Label:
		var lb := node as Label
		lb.text = txt
		lb.visible = txt != ""
		lb.autowrap_mode = TextServer.AUTOWRAP_OFF
		_fit(lb, null, center)


## Cho nhan tu do kich thuoc, roi bu lai theo DIEM NEO cua ban goc.
##
## Rat nhieu nhan trong file bo cuc ghi rong 0 (Cocos cho chu tu do kich
## thuoc), nen phep doi truc cua XggLayout khong tru duoc gi cho diem neo —
## chu bi dat lech sang phai, co cai tran ca ra ngoai man. Bu tay o day: vi tri
## ma bo cuc dat chinh la DIEM NEO, nen chi viec lui lai theo be rong that.
func _fit(lb: Label, anchor_from: Control = null, center := false) -> void:
	var src := anchor_from if anchor_from != null else lb
	var a := src.get_meta("cocos", Vector4(0, 0, 0, 0)) as Vector4
	if not lb.has_meta("anchor_pos"):
		lb.set_meta("anchor_pos", lb.position)
	var at := lb.get_meta("anchor_pos") as Vector2
	var want := lb.get_minimum_size()
	if lb.size.x <= 1.0 or anchor_from != null:
		lb.size.x = want.x
		# Chi lui theo diem neo khi chu NGAN (bang cuong hoa: "Cong", "+12",
		# "176.9") — do la kieu ban goc dat. Con nhung o ma ban goc chi de mot
		# con so, ta phai viet ca chu tieng Viet vao, canh giua thi tran ca ra
		# ngoai mep panel; nhung cho do bam trai. Da thu ca hai.
		lb.position.x = at.x - (a.z * want.x if center else 0.0)
	if lb.size.y <= 1.0 or anchor_from != null:
		lb.size.y = maxf(want.y, 22.0)
		lb.position.y = at.y - (1.0 - a.w) * (lb.size.y - want.y)


func _by_cls(cls: String, txt: String) -> void:
	_label(XggLayout.find_by_cls(ui, cls), txt)


## Tra nhan theo ten lop nhung CHI trong mot khoi. Hai khoi "hien tai" va "sau
## khi cuong hoa" co nhung node cung ten lop ("名字..."), nen tim tu goc se ra
## nham khoi.
func _in(parent_cls: String, child_cls: String, txt: String) -> void:
	var box := XggLayout.find_by_cls(ui, parent_cls)
	if box == null:
		return
	_label(XggLayout.find_by_cls(box, child_cls), txt, true)


# ------------------------------------------------------------------ du lieu
func _reload() -> void:
	var ses := await Game.ensure_session()
	if not ses.online:
		_tips.text = ("Khong noi duoc may chu nen chua doc duoc trang bi.\n"
				+ "Bat may chu:  cd server  &&  docker compose up -d")
		return
	var r := await ses.equipment()
	if not r.ok:
		_tips.text = "khong doc duoc trang bi: %s" % str(r.get("error", ""))
		return
	set_data(r.data, Game.roster())


## Nhan du lieu tu bx.equipment. Tach rieng khoi phan goi mang de con test
## duoc khong can may chu.
func set_data(p: Dictionary, hero_list: Array = []) -> void:
	payload = p
	gold = int(p.get("gold", 0))
	max_intensify = int(p.get("maxIntensify", 200))
	var owned: Dictionary = p.get("equipment", {})
	# Duyet theo doi hinh truoc (do la nhung tuong nguoi choi dang dung), roi
	# them tuong nao co do ma khong trong doi hinh.
	heroes = []
	for n in hero_list:
		heroes.append(str(n))
	for n in owned:
		if not heroes.has(str(n)):
			heroes.append(str(n))
	if heroes.is_empty():
		heroes = ["(chua co tuong)"]
	hero_i = clampi(hero_i, 0, heroes.size() - 1)
	_refresh()


func hero() -> String:
	return str(heroes[hero_i]) if hero_i < heroes.size() else ""


## Mon do dang o o `part` cua tuong dang xem. Rong = o trong.
func item() -> Dictionary:
	var owned: Dictionary = payload.get("equipment", {})
	var list = owned.get(hero(), [])
	if typeof(list) != TYPE_ARRAY:
		return {}
	for raw in list:
		if typeof(raw) == TYPE_DICTIONARY and int(raw.get("part", 0)) == part:
			return raw
	return {}


## Dung mot Equipment tu du lieu may chu gui, de tinh truoc buoc cuong hoa ke.
func _model(it: Dictionary) -> Equipment:
	var m: Dictionary = it.get("main", {})
	var e := Equipment.new(int(it.get("part", part)),
			int(m.get("type", Equipment.AP)), float(m.get("value", 0.0)),
			int(it.get("level", 1)), int(it.get("intensify", 0)),
			int(it.get("quality", 1)))
	for ap in it.get("appends", []):
		e.appends.append([int(ap.get("type", 0)), float(ap.get("value", 0.0))])
	return e


# ------------------------------------------------------------------ hien
func _refresh() -> void:
	_header.text = "%s      o: %s      vang: %d" % [hero(), PART_NAME.get(part, part), gold]
	if ui == null:
		return
	var it := item()
	if it.is_empty():
		_show_empty()
		return

	var e := _model(it)
	var st := e.stats()
	var lv := int(it.get("intensify", 0))

	_label(XggLayout.find_node(ui, "bmfEquipMainUIName"),
			PART_NAME.get(part, str(part)) if lv == 0
			else "%s +%d" % [PART_NAME.get(part, part), lv])
	_label(XggLayout.find_node(ui, "bmfEquipMainUILevel"), "Cap %d" % int(it.get("level", 1)))
	_label(XggLayout.find_node(ui, "ttfEquipMainUIQuality"), "Pham %d" % int(it.get("quality", 1)))
	_label(XggLayout.find_node(ui, "ttfEquipMainUIRank"), "O %d" % part)
	# Tinh luyen chua co luat ben game moi — noi thang thay vi hien so 0 gia.
	_label(XggLayout.find_node(ui, "ttfEquipMainUIRefine"), "Tinh luyen: chua co")

	var mt := int(it.get("main", {}).get("type", Equipment.AP))
	var base := float(it.get("main", {}).get("value", 0.0))
	_label(XggLayout.find_node(ui, "bmfEquipMainUIProperty"),
			"%s %s" % [PROP_NAME.get(mt, mt), _num(base, mt)])
	var bonus := float(st.get(mt, 0.0)) - base
	_label(XggLayout.find_node(ui, "bmfEquipMainUIPropertyAdd"),
			("+%s" % _num(bonus, mt)) if bonus > 0.0 else "")
	_label(XggLayout.find_node(ui, "ttfEquipMainUIFightingCapacity"),
			"Luc chien %d" % roundi(float(it.get("capacity", e.capacity()))))

	# Sau thuoc tinh phu; ban goc co dung sau o, nen do vao dung sau o do.
	var lines: Array = []
	if e.append_unlocked():
		for a in e.appends:
			lines.append("%s +%s" % [PROP_NAME.get(int(a[0]), a[0]), _num(float(a[1]), int(a[0]))])
	else:
		lines.append("Cap %d moi mo thuoc tinh phu" % Equipment.APPEND_UNLOCK_LEVEL)
	for i in range(1, 7):
		_label(XggLayout.find_node(ui, "ttfEquipMainUIAppendProperty%d" % i),
				str(lines[i - 1]) if i <= lines.size() else "")

	_icon(it)
	_refresh_intensify(it, e, mt)


## Icon mon do va nen theo pham chat, dung cach dat ten cua ban goc:
##
##   icon  equip_<EquipmentType>_<EquipLevel>.png   (CUIEquipment:GetEquipTextureName)
##   nen   v6/equipment_b_<Quality>.png             (szEquipmentQualityPngName)
##
## Game moi chua co bang vat pham nen chua co EquipmentType that; tam lay theo
## o do (5 bo icon co san, 6 o). Doi bang vat pham vao thi sua CHO NAY.
func _icon(it: Dictionary) -> void:
	for n in ["spEquipMainUIIconBg", "spEquipIntensifyUIIcon"]:
		var slot := XggLayout.find_node(ui, n)
		if slot != null:
			slot.visible = true
	var q := clampi(int(it.get("quality", 1)), 2, 6)
	var kind := (part - 1) % 5 + 1
	var tier := clampi(int(it.get("level", 1)), 0, 10)
	var frame := "equip_%d_%d.png" % [kind, tier]
	for pair in [["spEquipMainUIIconBg", "spEquipMainUIIcon"],
			["spEquipIntensifyUIIcon", ""]]:
		var bg := XggLayout.find_node(ui, pair[0])
		if bg != null:
			_slot_art(bg, "v6/equipment_b_%d.png" % q)
		var ic: Control = null
		if pair[1] != "":
			ic = XggLayout.find_node(ui, pair[1])
		elif bg != null:
			# Node ben panel phai khong co ten cho anh mon do; no la con
			# CCSprite 37x55 — dung kich thuoc o icon cua ban goc.
			for c in bg.get_children():
				if c is TextureRect and c.name != "_slot":
					ic = c
					break
		if ic != null:
			_slot_art(ic, frame)


## Dat anh vao mot O co san, GIU nguyen o.
##
## UiFrames.set_frame() keo node ve dung kich thuoc anh — dung y ban goc cho
## sprite thuong, nhung icon mon do trong atlas to hon o icon rat nhieu (co cai
## 200x300 cho mot o 37x55), nen dung thang thi anh tran ca ra ngoai man. O day
## giu o, cho anh co lai vua ben trong.
func _slot_art(node: Control, frame: String) -> void:
	var tex := UiFrames.get_frame(frame)
	if tex == null or not (node is TextureRect):
		return
	var box := node.get_meta("slot_size", node.size) as Vector2
	node.set_meta("slot_size", box)
	var tr := node as TextureRect
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = box


func _refresh_intensify(it: Dictionary, e: Equipment, mt: int) -> void:
	var lv := int(it.get("intensify", 0))
	var maxed := lv >= max_intensify
	var after := _model(it)
	after.intensify = lv + 1
	var now_val := float(e.stats().get(mt, 0.0))
	var aft_val := float(after.stats().get(mt, 0.0))
	var pname: String = PROP_NAME.get(mt, str(mt))

	# Bo cuc goc xep moi khoi thanh hai hang: [ten] [cap]  /  [chi so] [+them].
	# Giu dung the, va giu chu NGAN — cho nay ban goc chi de so.
	_in(CLS_NOW_BOX, CLS_TITLE, pname)
	_in(CLS_NOW_BOX, CLS_NOW_LEVEL, "+%d" % lv)
	_in(CLS_NOW_BOX, CLS_NOW_MAIN, _num(now_val, mt))
	_in(CLS_NOW_BOX, CLS_NOW_ADD, "")
	if maxed:
		_in(CLS_AFTER_BOX, CLS_TITLE, "")
		_in(CLS_AFTER_BOX, CLS_AFTER_LEVEL, "")
		_in(CLS_AFTER_BOX, CLS_AFTER_MAIN, "")
		_in(CLS_AFTER_BOX, CLS_AFTER_ADD, "")
	else:
		_in(CLS_AFTER_BOX, CLS_TITLE, pname)
		_in(CLS_AFTER_BOX, CLS_AFTER_LEVEL, "+%d" % (lv + 1))
		_in(CLS_AFTER_BOX, CLS_AFTER_MAIN, _num(aft_val, mt))
		# Cot "+them" cua ban goc nam o x=174 trong khoi, tuc sat mep phai
		# panel — chu tieng Viet dai hon so nen tran ra ngoai. Phan chenh lech
		# da co o dong "Luc chien A -> B" ngay tren dinh bang.
		_in(CLS_AFTER_BOX, CLS_AFTER_ADD, "")

	# Nhan rong o dinh bang: luc chien truoc va sau, de thay ngay duoc gi.
	var head := XggLayout.find_node(ui, "ttfEquipmentUI_IntensifyValue")
	if head != null:
		head.visible = true
		_label(head, "Luc chien %d" % roundi(e.capacity()) if maxed
				else "Luc chien %d  ->  %d"
				% [roundi(e.capacity()), roundi(after.capacity())])

	var cost := cost_now()
	var box := XggLayout.find_by_cls(ui, CLS_COST)
	if box != null:
		box.visible = not maxed
		# Nhan so vang la Label duy nhat trong khoi "强化消耗".
		for c in box.get_children():
			if c is Label:
				_label(c, "" if maxed else str(cost))

	var maxed_note := XggLayout.find_by_cls(ui, CLS_MAXED)
	if maxed_note != null:
		maxed_note.visible = maxed
		_label(maxed_note, "Da toi cap cuong hoa cao nhat" if maxed else "")

	var btn := XggLayout.find_node(ui, "snsEquipIntensify")
	if btn != null:
		btn.visible = not maxed
		for c in btn.get_children():
			if c is Label:
				_label(c, "Cuong hoa")
				(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				(c as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				c.size = btn.size
				c.position = Vector2.ZERO
		# Thieu vang thi lam mo — bam van goi len may chu va may chu tu choi,
		# nhung noi truoc thi hon la de nguoi choi bam roi an loi.
		btn.modulate = Color(1, 1, 1) if gold >= cost else Color(0.55, 0.55, 0.55)
	_tips.text = "" if gold >= cost or maxed else "Thieu vang: can %d, dang co %d" % [cost, gold]


func _show_empty() -> void:
	_label(XggLayout.find_node(ui, "bmfEquipMainUIName"), PART_NAME.get(part, str(part)))
	_label(XggLayout.find_node(ui, "bmfEquipMainUILevel"), "")
	_label(XggLayout.find_node(ui, "ttfEquipMainUIQuality"), "")
	_label(XggLayout.find_node(ui, "ttfEquipMainUIRank"), "")
	_label(XggLayout.find_node(ui, "ttfEquipMainUIRefine"), "")
	_label(XggLayout.find_node(ui, "bmfEquipMainUIProperty"), "O nay chua co do")
	_label(XggLayout.find_node(ui, "bmfEquipMainUIPropertyAdd"), "")
	_label(XggLayout.find_node(ui, "ttfEquipMainUIFightingCapacity"), "")
	for i in range(1, 7):
		_label(XggLayout.find_node(ui, "ttfEquipMainUIAppendProperty%d" % i),
				"Thang tran thi co the roi do" if i == 1 else "")
	for cls in [CLS_NOW_LEVEL, CLS_NOW_MAIN, CLS_NOW_ADD,
			CLS_AFTER_LEVEL, CLS_AFTER_MAIN, CLS_AFTER_ADD]:
		_by_cls(cls, "")
	var box := XggLayout.find_by_cls(ui, CLS_COST)
	if box != null:
		box.visible = false
	var btn := XggLayout.find_node(ui, "snsEquipIntensify")
	if btn != null:
		btn.visible = false
	# O trong thi giau ca icon: de cai khung "?" nam do trong hai panel trong
	# nhu la co do ma khong doc duoc.
	for n in ["spEquipMainUIIconBg", "spEquipIntensifyUIIcon"]:
		var ic := XggLayout.find_node(ui, n)
		if ic != null:
			ic.visible = false
	var head := XggLayout.find_node(ui, "ttfEquipmentUI_IntensifyValue")
	if head != null:
		head.visible = true
		_label(head, "Chua co do o o nay")
	_tips.text = ""


## Chi mang di theo phan tram, may va cong di theo don vi — hien khac nhau.
func _num(v: float, prop_type: int) -> String:
	if prop_type == Equipment.CRITICAL_STRIKE:
		return "%.2f%%" % (v * 100.0)
	return "%.1f" % v


## Gia cuong hoa mot cap. Lay so may chu gui neu co; khong thi tinh lai bang
## dung cong thuc do — hai ban da doi chieu nhau nen khong lech.
func cost_now() -> int:
	var it := item()
	if it.is_empty():
		return 0
	if it.has("nextCost"):
		return int(it["nextCost"])
	return ceili(Equipment.intensify_cost(int(it.get("intensify", 0)) + 1))


# ------------------------------------------------------------------ thao tac
func _step_part(d: int) -> void:
	part = wrapi(part - 1 + d, 0, 6) + 1
	_refresh()


func _step_hero(d: int) -> void:
	if heroes.size() > 1:
		hero_i = wrapi(hero_i + d, 0, heroes.size())
	_refresh()


func _on_intensify() -> void:
	if _busy:
		return
	var it := item()
	if it.is_empty() or int(it.get("intensify", 0)) >= max_intensify:
		return
	if gold < cost_now():
		_tips.text = "Thieu vang: can %d, dang co %d" % [cost_now(), gold]
		return
	_busy = true
	_tips.text = "dang cuong hoa..."
	var ses := await Game.ensure_session()
	var r := await ses.intensify(hero(), part)
	_busy = false
	if not r.ok:
		_tips.text = "khong cuong hoa duoc: %s" % str(r.get("error", ""))
		return
	# Doc lai ca bang: may chu vua doi vang lan mon do, va no moi la ban dung.
	await _reload()
	_tips.text = "+%d  (ton %d vang)" % [int(r.data.get("intensify", 0)),
			int(r.data.get("cost", 0))]
