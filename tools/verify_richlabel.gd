# Kiem RichLabel — nhan co the mau, va che do tach tung ky tu.
#
#   godot --headless --path . --script tools/verify_richlabel.gd
#
# Hai viec nay la hai loi IM LANG khac nhau, va ca hai deu da xay ra that:
#
# 1. `parseString_` doc co `failed` (`RichLabel.lua:672` gan, `:710` doc). Ban goc
#    doc ra `nil` o lan goi dau nen tach chuoi thanh tung doan; ta doc ra BONG
#    (truthy) nen tra nguyen chuoi lam MOT doan — moi chuoi co the mau hien nguyen
#    the ra man hinh. Do la ca mot tinh nang, khong phai mot chi tiet.
# 2. `getLimitShowCount` / `getLetterEx` truoc day tra 0 / nil, nen `_spriteArray`
#    rong: moi doan chu nam im o (0,0) cua `_containLayer` thay vi duoc xep cho.
#
# Phep kiem nay do BANG SO tren chuoi that, khong doc lai y dinh trong chu thich.
extends SceneTree

var ok := 0
var bad := 0


func t(name: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [name, ("  (%s)" % note) if note else ""])


func _init() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return

	var r = lua.run(_KIEM, "richlabel")
	if r == null:
		print("Lua hong: %s" % ", ".join(lua.errors))
		quit(1)
		return

	t("nap duoc lop RichLabel cua ban goc",
			str(r.get("co lop", "")) == "true", str(r.get("co lop", "?")))

	# 1. Chuoi co the mau phai tach thanh nhieu doan.
	#    '[fontColor=0000FF]Vu khi[/fontColor] dep' -> 2 doan: doan co mau 'Vu khi',
	#    roi doan thuong ' dep'.
	t("chuoi co the mau tach thanh nhieu doan",
			int(r.get("so doan", 0)) == 2, "%s doan" % r.get("so doan", "?"))
	t("doan dau mang mau cua the",
			str(r.get("doan 1 co mau", "")) == "true")
	t("doan dau la chu trong the, khong co the",
			str(r.get("doan 1 chu", "?")) == "Vu khi",
			"[%s]" % r.get("doan 1 chu", "?"))
	t("doan cuoi la chu ngoai the",
			str(r.get("doan 2 chu", "?")) == " dep",
			"[%s]" % r.get("doan 2 chu", "?"))

	# 2. Tach tung ky tu: so node chu phai bang so KY TU (khong phai so byte —
	#    'Vu khi dep' co dau, mot chu 2 byte).
	t("so node chu bang so ky tu",
			int(r.get("so chu", -1)) == int(r.get("so ky tu", -2)),
			"%s node / %s ky tu" % [r.get("so chu", "?"), r.get("so ky tu", "?")])
	t("ghep lai dung chuoi goc (bo the)",
			str(r.get("chu gom lai", "?")) == "Vu khi dep",
			"[%s]" % r.get("chu gom lai", "?"))
	# Moi node dung MOT ky tu, va khong node nao rong: cat theo byte thi chu co
	# dau se bi vo doi.
	t("moi node dung mot ky tu",
			str(r.get("deu mot ky tu", "")) == "true",
			str(r.get("dai nhat", "?")))
	t("nhan goc bi an di (khong ve hai lan)",
			str(r.get("nhan goc an", "")) == "true")
	# Node chu la CON cua NHAN DOAN, khong phai con truc tiep cua lop: luc chay
	# chung mang `parent_h` cua nhan doan (~23) chu khong phai 640 mac dinh, va
	# do la thu quyet dinh cho dat chu. (Do lai o day: truoc khi sua phep kiem,
	# toi viet y nguoc lai va no hong — `getParent()` tra ve nhan doan.)
	t("node chu la con cua nhan doan, khong phai cua lop",
			str(r.get("chu nam trong nhan", "")) == "true")

	# 3. boundingBox: ban goc chi doc hai so cuoi (RichLabel.lua:280), nhung tra
	#    thieu thi `if w < fAdvance` o :282 nem 'compare nil with number'.
	t("boundingBox tra du bon so",
			str(r.get("bb bon so", "")) == "true", str(r.get("bb", "?")))
	t("be rong boundingBox bang co node",
			str(r.get("bb khop co", "")) == "true", str(r.get("bb", "?")))

	# 4. getLetterEx theo chi so (RichLabel:552) va theo KY TU (CGuideLogical:221).
	t("getLetterEx(chi so) tra dung node",
			str(r.get("letter 0", "?")) == "V", str(r.get("letter 0", "?")))
	t("getLetterEx(chu) tra dung node",
			str(r.get("letter theo chu", "?")) == "k",
			str(r.get("letter theo chu", "?")))
	t("getLetterEx ngoai pham vi tra nil",
			str(r.get("letter ngoai", "")) == "true")

	# 5. Cho dat chu: `adjustPosition_` goi `sprite:setPosition`, ma `to_godot`
	#    cong them `parent_h` cua node. Node tao luc chay mang san parent_h = 640,
	#    nen neu khong dat lai theo chieu cao THAT cua nhan doan thi moi chu roi
	#    xuong y = 617 (do duoc) — ngoai khung.
	t("moi chu nam trong khung cua lop",
			str(r.get("trong khung", "")) == "true",
			"y cao nhat %s / lop cao %s" % [r.get("y cao nhat", "?"),
					r.get("cao lop", "?")])
	t("co be rong lop duoc dat theo chu",
			float(str(r.get("rong lop", "0"))) > 0.0,
			str(r.get("rong lop", "?")))

	# 6. Chuoi khong co the: di duong khac (`defaultResult`), mot doan duy nhat.
	t("chuoi khong the ra mot doan",
			int(r.get("so doan thuong", 0)) == 1, str(r.get("so doan thuong", "?")))

	# 7. Doi chu: `setLabelString` xoa con cu roi dung lai. Neu khong xoa thi chu
	#    cu va chu moi chong len nhau.
	t("doi chu thi so node chu doi theo",
			int(r.get("so chu sau khi doi", -1)) == int(r.get("so ky tu moi", -2)),
			"%s / %s" % [r.get("so chu sau khi doi", "?"),
					r.get("so ky tu moi", "?")])
	t("doi chu thi chu cu bi bo het",
			str(r.get("con lai cua chu cu", "")) == "0",
			str(r.get("con lai cua chu cu", "?")))

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


const _KIEM := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	boot.boot_goc()
	local out = Dictionary()

	out['co lop'] = tostring(RichLabel ~= nil and not boot.la_bong(RichLabel))

	-- Dem KY TU cua chuoi Lua (UTF-8 o day, mot chu 2-3 byte). Dem theo byte thi
	-- phep kiem tu no sai, khong phai phep kiem bat duoc loi.
	local function so_ky_tu(s)
		local n, i = 0, 1
		while i <= #s do
			local b = s:byte(i)
			i = i + (b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1)
			n = n + 1
		end
		return n
	end

	local CHUOI = '[fontColor=0000FF]Vu khi[/fontColor] dep'

	-- Doc THANG `parseString_` de dem doan. Ham nay khong doi trang thai.
	local rl = RichLabel:new()
	local doan = rl:parseString_(CHUOI)
	out['so doan'] = #doan
	out['doan 1 co mau'] = tostring(doan[1].fontColor ~= nil)
	out['doan 1 chu'] = tostring(doan[1].text)
	out['doan 2 chu'] = tostring(doan[2].text)
	-- Chuoi khong co the di duong `defaultResult`: dung MOT doan, nguyen van.
	out['so doan thuong'] = #rl:parseString_('khong co the gi')

	-- Duong that: `create` -> init_ -> setLabelString -> parseString_ ->
	-- createSprite_ -> adjustPosition_.
	rl:create({ text = CHUOI, fontSize = 30 })
	local spr = rl._spriteArray or {}
	out['so chu'] = #spr
	out['so ky tu'] = so_ky_tu('Vu khi dep')

	local gom, deu, dai, an, trong_nhan = '', true, 0, true, true
	local lop = rl:getLayer()
	for _, s in ipairs(spr) do
		local t = s:getString()
		gom = gom .. t
		if so_ky_tu(t) ~= 1 then deu = false end
		if #t > dai then dai = #t end
		if s:getIsVisible() == false then an = false end
		if s:getParent() == lop then trong_nhan = false end
	end
	out['chu gom lai'] = gom
	out['deu mot ky tu'] = tostring(deu)
	out['dai nhat'] = tostring(dai)
	-- Nhan doan chu phai BI AN: neu no van ve thi moi doan chu hien HAI lan —
	-- mot lan tai cho cu, mot lan tai cho `adjustPosition_` xep.
	local con = lop:getChildren()
	local nhan_hien = 0
	for _, c in ipairs(con) do
		if c:getString() ~= '' and c:getIsVisible() ~= false then nhan_hien = nhan_hien + 1 end
	end
	out['nhan goc an'] = tostring(nhan_hien == 0)
	-- Node chu phai la CON cua nhan doan: luc chay chung mang `parent_h` cua nhan
	-- doan chu khong phai 640 mac dinh.
	out['chu nam trong nhan'] = tostring(trong_nhan)

	if #spr > 0 then
		local x, y, w, h = spr[1]:boundingBox()
		local cw, ch = spr[1]:getContentSize()
		out['bb'] = x .. ',' .. y .. ',' .. w .. ',' .. h
		out['bb bon so'] = tostring(type(x) == 'number' and type(y) == 'number'
			and type(w) == 'number' and type(h) == 'number')
		out['bb khop co'] = tostring(w == cw and h == ch)
		out['rong lop'] = tostring(lop:getContentSize())
	end

	-- getLetterEx: theo CHI SO (nhan doan dau — doan co mau) va theo KY TU.
	local nhan1 = con[1]
	out['letter 0'] = tostring(nhan1:getLetterEx(0, true)
		and nhan1:getLetterEx(0, true):getString() or 'nil')
	out['letter theo chu'] = tostring(nhan1:getLetterEx('k')
		and nhan1:getLetterEx('k'):getString() or 'nil')
	out['letter ngoai'] = tostring(nhan1:getLetterEx(99) == nil)

	-- Cho dat: khong chu nao duoc roi ra ngoai khung cua lop.
	local cao = select(2, lop:getContentSize())
	local tren = -1e9
	for _, s in ipairs(spr) do
		local _, py = s:getPosition()
		if py > tren then tren = py end
	end
	out['cao lop'] = tostring(cao)
	out['y cao nhat'] = tostring(tren)
	out['trong khung'] = tostring(tren <= cao)

	-- Doi chu.
	local MOI = 'Ao giap'
	rl:setLabelString(MOI)
	local spr2 = rl._spriteArray or {}
	out['so chu sau khi doi'] = #spr2
	out['so ky tu moi'] = so_ky_tu(MOI)
	-- Con cu phai bi bo sach: dem con cua lop tru chu cua nhan moi.
	local con2 = lop:getChildren()
	local lai = 0
	for _, c in ipairs(con2) do
		local co_con = c:getChildrenCount()
		local cua_chu_moi = false
		for _, g in ipairs(c:getChildren()) do
			for _, s2 in ipairs(spr2) do
				if s2 == g then cua_chu_moi = true end
			end
		end
		if not cua_chu_moi and co_con > 0 then lai = lai + co_con end
	end
	out['con lai cua chu cu'] = tostring(lai)

	return out
"""
