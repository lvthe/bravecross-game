# Nut CHIEN DICH tren man Main — co MO duoc man chien dich khong, bang MOT cu
# cham THAT.
#
#   godot --headless --path . --script tools/verify_nut_chien_dich.gd
#
# Vi sao phai co bo kiem nay: `tools/do_chien_dich.gd` vao chien dich bang
# `g_CUINormalDlg:Show(g_CUISelectLevel:GetUIName(), {})` — dung duong cua ban
# goc, nhung no DI TAT qua chinh cai nut. Nen duong NGUOI CHOI di (cham vao
# toa nha [战役] tren man Main) chua tung duoc do lan nao.
#
# ---------------------------------------------------------------------------
# BAY DO DUOC, va la ly do bo kiem nay viet theo kieu "nha khung roi moi doc":
#
# Ca man hinh cua ban goc mo bang HOAT CANH TREO, khong phai bang mot lenh
# thang: `CUIMain.lua:251-254` xep
#
#     g_MainUIScene:runAction(S_CCSequence:create(
#         S_CCDelayTime:create(0),
#         S_CCCallFunc:create(g_CUIMain, "postOnMainShowBeginEvent")))
#
# ma `postOnMainShowBeginEvent` moi la cho POST `OnDialogShowBegin` — su kien
# `CGameFuncOpeningManager:OnDialogShow` nghe de di mo khoa cac nut chuc nang
# (an nhan khoa + het xam). Chuoi 4 chang cua `tools/vao_main.gd` DUNG NGAY khi
# `g_MainUIScene` len san khau, tuc la TRUOC khung hinh ke tiep — nen do trang
# thai ngay sau `chay()` la do mot khung hinh DONG BANG, va moi ket luan rut ra
# tu do deu sai. Do duoc: ngay sau `chay()` nhan khoa 5000 `hien=true`,
# `_getBuildingStatus` tra `1` (close), `_isBuildingOpen` tra `false`, bam tra
# `true` ma khong mo gi. Nha 5 khung: nhan `false`, status `2` (open).
#
# Cung ly do ay da ghi o `tools/quet_show.gd:118-127` cho `onVisible` cua moi
# man (no cung di qua mot `S_CCSequence(S_CCDelayTime, S_CCCallFunc)` tren
# rootUI, `CUIDialogAnimation.lua:86-95`) — va o do no gay dung mot phep do sai.
#
# `C.tick` KHONG dung duoc tu trong mot doan Lua cua bo do: `C` la mot BONG
# (`<bong C.actions>`), khong phai module that — `lua/actions.lua` nhan module
# that qua THAM SO (`return function(C)`), con `_G.C` khong he ton tai nen bi
# lop gia lap thay bang bong. Nen o day nha khung bang `lua.tick()` tu GDScript.
#
# ---------------------------------------------------------------------------
# Cong chuc nang la du lieu MAY CHU: `IsFuncOpening` doc
# `GameUserGlobalData['L_'..ten]`, ma bang ay chi ship dung MOT co. Nguoi choi
# offline la Lv1 (`G_UserLogic:GetLevel()` -> `true, 1`, do), con chien dich doi
# Lv22 — va so 22 ay nam trong KHOA NGON NGU `#MainUI_Unlock_AttackActivity`,
# tuc CHI la chu hien thi: khong co bang muc-tieu-cap nao doc duoc o client. Nen
# lop offline phat bieu "mo het" bang dung cong tac cua chinh ban goc
# (`g_CGameFuncOpeningManager.IsTest`, xem `lua/bootstrap.lua`), chu khong bia
# mot bang `L_*` nao.
#
# Khoi B va D la KIEM CHUNG NGUOC: tat cong tac di thi nut PHAI khoa lai va cu
# cham PHAI khong mo gi. Khong co chung thi mot bo kiem luon-xanh khong chung
# minh duoc gi.
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0
## So khung cho sau khi Main hien: du cho hoat canh treo `DelayTime(0)` chay
## (no xong trong DUNG mot khung) va cho `CGameFuncOpeningManager` lam xong.
const CHO := 30
## Ten nut chuc nang trong bang `self.tBuildingData` cua CUIMainBuildingManager.
const NUT := "btnMainUIAttackActivity"
## Man chien dich: `CUIMainBuildingManager:_btnMainUIAttackActivity` goi
## `g_CUINormalDlg:Show("BattleActivityMode")`.
const MAN := "BattleActivityMode"

var _dat := 0
var _hong := 0
var _lua: LuaRuntime
var _san: Control


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


func _init() -> void:
	_lua = LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	_lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not _lua.open():
		print("KHONG chay duoc: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true
	_san = Control.new()
	_san.size = _lua.cua_so_engine
	_san.scale = Vector2.ONE * (vp.y / _lua.cua_so_engine.y)
	_lua.set_stage(_san)
	_lua.set_touch_root(_san)
	get_root().add_child(_san)
	if _lua.run(VM._NAP, "nap") == null:
		print("nap hong: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	var d := VM.chay(_lua)
	if str(d["dung"]) != "":
		print("KHONG toi duoc Main, dung o: %s" % d["dung"])
		quit(1)
		return
	print("toi Main.")

	# --- A. Cong chuc nang tu mo sau khi nha khung -------------------------
	print("\nA. cong chuc nang tu mo (nha %d khung roi moi doc):" % CHO)
	var dong_bang := _doc()
	_ghi_chu(str(dong_bang["IsTest"]) == "true",
			"lop offline dat co IsTest = true (do: %s)" % dong_bang["IsTest"])
	# Trang thai DONG BANG — ghi ra de thay phep do co luc, khong phai de doi.
	print("   (ngay sau chay(), chua nha khung: nhan=%s status=%s isOpen=%s)"
			% [dong_bang["nhan"], dong_bang["status"], dong_bang["isOpen"]])
	_nha(CHO)
	var a := _doc()
	_ghi_chu(str(a["nhan"]) == "false",
			"nhan khoa 5000 (tag cua `pUnlockText`) da AN — do: %s" % a["nhan"])
	_ghi_chu(int(a["status"]) == 2,
			"_getBuildingStatus tra 2 (open) — do: %s" % a["status"])
	_ghi_chu(str(a["isOpen"]) == "true",
			"_isBuildingOpen tra true — do: %s" % a["isOpen"])
	_ghi_chu(str(dong_bang["nhan"]) == "true" and int(dong_bang["status"]) == 1,
			"doi chieu: luc CHUA nha khung thi nhan=%s status=%s — phep do doi theo KHUNG, khong phai mot con so chet"
			% [dong_bang["nhan"], dong_bang["status"]])

	# --- B. Kiem chung nguoc: tat cong tac thi nut KHOA lai -----------------
	print("\nB. kiem chung nguoc — tat cong tac IsTest:")
	_lua.run("g_CGameFuncOpeningManager.IsTest = false", "tat IsTest")
	_lua.run("g_CUIMain:RefreshUserLevelAndExp()", "refresh lai")
	_nha(CHO)
	var b := _doc()
	_ghi_chu(str(b["nhan"]) == "true", "tat cong tac: nhan khoa HIEN lai — do: %s" % b["nhan"])
	_ghi_chu(int(b["status"]) == 1,
			"tat cong tac: _getBuildingStatus ve 1 (close) — do: %s" % b["status"])
	_ghi_chu(str(b["isOpen"]) == "false",
			"tat cong tac: _isBuildingOpen ve false — do: %s" % b["isOpen"])

	# --- C. Cham THAT vao nut, bang duong nguoi choi di --------------------
	print("\nC. cham that vao nut [%s] (cong dang MO):" % NUT)
	_lua.run("g_CGameFuncOpeningManager.IsTest = true", "bat lai IsTest")
	_lua.run("g_CUIMain:RefreshUserLevelAndExp()", "refresh lai")
	_nha(CHO)
	var c0 := _doc()
	_ghi_chu(str(c0["isOpen"]) == "true", "cong mo lai truoc khi cham — do: %s" % c0["isOpen"])
	var bam := _bam()
	_nha(CHO)
	var c1 := _doc()
	print("   cham tai %s -> %s" % [bam[0], bam[1]])
	_ghi_chu(str(bam[1]) != "KHONG AI NHAN",
			"co node nhan cu cham (do: %s)" % bam[1])
	_ghi_chu(str(c1["manMo"]) == "true",
			"man %s MO ra (IsUiShow/IsUiVisible) — do: %s" % [MAN, c1["manMo"]])
	_ghi_chu(str(c1["dialog"]) == MAN,
			"g_CUINormalDlg.CurrentUIName = %s — do: %s" % [MAN, c1["dialog"]])

	# --- D. Kiem chung nguoc cho cu cham ----------------------------------
	# Dung lai tu dau: dong man chien dich, khoa cong, roi cham lai.
	print("\nD. kiem chung nguoc — khoa cong roi cham lai:")
	_lua.run("""
		pcall(function() g_CUINormalDlg:CloseImmediately() end)
		g_CUINormalDlg.IsUILock = false
		g_CUINormalDlg.CurrentUIName = nil
		g_CUINormalDlg.active = nil
		g_CUINormalDlg.AnimationList = {}
		g_CGameFuncOpeningManager.IsTest = false
		g_CUIMain:RefreshUserLevelAndExp()
	""", "dong man + khoa cong")
	_nha(CHO)
	var d0 := _doc()
	_ghi_chu(str(d0["manMo"]) == "false",
			"man chien dich da dong lai (do: %s)" % d0["manMo"])
	_ghi_chu(str(d0["isOpen"]) == "false", "cong da khoa lai — do: %s" % d0["isOpen"])
	var bam2 := _bam()
	_nha(CHO)
	var d1 := _doc()
	_ghi_chu(str(d1["manMo"]) == "false" and str(d1["dialog"]) != MAN,
			"cong khoa: cham KHONG mo duoc man chien dich (manMo=%s dialog=%s) — cu cham co bi gac that"
			% [d1["manMo"], d1["dialog"]])

	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)


func _nha(so: int) -> void:
	for i in so:
		_lua.tick(KHUNG)


## Doc trang thai cua nut va cua man chien dich. Mot luot Lua, nhieu cau hoi —
## de moi cau tra loi roi vao CUNG mot khung hinh.
func _doc() -> Dictionary:
	var r = _lua.run("""
		local c = require('cocos')
		local btn = _G['%s']
		local lab = btn ~= nil and btn:getChildByTag(5000) or nil
		-- Dictionary() chu KHONG phai {}: bang Lua thuong qua cau ra LuaTable,
		-- ma ham nay khai kieu tra ve la Dictionary nen GDScript nem loi kieu.
		-- Cung loi nay da gay o tools/quet_show.gd khong co — no cung dung
		-- Dictionary() (xem `_SAN_SANG`).
		local out = Dictionary()
		out.nhan = lab ~= nil and tostring(lab:getIsVisible()) or '(khong co nhan 5000)'
		out.status = tostring(g_CUIMainBuildingManager:_getBuildingStatus(btn))
		out.isOpen = tostring(g_CUIMainBuildingManager:_isBuildingOpen(btn))
		out.IsTest = tostring(g_CGameFuncOpeningManager.IsTest)
		local m = rawget(_G, 'g_CUIActivityMode')
		out.manMo = tostring(m ~= nil and (m.IsUiShow == true or m.IsUiVisible == true))
		out.dialog = tostring(g_CUINormalDlg.CurrentUIName)
		return out
	""" % NUT, "doc trang thai nut")
	if r == null:
		return {"nhan": "?", "status": "?", "isOpen": "?", "IsTest": "?",
				"manMo": "?", "dialog": "?"}
	return r


## Cham vao TAM nut bang dung duong cham cua ban goc (`touch_at` -> ten cham
## trong .xgg -> `onTouchEnd_<ten>` cua doi tuong nhan). Tra [toa do, ten node
## nhan] — goi thang ham thi bo qua dung cai phan dang nghi (nut co nhan cu
## bam khong).
func _bam() -> Array:
	var nut = _lua.run("return require('cocos').raw(_G['%s'])" % NUT, "nut")
	if not (nut is Control):
		return [Vector2.ZERO, "khong phai Control"]
	var c: Control = nut
	var p: Vector2 = LuaRuntime._bien_doi(c) * (c.size * 0.5)
	var an := _lua.touch_at("Begin", p)
	var nhan: Node = _lua._dang_cham
	_lua.touch_at("End", p)
	var ten := "KHONG AI NHAN"
	if an and nhan != null:
		ten = String(nhan.get_meta("xgg_name", nhan.get_meta("cls", nhan.name)))
	return [str(p.round()), ten]
