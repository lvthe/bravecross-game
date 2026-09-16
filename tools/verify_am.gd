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

	# --- 4. Duong Lua THAT: khung suon -> G_SoundManager -> kenh --------------
	# Ba phan tren moi kiem DU LIEU (file nap duoc, do dai dung, bang tra tra ra
	# file that). Phan nay kiem cho NOI. Ban goc khong bao gio goi thang file
	# .ogg: no goi `G_SoundManager:PlaySoundEffect(TEN)` (76 cho) roi xuong
	# `playSoundEffect` cua engine. Cac ten do truoc day la BONG — khong file
	# Lua nao trong 973 file dinh nghia chung — nen moi tieng bam nut, mo cua
	# so, nhan thuong deu cam. Day la phep kiem chot cua ca duong noi.
	await _duong_lua()

	_ket()


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
	t("tieng hen luc _init phat het o khung dau",
			am.so_phat - m_phat == mong and am.dang_hen() == 0,
			"phat %d, mong %d, con hen %d"
			% [am.so_phat - m_phat, mong, am.dang_hen()])
	t("khong tieng nao thieu file", am.so_thieu_file == m_thieu,
			"%d" % (am.so_thieu_file - m_thieu))
	t("khong tieng nao het kenh (12 kenh, xin %d)" % xin,
			am.so_het_kenh == m_kenh, "%d" % (am.so_het_kenh - m_kenh))
	t("kenh nao cung gan duoc vao san khau", am.so_khong_co_cha == m_cha,
			"%d" % (am.so_khong_co_cha - m_cha))
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
