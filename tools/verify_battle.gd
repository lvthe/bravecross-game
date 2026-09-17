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
	var rng := Combat.Rng.new(5)
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

	# --- toc do di chuyen lay tu map/*_config.xml, khong tu MovingSpeed
	# `MovingSpeed` KHONG co trong libgame.so (quet bang ten chi so quanh
	# 0x7b42f0: co AttackInterval, InjuryRates, NpcSize... khong co no), va
	# client chi dung no lam chi so hien thi. Toc do that nam o <sMove> ->
	# <ptVector>, don vi o, 1 o = 100 px.
	_check(absf(MoveRef.di("Defender") - 130.0) < 0.01,
			"Defender di 130 px/giay (move_near, 1.3 o)", str(MoveRef.di("Defender")))
	_check(absf(MoveRef.chay("Defender") - 300.0) < 0.01,
			"Defender chay 300 px/giay", str(MoveRef.chay("Defender")))
	_check(absf(MoveRef.chay("Archer") - 250.0) < 0.01,
			"Archer chay cham hon bo binh (2.5 o)", str(MoveRef.chay("Archer")))
	_check(absf(MoveRef.chay("Cavalry") - 350.0) < 0.01,
			"Cavalry chay nhanh hon bo binh (3.5 o)", str(MoveRef.chay("Cavalry")))
	_check(MoveRef.di("KhongCoSpriteNay") == 0.0,
			"sprite la thi tra 0 chu khong doan")

	# --- luat DI hay CHAY, do tu libgame.so (ham 0x413bd4, ban vn).
	# Nguong = 4 x be ngang O = 400 px; `+=` (vcmpe + it pl la `>=`).
	_check(BattleUnit.NGUONG_CHAY == 400.0 and BattleUnit.CHAY_O == 4.0
			and BattleUnit.O_PX == 100.0,
			"nguong chay = 4 O x 100 px = 400 px", str(BattleUnit.NGUONG_CHAY))
	_check(BattleUnit.nen_chay(500.0, true) and BattleUnit.nen_chay(-500.0, true),
			"xa hon 4 O thi chay (ca hai chieu)")
	_check(BattleUnit.nen_chay(400.0, true), "dung bang nguong thi CHAY (>=, khong phai >)")
	_check(not BattleUnit.nen_chay(399.9, true), "gan hon nguong thi di")
	_check(not BattleUnit.nen_chay(500.0, false), "chua biet toc do chay thi di, khong doan")

	# --- va chinh buoc di phai dung con so do: xa thi buoc dai bang toc do CHAY.
	# Dung mot don vi that (visual = false nen khong dung armature).
	var u_ta := BattleUnit.new()
	u_ta.visual = false
	u_ta.setup(c.make(c.order[0]), 0, c.rules, Combat.Rng.new(11), "",
			1.0, "", "Defender")
	var u_dich := BattleUnit.new()
	u_dich.visual = false
	u_dich.setup(c.make(c.order[0]), 1, c.rules, Combat.Rng.new(12), "",
			1.0, "", "Defender")
	u_ta.target = u_dich
	# Nguong 400 px: dat muc tieu o 500 px (chay) va o 300 px (di), do buoc di
	# duoc trong dung 1 giay. Toc do Defender: di 130, chay 300 px/giay.
	u_ta.sx = 0.0
	u_ta.sy = 0.0
	u_ta.advance(1.0, [], {u_ta: [0.0, 0.0], u_dich: [500.0, 0.0]})
	_check(absf(u_ta.sx - 300.0) < 0.01, "muc tieu o 500 px -> di duoc 300 px (CHAY)",
			str(u_ta.sx))
	u_ta.sx = 0.0
	u_ta.sy = 0.0
	u_ta.advance(1.0, [], {u_ta: [0.0, 0.0], u_dich: [300.0, 0.0]})
	_check(absf(u_ta.sx - 130.0) < 0.01, "muc tieu o 300 px -> di duoc 130 px (di)",
			str(u_ta.sx))
	# Khong biet sprite thi van di 130... khong: lay du phong theo chi so, va
	# KHONG chay (khong doan toc do chay).
	var u_la := BattleUnit.new()
	u_la.visual = false
	u_la.setup(c.make(c.order[0]), 0, c.rules, Combat.Rng.new(13), "",
			1.0, "", "KhongCoSpriteNay")
	u_la.target = u_dich
	u_la.sx = 0.0
	u_la.sy = 0.0
	u_la.advance(1.0, [], {u_la: [0.0, 0.0], u_dich: [500.0, 0.0]})
	_check(u_la.speed_chay == 0.0 and absf(u_la.sx - u_la.speed) < 0.01,
			"sprite la: khong chay, van di theo toc do du phong", str(u_la.sx))
	u_ta.free()
	u_dich.free()
	u_la.free()

	print("\n=== 5. anh xa truong sang ben danh / ben chiu (Harm) ===")
	# Doc ra tu cho dien struct 0x41ab82..0x41ad08: nDp va fReducingDamage lay tu
	# BEN CHIU, con nguyen to / xuyen / DamageAddition / DamageMultiples lay tu
	# BEN DANH. Xem dau battle/harm.gd.
	var ben_danh := {"FireAp": 40.0, "PiercingAp": 7.0, "DamageMultiplesAtDogface": 1.0,
			"DamageMultiplesAtBoss": 3.0, "DamageMultiplesAtHero": 2.0}
	var ben_chiu := {"DP": 0.0, "ReducingDamage": 10.0}
	# Khong giap: dmg = max(FireAp,0) + atk + PiercingAp - ReducingDamage.
	_check(absf(Harm.tinh(100.0, ben_danh, ben_chiu, false) - 137.0) < 0.01,
			"nguyen to + xuyen cua ben danh, giam sat thuong cua ben chiu",
			str(Harm.tinh(100.0, ben_danh, ben_chiu, false)))
	# Dat cung nhung con so do o BEN CHIU thi khong duoc an thua gi.
	var chiu_2 := ben_chiu.duplicate()
	chiu_2["FireAp"] = 999.0
	chiu_2["PiercingAp"] = 999.0
	chiu_2["DamageAddition"] = 9999.0
	_check(absf(Harm.tinh(100.0, ben_danh, chiu_2, false) - 137.0) < 0.01,
			"nguyen to / xuyen / DamageAddition cua BEN CHIU khong duoc tinh",
			str(Harm.tinh(100.0, ben_danh, chiu_2, false)))
	# 0x3d49d4: chon o he so nhan theo LOAI muc tieu. NpcType 5 = boss
	# (CUIChapterInfo.lua:1182 dung sBossIcon cho NpcType == 5).
	var chiu_boss := ben_chiu.duplicate()
	chiu_boss["NpcType"] = 5
	_check(absf(Harm.tinh(100.0, ben_danh, chiu_boss, false) - 137.0 * 3.0) < 0.01,
			"muc tieu NpcType == 5 -> dung DamageMultiplesAtBoss",
			str(Harm.tinh(100.0, ben_danh, chiu_boss, false)))
	_check(absf(Harm.tinh(100.0, ben_danh, chiu_boss, true) - 137.0 * 2.0) < 0.01,
			"muc tieu la tuong thi AtHero thang, du NpcType == 5",
			str(Harm.tinh(100.0, ben_danh, chiu_boss, true)))
	# 0x380cde: he so bo qua giap chi nhan khi nDp > 0.
	var danh_bo_qua := {"IgnoreDp": 0.5, "DamageMultiplesAtDogface": 1.0}
	var chiu_am := {"DP": -100.0}
	var dd := -100.0
	var mong := 100.0 * (1.0 - minf(1.0, dd / (dd + 1500.0)))
	_check(absf(Harm.tinh(100.0, danh_bo_qua, chiu_am, false) - mong) < 0.01,
			"giap AM thi khong nhan he so bo qua giap",
			"%.3f can %.3f" % [Harm.tinh(100.0, danh_bo_qua, chiu_am, false), mong])

	print("
=== 6. so lieu ky nang thuc tinh (WakeRef) ===")
	# So don = 1 + so truong `fSectionIntervalWake_F<n>` cua khoi <fight>
	# `fight_<Sprite>Wake`, chan tren boi `nAttackSectionLimitWake`.
	_check(WakeRef.so_don("ZhaoYun") == 1,
			"Trieu Van 1 don (khong co fSectionIntervalWake_F<n>)", str(WakeRef.so_don("ZhaoYun")))
	_check(WakeRef.so_don("GuanYu") == 6, "Quan Vu 6 don (F1..F5)", str(WakeRef.so_don("GuanYu")))
	_check(WakeRef.so_don("CaoZhi") == 3, "Tao Thuc 3 don (nAttackSectionLimitWake = 3)",
			str(WakeRef.so_don("CaoZhi")))
	_check(absf(WakeRef.them("ZhaoYun") - 0.47) < 0.001, "fDamageBonusWake cua Trieu Van = 0.47",
			str(WakeRef.them("ZhaoYun")))
	# `nSplitWake` = so muc tieu CHIA DEU sat thuong (khong phai so don):
	# global_config.xml ghi <nSplitNumForAOE>6</nSplitNumForAOE> ngay duoi chu
	# thich "群攻分摊个数" = so muc tieu don danh dien rong chia deu sat thuong.
	_check(absf(WakeRef.chia("ZhaoYun", 6) - 1.0) < 0.001,
			"6 muc tieu <= nSplitWake 12 -> khong chia", str(WakeRef.chia("ZhaoYun", 6)))
	_check(absf(WakeRef.chia("ZhaoYun", 24) - 0.5) < 0.001,
			"24 muc tieu -> chia con 0.5, chan boi fSplitFloorWake", str(WakeRef.chia("ZhaoYun", 24)))
	_check(WakeRef.so_don("KhongCoSpriteNay") == 0,
			"sprite la thi tra 0 chu khong doan")

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)
