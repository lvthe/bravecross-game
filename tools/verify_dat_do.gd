# `setGear` / `setLevelGear` — bang DO (trang bi) phai dung y bang goc, va bon
# duong gan do phai cham duoc vao du lieu that.
#
#   godot --headless --path . --script tools/verify_dat_do.gd
#
# VI SAO BO KIEM NAY TON TAI. Ban goc gan do bang hai ham TOAN CUC — `setGear`
# (10 cho goi THAT trong `sc/`) va `setLevelGear` (3 cho goi THAT, ca ba deu gac
# bang `if setLevelGear then`). `__index` cua lop gia lap tra ham cho MOI ten, nen
# thieu hai ham ay thi **khong mot dong loi**: do chi don gian la khong bao gio
# doi. Do la lop loi im lang dung nghia nhat trong ca repo, va no khong lo ra
# bang "chay khong co loi" — phai DEM va phai doi chieu voi BANG.
#
# Bon tang:
#   A. Bang: 201 muc `<Gear>` + 14 muc `<Parts>`, nam loai muc, dung MOT muc ra
#      trong, va cong thuc du phong phai trung bang `<Parts>` (7/7).
#   B. Nhanh ARM: doi o hien cua xuong bang mot RIG khac, co CHAN TREN theo cap.
#   C. Nhanh NODE CON (canh) va nhanh TEXTURE / `_Hide` cua luat du phong.
#   D. Nhanh BUNDLE (duong `setLevelGear`) va nang PARTS: moi muc `<Parts>` di
#      theo dung `nPartsType` cua no, va ghi dung MOT lan vao `chua_lam`.
#   E. NGUA MAC DINH (`<sDefaultMount>` cua `map/*.xml`): luat chi co DUNG mot
#      muc o ban VN, nen no de bi bo quen nhat — va bo quen thi khong bao gi.
#
# Du lieu (`data_ref/gear_ref.json`) sinh tu file bang cua ban goc — xem
# `.gitignore` — nen thieu thi bao BO QUA chu khong bao hong.
extends SceneTree

const DUONG := "res://data_ref/gear_ref.json"
const DUONG_NGUA := "res://data_ref/mount_ref.json"

const ANH_PLAYER := "res://assets_ref/Player000"
const TEN_NVC := "Player000M03W"
const ANH_DEF := "res://assets_ref/DefenderN"
const ANH_SPEAR := "res://assets_ref/SpearmenN"
const ANH_LVBU := "res://assets_ref/LvBuGod"

var ok := 0
var bad := 0


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


## O hien thu `idx` cua xuong, doc ra dang chu de in duoc ly do khi hong.
func _ta(rig: SngRig, bone: String, idx: int) -> String:
	var ds = rig.displays.get(bone)
	if ds == null or idx >= (ds as Array).size():
		return "RONG"
	var n = ds[idx]
	if n == null:
		return "RONG"
	if n is SngRig:
		return "RIG(%s)" % (n as SngRig).variant
	if n is Sprite2D:
		return "ANH(%s)" % (n as Sprite2D).texture.resource_path.get_file()
	return str(n)


## Ten bien the cua rig dang o o `idx` cua xuong, "" khi khong phai rig / rong.
func _bien_the(rig: SngRig, bone: String, idx: int) -> String:
	var ds = rig.displays.get(bone)
	if ds == null or idx >= (ds as Array).size():
		return ""
	var n = ds[idx]
	return (n as SngRig).variant if n is SngRig else ""


## Ten anh dang o o `idx` cua xuong, "" khi khong co.
func _anh(rig: SngRig, bone: String, idx: int) -> String:
	var ds = rig.displays.get(bone)
	if ds == null or idx >= (ds as Array).size():
		return ""
	var n = ds[idx]
	if n is Sprite2D:
		return (n as Sprite2D).texture.resource_path.get_file()
	return ""


func _init() -> void:
	var txt := FileAccess.get_file_as_string(DUONG)
	if txt.is_empty():
		print("BO QUA: khong co %s" % DUONG)
		print("  sinh bang: python ../brave-cross/work/gear_ref.py --json ../../bravecross-game/%s"
				% DUONG)
		_ket()
		return
	var d = JSON.parse_string(txt)
	t("gear_ref.json doc duoc", d is Dictionary)
	if not (d is Dictionary):
		_ket()
		return
	t("GearRef doc duoc bang", GearRef.co_bang())

	_tang_a(d)
	_tang_b()
	_tang_c()
	_tang_d()
	_tang_e()
	_ket()


## A. HINH DANG CUA BANG — khong dung rig nao.
func _tang_a(d: Dictionary) -> void:
	print("--- A. bang ---")
	var do_bang: Dictionary = d.get("do", {})
	var parts: Dictionary = d.get("parts", {})
	t("201 muc <Gear>", do_bang.size() == 201, str(do_bang.size()))
	t("14 muc <Parts>", parts.size() == 14, str(parts.size()))

	# Nam loai muc, do theo TRUONG chu khong theo ten. Con so nay la thu phai
	# khong doi: doi no nghia la bang goc da doi, va moi phep do ben duoi phai
	# lam lai.
	var loai := {"la": 0, "bundle": 0, "parts": 0, "baseItem": 0, "List": 0, "rong": 0}
	for k in do_bang:
		var m: Dictionary = do_bang[k]
		if m.get("nShowType") != null:
			loai["la"] += 1
		elif m.has("lsGear"):
			loai["bundle"] += 1
		elif m.has("lsParts"):
			loai["parts"] += 1
		elif m.has("sBaseItem"):
			loai["baseItem"] += 1
		elif String(m.get("sGear_lv5plus", "")) != "" or String(m.get("sGear_lv6plus", "")) != "":
			loai["List"] += 1
		else:
			loai["rong"] += 1
	t("loai muc: la 115 · bundle 70 · parts 7 · baseItem 3 · List 6 · rong 0",
			loai["la"] == 115 and loai["bundle"] == 70 and loai["parts"] == 7
			and loai["baseItem"] == 3 and loai["List"] == 6 and loai["rong"] == 0,
			str(loai))

	# `nShowType` chi nhan 2 va 4 (88 va 27). Kieu 1, 3, 5 khong muc nao — nen
	# chung chi con la nhanh cua duong DU PHONG, khong phai muc trong bang.
	var nst := {}
	for k in do_bang:
		var n = (do_bang[k] as Dictionary).get("nShowType")
		if n != null:
			nst[int(n)] = int(nst.get(int(n), 0)) + 1
	t("nShowType chi co 2 (88) va 4 (27)",
			nst.size() == 2 and int(nst.get(2, 0)) == 88 and int(nst.get(4, 0)) == 27,
			str(nst))

	# O TRONG: dung MOT muc, va phai la `equip_3_999`. Nhieu hon thi luat "moi
	# anh 1x1" da bat nham phan tu that, va cap 0 se ra hinh trong oan.
	var trong: Array = []
	for k in do_bang:
		if GearRef.trong(String(k)):
			trong.append(String(k))
	t("dung MOT muc ra trong, va la equip_3_999",
			trong.size() == 1 and trong[0] == "equip_3_999", str(trong))

	# Cong thuc du phong phai TRUNG bang `<Parts>` — hai cho doc lap trong cung
	# mot file, cung mot dap so. Day la phep thu co luc nhat cua tang A.
	var khop := 0
	var tong := 0
	for k in parts:
		var q: Dictionary = parts[k]
		if int(q.get("nPartsType", 0)) != GearRef.KIEU_TEXTURE:
			continue
		tong += 1
		var goc := String(k)
		if goc.ends_with("_Texture"):
			goc = goc.substr(0, goc.length() - 8)
		var r := GearRef.du_phong(goc)
		if String(r.get("xuong", "")) == String(q.get("sBone", "")) \
				and String(r.get("texture", "")) == String(q.get("sTextureName", "")):
			khop += 1
		else:
			print("     LECH: <Parts> %s -> %s  vs  %s / %s"
					% [k, r, q.get("sBone"), q.get("sTextureName")])
	t("cong thuc du phong trung bang <Parts> 7/7", tong == 7 and khop == 7,
			"%d/%d" % [khop, tong])

	# Hai nhanh cua luat du phong, doc thang tren ham (khong can rig).
	var r1 := GearRef.du_phong("DefenderN_Sword_lv1")
	t("du phong <arm>_<xuong>_lv<N> -> texture <arm>_res-<xuong>_lv<N>",
			String(r1.get("kieu", "")) == "texture" and String(r1.get("xuong", "")) == "Sword"
			and String(r1.get("texture", "")) == "DefenderN_res-Sword_lv1", str(r1))
	var r2 := GearRef.du_phong("DefenderN_Hat_Hide")
	t("du phong <arm>_<xuong>_Hide -> lenh AN xuong <xuong>",
			String(r2.get("kieu", "")) == "an" and String(r2.get("xuong", "")) == "Hat", str(r2))
	t("du phong ten mot doan -> rong (khong tach duoc)",
			GearRef.du_phong("DefenderN").is_empty())


## B. NHANH ARM (nShowType 2) — doi o hien cua xuong bang mot RIG khac.
func _tang_b() -> void:
	print("--- B. nhanh arm (nhan vat chinh) ---")
	var rig: SngRig = SngRig.build(ANH_PLAYER, TEN_NVC, false)
	t("dung duoc rig nhan vat chinh %s" % TEN_NVC, rig != null)
	if rig == null:
		return
	t("bien the dung bang ten da xin", rig.variant == TEN_NVC, rig.variant)
	t("co xuong Weapon", rig.co_xuong("Weapon"))
	if not rig.co_xuong("Weapon"):
		return

	# NEN do duoc: xuong `Weapon` mang san `Player000_Eff-EquipQin_5` — cap 5 la
	# MAC DINH cua armature, khong phai ai dat. Day la ly do `setGear` thieu di
	# thi khong co gi doi: man hinh van ra dan cap 5 trong khi du lieu noi cap 0.
	t("nen: Weapon[0] la anh Player000_Eff-EquipQin_5 (mac dinh cap 5)",
			_anh(rig, "Weapon", 0) == "Player000_Eff-EquipQin_5.png",
			_ta(rig, "Weapon", 0))

	t("dat_do(equip_3_0) = true", rig.dat_do("equip_3_0"))
	t("equip_3_0 -> Weapon[0] la rig EquipQin_1 (cap 0 la do THAT)",
			_bien_the(rig, "Weapon", 0) == "EquipQin_1", _ta(rig, "Weapon", 0))

	t("dat_do(equip_3_5) = true", rig.dat_do("equip_3_5"))
	t("equip_3_5 -> EquipQin_5", _bien_the(rig, "Weapon", 0) == "EquipQin_5",
			_ta(rig, "Weapon", 0))

	# CHAN TREN: art chi co cap 1..6, nen 7..10 deu tro ve `EquipQin_6`.
	t("dat_do(equip_3_9) = true", rig.dat_do("equip_3_9"))
	t("equip_3_9 -> EquipQin_6 (chan tren theo bang, khong suy tu hau to)",
			_bien_the(rig, "Weapon", 0) == "EquipQin_6", _ta(rig, "Weapon", 0))

	# `equip_3_999` la O TRONG: moi anh cua `EquipQin_0` la 1x1. Nham cho nay
	# thanh "cap 0" thi cap 0 ra hinh trong.
	t("dat_do(equip_3_999) = true", rig.dat_do("equip_3_999"))
	t("equip_3_999 -> o hien RONG", _ta(rig, "Weapon", 0) == "RONG",
			_ta(rig, "Weapon", 0))

	# Ten khong co trong bang, cung khong ra du phong: phai dem la TRUOT, khong
	# im lang. Anh `KhongCoGi_res-X_lv1` khong co trong atlas nao.
	t("ten la -> dat_do tra false", not rig.dat_do("KhongCoGi_X_lv1"))
	t("ten rong -> dat_do tra false", not rig.dat_do(""))


## C. NODE CON (canh) va hai nhanh du phong tren rig that.
func _tang_c() -> void:
	print("--- C. node con + du phong tren rig ---")
	var rig: SngRig = SngRig.build(ANH_PLAYER, TEN_NVC, false)
	if rig == null:
		t("dung duoc rig cho tang C", false)
		return
	var truoc := rig.get_child_count()
	t("dat_do(wing_1_5) = true", rig.dat_do("wing_1_5"))
	t("canh: rig co them dung MOT con", rig.get_child_count() == truoc + 1,
			"%d -> %d" % [truoc, rig.get_child_count()])
	var co_canh := ""
	for c in rig.get_children():
		if c is SngRig and (c as SngRig).variant == "EquipWing_05":
			co_canh = (c as SngRig).variant
	t("con moi la rig EquipWing_05", co_canh == "EquipWing_05", co_canh)

	# `_Hide` la LENH AN, khong phai ten texture hong — 21/201 ten la di duong
	# nay, va moi xuong chung an deu CO THAT trong armature.
	var d: SngRig = SngRig.build(ANH_DEF, "DefenderN", false)
	if d == null:
		t("dung duoc rig DefenderN", false)
		return
	t("dat_do(DefenderN_Hat_Hide) = true", d.dat_do("DefenderN_Hat_Hide"))
	t("_Hide -> Hat[0] RONG", _ta(d, "Hat", 0) == "RONG", _ta(d, "Hat", 0))


## D. BUNDLE (duong `setLevelGear`) va nang PARTS.
func _tang_d() -> void:
	print("--- D. bundle (setLevelGear) + <Parts> ---")
	var d: SngRig = SngRig.build(ANH_DEF, "DefenderN", false)
	if d == null:
		t("dung duoc rig DefenderN cho tang D", false)
		return
	var truoc := {}
	for b in d.bones:
		truoc[b] = _ta(d, String(b), 0)

	t("dat_do(DefenderN_lv3) = true", d.dat_do("DefenderN_lv3"))
	var doi: Array = []
	for b in d.bones:
		if _ta(d, String(b), 0) != truoc[b]:
			doi.append(String(b))
	doi.sort()
	t("bundle doi dung 3 xuong (Sword, Belt, Hat)", doi == ["Belt", "Hat", "Sword"], str(doi))
	t("Sword -> DefenderN_res-Sword_lv3", _anh(d, "Sword", 0) == "DefenderN_res-Sword_lv3.png",
			_anh(d, "Sword", 0))
	t("Belt  -> DefenderN_res-Belt_lv2 (ten do ghi cap 2)",
			_anh(d, "Belt", 0) == "DefenderN_res-Belt_lv2.png", _anh(d, "Belt", 0))
	t("Hat   -> DefenderN_res-Hat_lv3", _anh(d, "Hat", 0) == "DefenderN_res-Hat_lv3.png",
			_anh(d, "Hat", 0))

	# `DefenderN_Shield_lv3` KHONG gan duoc, va do la loi DU LIEU GOC chu khong
	# phai loi cua bo doc: luat du phong nham xuong `Shield`, ma `DefenderN.json`
	# khong co xuong ay — khien nam o `Logic_Shield` (va anh nen cua chinh xuong
	# ay LA `DefenderN_res-Shield_lv1`). Anh `DefenderN_res-Shield_lv3` thi CO
	# that trong `spriteFiles`, nen phep kiem chi-hoi-ten-anh se xanh nham.
	# Nay `gear_ref.py` dem no theo TEN; o day doi bo dem ay khop.
	t("chua_lam ghi dung DefenderN_Shield_lv3",
			d.chua_lam.size() == 1 and String(d.chua_lam[0]) == "DefenderN_Shield_lv3",
			str(d.chua_lam))
	t("bo dem khop: chua_lam.size() == so_lan_truot",
			d.chua_lam.size() == d.so_lan_truot,
			"%d vs %d" % [d.chua_lam.size(), d.so_lan_truot])

	# Nang PARTS: `SpearmenN_Spear_lv1` -> hai muc `<Parts>`. Muc `nPartsType 1`
	# cho ra DUNG anh dang co (do la dieu bang goc khai), con muc `nPartsType 5`
	# (`_Throw`) la viec CHUA LAM va phai ghi ra dung MOT lan.
	var s: SngRig = SngRig.build(ANH_SPEAR, "SpearmenN", false)
	t("dung duoc rig SpearmenN", s != null)
	if s == null:
		return
	t("co xuong Spear", s.co_xuong("Spear"))
	var anh_truoc := _anh(s, "Spear", 0)
	t("dat_do(SpearmenN_Spear_lv1) = true", s.dat_do("SpearmenN_Spear_lv1"))
	t("Spear[0] van la SpearmenN_res-Spear_lv1 (muc <Parts> khai dung anh ay)",
			_anh(s, "Spear", 0) == "SpearmenN_res-Spear_lv1.png" and anh_truoc == _anh(s, "Spear", 0),
			"%s -> %s" % [anh_truoc, _anh(s, "Spear", 0)])
	t("_Throw ghi dung MOT lan, kem ly do 'kieu 5 (nem) chua lam'",
			s.chua_lam.size() == 1
			and String(s.chua_lam[0]) == "SpearmenN_Spear_lv1_Throw (kieu 5 (nem) chua lam)",
			str(s.chua_lam))

	# Muc LIST chon do theo CAP, ma `setGear` KHONG truyen cap — nen no phai la
	# mot nhanh DEM DUOC co ten, khong phai mot lan roi vao "kieu 0 (?) chua lam"
	# (kieu 0 nghia la "khong co muc nao trong bang", ma muc thi CO).
	var l: SngRig = SngRig.build(ANH_PLAYER, TEN_NVC, false)
	if l == null:
		return
	t("dat_do(equip_Exclusive_10_List) = false", not l.dat_do("equip_Exclusive_10_List"))
	t("muc LIST ghi ly do 'thieu cap', khong phai 'kieu 0 (?)'",
			l.chua_lam.size() == 1
			and String(l.chua_lam[0]).contains("muc LIST: thieu cap de chon"),
			str(l.chua_lam))
	t("GearRef.la_list dung cho muc LIST", GearRef.la_list("equip_Exclusive_10_List"))
	t("GearRef.la_list sai cho muc thuong", not GearRef.la_list("equip_3_0"))


## E. NGUA MAC DINH — `<sDefaultMount>` cua `map/*.xml`.
##
## VI SAO CO TANG NAY. Luat nay chi co DUNG MOT muc o ban VN 1.26
## (`LvBuGod` -> `PonyChiTuGod`, `heroex_config.xml`), Lua 0 dong doc no, va
## khong mot ai phan nan ve no ca — nen no la loai loi im lang nhat: thieu thi
## khong co gi do, chi la Lu Bo khong bao gio cuoi ngua. Tang nay khoa hai dang:
## phep tra bang (ke ca chieu tien to) va duong dat that su len rig.
func _tang_e() -> void:
	print("--- E. ngua mac dinh (<sDefaultMount>) ---")
	if not FileAccess.file_exists(DUONG_NGUA):
		print("  BO QUA: khong co %s" % DUONG_NGUA)
		print("  sinh bang: python ../brave-cross/work/mount_ref.py")
		return

	# Bang: 10 mon ngua cua bang do (8 `mount_169..176` + `PonyChiTuGod`,
	# `PonyBlue`), va muc mac dinh DUY NHAT cua ban VN.
	t("GearRef.la_mount(PonyChiTuGod)", GearRef.la_mount("PonyChiTuGod"))
	t("GearRef.la_mount(mount_169) — ten khong bat dau bang Pony",
			GearRef.la_mount("mount_169"))
	t("GearRef.la_mount(equip_3_0) = false", not GearRef.la_mount("equip_3_0"))
	var so_ngua := 0
	for ten in ["mount_169", "mount_170", "mount_171", "mount_172", "mount_173",
			"mount_174", "mount_175", "mount_176", "PonyChiTuGod", "PonyBlue"]:
		if GearRef.la_mount(ten):
			so_ngua += 1
	t("dung 10 mon Mount trong bang do", so_ngua == 10, str(so_ngua))

	t("MountRef.mac_dinh(LvBuGod) = PonyChiTuGod",
			MountRef.mac_dinh("LvBuGod") == "PonyChiTuGod", MountRef.mac_dinh("LvBuGod"))
	t("ten khong co muc mac dinh -> '' (ZhaoYun)",
			MountRef.mac_dinh("ZhaoYun") == "", MountRef.mac_dinh("ZhaoYun"))
	# Chieu TIEN TO: don vi vao tran co the mang ten bien the (`LvBuGod_...`)
	# chu khong phai ten muc cau hinh.
	t("ten bien the LvBuGod_Crown cung tra ve PonyChiTuGod",
			MountRef.mac_dinh("LvBuGod_Crown") == "PonyChiTuGod",
			MountRef.mac_dinh("LvBuGod_Crown"))
	t("tien to khong duoc noi qua dau '_': LvBuGodFight -> ''",
			MountRef.mac_dinh("LvBuGodFight") == "", MountRef.mac_dinh("LvBuGodFight"))

	# Quyet dinh "co gan them khong" — ham THUAN, kiem duoc khong can tran.
	t("chua co do gi -> gan ngua mac dinh",
			MountRef.ngua_can_gan([], "LvBuGod") == "PonyChiTuGod")
	t("co do nhung khong co ngua -> van gan",
			MountRef.ngua_can_gan(["equip_3_0"], "LvBuGod") == "PonyChiTuGod")
	t("kich ban DA cho ngua (PonyBlue) -> khong gan de len",
			MountRef.ngua_can_gan(["PonyBlue"], "LvBuGod") == "")
	t("kich ban cho ngua ten tran (mount_169) -> cung khong gan de len",
			MountRef.ngua_can_gan(["mount_169"], "LvBuGod") == "")
	t("tuong khong co ngua mac dinh -> khong gan gi",
			MountRef.ngua_can_gan([], "ZhaoYun") == "")

	# Duong DAT that su: muc `node_con` -> `SngRig.dat_do` cua chinh rig.
	var rig: SngRig = SngRig.build(ANH_LVBU, "LvBuGod", false)
	t("dung duoc rig LvBuGod", rig != null)
	if rig == null:
		return
	t("muc PonyChiTuGod la kieu node_con, tro toi chinh no",
			GearRef.kieu("PonyChiTuGod") == GearRef.KIEU_NODE_CON
			and GearRef.node_con("PonyChiTuGod") == "PonyChiTuGod",
			"%d / %s" % [GearRef.kieu("PonyChiTuGod"), GearRef.node_con("PonyChiTuGod")])
	var truoc := rig.get_child_count()
	t("dat_do(PonyChiTuGod) = true", rig.dat_do("PonyChiTuGod"))
	t("ngua: rig co them dung MOT con", rig.get_child_count() == truoc + 1,
			"%d -> %d" % [truoc, rig.get_child_count()])
	var co_ngua := ""
	for c in rig.get_children():
		if c is SngRig and (c as SngRig).variant == "PonyChiTuGod":
			co_ngua = (c as SngRig).variant
	t("con moi la rig PonyChiTuGod", co_ngua == "PonyChiTuGod", co_ngua)


func _ket() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
