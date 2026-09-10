-- Module Nakama: MAY CHU tu tinh ket qua tran, client khong khai bao gi.
--
-- Truoc day client danh xong roi tu ghi thanh tich len kho. Mot client sua doi
-- ghi duoc con so bat ky. Nay:
--
--   * ban luu ghi voi permission_write = 0, tuc CHI MAY CHU ghi duoc.
--     Day moi la phan cuong che; khong co no thi RPC chi la hinh thuc.
--   * doi dich do may chu boc, khong phai client gui len — neu de client
--     chon thi no chon toan doi de.
--   * ket qua do may chu mo phong.
--
-- Hai RPC:
--   bx.chapters     {}                 danh sach chuong + tien do
--   bx.set_roster   {roster = {...}}   doi doi hinh, co kiem ten
--   bx.fight        {chapter = n}      danh mot chuong, tra ve ket qua
--   bx.equipment    {}                 trang bi dang co, luc chien, gia cuong hoa
--   bx.intensify    {hero, part}       cuong hoa mot mon len mot cap
--   bx.refine       {hero, part}       tinh luyen mot cap, ton tinh hoa
--
-- Mo hinh chien dau la ban Lua cua sim/battle.py. Doi chieu bang RPC thu ba:
--   bx.selftest     {}                 danh lai cac cap tham chieu roi so

local nk = require("nakama")
local data = require("hero_data")
local equip = require("equipment")

local COLLECTION = "player"
local KEY = "save"
local TEAM_SIZE = 4
local SAVE_VERSION = 6
--- Vang thuong khi qua MOT CHUONG MOI.
local GOLD_PER_CHAPTER = 60
--- Thang mot chuong DA QUA thi duoc it hon. Van phai co: neu chi thuong chuong
--- moi thi nguoi choi ket o mot chuong la het duong kiem vang, ma khong co vang
--- thi khong nang cap duoc, ma khong nang cap thi khong qua noi chuong do —
--- ket cung vinh vien. Da dinh dung the o chuong 3.
local GOLD_REPLAY = 0.25
--- Gia nang mot cap: cang cao cang dat.
local LEVEL_COST = 40
local CHAPTERS = 12
--- Doi dich manh dan theo chuong. 1.18 moi chuong nghia la chuong 12 manh
--- gap ~6 lan chuong 1 — du de bat nguoi choi phai doi doi hinh, chua toi muc
--- phai cay cap (chua co he thong cap).
local POWER_STEP = 0.18

-- ---------------------------------------------------------------- bo sinh so
-- Lua 5.1 cua Nakama co math.random, nhung no dung chung trang thai toan cuc
-- va khong hua hen giong nhau giua cac ban. Dung mot bo tu viet de mot seed
-- cho ra dung mot chuoi, lan nao cung the.
--
-- Park-Miller chu khong phai LCG kieu 1103515245: runtime Lua cua Nakama
-- (gopher-lua) giu MOI so duoi dang float64, ma float64 chi bieu dien chinh
-- xac so nguyen toi 2^53. Voi he so 1103515245 thi s * a cham 2.4e18, mat bit
-- thap, va cung mot seed se cho hai chuoi khac nhau giua Lua, Python va
-- GDScript. He so 16807 giu tich duoi 3.6e13 nen ca ba ngon ngu tinh ra dung
-- cung mot so — do la dieu kien de doi chieu TUNG TRAN (xem bx.fieldtest).
local Rng = {}
Rng.__index = Rng

function Rng.new(seed)
	local s = math.floor(seed or 0) % 2147483647
	if s <= 0 then
		s = s + 2147483646
	end
	return setmetatable({ s = s }, Rng)
end

function Rng:next()
	self.s = (self.s * 16807) % 2147483647
	return self.s
end

function Rng:float()
	return self:next() / 2147483647.0
end

function Rng:range(lo, hi)
	return lo + (hi - lo) * self:float()
end

function Rng:int(n)                      -- 1..n
	return (self:next() % n) + 1
end

-- Ky nang rieng tung tuong. Phai KHOP tung so voi SKILLS trong sim/battle.py
-- va SKILLS trong battle/combat.gd.
--
-- Ban goc co du lieu ai co ky nang nao (KDBGameHeroTalentSkill.xgg) nhung CHI
-- LUU TEN; hieu ung nam o server cua no, khong co trong tay. Bang duoi la
-- thiet ke cua ta, dua tren nghia cua cai ten.
local SKILLS = {
	NuQi      = { anger = 1.6 },        -- no khi: no day nhanh -> ky nang no som
	GongSu    = { interval = 0.8 },     -- cong toc: danh nhanh hon
	ShengMing = { hp = 1.3 },           -- sinh menh: nhieu mau
	TieBi     = { taken = 0.8 },        -- thiet bich: chiu it sat thuong
	BaoJi     = { crit_add = 0.15 },    -- bao kich: chi mang nhieu
	PoJia     = { pierce = 0.5 },       -- pha giap: bo qua nua giap
	FangYu    = { defence = 2.0 },      -- phong ngu: giap day
	GongJi    = { ap = 1.2 },           -- cong kich: sat thuong cao
	ShiXue    = { lifesteal = 0.15 },   -- thi huyet: hut mau
}

local function eff(row)
	if data.rules.useSkills == false then
		return {}
	end
	return SKILLS[row.TalentSkill or ""] or {}
end

local function m(e, k, dflt)
	local v = e[k]
	if v == nil then return dflt end
	return v
end

--- He so tang truong theo cap, CHUAN HOA ve 1.0 o cap 1. Phai KHOP
--- level_growth() trong sim/battle.py va Combat.level_growth trong
--- battle/combat.gd.
local function level_growth(row, level)
	local g = row.GrowthFactor or 1
	if g == 0 then g = 1 end
	local add = row.AddGrowthFactor or 0
	local lv = math.max(1, math.floor(level or 1))
	return (g + add * (lv - 1)) / g
end

-- ------------------------------------------------------------- mo hinh tran
local function fighter(name, power, level)
	local row = data.heroes[name]
	if row == nil then
		return nil
	end
	local b = data.base
	local g = (power or 1.0)
	if data.rules.useGrowth then
		g = g * row.GrowthFactor
	end
	g = g * level_growth(row, level or 1)
	local e = eff(row)
	local hp = b.HpBase * row.Viability * g * m(e, "hp", 1.0)
	return {
		name = name,
		hp_max = hp,
		hp = hp,
		anger = 0.0,
		ap_min = b.MinApBase * row.AttackCapability * g * m(e, "ap", 1.0),
		ap_max = b.MaxApBase * row.AttackCapability * g * m(e, "ap", 1.0),
		defence = b.DpBase * m(e, "defence", 1.0),
		interval = b.AttackInterval * m(e, "interval", 1.0),
		crit_chance = b.CriticalStrikeBase / 100.0 + m(e, "crit_add", 0.0),
		crit_mult = b.CritDamageDouble,
		hit_rate = 1.0 + row.InjuryRates,
		skill_rate = 1.0 + row.SkillInjuryRates,
		anger_gain = row.AngerRecovery * m(e, "anger", 1.0),
		taken = m(e, "taken", 1.0),          -- he so sat thuong PHAI CHIU
		pierce = m(e, "pierce", 0.0),        -- bo qua bao nhieu phan giap
		lifesteal = m(e, "lifesteal", 0.0),
		reflect = 0.0,               -- doi lai bao nhieu sat thuong
	}
end

local function strike(a, b, rng)
	local ap = rng:range(a.ap_min, a.ap_max)
	a.anger = a.anger + a.anger_gain
	local skill = a.anger >= data.rules.angerFull
	if skill then
		a.anger = 0.0
	end
	local dmg = ap * (skill and a.skill_rate or a.hit_rate)
	-- Pha giap: bo qua mot phan giap doi phuong.
	local def_eff = b.defence * (1.0 - a.pierce)
	if data.rules.mitigation == "divide" then
		local k = data.rules.defenceK
		dmg = dmg * (k / (k + def_eff))
	else
		dmg = dmg - def_eff
	end
	-- Thiet bich: he so nay thuoc ve BEN CHIU, khong phai ben danh.
	dmg = dmg * b.taken
	if rng:float() < a.crit_chance then
		dmg = dmg * a.crit_mult
	end
	if dmg < 1.0 then
		dmg = 1.0
	end
	b.hp = b.hp - dmg
	if a.lifesteal > 0.0 then
		a.hp = math.min(a.hp_max, a.hp + dmg * a.lifesteal)
	end
	-- Phan don: the tran `AllHeroReboundDamagePercent`. Doi lai theo sat thuong
	-- DA CHIU, va khong doi tiep lan nua — khong thi hai ben cung co phan don
	-- la thanh vong lap.
	if (b.reflect or 0.0) > 0.0 then
		a.hp = a.hp - dmg * b.reflect
	end
end

--- Mot tran tay doi. Tra ve 1 neu a thang, -1 neu b thang, 0 neu hoa.
local function duel(a, b, rng)
	a.hp, a.anger = a.hp_max, 0.0
	b.hp, b.anger = b.hp_max, 0.0
	local ta, tb, t = a.interval, b.interval, 0.0
	while t < data.rules.maxSeconds do
		t = math.min(ta, tb)
		local acts = {}
		if ta <= t + 1e-9 then
			acts[#acts + 1] = a
			ta = ta + a.interval
		end
		if tb <= t + 1e-9 then
			acts[#acts + 1] = b
			tb = tb + b.interval
		end
		for _, who in ipairs(acts) do
			strike(who, who == a and b or a, rng)
		end
		if a.hp <= 0 or b.hp <= 0 then
			if a.hp > 0 then return 1 end
			if b.hp > 0 then return -1 end
			return 0
		end
	end
	return 0
end

--- Tran doi hinh: ghep tung cap theo hang, ai thang nhieu cap hon thi thang.
--- Don gian hon man tran ben client (khong co di chuyen, khong co vi tri) —
--- day la trong tai, khong phai ban dien.
--- `levels` la bang ten tuong -> cap cua NGUOI CHOI. Doi dich luon cap 1;
--- do manh cua chung the hien qua `power` theo chuong.
local function team_fight(mine, theirs, rng, power, levels)
	local a_win, b_win = 0, 0
	local lanes = {}
	levels = levels or {}
	for i = 1, math.min(#mine, #theirs) do
		local x = fighter(mine[i], 1.0, levels[mine[i]] or 1)
		local y = fighter(theirs[i], power, 1)
		if x and y then
			local r = duel(x, y, rng)
			if r > 0 then
				a_win = a_win + 1
			elseif r < 0 then
				b_win = b_win + 1
			end
			lanes[#lanes + 1] = { mine = mine[i], theirs = theirs[i], result = r,
					level = levels[mine[i]] or 1 }
		end
	end
	local out = 2
	if a_win > b_win then
		out = 0
	elseif b_win > a_win then
		out = 1
	end
	return out, lanes, a_win, b_win
end

-- ------------------------------------------------------------ tran dan tran
-- Trong tai phai xu DUNG CAI TRAN MA NGUOI CHOI NHIN THAY. Truoc day o day
-- chi co team_fight(): ghep tung cap tuong danh tay doi, khong quan linh,
-- khong vi tri — trong khi man tran ben client da la hai doi quan dan theo ba
-- hang. Hai ben xu hai tro choi khac nhau thi con so tren man hinh khong con
-- nghia gi.
--
-- Cac hang so duoi day phai KHOP battle/battle.gd, battle/unit.gd va
-- sim/field.py. Doi mot ben ma quen hai ben kia la ba ban cai dat lech nhau.
local FIELD_STEP = 0.033
local LEFT_X, RIGHT_X = 190.0, 770.0
local MID_Y = 340.0
local ROW_BACK = 96.0
local ROW_GAP = 74.0
local SQUAD_SPREAD = 48.0
local BODY = 56.0
local LANE_PULL = 0.35
local LANE_WEIGHT = 4.0
--- Cap cua quan linh. Chi so cap 1 trong bang goc qua yeu so voi tuong; tu cap
--- 6 tro len hai ben moi cung mot thang. Chuong sau thi quan cung manh len.
local ARMY_BASE_LEVEL = 6

--- Buff cua the tran `name` o cap `level` cho cho dung `place` (1/2/3).
---
--- The tran la mot trong so it he thong cua ban goc con NGUYEN CA SO LIEU:
--- moi cap ghi ro tang gi, bao nhieu, cho cho dung nao. Khong co the tran do
--- thi khong buff gi — im lang tra bang rong chu khong doan.
local function formation_buffs(name, level, place)
	local f = data.formations[name or ""]
	if f == nil or f.levels == nil then
		return {}
	end
	local lv = math.max(0, math.min(math.floor(level or 0), f.maxLevel))
	local row = f.levels[lv + 1]          -- bang Lua dem tu 1, cap dem tu 0
	if row == nil or row.buffs == nil then
		return {}
	end
	return row.buffs[tostring(place)] or {}
end

--- Ap buff the tran vao mot tuong da dung xong.
--- `dmg_pct` nhan thang vao cong: cong thuc giam thuong kieu chia tuyen tinh
--- theo cong nen hai cach ra cung mot so.
local function apply_buffs(f, b)
	if f == nil or b == nil then
		return f
	end
	local function g(k)
		return tonumber(b[k]) or 0.0
	end
	f.hp_max = (f.hp_max + g("hp")) * (1.0 + g("hp_pct"))
	f.hp = f.hp_max
	local gain = 1.0 + g("dmg_pct")
	f.ap_min = (f.ap_min + g("ap")) * gain
	f.ap_max = (f.ap_max + g("ap")) * gain
	f.defence = (f.defence + g("dp")) * (1.0 + g("dp_pct"))
	f.taken = f.taken * (1.0 - g("taken_pct"))
	f.lifesteal = f.lifesteal + g("lifesteal")
	f.reflect = (f.reflect or 0.0) + g("reflect")
	-- `crit` la kenh cua TRANG BI (PropertyType CriticalStrike). The tran
	-- khong dung khoa nay, nen them vao day khong doi con so cua the tran.
	f.crit_chance = f.crit_chance + g("crit")
	return f
end

--- Mot top linh, chi so da keo theo cap. Phai khop Combat.make_army trong
--- battle/combat.gd va make_army trong sim/field.py.
local function army_fighter(name, level)
	local a = data.armies[name]
	if a == nil then
		return nil
	end
	local n = math.max(1, math.floor(level or 1)) - 1
	local hp = a.HpBase + (a.HpGrowthValue or 0) * n
	return {
		name = name,
		hp_max = hp,
		hp = hp,
		anger = 0.0,
		ap_min = a.MinApBase + (a.MinApGrowthValue or 0) * n,
		ap_max = a.MaxApBase + (a.MaxApGrowthValue or 0) * n,
		defence = a.DpBase + (a.DpGrowthValue or 0) * n,
		interval = a.AttackInterval,
		crit_chance = (a.CriticalStrike or 0) / 100.0,
		crit_mult = a.CritDamageDouble or 1.5,
		hit_rate = 1.0 + (a.InjuryRates or 0),
		-- Quan linh khong co ky nang: anger_gain = 0 nen thanh no khong bao gio
		-- day, skill_rate khong bao gio duoc dung toi.
		skill_rate = 1.0,
		anger_gain = 0.0,
		taken = 1.0,
		pierce = 0.0,
		lifesteal = 0.0,
		reflect = 0.0,
		reach = a.MaxAttackDistance or 30,
		min_reach = a.MinAttackDistance or 0,
		move_speed = a.MovingSpeed or 30,
		battle_row = a.Location or 1,
		units = math.max(1, math.floor(a.MaxUnit or 1)),
	}
end

--- Quan chung cua mot hang (1 truoc, 2 giua, 3 sau).
local function armies_in_row(r)
	local out = {}
	for _, n in ipairs(data.armyOrder or {}) do
		local a = data.armies[n]
		if a ~= nil and (a.Location or 1) == r then
			out[#out + 1] = n
		end
	end
	return out
end

--- Mot quan chung cho moi hang, boc theo seed.
local function pick_armies(seed_value)
	local r = Rng.new(seed_value)
	local out = {}
	for row = 1, 3 do
		local pool = armies_in_row(row)
		if #pool > 0 then
			out[#out + 1] = pool[r:int(#pool)]
		end
	end
	return out
end

local function place(t, row, slot, of)
	local back = (row - 1) * ROW_BACK
	local x = (t == 0) and (LEFT_X - back) or (RIGHT_X + back)
	local y = MID_Y + (slot - (of - 1) * 0.5) * SQUAD_SPREAD
	return x, y
end

local function unit_new(f, team, x, y)
	-- Tam danh 30 cua quan can chien nho hon khoang cach than (BODY = 56) nen
	-- ho khong bao gio cham duoc nhau — nang san len vua qua than nguoi.
	local reach = f.reach or 0.0
	if reach > 0.0 then
		reach = math.max(reach, 62.0)
	else
		reach = 58.0
	end
	return {
		f = f, team = team, x = x, y = y,
		reach = reach,
		min_reach = f.min_reach or 0.0,
		-- Toc do goc (20-80) qua cham cho man 960px; nhan len nhung van giu
		-- chenh lech giua ky binh (80) va voi (20).
		speed = math.max(28.0, (f.move_speed or 30.0) * 1.5),
		-- Don dau tien roi vao luc hoi chieu xong, giong mo phong tay doi.
		cooldown = f.interval,
		target = nil,
	}
end

--- Gan nhat, nhung lech LAN bi phat nang nen doi thu cung hang duoc uu tien.
local function nearest(u, enemies, snap)
	local best, best_d = nil, math.huge
	local h = snap[u]
	for _, e in ipairs(enemies) do
		if e.f.hp > 0 then
			local s = snap[e]
			local dx, dy = s[1] - h[1], s[2] - h[2]
			local ly = dy * LANE_WEIGHT
			local cost = dx * dx + ly * ly
			if cost < best_d then
				best_d, best = cost, e
			end
		end
	end
	return best
end

--- Pha 1: chon muc tieu, tien len. Tra ve muc tieu neu don vi nay ra don.
local function advance(u, delta, enemies, snap)
	if u.f.hp <= 0 then
		return nil
	end
	if u.target == nil or u.target.f.hp <= 0 then
		u.target = nearest(u, enemies, snap)
	end
	if u.target == nil then
		return nil
	end
	local h, tp = snap[u], snap[u.target]
	local dx, dy = tp[1] - h[1], tp[2] - h[2]
	local dist = math.sqrt(dx * dx + dy * dy)

	-- Qua gan thi lui ra: Artillery/Catapult co MinAttackDistance nen khong
	-- danh duoc muc tieu ap sat.
	if u.min_reach > 0.0 and dist < u.min_reach then
		local k = u.speed * delta * 0.6 / math.max(dist, 0.001)
		u.x, u.y = h[1] - dx * k, h[2] - dy * k
		return nil
	end

	if dist > u.reach then
		-- Di theo LAN: chay thang theo truc x, doi lan thi cham hon nhieu. Cho
		-- di thang toi muc tieu thi ca tam don vi don ve mot diem giua san roi
		-- chong len nhau thanh mot dong.
		local step_y = u.speed * LANE_PULL * delta
		if dx > 0 then
			u.x = h[1] + u.speed * delta
		elseif dx < 0 then
			u.x = h[1] - u.speed * delta
		else
			u.x = h[1]
		end
		u.y = h[2] + math.max(-step_y, math.min(step_y, dy))
		return nil
	end

	u.cooldown = u.cooldown - delta
	if u.cooldown <= 0.0 then
		u.cooldown = u.cooldown + u.f.interval
		return u.target
	end
	return nil
end

--- Day cac don vi ra khoi nhau. Cong don luc day roi ap MOT LAN.
---
--- Day tung cap ngay lap tuc thi cap xet sau nhin thay vi tri da doi — ma doi
--- 0 luon duoc duyet truoc. Dung loai bat doi xung da tung lam ben phai thang
--- 76% o pha ra don.
local function separate(every)
	local live = {}
	for _, u in ipairs(every) do
		if u.f.hp > 0 then
			live[#live + 1] = u
		end
	end
	local sx, sy = {}, {}
	for i = 1, #live do
		local a = live[i]
		for j = i + 1, #live do
			local b = live[j]
			local dx, dy = b.x - a.x, b.y - a.y
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist < BODY and dist >= 0.001 then
				local k = (BODY - dist) * 0.5 / dist
				local px, py = dx * k, dy * k
				sx[a] = (sx[a] or 0.0) - px
				sy[a] = (sy[a] or 0.0) - py
				sx[b] = (sx[b] or 0.0) + px
				sy[b] = (sy[b] or 0.0) + py
			end
		end
	end
	for _, u in ipairs(live) do
		if sx[u] ~= nil then
			u.x = u.x + sx[u]
			u.y = u.y + sy[u]
		end
	end
end

--- Mot tran dan tran. Tra ve (ket qua, so giay, con song trai, con song phai).
--- 0/1 la doi thang, 2 la hoa.
---
--- Mot buoc chia HAI PHA: pha 1 moi don vi doc vi tri tu MOT BAN CHUP, pha 2
--- gom moi don ra cung luc. Lam mot pha thi ben duyet sau vao tam truoc va
--- thang ap dao.
local function field_fight(teams, rng)
	local every = {}
	for t = 0, 1 do
		for _, u in ipairs(teams[t]) do
			every[#every + 1] = u
		end
	end
	local elapsed = 0.0
	local limit = data.rules.maxSeconds
	while true do
		elapsed = elapsed + FIELD_STEP
		local snap = {}
		for _, u in ipairs(every) do
			snap[u] = { u.x, u.y }
		end
		local strikes = {}
		for t = 0, 1 do
			for _, u in ipairs(teams[t]) do
				if u.f.hp > 0 then
					local v = advance(u, FIELD_STEP, teams[1 - t], snap)
					if v ~= nil then
						strikes[#strikes + 1] = { u, v }
					end
				end
			end
		end
		separate(every)
		for _, s in ipairs(strikes) do
			strike(s[1].f, s[2].f, rng)
		end

		local a, b = 0, 0
		for _, u in ipairs(teams[0]) do
			if u.f.hp > 0 then a = a + 1 end
		end
		for _, u in ipairs(teams[1]) do
			if u.f.hp > 0 then b = b + 1 end
		end
		if a > 0 and b > 0 then
			if elapsed >= limit then
				return 2, elapsed, a, b
			end
		elseif a > 0 then
			return 0, elapsed, a, b
		elseif b > 0 then
			return 1, elapsed, a, b
		else
			return 2, elapsed, a, b
		end
	end
end

--- Dung ca hai doi roi xu tran. Thay cho team_fight().
---
--- `levels` la bang ten tuong -> cap cua NGUOI CHOI. Doi dich luon cap 1; do
--- manh cua chung the hien qua `power` theo chuong.
--- Cho dung mac dinh cua doi dich. Doi cua nguoi choi dung cho dung trong ban
--- luu; doi dich khong co ban luu nen dung bang nay.
---
--- Truoc day ca hai ben deu dung cho dung CUA NGUOI CHOI, nghia la keo tuong
--- cua minh lui ve sau thi tuong doi dich cung lui theo — mot canh chon dang le
--- co y nghia lai thanh vo nghia.
local FOE_PLACEMENT = { 1, 1, 2, 3 }

--- `equips` la bang ten tuong -> bang buff do trang bi cong vao. Cong CHUNG
--- mot bang voi buff the tran roi ap MOT LAN: nho vay thu tu ap dung khong
--- con quan trong, va ban Python (sim/field.py) chac chan ra dung cung so.
local function army_battle(mine, theirs, rng, power, levels, chapter, seed_value,
		placement, formation, formation_level, equips)
	levels = levels or {}
	equips = equips or {}
	chapter = chapter or 0
	placement = placement or FOE_PLACEMENT
	local army_lv = ARMY_BASE_LEVEL + math.max(0, chapter)
	local teams = { [0] = {}, [1] = {} }
	local roster = { [0] = mine, [1] = theirs }
	for t = 0, 1 do
		for _, name in ipairs(pick_armies(seed_value * 31 + t * 7 + chapter)) do
			local proto = army_fighter(name, army_lv)
			if proto ~= nil then
				for k = 0, proto.units - 1 do
					local x, y = place(t, proto.battle_row, k, proto.units)
					teams[t][#teams[t] + 1] = unit_new(army_fighter(name, army_lv), t, x, y)
				end
			end
		end
		local names = roster[t]
		for i, name in ipairs(names) do
			local f = fighter(name, t == 0 and 1.0 or power, t == 0 and (levels[name] or 1) or 1)
			if f ~= nil then
				-- Cho dung quyet ca hai thu: dung o dau tren san, va an buff
				-- nao cua the tran. Chi doi cua NGUOI CHOI co the tran.
				local place = (t == 0 and placement[i] or FOE_PLACEMENT[i]) or 1
				if t == 0 then
					local bf = {}
					if formation ~= nil and formation ~= "" then
						bf = formation_buffs(formation, formation_level, place)
					end
					-- Trang bi CHI cua nguoi choi: doi dich khong deo do.
					apply_buffs(f, equip.merge_buffs(bf, equips[name]))
				end
				f.reach = 0.0
				f.min_reach = 0.0
				f.move_speed = data.base.MovingSpeed
				local back = (place - 1) * ROW_BACK
				local y = MID_Y + ((i - 1) - (#names - 1) * 0.5) * ROW_GAP
				local x = (t == 0) and (LEFT_X + 52.0 - back) or (RIGHT_X - 52.0 + back)
				teams[t][#teams[t] + 1] = unit_new(f, t, x, y)
			end
		end
	end
	local out, secs, alive_a, alive_b = field_fight(teams, rng)
	return out, secs, alive_a, alive_b
end

-- --------------------------------------------------------------- ban luu
local function max_level()
	return math.floor(data.rules.maxLevel or 40)
end

local function level_of(s, name)
	return math.max(1, math.floor(s.levels[name] or 1))
end

--- Gia nang tu cap hien tai len mot cap.
local function level_price(level)
	return LEVEL_COST * level
end

-- ------------------------------------------------------------- trang bi
-- Luat va cong thuc nam o server/modules/equipment.lua (chep tu ban goc).
-- Phan o day la thu ban goc co ma game moi chua co: NGUON ra trang bi. Ban
-- goc lay tu roi do, ghep do, cua hang, kho — chua he nao trong so do ton tai
-- ben nay, nen tam thoi mon do roi thang tu tran ra va gan luon vao tuong.
-- Khi nao co he vat pham va kho thi thay cho nay, khong phai thay cong thuc.
local EQUIP_PARTS = 6
local EQUIP_PART_NAME = { "vu khi", "giap", "day chuyen", "nhan", "giay", "o phu" }
--- O nao ra chi so gi. Chi dung ba loai ma ban goc co bang cuong hoa rieng
--- (Ap, HpLimit, DpAddtion) — do la dau hieu day moi la ba loai chi so chinh;
--- chi mang chi xuat hien o thuoc tinh phu, y nhu ban goc.
local EQUIP_MAIN = { equip.AP, equip.HP_LIMIT, equip.AP,
		equip.DP_ADDITION, equip.DP_ADDITION, equip.HP_LIMIT }
--- Gia tri goc o chuong 1, doi chieu voi chi so nen: HpBase 1000 x Viability,
--- MinAp 30 x AttackCapability, DpBase 30. Tuc mot mon do dau chuong dang
--- chung 5-10% chi so — dang ke ma khong lat keo.
local EQUIP_BASE = {
	[equip.AP] = 20.0,
	[equip.HP_LIMIT] = 200.0,
	[equip.DP_ADDITION] = 3.0,
}
local EQUIP_DROP_CHANCE = 0.35
local EQUIP_MAX_INTENSIFY = 200
local EQUIP_MAX_LEVEL = 90
local EQUIP_MAX_QUALITY = 5
local EQUIP_MAX_APPENDS = 3
--- Mot diem chi mang o day la 1% — dung thang cua CriticalStrikeBase (bang so
--- goc ghi 1 nghia la 1%), va trong so 50 cua ban goc noi dung dieu do: chi
--- mang tinh theo phan tram chu khong theo hang nghin nhu mau.
local EQUIP_APPEND_CRIT = 0.01
--- Nguon ra TINH HOA (Concentrate, ResourceType 8 cua ban goc). Ban goc cho
--- tinh hoa tu viec phan giai vat pham (RPC ClientRefineItem, moi vat pham mot
--- gia tri Concentrate trong bang do). Game moi chua co he vat pham, nhung da
--- co san mot thu vut di: mon do roi ra ma YEU HON mon dang deo. Phan giai no
--- thanh tinh hoa — dung y ban goc, va vua khop cho trong vong lap hien co.
local CONCENTRATE_PER_CAPACITY = 10.0

--- Boc mot mon do. Dai ngau nhien 0,8-1,3 dung bang dai thuoc tinh phu cua
--- ban goc — khong bia them mot con so thu hai cho cung mot viec.
local function roll_equipment(rng, chapter, part)
	local t = EQUIP_MAIN[part] or equip.AP
	local scale = 1.0 + POWER_STEP * math.max(0, (chapter or 1) - 1)
	local base = (EQUIP_BASE[t] or 1.0) * scale
	local value = equip.roll_append(base, function() return rng:float() end)
	local level = rng:int(6)
	local it = equip.make(part, t, value, {
		level = level,
		quality = rng:int(3),
	})
	-- Thuoc tinh phu chi co tu cap 4, dung luat ban goc.
	if level >= equip.APPEND_UNLOCK_LEVEL then
		it.appends = { {
			type = equip.CRITICAL_STRIKE,
			value = equip.roll_append(EQUIP_APPEND_CRIT,
					function() return rng:float() end),
		} }
	end
	return it
end

--- Loc mot mon do doc tu ban luu. Ban luu la du lieu ben ngoai: khong tin gi
--- ca, cai nao khong hop le thi bo han mon do chu khong sua cho lanh.
local function sanitize_item(v)
	if type(v) ~= "table" or type(v.main) ~= "table" then
		return nil
	end
	local part = math.floor(tonumber(v.part) or 0)
	local t = math.floor(tonumber(v.main.type) or 0)
	local val = tonumber(v.main.value) or -1
	if part < 1 or part > EQUIP_PARTS then return nil end
	if equip.BUFF_KEY[t] == nil then return nil end
	if val ~= val or val < 0 or val > 1e9 then return nil end
	local function clamp(x, lo, hi, dflt)
		local n = math.floor(tonumber(x) or dflt)
		return math.max(lo, math.min(hi, n))
	end
	local it = equip.make(part, t, val, {
		level = clamp(v.level, 1, EQUIP_MAX_LEVEL, 1),
		intensify = clamp(v.intensify, 0, EQUIP_MAX_INTENSIFY, 0),
		quality = clamp(v.quality, 1, EQUIP_MAX_QUALITY, 1),
		refine = clamp(v.refine, 0, equip.MAX_REFINE_LEVEL, 0),
	})
	if type(v.appends) == "table" then
		for _, ap in ipairs(v.appends) do
			local at = math.floor(tonumber(ap.type) or 0)
			local av = tonumber(ap.value) or -1
			if equip.BUFF_KEY[at] ~= nil and av == av and av >= 0 and av <= 1e9
					and #it.appends < EQUIP_MAX_APPENDS then
				it.appends[#it.appends + 1] = { type = at, value = av }
			end
		end
	end
	return it
end

--- Mon do dang deo o mot o cua mot tuong, kem chi so trong mang.
local function slot_of(s, name, part)
	local slots = s.equipment[name]
	if slots == nil then
		return nil, nil
	end
	for i, it in ipairs(slots) do
		if it.part == part then
			return it, i
		end
	end
	return nil, nil
end

--- Bang ten tuong -> buff do trang bi cong vao, de dua thang cho army_battle.
local function equip_buffs(s)
	local out = {}
	for name, items in pairs(s.equipment or {}) do
		out[name] = equip.to_buffs(items)
	end
	return out
end

--- Phan giai mot mon do thanh tinh hoa. Tra ve so tinh hoa duoc them.
--- Quy ra tu LUC CHIEN cua mon do, nen mon cang xin thi phan giai cang duoc
--- nhieu — khoi phai bia them mot bang gia thu hai.
local function dismantle(s, it)
	local n = math.max(1, math.floor(equip.capacity(it) / CONCENTRATE_PER_CAPACITY))
	s.concentrate = (s.concentrate or 0) + n
	return n
end

--- Thang tran thi co the roi mot mon. Chua co kho do nen quy tac gon: mon nao
--- MANH HON thi giu, mon kia bo. Bao ro ca hai ben cho nguoi choi biet.
local function try_drop(s, rng, chapter)
	if #s.roster == 0 or rng:float() >= EQUIP_DROP_CHANCE then
		return nil
	end
	local name = s.roster[rng:int(#s.roster)]
	local part = rng:int(EQUIP_PARTS)
	local it = roll_equipment(rng, chapter, part)
	if s.equipment[name] == nil then
		s.equipment[name] = {}
	end
	local cur, idx = slot_of(s, name, part)
	local drop = {
		hero = name,
		part = part,
		partName = EQUIP_PART_NAME[part],
		item = it,
		capacity = equip.capacity(it),
	}
	if cur == nil then
		local slots = s.equipment[name]
		slots[#slots + 1] = it
		drop.kept = true
	elseif equip.capacity(it) > equip.capacity(cur) then
		s.equipment[name][idx] = it
		drop.kept = true
		drop.replaced = true
		drop.oldCapacity = equip.capacity(cur)
		-- Mon cu bi thay thi phan giai luon, khong de mat trang.
		drop.concentrate = dismantle(s, cur)
	else
		drop.kept = false
		drop.oldCapacity = equip.capacity(cur)
		drop.concentrate = dismantle(s, it)
	end
	return drop
end

local function blank_save()
	return {
		version = SAVE_VERSION,
		roster = {},
		wins = 0, losses = 0, draws = 0, battles = 0,
		cleared = 0,              -- chuong cao nhat da qua
		gold = 0,
		levels = {},              -- ten tuong -> cap
		-- The tran (KDBGameFormationConfig cua ban goc). `placement` la cho
		-- dung cua tung tuong trong doi hinh: 1 truoc, 2 giua, 3 sau. Cho dung
		-- quyet ca vi tri tren san lan buff nao cua the tran ap vao.
		formation = "jichu",
		formationLevel = 0,
		formations = { jichu = 0 },   -- ten the tran -> cap da nang
		placement = { 1, 1, 2, 3 },
		-- Tinh hoa: tai nguyen rieng de tinh luyen, khong phai vang.
		concentrate = 0,
		-- Trang bi: ten tuong -> mang toi da 6 mon, moi mon mot o khac nhau.
		-- Luu thang thanh mang chu khong phai bang khoa so, vi qua JSON thi
		-- khoa so bien thanh chuoi — mang thi con nguyen la mang.
		equipment = {},
		lastResult = "",
		updatedAt = 0,
	}
end

local function read_save(user_id)
	local ok, objects = pcall(nk.storage_read, {
		{ collection = COLLECTION, key = KEY, user_id = user_id },
	})
	if not ok or objects == nil or #objects == 0 then
		return blank_save()
	end
	local v = objects[1].value
	if type(v) ~= "table" then
		return blank_save()
	end
	local s = blank_save()
	for _, k in ipairs({ "wins", "losses", "draws", "battles", "cleared",
			"gold", "concentrate", "updatedAt" }) do
		s[k] = tonumber(v[k]) or 0
	end
	s.lastResult = tostring(v.lastResult or "")
	if type(v.roster) == "table" then
		for _, n in ipairs(v.roster) do
			s.roster[#s.roster + 1] = tostring(n)
		end
	end
	if type(v.levels) == "table" then
		for name, lv in pairs(v.levels) do
			-- Ban luu la du lieu ben ngoai: chan cap vo ly ngay o day.
			local n = tonumber(lv) or 1
			if data.heroes[tostring(name)] ~= nil then
				s.levels[tostring(name)] = math.max(1, math.min(max_level(), math.floor(n)))
			end
		end
	end
	-- The tran da nang: chi nhan ten co that va cap trong bang.
	if type(v.formations) == "table" then
		s.formations = {}
		for name, lv in pairs(v.formations) do
			local f = data.formations[tostring(name)]
			if f ~= nil then
				local n = math.floor(tonumber(lv) or 0)
				s.formations[tostring(name)] = math.max(0, math.min(f.maxLevel, n))
			end
		end
		if s.formations.jichu == nil then
			s.formations.jichu = 0
		end
	end
	local fname = tostring(v.formation or "jichu")
	if data.formations[fname] == nil or s.formations[fname] == nil then
		fname = "jichu"
	end
	s.formation = fname
	s.formationLevel = s.formations[fname] or 0
	-- Trang bi: chi nhan tuong co that, moi o nhieu nhat mot mon.
	if type(v.equipment) == "table" then
		for name, items in pairs(v.equipment) do
			local hero = tostring(name)
			if data.heroes[hero] ~= nil and type(items) == "table" then
				local seen, out = {}, {}
				for _, raw in ipairs(items) do
					local it = sanitize_item(raw)
					if it ~= nil and not seen[it.part] then
						seen[it.part] = true
						out[#out + 1] = it
					end
				end
				if #out > 0 then
					s.equipment[hero] = out
				end
			end
		end
	end
	-- Cho dung: dung bon so, moi so 1..3.
	if type(v.placement) == "table" then
		local out = {}
		for i = 1, TEAM_SIZE do
			local n = math.floor(tonumber(v.placement[i]) or 1)
			out[i] = math.max(1, math.min(3, n))
		end
		s.placement = out
	end
	return s
end

local function write_save(user_id, s)
	s.version = SAVE_VERSION
	s.updatedAt = os.time()
	nk.storage_write({{
		collection = COLLECTION,
		key = KEY,
		user_id = user_id,
		value = s,
		permission_read = 1,     -- chu so huu doc duoc
		permission_write = 0,    -- CHI MAY CHU ghi duoc
	}})
	return s
end

--- Doi hinh mac dinh khi nguoi choi chua chon: boc tu bang tuong.
local function default_roster(rng)
	local pool = {}
	for i, n in ipairs(data.order) do
		pool[i] = n
	end
	for i = #pool, 2, -1 do
		local j = rng:int(i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	for i = 1, TEAM_SIZE do
		out[i] = pool[((i - 1) % #pool) + 1]
	end
	return out
end

--- Tuong xep theo suc manh (bac cong + bac thu). Dung de chia doi dich cho
--- tung chuong.
local function ranked_pool()
	local pool = {}
	for i, name in ipairs(data.order) do
		pool[i] = name
	end
	table.sort(pool, function(x, y)
		local a, b = data.heroes[x], data.heroes[y]
		local sa = a.AttackCapability + a.Viability
		local sb = b.AttackCapability + b.Viability
		if sa ~= sb then
			return sa < sb
		end
		return x < y                  -- hoa thi xep theo ten cho on dinh
	end)
	return pool
end

--- Doi dich cua mot chuong. Seed lay tu SO CHUONG chu khong tu dong ho, nen
--- chuong nao cung luon gap dung doi do — nguoi choi hoc duoc tran dau va doi
--- doi hinh cho hop, dung nghia mot man choi chu khong phai boc ngau nhien.
---
--- Va doi dich phai MANH DAN theo chuong. Ban dau o day boc ngau nhien tu ca
--- bang, nen chuong 1 co the gap ngay LvBuGod — nguoi choi hoa 2-2 vinh vien,
--- ma tran thi tat dinh nen danh lai bao nhieu lan cung hoa, va khong co vang
--- de nang cap. Tien do ket cung ngay tu chuong dau.
local function chapter_enemies(n)
	local pool = ranked_pool()
	local span = #pool
	if span <= TEAM_SIZE then
		return default_roster(Rng.new(n * 2654435761))
	end
	-- Cua so truot: chuong 1 lay trong nhom yeu nhat, chuong cuoi trong nhom
	-- manh nhat.
	local top = span - TEAM_SIZE
	local start = math.floor(top * (n - 1) / math.max(1, CHAPTERS - 1))
	local window = {}
	for i = 1, TEAM_SIZE do
		window[i] = pool[start + i]
	end
	-- Tron trong cua so cho moi chuong mot thu tu khac nhau.
	local rng = Rng.new(n * 2654435761)
	for i = #window, 2, -1 do
		local j = rng:int(i)
		window[i], window[j] = window[j], window[i]
	end
	return window
end

local function chapter_power(n)
	return 1.0 + POWER_STEP * (n - 1)
end

-- ------------------------------------------------------------------- RPC
local function rpc_set_roster(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local ok, body = pcall(nk.json_decode, payload or "{}")
	if not ok or type(body) ~= "table" or type(body.roster) ~= "table" then
		error("can truong roster la mot mang ten tuong")
	end
	local names = {}
	for _, n in ipairs(body.roster) do
		local name = tostring(n)
		if data.heroes[name] == nil then
			error("khong co tuong ten " .. name)
		end
		names[#names + 1] = name
	end
	if #names ~= TEAM_SIZE then
		error("doi hinh phai co dung " .. TEAM_SIZE .. " tuong")
	end
	local s = read_save(context.user_id)
	s.roster = names
	write_save(context.user_id, s)
	return nk.json_encode({ ok = true, save = s })
end

--- Danh sach chuong kem tien do. Client ve man chon chuong tu day.
local function rpc_chapters(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local s = read_save(context.user_id)
	local out = {}
	for n = 1, CHAPTERS do
		out[n] = {
			n = n,
			enemies = chapter_enemies(n),
			power = chapter_power(n),
			cleared = (n <= s.cleared),
			-- Chi mo chuong ke tiep. Khong cho nhay coc.
			unlocked = (n <= s.cleared + 1),
		}
	end
	return nk.json_encode({ ok = true, cleared = s.cleared,
			total = CHAPTERS, chapters = out, save = s,
			maxLevel = max_level(), levelCost = LEVEL_COST })
end

local function rpc_fight(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local ok, body = pcall(nk.json_decode, payload or "{}")
	if not ok or type(body) ~= "table" then
		body = {}
	end
	local s = read_save(context.user_id)

	local chapter = tonumber(body.chapter) or (s.cleared + 1)
	chapter = math.floor(chapter)
	if chapter < 1 or chapter > CHAPTERS then
		error("khong co chuong " .. chapter)
	end
	-- Chan nhay coc: chi danh duoc chuong da qua, hoac chuong ke tiep.
	if chapter > s.cleared + 1 then
		error("chua mo chuong " .. chapter .. "; moi qua toi chuong " .. s.cleared)
	end

	-- Seed do MAY CHU dat. Client khong dua vao duoc, nen khong the do tim
	-- mot seed cho ra tran thang roi chi gui seed do.
	local seed = math.floor(os.time() * 1000) + (s.battles * 7919)
	local rng = Rng.new(seed)

	if #s.roster ~= TEAM_SIZE then
		s.roster = default_roster(rng)
	end
	local theirs = chapter_enemies(chapter)
	local power = chapter_power(chapter)

	-- Seed dan quan tach khoi seed danh nhau: doi hinh quan linh cua mot chuong
	-- phai co dinh de nguoi choi hoc duoc, con dien bien tran thi moi lan mot
	-- khac. Trong tai xu DUNG tran dan tran ma client hien — truoc day o day
	-- la team_fight(), ghep cap tuong danh tay doi, khac han cai tren man hinh.
	local out, secs, alive_a, alive_b =
			army_battle(s.roster, theirs, rng, power, s.levels, chapter, chapter,
					s.placement, s.formation, s.formationLevel, equip_buffs(s))

	s.battles = s.battles + 1
	local unlocked = false
	local reward = 0
	local drop = nil
	if out == 0 then
		s.wins = s.wins + 1
		s.lastResult = "thang"
		if chapter == s.cleared + 1 then
			s.cleared = chapter
			unlocked = true
			reward = GOLD_PER_CHAPTER * chapter
		else
			-- Chuong da qua: van co vang de con duong ma go the khi bi ket,
			-- nhung it hon han de tien len van la duong nhanh nhat.
			reward = math.floor(GOLD_PER_CHAPTER * chapter * GOLD_REPLAY)
		end
		s.gold = s.gold + reward
		-- Boc do SAU khi da xu xong tran: mon vua roi khong duoc anh huong
		-- chinh tran vua danh.
		drop = try_drop(s, rng, chapter)
	elseif out == 1 then
		s.losses = s.losses + 1
		s.lastResult = "thua"
	else
		s.draws = s.draws + 1
		s.lastResult = "hoa"
	end
	write_save(context.user_id, s)

	return nk.json_encode({
		ok = true,
		seed = seed,
		chapter = chapter,
		power = power,
		result = out,
		unlockedNext = unlocked,
		goldGained = reward,
		drop = drop,
		opponent = theirs,
		seconds = secs,
		survivors = { mine = alive_a, theirs = alive_b },
		save = s,
	})
end

--- Doi chieu ban Lua voi ban Python. Cac cap va ti le mong doi nam san trong
--- hero_data.lua, do sim/export_stats.py tinh.
local function rpc_selftest(context, payload)
	local n = 4000
	local out = {}
	for _, e in ipairs(data.reference) do
		local rng = Rng.new(20260909)
		local x, y = fighter(e.a), fighter(e.b)
		local win = 0
		if x and y then
			for _ = 1, n do
				if duel(x, y, rng) > 0 then
					win = win + 1
				end
			end
		end
		out[#out + 1] = {
			a = e.a, b = e.b, battles = n,
			winPctLua = win * 100.0 / n,
			winPctPython = e.winPctA,
		}
	end
	return nk.json_encode({ ok = true, pairs = out })
end

--- Tao ban luu NGAY LUC DANG NHAP, do may chu ghi.
---
--- Chi dat permission_write = 0 thoi thi CHUA DU. Mot client chua he goi RPC
--- van tu tao duoc ban luu cua chinh no voi quyen ghi cua no, dien so bia vao,
--- roi moi goi bx.fight — va may chu doc dung con so bia do. Da thu: ghi
--- 999999 roi danh mot tran, may chu ghi lai thanh 1000000.
---
--- Nen ban luu phai thuoc ve may chu tu truoc khi client kip cham vao. Hook
--- nay chay sau moi lan dang nhap: chua co ban luu thi tao ngay mot ban rong,
--- permission_write = 0. Tu do client khong con cua nao de tao truoc.
local function after_authenticate(context, outgoing, incoming)
	local uid = context.user_id
	if uid == nil then
		return
	end
	local ok, objects = pcall(nk.storage_read, {
		{ collection = COLLECTION, key = KEY, user_id = uid },
	})
	if ok and objects ~= nil and #objects > 0 then
		return
	end
	pcall(write_save, uid, blank_save())
end

nk.register_req_after(after_authenticate, "AuthenticateDevice")

--- Nang mot tuong len mot cap. May chu tru vang va ghi ban luu; client khong
--- tu dat duoc cap nao (ban luu de permission_write = 0).
local function rpc_level_up(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local ok, body = pcall(nk.json_decode, payload or "{}")
	if not ok or type(body) ~= "table" then
		error("than tin nhan khong doc duoc")
	end
	local name = tostring(body.hero or "")
	if data.heroes[name] == nil then
		error("khong co tuong ten " .. name)
	end
	local s = read_save(context.user_id)
	local lv = level_of(s, name)
	if lv >= max_level() then
		error(name .. " da toi cap toi da " .. max_level())
	end
	local price = level_price(lv)
	if s.gold < price then
		error("thieu vang: can " .. price .. ", dang co " .. s.gold)
	end
	s.gold = s.gold - price
	s.levels[name] = lv + 1
	write_save(context.user_id, s)
	return nk.json_encode({ ok = true, hero = name, level = lv + 1,
			cost = price, save = s })
end

--- Doi chieu tran DAN TRAN voi ban Python (sim/field.py).
---
--- Khac bx.selftest o cho no so tung tran chu khong so ti le: hai ben dung
--- chung mot bo LCG nen cung seed phai ra dung cung ket qua, cung so giay,
--- cung so nguoi con song. Lech mot don vi la biet ngay mot ben tinh sai.
local function rpc_fieldtest(context, payload)
	local mine = { "MaChao", "LiuBei", "GanNing", "GuYong" }
	local theirs = { "CaoCao", "DengAi", "JiaXu", "HuaXiong" }
	local out = {}
	for seed = 1, 5 do
		local rng = Rng.new(seed)
		local res, secs, a, b = army_battle(mine, theirs, rng, 1.0, {}, seed, seed)
		out[#out + 1] = { seed = seed, result = res, seconds = secs,
				aliveA = a, aliveB = b }
	end
	-- Nam tran nua, lan nay doi ta co trang bi. Gui ke ca bang buff da dung
	-- de ban Python ap DUNG cai do — muc nay do phan NOI trang bi vao tran,
	-- con cong thuc trang bi thi muc 9 da do rieng.
	local eq = {}
	local rng0 = Rng.new(20250910)
	for _, name in ipairs(mine) do
		local items = {}
		for part = 1, 3 do
			items[#items + 1] = roll_equipment(rng0, 6, part)
		end
		eq[name] = equip.to_buffs(items)
	end
	local out2 = {}
	for seed = 1, 5 do
		local rng = Rng.new(seed)
		local res, secs, a2, b2 = army_battle(mine, theirs, rng, 1.0, {}, seed,
				seed, nil, nil, 0, eq)
		out2[#out2 + 1] = { seed = seed, result = res, seconds = secs,
				aliveA = a2, aliveB = b2 }
	end
	return nk.json_encode({ ok = true, mine = mine, theirs = theirs,
			battles = out, equipBattles = out2, equipBuffs = eq })
end

--- Danh sach the tran: cai nao da mo, cap may, nang tiep het bao nhieu.
local function rpc_formations(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local s = read_save(context.user_id)
	local out = {}
	for _, name in ipairs(data.formationOrder) do
		local f = data.formations[name]
		local owned = s.formations[name] ~= nil
		local lv = s.formations[name] or 0
		local nxt = f.levels[lv + 2]      -- cap ke tiep, bang dem tu 1
		out[#out + 1] = {
			name = name,
			maxLevel = f.maxLevel,
			owned = owned,
			level = lv,
			active = (s.formation == name),
			unlockGold = f.unlockGold,
			-- Het cap thi khong con gia nang: bao nil de client khoi hien nut.
			nextGold = nxt ~= nil and nxt.gold or nil,
			buffs = formation_buffs(name, lv, 1),
			buffs2 = formation_buffs(name, lv, 2),
			buffs3 = formation_buffs(name, lv, 3),
		}
	end
	return nk.json_encode({ ok = true, formations = out, save = s })
end

--- Chon the tran dang dung. Phai da mo roi.
local function rpc_set_formation(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local ok, body = pcall(nk.json_decode, payload or "{}")
	if not ok or type(body) ~= "table" then
		error("payload hong")
	end
	local name = tostring(body.formation or "")
	if data.formations[name] == nil then
		error("khong co the tran " .. name)
	end
	local s = read_save(context.user_id)
	if s.formations[name] == nil then
		error("chua mo the tran " .. name)
	end
	s.formation = name
	s.formationLevel = s.formations[name]
	write_save(context.user_id, s)
	return nk.json_encode({ ok = true, formation = name,
			level = s.formationLevel, save = s })
end

--- Mo hoac nang the tran. Gia lay tu chinh bang cua ban goc (da chia lai cho
--- vua nen kinh te o day) — cai manh thi dat, do la ca su can bang.
local function rpc_upgrade_formation(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local ok, body = pcall(nk.json_decode, payload or "{}")
	if not ok or type(body) ~= "table" then
		error("payload hong")
	end
	local s = read_save(context.user_id)
	local name = tostring(body.formation or s.formation)
	local f = data.formations[name]
	if f == nil then
		error("khong co the tran " .. name)
	end

	local cost, lv
	if s.formations[name] == nil then
		-- Chua co: day la lan mo.
		cost = f.unlockGold
		lv = 0
	else
		lv = s.formations[name] + 1
		if lv > f.maxLevel then
			error("the tran " .. name .. " da toi cap toi da " .. f.maxLevel)
		end
		cost = f.levels[lv + 1].gold
	end
	if s.gold < cost then
		error("thieu vang: can " .. cost .. ", dang co " .. s.gold)
	end
	s.gold = s.gold - cost
	s.formations[name] = lv
	if s.formation == name then
		s.formationLevel = lv
	end
	write_save(context.user_id, s)
	return nk.json_encode({ ok = true, formation = name, level = lv,
			cost = cost, save = s })
end

--- Doi cho dung cua bon tuong: 1 truoc, 2 giua, 3 sau.
--- Cho dung quyet ca vi tri tren san lan buff nao cua the tran ap vao, nen day
--- la mot canh chon that chu khong phai trang tri.
local function rpc_set_placement(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local ok, body = pcall(nk.json_decode, payload or "{}")
	if not ok or type(body) ~= "table" or type(body.placement) ~= "table" then
		error("thieu placement")
	end
	local out = {}
	for i = 1, TEAM_SIZE do
		local n = tonumber(body.placement[i])
		if n == nil then
			error("cho dung thu " .. i .. " khong phai so")
		end
		n = math.floor(n)
		if n < 1 or n > 3 then
			error("cho dung phai la 1, 2 hoac 3; nhan duoc " .. n)
		end
		out[i] = n
	end
	local s = read_save(context.user_id)
	s.placement = out
	write_save(context.user_id, s)
	return nk.json_encode({ ok = true, placement = out, save = s })
end

--- Trang bi dang co: tung tuong, tung o, kem luc chien va gia cuong hoa ke.
--- Client hien theo bang nay chu khong tu tinh — con so la cua may chu.
local function rpc_equipment(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local s = read_save(context.user_id)
	local out = {}
	local total = 0.0
	for name, items in pairs(s.equipment) do
		local list = {}
		for _, it in ipairs(items) do
			local cap = equip.capacity(it)
			total = total + cap
			list[#list + 1] = {
				part = it.part,
				partName = EQUIP_PART_NAME[it.part],
				level = it.level,
				intensify = it.intensify,
				quality = it.quality,
				main = it.main,
				appends = it.appends,
				capacity = cap,
				buffs = equip.to_buffs({ it }),
				refine = it.refine or 0,
				refinePercent = equip.refine_percent(it.refine or 0),
				mainValue = equip.main_value(it),
				nextCost = it.intensify < EQUIP_MAX_INTENSIFY
						and math.ceil(equip.cost_to_next(it)) or nil,
				nextRefineCost = equip.refine_cost_next(it) > 0
						and equip.refine_cost_next(it) or nil,
			}
		end
		out[name] = list
	end
	return nk.json_encode({
		ok = true,
		equipment = out,
		buffs = equip_buffs(s),
		capacity = total,
		partNames = EQUIP_PART_NAME,
		maxIntensify = EQUIP_MAX_INTENSIFY,
		maxRefine = equip.MAX_REFINE_LEVEL,
		gold = s.gold,
		concentrate = s.concentrate or 0,
		save = s,
	})
end

--- Cuong hoa mot mon len MOT cap. Gia do may chu tinh va tru — client gui gia
--- len thi cung khong ai nghe.
local function rpc_intensify(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local ok, body = pcall(nk.json_decode, payload or "{}")
	if not ok or type(body) ~= "table" then
		error("payload khong doc duoc")
	end
	local name = tostring(body.hero or "")
	local part = math.floor(tonumber(body.part) or 0)
	if data.heroes[name] == nil then
		error("khong co tuong " .. name)
	end
	if part < 1 or part > EQUIP_PARTS then
		error("khong co o thu " .. part)
	end
	local s = read_save(context.user_id)
	local it = slot_of(s, name, part)
	if it == nil then
		error(name .. " chua co do o o " .. (EQUIP_PART_NAME[part] or part))
	end
	if it.intensify >= EQUIP_MAX_INTENSIFY then
		error("da toi cap cuong hoa cao nhat (" .. EQUIP_MAX_INTENSIFY .. ")")
	end
	local cost = math.ceil(equip.cost_to_next(it))
	if s.gold < cost then
		error("thieu vang: can " .. cost .. ", dang co " .. s.gold)
	end
	local before = equip.capacity(it)
	s.gold = s.gold - cost
	it.intensify = it.intensify + 1
	write_save(context.user_id, s)
	local after = equip.capacity(it)
	return nk.json_encode({
		ok = true,
		hero = name,
		part = part,
		partName = EQUIP_PART_NAME[part],
		intensify = it.intensify,
		cost = cost,
		capacity = after,
		capacityGain = after - before,
		nextCost = it.intensify < EQUIP_MAX_INTENSIFY
				and math.ceil(equip.cost_to_next(it)) or nil,
		item = it,
		save = s,
	})
end

--- Tinh luyen mot mon len MOT cap. Ton TINH HOA, khong ton vang.
--- Gia lay tu bang cua ban goc (EquipRefineConfig): vu khi 40/80/160/320/640,
--- o khac 30/60/120/240/480; moi cap cong 5% vao chi so chinh.
local function rpc_refine(context, payload)
	if context.user_id == nil then
		error("phai dang nhap")
	end
	local ok, body = pcall(nk.json_decode, payload or "{}")
	if not ok or type(body) ~= "table" then
		error("payload khong doc duoc")
	end
	local name = tostring(body.hero or "")
	local part = math.floor(tonumber(body.part) or 0)
	if data.heroes[name] == nil then
		error("khong co tuong " .. name)
	end
	if part < 1 or part > EQUIP_PARTS then
		error("khong co o thu " .. part)
	end
	local s = read_save(context.user_id)
	local it = slot_of(s, name, part)
	if it == nil then
		error(name .. " chua co do o o " .. (EQUIP_PART_NAME[part] or part))
	end
	if (it.refine or 0) >= equip.MAX_REFINE_LEVEL then
		error("da toi cap tinh luyen cao nhat (" .. equip.MAX_REFINE_LEVEL .. ")")
	end
	local cost = equip.refine_cost_next(it)
	local have = s.concentrate or 0
	if have < cost then
		error("thieu tinh hoa: can " .. cost .. ", dang co " .. have)
	end
	local before = equip.capacity(it)
	s.concentrate = have - cost
	it.refine = (it.refine or 0) + 1
	write_save(context.user_id, s)
	local after = equip.capacity(it)
	return nk.json_encode({
		ok = true,
		hero = name,
		part = part,
		partName = EQUIP_PART_NAME[part],
		refine = it.refine,
		refinePercent = equip.refine_percent(it.refine),
		cost = cost,
		concentrate = s.concentrate,
		capacity = after,
		capacityGain = after - before,
		nextRefineCost = equip.refine_cost_next(it) > 0
				and equip.refine_cost_next(it) or nil,
		item = it,
		save = s,
	})
end

nk.register_rpc(rpc_level_up, "bx.level_up")
nk.register_rpc(rpc_set_roster, "bx.set_roster")
nk.register_rpc(rpc_chapters, "bx.chapters")
nk.register_rpc(rpc_fight, "bx.fight")
nk.register_rpc(rpc_selftest, "bx.selftest")
nk.register_rpc(rpc_fieldtest, "bx.fieldtest")
nk.register_rpc(rpc_formations, "bx.formations")
nk.register_rpc(rpc_set_formation, "bx.set_formation")
nk.register_rpc(rpc_upgrade_formation, "bx.upgrade_formation")
nk.register_rpc(rpc_set_placement, "bx.set_placement")
nk.register_rpc(rpc_equipment, "bx.equipment")
nk.register_rpc(rpc_intensify, "bx.intensify")
nk.register_rpc(rpc_refine, "bx.refine")
