# Mo DUNG mot man roi in so luot hoi tag / hut, kem nhat ky hut CUA RIENG man do.
#
#   godot --headless --path . --script tools/do_mot_man.gd -- <ten man> <module>
#
# Quan ly (trong 5 quan ly) duoc TU TIM theo ten man — khong truyen tay.
#
# Dung de tra xem "hut 0" cua mot man la that hay la loi phep do, va hut nao la
# CO Y (ma goc tu kiem tra roi bo qua) chu khong phai loi.
#
# Day la cho ROADMAP dua ra ket luan "man nao THIEU TAG THAT": quet_show.gd chi
# noi man hong hay mo duoc, con cai nay moi noi HUT O TAG NAO va vi sao — nho do
# moi phan biet duoc "ghep thieu tag" voi "loi cua chinh man".
extends SceneTree

const VaoMain := preload("res://tools/vao_main.gd")

const _MOT := """
	local c = require('cocos')
	local h0 = c.tag_lookups
	local m0 = c.tag_misses
	local n0 = #c.tag_miss_log
	local ok, err = pcall(function() require('%s') end)
	if not ok then return 'NAP HONG: ' .. tostring(err) end
	-- Tu tim quan ly dang giu man nay: man nao dang ky o quan ly khac
	-- (g_CUIXingHunBook chang han) thi goi thang g_CUINormalDlg:Show(ten) se
	-- khong bao loi gi ma cung khong mo gi — dung cai bay phai tranh.
	local ql = nil
	for _, t in ipairs(_QUAN_LY) do
		local q = rawget(_G, t)
		if type(q) == 'table' and type(q.UI) == 'table' and q.UI['%s'] then
			ql = q
			break
		end
	end
	if ql == nil then return 'KHONG QUAN LY NAO GIU MAN NAY' end
	local ok2, err2 = pcall(function() ql:Show('%s') end)
	local nk = {}
	for i = n0 + 1, #c.tag_miss_log do nk[#nk + 1] = c.tag_miss_log[i] end
	c.tag_miss_log = {}
	pcall(function() ql:CloseImmediately() end)
	ql.IsUILock = false
	return 'hoi=' .. (c.tag_lookups - h0) .. ' hut=' .. (c.tag_misses - m0)
		.. '\\n  Show: ' .. (ok2 and 'ok' or tostring(err2))
		.. '\\n  HUT:\\n    ' .. table.concat(nk, '\\n    ')
"""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("thieu ten man / module")
		quit(1)
		return
	var ten := args[0]
	var mod := args[1]

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

	var r = lua.run(_MOT % [mod, ten, ten], "thu " + ten)
	if r == null:
		print("LUA HONG: %s" % ", ".join(lua.errors))
	else:
		print("== %s\n%s" % [ten, r])
	quit()
