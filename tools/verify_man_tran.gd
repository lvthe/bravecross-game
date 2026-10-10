# Ba loi lam man tran KHONG CHOI DUOC (hoac nhin sai han), khoa lai bang so do.
#
#   godot --headless --path . tools/verify_man_tran.tscn
#
# A. TAM DEN PHU KIN SAN. Bo cuc HUD cua ban goc
#    (`layout_ref/Game_UI_Control_Panel_960_640.json`) co node
#    `g_BlackEffectLayer`: `CCLayerColorRoundRect`, 2000x1000 o (-200,-200), mau
#    [0,0,0], opacity 255, va trong file ghi `visible: True`. Dung nguyen bo cuc
#    thi ra MAN DEN TUYET DOI — do tren khung hinh that: 614.400/614.400 diem
#    anh cung MOT mau (0,0,0); an HUD di thi ra 2540 mau. Ban goc tat no bang co
#    `bShowBattleBlackEffectLayer`, va ai thuong dat co ay `false`
#    (`sc/user/Battle/ChapterNormalLevel.lua:8` — mot lan gan duy nhat trong ca
#    kho `sc/`). Khong file Lua nao doc co ay: no la truong ben C++ doc, va ten
#    node `g_BlackEffectLayer` nam trong pool chuoi cua `libgame.so` (ban vn
#    `0x7c0dc7`, canh `getEliteNameLabel` va `PauseLeaderShipTimer`) — tuc engine
#    tim node theo TEN roi tu bat/tat.
#
# B. QUAN KHONG CO ART. `SpriteName` trong bang quan chung la ten LOAI QUAN chu
#    khong phai ten armature: bang ghi `Archer(new)`, `Hoplite(董军入侵)`,
#    `Stakes`, `witch doctor`, con thu muc art ten `Archer`, `Hoplite`,
#    `Spearmen`, `WitchDoctor`. Doi chieu voi kho atlas cua CHINH ban goc thi
#    62/80 ten khong co armature nao. `SngRig.build` tra null VA `push_error`
#    khi thieu file `.json`, nen mot tran ra hang tram dong
#    `SngRig: khong thay res://assets_ref/...`. Bon bo kiem khong bat duoc: bo do
#    tran chay bang `--sim`, ma duong ay goi `_spawn(false)` — tat han phan hinh.
#
#    Don vi thieu art VAN PHAI DANH (mo phong khong dinh gi toi hinh; bo no khoi
#    tran moi la doi thanh phan quan cua chuong — README: do la doi do kho, phai
#    do lai). Nen phep kiem khoa CA HAI CHIEU: ten CO armature thi PHAI hien,
#    ten KHONG co thi PHAI vo hinh — nhung van nam tren san va van danh.
#
#    Chieu thu hai chong "sua loi" nguoc: kho co luat tien to se cuu duoc 32/62
#    ten (`Archer(new)` -> thu muc `Archer`), nhung 0/80 ten la bien the that su
#    — ap luat ay la hien sai quan. Phep kiem bat luon ca duong do.
#
# Phep kiem chay DUNG `_build_hud()` va `_add_unit()` cua man tran, khong dung
# lai mot ban sao: khoa mot ban sao thi sua man tran xong bo kiem van xanh.
#
# E. NHAN VAT VAO TRAN KHONG CO THAN. Bo loc ve tich cua `SngRig` khop theo TIEN
#    TO va co ca `Logic_`, ma `Logic_Body` giu dung anh THAN nhan vat — xem khoi
#    chu thich o `_kiem_xuong_than()`. Man tran la cho duy nhat con truyen
#    `no_clutter = true`, nen mat than CHI o man tran.
#
# F. HE SO PARALLAX CUA CAC LOP NEN. `_tim_lop` doc meta `parallax` cua tung lop
#    anh em, va ban dau doc bang `get_meta("parallax", null)` — ma Godot 4.7.2
#    coi `null` la "khong truyen mac dinh", tuc loi y het `get_meta(t)` (do lai
#    2026-09-21 bang mot phep thu rieng). Hau qua: MOI lop khong khai he so sinh
#    mot dong loi, va bo cuc ai thuong
#    (`layout_ref/BattleField_Battlefield_960_640.json`) co dung **5** lop nhu
#    the — nguoi dung thay 5 dong loi moi lan vao tran.
#
#    "Vang mat = 1" khong phai doan: `brave-cross/work/layout.py:68` CHI ghi
#    truong nay khi khac `[1,1]`, nen node khong co truong la node he so 1. Do
#    tren chinh file ay: **29/34** node goc co truong va **0** node ghi dung
#    `[1,1]` — ty le ay la bang chung nguoc cho luat, khong phai suy dien.
#
#    Nam lop thieu truong la `g_BattleField` (0x0) va bon dai mat dat
#    `gb1_0..gb1_3` (1024x40 o x = 0/1024/2048/3072); bon dai ay noi lien
#    **0..4096 px = 40,96 o** — va do cung la BE DAI THAT cua san.
#
#    Cung nam lop nen ay la MEP SAN THAT (`_trai`/`_phai`) — ba so khac han nhau
#    tung bi lan vao nhau: san 0..4096, khung nhin 1152 (do o cua so 16:9),
#    camera troi duoc 2944. Truoc 2026-09-21 `_trai`/`_phai` lay theo Control
#    NGOAI CUNG (khung nhin), nen san dan ra hep 3,56 lan va quan tiep vien cua
#    dich vao tran o x = 1152 - 90 = 1062, tuc giua san, thay vi mep phai that
#    (4006). Camera thi khong doi: `_cam_max` va `CAM_NGUONG` nay dung `_man`
#    (be ngang khung nhin) — truoc do chung an theo `_phai`/`_trai` cua khung
#    nhin, tuc tinh co ra dung.
#
#    Phep kiem chay DUNG `_tim_lop` cua man tran tren mot cay giao dien tu dung
#    (khong chep lai ham: chep thi sua man tran xong bo kiem van xanh), va khoa
#    ca so lieu cua bo cuc.
extends Node

const MAN := preload("res://battle/battle.gd")
const SAN := preload("res://battle/san_tran_ve.gd")
const HUONG := "res://layout_ref/Game_UI_Control_Panel_960_640.json"
const BANG := "res://data_ref/battle_data.json"
const ART := "res://assets_ref/"
const BO_CUC_SAN := "res://layout_ref/BattleField_Battlefield_960_640.json"

## O man, de phan biet "lop che" voi "o trang tri nho".
const O_MAN := Vector2(960.0, 640.0)

## Vai ten lay lam vi du co dinh. Khong phai de thay cho phep quet ca bang — phep
## quet moi la thu khoa luat — ma de doc ra NGAY trong ket qua khi bang doi: bon
## ten duoi day la bon kieu ten khac nhau ma bang dang co.
const VI_DU := ["Archer", "Hoplite(new)", "Stakes", "witch doctor"]

var _dat := 0
var _hong := 0


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


## Cac ten BIEN THE ghi trong chinh file armature (`groups[].variant`).
func _bien_the_cua(thu_muc: String) -> Dictionary:
	var ra := {}
	var p := ART.path_join(thu_muc).path_join(thu_muc + ".json")
	if not FileAccess.file_exists(p):
		return ra
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY:
		return ra
	for g in (d.get("groups", []) as Array):
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var v := String(g.get("variant", ""))
		if v != "":
			ra[v] = true
	return ra


## Thu muc GOC ma luat tien to cua kho chon cho ten nay ("" neu khong ra). Chep
## lai dung vong lap cua `san_tran_ve._thu_muc_rig` / `LuaRuntime._tao_rig` de do
## xem luat ay se lam gi voi bang ten nay.
##
## Khac mot cho: luat trong kho hoi `FileAccess.file_exists`, ma tren Windows phep
## ay KHONG phan biet chu hoa/thuong — no nhan ca `assets_ref/witch/` trong khi
## thu muc that ten `Witch`. O day doi chieu voi danh sach thu muc THAT (exact
## case), vi ban xuat ra nen tang phan biet chu hoa/thuong thi duong kia dut. So
## `_chi_khac_chu()` dem rieng nhung ten nhu vay.
func _thu_muc_tien_to(ten: String) -> String:
	for i in range(ten.length() - 1, 3, -1):
		var goc := ten.substr(0, i).trim_suffix("_")
		if _thu_muc.has(goc) \
				and FileAccess.file_exists(ART.path_join(goc).path_join(goc + ".json")):
			return goc
	return ""


## Ten thu muc THAT trong `assets_ref` (dung nguyen chu hoa/thuong nhu tren dia).
var _thu_muc := {}


func _nap_thu_muc() -> void:
	_thu_muc.clear()
	var d := DirAccess.open("res://assets_ref")
	if d == null:
		return
	for n in d.get_directories():
		_thu_muc[n] = true


## Cac ten ma luat tien to CHI ra duoc nho `file_exists` khong phan biet chu
## hoa/thuong: tren Windows chung "chay", ra ban xuat thi khong.
func _chi_khac_chu(ten: String) -> bool:
	if _thu_muc_tien_to(ten) != "":
		return false
	for i in range(ten.length() - 1, 3, -1):
		var goc := ten.substr(0, i).trim_suffix("_")
		if FileAccess.file_exists(ART.path_join(goc).path_join(goc + ".json")):
			return true
	return false


## Ten quan trong bang quan chung (`SpriteName`), da bo trung va xep theo thu tu
## chu cai de ket qua doc ra on dinh giua cac lan chay. `armies` la mot MANG 80
## muc, khong phai bang tra theo ten.
func _ten_trong_bang() -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(BANG):
		return out
	var d = JSON.parse_string(FileAccess.get_file_as_string(BANG))
	if typeof(d) != TYPE_DICTIONARY:
		return out
	var thay := {}
	for muc in (d.get("armies", []) as Array):
		if typeof(muc) != TYPE_DICTIONARY:
			continue
		var t := String(muc.get("SpriteName", ""))
		if t != "":
			thay[t] = true
	for k in thay:
		out.append(String(k))
	out.sort()
	return out


## Do "lop che den duc phu kin man" tren mot cay giao dien da dung.
##
## Quet CA CAY chu khong chi nham ten `g_BlackEffectLayer`: mot tam den khac moc
## vao sau nay cung phai lo ra. Dieu kien nhan dang doc tu chinh phep do da tim
## ra thu pham — `ColorRect` DANG HIEN, alpha >= 0,99 (duc), ba kenh mau cong lai
## < 0,1 (den), va o (da nhan ti le) lon hon ca o man.
func _dem_lop_che(n: Node, ra: Array) -> void:
	if n is ColorRect and n.visible:
		var cr := n as ColorRect
		var c := cr.color
		var o := cr.size * cr.scale
		if c.a >= 0.99 and (c.r + c.g + c.b) < 0.1 \
				and o.x >= O_MAN.x and o.y >= O_MAN.y:
			ra.append(cr)
	for ch in n.get_children():
		_dem_lop_che(ch, ra)


# --- A. Tam den ------------------------------------------------------------

func _kiem_tam_den() -> void:
	print("\nA. Tam den phu kin san (bo cuc HUD cua ban goc):")
	if not FileAccess.file_exists(HUONG):
		print("   BO QUA: chua co %s" % HUONG)
		return
	# Dung CHINH `_build_hud` cua man tran. Node khong can nam trong cay: bo cuc
	# duoc dung trong bo nho, va `find_node` di theo cay con cua no.
	var man := MAN.new()
	man._build_hud()
	if man.hud == null:
		_ghi_chu(false, "khong dung duoc HUD tu %s" % HUONG)
		man.free()
		return

	var den := XggLayout.find_node(man.hud, "g_BlackEffectLayer")
	# Node PHAI CON: no thuoc bo cuc cua ban goc, va ban goc chi TAT no chu khong
	# xoa. Xoa di la mat mot manh bo cuc — va cac che do tran khac (dau truong,
	# ai vo tan) moi la cho bat no len.
	_ghi_chu(den != null, "bo cuc con node g_BlackEffectLayer (ban goc chi tat, khong xoa)")
	if den != null:
		_ghi_chu(not den.visible, "g_BlackEffectLayer dang TAT")

	var che := []
	_dem_lop_che(man.hud, che)
	_ghi_chu(che.is_empty(),
			"khong con lop che den duc nao phu kin man (tim thay %d)" % che.size())
	for cr in che:
		print("        con lai: %s o %s mau %s" % [cr.name, cr.size, cr.color])

	man.free()


# --- B. Luat art theo du lieu ---------------------------------------------

func _kiem_luat_art(ten: PackedStringArray) -> void:
	print("\nB. Ten quan trong bang doi chieu voi kho armature:")
	if ten.is_empty():
		_ghi_chu(false, "khong doc duoc %s" % BANG)
		return

	var co := 0
	var khong := 0
	var lech := 0
	for t in ten:
		# Duong doc DOC LAP voi `MAN.co_art`: tu ghep duong dan o day. Hai duong
		# phai ra cung ket qua cho MOI ten — lech mot ten la `co_art` khong con la
		# phep kiem "co thu muc armature that".
		var that := FileAccess.file_exists(ART.path_join(t).path_join(t + ".json"))
		if that:
			co += 1
		else:
			khong += 1
		if MAN.co_art(t) != that:
			lech += 1
	print("   %d ten trong bang: %d co armature, %d khong" % [ten.size(), co, khong])
	for v in VI_DU:
		print("        %-16s %s" % [v, "CO" if MAN.co_art(v) else "khong"])

	_ghi_chu(lech == 0, "co_art khop phep doc file cho ca %d ten (lech %d)"
			% [ten.size(), lech])
	# Hai lop deu phai CO THAT, khong thi phan con lai cua phep kiem la rong:
	# "moi ten deu co art" thi nhanh vo hinh khong bao gio chay.
	_ghi_chu(co > 0 and khong > 0,
			"bang co CA HAI loai ten (%d co / %d khong)" % [co, khong])
	_ghi_chu(not MAN.co_art("") , "ten rong tra false (khong phai 'res://assets_ref//.json')")

	# Chieu thu hai — chieu chong "sua loi" nguoc: kho CO mot luat tien to
	# (`san_tran_ve._thu_muc_rig`, cung luat voi `LuaRuntime._tao_rig`) se cuu
	# duoc 32/62 ten: `Archer(new)` ra thu muc `Archer`, `Catapult(董军入侵)` ra
	# `Catapult`. Nhung quet bien the cua chinh cac file goc thi **0/80** ten
	# trong bang la bien the that su — `(new)` va `(董军入侵)` la LOAI QUAN cua ban
	# moi, art khong co trong APK nay. Ap luat tien to la hien sai quan
	# (`Archer(new)` mang hinh Archer cu). Phep kiem khoa lai: ten nao ra duoc thu
	# muc goc ma khong phai bien the cua no thi `co_art` PHAI tra false.
	var bay := 0
	var cuu_nham := 0
	var khac_chu := 0
	_nap_thu_muc()
	for t in ten:
		if FileAccess.file_exists(ART.path_join(t).path_join(t + ".json")):
			continue
		if _chi_khac_chu(t):
			khac_chu += 1
		var goc := _thu_muc_tien_to(t)
		if goc == "" or _bien_the_cua(goc).has(t):
			continue
		bay += 1
		if MAN.co_art(t):
			cuu_nham += 1
	print("   luat tien to 'cuu' duoc %d ten, trong do 0 ten la bien the that su" % bay)
	if khac_chu > 0:
		print("   (%d ten nua chi ra duoc nho file_exists khong phan biet chu hoa/thuong)"
				% khac_chu)
	_ghi_chu(bay > 0 and cuu_nham == 0,
			"luat tien to khong cuu nham ten nao sang hinh quan khac (cuu nham %d)" % cuu_nham)


# --- C. Don vi thieu art van danh -----------------------------------------

func _man_tran() -> Node2D:
	var man: Node2D = MAN.new()
	man.combat = Combat.new()
	var err: String = man.combat.load_data()
	if err != "":
		push_error(err)
	man.picks_seed = 1
	man._new_rosters(1)
	return man


## Day CA 80 ten trong bang qua `_add_unit` — dung cho that da sinh ra dong loi.
## Hai dieu phai dung cho tung ten: don vi VAN NAM TREN SAN (`teams`), va
## `visual` dung bang "co armature hay khong".
func _kiem_add_unit(ten: PackedStringArray) -> void:
	print("\nC. Day ca bang ten qua _add_unit (duong tung sinh loi SngRig):")
	var man := _man_tran()
	var hien := 0
	var an := 0
	var mat := 0
	for t in ten:
		var truoc: int = man.teams[0].size()
		man._add_unit(man.combat.make_army(t, 6), 0, [200.0, 300.0], t, true)
		if man.teams[0].size() != truoc + 1:
			mat += 1
			continue
		var u = man.teams[0][truoc]
		if u.visual:
			hien += 1
		else:
			an += 1
		if MAN.co_art(t) != bool(u.visual):
			mat += 1
	print("   %d don vi: %d co hinh, %d vo hinh" % [ten.size(), hien, an])
	_ghi_chu(mat == 0, "khong don vi nao bi mat hay nham hinh (lech %d)" % mat)
	_ghi_chu(an > 0, "co don vi VO HINH nhung van o tren san (%d)" % an)
	_ghi_chu(hien > 0, "co don vi CO hinh (%d) — neu khong thi phep kiem la rong" % hien)
	man.free()


## Tran that: bat/tat phan hinh khong duoc doi mot con so nao cua mo phong.
##
## Day moi la cau tra loi cho "don vi thieu art co danh khong": neu `visual` lot
## vao toc do / tam danh / thu tu ra don thi ben co hinh va ben vo hinh se ra hai
## tran khac nhau. Chay HAI lan cung seed, khac dung mot tham so `with_art`.
func _kiem_ban_tran() -> void:
	print("\nD. Bat/tat phan hinh, cung seed — tran phai y het nhau:")
	var ket := []
	for with_art in [false, true]:
		var man := _man_tran()
		man._spawn(with_art)
		var n: int = man.teams[0].size() + man.teams[1].size()
		var ra := -1
		var guard := 0
		while ra < 0 and guard < 100000:
			ra = man._step(MAN.STEP)
			guard += 1
		var hp := 0.0
		for t in 2:
			for u in man.teams[t]:
				hp += u.fighter.hp
		ket.append({"n": n, "ra": ra, "buoc": guard, "hp": hp,
				"elapsed": man.elapsed})
		man.free()
	print("   khong hinh: %d quan, ket qua %d, %d buoc, %.1fs, tong mau %.4f"
			% [ket[0]["n"], ket[0]["ra"], ket[0]["buoc"], ket[0]["elapsed"], ket[0]["hp"]])
	print("   co hinh   : %d quan, ket qua %d, %d buoc, %.1fs, tong mau %.4f"
			% [ket[1]["n"], ket[1]["ra"], ket[1]["buoc"], ket[1]["elapsed"], ket[1]["hp"]])
	_ghi_chu(ket[0]["n"] == ket[1]["n"] and ket[0]["n"] > 0,
			"so quan ra tran khong doi theo phan hinh")
	_ghi_chu(ket[0]["ra"] == ket[1]["ra"],
			"cung nguoi thang (khong hinh %d, co hinh %d)" % [ket[0]["ra"], ket[1]["ra"]])
	# So buoc va tong mau la hai thu KHAC nhau cua cung mot tran, nen doi ca hai
	# moi bat duoc lech nho: lech tam danh co the khong doi nguoi thang.
	_ghi_chu(ket[0]["buoc"] == ket[1]["buoc"],
			"cung so buoc (%d)" % ket[0]["buoc"])
	_ghi_chu(absf(float(ket[0]["hp"]) - float(ket[1]["hp"])) < 1e-9,
			"cung tong mau con lai")


# --- E. Xuong THAN khong bi bo loc an --------------------------------------

## Bo loc ve tich cua `SngRig` (`hide_clutter`, chi man tran bat) khop theo TIEN
## TO, ma `Logic_Body` khop `Logic_` — nen truoc 2026-09-20 nhan vat vao tran
## KHONG CO THAN: man tran la cho duy nhat con truyen `true` (`san_tran_ve.gd:1089`
## / `:1121`, `unit.gd:133` / `:137`), con duong Lua truyen `false` nen man Xem
## Tuong van du than. Do tren 397 rig: 94 xuong `Logic_Body*` o tang ngoai cung,
## 72 chua ANH THAT; va no la noi dung DUY NHAT cua xuong ay
## (`Player000M_res-Body` 33x41, `Player000W_res-Body` 23x32).
##
## Phep kiem khoa CA HAI CHIEU, va chay tren chinh `SngRig.build`:
##   - xuong `Logic_Body` PHAI con, va PHAI co anh (khong nam trong `missing_sprites`);
##   - bo loc PHAI con lam viec (dung `true` phai bo duoc it nhat mot xuong khac),
##     khong thi phep kiem dau la rong — no xanh ca khi ai do tat han bo loc.
func _kiem_xuong_than() -> void:
	print("\nE. Xuong THAN khong bi bo loc ve tich an:")
	var rig := SngRig.new()
	# Chieu 1 — chinh LUAT, khong can du lieu: ngoai le phai thang tien to.
	var luat := [
		["Logic_Body", false], ["Logic_Bodywpj", false], ["Logic_BodyBG", false],
		["Logic_Mark1", true], ["Logic_Chain", true], ["Logic_Ball_2", true],
		["Layer006", true], ["LayerName000", true],
	]
	for cap in luat:
		_ghi_chu(rig._is_clutter(cap[0]) == cap[1],
				"_is_clutter(\"%s\") = %s" % [cap[0], cap[1]])
	rig.free()

	# Chieu 2 — tren rig THAT, hai bien the cua nhan vat chinh: than phai CON.
	# KHONG kiem "bo loc con lam viec" o day: `Player000*` chi co DUNG MOT xuong
	# bi loc (`Logic_Body`), nen chua no ra la khong con gi de loc — do ra 29/29
	# va phep kiem do se do oan. Phai lay mot rig co CA HAI loai, xem chieu 3.
	for bien_the in ["Player000W03W", "Player000M03W"]:
		var r := SngRig.build("res://assets_ref/Player000", bien_the, true)
		if r == null:
			_ghi_chu(false, "khong dung duoc rig %s" % bien_the)
			continue
		_ghi_chu(r.bones.has("Logic_Body"), "%s: co xuong Logic_Body" % bien_the)
		_ghi_chu(not r.missing_sprites.has("Logic_Body"),
				"%s: Logic_Body CO ANH (khong vao missing_sprites)" % bien_the)
		var r2 := SngRig.build("res://assets_ref/Player000", bien_the, false)
		if r2 != null:
			_ghi_chu(r2.bones.has("Logic_Body"),
					"%s: duong KHONG loc cung co Logic_Body" % bien_the)
			r2.free()
		r.free()

	# Chieu 3 — phep kiem HAI CHIEU that su, tren mot rig co ca hai loai xuong:
	# `Player001M03W` co `Logic_Body` (anh that) LAN `LayerName000` (anh that).
	# Do 2026-09-20: **20** rig co ca hai. Cung mot rig, doi dung mot tham so:
	# than PHAI con, rac PHAI van bi bo. Neu ai do tat han bo loc thi ve sau do;
	# neu ai do bo luon ngoai le thi ve truoc do.
	var a := SngRig.build("res://assets_ref/Player001", "Player001M03W", true)
	var b := SngRig.build("res://assets_ref/Player001", "Player001M03W", false)
	if a == null or b == null:
		_ghi_chu(false, "khong dung duoc rig Player001M03W")
	else:
		_ghi_chu(a.bones.has("Logic_Body") and not a.missing_sprites.has("Logic_Body"),
				"Player001M03W: Logic_Body CON va CO ANH (co loc)")
		_ghi_chu(not a.bones.has("LayerName000"),
				"Player001M03W: LayerName000 VAN bi loc (co loc)")
		_ghi_chu(b.bones.has("Logic_Body") and b.bones.has("LayerName000"),
				"Player001M03W: duong KHONG loc co CA HAI")
		_ghi_chu(a.bones.size() < b.bones.size(),
				"Player001M03W: bo loc VAN lam viec (%d co loc / %d khong loc)"
				% [a.bones.size(), b.bones.size()])
		a.free()
		b.free()


# --- F. He so parallax cua cac lop nen -------------------------------------

func _lop_thu(cha: Control, ten: String, vitri: Vector2, co: Vector2, he) -> Control:
	var n := Control.new()
	n.name = ten
	cha.add_child(n)
	n.position = vitri
	n.size = co
	if he != null:
		n.set_meta("parallax", he)
	return n


func _kiem_he_so_lop() -> void:
	print("\nF. Lop nen cua san: he so parallax + mep san that (g_BattleFieldLayer):")

	# --- Nua thu nhat: so lieu bo cuc, doc doc lap voi ban dung. ---
	if not FileAccess.file_exists(BO_CUC_SAN):
		_ghi_chu(false, "khong co %s" % BO_CUC_SAN)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(BO_CUC_SAN))
	if typeof(d) != TYPE_DICTIONARY:
		_ghi_chu(false, "khong doc duoc %s" % BO_CUC_SAN)
		return
	var roots: Array = d.get("roots", [])
	var co := 0
	var thieu: Array = []
	var bang_mot := 0
	var mep := 0.0
	for n in roots:
		if typeof(n) != TYPE_DICTIONARY:
			continue
		if n.has("parallax"):
			co += 1
			# `layout.py:68` chi ghi khi khac (1,1) — mot node ghi DUNG (1,1) la
			# bang chung nguoc: no chung to "vang mat" khong con dong nghia voi 1.
			if n["parallax"] == [1.0, 1.0]:
				bang_mot += 1
		else:
			thieu.append(str(n.get("cls", "")))
			if float(n.get("w", 0.0)) > 0.0:
				mep = maxf(mep, float(n.get("x", 0.0)) + float(n.get("w", 0.0)))
	thieu.sort()
	print("   %d node goc: %d co he so, %d khong" % [roots.size(), co, thieu.size()])
	_ghi_chu(thieu == ["g_BattleField", "gb1_0", "gb1_1", "gb1_2", "gb1_3"],
			"dung 5 node thieu he so (ra %d): %s" % [thieu.size(), ", ".join(thieu)])
	_ghi_chu(bang_mot == 0,
			"khong node nao ghi he so (1,1) — nen 'vang mat = 1' moi dung (%d ngoai le)"
			% bang_mot)
	_ghi_chu(is_equal_approx(mep, 4096.0),
			"bon dai mat dat gb1_* trai 0..%.0f px = %.2f o (1 o = %.0f px)"
			% [mep, mep / SAN.O_PX, SAN.O_PX])

	# --- Nua thu hai: chay DUNG `_tim_lop` cua man tran. ---
	# Cay that co BA tang, va so tang nay la do chinh ham quyet dinh (`san_node :=
	# get_parent()` roi `cha := san_node.get_parent()`), nen lop parallax la ONG
	# cua node man tran chu khong phai CHA:
	#     g_BattleFieldLayer      <- lop parallax cha, cho `g_BattleField` nam
	#       gb1_0, troi, ...      <- cac LOP, day la thu `_tim_lop` gom
	#       g_BattleField         <- node giua (rong 0x0), man tran nam trong no
	#         <node man tran>
	# Do sai so tang thi `_lop` RONG trong im lang: khong camera bam, khong nen
	# troi, va khong mot dong loi. Cay thu nay giu dung hinh dang ay, va them hai
	# lop di truong ma du lieu khong co: mang RONG va mot SO (khong phai mang) —
	# hai kieu du lieu ma phep doc meta phai chiu duoc, khong thi bo cuc doi mot
	# node la vao tran la loi.
	var cha := Control.new()
	add_child(cha)
	cha.size = Vector2(4096.0, 640.0)
	var dat := _lop_thu(cha, "gb1_0", Vector2(0.0, 0.0), Vector2(4096.0, 40.0), null)
	var troi := _lop_thu(cha, "gbSky", Vector2(-100.0, 0.0), Vector2(2000.0, 640.0),
			[0.001, 1.0])
	var mang_rong := _lop_thu(cha, "gbMangRong", Vector2.ZERO, Vector2.ZERO, [])
	var kieu_so := _lop_thu(cha, "gbKieuSo", Vector2.ZERO, Vector2.ZERO, 3.0)
	var giua := _lop_thu(cha, "g_BattleField", Vector2.ZERO, Vector2.ZERO, null)
	var san := SAN.new()
	giua.add_child(san)
	# Be ngang khung nhin do o lan chay that (`khung()` cua ai thuong: `man 1152`).
	# `_dat_khung` dien no; o phep thu nay khong dung duoc Control ngoai cung nen
	# dat thang, va do cung la cho phan biet "san" voi "man" ro nhat.
	san._man = 1152.0
	san._tim_lop()

	var he := {}
	for m in san._lop:
		he[m[0]] = m[2]
	_ghi_chu(he.size() == 5, "_tim_lop gom dung 5 lop Control (%d)" % he.size())
	_ghi_chu(he.get(giua) == 1.0, "node giua g_BattleField cung vao danh sach (1.0)")
	_ghi_chu(he.get(dat) == 1.0,
			"lop KHONG khai he so -> 1.0 (ra %s) — cho tung sinh dong loi" % he.get(dat))
	_ghi_chu(is_equal_approx(he.get(troi, -1.0), 0.001),
			"lop khai [0.001,1.0] -> 0.001 (ra %s)" % he.get(troi))
	_ghi_chu(he.get(mang_rong) == 1.0,
			"lop khai MANG RONG -> 1.0 (ra %s)" % he.get(mang_rong))
	_ghi_chu(he.get(kieu_so) == 1.0,
			"lop khai SO (khong phai mang) -> 1.0 (ra %s)" % he.get(kieu_so))
	# SAN THAT lay tu cac dai mat dat he so 1 — khong phai tu khung nhin. Ba so
	# nay la ba thu khac han nhau va tung bi lan vao nhau: san 0..4096, khung nhin
	# 1152, camera troi duoc 2944.
	print("   san %.1f..%.1f, khung nhin %.1f -> _cam_max %.1f"
			% [san._trai, san._phai, san._man, san._cam_max])
	_ghi_chu(is_equal_approx(san._trai, 0.0) and is_equal_approx(san._phai, 4096.0),
			"mep san lay tu dai mat dat: %.1f..%.1f (khong phai 0..1152 cua khung nhin)"
			% [san._trai, san._phai])
	_ghi_chu(is_equal_approx(san._cam_max, 4096.0 - san._man),
			"_cam_max = het san tru mot KHUNG NHIN (ra %.1f)" % san._cam_max)
	# Quan tiep vien cua dich phai vao tu MEP PHAI CUA SAN. Day la hau qua nhin
	# thay duoc cua loi cu: `_phai` = 1152 thi dich vao tran o giua san.
	_ghi_chu(is_equal_approx(san._mep_vao(1), 4096.0 - SAN.BIEN)
			and is_equal_approx(san._mep_vao(0), san._trai + SAN.BIEN),
			"quan tiep vien vao tran o mep san: ta %.0f, dich %.0f"
			% [san._mep_vao(0), san._mep_vao(1)])
	cha.free()


func _ready() -> void:
	var ten := _ten_trong_bang()
	_kiem_tam_den()
	_kiem_luat_art(ten)
	# F khong phu thuoc bang quan chung, nen chay TRUOC cho thoat som: thieu bang
	# cung khong duoc phep im lang bo qua phan kiem nay.
	_kiem_he_so_lop()
	if ten.is_empty():
		print("\ndat %d, hong %d" % [_dat, _hong])
		get_tree().quit(1)
		return
	_kiem_add_unit(ten)
	_kiem_ban_tran()
	_kiem_xuong_than()
	print("\ndat %d, hong %d" % [_dat, _hong])
	get_tree().quit(1 if _hong > 0 else 0)
