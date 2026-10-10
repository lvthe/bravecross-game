# Cua vao cua game: `godot --path .` phai mo thang MAN MAIN THAT cua ban goc,
# va bam Back tu nam man GDScript phai ve do TUC THI.
#
#   godot --headless --path . tools/verify_vao_game.tscn
#
# Phai la bo kiem kieu `scene` chu khong `script`: can autoload `Game`, can
# theme tren root, va can chuoi khoi dong chay trong mot MAN THAT. Duong
# `--script` khong nap autoload nao.
#
# Gia phai tra, ghi ra chu dung de trong nhu loi: nhom D chay THAT ca chuoi
# Login -> Main (~5 giay tren may ranh, 7-15 giay khi chay nang may ao Android),
# nen `tools/check.py` cham them chung ay.
#
# Nam nhom:
#   A. Day noi        — `run/main_scene`, `Game.MENU`, man chu con tren dia.
#   B. Theme          — lop Lua rut ra khoi theme goc, bon man GDScript con nguyen.
#   C. `Tien`/`chay`  — hai duong chay ra CUNG mot vet goi, o bon ngan sach.
#   D. Dau-cuoi       — chuoi that, trong man that, ra Main that.
#   E. Khong ro       — `window_input` khong ket noi them, runtime song qua doi man.
extends Node

const KD := preload("res://game/khoi_dong.gd")

const DUONG_VAO := "res://ui/vao_game.tscn"
const DUONG_MENU_CHU := "res://ui/menu.tscn"

## Theme cua autoload `Game` (`game/ui_theme.gd:87`), ap cho ca cay node. Bon man
## GDScript ma nguoi choi di toi ngay sau do (roster/formation/equip/tasks) song
## nho no, nen no PHAI con — va lop Lua PHAI da rut ra khoi no.
const MAU_THEME_GOC := Color(1, 0.97, 0.9)

## Tran cho ca chuoi. Do duoc ~5 giay tren may ranh (7-15 giay khi chay nang may
## ao Android); de 180 giay de may cham cung khong treo bo kiem, ma neu that su
## ket thi van ra do.
const CHO_TOI_DA_MS := 180000

var _dat := 0
var _hong := 0
var _man: Node = null
var _cho_ms := 0
var _ket_noi_dau := 0


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


## Do duoc nhung KHONG cham diem. Dung cho nhung chuyen co truoc luot nay, hoac
## chuyen khong phai "dung/sai" ma la "dang the nao" — ghim chung thanh phep kiem
## thi ngay bo cuc doi, bo kiem do oan.
func _ghi_nhan(mo_ta: String) -> void:
	print("      [ghi nhan] %s" % mo_ta)


func _ready() -> void:
	# Do TRUOC khi dung gi: moi ket noi them vao `window_input` sau day la ro.
	_ket_noi_dau = get_tree().root.window_input.get_connections().size()
	_nhom_a()
	await _nhom_b_tinh()
	_nhom_c()
	await _dung_man()
	await _nhom_b_cay()
	_nhom_d()
	# PHAI `await`: `_nhom_e` co `await` ben trong, ma goi tran thi no tra ve ngay
	# tai cho ay — `_ready` chay tiep, in tong ket va thoat TRUOC khi sau `await`
	# chay duoc dong nao. Da mac dung mot lan: 6 phep kiem cuoi im lang khong chay.
	await _nhom_e()
	print("\ndat %d, hong %d" % [_dat, _hong])
	get_tree().quit(1 if _hong > 0 else 0)


# ---------------------------------------------------------------------------
# A. Day noi
# ---------------------------------------------------------------------------
func _nhom_a() -> void:
	print("\nA. Day noi")
	var ms := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	_ghi_chu(ms == DUONG_VAO, "run/main_scene = %s" % ms)
	_ghi_chu(Game.MENU == DUONG_VAO, "Game.MENU = %s" % Game.MENU)
	var ps = load(DUONG_VAO)
	_ghi_chu(ps is PackedScene, "man cua vao nap duoc thanh PackedScene")
	# Cua ngo cu KHONG duoc xoa: no la man DUY NHAT con tro toi roster /
	# formation / equip / tasks / battle, nen xoa di la bon man do mat luon
	# duong vao bang duong dan tuong minh.
	_ghi_chu(FileAccess.file_exists(DUONG_MENU_CHU), "ui/menu.tscn van con tren dia")


# ---------------------------------------------------------------------------
# B. Theme — phan tinh, khong can cay Lua
# ---------------------------------------------------------------------------
## Theme de DO co lap: theme goc THAT neu da xuat art giao dien, khong thi mot
## theme tong hop doi dung ba thu ma `game/ui_theme.gd:87-90` doi.
##
## Phai lam vay vi trong repo nay `assets_ref/ui/` CHUA duoc xuat: `UiTheme.tex`
## khong thay `ui_background134.png` nen `UiTheme.build()` tra null, va
## `game/game.gd:115` khong dat duoc theme nao len root — do duoc, `root.theme`
## la null. Lay theme goc ra ma do thi phep kiem co lap KHONG CO LUC. Theme tong
## hop dat dung tinh huong se xay ra luc art duoc xuat, va tu no thanh theme goc
## ngay khi ay (nen phep kiem khong phai sua lai).
func _theme_do() -> Theme:
	var th := UiTheme.build()
	if th != null:
		return th
	var gia := Theme.new()
	gia.set_color("font_color", "Label", MAU_THEME_GOC)
	gia.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	gia.set_constant("outline_size", "Label", 5)
	gia.set_font_size("font_size", "Label", 15)
	return gia


func _nhom_b_tinh() -> void:
	print("\nB. Theme")
	var mac_dinh := ThemeDB.get_default_theme()
	var do_th := _theme_do()
	print("      UiTheme.build() = %s | root.theme = %s"
			% ["null — CHUA xuat assets_ref/ui/" if UiTheme.build() == null else "ok",
			"null" if get_tree().root.theme == null else "co dat"])
	# Theme mac dinh cua Godot ra TRANG va khong vien — dung bang mac dinh cua
	# BAN GOC (`lua/cocos.lua:1609`), nen san khau rui ve day la KHOP.
	_ghi_chu(mac_dinh.get_color("font_color", "Label") == Color(1, 1, 1, 1),
			"theme mac dinh cua Godot: chu TRANG (%s) — dung mac dinh ban goc"
			% mac_dinh.get_color("font_color", "Label"))
	# Chong rong: hai theme TRUNG mau thi phep kiem co lap duoi day khong phan
	# biet duoc gi.
	_ghi_chu(do_th.get_color("font_color", "Label") == MAU_THEME_GOC
			and mac_dinh.get_color("font_color", "Label") != MAU_THEME_GOC,
			"theme de do doi mau chu, va KHAC mau mac dinh (%s vs %s)"
			% [MAU_THEME_GOC, mac_dinh.get_color("font_color", "Label")])
	_ghi_chu(do_th.has_color("font_outline_color", "Label")
			and do_th.has_constant("outline_size", "Label")
			and do_th.has_font_size("font_size", "Label"),
			"theme de do doi ca BA thu: mau, vien, co chu")

	var ngoai := Label.new()
	ngoai.text = "x"
	add_child(ngoai)
	var cu := get_tree().root.theme
	get_tree().root.theme = do_th
	await get_tree().process_frame
	# DO DUOC, khong cham diem: gan `root.theme` KHONG doi duoc mau chu cua mot
	# Control nao, ke ca sau ca mot khung cho lan truyen — trong khi theme cua mot
	# `Control` to tien thi lan ngay (phep kiem ngay duoi). Nghia la duong
	# `game/game.gd:115` (`get_tree().root.theme = th`) hien KHONG ap duoc theme
	# cho bon man GDScript; hom nay chua lo ra chi vi `UiTheme.build()` tra null
	# (chua xuat `assets_ref/ui/`) nen khong co theme nao de ap. Ghi vao ROADMAP,
	# khong ghim thanh phep kiem — ghim "root.theme khong lan" la ghim mot loi,
	# ngay no chay duoc thi bo kiem do oan.
	_ghi_nhan("gan root.theme -> nhan ngoai san khau ra %s (mong doi %s)"
			% [ngoai.get_theme_color("font_color"), MAU_THEME_GOC])
	get_tree().root.theme = cu
	await get_tree().process_frame
	# Co che ma SAN KHAU dua vao la theme cua mot Control to tien — do rieng no de
	# biet phep kiem co lap ben duoi co luc hay khong.
	var cha := Control.new()
	cha.theme = do_th
	add_child(cha)
	var con := Label.new()
	con.text = "x"
	cha.add_child(con)
	_ghi_chu(con.get_theme_color("font_color") == MAU_THEME_GOC,
			"theme cua mot Control to tien -> nhan con theo ngay (ra %s)"
			% con.get_theme_color("font_color"))
	cha.queue_free()
	ngoai.queue_free()


# ---------------------------------------------------------------------------
# C. `Tien` va `chay` khong duoc lech nhau
# ---------------------------------------------------------------------------
## Lua gia: khong `open()` nen khong dung toi LuaState, chi ghi lai VET goi.
##
## `errors` khong khai lai: `LuaRuntime` da co san `var errors: Array[String]`,
## va GDScript khong cho lop con khai de len. Bo dem rong ay dung y ta can —
## khong lenh nao o day that su chay Lua.
class LuaGia extends LuaRuntime:
	## ten chang -> so vong tick can de dieu kien dung; -1 = mai mai sai
	var nguong := {}
	## ten chang -> false nghia la lenh cua chang tra ve null (loi Lua)
	var hanh_dong := {}
	## ["run", ten] / ["tick"] theo dung thu tu
	var nhat: Array = []
	## ten chang -> so vong da tick trong chang do
	var dem := {}
	var dang := ""

	func run(_src: String, ten: String = "doan") -> Variant:
		nhat.append(["run", ten])
		if ten.begins_with("doi "):
			var t := ten.substr(4)
			var n := int(nguong.get(t, 1))
			if n < 0:
				return false
			return int(dem.get(t, 0)) >= n
		if hanh_dong.get(ten, true) == false:
			return null
		dang = ten
		dem[ten] = 0
		return true

	func tick(_d: float) -> int:
		nhat.append(["tick"])
		dem[dang] = int(dem.get(dang, 0)) + 1
		return 0


## Lua gia voi moi chang xong sau `xong_sau` vong.
func _lua_gia(xong_sau: int) -> LuaGia:
	var l := LuaGia.new()
	for c in KD.CHANG:
		l.nguong[String(c[0])] = xong_sau
	return l


## Chay het chuoi tren lua gia, tra ve vet day du.
func _chay_het(l: LuaGia, ngan_sach: int) -> Dictionary:
	var t := KD.Tien.new(l)
	var guard := 0
	while not t.buoc(ngan_sach):
		guard += 1
		if guard > 100000:
			break
	return {"qua": t.qua, "dung": t.dung, "xong": t.xong, "so_vong": t.so_vong,
			"nhat": l.nhat, "dem": l.dem}


func _nhom_c() -> void:
	print("\nC. `Tien` (chia buoc) va `chay` (dong bo) phai ra CUNG mot vet")
	# Chong rong: lua gia phai THAT SU chay qua ca bon chang, khong thi moi phep
	# so duoi day la so hai vet rong.
	var mau := _chay_het(_lua_gia(2), -1)
	_ghi_chu(mau["xong"] and mau["dung"] == "" and mau["qua"].size() == KD.CHANG.size(),
			"lua gia di het %d/%d chang, %d vong tick"
			% [mau["qua"].size(), KD.CHANG.size(), mau["so_vong"]])
	_ghi_chu(mau["so_vong"] > 0, "lua gia that su co tick (%d vong)" % mau["so_vong"])

	# Duong DONG BO cu (`chay`) phai ra y het `buoc(-1)`.
	var dong_bo := KD.Tien.new(_lua_gia(2))
	_ghi_chu(dong_bo.buoc(-1) and dong_bo.xong, "chay buoc(-1) mot luot la het chuoi")
	_ghi_chu(dong_bo.so_vong == int(mau["so_vong"]),
			"cung so vong tick (%d vs %d)" % [dong_bo.so_vong, int(mau["so_vong"])])
	_ghi_chu(dong_bo.ket_qua()["qua"] == mau["qua"]
			and dong_bo.ket_qua()["dung"] == mau["dung"],
			"cung ket qua {qua, dung}")

	# Bon ngan sach: chia nho toi dau cung phai ra cung mot vet goi.
	for ns in [1, 3, 1000, -1]:
		var kq := _chay_het(_lua_gia(2), ns)
		_ghi_chu(kq["qua"] == mau["qua"] and kq["dung"] == mau["dung"],
				"ngan sach %d ms: cung {qua, dung}" % ns)
		_ghi_chu(int(kq["so_vong"]) == int(mau["so_vong"]),
				"ngan sach %d ms: cung so vong tick (%d)" % [ns, int(kq["so_vong"])])
		_ghi_chu(kq["nhat"] == mau["nhat"],
				"ngan sach %d ms: cung DAY DU vet goi run/tick (%d muc)" % [ns, (kq["nhat"] as Array).size()])

	# Nhanh hong 1: dieu kien mai mai sai -> dung dung ten chang, sau DUNG c[3]
	# vong (y nhu vong `for i in range(c[3])` cua ban cu chay het).
	var l2 := _lua_gia(2)
	var ten3 := String(KD.CHANG[2][0])
	l2.nguong[ten3] = -1
	var t2 := KD.Tien.new(l2)
	var g2 := 0
	while not t2.buoc(3):
		g2 += 1
		if g2 > 100000:
			break
	_ghi_chu(t2.dung == ten3, "dieu kien mai sai -> dung o dung ten chang (%s)" % t2.dung)
	_ghi_chu(int(l2.dem.get(ten3, 0)) == int(KD.CHANG[2][3]),
			"dung sau DUNG c[3] = %d vong (%d)"
			% [int(KD.CHANG[2][3]), int(l2.dem.get(ten3, 0))])
	_ghi_chu(t2.qua.size() == 2, "hai chang truoc da xong (%d)" % t2.qua.size())

	# Nhanh hong 2: lenh cua chang tra null -> dung ngay tai chang do.
	var l3 := _lua_gia(2)
	var ten1 := String(KD.CHANG[1][0])
	l3.hanh_dong[ten1] = false
	var t3 := KD.Tien.new(l3)
	var g3 := 0
	while not t3.buoc(3):
		g3 += 1
		if g3 > 100000:
			break
	_ghi_chu(t3.dung.begins_with(ten1 + ": "), "lenh tra null -> '%s'" % t3.dung)
	_ghi_chu(t3.qua.size() == 1, "chi mot chang xong truoc khi dung (%d)" % t3.qua.size())
	_ghi_chu(t3.xong and int(l3.dem.get(ten1, 0)) == 0,
			"khong tick vong nao trong chang hong")


# ---------------------------------------------------------------------------
# Dung: man cua vao THAT, trong cay that
# ---------------------------------------------------------------------------
func _dung_man() -> void:
	_man = (load(DUONG_VAO) as PackedScene).instantiate()
	add_child(_man)
	var t0 := Time.get_ticks_msec()
	while not Game.da_vao and Time.get_ticks_msec() - t0 < CHO_TOI_DA_MS:
		await get_tree().process_frame
	_cho_ms = Time.get_ticks_msec() - t0


func _san() -> Control:
	if Game.lop_lua == null:
		return null
	return Game.lop_lua.get_node_or_null("SanLua") as Control


func _nhan_duoi(n: Node) -> Array:
	var ra: Array = []
	var ds: Array = [n]
	while not ds.is_empty():
		var x: Node = ds.pop_back()
		for c in x.get_children():
			ds.append(c)
		if x is Label:
			ra.append(x)
	return ra


func _hien_that(n: Node) -> bool:
	var p := n
	while p != null:
		if p is CanvasItem and not (p as CanvasItem).visible:
			return false
		p = p.get_parent()
	return true


## So node dang HIEN ma co `texture` — phep dem "khong phai man den". Khac
## `vao_main._thong_ke_ve` o cho no dem CA `Sprite2D` (rig nam trong do), khong
## chi `Control`.
func _dem_anh(n: Node) -> int:
	var so := 0
	var ds: Array = [n]
	while not ds.is_empty():
		var x: Node = ds.pop_back()
		for c in x.get_children():
			ds.append(c)
		if x is CanvasItem and x.get("texture") != null and _hien_that(x):
			so += 1
	return so


# ---------------------------------------------------------------------------
# B (phan cay) — lop Lua da rut ra khoi theme goc
# ---------------------------------------------------------------------------
func _nhom_b_cay() -> void:
	print("\nB (cay Lua). Theme cua san khau")
	var san := _san()
	if san == null:
		_ghi_chu(false, "khong thay san khau Lua — bo qua phan con lai cua nhom B")
		return
	var mac_dinh := ThemeDB.get_default_theme().get_color("font_color", "Label")
	_ghi_chu(san.theme == ThemeDB.get_default_theme(),
			"san khau mang theme MAC DINH cua engine")

	var ds := _nhan_duoi(san)
	_ghi_chu(ds.size() > 0, "cay Lua co %d nhan" % ds.size())
	var khong_ghi_de := 0
	var vi_du: Label = null
	for l in ds:
		if not (l as Label).has_theme_color_override("font_color"):
			khong_ghi_de += 1
			if vi_du == null:
				vi_du = l
	_ghi_chu(khong_ghi_de > 0,
			"%d/%d nhan khong ghi de font_color -> lay mau tu THEME"
			% [khong_ghi_de, ds.size()])
	if vi_du == null:
		_ghi_chu(false, "moi nhan deu ghi de font_color — khong do duoc co lap")
		return

	# Dat theme de do LEN ROOT — dung tinh huong se xay ra khi art giao dien duoc
	# xuat — roi kiem lop Lua co mien nhiem khong. Tra `root.theme` ve gia tri
	# THAT cua no sau khi do.
	# Kiem chung NGUOC, do tren CHINH san khau: doi `san.theme` sang theme goc thi
	# nhan Lua doi mau theo — tuc la mau dang ra LA do `san.theme` quyet dinh,
	# khong phai nhan Lua bo qua moi theme.
	var do_th := _theme_do()
	san.theme = do_th
	await get_tree().process_frame
	_ghi_chu(vi_du.get_theme_color("font_color") == MAU_THEME_GOC,
			"doi san khau sang theme goc -> nhan Lua doi theo (%s)"
			% vi_du.get_theme_color("font_color"))
	san.theme = ThemeDB.get_default_theme()
	await get_tree().process_frame
	_ghi_chu(vi_du.get_theme_color("font_color") == mac_dinh,
			"tra san khau ve theme mac dinh -> nhan Lua ve mau engine")


# ---------------------------------------------------------------------------
# D. Dau-cuoi
# ---------------------------------------------------------------------------
func _nhom_d() -> void:
	print("\nD. Dau-cuoi: chuoi Login -> Main chay trong mot MAN THAT")
	print("   (gia phai tra: man cua vao cho %d ms)" % _cho_ms)
	_ghi_chu(Game.da_vao, "chuoi Login -> Main da chay xong")
	_ghi_chu(_cho_ms < CHO_TOI_DA_MS, "cho %d ms, duoi tran %d" % [_cho_ms, CHO_TOI_DA_MS])
	_ghi_chu(Game.lua != null and is_instance_valid(Game.lua),
			"runtime da giao cho autoload `Game`")
	if Game.lua == null:
		return
	var bao = Game.lua.run(KD.BAO, "bao cao")
	if bao == null:
		_ghi_chu(false, "chay KD.BAO tra null: %s" % ", ".join(Game.lua.errors))
		return
	_ghi_chu(String(bao.get("CurrentScene", "")) == "Main",
			"CurrentScene = Main (%s)" % bao.get("CurrentScene", "?"))
	_ghi_chu(String(bao.get("dang doi canh", "")) == "false", "khong con doi canh")
	_ghi_chu(not bao.has("LOI CHET 1"), "khong co loi CHET cua coroutine doi canh")
	_ghi_chu(String(bao.get("g_MainUIScene", "")) == "true", "g_MainUIScene nam tren san khau")
	_ghi_chu(String(bao.get("lMainBtnLayer", "")) == "true", "lMainBtnLayer da dat")
	print("      so loi goc (dem, khong phai loi cua luot nay): %s" % bao.get("so loi goc", "?"))

	var san := _san()
	_ghi_chu(san != null and san.get_child_count() > 0,
			"san khau co %d node con" % (san.get_child_count() if san != null else -1))
	var co_anh := _dem_anh(san) if san != null else 0
	_ghi_chu(co_anh > 0, "co %d node dang HIEN ma co anh — khong phai man den" % co_anh)


# ---------------------------------------------------------------------------
# E. Khong ro, va duong quay ve tuc thi
# ---------------------------------------------------------------------------
func _nhom_e() -> void:
	print("\nE. Khong ro, va quay ve")
	var giua := get_tree().root.window_input.get_connections().size()
	# Man cua vao KHONG duoc tu noi vao `window_input`: tin hieu ay thuoc Window
	# va song lau hon moi man, nen mot lambda nop tu trong man se thanh callback
	# tren vat da giai phong, moi khi doi man. `Game` noi MOT lan, tu autoload.
	_ghi_chu(giua == _ket_noi_dau,
			"man cua vao khong noi them vao window_input (%d -> %d)" % [_ket_noi_dau, giua])

	var lua := Game.lua
	_man.free()
	_man = null
	await get_tree().process_frame
	var sau := get_tree().root.window_input.get_connections().size()
	_ghi_chu(sau == _ket_noi_dau, "giai phong man khong de lai ket noi (%d -> %d)"
			% [_ket_noi_dau, sau])
	_ghi_chu(Game.lua == lua and is_instance_valid(lua),
			"runtime CON SONG sau khi man cua vao bi huy")
	_ghi_chu(Game.da_vao and Game.lop_lua != null and not Game.lop_lua.visible,
			"lop Lua tu an khi roi man (khong de cu cham man tran bam vao nut Main)")

	# Duong quay ve: dung lai man cua vao, phai an tam nen NGAY va khong nap lai.
	var t0 := Time.get_ticks_msec()
	var man2 = (load(DUONG_VAO) as PackedScene).instantiate()
	add_child(man2)
	var ms := Time.get_ticks_msec() - t0
	_ghi_chu(ms < 500, "quay ve mat %d ms (nap lai thi ~5000 ms)" % ms)
	_ghi_chu(Game.lua == lua, "runtime VAN LA chinh no, khong nap lai")
	_ghi_chu(not (man2.get_node("Nen") as CanvasItem).visible
			and not (man2.get_node("Nhan") as CanvasItem).visible,
			"tam nen da an ngay")
	_ghi_chu(Game.lop_lua.visible, "lop Lua bat lai khi vao lai man")
	man2.free()
