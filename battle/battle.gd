# Man tran. Vao bang duong dan tuong minh (`godot --path . battle/battle.tscn`)
# hoac tu nut cua man chon chuong trong `ui/menu.tscn`; `Game.chapter` cho biet
# dang danh chuong nao, 0 la danh tap.
#
#   Esc   ve `Game.MENU` — man Main THAT cua ban goc, khong phai `ui/menu.tscn`
#   F     danh lai chuong nay (may chu xu, co tinh diem)
#   R     xem lai tai cho, KHONG tinh diem
#   space tam dung        1 / 2 / 3  toc do 1x / 2x / 4x
#
# Doi cua NGUOI CHOI (ben trai) lay tu ban luu tren may chu; doi dich cua mot
# chuong la co dinh, may chu quyet. Client khong khai ket qua, va cung khong
# ghi duoc ban luu (permission_write = 0).
#
# Cai chieu tren man la DUNG tran ma may chu da xu, khong phai mot tran khac
# dien lai cho de nhin. Phat lai duoc vi bon thu deu khop: cung mo hinh, cung
# bo sinh so (Combat.Rng), cung buoc thoi gian co dinh (STEP), va may chu tra
# ve chinh cai seed no da dung. Kiem bang:
#
#   godot --headless --path . battle/battle.tscn -- --replaycheck --url=...
#
# Khong noi duoc toi may chu thi van xem duoc tran tai cho, chi la khong tinh
# diem; them --offline de bo han phan mang.
#
# Che do do dac, khong mo cua so:
#   godot --headless --path . battle/battle.tscn -- --sim=200 --mirror
#   godot --headless --path . battle/battle.tscn -- --play=3
extends Node2D

const TEAM_SIZE := 4
## Vach dan quan cua hai ben. Hang truoc dung o day, hang giua va hang sau lui
## ve phia sau — dung nhu Location 1/2/3 cua bang quan chung.
const LEFT_X := 190.0
const RIGHT_X := 770.0
## Hang 2 lui 78px, hang 3 lui 156px. Voi 580px giua hai vach, quan tam 750
## (ArcherN) ban duoc ngay tu cho dung, tam 400 phai tien nua duong, tam 30
## phai xong vao tan noi.
const ROW_BACK := 96.0
const MID_Y := 340.0
const ROW_GAP := 74.0
## So linh moi top duoc nhan len cho dong hon mot chut; bang goc de 2-4.
const SQUAD_SPREAD := 48.0
## Cap cua quan linh. Chi so cap 1 trong bang goc qua yeu so voi tuong nen tran
## khong ket thuc; tu cap 6 tro len hai ben moi cung thang. Chuong sau thi quan
## cung manh len.
const ARMY_BASE_LEVEL := 6
## Khoang cach toi thieu giua hai don vi. Phai xap xi tam danh (reach = 58),
## khong thi khi may nguoi cung vay mot muc tieu ho lot vao trong tam nhau va
## chong len thanh mot dong.
const BODY := 56.0
const RIG_SCALE := 0.55
const ART := "res://assets_ref/"
## Buoc thoi gian CO DINH. Phai khop FIELD_STEP trong server/modules/battle.lua
## va STEP trong sim/field.py.
##
## Truoc day o day buoc theo `delta` cua khung hinh, nghia la may nhanh may cham
## cho ra hai tran khac nhau tu cung mot seed — va khong bao gio phat lai dung
## tran may chu da xu. Toc do 1x/2x/4x van chay duoc: Engine.time_scale lam
## `delta` lon hon nen moi khung chay nhieu BUOC hon, chu buoc thi khong doi.
const STEP := 0.033
## Cho dung mac dinh cua doi dich. Doi cua nguoi choi dung cho dung trong ban
## luu; doi dich khong co ban luu nen dung bang nay. Phai khop battle.lua.
const FOE_PLACEMENT := [1, 1, 2, 3]

var combat: Combat
var session: PlayerSession = null
var rng := Combat.Rng.new()
var teams: Array = [[], []]
var roster: Array = [[], []]
var finished := false
## Bat khi mot che do chay bang kich ban (--sim, --play) dang tu dieu khien
## tran. Khong co co nay thi _process VAN chay song song, buoc tran them mot
## lan moi khung va cong ket qua hai lan — 3 tran thanh 6.
var scripted := false
var elapsed := 0.0
var label: Label = null
var picks_seed := 0
## Phan xu cua may chu cho tran dang xem. -1 = tran tap, khong tinh diem.
var server_result := -1
## Bat khi hai ben dung CHUNG doi hinh (che do --mirror). Quan linh cung phai
## soi guong theo, khong thi phep kiem thien vi khong con la soi guong nua —
## da dinh: bao lech 9.8 diem trong khi hai ben von da khac quan.
var mirrored := false
## Seed cua MAY CHU cho tran dang xem. 0 = khong phat lai (danh tap, xem lai
## tai cho), khi do dung seed rieng cua client.
var replay_seed := 0
## He so manh cua doi dich theo chuong, do may chu tinh.
var replay_power := 1.0
## Buff trang bi dung khi PHAT LAI (luc do khong co phien de hoi). Ten tuong ->
## bang buff. Rong thi phat lai tran khong trang bi, y nhu truoc.
var replay_equip: Dictionary = {}
## Tran dang xem co phai danh vao doi hinh NGUOI THAT khong (bx.pvp). Bat thi
## quan linh hai ben la linh nen (chapter = 0) va doi phai dung `pvp_foe`.
var pvp := false
## Doi cua nguoi bi danh, do may chu gui ve khi `pvp`. Cung hinh dang nhu
## `foe` trong reply cua bx.pvp: power / levels / placement / formation /
## formationLevel / buffs. Rong thi giu nguyen luat cu (doi dich cap 1, cho
## dung mac dinh, do manh qua `power` cua chuong).
var pvp_foe: Dictionary = {}
## O nhap ten doi thu (phim T). Dung mot LineEdit tran chu KHONG dung UiONhap:
## lop do sinh ra cho giao dien Lua, chi dep khi co bo cuc .xgg dang sau.
var _o_ten: LineEdit = null
## Dong bao lai "ai vua danh minh", chi hien mot lan luc mo man.
var _reports_line := ""
## Thoi gian con du chua di het mot buoc.
var _accum := 0.0


var hud: Control = null


func _ready() -> void:
	label = $Info
	$Backdrop.texture = Game.backdrop(Game.chapter)
	combat = Combat.new()
	var err := combat.load_data()
	if err != "":
		label.text = err
		push_error(err)
		return

	var opts := _cli()
	if opts.has("sim"):
		# Che do do dac khong dung toi mang.
		_run_headless(int(opts["sim"]), opts.has("mirror"))
		return
	if opts.has("replaycheck"):
		await _replay_check(String(opts.get("url", "")))
		return

	_build_hud()

	picks_seed = int(opts.get("seed", "1"))
	_new_rosters(picks_seed)

	if not opts.has("offline"):
		label.text = "dang dang nhap..."
		# Phien choi nam o autoload `Game` chu khong o day: doi man se huy moi
		# node cua man cu, ma dang nhap lai moi lan vao tran thi vua cham vua
		# thua. Man tran chi muon dung nho.
		session = await Game.ensure_session()
		# Doi cua nguoi choi lay tu ban luu neu co. Chua co thi giu doi vua boc
		# roi luu lai ngay, de lan sau mo game van dung doi do.
		var saved: Array = session.data.get("roster", [])
		if saved.size() == TEAM_SIZE and _all_known(saved):
			roster[0] = saved.duplicate()
		elif session.online:
			await session.set_roster(roster[0])

	if opts.has("play"):
		await _play_through(int(opts["play"]))
		return

	# Tran PvP: `--pvp=TEN` danh ngay, dung cho bo kiem. Phai dat TRUOC nhanh
	# chuong, vi no khong phai mot chuong — `chapter = 0` moi dung.
	if opts.has("pvp"):
		await _pvp(String(opts["pvp"]))
		return

	# Bao lai: ai vua danh minh. Doc LA da nhan, nen chi hien mot lan.
	if session != null and session.online:
		await _show_reports()

	# chapter = 0 la danh tap: van dien, nhung khong xin may chu, khong tinh diem.
	$Backdrop.texture = Game.backdrop(Game.chapter)
	if session != null and session.online and Game.chapter > 0:
		await _ranked(Game.chapter)
	else:
		_spawn()



## Mot tran XEP HANG. May chu boc doi dich, mo phong, cong so va ghi ban luu;
## client PHAT LAI dung tran do.
##
## Phat lai duoc vi bon thu deu khop: cung mo hinh (co di chuyen, co vi tri),
## cung bo sinh so (Park-Miller), cung buoc thoi gian co dinh, va cung seed —
## may chu tra seed no da dung ve trong `seed`.
##
## Truoc day man nay dien mot tran KHAC roi ghi de ket qua cua may chu len tren,
## nen co luc nhin thay thang ma bang diem ghi thua.
func _ranked(chapter: int) -> void:
	server_result = -1
	replay_seed = 0
	# Tran chuong khong phai PvP: xoa het dau vet cua tran PvP truoc do, khong
	# thi doi phai van dung cap / the tran cua nguoi khac.
	pvp = false
	pvp_foe = {}
	label.text = "dang xin chuong %d tu may chu..." % chapter
	var f := await session.fight(chapter)
	if not f.ok:
		label.text = "khong xin duoc tran: %s" % str(f.get("error", ""))
		_spawn()
		return
	Game.last_fight = f
	var opp: Array = f.get("opponent", [])
	if opp.size() == TEAM_SIZE and _all_known(opp):
		roster[1] = opp.duplicate()
	server_result = int(f.get("result", 2))
	replay_seed = int(f.get("seed", 0))
	replay_power = float(f.get("power", 1.0))
	_spawn()


## Mot tran PvP: danh vao doi hinh THAT cua mot tai khoan chi dinh.
##
## Giong `_ranked` o cho may chu xu tran roi client PHAI LAI dung tran do, nen
## ca hai deu can cung seed / cung buoc thoi gian. Khac o cho doi phai khong
## con la "quan cua chuong" ma la nguoi that, voi cap / cho dung / the tran /
## trang bi rieng — mang trong `pvp_foe`.
##
## `chapter = 0` cho CA HAI ben: quan linh la linh nen, khong theo chuong nao.
## Khong dat `Game.chapter = 0` — do la trang thai cua autoload, song lau hon
## man nay, va se lam man chon chuong mat dau.
func _pvp(name: String) -> void:
	if session == null or not session.online:
		label.text = "chua noi duoc may chu, khong danh PvP duoc"
		return
	pvp = true
	pvp_foe = {}
	server_result = -1
	replay_seed = 0
	label.text = "dang xin tran voi %s..." % name
	var f := await session.pvp(name)
	if not f.ok:
		label.text = "khong xin duoc tran: %s" % str(f.get("error", ""))
		return
	Game.last_fight = f
	var foe: Dictionary = f.get("foe", {})
	var opp: Array = foe.get("roster", [])
	if opp.size() == TEAM_SIZE and _all_known(opp):
		roster[1] = opp.duplicate()
		pvp_foe = foe
	else:
		# Doi thu khong dung thi khong dien mot doi khac roi goi do la doi cua
		# nguoi ta. May chu da tu choi truong hop nay; day la chot thu hai.
		label.text = "doi hinh cua %s khong dung duoc" % name
		return
	server_result = int(f.get("result", 2))
	replay_seed = int(f.get("seed", 0))
	replay_power = float(foe.get("power", 1.0))
	if not bool(f.get("foeLedger", true)):
		# So ben bi danh khong ghi duoc (dua ghi nhau hai lan): tran thua do da
		# mat. Noi ra chu khong im.
		push_warning("so cua %s khong ghi duoc: tran nay khong vao so cua ho" % name)
	_spawn()


## Hien mot dong bao lai: ai vua danh minh. `result` giu nguyen diem nhin cua
## NGUOI DI DANH, nen doi chieu nguoc lai khi doc: 0 = minh bi danh bai,
## 1 = minh thang, 2 = hoa.
func _show_reports() -> void:
	var rows: Array = await session.reports()
	if rows.is_empty():
		return
	var parts: Array = []
	for r in rows:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var who := String(r.get("name", "?"))
		match int(r.get("result", 2)):
			0:
				parts.append("bi %s danh bai" % who)
			1:
				parts.append("thang %s" % who)
			_:
				parts.append("hoa %s" % who)
	if not parts.is_empty():
		_reports_line = "vua bi danh: " + ", ".join(parts)


## Ban luu va du lieu may chu deu la du lieu ben ngoai: co the tro toi tuong
## khong con trong bo du lieu (doi ban, bo bot tuong). Khong kiem thi _spawn
## se dung phai null.
func _all_known(names: Array) -> bool:
	for n in names:
		if not combat.heroes.has(String(n)):
			return false
	return true


func _cli() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var body := a.substr(2)
		if body.contains("="):
			var kv := body.split("=", true, 1)
			out[kv[0]] = kv[1]
		else:
			out[body] = "1"
	return out


## Boc doi hinh. `mirror` cho hai ben cung danh sach — dung de kiem tra xem
## san co thien vi ben nao khong.
func _new_rosters(seed_value: int, mirror := false) -> void:
	mirrored = mirror
	var pool := Array(combat.order)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	for i in range(pool.size() - 1, 0, -1):      # tron bang RNG co seed
		var j := r.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	roster = [[], []]
	for i in TEAM_SIZE:
		roster[0].append(pool[i % pool.size()])
		roster[1].append(pool[i % pool.size()] if mirror
				else pool[(i + TEAM_SIZE) % pool.size()])


func _clear() -> void:
	for side in teams:
		for u in side:
			u.queue_free()
	teams = [[], []]


## Mot quan chung cho moi hang, boc theo seed.
##
## Dung Park-Miller y het `Rng` trong server/modules/battle.lua chu KHONG dung
## RandomNumberGenerator: cung mot seed phai boc ra cung mot doi quan o ca hai
## ben, khong thi man hinh hien mot doi quan con trong tai xu mot doi quan khac.
func _pick_armies(seed_value: int) -> Array:
	var s: int = seed_value % 2147483647
	if s <= 0:
		s += 2147483646
	var out: Array = []
	for row in [1, 2, 3]:
		var pool := combat.armies_in_row(row)
		if pool.size() > 0:
			s = (s * 16807) % 2147483647
			out.append(pool[s % pool.size()])
	return out


## Tra ve [x, y] kieu float 64 bit chu khong phai Vector2: Vector2 cua Godot la
## float 32 bit, khong du de khop voi may chu.
func _place(t: int, row: int, slot: int, of: int) -> Array:
	var back := (row - 1) * ROW_BACK
	var x := (LEFT_X - back) if t == 0 else (RIGHT_X + back)
	var y := MID_Y + (float(slot) - (of - 1) * 0.5) * SQUAD_SPREAD
	return [x, y]


## Co armature that cho ten quan nay khong.
##
## `SpriteName` trong bang quan chung la ten LOAI QUAN, khong phai ten armature:
## bang ghi `Archer(new)`, `Hoplite(董军入侵)`, `Stakes`, `witch doctor`, con thu
## muc art ten la `Archer`, `Hoplite`, `Spearmen`, `WitchDoctor`. Doi chieu voi
## kho atlas cua CHINH ban goc thi **62/80** ten trong bang khong co armature nao.
##
## Da can nhac dung luat tien to co san cua kho (`san_tran_ve._thu_muc_rig`, cung
## luat voi `LuaRuntime._tao_rig`: khong trung thu muc thi cat dan duoi va xin ten
## day du lam BIEN THE). Luat ay **cuu nham 32/62** ten: `Archer(new)` ra
## `Archer`, `Catapult(董军入侵)` ra `Catapult` (29 ten ra duoc voi dung chu hoa/
## thuong cua thu muc, 3 ten nua chi ra duoc vi `FileAccess.file_exists` tren
## Windows khong phan biet chu hoa/thuong — `witch doctor` ra thu muc `witch`
## trong khi thu muc that ten `Witch`). Nhung do lai chinh la bay: quet ca kho
## `assets_ref` thi **0/80** ten trong bang la bien the that su cua armature nao.
## `(new)` va `(董军入侵)` la LOAI QUAN cua ban moi, art khong co trong APK nay;
## gan chung vao armature goc la hien sai quan (Archer(new) mang hinh Archer cu).
## Nen o day chi nhan dung thu muc trung ten, khong dung luat tien to.
##
## `SngRig.build` tra null VA `push_error` khi thieu file `.json`, ma truoc luot
## nay moi don vi deu di thang duong do: mot tran ra **hang tram dong**
## `SngRig: khong thay res://assets_ref/...`. Bon bo kiem khong bat duoc vi
## `--sim` chay bang `_spawn(false)` (tat han phan hinh).
##
## Don vi thieu art VAN DANH: mo phong khong dinh gi toi hinh, va bo no khoi tran
## moi la doi thanh phan quan cua chuong (README: do la doi do kho, phai do lai).
## Nen cho `visual = false` — vo hinh, chu khong bien mat.
static func co_art(art_name: String) -> bool:
	if art_name == "":
		return false
	return FileAccess.file_exists(ART.path_join(art_name).path_join(art_name + ".json"))


func _add_unit(f, t: int, pos: Array, art_name: String, with_art: bool) -> void:
	if f == null:
		return
	var co := with_art and co_art(art_name)
	var u := BattleUnit.new()
	u.visual = co
	u.sx = pos[0]
	u.sy = pos[1]
	u.position = Vector2(u.sx, u.sy)
	add_child(u)
	u.setup(f, t, combat.rules, rng, (ART + art_name) if co else "", RIG_SCALE)
	teams[t].append(u)


func _spawn(with_art := true) -> void:
	_clear()
	finished = false
	elapsed = 0.0
	_accum = 0.0
	rng.set_seed(replay_seed if replay_seed != 0 else 20260908 + picks_seed)

	for t in 2:
		# --- quan linh: moi hang mot top, moi top MaxUnit nguoi
		var side := 0 if mirrored else t
		# Seed lay tu CHUONG chu khong tu picks_seed, de khop army_battle() ben
		# may chu: quan linh cua mot chuong phai co dinh — nguoi choi hoc duoc
		# tran dau roi doi doi hinh cho hop, va cai hien tren man phai dung la
		# doi quan ma trong tai vua xu.
		#
		# Tran PvP dung chuong 0 y nhu may chu (no cung truyen chapter = 0), nen
		# quan linh hai ben la linh nen. Khong duoc gan Game.chapter = 0: do la
		# trang thai cua autoload Game, song lau hon man nay.
		var ch: int = 0 if pvp else Game.chapter
		var picks := _pick_armies(ch * 31 + side * 7 + ch)
		var army_lv: int = ARMY_BASE_LEVEL + maxi(0, ch)
		for name in picks:
			var proto = combat.make_army(name, army_lv)
			if proto == null:
				continue
			for k in proto.units:
				_add_unit(combat.make_army(name, army_lv), t,
						_place(t, proto.battle_row, k, proto.units), name, with_art)

		# --- tuong: moi nguoi dung o CHO DUNG cua minh (1 truoc, 2 giua, 3 sau)
		for i in roster[t].size():
			var hero_name: String = roster[t][i]
			# Doi cua nguoi choi dung cap that; doi dich luon cap 1 va do manh
			# cua chung the hien qua he so `power` cua chuong — dung nhu may chu.
			var lv := 1
			var power := 1.0
			# Cho dung quyet ca hai thu: dung o dau tren san, va an buff nao cua
			# the tran. Chi doi cua NGUOI CHOI co the tran.
			var spot: int = FOE_PLACEMENT[i] if i < FOE_PLACEMENT.size() else 1
			var buffs: Dictionary = {}
			if t == 0:
				if session != null:
					lv = session.level_of(hero_name)
					spot = session.placement_of(i)
					buffs = combat.formation_buffs(
							session.formation(), session.formation_level(), spot)
					# Trang bi di CHUNG mot bang voi buff the tran roi ap mot
					# lan — dung y may chu lam (army_battle trong battle.lua).
					# Thieu cho nay thi tran phat lai lech han tran may chu xu,
					# ngay khi nguoi choi nhat duoc mon do dau tien.
					buffs = Equipment.merge_buffs(buffs,
							session.equip_buffs(hero_name))
				elif not replay_equip.is_empty():
					# Duong phat lai: khong co phien de hoi, may chu gui thang
					# bang buff no vua dung — ap dung cai do.
					buffs = Equipment.merge_buffs(buffs,
							replay_equip.get(hero_name, {}))
			elif not pvp_foe.is_empty():
				# Doi thu la NGUOI THAT (bx.pvp): dung dung cap, cho dung, the
				# tran va trang bi cua ho — y nhu may chu lam trong nhanh
				# `elseif foe_formation ~= nil` cua army_battle(). Nhanh nay
				# phai khop TUNG DON VI, khong thi tran phat lai lech tran may
				# chu xu.
				var fl: Dictionary = pvp_foe.get("levels", {})
				lv = maxi(1, int(fl.get(hero_name, 1)))
				var fp: Array = pvp_foe.get("placement", [])
				if i < fp.size():
					spot = clampi(int(fp[i]), 1, 3)
				power = float(pvp_foe.get("power", 1.0))
				if pvp_foe.has("formation"):
					var fname := String(pvp_foe.get("formation", ""))
					var fb: Dictionary = {}
					if fname != "":
						fb = combat.formation_buffs(fname,
								int(pvp_foe.get("formationLevel", 0)), spot)
					var fbuff: Dictionary = pvp_foe.get("buffs", {})
					buffs = Equipment.merge_buffs(fb, fbuff.get(hero_name, {}))
			else:
				power = replay_power
			var y: float = MID_Y + (float(i) - (roster[t].size() - 1) * 0.5) * ROW_GAP
			# Tuong dung nhinh len truoc top linh cung hang, khong de len nhau.
			var back := (spot - 1) * ROW_BACK
			var x: float = (LEFT_X + 52.0 - back) if t == 0 else (RIGHT_X - 52.0 + back)
			_add_unit(combat.make(hero_name, lv, buffs, power), t, [x, y],
					hero_name, with_art)
	_refresh()


func _alive(t: int) -> int:
	var n := 0
	for u in teams[t]:
		if u.alive():
			n += 1
	return n


## Mot buoc cua tran, hai pha. Tra ve -1 neu chua xong, 0/1 la doi thang,
## 2 la hoa.
##
## Pha 1 cho moi don vi doc vi tri doi thu tu cung mot ban chup, pha 2 tru mau
## dong loat. Neu lam mot pha thi ben duoc duyet sau vao tam truoc va thang
## ap dao — do la loi that da gap: hai doi hinh giong het nhau ma ben phai
## thang 76%.
func _step(delta: float) -> int:
	elapsed += delta

	var snap := {}
	for t in 2:
		for u in teams[t]:
			snap[u] = [u.sx, u.sy]

	var strikes := []
	for t in 2:
		for u in teams[t]:
			var victim: BattleUnit = u.advance(delta, teams[1 - t], snap)
			if victim != null:
				strikes.append([u, victim])
	_separate()
	for pair in strikes:
		pair[0].resolve(pair[1])
	for t in 2:
		for u in teams[t]:
			if not u.alive():
				u.die()

	var a := _alive(0)
	var b := _alive(1)
	if a > 0 and b > 0:
		return -1 if elapsed < float(combat.rules.get("maxSeconds", 600.0)) else 2
	if a > 0:
		return 0
	if b > 0:
		return 1
	return 2


## Day cac don vi ra khoi nhau. Khong co buoc nay thi ca hai doi don vao mot
## diem va chong len nhau thanh mot dong, nhin khong ra ai danh ai.
## Cong don luc day roi ap MOT LAN, khong day tuan tu.
##
## Ban dau o day day tung cap ngay lap tuc, nen cap duoc xet sau nhin thay vi
## tri da doi — ma doi 0 luon duoc duyet truoc. Do la dung loai bat doi xung
## da tung lam ben phai thang 76% o pha ra don. Voi 4 don vi thi khong thay,
## voi hai doi quan hai chuc nguoi thi thay.
func _separate() -> void:
	var all := []
	for t in 2:
		for u in teams[t]:
			if u.alive():
				all.append(u)
	# Cong don bang float 64 bit, khong dung Vector2 (32 bit) — xem BattleUnit.sx.
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
			# He so truoc, roi moi nhan vao toa do — dung thu tu cua ban Lua.
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


func _process(delta: float) -> void:
	if scripted or finished or teams[0].is_empty():
		return
	# Gom `delta` lai roi chay tung BUOC CO DINH. Buoc thang bang delta thi cung
	# mot seed ra hai tran khac nhau tuy toc do khung hinh.
	_accum += delta
	var out := -1
	# Chan so buoc moi khung: may giat mot cai (hoac vua bam 4x) thi khong nen
	# chay bu ca tram buoc trong mot khung roi treo hinh.
	var budget := 40
	while _accum >= STEP and out < 0 and budget > 0:
		_accum -= STEP
		budget -= 1
		out = _step(STEP)
	if out >= 0:
		finished = true
		_report(out)
	_refresh(out)


## Tran vua xong. Khong con cong so o day — may chu da cong tu luc xin tran.
func _report(out: int) -> void:
	_refresh(out)


func _refresh(out := -1) -> void:
	if label == null:
		return
	var head := ("Chuong %d" % Game.chapter) if Game.chapter > 0 else "Danh tap"
	if pvp:
		head = "PvP  vs  %s" % String(pvp_foe.get("name", "?"))
	var txt := "%s   |   %s  %d/%d   vs   %d/%d  %s\n%.1fs" % [head,
			", ".join(roster[0]), _alive(0), teams[0].size(),
			_alive(1), teams[1].size(), ", ".join(roster[1]), elapsed]
	if out == 0:
		txt += "   —  DOI TRAI THANG"
	elif out == 1:
		txt += "   —  DOI PHAI THANG"
	elif out == 2:
		txt += "   —  HOA"
	else:
		txt += "\nEsc ve menu   F danh lai chuong   R xem lai   space tam dung   1/2/3 toc do"
		txt += "\nP dan dan ten doi thu (PvP)   T nhap ten doi thu"
	if server_result >= 0 and out >= 0:
		var verdict: String = ["BAN THANG", "BAN THUA", "HOA"][server_result]
		txt += "   |   may chu xu: %s" % verdict
		# Gio ban dien la ban PHAT LAI cua chinh tran may chu xu, nen hai ket
		# qua phai trung. Lech la co loi that (lech mo hinh, lech buoc thoi
		# gian, hoac may chu doi ma client chua doi theo) — bao ra chu khong
		# giau di.
		if server_result != out:
			txt += "  (!! ban dien lech voi may chu — chay --replaycheck)"
	if session != null:
		txt += "\n" + session.status_line()
	if _reports_line != "":
		txt += "\n" + _reports_line
	label.text = txt


func _unhandled_input(e: InputEvent) -> void:
	# CHOT BAT BUOC: o nhap ten dang mo va dang co tieu diem thi tra phim lai cho
	# no. Khong co chot nay thi go ten vua vao o vua doi doi hinh — R/F/N la chu
	# cai, Space/1/2/3 la phim tran, tat ca deu nam trong match ben duoi.
	if _o_ten != null and _o_ten.visible and _o_ten.has_focus():
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_R:                       # danh lai tai cho, khong tinh diem
			server_result = -1
			replay_seed = 0      # gieo seed rieng: day khong con la tran cua may chu
			_spawn()
		KEY_F:                       # danh lai chuong nay (tinh diem)
			if session != null and session.online and Game.chapter > 0:
				await _ranked(Game.chapter)
			else:
				_spawn()
		KEY_ESCAPE:                  # ve man chon chuong
			Game.goto(Game.MENU)
		KEY_N:                       # doi doi hinh (may chu kiem va ghi)
			picks_seed += 1
			_new_rosters(picks_seed)
			if session != null:
				await session.set_roster(roster[0])
			server_result = -1
			replay_seed = 0
			_spawn()
		KEY_P:                       # dan dan ten doi thu (PvP)
			_pvp_tu_clipboard()
		KEY_T:                       # nhap ten doi thu (PvP)
			_mo_o_ten()
		KEY_SPACE:
			get_tree().paused = not get_tree().paused
		KEY_1:
			Engine.time_scale = 1.0
		KEY_2:
			Engine.time_scale = 2.0
		KEY_3:
			Engine.time_scale = 4.0


## Dan ten doi thu tu clipboard. Hai cua so canh nhau thi day dung dong tac
## nguoi choi lam: bam P la danh ngay, khong phai go lai 10 ky tu.
func _pvp_tu_clipboard() -> void:
	var ten := DisplayServer.clipboard_get().strip_edges()
	if ten == "":
		label.text = "clipboard rong — bam T de nhap ten"
		return
	await _pvp(ten)


## O nhap ten tran: mot LineEdit dung trong ma, nam tren cung.
func _mo_o_ten() -> void:
	if _o_ten == null:
		_o_ten = LineEdit.new()
		_o_ten.placeholder_text = "username 10 ky tu"
		_o_ten.flat = true
		_o_ten.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
		_o_ten.position = Vector2(24, 12)
		_o_ten.size = Vector2(320, 30)
		_o_ten.text_submitted.connect(_nhan_ten)
		add_child(_o_ten)
	_o_ten.text = ""
	_o_ten.visible = true
	_o_ten.grab_focus()


func _nhan_ten(ten: String) -> void:
	_dong_o_ten()
	var s := ten.strip_edges()
	if s == "":
		return
	await _pvp(s)


func _dong_o_ten() -> void:
	if _o_ten != null:
		_o_ten.visible = false
		_o_ten.release_focus()


## Kiem tra dieu quan trong nhat cua man nay: cai chieu tren man co DUNG la
## tran ma may chu da xu khong.
##
##   godot --headless --path . battle/battle.tscn -- --replaycheck --url=...
##
## bx.fieldtest cho may chu danh may tran voi seed dinh san roi tra ve ket qua,
## so nguoi con song va so giay. O day dung CHINH duong danh cua man tran —
## _spawn() roi _step() — de danh lai tung tran do, va doi chieu.
##
## Chay voi NAKAMA THAT chu khong phai ban gia: runtime Lua cua Nakama giu moi
## so duoi dang float64, con lupa thi co so nguyen 64 bit. Chi may chu that moi
## tra loi duoc cau hoi nay.
func _replay_check(url: String) -> void:
	scripted = true
	var n_pass := 0
	var n_fail := 0

	var client := NakamaClient.new()
	if url != "":
		client.url = url
	add_child(client)
	var la := await client.login("replay-%d-%d"
			% [Time.get_unix_time_from_system(), randi() % 100000])
	if not la.ok:
		print("khong dang nhap duoc: %s" % str(la.get("error", "")))
		print("Can Nakama that:  cd server && docker compose up -d")
		get_tree().quit(1)
		return
	var ft := await client.call_rpc("bx.fieldtest", {})
	if not ft.ok:
		print("khong goi duoc bx.fieldtest: %s" % str(ft.get("error", "")))
		get_tree().quit(1)
		return

	var mine: Array = ft.data.get("mine", [])
	var theirs: Array = ft.data.get("theirs", [])
	print("may chu: %s" % client.url)
	print("doi trai : %s" % ", ".join(mine))
	print("doi phai : %s\n" % ", ".join(theirs))

	# Ba luot. Luot dau la tran tran nhu truoc; luot hai dung nhung tran do
	# nhung doi ta co trang bi — do CHINH cai vua noi vao: buff trang bi rang
	# vao tran o client co giong het ben may chu khong. Luot ba la doi dich la
	# NGUOI THAT: cap, cho dung, the tran va trang bi cua doi phuong deu khac
	# mac dinh, nen no khoa luon nhanh `elseif` trong `_spawn` — nhanh ma khong
	# luot nao khac cham toi.
	#
	# `foe` (chu khong phai co nao khac) moi la thu bat nhanh do: `_spawn` doc
	# `pvp_foe` chu khong doc `replay_power` khi no khac rong.
	var rounds := [
		{"ten": "khong trang bi", "battles": ft.data.get("battles", []), "eq": {}},
		{"ten": "co trang bi", "battles": ft.data.get("equipBattles", []),
			"eq": ft.data.get("equipBuffs", {})},
		{"ten": "doi thu la nguoi that", "battles": ft.data.get("foeBattles", []),
			"eq": {}, "foe": ft.data.get("foeDesc", {})},
	]
	for r in rounds:
		var label: String = r["ten"]
		replay_equip = r["eq"]
		# Co `foe` thi tran chay theo duong PvP: `chapter = 0` cho CA HAI ben
		# (y may chu: bx.pvp truyen chapter = 0), quan linh hai ben la linh nen.
		pvp = r.has("foe")
		pvp_foe = r.get("foe", {})
		print("-- %s --" % label)
		for e in r["battles"]:
			var seed_value := int(e.get("seed", 0))
			# bx.fieldtest goi army_battle(mine, theirs, Rng.new(seed), 1.0, {},
			# chapter, seed_value, ...) — khong ban luu nen khong the tran,
			# khong cap, cho dung mac dinh. Dung lai y het o day.
			#
			# Hai luot dau: chapter = seed_value = seed. Luot PvP: chapter = 0
			# va seed_value = 0 (doi dich la nguoi that, khong phai chuong nao),
			# nen `seed_value` KHONG con lai la chuong — va do cung la ly do
			# `army_battle` ben Lua phai nhan hai so rieng.
			Game.chapter = 0 if pvp else seed_value
			session = null
			roster = [mine.duplicate(), theirs.duplicate()]
			replay_seed = seed_value
			replay_power = 1.0
			_spawn(false)

			var out := -1
			var guard := 0
			while out < 0 and guard < 100000:
				out = _step(STEP)
				guard += 1

			var want_out := int(e.get("result", -1))
			var want_a := int(e.get("aliveA", -1))
			var want_b := int(e.get("aliveB", -1))
			var want_s := float(e.get("seconds", -1.0))
			var same := (out == want_out and _alive(0) == want_a and _alive(1) == want_b
					and absf(elapsed - want_s) < 0.05)
			if same:
				n_pass += 1
				print("  dat   seed %d: ket qua %d, con song %d-%d, %.1f giay"
						% [seed_value, out, _alive(0), _alive(1), elapsed])
			else:
				n_fail += 1
				print("  HONG  %s seed %d  ->  may chu %d/%d-%d/%.2fs   client %d/%d-%d/%.2fs"
						% [label, seed_value, want_out, want_a, want_b, want_s,
						out, _alive(0), _alive(1), elapsed])

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	get_tree().quit(0 if n_fail == 0 else 1)


## Danh n tran lien tiep, luu sau moi tran, roi bao ket qua va thoat.
## Dung de kiem tra ca duong day: dang nhap -> danh -> cong so -> day len.
func _play_through(n: int) -> void:
	scripted = true
	print("doi cua ban : %s" % ", ".join(roster[0]))
	print("trang thai  : %s" % (session.status_line() if session else "khong co phien"))
	var names := ["ban thang", "ban thua", "hoa"]
	for i in n:
		if session == null or not session.online:
			print("  tran %d: bo qua — dang ngoai tuyen" % (i + 1))
			continue
		var f := await session.fight()
		if not f.ok:
			print("  tran %d: khong xin duoc — %s" % [i + 1, str(f.get("error", ""))])
			continue
		print("  tran %d: %-10s  (doi dich: %s)"
				% [i + 1, names[int(f.result)], ", ".join(f.get("opponent", []))])
	print("trang thai  : %s" % (session.status_line() if session else "khong co phien"))
	get_tree().quit(0)


## Danh n tran khong ve gi, buoc thoi gian co dinh. Dung de kiem tra tran co
## ket thuc khong, va voi doi hinh guong thi co thien vi ben nao khong.
func _run_headless(n: int, mirror: bool) -> void:
	scripted = true
	var dt := STEP
	var win := [0, 0, 0]
	var secs := 0.0
	var steps := 0
	for i in n:
		picks_seed = i + 1
		_new_rosters(picks_seed, mirror)
		_spawn(false)
		var out := -1
		var guard := 0
		while out < 0 and guard < 100000:
			out = _step(dt)
			guard += 1
		win[out if out >= 0 else 2] += 1
		secs += elapsed
		steps += guard
	print("%d tran%s, buoc %.3fs" % [n, "  (doi hinh guong)" if mirror else "", dt])
	print("  doi trai thang : %d  (%.1f%%)" % [win[0], 100.0 * win[0] / n])
	print("  doi phai thang : %d  (%.1f%%)" % [win[1], 100.0 * win[1] / n])
	print("  hoa            : %d  (%.1f%%)" % [win[2], 100.0 * win[2] / n])
	print("  tran trung binh: %.1f giay" % (secs / n))

	if mirror:
		# Hai doi hinh giong het nhau thi san khong duoc thien vi ben nao. Day
		# tung la loi that: cap nhat mot pha cho ben duyet sau thang 76%.
		# Nguong 3 lan do lech chuan cua ti le 50%, san 6 diem.
		var decided: int = win[0] + win[1]
		var tol: float = maxf(6.0, 300.0 * sqrt(0.25 / maxf(float(decided), 1.0)))
		var gap: float = absf(100.0 * float(win[0] - win[1]) / maxf(float(decided), 1.0))
		if gap <= tol:
			print("
  dat   san khong thien vi ben nao (lech %.1f diem, cho phep %.1f)"
					% [gap, tol])
		else:
			print("
  HONG  san THIEN VI mot ben (lech %.1f diem, cho phep %.1f)"
					% [gap, tol])
			get_tree().quit(1)
			return
	get_tree().quit(0)

## HUD lay thang bo cuc cua ban goc.
##
## Toa do, phan cap, diem neo va anh deu doc tu Game_UI_Control_Panel_960_640,
## khong uom tay. Dat trong CanvasLayer de khong bi camera cua man tran keo di.
func _build_hud() -> void:
	var path := "res://layout_ref/Game_UI_Control_Panel_960_640.json"
	if not FileAccess.file_exists(path):
		# Bo cuc la noi dung dan xuat, khong nam trong repo. Thieu thi choi
		# khong co HUD chu khong sap.
		push_warning("chua co %s — sinh bang: " % path
				+ "python ../brave-cross/work/layout.py --all --out layout_ref")
		return
	var ui := XggLayout.build(path)
	if ui == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = 10
	layer.add_child(ui)
	add_child(layer)
	hud = ui

	# Tat `g_BlackEffectLayer` — tam den phu kin ca san cua bo cuc goc.
	#
	# Node ay la `CCLayerColorRoundRect` 2000x1000 o (-200,-200), mau [0,0,0],
	# opacity 255, va trong file ghi `visible: True`. Dung nguyen bo cuc thi ra
	# MAN DEN TUYET DOI: do tren khung hinh that, HUD hien -> khung hinh dung MOT
	# mau (0,0,0) tren ca 614.400 diem anh; tat HUD -> 2540 mau, co ca mau nen
	# (0,106; 0,118; 0,145) lan quan xanh/do. Truoc luot nay man tran khong choi
	# duoc chi vi node nay.
	#
	# Ban goc TAT no bang co `bShowBattleBlackEffectLayer`, va ai thuong dat co ay
	# `false` (`sc/user/Battle/ChapterNormalLevel.lua:8` — mot lan gan duy nhat
	# trong ca kho sc/). Khong file Lua nao doc co ay: no la truong ben C++ doc,
	# va ten node `g_BlackEffectLayer` nam trong pool chuoi cua `libgame.so`
	# (ban vn `0x7c0dc7`, canh `getEliteNameLabel` va `PauseLeaderShipTimer`) —
	# tuc engine tim node theo TEN roi tu bat/tat. Nen hien nguyen trang thai cua
	# file moi la nguoc voi ban goc.
	#
	# Duong CHIEN DICH da tat no tu truoc, o phia Lua: `lua/san_tran.lua:481`
	# (`lop_den`) tat luc `_Lua_LoadMap`, va `SetLayerDark(b)` cua `g_BattleField`
	# bat/tat theo kich ban. Man nay la man tran DUNG RIENG (danh tap / xep hang),
	# khong di qua `san_tran.lua`, nen no khong duoc huong phep tat do — cung mot
	# node, cung mot luat, hai duong khac nhau. Chu thich o `san_tran.lua` ghi
	# phep tat ay la SUY RA; day la phep do cho dung luat ay.
	#
	# Giu node lai chu khong xoa: no thuoc bo cuc goc, va cac che do tran khac
	# (dau truong, ai vo tan) moi la cho bat no len — man nay chi danh ai thuong.
	var den := XggLayout.find_node(hud, "g_BlackEffectLayer")
	if den != null:
		den.visible = false

	_show_mode_layer("lUINormal")


## Bat dung mot lop che do choi, y nhu ban goc.
##
## lUITopLayer co 13 con, moi con la mot che do: lUINormal, lUIEndless,
## lUIArena, lUIJFZY, lUICavern... Tat ca an san va Lua bat DUNG MOT cai tuy
## tran dang danh. Tran chien dich thuong dung lUINormal.
func _show_mode_layer(mode: String) -> void:
	if hud == null:
		return
	var n := XggLayout.find_node(hud, mode)
	if n == null:
		push_warning("khong thay lop che do " + mode)
		return
	# Hien chinh no; to tien da hien san theo co cua ban goc.
	n.visible = true

