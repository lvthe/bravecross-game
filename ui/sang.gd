class_name UiSang
extends RefCounted

## Hieu ung sang mot node VE bang dung shader cua ban goc — xem `ui/sang.gdshader`.
##
## Y het `ui/xam.gd`, va vi cung ly do: `lua/cocos.lua` la Lua nen khong dung
## duoc lop `Shader` cua Godot (cau bac la `_godot_dat_sang` trong
## `game/lua_runtime.gd`), vat lieu la MOT ban dung chung vi shader khong co tham
## so nao doi theo node, va phai gan len CHINH node ve — vat lieu cua node cha
## khong truyen xuong `Sprite2D` con trong Godot 4 (so do o `ui/xam.gd`).

const SHADER := preload("res://ui/sang.gdshader")

static var _vat_lieu: ShaderMaterial


static func vat_lieu() -> ShaderMaterial:
	if _vat_lieu == null:
		_vat_lieu = ShaderMaterial.new()
		_vat_lieu.shader = SHADER
	return _vat_lieu


## Bat/tat hieu ung sang cho mot node ve.
##
## Tat KHONG chi la "go vat lieu cua ta": ban goc dat lai chuong trinh THUONG cua
## node (`ShaderPositionTextureColor`), tuc xoa luon hieu ung XAM neu dang co —
## ca `setGlow` lan `setGray` deu di qua cung mot o `vfunc_0x158`. Nen viec go nam
## o mot cho duy nhat, `go()`, va `ui/xam.gd` cung goi no.
static func dat(node: CanvasItem, bat: bool) -> void:
	if node == null:
		return
	if bat:
		node.material = vat_lieu()
	else:
		go(node)


## Tra node ve chuong trinh thuong: go BAT KY vat lieu dac biet nao cua ta (xam
## hoac sang) dang nam tren node, va khong cham vao vat lieu cua nguoi khac
## (`SngRig._dat_tron` gan `CanvasItemMaterial` cho tung `Sprite2D` cua no).
static func go(node: CanvasItem) -> void:
	if node == null:
		return
	if node.material == vat_lieu() or node.material == UiXam.vat_lieu():
		node.material = null
