class_name UiChuyenSac
extends RefCounted

## Chuyen sac (gradient) chu cua mot nhan bang dung chuong trinh shader cua ban
## goc — xem `ui/chuyen_sac.gdshader` de biet cong thuc va bon so do rut ra tu
## do.
##
## Vi sao di qua GDScript: `lua/cocos.lua` la Lua, khong dung duoc lop `Shader`
## cua Godot. Cau bac la `_godot_dat_chuyen_sac` trong `game/lua_runtime.gd`.
##
## KHAC `ui/xam.gd` / `ui/sang.gd` o mot cho quan trong: vat lieu o day KHONG
## dung chung duoc, vi hai mau cua dai la THAM SO cua tung node. Nen moi lan dat
## la mot `ShaderMaterial` MOI, va vat lieu do duoc nho trong meta cua chinh node
## (khoa `KHOA`) de `go()` biet cai nao la cua ta.
##
## `go()` o day KHONG go vat lieu xam / sang nhu `UiSang.go` lam, va do la dung
## chu khong phai thieu: bang bind cho thay ba hieu ung nam tren hai nhom lop
## KHONG GIAO NHAU — xam va sang chi co o `CCSprite` / `CCButton` /
## `CCScale9Sprite` (ba lop deu ra `TextureRect`/`NinePatchRect`), con chuyen sac
## chi co o lop 12 `Label` (ra `Label`). Mot node khong the vua la sprite vua la
## nhan, nen "go vat lieu cua ta" va "tra node ve chuong trinh thuong" (dieu ma
## `vfunc_0x2e8` cua `disableGradual` lam) la cung mot viec.

const SHADER := preload("res://ui/chuyen_sac.gdshader")
const KHOA := "chuyen_sac_mat"


## Dat dai chuyen sac cho mot nhan. `mau_dau` la mau o CUOI o, `mau_cuoi` la mau
## o DAU o — xem `ui/chuyen_sac.gdshader`, muc ve chieu cua `a`.
static func dat(node: Control, mau_dau: Color, mau_cuoi: Color) -> void:
	if node == null:
		return
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("mau_dau", mau_dau)
	m.set_shader_parameter("mau_cuoi", mau_cuoi)
	m.set_shader_parameter("chieu_cao", _chieu_cao(node))
	node.set_meta(KHOA, m)
	node.material = m
	# Chieu cao vao shader la tham so, nen no phai duoc lam moi khi nhan doi o —
	# bo cuc .xgg dat o SAU khi node duoc tao, con `autoFixSize` va `setDimensions`
	# doi o bat cu luc nao. Callable co tham so buoc (`bind`) nen `is_connected`
	# van doi chieu dung node, khong bao trung khi dat lai tren cung node.
	var f := _cap_nhat.bind(node)
	if not node.resized.is_connected(f):
		node.resized.connect(f)


## Vat lieu chuyen sac DANG nam tren node nay (nho trong meta), hoac null.
static func cua(node: CanvasItem) -> Material:
	if node == null or not node.has_meta(KHOA):
		return null
	return node.get_meta(KHOA)


## Tra node ve chuong trinh THUONG. Chi go vat lieu CUA TA — node co the dang
## mang vat lieu cua nguoi khac (`SngRig._dat_tron` gan `CanvasItemMaterial` cho
## tung `Sprite2D` cua no); duong do khong cham duoc vao day (`Label` khong phai
## `Sprite2D`), nhung giu phep kiem lai thi khong bao gio lam mat do cua nguoi
## khac. Meta cung duoc xoa, de `cua()` khong tra ve mot vat lieu da bi go.
static func go(node: CanvasItem) -> void:
	if node == null:
		return
	var m := cua(node)
	if m != null and node.material == m:
		node.material = null
	if node.has_meta(KHOA):
		node.remove_meta(KHOA)


static func _cap_nhat(node: Control) -> void:
	var m := cua(node)
	if m != null:
		m.set_shader_parameter("chieu_cao", _chieu_cao(node))


## Chieu cao dung lam mau so cho vi tri trong dai, tinh bang diem anh.
##
## Ban goc lay `|v_coordYRange.y - v_coordYRange.x|` = chieu cao KHUON ANH cua
## nhan, va chieu cao ay bang O cua nhan: `setDimensions` dat luon co anh theo o
## (do duoc o `brave-cross/work/emu_nhan.py`), con nhan khong co o thi anh = co
## CHU. Trong Godot, o cua `Control` la `size`, nen dung `size.y`.
##
## Vi sao chi mot dong la du: `Control.size` KHONG xuong duoi co toi thieu duoc
## (Godot kep ngay trong `Control::set_size`), ma co toi thieu cua `Label` chinh
## la khoi chu — nen `size.y` bang chieu cao khuon anh o CA HAI duong: nhan co o
## (o cao hon chu thi ban goc ve chu canh giua trong o, dai van trai ca o, dung
## nhu `size.y` o day) va nhan khong co o (o = co chu). Khang dinh "bi kep" do
## `tools/verify_chuyen_sac.gd` do lai chu khong tin.
##
## Truong hop bien con lai: nhan RONG, co toi thieu 0x0 — khong co diem anh nao
## de ve nen mau so la bao nhieu cung vay, lay 1,0 cho khac 0.
static func _chieu_cao(node: Control) -> float:
	return node.size.y if node.size.y > 0.0 else 1.0
