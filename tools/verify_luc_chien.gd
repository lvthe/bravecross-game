# Bo kiem LUC CHIEN cua man dan tran chien dich (CUIBattleDeploy).
#
# VI SAO PHAI CO. Sau khi lop offline (offline/luc_chien.lua) dien `FightCapacity`
# va `AllFightCapacity` thay cho may chu that, KHONG bo kiem nao trong bang doc
# con so ay ra man: `do_chien_dich.gd --kiem` di QUA man dan tran nhung chi hoi
# "co qua duoc buoc khong", con `verify_chon_ai.gd` dung lai o man chon ai. Nen
# bat bien duoi day — "nhan `Lực` tren man bang dung so ma CHINH HAI HAM GOC
# tinh ra" — hien khong phep do nao tra loi.
#
# LUAT DO TU MA GOC, khong phai cong thuc chep lai:
#   * Nhan la node con tag 1 cua `lBattleDeployImplement`
#     (`CUIBattleDeploy.lua:1433`:
#     `self.ttfTotalFightCapacity = self.ImplementRoot:getChildByTag(1)`), va
#     duoc ghi boi `calcuFightingCapacity` (`:2592`) bang `nTotalFightingCapacity`
#     — TONG cua tung tuong da xep vao o (`:2587` cong khi chon, `:2589` tru khi
#     bo). Nen mot cho lech o bat ky tuong nao cung lam tong lech.
#   * Moi tuong duoc doc bang `GetHeroAllFightCapacity` (`HeroCapacityLogic.lua:56`)
#     -> `GetHeroAllFightCapacityWithHero` (`:63`) — ham nay KHONG tinh: no doc
#     thang truong `AllFightCapacity` da co, va chi khi truong ay NIL moi lui ve
#     `FightCapacity` (`:65`). Day chinh la cho lam loi im lang: mot so 0 (khac
#     nil) chan luon duong lui.
#   * So ma truong ay PHAI bang: `CalHeroAllFightCapacityWithHero` (`:73`) =
#     `FightCapacity` + trang bi + canh + than binh + hon sao, `math.floor`.
#
# Ba phep do, ba nguon doc lap, lech mot cho la lo ra ngay:
#   A. nhan tren MAN (doc tu NODE THAT trong cay) == `D.nTotalFightingCapacity`
#   B. `D.nTotalFightingCapacity`                 == TONG `GetHeroAllFightCapacity`
#   C. TONG ay                                    == TONG `CalHeroAllFightCapacityWithHero`
#
# Va phep kiem phai CO LUC. Nhom C xoa hai truong di roi bat nhan roi ve 0 —
# khong co nhom nay thi "nhan > 0" van xanh tren mot man khong he doc truong nao.
# Nhom D goi lai `OfflineLucChien:bo_sung()` roi doi so CU tro lai: vua khang
# dinh chieu nguoc, vua bat luon loi ghi LUY THUA DANG (goi hai lan ra cung so) —
# truoc luot nay do moi chi la mot CAU trong chu thich, chua phep do nao bat.
#
# GIOI HAN noi ro: chi do duong TUONG CUA MINH (`GetHeroAllFightCapacity`).
# Duong LINH THUE (`tHeroData.strHeroIndex`, `:2570-2574`) khong cham toi duoc:
# `GuildId` cua ban luu offline bang 0 nen nhanh ay khong mo (`:4559`).
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0

var _dat := 0
var _hong := 0
var _da_in := 0
var _lua: LuaRuntime
var _san: Control

## Chuoi vao man dan tran: DUNG cac buoc cua chinh man (Show -> GoNextCallback ->
## onTouchEnd_OnGo), y nhu `tools/do_chien_dich.gd` va `tools/bam_that.gd`.
const _VAO := """
	local c = require('cocos')
	local L = g_CUISelectLevel
	g_CUINormalDlg:Show(L:GetUIName(), {})
	for _ = 1, 90 do c.tick(%f) end
	for i, v in ipairs(L.tChapterData or {}) do
		if v.BattleStatus ~= 0 and L.nSubChapter == nil then L.nSubChapter = i end
	end
	if L.nSubChapter == nil then return 'khong mo duoc ai nao' end
	L:GoNextCallback()
	for _ = 1, 60 do c.tick(%f) end
	g_CUIChapterInfo:onTouchEnd_OnGo(nil, true)
	for _ = 1, 90 do c.tick(%f) end
	return 'man: ' .. tostring(g_CUINormalDlg:GetCurrentUIName())
"""

## Xep tuong vao o di DUNG duong nguoi choi: moi tuong trong danh sach xep
## (`tAllUnlockHerosData`, do `refreshHerosScrollLayerUI` do ra) di qua
## `OnTouchAllHerosEnd` -> `OnTouchSelectHero` -> `selectHeroToSlot`.
const _XEP := """
	local D = g_CUIBattleDeploy
	pcall(function() D:refreshHerosScrollLayerUI(1) end)
	local n = 0
	for _, h in ipairs(D.tAllUnlockHerosData or {}) do
		if type(h) == 'table' and h.UserHeroID == nil and type(h[1]) == 'table' then
			h = h[1]
		end
		if type(h) == 'table' and tonumber(h.UserHeroID) ~= nil then
			local _, it = D:getItemByHeroID(h.UserHeroID)
			D:OnTouchAllHerosEnd(it, h, true)
			n = n + 1
			if n >= 5 then break end
		end
	end
	return 'thu xep ' .. tostring(n) .. ' tuong'
"""


## Trang thai luc chien cua man, doc trong MOT luot Lua.
##
## Thu tu trong moi tuong la CO Y: `raw` (truong tho) truoc, roi `cal` (ham
## TINH LAI), roi `get` (ham man goi) SAU CUNG — vi `GetHeroAllFightCapacityWithHero`
## (`:63`) co GHI khi truong la nil (`tHeroData.AllFightCapacity = tHeroData.FightCapacity or 0`),
## nen doc no truoc thi chinh phep do lam mat trang thai can do.
const _DOC := """
	local D = g_CUIBattleDeploy
	local out = Dictionary()
	local so, tong_get, tong_cal, raw_tong = 0, 0, 0, 0
	local ds = {}
	for i = 1, 5 do
		local k = string.format('HeroSlot_%02d', i)
		local it = D.tSelectedHerosItemConfig[k]
		local d = it and it.ItemData
		if type(d) == 'table' and tonumber(d.UserHeroID) ~= nil then
			local raw = d.AllFightCapacity
			local _, n_cal = G_HeroLogic:CalHeroAllFightCapacityWithHero(d)
			local _, n_f = G_HeroLogic:CalcHeroFightCapatity(d)
			local _, n_get = G_HeroLogic:GetHeroAllFightCapacity(d)
			so = so + 1
			raw_tong = raw_tong + (tonumber(raw) or 0)
			tong_cal = tong_cal + (tonumber(n_cal) or 0)
			tong_get = tong_get + (tonumber(n_get) or 0)
			ds[#ds + 1] = string.format('%s id=%s Fight=%s truong=%s get=%s tinh=%s',
				k, tostring(d.UserHeroID), tostring(n_f), tostring(raw),
				tostring(n_get), tostring(n_cal))
		end
	end
	out.so_o = math.floor(so)
	out.raw_all = math.floor(raw_tong)
	out.tong_get = math.floor(tong_get)
	out.tong_cal = math.floor(tong_cal)
	out.tong_lua = math.floor(tonumber(D.nTotalFightingCapacity) or -1)
	out.chi_tiet = table.concat(ds, ' | ')
	return out
"""

## Xoa hai truong cua tung tuong dang xep roi TINH LAI nhan bang chinh
## `calcuFightingCapacity` cua man — de con so tren man la do man tu ghi, chu
## khong phai do bo kiem dat tay.
const _XOA := """
	local D = g_CUIBattleDeploy
	local so = 0
	for i = 1, 5 do
		local it = D.tSelectedHerosItemConfig[string.format('HeroSlot_%02d', i)]
		local d = it and it.ItemData
		if type(d) == 'table' and tonumber(d.UserHeroID) ~= nil then
			d.FightCapacity = 0
			d.AllFightCapacity = 0
			so = so + 1
		end
	end
	D.nTotalFightingCapacity = 0
	for i = 1, 5 do
		local it = D.tSelectedHerosItemConfig[string.format('HeroSlot_%02d', i)]
		local d = it and it.ItemData
		if type(d) == 'table' and tonumber(d.UserHeroID) ~= nil then
			D:calcuFightingCapacity(d, true)
		end
	end
	return 'xoa ' .. tostring(so) .. ' tuong, nhan = ' .. tostring(D.nTotalFightingCapacity)
"""

## Goi LAI lop offline roi cong lai vao nhan. Tra ve `tong_cal` tinh lai lan hai
## de doi chieu voi lan dau (luy thua dang) — do o PHIA LUA, khong qua man, nen
## no khong the trung voi phep do nhan.
const _KHOI_PHUC := """
	local n_dien = OfflineLucChien:bo_sung()
	local D = g_CUIBattleDeploy
	D.nTotalFightingCapacity = 0
	local tong_cal = 0
	for i = 1, 5 do
		local it = D.tSelectedHerosItemConfig[string.format('HeroSlot_%02d', i)]
		local d = it and it.ItemData
		if type(d) == 'table' and tonumber(d.UserHeroID) ~= nil then
			local _, n_cal = G_HeroLogic:CalHeroAllFightCapacityWithHero(d)
			tong_cal = tong_cal + (tonumber(n_cal) or 0)
			D:calcuFightingCapacity(d, true)
		end
	end
	local out = Dictionary()
	out.n_dien = math.floor(tonumber(n_dien) or -1)
	out.tong_cal = math.floor(tong_cal)
	out.tong_nhan = math.floor(tonumber(D.nTotalFightingCapacity) or -1)
	return out
"""


func _init() -> void:
	_lua = LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	_lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not _lua.open():
		print("KHONG chay duoc: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true
	_san = Control.new()
	_san.size = _lua.cua_so_engine
	_san.scale = Vector2.ONE * (vp.y / _lua.cua_so_engine.y)
	_lua.set_stage(_san)
	_lua.set_touch_root(_san)
	get_root().add_child(_san)
	if _lua.run(VM._NAP, "nap") == null:
		print("nap hong: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	var d := VM.chay(_lua)
	if str(d["dung"]) != "":
		print("KHONG toi duoc Main, dung o: %s" % d["dung"])
		quit(1)
		return
	print("toi Main.")
	_nha(60)

	# --- A. Vao man dan tran va xep tuong ---------------------------------
	print("\nA. vao man dan tran bang dung chuoi cua man:")
	print("   %s" % str(_lua.run(_VAO % [KHUNG, KHUNG, KHUNG], "vao man dan tran")))
	_xa_loi()
	_nha(40)
	var man := str(_lua.run("return tostring(g_CUINormalDlg:GetCurrentUIName())", "man"))
	_ghi_chu(man == "BattleDeploy",
			"dung o man dan tran: CurrentUIName=%s — do: %s" % [man, man])
	print("   %s" % str(_lua.run(_XEP, "xep tuong")))
	_xa_loi()
	_nha(40)
	var a := _doc_luc()
	print("   o da xep: %s" % a["so_o"])
	print("   %s" % a["chi_tiet"])
	_ghi_chu(int(a["so_o"]) >= 1,
			"co it nhat mot tuong trong o (do: %s) — khong co thi moi phep do sau do la phep do tren man RONG"
			% a["so_o"])

	# --- B. Ba nguon phai khop -------------------------------------------
	print("\nB. nhan tren man <-> tong theo hai ham goc:")
	var nhan_man := _nhan_tren_man()
	var nhan_lua := int(a["tong_lua"])
	var tong_get := int(a["tong_get"])
	var tong_cal := int(a["tong_cal"])
	print("   nhan tren MAN = \"%s\" | D.nTotalFightingCapacity = %d" % [nhan_man, nhan_lua])
	print("   TONG GetHeroAllFightCapacity = %d | TONG CalHeroAllFightCapacityWithHero = %d"
			% [tong_get, tong_cal])
	_ghi_chu(tong_get > 0,
			"TONG luc chien > 0 (do: %d) — truoc khi lop offline dien hai truong thi cho nay ra 0"
			% tong_get)
	_ghi_chu(_so(nhan_man) == nhan_lua,
			"A. nhan tren MAN (%s) == nTotalFightingCapacity cua Lua (%d)"
			% [nhan_man, nhan_lua])
	_ghi_chu(nhan_lua == tong_get,
			"B. nTotalFightingCapacity (%d) == TONG GetHeroAllFightCapacity tung tuong (%d) — do la ham chinh man goi (:2571)"
			% [nhan_lua, tong_get])
	_ghi_chu(tong_get == tong_cal,
			"C. TONG theo ham DOC TRUONG (%d) == TONG theo ham TINH LAI (%d) — tuc truong da dien dung bang so ma chinh ban goc tinh"
			% [tong_get, tong_cal])

	# --- C. Kiem chung nguoc: xoa hai truong -> nhan phai ve 0 -----------
	print("\nC. kiem chung nguoc — xoa hai truong cua tung tuong dang xep:")
	print("   %s" % str(_lua.run(_XOA, "xoa hai truong")))
	_xa_loi()
	var c1 := _doc_luc()
	var nhan_man_0 := _nhan_tren_man()
	print("   nhan tren MAN = \"%s\" | D.nTotalFightingCapacity = %s" % [nhan_man_0, c1["tong_lua"]])
	_ghi_chu(int(c1["tong_lua"]) == 0 and _so(nhan_man_0) == 0,
			"xoa `FightCapacity` + `AllFightCapacity` thi nhan ve 0 (Lua=%s, man=%s) — phep kiem o nhom B CO LUC"
			% [c1["tong_lua"], nhan_man_0])
	_ghi_chu(int(c1["raw_all"]) == 0,
			"va truong `AllFightCapacity` doc THANG cung la 0 (do: %s) — khong phai man bo qua truong"
			% c1["raw_all"])

	# --- D. Goi lai bo sung -> so cu phai tro lai ------------------------
	print("\nD. goi lai OfflineLucChien:bo_sung() (lan thu hai):")
	var d1 := _khoi_phuc()
	print("   bo sung dien %s tuong | TONG tinh lai lan 2 = %s | nhan = %s | nhan tren MAN = \"%s\""
			% [d1["n_dien"], d1["tong_cal"], d1["tong_nhan"], _nhan_tren_man()])
	_ghi_chu(int(d1["n_dien"]) >= int(a["so_o"]),
			"lan goi thu hai dien lai duoc %s tuong (>= so o dang xep %s)"
			% [d1["n_dien"], a["so_o"]])
	_ghi_chu(int(d1["tong_cal"]) == tong_cal,
			"D. so lan hai BANG so lan dau: %s == %d — loi ghi LUY THUA DANG (goi lai khong doi ket qua)"
			% [d1["tong_cal"], tong_cal])
	_ghi_chu(int(d1["tong_nhan"]) == tong_get and _so(_nhan_tren_man()) == tong_get,
			"va nhan tro lai dung so cu: Lua=%s man=\"%s\" (doi %d)"
			% [d1["tong_nhan"], _nhan_tren_man(), tong_get])

	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)


func _nha(so: int) -> void:
	for i in so:
		_lua.tick(KHUNG)


func _xa_loi() -> void:
	while _da_in < _lua.errors.size():
		print("   loi Lua: %s" % str(_lua.errors[_da_in]).substr(0, 200))
		_da_in += 1


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


## So nguyen doc tu chuoi tren man; -1 nghia la khong doc ra so (khac han "doc
## ra 0" — hai chuyen khac nhau, phai phan biet duoc).
func _so(chuoi: String) -> int:
	var s := chuoi.strip_edges()
	if s.is_valid_int():
		return s.to_int()
	if s.is_valid_float():
		return int(s.to_float())
	return -1


## Nhan `Lực` doc tu NODE THAT trong cay san khau — khong phai tu doi tuong Lua,
## de phep do chung minh con so ay THAT SU ra toi man.
func _nhan_tren_man() -> String:
	var ds := _tim_ten(_san, "lBattleDeployImplement")
	if ds.is_empty():
		return "(khong thay lBattleDeployImplement)"
	for con in ds[0].get_children():
		# Ban goc lay bang `getChildByTag(1)` (:1433) — trong cay con truc tiep
		# co dung mot node mang tag 1, nen khong the lan voi node tag 0 khac.
		if int(con.get_meta("tag", -1)) != 1:
			continue
		if con is Label:
			return (con as Label).text
		return "(tag 1 khong phai nhan: %s)" % con.get_class()
	return "(khong co con truc tiep mang tag 1)"


func _tim_ten(n: Node, ten: String) -> Array:
	var ds: Array = []
	_gom_ten(n, ten, ds)
	return ds


func _gom_ten(n: Node, ten: String, ds: Array) -> void:
	if String(n.name) == ten:
		ds.append(n)
	for c in n.get_children():
		_gom_ten(c, ten, ds)


func _doc_luc() -> Dictionary:
	var r = _lua.run(_DOC, "doc luc chien")
	_xa_loi()
	if r == null:
		return {"so_o": -1, "raw_all": -1, "tong_get": -1, "tong_cal": -1,
				"tong_lua": -1, "chi_tiet": "(doan Lua hong)"}
	return r


func _khoi_phuc() -> Dictionary:
	var r = _lua.run(_KHOI_PHUC, "khoi phuc luc chien")
	_xa_loi()
	if r == null:
		return {"n_dien": -1, "tong_cal": -1, "tong_nhan": -1}
	return r
