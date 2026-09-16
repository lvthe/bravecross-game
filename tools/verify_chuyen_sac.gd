# Chuyen sac chu cua nhan: bon ham ma ban goc lo ra o lop 12 `Label`.
#
#   godot --headless --path . --script tools/verify_chuyen_sac.gd
#
# Bo nay kiem PHAN NOI DAY — node nao, vat lieu nao, cong thuc trong file
# `.gdshader`. Phan HINH (dai chay dung chieu nao, ra dung con so nao) do bang
# `tools/do_chuyen_sac.gd`, va bo do PHAI chay CO trinh ve that (trinh ve gia
# khong dung `SubViewport`) nen no khong nam trong `check.py` — chia hai nua nhu
# vay la CO Y, y het `verify_sang.gd` / `do_sang.gd`.
#
# Cong thuc thi VAN kiem duoc o day bang cach DOC CHINH FILE `.gdshader`: mot
# phep tron nguoc chieu (`mix(mau_dau.rgb, mau_cuoi.rgb, a)`) la loi IM LANG —
# dai van ra, chi la ra nguoc.
#
# Phan cuoi chay DUNG duong ma ban goc dung bon ham nay: man hinh khong bao gio
# goi thang `enableGradual` de to xam, no goi
# `g_CUIPublic:SetEnableGradualLableGray` (CUIPublic.lua:438) — va ham do doi
# `IsEnableGradualColor()` phai true truoc da. Do la phep kiem dat nhat trong bo
# nay, vi no bat ca ba thu cung luc: co dang bat, THU TU sau gia tri, va quy
# "lam phang" cua ma goc luc tra lai.
extends SceneTree

const CS := preload("res://ui/chuyen_sac.gd")

var ok := 0
var bad := 0


func t(name: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [name, ("  (%s)" % note) if note else ""])


func _init() -> void:
	_kiem_file_shader()
	await _kiem_noi_day()
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# 1. Cong thuc trong file .gdshader ---------------------------------------

func _kiem_file_shader() -> void:
	print("=== file shader ===")
	var ma := FileAccess.get_file_as_string("res://ui/chuyen_sac.gdshader")
	t("doc duoc ui/chuyen_sac.gdshader", not ma.is_empty())
	if ma.is_empty():
		return
	# Chi doc THAN ham: phan chu thich dau file nhac lai NGUYEN VAN ban goc, ke ca
	# dong `resultColor.r = v_colorBegin.r*a + v_colorEnd.r*b` — khong cat ra thi
	# cac phep kiem ben duoi tu bao sai.
	var cat := ma.find("shader_type")
	t("co dong shader_type", cat >= 0)
	if cat < 0:
		return
	var than := ma.substr(cat)

	t("co tham so chieu_cao", than.contains("uniform float chieu_cao"))
	# Vi tri phai lay theo chieu DOC cua O NODE, va phai lay TRONG `vertex()`:
	# trong Godot 4.7 `VERTEX` doc o `fragment()` la toa do KHUNG VE, nen dai se
	# lech theo cho node dung. Do duoc (`tools/do_chuyen_sac.gd`): nhan cao 55 dat
	# o y = 8 ma kenh do ra dung `y_khung / 55`, tuc an ca vi tri node; sau khi
	# sua thi 29/29 hang khop cong thuc voi lech 0,0000.
	var i_frag := than.find("void fragment()")
	t("co ham fragment()", i_frag >= 0)
	if i_frag >= 0:
		var frag := than.substr(i_frag)
		t("fragment() doc vi tri CUC BO, khong doc thang VERTEX.y",
				frag.contains("v_y_cuc_bo / max(chieu_cao")
				and not frag.contains("VERTEX.y"))
	t("vertex() ghi vi tri cuc bo ra varying", than.contains("v_y_cuc_bo = VERTEX.y"))
	# Chieu: a = 0 o DAU o. Ban goc: `a = 0` ra v_colorEnd, tuc bo ba THU HAI la
	# mau o TREN — nen `mix` phai lay `mau_cuoi` truoc.
	t("tro nguoc chieu la loi: mix lay mau_cuoi truoc (a = 0 o dau o)",
			than.contains("mix(mau_cuoi.rgb, mau_dau.rgb, a)"))
	t("khong tron nguoc", not than.contains("mix(mau_dau.rgb, mau_cuoi.rgb, a)"))
	# `v_fragmentColor` cua ban goc: Godot 4.7 khong co MODULATE, nen mau node
	# phai lay tu COLOR.rgb trong vertex() — do la ca ly do co ham vertex().
	t("co ham vertex()", than.contains("void vertex()"))
	t("mau node lay tu COLOR.rgb trong vertex()",
			than.contains("v_mau_node = COLOR.rgb"))
	t("rgb = dai x mau node", than.contains("vec4(mau * v_mau_node, COLOR.a)"))
	t("alpha giu nguyen (nhan ca vec4 la loi im lang thu hai)",
			not than.contains("COLOR * v_mau_node"))
	t("KHONG doc alpha cua hai mau (ban goc khong co tham so alpha)",
			not than.contains("mau_dau.a") and not than.contains("mau_cuoi.a"))
	# Ban goc bo han rgb cua anh chu (`resultColor.r` chi den tu dai); Godot cung
	# vay, va o day con dung hon: khong doc lai anh thi khong the lay nham.
	t("KHONG doc lai anh chu", not than.contains("texture(TEXTURE"))


# 2. Noi day ---------------------------------------------------------------

func _kiem_noi_day() -> void:
	print("=== noi day (qua ma goc Lua) ===")
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		bad += 1
		return
	lua.run("local c = require('cocos'); require('bootstrap').install_cocos()", "cai")

	var a := lua._new_node("label")
	var b := lua._new_node("label")
	var eb := lua._new_node("label")
	var rong := lua._new_node("label")
	var c := lua._new_node("label")
	var d := lua._new_node("label")
	var spr := lua._new_node("sprite")
	# Ban goc khong co enableGradual o CCEditBox (bang bind: bon ban ghi deu o lop
	# 12), nen node mang type_name do KHONG duoc di duong nay.
	eb.set_meta("type_name", "CCEditBox")
	for n in [a, b, eb, rong, c, d]:
		n.size = Vector2(120, 30)
	root.add_child(a)
	root.add_child(b)
	# `resized` chi ban ra khi node THAT SU nam trong cay, va trong che do
	# `--script` thi `add_child` chua lam node vao cay ngay — phai qua mot khung.
	# Do duoc bang `thu_resize2.gd`: ngay sau `add_child` la `is_inside_tree() =
	# false` va 0 lan ban; sau mot khung la true va moi lan doi o ban ra mot lan.
	# Thieu buoc nay thi phep kiem duoi day do CHINH PHEP DO chu khong do code.
	await process_frame

	# `Control.size` khong xuong duoi co toi thieu duoc — khang dinh ma
	# `UiChuyenSac._chieu_cao` dua vao, do lai chu khong tin.
	var truoc := rong.size.y
	rong.size = Vector2(10, 5)
	t("Control.size bi kep o co toi thieu (nen size.y dung duoc lam mau so)",
			rong.size.y > 5.0 and rong.size.y >= rong.get_minimum_size().y,
			"size.y = %.1f, truoc %.1f" % [rong.size.y, truoc])

	_boc(lua, a, "A")
	_boc(lua, b, "B")
	_boc(lua, eb, "EB")
	_boc(lua, rong, "RONG")
	_boc(lua, c, "C")
	_boc(lua, d, "D")
	_boc(lua, spr, "SPR")

	# Chua bat: co phai false, va do la co KHOI TAO cua ban goc (ham dung Label
	# 0x4f8a24 ghi +0x3a0 = 0 chu khong phai 1).
	t("nhan chua bat: IsEnableGradualColor() tra false",
			not lua.run("return A:IsEnableGradualColor()", "hoi"))

	lua.run("A:enableGradual(255, 210, 100, 255, 255, 190)", "bat chuyen sac")
	var m: Material = a.material
	t("nhan: co vat lieu chuyen sac", m is ShaderMaterial, str(m))
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		t("vat lieu dung file shader cua ta", sm.shader == CS.SHADER)
		t("mau dau (o CUOI) = bo ba 1 / 255",
				_mau(sm.get_shader_parameter("mau_dau"), 255, 210, 100),
				str(sm.get_shader_parameter("mau_dau")))
		t("mau cuoi (o DAU) = bo ba 2 / 255",
				_mau(sm.get_shader_parameter("mau_cuoi"), 255, 255, 190),
				str(sm.get_shader_parameter("mau_cuoi")))
		t("chieu_cao = o cua nhan (30)", _so(sm.get_shader_parameter("chieu_cao"), 30.0),
				str(sm.get_shader_parameter("chieu_cao")))
	t("nhan: IsEnableGradualColor() tra true",
			lua.run("return A:IsEnableGradualColor()", "hoi"))
	t("getEnableGradualColor tra DUNG sau gia tri, dung thu tu",
			lua.run("""local t = {A:getEnableGradualColor()}
				return #t == 6 and t[1] == 255 and t[2] == 210 and t[3] == 100
					and t[4] == 255 and t[5] == 255 and t[6] == 190""", "hoi"))

	# Vat lieu theo TUNG node: ban goc giu hai mau trong CHINH node, nen hai nhan
	# khac nhau khong the dung chung — khac `ui/xam.gd` / `ui/sang.gd`.
	lua.run("B:enableGradual(0, 255, 0, 0, 0, 255)", "bat cho nhan thu hai")
	t("hai nhan: hai vat lieu KHAC nhau", b.material != null and b.material != m)
	t("nhan 1 khong bi doi theo", _mau(
			(m as ShaderMaterial).get_shader_parameter("mau_dau"), 255, 210, 100))
	if b.material is ShaderMaterial:
		t("nhan 2 mang mau cua no",
				_mau((b.material as ShaderMaterial).get_shader_parameter("mau_dau"), 0, 255, 0))

	# Bat lai tren cung node: van mot vat lieu, va so luu lai doi theo.
	lua.run("A:enableGradual(10, 20, 30, 40, 50, 60)", "bat lai")
	t("bat lai: van mot vat lieu (khong chong hai cai)",
			a.material is ShaderMaterial and a.material == CS.cua(a))
	t("bat lai: mau doi theo", _mau(
			(a.material as ShaderMaterial).get_shader_parameter("mau_dau"), 10, 20, 30))
	t("bat lai: getEnableGradualColor tra so MOI",
			lua.run("""local t = {A:getEnableGradualColor()}
				return t[1] == 10 and t[6] == 60""", "hoi"))

	# Chieu cao la tham so nap tu ngoai, nen phai theo o khi o doi — bo cuc .xgg
	# dat o SAU khi node duoc tao.
	a.size = Vector2(120, 64)
	if a.material is ShaderMaterial:
		t("o doi 30 -> 64: chieu_cao theo kip",
				_so((a.material as ShaderMaterial).get_shader_parameter("chieu_cao"), 64.0),
				str((a.material as ShaderMaterial).get_shader_parameter("chieu_cao")))
	a.size = Vector2(120, 30)

	# Tat.
	lua.run("A:disableGradual()", "tat")
	t("tat: go vat lieu", a.material == null, str(a.material))
	t("tat: xoa ca meta cua vat lieu", CS.cua(a) == null)
	t("tat: IsEnableGradualColor() tra false",
			not lua.run("return A:IsEnableGradualColor()", "hoi"))
	t("tat: getEnableGradualColor tra sau so 0 (ban goc doc o chua khoi tao)",
			lua.run("""local t = {A:getEnableGradualColor()}
				return #t == 6 and t[1] == 0 and t[6] == 0""", "hoi"))
	t("tat hai lan khong hong gi", lua.run("A:disableGradual(); return true", "hoi"))

	# Vat lieu cua NGUOI KHAC thi khong duoc go — cung phep kiem nhu `verify_sang.gd`.
	b.material = CanvasItemMaterial.new()
	var cua_nguoi_khac := b.material
	lua.run("B:disableGradual()", "tat khi co vat lieu khac")
	t("tat KHONG go vat lieu cua nguoi khac", b.material == cua_nguoi_khac, str(b.material))
	b.material = null

	_kiem_khong_phai_nhan(lua, eb, spr, rong)
	_kiem_duong_man_hinh(lua, c, d)


func _kiem_khong_phai_nhan(lua: LuaRuntime, eb: Control, spr: Control, rong: Control) -> void:
	print("=== node khong phai nhan (ban goc khong co API nay) ===")
	lua.run("EB:enableGradual(255, 0, 0, 255, 0, 0)", "hop nhap chu")
	t("CCEditBox: KHONG mang vat lieu", eb.material == null, str(eb.material))
	t("CCEditBox: co van la false", not lua.run("return EB:IsEnableGradualColor()", "hoi"))

	lua.run("SPR:enableGradual(255, 0, 0, 255, 0, 0)", "sprite")
	t("sprite: KHONG mang vat lieu", spr.material == null, str(spr.material))
	t("sprite: co van la false", not lua.run("return SPR:IsEnableGradualColor()", "hoi"))

	# Ban goc doi DUNG sau tham so: ham boc 0x2cab6c dem roi `cmp r0,#6; bne` thi
	# in loi va thoat, KHONG lam gi. Thieu tham so o day cung phai vay.
	lua.run("EB:enableGradual(1, 2, 3, 4, 5)", "thieu tham so")
	t("thieu tham so: khong lam gi", eb.material == null and not
			lua.run("return EB:IsEnableGradualColor()", "hoi"), str(eb.material))

	# Nhan rong: mau so khong duoc la 0.
	rong.size = Vector2(0, 0)
	lua.run("RONG:enableGradual(255, 0, 0, 0, 0, 255)", "nhan rong")
	if rong.material is ShaderMaterial:
		var cao: float = (rong.material as ShaderMaterial).get_shader_parameter("chieu_cao")
		t("nhan rong: van nhan duoc va mau so khac 0", cao > 0.0, str(cao))
	else:
		t("nhan rong: van nhan duoc (khong crash)", false, str(rong.material))


# 3. Dung duong ma man hinh dung ------------------------------------------
#
# Ban goc to xam nhan chu bang `g_CUIPublic:SetEnableGradualLableGray`, va ham do
# co HAI tang cong ma mot phep kiem gia se khong bao gio cham toi:
#
#   * `if btnText.IsEnableGradualColor == nil or not(btnText:IsEnableGradualColor())
#     then goto Exit0 end` (CUIPublic.lua:441) — phai la true truoc da;
#   * luc TRA LAI no goi `enableGradual(c.r2, c.g2, c.b2, c.r2, c.g2, c.b2)`
#     (CUIPublic.lua:474): no LAM PHANG dai bang chinh bo ba THU HAI, chu khong
#     tra lai gradient goc. Do la quy cua ma goc, va phep kiem nay khoa luon THU
#     TU sau gia tri: neu `getEnableGradualColor` tra nguoc hai bo ba thi cho nay
#     ra (255,210,100) thay vi (255,255,190).
func _kiem_duong_man_hinh(lua: LuaRuntime, c: Control, d: Control) -> void:
	print("=== duong cua man hinh: g_CUIPublic:SetEnableGradualLableGray ===")
	# `g_CUIPublic` duoc tao ngay dong cuoi `sc/user/Public/CUIPublic.lua:649`
	# (`g_CUIPublic = CUIPublic:new()`), nhung nap file do mot minh thi chet ngay
	# dong 1 (`CUIPublic = class()`) vi `class` nam trong `share/class.lua`. Di
	# dung duong ma game di: `bootstrap.boot_goc()` — no nap ca khung suon ban goc
	# theo thu tu trong `sc/game.lua:174-183`, y nhu cac bo `verify_dimensions` /
	# `verify_richlabel` / `verify_plug` dang lam.
	var loi: Array = lua.errors.duplicate()
	var bao: Variant = lua.run("""
		local boot = require('bootstrap')
		boot.install_cocos()
		boot.install()
		local bao = boot.boot_goc()
		return bao.nap*1000 + bao.so
	""", "nap khung suon goc")
	if lua.errors.size() > loi.size():
		t("nap duoc khung suon goc", false, str(lua.errors[-1]))
		return
	t("nap duoc g_CUIPublic tu ma goc",
			lua.run("return g_CUIPublic ~= nil and g_CUIPublic.SetEnableGradualLableGray ~= nil", "hoi"),
			"nap %d/%d module" % [int(bao) / 1000, int(bao) % 1000])

	# Nhan CHUA tung bat chuyen sac: ham do phai bo qua (o day la nhan dang xam
	# theo duong Lua, khong phai duong shader).
	lua.run("D:setColor(50, 50, 50)", "to xam nhan D bang duong Lua")
	var truoc := d.modulate
	lua.run("g_CUIPublic:SetEnableGradualLableGray(D, true)", "nhan chua bat")
	t("chua bat chuyen sac: ham bo qua (khong gan vat lieu)", d.material == null)
	t("chua bat chuyen sac: khong doi trang thai",
			not lua.run("return D:IsEnableGradualColor()", "hoi"))
	t("chua bat chuyen sac: mau rieng cua nhan khong bi dung toi",
			d.modulate == truoc, str(d.modulate))

	# Nhan DANG bat: 255,210,100 -> 255,255,190 (dai vang sang tro).
	lua.run("C:enableGradual(255, 210, 100, 255, 255, 190)", "bat dai goc")
	lua.run("g_CUIPublic:SetEnableGradualLableGray(C, true)", "to xam")
	if c.material is ShaderMaterial:
		var sm := c.material as ShaderMaterial
		t("to xam: ca HAI dau dai thanh 192,192,192",
				_mau(sm.get_shader_parameter("mau_dau"), 192, 192, 192)
				and _mau(sm.get_shader_parameter("mau_cuoi"), 192, 192, 192),
				str(sm.get_shader_parameter("mau_dau")))
	t("to xam: vien chu thanh (0,0,0,125)",
			lua.run("local r,g,b,a = C:getEffectColor()\n"
					+ "return r == 0 and g == 0 and b == 0 and a == 125", "hoi"))
	t("to xam: co van la true", lua.run("return C:IsEnableGradualColor()", "hoi"))

	lua.run("g_CUIPublic:SetEnableGradualLableGray(C, false)", "tra lai")
	if c.material is ShaderMaterial:
		var sm2 := c.material as ShaderMaterial
		t("tra lai: LAM PHANG bang bo ba THU HAI (255,255,190) — quy cua ma goc",
				_mau(sm2.get_shader_parameter("mau_dau"), 255, 255, 190)
				and _mau(sm2.get_shader_parameter("mau_cuoi"), 255, 255, 190),
				str(sm2.get_shader_parameter("mau_dau")))
	t("tra lai: vien chu ve gia tri cu (chua tung dat vien -> 0,0,0,0)",
			lua.run("local r,g,b,a = C:getEffectColor()\n"
					+ "return r == 0 and g == 0 and b == 0 and a == 0", "hoi"))


func _boc(lua: LuaRuntime, node: Control, ten: String) -> void:
	lua.state.globals["_%s" % ten] = node
	lua.run("%s = require('cocos').wrap(_%s)" % [ten, ten], "boc %s" % ten)


## So sanh mot tham so mau cua vat lieu voi ba so 0..255.
func _mau(v: Variant, r: float, g: float, b: float) -> bool:
	if not (v is Color):
		return false
	var c := v as Color
	return _so(c.r, r / 255.0) and _so(c.g, g / 255.0) and _so(c.b, b / 255.0)


## So sanh float32 (Color cua Godot la float32) — dung sai 1e-6.
func _so(a: float, b: float) -> bool:
	return absf(a - b) < 0.000001
