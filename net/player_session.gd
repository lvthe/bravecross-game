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
#     await ses.set_roster(["MaChao", "LiuBei", "GanNing", "GuYong"])
#     var r := await ses.fight()   # may chu danh, may chu cong so
#
# BAN LUU DO MAY CHU GIU. Tu ban nay client khong con quyen ghi len kho
# (permission_write = 0), nen no khong the tu khai thanh tich. Moi thay doi
# deu qua RPC bx.set_roster / bx.fight.
class_name PlayerSession
extends Node

## Doi so nay khi cau truc ban luu thay doi, de con biet duong nang cap.
## Phai khop SAVE_VERSION ben server/modules/battle.lua.
const SAVE_VERSION := 5

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
		"cleared": 0,                 # chuong cao nhat da qua
		"gold": 0,
		"levels": {},                 # ten tuong -> cap
		# The tran (KDBGameFormationConfig cua ban goc). `placement` la cho dung
		# cua tung tuong: 1 truoc, 2 giua, 3 sau. Cho dung quyet ca vi tri tren
		# san lan buff nao cua the tran ap vao.
		"formation": "jichu",
		"formationLevel": 0,
		"formations": {"jichu": 0},   # ten the tran -> cap da nang
		"placement": [1, 1, 2, 3],
		# Trang bi: ten tuong -> mang toi da 6 mon (moi o mot mon).
		"equipment": {},
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
	# Thieu mot ten o day la truong do bien mat lang le: may chu van giu, nhung
	# client doc ra khong thay. Da dinh dung the voi "cleared".
	for k in ["wins", "losses", "draws", "battles", "cleared", "gold"]:
		out[k] = int(d.get(k, 0))
	var levels := {}
	if typeof(d.get("levels")) == TYPE_DICTIONARY:
		for name in d["levels"]:
			levels[str(name)] = maxi(1, int(d["levels"][name]))
	out["levels"] = levels
	out["lastResult"] = String(d.get("lastResult", ""))
	out["updatedAt"] = int(d.get("updatedAt", 0))
	var roster: Array = []
	if typeof(d.get("roster")) == TYPE_ARRAY:
		for x in d["roster"]:
			# str() moi la ham chuyen kieu chung; String(x) la ham dung va no
			# tu choi chinh kieu String.
			roster.append(str(x))
	out["roster"] = roster
	# The tran. Cung ly do nhu "cleared" o tren: thieu mot ten o day la truong
	# do bien mat lang le — may chu van giu ma client doc ra khong thay.
	out["formation"] = String(d.get("formation", "jichu"))
	out["formationLevel"] = int(d.get("formationLevel", 0))
	var owned := {}
	if typeof(d.get("formations")) == TYPE_DICTIONARY:
		for name in d["formations"]:
			owned[str(name)] = maxi(0, int(d["formations"][name]))
	if owned.is_empty():
		owned = {"jichu": 0}
	out["formations"] = owned
	var spots: Array = []
	if typeof(d.get("placement")) == TYPE_ARRAY:
		for x in d["placement"]:
			spots.append(clampi(int(x), 1, 3))
	while spots.size() < 4:
		spots.append(1)
	out["placement"] = spots
	# Trang bi. Van ly do o tren: khong liet ke o day thi truong nay bien mat
	# lang le, may chu van giu ma client doc ra khong thay.
	var eq := {}
	if typeof(d.get("equipment")) == TYPE_DICTIONARY:
		for name in d["equipment"]:
			if typeof(d["equipment"][name]) != TYPE_ARRAY:
				continue
			var items: Array = []
			for one in d["equipment"][name]:
				if typeof(one) == TYPE_DICTIONARY:
					items.append(one)
			if not items.is_empty():
				eq[str(name)] = items
	out["equipment"] = eq
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


## Doi doi hinh. Online thi may chu ghi (va kiem ten); ngoai tuyen thi chi
## doi trong bo nho, khong luu duoc.
func set_roster(names: Array) -> Dictionary:
	data["roster"] = names.duplicate()
	if not online:
		dirty = true
		return {"ok": false, "error": "dang choi ngoai tuyen, khong luu duoc"}
	var r := await client.call_rpc("bx.set_roster", {"roster": names})
	if not r.ok:
		last_error = String(r.get("error", "khong doi duoc doi hinh"))
		dirty = true
		return r
	data = _upgrade(r.data.get("save", {}))
	dirty = false
	return {"ok": true}


## Danh mot tran. MAY CHU quyet dinh: no boc doi dich, mo phong, cong so va
## ghi ban luu. Client khong khai gi ca — no khong the ghi ban luu nua
## (permission_write = 0), nen co sua client cung khong bia duoc thanh tich.
##
## Tra ve {ok, result, seed, power, opponent, seconds, survivors} khi online.
func fight(chapter := 0) -> Dictionary:
	if not online:
		return {"ok": false, "error": "dang choi ngoai tuyen, khong danh duoc"}
	var body := {} if chapter <= 0 else {"chapter": chapter}
	var r := await client.call_rpc("bx.fight", body)
	if not r.ok:
		last_error = String(r.get("error", "khong goi duoc bx.fight"))
		return r
	var d: Dictionary = r.data
	data = _upgrade(d.get("save", {}))
	dirty = false
	return {"ok": true, "result": int(d.get("result", 2)),
			"chapter": int(d.get("chapter", 0)),
			# Seed may chu da dung. Man tran gieo lai dung so nay de phat lai
			# dung tran do, khong phai dien mot tran khac cho de nhin.
			"seed": int(d.get("seed", 0)),
			"unlockedNext": bool(d.get("unlockedNext", false)),
			"power": float(d.get("power", 1.0)),
			"opponent": d.get("opponent", []),
			"seconds": d.get("seconds", 0.0),
			"survivors": d.get("survivors", {})}


## Nang mot tuong len mot cap. May chu tru vang va ghi ban luu.
func level_up(hero_name: String) -> Dictionary:
	if not online:
		return {"ok": false, "error": "dang choi ngoai tuyen, khong nang cap duoc"}
	var r := await client.call_rpc("bx.level_up", {"hero": hero_name})
	if not r.ok:
		last_error = String(r.get("error", "khong nang cap duoc"))
		return r
	data = _upgrade(r.data.get("save", {}))
	return {"ok": true, "hero": hero_name, "level": int(r.data.get("level", 1)),
			"cost": int(r.data.get("cost", 0))}


func level_of(hero_name: String) -> int:
	var lv: Dictionary = data.get("levels", {})
	return maxi(1, int(lv.get(hero_name, 1)))


## The tran dang dung, va cap cua no.
func formation() -> String:
	return String(data.get("formation", "jichu"))


func formation_level() -> int:
	return maxi(0, int(data.get("formationLevel", 0)))


## Cho dung cua tuong thu `i` trong doi hinh: 1 truoc, 2 giua, 3 sau.
func placement_of(i: int) -> int:
	var spots: Array = data.get("placement", [])
	if i < 0 or i >= spots.size():
		return 1
	return clampi(int(spots[i]), 1, 3)


## Danh sach the tran: cai nao da mo, cap may, nang tiep het bao nhieu.
func formations() -> Dictionary:
	if not online:
		return {"ok": false, "error": "chua noi duoc may chu"}
	var r := await client.call_rpc("bx.formations", {})
	if r.ok:
		data = _upgrade(r.data.get("save", {}))
	return r


## Chon the tran dang dung. May chu kiem da mo hay chua.
func set_formation(name: String) -> Dictionary:
	if not online:
		return {"ok": false, "error": "chua noi duoc may chu"}
	var r := await client.call_rpc("bx.set_formation", {"formation": name})
	if r.ok:
		data = _upgrade(r.data.get("save", {}))
	return r


## Mo hoac nang the tran. May chu tru vang, client khong tu tinh.
func upgrade_formation(name: String) -> Dictionary:
	if not online:
		return {"ok": false, "error": "chua noi duoc may chu"}
	var r := await client.call_rpc("bx.upgrade_formation", {"formation": name})
	if r.ok:
		data = _upgrade(r.data.get("save", {}))
	return r


## Doi cho dung cua bon tuong.
func set_placement(spots: Array) -> Dictionary:
	if not online:
		return {"ok": false, "error": "chua noi duoc may chu"}
	var r := await client.call_rpc("bx.set_placement", {"placement": spots})
	if r.ok:
		data = _upgrade(r.data.get("save", {}))
	return r


## Trang bi dang co: tung tuong, tung o, kem luc chien va gia cuong hoa ke.
## Con so do MAY CHU tinh — client chi hien lai, y nhu the tran va cap tuong.
func equipment() -> Dictionary:
	if not online:
		return {"ok": false, "error": "chua noi duoc may chu"}
	var r := await client.call_rpc("bx.equipment", {})
	if r.ok:
		data = _upgrade(r.data.get("save", {}))
	return r


## Cuong hoa mot mon len mot cap. May chu tinh gia va tru vang.
func intensify(hero_name: String, part: int) -> Dictionary:
	if not online:
		return {"ok": false, "error": "chua noi duoc may chu"}
	var r := await client.call_rpc("bx.intensify",
			{"hero": hero_name, "part": part})
	if r.ok:
		data = _upgrade(r.data.get("save", {}))
	return r


## Buff do trang bi cua mot tuong, dang ma mo hinh chien dau hieu.
##
## Doc thang tu ban luu may chu gui ve — KHONG tinh lai tu cong thuc, de client
## va may chu khong bao gio lech. Equipment.to_buffs() chi dung khi muon xem
## thu mot mon do chua deo.
func equip_buffs(hero_name: String) -> Dictionary:
	var all_eq: Dictionary = data.get("equipment", {})
	if not all_eq.has(hero_name):
		return {}
	var items := []
	for raw in all_eq[hero_name]:
		var it: Dictionary = raw
		var m: Dictionary = it.get("main", {})
		var e := Equipment.new(int(it.get("part", 1)), int(m.get("type", Equipment.AP)),
				float(m.get("value", 0.0)), int(it.get("level", 1)),
				int(it.get("intensify", 0)), int(it.get("quality", 1)))
		for ap in it.get("appends", []):
			e.appends.append([int(ap.get("type", 0)), float(ap.get("value", 0.0))])
		items.append(e)
	return Equipment.to_buffs(items)


func gold() -> int:
	return int(data.get("gold", 0))


## Ngoai tuyen: cong ket qua vao bo nho. Online thi khong dung — may chu cong.
func flush() -> Dictionary:
	if not online:
		return {"ok": false, "error": "dang choi ngoai tuyen, khong luu duoc"}
	# Client KHONG con quyen ghi ban luu. Moi thay doi phai di qua RPC.
	return {"ok": false,
			"error": "ban luu do may chu giu; dung set_roster() hoac fight()"}


## Mot dong ngan de hien len man hinh.
func status_line() -> String:
	if not online:
		return "ngoai tuyen — %s" % (last_error if last_error != "" else "khong ro")
	return "%s  ·  %d vang  ·  chuong %d  ·  %d tran: %d thang / %d thua / %d hoa%s" % [
			client.username if client.username != "" else client.user_id.substr(0, 8),
			gold(), int(data.get("cleared", 0)),
			int(data.get("battles", 0)), int(data.get("wins", 0)),
			int(data.get("losses", 0)), int(data.get("draws", 0)),
			"  (chua luu)" if dirty else ""]
