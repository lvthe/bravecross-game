# Cua vao cua game: chay chuoi Login -> Main cua BAN GOC, roi tra man cho lop Lua.
#
#     godot --path .                  # mo thang vao day
#
# Man nay khong ve giao dien game. No lam dung ba viec: dung san khau Lua, chay
# chuoi khoi dong, roi an tam nen di. Giao dien that la cua lop Lua — va lop Lua
# KHONG thuoc man nay (xem `game/game.gd`, bien `lop_lua`), nen doi man khong
# giet no.
#
# Nam man GDScript kia (`battle` / `equip` / `formation` / `roster` / `tasks`)
# tro ve day bang `Game.goto(Game.MENU)`. Vi runtime da nap san tu lan dau, lan
# ve do la TUC THI: khong chay lai chuoi ~5 giay.
extends Control

const KD := preload("res://game/khoi_dong.gd")

## Mili giay tick Lua cho mot khung.
##
## Do duoc: ca chuoi chi co **18 vong** `tick()` — khong phai ~314 khung nhu da
## tuong — nen ngan sach 8 ms hay 16 ms deu cho ra dung mot vong mot khung, va no
## khong lam cham them lan nao. Dat nho de may nhanh thi khung van con thoi gian
## ve.
##
## Con so thoi gian: ba lan chay may RANH ra chuoi **3499 / 3630 / 3957 ms**
## (~200 ms mot vong trung binh), con `nap` **1312 / 1482 / 1293 ms**. Chay nang
## may ao Android thi chuoi len **11517 ms** (~640 ms mot vong) — moi con so ghi
## o tep nay truoc luot do lai deu thuoc truong hop NANG do, xem `CLAUDE.md`
## muc "Cua vao".
const NGAN_SACH_MS := 8

@onready var _nen: ColorRect = $Nen
@onready var _nhan: Label = $Nhan

var _lua: LuaRuntime = null
## Bo chia buoc chuoi khoi dong. Kieu that lay qua `KD` (lop con cua mot script
## `preload`), nen khong can khai lai lop nao.
var _tien: KD.Tien = null
var _t0_chuoi := 0
var _truoc := -1
var _khung := 0
var _cach_lon_nhat := 0


func _ready() -> void:
	# Bat lai lop Lua: `_exit_tree` da an no di khi roi man nay (vao tran, vao
	# tui do...), ma lop Lua khong thuoc man nen `change_scene_to_file` khong
	# dung toi no. Duong quay ve cung phai bat, vi luc do no dang an.
	if Game.lop_lua != null:
		Game.lop_lua.visible = true

	if Game.da_vao:
		# Quay ve tu mot man khac: runtime con song, san khau con nguyen tren cay,
		# chuoi khoi dong khong chay lai. Viec duy nhat la an tam nen di.
		_an()
		return

	# Ma goc. Thieu no thi khong con gi de chay — va phai NOI RA, dung de nguoi
	# dung ngoi nhin mot man den roi tuong game hong.
	if LuaRuntime.thieu_ma_goc():
		_nhan.text = "Thieu ma goc Lua.\nChay: python tools/import_lua.py"
		return

	if not _dung_san_khau():
		return

	# Nha mot khung de tam nen kip VE truoc khoi `NAP` ben duoi. `process_frame`
	# chu KHONG `RenderingServer.frame_post_draw`: bo kiem chay `--headless`, tin
	# hieu ấy khong bao gio phat va bo kiem treo.
	await get_tree().process_frame

	var t0 := Time.get_ticks_msec()
	var r = _lua.run(KD.NAP, "nap")
	if r == null:
		_nhan.text = "Nap ma goc hong:\n" + "\n".join(_lua.errors)
		push_error("nap ma goc hong: %s" % ", ".join(_lua.errors))
		return
	print("nap %s module, cau hinh %s (%d ms)"
			% [r.get("nap", "?"), r.get("cau hinh", "?"), Time.get_ticks_msec() - t0])
	for k in r:
		if str(k).contains("khoi dong"):
			print("  %s: %s" % [k, str(r[k]).substr(0, 200)])

	_tien = KD.Tien.new(_lua)
	# Do thoi gian TUNG vong tick: khoi dung hinh nam trong mot vong `tick()` cua
	# ma goc, chu khong rai deu — xem phan in o `_xong_chuoi`.
	_tien.do_vong = true
	_t0_chuoi = Time.get_ticks_msec()


## In ba vong tick dat nhat, kem ten chang.
##
## Co no vi "dung hinh may giay" khong phai mot con so rai deu: do duoc vong dat
## nhat chiem phan lon ca chuoi, va no NAM TRONG `tick()` cua lop Lua (`InitUI`
## dung ca canh Main trong MOT vong). Biet ten chang thi moi biet cho ma cat —
## va cung moi biet rang cat `boot_goc` (vai tram mili giay) KHONG giai quyet
## duoc gi.
func _in_vong_dat_nhat() -> void:
	var ds := _tien.vong.duplicate()
	ds.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var dau := []
	for i in mini(3, ds.size()):
		dau.append("%s %d ms" % [ds[i][1], ds[i][0]])
	print("vong tick dat nhat: %s" % (", ".join(dau) if not dau.is_empty() else "(khong do)"))


## Dung san khau Lua duoi lop `Game.lop_lua`. Tra `false` neu khong dung duoc —
## ly do da ghi len `_nhan` va ra `push_error`.
func _dung_san_khau() -> bool:
	# Co cua so cua ENGINE: cao co dinh 768, rong theo ti le man — may ao do duoc
	# ca 13 CCScene la 1429x768 tai (0,0). San khau mang co do roi thu nho cho vua
	# cua so Godot.
	#
	# Lay tu CAI DAT DU AN, khong tu `root.size`: luc nay cua so that chua kip doi
	# ve co that (headless bao ~178x100) va ca canh bi thu nho vao goc tren trai.
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	var cua_so := Vector2(roundf(768.0 * vp.x / vp.y), 768.0)

	_lua = LuaRuntime.new()
	_lua.cua_so_engine = cua_so
	if not _lua.open():
		_nhan.text = "Khong mo duoc khung suon Lua:\n" + "\n".join(_lua.errors)
		push_error("khong mo duoc khung suon Lua: %s" % ", ".join(_lua.errors))
		_lua = null
		return false
	XggLayout.respect_visible = true

	var san := Control.new()
	san.name = "SanLua"
	san.size = cua_so
	san.scale = Vector2.ONE * (vp.y / cua_so.y)
	# Lop Lua tu lo cu cham (no nhan qua `window_input` cua cua so), nen san khau
	# khong duoc nuot cu bam cua man khac.
	san.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# San khau RUT RA khoi theme cua autoload: theme do doi BA thu tren MOI nhan
	# — mau kem, vien den 5 px, co chu 15 — trong khi ban goc chi vien nhan nao
	# xin vien va co chu lay tu engine. Xem chum o `game/game.gd:_ready`.
	san.theme = ThemeDB.get_default_theme()
	_lua.set_stage(san)
	_lua.set_touch_root(san)
	# Phai vao CAY truoc khi nap: `AudioStreamPlayer` ngoai cay KHONG phat, nen
	# moi tieng ma ban goc xin trong luc nap deu mat trang (do o
	# `tools/verify_am.gd:393-408`).
	Game.lop_lua.add_child(san)
	return true


## Buoc chuoi khoi dong mot chut moi khung, va DO khoang cach giua hai khung.
##
## Khoi `NAP` (mot lan `lua.run`, khong cat duoc) va tung vong `tick` nam trong
## than ham nay hoac trong `_ready`, nen chung lo ra o day thanh nhung khoang
## rong. Do bang so chu khong doan: ba lan chay may ranh ra **2634 / 2740 /
## 3053 ms** — duoi tran 4000 ms. Nguong do khong dat duoc khi chay nang may ao
## Android (do duoc toi 6092 ms); xem `CLAUDE.md` muc "Cua vao".
func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec()
	if _truoc >= 0:
		_cach_lon_nhat = maxi(_cach_lon_nhat, t - _truoc)
	_truoc = t
	_khung += 1
	if _tien == null or _tien.xong:
		return
	if _tien.buoc(NGAN_SACH_MS):
		_xong_chuoi()


func _xong_chuoi() -> void:
	var ms := Time.get_ticks_msec() - _t0_chuoi
	print("chuoi Login -> Main: %d ms (%d khung, %d vong tick Lua)"
			% [ms, _khung, _tien.so_vong])
	print("khoang cach LON NHAT giua hai khung: %d ms" % _cach_lon_nhat)
	_in_vong_dat_nhat()
	print("chang da qua: %s" % (", ".join(_tien.qua) if not _tien.qua.is_empty() else "(chua)"))
	print("dung o: %s" % (_tien.dung if _tien.dung != "" else "(khong — toi Main)"))
	var bao = _lua.run(KD.BAO, "bao cao")
	if bao != null:
		for k in ["CurrentScene", "dang doi canh", "g_MainUIScene", "lMainBtnLayer", "so loi goc"]:
			if bao.has(k):
				print("  %-18s %s" % [k, bao[k]])
		for k in bao:
			if str(k).begins_with("LOI CHET") or str(k).begins_with("HONG"):
				print("  %s: %s" % [k, str(bao[k]).substr(0, 200)])
	# Giao lop Lua cho autoload — tu day `Game._process` tick, va
	# `Game._su_kien_cua_so` day cu cham vao. Dat SAU khi chuoi xong, de cu cham
	# trong luc khoi dong khong pha chuoi.
	Game.lua = _lua
	Game.da_vao = true
	if _tien.dung == "":
		_an()
	else:
		# Dung giua duong thi PHAI hien ly do: lop Lua con nguyen nhung man hinh
		# se trong, de nguoi dung tuong game hong.
		_nhan.text = "Khoi dong dung o: %s" % _tien.dung


## Roi man nay (vao tran, vao tui do...): an lop Lua di.
##
## Lop Lua khong thuoc man nen `change_scene_to_file` khong ha no xuong — phai tu
## an. Khong an thi no van hit-test cu cham: bam vao nut cua man tran cung bam
## luon vao nut Main nam duoi no.
func _exit_tree() -> void:
	if Game.lop_lua != null:
		Game.lop_lua.visible = false


func _an() -> void:
	_nen.visible = false
	_nhan.visible = false
