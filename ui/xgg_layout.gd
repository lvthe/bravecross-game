## Dung cay Control tu bo cuc man hinh cua ban goc.
##
## Doc JSON do `brave-cross/work/layout.py` xuat ra tu file .xgg. Nho vay bo
## cuc KHONG phai uom tay theo anh chup: toa do, kich thuoc, diem neo va quan
## he cha-con deu lay dung so cua ban goc.
##
##   var ui := XggLayout.build("res://layout_ref/Game_UI_Control_Panel_960_640.json")
##   add_child(ui)
##   var btn := XggLayout.find_node(ui, "g_btnAutoCombat")
##
## DOI HE TOA DO. Cocos2d va Godot nguoc nhau o hai diem, sai mot trong hai la
## lech het:
##
##   1. Cocos goc DUOI-TRAI, y huong LEN;  Godot goc TREN-TRAI, y huong XUONG
##   2. Cocos x,y la vi tri DIEM NEO;      Godot position la goc TREN-TRAI
##
## Voi node co kich thuoc (w,h), neo (ax,ay), toa do (x,y) trong cha cao ph:
##
##   goc trai   = x - ax*w
##   canh tren  = y - ay*h + h        (do tu day cha len)
##   Godot y    = ph - canh tren
class_name XggLayout
extends RefCounted

## Kich thuoc thiet ke cua ban goc. Moi toa do trong JSON deu theo khung nay.
const DESIGN := Vector2(960, 640)

## Ve o mau thay cho anh chua nap duoc. Bat len de soi bo cuc.
static var debug_boxes := false

## Dung ca nhung ten anh CHUA tu kiem chung duoc.
##
## Truong chua ten anh trong ban ghi node moi chi do bang thong ke chu chua
## doc tu libgame.so, nen ten nao khong doi chieu duoc voi section C thi coi
## la phong doan. Tren 296 man: 11631 ten xac minh duoc, 360 phong doan.
## Mac dinh bo qua 360 cai do — hien thieu anh con hon hien nham anh.
static var use_guessed_images := false

## Nghe theo co hien/an cua ban goc. MAC DINH CO.
##
## File HUD chua 20 LOP TRANG THAI khac nhau chong len nhau: lUITopLayer la
## HUD trong tran that (314 node), con lHeroPKBattleUI, lArenaFight,
## lContestFight, clBattlePause... la UI cua cac che do khac, deu an san.
## Tat co nay di thi ca 20 lop cung ve mot luc — man hinh thanh mot dong mat
## tuong khong lo chong nhau. Da thu va dung nhu vay.
static var respect_visible := true

const _DEBUG_COLORS := {
	"sprite": Color(0.90, 0.45, 0.25, 0.55),
	"scale9": Color(0.25, 0.55, 0.85, 0.55),
	"label": Color(0.35, 0.75, 0.45, 0.55),
	"layer": Color(1, 1, 1, 0.06),
}


## Loai node Godot suy tu ten lop Cocos.
##
## Quy uoc ten cua ban goc: sp* sprite, s9* scale-9, ttf* chu, bmf* chu phong
## bitmap (CCLabelBMFont), l*/g_*/cl* lop. Ten lop Cocos that (CCSprite,
## CCScale9Sprite, CCLabelTTF) duoc uu tien vi no chinh xac hon tien to.
## Loai node THAT, doc tu bang kieu trong libgame.so (xem xgg.py). Truoc day
## ham nay doan theo tien to cua ten lop — ma ten lop la do nguoi thiet ke dat,
## nen doan sai la thuong: mot node ten "CCSprite" co the that ra la CCButton.
const KIND_OF_TYPE := {
	"CCScale9Sprite": "scale9",
	"CCSprite": "sprite",
	"CCLabelTTF": "label",
	"CCLabelBMFont": "label",
	"CCRichLabel": "label",
	"CCEditBox": "label",
}


static func kind_of_type(type_name: String) -> String:
	return KIND_OF_TYPE.get(type_name, "layer")


## Doan theo TEN. Chi con dung khi bo cuc cu chua co truong typeName.
static func kind_of(cls: String) -> String:
	if cls.begins_with("CCScale9Sprite") or cls.begins_with("s9"):
		return "scale9"
	if cls.begins_with("CCSprite") or cls.begins_with("sp"):
		return "sprite"
	if cls.begins_with("CCLabel") or cls.begins_with("ttf") or cls.begins_with("sns"):
		return "label"
	# bmf = CCLabelBMFont. Bo sot tien to nay thi nhung o so nhu ten do, cap,
	# chi so chinh ra Control tron va khong hien duoc chu nao.
	if cls.begins_with("bmf"):
		return "label"
	return "layer"


## Ky tu Godot cam trong ten node. Ban goc dat ten kha thoai mai — mot so
## "ten" that ra la chu hien thi: "0/3", "可领取:", "Lv.90", "+30%". Doi chung
## sang '_' de Godot nhan, ten goc van giu o meta "xgg_name".
const _BAD_NAME_CHARS := [".", ":", "@", "/", "\"", "%", "$"]


static func _safe_name(s: String) -> String:
	var out := s
	for c in _BAD_NAME_CHARS:
		out = out.replace(c, "_")
	out = out.strip_edges()
	return out if out != "" else "node"


static func build(json_path: String) -> Control:
	var txt := FileAccess.get_file_as_string(json_path)
	if txt.is_empty():
		push_error("XggLayout: khong doc duoc " + json_path)
		return null
	var doc = JSON.parse_string(txt)
	if not doc is Dictionary or not doc.has("roots"):
		push_error("XggLayout: %s khong phai file bo cuc" % json_path)
		return null

	var design := DESIGN
	if doc.has("design"):
		design = Vector2(float(doc["design"].get("w", 960)),
				float(doc["design"].get("h", 640)))

	var root := Control.new()
	root.name = "XggLayout"
	root.size = design
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in doc["roots"]:
		var n := _make(r, design)
		if n != null:
			root.add_child(n)
	sap_xep_theo_z(root)
	var idx := {}
	_index(root, idx)
	root.set_meta("index", idx)
	root.set_meta("source", json_path)
	return root


static func _make(nd: Dictionary, parent_size: Vector2) -> Control:
	var w := float(nd.get("w", 0.0))
	var h := float(nd.get("h", 0.0))
	var ax := float(nd.get("anchorX", 0.0))
	var ay := float(nd.get("anchorY", 0.0))
	var x := float(nd.get("x", 0.0))
	var y := float(nd.get("y", 0.0))

	var tn := String(nd.get("typeName", ""))
	var kind := kind_of_type(tn) if tn != "" else kind_of(String(nd.get("cls", "")))
	# Node nao co ANH thi phai la node ve duoc, du ten lop khong noi len dieu
	# do: CCButton, btnBattleTest... deu mang anh nhung kind_of() xep vao
	# 'layer'. Khong doi thi set_frame() tu choi va anh bien mat lang le.
	if kind == "layer" and String(nd.get("img", "")) != "":
		kind = "sprite"
	var node: Control
	match kind:
		"label":
			var lb := Label.new()
			lb.text = String(nd.get("res", ""))
			node = lb
		"scale9":
			var np := NinePatchRect.new()
			np.draw_center = true
			node = np
		"sprite":
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			node = tr
		_:
			# CCLayerColorRoundRect co MAU rieng (bon byte R,G,B,A trong ban
			# ghi). Phan lon la A=0 nen khong ve gi — nhung may lop CHE thi
			# song nho no: ma goc bat lop che len roi cho S_CCFadeTo dua do mo
			# tu 0 len 179. Khong co mau thi lop che chi la mot Control rong,
			# va man hinh phia sau khong bao gio toi di.
			if nd.has("color"):
				var cr := ColorRect.new()
				var c: Array = nd["color"]
				cr.color = Color8(int(c[0]), int(c[1]), int(c[2]),
						int(nd.get("opacity", 255)))
				node = cr
			else:
				node = Control.new()

	# TEN INSTANCE va TEN LOP la hai thu khac nhau, va chi cai dau moi la cai
	# ma goc goi toi. 30.694/33.472 node khong co ten instance; truoc day ta lay
	# ten lop thay vao va dat luon vao xgg_name, thanh ra 30.694 cai ten gia
	# tron lan voi 2.778 ten that. Ten that thi khong bao gio trung nhau, con
	# ten gia thi co: mot node khong ten mang lop 'lSubDialogMask' nam trong
	# lDebugBoxMask da de len chinh lSubDialogMask that trong bang tra cuu.
	# Ten lop van dung lam TEN NODE cua Godot cho de doc cay.
	var ten_that := String(nd.get("name", ""))
	var nm := ten_that if ten_that != "" else String(nd.get("cls", "node"))
	if ten_that != "":
		node.set_meta("xgg_name", ten_that)   # giu nguyen, ke ca khi phai lam sach
	node.name = _safe_name(nm)
	node.size = Vector2(w, h)
	# Doi truc: xem chu thich dau file.
	node.position = Vector2(x - ax * w, parent_size.y - (y - ay * h) - h)
	# Tam phong to / xoay. Cocos giu DIEM NEO dung yen khi phong to hay xoay;
	# Godot lam quanh pivot_offset, mac dinh la goc tren-trai. Co 5.841 node
	# vua co phong/xoay khac mac dinh vua co neo khac 0 — bay nhieu cho se ve
	# lech neu bo qua. Truc y nguoc nhau nen phai lat.
	node.pivot_offset = Vector2(ax * w, (1.0 - ay) * h)
	node.rotation_degrees = -float(nd.get("rot", 0.0))   # Cocos quay nguoc chieu
	node.scale = Vector2(float(nd.get("scaleX", 1.0)), float(nd.get("scaleY", 1.0)))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Co hien/an cua ban goc. An san la BINH THUONG o day: ban goc an gan het
	# roi de Lua bat len khi can — tren HUD man tran chi 10/629 node hien san.
	# Ta chua port phan Lua do, nen mac dinh HIEN HET de con nhin thay khung;
	# bat respect_visible khi da co logic bat/tat that su.
	node.set_meta("xgg_visible", bool(nd.get("visible", true)))
	if respect_visible and not bool(nd.get("visible", true)):
		node.visible = false
	node.set_meta("cls", nd.get("cls", ""))
	# TAG THAT, do tu chinh engine ban goc chu khong doc tu file: tag khong
	# nam trong .xgg, engine sinh ra luc nap. Xem work/emu_tags.py va
	# work/emu_join.py. Node nao engine khong tra ve thi khong co tag —
	# getChildByTag chi tra ve node DAU TIEN mang tag do, nen anh em trung
	# tag thi nhung cai sau bi khuat, va ma goc cung khong voi toi chung.
	if nd.has("tag"):
		node.set_meta("tag", int(nd["tag"]))
	# zOrder cua Cocos: quyet dinh THU TU VE. Godot ve anh em theo thu tu cay
	# va chi cho z_index trong khoang +-4096, ma ban goc dung toi 9000, nen ta
	# XEP LAI anh em thay vi dat z_index. Xem sap_xep_theo_z().
	node.set_meta("zorder", int(nd.get("zOrder", 0)))
	node.set_meta("res", nd.get("res", ""))
	node.set_meta("kind", kind)
	node.set_meta("type_name", tn)
	# Giu nguyen toa do Cocos de set_frame() tinh lai duoc vi tri khi anh moi
	# co kich thuoc khac — ban goc doi anh thi giu DIEM NEO, khong giu goc o.
	node.set_meta("cocos", Vector4(x, y, ax, ay))
	node.set_meta("parent_h", parent_size.y)

	# Gan anh neu bo cuc co ghi. 'verified' = ten tu kiem chung duoc bang
	# section C cua chinh man do (co trong danh sach anh VA dung kich thuoc);
	# 'guess' = giai ra chuoi hop le nhung khong tu kiem chung duoc, nen mac
	# dinh KHONG dung — bat bang use_guessed_images neu muon xem thu.
	var img := String(nd.get("img", ""))
	var from := String(nd.get("imgFrom", ""))
	# "size" = khop voi danh sach ANH ROI cua chinh man do theo kich thuoc,
	# va chi nhan khi khop DUY NHAT. Day la cach duy nhat lay duoc may tam
	# nen to: chung khong ghi ten anh trong ban ghi node.
	if img != "" and (from == "verified" or from == "size"
			or (from == "guess" and use_guessed_images)):
		node.set_meta("img", img)
		node.set_meta("img_from", from)
		if UiFrames.set_frame(node, img):
			node.set_meta("img_applied", true)

	if debug_boxes and w > 0.0 and h > 0.0:
		var box := ColorRect.new()
		box.name = "_debug"
		box.color = _DEBUG_COLORS.get(kind, Color(1, 0, 1, 0.4))
		box.size = Vector2(w, h)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(box)

	for c in nd.get("children", []):
		var child := _make(c, Vector2(w, h))
		if child != null:
			node.add_child(child)
	sap_xep_theo_z(node)
	return node


## Xep lai con theo zOrder cua Cocos, GIU NGUYEN thu tu goc khi bang nhau
## (Cocos cung vay: cung zOrder thi ai vao truoc ve truoc).
##
## Phai xep chu khong dat z_index: ban goc dung toi zOrder 9000
## (lDebugBoxMask), con Godot chi nhan z_index trong khoang +-4096.
static func sap_xep_theo_z(cha: Node) -> void:
	var ds := []
	var i := 0
	for c in cha.get_children():
		ds.append([int(c.get_meta("zorder", 0)), i, c])
		i += 1
	var da_sap := ds.duplicate()
	da_sap.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	var doi := false
	for j in range(da_sap.size()):
		if da_sap[j][2] != ds[j][2]:
			doi = true
			break
	if not doi:
		return
	for j in range(da_sap.size()):
		cha.move_child(da_sap[j][2], j)


## Dua mot man hinh vao trong khung chung cua hop thoai.
##
## Ban goc khong co "hai bo cuc roi nhau": moi thu nam chung mot cay, va zOrder
## sap xep chung. UI_NormalDlg_960_640 giu lop che (z=20), thanh nut Back
## (z=60) va nen canh; man hinh cu the (vi du lAchieveTaskUI, z=33) la MOT
## NGUOI ANH EM nam giua hai cai do. De roi hai cay thi nut Back bi nen phu,
## va lop che nam sai phia.
##
## Chuyen cac goc cua `man` vao `vao_trong` (mac dinh UIRootLayer cua khung),
## roi xep lai theo zOrder. Tra ve so goc da chuyen.
static func ghep_vao(khung: Node, man: Node, vao_trong: String = "UIRootLayer") -> int:
	var cha := find_node(khung, vao_trong)
	if cha == null:
		push_error("XggLayout: khong thay %s trong khung" % vao_trong)
		return 0
	# Dua lop chua ve goc toa do. Trong file, UIRootLayer nam o (31,6 / 64,2) —
	# do la cho nguoi thiet ke ke no trong trinh sua. Game chay khong the dat no
	# o do, va chinh noi dung cua no chung minh: may lop che ben trong deu la
	# 1366x768 dat tai (-203, -64), tuc la thua deu moi ben cua khung 960x640
	# ((1366-960)/2 = 203, (768-640)/2 = 64). Canh deu nhu vay chi dung khi lop
	# chua nam dung goc. De nguyen thi ca giao dien — ke ca nut Back — bi day
	# len khoi mep tren.
	if cha is Control:
		(cha as Control).position = Vector2.ZERO
	var n := ghep_vao_node(cha, man)
	# Gop bang tra cuu, de find_node tren khung tim duoc ca node cua man.
	if khung.has_meta("index") and man.has_meta("index"):
		var idx: Dictionary = khung.get_meta("index")
		for k in man.get_meta("index"):
			idx[k] = man.get_meta("index")[k]
	return n


## Chuyen cac goc cua `man` vao thang node `cha`, roi xep lai theo zOrder.
##
## Day la viec ma loadLevelFile(file, parentNode) cua ban goc lam: nap mot .xgg
## vao duoi mot node co san. Tra ve so goc da chuyen.
static func ghep_vao_node(cha: Node, man: Node) -> int:
	var n := 0
	for c in man.get_children().duplicate():
		man.remove_child(c)
		cha.add_child(c)
		n += 1
	sap_xep_theo_z(cha)
	return n


## Tim node theo ten instance, di sau xuong ca cay.
## Tim theo ten GOC truoc (meta "xgg_name"), roi moi den ten da lam sach — de
## tra cuu bang dung cai ten nhin thay trong file .xgg.
##
## Dung bang chi muc gan o root neu co (build() luon gan), khong thi duyet cay.
static func find_node(root: Node, wanted: String) -> Control:
	if root.has_meta("index"):
		var idx: Dictionary = root.get_meta("index")
		if idx.has(wanted):
			var n = idx[wanted]
			if is_instance_valid(n):
				return n
	if root is Control and (String(root.get_meta("xgg_name", "")) == wanted
			or root.name == wanted):
		return root
	for c in root.get_children():
		var hit := find_node(c, wanted)
		if hit != null:
			return hit
	return null


## Bang ten -> node, dung y cach ban goc lam.
##
## Engine goc nap .xgg xong thi BOM moi node vao bang toan cuc _G theo ten
## instance — xem CUIPublic:GetRootUI(), no chi lam `_G[self.RootUIName]`.
## Nho vay ma Lua goi thang `g_btnAutoCombat:setVisible(...)`. O day khong bom
## vao khong gian toan cuc (de tranh dam nhau giua cac man), ma gan bang chi
## muc len chinh node goc.
static func index_of(root: Node) -> Dictionary:
	return root.get_meta("index", {})


static func _index(node: Node, into: Dictionary) -> void:
	if node is Control and node.has_meta("xgg_name"):
		var nm := String(node.get_meta("xgg_name"))
		# Trung ten thi cai SAU ghi de cai truoc, dung nhu `_G[ten] = node`
		# ben Lua. Rat nhieu node trung ten (CCSprite, ttfContent, Board...)
		# nen so ten it hon han so node — 207 ten tren 629 node o HUD man tran.
		# Nhung ten ma Lua thuc su goi den (g_btnAutoCombat, spBattleStartTime)
		# thi deu la duy nhat.
		if nm != "":
			into[nm] = node
	for c in node.get_children():
		_index(c, into)


## Tim node theo TEN LOP Cocos (meta "cls").
##
## Nhieu nhan trong bo cuc goc khong co ten instance — nguoi lam UI dat ten
## LOP thanh chu tieng Trung mo ta cho do ("当前-主属性", "强化消耗"). Do la
## cach duy nhat tro toi chung ma khong phai dem chi so con, thu se vo nghia
## ngay khi bo cuc doi mot node.
static func find_by_cls(root: Node, cls: String) -> Control:
	if root is Control and String(root.get_meta("cls", "")) == cls:
		return root
	for c in root.get_children():
		var hit := find_by_cls(c, cls)
		if hit != null:
			return hit
	return null


## Hien mot node va MOI CAP CHA cua no, tinh den `stop`.
##
## Ban goc an gan het roi de Lua bat len dung cai can. Bat mot node ma quen
## cha thi no van khong hien — da dinh dung the.
static func show_branch(node: Control, stop: Node = null) -> void:
	var n: Node = node
	while n != null and n != stop:
		if n is Control:
			(n as Control).visible = true
		n = n.get_parent()


## Toa do man hinh cua mot node, cong don qua ca duong tu goc xuong.
static func screen_rect(node: Control) -> Rect2:
	var pos := node.position
	var p := node.get_parent()
	while p is Control:
		pos += (p as Control).position
		p = p.get_parent()
	return Rect2(pos, node.size)
