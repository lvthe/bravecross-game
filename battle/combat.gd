# Ban cai dat GDScript cua mo hinh chien dau.
#
# Mo hinh goc o sim/battle.py (Python). File nay phai cho ra CUNG KET QUA.
# So lieu khong chep tay sang day — doc tu data_ref/battle_data.json do
# sim/export_stats.py sinh ra, trong do co san khoi `reference` la ti le thang
# mot so cap tuong theo ban Python. tools/verify_battle.gd danh lai cac cap do
# bang chinh file nay roi doi chieu; lech qua nguong la bao hong.
#
# Hai ban dung bo sinh so ngau nhien khac nhau (Python: Mersenne Twister,
# Godot: PCG32) nen tung tran khong the trung nhau — chi ti le mo i so sanh
# duoc, va so sanh trong sai so lay mau.
class_name Combat
extends RefCounted

const DATA_PATH := "res://data_ref/battle_data.json"

## Ky nang rieng tung tuong. Phai KHOP tung so voi SKILLS trong sim/battle.py
## va SKILLS trong server/modules/battle.lua.
##
## Ban goc co du lieu ai co ky nang nao (KDBGameHeroTalentSkill.xgg) nhung CHI
## LUU TEN; hieu ung nam o server, khong co trong tay. Bang duoi la thiet ke
## cua ta, dua tren nghia cua cai ten.
const SKILLS := {
	"NuQi":      {"anger": 1.6},        # no khi: no day nhanh -> ky nang no som
	"GongSu":    {"interval": 0.8},     # cong toc: danh nhanh hon
	"ShengMing": {"hp": 1.3},           # sinh menh: nhieu mau
	"TieBi":     {"taken": 0.8},        # thiet bich: chiu it sat thuong
	"BaoJi":     {"crit_add": 0.15},    # bao kich: chi mang nhieu
	"PoJia":     {"pierce": 0.5},       # pha giap: bo qua nua giap
	"FangYu":    {"defence": 2.0},      # phong ngu: giap day
	"GongJi":    {"ap": 1.2},           # cong kich: sat thuong cao
	"ShiXue":    {"lifesteal": 0.15},   # thi huyet: hut mau
}


## Mot tuong da quy ra chi so, giu luon mau va no hien tai.
class Fighter extends RefCounted:
	var name: String
	var job: int
	var rarity: int
	var hp_max: float
	var hp: float
	var anger: float
	var ap_min: float
	var ap_max: float
	var defence: float
	var interval: float
	var crit_chance: float
	var crit_mult: float
	var hit_rate: float
	var skill_rate: float
	var anger_gain: float
	var skill: String
	var taken: float          ## he so sat thuong PHAI CHIU (thuoc ben chiu)
	var pierce: float         ## bo qua bao nhieu phan giap doi phuong
	var lifesteal: float

	func _init(row: Dictionary, base: Dictionary, rules: Dictionary) -> void:
		name = row.get("HeroSprite", "?")
		job = int(row.get("HeroJobType", 0))
		rarity = int(row.get("HeroRarity", 0))
		var g: float = float(row.get("GrowthFactor", 1)) if rules.get("useGrowth", false) else 1.0
		hp_max = float(base["HpBase"]) * float(row["Viability"]) * g
		ap_min = float(base["MinApBase"]) * float(row["AttackCapability"]) * g
		ap_max = float(base["MaxApBase"]) * float(row["AttackCapability"]) * g
		defence = float(base["DpBase"])
		interval = float(base["AttackInterval"])
		crit_chance = float(base["CriticalStrikeBase"]) / 100.0
		crit_mult = float(base["CritDamageDouble"])
		hit_rate = 1.0 + float(row["InjuryRates"])
		skill_rate = 1.0 + float(row["SkillInjuryRates"])
		anger_gain = float(row["AngerRecovery"])

		skill = String(row.get("TalentSkill", ""))
		var e: Dictionary = SKILLS.get(skill, {}) if rules.get("useSkills", true) else {}
		hp_max *= float(e.get("hp", 1.0))
		ap_min *= float(e.get("ap", 1.0))
		ap_max *= float(e.get("ap", 1.0))
		defence *= float(e.get("defence", 1.0))
		interval *= float(e.get("interval", 1.0))
		anger_gain *= float(e.get("anger", 1.0))
		crit_chance += float(e.get("crit_add", 0.0))
		taken = float(e.get("taken", 1.0))
		pierce = float(e.get("pierce", 0.0))
		lifesteal = float(e.get("lifesteal", 0.0))
		reset()

	func reset() -> void:
		hp = hp_max
		anger = 0.0

	func alive() -> bool:
		return hp > 0.0

	## Mot don. Tra ve {damage, skill, crit}.
	func strike(target: Fighter, rng: RandomNumberGenerator, rules: Dictionary) -> Dictionary:
		var ap := rng.randf_range(ap_min, ap_max)
		anger += anger_gain
		# Ten bien la `fired` chu khong phai `skill`: `skill` nay la ten ky
		# nang rieng cua tuong.
		var fired := anger >= float(rules.get("angerFull", 100.0))
		if fired:
			anger = 0.0
		var dmg := ap * (skill_rate if fired else hit_rate)
		# Pha giap: bo qua mot phan giap doi phuong.
		var def_eff := target.defence * (1.0 - pierce)
		if String(rules.get("mitigation", "subtract")) == "divide":
			var k := float(rules.get("defenceK", 100.0))
			dmg *= k / (k + def_eff)
		else:
			dmg -= def_eff
		# Thiet bich: he so nay thuoc ve BEN CHIU, khong phai ben danh.
		dmg *= target.taken
		var crit := rng.randf() < crit_chance
		if crit:
			dmg *= crit_mult
		dmg = maxf(1.0, dmg)
		target.hp -= dmg
		if lifesteal > 0.0:
			hp = minf(hp_max, hp + dmg * lifesteal)
		return {"damage": dmg, "skill": fired, "crit": crit}


var base: Dictionary = {}
var rules: Dictionary = {}
var heroes: Dictionary = {}          ## HeroSprite -> ban ghi
var reference: Array = []
var order: PackedStringArray = []    ## giu dung thu tu trong file


## Doc data_ref/battle_data.json. Tra ve chuoi loi, hoac "" neu doc duoc.
func load_data(path: String = DATA_PATH) -> String:
	if not FileAccess.file_exists(path):
		return ("khong thay %s\n"
				+ "Sinh no bang:  python sim/export_stats.py\n"
				+ "So lieu goc co ban quyen nen khong nam trong repo.") % path
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "%s khong phai JSON hop le" % path
	base = parsed.get("base", {})
	rules = parsed.get("rules", {})
	reference = parsed.get("reference", [])
	heroes.clear()
	order = PackedStringArray()
	for r in parsed.get("heroes", []):
		heroes[r["HeroSprite"]] = r
		order.append(r["HeroSprite"])
	if heroes.is_empty():
		return "%s khong co tuong nao" % path
	return ""


func make(hero_name: String) -> Fighter:
	if not heroes.has(hero_name):
		return null
	return Fighter.new(heroes[hero_name], base, rules)


## Mot tran tay doi, khong do hoa. Tra ve {result, hits, seconds}
## result: 1 = a thang, -1 = b thang, 0 = hoa.
func duel(a: Fighter, b: Fighter, rng: RandomNumberGenerator) -> Dictionary:
	a.reset()
	b.reset()
	var max_seconds := float(rules.get("maxSeconds", 600.0))
	var ta := a.interval
	var tb := b.interval
	var t := 0.0
	var hits := 0
	while t < max_seconds:
		t = minf(ta, tb)
		var acts: Array[Fighter] = []
		if ta <= t + 1e-9:
			acts.append(a)
			ta += a.interval
		if tb <= t + 1e-9:
			acts.append(b)
			tb += b.interval
		for who in acts:
			who.strike(b if who == a else a, rng, rules)
			hits += 1
		if not a.alive() or not b.alive():
			var res := 0
			if a.alive():
				res = 1
			elif b.alive():
				res = -1
			return {"result": res, "hits": hits, "seconds": t}
	return {"result": 0, "hits": hits, "seconds": t}


## Danh n tran giua hai tuong. Tra ve {win, lose, draw}.
func match_up(a_name: String, b_name: String, n: int, seed_value: int = 0) -> Dictionary:
	var a := make(a_name)
	var b := make(b_name)
	if a == null or b == null:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := {"win": 0, "lose": 0, "draw": 0}
	for i in n:
		var r := duel(a, b, rng)
		if r["result"] > 0:
			out["win"] += 1
		elif r["result"] < 0:
			out["lose"] += 1
		else:
			out["draw"] += 1
	return out
