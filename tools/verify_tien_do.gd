# Thanh / vong tien do cua ban goc (CCProgressTimer -> ui/tien_do.gd,
# lua/tien_do.lua).
#
#   godot --headless --path . --script tools/verify_tien_do.gd
#
# BO NAY KIEM PHAN TINH DUOC. Bon tang:
#
#   1. Hinh hoc thanh (`o_thanh`): neo theo kieu va tinh CAT chu khong phong to
#      — ca hai deu la thu DA DO tren ban goc, khong phai lua chon cua ta.
#   2. Hinh hoc vong (`quat_vong`): quat nam gon trong o, goc bat dau, chieu
#      quet, va bon goc o khong bi vat.
#   3. Noi day tu bo cuc THAT: node thanh phai la TienDo, o lay theo BAN GHI
#      (khong theo anh), kieu va phan tram phai dung so trong JSON.
#   4. Noi day tu phia Lua: `setPercentage` / `setType` cua lop gia lap phai
#      doi dung node Godot, va `setOrange` phai doi MAU chu khong doi HINH.
#
# Phan HINH (diem anh that) khong do o day: `--headless` dung trinh ve gia nen
# khong doc duoc diem anh nao (xem ghi chu dau `tools/do_tron.gd`), va o day
# cung khong gia vo la da do hinh.
extends SceneTree

const HUD := "res://layout_ref/Game_UI_Control_Panel_960_640.json"
const NAP := "res://layout_ref/UI_LoadingGame.json"
const NGOAI := "res://layout_ref/UI_WarSoul_960_640.json"

## Dung sai cho phep khi doi chieu toa do diem. Bon goc o duoc dung lai bang
## luong giac (huong -> toi_bien -> c + h*d) nen lech vai phan nghin diem anh
## la binh thuong; nguong nay nho hon mot diem anh va lon hon sai so do.
const EPS_DIEM := 0.05

var ok := 0
var bad := 0


func t(ten: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % note) if note else ""])


func _init() -> void:
	_kiem_thanh()
	_kiem_vong()
	_kiem_bo_cuc()
	_kiem_lua()
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# 1. Thanh: neo va tinh CAT ------------------------------------------------

func _kiem_thanh() -> void:
	print("=== 1. hinh hoc thanh ===")
	# Dung DUNG cap so cua ban goc: o 360x15 (s9Blood_1 trong HUD) va anh that
	# cua no la 362x14 (ui_ref: sngSplitData/v6/ui_blood_23). Lech nay la co
	# that, nen phep kiem phai chay tren no — dung so dep 100x100 thi khong lo
	# ra loi "lay anh lam o".
	var co := Vector2(360, 15)
	var anh := Vector2(362, 14)
	var cap := [[TienDo.LR, "lr", true], [TienDo.RL, "rl", true],
			[TienDo.BT, "bt", false], [TienDo.TB, "tb", false]]
	for m in cap:
		var k: int = m[0]
		var ten: String = m[1]
		var ngang: bool = m[2]
		var neo := []
		var dai_rong := []
		for p in [5.0, 25.0, 50.0, 99.0]:
			var o := TienDo.o_thanh(k, p, co, anh)
			t("%s p=%d: co ve" % [ten, int(p)], o.size() == 2)
			if o.size() != 2:
				continue
			var src := o[0] as Rect2
			var dst := o[1] as Rect2
			# CAT chu khong PHONG TO: vung anh lay ra phai dung bang t phan tram
			# kich thuoc anh, va vung ve dung bang t phan tram o. Phong to thi o
			# ve van dung ti le do nhung ANH lay ra se la CA TAM anh — tuc
			# src.size luon bang kich thuoc anh o moi p.
			var t_ := float(p) / 100.0
			var dai := src.size.x if ngang else src.size.y
			var dai_o := dst.size.x if ngang else dst.size.y
			var tong := anh.x if ngang else anh.y
			var tong_o := co.x if ngang else co.y
			t("%s p=%d: vung anh = %.0f%% chieu dai anh" % [ten, int(p), p],
					absf(dai - tong * t_) < 0.02, "%f vs %f" % [dai, tong * t_])
			t("%s p=%d: vung ve = %.0f%% o" % [ten, int(p), p],
					absf(dai_o - tong_o * t_) < 0.02,
					"%f vs %f" % [dai_o, tong_o * t_])
			# Mep NEO: mep khong chay. Voi thanh ngang la x (lr) hoac x + w (rl);
			# voi thanh doc la y (tb) hoac y + h (bt). Do la phep phan biet bon
			# kieu voi nhau — doan nao sai thi thanh chay nguoc chieu.
			match k:
				TienDo.LR:
					neo.append(dst.position.x)
				TienDo.RL:
					neo.append(dst.position.x + dst.size.x - co.x)
				TienDo.TB:
					neo.append(dst.position.y)
				TienDo.BT:
					neo.append(dst.position.y + dst.size.y - co.y)
			dai_rong.append(dai_o)
		t("%s: mep neo dung yen o moi phan tram" % ten,
				not neo.is_empty() and neo.all(func(v): return absf(v) < EPS_DIEM),
				str(neo))
		# Neo dung yen ma do dai KHONG tang thi node khong lam gi ca.
		t("%s: do dai ve lon dan theo phan tram" % ten,
				dai_rong.size() == 4 and dai_rong[0] < dai_rong[1]
				and dai_rong[1] < dai_rong[2] and dai_rong[2] < dai_rong[3],
				str(dai_rong))

	# Hai dau: p = 100 phu KIN ca o lan anh; p = 0 khong ve gi.
	var full := TienDo.o_thanh(TienDo.LR, 100.0, co, anh)
	t("p=100: vung ve bang DUNG o cua ban ghi",
			full.size() == 2 and (full[1] as Rect2).size.is_equal_approx(co), str(full))
	t("p=100: vung anh bang DUNG kich thuoc anh that (362x14, khong phai 360x15)",
			full.size() == 2 and (full[0] as Rect2).size.is_equal_approx(anh), str(full))
	t("p=0: khong ve gi (ban goc cung vay: 10 node p=0 tren toan bo du lieu)",
			TienDo.o_thanh(TienDo.LR, 0.0, co, anh).is_empty())
	t("p am: khong ve gi", TienDo.o_thanh(TienDo.LR, -5.0, co, anh).is_empty())
	t("p qua 100: bi kep ve 100",
			(TienDo.o_thanh(TienDo.LR, 500.0, co, anh)[1] as Rect2).size.x == co.x)
	t("o rong 0: khong ve gi (chia cho 0)",
			TienDo.o_thanh(TienDo.LR, 50.0, Vector2(0, 0), anh).is_empty())
	# Kieu la: khong ve gi chu khong roi vao nhanh nao. 0/1 la vong, 2..5 la
	# thanh, nen chi con 6.. la la.
	t("kieu la (9): khong ve thanh", TienDo.o_thanh(9, 50.0, co, anh).is_empty())


# 2. Vong ------------------------------------------------------------------

func _kiem_vong() -> void:
	print("=== 2. hinh hoc vong ===")
	# Dung o 81x81 cua thanh nap game (ptLoadingGamePercent) — node vong DUY NHAT
	# trong toan bo du lieu co chay that.
	var co := Vector2(81, 81)
	var anh := Vector2(81, 81)
	var c := co * 0.5

	var kieu := [[TienDo.CW, "cw"], [TienDo.CCW, "ccw"]]
	var goc_theo_kieu := {TienDo.CW: [], TienDo.CCW: []}
	for m in kieu:
		var k: int = m[0]
		var ten: String = m[1]
		var quet := 180.0                    # p = 50
		var dau := 0.0 if k == TienDo.CW else 360.0 - quet
		var q := TienDo.quat_vong(k, 50.0, co, anh)
		t("%s p=50: co quat" % ten, not q.is_empty())
		if q.is_empty():
			continue
		var diem: PackedVector2Array = q["diem"]
		var uv: PackedVector2Array = q["uv"]
		t("%s: uv cung so diem va bat dau o TAM" % ten,
				uv.size() == diem.size() and uv[0].is_equal_approx(Vector2(0.5, 0.5)))
		t("%s: diem dau tien la tam o" % ten, diem[0].is_equal_approx(c), str(diem[0]))
		# MOI diem phai nam trong o: quat lay diem tren BIEN cua o (qua _toi_bien)
		# chu khong phai tren duong tron ban kinh lon, neu khong thi ve tran ra
		# ngoai o. uv = diem / co nen uv cung phai trong [0, 1].
		var tran := 0
		var uv_sai := 0
		for i in diem.size():
			var d := diem[i]
			if d.x < -EPS_DIEM or d.y < -EPS_DIEM or d.x > co.x + EPS_DIEM or d.y > co.y + EPS_DIEM:
				tran += 1
			if uv[i].x < -0.001 or uv[i].y < -0.001 or uv[i].x > 1.001 or uv[i].y > 1.001:
				uv_sai += 1
		t("%s: khong diem nao ve tran ra ngoai o" % ten, tran == 0, "%d diem tran" % tran)
		t("%s: uv nam trong [0,1]" % ten, uv_sai == 0, "%d uv sai" % uv_sai)
		# Chieu quet: moi diem phai nam trong CUNG quet ke tu goc bat dau.
		# Doi chieu bang chinh `_goc` (0 = 12 gio, chieu duong = kim dong ho)
		# chu khong so sanh voi 180 — goc 360 va goc 0 la CUNG mot huong.
		var sai := 0
		for i in range(1, diem.size()):
			var lech := fposmod(TienDo._goc(diem[i] - c) - dau, 360.0)
			if lech > quet + 0.01:
				sai += 1
		t("%s: moi diem nam trong cung quet cua no" % ten, sai == 0,
				"%d diem sai chieu" % sai)
		# Nua vong phai khac nua kia: ccw quet tu 180 lui ve 0 chu khong tu 0 len.
		# Ghi lai TAP GOC chu khong dem theo nguong 180 — goc 360 va goc 0 la
		# cung mot huong, dem theo nguong thi mau bien cua ccw bi tinh sai.
		for i in range(1, diem.size()):
			goc_theo_kieu[k].append(snappedf(TienDo._goc(diem[i] - c), 0.1))

	# Hai chieu phai cho ra hai nua vong KHAC NHAU. Neu ca hai ra cung mot tap
	# thi `quat_vong` da bo qua tham so kieu. Chung DUNG HAI goc la phai: hai
	# nua vong gap nhau o 12 gio va 6 gio chu khong roi nhau.
	var chung := 0
	var rieng := 0
	for g in goc_theo_kieu[TienDo.CW]:
		if goc_theo_kieu[TienDo.CCW].has(g):
			chung += 1
		else:
			rieng += 1
	t("cw va ccw cho ra hai nua vong khac nhau (chung toi da 2 goc gap nhau)",
			chung <= 2 and rieng >= 30, "%d goc chung, %d goc rieng" % [chung, rieng])

	var day := TienDo.quat_vong(TienDo.CW, 100.0, co, anh)
	t("p=100: co quat", not day.is_empty())
	if not day.is_empty():
		var diem: PackedVector2Array = day["diem"]
		# Bon goc cua o phai co MAT trong danh sach diem: quat quet 360 do ma bo
		# goc thi bi vat bon goc — o 28x28 hut toi 2 diem anh moi goc, o 81x81
		# cua man nap nhin thay han.
		var can := [Vector2(0, 0), Vector2(co.x, 0), Vector2(0, co.y), co]
		var thieu := 0
		for g in can:
			if not _co_diem(diem, g):
				thieu += 1
		t("p=100: quat co du bon goc cua o", thieu == 0, "thieu %d" % thieu)
	t("p=0: vong khong ve gi", TienDo.quat_vong(TienDo.CW, 0.0, co, anh).is_empty())


func _co_diem(diem: PackedVector2Array, g: Vector2) -> bool:
	for d in diem:
		if d.distance_to(g) < EPS_DIEM:
			return true
	return false


# 3. Noi day tu bo cuc that -------------------------------------------------

func _kiem_bo_cuc() -> void:
	print("=== 3. noi day tu bo cuc ===")
	t("CCProgressTimer duoc xep vao kind 'progress', khong phai 'layer'",
			XggLayout.kind_of_type("CCProgressTimer") == "progress")

	# Man Ngoai: g_ptWarSoulTBar la node kieu 4 (bt). O trong ban ghi 71x297,
	# con anh that (ui_ref: sngSplitData/v6/ui_background499) la 102x324 — lech
	# that, nen day cung la cho kiem "o lay theo ban ghi, khong theo anh".
	var man := XggLayout.build(NGOAI)
	t("dung duoc UI_WarSoul", man != null)
	if man != null:
		var nd := XggLayout.find_node(man, "g_ptWarSoulTBar")
		t("tim thay g_ptWarSoulTBar", nd != null)
		if nd != null:
			t("la node TienDo", nd is TienDo, str(nd.get_class()))
			if nd is TienDo:
				var td := nd as TienDo
				t("kieu = 4 (bt) dung nhu ban ghi", td.kieu == 4, str(td.kieu))
				t("phan tram = 100 nhu ban ghi", absf(td.pct - 100.0) < 0.001, str(td.pct))
				t("o lay theo BAN GHI 71x297, khong theo anh 102x324",
						td.size.is_equal_approx(Vector2(71, 297)), str(td.size))
				t("co anh (ten doc thang tu ban ghi)",
						td.anh != null and td.anh.get_size().is_equal_approx(Vector2(102, 324)),
						str(td.anh))
		man.free()

	# Man nap game: ptLoadingGamePercent la node DUY NHAT co ten anh o +0xE4
	# (khong phai +0xEC nhu 323 node kia), la node vong DUY NHAT chay that, va
	# la node DUY NHAT ma ban goc tu goi setType — trong S_CCCallFunc cua
	# sc/user/UI/CUIDownload.lua:57-69, dao "cw" roi "ccw".
	var nap := XggLayout.build(NAP)
	t("dung duoc UI_LoadingGame", nap != null)
	if nap != null:
		var nd := XggLayout.find_node(nap, "ptLoadingGamePercent")
		t("tim thay ptLoadingGamePercent", nd != null)
		if nd != null:
			t("la node TienDo", nd is TienDo, str(nd.get_class()))
			if nd is TienDo:
				var td := nd as TienDo
				t("kieu = 0 (cw) dung nhu ban ghi", td.kieu == 0, str(td.kieu))
				t("o = 81x81 theo ban ghi", td.size.is_equal_approx(Vector2(81, 81)),
						str(td.size))
				t("anh lay tu o +0xE4 (loading_2.png 81x81)",
						td.anh != null and td.anh.get_size().is_equal_approx(Vector2(81, 81)),
						str(td.anh))
		nap.free()

	# HUD: 60 node thanh, 48 trong so do kieu 3 (rl) — thanh mau. Truoc day
	# (khong co kind 'progress') ca 60 bi coi la sprite va ve DAY DAC o moi
	# phan tram: node 'layer' co anh thi thanh 'sprite', ma sprite thi khong
	# biet phan tram.
	var hud := XggLayout.build(HUD)
	t("dung duoc HUD", hud != null)
	if hud != null:
		var dem := {"co": 0, "kieu": {}, "tien_do": 0, "anh": 0}
		_di_qua(hud, dem)
		t("HUD co 60 node thanh (dung so do tren JSON)", dem["co"] == 60, str(dem["co"]))
		t("tat ca deu la node TienDo", dem["tien_do"] == dem["co"],
				"%d/%d" % [dem["tien_do"], dem["co"]])
		t("48 node kieu 3 (rl) — thanh mau", dem["kieu"].get(3, 0) == 48, str(dem["kieu"]))
		t("khong node nao mang kieu la",
				dem["kieu"].keys().all(func(k): return k >= 0 and k <= 5), str(dem["kieu"]))
		# Dung MOT node khong co ten anh o ca hai cho (+0xE4 lan +0xEC): node
		# 'CCProgressTimer' 40x40. No phai la TienDo chu khong phai sprite, va
		# khong co anh thi _draw khong ve gi — dung, vi ban goc cung khong co gi
		# de ve.
		t("59/60 node co anh, dung 1 node khong co ten anh nao",
				dem["anh"] == 59, "%d/60" % dem["anh"])
		hud.free()


func _di_qua(nd: Node, dem: Dictionary) -> void:
	for c in nd.get_children():
		if String(c.get_meta("type_name", "")) == "CCProgressTimer":
			dem["co"] += 1
			if c is TienDo:
				dem["tien_do"] += 1
				var k: int = (c as TienDo).kieu
				dem["kieu"][k] = dem["kieu"].get(k, 0) + 1
				if (c as TienDo).anh != null:
					dem["anh"] += 1
		_di_qua(c, dem)


# 4. Noi day tu phia Lua ----------------------------------------------------

func _kiem_lua() -> void:
	print("=== 4. noi day tu Lua (lop gia lap) ===")
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc Lua: %s" % ", ".join(lua.errors))
		bad += 1
		return
	lua.run("local c = require('cocos'); require('bootstrap').install_cocos()", "cai")

	# Node mang type_name 'CCProgressTimer' — wrap() phai boc no bang lop CUA TA
	# (c.lop_theo_loai), khong phai bang Node chung. Do la ca co che: cocos.lua:86
	# chon __index theo meta 'type_name' cua node.
	var td := TienDo.new()
	td.name = "ptThu"
	td.set_meta("type_name", "CCProgressTimer")
	td.size = Vector2(360, 15)
	td.kieu = TienDo.LR
	root.add_child(td)
	lua.state.globals["_PT"] = td
	lua.run("""
		local c = require('cocos')
		PT = c.wrap(_PT)
	""", "boc node")
	t("wrap() chon lop tien do theo meta type_name",
			lua.run("return PT.setPercentage == require('cocos').tien_do.setPercentage",
					"hoi lop") == true)

	lua.run("PT:setPercentage(30)", "dat 30%")
	t("setPercentage(30) doi node Godot", absf(td.pct - 30.0) < 0.001, str(td.pct))
	t("getPercentage() doc lai dung 30",
			lua.run("return PT:getPercentage()", "hoi") == 30.0)
	lua.run("PT:setPercentage('75')", "dat bang chuoi so")
	t("setPercentage('75') cung chay (ma goc co cho truyen chuoi)",
			absf(td.pct - 75.0) < 0.001, str(td.pct))
	lua.run("PT:setPercentage('khong-phai-so')", "chuoi khong phai so")
	t("setPercentage chuoi la: giu nguyen, khong thanh NaN",
			absf(td.pct - 75.0) < 0.001, str(td.pct))
	lua.run("PT:setPercentage(150)", "qua 100")
	t("phan tram bi kep o 100 (node tu kep trong dat_pct)",
			absf(td.pct - 100.0) < 0.001, str(td.pct))

	# setType: sau ten cua engine, thu tu trong bang phuong thuc (ROADMAP muc 4).
	# Cho goi THAT trong ma goc la thanh nap game, dao "cw" roi "ccw".
	t("setType('cw') -> kieu 0, tra true",
			lua.run("return PT:setType('cw')", "kieu") == true and td.kieu == 0,
			str(td.kieu))
	t("setType('ccw') -> kieu 1", lua.run("return PT:setType('ccw')", "kieu") == true
			and td.kieu == 1, str(td.kieu))
	t("setType('rl') -> kieu 3 (node kieu 3 trong HUD la thanh mau)",
			lua.run("return PT:setType('rl')", "kieu") == true and td.kieu == 3,
			str(td.kieu))
	t("setType('khong-co') -> false va KHONG doi kieu",
			lua.run("return PT:setType('khong-co')", "kieu") == false and td.kieu == 3,
			str(td.kieu))
	t("setType(4) bang ma so cung chay", lua.run("return PT:setType(4)", "kieu") == true
			and td.kieu == 4, str(td.kieu))
	t("setType(9) ngoai bang -> false",
			lua.run("return PT:setType(9)", "kieu") == false and td.kieu == 4,
			str(td.kieu))
	t("getType() doc lai dung 4", lua.run("return PT:getType()", "hoi") == 4)

	# setOrange DA LAM (6 cho goi trong ma goc — 12 dong, moi cho mot cap
	# true/false). Bon dieu phai dung:
	#
	#   (a) no KHONG con nam trong bang THIEU: dat ten that roi thi khong duoc
	#       dem la thieu nua;
	#   (b) he so phai DUNG bang so doc tu nguon shader Orange
	#       (`.rodata 0x7cd0c1`), khong duoc "don dep" cho dep;
	#   (c) doi no chi doi MAU, khong doi HINH — ban goc chi doi chuong trinh
	#       shader, con da giac tien do khong ai cham vao. Chinh (c) la ly do
	#       nhanh `false` — nhanh DUY NHAT ban nay di qua (`IS_OPEN_LANGUAGE =
	#       false` nen khong bao gio ra "en") — khong lam hinh doi mot diem anh
	#       nao: do duoc 0/921.600 diem bang work/emu_pt.py --cam.
	var truoc: int = lua.run(
			"return require('cocos').missing.setOrange or 0", "dem truoc")
	lua.run("return PT:setOrange(true)", "goi setOrange true")
	var sau: int = lua.run("return require('cocos').missing.setOrange or 0", "dem sau")
	t("setOrange KHONG con nam trong bang THIEU (da lam that)", sau == truoc,
			"truoc %d, sau %d" % [truoc, sau])

	t("setOrange(true) -> orange = true", td.orange == true)
	t("he so Orange = dung so nguon (0,9 / 2,9 / 0,0)",
			absf(TienDo.HE_ORANGE.r - 0.9) < 1e-6
			and absf(TienDo.HE_ORANGE.g - 2.9) < 1e-6
			and absf(TienDo.HE_ORANGE.b - 0.0) < 1e-6, str(TienDo.HE_ORANGE))
	t("mau ve khi bat = he so Orange; khi tat = trang (khong doi gi)",
			td.mau_ve().is_equal_approx(TienDo.HE_ORANGE), str(td.mau_ve()))
	t("setOrange(false) -> tra false, orange = false, mau ve = trang",
			lua.run("return PT:setOrange(false)", "goi setOrange false") == false
			and td.orange == false and td.mau_ve().is_equal_approx(Color(1, 1, 1, 1)),
			str(td.mau_ve()))
	t("setOrange(nil) -> false (khong duoc bat bua)", lua.run(
			"return PT:setOrange()", "goi setOrange khong doi so") == false
			and td.orange == false)

	# (c): vung VE phai giong het khi bat va khi tat — chi mau doi.
	var o_tat: Array = TienDo.o_thanh(TienDo.LR, 50.0, Vector2(200, 20), Vector2(200, 20))
	var o_tat_vong: Dictionary = TienDo.quat_vong(TienDo.CW, 50.0,
			Vector2(40, 40), Vector2(40, 40))
	lua.run("return PT:setOrange(true)", "bat lai")
	var o_bat: Array = TienDo.o_thanh(TienDo.LR, 50.0, Vector2(200, 20), Vector2(200, 20))
	var o_bat_vong: Dictionary = TienDo.quat_vong(TienDo.CW, 50.0,
			Vector2(40, 40), Vector2(40, 40))
	t("setOrange chi doi mau: vung ve THANH giong het khi bat va khi tat",
			o_tat == o_bat, "%s vs %s" % [str(o_tat), str(o_bat)])
	t("setOrange chi doi mau: quat VONG giong het khi bat va khi tat",
			o_tat_vong == o_bat_vong, str(o_tat_vong))
	lua.run("return PT:setOrange(false)", "tra ve tat")

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	td.free()
