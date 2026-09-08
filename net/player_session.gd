# Phien choi: giu du lieu nguoi choi va lo viec dong bo voi may chu.
#
# Man tran khong noi chuyen truc tiep voi may chu. No hoi lop nay, va lop nay
# chiu trach nhiem: dang nhap, nap ban luu, ghi lai ket qua, day len.
#
# NGUYEN TAC: MAT MANG KHONG DUOC CHAN NGUOI CHOI. Khong dang nhap duoc thi
# van choi duoc, ket qua van cong don trong bo nho, chi la khong luu len may
# chu. `online` cho biet dang o che do nao.
#
#     var ses := PlayerSession.new()
#     add_child(ses)
#     await ses.start()
#     ses.data.roster = ["MaChao", "LiuBei"]
#     ses.record_result(0)      # doi 0 (nguoi choi) thang
#     await ses.flush()
class_name PlayerSession
extends Node

## Doi so nay khi cau truc ban luu thay doi, de con biet duong nang cap.
const SAVE_VERSION := 1

var client: NakamaClient = null
var data: Dictionary = {}
var online := false
var last_error := ""
var dirty := false


func _ready() -> void:
	_ensure_client()


func _ensure_client() -> void:
	if client != null and is_instance_valid(client):
		return
	client = NakamaClient.new()
	add_child(client)


## Ban luu rong, dung khi chua dang nhap duoc hoac chua choi lan nao.
static func blank() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"roster": [],
		"wins": 0, "losses": 0, "draws": 0, "battles": 0,
		"lastResult": "",
		"updatedAt": 0,
	}


## Dang nhap roi nap ban luu. Luon tra ve ok — that bai chi lam `online` = false
## chu khong chan gi.
## `device` de trong thi dung ma may nay (nho lai giua cac lan mo game). Chi
## dinh ro khi muon vao mot tai khoan cu the — bo test dua vao day de moi lan
## chay la mot nguoi choi moi, khong an theo du lieu cua lan truoc.
func start(url := "", device := "") -> Dictionary:
	_ensure_client()
	if url != "":
		client.url = url
	data = blank()
	online = false
	last_error = ""

	var r := await client.login(device)
	if not r.ok:
		last_error = String(r.get("error", "khong dang nhap duoc"))
		return {"ok": true, "online": false, "error": last_error}

	var s := await client.load_save()
	if not s.ok:
		last_error = String(s.get("error", "khong nap duoc ban luu"))
		return {"ok": true, "online": false, "error": last_error}

	online = true
	if bool(s.get("found", false)):
		data = _upgrade(s.get("data", {}))
	return {"ok": true, "online": true, "found": bool(s.get("found", false)),
			"userId": client.user_id, "username": client.username}


## Vá ban luu cu / hong ve dung hinh dang. Ban luu tren may chu la du lieu
## ben ngoai: co the thieu truong, sai kieu, hoac do mot phien ban khac ghi.
func _upgrade(raw: Variant) -> Dictionary:
	var out := blank()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw
	for k in ["wins", "losses", "draws", "battles"]:
		out[k] = int(d.get(k, 0))
	out["lastResult"] = String(d.get("lastResult", ""))
	out["updatedAt"] = int(d.get("updatedAt", 0))
	var roster: Array = []
	if typeof(d.get("roster")) == TYPE_ARRAY:
		for x in d["roster"]:
			# str() moi la ham chuyen kieu chung; String(x) la ham dung va no
			# tu choi chinh kieu String.
			roster.append(str(x))
	out["roster"] = roster
	return out


## Ghi lai ket qua mot tran. `winner`: 0 doi nguoi choi, 1 doi dich, 2 hoa.
func record_result(winner: int) -> void:
	data["battles"] = int(data.get("battles", 0)) + 1
	match winner:
		0:
			data["wins"] = int(data.get("wins", 0)) + 1
			data["lastResult"] = "thang"
		1:
			data["losses"] = int(data.get("losses", 0)) + 1
			data["lastResult"] = "thua"
		_:
			data["draws"] = int(data.get("draws", 0)) + 1
			data["lastResult"] = "hoa"
	dirty = true


func set_roster(names: Array) -> void:
	data["roster"] = names.duplicate()
	dirty = true


## Day ban luu len may chu. Khong online thi bao ro chu khong im lang bo qua.
func flush() -> Dictionary:
	if not online:
		return {"ok": false, "error": "dang choi ngoai tuyen, khong luu duoc"}
	data["version"] = SAVE_VERSION
	data["updatedAt"] = int(Time.get_unix_time_from_system())
	var r := await client.save(data)
	if r.ok:
		dirty = false
	else:
		last_error = String(r.get("error", "khong luu duoc"))
	return r


## Mot dong ngan de hien len man hinh.
func status_line() -> String:
	if not online:
		return "ngoai tuyen — %s" % (last_error if last_error != "" else "khong ro")
	return "%s  ·  %d tran: %d thang / %d thua / %d hoa%s" % [
			client.username if client.username != "" else client.user_id.substr(0, 8),
			int(data.get("battles", 0)), int(data.get("wins", 0)),
			int(data.get("losses", 0)), int(data.get("draws", 0)),
			"  (chua luu)" if dirty else ""]
