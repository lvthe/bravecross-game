# Kiem man trang bi ma KHONG can may chu.
#
#   godot --headless --path . tools/verify_equip.tscn
#
# Chay dang CANH chu khong phai --script: man trang bi dung autoload `Game`,
# ma autoload chi ton tai khi co cay canh. Da thu --script truoc: Godot bao
# "Identifier not found: Game" ngay luc bien dich.
#
# Man trang bi nhan du lieu qua set_data() thay vi tu goi mang, nen o day dua
# vao mot ban tra loi bx.equipment gia roi do:
#
#   * moi node cua ban goc ma man nay tro toi deu co that trong bo cuc
#     (day la hop dong voi UI_Equipment.xgg — thieu mot cai la hong)
#   * cac nhan duoc dien dung so
#   * o trong thi khong hien nut cuong hoa
#   * doi o, doi tuong thi noi dung doi theo
#   * thieu vang thi nut mo di va co loi bao truoc
#
# Cai KHONG do o day: mot node co that su ve ra pixel khong. Do la viec cua
# anh chup (godot ... ui/equip.tscn -- --shot=x.png).
extends Node

const SCENE := "res://ui/equip.tscn"

var n_pass := 0
var n_fail := 0


func _check(ok: bool, desc: String, detail: String = "") -> void:
	if ok:
		n_pass += 1
		print("  dat   ", desc)
	else:
		n_fail += 1
		print("  HONG  ", desc, "" if detail == "" else "  -> " + detail)


## Mot mon do dung dang ma bx.equipment tra ve.
func _item(part: int, prop: int, value: float, lv: int, intensify: int,
		appends: Array = [], refine: int = 0) -> Dictionary:
	var e := Equipment.new(part, prop, value, lv, intensify, 2, [], refine)
	for a in appends:
		e.appends.append(a)
	var aps: Array = []
	for a in appends:
		aps.append({"type": a[0], "value": a[1],
				"base": float(a[2]) if a.size() > 2 else 1.0})
	var syn = null
	if lv < Equipment.MAX_EQUIP_LEVEL:
		syn = {"nextLevel": lv + 1, "gold": 3700, "needHeroLevel": 20,
			"heroLevel": 31, "ready": true, "reason": "",
			"materials": [[25, 3], [52, 5]]}
	return {
		"part": part, "level": lv, "intensify": intensify, "quality": 2,
		"refine": refine, "equipType": 1, "synthesis": syn,
		"main": {"type": prop, "value": value},
		"appends": aps,
		"capacity": e.capacity(),
		"nextCost": ceili(Equipment.intensify_cost(intensify + 1)),
		"nextRefineCost": e.refine_cost_next(),
		"levelCoef": 20.0, "recastCost": Equipment.RECAST_COST_GOLD,
		"appendScore": e.append_score_total(),
		"qualityUp": {"nextQuality": 3, "gold": 10, "needHeroLevel": 1,
			"heroLevel": 31, "ready": true, "reason": "",
			"materials": [[86, 1]]},
	}


## Doc chu cua mot node, di qua dung duong ma man hinh dung.
##
## Mot so nhan trong bo cuc goc khong ra Label duoc (truong "lop" cua chung la
## chu tieng Trung mo ta), nen man hinh gan mot Label lam con. Doc thang node
## se bao "khong phai nhan" du chu van hien dung.
func _text_of(scr: Control, n: Control) -> String:
	if n == null:
		return "<khong tim thay node>"
	var lb: Label = scr._ensure_label(n)
	return lb.text if lb != null else "<khong phai nhan>"


func _text(scr: Control, node_name: String) -> String:
	return _text_of(scr, XggLayout.find_node(scr.ui, node_name))


func _text_cls(scr: Control, cls: String) -> String:
	return _text_of(scr, XggLayout.find_by_cls(scr.ui, cls))


func _ready() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		print("khong nap duoc ", SCENE)
		_done(1)
		return
	var scr := packed.instantiate() as Control
	# Khong add vao cay: _ready() se di goi may chu. Dung tay dung bo cuc roi
	# bom du lieu vao — dung cai duong ma bo test muon do.
	scr._header = scr.get_node("Header")
	scr._tips = scr.get_node("Tips")
	scr._build()

	print("=== 1. bo cuc co du node man nay tro toi ===")
	_check(scr.ui != null, "dung duoc bo cuc UI_Equipment")
	if scr.ui == null:
		print("  (thieu layout_ref — chay: python ../brave-cross/work/layout.py "
				+ "--all --out layout_ref)")
		_done(1)
		return
	var missing: Array = []
	for n in scr.NEED:
		if XggLayout.find_node(scr.ui, n) == null:
			missing.append(n)
	_check(missing.is_empty(), "%d node ten cua ban goc deu co" % scr.NEED.size(),
			str(missing))
	var missing_cls: Array = []
	for c in [scr.CLS_AFTER_MAIN, scr.CLS_AFTER_LEVEL, scr.CLS_AFTER_ADD,
			scr.CLS_NOW_MAIN, scr.CLS_NOW_LEVEL, scr.CLS_NOW_ADD,
			scr.CLS_COST, scr.CLS_MAXED]:
		if XggLayout.find_by_cls(scr.ui, c) == null:
			missing_cls.append(c)
	_check(missing_cls.is_empty(), "8 nhan tra theo ten lop deu co", str(missing_cls))
	# Ba lop ta bat phai hien, con cac bang hanh dong khac phai con an.
	var main_ui := XggLayout.find_node(scr.ui, "lEquipmentMainUI")
	var refine := XggLayout.find_node(scr.ui, "lEquipmentRefineUI")
	var forge := XggLayout.find_node(scr.ui, "lEquipmentForgeUI")
	var quality_ui := XggLayout.find_node(scr.ui, "lEquipmentUpgradeQualityUI")
	_check(main_ui != null and main_ui.visible, "panel mon do duoc bat len")
	_check(refine != null, "co bang tinh luyen trong bo cuc")
	_check(forge != null, "co bang ghep do trong bo cuc")
	# Nam bang hanh dong nam CHONG len nhau trong lEquipmentChildUI. Bat dung
	# mot cai la luat cua ban goc; bat hai cai la man hinh thanh mot dong
	# chong cheo. Do bat bien do thay vi do tung bang mot.
	var panels := ["lEquipmentIntensifyUI", "lEquipmentRefineUI",
			"lEquipmentForgeUI", "lEquipmentAlterUI",
			"lEquipmentUpgradeQualityUI"]
	var missing_panel: Array = []
	for n in panels:
		if XggLayout.find_node(scr.ui, n) == null:
			missing_panel.append(n)
	_check(missing_panel.is_empty(), "co du 5 bang hanh dong", str(missing_panel))
	var shown := 0
	for n in panels:
		var pn := XggLayout.find_node(scr.ui, n)
		if pn != null and pn.visible:
			shown += 1
	_check(shown == 1, "chi MOT bang duoc bat len mot luc", str(shown))
	_check(quality_ui != null, "co bang pham chat trong bo cuc")

	print("\n=== 2. do vao thi hien dung so ===")
	var data := {
		"gold": 500,
		"concentrate": 100,
		# Tui do co san nguyen lieu: nhung muc duoi day do dieu kien VANG va
		# cap tuong, khong phai dieu kien nguyen lieu (muc 3l lo phan do).
		"save": {"items": {"25": 5, "52": 9, "86": 3, "87": 3}},
		"maxIntensify": 200,
		"maxRefine": 5,
		"equipment": {
			"MaChao": [
				_item(1, Equipment.AP, 100.0, 5, 3, [
					Equipment.make_append(Equipment.CRITICAL_STRIKE,
							1.0, 2.0, 20.0)]),
				_item(2, Equipment.HP_LIMIT, 250.0, 2, 0),
			],
			"GanNing": [_item(1, Equipment.AP, 40.0, 6, 0)],
		},
	}
	scr.set_data(data, ["MaChao", "GanNing"])
	_check(scr.hero() == "MaChao", "tuong dau tien la tuong trong doi hinh", scr.hero())
	_check(scr.part == 1, "mo o vu khi truoc")
	var nm := _text(scr, "bmfEquipMainUIName")
	_check(nm == "Vu khi +3", "ten o kem cap cuong hoa", nm)
	var lv := _text(scr, "bmfEquipMainUILevel")
	_check(lv == "Cap 5", "cap mon do", lv)

	# Chi so chinh phai la con so goc, con phan cuong hoa nam o nhan "+".
	var prop := _text(scr, "bmfEquipMainUIProperty")
	_check(prop == "Cong 100.0", "chi so chinh", prop)
	var add := _text(scr, "bmfEquipMainUIPropertyAdd")
	_check(add.begins_with("+") and add != "+0.0", "phan cuong hoa cong them", add)

	var cap := _text(scr, "ttfEquipMainUIFightingCapacity")
	_check(cap.begins_with("Luc chien "), "luc chien", cap)

	# Cap 5 >= 4 nen thuoc tinh phu da mo, va chi mang hien theo phan tram.
	var ap1 := _text(scr, "ttfEquipMainUIAppendProperty1")
	# Chi mang cua thuoc tinh phu tinh theo DIEM PHAN TRAM: coef 0.1, base 1.0,
	# pham 2, he so cap 20 -> 0.1 * (2 - 0.3) * 1 = 0.17 diem phan tram.
	_check(ap1 == "Chi mang +0.17%", "thuoc tinh phu theo diem phan tram", ap1)

	print("\n=== 3. bang cuong hoa: hien tai va sau khi cuong hoa ===")
	_check(_text_cls(scr, scr.CLS_NOW_LEVEL) == "+3", "cap hien tai",
			_text_cls(scr, scr.CLS_NOW_LEVEL))
	_check(_text_cls(scr, scr.CLS_AFTER_LEVEL) == "+4", "cap sau khi cuong hoa",
			_text_cls(scr, scr.CLS_AFTER_LEVEL))
	var now_main := _text_cls(scr, scr.CLS_NOW_MAIN)
	var aft_main := _text_cls(scr, scr.CLS_AFTER_MAIN)
	_check(now_main != aft_main, "cuong hoa lam chi so tang len that",
			"%s -> %s" % [now_main, aft_main])
	_check(scr.cost_now() == ceili(Equipment.intensify_cost(4)),
			"gia dung cong thuc cap ke", str(scr.cost_now()))
	var btn := XggLayout.find_node(scr.ui, "snsEquipIntensify")
	_check(btn != null and btn.visible, "co nut cuong hoa")
	_check(btn != null and btn.modulate.r > 0.9, "du vang thi nut sang binh thuong")

	print("\n=== 3b. bang tinh luyen ===")
	_check(scr.tab == "intensify", "mo bang cuong hoa truoc", scr.tab)
	var pan_in := XggLayout.find_node(scr.ui, "lEquipmentIntensifyUI")
	var pan_rf := XggLayout.find_node(scr.ui, "lEquipmentRefineUI")
	scr._set_tab("refine")
	_check(pan_rf != null and pan_rf.visible, "doi sang bang tinh luyen")
	_check(pan_in != null and not pan_in.visible, "bang cuong hoa an di")

	# O vu khi: gia cap 1 la 40 (bang goc); o khac la 30.
	_check(scr.refine_cost_now() == 40, "gia tinh luyen cap 1 cua vu khi",
			str(scr.refine_cost_now()))
	var rbtn := XggLayout.find_by_cls(scr.ui, scr.CLS_REFINE_BTN)
	_check(rbtn != null and rbtn.visible, "co nut tinh luyen")
	_check(rbtn != null and rbtn.modulate.r > 0.9, "co 100 tinh hoa thi du 40")

	var step := XggLayout.find_by_cls(scr.ui, scr.CLS_REFINE_STEP)
	_check(step != null and step.visible, "hien khoi truoc/sau khi tinh luyen")
	var now_g := _text_of(scr, scr._child(step, scr.CLS_GRADE_NOW))
	var next_g := _text_of(scr, scr._child(step, scr.CLS_GRADE_NEXT))
	_check(now_g == "Bac 0", "cap hien tai", now_g)
	_check(next_g == "Bac 1", "cap ke", next_g)
	var now_v := _text_of(scr, scr._child(step, scr.CLS_ADD_NOW))
	var next_v := _text_of(scr, scr._child(step, scr.CLS_ADD_NEXT))
	_check(now_v == "Cong 100.0", "chi so chinh hien tai", now_v)
	_check(next_v == "Cong 105.0", "sau mot cap thi +5%", next_v)

	print("\n=== 3c. thieu tinh hoa / het cap tinh luyen ===")
	var thin := data.duplicate(true)
	thin["concentrate"] = 5
	scr.set_data(thin, ["MaChao", "GanNing"])
	scr.part = 1
	scr._refresh()
	_check(rbtn != null and rbtn.modulate.r < 0.9, "thieu tinh hoa thi nut mo di")
	_check(scr._tips.text.begins_with("Thieu tinh hoa"),
			"bao truoc khi bam", scr._tips.text)

	var maxed_rf := {
		"gold": 500, "concentrate": 9999, "maxIntensify": 200, "maxRefine": 5,
		"equipment": {"MaChao": [_item(1, Equipment.AP, 100.0, 5, 0, [], 5)]},
	}
	scr.set_data(maxed_rf, ["MaChao"])
	scr.part = 1
	scr._refresh()
	_check(scr.refine_cost_now() == 0, "het cap thi khong con gia",
			str(scr.refine_cost_now()))
	_check(rbtn != null and not rbtn.visible, "het cap thi giau nut tinh luyen")
	var full := XggLayout.find_by_cls(scr.ui, scr.CLS_REFINE_FULL)
	_check(full != null and full.visible, "hien khoi 'da het cap'")
	_check(_text_of(scr, scr._child(full, scr.CLS_GRADE_NOW)) == "Bac 5",
			"khoi het cap ghi dung cap",
			_text_of(scr, scr._child(full, scr.CLS_GRADE_NOW)))
	# Va chi so chinh phai la 125 = 100 * 1.25.
	_check(_text_of(scr, scr._child(full, scr.CLS_ADD_NOW)) == "Cong 125.0",
			"tinh luyen 5 cong 25% vao chi so chinh",
			_text_of(scr, scr._child(full, scr.CLS_ADD_NOW)))

	# Tra lai trang thai cho cac muc sau.
	scr.set_data(data, ["MaChao", "GanNing"])
	scr._set_tab("intensify")
	scr.part = 1
	scr._refresh()

	print("\n=== 3d. bang ghep do ===")
	scr.set_data(data, ["MaChao", "GanNing"])
	scr.part = 1
	scr._set_tab("forge")
	var pan_fg := XggLayout.find_node(scr.ui, "lEquipmentForgeUI")
	_check(pan_fg != null and pan_fg.visible, "doi sang bang ghep do")
	_check(pan_rf != null and not pan_rf.visible, "bang tinh luyen an di")

	# Bang goc co ba bien the khung theo SO nguyen lieu — hai mon thi phai
	# dung khung "2 nguyen lieu", con hai khung kia phai an.
	var box2 := XggLayout.find_by_cls(pan_fg, scr.CLS_FORGE_CONSUME[2])
	var box3 := XggLayout.find_by_cls(pan_fg, scr.CLS_FORGE_CONSUME[3])
	_check(box2 != null and box2.visible, "hai nguyen lieu thi dung khung 2 o")
	_check(box3 != null and not box3.visible, "khung 3 o phai an")

	var nm2 := _text_of(scr, XggLayout.find_by_cls(box2, scr.CLS_FORGE_NAME))
	_check(nm2 == "Vu khi  cap 5 -> 6", "ten va buoc cap", nm2)
	var tip2 := _text_of(scr, XggLayout.find_by_cls(box2, scr.CLS_FORGE_TIPS))
	_check(tip2 == "tuong cap 31/20", "cap tuong hien tai tren cap doi hoi", tip2)

	var gold_box := XggLayout.find_node(scr.ui, "g_EquipForgeUIGoldCost")
	_check(gold_box != null and gold_box.visible, "hien khoi gia vang")
	_check(_text_of(scr, XggLayout.find_by_cls(gold_box, scr.CLS_FORGE_GOLD))
			== "3700", "gia vang dung bang goc")

	var fbtn := XggLayout.find_node(scr.ui, "snsEquipForge")
	_check(fbtn != null and fbtn.visible, "co nut ghep do")
	# Du lieu gia co 500 vang ma gia 3700 -> phai mo di va bao truoc.
	_check(fbtn != null and fbtn.modulate.r < 0.9, "thieu vang thi nut mo di")
	_check(scr._tips.text.begins_with("Thieu vang"), "bao truoc",
			scr._tips.text)

	# Hai o nguyen lieu phai duoc dien, o thu ba phai an.
	var slot1 := XggLayout.find_node(box2, "btnEquipForgeConsumeUI2_Icon1")
	var slot2 := XggLayout.find_node(box2, "btnEquipForgeConsumeUI2_Icon2")
	_check(slot1 != null and slot1.visible and slot2 != null and slot2.visible,
			"hien du hai o nguyen lieu")
	_check(_text_of(scr, slot1) == "5/3" and _text_of(scr, slot2) == "9/5",
			"hien so dang co tren so can",
			"%s / %s" % [_text_of(scr, slot1), _text_of(scr, slot2)])

	print("\n=== 3e. chua du cap tuong / het cap ===")
	var low := data.duplicate(true)
	low["equipment"]["MaChao"][0]["synthesis"]["ready"] = false
	low["equipment"]["MaChao"][0]["synthesis"]["reason"] = "can tuong cap 20"
	scr.set_data(low, ["MaChao"])
	scr.part = 1
	scr._refresh()
	_check(scr._tips.text.begins_with("Chua ghep duoc"),
			"chua du cap tuong thi noi ro", scr._tips.text)

	var top := {
		"gold": 9999999, "concentrate": 0, "maxIntensify": 200, "maxRefine": 5,
		"equipment": {"MaChao": [_item(1, Equipment.AP, 100.0, 10, 0)]},
	}
	scr.set_data(top, ["MaChao"])
	scr.part = 1
	scr._refresh()
	_check(fbtn != null and not fbtn.visible, "het cap thi giau nut ghep")
	var maxnote := XggLayout.find_node(scr.ui, "lEquipForgeUI_IsMaxLevel")
	_check(maxnote != null and maxnote.visible, "hien dong 'da toi cap cao nhat'")

	scr.set_data(data, ["MaChao", "GanNing"])
	scr._set_tab("intensify")
	scr.part = 1
	scr._refresh()

	print("\n=== 3f. do chuyen thuoc ===")
	# Da tay bac 5: bang tinh luyen phai doi thanh che do REN, dung y ban goc
	# (EquipRefineType.OpenExclusive) chu khong mo mot tab thu tu.
	var ready_forge := {
		"gold": 500, "concentrate": 100, "maxIntensify": 200, "maxRefine": 5,
		"maxPurify": 20,
		"equipment": {"MaChao": [{
			"part": 4, "level": 3, "intensify": 0, "quality": 2, "refine": 5,
			"equipType": 42, "exclusive": false,
			"main": {"type": Equipment.HP_LIMIT, "value": 100.0},
			"appends": [], "capacity": 12.5,
			"exclusiveReady": {"ready": true, "reason": "", "needRefine": 5,
				"materials": [[212, 5]]},
		}]},
	}
	scr.set_data(ready_forge, ["MaChao"])
	scr.part = 4
	scr._set_tab("refine")
	var rbtn2 := XggLayout.find_by_cls(scr.ui, scr.CLS_REFINE_BTN)
	var btn_txt := ""
	for c in rbtn2.get_children():
		if c is Label:
			btn_txt = (c as Label).text
	_check(btn_txt == "Ren chuyen thuoc",
			"tay bac 5 thi nut doi thanh nut ren", btn_txt)
	_check(scr._tips.text.contains("chuyen thuoc"), "bao cho nguoi choi biet",
			scr._tips.text)
	# Ren thi khong ton tinh hoa nen khoi gia phai an.
	var cost_box := XggLayout.find_by_cls(scr.ui, scr.CLS_REFINE_COST)
	_check(cost_box != null and not cost_box.visible,
			"che do ren thi khong hien gia tinh hoa")

	# Da la do chuyen thuoc: duong tay 21 bac, bat dau +25%.
	var exc := {
		"gold": 500, "concentrate": 100000, "maxIntensify": 200,
		"maxRefine": 5, "maxPurify": 20,
		"equipment": {"MaChao": [{
			"part": 4, "level": 3, "intensify": 0, "quality": 2, "refine": 5,
			"equipType": 42, "exclusive": true, "purify": 3,
			"purifyPercent": 40.0, "nextPurifyCost": 200,
			"main": {"type": Equipment.HP_LIMIT, "value": 100.0},
			"appends": [], "capacity": 14.0,
		}]},
	}
	scr.set_data(exc, ["MaChao"])
	scr.part = 4
	scr._refresh()
	var e_exc: Equipment = scr._model(scr.item())
	_check(e_exc.exclusive and e_exc.bonus_percent() == 40.0,
			"doc dung bac tay va phan tram", str(e_exc.bonus_percent()))
	_check(is_equal_approx(e_exc.effective_main(), 140.0),
			"chi so chinh = 100 * 1.40", str(e_exc.effective_main()))
	_check(scr.refine_cost_now() == 200, "gia bac ke lay tu may chu",
			str(scr.refine_cost_now()))
	var step2 := XggLayout.find_by_cls(scr.ui, scr.CLS_REFINE_STEP)
	_check(_text_of(scr, scr._child(step2, scr.CLS_GRADE_NOW)) == "Bac 3",
			"bac hien tai", _text_of(scr, scr._child(step2, scr.CLS_GRADE_NOW)))
	_check(_text_of(scr, scr._child(step2, scr.CLS_GRADE_NEXT)) == "Bac 4",
			"bac ke")
	# Ky nang cua o 4 la chi mang.
	var sk: Array = e_exc.skills()
	_check(sk.size() == 1 and String(sk[0][0]) == "ZhuanShuXiangLian",
			"o 4 cho ky nang chi mang", str(sk))
	_check(is_equal_approx(float(Equipment.to_buffs([e_exc]).get("crit", 0.0)), 0.10),
			"ky nang quy ra buff crit +10%")

	scr.set_data(data, ["MaChao", "GanNing"])
	scr._set_tab("intensify")
	scr.part = 1
	scr._refresh()

	print("\n=== 3g. bang tay luyen ===")
	var alter_data := {
		"gold": 50000, "concentrate": 0, "maxIntensify": 200, "maxRefine": 5,
		"maxPurify": 20,
		"equipment": {"MaChao": [_item(1, Equipment.AP, 100.0, 5, 0, [
			Equipment.make_append(Equipment.HP_LIMIT, 0.85, 2.0, 20.0),
			Equipment.make_append(Equipment.CRITICAL_STRIKE, 1.25, 2.0, 20.0)])]},
	}
	scr.set_data(alter_data, ["MaChao"])
	scr.part = 1
	scr._set_tab("alter")
	var pan_al := XggLayout.find_node(scr.ui, "lEquipmentAlterUI")
	_check(pan_al != null and pan_al.visible, "doi sang bang tay luyen")
	_check(pan_fg != null and not pan_fg.visible, "bang ghep do an di")

	var line1 := _text_of(scr, XggLayout.find_by_cls(pan_al, "属性1"))
	_check(line1.begins_with("Mau "), "dong 1 la thuoc tinh mau", line1)
	var max1 := _text_of(scr, XggLayout.find_by_cls(pan_al, "最大值1"))
	_check(max1.begins_with("10 diem"), "base 0.85 duoc 10 diem", max1)
	var max2 := _text_of(scr, XggLayout.find_by_cls(pan_al, "最大值2"))
	_check(max2.begins_with("60 diem"), "base 1.25 duoc 60 diem", max2)
	# Dong 3 tro di phai trong.
	_check(_text_of(scr, XggLayout.find_by_cls(pan_al, "属性3")) == "",
			"chi hien dung so dong co that")
	var tip_al := _text_of(scr, XggLayout.find_by_cls(pan_al, scr.CLS_ALTER_TIPS))
	_check(tip_al == "Tong 70 diem", "tong diem = 10 + 60", tip_al)

	# Chi mang cua thuoc tinh phu tinh theo DIEM PHAN TRAM, khong phai phan so.
	var line2 := _text_of(scr, XggLayout.find_by_cls(pan_al, "属性2"))
	var want_v: float = Equipment.append_value(1.25, Equipment.CRITICAL_STRIKE, 2.0, 20.0)
	_check(line2 == "Chi mang %.2f%%" % want_v,
			"hien dung don vi diem phan tram", line2)

	var abtn := XggLayout.find_by_cls(pan_al, scr.CLS_ALTER_BTN)
	_check(abtn != null and abtn.visible, "co nut tay luyen")
	_check(abtn != null and abtn.modulate.r > 0.9, "co 50 000 vang thi du 10 000")
	var gbox := XggLayout.find_by_cls(pan_al, scr.CLS_ALTER_GOLD_BOX)
	_check(_text_of(scr, XggLayout.find_node(gbox, "uiGoldIconCount")) == "10000",
			"gia tay luyen dung bang goc")

	# Tay cao cap ton kim cuong, va dem da tay luyen — chua co, phai an.
	var adv := XggLayout.find_by_cls(pan_al, scr.CLS_ALTER_BTN_ADV)
	_check(adv != null and not adv.visible, "nut tay cao cap (kim cuong) an di")
	var stone := XggLayout.find_node(scr.ui, "g_AlterStroeCount")
	_check(stone != null and not stone.visible, "dem da tay luyen an di")

	print("\n=== 3h. mon chua mo thuoc tinh phu ===")
	var no_ap := {
		"gold": 50000, "concentrate": 0, "maxIntensify": 200, "maxRefine": 5,
		"maxPurify": 20,
		"equipment": {"MaChao": [_item(1, Equipment.AP, 100.0, 2, 0, [])]},
	}
	scr.set_data(no_ap, ["MaChao"])
	scr.part = 1
	scr._refresh()
	_check(abtn != null and not abtn.visible, "khong co thuoc tinh phu thi giau nut")
	_check(scr._tips.text.begins_with("Mon nay chua co"), "noi ro vi sao",
			scr._tips.text)

	scr.set_data(data, ["MaChao", "GanNing"])
	scr._set_tab("intensify")
	scr.part = 1
	scr._refresh()

	print("\n=== 3i. bang nang pham chat ===")
	scr.set_data(data, ["MaChao", "GanNing"])
	scr.part = 1
	scr._set_tab("quality")
	var pan_q := XggLayout.find_node(scr.ui, "lEquipmentUpgradeQualityUI")
	_check(pan_q != null and pan_q.visible, "doi sang bang nang pham")
	_check(pan_al != null and not pan_al.visible, "bang tay luyen an di")

	var now_box := XggLayout.find_node(pan_q, "g_UpgradeQualityActionEndLayer")
	var next_box := XggLayout.find_node(pan_q, "g_UpgradeQualityActionBeginLayer")
	_check(now_box != null and next_box != null, "co ca hai khoi truoc/sau")
	_check(_text_of(scr, scr._child(now_box, "品质")) == "Pham 2",
			"khoi trai la pham hien tai",
			_text_of(scr, scr._child(now_box, "品质")))
	_check(_text_of(scr, scr._child(next_box, "品质")) == "Pham 3",
			"khoi phai la pham ke",
			_text_of(scr, scr._child(next_box, "品质")))
	# Chi so chinh o pham moi phai CAO HON, khong duoc thap hon.
	var now_txt := _text_of(scr, scr._child(now_box, "主属性"))
	var next_txt := _text_of(scr, scr._child(next_box, "主属性"))
	var q_now := now_txt.get_slice(" ", 1).to_float()
	var q_next := next_txt.get_slice(" ", 1).to_float()
	_check(q_next > q_now, "nang pham thi chi so chinh cao hon",
			"%s -> %s" % [now_txt, next_txt])

	var gold_q := XggLayout.find_node(pan_q, "g_EquipQualityUIGoldCost")
	_check(gold_q != null and gold_q.visible, "hien khoi gia vang")
	_check(_text_of(scr, XggLayout.find_by_cls(gold_q, scr.CLS_FORGE_GOLD)) == "10",
			"gia len pham 3 dung bang goc")
	var qbtn := XggLayout.find_node(pan_q, "snsEquipUpgradeQuality")
	_check(qbtn != null and qbtn.visible, "co nut nang pham")
	_check(qbtn != null and qbtn.modulate.r > 0.9, "du vang thi nut sang")
	var qmat := XggLayout.find_node(pan_q, "g_UpgradeQualityActionMaterialItem")
	_check(qmat != null and qmat.visible and _text_of(scr, qmat) == "3/1",
			"hien nguyen lieu ban goc doi", _text_of(scr, qmat))

	print("\n=== 3j. het pham / chua du cap tuong ===")
	var topq := {
		"gold": 500000, "concentrate": 0, "maxIntensify": 200, "maxRefine": 5,
		"maxPurify": 20, "maxQuality": 6,
		"equipment": {"MaChao": [_item(1, Equipment.AP, 100.0, 5, 0)]},
	}
	topq["equipment"]["MaChao"][0]["qualityUp"] = null
	scr.set_data(topq, ["MaChao"])
	scr.part = 1
	scr._refresh()
	_check(qbtn != null and not qbtn.visible, "het pham thi giau nut")
	var qnote := XggLayout.find_node(pan_q, "lEquipUpgradeQualityUIMaxLevelTips")
	_check(qnote != null and qnote.visible, "hien dong da toi pham cao nhat")

	var lowq := data.duplicate(true)
	lowq["equipment"]["MaChao"][0]["qualityUp"]["ready"] = false
	lowq["equipment"]["MaChao"][0]["qualityUp"]["reason"] = "can tuong cap 35"
	scr.set_data(lowq, ["MaChao"])
	scr.part = 1
	scr._refresh()
	_check(scr._tips.text.begins_with("Chua nang duoc"),
			"chua du cap tuong thi noi ro", scr._tips.text)

	scr.set_data(data, ["MaChao", "GanNing"])
	scr._set_tab("intensify")
	scr.part = 1
	scr._refresh()

	print("\n=== 3k. ky nang vu khi chuyen thuoc ===")
	var wdata := {
		"gold": 500, "concentrate": 0, "maxIntensify": 200, "maxRefine": 5,
		"maxPurify": 20, "maxQuality": 6,
		"weaponSkills": {"XiaoQiao": {"skill": "ShenQinRaoLiang",
			"buffs": {"pierce": 0.1, "anger": 35.0}, "modelled": true}},
		"equipment": {"XiaoQiao": [{
			"part": 1, "level": 5, "intensify": 0, "quality": 2, "refine": 5,
			"equipType": 3, "exclusive": true, "purify": 0,
			"purifyPercent": 25.0, "nextPurifyCost": 100,
			"main": {"type": Equipment.AP, "value": 100.0},
			"appends": [], "capacity": 112.5, "levelCoef": 20.0,
		}]},
	}
	scr.set_data(wdata, ["XiaoQiao"])
	scr.part = 1
	scr._refresh()
	var wtip := _text(scr, "ttfHeroEquipmentUITips")
	_check(wtip.begins_with("Ky nang vu khi: ShenQinRaoLiang"),
			"hien ten ky nang vu khi", wtip)
	_check(not wtip.contains("chua mo phong"),
			"ky nang nay mo phong duoc nen khong ghi chu them", wtip)

	# Ky nang may trang thai: van hien ten, nhung noi ro la chua mo phong.
	var wdata2 := wdata.duplicate(true)
	wdata2["weaponSkills"] = {"XiaoQiao": {"skill": "ShenQiangLongDan",
			"buffs": {}, "modelled": false}}
	scr.set_data(wdata2, ["XiaoQiao"])
	scr.part = 1
	scr._refresh()
	_check(_text(scr, "ttfHeroEquipmentUITips").contains("chua mo phong"),
			"noi ro ky nang chua mo phong", _text(scr, "ttfHeroEquipmentUITips"))

	# O khac vu khi thi khong hien dong nay.
	scr.part = 2
	scr._refresh()
	_check(_text(scr, "ttfHeroEquipmentUITips") == "",
			"chi hien o o vu khi", _text(scr, "ttfHeroEquipmentUITips"))

	scr.set_data(data, ["MaChao", "GanNing"])
	scr._set_tab("intensify")
	scr.part = 1
	scr._refresh()

	print("\n=== 3l. nguyen lieu: co/can ===")
	var mdata := data.duplicate(true)
	mdata["save"] = {"items": {"25": 1, "52": 9}}
	scr.set_data(mdata, ["MaChao"])
	scr.part = 1
	scr._set_tab("forge")
	var pan_fg2 := XggLayout.find_node(scr.ui, "lEquipmentForgeUI")
	var box_m := XggLayout.find_by_cls(pan_fg2, scr.CLS_FORGE_CONSUME[2])
	var s1 := XggLayout.find_node(box_m, "btnEquipForgeConsumeUI2_Icon1")
	var s2 := XggLayout.find_node(box_m, "btnEquipForgeConsumeUI2_Icon2")
	# Bang gia doi 25 x3 va 52 x5; tui co 1 va 9.
	_check(_text_of(scr, s1) == "1/3", "o thieu hien co/can", _text_of(scr, s1))
	_check(_text_of(scr, s2) == "9/5", "o du cung hien co/can", _text_of(scr, s2))
	var lb1: Label = scr._ensure_label(s1)
	var lb2: Label = scr._ensure_label(s2)
	_check(lb1.modulate.g < 0.9, "thieu thi to do")
	_check(lb2.modulate.g > 0.9, "du thi de mau thuong")
	var fbtn2 := XggLayout.find_node(scr.ui, "snsEquipForge")
	_check(fbtn2 != null and fbtn2.modulate.r < 0.9,
			"thieu nguyen lieu thi nut mo di")
	_check(scr._tips.text == "Thieu nguyen lieu", "va noi ro la thieu gi",
			scr._tips.text)

	# Du ca hai thi nut sang lai (van con dieu kien vang).
	var mdata2 := data.duplicate(true)
	mdata2["gold"] = 999999
	mdata2["save"] = {"items": {"25": 5, "52": 9}}
	scr.set_data(mdata2, ["MaChao"])
	scr.part = 1
	scr._refresh()
	_check(fbtn2 != null and fbtn2.modulate.r > 0.9,
			"du ca nguyen lieu lan vang thi nut sang")

	scr.set_data(data, ["MaChao", "GanNing"])
	scr._set_tab("intensify")
	scr.part = 1
	scr._refresh()

	print("\n=== 4. o trong ===")
	scr.part = 3          # day chuyen: MaChao khong co
	scr._refresh()
	_check(_text(scr, "bmfEquipMainUIProperty") == "O nay chua co do",
			"noi ro o trong", _text(scr, "bmfEquipMainUIProperty"))
	_check(btn != null and not btn.visible, "o trong thi khong hien nut cuong hoa")
	_check(scr.cost_now() == 0, "o trong thi khong co gia")

	print("\n=== 5. hai mui ten cua ban goc duyet het 6 o ===")
	scr.part = 1
	var seen: Array = []
	for i in 6:
		seen.append(scr.part)
		scr._step_part(1)
	_check(seen == [1, 2, 3, 4, 5, 6], "sang phai di het 6 o roi quay lai", str(seen))
	_check(scr.part == 1, "quay ve o dau")
	scr._step_part(-1)
	_check(scr.part == 6, "sang trai tu o 1 thi ve o 6", str(scr.part))

	print("\n=== 6. doi tuong ===")
	scr.part = 1
	scr._step_hero(1)
	_check(scr.hero() == "GanNing", "sang tuong sau", scr.hero())
	var g_prop := _text(scr, "bmfEquipMainUIProperty")
	_check(g_prop == "Cong 40.0", "hien do CUA tuong do", g_prop)
	scr._step_hero(-1)
	_check(scr.hero() == "MaChao", "quay lai tuong truoc")

	print("\n=== 7. thieu vang ===")
	var poor := data.duplicate(true)
	poor["gold"] = 1
	scr.set_data(poor, ["MaChao", "GanNing"])
	scr.part = 1
	scr._refresh()
	_check(btn != null and btn.modulate.r < 0.9, "thieu vang thi nut mo di")
	_check(scr._tips.text.begins_with("Thieu vang"), "bao truoc chu khong de bam roi loi",
			scr._tips.text)

	print("\n=== 8. da toi cap cao nhat ===")
	var maxed := {
		"gold": 999999999, "maxIntensify": 200,
		"equipment": {"MaChao": [_item(1, Equipment.AP, 100.0, 5, 200)]},
	}
	scr.set_data(maxed, ["MaChao"])
	scr.part = 1
	scr._refresh()
	_check(btn != null and not btn.visible, "het cap thi giau nut cuong hoa")
	var note := XggLayout.find_by_cls(scr.ui, scr.CLS_MAXED)
	_check(note != null and note.visible, "hien dong bao da toi cap cao nhat")

	scr.free()
	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	_done(1 if n_fail > 0 else 0)


func _done(code: int) -> void:
	get_tree().quit(code)
