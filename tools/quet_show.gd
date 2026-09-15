# Quet: mo THU tung man hinh cua ban goc bang dung duong Show cua no.
#
#   godot --headless --path . --script tools/quet_show.gd
#   godot --headless --path . --script tools/quet_show.gd -- --tho
#
# Khong phai phep kiem dat/hong, ma la mot phep DO: duong Show chay duoc bao xa
# tren bao nhieu man. Moi man deu di dung mot dong — <quan ly>:Show(<ten>) — va
# tat ca phan con lai la ma goc.
#
# Mac dinh chay tren MOT NGUOI CHOI THAT: di tron chuoi Login -> Main qua lop
# offline (dung tools/vao_main.gd), roi moi quet. Quan trong vi phan lon man
# hong la hong o cho DOC DU LIEU NGUOI CHOI — khong co nguoi choi thi phep do
# chi dang do cai engine, khong dang do man hinh.
#
#   --tho   bo qua dang nhap, quet tren nen tran nhu truoc (canh 'Test',
#           khong co nguoi choi). De doi chieu xem dang nhap duoc bao nhieu.
#
# Ba muc trong bao cao:
#
#   mo duoc  Show chay tron: nap bo cuc, onInit, hoat canh mo, onShow.
#   im       Show ve ma khong onShow — thuong la man DOI THAM SO ma Show goi
#            tran. Ghi kem so tham so cua onShow (nparams, dem ca self).
#   hong     ma goc nem loi. Ghi ro kieu: bong bi dem ra lam gia tri la thieu
#            ENGINE, con nil la thieu DU LIEU.
#
# Hai cho phai don tay giua cac man, vi trong game that khong ai mo 353 hop
# thoai lien tiep: IsUILock va hang doi hoat canh. Xem chu thich trong ma.
extends SceneTree

const VaoMain := preload("res://tools/vao_main.gd")

## Phan chuan bi RIENG cua phep quet, chay sau khi da vao Main.
const _SAN_SANG := """
	_G._QUAN_LY = {'g_CUINormalDlg', 'g_CUISubDialog', 'g_CUIMessageDlg',
		'g_CUITipsDlg', 'g_CUIMultiLayerDialog'}
	_G._DA_BIET = {}
	return true
"""

## Nen tran, khi chay --tho: khong dang nhap, khong nguoi choi.
const _BOOT_THO := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	-- Nap TOAN BO ma goc theo dung ban ke khai cua no (876 module), chu khong
	-- phai mot danh sach ngan minh chon. Khac nhau rat lon: cai gi khong nap
	-- thi la bong, ma bong goi ra MOT gia tri, nen
	-- 'local bRet, data = G_XLogic:GetY()' cho data = nil va man hinh hong o
	-- dong sau, trong nhu la thieu du lieu may chu.
	boot.boot_goc()
	boot.init_config()
	-- Ban goc luon o trong mot canh; ten canh la nil thi CLevelLoader khong
	-- ban tin OnLoadXGG va onInit khong bao gio chay.
	g_CSceneManager.CurrentScene = 'Test'
	return true
"""


## Nhat ky "hut tag" moi sinh ra tu luot truoc, roi XOA di — de nho khong phinh
## theo so man. `cocos.lua` ghi lai moi lan getChildByTag tra ve nil, kem ten
## node cha va cac tag no THUC SU co.
##
## Tra ve MOT CHUOI chu khong phai bang: bang Lua (khoa 1..n) khong doi sang
## kieu Godot nao ma phep kiem `is Array` / `is Dictionary` bat duoc — da thu ca
## hai va muc "cho hut nhieu nhat" van in ra trong. Chuoi thi chac chan doc duoc
## (moi gia tri khac cua `_MOT` deu la chuoi va deu doc duoc).
const _LAY_HUT := """
	local c = require('cocos')
	local out = table.concat(c.tag_miss_log, '\\n')
	c.tag_miss_log = {}
	return out
"""

## Nap mot module man hinh roi mo moi man MOI ma no vua dang ky.
##
## Hut tag duoc dem theo TUNG KHOA man (`~hut`), khong theo TUNG FILE nhu truoc:
## `moi` cua luot dau tien chua MOI man da dang ky tu `boot_goc()` (876 module),
## nen neu dem theo file thi ca 1.500 luot hut don het vao bucket cua file dau
## tien (`CUIAchieve`) va bang "hut theo man" thanh vo dung. Do la loi phep do
## da mac: `RedPacketMainDlg` bi bao hut 0 trong khi do rieng no ra `hoi=1 hut=1`.
const _MOT := """
	local out = Dictionary()
	local c = require('cocos')
	local ok, err = pcall(function() require('user.UI.%s') end)
	if not ok then
		out['nap'] = tostring(err)
		return out
	end
	out['nap'] = 'ok'
	local moi = {}
	for _, ten_ql in ipairs(_QUAN_LY) do
		local ql = rawget(_G, ten_ql)
		if type(ql) == 'table' and type(ql.UI) == 'table' then
			for ten, obj in pairs(ql.UI) do
				local khoa = ten_ql .. '/' .. ten
				if not _DA_BIET[khoa] then
					_DA_BIET[khoa] = true
					moi[#moi + 1] = { ql = ql, ten = ten, khoa = khoa }
				end
			end
		end
	end
	local hut = {}
	for i, m in ipairs(moi) do
		local h0 = c.tag_misses
		local ok2, err2 = pcall(function() m.ql:Show(m.ten) end)
		local dm = c.tag_misses - h0
		if dm > 0 then hut[#hut + 1] = m.khoa .. '=' .. dm end
		local obj = m.ql.UI[m.ten]
		if not ok2 then
			out[m.khoa] = 'HONG ' .. tostring(err2)
		elseif obj.IsUiShow ~= true and obj.IsUiVisible ~= true then
			-- Hoi CA HAI co. IsUiShow do CUIPublic:onShow dat, ma vai man ghi
			-- de onShow roi khong goi len lop cha (CUIGuildContestRuleDlg chi
			-- goi _initUI). Nhung man do van mo that, va co IsUiVisible —
			-- do setDialogVisible -> onVisible dat — moi la dau hieu dung.
			-- onShow cua man hinh doi may THAM SO? Ban goc goi
			-- Show(ten, data, kieu) va truyen data xuong onShow; man nao doi
			-- them tham so ma ta goi Show tran thi no tu thoat ra ngay dong
			-- dau. debug.getinfo dem ca 'self'.
			local inf = debug.getinfo(obj.onShow, 'u')
			out[m.khoa] = 'IM nparams=' .. tostring(inf and inf.nparams)
				.. ' khoa=' .. tostring(m.ql.IsUILock)
				.. ' hientai=' .. tostring(m.ql.CurrentUIName)
				.. ' goc=' .. tostring(obj.RootUIName)
				.. ' xgg=' .. tostring(obj.ResourceXggList and obj.ResourceXggList[1])
				.. ' conoc=' .. tostring(obj:GetRootUI() ~= nil)
				.. ' isInit=' .. tostring(obj.isInit)
				.. ' tenkhop=' .. tostring(obj.UIName == m.ten)
				.. ' codialog=' .. tostring(obj.dialog == m.ql)
		else
			out[m.khoa] = 'ok'
		end
		-- Dong lai va MO KHOA. CloseImmediately cua ban goc khong dat lai
		-- IsUILock; man nao mo do dang thi quan ly do khoa luon, va moi man
		-- sau do deu im re. Trong game that thi hiem khi gap vi mo mot man la
		-- xong mot man; o day quet 164 man lien nen phai don tay.
		pcall(function() m.ql:CloseImmediately() end)
		m.ql.IsUILock = false
		m.ql.CurrentUIName = nil
		m.ql.active = nil
		-- Va don HANG DOI HOAT CANH. InsertAnimation chi chay ngay khi hang doi
		-- dang rong ("if #self.AnimationList == 1"); cai dang chay chi duoc go
		-- ra o OnShowAnimationFinish. Dong mot man giua chung thi no nam lai
		-- trong hang, va MOI man sau do chi duoc xep hang chu khong chay.
		m.ql.AnimationList = {}
	end
	out['~hut'] = table.concat(hut, ';')
	return out
"""


func _init() -> void:
	var tho := false
	for a in OS.get_cmdline_user_args():
		if a == "--tho":
			tho = true

	var lua := LuaRuntime.new()
	# Cua so cua ENGINE — giong tools/vao_main.gd: cao co dinh 768, rong theo
	# ti le man. Canh cua ban goc dung dung co do.
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true

	var san := Control.new()
	san.size = lua.cua_so_engine
	lua.set_stage(san)
	lua.set_touch_root(san)

	if tho:
		# Nen tran: khung hop thoai dung tay, khong canh, khong nguoi choi.
		var nen := XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
		san.add_child(nen)
		lua.bind_layout(nen)
		var goc := XggLayout.find_node(nen, "UIRootLayer")
		goc.position = Vector2.ZERO
		lua.set_ui_root(goc)
		if lua.run(_BOOT_THO, "boot tho") == null:
			print("boot hong: %s" % ", ".join(lua.errors))
			quit(1)
			return
		print("nen: TRAN (khong dang nhap)")
	else:
		# Nguoi choi THAT: di tron chuoi Login -> Main qua lop offline.
		if lua.run(VaoMain._NAP, "nap") == null:
			print("nap hong: %s" % ", ".join(lua.errors))
			quit(1)
			return
		var d := VaoMain.chay(lua)
		if d["dung"] != "":
			print("KHONG vao duoc Main, dung o: %s" % d["dung"])
			quit(1)
			return
		var lv = lua.run("return select(2, G_UserLogic:GetLevel())", "cap")
		print("nen: da dang nhap, dang o canh Main (nguoi choi cap %s)" % lv)

	if lua.run(_SAN_SANG, "san sang") == null:
		print("san sang hong: %s" % ", ".join(lua.errors))
		quit(1)
		return

	var ds: Array = []
	var thu_muc := DirAccess.open("res://sc/user/UI")
	thu_muc.list_dir_begin()
	var f := thu_muc.get_next()
	while f != "":
		if f.ends_with(".lua"):
			ds.append(f.get_basename())
		f = thu_muc.get_next()
	ds.sort()

	var nap_hong := []
	var mo_ok := 0
	var mo_im := 0
	var mo_hong := {}
	var hong_theo_man := []
	var im_ly := []
	var im_loai := {}
	var tong := 0
	var hoi_tong := 0
	var hut_tong := 0
	var hut_man := []
	var hut_loi := {}
	for m in ds:
		var hoi0 := int(lua.run("return require('cocos').tag_lookups", "hoi0"))
		var hut0 := int(lua.run("return require('cocos').tag_misses", "hut0"))
		var r = lua.run(_MOT % m, "thu " + m)
		var hoi1 := int(lua.run("return require('cocos').tag_lookups", "hoi1"))
		var hut1 := int(lua.run("return require('cocos').tag_misses", "hut1"))
		hoi_tong += hoi1 - hoi0
		hut_tong += hut1 - hut0
		var nk = lua.run(_LAY_HUT, "nhat ky hut")
		if nk is String and not (nk as String).is_empty():
			for dong in (nk as String).split("\n", false):
				hut_loi[dong] = int(hut_loi.get(dong, 0)) + 1
		# Day het hoat canh mo (0,19 giay) sau MOI lan thu: cai nao con do dang
		# thi chan hang doi cua ca quan ly do.
		for i in range(8):
			lua.tick(0.05)
		if r == null:
			nap_hong.append("%s: Lua chet" % m)
			continue
		for k in r:
			var v := str(r[k])
			if str(k) == "nap":
				if v != "ok":
					nap_hong.append("%s: %s" % [m, v])
				continue
			if str(k) == "~hut":
				# "<khoa man>=<so luot hut>;..." — hut theo TUNG MAN.
				for phan in v.split(";", false):
					var eq := phan.rfind("=")
					if eq <= 0:
						continue
					var khoa := phan.substr(0, eq)
					var n := int(phan.substr(eq + 1))
					hut_man.append([n, khoa])
				continue
			tong += 1
			if v == "ok":
				mo_ok += 1
			elif v.begins_with("IM"):
				mo_im += 1
				# Phan loai: bo cuc co nap duoc khong, onInit co chay khong.
				var loai := "nparams=" + v.substr(v.find("nparams=") + 8, 2).strip_edges()
				im_loai[loai] = int(im_loai.get(loai, 0)) + 1
				if im_ly.size() < 40:
					im_ly.append("%s -> %s" % [k, v])
			else:
				var ly := v.substr(5)
				mo_hong[ly] = int(mo_hong.get(ly, 0)) + 1
				hong_theo_man.append("%s | %s" % [k, ly])

	print("\n%d module man hinh, %d khong nap duoc" % [ds.size(), nap_hong.size()])
	for e in nap_hong.slice(0, 10):
		print("   khong nap: %s" % e)
	print("\n%d man dang ky; mo duoc %d, im %d, hong %d"
			% [tong, mo_ok, mo_im, tong - mo_ok - mo_im])
	for k in im_loai:
		print("   im: %-28s x%d" % [k, im_loai[k]])
	for e in im_ly:
		print("   IM: %s" % e)
	print("
TUNG MAN HONG:")
	for e in hong_theo_man:
		print("   %s" % e)
	var xep := []
	for k in mo_hong:
		xep.append([int(mo_hong[k]), String(k)])
	xep.sort_custom(func(a, b): return a[0] > b[0])
	print("\nCac loi hay gap nhat:")
	for e in xep.slice(0, 15):
		print("   x%-4d %s" % [e[0], e[1].substr(0, 110)])

	# Tag: do PHU cua tag do duoc tu may ao tren dung nhung luot hoi ma ma goc
	# that su goi. Con so nay la thu muc tieu cua item 2(b) trong ROADMAP, va
	# truoc day khong co cach do nao chay lai duoc.
	if hoi_tong > 0:
		print("\nTAG: %d/%d luot getChildByTag co ket qua (%.1f%%), hut %d"
				% [hoi_tong - hut_tong, hoi_tong,
					100.0 * (hoi_tong - hut_tong) / hoi_tong, hut_tong])
	hut_man.sort_custom(func(a, b): return a[0] > b[0])
	for e in hut_man.slice(0, 12):
		print("   hut %-4d  %s" % [e[0], e[1]])
	var hut_xep := []
	for k in hut_loi:
		hut_xep.append([int(hut_loi[k]), String(k)])
	hut_xep.sort_custom(func(a, b): return a[0] > b[0])
	print("\nCho hut nhieu nhat (ten node cha hoi tag, va cac tag no co):")
	for e in hut_xep.slice(0, 15):
		print("   x%-4d %s" % [e[0], e[1].substr(0, 118)])
	quit()
