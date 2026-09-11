## Mo THU tung man hinh cua ban goc, bang tay.
##
##   godot --path . tools/xem_man.tscn
##
## Ben trai la danh sach moi man da dang ky (lay tu chinh so dang ky cua ban
## goc: g_CUINormalDlg.UI, g_CUISubDialog.UI...). Bam mot cai la goi dung mot
## dong cua ban goc:
##
##     <quan ly>:Show(<ten>)
##
## va tat ca phan con lai — nap bo cuc, onInit, hoat canh mo, onShow,
## setDialogVisible, onVisible, Reflesh — la ma cua no.
##
##   Tab     an / hien danh sach
##   Esc     dong man dang mo
##
## Man nao khong mo duoc thi dong trang thai noi ro vi sao, va phan lon la
## THIEU DU LIEU NGUOI CHOI chu khong phai thieu engine: may chu cu da chet.
extends Control

const RONG_BANG := 300.0

var _lua: LuaRuntime = null
var _khung: Control = null
var _ds: Array = []          ## [[ten quan ly, ten man]]
var _bang: PanelContainer = null
var _hop: VBoxContainer = null
var _loc: LineEdit = null
var _trang_thai: Label = null
var _dang_mo := ""


func _process(dt: float) -> void:
	if _lua != null:
		_lua.tick(dt)


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	if e.keycode == KEY_TAB:
		_bang.visible = not _bang.visible
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_ESCAPE:
		_dong()
		get_viewport().set_input_as_handled()


func _ready() -> void:
	if not FileAccess.file_exists("res://sc/share/class.lua"):
		_bao("thieu ma goc — chay: python tools/import_lua.py")
		return
	_dung_bang()
	_trang_thai.text = "dang nap ma goc cua ban goc (876 module)..."
	# Cho mot khung hinh de chu kip hien truoc khi nap.
	await get_tree().process_frame
	await get_tree().process_frame

	XggLayout.respect_visible = true
	_khung = XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
	if _khung == null:
		_bao("khong dung duoc khung hop thoai")
		return
	add_child(_khung)
	# Bang chon phai nam TREN cung, khong thi no bi man hinh de len — ma
	# ColorRect nen cua canh nay thi phai nam DUOI, khong thi no che het.
	move_child(_bang, get_child_count() - 1)

	_lua = LuaRuntime.new()
	if not _lua.open():
		_bao("khong mo duoc Lua: %s" % ", ".join(_lua.errors))
		return
	_lua.bind_layout(_khung)
	var goc := XggLayout.find_node(_khung, "UIRootLayer")
	goc.position = Vector2.ZERO
	_lua.set_ui_root(goc)

	var r = _lua.run(_NAP, "nap")
	if r == null:
		_bao("nap hong: %s" % ", ".join(_lua.errors))
		return
	_trang_thai.text = "nap %s module, cau hinh %s — bam mot man de mo (Tab: an bang)" % [
			r.get("nap", "?"), r.get("cau hinh", "?")]

	_ds = []
	var ds = _lua.run(_LIET_KE, "liet ke")
	if ds != null:
		for k in ds:
			_ds.append([str(ds[k]), str(k)])
	_ds.sort_custom(func(a, b): return a[1].naturalnocasecmp_to(b[1]) < 0)
	_ve_danh_sach("")

	# Mo thang mot man tu dong lenh, khoi phai bam:
	#   godot --path . tools/xem_man.tscn -- --mo=AchieveUI
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mo="):
			var ten := a.substr(5)
			for e in _ds:
				if e[1] == ten:
					# Mo thang tu dong lenh thi an bang di cho de nhin
					# (bam Tab de hien lai).
					_bang.visible = false
					_mo(e[0], ten)
					return
			_trang_thai.text = "khong co man ten '%s'" % ten


func _dung_bang() -> void:
	_bang = PanelContainer.new()
	_bang.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_bang.offset_right = RONG_BANG
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	_bang.add_theme_stylebox_override("panel", st)
	add_child(_bang)

	var doc := VBoxContainer.new()
	doc.add_theme_constant_override("separation", 4)
	_bang.add_child(doc)

	_loc = LineEdit.new()
	_loc.placeholder_text = "loc theo ten..."
	_loc.text_changed.connect(_ve_danh_sach)
	doc.add_child(_loc)

	var cuon := ScrollContainer.new()
	cuon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	doc.add_child(cuon)
	_hop = VBoxContainer.new()
	_hop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hop.add_theme_constant_override("separation", 1)
	cuon.add_child(_hop)

	_trang_thai = Label.new()
	_trang_thai.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trang_thai.custom_minimum_size = Vector2(0, 96)
	_trang_thai.add_theme_font_size_override("font_size", 12)
	doc.add_child(_trang_thai)


func _ve_danh_sach(loc: String) -> void:
	for c in _hop.get_children():
		c.queue_free()
	var l := loc.to_lower()
	var n := 0
	for e in _ds:
		var ten: String = e[1]
		if l != "" and not ten.to_lower().contains(l):
			continue
		n += 1
		var b := Button.new()
		b.text = ten
		b.tooltip_text = e[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_mo.bind(e[0], ten))
		_hop.add_child(b)
	if _loc.text == loc:
		_loc.placeholder_text = "loc theo ten... (%d man)" % n


func _dong() -> void:
	if _dang_mo == "" or _lua == null:
		return
	_lua.run(_DONG % _dang_mo, "dong")
	_dang_mo = ""


func _mo(quan_ly: String, ten: String) -> void:
	if _lua == null:
		return
	_dong()
	var r = _lua.run(_MO % [quan_ly, ten, quan_ly, ten], "mo " + ten)
	if r == null:
		_trang_thai.text = "%s: Lua chet — %s" % [ten, ", ".join(_lua.errors)]
		return
	_dang_mo = quan_ly
	var kq := str(r.get("kq", "?"))
	_trang_thai.text = "%s (%s)\n%s" % [ten, quan_ly, kq]


func _bao(msg: String) -> void:
	if _trang_thai != null:
		_trang_thai.text = msg
	push_warning(msg)


## Nap toan bo ma goc theo dung ban ke khai cua no.
const _NAP := """
	local boot = require('bootstrap')
	boot.install_cocos()
	boot.install()
	local bao = boot.boot_goc()
	local out = Dictionary()
	out['nap'] = bao.nap .. '/' .. bao.so
	out['cau hinh'] = boot.init_config()
	-- Ban goc luon o trong mot canh; ten canh la nil thi CLevelLoader khong
	-- ban tin OnLoadXGG va onInit cua man hinh khong bao gio chay. Chua dung
	-- canh Main nen dat "Test" — mot canh co that cua ban goc.
	g_CSceneManager.CurrentScene = 'Test'
	return out
"""

## Lay danh sach man tu chinh so dang ky cua ban goc.
const _LIET_KE := """
	local out = Dictionary()
	for _, ten_ql in ipairs({'g_CUINormalDlg', 'g_CUISubDialog', 'g_CUIMessageDlg',
			'g_CUITipsDlg', 'g_CUIMultiLayerDialog'}) do
		local ql = rawget(_G, ten_ql)
		if type(ql) == 'table' and type(ql.UI) == 'table' then
			for ten, _ in pairs(ql.UI) do out[ten] = ten_ql end
		end
	end
	return out
"""

## Mo mot man. Dung MOT dong cua ban goc, phan con lai la ma cua no.
const _MO := """
	local out = Dictionary()
	local ql = %s
	local ok, err = pcall(function() ql:Show('%s') end)
	local ui = %s.UI['%s']
	if not ok then
		out['kq'] = 'HONG: ' .. tostring(err)
	elseif ui.IsUiShow ~= true and ui.IsUiVisible ~= true then
		-- Ban goc goi Show(ten, data, kieu) va truyen data xuong onShow.
		-- Man nao doi them tham so thi thoat ngay dong dau. nparams dem ca self.
		local inf = debug.getinfo(ui.onShow, 'u')
		out['kq'] = 'IM — onShow doi ' .. tostring(inf and inf.nparams)
			.. ' tham so (ke ca self) ma Show goi tran'
	else
		out['kq'] = 'mo duoc'
	end
	local c = require('cocos')
	for i, e in ipairs(c.cell_errors) do
		if i <= 2 then out['kq'] = tostring(out['kq']) .. '\\n   o hong: ' .. e end
	end
	while #c.cell_errors > 0 do table.remove(c.cell_errors) end
	return out
"""

## Dong man dang mo, va don tay hai cho ban goc khong tu don:
## IsUILock (CloseImmediately khong dat lai) va hang doi hoat canh
## (InsertAnimation chi chay ngay khi hang doi rong).
const _DONG := """
	local ql = %s
	pcall(function() ql:CloseImmediately() end)
	ql.IsUILock = false
	ql.CurrentUIName = nil
	ql.active = nil
	ql.AnimationList = {}
	return true
"""
