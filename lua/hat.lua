-- CCParticleSystemQuad gia: he hat cua ban goc (typeName 'CCParticleSystemQuad',
-- 87 node trong 296 file bo cuc, dung 7 dinh nghia hat khac nhau).
--
-- VI SAO CAN. Ban goc dieu khien hat bang ba ham tren chinh node do, va khong
-- co lop nay thi ca ba la BONG — do tren sc/: `stopSystem()` 13 cho goi,
-- `resetSystem()` 9. Vd CUIArmyGroupCampsite.lua:2627-2631 doi lua:
--
--   setIsVisible(true)  + resetSystem()      (bat lua trai, tat lua phai)
--   setIsVisible(false) + stopSystem()
--
-- `getIsVisible`/`setIsVisible` da co o lop Node (cocos.lua:612/616), nen lop
-- nay chi con ba ham cua rieng he hat. Rieng `CPublic:playButtonParticleSystem`
-- (CPublic.lua:1730) con cho hat BAY THEO NUT: stopSystem() roi setIsVisible(true),
-- resetSystem(), resumeActions() va runAction(RepeatForever(...MoveTo/BezierTo)).
-- Chay duoc nho hat cua Godot song trong he toa do cua CHINH node
-- (ui/hat.gd: local_coords = true) — cung tinh chat ma Cocos co.
--
-- PHAN VE nam trong ui/hat.gd (HatNode: mot Control boc GPUParticles2D): dich
-- tung khoa cua .plist sang tham so Godot, moi dong truy ve mot so do.
--
-- DO TRONG sc/ (dung dem theo ten ham de khong lan voi lop khac): stopSystem 13,
-- resetSystem 9, isActive 0, setTotalParticles 0, setDuration 0. Con `setSpeed`
-- (5) va `getDuration` (1) KHONG phai cua hat — chung la cua action
-- (CActionManager.lua:721, RunMode.lua:149).
return function(C)
	local S = setmetatable({}, { __index = C.Node })

	-- Cocos: _active = false, _elapsed = _duration, _emitCounter = 0. Hat dang
	-- bay thi BAY NOT roi chet — vong cap nhat hat cua Cocos khong nghi khi
	-- _active == false. Ben Godot emitting = false dung y vay: hat dang bay
	-- song not doi cua no, khong bi xoa ngay.
	function S:stopSystem()
		C.raw(self):stopSystem()
	end

	-- Cocos: _active = true, _elapsed = 0, moi hat dang song bi giet
	-- (timeToLive = 0). Godot restart() lam dung the: xoa het hat cu, phat lai.
	function S:resetSystem()
		C.raw(self):resetSystem()
	end

	-- Cocos tra ve _active, tuc co dang phat hat hay khong. Khong cho nao trong
	-- sc/ goi, nhung day la cung mot co ma stopSystem/resetSystem ghi, nen anh
	-- xa thang sang emitting la dung chu khong phai doan.
	function S:isActive()
		return C.raw(self):isActive()
	end

	return S
end
