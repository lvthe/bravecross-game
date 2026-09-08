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
var speed := 90.0
var reach := 58.0
var target: BattleUnit = null
var state: State = State.ADVANCE
var cooldown := 0.0
var facing := 1.0
var visual := true

var _rules: Dictionary = {}
var _rng: RandomNumberGenerator = null
var _anim := ""
var _death_timer := 0.0


func setup(f: Combat.Fighter, team_index: int, rules: Dictionary,
		rng: RandomNumberGenerator, art_dir: String = "", art_scale := 1.0) -> void:
	fighter = f
	team = team_index
	_rules = rules
	_rng = rng
	facing = 1.0 if team == 0 else -1.0
	# Don dau tien roi vao luc hoi chieu xong, giong mo phong Python.
	cooldown = fighter.interval
	if visual and art_dir != "":
		rig = SngRig.build(art_dir)
		if rig != null:
			rig.scale = Vector2(facing * art_scale, art_scale)
			add_child(rig)
			_play("Standby")


func _play(anim_name: String) -> void:
	if rig == null or _anim == anim_name:
		return
	if rig.play(anim_name):
		_anim = anim_name


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
func advance(delta: float, enemies: Array, snap: Dictionary) -> BattleUnit:
	if state == State.DEAD:
		_death_timer += delta
		return null
	if not alive():
		die()
		return null

	if target == null or not target.alive():
		target = _nearest(enemies, snap)
	if target == null:
		_play("Standby")
		return null

	var here: Vector2 = snap.get(self, position)
	var there: Vector2 = snap.get(target, target.position)
	var to := there - here
	var dist := to.length()

	if dist > reach:
		state = State.ADVANCE
		# Di theo LAN: chay thang mot mach theo truc x, con doi lan thi cham
		# hon nhieu. Neu cho di thang toi muc tieu thi ca tam don vi don ve
		# mot diem giua san roi chong len nhau thanh mot dong.
		position = here + Vector2(
				signf(to.x) * speed * delta,
				clampf(to.y, -speed * LANE_PULL * delta, speed * LANE_PULL * delta))
		if absf(to.x) > 1.0:
			facing = signf(to.x)
			if rig != null:
				rig.scale.x = facing * absf(rig.scale.y)
		_play("Walk")
		return null

	state = State.ATTACK
	cooldown -= delta
	if cooldown <= 0.0:
		cooldown += fighter.interval
		_play("Fight")
		return target
	if _anim != "Fight":
		_play("Standby")
	return null


## Pha 2: ra don. Goi sau khi CA HAI ben da chot muc tieu.
func resolve(victim: BattleUnit) -> void:
	if victim == null or fighter == null:
		return
	fighter.strike(victim.fighter, _rng, _rules)


## Chon muc tieu: gan nhat, nhung khoang cach theo truc y duoc tinh nang hon
## nen doi thu CUNG LAN luon duoc uu tien. Nho vay tran thanh may cap danh
## nhau theo hang, nhin ra duoc ai danh ai.
func _nearest(enemies: Array, snap: Dictionary) -> BattleUnit:
	var best: BattleUnit = null
	var best_d := INF
	var here: Vector2 = snap.get(self, position)
	for e in enemies:
		if not e.alive():
			continue
		var d: Vector2 = snap.get(e, e.position) - here
		var cost := d.x * d.x + (d.y * LANE_WEIGHT) * (d.y * LANE_WEIGHT)
		if cost < best_d:
			best_d = cost
			best = e
	return best


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	fighter.hp = 0.0
	_anim = ""
	_play("Death")
	if rig != null:
		rig.z_index = -1          # xac nam duoi nguoi con song
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
