# Do AM THANH THAT: ghi lai PCM ma Godot dua ra loa, roi do.
#
#   godot --headless --path . --script tools/do_tieng.gd -- --tep=<duong .ogg|.wav> \
#         [--giay=2] [--lap=0|1] [--ra=<tep tho>]
#
# VI SAO CAN. `tools/verify_am.gd` do duoc rang tieng CO duoc xin, CO kenh, CO
# `playing` — nhung no khong he nghe. Mot luong am thanh co the "chay dung" ma
# van keu rit: giai ma sai, hoac vong lap cat vao mot doan vai mau. Do duoc ngay
# o day: BGM man Main ra dinh **12,5** (vuot xa ±1,0) va **97,7%** nang luong
# tren 8 kHz — tuc la tieng rit, khong phai nhac.
#
# Cach do: cam `AudioEffectCapture` vao mot bus rieng, cho kenh phat qua bus do,
# roi hut tung khung ra. Ra tep nhi phan `float32` gian xen ke (trai, phai) de
# ben ngoai do bang numpy — FFT, so diem vo, do vo dai.
#
# NHAN CA `.wav`, va do la cho quan trong: tep `.ogg` cua ban goc co the hong nen
# khong the lay chinh no lam chuan. Mot sine 440 Hz biet truoc di qua CUNG duong
# nay ma ra dung sine thi bo do sach; ra khac thi tai cho khac.
#
# VONG LAP NAM O `_process`, KHONG o `_init`: trong mot script `--script`,
# `SceneTree.root` chua ton tai luc `_init` chay, va `await process_frame` o do
# TREO (do duoc: khong in duoc dong nao, het 120 giay). `tools/vao_main.gd` cung
# di duong `_process(dt) -> bool`.
extends SceneTree

const BUS := "do"
const THU_MUC := "res://assets_ref/audio/"

var _tep := ""
var _giay := 2.0
var _lap := true
var _ra := "C:/tmp/tieng.raw"
var _cam: AudioEffectCapture = null
var _p: AudioStreamPlayer = null
var _any: AudioStream = null
var _du := PackedVector2Array()
var _can := 0
var _hen := 0
var _xong := false


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for x in a:
		if x.begins_with("--tep="):
			_tep = x.substr(6)
		elif x.begins_with("--giay="):
			_giay = float(x.substr(7))
		elif x.begins_with("--lap="):
			_lap = x.substr(6) == "1"
		elif x.begins_with("--ra="):
			_ra = x.substr(5)
	if _tep == "":
		_tep = "BGM__BGM_Main02.ogg"
	if not _tep.contains(":") and not _tep.begins_with("res://"):
		_tep = ProjectSettings.globalize_path(THU_MUC + _tep.get_file())

	AudioServer.add_bus()
	var bi := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bi, BUS)
	AudioServer.set_bus_send(bi, "Master")
	_cam = AudioEffectCapture.new()
	_cam.buffer_length = 60.0
	AudioServer.add_bus_effect(bi, _cam)

	print("tep            %s" % _tep.get_file())
	if _tep.get_extension().to_lower() == "wav":
		_any = AudioStreamWAV.load_from_file(_tep)
	else:
		_any = AudioStreamOggVorbis.load_from_file(_tep)
	if _any == null:
		print("KHONG NAP DUOC: ", _tep)
		quit(1)
		return
	print("kieu           %s" % _any.get_class())
	print("dai (giay)     %.6f" % _any.get_length())
	if _any is AudioStreamOggVorbis:
		var o := _any as AudioStreamOggVorbis
		# `loop_end` KHONG ton tai o ban Godot nay (do duoc: "Invalid access to
		# property ... 'loop_end'"). Chi co `loop` va `loop_offset`.
		print("loop truoc     %s  offset %.4f" % [str(o.loop), o.loop_offset])
		if _lap:
			o.loop = true
		print("loop dat       %s  offset %.4f" % [str(o.loop), o.loop_offset])
	print("mix_rate       %d" % AudioServer.get_mix_rate())


func _process(_dt: float) -> bool:
	# Khung dau: cay da co `root`, nen moi gan kenh vao duoc.
	if _p == null:
		_p = AudioStreamPlayer.new()
		_p.stream = _any
		_p.bus = BUS
		_p.volume_db = 0.0
		root.add_child(_p)
		_p.play()
		_can = int(_giay * AudioServer.get_mix_rate())
		_hen = Time.get_ticks_msec()
		return false
	if _xong:
		return true
	if _cam.get_frames_available() > 0:
		_du.append_array(_cam.get_buffer(_cam.get_frames_available()))
	if _du.size() >= _can or Time.get_ticks_msec() - _hen > (_giay + 10.0) * 1000.0:
		_ghi()
		_xong = true
		return true
	return false


func _ghi() -> void:
	var f := FileAccess.open(_ra, FileAccess.WRITE)
	f.store_32(_du.size())
	f.store_32(AudioServer.get_mix_rate())
	for v in _du:
		f.store_float(v.x)
		f.store_float(v.y)
	f.close()
	print("hut duoc       %d khung / %d khung xin" % [_du.size(), _can])
	print("vi tri phat    %.4f  (dai %.4f)"
			% [_p.get_playback_position(), _any.get_length()])
	print("ra             %s" % _ra)
