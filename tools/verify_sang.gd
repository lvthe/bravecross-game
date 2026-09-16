# Hieu ung sang (setGlow): node VE nao doi sang chuong trinh shader so 2, va
# trang thai cua node ra sao.
#
#   godot --headless --path . --script tools/verify_sang.gd
#
# Bo nay kiem PHAN NOI DAY — node nao, vat lieu nao. Phan HINH (shader ra dung
# con so nao) do bang `tools/do_sang.gd`, va bo do phai chay CO trinh ve that
# (trinh ve gia khong dung `SubViewport`) nen no khong nam trong `check.py`.
# Chia hai nua nhu vay la CO Y, y het `verify_xam.gd` / `do_xam.gd`.
#
# Cong thuc thi VAN kiem duoc o day bang cach DOC CHINH FILE `.gdshader`: he so
# sai (vi du 2,0 hay 1,2) la loi IM LANG — anh van ra, chi la ra sai do sang.
extends SceneTree

const SANG := preload("res://ui/sang.gd")
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
	var ma := FileAccess.get_file_as_string("res://ui/sang.gdshader")
	t("doc duoc ui/sang.gdshader", not ma.is_empty())
	if ma.is_empty():
		return
	# Chi doc THAN ham: phan chu thich dau file nhac lai NGUYEN VAN ban goc, ke ca
	# bon dong `texColor[i] = texColor[i] * factor` — khong cat ra thi phep kiem
	# ben duoi tu bao sai.
	var cat := ma.find("shader_type")
	t("co dong shader_type", cat >= 0)
	if cat < 0:
		return
	var than := ma.substr(cat)

	t("co hang so 1.5", than.contains("1.5"))
	t("rgb nhan hang so do", than.contains("COLOR.rgb * HE_SANG"))
	t("alpha KHONG nhan (giu COLOR.a)", than.contains("COLOR.a"))
	t("than ham KHONG doc lai anh (mau node phai con tac dung)",
			not than.contains("texture(TEXTURE"))
	t("than ham KHONG dung v_fragmentColor",
			not than.contains("v_fragmentColor"))
	# Nhan ba kenh rgb chu khong phai ca vec4: nhan ca vec4 thi alpha cung nhan
	# 1,5 — do la loi im lang thu hai co the co o day.
	t("KHONG nhan ca vec4", not than.contains("COLOR * HE_SANG"))


# 2. Noi day ---------------------------------------------------------------

func _kiem_noi_day() -> void:
	print("=== noi day (qua ma goc Lua) ===")
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		bad += 1
		return
	lua.run("local c = require('cocos'); require('bootstrap').install_cocos()", "cai")

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

	_kiem_sprite(lua, spr, sca)
	_kiem_nhan_va_lop_mau(lua, lbl, mau)
	_kiem_hai_hieu_ung(lua, spr, sca)

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	spr.free()
	sca.free()
	lbl.free()
	mau.free()


func _kiem_sprite(lua: LuaRuntime, spr: Control, sca: Control) -> void:
	lua.run("SPR:setGlow(true)", "sang sprite")
	t("sprite: co vat lieu sang", spr.material == SANG.vat_lieu(), str(spr.material))
	t("sprite: vat lieu la ShaderMaterial dung file shader",
			spr.material is ShaderMaterial
			and (spr.material as ShaderMaterial).shader == SANG.SHADER)

	lua.run("SPR:setGlow(true)", "sang lai")
	t("sprite: bat hai lan thi van mot vat lieu", spr.material == SANG.vat_lieu())
	lua.run("SCA:setGlow(true)", "sang scale9")
	t("scale9 (CCScale9Sprite): dung CHUNG mot vat lieu", sca.material == spr.material)
	lua.run("SPR:setGlow(false)", "thoi sang")
	t("sprite: thoi sang thi go vat lieu", spr.material == null, str(spr.material))
	lua.run("SPR:setGlow(false)", "thoi sang lan hai")
	t("sprite: thoi sang hai lan khong hong gi", spr.material == null)
	lua.run("SCA:setGlow(false)", "thoi sang scale9")

	# Ban goc KHONG ghi co nao len node (than ham 0x49d740 khong co mot lenh
	# `strb` nao, trong khi setGray ghi `[r0+0x23b] = b`), va bang bind cung khong
	# co `isGlow`/`getGlow`. Phep kiem phai dung `rawget`: bang `Node` co
	# `__index` tra ve ham "API chua lam", nen `Node.isGlow` KHONG BAO GIO la nil
	# o day — doc thang qua metatable thi phep kiem se luon sai.
	t("lop Node KHONG co isGlow (ban goc khong lo ra API nay)",
			not lua.run("return rawget(require('cocos').Node, 'isGlow') ~= nil", "hoi"))
	t("lop Node CO isGray (doi chieu: ban goc co, va ta cung co)",
			lua.run("return rawget(require('cocos').Node, 'isGray') ~= nil", "hoi"))

	# Vat lieu cua NGUOI KHAC thi khong duoc go — cung phep kiem nhu `verify_xam.gd`.
	spr.material = CanvasItemMaterial.new()
	var cua_nguoi_khac := spr.material
	lua.run("SPR:setGlow(false)", "thoi sang khi co vat lieu khac")
	t("sprite: thoi sang KHONG go vat lieu cua nguoi khac",
			spr.material == cua_nguoi_khac, str(spr.material))
	spr.material = null


func _kiem_nhan_va_lop_mau(lua: LuaRuntime, lbl: Label, mau: ColorRect) -> void:
	# Nhan (Label) va lop mau (CCLayerColorRoundRect) KHONG co `setGlow` o ban goc:
	# bang bind chi ra 3 lop, ca ba deu co anh. Nen chung khong duoc mang vat lieu
	# — chu cua nhan la atlas chu mau TRANG, nhan se ra TRANG.
	lua.run("LBL:setGlow(true)", "sang nhan")
	t("nhan: KHONG mang vat lieu sang", lbl.material == null, str(lbl.material))
	lua.run("MAU:setGlow(true)", "sang lop mau")
	var truoc := mau.color
	t("lop mau: KHONG mang vat lieu sang", mau.material == null, str(mau.material))
	t("lop mau: mau cua chinh no khong bi doi", mau.color == truoc, str(mau.color))
	lua.run("LBL:setGlow(false); MAU:setGlow(false)", "thoi")


func _kiem_hai_hieu_ung(lua: LuaRuntime, spr: Control, sca: Control) -> void:
	# Hai hieu ung dung CUNG mot o chuong trinh cua node (`vfunc_0x158`), nen:
	#   * bat cai sau thi cai truoc MAT (khong phai hai vat lieu chong nhau);
	#   * tat mot cai la tra node ve chuong trinh THUONG, tuc xoa luon cai kia —
	#     do la hanh vi cua ban goc, va la cho de lam sai nhat.
	print("=== hai hieu ung tren cung mot node ===")
	lua.run("SPR:setGray(true)", "xam")
	t("sau setGray(true): vat lieu xam", spr.material == XAM.vat_lieu())
	lua.run("SPR:setGlow(true)", "roi sang")
	t("setGlow(true) sau setGray(true): doi sang vat lieu SANG (cai sau thang)",
			spr.material == SANG.vat_lieu(), str(spr.material))
	lua.run("SPR:setGray(true)", "xam lai")
	t("setGray(true) sau setGlow(true): doi lai vat lieu XAM",
			spr.material == XAM.vat_lieu(), str(spr.material))
	lua.run("SPR:setGlow(false)", "tat sang khi dang xam")
	t("setGlow(false) khi dang xam: tra ve chuong trinh THUONG (go ca vat lieu xam)",
			spr.material == null, str(spr.material))

	lua.run("SPR:setGlow(true)", "sang")
	lua.run("SPR:setGray(false)", "tat xam khi dang sang")
	t("setGray(false) khi dang sang: cung tra ve chuong trinh THUONG",
			spr.material == null, str(spr.material))
	t("scale9: van khong dinh gi", sca.material == null, str(sca.material))
