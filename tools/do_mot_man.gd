# Mo mot hoac mot CHUOI man, in so luot hoi tag / hut cho TUNG man, kem nhat ky
# hut CUA RIENG man do.
#
#   godot --headless --path . --script tools/do_mot_man.gd -- <ten man> <module> [<ten man 2> <module 2> ...]
#
# Quan ly (trong 5 quan ly) duoc TU TIM theo ten man — khong truyen tay.
#
# Dung de tra xem "hut 0" cua mot man la that hay la loi phep do, va hut nao la
# CO Y (ma goc tu kiem tra roi bo qua) chu khong phai loi.
#
# Day la cho ROADMAP dua ra ket luan "man nao THIEU TAG THAT": quet_show.gd chi
# noi man hong hay mo duoc, con cai nay moi noi HUT O TAG NAO va vi sao — nho do
# moi phan biet duoc "ghep thieu tag" voi "loi cua chinh man".
#
# NHIEU CAP = mo LAN LUOT va KHONG dong cai truoc. Can the vi mot man mo MOT
# MINH co the hong trong khi chay tot qua duong that cua no: CUIQuestInfo doc
# thang `g_CUIQuest.tAreaData`, ma bang do chi duoc dien trong
# `CUIQuest:_refresh()` — tuc la phai mo CUIQuest truoc. Chinh no la cho goi
# (`CUIQuest.lua:819,831` goi `g_CUIMultiLayerDialog:Show(...)` khi CUIQuest dang
# mo ben duoi). Do mot man roi ket luan "man hong" la ket luan SAI ve san pham.
extends SceneTree

const VaoMain := preload("res://tools/vao_main.gd")

const _CHUOI := """
	local c = require('cocos')
	local ds = %s
	local ra = {}
	local function mo_mot(m)
		local ok, err = pcall(function() require(m.mod) end)
		if not ok then
			return '  NAP HONG: ' .. tostring(err)
		end
		-- Tu tim quan ly dang giu man nay: man nao dang ky o quan ly khac
		-- (g_CUIXingHunBook chang han) thi goi thang g_CUINormalDlg:Show(ten) se
		-- khong bao loi gi ma cung khong mo gi — dung cai bay phai tranh.
		local ql = nil
		for _, t in ipairs(_QUAN_LY) do
			local q = rawget(_G, t)
			if type(q) == 'table' and type(q.UI) == 'table' and q.UI[m.ten] then
				ql = q
				break
			end
		end
		if ql == nil then
			return '  KHONG QUAN LY NAO GIU MAN NAY'
		end
		local h0 = c.tag_lookups
		local m0 = c.tag_misses
		local k0 = #c.tag_miss_log
		local ok2, err2 = pcall(function() ql:Show(m.ten) end)

		-- NHA KHUNG. `Show` moi chi chay toi `CUIManager:OnShowAnimationBegin`
		-- (goi onShow); con `onVisible` — cho chua phan refresh cua nhieu man —
		-- nam o `OnShowAnimationFinish`, duoc xep qua mot
		-- `S_CCSequence(S_CCDelayTime, S_CCCallFunc)` chay tren rootUI
		-- (CUIDialogAnimation.lua:86-95). Trong game that khung troi qua nen no
		-- chay; o day `lua.run` chay mot mach khong co khung nao, nen khong nha
		-- thi onVisible KHONG BAO GIO chay — do ra "man hong" trong khi man
		-- khong he chay refresh. Do duoc: CUIQuest chi rieng phan nay da la
		-- bVisible=false => tAreaData=nil.
		local ok3, err3 = pcall(function()
			for _ = 1, 30 do c.tick(0.05) end
		end)
		local obj = ql.UI[m.ten]
		local nk = {}
		for i = k0 + 1, #c.tag_miss_log do nk[#nk + 1] = c.tag_miss_log[i] end
		return '  hoi=' .. (c.tag_lookups - h0) .. ' hut=' .. (c.tag_misses - m0)
			.. '\\n  Show: ' .. (ok2 and 'ok' or tostring(err2))
			.. '\\n  Tick: ' .. (ok3 and 'ok' or tostring(err3))
			.. '\\n  visible=' .. tostring(obj and obj.IsUiVisible)
			.. '\\n  HUT:\\n    ' .. table.concat(nk, '\\n    ')
	end

	for _, m in ipairs(ds) do
		ra[#ra + 1] = '== ' .. m.ten .. '\\n' .. mo_mot(m)
	end

	-- Don: dong het cac quan ly da dung, va mo khoa (man hong de lai IsUILock
	-- = true thi lan mo sau trong cung phien bi chan im lang).
	for _, t in ipairs(_QUAN_LY) do
		local q = rawget(_G, t)
		if type(q) == 'table' and type(q.CloseImmediately) == 'function' then
			pcall(function() q:CloseImmediately() end)
			q.IsUILock = false
		end
	end
	return table.concat(ra, '\\n')
"""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() % 2 != 0:
		print("can tung cap <ten man> <module> (so tham so phai chan)")
		quit(1)
		return
	var ten_re := RegEx.new()
	ten_re.compile("^[A-Za-z0-9_]+$")
	var mod_re := RegEx.new()
	mod_re.compile("^[A-Za-z0-9_.]+$")
	var ds := PackedStringArray()
	for i in range(0, args.size(), 2):
		var ten := args[i]
		var mod := args[i + 1]
		if ten_re.search(ten) == null or mod_re.search(mod) == null:
			print("ten man / module khong hop le: %s / %s" % [ten, mod])
			quit(1)
			return
		ds.append("{ten='%s', mod='%s'}" % [ten, mod])

	var lua := LuaRuntime.new()
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

	if lua.run(VaoMain._NAP, "nap") == null:
		print("nap hong")
		quit(1)
		return
	var d := VaoMain.chay(lua)
	if d["dung"] != "":
		print("KHONG vao duoc Main: %s" % d["dung"])
		quit(1)
		return
	lua.run("_G._QUAN_LY = {'g_CUINormalDlg','g_CUISubDialog','g_CUIMessageDlg','g_CUITipsDlg','g_CUIMultiLayerDialog'}; _G._DA_BIET = {}; return true", "san sang")

	var r = lua.run(_CHUOI % ("{" + ",".join(ds) + "}"), "thu " + ", ".join(args))
	if r == null:
		print("LUA HONG: %s" % ", ".join(lua.errors))
	else:
		print(r)
	quit()
