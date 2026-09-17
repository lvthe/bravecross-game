class_name UiONhap
extends Control

## O NHAP CHU (typeName 'CCEditBox', lop bind 21; 40 node trong 22 bo cuc).
##
## KHONG ke thua LineEdit, va day la quyet dinh do duoc chu khong phai so thich:
## ba ham cua lua/cocos.lua — `la_nhan_chuyen_sac`, `setString`,
## `setHorizontalAlignment` — deu hoi `gd.text == nil` de biet node co phai NHAN
## khong. Mot LineEdit o lop ngoai tra `text` khac nil, nen o nhap se bi coi la
## nhan: bi to mau chu theo dai va bi `setString` ghi de. Node nay giu `text` la
## nil, con chu that nam trong LineEdit con.
##
## Node giu DUNG HAI con:
##   * con 0 `nen`  — anh nen doc tu ban ghi .xgg (truong +0xF0 cua ban ghi 324
##     byte; xem work/xgg.py). Ve duoi nen phai la con so 0.
##   * con 1 `o_chu` — LineEdit that, an kin o cua node.
##
## Bon su kien cua ban goc (began / changed / ended / return — bon ten doc tu
## .rodata 0x7a6a30..0x7a6a90) thanh bon tin hieu o day; game/lua_runtime.gd
## noi chung voi ham Lua da dang ky bang `setLuaCallbackObjAndFunc`.
##
## Nhip cua bon tin hieu do LineEdit cua Godot 4.7.2 quyet dinh, va no KHAC ban
## goc o dung mot cho — do tren mot LineEdit tran:
##
##   * `began` / `ended` (tieu diem) va `return` (Enter) ban NGAY trong khung do;
##   * `changed` doi sang khung SAU (`text_changed_dirty` trong line_edit.cpp),
##     va nhieu lan sua trong CUNG mot khung GOP thanh MOT lan ban, mang chu cuoi
##     (go 'x' roi 'a' trong cung khung -> dung mot su kien, chu 'xa');
##   * dat chu bang ma (`o_chu.text = ...`) khong bao gio ban, ke ca sau mot khung.
##
## Ban goc ban `changed` ngay ben trong ham xu ly phim, moi lan mot. Mot khung tre
## va viec gop lai la khac biet CO THAT, va khong sua duoc neu khong tu viet lai
## phan go phim cua LineEdit — ghi lai day de nguoi doc sau biet ma doi chieu.

const TEN_NEN := "nen"
const TEN_O_CHU := "o_chu"

## Tin hieu ban ra khi LineEdit nhan / mat tieu diem, khi chu doi, khi go Enter.
signal bat_dau_go()
signal doi_chu(chu: String)
signal go_ve(chu: String)
signal ket_thuc_go()

var o_chu: LineEdit = null
var nen: TextureRect = null

## Dang dat chu bang MA (dat_chu). Khong can co nao chan su kien 'changed': do
## tren LineEdit cua Godot 4.7.2 thi dat `o_chu.text` KHONG ban `text_changed`,
## ke ca sau mot khung. Ban goc cung im lang, vi ly do khac — than ham `setText`
## (0x2d1cc5) chi goi assign chuoi roi goi vtable cua widget trong, KHONG goi
## ham Lua da dang ky (CUIGuildInformation.lua:703 goi `pInput:setText(...)` tu
## trong ham xu ly cua chinh no).


func _init() -> void:
	nen = TextureRect.new()
	nen.name = TEN_NEN
	nen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nen.stretch_mode = TextureRect.STRETCH_SCALE
	nen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nen.visible = false
	_an_kin(nen)
	add_child(nen)

	o_chu = LineEdit.new()
	o_chu.name = TEN_O_CHU
	# Khung cua o la ANH NEN cua bo cuc (xem dat_nen), khong phai StyleBox cua
	# Godot: de nguyen thi o co hai khung chong nhau.
	o_chu.flat = true
	_an_kin(o_chu)
	add_child(o_chu)

	# Bon tin hieu nay la bon su kien cua ban goc. Nhip ban cua chung do LineEdit
	# quyet dinh — xem khoi dau file: `changed` doi sang khung sau va gop nhieu
	# lan sua trong cung khung lam mot.
	o_chu.text_changed.connect(_khi_doi_chu)
	o_chu.text_submitted.connect(_khi_go_ve)
	o_chu.focus_entered.connect(_khi_bat_dau_go)
	o_chu.focus_exited.connect(_khi_ket_thuc_go)


## Cho con an kin o cua node cha. Dat thang bon neo thay vi
## `set_anchors_preset()`: ham do doi node da nam trong cay, ma o day node con
## duoc dung tu `_init` (truoc khi vao cay).
static func _an_kin(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


## Anh nen cua o, doc tu ban ghi .xgg. KHONG doi o cua node: anh nho hon o rat
## nhieu (ui_background189.png la 30x30 theo section C cua chinh bo cuc do, con
## cac o dung no la 150x30 .. 410x45 — do tren ca 13 node dung anh nay), tuc ban
## goc CO GIAN anh nen theo o. Xem them ui/ui_frames.gd, nhanh UiONhap.
func dat_nen(tex: Texture2D) -> void:
	nen.texture = tex
	nen.visible = tex != null


## Dat chu bang MA (CCEditBox::setText). Khong ban su kien 'changed' — chinh
## LineEdit da im lang khi dat chu bang ma, khong phai nho co chan nao.
func dat_chu(s: String) -> void:
	o_chu.text = s


## Chu dang co trong o (CCEditBox::getText). Ban goc: khi widget trong khong co
## thi tra ve mot chuoi RONG TINH — o day widget trong luon co, nen chuoi rong
## chi co nghia la o dang rong.
func lay_chu() -> String:
	return o_chu.text


## setMaxLength cua ban goc (0x2d1bcd) cat thanh so nguyen bang `vcvt.s32.f64`
## — cat ve phia 0 (3,7 -> 3; -3,7 -> -3), roi ghi vao +0x240 va chuyen tiep cho
## widget trong. Gia tri do KHONG co ham doc nao, va ca 973 file ma goc khong he
## goi `setMaxLength` (0 cho), nen don vi dem cua widget trong khong khoi phuc
## duoc — vi vay o day CHI ghi lai so da cat, KHONG tu cat chu: cat theo mot
## luat khac luat goc thi con te hon khong cat.
func dat_dai_toi_da(n: float) -> void:
	set_meta("max_length", int(n))


## Can chu trong o. Thu tu enum y nhu truong alignH cua .xgg (ban ghi o nhap
## khong co truong do — ca 40 node dung 20 truong), y nhu
## HORIZONTAL_ALIGNMENT_* cua Godot: 0 trai, 1 giua, 2 phai — ba so giong nhau
## nen ghi thang. Thuoc tinh cua LineEdit ten la `alignment`, ham dat ten la
## `set_horizontal_alignment` (do ca hai danh sach cua lop).
func dat_can_ngang(k: int) -> void:
	o_chu.set_horizontal_alignment(clampi(k, 0, 2))


## Can doc: GHI LAI, khong ve ra duoc. LineEdit cua Godot 4.7 khong co can doc
## nao — do ca danh sach thuoc tinh (text, placeholder_text, alignment,
## max_length, ...) lan danh sach phuong thuc, khong mot ten nao chua 'vertical'.
## Ban goc day xuong vtable +0x68 cua widget trong, con o day khong co gi de
## day; tu chinh hinh hoc (thu nho o chu roi doi cho) la mot luat KHAC han luat
## goc, nen khong lam. Ca 973 file ma goc khong goi can doc tren O NHAP lan nao —
## bon cho goi deu la nhan (CUIBarracks.lua:260,273; CUIResearch.lua:170,211).
func dat_can_doc(k: int) -> void:
	set_meta("can_doc", clampi(k, 0, 2))


func _khi_doi_chu(chu: String) -> void:
	doi_chu.emit(chu)


func _khi_go_ve(chu: String) -> void:
	go_ve.emit(chu)


func _khi_bat_dau_go() -> void:
	bat_dau_go.emit()


func _khi_ket_thuc_go() -> void:
	ket_thuc_go.emit()
