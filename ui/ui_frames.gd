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
static var _alias: Dictionary = {}      ## ten tran -> khoa day du (khi khong trung)
static var _duoi: Dictionary = {}       ## ten tran -> [moi khoa cung ten]
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
		_alias = doc.get("alias", {})
		# Chi muc doi cu chi danh theo ten tran, khong co "alias". Van chay
		# duoc, chi la khong phan biet duoc cho trung ten.
		if _alias.is_empty():
			for k in _index:
				_alias[k] = k
		_duoi.clear()
		for k in _index:
			var b := String(k).get_file()
			if not _duoi.has(b):
				_duoi[b] = []
			_duoi[b].append(k)


## Ten trong bo cuc co the la 'v6/ui_words86.png', '@v6/ui_words86.png' hoac
## chi 'ui_words86'. Chi muc danh theo ten file khong duoi, nen quy ve dang do.
## Ten trong bo cuc co the la 'v6/ui_words86.png', '@v6/ui_words86.png' hoac
## chi 'ui_words86'. Tra ve KHOA day du trong chi muc, hoac "" neu khong co.
##
## PHAI dung ca phan thu muc khi bo cuc co ghi. Co 26 ten trung ma khac anh —
## `ui_background176` vua co ban `png/book/` (152x155) vua co ban
## `sngSplitData/v6/` (76x77). Truoc day rut ve ten tran nen lay nham ban to,
## va o thanh tuu phinh gap doi roi de len nhan ten ben canh.
static func key_of(name: String) -> String:
	_load_index()
	var s := name.lstrip("@")
	if s.ends_with(".png") or s.ends_with(".jpg"):
		s = s.get_basename()
	if _index.has(s):
		return s
	var base := s.get_file()
	# Bo cuc ghi ca thu muc: tim khoa nao ket thuc dung bang duong dan do.
	if s != base:
		for k in _duoi.get(base, []):
			if String(k).ends_with("/" + s) or String(k) == s:
				return k
	# Ten tran, khong trung: tra bang bi danh.
	if _alias.has(base):
		return _alias[base]
	# Ten tran nhung TRUNG (536 ten). Chon theo hai buoc:
	#
	#  1. Uu tien sngSplitData/. Do la khong gian ten cua CHINH
	#     S_CCSpriteFrameCache: anh giao dien khong nam trong atlas, moi anh la
	#     mot file .pkm rieng trong sngSplitData/, va ten file trung khit ten
	#     trong section C cua .xgg (xem uiart.py). Con png/ la anh roi, chi
	#     duoc goi bang DUONG DAN DAY DU qua initWithFile — ma duong dan day du
	#     thi da khop o nhanh tren roi. Nen mot cai ten TRAN thi gan nhu chac
	#     chan la mot khung trong sngSplitData.
	#
	#  2. Trong sngSplitData, lay ban NONG NHAT. Thu muc con (v6/,
	#     background/OneThanOne_v6/...) duoc bo cuc goi kem duong dan
	#     ('v6/ui_background176.png'), nen ten tran chi con tro ve goc.
	#
	# Do duoc: item_4 co hai ban — png/item/ (228x179) va sngSplitData/
	# (79x79). O phan thuong cua man thanh tuu la 79x79 giong moi icon khac,
	# ma truoc day ta lay ban 228x179 nen no phinh ra de len ca dong.
	var ds: Array = _duoi.get(base, [])
	if ds.is_empty():
		return ""
	if ds.size() == 1:
		return ds[0]
	var khung := []
	for k in ds:
		if String(k).begins_with("sngSplitData/"):
			khung.append(k)
	if khung.is_empty():
		_mo_ho[base] = ds.size()
		return ds[0]
	var tot: String = khung[0]
	for k in khung:
		if String(k).count("/") < tot.count("/"):
			tot = k
	if khung.size() > 1:
		var nong := 0
		for k in khung:
			if String(k).count("/") == tot.count("/"):
				nong += 1
		if nong > 1:
			_mo_ho[base] = khung.size()
	return tot


## Ten tra ra nhieu ban ma bo cuc khong ghi ro duong dan. Dung de biet cho nao
## con co the dang hien nham anh.
static var _mo_ho: Dictionary = {}

## Ten tran nay co nhieu ban trong chi muc khong.
static func is_ambiguous(name: String) -> bool:
	_load_index()
	var s := name.lstrip("@")
	if s.ends_with(".png") or s.ends_with(".jpg"):
		s = s.get_basename()
	return Array(_duoi.get(s.get_file(), [])).size() > 1


static func ambiguous() -> Dictionary:
	return _mo_ho


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
	# Thanh tien do (CCProgressTimer) la NGOAI LE cua luat "anh quyet dinh o":
	# o cua no lay theo ban ghi (do duoc: getContentSize() cua ban goc tra ve
	# 178 cho node 178x28), con anh cua ho thanh nao cung lech vai diem so voi
	# o (ui_blood_23.png 362x14 cho o 360x15). Lay anh lam o thi thanh ngan di
	# dung vai diem anh do — va voi o 77x13 ma anh 13x13 thi ngan di 64 diem.
	# Xem ui/tien_do.gd.
	if node is TienDo:
		(node as TienDo).anh = tex
		(node as TienDo).queue_redraw()
		return true
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
