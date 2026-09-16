-- Am thanh cua ban goc: cac ham am thanh toan cuc do engine C++ dang ky.
--
-- VI SAO CAN. Ca 973 file Lua khong dinh nghia mot ten nao trong so nay, nen
-- trong may ao chung la BONG: goi duoc, khong nem loi, va IM. Do tren ma goc:
-- 76 cho `G_SoundManager:PlaySoundEffect` (mo/dong cua so, nut bam, nhan
-- thuong), 12 cho `PlayBackgroundMusic`, 7 `playSoundEffect` goi thang, 8
-- `stopSoundEffect`, 36 `loadEffectBank`, 18 `unloadBankByName`.
--
-- HOP DONG lay tu chinh CHO GOI, khong suy dien:
--
--   * SoundManager.lua:24, :39, :54 — `playBackgroundMusic(ten)`,
--     `playSoundEffect(ten)`; khong ben nao dung gia tri tra ve.
--   * CUIWing.lua:1474-1475 — `stopSoundEffect(self.soundId)` roi
--     `loadEffectBank("UI", ...)` roi
--     `bRetCode, self.soundId = playSoundEffect(...)`: HAI gia tri tra ve, va
--     `self.soundId` duoc giu lai de tat sau.
--   * CGuideScheme.lua:12-14 — `stopSoundEffect(playingGuideVoiceID)` roi
--     `local bRetCode, nID = playSoundEffect(strVoiceName)`. `soundId` luc dau
--     la nil nen `stopSoundEffect(nil)` PHAI chiu duoc.
--   * CAsrManager.lua:178-179 — `bRecode, self.fBackgroundMusicVolume =
--     getBackgroundMusicVolume()` roi `setBackgroundMusicVolume(0.0)`, va
--     :194 tra lai. Bon man chat (CUIArmyGroupCampsiteChatting, CUIChatting,
--     CUIFriendsChatting, CAsr) dung dung cap nay de HAT NHO nhac nen luc ghi
--     am — nen hai ham do phai that, khong duoc de trong.
--   * game.lua:340-345 — `loadBackgroundBank("BG", "banks/BGM.bank")`,
--     `loadEffectBank("UI", "banks/UI.bank")`: ten bank chi de goi, duong dan
--     moi la dia chi. Ca hai deu KHONG tra ve gi.
--
-- Du lieu va cach phat nam o `game/am_thanh.gd`; file nay chi la mat Lua.

local M = {}

function M.install()
	local gd = {
		phat = _godot_phat_tieng,
		dung = _godot_dung_tieng,
		nhac = _godot_phat_nhac,
		dung_nhac = _godot_dung_nhac,
		tam_dung_nhac = _godot_tam_dung_nhac,
		nhac_dang_chay = _godot_nhac_dang_chay,
		am_luong = _godot_am_luong,
		dat_am_luong = _godot_dat_am_luong,
		ghi_bank = _godot_ghi_chu_bank,
		bo_bank = _godot_bo_bank,
	}

	-- playSoundEffect(ten) -> (bRetCode, nID). bRetCode = 1 khi co tieng.
	-- Tra ve 0, 0 chu khong tra nil: hai cho goi doc ca hai gia tri, va
	-- `stopSoundEffect(nil)` cua lan sau la vo hai.
	function playSoundEffect(ten)
		if type(ten) ~= 'string' then return 0, 0 end
		local id = gd.phat(ten)
		if type(id) ~= 'number' or id <= 0 then return 0, 0 end
		return 1, id
	end

	function stopSoundEffect(id)
		if type(id) ~= 'number' or id <= 0 then return end
		gd.dung(id)
	end

	function playBackgroundMusic(ten)
		if type(ten) ~= 'string' then return end
		gd.nhac(ten)
	end

	function stopBackgroundMusic()
		gd.dung_nhac()
	end

	function pauseBackgroundMusic()
		gd.tam_dung_nhac(true)
	end

	function resumeBackgroundMusic()
		gd.tam_dung_nhac(false)
	end

	function isBackgroundMusicPlaying()
		return gd.nhac_dang_chay()
	end

	-- `bRecode, gia tri` — CAsrManager.lua:178 doc hai gia tri nay.
	function getBackgroundMusicVolume()
		return true, gd.am_luong(true)
	end

	function setBackgroundMusicVolume(v)
		if type(v) ~= 'number' then return end
		gd.dat_am_luong(true, v)
	end

	function getEffectsVolume()
		return true, gd.am_luong(false)
	end

	function setEffectsVolume(v)
		if type(v) ~= 'number' then return end
		gd.dat_am_luong(false, v)
	end

	-- Nap / bo nap bank. Ban goc chi phat duoc tieng cua bank da nap; o day
	-- 1498 mau da nam san tren dia nen khong phai nap gi — hai ham nay chi GHI
	-- LAI de biet client nap nhung bank nao. Ly do khong chan tieng theo so
	-- nay: xem `ghi_chu_bank` trong game/am_thanh.gd.
	function loadEffectBank(ten, duong)
		if type(ten) ~= 'string' then return end
		gd.ghi_bank(ten, type(duong) == 'string' and duong or '')
	end

	function loadBackgroundBank(ten, duong)
		if type(ten) ~= 'string' then return end
		gd.ghi_bank(ten, type(duong) == 'string' and duong or '')
	end

	function unloadBankByName(ten)
		if type(ten) ~= 'string' then return end
		gd.bo_bank(ten)
	end

	function unloadBackgroundBank(ten)
		if type(ten) ~= 'string' then return end
		gd.bo_bank(ten)
	end

	-- SimpleAudioEngine: lop cua engine (Cocos2d-x). Trong ma goc no chi con
	-- HAI cho dung that: game.lua:238 `g_SimpleAudioEngine =
	-- SimpleAudioEngine:new()` (duong khoi dong that cua ban goc) va
	-- system/audio_base.lua:10. Ca lop `AudioBase` la MA CHET — khong noi nao
	-- instantiate no, va `self.music` / `self.effect` (no tra cuu theo ten)
	-- khong bao gio duoc ghi, tuc moi lan goi `self.musicEngine:play...(nil)`
	-- thi tham so la nil. Nen lop phai CO, con duong di cua no thi khong bao
	-- gio chay.
	--
	-- Dung bang thuong + setmetatable chu khong dung `class()` cua ban goc:
	-- install_cocos chay ngay sau nhom ke khai DAU TIEN, luc do `class` chua
	-- chac da nap xong.
	SimpleAudioEngine = {}
	function SimpleAudioEngine:new()
		return setmetatable({ music = {}, effect = {} }, { __index = self })
	end

	function SimpleAudioEngine:release() end
	-- preload khong phat: AudioBase:playMusic (:49) goi preload roi moi play,
	-- de preload phat luon thi bai hat chay lai tu dau o lan goi sau.
	function SimpleAudioEngine:preloadBackgroundMusic(p) return true end
	function SimpleAudioEngine:playBackgroundMusic(p) playBackgroundMusic(p) end
	function SimpleAudioEngine:stopBackgroundMusic() stopBackgroundMusic() end
	function SimpleAudioEngine:pauseBackgroundMusic() pauseBackgroundMusic() end
	function SimpleAudioEngine:resumeBackgroundMusic() resumeBackgroundMusic() end
	function SimpleAudioEngine:isBackgroundMusicPlaying()
		return isBackgroundMusicPlaying()
	end
	-- Tra ve MOT gia tri la id: day la SimpleAudioEngine cua Cocos, khac
	-- `playSoundEffect` cua engine goc (tra hai gia tri, xem dau file).
	function SimpleAudioEngine:playEffect(p)
		local _, id = playSoundEffect(p)
		return id
	end
	function SimpleAudioEngine:stopEffect(id) stopSoundEffect(id) end
	function SimpleAudioEngine:preloadEffect(p) return true end
	function SimpleAudioEngine:unloadEffect(p) end
	function SimpleAudioEngine:unloadAllEffect() end
	function SimpleAudioEngine:setBackgroundMusicVolume(v) setBackgroundMusicVolume(v) end
	function SimpleAudioEngine:getBackgroundMusicVolume() return getBackgroundMusicVolume() end
	function SimpleAudioEngine:setEffectsVolume(v) setEffectsVolume(v) end
	function SimpleAudioEngine:getEffectsVolume() return getEffectsVolume() end

	return gd
end

return M
