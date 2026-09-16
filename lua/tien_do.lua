-- CCProgressTimer gia: lop THANH / VONG TIEN DO cua engine (typeName
-- 'CCProgressTimer', type 8 trong .xgg; 325 node trong 73 file bo cuc).
--
-- VI SAO CAN. Ban goc dieu khien thanh tien do HOAN TOAN bang `setPercentage`
-- — 160 cho goi trong ma Lua goc. Thieu lop nay thi moi dong do roi vao bo dem
-- `M.missing` (Node __index tra ve ham dem lai) tuc thanh DUNG YEN: thanh kinh
-- nghiem cua HUD, thanh mau trong tran, thanh ngoai cua man Ngoai deu khong
-- bao gio chay, ma cung khong bao loi gi.
--
-- VIEC THUC SU XAY RA khi goi. Gia tri phan tram duoc ghi vao chinh node Godot
-- (ui/tien_do.gd) — node do ve lai theo KIEU cua no. Kieu KHONG phai mac dinh
-- cua engine ma nam trong ban ghi .xgg (+0xF4): 0 cw, 1 ccw, 2 lr, 3 rl,
-- 4 bt, 5 tb (xem ui/tien_do.gd va ROADMAP muc 8).
--
-- CACH GOI SANG GODOT: qua `C.raw(self)` roi goi THANG phuong thuc/thuoc tinh
-- cua node Godot. Lop boc `C.wrap` da chot `__index` ve bang Node, nen
-- `node:dat_pct(...)` tren lop boc se roi vao bo dem `M.missing` va IM LANG
-- khong lam gi — da do duoc: goi kieu do tra ve khong loi ma `pct` van nguyen
-- 100. Con `raw(self)` giu nguyen doi tuong Godot, va o do ca doc thuoc tinh
-- (`gd.pct`), ghi thuoc tinh (`gd.pct = 40`) lan goi phuong thuc
-- (`gd:dat_pct(60)`) deu chay — ba duong do da kiem bang tay truoc khi viet.
--
-- CHUA LAM, noi ro:
--   * `setOrange` (12 cho goi, luon la true roi false quanh mot doan). Do tren
--     bang bang phuong thuc cua engine: `setOrange` chi co tren DUNG lop nay,
--     khong lop nao khac — nhung NO LAM GI thi chua do duoc (chua doc duoc than
--     ham, cung chua chup duoc anh doi chieu). Nen KHONG dat ten no o day: no
--     van roi vao bo dem `M.missing` nhu cu, de con thay la chua lam, chu khong
--     duoc im lang bo qua.
--   * `setType` voi ten la thi tra ve false va khong doi gi. Ca ma goc chi co
--     DUNG mot cho goi — thanh nap game tu goi "cw"/"ccw" qua S_CCCallFunc
--     (sc/user/UI/CUIDownload.lua:57-69) — va hai ten do co ca.
--   * `setBarChangeRate` / `setMidpoint`: 0 cho goi trong 973 file ma goc, nen
--     khong lam.
return function(C)
	local S = setmetatable({}, { __index = C.Node })

	-- Ma kieu theo S_CCProgressTimer:setType — THU TU sau ten trong bang phuong
	-- thuc cua engine (ROADMAP muc 4), cung bang ma ui/tien_do.gd dung.
	local MA = { cw = 0, ccw = 1, lr = 2, rl = 3, bt = 4, tb = 5 }

	-- Node Godot cua self, hoac nil neu khong phai thanh tien do. Nhan ra bang
	-- thuoc tinh `pct` cua ui/tien_do.gd: chi lop do moi co.
	local function gd_tien_do(self)
		local gd = C.raw(self)
		if gd == nil or gd.pct == nil then return nil end
		return gd
	end

	-- Dat phan tram. Ban goc nhan so; ma Lua goc co cho truyen chuoi so (ghep
	-- tu du lieu) nen ep qua tonumber chu khong doi kieu.
	function S:setPercentage(v)
		local gd = gd_tien_do(self)
		if gd == nil then return end
		local p = tonumber(v)
		if p == nil then return end
		gd:dat_pct(p)
	end

	function S:getPercentage()
		local gd = gd_tien_do(self)
		if gd == nil then return 0 end
		return gd.pct
	end

	-- Doi kieu bang TEN ('cw', 'ccw', 'lr', 'rl', 'bt', 'tb'), hoac bang ma so
	-- trong ban ghi. Tra true neu doi duoc.
	function S:setType(ten)
		local gd = gd_tien_do(self)
		if gd == nil then return false end
		local k = MA[tostring(ten)]
		if k == nil and type(ten) == 'number' then
			k = math.floor(ten)
			if k < 0 or k > 5 then k = nil end
		end
		if k == nil then return false end
		gd.kieu = k
		gd:queue_redraw()
		return true
	end

	function S:getType()
		local gd = gd_tien_do(self)
		if gd == nil then return 0 end
		return gd.kieu
	end

	return S
end
