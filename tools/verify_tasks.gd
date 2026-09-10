# Kiem man thanh tuu / nhiem vu ngay, khong can may chu.
#
#   godot --headless --path . tools/verify_tasks.tscn
#
# Dua cho man mot ban tra loi bx.tasks bia ra (ui/tasks.gd: fake_data) roi kiem
# dung nhung dieu ban goc lam: chi hien chuoi dang lam / da dat, da dat len
# dau, nut nhan chi co khi da dat, vang theo cap tinh bang cap nguoi choi.
extends Node

var n_pass := 0
var n_fail := 0


func _check(ok: bool, desc: String, detail: String = "") -> void:
	if ok:
		n_pass += 1
		print("  dat   ", desc)
	else:
		n_fail += 1
		print("  HONG  ", desc, "" if detail == "" else "  -> " + detail)


func _rows(ui: Node) -> Array:
	var out: Array = []
	for c in ui.get_node("Frame/Scroll/List").get_children():
		if c.has_meta("type"):
			out.append(c)
	return out


func _row(ui: Node, t: int) -> Node:
	for r in _rows(ui):
		if int(r.get_meta("type")) == t:
			return r
	return null


func _text(row: Node, nm: String) -> String:
	if row == null:
		return "<khong co dong>"
	var n := row.get_node_or_null(nm)
	return (n as Label).text if n is Label else "<khong co %s>" % nm


func _ready() -> void:
	var ui: Control = load("res://ui/tasks.tscn").instantiate()
	ui.set_meta("no_session", true)
	add_child(ui)
	await get_tree().process_frame
	var fake: Dictionary = ui.fake_data()
	ui.set_data(fake)

	print("=== 1. bang thanh tuu ===")
	var rows := _rows(ui)
	_check(rows.size() == 3, "chuoi da nhan het thi an (3 dong, khong phai 4)",
			str(rows.size()))
	_check(rows.size() > 0 and int(rows[0].get_meta("type")) == 9,
			"chuoi da dat xep len dau", str(rows[0].get_meta("type")) if rows.size() > 0 else "")
	var r9 := _row(ui, 9)
	var r6 := _row(ui, 6)
	_check(r9 != null and r9.get_node_or_null("Claim") != null,
			"da dat thi co nut nhan")
	_check(r6 != null and r6.get_node_or_null("Claim") == null,
			"dang lam thi khong co nut nhan")
	_check(_text(r6, "Progress") == "(0/1)", "dang lam thi hien (dang co/can)",
			_text(r6, "Progress"))
	var r14 := _row(ui, 14)
	_check(_text(r14, "Reward1") == "X10000", "phan thuong vang hien dung so",
			_text(r14, "Reward1"))
	_check(_text(r14, "NotGranted").find("kim cuong") >= 0,
			"thu khong co cho chua ghi 'chua trao'", _text(r14, "NotGranted"))
	_check(_text(r9, "Desc") == "3 tuong dat cap 10", "mo ta sinh tu dieu kien",
			_text(r9, "Desc"))

	print("\n=== 2. bang nhiem vu ngay ===")
	ui.set_tab("daily")
	rows = _rows(ui)
	_check(rows.size() == 2, "hai nhiem vu ngay", str(rows.size()))
	_check(rows.size() > 0 and int(rows[0].get_meta("type")) == 113,
			"nhiem vu da dat len dau")
	var r103 := _row(ui, 103)
	# 200 vang moi cap x cap nguoi choi 12 = 2400.
	_check(_text(r103, "Reward1") == "X2400", "vang theo cap = 200 x cap nguoi choi",
			_text(r103, "Reward1"))
	_check(_text(r103, "Desc").find("10") >= 0, "mo ta ghi so tran can thang",
			_text(r103, "Desc"))
	var t151: String = ui._title({"type": 151, "kind": "counter"})
	_check(t151 == "Cuong hoa", "nhiem vu cua game moi co ten rieng", t151)
	var btn: Button = ui.get_node("Frame/Chest/ChestButton")
	var lbl: Label = ui.get_node("Frame/Chest/ChestLabel")
	_check(btn.disabled, "chua du nang dong thi khoa ruong")
	_check(lbl.text.find("1/5") >= 0, "hien nang dong 1/5", lbl.text)
	_check(ui.get_node("Frame/Chest").visible, "bang ngay thi hien khoi ruong")

	var ready: Dictionary = fake.duplicate(true)
	ready["chest"] = {"liveness": 5, "claimed": 0, "need": 5, "ready": true,
			"done": false}
	ui.set_data(ready)
	_check(not btn.disabled, "du nang dong thi mo khoa ruong")
	var gone: Dictionary = fake.duplicate(true)
	gone["chest"] = {"liveness": 5, "claimed": 1, "done": true}
	ui.set_data(gone)
	_check(btn.disabled and btn.text == "Da nhan", "da nhan ruong thi khoa lai",
			btn.text)

	print("\n=== 3. doi bang, du lieu rong ===")
	ui.set_tab("achieve")
	_check(_rows(ui).size() == 3, "doi lai bang thanh tuu thi dung lai du 3 dong")
	_check(not ui.get_node("Frame/Chest").visible, "bang thanh tuu thi an ruong")
	ui.set_data({})
	_check(_rows(ui).size() == 0, "chua co du lieu thi khong co dong nao")

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	get_tree().quit(0 if n_fail == 0 else 1)
