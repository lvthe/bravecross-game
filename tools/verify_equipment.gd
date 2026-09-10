# Doi chieu ban GDScript cua luat trang bi voi ban Python.
#
#   godot --headless --path . --script tools/verify_equipment.gd
#
# data_ref/equipment_ref.json do `python sim/equipment.py --export` sinh ra:
# 168 ca, moi ca kem ket qua ma sim/equipment.py tinh duoc. O day tinh lai
# bang battle/equipment.gd roi so.
#
# Khac phep doi chieu cua mo hinh chien dau: cho nay KHONG co ngau nhien, nen
# khong lay nguong theo sai so lay mau — hai ban deu float64, cung thu tu phep
# tinh, phai ra gan nhu dung mot so. Nguong 1e-9 tuong doi chi de bo qua sai
# so lam tron cuoi cung.
extends SceneTree

const REF := "res://data_ref/equipment_ref.json"
const TOL := 1e-9

var n_pass := 0
var n_fail := 0


func _check(ok: bool, desc: String, detail: String = "") -> void:
	if ok:
		n_pass += 1
		print("  dat   ", desc)
	else:
		n_fail += 1
		print("  HONG  ", desc, "" if detail == "" else "  -> " + detail)


func _close(a: float, b: float) -> bool:
	return absf(a - b) <= TOL * maxf(1.0, maxf(absf(a), absf(b)))


func _init() -> void:
	var txt := FileAccess.get_file_as_string(REF)
	if txt.is_empty():
		print("thieu ", REF, " — chay:  python sim/equipment.py --export")
		quit(1)
		return
	var doc = JSON.parse_string(txt)
	if not doc is Dictionary or not doc.has("cases"):
		print(REF, " khong phai bo ca doi chieu")
		quit(1)
		return

	print("=== 1. hang so khop ban Python ===")
	_check(_close(Equipment.INTENSIFY_STEP, float(doc["intensifyStep"])),
			"buoc cuong hoa", "%.17f vs %.17f"
			% [Equipment.INTENSIFY_STEP, float(doc["intensifyStep"])])
	_check(Equipment.APPEND_UNLOCK_LEVEL == int(doc["appendUnlockLevel"]),
			"cap mo thuoc tinh phu")
	_check(Equipment.RECAST_ITEM_ID == int(doc["recastItemId"]),
			"id da tay luyen")
	var rng: Array = doc["appendRange"]
	_check(_close(Equipment.APPEND_RANGE_MIN, float(rng[0]))
			and _close(Equipment.APPEND_RANGE_MAX, float(rng[1])),
			"dai ngau nhien thuoc tinh phu")
	var w_bad := []
	for k in doc["weights"]:
		var t := int(String(k))
		if not _close(Equipment.weight_of(t), float(doc["weights"][k])):
			w_bad.append(k)
	_check(w_bad.is_empty(), "%d trong so luc chien" % doc["weights"].size(),
			str(w_bad))

	print("\n=== 2. %d ca: tung con so mot ===" % doc["cases"].size())
	# In tung ca thi 168 dong x 8 truong lut man; gom lai theo TRUONG, va khi
	# lech thi neu ro ca dau lech bao nhieu — du de lan ra cho sai.
	var fields := ["increment", "propVal", "total", "cost", "costTo",
			"qualityRange", "capacity", "capacityOrig",
			"refinePercent", "refineCost", "mainValue"]
	var bad := {}
	var worst := {}
	for f in fields:
		bad[f] = 0
		worst[f] = ""
	var stats_bad := 0
	var stats_note := ""

	for c in doc["cases"]:
		var ptype := int(c["prop"])
		var base := float(c["base"])
		var lv := int(c["level"])
		var iv := int(c["intensify"])
		var rf := int(c["refine"])
		var pt := int(c["part"])
		var e := Equipment.new(pt, ptype, base, lv, iv, 2,
				[[Equipment.CRITICAL_STRIKE, 0.05], [Equipment.HP_LIMIT, 120.0]], rf)
		var got := {
			"increment": Equipment.intensify_increment(iv, base),
			"propVal": Equipment.intensify_property_val(base, ptype),
			"total": Equipment.intensify_total(iv, base),
			"cost": Equipment.intensify_cost(maxi(1, iv)),
			"costTo": e.cost_to_level(iv + 5),
			"qualityRange": Equipment.quality_range(base, 10.0, 2.0),
			"capacity": e.capacity(),
			"capacityOrig": e.capacity_as_original(),
			"refinePercent": Equipment.refine_percent(rf),
			"refineCost": e.refine_cost_next(),
			"mainValue": e.effective_main(),
		}
		for f in fields:
			var want := float(c[f])
			if not _close(float(got[f]), want):
				bad[f] += 1
				if worst[f] == "":
					worst[f] = ("loai %d, goc %.1f, cap %d, +%d, tinh luyen %d, o %d: "
							+ "GD %.10f vs PY %.10f") % [ptype, base, lv, iv, rf, pt,
							got[f], want]
		# Bang chi so: dung so khoa va dung tung gia tri.
		var st := e.stats()
		var want_st: Dictionary = c["stats"]
		if st.size() != want_st.size():
			stats_bad += 1
			if stats_note == "":
				stats_note = "so chi so %d vs %d" % [st.size(), want_st.size()]
		else:
			for k in want_st:
				var t := int(String(k))
				if not st.has(t) or not _close(float(st[t]), float(want_st[k])):
					stats_bad += 1
					if stats_note == "":
						stats_note = "chi so %s: %s vs %s" \
								% [k, st.get(t, "thieu"), want_st[k]]
					break

	var n: int = doc["cases"].size()
	for f in fields:
		_check(bad[f] == 0, "%-13s khop ca %d ca" % [f, n],
				"%d ca lech; %s" % [bad[f], worst[f]])
	_check(stats_bad == 0, "%-13s khop ca %d ca" % ["stats", n],
			"%d ca lech; %s" % [stats_bad, stats_note])

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)
