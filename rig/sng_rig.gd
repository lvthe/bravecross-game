# Nap mot nhan vat da xuat tu ban goc (JSON + PNG roi) thanh cay Node2D
# co AnimationPlayer chay duoc ngay.
#
# Nguon du lieu la thu muc do work/export.py sinh ra:
#
#     <Ten>/
#         <Ten>.json      bo xuong, bien the, dong tac, keyframe
#         sprites/*.png   tung bo phan mot file
#
# Cach dung:
#
#     var rig := SngRig.build("res://assets_ref/Archer")
#     add_child(rig)
#     rig.play("Walk")
#
# Mot file JSON chua NHIEU BIEN THE (variant). Vd Archer co:
#     Archer                 bo xuong chinh, 19 dong tac
#     Archer_Dong/Evil/Shi   cung bo xuong, khac bo sprite  -> trang phuc
#     Archer_WeaponNormal    bo xuong rieng cua vu khi, 1 dong tac
# build() lay bien the MANG DUNG TEN thu muc, dung nhu ban goc; ten thu muc khong
# phai mot bien the thi moi lay nhom nhieu dong tac nhat — xem _bien_the_cho().
@tool
class_name SngRig
extends Node2D

## Doi dau toa do Y. Cocos2d dung truc Y huong LEN nen tuong la phai doi,
## nhung dung thu thi nhan vat lon nguoc — dau duoi chan tren. Toa do trong
## .xml da o he Y huong XUONG san, giong Godot. Giu false.
const FLIP_Y := false
## Goc xoay di theo truc Y, khong doi dau thi thoi.
const NEGATE_ROT := false
## Thu tu trong "children" la tu SAU ra TRUOC (phan tu dau nam sau lung).
const CHILDREN_BACK_TO_FRONT := true

## So khung moi giay. Ban goc KHONG luu truong nay o dau trong .xml — day la
## phong doan. Doi so nay neu hoat anh chay nhanh hay cham hon ban goc.
const FPS := 24.0

## Bo phan khong co anh: diem gan, vung cham. Van tao node de gan hieu ung
## hay hitbox vao, chi la khong co Sprite2D.
const MARKER_PREFIXES := ["PlugIn", "Collision", "ShootPoint", "Bone", "Effect"]

## Ten cach tron trong truong "blend" cua khung, ung voi phep tron CONG.
##
## Ban goc KHONG co mot che do tron chung cho armature: cach tron nam trong
## TUNG KHUNG (anim.py, +0x38 cua ban ghi khung), nen cung mot bien the co the
## vua ve thuong vua ve cong — `UIWuDaoHui_HeroLightFront` co 6 khung 'screen'
## lan trong 19 khung 'normal'. Dat dai additive cho moi SngRig la SAI.
##
## Doi chieu hai duong doc lap, khop nhau:
##
##   * do tren ban goc chay trong may ao (`work/emu_dom.py`): hieu ung nao co
##     khung 'screen' thi sang len o MOI kenh (chi tron cong lam duoc the),
##     hieu ung khong co thi toi di o kenh nao do (tron cong khong bao gio lam
##     toi) — 9/9 bien the dung nhu du lieu noi;
##   * ham phan nhanh trong `libgame.so`, 0x25d476..0x25d4ce — doc thang cap
##     he so ra: 'screen' -> (0x302, 1) = GL_SRC_ALPHA, GL_ONE = phep tron CONG.
##     ('' / 'normal' -> (1, 0x303); 'multiply' -> (0x306, 0x303).)
##
## Ten la tra ve MIX KHONG phai lam au: chinh ham cua ban goc lam vay — chuoi
## khac 'screen'/'multiply' roi vao nhanh 0x25d4c6, tuc che do mac dinh. Do tren
## 418 file .xml / 644.623 khung: 'normal' 462.413, rong 157.033, 'screen'
## 22.083, con lai 9 khung ten rac. KHONG co khung 'multiply' nao.
const BLEND_CONG := "screen"

## Bo phan la ve tich cua file goc: ten lop Photoshop con sot lai, hoac lop
## hieu ung logic. Chung khong thuoc dang nguoi va nam rat xa than —
## MaChao/Fight co "Layer006" cach goc 436 px, to hon ca nhan vat.
##
## Ban goc chi loe chung vai khung roi tat. Duong doi anh theo khung nay da giai
## (chi so anh `d` cua khung, anim.py) va SngRig da lam theo; bo loc chi con dung
## cho MAN TRAN (`battle/*` goi `SngRig.build(..., true)`) vi chua do lai xem con
## lop nao cua nhom nay hien sai. Trinh xem rig de tat de con nhin thay het.
##
## Duong LUA (`LuaRuntime._tao_rig`, tuc toan bo giao dien) thi KHONG loc: o do
## `Layer*` khong phai ve tich ma la chinh doi tuong — do ra thi **1319/2935**
## bien the dung ra 0 xuong, ke ca toa nha Vo Hoi cua man Main. Xem chu thich o
## cho goi `SngRig.build` trong `game/lua_runtime.gd`.
##
## CHI LOC O TANG NGOAI CUNG, khong truyen xuong rig long nhau. Danh sach bo
## phan cua mot nhan vat dat ten co nghia (Head, Body, ArmLeft), nen ten Layer*
## o do dung la ve tich. Con rig long nhau la mot ban ve rieng, bo phan cua no
## dat ten Photoshop la binh thuong: CaoCao_mc_Head co dung 4 bo phan va CA
## BON deu ten Layer*. Truyen co nay xuong la mat sach dau va than — da dinh
## dung the, CaoCao tu 23 bo phan con 17 va chi con moi thanh kiem.
const CLUTTER_PREFIXES := ["Layer", "LayerName", "Logic_", "图层"]

## Ngoai le cua bo loc tren: ho `Logic_Body*` KHONG phai ve tich — no giu dung
## anh THAN nhan vat (`Player000M_res-Body` 33x41, `Player000W_res-Body` 23x32),
## va do la noi dung DUY NHAT cua xuong ay. Bo no thi nhan vat vao tran khong co
## than: man tran la cho duy nhat con bat co loc (`battle/*` truyen `true`), nen
## o man Xem Tuong van thay du than ma vao tran la mat.
##
## Do 2026-09-20 tren 397 rig / 22.874 bo phan tang ngoai cung: 94 xuong
## `Logic_Body*` o tang ay, **72 chua ANH THAT**. Cac ten `Logic_*` khac dung la
## lop hieu ung / logic (`Logic_Mark*`, `Logic_Chain`, `Logic_Ball_*`,
## `Logic_Area_*`, `Logic_Swift*`, `Logic_Track`) nen VAN bi loc binh thuong —
## khong phai bo `Logic_` khoi luat, ma la chua rieng ho nay ra.
const CLUTTER_NGOAI_LE := ["Logic_Body"]

var data: Dictionary = {}
var variant: String = ""
var source_dir: String = ""
var bones: Dictionary = {}
var player: AnimationPlayer = null
var missing_sprites: PackedStringArray = []
## Bo phan tro toi mot rig long nhau (<Ten>_mc_...) chu khong phai anh.
var nested_rigs: PackedStringArray = []
var hide_clutter := false
var _chain: Dictionary = {}
## Dung chung cho MOI xuong cua rig nay: vai tram node tro cung mot vat lieu,
## khong phai moi xuong mot cai.
var _vat_lieu_cong: CanvasItemMaterial = null
## 'multiply' co dinh nghia trong engine nhung KHONG xuat hien trong du lieu
## nao ca (0 tren 644.623 khung). Canh bao mot lan, dung im lang roi ve sai.
var _da_canh_bao_multiply := false


## Dung nhan vat tu thu muc da xuat. Tra ve null neu doc khong duoc.
##
## `chinh_xac` = CHI nhan khi `want_variant` la MOT NHOM dong tac co that trong
## chinh file rig nay; khong lui ve nhom nhieu dong tac nhat. Duong HIEU UNG bat
## buoc co (xem `battle/san_tran_ve.gd:hieu_ung_tai_o`), vi do la cho duy nhat
## phep lui ay ve ra duoc mot HINH KHAC HAN.
##
## Do 2026-09-21 tren 56 ten hieu ung thuc tinh cua `wake_ref.json`: 46 ten ve
## ra dung art cua minh, **6 ten khong co art rieng** (`CaiWenJiWakeBuff`,
## `JiangWeiExclus_WeaponWake`, `SiMaYi_WakeBuff`, `SuperThunderDragonHero_Shield`,
## `ThunderDragon_ShakeWake`, `XuShu_WeaponWakeFinal`) bi phep lui nay ve ra
## **THAN cua chinh tuong ay** (16/18/14/8/15 dong tac), va 4 ten khong ra thu
## muc nao. Con tren ten CO THAT trong kho thi phep lui sach: do ca 2757 ten bien
## the, **0** ca giai ra thu muc ma ten khong phai bien the that.
static func build(dir_path: String, want_variant: String = "",
		no_clutter := false, chinh_xac := false) -> SngRig:
	var char_name := dir_path.get_file()
	var json_path := dir_path.path_join(char_name + ".json")
	if not FileAccess.file_exists(json_path):
		push_error("SngRig: khong thay %s" % json_path)
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SngRig: %s khong phai JSON hop le" % json_path)
		return null

	var rig := _make(parsed, dir_path, char_name, want_variant, {}, no_clutter, chinh_xac)
	if rig == null:
		push_error("SngRig: %s khong co bien the nao co dong tac" % char_name)
	return rig


## Dung mot bien the. `chain` giu cac bien the dang nam tren duong dung, de
## rig long nhau khong goi vong lai chinh no.
static func _make(src: Dictionary, dir_path: String, node_name: String,
		want_variant: String, chain: Dictionary, no_clutter := false,
		chinh_xac := false) -> SngRig:
	var rig := SngRig.new()
	rig.hide_clutter = no_clutter
	rig.data = src
	rig.source_dir = dir_path
	rig.name = node_name
	if want_variant == "":
		# Ten thu muc lam bien the: `Player000.xml` khong co nhom nao ten
		# `Player000`, nen duong lui ve nhom nhieu dong tac nhat o day la DUNG
		# (tai lieu hoa o `_bien_the_cho`).
		rig.variant = rig._bien_the_cho(node_name)
	elif chinh_xac and not rig.co_nhom(want_variant):
		# Ten CO trong du lieu nhung KHONG phai mot nhom cua file nay: ve tiep la
		# ve mot hinh khac han. Tra null de nguoi goi dem duoc la mot cu TRUOT,
		# thay vi mot cu "ve duoc" ma sai.
		return null
	else:
		rig.variant = want_variant
	if rig.variant == "":
		return null
	rig._chain = chain.duplicate()
	rig._chain[rig.variant] = true
	rig._build_bones()
	rig._build_animations()
	rig._san_sang_tieng()
	return rig


## Cac bien the co dong tac (trang phuc, vu khi...).
func variants() -> PackedStringArray:
	var out := PackedStringArray()
	for g in data.get("groups", []):
		out.append(g.get("variant", ""))
	return out


## `ten` co phai MOT NHOM dong tac co that trong file nay khong. Day la phep thu
## dung cho duong HIEU UNG (xem `build`, tham so `chinh_xac`): khac `variants()`
## o cho no tra loi cho MOT ten bat ky, ke ca ten khong co trong file.
##
## KHONG tinh luat TRANG PHUC (`Defender_VampirE` dung nhom `Defender`): luat ay
## do duoc tren 76 bo phuc trang va la dung cho THAN TUONG, nhung voi mot ten
## HIEU UNG thi chinh no la phep lui ve ra than tuong — do 6/56 ten thuc tinh.
func co_nhom(ten: String) -> bool:
	if ten == "":
		return false
	for g in data.get("groups", []):
		if String(g.get("variant", "")) == ten:
			return true
	return false


## Thu muc rig cho mot ten bien the — MOT luat, ba duong goi ten dung chung
## (`LuaRuntime._tao_rig`, `SngRig.theo_ten`, `SanTranVe._thu_muc_rig`). Luat nay
## tung chep tay o ba noi, va do la cach no lech nhau.
##
## Tra `[duong, bien_the]`: trung ten thu muc thi bien_the "" (dung chinh ten
## thu muc lam bien the), khong thi cat dan duoi va xin ten day du lam BIEN THE
## (`Player000M03W` -> thu muc `Player000`, bien the `Player000M03W`).
## Tra `["", ""]` khi khong thu muc nao nhan.
static func tim_thu_muc(ten: String) -> Array:
	if ten == "":
		return ["", ""]
	if FileAccess.file_exists("res://assets_ref/%s/%s.json" % [ten, ten]):
		return ["res://assets_ref/" + ten, ""]
	for i in range(ten.length() - 1, 3, -1):
		var goc := ten.substr(0, i).trim_suffix("_")
		if FileAccess.file_exists("res://assets_ref/%s/%s.json" % [goc, goc]):
			return ["res://assets_ref/" + goc, ten]
	return ["", ""]


## Ten cac dong tac cua bien the dang dung.
func animations() -> PackedStringArray:
	var out := PackedStringArray()
	if player:
		for a in player.get_animation_list():
			out.append(a)
	return out


func play(anim_name: String) -> bool:
	if player == null or not player.has_animation(anim_name):
		return false
	player.play(anim_name)
	return true


## Thoi luong mot dong tac, tinh bang GIAY. Ma goc hoi cai nay 97 lan
## (`_lua_getAnimationTime`) roi lay do lam do tre: no phai cho dong tac dien
## xong moi chay buoc ke tiep (man ket thuc tran, chuong trinh mo cong trinh).
## Thieu thi tra 0,0: cho 0 giay = di tiep ngay, va do cung la gia tri vo hai
## nhat — khong do duoc ban goc tra gi khi dong tac khong ton tai, ma moi gia
## tri <= 0,001 thi Cocos deu coi la "khong cho".
func thoi_luong(anim_name: String) -> float:
	if player == null:
		return 0.0
	if not player.has_animation(anim_name):
		return 0.0
	return player.get_animation(anim_name).length


## Dung dong tac dang chay, GIU nguyen tu the dang dung. Cocos
## `stopAnimation` khong dua ve khung 0 — ma vai cho goi no roi doi node im
## nguyen o tu the vua chay (`spBuilding:_lua_stop()`, 24 cho).
func dung() -> void:
	if player != null:
		player.stop(true)


## He so chay nhanh/cham. Ma goc goi 26 cho (`_lua_setAnimationRate`).
## `speed_scale` cua Godot chay muot theo khung, khac Cocos o cho toc do doi
## ngay lap tuc — nhung do lech chi thay trong vai khung dau, va khong co so do
## nao noi ban goc doi luc nao, nen lay duong muot.
func dat_toc_do(he_so: float) -> void:
	if player != null:
		player.speed_scale = he_so


## Diem gan (plug) cua ban goc. Bo phan trong .xml dat ten "PlugIn_<n>" hoac
## "PlugIn_<n>_<gi>" — hau to chi la chu thich cua nguoi thiet ke, khong nam
## trong so. Do tren 418 file .xml / 587 bien the co plug: PlugIn_1 (558),
## _2 (513), _3 (512), roi _30 (130), _31 (50), _11 (48), _40 (21), _5 (16),
## _60 (16), _6 (8), _32 (7), _4 (5), _20 (3), _50 (2), _102 (1), _7 (1).
##
## Khop theo SO chu khong theo thu tu xuat hien, va dieu do da kiem bang mot
## ca khong the trung: Gashapon co dung PlugIn_4_Hero, PlugIn_5_Word,
## PlugIn_6_Light, PlugIn_7_HeroName — va CUIUnlockHeroAnimation.lua:166-169
## goi _lua_clearPlugIn dung bon so 4, 5, 6, 7. UIZhanYiFuBen thi moi bien the
## chi co PlugIn_6_Text, dung cho FBDingJunShanJiaoFei.lua:85 (so 6).
func plug(idx: int) -> Node2D:
	var dau := "PlugIn_%d" % idx
	for ten in bones:
		var t := String(ten)
		if t == dau or t.begins_with(dau + "_"):
			return bones[ten]
	return null


## Hop cham cua armature (`_lua_CollisionSize` cua ban goc, 6 cho goi). Tra ve
## `Vector2.ZERO` khi khong tra duoc — dung nhu ban goc tra (0, 0) cho armature
## khong co xuong `Collision`. Cong thuc, so do va do chinh xac: `battle/cham_ref.gd`.
##
## Tra theo BIEN THE DANG DUNG (`variant`), vi do moi la hinh tuong that su duoc
## dung ra — mot file `.xml` chua nhieu armature voi co rieng.
##
## HE QUA da do, va da SUA: **45** rig co bien the mang ten file khac nhom nhieu
## dong tac nhat, va **12** trong so do co hop cham KHAC HAN nhau giua hai bien
## the. Truoc khi `_bien_the_cho()` ra doi, 12 rig ay tra (0, 0) hoac sai so.
## Bang chung chon dung bien the nao: xem chu thich `_bien_the_cho`.
func ho_cham() -> Vector2:
	return ChamRef.ho_cham(variant)


## Bien the nay co so do hop cham khong — de phan biet "(0, 0) vi khong co xuong
## `Collision`" voi "(0, 0) vi bang thieu".
func co_ho_cham() -> bool:
	return not ChamRef.muc(variant).is_empty()


## Xuong `ten` co trong dong tac dau tien nao khong.
##
## De `_lua_getBonePosInNode` phan biet "khong co xuong" — ban goc tra `(0, 0)` —
## voi mot diem that su bang `(0, 0)`. Ban goc KHONG bao loi khi ten xuong sai
## (do tren mot ten bia dat ra), nen phep kiem nay khong duoc nem loi thay.
func co_xuong(ten: String) -> bool:
	return not khoa_xuong(ten).is_empty()


## Khoa 0 cua xuong `ten` trong DONG TAC DAU TIEN co xuong ay — `{}` neu khong co.
##
## Cung mot luat ma `cham_ref.py` dang dung cho xuong `Collision` ("khoa 0 cua
## dong tac DAU TIEN co xuong"), va cung la luat duy nhat tai hien duoc moi phep
## do dang co. Ban goc thi doc theo khung dang chay; o day KHONG phan biet duoc
## hai luat: 223/224 rig co khoa 0 giong nhau o moi dong tac, va phep doi chung
## tren may ao (doi dong tac roi hoi lai) AM — `playAnimation` khong kip co tac
## dung trong cung mot doan Lua.
func khoa_xuong(ten: String) -> Dictionary:
	for a in _group().get("animations", []):
		for b in a.get("bones", []):
			if String(b.get("name", "")) == ten:
				var ks: Array = b.get("keys", [])
				return ks[0] if not ks.is_empty() else {}
	return {}


## Diem neo cua xuong trong HE CUA RIG (Godot, y huong xuong) — cap `+0x08` cua
## ban ghi khung, `anim.py` ghi ra thanh `v2`/`v3`.
##
## Day la cap ma `_lua_getBonePosInNode` cua ban goc tra ve (voi y doi dau):
## `(v2, -v3)`. Do bang may ao tren nam xuong va doi chieu duoc doc lap tu du
## lieu — ZhangLiangBao `Collision` `(-88, -227)` -> `(-88, 227)`,
## ElephantSoldier `(-103, -115)` -> `(-103, 115)`, YuJin `Head` `(1, -127)` ->
## `(1, 127)`, Gashapon `(-132, -196)`, Hoplite `(-77, -162)`: khop CA NAM so
## may ao do. Xem `emu_xuong.py` muc (A)/(B)/(D).
##
## Truoc luot nay `v2`/`v3` khong duoc xuat ra JSON (chung la cap ma `anim.py`
## ghi la "chua ro nghia" — nay biet mot nguoi doc).
func diem_xuong(ten: String) -> Vector2:
	var k := khoa_xuong(ten)
	if k.is_empty():
		return Vector2.ZERO
	return Vector2(float(k.get("v2", 0.0)), float(k.get("v3", 0.0)))


## Anh ma xuong `ten` ve o khoa 0 cua dong tac dau tien co xuong ay. `""` khi
## khong tra duoc (khong co xuong, chi so `d` am/nam ngoai danh sach, hoac ten
## anh khong co trong `spriteFiles`).
func anh_xuong(ten: String) -> String:
	var k := khoa_xuong(ten)
	if k.is_empty():
		return ""
	var d := int(k.get("d", -1))
	if d < 0:
		return ""
	var refs: Array = _anh_cua_xuong().get(ten, [])
	if d >= refs.size():
		return ""
	return String(refs[d])


## `(w, h)` = `sourceSize` cua anh ma xuong ve — dung nguon khung ma ban goc doc
## (`CCSpriteFrame::getOriginalSize`; do: `BatFlight` 145,00999450684 x 120 chu
## khong phai 290,02 cua ban ghi `.xml`). `Vector2.ZERO` khi anh do khong xuat
## duoc ra PNG (muc danh dau kich thuoc 0).
##
## `spriteFiles[anh] = null` nghia la sprite do KHONG cat duoc PNG (o 0x0 trong
## atlas — moi nhan vat co mot cai), chu khong phai "khong co o". O cua no van
## nam trong `.plist` va `export.py` xuat sang ban do `sourceSize`. Thieu duong
## lui nay thi `YuJin_res-44` (1x1) ra (0, 0) trong khi may ao do hop xuong
## `Collision` la 140,00547790527 x 179,98643493652 — bon trong nam rig da do
## deu dung anh `_res-44` (YuJin, ZhangLiangBao, BatFlight, DragonFlight).
func khung_xuong(ten: String) -> Vector2:
	var anh := anh_xuong(ten)
	if anh == "":
		return Vector2.ZERO
	var info: Variant = data.get("spriteFiles", {}).get(anh, null)
	if info is Dictionary and not (info as Dictionary).is_empty():
		return Vector2(float(info.get("srcW", 0.0)), float(info.get("srcH", 0.0)))
	var nguon: Array = data.get("sourceSize", {}).get(anh, [])
	if nguon.size() < 2:
		return Vector2.ZERO
	return Vector2(float(nguon[0]), float(nguon[1]))


## Hop cua xuong bat ky = dung cong thuc `hop()` cua `cham_ref.py`, voi `(w, h)`
## la `sourceSize` cua anh xuong ay dang ve. Khi xuong la `Collision` thi bang
## DUNG `_lua_CollisionSize` (do tren ba rig: YuJin, Gashapon, Hoplite).
##
## `(0, 0)` khi khong tra duoc — cung nhu ban goc: ten xuong khong co thi im lang
## tra (0, 0), khong bao loi (do tren `DaQuZhanShi` va mot ten bia).
func hop_xuong(ten: String) -> Vector2:
	var k := khoa_xuong(ten)
	if k.is_empty():
		return Vector2.ZERO
	var wh := khung_xuong(ten)
	if wh == Vector2.ZERO:
		return Vector2.ZERO
	return ChamRef.tinh(wh, float(k.get("rot", 0.0)), float(k.get("rot2", 0.0)),
			float(k.get("sx", 1.0)), float(k.get("sy", 1.0)))


## Bang LIEN KET XUONG -> ANH cua chinh file `.xml` (mang o header 0x4c, xuat ra
## o `parts[].children[].sprites`). Dung chung cho ca ve lan `anh_xuong`.
var _bang_anh := {}

func _anh_cua_xuong() -> Dictionary:
	if not _bang_anh.is_empty():
		return _bang_anh
	for p in _ordered_parts():
		var ten := String(p.get("name", ""))
		if not _bang_anh.has(ten):
			_bang_anh[ten] = (p.get("sprites", []) as Array).duplicate()
	return _bang_anh



# ------------------------------------------------------------------ noi bo

## Bien the dung khi nguoi goi khong chi dinh: nhom MANG DUNG TEN duoc hoi.
##
## Ban goc dung bien the mang dung ten ay — DO, khong suy. Mot file `.xml` chua
## nhieu armature, va bien the mang ten file nam CUOI danh sach nhom o 297/304
## file (do tren `assets/map/*.xml`), nen hai cach chon "hop ly" kia deu sai:
##
##   DaQiao          7 nhom: `DaQiao` CUOI, nhieu dong tac nhat la `DaQiaoReplica`
##                   (nhom thu 2). May ao goi `getSpriteFromSpriteCatch('DaQiao')`
##                   roi `_lua_CollisionSize()` ra **85 x 135** = hop cua nhom
##                   `DaQiao`; `DaQiaoReplica` KHONG co xuong `Collision` nen
##                   "nhieu dong tac nhat" se ra (0, 0).
##   CaiWenJiCircle  6 nhom: nhom DAU la `CaiWenJiCircle_Top` (cung la nhieu dong
##                   tac nhat, khong co `Collision`), `CaiWenJiCircle` CUOI. May
##                   ao ra **875,12 x 523,8** — tuc khong phai nhom dau.
##
## Hai rig nay bac bo ca hai cach chon kia, va chi con lai mot luat khop: khop
## TEN. Do la ham `getSpriteFromSpriteCatch(<ten>)` cua ban goc: ten armature
## quyet dinh, khong phai so dong tac.
##
## Anh huong da do: **45** rig co bien the mang ten file VA no khac nhom nhieu
## dong tac nhat; **12** trong so do co hop cham KHAC HAN nhau giua hai bien the
## (CaiWenJiCircle, CaiWenJiExclusCircle, DaQiao, DebuffPoisoning, DebuffSleep,
## StartCartoon, XSHeTiJiLiuGuanZhang, XSJiYouHeTiJi, XSJieSuoBingZhong,
## XSJieSuoLinTong, XSTaoTieChangJing, XSYuanJunJiaDao).
##
## Ten file khong phai luc nao cung la mot bien the (`Player000.xml` khong co
## nhom nao ten `Player000` — cac nhom la `Player000W03W`...), nen van phai co
## duong lui ve nhom nhieu dong tac nhat.
func _bien_the_cho(want: String) -> String:
	for g in data.get("groups", []):
		if String(g.get("variant", "")) == want:
			return want
	return _richest_variant()


## Bien the co DONG TAC HIEU UNG (`PluginPlay`, hoac bo `Wake*`) — doc thang
## json cua armature, khong dung rig nao. Tra "" khi khong nhom nao co.
##
## VI SAO CAN: khi ten khong phai la mot BIEN THE ma la chinh THU MUC (vd
## `CaiWenJiCircle`), `_bien_the_cho` tra ve `_richest_variant()`, va "nhieu
## dong tac nhat" KHONG phai "nhom hieu ung". Do 2026-09-21: `CaiWenJiCircle`
## duoc chon ra nhom `Born/Death/Standby` — mot con vong tron KHONG chay gi,
## trong khi nhom that cua no chay `Born/PluginPlay/PluginStop`.
static func bien_the_hieu_ung(dir_path: String) -> String:
	var jp := dir_path.path_join(dir_path.get_file() + ".json")
	if not FileAccess.file_exists(jp):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(jp))
	if not (d is Dictionary):
		return ""
	for g in d.get("groups", []):
		for a in g.get("animations", []):
			var n := String(a.get("name", ""))
			if n == "PluginPlay" or n.begins_with("Wake"):
				return String(g.get("variant", ""))
	return ""


## Nhom nhieu dong tac nhat. Chi con dung lam DUONG LUI khi ten file khong phai
## la mot bien the (xem `_bien_the_cho`) va trong `_group()`.
func _richest_variant() -> String:
	var best := ""
	var best_n := -1
	for g in data.get("groups", []):
		var n: int = (g.get("animations", []) as Array).size()
		if n > best_n:
			best_n = n
			best = g.get("variant", "")
	return best


## Nhom dong tac cua bien the. TRANG PHUC (Defender_VampirE, Archer_Dong...) la
## mot BO ANH cho cung bo xuong, KHONG co nhom dong tac rieng: dung dong tac cua
## nhom co ten la TIEN TO dai nhat. Do tren ca assets_ref: 76 bo phan cap cao
## khong co nhom rieng, 75 co nhom goc la tien to; xuong cua trang phuc trung
## xuong ma dong tac nhom goc dieu khien, trung vi 100%. Ca con lai
## (PlayerEquM001 trong PlayerM) lay nhom nhieu dong tac nhat.
##
## Truoc day tra ve rong: linh Defender_VampirE tren san tran KHONG co dong tac
## nao, dung im o anh dau cua moi xuong — ca xuong hieu ung chi loe khi danh —
## thanh mot mang vuot do bam theo ca tran.
func _group() -> Dictionary:
	var gs := {}
	for g in data.get("groups", []):
		gs[String(g.get("variant", ""))] = g
	if gs.has(variant):
		return gs[variant]
	var s := variant
	while s.contains("_"):
		s = s.substr(0, s.rfind("_"))
		if gs.has(s):
			return gs[s]
	var dai := ""
	for k in gs:
		if variant.begins_with(k) and String(k).length() > dai.length():
			dai = k
	if dai != "":
		return gs[dai]
	var giau := _richest_variant()
	return gs.get(giau, {})


## Thu tu ve: lay tu "parts". Bo phan chi xuat hien trong dong tac thi xep sau.
## Tra ve mang {name, sprites} — sprites la danh sach anh do CHINH FILE .xml
## chi dinh cho bo phan do.
func _ordered_parts() -> Array:
	var out: Array = []
	for p in data.get("parts", []):
		if p.get("name", "") == variant:
			out = (p.get("children", []) as Array).duplicate()
			break
	if not CHILDREN_BACK_TO_FRONT:
		out.reverse()
	var seen := {}
	for c in out:
		seen[c.get("name", "")] = true
	for a in _group().get("animations", []):
		for b in a.get("bones", []):
			var bn: String = b.get("name", "")
			if bn != "" and not seen.has(bn):
				seen[bn] = true
				out.append({"name": bn, "sprites": []})
	return out


## Chon anh cho mot bo phan.
##
## Khong doan theo ten. File .xml co san bang LIEN KET XUONG -> ANH (mang o
## header 0x4c), va export.py ghi no ra thanh truong "sprites" cua tung bo
## phan. Doan theo ten se sai voi nhung nhan vat dat ten anh kieu khac:
## CaoCao co "face1", "touguan", "toufa0013_instant", va LeftArm cua no dung
## lai anh "CaoCao_res-RightArm".
##
## Mot bo phan co the tro toi NHIEU anh — Archer/Head co 5 net mat, Effect co
## 6 khung. Moi keyframe chon mot anh bang chi so `d` (xem displays,
## _doi_anh); ham nay tim anh cho MOT ten.
##
## Ten bat dau bang "<Ten>_mc_" khong phai anh ma la MOT RIG LONG NHAU (bien
## the khac trong cung file). Chua rap duoc, tam bo qua — xem nested_rigs.
func _sprite_for(refs: Array) -> Dictionary:
	var files: Dictionary = data.get("spriteFiles", {})
	for r in refs:
		var key := String(r)
		if files.has(key) and files[key] != null:
			return files[key]
		if files.has(key + ".png") and files[key + ".png"] != null:
			return files[key + ".png"]
	return {}


## Ten bien the ma bo phan nay tro toi, neu do la mot rig long nhau.
##
## Quy tac la CO MOT BIEN THE TRUNG TEN trong file, chu khong phai ten co chua
## "_mc_". Phan lon rig long nhau ten kieu <Ten>_mc_Head that, nhung khong phai
## tat ca: ZhangLiao_EquipJian_2, JiaXu_EquipJian_2, ZhuGeLiangYoung_Base_Zhang
## deu la bien the that ma khong mang dau do — doi dung "_mc_" thi ba tuong ay
## mat vu khi.
##
## Goi sau _sprite_for() nen neu mot ten vua la anh vua la bien the thi anh
## duoc uu tien.
func _nested_variant(refs: Array) -> String:
	for r in refs:
		var key := String(r)
		if _chain.has(key):
			continue
		for p in data.get("parts", []):
			if p.get("name", "") == key:
				return key
	return ""


func _is_clutter(bone: String) -> bool:
	# Ngoai le xet TRUOC: `Logic_Body` khop ca `Logic_` lan chinh no, nen phai
	# chua truoc khi xet tien to — xem CLUTTER_NGOAI_LE.
	for e in CLUTTER_NGOAI_LE:
		if bone.begins_with(e):
			return false
	for p in CLUTTER_PREFIXES:
		if bone.begins_with(p):
			return true
	return false


func _is_marker(bone: String) -> bool:
	for p in MARKER_PREFIXES:
		if bone.begins_with(p):
			return true
	return false


func _load_texture(rel: String) -> Texture2D:
	return nap_anh(source_dir.path_join(rel))


## Nap anh theo duong dan res:// bat ky (rig dung cho anh cua chinh no, bong
## dung cho anh dung chung nam ngoai thu muc rig).
func nap_anh(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is Texture2D:
			return res
	# Chua qua buoc import cua Godot, hoac nam ngoai res:// — doc thang file.
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


func _make_sprite(info: Dictionary, ten_anh: String = "") -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = _load_texture(info.get("png", ""))
	spr.centered = true
	var w_anh := 0.0
	var h_anh := 0.0
	if spr.texture != null:
		w_anh = float(spr.texture.get_width())
		h_anh = float(spr.texture.get_height())

	# NEO CUA CHINH ANH AY nam tren goc xuong — luat cua ban goc.
	#
	# Ban goc khai neo theo tung anh o `+0x08` cua ban ghi tham chieu sprite
	# (`anim.py:sprite_anchors` -> khoa `spriteAnchors` trong JSON). Do tren 397
	# file .xml: neo la thuoc tinh cua ANH chu khong cua xuong — 15.237/15.238
	# ten anh khai CUNG mot neo o moi rig dung chung (ngoai le duy nhat:
	# `ZhaoYun_Eff-Line_instant`), va 12.761/12.957 (98,5%) neo nam gon trong o
	# anh cua no.
	#
	# Luat cu (canh day anh nam tren goc xuong) lam neo cua chinh anh trung goc
	# xuong chi 2.977/27.948 cap xuong->anh (10,7%; rieng rig nhan vat
	# 1.232/6.434 = 19,1%), lech trung vi -26,0 px. No cung la ly do tay cam
	# lech khoi cho cam: `EquipQin_res-EquipQin_5_client` (104x137, neo
	# 53,68/77,76) bi day thap hon cho cam 59,24 px, trong khi neo roi dung
	# 77,76/137 = 57% chieu cao anh, tuc GIUA cay dan.
	#
	# Neo ke tu goc TRAI-TREN cua o anh; `centered = true` dat TAM anh o goc
	# xuong, nen day tam di dung do lech tu tam toi neo.
	var neo: Array = data.get("spriteAnchors", {}).get(ten_anh, [])
	if neo.size() == 2 and w_anh > 0.0 and h_anh > 0.0:
		var ay := float(neo[1])
		if FLIP_Y:
			ay = h_anh - ay
		spr.offset = Vector2(w_anh / 2.0 - float(neo[0]), h_anh / 2.0 - ay)
		return spr

	# Duong lui khi anh khong co ban ghi neo (JSON cu, hoac ten khong nam trong
	# ban ghi tham chieu nao).
	#
	# offX/offY la do lech tam anh so voi tam khung goc, theo dung nghia
	# "offset" cua plist Cocos2d. Phan lon bang 0 nhung co the len toi 78 px;
	# bo qua thi cac manh to nam lech han.
	#
	# TRU h/2: `centered = true` dat TAM anh o goc xuong, nhung ban goc dat
	# CANH DAY anh o goc xuong (xem `_add_track` — y cua track la v3, tuc canh
	# day). Thieu ve tru nay thi anh nao cang cao cang nhic len xa: do tren
	# DefenderN, dau/hat (h~50) leo ~2x xa hon than (h=21) nen than bi chon
	# trong dau — do duoc: hop Body [-56.5,-35.5] nam TRON trong hop HatBG
	# [-66.5,-17.5], ma HatBG ve SAU. Tru di thi hai hop khop nhau 1 px.
	spr.offset = Vector2(float(info.get("offX", 0.0)),
			(-float(info.get("offY", 0.0)) if FLIP_Y else float(info.get("offY", 0.0))) - h_anh / 2.0)
	return spr


## Moi xuong -> danh sach CAC THU NO CO THE HIEN, dung thu tu bang lien ket
## xuong -> anh cua file (header 0x4c): Sprite2D, SngRig long nhau, hoac null
## (anh khong co trong atlas). Keyframe chon mot o bang chi so `d` (anim.py,
## +0x2C cua khung); -1 la an. Truoc day moi xuong chi co anh DAU TIEN va hien
## suot — hieu ung chi loe vai khung (eff010 cua Player000 khi Fight) thanh ra
## bam theo nhan vat ca tran.
var displays: Dictionary = {}


func _build_bones() -> void:
	for part in _ordered_parts():
		var bone: String = part.get("name", "")
		if hide_clutter and _is_clutter(bone):
			continue
		var refs: Array = part.get("sprites", [])
		var node: Node2D = null
		var ds: Array = []
		if not _is_marker(bone):
			# KHUNG xuong: mang bien doi cua xuong; cac thu co the hien la con.
			node = Node2D.new()
			var co := false
			for r in refs:
				var d := _display_for(String(r), bone)
				ds.append(d)
				if d != null:
					d.visible = false
					node.add_child(d)
					co = true
			if not co:
				missing_sprites.append(bone)
		if node == null:
			node = Marker2D.new()
		node.name = bone
		# THU TU VE lay tu THU TU CON, khong tu `z_index`. `_ordered_parts()` da
		# tra ve dung thu tu ve (CHILDREN_BACK_TO_FRONT), nen `add_child` theo
		# thu tu ay la du — va la duy nhat dung.
		#
		# Vi sao KHONG duoc dat `z_index = i` nhu truoc: `z_index` cua Godot la
		# so HIEU DUNG TRONG CA CANVAS (cong don tu moi to tien), khong phai so
		# tuong doi trong rig nhu zOrder cua Cocos. Do duoc tren man Main: 1378
		# node mang z hieu dung khac 0, TAT CA la xuong armature — va vi chung
		# nam trong lop thanh pho nen chung ve DE LEN CA THANH CONG CU (o icon
		# `tag=2` bi che 5329/5340 diem anh). Nang `lMainToolbarRightButton`
		# len `z_index = 2000` thi thanh cong cu hien ra du 5/5 o — tuc thu pham
		# dung la `z_index` nay.
		add_child(node)
		bones[bone] = node
		displays[bone] = ds
		# Chua dong tac nao chon thi hien o dau, nhu truoc.
		_dat_khung(bone, 0)


## Mot thu co the hien cua xuong: anh trong atlas, hoac CA MOT RIG KHAC nam
## trong cung file — dau cua CaoCao, than cua ZhuGeLiang deu vay. Rig long nhau
## dung de quy va chay dong tac dau cua no.
##
## Anh duoc UU TIEN khi mot ten co o ca hai bang (xem `_nested_variant`).
func _display_for(ref: String, bone: String) -> Node2D:
	if not _sprite_for([ref]).is_empty():
		return o_hien(ref, bone, true)
	return o_hien(ref, bone, false)


## Dung mot thu HIEN DUOC tu TEN cua no trong file, de thay vao o cua mot xuong.
##
## Moi ten trong .xml chi thuoc MOT trong hai bang, va ban goc cung tach dung
## hai duong ay — do la ly do co HAI ham rieng
## (`_lua_changeTextureDisplay` 0x2aa81e / `_lua_changeArmtureDisplay` 0x2aa87a,
## hai ham nam ngay canh nhau va than giong het nhau, chi khac cho chung goi
## `[vtable+0x280]` hay `[vtable+0x284]` cua doi tuong armature):
##
##   chi_anh = true   ten la ANH trong atlas (`UIWoYaoShenJiang_res-Num3`,
##                    `UIZhuangBeiWuHun_Res-300T`)
##   chi_anh = false  ten la MOT BIEN THE cua chinh file .xml do
##                    (`UIWoYaoShenJiang_Base_Light`) — rig long nhau
##
## Tra ve null khi khong co trong bang ay — va do la duong AN mot xuong ma ban
## goc dang dung: `UIWoYaoShenJiang_res-44` la anh 4x4 rong, va bang lien ket
## cua chinh file ay cho `PlugIn_1..6` + `LayerName000` deu tro toi no.
##
## `bone` chi de ghi so `nested_rigs` (nhu `_display_for`), khong dung vao viec
## dung node.
func o_hien(ten: String, bone: String, chi_anh: bool) -> Node2D:
	if chi_anh:
		var info := _sprite_for([ten])
		if info.is_empty():
			return null
		return _make_sprite(info, ten)
	var nested := _nested_variant([ten])
	if nested == "":
		return null
	# Tham so cuoi (hide_clutter) luon la false: KHONG truyen bo loc xuong rig
	# long nhau — xem chu thich o CLUTTER_PREFIXES.
	var child := _make(data, source_dir, nested, nested, _chain, false)
	if child == null:
		return null
	var names := child.animations()
	if not names.is_empty():
		child.player.play(names[0])
	if bone != "" and not nested_rigs.has(bone):
		nested_rigs.append(bone)
	return child


## Thay thu dang hien o o `idx` cua xuong `bone` bang `node`; `node` = null thi
## o do thanh RONG.
##
## Ban goc KHONG them mot o moi: no THAY the phan tu `idx` trong danh sach hien
## cua xuong (vtable +0x280 / +0x284). Nen o chi so `d` cua cac khung sau do —
## ca khung chua chay lan khung dang chay — deu lay dung node vua thay. Do la y
## cua tro: CUIShakeDice doi mat xuc xac bang cach thay anh o mot o, roi de dong
## tac chay tiep.
##
## O vuot bang thi NOI RONG bang `null` (khac `_dat_khung` — ham do COI chi so
## ngoai bang la 0 vi do la du lieu khung hong). O `idx` am thi bo qua.
func thay_o_hien(bone: String, node: Node2D, idx: int) -> bool:
	if idx < 0 or not displays.has(bone):
		return false
	var xuong: Node2D = bones.get(bone)
	if xuong == null:
		return false
	var ds: Array = displays[bone]
	while ds.size() <= idx:
		ds.append(null)
	var cu = ds[idx]
	if cu != null and is_instance_valid(cu):
		xuong.remove_child(cu)
		cu.queue_free()
	ds[idx] = node
	if node != null:
		node.visible = false
		xuong.add_child(node)
	# Doi HIEN/AN bang tay chu khong goi `_dat_khung`: ham do con dat lai CACH
	# TRON cua ca xuong theo tham so, ma o day khong biet khung nao dang chay.
	for i in ds.size():
		if ds[i] != null and is_instance_valid(ds[i]):
			ds[i].visible = i == idx
	return true


## Bien the nay co phai CANH khong.
##
## Canh la mot armature RIENG (`EquipWing_01`, `EquipWing_11`… — 63 bien the
## trong `assets_ref/EquipWing`), khong phai mot xuong cua nhan vat. Dong tac
## cua no dung ten `Standby` / `Run` / `Death` / `Fire` / `Hit`, va
## `CUIArmyGroupCampsite.lua:1797,1799` goi dung `Death` / `Standby` — nen phep
## kiem nay chon dung thu ma `_Lua_changeWingAnimation` can.
##
## Duong GAN canh da CO trong ban dung: ban goc gan bang ham toan cuc
## `setGear(pRole, ten)` (`ClientPaperDoll:ChangePaperDollHelper` goi no cho tung
## muc cua `tSkinMap`, ke ca `HeroSkinType.Wing = "Wing"`), va ban dung da lam ham
## ay (`lua/bootstrap.lua:591` -> `LuaRuntime._godot_dat_do` -> `dat_do` ngay
## duoi). Quet `sc/`: **10 cho goi THAT** (11 dong chua chu "setGear", mot dong bi
## chu thich), **3 cho truyen thang ten canh** — `CUIActivityScoreStroe.lua:25`
## (`"wing_1_2"`), `CUIWing.lua:1403`, `CUIWingShow.lua:248`
## (`string.format("wing_%d_%d", …)`) — va 17 muc `loai: "Wing"` cua bang do deu
## la `kieu: "node_con"` voi `sPropertyName` = `EquipWing_*`, tuc dung kieu ma
## `_dat_node_con` gan duoc. Nen ham nay tra true ngay khi co man nao gan canh.
##
## Cho KHONG mo hinh duoc la con tro rieng cua ban goc: bon cho ghi
## `this[+0x9fc]` deu nam trong C++ va khong co trong bang bind Lua nao — ban dung
## tim canh trong cay con thay vi qua con tro.
func la_canh() -> bool:
	return variant.begins_with("EquipWing")


## Dem so lan `dat_do` CO tac dung / KHONG lam duoc gi. Phai dem chu khong the
## nhin: ban goc goi `setGear` qua lop gia lap, ham thieu thi `__index` tra ve
## mot ham cho MOI ten nen loi goi di vao hu khong va KHONG mot dong loi.
var so_lan_dat_do := 0
var so_lan_truot := 0
## Ten nhung mon "chua lam duoc" (kieu 1/3/5, hoac thieu du lieu) — de phep
## kiem doc ra duoc LY DO, khong chi mot con so.
var chua_lam: PackedStringArray = []
## Node con da gan cho kieu 4 (canh / mount), theo `sPropertyName`, de lan goi
## sau THAY cai cu chu khong chong them.
var _do_node_con: Dictionary = {}


## Dung rig TU MOT TEN armature khac file — `getSpriteFromSpriteCatch(<ten>)`
## cua ban goc. Ten co the la BIEN THE nam trong file khac ten (`EquipQin_1`
## trong `EquipQin.json`, `Player004M03F` trong `Player004.json`), nen cat dan
## duoi de tim thu muc.
##
## Vi sao khong dung `LuaRuntime._tao_rig`: ham do boc rig trong mot `Control`
## mang ti le 1,02 va dem vao hai bo dem cua runtime — dung cho node roi tren
## man Lua, sai cho mot rig nam TRONG mot rig khac (o day rig cha da mang ti le
## cua no). Cung mot luat cat duoi, hai cho dung khac nhau.
static func theo_ten(ten: String) -> SngRig:
	var r := tim_thu_muc(ten)
	if r[0] == "":
		return null
	return build(r[0], r[1], false)


## Dat mot mon do len rig nay bang TEN cua no, theo dung bang
## `map/gear_config.xml` (xem `rig/gear_ref.gd` cho nam loai muc va so do).
##
## Ban goc: `setGear(pRole, ten)` — ham TOAN CUC, 10 cho goi THAT trong `sc/`,
## goi tu `ClientPaperDoll:ChangePaperDollHelper`. Nam viec, do tu file bang:
##
##   kieu 2  doi ARM cua khop `sBone` bang armature `sArmtureName`  — vu khi
##   kieu 4  doi NODE CON bang `sPropertyName`                      — canh / mount
##   kieu 1  doi texture cua khop `sBone` bang `sTextureName`
##   kieu 3  doi he hat        — KHONG muc nao trong bang
##   kieu 5  doi vu khi nem    — KHONG muc nao trong bang
##
## Va khi ten KHONG co trong bang thi luat DU PHONG cua chinh file, HAI nhanh:
## `<arm>_<xuong>_lv<N>` -> doi texture `<arm>_res-<xuong>_lv<N>` tren xuong
## `<xuong>`; `<arm>_<xuong>_Hide` -> AN xuong `<xuong>`.
##
## Tra true khi co it nhat mot thay doi that. Dem vao `so_lan_dat_do` /
## `so_lan_truot` — chu KHONG im lang, va ghi `chua_lam` khi gap kieu chua lam.
func dat_do(ten: String) -> bool:
	return _dat_do(ten, {})


func _dat_do(ten: String, da_di: Dictionary) -> bool:
	if ten == "" or da_di.has(ten):
		return false
	da_di[ten] = true

	var m := GearRef.muc(ten)
	if m.is_empty():
		return _dat_do_du_phong(ten, da_di)

	# Do chuyen tiep: `Witch_lv7` -> `sBaseItem Witch_lv6`; muc LIST chon theo
	# cap (`equip_Exclusive_10_List` -> `sGear_lv5plus`). `setGear` khong truyen
	# cap nen nhanh LIST khong voi toi — di tiep sang muc goc.
	var tiep := GearRef.chuyen_tiep(ten)
	if tiep != "":
		return _dat_do(tiep, da_di)

	# BUNDLE: ten don vi + cap (`DefenderN_lv1`) -> danh sach ten do con. Duong
	# nay thuoc `setLevelGear` (3 cho goi THAT trong `sc/`: `CUIBarracksMain.lua:1036`,
	# `CUIBarracksArmyInfo.lua:272`, `CUIPopUpBox.lua:723`).
	if GearRef.la_bundle(ten):
		var co := false
		for con in GearRef.ls_gear(ten):
			if _dat_do(String(con), da_di):
				co = true
		return _dem(ten, co, "")

	# PARTS: bang RIENG `<Parts>` (14 muc). `nPartsType` dung lai bo ma cua
	# `nShowType`, va `nPartsType 1` o day chinh la ket qua cua luat du phong —
	# nen nhanh nay va nhanh du phong phai cho ra CUNG mot ket qua.
	#
	# KHONG duoc lui ve `_dat_do(p)`: ten `<Parts>` khong bao gio la ten `<Gear>`
	# (`SpearmenN_Spear_lv1_Throw` khong co muc nao trong bang), nen loi goi ay
	# LUON roi xuong du phong — do ra mot xuong `Spear` va mot texture
	# `SpearmenN_res-Spear_lv1_Throw` khong co, tuc mot phep thu sai, va no con
	# ghi ten ay vao `chua_lam` lan thu nhat (lan thu hai do dong `else` cu).
	# Nay moi muc `<Parts>` di theo DUNG `nPartsType` cua no, va ghi dung MOT lan.
	var ls := GearRef.ls_parts(ten)
	if not ls.is_empty():
		var co := false
		for p in ls:
			var tp := String(p)
			var q := GearRef.part(tp)
			if q.is_empty():
				_dem(tp, false, "muc <Parts> khong co trong bang")
				continue
			var kp := int(q.get("nPartsType", 0))
			if kp == GearRef.KIEU_TEXTURE:
				if _dem(tp, _dat_texture(tp, String(q.get("sBone", "")),
						String(q.get("sTextureName", ""))), ""):
					co = true
			else:
				# Kieu 5 (`_Throw`): doi VU KHI NEM — ban dung chua lam, va trong
				# bang khong co muc `<Gear>` nao kieu 5. Ghi ra chu khong im lang.
				_dem(tp, false, "kieu %d (%s) chua lam"
						% [kp, GearRef.KIEU_TEN.get(kp, "?")])
		return _dem(ten, co, "")

	# LIST: chon do theo CAP. `chuyen_tiep` o tren da thu roi, nhung cap = 0 nen
	# no khong chon duoc — va do cung la duong DUY NHAT toi 6 muc dang nay. Phai
	# ghi ra TRUOC nhanh cuoi, khong thi loi bao la "kieu 0 (?)" — ma kieu 0
	# nghia la "ten khong co muc nao trong bang", trong khi muc thi CO.
	if GearRef.la_list(ten):
		return _dem(ten, false, "muc LIST: thieu cap de chon")

	var kieu := GearRef.kieu(ten)
	if kieu == GearRef.KIEU_ARMATURE:
		return _dem(ten, _dat_armature(ten), "")
	if kieu == GearRef.KIEU_NODE_CON:
		return _dem(ten, _dat_node_con(ten), "")
	if kieu == GearRef.KIEU_TEXTURE:
		var ok := _dat_texture(ten, GearRef.xuong(ten),
				String(m.get("sTextureName", "")))
		return _dem(ten, ok, "")

	# Kieu 3 (hat) va 5 (nem): khong muc nao trong bang, va ban dung chua lam.
	# Ghi ra chu khong tra `false` im lang.
	var ly := "kieu %d (%s) chua lam" % [kieu, GearRef.KIEU_TEN.get(kieu, "?")]
	return _dem(ten, false, ly)


func _dem(ten: String, co: bool, ly: String) -> bool:
	if co:
		so_lan_dat_do += 1
	else:
		so_lan_truot += 1
		chua_lam.append(ten if ly == "" else "%s (%s)" % [ten, ly])
	return co


## Kieu 2: THAY o hien cua xuong `sBone` bang mot rig dung tu `sArmtureName`.
##
## O bi thay la o 0 — do la o dang hien anh MAC DINH cua armature (do duoc:
## xuong `Weapon` cua `Player000` mang san `Player000_Eff-EquipQin_5`, cap 5,
## trong khi du lieu noi cap 0). Doi o 0 nen lan goi sau THAY cai truoc.
func _dat_armature(ten: String) -> bool:
	var bone := GearRef.xuong(ten)
	if bone == "" or not displays.has(bone):
		return false
	var dich := GearRef.armature(ten)
	if dich == "":
		return false
	# Kieu `SngRig` chu khong `Node2D`: `theo_ten` tra ve `SngRig`, va de kieu
	# rong thi `node.animations()` la loi goi DONG (khong suy duoc kieu tra ve)
	# nen `:=` khong dich duoc — do la mot loi BIEN DICH, khong phai loi chay.
	var node: SngRig = null
	if not GearRef.trong(ten):
		node = theo_ten(dich)
		if node != null:
			var ten_dong := node.animations()
			if not ten_dong.is_empty():
				node.player.play(ten_dong[0])
	return thay_o_hien(bone, node, 0)


## Kieu 1 (va 179/201 ten la cua duong du phong): THAY o 0 cua xuong bang anh
## `texture` — anh trong CHINH atlas cua rig nay (`SpearmenN_res-Spear_lv1`), nen
## tra qua `o_hien(..., true)`, khong phai dung rig khac.
func _dat_texture(ten: String, bone: String, texture: String) -> bool:
	if bone == "" or texture == "" or not displays.has(bone):
		return false
	var node := o_hien(texture, bone, true)
	# Anh khong co trong atlas: thieu du lieu, KHONG phai lenh an. Duong an di
	# rieng (`_Hide` -> `thay_o_hien(bone, null, 0)`), nen o day tra `false` la
	# dung — va nho vay phep kiem bat duoc ten texture sai.
	if node == null:
		return false
	return thay_o_hien(bone, node, 0)


## Kieu 4: node con cua CHINH rig (canh, mount). Khong co `sBone` trong bang —
## ban goc gan vao node goc chu khong theo xuong, nen o day gan vao chinh rig.
func _dat_node_con(ten: String) -> bool:
	var thuoc := GearRef.node_con(ten)
	if thuoc == "":
		return false
	var cu = _do_node_con.get(thuoc)
	if cu != null and is_instance_valid(cu):
		remove_child(cu)
		cu.queue_free()
		_do_node_con.erase(thuoc)
	var node := theo_ten(thuoc)
	if node == null:
		return false
	var ten_dong := node.animations()
	if not ten_dong.is_empty():
		node.player.play(ten_dong[0])
	add_child(node)
	_do_node_con[thuoc] = node
	return true


## LUAT DU PHONG — ten khong co muc nao trong bang. Hai nhanh, ca hai deu duoc
## CHINH FILE xac nhan: bang `<Parts>` khai tuong minh ket qua cua nhanh texture
## (7/7 muc `nPartsType 1` trung khit cong thuc nay).
func _dat_do_du_phong(ten: String, _da_di: Dictionary) -> bool:
	var r := GearRef.du_phong(ten)
	if r.is_empty():
		return _dem(ten, false, "ten khong tach duoc, khong co trong bang")
	if r.get("kieu", "") == "an":
		# `_Hide`: AN xuong. `thay_o_hien(bone, null, 0)` la duong an that —
		# o do thanh rong, va `_dat_khung` se an ca xuong.
		return _dem(ten, thay_o_hien(String(r["xuong"]), null, 0), "")
	return _dem(ten, _dat_texture(ten, String(r["xuong"]),
			String(r.get("texture", ""))), "")


## Hien o thu `idx` cua xuong, an cac o khac; -1 an het. Chi so ngoai bang
## (BingYing.xml, XSJiYouHeTiJi.xml — bo cuc khung khac, xem anim.py) thi giu
## o dau nhu cach cu, khong doan.
##
## Dat luon CACH TRON cua khung: vat lieu gan vao TUNG Sprite2D dang hien.
##
## KHONG gan len node xuong: vat lieu cua node CHA khong truyen xuong Sprite2D
## con trong Godot 4 — do bang diem anh that (`tools/do_tron.gd`: Sprite2D xam
## 0.392 tren nen 0.235 ra dung 0.3882 khi node cha mang vat lieu ADD, y het luc
## khong co vat lieu; gan truc tiep len Sprite2D thi ra 0.6235 = 0.235+0.392).
## Gan len node xuong thi phep thu van xanh ma man hinh khong doi mot diem anh
## nao — dung cai bay da mac.
##
## Bo phan la mot rig long nhau (dau CaoCao, than ZhuGeLiang) thi BO QUA: rig
## con co khung rieng cua no, dat de len la hai ben gianh nhau. Do tren ca
## assets_ref: khong xuong nao vua la rig long nhau vua co khung 'screen'.
func _dat_khung(bone: String, idx: int, blend := "") -> void:
	_dat_tron(bone, blend)
	var ds: Array = displays.get(bone, [])
	if ds.is_empty():
		return
	if idx < -1 or idx >= ds.size():
		idx = 0
	for i in ds.size():
		if ds[i] != null:
			ds[i].visible = i == idx


## Vat lieu cho mot ten cach tron. MIX tra ve null (mac dinh cua Godot, khong
## gan gi) de cay node khong phai mang them vat lieu nao.
func _vat_lieu_theo(ten: String) -> CanvasItemMaterial:
	if ten != BLEND_CONG:
		if ten == "multiply" and not _da_canh_bao_multiply:
			_da_canh_bao_multiply = true
			push_warning(("SngRig: khung mang cach tron 'multiply' — ban goc dung "
					+ "(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA), Godot khong co che do "
					+ "tuong ung nen ve tam bang MIX. Chua tung gap trong du lieu "
					+ "goc; gap thi phai viet shader rieng."))
		return null
	if _vat_lieu_cong == null:
		_vat_lieu_cong = CanvasItemMaterial.new()
		_vat_lieu_cong.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _vat_lieu_cong


func _dat_tron(bone: String, ten: String) -> void:
	var vat := _vat_lieu_theo(ten)
	for d in displays.get(bone, []):
		if d is Sprite2D:
			(d as Sprite2D).material = vat


func _build_animations() -> void:
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	var lib := AnimationLibrary.new()

	for a in _group().get("animations", []):
		var anim := Animation.new()
		var frames: int = int(a.get("frames", 1))
		var dur: int = int(a.get("duration", frames))
		# Do dai tinh bang khung; khung cuoi van phai duoc hien nen dung dur.
		anim.length = maxf(float(dur), 1.0) / FPS
		anim.loop_mode = Animation.LOOP_LINEAR if a.get("loop", false) else Animation.LOOP_NONE

		# Moi dong tac chi dung MOT PHAN bo phan. Vd Archer khi Standby thi
		# khong co Arrow / Effect / Effect2 — dung ra la phai an chung di.
		# Neu de nguyen, chung nam lai o goc toa do (duoi chan nhan vat) va
		# hien ra lo lo: mui ten nam duoi dat.
		var used := {}
		for b in a.get("bones", []):
			used[b.get("name", "")] = true
		for bone_name in bones:
			var t_vis := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(t_vis, NodePath("%s:visible" % bone_name))
			anim.value_track_set_update_mode(t_vis, Animation.UPDATE_DISCRETE)
			anim.track_insert_key(t_vis, 0.0, used.has(bone_name))

		for b in a.get("bones", []):
			var bone: String = b.get("name", "")
			if not bones.has(bone):
				continue
			# Doi anh theo khung: MOT duong goi _dat_khung cho MOI xuong. Dung
			# chung mot duong thi hai xuong co keyframe cung luc se ghi de nhau
			# (track_insert_key cung thoi diem thay khoa cu) — do duoc: Standby
			# cua nhan vat dau tien con 537/675 khoa.
			var t_anh := anim.add_track(Animation.TYPE_METHOD)
			anim.track_set_path(t_anh, NodePath("."))
			var t_pos := _add_track(anim, bone, "position")
			var t_rot := _add_track(anim, bone, "rotation")
			var t_scl := _add_track(anim, bone, "scale")
			# Keyframe BAT DAU o tong so khung giu cua cac keyframe truoc no
			# (dur, +0x40 cua khung — xem anim.py). Truoc day moi keyframe cach
			# nhau dung 1 khung: Weapon/Walk cua Player000 giu 3,3,3,2,1 khung
			# ma bi don vao 5 khung dau. JSON cu chua co dur thi van 1 khung.
			# Chi tin dur / d khi dung bat bien DO DUOC: xuong >= 2 keyframe thi
			# tong dur = do dai dong tac (95.416 / 95.431 xuong, anim.py). 15 xuong
			# sai deu o BingYing.xml — bo cuc khung khac, dur va d o do la rac —
			# thi quay ve cach cu: moi keyframe 1 khung, anh dau.
			var ks: Array = b.get("keys", [])
			var tong := 0
			for k in ks:
				tong += int(k.get("dur", 0))
			var tin := ks.size() < 2 or tong == dur or tong == frames
			var f := 0
			for k in ks:
				var t := float(f) / FPS
				f += maxi(1, int(k.get("dur", 1))) if tin else 1
				# v3 (khong phai y) la CANH DAY cua o anh: v2/v3 la cap da hieu
				# chinh diem neo (`ax, ay` +0x20 cua khung — anim.py khong xuat
				# hai truong do nhung da cong vao v2/v3). Do tren DefenderN:
				# Body co diem neo DUY NHAT khac 0 (ay = -24) nen y=-45.40 ma
				# v3=-21.00; dung `y` thi Body roi vao [-66,-45] tuc van nam
				# trong dau, dung `v3` moi ra [-42,-21] va khop duoi dau 1 px.
				var y: float = float(k.get("v3", k.get("y", 0.0)))
				var r: float = float(k.get("rot", 0.0))
				anim.track_insert_key(t_pos, t, Vector2(
						float(k.get("x", 0.0)), -y if FLIP_Y else y))
				anim.track_insert_key(t_rot, t, deg_to_rad(-r if NEGATE_ROT else r))
				anim.track_insert_key(t_scl, t, Vector2(
						float(k.get("sx", 1.0)), float(k.get("sy", 1.0))))
				anim.track_insert_key(t_anh, t,
						{"method": "_dat_khung", "args": [bone,
							int(k.get("d", 0)) if tin else 0,
							String(k.get("blend", ""))]})

		lib.add_animation(a.get("name", "?"), anim)

	player.add_animation_library("", lib)
	player.root_node = NodePath("..")


func _add_track(anim: Animation, bone: String, prop: String) -> int:
	var idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath("%s:%s" % [bone, prop]))
	anim.value_track_set_update_mode(idx, Animation.UPDATE_CONTINUOUS)
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	return idx


# ------------------------------------------------------------------ bong

## Bong duoi chan. Ban goc KHONG dung san: `_ShowShadow(true)` moi TAO
## (`libgame.so` 0x419f74 → 0x419de6, goi 0x419668 truoc tien), con
## `_ShowShadow(false)` thi XOA HAN va quen di (0x417e14:
## `removeFromParentAndCleanup(true)` + `release()` + `self[0xa04] = 0`) — lan
## `true` sau do tao lai tu dau. Do la ly do 20 cho goi trong ma goc deu la
## bat/tat han chu khong phai chinh do dam.
##
## So do: `battle/bong_ref.gd` (ti le + do dam) va anh dung chung
## `assets_ref/bong/Shadow.png` (164x22) — duong tao bong cua engine cung nap
## thang mot chuoi "Shadow.png" (0x7beccd) chu khong theo ten sprite.
var bong: Sprite2D = null

## zOrder cua bong trong ban goc: do duoc -10 (`0x419de6` sap lai bong ve -10 truoc
## khi hien). zOrder cua Cocos la so TUONG DOI trong node cha, nen -10 chi co nghia
## "ve truoc moi xuong" — khong phai mot so tuyet doi nao.
##
## Ban dung khong co hang so nay: thu tu ve lay tu THU TU CON (`move_child(bong, 0)`
## trong `_tao_bong`), dung mot luat voi `_build_bones`. Ly do y het o do: `z_index`
## cua Godot la so HIEU DUNG TRONG CA CANVAS, nen dat -10 cho bong cua mot rig nam
## trong lop thanh pho se keo CA RIG xuong duoi moi node z=0 cua lop UI — do duoc
## tren man Main: 1378 node mang z hieu dung khac 0, TAT CA la xuong armature.

var _bong_dong_bo_y := true
var _da_canh_bao_bong := false


func co_bong() -> bool:
	return bong != null


## `_ShowShadow(co)`. `co` gian thi xoa bong; `co` that thi tao (neu chua co),
## sap ve z -10 va hien.
func hien_bong(co: bool) -> void:
	if not co:
		if bong != null:
			bong.queue_free()
			bong = null
		return
	if bong == null and not _tao_bong():
		return
	# Do lai: 0x419de6 chi sap lai va hien khi CHINH armature dang hien VA bong
	# dang an (`self visible && !shadow visible`). Armature an thi bong o lai
	# trang thai an — no VAN duoc tao, vi cua kiem ay nam sau buoc tao.
	if not visible or bong.visible:
		return
	# Khong dung `z_index`: xem chu thich dau `Z_BONG` (nay la chu thich, khong con
	# la hang so). Bong da nam o VI TRI CON dau tien tu `_tao_bong` nen no ve truoc
	# moi xuong — dung cai ma zOrder -10 cua ban goc dien ta.
	_dat_bong_y()
	bong.visible = true


## `_SetSyncShadowPosY(co)`: co bat thi bong bam theo Y cua armature.
##
## Do duoc: `shadow[0x1a6] = tobool(co, 1)` (0x417df9) — KHONG tim thay cho doc
## co ay trong `.text`, va lan goi `false` duy nhat cua ma goc
## (`CUIArmyGroupCampsite.lua:738`) di ngay sau `_ShowShadow(false)`, tuc bong da
## bi xoa. Nen nhanh `false` khong quan sat duoc o ban goc; o day hieu la "thoi
## cap nhat Y" va ghi lai la DAT.
func dong_bo_bong_y(co: bool) -> void:
	_bong_dong_bo_y = co
	_dat_bong_y()


## `_UpdateShadowPosY()` — ma goc goi 0 lan trong Lua, nhung ham co that:
## 0x417ddc truyen hang so -1,0 xuong `setShadowPosY`, va -1,0 la sentinel nghia
## "lay Y cua chinh armature" (`0x417d9e` doc `vtbl[0x78]()+4`), roi di de quy
## xuong cac con (0x3c93c0).
func cap_nhat_bong_y() -> void:
	_dat_bong_y()
	for r in find_children("", "SngRig", true, false):
		if r != self:
			r.cap_nhat_bong_y()


## Bong nam tai GOC cua rig. Ban goc lay x cua armature va Y mat dat
## (`self+0x49c`), con duong `_UpdateShadowPosY` thi dung thang Y cua armature.
## Goc cua rig trong ban dung CHINH LA cho dat chan, nen Y = 0 — day la cho DUY
## NHAT phai suy: truong +0x49c duoc ghi luc dat armature xuong dat, khong co
## hang so nao trong `.text` de doi chieu.
func _dat_bong_y() -> void:
	if bong == null or not _bong_dong_bo_y:
		return
	bong.position = Vector2.ZERO


## Tao bong lan dau. Neo (0.5, 0.5) va ti le/anh lay theo so do cua ban goc
## (xem chu thich dau `battle/bong_ref.gd`).
func _tao_bong() -> bool:
	var tex := nap_anh(BongRef.ANH)
	if tex == null:
		if not _da_canh_bao_bong:
			_da_canh_bao_bong = true
			push_warning(("SngRig: chua co %s — xuat bang: python "
					+ "../brave-cross/work/bong_ref.py --anh assets_ref/bong")
					% BongRef.ANH)
		return false
	var ten := _ten_armature()
	var s := Sprite2D.new()
	s.name = "Bong"
	s.texture = tex
	s.centered = true
	s.scale = Vector2.ONE * BongRef.ti_le(ten)
	s.modulate.a = BongRef.do_mo(ten)
	s.visible = false
	add_child(s)
	# VE TRUOC MOI XUONG, bang vi tri con chu khong bang `z_index` — xem chu thich
	# dau `Z_BONG`. Day la cho thay the cho `z_index = -10` cua ban dung truoc.
	# `_build_bones` da chay xong truoc khi tao bong (bong tao o lan `hien_bong`
	# dau tien, con xuong tao ngay trong `build`), nen chi so 0 la duoi tat ca.
	move_child(s, 0)
	bong = s
	return true


# --------------------------------------------------------------- tieng dong

## Tieng theo KHUNG HOAT DONG cua `sound_config.xml` (xem game/tieng_dong.gd).
##
## Ban goc phat chung o tang C++ khi armature chay toi khung, khong qua Lua —
## nen khong co duong nao "chay ma goc" cho phan nay.
##
## Gan vao `AnimationPlayer.animation_started` chu KHONG gan trong `play()`:
## dong tac con duoc choi bang duong khac — `BattleUnit._play_lai` goi thang
## `player.play()` + `seek` (battle/unit.gd:156-162) de danh lai tu dau moi don.
##
## Do tren bang goc: 276 armature co tieng, 685 tieng, nhung 149/165 dong tac
## `Fight` chi co DUNG MOT tieng va khong dong tac `Walk`/`Standby` nao co
## tieng (tru 7 tieng `loop="1"`), nen khong co chuyen tieng buoc chan lam ngap
## 12 kenh khi ca tran cung di.
var _tiet_tau: Array = []       ## [{giay, su_kien, lap}] da sap theo giay
var _tiet_i := 0                ## tieng ke tiep chua phat
var _tiet_lap := 0              ## chi so tieng `lap` dau tien, = size neu khong co
var _vi_tri_truoc := 0.0


func _san_sang_tieng() -> void:
	if player == null:
		return
	player.animation_started.connect(_dong_moi)


func _dong_moi(_ten: StringName) -> void:
	_tiet_tau = []
	_tiet_i = 0
	_tiet_lap = 0
	_vi_tri_truoc = 0.0
	# Khong co ai doi tieng (chua mo khung suon Lua, hoac dang o trong trinh
	# xem rig cua Godot): khong doc bang, khong bat `_process`.
	if TiengDong.am == null or player == null:
		set_process(false)
		return
	var ten := player.current_animation
	# Tra theo ten BIEN THE truoc (do la ten armature that trong
	# `sound_config.xml`), roi moi den ten thu muc — co file ma hai ten do khac
	# nhau, va bo qua buoc thu hai thi nhung rig do cam.
	var td := TiengDong.moi()
	var ten_arm := _ten_armature()
	var ds := td.nhip(ten_arm, String(ten))
	if ds.is_empty() and ten_arm != String(name):
		ds = td.nhip(String(name), String(ten))
	if ds.is_empty():
		set_process(false)
		return
	for m in ds:
		# `khung` la chi so khung cua dong tac, va truc thoi gian cua dong tac
		# duoc dung bang chinh FPS nay (`anim.length = dur / FPS`).
		_tiet_tau.append({"giay": float(m["khung"]) / FPS,
				"su_kien": String(m["su_kien"]), "lap": bool(m["lap"])})
	_tiet_tau.sort_custom(func(a, b): return float(a["giay"]) < float(b["giay"]))
	_tiet_lap = _tiet_tau.size()
	for i in _tiet_tau.size():
		if _tiet_tau[i]["lap"]:
			_tiet_lap = i
			break
	set_process(true)


## Ten armature de tra bang tieng: `variant` khi rig nay la mot BIEN THE trong
## file khac (`ArcherN_Weapon_Normal` nam trong `ArcherN`), khong thi ten thu
## muc. Bang `sound_config.xml` khoa theo ten armature that.
func _ten_armature() -> String:
	return variant if variant != "" else String(name)


func _process(_delta: float) -> void:
	if _tiet_i >= _tiet_tau.size() and _tiet_lap >= _tiet_tau.size():
		set_process(false)
		return
	if player == null or TiengDong.am == null:
		return
	var vt := player.current_animation_position
	if vt < _vi_tri_truoc:
		# Dong tac quay vong: chi nhung tieng `loop="1"` moi phat lai (7 tieng
		# tren toan bo bang, vd `WakeLoop` cua Gia Xu).
		_tiet_i = _tiet_lap
	_vi_tri_truoc = vt
	while _tiet_i < _tiet_tau.size() \
			and float(_tiet_tau[_tiet_i]["giay"]) <= vt:
		var m: Dictionary = _tiet_tau[_tiet_i]
		_tiet_i += 1
		TiengDong.am.phat(String(m["su_kien"]))
