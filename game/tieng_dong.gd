## Tieng dong cua ban goc theo HOAT DONG va theo DON DANH — hai bang cau hinh
## ma CHI engine C++ doc.
##
## VI SAO PHAI LAM LAI. Do tren 973 file Lua trong `sc/`: khong file nao doc
## `sound_config.xml` hay `hit_config.xml`. Hai bang do chi xuat hien o
## `sngCrcCache.sc` (bang bam CRC cua tai nguyen) va trong `libgame.so`. Engine
## C++ tu doc roi tu phat: khi armature chay toi khung thu may, va khi don danh
## trung. Nen o day khong co "ma goc de chay" nhu duong `G_SoundManager` — phai
## lam lai dung luat do tu chinh du lieu.
##
## Du lieu sinh bang `../brave-cross/work/trigger_ref.py` ->
## `data_ref/trigger_ref.json`. Noi phat la `AmThanh` (cung bang tra
## `event:/...` -> file .ogg nhu moi tieng khac).
##
## KHONG KHOI PHUC DUOC, va khong bia (bon cho, do chu khong doan):
##
##   * DO MANH cua cu danh — khoa `<kit>_<giap>_<do manh>`, do manh 1 nhe /
##     2 nang. Bang goc khong ghi no: do tren 226 cu danh, the `<strike>` chi
##     mang `index` va `kitMaterial`. 1 hay 2 la engine C++ quyet dinh luc chay.
##     Xem `trung_don` (cho dung thi lay don ky nang lam "nang", va noi ro).
##   * `specifyEvent` / `specifyPlugin` (17 cu danh) chi la CHI SO, gia tri chi
##     co 0 hoac 5, va khong bang nao noi "5" la gi. JSON giu nguyen gia tri goc.
##   * Khi nao phat tieng trung don: engine ghep theo `index` cua cu danh trong
##     dong tac. 218/226 cu danh mang `index = 0`; 8 cai con lai chi nam o cac
##     dong tac nhieu cu danh cua Lu Bu — ta luon hoi `index = 0`.
##   * `loop="1"` (7 tieng) thi CO that nen lam theo, khong phai doan.
##   * Ten BIEN THE (`*_VampirE`, `*_Dong`, `*_Boss`, `*_Skeleton`) — `giap` co
##     40 ten nhu vay nhung **0/40** co mat trong `sound_config.xml` lan `danh`:
##     hai bang phia VU KHI cua chinh ban goc deu khong biet chung (ten GOC thi
##     co: 36/40 trong `sound_config`, 20/40 trong `danh`). Muon co tieng thi phai
##     BIA mot luat doi ten ma engine C++ chua lo ra, nen ta de im. Xem
##     `_phat_trung_don` cua `san_tran_ve.gd` de biet no anh huong bao nhieu.
##
## Cong cu do: `tools/verify_am.gd` (phan 5).
class_name TiengDong
extends RefCounted

const BANG := "res://data_ref/trigger_ref.json"

## Noi phat, VA cung la co "co ai doi tieng khong".
##
## `SngRig` phai hoi duoc cho nay ma khong biet khung suon Lua: rig con chay o
## man Main, trong trinh xem rig, trong `tools/verify*.gd`. Dat o lop du lieu
## chu khong o lop ve, vi bang va nguoi phat la CUNG mot tinh nang.
## `LuaRuntime.open()` dat — do la cho DUY NHAT dat.
static var am: AmThanh = null

static var _chung: TiengDong = null

## Ban dung chung. Bang nay 700 KB va khong doi, doc lai cho tung rig thi phi.
static func moi() -> TiengDong:
	if _chung == null:
		_chung = TiengDong.new()
		_chung.doc_bang()
	return _chung


## {armature: {dong tac: [{khung, su_kien, lap}]}}
var tieng_hoat_dong: Dictionary = {}
## {armature: {dong tac: [{index, kit, chi_dinh_su_kien, chi_dinh_hieu_ung}]}}
var danh: Dictionary = {}
## {armature: armorMaterial}
var giap: Dictionary = {}
## {armature: armature khac co du lieu danh}
var dung_lai: Dictionary = {}
## {"<kit>_<giap>_<do manh>": "event:/Impact/..."}
var su_kien: Dictionary = {}
var co_bang := false

## Vi sao lan goi `trung_don` vua roi tra ve "": mot trong bon ma o duoi, hoac ""
## neu tra duoc. Chi de DO muc phu (xem `_phat_trung_don` cua `san_tran_ve.gd`),
## khong phai de dieu khien tieng nao.
var ly_do := ""


func doc_bang() -> void:
	if co_bang:
		return
	co_bang = true
	var t = JSON.parse_string(FileAccess.get_file_as_string(BANG))
	if typeof(t) != TYPE_DICTIONARY:
		# Thieu du lieu cua ban goc (khong commit duoc, xem .gitignore): im lang,
		# chu khong nem loi — moi cau goi tra ve rong va ben kiem tu bao BO QUA.
		return
	tieng_hoat_dong = t.get("tieng_hoat_dong", {})
	var td: Dictionary = t.get("trung_don", {})
	danh = td.get("danh", {})
	giap = td.get("giap", {})
	dung_lai = td.get("dung_lai", {})
	su_kien = td.get("su_kien", {})


## Tieng phai phat khi armature chay dong tac `dong_tac`, theo khung.
##
## `khung` dem tu 0 theo CHI SO KHUNG cua chinh dong tac do (khong phai giay),
## nen ben goi chia cho cung so FPS ma `SngRig` dung de dung truc thoi gian.
func nhip(armature: String, dong_tac: String) -> Array:
	if not co_bang:
		doc_bang()
	var a = tieng_hoat_dong.get(_cat(armature))
	if not (a is Dictionary):
		a = tieng_hoat_dong.get(armature)
	if not (a is Dictionary):
		return []
	var ds = a.get(dong_tac)
	return ds if ds is Array else []


## Tieng trung don, hoac "" neu khong tra duoc.
##
## Ba manh ghep lai, dung nhu bang goc: loai VU KHI cua ben danh (`kitMaterial`
## theo armature + dong tac + so thu tu cu danh), loai GIAP cua ben chiu
## (`armorMaterial` theo armature), roi tra `<kit>_<giap>_<do manh>`.
##
## `do_manh` la DAT va day la cho phai noi ro: bang goc khong ghi no o dau ca
## (xem dau file), nen ben goi phai chon 1 (nhe) hay 2 (nang).
##
## Vi sao chi hoi `index = 0`: xem dau file. Vi sao co the tra ve "": rat nhieu
## armature khong co trong `hit_config.xml` — ten linh trong du lieu tran la
## armature THAN (Archer, SpearmenN), con vu khi la armature RIENG
## (ArcherN_Weapon_Normal) ma `dung_lai` moi noi toi. Do tren
## `data_ref/battle_data.json`: 10/37 ten linh va 31/71 ten tuong tra duoc.
##
## Lan goi nao tra "" thi `ly_do` noi vi sao (bon ma, xem `ly_do`).
func trung_don(ten_danh: String, dong_tac: String, index: int,
		ten_chiu: String, do_manh: int) -> String:
	ly_do = ""
	if not co_bang:
		doc_bang()
	var kit := _kit(ten_danh, dong_tac, index)
	# `kitMaterial = 0` nghia la "khong co vu khi" (10 cu danh nhu vay) va bang
	# `events` khong co khoa nao bat dau bang "0_" — tra tiep la vo nghia.
	if kit < 0:
		ly_do = "khong-co-danh"
		return ""
	if kit == 0:
		ly_do = "tay-khong"
		return ""
	var g = giap.get(_cat(ten_chiu))
	if g == null:
		ly_do = "khong-co-giap"
		return ""
	var ev = su_kien.get("%d_%d_%d" % [kit, int(g), do_manh])
	if ev == null:
		ly_do = "khong-co-su-kien"
		return ""
	return String(ev)


## Loai vu khi cua mot cu danh, -1 neu armature/dong tac khong co du lieu.
func _kit(ten: String, dong_tac: String, index: int) -> int:
	var d := _bang_danh(ten)
	if d.is_empty():
		return -1
	var ds = d.get(dong_tac)
	if not (ds is Array) or (ds as Array).is_empty():
		return -1
	for s in ds:
		if int(s.get("index", 0)) == index:
			return int(s.get("kit", -1))
	# Khong cu nao mang so thu tu do: lay cu DAU. 218/226 cu danh mang index 0
	# nen day gan nhu khong bao gio xay ra, nhung im lang bo qua thi don danh
	# cua Lu Bu (cu thu 4 moi doi loai vu khi) se khong co tieng nao.
	return int((ds as Array)[0].get("kit", -1))


## Du lieu danh cua mot armature: thang, hoac qua `reuseArmatures`.
##
## `reuseArmatures` nghia la "dung du lieu cua xuong nao" (do 131/131 gia tri
## deu co trong `danh`, khong co gia tri treo): `ArcherN_Weapon_Normal` ->
## `DEF_Weapon_3`. Ten o day la armature VU KHI, khong bao gio xuat hien trong
## du lieu tran, nen khong co duong nay thi cung thu khong bao gio co tieng.
func _bang_danh(ten: String) -> Dictionary:
	var t := _cat(ten)
	var d = danh.get(t)
	if d is Dictionary:
		return d
	var y = dung_lai.get(t)
	if y != null:
		var d2 = danh.get(String(y))
		if d2 is Dictionary:
			return d2
	return {}


## Bo duoi trong ngoac cua ten hinh.
##
## Du lieu tran co ten nhu "ZhaoYun(new)" va "Defender(董军入侵)" — VAN la cung
## mot armature, ban goc phan biet bang co che khac chu khong phai ten file. Do
## tren `battle_data.json`: 37 ten linh khac nhau sau khi bo duoi (khong bo thi
## chung tach thanh nhieu ten rac, va khong ten nao tra duoc bang tieng).
static func _cat(ten: String) -> String:
	var i := ten.find("(")
	var j := ten.find("（")
	if i < 0 or (j >= 0 and j < i):
		i = j
	if i < 0:
		return ten.strip_edges()
	return ten.substr(0, i).strip_edges()
