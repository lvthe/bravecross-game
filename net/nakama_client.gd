# Client Nakama toi gian: DUNG HAI VIEC — dang nhap va luu/nap du lieu.
#
# Khong dung SDK Nakama cho Godot, chi goi REST bang HTTPRequest. Ba diem cuoi,
# tra tu tai lieu chinh thuc (khong phai doan):
#
#   POST /v2/account/authenticate/device?create=true    Basic <server key>
#   PUT  /v2/storage                                    Bearer <token>   ghi
#   POST /v2/storage                                    Bearer <token>   doc
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
	user_id = String(body.get("user_id", ""))
	username = String(body.get("username", ""))
	if token == "":
		return {"ok": false, "error": "may chu tra ve khong co token", "status": res.status}
	return {"ok": true, "userId": user_id, "username": username,
			"created": bool(body.get("created", false))}


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
