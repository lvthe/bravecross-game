# Kiem ngung nghia O CHU / autoFixSize cua nhan — theo so DO TU BAN GOC.
#
#   godot --headless --path . --script tools/verify_dimensions.gd
#
# Chay DUNG chuoi buoc ma `brave-cross/work/emu_nhan.py` da do tren ban goc that
# (may ao Android, cac dong NHAN|), roi doi chieu voi LUAT — khong doi chieu
# diem anh: font cua ta khac tahoma (do duoc: chu dai o co 20 -> ta 1211, goc
# 1128; "ngan" -> ta 49, goc 44), nen chi LUAT moi so sanh duoc.
#
# So mong doi duoc tinh LAI tu API font cua Godot trong chinh khoi Lua duoi day
# (khong di qua cocos.lua), nen phep kiem khong the "tu dung" theo loi cua no.
#
# Cac con so cua ban goc (nhan that `ttfPopDialogContent` / `ttfPopDialogTitle`
# cua Pop_Dialog_UI_960_640.xgg, va nhan tao bang Label:new()):
#
#   o 200x0  + chu dai     -> (200, 168)      o 400x40 + chu dai, sau fix -> (1128, 40)
#   o 200x0  + chu ngan    -> (200, 24)       o 100x0  + chu dai, sau fix -> (1128, 24)
#   o 200x30 + chu ngan    -> (200, 30)       o 0x0    + "ngan",  sau fix -> (44, 24)
#   o 100x40 + chu dai     -> (103, 40)       o 250x40 + ""              -> (250, 0)
#   nhan .xgg chua dung toi -> (400, 80)      nhan tao luc chay: o = (0, 0)
#
# Va scale cua autoFixSize: 0,97087377309799 (100/103, so CU da do),
# 0,35460993647575 (400/1128), 0,24509803950787 (100/408), 1 (vua o), 0 (o cao 0).
extends SceneTree

var ok := 0
var bad := 0


func t(name: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [name, ("  (%s)" % note) if note else ""])


func _init() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return

	var r = lua.run(_KIEM, "dimensions")
	if r == null:
		print("Lua hong: %s" % ", ".join(lua.errors))
		quit(1)
		return

	# 1. Nhan trong bo cuc, CHUA AI DUNG TOI: ca getContentSize lan getDimensions
	#    tra dung o ghi trong .xgg (ban goc: (400, 80)). Day cung la duong nhanh
	#    ma 742 cho goi getContentSize cua ma goc di qua, nen phai giu.
	t("nhan .xgg chua dung toi tra dung o",
			_khop(r, "1-o", "1-mong"), "%s / %s" % [r.get("1-o", "?"), r.get("1-mong", "?")])
	t("nhan .xgg getDimensions cung tra o do",
			_khop(r, "1b-o", "1b-mong"), "%s / %s" % [r.get("1b-o", "?"), r.get("1b-mong", "?")])
	# O that cua tieu de trong .xgg la 250x40 — khop con so do duoc tu ban goc.
	t("o tieu de trong .xgg la (250, 40)",
			_gan(r, "15-dim", [250.0, 40.0]), str(r.get("15-dim", "?")))

	# 2. setString roi doc: o co ca hai chieu thi tra DUNG O (chu ngan hay dai
	#    deu vay) — ban goc do (400, 80).
	t("setString roi doc tra o", _gan(r, "2-o", [400.0, 80.0]), str(r.get("2-o", "?")))

	# 3. O chi co be rong: x = o, y = cao chu da xuong dong.
	t("o 200x0: x = o, y = cao chu", _khop(r, "3-o", "3-mong"),
			"%s / %s" % [r.get("3-o", "?"), r.get("3-mong", "?")])
	# 4. Doi chu NGAY SAU setDimensions(o cao 0) phai do LAI. Day chinh la loi da
	#    bat duoc: co "ban" chi duoc bat khi kich thuoc node co chieu bang 0, ma
	#    sau setDimensions(200, 0) kich thuoc node lai la cao chu (~153) nen no
	#    khong bat — lan doc sau tra so CU.
	t("setString sau setDimensions(200,0) do lai",
			_khop(r, "4-o", "4-mong"),
			"%s / %s  (so CU se la %s)" % [r.get("4-o", "?"), r.get("4-mong", "?"), r.get("3-o", "?")])
	# ... va cao tra ve phai la cao MOT DONG (~23-24 o co 20): tra so CU thi no la
	# cao NHIEU dong cua chu dai, tuc bang cua buoc 3.
	t("... va cao tra ve la cao MOT DONG cua chu ngan",
			_dang(r, "4-o")[1] <= 30.0, str(r.get("4-o", "?")))

	# 5. O co ca hai chieu thi y = o.
	t("o 200x30: y = 30", _gan(r, "5-o", [200.0, 30.0]), str(r.get("5-o", "?")))

	# 6. Chu VUOT o: ban goc cho mot dong dai 103 > o 100 (bo ngat dong cua no
	#    de dong vuot o); Godot khong bao gio de dong vuot o nen x = 100. Ghi nhan
	#    khac biet nay chu khong gia vo la giong.
	t("o 100x40: y = o, x <= o",
			absf(_dang(r, "6-o")[1] - 40.0) <= 0.51 and _dang(r, "6-o")[0] <= 100.51,
			"%s  (ban goc 103 vi bo ngat dong cua no cho vuot o)" % [r.get("6-o", "?")])

	# 7. autoFixSize khi so CU dang sach: ti le ngang = 1 (ban goc 0,9708 vi so
	#    CU cua no la 103).
	t("autoFixSize voi so CU da do -> scale 1", absf(_so(r, "7-scale") - 1.0) <= 1e-6,
			str(r.get("7-scale", "?")))

	# 8. Co autoFix (+0x21c) KHONG bi setDimensions xoa (ma may 0x4f6750 khong he
	#    cham +0x21c): o 300x200 voi chu ngan -> (300, 200) va scale DUNG 1.
	#    Ban goc do duoc dung the (buoc 87-88 cua luot 3).
	t("sau autoFix, doi o + chu ngan -> (300, 200)", _gan(r, "8-o", [300.0, 200.0]),
			str(r.get("8-o", "?")))
	t("... va scale dung 1", absf(_so(r, "8-scale") - 1.0) <= 1e-6, str(r.get("8-scale", "?")))

	# 9. O rong 0: be rong lay theo CHU (ban goc: 0x0 + "ngan" -> (44, 24)).
	t("o 0x0: lay theo chu", _khop(r, "9-o", "9-mong"),
			"%s / %s" % [r.get("9-o", "?"), r.get("9-mong", "?")])
	t("o 0x0: getDimensions tra (0, 0)", _gan(r, "9b-o", [0.0, 0.0]), str(r.get("9b-o", "?")))

	# 10. Nhan TAO LUC CHAY co o = (0, 0) nhung van bao be rong chu (ban goc luot 3,
	#     buoc 81-85) — neu ta lay kich thuoc node lam o thi ra so CU.
	t("nhan tao luc chay co o (0, 0)", _gan(r, "11-dim", [0.0, 0.0]), str(r.get("11-dim", "?")))
	t("... va getContentSize = be rong chu", _khop(r, "11-o", "11-mong"),
			"%s / %s" % [r.get("11-o", "?"), r.get("11-mong", "?")])
	t("... doi chu thi be rong theo chu MOI", _khop(r, "11c-o", "11c-mong"),
			"%s / %s" % [r.get("11c-o", "?"), r.get("11c-mong", "?")])

	# 11. Mot tu dai khong co cho ngat: x = max(o, be rong chu), scale = o/chu.
	t("mot tu dai trong o 100x40", _khop(r, "12-o", "12-mong"),
			"%s / %s" % [r.get("12-o", "?"), r.get("12-mong", "?")])
	t("autoFixSize: scale = o rong / be rong chu",
			absf(_so(r, "13-scale") - _so(r, "13-mong")) <= 1e-6,
			"%s / %s" % [r.get("13-scale", "?"), r.get("13-mong", "?")])

	# 12. O cao 0 -> ti le doc = 0 nen nhan BIEN MAT (quirk that cua ban goc: do
	#     ra 0 ba lan). Godot khong giu duoc dung 0 — dat scale (0,0) roi doc lai
	#     ra 0,00001 (do rieng, ca Control lan Node2D) — nen doi <= 1e-4.
	t("o cao 0 -> scale 0 (Godot chan thanh 1e-5)",
			_so(r, "14-scale") <= 1e-4, str(r.get("14-scale", "?")))
	t("o cao 0 -> x van lay theo chu", _khop(r, "14-o", "14-mong"),
			"%s / %s" % [r.get("14-o", "?"), r.get("14-mong", "?")])

	# 13. setContentSize ghi THANG cap +0x5c/+0x60 ma getContentSize tra ve, va
	#     KHONG xoa co "ban" (ma may 0x49bdcc; do duoc o luot 4, buoc 91-99b).
	#     Ba lan doc lien nhau, dung thu tu may ao:
	#       sau setString("") + setContentSize(0,0) -> (250, 0)  (lan bo cuc THANG)
	#       setContentSize(0,0) lan hai, luc nay da sach -> (0, 0)  (cap vua ghi)
	#       setContentSize(123,45)                      -> (123, 45) (cap vua ghi)
	#     Tuc la: con "ban" thi bo cuc lai ghi de, da sach thi ghi thang.
	t("chu RONG trong o 250x40 -> (250, 0)", _gan(r, "15c-o", [250.0, 0.0]),
			str(r.get("15c-o", "?")))
	t("... lan ghi thu hai (da sach) tra dung cap vua ghi",
			_gan(r, "15d-o", [0.0, 0.0]), str(r.get("15d-o", "?")))
	t("... ghi cap khac cung tra dung cap do", _gan(r, "15e-o", [123.0, 45.0]),
			str(r.get("15e-o", "?")))
	t("setContentSize KHONG doi o", _gan(r, "15g-o", [250.0, 40.0]),
			str(r.get("15g-o", "?")))

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _so(r, k) -> float:
	return float(str(r.get(k, "0")))


# So sanh co SAI SO, khong so sanh bang: o .xgg di qua `Vector2` (float32) nen
# 80 doc lai thanh 79,999992370605, va be rong chu do bang API font cua Godot
# cung khong bao gio trung tuyet doi voi con so ma cocos.lua tinh ra. Nua diem
# anh la nguong dung — no nho hon moi khac biet that (ban goc lech 3% be rong
# dong vi bo ngat dong khac), va lon hon sai so lam tron float32.
const SAI_SO := 0.51


func _dang(r, k) -> Array:
	var s := str(r.get(k, ""))
	var ph := s.split(",")
	var out: Array = []
	for p in ph:
		out.append(float(p))
	return out


func _gan(r, k: String, mong: Array) -> bool:
	var thuc := _dang(r, k)
	if thuc.size() != mong.size():
		return false
	for i in thuc.size():
		if absf(thuc[i] - mong[i]) > SAI_SO:
			return false
	return true


func _khop(r, k1: String, k2: String) -> bool:
	var a := _dang(r, k1)
	var b := _dang(r, k2)
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(a[i] - b[i]) > SAI_SO:
			return false
	return true


const _KIEM := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	boot.boot_goc()
	local C = require('cocos')
	local out = Dictionary()

	-- So mong doi tinh THANG tu API font cua Godot — khong qua cocos.lua, de
	-- phep kiem khong the tu dung theo loi cua chinh no. Node GOC lay bang
	-- C.raw(): lop Node cua ta chi lo ra API da lam, get_theme_font khong co
	-- trong so do.
	local function do_chu(l, cat)
		local gd = C.raw(l)
		local f = gd:get_theme_font('font')
		local co = gd:get_theme_font_size('font_size')
		local ms = f:get_multiline_string_size(gd.text, 0, cat > 0 and cat or -1, co)
		local lh = f:get_height(co)
		local n = math.max(1, math.floor(ms.y / lh + 0.5))
		return ms.x, n * lh + (n - 1) * gd:get_theme_constant('line_spacing')
	end

	-- Lua: (o rong, o cao, da autoFix) -> cap ma getContentSize phai tra.
	local function mong(l, ox, oy, da_fix)
		local cx, cy = do_chu(l, da_fix and 0 or ox)
		local rong = (cx <= 0 and cy <= 0)
		local w = (ox > 0 and cx <= ox) and ox or cx
		local h = ((oy > 0) and not rong) and oy or cy
		return tostring(w) .. ',' .. tostring(h)
	end

	local function chep(k, l)
		local w, h = l:getContentSize()
		out[k] = tostring(w) .. ',' .. tostring(h)
	end

	-- `getDimensions` tra HAI so, ma `tostring(f())` chi lay so DAU — phai huc
	-- rieng ra hai bien roi moi noi.
	local function dim(l)
		local w, h = l:getDimensions()
		return tostring(w) .. ',' .. tostring(h)
	end

	local FONT_TTF = GetStringWithKey('FONT_TTF')
	local ten = string.sub(FONT_TTF, 4, -1)
	local DAI = 'day la mot cau rat dai de do xem nhan tu xuong dong nhu the nao'
		.. ' va no dai them mot doan nua cho chac chan vuot 200 diem'

	loadLevelFile('conf/Pop_Dialog_UI_960_640.xgg')
	local n = rawget(_G, 'ttfPopDialogContent')

	chep('1-o', n)
	out['1-mong'] = '400,80'
	out['1b-o'] = dim(n)
	out['1b-mong'] = '400,80'

	n:setString(DAI)
	chep('2-o', n)

	n:setDimensions(200, 0)
	out['3-mong'] = mong(n, 200, 0, false)
	chep('3-o', n)

	n:setString('mot cau ngan thoi')
	out['4-mong'] = mong(n, 200, 0, false)
	chep('4-o', n)

	n:setDimensions(200, 30)
	chep('5-o', n)

	n:setDimensions(100, 40)
	n:setString(DAI)
	chep('6-o', n)
	n:autoFixSize()
	out['7-scale'] = tostring(n:getScaleX())

	n:setDimensions(300, 200)
	n:setString('ngan')
	n:autoFixSize()
	chep('8-o', n)
	out['8-scale'] = tostring(n:getScaleX())

	n:setDimensions(0, 0)
	out['9-mong'] = mong(n, 0, 0, true)
	chep('9-o', n)
	out['9b-o'] = dim(n)

	-- Nhan TAO LUC CHAY: o = (0, 0).
	local l2 = Label:new()
	l2:createWithTTF(DAI, ten, 20)
	out['11-dim'] = dim(l2)
	out['11-mong'] = mong(l2, 0, 0, false)
	chep('11-o', l2)
	l2:setString('ngan')
	out['11c-mong'] = mong(l2, 0, 0, false)
	chep('11c-o', l2)

	l2:setDimensions(100, 40)
	l2:setString(string.rep('A', 34))
	local wt = do_chu(l2, 0)
	out['12-mong'] = tostring(math.max(100, wt)) .. ',40'
	chep('12-o', l2)
	l2:autoFixSize()
	out['13-mong'] = tostring(100 / math.max(100, wt))
	out['13-scale'] = tostring(l2:getScaleX())

	local l3 = Label:new()
	l3:createWithTTF(DAI, ten, 20)
	l3:setDimensions(400, 0)
	l3:setString(DAI)
	l3:autoFixSize()
	out['14-scale'] = tostring(l3:getScaleX())
	out['14-mong'] = mong(l3, 400, 0, true)
	chep('14-o', l3)

	-- setContentSize: thu tu DUNG nhu may ao (luot 4, buoc 90-99b) — giua
	-- setString va phep doc dau tien khong doc gi, vi chinh phep doc moi xoa co
	-- 'ban', va setContentSize thi khong xoa.
	loadLevelFile('conf/Pop_Dialog_UI_960_640.xgg')
	local t = rawget(_G, 'ttfPopDialogTitle')
	out['15-dim'] = dim(t)
	t:setString('')
	t:setContentSize(0, 0)
	chep('15c-o', t)
	t:setContentSize(0, 0)
	chep('15d-o', t)
	t:setContentSize(123, 45)
	chep('15e-o', t)
	out['15g-o'] = dim(t)

	return out
"""
