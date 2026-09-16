class_name UiXam
extends RefCounted

## To xam mot node VE bang dung shader cua ban goc — xem `ui/xam.gdshader`.
##
## Vi sao phai di qua GDScript: `lua/cocos.lua` la Lua, khong dung duoc lop
## `Shader` cua Godot. Cau bac la `_godot_dat_xam` trong `game/lua_runtime.gd`.
##
## Vat lieu la MOT ban dung chung: shader khong co tham so nao doi theo node nen
## khong can ban rieng, va mot vat lieu dung chung thi Godot gop loi ve (it
## draw call hon).
##
## Phai gan len CHINH node ve, khong phai node cha: do duoc o `tools/do_tron.gd`
## rang vat lieu cua node cha KHONG truyen xuong `Sprite2D` con trong Godot 4
## (nen 0,235 + anh xam 0,392: khong vat lieu 0,3882, vat lieu o node cha cung
## 0,3882, vat lieu o chinh `Sprite2D` moi ra 0,6235).

const SHADER := preload("res://ui/xam.gdshader")

static var _vat_lieu: ShaderMaterial


static func vat_lieu() -> ShaderMaterial:
	if _vat_lieu == null:
		_vat_lieu = ShaderMaterial.new()
		_vat_lieu.shader = SHADER
	return _vat_lieu


## Bat/tat to xam cho mot node ve.
##
## Tat KHONG chi go vat lieu CUA TA, ma tra node ve chuong trinh THUONG — y nhu
## ban goc: `setGray(false)` goi `vfunc_0x158("ShaderPositionTextureColor")`, cung
## mot o ma `setGlow` dung, nen no xoa luon hieu ung sang neu dang co. Vi vay
## phan go nam o `UiSang.go`, va o do moi so sanh vat lieu chu khong dat `null` vo
## dieu kien: node co the dang mang vat lieu cua nguoi khac — `SngRig._dat_tron`
## gan `CanvasItemMaterial` cho tung `Sprite2D` cua no. Duong do khong cham duoc
## vao day (`setGray` chi di qua `TextureRect`/`NinePatchRect`, con `Sprite2D`
## khong phai `Control`), nhung giu phep kiem lai thi khong bao gio lam mat do cua
## nguoi khac.
static func dat(node: CanvasItem, bat: bool) -> void:
	if node == null:
		return
	if bat:
		node.material = vat_lieu()
	else:
		UiSang.go(node)
