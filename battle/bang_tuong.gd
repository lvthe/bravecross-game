# Day THE TUONG ta o goc duoi-trai man tran: moi tuong mot the gom KHUNG bo goc
# + SAO (bac tuong) + thanh MAU + thanh NO. Ban goc ve day nay trong may C++
# (ChapterObj), ma minh thay may do bang san_tran_ve nen phai tu ve.
#
# HINH LA CUA TA: khung, sao, thanh deu ve bang draw_* (hinh don gian, khong
# chep khung/anh cua ban goc). Mat tuong KHONG ve o day — no la nut ky nang cua
# lop UI goc (anh chan dung asset san co cua game), hien qua o TRONG suot giua
# khung. Khung/sao/thanh nam TREN (CanvasLayer) va chua tam giua nen khong che mat.
#
# Toa do khop nut ky nang do duoc: o=(10,499) kich 96x96 tren man 960x640.
extends Control

const KHUNG_X := 10.0        ## goc trai the dau (khop nut ky nang)
const KHUNG_TOP := 499.0     ## dinh khung (dinh nut ky nang)
const KHUNG_CANH := 96.0     ## canh o mat
const RONG := 96.0           ## be ngang thanh mau/no (= canh khung)
const CAO_MAU := 9.0
const CAO_NO := 6.0
const KHE := 2.0             ## khe giua hai thanh
const CACH := 8.0            ## cach ngang giua cac the

## Moi phan tu: {"ten": String, "mau": 0..1, "no": 0..1, "sao": int, "song": bool}
var tuong: Array = []


func _draw() -> void:
	var x := KHUNG_X
	for t in tuong:
		_ve_the(x, t)
		x += KHUNG_CANH + CACH


func _ve_the(x: float, t: Dictionary) -> void:
	var mau: float = clampf(float(t.get("mau", 0.0)), 0.0, 1.0)
	var no: float = clampf(float(t.get("no", 0.0)), 0.0, 1.0)
	var song: bool = bool(t.get("song", true))
	var sao: int = maxi(0, int(t.get("sao", 1)))
	var mo := 1.0 if song else 0.4

	# KHUNG bo goc quanh mat (ruot trong suot de thay chan dung o lop UI goc).
	var o := Rect2(x, KHUNG_TOP, KHUNG_CANH, KHUNG_CANH)
	var kh := StyleBoxFlat.new()
	kh.bg_color = Color(0, 0, 0, 0)
	kh.set_corner_radius_all(10)
	kh.border_color = Color(0.36, 0.78, 0.30, mo)      # vien xanh la
	kh.set_border_width_all(3)
	draw_style_box(kh, o)
	# Vien ngoai toi mong cho khung noi khoi nen.
	var kh2 := StyleBoxFlat.new()
	kh2.bg_color = Color(0, 0, 0, 0)
	kh2.set_corner_radius_all(12)
	kh2.border_color = Color(0.05, 0.15, 0.05, 0.7 * mo)
	kh2.set_border_width_all(1)
	draw_style_box(kh2, o.grow(1.0))

	# SAO bac tuong: xep giua o day khung (huy hieu).
	if sao > 0:
		var tong := sao * 14.0
		var sx := x + KHUNG_CANH * 0.5 - tong * 0.5 + 7.0
		var sy := KHUNG_TOP + KHUNG_CANH - 9.0
		for i in sao:
			_ve_sao(Vector2(sx + i * 14.0, sy), 6.0, mo)

	# Thanh MAU + NO ngay duoi khung.
	var yb := KHUNG_TOP + KHUNG_CANH + 3.0
	_thanh(Vector2(x, yb), CAO_MAU, mau, Color(0.30, 0.80, 0.28, mo),
			Color(0.16, 0.42, 0.16, mo), mo)
	_thanh(Vector2(x, yb + CAO_MAU + KHE), CAO_NO, no,
			Color(0.98, 0.72, 0.16, mo), Color(0.5, 0.34, 0.06, mo), mo)


## Mot thanh bo goc tron: ranh toi + ruot day + vien duoi dam cho co khoi.
func _thanh(goc: Vector2, cao: float, ti: float, mau_day: Color, mau_dinh: Color,
		mo: float) -> void:
	var r := int(cao * 0.5)
	var ranh := StyleBoxFlat.new()
	ranh.bg_color = Color(0.05, 0.06, 0.08, 0.82 * mo)
	ranh.set_corner_radius_all(r)
	ranh.border_color = Color(0, 0, 0, 0.5 * mo)
	ranh.set_border_width_all(1)
	draw_style_box(ranh, Rect2(goc, Vector2(RONG, cao)))
	if ti <= 0.0:
		return
	var w := maxf(cao, RONG * ti)
	var ruot := StyleBoxFlat.new()
	ruot.bg_color = mau_day
	ruot.set_corner_radius_all(r)
	ruot.border_color = mau_dinh
	ruot.border_width_bottom = int(maxf(1.0, cao * 0.35))
	draw_style_box(ruot, Rect2(goc + Vector2(1, 1), Vector2(w - 2.0, cao - 2.0)))


## Ngoi sao 5 canh (hinh cua ta): huy hieu bac tuong.
func _ve_sao(tam: Vector2, ban_kinh: float, mo: float) -> void:
	var diem := PackedVector2Array()
	for i in 10:
		var r := ban_kinh if i % 2 == 0 else ban_kinh * 0.42
		var g := -PI / 2.0 + i * PI / 5.0
		diem.append(tam + Vector2(cos(g), sin(g)) * r)
	draw_colored_polygon(diem, Color(0.99, 0.83, 0.24, mo))
	draw_polyline(diem + PackedVector2Array([diem[0]]), Color(0.5, 0.34, 0.05, mo), 1.0)
