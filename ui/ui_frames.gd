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


## Quy duong dan trong bo cuc ve dang goc tai nguyen.
##
## Bo cuc nam trong `conf/`, nen duong dan no ghi tinh tu DO: `../png/scene/...`
## nghia la `png/scene/...` (goc tai nguyen). Chi muc `ui_ref/index.json` danh
## theo goc tai nguyen. Hai goc khac nhau, nen phai quy ve mot.
##
## Bo `..` khi khong con doan nao de huy: do la `..` vuot qua goc, va goc tai
## nguyen khong co cap tren — bo di moi dung. `../other/` (anh em voi `conf/`)
## cung nho vay ma thanh `other/`, dung.
static func _chuan_hoa(s: String) -> String:
	var ra: Array = []
	for ph in s.split("/", false):
		if ph == ".":
			continue
		if ph == "..":
			if not ra.is_empty():
				ra.remove_at(ra.size() - 1)
			continue
		ra.append(ph)
	return "/".join(ra)


## Ten trong bo cuc co the la 'v6/ui_words86.png', '@v6/ui_words86.png' hoac
## chi 'ui_words86'. Chi muc danh theo ten file khong duoi, nen quy ve dang do.
## Tra ve KHOA day du trong chi muc, hoac "" neu khong co.
##
## PHAI dung ca phan thu muc khi bo cuc co ghi. Co 26 ten trung ma khac anh —
## `ui_background176` vua co ban `png/book/` (152x155) vua co ban
## `sngSplitData/v6/` (76x77). Truoc day rut ve ten tran nen lay nham ban to,
## va o thanh tuu phinh gap doi roi de len nhan ten ben canh.
##
## PHAI chuan hoa `../` TRUOC khi khop thu muc, khong thi phep khop truot va
## roi xuong buoc "ten tran trung" — ma buoc do CHON BUA. Do duoc: bon anh mat
## dat cua man Main (`../png/scene/mainscene/mainscene_ground_{a,b,-aa,-bb}.png`)
## deu truot kieu ay va lay het ban `png/scene/christmas/...`, nen mat dat man
## Main ra mau TUYET trang thay vi co xanh. Cung bon ten do co dung hai ban
## (mainscene va christmas) nen khong co gi phan biet ngoai duong dan.
## Hau to NGON NGU cua ten anh danh dau bang `@` trong .xgg.
##
## `@` KHONG phai ky tu rac phai bo di: no danh dau ten ANH THEO NGON NGU. Do
## tren ca 296 bo cuc (`layout_ref/*.json`): **562 node** mang ten co `@` (145
## ten khac nhau, 130 bo cuc), va **482 node / 128 ten CHI ra anh khi them hau
## to nay** — duong cu bo `@` roi tra thang ten goc, nen 482 node ay khong co
## anh nao. Hai vi du nhin thay duoc: `CanUpgrade` tag#55 va `CanUnlock` tag#54
## cua man Doanh Trai (`CUIBarracksMain.lua:1073-1074`, anh `@v6/ui_words93/94.png`).
## Them 72 node nua ra CA HAI duong, va o do duong `_vi` moi dung theo duong dan
## bo cuc ghi (`@v6/ui_background214.png` ra `sngSplitData/v6/ui_background214_vi`
## thay vi `sngSplitData/ui_background214` — bo cuc da ghi ro thu muc `v6/`).
##
## Con **8 node khong ra duong nao** du them hau to hay khong
## (`@words/ui_words850.png`, `@ui_words853/854/855.png` — thieu tai nguyen that,
## khong phai loi tra cuu), nen PHAI giu buoc LUI ve ten goc: 2 node
## (`@v6/ui_background941/942.png`) chi ra duoc khi KHONG them hau to.
##
## Nguon SU THAT cua gia tri nay la `DEFAULT_LANGUAGE = 'vi'`
## (`lua/bootstrap.lua:317`, doc ra qua `GetLanguageName()`), khong phai mot lua
## chon cua ban dung — `tools/verify_lua_actions.gd` (khoi `@`) doc gia tri ay TU
## `res://lua/bootstrap.lua` roi doi chieu voi hang so nay, de hai ben khong lech
## nhau trong im lang.
const HAU_TO_NGON_NGU := "_vi"


## Chen hau to ngon ngu truoc PHAN MO RONG, khong phai vao cuoi chuoi.
##
## `@v6/ui_words86.png` phai ra `@v6/ui_words86_vi.png`; noi vao cuoi chuoi thi
## ra `@v6/ui_words86.png_vi` va phep tra truot — do dung mot lan thi tuong `_vi`
## khong cuu duoc ten nao (0/145 thay vi 128/145).
static func _them_hau_to(name: String) -> String:
	var goc := name.get_basename()
	return goc + HAU_TO_NGON_NGU + name.substr(goc.length())


## Tra anh theo ten, co tinh hau to ngon ngu cho ten bat dau bang `@`.
static func key_of(name: String) -> String:
	if name.begins_with("@"):
		var k := _tra(_them_hau_to(name))
		if k != "":
			return k
	return _tra(name)


## Cac luat tra cuu, KHONG tinh hau to ngon ngu — xem `key_of`.
static func _tra(name: String) -> String:
	_load_index()
	var s := _chuan_hoa(name.lstrip("@"))
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
	# NHAN co anh nen (CCLabelTTF mang CA `img` LAN `text`). 202 nhan trong 11 bo
	# cuc lam the, nhieu nhat la `buildingname_16.png` (28 nhan = ten toa nha
	# trong thanh) va `ui_background018.png` (150 nhan). Anh nen la TAM VANG
	# 144x34 dung bang o cua ban ghi — no la cai khung vang nhin thay trong man
	# goc, khong phai trang tri phu.
	#
	# Dat bang o theme `normal` cua Label chu KHONG boc them node cha: `Label`
	# ve o `normal` ngay duoi chu cua chinh no, nen thu tu ve dung san; va node
	# van la `Label` — `ui/equip.gd` quet `c is Label` tren cay nen boc lai la
	# vo het cho do.
	#
	# KHONG dat o theo anh nhu duong chung ben duoi: o cua nhan la o CHU (ban ghi
	# ghi w/h), anh nen chi duoc keo gian cho vua o do. Lay anh lam o thi nhan
	# nao co anh nen khac co lai.
	#
	# Tam la mot DAI, va vien vang cua no chay DOC THEO TRUC DAI. Nen keo truc
	# DAI thi vien khong hong (chi dai ra), con keo truc NGAN thi bop vien. Vay
	# luat la: CANH NGAN cua tam phai khop canh ngan cua o; canh dai duoc keo.
	#
	# Do duoc ba ca, va ca ba deu dung luat nay:
	#   `buildingname_16` 144x34 vao o 166x34  -> nhan (rong ra 22 diem)
	#   `v6/ui_background018` 50x30 vao o 79x30 -> nhan
	#   `v6/ui_background112` 214x366 vao o 30x30 -> LOAI (canh ngan 214 vs 30)
	# Ca cuoi la that: ten ay co HAI ban trong kho, ban `png/background/` 214x366
	# va ban `sngSplitData/v6/` 30x30 — xem chu thich `key_of`. Keo 214x366 vao o
	# 30x30 thi ra mot mang o vuong vo, dung cai nhin thay tren man doanh trai.
	if node is Label:
		var t := tex.get_size()
		var o := (node as Label).size
		if not is_equal_approx(minf(t.x, t.y), minf(o.x, o.y)):
			return false
		var o_nen := StyleBoxTexture.new()
		o_nen.texture = tex
		(node as Label).add_theme_stylebox_override("normal", o_nen)
		return true
	if node is TienDo:
		(node as TienDo).anh = tex
		(node as TienDo).queue_redraw()
		return true
	# O nhap chu (CCEditBox): cung ly do nhu TienDo, va o day manh hon — anh nen
	# nho hon o rat nhieu (ui_background189.png 30x30 theo section C, dung cho o
	# 150x30 .. 410x45), tuc ban goc CO GIAN anh nen theo o. Dat o theo anh thi
	# o nhap co lai con 30x30 va chu bi cat. Xem ui/o_nhap.gd.
	if node is UiONhap:
		(node as UiONhap).dat_nen(tex)
		return true
	# CHIN-PHAN-NAM (CCScale9Sprite): dat anh roi THOI, khong dung toi o va cho.
	#
	# O cua no trong ban ghi la o DICH cua mot anh GOC bi keo 9 phan, nen kich
	# thuoc anh va kich thuoc o KHONG BAO GIO bang nhau — do tren 296 bo cuc:
	# 4.126 node ban ghi 248 byte co ten anh, chi 677 (16,4%) trung kich thuoc.
	# Lay anh lam o (duong chung ben duoi) thi 3.449 node con lai bi DOI kich
	# thuoc, va do duoc hau qua that: bat anh cho chung lam `bam that Main ->
	# tran` tut tu 5 dat / 0 hong xuong 0 dat / 5 hong — cu bam vao nut tan cong
	# `lMainExtraUIAttack` o (888, 576) bi `btnBackpackUI` nuot mat.
	#
	# Doi kich thuoc con SAI ca ve luat ban goc: `CCScale9Sprite` giu nguyen
	# contentSize roi keo 9 phan vao do, dung nhu `NinePatchRect` cua Godot. Ca
	# 677 node trung kich thuoc thi khong doi gi (keo vao o bang chinh no).
	if node is NinePatchRect:
		(node as NinePatchRect).texture = tex
		return true
	if node is TextureRect:
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
