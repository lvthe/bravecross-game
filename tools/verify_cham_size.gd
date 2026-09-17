# Do HOP CHAM cua armature: `_lua_CollisionSize`.
#
#   godot --headless --path . --script tools/verify_cham_size.gd
#
# Ham nay co 6 cho goi trong ma goc (CUIBarracksMain.lua 1043/1091, CUICavern.lua
# 363/408/454, CUIInfiniteLevelMain.lua 848) va truoc luot nay KHONG HE TON TAI o
# lop gia lap: ten khong co trong bang Node nen roi vao `__index`, tra ve mot ham
# dem lai roi tra nil — khong bao loi, chi la cai nhan tren dau nhan vat roi vao
# goc (0,0). Cung kieu voi `_ShowShadow` va ba ham diem gan.
#
# Cai phai do la ba tang doc lap, khong phai "co tra ve so khong":
#
#   A. BANG SO LIEU. `ChamRef` tinh LAI cong thuc tu chinh cac thanh phan no luu
#      (w, h, rot1, rot2, sx, sy) roi so voi cap so da luu — hai duong doc lap
#      (Python sinh bang, GDScript tinh lai) phai gap nhau.
#   B. SO DO TU BAN GOC. Chin phep do tren may ao (`emu_cham.py` + ba phep cua
#      `emu_xuong.py` muc D), ghi thang so
#      vao day. Voi `rot = 0` phai khop TUNG BIT (ban goc chi nhan `w*sx`);
#      voi ba rig goc nho khac 0 thi dung sai 3e-4 — xem chu thich dau
#      `battle/cham_ref.gd`, phan lech ay CHUA RO nguyen nhan va da ghi lai.
#   C. DUONG LUA. Dung armature that qua `getSpriteFromSpriteCatch` roi goi
#      `_lua_CollisionSize()` — dung cu phap ma bon man kia dung.
#
# Ba ca bien phai co, vi thieu chung thi mot ban dung sai van xanh:
#   * thu tu hai so (rong TRUOC, cao SAU) — phai chon rig co hai so KHAC NHAU
#     (ElephantSoldier 170,52 x 118,5) chu khong phai rig vuong;
#   * armature KHONG co xuong `Collision` phai ra (0, 0) chu khong nem loi
#     (`DaQuZhanShi`);
#   * node KHONG phai rig cung phai ra (0, 0) chu khong nem loi.
extends SceneTree

const BANG := "res://data_ref/cham_ref.json"
const RIG_GA := "res://assets_ref/Hoplite"
const RIG_VUONG := "res://assets_ref/Hoplite"
const RIG_CHU_NHAT := "res://assets_ref/ElephantSoldier"
## Rig khong co xuong `Collision` — ban goc tra (0, 0), do duoc tren may ao.
const RIG_KHONG_CHAM := "res://assets_ref/DaQuZhanShi"

## 590 bien the co xuong `Collision` (418 file .xml, 224 bien the mang ten file).
##
## KHONG phai 592: tai lieu cu dem bang khung `.xml`, va `LvBuZhanShi_res-44` co
## `sourceSize` la `0 x 0` nen hop cua hai bien the `LvBuZhanShi_A2` va
## `LvBuZhanShi_Weapon1` bang khong. Do la he qua cua viec doi nguon khung sang
## `sourceSize` cua `.plist`, khong phai mot dong bi mat.
const SO_BIEN_THE := 590

## Phep do tren may ao (`emu_cham.py`, ban goc chay trong Android). Gia tri la
## `rong` roi `cao`; `null` = phep do lan do khong lay duoc so cao.
##
## HAI muc cuoi (`BatFlight`, `DragonFlight`) la ba phep do lat nguoc nguon khung
## (`emu_xuong.py` muc D, do ba rig CHUA TUNG do lan nao). Ca hai deu hop voi
## `sourceSize` cua `.plist` va deu KHONG hop voi ban ghi `.xml`:
##   BatFlight     145,00999450684 x 120   (.xml doi ra 290,02 x 240)
##   DragonFlight  175 x 145               (.xml doi ra 350 x 290)
const DO_DUOC := {
	"Hoplite": [163.55999755859, null],
	"ElephantSoldier": [170.52000427246, 118.5],
	"BaiHuZi": [320.0, 305.0],
	"ZhangLiangBao": [175.0, 227.5],
	"YuJin": [140.00547790527, null],
	"MaYuanYi": [254.65454101562, 189.62301635742],
	"GongSunZan": [140.01898193359, 185.00645446777],
	"BatFlight": [145.00999450684, 120.0],
	"DragonFlight": [175.0, 145.0],
}

## Ba rig duy nhat trong 590 di qua `sin`/`cos` o goc khac 0 (|rot| <= 0,08 do).
## Moi bien the khac chi co goc 0 hoac 180, va hai goc do khong chay duong luong
## giac nao (`|cos 180| = 1`, `|sin 180| = 0`). Dung sai rong hon cho ba rig nay.
const GOC_NHO := ["YuJin", "MaYuanYi", "GongSunZan"]

## Do tren may ao (`emu_cham.py`, muc F): PHEP CHON BIEN THE. Ban goc dung nhom
## MANG DUNG TEN duoc hoi, khong phai nhom nhieu dong tac nhat. Khoa la ten dem
## hoi `getSpriteFromSpriteCatch`, gia tri la (bien the phai chon, rong, cao).
##
## Hai rig nay bac bo ca hai cach chon "hop ly" kia:
##   DaQiao          7 nhom, `DaQiao` CUOI; nhieu dong tac nhat la `DaQiaoReplica`
##                   — ma no KHONG co xuong `Collision` nen se ra (0, 0).
##   CaiWenJiCircle  nhom DAU (cung la nhieu dong tac nhat) la `_Top`, cung khong
##                   co `Collision`; `CaiWenJiCircle` nam CUOI.
const DO_BIEN_THE := {
	"DaQiao": ["DaQiao", 85.0, 135.0],
	"CaiWenJiCircle": ["CaiWenJiCircle", 875.1199951171875, 523.7999877929688],
}

## Ten THU MUC khong phai mot bien the: `PlayerM.xml` khong co nhom nao ten
## `PlayerM` (cac nhom la `PlayerM03W`...). Duong lui phai chay, khong duoc ra null.
const KHONG_CO_NHOM_TRUNG_TEN := "res://assets_ref/PlayerM"

const _BOOT := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	boot.boot_goc()
	boot.init_config()
	g_CSceneManager.CurrentScene = 'Test'
	return true
"""

## Do nam rig qua DUONG CUA BAN GOC (`getSpriteFromSpriteCatch`), tra ve chuoi
## "x,y" noi bang ';'. `tostring` cua Lua in 14 chu so — du de so sanh chat.
##
## `ElephantSoldier` duoc chon de kiem THU TU hai so: 170,52 va 118,5 khac nhau
## du xa, con mot rig vuong thi doi cho hai so cung khong ai thay.
##
## `DaQiao` la ca CHON BIEN THE di qua duong Lua: thu muc `DaQiao` ton tai nen
## `LuaRuntime._tao_rig` khong xin bien the nao, va `_bien_the_cho()` phai chon
## nhom `DaQiao` (85 x 135) chu khong phai `DaQiaoReplica` ((0, 0)).
const _LUA_DO := """
	local c = require('cocos')
	_G['_SAN'] = c.wrap(_root)
	local cha = c.new_node('layer')
	_SAN:addChild(cha)
	local ra = {}
	for _, t in ipairs({'Hoplite','ElephantSoldier','ZhangLiangBao','DaQuZhanShi','DaQiao'}) do
		local sp = getSpriteFromSpriteCatch(t)
		cha:addChild(sp)
		local x, y = sp:_lua_CollisionSize()
		ra[#ra + 1] = t .. '=' .. tostring(x) .. ',' .. tostring(y)
	end
	_G['_CHA'] = cha
	return table.concat(ra, ';')
"""

## Node KHONG phai rig: bo cuc nao cung co the tro nham, phai im lang tra (0,0).
const _LUA_NODE_THUONG := """
	local c = require('cocos')
	local n = c.new_node('layer')
	_G['_CHA']:addChild(n)
	local x, y = n:_lua_CollisionSize()
	return tostring(x) .. ',' .. tostring(y)
"""

var _dat := 0
var _hong := 0
var _lua: LuaRuntime = null


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
## doan vo se lam bo kiem di qua trong im lang, va bo kiem bao xanh ma thuc ra
## khong do gi.
func _chay(ma: String, ten: String) -> Variant:
	var r = _lua.run(ma, ten)
	if r == null:
		_ghi_chu(false, "doan Lua '%s' hong: %s" % [ten, ", ".join(_lua.errors)])
	return r


## Cong thuc doc lap voi Python: tinh lai tu chinh cac thanh phan da luu.
func _tinh_lai(m: Dictionary) -> Vector2:
	var a1 := deg_to_rad(float(m["rot"]))
	var a2 := deg_to_rad(float(m["rot2"]))
	var w := float(m["w"]) * float(m["sx"])
	var h := float(m["h"]) * float(m["sy"])
	return Vector2(w * absf(cos(a1)) + h * absf(sin(a1)),
			h * absf(cos(a2)) + w * absf(sin(a2)))


func _init() -> void:
	# --- A. Bang so lieu ---------------------------------------------------
	print("A. data_ref/cham_ref.json + ChamRef:")
	var d = JSON.parse_string(FileAccess.get_file_as_string(BANG))
	if typeof(d) != TYPE_DICTIONARY:
		_ghi_chu(false, "khong doc duoc %s" % BANG)
		quit(1)
		return
	var bang: Dictionary = d.get("cham", {})
	_ghi_chu(ChamRef.co_bang(), "ChamRef doc duoc bang")
	_ghi_chu(bang.size() == SO_BIEN_THE,
			"%d bien the co xuong Collision (do tu 418 file .xml: %d)"
			% [bang.size(), SO_BIEN_THE])
	_ghi_chu(ChamRef.so_bien_the() == SO_BIEN_THE,
			"ChamRef.so_bien_the() = %d" % ChamRef.so_bien_the())

	# Tinh LAI cong thuc tu cac thanh phan da luu, roi so voi cap so da luu. Hai
	# duong doc lap: Python sinh bang, GDScript tinh lai. Dung sai chi con sai so
	# bieu dien float32 — o 1607 diem anh mot ulp da la 1,2e-4.
	var lech_max := 0.0
	var ten_lech := ""
	var so_goc_0 := 0
	var so_goc_180 := 0
	var so_goc_nho := 0
	for k in bang:
		var m: Dictionary = bang[k]
		var t := _tinh_lai(m)
		var luu := Vector2(float(m["rong"]), float(m["cao"]))
		var e := maxf(absf(t.x - luu.x), absf(t.y - luu.y))
		# Dung sai theo ti le cong tuyet doi: mot ulp float32 o 1607 px la 1,2e-4.
		var mien := 1e-3 + absf(luu.x) * 1e-6
		if e > mien and e > lech_max:
			lech_max = e
			ten_lech = String(k)
		if float(m["rot"]) == 0.0 and float(m["rot2"]) == 0.0:
			so_goc_0 += 1
		elif absf(float(m["rot"])) == 180.0 or absf(float(m["rot2"])) == 180.0:
			so_goc_180 += 1
		else:
			so_goc_nho += 1
	_ghi_chu(ten_lech == "",
			"tinh lai cong thuc tu (w,h,rot1,rot2,sx,sy) khop cap so da luu o ca %d bien the%s"
			% [bang.size(), "" if ten_lech == "" else " — lech %.3e o '%s'" % [lech_max, ten_lech]])

	# Ba nhom goc. Con so nay la cho chot do chinh xac cua bang: chi ba bien the
	# di qua sin/cos o goc khac 0, nen phan lech CHUA RO chi anh huong ba rig ay.
	_ghi_chu(so_goc_nho == GOC_NHO.size(),
			"chi %d/%d bien the co goc khac 0 VA khac 180 (do: %d) — phan con lai: goc 0 (%d), goc 180 (%d)"
			% [so_goc_nho, bang.size(), GOC_NHO.size(), so_goc_0, so_goc_180])
	for t in GOC_NHO:
		var m2: Dictionary = bang.get(t, {})
		_ghi_chu(not m2.is_empty() and absf(float(m2["rot"])) > 0.0
				and absf(float(m2["rot"])) < 1.0 and absf(float(m2["rot2"])) < 1.0,
				"  %-12s goc %s / %s — goc nho, di qua sin/cos"
				% [t, m2.get("rot", "thieu"), m2.get("rot2", "thieu")])

	# --- B. So do tu ban goc -----------------------------------------------
	print("\nB. Chin phep do tren may ao (emu_cham.py, emu_xuong.py):")
	for t in DO_DUOC:
		var m3: Dictionary = bang.get(t, {})
		if m3.is_empty():
			_ghi_chu(false, "%s khong co trong bang" % t)
			continue
		var do: Array = DO_DUOC[t]
		var dung_sai := 3e-4 if GOC_NHO.has(t) else 1e-9
		var loi := absf(float(m3["rong"]) - float(do[0]))
		_ghi_chu(loi <= dung_sai,
				"%-16s rong %s (may ao do %s, lech %.6f, dung sai %s)"
				% [t, m3["rong"], do[0], loi, dung_sai])
		if do[1] != null:
			var loi2 := absf(float(m3["cao"]) - float(do[1]))
			_ghi_chu(loi2 <= dung_sai,
					"%-16s cao  %s (may ao do %s, lech %.6f, dung sai %s)"
					% [t, m3["cao"], do[1], loi2, dung_sai])

	# Rig khong co xuong `Collision`: KHONG co muc nao trong bang, va `ChamRef`
	# tra (0, 0) — dung nhu ban goc. `getContentSize` la dai luong KHAC.
	_ghi_chu(ChamRef.muc("DaQuZhanShi").is_empty(),
			"DaQuZhanShi khong co muc nao — khong co xuong Collision")
	_ghi_chu(ChamRef.ho_cham("DaQuZhanShi") == Vector2.ZERO,
			"ChamRef.ho_cham('DaQuZhanShi') = %s (ban goc tra 0, 0)"
			% ChamRef.ho_cham("DaQuZhanShi"))
	_ghi_chu(ChamRef.ho_cham("TenRigKhongTonTai") == Vector2.ZERO,
			"ten khong co trong bang cung tra (0, 0), khong nem loi")

	# --- C. SngRig --------------------------------------------------------
	print("\nC. rig/sng_rig.gd:")
	var nen := Node2D.new()
	root.add_child(nen)
	var rig := SngRig.build(RIG_VUONG)
	if rig == null:
		_ghi_chu(false, "khong dung duoc rig tu %s" % RIG_VUONG)
		quit(1)
		return
	nen.add_child(rig)
	_ghi_chu(rig.ho_cham() == Vector2(163.55999755859375, 163.20001220703125),
			"Hoplite ho_cham() = %s (may ao do 163,55999755859 x 163,2)" % rig.ho_cham())
	_ghi_chu(rig.co_ho_cham(), "Hoplite co_ho_cham() — bien the '%s' co trong bang" % rig.variant)

	var rig_cn := SngRig.build(RIG_CHU_NHAT)
	if rig_cn == null:
		_ghi_chu(false, "khong dung duoc rig tu %s" % RIG_CHU_NHAT)
	else:
		nen.add_child(rig_cn)
		_ghi_chu(rig_cn.ho_cham() == Vector2(170.52000427246094, 118.5),
				"ElephantSoldier ho_cham() = %s (may ao do 170,52000427246 x 118,5)"
				% rig_cn.ho_cham())
		_ghi_chu(rig_cn.ho_cham().x > rig_cn.ho_cham().y,
				"ElephantSoldier: chieu RONG lon hon chieu CAO (170,52 > 118,5) — phep kiem thu tu hai so")

	var rig_kc := SngRig.build(RIG_KHONG_CHAM)
	if rig_kc == null:
		_ghi_chu(false, "khong dung duoc rig tu %s" % RIG_KHONG_CHAM)
	else:
		nen.add_child(rig_kc)
		_ghi_chu(rig_kc.ho_cham() == Vector2.ZERO and not rig_kc.co_ho_cham(),
				"DaQuZhanShi ho_cham() = %s, co_ho_cham() = %s — rig co that nhung khong co xuong Collision"
				% [rig_kc.ho_cham(), rig_kc.co_ho_cham()])

	# CHON BIEN THE nao (xem DO_BIEN_THE). Day la phan khoa cua `_bien_the_cho()`.
	for ten in DO_BIEN_THE:
		var mong: Array = DO_BIEN_THE[ten]
		var r := SngRig.build("res://assets_ref/%s" % ten)
		if r == null:
			_ghi_chu(false, "khong dung duoc rig tu %s" % ten)
			continue
		nen.add_child(r)
		_ghi_chu(r.variant == String(mong[0]),
				"%-16s chon bien the '%s' (may ao: ban goc dung '%s')"
				% [ten, r.variant, mong[0]])
		_ghi_chu(r.ho_cham() == Vector2(float(mong[1]), float(mong[2])),
				"%-16s ho_cham() = %s (may ao do %s x %s)"
				% [ten, r.ho_cham(), mong[1], mong[2]])

	# Xin DUNG bien the thi phai duoc dung bien the do: duong nay duoc dung that
	# (`LuaRuntime._tao_rig` tim thu muc theo tien to roi xin dung ten bien the).
	var rig_xin := SngRig.build("res://assets_ref/DaQiao", "DaQiaoReplica")
	if rig_xin == null:
		_ghi_chu(false, "khong dung duoc DaQiao voi bien the xin dung")
	else:
		nen.add_child(rig_xin)
		_ghi_chu(rig_xin.variant == "DaQiaoReplica" and rig_xin.ho_cham() == Vector2.ZERO,
				"xin dung 'DaQiaoReplica' thi dung no (%s) va ra (0, 0) vi khong co xuong Collision"
				% rig_xin.variant)

	# Thu muc khong trung ten bien the nao: van phai dung ra mot rig, khong null.
	var rig_lui := SngRig.build(KHONG_CO_NHOM_TRUNG_TEN)
	if rig_lui == null:
		_ghi_chu(false, "duong lui hong: %s ra null" % KHONG_CO_NHOM_TRUNG_TEN)
	else:
		nen.add_child(rig_lui)
		_ghi_chu(rig_lui.variant != "" and rig_lui.animations().size() > 0,
				"ten thu muc khong phai bien the ('%s') -> lui ve '%s', %d dong tac"
				% [KHONG_CO_NHOM_TRUNG_TEN.get_file(), rig_lui.variant,
					rig_lui.animations().size()])

	# --- D. Duong Lua ------------------------------------------------------
	print("\nD. lua/cocos.lua — Node:_lua_CollisionSize:")
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
	var san := Control.new()
	san.size = lua.cua_so_engine
	lua.set_stage(san)
	lua.set_touch_root(san)
	root.add_child(san)
	lua.bind_layout(san)
	lua.set_ui_root(san)
	if lua.run(_BOOT, "boot") == null:
		print("boot hong: %s" % ", ".join(lua.errors))
		quit(1)
		return

	var r = _chay(_LUA_DO, "do _lua_CollisionSize tren bon rig")
	if r != null:
		var o := (r as String).split(";")
		_ghi_chu(o.size() == 5, "doan Lua tra ve %d muc (phai la 5)" % o.size())
		for muc in o:
			var p := (muc as String).split("=")
			if p.size() != 2:
				_ghi_chu(false, "muc khong doc duoc: %s" % muc)
				continue
			var ten := p[0]
			var xy := (p[1] as String).split(",")
			if xy.size() != 2:
				_ghi_chu(false, "%s: khong tra ve HAI so: %s" % [ten, p[1]])
				continue
			var x := (xy[0] as String).to_float()
			var y := (xy[1] as String).to_float()
			var m4: Dictionary = bang.get(ten, {})
			if m4.is_empty():
				_ghi_chu(x == 0.0 and y == 0.0,
						"%-16s Lua tra (%.4f, %.4f) — khong co xuong Collision nen phai la (0, 0)"
						% [ten, x, y])
			else:
				var ds := 3e-4 if GOC_NHO.has(ten) else 1e-9
				_ghi_chu(absf(x - float(m4["rong"])) <= ds and absf(y - float(m4["cao"])) <= ds,
						"%-16s Lua tra (%s, %s) — bang ghi (%s, %s)"
						% [ten, xy[0], xy[1], m4["rong"], m4["cao"]])

	var r2 = _chay(_LUA_NODE_THUONG, "goi tren node khong phai rig")
	if r2 != null:
		_ghi_chu((r2 as String) == "0,0",
				"node khong phai rig tra '%s' (phai la '0,0'), khong nem loi" % r2)

	# Phep kiem "ham co that": neu ten nay khong co trong bang Node thi no roi
	# vao `__index` va bi dem vao `M.missing` — khong mot loi nao.
	var miss := lua.missing()
	_ghi_chu(not miss.has("_lua_CollisionSize"),
			"_lua_CollisionSize KHONG nam trong bo dem M.missing%s"
			% ("" if not miss.has("_lua_CollisionSize") else " (=%d)" % miss["_lua_CollisionSize"]))

	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)
