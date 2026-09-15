# Bang danh sach cua engine (lua/bang.lua): LuaTableView_create / LuaTableViewCell_create.
#
#   godot --headless --path . --script tools/verify_bang.gd
#
# Do cai gi, theo dung hop dong cua BAN GOC (doc tu sc/, khong suy dien):
#
#   A. MOT BANG DUNG RIENG, uy quyen gia — do tung con so cua hop dong:
#      * `LuaTableView_create(uyQuyen, w, h)` phai ra node THAT (khong phai
#        bong), kich thuoc (w,h), `type_name` = 'CCTableView', va CAT phan tran.
#      * `resetNumberOfCellsInTableView(n)` phai goi `tableCellSizeForIndex` roi
#        `tableCellAtIndex` dung n lan, chi so 0..n-1 THEO THU TU.
#      * O thu 0 o mep TREN (kCCTableViewFillTopDown cua Cocos, va cung la thu
#        tu ma `_cfgArr[data.cellIndex + 1]` cua CUIXingHunBook.lua:225 doi).
#      * O phai mang KICH THUOC tu `tableCellSizeForIndex` — thieu thi
#        `hop_noi_dung` cua lop cuon khong thay gi de cuon.
#      * `dequeueAllUseCell` phai tra ve bang LUA that, moi o tra loi
#        `getView()` / `getIdx()`.
#      * Keo phai cuon, va phai KEP o bien (bien tinh doc lap trong file nay).
#      * `scrollTo(1)` = mep CUOI, `scrollTo(0)` = mep dau — ti le cua quang
#        cuon duoc, khong phai cua be cao noi dung (CUISign.lua:905).
#      * Mot cu BAM vao o phai goi `tableCellTouched(tableView, cell)` dung o
#        DUOI NGON TAY.
#      * `dequeueCell(tag)` tra o tu kho; kho rong thi tra nil (duong dung that
#        cua CUITableViewZ_Helper.getOrCreateCell:89).
#
#   B. MOT MAN THAT dung bang: `XingHunBook` — nay phai MO duoc, va trong cay
#      phai co node 'CCTableView' voi o that. Truoc khi co bang thi man nay
#      chet dung o `cocos.lua:458: diem neo khong phai so (table, table) cua
#      <bong LuaTableView_create()>` (do duoc bang tools/quet_show.gd), va
#      `PetIllustration` chet y het.
#
# Con so bien duoc TINH LAI DOC LAP trong file nay tu chinh kich thuoc doc ra tu
# cay Godot, chu khong lay hang so cua lua/bang.lua.
extends SceneTree

const VM := preload("res://tools/vao_main.gd")

const RONG := 200.0     # be rong khung bang trong phep do
const CAO := 300.0      # be cao khung
const H_O := 40.0       # be cao mot o
const SO_O := 20        # 20 * 40 = 800 > 300, tuc co cho ma cuon

var ok := 0
var bad := 0
var lua: LuaRuntime
var san: Control


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


func _init() -> void:
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	var cua_so := Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	lua = LuaRuntime.new()
	lua.cua_so_engine = cua_so
	if not lua.open():
		t("mo Lua", false, ", ".join(lua.errors))
		_ket()
		return
	XggLayout.respect_visible = true
	san = Control.new()
	san.size = cua_so
	san.scale = Vector2.ONE * (vp.y / cua_so.y)
	lua.set_stage(san)
	lua.set_touch_root(san)
	lua.state.globals["_san"] = san

	if lua.run(VM._NAP, "nap") == null:
		t("nap game", false, ", ".join(lua.errors))
		_ket()
		return
	var d := VM.chay(lua)
	if d["dung"] != "":
		t("chuoi Login -> Main", false, str(d["dung"]))
		_ket()
		return
	t("chuoi Login -> Main", true)
	# Hop thoai CHO con nam de man vai chuc khung dau va nuot moi cu cham —
	# do duoc o tools/verify_cuon.gd. Phai cho no tan roi moi do keo/bam.
	_tick(40)

	_dung_bang()
	_keo_bang()
	_bam_o()
	_scroll_to()
	_kho_o()
	_man_that()

	print("  loi Lua: %d" % lua.errors.size())
	for e in lua.errors.slice(maxi(0, lua.errors.size() - 6), lua.errors.size()):
		print("     %s" % str(e).substr(0, 220))
	_ket()


func _ket() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# ---------------------------------------------------------------- dung bang

## Uy quyen gia: ghi lai tung loi goi, tra ve o that voi view that.
##
## Lam y nguyen `CUITableViewZ_Helper.getOrCreateCell` (sc/user/UI/CUITableViewZ.lua:84):
## hoi `dequeueCell` truoc, khong co thi `LuaTableViewCell_create` + copy mau +
## `cell:setView`. Day la duong DUNG THAT chu khong phai duong tat — neu no sai
## thi man that cung sai.
const _UY_QUYEN := """
	local C = require('cocos')
	-- Dem so o TAO MOI, de phan biet "lay tu kho" voi "dung o moi". Boc ham
	-- engine chu khong dem trong uy quyen: uy quyen chi thay `dequeueCell` tra
	-- nil hay khong, con viec tao o moi la do chinh no quyet dinh.
	_g_tao_o = 0
	local tao_o_goc = LuaTableViewCell_create
	LuaTableViewCell_create = function(tag)
		_g_tao_o = _g_tao_o + 1
		return tao_o_goc(tag)
	end
	_g_bang_log = { size = {}, cell = {}, touched = {} }
	local D = {}
	function D:tableCellSizeForIndex(tv, idx)
		_g_bang_log.size[#_g_bang_log.size + 1] = idx
		return 200, 40
	end
	function D:tableCellAtIndex(tv, idx)
		_g_bang_log.cell[#_g_bang_log.cell + 1] = idx
		local o = tv:dequeueCell('o' .. (idx % 3))
		if o == nil then
			o = LuaTableViewCell_create('o' .. (idx % 3))
			local v = C.new_node('')
			v:setContentSize(180, 40)
			v:setPosition(0, 0)
			o:setView(v)
		end
		return o
	end
	function D:tableCellTouched(tv, cell)
		_g_bang_log.touched[#_g_bang_log.touched + 1] = cell:getIdx()
	end
	local tv = LuaTableView_create(D, 200, 300)
	local stage = C.wrap(_san)
	tv:setDirection(1)
	tv:setIsEnableScroll(true)
	tv:setPosition(100, 100)
	stage:addChild(tv)
	_g_bang = tv
	-- Ghi lai toa do (khong gian CUA LOP, Godot) ma lop cuon bao ra luc mot cu
	-- bam ket thuc. Chup lai de khi phep kiem "bam vao o thu may" sai thi con
	-- doc duoc no sai o dau. Day la muc thu HAI cua `moc_bam` (bang.lua dang ky
	-- muc thu nhat).
	_g_bam_log = {}
	require('cocos').cuon.dang_ky_bam(function(lop, node_bat, x, y)
		_g_bam_log[#_g_bam_log + 1] = string.format('%d @ %.1f, %.1f',
			node_bat and node_bat:get_instance_id() or -1, x, y)
	end)
	return true
"""


func _dung_bang() -> void:
	var r = lua.run(_UY_QUYEN, "dung bang")
	t("dung duoc bang", r == true, ", ".join(lua.errors))
	if r != true:
		return

	var k = lua.run("""
		local C = require('cocos')
		local B = require('bootstrap')
		local out = Dictionary()
		local tv = _g_bang
		local gd = C.raw(tv)
		out['la bong'] = tostring(B.la_bong(tv))
		out['la Control'] = tostring(gd:is_class('Control'))
		out['rong'] = tostring(gd.size.x)
		out['cao'] = tostring(gd.size.y)
		out['loai'] = tostring(gd:get_meta('type_name'))
		out['cat tran'] = tostring(gd.clip_contents)
		out['huong'] = tostring(tv:getDirection())
		out['co ten cham'] = tostring(tv:getLuaTouchName())

		tv:resetNumberOfCellsInTableView(20, true, true)

		local ds = tv:dequeueAllUseCell()
		out['so o dang dung'] = tostring(#ds)
		out['bang godot'] = string.format('%.1f, %.1f (%.1f x %.1f)',
			gd.position.x, gd.position.y, gd.size.x, gd.size.y)
		local idx, cao_o, co_view, y_godot = {}, {}, {}, {}
		for i = 1, #ds do
			local o = ds[i]
			idx[#idx + 1] = tostring(o:getIdx())
			local og = C.raw(o)
			cao_o[#cao_o + 1] = string.format('%.1f x %.1f', og.size.x, og.size.y)
			y_godot[#y_godot + 1] = string.format('%.1f', og.position.y)
			local v = o:getView()
			if v == nil then
				co_view[#co_view + 1] = 'nil'
			else
				co_view[#co_view + 1] = string.format('%.1f', C.raw(v).size.y)
			end
		end
		out['idx'] = table.concat(idx, ',')
		out['cao o (dau)'] = cao_o[1] or '-'
		out['cao o (cuoi)'] = cao_o[#cao_o] or '-'
		out['y godot (dau)'] = y_godot[1] or '-'
		out['y godot (cuoi)'] = y_godot[#y_godot] or '-'
		out['cao view (dau)'] = co_view[1] or '-'
		out['goi size'] = tostring(#_g_bang_log.size)
		out['goi cell'] = tostring(#_g_bang_log.cell)
		local thu_tu = {}
		for i = 1, #_g_bang_log.size do thu_tu[#thu_tu + 1] = tostring(_g_bang_log.size[i]) end
		out['thu tu idx do size hoi'] = table.concat(thu_tu, ',')
		thu_tu = {}
		for i = 1, #_g_bang_log.cell do thu_tu[#thu_tu + 1] = tostring(_g_bang_log.cell[i]) end
		out['thu tu idx do cell hoi'] = table.concat(thu_tu, ',')

		-- cellAtIndex(idx) tra dung o thu idx (danh so tu 0 nhu CCTableView).
		local o3 = tv:cellAtIndex(3)
		out['cellAtIndex(3)'] = tostring(o3 ~= nil and o3:getIdx() or -1)
		-- Ngoai pham vi thi ra nil, khong nem loi.
		local o99 = tv:cellAtIndex(99)
		out['cellAtIndex(99)'] = tostring(o99 == nil)
		out['cell_errors'] = tostring(#C.cell_errors)
		return out
	""", "do hinh dang bang")
	t("do hinh dang bang chay", k != null, ", ".join(lua.errors))
	if k == null:
		return

	t("khong phai bong", str(k["la bong"]) == "false", str(k["la bong"]))
	t("la Control that", str(k["la Control"]) == "true", str(k["la Control"]))
	t("kich thuoc dung (200x300)",
			str(k["rong"]) == "200" and str(k["cao"]) == "300",
			"%s x %s" % [k["rong"], k["cao"]])
	t("type_name = CCTableView", str(k["loai"]) == "CCTableView", str(k["loai"]))
	t("cat phan tran ra ngoai khung", str(k["cat tran"]) == "true", str(k["cat tran"]))
	t("setDirection(1) doc ra 1 (truc doc)", str(k["huong"]) == "1", str(k["huong"]))
	t("node co ten cham de nhan Begin", str(k["co ten cham"]) == "tableView",
			str(k["co ten cham"]))

	t("%d o duoc dung" % SO_O, str(k["so o dang dung"]) == str(SO_O), str(k["so o dang dung"]))
	var phan := PackedStringArray()
	for i in range(SO_O):
		phan.append(str(i))
	var idx_dung := ",".join(phan)
	t("getIdx tra 0..%d dung thu tu" % (SO_O - 1), str(k["idx"]) == idx_dung,
			"%s..." % str(k["idx"]).substr(0, 60))
	t("tableCellSizeForIndex duoc hoi dung %d lan" % SO_O,
			str(k["goi size"]) == str(SO_O), str(k["goi size"]))
	t("tableCellAtIndex duoc hoi dung %d lan" % SO_O,
			str(k["goi cell"]) == str(SO_O), str(k["goi cell"]))
	t("hoi size theo thu tu 0..%d" % (SO_O - 1), str(k["thu tu idx do size hoi"]) == idx_dung,
			"%s..." % str(k["thu tu idx do size hoi"]).substr(0, 60))
	t("hoi cell theo thu tu 0..%d" % (SO_O - 1), str(k["thu tu idx do cell hoi"]) == idx_dung,
			"%s..." % str(k["thu tu idx do cell hoi"]).substr(0, 60))

	# Kich thuoc o den tu tableCellSizeForIndex, khong phai tu view (view 180x40).
	t("o mang kich thuoc tu tableCellSizeForIndex (200x40)",
			str(k["cao o (dau)"]) == "200.0 x 40.0" and str(k["cao o (cuoi)"]) == "200.0 x 40.0",
			"%s / %s" % [k["cao o (dau)"], k["cao o (cuoi)"]])
	# O thu 0 o mep TREN: trong khong gian Godot (y xuong) no phai o y = 0.
	t("o thu 0 nam o MEP TREN (godot y = 0)", str(k["y godot (dau)"]) == "0.0",
			str(k["y godot (dau)"]))
	# O cuoi cung cach mep tren (n-1)*40 = 760.
	t("o cuoi cung cach mep tren %d px" % int((SO_O - 1) * H_O),
			str(k["y godot (cuoi)"]) == "760.0", str(k["y godot (cuoi)"]))
	t("o nao cung co view (getView khac nil)", str(k["cao view (dau)"]) == "40.0",
			str(k["cao view (dau)"]))
	t("cellAtIndex(3) tra dung o thu 3", str(k["cellAtIndex(3)"]) == "3",
			str(k["cellAtIndex(3)"]))
	t("cellAtIndex ngoai pham vi tra nil", str(k["cellAtIndex(99)"]) == "true",
			str(k["cellAtIndex(99)"]))
	t("khong o nao dung hong (cocos.cell_errors rong)", str(k["cell_errors"]) == "0",
			str(k["cell_errors"]))


# ------------------------------------------------------------------ keo bong

func _keo_bang() -> void:
	# Bien tinh DOC LAP tu kich thuoc doc ra tu cay: 0 la mep tren, va keo xa
	# nhat la khi mep duoi noi dung cham mep duoi khung.
	var bien := CAO - SO_O * H_O
	print("  bien tinh doc lap: %.1f" % bien)
	t("luc dau chua cuon", is_equal_approx(_lech(), 0.0), str(_lech()))

	_keo(200, 350, 100.0)     # ngoi tay keo LEN 100 px trong khong gian cocos
	var off := _lech()
	t("keo len 100 thi lech = -100", absf(off + 100.0) < 0.5, str(off))

	_tick(2)
	_keo(200, 350, 4000.0, 1)  # keo qua xa -> phai KEP o bien
	_tick(20)
	off = _lech()
	t("keo qua xa thi kep o bien", absf(off - bien) < 0.5,
			"lech=%s bien=%.1f" % [off, bien])

	# O nao bi day ra ngoai khung thi khong cham toi duoc (clip_contents).
	lua.run("_g_bang:scrollTo(0) return true", "ve dau")
	_tick(2)


# ----------------------------------------------------- bam vao o danh sach

func _bam_o() -> void:
	# In toa do ra truoc khi bam: phep kiem "bam vao o thu may" sai thi gan nhu
	# luon la sai o khau doi toa do, va khong co may con so nay thi khong biet
	# sai o khau nao.
	print("  %s" % str(lua.run("""
		local C = require('cocos')
		local gd = C.raw(_g_bang)
		local s = {string.format('bang godot %s', C.raw(_g_bang).position)}
		s[#s + 1] = string.format('bang o cocos (%s, %s)',
			tostring(_g_bang:getPositionX()), tostring(_g_bang:getPositionY()))
		local ds = _g_bang:dequeueAllUseCell()
		for i = 1, math.min(8, #ds) do
			local og = C.raw(ds[i])
			s[#s + 1] = string.format('o %d: y=%.1f cao=%.1f',
				ds[i]:getIdx(), og.position.y, og.size.y)
		end
		return table.concat(s, ' ; ')
	""", "in toa do")))
	# Tam o thu 5 trong khong gian Cocos cua san khau: bang o (100,100) cao 300,
	# o thu i chiem y trong [300-40(i+1), 300-40i] cua bang.
	var cx := 200.0
	var cy := 100.0 + (CAO - H_O * 5.0 - H_O * 0.5)
	lua.run("_g_bang_log.touched = {} _g_bam_log = {} return true", "xoa nhat ky cham")
	_cham("Begin", _p(cx, cy))
	_cham("End", _p(cx, cy))
	print("  bam o cocos (%.1f, %.1f) -> lop cuon bao: %s"
			% [cx, cy, str(lua.run("return table.concat(_g_bam_log, ' | ')",
					"doc vet bam"))])
	var r := str(lua.run("""
		local s = {}
		for i = 1, #_g_bang_log.touched do s[#s + 1] = tostring(_g_bang_log.touched[i]) end
		return table.concat(s, ',')
	""", "doc nhat ky cham"))
	t("bam vao o thu 5 -> tableCellTouched(5)", r == "5", r)

	# Bam ra NGOAI khung bang thi khong duoc goi gi.
	lua.run("_g_bang_log.touched = {} return true", "xoa nhat ky cham")
	_cham("Begin", _p(600, 600))
	_cham("End", _p(600, 600))
	r = str(lua.run("""
		local s = {}
		for i = 1, #_g_bang_log.touched do s[#s + 1] = tostring(_g_bang_log.touched[i]) end
		return table.concat(s, ',')
	""", "doc nhat ky cham"))
	t("bam ngoai khung bang thi khong goi tableCellTouched", r == "", r)

	# Mot lan KEO khong duoc tinh la mot cu bam.
	lua.run("_g_bang_log.touched = {} return true", "xoa nhat ky cham")
	_cham("Begin", _p(cx, cy))
	_cham("Move", _p(cx, cy + 40.0))
	_cham("End", _p(cx, cy + 40.0))
	_tick(20)
	r = str(lua.run("""
		local s = {}
		for i = 1, #_g_bang_log.touched do s[#s + 1] = tostring(_g_bang_log.touched[i]) end
		return table.concat(s, ',')
	""", "doc nhat ky cham"))
	t("keo thi khong goi tableCellTouched", r == "", r)
	lua.run("_g_bang:scrollTo(0) return true", "ve dau")
	_tick(2)


# --------------------------------------------------------------- scrollTo

func _scroll_to() -> void:
	lua.run("_g_bang:scrollTo(1) return true", "xuong cuoi")
	var off := _lech()
	t("scrollTo(1) -> mep cuoi (lech = bien)", absf(off - (CAO - SO_O * H_O)) < 0.5,
			"lech=%s" % off)
	lua.run("_g_bang:scrollTo(0) return true", "ve dau")
	off = _lech()
	t("scrollTo(0) -> mep dau (lech = 0)", is_equal_approx(off, 0.0), str(off))

	# Ti le ngoai [0,1] bi KEP, khong day noi dung ra ngoai khung.
	lua.run("_g_bang:scrollTo(5) return true", "ti le qua lon")
	off = _lech()
	t("scrollTo(5) bi kep ve mep cuoi", absf(off - (CAO - SO_O * H_O)) < 0.5, str(off))
	lua.run("_g_bang:scrollTo(-3) return true", "ti le am")
	off = _lech()
	t("scrollTo(-3) bi kep ve mep dau", is_equal_approx(off, 0.0), str(off))


# ------------------------------------------------------------------- kho o

func _kho_o() -> void:
	# Doi so o roi xep lai: o cu phai ve KHO va `dequeueCell` phai lay lai duoc.
	var r = lua.run("""
		local out = Dictionary()
		local tv = _g_bang
		tv:resetNumberOfCellsInTableView(10, true, true)
		local dung = tv:dequeueAllUseCell()
		local kho = tv:dequeueAllUnUseCell()
		out['so dung'] = tostring(#dung)
		out['so kho'] = tostring(#kho)
		-- Doi so xuong 10 thi phai co o trong kho de dung lai, va khong duoc
		-- TAO o moi (getOrCreateCell:89 hoi kho TRUOC khi goi
		-- LuaTableViewCell_create).
		local n_truoc, o_truoc = #_g_bang_log.cell, _g_tao_o
		tv:resetNumberOfCellsInTableView(10, true, true)
		out['goi cell them'] = tostring(#_g_bang_log.cell - n_truoc)
		out['tao o moi'] = tostring(_g_tao_o - o_truoc)
		out['tao o moi (ca phien)'] = tostring(_g_tao_o)
		local c1 = tv:dequeueCell('o0')
		out['dequeueCell tag la'] = tostring(c1 ~= nil and c1:getStringTag() or '')
		return out
	""", "kho o")
	t("kho o chay", r != null, ", ".join(lua.errors))
	if r == null:
		return
	t("doi xuong 10 o -> dung 10, kho 10",
			str(r["so dung"]) == "10" and str(r["so kho"]) == "10",
			"%s / %s" % [r["so dung"], r["so kho"]])
	# 10 o dau tien tai dung tu kho nen khong phai tao o moi -> khong hoi them.
	t("xep lai van hoi tableCellAtIndex 10 lan",
			str(r["goi cell them"]) == "10", str(r["goi cell them"]))
	t("xep lai KHONG tao o moi (lay tu kho)", str(r["tao o moi"]) == "0",
			str(r["tao o moi"]))
	t("ca phien chi tao dung 20 o cho 20 chi so", str(r["tao o moi (ca phien)"]) == "20",
			str(r["tao o moi (ca phien)"]))
	t("dequeueCell tra o tu kho theo stringTag", str(r["dequeueCell tag la"]) == "o0",
			str(r["dequeueCell tag la"]))


# -------------------------------------------------------------- man that

## XingHunBook (sc/user/UI/XingHun/CUIXingHunBook.lua:132) va PetIllustration
## (sc/user/UI/pet/CUIPetIllustrated.lua:73) — hai man DO DUOC da chet o
## `<bong LuaTableView_create()>` truoc khi co lua/bang.lua.
func _man_that() -> void:
	for m in [["XingHunBook", "user.UI.XingHun.CUIXingHunBook"],
			["PetIllustration", "user.UI.pet.CUIPetIllustrated"]]:
		var ten: String = m[0]
		var mod: String = m[1]
		var truoc := lua.errors.size()
		var r = lua.run("""
			local C = require('cocos')
			local ok, err = pcall(function() require('%s') end)
			if not ok then return 'NAP HONG: ' .. tostring(err) end
			_g_bang_log = { size = {}, cell = {}, touched = {} }
			local ql = nil
			for _, t in ipairs({'g_CUINormalDlg','g_CUISubDialog','g_CUIMessageDlg',
					'g_CUITipsDlg','g_CUIMultiLayerDialog'}) do
				local q = rawget(_G, t)
				if type(q) == 'table' and type(q.UI) == 'table' and q.UI['%s'] then
					ql = q break
				end
			end
			if ql == nil then return 'KHONG QUAN LY NAO GIU MAN NAY' end
			local ok2, err2 = pcall(function() ql:Show('%s') end)
			pcall(function() ql:CloseImmediately() end)
			ql.IsUILock = false
			ql.CurrentUIName = nil
			if not ok2 then return 'HONG: ' .. tostring(err2) end
			return 'ok'
		""" % [mod, ten, ten], "mo " + ten)
		t("%s mo duoc (truoc day chet o <bong LuaTableView_create>)" % ten,
				str(r) == "ok", str(r))
		var vet := ""
		for i in range(truoc, lua.errors.size()):
			vet += str(lua.errors[i]) + " | "
		t("%s khong sinh loi Lua moi" % ten, vet == "", vet.substr(0, 200))


# ------------------------------------------------------------------ tien ich

## Diem cham (toa do canvas) cua mot diem trong khong gian Cocos cua san khau.
func _p(cx: float, cy: float) -> Vector2:
	return LuaRuntime._bien_doi(san) * Vector2(cx, san.size.y - cy)


## Mot lan keo: Begin tai (x0, y0) roi Move/End tung quang `buoc` px.
##
## `buoc` duong = keo LEN (y Cocos tang), tuc noi dung di xuong duoi khung.
func _keo(x0: float, y0: float, buoc: float, so_buoc: int = 4) -> void:
	_cham("Begin", _p(x0, y0))
	for i in range(1, so_buoc + 1):
		_cham("Move", _p(x0, y0 + buoc * i / so_buoc))
	_cham("End", _p(x0, y0 + buoc))


func _cham(pha: String, p: Vector2) -> void:
	lua.touch_at(pha, p)


## Do lech dang ap, doc tu trong Lua (khong doc bien cua ta).
func _lech() -> float:
	var r = lua.run("""
		local o = _g_bang:getContentOffset()
		if math.abs(o.y) > 0.001 then return o.y end
		return o.x
	""", "do lech")
	if r == null:
		return NAN
	return float(str(r))


func _tick(n: int) -> void:
	for i in range(n):
		lua.tick(1.0 / 60.0)
