# Cho dung quan: hang so LAN cua man tran phai dung bang hang so cua ban goc.
#
#   godot --headless --path . --script tools/verify_lan.gd
#
# Truoc day bon nam hang so cua `battle/san_tran_ve.gd` (`LAN_CACH`, `LAN_LECH`,
# `LAN_SO`, `ARMY_SPACE`) va nam hang so camera la ĐẶT: ghi chu noi "suy tu chinh
# `map/global_config.xml`" chu chua co cho nao trong file game noi ro engine dung
# chung the nao. Nay do duoc het (xem `brave-cross/work/tran_ref.py`):
#
#   * DON VI la O: chinh file cau hinh ghi chu `<!-- 道宽 格 -->` tren hai hang so
#     do, va engine nhan voi co o tinh bang px (`0x35f43e` doc `fLaneWidth` roi
#     `vmul.f32` voi o `+0x270` = `this+0x180`);
#   * CONG THUC xep lan: `0x35f0a4` = `y = y0 + (Location-1) * rong + lech`;
#   * SO LAN: `Location` cua bang binh chung chi nhan 0..3 (91 muc).
#
# Nen bo kiem nay khong hoi "chay duoc khong" — no hoi MAN TRAN co con dung so
# cua ban goc khong. Mot lan ai do sua `LAN_CACH` cho dep mat thi do la cho hong,
# chu khong phai mot lan lam moi.
#
# Du lieu (`data_ref/tran_ref.json`) khong commit duoc — sinh tu file cua ban goc,
# xem .gitignore — nen thieu thi bao BO QUA chu khong bao hong.
extends SceneTree

const TRAN := "res://data_ref/tran_ref.json"
const BANG_LINH := "res://data_ref/config/share/KDBGameArmyConfig.xgg"
const STV := preload("res://battle/san_tran_ve.gd")

var ok := 0
var bad := 0


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


func _init() -> void:
	var txt := FileAccess.get_file_as_string(TRAN)
	if txt.is_empty():
		print("BO QUA: khong co %s" % TRAN)
		print("  sinh bang: python ../brave-cross/work/tran_ref.py")
		_ket()
		return
	var d = JSON.parse_string(txt)
	t("tran_ref.json doc duoc", d is Dictionary)
	if not (d is Dictionary):
		_ket()
		return

	# --- 1. Co o, va don vi px cua no -------------------------------------------
	# Ba duong doc lap trong file game deu noi co o = 100 px. Neu nguon doi co o
	# thi MOI con so ben duoi doi theo, nen kiem cai nay truoc.
	var co: Dictionary = d.get("co_o", {})
	var o_px := float(d.get("o_px", 0))
	t("co o doc duoc", o_px > 0.0, str(o_px))
	t("co o vuong", float(co.get("rong_px", 0)) == float(co.get("cao_px", -1)),
			"%s x %s" % [co.get("rong_px"), co.get("cao_px")])
	t("O_PX cua man tran bang co o", STV.O_PX == o_px,
			"ta %s, ban goc %s" % [STV.O_PX, o_px])

	# --- 2. Bang chung DON VI con nam trong bang so ------------------------------
	# Hai chu thich 道宽 格 la thu phan quyet dinh "don vi la o". Bang so sinh lai
	# ma mat chung thi phai biet, chu khong de no lang le thanh suy luan lai.
	var lan: Dictionary = d.get("lan", {})
	var chung: Dictionary = lan.get("chung", {})
	t("bang so giu chu thich don vi cua ban goc",
			not String(chung.get("fLaneWidth", "")).is_empty()
			and not String(chung.get("fLaneOffset", "")).is_empty(),
			JSON.stringify(chung))
	t("cong thuc xep lan ghi trong bang so",
			String(lan.get("cong_thuc", "")).find("Location") >= 0,
			String(lan.get("cong_thuc", "")))

	# --- 3. Hai hang so LAN cua man tran ----------------------------------------
	var rong_o := float(lan.get("rong_o", 0))
	var lech_o := float(lan.get("lech_o", 0))
	t("rong lan = 0.4 o", is_equal_approx(rong_o, 0.4), str(rong_o))
	t("lech lan = 0.1 o", is_equal_approx(lech_o, 0.1), str(lech_o))
	t("LAN_CACH = rong lan * co o", is_equal_approx(STV.LAN_CACH, rong_o * o_px),
			"ta %s, ban goc %s" % [STV.LAN_CACH, rong_o * o_px])
	t("LAN_LECH = lech lan * co o", is_equal_approx(STV.LAN_LECH, lech_o * o_px),
			"ta %s, ban goc %s" % [STV.LAN_LECH, lech_o * o_px])
	# 0.4 x 100 = 40 px va 0.1 x 100 = 10 px: chot luon con so cu the, vi do moi la
	# thu nguoi doc man tran nhin thay.
	t("LAN_CACH = 40 px", is_equal_approx(STV.LAN_CACH, 40.0), str(STV.LAN_CACH))
	t("LAN_LECH = 10 px", is_equal_approx(STV.LAN_LECH, 10.0), str(STV.LAN_LECH))

	# --- 4. Cong thuc cua engine: lan 1/2/3 -> 10/50/90 px ----------------------
	# Day la phep kiem chinh cua ca bo: `lan_lech_y` la cho DUY NHAT trong man tran
	# tinh chuyen lan ra toa do, va no phai khop tung con so cua
	# `lech_px_theo_lan` (sinh tu `y = y0 + (Location-1)*rong + lech`).
	var theo_lan: Array = lan.get("lech_px_theo_lan", [])
	t("bang so co du ba lan", theo_lan.size() == 3, str(theo_lan.size()))
	for n in range(1, mini(4, theo_lan.size() + 1)):
		var mong := float(theo_lan[n - 1])
		t("lan %d lech %.1f px" % [n, mong],
				is_equal_approx(STV.lan_lech_y(n), mong),
				"ta %s" % STV.lan_lech_y(n))
	t("lan 1/2/3 = 10/50/90 px",
			is_equal_approx(STV.lan_lech_y(1), 10.0)
			and is_equal_approx(STV.lan_lech_y(2), 50.0)
			and is_equal_approx(STV.lan_lech_y(3), 90.0),
			"%s/%s/%s" % [STV.lan_lech_y(1), STV.lan_lech_y(2), STV.lan_lech_y(3)])
	# Ba lan phai gon trong MOT o (90 < 100) — do cung la ly do chi so lan chi
	# nhan 1..3, va la thu khien doi hinh khong tran sang o ben canh.
	t("ba lan gon trong mot o", STV.lan_lech_y(int(lan.get("lan_so", 3))) < o_px,
			"%s < %s" % [STV.lan_lech_y(int(lan.get("lan_so", 3))), o_px])

	# --- 5. So lan: do tu bang binh chung, khong phai ta chon -------------------
	var lan_so := int(lan.get("lan_so", 0))
	t("LAN_SO = so lan cua bang so", STV.LAN_SO == lan_so,
			"ta %d, ban goc %d" % [STV.LAN_SO, lan_so])
	t("bang so ghi ro nguon cua so lan",
			String(lan.get("location_nguon", "")).find("KDBGameArmyConfig") >= 0,
			String(lan.get("location_nguon", "")))
	_dem_location(lan, lan_so)

	# --- 6. Khoang cach hai quan cung toan --------------------------------------
	var army: Dictionary = d.get("army", {})
	t("ARMY_SPACE = fArmySpace", is_equal_approx(STV.ARMY_SPACE,
			float(army.get("fArmySpace", 0))),
			"ta %s, ban goc %s" % [STV.ARMY_SPACE, army.get("fArmySpace")])
	t("fArmySpace = 1.1 o = 110 px", is_equal_approx(STV.ARMY_SPACE, 1.1)
			and is_equal_approx(STV.ARMY_SPACE * o_px, 110.0),
			str(STV.ARMY_SPACE))
	# Dau truong dung ban KHAC (`fArmySpaceInArena`) — do la ly do engine co hai
	# ham doc rieng (`0x38193c` / `0x388240`). Man tran thuong khong duoc lay nham
	# con so cua dau truong.
	t("fArmySpaceInArena co that va KHAC fArmySpace",
			float(army.get("fArmySpaceInArena", 0)) > 0.0
			and not is_equal_approx(float(army.get("fArmySpaceInArena", 0)),
					float(army.get("fArmySpace", 0))),
			"%s vs %s" % [army.get("fArmySpaceInArena"), army.get("fArmySpace")])

	# --- 7. Nam hang so camera --------------------------------------------------
	# Truoc day chung cung la ĐẶT (chi ghi ten truong cua ban goc canh moi hang).
	var cam: Dictionary = d.get("camera", {})
	for cap in [["CAM_NGUONG", STV.CAM_NGUONG, "fCameraThreshold"],
			["CAM_TOC", STV.CAM_TOC, "fTrackSpeedPPS"],
			["CAM_CHAM_RA", STV.CAM_CHAM_RA, "fTrackSlowOutDist"],
			["CAM_CHAM_VAO", STV.CAM_CHAM_VAO, "fTrackSlowInFullTime"],
			["CAM_DUOI", STV.CAM_DUOI, "fTrackChasingDist"]]:
		var mong := float(cam.get(String(cap[2]), 0))
		t("%s = %s" % [cap[0], cap[2]], is_equal_approx(float(cap[1]), mong),
				"ta %s, ban goc %s" % [cap[1], mong])

	print("  co o %s px | lan rong %s o, lech %s o | %d lan | "
			% [o_px, rong_o, lech_o, lan_so]
			+ "quan cung lan cach %s o | camera %s/%s/%s/%s/%s"
			% [STV.ARMY_SPACE, STV.CAM_NGUONG, STV.CAM_TOC, STV.CAM_CHAM_RA,
			   STV.CAM_CHAM_VAO, STV.CAM_DUOI])
	_ket()


## `Location` cua bang binh chung: dem lai lan nua roi doi chieu voi so cua
## `tran_ref.py`. Hai duong doc khac nhau (Python `json` -> `tran_ref.py`, va
## Godot `JSON.parse_string` -> day) nen soi ra duoc mot lan hong o giua.
func _dem_location(lan: Dictionary, lan_so: int) -> void:
	var mong: Dictionary = lan.get("location_dem", {})
	t("bang so co bang dem Location", not mong.is_empty(), JSON.stringify(mong))
	var txt := FileAccess.get_file_as_string(BANG_LINH)
	if txt.is_empty():
		print("  (khong co %s — bo qua phan doi chieu bang binh chung)" % BANG_LINH)
		return
	var ds = JSON.parse_string(txt)
	if not (ds is Array) or ds.is_empty():
		t("doc duoc bang binh chung cua ban goc", false, str(ds))
		return
	var dem := {}
	for m in ds:
		var k := str(int((m as Dictionary).get("Location", 0)))
		dem[k] = int(dem.get(k, 0)) + 1
	t("bang binh chung dem ra cung so Location", dem.size() == mong.size(),
			"%s vs %s" % [JSON.stringify(dem), JSON.stringify(mong)])
	var lech := 0
	for k in mong:
		if int(dem.get(k, -1)) != int(mong[k]):
			lech += 1
	t("moi muc Location dem dung", lech == 0, "%d lech" % lech)
	# `Location` lon nhat trong bang binh chung chinh la so lan — neu bang so noi
	# 3 ma du lieu co 4 thi `LAN_SO` thieu mot lan, va quan thu 4 se bi don vao
	# hang cua lan khac.
	var lon_nhat := 0
	for k in dem:
		lon_nhat = maxi(lon_nhat, int(k))
	t("Location lon nhat = LAN_SO", lon_nhat == lan_so,
			"du lieu %d, LAN_SO %d" % [lon_nhat, lan_so])
	t("co muc Location = 0 (tuong nguoi choi)", dem.has("0"),
			JSON.stringify(dem))
	print("  Location cua %d binh chung: %s" % [ds.size(), JSON.stringify(dem)])


func _ket() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
