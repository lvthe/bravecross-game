# Bo kiem `pb`: bo protobuf Lua thuan thay cho mo-dun C lua-protobuf.
#
# Vi sao phai viet lai thay vi dung ban goc: xem dau `lua/pb.lua`. Tom tat mot
# dong: `pb` la mo-dun C, ma Lua o port nam trong addon Godot nen
# `require("pb")` khong bao gio giai ra ma C.
#
# Ba tang, ca ba deu chay MA GOC khong sua mot chu:
#
#   A. Oracle blob cua Google. Lay NGUYEN VAN doan `local descriptor_pb = ...`
#      nhung trong `sc/Framework/Network/pb/protoc.lua`, giai ra roi ma hoa lai,
#      doi KHOP TUNG BYTE voi chuoi goc (4604 byte). Phep thu co luc that: thieu
#      mot truong trong schema `descriptor.proto` viet tay thi `pb.decode` bo qua
#      no va `pb.encode` khong ghi lai, nen do dai lech ngay. Gioi han cua no,
#      noi ro: ten truong dung SAI thi khong bat duoc (ten dung doi xung o hai
#      chieu), chi bat duoc thieu/thua truong, sai so truong, sai kieu day, sai
#      nhan `repeated`.
#   B. Duong that cua ban goc: chay nguyen van `protoc.lua` (no tu goi
#      `Parser.reload()` -> `pb.load(descriptor_pb)` ngay luc nap, va vo dieu
#      kien — xem `lua/pb.lua`), cho no `load` van ban proto3 cua
#      `sc/def/PBProto.lua`, roi kiem vong ma hoa/giai ma `HandshakeReq` va doc
#      thang wire type tu byte dau.
#   C. `.proto` THAT tren dia: `required`, `default`, enum long trong message,
#      message long trong message, repeated message, `service`/`rpc`, va
#      `import`. Bay tep nam o cay nguon VN — thu muc do khong commit duoc
#      (xem .gitignore), nen thieu thi bao BO QUA chu khong bao hong, dung loi
#      da co o `verify_am.gd` / `verify_lan.gd`.
#
# Duong giai `import` phai di qua `Parser.paths` + `io.open` (Parser:addpath).
# KHONG dung `Parser.import_fallback` cho viec nay dau ten no rat goi: do duoc
# la `make_context` (protoc.lua:770) dat mot `ctx.import_fallback` RIENG, no la
# hook `self.unknown_import` (chi tra true/nil de MIEN LOI) va vi `ctx` co
# truong ay nen no CHE MAT ham cua `Parser` — dat vao roi nap thi khong he duoc
# goi.
#
#   godot --headless --path . --script tools/verify_pb.gd
extends SceneTree

const PROTOC := "res://sc/Framework/Network/pb/protoc.lua"
const PBPROTO := "res://sc/def/PBProto.lua"

## Do truoc bang Python tren chinh doan nhung trong protoc.lua: 4604 byte.
const DAI_BLOB := 4604

## Cay nguon VN, tinh TU GOC DU AN ra chu khong viet cung duong dan may: day
## dung la cay ma `tools/import_lua.py` dung de sinh `sc/`, nen may nao chay
## duoc `check.py` thi da co no.
const CAY_VN := "brave-cross/work/vn/decrypted/assets"
const TEP_PROTO := {
	"addressbook.proto": "proto/addressbook.proto",
	"kClientCommon.proto": "conf/kClientCommon.proto",
	"kGameResponseData.proto": "conf/kGameResponseData.proto",
	"kGameRequestData.proto": "conf/kGameRequestData.proto",
}


func _doc(duong: String) -> String:
	var f := FileAccess.open(duong, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


func _goc_vn() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..") \
			.path_join(CAY_VN).simplify_path()


## Bang Lua { ten = noi dung tep }, boc trong [==[ ]==] nen khong phai escape.
func _bang_proto(goc: String) -> String:
	var dong := []
	for ten in TEP_PROTO:
		var s := _doc(goc.path_join(TEP_PROTO[ten]))
		if s == "":
			continue
		dong.append('\t["%s"] = [==[\n%s]==],' % [ten, s])
	return "\n".join(dong)


func _init() -> void:
	var protoc := _doc(PROTOC)
	var pbproto := _doc(PBPROTO)
	if protoc == "" or pbproto == "":
		print("KHONG doc duoc %s / %s" % [PROTOC, PBPROTO])
		print("  (chay `python tools/import_lua.py` truoc)")
		print("dat 0, hong 1")
		quit(1)
		return

	# Cat NGUYEN VAN doan blob ra khoi protoc.lua — khong chep tay mot byte nao.
	var a := protoc.find("local descriptor_pb =")
	var b := protoc.find("function Parser.reload")
	if a < 0 or b <= a:
		print("KHONG tim thay doan blob trong %s (a=%d b=%d)" % [PROTOC, a, b])
		print("dat 0, hong 1")
		quit(1)
		return
	var manh := protoc.substr(a, b - a)

	var goc := _goc_vn()
	# Du 7 tep .proto moi chay tang C. Thieu mot tep thi bao BO QUA ca bo (kieu
	# cua verify_am.gd / verify_lan.gd) chu khong de no thanh mot dong HONG gia.
	var thieu := []
	for ten in TEP_PROTO:
		if _doc(goc.path_join(TEP_PROTO[ten])) == "":
			thieu.append(goc.path_join(TEP_PROTO[ten]))
	if not thieu.is_empty():
		print("BO QUA: khong doc duoc cay nguon %s (thieu %s)"
				% [goc, ", ".join(thieu)])
		quit(0)
		return
	var bang := _bang_proto(goc)

	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG mo duoc Lua: %s" % ", ".join(lua.errors))
		print("dat 0, hong 1")
		quit(1)
		return

	# KHONG dung toan tu `%` cua GDScript o day: ca ba manh thay vao deu chua
	# `%` cua chinh Lua (`string.format`), nen no dem nham la cho trong.
	var nguon := _DO.replace("__MANH__", manh) \
			.replace("__PROTOC__", protoc).replace("__PBPROTO__", pbproto) \
			.replace("__BANG__", bang) \
			.replace("__CONFDIR__", '"%s"' % goc.path_join("conf"))
	var r = lua.run(nguon, "verify pb")

	var kiem := []
	if r == null:
		print("chay hong: %s" % ", ".join(lua.errors))
		kiem.append(["Lua chay duoc", false])
	else:
		kiem = _xet(r)
	var dat := 0
	var hong := 0
	for e in kiem:
		if e[1]:
			dat += 1
		else:
			hong += 1
			print("  HONG: %s" % e[0])
	for k in (r if r != null else {}):
		print("  %-30s %s" % [k, r[k]])
	print("")
	print("dat %d, hong %d" % [dat, hong])
	quit(1 if hong > 0 else 0)


func _xet(r: Dictionary) -> Array:
	var s := {}
	for k in r:
		s[k] = str(r[k])
	return [
		# --- A: oracle blob cua Google ---
		["A blob dung %d byte" % DAI_BLOB, int(r.get("A dai blob", -1)) == DAI_BLOB],
		["A giai ra 1 FileDescriptorSet", int(r.get("A so file", -1)) == 1],
		["A goi dung google.protobuf",
				s.get("A goi") == "google.protobuf"],
		["A du 18 message muc cao nhat", int(r.get("A so message", -1)) == 18],
		["A ma hoa lai khop TUNG BYTE", s.get("A khop tung byte") == "true"],
		["A pb.load nuot duoc blob", s.get("A load").begins_with("true")],
		# --- B: duong that cua ban goc ---
		["B nap protoc.lua (reload() chay)", s.get("B nap protoc") == "ok"],
		["B load van ban proto3 cua PBProto", s.get("B load") == "ok"],
		["B HandshakeReq ra byte", int(r.get("B dai HandshakeReq", -1)) > 0],
		["B giai lai ra dung bang da vao", s.get("B khop vong") == "true"],
		["B byte dau dung wire type (08 83 01)",
				s.get("B dau HandshakeReq") == "08 83 01"],
		["B truong string di wire type 2", s.get("B proto_md5 wt") == "2"],
		["B truong bool di wire type 0", s.get("B need_login wt") == "0"],
		["B EmptyStruct ra chuoi rong", s.get("B EmptyStruct") == "0"],
		# --- C: .proto that tren dia ---
		["C addressbook.proto nap duoc (proto2, required)",
				s.get("C addressbook") == "ok"],
		["C OAR1.Person di vong dung", s.get("C OAR1.Person vong") == "ok"],
		["C message long dang ky theo ten day du",
				s.get("C ten long dang ky") == "true"],
		["C ba tep conf/ nap duoc qua import (io.open)",
				s.get("C conf/kGameRequestData.proto") == "ok"],
		["C tep chi co import + package nap duoc",
				s.get("C tep rong nap duoc") == "ok"],
		["C GameActionData du 10 truong",
				s.get("C GameActionData so truong") == "10"],
		["C GameActionData di vong dung", s.get("C GameActionData vong") == "ok"],
		["C uid = -1 ra 10 byte varint",
				s.get("C uid = -1 ra 10 byte") == "true"],
	]


const _DO := """
local out = Dictionary()
local pb = require('pb')

local function hex(s, n)
	local t = {}
	for i = 1, math.min(n, #s) do
		t[#t + 1] = string.format('%02x', string.byte(s, i))
	end
	return table.concat(t, ' ')
end

-- ===================== A. Oracle blob cua Google =====================
-- Nguyen van doan nhung trong protoc.lua, chay y nhu ban goc chay no.
local blob = (function()
__MANH__
return descriptor_pb
end)()
out['A dai blob'] = #blob

local set = pb.decode('.google.protobuf.FileDescriptorSet', blob)
if set == nil then
	out['A giai'] = 'nil'
else
	out['A giai'] = 'ok'
	out['A so file'] = (type(set.file) == 'table') and #set.file or -1
	local f1 = set.file and set.file[1]
	out['A goi'] = tostring(f1 and f1.package)
	out['A so message'] = (f1 and type(f1.message_type) == 'table')
		and #f1.message_type or -1

	local lai = pb.encode('.google.protobuf.FileDescriptorSet', set)
	out['A khop tung byte'] = tostring(lai ~= nil and lai == blob)
	if lai ~= blob then
		local n = math.min(#lai or 0, #blob)
		for i = 1, n do
			if string.byte(lai, i) ~= string.byte(blob, i) then
				out['A lech tai'] = i
				out['A byte'] = string.format('blob=%d lai=%d',
					string.byte(blob, i), string.byte(lai, i))
				break
			end
		end
		out['A dai lai'] = #lai
	end
end

local nap, vitri = pb.load(blob)
out['A load'] = tostring(nap) .. ' @ ' .. tostring(vitri)

-- ===================== B. Duong that cua ban goc =====================
local Parser = (function()
__PROTOC__
end)()
out['B nap protoc'] = 'ok'

local PBProto = (function()
__PBPROTO__
end)()

local ok, err = pcall(function() return Parser:load(PBProto.pb, 'PBProto') end)
out['B load'] = ok and 'ok' or tostring(err)

if ok then
	local req = {
		client_version = 131, proto_md5 = 'abc', token_str = 'xyz',
		logic_busid = 7, device_uid = 'dev', serverid = 3,
		app_version = '1.31', bundle_version = 'b1',
	}
	local bytes = pb.encode('HandshakeReq', req)
	if bytes == nil then
		out['B dai HandshakeReq'] = -1
	else
		out['B dai HandshakeReq'] = #bytes
		-- client_version = 131 -> khoa 1*8+0 = 8, gia tri 131 = 0x83 0x01.
		out['B dau HandshakeReq'] = hex(bytes, 3)
		local lai = pb.decode('HandshakeReq', bytes)
		if lai == nil then
			out['B khop vong'] = 'giai ra nil'
		else
			local khop = true
			for k, v in pairs(req) do
				if lai[k] ~= v then khop = false out['B lech ' .. k] = tostring(lai[k]) end
			end
			for k, v in pairs(lai) do
				if req[k] == nil then khop = false out['B thua ' .. k] = tostring(v) end
			end
			out['B khop vong'] = tostring(khop)
		end
		-- Wire type doc thang tu byte dau, khong qua bang cua ta.
		-- proto_md5 (truong 2, string) -> khoa 2*8+2 = 18 = 0x12.
		for i = 1, #bytes do
			if string.byte(bytes, i) == 18 then out['B proto_md5 wt'] = 2 break end
		end
	end

	local rsp = pb.encode('HandshakeRsp', { need_login = true, encrypt_mode = 1,
		cur_proto_md5 = 'zz' })
	-- need_login (truong 1, bool) -> khoa 1*8+0 = 8 = 0x08.
	out['B need_login wt'] = tostring(
		rsp ~= nil and string.byte(rsp, 1) == 8 and 0 or -1)

	local e = pb.encode('EmptyStruct', {})
	out['B EmptyStruct'] = tostring(e ~= nil and #e or -1)
end

-- ===================== C. .proto that tren dia =====================
-- Duong THAT de protoc giai import: `toplevel:import` -> `Parser:parsefile`,
-- ma `parsefile` di tim tung `name` trong `Parser.paths` bang `io.open`.
Parser:addpath(__CONFDIR__)

local KHO = {
__BANG__
}

local function nap_tep(ten)
	local c = KHO[ten]
	if c == nil then return 'KHONG co trong bang' end
	local ok2, e2 = pcall(function() return Parser:load(c, ten) end)
	if not ok2 then return 'HONG: ' .. tostring(e2) end
	if e2 == nil then return 'load tra nil' end
	return 'ok'
end

out['C addressbook'] = nap_tep('addressbook.proto')
if out['C addressbook'] == 'ok' then
	local p = { name = 'An', id = 42,
		phone = { { number = '111' }, { number = '222', type = 1 } } }
	local b = pb.encode('OAR1.Person', p)
	if b == nil then
		out['C OAR1.Person vong'] = 'ma hoa tra nil'
	else
		local lai = pb.decode('OAR1.Person', b)
		local khop = lai ~= nil and lai.name == 'An' and lai.id == 42
			and type(lai.phone) == 'table' and #lai.phone == 2
			and lai.phone[1].number == '111' and lai.phone[2].type == 1
		out['C OAR1.Person vong'] = khop and 'ok' or 'HONG'
	end
	-- `Person.PhoneNumber` la message LONG: phai dang ky duoc theo ten day du.
	out['C ten long dang ky'] = tostring(
		pb.encode('OAR1.Person.PhoneNumber', { number = 'x' }) ~= nil)
end

out['C conf/kGameRequestData.proto'] = nap_tep('kGameRequestData.proto')
if out['C conf/kGameRequestData.proto'] == 'ok' then
	-- kGameResponseData.proto RONG (chi co import + package) — do rieng xem
	-- `protoc` co chiu mot tep khong message nao khong.
	out['C tep rong nap duoc'] = nap_tep('kGameResponseData.proto')

	local t = { module = 1, funcName = 'f', uid = 12345, sessionId = 's',
		data = 'd', connId = 9, IP = 1000, objName = 'o', serialID = 77,
		serverID = 2 }
	local b = pb.encode('kProtoBuf.GameActionData', t)
	if b == nil then
		out['C GameActionData vong'] = 'ma hoa tra nil'
	else
		local lai = pb.decode('kProtoBuf.GameActionData', b)
		local n, khop = 0, true
		for k, v in pairs(t) do
			n = n + 1
			if lai[k] ~= v then khop = false out['C lech ' .. k] = tostring(lai[k]) end
		end
		for k, v in pairs(lai) do
			if t[k] == nil then khop = false out['C thua ' .. k] = tostring(v) end
		end
		out['C GameActionData so truong'] = tostring(n)
		out['C GameActionData vong'] = khop and 'ok' or 'HONG'
	end
	-- int64 am phai ra du 10 byte varint (chia 28 bit = 4x7, khong phai 32).
	-- `uid` am de ep varint 10 byte; 11 = 10 byte gia tri + 1 byte khoa.
	local am = pb.encode('kProtoBuf.GameActionData', { uid = -1 })
	out['C uid = -1 ra 10 byte'] = tostring(am ~= nil and #am == 11 or false)
end
return out
"""
