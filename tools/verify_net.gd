# Kiem tra net/nakama_client.gd truoc mot may chu Nakama.
#
# Voi may chu GIA (khong can Docker):
#   python tools/fake_nakama.py --port 7399
#   godot --headless --path . --script tools/verify_net.gd -- --url=http://127.0.0.1:7399
#
# Voi Nakama THAT:
#   cd server && docker compose up -d
#   godot --headless --path . --script tools/verify_net.gd -- --url=http://127.0.0.1:7350
#
# CUNG MOT BO TEST, chi doi --url. May gia chi chung minh client goi dung dang;
# no khong chung minh Nakama chap nhan. Chay lai voi Nakama that moi la ket
# luan. Test o day duoc viet de khong biet minh dang noi voi ben nao.
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


func _client(url: String, key := NakamaClient.DEFAULT_SERVER_KEY) -> NakamaClient:
	var c := NakamaClient.new()
	c.url = url
	c.server_key = key
	root.add_child(c)
	return c


func _init() -> void:
	# _init() chay truoc khi cay node san sang; cho mot khung roi moi lam viec.
	await process_frame
	var opts := _cli()
	var url: String = opts.get("url", NakamaClient.DEFAULT_URL)
	# Ma thiet bi rieng cho moi lan chay, de chay lai khong dinh du lieu cu.
	var dev := "test-%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	print("may chu: %s\nma thiet bi: %s\n" % [url, dev])

	print("=== 1. dang nhap ===")
	var c := _client(url)
	var r := await c.login(dev)
	if not r.ok:
		_check(false, "dang nhap duoc", str(r.get("error", "")))
		print("\nKhong noi duoc toi may chu — bo qua phan con lai.")
		print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
		quit(1)
		return
	_check(true, "dang nhap duoc")
	_check(c.token != "", "co token")
	_check(c.user_id != "", "co user_id", c.user_id)
	_check(bool(r.get("created", false)), "ma thiet bi moi thi tai khoan la moi tao")

	print("\n=== 2. chua luu gi thi nap ra rong, khong phai loi ===")
	var empty := await c.load_save()
	_check(empty.ok, "nap duoc", str(empty.get("error", "")))
	_check(not bool(empty.get("found", true)), "bao la chua co du lieu")
	_check((empty.get("data", {}) as Dictionary).is_empty(), "du lieu rong")

	print("\n=== 3. luu roi nap lai ===")
	var save_data := {
		"level": 7,
		"gold": 1200,
		"roster": ["MaChao", "LiuBei", "GanNing"],
		"unlocked": true,
		"ratio": 0.75,
		"ten": "Đội của tôi",     # dau tieng Viet phai song sot
	}
	var w := await c.save(save_data)
	_check(w.ok, "luu duoc", str(w.get("error", "")))
	var back := await c.load_save()
	_check(back.ok and bool(back.get("found", false)), "nap lai thay du lieu")
	var got: Dictionary = back.get("data", {})
	_check(int(got.get("level", -1)) == 7, "so nguyen giu nguyen", str(got.get("level")))
	_check(bool(got.get("unlocked", false)) == true, "true khong bien thanh gia tri khac")
	_check(absf(float(got.get("ratio", 0.0)) - 0.75) < 1e-9, "so thap phan giu nguyen")
	_check((got.get("roster", []) as Array).size() == 3, "mang giu du 3 phan tu")
	_check(String(got.get("ten", "")) == "Đội của tôi", "chu co dau giu nguyen",
			String(got.get("ten", "")))

	print("\n=== 4. ghi de len ban luu cu ===")
	await c.save({"level": 8})
	var back2 := await c.load_save()
	_check(int((back2.get("data", {}) as Dictionary).get("level", -1)) == 8,
			"lan luu sau de len lan truoc")
	_check(not (back2.get("data", {}) as Dictionary).has("gold"),
			"ghi de la thay ca ban luu, khong phai tron vao")

	print("\n=== 5. dang nhap lai bang cung ma thiet bi ===")
	var c2 := _client(url)
	var r2 := await c2.login(dev)
	_check(r2.ok, "dang nhap lai duoc")
	_check(String(r2.get("userId", "")) == c.user_id,
			"van la nguoi choi cu, khong tao tai khoan moi")
	_check(not bool(r2.get("created", true)), "bao la tai khoan da co san")
	var back3 := await c2.load_save()
	_check(int((back3.get("data", {}) as Dictionary).get("level", -1)) == 8,
			"phien moi thay duoc du lieu da luu")

	print("\n=== 6. khoa may chu sai thi phai bao loi ===")
	var bad := _client(url, "khoa-sai")
	var rb := await bad.login(dev)
	_check(not rb.ok, "khoa sai bi tu choi")
	_check(int(rb.get("status", 0)) == 401, "tra ve 401", str(rb.get("status")))

	print("\n=== 7. chua dang nhap thi khong luu duoc ===")
	var fresh := _client(url)
	var nope := await fresh.save({"x": 1})
	_check(not nope.ok, "tu choi luu khi chua dang nhap")
	_check(String(nope.get("error", "")).contains("chua dang nhap"),
			"bao dung ly do", String(nope.get("error", "")))

	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)
