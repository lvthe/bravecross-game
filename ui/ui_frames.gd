## Tra anh giao dien theo TEN, y het S_CCSpriteFrameCache cua ban goc.
##
## Ban goc gan anh luc chay chu khong luu san trong file bo cuc:
##
##     spIcon:setDisplayFrame(S_CCSpriteFrameCache:spriteFrameByName(szIconName))
##
## Ten thuong duoc tinh tai cho ("battle_medicine0"..i..".png"), nen khong co
## bang tinh node->anh de trich. Cach duy nhat dung la dung lai chinh co che
## tra theo ten do — day la no.
##
##     UiFrames.set_frame(node, "item_55.png")
##     var tex := UiFrames.get_frame("v6/ui_background204.png")
class_name UiFrames
extends RefCounted

const INDEX_PATH := "res://ui_ref/index.json"
const ART_DIR := "res://ui_ref/"

static var _index: Dictionary = {}
static var _cache: Dictionary = {}
static var _loaded := false
static var _misses: Dictionary = {}


static func _load_index() -> void:
	if _loaded:
		return
	_loaded = true
	var txt := FileAccess.get_file_as_string(INDEX_PATH)
	if txt.is_empty():
		push_warning("UiFrames: chua co %s — sinh bang: "
				% INDEX_PATH
				+ "python ../brave-cross/work/uiart.py --out ui_ref")
		return
	var doc = JSON.parse_string(txt)
	if doc is Dictionary and doc.has("frames"):
		_index = doc["frames"]


## Ten trong bo cuc co the la 'v6/ui_words86.png', '@v6/ui_words86.png' hoac
## chi 'ui_words86'. Chi muc danh theo ten file khong duoi, nen quy ve dang do.
static func key_of(name: String) -> String:
	var s := name.lstrip("@")
	var slash := s.rfind("/")
	if slash >= 0:
		s = s.substr(slash + 1)
	if s.ends_with(".png") or s.ends_with(".jpg"):
		s = s.get_basename()
	return s


static func has_frame(name: String) -> bool:
	_load_index()
	return _index.has(key_of(name))


static func get_frame(name: String) -> Texture2D:
	_load_index()
	var k := key_of(name)
	if _cache.has(k):
		return _cache[k]
	if not _index.has(k):
		_misses[k] = true
		return null
	var path: String = ART_DIR + String(_index[k].get("png", ""))
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is Texture2D:
			tex = res
	if tex == null:
		# Chua qua buoc import cua Godot (hoac nam ngoai res://) — doc thang.
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_cache[k] = tex
	else:
		_misses[k] = true
	return tex


## Gan anh cho node, tuong duong setDisplayFrame cua Cocos.
##
## Cocos doi anh thi GIU DIEM NEO chu khong giu goc o: sprite 96x96 neo giua
## thay bang anh 120x120 se no deu ra bon phia. Node giu lai toa do Cocos o
## meta "cocos" nen tinh lai duoc; khong co meta thi giu nguyen o cu.
static func set_frame(node: Control, name: String) -> bool:
	var tex := get_frame(name)
	if tex == null:
		return false
	if node is NinePatchRect:
		(node as NinePatchRect).texture = tex
	elif node is TextureRect:
		(node as TextureRect).texture = tex
	else:
		return false

	var size := tex.get_size()
	node.size = size
	if node.has_meta("cocos") and node.has_meta("parent_h"):
		var c: Vector4 = node.get_meta("cocos")     # x, y, anchorX, anchorY
		var ph: float = node.get_meta("parent_h")
		node.position = Vector2(c.x - c.z * size.x,
				ph - (c.y - c.w * size.y) - size.y)
	return true


## Ten da yeu cau ma khong co anh. Dung de biet con thieu gi, thay vi im lang.
static func missing() -> Array:
	var out := _misses.keys()
	out.sort()
	return out


static func stats() -> Dictionary:
	_load_index()
	return {"indexed": _index.size(), "cached": _cache.size(),
			"missing": _misses.size()}
