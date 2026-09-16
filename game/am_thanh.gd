## Am thanh cua ban goc: noi `playSoundEffect` / `playBackgroundMusic` /
## `loadEffectBank` cua engine C++ vao AudioStreamPlayer cua Godot.
##
## VI SAO CAN. Ban goc goi tieng qua tam ten toan cuc do engine C++ dang ky —
## `playSoundEffect`, `stopSoundEffect`, `playBackgroundMusic`,
## `loadBackgroundBank`, `loadEffectBank`, `unloadBankByName`,
## `get/setBackgroundMusicVolume` — va **khong file Lua nao trong 973 file**
## dinh nghia ten nao trong so do. Nen trong may ao chung la BONG: goi duoc,
## khong nem loi, va im. Do tren ma goc: 76 cho goi
## `G_SoundManager:PlaySoundEffect` (mo/dong cua so, nut bam, nhan thuong), 12
## cho `PlayBackgroundMusic`, 36 `loadEffectBank`, 18 `unloadBankByName`. Ca
## nhung tieng do deu cam.
##
## Du lieu: 1498 file `.ogg` boc tu 361 bank cua ban goc (xem
## `../brave-cross/work/BANK.md`) va bang tra `event:/...` -> file o
## `data_ref/event_ref.json`.
##
## KHONG PHAI FMOD, va ba thu cua FMOD thi o day KHONG co:
##
##   * Chon bien the. Mot event co the co nhieu ban (`_01`..`_04`), ban goc de
##     FMOD quyet dinh theo luat cua no — khong khoi phuc duoc (BANK.md). O day
##     chon NGAU NHIEN.
##   * Loop cua nhac nen. FSB5 khong ghi co loop cho Vorbis, con thong tin that
##     nam trong `MasterBank` — ma bank do khong co mot mau am thanh nao (chi
##     `FMT ` + `LIST`, xem BANK.md), nen khong doc ra duoc. Dat `loop = true`:
##     nhac nen cua ban goc dai 42-43 giay, tat loop thi man Main im sau 43 giay
##     trong khi ban goc van hat.
##   * Tron 3D, bus, hieu ung cua FMOD Studio. Khong co duong nao doc ra.
##
## Cong cu do: `tools/verify_am.gd` (phan cuoi — di dung duong Lua nhu
## `SoundManager.lua` di).
class_name AmThanh
extends RefCounted

const THU_MUC := "res://assets_ref/audio"
const BANG := "res://data_ref/event_ref.json"
## Kiem ke tung subsound (bank.py ghi ra). Dung de tra tiep theo TEN khi bang
## tra chinh khong co: ten event do client tu dien luc chay
## (`string.format("event:/Vo-Usual/Vo_%s_Usual", heroSprite)`) nen khong bao
## gio nam trong danh sach chuoi quet duoc.
const KEM := THU_MUC + "/bank_ref.json"

## So tieng phat chong nhau duoc. Moi kenh la mot AudioStreamPlayer NAM TRONG
## CAY (khong co cach nao khac — AudioStreamPlayer ngoai cay thi khong phat).
## 12 la du: cho dong nhat trong game la tieng mo cua so + tieng nut, moi thu
## dai duoi 1 giay.
const SO_KENH := 12

## Duoi so cua ten subsound khong thong nhat: `_01`, `01`, ca `_ 02`
## (`Impact_Catapult_Light_ 02`). Cung luat voi event_ref.py.
const DUOI := "[\\d_\\s]+$"

## {ten event: [ten file]} — bang tra chinh.
var bang: Dictionary = {}
## {ten event: ly do} — chuoi co `%` (client tu dien ten vao luc chay).
var mau: Dictionary = {}
var khong_giai_duoc: Dictionary = {}
## {ten subsound da chuan hoa: [ten file]} — tra tiep theo ten.
var theo_ten: Dictionary = {}
var co_bang := false

## Dem lai, khong doan: biet duong noi nay phu duoc bao nhieu.
var so_phat := 0
var so_khong_tra_duoc := 0
var so_thieu_file := 0
var so_het_kenh := 0
## {ten bank: so lan} cho `loadEffectBank` / `loadBackgroundBank`. Chi de DO:
## xem client co nap bank nao ma ta khong co — quy tac "nap bank theo armature"
## nam trong `bank_config.xml` va do engine C++ lam, xem `ghi_chu_bank`.
var bank_da_nap: Dictionary = {}

var _thung: Array[AudioStreamPlayer] = []
var _dang: Dictionary = {}       # id -> AudioStreamPlayer
var _nho: Dictionary = {}        # khoa -> AudioStream
var _id := 0
var _nhac: AudioStreamPlayer = null
var _nhac_dang := ""
var _cha: Node = null
var _re: RegEx = null

var _am_luong_nhac := 1.0
var _am_luong_tieng := 1.0

## Tieng doi den khung dau roi moi phat duoc (xem `_thu_lai`).
##
## Moi muc la `[kenh, so_lan_da_thu]`. Kenh la con cua `_cha` (khong phai cua ta)
## nen no co the bi giai phong giua luc xin va luc khung dau chay — do la nguon
## cua mot cu SEGFAULT that: `quet_show.gd` chet vi song song do (xem `_thu_lai`).
var _cho: Array = []
var _hen := false
## Dem rieng: dang CHO khung dau, chua thuc su phat.
var so_cho := 0
## Dem rieng: kenh bi giai phong truoc khi kip phat, nen bo luon (xem `_thu_lai`).
var so_bo_cho := 0
## Dem rieng: khong co node nao de gan kenh vao (xem `_chuan_bi`).
var so_khong_co_cha := 0


func _khoi_re() -> RegEx:
	if _re == null:
		_re = RegEx.new()
		_re.compile(DUOI)
	return _re


## Doc hai bang tra mot lan. Thieu du lieu cua ban goc (khong commit duoc, xem
## .gitignore) thi `co_bang` o lai false va moi cau goi tra ve im lang — ben
## kiem `tools/verify_am.gd` tu bao BO QUA.
func doc_bang() -> void:
	if co_bang:
		return
	co_bang = true
	var t = JSON.parse_string(FileAccess.get_file_as_string(BANG))
	if typeof(t) == TYPE_DICTIONARY:
		bang = t.get("event_ref", {})
		mau = t.get("mau", {})
		khong_giai_duoc = t.get("khong_giai_duoc", {})
	var k = JSON.parse_string(FileAccess.get_file_as_string(KEM))
	if typeof(k) == TYPE_ARRAY:
		var re := _khoi_re()
		for r in k:
			var ten := re.sub(String(r["ten"]), "", true)
			var f := String(r["file"])
			var ds: Array = theo_ten.get(ten, [])
			ds.append(f)
			theo_ten[ten] = ds


## Node cha cua cac kenh: san khau neu ben goi da dat, khong thi goc cua cay.
##
## KHONG doi hoi node cha da nam trong cay. Do bang cach chay thu: trong `_init`
## cua mot script `--script` thi `Engine.get_main_loop()` la null VA
## `SceneTree.root.is_inside_tree()` la false — goc cua so chi vao cay o
## `SceneTree.initialize()`, tuc SAU khi `_init` chay xong. Ma ca duong Lua
## (nap khung suon roi mo man hinh) chay gon trong `_init`, nen luc do KHONG co
## node nao trong cay de ma gan vao. Vi vay kenh cu tao ra duoc, con `play()`
## thi doi den khung dau — xem `_thu_lai`.
func dat_cha(n: Node) -> void:
	_cha = n


func _lay_cha() -> Node:
	if _cha != null and is_instance_valid(_cha):
		return _cha
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root
	return null


func _chuan_bi() -> bool:
	if not _thung.is_empty():
		return true
	var cha := _lay_cha()
	if cha == null:
		# Khong co cho nao de gan kenh vao: ben goi chua dat san khau VA cay
		# chua chay. Dem rieng de bo kiem phan biet duoc voi "het kenh".
		so_khong_co_cha += 1
		return false
	for i in SO_KENH:
		var p := AudioStreamPlayer.new()
		p.name = "AmThanh%d" % i
		cha.add_child(p)
		_thung.append(p)
	_nhac = AudioStreamPlayer.new()
	_nhac.name = "AmThanhNhac"
	cha.add_child(_nhac)
	return true


## Danh sach file cua mot ten `event:/...`. Rong nghia la khong co.
func tra(ten: String) -> Array:
	doc_bang()
	var v = bang.get(ten)
	if v != null:
		return v.get("file", [])
	# Duong phu theo TEN. Luat nay khong phai suy dien: no la luat da do cua
	# bang tra (xem event_ref.py) — bank duoc xac dinh bang TEN subsound, con
	# duong dan chi la goi y. Can o day cho nhung ten client tu ghep luc chay.
	var cuoi := ten.get_file()
	if cuoi.is_empty():
		return []
	var ds: Array = theo_ten.get(_khoi_re().sub(cuoi, "", true), [])
	return ds


func _stream(duong: String, lap: bool) -> AudioStream:
	var khoa := ("L:" if lap else "T:") + duong
	if _nho.has(khoa):
		return _nho[khoa]
	var st := AudioStreamOggVorbis.load_from_file(duong)
	if lap and st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_nho[khoa] = st
	return st


func _don_kenh() -> void:
	for k in _dang.keys():
		var p: AudioStreamPlayer = _dang[k]
		# Kenh dang HEN cho khung dau cung la kenh dang dung: `playing` con false
		# nhung tieng da thuoc ve no. Thieu ve `_dang_cho` o day thi don sach
		# `_dang` ngay trong `_init` (moi kenh deu chua vao cay), va he qua la
		# `stopSoundEffect(id)` khong tim thay kenh nao de tat — do duoc bang
		# tools/verify_am.gd: 10 tieng dang dung ma `_dang` chi con 1.
		if not is_instance_valid(p) or (not p.playing and not _dang_cho(p)):
			_dang.erase(k)


## Phat, hoac hen den khung dau. Tra true neu da phat ngay.
##
## Vi sao phai hen: xem `dat_cha`. `call_deferred` chay duoc ca khi node chua
## vao cay (no di qua hang doi cua vong lap chinh, khong dinh gi toi cay), nhu
## vay tieng nao xin luc `_init` se duoc phat ngay khung dau tien — man hinh
## nao bat nhac nen luc khoi dong thi nhac van len, chu khong im.
func _chay(p: AudioStreamPlayer, st: AudioStream) -> bool:
	if p.is_inside_tree():
		p.play()
		so_phat += 1
		return true
	_cho.append([p, 0])
	so_cho += 1
	if not _hen:
		_hen = true
		call_deferred("_thu_lai")
	return false


## So lan thu lai toi da. Mot lan la du cho ca that su (xin luc `_init` thi khung
## dau da co cay), nhung de du phong cho truong hop cay len cham.
const SO_LAN_THU := 3


## Thu lai cac tieng da hen, goi luc khung dau (va goi tay duoc tu bo kiem).
##
## HAI CHOT, ca hai deu la sua loi do duoc chu khong phai cho dep:
##
##   * Kenh KHONG CON HOP LE thi BO, khong xep lai hang. Kenh nam duoi `_cha`,
##     ma `_cha` co the la node cua mot man hinh vua bi dong — luc do doi tiep la
##     doi mai. Ban cu xep lai nen vong `call_deferred` quay vo tan, va
##     `quet_show.gd` (mo 353 man lien tiep) **chet bang signal 11** voi vet
##     GDScript tro dung vao day. Doc `m[0]` bang bien KHONG kieu: gan mot
##     instance da giai phong vao bien co kieu (`AudioStreamPlayer`) tu no da la
##     mot loi.
##   * Thu qua `SO_LAN_THU` lan thi BO. Khong co cay thi khong bao gio co tieng,
##     va hen mai chi lam vong lap chay den luc tat may.
func _thu_lai() -> void:
	_hen = false
	if _cho.is_empty():
		return
	var con: Array = []
	for m in _cho:
		var p = m[0]
		m[1] = int(m[1]) + 1
		if not is_instance_valid(p):
			so_bo_cho += 1
			continue
		if p.is_inside_tree():
			p.play()
			so_phat += 1
		elif int(m[1]) < SO_LAN_THU:
			con.append(m)
		else:
			so_bo_cho += 1
	_cho = con
	if not _cho.is_empty() and not _hen:
		_hen = true
		call_deferred("_thu_lai")


static func _db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


## `playSoundEffect(ten) -> id`, 0 la khong phat duoc.
func phat(ten: String) -> int:
	if ten.is_empty():
		return 0
	var ds := tra(ten)
	if ds.is_empty():
		so_khong_tra_duoc += 1
		return 0
	if not _chuan_bi():
		return 0
	# Nhieu ban thi ban goc de FMOD chon — chua khoi phuc duoc, xem dau file.
	var duong := THU_MUC + "/" + String(ds[randi() % ds.size()])
	var st := _stream(duong, false)
	if st == null:
		so_thieu_file += 1
		return 0
	_don_kenh()
	var p := _kenh_ranh()
	if p == null:
		so_het_kenh += 1
		return 0
	_id += 1
	p.stream = st
	p.volume_db = _db(_am_luong_tieng)
	_dang[_id] = p
	_chay(p, st)
	return _id


func _kenh_ranh() -> AudioStreamPlayer:
	# Kenh da hen cho khung dau cung la kenh DANG DUNG, du `playing` con false.
	var ban := {}
	for m in _cho:
		ban[m[0]] = true
	for p in _thung:
		if not p.playing and not ban.has(p):
			return p
	# Het kenh: lay lai kenh LAU NHAT (id nho nhat) chu khong bo tieng moi —
	# ban goc co 64 kenh ao nen hau nhu khong bao gio het; cat tieng dang keo
	# dai de lay cho tieng vua bam la nguoc.
	var nho_nhat := -1
	for k in _dang:
		if nho_nhat < 0 or int(k) < nho_nhat:
			nho_nhat = int(k)
	if nho_nhat < 0:
		return null
	var p2: AudioStreamPlayer = _dang[nho_nhat]
	_dang.erase(nho_nhat)
	_bo_hen(p2)
	return p2


func _bo_hen(p: AudioStreamPlayer) -> void:
	for i in range(_cho.size() - 1, -1, -1):
		if _cho[i][0] == p:
			_cho.remove_at(i)


func _dang_cho(p: AudioStreamPlayer) -> bool:
	for m in _cho:
		if m[0] == p:
			return true
	return false


func dung(id: int) -> void:
	var p = _dang.get(id)
	if p == null:
		return
	if is_instance_valid(p):
		p.stop()
	_dang.erase(id)
	_bo_hen(p)


func nhac(ten: String) -> bool:
	if ten.is_empty():
		return false
	# `_dang_cho` cung tinh la dang hat: bai xin luc `_init` chua kip vao cay,
	# ma `SoundManager:PlayBackgroundMusic` lai goi lai moi khung.
	if _nhac != null and is_instance_valid(_nhac) and _nhac_dang == ten \
			and (_nhac.playing or _dang_cho(_nhac)):
		return true
	var ds := tra(ten)
	if ds.is_empty():
		so_khong_tra_duoc += 1
		return false
	if not _chuan_bi():
		return false
	# Nhac nen: ban goc cung de FMOD chon khi co nhieu ban (`BGM_Battle_Normal`
	# co 4) — o day lay ban dau, vi doi nhac giua luc dang hat thi nghe ro.
	var duong := THU_MUC + "/" + String(ds[0])
	var st := _stream(duong, true)
	if st == null:
		so_thieu_file += 1
		return false
	_nhac_dang = ten
	_nhac.stream = st
	_nhac.volume_db = _db(_am_luong_nhac)
	_chay(_nhac, st)
	return true


func dung_nhac() -> void:
	_nhac_dang = ""
	if _nhac != null and is_instance_valid(_nhac):
		_nhac.stop()
		_bo_hen(_nhac)


func tam_dung_nhac(dung_lai: bool) -> void:
	if _nhac != null and is_instance_valid(_nhac):
		_nhac.stream_paused = dung_lai


func nhac_dang_chay() -> bool:
	return _nhac != null and is_instance_valid(_nhac) and _nhac.playing


## Ba so duoi day chi de DO (`tools/verify_am.gd` khong phai voi vao trong rieng
## cua lop nay): so tieng dang cho khung dau, so kenh dang dung, ten bai nhac.
func dang_hen() -> int:
	return _cho.size()


func so_kenh_dang_dung() -> int:
	return _dang.size()


func ten_nhac_dang() -> String:
	return _nhac_dang


func am_luong(loai_nhac: bool) -> float:
	return _am_luong_nhac if loai_nhac else _am_luong_tieng


func dat_am_luong(loai_nhac: bool, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if loai_nhac:
		_am_luong_nhac = v
		if _nhac != null and is_instance_valid(_nhac):
			_nhac.volume_db = _db(v)
		return
	_am_luong_tieng = v
	for k in _dang:
		var p: AudioStreamPlayer = _dang[k]
		if is_instance_valid(p):
			p.volume_db = _db(v)


## Ghi lai mot lan `loadEffectBank` / `loadBackgroundBank`.
##
## KHONG dung de CHAN tieng, va day la cho phai noi ro: ban goc chi phat duoc
## am thanh cua bank da nap, nhung quy tac nap bank theo armature nam trong
## `vn/apk/assets/banks/bank_config.xml` (armature -> `banks/X.bank`) va do
## engine C++ lam luc tao sprite — khong do duoc tren ban goc, nen khong the
## lam lai cho dung. Chan theo so nay thi moi tieng cua tuong (bank `Archer`,
## `LvBu`…) cam het, vi khong file Lua nao goi `loadEffectBank` cho chung.
## Nen: ghi lai de biet minh phu duoc bao nhieu, con phat thi cu phat.
func ghi_chu_bank(ten: String, duong: String) -> void:
	bank_da_nap[ten] = duong


func bo_bank(ten: String) -> void:
	bank_da_nap.erase(ten)
