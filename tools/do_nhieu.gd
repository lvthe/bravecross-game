# Do NHIEU tep .ogg trong MOT luot chay: ghi PCM tho cua tung tep ra thu muc.
#
#   godot --headless --path . --script tools/do_nhieu.gd -- --thu-muc=C:/tmp/setup_bgm \
#         [--giay=1.0] [--ra=C:/tmp/nhieu]
#
# VI SAO CAN. Khi nghi mot khoi setup (codebook) Vorbis bi ghep sai thi cach duy
# nhat de biet KHOI NAO dung la thu LAN LUOT roi nghe/do. Mot tep mot tien trinh
# Godot thi ~10 giay khoi dong x 84 = 14 phut; o day mot tien trinh do het.
#
# Do gi: `do_tieng.gd` da chung minh bo do nay sach (sine 440 Hz biet truoc di
# qua ra dung 440,1 Hz, 0% nang luong tren 8 kHz). Nen o day chi can hut PCM
# roi de numpy phan tich — peak, rms, ti le nang luong tren 8 kHz, do "det" cua
# pho (trung binh nhan chia trung binh cong: nhieu trang ~1, nhac thi rat nho).
#
# Vong lap nam o `_process`, khong o `_init`: trong `--script`, `SceneTree.root`
# chua ton tai luc `_init` va `await process_frame` o do TREO (do duoc).
extends SceneTree

const BUS := "do"

var _thu_muc := ""
var _ra := "C:/tmp/nhieu"
var _giay := 1.0
var _ds: Array = []
var _i := -1
var _cam: AudioEffectCapture = null
var _p: AudioStreamPlayer = null
var _du := PackedVector2Array()
var _can := 0
var _hen := 0
var _xong := false
var _dang := false


func _init() -> void:
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--thu-muc="):
			_thu_muc = x.substr(10)
		elif x.begins_with("--ra="):
			_ra = x.substr(5)
		elif x.begins_with("--giay="):
			_giay = float(x.substr(7))
	if _thu_muc == "":
		print("thieu --thu-muc=")
		quit(1)
		return
	var d := DirAccess.open(_thu_muc)
	if d == null:
		print("khong mo duoc thu muc ", _thu_muc)
		quit(1)
		return
	var f := d.get_files()
	f.sort()
	for t in f:
		if t.ends_with(".ogg"):
			_ds.append(_thu_muc.path_join(t))
	DirAccess.make_dir_recursive_absolute(_ra)

	AudioServer.add_bus()
	var bi := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bi, BUS)
	AudioServer.set_bus_send(bi, "Master")
	_cam = AudioEffectCapture.new()
	_cam.buffer_length = 60.0
	AudioServer.add_bus_effect(bi, _cam)

	_can = int(_giay * AudioServer.get_mix_rate())
	print("thu muc        %s" % _thu_muc)
	print("so tep         %d" % _ds.size())
	print("so khung moi tep %d  (%.2f giay @ %d Hz)"
			% [_can, _giay, AudioServer.get_mix_rate()])


func _process(_dt: float) -> bool:
	if _xong:
		return true
	if not _dang:
		_i += 1
		if _i >= _ds.size():
			_xong = true
			print("xong: %d tep, ra %s" % [_ds.size(), _ra])
			return true
		var duong := String(_ds[_i])
		var st := AudioStreamOggVorbis.load_from_file(duong)
		if st == null:
			print("%-34s KHONG NAP DUOC" % duong.get_file())
			return false
		_p = AudioStreamPlayer.new()
		_p.stream = st
		_p.bus = BUS
		root.add_child(_p)
		_p.play()
		_cam.clear_buffer()
		_du = PackedVector2Array()
		_hen = Time.get_ticks_msec()
		_dang = true
		return false
	if _cam.get_frames_available() > 0:
		_du.append_array(_cam.get_buffer(_cam.get_frames_available()))
	# Het bai thi dung ngay: do ca tep dai 45 giay ma cho du 2 giay thi hut
	# thua phan dem, va dinh do ra nho hon dinh THAT cua tep.
	var het := not _p.playing and _du.size() > AudioServer.get_mix_rate() / 5
	if _du.size() >= _can or het or Time.get_ticks_msec() - _hen > 60000:
		_ghi()
		_p.queue_free()
		_p = null
		_dang = false
	return false


func _ghi() -> void:
	var ten := String(_ds[_i]).get_file().get_basename()
	var f := FileAccess.open(_ra.path_join(ten + ".raw"), FileAccess.WRITE)
	f.store_32(_du.size())
	f.store_32(AudioServer.get_mix_rate())
	for v in _du:
		f.store_float(v.x)
		f.store_float(v.y)
	f.close()
	print("  %-30s %d khung" % [ten, _du.size()])
