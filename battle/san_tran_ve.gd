# Tran CO HINH tren san cua ban goc. g_BattleField gia (lua/san_tran.lua) gan
# mot nut nay vao node g_BattleField roi goi bat_dau / buoc / chot / dung.
#
# Quan: BattleUnit (battle/unit.gd) — di theo lan, chon muc tieu, nhip danh,
# thanh mau, dong tac SngRig. So: Combat.Fighter dung tu CHI SO THAT cua ban
# goc (tran_goc.gd doc_quan). Buoc tran hai pha va day nhau ra: chep dung
# cach cua battle/battle.gd (_step, _separate), ly do ghi o do.
#
# Buoc theo nhip cua LUA (buoc(dt) moi khung), khong theo _process: cong cu do
# chay khong cua so, san khau khong nam trong cay canh, _process khong chay.
#
# Cho dung va camera theo so THAT: 1 o = 100 px (map/hero_config.xml ghi
# "单位:格 100pix"), PosX cua du lieu ai tinh theo o tu g_MapZero, man nhin
# rong 13,66 o (CUIGame:FitBattleArmyPos can giua dau truong o 6,83). San dai
# hon man nen camera chay theo quan, va tung lop nen troi theo he so parallax
# cua no (+0x30 cua ban ghi node — xem brave-cross/work/xgg.py).
#
# DAT, khong phai ban goc:
#   * CACH camera bam quan (_buoc_camera) — con so cua no thi that;
#   * duong mat dat: giua node g_MapZero (bo cuc ghi y = 165);
#   * co armature: NpcSize cua du lieu goc;
#   * toc do, tam danh toi thieu: cua BattleUnit (chinh cho man 960 px);
#   * nguoi DAU TIEN cua toan linh dua ra dung ngay moc cua toan hay lech nua
#     toan, va nhip cach giua cac toan dua ra — xem `dua_linh`.
extends Node2D

const TRAN_GOC := preload("res://battle/tran_goc.gd")
const BANG_TUONG := preload("res://battle/bang_tuong.gd")
const STEP := 0.033
## 1 o (格) = 100 px: "单位:格 100pix" (map/hero_config.xml). Khop voi
## MaxAttackDistance tinh bang px (30 can chien, 300-500 ban xa).
const O_PX := 100.0
## Muc <camera> cua map/global_config.xml, don vi o va giay.
const CAM_NGUONG := 0.8     ## fCameraThreshold
const CAM_TOC := 1.8        ## fTrackSpeedPPS
const CAM_CHAM_RA := 2.0    ## fTrackSlowOutDist
const CAM_CHAM_VAO := 0.7   ## fTrackSlowInFullTime
const CAM_DUOI := 5.0       ## fTrackChasingDist
const HANG := 26.0          ## linh cung nhom dung lech nhau theo y
const BODY := 56.0          ## xem battle.gd
const BIEN := 90.0          ## le trai / phai: cho quan tiep vien vao tran
## Luoi dan quan luc ra tran, XEP CHEO nhu ban goc: cac hang lech nhau ca theo
## y (RANK_Y) LAN theo x (SKEW_X) nen tuy y-cach nho hon than nguoi (BODY=56)
## ma hai nguoi canh nhau van cach du xa (sqrt(RANK_Y^2+SKEW_X^2) >= BODY) —
## khoi chong. Nho vay doi hinh gon theo chieu doc, nam THAP o duoi san giong
## ban TQ (nguoi choi doi chieu bang anh chup ban goc), khong treo len giua man.
## Chi la CHO DUNG BAN DAU cua ta; _tach() giu khoang cach sau do, ket qua tran
## do chi so + cong thuc quyet dinh.
## SO LAN va KHOANG CACH LAN la cua BAN GOC, va DON VI nay DA DO DUOC — khong con
## la suy luan. Chinh `map/global_config.xml` ghi chu ngay tren hai hang so do
## `<!-- 道宽 格 -->` ("be ngang duong [lan], tinh bang O"), va engine nhan no voi
## co o tinh bang px: `0x35f43e` (vn; lop `CDFTMXTiledMap`) doc `fLaneWidth` roi
## `vmul.f32` voi o `+0x270` (= `0x35e73a`, vn; tuc `this+0x180`, cap co o). Vay
## 0.4 o = 40 px va 0.1 o = 10 px — ba duong doc lap khac cung noi co o = 100 px
## (engine viet cung `100*(4-idx)`, `InWhichCell` chan theo "co o x so o", va
## `map/map_1.tmx` khai `tilewidth=100`).
## Cong thuc xep lan cua engine `0x35f0a4` (vn): `y = y0 + (Location-1) * 40 + 10` —
## xem `lan_lech_y()`. Ba lan nam gon trong 10 + 2*40 = 90 px < 1 o, va `Location`
## cua bang binh chung (`config/share/KDBGameArmyConfig.xgg`, 91 muc) chi nhan
## 0..3 — nen `LAN_SO` cung la so DO, khong phai so ta chon.
## Bang so + duong do: `brave-cross/work/tran_ref.py` -> `data_ref/tran_ref.json`,
## khoa bang `tools/verify_lan.gd`.
const LAN_SO := 3           ## max Location cua bang binh chung
const LAN_CACH := 40.0      ## fLaneWidth 0.4 o
const LAN_LECH := 10.0      ## fLaneOffset 0.1 o
const HANG_SO := LAN_SO     ## so hang xep khi quan KHONG co lan rieng
const RANK_Y := LAN_CACH    ## cach hang theo y
const SKEW_X := 46.0        ## hang sau lech ngang -> xep cheo, khoi chong
## Khoang cach giua hai quan cung lan: `fArmySpace` cua map/global_config.xml,
## don vi o (1.1 o = 110 px voi o = 100). So THAT cua ban goc; truoc day la 48
## px do ta dat, nho hon than nguoi (BODY = 56) nen quan cung lan chong nhau va
## `_tach()` phai day ra.
const ARMY_SPACE := 1.1
const DOAN_LEN := 24.0      ## nhac ca doi hinh len khoi the tuong o goc man

var _rules: Dictionary = {}
var _rng: Combat.Rng
var _doi: Array = [[], []]     ## BattleUnit theo doi
var _muc := {}                 ## BattleUnit -> muc cua doc_quan
var _cho: Array = []           ## dich chua ra tran (AppearTime > 0)
var _dem := {}                 ## so quan da dat o moi (doi, o)
var _t := 0.0
var _max_t := 300.0
var _accum := 0.0
var _xong := false
var _sat := {}
## Mep TRAI / PHAI cua SAN THAT — cac lop nen he so 1 (`gb1_*`, cac dai mat dat).
## Do 2026-09-21 tren bo cuc ai thuong: bon dai 1024x40 o x = 0/1024/2048/3072 nen
## san trai **0..4096 px = 40,96 o**. Truoc do hai so nay lay theo Control NGOAI
## CUNG — tuc be ngang KHUNG NHIN (do duoc 1152 px o cua so 16:9), nho hon san
## that **3,56 lan**; hau qua thay duoc la quan TIEP VIEN cua dich vao tran o
## x = 1152 - BIEN, tuc giua san, thay vi mep phai that (`_mep_vao`).
## Hai gia tri mac dinh duoi day chi la du phong: `_dat_khung` dien chung theo
## khung nhin, roi `_tim_lop` ghi de bang san that neu bo cuc co dai mat dat.
var _trai := 0.0
var _phai := 1429.0
## Be ngang KHUNG NHIN (Control ngoai cung) trong he toa do cua nut nay. Camera va
## minimap can be ngang DANG NHIN, khong phai be ngang san — hai thu khac han nhau
## (1152 so voi 4096), nen truoc day chung dung nham `_phai - _trai`.
var _man := 0.0
var _o := 48.0
var _mat_dat := -165.0
var _thieu_rig := {}
var _dau: Array = []           ## [ten, x, y] luc ra tran — cho khung()
var _sprite: Dictionary = {}   ## Sprite cua du lieu quan ta: Troop_<n> la linh dua ra duoc
var _so_linh := 0              ## so linh da dua ra (danh so thu tu)
var _so_thuc_tinh := 0         ## so don thuc tinh tuong ta da tung
## Tieng trung don: tong so don, so don co tieng, so don im. Xem `dem_tieng`.
var _so_don := 0
var _so_tieng := 0
var _so_im := 0
## {ly do: so don} — chia so im theo nguyen nhan. Xem `_phat_trung_don`.
var _ly_do_im: Dictionary = {}
## Hieu ung trung don: so lan chay duoc, so lan im, va {ly do: so lan}. Xem
## `_phat_hieu_ung` va `dem_tieng`.
var _so_hieu_ung := 0
var _so_hieu_ung_im := 0
var _ly_do_hu: Dictionary = {}
## Hieu ung THUC TINH — 14 truong `s*` nhom SINH HIEN cua `WakeRef` (xem
## `battle/wake_ref.gd` va `hieu_ung_thuc_tinh`). Cung loi `dem_tieng`: mot
## armature khong dung duoc thi **khong nem mot dong loi nao**, nen phai DEM.
var _so_tt_ve := 0
var _so_tt_im := 0
var _ly_do_tt: Dictionary = {}
## So sat thuong NOI (battle/nhan_sat_thuong.gd). Node con cua chinh nut nay nen
## dung cung he toa do voi `BattleUnit.sx/sy` — khong phai doi o nao.
var _nhan: NhanSatThuong = null
var _goc_x := 0.0              ## o 0 cua san (g_MapZero), toa do cua nut nay
## Moc dung cua toan quan ta tren san, tinh bang O (`Sprite.Troop.PosX` — mot cho
## dinh nghia duy nhat: `tran_goc.moc_toan`). Linh CO SAN trong du lieu tran dung
## moc nay; toan linh DUA RA cung dung moc nay (truoc 2026-09-20 la o 0) — xem
## `dua_linh`.
var _moc_toan := 0.0
var _ra_cuoi := 0              ## so nguoi vua ra o lan `dua_linh` cuoi cung
## Ket qua GAN DO cua lan `dua_dong_minh` gan nhat, dang chuoi cho nhat ky kich
## ban: "do 1/1 ok" khi gan duoc, "do 0/1, truot: ..." khi hong. Tu 2026-09-21
## luon co them phan NGUA MAC DINH khi don vi chua co ngua — "do 0/0 ok
## +ngua-mac-dinh:PonyChiTuGod" cho Lu Bo (xem `_gan_do`).
## Phai DEM chu khong im lang: gan do hong thi tran van xanh (khong phep kiem nao
## bat), nen khong doc so thi khong biet duong ay co chay khong. Xem `_gan_do`.
var _do_vua_gan := ""
## Ten tuong da duoc gan ngua MAC DINH (khoa `<sDefaultMount>` cua `map/*.xml`)
## — xem `_gan_do` va `do_ngua_mac_dinh`.
var _ngua_md: Array[String] = []
var _cam := 0.0                ## camera da troi bao nhieu px sang phai
var _cam_max := 0.0
var _cam_toc := 0.0            ## toc do hien tai, o/giay (tang dan luc bat dau)
var _cam_dung := false
var _lop: Array = []           ## [Control, x goc, he so parallax] cua nut parallax cha
var _bang = null               ## BangTuong: khung + thanh mau/no cua tuong ta (goc duoi-trai)


## Lech y cua mot LAN so voi duong dat (px, huong LEN), theo dung cong thuc cua
## engine `0x35f0a4`: `y = y0 + (Location-1) * fLaneWidth + fLaneOffset`. `lan`
## o day la so lan 1-based nhu `Location` cua ban goc, nen lan 1/2/3 ra
## 10 / 50 / 90 px. Tach ra thanh ham de bo kiem `tools/verify_lan.gd` doi chieu
## duoc voi con so trong `data_ref/tran_ref.json`.
static func lan_lech_y(lan: int) -> float:
	return LAN_LECH + float(lan - 1) * LAN_CACH


## Tra ve chuoi loi, hoac "" neu bat dau duoc. `mz` la node g_MapZero (co the
## null).
func bat_dau(ta_json: String, dich_json: String, hat: int, mz) -> String:
	var cb := Combat.new()
	var loi := cb.load_data()
	if loi != "":
		return loi
	_rules = cb.rules
	# Tran co hinh dung cong thuc sat thuong THAT cua ban goc (battle/harm.gd);
	# co nay chi tren ban rules rieng cua tran nay, khong dung toi mo hinh doi
	# chieu ba ben (combat.gd mac dinh, sim/, server/).
	_rules["harm_real"] = true
	_rng = Combat.Rng.new(hat)
	var ta = JSON.parse_string(ta_json) if ta_json != "" else null
	var dich = JSON.parse_string(dich_json) if dich_json != "" else null
	if not (ta is Dictionary) or not (dich is Dictionary):
		return "setSendTroops / setLevelData khong phai JSON object"
	_sprite = ta.get("Sprite", {})
	_moc_toan = TRAN_GOC.moc_toan(_sprite)
	var q: Dictionary = TRAN_GOC.doc_quan(ta, dich, _rules)
	_max_t = float(q["max_t"])
	_dat_khung(mz)
	_o = O_PX
	_tim_lop()
	for e in q["ta"]:
		_them(e, 0)
	for e in q["dich"]:
		if float(e["xuat_hien"]) > 0.0:
			_cho.append(e)
		else:
			_them(e, 1)
	_tao_nhan(hat)
	_tao_bang()
	return ""


## So sat thuong noi. Node con cua chinh nut nay nen `hien()` nhan thang toa do
## cua `BattleUnit` (px, cung he) — khong doi o, khong doi goc.
##
## Bo sinh so RIENG, khong dung `_rng` cua tran: `_rng` la mot day LCG, moi lan
## lay de lech ngang se day day so di mot buoc va LAM DOI KET QUA TRAN (chi so
## trung / chi mang cua tung don deu lay tu chinh day ay). Do la mot loi im lang
## nghiem trong: them mot hieu ung trang tri ma doi ket qua danh nhau.
## `hat + 1` de hai day khac nhau, va van theo `hat` nen phep kiem lap lai duoc.
func _tao_nhan(hat: int) -> void:
	_nhan = NhanSatThuong.new()
	add_child(_nhan)
	_nhan.dat_rng(Combat.Rng.new(hat + 1))


## Bang trang thai tuong ta (khung + thanh mau/no) o goc duoi-trai. Dat trong
## CanvasLayer nen theo toa do man hinh, khong troi theo camera, luon tren cung.
func _tao_bang() -> void:
	var lop := CanvasLayer.new()
	lop.layer = 20
	add_child(lop)
	_bang = BANG_TUONG.new()
	_bang.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lop.add_child(_bang)
	_cap_nhat_bang()


## Chep mau/no cua tung tuong ta sang bang de ve. Goi moi khung trong buoc().
func _cap_nhat_bang() -> void:
	if _bang == null:
		return
	var ds: Array = []
	for u in _doi[0]:
		var e: Dictionary = _muc.get(u, {})
		if not bool(e.get("tuong", false)):
			continue
		var f: Combat.Fighter = u.fighter
		if f == null:
			continue
		var full := float(_rules.get("angerFull", 100.0))
		ds.append({
			"ten": String(e.get("ten", "")),
			"mau": (f.hp / f.hp_max) if f.hp_max > 0.0 else 0.0,
			"no": (f.anger / full) if full > 0.0 else 0.0,
			# So sao = bac tuong (GrowthFactor cua du lieu tran, 1..4). Nhan vat
			# chinh tan thu la 1; tuong khac lay dung bac cua no. HeroGrowthFactor
			# dong (thien menh) cua nhan vat chinh chua noi vao — dung bac goc.
			"sao": maxi(1, int(f.raw.get("GrowthFactor", 1))) if f.raw != null else 1,
			"song": u.alive(),
		})
	_bang.tuong = ds
	_bang.queue_redraw()


## Be ngang KHUNG NHIN va duong mat dat, doi ve toa do cua nut nay. Tinh qua
## LuaRuntime._bien_doi (khong can nam trong cay canh), va lay mep theo chinh
## san khau nen khong phu thuoc ti le thu nho cua cua so.
##
## San THAT (mep trai/phai) khong lay o day: no nam tren cac lop nen he so 1
## (`gb1_*`), ma chi `_tim_lop` — chay NGAY SAU ham nay trong `bat_dau` — nhin
## thay. Hai gia tri dien o day la du phong cho bo cuc khong co dai mat dat.
func _dat_khung(mz) -> void:
	var cha := get_parent()
	if not (cha is Control):
		return
	var san: Control = cha
	while san.get_parent() is Control:
		san = san.get_parent()
	var nguoc := LuaRuntime._bien_doi(cha).affine_inverse()
	var bd_san := LuaRuntime._bien_doi(san)
	_trai = (nguoc * (bd_san * Vector2(0, 0))).x
	_man = (nguoc * (bd_san * Vector2(san.size.x, 0))).x - _trai
	_phai = _trai + _man
	_goc_x = _trai
	# g_MapZero la MOC bo cuc ban goc dung de dat quan (x = 0 cua san, y = duong
	# dat). No la CanvasItem nhung KHONG phai Control (khong co size), nen truoc
	# day nhanh "mz is Control" bi bo qua -> roi ve mat_dat mac dinh -165, quan
	# treo sai cho. Doc goc (0,0 cuc bo) cua no: Control thi lay tam, con lai lay
	# ngay diem goc.
	if mz is CanvasItem:
		var m: CanvasItem = mz
		var loc := (m as Control).size * 0.5 if m is Control else Vector2.ZERO
		var tam: Vector2 = nguoc * (LuaRuntime._bien_doi(m) * loc)
		_mat_dat = tam.y
		_goc_x = tam.x


func _them(e: Dictionary, doi: int) -> void:
	var px := float(e["pos_x"])
	var k := "%d/%s" % [doi, px]
	var i := int(_dem.get(k, 0))
	_dem[k] = i + 1
	var u := BattleUnit.new()
	# Dan HANG NGANG truoc, cot lui ra sau: xep theo luoi HANG_SO hang (chieu y)
	# roi moi day sang cot (chieu x). Truoc day chi 3 hang cach 26 px, ma than
	# nguoi BODY = 56 px > 26 -> ba hang chong len nhau, _tach() day thanh mot
	# dam tron thay vi doi ngu. Gio hang cach RANK_Y (>= BODY) nen nhin ra tung
	# hang, cot cach RANK_X. Luoi can giua quanh mat dat.
	# `Location` cua ban goc quyet dinh LAN (0..2). Quan khong co lan rieng
	# (tuong nguoi choi, `Location = 0`) thi rai deu theo thu tu ra tran nhu cu.
	var lan := int(e.get("lan", -1))
	var hang := lan if lan >= 0 else (i % HANG_SO)
	var cot := i / HANG_SO if lan < 0 else int(_dem.get(k + "/" + str(lan), 0))
	if lan >= 0:
		_dem[k + "/" + str(lan)] = cot + 1
	var lui := -1.0 if doi == 0 else 1.0
	u.sx = _goc_x + px * _o + lui * (float(cot) * _o * ARMY_SPACE + float(hang) * SKEW_X)
	# Hang truoc (hang 0) DUNG NGAY tren duong dat g_MapZero, cac hang sau lui
	# LEN (chieu sau san, y am hon) — dung vat ly duong dat, khong day xuong che
	# ca the tuong o goc man. DOAN_LEN nhac ca doi hinh len mot chut cho thoat
	# the tuong (nguoi choi doi chieu bang anh ban goc). CHO DAT la cua ban goc
	# phan LAN (`lan_lech_y`); DOAN_LEN thi la cua ta.
	u.sy = _mat_dat - DOAN_LEN - lan_lech_y(hang + 1)
	u.position = Vector2(u.sx, u.sy)
	add_child(u)
	var r := _thu_muc_rig(String(e["ten"]))
	var ten_hinh := String(e["ten"])
	if r[0] == "" and String(e["sprite"]) != "":
		r = _thu_muc_rig(String(e["sprite"]))
		ten_hinh = String(e["sprite"])
	if r[0] == "":
		_thieu_rig[String(e["ten"])] = true
	# Ten armature de tra HAI bang tieng cua ban goc (sound_config.xml theo hoat
	# dong, hit_config.xml theo don danh): lay dung ten vua phan giai duoc thanh
	# thu muc rig. Voi tuong thi `ten` la ten armature that ("ZhaoYun"); voi quan
	# thi co khi phai lay `sprite` moi ra.
	e["hinh"] = ten_hinh
	# Tuong ta giu no cho nut thuc tinh (Combat.Fighter.giu_no).
	if doi == 0 and e["tuong"]:
		(e["f"] as Combat.Fighter).giu_no = true
	# Ten sprite de tra toc do that (MoveRef): bang khoa theo <sName> cua
	# map/*_config.xml, khop voi SpriteName cua du lieu tran ("Defender").
	u.setup(e["f"], doi, _rules, _rng, r[0], float(e["co"]), r[1],
			String(e["sprite"]) if String(e["sprite"]) != "" else String(e["ten"]))
	_dau.append(["%s%d" % ["T" if doi == 0 else "D", int(e["id"])], u.sx, u.sy])
	_doi[doi].append(u)
	_muc[u] = e


## Cho MOT don vi VAO TRAN GIUA TRAN: mep san ben minh (ta: mep trai, dich: mep
## phai — hang so `BIEN` la le cua san danh cho quan tiep vien). MOT cho dinh
## nghia duy nhat cho duong quan TIEP VIEN cua kich ban (`dua_dong_minh`, ca hai
## doi). Toan linh bam nut binh chung CO Y khong di duong nay — xem `dua_linh`.
##
## Mep o day la mep SAN THAT (`_phai` = 4096 px o ai thuong), khong phai mep
## khung nhin: dich tiep vien phai vao tu mep phai cua san, khong phai tu giua
## san — do dung la hau qua cua viec lay `_phai` theo Control ngoai cung.
func _mep_vao(doi: int) -> float:
	return (_trai + BIEN) if doi == 0 else (_phai - BIEN)


## Dua MOT TOAN linh ra tran — nut binh chung cua ban goc (engine goi
## dispatch). Toan gom MaxUnit nguoi dung tu CHI SO THAT cua Sprite[<ten>]
## (vd Troop_1: DefenderN, HP 1000, MaxUnit 4). Tra so nguoi da dua ra.
##
## CHO DAT: MOC CUA TOAN — `_moc_toan` (`Sprite.Troop.PosX`, don vi O) truyen thang
## vao `_muc`. Truoc 2026-09-20 cho nay la o 0; doi sang moc vi mot phep do moi,
## xem "VI SAO DOI" duoi.
##
## MOC CUA TOAN thi la so DO: `Sprite.Troop.PosX` (`tran_goc.moc_toan`) la cho
## `CUIGame:FitBattleArmyPos` (CUIGame.lua:702) dat toan quan ta — 3,83 o (can
## giua o 6,83, doi phuong 9,83), `FightLogic:GetSelfFightDataBody` mac dinh 7 o;
## do trong tran THAT `L_N_01_01` bang `do_chien_dich --kiem`: PosX = 7 o = 700 px.
## `tran_goc.doc_quan` vi the dat linh CO SAN o moc ay.
##
## Vi sao KHONG dung moc ay cho toan dua ra:
##   * `dispatch()` cua engine khong tinh toa do nao (doc `.so` BAN VN: `0x45eef0`
##     -> than `0x45eda4` -> callee `0x466220` chi danh dau quan `+0x5a4 = 0x44`
##     roi noi quan vao danh sach cua san `singleton+0x39c`), nen "cho dung cua
##     quan dua ra = cho dung cua toan" chi la SUY RA, khong phai so do;
##   * may ao khong do duoc: bat co `bDirectBattle` (`sc/game.lua:483` ->
##     `CUIGame:Test()`) thi tien trinh toi `bDirectBattle = true` roi SIGSEGV
##     trong `RepaleceScene` (do: `work/emu_dom.py`, `work/emu_tran.py`);
##   * DA THU dat ngay moc, va DA DO LAI (2026-09-18) sau khi va hai loi o
##     `lua/san_tran.lua` (`dua_linh` gac oan theo co TAM DUNG, va `dung_tran` tat
##     dong ho dang buoc kich ban — xem `lua/san_tran.lua`):
##       - luot 2026-09-17 (luc hai loi con do): dat ngay moc lam
##         `do_chien_dich --kichban` tut tu **9 dat / 0 hong** xuong **6 dat / 3
##         hong**, vi tran KET THUC truoc buoc ke tiep cua kich ban ma dong ho kich
##         ban chinh la dong ho tran (`dung_tran` goi `T.hen:stop()`) — kich ban
##         dung han o lenh 27/43 (`ChangeFight LvbuEvil Fight`, khong bao gio toi
##         `SetArmyWaiting`). Dat tu mep (`_mep_vao`) cung ra **6 dat / 3 hong**.
##       - luot 2026-09-18 (sau khi va): dat ngay moc ra **11 dat / 0 hong**,
##         nhat ky kich ban **Y HET** luot dat o o 0, cung **1379 khung**. TUC
##         ket qua tut cua luot truoc la HE QUA cua hai loi kia, khong phai cua
##         cho dat. Khac biet DUY NHAT do duoc: tran xong som hon theo gio tran
##         (`song 0 giay 18` so voi `giay 57`) — nay vo hai vi `hen:buoc` van buoc
##         kich ban cho tới khi kich ban dien xong.
##     VI SAO DOI (2026-09-20): phep do cu chi hoi "bo do co phan biet duoc
##     khong" — va no khong phan biet duoc that. Nhung hinh thi phan biet duoc, va
##     luot nay do ra ve con thieu: dong `khung san` cua `do_chien_dich --kiem`
##     in the dung THE DUNG BAN DAU cua ca hai ben —
##       `trai 0 phai 1152 o 100.0 | T25@(700,-199) | T1@(0) T1@(-46) ... T1@(-422)`
##       `| D1@(1200) D1@(1310) D1@(1420) | D1@(1800,1910,2020) | D2015@(2400) ...`
##       * toan DICH theo dung `PosX`: 1200/1800/2400 px = 12/18/24 o, khop tung
##         chu voi `GROUPS DICH` cua chinh chuoi JSON, va luoi TIEN (+110) tu do;
##       * tuong ta `T25` dung dung **700** (= moc 7 o), con 12 linh DUA RA nam o
##         **0 .. -422** — tuc bang va NGOAI mep trai san (`trai 0`), cach moc cua
##         chinh toan minh **700 px**. Chung phai di bo vao san nen vao tran roi van
##         con don cuc o mep trai: dung cai nguoi dung thay trong anh loi.
##     Neu noi "quan dua ra dung cho cua toan" la SUY RA thi ket qua cua phep suy
##     do bay gio da ro: toan minh cung theo moc, giong het ben dich. Doi neo khong
##     doi luoi (luoi da khop `fArmySpace`/`SKEW_X`), chi doi goc.
##     Giu lai doan cu de biet vi sao lan 2026-09-17 lui lai: hai cho dat nay
##     **bo do khong phan biet duoc** (cung
##     11/0, cung nhat ky, cung so khung), nen doi cho dat la doi hanh vi ma khong
##     co bang chung nao doi theo. `dispatch()` cua engine khong tinh toa do nao,
##     nen ca hai deu la SUY RA. Giu nguyen o 0 cho tới khi co bang chung THAT.
##   * Duong (b) — lam bo do trung thanh — DA LAM MOT PHAN, va chinh no BAC BO mot
##     gia thiet cu: `lua/kich_ban.lua` nay giu CO THAT cua lenh
##     `SeDispatchButtonDisable` (`.so` BAN VN `0x468b54`: `r0 = toboolean(arg);
##     eor r0,r0,#1; strb.w r0,[drama+0x390]` — tuc `+0x390` la co BAN, gia tri
##     truyen vao bi DAO truoc khi ghi; ham doc lai o vn `0x45d554` tra 0 tru khi
##     `[drama+0x37c] == 1`; ban apk la `0x46af20` / `0x46af44`), va
##     `lua/san_tran.lua` DEM so lan bam trong luc bi cam. Do duoc: **0 lan** —
##     `SeDispatchButtonDisable(true)` (`drama_L_N_01_01.lua:668`) la lenh GAN CUOI
##     kich ban, sau khi quan da ra het, nen bo do khong he bam trong cua so bi cam.
##     Gia thiet cu ("bo do bam nut moi 30 khung KE CA trong cua so cam") vi the
##     SAI — no khong dung duoc de giai thich 9/0 -> 6/3; nguyen nhan van la dong
##     ho kich ban dung theo tran (muc ngay tren).
##   * Con lai cho (a): do duoc tren ban goc (duong may ao da chet) — van la
##     "chua ro" THAT, khong phai "da bac bo". Duong (b) con mot buoc nua moi
##     trung thanh that: cho bo do TUAN THEO co ay — khi do `bam_cam` khac 0 moi
##     la loi cua bo do, con bay gio no la so do.
## Vi vay tu 2026-09-20: cho dat la MOC CUA TOAN, va phep kiem `_kiem_moc` cua
## `do_chien_dich` do luoi lui tu CHINH moc ay (truoc do no do tu `_goc_x`).
func dua_linh(ten: String) -> int:
	if _xong:
		return 0
	var cs = _sprite.get(ten, null)
	if not (cs is Dictionary):
		return 0
	var bi = cs.get("BaseInfo", {})
	var n := maxi(1, int(bi.get("MaxUnit", 1))) if bi is Dictionary else 1
	for k in n:
		# Neo = MOC CUA TOAN (`Sprite.Troop.PosX`, o), khong phai o 0 — xem khoi
		# chu thich "CHO DAT" ngay tren ham nay. Truyen moc lam `_them` dung
		# CUNG mot khoa `_dem` voi linh co san cua toan (`"0/<moc>"`), nen linh
		# dua ra noi tiep luoi cua toan thay vi de len nguoi dau.
		var e: Dictionary = TRAN_GOC._muc(cs, _rules, int(cs.get("ArmyTypeID", 0)), false,
				_moc_toan, 0.0, _so_linh)
		_so_linh += 1
		_them(e, 0)
	_ra_cuoi = n
	return n


## Them MOT don vi GIUA TRAN theo kich ban (TakeUnitJoinBattle / CreateNpc cua
## g_DramaSystem). `cs` la ban ghi chi so THAT: NPC config (GetNpcConfigWithNpcId)
## cho dong minh nhu Lang Thong / Trieu Van, hoac linh. `ten_hinh` la ten
## armature de ve (Hero_Lingtong...). `doi` 0 = ben ta, 1 = ben dich.
## Nho vay ai co kich ban thang duoc DUNG cach ban goc: dong minh danh cung,
## khong phai chinh so lieu.
##
## `do_json` la danh sach TEN DO cua don vi (JSON mang chuoi), den tu hai nguon
## THAT cua kich ban: bang doi hinh (`G_HeroLogic:GetCharacterArmatureData` ->
## `.Weapon`...) va doi thu 11 cua `CreateNpcAndMoveTo` (`"equip_8_6"`). Gan
## bang dung duong `setGear` cua ban goc (`SngRig.dat_do`, xem `rig/sng_rig.gd`).
## Ban goc gan do bang `ClientPaperDoll:ChangePaperDollHelper`
## (`sc/user/Logical/ClientPaperDoll.lua:300-302`): duyet MOI gia tri cua bang
## doi hinh roi goi `setGear(pRole, value)` — khong loc theo loai.
func dua_dong_minh(ten_hinh: String, doi: int, cs_json: String,
		do_json: String = "") -> bool:
	if _xong:
		return false
	var cs = JSON.parse_string(cs_json) if cs_json != "" else null
	if not (cs is Dictionary):
		return false
	var e: Dictionary = TRAN_GOC._muc(cs, _rules, int(cs.get("NpcID", 0)), false,
			0.0, 0.0, _so_linh)
	# Ve theo armature kich ban chi dinh (Hero_Lingtong...), khong theo ten NPC.
	if ten_hinh != "":
		e["ten"] = ten_hinh
	_so_linh += 1
	var d := clampi(doi, 0, 1)
	_them(e, d)
	# Vao tran tu MEP (dong minh tu trai, dich tu phai) roi tu di vao — quan
	# tiep vien "di vao" cua kich ban (CreateNpcAndMoveTo), thay vi hien ngay
	# giua san. AI cua BattleUnit tu tien ve phia dich.
	var u: BattleUnit = _doi[d].back()
	u.sx = _mep_vao(d)
	u.position = Vector2(u.sx, u.sy)
	_do_vua_gan = _gan_do(u, do_json)
	return true


## Ket qua GAN DO cua lan `dua_dong_minh` gan nhat (xem `_do_vua_gan`).
func do_vua_gan() -> String:
	return _do_vua_gan


## Ten cac tuong da duoc gan NGUA MAC DINH trong tran nay (xem `_gan_do`), de
## `do_chien_dich` bao lai. Dem chu khong im lang: luat `<sDefaultMount>` chi co
## MOT muc o ban VN, nen "khong thay gi" va "chua bao gio chay" trong y het nhau.
func do_ngua_mac_dinh() -> String:
	return ", ".join(PackedStringArray(_ngua_md))


## Gan tung mon do len rig cua don vi, dung duong cua ban goc: `setGear(pRole,
## ten)` -> `SngRig.dat_do`. Tra chuoi mo ta ket qua (xem `_do_vua_gan`).
##
## Sau khi gan xong do cua kich ban, con mot luat nua: NGUA MAC DINH cua tuong
## (`rig/mount_ref.gd`, khoa `<sDefaultMount>` cua `map/*.xml`). Do 2026-09-21
## tren cay VN 1.26 luat ay co DUNG mot muc — `LvBuGod` -> `PonyChiTuGod` — va
## Lua 0 dong doc no; engine C++ doc theo ten. Chi gan khi don vi CHUA co mon
## ngua nao, va hoi bang BANG DO (`GearRef.la_mount`), khong doan theo ten.
func _gan_do(u: BattleUnit, do_json: String) -> String:
	if do_json == "":
		do_json = "[]"
	var ls = JSON.parse_string(do_json)
	if not (ls is Array):
		return "do: json hong"
	if u.rig == null:
		# Khong co rig thi khong co gi de gan — noi thang, dung nuot.
		return "do %d mon: khong co rig" % ls.size()
	var dat := 0
	var hong: Array = []
	for g in ls:
		var ten := String(g)
		if ten == "":
			continue
		if u.rig.dat_do(ten):
			dat += 1
		else:
			hong.append(ten)
	var them := ""
	var hinh := String(_muc[u].get("hinh", ""))
	var ngua := MountRef.ngua_can_gan(ls, hinh)
	if ngua != "":
		if u.rig.dat_do(ngua):
			dat += 1
			them = " +ngua-mac-dinh:" + ngua
			_ngua_md.append(hinh)
		else:
			hong.append(ngua + "(mac dinh)")
	if hong.is_empty():
		return "do %d/%d ok%s" % [dat, ls.size(), them]
	return "do %d/%d, truot: %s%s" % [dat, ls.size(),
			", ".join(PackedStringArray(hong)), them]


## Rut don vi khoi tran theo TEN ARMATURE (kich ban goi MakeUnitToPlotSprite /
## cho boss bo chay). Boss cua man huong dan (Lu Bo) la don vi kich ban dieu
## khien: ban goc keo no khoi giao tranh thuong roi cho chay. Bo no ra thi ben
## ta (co dong minh) don sach dam con lai -> thang. Tra so don vi da rut.
## DAT: khop bang ten armature chua chuoi `ten` (khong phan biet hoa thuong),
## vi kich ban goi theo sprite chu khong theo NpcID.
func xoa_theo_hinh(ten: String, doi: int) -> int:
	if ten == "":
		return 0
	var n := 0
	# Uu tien khop CHINH XAC ten armature; khong co moi den khop chua-chuoi.
	# Tranh "LvBu" vo tinh trung "LvBuEvil" khi ca hai cung tren san.
	for chinh_xac in [true, false]:
		for u in _doi[clampi(doi, 0, 1)]:
			if not u.alive():
				continue
			if _khop_hinh(_muc[u], ten, chinh_xac):
				u.fighter.hp = 0.0
				u.die()
				n += 1
		if n > 0:
			break
	return n


## Don vi `e` co khop ten armature `ten` khong. chinh_xac = so bang; nguoc lai
## la chua-chuoi (khong phan biet hoa thuong) — kich ban goi theo sprite.
func _khop_hinh(e: Dictionary, ten: String, chinh_xac: bool) -> bool:
	var k := ten.to_lower()
	var a := String(e.get("ten", "")).to_lower()
	var b := String(e.get("sprite", "")).to_lower()
	if chinh_xac:
		return a == k or b == k
	return a.contains(k) or b.contains(k) or (a != "" and k.contains(a))


## Vet cac lan `tuyet_chieu` da NHAN tham so, moi lan mot muc ngan cach `' > '`:
##
##     <hinh>|<dong tac>|<form>|<ky_nang|tu_the>|<so_don>
##
## Co ly do rieng chu khong phai tien tay: duong Lua -> GDScript di qua `goi_tran`
## cua `lua/kich_ban.lua`, ma ham ay boc loi goi trong `pcall` — lech SO THAM SO
## thi bi nuot IM LANG, khong mot dong loi nao. Muon biet tham so thu 5 (`form`)
## co toi noi that khong thi phai GHI LAI dung thu ham nhan duoc, chu "khong thay
## loi" khong noi duoc gi. `do_chien_dich --kichban` doc lai roi doi chieu voi
## nhat ky kich ban.
var _vet_tc: Array[String] = []


## Vet duoi dang chuoi de bo do doc qua cau Lua.
func vet_tuyet_chieu() -> String:
	return " > ".join(_vet_tc)


## Tuyet chieu theo KICH BAN (SetRoleChangeFight ... "Wake"/"Talent"). Tim don
## vi khop ten armature ben `doi`, phat dong tac `action`. Neu la tuyet chieu
## BEN TA (doi 0) thi danh AoE len moi dich con song — Trieu Van "that tien
## that xuat". Tra so don vi ta da tung chieu.
##
## SO DON lay tu CAU HINH GOC (WakeRef: 1 + so `fSectionIntervalWake_F<n>`,
## chan tren boi `nAttackSectionLimitWake`) — Trieu Van 1 don, Quan Vu 6, Tao
## Thuc 3. `so_don` truyen vao chi dung khi khong tra duoc sprite do.
## He so `fDamageBonusWake` va he so CHIA theo `nSplitWake` cung la so that;
## CACH ap (nhan `1 + bonus`, chia `clamp(nSplit/n, floor, 1)`) la DAT — luat
## ghep nam trong C++ (`CDFSpriteFight*Wake`).
## Van DAT: danh KHAP dich. SAT THUONG moi don dung cong thuc va chi so THAT
## (Combat.Fighter.strike voi ep_no, qua Harm), khong bia con so.
func tuyet_chieu(ten_hinh: String, doi: int, action: String, so_don: int,
		form: int = 0) -> int:
	if ten_hinh == "":
		return 0
	# THAM SO `form` MOI LA THAM QUYEN, khong phai ten dong tac. Do ca 17 cho
	# goi trong sc/plot/drama_*.lua thi form khop TUYET DOI voi ho dong tac:
	#
	#     form 1 -> "Fight", "Fight3", "Fight20"    (5 cho) doi TU THE
	#     form 2 -> "Wake", "Super", "Super4"      (10 cho) BIEN THAN / tuyet chieu
	#     form 4 -> "Talent"                        (1 cho) kich THIEN PHU
	#
	# Nghia cua form doc tu chinh chu thich ban goc: `--吕布变身` (Lv Bo BIEN
	# THAN) di voi form 2 + "Wake"; `--赵云触发龙胆` (Trieu Van kich thien phu)
	# di voi form 4 + "Talent".
	#
	# Truoc day thu phan loai nay theo TEN dong tac (`begins_with("Wake")`). DO
	# LAI thi tren DUNG 17 cho goi hien co hai luat cho ra CUNG ket qua, nen luot
	# nay KHONG doi ket qua tran nao: ba cho "Super"/"Super4" (drama_L_XSGK.lua)
	# deu la `doi = 1`, ma nhanh AoE duoi day von da bo qua moi loi goi cua ben
	# dich, con nam cho "Fight*" cua ben ta thi ten va form noi cung mot y.
	#
	# Doi sang `form` vi ten dong tac la mot QUY UOC con `form` la con so engine
	# gui — mot ai sau nay goi ky nang ben TA bang ten khac ("Super" chang han)
	# se bi luat ten bien thanh TU THE va khong gay sat thuong, khong mot dong
	# loi nao (xem `vet_tuyet_chieu`).
	#
	# `form` = 0 (khong truyen) thi LUI VE phep thu theo ten: duong CU, de cho
	# goi nao thieu tham so khong am tham doi hanh vi.
	var la_ky_nang := action.begins_with("Wake") or action.begins_with("Talent")
	if form > 0:
		la_ky_nang = form == 2 or form == 4
	# "Thuc tinh" (bien than) la form 2; form 4 ("Talent") khong phai, va ten
	# dong tac `Fight*` cua form 1 la doi TU THE. Mot cho dinh nghia, dung cho
	# ca so don lan hieu ung ben duoi.
	var la_thuc_tinh := form == 2 or (form == 0 and action.begins_with("Wake"))
	# So don cua ban goc chi co o dong tac THUC TINH (form 2); "Talent" (form 4)
	# tra WakeRef ra 0 nen giu nguyen so don truyen vao.
	if la_thuc_tinh:
		var that := WakeRef.so_don(ten_hinh)
		if that > 0:
			so_don = that
	# GHI VET truoc khi gac `_xong`. Vet la KENH DO chu khong phai HIEU UNG: no
	# phai ghi MOI loi goi da toi day, ke ca loi goi sau khi tran xong, vi
	# `do_chien_dich --kichban` doc chinh no de biet tham so `form` co di noi
	# khong (xem `vet_tuyet_chieu`). Do 2026-09-20: tran ket thuc o GIAY 22 con
	# kich ban chay 1379 khung, nen lenh `ChangeFight ZhaoYun Wake f2` cuoi cung
	# cua kich ban VA CA BON phep do `form` deu toi sau `_xong` — de phep ghi
	# duoi cong thi 5 loi goi bi nuot IM LANG va `--kichban` tut tu 16 dat /
	# 0 hong xuong 11 dat / 5 hong, khong mot dong loi nao. HIEU UNG (sat
	# thuong, doi dong tac) thi VAN gac, o cong ngay duoi day.
	_vet_tc.append("%s|%s|%d|%s|%d" % [ten_hinh, action, form,
			"ky_nang" if la_ky_nang else "tu_the", so_don])
	if _vet_tc.size() > 64:
		_vet_tc.remove_at(0)
	if _xong:
		return 0
	var full := float(_rules.get("angerFull", 100.0))
	var n := 0
	for u in _doi[clampi(doi, 0, 1)]:
		if not u.alive() or not _khop_hinh(_muc[u], ten_hinh, false):
			continue
		n += 1
		u._play_lai(action if action != "" else "Wake")
		# HIEU UNG THUC TINH: `_play_lai` chi doi dong tac cua CHINH tuong; 14
		# truong `s*` con tro toi nhung armature RIENG va khong duong nao khac
		# cham toi chung (xem `hieu_ung_thuc_tinh`). Chi voi don BIEN THAN —
		# form 1 (`Fight*`) la doi TU THE, khong co hieu ung thuc tinh nao.
		# Sinh cho CA HAI ben: day la trang tri, va mot don thuc tinh cua dich
		# cung phai thay hieu ung cua no.
		if la_thuc_tinh:
			hieu_ung_thuc_tinh(ten_hinh, u)
		if doi != 0 or not la_ky_nang:
			continue        # tuyet chieu dich / doi tu the: chi dien, khong AoE
		var song := 0
		for v in _doi[1]:
			if v.alive():
				song += 1
		var he_so := WakeRef.chia(ten_hinh, song) * (1.0 + WakeRef.them(ten_hinh))
		for v in _doi[1]:
			for _k in maxi(1, so_don):
				if not v.alive():
					break
				u.fighter.anger = full
				u.fighter.ep_no = true
				# Mau cua CA HAI ben truoc don: ben chiu de biet sat thuong that,
				# ben danh de biet `strike()` co hut mau hay khong (xem `_phat_trung_don`).
				var mau_u: float = u.fighter.hp
				var mau_v: float = v.fighter.hp
				var r: Dictionary = u.fighter.strike(v.fighter, _rng, _rules)
				# strike() da tru mau theo don thuong; buoc them / bot cho dung
				# he so thuc tinh cua ban goc.
				var bu := float(r.get("damage", 0.0)) * (he_so - 1.0)
				v.fighter.hp = maxf(0.0, v.fighter.hp - bu)
				_phat_trung_don(u, v, 2, {
					"sat": maxf(0.0, mau_v - v.fighter.hp),
					"crit": bool(r.get("crit", false)),
					"hoi": maxf(0.0, u.fighter.hp - mau_u),
				})
			if not v.alive():
				v.die()
	return n


## No cua tung tuong ta, dung thu tu ra tran: JSON [{id, day, song}]. San tran
## gia (lua/san_tran.lua) doc moi khung de doi trang thai nut thuc tinh.
func no_tuong() -> String:
	var full := float(_rules.get("angerFull", 100.0))
	var ds: Array = []
	for u in _doi[0]:
		var e: Dictionary = _muc[u]
		if not e["tuong"]:
			continue
		ds.append({"id": e["id"], "day": u.alive() and u.fighter.anger >= full,
				"song": u.alive()})
	return JSON.stringify(ds)


## Nguoi choi bam nut thuc tinh cua tuong `id`: don KE TIEP cua tuong la don
## ky nang (Combat.Fighter.ep_no). DAT: hieu ung rieng cua tung ky nang nam
## trong C++ cua ban goc (cac lop CDFSpriteFight*Wake), chua giai.
func thuc_tinh(id: int) -> bool:
	if _xong:
		return false
	var full := float(_rules.get("angerFull", 100.0))
	for u in _doi[0]:
		var e: Dictionary = _muc[u]
		if e["tuong"] and int(e["id"]) == id and u.alive() and u.fighter.anger >= full:
			u.fighter.ep_no = true
			return true
	return false


func so_thuc_tinh() -> int:
	return _so_thuc_tinh


## CHI DE KIEM (tools/do_chien_dich.gd), khong phai ham cua ban goc: dat no
## cua tuong ta `id`. Kiem duong nut thuc tinh (sang -> bam -> NoticeCastSkill
## -> don ky nang) ma khong phu thuoc can can tran: o L_N_01_01 tuong ta co
## the chet truoc khi du 4 don de day no.
func _dat_no(id: int, gia_tri: float) -> bool:
	for u in _doi[0]:
		var e: Dictionary = _muc[u]
		if e["tuong"] and int(e["id"]) == id and u.alive():
			u.fighter.anger = gia_tri
			return true
	return false


## Mot khung cua Lua. Tra ve "" khi tran con danh, JSON cua tong_ket khi xong
## (dung mot lan).
func buoc(dt: float) -> String:
	if _xong:
		return ""
	# Gom dt roi chay tung BUOC CO DINH — xem battle.gd _process.
	_accum += dt
	var out := -1
	var budget := 40
	while _accum >= STEP and out < 0 and budget > 0:
		_accum -= STEP
		budget -= 1
		out = _mot_buoc(STEP)
	_buoc_camera(dt)
	_buoc_thu_phong(dt)
	_buoc_di_dien(dt)
	_buoc_hieu_ung(dt)
	if _nhan != null:
		_nhan.buoc(dt)
	_buoc_phu(dt)
	_buoc_rung(dt)
	_cap_nhat_bang()
	_ve_minimap()
	if out < 0:
		return ""
	return chot(out == 0)


func _mot_buoc(delta: float) -> int:
	_t += delta
	for e in _cho.duplicate():
		if float(e["xuat_hien"]) <= _t:
			_cho.erase(e)
			_them(e, 1)

	var snap := {}
	for d in 2:
		for u in _doi[d]:
			snap[u] = [u.sx, u.sy]
	var danh := []
	for d in 2:
		for u in _doi[d]:
			var v: BattleUnit = u.advance(delta, _doi[1 - d], snap)
			if v != null:
				danh.append([u, v])
	_tach()
	for p in danh:
		var truoc: float = p[1].fighter.hp
		var mau_danh: float = p[0].fighter.hp
		var r: Dictionary = p[0].resolve(p[1])
		var e: Dictionary = _muc[p[0]]
		# Sat thuong THAT da tru = mau truoc tru mau sau (khong dung `r.damage`:
		# `hp` bi chan duoi o 0, nen mot don ket lieu ghi 5000 vao mot nguoi con
		# 12 mau thi con so nguoi choi thay phai la 12). Dung lai chinh so nay cho
		# bang `_sat` ben duoi — mot phep tinh, mot cho.
		var mat := maxf(0.0, truoc - p[1].fighter.hp)
		# Tieng TRUNG DON: ban goc phat o tang C++ khi don trung, ghep tu loai vu
		# khi cua ben danh + loai giap cua ben chiu + do manh. Don ky nang dem
		# "nang" (2), don thuong "nhe" (1) — do manh la DAT, xem `_phat_trung_don`.
		if not r.is_empty():
			_phat_trung_don(p[0], p[1], 2 if r.get("skill", false) else 1, {
				"sat": mat,
				"crit": bool(r.get("crit", false)),
				"hoi": maxf(0.0, p[0].fighter.hp - mau_danh),
			})
		# Don thuc tinh cua tuong ta: dem, va phat dong tac Wake cua armature.
		if r.get("skill", false) and e["tuong"] and p[0].team == 0:
			_so_thuc_tinh += 1
			p[0]._play_lai("Wake")
			# HIEU UNG THUC TINH. Day moi la duong NGUOI CHOI di: bam nut thuc
			# tinh (`thuc_tinh(id)` dat `ep_no`), roi don ke tiep thanh don ky
			# nang — khac han duong KICH BAN (`tuyet_chieu`), va ca hai deu phai
			# sinh hieu ung. Do 2026-09-21 tren `do_chien_dich --kiem`: tran that
			# di dung duong nay (`thuc tinh 25` trong nhat ky), va truoc khi noi
			# day thi `dem_thuc_tinh` ra `ve 0, im 0` — tuc KHONG mot dau vet.
			hieu_ung_thuc_tinh(String(e.get("hinh", "")), p[0])
		if e["tuong"] and p[0].team == 0:
			var key := str(e["id"])
			_sat[key] = float(_sat.get(key, 0.0)) + mat
	for d in 2:
		for u in _doi[d]:
			if not u.alive():
				u.die()

	var a := _con_song(0)
	var b := _con_song(1) + _cho.size()
	if a > 0 and b > 0:
		return -1 if _t < _max_t else 2
	if a > 0:
		return 0
	if b > 0:
		return 1
	return 2


func _con_song(d: int) -> int:
	var n := 0
	for u in _doi[d]:
		if u.alive():
			n += 1
	return n


## Day cac don vi ra khoi nhau — chep battle.gd _separate.
func _tach() -> void:
	var all := []
	for d in 2:
		for u in _doi[d]:
			if u.alive():
				all.append(u)
	var sh_x := {}
	var sh_y := {}
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: BattleUnit = all[i]
			var b: BattleUnit = all[j]
			var dx: float = b.sx - a.sx
			var dy: float = b.sy - a.sy
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= BODY or dist < 0.001:
				continue
			var k := (BODY - dist) * 0.5 / dist
			var px := dx * k
			var py := dy * k
			sh_x[a] = float(sh_x.get(a, 0.0)) - px
			sh_y[a] = float(sh_y.get(a, 0.0)) - py
			sh_x[b] = float(sh_x.get(b, 0.0)) + px
			sh_y[b] = float(sh_y.get(b, 0.0)) + py
	for u in all:
		if sh_x.has(u):
			u.sx += float(sh_x[u])
			u.sy += float(sh_y[u])
			u.position = Vector2(u.sx, u.sy)


## Chot tran NGAY (het tran, het gio, hay ban goc goi showGameEnd). Tra JSON.
func chot(thang: bool) -> String:
	_xong = true
	var ds_ta := []
	var ds_dich := []
	# Xong tran: nguoi song ve Standby, xac an han (buoc khong con chay nen
	# advance() khong mo not duoc — an o day cho man ket thuc sach).
	for d in 2:
		for u in _doi[d]:
			(ds_ta if d == 0 else ds_dich).append(_muc[u])
			if u.alive():
				u._play("Standby")
			elif u.rig != null:
				u.rig.visible = false
	for e in _cho:
		ds_dich.append(e)
	return JSON.stringify(TRAN_GOC.tong_ket(ds_ta, ds_dich, _t, _sat, thang))


func dung() -> void:
	_xong = true


## Cac lop cua nut parallax cha — g_BattleFieldLayer, CCParallaxNode trong
## Game_UI_960_640 — ma ban goc nap ca file san vao: nen gb<tang>_<o>, troi,
## va chinh g_BattleField. Ghi x goc va he so (meta 'parallax'; khong co la 1).
##
## Ham nay cung la cho DUY NHAT biet SAN THAT rong bao nhieu: cac lop he so 1
## (`gb1_0..3`, bon dai 1024x40 lien nhau) trai 0..4096 px = 40,96 o. Truoc
## 2026-09-21 `_trai`/`_phai` lay theo Control ngoai cung (be ngang KHUNG NHIN,
## 1152 px) — hep hon san that 3,56 lan.
func _tim_lop() -> void:
	_lop.clear()
	var san_node := get_parent()
	var cha: Node = san_node.get_parent() if san_node != null else null
	if not (cha is Control):
		return
	var lech_san := (san_node as Control).position.x if san_node is Control else 0.0
	var mep := 0.0
	var mep_trai := INF
	for c in cha.get_children():
		if not (c is Control):
			continue
		var k: Control = c
		var r := 1.0
		# KHONG dung `get_meta("parallax", null)`: Godot coi `null` la "khong
		# truyen mac dinh" (do 2026-09-21 tren 4.7.2: `get_meta(t, null)` bao loi
		# y het `get_meta(t)`), nen moi lop KHONG khai he so sinh mot dong loi —
		# dung 5 dong moi lan vao tran (5/34 node goc cua
		# BattleField_Battlefield_960_640 khong co truong nay: g_BattleField va
		# gb1_0..3). Bo cuc chi ghi khi khac (1,1) (work/layout.py:68) nen
		# "vang mat = 1" moi la dung, khong phai doan.
		if k.has_meta("parallax"):
			var p = k.get_meta("parallax")
			if p is Array and not (p as Array).is_empty():
				r = float(p[0])
		_lop.append([k, k.position.x, r])
		if k != san_node and absf(r - 1.0) < 0.001:
			mep = maxf(mep, k.position.x + k.size.x * k.scale.x - lech_san)
			mep_trai = minf(mep_trai, k.position.x - lech_san)
	# San THAT: mep cua cac dai mat dat. Chi ghi de khi THUC SU co dai nao rong
	# hon 0 — bo cuc khong co mat dat thi giu du phong cua `_dat_khung`.
	if mep > 0.0 and mep_trai < INF:
		_trai = mep_trai
		_phai = mep
	# Camera troi duoc bao xa: het san tru di mot KHUNG NHIN (khong phai tru
	# `_phai` — hai so do bang nhau chi khi khung nhin rong bang ca san).
	_cam_max = maxf(0.0, mep - _man)


## Camera bam quan ta. SO la cua ban goc (muc <camera> cua
## map/global_config.xml, don vi o), CACH dung so la DAT — luat that nam trong
## lop C++ CDFCamera, chua giai:
##   * dich: giu quan ta di dau o CAM_NGUONG be ngang man;
##   * chay CAM_TOC o/giay; lech hon CAM_DUOI o thi nhanh len theo ti le, con
##     duoi CAM_CHAM_RA o thi cham dan; tu dung yen thi tang toc trong
##     CAM_CHAM_VAO giay.
## Chi la HINH: khong dung toi mo phong, nen chay theo dt that cua khung.
func _buoc_camera(dt: float) -> void:
	if _cam_dung or _lop.is_empty():
		return
	var dau := -INF
	for u in _doi[0]:
		if u.alive():
			dau = maxf(dau, u.sx)
	if dau != -INF:
		_bam_toi(dau, dt)


func _bam_toi(dau: float, dt: float) -> void:
	var dich := clampf(dau - _trai - CAM_NGUONG * _man, 0.0, _cam_max)
	var lech := dich - _cam
	var kc := absf(lech) / O_PX
	if kc < 0.005:
		_cam_toc = 0.0
		return
	var toc := CAM_TOC
	if kc > CAM_DUOI:
		toc *= kc / CAM_DUOI
	elif kc < CAM_CHAM_RA:
		toc *= maxf(0.1, kc / CAM_CHAM_RA)
	_cam_toc = minf(toc, _cam_toc + CAM_TOC * dt / CAM_CHAM_VAO)
	_cam += signf(lech) * minf(absf(lech), _cam_toc * O_PX * dt)
	_ap_camera()


## CCParallaxNode: con troi theo camera nhan he so cua no. g_BattleField he
## so 1 nen quan (con cua nut nay) di dung theo mat dat gb1.
func _ap_camera() -> void:
	for l in _lop:
		var c: Control = l[0]
		if is_instance_valid(c):
			c.position.x = float(l[1]) - float(l[2]) * _cam


## Kich ban goi g_BattleField:StopCamera() (plot/drama_L_N_01_03.lua:113).
func dung_camera() -> void:
	_cam_dung = true


## Lia camera theo KICH BAN (CameraMoveBy(huong, giay)): dung bam quan roi dich
## camera sang huong (+1 phai, -1 trai) nua man. Chi la HINH cho canh dien anh;
## khong dung toi mo phong. DAT: bien do (nua be ngang man) la ta dat.
func lia_camera(huong: float) -> void:
	_cam_dung = true
	_cam = clampf(_cam + signf(huong) * _man * 0.5, 0.0, _cam_max)
	_ap_camera()


## Cho camera bam quan tro lai (StartGame sau canh dien anh).
func theo_lai() -> void:
	_cam_dung = false


## Thu phong camera, giu MOT DIEM tren man hinh dung yen.
##
## Kich ban goi `SetCameraScale(giay, ?, ty_le, x, y)` — nam tham so, doc ra tu
## chinh cho goi (plot/drama_L_XSGK.lua:199) va chu thich cua ban goc ngay tren
## no: "镜头特写孙尚香" (lay can nhan vat). Tuc tham so 3 la TY LE va (4, 5) la
## DIEM TAM theo toa do man hinh — kich ban tinh x bang
## `screenWidth * <o dung> * 0.01`.
##
## That: ty le, diem tam VA thoi gian. Ham engine 0x366c7c doc ra nhu sau:
##   a1 = giay; a3 = ty le (nhan voi ty le nen o `this[0x1c4]`);
##   (a4, a5) = diem tam, chi dat khi khac nil; a6 = tham so phu.
##   `if a1 <= 0.001` -> dat ty le NGAY (0x366cf2); nguoc lai dung
##   CCScaleTo chay dan trong a1 giay (0x366ca8..).
## Ca bon cho goi deu truyen 0.5 giay nen ban goc CHAY DAN, khong ap ngay.
##
## Tham so 2: la mot SO THUC, dua qua 0x4a9040 — ham do cap phat mot doi tuong
## 0x30 byte, ghi tham so vao +0x24 va thay 0 bang 0x34000000 = FLT_EPSILON.
## Do dung la than `CCActionInterval::initWithDuration` cua Cocos2d-x, nen tham
## so 2 la mot KHOANG THOI GIAN nua boc ngoai phep thu phong. Ca bon cho goi
## deu truyen 0 nen khong doi hanh vi — ghi lai chu khong doan them.
## Ty le dang dung. 1 = khong phong.
##
## Khong dung Tween: node san tran nam NGOAI cay canh (bo do chay headless cho
## thay "ngoai-cay"), ma Tween thi doi node o trong cay. Chay dan bang chinh
## buoc khung cua san tran, giong moi thu khac o day.
var _thu_phong := 1.0
var _phong_dich := 1.0          ## ty le muc tieu khi dang chay dan
var _phong_vi_tri := Vector2.ZERO
var _phong_tu := 1.0            ## ty le luc bat dau chay
var _phong_tu_vi_tri := Vector2.ZERO
var _phong_con := 0.0           ## con lai bao nhieu giay
var _phong_tong := 0.0

func dat_thu_phong(ty_le: float, tam_x: float = INF, tam_y: float = 0.0,
		giay: float = 0.0) -> void:
	var t := clampf(ty_le, 0.2, 4.0)
	if absf(t - _phong_dich) < 0.001:
		return
	# Giu diem tam dung yen: trong he toa do CHA, diem do phai ra cung mot cho
	# truoc va sau khi doi ty le.
	var tam := Vector2(tam_x, tam_y)
	if tam_x == INF:
		tam = Vector2((_trai + _phai) * 0.5 * _thu_phong + position.x, position.y)
	var vi_tri := tam - (tam - position) * (t / maxf(_thu_phong, 0.001))
	_phong_dich = t
	# Nguong 0.001 giay la cua ban goc (0x366c9a so `giay` voi hang so 0.001).
	if giay <= 0.001:
		_phong_con = 0.0
		position = vi_tri
		scale = Vector2(t, t)
		_thu_phong = t
		return
	_phong_tu = _thu_phong
	_phong_tu_vi_tri = position
	_phong_vi_tri = vi_tri
	_phong_tong = giay
	_phong_con = giay


## Mot buoc cua phep thu phong dang chay dan. Goi tu `buoc()`.
func _buoc_thu_phong(dt: float) -> void:
	if _phong_con <= 0.0:
		return
	_phong_con = maxf(0.0, _phong_con - dt)
	var k := 1.0 - _phong_con / maxf(_phong_tong, 0.001)
	_thu_phong = lerpf(_phong_tu, _phong_dich, k)
	position = _phong_tu_vi_tri.lerp(_phong_vi_tri, k)
	scale = Vector2(_thu_phong, _thu_phong)


## Ty le thu phong dang dung (de phep kiem doc lai).
func thu_phong() -> float:
	return _thu_phong


## "<muc tieu> <ty le THAT cua node>" — phep kiem doc de phan biet "ap ngay"
## voi "chay dan": chay dan thi node chua toi muc tieu ngay sau loi goi.
func do_thu_phong() -> String:
	return "%.4f %.4f %s" % [_phong_dich, scale.x,
			"dan" if _phong_con > 0.0 else "ngay"]


## So do CHO DAT cua toan linh vua bam nut: MOC CUA TOAN doc tu `Sprite.Troop.PosX`
## cua du lieu tran (o, roi ra px) — tuc cho dung CUA TOAN theo du lieu goc, va x
## cua tung nguoi vua ra (px so voi o 0 cua san) — cong goc san.
## Hai so nay CO Y khac nhau, va ca hai deu la SO DO: `moc` la neo ma `dua_linh`
## dung (tu 2026-09-20 — truoc la o 0), con x tung nguoi luon NHO HON moc vi luoi
## cua ta lui dan ve sau (fArmySpace 110 px, SKEW_X 46 px). Do 2026-09-20 tren
## `L_N_01_01`: `moc 7.00 o = 700 px | goc 0` va bon nguoi vua ra o 498/480/434/388
## — dung 700 tru 202/220/266/312.
## Ham cua CONG CU DO, khong phai ham cua ban goc.
func do_cho_dat() -> String:
	var ds := PackedStringArray()
	for i in range(maxi(0, _dau.size() - _ra_cuoi), _dau.size()):
		ds.append("%s@%.0f" % [_dau[i][0], float(_dau[i][1])])
	return "moc %.2f o = %.0f px | goc %.0f | %d nguoi vua ra: %s" % [
			_moc_toan, _moc_toan * _o, _goc_x, _ra_cuoi, ", ".join(ds)]


## Do: camera, gioi han, va moi lop da troi bao xa so voi goc.
func camera() -> String:
	var ds := PackedStringArray()
	for l in _lop:
		var c: Control = l[0]
		if is_instance_valid(c):
			ds.append("%s:%.2f/%.0f" % [String(c.get_meta("cls", c.name)), float(l[2]),
					float(l[1]) - c.position.x])
	return "cam %.0f max %.0f dung %s | %s" % [_cam, _cam_max, _cam_dung, " ".join(ds)]


## CHI DE KIEM (tools/do_chien_dich.gd), khong phai ham cua ban goc: cho camera
## bam mot quan dau GIA dung o `dau_x` trong `giay` giay (buoc 1/30), tra
## camera(). Kiem gioi han va he so parallax ma khong phu thuoc can can tran —
## o L_N_01_01 quan ta co the chet truoc khi di qua 0,8 be ngang man.
func _thu_camera(dau_x: float, giay: float) -> String:
	for i in int(giay * 30.0):
		_bam_toi(dau_x, 1.0 / 30.0)
	return camera()


## --------------------------------------------------- canh dien anh (kich ban)
##
## Cac lenh duoi day la API THAT cua `g_DramaSystem` — doc ra tu 56 file
## `sc/plot/drama_*.lua` (so tham so va thu tu lay tu chinh cho goi). Ban goc
## lam chung trong C++; o day lam bang SngRig + node cua san tran.
##
## THAT: ten lenh, chu ky, ten armature / dong tac / mat (bien the `Face_*` cua
## armature `Face`), toa do tinh bang O.
## DAT: toc do di chuyen khi kich ban khong noi, kieu noi suy cua lop phu mau,
## bien do rung man.
const BONG_BONG_Y := -96.0   ## tren dau: rig lay goc o chan, nguoi cao ~90

## Doi dang cho "di toi roi dien": u -> [dich_x, dich_y, dong tac khi toi].
var _di_dien := {}
## Hieu ung / bong bong / lenh cho: [node, con lai bao nhieu giay, viec sau].
var _hieu_ung: Array = []
var _phu: ColorRect = null
var _phu_tu := 0.0
var _phu_den := 0.0
var _phu_con := 0.0
var _phu_tong := 0.0
var _rung_con := 0.0
var _rung_bien := 0.0
var _rung_goc_y := INF


## Tim cac don vi khop ten armature ben `doi` (khop chinh xac truoc).
func _tim_hinh(ten: String, doi: int) -> Array:
	var ds: Array = []
	if ten == "":
		return ds
	for chinh_xac in [true, false]:
		for u in _doi[clampi(doi, 0, 1)]:
			if u.alive() and _khop_hinh(_muc[u], ten, chinh_xac):
				ds.append(u)
		if not ds.is_empty():
			return ds
	return ds


## Dong tac KET THUC don vi: kich ban dung chung de cho mot hinh chet / bien
## mat, khong phai de dien roi van dung day. O ai 1, LvBuEvil bi ha bang dung
## chuoi nay ("ScriptXiaGuiLoop" -> "Disappear" -> di roi "Death") chu KHONG
## phai bang sat thuong — nen phai rut no khoi san, khong thi tran khong xong.
const DONG_TAC_HET := ["Death", "Disappear"]


static func _la_dong_tac_het(action: String) -> bool:
	return action in DONG_TAC_HET


## DoAction(sprite, side, action [, giay, action2]) — dien mot dong tac; co
## `action2` thi sau `giay` giay doi sang dong tac do.
func dien_dong_tac(ten: String, doi: int, action: String, giay: float = 0.0,
		action2: String = "") -> int:
	var ds := _tim_hinh(ten, doi)
	for u in ds:
		u._play_lai(action)
		if action2 != "" and giay > 0.0:
			_hieu_ung.append([u, giay, action2])
		elif _la_dong_tac_het(action):
			# Cho dien het roi moi rut, khong bien mat dot ngot.
			_hieu_ung.append([u, 1.0, "@rut"])
	return ds.size()


## MoveThenDoAction(sprite, side, tuyet_doi, action_di, x, y, action_toi).
## `x`, `y` tinh bang O nhu moi toa do khac cua kich ban (PosX/PosY,
## PlayEffectInMap). `tuyet_doi` false/0 = doi CHO so voi cho dang dung.
func di_roi_dien(ten: String, doi: int, tuyet_doi, action_di: String,
		x: float, y: float, action_toi: String) -> int:
	var ds := _tim_hinh(ten, doi)
	var td := true
	if typeof(tuyet_doi) == TYPE_BOOL:
		td = bool(tuyet_doi)
	elif typeof(tuyet_doi) == TYPE_INT or typeof(tuyet_doi) == TYPE_FLOAT:
		td = float(tuyet_doi) != 0.0
	for u in ds:
		var dx: float = (_goc_x + x * _o) if td else (u.sx + x * _o)
		var dy: float = (_mat_dat - DOAN_LEN - LAN_LECH - y * LAN_CACH) if td 				else (u.sy - y * LAN_CACH)
		_di_dien[u] = [dx, dy, action_toi]
		if action_di != "":
			u._play_lai(action_di)
	return ds.size()


## Mot buoc cua "di toi roi dien". Toc do lay tu chinh don vi (MoveRef).
func _buoc_di_dien(dt: float) -> void:
	for u in _di_dien.keys():
		if not is_instance_valid(u) or not u.alive():
			_di_dien.erase(u)
			continue
		var d: Array = _di_dien[u]
		var toi := Vector2(float(d[0]), float(d[1]))
		var cho := Vector2(u.sx, u.sy)
		var v := maxf(60.0, u.speed) * dt
		if cho.distance_to(toi) <= v:
			u.sx = toi.x
			u.sy = toi.y
			u.position = toi
			var dt2 := String(d[2])
			u._play_lai(dt2)
			_di_dien.erase(u)
			if _la_dong_tac_het(dt2):
				_hieu_ung.append([u, 1.0, "@rut"])
		else:
			var b := cho + (toi - cho).normalized() * v
			u.sx = b.x
			u.sy = b.y
			u.position = b


## SetReversal(sprite, side) — lat huong nhin cua hinh.
func lat_hinh(ten: String, doi: int) -> int:
	var ds := _tim_hinh(ten, doi)
	for u in ds:
		u.facing = -u.facing
		if u.rig != null:
			u.rig.scale.x = -u.rig.scale.x
	return ds.size()


## PlayEffectInMap(ten, o_x, o_y [, action] [, lap]) — chay mot armature hieu
## ung tai o (o_x, o_y). `ten` la BIEN THE (vd "DramaDialog_SmokeWhite" thuoc
## armature "DramaDialog"); `_thu_muc_rig` tu lan ra armature goc.
##
## `giay <= 0` = "de dong tac tu quyet": lay thoi luong cua chinh dong tac vua
## chay (`SngRig.thoi_luong`). Hieu ung thuc tinh dai ngan khac nhau (vong tron
## CaiWenJi 3 dong tac, chu ZhaoYun 19 khung), nen mot con so cung cho tat ca
## hoac la cat ngang hoac la de mot xac rig nam tren san. Ba cho goi cu deu
## truyen so duong nen khong doi hanh vi nao.
func hieu_ung_tai_o(ten: String, o_x: float, o_y: float, action: String = "PluginPlay",
		giay: float = 3.0) -> bool:
	var r := _thu_muc_rig(ten)
	if r[0] == "":
		return false
	# Ten khong phai la mot BIEN THE ma la chinh THU MUC (vd `CaiWenJiCircle`):
	# `_bien_the_cho` se tra ve `_richest_variant()`, ma "nhieu dong tac nhat"
	# khong phai "nhom hieu ung" — do 2026-09-21: no chon nhom
	# `Born/Death/Standby`, tuc mot con vong tron KHONG chay gi. Chi doi khi
	# nguoi goi KHONG chi dinh dong tac: co chi dinh roi thi ten bien the la y
	# cua nguoi goi.
	if action == "":
		r = _thu_muc_hieu_ung(ten)
	# `chinh_xac = true`: HIEU UNG khong duoc phep lui ve nhom nhieu dong tac nhat.
	# Do 2026-09-21 tren 56 ten thuc tinh cua `wake_ref.json`: 6 ten khong co art
	# rieng bi phep lui ay ve ra THAN cua chinh tuong do — mot bong tuong thu hai
	# moc len giua san, va phep dem van ghi la "ve duoc". Tra null -> nguoi goi
	# dem vao `thieu-art:<ten>` (xem `_phat_hieu_ung`).
	var rig := SngRig.build(r[0], r[1], true, true)
	if rig == null:
		return false
	rig.position = Vector2(_goc_x + o_x * _o,
			_mat_dat - DOAN_LEN - LAN_LECH - o_y * LAN_CACH)
	add_child(rig)
	var dong := action
	if dong == "":
		dong = _dong_tac_cua(rig)
		if dong == "":
			# Dung lai mot rig KHONG chay dong tac nao thi no nam im giua san —
			# dung cai bay ma `_phat_hieu_ung` da phai chan. Tra false de nguoi
			# goi dem vao `khong-dung-duoc:<ten>`.
			# Do NGAY (`remove_child` + `free`) chu khong `queue_free`: xoa hoan
			# lai thi con mot khung nua no van la con cua nut tran, va phep dem
			# "co de lai rig nao khong" doc ra sai.
			remove_child(rig)
			rig.free()
			return false
	if dong != "":
		rig.play(dong)
	var cho := giay
	if cho <= 0.0:
		cho = rig.thoi_luong(dong)
	_hieu_ung.append([rig, maxf(0.2, cho), ""])
	return true


## Dong tac cua mot armature HIEN TUONG khi nguoi goi khong chi dinh ten dong
## tac (`action = ""`). `PluginPlay` truoc — do 2026-09-21 tren 22 ten thuc tinh
## tra ra duoc: 20 chay `PluginPlay` — roi moi den bo `Wake*` (2 ten cua
## `sWakeEffect`: `SunLuBan_WakeEffect`, `SiMaYi_WakeEffect`).
static func _dong_tac_cua(rig: SngRig) -> String:
	var ds := rig.animations()
	if ds.has("PluginPlay"):
		return "PluginPlay"
	for a in ds:
		if String(a).begins_with("Wake"):
			return String(a)
	return ""


## PlayEffectThenDisappear(hieu_ung, sprite, side, ?, giay) — chay hieu ung len
## hinh roi RUT hinh do khoi san.
func hieu_ung_roi_rut(ten_hieu_ung: String, ten: String, doi: int, giay: float) -> int:
	var ds := _tim_hinh(ten, doi)
	for u in ds:
		if ten_hieu_ung != "":
			hieu_ung_tai_o(ten_hieu_ung, (u.sx - _goc_x) / _o, 0.0, "PluginPlay", giay)
		_hieu_ung.append([u, maxf(0.0, giay), "@rut"])
	return ds.size()


## Sinh hieu ung cua don THUC TINH — cac armature ma 14 truong `s*` nhom SINH
## HIEN cua khoi `fight_<X>Wake` tro toi (xem `battle/wake_ref.gd`). Tra so
## armature dung duoc.
##
## VI SAO PHAI CO HAM NAY: `tuyet_chieu` chi goi `u._play_lai(action)` — tuc la
## chi doi dong tac cua CHINH tuong. Do tren 23 ten rieng cua nhom do: 22 tra ra
## duoc armature THAT (vong tron CaiWenJi, chu ZhaoYun, khien SuperThunderDragon,
## hieu ung trung SiMaYi...) va **khong duong nao khac cham toi chung**. Thieu
## ham nay thi mot lan tuyet chieu chi la mot lan doi tu the.
##
## Do dai: `giay = 0` = de chinh dong tac quyet (xem `hieu_ung_tai_o`) — cac
## hieu ung nay dai ngan rat khac nhau (vong tron CaiWenJi 3 dong tac, chu
## ZhaoYun 19 khung), mot con so cung cho tat ca thi hoac cat ngang hoac de mot
## xac rig nam tren san.
func hieu_ung_thuc_tinh(ten_hinh: String, u: BattleUnit) -> int:
	if u == null or not u.visual:
		# Che do khong dung anh (`--sim`): cung loi `_phat_hieu_ung` — VAN dem
		# vao so im, de `ve` + `im` luon bang so lan chieu that.
		_so_tt_im += 1
		_ly_do_tt["khong-ve-hinh"] = int(_ly_do_tt.get("khong-ve-hinh", 0)) + 1
		return 0
	var ds := WakeRef.hieu_ung(ten_hinh)
	if ds.is_empty():
		# KHONG co dong nao trong bang cho tuong nay — ban goc khong co khoi
		# `fight_<X>Wake` nao trong `map/*_config.xml`. VAN phai dem va GOI TEN
		# ra: mot tuong thuc tinh ma khong co hieu ung nao se di qua hoan toan
		# im lang, dung loai loi ma `CLAUDE.md` goi la loi im. Do 2026-09-21:
		# nhan vat chinh (`Player000M03W`) la mot ten nhu vay — ban VN 1.26 chi
		# co `fight_Player000W03WWake` / `fight_Player002W03WWake` /
		# `fight_Player00003Wake` / `fight_Player03Wake`, khong co `M03W`.
		_so_tt_im += 1
		var lt := "khong-co-bang:" + ten_hinh
		_ly_do_tt[lt] = int(_ly_do_tt.get(lt, 0)) + 1
		return 0
	var o_x := (u.sx - _goc_x) / _o
	var n := 0
	for cap in ds:
		var ten := String(cap[1])
		if hieu_ung_tai_o(ten, o_x, 0.0, "", 0.0):
			n += 1
			_so_tt_ve += 1
		else:
			# Hai nguyen nhan roi han nhau, va CA HAI deu la su that do duoc:
			# `SngRig.tim_thu_muc` khong tra ra thu muc nao, hay co thu muc ma
			# khong dung duoc rig (khong bien the nao co dong tac, hoac khong
			# co dong tac hieu ung nao). Ten armature la thu can sua nen ghi kem.
			_so_tt_im += 1
			var ld := ("khong-tra-thu-muc:" if WakeRef.tra_thu_muc(ten) == ""
					else "khong-dung-duoc:")
			ld += ten
			_ly_do_tt[ld] = int(_ly_do_tt.get(ld, 0)) + 1
	return n


## AddPhiz(sprite, side, mat, giay) — bong bong bieu cam tren dau. `mat` la bien
## the cua armature `Face` (vd "Face_ShengQi"), dong tac "PluginPlay" — doc tu
## chinh assets_ref/Face/Face.json.
func bong_bong(ten: String, doi: int, mat: String, giay: float = 0.0) -> int:
	var ds := _tim_hinh(ten, doi)
	if ds.is_empty() or mat == "":
		return 0
	var n := 0
	for u in ds:
		# `chinh_xac = true`: `mat` la mot mat bieu cam, khong phai mot nhan vat —
		# khong co mat do thi dung ve mat khac. Ca 13 nhom cua `Face.json` deu la
		# `Face_*`, va moi cho goi `AddPhiz` trong `sc/plot/` deu goi ten nhom that.
		var rig := SngRig.build("res://assets_ref/Face", mat, true, true)
		if rig == null:
			continue
		rig.position = Vector2(0, BONG_BONG_Y)
		u.add_child(rig)
		rig.play("PluginPlay")
		_hieu_ung.append([rig, maxf(1.0, giay + 2.0), ""])
		n += 1
	return n


## RunShakyByLevel(muc, giay, ?) va SetVibration(bat) — rung man hinh.
## DAT: bien do 3 px moi muc; ban goc de trong C++ (CDFCamera).
func rung_man(muc: float, giay: float) -> void:
	if _rung_goc_y == INF:
		_rung_goc_y = position.y
	_rung_bien = maxf(1.0, muc) * 3.0
	_rung_con = maxf(0.05, giay)


func _buoc_rung(dt: float) -> void:
	if _rung_con <= 0.0:
		return
	_rung_con -= dt
	if _rung_con <= 0.0:
		position.y = _rung_goc_y
		return
	position.y = _rung_goc_y + (_rng.randf() * 2.0 - 1.0) * _rung_bien


## ColorLayerFadeIn / FadeOut / FadeTo va SetBattleBlackLayerFadeOut: lop phu
## mau tren toan san. `mau` 0 = den, 1 = trang — doc tu cho goi (FadeIn(1, 0.3)
## dung cho chop trang, FadeIn(0, 0.3) cho toi man).
func phu_mau(mau: int, giay: float, den_alpha: float) -> void:
	if not is_instance_valid(_phu):
		_phu = ColorRect.new()
		_phu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_phu.size = Vector2(maxf(_phai - _trai, 1280.0) * 4.0, 2048.0)
		_phu.position = Vector2(_trai - (_phai - _trai) * 1.5, _mat_dat - 1600.0)
		_phu.z_index = 900
		_phu.color = Color(0, 0, 0, 0)
		add_child(_phu)
	var a := _phu.color.a
	_phu.color = Color(1, 1, 1, a) if mau == 1 else Color(0, 0, 0, a)
	_phu_tu = a
	_phu_den = clampf(den_alpha, 0.0, 1.0)
	_phu_tong = maxf(0.001, giay)
	_phu_con = _phu_tong


func _buoc_phu(dt: float) -> void:
	if _phu_con <= 0.0 or not is_instance_valid(_phu):
		return
	_phu_con = maxf(0.0, _phu_con - dt)
	var k := 1.0 - _phu_con / _phu_tong
	_phu.color.a = lerpf(_phu_tu, _phu_den, k)


## Dem nguoc cac hieu ung / bong bong / lenh cho roi don.
func _buoc_hieu_ung(dt: float) -> void:
	for i in range(_hieu_ung.size() - 1, -1, -1):
		var h: Array = _hieu_ung[i]
		h[1] = float(h[1]) - dt
		if float(h[1]) > 0.0:
			continue
		_hieu_ung.remove_at(i)
		var n = h[0]
		if not is_instance_valid(n):
			continue
		var sau := String(h[2])
		if sau == "@rut":
			var u := n as BattleUnit
			u.fighter.hp = 0.0
			u.die()
		elif sau != "":
			(n as BattleUnit)._play_lai(sau)
		else:
			n.queue_free()


## Do canh dien anh: bao nhieu don vi dang di, bao nhieu hieu ung dang song,
## alpha lop phu, rung con bao lau.
func do_dien_anh() -> String:
	return "di %d hieu_ung %d phu %.2f rung %.2f" % [_di_dien.size(), _hieu_ung.size(),
			_phu.color.a if is_instance_valid(_phu) else 0.0, _rung_con]


## ---------------------------------------------------------------- minimap
##
## Ban goc KHONG ve minimap trong Lua: client chi tra ve NUT
## (`CUIGame:getMinimap()` -> `ChapterBattle:GetMinimapObj()`, nut tag 107 ->
## con tag 104 cua bo cuc tran), con cham thi engine C++ ve vao do. Bo cuc goc
## cho nut do la dai 510x40 dat o goc tren-phai — do duoc luc chay
## (`do_chien_dich --kiem` in ra "board 40x50 @(480,585) | layer 510x40").
##
## Ta ve cham vao DUNG nut do. THAT: nut, kich thuoc, cho dat — cua ban goc.
## DAT: hinh dang cham (o vuong), mau, va viec co khung ngam camera — luat that
## nam trong C++, chua giai.
const MM_CHAM := 4.0        ## canh o vuong mot quan
const MM_CHAM_TUONG := 7.0  ## tuong / boss to hon cho de thay
var _minimap: Control = null
var _mm_cham: Array[ColorRect] = []
var _mm_khung: ColorRect = null


## Nhan nut minimap cua bo cuc goc. `nut` la Control (lua/san_tran.lua dua qua
## `C.raw`). Truyen null de thoi ve.
func dat_minimap(nut) -> void:
	for c in _mm_cham:
		if is_instance_valid(c):
			c.queue_free()
	_mm_cham.clear()
	if is_instance_valid(_mm_khung):
		_mm_khung.queue_free()
	_mm_khung = null
	_minimap = nut as Control


## Be ngang THAT cua man do: ca be ngang SAN (khong phai be ngang khung nhin).
## Truoc 2026-09-21 cho nay viet `(_phai + _cam_max) - _trai`, va no ra dung 4096
## chi vi `_phai` khi ay la be ngang khung nhin con `_cam_max` bu lai — mot dang
## thuc dung nho hai loi bu nhau. Nay moi so noi y that cua no.
func _mm_rong_the_gioi() -> float:
	return maxf(1.0, _phai - _trai)


func _ve_minimap() -> void:
	if not is_instance_valid(_minimap):
		return
	var w: float = _minimap.size.x
	var h: float = _minimap.size.y
	if w <= 1.0 or h <= 1.0:
		return
	var span := _mm_rong_the_gioi()
	var n := 0
	for d in 2:
		for u in _doi[d]:
			if not u.alive():
				continue
			var e: Dictionary = _muc[u]
			var tuong: bool = bool(e.get("tuong", false))
			var c := _mm_lay(n)
			n += 1
			var canh := MM_CHAM_TUONG if tuong else MM_CHAM
			c.size = Vector2(canh, canh)
			# Quan ta xanh, dich do; tuong sang hon.
			if d == 0:
				c.color = Color(0.45, 0.85, 1.0) if tuong else Color(0.20, 0.55, 0.95)
			else:
				c.color = Color(1.0, 0.75, 0.35) if tuong else Color(0.90, 0.25, 0.20)
			var x := clampf((u.sx - _trai) / span, 0.0, 1.0) * (w - canh)
			# Ba lan trai ra het chieu cao dai: lan 0 o giua, lan 1/2 lech dan.
			var lan := float(int(e.get("lan", 0)))
			var y := (h - canh) * 0.5 + lan * (h - canh) * 0.25
			c.position = Vector2(x, clampf(y, 0.0, h - canh))
			c.visible = true
	for i in range(n, _mm_cham.size()):
		_mm_cham[i].visible = false
	_mm_ve_khung(w, h, span)


## Khung ngam: phan san dang hien tren man hinh.
func _mm_ve_khung(w: float, h: float, span: float) -> void:
	if not is_instance_valid(_mm_khung):
		_mm_khung = ColorRect.new()
		_mm_khung.color = Color(1, 1, 1, 0.18)
		_mm_khung.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap.add_child(_mm_khung)
	var be := _man / span * w
	_mm_khung.size = Vector2(maxf(4.0, be), h)
	_mm_khung.position = Vector2(clampf(_cam / span, 0.0, 1.0) * (w - _mm_khung.size.x), 0.0)


func _mm_lay(i: int) -> ColorRect:
	while _mm_cham.size() <= i:
		var c := ColorRect.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap.add_child(c)
		_mm_cham.append(c)
	return _mm_cham[i]


## Do minimap: co nut khong, bao nhieu cham dang hien, khung ngam rong bao
## nhieu phan tram dai.
func do_minimap() -> String:
	if not is_instance_valid(_minimap):
		return "khong co nut"
	var hien := 0
	for c in _mm_cham:
		if c.visible:
			hien += 1
	var k := 0.0
	if is_instance_valid(_mm_khung) and _minimap.size.x > 0.0:
		k = 100.0 * _mm_khung.size.x / _minimap.size.x
	return "nut %.0fx%.0f cham %d/%d khung %.0f%%" % [_minimap.size.x, _minimap.size.y,
			hien, _mm_cham.size(), k]


## Hinh hoc cua san, de do: mep, be rong o, mat dat, cho dung LUC BAT DAU.
func khung() -> String:
	var ds := PackedStringArray()
	for u in _dau:
		ds.append("%s@(%.0f,%.0f)" % [u[0], u[1], u[2]])
	return "trai %.0f phai %.0f man %.0f cam_max %.0f o %.1f mat_dat %.0f | %s" % [_trai,
			_phai, _man, _cam_max, _o, _mat_dat, " ".join(ds)]


## Moi quan: ten armature, bien the that su dung, vi tri tren man (toa do cua
## san khau), con song khong — de do xem hinh nao dung o dau.
func ds_quan() -> String:
	var bd := LuaRuntime._bien_doi(self)
	var ds := PackedStringArray()
	for d in 2:
		for u in _doi[d]:
			var e: Dictionary = _muc[u]
			var p: Vector2 = bd * Vector2(u.sx, u.sy)
			ds.append("%s/%s[%s]@(%.0f,%.0f)%s" % ["T" if d == 0 else "D", e["ten"],
					u.rig.variant if u.rig != null else "-", p.x, p.y, "" if u.alive() else " chet"])
	return " ".join(ds)


func so_quan() -> int:
	return _doi[0].size() + _doi[1].size()


## Ten armature khong tim thay du lieu, ngan cach bang dau phay.
func thieu_rig() -> String:
	return ",".join(PackedStringArray(_thieu_rig.keys()))


## Tieng TRUNG DON cua ban goc, hoac im neu khong tra duoc.
##
## Ba manh ghep lai: loai VU KHI cua ben danh (`kitMaterial` theo armature +
## dong tac + so thu tu cu danh), loai GIAP cua ben chiu (`armorMaterial` theo
## armature), roi tra bang `events` theo khoa "<kit>_<giap>_<do manh>". Bang goc
## va luat ghep: xem game/tieng_dong.gd.
##
## `do_manh` la DAT, va day la cho phai noi ro: bang goc KHONG ghi no o dau ca —
## do tren 226 cu danh, the `<strike>` chi mang `index` va `kitMaterial`, con
## 1 (nhe) hay 2 (nang) la engine C++ quyet dinh luc chay. Ta lay don KY NANG
## lam "nang": do la phep chia DUY NHAT ma mo hinh tran cua ta co.
##
## Nhieu don vi IM, va do la su that cua du lieu chu khong phai loi noi: ten linh
## trong du lieu tran la armature THAN (Archer, SpearmenN), con vu khi la
## armature RIENG (ArcherN_Weapon_Normal) chi `dung_lai` moi noi toi. Do tren
## `data_ref/battle_data.json`: 10/37 ten linh va 31/71 ten tuong tra duoc; rieng
## cung ten thi khoa `3_3_*` (giap THIT) tro toi `Impact_Archery_Flesh_*` ma hai
## tieng do khong co subsound trong bank nao — xem BANK.md.
##
## Bon nguyen nhan im, do bang `dem_tieng` chu khong doan: `khong-co-danh` (bang
## goc khong co armature do), `tay-khong` (co danh nhung `kitMaterial = 0`, 10 cu
## danh), `khong-co-giap` (ben chiu khong co trong bang giap), `khong-co-su-kien`
## (cap vu khi/giap do khong co khoa — 56/80 khoa thieu), va `thieu-trong-bank`
## (tra duoc `event:/...` ma bank khong co tieng, ca dang do la `3_3_*`).
##
## Ai im thi ghi kem TEN armature, vi do moi la thu can sua. Do tren mot tran
## chien dich tron (`do_chien_dich --kiem`): 145 don, 51 co tieng, 94 im — TAT CA
## deu la `khong-co-danh`, chia ra `Archer_VampirE` 89 va `Player000W03W` 5.
## Kiem lai thi thay khong phai loi cua lop nay: `hit_config.xml` co 40 ten bien
## the (`*_VampirE`, `*_Dong`, `*_Boss`, `*_Skeleton`), va **0/40** ten do co mat
## trong `sound_config.xml` lan `danh` — hai bang phia VU KHI cua chinh ban goc
## deu khong biet chung. Ten GOC (bo hau to) thi co: 36/40 trong `sound_config`,
## 20/40 trong `danh`. Nen muon co tieng cho chung thi phai BIA mot luat doi ten
## ma engine C++ chua lo ra — khong lam, theo nguyen tac 1. `Player000W03W` cung
## vay: co trong `sound_config` (nen NO CO tieng hoat dong) nhung khong co trong
## `danh` (nen don danh khong co tieng vu khi).
func _phat_trung_don(u_danh: BattleUnit, u_chiu: BattleUnit, do_manh: int,
		nhan: Dictionary = {}) -> void:
	# SO SAT THUONG NOI — dat TRUOC moi cong ben duoi, vi khong co cong nao
	# dung toi no: tieng phu thuoc bank, hinh phu thuoc art, con so chi phu thuoc
	# bang nhan. `nhan` rong (goi cu) thi khong ve gi — khong nem loi.
	#
	# `sat` la sat thuong THAT da tru, `hoi` la mau ben DANH hut duoc. Hai con so
	# nay ra hai nhan KHAC NHAU va o hai CHO khac nhau (nguoi chiu / nguoi danh),
	# dung nhu hai loai nhan cua ban goc (`Foe`/`Troop`/`Critical` so voi
	# `Increase`).
	if _nhan != null and not nhan.is_empty():
		var sat := float(nhan.get("sat", 0.0))
		if sat > 0.0:
			_nhan.hien(NhanSatThuong.loai_theo_duoi(u_chiu.team,
					bool(nhan.get("crit", false))), sat, u_chiu.sx, u_chiu.sy)
		var hoi := float(nhan.get("hoi", 0.0))
		if hoi > 0.0:
			_nhan.hien(NhanSatThuong.INCREASE, hoi, u_danh.sx, u_danh.sy)
	# HIEU UNG TRUNG DON — cung bang, cung cu danh, cung `kit` voi tieng: khoa
	# `<kit>_0_0` cua khoi `hieu_ung` (`hit_config.xml`), xem `TiengDong.hieu_ung`.
	# Ban goc chay no o tang C++; `hieu_ung_tai_o` chinh la duong `PlayEffectInMap`
	# ma kich ban dung, nen day khong phai duong moi.
	#
	# Dat TRUOC cong `TiengDong.am` ben duoi: cong do la cua TIENG (khong co
	# bank thi khong phat duoc), con hinh thi khong phu thuoc vao bank nao.
	#
	# NOI RO: hieu ung duoc dat TAI CHO NGUOI CHIU don, khong bay tu nguoi danh
	# sang. Duong BAY that (vien dan di giua hai nguoi) nam trong C++ va KHONG co
	# bang du lieu nao mo ta no — `cham_ref.json` chi co mot muc `HitEffect_Shoot`
	# (hop 138x4 px, dong tac PluginPlay) chu khong co quy dao/thoi gian bay. Nen
	# o day chay dung bien the ma bang chi dinh, dung cho ma no dung.
	_phat_hieu_ung(u_danh, u_chiu)
	if TiengDong.am == null:
		return
	_so_don += 1
	var ev := TiengDong.moi().trung_don(
			String(_muc[u_danh].get("hinh", "")), u_danh.dong_tac_dang(), 0,
			String(_muc[u_chiu].get("hinh", "")), do_manh)
	if ev != "" and TiengDong.am.phat(ev) > 0:
		_so_tieng += 1
	else:
		_so_im += 1
		var ld := TiengDong.moi().ly_do
		if ld == "":
			# Tra duoc su kien ma bank khong co tieng: loi o tang bank, khong
			# phai tang bang. Ca dang do la `3_3_*` (xem `dem_tieng`).
			ld = "thieu-trong-bank"
		if ld == "khong-co-danh":
			ld += ":" + String(_muc[u_danh].get("hinh", ""))
		_ly_do_im[ld] = int(_ly_do_im.get(ld, 0)) + 1


## Dem tieng trung don, de `tools/do_chien_dich.gd` bao lai. Khong phai de khoe:
## phan lon don danh IM (xem `_phat_trung_don`), nen con so nay la phep do muc
## phu that cua duong nay. `im_vi_sao` chia so im theo NGUYEN NHAN, de biet cho
## nao la loi cua ta con cho nao la du lieu ban goc thieu.
##
## `hieu_ung` / `hieu_ung_im` la cung phep do ay cho duong HIEU UNG trung don
## (xem `_phat_hieu_ung`): dem rieng vi hai duong co the im vi hai ly do khac
## nhau — tieng tra `<kit>_<giap>_<do manh>`, hieu ung tra `<kit>_0_0`.
func dem_tieng() -> String:
	return JSON.stringify({"don": _so_don, "phat": _so_tieng, "im": _so_im,
			"im_vi_sao": _ly_do_im, "hieu_ung": _so_hieu_ung,
			"hieu_ung_im": _so_hieu_ung_im, "hieu_ung_vi_sao": _ly_do_hu})


## Dem so sat thuong noi — cung loi `dem_tieng()`: `ve` bao nhieu nhan ve duoc,
## `bo` bao nhieu bi TRAN cua ban goc day ra, `im_vi_sao` chia so KHONG ve duoc
## theo nguyen nhan. Mot nhan khong ve duoc KHONG nem loi nao (xem
## `battle/nhan_sat_thuong.gd`), nen thieu kenh do nay thi khong ai biet.
func dem_nhan() -> String:
	if _nhan == null:
		return "{}"
	return _nhan.dem()


## Dem hieu ung THUC TINH — cung loi `dem_tieng()` va `dem_nhan()`: `ve` bao
## nhieu armature dung duoc, `im_vi_sao` chia so KHONG dung duoc theo nguyen
## nhan. Mot armature khong dung duoc khong nem mot dong loi nao, nen thieu
## kenh do nay thi khong ai biet tuyet chieu dang thieu gi.
func dem_thuc_tinh() -> String:
	return JSON.stringify({"ve": _so_tt_ve, "im": _so_tt_im,
			"im_vi_sao": _ly_do_tt})


## Chay hieu ung trung don cua mot cu danh (xem `_phat_trung_don`). Dem ca hai
## chieu: chay duoc bao nhieu, im bao nhieu va vi sao.
func _phat_hieu_ung(u_danh: BattleUnit, u_chiu: BattleUnit) -> void:
	if not u_chiu.visual:
		# Che do khong dung anh (`--sim`, vai phep kiem): don vi khong dung rig
		# nao thi hieu ung cung khong. VAN dem vao so im, de `hieu_ung` +
		# `hieu_ung_im` luon bang so don danh — thieu mot chieu thi con so khong
		# con la phep do.
		_so_hieu_ung_im += 1
		_ly_do_hu["khong-ve-hinh"] = int(_ly_do_hu.get("khong-ve-hinh", 0)) + 1
		return
	var ten := TiengDong.moi().hieu_ung(
			String(_muc[u_danh].get("hinh", "")), u_danh.dong_tac_dang(), 0)
	if ten == "":
		_so_hieu_ung_im += 1
		var ld := TiengDong.moi().ly_do
		if ld == "":
			ld = "khong-ro"
		# Ten armature la thu can sua, nen ghi kem — nhu ben tieng.
		if ld == "khong-co-danh":
			ld += ":" + String(_muc[u_danh].get("hinh", ""))
		_ly_do_hu[ld] = int(_ly_do_hu.get(ld, 0)) + 1
		return
	# Cung cho dat voi `hieu_ung_roi_rut` (o_x theo nguoi chiu, o_y = 0 = duong
	# dat). Bien the `HitEffect_*` deu chi co MOT dong tac `PluginPlay`.
	if hieu_ung_tai_o(ten, (u_chiu.sx - _goc_x) / _o, 0.0, "PluginPlay", 0.8):
		_so_hieu_ung += 1
	else:
		_so_hieu_ung_im += 1
		_ly_do_hu["thieu-art:" + ten] = int(_ly_do_hu.get("thieu-art:" + ten, 0)) + 1


## Thu muc armature cho mot ten — luat nay nay o MOT cho (`SngRig.tim_thu_muc`),
## dung chung voi `LuaRuntime._tao_rig` va `SngRig.theo_ten`. Ba noi tung chep tay
## cung mot vong lap, va do la cach chung lech nhau.
static func _thu_muc_rig(ten: String) -> Array:
	return SngRig.tim_thu_muc(ten)


## Thu muc + bien the de dung mot ten HIEU UNG. `_thu_muc_rig` roi, va khi ten
## khong phai la mot BIEN THE (tra ve rong) thi hoi nhom CO dong tac hieu ung —
## xem `SngRig.bien_the_hieu_ung`. Mot cho dinh nghia: `hieu_ung_tai_o` va
## `tools/verify_thuc_tinh.gd` di cung duong nay, nen con so bo kiem do ra la con
## so cua duong that.
static func _thu_muc_hieu_ung(ten: String) -> Array:
	var r := SngRig.tim_thu_muc(ten)
	if r[0] != "" and r[1] == "":
		r[1] = SngRig.bien_the_hieu_ung(r[0])
	return r
