# O NHAP CHU cua engine (typeName 'CCEditBox') — ui/o_nhap.gd + lua/o_nhap.lua.
#
#   godot --headless --path . --script tools/verify_o_nhap.gd
#
# Truoc luot nay, ui/xgg_layout.gd xep 'CCEditBox' vao kind 'label': 40 o nhap
# trong 22 bo cuc thanh NHAN CHU — khong go duoc, va bay phuong thuc cua ma goc
# roi vao bo dem M.missing, khong mot loi nao.
#
# Bon phan, bon duong do doc lap:
#
#   1. DU LIEU (.xgg): dem lai 40 node / 22 file, ban ghi o nhap KHONG co
#      text/alignH/alignV/touch, va doi chieu anh nen voi o cua tung node.
#      Anh 30x30 dung cho o 150x30 .. 410x45 — do la can cu cho "ban goc CO GIAN
#      anh nen theo o", chu khong phai suy doan.
#   2. API: nam phuong thuc thuoc DUNG lop CCEditBox (bang bind cua engine), do
#      dai CO TRONG SO cua getTextWithLen doi chieu voi CHINH ham kiem cua ban
#      goc — g_CUIRegisterVerification:CheckNickName + getNickNameMaxLength
#      (VI = 16).
#   3. DUONG NGUOI CHOI: cham vao o -> tieu diem -> go phim THAT -> bon su kien
#      began / changed / ended / return ban ra ham Lua da dang ky.
#   4. XEN KE: o nhap nam duoi / nam tren mot node co ten cham.
extends SceneTree

const TAI_LIEU := "res://layout_ref/"
const ANH := "res://ui_ref/index.json"

var ok := 0
var bad := 0
var lua: LuaRuntime
var san: Control
var _login: Control = null       ## bo cuc UI_Login da dung (phan 2 va 3)
var _nen: Control = null         ## giu cac bo cuc KHONG duoc cham toi (phan 2)


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


func _init() -> void:
	_du_lieu()
	_api()
	# `root` (Window) chi nam trong cay SAU khung hinh dau tien — `_init` cua
	# SceneTree chay truoc khi vong lap chinh bat dau, va push_input doi
	# `is_inside_tree()`. Mot khung la du; phan 1 va 2 khong can.
	await process_frame
	await _duong_nguoi_choi()
	_xen_ke()
	if lua != null:
		for e in lua.errors:
			bad += 1
			print("  LOI Lua: ", e)
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# ---------------------------------------------------------------------------
# 1. Du lieu .xgg
# ---------------------------------------------------------------------------

var _anh_that := {}          # ten anh (khoa chi muc = ten tran, KHONG duoi) -> co that

func _do_anh() -> void:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(ANH))
	if doc is Dictionary:
		for k in doc.get("frames", {}):
			var f: Dictionary = doc["frames"][k]
			# Khoa cua chi muc khong co duoi ('sngSplitData/v6/ui_background189'),
			# con ten trong bo cuc thi co ('v6/ui_background189.png'). get_file()
			# o day la ten TRAN khong duoi — hai ben phai rut ve cung dang do.
			_anh_that[String(k).get_file()] = Vector2i(int(f.get("w", 0)), int(f.get("h", 0)))


## Co that cua mot ten anh trong bo cuc ('v6/ui_background189.png').
func _co_anh(ten: String) -> Vector2i:
	return _anh_that.get(ten.get_basename().get_file(), Vector2i.ZERO)


## Di het cay node cua mot bo cuc, goi f(n) voi moi node.
##
## f KHONG duoc cong vao bien CUC BO cua _du_lieu: ham lambda cua GDScript bat
## bien theo GIA TRI, nen `so_o += 1` trong do chi doi ban sao. Do duoc dung loi
## nay: bo dem ra 0 trong khi bang theo anh (kieu tham chieu) van day.
func _di(n: Dictionary, f: Callable) -> void:
	f.call(n)
	var con = n.get("children")
	if con is Array:
		for c in con:
			_di(c, f)


func _tong(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


## {co o: so lan} -> {"150x30": 6, ...} de so voi mot bang viet thang.
func _theo_co(d: Dictionary) -> Dictionary:
	var ra := {}
	for k in d:
		ra["%dx%d" % [k.x, k.y]] = int(d[k])
	return ra


func _du_lieu() -> void:
	_do_anh()
	var dem := {"o": 0, "file": 0, "text": 0, "cham": 0}
	var kieu_ban_ghi := {}
	var truong := {}         # ten truong -> so ban ghi co truong do
	var theo_anh := {}       # ten anh -> {kich thuoc o: so lan}
	var so_o_moi_file := {}
	for f in DirAccess.get_files_at("res://layout_ref"):
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string(TAI_LIEU + f))
		if not (doc is Dictionary):
			continue
		var trong_file := {"n": 0}
		for r in doc.get("roots", []):
			_di(r, func(n: Dictionary) -> void:
				if String(n.get("typeName", "")) != "CCEditBox":
					return
				dem["o"] += 1
				trong_file["n"] += 1
				for k in n.keys():
					truong[k] = int(truong.get(k, 0)) + 1
				var khoa := PackedStringArray(n.keys())
				khoa.sort()
				var ten_khoa := "|".join(khoa)
				kieu_ban_ghi[ten_khoa] = int(kieu_ban_ghi.get(ten_khoa, 0)) + 1
				if n.has("text"):
					dem["text"] += 1
				if String(n.get("touch", "")) != "" or String(n.get("touchObj", "")) != "":
					dem["cham"] += 1
				var ov := Vector2i(int(n.get("w", 0)), int(n.get("h", 0)))
				var ten_anh := String(n.get("img", "")).get_file()
				if not theo_anh.has(ten_anh):
					theo_anh[ten_anh] = {}
				theo_anh[ten_anh][ov] = int(theo_anh[ten_anh].get(ov, 0)) + 1)
		if int(trong_file["n"]) > 0:
			dem["file"] += 1
			so_o_moi_file[f] = int(trong_file["n"])

	# 40 node trong 22 file: do bang chinh phep dem nay. Con so nay la cai neo cho
	# moi phep do ben duoi (neu layout_ref dung lai thi no doi truoc tien).
	t("40 o nhap trong 22 bo cuc", int(dem["o"]) == 40 and int(dem["file"]) == 22,
			"%d node / %d file" % [int(dem["o"]), int(dem["file"])])
	t("UI_Login co 6 o, UI_AccountLogin co 8 o",
			int(so_o_moi_file.get("UI_Login_960_640.json", 0)) == 6
			and int(so_o_moi_file.get("UI_AccountLogin_960_640.json", 0)) == 8,
			"Login %d, AccountLogin %d" % [
				int(so_o_moi_file.get("UI_Login_960_640.json", 0)),
				int(so_o_moi_file.get("UI_AccountLogin_960_640.json", 0))])

	# Ban ghi o nhap co HAI hinh dang: 19 truong, hoac 20 truong khi co `fix`
	# (xgg.py chi ghi `fix` khi no khac rong). Hop lai dung 20 ten, va trong do
	# KHONG co text / alignH / alignV — do la ly do o nhap luon bat dau RONG va
	# khong co can chu nao doc duoc tu du lieu, khac han nhan (xem
	# ui/xgg_layout.gd nhanh "edit").
	var co := {}
	var so_truong := {}
	for kh in kieu_ban_ghi:
		so_truong[kh.split("|").size()] = int(so_truong.get(kh.split("|").size(), 0)) + int(kieu_ban_ghi[kh])
	t("moi ban ghi o nhap co 19 hoac 20 truong (19 + `fix` khi khac rong)",
			so_truong.size() == 2 and so_truong.get(19, 0) == 15 and so_truong.get(20, 0) == 25,
			"%s | %d kieu" % [str(so_truong), kieu_ban_ghi.size()])
	t("hop 20 ten truong, va KHONG co text / alignH / alignV",
			truong.size() == 20 and truong.get("fix", 0) == 25
			and not truong.has("text") and not truong.has("alignH") and not truong.has("alignV"),
			"%d truong: %s" % [truong.size(), str(truong.keys())])
	t("khong o nhap nao co chu san, khong o nhap nao co ten cham",
			int(dem["text"]) == 0 and int(dem["cham"]) == 0,
			"text %d, cham %d" % [int(dem["text"]), int(dem["cham"])])

	# Anh nen. Mot anh, nhieu co o — do la can cu cho "ban goc CO GIAN anh nen
	# theo o" (ui/ui_frames.gd, nhanh UiONhap), chu khong phai suy doan.
	var a189: Dictionary = theo_anh.get("ui_background189.png", {})
	t("ui_background189.png: 12 o, 5 co o khac nhau",
			_tong(a189) == 12 and a189.size() == 5,
			"%d o, %d co: %s" % [_tong(a189), a189.size(), str(_theo_co(a189))])
	t("  5 co do dung bang: 150x30 x6, 204x35 x2, 260x60 x2, 200x90, 410x45",
			_theo_co(a189) == {"150x30": 6, "204x35": 2, "260x60": 2,
					"200x90": 1, "410x45": 1}, str(_theo_co(a189)))
	var a402: Dictionary = theo_anh.get("ui_background402.png", {})
	t("v6/login/ui_background402.png: 7 o, 3 co o khac nhau (275x45 x5, 220x59, 100x50)",
			_tong(a402) == 7 and a402.size() == 3
			and _theo_co(a402) == {"275x45": 5, "220x59": 1, "100x50": 1},
			"%d o, %d co: %s" % [_tong(a402), a402.size(), str(_theo_co(a402))])
	t("ui_background189.png that su la 30x30", _co_anh("ui_background189.png") == Vector2i(30, 30),
			str(_co_anh("ui_background189.png")))
	t("v6/login/ui_background402.png that su la 59x59",
			_co_anh("v6/login/ui_background402.png") == Vector2i(59, 59),
			str(_co_anh("v6/login/ui_background402.png")))
	# O nho nhat dung anh 189 la 150x30 — rong gap 5 lan anh, cao bang anh. Khong
	# the la "o theo anh": theo anh thi ca 12 o nay da la 30x30.
	var nho_nhat := Vector2i(99999, 99999)
	for k in a189:
		nho_nhat.x = mini(nho_nhat.x, k.x)
		nho_nhat.y = mini(nho_nhat.y, k.y)
	t("o nho nhat dung anh 189 la 150x30 (rong gap 5 lan anh)",
			nho_nhat == Vector2i(150, 30), str(nho_nhat))
	# ui_button01.png (143x61) la ca ba o "verified" — va o cua chung DUNG BANG
	# anh. Tuc "verified" nghia la "co anh khop o", khong phai "doan ra ten anh".
	var a01: Dictionary = theo_anh.get("ui_button01.png", {})
	t("ui_button01.png (143x61): 3 o, ca ba dung 143x61",
			_tong(a01) == 3 and a01.size() == 1 and a01.get(Vector2i(143, 61), 0) == 3,
			"%d o: %s" % [_tong(a01), str(_theo_co(a01))])


# ---------------------------------------------------------------------------
# 2. API
# ---------------------------------------------------------------------------

## Nap Lua theo DUNG chuoi cua game that: install_cocos (ham engine), install
## (lop bong cua _G), boot (khung suon 17 module cua game.lua).
##
## Chuoi nay khong phai tu chon: `M.install()` CHI lap bang metatable cua _G,
## con danh sach module nam o `M.boot`. Do duoc ca hai chieu —
##   * chi install_cocos: moi ten la doc ra nil (khong co lop bong), nen
##     `require('user.UI.CUILogin')` chet ngay o `class` (CUILogin.lua:25);
##   * install_cocos + install (thieu boot): `class` van la bong vi
##     share.class nam trong FRAMEWORK, nen `CUIRegisterVerification = class()`
##     ra mot BONG — `getNickNameMaxLength()` tra ve '<bong ...>' chu khong loi.
## Va KDebug cung la bong khi thieu boot, ma `KDebug.ArgIsNumber` la thu
## nicknameFindGM hoi: thieu no thi nicknameFindGM tra TRUE voi MOI ten.
func _mo() -> bool:
	lua = LuaRuntime.new()
	if not lua.open():
		t("mo Lua", false, ", ".join(lua.errors))
		return false
	var nap := {
		"install_cocos": "require('bootstrap').install_cocos()",
		"install": "require('bootstrap').install()",
		"boot": "require('bootstrap').boot({})",
	}
	for ten in nap:
		var truoc := lua.errors.size()
		lua.run(nap[ten], "nap " + ten)
		if lua.errors.size() > truoc:
			t("nap %s" % ten, false, lua.errors[lua.errors.size() - 1])
	# Bon module ma CUILogin can ma khung suon khong co: hang so ngon ngu
	# (DEFAULT_LANGUAGE o share/Setting.lua:14), bang LANGUAGE, g_SetGame +
	# set_base, va chinh CUILogin.
	var them: String = str(lua.run("""
		local xau = {}
		for _, m in ipairs({'share.Setting', 'user.Globals.user_global',
				'user.Public.set', 'user.UI.CUILogin'}) do
			local ok, e = pcall(function() require(m) end)
			if not ok then xau[#xau + 1] = m .. ': ' .. tostring(e) end
		end
		return table.concat(xau, ' ;; ')
	""", "bon module"))
	t("nap du bon module cua CUILogin, khong loi", them == "", them)

	# respect_visible = false: bon o cua UI_Login nam trong lCreate / lLogin /
	# lRegister, ma ban ghi danh dau AN (ban goc hien chung ra sau, bang Lua).
	# Do la duong di THAT cua nguoi choi chu khong phai mot bo cuc khac.
	XggLayout.respect_visible = false
	san = Control.new()
	san.size = Vector2(960, 640)
	root.add_child(san)
	lua.set_stage(san)
	lua.set_touch_root(san)
	return true


## Dung mot bo cuc. `cham_duoc = false` thi no nam TRONG CAY (node con can
## is_inside_tree) nhung KHONG nam duoi goc cham: ca ba bo cuc deu 960x640 nen
## lop cham cua cai sau se phu len o nhap cua cai truoc, va cu cham se thuoc ve
## no. Do duoc dung loi nay: o nhan tieu diem = false va nhat ky rong, trong khi
## `touch_at` van tra true (node kia nuot Begin).
func _dung(file: String, cham_duoc := true) -> Control:
	var n := XggLayout.build(TAI_LIEU + file)
	if cham_duoc:
		san.add_child(n)
	else:
		if _nen == null:
			_nen = Control.new()
			_nen.size = Vector2(960, 640)
			root.add_child(_nen)
		_nen.add_child(n)
	return n


func _tim(n: Node, ten: String) -> Control:
	if n is Control and (n.name == ten or (n.has_meta("xgg_name")
			and String(n.get_meta("xgg_name")) == ten)):
		return n
	for c in n.get_children():
		var h := _tim(c, ten)
		if h != null:
			return h
	return null


## Nhan dau tien trong cay (de do `setText` tren mot node KHONG phai o nhap).
func _nhan(n: Node) -> Control:
	if n is Control and n.has_meta("kind") and String(n.get_meta("kind")) == "label":
		return n
	for c in n.get_children():
		var h := _nhan(c)
		if h != null:
			return h
	return null


## Chay mot doan Lua, doi khong loi. Tra ve gia tri.
##
## Doi `lua.errors` truoc/sau chu KHONG doi ket qua khac null: mot doan Lua chay
## TRON ma khong tra gi cung cho ra null (vd phep gan), nen `r == null` khong
## phan biet duoc "chay xong" voi "hong".
func _L(src: String, ten: String) -> Variant:
	var truoc := lua.errors.size()
	var r = lua.run(src, ten)
	if lua.errors.size() > truoc:
		t(ten, false, lua.errors[lua.errors.size() - 1])
		return null
	return r


func _api() -> void:
	if not _mo():
		return
	var login := _dung("UI_Login_960_640.json")
	_login = login
	var acct := _dung("UI_AccountLogin_960_640.json", false)

	# --- 2a. Bon cuc that: o nhap ra UiONhap, o theo BAN GHI, nen theo ANH ----
	var ten_o := ["ebUserLoginName", "ebUserLoginPassword", "ebRegisterUserName",
			"ebRegisterPassword", "ebRegisterPassword2", "ebCreateName"]
	var sai_kieu := 0
	var sai_o := 0
	var sai_nen := 0
	for ten in ten_o:
		var o := _tim(login, ten)
		if o == null or not (o is UiONhap):
			sai_kieu += 1
			continue
		if o.size != Vector2(150, 30):
			sai_o += 1
		if o.get_child_count() != 2 or o.get_child(0).name != UiONhap.TEN_NEN \
				or o.get_child(1).name != UiONhap.TEN_O_CHU:
			sai_nen += 1
		elif not (o.nen.texture is Texture2D):
			sai_nen += 1
		elif o.nen.texture.get_size() != Vector2(30, 30):
			sai_nen += 1
		elif not o.nen.visible:
			sai_nen += 1
	t("UI_Login: 6 o nhap deu la UiONhap", sai_kieu == 0, str(sai_kieu))
	t("UI_Login: o cua 6 o dung 150x30 nhu ban ghi", sai_o == 0, str(sai_o))
	t("UI_Login: o nao cung co nen + o chu, nen la anh 30x30 dang hien",
			sai_nen == 0, str(sai_nen))

	# O 220x59 dung anh 59x59: mot chieu bang anh, mot chieu khong — van la co
	# gian (theo chieu rong), nen khong duoc phep lay anh lam o.
	var rong := _tim(acct, "ebCreateName")
	var kieu_acct := 0
	if rong is UiONhap and rong.size == Vector2(220, 59) \
			and rong.nen.texture != null \
			and rong.nen.texture.get_size() == Vector2(59, 59):
		kieu_acct += 1
	t("UI_AccountLogin: ebCreateName 220x59 + nen 59x59", kieu_acct == 1, str(kieu_acct))

	var hero := _dung("UI_Hero_960_640.json", false)
	var q := _tim(hero, "ebUseQuantity")
	t("UI_Hero: ebUseQuantity 100x50 (nen 59x59, khac ca hai chieu)",
			q is UiONhap and q.size == Vector2(100, 50) and q.nen.texture != null
			and q.nen.texture.get_size() == Vector2(59, 59),
			("%s %s" % [str(q.size), str(q.nen.texture.get_size())]) if q is UiONhap else "khong phai UiONhap")

	var eb := _tim(login, "ebUserLoginName")
	lua.state.globals["_EB"] = eb
	_L("EB = require('cocos').wrap(_EB)", "boc EB")

	# --- 2b. Bay phuong thuc thuoc DUNG lop CCEditBox ------------------------
	# `rawget` chu khong phai `Node.getText`: Node co metatable tra ve mot ham
	# DEM cho moi ten la (do la cach M.missing hoat dong), nen `Node.getText`
	# KHONG he nil — no la bong. Bang Node that su khong co nam phuong thuc nay
	# (do duoc: ca nam deu nil), con hai phuong thuc can chu thi CO, vi moi nhan
	# trong bo cuc deu can duoc (8.968 nhan CCLabelTTF / 0 CCLabelBMFont).
	var hoi: String = str(_L("""
		local c = require('cocos')
		local n = 0
		for _, k in ipairs({'setText','getText','getTextWithLen','setMaxLength',
				'setLuaCallbackObjAndFunc'}) do
			if rawget(c.Node, k) == nil then n = n + 1 end
			if c.o_nhap[k] == nil then n = n + 100 end
		end
		local m = 0
		if rawget(c.Node, 'setHorizontalAlignment') == nil then m = m + 1 end
		if rawget(c.Node, 'setVerticalAlignment') == nil then m = m + 1 end
		return n .. '|' .. m .. '|' .. tostring(c.o_nhap == c.lop_theo_loai['CCEditBox'])
	""", "hoi lop"))
	t("5 phuong thuc chu: khong co o bang Node (5), co du o lop CCEditBox",
			hoi.begins_with("5|"), hoi)
	t("hai phuong thuc can chu co o bang Node (moi nhan deu can duoc)",
			hoi.contains("|0|"), hoi)
	t("lop_theo_loai['CCEditBox'] chinh la lop o nhap", hoi.ends_with("|true"), hoi)

	# --- 2c. Do dai co trong so, doi chieu voi chinh ham kiem cua ban goc -----
	# Cac so duoi day dem TAY theo tung DON VI UTF-16 (2 neu isWide, 1 neu khong):
	#   "Xin chào"   X i n ' ' c h = 6, à = 2 (0x00E0 co trong bang), o = 1  -> 9
	#   "àáâ"        ba muc 0x00E0/0x00E1/0x00E2, ca ba trong bang           -> 6
	#   "ăâđêôơư"    bảy muc 0x0103/0x00E2/0x0111/0x00EA/0x00F4/0x01A1/0x01B0 -> 14
	#   "你好"       0x4E00..0x9FBF                                         -> 4
	#   "😀"         ngoai BMP: mot cap surrogate, hai don vi deu KHONG rong -> 2
	#   "¡¢£"        0x00A1/0x00A2/0x00A3 — khong o khoang nao, khong o bang   -> 3
	#   "ỷ"          0x1EF7 = muc CUOI cua bang                              -> 2
	#   "ỹ"          0x1EF9 — NGOAI bang (bang dung o 0x1EF7)                 -> 1
	var dai: String = str(_L("""
		local f = require('cocos').o_nhap.do_dai
		local ds = {'', 'abc', 'Xin chào', 'àáâ', 'ăâđêôơư', '你好', '😀', 'A😀B',
				'¡¢£', 'ỷ', 'ỹ'}
		local out = {}
		for i, s in ipairs(ds) do out[i] = tostring(f(s)) end
		return table.concat(out, ',')
	""", "do dai"))
	# Hai chuoi trong so nay la duong LUA doc ra, khong phai ban sao ben GDScript.
	t("do dai co trong so: 0,3,9,6,14,4,2,4,3,2,1",
			dai == "0,3,9,6,14,4,2,4,3,2,1", dai)

	# Bang 134 muc: kiem HINH DANG chu khong chi kiem so muc. 133 muc KHONG nam
	# trong khoang nao (44 chu cai La-tinh co dau o Latin-1/Latin-Extended-A + 88
	# muc 0x1EA0..0x1EF7 + muc 0x0000 ket chuoi), dung 1 muc nam san trong khoang
	# (0x4565, thua — no da thuoc 0x31C0..0x4DFF), va ca 88 diem ma
	# 0x1EA0..0x1EF7 deu co mat. 133 + 1 = 134 khop voi so muc do duoc, va 44 +
	# 88 + 1 = 133: day la phep dem doc lap co the bat mot muc bi chep sai.
	var bang: String = str(_L("""
		local o = require('cocos').o_nhap
		local ngoai, trong, thieu = 0, 0, 0
		local co = {}
		for _, c in ipairs(o.BANG_RONG) do
			co[c] = true
			local rong = false
			for _, k in ipairs(o.DAI_RONG) do
				if c >= k[1] and c <= k[2] then rong = true end
			end
			if rong then trong = trong + 1 else ngoai = ngoai + 1 end
		end
		for c = 0x1EA0, 0x1EF7 do if not co[c] then thieu = thieu + 1 end end
		local x = ''
		if co[0x1EF8] or co[0x1EF9] then x = 'co' else x = 'khong' end
		return string.format('%d|%d|%d|%d|%d|%s', #o.BANG_RONG, ngoai, trong,
				thieu, #o.DAI_RONG, x)
	""", "bang rong"))
	t("BANG_RONG: 134 muc, 133 ngoai khoang, 1 trong khoang, du 88 muc 0x1EA0..0x1EF7",
			bang == "134|133|1|0|9|khong", bang)
	print("  -> bang trong so: ", bang)

	# Va day moi la CHO DOI CHIEU CO THAT: chay CHINH ham kiem cua ban goc tren
	# chinh ma cua no. Bon so do duoc:
	#   * getNickNameMaxLength(nil) = 16 — nhanh VI cua CUILogin.lua:112-125,
	#     va no chay duoc nghia la GetLanguageName() tra 'vi' (DEFAULT_LANGUAGE
	#     cua share/Setting.lua:14, vi g_SetGame:GetString tra nil khi chua
	#     LoadXgg) va LANGUAGE.VI = 'vi';
	#   * tham so truyen vao duoc tra lai nguyen (9 -> 9);
	#   * mot ten Viet 8 chu co dau = 16 don vi — VUA DUNG tran, con 9 chu = 18
	#     la qua (do bang chinh do_dai cua o nhap).
	#
	# Va mot KHOANG TRONG do duoc, ghi lai chu khong sua: ba ham LGG_* cua engine
	# (LGG_CheckNickName, LGG_CheckNickNameByLanguage, LGG_CheckNickNameIncludeVI,
	# LGG_CheckStringLegal) khong co ma Lua nao dinh nghia — chung la BONG, ma
	# bong thi truthy, nen `nicknameIsTrue(...) == false` va `if not bLegal` KHONG
	# BAO GIO dung: o ban dung, chuoi '@@@' lot qua phep kiem dinh dang. Do la
	# luat dinh dang nam trong C++ (`LGG_CheckNickName`), khong phai viec cua o
	# nhap — xem ROADMAP.
	var tran: String = str(_L("""
		local v = rawget(_G, 'g_CUIRegisterVerification')
		if v == nil then return 'KHONG CO g_CUIRegisterVerification' end
		local f = require('cocos').o_nhap.do_dai
		local viet = 'ăâđêôơưĐ'
		local a1, e1 = v:CheckNickName('Nguyen', f('Nguyen'), nil)
		local a2, e2 = v:CheckNickName(string.rep('a', 20), 20, nil)
		local a3, e3 = v:CheckNickName('@@@', 3, nil)
		return string.format('%d|%d|%d|%s|%s|%s|%s|%s|%s|%s',
				v:getNickNameMaxLength(nil), v:getNickNameMaxLength(9), f(viet),
				tostring(a1), tostring(e1), tostring(a2), tostring(e2),
				tostring(a3), type(LGG_CheckNickName), tostring(v:nicknameFindGM('Nguyen')))
	""", "tran ten"))
	var ph := tran.split("|")
	t("tran ten VI = 16 don vi; 8 chu co dau = 16 (vua tran), 9 chu = 18 (qua)",
			ph.size() == 10 and ph[0] == "16" and ph[1] == "9" and ph[2] == "16", tran)
	t("ten hop le: CheckNickName tra true, loi rong",
			ph.size() == 10 and ph[3] == "true" and ph[4] == "", tran)
	# Qua dai: bao loi, va loi do KHONG bi lop kiem dinh dang ghi de (lop do
	# khong chay duoc — xem khoang trong o tren).
	t("qua dai: tra false voi loi 'qua dai', khong phai loi dinh dang",
			ph.size() == 10 and ph[5] == "false" and ph[6] == "Register_createNicknameToLong",
			tran)
	t("KHOANG TRONG: '@@@' lot qua vi LGG_* la bong (truthy)",
			ph.size() == 10 and ph[7] == "true" and ph[8] == "table", tran)
	t("nicknameFindGM('Nguyen') = false (KDebug.ArgIsNumber chay that)",
			ph.size() == 10 and ph[9] == "false", tran)

	# --- 2d. Nam phuong thuc cua CCEditBox chay that -------------------------
	_L("EB:setText('Nguyen Van A')", "dat chu")
	t("setText / getText di vong", eb.lay_chu() == "Nguyen Van A", eb.lay_chu())
	# setText(nil) la NO-OP (ma may: 0x2d1cc5 so nil roi `beq` thoat ngay).
	_L("EB:setText(nil)", "dat nil")
	t("setText(nil) khong xoa o", eb.lay_chu() == "Nguyen Van A", eb.lay_chu())
	# getTextWithLen tra HAI gia tri.
	var hai: String = str(_L("""
		EB:setText('Xin chào')
		local s, n = EB:getTextWithLen()
		return s .. '|' .. n
	""", "hai gia tri"))
	t("getTextWithLen tra (chuoi, do dai)", hai == "Xin chào|9", hai)

	# setMaxLength: `vcvt.s32.f64` cat ve phia 0, va KHONG tu cat chu (don vi dem
	# cua widget trong khong khoi phuc duoc — xem ui/o_nhap.gd).
	_L("EB:setText('abcdef'); EB:setMaxLength(3.7)", "max len")
	t("setMaxLength(3.7) ghi lai 3", int(eb.get_meta("max_length", -1)) == 3,
			str(eb.get_meta("max_length", "-")))
	t("setMaxLength KHONG tu cat chu dang co", eb.lay_chu() == "abcdef", eb.lay_chu())

	# Can chu. LineEdit cua Godot 4.7 co `alignment` (thuoc tinh ten `alignment`,
	# ham dat ten `set_horizontal_alignment` — do ca hai danh sach) nhung KHONG
	# co can doc nao: khong mot thuoc tinh hay phuong thuc nao chua chu
	# 'vertical'. Nen can doc chi duoc GHI LAI, khong ve ra.
	_L("EB:setHorizontalAlignment(2); EB:setVerticalAlignment(2)", "can chu")
	t("setHorizontalAlignment(2) -> phai", eb.o_chu.alignment == HORIZONTAL_ALIGNMENT_RIGHT,
			str(eb.o_chu.alignment))
	t("setVerticalAlignment(2) -> ghi lai 2 (LineEdit khong ve duoc)",
			int(eb.get_meta("can_doc", -1)) == 2, str(eb.get_meta("can_doc", "-")))
	_L("EB:setHorizontalAlignment(9); EB:setVerticalAlignment(-1)", "can chu ngoai mien")
	t("can chu ngoai mien -> ve 0", eb.o_chu.alignment == HORIZONTAL_ALIGNMENT_LEFT
			and int(eb.get_meta("can_doc", -1)) == 0,
			"%d / %s" % [eb.o_chu.alignment, str(eb.get_meta("can_doc", "-"))])
	_L("EB:setHorizontalAlignment(1); EB:setVerticalAlignment(1)", "tra ve giua")

	# setLuaCallbackObjAndFunc: hai ten, lan sau ghi de lan truoc.
	_L("EB:setLuaCallbackObjAndFunc('g_Thu', 'khi_doi')", "dang ky")
	t("setLuaCallbackObjAndFunc luu hai ten",
			String(eb.get_meta("lua_cb_obj", "")) == "g_Thu"
			and String(eb.get_meta("lua_cb_ham", "")) == "khi_doi",
			"%s / %s" % [str(eb.get_meta("lua_cb_obj", "-")), str(eb.get_meta("lua_cb_ham", "-"))])
	_L("EB:setLuaCallbackObjAndFunc('g_Thu2', 'khac')", "dang ky lai")
	t("lan goi sau GHI DE lan truoc",
			String(eb.get_meta("lua_cb_obj", "")) == "g_Thu2"
			and String(eb.get_meta("lua_cb_ham", "")) == "khac",
			"%s / %s" % [str(eb.get_meta("lua_cb_obj", "-")), str(eb.get_meta("lua_cb_ham", "-"))])

	# --- 2e. Cong lop: chi o nhap moi co nam phuong thuc do ------------------
	# Node KHONG phai o nhap thi `setText` roi vao BONG dem cua `Node.__index`
	# (M.missing) — ham tra nil va khong lam gi. Do la cach duy nhat de phep kiem
	# nay khang dinh "nam phuong thuc khong thuoc lop khac" khi ban dung co
	# metatable tra ham dem cho MOI ten la: `nhan.getText` khong bao gio nil.
	var nhan := _nhan(login)
	lua.state.globals["_NHAN"] = nhan
	var dem: String = str(_L("""
		local c = require('cocos')
		local nhan = c.wrap(_NHAN)
		local truoc_chu = tostring(c.raw(nhan).text)
		local truoc = c.missing['setText'] or 0
		nhan:setText('khong duoc ghi')
		local sau = c.missing['setText'] or 0
		local truoc2 = c.missing['setText'] or 0
		EB:setText('ghi that')
		local sau2 = c.missing['setText'] or 0
		return string.format('%d|%d|%s|%s|%s', sau - truoc, sau2 - truoc2,
				tostring(truoc_chu == tostring(c.raw(nhan).text)), truoc_chu,
				tostring(c.raw(nhan).text))
	""", "cong lop"))
	# Nhan do co the dang RONG (chu duoc dat luc chay), nen phep kiem la "chu
	# khong doi" chu khong phai "chu khac rong".
	t("nhan: setText roi vao bo dem M.missing, chu KHONG doi",
			dem.begins_with("1|0|true|"), dem)
	print("  -> cong lop (nhan / o nhap): ", dem)

	# setVerticalAlignment: CCLabelTTF la lop DUY NHAT trong bon lop co can ngang
	# ma KHONG co can doc — tren no loi goi phai KHONG LAM GI. Day la truong hop
	# cua MOI nhan trong layout: do lai ca 296 bo cuc thi 8.968 nhan chu deu la
	# CCLabelTTF, con CCLabelBMFont thi khong co node nao (xem phan 1).
	var can_ttf: String = str(_L("""
		local c = require('cocos')
		local nhan = c.wrap(_NHAN)
		local truoc = c.raw(nhan).vertical_alignment
		nhan:setVerticalAlignment(2)
		return tostring(truoc) .. '|' .. tostring(c.raw(nhan).vertical_alignment)
				.. '|' .. tostring(c.raw(nhan):get_meta('type_name'))
	""", "can doc ttf"))
	var ph2 := can_ttf.split("|")
	t("CCLabelTTF: setVerticalAlignment KHONG lam gi",
			ph2.size() == 3 and ph2[0] == ph2[1] and ph2[2] == "CCLabelTTF", can_ttf)

	# CCLabelBMFont thi co can doc — nhung khong bo cuc nao chua node loai do
	# (0 node trong 296 file), nen phai dung mot node gia. Phep kiem nay khoa
	# LUAT (hoi type_name), khong phai khoa du lieu.
	var bmf := Label.new()
	bmf.text = "bmf"
	bmf.size = Vector2(100, 30)
	bmf.set_meta("kind", "label")
	bmf.set_meta("type_name", "CCLabelBMFont")
	san.add_child(bmf)
	lua.state.globals["_BMF"] = bmf
	var can_bmf: String = str(_L("""
		local c = require('cocos')
		local x = c.wrap(_BMF)
		local truoc = c.raw(x).vertical_alignment
		x:setVerticalAlignment(2)
		return tostring(truoc) .. '|' .. tostring(c.raw(x).vertical_alignment)
	""", "can doc bmf"))
	# Label moi dung o VERTICAL_ALIGNMENT_TOP = 0, khac CCLabelTTF (mac dinh giua).
	t("CCLabelBMFont: setVerticalAlignment(2) -> duoi", can_bmf == "0|2", can_bmf)
	# Node khong co `text` (khong phai nhan) thi khong duoc dung toi.
	var khong_nhan := Control.new()
	khong_nhan.size = Vector2(10, 10)
	san.add_child(khong_nhan)
	lua.state.globals["_KN"] = khong_nhan
	var can_kn: String = str(_L("""
		local c = require('cocos')
		local x = c.wrap(_KN)
		x:setVerticalAlignment(2)
		return 'xong'
	""", "can doc khong nhan"))
	t("node khong co chu: setVerticalAlignment chay khong loi", can_kn == "xong", can_kn)


# ---------------------------------------------------------------------------
# 3. Duong nguoi choi
# ---------------------------------------------------------------------------

## Ham xu ly cua ban goc: `self` la DOI TUONG TRA THEO TEN TOAN CUC, khong phai
## node (CUIBuyDialogEx.lua:113-114 dang ky ("g_CUIBuyDialogEx", "editboxEventHandler")
## roi CUIUserInfoNickName.lua:142 nhan mot doi so la chuoi su kien).
const _HANDLER := """
	g_Thu = { ds = {} }
	function g_Thu:khi_doi(sk) self.ds[#self.ds + 1] = tostring(sk) end
	function g_Thu:onTouchBegin_x(sender) self.ds[#self.ds + 1] = 'touch-x' return true end
"""


func _nhat() -> String:
	return str(_L("return table.concat(g_Thu.ds, ',')", "nhat ky"))


## Go MOT phim roi cho qua mot khung. Phai cho: LineEdit cua Godot 4.7.2 doi
## `text_changed` sang khung SAU (`text_changed_dirty` trong line_edit.cpp, gom
## nhieu lan sua trong cung khung thanh MOT lan ban), trong khi `text_submitted`
## thi ban ngay. Do ca hai tren mot LineEdit tran:
##   * mot phim -> chu doi NGAY, `text_changed` ra o khung sau;
##   * hai phim trong CUNG khung -> chu 'xa' nhung chi MOT su kien, mang chu 'xa';
##   * hai phim khac khung -> hai su kien, 'xab' roi 'xabc';
##   * `le.text = 'abc'` -> khong bao gio ban (ke ca sau mot khung);
##   * Enter -> `text_submitted` ban ngay trong chinh khung do.
## Nen o day go tung phim mot va cho qua khung, neu khong phep dem se ra thieu.
func _go(ma: int, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = ma
	ev.unicode = unicode
	root.push_input(ev)
	await process_frame


func _duong_nguoi_choi() -> void:
	if lua == null:
		return
	_L(_HANDLER, "ham xu ly")
	var eb := _tim(_login, "ebUserLoginName")
	var eb2 := _tim(_login, "ebUserLoginPassword")
	lua.state.globals["_EB"] = eb
	# Ba tang lCreate / lRegister / lLogin nam CHONG KHIT nhau trong ban ghi (ca
	# ba 344x400 o cung cho) va ban ghi khong ghi `vis`, nen khi
	# `respect_visible = false` thi ca sau tang cung hien. Ban goc chi hien MOT
	# tang: do duoc o day — ebRegisterPassword2 (y=160,5) phu len
	# ebUserLoginPassword (y=150), ca hai 150x30, nen o dang nhap khong con la o
	# TREN CUNG tai diem giua cua no nua: cu cham thuoc ve o cua tang dang ky.
	# Tat hai tang kia cho giong trang thai ban goc luc dang nhap.
	_tim(_login, "lRegister").visible = false
	_tim(_login, "lCreate").visible = false
	# Phan 2 da de lai chu va con tro trong o; dua ve trang thai dau roi moi do.
	_L("EB = require('cocos').wrap(_EB); EB:setText(''); g_Thu.ds = {}; "
			+ "EB:setLuaCallbackObjAndFunc('g_Thu', 'khi_doi')", "dang ky ham")
	t("o bat dau RONG (phan 2 da de lai chu, o day da xoa)", eb.lay_chu() == "",
			eb.lay_chu())

	var tam: Vector2 = lua._bien_doi(eb) * (eb.size * 0.5)
	t("diem giua o nam trong o", lua._trung(eb, tam), str(tam))
	# Cham vao o -> tieu diem. Duong cham di TRON cay mot luot (o nhap khong co
	# ten cham, nen duong cham thuong khong bao gio voi toi no).
	t("cham Begin vao o -> true", lua.touch_at("Begin", tam))
	t("o nhan tieu diem", eb.o_chu.has_focus())
	t("ban ra dung mot su kien 'began'", _nhat() == "began", _nhat())

	# Go phim THAT qua cay input cua Godot (khong phai dat chu bang ma).
	await _go(KEY_X, 120)
	t("phim X vao dung o dang co tieu diem", eb.lay_chu() == "x", eb.lay_chu())
	await _go(KEY_A, 97)
	t("phim A noi tiep", eb.lay_chu() == "xa", eb.lay_chu())
	t("moi lan go ban ra 'changed'", _nhat() == "began,changed,changed", _nhat())

	# setText bang MA khong ban su kien — do la co cua chinh LineEdit: dat
	# `o_chu.text` khong bao gio ban `text_changed` (do tren LineEdit tran: khong
	# ban, ke ca sau mot khung). Ban goc im lang vi ly do khac (0x2d1cc5 chi goi
	# assign roi goi vtable cua widget trong, KHONG goi ham Lua da dang ky), nhung
	# ket qua thi giong nhau. Thieu co nay thi CUIGuildInformation.lua:703 ban
	# nguoc 'changed' vao chinh ham xu ly cua no.
	_L("EB:setText('Nguyen Van A')", "dat bang ma")
	t("setText bang ma doi chu", eb.lay_chu() == "Nguyen Van A", eb.lay_chu())
	t("setText bang ma KHONG ban 'changed'", _nhat() == "began,changed,changed", _nhat())
	# Dat chu bang ma thi Godot de con tro o dau chuoi (do duoc: dat 'abc' roi go
	# X ra 'xabc'), nen phai dua con tro ve CUOI truoc khi go tiep — khong thi
	# phep kiem do cho dat con tro cua Godot chu khong do o nhap.
	eb.o_chu.caret_column = eb.lay_chu().length()

	# Enter -> 'return'. Ban goc dung su kien nay o CUIUserInfoNickName.lua:142.
	await _go(KEY_ENTER, 0)
	t("Enter ban ra 'return'", _nhat() == "began,changed,changed,return", _nhat())

	# Cham ra ngoai -> mat tieu diem -> 'ended'. Chu trong o GIU NGUYEN.
	lua.touch_at("Begin", Vector2(5, 5))
	t("cham ra ngoai -> mat tieu diem", not eb.o_chu.has_focus())
	t("mat tieu diem ban ra 'ended'",
			_nhat() == "began,changed,changed,return,ended", _nhat())
	t("chu trong o van con", eb.lay_chu() == "Nguyen Van A", eb.lay_chu())

	# Khong dang ky gi thi khong ton lan goi Lua: cap rong, va ten doi tuong
	# khong ton tai thi rawget tra nil THAT (khong phai bong) -> thoat, khong loi.
	lua.touch_at("Begin", tam)
	eb.o_chu.caret_column = eb.lay_chu().length()
	_L("EB:setLuaCallbackObjAndFunc('', '')", "xoa dang ky")
	await _go(KEY_B, 98)
	t("cap rong ('','') = khong co ham xu ly", eb.lay_chu() == "Nguyen Van Ab",
			eb.lay_chu())
	t("cap rong khong ban su kien nao",
			_nhat() == "began,changed,changed,return,ended,began", _nhat())
	_L("EB:setLuaCallbackObjAndFunc('khong_co_bien_nay', 'x')", "ten la")
	await _go(KEY_C, 99)
	t("ten doi tuong khong ton tai: khong loi, khong ban",
			eb.lay_chu() == "Nguyen Van Abc"
			and _nhat() == "began,changed,changed,return,ended,began", eb.lay_chu())
	lua.state.globals["_EB2"] = eb2
	_L("require('cocos').wrap(_EB2):setText('khong dang ky gi')", "o thu hai")
	t("o khong dang ky: setText van chay", eb2.lay_chu() == "khong dang ky gi", eb2.lay_chu())
	var tam2: Vector2 = lua._bien_doi(eb2) * (eb2.size * 0.5)
	t("diem giua o thu hai nam trong o", lua._trung(eb2, tam2), str(tam2))
	# O nhap TREN CUNG tai diem do phai la o dang cham. Vai node khac cung ung
	# vien (slSelectListBg, clSelectListBg, lLoginBG) nhung chung khong co ham
	# xu ly trong Lua nen `cocos.cham` tra false va luot cham di tiep xuong.
	var ds2: Array = []
	lua._ung_vien(san, tam2, ds2, true)
	var tren_cung: Control = null
	for n in ds2:
		if n is UiONhap:
			tren_cung = n
			break
	t("o nhap tren cung tai diem do la o thu hai", tren_cung == eb2,
			"%s giua %d ung vien" % [str(tren_cung.name if tren_cung else "-"), ds2.size()])
	var cham2 := lua.touch_at("Begin", tam2)
	t("cham vao o thu hai -> true", cham2)
	t("o thu hai nhan tieu diem", eb2.o_chu.has_focus())
	eb2.o_chu.caret_column = eb2.lay_chu().length()
	await _go(KEY_D, 100)
	t("o khong dang ky: go duoc, khong ban su kien nao",
			eb2.lay_chu() == "khong dang ky gid"
			and _nhat() == "began,changed,changed,return,ended,began", eb2.lay_chu())


# ---------------------------------------------------------------------------
# 4. Xen ke voi node co ten cham
# ---------------------------------------------------------------------------

## O nhap khong co ten cham trong du lieu, nen thu tu tren-duoi giua no va node
## cham phai theo dung mot luot di cay (LuaRuntime.touch_at). Do tren cay gia:
## hai node chong khit nhau, doi z_index de doi ben thang.
func _xen_ke() -> void:
	if lua == null:
		return
	var khung := Control.new()
	khung.size = Vector2(200, 100)
	khung.position = Vector2(300, 200)
	san.add_child(khung)

	var o := UiONhap.new()
	# UiONhap an kin o cua node cha (bon neo 0..1), nen o day phai mo neo ra
	# truoc khi dat kich thuoc — day la node gia, khong qua XggLayout.
	o.anchor_right = 0.0
	o.anchor_bottom = 0.0
	o.size = Vector2(100, 30)
	o.position = Vector2(20, 20)
	# Node gia phai tu dang ky ham nhu mot o that (XggLayout lam viec nay khi
	# doc ban ghi co truong lua_cb_obj) — khong co thi Begin lam o lay tieu diem
	# nhung khong ban su kien nao, va phep kiem se do nham.
	o.set_meta("lua_cb_obj", "g_Thu")
	o.set_meta("lua_cb_ham", "khi_doi")
	khung.add_child(o)

	var nut := Control.new()
	nut.size = Vector2(100, 30)
	nut.position = Vector2(20, 20)
	nut.set_meta("touch", "x")
	nut.set_meta("touch_obj", "g_Thu")
	khung.add_child(nut)

	var tam: Vector2 = lua._bien_doi(o) * (o.size * 0.5)
	_L("g_Thu.ds = {}", "xoa nhat ky")
	# nut ve SAU o -> nam TREN. Cu cham phai thuoc ve nut, va o KHONG duoc lay
	# tieu diem: ban goc cung vay, node tren cung nuot Begin.
	lua.touch_at("Begin", tam)
	t("nut nam TREN: nut nhan Begin, o khong lay tieu diem",
			_nhat() == "touch-x" and not o.o_chu.has_focus(),
			"%s / %s" % [_nhat(), str(o.o_chu.has_focus())])

	# Lat lai: o len tren -> cu cham thuoc ve o.
	o.z_index = 1
	_L("g_Thu.ds = {}", "xoa nhat ky")
	lua.touch_at("Begin", tam)
	t("o nam TREN: o lay tieu diem, nut khong chay",
			_nhat() == "began" and o.o_chu.has_focus(),
			"%s / %s" % [_nhat(), str(o.o_chu.has_focus())])
	lua.touch_at("Begin", Vector2(5, 5))
