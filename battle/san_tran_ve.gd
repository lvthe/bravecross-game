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
const HANG_SO := 4          ## so hang (chieu ngang doi ngu)
const RANK_Y := 34.0        ## cach hang theo y (nen, doi hinh khoi cao)
const SKEW_X := 46.0        ## hang sau lech ngang -> xep cheo, khoi chong
const RANK_X := 48.0        ## cach cot (chieu sau)
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
	var hang := i % HANG_SO
	var cot := i / HANG_SO
	var lui := -1.0 if doi == 0 else 1.0
	u.sx = _goc_x + px * _o + lui * (float(cot) * RANK_X + float(hang) * SKEW_X)
	# Hang truoc (hang 0) DUNG NGAY tren duong dat g_MapZero, cac hang sau lui
	# LEN (chieu sau san, y am hon) — dung vat ly duong dat, khong day xuong che
	# ca the tuong o goc man. DOAN_LEN nhac ca doi hinh len mot chut cho thoat
	# the tuong (nguoi choi doi chieu bang anh ban goc).
	u.sy = _mat_dat - DOAN_LEN - float(hang) * RANK_Y
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
	u.setup(e["f"], doi, _rules, _rng, r[0], float(e["co"]), r[1])
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
## DAT: so don `so_don` va viec danh KHAP dich la ta dat — hieu ung that nam
## trong C++ (CDFSpriteFight*Wake). Nhung SAT THUONG moi don dung cong thuc va
## chi so THAT (Combat.Fighter.strike voi ep_no, qua Harm), khong bia con so.
func tuyet_chieu(ten_hinh: String, doi: int, action: String, so_don: int) -> int:
	if _xong or ten_hinh == "":
		return 0
	var full := float(_rules.get("angerFull", 100.0))
	var n := 0
	for u in _doi[clampi(doi, 0, 1)]:
		if not u.alive() or not _khop_hinh(_muc[u], ten_hinh, false):
			continue
		n += 1
		u._play_lai(action if action != "" else "Wake")
		if doi != 0:
			continue                       # tuyet chieu dich: chi dien, khong AoE
		for v in _doi[1]:
			for _k in maxi(1, so_don):
				if not v.alive():
					break
				u.fighter.anger = full
				u.fighter.ep_no = true
				u.fighter.strike(v.fighter, _rng, _rules)
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
	_cap_nhat_bang()
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
