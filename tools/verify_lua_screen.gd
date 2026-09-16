# Mo MOT MAN HINH cua ban goc bang DUNG DUONG CUA NO, khong sua mot chu nao
# trong ma cua no.
#
#   godot --headless --path . --script tools/verify_lua_screen.gd
#
# Truoc day phep kiem nay tu dung bo cuc, tu goi onInit, tu goi setDialogVisible
# — tuc minh dong vai bo nap. Nay chi lam dung mot viec cua engine (dung khung
# chung UI_NormalDlg_960_640, vi no la thu duy nhat co san truoc moi thu khac),
# roi goi MOT dong:
#
#     g_CUISubDialog:Show('AchieveUI')
#
# va ca chuoi con lai la ma goc: nap bo cuc bang loadLevelFile, onInit, hoat
# canh mo, onShow, setDialogVisible, onVisible, Reflesh.
#
# Nhung bien toan cuc cua khung suon ma minh chua lam (g_CUIHelper,
# G_SoundManager...) van la BONG — xem lua/bootstrap.lua. Bong lam sai hanh vi,
# nen bao cao cuoi bai liet ke chung ra.
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
	if not FileAccess.file_exists("res://sc/share/class.lua"):
		print("thieu ma nguon ban goc — chay: python tools/import_lua.py")
		quit(1)
		return
	var lua := LuaRuntime.new()
	if not lua.open():
		print("KHONG chay duoc: %s" % ", ".join(lua.errors))
		quit(1)
		return

	# Ton trong co hien/an cua file: gio ma goc tu bat len.
	XggLayout.respect_visible = true
	# Khung chung cua hop thoai. Bo cuc cua CHINH man thanh tuu thi khong dung
	# o day — ban goc tu nap no qua loadLevelFile.
	var nen := XggLayout.build("res://layout_ref/UI_NormalDlg_960_640.json")
	t("dung duoc khung hop thoai", nen != null)
	if nen == null:
		_done()
		return
	var n := lua.bind_layout(nen)
	t("dat duoc bien toan cuc", n > 0, "dat %d" % n)
	var goc := XggLayout.find_node(nen, "UIRootLayer")
	t("co UIRootLayer", goc != null)
	if goc == null:
		_done()
		return
	goc.position = Vector2.ZERO
	lua.set_ui_root(goc)

	# Nap khung suon that, theo dung thu tu ban goc phu thuoc.
	var r = lua.run(_NAP, "nap khung suon")
	if r == null:
		t("nap khung suon", false)
		_done()
		return
	var so_module := int(r.get("so module", 0))
	var nap_duoc := int(r.get("nap duoc", 0))
	for k in r:
		if str(k).begins_with("HONG "):
			print("  %s: %s" % [k, r[k]])
	t("cau hinh nap duoc", str(r.get("cau hinh", "")) == "ok",
			str(r.get("cau hinh", "?")))
	# 875/876. Cai duy nhat hong la user.UI.CUIChapterChoice — ban ke khai cua
	# chinh ban goc doi mot file khong he co trong 973 file da ship.
	t("nap gan het ma goc", so_module > 800 and so_module - nap_duoc <= 1,
			"%d/%d module" % [nap_duoc, so_module])
	print("  -> nap %d/%d module cua ban goc" % [nap_duoc, so_module])
	print("  luc nap doc ra nil: %s" % str(r.get("doc ra nil", "?")))
	print("  so bien_lua = %s, so thieu = %s" % [r.get("so bien_lua", "?"), r.get("so thieu", "?")])

	# MOT DONG. Tu day tro di khong con dong nao cua minh.
	var d = lua.run(_SHOW, "mo man hinh")
	t("Show() chay het", d != null and str(d.get("Show", "")) == "ok",
			str(d.get("Show", "?")) if d != null else "?")
	if d == null:
		_done()
		return
	t("loadLevelFile nap bo cuc cua man hinh",
			str(d.get("nap bo cuc", "")) == "true", str(d.get("nap bo cuc", "?")))
	print("  so muc seed tu cau hinh = %s" % str(d.get("so muc lay tu cau hinh", "?")))
	t("bo cuc duoc nap vao UIRootLayer",
			str(d.get("nam trong UIRootLayer", "")) == "true",
			str(d.get("nam trong UIRootLayer", "?")))
	# onInit chi chay khi su kien OnLoadXGG ban ra — tuc khi CLevelLoader ghi
	# ten xgg vao danh sach cua canh dang choi. Day la cho de hong nhat: ten
	# canh la nil thi ca chuoi im lang, khong bao gi.
	t("onInit() da chay (ScrollLayer duoc dat)",
			str(d.get("onInit", "")) == "true", str(d.get("onInit", "?")))
	t("onShow() da chay va bat goc man hinh len",
			str(d.get("IsUiShow", "")) == "true", str(d.get("IsUiShow", "?")))

	# Hoat canh mo keo 0,19 giay (PopUp 0,15 + lui 0,04). Phai day thoi gian
	# roi moi hoi — chinh no goi nguoc ve OnShowAnimationFinish.
	for i in range(20):
		lua.tick(0.05)
	var sau = lua.run(_SAU, "sau hoat canh")
	if sau == null:
		_done()
		return
	t("hoat canh mo xong thi setDialogVisible chay",
			str(sau.get("IsUiVisible", "")) == "true",
			str(sau.get("IsUiVisible", "?")))
	t("goc man hinh ve dung cho cu sau hoat canh",
			str(sau.get("vi tri", "")) == "110,30", str(sau.get("vi tri", "?")))
	t("ty le ve 1 sau hoat canh",
			str(sau.get("ty le", "")) == "1,1", str(sau.get("ty le", "?")))
	# SetOpenZorder: 150 la CUISubDialog.OpenZorder (CUIManager.lua:1847).
	t("goc man hinh len dung z = OpenZorder",
			str(sau.get("zOrder", "")) == str(sau.get("OpenZorder", "x")),
			"%s / %s" % [sau.get("zOrder", "?"), sau.get("OpenZorder", "?")])
	t("lop che cua hop thoai con hien len",
			str(sau.get("che hien", "")) == "true", str(sau.get("che hien", "?")))
	# Khac han hop thoai thuong: CUINormalDlg dat MaskOpacity = 0 (khong lam
	# toi man), con hop thoai con khong dat gi nen CPublic dung 179.
	var mo := float(str(sau.get("che mo", "0")))
	t("lop che mo dan toi 179", absf(mo - 179.0) < 1.0, "%.1f" % mo)
	# Danh sach nhan du 6 muc; so DONG DUNG DUOC co the it hon, vi mot vai ma
	# phan thuong doi du lieu nguoi choi (o dang do lam, o thu 6 la mot phan
	# thuong quan linh va ArmyDataManager chua co du lieu doi hinh). Neu cho
	# hong ca danh sach vi mot o thi khong con do duoc gi.
	t("danh sach nhan du 6 muc", str(sau.get("ItemCellNumber sau", "")) == "6",
			str(sau.get("ItemCellNumber sau", "?")))
	t("dung duoc it nhat 5 dong", int(sau.get("so dong", -1)) >= 5,
			str(sau.get("so dong", "?")))
	for k in sau:
		if str(k).begins_with("O HONG"):
			print("      %s = %s" % [k, sau[k]])
	print("  doc ra nil: %s" % str(sau.get("doc ra nil", "?")))

	# Bao cao: con thieu nhung gi.
	var ghosts = lua.run("""
		local boot = require('bootstrap')
		local out = Dictionary()
		for k, v in pairs(boot.report()) do out[k] = v end
		return out
	""", "bao cao bong")
	if ghosts != null:
		var keys := []
		for k in ghosts:
			keys.append([int(ghosts[k]), String(k)])
		keys.sort_custom(func(a, b): return a[0] > b[0])
		print("\n  Bien toan cuc cua khung suon ma minh CHUA LAM (%d cai):"
				% keys.size())
		for e in keys:
			print("      %-34s x%d" % [e[1], e[0]])

	var miss := lua.missing()
	print("\n  API Cocos bi goi ma CHUA LAM (%d loai):" % miss.size())
	var mk := []
	for k in miss:
		mk.append([int(miss[k]), String(k)])
	mk.sort_custom(func(a, b): return a[0] > b[0])
	for e in mk:
		print("      %-34s x%d" % [e[1], e[0]])

	for e in lua.errors:
		print("  loi Lua: %s" % e)
	nen.free()
	_done()


func _done() -> void:
	print("\ndat %d, hong %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


## Nap khung suon, ke ca ba module cua duong Show.
## Nap khung suon.
const _NAP := """
	local boot = require('bootstrap')
	-- install_cocos truoc install: duong Show chay ma THAT, ma ma that goi
	-- GetStringWithKey roi nem thang ket qua vao string.format. De no la bong
	-- thi bong tra ve mot cai bang, va format bao 'string expected, got table'
	-- — loi hien o ma goc chu khong o cho thieu.
	boot.install_cocos()
	boot.install()
	-- Do xem luc NAP doc tien bien nao ra nil: trong bong thi mot ten doc ra
	-- BONG (khac nil), ma `if X == nil then` trong ma goc re sang nhanh khac.
	boot.danh_dau()
	local out = Dictionary()
	-- Nap TOAN BO ma goc theo dung bon ban ke khai cua no (876 module), chu
	-- khong phai mot danh sach ngan minh chon. Khac nhau rat lon: cai gi
	-- khong nap thi la bong, ma bong goi ra MOT gia tri, nen
	-- 'local bRet, data = G_XLogic:GetY()' cho data = nil va man hinh hong o
	-- dong sau — trong nhu la thieu du lieu may chu chu khong phai thieu module.
	local bao = boot.boot_goc()
	out['so module'] = bao.so
	out['nap duoc'] = bao.nap
	for m, e in pairs(bao.hong) do out['HONG ' .. m] = e end
	out['cau hinh'] = boot.init_config()
	out['so bien_lua'] = boot.so_bien_lua
	out['so thieu'] = boot.so_thieu()
	do
		local dem = {}
		for _, k in ipairs(boot.tu_dau) do dem[k] = (dem[k] or 0) + 1 end
		local dk = {}
		for k, v in pairs(dem) do dk[#dk + 1] = v .. ' ' .. k end
		table.sort(dk)
		out['doc ra nil'] = table.concat(dk, ' | ')
	end
	return out
"""


## Do du lieu vao roi goi DUNG MOT dong cua ban goc.
const _SHOW := """
	local out = Dictionary()
	local boot = require('bootstrap')
	-- Do xem doan nay doc tien bien nao ra nil (xem bootstrap.danh_dau).
	boot.danh_dau()
	-- Ban goc luon dang o trong MOT CANH, va CLevelLoader ghi ten xgg da nap
	-- vao danh sach cua canh do; ten canh la nil thi registerPreloadXgg bo
	-- qua, khong ban tin OnLoadXGG, va onInit khong bao gio chay. Ta chua
	-- dung canh Main nen dat la "Test" — mot canh co that cua ban goc.
	g_CSceneManager.CurrentScene = 'Test'

	-- Du lieu thanh tuu lay tu CHINH BANG CAU HINH cua ban goc
	-- (KDBGameAchieveConfig, 357 muc), khong phai so minh bia. Truoc day minh
	-- dat AchieveType = 101..106 va Award = {1..6}; ca hai deu sai kieu — loai
	-- that la so nho (0..21, va 101/102), con Award la danh sach ma phan thuong
	-- 3 chu so tro len ([401], [501], [601]). Bia sai thi
	-- CUIPrizeResHelper:getPrizeResInfo tra ve nil va ca dong hong.
	--
	-- Bo loai 0 va 1 (Reflesh bo qua), va 3/7/12/15 (nhung loai do con hoi
	-- g_CGameFuncOpeningManager xem tinh nang da mo chua).
	local BO_QUA = { [0] = true, [1] = true, [3] = true, [7] = true,
		[12] = true, [15] = true }
	local bando = {}
	local dem = 0
	-- Hoi tung muc mot bang dung ham tra cuu cua ban goc,
	-- GetAchieveConfig(loai, chi so). Bang tra ve co the long nhieu tang tuy
	-- ban, nen di thang bang ham chac hon la tu duyet.
	for loai = 2, 21 do
		if dem >= 6 then break end
		if not BO_QUA[loai] then
			-- Bang cau hinh duoc bam theo CHUOI:
			-- achieveConfig[tostring(loai)][tostring(chi so)]
			-- (share_configManager.lua:1034). Truyen so thi tra ve nil.
			local cfg = G_ConfigManager:GetAchieveConfig(tostring(loai), '1')
			if type(cfg) == 'table' and cfg.Award ~= nil then
				local aw = cfg.Award
				if type(aw) == 'string' then aw = cjson.decode(aw) end
				-- Chi nhan muc nao co phan thuong TRA CUU DUOC. Vai ma phan
				-- thuong trong bang tro toi loai vat pham can them du lieu
				-- may chu (vi du anh hung theo PrizeProperty), va ma goc thi
				-- tra nil roi hong o CUIRewardLayer:739. Day la chon du lieu
				-- kiem, khong phai che gia tri.
				local dung = false
				if type(aw) == 'table' and aw[1] ~= nil then
					-- pcall: vai ma phan thuong lam ham tra cuu nem loi chu
					-- khong chi tra nil.
					pcall(function()
						local b1, pc = G_PrizeLogic:GetPrizeWithID(aw[1])
						if b1 and type(pc) == 'table'
								and type(pc.PrizeContent) == 'table'
								and type(pc.PrizeContent[1]) == 'table' then
							-- Phai tra cuu duoc MOI muc trong PrizeContent,
							-- khong chi muc dau: CUIAchieve.lua:499 duyet het.
							dung = true
							for _, muc in ipairs(pc.PrizeContent) do
								local b2, ti = g_CUIPrizeResHelper:getPrizeResInfo(muc)
								if b2 ~= true or type(ti) ~= 'table' then
									dung = false
									break
								end
							end
						end
					end)
				end
				if dung then
					dem = dem + 1
					bando[tostring(dem)] = {
						AchieveType = loai, AchieveIndex = 1,
						State = (dem % 2 == 0) and AchieveState.Done
								or AchieveState.Doing,
						Current = 1, Total = 3, Award = { aw[1] },
					}
				end
			end
		end
	end
	out['so muc lay tu cau hinh'] = dem
	local L = rawget(_G, 'G_AchieveLogic')
	if L ~= nil then
		L.UserAchieveMap = bando
		L.bIsInited = true
	end

	local ok, err = pcall(function() g_CUISubDialog:Show('AchieveUI') end)
	out['Show'] = ok and 'ok' or tostring(err)

	local g = rawget(_G, 'lAchieveTaskUI')
	out['nap bo cuc'] = tostring(g ~= nil)
	if g ~= nil then
		local cha = require('cocos').raw(g):get_parent()
		out['nam trong UIRootLayer'] = tostring(
			cha ~= nil and tostring(cha:get_meta('xgg_name')) == 'UIRootLayer')
	end
	local ui = g_CUISubDialog.UI['AchieveUI']
	out['onInit'] = tostring(ui ~= nil and ui.ScrollLayer ~= nil)
	out['IsUiShow'] = tostring(ui ~= nil and ui.IsUiShow == true)
	return out
"""


## Sau khi day het hoat canh mo.
const _SAU := """
	local out = Dictionary()
	local ui = g_CUISubDialog.UI['AchieveUI']
	local g = ui:GetRootUI()
	out['IsUiVisible'] = tostring(ui:IsUIVisible())
	local px, py = g:getPosition()
	out['vi tri'] = px .. ',' .. py
	out['ty le'] = g:getScaleX() .. ',' .. g:getScaleY()
	out['zOrder'] = tostring(g:getZOrder())
	out['OpenZorder'] = tostring(g_CUISubDialog.OpenZorder)
	out['che hien'] = tostring(lSubDialogMask:getIsVisible())
	out['che mo'] = tostring(lSubDialogMask:getOpacity())
	local tv = ui.AchieveTableView
	local inner = tv and tv.tableView
	out['so dong'] = (inner ~= nil and inner.cells ~= nil) and #inner.cells or -1
	out['DataList'] = ui.AchieveDataList and #ui.AchieveDataList or -1
	-- So MUC danh sach nhan duoc (khac so DONG dung duoc: mot o hong thi
	-- cocos.lua ghi lai roi di tiep chu khong giet ca danh sach).
	out['ItemCellNumber sau'] = tostring(tv and tv.ItemCellNumber)
	-- Ten ma doan nay doc ra nil vi luat `bien_lua` (bootstrap.install): ten do
	-- CHINH Lua ban goc dat, nhung module dat no khong nam trong bon ban ke
	-- khai nen no chua duoc nap. Ban goc cung doc ra nil o day — khac han bong,
	-- va khac han la mot loi. In ra de biet minh dang thieu module nao.
	local boot = require('bootstrap')
	if boot.tu_dau ~= nil then
		local dem = {}
		for _, k in ipairs(boot.tu_dau) do dem[k] = (dem[k] or 0) + 1 end
		local dk = {}
		for k, v in pairs(dem) do dk[#dk + 1] = v .. ' ' .. k end
		table.sort(dk)
		out['doc ra nil'] = table.concat(dk, ' | ')
	end
	for i, e in ipairs(require('cocos').cell_errors) do out['O HONG ' .. i] = e end
	return out
"""
