## CCProgressTimer cua ban goc — thanh / vong tien do.
##
## HAI thu phai nho, ca hai deu DO chu khong suy:
##
## 1. DO DAI KHONG PHAI PHEP PHONG TO. Do bang anh 1:1 (chup hai luot chay
##    khac nhau dung o `setPercentage`, roi tru diem anh) tren thanh kinh
##    nghiem cua HUD: mep TRAI cua vung to dung yen o MOI gia tri p, chi mep
##    PHAI chay — tuc ban goc CAT anh, khong keo gian no. Vi vay o day ve bang
##    `draw_texture_rect_region` (lay mot phan cua anh roi dat vao mot o nho
##    hon) chu khong phai bang `stretch_mode`. Keo gian se lam mat dang mep
##    vat cua thanh (cac anh `ui_blood_*` deu co mep vat).
##
## 2. KIEU NAM TRONG BAN GHI (+0xF4), khong phai mac dinh cua engine. Sau ten
##    cua `setType` xep theo dung thu tu do (ROADMAP muc 4): 0 cw, 1 ccw,
##    2 lr, 3 rl, 4 bt, 5 tb. Do doc 325 node: 2 -> 262, 3 -> 49, 0 -> 12,
##    4 -> 2. Doi chieu doc lap cho hai kieu co mau: node kieu 2 do ra vung to
##    lon dan sang PHAI (cach mep trai +0), node kieu 4 do ra vung to len TU
##    DUOI (duoi +181 len +0) — dung 'lr' va 'bt'. Kieu 0/1 la vong: ca 12 node
##    kieu 0 deu la hinh VUONG (28x28, 45x45, 81x81, 95x95), trong khi 262 node
##    kieu 2 deu la hinh dai (78x13, 120x28, 350x13...).
##
## CHO CHUA GIAI HET, ghi ro de dung co ma tuong da xong: cong thuc dung cua
## ban goc KHONG phai ti le thuan. Do tren thanh kinh nghiem cua HUD (o 126x21
## tren man):
##
##     p     10  15  20  25  30  50  75  90  100
##     do duoc 0   0   7  14  22  52  90 112  126
##
## Ti le thuan cho 12,6 / 18,9 / 25,2 o p = 20/25/30 — SAI, va p = 10..15 khong
## ve gi trong khi ti le thuan doi 12..19 diem. Binh phuong nho nhat ra
## L = 1,508p - 23,7 (bang 0 o 15,7%). Thanh doc cua man Ngoai (o 54x251) lai
## GAN ti le thuan: H = 2,617p - 8,35 (bang 0 o 3,2%). Hai thanh khong cung mot
## duong, nen co che that chua khoi phuc duoc — o day ve TI LE THUAN, dung o ca
## hai dau (p = 100: 309/325 node; p = 0: 10/325 node, va 10 node do ban goc
## cung khong ve gi), con khuc giua thi lech toi da 11 diem anh tren thanh HUD.
## Da ghi vao ROADMAP muc 8, muc 8 — do lai bang may ao thi con duong.
class_name TienDo
extends Control

const LR := 2
const RL := 3
const BT := 4
const TB := 5
const CW := 0
const CCW := 1

## Sau ten cua `setType` -> ma trong ban ghi (+0xF4). Thu tu o ROADMAP muc 4.
const MA_KIEU := {"cw": CW, "ccw": CCW, "lr": LR, "rl": RL, "bt": BT, "tb": TB}

## He so cua chuong trinh Orange — do tu chinh ban goc, khong suy. Nguon shader
## o `.rodata 0x7cd0c1` (283 byte):
##
##     gl_FragColor = texture2D(u_texture, v_texCoord) * v_fragmentColor;
##     gl_FragColor.r *= 0.9;  gl_FragColor.g *= 2.9;  gl_FragColor.b *= 0.0;
##
## No nhan vao rgb SAU khi da nhan `v_fragmentColor`, tuc tuong duong nhan mau ve
## them mot lan nua — nen o day dat thang vao modulate cua phep ve. Kenh g > 1
## duoc: Godot khong kep mau dinh truoc khi ghi khung, dung nhu GL.
const HE_ORANGE := Color(0.9, 2.9, 0.0, 1.0)

## Bon huong cheo cua o — goc cua chung luon phai nam trong danh sach mau, neu
## khong thi quat bi vat goc (xem quat_vong).
const GOC_GOC := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]

var pct := 100.0
var kieu := LR
var anh: Texture2D = null
var orange := false


## Mau nhan vao phep ve: he so Orange khi dang bat, trang (khong doi gi) khi tat.
func mau_ve() -> Color:
	return HE_ORANGE if orange else Color(1, 1, 1, 1)


## Vung ANH (nguon) va vung VE (dich) cua thanh. Tra [] khi khong ve gi.
##
## `co` la o cua node, `co_anh` la kich thuoc that cua anh. Hai mep neo:
##   lr (2) mep trai  — vung ve moc o trai, rong ra theo p
##   rl (3) mep phai  — moc o phai, rong ra theo p nguoc chieu
##   bt (4) mep duoi  — trong Godot y huong XUONG, nen 'duoi' la y lon
##   tb (5) mep tren
static func o_thanh(k: int, p: float, co: Vector2, co_anh: Vector2) -> Array:
	var t := clampf(p, 0.0, 100.0) / 100.0
	if t <= 0.0 or co.x <= 0.0 or co.y <= 0.0:
		return []
	match k:
		LR:
			return [Rect2(0.0, 0.0, co_anh.x * t, co_anh.y),
					Rect2(0.0, 0.0, co.x * t, co.y)]
		RL:
			return [Rect2(co_anh.x * (1.0 - t), 0.0, co_anh.x * t, co_anh.y),
					Rect2(co.x * (1.0 - t), 0.0, co.x * t, co.y)]
		BT:
			return [Rect2(0.0, co_anh.y * (1.0 - t), co_anh.x, co_anh.y * t),
					Rect2(0.0, co.y * (1.0 - t), co.x, co.y * t)]
		TB:
			return [Rect2(0.0, 0.0, co_anh.x, co_anh.y * t),
					Rect2(0.0, 0.0, co.x, co.y * t)]
	return []


## Quat cua vong (kieu 0/1): tra {diem, uv} — tam o truoc, roi cac diem tren
## BIEN cua o theo goc. Lay diem tren bien chu khong phai tren duong tron ban
## kinh lon: duong tron se ve tran ra ngoai o (anh cua ban goc la hinh vuong,
## phan ngoai o la rac cua mep anh).
##
## Goc 0 = 12 gio, chieu DUONG = theo chieu kim dong ho (khong gian Godot, y
## huong xuong). 'cw' quet tu 0 len, 'ccw' quet tu 360 lui — ten kieu doc tu
## bang `setType` cua engine, con CHO BAT DAU (12 gio) va CHIEU thi CHUA DO
## duoc: ban goc chi co dung MOT node vong chay that (thanh nap game, tu no dao
## 0 -> 100 -> 0), nen chieu sai thi khong lo ra. Ghi lai o ROADMAP.
static func quat_vong(k: int, p: float, co: Vector2, co_anh: Vector2) -> Dictionary:
	var t := clampf(p, 0.0, 100.0)
	if t <= 0.0 or co.x <= 0.0 or co.y <= 0.0:
		return {}
	var quet := t * 3.6                      # 100% = 360 do
	var dau := 0.0 if k == CW else 360.0 - quet
	var c := co * 0.5
	# Goc lay mau: chia deu 6 do mot mau, CONG them dung bon goc cua o — khong
	# co bon goc thi quat bi vat goc: o 28x28 ma buoc 6 do thi moi goc bi hut
	# toi 2 diem anh, va o 81x81 cua man nap thi nhin thay han.
	var goc_ds := PackedFloat32Array()
	var n := clampi(int(ceil(quet / 6.0)), 2, 60)
	for i in n + 1:
		goc_ds.append(quet * float(i) / float(n))
	for g in GOC_GOC:
		var lech := fposmod(_goc(g) - dau, 360.0)
		if lech > 0.0 and lech < quet:
			goc_ds.append(lech)
	goc_ds.sort()
	var diem := PackedVector2Array([c])
	var uv := PackedVector2Array([Vector2(0.5, 0.5)])
	for lech in goc_ds:
		var huong := Vector2(sin(deg_to_rad(dau + lech)), -cos(deg_to_rad(dau + lech)))
		var d := _toi_bien(huong, co)
		diem.append(c + huong * d)
		# Anh ve tran khap o (nhu thanh), nen uv = vi tri / co.
		uv.append((c + huong * d) / co)
	return {"diem": diem, "uv": uv, "co_anh": co_anh}


## Goc cua mot huong theo quy uoc cua `quat_vong`: 0 = 12 gio, chieu duong =
## kim dong ho (khong gian Godot, y huong xuong).
static func _goc(h: Vector2) -> float:
	return fposmod(rad_to_deg(atan2(h.x, -h.y)), 360.0)


## Khoang cach tu tam toi BIEN cua o theo huong `h` (o nam giua node, kich
## thuoc `co`). Truc nao cham bien truoc thi lay truc do.
static func _toi_bien(h: Vector2, co: Vector2) -> float:
	var d := INF
	if absf(h.x) > 1e-8:
		d = minf(d, co.x * 0.5 / absf(h.x))
	if absf(h.y) > 1e-8:
		d = minf(d, co.y * 0.5 / absf(h.y))
	return 0.0 if d == INF else d


func dat_pct(p: float) -> void:
	pct = clampf(p, 0.0, 100.0)
	queue_redraw()


## Bat/tat chuong trinh Orange cua ban goc. Xem `HE_ORANGE` va `S:setOrange`
## trong `lua/tien_do.lua` de biet vi sao nhanh `false` khong doi mot diem anh.
func dat_orange(b: bool) -> void:
	orange = b
	queue_redraw()


## Doi kieu bang TEN nhu ban goc (`setType("cw")`). Tra false neu ten la.
func dat_kieu_theo_ten(ten: String) -> bool:
	var k = MA_KIEU.get(ten)
	if k == null:
		return false
	kieu = int(k)
	queue_redraw()
	return true


func _draw() -> void:
	if anh == null or pct <= 0.0:
		return
	if kieu <= CCW:
		var q := quat_vong(kieu, pct, size, anh.get_size())
		if q.is_empty():
			return
		var mau := PackedColorArray()
		mau.resize((q["diem"] as PackedVector2Array).size())
		mau.fill(mau_ve())
		draw_polygon(q["diem"], mau, q["uv"], anh)
		return
	var o := o_thanh(kieu, pct, size, anh.get_size())
	if o.is_empty():
		return
	draw_texture_rect_region(anh, o[1], o[0], mau_ve())
