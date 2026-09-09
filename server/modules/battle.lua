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
--
-- Mo hinh chien dau la ban Lua cua sim/battle.py. Doi chieu bang RPC thu ba:
--   bx.selftest     {}                 danh lai cac cap tham chieu roi so

local nk = require("nakama")
local data = require("hero_data")

local COLLECTION = "player"
local KEY = "save"
local TEAM_SIZE = 4
local SAVE_VERSION = 2
local CHAPTERS = 12
--- Doi dich manh dan theo chuong. 1.18 moi chuong nghia la chuong 12 manh
--- gap ~6 lan chuong 1 — du de bat nguoi choi phai doi doi hinh, chua toi muc
--- phai cay cap (chua co he thong cap).
local POWER_STEP = 0.18

-- ---------------------------------------------------------------- bo sinh so
-- Lua 5.1 cua Nakama co math.random, nhung no dung chung trang thai toan cuc
-- va khong hua hen giong nhau giua cac ban. Dung mot bo LCG tu viet de mot
-- seed cho ra dung mot chuoi, lan nao cung the.
local Rng = {}
Rng.__index = Rng

function Rng.new(seed)
	return setmetatable({ s = (seed or 0) % 2147483647 }, Rng)
end

function Rng:next()
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	return self.s
end

function Rng:float()
	return self:next() / 2147483648.0
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

-- ------------------------------------------------------------- mo hinh tran
local function fighter(name, power)
	local row = data.heroes[name]
	if row == nil then
		return nil
	end
	local b = data.base
	local g = (power or 1.0)
	if data.rules.useGrowth then
		g = g * row.GrowthFactor
	end
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
local function team_fight(mine, theirs, rng, power)
	local a_win, b_win = 0, 0
	local lanes = {}
	for i = 1, math.min(#mine, #theirs) do
		local x, y = fighter(mine[i], 1.0), fighter(theirs[i], power)
		if x and y then
			local r = duel(x, y, rng)
			if r > 0 then
				a_win = a_win + 1
			elseif r < 0 then
				b_win = b_win + 1
			end
			lanes[#lanes + 1] = { mine = mine[i], theirs = theirs[i], result = r }
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

-- --------------------------------------------------------------- ban luu
local function blank_save()
	return {
		version = SAVE_VERSION,
		roster = {},
		wins = 0, losses = 0, draws = 0, battles = 0,
		cleared = 0,              -- chuong cao nhat da qua
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
	for _, k in ipairs({ "wins", "losses", "draws", "battles", "cleared", "updatedAt" }) do
		s[k] = tonumber(v[k]) or 0
	end
	s.lastResult = tostring(v.lastResult or "")
	if type(v.roster) == "table" then
		for _, n in ipairs(v.roster) do
			s.roster[#s.roster + 1] = tostring(n)
		end
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

--- Doi dich cua mot chuong. Seed lay tu SO CHUONG chu khong tu dong ho, nen
--- chuong nao cung luon gap dung doi do — nguoi choi hoc duoc tran dau va doi
--- doi hinh cho hop, dung nghia mot man choi chu khong phai boc ngau nhien.
local function chapter_enemies(n)
	return default_roster(Rng.new(n * 2654435761))
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
			total = CHAPTERS, chapters = out, save = s })
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

	local out, lanes, a_win, b_win = team_fight(s.roster, theirs, rng, power)

	s.battles = s.battles + 1
	local unlocked = false
	if out == 0 then
		s.wins = s.wins + 1
		s.lastResult = "thang"
		if chapter == s.cleared + 1 then
			s.cleared = chapter
			unlocked = true
		end
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
		opponent = theirs,
		lanes = lanes,
		laneWins = { mine = a_win, theirs = b_win },
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

nk.register_rpc(rpc_set_roster, "bx.set_roster")
nk.register_rpc(rpc_chapters, "bx.chapters")
nk.register_rpc(rpc_fight, "bx.fight")
nk.register_rpc(rpc_selftest, "bx.selftest")
