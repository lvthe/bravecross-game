# Cong thuc sat thuong THAT cua ban goc, giai tu libgame.so.
#
# Chi dung cho TRAN CO HINH (battle/san_tran_ve.gd) — mo hinh doi chieu ba ben
# (combat.gd + sim/battle.py + server/battle.lua) van giu nguyen. Bat bang
# rules['harm_real'] = true; san_tran_ve dat co do tren ban sao rules cua no.
#
# NGUON (xem brave-cross/work/README.md, muc "cong thuc sat thuong"):
#   * Cau truc: ham C++ 0x380c94 va cac ham con 0x380ae0.. — CHAC CHAN.
#   * Hang so: muc <formula> cua map/global_config.xml, khop offset trong doi
#     tuong cau hinh (+0x14c..+0x16c) — CHAC CHAN.
#   * Ten truong struct: strcmp trong builder 0x3808d8 — CHAC CHAN.
#   * Anh xa truong sang chi so ben danh / ben chiu: theo NGHIA cua ten truong
#     (fAp/nFireAp/nDamageAddition = ben danh; nDp/fReducingDamage = ben chiu) —
#     DAT, chua kiem byte-exact vi can chay ban goc trong may ao.
#
# Cong thuc, dung thu tu cua 0x380c94:
#   atk   = <sat thuong goc dua vao, da tinh he so thuong/ky nang>
#   d     = nDp * max(0, 1 - fIgnoreDp)
#   avoid = min(1, max(d, -1000) / (max(d, -1000) + 1500))   ; DefendAvoid
#   dmg   = max(nFireAp, nIceAp, 0, nThunderAp) + atk*(1 - avoid) + nPiercingAp
#   dmg  += dmg * (nDamageAddition / 3000)                    ; DamageAddition
#   dmg  -= fReducingDamage
#   dmg  += dmg * FinalHarm(...)                              ; lv1 = 0
#   out   = dmg * fDamageMultiples
class_name Harm
extends RefCounted

# Muc <formula> global_config.xml (brave-cross/work/vn/decrypted/assets/map).
const DEFEND_AVOID_MIN := -1000.0
const DEFEND_AVOID_BASE := 1500.0
const DAMAGE_ADDITION_DENOM := 3000.0
const FINAL_HARM_DENOM := 3000.0


## Doc mot khoa so tu ban ghi goc, chap nhan vai ten viet khac nhau.
static func _so(d: Dictionary, ten: String, mac_dinh := 0.0) -> float:
	return float(d.get(ten, mac_dinh))


## atk: sat thuong goc (ap * he so thuong hoac ky nang), tinh o strike.
## atk_raw / def_raw: ban ghi chi so goc cua ben danh / ben chiu (Fighter.raw).
## muc_tieu_tuong: muc tieu la tuong (HeroID > 0) — chon he so nhan tuong / linh.
static func tinh(atk: float, atk_raw: Dictionary, def_raw: Dictionary,
		muc_tieu_tuong: bool) -> float:
	# DefendAvoid(0x380ae0): giap cua ben chiu, bo qua bao nhieu phan boi ben danh.
	var d := _so(def_raw, "DP", _so(def_raw, "Dp")) * maxf(0.0, 1.0 - _so(atk_raw, "IgnoreDp"))
	var a := maxf(d, DEFEND_AVOID_MIN)
	var avoid := minf(1.0, a / (a + DEFEND_AVOID_BASE)) if (a + DEFEND_AVOID_BASE) != 0.0 else 0.0

	# Sat thuong nguyen to cua ben danh: lay lon nhat (khong am), roi so tiep set.
	var elem := maxf(maxf(_so(atk_raw, "FireAp"), _so(atk_raw, "IceAp")), 0.0)
	elem = maxf(elem, _so(atk_raw, "ThunderAp"))

	var dmg := elem + atk * (1.0 - avoid) + _so(atk_raw, "PiercingAp")
	dmg += dmg * (_so(atk_raw, "DamageAddition") / DAMAGE_ADDITION_DENOM)
	dmg -= _so(def_raw, "ReducingDamage")
	dmg += dmg * _final_harm(atk_raw, def_raw)

	# fDamageMultiples: he so nhan cuoi theo LOAI muc tieu. Hero_25 = 1 voi moi
	# loai; linh NPC Defender = 5 voi linh (DamageMultiplesAtDogface). DAT: chi
	# phan tuong / linh, chua tach boss va thu cung.
	var mult := _so(atk_raw, "DamageMultiplesAtHero" if muc_tieu_tuong
			else "DamageMultiplesAtDogface", 1.0)
	if mult != 0.0:
		dmg *= mult
	return maxf(0.0, dmg)


## FinalHarm (0x380c00): cong / tru theo bon truong "Final*". O cap 1 cua chien
## dich ca bon deu 0 nen tra 0 — duong di ban goc gap dung nhanh nay. Cac gia
## tri khac 0 (trang bi / the tran cap cao) thi day la XAP XI: hieu hai ti le,
## chan duoi -1. Luat ghep chinh xac bon tham so nam trong 0x380c00, chua giai
## het thu tu, nen danh dau DAT.
static func _final_harm(atk_raw: Dictionary, def_raw: Dictionary) -> float:
	var them := _so(atk_raw, "FinalDamage") / FINAL_HARM_DENOM + _so(atk_raw, "FinalDamageRates")
	var bot := _so(def_raw, "FinalReducingDamage") / FINAL_HARM_DENOM \
			+ _so(def_raw, "FinalReducingDamageRates")
	return maxf(-1.0, them - bot)
