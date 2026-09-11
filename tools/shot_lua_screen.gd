## Dung mot man hinh cua ban goc de CHUP.
##
##   godot --path . tools/shot_lua_screen.tscn -- --shot=D:/tmp/x.png --at=1
##   godot --path . tools/shot_lua_screen.tscn -- --man=UI_AchievementTask_960_640
##
## Khac voi tools/verify_lua_*.gd (chay khong cua so, chi kiem logic), canh nay
## ve that de nhin bang mat.
##
## Dung cai gi: bo cuc .xgg cua ban goc, co ton trong co hien/an cua no, va
## khung suon Lua cua ban goc chay onInit.
##
## CHUA dung duoc: noi dung that. Muon do noi dung thi ma goc phai tro toi tung
## node bang getChildByTag, ma tag so nguyen do chua tim ra (xem work/xgg.py).
extends Control

const DEFAULT_SCREEN := "UI_AchievementTask_960_640"


func _ready() -> void:
	var screen := DEFAULT_SCREEN
	var boot := true
	var respect := true
	var guess := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--man="):
			screen = a.substr(6)
		elif a == "--khong-lua":
			boot = false
		elif a == "--anh-doan":
			# Bo cuc co ten anh o hai muc tin cay. 'verified' la tu kiem chung
			# duoc bang chinh man do; 'guess' thi khong. Mac dinh chi dung
			# 'verified', nen man hinh trong tron. Co nay dung ca anh DOAN.
			guess = true
		elif a == "--hien-het":
			# Ban goc an gan het node roi de Lua bat len. Chua chay duoc phan
			# Lua do (thieu tag), nen ton trong co an la ra man hinh TRONG
			# TRON. Co nay hien tuot de con nhin thay bo cuc.
			respect = false

	var path := "res://layout_ref/%s.json" % screen
	if not FileAccess.file_exists(path):
		_note("khong co bo cuc %s" % path)
		return

	# Ban goc an gan het node roi de Lua bat len khi can. Ton trong co do thi
	# man hinh gan giong ban goc hon nhieu so voi hien tuot.
	XggLayout.respect_visible = respect
	XggLayout.use_guessed_images = guess
	var root := XggLayout.build(path)
	if root == null:
		_note("khong dung duoc bo cuc")
		return
	add_child(root)

	if not boot:
		return
	if not FileAccess.file_exists("res://sc/share/class.lua"):
		_note("thieu ma goc — python tools/import_lua.py")
		return

	var lua := LuaRuntime.new()
	if not lua.open():
		_note("khong mo duoc Lua: %s" % ", ".join(lua.errors))
		return
	lua.bind_layout(root)
	var r = lua.run("""
		local boot = require('bootstrap')
		boot.install()
		boot.boot({'user.UI.CUIAchieve'})
		local ok, err = pcall(function()
			local ui = CUIAchieve:new()
			ui:onInit()
			return ui
		end)
		return ok and 'ok' or tostring(err)
	""", "chay man")
	print("[lua] onInit: %s" % str(r))


func _note(msg: String) -> void:
	var lb := Label.new()
	lb.text = msg
	lb.position = Vector2(12, 12)
	add_child(lb)
	push_warning(msg)
