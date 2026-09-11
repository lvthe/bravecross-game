# Quet: mo THU tung man hinh cua ban goc bang dung duong Show cua no.
#
#   godot --headless --path . --script tools/quet_show.gd
#
# Khong phai phep kiem dat/hong, ma la mot phep DO: duong Show chay duoc bao xa
# tren bao nhieu man. Moi man deu di dung mot dong — <quan ly>:Show(<ten>) — va
# tat ca phan con lai la ma goc.
#
# Ba muc trong bao cao:
#
#   mo duoc  Show chay tron: nap bo cuc, onInit, hoat canh mo, onShow.
#   im       Show ve ma khong onShow. Ghi kem bo cuc co nap duoc khong
#            (conoc) va onInit co chay khong (isInit), de biet no dung o dau.
#   hong     ma goc nem loi. Phan lon la THIEU DU LIEU chu khong phai thieu
#            engine: nil config, nil du lieu may chu, hoac mot cai bong bi dem
#            ra lam so.
#
# Hai cho phai don tay giua cac man, vi trong game that khong ai mo 164 hop
# thoai lien tiep: IsUILock va hang doi hoat canh. Xem chu thich trong ma.
extends SceneTree

const _BOOT := """
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
	g_CSceneManager.CurrentScene = 'Test'
	_G._QUAN_LY = {'g_CUINormalDlg', 'g_CUISubDialog', 'g_CUIMessageDlg',
		'g_CUITipsDlg', 'g_CUIMultiLayerDialog'}
	_G._DA_BIET = {}
"""


## Nap mot module man hinh roi mo moi man MOI ma no vua dang ky.
const _MOT := """
	local out = Dictionary()
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
	for i, m in ipairs(moi) do
		local ok2, err2 = pcall(function() m.ql:Show(m.ten) end)
		local obj = m.ql.UI[m.ten]
		if not ok2 then
			out[m.khoa] = 'HONG ' .. tostring(err2)
		elseif obj.IsUiShow ~= true then
			out[m.khoa] = 'IM khoa=' .. tostring(m.ql.IsUILock)
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
	return out
"""


func _init() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true
	var nen := XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
	lua.bind_layout(nen)
	var goc := XggLayout.find_node(nen, "UIRootLayer")
	goc.position = Vector2.ZERO
	lua.set_ui_root(goc)
	lua.run(_BOOT, "boot")

	var ds: Array = []
	var d := DirAccess.open("res://sc/user/UI")
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".lua"):
			ds.append(f.get_basename())
		f = d.get_next()
	ds.sort()

	var nap_hong := []
	var mo_ok := 0
	var mo_im := 0
	var mo_hong := {}
	var hong_theo_man := []
	var im_ly := []
	var im_loai := {}
	var tong := 0
	for m in ds:
		var r = lua.run(_MOT % m, "thu " + m)
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
			tong += 1
			if v == "ok":
				mo_ok += 1
			elif v.begins_with("IM"):
				mo_im += 1
				# Phan loai: bo cuc co nap duoc khong, onInit co chay khong.
				var loai := v.substr(v.find("isInit="))
				im_loai[loai] = int(im_loai.get(loai, 0)) + 1
				if im_ly.size() < 4:
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
	quit()
