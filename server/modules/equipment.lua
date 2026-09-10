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

-- ---------------------- Nang pham chat (PromoteQualityEquipment)
-- Bang: KDBGameCommonConfig / GameEquipQualityPromotionConfig, khoa la PHAM
-- DICH (2..6). Pham chat an vao HAI cho — chi so chinh va thuoc tinh phu —
-- nen len mot pham la manh len ca hai duong.
M.MAX_QUALITY = 6

function M.quality_row(tbl, quality)
	if tbl == nil then
		return nil
	end
	return tbl[tostring(math.floor(quality))]
end

--- Co nang pham duoc khong. Tra ve (duoc, ly do).
function M.quality_ready(tbl, quality, hero_level)
	local q = math.floor(quality or 1)
	if q >= M.MAX_QUALITY then
		return false, "da toi pham cao nhat"
	end
	local row = M.quality_row(tbl, q + 1)
	if row == nil then
		return false, string.format("khong co cong thuc nang len pham %d", q + 1)
	end
	if math.floor(hero_level or 1) < math.floor(row.unlockLevel) then
		return false, string.format("can tuong cap %d", math.floor(row.unlockLevel))
	end
	return true, ""
end

-- ------------------------ Thuoc tinh phu va tay luyen (RecastEquipment)
-- share_EquipmentPropertyLogic:getAppendPropertyValue
--
--   value = coef * (base * quality - 0.3) * (levelCoef / 20)
--
-- `base` la so BOC RA trong dai 0.8..1.3; tay luyen chinh la boc lai no.
M.AP_MIN = 22
M.AP_MAX = 23
M.CRIT_MULT = 25

M.APPEND_COEF = {
	[M.HP_LIMIT] = 40.0,
	[M.AP_MIN] = 2.7,
	[M.AP_MAX] = 11.8,
	[M.DP_ADDITION] = 2.5,
	[M.CRITICAL_STRIKE] = 0.1,
	[M.CRIT_MULT] = 50.0,
}

-- Thuoc tinh phu QUY RA LUC CHIEN theo DAI boc duoc, khong phai theo gia tri
-- nhan trong so (CalcEquipFightingCapacity).
M.APPEND_SCORE_BANDS = {
	{ 1.2, 60 }, { 1.1, 40 }, { 1.0, 30 }, { 0.9, 20 }, { 0.8, 10 },
}

M.RECAST_COST_GOLD = 10000
M.RECAST_COST_DIAMOND = 100

-- Loai chi so phu -> { kenh buff, he so doi don vi }. Chi mang cua ban goc
-- tinh theo DIEM PHAN TRAM, mo hinh chien dau ben nay dung phan so.
M.APPEND_TO_BUFF = {
	[M.HP_LIMIT] = { "hp", 1.0 },
	[M.AP_MAX] = { "ap", 1.0 },
	[M.AP_MIN] = { "ap", 1.0 },
	[M.DP_ADDITION] = { "dp", 1.0 },
	[M.CRITICAL_STRIKE] = { "crit", 0.01 },
	[M.CRIT_MULT] = { "crit_mult", 0.01 },
}

function M.append_value(base, prop_type, quality, level_coef)
	local coef = M.APPEND_COEF[prop_type]
	if coef == nil then
		return 0.0
	end
	return coef * (base * quality - 0.3) * (level_coef / 20.0)
end

--- Diem luc chien cua mot thuoc tinh phu, cham theo DAI boc duoc.
function M.append_score(base)
	local val = 0
	for _, row in ipairs(M.APPEND_SCORE_BANDS) do
		if base > row[1] and row[2] > val then
			val = row[2]
		end
	end
	return val
end

--- Boc mot lan: so trong dai 0.8..1.3.
function M.roll_append_base(rand)
	return M.APPEND_RANGE_MIN + rand() * (M.APPEND_RANGE_MAX - M.APPEND_RANGE_MIN)
end

--- { type, value, base } — giu ca `base` vi luc chien cham theo no.
function M.make_append(prop_type, base, quality, level_coef)
	return {
		type = prop_type,
		value = M.append_value(base, prop_type, quality, level_coef),
		base = base,
	}
end

--- Tong diem cac thuoc tinh phu.
function M.append_score_total(e)
	if not M.append_unlocked(e) then
		return 0
	end
	local sum = 0
	for _, ap in ipairs(e.appends or {}) do
		sum = sum + M.append_score(ap.base or 1.0)
	end
	return sum
end

--- Tay luyen: boc LAI toan bo thuoc tinh phu. Loai chi so giu nguyen, chi
--- con so doi — dung y updateAppendProperty cua ban goc.
function M.recast(e, rand, level_coef)
	local out = {}
	for i, ap in ipairs(e.appends or {}) do
		out[i] = M.make_append(ap.type, M.roll_append_base(rand),
				e.quality or 1, level_coef)
	end
	e.appends = out
	return out
end

-- ---------------------------------- Trang bi chuyen thuoc (ExclusiveEquip)
-- Mon do thuong tay toi bac 5 (+25%) thi REN len duoc thanh do chuyen thuoc —
-- neu tuong do nam trong danh sach 22 tuong co do rieng. Do chuyen thuoc dung
-- mot duong tay KHAC HAN: 21 bac (0..20), bat dau ngay o +25% va len toi
-- +125%. Tuc no noi tiep dung cho duong thuong dung lai.
M.MAX_PURIFY_LEVEL = 20

--- Ky nang cua do chuyen thuoc: { ten, khoa buff, gia tri }.
--- O 1 (vu khi) co ky nang RIENG theo tung tuong, khong nam trong bang chung.
M.EXCLUSIVE_SKILL = {
	[2] = { "ZhuanShuYiFu", "immune_normal", 0.10 },
	[3] = { "ZhuanShuXieZi", "taken_skill", -0.15 },
	[4] = { "ZhuanShuXiangLian", "crit", 0.10 },
	[5] = { "ZhuanShuJieZhi", "crit_mult", 0.25 },
}

local function purify_rows(tbl, part)
	if tbl == nil or tbl.purify == nil then
		return nil
	end
	return tbl.purify[math.floor(part)]
end

--- Phan tram cong vao chi so chinh cua do CHUYEN THUOC.
--- Co gia tri ngay tu bac 0 (+25%): ban goc viet `nRefineLevel >= 0`.
function M.exclusive_percent(tbl, part, purify_level)
	local rows = purify_rows(tbl, part)
	if rows == nil then
		return 0.0
	end
	local i = math.max(0, math.min(math.floor(purify_level or 0), #rows - 1))
	return rows[i + 1].percent + 0.0
end

--- Tinh hoa de len bac tay `purify_level` (1..20) cua do chuyen thuoc.
function M.exclusive_cost(tbl, part, purify_level)
	local rows = purify_rows(tbl, part)
	local lv = math.floor(purify_level or 0)
	if rows == nil or lv < 1 or lv > #rows - 1 then
		return 0
	end
	return rows[lv + 1].need
end

--- Co ren len do chuyen thuoc duoc khong. Tra ve (duoc, ly do).
function M.exclusive_ready(tbl, hero_id, part, refine_level)
	if tbl == nil then
		return false, "khong co bang do chuyen thuoc"
	end
	local found = false
	for _, id in ipairs(tbl.heroes or {}) do
		if math.floor(id) == math.floor(hero_id) then
			found = true
			break
		end
	end
	if not found then
		return false, "tuong nay khong co do chuyen thuoc"
	end
	local row = (tbl.forge or {})[string.format("%d_%d", math.floor(hero_id),
			math.floor(part))]
	if row == nil then
		return false, "khong co cong thuc ren cho o nay"
	end
	if math.floor(refine_level or 0) < math.floor(row.purifyLevel) then
		return false, string.format("can tinh luyen bac %d",
				math.floor(row.purifyLevel))
	end
	return true, ""
end

function M.exclusive_forge_row(tbl, hero_id, part)
	if tbl == nil then
		return nil
	end
	return (tbl.forge or {})[string.format("%d_%d", math.floor(hero_id),
			math.floor(part))]
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
--- Phan tram cong vao chi so chinh: duong thuong hay duong chuyen thuoc.
function M.bonus_percent(e)
	if e.exclusive then
		return e.purifyPercent or 0.0
	end
	return M.refine_percent(e.refine or 0)
end

function M.main_value(e)
	return e.main.value * (1.0 + M.bonus_percent(e) / 100.0)
end

--- Ky nang mon do cho. Chi do chuyen thuoc moi co.
function M.skills(e)
	if not e.exclusive then
		return {}
	end
	local row = M.EXCLUSIVE_SKILL[math.floor(e.part or 0)]
	return row and { row } or {}
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
--- Luc chien mon do (CalcEquipFightingCapacity): chi so chinh (da gom cuong
--- hoa) nhan trong so, CONG tong DIEM cua thuoc tinh phu. Thuoc tinh phu
--- khong nhan trong so — no cham theo dai boc duoc.
function M.capacity(e)
	local t = e.main.type
	local sum = (M.stats(e)[t] or 0.0) * M.weight_of(t)
	return sum + M.append_score_total(e)
end

--- Luc chien tinh Y HET client ban goc, de doi chieu: dung moc co dinh thay vi
--- cong don theo cap, nen KHONG doi theo cap cuong hoa.
--- share_EquipmentLogic:CalcEquipFightingCapacity
function M.capacity_as_original(e)
	local t, v = e.main.type, M.main_value(e)
	local out = (v + M.intensify_property_val(v, t)) * M.weight_of(t)
	return out + M.append_score_total(e)
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
		local mt = e.main.type
		local k = M.BUFF_KEY[mt]
		if k ~= nil then
			out[k] = (out[k] or 0.0) + (M.stats(e)[mt] or 0.0)
		end
		-- Thuoc tinh PHU co bang rieng vi don vi khac.
		if M.append_unlocked(e) then
			for _, ap in ipairs(e.appends or {}) do
				local pair = M.APPEND_TO_BUFF[ap.type]
				if pair ~= nil then
					out[pair[1]] = (out[pair[1]] or 0.0) + ap.value * pair[2]
				end
			end
		end
		-- Ke ca ky nang cua do chuyen thuoc: ca bon deu quy ve kenh buff.
		for _, sk in ipairs(M.skills(e)) do
			out[sk[2]] = (out[sk[2]] or 0.0) + sk[3]
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
		exclusive = opts.exclusive or false,
		purify = opts.purify or 0,
		purifyPercent = opts.purifyPercent or 0.0,

		main = { type = prop_type, value = value },
		appends = opts.appends or {},
	}
end

return M
