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

## O do -> ten tieng Viet. Thu tu dung theo HeroEquipPart cua ban goc
## (Protocol.lua:305), khong phai thu tu tu dat.
const PART_NAME := {
	1: "Vu khi", 2: "Giap", 3: "Giay",
	4: "Day chuyen", 5: "Nhan", 6: "O phu",
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

# --- tab tinh luyen (lEquipmentRefineUI) ---
const CLS_REFINE_BTN := "精炼按钮"          # nut tinh luyen
const CLS_REFINE_COST := "消耗精华"         # khoi "ton tinh hoa"
const CLS_REFINE_STEP := "锻位进阶"         # khoi truoc/sau khi tinh luyen
const CLS_REFINE_FULL := "满锻位"           # khoi khi da het cap
const CLS_GRADE_NOW := "currentgrade"
const CLS_GRADE_NEXT := "nextgrade"
const CLS_ADD_NOW := "HPnowincrease"
const CLS_ADD_NEXT := "HPnextincrease"
const CLS_FULL_FORGE := "FullForge"
const CLS_FULL_TIPS := "FullHPTips"
const CLS_REFINE_PROGRESS := "RefineProgress"   # day 5 cham bac

# --- tab ghep do (lEquipmentForgeUI) ---
## Ban goc co ba bien the khung theo SO NGUYEN LIEU. Chon dung cai theo bang.
const CLS_FORGE_CONSUME := {2: "2个消耗品的锻造", 3: "3个消耗品的锻造",
		4: "4个消耗品的锻造"}
const CLS_FORGE_BTN := "锻造按钮"           # nut ghep
const CLS_FORGE_GOLD := "金币数"            # so vang trong khoi gia
const CLS_FORGE_NAME := "装备名字"
const CLS_FORGE_LEVEL := "装备等级"
const CLS_FORGE_TIPS := "提示语"
const CLS_FORGE_MAXED := "锻造到达最高级"
const CLS_MAXED := "强化到达最高级"          # bao da toi cap cao nhat

## Man nay lam viec duoc ma khong can may chu: set_data() nhan thang du lieu.
## Nho vay bo test chay duoc khong can Nakama (xem tools/verify_equip.gd).
var payload: Dictionary = {}
var heroes: Array = []
var hero_i := 0
var part := 1
var gold := 0
var concentrate := 0
var max_intensify := 200
var max_refine := 5
var max_purify := 20
## "intensify" hoac "refine" — dung hai nut cua ban goc de doi.
var tab := "intensify"

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
		if "--refine" in OS.get_cmdline_user_args():
			_set_tab("refine")
		elif "--forge" in OS.get_cmdline_user_args():
			_set_tab("forge")
		if "--part4" in OS.get_cmdline_user_args():
			part = 4
			_refresh()
		return
	await _reload()


## Mot ban tra loi bx.equipment bia ra, chi de xem bo cuc.
func _fake() -> Dictionary:
	var mk := func(part: int, prop: int, v: float, lv: int, iv: int,
			aps: Array, rf: int = 0) -> Dictionary:
		var e := Equipment.new(part, prop, v, lv, iv, 2, [], rf)
		var out: Array = []
		for a in aps:
			e.appends.append(a)
			out.append({"type": a[0], "value": a[1]})
		return {"part": part, "level": lv, "intensify": iv, "quality": 2,
				"refine": rf, "main": {"type": prop, "value": v}, "appends": out,
				"capacity": e.capacity(), "equipType": 1,
				"nextCost": ceili(Equipment.intensify_cost(iv + 1)),
				"nextRefineCost": e.refine_cost_next(),
				"synthesis": {"nextLevel": lv + 1, "gold": 3700,
					"needHeroLevel": 20, "heroLevel": 31, "ready": true,
					"reason": "", "materials": [[25, 3], [52, 5]]}}
	return {
		"gold": 1240, "concentrate": 860, "maxIntensify": 200, "maxRefine": 5,
		"maxPurify": 20,
		"equipment": {
			"MaChao": [
				mk.call(1, Equipment.AP, 118.4, 7, 12,
						[[Equipment.CRITICAL_STRIKE, 0.0132]], 2),
				mk.call(2, Equipment.HP_LIMIT, 264.0, 5, 3, []),
				# Mot mon da la do chuyen thuoc, de xem thu duong tay rieng.
				{"part": 4, "level": 4, "intensify": 2, "quality": 3,
					"refine": 5, "equipType": 42, "exclusive": true,
					"purify": 3, "purifyPercent": 40.0, "nextPurifyCost": 200,
					"main": {"type": Equipment.HP_LIMIT, "value": 210.0},
					"appends": [], "capacity": 29.4,
					"nextCost": ceili(Equipment.intensify_cost(3))},
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
			"lEquipmentIntensifyUI", "lEquipmentRefineUI", "lEquipmentForgeUI"]:
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
	_click(XggLayout.find_by_cls(ui, CLS_REFINE_BTN), _on_refine)
	# Hai nut doi bang cua chinh ban goc, nam o cot phai panel trai.
	_click(XggLayout.find_node(ui, "btnShowEquipmentIntensifyUI"),
			func(): _set_tab("intensify"))
	_click(XggLayout.find_node(ui, "btnShowEquipmentRefineUI"),
			func(): _set_tab("refine"))
	_click(XggLayout.find_node(ui, "btnEquipmentUI_ShowEquipForgeUI"),
			func(): _set_tab("forge"))
	_click(XggLayout.find_node(ui, "snsEquipForge"), _on_synthesize)
	_button_art(XggLayout.find_node(ui, "snsEquipForge"), "v6/ui_button01.png")
	_backing(XggLayout.find_node(ui, "lEquipmentForgeUI"))
	_button_art(XggLayout.find_by_cls(ui, CLS_REFINE_BTN), "v6/ui_button01.png")
	_backing(XggLayout.find_node(ui, "lEquipmentRefineUI"))
	# Nut "lay them tinh hoa" tro toi cua hang — chua co he do, an di.
	var get_btn := XggLayout.find_by_cls(ui, "获取按钮")
	if get_btn != null:
		get_btn.visible = false
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


## Doi giua bang cuong hoa va bang tinh luyen. Ban goc cung lam the: hai bang
## nam chong nhau trong lEquipmentChildUI, Lua bat dung mot cai.
func _set_tab(which: String) -> void:
	tab = which
	var it := XggLayout.find_node(ui, "lEquipmentIntensifyUI")
	var rf := XggLayout.find_node(ui, "lEquipmentRefineUI")
	var fg := XggLayout.find_node(ui, "lEquipmentForgeUI")
	if it != null:
		it.visible = which == "intensify"
	if rf != null:
		rf.visible = which == "refine"
	if fg != null:
		fg.visible = which == "forge"
	_refresh()


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
	concentrate = int(p.get("concentrate", 0))
	max_intensify = int(p.get("maxIntensify", 200))
	max_refine = int(p.get("maxRefine", 5))
	max_purify = int(p.get("maxPurify", 20))
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
			int(it.get("quality", 1)), [], int(it.get("refine", 0)))
	e.exclusive = bool(it.get("exclusive", false))
	e.purify = int(it.get("purify", 0))
	e.purify_percent = float(it.get("purifyPercent", 0.0))
	for ap in it.get("appends", []):
		e.appends.append([int(ap.get("type", 0)), float(ap.get("value", 0.0))])
	return e


# ------------------------------------------------------------------ hien
func _refresh() -> void:
	_header.text = "%s      o: %s      vang: %d      tinh hoa: %d" % [
			hero(), PART_NAME.get(part, part), gold, concentrate]
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
	var rf := int(it.get("refine", 0))
	if bool(it.get("exclusive", false)):
		_label(XggLayout.find_node(ui, "ttfEquipMainUIRefine"),
				"Chuyen thuoc bac %d (+%d%%)" % [int(it.get("purify", 0)),
				int(float(it.get("purifyPercent", 0.0)))])
	else:
		_label(XggLayout.find_node(ui, "ttfEquipMainUIRefine"),
				"Tinh luyen %d (+%d%%)" % [rf, int(Equipment.refine_percent(rf))]
				if rf > 0 else "Chua tinh luyen")

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
	_refresh_refine(it, e, mt)
	_refresh_forge(it)


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
	if tex == null:
		return
	var box := node.get_meta("slot_size", node.size) as Vector2
	node.set_meta("slot_size", box)
	var tr: TextureRect = node as TextureRect
	if tr == null:
		# O nao trong bo cuc khong mang anh thi ra Control tron. Gan mot
		# TextureRect vao lam con — dung mot lan — thay vi bo qua lang le.
		tr = node.get_node_or_null("_slot") as TextureRect
		if tr == null:
			tr = TextureRect.new()
			tr.name = "_slot"
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(tr)
			node.move_child(tr, 0)
		# Con san trong o (vi du hinh "?" mac dinh) thi giau di.
		for c in node.get_children():
			if c is TextureRect and c.name != "_slot":
				c.visible = false
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


## Bang tinh luyen. Bo cuc goc chia lam hai khoi chong nhau: "锻位进阶" khi
## con len duoc, "满锻位" khi da het cap — bat dung mot cai, y nhu ban goc.
func _refresh_refine(it: Dictionary, e: Equipment, mt: int) -> void:
	var exclusive := bool(it.get("exclusive", false))
	# Ban goc khong lam tab rieng cho do chuyen thuoc: no doi CHE DO cua chinh
	# bang tinh luyen khi mon do da tay bac 5 (EquipRefineType.OpenExclusive).
	# Lam dung the.
	var can_forge := false
	var forge_reason := ""
	if not exclusive:
		var er = it.get("exclusiveReady")
		if er != null:
			can_forge = bool(er.get("ready", false))
			forge_reason = str(er.get("reason", ""))

	var lv := int(it.get("purify", 0)) if exclusive else int(it.get("refine", 0))
	var cap_lv := max_purify if exclusive else max_refine
	var maxed := lv >= cap_lv
	var pname: String = PROP_NAME.get(mt, str(mt))
	var word := "Bac" if exclusive else "Bac"

	# Nam cham bac: ban goc lam MO cai chua dat (setGray). Duong chuyen thuoc
	# co 21 bac ma cho chi ve duoc 5 cham, nen chia theo tung chang 5 bac —
	# dung y ban goc (no lay `RefineLevel % 5`).
	var prog := XggLayout.find_by_cls(ui, CLS_REFINE_PROGRESS)
	if prog != null:
		var lit := lv % 5 if exclusive and lv < cap_lv else mini(lv, 5)
		for i in range(1, 6):
			var dot := XggLayout.find_by_cls(prog, "CCSprite%d" % i)
			if dot != null:
				dot.modulate = Color(1, 1, 1) if i <= lit else Color(0.32, 0.34, 0.38)

	# Tab tinh luyen co o icon rieng cua no; gan cung mot anh.
	var rf_panel := XggLayout.find_node(ui, "lEquipmentRefineUI")
	if rf_panel != null:
		var rf_icon := XggLayout.find_by_cls(rf_panel, "spEquipMainUIIcon")
		if rf_icon != null:
			_slot_art(rf_icon, "equip_%d_%d.png" % [(part - 1) % 5 + 1,
					clampi(int(it.get("level", 1)), 0, 10)])
			var bg := rf_icon.get_parent()
			if bg is TextureRect:
				_slot_art(bg, "v6/equipment_b_%d.png"
						% clampi(int(it.get("quality", 1)), 2, 6))

	var step := XggLayout.find_by_cls(ui, CLS_REFINE_STEP)
	var full := XggLayout.find_by_cls(ui, CLS_REFINE_FULL)
	if step != null:
		step.visible = not maxed
	if full != null:
		full.visible = maxed

	if maxed:
		_label(_child(full, CLS_GRADE_NOW), "%s %d" % [word, lv], true)
		_label(_child(full, CLS_FULL_FORGE), "cao nhat", true)
		_label(_child(full, CLS_ADD_NOW),
				"%s %s" % [pname, _num(e.effective_main(), mt)], true)
		_label(_child(full, CLS_FULL_TIPS), "+%d%%" % int(e.bonus_percent()), true)
	else:
		var after := _model(it)
		var nxt_pct := 0.0
		if exclusive:
			after.purify = lv + 1
			# Bang phan tram cua duong chuyen thuoc do MAY CHU giu; client chi
			# xem truoc mot buoc bang quy luat +5% moi bac cua chinh bang do.
			nxt_pct = e.bonus_percent() + 5.0
			after.purify_percent = nxt_pct
		else:
			after.refine = lv + 1
		_label(_child(step, CLS_GRADE_NOW), "%s %d" % [word, lv], true)
		_label(_child(step, CLS_GRADE_NEXT), "%s %d" % [word, lv + 1], true)
		_label(_child(step, CLS_ADD_NOW),
				"%s %s" % [pname, _num(e.effective_main(), mt)], true)
		_label(_child(step, CLS_ADD_NEXT),
				"%s %s" % [pname, _num(after.effective_main(), mt)], true)

	# Nhan rong o dinh bang: noi ro dang o duong nao.
	var head := XggLayout.find_node(ui, "ttfEquipmentUI_IntensifyValue")
	if head != null:
		head.visible = true
		if can_forge:
			_label(head, "Ren duoc thanh do chuyen thuoc")
		elif exclusive:
			_label(head, "Do chuyen thuoc  +%d%%" % int(e.bonus_percent()))
		else:
			_label(head, "Tinh luyen  +%d%%" % int(e.bonus_percent()))

	var cost := refine_cost_now()
	var box := XggLayout.find_by_cls(ui, CLS_REFINE_COST)
	if box != null:
		# Ren thanh do chuyen thuoc thi khong ton tinh hoa (ban goc ton nguyen
		# lieu, ma game moi chua co he vat pham).
		box.visible = not maxed and not can_forge
		var labels: Array = []
		_collect_labels(box, labels)
		if labels.size() > 0:
			_label(labels[0], "%d / %d" % [concentrate, cost])
		for i in range(1, labels.size()):
			_label(labels[i], "")

	var maxed_note := XggLayout.find_by_cls(ui, CLS_MAXED)
	if maxed_note != null:
		maxed_note.visible = maxed
		_label(maxed_note, "Da toi bac cao nhat" if maxed else "")

	var btn := XggLayout.find_by_cls(ui, CLS_REFINE_BTN)
	if btn != null:
		btn.visible = not maxed
		for c in btn.get_children():
			if c is Label:
				_label(c, "Ren chuyen thuoc" if can_forge else "Tinh luyen")
				(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				(c as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				c.size = btn.size
				c.position = Vector2.ZERO
		btn.modulate = Color(1, 1, 1) if (can_forge or concentrate >= cost) 				else Color(0.55, 0.55, 0.55)

	if tab == "refine":
		if can_forge:
			_tips.text = "Da tay bac 5 — ren duoc thanh do chuyen thuoc"
		elif maxed:
			_tips.text = ""
		elif concentrate < cost:
			_tips.text = "Thieu tinh hoa: can %d, dang co %d" % [cost, concentrate]
		elif forge_reason != "" and not exclusive:
			_tips.text = ""
		else:
			_tips.text = ""


## Nhan con theo ten lop, tim TRONG mot khoi.
## Bang ghep do. Ban goc chia san ba bien the khung theo SO NGUYEN LIEU
## (2, 3, 4 mon) — chon dung cai theo bang, y nhu no.
##
## Nguyen lieu hien ra de nguoi choi biet ban goc doi gi, nhung CHUA tru duoc:
## game moi con thieu he vat pham. May chu chi tru vang va doi cap tuong.
func _refresh_forge(it: Dictionary) -> void:
	var syn = it.get("synthesis")
	var maxed := syn == null
	var panel := XggLayout.find_node(ui, "lEquipmentForgeUI")
	if panel == null:
		return

	for k in CLS_FORGE_CONSUME:
		var b := XggLayout.find_by_cls(panel, CLS_FORGE_CONSUME[k])
		if b != null:
			b.visible = false
	var note := XggLayout.find_node(ui, "lEquipForgeUI_IsMaxLevel")
	if note != null:
		note.visible = maxed
		_label(note, "Da toi cap cao nhat" if maxed else "", true)
	var gold_box := XggLayout.find_node(ui, "g_EquipForgeUIGoldCost")
	if gold_box != null:
		gold_box.visible = not maxed
	var btn := XggLayout.find_node(ui, "snsEquipForge")
	if btn != null:
		btn.visible = not maxed
	if maxed:
		return

	var info: Dictionary = syn
	var mats: Array = info.get("materials", [])
	var n := clampi(mats.size(), 2, 4)
	var box := XggLayout.find_by_cls(panel, CLS_FORGE_CONSUME[n])
	if box != null:
		box.visible = true
		# Hai nhan ten/cap cua ban goc cach nhau co 20px (chu cua no ngan kieu
		# "Vu khi" + "Lv7"), nen gop lam mot; dong tips ben duoi rong 300px.
		_label(XggLayout.find_by_cls(box, CLS_FORGE_NAME),
				"%s  cap %d -> %d" % [PART_NAME.get(part, str(part)),
				int(it.get("level", 1)), int(info.get("nextLevel", 0))], true)
		_label(XggLayout.find_by_cls(box, CLS_FORGE_LEVEL), "", true)
		var need := int(info.get("needHeroLevel", 0))
		_label(XggLayout.find_by_cls(box, CLS_FORGE_TIPS),
				"tuong cap %d/%d" % [int(info.get("heroLevel", 1)), need], true)
		_forge_materials(box, mats, n)
		# O goc cua so do cay la KET QUA: chinh mon do dang ghep.
		var root_icon := XggLayout.find_node(box, "btnEquipForgeTreeNodeRoot")
		if root_icon == null:
			root_icon = XggLayout.find_by_cls(box, "CCButton")
		if root_icon != null:
			_slot_art(root_icon, "v6/equipment_b_%d.png"
					% clampi(int(it.get("quality", 1)), 2, 6))
			var inner := XggLayout.find_by_cls(root_icon, "CCSprite")
			if inner != null:
				_slot_art(inner, "equip_%d_%d.png" % [(part - 1) % 5 + 1,
						clampi(int(it.get("level", 1)), 0, 10)])

	if gold_box != null:
		_label(XggLayout.find_by_cls(gold_box, CLS_FORGE_GOLD),
				str(int(info.get("gold", 0))))

	var ready := bool(info.get("ready", false)) and gold >= int(info.get("gold", 0))
	if btn != null:
		for c in btn.get_children():
			if c is Label:
				_label(c, "Ghep do")
				(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				(c as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				c.size = btn.size
				c.position = Vector2.ZERO
		btn.modulate = Color(1, 1, 1) if ready else Color(0.55, 0.55, 0.55)

	if tab == "forge":
		if not bool(info.get("ready", false)):
			_tips.text = "Chua ghep duoc: %s" % str(info.get("reason", ""))
		elif gold < int(info.get("gold", 0)):
			_tips.text = "Thieu vang: can %d, dang co %d" % [
					int(info.get("gold", 0)), gold]
		else:
			_tips.text = ""


## Icon nguyen lieu. Ban goc dat ten anh vat pham la "item_<id>.png".
##
## Tim theo TEN node (btnEquipForgeConsumeUI<n>_Icon<i>) chu khong quet theo
## ten lop: trong khung con co mot o goc cua so do cay cung mang lop CCButton,
## quet theo lop la nham no thanh o nguyen lieu.
func _forge_materials(box: Control, mats: Array, n: int) -> void:
	for i in range(1, 5):
		var slot := XggLayout.find_node(box, "btnEquipForgeConsumeUI%d_Icon%d" % [n, i])
		if slot == null:
			continue
		if i <= mats.size():
			slot.visible = true
			_slot_art(slot, "item_%d.png" % int(mats[i - 1][0]))
			# O nay von co hai sprite con ve de len (nen trong + hinh "?").
			# Anh vat pham la mot tam tron ca khung nen giau chung di.
			for c in slot.get_children():
				if c is TextureRect:
					c.visible = false
			var lb := _ensure_label(slot)
			lb.text = "x%d" % int(mats[i - 1][1])
			lb.visible = true
			lb.position = Vector2(4, slot.size.y - 22)
		else:
			slot.visible = false


func _child(box: Control, cls: String) -> Control:
	if box == null:
		return null
	return XggLayout.find_by_cls(box, cls)


func _collect_labels(node: Control, into: Array) -> void:
	for c in node.get_children():
		if c is Label:
			into.append(c)
		elif c is Control:
			_collect_labels(c, into)


## Tinh hoa can de tinh luyen mon dang xem len mot cap.
func refine_cost_now() -> int:
	var it := item()
	if it.is_empty():
		return 0
	if bool(it.get("exclusive", false)):
		# Duong chuyen thuoc co bang gia rieng, may chu giu — khong tinh lai.
		return int(it.get("nextPurifyCost", 0))
	if it.has("nextRefineCost"):
		return int(it["nextRefineCost"])
	var lv := int(it.get("refine", 0))
	if lv >= max_refine:
		return 0
	return Equipment.refine_cost(part, lv + 1)


func _on_refine() -> void:
	if _busy:
		return
	var it := item()
	if it.is_empty():
		return
	# Cung mot nut: da tay bac 5 thi no la nut REN thanh do chuyen thuoc.
	var er = it.get("exclusiveReady")
	if not bool(it.get("exclusive", false)) and er != null 			and bool(er.get("ready", false)):
		await _do_forge_exclusive()
		return
	var lv := int(it.get("purify", 0)) if bool(it.get("exclusive", false)) 			else int(it.get("refine", 0))
	var cap_lv := max_purify if bool(it.get("exclusive", false)) else max_refine
	if lv >= cap_lv:
		return
	var cost := refine_cost_now()
	if concentrate < cost:
		_tips.text = "Thieu tinh hoa: can %d, dang co %d" % [cost, concentrate]
		return
	_busy = true
	_tips.text = "dang tinh luyen..."
	var ses := await Game.ensure_session()
	var r := await ses.refine(hero(), part)
	_busy = false
	if not r.ok:
		_tips.text = "khong tinh luyen duoc: %s" % str(r.get("error", ""))
		return
	await _reload()
	_tips.text = "Tinh luyen %d  (+%d%%, ton %d tinh hoa)" % [
			int(r.data.get("refine", 0)), int(r.data.get("refinePercent", 0)),
			int(r.data.get("cost", 0))]


func _do_forge_exclusive() -> void:
	_busy = true
	_tips.text = "dang ren..."
	var ses := await Game.ensure_session()
	var r := await ses.forge_exclusive(hero(), part)
	_busy = false
	if not r.ok:
		_tips.text = "khong ren duoc: %s" % str(r.get("error", ""))
		return
	await _reload()
	_tips.text = "Thanh do chuyen thuoc  (+%d%%, co ky nang %s)" % [
			int(float(r.data.get("purifyPercent", 0))),
			str(r.data.get("skill", ""))]


func _on_synthesize() -> void:
	if _busy:
		return
	var it := item()
	var syn = it.get("synthesis")
	if it.is_empty() or syn == null:
		return
	var info: Dictionary = syn
	if not bool(info.get("ready", false)):
		_tips.text = "Chua ghep duoc: %s" % str(info.get("reason", ""))
		return
	if gold < int(info.get("gold", 0)):
		_tips.text = "Thieu vang: can %d, dang co %d" % [
				int(info.get("gold", 0)), gold]
		return
	_busy = true
	_tips.text = "dang ghep..."
	var ses := await Game.ensure_session()
	var r := await ses.synthesize(hero(), part)
	_busy = false
	if not r.ok:
		_tips.text = "khong ghep duoc: %s" % str(r.get("error", ""))
		return
	await _reload()
	_tips.text = "Len cap %d  (ton %d vang)" % [int(r.data.get("level", 0)),
			int(r.data.get("cost", 0))]


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
	# Bang tinh luyen cung phai tat het theo.
	var fbtn := XggLayout.find_node(ui, "snsEquipForge")
	if fbtn != null:
		fbtn.visible = false
	var fgold := XggLayout.find_node(ui, "g_EquipForgeUIGoldCost")
	if fgold != null:
		fgold.visible = false
	for cls in [CLS_REFINE_BTN, CLS_REFINE_COST, CLS_REFINE_STEP, CLS_REFINE_FULL]:
		var n := XggLayout.find_by_cls(ui, cls)
		if n != null:
			n.visible = false
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
