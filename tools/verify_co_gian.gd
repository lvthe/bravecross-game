# Chinh sach co gian cua so — kiem KHONG can cua so that.
#
#   godot --headless --path . --script tools/verify_co_gian.gd
#
# `tools/do_co_gian.gd` do bang cua so that (phai co, vi `--headless` dung trinh
# dieu khien hien thi gia nen `--resolution` khong co tac dung). Bo nay trai lai:
# no khong do kich thuoc nao ca, ma kiem ba dieu ma phep do khong giu duoc —
#
#   1. Cai dat du an dung la `stretch/aspect = "expand"` (doi lai thanh `keep`
#      la cong thuc cua ban goc lech ngay, xem duoi).
#   2. Cong thuc cua ban goc van con NGUYEN trong `sc/` — moi dieu khang dinh
#      ve no phai neo vao ma goc, khong phai vao tri nho cua nguoi viet.
#   3. Hai duong tinh — cong thuc hai nhanh cua ban goc, va cach Godot tinh
#      `expand` — ra CUNG mot ket qua tren ca mot dai ti le, chu khong phai chi
#      dung o hai diem lay mau.
#
# Vi sao phai co bo nay: `project.godot` la file cau hinh, khong ai doc lai no
# khi sua man hinh khac. Mot lan doi ve mac dinh cua Godot (`keep`) thi lop Main
# bi dat co theo ti le CUA SO (1,7778) trong khi khung dang ve ra chi ti le 1,5
# — day ra ngoai khung — ma khong bo Lua nao bao loi.
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
	_cai_dat()
	_ma_goc()
	_hai_duong_tinh()
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# 1. Cai dat du an ---------------------------------------------------------

func _cai_dat() -> void:
	var kieu = ProjectSettings.get_setting("display/window/stretch/aspect", "(khong dat)")
	var che_do = ProjectSettings.get_setting("display/window/stretch/mode", "(khong dat)")
	t("stretch/aspect = 'expand' (khong phai mac dinh 'keep')", str(kieu) == "expand", str(kieu))
	t("stretch/mode = 'canvas_items'", str(che_do) == "canvas_items", str(che_do))
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 0)))
	t("viewport dung 960x640 (vung thiet ke cua ban goc)", vp == Vector2(960, 640), str(vp))


# 2. Ma goc ----------------------------------------------------------------

## Doc thang `SetWHScaleToWinSize` chu khong tin tri nho. Tra ve noi dung ham.
func _doc_ma_goc() -> String:
	var f := "res://sc/user/Public/CSceneManager.lua"
	if not FileAccess.file_exists(f):
		return ""
	return FileAccess.get_file_as_string(f)


func _ma_goc() -> void:
	var s := _doc_ma_goc()
	if s == "":
		t("doc duoc sc/user/Public/CSceneManager.lua", false, "khong co file")
		return
	t("co ham SetWHScaleToWinSize", s.contains("function CSceneManager:SetWHScaleToWinSize"))
	# Hai nhanh, nguyen van.
	t("nhanh rong hon: cao giu LogicWinSizeH, rong no ra",
			s.contains("setContentSize(self.LogicWinSizeH * realWinSizeW/realWinSizeH,self.LogicWinSizeH)"))
	t("nhanh hep hon: rong giu LogicWinSizeW, cao no ra",
			s.contains("setContentSize(self.LogicWinSizeW,self.LogicWinSizeW * realWinSizeH/realWinSizeW)"))
	t("so thiet ke la 960x640", s.contains("self.LogicWinSizeW = 960")
			and s.contains("self.LogicWinSizeH = 640"))
	# Tai cho iphoneX: ban goc BO bot be ngang tai cho TRUOC khi tinh ti le. Do
	# la ly do 1137,8x640 do duoc tren may ao la con so DUNG: may ao la android
	# nen `GetLiuHaiWidth` tra 0 (dong dau cua ham), tuc khong bi tru.
	# Xem `ROADMAP.md` §8 muc 9 (phan "Chinh sach co gian", viec (e)) — day la
	# cho `expand` KHONG khop ban goc
	# (ti le > 2,0 tren iOS thi ban goc thu hep vung thiet ke, con `expand` thi
	# khong), ghi ra chu khong im lang bo qua.
	t("GetLiuHaiWidth tra 0 tren android (nen so 1137,8x640 la duong khong khuyet)",
			s.contains("function CSceneManager:GetLiuHaiWidth")
			and s.contains('LGG_GetPlatformString() == "android"'))
	t("GetLiuHaiWidth tra 0 khi ti le <= 2,0 (chi iphoneX moi tru)",
			s.contains("if fRate <= 2.0 then") and s.contains("(60 * realWinSizeW) / 2436"))


# 3. Hai duong tinh --------------------------------------------------------

## Cong thuc hai nhanh cua ban goc, chep lai tu `sc/` — dung so thiet ke 960x640.
func _ban_goc(ti_le: float) -> Vector2:
	if ti_le > LOGIC_W / LOGIC_H:
		return Vector2(LOGIC_H * ti_le, LOGIC_H)
	return Vector2(LOGIC_W, LOGIC_W / ti_le)


## Cach Godot tinh voi `expand`: he so phong = min(W/960, H/640), roi canvas =
## kich thuoc cua so chia he so do. Lay W:H theo ti le, chuan hoa H = 640 cho
## de so (nhan ca hai ve voi cung mot so thi ti le khong doi).
func _godot(ti_le: float) -> Vector2:
	var w := ti_le
	var h := 1.0
	var he_so := minf(w / LOGIC_W, h / LOGIC_H)
	return Vector2(w / he_so, h / he_so)


func _hai_duong_tinh() -> void:
	print("=== hai duong tinh tren mot dai ti le ===")
	var lech_nhat := 0.0
	var so := 0
	var r := 1.0
	while r <= 2.5001:
		var a := _ban_goc(r)
		var b := _godot(r)
		lech_nhat = maxf(lech_nhat, a.distance_to(b))
		so += 1
		r += 0.005
	t("%d ti le (1,0 -> 2,5): cong thuc ban goc BANG cach tinh cua `expand`" % so,
			lech_nhat < 0.001, "lech lon nhat %.6f" % lech_nhat)
	print("  -> %d ti le, lech lon nhat %.9f diem" % [so, lech_nhat])

	# Hai diem neo, va diem neo thu ba: hai ti le do di HAI nhanh khac nhau.
	var r169 := _ban_goc(16.0 / 9.0)
	print("  16:9 -> %.2f x %.2f   (do duoc tren may ao: 1137,8 x 640)"
			% [r169.x, r169.y])
	t("16:9 -> 1137,78 x 640, khop so do tren may ao 16:9",
			absf(r169.x - 1137.78) < 0.01 and absf(r169.y - 640.0) < 0.01, str(r169))
	var r43 := _ban_goc(4.0 / 3.0)
	t("4:3 -> 960 x 720 (rong giu 960, cao no ra)", r43 == Vector2(960, 720), str(r43))
	t("960x640 -> 960 x 640 (ti le 1,5: ca hai nhanh deu ra y nguyen)",
			_ban_goc(1.5) == Vector2(960, 640) and _godot(1.5) == Vector2(960, 640))
	t("16:9 va 4:3 di HAI nhanh khac nhau (khong phai mot luat nhan ti le)",
			r169.y == 640.0 and r43.x == 960.0)
	# Godot lam tron `visible_rect` ve so nguyen, nen canvas that o 1920x1080 la
	# 1137 chu khong phai 1137,78 (do duoc o `tools/do_co_gian.gd`). Kiem luon
	# rang so lam tron do KHONG lam cong thuc sai qua 1 diem.
	t("lam tron canvas ve so nguyen khong lam lech qua 1 diem (1137 vs 1137,78)",
			absf(1137.0 - r169.x) < 1.0)
