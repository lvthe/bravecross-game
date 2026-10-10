# Do HIEU UNG SAO theo cap sao cua tuong: `_Lua_addStarLevelEffect`.
#
#   godot --headless --path . --script tools/verify_sao.gd
#
# Bon cho goi trong ma goc (`ClientPaperDoll.lua:271,288` — tu do ra man tui /
# doi hinh / thong tin tuong / hang / ai vo tan — va `CUIGame.lua:953` cho san
# tran). Ca bon deu gac bang `if spHeroSprite._Lua_addStarLevelEffect then`, ma
# `__index` cua lop gia lap tra ve mot ham cho MOI ten — nen thieu ham nay thi
# KHONG mot dong loi nao, chi la hieu ung sao khong bao gio hien. Do la ly do
# phep kiem phai do BANG SO (co bao nhieu armature duoc gan vao node tuong),
# khong phai bang "chay khong loi".
#
# Bon tang, ba duong doc lap:
#   A. Bang so lieu `data_ref/star_ref.json` + `StarRef`: sau cap sao, 11 ten,
#      moi ten mot bien the co DUNG mot dong tac `PluginPlay`, va so xuong tung
#      bien the (2Up 7, 3Down 1, 7Up 11, ...). So xuong la phep thu phan biet
#      that: chon nham bien the trong cung file armature thi lech ngay. Cung
#      tang nay doi phep chia 23 bien the cua file: 11 hieu ung + 12 rig long
#      nhau (dong tac `Play`).
#   B. `SngRig` dung THANG tu `assets_ref/StarLevelEffect` — ca 11 bien the, khong
#      thieu anh nao, va CA 11 deu co rig LONG NHAU (2/2/1/3/2/5/2/6/2/6/5 xuong
#      tro toi chung, theo thu tu 2Up..7Down; ten do KHONG co trong `spriteFiles`,
#      no la bien the khac trong cung file — do la duong `_nested_variant`).
#      Tang nay cung giu lai cai BAY vua mac: bat bo loc xuong `Layer*` thi moi
#      bien the hieu ung ra rig RONG, ma rig rong van `play()` duoc (tra true).
#   C. Duong Lua: `sp:_Lua_addStarLevelEffect(cap)` qua lop gia lap, do so
#      armature duoc gan, THU TU, va dieu quan trong nhat — node tuong VAN tra
#      dung rig cua no sau khi gan (`_rig_cua` lay con DAU TIEN co `animations`
#      + `play`; neu armature hieu ung lot len truoc thi moi `_Lua_playAnimation`
#      / `_lua_stop` / `_lua_setOpacity` cua tuong se tro nham sang hieu ung).
#   D. Chinh ma goc: `g_ClientPaperDoll:ShowStarEffectWithHeroData` — duong goi
#      that, chay nguyen van.
extends SceneTree

## Do tu cau hinh goc (`map/global_config.xml`, khoi `<star>`) va doi chieu voi
## `map/StarLevelEffect.xml` — xem dau `work/star_ref.py`.
const SO_CAP := 6
const SO_TEN := 11
## File armature co 23 bien the: 11 cua cau hinh (dong tac `PluginPlay`) + 12
## ten `StarLevelEffect_mc_*` la rig long nhau (dong tac `Play`). Doc nham cho
## nay mot lan roi (tuong ca 23 deu `PluginPlay`).
const SO_LONG := 12
const DONG_TAC := "PluginPlay"
const DONG_TAC_LONG := "Play"
const CAP_2 := ["StarLevelEffect_2Up"]
const CAP_7 := ["StarLevelEffect_7Up", "StarLevelEffect_7Down"]
const SO_XUONG := {
	"StarLevelEffect_2Up": 7, "StarLevelEffect_3Up": 7, "StarLevelEffect_3Down": 1,
	"StarLevelEffect_4Up": 8, "StarLevelEffect_4Down": 2, "StarLevelEffect_5Up": 10,
	"StarLevelEffect_5Down": 2, "StarLevelEffect_6Up": 11, "StarLevelEffect_6Down": 2,
	"StarLevelEffect_7Up": 11, "StarLevelEffect_7Down": 5,
}
## Xuong tro toi MOT BIEN THE khac trong cung file (ten co trong `parts` nhung
## KHONG co trong `spriteFiles`) — do la duong `_nested_variant` cua `SngRig`.
## Do tren chinh file armature theo dung luat cua `_sprite_for` (uu tien ANH, roi
## moi toi bien the): **ca 11 bien the deu co** rig long nhau, khong phai chi hai
## cai nhu ghi chep truoc kia. Do sau: `_mc_23` long trong `_5Up` lai co rig long
## nhau cua no, nen danh sach duoi day la cac ten truc tiep.
const LONG_NHAU := {
	"StarLevelEffect_2Up": ["StarLevelEffect_mc_guang2"],
	"StarLevelEffect_3Up": ["StarLevelEffect_mc_guang2"],
	"StarLevelEffect_3Down": ["StarLevelEffect_mc_WakeEff"],
	"StarLevelEffect_4Up": ["StarLevelEffect_mc_guang2", "StarLevelEffect_mc_huofa"],
	"StarLevelEffect_4Down": ["StarLevelEffect_mc_WakeEff", "StarLevelEffect_mc_huofa"],
	"StarLevelEffect_5Up": ["StarLevelEffect_mc_guang2", "StarLevelEffect_mc_huofa",
			"StarLevelEffect_mc_23"],
	"StarLevelEffect_5Down": ["StarLevelEffect_mc_WakeEff", "StarLevelEffect_mc_huofa"],
	"StarLevelEffect_6Up": ["StarLevelEffect_mc_guang2", "StarLevelEffect_mc_huofa",
			"StarLevelEffect_mc_231", "StarLevelEffect_mc_yanwu"],
	"StarLevelEffect_6Down": ["StarLevelEffect_mc_WakeEff", "StarLevelEffect_mc_huofa"],
	"StarLevelEffect_7Up": ["StarLevelEffect_mc_233", "StarLevelEffect_mc_guang2",
			"StarLevelEffect_mc_huofa2", "StarLevelEffect_mc_yanwu"],
	"StarLevelEffect_7Down": ["StarLevelEffect_mc_1323", "StarLevelEffect_mc_huofa2"],
}
## So XUONG tro toi rig long nhau (mot bien the co the duoc nhieu xuong tro toi,
## vd `_mc_guang2` duoc `Layer000` va `Layer001` cua `_4Up`).
const SO_LONG_NHAU := {
	"StarLevelEffect_2Up": 2, "StarLevelEffect_3Up": 2, "StarLevelEffect_3Down": 1,
	"StarLevelEffect_4Up": 3, "StarLevelEffect_4Down": 2, "StarLevelEffect_5Up": 5,
	"StarLevelEffect_5Down": 2, "StarLevelEffect_6Up": 6, "StarLevelEffect_6Down": 2,
	"StarLevelEffect_7Up": 6, "StarLevelEffect_7Down": 5,
}

const RIG_TUONG := "YuJin"
const THU_MUC := "res://assets_ref/StarLevelEffect"

const _BOOT := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	boot.boot_goc()
	boot.init_config()
	g_CSceneManager.CurrentScene = 'Test'
	return true
"""

## Goi DUNG cu phap cua ma goc: hai ham `createLayer`-style cua lop phong nen,
## roi `getSpriteFromSpriteCatch` de dung armature tuong.
const _LUA_DUNG := """
	local c = require('cocos')
	_G['_SAN'] = c.wrap(_root)
	local cha = c.new_node('layer')
	_SAN:addChild(cha)
	local sp = getSpriteFromSpriteCatch('@TEN@')
	cha:addChild(sp)
	_G['_SP'] = sp
	return tostring(sp ~= nil)
"""

## Goi qua CHINH ma goc cua ban goc (tang D) — khong phai goi thang lop gia lap.
const _LUA_MA_GOC := """
	require('user.Logical.ClientPaperDoll')
	local sp = _G['_SP']
	local ra = {}
	-- Cap 4 qua duong that: `ShowStarEffectWithHeroData` doc
	-- `tHero.HeroGrowthFactor` roi `NumberUtils.Range(..., 1, 7)`.
	g_ClientPaperDoll:ShowStarEffectWithHeroData(sp, { HeroGrowthFactor = 4 })
	ra[#ra + 1] = tostring(g_ClientPaperDoll ~= nil)
	-- Cap 1: cau hinh KHONG co muc nao, nen phai xoa sach chu khong tao gi.
	g_ClientPaperDoll:ShowStarEffectWithHeroData(sp, { HeroGrowthFactor = 1 })
	-- Tran (`tHero` nil) va sprite nil: hai duong thoat som, khong duoc nem loi.
	g_ClientPaperDoll:ShowStarEffectWithHeroData(sp, nil)
	g_ClientPaperDoll:ShowStarEffectWithHeroData(nil, { HeroGrowthFactor = 5 })
	-- Biet so 99: `Range` chan tren 7, nen duong that khong bao gio ra 99 —
	-- goi thang lop gia lap de do nhanh ngoai bang.
	ra[#ra + 1] = tostring(sp:_Lua_addStarLevelEffect(99))
	return table.concat(ra, ';')
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


## Cac SngRig hieu ung sao ma `_hieu_ung_sao` gan vao node tuong. Moi lan gan la
## mot HOP (`_tao_rig`, meta `kind = "rig"`) voi SngRig lam con — nen chi dem
## dung cac hop ay, KHONG quet ca cay: rig long nhau ben trong cung ten
## `StarLevelEffect_mc_*` nen quet sau se dem lan ca chung.
func _sao_duoi(n: Node) -> Array:
	var ra: Array = []
	for c in n.get_children():
		if not c.has_meta("kind") or String(c.get_meta("kind")) != "rig":
			continue
		for g in c.get_children():
			var r := g as SngRig
			if r != null and r.variant.begins_with("StarLevelEffect_"):
				ra.append(r)
	return ra


## Cac SngRig long nhau nam TRONG `n`, ke ca long nhieu tang.
func _rig_long_nhau(n: Node) -> Array:
	var ra: Array = []
	for c in n.get_children():
		if c is SngRig:
			ra.append(c)
		ra.append_array(_rig_long_nhau(c))
	return ra


func _rig_cua_tuong(n: Node) -> SngRig:
	for c in n.get_children():
		if c is SngRig:
			return c
		var r := _rig_cua_tuong(c)
		if r != null:
			return r
	return null


## Chay mot doan Lua. Doan Lua hong thi tinh la HONG luon — neu khong thi mot
## doan vo se lam bo kiem di qua trong im lang.
func _chay(ma: String, ten: String) -> Variant:
	var r = _lua.run(ma, ten)
	if r == null:
		_ghi_chu(false, "doan Lua '%s' hong: %s" % [ten, ", ".join(_lua.errors)])
	return r


func _init() -> void:
	# --- A. Bang so lieu ---------------------------------------------------
	print("A. data_ref/star_ref.json + ui/star_ref.gd:")
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data_ref/star_ref.json"))
	if typeof(d) != TYPE_DICTIONARY:
		_ghi_chu(false, "khong doc duoc res://data_ref/star_ref.json")
		quit(1)
		return
	var bang: Dictionary = d.get("dongtac", {})
	var bien_the: Dictionary = d.get("bien_the", {})
	_ghi_chu(bang.size() == SO_CAP, "%d cap sao co muc trong cau hinh (do tu khoi <star>: %d)"
			% [bang.size(), SO_CAP])
	var so_ten := 0
	var so_hieu := 0
	var so_long := 0
	var ten_la: Array = []
	var sai_dong_tac: Array = []
	var sai_dong_tac_long: Array = []
	var sai_loai: Array = []
	for k in bien_the:
		so_ten += 1
		if not String(k).begins_with("StarLevelEffect_"):
			ten_la.append(String(k))
		var o: Dictionary = bien_the[k]
		var dt: Array = o.get("dong_tac", [])
		var loai := String(o.get("loai", ""))
		if loai == "hieu_ung":
			so_hieu += 1
			if dt.size() != 1 or String(dt[0]) != DONG_TAC:
				sai_dong_tac.append("%s=%s" % [k, dt])
		elif loai == "long_nhau":
			so_long += 1
			if dt.size() != 1 or String(dt[0]) != DONG_TAC_LONG:
				sai_dong_tac_long.append("%s=%s" % [k, dt])
		else:
			sai_loai.append("%s=%s" % [k, loai])
	_ghi_chu(not ten_la.is_empty() == false and ten_la.is_empty(),
			"moi ten deu bat dau bang 'StarLevelEffect_'")
	_ghi_chu(sai_dong_tac.is_empty(),
			"11 bien the HIEU UNG co DUNG mot dong tac '%s'%s"
			% [DONG_TAC, "" if sai_dong_tac.is_empty() else ": " + ", ".join(sai_dong_tac)])
	_ghi_chu(sai_dong_tac_long.is_empty(),
			"%d bien the LONG NHAU co DUNG mot dong tac '%s'%s"
			% [so_long, DONG_TAC_LONG, "" if sai_dong_tac_long.is_empty() else ": " + ", ".join(sai_dong_tac_long)])
	_ghi_chu(sai_loai.is_empty(),
			"moi bien the deu co truong `loai`%s"
			% ("" if sai_loai.is_empty() else ": " + ", ".join(sai_loai)))
	var dem := 0
	for k in bang:
		dem += (bang[k] as Array).size()
	_ghi_chu(dem == SO_TEN, "%d ten trong bang = %d (1 + 2x5)" % [dem, SO_TEN])
	_ghi_chu(so_ten == SO_TEN + SO_LONG and so_hieu == SO_TEN and so_long == SO_LONG,
			"bang so lieu: %d bien the = %d hieu ung + %d long nhau (phai la %d = %d + %d)"
			% [so_ten, so_hieu, so_long, SO_TEN + SO_LONG, SO_TEN, SO_LONG])

	# Duong doc cua ban dung.
	_ghi_chu(StarRef.co_bang(), "StarRef doc duoc bang")
	_ghi_chu(StarRef.dongtac(1).is_empty(), "cap 1: KHONG co muc nao (cau hinh bat dau tu _2)")
	_ghi_chu(StarRef.dongtac(0).is_empty() and StarRef.dongtac(8).is_empty()
			and StarRef.dongtac(-3).is_empty(),
			"cap 0 / 8 / -3: rong")
	_ghi_chu(not StarRef.co_hieu_ung(1) and StarRef.co_hieu_ung(2),
			"co_hieu_ung(1) = false, co_hieu_ung(2) = true")
	_ghi_chu(StarRef.dongtac("x").is_empty(), "cap khong phai so: rong, khong nem loi")
	_ghi_chu(StarRef.dongtac(2) == CAP_2, "cap 2 = %s" % [StarRef.dongtac(2)])
	_ghi_chu(StarRef.dongtac(7) == CAP_7, "cap 7 = %s" % [StarRef.dongtac(7)])
	for ten in SO_XUONG:
		_ghi_chu(StarRef.so_xuong(ten) == SO_XUONG[ten],
				"  %-24s %d xuong" % [ten, StarRef.so_xuong(ten)])
	_ghi_chu(StarRef.la_hieu_ung("StarLevelEffect_3Up")
			and not StarRef.la_hieu_ung("StarLevelEffect_mc_guang2")
			and not StarRef.la_hieu_ung("khong-co-ten-nay"),
			"la_hieu_ung: dung cho ten trong cau hinh, sai cho rig long nhau va ten la")
	# Ten trong cau hinh phai la bien the HIEU UNG — chieu nguoc lai cua phep
	# kiem tren, de mot ten lot vao `dongtac` ma khong co trong `bien_the`
	# cung lo ra.
	var khong_la: Array = []
	for k in bang:
		for t in (bang[k] as Array):
			if not StarRef.la_hieu_ung(String(t)):
				khong_la.append(String(t))
	_ghi_chu(khong_la.is_empty(),
			"moi ten trong khoi <star> deu la bien the 'hieu_ung'%s"
			% ("" if khong_la.is_empty() else ": " + ", ".join(khong_la)))

	# --- B. SngRig dung thang ---------------------------------------------
	print("\nB. rig/sng_rig.gd — 11 bien the dung thang tu %s:" % THU_MUC)
	var nen := Node2D.new()
	root.add_child(nen)
	for ten in SO_XUONG:
		# `no_clutter = false` — xuong cua armature HIEU UNG deu ten `Layer*`,
		# bat bo loc thi ca bien the ra rong. Xem phep kiem ngay duoi.
		var rig := SngRig.build(THU_MUC, ten, false)
		if rig == null:
			_ghi_chu(false, "khong dung duoc %s" % ten)
			continue
		nen.add_child(rig)
		var dt := rig.animations()
		_ghi_chu(rig.variant == ten, "%s → bien the dung ten (chon theo TEN, khong phai nhieu dong tac nhat)"
				% ten)
		_ghi_chu(rig.bones.size() == SO_XUONG[ten],
				"  %d xuong (bang so lieu: %d)" % [rig.bones.size(), SO_XUONG[ten]])
		# Chinh cai bay vua mac: o armature hieu ung thi MOI xuong tang ngoai cung
		# deu ten `Layer*`, nen loc la ra rig 0 xuong. Rig 0 xuong VAN `play()`
		# duoc (tra true) va VAN co ten dong tac, nen neu chi kiem "play tra true"
		# thi khong thay gi.
		#
		# Phep kiem nay goi THANG `SngRig.build` chu khong qua `_tao_rig`, nen no
		# khong phai cai cong gac cho `_tao_rig`. Cong gac that nam o
		# `verify_o_hien.gd` (do so xuong qua duong Lua voi bang so lieu cua file).
		# Giu phep kiem nay vi no chung minh bo loc VAN con hai: no van dung cho
		# man tran, nen khong duoc xoa no khoi `SngRig`.
		var loc := SngRig.build(THU_MUC, ten, true)
		_ghi_chu(loc != null and loc.bones.is_empty(),
				"  bat bo loc `Layer*` thi rig rong (%d xuong) — do la ly do bo loc chi duoc dung cho rig NHAN VAT o man tran"
				% (0 if loc == null else loc.bones.size()))
		if loc != null:
			loc.free()
		_ghi_chu(dt.size() == 1 and dt[0] == DONG_TAC,
				"  dong tac %s" % [dt])
		_ghi_chu(rig.missing_sprites.is_empty(),
				"  khong thieu anh nao%s"
				% ("" if rig.missing_sprites.is_empty() else ": " + ", ".join(rig.missing_sprites)))
		_ghi_chu(rig.play(DONG_TAC), "  phat duoc '%s' (tra true)" % DONG_TAC)
		# Rig long nhau: neu chi kiem "co hay khong" thi mot rig long RONG cung
		# lot — ma rig long rong la hinh mat, dung loai loi im lang dang can bat.
		var ln := _rig_long_nhau(rig)
		var ten_ln: Array = []
		var rong_ln: Array = []
		for x in ln:
			var rx := x as SngRig
			ten_ln.append(rx.variant)
			if rx.bones.is_empty():
				rong_ln.append(rx.variant)
		var thieu_ln := []
		for x in LONG_NHAU[ten]:
			if not ten_ln.has(x):
				thieu_ln.append(x)
		_ghi_chu(rig.nested_rigs.size() == SO_LONG_NHAU[ten],
				"  %d xuong tro toi rig long nhau (bang so lieu: %d)"
				% [rig.nested_rigs.size(), SO_LONG_NHAU[ten]])
		_ghi_chu(thieu_ln.is_empty(),
				"  du %d ten rig long nhau do tu file%s"
				% [LONG_NHAU[ten].size(), "" if thieu_ln.is_empty() else " (thieu %s)" % ", ".join(thieu_ln)])
		_ghi_chu(rong_ln.is_empty(),
				"  ca %d rig long nhau (ke ca long nhieu tang) deu co xuong%s"
				% [ln.size(), "" if rong_ln.is_empty() else " (rong: %s)" % ", ".join(rong_ln)])

	# --- C. Duong Lua ------------------------------------------------------
	print("\nC. lua/cocos.lua — `Node:_Lua_addStarLevelEffect`:")
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

	var r = _chay(_LUA_DUNG.replace("@TEN@", RIG_TUONG), "dung tuong")
	if r == null or String(r) != "true":
		_ghi_chu(false, "khong dung duoc armature tuong %s" % RIG_TUONG)
		quit(1)
		return
	var sp: Control = _san.get_child(0).get_child(0) as Control
	var rig_tuong := _rig_cua_tuong(sp)
	if rig_tuong == null:
		_ghi_chu(false, "node tuong khong co rig")
		quit(1)
		return
	var id_tuong := rig_tuong.get_instance_id()
	var bien_the_tuong := rig_tuong.variant
	_ghi_chu(not bien_the_tuong.begins_with("StarLevelEffect_"),
			"rig tuong = '%s' (khong phai hieu ung)" % bien_the_tuong)

	# Cap 3 → dung hai armature, theo THU TU trong cau hinh.
	var r3 = _chay("""
		local sp = _G['_SP']
		local n = sp:_Lua_addStarLevelEffect(3)
		return tostring(n)
	""", "cap 3")
	await process_frame
	var sao := _sao_duoi(sp)
	_ghi_chu(r3 != null and String(r3) == "2", "cap 3 gan 2 armature (tra ve %s)" % r3)
	var ten_sao: Array = []
	for s in sao:
		ten_sao.append((s as SngRig).variant)
	_ghi_chu(ten_sao == ["StarLevelEffect_3Up", "StarLevelEffect_3Down"],
			"dung hai bien the, dung THU TU cau hinh: %s" % [ten_sao])
	_ghi_chu(sp.get_child(0) is SngRig and (sp.get_child(0) as SngRig).get_instance_id() == id_tuong,
			"rig tuong VAN la con DAU TIEN (nen `_rig_cua` khong tro nham sang hieu ung)")
	_ghi_chu(_rig_cua_tuong(sp).get_instance_id() == id_tuong,
			"_rig_cua_tuong sau khi gan: van la rig cu")
	var dang_phat := 0
	var trong_cay := 0
	var du_xuong := 0
	var tong_xuong := 0
	for s in sao:
		var sr := s as SngRig
		if sr.is_inside_tree():
			trong_cay += 1
		if sr.player != null and sr.player.current_animation == DONG_TAC:
			dang_phat += 1
		# Rig RONG van `play()` duoc (tra true) va van co ten dong tac — nen
		# "phat duoc" KHONG du biet hieu ung co hinh. Phai dem xuong: bay da
		# mac mot lan (loc `Layer*` xoa sach ca 11 bien the, xem muc B).
		if sr.bones.size() == SO_XUONG.get(sr.variant, -1):
			du_xuong += 1
		tong_xuong += sr.get_child_count()
	_ghi_chu(trong_cay == sao.size(), "ca %d armature nam trong cay" % [trong_cay])
	_ghi_chu(dang_phat == sao.size(),
			"ca %d armature dang chay '%s' (khong phai chi duoc tao ra)" % [dang_phat, DONG_TAC])
	_ghi_chu(du_xuong == sao.size(),
			"ca %d armature co DU xuong theo bang so lieu (%d xuong trong cay)"
			% [du_xuong, tong_xuong])
	_ghi_chu(sp.get_meta("hieu_ung_sao", []).size() == 2, "node tuong giu danh sach 2 armature trong meta")
	# Sau khi gan hieu ung, duong armature cua tuong phai con nguyen: hoi thoi
	# luong mot dong tac cua chinh tuong qua lop gia lap.
	var t_dong_tac = _chay("""
		local sp = _G['_SP']
		local a = sp:_lua_getAnimationTime('%s')
		return tostring(a)
	""" % String(rig_tuong.animations()[0]), "hoi dong tac cua tuong")
	_ghi_chu(t_dong_tac != null and float(String(t_dong_tac)) > 0.0,
			"tuong van tra thoi luong dong tac '%s' = %s sau khi gan hieu ung"
			% [rig_tuong.animations()[0], t_dong_tac])

	# Goi lai voi cap khac: phai XOA cai cu roi tao doi tuong MOI.
	var id_cu: Array = []
	for s in sao:
		id_cu.append((s as SngRig).get_instance_id())
	var r5 = _chay("""
		local sp = _G['_SP']
		return tostring(sp:_Lua_addStarLevelEffect(5))
	""", "cap 5")
	await process_frame
	var sao5 := _sao_duoi(sp)
	var ten5: Array = []
	var trung := 0
	for s in sao5:
		ten5.append((s as SngRig).variant)
		if id_cu.has((s as SngRig).get_instance_id()):
			trung += 1
	_ghi_chu(r5 != null and String(r5) == "2", "cap 5 tra ve 2")
	_ghi_chu(ten5 == ["StarLevelEffect_5Up", "StarLevelEffect_5Down"], "bien the doi sang: %s" % [ten5])
	_ghi_chu(sao5.size() == 2 and trung == 0,
			"cai CU da bi xoa, khong con armature nao trung doi tuong (con %d, trung %d)"
			% [sao5.size(), trung])
	_ghi_chu(_rig_cua_tuong(sp).get_instance_id() == id_tuong, "rig tuong khong bi dung toi")

	# Cap 1: cau hinh khong co muc nao → xoa sach, khong tao gi.
	var r1 = _chay("""
		local sp = _G['_SP']
		return tostring(sp:_Lua_addStarLevelEffect(1))
	""", "cap 1")
	await process_frame
	_ghi_chu(r1 != null and String(r1) == "0", "cap 1 tra ve 0")
	_ghi_chu(_sao_duoi(sp).is_empty(), "cap 1: khong con armature hieu ung nao")
	_ghi_chu(sp.get_meta("hieu_ung_sao", []).size() == 0, "danh sach trong meta da rong")

	var node_thuong = _chay("""
		local c = require('cocos')
		local n = c.new_node('layer')
		_SAN:addChild(n)
		n:_Lua_addStarLevelEffect(3)
		local gd = c.raw(n)
		local n_con = gd:get_child_count()
		n:_Lua_addStarLevelEffect(1)
		return tostring(n_con)
	""", "node khong phai armature")
	_ghi_chu(node_thuong != null and String(node_thuong) == "2",
			"node THUONG (khong phai armature) van dung duoc: gan 2 roi xoa sach, khong nem loi (con %s)"
			% node_thuong)

	# --- D. Chinh ma goc ---------------------------------------------------
	print("\nD. sc/user/Logical/ClientPaperDoll.lua — duong goi that:")
	var r4 = _chay(_LUA_MA_GOC, "ma goc 星级")
	if r4 != null:
		var p := String(r4).split(";")
		_ghi_chu(p.size() == 2 and p[0] == "true", "g_ClientPaperDoll co that")
		_ghi_chu(p.size() == 2 and p[1] == "0", "cap 99 (ngoai bang) tra ve 0")
	await process_frame
	_ghi_chu(_sao_duoi(sp).is_empty(),
			"sau luot ma goc: `HeroGrowthFactor = 1` va `Range` chan tren da don sach hieu ung")

	# Ten ham phai co THAT trong bang Node: neu khong thi no roi vao `__index`
	# va bi dem vao `M.missing` — khong mot loi nao, chi la hieu ung khong hien.
	var miss := lua.missing()
	_ghi_chu(not miss.has("_Lua_addStarLevelEffect"),
			"_Lua_addStarLevelEffect khong nam trong bo dem M.missing%s"
			% ("" if not miss.has("_Lua_addStarLevelEffect") else " (%d lan goi)" % miss["_Lua_addStarLevelEffect"]))
	# Duong dung armature: `_tao_rig` tim file theo tien to ngan dan, va ghi ten
	# nao khong dung duoc vao `rig_thieu`. Rong nghia la ca 11 bien the deu dung ra.
	var thieu := []
	for ten in lua.rig_thieu:
		if String(ten).begins_with("StarLevelEffect_"):
			thieu.append(ten)
	_ghi_chu(thieu.is_empty(),
			"khong ten hieu ung sao nao bi ghi vao rig_thieu%s"
			% ("" if thieu.is_empty() else ": " + ", ".join(thieu)))
	# `rig_rong` la bo dem moi: armature dung ra nhung 0 xuong. Truoc phep kiem
	# nay, ca 11 bien the hieu ung sao deu roi vao day ma khong ai thay.
	var rong := []
	for ten in lua.rig_rong:
		if String(ten).begins_with("StarLevelEffect_"):
			rong.append(ten)
	_ghi_chu(rong.is_empty(),
			"khong hieu ung sao nao dung ra RONG (0 xuong)%s"
			% ("" if rong.is_empty() else ": " + ", ".join(rong)))
	_ghi_chu(lua.errors.is_empty(), "khong co loi Lua%s"
			% ("" if lua.errors.is_empty() else ": " + ", ".join(lua.errors)))

	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)
