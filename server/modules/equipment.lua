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
	local t, v = e.main.type, e.main.value
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
	local t, v = e.main.type, e.main.value
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

--- Dung mot mon trang bi tu cac truong roi, dien san mac dinh.
function M.make(part, prop_type, value, opts)
	opts = opts or {}
	return {
		part = part,
		level = opts.level or 1,
		intensify = opts.intensify or 0,
		quality = opts.quality or 1,
		main = { type = prop_type, value = value },
		appends = opts.appends or {},
	}
end

return M
