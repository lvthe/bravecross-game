# Kiem tra net/player_session.gd — lop noi giua man tran va may chu.
#
#   godot --headless --path . --script tools/verify_session.gd -- --url=http://127.0.0.1:7350
#
# Hai nua quan trong nhu nhau:
#   1. Online: doi hinh va so tran co song sot qua mot phien moi khong.
#   2. Ngoai tuyen: MAY CHU CHET THI NGUOI CHOI VAN PHAI CHOI DUOC. Day la
#      phan de quen nhat, va cung la phan nguoi choi gap nhieu nhat.
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
	var dev := "ses-%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	print("may chu: %s\nma thiet bi: %s\n" % [url, dev])

	print("=== 1. phien dau: chua co ban luu ===")
	var a := PlayerSession.new()
	root.add_child(a)
	a._ensure_client()
	a.client.url = url
	var r := await a.start("", dev)
	_check(r.ok, "start() luon tra ve ok")
	if not bool(r.get("online", false)):
		_check(false, "ket noi duoc may chu", a.last_error)
		print("\nKhong noi duoc toi may chu — bo qua phan online.")
	else:
		_check(true, "ket noi duoc may chu")
		_check(int(a.data.get("battles", -1)) == 0, "so tran bat dau tu 0")
		_check((a.data.get("roster", []) as Array).is_empty(), "chua co doi hinh")

		print("\n=== 2. ghi doi hinh va ket qua ===")
		a.set_roster(["MaChao", "LiuBei", "GanNing", "GuYong"])
		_check(a.dirty, "co viec chua luu thi bao dirty")
		a.record_result(0)
		a.record_result(1)
		a.record_result(2)
		a.record_result(0)
		_check(int(a.data["battles"]) == 4, "dem du 4 tran", str(a.data["battles"]))
		_check(int(a.data["wins"]) == 2 and int(a.data["losses"]) == 1
				and int(a.data["draws"]) == 1, "chia dung thang/thua/hoa",
				"%d/%d/%d" % [a.data["wins"], a.data["losses"], a.data["draws"]])
		_check(String(a.data["lastResult"]) == "thang", "nho ket qua tran cuoi")
		var f := await a.flush()
		_check(f.ok, "day len duoc", str(f.get("error", "")))
		_check(not a.dirty, "luu xong thi het dirty")

		print("\n=== 3. phien moi cua CUNG nguoi choi ===")
		# Dung lai chinh client cu de chac chan cung tai khoan, roi nap lai.
		var b := PlayerSession.new()
		root.add_child(b)
		b.client = a.client
		var s2 := await b.client.load_save()
		_check(s2.ok and bool(s2.get("found", false)), "tim thay ban luu")
		b.data = b._upgrade(s2.get("data", {}))
		b.online = true
		_check((b.data.get("roster", []) as Array).size() == 4, "doi hinh song sot")
		_check(String((b.data["roster"] as Array)[0]) == "MaChao",
				"dung thu tu doi hinh")
		_check(int(b.data["battles"]) == 4 and int(b.data["wins"]) == 2,
				"so tran song sot")

		print("\n=== 4. ban luu hong / thieu truong ===")
		var patched := b._upgrade({"roster": ["MaChao", 12, null], "wins": "3"})
		_check(int(patched["battles"]) == 0, "truong thieu duoc bu bang 0")
		_check((patched["roster"] as Array).size() == 3
				and typeof((patched["roster"] as Array)[1]) == TYPE_STRING,
				"phan tu doi hinh deu thanh chuoi")
		_check(int(patched["wins"]) == 3, "chuoi so van doc duoc thanh so")
		var junk := b._upgrade("khong phai tu dien")
		_check(int(junk["battles"]) == 0 and (junk["roster"] as Array).is_empty(),
				"ban luu khong phai tu dien thi tra ve ban rong")

	print("\n=== 5. may chu chet thi van choi duoc ===")
	var off := PlayerSession.new()
	root.add_child(off)
	off._ensure_client()
	off.client.url = "http://127.0.0.1:1"      # cong khong ai nghe
	off.client.timeout_sec = 3.0
	var ro := await off.start()
	_check(ro.ok, "start() van tra ve ok du khong ket noi duoc")
	_check(not off.online, "biet la dang ngoai tuyen")
	_check(off.last_error != "", "co ghi ly do", off.last_error)
	_check(int(off.data.get("battles", -1)) == 0, "co ban luu rong de choi tiep")

	off.record_result(0)
	off.record_result(0)
	_check(int(off.data["battles"]) == 2 and int(off.data["wins"]) == 2,
			"ngoai tuyen van cong don ket qua trong bo nho")
	var fo := await off.flush()
	_check(not fo.ok, "day len that bai, khong im lang bao thanh cong")
	_check(String(fo.get("error", "")).contains("ngoai tuyen"),
			"bao dung ly do", String(fo.get("error", "")))
	_check(off.status_line().contains("ngoai tuyen"),
			"dong trang thai noi ro la ngoai tuyen", off.status_line())

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)
