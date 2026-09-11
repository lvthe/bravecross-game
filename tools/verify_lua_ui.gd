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

	# 4. getChildByTag — API ban goc goi nhieu nhat (9529 lan).
	r = lua.run("""
		local tpl = lAchieveTemplate
		local canget = tpl:getChildByTag(2)
		local noget  = tpl:getChildByTag(1)
		local rl     = tpl:getChildByTag(11)
		return {
			canget = canget ~= nil and canget:getStringTag() or '',
			noget  = noget  ~= nil and noget:getStringTag()  or '',
			rlist  = rl     ~= nil and rl:getStringTag()     or '',
			-- reward1 nam trong rewardList2, tag 7
			r1 = (rl ~= nil and rl:getChildByTag(7) ~= nil)
			     and rl:getChildByTag(7):getStringTag() or '',
		}
	""", "getChildByTag")
	t("tag 2 ra canget", r != null and String(r["canget"]) == "canget",
			"duoc '%s'" % (String(r["canget"]) if r != null else "?"))
	t("tag 1 ra noget", r != null and String(r["noget"]) == "noget",
			"duoc '%s'" % (String(r["noget"]) if r != null else "?"))
	t("tag 11 ra rewardList2", r != null and String(r["rlist"]) == "rewardList2")
	t("long hai tang ra reward1", r != null and String(r["r1"]) == "reward1")

	# 5. Lua SUA duoc node that khong — doi ben Godot phai thay.
	var canget := _by_tag(XggLayout.find_node(root, "lAchieveTemplate"), 2)
	t("Godot cung thay canget", canget != null)
	if canget != null:
		canget.visible = true
		lua.run("lAchieveTemplate:getChildByTag(2):setIsVisible(false)", "an")
		t("setIsVisible(false) an that", not canget.visible)
		lua.run("lAchieveTemplate:getChildByTag(2):setIsVisible(true)", "hien")
		t("setIsVisible(true) hien lai", canget.visible)

	# 6. Toa do: Cocos lay goc duoi-trai, Godot tren-trai. Doi qua roi doi lai
	#    phai ve cho cu, khong thi moi thu Lua dat vi tri se troi.
	var name_node := XggLayout.find_node(root, "lAchieveTemplate")
	if name_node != null and name_node.get_child_count() > 0:
		var before: Vector2 = name_node.get_child(0).position
		lua.run("""
			local c = lAchieveTemplate:getChildByTag(10)
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
