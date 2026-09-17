# Mốc đứng của toán quân ta, và chỗ đặt toán lính khi bấm nút binh chủng.
#
#   godot --headless --path . --script tools/verify_dat_linh.gd
#
# Bộ này canh HAI số KHÁC NHAU, và điều quan trọng là đừng trộn chúng:
#
#   1. MỐC CỦA TOÁN — SỐ ĐO. `Sprite.Troop.PosX` là chỗ `CUIGame:FitBattleArmyPos`
#      (`sc/user/Battle/CUIGame.lua:702`) đặt toán quân ta: 3,83 ô (can giữa 6,83,
#      đối phương 9,83) hoặc 7,1 / 7 tùy loại trận; `FightLogic:GetSelfFightDataBody`
#      (`sc/share/FightLogic.lua:187`) mặc định 7 ô. Đo trong trận thật `L_N_01_01`
#      bằng `do_chien_dich --kiem`: PosX = 7 ô = 700 px. `tran_goc.moc_toan` là chỗ
#      ĐỊNH NGHĨA duy nhất, `tran_goc.doc_quan` đặt lính CÓ SẴN ở đó.
#
#   2. CHỖ ĐẶT TOÁN LÍNH ĐƯA RA — ĐẶT, chưa đo được. `dua_linh` đặt ở ô 0 (mép
#      trái sàn) và KHÔNG dùng mốc của toán. Đã THỬ dùng mốc (2026-09-17) và phải
#      bỏ: `do_chien_dich --kichban` tụt từ 9 đạt / 0 hỏng xuống 6 đạt / 3 hỏng,
#      vì toán đứng trong sàn thì gặp địch sớm hơn ~1,4 giây, trận KẾT THÚC trước
#      bước kế tiếp của kịch bản, mà đồng hồ của kịch bản chính là đồng hồ trận
#      (`lua/san_tran.lua:78`, `dung_tran` gọi `T.hen:stop()`) — kịch bản đứng hẳn
#      ở lệnh 27/43. Xem `dua_linh` để có đủ chuỗi bằng chứng.
#
# Vì thế bộ này kiểm: mốc đọc đúng từ dữ liệu và `doc_quan` dùng nó; `dua_linh`
# đặt ở ô 0 như đã ghi; và BẰNG CHỨNG còn nguyên trong Lua gốc (mất hai dòng ấy
# thì mốc lại thành suy luận, phải biết ngay — cùng lối với chú thích
# `<!-- 道宽 格 -->` ở `tools/verify_lan.gd`).
extends SceneTree

const STV := preload("res://battle/san_tran_ve.gd")
const TG := preload("res://battle/tran_goc.gd")
const LUA_GOC := "res://sc/user/Battle/CUIGame.lua"
const LUA_FIGHT := "res://sc/share/FightLogic.lua"
const DICH := {"Groups": []}

## Mốc thật của toán quân ta trong một trận thường: 3,83 ô (can giữa 6,83).
const MOC := 3.83
const O := 100.0

## Dữ liệu trận tối thiểu, đúng hình dạng bản gốc gửi xuống: `Sprite.Troop` là
## toán của ta (PosX + Soldiers), `Sprite.Troop_<ArmyID>` là một binh chủng mà
## nút binh chủng đưa ra (`CUIGame:setArmyIcons` đặt `stringTag = "Troop_<n>"`).
static func _ta(co_toan: bool) -> Dictionary:
	var troop := {"PosY": 0, "Soldiers": []}
	if co_toan:
		troop["PosX"] = MOC
	return {
		"Sprite": {
			"Troop": troop,
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

var ok := 0
var bad := 0


func t(ten: String, dat: bool, ghi: String = "") -> void:
	if dat:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [ten, ("  (%s)" % ghi) if ghi else ""])


func _init() -> void:
	# --- 1. Moc cua toan: mot cho dinh nghia, du lieu cu van chay -------------
	var sp: Dictionary = _ta(true)["Sprite"]
	t("moc_toan lay dung Sprite.Troop.PosX", is_equal_approx(TG.moc_toan(sp), MOC),
			str(TG.moc_toan(sp)))
	t("moc khong phai o 0", not is_equal_approx(TG.moc_toan(sp), 0.0), str(MOC))
	# Du lieu cu (khong co PosX) van chay: moc 0, khong no ra.
	t("thieu PosX thi moc = 0, khong no", is_equal_approx(TG.moc_toan({}), 0.0)
			and is_equal_approx(TG.moc_toan({"Troop": {}}), 0.0), str(TG.moc_toan({})))
	# `doc_quan` dat linh CO SAN o moc cua toan — duong thu nhat dung moc nay.
	var q: Dictionary = TG.doc_quan(_ta(true), DICH, {})
	t("Sprite.Troop.Soldiers rong thi chua co ai", (q["ta"] as Array).is_empty(),
			str((q["ta"] as Array).size()))
	# Duong thuc su dat linh: mot nguoi trong `Soldiers` phai ra dung moc.
	var ta1 := _ta(true)
	ta1["Sprite"]["Troop"]["Soldiers"] = [{"Data": "Troop_1", "Num": 1}]
	var q1: Dictionary = TG.doc_quan(ta1, DICH, {})
	var ds: Array = q1["ta"]
	t("doc_quan dat linh co san DUNG moc cua toan",
			ds.size() == 1 and is_equal_approx(float(ds[0]["pos_x"]), MOC),
			"%d nguoi, pos_x %s" % [ds.size(), (ds[0]["pos_x"] if ds.size() > 0 else "?")])

	# --- 2. Man tran: moc doc ra, va cho dat ĐẶT cua toan linh dua ra ---------
	var t1 := STV.new()
	var loi: String = t1.bat_dau(JSON.stringify(_ta(true)), JSON.stringify(DICH), 1, null)
	t("tran dung duoc tu du lieu toi thieu", loi == "", loi)
	# `_goc_x` = 0 vi nut khong nam trong cay canh, nen x doc ra chinh la px so voi o 0.
	t("o 0 cua san = 0 khi chua gan vao cay canh", is_equal_approx(t1._goc_x, 0.0),
			str(t1._goc_x))
	t("man tran doc moc toan ra px", is_equal_approx(t1._moc_toan * O, MOC * O),
			"%s px" % (t1._moc_toan * O))
	var n0: int = t1._doi[0].size()
	var so: int = t1.dua_linh("Troop_1")
	t("dua_linh tra so nguoi cua toan (MaxUnit)", so == 2, str(so))
	t("so quan tang dung bang so dua ra", t1._doi[0].size() == n0 + 2,
			"%d -> %d" % [n0, t1._doi[0].size()])
	var x0 := float(t1._doi[0][n0].sx)
	var x1 := float(t1._doi[0][n0 + 1].sx)
	# ĐẶT, ghi ro: o 0 (mep trai san), KHONG phai moc cua toan — xem dua_linh.
	t("toan linh dua ra dat o o 0 (ĐẶT, khong dung moc cua toan)",
			is_equal_approx(x0, 0.0) and not is_equal_approx(x0, MOC * O),
			"x %.1f px, moc %.1f" % [x0, MOC * O])
	t("nguoi thu hai lui dung fArmySpace (110 px)",
			is_equal_approx(x0 - x1, STV.ARMY_SPACE * O), "x %.1f -> %.1f" % [x0, x1])
	# Toan thu hai khong duoc dung de len toan thu nhat: chi so cot phai chay tiep.
	var so2: int = t1.dua_linh("Troop_1")
	var x2 := float(t1._doi[0][n0 + 2].sx)
	t("toan thu hai khong de len toan thu nhat", so2 == 2
			and not is_equal_approx(x2, x0) and not is_equal_approx(x2, x1),
			"x %.1f (toan 1: %.1f, %.1f)" % [x2, x0, x1])
	# Do cua cong cu phai noi dung CA HAI so (do_chien_dich --kiem doc chuoi nay):
	# moc cua toan (so do) va goc san — de phep kiem phan biet duoc hai duong.
	var do_chuoi: String = t1.do_cho_dat()
	t("do_cho_dat bao moc cua toan, goc san va so nguoi vua ra",
			do_chuoi.find("383 px") >= 0 and do_chuoi.find("goc 0") >= 0
			and do_chuoi.find("2 nguoi vua ra") >= 0, do_chuoi)
	t1.free()

	# Du lieu KHONG co PosX (truong cu): moc 0, khong no, van ra quan.
	var t2 := STV.new()
	var loi2: String = t2.bat_dau(JSON.stringify(_ta(false)), JSON.stringify(DICH), 1, null)
	var so3: int = t2.dua_linh("Troop_1")
	t("du lieu khong co PosX: moc 0 va van ra duoc quan",
			loi2 == "" and so3 == 2 and is_equal_approx(t2._moc_toan, 0.0), loi2)
	t2.free()

	# --- 3. Bang chung con nguyen trong Lua goc ------------------------------
	# Moc nay khong phai suy luan: chinh Lua goc dat toan o PosX. Mat dong do thi
	# day la cho phai sua, khong phai cho lang le thanh ĐẶT lai.
	var lc := FileAccess.get_file_as_string(LUA_GOC)
	t("Lua goc van dat toan o Sprite.Troop.PosX",
			lc.find("Sprite.Troop.PosX") >= 0 and lc.find("PosX = 3.83") >= 0, LUA_GOC)
	var lf := FileAccess.get_file_as_string(LUA_FIGHT)
	t("du lieu cua chinh minh mac dinh PosX = 7 o",
			lf.find("PosX = nPositionY or 7") >= 0, LUA_FIGHT)

	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
