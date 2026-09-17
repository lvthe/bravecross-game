# Do BONG (shadow) cua armature: `_ShowShadow` / `_SetSyncShadowPosY` /
# `_UpdateShadowPosY`.
#
#   godot --headless --path . --script tools/verify_bong.gd
#
# Ba ham nay co 23 cho goi trong ma goc (20 / 3 / 0) va truoc luot nay KHONG HE
# TON TAI o lop gia lap: ten khong co trong bang Node nen roi vao `__index`,
# tra ve mot ham dem lai roi tra nil — khong bao loi, chi la bong khong bao gio
# hien. Cung kieu voi `_godot_zsort` va ba ham diem gan (xem ROADMAP).
#
# Cai phai do KHONG phai "bong co hien khong" ma la ba khang dinh doc ra tu ma
# may cua ban goc (`libgame.so`, Thumb):
#
#   1. Bong KHONG duoc dung san. `_ShowShadow(true)` (0x419f74) moi goi
#      0x419de6, va trong do buoc DAU TIEN la 0x419668 = tao bong. Khong co
#      duong nao khac tao no — nen mot rig vua dung xong phai KHONG co bong.
#   2. `_ShowShadow(false)` XOA HAN chu khong phai lam mo di: 0x417e14 goi
#      `removeFromParentAndCleanup(true)` + `release()` roi tra con tro ve 0.
#      Lan `true` sau do tao lai tu dau (doi tuong MOI).
#   3. Goc dat bong: 0x419de6 chi sap lai (zOrder -10) va hien khi CHINH
#      armature dang hien VA bong dang an — armature an thi bong van duoc tao
#      nhung o lai trang thai an.
#
# Phan so lieu (`BongRef`) do doc lap: bang `data_ref/bong_ref.json` sinh bang
# `python ../brave-cross/work/bong_ref.py`, va no tu doi chieu voi phep dem tho
# tren chuoi cua sau file cau hinh goc (nShadowSize 7, fShadowScaleRate 7,
# fShadowOffsetRate 8, fShadowOpacity 2, 120 khoi `limbs` co `sShadow`). Anh bong
# kiem bang chinh file PNG: 164x22, alpha giua 112/255 = 0,439 va PHANG trong
# long hinh — elip dac vien cung chu khong phai gradient mem — hep dan ra hai dau
# va doi xung tren-duoi. Do la phep thu cho thuat toan tach alpha cua ETC1 (nua
# duoi lay kenh do): doc sai mat na thi khong ra hinh doi xung gon gang nhu vay.
extends SceneTree

const ANH := "res://assets_ref/bong/Shadow.png"
const BANG := "res://data_ref/bong_ref.json"
const RIG_GA := "res://assets_ref/Hoplite"
const RIG_MAC_DINH := "res://assets_ref/YuJin"
## Rig co rig long nhau ben trong (dau CaoCao la mot bien the khac trong cung
## file) — de do phan de quy cua `_UpdateShadowPosY` (0x417ddc di xuong con bang
## 0x3c93c0).
const RIG_LONG := "res://assets_ref/CaoCao"

## So do doc tu cau hinh goc (xem chu thich dau `battle/bong_ref.gd`).
const SO_MUC := 19
const SO_TAI_NGUYEN := 120
const TI_LE_GA := 0.7          ## Hoplite
const TI_LE_MAC_DINH := 0.9    ## global_config.xml, khoi <stage>
const DO_MO := 0.8             ## DragonFlight, BatFlight
## Bay sprite ghi `fShadowScaleRate` rieng — dung bay ten nay, khong hon.
const CO_TI_LE := {
	"BaiHuZi": 0.7, "DongZhuoEvil": 0.8, "ElephantSoldier": 1.0,
	"FengYaoJi": 0.7, "Hoplite": 0.7, "MaYuanYi": 0.76, "ZhangLiangBao": 0.8,
}

const _BOOT := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	boot.boot_goc()
	boot.init_config()
	g_CSceneManager.CurrentScene = 'Test'
	return true
"""

## Dung armature that qua duong cua ban goc, roi goi ba ham bong bang DUNG cu
## phap cua ma goc.
##
## Tra ve sau o: co rig khong; rig co bong khong TRUOC khi goi; sau
## `_ShowShadow(true)`; sau `_ShowShadow(false)`; va sau lan `true` thu hai.
## Bon so cua bong (ti le, do dam, z, dang hien) do ben GDScript chu khong do o
## day — `_rig_cua` cua `lua/cocos.lua` tra ve node Godot THO, ma doc thuoc
## tinh cua mot bien GDScript qua lop boc la chuyen khong chac chan; con
## `co_bong()` la phuong thuc nen goi duoc, va no chung minh dung cai can chung
## minh: loi goi Lua tim ra duoc rig trong cay.
##
## Cho trong ten sprite la `@TEN@` chu KHONG phai `%s`: trong doan nay co
## `'%.4f'` cua Lua, ma toan tu `%` cua GDScript se hieu do la dinh dang.
const _LUA_DUNG := """
	local c = require('cocos')
	_G['_SAN'] = c.wrap(_root)
	local cha = c.new_node('layer')
	_SAN:addChild(cha)
	local sp = getSpriteFromSpriteCatch('@TEN@')
	cha:addChild(sp)
	sp:setPosition(0, 0)
	_G['_SP'] = sp
	-- Cung phep thu nhan dien rig nhu `_rig_cua` cua cocos.lua: co 'animations'
	-- VA co 'play'.
	local function rig()
		local gd = c.raw(sp)
		for i = 0, gd:get_child_count() - 1 do
			local r = gd:get_child(i)
			if r:has_method('animations') and r:has_method('play') then return r end
		end
		return nil
	end
	_G['_RIG'] = rig()
	local ra = {}
	ra[#ra + 1] = tostring(rig() ~= nil)
	ra[#ra + 1] = tostring(rig() ~= nil and rig():co_bong())
	sp:_ShowShadow(true)
	ra[#ra + 1] = tostring(rig():co_bong())
	sp:_SetSyncShadowPosY(true)
	return table.concat(ra, ';')
"""

const _LUA_XOA := """
	local sp = _G['_SP']
	sp:_ShowShadow(false)
	local ra = {}
	ra[#ra + 1] = tostring(_G['_RIG']:co_bong())
	-- Lan `true` sau do phai TAO LAI (doi tuong moi), khong phai bat lai cai cu.
	sp:_ShowShadow(true)
	ra[#ra + 1] = tostring(_G['_RIG']:co_bong())
	return table.concat(ra, ';')
"""

## Goi ba ham tren mot node KHONG phai rig: ban goc co the tro nham, va o day
## phai im lang bo qua chu khong nem loi giua mot man 3000 dong.
const _LUA_NODE_THUONG := """
	local c = require('cocos')
	local n = c.new_node('layer')
	_SAN:addChild(n)
	n:_ShowShadow(true)
	n:_ShowShadow(false)
	n:_SetSyncShadowPosY(false)
	n:_UpdateShadowPosY()
	return 'xong'
"""

## `_ShowShadow` goi TRAN (khong tham so): ban goc truyen mac dinh 1 ngay trong
## ma may (`movs r1, #1; bl 0x23c17c`), nen thieu tham so nghia la BAT.
const _LUA_TRAN := """
	local c = require('cocos')
	local cha = c.new_node('layer')
	_SAN:addChild(cha)
	local sp = getSpriteFromSpriteCatch('@TEN@')
	cha:addChild(sp)
	_G['_SP2'] = sp
	local function rig()
		local gd = c.raw(sp)
		for i = 0, gd:get_child_count() - 1 do
			local r = gd:get_child(i)
			if r:has_method('animations') and r:has_method('play') then return r end
		end
		return nil
	end
	sp:_ShowShadow()
	return tostring(rig() ~= nil and rig():co_bong())
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


func _tim_rig(n: Node) -> SngRig:
	if n is SngRig:
		return n
	for c in n.get_children():
		var r := _tim_rig(c)
		if r != null:
			return r
	return null


## Chay mot doan Lua. Doan Lua hong thi tinh la HONG luon: neu khong thi mot
## doan vo (vd rig khong dung duoc nen `rig()` tra nil) se lam bo kiem di qua
## trong im lang, va bo kiem bao xanh ma thuc ra khong do gi.
func _chay(ma: String, ten: String) -> Variant:
	var r = _lua.run(ma, ten)
	if r == null:
		_ghi_chu(false, "doan Lua '%s' hong: %s" % [ten, ", ".join(_lua.errors)])
	return r


func _init() -> void:
	# --- A. Bang so lieu ---------------------------------------------------
	print("A. data_ref/bong_ref.json + %s:" % ANH.get_file())
	var d = JSON.parse_string(FileAccess.get_file_as_string(BANG))
	if typeof(d) != TYPE_DICTIONARY:
		_ghi_chu(false, "khong doc duoc %s" % BANG)
		quit(1)
		return
	var muc: Dictionary = d.get("muc", {})
	var vai: Dictionary = d.get("vai", {})
	var toan: Dictionary = d.get("toan_cuc", {})
	_ghi_chu(muc.size() == SO_MUC, "%d muc co so do bong (do tu cau hinh goc: %d)"
			% [muc.size(), SO_MUC])
	_ghi_chu(vai.size() == SO_TAI_NGUYEN,
			"%d armature co `sShadow` (do tu cau hinh goc: %d)" % [vai.size(), SO_TAI_NGUYEN])
	_ghi_chu(is_equal_approx(float(toan.get("fShadowScaleRate", 0.0)), TI_LE_MAC_DINH),
			"mac dinh toan cuc fShadowScaleRate = %s (do tu global_config.xml: %s)"
			% [toan.get("fShadowScaleRate"), TI_LE_MAC_DINH])

	# Bay sprite ghi ti le rieng — dung bay ten, khong hon khong kem. Ten sai
	# hay thua mot muc la bang sinh ra da lech.
	var co_ti_le := {}
	for k in muc:
		if (muc[k] as Dictionary).has("fShadowScaleRate"):
			co_ti_le[String(k)] = float(muc[k]["fShadowScaleRate"])
	_ghi_chu(co_ti_le.size() == CO_TI_LE.size(),
			"dung %d sprite ghi fShadowScaleRate (do tu cau hinh goc: %d)"
			% [co_ti_le.size(), CO_TI_LE.size()])
	for k in CO_TI_LE:
		_ghi_chu(co_ti_le.has(k) and is_equal_approx(float(co_ti_le[k]), float(CO_TI_LE[k])),
				"  %-18s ti le %s (do tu cau hinh goc: %s)"
				% [k, co_ti_le.get(k, "thieu"), CO_TI_LE[k]])

	# Duong doc cua ban dung: `BongRef` tra so cua sprite, va tra MAC DINH cho
	# sprite khong khai gi — mac dinh lay tu chinh file cau hinh, khong phai so
	# cua ban dung.
	_ghi_chu(is_equal_approx(BongRef.ti_le("Hoplite"), TI_LE_GA),
			"BongRef.ti_le('Hoplite') = %s (do: %s)" % [BongRef.ti_le("Hoplite"), TI_LE_GA])
	_ghi_chu(is_equal_approx(BongRef.ti_le("YuJin"), TI_LE_MAC_DINH),
			"BongRef.ti_le('YuJin') = %s — sprite khong khai thi lay mac dinh %s"
			% [BongRef.ti_le("YuJin"), TI_LE_MAC_DINH])
	_ghi_chu(is_equal_approx(BongRef.do_mo("DragonFlight"), DO_MO)
			and is_equal_approx(BongRef.do_mo("BatFlight"), DO_MO),
			"do dam DragonFlight/BatFlight = %s (do tu evil_config.xml: %s)"
			% [BongRef.do_mo("DragonFlight"), DO_MO])
	_ghi_chu(is_equal_approx(BongRef.do_mo("YuJin"), 1.0),
			"do dam YuJin = %s — khong khai thi 1,0"
			% BongRef.do_mo("YuJin"))

	# Ten tai nguyen bong: LUON la <Ten>Shadow, tru mot mau le DAO DAI
	# (DaQiao → DaQiaoReplica) — nen phep kiem nay phan biet "doc bang" voi
	# "ghep chuoi <Ten>Shadow".
	_ghi_chu(BongRef.ten_bong("YuJin") == "YuJinShadow", "ten_bong('YuJin') = %s"
			% BongRef.ten_bong("YuJin"))
	_ghi_chu(BongRef.ten_bong("Player03") == "Player03Shadow", "ten_bong('Player03') = %s"
			% BongRef.ten_bong("Player03"))
	_ghi_chu(BongRef.ten_bong("DaQiao") == "DaQiaoReplica",
			"ten_bong('DaQiao') = %s — mau le, khong phai ghep chuoi"
			% BongRef.ten_bong("DaQiao"))
	_ghi_chu(BongRef.ten_bong("XiaoQiaoExclus") == "XiaoQiaoExclusShadow",
			"ten_bong('XiaoQiaoExclus') = %s" % BongRef.ten_bong("XiaoQiaoExclus"))
	_ghi_chu(BongRef.ten_bong("Hoplite") == "",
			"ten_bong('Hoplite') = '' — linh khong co khoi <limbs>" )

	# Anh bong: kich thuoc va DANG ALPHA, do tu chinh file PNG. Day la phep thu
	# cho thuat toan tach alpha cua ETC1 (nua duoi lay kenh do — y nhu
	# `sprites.py` dang dung cho 397 cap plist+texture). Do lai:
	#   * giua anh alpha 112/255 = 0,439, bon goc 0.
	#   * alpha PHANG trong long hinh: ca anh khong diem nao qua 115/255. Tuc day
	#     la mot ELIP DAC vien cung, KHONG phai gradient mem — do dam den tu chinh
	#     anh, con `fShadowOpacity` nhan them len tren (`modulate.a` nhan vao
	#     alpha cua texture).
	#   * be ngang hep dan tu giua ra hai dau va dong tren cung be ngang dong duoi
	#     (do: 66 va 66) — elip noi tiep trong o 164x22, be ngang 164 o hang giua.
	#     Mot mat na alpha doc sai se khong ra hinh doi xung gon gang nhu vay.
	var img := Image.load_from_file(ProjectSettings.globalize_path(ANH))
	if img == null:
		_ghi_chu(false, "khong doc duoc %s" % ANH)
	else:
		var w := img.get_width()
		var h := img.get_height()
		_ghi_chu(w == 164 and h == 22, "anh bong %dx%d (do tu Shadow.pkm: 164x22)" % [w, h])
		var giua := img.get_pixel(w / 2, h / 2).a
		_ghi_chu(absf(giua - 112.0 / 255.0) < 0.01,
				"alpha giua %.3f — do lai 112/255 = 0,439: alpha PHANG trong long hinh (vien cung, khong mem dan)"
				% giua)
		_ghi_chu(img.get_pixel(1, 1).a == 0.0 and img.get_pixel(w - 2, h - 2).a == 0.0,
				"bon goc alpha 0")

		var ca_anh := 0.0
		var be := []
		for y in [0, h / 2, h - 1]:
			var n := 0
			for x in range(w):
				if img.get_pixel(x, y).a > 0.0:
					n += 1
			be.append(n)
		for y in range(h):
			for x in range(w):
				ca_anh = maxf(ca_anh, img.get_pixel(x, y).a)
		_ghi_chu(be[1] == w and be[0] == be[2],
				"be ngang: hang giua %d (ca o, elip cham hai mep), hang dau %d = hang cuoi %d"
				% [be[1], be[0], be[2]])
		_ghi_chu(be[0] < be[1] / 2 and ca_anh < 0.5,
				"hep dan ra hai dau (%d < %d) va alpha phang %.3f < 0,5 — elip dac vien cung, khong gradient mem"
				% [be[0], be[1] / 2, ca_anh])

	# --- B. SngRig --------------------------------------------------------
	print("\nB. rig/sng_rig.gd — tao theo yeu cau, khong dung san:")
	var nen := Node2D.new()
	root.add_child(nen)
	var rig := SngRig.build(RIG_GA)
	var rig2 := SngRig.build(RIG_MAC_DINH)
	if rig == null or rig2 == null:
		_ghi_chu(false, "khong dung duoc rig tu %s / %s" % [RIG_GA, RIG_MAC_DINH])
		quit(1)
		return
	nen.add_child(rig)
	nen.add_child(rig2)
	rig2.position = Vector2(400, 0)

	_ghi_chu(not rig.co_bong(), "rig vua dung xong KHONG co bong (ban goc chi tao khi co nguoi goi)")
	rig.hien_bong(false)
	_ghi_chu(not rig.co_bong(), "hien_bong(false) tren rig chua co bong: im lang, van khong co gi")
	_ghi_chu(not rig2.co_bong(), "rig thu hai trong cung cay cung khong bi dung bong theo")

	rig.hien_bong(true)
	var b := rig.bong
	if b == null:
		_ghi_chu(false, "hien_bong(true) khong tao ra bong")
	else:
		_ghi_chu(b.z_index == SngRig.Z_BONG and SngRig.Z_BONG < 0,
				"z = %d (ban goc sap bong ve -10 truoc khi hien)" % b.z_index)
		_ghi_chu(b.centered, "neo giua (ban goc: setAnchorPoint(0.5, 0.5))")
		_ghi_chu(b.position == Vector2.ZERO, "bong nam tai goc rig, y = %s" % b.position.y)
		_ghi_chu(b.visible, "hien ra")
		_ghi_chu(is_equal_approx(b.scale.x, TI_LE_GA) and is_equal_approx(b.scale.y, TI_LE_GA),
				"ti le %s (Hoplite ghi 0,7 trong sprite_config.xml)" % b.scale.x)
		_ghi_chu(is_equal_approx(b.modulate.a, 1.0), "do dam %s (Hoplite khong khai)" % b.modulate.a)
		_ghi_chu(b.texture != null and b.texture.get_width() == 164,
				"anh lay tu %s" % ANH)
	_ghi_chu(not rig2.co_bong(), "rig thu hai VAN khong co bong — chi rig duoc hoi moi co")

	var id_cu := b.get_instance_id() if b != null else 0
	rig.hien_bong(false)
	await process_frame
	_ghi_chu(not rig.co_bong() and rig.find_child("Bong", true, false) == null,
			"hien_bong(false) XOA HAN bong (ban goc: removeFromParentAndCleanup + release)")
	rig.hien_bong(true)
	_ghi_chu(rig.bong != null and rig.bong.get_instance_id() != id_cu,
			"lan true sau do TAO LAI doi tuong moi (id cu %d, id moi %d)"
			% [id_cu, rig.bong.get_instance_id() if rig.bong != null else 0])

	# Armature dang AN: 0x419de6 tao bong TRUOC cua kiem `self visible`, nen
	# bong co that nhung phai o lai trang thai an.
	rig.hien_bong(false)
	rig.visible = false
	rig.hien_bong(true)
	_ghi_chu(rig.co_bong() and rig.bong != null and not rig.bong.visible,
			"armature an: bong VAN duoc tao nhung o lai trang thai an")
	rig.visible = true
	rig.hien_bong(true)
	_ghi_chu(rig.bong != null and rig.bong.visible,
			"armature hien lai roi goi true: bong hien ra")

	# Co dong bo Y: `_SetSyncShadowPosY` (0x417df9 ghi shadow[0x1a6]).
	rig.bong.position = Vector2(5, 5)
	rig.dong_bo_bong_y(false)
	rig.cap_nhat_bong_y()
	_ghi_chu(rig.bong.position == Vector2(5, 5),
			"dong bo Y TAT: cap_nhat_bong_y() khong keo bong ve (giu %s)" % rig.bong.position)
	rig.dong_bo_bong_y(true)
	rig.cap_nhat_bong_y()
	_ghi_chu(rig.bong.position == Vector2.ZERO,
			"dong bo Y BAT lai: cap_nhat_bong_y() keo bong ve goc rig")

	# `_UpdateShadowPosY` di DE QUY xuong cac con (0x3c93c0). Do bang rig co rig
	# long nhau: bat bong cho CA rig trong lan rig con, roi xem mot lan goi tren
	# rig cha co keo duoc bong cua con ve khong.
	var rig_l := SngRig.build(RIG_LONG)
	if rig_l == null:
		_ghi_chu(false, "khong dung duoc rig %s de do phan de quy" % RIG_LONG)
	else:
		nen.add_child(rig_l)
		var con := rig_l.find_children("", "SngRig", true, false)
		_ghi_chu(con.size() > 0, "%s co %d rig long nhau ben trong" % [RIG_LONG, con.size()])
		var ds: Array = [rig_l]
		ds.append_array(con)
		var co_bong := 0
		for r in ds:
			r.hien_bong(true)
			if r.bong != null:
				r.bong.position = Vector2(7, 7)
				co_bong += 1
		_ghi_chu(co_bong == ds.size(), "bat bong cho ca %d rig (%d co bong)"
				% [ds.size(), co_bong])
		rig_l.cap_nhat_bong_y()
		var xa := 0
		for r in ds:
			if r.bong != null and r.bong.position != Vector2.ZERO:
				xa += 1
		_ghi_chu(xa == 0, "mot lan goi tren rig cha keo duoc CA %d bong con ve goc (con lech: %d)"
				% [ds.size(), xa])

	# --- C. Duong Lua ------------------------------------------------------
	print("\nC. lua/cocos.lua — ba ham cua lop Node:")
	var lua := LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not lua.open():
		print("KHONG mo duoc Lua: %s" % ", ".join(lua.errors))
		quit(1)
		return
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
		return

	var r = _chay(_LUA_DUNG.replace("@TEN@", "Hoplite"), "dung armature + _ShowShadow")
	# Node rig do ben GDScript tim trong cay `_san`: luc nay no la rig DUY NHAT
	# trong do (canh Main khong duoc dung o bo kiem nay), nen khong lan ai.
	var rig_lua := _tim_rig(_san)
	if r != null:
		var p := (r as String).split(";")
		_ghi_chu(p.size() == 3, "doan Lua tra ve %d o (phai la 3)" % p.size())
		if p.size() >= 3:
			_ghi_chu(p[0] == "true", "getSpriteFromSpriteCatch('Hoplite') co rig duoi no")
			_ghi_chu(p[1] == "false", "truoc _ShowShadow(true): rig KHONG co bong")
			_ghi_chu(p[2] == "true", "sau _ShowShadow(true): rig CO bong")
	if rig_lua == null:
		_ghi_chu(false, "khong tim thay rig trong cay sau doan Lua")
	else:
		_ghi_chu(rig_lua.bong != null, "bong co that trong cay, khong chi la co trong Lua")
		if rig_lua.bong != null:
			_ghi_chu(is_equal_approx(rig_lua.bong.scale.x, TI_LE_GA),
					"ti le cua bong doc tu Lua = %s (Hoplite: %s)"
					% [rig_lua.bong.scale.x, TI_LE_GA])
			_ghi_chu(rig_lua.bong.z_index == SngRig.Z_BONG, "z = %d" % rig_lua.bong.z_index)
			_ghi_chu(rig_lua.bong.visible, "bong hien ra qua duong Lua")
		_ghi_chu(rig_lua._bong_dong_bo_y, "_SetSyncShadowPosY(true) dat co dong bo Y")
		var id_lua := rig_lua.bong.get_instance_id() if rig_lua.bong != null else 0

		var r2 = _chay(_LUA_XOA, "xoa roi tao lai")
		if r2 != null:
			var p2 := (r2 as String).split(";")
			_ghi_chu(p2.size() == 2, "doan Lua tra ve %d o (phai la 2)" % p2.size())
			if p2.size() >= 2:
				_ghi_chu(p2[0] == "false", "sau _ShowShadow(false): bong da bi xoa")
				_ghi_chu(p2[1] == "true", "lan true thu hai: bong co lai")
			await process_frame
			_ghi_chu(rig_lua.bong != null and rig_lua.bong.get_instance_id() != id_lua,
					"lan true thu hai TAO LAI doi tuong moi (id cu %d, id moi %d)"
					% [id_lua, rig_lua.bong.get_instance_id() if rig_lua.bong != null else 0])
			_ghi_chu(rig_lua.visible and rig_lua.bong != null and rig_lua.bong.visible,
					"armature dang hien thi bong hien theo")

	var r3 = _chay(_LUA_TRAN.replace("@TEN@", "YuJin"), "_ShowShadow khong tham so")
	if r3 != null:
		_ghi_chu((r3 as String) == "true",
				"_ShowShadow() khong tham so = BAT (ban goc truyen mac dinh 1)")

	var r4 = _chay(_LUA_NODE_THUONG, "goi tren node khong phai rig")
	_ghi_chu(r4 != null, "goi ca ba ham tren node khong phai rig: khong nem loi")

	# Chinh phep kiem "ham co that": neu ba ten nay khong co trong bang Node thi
	# chung roi vao `__index` va bi dem vao `M.missing` — khong mot loi nao.
	var miss := lua.missing()
	var con_thieu: Array = []
	for ten in ["_ShowShadow", "_SetSyncShadowPosY", "_UpdateShadowPosY"]:
		if miss.has(ten):
			con_thieu.append("%s=%d" % [ten, miss[ten]])
	_ghi_chu(con_thieu.is_empty(),
			"ba ham bong KHONG nam trong bo dem M.missing%s"
			% ("" if con_thieu.is_empty() else ": " + ", ".join(con_thieu)))

	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)
