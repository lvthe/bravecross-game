# Kiem xem ma Lua co dieu khien duoc cay node Godot khong.
#
#   godot --headless --path . --script tools/verify_lua_ui.gd
#
# Day la mui tham do cua huong "chay thang ma goc" thay vi chep tay tung man.
# No KHONG chay ca man CUIAchieve — lam vay can ca khung suon, mang, dang nhap.
# No chi kiem dung mot dieu, nhung la dieu quyet dinh:
#
#     doan Lua viet y nhu ban goc co tro dung toi node khong, va sua duoc
#     node do khong.
#
# Neu dat thi 501 file giao dien cua ban goc co duong chay. Neu hong thi
# huong nay tac va phai quay lai chep tay.
extends SceneTree

var ok := 0
var bad := 0


func t(name: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [name, ("  (%s)" % note) if note else ""])


func _init() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return

	# 1. Bo cuc that cua ban goc.
	var path := "res://layout_ref/UI_AchievementTask_960_640.json"
	if not FileAccess.file_exists(path):
		print("thieu %s — sinh lai bang layout.py" % path)
		quit(1)
		return
	var root := XggLayout.build(path)
	t("dung duoc bo cuc", root != null)
	if root == null:
		_done()
		return
	# KHONG gan vao get_root(): luc _init() cua SceneTree thi root chua co, gan
	# vao la loi roi treo luon (khong toi duoc quit()). Cay node van chay du
	# ngoai scene tree — meta, con, vi tri deu doc ghi binh thuong.

	# 2. Dua vao Lua duoi dang bien toan cuc, dung cach ban goc lam.
	var n := lua.bind_layout(root)
	t("dat duoc bien toan cuc", n > 0, "dat %d" % n)
	print("  -> %d node co ten thanh bien Lua" % n)

	# 3. Chinh nhung dong nay nam trong CUIAchieve.lua cua ban goc:
	#       self.ScrollLayer = lAchievementTaskSrollLayer
	#       self.TopAchieveItem = lAchieveLayer:getChildByTag(2)
	#    Chay nguyen van, khong sua chu nao.
	var r = lua.run("""
		local co = {}
		co.ui     = lAchieveTaskUI
		co.scroll = lAchievementTaskSrollLayer
		co.tpl    = lAchieveTemplate
		return {
			co_ui     = co.ui ~= nil,
			co_scroll = co.scroll ~= nil,
			co_tpl    = co.tpl ~= nil,
		}
	""", "tro toi node")
	t("thay lAchieveTaskUI", r != null and bool(r["co_ui"]))
	t("thay lAchievementTaskSrollLayer", r != null and bool(r["co_scroll"]))
	t("thay lAchieveTemplate", r != null and bool(r["co_tpl"]))

	# 4. getChildByTag voi TAG THAT.
	#
	# Cac so duoi day khong phai minh dat ra: chung do duoc tu chinh engine
	# ban goc chay trong may ao (work/emu_tags.py hoi getChildByTag tung so
	# mot, work/emu_join.py ghep ket qua vao bo cuc). Tag KHONG nam trong file
	# .xgg — engine sinh ra luc nap — nen khong the doc ra tu file.
	#
	# Va chung khop voi cai ma CUIAchieve.lua mong doi: tag 4 la nut nhan,
	# tag 6 la khung phan thuong. Trong khung do, reward1/2/3 mang dung tag
	# 1/2/3.
	#
	# Nhan dang node tra ve bang `getTag()` — cung mot gia tri do tu may ao,
	# nen phep kiem khong tua vao chinh cai ham dang kiem.
	#
	# Con `getStringTag()`: do truc tiep trong may ao (`work/emu_tags.py
	# --cay` -> `work/tags_cay.json`, 44.587 duong node) thi no tra ve TRUONG
	# 'res' cua ban ghi: 2.742 duong khop 'res', 0 duong khop 'cls', va trong
	# 2.742 do co 1.276 duong ma 'cls' KHAC HAN 'res' (res='CavernEffect_Fire3'
	# con cls='CCNode') — ca 1.276 deu ra 'res'. Man thanh tuu nay res rong
	# HET, nen o day phai ra chuoi rong.
	#
	# Truoc day bo kiem doi 'canget'/'rewardList2'/'reward1' — do la 'cls'
	# (chu thich cua hoa si trong trinh sua), va chinh no lam hong thanh cong
	# cu man Main: CUIMainMenuTool:sortUIItem (CUIMainMenuTool.lua:276-282)
	# doc getStringTag roi tonumber; nam icon thanh cong cu co cls la chu
	# Trung nen tonumber ra nil, ham thoat giua duong, thanh cong cu khong
	# truot (do duoc: nRightToolButtonSizeLengh = 0).
	r = lua.run("""
		local tpl = lAchieveTemplate
		local canget = tpl:getChildByTag(4)
		local noget  = tpl:getChildByTag(10)
		local rl     = tpl:getChildByTag(6)
		local r1     = rl ~= nil and rl:getChildByTag(1) or nil
		return {
			canget = canget ~= nil and canget:getTag() or -1,
			noget  = noget  ~= nil and noget:getTag()  or -1,
			rlist  = rl     ~= nil and rl:getTag()     or -1,
			r1     = r1     ~= nil and r1:getTag()     or -1,
			str    = canget ~= nil and canget:getStringTag() or nil,
		}
	""", "getChildByTag")
	t("tag 4 ra node mang tag 4", r != null and int(r["canget"]) == 4,
			"duoc '%s'" % (str(r["canget"]) if r != null else "?"))
	t("tag 10 ra node mang tag 10", r != null and int(r["noget"]) == 10,
			"duoc '%s'" % (str(r["noget"]) if r != null else "?"))
	t("tag 6 ra node mang tag 6", r != null and int(r["rlist"]) == 6)
	t("long hai tang: con tag 1 cua tag 6 mang tag 1",
			r != null and int(r["r1"]) == 1)
	t("getStringTag() ra RONG khi 'res' rong (khong phai 'cls' = 'canget')",
			r != null and r["str"] != null and String(r["str"]) == "",
			"duoc '%s'" % (str(r["str"]) if r != null else "?"))

	# 4b. setStringTag ghi vao cho RIENG, khong de len 'cls': doc lai ra dung
	#     so vua ghi, va getChildByStringTag tim lai duoc chinh node do.
	r = lua.run("""
		local c = lAchieveTemplate:getChildByTag(4)
		c:setStringTag('7')
		local lai = lAchieveTemplate:getChildByStringTag('7')
		return {
			sau = c:getStringTag(),
			lai = lai ~= nil and lai:getTag() or -1,
			cls_con = c:getStringTag() == 'canget',
		}
	""", "setStringTag")
	t("setStringTag roi doc lai ra dung so", r != null and String(r["sau"]) == "7",
			"duoc '%s'" % (str(r["sau"]) if r != null else "?"))
	t("getChildByStringTag tim lai duoc node vua ghi",
			r != null and int(r["lai"]) == 4)
	t("getStringTag khong con tra ve 'cls'", r != null and not bool(r["cls_con"]))

	# 5. Lua SUA duoc node that khong — doi ben Godot phai thay.
	var canget := _by_tag(XggLayout.find_node(root, "lAchieveTemplate"), 4)
	t("Godot cung thay canget", canget != null)
	if canget != null:
		canget.visible = true
		lua.run("lAchieveTemplate:getChildByTag(4):setIsVisible(false)", "an")
		t("setIsVisible(false) an that", not canget.visible)
		lua.run("lAchieveTemplate:getChildByTag(4):setIsVisible(true)", "hien")
		t("setIsVisible(true) hien lai", canget.visible)

	# 6. Toa do: Cocos lay goc duoi-trai, Godot tren-trai. Doi qua roi doi lai
	#    phai ve cho cu, khong thi moi thu Lua dat vi tri se troi.
	var name_node := XggLayout.find_node(root, "lAchieveTemplate")
	if name_node != null and name_node.get_child_count() > 0:
		var before: Vector2 = name_node.get_child(0).position
		lua.run("""
			local c = lAchieveTemplate:getChildByTag(2)
			if c then local x, y = c:getPosition(); c:setPosition(x, y) end
		""", "doi toa do")
		var after: Vector2 = name_node.get_child(0).position
		t("doi toa do qua lai khong troi", before.distance_to(after) < 0.01,
				"%s -> %s" % [before, after])

	# 7. Chua lam gi thi phai bao duoc la chua lam.
	var miss := lua.missing()
	print("  -> API Cocos bi goi ma chua lam: %d loai" % miss.size())
	for k in miss:
		print("       %s x%d" % [k, miss[k]])

	if not lua.errors.is_empty():
		for e in lua.errors:
			print("  loi Lua: %s" % e)
	root.free()
	_done()


func _by_tag(parent: Node, tag: int) -> Control:
	if parent == null:
		return null
	for c in parent.get_children():
		if c.has_meta("tag") and int(c.get_meta("tag")) == tag:
			return c
	return null


func _done() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
