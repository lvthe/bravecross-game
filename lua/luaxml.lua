-- Nua C cua LuaXML, cho lop gia lap.
--
-- LuaXML cua ban goc co hai nua. Nua LUA la chinh file sc/system/xml.lua cua
-- ban goc: 'local xml = xml; module("xml")' roi dinh nghia tag, new, append,
-- str, save, find, find_direct. Nua C do engine rang buoc san thanh bang toan
-- cuc 'xml' TRUOC khi file do chay, va file do goi thang vao no:
--
--   xml.load, xml.eval   ma goc goi tu ngoai (set_base.lua:24, s_set.lua:13)
--   encode, _save        goi TRONG module("xml") (xml.lua:54, :86), tuc la
--                        xml.encode va xml._save — khong dinh nghia o dau
--                        trong 973 file Lua
--
-- Nen o day CHI lam nua C. Bang nay phai dat thanh 'xml' truoc khi nap ban ke
-- khai (bootstrap.install_cocos): module("xml") thay bang toan cuc san co thi
-- dung lai no, va nua Lua cua ban goc duoc them vao dung bang nay. Truoc day
-- khong co gi dat san, module() tao bang moi chi co nua Lua, va xml.load la nil.
--
-- Phan tu: [0] = ten the, khoa chuoi = thuoc tinh, [1..n] = con (phan tu,
-- hoac chuoi van ban da cat khoang trang); metatable giong het cai new() cua
-- ban goc dat (xml.lua:21), de goi duoc t:find(), t:append().

local xml = { TAG = 0 }

local function gan_mt(t)
	return setmetatable(t, {
		__index = xml,
		__tostring = function(v) return xml.str ~= nil and xml.str(v) or '' end,
	})
end

-- registerCode(giai, ma): cap ky tu / thuc the dung cho encode va eval.
local CAP = {
	{ '&', '&amp;' }, { '<', '&lt;' }, { '>', '&gt;' },
	{ '"', '&quot;' }, { "'", '&apos;' },
}

function xml.registerCode(giai, ma)
	CAP[#CAP + 1] = { giai, ma }
end

local function thay(s, tu, den)
	local i, out = 1, {}
	while true do
		local a, b = s:find(tu, i, true)
		if a == nil then break end
		out[#out + 1] = s:sub(i, a - 1)
		out[#out + 1] = den
		i = b + 1
	end
	out[#out + 1] = s:sub(i)
	return table.concat(out)
end

function xml.encode(s)
	s = tostring(s)
	for _, c in ipairs(CAP) do s = thay(s, c[1], c[2]) end
	return s
end

local function giai_ma(s)
	for i = #CAP, 1, -1 do s = thay(s, CAP[i][2], CAP[i][1]) end
	return s
end

-- Phan tich chuoi XML. Sai cau truc (the dong khong khop) thi tra nil — dung
-- cach LGG_IsXmlValid can de biet file hong.
function xml.eval(s)
	if type(s) ~= 'string' then return nil end
	s = s:gsub('<%?.-%?>', ''):gsub('<!%-%-.-%-%->', '')
	local goc, ngan, i = nil, {}, 1
	while true do
		local a, b, dong, ten, thuoc, tu_dong = s:find('<(/?)([%w_:%.%-]+)(.-)(/?)>', i)
		if a == nil then break end
		local chu = s:sub(i, a - 1):match('^%s*(.-)%s*$')
		if chu ~= '' and #ngan > 0 then
			local cha = ngan[#ngan]
			cha[#cha + 1] = giai_ma(chu)
		end
		if dong == '/' then
			local mo = table.remove(ngan)
			if mo == nil or mo[0] ~= ten then return nil end
		else
			local el = gan_mt({ [0] = ten })
			for k, _, v in thuoc:gmatch('([%w_:%.%-]+)%s*=%s*(["\'])(.-)%2') do
				el[k] = giai_ma(v)
			end
			if #ngan > 0 then
				local cha = ngan[#ngan]
				cha[#cha + 1] = el
			elseif goc == nil then
				goc = el
			end
			if tu_dong ~= '/' then ngan[#ngan + 1] = el end
		end
		i = b + 1
	end
	if #ngan > 0 then return nil end
	return goc
end

-- Doc file. Duong dan tuyet doi (thu muc ghi duoc, LGG_GetSetFilePath) di qua
-- io; duong dan tuong doi ('conf/set_org.xgg') la tai nguyen ban goc.
local function doc(p)
	if type(p) ~= 'string' then return nil end
	if p:match('^%a:[/\\]') or p:sub(1, 1) == '/' then
		local f = io.open(p, 'r')
		if f == nil then return nil end
		local s = f:read('*a')
		f:close()
		return s
	end
	return _godot_doc_file ~= nil and _godot_doc_file(p) or nil
end
xml.doc = doc

function xml.load(p)
	return xml.eval(doc(p))
end

-- _save(chuoi, ten_file): xml.lua:86 goi voi chuoi da dung san bang str().
function xml._save(s, p)
	if type(s) ~= 'string' or type(p) ~= 'string' then return false end
	local f = io.open(p, 'w')
	if f == nil then return false end
	f:write(s)
	f:close()
	return true
end

return xml
