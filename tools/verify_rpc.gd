# Kiem tra phan may chu tu xu tran.
#
#   godot --headless --path . --script tools/verify_rpc.gd -- --url=http://127.0.0.1:7350
#
# Can Nakama that dang chay (server/docker compose up -d). May chu gia khong
# co runtime Lua nen khong thay the duoc o day.
#
# Cau hoi quan trong nhat khong phai "RPC co chay khong" ma la "client con bia
# duoc thanh tich khong". Phan cuong che nam o permission_write = 0 tren ban
# luu; RPC ma thieu no thi chi la hinh thuc. Muc 4 kiem dung cho do.
extends SceneTree

var n_pass := 0
var n_fail := 0


func _check(ok: bool, desc: String, detail: String = "") -> void:
	if ok:
		n_pass += 1
		print("  dat   ", desc)
	else:
		n_fail += 1
		print("  HONG  ", desc, "" if detail == "" else "  -> " + detail)


func _cli() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


func _init() -> void:
	await process_frame
	var opts := _cli()
	var url: String = opts.get("url", NakamaClient.DEFAULT_URL)
	var dev := "rpc-%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	print("may chu: %s\nma thiet bi: %s\n" % [url, dev])

	var ses := PlayerSession.new()
	root.add_child(ses)
	ses._ensure_client()
	ses.client.url = url
	var r := await ses.start("", dev)
	if not bool(r.get("online", false)):
		_check(false, "ket noi duoc Nakama", ses.last_error)
		print("\nCan Nakama that: cd server && docker compose up -d")
		print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
		quit(1)
		return
	_check(true, "ket noi duoc Nakama")

	print("\n=== 1. mo hinh Lua khop mo hinh Python ===")
	var st := await ses.client.call_rpc("bx.selftest", {})
	if not st.ok:
		_check(false, "goi duoc bx.selftest", str(st.get("error", "")))
	else:
		var pairs: Array = st.data.get("pairs", [])
		_check(pairs.size() > 0, "co cap de doi chieu")
		for e in pairs:
			var lua := float(e.get("winPctLua", -1.0))
			var py := float(e.get("winPctPython", -1.0))
			# Hai bo sinh so khac nhau nen chi so sanh duoc ti le, trong sai so
			# lay mau: 3 do lech chuan cua ca hai phep do, san 3 diem.
			var p: float = clampf(py / 100.0, 0.0, 1.0)
			var sd := sqrt(maxf(p * (1.0 - p), 0.0001) / 4000.0)
			var tol := maxf(3.0, 600.0 * sd)
			_check(absf(lua - py) <= tol,
					"%-18s vs %-18s  Lua %6.2f%%  Python %6.2f%%  (lech %.2f, cho phep %.2f)"
							% [e.get("a"), e.get("b"), lua, py, absf(lua - py), tol])

	print("\n=== 2. doi hinh: may chu kiem ten ===")
	var good := await ses.set_roster(["MaChao", "LiuBei", "GanNing", "GuYong"])
	_check(good.ok, "nhan doi hinh hop le", str(good.get("error", "")))
	_check((ses.data.get("roster", []) as Array).size() == 4, "ban luu co 4 tuong")

	var bad := await ses.client.call_rpc("bx.set_roster",
			{"roster": ["KhongCoAi", "LiuBei", "GanNing", "GuYong"]})
	_check(not bad.ok, "tu choi tuong khong ton tai")
	_check(String(bad.get("error", "")).contains("KhongCoAi"),
			"bao ro ten sai", String(bad.get("error", "")))

	var short_r := await ses.client.call_rpc("bx.set_roster", {"roster": ["MaChao"]})
	_check(not short_r.ok, "tu choi doi hinh thieu nguoi")

	print("\n=== 3. may chu xu tran ===")
	var before := int(ses.data.get("battles", 0))
	var f := await ses.fight()
	_check(f.ok, "danh duoc mot tran", str(f.get("error", "")))
	_check(int(f.get("result", -1)) in [0, 1, 2], "ket qua la 0/1/2",
			str(f.get("result")))
	_check((f.get("opponent", []) as Array).size() == 4, "doi dich du 4 tuong")
	_check(int(ses.data.get("battles", 0)) == before + 1,
			"so tran tang dung 1", "%d -> %d" % [before, ses.data.get("battles", 0)])
	var w := int(ses.data.get("wins", 0))
	var l := int(ses.data.get("losses", 0))
	var d := int(ses.data.get("draws", 0))
	_check(w + l + d == int(ses.data.get("battles", 0)),
			"thang + thua + hoa = so tran", "%d+%d+%d vs %d" % [w, l, d, ses.data.get("battles", 0)])

	print("\n=== 3b. chuong: khong nhay coc duoc ===")
	var ch := await ses.client.call_rpc("bx.chapters", {})
	_check(ch.ok, "goi duoc bx.chapters", str(ch.get("error", "")))
	var list: Array = ch.data.get("chapters", []) if ch.ok else []
	_check(list.size() == 12, "co 12 chuong", str(list.size()))
	var cleared := int(ch.data.get("cleared", -1)) if ch.ok else -1
	_check(cleared >= 0, "co so chuong da qua", str(cleared))
	if list.size() == 12:
		var unlocked := 0
		for c in list:
			if bool(c.get("unlocked", false)):
				unlocked += 1
		_check(unlocked == cleared + 1,
				"chi mo toi chuong ke tiep", "mo %d, da qua %d" % [unlocked, cleared])
		_check(float(list[11].get("power", 0.0)) > float(list[0].get("power", 0.0)),
				"chuong sau manh hon chuong dau",
				"%.2f -> %.2f" % [list[0].get("power"), list[11].get("power")])
		# Doi dich cua mot chuong phai co dinh: nguoi choi hoc duoc tran dau roi
		# doi doi hinh cho hop. Boc ngau nhien moi lan thi khong con la man choi.
		var ch2 := await ses.client.call_rpc("bx.chapters", {})
		_check(ch2.ok and str((ch2.data.get("chapters", []) as Array)[4].get("enemies"))
						== str(list[4].get("enemies")),
				"doi dich cua mot chuong khong doi giua hai lan hoi")

	# Nhay coc phai bi tu choi tu MAY CHU, khong phai chi an nut o client.
	var skip := await ses.client.call_rpc("bx.fight", {"chapter": cleared + 3})
	_check(not skip.ok, "tu choi chuong chua mo")
	_check(String(skip.get("error", "")).contains("chua mo"), "bao dung ly do",
			String(skip.get("error", "")))
	var nope_ch := await ses.client.call_rpc("bx.fight", {"chapter": 999})
	_check(not nope_ch.ok, "tu choi chuong khong ton tai")

	print("\n=== 3c. qua chuong moi duoc mo chuong sau ===")
	# Kiem LUAT chu khong kiem ket qua: thang thi cleared tang dung 1, khong
	# thang thi giu nguyen. Kieu nay khong phu thuoc vao viec doi hinh manh yeu.
	# Truong cua may chu khong duoc roi mat khi client doc ban luu. Da dinh
	# dung the: `cleared` co ben Lua nhung PlayerSession._upgrade() khong liet
	# ke nen no bien mat lang le, va man chon chuong doc ra luon bang 0.
	_check(ses.data.has("cleared"), "ban luu ben client con giu truong cleared",
			str(ses.data.keys()))

	var before_c := int(ses.data.get("cleared", -1))
	var fc := await ses.fight(before_c + 1)
	_check(fc.ok, "danh duoc chuong ke tiep", str(fc.get("error", "")))
	var after_c := int(ses.data.get("cleared", -1))
	if int(fc.get("result", 2)) == 0:
		_check(after_c == before_c + 1, "thang thi mo them dung 1 chuong",
				"%d -> %d" % [before_c, after_c])
		_check(bool(fc.get("unlockedNext", false)), "bao la vua mo chuong moi")
	else:
		_check(after_c == before_c, "khong thang thi khong mo them chuong",
				"%d -> %d" % [before_c, after_c])
		_check(not bool(fc.get("unlockedNext", true)), "khong bao mo chuong moi")

	print("\n=== 3d. the tran ===")
	# The tran la he thong cua ban goc con nguyen ca so lieu (moi cap ghi ro tang
	# gi, bao nhieu, cho CHO DUNG nao). Phan kiem o day la LUAT — mo roi moi dung
	# duoc, du vang moi nang duoc, cho dung phai la 1/2/3 — chu khong kiem con so
	# buff, vi con so la cua ban goc chu khong phai cua ta.
	var fm := await ses.formations()
	_check(fm.ok, "goi duoc bx.formations", str(fm.get("error", "")))
	var flist: Array = fm.data.get("formations", []) if fm.ok else []
	_check(flist.size() == 12, "co 12 the tran", str(flist.size()))
	var jichu := {}
	var locked := 0
	for row in flist:
		if String(row.get("name", "")) == "jichu":
			jichu = row
		if not bool(row.get("owned", false)):
			locked += 1
	_check(not jichu.is_empty() and bool(jichu.get("owned", false)),
			"jichu co san tu dau")
	_check(locked == 11, "cac the tran con lai chua mo", str(locked))
	
	# Chua mo thi MAY CHU phai tu choi, khong phai chi an nut o client.
	var pick_locked := await ses.client.call_rpc("bx.set_formation",
			{"formation": "yanyue"})
	_check(not pick_locked.ok, "tu choi chon the tran chua mo")
	var pick_bad := await ses.client.call_rpc("bx.set_formation",
			{"formation": "KhongCoTran"})
	_check(not pick_bad.ok, "tu choi ten the tran khong co")
	
	# Cho dung: 1/2/3 thi nhan, ngoai khoang thi tu choi.
	var pl := await ses.set_placement([3, 2, 1, 1])
	_check(pl.ok, "doi duoc cho dung", str(pl.get("error", "")))
	_check(ses.placement_of(0) == 3 and ses.placement_of(2) == 1,
			"cho dung vao dung ban luu",
			"%d,%d" % [ses.placement_of(0), ses.placement_of(2)])
	var pl_bad := await ses.client.call_rpc("bx.set_placement",
			{"placement": [0, 1, 1, 1]})
	_check(not pl_bad.ok, "tu choi cho dung ngoai 1..3")
	
	# Va tran van danh duoc sau khi doi cho dung.
	var f_after := await ses.fight()
	_check(f_after.ok, "van danh duoc tran sau khi doi cho dung",
			str(f_after.get("error", "")))
	
	print("\n=== 4. CLIENT KHONG DUOC GHI BAN LUU ===")
	# Day moi la phan cuong che. Khong co no thi moi thu tren chi la hinh thuc.
	# Doc lai ngay truoc khi thu: cac muc tren vua danh them tran, nen con so
	# ghi tu muc 3 da cu. (Da dinh: test bao hong vi so sanh voi so cu.)
	var w_now := int(ses.data.get("wins", -1))
	var cheat := await ses.client.save({"wins": 999999, "battles": 999999})
	_check(not cheat.ok, "may chu tu choi ban luu do client ghi thang")
	_check(String(cheat.get("error", "")).to_lower().contains("permission"),
			"tu choi vi phan quyen", String(cheat.get("error", "")))
	var after := await ses.client.load_save()
	_check(int((after.get("data", {}) as Dictionary).get("wins", -1)) == w_now,
			"so thang khong bi sua",
			"%s vs %d" % [(after.get("data", {}) as Dictionary).get("wins"), w_now])

	# Va duong cu cua PlayerSession cung phai tu choi, khong im lang.
	var fl := await ses.flush()
	_check(not fl.ok, "flush() khong con ghi duoc nua")

	print("\n=== 5. khong the chiem ban luu tu truoc (test hoi quy) ===")
	# Lo hong that da tung co: permission_write = 0 chi chan GHI DE, khong chan
	# TAO MOI. Mot thiet bi chua he goi RPC tu tao duoc ban luu cua no, dien
	# 999999 vao, roi goi bx.fight — va may chu doc dung con so do roi ghi lai
	# thanh 1000000. Nay hook sau dang nhap tao san ban luu do may chu so huu.
	var fresh_dev := "moi-%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	var attacker := NakamaClient.new()
	attacker.url = url
	root.add_child(attacker)
	var la := await attacker.login(fresh_dev)
	_check(la.ok, "thiet bi moi dang nhap duoc", str(la.get("error", "")))
	var grab := await attacker.save({"wins": 999999, "battles": 999999})
	_check(not grab.ok, "khong tao truoc duoc ban luu du chua tung goi RPC",
			"da ghi duoc — lo hong tai phat")
	var atk_ses := PlayerSession.new()
	root.add_child(atk_ses)
	atk_ses.client = attacker
	atk_ses.online = true
	var af := await atk_ses.fight()
	_check(af.ok, "van danh duoc tran", str(af.get("error", "")))
	_check(int(atk_ses.data.get("battles", -1)) == 1,
			"tran dau tien tinh tu 1, khong an theo so bia",
			str(atk_ses.data.get("battles")))
	_check(int(atk_ses.data.get("wins", -1)) <= 1, "so thang khong bi bom",
			str(atk_ses.data.get("wins")))

	print("\n=== 6. song sot qua phien moi ===")
	var s2 := PlayerSession.new()
	root.add_child(s2)
	s2._ensure_client()
	s2.client.url = url
	var r2 := await s2.start("", dev)
	_check(bool(r2.get("online", false)), "dang nhap lai duoc")
	_check(int(s2.data.get("battles", -1)) == int(ses.data.get("battles", 0)),
			"so tran song sot", "%d vs %d" % [s2.data.get("battles", -1), ses.data.get("battles", 0)])
	_check((s2.data.get("roster", []) as Array).size() == 4
			and String((s2.data["roster"] as Array)[0]) == "MaChao",
			"doi hinh song sot")

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)
