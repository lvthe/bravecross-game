# Mo man Doanh Trai (BarracksMain) bang dung ma goc roi IN CA CAY NODE kem
# toa do THAT, de doi chieu voi bo cuc trong layout_ref/ va voi so ma Lua dat.
#
#   godot --headless --path . --script tools/do_doanh_trai.gd -- [--ra=C:/tmp/dtai.txt] [--man=BarracksMain]
#
# VI SAO PHAI CO BO DO NAY. `do_mot_man.gd` chi dem luot hoi tag — no khong noi
# node nam o dau. Ma loi bo cuc thi dung la loi CHO NAM: nhan ve hai lan lech
# nhau, tam nen thieu, o sai kich thuoc. Muon biet node nao ve cai gi thi phai
# doc toa do cua chinh node do, roi doi chieu voi:
#   - bo cuc tinh: layout_ref/UI_Barracks_MainUI_960_640.json (toa do goc trong
#     file .xgg, da doi ve he Godot theo cung luat xgg_layout.gd),
#   - node do Lua dung ra: so nam ngay trong ma (`setPosition`, `addChild`).
#
# Engine size dat 960x640 (khong phai co gian) de toa do in ra nam DUNG he cua
# bo cuc — co gian chi nhan them mot he so, khong lam mot node sai cho tro thanh
# dung.
extends SceneTree

const VaoMain := preload("res://tools/vao_main.gd")

## Che do chup anh (xem `_process`). Rong = chi ket xuat cay node roi thoat.
var _chup := ""
var _khung := 45
var _stage: Control = null
var _lua: LuaRuntime = null
var _dem := 0

const _MO := """
	local c = require('cocos')
	local ra = {}
	local ql = g_CUINormalDlg
	local ok, err = pcall(function() ql:Show('%s', {}, 1) end)
	if not ok then return 'SHOW HONG: ' .. tostring(err) end
	-- onVisible nam trong OnShowAnimationFinish (S_CCSequence + delay), phai co
	-- khung troi qua moi chay — xem do_mot_man.gd:52-61.
	local ok2, err2 = pcall(function() for _ = 1, 40 do c.tick(0.05) end end)
	if not ok2 then return 'TICK HONG: ' .. tostring(err2) end
	return 'ok'
"""


func _init() -> void:
	var ra := "C:/tmp/dtai.txt"
	var man := "BarracksMain"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ra="):
			ra = a.substr(5)
		elif a.begins_with("--man="):
			man = a.substr(6)
		elif a.begins_with("--chup="):
			_chup = a.substr(7)
		elif a.begins_with("--khung="):
			_khung = int(a.substr(8))

	var lua := LuaRuntime.new()
	lua.cua_so_engine = Vector2(960, 640)
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return
	_lua = lua
	XggLayout.respect_visible = true

	var san := Control.new()
	san.size = Vector2(960, 640)
	lua.set_stage(san)
	lua.set_touch_root(san)

	if lua.run(VaoMain._NAP, "nap") == null:
		print("nap hong")
		quit(1)
		return
	var d := VaoMain.chay(lua)
	if d["dung"] != "":
		print("KHONG vao duoc Main: %s" % d["dung"])
		quit(1)
		return

	var r = lua.run(_MO % man, "mo " + man)
	print("mo man: ", r)

	var goc := _tim_goc(san)
	if goc == null:
		print("khong thay node man tren san khau")
		quit(1)
		return

	var dong := []
	_xuat(goc, dong, 0)
	var f := FileAccess.open(ra, FileAccess.WRITE)
	for s in dong:
		f.store_line(s)
	f.close()
	print("ghi %d dong vao %s" % [dong.size(), ra])

	# Anh: phai chay CO trinh ve (khong `--headless`) va phai giu cay song qua
	# mot vai khung, khong thi khong co gi de chup. San khau duoc gan vao
	# `root` ngay o day — `set_stage` chi nho no chu KHONG them vao cay (xem
	# `LuaRuntime.set_stage`).
	if _chup != "":
		san.size = Vector2(960, 640)
		root.add_child(san)
		_stage = san
		print("cho %d khung roi chup %s" % [_khung, _chup])
		return
	quit()


## Dem khung roi luu anh. `san` khong thu nho: cua so 960x640 (co dinh trong
## `project.godot`), san khau dung 960x640, nen TOA DO TRONG ANH TRUNG KHUNG voi
## toa do trong ban ket xuat — nhin mot dong `g=(x,y)` la chi duoc vao diem anh.
func _process(_dt: float) -> bool:
	if _stage == null:
		return false
	_lua.tick(_dt)
	_dem += 1
	if _dem >= _khung:
		var img := root.get_texture().get_image()
		var e := img.save_png(_chup)
		print("chup %s (%dx%d) loi=%d" % [_chup, img.get_width(), img.get_height(), e])
		return true
	return false


## Node goc cua man: node co meta type_name ma ten bat dau bang "lBarracksMainUI".
func _tim_goc(san: Control) -> Node:
	var ung := []
	_quet(san, ung)
	for n in ung:
		if String(n.name).begins_with("lBarracksMainUI"):
			return n
	return null


func _quet(n: Node, ra: Array) -> void:
	for c in n.get_children():
		if c.has_meta("type_name"):
			ra.append(c)
		_quet(c, ra)


## In mot node thanh mot dong; de quy xuong con.
func _xuat(n: Node, ra: Array, sau: int) -> void:
	var d := "  ".repeat(sau)
	var ten := String(n.name)
	var tn := String(n.get_meta("type_name", "")) if n.has_meta("type_name") else ""
	var tag := ("#%s" % str(n.get_meta("tag"))) if n.has_meta("tag") else ""
	var lop := n.get_class()
	var vt := ""
	var co := ""
	if n is Control:
		var c := n as Control
		var r := c.get_global_rect()
		vt = "g=(%.2f,%.2f) o=%.2fx%.2f" % [r.position.x, r.position.y, r.size.x, r.size.y]
		co = " neo=%s" % str(c.get_meta("cocos", Vector4.ZERO)) if c.has_meta("cocos") else ""
	elif n is Node2D:
		var o := (n as Node2D).get_global_transform().origin
		vt = "g=(%.2f,%.2f)" % [o.x, o.y]
	var hien := "hien=%s" % str((n as CanvasItem).visible) if n is CanvasItem else ""
	var anh := ""
	if n.has_meta("img") and String(n.get_meta("img")) != "":
		anh = " img=%s%s" % [String(n.get_meta("img")),
				" [da gan]" if n.get_meta("img_applied", false) else " [KHONG GAN]"]
	var chu := ""
	if n is Label:
		chu = " chu=%s" % JSON.stringify((n as Label).text)
	elif n is TextureRect:
		chu = " anh=%s" % _anh((n as TextureRect).texture)
	elif n is NinePatchRect:
		chu = " anh=%s" % _anh((n as NinePatchRect).texture)
	var sc := ""
	if n is CanvasItem and not (n as CanvasItem).scale.is_equal_approx(Vector2.ONE):
		sc = " scale=%s" % str((n as CanvasItem).scale)
	ra.append("%s%-30s tag=%-6s %s <%s> %s%s%s%s%s%s" % [d, ten, tag, tn, lop, vt, co, hien, sc, anh, chu])
	for c in n.get_children():
		_xuat(c, ra, sau + 1)


## Mo ta anh DANG GAN THAT: duong dan tai nguyen + kich thuoc.
##
## VI SAO KHONG CHI IN KICH THUOC. Bon o binh trong Doanh Trai deu la o 80x100
## (kich thuoc hop node, lay tu .xgg), nen chi in kich thuoc thi sau o ra SAU
## DONG GIONG HET NHAU — khong tra loi duoc cau hoi "moi o co lay dung
## `ui_arms_%02d.png` cua Lua khong" (CUIBarracksMain.lua:285,
## `setDisplayFrame(spriteFrameByName(IconName))`). Duong dan tai nguyen thi
## tra loi duoc: khac ten tep la khac anh.
func _anh(t: Texture2D) -> String:
	if t == null:
		return "khong"
	var rp := t.resource_path
	if rp == "":
		rp = "?(khong co duong dan)"
	# Cat "res://assets_ref/..." cho dong ngan lai, phan dau giong nhau o moi dong.
	rp = rp.replace("res://assets_ref/", "")
	return "%s %dx%d" % [rp, t.get_width(), t.get_height()]
