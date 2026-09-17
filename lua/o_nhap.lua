-- CCEditBox gia: lop O NHAP CHU cua engine (typeName 'CCEditBox', lop bind 21;
-- 40 node trong 22 file bo cuc).
--
-- VI SAO CAN. Truoc day ui/xgg_layout.gd xep 'CCEditBox' vao kind 'label', tuc
-- moi o nhap thanh mot NHAN CHU: khong go duoc, khong co cho dat chu, va
-- `setText` / `getText` / `getTextWithLen` / `setLuaCallbackObjAndFunc` cua ma
-- goc deu roi vao bo dem `M.missing` — im lang, khong mot loi nao.
--
-- BAY PHUONG THUC, va chung la CA MOT LOP RIENG chu khong phai vai ham them vao
-- Node. Do bang `work/binder.py` (bang dang ky phuong thuc cua chinh engine):
--
--   setText                  1 lop: CCEditBox
--   getText                  1 lop: CCEditBox
--   getTextWithLen           1 lop: CCEditBox
--   setMaxLength             1 lop: CCEditBox
--   setLuaCallbackObjAndFunc 1 lop: CCEditBox
--   setHorizontalAlignment   4 lop: CCLabelTTF, CCLabelBMFont, Label, CCEditBox
--   setVerticalAlignment     3 lop: CCLabelBMFont, Label, CCEditBox
--
-- Nam ham dau KHONG co o lop nao khac trong 132 lop; hai ham cuoi thi co, va
-- CCLabelTTF CO `setHorizontalAlignment` nhung KHONG co `setVerticalAlignment`.
-- Vi vay lop nay la mot BANG RIENG (`C.lop_theo_loai['CCEditBox']`) chu khong
-- phai may ham gan vao Node: nho vay `nhan.getText == nil` dung nhu ban goc, va
-- `if pInput.setText then` (CUIGuildInformation.lua:703) van co nghia — do
-- chinh la kieu ma ban goc tu chan.
--
-- NGU NGHIA DOC TU MA MAY, khong suy doan (work/armdis.py):
--   setText      0x2d1cc5  tham so nil thi KHONG lam gi; khong ban su kien
--   getText      0x2d1c57  tra 1 gia tri; widget trong vang thi tra chuoi rong
--   getTextWithLen 0x2d1c6b tra 2 gia tri (chuoi, do dai co trong so)
--   setMaxLength 0x2d1bcd  `vcvt.s32.f64` -> CAT VE PHIA 0, ghi +0x240
--   setLuaCallbackObjAndFunc 0x2d1bf1  ghi hai ten vao +0x24c / +0x250
--   setHorizontalAlignment 0x2d1c3d -> vtable cua widget trong +0x64
--   setVerticalAlignment   0x2d1c23 -> vtable cua widget trong +0x68
--
-- Widget trong nam o `[obj+0x20c]`. Ban goc KHONG co `setPlaceHolder`,
-- `setInputFlag`, `setInputMode`, `setReturnType` hay `setFontSize` o bat cu lop
-- nao trong 132 lop, nen: che do mat khau va chu mo khong yeu cau duoc tu Lua —
-- mac dinh cua widget trong thi KHONG khoi phuc duoc, va o day khong bia ra.
return function(C)
	local O = setmetatable({}, { __index = C.Node })

	-- Do dai CO TRONG SO cua `getTextWithLen`. Ham boc 0x2d1c6b cong don theo
	-- tung DON VI UTF-16: 2 neu `isWide` dung, 1 neu khong.
	--
	-- `isWide` (0x4de9b0) la mot phep HOAC cac khoang ma:
	local DAI_RONG = {
		{ 0x0E00, 0x0E7F },   -- chu Thai
		{ 0x2E80, 0x2FDF },   -- bo thu CJK
		{ 0x2FF0, 0x30FF },   -- dau cau CJK + katakana
		{ 0x3100, 0x31BF },   -- bopomofo + hangul
		{ 0x31C0, 0x4DFF },   -- net CJK + yi
		{ 0x4E00, 0x9FBF },   -- chu Han
		{ 0xAC00, 0xD7AF },   -- hangul
		{ 0xF900, 0xFAFF },   -- Han tuong thich
		{ 0xFE30, 0xFE4F },   -- mau dau cau CJK
	}
	-- va mot bang 134 muc uint16 o .rodata 0x816180 (doc qua literal
	-- 0x00337800 + pc 0x4de980). Day la NGUYEN VAN bang do, dung thu tu da doc:
	-- 133 muc tu 0x0000 tro di cong mot muc 0x4565 o dau. Muc 0x4565 THUA
	-- (no da nam trong khoang 0x31C0-0x4DFF) va muc 0x0000 cung thua (chuoi ket
	-- thuc o NUL nen khong bao gio hoi tới) — ca hai truong hop deu khong doi
	-- hanh vi, va phep dem 133 + 1 = 134 khop voi so muc do duoc.
	local BANG_RONG = {
		0x4565, 0x0000, 0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C8, 0x00C9,
		0x00CA, 0x00CC, 0x00CD, 0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D9,
		0x00DA, 0x00DD, 0x00E0, 0x00E1, 0x00E2, 0x00E3, 0x00E8, 0x00E9,
		0x00EA, 0x00EC, 0x00ED, 0x00F2, 0x00F3, 0x00F4, 0x00F5, 0x00F9,
		0x00FA, 0x00FD, 0x0102, 0x0103, 0x0110, 0x0111, 0x0128, 0x0129,
		0x0168, 0x0169, 0x01A0, 0x01A1, 0x01AF, 0x01B0, 0x1EA0, 0x1EA1,
		0x1EA2, 0x1EA3, 0x1EA4, 0x1EA5, 0x1EA6, 0x1EA7, 0x1EA8, 0x1EA9,
		0x1EAA, 0x1EAB, 0x1EAC, 0x1EAD, 0x1EAE, 0x1EAF, 0x1EB0, 0x1EB1,
		0x1EB2, 0x1EB3, 0x1EB4, 0x1EB5, 0x1EB6, 0x1EB7, 0x1EB8, 0x1EB9,
		0x1EBA, 0x1EBB, 0x1EBC, 0x1EBD, 0x1EBE, 0x1EBF, 0x1EC0, 0x1EC1,
		0x1EC2, 0x1EC3, 0x1EC4, 0x1EC5, 0x1EC6, 0x1EC7, 0x1EC8, 0x1EC9,
		0x1ECA, 0x1ECB, 0x1ECC, 0x1ECD, 0x1ECE, 0x1ECF, 0x1ED0, 0x1ED1,
		0x1ED2, 0x1ED3, 0x1ED4, 0x1ED5, 0x1ED6, 0x1ED7, 0x1ED8, 0x1ED9,
		0x1EDA, 0x1EDB, 0x1EDC, 0x1EDD, 0x1EDE, 0x1EDF, 0x1EE0, 0x1EE1,
		0x1EE2, 0x1EE3, 0x1EE4, 0x1EE5, 0x1EE6, 0x1EE7, 0x1EE8, 0x1EE9,
		0x1EEA, 0x1EEB, 0x1EEC, 0x1EED, 0x1EEE, 0x1EEF, 0x1EF0, 0x1EF1,
		0x1EF2, 0x1EF3, 0x1EF4, 0x1EF5, 0x1EF6, 0x1EF7,
	}
	O.BANG_RONG = BANG_RONG       -- de bo kiem dem lai: phai dung 134 muc
	O.DAI_RONG = DAI_RONG
	-- Tra cuu bang BANG BAM, khong quet 134 muc cho tung chu: chuoi o day ngan
	-- nhung ham nay chay trong `onGetEditBoxEvent` cua moi lan go phim.
	local RONG_THEM = {}
	for _, c in ipairs(BANG_RONG) do RONG_THEM[c] = true end

	-- Rong hay khong: 0x4de9b0. Cac khoang duoc xet truoc, bang tra sau —
	-- thu tu khong quan trong vi hai ben khong giao nhau (bang toan muc duoi
	-- 0x2000, con cac khoang deu tu 0x2E80 tro len, tru 0x0E00-0x0E7F).
	local function rong(c)
		for _, k in ipairs(DAI_RONG) do
			if c >= k[1] and c <= k[2] then return true end
		end
		return RONG_THEM[c] == true
	end

	-- Doc mot DIEM MA UTF-8 tai vi tri i, tra ve (diem ma, so byte). Byte hong
	-- hay chuoi bi cat ngang thi tra nil — ban goc khong bao gio gap (chuoi do
	-- chinh no giu), nhung day la duong di tu Lua sang.
	local function diem_ma(s, i)
		local b = s:byte(i)
		if b == nil then return nil, 1 end
		if b < 0x80 then return b, 1 end
		if b < 0xC0 then return nil, 1 end
		local b2 = s:byte(i + 1)
		if b < 0xE0 then
			if b2 == nil then return nil, 1 end
			return (b - 0xC0) * 0x40 + (b2 - 0x80), 2
		end
		local b3 = s:byte(i + 2)
		if b < 0xF0 then
			if b2 == nil or b3 == nil then return nil, 1 end
			return (b - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80), 3
		end
		local b4 = s:byte(i + 3)
		if b2 == nil or b3 == nil or b4 == nil then return nil, 1 end
		return (b - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000
				+ (b3 - 0x80) * 0x40 + (b4 - 0x80), 4
	end

	-- Do dai co trong so. Ngoai BMP thi mot chu thanh HAI don vi UTF-16
	-- (cap surrogate), va ca hai don vi deu khong thuoc bang/khoang nao nen
	-- cong dung 2 — dung bang cach hoi tung don vi mot.
	local function do_dai(s)
		local n, i = 0, 1
		while i <= #s do
			local c, k = diem_ma(s, i)
			i = i + k
			if c == nil then
				n = n + 1
			elseif c > 0xFFFF then
				n = n + 2
			elseif rong(c) then
				n = n + 2
			else
				n = n + 1
			end
		end
		return n
	end
	O.do_dai = do_dai

	local function gd_cua(self)
		local gd = C.raw(self)
		if gd == nil then return nil end
		if not gd:has_meta('type_name') then return nil end
		if tostring(gd:get_meta('type_name')) ~= 'CCEditBox' then return nil end
		return gd
	end

	-- Dat chu bang MA. Ban goc (0x2d1cc5): tham so nil thi `beq` thoat NGAY,
	-- khong ghi gi — nen `if pInput.setText then pInput:setText(nil) end` cua
	-- ma goc khong xoa o. Cac kieu khac di qua `tostring`, y nhu `setString`.
	function O:setText(s)
		local gd = gd_cua(self)
		if gd == nil or s == nil then return end
		gd:dat_chu(tostring(s))
	end

	function O:getText()
		local gd = gd_cua(self)
		if gd == nil then return nil end
		return gd:lay_chu()
	end

	function O:getTextWithLen()
		local gd = gd_cua(self)
		if gd == nil then return nil end
		local s = gd:lay_chu()
		return s, do_dai(s)
	end

	function O:setMaxLength(n)
		local gd = gd_cua(self)
		if gd == nil or type(n) ~= 'number' then return end
		gd:dat_dai_toi_da(n)
	end

	function O:setHorizontalAlignment(n)
		local gd = gd_cua(self)
		if gd == nil or type(n) ~= 'number' then return end
		local k = math.floor(n)
		if k < 0 or k > 2 then k = 0 end
		gd:dat_can_ngang(k)
	end

	function O:setVerticalAlignment(n)
		local gd = gd_cua(self)
		if gd == nil or type(n) ~= 'number' then return end
		local k = math.floor(n)
		if k < 0 or k > 2 then k = 0 end
		gd:dat_can_doc(k)
	end

	-- Dang ky ham xu ly su kien. Ma goc goi hai lan:
	--   editBox:setLuaCallbackObjAndFunc("", "")                       -- xoa
	--   editBox:setLuaCallbackObjAndFunc("g_CUIBuyDialogEx", "editboxEventHandler")
	-- (CUIBuyDialogEx.lua:113-114). Cap RONG la "khong co ham" mot cach tu
	-- nhien: `_G[""]` la nil. Ten doi tuong la ten BIEN TOAN CUC, khong phai
	-- node — xem O.su_kien ben duoi.
	function O:setLuaCallbackObjAndFunc(obj, ham)
		local gd = gd_cua(self)
		if gd == nil then return end
		-- Ten cua ban goc la std::string o +0x24c / +0x250 (assign 0x5f3c80),
		-- nen lan goi sau GHI DE lan truoc. Ghi vao meta cua node: trang thai
		-- chet theo node, khong phai don mot bang rieng.
		gd:set_meta('lua_cb_obj', tostring(obj or ''))
		gd:set_meta('lua_cb_ham', tostring(ham or ''))
	end

	-- Ban mot su kien ra ham da dang ky. Ham xu ly nhan DUNG MOT doi so — chuoi
	-- su kien. Bon ten do tu .rodata 0x7a6a30..0x7a6a90: began, changed, ended,
	-- return; ma goc chi dung `changed` (CUIBuyDialogEx.lua:84) va `return`
	-- (CUIUserInfoNickName.lua:142), hai ten kia van ban ra cho dung bo.
	--
	-- `self` cua ham xu ly la DOI TUONG TRA THEO TEN, khong phai node: ban goc
	-- tra `_G[ten]` roi goi <doi tuong>.<ham>(doi tuong, su kien). rawget de
	-- mot bien chua co ra nil THAT, khong thanh BONG.
	function O.su_kien(gd, ten)
		if gd == nil or not gd:has_meta('lua_cb_obj') then return end
		local ten_obj = tostring(gd:get_meta('lua_cb_obj'))
		if ten_obj == '' then return end
		local doi_tuong = rawget(_G, ten_obj)
		if doi_tuong == nil then return end
		local ham = doi_tuong[tostring(gd:get_meta('lua_cb_ham'))]
		if ham == nil then return end
		return ham(doi_tuong, ten)
	end

	return O
end
