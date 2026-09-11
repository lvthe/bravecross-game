extends SceneTree
func _init() -> void:
	var lua := LuaRuntime.new()
	if not lua.open():
		print("khong mo duoc"); quit(); return
	XggLayout.respect_visible = true
	var nen := XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
	lua.bind_layout(nen)
	var goc := XggLayout.find_node(nen, "UIRootLayer")
	goc.position = Vector2.ZERO
	lua.set_ui_root(goc)
	var r = lua.run("""
		local boot = require('bootstrap')
		boot.install_cocos(); boot.install(); boot.boot_goc(); boot.init_config()
		local out = Dictionary()
		for loai = 2, 21 do
			local cfg = G_ConfigManager:GetAchieveConfig(tostring(loai), '1')
			if type(cfg) == 'table' and type(cfg.Award) == 'table' then
				local ok, pc = G_PrizeLogic:GetPrizeWithID(cfg.Award[1])
				if ok and type(pc) == 'table' and type(pc.PrizeContent) == 'table' then
					local ok2, ten = pcall(function()
						local b, n1 = G_CUIRewardLayer:getIconNameInfo(pc.PrizeContent[1])
						return n1
					end)
					out['loai ' .. loai] = ok2 and tostring(ten) or ('HONG ' .. tostring(ten))
				end
			end
		end
		return out
	""", "icon")
	if r == null:
		for e in lua.errors: print("loi: ", e)
		quit(); return
	var ks := []
	for k in r: ks.append(str(k))
	ks.sort()
	for k in ks:
		var ten := str(r[k])
		var tex := UiFrames.get_frame(ten)
		print("   %-10s %-34s kich thuoc=%-12s khoa=%s" % [k, ten,
			str(tex.get_size()) if tex != null else "khong co",
			UiFrames.key_of(ten)])
	quit()
