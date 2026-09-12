# Tran cua g_BattleField gia (lua/san_tran.lua): doc quan tu du lieu goc, va
# danh tuc thi khi can.
#
# Ban goc danh tran trong C++ (libgame.so): Lua chi dua du lieu vao qua
# setSendTroops / setLevelData (CUIGame.lua:924-925). Du lieu do da la CHI SO
# THAT do luat goc tinh (FightLogic cua sc/share): HP, MinAp/MaxAp, DP,
# AttackInterval, CriticalStrike... cua tung tuong va tung loai linh, da tinh
# cap. O day dung dung cac so do.
#
# Cach GOP chi so thanh sat thuong (Combat.Fighter.strike, cung mo hinh voi
# battle/ va sim/) va cach hai ben ap sat nhau la cua ta — phan do cua ban goc
# nam trong ma may C++, chua giai duoc.
#
# Tran CO HINH o battle/san_tran_ve.gd; file nay cho no doc_quan / tong_ket, va
# tu danh tuc thi (danh) cho che do tinh nhanh (setQuickResult cua ban goc).
extends RefCounted


## Danh mot tran TUC THI, khong hinh: hai hang, tung cap dau mat nhau theo thu
## tu, dich xep theo nhom tu trai sang phai. Tra ve CHUOI JSON cua tong_ket().
static func danh(ta_json: String, dich_json: String, hat: int) -> String:
	var cb := Combat.new()
	var loi := cb.load_data()
	if loi != "":
		return JSON.stringify(_loi(loi))
	var ta = JSON.parse_string(ta_json) if ta_json != "" else null
	var dich = JSON.parse_string(dich_json) if dich_json != "" else null
	if not (ta is Dictionary) or not (dich is Dictionary):
		return JSON.stringify(_loi("setSendTroops / setLevelData khong phai JSON object"))
	var rules: Dictionary = cb.rules
	var q := doc_quan(ta, dich, rules)
	var doi_ta: Array = q["ta"]
	var doi_dich: Array = q["dich"]
	# Nhom trai truoc; trong nhom giu nguyen thu tu (sort_custom khong on dinh).
	doi_dich.sort_custom(func(p, r):
		return float(p["pos_x"]) * 100000.0 + float(p["thu_tu"]) \
				< float(r["pos_x"]) * 100000.0 + float(r["thu_tu"]))
	var max_t := float(q["max_t"])

	var rng := Combat.Rng.new(hat)
	var sat := {}
	var i := 0
	var j := 0
	var t := 0.0
	var na := INF
	var nb := INF
	if not doi_ta.is_empty():
		na = (doi_ta[0]["f"] as Combat.Fighter).interval
	if not doi_dich.is_empty():
		nb = (doi_dich[0]["f"] as Combat.Fighter).interval
	while i < doi_ta.size() and j < doi_dich.size():
		var a: Combat.Fighter = doi_ta[i]["f"]
		var b: Combat.Fighter = doi_dich[j]["f"]
		t = minf(na, nb)
		if t > max_t:
			t = max_t
			break
		if na <= t + 1e-9:
			var r := a.strike(b, rng, rules)
			if doi_ta[i]["tuong"]:
				var key := str(doi_ta[i]["id"])
				sat[key] = float(sat.get(key, 0.0)) + float(r["damage"])
			na += a.interval
		if nb <= t + 1e-9:
			# Ke vua chet trong nhip nay thi khong danh tra.
			if b.alive() and a.alive():
				b.strike(a, rng, rules)
			nb += b.interval
		if not b.alive():
			j += 1
			if j < doi_dich.size():
				nb = t + (doi_dich[j]["f"] as Combat.Fighter).interval
		if not a.alive():
			i += 1
			if i < doi_ta.size():
				na = t + (doi_ta[i]["f"] as Combat.Fighter).interval
	var thang := j >= doi_dich.size() and i < doi_ta.size()
	return JSON.stringify(tong_ket(doi_ta, doi_dich, t, sat, thang))


## Doc hai doi quan tu du lieu ban goc gui cho engine. Moi muc:
##   f (Combat.Fighter), id, tuong, ten / sprite (ten armature), pos_x (o tren
##   san), xuat_hien (AppearTime cua nhom), co (NpcSize), thu_tu.
## Quan ta: Sprite.Troop.Soldiers, chi so o Sprite[<Data>], dung o Troop.PosX.
## Quan dich: Groups[].Soldiers, chi so o Data[<Data>], dung o PosX cua nhom.
static func doc_quan(ta: Dictionary, dich: Dictionary, rules: Dictionary) -> Dictionary:
	var sprite: Dictionary = ta.get("Sprite", {})
	var troop = sprite.get("Troop", {})
	var px_ta := float(troop.get("PosX", 0)) if troop is Dictionary else 0.0
	var doi_ta: Array = []
	for s in _ds(troop.get("Soldiers", []) if troop is Dictionary else []):
		if not (s is Dictionary):
			continue
		var cs = sprite.get(String(s.get("Data", "")), null)
		if not (cs is Dictionary):
			continue
		for k in maxi(1, int(s.get("Num", 1))):
			doi_ta.append(_muc(cs, rules, int(s.get("ID", 0)), bool(s.get("IsHero", false)),
					px_ta, 0.0, doi_ta.size()))

	var bang: Dictionary = dich.get("Data", {})
	var doi_dich: Array = []
	for g in _ds(dich.get("Groups", [])):
		if not (g is Dictionary):
			continue
		for s in _ds(g.get("Soldiers", [])):
			if not (s is Dictionary):
				continue
			var cs = bang.get(String(s.get("Data", "")), null)
			if not (cs is Dictionary):
				continue
			# Num = 0 thi khong ra tran: nhom dau cua L_N_01_01 co nam NPC
			# Num = 0 (cap 0), dung o nhom PosX = 0.
			for k in int(s.get("Num", 0)):
				doi_dich.append(_muc(cs, rules, int(s.get("NpcID", 0)), false,
						float(g.get("PosX", 0)), float(g.get("AppearTime", 0)), doi_dich.size()))

	var chapter = sprite.get("Chapter", {})
	var max_t := float(chapter.get("ChapterGameTime", 300)) if chapter is Dictionary else 300.0
	if max_t <= 0.0:
		max_t = 300.0
	return {"ta": doi_ta, "dich": doi_dich, "max_t": max_t}


static func _muc(cs: Dictionary, rules: Dictionary, id: int, tuong: bool, pos_x: float,
		xuat_hien: float, thu_tu: int) -> Dictionary:
	var co := float(cs.get("NpcSize", 1))
	return {"f": _chien_binh(cs, rules), "id": id, "tuong": tuong,
			"ten": String(cs.get("Name", "")), "sprite": String(cs.get("SpriteName", "")),
			"pos_x": pos_x, "xuat_hien": xuat_hien, "co": co if co > 0.0 else 1.0,
			"thu_tu": thu_tu}


## Ket qua tran, dung hinh ma lua/san_tran.lua doc:
##   thang, giay, song (so tuong ta con song), ta_con [{ID, HP, Fury}],
##   dich_con [{ID, NpcID, HP, Fury}], ta_pct, dich_pct (mau con / mau goc),
##   sat_thuong_tuong {id tuong: sat thuong}, loi.
static func tong_ket(ds_ta: Array, ds_dich: Array, giay: float, sat: Dictionary,
		thang: bool) -> Dictionary:
	var song := 0
	var hp_ta := 0.0
	var goc_ta := 0.0
	var ta_con: Array = []
	for e in ds_ta:
		var f: Combat.Fighter = e["f"]
		goc_ta += f.hp_max
		if f.alive():
			hp_ta += f.hp
			if e["tuong"]:
				song += 1
				ta_con.append({"ID": e["id"], "HP": f.hp, "Fury": f.anger})
	var hp_dich := 0.0
	var goc_dich := 0.0
	var dich_con: Array = []
	for e in ds_dich:
		var f: Combat.Fighter = e["f"]
		goc_dich += f.hp_max
		if f.alive():
			hp_dich += f.hp
			dich_con.append({"ID": e["id"], "NpcID": e["id"], "HP": f.hp, "Fury": f.anger})
	return {"thang": thang, "giay": giay, "song": song, "ta_con": ta_con,
			"dich_con": dich_con,
			"ta_pct": hp_ta / goc_ta if goc_ta > 0.0 else 0.0,
			"dich_pct": hp_dich / goc_dich if goc_dich > 0.0 else 0.0,
			"sat_thuong_tuong": sat, "loi": ""}


static func _loi(s: String) -> Dictionary:
	return {"thang": false, "giay": 0.0, "song": 0, "ta_con": [], "dich_con": [],
			"ta_pct": 0.0, "dich_pct": 0.0, "sat_thuong_tuong": {}, "loi": s}


## Mot chien binh tu CHI SO THAT cua ban goc (da tinh cap), dung khuon cua
## Combat.make_army: ban ghi kieu tuong he so 1, roi ghi de bang so that.
static func _chien_binh(s: Dictionary, rules: Dictionary) -> Combat.Fighter:
	var f := Combat.Fighter.new({
		"HeroSprite": String(s.get("Name", "?")),
		"Viability": 1, "AttackCapability": 1, "GrowthFactor": 1, "AddGrowthFactor": 0,
		"InjuryRates": float(s.get("InjuryRates", 0)),
		"SkillInjuryRates": float(s.get("SkillInjuryRates", 0)),
		"AngerRecovery": float(s.get("AngerRecovery", 0)),
		"TalentSkill": "",
	}, {
		"HpBase": float(s.get("HP", 1)),
		"MinApBase": float(s.get("MinAp", 0)),
		"MaxApBase": float(s.get("MaxAp", 0)),
		"DpBase": float(s.get("DP", 0)),
		"AttackInterval": maxf(0.1, float(s.get("AttackInterval", 1))),
		"CriticalStrikeBase": float(s.get("CriticalStrike", 0)),
		"CritDamageDouble": float(s.get("CritDamageDouble", 1.5)),
		"MovingSpeed": float(s.get("MovingSpeed", 30)),
	}, rules)
	f.reach = float(s.get("MaxAttackDistance", 30))
	f.min_reach = float(s.get("MinAttackDistance", 0))
	f.move_speed = float(s.get("MovingSpeed", 30))
	# Giu ban ghi goc cho cong thuc sat thuong that (battle/harm.gd): no doc
	# FireAp, DamageAddition, DamageMultiples... ma Fighter khong mang.
	f.raw = s
	return f


## cjson ma hoa bang Lua co lo thanh object: nhan ca mang lan object.
static func _ds(v) -> Array:
	if v is Array:
		return v
	if v is Dictionary:
		return (v as Dictionary).values()
	return []
