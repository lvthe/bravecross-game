# Kiem bo nap bo cuc XggLayout ma khong can mo cua so.
#
#   godot --headless --path . --script tools/verify_layout.gd
#
# Dung moi file trong layout_ref/ roi doi chieu voi chinh JSON: du node chua,
# doi he toa do co dung khong, cay co dung hinh dang khong.
extends SceneTree

const ROOT := "res://layout_ref/"
const HUD := "Game_UI_Control_Panel_960_640"

var n_pass := 0
var n_fail := 0


func _check(ok: bool, desc: String, detail: String = "") -> void:
	if ok:
		n_pass += 1
		print("  dat   ", desc)
	else:
		n_fail += 1
		print("  HONG  ", desc, "" if detail == "" else "  -> " + detail)


func _count(nd: Dictionary) -> int:
	var n := 1
	for c in nd.get("children", []):
		n += _count(c)
	return n


## Dem so LOP CUON trong mot nhanh cua ban ghi `.xgg`.
##
## `la_lop_cuon` chu khong phai mot danh sach viet lai: do la cung mot luat ma
## `_boc_lop_chua` dung de quyet dinh co boc hay khong, nen hai ben khong the
## lech nhau.
func _dem_lop_cuon(nd: Dictionary) -> int:
	var n := 1 if XggLayout.la_lop_cuon(String(nd.get("typeName", ""))) else 0
	for c in nd.get("children", []):
		n += _dem_lop_cuon(c)
	return n


## Dem lop NOI DUNG sinh luc chay (meta `lop_chua`) trong cay da dung.
func _dem_noi_dung(n: Node) -> int:
	var c := 1 if n.has_meta("lop_chua") else 0
	for k in n.get_children():
		c += _dem_noi_dung(k)
	return c


func _init() -> void:
	var dir := DirAccess.open(ROOT)
	if dir == null:
		print("khong mo duoc ", ROOT,
				" — sinh bang: python ../brave-cross/work/layout.py --all --out layout_ref")
		quit(1)
		return

	# --- 1. doi he toa do, tinh tay tren mot node da biet
	print("\n=== 1. doi he toa do Cocos -> Godot ===")
	var hud_path := ROOT + HUD + ".json"
	if not FileAccess.file_exists(hud_path):
		print("khong thay ", hud_path)
		quit(1)
		return
	var hud := XggLayout.build(hud_path)
	_check(hud != null, "dung duoc HUD man tran")
	if hud == null:
		quit(1)
		return

	# g_GameUILayer: 0,0 960x640, neo (0,0) -> Godot (0,0)
	var rootn := XggLayout.find_node(hud, "g_GameUILayer")
	_check(rootn != null, "tim thay g_GameUILayer")
	if rootn != null:
		_check(rootn.position.is_equal_approx(Vector2.ZERO),
				"lop goc o (0,0)", str(rootn.position))
		_check(rootn.size.is_equal_approx(Vector2(960, 640)),
				"lop goc 960x640", str(rootn.size))

	# spBattleStartTime: Cocos 480,320 150x50, neo (0.5,0.5) trong cha 960x640
	#   trai = 480 - 0.5*150 = 405
	#   y    = 640 - (320 - 0.5*50) - 50 = 640 - 295 - 50 = 295
	var t := XggLayout.find_node(hud, "spBattleStartTime")
	_check(t != null, "tim thay spBattleStartTime")
	if t != null:
		var want := Vector2(405, 295)
		_check(t.position.is_equal_approx(want),
				"node neo giua doi dung toa do", "%s, mong doi %s" % [t.position, want])

	# lBattleSkill: CCLayer 270,75 520x140 neo (0.5,0.5) — lop BO QUA neo khi
	# dat cho (XggLayout.bo_qua_neo), nen goc duoi-trai o dung 270,75:
	#   y = 640 - 75 - 140 = 425
	# Neo van phai con trong meta: fixListViewPosition doc getAnchorPoint() de
	# tru di, va chi ra nut thuc tinh dung cho khi ca hai cung dung.
	var bs := XggLayout.find_node(hud, "lBattleSkill")
	_check(bs != null, "tim thay lBattleSkill")
	if bs != null:
		_check(bs.position.is_equal_approx(Vector2(270, 425)),
				"lop bo qua neo khi dat cho", "%s, mong doi (270, 425)" % bs.position)
		var c: Vector4 = bs.get_meta("cocos", Vector4.ZERO)
		_check(is_equal_approx(c.z, 0.5) and is_equal_approx(c.w, 0.5),
				"lop van giu neo that trong meta", str(c))

	# --- 2. du node tren moi man hinh
	print("\n=== 2. du node tren moi man hinh ===")
	var files := dir.get_files()
	var checked := 0
	var short := []
	var empty := []
	var thua_lop := 0
	for f in files:
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string(ROOT + f))
		if not doc is Dictionary or not doc.has("roots"):
			continue
		var want := 0
		var lop := 0
		for r in doc["roots"]:
			want += _count(r)
			lop += _dem_lop_cuon(r)
		var built := XggLayout.build(ROOT + f)
		if built == null:
			empty.append(f)
			continue
		var got := 0
		var chua := 0
		for c in built.get_children():
			got += _count_nodes(c)
			chua += _dem_noi_dung(c)
		# Ky vong la so node cua FILE cong so LOP CUON, khong phai so node cua
		# file: `.xgg` khong co lop noi dung — engine sinh no luc chay, va port
		# nay cung vay (`XggLayout._boc_lop_chua`, dung mot lop cho MOI lop cuon,
		# ke ca lop khong co mat nao trong file). Do tren ca 296 bo cuc: 148 bo
		# cuc co lop cuon / 315 lop, va 148/148 bo cuc lech dung bang so lop cuon
		# cua chinh no, 0 bo cuc lech kieu khac.
		if got != want + lop:
			short.append("%s(%d/%d+%d)" % [f.get_basename(), got, want, lop])
		if chua != lop:
			thua_lop += 1
		built.free()
		checked += 1
	_check(checked > 0, "co man hinh de kiem (%d file)" % checked)
	_check(empty.is_empty(), "man hinh nao cung dung duoc", ", ".join(empty))
	_check(short.is_empty(), "du node tren moi man hinh", ", ".join(short))
	# Phep dem tren chi doi tong cho khop; dong nay doi LOP NOI DUNG phai dung
	# cho: moi lop cuon mot lop, va khong node nao khac mang meta `lop_chua` —
	# `lua/cocos.lua` va `lua/cuon.lua` nhan ra no bang chinh meta ay.
	_check(thua_lop == 0,
			"moi lop cuon co dung mot lop noi dung", "%d man lech" % thua_lop)

	# --- 3. cay dung hinh dang: con nam trong cha
	print("\n=== 3. quan he cha-con ===")
	var deep := XggLayout.find_node(hud, "leftHeroInfoBox")
	_check(deep != null, "tim thay node long sau (leftHeroInfoBox)")
	if deep != null:
		_check(deep.get_child_count() > 0,
				"node long sau co con (%d)" % deep.get_child_count())

	# --- 4. bang ten, dung vai tro cua _G ben ban goc
	print("\n=== 4. bang ten node (thay cho _G) ===")
	var idx := XggLayout.index_of(hud)
	# It hon HAN so node la DUNG: chi node co TEN INSTANCE moi vao bang, dung
	# nhu ban goc — no viet `lAchieveTaskUI`, `sngItemIcon`... chu khong goi node
	# theo ten lop. Tren toan bo 296 man, 30.694/33.472 node khong he co ten
	# instance. Truoc day ta lay ten lop dap vao cho thieu, va cai ten gia do
	# de len ca ten that (mot node khong ten mang lop 'lSubDialogMask' da cuop
	# cho cua chinh lSubDialogMask).
	_check(idx.size() > 40, "co bang chi muc (%d ten tren 629 node)" % idx.size())
	_check(idx.has("g_btnAutoCombat"),
			"tra duoc nut tu dong chien dau bang dung ten cua ban goc")
	var by_index := XggLayout.find_node(hud, "spBattleStartTime")
	_check(by_index != null and by_index == idx.get("spBattleStartTime"),
			"find_node tra ve dung node trong chi muc")

	# --- 5. tra anh theo ten, y het spriteFrameByName
	print("\n=== 5. tra anh theo ten ===")
	var st := UiFrames.stats()
	_check(int(st.get("indexed", 0)) > 5000,
			"chi muc anh co %d muc" % st.get("indexed", 0))
	var tex := UiFrames.get_frame("item_55.png")
	_check(tex != null, "nap duoc mot anh cu the (item_55.png)")
	if tex != null:
		_check(tex.get_size() == Vector2(79, 79),
				"anh dung kich thuoc 79x79", str(tex.get_size()))
	_check(UiFrames.get_frame("v6/ui_background204.png") != null,
			"ten co thu muc dang truoc van tra duoc")
	_check(UiFrames.get_frame("@v6/ui_background204.png") != null,
			"ten co tien to @ van tra duoc")

	# set_frame phai GIU DIEM NEO: node 96x96 neo giua o (200,300) trong cha
	# cao 640 -> goc o (152, 640-300-48=292). Thay anh 79x79 thi tam van o
	# (200,300), goc o thanh (160.5, 640-300-39.5=300.5).
	var probe := TextureRect.new()
	probe.set_meta("cocos", Vector4(200, 300, 0.5, 0.5))
	probe.set_meta("parent_h", 640.0)
	probe.size = Vector2(96, 96)
	if UiFrames.set_frame(probe, "item_55.png"):
		_check(probe.position.is_equal_approx(Vector2(160.5, 300.5)),
				"doi anh thi giu diem neo", str(probe.position))
	else:
		_check(false, "set_frame chay duoc")
	probe.free()

	# Bao nhieu anh cua HUD tra duoc — con so nay noi len do phu that su.
	var doc = JSON.parse_string(FileAccess.get_file_as_string(hud_path))
	var want := 0
	var got := 0
	for s in doc.get("sprites", []):
		if String(s.get("name", "")) == "":
			continue
		want += 1
		if UiFrames.has_frame(String(s["name"])):
			got += 1
	_check(got >= want - 2, "HUD tra duoc %d/%d anh" % [got, want])

	# --- 6. anh da duoc gan vao node
	print("\n=== 6. gan anh vao node ===")
	var no_tex: Array = []
	var tally := _tally(hud, no_tex)
	_check(tally[0] > 100, "co %d node duoc gan anh" % tally[0])
	_check(tally[1] == 0,
			"anh CO trong kho thi phai gan duoc vao node",
			", ".join(no_tex.slice(0, 6)))
	var missing := UiFrames.missing()
	print("  (%d ten anh yeu cau ma khong co file)" % missing.size())
	if missing.size() > 0:
		print("  (%s)" % ", ".join(missing.slice(0, 6)))

	# --- 6b. NHAN co ANH NEN (CCLabelTTF mang CA `img` LAN `text`)
	#
	# 202 nhan trong 11 bo cuc lam the. HUD man tran khong co cai nao (do: 159
	# nhan, 0 tam nen), nen phai do tren man khac — lay man Main, noi do duoc
	# nhieu nhat va noi con nguoi nhin thay ngay: 14/38 nhan mang tam nen, TAT CA
	# deu la `buildingname_16.png` (144x34). Kho co 16 tam `buildingname_*`, nhung
	# 15 tam kia la 34x133 (bang DOC treo tren toa nha) — chi `_16` la 144x34, nen
	# phep khop kich thuoc cua `imgFrom: size` chon dung, khong mo ho.
	#
	# Truoc day cho nay HONG IM LANG: `ui_frames.gd:set_frame` tra ve `false` cho
	# moi node khong phai TienDo/UiONhap/NinePatchRect/TextureRect, tuc la `Label`
	# bi bo — node van co meta `img` nhung khong co `img_applied`, nen nhin cay
	# khong thay gi. Phai dem theo `img_applied` moi bat duoc. Day chinh la tam
	# VANG nhin thay trong man goc.
	#
	# VI SAO CHI DO TREN MAIN: khong phai man nao co tam nen cung gan duoc, va
	# phan con lai la LO HONG KHO ANH chu khong phai loi ma. Do duoc:
	# `UI_ActivityMode_Finish` co 8 nhan mang tam nen ma chi 2 gan duoc — 6 cai
	# kia dung `ui_words357.png`, ten CO trong bo cuc nhung KHONG co trong
	# `ui_ref/index.json` va khong co tep, vi ban goc ship ban THEO NGON NGU
	# (`sngSplitData/v6/ui_words357_vi.pkm`). Doi phep kiem sang man do thi no do
	# dung vi ly do sai. Man Main sach: 14/14.
	print("\n=== 6b. nhan co anh nen ===")
	# Do TREN MOI bo cuc trong MOT luot chay. Goi tung bo cuc mot tien trinh rieng
	# thi ~200 tien trinh Godot, khong chay noi — ma `verify_layout` da dung het
	# moi file roi.
	var d := {"co": 0, "gan": 0, "thieu": [], "khong_anh": 0, "lech": 0}
	var n_bo := 0
	for f in DirAccess.get_files_at(ROOT):
		if not f.ends_with(".json"):
			continue
		n_bo += 1
		var man := XggLayout.build(ROOT + f)
		if man == null:
			continue
		_dem_nhan(man, d)
	if int(d["co"]) > 0:
		# "Khong gan duoc" co HAI nguyen nhan khac han nhau, va chi cai thu hai
		# moi la loi cua ta: (a) kho KHONG co tep anh do — do la lo hong du lieu,
		# vd `ui_words357.png` chi co ban theo ngon ngu `ui_words357_vi.pkm`;
		# (b) co tep nhung no KEO VAO O thi hong vien (canh ngan lech). Dem rieng.
		#
		# Phep kiem CO LUC la cai thu ba: nhan CO tep VA canh ngan KHOP ma van
		# khong gan duoc thi do la loi that, khong duoc lan vao hai cai kia.
		_check(int(d["gan"]) + int(d["khong_anh"]) + (d["thieu"] as Array).size()
				== int(d["co"]),
				"nhan co anh nen: %d/%d gan duoc (%d ten khong co tep anh)"
				% [int(d["gan"]), int(d["co"]), int(d["khong_anh"])],
				", ".join((d["thieu"] as Array).slice(0, 6)))
		_check(int(d["lech"]) == 0,
				"canh ngan KHOP thi buoc phai gan duoc: %d nhan khong" % int(d["lech"]))
		if (d["thieu"] as Array).size() > 0:
			# Noi ro ra, dung de no trông nhu mot con so binh thuong: nhung nhan
			# nay CO tep, chi la keo vao o thi bop vien.
			print("  (%d nhan co tep nhung canh ngan lech nen KHONG keo: %s)"
					% [(d["thieu"] as Array).size(),
					", ".join((d["thieu"] as Array).slice(0, 8))])
	print("  (%d nhan co anh nen tren %d bo cuc)" % [int(d["co"]), n_bo])

	# Kiem duoc vi CUIManager.lua dat zOrder cho tung lop che bang hang so viet
	# ro trong ma, ma ten lop che thi biet san. Neu doc sai truong nay thi
	# khong loi gi ca, chi la lop nay de len lop kia sai cho.
	print("\n=== zOrder (thu tu ve) ===")
	var khung := XggLayout.build(ROOT + "UI_NormalDlg_960_640.json")
	_check(khung != null, "dung duoc khung hop thoai")
	if khung != null:
		var z := func(ten: String) -> int:
			var nd := XggLayout.find_node(khung, ten)
			return int(nd.get_meta("zorder", -1)) if nd != null else -1
		# So voi hang so trong sc/user/Public/CUIManager.lua.
		_check(z.call("lNormalDlgMask") == 20, "lNormalDlgMask = maskZorder 20")
		_check(z.call("lNormalDlgTouchMask") == 21, "lop cham = maskZorder + 1")
		_check(z.call("lSubDialogMask") == 100, "lSubDialogMask = 100")
		_check(z.call("lMessageBoxMask") == 2000, "lMessageBoxMask = 2000")
		_check(z.call("lSystemMask") == 4000, "lSystemMask = 4000")
		_check(z.call("lNetWorkMask") == 6000, "lNetWorkMask = 6000")
		_check(z.call("lDebugBoxMask") == 9000, "lDebugBoxMask = 9000")
		# Nen canh phai nam DUOI lop giao dien, khong thi anh nen phu kin.
		_check(z.call("lSceneBackgroundLayer") < z.call("UIRootLayer"),
				"nen canh nam duoi lop giao dien")
		# Va cay dung ra phai da xep theo do.
		var u := XggLayout.find_node(khung, "UIRootLayer")
		var tang := true
		var truoc := -999999
		for c in u.get_children():
			var zz := int(c.get_meta("zorder", 0))
			if zz < truoc:
				tang = false
			truoc = zz
		_check(tang, "con cua UIRootLayer da xep theo zOrder")

		# Ghep man hinh vao khung: day la cach ban goc bay \u2014 mot cay duy nhat,
		# zOrder sap xep. Man thanh tuu (33) phai nam giua lop che (20) va
		# thanh nut Back (60).
		var man := XggLayout.build(ROOT + "UI_AchievementTask_960_640.json")
		if man != null:
			var da := XggLayout.ghep_vao(khung, man)
			_check(da > 0, "ghep duoc man hinh vao khung")
			var ui := XggLayout.find_node(khung, "lAchieveTaskUI")
			_check(ui != null and ui.get_parent() == u,
					"man hinh thanh anh em cua lop che")
			if ui != null:
				var i_che := u.get_children().find(
						XggLayout.find_node(khung, "lNormalDlgMask"))
				var i_ui := u.get_children().find(ui)
				var i_back := u.get_children().find(
						XggLayout.find_node(khung, "lDialogControlPanel"))
				_check(i_che < i_ui and i_ui < i_back,
						"man hinh ve tren lop che va duoi nut Back")
			_check(absf(u.position.x) < 0.01 and absf(u.position.y) < 0.01,
					"lop giao dien duoc dua ve goc toa do")
			man.free()
		khung.free()


	# --- Ten TRAN bi trung: chon ban nao?
	#
	# 536 ten anh xuat hien o nhieu thu muc. Khi bo cuc ghi ca duong dan thi
	# khong co gi phai chon; khi ma goc goi
	# spriteFrameByName("item_4.png") — mot cai ten tran — thi phai chon.
	#
	# Cham diem bang CHINH BANG SPRITE cua tung man (.xgg section C): no ghi
	# ten KEM KICH THUOC, tuc la cau tra loi do ban goc ghi san. Sai lech 1
	# pixel duoc bo qua: anh .pkm dung ETC1 nen chieu cao duoc dem cho chia
	# het 4 (xem uiart.py).
	print("\n=== chon anh khi ten tran bi trung ===")
	var dung := 0
	var sai := 0
	var vi_du := []
	var d2 := DirAccess.open(ROOT)
	d2.list_dir_begin()
	var f2 := d2.get_next()
	while f2 != "":
		if f2.ends_with(".json"):
			var doc2 = JSON.parse_string(
					FileAccess.get_file_as_string(ROOT + f2))
			if doc2 is Dictionary:
				for r in doc2.get("sprites", []):
					var ten := String(r.get("name", ""))
					if ten == "" or ten.contains("/"):
						continue
					if not UiFrames.is_ambiguous(ten):
						continue
					var tx := UiFrames.get_frame(ten)
					if tx == null:
						continue
					var w := float(r.get("w", 0))
					var h := float(r.get("h", 0))
					if absf(tx.get_size().x - w) <= 1.0 \
							and absf(tx.get_size().y - h) <= 1.0:
						dung += 1
					else:
						sai += 1
						if vi_du.size() < 4:
							vi_du.append("%s: xgg %.0fx%.0f, ta %s"
									% [ten, w, h, tx.get_size()])
		f2 = d2.get_next()
	for e in vi_du:
		print("      lech: %s" % e)
	_check(dung + sai > 100, "co du mau de cham (%d)" % (dung + sai))
	# Luat cu (lay ban dau trong danh sach) chi dung 15/183. Luat moi —
	# uu tien sngSplitData/ roi lay ban nong nhat — dung 178/183.
	_check(dung >= (dung + sai) * 9 / 10,
			"chon dung ban anh: %d/%d" % [dung, dung + sai])

	hud.free()
	print("\n===== dat %d, hong %d =====" % [n_pass, n_fail])
	quit(0 if n_fail == 0 else 1)


## Dem node do CHINH bo cuc dung ra, khong dem con ve ma lop gia lap tu them.
##
## Dau hieu "do bo cuc dung ra" la meta `type_name`, ma `XggLayout._make` dat cho
## MOI node (`ui/xgg_layout.gd:329`, khong nhanh nao thoat truoc do). Truoc day
## phep dem dem MOI con va chi tru mot cai ten `_debug`, nen vua roi vao bay khi
## he hat ra doi: `HatNode` mang theo mot `GPUParticles2D` con de ve, va 87 node
## hat tren 23 man hinh lam phep dem lech dung 87 (do: hieu so tung man +
## 2+10+6+2+4+2+8+2+6+2+3+2+5+2+4+2+4+9+2+2+4+2+2 = 87). Node hat khong ve
## duoc thi khong co con nao, va do cung la mot ly do de dem theo meta chu khong
## theo so con.
func _count_nodes(n: Node) -> int:
	var c := 1 if n.has_meta("type_name") else 0
	for k in n.get_children():
		c += _count_nodes(k)
	return c

## Dem nhan (CCLabelTTF) mang ANH NEN, va bao nhieu cai gan duoc vao node.
## Xem khoi 6b: `set_frame` bo im lang moi `Label`, nen phai dem theo
## `img_applied` chu khong theo `img`.
func _dem_nhan(n: Node, d: Dictionary) -> void:
	if n.has_meta("type_name") and String(n.get_meta("type_name")) == "CCLabelTTF":
		if n.has_meta("img") and String(n.get_meta("img")) != "":
			var img := String(n.get_meta("img"))
			d["co"] = int(d["co"]) + 1
			if n.get_meta("img_applied", false):
				d["gan"] = int(d["gan"]) + 1
			elif not UiFrames.has_frame(img):
				d["khong_anh"] = int(d["khong_anh"]) + 1
			else:
				# Co tep ma khong gan duoc: keo vao o thi hong vien (canh ngan
				# lech), hoac ten tran trung nen giai ra ban khac co.
				#
				# Tach hai truong hop nay ra, vi mot cai la LUA CHON cua ta con
				# cai kia la LOI THAT. `ui_words357` la vi du that, do duoc sau
				# khi `key_of` biet hau to ngon ngu: ten giai ra
				# `sngSplitData/v6/ui_words357_vi.png` (176x64) con o cua nhan la
				# 152x68 — canh ngan 64 vs 68, keo doc 6% thi vien vang cua dai
				# bi bop. Truoc day 6 nhan nay duoc dem vao `khong_anh` ("thieu
				# du lieu"), tuc la mot LUA CHON bi ghi nham thanh mot LO HONG.
				var o := (n as Control).size
				var tex := UiFrames.get_frame(img)
				if tex != null and is_equal_approx(
						minf(tex.get_width(), tex.get_height()), minf(o.x, o.y)):
					d["lech"] = int(d["lech"]) + 1
				else:
					(d["thieu"] as Array).append("%s vao o %dx%d" % [img,
							int(o.x), int(o.y)])
	for c in n.get_children():
		_dem_nhan(c, d)


## [so node da gan anh, so node ghi 'verified' ma khong nap duoc anh]
func _tally(n: Node, no_tex: Array) -> Array:
	var applied := 0
	var broken := 0
	if n is Control and n.has_meta("img"):
		var nm := String(n.get_meta("img"))
		if n.get_meta("img_applied", false):
			applied += 1
		elif String(n.get_meta("img_from", "")) == "verified":
			# Phan biet "ban goc khong ship anh do" voi "code khong gan duoc".
			# Chi cai thu hai moi la loi; cai dau la du lieu von the.
			if UiFrames.has_frame(nm):
				broken += 1
				if no_tex.size() < 12:
					no_tex.append(nm)
	for c in n.get_children():
		var r := _tally(c, no_tex)
		applied += r[0]
		broken += r[1]
	return [applied, broken]
