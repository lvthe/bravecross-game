# Kiem tang cau hinh: 104 bang so cua ban goc.
#
#   godot --headless --path . --script tools/verify_lua_config.gd
#
# Cai duoc kiem KHONG phai code cua minh — ma la: ConfigManager cua ban goc
# (5.063 dong) co doc duoc du lieu that qua ba cay cau minh bac hay khong.
#
#   ClientConfigManager:GetConfigTableWithName(ten)
#     -> JsonFile.Load(LGG_GetPathWithFileName("config/share/<ten>.xgg"))
#
# Ba ham do la tat ca nhung gi minh phai lam. Neu bo kiem nay xanh thi moi
# bang so ban goc doc luc chay deu san sang, khong phai bom tay tung cai.
extends SceneTree

var ok := 0
var bad := 0


func t(name: String, cond: bool, note: String = "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("  HONG: %s%s" % [name, ("  (%s)" % note) if note else ""])


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(
			"res://data_ref/config")):
		print("thieu data_ref/config — chay: python ../brave-cross/work/config_tables.py")
		quit(1)
		return

	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return

	var t0 := Time.get_ticks_msec()
	var r = lua.run("""
		local boot = require('bootstrap')
		boot.install_cocos()
		boot.install()
		local nap = boot.boot({})
		local out = Dictionary()
		for k, v in pairs(nap) do if v ~= 'ok' then out['NAP ' .. k] = v end end
		out['Init'] = boot.init_config()

		-- Bang ROI: doc thang mot file, phai ra BANG LUA that (ipairs chay).
		local co, cfg = JsonFile.Load('config/share/KDBGamePrizeConfig.xgg')
		out['doc file'] = tostring(co)
		out['kieu'] = type(cfg)
		local n = 0
		if type(cfg) == 'table' then for _ in ipairs(cfg) do n = n + 1 end end
		out['so muc'] = n

		-- Qua duong cua ban goc.
		local p = G_ConfigManager:GetPrizeConfigWithID(1)
		out['prize 1'] = type(p)
		out['prize 1 co PrizeContent'] = tostring(type(p) == 'table'
			and p.PrizeContent ~= nil)

		-- Phai tra bang DAU CHAM roi moi goi: 'obj:ten and ...' la loi cu phap
		-- trong Lua, dau hai cham bat buoc phai keo theo loi goi.
		local it = nil
		if type(G_ConfigManager.GetItemConfigWithId) == 'function' then
			it = G_ConfigManager:GetItemConfigWithId(1)
		end
		out['item 1'] = type(it)

		-- Chu tieng Viet van phai chay (bang chu la duong khac).
		out['chu'] = GetStringWithKey('AchieveUI_Description_101_1')

		-- Ham engine ma lop gia lap CO lam that: phai la HAM THAT, khong duoc
		-- la BONG. Mot ten engine quen lam thi im lang di nhanh sai, vi bong
		-- dem ra so sanh voi chuoi luon ra 'khac'. Da gap that voi
		-- LGG_GetPlatformString: no thanh bong, KDebug.lua:181 so bong voi
		-- "windows" nen di vao nhanh Android/iOS roi goi
		-- sngDownload:getCurResVersion() — ma `sngDownload` ra nil theo luat
		-- bien_lua — va MOI dong loi deu nem loi, lam CUIAchieve:Reflesh dung
		-- giua duong. Xem ROADMAP, muc "Ten ma chinh Lua ban goc gan".
		local doi = {
			'LGG_GetPlatformString', 'LGG_GetPathWithFileName', 'LGG_IsFileExist',
			'LGG_GetSetFilePath', 'sngUtil_getDownloadPath',
			'sngUtil_getTempDownloadPath', 'sngUtil_getFileData',
			'sngUtil_getFileSize', 'sngUtil_getIDFV', 'LGG_GetUtf8WordLen',
			'GetStringWithKey', 'GetCNStringWithKey',
		}
		local bong = {}
		for _, ten in ipairs(doi) do
			if boot.la_bong(_G[ten]) then bong[#bong + 1] = ten end
		end
		out['bong engine'] = table.concat(bong, ' ')

		out['platform'] = tostring(LGG_GetPlatformString())
		out['platform la chuoi'] =
			tostring(type(LGG_GetPlatformString()) == 'string')
		out['thu muc tai co /'] = sngUtil_getDownloadPath():sub(-1)
		out['getFileData(nil)'] = sngUtil_getFileData(nil) == nil and 'nil' or 'khac'
		out['getFileSize(khong co)'] = tostring(sngUtil_getFileSize('khong/co/that'))
		-- Luat bien_lua: 6.901 ten, va phai doc duoc so luong bang so_thieu()
		-- chu khong bang '#' (bang dem khong co phan mang).
		out['so bien_lua'] = tostring(boot.so_bien_lua)
		out['so_thieu la so'] = tostring(type(boot.so_thieu()) == 'number')
		return out
	""", "cau hinh")
	var ms := Time.get_ticks_msec() - t0
	if r == null:
		print("Lua hong: %s" % ", ".join(lua.errors))
		quit(1)
		return

	for k in r:
		if String(k).begins_with("NAP "):
			print("  HONG nap %s: %s" % [String(k).substr(4), r[k]])
			bad += 1

	t("ConfigManager cua ban goc Init xong", String(r.get("Init", "")) == "ok",
			String(r.get("Init", "?")))
	t("doc duoc file cau hinh", String(r.get("doc file", "")) == "true")
	t("ra BANG LUA that chu khong userdata", String(r.get("kieu", "")) == "table",
			String(r.get("kieu", "?")))
	t("bang phan thuong co du muc", int(r.get("so muc", 0)) > 2000,
			"%d muc" % int(r.get("so muc", 0)))
	t("GetPrizeConfigWithID(1) ra bang", String(r.get("prize 1", "")) == "table",
			String(r.get("prize 1", "?")))
	t("phan thuong co PrizeContent",
			String(r.get("prize 1 co PrizeContent", "")) == "true")
	t("GetItemConfigWithId(1) ra bang", String(r.get("item 1", "")) == "table",
			String(r.get("item 1", "?")))
	t("bang chu tieng Viet van chay",
			String(r.get("chu", "")).find("Lôi Đài") >= 0,
			String(r.get("chu", "?")))

	# Ham engine phai la ham THAT. Mot ten quen lam thi khong nem loi, khong ra
	# nil — no ra mot BONG, va bong so voi chuoi luon ra 'khac'. Do la cach
	# LGG_GetPlatformString lam mat mot man hinh (xem chu thich trong khoi Lua).
	t("khong ham engine nao bi lam bong",
			String(r.get("bong engine", "?")) == "",
			String(r.get("bong engine", "?")))
	t("LGG_GetPlatformString tra chuoi that",
			String(r.get("platform la chuoi", "")) == "true")
	# Ban goc CO ban Windows that (GameOS.lua, OS_TYPE.WINDOWS), va 24 cho trong
	# sc/ dem chuoi nay ra so sanh. Ta chay tren Windows nen phai tra dung chu do.
	t("he dieu hanh tra 'windows'", String(r.get("platform", "")) == "windows",
			String(r.get("platform", "?")))
	t("thu muc tai ve co dau phan cach cuoi",
			String(r.get("thu muc tai co /", "")) == "/",
			String(r.get("thu muc tai co /", "?")))
	t("doc file khong ton tai ra nil",
			String(r.get("getFileData(nil)", "?")) == "nil")
	t("co file khong ton tai ra 0",
			String(r.get("getFileSize(khong co)", "?")) == "0",
			String(r.get("getFileSize(khong co)", "?")))
	# Luat bien_lua phai con song: 6.901 ten, va so_thieu() dem duoc (khong dung
	# '#' — thieu_bien_lua la bang dem theo ten nen '#' luon la 0).
	t("luat bien_lua nap du 6.901 ten",
			int(r.get("so bien_lua", 0)) == 6901, String(r.get("so bien_lua", "?")))
	t("so_thieu() tra ve so", String(r.get("so_thieu la so", "")) == "true")
	# 104 bang, ~6,5 MB. Cham hon nhieu la co gi do doc lai nhieu lan.
	t("nap het trong 5 giay", ms < 5000, "%d ms" % ms)
	print("  -> nap ca tang cau hinh mat %d ms" % ms)

	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
