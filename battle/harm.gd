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
#   * Anh xa truong sang ben danh / ben chiu — CHAC CHAN, doc tu CHO DIEN
#     struct (0x41ab82..0x41ad08). 0x380c94 nhan mot struct 0x4c byte; chinh
#     cho dien do lay tung o tu hai doi tuong khac nhau:
#         r5 = BEN DANH (co the NULL: `cmp r5,#0; beq` nhay thang toi cho goi)
#         r6 = BEN CHIU (luon co)
#     Doi chieu tung o (offset trong struct -> ten strcmp -> nguon):
#         +0x00 fAp                r5  (tinh san o strike)
#         +0x04 (khong ten)        don danh: cong thang vao dam co ban
#         +0x08 fInjuryRates       r5
#         +0x0c fGrowthFactor      r5
#         +0x10 nDp                r6 + 0x64c
#         +0x14 fIgnoreDp          r5 + 0x3e0, +0x3f0 (cong voi hai o cua don)
#         +0x18 (khong ten)        r5 + 0x3e8 — TRU vao ti le ne, xem duoi
#         +0x1c nFireAp            r5 + 0x65c
#         +0x20 nIceAp             r5 + 0x664
#         +0x24 nThunderAp         r5 + 0x66c
#         +0x28 nPiercingAp        r5 + 0x674
#         +0x2c nDamageAddition    r5 + 0x718
#         +0x30 fReducingDamage    r6 + 0x748
#         +0x34 fDamageMultiples   0x3d49d4(r5, r6) — so cua r5, chon o theo r6
#         +0x38 FinalDamageRates           r5 + 0x7d8
#         +0x3c FinalDamage                r5 + 0x7e0
#         +0x40 FinalReducingDamageRates   r6 + 0x7e8
#         +0x44 FinalReducingDamage        r6 + 0x7f0
#         +0x48 (khong ten)        0x3d2958(r6) = 0.5 + r6[0x59c] — chan duoi
#     Tat ca bon gia dinh cu (fAp/nFireAp/nDamageAddition ben danh; nDp/
#     fReducingDamage ben chiu) deu DUNG.
#   * fDamageMultiples co BA o, khong phai hai (0x3d49d4): ben danh +0x780 khi
#     muc tieu la tuong, +0x790 khi muc tieu co NpcType == 5, con lai +0x788.
#     Bang ten lien tiep o 0x7b4504 xep Hero, Dogface, Boss, Pet (cach 8 byte)
#     nen +0x780/+0x788/+0x790 = AtHero / AtDogface / AtBoss. NpcType 5 = boss
#     doc tu chinh ban goc (CUIChapterInfo.lua:1182 dung sBossIcon).
#
# Cong thuc, dung thu tu cua 0x380c94:
#   atk   = 0x380c52(fAp, fInjuryRates, fGrowthFactor) + <don danh>
#   d     = nDp > 0 ? nDp * max(0, 1 - fIgnoreDp) : nDp   ; nDp <= 0 thi KHONG
#                                                         ; nhan he so bo qua
#   avoid = min(1, max(d, -1000) / (max(d, -1000) + 1500))   ; DefendAvoid
#   if avoid > 0: avoid = max(0, avoid - struct[+0x18])
#   dmg   = max(max(nFireAp, nIceAp), 0, nThunderAp) + atk*(1 - avoid) + nPiercingAp
#   dmg  += dmg * (nDamageAddition / 3000)                    ; DamageAddition
#   dmg  -= fReducingDamage
#   dmg  += dmg * FinalHarm(...)                              ; lv1 = 0
#   out   = dmg * fDamageMultiples
#
# CON DAT (ghi lai, khong doan bua):
#   * struct[+0x18] tru vao ti le ne: ben danh, o +0x3e8, KHONG co trong bang
#     ten cua builder nen chua biet ten. O day coi la 0 — dung bang ban goc khi
#     chi so do bang 0, lech khi khac 0.
#   * Chan duoi cua FinalHarm la -(0.5 + r6[0x59c]) chu khong phai hang so.
#     Giu -1.0 (= 0.5 + 0.5) vi chua doc duoc gia tri mac dinh cua r6[0x59c].
#   * Ban goc KHONG chan out >= 0 (chi ham goi doi sang so nguyen). O day van
#     chan de khoi tra so am cho san tran.
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
	# 0x380cde: he so bo qua chi nhan khi nDp > 0 (ite gt / vmovle), nen giap am
	# di thang vao cong thuc.
	var dp := _so(def_raw, "DP", _so(def_raw, "Dp"))
	var d := dp * maxf(0.0, 1.0 - _so(atk_raw, "IgnoreDp")) if dp > 0.0 else dp
	var a := maxf(d, DEFEND_AVOID_MIN)
	var avoid := minf(1.0, a / (a + DEFEND_AVOID_BASE)) if (a + DEFEND_AVOID_BASE) != 0.0 else 0.0

	# Sat thuong nguyen to cua ben danh: lay lon nhat (khong am), roi so tiep set.
	var elem := maxf(maxf(_so(atk_raw, "FireAp"), _so(atk_raw, "IceAp")), 0.0)
	elem = maxf(elem, _so(atk_raw, "ThunderAp"))

	var dmg := elem + atk * (1.0 - avoid) + _so(atk_raw, "PiercingAp")
	dmg += dmg * (_so(atk_raw, "DamageAddition") / DAMAGE_ADDITION_DENOM)
	dmg -= _so(def_raw, "ReducingDamage")
	dmg += dmg * _final_harm(atk_raw, def_raw)

	# fDamageMultiples: he so nhan cuoi theo LOAI muc tieu, so cua BEN DANH.
	# 0x3d49d4 xet theo thu tu: muc tieu la tuong -> AtHero; NpcType == 5 (boss,
	# theo CUIChapterInfo.lua:1182) -> AtBoss; con lai -> AtDogface. Hero_25 = 1
	# voi moi loai; linh NPC Defender = 5 voi linh.
	var o_mult := "DamageMultiplesAtDogface"
	if muc_tieu_tuong:
		o_mult = "DamageMultiplesAtHero"
	elif int(def_raw.get("NpcType", 0)) == 5:
		o_mult = "DamageMultiplesAtBoss"
	var mult := _so(atk_raw, o_mult, 1.0)
	if mult != 0.0:
		dmg *= mult
	return maxf(0.0, dmg)


## FinalHarm (0x380c00): cong / tru theo bon truong "Final*". Thu tu da giai
## het: s17 = (Rates_danh + Flat_danh/3000) - (Rates_chiu + Flat_chiu/3000),
## roi chan duoi bang -(tham so thu nam). Cho dien struct cho thay hai truong
## dau lay tu ben danh (+0x7d8, +0x7e0), hai truong sau tu ben chiu (+0x7e8,
## +0x7f0) — dung nhu o day. O cap 1 cua chien dich ca bon deu 0 nen tra 0.
## Chi con chan duoi la DAT: ban goc dung -(0.5 + r6[0x59c]), ta giu -1.
static func _final_harm(atk_raw: Dictionary, def_raw: Dictionary) -> float:
	var them := _so(atk_raw, "FinalDamage") / FINAL_HARM_DENOM + _so(atk_raw, "FinalDamageRates")
	var bot := _so(def_raw, "FinalReducingDamage") / FINAL_HARM_DENOM \
			+ _so(def_raw, "FinalReducingDamageRates")
	return maxf(-1.0, them - bot)
