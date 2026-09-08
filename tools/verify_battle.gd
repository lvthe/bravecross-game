# Doi chieu ban GDScript cua mo hinh chien dau voi ban Python.
#
#   godot --headless --path . --script tools/verify_battle.gd
#
# data_ref/battle_data.json co san khoi `reference`: ti le thang cua mot so cap
# tuong do sim/battle.py tinh. O day danh lai dung cac cap do bang
# battle/combat.gd roi so sanh.
#
# Hai ban dung bo sinh so ngau nhien khac nhau nen khong the trung tung tran.
# Nguong dat theo sai so lay mau: voi n tran, do lech chuan cua ti le la
# sqrt(p(1-p)/n); lay 3 lan do lech chuan cua ca hai phia, toi thieu 3 diem.
extends SceneTree

const N := 4000

var n_pass := 0
var n_fail := 0


func _check(ok: bool, desc: String, detail: String = "") -> void:
	if ok:
		n_pass += 1
		print("  dat   ", desc)
	else:
		n_fail += 1
		print("  HONG  ", desc, "" if detail == "" else "  -> " + detail)


func _tolerance(p_pct: float, n_ref: int) -> float:
	# 3 sigma cua ca hai phep do cong lai, san 3 diem.
	var p: float = clampf(p_pct / 100.0, 0.0, 1.0)
	var sd := sqrt(maxf(p * (1.0 - p), 0.0001) / float(n_ref))
	var sd2 := sqrt(maxf(p * (1.0 - p), 0.0001) / float(N))
	return maxf(3.0, 300.0 * (sd + sd2))


func _init() -> void:
	var c := Combat.new()
	var err := c.load_data()
	if err != "":
		print(err)
		quit(1)
		return

	print("doc %d tuong, %d cap doi chieu" % [c.order.size(), c.reference.size()])
	print("cong thuc: giam sat thuong = %s, GrowthFactor = %s\n"
			% [c.rules.get("mitigation"), c.rules.get("useGrowth")])

	print("=== 1. chi so quy doi dung ===")
	var f := c.make(c.order[0])
	_check(f != null and f.hp_max > 0.0 and f.ap_max >= f.ap_min,
			"dung duoc tuong dau tien (%s)" % c.order[0])
	_check(f != null and f.hp == f.hp_max and f.anger == 0.0, "bat dau day mau, khong no")

	print("\n=== 2. cung seed ra cung ket qua ===")
	var r1 := c.match_up(c.order[0], c.order[1], 200, 7)
	var r2 := c.match_up(c.order[0], c.order[1], 200, 7)
	_check(r1 == r2, "cung seed -> cung ket qua", "%s vs %s" % [r1, r2])
	_check(int(r1["win"]) + int(r1["lose"]) + int(r1["draw"]) == 200,
			"thang + thua + hoa = so tran")

	print("\n=== 3. doi chieu voi mo phong Python ===")
	for e in c.reference:
		var a: String = e["a"]
		var b: String = e["b"]
		if not c.heroes.has(a) or not c.heroes.has(b):
			_check(false, "%s vs %s: thieu tuong trong bo du lieu" % [a, b])
			continue
		var got := c.match_up(a, b, N, 20260908)
		var pct := 100.0 * float(got["win"]) / float(N)
		var want := float(e["winPctA"])
		var tol := _tolerance(want, int(e["battles"]))
		_check(absf(pct - want) <= tol,
				"%-18s vs %-18s  GDScript %5.1f%%  Python %5.1f%%  (lech %.1f, cho phep %.1f)"
						% [a, b, pct, want, absf(pct - want), tol])

	print("\n=== 4. tinh chat khong phu thuoc so lieu ===")
	# Tuong danh voi chinh no: khong duoc thien vi ben nao.
	var mirror := c.match_up(c.order[0], c.order[0], 1000, 99)
	var w := int(mirror["win"])
	var l := int(mirror["lose"])
	_check(w + l == 0 or absf(float(w - l)) <= maxf(40.0, 0.15 * float(w + l)),
			"tuong danh voi chinh no khong thien vi ben nao",
			"thang %d, thua %d, hoa %d" % [w, l, int(mirror["draw"])])

	# Sat thuong khong bao gio duoi 1, ke ca don yeu nhat vao muc thu cao nhat.
	var lo := INF
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var weakest := c.order[0]
	var toughest := c.order[0]
	for n in c.order:
		if int(c.heroes[n]["AttackCapability"]) < int(c.heroes[weakest]["AttackCapability"]):
			weakest = n
		if int(c.heroes[n]["Viability"]) > int(c.heroes[toughest]["Viability"]):
			toughest = n
	var atk := c.make(weakest)
	var def := c.make(toughest)
	for i in 500:
		lo = minf(lo, float(atk.strike(def, rng, c.rules)["damage"]))
	_check(lo >= 1.0, "don yeu nhat (%s) vao muc thu cao nhat (%s) van >= 1"
			% [weakest, toughest], str(lo))

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)
