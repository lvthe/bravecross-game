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
#   * toc do, tam danh toi thieu: cua BattleUnit (chinh cho man 960 px).
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
## SO LAN va KHOANG CACH LAN la cua BAN GOC: muc <camera>/<army> cua
## map/global_config.xml ghi `fLaneWidth = 0.4`, `fLaneOffset = 0.1`; moi hang
## so trong file do deu tinh bang O (vd `fArmyLength = 4`, `fArmySpace = 1.1`,
## `<ptVector>` cua toc do) va 1 o = 100 px, nen 0.4 o = 40 px va 0.1 o = 10 px.
## Ba lan nam gon trong 10 + 2*40 = 90 px < 1 o — khop voi viec chi so lan
## (`Location`) chi nhan 1..3.
## DAT: don vi cua `fLaneWidth`/`fLaneOffset` la O (suy tu chinh file do, chua
## doc duoc cho engine dung hai hang so nay).
const LAN_SO := 3
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
var _trai := 0.0
var _phai := 1429.0
var _o := 48.0
var _mat_dat := -165.0
var _thieu_rig := {}
var _dau: Array = []           ## [ten, x, y] luc ra tran — cho khung()
var _sprite: Dictionary = {}   ## Sprite cua du lieu quan ta: Troop_<n> la linh dua ra duoc
var _so_linh := 0              ## so linh da dua ra (danh so thu tu)
var _so_thuc_tinh := 0         ## so don thuc tinh tuong ta da tung
var _goc_x := 0.0              ## o 0 cua san (g_MapZero), toa do cua nut nay
var _cam := 0.0                ## camera da troi bao nhieu px sang phai
var _cam_max := 0.0
var _cam_toc := 0.0            ## toc do hien tai, o/giay (tang dan luc bat dau)
var _cam_dung := false
var _lop: Array = []           ## [Control, x goc, he so parallax] cua nut parallax cha
var _bang = null               ## BangTuong: khung + thanh mau/no cua tuong ta (goc duoi-trai)


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
	_tao_bang()
	return ""


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


## Mep trai / phai cua san khau va duong mat dat, doi ve toa do cua nut nay.
## Tinh qua LuaRuntime._bien_doi (khong can nam trong cay canh), va lay mep
## theo chinh san khau nen khong phu thuoc ti le thu nho cua cua so.
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
	_phai = (nguoc * (bd_san * Vector2(san.size.x, 0))).x
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
	# the tuong (nguoi choi doi chieu bang anh ban goc).
	u.sy = _mat_dat - DOAN_LEN - LAN_LECH - float(hang) * LAN_CACH
	u.position = Vector2(u.sx, u.sy)
	add_child(u)
	var r := _thu_muc_rig(String(e["ten"]))
	if r[0] == "" and String(e["sprite"]) != "":
		r = _thu_muc_rig(String(e["sprite"]))
	if r[0] == "":
		_thieu_rig[String(e["ten"])] = true
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


## Dua MOT TOAN linh ra tran — nut binh chung cua ban goc (engine goi
## dispatch). Toan gom MaxUnit nguoi dung tu CHI SO THAT cua Sprite[<ten>]
## (vd Troop_1: DefenderN, HP 1000, MaxUnit 4). Tra so nguoi da dua ra.
## DAT: toan xuat hien o mep trai san (o 0); ban goc dua tu dau, chua do.
func dua_linh(ten: String) -> int:
	if _xong:
		return 0
	var cs = _sprite.get(ten, null)
	if not (cs is Dictionary):
		return 0
	var bi = cs.get("BaseInfo", {})
	var n := maxi(1, int(bi.get("MaxUnit", 1))) if bi is Dictionary else 1
	for k in n:
		var e: Dictionary = TRAN_GOC._muc(cs, _rules, int(cs.get("ArmyTypeID", 0)), false,
				0.0, 0.0, _so_linh)
		_so_linh += 1
		_them(e, 0)
	return n


## Them MOT don vi GIUA TRAN theo kich ban (TakeUnitJoinBattle / CreateNpc cua
## g_DramaSystem). `cs` la ban ghi chi so THAT: NPC config (GetNpcConfigWithNpcId)
## cho dong minh nhu Lang Thong / Trieu Van, hoac linh. `ten_hinh` la ten
## armature de ve (Hero_Lingtong...). `doi` 0 = ben ta, 1 = ben dich.
## Nho vay ai co kich ban thang duoc DUNG cach ban goc: dong minh danh cung,
## khong phai chinh so lieu.
func dua_dong_minh(ten_hinh: String, doi: int, cs_json: String) -> bool:
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
	u.sx = (_trai + BIEN) if d == 0 else (_phai - BIEN)
	u.position = Vector2(u.sx, u.sy)
	return true


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
func tuyet_chieu(ten_hinh: String, doi: int, action: String, so_don: int) -> int:
	if _xong or ten_hinh == "":
		return 0
	var full := float(_rules.get("angerFull", 100.0))
	# CHI dong tac KY NANG moi gay sat thuong. `SetRoleChangeFight` con dung de
	# DOI TU THE ("Fight", "Fight20", "Standby"...) — truoc day ta danh AoE cho
	# moi lan goi, nen o ai 1 hai Trieu Van x ba lan goi = 6 lan AoE khong co
	# that. Danh sach lay tu chinh cac cho goi trong sc/plot/drama_*.lua.
	var la_ky_nang := action.begins_with("Wake") or action.begins_with("Talent")
	if la_ky_nang and action.begins_with("Wake"):
		var that := WakeRef.so_don(ten_hinh)
		if that > 0:
			so_don = that
	var n := 0
	for u in _doi[clampi(doi, 0, 1)]:
		if not u.alive() or not _khop_hinh(_muc[u], ten_hinh, false):
			continue
		n += 1
		u._play_lai(action if action != "" else "Wake")
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
				var r: Dictionary = u.fighter.strike(v.fighter, _rng, _rules)
				# strike() da tru mau theo don thuong; buoc them / bot cho dung
				# he so thuc tinh cua ban goc.
				var bu := float(r.get("damage", 0.0)) * (he_so - 1.0)
				v.fighter.hp = maxf(0.0, v.fighter.hp - bu)
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
		var r: Dictionary = p[0].resolve(p[1])
		var e: Dictionary = _muc[p[0]]
		# Don thuc tinh cua tuong ta: dem, va phat dong tac Wake cua armature.
		if r.get("skill", false) and e["tuong"] and p[0].team == 0:
			_so_thuc_tinh += 1
			p[0]._play_lai("Wake")
		if e["tuong"] and p[0].team == 0:
			var key := str(e["id"])
			_sat[key] = float(_sat.get(key, 0.0)) + maxf(0.0, truoc - p[1].fighter.hp)
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
## Be dai san = mep phai xa nhat cua cac lop he so 1 (mat dat gb1_*).
func _tim_lop() -> void:
	_lop.clear()
	var san_node := get_parent()
	var cha: Node = san_node.get_parent() if san_node != null else null
	if not (cha is Control):
		return
	var lech_san := (san_node as Control).position.x if san_node is Control else 0.0
	var mep := 0.0
	for c in cha.get_children():
		if not (c is Control):
			continue
		var k: Control = c
		var r := 1.0
		var p = k.get_meta("parallax", null)
		if p is Array and not (p as Array).is_empty():
			r = float(p[0])
		_lop.append([k, k.position.x, r])
		if k != san_node and absf(r - 1.0) < 0.001:
			mep = maxf(mep, k.position.x + k.size.x * k.scale.x - lech_san)
	_cam_max = maxf(0.0, mep - _phai)


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
	var dich := clampf(dau - _trai - CAM_NGUONG * (_phai - _trai), 0.0, _cam_max)
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
	_cam = clampf(_cam + signf(huong) * (_phai - _trai) * 0.5, 0.0, _cam_max)
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
func hieu_ung_tai_o(ten: String, o_x: float, o_y: float, action: String = "PluginPlay",
		giay: float = 3.0) -> bool:
	var r := _thu_muc_rig(ten)
	if r[0] == "":
		return false
	var rig := SngRig.build(r[0], r[1], true)
	if rig == null:
		return false
	rig.position = Vector2(_goc_x + o_x * _o,
			_mat_dat - DOAN_LEN - LAN_LECH - o_y * LAN_CACH)
	add_child(rig)
	if action != "":
		rig.play(action)
	_hieu_ung.append([rig, maxf(0.2, giay), ""])
	return true


## PlayEffectThenDisappear(hieu_ung, sprite, side, ?, giay) — chay hieu ung len
## hinh roi RUT hinh do khoi san.
func hieu_ung_roi_rut(ten_hieu_ung: String, ten: String, doi: int, giay: float) -> int:
	var ds := _tim_hinh(ten, doi)
	for u in ds:
		if ten_hieu_ung != "":
			hieu_ung_tai_o(ten_hieu_ung, (u.sx - _goc_x) / _o, 0.0, "PluginPlay", giay)
		_hieu_ung.append([u, maxf(0.0, giay), "@rut"])
	return ds.size()


## AddPhiz(sprite, side, mat, giay) — bong bong bieu cam tren dau. `mat` la bien
## the cua armature `Face` (vd "Face_ShengQi"), dong tac "PluginPlay" — doc tu
## chinh assets_ref/Face/Face.json.
func bong_bong(ten: String, doi: int, mat: String, giay: float = 0.0) -> int:
	var ds := _tim_hinh(ten, doi)
	if ds.is_empty() or mat == "":
		return 0
	var n := 0
	for u in ds:
		var rig := SngRig.build("res://assets_ref/Face", mat, true)
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


## Be ngang THAT cua man do: tu mep trai san toi het phan camera con di duoc.
func _mm_rong_the_gioi() -> float:
	return maxf(1.0, (_phai + _cam_max) - _trai)


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
	var be := (_phai - _trai) / span * w
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
	return "trai %.0f phai %.0f o %.1f mat_dat %.0f | %s" % [_trai, _phai, _o, _mat_dat,
			" ".join(ds)]


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


## Thu muc armature cho mot ten — cung luat voi LuaRuntime._tao_rig: trung ten
## thi dung, khong thi thu tien to ngan dan va xin ten day du lam BIEN THE
## ("Player000M03W" -> thu muc Player000, bien the Player000M03W).
static func _thu_muc_rig(ten: String) -> Array:
	if ten == "":
		return ["", ""]
	if FileAccess.file_exists("res://assets_ref/%s/%s.json" % [ten, ten]):
		return ["res://assets_ref/" + ten, ""]
	for i in range(ten.length() - 1, 3, -1):
		var goc := ten.substr(0, i).trim_suffix("_")
		if FileAccess.file_exists("res://assets_ref/%s/%s.json" % [goc, goc]):
			return ["res://assets_ref/" + goc, ten]
	return ["", ""]
