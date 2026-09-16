# He hat cua ban goc (ui/hat.gd + lua/hat.lua).
#
#   godot --headless --path . --script tools/verify_hat.gd
#
# Do cai gi. Bon tang:
#
#   A. DU LIEU. 33 dinh nghia trong hat_ref/, 87 node hat trong 296 bo cuc, va
#      moi duong dan 'res' phai tra ra mot dinh nghia — ke ca cai ten co DUOI
#      CACH that ('../map/buttonbling .plist'). Anh cua ca 33 phai co trong
#      ui_ref; thieu anh thi he hat khong ve duoc gi ma cung khong bao loi.
#   B. PHEP DICH. Voi TUNG dinh nghia dang dung: tinh lai moi tham so o DAY,
#      tu chinh file JSON, bang cong thuc viet lai doc lap — roi doi chieu voi
#      cai ma ui/hat.gd dat vao vat lieu. Hai duong khac nhau phai ra cung so.
#      Phan quan trong nhat la THOI GIAN SONG: Godot rut mot phia, nen T = L+v
#      va r = 2v/(L+v) phai cho ra dung dai [L-v, L+v] cua Cocos (chan o 0).
#   C. BO CUC THAT. Dung mot man co hai node hat (UI_ArmyGroup_Campsite_Info)
#      va mot man co buttonbling, doi node phai la HatNode, co con ve, co neo
#      dung, va khong co node hat nao bi bo lai thanh Control rong.
#   D. LOP LUA. stopSystem/resetSystem (13 va 9 cho goi trong sc/) phai chay
#      duoc tu Lua va phai doi dung co emitting cua node that — day moi la
#      bang chung chung khong phai BONG.
#
# Bon khang dinh trong chu thich cua ui/hat.gd cung duoc kiem o day, de chung
# khong phai la cau chu: ca 33 dinh nghia deu duration < 0, deu rotationEnd ==
# rotationStart, deu L+v > 0, va khong kenh nao co mau 0 kem phuong sai.
extends SceneTree

const REF := "res://hat_ref/"
const LAYOUTS := "res://layout_ref/"
const KIEU := "CCParticleSystemQuad"
const EPS := 0.0001

## Bang doi chieu phep tron cua Cocos sang Godot (do tren 33 dinh nghia).
## Gia tri: ten hang so trong CanvasItemMaterial cua Godot.
const TRON := {
	Vector2i(770, 1): "ADD",              # 25 dinh nghia
	Vector2i(1, 771): "PREMULT_ALPHA",    # 5
	Vector2i(770, 771): "MIX",            # 1
	Vector2i(772, 1): "ADD",              # 1, XAP XI (Godot khong co DST_ALPHA)
	Vector2i(775, 1): "ADD",              # 1, XAP XI (khong co SRC_ALPHA_SATURATE)
}

var ok := 0
var bad := 0
## Man UI_ArmyGroup_Campsite_Info da dung o phan C, de phan D boc node THAT
## trong do (meta 'type_name' do chinh XggLayout._make dat, khong phai ta dat).
var _ui: Control = null


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


func _doc_json(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


## Moi node hat trong mot file bo cuc (bo qua file khong nhac toi no, cho nhanh).
func _node_hat_tat_ca() -> Array:
	var ra: Array = []
	var thu_muc := DirAccess.open(LAYOUTS)
	for ten in thu_muc.get_files():
		if not ten.ends_with(".json"):
			continue
		var chuoi := FileAccess.get_file_as_string(LAYOUTS + ten)
		if not chuoi.contains(KIEU):
			continue
		var d = JSON.parse_string(chuoi)
		if not (d is Dictionary):
			continue
		for r in (d.get("roots") as Array if d.get("roots") is Array else []):
			_gom_hat(r, ra)
	return ra


func _gom_hat(goc: Variant, ra: Array) -> void:
	if not (goc is Dictionary):
		return
	if String((goc as Dictionary).get("typeName", "")) == KIEU:
		ra.append(goc)
	var con = (goc as Dictionary).get("children")
	if con is Array:
		for c in con:
			_gom_hat(c, ra)


func _khoa(res: String) -> String:
	return HatNode.khoa_tu_res(res)


func _init() -> void:
	_kiem_du_lieu()
	var dung := _dinh_nghia_dang_dung()
	_kiem_dich(dung)
	_kiem_bo_cuc()
	_kiem_lua()
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# --- A. Du lieu -------------------------------------------------------------

func _kiem_du_lieu() -> void:
	print("=== A. du lieu hat ===")
	var idx := _doc_json(REF + "index.json")
	t("co index.json", not idx.is_empty())
	t("33 dinh nghia", idx.size() == 33, "ra %d" % idx.size())
	var thieu_tep := 0
	var thieu_anh := 0
	for k in idx:
		var muc: Dictionary = idx[k]
		if _doc_json(REF + String(muc.get("json", ""))).is_empty():
			thieu_tep += 1
		if not UiFrames.has_frame(String(muc.get("texture", ""))):
			thieu_anh += 1
			print("    thieu anh: %s -> %s" % [k, muc.get("texture", "")])
	t("moi dinh nghia co tep JSON", thieu_tep == 0, "thieu %d" % thieu_tep)
	t("moi dinh nghia co anh trong ui_ref", thieu_anh == 0, "thieu %d" % thieu_anh)

	var nodes := _node_hat_tat_ca()
	var khoa := {}
	var khong_dich := 0
	for nd in nodes:
		var k: String = _khoa(String(nd.get("res", "")))
		khoa[k] = true
		if not HatNode.co_hat(String(nd.get("res", ""))):
			khong_dich += 1
			print("    khong dich duoc: %s" % nd.get("res", ""))
	t("87 node hat trong bo cuc", nodes.size() == 87, "ra %d" % nodes.size())
	t("moi node hat tra ra dinh nghia", khong_dich == 0, "thieu %d" % khong_dich)
	t("7 dinh nghia duoc dung", khoa.size() == 7, "ra %d" % khoa.size())
	# Ten co duoi cach THAT trong du lieu goc: 74/87 node dung no.
	t("khoa giu nguyen duoi cach",
			_khoa("../map/buttonbling .plist") == "map/buttonbling "
			and HatNode.co_hat("../map/buttonbling .plist"))
	t("bo '../' va duoi .plist",
			_khoa("../png/particle/StarTrail.plist") == "png/particle/StarTrail")


## Cac dinh nghia ma bo cuc dung that, kem node dau tien dung no.
func _dinh_nghia_dang_dung() -> Array:
	var ra: Array = []
	var da := {}
	for nd in _node_hat_tat_ca():
		var res := String(nd.get("res", ""))
		var k: String = _khoa(res)
		if da.has(k):
			continue
		da[k] = true
		ra.append({"khoa": k, "res": res})
	return ra


# --- B. Phep dich -----------------------------------------------------------

func _gan(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func _mau(d: Dictionary, moc: String) -> Color:
	return Color(float(d.get(moc + "Red", 0.0)), float(d.get(moc + "Green", 0.0)),
			float(d.get(moc + "Blue", 0.0)), float(d.get(moc + "Alpha", 1.0)))


func _kiem_dich(dung: Array) -> void:
	print("=== B. phep dich (tinh lai o day) ===")
	var idx := _doc_json(REF + "index.json")
	# Bon khang dinh trong chu thich ui/hat.gd. Sai mot cai la co dinh nghia
	# roi vao nhanh ma ta KHONG dich (hoac chia cho 0) ma khong ai biet.
	var so_duration_am := 0
	var so_quay := 0
	var so_song_duong := 0
	var so_kenh_0 := 0
	for k in idx:
		var d := _doc_json(REF + String((idx[k] as Dictionary).get("json", "")))
		if float(d.get("duration", 1.0)) < 0.0:
			so_duration_am += 1
		if not _gan(float(d.get("rotationEnd", 0.0)), float(d.get("rotationStart", 0.0))):
			so_quay += 1
		if float(d.get("particleLifespan", 0.0)) + float(d.get("particleLifespanVariance", 0.0)) > 0.0:
			so_song_duong += 1
		for ch in ["Red", "Green", "Blue", "Alpha"]:
			if float(d.get("startColor" + ch, 0.0)) == 0.0 \
					and float(d.get("startColorVariance" + ch, 0.0)) != 0.0:
				so_kenh_0 += 1
	t("ca 33 dinh nghia co duration < 0 (khong co cua so phat huu han)",
			so_duration_am == 33, "ra %d" % so_duration_am)
	t("ca 33 dinh nghia co rotationEnd == rotationStart (hat khong quay)",
			so_quay == 0, "ra %d cai quay" % so_quay)
	t("ca 33 dinh nghia co L+v > 0", so_song_duong == 33, "ra %d" % so_song_duong)
	t("khong kenh mau nao la 0 kem phuong sai (khong chia cho 0)",
			so_kenh_0 == 0, "ra %d" % so_kenh_0)

	for muc in dung:
		_kiem_mot(muc["khoa"], muc["res"])


func _kiem_mot(khoa: String, res: String) -> void:
	var d := _doc_json(REF + String((_doc_json(REF + "index.json")[khoa] as Dictionary).get("json", "")))
	var n := HatNode.tao(res)
	if n == null or n.hat == null:
		t("%s: dung duoc node" % khoa, false)
		return
	var p := n.hat
	var pm := p.process_material as ParticleProcessMaterial
	t("%s: co vat lieu tien trinh" % khoa, pm != null)
	if pm == null:
		return

	var song := float(d.get("particleLifespan", 0.0))
	var sv := float(d.get("particleLifespanVariance", 0.0))
	var t_song := song + sv
	var r := clampf(2.0 * sv / t_song, 0.0, 1.0)
	# 1. Thoi gian song. Godot chi rut MOT phia, [T(1-r), T]; Cocos hai phia
	# [L-v, L+v]. Day la phep kiem noi dung cua phep dich, khong phai ten ham.
	t("%s: lifetime = L+v" % khoa, _gan(p.lifetime, t_song),
			"%.4f vs %.4f" % [p.lifetime, t_song])
	t("%s: r = 2v/(L+v)" % khoa, _gan(pm.lifetime_randomness, r),
			"%.4f vs %.4f" % [pm.lifetime_randomness, r])
	t("%s: dai thuc te = [L-v, L+v] chan 0" % khoa,
			_gan(p.lifetime * (1.0 - pm.lifetime_randomness), maxf(0.0, song - sv))
			and _gan(p.lifetime, song + sv))

	# 2. Phong: kich thuoc trong .plist la PIXEL cua anh goc, Godot phong theo
	# ti le -> nhan lai be rong anh phai ra dung so cua plist.
	var rong := float(p.texture.get_width())
	var s0 := float(d.get("startParticleSize", 0.0))
	var ssv := float(d.get("startParticleSizeVariance", 0.0))
	var s1 := float(d.get("finishParticleSize", 0.0))
	t("%s: scale_min/max = (s0 -+ sv)/be rong anh" % khoa,
			_gan(pm.scale_min * rong, s0 - ssv) and _gan(pm.scale_max * rong, s0 + ssv))
	var gt := pm.scale_curve as GradientTexture1D
	t("%s: scale_curve 1,0 -> s1/s0 (NHAN, khong phai cong)" % khoa,
			gt != null and _gan(gt.gradient.sample(1.0).r, s1 / s0 if s0 != 0.0 else 1.0))

	# 3. Luc: gravity cua Godot la gia toc pixel/giay^2 -> lat dau truc y.
	t("%s: gravity = (gx, -gy)" % khoa,
			_gan(pm.gravity.x, float(d.get("gravityx", 0.0)))
			and _gan(pm.gravity.y, -float(d.get("gravityy", 0.0))))
	# 4. Huong: goc Cocos do nguoc chieu kim dong ho voi y huong LEN.
	var a := float(d.get("angle", 0.0))
	var goc := rad_to_deg(atan2(pm.direction.y, pm.direction.x))
	t("%s: huong = -angle" % khoa, _gan(fposmod(goc, 360.0), fposmod(-a, 360.0)),
			"%.3f vs %.3f" % [goc, -a])
	t("%s: spread = angleVariance" % khoa,
			_gan(pm.spread, float(d.get("angleVariance", 0.0))))
	t("%s: van toc = speed -+ speedVariance" % khoa,
			_gan(pm.initial_velocity_min, float(d.get("speed", 0.0)) - float(d.get("speedVariance", 0.0)))
			and _gan(pm.initial_velocity_max, float(d.get("speed", 0.0)) + float(d.get("speedVariance", 0.0))))
	# 5. Hop phat: +-sourcePositionVariance (sourcePosition bi bo qua co chu y).
	t("%s: hop phat = +-phuong sai vi tri" % khoa,
			_gan(pm.emission_box_extents.x, absf(float(d.get("sourcePositionVariancex", 0.0))))
			and _gan(pm.emission_box_extents.y, absf(float(d.get("sourcePositionVariancey", 0.0)))))
	# 6. Xoay: hat khong quay (rotationEnd == rotationStart) nen goc la hang so.
	# Dau THAP truoc dau CAO: Godot kep lan nhau hai dau cua mot cap min/max
	# (dat min=30 roi max=-30 thi ra (-30,-30)) — ui/hat.gd dat theo thu tu do.
	var r0 := float(d.get("rotationStart", 0.0))
	var rv := float(d.get("rotationStartVariance", 0.0))
	t("%s: angle = -(rotationStart -+ variance), khong quay" % khoa,
			_gan(pm.angle_min, -(r0 + rv)) and _gan(pm.angle_max, -(r0 - rv))
			and _gan(pm.angular_velocity_min, 0.0) and _gan(pm.angular_velocity_max, 0.0),
			"min %.3f max %.3f" % [pm.angle_min, pm.angle_max])
	# 7. So hat va cac co.
	t("%s: amount = maxParticles (nhip phat = amount/lifetime)" % khoa,
			p.amount == maxi(int(d.get("maxParticles", 8.0)), 1))
	t("%s: local_coords (he hat theo node) va khong chay truoc" % khoa,
			p.local_coords and _gan(p.preprocess, 0.0) and not p.one_shot
			and _gan(p.explosiveness, 0.0) and _gan(p.randomness, 0.0))
	# 8. Mau: color TRANG, color_ramp tuyet doi, color_initial_ramp la he so.
	t("%s: color = trang (de phep nhan la mau goc)" % khoa, pm.color == Color.WHITE)
	var gr := pm.color_ramp as GradientTexture1D
	var m0 := gr.gradient.sample(0.0)
	var m1 := gr.gradient.sample(1.0)
	var e0 := _mau(d, "startColor")
	var e1 := _mau(d, "finishColor")
	t("%s: color_ramp = startColor -> finishColor" % khoa,
			_gan(m0.r, e0.r) and _gan(m0.g, e0.g) and _gan(m0.b, e0.b) and _gan(m0.a, e0.a)
			and _gan(m1.r, e1.r) and _gan(m1.g, e1.g) and _gan(m1.b, e1.b) and _gan(m1.a, e1.a))
	# He so nhan nguoc lai phai ra DUNG mau luc sinh, kem phan bi chan o 1,0
	# (mau hat cua Cocos di vao vertex colour dang byte nen bi chan).
	var gs := pm.color_initial_ramp as GradientTexture1D
	var hs0 := gs.gradient.sample(0.0)
	var hs1 := gs.gradient.sample(1.0)
	var dung_mau := true
	var kenh := {"Red": "r", "Green": "g", "Blue": "b", "Alpha": "a"}
	for ch in kenh:
		var m := float(d.get("startColor" + ch, 0.0))
		var v := float(d.get("startColorVariance" + ch, 0.0))
		var lo: float = hs0[kenh[ch]] * m
		var hi: float = hs1[kenh[ch]] * m
		if not (_gan(lo, clampf(m - v, 0.0, 1.0)) and _gan(hi, clampf(m + v, 0.0, 1.0))):
			dung_mau = false
	t("%s: he so mau nhan nguoc ra startColor -+ variance (chan 1,0)" % khoa, dung_mau)
	# 9. Phep tron dung bang doi chieu.
	var cap := Vector2i(int(d.get("blendFuncSource", 770)), int(d.get("blendFuncDestination", 1)))
	var vat := p.material as CanvasItemMaterial
	var mong: String = TRON.get(cap, "?")
	var co: String = ""
	if vat != null:
		match vat.blend_mode:
			CanvasItemMaterial.BLEND_MODE_ADD:
				co = "ADD"
			CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA:
				co = "PREMULT_ALPHA"
			CanvasItemMaterial.BLEND_MODE_MIX:
				co = "MIX"
	t("%s: phep tron (%d,%d) -> %s" % [khoa, cap.x, cap.y, mong], co == mong,
			"ra %s" % co)
	# Node nam trong cay bo cuc da dung o phan C, khong free o day.


# --- C. Bo cuc that ---------------------------------------------------------

func _tim(goc: Node, ten: String) -> Node:
	var ds: Array = [goc]
	while not ds.is_empty():
		var n: Node = ds.pop_back()
		if String(n.get_meta("xgg_name", "")) == ten:
			return n
		for c in n.get_children():
			ds.append(c)
	return null


func _co_hat_con(goc: Node) -> int:
	var ds: Array = [goc]
	var dem := 0
	while not ds.is_empty():
		var n: Node = ds.pop_back()
		if String(n.get_meta("type_name", "")) == KIEU:
			dem += 1
		for c in n.get_children():
			ds.append(c)
	return dem


func _kiem_bo_cuc() -> void:
	print("=== C. bo cuc that ===")
	# UI_ArmyGroup_Campsite_Info: hai node hat canh nhau, lua bat/tat chung o
	# CUIArmyGroupCampsite.lua:2627-2662 (lua trai / lua phai).
	var duong := LAYOUTS + "UI_ArmyGroup_Campsite_Info_960_640.json"
	var ui := XggLayout.build(duong)
	_ui = ui
	t("dung duoc UI_ArmyGroup_Campsite_Info", ui != null)
	if ui == null:
		return
	var nho := _tim(ui, "cpCampsFireSmall")
	var lon := _tim(ui, "cpCampsFireBig")
	t("co hai node hat theo ten", nho != null and lon != null)
	t("ca hai la HatNode", nho is HatNode and lon is HatNode)
	if nho is HatNode and lon is HatNode:
		t("nap dung dinh nghia",
				(nho as HatNode).hat != null and (lon as HatNode).hat != null)
		t("node hat la kind 'particle'", String(nho.get_meta("kind", "")) == "particle")
		# Neo: bo cuc ghi anchor 0,5 nen goc node Cocos nam giua o 40x40, va con
		# ve phai nam dung do. _process lam viec nay -> goi thang ra de kiem.
		nho.pivot_offset = Vector2(20, 20)
		nho._process(0.0)
		t("con ve nam tai goc node Cocos (neo)",
				(nho as HatNode).hat.position == Vector2(20, 20),
				"%s" % (nho as HatNode).hat.position)
		# Khong co node hat nao bi bo lai thanh Control rong.
		var tat_ca := _co_hat_con(ui)
		var that := _dem_hat_that(ui)
		t("moi node hat trong man deu dung duoc (khong co Control rong)",
				tat_ca == that, "%d node hat, %d hat that" % [tat_ca, that])

	# buttonbling: dinh nghia dung nhieu nhat (74/87 node) va co ten kem duoi
	# cach trong bo cuc.
	var ten_bb := ""
	var thu_muc := DirAccess.open(LAYOUTS)
	for ten in thu_muc.get_files():
		if not ten.ends_with(".json"):
			continue
		var chuoi := FileAccess.get_file_as_string(LAYOUTS + ten)
		if chuoi.contains("buttonbling"):
			ten_bb = ten
			break
	t("co bo cuc dung buttonbling", ten_bb != "")
	if ten_bb != "":
		var ui2 := XggLayout.build(LAYOUTS + ten_bb)
		var dem := _dem_hat_that(ui2)
		t("man buttonbling: moi node hat dung duoc",
				dem > 0 and dem == _co_hat_con(ui2),
				"%d hat that / %d node hat" % [dem, _co_hat_con(ui2)])


## Dem so node hat trong cay ma co con ve that.
func _dem_hat_that(goc: Node) -> int:
	var ds: Array = [goc]
	var dem := 0
	while not ds.is_empty():
		var n: Node = ds.pop_back()
		if n is HatNode and (n as HatNode).hat != null:
			dem += 1
		for c in n.get_children():
			ds.append(c)
	return dem


# --- D. Lop Lua -------------------------------------------------------------

func _kiem_lua() -> void:
	print("=== D. lop Lua ===")
	var lua := LuaRuntime.new()
	if not lua.open():
		t("mo Lua", false, ", ".join(lua.errors))
		return
	lua.run("require('bootstrap').install_cocos()", "cai cocos")
	# Boc node THAT trong bo cuc: lop duoc chon theo meta 'type_name' ma chinh
	# XggLayout._make dat (ui/xgg_layout.gd:319), nen day moi la duong that.
	var n := _tim(_ui, "cpCampsFireSmall") as HatNode
	t("lay duoc node hat tu bo cuc", n != null)
	if n == null:
		return
	lua.state.globals["_h"] = n
	lua.run("h = require('cocos').wrap(_h)", "boc node")
	# Lop phai duoc dang ky theo typeName — neu khong thi ba ham duoi day roi
	# vao __index cua Node, tra ve mot ham dem lai roi tra nil (khong bao loi).
	lua.run("h:stopSystem()", "stopSystem")
	t("Lua stopSystem -> emitting = false", n.hat.emitting == false)
	lua.run("h:resetSystem()", "resetSystem")
	t("Lua resetSystem -> emitting = true", n.hat.emitting == true)
	lua.run("_act = h:isActive()", "isActive")
	t("Lua isActive tra ve dung co phat", lua.state.globals["_act"] == true,
			"%s" % lua.state.globals["_act"])
	# Goc goi theo DUNG thu tu cua CPublic:playButtonParticleSystem.
	lua.run("h:stopSystem(); h:setIsVisible(true); h:resetSystem()", "theo CPublic")
	t("theo CPublic: bat lai thi phat", n.hat.emitting == true and n.visible)
	lua.run("h:setIsVisible(false); h:stopSystem()", "theo CPublic (tat)")
	t("theo CPublic: tat thi khong phat", n.hat.emitting == false and not n.visible)
	for e in lua.errors:
		print("  loi Lua: %s" % e)
	# Node nam trong cay bo cuc da dung o phan C, khong free o day.
