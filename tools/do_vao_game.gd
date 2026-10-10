# Cua vao ve ra co GIONG duong `--script tools/vao_main.gd` khong — do bang
# DIEM ANH, khong bang thuoc tinh.
#
#   godot --path . --fixed-fps 30 --script tools/vao_main.gd -- --chup=D:/tmp/a.png
#   godot --path . --fixed-fps 30 tools/do_vao_game.tscn -- --chup=D:/tmp/b.png
#   godot --path . --fixed-fps 30 tools/do_vao_game.tscn -- --chup=D:/tmp/c.png --theme=san
#
#   python tools/lech_anh.py D:/tmp/a.png D:/tmp/b.png --cat=150:640 --giong   # nhan: 0 diem
#   python tools/lech_anh.py D:/tmp/b.png D:/tmp/c.png --cat=150:640 --doi     # chung nguoc: PHAI khac
#
# DO DUOC (2026-09-18, luot dau):
#
#   ngoai dai y < 150  — man vs --script: **0 diem khac / 470.400**, va cung
#   duong chay hai lan cung **0 diem** (nen khac biet khong the la do nhieu).
#   Chung nguoc `--theme=san`: **9.171 diem khac**, lech lon nhat 255 — phep so
#   CO LUC that.
#
#   trong dai y < 150 — **KHONG dat duoc 0 diem o bat ky duong nao**: cung mot
#   duong chay hai lan da khac nhau **15.236** diem (`man`) / **20.521** diem
#   (`--script`), con hai duong khac nhau **23.401** diem. Lay mat na ra thi
#   thay ro nguyen nhan: cac dom tron mem — **hat sang** bay tren nen troi
#   (`UITongYong`, xem CLAUDE.md muc "Dom xanh o Main"), pha cua chung doi giua
#   cac lan chay. Nen day KHONG phai khac biet cua duong vao; no la nhieu, va
#   `--cat=150:640` la cach loai no ra chu khong phai cach lam dep so.
#
# Vi sao phai co phep do nay: `check.py` chay headless nen khong ve gi ca
# (`tools/do_tron.gd:1-10`), ma cau hoi "man Main dung ra co giong khong" thi
# CHI diem anh tra loi duoc. Mot khac biet ve thuoc tinh — theme, thu tu layer,
# co san khau — co the khong doi mot diem anh nao, va nguoc lai.
#
# `--fixed-fps 30` o CA HAI luot la bat buoc: khong co no thi pha hoat hinh khac
# nhau giua hai lan chay va phep so vo nghia.
#
# Khung chup: khung thu 45 SAU khi chuoi khoi dong xong, dem y nhu
# `tools/vao_main.gd:_process` (`_dem == 45`) — luc ay ca hai duong da tick dung
# 45 vong Lua voi cung buoc thoi gian (`KHUNG = 1/30`), nen pha hoat hinh khop.
# Thu tu trong khung cung phai khop: `_lua.tick` xong roi moi dem, va CA HAI deu
# chup ngay trong `_process` chu khong doi `RenderingServer.frame_post_draw` —
# doi thi luot nay lay khung vua ve con luot kia lay khung truoc, lech mot khung
# hoat hinh.
extends Node

const DUONG_VAO := "res://ui/vao_game.tscn"

## Tran cho ca chuoi khoi dong. Do duoc **~5 giay** tren may ranh (7-15 giay khi
## chay nang may ao Android); de rong de may cham khong lam phep do that bai, ma
## neu ket that thi van bao ra.
const CHO_TOI_DA_MS := 180000

## So khung dem sau khi chuoi xong roi moi chup, khop `tools/vao_main.gd`.
const KHUNG_CHUP := 45

## Theme de chung nguoc: mau kem + vien den 5 px + co chu 15, dung ba thu ma
## `game/ui_theme.gd:87-90` doi. Dung khi `UiTheme.build()` tra null (repo nay
## CHUA xuat `assets_ref/ui/`, nen no luon tra null).
const MAU_THEME_GOC := Color(1, 0.97, 0.9)

## Sau bao nhieu tang thi thoi khi in cay. Tang 7 du de quy mot dai anh ve node
## nao, nhung KHONG du de thay xuong cua armature: mot rig nam o tang 6 thi cac
## sprite cua no o tang 8-9, tuc la dung ngoai tam. Ma "rig dung ra 0 sprite"
## voi "rig dung ra sprite roi an chung di" la hai benh khac han nhau — phai
## nhin duoc tan day moi phan biet duoc. Nen de nang bang `--sau=`.
var _sau := 7

var _man: Node = null
var _chup := ""
var _theme := ""
var _cay := ""
var _an := ""
## Chuoi con cua duong dan anh, vi du `--tim=lizi` hay `--tim=UITongYong`.
var _tim := ""
## Nhieu diem mot luot: `--diem=480,560;430,175`. Mot luot chay ton ~20 giay, nen
## hoi mot diem mot luot thi nam cau mat gan hai phut.
var _diem: Array[Vector2] = []
var _xong := false
var _dem := 0
var _t0 := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			_chup = a.substr(7)
		elif a.begins_with("--theme="):
			_theme = a.substr(8)
		elif a.begins_with("--cay="):
			_cay = a.substr(6)
		elif a.begins_with("--an="):
			_an = a.substr(5)
		elif a.begins_with("--tim="):
			_tim = a.substr(6)
		elif a.begins_with("--sau="):
			_sau = int(a.substr(6))
		elif a.begins_with("--diem="):
			for cap in a.substr(7).split(";"):
				var ph := cap.split(",")
				if ph.size() == 2:
					_diem.append(Vector2(float(ph[0]), float(ph[1])))
	if _chup == "" and _cay == "" and _diem.is_empty() and _tim == "":
		print("thieu --chup=<tep.png> (hoac --cay=<tep.txt>)")
		get_tree().quit(1)
		return
	_t0 = Time.get_ticks_msec()
	_man = (load(DUONG_VAO) as PackedScene).instantiate()
	add_child(_man)
	print("dung %s, cho chuoi Login -> Main... (theme do: '%s')"
			% [DUONG_VAO, _theme if _theme != "" else "(khong doi)"])


func _process(_dt: float) -> void:
	if _xong:
		return
	if not Game.da_vao:
		if Time.get_ticks_msec() - _t0 > CHO_TOI_DA_MS:
			print("HONG: chuoi khoi dong khong xong sau %d ms" % CHO_TOI_DA_MS)
			_xong = true
			get_tree().quit(1)
		return
	# Khung dau tien thay `da_vao`: `Game._process` da tick xong khung nay (autoload
	# nam TRUOC man hien tai trong cay), con khung dat co thi no chua kip tick —
	# nen tu day dem dung bang so vong tick.
	if _dem == 0:
		print("chuoi xong sau %d ms; dem %d khung roi chup"
				% [Time.get_ticks_msec() - _t0, KHUNG_CHUP])
		_in_cua_so()
		if _cay != "":
			_in_cay()
		if _an != "":
			_dat_an()
		for d in _diem:
			_tai_diem(d)
		if _tim != "":
			_tim_anh()
		if _theme != "":
			_dat_theme()
		if _chup == "":
			_xong = true
			get_tree().quit(0)
			return
	_dem += 1
	if _dem < KHUNG_CHUP:
		return
	_xong = true
	var img := get_viewport().get_texture().get_image()
	var e := img.save_png(_chup)
	print("chup %s -> %s (%dx%d)" % [_chup, "ok" if e == OK else "loi %d" % e,
			img.get_width(), img.get_height()])
	get_tree().quit(0 if e == OK else 1)


## In cung phep do ma `tools/vao_main.gd:71-80` in (`[DO TAM] win=...`). Co no
## thi moi quy duoc mot khac biet diem anh ve cua so hay ve bo cuc, chu khong
## phai doan.
func _in_cua_so() -> void:
	var s = Game.lua.run("""
		local w, h = g_CPublic:GetWinSize()
		local u = _G['UIRootLayer']
		local uw, uh = u:getContentSize()
		local m = _G['g_MainUIScrollLayer']
		local mw, mh = m:getContentSize()
		return string.format('win=%sx%s  UIRoot=%sx%s  fScale=%s  MainScroll=%sx%s',
			tostring(w), tostring(h), tostring(uw), tostring(uh),
			tostring(g_CSceneManager.fScale), tostring(mw), tostring(mh))
	""", "do cua so")
	print("  [DO TAM] %s" % str(s))
	print("  Window.size = %s   cua so Godot = %s" % [get_window().size, get_viewport().get_visible_rect().size])
	# San khau cua TA: co nao, ti le nao, dat o dau. Ba so nay cong voi `win=` o
	# tren la du de quy "mot node cua bo cuc goc ra bao nhieu diem anh".
	var san := Game.lop_lua.get_node_or_null("SanLua") as Control
	if san != null:
		print("  SanLua: size=%s scale=%s pos=%s  -> 1 don vi bo cuc = %.4f diem anh"
				% [san.size, san.scale, san.position, san.scale.x * (1.0 if san.size.x == 0 else 1.0)])


## In CAY node cua man Main ra tep: ten, cho, co, ti le, an/hien, do trong suot.
##
## Co no vi "cho nao ve ra cai gi" la cau hoi phai tra loi duoc bang DU LIEU chu
## khong bang mat. Mot dai anh sai mau co the do mot node dat SAI CO, hoac do mot
## node KHAC phu len — nhin anh khong phan biet duoc hai cai do, ma cach sua
## nguoc han nhau. Cung the voi ti le: ca canh trong to hon ban goc thi phai biet
## no to ra o node nao.
func _in_cay() -> void:
	var s = Game.lua.run(CAY_LUA.replace("__SAU__", str(_sau)), "in cay")
	if s == null:
		push_error("khong in duoc cay: " + ", ".join(Game.lua.errors))
		return
	var f := FileAccess.open(_cay, FileAccess.WRITE)
	if f == null:
		push_error("khong mo duoc %s" % _cay)
		return
	f.store_string(str(s))
	f.close()
	print("  in cay man Main -> %s (%d dong)" % [_cay, str(s).count("\n") + 1])


## Duyet tu `g_MainUIScene` xuong, sau `--sau=` tang thi thoi (mac dinh 7).
##
## KHONG dung `getLocalZOrder` — lop gia lap khong co ham ay (da grep). Dung ten
## `xgg_name` khi co, vi do moi la ten trong bo cuc goc.
##
## MOI phep doc deu phai boc `pcall`: `to_cocos` (`cocos.lua:174-181`) doc
## `gd.size`, ma xuong cua armature la `Node2D` — no KHONG co `size`, nen ca
## `getPosition()` lan `getContentSize()` deu nem loi. Bo do chet vi mot node
## khong co co thi khong do duoc gi.
const CAY_LUA := """
	local c = require('cocos')
	local goc = _G['g_MainUIScene']
	if goc == nil then return 'KHONG THAY g_MainUIScene' end
	local function thu(f, mac_dinh)
		local ok, a, b = pcall(f)
		if not ok then return mac_dinh, mac_dinh end
		return a or mac_dinh, b or mac_dinh
	end
	local out = {}
	local function di(n, sau)
		if sau > __SAU__ then return end
		local gd = c.raw(n)
		local ten = gd:get_name()
		if gd:has_meta('xgg_name') then ten = tostring(gd:get_meta('xgg_name')) end
		if gd:has_meta('cls') then ten = ten .. '<' .. tostring(gd:get_meta('cls')) .. '>' end
		local x, y = thu(function() return n:getPosition() end, 0)
		local w, h = thu(function() return n:getContentSize() end, 0)
		local sx, sy = thu(function() return n:getScaleX(), n:getScaleY() end, 0)
		local op = thu(function() return n:getOpacity() end, 255)
		-- `isVisible` KHONG co trong lop gia lap (da grep) — nen doc thang
		-- `visible` cua Godot. Doc thuoc tinh that chu khong doc qua lop gia lap,
		-- vi cau hoi dat ra la "node nay co duoc VE khong", va chi Godot tra loi
		-- duoc. `vis=` la co luc chay, `xgg=` la co ghi trong tep bo cuc: hai so
		-- nay LECH NHAU nghia la co gi do da doi no sau khi nap.
		out[#out + 1] = string.format(
			'%s%s %.0f,%.0f %.0fx%.0f sc=%.2f,%.2f vis=%s xgg=%s op=%.0f',
			string.rep('  ', sau), ten, x, y, w, h, sx, sy,
			tostring(gd.visible),
			tostring(gd:has_meta('xgg_visible') and gd:get_meta('xgg_visible')),
			op)
		local con = n:getChildren()
		for i = 1, #con do di(con[i], sau + 1) end
	end
	di(goc, 0)
	return table.concat(out, string.char(10))
"""


## In MOI node dang hien phu len mot diem anh, kem duong dan anh cua no.
##
## Co no vi day la cau hoi dat ra lien tuc khi anh sai mau — "cho nay ve ra cai
## gi?" — va tra loi no bang cach an tung nhom roi chup lai thi moi nhom mot luot
## chay ~20 giay, con so nhom thi khong biet truoc. Mot luot in ra het: node nao,
## o dau, anh nao, thu tu ve nao.
##
## Loc theo `visible` THAT va theo hinh bao THAT (`get_global_transform`), nen no
## tra loi dung cau hoi "diem anh nay do node nao ve" chu khong phai "node nao co
## toa do gan do". Diem tinh theo toa do CUA SO Godot, dung nhu anh chup.
func _tai_diem(diem: Vector2) -> void:
	var ds: Array[Node] = []
	var goc := Game.lop_lua.get_node_or_null("SanLua")
	if goc == null:
		push_error("khong thay san khau Lua")
		return
	_gom(goc, ds)
	var ra: Array = []
	for x in ds:
		if not x is CanvasItem or not (x as CanvasItem).is_visible_in_tree():
			continue
		var ci := x as CanvasItem
		var r := Rect2(Vector2.ZERO, ci.get_global_transform().origin * 0.0)
		if ci is Control:
			var c := ci as Control
			r = Rect2(Vector2.ZERO, c.size)
		elif ci is Sprite2D:
			var sp := ci as Sprite2D
			var t := sp.texture
			r = Rect2(-sp.offset, Vector2.ONE if t == null else t.get_size())
		else:
			continue
		var o := ci.get_global_transform() * r
		if not Rect2(o.position, o.size).has_point(diem):
			continue
		var ten := String(ci.get_meta("xgg_name", ci.get_meta("cls", ci.name)))
		var anh := ""
		for p in ["texture", "texture_normal", "texture_pressed"]:
			var t = ci.get(p)
			if t is Texture2D:
				anh = (t as Texture2D).resource_path
				break
		if anh == "":
			var ch: Node = ci
			for _i in 4:
				if ch == null:
					break
				for p in ["texture"]:
					var t = ch.get(p)
					if t is Texture2D:
						anh = "(cha) " + (t as Texture2D).resource_path
						break
				if anh != "":
					break
				ch = ch.get_parent()
		ra.append([ci, String(ci.name), ten, str(o), ci.z_index, anh])
	ra.sort_custom(func(a, b): return int(a[4]) > int(b[4]))
	print("  tai diem %s: %d node dang hien phu len" % [diem, ra.size()])
	for e in ra:
		print("    z=%-5s %-26s %-30s %s" % [e[4], String(e[2]).substr(0, 26),
				String(e[3]), e[5]])
		# Chuoi cha: mot node dat sai cho thi phai biet no thuoc RIG nao — ten no
		# la `@Sprite2D@2762` (Godot tu dat) nen tu no khong noi len duoc gi.
		var chuoi: Array = []
		var p: Node = e[0]
		while p != null and chuoi.size() < 7:
			chuoi.append(String(p.get_meta("xgg_name", p.get_meta("cls", p.name))))
			p = p.get_parent()
		print("           cha: %s" % " < ".join(chuoi))


## Dem va in moi node dang hien co ANH chua chuoi `--tim=`, kem o cua no.
##
## Khac `--diem` o cho no khong hoi "diem nay do node nao ve" ma hoi "anh nay
## duoc ve ra o NHUNG DAU". Cau hoi ay moi tra loi duoc "mot hieu ung nam dung
## cho hay rai khap man hinh" — ma do la khac biet giua "hieu ung hoi to" va
## "hieu ung dat sai toa do", hai cach sua nguoc han nhau.
##
## Loc theo `visible` THAT, nen node bi an khong lam nhieu so dem.
func _tim_anh() -> void:
	var goc := Game.lop_lua.get_node_or_null("SanLua")
	if goc == null:
		push_error("khong thay san khau Lua")
		return
	var ds: Array[Node] = []
	_gom(goc, ds)
	var ra: Array = []
	var an := 0
	for x in ds:
		if not x is CanvasItem:
			continue
		var ci := x as CanvasItem
		var t = ci.get("texture")
		if not t is Texture2D:
			continue
		var p := (t as Texture2D).resource_path
		if not p.contains(_tim):
			continue
		var hien := ci.is_visible_in_tree()
		if hien:
			an += 1
		var r := Rect2(Vector2.ZERO, Vector2.ONE)
		if ci is Control:
			r = Rect2(Vector2.ZERO, (ci as Control).size)
		elif ci is Sprite2D:
			r = Rect2(-(ci as Sprite2D).offset, (t as Texture2D).get_size())
		var o := ci.get_global_transform() * r
		ra.append([0 if hien else 1, str(o.position), str(o.size),
				String(ci.get_meta("xgg_name", ci.get_meta("cls", ci.name))), p,
				ci.visible, ci.modulate.a])
	# Node AN xep sau node HIEN, va in ca hai: "rig dung 0 sprite" khac han
	# "rig dung sprite roi an chung di" — hai benh, hai cach sua. Chi dem node
	# dang hien thi khong phan biet duoc, va lan truoc toi da ket luan sai tu do.
	print("  --tim=%s: %d node co anh do, trong do %d DANG HIEN" % [_tim, ra.size(), an])
	ra.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for e in ra.slice(0, 40):
		print("    %s %-22s %-22s %-24s a=%.2f %s" % ["H " if e[0] == 0 else "an",
				e[1], e[2], String(e[3]).substr(0, 24), e[5], e[4]])


## An moi node co ten (hoac ten lop) chua chuoi `--an=`. Tra ve so node da an.
##
## Co no de tra loi mot cau hoi bang PHEP DO chu khong bang mat: "dom trang kia
## la node nao". Nhin anh thi khong phan biet duoc "mot node to ve sai" voi "nhieu
## node nho ve de len nhau", ma hai cai do sua nguoc han nhau. An tung nhom roi
## chup lai: nhom nao lam dom bien mat thi dom la cua nhom do.
##
## An bang `visible = false` chu KHONG bang `setOpacity(0)`: `setVisible` khong co
## trong lop gia lap, va `visible` moi la co ma Godot dung de quyet dinh co ve hay
## khong — dung y nguyen phep kiem.
##
## Do theo BA cai ten, khong phai mot: ten THAT cua node trong bo cuc nam o meta
## `xgg_name` (`Godot` tu dat ten kieu `@Control@2761` cho node khong ten), con
## `name` chi la ten Godot. Do moi `name` thi `--an=UITongYong` khop **0 node**
## trong khi cay in ra dung chu `UITongYong` — da dinh, va do la loai im lang:
## phep do chay xong, anh khong doi, roi ket luan sai la "khong phai no".
func _dat_an() -> void:
	var goc := Game.lop_lua.get_node_or_null("SanLua")
	if goc == null:
		push_error("khong thay san khau Lua")
		return
	var ds: Array[Node] = []
	_gom(goc, ds)
	var n := 0
	for x in ds:
		# `CanvasItem` chu KHONG `Control`: xuong cua armature la `Node2D`, va
		# chung khong phai `Control` — loc theo `Control` thi `--an=UITongYong`
		# van khop 0 node lan thu hai. `CanvasItem` moi la lop co `visible`.
		if not x is CanvasItem:
			continue
		var ten := String(x.name)
		var xg := String(x.get_meta("xgg_name", ""))
		var cl := String(x.get_meta("cls", ""))
		if ten.contains(_an) or xg.contains(_an) or cl.contains(_an):
			(x as CanvasItem).visible = false
			n += 1
	print("  an '%s': %d node" % [_an, n])


func _gom(g: Node, ra: Array[Node]) -> void:
	ra.append(g)
	for c in g.get_children():
		_gom(c, ra)


## Dat theme de chung nguoc len CHINH SAN KHAU.
##
## KHONG dat len `root`: do duoc la `get_tree().root.theme = t` khong lan toi
## `Control` nao (gan roi cho tron mot khung, mau chu van khong doi), trong khi
## theme cua mot `Control` to tien thi lan ngay. Dat len root thi pheng chung
## nguoc ra **0 diem anh khac** va phep do trong nhu dat trong khi thuc ra no
## khong do duoc gi.
func _dat_theme() -> void:
	var san := Game.lop_lua.get_node_or_null("SanLua") as Control
	if san == null:
		push_error("khong thay san khau Lua de dat theme")
		return
	var th := UiTheme.build()
	if th != null:
		san.theme = th
		print("  dat theme GOC cua UiTheme len san khau")
		return
	var gia := Theme.new()
	gia.set_color("font_color", "Label", MAU_THEME_GOC)
	gia.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	gia.set_constant("outline_size", "Label", 5)
	gia.set_font_size("font_size", "Label", 15)
	san.theme = gia
	print("  UiTheme.build() = null (chua xuat assets_ref/ui/) -> dat theme TONG HOP")
