-- Bo protobuf Lua thuan, thay cho mo-dun C `lua-protobuf` (`pb`) cua ban goc.
--
-- VI SAO PHAI VIET LAI. `pb` la mot mo-dun C. Lua o ban dung nam trong addon
-- Godot, nen `require("pb")` khong bao gio giai ra ma C — bat ke dat tep o dau.
-- Do duoc: ban goc goi dung BA ham, o TAM cho, trong sau tep:
--
--     pb.load(bytes)          -> true | nil, vi tri
--     pb.encode(ten, bang)    -> chuoi byte | nil
--     pb.decode(ten, bytes)   -> bang | nil
--
-- `pb.encode` phai nhan CA ten tran ("HandshakeReq") LAN ten co dau cham dau
-- (".google.protobuf.FileDescriptorSet") — do ca hai kieu o cho goi that.
--
-- VI SAO `pb.load` KHONG DUOC PHEP TRA nil. `protoc.lua:1067` goi
-- `pb.load(descriptor_pb)` VO DIEU KIEN, trong khoi `do ... end` mo o dong 970
-- va chua CA `Parser.reload`, `compile`, `load`. Nen mot `pb` gia chi tra nil
-- con TE HON la khong co `pb`: thieu han thi `pcall(require, "pb")` that bai,
-- ca khoi bi bo qua va `protoc` van lai duoc; con co `pb` ma `load` hong thi
-- `require("Framework.Network.pb.protoc")` NEM LOI.
--
-- Lua o day la 5.1 (LuaJIT trong addon): do duoc — KHONG co `string.pack`,
-- `math.type`, `bit32`; co `bit` va `math.frexp`. Nen moi phep ghep byte deu
-- lam bang tay, va khong dung toan tu `//`.
--
-- GIOI HAN DA BIET, ghi ro chu khong im lang: so o Lua 5.1 la double, chinh xac
-- tuyet doi toi 2^53. Truong uint64/int64 vuot 2^53 (vi du `uint64 IP` cua
-- `kGameRequestData.proto`) se MAT chu so cuoi. Ban goc cung vay — lua-protobuf
-- tren LuaJIT dung chung mot loai so.

local M = {}

local floor = math.floor
local frexp = math.frexp
local char = string.char
local byte = string.byte
local sub = string.sub
local concat = table.concat

-- Ma hoa kieu truong, lay dung so cua FieldDescriptorProto.Type (xem blob
-- `descriptor.proto` nhung trong protoc.lua: `TYPE_DOUBLE = 1 ... TYPE_SINT64
-- = 18`). Dung so chu khong dung ten de doi chieu duoc voi blob.
local T_DOUBLE, T_FLOAT = 1, 2
local T_INT64, T_UINT64 = 3, 4
local T_INT32 = 5
local T_FIXED64, T_FIXED32 = 6, 7
local T_BOOL, T_STRING = 8, 9
local T_GROUP, T_MESSAGE, T_BYTES = 10, 11, 12
local T_UINT32, T_ENUM = 13, 14
local T_SFIXED32, T_SFIXED64 = 15, 16
local T_SINT32, T_SINT64 = 17, 18

-- Nhan cua truong trong FieldDescriptorProto: LABEL_OPTIONAL = 1, LABEL_
-- REQUIRED = 2, LABEL_REPEATED = 3.
local L_REPEATED = 3

-- Kieu di tren day (wire type). Nhom (3) va het nhom (4) khong xuat hien trong
-- blob da do — 0 lan — nen khong lam.
local W_VARINT, W_64, W_LEN, W_32 = 0, 1, 2, 5

--------------------------------------------------------------------------
-- 1. Varint
--------------------------------------------------------------------------

-- Tra ve chuoi byte cua mot so nguyen khong dau.
--
-- So AM ma hoa bang dang bu hai 64 bit, va day la cho de sai nhat: cat o moc
-- 32 bit thi LAM LECH nhom 7 bit (32 khong chia het cho 7) va ra chuoi khac
-- ban goc. Cat o moc 28 bit (28 = 4x7) thi khong. Do lai: -1 ra dung muoi byte
-- `FF FF FF FF FF FF FF FF FF 01` — dang chuan cua protobuf.
local function ma_varint(n)
	if n >= 0 then
		local out = {}
		repeat
			local b = n % 128
			n = floor(n / 128)
			out[#out + 1] = char(b + (n > 0 and 128 or 0))
		until n == 0
		return concat(out)
	end
	local lo = n % 268435456				-- 2^28
	local hi = (n - lo) / 268435456 + 68719476736	-- + 2^36
	local out = {}
	for _ = 1, 4 do
		out[#out + 1] = char(lo % 128 + 128)
		lo = floor(lo / 128)
	end
	repeat
		local b = hi % 128
		hi = floor(hi / 128)
		out[#out + 1] = char(b + (hi > 0 and 128 or 0))
	until hi == 0
	return concat(out)
end

-- Doc mot varint. Tra ve (gia tri, vi tri ke tiep).
local function doc_varint(s, i)
	local r, sh = 0, 1
	while true do
		local b = byte(s, i)
		if b == nil then error("varint cut ngang", 0) end
		i = i + 1
		if b < 128 then return r + b * sh, i end
		r = r + (b - 128) * sh
		sh = sh * 128
		if sh > 2 ^ 63 then error("varint qua dai", 0) end
	end
end

-- ZigZag: sint32/sint64 di tren day duoi dang so khong dau.
local function ma_zigzag(n)
	return n >= 0 and n * 2 or (-n) * 2 - 1
end

local function doc_zigzag(u)
	if u % 2 == 0 then return u / 2 end
	return -(u + 1) / 2
end

--------------------------------------------------------------------------
-- 2. Bon byte / tam byte co dinh, va so thuc
--------------------------------------------------------------------------

local function ma_32le(v)
	v = v % 4294967296
	return char(v % 256, floor(v / 256) % 256, floor(v / 65536) % 256,
			floor(v / 16777216) % 256)
end

local function doc_32le(s, i)
	local a, b, c, d = byte(s, i, i + 3)
	if d == nil then error("thieu byte", 0) end
	return a + b * 256 + c * 65536 + d * 16777216, i + 4
end

local function ma_64le(v)
	local lo = v % 4294967296
	local hi = floor(v / 4294967296) % 4294967296
	return ma_32le(lo) .. ma_32le(hi)
end

local function doc_64le(s, i)
	local lo, j = doc_32le(s, i)
	local hi, k = doc_32le(s, j)
	return lo + hi * 4294967296, k
end

-- Dung chuoi byte cua mot double (IEEE-754 nhi phan 64). Lam bang tay vi Lua
-- 5.1 khong co `string.pack`.
local function ma_double(x)
	if x ~= x then return char(0, 0, 0, 0, 0, 0, 248, 127) end	-- NaN
	local am = false
	if x < 0 then am = true; x = -x end
	local mu, dinh
	if x == math.huge then
		mu, dinh = 2047, 0
	elseif x == 0 then
		mu, dinh = 0, 0
	else
		local m, e = frexp(x)			-- x = m * 2^e, m trong [0.5, 1)
		mu = e - 1 + 1023
		dinh = floor((m * 2 - 1) * 4503599627370496 + 0.5)	-- 2^52
		if dinh >= 4503599627370496 then dinh, mu = 0, mu + 1 end
	end
	local v = dinh + mu * 4503599627370496
	if am then v = v + 9223372036854775808 end	-- bit dau
	return ma_64le(v)
end

local function doc_double(s, i)
	local v, j = doc_64le(s, i)
	local am = v >= 9223372036854775808
	if am then v = v - 9223372036854775808 end
	local mu = floor(v / 4503599627370496)
	local dinh = v - mu * 4503599627370496
	local x
	if mu == 2047 then
		x = dinh == 0 and math.huge or (0 / 0)
	elseif mu == 0 and dinh == 0 then
		x = 0
	else
		x = (dinh / 4503599627370496 + 1) * 2 ^ (mu - 1023)
	end
	return am and -x or x, j
end

-- Dung chuoi byte cua mot float (32 bit).
local function ma_float(x)
	if x ~= x then return char(0, 0, 192, 127) end
	local am = false
	if x < 0 then am = true; x = -x end
	local mu, dinh
	if x == math.huge then
		mu, dinh = 255, 0
	elseif x == 0 then
		mu, dinh = 0, 0
	else
		local m, e = frexp(x)
		mu = e - 1 + 127
		dinh = floor((m * 2 - 1) * 8388608 + 0.5)		-- 2^23
		if dinh >= 8388608 then dinh, mu = 0, mu + 1 end
	end
	local v = dinh + mu * 8388608
	if am then v = v + 2147483648 end
	return ma_32le(v)
end

local function doc_float(s, i)
	local v, j = doc_32le(s, i)
	local am = v >= 2147483648
	if am then v = v - 2147483648 end
	local mu = floor(v / 8388608)
	local dinh = v - mu * 8388608
	local x
	if mu == 255 then
		x = dinh == 0 and math.huge or (0 / 0)
	elseif mu == 0 and dinh == 0 then
		x = 0
	else
		x = (dinh / 8388608 + 1) * 2 ^ (mu - 127)
	end
	return am and -x or x, j
end

--------------------------------------------------------------------------
-- 3. Kieu truong -> kieu di tren day
--------------------------------------------------------------------------

local function kieu_day(t)
	if t == T_DOUBLE or t == T_FIXED64 or t == T_SFIXED64 then return W_64 end
	if t == T_FLOAT or t == T_FIXED32 or t == T_SFIXED32 then return W_32 end
	if t == T_STRING or t == T_BYTES or t == T_MESSAGE then return W_LEN end
	return W_VARINT			-- int32/64, uint32/64, sint32/64, bool, enum
end

-- Truong vo huong (khong phai message/string/bytes) va la `repeated` thi mac
-- dinh PACKED voi proto3, KHONG packed voi proto2. Co `[packed=true]` thi lay
-- theo co. Do tren `descriptor.proto` (proto2): `SourceCodeInfo.Location.path`
-- co `B\2\16\1` = options.packed = true, va no la ngoai le duy nhat.
local function la_packed(truong)
	if truong.packed ~= nil then return truong.packed end
	local t = truong.type
	if t == T_STRING or t == T_BYTES or t == T_MESSAGE then return false end
	return truong.proto3 == true
end

--------------------------------------------------------------------------
-- 4. So dang ky kieu
--------------------------------------------------------------------------

-- M.schema[ten] = { ten, truong = { [so] = {so, ten, label, type, type_name,
--                                          packed, proto3} },
--                   so = { cac so truong theo thu tu TANG DAN },
--                   ten2so = { [ten truong] = so } }
local schema = {}
M.schema = schema

local function chuan_hoa(ten)
	if sub(ten, 1, 1) == "." then return sub(ten, 2) end
	return ten
end

local function tra(ten)
	local t = chuan_hoa(ten)
	return schema[t]
end
M.tra = tra

local function dang_ky(ten, danh_sach_truong, proto3)
	local truong, so, ten2so = {}, {}, {}
	for _, f in ipairs(danh_sach_truong) do
		truong[f.so] = f
		so[#so + 1] = f.so
		ten2so[f.ten] = f.so
	end
	table.sort(so)
	schema[ten] = { ten = ten, truong = truong, so = so, ten2so = ten2so }
	return schema[ten]
end

--------------------------------------------------------------------------
-- 5. `descriptor.proto` viet tay
--------------------------------------------------------------------------
--
-- Day la cho MAU CHOT cua ca tep. `pb.load(descriptor_pb)` phai giai duoc mot
-- FileDescriptorSet that, ma muon giai thi phai biet schema cua chinh
-- descriptor.proto — mot vong luon quanh. Nen no phai viet tay.
--
-- Bang duoi lay TU CHINH BLOB: do duoc 21 message, 4 enum, 97 truong, va thu tu
-- truong tren day TANG DAN (do thang: FileDescriptorProto ra [1, 2, 4x18, 8]).
-- Viet theo thu tu khai bao trong nguon descriptor.proto, khong theo so —
-- thu tu do khong quan trong vi luc ma hoa luon di theo so tang dan.
--
-- O day CHI ghi message. Enum khong can bang rieng: truong kieu enum di tren
-- day y het varint, va `pb` khong bao gio phai doi so ra ten.
--
-- Dinh dang moi dong: { so, ten, nhan, kieu, ten kieu (neu la message) }
local D_OPT = "optional"
local D_REP = "repeated"
local D_REQ = "required"

local M_DESCRIPTOR = {
	{ "FileDescriptorSet", {
		{ 1, "file", D_REP, T_MESSAGE, ".google.protobuf.FileDescriptorProto" },
	} },
	{ "FileDescriptorProto", {
		{ 1, "name", D_OPT, T_STRING },
		{ 2, "package", D_OPT, T_STRING },
		{ 3, "dependency", D_REP, T_STRING },
		{ 10, "public_dependency", D_REP, T_INT32 },
		{ 11, "weak_dependency", D_REP, T_INT32 },
		{ 4, "message_type", D_REP, T_MESSAGE, ".google.protobuf.DescriptorProto" },
		{ 5, "enum_type", D_REP, T_MESSAGE, ".google.protobuf.EnumDescriptorProto" },
		{ 6, "service", D_REP, T_MESSAGE, ".google.protobuf.ServiceDescriptorProto" },
		{ 7, "extension", D_REP, T_MESSAGE, ".google.protobuf.FieldDescriptorProto" },
		{ 8, "options", D_OPT, T_MESSAGE, ".google.protobuf.FileOptions" },
		{ 9, "source_code_info", D_OPT, T_MESSAGE, ".google.protobuf.SourceCodeInfo" },
		{ 12, "syntax", D_OPT, T_STRING },
	} },
	{ "DescriptorProto", {
		{ 1, "name", D_OPT, T_STRING },
		{ 2, "field", D_REP, T_MESSAGE, ".google.protobuf.FieldDescriptorProto" },
		{ 6, "extension", D_REP, T_MESSAGE, ".google.protobuf.FieldDescriptorProto" },
		{ 3, "nested_type", D_REP, T_MESSAGE, ".google.protobuf.DescriptorProto" },
		{ 4, "enum_type", D_REP, T_MESSAGE, ".google.protobuf.EnumDescriptorProto" },
		{ 5, "extension_range", D_REP, T_MESSAGE,
				".google.protobuf.DescriptorProto.ExtensionRange" },
		{ 8, "oneof_decl", D_REP, T_MESSAGE, ".google.protobuf.OneofDescriptorProto" },
		{ 7, "options", D_OPT, T_MESSAGE, ".google.protobuf.MessageOptions" },
	} },
	{ "DescriptorProto.ExtensionRange", {
		{ 1, "start", D_OPT, T_INT32 },
		{ 2, "end", D_OPT, T_INT32 },
	} },
	{ "FieldDescriptorProto", {
		{ 1, "name", D_OPT, T_STRING },
		{ 3, "number", D_OPT, T_INT32 },
		{ 4, "label", D_OPT, T_ENUM, ".google.protobuf.FieldDescriptorProto.Label" },
		{ 5, "type", D_OPT, T_ENUM, ".google.protobuf.FieldDescriptorProto.Type" },
		{ 6, "type_name", D_OPT, T_STRING },
		{ 2, "extendee", D_OPT, T_STRING },
		{ 7, "default_value", D_OPT, T_STRING },
		{ 9, "oneof_index", D_OPT, T_INT32 },
		{ 8, "options", D_OPT, T_MESSAGE, ".google.protobuf.FieldOptions" },
	} },
	{ "OneofDescriptorProto", {
		{ 1, "name", D_OPT, T_STRING },
	} },
	{ "EnumDescriptorProto", {
		{ 1, "name", D_OPT, T_STRING },
		{ 2, "value", D_REP, T_MESSAGE, ".google.protobuf.EnumValueDescriptorProto" },
		{ 3, "options", D_OPT, T_MESSAGE, ".google.protobuf.EnumOptions" },
	} },
	{ "EnumValueDescriptorProto", {
		{ 1, "name", D_OPT, T_STRING },
		{ 2, "number", D_OPT, T_INT32 },
		{ 3, "options", D_OPT, T_MESSAGE, ".google.protobuf.EnumValueOptions" },
	} },
	{ "ServiceDescriptorProto", {
		{ 1, "name", D_OPT, T_STRING },
		{ 2, "method", D_REP, T_MESSAGE, ".google.protobuf.MethodDescriptorProto" },
		{ 3, "options", D_OPT, T_MESSAGE, ".google.protobuf.ServiceOptions" },
	} },
	{ "MethodDescriptorProto", {
		{ 1, "name", D_OPT, T_STRING },
		{ 2, "input_type", D_OPT, T_STRING },
		{ 3, "output_type", D_OPT, T_STRING },
		{ 4, "options", D_OPT, T_MESSAGE, ".google.protobuf.MethodOptions" },
		{ 5, "client_streaming", D_OPT, T_BOOL },
		{ 6, "server_streaming", D_OPT, T_BOOL },
	} },
	{ "FileOptions", {
		{ 1, "java_package", D_OPT, T_STRING },
		{ 8, "java_outer_classname", D_OPT, T_STRING },
		{ 10, "java_multiple_files", D_OPT, T_BOOL },
		{ 20, "java_generate_equals_and_hash", D_OPT, T_BOOL },
		{ 27, "java_string_check_utf8", D_OPT, T_BOOL },
		{ 9, "optimize_for", D_OPT, T_ENUM, ".google.protobuf.FileOptions.OptimizeMode" },
		{ 11, "go_package", D_OPT, T_STRING },
		{ 16, "cc_generic_services", D_OPT, T_BOOL },
		{ 17, "java_generic_services", D_OPT, T_BOOL },
		{ 18, "py_generic_services", D_OPT, T_BOOL },
		{ 23, "deprecated", D_OPT, T_BOOL },
		{ 31, "cc_enable_arenas", D_OPT, T_BOOL },
		{ 36, "objc_class_prefix", D_OPT, T_STRING },
		{ 999, "uninterpreted_option", D_REP, T_MESSAGE,
				".google.protobuf.UninterpretedOption" },
	} },
	{ "MessageOptions", {
		{ 1, "message_set_wire_format", D_OPT, T_BOOL },
		{ 2, "no_standard_descriptor_accessor", D_OPT, T_BOOL },
		{ 3, "deprecated", D_OPT, T_BOOL },
		{ 7, "map_entry", D_OPT, T_BOOL },
		{ 999, "uninterpreted_option", D_REP, T_MESSAGE,
				".google.protobuf.UninterpretedOption" },
	} },
	{ "FieldOptions", {
		{ 1, "ctype", D_OPT, T_ENUM, ".google.protobuf.FieldOptions.CType" },
		{ 2, "packed", D_OPT, T_BOOL },
		{ 5, "lazy", D_OPT, T_BOOL },
		{ 3, "deprecated", D_OPT, T_BOOL },
		{ 10, "weak", D_OPT, T_BOOL },
		{ 999, "uninterpreted_option", D_REP, T_MESSAGE,
				".google.protobuf.UninterpretedOption" },
	} },
	{ "EnumOptions", {
		{ 2, "allow_alias", D_OPT, T_BOOL },
		{ 3, "deprecated", D_OPT, T_BOOL },
		{ 999, "uninterpreted_option", D_REP, T_MESSAGE,
				".google.protobuf.UninterpretedOption" },
	} },
	{ "EnumValueOptions", {
		{ 1, "deprecated", D_OPT, T_BOOL },
		{ 999, "uninterpreted_option", D_REP, T_MESSAGE,
				".google.protobuf.UninterpretedOption" },
	} },
	{ "ServiceOptions", {
		{ 33, "deprecated", D_OPT, T_BOOL },
		{ 999, "uninterpreted_option", D_REP, T_MESSAGE,
				".google.protobuf.UninterpretedOption" },
	} },
	{ "MethodOptions", {
		{ 33, "deprecated", D_OPT, T_BOOL },
		{ 999, "uninterpreted_option", D_REP, T_MESSAGE,
				".google.protobuf.UninterpretedOption" },
	} },
	{ "UninterpretedOption", {
		{ 2, "name", D_REP, T_MESSAGE, ".google.protobuf.UninterpretedOption.NamePart" },
		{ 3, "identifier_value", D_OPT, T_STRING },
		{ 4, "positive_int_value", D_OPT, T_UINT64 },
		{ 5, "negative_int_value", D_OPT, T_INT64 },
		{ 6, "double_value", D_OPT, T_DOUBLE },
		{ 7, "string_value", D_OPT, T_BYTES },
		{ 8, "aggregate_value", D_OPT, T_STRING },
	} },
	{ "UninterpretedOption.NamePart", {
		{ 1, "name_part", D_REQ, T_STRING },
		{ 2, "is_extension", D_REQ, T_BOOL },
	} },
	{ "SourceCodeInfo", {
		{ 1, "location", D_REP, T_MESSAGE, ".google.protobuf.SourceCodeInfo.Location" },
	} },
	{ "SourceCodeInfo.Location", {
		{ 1, "path", D_REP, T_INT32 },
		{ 2, "span", D_REP, T_INT32 },
		{ 3, "leading_comments", D_OPT, T_STRING },
		{ 4, "trailing_comments", D_OPT, T_STRING },
		{ 6, "leading_detached_comments", D_REP, T_STRING },
	} },
}

-- Nhan ghi bang CHU trong bang tren cho de doc, nhung moi cho so sanh deu so
-- voi SO (L_REPEATED = 3). Phai doi o day, khong thi moi truong `repeated` bi
-- coi la truong don — `FileDescriptorSet.file` se chi giu 1 trong 18 tep.
local NHAN = { optional = 1, required = 2, repeated = 3 }

local function nap_descriptor()
	for _, m in ipairs(M_DESCRIPTOR) do
		local ds = {}
		for _, f in ipairs(m[2]) do
			ds[#ds + 1] = {
				so = f[1], ten = f[2], label = NHAN[f[3]], type = f[4],
				type_name = f[5], proto3 = false,
			}
		end
		dang_ky("google.protobuf." .. m[1], ds, false)
	end
	-- Ten tran, de `pb.encode(".google.protobuf.X", ...)` va `pb.encode("X", ...)`
	-- deu tra duoc. Do ca hai kieu o cho goi that (protoc.lua dung ten co cham,
	-- Framework/Network dung ten tran).
	for _, m in ipairs(M_DESCRIPTOR) do
		if schema[m[1]] == nil then
			schema[m[1]] = schema["google.protobuf." .. m[1]]
		end
	end
end

nap_descriptor()

--------------------------------------------------------------------------
-- 6. Ma hoa
--------------------------------------------------------------------------

-- Phan DU LIEU cua mot gia tri vo huong, khong kem khoa. Tach rieng vi goi
-- `packed` ghep nhieu gia tri lai sau MOT khoa chung.
local function ghi_than(out, f, v)
	local t = f.type
	if t == T_STRING or t == T_BYTES then
		v = tostring(v)
		out[#out + 1] = ma_varint(#v) .. v
	elseif t == T_DOUBLE then
		out[#out + 1] = ma_double(v)
	elseif t == T_FLOAT then
		out[#out + 1] = ma_float(v)
	elseif t == T_FIXED64 or t == T_SFIXED64 then
		out[#out + 1] = ma_64le(v)
	elseif t == T_FIXED32 or t == T_SFIXED32 then
		out[#out + 1] = ma_32le(v)
	else
		-- int32/int64/uint32/uint64/bool/enum: varint. bool thanh 0/1.
		if t == T_BOOL then v = v and 1 or 0 end
		if t == T_SINT32 or t == T_SINT64 then v = ma_zigzag(v) end
		out[#out + 1] = ma_varint(v)
	end
end

-- Mot truong, kem khoa. Message va chuoi mang san do dai o phan dau truong.
local function ghi_truong(out, f, v)
	local t = f.type
	if t == T_MESSAGE then
		local bytes = M.encode(f.type_name, v)
		if bytes == nil then return false end
		out[#out + 1] = ma_varint(f.so * 8 + W_LEN) .. ma_varint(#bytes) .. bytes
		return true
	end
	out[#out + 1] = ma_varint(f.so * 8 + kieu_day(t))
	ghi_than(out, f, v)
	return true
end

local function ma_thong_diep(sc, t, out)
	for _, so in ipairs(sc.so) do
		local f = sc.truong[so]
		local v = t[f.ten]
		if v ~= nil then
			if f.label == L_REPEATED and type(v) == "table" then
				if la_packed(f) then
					local con = {}
					for _, e in ipairs(v) do ghi_than(con, f, e) end
					local than = concat(con)
					out[#out + 1] = ma_varint(f.so * 8 + W_LEN)
							.. ma_varint(#than) .. than
				else
					for _, e in ipairs(v) do
						if not ghi_truong(out, f, e) then return false end
					end
				end
			elseif not ghi_truong(out, f, v) then
				return false
			end
		end
	end
	return true
end

function M.encode(ten, t)
	local sc = tra(ten)
	if sc == nil or type(t) ~= "table" then return nil end
	local out = {}
	if not ma_thong_diep(sc, t, out) then return nil end
	return concat(out)
end

--------------------------------------------------------------------------
-- 7. Giai ma
--------------------------------------------------------------------------

local function doc_mot_truong(s, i, f)
	local t = f.type
	if t == T_MESSAGE then
		local n, j = doc_varint(s, i)
		return M.decode(f.type_name, sub(s, j, j + n - 1)), j + n
	elseif t == T_STRING or t == T_BYTES then
		local n, j = doc_varint(s, i)
		return sub(s, j, j + n - 1), j + n
	elseif t == T_DOUBLE then
		return doc_double(s, i)
	elseif t == T_FLOAT then
		return doc_float(s, i)
	elseif t == T_FIXED64 or t == T_SFIXED64 then
		return doc_64le(s, i)
	elseif t == T_FIXED32 or t == T_SFIXED32 then
		return doc_32le(s, i)
	else
		local u, j = doc_varint(s, i)
		if t == T_BOOL then return u ~= 0, j end
		if t == T_SINT32 or t == T_SINT64 then return doc_zigzag(u), j end
		return u, j
	end
end

function M.decode(ten, s)
	local sc = tra(ten)
	if sc == nil or type(s) ~= "string" then return nil end
	local t, i = {}, 1
	local ok, err = pcall(function()
		while i <= #s do
			local key
			key, i = doc_varint(s, i)
			local so, wt = floor(key / 8), key % 8
			local f = sc.truong[so]
			if f == nil then
				-- Truong la: bo qua cho dung, dung doan bo.
				if wt == W_VARINT then
					_, i = doc_varint(s, i)
				elseif wt == W_LEN then
					local n; n, i = doc_varint(s, i); i = i + n
				elseif wt == W_64 then i = i + 8
				elseif wt == W_32 then i = i + 4
				else error("kieu di tren day la " .. wt, 0) end
			elseif f.label == L_REPEATED and wt == W_LEN
					and kieu_day(f.type) ~= W_LEN and la_packed(f) then
				local n; n, i = doc_varint(s, i)
				local het = i + n
				t[f.ten] = t[f.ten] or {}
				while i < het do
					local v; v, i = doc_mot_truong(s, i, f)
					t[f.ten][#t[f.ten] + 1] = v
				end
			else
				local v; v, i = doc_mot_truong(s, i, f)
				if f.label == L_REPEATED then
					t[f.ten] = t[f.ten] or {}
					t[f.ten][#t[f.ten] + 1] = v
				else
					t[f.ten] = v
				end
			end
		end
	end)
	if not ok then return nil, err end
	return t
end

--------------------------------------------------------------------------
-- 8. `load`: nhan mot FileDescriptorSet roi dang ky moi message trong do
--------------------------------------------------------------------------

-- Dang ky mot DescriptorProto va moi message long trong no, theo dung ten day
-- du (goi.Ten.Long) — `protoc.lua` sinh ra ten nhu vay tu chinh van ban .proto.
local function dang_ky_message(dp, tien_to, proto3)
	local ds = {}
	local d = dp.field
	if type(d) == "table" then
		for _, fd in ipairs(d) do
			ds[#ds + 1] = {
				so = fd.number,
				ten = fd.name,
				label = fd.label or 1,
				type = fd.type,
				type_name = fd.type_name,
				proto3 = proto3,
			}
		end
	end
	local ten = tien_to .. dp.name
	dang_ky(ten, ds, proto3)
	local nt = dp.nested_type
	if type(nt) == "table" then
		for _, con in ipairs(nt) do
			dang_ky_message(con, ten .. ".", proto3)
		end
	end
	if schema[dp.name] == nil then schema[dp.name] = schema[ten] end
end

function M.load(bytes)
	if type(bytes) ~= "string" then return nil, 1 end
	local set, err = M.decode(".google.protobuf.FileDescriptorSet", bytes)
	if set == nil then return nil, 1 end
	local files = set.file
	if type(files) ~= "table" then return nil, 1 end
	local ok, loi = pcall(function()
		for _, fdp in ipairs(files) do
			local proto3 = fdp.syntax == "proto3"
			local goi = fdp.package and (fdp.package .. ".") or ""
			local mt = fdp.message_type
			if type(mt) == "table" then
				for _, dp in ipairs(mt) do
					dang_ky_message(dp, goi, proto3)
				end
			end
		end
	end)
	if not ok then return nil, 1 end
	return true, #bytes
end

return M
