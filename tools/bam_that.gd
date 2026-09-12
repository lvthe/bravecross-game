# Di tu Main vao tran BANG CU BAM THAT. Moi buoc: tim node dang hien mang ten
# cham cua nut (dung ten ban goc gan — ham onTouchEnd_<ten>), bam vao tam no
# qua LuaRuntime.touch_at (dung duong chuot cua --xem), roi xem man ke tiep
# co mo khong. O moi man in ra cac ten cham dang hien, va node NAO thuc su
# nhan cu bam, de biet con vuong o dau.
#
#   godot --headless --path . --script tools/bam_that.gd
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0

## [ten buoc, ten cham ('~' dau = mau regex), Lua tra true khi buoc xong,
##  so node toi da thu bam, so khung cho sau moi cu bam]
const BUOC := [
	["nut tan cong o Main", "btnMainExtraUIAttack",
		"return g_CUINormalDlg:GetCurrentUIName() == g_CUISelectLevel:GetUIName()", 1, 90],
	["o ai dang mo", "OnSelectLevel",
		"return g_CUINormalDlg:GetCurrentUIName() == 'ChapterInfo'", 20, 60],
	["nut Di", "OnGo",
		"return g_CUINormalDlg:GetCurrentUIName() == g_CUIBattleDeploy:GetUIName()", 1, 90],
	# O tuong trong danh sach chon: CUIBattleSelectHeroList:onTouchEnd_OnIconClick
	# (CUIBattleDeploy.lua:837). onUnSelectHero la tuong DA trong doi — bam vao
	# do la bo ra, va mo hop chu thich co lop che nuot cu bam sau.
	["chon tuong", "OnIconClick",
		"local l = g_CUIBattleDeploy.ItemTableViewList return l ~= nil and #(l.tSelectedHerosTagList or {}) > 0", 5, 30],
	["nut tan cong o bo tri", "OnChapterListAttack",
		"return require('cocos').tran_nut ~= nil", 1, 300],
]

const _MAN := """
	local function lay(f) local ok, v = pcall(f) return ok and tostring(v) or ('?' .. tostring(v):sub(1, 80)) end
	return 'man ' .. lay(function() return g_CUINormalDlg:GetCurrentUIName() end)
		.. ' | canh ' .. lay(function() return g_CSceneManager:GetCurrentSceneName() end)
		-- Lop "dang tai" chung (UI_MessageBox_Loading): ghi AN trong file, ma
		-- neu con hien thi no nuot moi cu bam (ten cham ClickBackground).
		.. ' | he thong ' .. lay(function() return g_CUISystemDlg:GetCurrentUIName() end)
		.. ' | dang tai ' .. lay(function() return g_buyLoadingDialog.bIsLoading end)
		.. ' | lCommonLoadingDialog hien ' .. lay(function()
			local n = rawget(_G, 'lCommonLoadingDialog') return n ~= nil and n:getIsVisible() end)
		.. ' | lLoadingDialog hien ' .. lay(function()
			local n = rawget(_G, 'lLoadingDialog') return n ~= nil and n:getIsVisible() end)
"""

## Cai TRUOC khi di Login -> Main: ghi moi loi goi may chu, moi dong nhat ky
## offline khong phai 'info', va ai mo / dong lop "dang tai" (kem vet goi).
## Ham cua lop nam trong vtbl (share/class.lua): DOC qua doi tuong, GHI vao lop.
const _MOC := """
	moc = { sv = {}, off = {}, tai = {} }
	local goc_dispatch = OfflineNet.dispatch
	OfflineNet.dispatch = function(self, m, o, f, ...)
		moc.sv[#moc.sv + 1] = tostring(f) .. (OfflineRouter:has(f) and '' or '(THIEU)')
		return goc_dispatch(self, m, o, f, ...)
	end
	local goc_ghi = OfflineLog.write
	OfflineLog.write = function(self, tag, msg)
		if tag ~= 'info' then moc.off[#moc.off + 1] = tostring(tag) .. ' ' .. tostring(msg):sub(1, 200) end
		return goc_ghi(self, tag, msg)
	end
	local dl = rawget(_G, 'g_buyLoadingDialog')
	if dl ~= nil then
		for _, ham in ipairs({ 'Show', 'Hide' }) do
			local goc = dl[ham]
			CBuyLoadingDialog[ham] = function(...)
				local vet = debug.traceback('', 2):gsub('\\n%s*', ' < '):sub(1, 900)
				moc.tai[#moc.tai + 1] = ham .. vet
				return goc(...)
			end
		end
	else
		moc.tai[1] = 'g_buyLoadingDialog chua nap luc cai moc'
	end
	return true
"""

const _DOC_MOC := """
	local function ds(t, n) local o = {} for i = math.max(1, #t - n + 1), #t do o[#o + 1] = t[i] end return table.concat(o, ' ; ') end
	return 'MAY CHU: ' .. ds(moc.sv, 40) .. ' || OFFLINE: ' .. ds(moc.off, 15) .. ' || DANG TAI: ' .. ds(moc.tai, 6)
"""

var _san: Control


func _init() -> void:
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
	_san = Control.new()
	_san.size = lua.cua_so_engine
	_san.scale = Vector2.ONE * (vp.y / lua.cua_so_engine.y)
	lua.set_stage(_san)
	lua.set_touch_root(_san)
	if lua.run(VM._NAP, "nap") == null:
		print("nap hong: %s" % ", ".join(lua.errors))
		quit(1)
		return
	lua.run(_MOC, "moc theo doi")
	var d := VM.chay(lua)
	if str(d["dung"]) != "":
		print("KHONG toi duoc Main, dung o: %s" % d["dung"])
		quit(1)
		return
	for i in 60:
		lua.tick(KHUNG)
	print("toi Main. %s" % str(lua.run(_MAN, "man")))
	print("  theo doi: %s" % str(lua.run(_DOC_MOC, "doc moc")))
	var da_in := lua.errors.size()
	var hong := 0
	var dat := 0
	for b in BUOC:
		print("\n== %s  (ten cham %s)" % [b[0], b[1]])
		_in_ten_cham()
		# Da xong san (vd tuong da nam trong doi) thi KHONG bam: nguoi choi that
		# cung khong bam, va bam thua co the mo hop (lToolTipMask) nuot cu sau.
		if lua.run(String(b[2]), "xong san") == true:
			print("  => DA XONG SAN, khong bam. %s" % str(lua.run(_MAN, "man")))
			dat += 1
			continue
		var ds := _tim(String(b[1]))
		print("  node dang hien mang ten nay: %d" % ds.size())
		var xong := false
		for n in ds.slice(0, int(b[3])):
			var c: Control = n
			var p: Vector2 = LuaRuntime._bien_doi(c) * (c.size * 0.5)
			lua.run("require('cocos').nhat_ky_cham = {}", "xoa nhat ky")
			var an := lua.touch_at("Begin", p)
			var nhan: Node = lua._dang_cham
			lua.touch_at("End", p)
			for k in int(b[4]):
				lua.tick(KHUNG)
			var goi = lua.run("return table.concat(require('cocos').nhat_ky_cham or {}, ' | ')", "nhat ky")
			print("  bam '%s' tag=%s o %s -> nhan: %s, goi: %s" % [
					String(c.get_meta("xgg_name", c.name)), str(c.get_meta("tag", "-")), p.round(),
					_ten(nhan) if an else "KHONG AI NHAN", str(goi).substr(0, 200)])
			while da_in < lua.errors.size():
				print("  loi Lua  %s" % str(lua.errors[da_in]).substr(0, 300))
				da_in += 1
			if lua.run(String(b[2]), "xong chua") == true:
				xong = true
				break
		print("  => %s. %s" % ["XONG" if xong else "KHONG QUA DUOC", str(lua.run(_MAN, "man"))])
		if not xong:
			hong += 1
			break
		dat += 1
	print("\n%s" % ("DI TRON TU Main VAO TRAN BANG CU BAM THAT" if hong == 0 else "VUONG — xem buoc cuoi"))
	# Buoc sau cho vuong khong chay duoc: tinh la hong luon (check.py doc dong nay).
	print("dat %d, hong %d" % [dat, BUOC.size() - dat])
	_san.free()
	quit(1 if hong > 0 else 0)


static func _ten(n: Node) -> String:
	if n == null:
		return "-"
	return "%s[%s]" % [String(n.get_meta("xgg_name", n.name)), String(n.get_meta("touch", ""))]


## Node dang hien (ca chuoi cha) mang ten cham khop, theo thu tu cay.
func _tim(ten: String) -> Array:
	var ds: Array = []
	var re: RegEx = null
	if ten.begins_with("~"):
		re = RegEx.create_from_string(ten.substr(1))
	_gom(_san, ten, re, ds)
	return ds


func _gom(n: Node, ten: String, re: RegEx, ds: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control and n.has_meta("touch"):
		var t := String(n.get_meta("touch"))
		if t != "" and ((re == null and t == ten) or (re != null and re.search(t) != null)):
			ds.append(n)
	for c in n.get_children():
		_gom(c, ten, re, ds)


## Cac ten cham dang hien tren man, kem so node — biet man nay bam duoc gi.
func _in_ten_cham() -> void:
	var dem := {}
	_dem_ten(_san, dem)
	var ds: Array = []
	for k in dem:
		ds.append("%s x%d" % [k, dem[k]])
	ds.sort()
	print("  ten cham dang hien (%d): %s" % [ds.size(), ", ".join(ds).substr(0, 900)])


func _dem_ten(n: Node, dem: Dictionary) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control and n.has_meta("touch"):
		var t := String(n.get_meta("touch"))
		if t != "":
			dem[t] = int(dem.get(t, 0)) + 1
	for c in n.get_children():
		_dem_ten(c, dem)
