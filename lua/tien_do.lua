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
--   * `setType` voi ten la thi tra ve false va khong doi gi. Ca ma goc chi co
--     DUNG mot cho goi — thanh nap game tu goi "cw"/"ccw" qua S_CCCallFunc
--     (sc/user/UI/CUIDownload.lua:57-69) — va hai ten do co ca.
--   * `setBarChangeRate` / `setMidpoint`: 0 cho goi trong 973 file ma goc, nen
--     khong lam.
--
-- setOrange — DA DO XONG, va ket qua la: nhanh ma ban nay di qua KHONG DOI GI.
--
-- No la gi (do tu file game, khong suy): `CCProgressTimer::setOrange` o
-- 0x2bd1d0 (slot vtable +0x298; `setGray` 0x2bd218 slot +0x290, hai than ham
-- giong het nhau). Than ham: thoat som neu `*(uint8*)(self+0x1cc) == 0`; khong
-- thi lay `inner = *(CCSprite**)(*(self+0x1c8)+0x1d8)` roi goi
-- `inner->vfunc_0x158(b and "ShaderPositionTextureColor_Orange" or
-- "ShaderPositionTextureColor")`. Ca HAI setter cua lop nay deu KHONG ghi `b`
-- vao mot byte co nao — khac `CCSprite::setGray` (0x49d6d4) co
-- `strb.w r1,[r0,#0x23b]`. Bang chi so chuong trinh (work/shaderghep.py --bang,
-- doi chieu voi ma dang ky o 0x4d97ec): 0 Orange, 1 Gray, 9 = ban thuong.
-- Nguon manh Orange o `.rodata 0x7cd0c1` (283 byte):
--
--     gl_FragColor = texture2D(u_texture, v_texCoord) * v_fragmentColor;
--     gl_FragColor.r *= 0.9;  gl_FragColor.g *= 2.9;  gl_FragColor.b *= 0.0;
--
-- Vi sao KHONG doi gi o ban nay. Ca 6 cho goi trong ma goc (CUIGameFinish.lua:
-- 1429, CUIPublic.lua:524, CUIHeroInfoMainUI.lua:1513, CUIHeroListEx.lua:1312,
-- CUIMain.lua:1522, CUIExpShop.lua:148 — 12 dong, moi cho mot cap true/false)
-- deu co dang `if X.setOrange then if GetLanguageName()=="en" then true else
-- false end end`. Ban nay khong bao gio ra "en": `IS_OPEN_LANGUAGE = false`
-- (sc/share/Setting.lua:13) nen danh sach ngon ngu trong man Tuy chon chi con
-- MOT muc, va DEFAULT_LANGUAGE = 'vi'. Nen chi nhanh `false` chay duoc.
--
-- Va nhanh `false` DA DUOC DO la khong doi mot diem anh nao. Ba luot tren may
-- ao (work/emu_pt.py --cam, node `pMainUIHeroExp` cua UI_Main_ControlPanel_
-- 960_640): khong goi gi / goi setOrange(true) / goi setOrange(false) —
--
--   khong goi  vs  setOrange(false) : 0 / 921.600 diem anh khac (lech toi 0)
--   setOrange(false) vs setOrange(true): 2.486 diem khac, TAT CA trong
--                                       (270,139)-(395,159) = dung o thanh dang
--                                       ve, 0 diem khac o ngoai
--
-- Tuc chuong trinh mac dinh DA la "ShaderPositionTextureColor", dung cai ma
-- nhanh `false` dat vao. Nen dat ten phuong thuc nay o day khong lam hinh doi,
-- va bo qua no (de roi vao bo dem `M.missing`) cung khong sai hinh — nhung dat
-- ten thi con ghi lai duoc su that va khong de mot lo hong im lang.
--
-- Phep kiem chuong trinh Orange tren 2.486 diem ay (he so lay tu nguon shader
-- o tren, anh chi duoc phep BAC BO): phep tron mac dinh GL_ONE /
-- GL_ONE_MINUS_SRC_ALPHA cho diem man hinh = S + D*(1-a), nen shader doi
-- `delta = S*(T-1)`; suy nguoc S tu delta roi kiem ba tang: 0 diem sai dau
-- (phai co r<=0, g>=0, b<=0), 0 diem cho S ra ngoai [0,255], va S ra MOT mau do
-- nhat quan (170, 29, 29) voi ti so do duoc delta_g/delta_b = -1,903 so voi
-- -1,9 ma nguon noi. Cong thuc cu "diem moi = diem cu * T" chi khop 1.100/2.486
-- vi no bo qua so hang nen D*(1-a) — con so do la sai, khong phai shader sai.
--
-- CON LAI, ghi ro: nhanh `true` viet theo dung nguon manh tren, nhung vi no
-- khong the chay o ban nay nen CHUA duoc kiem bang anh trong Godot. Va byte
-- +0x1cc co the lam setOrange thanh khong-lam-gi ca voi `true`: do duoc la no
-- KHAC 0 voi `pMainUIHeroExp` (goi true co doi hinh that), con 5 cho kia chua
-- do — neu bang 0 thi cung chi THEM mot phep khong-lam-gi, khong bao gio doi
-- hinh nguoc lai.
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

	-- Bat/tat chuong trinh Orange — xem khoi chu thich DAU FILE de biet day la gi
	-- va vi sao nhanh `false` khong doi mot diem anh nao (do: 0/921.600).
	--
	-- Tra ve chinh `b`, giong ban goc: `setOrange` khong tra gi, nhung ham dem
	-- `M.missing` thi tra nil, nen tra `b` de cho goi nao doc ket qua cung thay
	-- mot gia tri that. Node khong phai thanh tien do thi bo qua — dung nhu ban
	-- goc, o do `X.setOrange` la nil nen ca khoi `if` bi bo.
	function S:setOrange(b)
		local gd = gd_tien_do(self)
		if gd == nil then return end
		b = b and true or false
		gd.orange = b
		gd:queue_redraw()
		return b
	end

	return S
end
