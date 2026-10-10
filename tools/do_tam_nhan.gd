# Dem nhan (CCLabelTTF) co ANH NEN trong bo cuc, va cho biet anh nen co ve duoc
# khong. Tra loi cau hoi: "tam vang buildingname_16.png co duoc gan vao nhan
# khong, hay bi bo o dau do".
#
#   godot --headless --path . --script tools/do_tam_nhan.gd -- <ten bo cuc .json>
#
# Vi sao can: `xgg_layout.gd` goi `UiFrames.set_frame(node, img)` cho MOI node co
# `img`, ke ca nhan; nhung `ui_frames.gd:set_frame` tra ve `false` cho bat ky node
# nao khong phai TienDo / UiONhap / NinePatchRect / TextureRect — tuc la `Label`
# bi bo IM LANG. Node van co meta `img` nhung khong co `img_applied`, nen nhin cay
# khong thay gi. Phai dem theo `img_applied` moi biet.
extends SceneTree

const XggLayout := preload("res://ui/xgg_layout.gd")
const UiFrames := preload("res://ui/ui_frames.gd")

static var _so := {"nhan": 0, "co_anh": 0, "ve_duoc": 0}


static func _dem(n: Node, thieu: Dictionary) -> void:
	if n.has_meta("type_name") and String(n.get_meta("type_name")) == "CCLabelTTF":
		_so.nhan += 1
		if n.has_meta("img") and String(n.get_meta("img")) != "":
			_so.co_anh += 1
			var img := String(n.get_meta("img"))
			if n.has_meta("img_applied"):
				_so.ve_duoc += 1
			else:
				# In ca KICH THUOC TEP GIAI RA so voi o cua nhan: lech nhau thi
				# do la ly do that (ten tran trung -> lay nham ban), khong phai
				# "thieu anh". Day moi la thu phan biet duoc hai nguyen nhan.
				var tex := UiFrames.get_frame(img)
				var kich := "khong co anh"
				if tex != null:
					kich = "%dx%d vs o %dx%d" % [tex.get_width(), tex.get_height(),
							int((n as Control).size.x), int((n as Control).size.y)]
				thieu["%s  [%s]" % [img, kich]] = int(thieu.get("%s  [%s]" % [img, kich], 0)) + 1
	for c in n.get_children():
		_dem(c, thieu)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://layout_ref/UI_Main_960_640.json"
	var root := XggLayout.build(path)
	if root == null:
		print("KHONG DUNG DUOC BO CUC: ", path)
		quit(1)
		return
	var thieu: Dictionary = {}
	_dem(root, thieu)
	var nhan: int = _so["nhan"]
	var co_anh: int = _so["co_anh"]
	var ve_duoc: int = _so["ve_duoc"]
	print("bo cuc           %s" % path)
	print("nhan CCLabelTTF  %d" % nhan)
	print("  co anh nen     %d" % co_anh)
	print("  VE DUOC        %d" % ve_duoc)
	print("  khong ve duoc  %d" % (co_anh - ve_duoc))
	for k in thieu:
		print("     thieu %-40s %d" % [k, thieu[k]])
	# Vi sao thieu: ten khong co trong chi muc, hay co ma khong doc duoc anh.
	print("UiFrames: %s" % str(UiFrames.stats()))
	var m := UiFrames.missing()
	print("so ten da yeu cau ma khong co anh: %d" % m.size())
	if m.size() > 0 and m.size() <= 20:
		print("  ", str(m))
	quit(0)
