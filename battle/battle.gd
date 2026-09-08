# Man tran: hai doi chay vao nhau, danh nhau, co thanh mau.
#
#   R           danh lai voi cung doi hinh
#   N           boc doi hinh moi
#   space       tam dung
#   1 / 2 / 3   toc do 1x / 2x / 4x
#
# Chay khong mo cua so, danh N tran roi bao ket qua — dung de kiem tra vong
# lap co ket thuc va co thien vi ben nao khong:
#
#   godot --headless --path . battle/battle.tscn -- --sim=200
#   godot --headless --path . battle/battle.tscn -- --sim=200 --mirror
extends Node2D

const TEAM_SIZE := 4
const LEFT_X := 120.0
const RIGHT_X := 840.0
const MID_Y := 340.0
const ROW_GAP := 88.0
const BODY := 44.0          ## khoang cach toi thieu giua hai don vi
const RIG_SCALE := 0.55
const ART := "res://assets_ref/"

var combat: Combat
var rng := RandomNumberGenerator.new()
var teams: Array = [[], []]
var roster: Array = [[], []]
var finished := false
var elapsed := 0.0
var label: Label = null
var picks_seed := 0


func _ready() -> void:
	label = $Info
	combat = Combat.new()
	var err := combat.load_data()
	if err != "":
		label.text = err
		push_error(err)
		return

	var opts := _cli()
	if opts.has("sim"):
		_run_headless(int(opts["sim"]), opts.has("mirror"))
		return

	picks_seed = int(opts.get("seed", "1"))
	_new_rosters(picks_seed)
	_spawn()
	if opts.has("shot"):
		await _shoot(opts["shot"], float(opts.get("at", "6")))


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


func _spawn(with_art := true) -> void:
	_clear()
	finished = false
	elapsed = 0.0
	rng.seed = 20260908 + picks_seed
	for t in 2:
		for i in roster[t].size():
			var hero_name: String = roster[t][i]
			var u := BattleUnit.new()
			u.visual = with_art
			u.position = Vector2(
					LEFT_X if t == 0 else RIGHT_X,
					MID_Y + (float(i) - (roster[t].size() - 1) * 0.5) * ROW_GAP)
			add_child(u)
			u.setup(combat.make(hero_name), t, combat.rules, rng,
					(ART + hero_name) if with_art else "", RIG_SCALE)
			teams[t].append(u)
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
			snap[u] = u.position

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
func _separate() -> void:
	var all := []
	for t in 2:
		for u in teams[t]:
			if u.alive():
				all.append(u)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: BattleUnit = all[i]
			var b: BattleUnit = all[j]
			var d := b.position - a.position
			var dist := d.length()
			if dist >= BODY or dist < 0.001:
				continue
			var push := d / dist * (BODY - dist) * 0.5
			a.position -= push
			b.position += push


func _process(delta: float) -> void:
	if finished or teams[0].is_empty():
		return
	var out := _step(delta)
	if out >= 0:
		finished = true
	_refresh(out)


func _refresh(out := -1) -> void:
	if label == null:
		return
	var txt := "%s  %d/%d   vs   %d/%d  %s\n%.1fs" % [
			", ".join(roster[0]), _alive(0), teams[0].size(),
			_alive(1), teams[1].size(), ", ".join(roster[1]), elapsed]
	if out == 0:
		txt += "   —  DOI TRAI THANG"
	elif out == 1:
		txt += "   —  DOI PHAI THANG"
	elif out == 2:
		txt += "   —  HOA"
	else:
		txt += "\nR danh lai   N doi hinh moi   space tam dung   1/2/3 toc do"
	label.text = txt


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_R:
			_spawn()
		KEY_N:
			picks_seed += 1
			_new_rosters(picks_seed)
			_spawn()
		KEY_SPACE:
			get_tree().paused = not get_tree().paused
		KEY_1:
			Engine.time_scale = 1.0
		KEY_2:
			Engine.time_scale = 2.0
		KEY_3:
			Engine.time_scale = 4.0


## Chay tran toi giay `at` roi chup mot khung va thoat.
func _shoot(path: String, at: float) -> void:
	while elapsed < at and not finished:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("chup %s -> %s" % [path, "ok" if err == OK else "loi %d" % err])
	get_tree().quit()


## Danh n tran khong ve gi, buoc thoi gian co dinh. Dung de kiem tra tran co
## ket thuc khong, va voi doi hinh guong thi co thien vi ben nao khong.
func _run_headless(n: int, mirror: bool) -> void:
	var dt := 1.0 / 30.0
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
