# Kiem tra net/player_session.gd — lop noi giua man tran va may chu.
#
#   godot --headless --path . --script tools/verify_session.gd -- --url=http://127.0.0.1:7350
#
# PHAM VI: nhung gi PlayerSession con tu lo sau khi may chu gianh quyen ghi —
# dang nhap, nap ban luu, va nhat la duong NGOAI TUYEN.
#
# Phan quyen luc va chong gian lan da chuyen sang tools/verify_rpc.gd. Doi lai,
# o day lo phan de quen nhat: MAY CHU CHET THI NGUOI CHOI VAN PHAI CHOI DUOC.
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


func _new(url: String) -> PlayerSession:
	var s := PlayerSession.new()
	root.add_child(s)
	s._ensure_client()
	s.client.url = url
	return s


func _init() -> void:
	await process_frame
	var opts := _cli()
	var url: String = opts.get("url", NakamaClient.DEFAULT_URL)
	var dev := "ses-%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	print("may chu: %s\nma thiet bi: %s\n" % [url, dev])

	print("=== 1. dang nhap va nap ban luu ===")
	var a := _new(url)
	var r := await a.start("", dev)
	_check(r.ok, "start() luon tra ve ok")
	var online := bool(r.get("online", false))
	if not online:
		_check(false, "ket noi duoc may chu", a.last_error)
		print("  (bo qua phan online)")
	else:
		_check(true, "ket noi duoc may chu")
		# Hook sau dang nhap cua may chu tao san mot ban luu rong, nen phien
		# dau tien cua nguoi choi moi van thay ban luu — chi la moi truong 0.
		_check(int(a.data.get("battles", -1)) == 0, "so tran bat dau tu 0",
				str(a.data.get("battles")))
		_check((a.data.get("roster", []) as Array).is_empty(), "chua co doi hinh")
		_check(a.client.user_id != "", "co user_id")
		_check(a.status_line().contains("tran"), "dong trang thai co so lieu",
				a.status_line())

		print("\n=== 2. doi hinh di qua may chu ===")
		var ok_r := await a.set_roster(["MaChao", "LiuBei", "GanNing", "GuYong"])
		_check(ok_r.ok, "doi duoc doi hinh", str(ok_r.get("error", "")))
		_check(not a.dirty, "doi xong thi khong con viec treo")
		var b := _new(url)
		var rb := await b.start("", dev)
		_check(bool(rb.get("online", false))
				and (b.data.get("roster", []) as Array).size() == 4,
				"phien moi thay duoc doi hinh vua dat")

	print("\n=== 2b. ban luu hong / thieu truong ===")
	# _upgrade la ham thuan, khong can may chu. Ban luu la du lieu ben ngoai:
	# co the thieu truong, sai kieu, hoac do mot phien ban khac ghi.
	var patched := a._upgrade({"roster": ["MaChao", 12, null], "wins": "3"})
	_check(int(patched["battles"]) == 0, "truong thieu duoc bu bang 0")
	_check((patched["roster"] as Array).size() == 3
			and typeof((patched["roster"] as Array)[1]) == TYPE_STRING,
			"phan tu doi hinh deu thanh chuoi")
	_check(int(patched["wins"]) == 3, "chuoi so van doc duoc thanh so")
	var junk := a._upgrade("khong phai tu dien")
	_check(int(junk["battles"]) == 0 and (junk["roster"] as Array).is_empty(),
			"ban luu khong phai tu dien thi tra ve ban rong")

	print("\n=== 3. may chu chet thi van choi duoc ===")
	var off := _new("http://127.0.0.1:1")      # cong khong ai nghe
	off.client.timeout_sec = 3.0
	var ro := await off.start()
	_check(ro.ok, "start() van tra ve ok du khong ket noi duoc")
	_check(not off.online, "biet la dang ngoai tuyen")
	_check(off.last_error != "", "co ghi ly do", off.last_error)
	_check(int(off.data.get("battles", -1)) == 0, "co ban luu rong de choi tiep")

	off.record_result(0)
	off.record_result(0)
	off.record_result(1)
	_check(int(off.data["battles"]) == 3 and int(off.data["wins"]) == 2
			and int(off.data["losses"]) == 1,
			"ngoai tuyen van cong don ket qua trong bo nho",
			"%d/%d/%d" % [off.data["battles"], off.data["wins"], off.data["losses"]])

	var fo := await off.fight()
	_check(not fo.ok, "ngoai tuyen thi khong danh tran xep hang duoc")
	_check(String(fo.get("error", "")).contains("ngoai tuyen"), "bao dung ly do",
			String(fo.get("error", "")))
	var sr := await off.set_roster(["MaChao", "LiuBei", "GanNing", "GuYong"])
	_check(not sr.ok, "ngoai tuyen thi khong luu doi hinh duoc")
	_check((off.data.get("roster", []) as Array).size() == 4,
			"nhung van doi duoc trong bo nho de choi tiep")
	_check(off.dirty, "va danh dau la co viec chua luu")
	_check(off.status_line().contains("ngoai tuyen"),
			"dong trang thai noi ro la ngoai tuyen", off.status_line())

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)
