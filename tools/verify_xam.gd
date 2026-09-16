# To xam: node VE nao doi sang shader xam, va trang thai ghi lai ra sao.
#
#   godot --headless --path . --script tools/verify_xam.gd
#
# Bo nay kiem PHAN NOI DAY — node nao, vat lieu nao, trang thai nao.
#
# Phan HINH (shader ra dung con so nao) do bang `tools/do_xam.gd`, va bo do phai
# chay CO trinh ve that (trinh ve gia khong dung `SubViewport`, xem ghi chu dau
# `tools/do_tron.gd`) nen no khong nam trong `check.py`. Chia hai nua nhu vay la
# CO Y: o day khong doc duoc mot diem anh nao, nen cung khong gia vo la da do
# hinh.
#
# Cong thuc cua shader thi VAN kiem duoc o day, bang cach DOC CHINH FILE
# `.gdshader`: mot he so sai (vi du Rec.709 thay vi Rec.601) la loi IM LANG —
# anh van ra, chi la ra sai mau — nen phai co mot cho chan no lai.
extends SceneTree

const XAM := preload("res://ui/xam.gd")

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
	_kiem_noi_day()
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# 1. Cong thuc trong file .gdshader ---------------------------------------

func _kiem_file_shader() -> void:
	print("=== file shader ===")
	var ma := FileAccess.get_file_as_string("res://ui/xam.gdshader")
	t("doc duoc ui/xam.gdshader", not ma.is_empty())
	if ma.is_empty():
		return
	# Chi doc THAN ham: phan chu thich dau file co nhac lai nguyen van ban goc,
	# ke ca dong `v_fragmentColor = a_color` — neu khong cat ra thi phep kiem
	# "than ham khong dung v_fragmentColor" se tu bao sai.
	var cat := ma.find("shader_type")
	t("co dong shader_type", cat >= 0)
	if cat < 0:
		return
	var than := ma.substr(cat)

	var re := RegEx.new()
	re.compile("vec3\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)")
	var m := re.search(than)
	t("co bo he so vec3(...)", m != null)
	if m == null:
		return
	var a := float(m.get_string(1))
	var b := float(m.get_string(2))
	var c := float(m.get_string(3))
	t("he so la Rec.601 (0.299 / 0.587 / 0.114)",
			absf(a - 0.299) < 1e-9 and absf(b - 0.587) < 1e-9 and absf(c - 0.114) < 1e-9,
			"%.4f / %.4f / %.4f" % [a, b, c])
	t("he so KHONG phai Rec.709",
			absf(a - 0.2126) > 1e-6 and absf(b - 0.7152) > 1e-6 and absf(c - 0.0722) > 1e-6)
	t("he so cong lai bang 1 (khong doi do sang)",
			absf(a + b + c - 1.0) < 1e-9, "%.9f" % (a + b + c))
	t("alpha lay tu ANH (t.a), khong tu node",
			than.contains("vec4(grey, grey, grey, t.a)"))
	t("than ham khong dung v_fragmentColor", not than.contains("v_fragmentColor"))
	t("doc anh qua texture(TEXTURE, UV)", than.contains("texture(TEXTURE, UV)"))


# 2. Noi day ---------------------------------------------------------------

func _kiem_noi_day() -> void:
	print("=== noi day (qua ma goc Lua) ===")
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		bad += 1
		return
	lua.run("local c = require('cocos'); require('bootstrap').install_cocos()", "cai")

	# Dung DUNG bo tao node cua game (`_new_node`), khong tu dung lai: co vay
	# bon loai duoi day moi la bon loai ma game that su dung.
	var spr := lua._new_node("sprite")
	var sca := lua._new_node("scale9")
	var lbl := lua._new_node("label")
	var mau := lua._new_node("mau")
	lua.state.globals["_SPR"] = spr
	lua.state.globals["_SCA"] = sca
	lua.state.globals["_LBL"] = lbl
	lua.state.globals["_MAU"] = mau
	lua.run("""
		local c = require('cocos')
		SPR, SCA, LBL, MAU = c.wrap(_SPR), c.wrap(_SCA), c.wrap(_LBL), c.wrap(_MAU)
	""", "boc node")

	_kiem_sprite(lua, spr)
	_kiem_scale9(lua, sca, spr)
	_kiem_nhan(lua, lbl)
	_kiem_lop_mau(lua, mau)

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	spr.free()
	sca.free()
	lbl.free()
	mau.free()


func _kiem_sprite(lua: LuaRuntime, spr: Control) -> void:
	lua.run("SPR:setGray(true)", "xam sprite")
	t("sprite: co vat lieu xam", spr.material == XAM.vat_lieu(),
			str(spr.material))
	t("sprite: vat lieu la ShaderMaterial dung file shader",
			spr.material is ShaderMaterial
			and (spr.material as ShaderMaterial).shader == XAM.SHADER)
	t("sprite: isGray() doc lai true", lua.run("return SPR:isGray()", "hoi") == true)

	# Bat hai lan / tat hai lan: khong duoc de lai vat lieu cung hay loi.
	lua.run("SPR:setGray(true)", "xam lai")
	t("sprite: xam hai lan thi van mot vat lieu", spr.material == XAM.vat_lieu())
	lua.run("SPR:setGray(false)", "thoi xam")
	t("sprite: thoi xam thi go vat lieu", spr.material == null, str(spr.material))
	t("sprite: isGray() doc lai false", lua.run("return SPR:isGray()", "hoi") == false)
	lua.run("SPR:setGray(false)", "thoi xam lan hai")
	t("sprite: thoi xam hai lan khong hong gi", spr.material == null)

	# Vat lieu CUA NGUOI KHAC thi khong duoc go. Duong nay khong cham toi
	# (`setGray` chi di qua TextureRect/NinePatchRect, con `SngRig` gan vat lieu
	# cho `Sprite2D`), nhung giu phep kiem thi khong bao gio lam mat do cua ai.
	spr.material = CanvasItemMaterial.new()
	var cua_nguoi_khac := spr.material
	lua.run("SPR:setGray(false)", "thoi xam khi co vat lieu khac")
	t("sprite: thoi xam KHONG go vat lieu cua nguoi khac",
			spr.material == cua_nguoi_khac, str(spr.material))
	spr.material = null


func _kiem_scale9(lua: LuaRuntime, sca: Control, spr: Control) -> void:
	lua.run("SCA:setGray(true)", "xam scale9")
	t("scale9 (CCScale9Sprite): co vat lieu xam", sca.material == XAM.vat_lieu())

	# Hai node cung xam phai dung CHUNG mot vat lieu: shader khong co tham so nao
	# doi theo node, nen de ra ban rieng chi ton bo nho va them draw call.
	lua.run("SPR:setGray(true)", "xam sprite lai")
	t("hai node xam dung CHUNG mot vat lieu", spr.material == sca.material
			and spr.material == XAM.vat_lieu(), str(spr.material))
	lua.run("SPR:setGray(false); SCA:setGray(false)", "thoi xam ca hai")
	t("scale9: thoi xam thi go vat lieu", sca.material == null)
	t("sprite: thoi xam thi go vat lieu (lan hai)", spr.material == null)


func _kiem_nhan(lua: LuaRuntime, lbl: Label) -> void:
	# Ban goc to chu bang duong LUA chu khong bang shader: `CUIPublic:SetLableGray`
	# luu mau goc roi dat setColor(50,50,50) + setEffectColor(190,190,190). Dem
	# duoc 132 dong goi duong do, trong khi duong `setGray` tu xuong con chi co
	# 3 cho. Nen nhan KHONG duoc mang vat lieu xam — va mau chu VAN phai theo
	# setColor nhu thuong.
	lua.run("LBL:setGray(true)", "xam nhan")
	t("nhan: KHONG mang vat lieu xam", lbl.material == null, str(lbl.material))
	t("nhan: isGray() van ghi lai true", lua.run("return LBL:isGray()", "hoi") == true)
	lua.run("LBL:setColor(50, 50, 50)", "to chu xam bang duong Lua")
	var m := lbl.modulate
	t("nhan: duong Lua (setColor) van to duoc chu xam",
			absf(m.r - 50.0 / 255.0) < 0.002 and absf(m.g - m.r) < 0.002
			and absf(m.b - m.r) < 0.002, str(m))
	t("nhan: chu xam ma khong bi vat lieu xam de len", lbl.material == null)


func _kiem_lop_mau(lua: LuaRuntime, mau: ColorRect) -> void:
	# CCLayerColorRoundRect: CHUA LAM, va khong doan bua — xem ghi chu dai o
	# lua/cocos.lua:setGray. Kiem lai cho chac rang no khong bi gan nham vat lieu
	# xam: lop mau khong co anh, shader xam se doc anh TRANG mac dinh cua Godot
	# va lop mau bien thanh TRANG — sai ro rang.
	var truoc := mau.color
	lua.run("MAU:setGray(true)", "xam lop mau")
	t("lop mau: KHONG bi gan vat lieu xam", mau.material == null, str(mau.material))
	t("lop mau: mau cua chinh no khong bi doi", mau.color == truoc, str(mau.color))
	t("lop mau: isGray() van ghi lai true", lua.run("return MAU:isGray()", "hoi") == true)
