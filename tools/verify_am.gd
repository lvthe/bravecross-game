# Am thanh: moi file .ogg boc tu .bank phai NAP DUOC bang trinh giai ma cua
# Godot, va do dai doc ra phai dung bang so mau / tan so cua ban goc.
#
#   godot --headless --path . --script tools/verify_am.gd
#
# Day la phep kiem chot cua ca duong boc am thanh. Bank la FSB5 cua FMOD nhung
# khong phai FSB tran: khoi setup Vorbis KHONG nam trong bank (FSB5 chi tham
# chieu no bang `setup_id`), nen phai lay khoi setup tu chinh libfmod.so cua
# game. Lam sai cho nao thi libvorbis tu choi ngay bang `OV_EBADHEADER`, hoac
# (te hon) nhan nhung cat sai do dai o trang cuoi. Vi vay phep kiem khong hoi
# "nap duoc khong" khong thoi, ma hoi do dai co BANG so_mau/rate khong: do dai
# dung chi ra rang khoi setup, so kenh, co khoi, va granule trang cuoi deu dung.
#
# Bang kiem ke do chinh `brave-cross/work/bank.py` ghi ra kem thu muc am thanh,
# nen so mong doi o day KHONG phai chep tay: no la so FSB5 cua ban goc.
#
# Phan cuoi (`_duong_lua`) di dung duong ma MAN HINH di: nap khung suon roi goi
# `G_SoundManager:PlaySoundEffect` / `PlayBackgroundMusic` nhu ban goc goi o 76
# cho. Cac ten toan cuc do truoc day la BONG — khong file Lua nao trong 973 file
# dinh nghia chung — nen moi tieng bam nut, mo cua so, nhan thuong deu cam.
#
# Du lieu nay khong commit duoc (am thanh cua ban goc, xem .gitignore) nen khi
# thieu thi bao BO QUA chu khong bao hong.
extends SceneTree

const AUDIO := "res://assets_ref/audio"
const KEM := AUDIO + "/bank_ref.json"
const EV := "res://data_ref/event_ref.json"
const LECH_TOI_DA := 0.05   # giay
## Nap khung suon Lua: dung lai duong cua tools/vao_main.gd chu khong chep lai
## mot ban khac (chep lai thi hai ben lech nhau luc nao khong biet).
const VM := preload("res://tools/vao_main.gd")

var ok := 0
var bad := 0


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		if bad <= 20:
			print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


func _init() -> void:
	var txt := FileAccess.get_file_as_string(KEM)
	if txt.is_empty():
		print("BO QUA: khong co %s" % KEM)
		print("  sinh bang: python ../brave-cross/work/bank.py --all --out assets_ref/audio")
		_ket()
		return
	var bang: Array = JSON.parse_string(txt)
	t("bang kiem ke doc duoc", bang != null and not bang.is_empty())
	if bang == null or bang.is_empty():
		_ket()
		return
	print("  %d subsound trong kiem ke" % bang.size())

	# --- 1. Tung file: nap duoc va do dai dung ---------------------------------
	# Do dai mong doi lay tu `giay` = so_mau / rate, tuc thang tu header FSB5,
	# khong phai tu file .ogg ta vua ghi (lay tu file ta ghi thi phep kiem
	# khong noi len dieu gi).
	var n_nap := 0
	var n_dai := 0
	var n_khong_thay := 0
	var lech_lon_nhat := 0.0
	var ten_lech := ""
	var rong_nhat := 999999
	for m in bang:
		var f: String = AUDIO + "/" + String(m["file"])
		if not FileAccess.file_exists(f):
			n_khong_thay += 1
			t("co file %s" % m["file"], false)
			continue
		var st: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(f)
		if st == null:
			t("nap duoc %s" % m["file"], false)
			continue
		n_nap += 1
		var giay := st.get_length()
		var mong := float(m["giay"])
		var lech: float = absf(giay - mong)
		if lech > lech_lon_nhat:
			lech_lon_nhat = lech
			ten_lech = String(m["file"])
		if lech < LECH_TOI_DA:
			n_dai += 1
		else:
			t("dung do dai %s" % m["file"], false,
					"mong %.3f s, doc %.3f s" % [mong, giay])
		var fh := FileAccess.open(f, FileAccess.READ)
		var n := 0
		if fh != null:
			n = fh.get_length()
			fh.close()
		if n > 0 and n < rong_nhat:
			rong_nhat = n
	t("khong thieu file nao", n_khong_thay == 0, "%d thieu" % n_khong_thay)
	t("moi file deu nap duoc", n_nap == bang.size(),
			"%d/%d" % [n_nap, bang.size()])
	t("moi file dung do dai", n_dai == bang.size(),
			"%d/%d" % [n_dai, bang.size()])
	t("file nho nhat khong phai file rong", rong_nhat > 500, "%d byte" % rong_nhat)
	print("  lech do dai lon nhat: %.4f s (%s)" % [lech_lon_nhat, ten_lech])

	# --- 2. So file tren dia dung bang so dong kiem ke -------------------------
	var d := DirAccess.open(AUDIO)
	var n_ogg := 0
	if d != null:
		for f in d.get_files():
			if f.ends_with(".ogg"):
				n_ogg += 1
	t("so file .ogg tren dia bang so dong kiem ke", n_ogg == bang.size(),
			"%d vs %d" % [n_ogg, bang.size()])

	# --- 3. Bang tra event -> file --------------------------------------------
	# Phep kiem co gia tri nhat o day: bay am thanh ma CHINH SoundManager.lua
	# cua ban goc dung (SoundDefine) phai tra ra file that. Neu bang tra hong
	# cho nay thi moi tieng bam nut trong game deu cam.
	var etxt := FileAccess.get_file_as_string(EV)
	if etxt.is_empty():
		print("  (khong co %s — bo qua phan event)" % EV)
		_ket()
		return
	var ev: Dictionary = JSON.parse_string(etxt)
	var bang_tra: Dictionary = ev.get("event_ref", {})
	t("bang tra event doc duoc", not bang_tra.is_empty())
	for ten in ["event:/UI/UI_Window_General", "event:/UI/UI_Window_Close",
			"event:/UI/UI_Window_Open", "event:/UI/UI_Messager_General",
			"event:/UI/UI_Messager_False", "event:/UI/UI_Window_Reward",
			"event:/UI/UI_Objects"]:
		var v = bang_tra.get(ten)
		t("%s co trong bang tra" % ten, v != null)
		if v == null:
			continue
		var ds: Array = v["file"]
		t("%s co it nhat mot file" % ten, not ds.is_empty())
		if ds.is_empty():
			continue
		var st2: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(
				AUDIO + "/" + String(ds[0]))
		t("%s nap duoc" % ds[0], st2 != null)
	# Moi file ma bang tra tro toi deu phai nam trong kiem ke. Khong kiem bang
	# FileAccess.file_exists khong thoi: file mo coi trong thu muc ma khong co
	# trong kiem ke thi do dai khong ai doi chieu.
	var co: Dictionary = {}
	for m in bang:
		co[String(m["file"])] = true
	var n_ngoai := 0
	for k in bang_tra:
		for f in bang_tra[k]["file"]:
			if not co.has(String(f)):
				n_ngoai += 1
	t("moi file cua bang tra deu co trong kiem ke", n_ngoai == 0,
			"%d file la" % n_ngoai)
	var tk: Dictionary = ev.get("thong_ke", {})
	print("  event: %d giai duoc / %d, %d mau, %d khong giai duoc — xem event_ref.py"
			% [int(tk.get("so_giai_duoc", 0)), int(tk.get("so_event", 0)),
			   int(tk.get("so_mau", 0)), int(tk.get("so_khong_giai_duoc", 0))])

	# --- 4. Tieng dong cua ban goc: theo hoat dong va theo don danh ------------
	# Hai bang nay chi engine C++ doc (khong file Lua nao trong 973 file doc
	# chung), nen tra bang tay het: game/tieng_dong.gd.
	_tieng_dong(co, bang_tra)

	# --- 5. Duong Lua THAT: khung suon -> G_SoundManager -> kenh --------------
	# Ba phan tren moi kiem DU LIEU (file nap duoc, do dai dung, bang tra tra ra
	# file that). Phan nay kiem cho NOI. Ban goc khong bao gio goi thang file
	# .ogg: no goi `G_SoundManager:PlaySoundEffect(TEN)` (76 cho) roi xuong
	# `playSoundEffect` cua engine. Cac ten do truoc day la BONG — khong file
	# Lua nao trong 973 file dinh nghia chung — nen moi tieng bam nut, mo cua
	# so, nhan thuong deu cam. Day la phep kiem chot cua ca duong noi.
	await _duong_lua()

	_ket()


## Hai bang tieng cua ban goc — `sound_config.xml` (theo hoat dong) va
## `hit_config.xml` (theo don danh). Ca hai do `../brave-cross/work/trigger_ref.py`
## doc ra; o day khong chep lai con so nao, chi doi chieu voi so do.
##
## `co` la tap file co that trong kiem ke, `bang_tra` la `event_ref`.
func _tieng_dong(co: Dictionary, bang_tra: Dictionary) -> void:
	var txt := FileAccess.get_file_as_string("res://data_ref/trigger_ref.json")
	if txt.is_empty():
		print("  (khong co trigger_ref.json — bo qua phan tieng dong)")
		t("co bang tieng dong cua ban goc", false)
		return
	var d: Dictionary = JSON.parse_string(txt)
	t("bang tieng dong doc duoc", not d.is_empty())
	if d.is_empty():
		return
	var tk: Dictionary = d.get("thong_ke", {})
	var td := TiengDong.moi()

	# --- Hinh dang: doi chieu voi so do cua trigger_ref.py ---------------------
	t("sound_config: %d armature" % int(tk.get("so_armature_sound_config", 0)),
			td.tieng_hoat_dong.size() == int(tk.get("so_armature_sound_config", -1)))
	t("hit_config: %d armature danh" % int(tk.get("so_armature_hit_config", 0)),
			td.danh.size() == int(tk.get("so_armature_hit_config", -1)))
	var n_tieng := 0
	var n_lap := 0
	for a in td.tieng_hoat_dong.values():
		for ds in (a as Dictionary).values():
			for m in ds:
				n_tieng += 1
				if m["lap"]:
					n_lap += 1
	t("sound_config: %d tieng" % int(tk.get("so_tieng_hoat_dong", 0)),
			n_tieng == int(tk.get("so_tieng_hoat_dong", -1)), "%d" % n_tieng)
	t("sound_config: %d tieng loop" % int(tk.get("so_tieng_lap", 0)),
			n_lap == int(tk.get("so_tieng_lap", -1)), "%d" % n_lap)
	var n_cu := 0
	for a in td.danh.values():
		for ds in (a as Dictionary).values():
			n_cu += ds.size()
	t("hit_config: %d cu danh" % int(tk.get("so_cu_danh", 0)),
			n_cu == int(tk.get("so_cu_danh", -1)), "%d" % n_cu)
	t("hit_config: %d cu danh dung lai armature khac" % int(tk.get("so_dung_lai", 0)),
			td.dung_lai.size() == int(tk.get("so_dung_lai", -1)))
	t("hit_config: %d bang su kien" % int(tk.get("so_su_kien_trung_don", 0)),
			td.su_kien.size() == int(tk.get("so_su_kien_trung_don", -1)))
	# `reuseArmatures` nghia la "dung du lieu cua xuong nao": gia tri treo thi
	# duong tra cuu im lang mat, khong bao gi.
	var treo := 0
	for v in td.dung_lai.values():
		if not td.danh.has(String(v)):
			treo += 1
	t("moi gia tri reuseArmatures deu co du lieu danh", treo == 0, "%d treo" % treo)

	# --- Chieu doc: tra dung tieng cua tung armature ---------------------------
	# Ba vi du lay thang tu `sound_config.xml`, khong phai tu suy dien:
	# `Archer/Fight` co dung MOT tieng o khung 10.
	var n := td.nhip("Archer", "Fight")
	t("Archer/Fight co dung mot tieng o khung 10",
			n.size() == 1 and int(n[0]["khung"]) == 10
			and String(n[0]["su_kien"]) == "event:/Character/Archer/Act_Archer_Fight_Cast"
			and not bool(n[0]["lap"]), JSON.stringify(n))
	t("Archer/Wake co tieng", not td.nhip("Archer", "Wake").is_empty())
	t("armature khong co trong bang thi tra rong",
			td.nhip("khong_co_armature_nay", "Fight").is_empty())
	t("dong tac khong co tieng thi tra rong", td.nhip("Archer", "Boom").is_empty())
	# `loop="1"` co that (7 tieng tren toan bang, vd `WakeLoop` cua Gia Xu).
	var nl := td.nhip("JiaXu", "WakeLoop")
	t("tieng `loop=\"1\"` giu co lap",
			nl.size() == 1 and bool(nl[0]["lap"]), JSON.stringify(nl))

	# --- Chieu tra tieng trung don ---------------------------------------------
	# Loai vu khi cua Lu Bu khi `Fight` la 1 (sac), giap cua ArcherN la 3 (thit)
	# -> khoa `1_3_1`. Do thang tu `hit_config.xml`.
	t("LvBu danh ArcherN (sac/thit/nhe) ra Impact_Sharp_Flesh_Light",
			td.trung_don("LvBu", "Fight", 0, "ArcherN", 1)
			== "event:/Impact/Impact_Sharp_Flesh_Light")
	t("cung do manh nang ra dung ban _Heavy",
			td.trung_don("LvBu", "Fight", 0, "ArcherN", 2)
			== "event:/Impact/Impact_Sharp_Flesh_Heavy")
	# Ten linh trong du lieu tran la armature THAN, con vu khi la armature RIENG:
	# chi `reuseArmatures` moi noi toi (`ArcherN_Weapon_Normal` -> `DEF_Weapon_3`,
	# loai 3 = cung).
	t("ten vu khi tra qua reuseArmatures ra dung loai cung",
			td.trung_don("ArcherN_Weapon_Normal", "Fight", 0, "Defender", 1)
			== "event:/Impact/Impact_Archery_Flesh_Light")
	# Du lieu tran dat ten co duoi trong ngoac ("ZhaoYun(new)",
	# "Defender(董军入侵)") — VAN la cung armature.
	t("bo duoi trong ngoac roi van tra ra cung tieng",
			td.trung_don("ZhaoYun(new)", "Fight", 0, "Defender(董军入侵)", 1)
			== td.trung_don("ZhaoYun", "Fight", 0, "Defender", 1)
			and td.trung_don("ZhaoYun", "Fight", 0, "Defender", 1)
			== "event:/Impact/Impact_Sharp_Flesh_Light")
	# `kitMaterial = 0` = khong co vu khi (10 cu danh), va `events` khong co
	# khoa nao bat dau bang "0_" -> tra tiep la vo nghia.
	t("cu danh co vu khi loai 0 thi khong co tieng",
			td.trung_don("DEF_Weapon_0", "Fight", 0, "Defender", 1) == "")
	t("armature khong co du lieu danh thi khong co tieng",
			td.trung_don("Archer", "Fight", 0, "Defender", 1) == "")
	t("ben chiu khong co trong bang giap thi khong co tieng",
			td.trung_don("LvBu", "Fight", 0, "khong_co_giap_nay", 1) == "")

	# --- Vi sao im: bon ma, va phai dung ma -------------------------------------
	# `dem_tieng` cua `san_tran_ve.gd` chia so don im theo `ly_do`, nen ma sai thi
	# bang muc phu sai theo. Do tren `trigger_ref.json`: 10 cu danh tay khong,
	# `danh` khong co armature nao ten `Player*` (do la ly do 94/145 don im).
	td.trung_don("Archer", "Fight", 0, "Defender", 1)
	t("im vi armature khong co du lieu danh", td.ly_do == "khong-co-danh",
			td.ly_do)
	td.trung_don("DEF_Weapon_0", "Fight", 0, "Defender", 1)
	t("im vi cu danh tay khong", td.ly_do == "tay-khong", td.ly_do)
	td.trung_don("LvBu", "Fight", 0, "khong_co_giap_nay", 1)
	t("im vi ben chiu khong co giap", td.ly_do == "khong-co-giap", td.ly_do)
	# Khong phai moi cap (loai vu khi, loai giap) deu co khoa: do tren bang goc,
	# 56/80 khoa thieu. Vi du that: `DEF_Weapon_4` (nhac khi) danh `Hoplite`
	# (giap sat) -> `4_1_1` khong co.
	td.trung_don("DEF_Weapon_4", "Fight", 0, "Hoplite", 1)
	t("im vi cap vu khi/giap khong co khoa", td.ly_do == "khong-co-su-kien",
			td.ly_do)
	td.trung_don("LvBu", "Fight", 0, "ArcherN", 1)
	t("tra duoc thi ly_do rong", td.ly_do == "", td.ly_do)

	# --- Ten bien the: do cho chac, roi de im -----------------------------------
	# `giap` co nhieu ten bien the ma HAI BANG PHIA VU KHI khong biet. Phep kiem
	# nay khoa con so, de sau nay khong ai "sua" bang mot luat doi ten bia dat.
	var loc := RegEx.new()
	loc.compile("_(VampirE|Dong|Boss|Skeleton|DongBoss)$")
	var n_bt := 0
	var n_bt_thd := 0
	var n_bt_danh := 0
	var n_goc_thd := 0
	for k in td.giap:
		if loc.search(String(k)) == null:
			continue
		n_bt += 1
		if td.tieng_hoat_dong.has(String(k)):
			n_bt_thd += 1
		if td.danh.has(String(k)):
			n_bt_danh += 1
		if td.tieng_hoat_dong.has(loc.sub(String(k), "", true)):
			n_goc_thd += 1
	t("40 ten bien the trong bang giap", n_bt == 40, "%d" % n_bt)
	t("khong ten bien the nao co trong hai bang phia vu khi",
			n_bt_thd == 0 and n_bt_danh == 0,
			"sound_config %d, danh %d" % [n_bt_thd, n_bt_danh])
	t("ten goc cua chung thi co: 36/40 trong sound_config", n_goc_thd == 36,
			"%d/%d" % [n_goc_thd, n_bt])

	# --- Moi tieng cua hai bang phai NAP DUOC ---------------------------------
	# Phep kiem co gia tri nhat: bang tieng tra ra duoc mot chuoi `event:/...`
	# van chua du nghia — phai co file .ogg that. Do tren ban goc: 375 chuoi
	# tieng hoat dong thi 360 giai duoc, 38 chuoi trung don thi 36.
	var thd := {}
	for a in td.tieng_hoat_dong.values():
		for ds in (a as Dictionary).values():
			for m in ds:
				thd[String(m["su_kien"])] = true
	var n_hd := 0
	for e in thd:
		if bang_tra.has(e):
			n_hd += 1
	t("tieng hoat dong: 360/%d chuoi co trong bang tra event" % thd.size(),
			n_hd == 360 and thd.size() == 375, "%d/%d" % [n_hd, thd.size()])
	var n_td := 0
	var thieu_td := []
	for e in td.su_kien.values():
		if bang_tra.has(String(e)):
			n_td += 1
		else:
			thieu_td.append(String(e))
	t("tieng trung don: 36/38 chuoi co trong bang tra event",
			n_td == 36 and td.su_kien.size() == 38, "%d/%d" % [n_td, td.su_kien.size()])
	# Va day la CHO HO CUA DU LIEU GOC, phai noi ra chu khong im: dung hai
	# tieng thieu la `Impact_Archery_Flesh_Light/Heavy` — tuc moi don CUNG
	# (kitMaterial 3) vao giap THIT (armorMaterial 3) deu cam, ma giap thit moi
	# la loai pho bien nhat (`DefenderN`, `ArcherN`, `SpearmenN`, `ShieldMaster`
	# deu la 3). Chung khong co subsound trong bank nao; cung nhom voi 15 chuoi
	# tieng hoat dong thieu. Xem BANK.md.
	var dung_2 := true
	for e in thieu_td:
		if not e.begins_with("event:/Impact/Impact_Archery_Flesh_"):
			dung_2 = false
	t("dung hai tieng thieu la Impact_Archery_Flesh_Light/Heavy",
			thieu_td.size() == 2 and dung_2, ", ".join(thieu_td))
	# Moi file ma bang tra tro toi deu phai co trong kiem ke (khong kiem
	# `FileAccess.file_exists` khong thoi: file mo coi trong thu muc ma khong co
	# trong kiem ke thi do dai khong ai doi chieu).
	var n_la := 0
	for e in thd:
		if not bang_tra.has(e):
			continue
		for f in bang_tra[e]["file"]:
			if not co.has(String(f)):
				n_la += 1
	for e in td.su_kien.values():
		var k := String(e)
		if not bang_tra.has(k):
			continue
		for f in bang_tra[k]["file"]:
			if not co.has(String(f)):
				n_la += 1
	t("moi file cua bang tieng dong deu co trong kiem ke", n_la == 0,
			"%d file la" % n_la)
	print("  tieng dong: %d armature/%d tieng hoat dong, %d armature/%d cu danh"
			% [td.tieng_hoat_dong.size(), n_tieng, td.danh.size(), n_cu])


## Chay khung suon Lua roi bam thu nhu ban goc bam.
##
## Phai la ham CHO duoc: kenh am thanh la node con cua san khau, ma trong `_init`
## cua SceneTree thi CHUA node nao vao cay (`Engine.get_main_loop()` con null) —
## nen tieng nao xin trong `_init` deu duoc HEN den khung dau (xem `_chay` /
## `_thu_lai` trong game/am_thanh.gd). Khong cho khung thi `so_phat` dung o 0 va
## phep kiem nay khong noi len dieu gi.
func _duong_lua() -> void:
	var lua := LuaRuntime.new()
	lua.cua_so_engine = Vector2(1429, 768)
	if not lua.open():
		t("mo duoc khung suon Lua", false, ", ".join(lua.errors))
		return
	var san := Control.new()
	san.size = lua.cua_so_engine
	lua.set_stage(san)
	lua.set_touch_root(san)
	# Phai vao cay: AudioStreamPlayer ngoai cay KHONG phat ("Playback can only
	# happen when a node is inside the scene tree"), xem `dat_cha`.
	root.add_child(san)
	if lua.run(VM._NAP, "nap") == null:
		t("nap duoc khung suon Lua", false, ", ".join(lua.errors))
		return
	var am: AmThanh = lua.am
	# Duong am thanh KHOI DONG cua ban goc (sc/game.lua:340-345): bon bank nhac
	# nen + hai bank hieu ung `UI` / `UI_EVENT`, roi pushBankStack. Phan nay
	# truoc day bi bo qua han (bootstrap co y bo qua ca nhom am thanh).
	t("khoi dong nap bank nhu game.lua:340-345",
			am.bank_da_nap.has("BG") and am.bank_da_nap.has("UI"),
			", ".join(am.bank_da_nap.keys()))

	var m_phat := am.so_phat
	var m_cho := am.so_cho
	var m_khong_tra := am.so_khong_tra_duoc
	var m_thieu := am.so_thieu_file
	var m_kenh := am.so_het_kenh
	var m_cha := am.so_khong_co_cha

	var r = lua.run(_BAM_THU, "bam thu")
	if r == null:
		t("chay duoc duong am thanh cua ban goc", false, ", ".join(lua.errors))
		return
	print("  Lua xin: %s tieng duoc, %s tieng khong; SoundDefine %s ten, hong: '%s'"
			% [r["xin"], r["that_bai"], r["so_define"], r["define_hong"]])
	print("  nhac nen: goi xuong %s lan, ham tra ve %s; am luong dau %s"
			% [r["nhac_goi"], r["nhac_dat"], r["vol_dau"]])
	t("bay ten cua SoundDefine deu phat duoc", String(r["define_hong"]).is_empty(),
			String(r["define_hong"]))
	t("ten do client tu ghep luc chay phat duoc", int(r["voice"]) > 0)
	t("SimpleAudioEngine:playEffect tra ve id", int(r["sae"]) > 0)
	t("ten khong co that tra dung 0, 0 chu khong nem loi",
			int(r["that_bai_4"]) == 1 and int(r["that_bai"]) == 1,
			"that bai %s lan" % r["that_bai"])
	# `nhac_dat` la gia tri ma `playBackgroundMusic` cua ta tra ve — no KHONG
	# tra ve gi (xem lua/am_thanh.lua: khong cho goi nao dung gia tri do), nen
	# phep do that o day la SO LAN ham cua ta duoc goi xuong.
	t("G_SoundManager:PlayBackgroundMusic goi xuong dung mot lan",
			int(r["nhac_goi"]) == 1, "%s lan" % r["nhac_goi"])
	t("doi am luong nhac nen tra dung gia tri dang co", float(r["vol_dau"]) == 1.0,
			str(r["vol_dau"]))

	# CHO KHUNG: day moi la phep kiem cua phan nay.
	await process_frame
	await process_frame

	var xin := int(r["xin"])
	var mong := xin + int(r["nhac_goi"])
	# Phep do dung `so_cho` chu khong `so_phat`: `so_cho` dem DUNG so tieng xin
	# luc chua vao cay, nen no bang `xin + nhac_goi` chinh xac ke ca khi co
	# tieng khac chen vao giua hai moc. Tieng do lop tieng-dong cua ban goc phat
	# (`SngRig._process`, xem game/tieng_dong.gd) roi vao thoi diem nay khi rig
	# da o trong cay, nen `so_phat` se lon hon — do la ly do phai tach hai phep
	# do ra, khong phai de noi long phep kiem.
	t("tieng hen luc _init phat het o khung dau",
			am.so_cho - m_cho == mong and am.dang_hen() == 0,
			"hen %d, mong %d, con hen %d"
			% [am.so_cho - m_cho, mong, am.dang_hen()])
	t("khong tieng nao xin luc _init bi mat",
			am.so_phat - m_phat >= mong,
			"phat %d, mong it nhat %d" % [am.so_phat - m_phat, mong])
	t("khong tieng nao thieu file", am.so_thieu_file == m_thieu,
			"%d" % (am.so_thieu_file - m_thieu))
	t("khong tieng nao het kenh (12 kenh, xin %d)" % xin,
			am.so_het_kenh == m_kenh, "%d" % (am.so_het_kenh - m_kenh))
	t("kenh nao cung gan duoc vao san khau", am.so_khong_co_cha == m_cha,
			"%d" % (am.so_khong_co_cha - m_cha))

	# KENH BI GIAI PHONG TRUOC KHUNG DAU: phai BO, khong duoc xep lai hang.
	# Kenh la con cua `_cha` (khong phai cua `AmThanh`), ma `_cha` co the la node
	# cua mot man hinh vua dong. Ban cu xep lai nen vong `call_deferred` quay vo
	# tan, va `quet_show.gd` chet bang signal 11 voi vet GDScript tro dung vao
	# `_thu_lai`. Dung mot `AmThanh` rieng voi `_cha` NGOAI cay de dung lai dung
	# tinh huong: kenh tao ra duoc nhung chua vao cay, roi cha bi giai phong.
	# `AmThanh` la RefCounted chu khong phai Node (kenh moi la node, va chung nam
	# duoi `_cha`) — nen o day chi can mot `_cha` ngoai cay.
	var am2 := AmThanh.new()
	var cha_tam := Node.new()
	cha_tam.name = "ChaTam"
	am2.dat_cha(cha_tam)
	var bo_truoc := am2.so_bo_cho
	am2.phat("event:/UI/UI_Click")
	t("kenh ngoai cay thi vao hang doi", am2.dang_hen() == 1,
			"hen %d" % am2.dang_hen())
	cha_tam.free()
	await process_frame
	await process_frame
	t("cha bi giai phong thi bo kenh, khong xep lai hang",
			am2.dang_hen() == 0 and am2.so_bo_cho - bo_truoc == 1,
			"con hen %d, bo %d" % [am2.dang_hen(), am2.so_bo_cho - bo_truoc])
	# Hai ten co y sai trong _BAM_THU (mot goi thang, mot qua SoundManager).
	t("chi ten co y sai moi khong tra duoc", am.so_khong_tra_duoc - m_khong_tra == 2,
			"%d" % (am.so_khong_tra_duoc - m_khong_tra))
	t("nhac nen dang hat", am.nhac_dang_chay())
	t("dung bai nhac nen da xin", am.ten_nhac_dang() == "event:/BGM/BGM_Main",
			am.ten_nhac_dang())

	# Tat tieng: ban goc lam viec nay o CUIWing.lua:1474 va CGuideScheme.lua:12,
	# va `soundId` o CGuideScheme luc dau la nil nen `stopSoundEffect(nil)` PHAI
	# chiu duoc. Do luon bon man chat hat nho nhac nen roi tra lai
	# (CAsrManager.lua:178-194), va nap / bo nap bank (CUIWing.lua:1474).
	var dang_dung := am.so_kenh_dang_dung()
	var r2 = lua.run(_TAT_THU % int(r["id1"]), "tat thu")
	if r2 == null:
		t("tat duoc tieng", false, ", ".join(lua.errors))
		return
	t("tat tieng khong nem loi (id that, nil, 0, id khong co, ten bong)",
			bool(r2["khong_loi"]))
	t("tat mot tieng thi tra lai dung mot kenh",
			am.so_kenh_dang_dung() == dang_dung - 1,
			"%d -> %d" % [dang_dung, am.so_kenh_dang_dung()])
	t("hat nho nhac nen roi tra lai dung so cu",
			float(r2["vol_0"]) == 0.0 and float(r2["vol_tra_lai"]) == 1.0,
			"%s -> %s" % [r2["vol_0"], r2["vol_tra_lai"]])
	t("loadEffectBank ghi lai duoc ten bank", am.bank_da_nap.has("EXTRA"))
	# Bo nap: 18 cho goi `unloadBankByName` trong ma goc. Phai kiem SAU khi da
	# thay `loadEffectBank` ghi duoc, khong thi phep kiem nay xanh ca khi ca hai
	# ham deu khong lam gi.
	if lua.run(_BO_BANK, "bo bank") == null:
		t("bo nap bank khong nem loi", false, ", ".join(lua.errors))
		return
	t("unloadBankByName bo duoc ten bank", not am.bank_da_nap.has("EXTRA"))
	t("khong hong them gi trong luc tat", am.so_het_kenh == m_kenh)

	# --- 6. Tieng theo khung hoat dong, chay THAT tren mot rig ---------------
	# Phan 4 moi kiem bang tra; phan nay kiem cho NOI: `SngRig` phai tu phat khi
	# dong tac chay toi khung. Duong do khong ai chay ho duoc — ban goc phat o
	# tang C++ — nen phep kiem phai la: dung rig that, choi dong tac that, roi
	# `seek` toi moc cua khung va dem tieng.
	#
	# `seek` duoc la vi `SngRig._process` doc `current_animation_position`, chu
	# khong dua vao track phuong thuc (track phuong thuc KHONG chay khi
	# `seek`/`advance`, xem chu thich o `_dat_tron`).
	var rig := SngRig.build("res://assets_ref/Archer")
	t("dung duoc rig Archer de do", rig != null)
	if rig != null:
		root.add_child(rig)
		rig.position = Vector2(100, 100)
		# `Archer/Fight` co dung mot tieng, o khung 10 = 10/24 giay (phuong kiem
		# ngay tren). Khung dau chua toi moc do.
		rig.play("Fight")
		await process_frame
		await process_frame
		var truoc := am.so_phat
		rig.player.seek(10.0 / SngRig.FPS + 0.01, true)
		await process_frame
		var sau := am.so_phat
		t("rig tu phat tieng khi dong tac toi khung",
				sau - truoc == 1, "phat them %d" % (sau - truoc))
		# Qua moc ma khong choi lai thi khong phat lai lan nua (chi tieng
		# `loop="1"` moi phat lai khi dong tac quay vong).
		rig.player.seek(20.0 / SngRig.FPS, true)
		await process_frame
		t("qua moc ma khong quay vong thi khong phat lai",
				am.so_phat - sau == 0, "phat them %d" % (am.so_phat - sau))
		rig.queue_free()


## Bam thu dung nhu man hinh ban goc bam: qua `G_SoundManager`, khong goi thang
## chuoi `event:/...` (SoundManager.lua:24, :39, :44, :54).
##
## Boc ham toan cuc mot lat de DOC DUOC id ma `G_SoundManager:PlaySoundEffect`
## nem di — no khong dung gia tri tra ve. Vo boc tra dung hai gia tri nhu ban
## goc nen khong doi hanh vi cua no.
const _BAM_THU := """
	local o = {}
	o.xin, o.that_bai, o.define_hong = 0, 0, ''
	o.voice, o.sae, o.that_bai_4 = 0, 0, 0
	local goc = playSoundEffect
	local id_cuoi = 0
	playSoundEffect = function(ten)
		local ok, id = goc(ten)
		if ok == 1 and type(id) == 'number' and id > 0 then id_cuoi = id
		else id_cuoi = -1 end
		return ok, id
	end
	local goc_nhac = playBackgroundMusic
	o.nhac_goi, o.nhac_dat = 0, 0
	playBackgroundMusic = function(ten)
		o.nhac_goi = o.nhac_goi + 1
		local kq = goc_nhac(ten)
		o.nhac_dat = kq and 1 or 0
		return kq
	end	local function thu1(f)
		id_cuoi = 0
		f()
		if id_cuoi > 0 then o.xin = o.xin + 1 return id_cuoi end
		o.that_bai = o.that_bai + 1
		return 0
	end

	-- 1. Bay tieng trong SoundDefine — dung bay ten ma ban goc dung o 76 cho
	--    (mo/dong cua so, nut bam, nhan thuong).
	local ds = {}
	for ten, ev in pairs(G_SoundManager.SoundDefine) do ds[#ds + 1] = {ten, ev} end
	table.sort(ds, function(a, b) return a[1] < b[1] end)
	o.so_define = #ds
	G_thu_am_id = {}
	for _, m in ipairs(ds) do
		local id = thu1(function() G_SoundManager:PlaySoundEffect(m[1]) end)
		if id == 0 then o.define_hong = o.define_hong .. m[1] .. ' ' end
		if id > 0 then G_thu_am_id[#G_thu_am_id + 1] = id end
	end
	o.id1 = G_thu_am_id[1] or 0

	-- 2. Ten do CLIENT tu ghep luc chay (giong noi cua tuong,
	--    CGuideScheme.lua:14): khong bao gio nam trong danh sach chuoi quet
	--    duoc, nen phai tra tiep theo TEN subsound.
	o.voice = thu1(function()
		playSoundEffect(string.format('event:/Vo-Usual/Vo_%s_Usual', 'ZhaoYun'))
	end)

	-- 3. SimpleAudioEngine: lop cua engine (game.lua:238 la cho dung that).
	local e = SimpleAudioEngine:new()
	local id_sae = e:playEffect('event:/UI/UI_Objects')
	if type(id_sae) == 'number' and id_sae > 0 then o.sae = 1 o.xin = o.xin + 1
	else o.that_bai = o.that_bai + 1 end

	-- 4. directPlaySoundEffect (2 cho) — khong tra ve gi.
	thu1(function() G_SoundManager:directPlaySoundEffect('event:/UI/UI_Objects') end)

	-- 5. Ten khong co that: PHAI tra `0, 0` chu khong nem loi, va PHAI dem
	--    vao so khong tra duoc de ben kiem con phan biet duoc.
	local ok4, id4 = playSoundEffect('event:/Khong/Co_That')
	if ok4 == 0 and id4 == 0 then o.that_bai_4 = 1 end
	-- Duong cua SoundManager khi ten khong co trong SoundDefine: no bao
	-- "no define sound" roi VAN thu phat chuoi tho (SoundManager.lua:48-49).
	thu1(function() G_SoundManager:PlaySoundEffect('khong_co_ten_nay') end)

	-- 6. Nhac nen. Xoa ten dang hat truoc: PlayBackgroundMusic KHONG goi lai
	--    cung mot bai (SoundManager.lua:26).
	G_SoundManager.strPlayingBackgroundMusic = nil
	stopBackgroundMusic()
	G_SoundManager:PlayBackgroundMusic('event:/BGM/BGM_Main')

	local okv, vol = getBackgroundMusicVolume()
	o.vol_dau = vol
	playSoundEffect = goc
	playBackgroundMusic = goc_nhac
	return o
"""

## Tat tieng va hat nho nhac nen. `%d` la id that lay tu _BAM_THU.
const _TAT_THU := """
	local o = {}
	o.khong_loi = pcall(function()
		stopSoundEffect(%d)
		stopSoundEffect(nil)
		stopSoundEffect(0)
		stopSoundEffect(999999)
		stopSoundEffect(S_CCDirector)
	end)
	-- Bon man chat hat nho nhac nen luc ghi am roi tra lai (CAsrManager.lua).
	local _, vol_dau = getBackgroundMusicVolume()
	setBackgroundMusicVolume(0.0)
	o.vol_0 = select(2, getBackgroundMusicVolume())
	setBackgroundMusicVolume(vol_dau)
	o.vol_tra_lai = select(2, getBackgroundMusicVolume())
	-- Nap / bo nap bank — CUIWing.lua:1474 va game.lua:340-345.
	loadEffectBank('EXTRA', 'banks/EXTRA.bank')
	return o
"""

## Bo nap bank, va kiem luon rang ham chiu duoc tham so la (ban goc goi
## `unloadBankByName(ten)` o 18 cho, co cho chi truyen ten).
const _BO_BANK := """
	unloadBankByName('EXTRA')
	unloadBankByName('khong_co_bank_nay')
	unloadBackgroundBank('EXTRA')
	return true
"""


func _ket() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
