# Vao canh Main bang DUNG CHUOI cua ban goc — lop offline dong vai may chu —
# roi do xem no dung o dau.
#
#   godot --headless --path . --script tools/vao_main.gd
#
# Tren may that: canh Login -> go tai khoan, bam dang nhap -> chon may chu ->
# bam "vao game". Ba cu bam do la viec cua NGUOI CHOI, nen o day lam thay
# bang DUNG HAM ma nut goi; con lai la ma goc:
#
#   G_Login:Login -> (offline) OnServerLogin -> CUILogin:onLoginLogic
#   (LoginLogicUid, danh sach may chu) -> setSelectServer
#   -> onTouchEnd_OnEnterGame -> __sngLoginGame -> SetRPCUid + callGameRPC
#   -> StartRPC -> OnConnected -> Handshake -> CUILogin:OnServerConnected
#   -> G_GameWorld:EnterGame -> (offline) OnServerEnterGame(nguoi choi moi)
#   -> CUILogin:OnServerEnterGame -> sngEnterGame -> (offline)
#   OnGetAcvitityList -> RepaleceScene('Main') -> coroutine doi canh -> InitUI
#
# Nguoi choi MOI TINH: du lieu dung tu cac muc '<bang>Reset' cua
# KDBGameCommonConfig (brave-cross/work/offline/sc/offline/bootstrap.lua).
extends SceneTree

const KHUNG := 1.0 / 30.0

## [ten chang, viec lam (Lua), dieu kien xong (Lua), so khung toi da]
const CHANG := [
	["vao canh Login",
		"g_CSceneManager:RepaleceSceneWithoutLoading('Login') return true",
		"return g_CSceneManager.CurrentScene == 'Login' and not g_CSceneManager.isLoading",
		300],
	["dang nhap (go tai khoan, bam dang nhap)",
		"G_Login:Login('offline', '', 0) return true",
		"local l = g_CUILoginServerList.tRecommendServer"
			+ " return g_CUILogin.LoginLogicUid ~= nil and l ~= nil and next(l) ~= nil",
		120],
	["chon may chu",
		"local _, sv = next(g_CUILoginServerList.tRecommendServer)"
			+ " g_CUILogin:setSelectServer(sv) return true",
		"return g_CUILogin.szGameServerIP ~= nil",
		5],
	["bam 'vao game'",
		"g_CUILogin:onTouchEnd_OnEnterGame(nil, true) return true",
		"return g_CSceneManager.CurrentScene == 'Main' and not g_CSceneManager.isLoading",
		600],
]


func _init() -> void:
	if not FileAccess.file_exists("res://sc/share/class.lua"):
		print("thieu ma goc — chay: python tools/import_lua.py")
		quit(1)
		return
	var lua := LuaRuntime.new()
	# Cua so cua ENGINE: cao co dinh 768, rong theo ti le man — may ao do duoc
	# ca 13 CCScene la 1429x768 tai (0,0). San khau mang dung co do roi thu nho
	# cho vua cua so Godot.
	# Co cua so lay tu cai dat du an, KHONG tu root.size: trong _init cua so
	# chua kip doi ve co that (headless ra ~178x100), va ca canh bi thu nho vao
	# goc tren trai.
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	var cua_so := Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	lua.cua_so_engine = cua_so
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true
	var san := Control.new()
	san.size = cua_so
	san.scale = Vector2.ONE * (vp.y / cua_so.y)
	lua.set_stage(san)
	lua.set_touch_root(san)

	var r = lua.run(_NAP, "nap")
	if r == null:
		print("nap hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	print("nap %s module, cau hinh %s" % [r.get("nap", "?"), r.get("cau hinh", "?")])
	for k in r:
		if str(k).contains("khoi dong"):
			print("  %s: %s" % [k, str(r[k]).substr(0, 200)])

	var d := chay(lua)
	print("\n[DO TAM] %s" % str(lua.run("""
		local w, h = g_CPublic:GetWinSize()
		local u = _G['UIRootLayer']
		local uw, uh = u:getContentSize()
		local m = _G['g_MainUIScrollLayer']
		local mw, mh = m:getContentSize()
		return string.format('win=%sx%s  UIRoot=%sx%s  fScale=%s  MainScroll=%sx%s',
			tostring(w), tostring(h), tostring(uw), tostring(uh),
			tostring(g_CSceneManager.fScale), tostring(mw), tostring(mh))
	""", "do tam")))
	print("\nchang da qua: %s" % (", ".join(d["qua"]) if not d["qua"].is_empty() else "(chua)"))
	print("dung o: %s" % (d["dung"] if d["dung"] != "" else "(khong — toi Main)"))

	_thong_ke_ve(san)
	_liet_ke_rig(san, lua)
	_o_giao_dien(san)

	var bao = lua.run(_BAO, "bao cao")
	if bao != null:
		for k in bao:
			print("  %-26s %s" % [k, bao[k]])
	var miss := lua.missing()
	# `sngFixInfoReflash` la phuong thuc C++ cua ban goc (khong file Lua nao
	# dinh nghia), nen thieu no thi KHONG co loi nao — chi la moi node neo dung
	# yen. Dem lai moi biet no co chay, va chay bao nhieu node.
	var fx := lua.fix_reflash()
	print("\n  sngFixInfoReflash: ma goc goi %d lan, doi cho %d node"
			% [fx["goi"], fx["node"]])
	for dong in XggLayout.reflash_log:
		print("      %s" % dong)
	var mk := []
	for k in miss:
		mk.append([int(miss[k]), String(k)])
	mk.sort_custom(func(a, b): return a[0] > b[0])
	print("\n  API Cocos bi goi ma CHUA LAM (%d loai):" % mk.size())
	for e in mk.slice(0, 25):
		print("      %-34s x%d" % [e[1], e[0]])
	for e in lua.errors:
		print("  loi Lua: %s" % e)
	# Chup man hinh — PHAI chay khong --headless de co ve that:
	#   godot --path . --script tools/vao_main.gd -- --chup=main.png
	# Xem va bam tay — cua so giu nguyen, chuot di vao ma goc qua touch():
	#   godot --path . --script tools/vao_main.gd -- --xem
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			_chup = a.substr(7)
		elif a == "--xem":
			_xem = true
	if _chup != "" or _xem:
		_lua = lua
		root.add_child(san)
		if _xem:
			_da_in = lua.errors.size()
			# window_input phat TRUOC khi GUI cua Godot xu ly, nen node .xgg
			# khong nuot mat cu bam. Nhung no mang toa do DIEM ANH cua cua so;
			# stretch canvas_items (project.godot) thi phai doi ve toa do canvas,
			# khong thi phong to cua so la bam lech.
			root.window_input.connect(func(e: InputEvent):
				lua.touch(e.xformed_by(root.get_final_transform().affine_inverse())))
			print("\ndang mo cua so — bam thoai mai, dong cua so de thoat")
		return
	san.free()
	quit(0)


var _chup := ""
var _xem := false
var _da_in := 0
var _lua: LuaRuntime = null
var _dem := 0


## Do xem canh Main ve ra sao: bao nhieu node CO ANH, bao nhieu HIEN that
## (ca chuoi cha deu hien), bao nhieu nam TRONG khung 960x640 — va o that su
## cua cac lop nen.
static func _thong_ke_ve(san: Control) -> void:
	# O cua node tinh theo toa do cua so Godot (qua ca ti le thu nho san khau).
	var khung := Rect2(Vector2.ZERO, san.size * san.scale)
	var so := {"co anh": 0, "hien": 0, "trong khung": 0}
	var ngoai: Array = []
	var ds: Array = [san]
	while not ds.is_empty():
		var n: Node = ds.pop_back()
		for c in n.get_children():
			ds.append(c)
		if not (n is Control):
			continue
		var ten := String(n.get_meta("xgg_name", n.get_meta("cls", n.name)))
		if ten in ["g_MainUIScrollLayer", "CCParallaxNode", "CCLayerGradientEx"] \
				or ten.begins_with("gb"):
			var o := LuaRuntime._bien_doi(n) * Rect2(Vector2.ZERO, n.size)
			print("  o %-28s %-14s hien=%s %s z=%s" % [ten.substr(0, 28), n.get_class(),
					_hien_that(n), o, n.get_meta("zorder", "?")])
		var tex = n.get("texture")
		if tex == null:
			continue
		so["co anh"] += 1
		if not _hien_that(n):
			continue
		so["hien"] += 1
		var r := LuaRuntime._bien_doi(n) * Rect2(Vector2.ZERO, n.size)
		if r.intersects(khung):
			so["trong khung"] += 1
		elif ngoai.size() < 8:
			# Kem chuoi cha (ten xgg) de biet anh thuoc lop nao.
			var chuoi: Array = []
			var p := n.get_parent()
			while p != null and p != san and chuoi.size() < 6:
				if p.has_meta("xgg_name"):
					chuoi.append(String(p.get_meta("xgg_name")))
				p = p.get_parent()
			ngoai.append("%s %s <- %s" % [String(n.get_meta("img", n.name)).substr(0, 40),
					r, " < ".join(chuoi)])
	print("\n  ve: %s" % so)
	for s in ngoai:
		print("    hien ma NGOAI khung: %s" % s)


## Armature (getUIAnimFromSpriteCatch) da tao: ten, co SngRig khong, hien that
## khong, dat o dau, cha la ai — va ten nao khong co du lieu.
static func _liet_ke_rig(san: Control, lua: LuaRuntime) -> void:
	var ds: Array = [san]
	var n := 0
	while not ds.is_empty():
		var nd: Node = ds.pop_back()
		for c in nd.get_children():
			ds.append(c)
		if not (nd is Control) or String(nd.get_meta("kind", "")) != "rig":
			continue
		n += 1
		if n > 15:
			continue
		var cha := nd.get_parent()
		var ten_cha := String(cha.get_meta("xgg_name", cha.name)) if cha != null else "?"
		var goc := LuaRuntime._bien_doi(nd) * Vector2.ZERO
		print("  rig %-24s con=%d hien=%s tai=%s cha=%s" % [String(nd.get_meta("rig_ten", "?")),
				nd.get_child_count(), _hien_that(nd), goc, ten_cha])
	print("  tong rig: %d; khong co du lieu: %s" % [n, lua.rig_thieu])


## O THAT (toa do cua so) cua cac lop giao dien chinh cua canh Main, de do vi
## sao dai nut tren cung bi cat.
static func _o_giao_dien(san: Control) -> void:
	var muon := ["UIRootLayer", "lMainBtnLayer", "lMainToolbarRightTop", "lMainToolbarLeft",
			"lMainUserInfo", "lDialogControlPanel", "lMainToolbarRightBottom"]
	var ds: Array = [san]
	while not ds.is_empty():
		var nd: Node = ds.pop_back()
		for c in nd.get_children():
			ds.append(c)
		if nd is Control and String(nd.get_meta("xgg_name", "")) in muon:
			var o := LuaRuntime._bien_doi(nd) * Rect2(Vector2.ZERO, nd.size)
			print("  gd %-24s hien=%s o=%s co=%s scale=%s cocos=%s parent_h=%s" % [
					nd.get_meta("xgg_name"), _hien_that(nd), o, nd.size, nd.scale,
					nd.get_meta("cocos", "?"), nd.get_meta("parent_h", "?")])


static func _hien_that(n: Node) -> bool:
	var p := n
	while p != null:
		if p is CanvasItem and not (p as CanvasItem).visible:
			return false
		p = p.get_parent()
	return true


func _process(dt: float) -> bool:
	if _lua == null:
		return false
	_lua.tick(dt)
	if _xem:
		# Loi Lua moi (vd bam nut ma man do hong) in ra ngay de con biet.
		while _da_in < _lua.errors.size():
			print("  loi Lua: %s" % _lua.errors[_da_in])
			_da_in += 1
		return false
	_dem += 1
	# Vai chuc khung cho hoat canh mo va anh kip ve.
	if _dem == 45:
		var img := root.get_texture().get_image()
		img.save_png(_chup)
		print("da chup %s (%dx%d)" % [_chup, img.get_width(), img.get_height()])
		quit(0)
	return false


## Chay ca chuoi tren mot LuaRuntime da nap (_NAP). verify_main.gd dung lai.
## Tra ve {"qua": [chang da xong], "dung": chang/loi dung lai, "" neu toi Main}.
static func chay(lua: LuaRuntime) -> Dictionary:
	var out := {"qua": [], "dung": ""}
	if lua.run(_CHUAN_BI, "chuan bi") == null:
		out["dung"] = "chuan bi: " + ", ".join(lua.errors)
		return out
	for c in CHANG:
		if lua.run(c[1], c[0]) == null:
			out["dung"] = "%s: %s" % [c[0], ", ".join(lua.errors)]
			return out
		var xong := false
		for i in range(int(c[3])):
			lua.tick(KHUNG)
			if lua.run(c[2], "doi " + c[0]) == true:
				xong = true
				break
		if not xong:
			out["dung"] = c[0]
			return out
		out["qua"].append(c[0])
	return out


const _NAP := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	local bao = boot.boot_goc()
	local out = Dictionary()
	out['nap'] = bao.nap .. '/' .. bao.so
	out['cau hinh'] = boot.init_config()
	-- Bat loi ma ban goc tu bao qua KDebug.PrintError: coroutine doi canh do
	-- loi ra do (CSceneManager.lua:500, :533) va khong nem len tren. Loi CHET
	-- (sngLoadingNext / RepaleceScene) giu het; loi thuong chi dem.
	loi_goc, loi_chet, so_loi = {}, {}, 0
	local goc = KDebug.PrintError
	KDebug.PrintError = function(...)
		local t = {}
		for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end
		local s = table.concat(t, ' ')
		so_loi = so_loi + 1
		if s:find('sngLoadingNext :', 1, true) or s:find('RepaleceScene', 1, true) then
			loi_chet[#loi_chet + 1] = s
		elseif #loi_goc < 12 then
			loi_goc[#loi_goc + 1] = s:sub(1, 400)
		end
		if type(goc) == 'function' then pcall(goc, ...) end
	end
	-- Phan con lai cua sc/game.lua sau G_ConfigManager:Init (xem bootstrap).
	local n_kd, hong_kd, tong_kd = boot.khoi_dong_game()
	out['khoi dong game.lua'] = n_kd .. '/' .. tong_kd
	for k, e in pairs(hong_kd) do out['HONG khoi dong: ' .. k] = e end
	return out
"""

## Lop offline thay may chu, va nguoi choi MOI TINH.
const _CHUAN_BI := """
	-- Nhat ky THIEU / WARN / ERROR cua lop offline di vao bao cao: loi cua no
	-- bi pcall nuot.
	require('offline.log')
	local ghi = OfflineLog.write
	OfflineLog.write = function(self, tag, msg)
		if tag ~= 'info' and #loi_goc < 60 then
			loi_goc[#loi_goc + 1] = 'offline ' .. tostring(tag) .. ': ' .. tostring(msg)
		end
		return ghi(self, tag, msg)
	end
	require('offline.init')
	-- Mac dinh XOA de moi lan chay la nguoi choi moi tinh (test on dinh). Bat
	-- co GIU_SAVE (do_chien_dich --giu) thi GIU ban luu de thu tien trinh chien
	-- dich qua nhieu ai (thang ai 1 -> len cap -> mo ai 2 -> choi tiep).
	if rawget(_G, 'GIU_SAVE') ~= true then
		Offline:wipe()
	end
	-- Cong tac co san cua ban goc (game.lua:457, CloseGuide trong set.xgg).
	-- Khong bat thi nguoi choi moi tinh vao ai huong dan (CUILogin2.lua:3714)
	-- — dung voi ban goc, nhung la canh Battle chu khong phai Main.
	g_CUIMain.bIgnoreGuide = true
	return true
"""

const _BAO := """
	local c = require('cocos')
	local out = Dictionary()
	out['CurrentScene'] = tostring(g_CSceneManager.CurrentScene)
	out['dang doi canh'] = tostring(g_CSceneManager.isLoading)
	out['canh dang chay'] = tostring(c.canh_dang_chay ~= nil and c.raw(c.canh_dang_chay):get_meta('xgg_name'))
	out['LoginLogicUid'] = tostring(g_CUILogin.LoginLogicUid)
	out['may chu chon'] = tostring(g_CUILogin.szGameServerIP)
	out['IsEnterGame'] = tostring(G_GameWorld and G_GameWorld.IsEnterGame)
	local okL, lv = pcall(function() return select(2, G_UserLogic:GetLevel()) end)
	out['Level'] = tostring(okL and lv)
	local okG, gv = pcall(function() return select(2, G_UserLogic:GetGold()) end)
	out['Gold'] = tostring(okG and gv)
	out['g_MainUIScene'] = tostring(rawget(_G, 'g_MainUIScene') ~= nil)
	out['lMainBtnLayer'] = tostring(rawget(_G, 'lMainBtnLayer') ~= nil)
	out['tag hut'] = tostring(c.tag_misses) .. '/' .. tostring(c.tag_lookups)
	out['so loi goc'] = tostring(so_loi)
	for i, e in ipairs(loi_chet) do out['LOI CHET ' .. i] = e end
	for i, e in ipairs(loi_goc) do out['loi goc ' .. i] = e end
	for i, e in ipairs(c.loi_hen) do
		if i <= 8 then out['loi hen ' .. i] = e end
	end
	local ghost = require('bootstrap').report()
	local ds = {}
	for k, v in pairs(ghost) do ds[#ds + 1] = { k, v } end
	table.sort(ds, function(a, b) return a[2] > b[2] end)
	for i = 1, math.min(10, #ds) do out['bong ' .. i] = ds[i][1] .. ' x' .. ds[i][2] end
	return out
"""
