# Chuoi khoi dong Login -> Main cua lop Lua, tach ra khoi `tools/vao_main.gd`
# de MAN THAT dung duoc.
#
# Truoc luot nay chuoi nay chi nam trong `tools/`, ma `tools/` khong phai la
# cho de mot man cua game goi vao: `game/` khong duoc phep phu thuoc `tools/`
# (chieu phu thuoc la `tools/` -> `game/`). Nen phan dung chung doi ve day, con
# `tools/vao_main.gd` giu lai nam dong a-li-at de **9 tep** dang `preload` roi
# dung `VM._NAP` / `VM.chay(...)` khong phai sua.
#
# `extends RefCounted`: khong cho nao o day dung toi cay node, va `RefCounted`
# chet theo tham chieu cuoi cung — dung y mot man `change_scene_to_file` can.
# Khong `class_name`: ca 9 noi tieu thu deu di qua `preload`, nen dang ky ten
# toan cuc khong them duoc gi.
#
# Day KHONG phai ban sao cua `tools/vao_main.gd` — no la CHO DUY NHAT dinh
# nghia chuoi nay. Sua chuoi thi sua o day.
extends RefCounted

## Mot khung cua lop Lua. Ban goc chay 30 khung/giay.
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


## Chay chuoi vao Main theo TUNG BUOC, co ngan sach thoi gian — de cua so khong
## bi treo khi chuoi chay trong mot man THAT.
##
## `chay()` (duong dong bo cu, 8 tep dang dung) chi la `buoc(-1)`. Nho vay ca
## kho chi con MOT vong lap: hai duong khong the lech nhau, va phep kiem doi
## chieu hai duong chi con phai kiem mot thu.
class Tien extends RefCounted:
	## [ten chang] da xong, theo thu tu.
	var qua: Array = []
	## "" neu toi Main; ten chang hoac chuoi loi neu dung lai.
	var dung := ""
	## Het chuoi (toi Main) hoac dung lai — nghia la se KHONG buoc nao nua.
	## KHONG co nghia la thanh cong: `dung == ""` moi la thanh cong.
	var xong := false
	## So lan tick() da goi. De doi chieu hai duong chay ra cung mot so.
	var so_vong := 0

	## Ghi thoi gian TUNG vong tick — chi khi bat `do_vong`. Moi phan tu la
	## `[ms, ten chang]`.
	##
	## Co no vi "khung nao dung hinh lau" la cau hoi KHONG tra loi duoc bang cach
	## dem so khung: do duoc ca chuoi chi co **18 vong** ma vong dat nhat chiem
	## phan lon thoi gian (xem `ui/vao_game.gd`). Mac dinh TAT de cac bo do khac
	## khong phai chiu them mot lan goi dong ho moi vong.
	var do_vong := false
	var vong: Array = []

	var _lua: LuaRuntime = null
	var _chang := -1        ## -1 = chua chay CHUAN_BI
	var _da_lenh := false   ## da chay lenh cua chang hien tai chua
	var _du := 0            ## so khung da tick trong chang hien tai

	func _init(lua: LuaRuntime) -> void:
		_lua = lua

	func ket_qua() -> Dictionary:
		return {"qua": qua, "dung": dung}

	## Chay toi da `ngan_sach_ms` mili giay, nhung LUON lam duoc it nhat mot
	## viec trong mot luot goi (ngan sach 0 khong the quay vong). `-1` = khong
	## gioi han. Tra true khi da xong (toi Main, hoac dung lai).
	func buoc(ngan_sach_ms: int) -> bool:
		if xong:
			return true
		var t0 := Time.get_ticks_msec()
		var da_lam := false

		# Buoc 0: lop offline + nguoi choi MOI TINH. Phai chay truoc moi chang,
		# va PHAI doc co GIU_SAVE ma nguoi goi dat TRUOC chuoi (xem
		# `tools/do_chien_dich.gd` phan `--giu`).
		if _chang < 0:
			if _lua.run(CHUAN_BI, "chuan bi") == null:
				dung = "chuan bi: " + ", ".join(_lua.errors)
				xong = true
				return true
			_chang = 0
			_da_lenh = false
			_du = 0
			da_lam = true

		while not xong:
			var c: Array = CHANG[_chang]
			var ten := String(c[0])
			if not _da_lenh:
				if _lua.run(String(c[1]), ten) == null:
					dung = "%s: %s" % [ten, ", ".join(_lua.errors)]
					xong = true
					return true
				_da_lenh = true
				_du = 0

			# Het so khung cho phep — y nhu vong `for i in range(c[3])` cua ban
			# cu chay het ma dieu kien van chua dung.
			if _du >= int(c[3]):
				dung = ten
				xong = true
				return true

			# Ngan sach chi xet TRUOC mot tick, va chi khi luot goi nay da lam
			# duoc it nhat mot viec — nen khong luot nao quay vong ma khong
			# tien, va khong bao gio tra ve giua mot chang.
			if da_lam and ngan_sach_ms >= 0 \
					and Time.get_ticks_msec() - t0 >= ngan_sach_ms:
				return false

			# THU TU NAY LA CO Y, dung "sua" lai: ban cu tick TRUOC roi moi hoi
			# dieu kien. Hoi truoc roi moi tick thi so khung Lua chay lech di
			# mot, va moi thu bam theo so khung (vi tri nhan vat, dong ho canh)
			# lech theo — im lang, khong loi nao.
			var t_vong := Time.get_ticks_msec() if do_vong else 0
			_lua.tick(KHUNG)
			so_vong += 1
			_du += 1
			da_lam = true
			if do_vong:
				vong.append([Time.get_ticks_msec() - t_vong, ten])

			if _lua.run(String(c[2]), "doi " + ten) == true:
				qua.append(ten)
				_chang += 1
				_da_lenh = false
				_du = 0
				if _chang >= CHANG.size():
					xong = true

		return true


## Chay ca chuoi tren mot LuaRuntime da nap (xem NAP). Duong DONG BO.
##
## Vo mong cua `Tien`: giu nguyen thu tu `run`/`tick` cua ban cu, va `-1` nghia
## la ngan sach khong bao gio duoc xet, nen day chay dung bang so lan goi nhu
## truoc. `assert` de neu co ngay nao do `buoc(-1)` tra ve som thi no lo ra
## thanh mot loi that, chu khong am tham tra ve mot chuoi chay dang do.
static func chay(lua: LuaRuntime) -> Dictionary:
	var t := Tien.new(lua)
	assert(t.buoc(-1) and t.xong, "Tien.buoc(-1) phai chay het chuoi")
	return t.ket_qua()


## Nap toan bo ma goc + lop offline. Chay MOT lan cho ca phien.
##
## `BAO` (o duoi) doc cac bien toan cuc `loi_goc` / `loi_chet` / `so_loi` ma
## khoi nay dat, nen no chi co nghia SAU khi khoi nay chay xong — dung thu tu.
const NAP := """
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

## Lop offline thay may chu, va nguoi choi MOI TINH. Chang 0 cua `Tien`.
const CHUAN_BI := """
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

## Bao cao "dung o dau, vi sao" — doc sau khi chuoi chay xong (hoac dung lai).
const BAO := """
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
