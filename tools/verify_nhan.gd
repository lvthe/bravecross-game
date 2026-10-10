# So sat thuong NOI — sau loai nhan cua ban goc.
#
#   godot --headless --path . --script tools/verify_nhan.gd
#
# VI SAO BO NAY PHAI CO: ban dung truoc day KHONG co duong nay, va mot nhan khong
# ve duoc thi **khong nem mot dong loi nao** — `load()` tra null, `Label` khong
# co phong van ton tai, van `queue_free()` binh thuong. Nen "chay khong loi" khong
# noi len gi; phep kiem phai do BANG SO (bao nhieu nhan ve duoc, vi sao khong).
#
# Sau tang, nam duong doc lap:
#   A. Bang so lieu: `data_ref/nhan_ref.json` + `NhanRef` — 12 con so cua khoi
#      `<label>` (`map/global_config.xml`), doi chieu voi HANG SO viet thang o
#      day (boc tu chinh cau hinh, khong doc lai json roi tu khen).
#   B. Bang ghep LOAI -> PHONG la **DAT** — khoa no lai: du sau loai, phai tra
#      ve dung MOT trong bay phong HO SO (khong bao gio tro vao phong chu), va
#      phai thua dung MOT phong (`ImpactBlue`). Do la cho ghi ro cai chua biet,
#      khong phai cho de doan bu cho du.
#   C. Phong tren dia: `.fnt` nap duoc thanh `Font`, trang PNG ma chinh `.fnt`
#      khai phai CO that (ten trang khong duoc doan theo ten phong — do la bay
#      cua `fontart.py`), va bo glyph phai co du chu so.
#   D. Bo sinh nhan: sau loai deu ra chu, `Increase` duoc `+` vi phong cua no CO
#      glyph ay, so <= 0 bi tu choi va DEM, nhan bay len roi tu giai phong.
#   E. TRAN cua ban goc: `Foe` 30, `Troop` 50 — vuot tran thi BO CAI CU NHAT cua
#      CUNG LOAI, va tran cua loai nay khong dung toi loai khac.
#   F. Phan loai: `Bonus` / `Shield` KHONG BAO GIO ra (khong co luat nao sinh ra
#      chung) — khang dinh thang, de neu sau nay co ai noi "da lam du sau loai"
#      thi phep kiem nay bat duoc. Phong cua hai loai ay VAN phai co san.
#   G. Duong tran that: `san_tran_ve._phat_trung_don` — nut that, don vi that,
#      dem that. Va nhan phai nam TRONG tam truc x cua nguoi chiu, TREN dau.
extends SceneTree

const NST := preload("res://battle/nhan_sat_thuong.gd")
const STV := preload("res://battle/san_tran_ve.gd")
const TGD := preload("res://battle/tran_goc.gd")

## Mot quan dich, dung hinh dang ban goc gui xuong (`doc_quan` doc `Data` +
## `Groups`; xem `tools/verify_dat_linh.gd`). De o `PosX` 9 o cho xa quan ta —
## phep kiem nay khong de chung tu danh nhau, no goi thang duong trung don.
const DICH := {
	"Data": {"E1": {"Name": "Defender", "SpriteName": "Defender", "NpcSize": 0.83,
			"Location": 1, "HP": 1000, "DP": 10, "MinAp": 10, "MaxAp": 20,
			"AttackInterval": 1.5, "MaxAttackDistance": 30}},
	"Groups": [{"PosX": 9.0, "AppearTime": 0,
			"Soldiers": [{"Data": "E1", "Num": 1, "NpcID": 5}]}],
}

## 12 con so cua khoi `<label>` — BOC TU `map/global_config.xml` (ban vn 1.26),
## khong doc lai json. Day la ve thu hai cua phep do: neu `nhan_ref.py` doc lech
## mot khoa nao thi con so o day khong khop.
const HE_SO := {"Foe": 0.825, "Troop": 1.0, "Critical": 1.0,
		"Increase": 0.71, "Bonus": 0.7, "Shield": 0.7}
const TRAN := {"Foe": 30, "Critical": 40, "Troop": 50,
		"Increase": 100, "Bonus": 30, "Shield": 50}
## Thu tu HAI ho khoa trong tep goc. Chung KHAC NHAU (Troop/Critical doi cho) —
## do la bang chung engine doc rieng tung khoa chu khong duyet mot mang ten dung
## chung. Ghi lai o day de khong ai "chuan hoa" thu tu roi lam mat phep do.
const TT_HE_SO := ["Foe", "Troop", "Critical", "Increase", "Bonus", "Shield"]
const TT_TRAN := ["Foe", "Critical", "Troop", "Increase", "Bonus", "Shield"]

## Ho SO = chi chu so + vai ky hieu; ho CHU = ca bang ma ASCII / chu CJK.
## Do 2026-09-21 tren 11 tep `.fnt` cua `assets/fonts`.
const SO_PHONG := 11
const SO_HO_SO := 7
const PHONG_THUA := "ImpactBlue"

const FNT := "res://assets_ref/fonts/%s.fnt"
const PNG := "res://assets_ref/fonts/%s"

var ok := 0
var bad := 0


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


## Doc mot tep `.fnt` — BMFont dang VAN BAN: `page id=N file="..."` va `char id=N`.
func _doc_fnt(duong: String) -> Dictionary:
	var s := FileAccess.get_file_as_string(duong)
	var trang: Array = []
	var glyph: Array = []
	for d in s.split("\n"):
		var l := d.strip_edges()
		if l.begins_with("page ") and l.find("file=\"") >= 0:
			var a := l.find("file=\"") + 6
			trang.append(l.substr(a, l.find("\"", a) - a))
		elif l.begins_with("char id="):
			glyph.append(int(l.substr(8, l.find(" ", 8) - 8)))
	return {"trang": trang, "glyph": glyph, "dai": s.length()}


## Bo glyph phai co du 0..9: mot nhan sat thuong chi gom chu so, thieu mot chu so
## thi Godot ve O TRONG chu khong bao loi. So sanh theo MA ASCII (BMFont ghi
## `char id=<so thap phan>`), khong theo chu.
func _co_du_chu_so(glyph: Array) -> bool:
	for c in range(10):
		if not glyph.has(48 + c):
			return false
	return true


## Du lieu tran toi thieu, cung hinh dang `tools/verify_dat_linh.gd` dung.
static func _ta() -> Dictionary:
	return {
		"Sprite": {
			"Troop": {"PosY": 0, "PosX": 3.83, "Soldiers": []},
			"Troop_1": {
				"Name": "Defender", "SpriteName": "Defender", "ArmyTypeID": 1001,
				"Location": 1, "NpcSize": 0.83, "MaxUnit": 2,
				"HP": 1000, "DP": 10, "MinAp": 10, "MaxAp": 20,
				"AttackInterval": 1.5, "MaxAttackDistance": 30,
				"BaseInfo": {"MaxUnit": 2},
			},
		},
		"Chapter": {"ChapterGameTime": 300},
	}


func _init() -> void:
	# Thieu bang du lieu thi bao BO QUA chu khong bao HONG: `nhan_ref.json`
	# nam trong `.gitignore` (sinh tu cay goc), nen may chua chay `nhan_ref.py`
	# se ra hang chuc dong do vo nghia — dung thu lam nguoi ta hoc cach bo qua
	# bo kiem.
	if FileAccess.get_file_as_string(NhanRef.DUONG).is_empty():
		print("BO QUA: khong co %s" % NhanRef.DUONG)
		print("  sinh bang: python ../brave-cross/work/nhan_ref.py")
		quit(0)
		return

	print("A. Bang so lieu (data_ref/nhan_ref.json + NhanRef):")
	t("NhanRef.LOAI dung sau loai", NhanRef.LOAI.size() == 6, str(NhanRef.LOAI.size()))
	for k in HE_SO:
		t("%s: he so %s" % [k, HE_SO[k]], is_equal_approx(NhanRef.he_so(k), HE_SO[k]),
				str(NhanRef.he_so(k)))
	for k in TRAN:
		t("%s: tran %d" % [k, TRAN[k]], NhanRef.tran(k) == TRAN[k], str(NhanRef.tran(k)))
	t("khong loai nao thieu du lieu", NhanRef.thieu().is_empty(), str(NhanRef.thieu()))

	# Hai thu tu PHAI khac nhau — neu bang nhau thi hoac json bi sua, hoac phep
	# doc thu tu bi roi ve mot mang dung chung.
	var hs: Array = NhanRef._d.get("nguon", {}).get("thu_tu_he_so", [])
	var tt_tr: Array = NhanRef._d.get("nguon", {}).get("thu_tu_tran", [])
	t("thu tu <fRiseLabel_*> dung nhu tep goc", hs == TT_HE_SO, str(hs))
	t("thu tu <nRiseLabelCountLimit_*> dung nhu tep goc", tt_tr == TT_TRAN, str(tt_tr))
	t("hai thu tu KHAC nhau (Troop/Critical doi cho) — engine doc rieng tung khoa",
			hs != tt_tr, "giong nhau thi mat bang chung nay")

	print("\nB. Bang ghep loai -> phong (DAT):")
	var ho_so := []
	for ten in NhanRef.ds_phong():
		if String(NhanRef.phong(ten).get("ho", "")) == NhanRef.HO_SO:
			ho_so.append(ten)
	t("ban goc ship %d phong" % SO_PHONG, NhanRef.ds_phong().size() == SO_PHONG,
			str(NhanRef.ds_phong().size()))
	t("trong do %d phong HO SO" % SO_HO_SO, ho_so.size() == SO_HO_SO, str(ho_so.size()))
	var dung := []
	for k in NhanRef.LOAI:
		var p := NhanRef.phong_cua(k)
		if p == "":
			t("%s co phong" % k, false, "chua gan")
			continue
		dung.append(p)
		if not ho_so.has(p):
			t("%s -> %s la phong HO SO" % [k, p], false,
					"ho = %s" % NhanRef.phong(p).get("ho", "?"))
	t("ca sau loai deu tro vao phong HO SO", dung.size() == 6, str(dung))
	# Hai loai co TEN KHOA TRUNG TEN PHONG — can cu manh nhat cua bang DAT.
	t("Critical -> CriticalFont (trung ten)", NhanRef.phong_cua("Critical") == "CriticalFont")
	t("Shield -> ShieldWhite (trung ten)", NhanRef.phong_cua("Shield") == "ShieldWhite")
	# Phong thua: sau loai, bay phong so — phai THUA dung mot, va goi ten no ra.
	var thua := []
	for p in ho_so:
		if not dung.has(p):
			thua.append(p)
	t("thua dung MOT phong so, va no la %s" % PHONG_THUA,
			thua.size() == 1 and thua[0] == PHONG_THUA, str(thua))

	print("\nC. Phong tren dia (assets_ref/fonts):")
	for k in NhanRef.LOAI:
		var ten := NhanRef.phong_cua(k)
		var duong := NhanRef.duong_fnt(ten)
		if duong == "":
			t("%s: duong .fnt" % ten, false, "rong")
			continue
		if not FileAccess.file_exists(duong):
			t("%s.fnt co tren dia" % ten, false, duong)
			continue
		var f = load(duong)
		t("%s.fnt nap duoc thanh Font" % ten, f is Font, str(f))
		var d := _doc_fnt(duong)
		t("%s.fnt khai it nhat mot trang" % ten, (d["trang"] as Array).size() >= 1,
				str(d["trang"]))
		t("%s.fnt co du chu so 0..9" % ten, _co_du_chu_so(d["glyph"]),
				"thieu chu so thi ve o trong")
		for t_trang in d["trang"]:
			# TEN TRANG KHONG DUOC DOAN THEO TEN PHONG: bon phong `Impact*` tro
			# toi `<ten>_0.png`, con `ReduceBloodFont` tro toi `<ten>.png`.
			t("%s: trang %s co tren dia" % [ten, t_trang], FileAccess.file_exists(PNG % t_trang),
					PNG % t_trang)

	# --- D. Bo sinh nhan ------------------------------------------------------
	print("\nD. Bo sinh nhan (battle/nhan_sat_thuong.gd):")
	var n := NST.new()
	root.add_child(n)
	var y := 400.0
	# KHONG dat RNG o day: `_rng` null nghia la khong lech ngang, tuc toa do do
	# duoc la toa do that — phep kiem can so xac dinh.
	for k in NhanRef.LOAI:
		var ve: bool = n.hien(k, 123.0, 100.0, y)
		t("%s: ve duoc mot nhan" % k, ve and n.dang_bay_loai(k) == 1,
				"ve=%s, dang bay %d" % [ve, n.dang_bay_loai(k)])
	var con: Array = n.get_children()
	t("sau loai ra sau nhan", con.size() == 6, str(con.size()))
	var lb := con[0] as Label
	t("nhan la Label va co chu so cua so sat thuong", lb != null and lb.text == "123",
			lb.text if lb != null else "khong phai Label")
	t("nhan mang dung phong cua loai (Foe -> ImpactRed)",
			lb != null and lb.label_settings != null and lb.label_settings.font != null,
			"thieu phong thi chu khong hien")
	var lb_increase: Label = null
	for c in con:
		if c is Label and String(c.text).begins_with("+"):
			lb_increase = c
	t("Increase duoc dau + (phong cua no CO glyph ay)", lb_increase != null,
			"khong nhan nao co dau +")
	# So <= 0 bi tu choi va PHAI duoc dem — khong lang le bo qua.
	t("so 0 bi tu choi", not n.hien("Foe", 0.0, 0.0, 0.0))
	t("so am bi tu choi", not n.hien("Foe", -5.0, 0.0, 0.0))
	t("ly do tu choi duoc DEM (khong im lang)", n.dem().find("\"so-0\":2") > 0, n.dem())

	# Bay len roi tu giai phong.
	# Nhan la `Label` — mot `Control`, KHONG phai `Node2D`. Ep kieu `as Node2D`
	# tra null va ca phep kiem chet giua duong; te hon nua, loi luc chay trong
	# `SceneTree._init` lam `quit()` khong bao gio duoc goi nen tien trinh TREO
	# chu khong thoat (da bi mot lan). Ep kieu dung ho: `CanvasItem`.
	var lb0 := con[0] as CanvasItem
	var y0: float = lb0.position.y
	n.buoc(NST.BAY_GIAY * 0.5)
	var y1: float = lb0.position.y
	t("nhan BAY LEN (y giam dan theo thoi gian)", y1 < y0, "%.1f -> %.1f" % [y0, y1])
	n.buoc(NST.BAY_GIAY * 0.6)
	t("qua thoi gian bay thi khong con nhan nao", n.dang_bay() == 0, str(n.dang_bay()))
	await process_frame
	t("node nhan da duoc giai phong", not is_instance_valid(con[0]))
	n.xoa_het()

	# --- E. TRAN cua ban goc --------------------------------------------------
	print("\nE. TRAN nhan cua ban goc:")
	var vuot := 5
	for i in range(NhanRef.tran("Foe") + vuot):
		n.hien("Foe", 10.0, 0.0, 0.0)
	t("Foe: ve %d lan, con dung %d nhan" % [NhanRef.tran("Foe") + vuot, NhanRef.tran("Foe")],
			n.dang_bay_loai("Foe") == NhanRef.tran("Foe"), str(n.dang_bay_loai("Foe")))
	t("so nhan bi tran day ra duoc DEM", n.dem().find("\"bo\":%d" % vuot) > 0, n.dem())
	# Tran cua mot loai khong dung toi loai khac: `Troop` (50) van con cho rieng.
	for i in range(NhanRef.tran("Troop")):
		n.hien("Troop", 10.0, 0.0, 0.0)
	t("tran cua Foe khong dung toi Troop",
			n.dang_bay_loai("Troop") == NhanRef.tran("Troop")
			and n.dang_bay_loai("Foe") == NhanRef.tran("Foe"),
			"Foe %d / Troop %d" % [n.dang_bay_loai("Foe"), n.dang_bay_loai("Troop")])
	t("tong so nhan dang bay = 30 + 50", n.dang_bay() == 80, str(n.dang_bay()))
	n.xoa_het()

	# --- F. Phan loai --------------------------------------------------------
	print("\nF. Phan loai loai nhan:")
	var ra := {}
	for team_chiu in [0, 1]:
		for crit in [false, true]:
			ra[NST.loai_theo_duoi(team_chiu, crit)] = true
	t("trung don thang moi thu khac", NST.loai_theo_duoi(0, true) == "Critical"
			and NST.loai_theo_duoi(1, true) == "Critical")
	t("don vao DICH -> Foe", NST.loai_theo_duoi(1, false) == "Foe")
	t("don vao TA -> Troop", NST.loai_theo_duoi(0, false) == "Troop")
	# Khang dinh thang: hai loai nay KHONG co luat nao sinh ra chung. Neu sau nay
	# co ai noi "da du sau loai" thi dong nay bat duoc.
	t("Bonus KHONG BAO GIO ra tu phan loai", not ra.has("Bonus"))
	t("Shield KHONG BAO GIO ra tu phan loai", not ra.has("Shield"),
			"combat.gd khong co chi so chan nao")
	t("nhung phong cua chung VAN co san (ngay co luat thi chi viec goi hien)",
			FileAccess.file_exists(NhanRef.duong_fnt(NhanRef.phong_cua("Bonus")))
			and FileAccess.file_exists(NhanRef.duong_fnt(NhanRef.phong_cua("Shield"))))

	# --- G. Duong tran that ---------------------------------------------------
	print("\nG. Duong tran that (san_tran_ve._phat_trung_don):")
	var tr1 := STV.new()
	var loi: String = tr1.bat_dau(JSON.stringify(_ta()), JSON.stringify(DICH), 7, null)
	t("tran dung duoc tu du lieu toi thieu", loi == "", loi)
	t("nut tran co bo sinh nhan", tr1._nhan != null)
	t("bo sinh nhan nam TRONG nut tran (cung he toa do voi quan)",
			tr1._nhan != null and tr1._nhan.get_parent() == tr1)
	# RNG cua bo sinh nhan phai la day RIENG: dung chung `_rng` cua tran thi moi
	# lan lech ngang day day so di mot buoc va DOI KET QUA TRAN.
	t("bo sinh nhan dung day so RIENG, khong dung _rng cua tran",
			tr1._nhan._rng != tr1._rng, "dung chung thi doi ket qua danh nhau")
	var so_linh: int = tr1.dua_linh("Troop_1")
	t("co quan ta de danh", so_linh > 0, str(so_linh))
	t("co quan dich", tr1._doi[1].size() == 1, str(tr1._doi[1].size()))
	var u_ta: BattleUnit = tr1._doi[0][0]
	var u_dich: BattleUnit = tr1._doi[1][0]
	tr1._phat_trung_don(u_ta, u_dich, 1, {"sat": 250.0, "crit": false, "hoi": 0.0})
	t("don vao DICH ra nhan Foe", tr1.dem_nhan().find("\"Foe\":1") > 0, tr1.dem_nhan())
	# Nhan phai nam TRONG tam truc x cua nguoi chiu (chi lech toi da LECH_X do
	# lech ngau nhien), va TREN dau (y nho hon).
	var lb2 := tr1._nhan.get_child(tr1._nhan.get_child_count() - 1) as Label
	t("nhan nam tren dau nguoi chiu",
			lb2 != null and lb2.position.y < u_dich.sy
			and is_equal_approx(lb2.position.y, u_dich.sy - NST.CAO_DAU),
			"y %.1f so voi chan %.1f" % [lb2.position.y if lb2 != null else 0.0, u_dich.sy])
	t("nhan nam trong tam truc x cua nguoi chiu (lech <= %d px)" % int(NST.LECH_X),
			lb2 != null and absf(lb2.position.x - u_dich.sx) <= NST.LECH_X + 0.01,
			"x %.1f so voi %.1f" % [lb2.position.x if lb2 != null else 0.0, u_dich.sx])
	t("chu cua nhan dung bang so sat thuong", lb2 != null and lb2.text == "250",
			lb2.text if lb2 != null else "?")
	# Don vao TA ra Troop, va hut mau ra Increase o cho NGUOI DANH.
	tr1._phat_trung_don(u_dich, u_ta, 1, {"sat": 40.0, "crit": true, "hoi": 12.0})
	var dn := tr1.dem_nhan()
	t("trung don ra Critical", dn.find("\"Critical\":1") > 0, dn)
	t("hut mau ra Increase", dn.find("\"Increase\":1") > 0, dn)
	t("tong so nhan ve duoc = 3 (Foe, Critical, Increase)", dn.find("\"ve\":3") > 0, dn)
	t("khong nhan nao bi tu choi o duong that", dn.find("\"im_vi_sao\":{}") > 0, dn)
	tr1.free()

	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
