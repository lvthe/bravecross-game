# Chinh sach co gian: Godot bao kich thuoc nao, va no co khop voi cong thuc CUA
# BAN GOC khong?
#
#   godot --path . --script tools/do_co_gian.gd
#   godot --path . --resolution 1920x1080 --script tools/do_co_gian.gd
#
# PHAI chay CO cua so that de doi duoc do phan giai: che do `--headless` dung
# trinh dieu khien hien thi gia nen `--resolution` khong co tac dung. Vi vay bo
# nay nam ngoai `check.py` — cung ly do voi `do_xam.gd` va `do_tron.gd`.
#
# CONG THUC CUA BAN GOC (doc thang tu `CSceneManager:SetWHScaleToWinSize`,
# sc/user/Public/CSceneManager.lua:305-326 — KHONG suy tu anh):
#
#     if realW/realH > LogicWinSizeW/LogicWinSizeH then
#         uiObj:setContentSize(LogicWinSizeH * realW/realH, LogicWinSizeH)
#     else
#         uiObj:setContentSize(LogicWinSizeW, LogicWinSizeW * realH/realW)
#
# Voi `LogicWinSizeW/H` = 960/640 (ti le 1,5):
#
#   * rong hon 1,5 (16:9 = 1,7778): CAO dung 640, RONG no ra 640*1,7778 =
#     1137,78  -> khop dung "vung thiet ke nhin thay 1137,8x640" da do tren
#     may ao 16:9.
#   * hep hon 1,5 (4:3 = 1,3333): RONG dung 960, CAO no ra 960/1,3333 = 720.
#
# Do la DUNG cach tinh cua `stretch/aspect = "expand"` cua Godot: he so co bang
# `min(W/960, H/640)`, nen canvas ra `640*ti_le x 640` khi ti le > 1,5 va
# `960 x 960/ti_le` khi ti le < 1,5 — hai nhanh y het nhau. Bo nay DO dieu do
# chu khong tin: no in ra tat ca cac so ma `lua_runtime.gd` doc de do vao
# `screenWidth`/`screenHeight`, va doi chieu voi cong thuc tren.
#
# DA DO (2026-09-17, `stretch/aspect = "expand"`):
#
#   960x640   -> canvas 960x640    (ti le 1,5  -> min(1, 1) = 1, y nhu cu)
#   1920x1080 -> canvas 1137x640   (nhanh rong hon; 1137,78 lam tron thanh 1137)
#   1024x768  -> canvas 960x720    (nhanh hep hon, dung nhanh thu hai)
extends SceneTree

const LOGIC_W := 960.0
const LOGIC_H := 640.0

var ok := 0
var bad := 0


func t(ten: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % note) if note else ""])


func _init() -> void:
	# DO SAU MOT KHUNG HINH, khong do trong `_init`: o che do `--script`, `_init`
	# chay TRUOC khi cua so goc duoc dat theo `project.godot` — do duoc la
	# `Window.size` = 100x100 va `content_scale_mode` = 0 (DISABLED) neu doc
	# ngay trong `_init`, tuc moi so deu la so mac dinh cua mot cua so chua dung.
	process_frame.connect(_do)


func _do() -> void:
	var w := root
	var cua_so := Vector2(w.size)
	var canvas := w.get_visible_rect().size
	var ds := Vector2(DisplayServer.window_get_size())
	print("=== kich thuoc ===")
	print("  che do doi cham : %d  (0 tat, 1 canvas_items, 2 viewport)" % w.content_scale_mode)
	print("  kieu ti le      : %d  (0 ignore, 1 keep, 2 keep_w, 3 keep_h, 4 expand)"
			% w.content_scale_aspect)
	print("  content_scale_size: %s" % [w.content_scale_size])
	print("  Window.size     : %s   <- cho `lua_runtime.gd` doc screenWidth/Height" % [cua_so])
	print("  visible_rect    : %s" % [canvas])
	print("  DisplayServer   : %s   <- cua so that, tinh bang diem anh" % [ds])
	print("  stretch mode    : %s" % ProjectSettings.get_setting(
			"display/window/stretch/mode", "(khong dat)"))
	print("  stretch aspect  : %s" % ProjectSettings.get_setting(
			"display/window/stretch/aspect", "(khong dat)"))

	# Cong thuc cua ban goc, tinh tu TI LE CUA SO (khong phai ti le canvas: lay
	# ti le canvas thi phep kiem thanh vong tron — do chinh cai dang kiem roi
	# dung no lam dau vao). Chi dung TI LE nen don vi (diem anh hay don vi thiet
	# ke) khong anh huong — dung nhu ban goc, o do `GetWinSize` tra diem anh that.
	#
	# Sai so cho phep la 1 diem: Godot lam tron `visible_rect` ve SO NGUYEN,
	# nen o cua so 1920x1080 canvas ra 1137 chu khong phai 1137,78. Do la lam
	# tron cho hien thi, khong phai lech cong thuc — do duoc: 1137 vs 1137,78.
	var logic := _logic(cua_so.x / maxf(cua_so.y, 1.0))
	var ti_le := canvas.x / maxf(canvas.y, 1.0)
	print("\n=== cong thuc ban goc (ti le cua so %.4f) ===" % (cua_so.x / maxf(cua_so.y, 1.0)))
	print("  phai ra: %.2f x %.2f" % [logic.x, logic.y])
	print("  dang ra: %.2f x %.2f" % [canvas.x, canvas.y])
	t("canvas khop cong thuc cua ban goc (le < 1 diem do Godot lam tron so nguyen)",
			canvas.distance_to(logic) <= 1.0, "%s vs %s" % [canvas, logic])

	# `lua_runtime.gd:166-178` do vao `screenWidth`/`screenHeight` tu
	# `root.size`, va `SetWHScaleToWinSize` chia hai so do cho nhau. Nen ti le
	# ma no dung PHAI bang ti le canvas — neu khong thi lop Main bi dat co theo
	# mot ti le khac voi khung dang ve ra (dung cai xay ra voi `keep`: 1,7778
	# so voi 1,5).
	#
	# Sai so cho phep lay tu chinh phep lam tron: canvas rong dung `ti_le` diem
	# thi sai lech toi da la 1/cao diem, tuc 1/640 = 0,0015625.
	if cua_so.y > 0.0 and canvas.y > 0.0:
		var lech_toi_da := 1.0 / canvas.y + 0.000001
		t("ti le cua Window.size bang ti le canvas (day la so ma GetWinSize dung)",
				absf(cua_so.x / cua_so.y - ti_le) <= lech_toi_da,
				"%.4f vs %.4f (cho phep %.6f)" % [cua_so.x / cua_so.y, ti_le, lech_toi_da])

	# Cua so that va canvas phai cung ti le: `expand` khong de lai vien den, nen
	# hai so nay phai trung ti le. Lech ti le nghia la dang co vien den.
	if ds.y > 0.0:
		print("\n=== cua so that vs canvas ===")
		print("  ti le cua so  : %.4f" % (ds.x / ds.y))
		print("  ti le canvas  : %.4f" % ti_le)
		print("  he so phong   : %.4f  (canvas/cua so: %.4f x %.4f)"
				% [ds.y / maxf(canvas.y, 1.0), ds.x / maxf(canvas.x, 1.0),
					ds.y / maxf(canvas.y, 1.0)])

	# Hai dau da do tren ban goc: 16:9 -> 1137,8x640 (may ao), va nhanh kia
	# theo dung cong thuc.
	var r169 := _logic(16.0 / 9.0)
	print("\n=== doi chieu so da do tren may ao 16:9 ===")
	print("  16:9 -> %.2f x %.2f   (ban goc do duoc 1137,8 x 640)" % [r169.x, r169.y])
	t("16:9 ra 1137,8 x 640 — khop so do tren may ao",
			absf(r169.x - 1137.8) < 0.1 and absf(r169.y - 640.0) < 0.01, str(r169))
	var r43 := _logic(4.0 / 3.0)
	t("4:3 ra 960 x 720 (rong giu 960, cao no ra)", absf(r43.x - 960.0) < 0.01
			and absf(r43.y - 720.0) < 0.01, str(r43))
	t("16:9 va 4:3 di HAI nhanh khac nhau cua ban goc (khong phai mot luat)",
			absf(r169.y - 640.0) < 0.01 and absf(r43.x - 960.0) < 0.01)

	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


## Vung thiet ke theo dung hai nhanh cua `SetWHScaleToWinSize`.
func _logic(ti_le: float) -> Vector2:
	if ti_le > LOGIC_W / LOGIC_H:
		return Vector2(LOGIC_H * ti_le, LOGIC_H)
	return Vector2(LOGIC_W, LOGIC_W / ti_le)
