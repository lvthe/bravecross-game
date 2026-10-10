# Bon nhom API vua lam cua lop gia lap: doi thu dang hien cua mot xuong
# (`_lua_changeTextureDisplay` / `_lua_changeArmtureDisplay`), dong tac cua
# canh (`_Lua_changeWingAnimation`), tieng dong khi cham (`setSoundStrArr`), va
# vung cham rieng cua node (`setIsOpenDetection` +
# `pushDetectionAreaInPatentSpace`).
#
#   godot --headless --path . --script tools/verify_o_hien.gd
#
# Sau tang:
#   A. Doc thang `assets_ref/UIWoYaoShenJiang/UIWoYaoShenJiang.json` — bang
#      LIEN KET XUONG -> ANH cua chinh file ay. Day la phep do DOC LAP: no noi
#      xuong nao la ANH (`Dice3` -> `..._res-Num3`) va xuong nao la MOT BIEN THE
#      long nhau (`Light1` -> `UIWoYaoShenJiang_Base_Light`) — dung hai bang ay
#      la ly do ban goc co HAI ham rieng.
#   B. `rig/sng_rig.gd` — `o_hien`, `thay_o_hien`, `la_canh`, va canh
#      `EquipWing_11` voi nam dong tac cua no.
#   C. Duong Lua DUNG NHU CHO GOI THAT: `CUIShakeDice.lua:404-419` lat sau mat
#      xuc xac, va `CUIHeroInfoFightSoulUI.lua:1549` doi so cua bua vo hon.
#   D. `setSoundStrArr` + `setIsOpenDetection` + `pushDetectionAreaInPatentSpace`
#      di qua dung `LuaRuntime.touch_at` / `_trong_thuc`.
extends SceneTree

const MAN := "res://assets_ref/UIWoYaoShenJiang"
const TEP := MAN + "/UIWoYaoShenJiang.json"
const RIG_TEN := "UIWoYaoShenJiang"
## Bien the ma `SngRig._bien_the_cho("UIWoYaoShenJiang")` phai chon: ten thu muc
## khong phai ten bien the, nen no lui ve nhom NHIEU DONG TAC NHAT — va `Dice`
## la nhom duy nhat co 4 (ba nhom kia 2, bon nhom con lai 1).
const BIEN_THE := "UIWoYaoShenJiang_Dice"
## 25 bo phan trong khoi `parts` cua bien the ay (do tu file).
const SO_XUONG := 25
## Qua `getSpriteFromSpriteCatch` thi `_tao_rig` KHONG loc xuong `Layer*`, nen so
## xuong phai BANG dung duong truc tiep o tren. Truoc day hang so nay la 24 va
## phep kiem ghi lai "`LayerName000` bi bo" — do la LO HONG da ghi o CLAUDE.md
## ("armature hieu ung goi qua getSpriteFromSpriteCatch van di duong loc"), khong
## phai hanh vi dung. Bo loc da bo khoi duong Lua ngay 2026-09-18, nen hai duong
## nay khop va khong con hang so rieng: do la MOT su that, khong phai hai.
const DONG_TAC := ["Standby", "Play", "Play2", "Stop"]

const CANH_MAN := "res://assets_ref/EquipWing"
const CANH := "EquipWing_11"
## Nam dong tac cua `EquipWing_11`, kem so khung cua tung cai (do tu file).
const CANH_DONG_TAC := {"Standby": 39, "Run": 8, "Death": 13, "Fire": 8, "Hit": 5}
const CANH_XUONG := ["LayerName007", "LayerName006", "PlugIn_3", "PlugIn_2", "PlugIn_1"]

## Anh RONG dung de AN mot xuong: 4x4. Bang lien ket cua chinh file cho ca
## `PlugIn_1..6` lan `LayerName000` deu tro toi no — do la duong an cua ban goc,
## khong phai meo cua ban dung.
const ANH_AN := "UIWoYaoShenJiang_res-44"
const ANH_AN_CANH := 4

const _BOOT := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	boot.boot_goc()
	boot.init_config()
	g_CSceneManager.CurrentScene = 'Test'
	return true
"""

## Dung armature xuc xac qua DUNG duong cua ban goc, roi lat sau mat y nhu
## `CUIShakeDice.lua:399-424` — chep lai dung bieu thuc cua no
## (`"Dice"..i`, `"UIWoYaoShenJiang_res-Num" .. nPoints`, nhanh `nPoints == 6`).
##
## Bang diem `{1,2,3,4,5,6}` nen ca sau mat deu khac nhau VA mat thu 6 roi vao
## nhanh `== 6` — hai nhanh cua cho goi that deu duoc chay.
const _LUA_XUC_XAC := """
	local c = require('cocos')
	_G['_SAN'] = c.wrap(_root)
	local cha = c.new_node('layer')
	_SAN:addChild(cha)
	local sp = getSpriteFromSpriteCatch('UIWoYaoShenJiang')
	cha:addChild(sp)
	_G['_SP'] = sp

	local pAni = sp
	local tPoints = {1, 2, 3, 4, 5, 6}
	pAni:_Lua_playAnimation('Standby')
	for i = 1, 6 do
		local nPoints = tPoints[i]
		pAni:_lua_changeTextureDisplay('Dice'..i, 'UIWoYaoShenJiang_res-Num' .. nPoints, 0)
		if nPoints == 6 then
			pAni:_lua_changeArmtureDisplay('Light'..i, 'UIWoYaoShenJiang_Base_Light', 0)
			pAni:_lua_changeArmtureDisplay('Star'..i, 'UIWoYaoShenJiang_Base_Star', 0)
		else
			pAni:_lua_changeTextureDisplay('Light'..i, 'UIWoYaoShenJiang_res-44', 0)
			pAni:_lua_changeTextureDisplay('Star'..i, 'UIWoYaoShenJiang_res-44', 0)
		end
	end
	return 'xong'
"""

var _dat := 0
var _hong := 0
var _lua: LuaRuntime = null
var _san: Control = null


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


## So nguyen tu mot Variant bat ky, khong nem loi: bo dem cua `AmThanh` va
## bien toan cuc cua Lua deu ve day duoi dang Variant, ma `int(nil)` thi
## Godot nem "Nonexistent 'int' constructor" va lam dut ca phep kiem.
func _so(v: Variant) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v)
		TYPE_BOOL:
			return 1 if v else 0
	return 0


func _chay(ma: String, ten: String) -> Variant:
	var r = _lua.run(ma, ten)
	if r == null:
		_ghi_chu(false, "doan Lua '%s' hong: %s" % [ten, ", ".join(_lua.errors)])
	return r


## SngRig nam trong `n` (ke ca long nhieu tang).
func _rig_trong(n: Node) -> SngRig:
	for c in n.get_children():
		if c is SngRig:
			return c
		var r := _rig_trong(c)
		if r != null:
			return r
	return null


## Cac thu dang hien o o `idx` cua xuong — doc thang bang `displays` cua rig.
func _o(rig: SngRig, bone: String, idx: int) -> Node2D:
	if not rig.displays.has(bone):
		return null
	var ds: Array = rig.displays[bone]
	if idx >= ds.size():
		return null
	return ds[idx]


## Co `n` phai la Sprite2D dung co cua anh trong file khong.
func _la_anh(n: Node2D, w: int, h: int) -> bool:
	if not (n is Sprite2D):
		return false
	var t := (n as Sprite2D).texture
	return t != null and t.get_size() == Vector2(w, h)


## Ten bien the cua mot SngRig, hoac nhan dang node de ghi ra thong bao.
func _la_rig(n: Node2D, bien_the: String, so_xuong: int) -> bool:
	if not (n is SngRig):
		return false
	var r := n as SngRig
	if r.variant != bien_the:
		return false
	return so_xuong < 0 or r.bones.size() == so_xuong


func _ten(n: Node2D) -> String:
	if n == null:
		return "null"
	if n is SngRig:
		return (n as SngRig).variant
	return n.get_class()


func _init() -> void:
	_bang_so_lieu()
	_rig_dung_thang()
	var xong := await _duong_lua()
	if not xong:
		return
	await _cham_va_tieng()
	_cuoi()


# --- A. Bang so lieu cua chinh file -------------------------------------------------

## Doc thang khoi `parts` + `spriteFiles` + `groups` cua file .xml. Phep do nay
## khong dung toi `SngRig`: no tra loi "xuong nao la anh, xuong nao la bien the"
## bang chinh bang lien ket cua ban goc.
func _bang_so_lieu() -> void:
	print("A. %s — bang lien ket xuong -> anh cua chinh file:" % TEP)
	var d = JSON.parse_string(FileAccess.get_file_as_string(TEP))
	if typeof(d) != TYPE_DICTIONARY:
		_ghi_chu(false, "khong doc duoc %s" % TEP)
		quit(1)
		return
	var parts: Dictionary = {}
	for p in (d.get("parts", []) as Array):
		parts[String(p.get("name", ""))] = p.get("children", [])
	var sprite: Dictionary = d.get("spriteFiles", {})
	_ghi_chu(parts.size() == 8, "8 khoi <parts> (do duoc: %d)" % parts.size())
	_ghi_chu(sprite.size() == 50, "50 anh trong bang sprite (do duoc: %d)" % sprite.size())

	# Nhom nhieu dong tac nhat = Dice, va do la bien the ma ten thu muc se ra.
	var so_dong: Dictionary = {}
	for g in (d.get("groups", []) as Array):
		so_dong[String(g.get("variant", ""))] = (g.get("animations", []) as Array).size()
	var nhieu_nhat := ""
	var cao := -1
	for k in so_dong:
		if int(so_dong[k]) > cao:
			cao = int(so_dong[k])
			nhieu_nhat = String(k)
	_ghi_chu(nhieu_nhat == BIEN_THE and cao == DONG_TAC.size(),
			"nhom nhieu dong tac nhat = %s voi %d dong tac (do duoc %d)" % [BIEN_THE, DONG_TAC.size(), cao])

	# Hai bang PHAI roi nhau — do la ly do ban goc tach hai ham. Neu mot ten
	# nam o ca hai thi `_display_for` (uu tien anh) se im lang chon mot ben.
	var trung: Array = []
	for k in sprite:
		if parts.has(String(k)):
			trung.append(String(k))
	_ghi_chu(trung.is_empty(), "khong ten nao nam o CA hai bang%s"
			% ("" if trung.is_empty() else ": " + ", ".join(trung)))

	var xuong: Array = parts.get(BIEN_THE, [])
	_ghi_chu(xuong.size() == SO_XUONG, "%s co %d xuong (do duoc %d)"
			% [BIEN_THE, SO_XUONG, xuong.size()])
	# Sau mat: `Dice<i>` tro toi `..._res-Num<i>`, 93x93.
	var sai_mat: Array = []
	for i in range(1, 7):
		var ten := "Dice%d" % i
		var refs := _refs_cua(xuong, ten)
		var mong := "UIWoYaoShenJiang_res-Num%d" % i
		if refs != [mong]:
			sai_mat.append("%s=%s" % [ten, refs])
			continue
		var o: Dictionary = sprite.get(mong, {})
		if int(o.get("w", -1)) != 93 or int(o.get("h", -1)) != 93:
			sai_mat.append("%s -> %dx%d" % [mong, o.get("w", -1), o.get("h", -1)])
	_ghi_chu(sai_mat.is_empty(), "sau xuong `Dice1..6` tro toi dung sau anh Num1..6, moi anh 93x93%s"
			% ("" if sai_mat.is_empty() else ": " + ", ".join(sai_mat)))

	# Sau xuong `Light<i>` / `Star<i>` tro toi MOT BIEN THE khac trong cung file
	# — ten ay KHONG co trong bang sprite, chi co trong bang <parts>.
	var sai_long: Array = []
	for cap in [["Light", "UIWoYaoShenJiang_Base_Light"], ["Star", "UIWoYaoShenJiang_Base_Star"]]:
		for i in range(1, 7):
			var refs := _refs_cua(xuong, "%s%d" % [cap[0], i])
			if refs != [cap[1]]:
				sai_long.append("%s%d=%s" % [cap[0], i, refs])
				continue
			if sprite.has(String(cap[1])):
				sai_long.append("%s nam o CA bang sprite" % cap[1])
			elif not parts.has(String(cap[1])):
				sai_long.append("%s khong phai bien the nao" % cap[1])
	_ghi_chu(sai_long.is_empty(),
			"12 xuong `Light1..6` / `Star1..6` tro toi hai BIEN THE long nhau (khong phai anh)%s"
			% ("" if sai_long.is_empty() else ": " + ", ".join(sai_long)))

	# Duong AN xuong cua ban goc: `PlugIn_1..6` va `LayerName000` deu tro toi
	# anh 4x4 rong — cung anh ma `CUIShakeDice.lua:418,419` dung de an o sang.
	var toi_an: Array = []
	for ten in ["PlugIn_1", "PlugIn_2", "PlugIn_3", "PlugIn_4", "PlugIn_5", "PlugIn_6",
			"LayerName000"]:
		if _refs_cua(xuong, ten) == [ANH_AN]:
			toi_an.append(ten)
	var o_an: Dictionary = sprite.get(ANH_AN, {})
	_ghi_chu(toi_an.size() == 7 and int(o_an.get("w", -1)) == ANH_AN_CANH
			and int(o_an.get("h", -1)) == ANH_AN_CANH,
			"7 xuong tro toi anh an %s (%dx%d) — do la duong AN cua ban goc (do duoc %d xuong)"
			% [ANH_AN, o_an.get("w", -1), o_an.get("h", -1), toi_an.size()])


func _refs_cua(xuong: Array, ten: String) -> Array:
	for c in xuong:
		if String(c.get("name", "")) == ten:
			return c.get("sprites", [])
	return []


# --- B. SngRig dung thang -----------------------------------------------------------

func _rig_dung_thang() -> void:
	print("\nB. rig/sng_rig.gd — `o_hien` / `thay_o_hien` / `la_canh`:")
	var nen := Node2D.new()
	root.add_child(nen)

	# `hide_clutter = false` (giong `o_hien` khi no dung rig long nhau): giu du
	# 25 xuong, ke ca `LayerName000`.
	var rig := SngRig.build(MAN, "", false)
	if rig == null:
		_ghi_chu(false, "khong dung duoc %s" % RIG_TEN)
		quit(1)
		return
	nen.add_child(rig)
	_ghi_chu(rig.variant == BIEN_THE, "bien the = %s (ten thu muc khong phai bien the)"
			% rig.variant)
	_ghi_chu(rig.bones.size() == SO_XUONG, "%d xuong (bang so lieu: %d) — khong loc `Layer*`"
			% [rig.bones.size(), SO_XUONG])
	# So sanh theo TAP, khong theo thu tu: `AnimationPlayer.get_animation_list()`
	# tra ten da xep chu (Play, Play2, Standby, Stop), con bang trong file giu
	# thu tu tac gia viet.
	var ten_dong: Array = []
	for a in rig.animations():
		ten_dong.append(String(a))
	var xep_truoc := DONG_TAC.duplicate()
	xep_truoc.sort()
	ten_dong.sort()
	_ghi_chu(ten_dong == xep_truoc, "4 dong tac cua bien the (khong ke thu tu): %s" % [ten_dong])
	_ghi_chu(rig.missing_sprites.is_empty(), "khong thieu anh nao%s"
			% ("" if rig.missing_sprites.is_empty() else ": " + ", ".join(rig.missing_sprites)))
	_ghi_chu(rig.nested_rigs.size() == 12,
			"12 xuong tro toi rig long nhau (6 Light + 6 Star; do duoc %d)" % rig.nested_rigs.size())

	# Rig da dung san: hai bang phai di dung hai duong — day la phep kiem
	# `_display_for` bang chinh cay node, khong phai bang ham goi tay.
	_ghi_chu(_la_anh(_o(rig, "Dice3", 0), 93, 93), "xuong `Dice3` hien ANH 93x93")
	_ghi_chu(_la_anh(_o(rig, "LayerName000", 0), ANH_AN_CANH, ANH_AN_CANH),
			"xuong `LayerName000` hien anh an 4x4")
	var l3 := _o(rig, "Light3", 0)
	_ghi_chu(_la_rig(l3, "UIWoYaoShenJiang_Base_Light", 2),
			"xuong `Light3` hien MOT RIG LONG NHAU '%s' co 2 xuong" % _ten(l3))
	var s1 := _o(rig, "Star1", 0)
	_ghi_chu(_la_rig(s1, "UIWoYaoShenJiang_Base_Star", 5),
			"xuong `Star1` hien MOT RIG LONG NHAU '%s' co 5 xuong" % _ten(s1))
	# Xuong `PlugIn_*` la DIEM GAN (Marker2D) nen khong dung thu hien nao —
	# `CUIShakeDice.lua:431` goi vao no nhung dong ay bi chu thich.
	_ghi_chu(rig.bones["PlugIn_1"] is Marker2D and (rig.displays["PlugIn_1"] as Array).is_empty(),
			"`PlugIn_1` la diem gan, danh sach hien RONG (van thay duoc, xem duoi)")

	# `o_hien` goi tay: ten anh -> Sprite2D; ten bien the -> SngRig; va hai
	# bang roi nhau nen moi ben tra null cho ten cua ben kia.
	_ghi_chu(_la_anh(rig.o_hien("UIWoYaoShenJiang_res-zuozi", "Dice1", true), 1225, 340),
			"o_hien(ten ANH) dung anh theo TEN, khong theo xuong (1225x340)")
	var ln := rig.o_hien("UIWoYaoShenJiang_Base_Star", "Star2", false)
	_ghi_chu(_la_rig(ln, "UIWoYaoShenJiang_Base_Star", 5)
			and not (ln as SngRig).animations().is_empty(),
			"o_hien(ten BIEN THE) dung rig long nhau va da phat dong tac dau")
	_ghi_chu(rig.o_hien("UIWoYaoShenJiang_res-Num5", "Dice3", false) == null,
			"ten ANH di duong BIEN THE: null — hai bang roi nhau")
	_ghi_chu(rig.o_hien("UIWoYaoShenJiang_Base_Light", "Light1", true) == null,
			"ten BIEN THE di duong ANH: null — hai bang roi nhau")
	_ghi_chu(rig.o_hien("khong-co-ten-nay", "Dice1", true) == null
			and rig.o_hien("khong-co-ten-nay", "Dice1", false) == null,
			"ten la: ca hai duong deu null")
	if ln != null:
		ln.free()

	# `thay_o_hien`: THAY phan tu `idx`, khong them phan tu moi.
	var cu := _o(rig, "Dice3", 0)
	var moi := rig.o_hien("UIWoYaoShenJiang_res-Num5", "Dice3", true)
	_ghi_chu(rig.thay_o_hien("Dice3", moi, 0), "thay_o_hien('Dice3', anh, 0) tra true")
	_ghi_chu((rig.displays["Dice3"] as Array).size() == 1,
			"danh sach hien VAN 1 phan tu — THAY chu khong THEM (%d)"
			% (rig.displays["Dice3"] as Array).size())
	_ghi_chu(not is_instance_valid(cu) or cu.get_parent() == null,
			"thu CU da bi rut khoi xuong")
	_ghi_chu(moi.get_parent() == (rig.bones["Dice3"] as Node), "thu MOI la con cua xuong `Dice3`")
	_ghi_chu(moi.visible, "thu MOI dang hien")
	_ghi_chu(_o(rig, "Dice3", 0) == moi, "o 0 cua `Dice3` nay la thu moi")

	# Chinh duong ma ma goc di: khung chon o bang chi so `d`, va `_dat_khung`
	# chinh la ham ma duong phuong thuc cua dong tac goi. Sau khi thay o, dong
	# tac chay tiep PHAI lay dung thu vua thay — do la ca y nghia cua phep thay.
	rig.play("Standby")
	await process_frame
	_ghi_chu(_o(rig, "Dice3", 0) == moi and moi.visible,
			"dong tac 'Standby' (khung dau, d = 0) hien dung thu VUA THAY")

	# Duong AN: `thay_o_hien(bone, null, idx)` — `CUIShakeDice.lua` khong dung,
	# nhung do la doi so null cua chinh ham ay.
	_ghi_chu(rig.thay_o_hien("Dice3", null, 0) and _o(rig, "Dice3", 0) == null,
			"thay bang null: o do thanh RONG")
	_ghi_chu((rig.bones["Dice3"] as Node).get_child_count() == 0, "xuong `Dice3` khong con con nao")

	# O vuot bang thi NOI RONG bang null (khac `_dat_khung` — ham do coi chi so
	# ngoai bang la 0). Chi so am / xuong la thi bo qua, khong nem loi.
	var xa := rig.o_hien("UIWoYaoShenJiang_res-Num6", "Dice3", true)
	_ghi_chu(rig.thay_o_hien("Dice3", xa, 5) and (rig.displays["Dice3"] as Array).size() == 6,
			"o 5 cua bang 1 phan tu: NOI RONG thanh 6")
	var hien := 0
	for i in 6:
		if _o(rig, "Dice3", i) != null and _o(rig, "Dice3", i).visible:
			hien += 1
	_ghi_chu(hien == 1 and xa.visible, "chi o 5 hien, cac o khac an (%d o hien)" % hien)
	_ghi_chu(not rig.thay_o_hien("Dice3", xa, -1), "chi so am: tra false")
	_ghi_chu(not rig.thay_o_hien("khong-co-xuong", xa, 0), "xuong la: tra false")
	# `PlugIn_*` la diem gan nen danh sach hien RONG — nhung `thay_o_hien` van
	# dung duoc (no NOI RONG bang null), dung nhu dong bi chu thich o
	# `CUIShakeDice.lua:431`.
	var vao_plug := rig.o_hien("UIWoYaoShenJiang_res-Num1", "PlugIn_1", true)
	_ghi_chu(rig.thay_o_hien("PlugIn_1", vao_plug, 0)
			and (rig.displays["PlugIn_1"] as Array).size() == 1,
			"`PlugIn_1` (diem gan, danh sach RONG) van thay duoc o 0")

	# Canh: armature RIENG, khong phai mot xuong cua nhan vat.
	_ghi_chu(not rig.la_canh(), "armature xuc xac KHONG phai canh")
	var canh := SngRig.build(CANH_MAN, CANH, false)
	if canh == null:
		_ghi_chu(false, "khong dung duoc %s" % CANH)
		return
	nen.add_child(canh)
	_ghi_chu(canh.la_canh() and canh.variant == CANH, "`%s` LA canh" % canh.variant)
	_ghi_chu(canh.bones.size() == CANH_XUONG.size(),
			"%d xuong: %s" % [canh.bones.size(), CANH_XUONG])
	var thieu: Array = []
	var sai: Array = []
	for t in CANH_DONG_TAC:
		if not canh.play(String(t)):
			thieu.append(String(t))
			continue
		# So khung doc tu file phai khop do dai dong tac — 24 khung/giay.
		if not is_equal_approx(canh.thoi_luong(String(t)),
				float(CANH_DONG_TAC[t]) / SngRig.FPS):
			sai.append("%s=%f" % [t, canh.thoi_luong(String(t))])
	_ghi_chu(thieu.is_empty(), "phat duoc CA NAM dong tac cua canh%s"
			% ("" if thieu.is_empty() else " (thieu %s)" % ", ".join(thieu)))
	_ghi_chu(sai.is_empty(), "do dai dung so khung cua file (%s)%s"
			% ["39/8/13/8/5 khung", "" if sai.is_empty() else ": " + ", ".join(sai)])
	# Hai ten ma `CUIArmyGroupCampsite.lua:1797,1799` truyen vao.
	_ghi_chu(canh.play("Death") and canh.player.current_animation == "Death",
			"phat 'Death' — ten cho goi that truyen vao")
	_ghi_chu(canh.play("Standby") and canh.player.current_animation == "Standby",
			"phat 'Standby' — ten cho goi that truyen vao")
	_ghi_chu(not canh.play("khong-co"), "dong tac la: tra false")


# --- C. Duong Lua, dung nhu cho goi that -------------------------------------------

func _duong_lua() -> bool:
	print("\nC. lua/cocos.lua — cho goi that `CUIShakeDice.lua:399-424`:")
	var lua := LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not lua.open():
		print("KHONG mo duoc Lua: %s" % ", ".join(lua.errors))
		quit(1)
		return false
	_lua = lua
	_san = Control.new()
	_san.size = lua.cua_so_engine
	lua.set_stage(_san)
	lua.set_touch_root(_san)
	root.add_child(_san)
	lua.bind_layout(_san)
	lua.set_ui_root(_san)
	if lua.run(_BOOT, "boot") == null:
		print("boot hong: %s" % ", ".join(lua.errors))
		quit(1)
		return false

	var r = _chay(_LUA_XUC_XAC, "xuc xac")
	if r == null or String(r) != "xong":
		_ghi_chu(false, "khong chay duoc duong xuc xac cua ban goc")
		quit(1)
		return false

	var hop := _san.get_child(0).get_child(0) as Control
	if hop == null:
		_ghi_chu(false, "`getSpriteFromSpriteCatch` khong tra node")
		quit(1)
		return false
	var rig := _rig_trong(hop)
	if rig == null:
		_ghi_chu(false, "node xuc xac khong co rig")
		quit(1)
		return false
	_ghi_chu(rig.variant == BIEN_THE, "getSpriteFromSpriteCatch('%s') ra bien the %s"
			% [RIG_TEN, rig.variant])
	_ghi_chu(rig.bones.size() == SO_XUONG,
			"qua duong Lua: %d xuong — BANG duong truc tiep (bang so lieu %d), khong loc `Layer*`"
			% [rig.bones.size(), SO_XUONG])

	# Sau mat: `Dice<i>` -> anh Num<diem>, 93x93.
	var sai: Array = []
	for i in range(1, 7):
		var o := _o(rig, "Dice%d" % i, 0)
		if not _la_anh(o, 93, 93):
			sai.append("Dice%d" % i)
	_ghi_chu(sai.is_empty(), "sau o mat `Dice1..6` deu la ANH 93x93%s"
			% ("" if sai.is_empty() else " (hong %s)" % ", ".join(sai)))

	# Nam mat dau: `Light<i>` / `Star<i>` bi thay bang anh an 4x4 — day la duong
	# AN cua ban goc, va no THAY the rig long nhau cu.
	var an_sai: Array = []
	for i in range(1, 6):
		for t in ["Light", "Star"]:
			if not _la_anh(_o(rig, "%s%d" % [t, i], 0), ANH_AN_CANH, ANH_AN_CANH):
				an_sai.append("%s%d" % [t, i])
	_ghi_chu(an_sai.is_empty(), "10 o `Light1..5` / `Star1..5` thanh anh an 4x4%s"
			% ("" if an_sai.is_empty() else " (hong %s)" % ", ".join(an_sai)))

	# Mat thu 6: nhanh `nPoints == 6` tra hai o ay ve RIG LONG NHAU.
	var l6 := _o(rig, "Light6", 0)
	var s6 := _o(rig, "Star6", 0)
	_ghi_chu(_la_rig(l6, "UIWoYaoShenJiang_Base_Light", 2),
			"`Light6` (mat 6) la rig long nhau Base_Light")
	_ghi_chu(_la_rig(s6, "UIWoYaoShenJiang_Base_Star", 5),
			"`Star6` (mat 6) la rig long nhau Base_Star")
	# `is_inside_tree()` / `get_tree()` KHONG do duoc trong bo do nay: `_san` duoc
	# gan vao `SceneTree.root`, ma chinh root ay bao `is_inside_tree() == false`
	# va `get_tree() == null` (no LA goc cua cay, khong bao gio nhan
	# ENTER_TREE) — nen MOI node cua cay deu bao y nhu vay (do duoc: ca bay tang
	# tu `Light6` len `root` deu false). Kiem thang phep GAN: o `Light6` phai la
	# cha cua rig vua thay, va o do dang hien.
	var xuong_l6: Node2D = rig.bones.get("Light6")
	_ghi_chu(l6 is SngRig and xuong_l6 != null and l6.get_parent() == xuong_l6
			and l6.visible and xuong_l6.get_children().has(l6),
			"rig long nhau vua thay duoc GAN vao o `Light6` va dang hien")

	# Doi so cua bua vo hon (`CUIHeroInfoFightSoulUI.lua:2673-2674`,
	# `:3282-3283`, va ban bi chu thich `:1548-1549`): ten xuong `Number`, ten
	# anh `UIZhuangBeiWuHun_Res-<lv>00T`.
	#
	# Ten truyen vao la TEN BIEN THE — `UIZhuangBeiWuHun_CuiZhi` — chu khong
	# phai ten thu muc. Do la diem phan biet that: xem phep do ngay duoi.
	var bua = _chay("""
		local sp = getSpriteFromSpriteCatch('UIZhuangBeiWuHun_CuiZhi')
		_SAN:addChild(sp)
		sp:_Lua_playAnimation('Play')
		return tostring(sp:_lua_changeTextureDisplay('Number', 'UIZhuangBeiWuHun_Res-300T', 0))
	""", "bua vo hon")
	await process_frame
	_ghi_chu(bua != null and String(bua) == "0", "doi so tra ve 0 nhu than ham ban goc (%s)" % bua)
	var rig_bua := _rig_trong(_san.get_child(_san.get_child_count() - 1))
	if rig_bua == null:
		_ghi_chu(false, "khong dung duoc armature cua bua vo hon")
	else:
		# Bang lien ket cua chinh file: xuong `Number` cua bien the `_CuiZhi`
		# tro toi `Res-100T` (87x27), con anh doi vao la `Res-300T` (93x27). Do
		# la mot phep phan biet that: neu o do khong bi thay thi co anh 87x27.
		var o_so := _o(rig_bua, "Number", 0)
		_ghi_chu(_la_anh(o_so, 93, 27),
				"xuong `Number` doi sang ANH 93x27 (`Res-300T`)%s"
				% ("" if _la_anh(o_so, 93, 27) else ": " + _ten(o_so)))
		var ten_xuong: Array = []
		for k in rig_bua.bones:
			ten_xuong.append(String(k))
		_ghi_chu(String(rig_bua.variant) == "UIZhuangBeiWuHun_CuiZhi"
				and ten_xuong == ["Hammer", "Number"],
				"ten bien the va hai xuong dung nhu file: %s %s"
				% [rig_bua.variant, ten_xuong])

	# DO RONG: ten THU MUC (`UIZhuangBeiWuHun`) khong phai mot bien the, nen
	# `_bien_the_cho` lui ve nhom nhieu dong tac nhat — `UIZhuangBeiWuHun_WuHun`
	# (Born/Move/Death) — ma xuong cua nhom ay ten `LayerName*` het.
	#
	# Truoc 2026-09-18 phep kiem nay doi rig ra **0 xuong** va `rig_rong` dem duoc
	# 1: do la LO HONG da ghi o CLAUDE.md ("armature hieu ung goi qua
	# getSpriteFromSpriteCatch van di duong loc") — bo loc `Layer*` an sach mot
	# armature hieu ung THAT. Nay bo loc da bo khoi duong Lua, nen cho nay doi
	# thanh: rig phai CO xuong, va `rig_rong` KHONG duoc dem mot rig rong khong co
	# that. Hai ve deu la su that do duoc tu file: `UIZhuangBeiWuHun_WuHun` co
	# dung hai xuong `LayerName000` / `LayerName001` (khong phai anh — chung hien
	# cac bien the long nhau `Base_WuHun` / `Base_Star`).
	var rong = _chay("""
		local sp = getSpriteFromSpriteCatch('UIZhuangBeiWuHun')
		_SAN:addChild(sp)
		return 'xong'
	""", "ten thu muc")
	var rig_rong := _rig_trong(_san.get_child(_san.get_child_count() - 1)) if rong != null else null
	var xuong_rong: Array = []
	if rig_rong != null:
		for k in rig_rong.bones:
			xuong_rong.append(String(k))
	_ghi_chu(rig_rong != null and xuong_rong == ["LayerName001", "LayerName000"]
			and not _lua.rig_rong.has("UIZhuangBeiWuHun"),
			"ten THU MUC (khong phai bien the) -> nhom `_WuHun` -> 2 xuong `LayerName*` (do duoc %s), va `rig_rong` KHONG dem (co ten trong bo dem: %s)"
			% [str(xuong_rong), str(_lua.rig_rong.has("UIZhuangBeiWuHun"))])

	# Ten khong co trong bang: thay bang null (AN o do), khong nem loi. Ghi lai
	# dung hanh vi dang co — y nghia cua no o ban goc KHONG do duoc.
	var la = _chay("""
		local sp = _G['_SP']
		sp:_lua_changeTextureDisplay('khong-co-xuong', 'khong-co-anh', 0)
		return tostring(sp:_lua_changeTextureDisplay('Dice1', 'UIWoYaoShenJiang_res-Num1', 0))
	""", "ten la")
	_ghi_chu(la != null and String(la) == "0", "xuong la / anh la: tra 0, khong nem loi (%s)" % la)
	_ghi_chu(_lua.errors.is_empty(), "khong co loi Lua%s"
			% ("" if _lua.errors.is_empty() else ": " + ", ".join(_lua.errors)))
	return true


# --- D. Vung cham + tieng dong ------------------------------------------------------

func _cham_va_tieng() -> void:
	print("\nD. lua/cocos.lua + game/lua_runtime.gd — vung cham rieng va tieng dong:")
	# Cay: cha o (30,20) co 200x100; con o (100,50) co 50x50. Vung cham tinh
	# trong HE CUA CHA (`CampsiteActiveArea` cua ban goc), va bon so la HAI GOC
	# DOI NHAU — nen mot vung (0,0)-(60,60) cua cha chua duoc diem canvas
	# (40,70) [= (10,50) trong he cha, y lat thanh 50] nhung KHONG chua diem ay
	# trong he cua chinh con.
	var cha := Control.new()
	cha.position = Vector2(30, 20)
	cha.size = Vector2(200, 100)
	var con := Control.new()
	con.position = Vector2(100, 50)
	con.size = Vector2(50, 50)
	_san.add_child(cha)
	cha.add_child(con)
	_lua.state.globals["_CHA"] = cha
	_lua.state.globals["_CON"] = con

	# Bat + mot vung, bang DUNG API cua ban goc (khong dat meta tay).
	var r = _chay("""
		local c = require('cocos')
		local con = c.wrap(_G['_CON'])
		con:setIsOpenDetection(true, 10, 4)
		con:pushDetectionAreaInPatentSpace(0, 0, 60, 60)
		local gd = c.raw(con)
		return table.concat({
			tostring(gd:get_meta('cham_mo')),
			tostring(gd:get_meta('cham_so_1')),
			tostring(gd:get_meta('cham_so_2')),
		}, ',')
	""", "vung cham")
	_ghi_chu(r != null and String(r) == "true,10,4",
			"hai so nguyen cua ban goc duoc giu NGUYEN (10, 4) — khong suy dien gi tu chung (%s)" % r)

	# Diem nam trong vung khi do theo HE CHA, nhung NGOAI o cua chinh node —
	# phep kiem phan biet duoc "he cha" voi "he node".
	var p_trong := Vector2(40, 70)
	_ghi_chu(LuaRuntime._trong_thuc(con, p_trong),
			"diem (40,70): trong vung theo HE CHA -> true")
	_ghi_chu(not LuaRuntime._trung(con, p_trong),
			"cung diem ay NGOAI o cua chinh node -> `_trung` false (hai phep kiem KHAC nhau)")
	_ghi_chu(not LuaRuntime._trong_thuc(con, Vector2(95, 95)),
			"diem (95,95): ngoai vung -> false")

	# Doi thu tu hai goc: ban goc luu bon so tho, nen phai ra ket qua y nguyen.
	var doi = _chay("""
		local c = require('cocos')
		local con = c.wrap(_G['_CON'])
		con:pushDetectionAreaInPatentSpace(60, 60, 0, 0)
		return 'xong'
	""", "goc doi")
	_ghi_chu(doi != null and LuaRuntime._trong_thuc(con, p_trong),
			"day them vung voi HAI GOC DOI NHAU (60,60)-(0,0): van true")

	# Tat co: ban goc XOA danh sach vung, nen phep thu quay ve o cua node.
	var p_o_con := Vector2(140, 80)
	_ghi_chu(LuaRuntime._trung(con, p_o_con), "diem (140,80) nam TRONG o cua con")
	var tat = _chay("""
		local c = require('cocos')
		local con = c.wrap(_G['_CON'])
		con:setIsOpenDetection(false, 10, 4)
		return tostring(c.raw(con):has_meta('vung_cham'))
	""", "tat co")
	_ghi_chu(tat != null and String(tat) == "false", "tat co: danh sach vung bi XOA")
	_ghi_chu(LuaRuntime._trong_thuc(con, p_o_con) == LuaRuntime._trung(con, p_o_con)
			and LuaRuntime._trong_thuc(con, p_o_con),
			"tat co roi thi phep thu quay ve o cua node (true tai (140,80))")
	_ghi_chu(not LuaRuntime._trong_thuc(con, p_trong),
			"diem ngoai o cua node: false, dung nhu khong he bat co")

	# Bat co ma KHONG day vung nao: ban goc duyet mot vector rong -> false.
	var rong = _chay("""
		local c = require('cocos')
		local con = c.wrap(_G['_CON'])
		con:setIsOpenDetection(true, 9, 3)
		return tostring(c.raw(con):has_meta('vung_cham'))
	""", "rong")
	_ghi_chu(rong != null and String(rong) == "false" and not LuaRuntime._trong_thuc(con, p_o_con),
			"bat co nhung khong co vung nao: false ngay trong o cua node (vector rong)")

	# Node khong he goi hai ham ay: di nguyen duong `_trung`.
	var thuong := Control.new()
	thuong.position = Vector2(300, 300)
	thuong.size = Vector2(40, 40)
	_san.add_child(thuong)
	_ghi_chu(LuaRuntime._trong_thuc(thuong, Vector2(320, 320))
			and not LuaRuntime._trong_thuc(thuong, Vector2(10, 10)),
			"node khong bat co: di nguyen duong `_trung` (trong o true, ngoai o false)")

	# --- Tieng dong khi cham -------------------------------------------------------
	# Node cham that: ten cham + bang tieng + doi tuong nhan cham. Ca ba deu la
	# dieu kien cua ban goc — `M.cham` thoat NGAY (truoc khi phat tieng) khi
	# node khong co doi tuong nhan.
	var nut := Control.new()
	nut.position = Vector2(500, 500)
	nut.size = Vector2(100, 100)
	_san.add_child(nut)
	_lua.state.globals["_NUT"] = nut
	var im := Control.new()
	im.position = Vector2(700, 500)
	im.size = Vector2(100, 100)
	_san.add_child(im)
	_lua.state.globals["_IM"] = im
	var d = _chay("""
		local c = require('cocos')
		local nut = c.wrap(_G['_NUT'])
		nut:setLuaTouchName('T')
		nut:setSoundStrArr({'event:/UI/UI_Click', 'event:/UI/UI_Click2'})
		-- Than ham cua ban goc lam viec THAT (ghi vao chinh node nhan), chu khong
		-- chi tang mot bien Lua: `setTag` / `setStringTag` la API that cua Cocos
		-- va GDScript doc lai duoc ngay tren node. Hai pha ghi vao HAI o khac
		-- nhau nen biet chac pha nao chay MAY lan, va ca hai deu khong doi hinh
		-- hoc nen cu cham pha End van trung.
		--
		-- Dem bang bien Lua thi khong duoc: bien toan cuc ghi tu Lua doc nguoc ra
		-- la mot bang "bong" chu khong phai so (do duoc: `type(_G['_DEM'])` =
		-- `table`, va `string.format('%d', _G['_DEM'])` nem "number expected,
		-- got table"), nen bo dem phai nam BEN GODOT moi doc lai duoc.
		nut:setCallbackLuaObject({
			-- Chu ky cua ban goc: `goi_pha` goi ham NHU PHUONG THUC cua doi tuong
			-- (`pcall(f, obj, sender, ...)`), nen node nhan cham la tham so THU
			-- HAI — `onTouchBegin_<ten>(o, sender)`, `onTouchEnd_<ten>(o, sender,
			-- trong)`. Doc sai chu ky nay thi khong loi nao: `goi_pha` bat loi
			-- bang `pcall` roi ghi vao `nhat_ky_cham` nhu thuong (do duoc: mot
			-- loi `attempt to call method 'getStringTag'` khi goi nham vao bang).
			onTouchBegin_T = function(o, sender) sender:setTag((sender:getTag() or 0) + 1) end,
			onTouchEnd_T = function(o, sender, trong)
				sender:setStringTag(tostring((tonumber(sender:getStringTag()) or 0) + 1))
			end,
		})
		local im = c.wrap(_G['_IM'])
		im:setLuaTouchName('T')
		im:setSoundStrArr({'event:/UI/UI_Click'})
		return 'xong'
	""", "node cham")
	if d == null:
		return
	# Bang tieng phai doc duoc, neu khong thi "khong phat tieng" khong noi len
	# dieu gi. Do truoc: ten ay co trong bang cua ban goc khong.
	_ghi_chu(_lua.am.has_method("tra") and not _lua.am.tra("event:/UI/UI_Click").is_empty(),
			"ten tieng 'event:/UI/UI_Click' co trong bang cua ban goc")
	# Bo dem bat dau tu 0, dat tu day: mac dinh tag cua Cocos la -1
	# (`kCCNodeTagInvalid`), de mac dinh thi "chay mot lan" ra 0 va phep kiem doc
	# ra kho hon. Dat truoc khi cham thi `setTag` cua ban goc cong len dung 1.
	#
	# Bo dem pha END di qua `setStringTag`/`getStringTag` (chinh dong Lua o
	# `onTouchEnd_T`), nen cho DAT va cho DOC cung phai goi hai ham do — doc
	# thang meta la doc mot o khac: truoc day `setStringTag` ghi vao meta 'cls'
	# nen `nut.set_meta('cls', '0')` tinh co dung; nay `setStringTag` co o rieng
	# (xem lua/cocos.lua: getStringTag() tra ve 'res' cua ban ghi), va phep kiem
	# se bao 0 du ham da chay dung.
	nut.set_meta("tag", 0)
	_chay("""
		local c = require('cocos')
		c.wrap(_G['_NUT']):setStringTag('0')
		return 'xong'
	""", "dat bo dem stringTag")
	var truoc: int = _so(_lua.am.so_phat)
	var begin := _lua.touch_at("Begin", Vector2(550, 550))
	_ghi_chu(begin, "cham Begin vao node co ten cham: nuot cu cham")
	_ghi_chu(_so(nut.get_meta("tag", -1)) == 1,
			"ham `onTouchBegin_T` cua ban goc chay dung MOT lan, khong loi (tag=%s)"
			% nut.get_meta("tag", "-"))
	_ghi_chu(_so(_lua.am.so_phat) == truoc + 1,
			"tieng dong phat o pha BEGIN (%d -> %d)" % [truoc, _so(_lua.am.so_phat)])
	_ghi_chu(_so(_lua.am.so_khong_tra_duoc) == 0,
			"ten tieng tra duoc, khong roi vao `so_khong_tra_duoc`")
	# Pha End KHONG duoc phat lai: pha la DAT (xem chu thich o `setSoundStrArr`),
	# va phep kiem nay khoa lua chon ay lai de sau nay doi thi lo ra.
	var giua: int = _so(_lua.am.so_phat)
	# Pha End di qua node DA NHAN BEGIN (`_dang_cham`), khong di lai cay — va o
	# day `M.cuon` co ton tai (lop cuon cua bo cuc), nhung no KHONG cuop cu cham:
	# nhat ky cham chi co `onTouchEnd_T`, khong co `onTouchEndEx_T`.
	_lua.touch_at("End", Vector2(550, 550))
	_ghi_chu(_so(_lua.am.so_phat) == giua,
			"pha END khong phat lai tieng (%d -> %d)" % [giua, _so(_lua.am.so_phat)])
	var dem = _chay("""
		local c = require('cocos')
		return c.wrap(_G['_NUT']):getStringTag()
	""", "doc bo dem")
	_ghi_chu(String(dem) == "1",
			"ham `onTouchEnd_T` cua ban goc chay dung MOT lan (stringTag=%s)" % dem)
	var loi = _chay("""
		local c = require('cocos')
		return string.format('%d', #c.loi_cham)
	""", "loi cham")
	_ghi_chu(loi != null and String(loi) == "0", "khong ham cham nao nem loi (%s)" % loi)
	# Node co tieng + ten cham ma KHONG co doi tuong nhan: ban goc khong phat tieng.
	var truoc_im: int = _so(_lua.am.so_phat)
	_ghi_chu(not _lua.touch_at("Begin", Vector2(750, 550)),
			"node khong co doi tuong nhan cham: cu cham di tiep (tra false), khong nuot")
	_ghi_chu(_so(_lua.am.so_phat) == truoc_im,
			"node khong co doi tuong nhan: KHONG phat tieng (%d -> %d)"
			% [truoc_im, _so(_lua.am.so_phat)])

	# --- Canh: `_Lua_changeWingAnimation` -----------------------------------------
	# Duong GAN canh that la `setGear` -> `SngRig.dat_do` (kieu `node_con`), chay
	# khi mot man cua `sc/` gan canh (`CUIActivityScoreStroe.lua:25`,
	# `CUIWing.lua:1403`, `CUIWingShow.lua:248`). O day tu gan mot armature canh
	# vao cay con de phep kiem khong phu thuoc man nao. Kiem dung hai dieu: no voi
	# tới CANH, va no KHONG dung tới nhan vat.
	var canh = _chay("""
		local sp = _G['_SP']
		local canh = getSpriteFromSpriteCatch('EquipWing_11')
		sp:addChild(canh)
		local ra = {}
		ra[#ra + 1] = tostring(sp:_Lua_changeWingAnimation('Death'))
		ra[#ra + 1] = tostring(sp:_Lua_changeWingAnimation('khong-co'))
		return table.concat(ra, ',')
	""", "canh")
	await process_frame
	_ghi_chu(canh != null and String(canh) == "true,false",
			"doi dong tac canh: 'Death' ra true, ten la ra false (%s)" % canh)
	# Node canh la con CUOI cua node nhan vat; rig cua no nam trong do.
	var hop_nv := _san.get_child(0).get_child(0)
	var hop_canh := hop_nv.get_child(hop_nv.get_child_count() - 1)
	var rig_canh := _rig_trong(hop_canh)
	_ghi_chu(rig_canh != null and rig_canh.la_canh(),
			"node canh vua them dung la armature canh '%s'" % _ten(rig_canh))
	_ghi_chu(rig_canh != null and rig_canh.player.current_animation == "Death",
			"CANH dang chay 'Death'%s"
			% ("" if rig_canh == null else ": " + String(rig_canh.player.current_animation)))
	# Nhan vat thi KHONG bi dung toi: `_Lua_changeWingAnimation` di tim canh
	# chu khong doi dong tac cua chinh nhan vat.
	var rig_nv := _rig_trong(hop_nv)
	_ghi_chu(rig_nv != null and not rig_nv.la_canh()
			and rig_nv.player.current_animation == "Standby",
			"rig cua NHAN VAT khong phai canh va VAN dang 'Standby'%s"
			% ("" if rig_nv == null else ": " + String(rig_nv.player.current_animation)))
	# Truong hop that trong ban dung: khong co canh nao trong cay.
	var khong = _chay("""
		local c = require('cocos')
		local n = c.new_node('layer')
		_SAN:addChild(n)
		return tostring(n:_Lua_changeWingAnimation('Death'))
	""", "khong co canh")
	_ghi_chu(khong != null and String(khong) == "false",
			"khong co canh trong cay: tra false, im lang — dung nhanh `if (w)` NULL cua ban goc (0x417fea)")


func _cuoi() -> void:
	# Sau ten ham phai co THAT trong bang `Node`: neu khong thi chung roi vao
	# `__index` va bi dem vao `M.missing` — khong mot loi nao, chi la API khong
	# bao gio chay.
	var miss := _lua.missing()
	for ten in ["_lua_changeTextureDisplay", "_lua_changeArmtureDisplay",
			"_Lua_changeWingAnimation", "setSoundStrArr", "setIsOpenDetection",
			"pushDetectionAreaInPatentSpace"]:
		_ghi_chu(not miss.has(ten), "`%s` khong nam trong bo dem M.missing%s"
				% [ten, "" if not miss.has(ten) else " (%d lan goi)" % miss[ten]])
	var thieu: Array = []
	for ten in _lua.rig_thieu:
		if String(ten) == RIG_TEN or String(ten) == CANH:
			thieu.append(String(ten))
	_ghi_chu(thieu.is_empty(), "khong armature nao cua phep kiem bi ghi vao rig_thieu%s"
			% ("" if thieu.is_empty() else ": " + ", ".join(thieu)))
	var rong: Array = []
	for ten in _lua.rig_rong:
		if String(ten) == RIG_TEN or String(ten) == CANH:
			rong.append(String(ten))
	_ghi_chu(rong.is_empty(), "khong armature nao cua phep kiem dung ra RONG (0 xuong)%s"
			% ("" if rong.is_empty() else ": " + ", ".join(rong)))
	_ghi_chu(_lua.errors.is_empty(), "khong co loi Lua%s"
			% ("" if _lua.errors.is_empty() else ": " + ", ".join(_lua.errors)))
	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)
