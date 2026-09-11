-- Giải JSON ra BẢNG LUA THẬT.
--
-- Vì sao không dùng JSON của Godot: dữ liệu Godot đưa sang Lua thành
-- `userdata`. Tra khoá thì được, `#` cũng được, nhưng `ipairs` HỎNG — mà mã
-- gốc duyệt bảng cấu hình bằng `ipairs`/`pairs` khắp nơi. Nên phải ra bảng
-- Lua thật.
--
-- Toàn bộ cấu hình là 6,5 MB, bản lớn nhất ~1 MB. LuaJIT giải chỗ đó dưới một
-- giây, đủ nhanh cho việc nạp một lần rồi nhớ lại.

local M = {}

local byte, sub, find = string.byte, string.sub, string.find
local concat = table.concat

local TRONG = { [32] = true, [9] = true, [10] = true, [13] = true }

local THOAT = {
	[110] = '\n', [116] = '\t', [114] = '\r', [98] = '\b', [102] = '\f',
	[34] = '"', [92] = '\\', [47] = '/',
}


local function bo_trong(s, i)
	while true do
		local c = byte(s, i)
		if c == nil or not TRONG[c] then return i end
		i = i + 1
	end
end


-- Ma Unicode -> UTF-8. Cau hinh co tieng Viet va tieng Trung duoi dang \uXXXX.
local function ma_utf8(n)
	if n < 0x80 then
		return string.char(n)
	elseif n < 0x800 then
		return string.char(0xC0 + math.floor(n / 0x40), 0x80 + n % 0x40)
	elseif n < 0x10000 then
		return string.char(0xE0 + math.floor(n / 0x1000),
			0x80 + math.floor(n / 0x40) % 0x40, 0x80 + n % 0x40)
	end
	return string.char(0xF0 + math.floor(n / 0x40000),
		0x80 + math.floor(n / 0x1000) % 0x40,
		0x80 + math.floor(n / 0x40) % 0x40, 0x80 + n % 0x40)
end


local doc_gia_tri


local function doc_chuoi(s, i)
	i = i + 1                       -- bo dau "
	-- Duong nhanh: khong co dau thoat thi cat thang.
	local j = i
	while true do
		local a, b = find(s, '["\\]', j)
		if a == nil then
			error('JSON: chuoi khong dong o ' .. i)
		end
		if byte(s, a) == 34 then     -- "
			if a == i then return '', a + 1 end
			return sub(s, i, a - 1), a + 1
		end
		-- gap \ : phai di duong cham
		break
	end

	local ra = {}
	local k = i
	while true do
		local c = byte(s, k)
		if c == nil then error('JSON: chuoi khong dong') end
		if c == 34 then
			ra[#ra + 1] = sub(s, i, k - 1)
			return concat(ra), k + 1
		elseif c == 92 then
			ra[#ra + 1] = sub(s, i, k - 1)
			local e = byte(s, k + 1)
			if e == 117 then                    -- \uXXXX
				local hex = sub(s, k + 2, k + 5)
				ra[#ra + 1] = ma_utf8(tonumber(hex, 16) or 63)
				k = k + 6
			else
				ra[#ra + 1] = THOAT[e] or string.char(e or 63)
				k = k + 2
			end
			i = k
		else
			k = k + 1
		end
	end
end


local function doc_so(s, i)
	local a, b = find(s, '^%-?%d+%.?%d*[eE]?[-+]?%d*', i)
	return tonumber(sub(s, a, b)), b + 1
end


local function doc_mang(s, i)
	local t, n = {}, 0
	i = bo_trong(s, i + 1)
	if byte(s, i) == 93 then return t, i + 1 end      -- ]
	while true do
		local v
		v, i = doc_gia_tri(s, i)
		n = n + 1
		t[n] = v
		i = bo_trong(s, i)
		local c = byte(s, i)
		if c == 93 then return t, i + 1 end
		if c ~= 44 then error('JSON: cho , hoac ] o ' .. i) end
		i = bo_trong(s, i + 1)
	end
end


local function doc_bang(s, i)
	local t = {}
	i = bo_trong(s, i + 1)
	if byte(s, i) == 125 then return t, i + 1 end     -- }
	while true do
		if byte(s, i) ~= 34 then error('JSON: cho khoa o ' .. i) end
		local k
		k, i = doc_chuoi(s, i)
		i = bo_trong(s, i)
		if byte(s, i) ~= 58 then error('JSON: cho : o ' .. i) end
		local v
		v, i = doc_gia_tri(s, bo_trong(s, i + 1))
		t[k] = v
		i = bo_trong(s, i)
		local c = byte(s, i)
		if c == 125 then return t, i + 1 end
		if c ~= 44 then error('JSON: cho , hoac } o ' .. i) end
		i = bo_trong(s, i + 1)
	end
end


doc_gia_tri = function(s, i)
	i = bo_trong(s, i)
	local c = byte(s, i)
	if c == 123 then return doc_bang(s, i) end        -- {
	if c == 91 then return doc_mang(s, i) end         -- [
	if c == 34 then return doc_chuoi(s, i) end        -- "
	if c == 116 then return true, i + 4 end           -- true
	if c == 102 then return false, i + 5 end          -- false
	if c == 110 then return nil, i + 4 end            -- null
	if c == nil then error('JSON: het chuoi') end
	return doc_so(s, i)
end


--- Giải một chuỗi JSON. Trả về (bảng) hoặc (nil, lỗi).
function M.decode(s)
	if type(s) ~= 'string' or s == '' then
		return nil, 'rong'
	end
	local ok, v = pcall(function()
		local r = doc_gia_tri(s, 1)
		return r
	end)
	if not ok then return nil, tostring(v) end
	return v
end


--- Đóng gói lại thành JSON. Bản gốc dùng chủ yếu để in log, nhưng vẫn phải
--- có: `cjson.encode` xuất hiện trong mã gốc và thiếu nó thì cả dòng hỏng.
local function ma_hoa(v, ra)
	local t = type(v)
	if v == nil then
		ra[#ra + 1] = 'null'
	elseif t == 'boolean' then
		ra[#ra + 1] = tostring(v)
	elseif t == 'number' then
		ra[#ra + 1] = string.format('%.14g', v)
	elseif t == 'string' then
		ra[#ra + 1] = '"' .. v:gsub('[%c"\\]', function(c)
			if c == '"' then return '\\"' end
			if c == '\\' then return '\\\\' end
			if c == '\n' then return '\\n' end
			if c == '\r' then return '\\r' end
			if c == '\t' then return '\\t' end
			return string.format('\\u%04x', byte(c))
		end) .. '"'
	elseif t == 'table' then
		-- Mang hay bang? Lua khong phan biet, nen do: co phan tu [1] thi coi
		-- la mang, dung dung cach ban goc sinh ra du lieu.
		if v[1] ~= nil or next(v) == nil then
			ra[#ra + 1] = '['
			for i = 1, #v do
				if i > 1 then ra[#ra + 1] = ',' end
				ma_hoa(v[i], ra)
			end
			ra[#ra + 1] = ']'
		else
			ra[#ra + 1] = '{'
			local dau = true
			for k, x in pairs(v) do
				if not dau then ra[#ra + 1] = ',' end
				dau = false
				ma_hoa(tostring(k), ra)
				ra[#ra + 1] = ':'
				ma_hoa(x, ra)
			end
			ra[#ra + 1] = '}'
		end
	else
		ra[#ra + 1] = '"<' .. t .. '>"'
	end
end


function M.encode(v)
	local ra = {}
	ma_hoa(v, ra)
	return concat(ra)
end


return M
