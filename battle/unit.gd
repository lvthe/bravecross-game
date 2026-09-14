# Mot don vi tren san: chi so chien dau + hinh anh + thanh mau.
#
# Phan SO nam o Combat.Fighter (da doi chieu voi ban Python). Phan HINH nam o
# SngRig. File nay chi noi hai thu do lai va them di chuyen, chon muc tieu,
# thanh mau.
#
# Dat `visual = false` de chay khong dung anh — dung cho che do --sim, dung
# rig cho 10 don vi moi tran thi qua cham.
class_name BattleUnit
extends Node2D

signal died(unit: BattleUnit)

enum State { ADVANCE, ATTACK, DEAD }

const BAR_W := 46.0
const BAR_H := 5.0
const LANE_PULL := 0.35        ## doi lan cham hon chay thang bao nhieu lan
const LANE_WEIGHT := 4.0       ## lech lan bi phat nang the nay khi chon muc tieu
const BAR_Y := -88.0           ## rig lay goc o chan, nhan vat cao khoang 90

var fighter: Combat.Fighter
var team := 0
var rig: SngRig = null
## Toc do va tam danh lay tu chi so cua don vi (setup() ghi de). Gia tri o day
## chi la du phong.
var speed := 90.0
var reach := 58.0
## Tam toi thieu: vai quan chung khong danh duoc muc tieu qua gan (Artillery,
## Catapult). 0 = khong co han che.
var min_reach := 0.0
## Toa do dung cho MO PHONG. `position` cua Node2D la Vector2, ma Vector2 trong
## Godot dung float 32 BIT — khong du chinh xac de khop voi may chu (Lua) va
## sim/field.py (Python), ca hai deu tinh bang 64 bit. Sai so 32 bit don lai qua
## hang nghin buoc du de doi muc tieu va doi ket qua tran.
##
## `position` tu day chi de VE, va duoc cap nhat theo sx/sy.
var sx := 0.0
var sy := 0.0
var target: BattleUnit = null
var state: State = State.ADVANCE
var cooldown := 0.0
## Huong nhin: +1 la nhin sang PHAI, -1 sang TRAI. Day la huong LOGIC, khong
## phai scale — xem ART_FACES_LEFT.
var facing := 1.0
var visual := true

## Art cua ban goc ve nhan vat QUAY SANG TRAI. Da kiem bang cach dung mot rig
## o scale.x = +1: giao cua Ma Sieu, kiem cua Cam Ninh va cung cua cung thu
## deu chia sang trai. Nen muon nhin sang PHAI thi phai LAT, tuc scale.x am.
##
## Truoc day mã đặt scale.x = facing, thanh ra doi trai (nhin phai) bi lat
## nguoc: di sang phai ma quay mat sang trai, danh cung quay lung lai.
const ART_FACES_LEFT := true

var _rules: Dictionary = {}
var _rng: Combat.Rng = null
var _anim := ""
var _death_timer := 0.0


func setup(f: Combat.Fighter, team_index: int, rules: Dictionary,
		rng: Combat.Rng, art_dir: String = "", art_scale := 1.0,
		variant := "", ten_sprite := "") -> void:
	fighter = f
	team = team_index
	_rules = rules
	_rng = rng
	facing = 1.0 if team == 0 else -1.0
	# Tam danh 30 cua quan can chien nho hon khoang cach than (BODY = 56) nen
	# ho khong bao gio cham duoc nhau — nang san len vua qua than nguoi.
	reach = maxf(f.reach, 62.0) if f.reach > 0.0 else 58.0
	min_reach = f.min_reach
	# Toc do THAT cua ban goc, theo sprite (MoveRef): bo binh di 130 px/giay,
	# ky binh 140... Truong `MovingSpeed` cua bang chi so tran KHONG phai cho
	# engine lay toc do — no khong he co trong libgame.so; xem battle/move_ref.gd.
	#
	# DAT: lay toc do DI. Ban goc con co toc do CHAY (bo binh 300, cung 250,
	# ky binh 350) va chon di hay chay theo "brain" ben C++ — chua giai.
	speed = MoveRef.di(ten_sprite)
	if speed <= 0.0:
		# Khong biet sprite do: giu cach cu de khoi dung im.
		speed = maxf(28.0, f.move_speed * 1.5)
	# Don dau tien roi vao luc hoi chieu xong, giong mo phong Python.
	cooldown = fighter.interval
	if visual and art_dir != "":
		# Man tran bo qua cac lop ve tich (ten lop Photoshop, lop hieu ung
		# logic): chung nam xa than va o day hien suot chu khong loe roi tat.
		rig = SngRig.build(art_dir, variant, true)
		# San tran cua ban goc xin BIEN THE theo ten quan (Player000M03W);
		# armature khong co bien the do thi lay bien the mac dinh.
		if rig == null and variant != "":
			rig = SngRig.build(art_dir, "", true)
		if rig != null:
			rig.scale = Vector2(_scale_x(art_scale), art_scale)
			add_child(rig)
			# Dong tac danh / thuc tinh KHONG lap (loop=false): choi xong dung o
			# khung cuoi. Khi choi xong ma van song thi ve Standby (dung im nhip
			# tho), khoi treo cung o khung cuoi giua cac don.
			if rig.player != null:
				rig.player.animation_finished.connect(_dong_tac_xong)
			_play("Standby")


## Dong tac vua choi xong (ban goc loop=false cho Fight/Wake/Hit...). Con song
## thi ve Standby de khong dung cung khung cuoi.
func _dong_tac_xong(ten: StringName) -> void:
	if state != State.DEAD and String(ten) != "Standby":
		_play("Standby")


## scale.x cho huong `facing` hien tai, da tinh ca chieu ve cua art.
func _scale_x(mag: float) -> float:
	return (-facing if ART_FACES_LEFT else facing) * mag


## Chuoi thay the cho tung dong tac: khong phai armature nao cung du bo dong tac
## chuan. Flagman chi co "Walk" (khong Standby/Fight) -> truoc day _play im lang,
## don vi treo cung o khung 0. Doi sang dong tac gan nghia nhat con co that.
const THAY_DONG := {
	"Standby": ["Standby", "Standby2", "Walk", "Run"],
	"Walk": ["Walk", "Walk2", "Run", "Standby"],
	"Fight": ["Fight", "Fight2", "Fight3", "Fire", "Walk"],
	"Wake": ["Wake", "Wake2", "WakeLoop", "Fight", "Walk"],
	"Death": ["Death", "Down", "Hit", "Standby"],
}


## Ten dong tac CO THAT gan nhat voi `anim_name` tren rig hien tai; "" neu chiu.
func _ten_dong(anim_name: String) -> String:
	if rig == null or rig.player == null:
		return ""
	if rig.player.has_animation(anim_name):
		return anim_name
	for ten in THAY_DONG.get(anim_name, []):
		if rig.player.has_animation(ten):
			return ten
	# Cuoi cung: dong tac dau tien co, con hon dung im.
	var ds := rig.player.get_animation_list()
	return String(ds[0]) if not ds.is_empty() else ""


func _play(anim_name: String) -> void:
	if rig == null:
		return
	var ten := _ten_dong(anim_name)
	if ten == "" or _anim == ten:
		return
	if rig.play(ten):
		_anim = ten


## Choi LAI tu dau, du dang o dung dong tac do — cho don danh / ky nang lap lai
## moi don. Khong co cai nay thi don thu hai tro di bi _play bo qua (trung ten)
## va nhan vat treo o khung cuoi Fight -> "danh khong muot".
func _play_lai(anim_name: String) -> void:
	if rig == null or rig.player == null:
		return
	var ten := _ten_dong(anim_name)
	if ten == "":
		return
	rig.player.play(ten)
	rig.player.seek(0.0, true)
	_anim = ten


func alive() -> bool:
	return fighter != null and fighter.alive()


# Mot buoc thoi gian chia lam HAI PHA, va do la co y.
#
# Ban dau lam mot pha — duyet doi 0 roi doi 1 — thi voi hai doi hinh GIONG HET
# NHAU, doi phai thang 76%. Ly do: doi 0 di chuyen truoc, nen khi doi 1 tinh
# khoang cach thi doi thu da tien lai gan, doi 1 vao tam truoc va ra don truoc.
#
# Nen: pha 1 moi don vi doc vi tri doi thu tu MOT BAN CHUP truoc khi ai di
# chuyen; pha 2 gom moi don ra cung luc roi tru mau mot the. Nho vay hai ben
# co the cung chet trong mot buoc, dung nhu mo hinh Python.

## Pha 1: chon muc tieu, tien len. `snap` la vi tri cua moi don vi truoc buoc
## nay. Tra ve muc tieu neu don vi nay ra don trong buoc, khong thi null.
## Xac mo dan roi BIEN MAT sau khi chet — khong de dong lai thanh vet den.
const DEATH_FADE := 1.2

func advance(delta: float, enemies: Array, snap: Dictionary) -> BattleUnit:
	if state == State.DEAD:
		_death_timer += delta
		if rig != null:
			if _death_timer >= DEATH_FADE:
				# Da mo het: an han xac de khong chong dong thanh vet den.
				if rig.visible:
					rig.visible = false
			else:
				# Mo dan tu ~0,85 ve 0 trong DEATH_FADE giay.
				var a := 0.85 * (1.0 - _death_timer / DEATH_FADE)
				rig.modulate = Color(0.7, 0.7, 0.76, a)
		return null
	if not alive():
		die()
		return null

	if target == null or not target.alive():
		target = _nearest(enemies, snap)
	if target == null:
		_play("Standby")
		return null

	var here: Array = snap[self]
	var there: Array = snap[target]
	var dx: float = there[0] - here[0]
	var dy: float = there[1] - here[1]
	var dist := sqrt(dx * dx + dy * dy)

	# Qua gan thi lui ra: Artillery/Catapult co MinAttackDistance nen khong
	# danh duoc muc tieu ap sat.
	if min_reach > 0.0 and dist < min_reach:
		state = State.ADVANCE
		# `k` tach rieng chu khong viet lien mot dong: ban Lua va ban Python
		# deu tinh he so truoc roi moi nhan vao toa do. Doi thu tu la doi ket
		# qua lam tron, va tran phat lai se lech dan.
		var k := speed * delta * 0.6 / maxf(dist, 0.001)
		sx = here[0] - dx * k
		sy = here[1] - dy * k
		_sync()
		_play("Walk")
		return null

	if dist > reach:
		state = State.ADVANCE
		# Di theo LAN: chay thang mot mach theo truc x, con doi lan thi cham
		# hon nhieu. Neu cho di thang toi muc tieu thi ca tam don vi don ve
		# mot diem giua san roi chong len nhau thanh mot dong.
		var step_y := speed * LANE_PULL * delta
		if dx > 0.0:
			sx = here[0] + speed * delta
		elif dx < 0.0:
			sx = here[0] - speed * delta
		else:
			sx = here[0]
		sy = here[1] + maxf(-step_y, minf(step_y, dy))
		_sync()
		if absf(dx) > 1.0:
			facing = signf(dx)
			if rig != null:
				rig.scale.x = _scale_x(absf(rig.scale.y))
		_play("Walk")
		return null

	state = State.ATTACK
	cooldown -= delta
	if cooldown <= 0.0:
		cooldown += fighter.interval
		_play_lai("Fight")
		return target
	if _anim != "Fight":
		_play("Standby")
	return null


## Pha 2: ra don. Goi sau khi CA HAI ben da chot muc tieu.
## Tra ve ket qua cua don ({damage, skill, crit}); rong neu khong danh.
func resolve(victim: BattleUnit) -> Dictionary:
	if victim == null or fighter == null:
		return {}
	return fighter.strike(victim.fighter, _rng, _rules)


## Chon muc tieu: gan nhat, nhung khoang cach theo truc y duoc tinh nang hon
## nen doi thu CUNG LAN luon duoc uu tien. Nho vay tran thanh may cap danh
## nhau theo hang, nhin ra duoc ai danh ai.
func _nearest(enemies: Array, snap: Dictionary) -> BattleUnit:
	var best: BattleUnit = null
	var best_d := INF
	var here: Array = snap[self]
	for e in enemies:
		if not e.alive():
			continue
		var s: Array = snap[e]
		var dx: float = s[0] - here[0]
		var dy: float = s[1] - here[1]
		var ly := dy * LANE_WEIGHT
		var cost := dx * dx + ly * ly
		if cost < best_d:
			best_d = cost
			best = e
	return best


## Chep toa do mo phong sang `position` de ve. Chi hinh anh moi dung Vector2.
func _sync() -> void:
	position = Vector2(sx, sy)


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	fighter.hp = 0.0
	_anim = ""
	_play("Death")
	if rig != null:
		# KHONG dung z_index o day. Cac bo phan trong rig dat z 0..23 theo kieu
		# TUONG DOI voi rig, nen ha rig xuong -1 lam moi manh thanh -1..22:
		# manh sau cung tut xuong duoi ca nen (bien mat), so con lai nhay len
		# tren ca nguoi con song. Ket qua la vu khi bay lo lung giua man hinh.
		# Lam mo la du de phan biet xac voi nguoi song; advance() mo tiep ve 0
		# roi an han (xem DEATH_FADE) de xac khong chong dong thanh vet den.
		rig.modulate = Color(0.7, 0.7, 0.76, 0.85)
	_death_timer = 0.0
	died.emit(self)


func _process(delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if fighter == null or state == State.DEAD:
		return
	var frac: float = clampf(fighter.hp / fighter.hp_max, 0.0, 1.0)
	var x := -BAR_W * 0.5
	draw_rect(Rect2(x - 1, BAR_Y - 1, BAR_W + 2, BAR_H + 2), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(x, BAR_Y, BAR_W, BAR_H), Color(0.22, 0.05, 0.05))
	var col := Color(0.35, 0.78, 0.35) if team == 0 else Color(0.85, 0.42, 0.35)
	draw_rect(Rect2(x, BAR_Y, BAR_W * frac, BAR_H), col)
	# vach no: day thi don sau la ky nang
	var anger: float = clampf(fighter.anger / float(_rules.get("angerFull", 100.0)), 0.0, 1.0)
	draw_rect(Rect2(x, BAR_Y + BAR_H + 1, BAR_W * anger, 2.0), Color(0.95, 0.8, 0.25))
