# Client Nakama toi gian: DUNG HAI VIEC — dang nhap va luu/nap du lieu.
#
# Khong dung SDK Nakama cho Godot, chi goi REST bang HTTPRequest. Ba diem cuoi,
# tra tu tai lieu chinh thuc (khong phai doan):
#
#   POST /v2/account/authenticate/device?create=true    Basic <server key>
#   PUT  /v2/storage                                    Bearer <token>   ghi
#   POST /v2/storage                                    Bearer <token>   doc
#   GET  /v2/account                                    Bearer <token>   du phong
#
# LUU Y quan trong, hoc duoc khi chay voi Nakama that: lenh dang nhap tra ve
# DUNG BA truong — created, token, refresh_token. KHONG co user_id. Ma nguoi
# choi nam trong claim `uid` cua token.
#
# Cach dung:
#
#     var net := NakamaClient.new()
#     add_child(net)
#     var r := await net.login()
#     if r.ok:
#         await net.save({"level": 7, "gold": 1200})
#         var s := await net.load_save()
#         print(s.data)
#
# Moi ham tra ve mot Dictionary co truong `ok`; khi that bai co them `error`
# va `status`. Khong ham nao nem loi — mat mang la chuyen binh thuong, khong
# phai truong hop ngoai le.
class_name NakamaClient
extends Node

## Dia chi may chu. Doi sang may that khi trien khai.
const DEFAULT_URL := "http://127.0.0.1:7350"
## Khoa may chu mac dinh cua Nakama. PHAI doi truoc khi phat hanh — bat ky ai
## biet khoa nay deu tao duoc tai khoan tren may chu cua ban.
const DEFAULT_SERVER_KEY := "defaultkey"

const COLLECTION := "player"
const KEY := "save"
const DEVICE_FILE := "user://device_id"

var url := DEFAULT_URL
var server_key := DEFAULT_SERVER_KEY
var token := ""
var user_id := ""
var username := ""
var timeout_sec := 10.0

var _http: HTTPRequest = null


func _ready() -> void:
	_ensure_http()


## Tao HTTPRequest khi can. Khong dat rieng trong _ready vi co luc client duoc
## dung tu mot script SceneTree (--script), luc do _ready chua chay.
func _ensure_http() -> void:
	if _http != null and is_instance_valid(_http):
		return
	_http = HTTPRequest.new()
	_http.timeout = timeout_sec
	add_child(_http)


## Ma may nay. Sinh mot lan roi giu lai, de mo game lan sau van vao dung tai
## khoan cu. Nakama doi id thiet bi dai it nhat 10 ky tu.
func device_id() -> String:
	if FileAccess.file_exists(DEVICE_FILE):
		var f := FileAccess.open(DEVICE_FILE, FileAccess.READ)
		if f:
			var s := f.get_as_text().strip_edges()
			if s.length() >= 10:
				return s
	var fresh := "bx-%d-%d" % [Time.get_unix_time_from_system(), randi()]
	var w := FileAccess.open(DEVICE_FILE, FileAccess.WRITE)
	if w:
		w.store_string(fresh)
	return fresh


## Dang nhap bang ma thiet bi. Tao tai khoan neu chua co.
func login(id := "", name_hint := "") -> Dictionary:
	if id == "":
		id = device_id()
	var path := "/v2/account/authenticate/device?create=true"
	if name_hint != "":
		path += "&username=" + name_hint.uri_encode()
	var auth := "Basic " + Marshalls.utf8_to_base64(server_key + ":")
	var res := await _send(HTTPClient.METHOD_POST, path, {"id": id}, auth)
	if not res.ok:
		return res
	var body: Dictionary = res.body
	token = String(body.get("token", ""))
	if token == "":
		return {"ok": false, "error": "may chu tra ve khong co token", "status": res.status}

	# Nakama KHONG tra ve user_id o than tin nhan — chi co created, token,
	# refresh_token. Ma nguoi choi nam trong chinh token, o claim `uid`
	# (username o `usn`). Doc nham cho nay thi user_id rong, va moi lenh doc
	# kho deu tra ve rong ma khong bao loi gi.
	var cl := claims(token)
	user_id = String(cl.get("uid", ""))
	username = String(cl.get("usn", ""))

	if user_id == "":
		# Du phong: hoi thang may chu. Cham hon mot vong nhung khong phu thuoc
		# vao ruot cua token.
		var acc := await _send(HTTPClient.METHOD_GET, "/v2/account", null, _bearer())
		if acc.ok:
			var u: Dictionary = acc.body.get("user", {})
			user_id = String(u.get("id", ""))
			if username == "":
				username = String(u.get("username", ""))
	if user_id == "":
		return {"ok": false, "status": res.status,
				"error": "khong lay duoc user_id tu token lan tu /v2/account"}

	return {"ok": true, "userId": user_id, "username": username,
			"created": bool(body.get("created", false))}


## Doc phan claims cua mot JWT. Khong kiem tra chu ky — day chi la de lay ma
## nguoi choi ma may chu vua cap, khong phai de tin tuong dieu gi.
static func claims(jwt: String) -> Dictionary:
	var parts := jwt.split(".")
	if parts.size() < 2:
		return {}
	var raw := _b64url_to_text(parts[1])
	if raw == "":
		return {}
	var doc = JSON.parse_string(raw)
	return doc if typeof(doc) == TYPE_DICTIONARY else {}


## base64url (JWT dung kieu nay) khac base64 thuong o hai ky tu va o cho khong
## co dau chen `=`.
static func _b64url_to_text(s: String) -> String:
	var t := s.replace("-", "+").replace("_", "/")
	match t.length() % 4:
		2: t += "=="
		3: t += "="
		1: return ""
	return Marshalls.base64_to_utf8(t)


## Luu du lieu nguoi choi. `data` la mot Dictionary bat ky.
func save(data: Dictionary) -> Dictionary:
	if token == "":
		return {"ok": false, "error": "chua dang nhap"}
	var payload := {"objects": [{
		"collection": COLLECTION,
		"key": KEY,
		# Nakama nhan `value` la MOT CHUOI JSON, khong phai object long nhau.
		"value": JSON.stringify(data),
		"permission_read": 1,     # chi chu so huu doc duoc
		"permission_write": 1,    # chi chu so huu ghi duoc
	}]}
	var res := await _send(HTTPClient.METHOD_PUT, "/v2/storage", payload, _bearer())
	if not res.ok:
		return res
	return {"ok": true}


## Nap du lieu nguoi choi. Chua luu lan nao thi tra ve ok voi data rong.
func load_save() -> Dictionary:
	if token == "":
		return {"ok": false, "error": "chua dang nhap"}
	var payload := {"object_ids": [{
		"collection": COLLECTION, "key": KEY, "user_id": user_id,
	}]}
	var res := await _send(HTTPClient.METHOD_POST, "/v2/storage", payload, _bearer())
	if not res.ok:
		return res
	var objects: Array = res.body.get("objects", [])
	if objects.is_empty():
		return {"ok": true, "found": false, "data": {}}
	var raw = JSON.parse_string(String(objects[0].get("value", "{}")))
	return {"ok": true, "found": true,
			"data": raw if typeof(raw) == TYPE_DICTIONARY else {},
			"version": String(objects[0].get("version", ""))}


func _bearer() -> String:
	return "Bearer " + token


func _send(method: int, path: String, body: Variant, auth: String) -> Dictionary:
	_ensure_http()
	if not is_inside_tree():
		return {"ok": false, "error": "NakamaClient phai duoc them vao cay node truoc"}
	_http.timeout = timeout_sec        # doi duoc giua chung, khong chi luc tao
	var headers := PackedStringArray([
		"Content-Type: application/json", "Authorization: " + auth])
	var err := _http.request(url + path, headers, method,
			"" if body == null else JSON.stringify(body))
	if err != OK:
		return {"ok": false, "error": "khong goi duoc (%d) — may chu chua chay?" % err,
				"status": 0}
	var out: Array = await _http.request_completed
	var result: int = out[0]
	var status: int = out[1]
	var text := (out[3] as PackedByteArray).get_string_from_utf8()

	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": status,
				"error": "khong noi duoc toi %s (ma %d) — may chu chua chay?"
						% [url, result]}
	var parsed = JSON.parse_string(text) if text != "" else {}
	var doc: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if status < 200 or status >= 300:
		return {"ok": false, "status": status,
				"error": String(doc.get("message", doc.get("error", text))),
				"body": doc}
	return {"ok": true, "status": status, "body": doc}
