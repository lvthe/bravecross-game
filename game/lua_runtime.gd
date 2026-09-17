## May ao Lua + lop gia lap Cocos2d-x, de chay THANG ma nguon cua ban goc.
##
## Vi sao: ban goc co san 952 file Lua / 510.068 dong, trong do rieng giao dien
## la 501 file / ~324.000 dong. Chep tay tung man sang GDScript thi khong bao
## gio xong va khong bao gio giong. Nen ta nap chinh ma do.
##
## Hai thu mac phai lam thu cong, vi Godot khong lam ho:
##
##   * require — ban goc dat package.path = "sc/?.lua" roi require theo ten
##     module. Ta cai mot ham tim tu doc qua FileAccess, vi thu muc sc/ co
##     .gdignore (phai co: addon Lua dang ky .lua la mot ngon ngu script cua
##     Godot, de Godot quet vao thi moi file ma goc bi coi la script Godot).
##
##   * lop gia lap — xem lua/cocos.lua.
class_name LuaRuntime
extends RefCounted

## Thu muc chua ma nguon Lua cua ban goc (bê vao bang tools/import_lua.py).
const SC := "res://sc/"

## Thu muc chua lop gia lap do minh viet.
const SHIM := "res://lua/"

var state: Object = null
var _loaded: Dictionary = {}
var errors: Array[String] = []


## Mo may ao va cai require. Tra ve false neu khong co addon.
## getSpriteFromSpriteCatch / getUIAnimFromSpriteCatch cua engine: tao mot
## ARMATURE (hoat anh xuong) theo ten. Ma goc goi 216 + 31 lan, va 440 lan
## _Lua_playAnimation — nha cua canh Main ("UIBingYing", "UIBaoXiang"...),
## hieu ung, tuong trong giao dien. Du lieu la chinh armature cua ban goc
## (map/<ten>.xml) do work/export.py xuat ra assets_ref/<ten>/; SngRig la bo
## phat da dung cho tran danh.
##
## Tra ve mot HOP Control co 0 (de cac API node cua lop gia lap dung duoc),
## voi SngRig lam con, goc cua rig trung diem dat cua hop — Cocos dat armature
## theo diem goc cua no. Khong co du lieu thi tra hop rong va ghi ten lai.
var rig_thieu: Dictionary = {}

## Am thanh (xem game/am_thanh.gd va lua/am_thanh.lua). Tao ngay o day chu
## khong doi den lan phat dau tien: ben kiem doc thang `am.so_phat` de biet
## duong noi co chay khong, va doi thi khong con gi de doc.
var am := AmThanh.new()

func _tao_rig(ten: String) -> Control:
	var hop := _new_node("node")
	hop.set_meta("kind", "rig")
	hop.set_meta("rig_ten", ten)
	var thu_muc := "res://assets_ref/%s" % ten
	var bien_the := ""
	# Ten la BIEN THE nam trong mot file armature khac ten: "UITongYong_ItemLight"
	# nam trong UITongYong, "Player004M03F" nam trong Player004 (co trong
	# map/Player004.xml). SngRig dat ten bien the day du dung nhu vay
	# (Archer_WeaponNormal). Khong co thu muc trung ten thi thu tien to ngan dan,
	# lay cai DAI NHAT co du lieu, va xin dung bien the do.
	if not FileAccess.file_exists("%s/%s.json" % [thu_muc, ten]):
		for i in range(ten.length() - 1, 3, -1):
			var goc := ten.substr(0, i).trim_suffix("_")
			if FileAccess.file_exists("res://assets_ref/%s/%s.json" % [goc, goc]):
				thu_muc = "res://assets_ref/%s" % goc
				bien_the = ten
				break
	var tep := "%s/%s.json" % [thu_muc, thu_muc.get_file()]
	if FileAccess.file_exists(tep):
		var rig := SngRig.build(thu_muc, bien_the, true)
		if rig != null:
			hop.add_child(rig)
			return hop
	rig_thieu[ten] = int(rig_thieu.get(ten, 0)) + 1
	return hop


## Cau noi mong sang game/am_thanh.gd. Moi ham o day chi de dua qua Lua duoc
## (phai la Callable dang ky trong `state.globals`) — khong them gi vao do.
func _phat_tieng(ten: String) -> int:
	return am.phat(ten)


func _dung_tieng(id: int) -> void:
	am.dung(id)


func _phat_nhac(ten: String) -> bool:
	return am.nhac(ten)


func _dung_nhac() -> void:
	am.dung_nhac()


func _tam_dung_nhac(dung_lai: bool) -> void:
	am.tam_dung_nhac(dung_lai)


func _nhac_dang_chay() -> bool:
	return am.nhac_dang_chay()


func _am_luong(loai_nhac: bool) -> float:
	return am.am_luong(loai_nhac)


func _dat_am_luong(loai_nhac: bool, v: float) -> void:
	am.dat_am_luong(loai_nhac, v)


func _ghi_chu_bank(ten: String, duong: String) -> void:
	am.ghi_chu_bank(ten, duong)


func _bo_bank(ten: String) -> void:
	am.bo_bank(ten)


func open() -> bool:
	if not ClassDB.class_exists("LuaState"):
		errors.append("khong co LuaState — chay: python tools/fetch_addons.py")
		return false
	state = ClassDB.instantiate("LuaState")
	state.open_libraries()
	state.globals["_godot_tao_rig"] = _tao_rig
	state.globals["_godot_read"] = _read
	state.globals["_godot_log"] = func(s): print("[lua] ", s)
	state.globals["_godot_copy"] = _copy
	state.globals["_godot_frame"] = _frame
	state.globals["_godot_dat_xam"] = _dat_xam
	state.globals["_godot_dat_sang"] = _dat_sang
	state.globals["_godot_dat_chuyen_sac"] = _dat_chuyen_sac
	state.globals["_godot_go_chuyen_sac"] = _go_chuyen_sac
	state.globals["_godot_zsort"] = _zsort
	state.globals["_godot_reflash"] = _reflash
	state.globals["_godot_load_xgg"] = _load_xgg
	state.globals["_godot_new_node"] = _new_node
	state.globals["_godot_text"] = _text
	state.globals["_godot_co_file"] = _co_file
	state.globals["_godot_doc_file"] = _doc_file
	state.globals["_godot_replace_scene"] = _replace_scene
	state.globals["_godot_ra_the_gioi"] = _ra_the_gioi
	state.globals["_godot_vao_node"] = _vao_node
	state.globals["_godot_bo_xgg"] = _bo_xgg
	state.globals["_godot_danh_tran"] = _danh_tran
	state.globals["_godot_tao_tran"] = _tao_tran
	# Am thanh: bay ten toan cuc cua engine goc (lua/am_thanh.lua) de len tren
	# lop am thanh nay. Xem game/am_thanh.gd. Node cha cua cac kenh do
	# `set_stage` dat (no chay SAU open), khong dat o day.
	state.globals["_godot_phat_tieng"] = _phat_tieng
	state.globals["_godot_dung_tieng"] = _dung_tieng
	state.globals["_godot_phat_nhac"] = _phat_nhac
	state.globals["_godot_dung_nhac"] = _dung_nhac
	state.globals["_godot_tam_dung_nhac"] = _tam_dung_nhac
	state.globals["_godot_nhac_dang_chay"] = _nhac_dang_chay
	state.globals["_godot_am_luong"] = _am_luong
	state.globals["_godot_dat_am_luong"] = _dat_am_luong
	state.globals["_godot_ghi_chu_bank"] = _ghi_chu_bank
	state.globals["_godot_bo_bank"] = _bo_bank
	# LGG_GetSetFilePath (lua/bootstrap.lua): thu muc ghi duoc, dang duong dan
	# that de io.open cua Lua mo duoc.
	var ghi := ProjectSettings.globalize_path("user://")
	if not ghi.ends_with("/"):
		ghi += "/"
	state.globals["_godot_thu_muc_ghi"] = ghi
	state.globals["_godot_doc_ngoai"] = _doc_ngoai
	state.globals["_godot_ghi_ngoai"] = _ghi_ngoai
	state.globals["_godot_xoa_ngoai"] = _xoa_ngoai
	state.globals["_godot_ky_thuoc_ngoai"] = _ky_thuoc_ngoai
	# Kich thuoc cua so. Ban goc doc qua hai bien toan cuc nay
	# (CPublic:GetWinSize tra thang chung), va SetNodeAdaptWinSize chia cho
	# chung — de la bong thi bao 'arithmetic on a table value'.
	var vp := Vector2(960, 640)
	if Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		if st.root != null and st.root.size.x > 0:
			vp = Vector2(st.root.size)
	# Cua so ENGINE (don vi thiet ke), neu cong cu canh dat — xem cua_so_engine.
	if cua_so_engine != Vector2.ZERO:
		vp = cua_so_engine
	state.globals["screenWidth"] = vp.x
	state.globals["screenHeight"] = vp.y
	_cao_the_gioi = vp.y
	# require tu viet: doi "a.b.c" ra "res://sc/a/b/c.lua", nho ket qua lai
	# dung kieu package.loaded cua Lua that (mot module chi chay mot lan).
	var r = state.do_string("""
		local loaded = {}
		local reading = {}
		local require_goc = require
		function require(name)
			if loaded[name] ~= nil then return loaded[name] end
			if reading[name] then
				error('require vong tron: ' .. name)
			end
			reading[name] = true
			local path = name:gsub('%.', '/')
			local src = _godot_read(path)
			reading[name] = nil
			if src == nil then
				-- LuaJIT co san vai thu vien nap kieu package.preload ma khong
				-- co file: 'bit' la mot (system/rpc.lua va user/Logical/Device.lua
				-- deu can). Tim file khong thay thi hoi require that.
				if require_goc ~= nil then
					local good, v = pcall(require_goc, name)
					if good then
						loaded[name] = v
						return v
					end
				end
				error("khong tim thay module '" .. name .. "'")
			end
			local chunk, err = loadstring(src, '@' .. path .. '.lua')
			if chunk == nil then error(err) end
			local v = chunk()
			if v == nil then v = true end
			loaded[name] = v
			return v
		end
		package = package or {}
		package.loaded = loaded
	""")
	if _is_error(r):
		errors.append("cai require hong: %s" % r)
		return false
	return true


## Doc mot file Lua theo ten module. Tim trong lop gia lap truoc, roi den ma
## goc — de ta de len duoc mot module cua ban goc khi can thay the.
func _read(rel: String) -> Variant:
	for base: String in [SHIM, SC]:
		var p := base + rel + ".lua"
		if FileAccess.file_exists(p):
			return FileAccess.get_file_as_string(p)
	return null


## Nhan ban mot node ke ca cay con. Ban goc nhan mau thanh tung dong danh
## sach, nen thieu cai nay la danh sach rong.
##
## Chep META tuong minh. duplicate() cua Godot khong mang theo metadata, ma
## toan bo cach ma goc tro toi node deu dua vao meta "tag" — ban sao mat tag
## thi getChildByTag tra ve nil va dong nao cung hong ngay dong dau.
func _copy(node: Node) -> Node:
	if node == null:
		return null
	var ban := node.duplicate()
	_copy_meta(node, ban)
	return ban


static func _copy_meta(tu: Node, den: Node) -> void:
	for k in tu.get_meta_list():
		den.set_meta(k, tu.get_meta(k))
	var n: int = mini(tu.get_child_count(), den.get_child_count())
	for i in range(n):
		_copy_meta(tu.get_child(i), den.get_child(i))


## Nap mot file .xgg vao duoi mot node — dung viec ma loadLevelFile() cua ban
## goc lam. Ban goc goi no qua CLevelLoader:LoadFiles trong duong Show:
##
##     loader:LoadFiles(tenCanh, self.ResourceXggList, uiRootLayer)
##
## nghia la moi man hinh tu khai bao file bo cuc cua no (ResourceXggList) va tu
## nap vao UIRootLayer. Truoc day minh dung tay lam viec nay o phia GDScript;
## nay de ma goc lo, va nho vay MOI man deu mo duoc bang ten chu khong phai
## noi day tung cai.
##
## Tra ve mot Array xen ke [ten, node, ten, node, ...] de phia Lua dat thanh
## bien toan cuc — dung cach bo nap cua ban goc lam.
var _da_nap: Dictionary = {}
var _goc_ui: Node = null

## Node ma cac man hinh duoc nap vao (UIRootLayer). Dat truoc khi chay Show.
func set_ui_root(n: Node) -> void:
	_goc_ui = n


## San khau: noi cac CANH duoc nap vao va thay nhau. Ban goc nap file cua canh
## voi cha = nil (CSceneManager:sngLoadXggAsync -> LoadFilesAsync(..., nil)),
## tuc goc cua file — mot CCScene nhu g_MainUIScene — dung rieng, roi
## S_CCDirector:replaceScene chon canh nao dang chay. Chua dat san khau thi
## cha = nil van roi vao UIRootLayer nhu truoc.
var _san: Node = null

func set_stage(n: Node) -> void:
	_san = n
	# Kenh am thanh nam trong cay thi moi phat duoc, va nen nam cung cho voi
	# canh (khong phai goc cua so) de doi canh khong dung toi chung.
	am.dat_cha(n)
	# Noi phat cho lop tieng-dong cua ban goc (game/tieng_dong.gd). Day la cho
	# DUY NHAT dat: tu day tro di, moi `SngRig` dung len deu tu phat tieng theo
	# khung hoat dong, va tran danh tu phat tieng trung don.
	TiengDong.am = am


func _replace_scene(canh: Node) -> void:
	if _san == null or canh == null:
		return
	if canh.get_parent() != _san:
		if canh.get_parent() != null:
			canh.get_parent().remove_child(canh)
		_san.add_child(canh)
	for c in _san.get_children():
		if c is CanvasItem:
			c.visible = (c == canh)


## convertToWorldSpace / convertToNodeSpace cua Cocos. Khong gian cua mot node
## lay goc o goc DUOI-TRAI cua o node, y huong len; the gioi lay goc o goc
## duoi-trai cua cua so. Di qua chuoi bien doi cua Godot (_bien_doi) chu khong
## tu cong toa do: phong to va xoay cua cha deu phai tinh.
var _cao_the_gioi := 640.0

func _ra_the_gioi(n: Node, x: float, y: float) -> Vector2:
	if not (n is Control):
		return Vector2(x, y)
	var p := _bien_doi(n) * Vector2(x, (n as Control).size.y - y)
	return Vector2(p.x, _cao_the_gioi - p.y)


func _vao_node(n: Node, x: float, y: float) -> Vector2:
	if not (n is Control):
		return Vector2(x, y)
	var q := _bien_doi(n).affine_inverse() * Vector2(x, _cao_the_gioi - y)
	return Vector2(q.x, (n as Control).size.y - q.y)


## sngXggMgrPool_popXgg: quen file da nap de lan sau nap lai duoc (xem
## lua/bootstrap.lua). Chua giai phong node.
func _bo_xgg(duong: String) -> void:
	_da_nap.erase(duong.get_file().get_basename())


## Cua so cua ENGINE, don vi thiet ke — dat TRUOC open(). Zero = dung co cua
## so Godot nhu truoc (cac cong cu xem man). Cong cu canh dat cao 768, rong
## theo ti le man: may ao do duoc ca 13 CCScene cua ban goc la 1429x768.
var cua_so_engine := Vector2.ZERO


func _load_xgg(duong: String, cha = null) -> Array:
	var ten := duong.get_file().get_basename()
	if _da_nap.has(ten) and is_instance_valid(_da_nap[ten]):
		# Ban goc cung khong nap lai: "LoadFilesAsync noi bo khong nap lai xgg".
		return []
	var p := "res://layout_ref/%s.json" % ten
	if not FileAccess.file_exists(p):
		errors.append("loadLevelFile: khong co bo cuc %s" % p)
		return []
	var man := XggLayout.build(p)
	if man == null:
		return []
	var cha_node: Node = cha if cha is Node else (_san if _san != null else _goc_ui)
	var ds: Array = []
	for c in man.get_children():
		_gom_ten(c, ds)
	# CANH len san khau: engine dat CCScene tai goc cua so, co bang cua so. May
	# ao do duoc ca 13 CCScene 1429x768 tai (0,0), trong khi file ghi (1,-1),
	# neo 0,5, co 1366x768 — CCScene bo qua neo khi dat cho. Dung theo file thi
	# ca canh Main lech sang trai 682 px va xuong 257 px, ra ngoai khung.
	if cha_node != null and cha_node == _san and _san is Control:
		for c in man.get_children():
			if c is Control and String(c.get_meta("type_name", "")) == "CCScene":
				c.position = Vector2.ZERO
				c.size = (_san as Control).size
				c.set_meta("parent_h", (_san as Control).size.y)
				c.set_meta("cocos", Vector4(0, 0, 0, 0))
				# Con TRUC TIEP cua canh da dat theo co trong FILE. g_GameUIScene
				# (canh Battle) ghi 40x40, nen g_BattleFieldLayer — (0,0), neo 0 —
				# dung o y = 40 - 40 = 0: MEP TREN, va ca san tran nam ngoai khung
				# (goc nut tran do duoc o y = 33 tren man). Cocos dat con theo goc
				# DUOI-trai cua cha: dat lai theo chieu cao that. g_MainUIScene ghi
				# san 768 nen khong doi gi.
				var h_canh := (_san as Control).size.y
				for k in c.get_children():
					if k is Control and k.has_meta("cocos"):
						var v: Vector4 = k.get_meta("cocos")
						if XggLayout.bo_qua_neo(String(k.get_meta("type_name", ""))):
							v.z = 0.0
							v.w = 0.0
						var sz: Vector2 = (k as Control).size
						k.position = Vector2(v.x - v.z * sz.x, h_canh - (v.y - v.w * sz.y) - sz.y)
						k.set_meta("parent_h", h_canh)
	# Bo cuc nap vao MOT CHA KHAC: node cap cao nhat duoc dung theo khung thiet
	# ke 960x640, nhung toa do Cocos cua no la tuong doi voi CHA THAT (goc
	# duoi-trai). Doi lai theo chieu cao that cua cha, giu nguyen toa do Cocos
	# — nhu Node:addChild. Truoc day khung hop thoai (UI_NormalDlg) nap vao
	# g_MainUIScene cao 768 van giu parent_h = 640, nen UIRootLayer dat cao hon
	# 128, phong 1,2 quanh goc duoi-trai, va dai nut tren cung bi cat mat.
	elif cha_node is Control and (cha_node as Control).size.y > 0.0:
		var h_cha := (cha_node as Control).size.y
		for c in man.get_children():
			if c is Control and c.has_meta("cocos") \
					and absf(float(c.get_meta("parent_h", h_cha)) - h_cha) > 0.5:
				var v: Vector4 = c.get_meta("cocos")
				if XggLayout.bo_qua_neo(String(c.get_meta("type_name", ""))):
					v.z = 0.0
					v.w = 0.0
				var sz: Vector2 = (c as Control).size
				c.position = Vector2(v.x - v.z * sz.x, h_cha - (v.y - v.w * sz.y) - sz.y)
				c.set_meta("parent_h", h_cha)
	if cha_node != null:
		XggLayout.ghep_vao_node(cha_node, man)
		_da_nap[ten] = cha_node
		man.free()
	else:
		# Chua co cho de: giu nguyen cai boc lam goc.
		_da_nap[ten] = man
	return ds


static func _gom_ten(n: Node, ds: Array) -> void:
	if n is Control and n.has_meta("xgg_name"):
		var nm := String(n.get_meta("xgg_name"))
		if _is_ident(nm):
			ds.append(nm)
			ds.append(n)
	for c in n.get_children():
		_gom_ten(c, ds)


## Dung mot node MOI luc chay. Ban goc tao node ngoai bo cuc o 33 cho:
## Label:new() 14, CCScale9Sprite:new() 9, CCSprite:new() 7, CCLabelTTF:new() 3
## — nhieu nhat la RichLabel, no dung mot Label cho tung doan chu co dinh dang
## rieng.
##
## Node moi phai mang du meta nhu node dung tu .xgg, khong thi lop gia lap doi
## he toa do sai: 'cocos' (x, y, neo) va 'parent_h'.
func _new_node(kieu: String) -> Control:
	var n: Control
	match kieu:
		"label":
			var lb := Label.new()
			lb.add_theme_font_size_override("font_size", 20)
			n = lb
		"scale9":
			var np := NinePatchRect.new()
			np.draw_center = true
			n = np
		"mau":
			# CCLayerColorRoundRect tao luc chay: cung ColorRect nhu lop mau
			# nap tu .xgg (xgg_layout.gd), de setColor/setOpacity cua
			# cocos.lua (la_lop_mau) doi dung mau cua chinh no.
			var cr := ColorRect.new()
			cr.color = Color(0, 0, 0, 0)
			n = cr
		"sprite":
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			n = tr
		_:
			n = Control.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.set_meta("kind", kieu)
	# type_name quyet dinh cach dat vi tri: lop (CCLayer*, CCScene) bo qua
	# diem neo nhu Cocos (cocos.lua la_lop).
	n.set_meta("type_name", {"label": "CCLabelTTF", "mau": "CCLayerColorRoundRect",
			"lop": "CCLayer"}.get(kieu, "CCNode"))
	n.set_meta("cocos", Vector4(0, 0, 0, 0))
	n.set_meta("parent_h", 640.0)
	return n


const _TRAN_GOC := preload("res://battle/tran_goc.gd")

## Tran cua g_BattleField gia (lua/san_tran.lua). Tra CHUOI JSON — Lua giai
## bang cjson; Dictionary cua Godot sang Lua khong doc duoc nhu bang.
func _danh_tran(ta_json, dich_json, hat) -> String:
	return _TRAN_GOC.danh(str(ta_json), str(dich_json), int(hat) if hat != null else 0)


const _SAN_TRAN_VE := preload("res://battle/san_tran_ve.gd")

## Tran CO HINH (lua/san_tran.lua): mot Node2D gan vao node g_BattleField. Lua
## goi thang bat_dau / buoc / chot / dung tren doi tuong tra ve.
func _tao_tran(cha) -> Node2D:
	var t: Node2D = _SAN_TRAN_VE.new()
	if cha is Node:
		(cha as Node).add_child(t)
	return t


## Xep lai anh em theo zOrder. Ben Lua khong voi toi lop XggLayout duoc, nen
## phai bac qua day nhu may cai kia.
func _zsort(cha: Node) -> void:
	if cha != null:
		XggLayout.sap_xep_theo_z(cha)


## `sngFixInfoReflash` cua ban goc — lua/cocos.lua goi vao day. Chay tu tren
## xuong, moi node tu tinh lai cho theo `contentSize` cua CHA no. Cong thuc va
## tam so o ui/xgg_layout.gd, muc `reflash`.
##
## Ham nay KHONG duoc goi luc dung bo cuc: ban goc chi reflash nhung lop duoc
## goi ten (CSceneManager:PreLoadFinish, UIRootLayer, va 27 man co
## IsFullScreenAdaptation) — xem chu thich dai o lua/cocos.lua.
func _reflash(node: Control) -> int:
	if node == null:
		return 0
	return XggLayout.reflash(node)


## Gan anh theo ten khung. Ban goc gan anh luc CHAY chu khong ghi trong bo
## cuc — day la ly do bo cuc dung khong thi man hinh gan nhu trong tron.
func _frame(node: Control, name: String) -> bool:
	if node == null or name.is_empty():
		return false
	return UiFrames.set_frame(node, name)


## To xam mot node ve (CCSprite / CCScale9Sprite). Xem ui/xam.gdshader de biet
## vi sao cong thuc dung nhu vay, va lua/cocos.lua:setGray de biet vi sao chi
## node CO ANH moi di duong nay.
func _dat_xam(node: Control, bat: bool) -> void:
	UiXam.dat(node, bat)


## Hieu ung sang mot node ve (chuong trinh shader so 2 cua ban goc). Xem
## ui/sang.gdshader de biet vi sao cong thuc dung nhu vay, va
## lua/cocos.lua:setGlow de biet vi sao no dung chung duong voi `_dat_xam`.
func _dat_sang(node: Control, bat: bool) -> void:
	UiSang.dat(node, bat)


## Chuyen sac chu cua mot nhan (chuong trinh shader so 8 cua ban goc). Khac
## `_dat_xam`/`_dat_sang`: vat lieu o day gan theo TUNG node vi hai mau la tham
## so — xem ui/chuyen_sac.gd.
func _dat_chuyen_sac(node: Control, r1: float, g1: float, b1: float,
		r2: float, g2: float, b2: float) -> void:
	UiChuyenSac.dat(node, _mau255(r1, g1, b1), _mau255(r2, g2, b2))


## `disableGradual` cua ban goc: tat co roi tra chuong trinh THUONG
## (`vfunc_0x2e8`) — o day la go vat lieu cua ta.
func _go_chuyen_sac(node: Control) -> void:
	UiChuyenSac.go(node)


## Sau so Lua (0..255) thanh mot mau. Ban goc chia ngay trong ham boc
## `enableGradual` (0x2cab6c: `vdiv.f32` ba lan cho mot bo ba, chia cho hang
## 255,0 nam trong pool hang so), va bon o alpha cua hai vec4 duoc dien san bang
## 1,0 — nen KHONG co tham so alpha nao di qua day.
func _mau255(r: float, g: float, b: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0)


## Bang chu tieng Viet cua ban goc (data_ref/text_vi.json, 16.894 khoa).
## Thieu khoa thi tra chinh khoa do, de con nhin thay cho nao chua co chu.
var _strings: Dictionary = {}
var _strings_loaded := false

func _text(key: String) -> String:
	if not _strings_loaded:
		_strings_loaded = true
		var p := "res://data_ref/text_vi.json"
		if FileAccess.file_exists(p):
			var d = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				_strings = d
		else:
			push_warning("thieu %s — chay: python ../brave-cross/work/text_table.py" % p)
	return String(_strings.get(key, key))


## Thu muc chua 104 bang cau hinh cua ban goc (bê bang config_tables.py).
const CONFIG := "res://data_ref/"


## Doi duong dan ma goc yeu cau ("config/share/KDBGamePrizeConfig.xgg") thanh
## duong dan that. Ban goc giu nguyen cay thu muc nen chi can gan tien to.
##
## Duong dan TUYET DOI thi tra nguyen: `sngUtil:isFileExist` duoc goi voi
## `sngUtil:getDownloadPath().."<ten>"` (set.lua:259, :286-292), tuc mot duong
## dan ngoai — gan tien to vao thi no thanh "res://data_ref/C:/..." va luon ra
## 'khong co file', sai lang le.
static func _duong(p: String) -> String:
	if p.begins_with("res://") or p.contains("://") or p.is_absolute_path():
		return p
	return CONFIG + p


## Nang mot file theo byte, -1 khi khong co. Khong dung get_file_as_string: file
## nhi phan se bi thay byte sai thanh ky tu thay the, va do dai dem ra SAI —
## ma sngAsyncDLMgr:436,:735,:742 dem tien do tai bang chinh con so nay.
func _ky_thuoc_ngoai(p: String) -> int:
	if not FileAccess.file_exists(p):
		return -1
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n


func _co_file(p: String) -> bool:
	return FileAccess.file_exists(_duong(p))


func _doc_file(p: String) -> Variant:
	var d := _duong(p)
	if not FileAccess.file_exists(d):
		return null
	return FileAccess.get_file_as_string(d)


## Doc / ghi / xoa file theo DUONG DAN THAT, cho io.open cua Lua (xem
## lua/bootstrap.lua). io.open cua LuaJIT tren Windows goi fopen voi trang ma
## ANSI, nen duong dan co ky tu ngoai ASCII khong mo duoc — ma thu muc user://
## cua du an nay mang ten "BraveCross — game moi", co dau gach dai. FileAccess
## cua Godot thi mo duoc.
func _doc_ngoai(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	return FileAccess.get_file_as_string(p)


func _ghi_ngoai(p: String, s: String, noi: bool) -> bool:
	var f: FileAccess = null
	if noi and FileAccess.file_exists(p):
		f = FileAccess.open(p, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(s)
	f.close()
	return true


func _xoa_ngoai(p: String) -> bool:
	return DirAccess.remove_absolute(p) == OK


## Chay mot doan Lua. Tra ve ket qua, hoac null va ghi vao errors.
func run(src: String, name: String = "doan") -> Variant:
	var r = state.do_string(src)
	if _is_error(r):
		errors.append("%s: %s" % [name, r])
		return null
	return r


## Nap lop gia lap Cocos va tra ve bang cua no.
func load_cocos() -> Variant:
	return run("return require('cocos')", "cocos")


## Dua cay node cua mot man hinh (do XggLayout dung) vao Lua, dat moi node co
## TEN thanh bien toan cuc — dung cach ban goc lam. Ma goc cua no viet thang
## `lAchieveTaskUI`, `lAchieveLayer`... khong qua bien trung gian nao.
##
## Tra ve so bien da dat.
func bind_layout(root: Node) -> int:
	var cocos = load_cocos()
	if cocos == null:
		return 0
	state.globals["_root"] = root
	var n := 0
	var names: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c in cur.get_children():
			stack.push_back(c)
		if not cur.has_meta("xgg_name"):
			continue
		var nm := String(cur.get_meta("xgg_name"))
		# Chi dat ten nao dung duoc lam bien Lua.
		if nm.is_empty() or not _is_ident(nm):
			continue
		state.globals["_tmp_node"] = cur
		var r = state.do_string(
				"local c = require('cocos'); %s = c.wrap(_tmp_node)" % nm)
		if _is_error(r):
			errors.append("dat bien %s: %s" % [nm, r])
			continue
		names.append(nm)
		n += 1
	state.globals["_tmp_node"] = null
	return n


## Day thoi gian cho he action cua ban goc. Goi moi khung hinh.
## Tra ve so action con dang chay (0 = da yen).
func tick(dt: float) -> int:
	if state == null:
		return 0
	var r = state.do_string("return require('cocos').tick(%f)" % dt)
	if _is_error(r):
		# Ghi lai chu khong nuot. Ca duong Show cua ban goc di qua day:
		# OnShowAnimationFinish nam trong mot S_CCCallFunc, nen Reflesh() hong
		# thi loi chi hien o day — nuot di la man hinh trong ma khong ai biet
		# tai sao.
		var m := "tick: %s" % r
		if not errors.has(m):
			errors.append(m)
		return 0
	return int(r) if typeof(r) in [TYPE_INT, TYPE_FLOAT] else 0


## Cham. Engine ban goc tu tim node bi cham roi goi ham Lua cua no; o day
## GDScript tim node (vi can bien doi toa do cua Godot), con goi ham nao voi
## doi so gi thi o lua/cocos.lua (M.cham).
##
## Node bi cham la node TREN CUNG — ve sau thi nam tren — co ten cham, dang
## bat (setEnableLuaTouch), dang hien, va diem cham nam trong o cua no. Node
## da nhan Begin thi giu cham toi luc tha tay, du tay da truot ra ngoai:
## chinh vi the ma goc moi co doi so bTouchInSide.
var _goc_cham: Node = null
var _dang_cham: Control = null

## O nhap chu dang giu tieu diem (nhan chu). Chuyen tiep ban phim cho no thi
## Godot lo: LineEdit nam trong cay va dang co tieu diem thi nhan duoc phim qua
## he GUI cua viewport. O day chi can biet dang la o nao de THA khi nguoi choi
## cham ra ngoai — ban goc cung ket thuc sua dung luc do.
var _dang_go_o_nhap: UiONhap = null

## Goc de do cham (mac dinh la UIRootLayer). Nen dat la ca khung, vi lop che
## va nut Back cua hop thoai nam ngoai UIRootLayer.
func set_touch_root(n: Node) -> void:
	_goc_cham = n


## Nhan mot su kien chuot. Tra ve true neu mot node cua ban goc nhan no.
## Chi nghe chuot: Godot mac dinh doi cham man hinh thanh chuot
## (emulate_mouse_from_touch), nghe ca hai thi mot cai cham thanh hai.
func touch(e: InputEvent) -> bool:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		return touch_at("Begin" if e.pressed else "End", e.position)
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		return touch_at("Move", e.position)
	return false


## Cham tai diem p (toa do canvas). pha: Begin / Move / End.
func touch_at(pha: String, p: Vector2) -> bool:
	var goc: Node = _goc_cham if _goc_cham != null else _goc_ui
	if state == null or goc == null:
		return false
	var c := _toa_do_cocos(goc, p)
	# Goc cham, cho lop cuon (lua/cuon.lua) doi toa do ve khong gian cua chinh
	# no: a/b/c truyen cho Lua la toa do trong khong gian cua GOC nay, con
	# position cua cac con lai o khong gian cua lop. Khong co no thi mot phep
	# phong to nam giua hai thu do se lam do keo sai ti le. Xem cuon.lua doi_vao.
	state.globals["_cham_goc"] = goc
	if pha == "Begin":
		_dang_cham = null
		var ds: Array = []
		# Co ca O NHAP CHU trong danh sach: chung khong bao gio co ten cham (do
		# ca 40 node trong 22 bo cuc: khong node nao co 'touch' hay 'touchObj'),
		# nen duong cham thuong khong bao gio voi toi chung. Gop chung mot luot
		# di cay de THU TU TREN-DUOI giua o nhap va node cham van dung: ai ve
		# sau thi nam tren.
		_ung_vien(goc, p, ds, true)
		for n in ds:
			if n is UiONhap:
				# Ban goc: cham vao o nhap la BAT DAU SUA. Tieu diem cua
				# LineEdit ban ra 'began' qua tin hieu (xem ui/o_nhap.gd).
				_noi_tin_hieu_o_nhap(n)
				_dang_go_o_nhap = n
				if n.o_chu.is_inside_tree():
					n.o_chu.grab_focus()
				return true
			if _goi_cham("Begin", n, c.x, c.y, null):
				_tha_tieu_diem_o_nhap()
				_dang_cham = n
				return true
		_tha_tieu_diem_o_nhap()
		return false
	if _dang_cham == null or not is_instance_valid(_dang_cham):
		_dang_cham = null
		return false
	var trong := _trung(_dang_cham, p)
	if pha == "Move":
		_goi_cham("Move", _dang_cham, trong, c.x, c.y)
		return true
	var n := _dang_cham
	_dang_cham = null
	_goi_cham("End", n, trong, c.x, c.y)
	return true


func _goi_cham(pha: String, n: Node, a, b, c) -> bool:
	state.globals["_cham_node"] = n
	state.globals["_cham_a"] = a
	state.globals["_cham_b"] = b
	state.globals["_cham_c"] = c
	var r = state.do_string("""
		return require('cocos').cham('%s', _cham_node, _cham_a, _cham_b, _cham_c)
	""" % pha)
	state.globals["_cham_node"] = null
	if _is_error(r):
		errors.append("cham %s: %s" % [pha, r])
		return false
	return r == true


## Moi node nhan cham duoi diem p, tu TREN xuong: con ve sau nam tren con ve
## truoc, con nam tren cha. Nhanh bi an thi bo ca nhanh; o cat xen
## (clip_contents, vd danh sach cuon) thi diem ngoai o khong cham duoc con.
##
## `ca_o_nhap` = gom ca o nhap chu (UiONhap) vao danh sach. Duong cham THUONG
## khong bat no, vi o nhap khong co meta 'touch'.
func _ung_vien(n: Node, p: Vector2, ds: Array, ca_o_nhap := false) -> void:
	if n is CanvasItem and not n.visible:
		return
	if n is Control and n.clip_contents and not _trung(n, p):
		return
	var con: Array = []
	for i in range(n.get_child_count()):
		con.append(n.get_child(i))
	# z_index do addChild(con, z) dat: Godot ve z lon hon len tren.
	con.sort_custom(func(x, y):
		var zx: int = x.z_index if x is CanvasItem else 0
		var zy: int = y.z_index if y is CanvasItem else 0
		if zx != zy:
			return zx > zy
		return x.get_index() > y.get_index())
	for k in con:
		_ung_vien(k, p, ds, ca_o_nhap)
	if n is Control and _nhan_duoc(n, p, ca_o_nhap):
		ds.append(n)


func _nhan_duoc(n: Control, p: Vector2, ca_o_nhap: bool) -> bool:
	if not _trung(n, p):
		return false
	if n is UiONhap:
		return ca_o_nhap
	return n.has_meta("touch") and String(n.get_meta("touch")) != "" \
			and bool(n.get_meta("lua_touch", true))


## Tha tieu diem cua o nhap dang go (neu co). Ban goc ket thuc sua khi nguoi
## choi cham ra ngoai o — khong phai khi tha tay.
func _tha_tieu_diem_o_nhap() -> void:
	if _dang_go_o_nhap == null:
		return
	var o := _dang_go_o_nhap
	_dang_go_o_nhap = null
	if is_instance_valid(o) and o.o_chu != null and o.o_chu.has_focus():
		o.o_chu.release_focus()


## Noi bon tin hieu cua o nhap voi ham Lua da dang ky, MOT lan cho moi node.
## Noi luc cham chu khong luc dung bo cuc: XggLayout khong biet gi ve Lua.
func _noi_tin_hieu_o_nhap(o: UiONhap) -> void:
	if o.has_meta("lua_da_noi"):
		return
	o.set_meta("lua_da_noi", true)
	o.doi_chu.connect(func(_chu: String): _su_kien_o_nhap(o, "changed"))
	o.go_ve.connect(func(_chu: String): _su_kien_o_nhap(o, "return"))
	o.bat_dau_go.connect(func(): _su_kien_o_nhap(o, "began"))
	o.ket_thuc_go.connect(func(): _su_kien_o_nhap(o, "ended"))


## Ban su kien cua o nhap ra ham Lua. Ham do nhan DUNG MOT doi so — chuoi su
## kien — va `self` la DOI TUONG TRA THEO TEN TOAN CUC chu khong phai node:
## CUIBuyDialogEx.lua:113-114 dang ky ("g_CUIBuyDialogEx", "editboxEventHandler")
## va ham duoc goi la `editboxEventHandler(doiTuong, suKien)`. Bon ten su kien
## doc tu .rodata 0x7a6a30..0x7a6a90: began, changed, ended, return.
##
## Phan tra cuu nam ben Lua (lua/o_nhap.lua, O.su_kien) — cung mot luat voi ban
## goc. Chua dang ky gi thi thoat NGAY: `setLuaCallbackObjAndFunc` moi la thu
## dat meta 'lua_cb_obj', nen o nao khong dang ky thi khong ton lan goi Lua.
func _su_kien_o_nhap(n: Control, su_kien: String) -> void:
	if state == null or not n.has_meta("lua_cb_obj"):
		return
	state.globals["_sk_gd"] = n
	state.globals["_sk_ten"] = su_kien
	var r = state.do_string("return require('cocos').o_nhap.su_kien(_sk_gd, _sk_ten)")
	state.globals["_sk_gd"] = null
	if _is_error(r):
		errors.append("o nhap %s: %s" % [su_kien, r])


## p (toa do canvas) co nam trong o cua n khong. Tu nhan bien doi len theo
## chuoi cha thay vi get_global_transform(): cay dung trong phep kiem khong
## nam trong SceneTree, ma get_global_transform doi phai nam trong.
static func _trung(n: Control, p: Vector2) -> bool:
	if n.size.x <= 0.0 or n.size.y <= 0.0:
		return false
	return Rect2(Vector2.ZERO, n.size).has_point(_bien_doi(n).affine_inverse() * p)


static func _bien_doi(n: CanvasItem) -> Transform2D:
	var t := n.get_transform()
	var p := n.get_parent()
	while p is CanvasItem:
		t = (p as CanvasItem).get_transform() * t
		p = p.get_parent()
	return t


## Doi diem canvas ra toa do Cocos cua goc: goc duoi-trai, y huong len.
static func _toa_do_cocos(goc: Node, p: Vector2) -> Vector2:
	var q := p
	var h := 640.0
	if goc is Control:
		q = _bien_doi(goc).affine_inverse() * p
		if goc.size.y > 0.0:
			h = goc.size.y
	return Vector2(q.x, h - q.y)


## Hai bo dem cua `sngFixInfoReflash` (lua/cocos.lua): so lan ma goc goi, va so
## node no dat lai.
##
## Tra `Dictionary()` chu KHONG tra bang Lua: bang Lua ve ben nay la `LuaTable`,
## khong phai `Array`, nen `r[0]` doc ra nil va ham im lang tra so 0 — da mac
## dung cai bay ay (doc ra 0 trong khi `dem` ben Lua la 6). Tra -1 khi hong, de
## "khong doc duoc" khong tron voi "khong he chay".
func fix_reflash() -> Dictionary:
	var r = state.do_string("""
		local c = require('cocos')
		local out = Dictionary()
		out['goi'] = c.fix_reflash_goi
		out['node'] = c.fix_reflash_node
		return out
	""")
	if _is_error(r) or typeof(r) != TYPE_DICTIONARY:
		errors.append("fix_reflash: %s" % r)
		return {"goi": -1, "node": -1}
	return {"goi": int(r["goi"]), "node": int(r["node"])}


## Cac API Cocos bi goi ma minh chua lam — dem duoc, de biet con thieu gi.
func missing() -> Dictionary:
	# Dung thang Dictionary cua Godot ben Lua: LuaTable khong co keys(), ma
	# minh can mot Dictionary that de dem ben GDScript.
	var r = state.do_string("""
		local out = Dictionary()
		for k, v in pairs(require('cocos').missing) do out[k] = v end
		return out
	""")
	if _is_error(r) or typeof(r) != TYPE_DICTIONARY:
		return {}
	var d := {}
	for k in r:
		d[String(k)] = int(r[k])
	return d


static func _is_ident(s: String) -> bool:
	if s.is_empty():
		return false
	var c := s.unicode_at(0)
	if not (c == 95 or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)):
		return false
	for i in range(1, s.length()):
		var d := s.unicode_at(i)
		if not (d == 95 or (d >= 48 and d <= 57) or (d >= 65 and d <= 90)
				or (d >= 97 and d <= 122)):
			return false
	return true


static func _is_error(v: Variant) -> bool:
	# do_string tra ve du kieu — chuoi, so, bang, hay LuaError. Goi get_class()
	# tren mot chuoi la loi, nen phai xem kieu truoc.
	return typeof(v) == TYPE_OBJECT and v != null and v.get_class() == "LuaError"
