-- Luat trang bi — ban Lua cua sim/equipment.py, chay tren may chu.
--
-- Moi he so o day chep tu ban goc, KHONG tu can bang lai:
--
--   share_EquipmentLogic.lua          cuong hoa, chi phi, pham chat
--   share_EquipmentPropertyLogic.lua  gia tri cuong hoa theo loai chi so
--   share_configManager.lua:3221      trong so quy ra luc chien
--   Protocol.lua:466                  enum PropertyType
--
-- Ba ban cai dat cua cung mot mo hinh, doi chieu nhau tung ca:
--   sim/equipment.py            mo hinh goc, Python
--   battle/equipment.gd         ban GDScript (client)
--   server/modules/equipment.lua  ban nay (may chu)
--
-- Day la module LUAT THUAN — khong require("nakama"), khong dong den ban luu.
-- Nho vay ca may chu lan bai test deu nap duoc, va no la cho duy nhat giu
-- cong thuc: RPC nao can thi require lay, khong chep lai.
--
-- Mot mon trang bi la mot bang:
--   { part = 1..6, level = n, intensify = n, quality = n,
--     main = { type = <PropertyType>, value = x },
--     appends = { { type = ..., value = ... }, ... } }

local M = {}

-- ---------------------------------------------------------- Protocol.lua:466
M.HP_LIMIT = 1
M.REDUCING_DAMAGE = 3
M.FIRE_RES = 5
M.ICE_RES = 6
M.THUNDER_RES = 7
M.DP_ADDITION = 8
M.CRITICAL_STRIKE = 16
M.AP = 20

M.PROPERTY_NAME = {
	[M.HP_LIMIT] = "HpLimit",
	[M.REDUCING_DAMAGE] = "ReducingDamage",
	[M.FIRE_RES] = "FireResistence",
	[M.ICE_RES] = "IceResistence",
	[M.THUNDER_RES] = "ThunderResistence",
	[M.DP_ADDITION] = "DpAddtion",
	[M.CRITICAL_STRIKE] = "CriticalStrike",
	[M.AP] = "Ap",
}

-- ------------------------------------------------- share_configManager:3221
-- Trong so quy tung loai chi so ra LUC CHIEN. Bang nay noi len thang thiet ke:
-- 1 diem chi mang dang 50, 1 diem mau dang 0.1 — mau di theo hang nghin con
-- chi mang theo phan tram.
M.CAPACITY_WEIGHT = {
	[M.HP_LIMIT] = 0.1,
	[M.DP_ADDITION] = 1.0,
	[M.FIRE_RES] = 18.0,
	[M.ICE_RES] = 18.0,
	[M.THUNDER_RES] = 18.0,
	[M.CRITICAL_STRIKE] = 50.0,
	[M.AP] = 0.9,
}

-- ---------------------------------------------------- share_EquipmentLogic
M.APPEND_UNLOCK_LEVEL = 4      -- AppendPropertyUnlockLevel
M.APPEND_RANGE_MIN = 0.8       -- AppendPropertyRandomRangeMin
M.APPEND_RANGE_MAX = 1.3       -- AppendPropertyRandomRangeMax
M.RECAST_ITEM_ID = 97          -- RecastStroeItemID — da tay luyen

--- Moi cap cuong hoa nhan them he so nay; qua 200 cap thi gap 2.4 lan.
M.INTENSIFY_STEP = 2.4 ^ (1.0 / 200.0)

-- ------------------------------------- Chi so chinh sinh tu loai/cap/pham
-- share_EquipmentPropertyLogic:getMainPropertyValWithCoefficient
--
--   Ap        : 20 * (L + 10 + Q*6)^1.45 / (60 - J*6)
--   HpLimit   : 30 * (L + 10 + Q*5)^1.5  / (20 + J*10)
--   DpAddtion : 5  * (L + 10 + Q*6)^1.45 / (20 + J*8)
--
-- L khong phai cap mon do ma la HE SO CAP: getEquipLevelCoefficient tra ve
-- dung cot HeroLevel cua bang ghep do. Tuc bang ghep do vua la bang gia, vua
-- la thang suc manh.
--
-- EquipmentType = LOAI O * 10 + NGHE (Protocol.lua:322).
M.EQUIP_CATEGORY_WEAPON = 0
M.EQUIP_CATEGORY_ARMOR = 20
M.EQUIP_CATEGORY_SHOES = 30
M.EQUIP_CATEGORY_NECKLACE = 40
M.EQUIP_CATEGORY_RING = 50

M.MAIN_PROPERTY_BY_CATEGORY = {
	[M.EQUIP_CATEGORY_WEAPON] = M.AP,
	[M.EQUIP_CATEGORY_ARMOR] = M.DP_ADDITION,
	[M.EQUIP_CATEGORY_SHOES] = M.HP_LIMIT,
	[M.EQUIP_CATEGORY_NECKLACE] = M.HP_LIMIT,
	[M.EQUIP_CATEGORY_RING] = M.DP_ADDITION,
}

M.MAIN_PROPERTY_COEF = {
	[M.HP_LIMIT] = 30.0,
	[M.DP_ADDITION] = 5.0,
	[M.CRITICAL_STRIKE] = 0.0025,
	[M.AP] = 20.0,
}

M.JOB_COEF = { 1.0, 2.0, 3.0, 4.0, 5.0 }
M.MAX_EQUIP_LEVEL = 10

function M.equip_job(equip_type)
	return math.floor(equip_type) % 10
end

function M.equip_category(equip_type)
	return math.floor(equip_type) - M.equip_job(equip_type)
end

function M.main_property_type(equip_type)
	return M.MAIN_PROPERTY_BY_CATEGORY[M.equip_category(equip_type)]
end

--- Chi so chinh goc, truoc tinh luyen va cuong hoa.
--- CriticalStrike KHONG co nhanh nao trong ham goc (nhanh thu tu la ban sao
--- cua DpAddtion — loi go cua tac gia), nen tra 0 chu khong bia cong thuc.
function M.main_property_val(prop_type, level_coef, quality, job)
	local coef = M.MAIN_PROPERTY_COEF[prop_type]
	local j = M.JOB_COEF[math.floor(job or 0)]
	if coef == nil or j == nil then
		return 0.0
	end
	local q = quality + 0.0
	local lc = level_coef + 0.0
	if prop_type == M.AP then
		return coef * ((lc + 10.0 + q * 6.0) ^ 1.45) / (60.0 - j * 6.0)
	elseif prop_type == M.HP_LIMIT then
		return coef * ((lc + 10.0 + q * 5.0) ^ 1.5) / (20.0 + j * 10.0)
	elseif prop_type == M.DP_ADDITION then
		return coef * ((lc + 10.0 + q * 6.0) ^ 1.45) / (20.0 + j * 8.0)
	end
	return 0.0
end

-- ------------------------------------------ Ghep do (SynthesisEquipment)
-- Ghep do la NANG CAP MON DO len mot cap: tru vang, tru nguyen lieu, roi
-- EquipLevel + 1. Chi so chinh tinh LAI theo cap moi.

--- Mot dong bang ghep do. `table` la { ["<loai>_<cap>"] = {...} }.
function M.synthesis_row(tbl, equip_type, level)
	if tbl == nil then
		return nil
	end
	return tbl[string.format("%d_%d", math.floor(equip_type), math.floor(level))]
end

--- He so cap de tinh chi so chinh — chinh la cot HeroLevel.
function M.level_coefficient(tbl, equip_type, level)
	local row = M.synthesis_row(tbl, equip_type, level)
	return row and (row.heroLevel + 0.0) or 0.0
end

--- Co ghep len duoc khong. Tra ve (duoc, ly do).
---
--- Ban goc CO cot HeroLevel va co doc no, nhung cho kiem lai vo hieu:
--- `if HeroLevel < need then if ProcessError(bRecode) ... end end`, ma bRecode
--- luc do dang true nen than lenh khong bao gio chay. O day ta CHAN that —
--- mot dieu kien co trong bang ma khong ai kiem thi bang do vo nghia.
function M.synthesis_ready(tbl, equip_type, level, hero_level)
	if math.floor(level) >= M.MAX_EQUIP_LEVEL then
		return false, "da toi cap cao nhat"
	end
	local row = M.synthesis_row(tbl, equip_type, math.floor(level) + 1)
	if row == nil then
		return false, string.format("khong co cong thuc ghep cho loai %d cap %d",
				math.floor(equip_type), math.floor(level) + 1)
	end
	if math.floor(hero_level) < math.floor(row.heroLevel) then
		return false, string.format("can tuong cap %d", math.floor(row.heroLevel))
	end
	return true, ""
end

-- --------------------------------------------------- Tinh luyen (RefineLevel)
-- Bang lay tu KDBGameCommonConfig, muc ConfigName = "EquipRefineConfig": mot
-- mang 5 o, moi o 5 cap, moi cap { NeedConcentrate, AddPrecent }.
--
-- Tinh luyen CONG PHAN TRAM vao chi so chinh, khong cong thang mot luong:
--   share_EquipmentPropertyLogic:getMainPropertyVal
--   val = val + val * AddPrecent / 100
M.MAX_REFINE_LEVEL = 5
M.REFINE_ADD_PERCENT = { 5, 10, 15, 20, 25 }
-- Vu khi dat hon cac o khac dung mot bac — bang goc ghi the.
M.REFINE_COST_WEAPON = { 40, 80, 160, 320, 640 }
M.REFINE_COST_OTHER = { 30, 60, 120, 240, 480 }
-- Gia tinh bang TINH HOA (Concentrate), ResourceType 8 — tai nguyen rieng,
-- khong phai vang. Ban goc cho tinh hoa tu viec phan giai vat pham.
M.VIP_REFINE_DISCOUNT_LEVEL = 10      -- HeroLogic:GetUpgradeRefineCost
M.VIP_REFINE_DISCOUNT = 0.2

--- Phan tram cong them vao chi so chinh o cap tinh luyen nay.
function M.refine_percent(refine_level)
	local lv = math.floor(refine_level or 0)
	if lv >= 1 and lv <= M.MAX_REFINE_LEVEL then
		return M.REFINE_ADD_PERCENT[lv] + 0.0
	end
	return 0.0
end

function M.refine_multiplier(refine_level)
	return 1.0 + M.refine_percent(refine_level) / 100.0
end

--- Tinh hoa can de len cap tinh luyen `refine_level` (1..5).
--- VIP 10 tro len duoc giam 20%, lam TRON LEN.
function M.refine_cost(part, refine_level, vip_level)
	local lv = math.floor(refine_level or 0)
	if lv < 1 or lv > M.MAX_REFINE_LEVEL then
		return 0
	end
	local tbl = (part == 1) and M.REFINE_COST_WEAPON or M.REFINE_COST_OTHER
	local cost = tbl[lv]
	if (vip_level or 0) >= M.VIP_REFINE_DISCOUNT_LEVEL then
		return math.ceil(cost * (1.0 - M.VIP_REFINE_DISCOUNT))
	end
	return cost
end

--- Chi so chinh SAU tinh luyen.
--- Ban goc nhan phan tram tinh luyen ngay trong getMainPropertyVal, tuc moi
--- thu tinh sau do — ke ca cuong hoa — deu dua tren con so da nhan.
function M.main_value(e)
	return e.main.value * M.refine_multiplier(e.refine or 0)
end

--- Tinh hoa can de tinh luyen mon nay len mot cap. Het cap thi 0.
function M.refine_cost_next(e, vip_level)
	local lv = math.floor(e.refine or 0)
	if lv >= M.MAX_REFINE_LEVEL then
		return 0
	end
	return M.refine_cost(e.part, lv + 1, vip_level)
end

--- increment = (Val / 25) * (2.4^(1/200))^level
--- share_EquipmentLogic:GetIntensifiedIncrementWithLevel
function M.intensify_increment(level, value)
	return (value / 25.0) * (M.INTENSIFY_STEP ^ level)
end

-- Gia tri cuong hoa phu thuoc LOAI chi so: moi loai mot mau so va mot moc
-- rieng. share_EquipmentPropertyLogic:getIntensifyPropertyVal
local INTENSIFY_BY_TYPE = {
	[M.AP] = { 35.0, 10 },
	[M.HP_LIMIT] = { 25.0, 50 },
	[M.DP_ADDITION] = { 30.0, 50 },
}

--- Gia tri cuong hoa DUNG DE TINH LUC CHIEN, y het client ban goc.
---
--- Client ban goc KHONG dung cap cuong hoa o day — no dung mot moc CO DINH
--- rieng cho tung loai (Ap moc 10, HpLimit va DpAddtion moc 50). Da kiem: ham
--- co dung cap (GetIntensifiedIncrementWithLevel) chi duoc goi tu
--- GetIntensifiedIncrement, ma ham do BI COMMENT TOAN BO trong ban phat hanh.
--- Xem M.intensify_total cho duong tang that.
function M.intensify_property_val(main_value, prop_type)
	local spec = INTENSIFY_BY_TYPE[prop_type]
	if spec == nil then
		return 0.0
	end
	return main_value / spec[1] * (M.INTENSIFY_STEP ^ spec[2])
end

--- Tong gia tri cuong hoa cong don tu cap 1 den `level`.
---
--- Cong thuc cua chinh tac gia ban goc (GetIntensifiedIncrement), nhung ham do
--- da bi comment het trong ban phat hanh — duong tang that nam ben may chu ho,
--- thu ta khong co. Game moi dung lai cong thuc nay vi do la y do goc.
function M.intensify_total(level, base_value)
	local sum = 0.0
	for i = 1, math.floor(level or 0) do
		sum = sum + M.intensify_increment(i, base_value)
	end
	return sum
end

--- Chi phi len cap cuong hoa tiep theo. Nhan doi moi 4,5 cap luc dau, gian ra
--- 6,5 cap sau cap 31 — ban goc co y lam cham lam phat o khoang giua.
--- share_EquipmentLogic:GetResourceForIntensifyWithQualityAndLevel
function M.intensify_cost(level)
	local n = level - 1
	if n > 30 then
		return 140.0 * ((2.0 ^ (1.0 / 6.5)) ^ n)
	end
	return 25.0 * ((2.0 ^ (1.0 / 4.5)) ^ n)
end

--- (baseVal/coefficient + 0.3) / quality — share_EquipmentLogic:GetQualityRange
function M.quality_range(base_value, coefficient, quality)
	if coefficient == nil or coefficient == 0 or quality == nil or quality == 0 then
		return 0.0
	end
	return (base_value / coefficient + 0.3) / quality
end

function M.weight_of(prop_type)
	return M.CAPACITY_WEIGHT[prop_type] or 0.0
end

function M.append_unlocked(e)
	return (e.level or 1) >= M.APPEND_UNLOCK_LEVEL
end

--- { [loai chi so] = tong gia tri } sau cuong hoa va thuoc tinh phu.
function M.stats(e)
	local out = {}
	local t, v = e.main.type, M.main_value(e)
	out[t] = (out[t] or 0.0) + v
	local bonus = M.intensify_total(e.intensify or 0, v)
	if bonus ~= 0 then
		out[t] = (out[t] or 0.0) + bonus
	end
	if M.append_unlocked(e) then
		for _, ap in ipairs(e.appends or {}) do
			out[ap.type] = (out[ap.type] or 0.0) + ap.value
		end
	end
	return out
end

--- Luc chien: tung chi so nhan trong so cua no roi cong lai.
function M.capacity(e)
	local sum = 0.0
	for t, v in pairs(M.stats(e)) do
		sum = sum + v * M.weight_of(t)
	end
	return sum
end

--- Luc chien tinh Y HET client ban goc, de doi chieu: dung moc co dinh thay vi
--- cong don theo cap, nen KHONG doi theo cap cuong hoa.
--- share_EquipmentLogic:CalcEquipFightingCapacity
function M.capacity_as_original(e)
	local t, v = e.main.type, M.main_value(e)
	local out = (v + M.intensify_property_val(v, t)) * M.weight_of(t)
	if M.append_unlocked(e) then
		for _, ap in ipairs(e.appends or {}) do
			out = out + ap.value * M.weight_of(ap.type)
		end
	end
	return out
end

function M.cost_to_next(e)
	return M.intensify_cost((e.intensify or 0) + 1)
end

--- Tong chi phi cuong hoa tu cap hien tai len `target`.
function M.cost_to_level(e, target)
	local cur = e.intensify or 0
	if target <= cur then
		return 0.0
	end
	local sum = 0.0
	for lv = cur + 1, target do
		sum = sum + M.intensify_cost(lv)
	end
	return sum
end

--- Gia tri mot thuoc tinh phu: ngau nhien 0,8..1,3 lan gia tri goc.
--- `rand` la ham tra ve so trong [0,1) — truyen vao de con dat hat giong.
function M.roll_append(base_value, rand)
	return base_value * (M.APPEND_RANGE_MIN
		+ rand() * (M.APPEND_RANGE_MAX - M.APPEND_RANGE_MIN))
end

-- Trang bi noi vao mo hinh chien dau qua DUNG cai kenh buff ma the tran dang
-- dung (apply_buffs trong battle.lua) — khong mo duong rieng.
--
-- Bon loai chi so co cho tuong ung; ba loai khang he va ReducingDamage thi
-- CHUA co he tuong ung ben game moi, nen bo qua co y thuc.
M.BUFF_KEY = {
	[M.HP_LIMIT] = "hp",
	[M.AP] = "ap",
	[M.DP_ADDITION] = "dp",
	[M.CRITICAL_STRIKE] = "crit",
}

--- Gop chi so cua mot dam trang bi thanh bang buff cho mo hinh chien dau.
function M.to_buffs(items)
	local out = {}
	for _, e in ipairs(items or {}) do
		for t, v in pairs(M.stats(e)) do
			local k = M.BUFF_KEY[t]
			if k ~= nil then
				out[k] = (out[k] or 0.0) + v
			end
		end
	end
	return out
end

--- Cong hai bang buff. Trang bi va the tran di chung mot bang, cong don tung
--- khoa — nho vay thu tu ap dung khong con quan trong, va ba ban cai dat chac
--- chan ra cung mot so.
function M.merge_buffs(a, b)
	local out = {}
	for k, v in pairs(a or {}) do
		out[k] = v
	end
	for k, v in pairs(b or {}) do
		out[k] = (out[k] or 0.0) + v
	end
	return out
end

--- Dung mon do dung kieu ban goc: chi so chinh SINH RA tu loai/cap/pham.
function M.make_equipment(tbl, equip_type, level, quality, part, opts)
	opts = opts or {}
	local ptype = M.main_property_type(equip_type)
	local val = M.main_property_val(ptype,
			M.level_coefficient(tbl, equip_type, level), quality,
			M.equip_job(equip_type))
	opts.level = level
	opts.quality = quality
	opts.equipType = equip_type
	return M.make(part, ptype, val, opts)
end

--- Dung mot mon trang bi tu cac truong roi, dien san mac dinh.
function M.make(part, prop_type, value, opts)
	opts = opts or {}
	return {
		part = part,
		level = opts.level or 1,
		intensify = opts.intensify or 0,
		quality = opts.quality or 1,
		refine = opts.refine or 0,
		equipType = opts.equipType or 0,

		main = { type = prop_type, value = value },
		appends = opts.appends or {},
	}
end

return M
