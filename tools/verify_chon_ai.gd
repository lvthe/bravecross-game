# MAN CHON AI (`CUISelectLevel`) — bon widget dieu huong, va mot cu cham vao o ai.
#
#   godot --headless --path . --script tools/verify_chon_ai.gd
#
# Vi sao phai co bo kiem nay: hai bo san co di qua man nay deu khong hoi duoc
# nhung cau hoi o day.
#
#   `do_chien_dich.gd` vao bang `Show(g_CUISelectLevel:GetUIName(), {})`, roi
#   chon ai bang `L.nSubChapter = i; L:GoNextCallback()` — DI TAT qua ca bon
#   widget (Previous / Next / tab Normal / tab Hard) va qua chinh
#   `onTouchEnd_OnSelectLevel`.
#
#   `bam_that.gd` co cham THAT, nhung no chi hoi "co qua duoc buoc khong": no
#   thu lan luot cac o ai cho toi khi MOT o mo ra. No khong hoi o ai DANG KHOA
#   co bi tu choi khong, cung khong hoi bon widget kia chay theo luat nao.
#
# ---------------------------------------------------------------------------
# LUAT DO TU MA GOC, khong suy:
#
#   `onTouchEnd_onToPrevious` (:1784) — `nPrevChapter = nMainChapter - 1`, chi
#   doi khi `> 0`. Truoc `> 0` no VAN tra `true`: nen "handler tra true" khong
#   phai bang chung no da lam gi.
#   `onTouchEnd_onToNext` (:1801) — hai cong: `obj:isGray()` thi chi hien
#   tooltip `Chapter_SelectLevel_NeedLvToUnlock`; khong gray thi doi khi
#   `nHighestChapter >= nMainChapter + 1`, voi `nHighestChapter` lay tu
#   `tNormalHighestChapterData.MainChapter` (difficulty 1) hoac
#   `tHardHighestChapterData.MainChapter` (difficulty 2). Nen `Next` khong bao
#   gio vuot tran — do la BAT BIEN bo kiem nay khoa lai.
#   `RefreshChapterData` (:1313) = refreshSwitchButton + refreshTargetRewardLayer
#   + createChapterData(nMainChapter, nDifficulty).
#
#   O AI DANG KHOA bi chan o HAI tang, khong phai mot:
#     (a) `setEnableLuaTouch(false)` — `CUISelectLevel.lua:1490` cho o lon dong,
#         `:1569` cho o nho. `cocos.lua:465` ghi meta `lua_touch`, va
#         `lua_runtime.gd:927` (`_nhan_duoc`) doi meta ay PHAI truthy — nen o
#         khoa khong con la ung vien nhan cham nao ca, chu khong phai "nhan roi
#         tu choi".
#     (b) `onTouchEnd_OnSelectLevel` (:1248) van con cong
#         `tChapterData[nIndex].BattleStatus == 0 -> Exit0` cho truong hop (a)
#         bi go.
#   Bo kiem nay do CA HAI: (a) bang chinh meta cua node, (b) bang cu cham that.
#
# ---------------------------------------------------------------------------
# BAY DO DUOC, dung so `tMark` tho giua hai luot chay: `createChapterData` duyet
# `for i, v in pairs(self.tChapterData)` (:1401) roi ghi `tMark[v.SubChapter] = i`,
# nen CHI SO ben trong doi giua cac luot — do duoc `tMark[1]` = 1, 7, 3, 16 o bon
# luot. Nhung cap (tag -> du lieu) ma nguoi choi thay thi ON DINH, vi `tMark` va
# cac o ai cung dung tu mot bang. Nen bo kiem nay KHONG khoa mot con so `tMark`
# nao: no khoa BAT BIEN `tChapterData[tMark[tag]].SubChapter == tag` cho moi tag.
# Do dung la tinh chat ma phep duyet `pairs` co the pha — neu lech thi nguoi choi
# thay mot o MO ma bam vao lai ra ai khac — va no dung voi MOI thu tu duyet, nen
# khong bao gio do theo mot lan chay may man.
extends SceneTree

const VM := preload("res://tools/vao_main.gd")
const KHUNG := 1.0 / 30.0
## So khung cho sau khi Main hien — du cho hoat canh treo `DelayTime(0)` cua
## `CUIMain.lua:251` chay va cho `CGameFuncOpeningManager` mo khoa nut.
const CHO := 30
## Ten cham cua nut tan cong tren man Main (`CUIMain.lua:2778` -> Show(SelectLevel)).
const NUT_VAO := "btnMainExtraUIAttack"
## Ten cham cua tung o ai: ham cua ban goc la `onTouchEnd_OnSelectLevel`.
const O_AI := "OnSelectLevel"

var _dat := 0
var _hong := 0
var _lua: LuaRuntime
var _san: Control
var _da_in := 0


func _ghi_chu(ok: bool, mo_ta: String) -> void:
	if ok:
		_dat += 1
	else:
		_hong += 1
	print("   %s %s" % ["dat " if ok else "HONG", mo_ta])


func _init() -> void:
	_lua = LuaRuntime.new()
	var vp := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 640)))
	_lua.cua_so_engine = Vector2(roundf(768.0 * vp.x / vp.y), 768.0)
	if not _lua.open():
		print("KHONG chay duoc: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	XggLayout.respect_visible = true
	_san = Control.new()
	_san.size = _lua.cua_so_engine
	_san.scale = Vector2.ONE * (vp.y / _lua.cua_so_engine.y)
	_lua.set_stage(_san)
	_lua.set_touch_root(_san)
	get_root().add_child(_san)
	if _lua.run(VM._NAP, "nap") == null:
		print("nap hong: %s" % ", ".join(_lua.errors))
		quit(1)
		return
	var d := VM.chay(_lua)
	if str(d["dung"]) != "":
		print("KHONG toi duoc Main, dung o: %s" % d["dung"])
		quit(1)
		return
	print("toi Main.")

	# --- A. Vao man chon ai bang cu cham THAT ------------------------------
	# Duong NGUOI CHOI di. `bam_that.gd` cung di duong nay, nhung no chi hoi
	# "qua duoc khong"; o day phai chac chan man da mo TRUOC khi do cac widget,
	# khong thi moi phep do sau do do mot man khac.
	print("\nA. cham THAT vao nut tan cong [%s] tren man Main:" % NUT_VAO)
	_nha(CHO)
	var ten_man := str(_lua.run("return tostring(g_CUISelectLevel:GetUIName())", "ten man"))
	var vao := _bam_ten(NUT_VAO)
	print("   cham -> nhan: %s (tim thay %d node)" % [vao[2], vao[1]])
	_ghi_chu(str(vao[2]) != "KHONG AI NHAN", "co node nhan cu cham (do: %s)" % vao[2])
	_nha(90)
	var a := _doc()
	_ghi_chu(str(a["dialog"]) == ten_man,
			"man chon ai MO ra: CurrentUIName = %s (doi %s) — do: %s"
			% [ten_man, ten_man, a["dialog"]])
	_ghi_chu(str(a["lSelectLevel"]) == "true",
			"node lSelectLevel co tren san khau va dang hien — do: %s" % a["lSelectLevel"])
	_ghi_chu(str(a["canh"]) == "Main", "van o canh Main — do: %s" % a["canh"])

	# --- B. Bon widget dieu huong ----------------------------------------
	print("\nB. bon widget cua man chon ai:")
	for ten in ["btnPrevious", "btnNext", "NormalChapter", "HardChapter"]:
		_ghi_chu(str(a[ten]) == "true", "%s co (theo tag trong ban goc) — do: %s"
				% [ten, a[ten]])

	# --- C. Tab Normal / Hard --------------------------------------------
	print("\nC. doi tab (Normal <-> Hard):")
	print("   truoc: nDifficulty=%s nCurrentTab=%s" % [a["nDifficulty"], a["nCurrentTab"]])
	_ghi_chu(str(a["nDifficulty"]) == "1" and str(a["nCurrentTab"]) == "1",
			"mo ra o tab Normal: nDifficulty=1 nCurrentTab=1 — do: %s/%s"
			% [a["nDifficulty"], a["nCurrentTab"]])
	_lua.run("g_CUISelectLevel:onClickTag(g_CUISelectLevel.HardChapter, 2) return true", "sang Hard")
	_nha(CHO)
	var c2 := _doc()
	print("   Hard: nDifficulty=%s nCurrentTab=%s" % [c2["nDifficulty"], c2["nCurrentTab"]])
	_ghi_chu(str(c2["nDifficulty"]) == "2" and str(c2["nCurrentTab"]) == "2",
			"bam tab Hard: nDifficulty=2 nCurrentTab=2 — do: %s/%s"
			% [c2["nDifficulty"], c2["nCurrentTab"]])
	_lua.run("g_CUISelectLevel:onClickTag(g_CUISelectLevel.NormalChapter, 1) return true", "ve Normal")
	_nha(CHO)
	var c3 := _doc()
	_ghi_chu(str(c3["nDifficulty"]) == "1" and str(c3["nCurrentTab"]) == "1",
			"bam tab Normal: ve lai 1/1 — do: %s/%s (chieu nguoc lai)"
			% [c3["nDifficulty"], c3["nCurrentTab"]])

	# --- D. Tien/lui chuong ----------------------------------------------
	# `onToPrevious`/`onToNext` deu tra `true` KE CA khi khong doi gi (:1795,
	# :1837), nen "handler tra true" khong noi duoc gi. Phai do `nMainChapter`.
	print("\nD. nut Previous / Next doi chuong:")
	var tran := int(c3["nHighest"])
	print("   tran chuong (tNormalHighestChapterData.MainChapter) = %d, dang o chuong %s"
			% [tran, c3["nMainChapter"]])
	_ghi_chu(str(c3["nMainChapter"]) == "1", "mo ra o chuong 1 — do: %s" % c3["nMainChapter"])

	# Ep len chuong 2 roi lui ve 1: KIEM CHUNG NGUOC. Khong ep thi "bam Previous
	# khong doi gi" o chuong 1 la ket qua DUNG (1-1 = 0, khong > 0), va no khong
	# phan biet duoc handler song hay chet.
	_lua.run("g_CUISelectLevel.nMainChapter = 2 g_CUISelectLevel.nSubChapter = nil "
			+ "g_CUISelectLevel:RefreshChapterData() return true", "ep chuong 2")
	_nha(CHO)
	var d2 := _doc()
	_ghi_chu(str(d2["nMainChapter"]) == "2",
			"ep duoc len chuong 2 (RefreshChapterData chay) — do: %s" % d2["nMainChapter"])
	_bam_ham("g_CUISelectLevel:onTouchEnd_onToPrevious(g_CUISelectLevel.btnPrevious, true)")
	_nha(CHO)
	var d3 := _doc()
	_ghi_chu(str(d3["nMainChapter"]) == "1",
			"bam Previous tu chuong 2 -> ve 1, tuc handler SONG (khong phai bi chan) — do: %s"
			% d3["nMainChapter"])

	# Next: tu chuong 1 no chi duoc len 2 khi tran >= 2. Ky vong lay tu `tran` do
	# o tren (doc tu chinh bang cau hinh), khong lay tu chinh cu bam.
	_bam_ham("g_CUISelectLevel:onTouchEnd_onToNext(g_CUISelectLevel.btnNext, true)")
	_nha(CHO)
	var d4 := _doc()
	var mong := 2 if tran >= 2 else 1
	_ghi_chu(int(d4["nMainChapter"]) == mong,
			"bam Next o chuong 1 -> %d (tran %d; btnNext gray=%s) — do: %s"
			% [mong, tran, d4["nextXam"], d4["nMainChapter"]])
	# Bat bien: bam Next 5 lan nua cung khong duoc vuot tran. Dung cho ca hai
	# truong hop, va la thu ma cong `nHighestChapter >= nNextChapter` (:1828) hua.
	for i in 5:
		_bam_ham("g_CUISelectLevel:onTouchEnd_onToNext(g_CUISelectLevel.btnNext, true)")
		_nha(4)
	var d5 := _doc()
	_ghi_chu(int(d5["nMainChapter"]) <= tran,
			"bam Next 5 lan nua KHONG vuot tran: dang o %s, tran %d — do: %s"
			% [d5["nMainChapter"], tran, d5["nMainChapter"]])
	_ghi_chu(int(d5["nMainChapter"]) == tran,
			"va dung lai DUNG o tran: %s == %d" % [d5["nMainChapter"], tran])

	# --- E. Cac o ai: dem, roi cham vao o KHOA va o MO --------------------
	#
	# DO DUOC, va la ly do nhom nay dem hai lan o hai phia khac nhau: so node
	# MANG TEN CHAM khong bang so ai cua chuong. Do het ho `spChapterSelect*`
	# trong cay: 23 node, trong do
	#   7 node la MAU CAT SAN cua kho node (`lSelectLevelWidget` dang AN, vi tri
	#     x am) — mot node cho moi bien the, khong phai ai nao;
	#   16 node la o ai that, ung voi 12 muc `tAllSubChapter` (bon o lon mang
	#     them mot node `spChapterSelectSamllClosse` con, cung tag).
	# 12 ai do chia BA kieu:
	#   7 o KHOA ve bang `spChapterSelectSamllOpen` — KHONG co ten cham nao;
	#   4 o KHOA ve bang `spChapterSelectLarge`    — co ten `OnSelectLevel`,
	#     nhung `setEnableLuaTouch(false)`;
	#   1 o MO  ve bang `spChapterSelectCurrent`  — ten `OnSelectLevel`, cham BAT.
	# Nen "chi 1 trong 12 bam duoc" la DUNG: du lieu chuong 1-1 chi co dung mot
	# dong `BattleStatus ~= 0` (do: 12 dong qua bo loc, 1 dong battle=1).
	# Vi vay phep dem phai lam o PHIA LUA (du 12), con phep cham lam o phia cay.
	print("\nE. cac o ai:")
	var e0 := _doc_ai()
	print("   tAllSubChapter=%s  dong qua bo loc=%s  ai mo=%s khoa=%s  tag lech=%s"
			% [e0["so_sub"], e0["so_qua_loc"], e0["so_mo"], e0["so_khoa"], e0["so_mark_lech"]])
	_ghi_chu(int(e0["so_sub"]) > 0, "tAllSubChapter co ai (%s muc)" % e0["so_sub"])
	_ghi_chu(str(e0["so_sub"]) == str(e0["so_qua_loc"]),
			"so muc tAllSubChapter (%s) == so dong qua bo loc cua createChapterData (%s)"
			% [e0["so_sub"], e0["so_qua_loc"]])
	# BAT BIEN chong cai bay `pairs`: `createChapterData` duyet `pairs(tChapterData)`
	# (:1401) nen CHI SO doi giua cac luot, nhung cap (tag -> ai) thi khong duoc
	# lech — neu lech thi nguoi choi thay o MO ma bam vao lai ra ai khac.
	_ghi_chu(str(e0["so_mark_lech"]) == "0",
			"tMark TU NHAT QUAN: moi tag -> du lieu mang dung SubChapter do (so tag lech: %s) — phep kiem nay dung voi MOI thu tu duyet"
			% e0["so_mark_lech"])
	_ghi_chu(int(e0["so_mo"]) >= 1 and int(e0["so_khoa"]) >= 1,
			"co CA ai mo lan ai khoa de doi chieu hai chieu (mo=%s khoa=%s)"
			% [e0["so_mo"], e0["so_khoa"]])

	# Phia CAY: chi nhung o co ten cham moi cham duoc, nen day la tap con.
	var o_ai := _tim(O_AI)
	print("   node mang ten cham %s (tap con cham duoc): %d" % [O_AI, o_ai.size()])
	_ghi_chu(o_ai.size() > 0, "man co o ai cham duoc (%d node)" % o_ai.size())
	var ds_mo: Array = []
	var ds_khoa: Array = []
	for n in o_ai:
		var c: Control = n
		var tag := int(c.get_meta("tag", -1))
		var tt := _doc_o_ai(tag)
		if int(tt["battle"]) < 0:
			continue
		var dong := {
			"node": c, "tag": tag, "battle": int(tt["battle"]),
			"lua_touch": bool(c.get_meta("lua_touch", true)),
			"sub": int(tt["sub"]),
		}
		if int(tt["battle"]) == 0:
			ds_khoa.append(dong)
		else:
			ds_mo.append(dong)
		print("   tag=%-3d sub=%-3s battle=%-2d lua_touch=%-5s o=%s"
				% [tag, str(tt["sub"]), int(tt["battle"]),
					str(bool(c.get_meta("lua_touch", true))), str(c.size)])
	_ghi_chu(ds_mo.size() >= 1 and ds_khoa.size() >= 1,
			"trong tap cham duoc co CA o mo lan o khoa (mo=%d khoa=%d)"
			% [ds_mo.size(), ds_khoa.size()])

	# E1. Cham vao o KHOA — PHAI khong mo gi. Hai tang chan, do tang (a) bang
	# chinh meta cua node va tang (b) bang cu cham that.
	if ds_khoa.size() > 0:
		var k: Dictionary = ds_khoa[0]
		var kn: Control = k["node"]
		_ghi_chu(k["lua_touch"] == false,
				"o khoa (tag=%d) da bi setEnableLuaTouch(false): meta lua_touch=%s"
				% [k["tag"], str(k["lua_touch"])])
		var cu_k := _cham(kn)
		print("   cham o KHOA tag=%d o %s -> nhan: %s" % [k["tag"], str(cu_k[0]), cu_k[1]])
		_nha(60)
		var e1 := _doc()
		_ghi_chu(str(e1["dialog"]) == ten_man and str(e1["lChapterInfo"]) == "false",
				"cham o KHOA KHONG mo man thong tin ai (dialog=%s lChapterInfo hien=%s)"
				% [e1["dialog"], e1["lChapterInfo"]])

	# E2. Cham vao o MO — PHAI mo man thong tin ai. Day la chieu khang dinh; thieu
	# no thi E1 chi la "khong co gi xay ra", dung y het mot handler chet.
	if ds_mo.size() > 0:
		var m: Dictionary = ds_mo[0]
		var mn: Control = m["node"]
		var cu_m := _cham(mn)
		print("   cham o MO tag=%d (sub=%s) o %s -> nhan: %s"
				% [m["tag"], str(m["sub"]), str(cu_m[0]), cu_m[1]])
		_nha(60)
		var e2 := _doc()
		print("   nSubChapter=%s (nil la BINH THUONG: onClose cua CUISelectLevel (:499) xoa no khi man thong tin ai mo)"
				% e2["nSubChapter"])
		_ghi_chu(str(e2["dialog"]) == "ChapterInfo",
				"cham o MO mo man thong tin ai: CurrentUIName=%s — do: %s"
				% [e2["dialog"], e2["dialog"]])
		_ghi_chu(str(e2["lChapterInfo"]) == "true",
				"node lChapterInfo co tren san khau va dang hien — do: %s" % e2["lChapterInfo"])
		# `IsUiVisible` trong ban dung la TRUONG BOOLEAN, khong phai phuong thuc:
		# goi `:IsUiVisible()` nem loi va lam hong ca doan Lua.
		_ghi_chu(str(e2["chapterInfoHien"]) == "true",
				"g_CUIChapterInfo.IsUiVisible = true — do: %s" % e2["chapterInfoHien"])

	print("\ndat %d, hong %d" % [_dat, _hong])
	quit(1 if _hong > 0 else 0)


func _nha(so: int) -> void:
	for i in so:
		_lua.tick(KHUNG)


## Goi mot ham Lua cua ban goc, roi nha khung. Gom loi Lua ra de mot doan hong
## khong im lang di qua.
func _bam_ham(doan: String) -> void:
	_lua.run(doan + " return true", "goi " + doan.substr(0, 40))
	_xa_loi()


func _xa_loi() -> void:
	while _da_in < _lua.errors.size():
		print("   loi Lua: %s" % str(_lua.errors[_da_in]).substr(0, 200))
		_da_in += 1


## Trang thai cua man chon ai. Mot luot Lua, nhieu cau hoi — de moi cau tra loi
## roi vao CUNG mot khung hinh. Dung `Dictionary()` chu KHONG phai `{}`: bang Lua
## tran qua cau ra LuaTable, ma ham nay khai kieu tra ve la Dictionary nen
## GDScript nem loi kieu (cung loi da gay o tools/quet_show.gd).
func _doc() -> Dictionary:
	var r = _lua.run("""
		local function lay(f) local ok, v = pcall(f) return ok and tostring(v) or ('?' .. tostring(v)) end
		local L = g_CUISelectLevel
		local out = Dictionary()
		out.dialog = lay(function() return g_CUINormalDlg:GetCurrentUIName() end)
		out.canh = lay(function() return g_CSceneManager:GetCurrentSceneName() end)
		out.nMainChapter = lay(function() return L.nMainChapter end)
		out.nDifficulty = lay(function() return L.nDifficulty end)
		out.nCurrentTab = lay(function() return L.nCurrentTab end)
		out.nextXam = lay(function() return L.btnNext:isGray() end)
		-- Tran chuong lay tu chinh bang cau hinh ma `onToNext` (:1820-1824) doc.
		out.nHighest = lay(function()
			if L.nDifficulty == 1 then return L.tNormalHighestChapterData.MainChapter end
			return L.tHardHighestChapterData.MainChapter end)
		for _, ten in ipairs({ 'btnPrevious', 'btnNext', 'NormalChapter', 'HardChapter' }) do
			out[ten] = tostring(L[ten] ~= nil)
		end
		local l = rawget(_G, 'lSelectLevel')
		out.lSelectLevel = tostring(l ~= nil and l:getIsVisible())
		local ci = rawget(_G, 'lChapterInfo')
		out.lChapterInfo = tostring(ci ~= nil and ci:getIsVisible())
		local C = rawget(_G, 'g_CUIChapterInfo')
		out.chapterInfoHien = tostring(C ~= nil and C.IsUiVisible)
		out.nSubChapter = tostring(L.nSubChapter)
		return out
	""", "doc man chon ai")
	_xa_loi()
	# Doan Lua hong thi tra bang RONG co san moi khoa: doc thang `d["thieu"]` tren
	# mot Dictionary khong co khoa ay la loi truy cap, va no che mat loi that.
	var rong := {}
	for k in ["dialog", "canh", "nMainChapter", "nDifficulty", "nCurrentTab",
			"nextXam", "nHighest", "btnPrevious", "btnNext", "NormalChapter",
			"HardChapter", "lSelectLevel", "lChapterInfo", "chapterInfoHien",
			"nSubChapter"]:
		rong[k] = "?"
	if r == null:
		return rong
	return r


## Cac con so cua man chon ai, do o PHIA LUA — du 12 ai, khong phu thuoc vao
## node nao tinh co mang ten cham. `so_mark_lech` dem so tag ma
## `tChapterData[tMark[tag]].SubChapter` KHAC chinh tag do: do la bat bien ma
## phep duyet `pairs` o `createChapterData` (:1401) co the pha, va no dung voi
## moi thu tu duyet nen khong phai mot con so chet.
func _doc_ai() -> Dictionary:
	var r = _lua.run("""
		local L = g_CUISelectLevel
		local out = Dictionary()
		local so_sub, so_qua, so_mo, so_khoa, lech = 0, 0, 0, 0, 0
		for _ in pairs(L.tAllSubChapter or {}) do so_sub = so_sub + 1 end
		for _, d in pairs(L.tChapterData or {}) do
			if d.ChapterDifficulty == L.nDifficulty and d.SubChapter <= L.nLevelCapacity then
				so_qua = so_qua + 1
				if d.BattleStatus == 0 then so_khoa = so_khoa + 1 else so_mo = so_mo + 1 end
			end
		end
		-- tMark co 20 o, cac o 13..20 giu `false` (khong co ai nao) — bo qua chung.
		for tag, i in pairs(L.tMark or {}) do
			if type(tag) == 'number' and type(i) == 'number' then
				local d = L.tChapterData[i]
				if d == nil or d.SubChapter ~= tag then lech = lech + 1 end
			end
		end
		out.so_sub = so_sub
		out.so_qua_loc = so_qua
		out.so_mo = so_mo
		out.so_khoa = so_khoa
		out.so_mark_lech = lech
		return out
	""", "doc so lieu ai")
	_xa_loi()
	if r == null:
		return {"so_sub": -1, "so_qua_loc": -1, "so_mo": -1, "so_khoa": -1, "so_mark_lech": -1}
	return r


## Du lieu ma o ai mang `tag` tro toi, di DUNG duong cua ban goc:
## tag -> `tMark[tag]` -> `tChapterData[...]`. Tra `{battle, sub}`; `battle = -1`
## nghia la khong doc duoc (o do khong nam trong bang).
func _doc_o_ai(tag: int) -> Dictionary:
	var r = _lua.run("""
		local L = g_CUISelectLevel
		local out = Dictionary()
		local i = L.tMark and L.tMark[%d]
		if type(i) ~= 'number' then out.battle = -1 out.sub = -1 return out end
		local d = L.tChapterData and L.tChapterData[i]
		if d == nil or d.BattleStatus == nil or d.SubChapter == nil then
			out.battle = -1 out.sub = -1 return out
		end
		out.battle = math.floor(d.BattleStatus)
		out.sub = math.floor(d.SubChapter)
		return out
	""" % tag, "doc o ai tag %d" % tag)
	_xa_loi()
	if r == null:
		return {"battle": -1, "sub": -1}
	return r


## Cham vao tam mot node bang dung duong cham cua ban goc (`touch_at` -> ten cham
## trong .xgg -> `onTouchEnd_<ten>` cua doi tuong nhan). Tra [toa do, ten node
## nhan] — goi thang ham thi bo qua dung cai phan dang nghi (node do co nhan cu
## cham khong).
func _cham(c: Control) -> Array:
	var p: Vector2 = LuaRuntime._bien_doi(c) * (c.size * 0.5)
	var an := _lua.touch_at("Begin", p)
	var nhan: Node = _lua._dang_cham
	_lua.touch_at("End", p)
	_xa_loi()
	var ten := "KHONG AI NHAN"
	if an and nhan != null:
		ten = String(nhan.get_meta("xgg_name", nhan.get_meta("cls", nhan.name)))
	return [p.round(), ten]


## Tim node dang hien mang ten cham `ten`, roi cham vao node DAU TIEN.
## Tra [toa do, so node tim thay, ten node nhan].
func _bam_ten(ten: String) -> Array:
	var ds := _tim(ten)
	if ds.is_empty():
		return [Vector2.ZERO, 0, "KHONG AI NHAN"]
	var cu := _cham(ds[0])
	return [cu[0], ds.size(), cu[1]]


## Node dang hien (ca chuoi cha) mang ten cham `ten`, theo thu tu cay.
func _tim(ten: String) -> Array:
	var ds: Array = []
	_gom(_san, ten, ds)
	return ds


func _gom(n: Node, ten: String, ds: Array) -> void:
	# Nhanh bi an thi bo ca nhanh — `lua_runtime.gd:_ung_vien` cung bo, nen node
	# dang an khong bao gio la ung vien that.
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control and n.has_meta("touch") and String(n.get_meta("touch")) == ten:
		ds.append(n)
	for c in n.get_children():
		_gom(c, ten, ds)
