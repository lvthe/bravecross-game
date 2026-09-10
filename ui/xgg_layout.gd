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

const _DEBUG_COLORS := {
	"sprite": Color(0.90, 0.45, 0.25, 0.55),
	"scale9": Color(0.25, 0.55, 0.85, 0.55),
	"label": Color(0.35, 0.75, 0.45, 0.55),
	"layer": Color(1, 1, 1, 0.06),
}


## Loai node Godot suy tu ten lop Cocos.
##
## Quy uoc ten cua ban goc: sp* sprite, s9* scale-9, ttf* chu, l*/g_*/cl* lop.
## Ten lop Cocos that (CCSprite, CCScale9Sprite, CCLabelTTF) duoc uu tien vi
## no chinh xac hon tien to.
static func kind_of(cls: String) -> String:
	if cls.begins_with("CCScale9Sprite") or cls.begins_with("s9"):
		return "scale9"
	if cls.begins_with("CCSprite") or cls.begins_with("sp"):
		return "sprite"
	if cls.begins_with("CCLabel") or cls.begins_with("ttf") or cls.begins_with("sns"):
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

	var kind := kind_of(String(nd.get("cls", "")))
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
			node = Control.new()

	var nm := String(nd.get("name", ""))
	if nm == "":
		nm = String(nd.get("cls", "node"))
	node.set_meta("xgg_name", nm)      # giu nguyen ten goc, ke ca khi phai lam sach
	node.name = _safe_name(nm)
	node.size = Vector2(w, h)
	# Doi truc: xem chu thich dau file.
	node.position = Vector2(x - ax * w, parent_size.y - (y - ay * h) - h)
	node.rotation_degrees = -float(nd.get("rot", 0.0))   # Cocos quay nguoc chieu
	node.scale = Vector2(float(nd.get("scaleX", 1.0)), float(nd.get("scaleY", 1.0)))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_meta("cls", nd.get("cls", ""))
	node.set_meta("res", nd.get("res", ""))
	node.set_meta("kind", kind)
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
	if img != "" and (from == "verified" or (from == "guess" and use_guessed_images)):
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
	return node


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


## Toa do man hinh cua mot node, cong don qua ca duong tu goc xuong.
static func screen_rect(node: Control) -> Rect2:
	var pos := node.position
	var p := node.get_parent()
	while p is Control:
		pos += (p as Control).position
		p = p.get_parent()
	return Rect2(pos, node.size)
