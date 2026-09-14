# Lộ trình dựng lại Búa Tạ

Danh sách mọi phần cần làm để ra được game, kèm chỗ đang đứng. Cập nhật
2026-09-14.

**Cách đọc dấu**

| dấu | nghĩa |
|---|---|
| `[x]` | xong, và có bộ kiểm khoá lại |
| `[~]` | chạy được nhưng **ĐẶT** — chưa đúng bản gốc, chỗ đặt đã ghi rõ |
| `[ ]` | chưa làm |
| `[?]` | chưa đo được, cần máy ảo Android hoặc đọc `libgame.so` |

Số trong ngoặc là **đo được**, không phải ước lượng. Cách đo ghi kèm.

---

## 0. Thước đo hiện tại

| | số | đo bằng |
|---|---|---|
| Module Lua của bản gốc nạp được | **875 / 876** | `boot_goc()` |
| Màn hình mở được | **~259 / 353** | `tools/quet_show.gd` |
| Hàm máy chủ `Client*` đã có bản offline | **12 / 411** | đếm `sc/` vs `offline/handlers` |
| Lệnh kịch bản `g_DramaSystem` đã có | **60 / 60** | đối chiếu `sc/plot/drama_*.lua` |
| Bộ kiểm | **24**, xanh hết | `tools/check.py` |

> Con số màn hình **dao động ±3 giữa các lần chạy** (đo 3 lần trong ngày:
> 258, 259, 260). Bộ quét mở 353 hộp thoại liên tiếp trong một máy ảo dùng
> chung trạng thái, nên đừng đọc chênh lệch một vài màn là tiến bộ — muốn biết
> một sửa đổi có ăn thua không thì mở thẳng màn đó mà xem.

Con số 12/411 là thước đo thật của phần còn lại: **giao diện gần xong, máy
chủ mới làm được phần đi chiến dịch.**

---

## 1. Lấy dữ liệu ra khỏi bản gốc

- [x] Giải mã `.xgg` (bố cục màn hình) — 296 màn, 33.472 node
- [x] Giải `.pkm` → PNG (ETC1 + kênh alpha nửa dưới) — 7.262 ảnh giao diện
- [x] Bộ xương + hoạt ảnh (`sngXml`) — 397 atlas, 7.999 động tác
- [x] 104 bảng cấu hình, 16.894 dòng chữ tiếng Việt
- [x] Mã nguồn Lua — 973 file / 518.585 dòng, quy về UTF-8
- [x] Tag node đo từ bản gốc chạy trong máy ảo Android (phủ 90,7% lượt hỏi)
- [x] Nền cảnh trận, ảnh chương
- [x] Công thức sát thương giải từ `libgame.so` (`0x380c94`)
- [ ] ~45 mảnh trang trí nền cảnh: atlas `Scene_*.plist` **không có trong
      APK lẫn OBB** — bản gốc tải lúc chạy từ máy chủ vá. Không lấy được.

## 2. Engine giả lập (chạy thẳng mã Lua của bản gốc)

- [x] Máy ảo Lua + `require` riêng (LuaJIT = Lua 5.1, đúng bản Cocos dùng)
- [x] Lớp giả lập Cocos2d-x: node là userdata, hệ toạ độ, `getChildByTag`…
- [x] Hệ action viết tay (MoveTo, Sequence, Spawn, Repeat, 18 kiểu Ease…)
- [x] `loadLevelFile` — bộ nạp `.xgg`, đúng đường bản gốc dùng
- [x] Thứ tự vẽ theo `zOrder` (`+0xA4`)
- [x] Điểm neo: `CCLayer`/`CCScene` bỏ qua neo khi đặt chỗ
- [x] Bấm được: phân phối chạm → hàm `onTouchEnd_*` của bản gốc
- [x] Bảng chữ, tầng cấu hình, `cjson`, `ProtoRPC` giả
- [x] Bóng: mọi biến toàn cục chưa làm đều ghi lại lượt gọi
- [?] `CCLayerColorRoundRect` có bỏ qua neo không — chưa đo
- [?] Cách trộn màu của armature (đốm xanh ở Main) — đã khoanh vùng, chưa giải

## 3. Giao diện

- [x] Chuỗi Login → chọn máy chủ → vào game → cảnh `Main`
- [x] Vẽ `Main`: trời, thành phố, nhà (armature), dải nút, biển tên, số người chơi
- [x] Mở màn hình bằng đúng đường của bản gốc: `<quản lý>:Show(<tên>)`
- [x] Công cụ xem màn: `tools/xem_man.tscn`
- [ ] **95 màn chưa mở được** — 72 hỏng (xem mục 4), 23 đòi tham số
- [ ] Còn thiếu ở `Main`: `sngFixInfoReflash`, kéo cuộn lớp thành phố
- [ ] Lớp phủ hướng dẫn `g_CGuideLogical`

## 4. Máy chủ offline — phần dài nhất còn lại

Máy chủ cũ đã chết. Mỗi tính năng cần một handler đọc luật có sẵn trong
`sc/share/` rồi trả kết quả về, không bịa số.

**Đã có (7 handler):**

- [x] `login` — đăng nhập, người chơi mới tinh (từ mục `*Reset` của cấu hình)
- [x] `chapter` — chiến dịch: bắt đầu ải, thắng, thua, lên cấp, mở ải sau
- [x] `achieve` — thành tựu
- [x] `statewar` — quốc chiến (chặn, để không nuốt cú bấm)
- [x] `mysterious` — cửa hàng bí ẩn
- [x] `lottery` — chiêu mộ tướng
- [~] `cavern` — Ma Khu: **mở được màn** (thêm `Node:getChildren` cho lớp Cocos;
      `GameUserCavern` trả `nil` ở `initUserDataFromDB` để `CavernDataManager`
      tự dựng hình dạng gốc — nó dùng `CraeteUserCavern`, không phải `InitData`
      nên lọt qua bộ quét ở trên). Handler gọi luật `CavernLogic` gốc: lên tầng
      (`CompeleteProgress`, đo được P 0→1), đánh (`CompeleteFight`), nhận thưởng,
      đặt lại, hồi sinh, mua đồ. **CHƯA**: làm mới hàng cửa hàng và quét nhanh
      (luật sinh danh sách hàng không nằm trong `CavernLogic`, chưa tìm ra)
- [x] Bảng người chơi không có mục `<bảng>Reset` thì lấy hình dạng từ
      `InitData()` của chính client (`GamePet`, `GameUserStarSoul`) — trước đây
      để `{}` rỗng, và rỗng làm client chết ở dòng sau chứ không báo gì
- [~] Danh sách rơi đồ (`DropData.DropList`) — **đánh xong có rơi đồ**, và phần
      thưởng đi vào dữ liệu người chơi qua `SetDataWithPrizeData` (40/40 mục
      rơi của ải 1 phát được). Số lấy
      từ `KDBGameNpcConfig[NpcID].DropData` + `TotalDropValue` của chính bản
      gốc; mã đơn vị `"<nhóm>-<lính>-<bản sao>"` giải ra từ ví dụ trong chú
      thích `CUIGameFinish.lua` đối chiếu với `ChapterInfo`. **ĐẶT**: cách quay
      (mỗi mục quay riêng, xác suất `DropValue/TotalDropValue`) — luật sinh của
      server không được ship

**Chưa có — xếp theo số màn hình nó mở khoá:**

> Cách nhóm dưới đây dựa trên **đường dẫn file ném lỗi**, nên là ước lượng thô.
> Đã có một lần sai vì thế: nhóm "hộp thoại chung" ban đầu đếm 11 màn, nhưng
> đọc mã ra thì `CMessageBox`, `CUISubDialog`, `CUIMakeSureBuyDialog` lấy nội
> dung từ **tham số `data` của `onShow(lastUIName, data)`** — người gọi truyền
> vào, không phải máy chủ trả về. Chúng **không cần handler nào**; chúng hỏng
> chỉ vì bộ quét gọi `Show(tên)` trần. Trước khi viết handler cho một nhóm,
> đọc xem giá trị nil đó từ đâu ra.

- [ ] Ải vô tận / Epic / SB / COG (11 màn)
- [~] Bang hội / quân đoàn — handler `guild` đã có, và `GuildControlMain` mở
      được. Nhưng nhóm này **không phải 10 màn**: đọc mã ra thì 4 màn chỉ dùng
      chung widget `CUIGuildTableViewList` (thật ra là APR/Activity), 2 màn đòi
      đối số của người gọi, 1 màn hỏng vì thiếu **tag** chứ không thiếu dữ liệu.
      Phần còn lại (tạo bang, xin vào, chiến bang) cần người chơi khác — việc
      của máy chủ thật, không phải lớp offline
- [ ] Hoạt động, sự kiện, điểm danh, nạp tích luỹ (9 màn)
- [ ] Đấu trường / PvP / giải đấu (9 màn)
- [ ] Thú cưng (6 màn)
- [ ] Võ tướng, doanh trại, hồn tướng, cánh, thời trang (6 màn)
- [ ] Cửa hàng, nạp, VIP (5 màn)
- [~] Hang / ma khu (1 màn) — mở được + handler `cavern` (xem mục "Đã có"); còn
      làm mới hàng cửa hàng và quét nhanh
- [ ] Nhiệm vụ, thương nhân, bạn bè, chat (4 màn)

## 5. Trận đánh

- [x] Chuỗi trọn: Main → chọn ải → bố trí quân → trận → màn kết thúc
- [x] Chỉ số quân lấy từ luật gốc, không chỉnh tay
- [x] Công thức sát thương **thật** của bản gốc
- [x] Kịch bản trận: thoại, đồng minh nhập trận, boss bị rút → **thắng được ải 1
      đúng cách bản gốc**
- [x] Đưa lính ra trận, nút thức tỉnh theo dòng điều khiển gốc
- [x] Camera bám quân, nền trôi theo hệ số parallax
- [x] Thẻ tướng, đội hình xếp chéo, đánh mượt
- [x] Tốc độ quân — **số thật của bản gốc**. Hoá ra `MovingSpeed` *không phải*
      chỗ engine lấy tốc độ: nó **không hề có** trong `libgame.so` (bảng tên chỉ
      số quanh `0x7b42f0` có `AttackInterval`, `InjuryRates`, `NpcSize`,
      `ClosePressing`, `Jump`… nhưng không có nó), và client chỉ dùng nó làm chỉ
      số hiển thị. Tốc độ thật nằm ở `<sMove>` → `<ptVector>` trong
      `map/*_config.xml`, đơn vị ô, 1 ô = 100 px: bộ binh đi 130 px/s chạy 300,
      cung 130/250, kỵ 130/350. Bê ra bằng `work/move_speed.py` (124 sprite).
      **ĐẶT còn lại**: lấy tốc độ ĐI; engine chọn đi hay chạy lúc nào thì do
      "brain" bên C++
- [x] **Ánh xạ trường sang bên đánh / bên chịu** — đọc thẳng từ **chỗ điền
      struct** (`0x41ab82..0x41ad08`), không còn suy theo nghĩa của tên. Hàm
      `0x380c94` nhận một struct 0x4c byte; chỗ điền lấy từng ô từ hai đối
      tượng: `r5` = **bên đánh** (có thể NULL — `cmp r5,#0; beq` nhảy thẳng tới
      chỗ gọi) và `r6` = **bên chịu**. Cả bốn giả định cũ đều **đúng**:
      `nDp` (+0x64c) và `fReducingDamage` (+0x748) lấy từ bên chịu; nguyên tố,
      `nPiercingAp`, `nDamageAddition`, `fIgnoreDp`, `Final*` lấy từ bên đánh.
      Ba chỗ **sửa** theo số đo:
      (a) `fDamageMultiples` có **ba** ô chứ không phải hai — `0x3d49d4` chọn
      `AtHero` khi mục tiêu là tướng, `AtBoss` khi `NpcType == 5`
      (`CUIChapterInfo.lua:1182` dùng `sBossIcon` cho 5), còn lại `AtDogface`;
      (b) hệ số bỏ qua giáp **chỉ nhân khi `nDp > 0`** (`0x380cde` `ite gt`);
      (c) `FinalHarm` (`0x380c00`) đã giải hết thứ tự — chặn dưới thật là
      `-(0.5 + r6[0x59c])` chứ không phải hằng `-1`.
      Khoá bằng 5 phép kiểm trong `tools/verify_battle.gd` (22/22).
      **ĐẶT còn lại**: ô +0x18 (trừ vào tỉ lệ né, của bên đánh) không có trong
      bảng tên của bộ dựng nên chưa biết tên — coi là 0; và chặn dưới của
      `FinalHarm` giữ −1
- [x] **Cách hồi thống soái** — `LeaderShipResume` là **số giây để hồi 1 điểm**.
      Chứng minh bằng chính mã gốc: `SkillLogic:CommandReviveAccelerate`
      (`sc/share/SkillLogic.lua:579`, chú thích *"领导力恢复速度*2"*) làm
      `addtionPerSec = 1/LeaderShipResume`, cộng thêm rồi ghi ngược
      `LeaderShipResume = 1/addtionPerSec`. Ta đang hồi đúng như vậy.
      **ĐẶT còn lại**: vào trận thì đầy thống soái (engine C++ giữ con số này,
      client chỉ nhận qua `updateLeaderShip`)
- [x] **`SetCameraScale`** — giải hết bằng hàm engine `0x366c7c` (tìm qua bảng
      bind Lua ở `.data:0x939704` → `0x467fb4`). Chữ ký thật
      `(giây, tham2, tỉ lệ, x, y, tham6)`:
      `giây` là **thời gian chạy** — `0x366c9a` so với hằng **0.001**, dưới
      ngưỡng thì đặt tỉ lệ ngay, trên thì `CCScaleTo` chạy dần; cả bốn chỗ gọi
      trong `sc/plot/drama_L_XSGK.lua` đều truyền **0.5 giây**, nên bản gốc
      **chạy dần**. Đã sửa: `dat_thu_phong` nội suy trong chính bước khung của
      sân trận (không dùng `Tween` — node sân trận nằm **ngoài cây cảnh**).
      `tham2` là một **khoảng thời gian** nữa: nó đi vào `0x4a9040`, hàm đó ghi
      tham số vào `+0x24` và **thay 0 bằng `0x34000000` = `FLT_EPSILON`** — đúng
      thân `CCActionInterval::initWithDuration` của Cocos2d-x. Cả bốn chỗ gọi
      đều truyền 0 nên không đổi hành vi. Khoá bằng 3 phép kiểm trong
      `do_chien_dich --kiem` (22/22)
- [x] **Chỗ đứng quân** — làn và khoảng cách nay là **số thật**. `Location`
      (1..3) của chính bản ghi sprite quyết định làn (Defender 1, Archer 3);
      khoảng cách làn lấy từ `map/global_config.xml`: `fLaneWidth = 0.4` ô
      (40 px) và `fLaneOffset = 0.1` ô (10 px) — ba làn gọn trong 90 px < 1 ô,
      khớp với việc `Location` chỉ nhận 1..3. Khoảng cách giữa hai quân cùng
      làn dùng `fArmySpace = 1.1` ô (110 px) thay cho 48 px ta đặt trước đây —
      48 nhỏ hơn thân người (56) nên quân chồng nhau.
      **ĐẶT còn lại**: đơn vị của `fLaneWidth`/`fLaneOffset` là ô (suy từ chính
      file đó, chưa đọc được chỗ engine dùng hai hằng này); và thứ tự xếp khi
      quân **không có làn riêng** (`Location = 0`, ví dụ tướng người chơi) vẫn
      là của ta.
      `ptLayout`: **hai giả thuyết đã bị bác bỏ bằng số đo.** (1) "đội hình của
      toán lính" — tích `x*y` khớp `MaxUnit` ở **0/6** binh chủng có cả hai số
      (Berserker `{3,3}` = 9 nhưng `MaxUnit` = 2). (2) "kích thước chiếm chỗ" —
      không tương quan với `NpcSize`: nhóm `{3,3}` trung bình 0.83 còn nhóm
      `{1,1}` là 1.02. Đo lại cho đúng khối XML thì chỉ **67 sprite** đặt
      `ptLayout` (42 là `{1,1}`), không phải mọi binh chủng như lần đo hỏng
      trước. Engine có lưới ô thật — `InWhichCell` (`0x35ec4c`) nhận điểm tính
      bằng **px**, loại điểm âm và điểm vượt *cỡ ô × số ô*, rồi chia lấy chỉ số
      ô; `ptLayout` đọc vào `+0x460` của cấu hình. Trong `.text` không có chỗ
      nào đọc `+0x460` trực tiếp (engine đọc qua bảng tên), nên **ý nghĩa của
      `ptLayout` không khôi phục được nếu không chạy bản gốc**
- [x] **Hiệu ứng kỹ năng thức tỉnh** — số liệu nay lấy từ **cấu hình gốc**,
      không còn con số nào của ta. `work/wake_ref.py` bê 247 khối `<fight>`
      ra `data_ref/wake_ref.json`; `WakeRef` tra:
      **số đòn** = 1 + số trường `fSectionIntervalWake_F<n>`, chặn trên bởi
      `nAttackSectionLimitWake` (Triệu Vân 1, Quan Vũ 6, Tào Thực 3);
      `fDamageBonusWake` (Triệu Vân 0.47); `nSplitWake` = **số mục tiêu chia
      đều sát thương** — nghĩa này đọc từ chính bản gốc, `global_config.xml`
      ghi `<nSplitNumForAOE>6</nSplitNumForAOE>` ngay dưới chú thích
      *"群攻分摊个数"*, nên giả thuyết "`nSplitWake` là số đòn" **bị bác bỏ**.
      Đồng thời sửa một lỗi nặng của ta: `SetRoleChangeFight` bị coi là AoE ở
      **mọi** lần gọi, kể cả khi nó chỉ đổi tư thế (`Fight`, `Fight20`) — ở ải 1
      là 2 Triệu Vân × 3 lần gọi = 6 lần AoE không có thật. Nay chỉ động tác
      **kỹ năng** (`Wake*`, `Talent*`) mới gây sát thương. Sau khi sửa cả hai,
      ải 1 **vẫn thắng** (53 giây) mà không cần con số đặt nào.
      **ĐẶT còn lại**: cách ghép (`dmg * (1 + fDamageBonusWake)`, hệ số chia
      `clamp(nSplitWake/n, fSplitFloorWake, 1)`) và việc đánh **khắp** địch —
      luật thật nằm trong ~80 lớp C++ `CDFSpriteFight*Wake`
- [x] **Đường đi / hiệu ứng điện ảnh** — **xong**. Đối chiếu 56 file
      `sc/plot/drama_*.lua` với `lua/kich_ban.lua` thì thiếu **35/60** lệnh
      `g_DramaSystem`; nay đủ **60/60**. Làm thật (chữ ký đọc từ chính chỗ gọi):
      `MoveThenDoAction` (đường đi: tới ô rồi diễn động tác), `DoAction`,
      `SetReversal`, `PlayEffectInMap` / `PlayEffectInMapAbsolute` (armature
      hiệu ứng tại ô — `DramaDialog_SmokeWhite`… tự lần ra armature gốc),
      `PlayEffectThenDisappear`, `AddPhiz` (bong bóng biểu cảm: biến thể
      `Face_*` của armature `Face`, động tác `PluginPlay`), `RunShakyByLevel`,
      `ColorLayerFadeIn/Out/To`, `SetBattleBlackLayerFadeOut`, `EndPlot`.
      Động tác kết thúc (`Death`, `Disappear`) nay **rút hình khỏi sân** —
      kịch bản dùng nó để hạ boss chứ không phải để diễn suông.
      Nhóm lệnh trạng thái trận (`SetArmyWaiting`, `SetStateImmunity`,
      `AddPlugin`, `RelateWakeButton`…) **ghi nhật ký** chứ chưa có hành vi
      riêng — ghi lại chứ không đoán. Khoá bằng 9 phép kiểm (`--kichban`)
- [x] **Minimap** — **xong**. Bản gốc không vẽ minimap trong Lua: client chỉ
      trả về **nút** (`CUIGame:getMinimap()` → `ChapterBattle:GetMinimapObj()`,
      tag 107 → con tag 104), engine C++ vẽ chấm vào đó. Đo lúc chạy thì nút
      đó là dải **510×40** ở góc trên-phải và đang hiện. Ta vẽ chấm vào **đúng
      nút đó**: quân ta xanh / địch đỏ, tướng to hơn, cộng khung ngắm cho biết
      phần sân đang trên màn hình. **ĐẶT**: hình dạng chấm, màu, và việc có
      khung ngắm — luật thật nằm trong C++
- [ ] Trận PvP, đấu trường, quốc chiến — **chặn bởi mục 4**, không phải mục
      này. Cần handler offline cho nhóm "Đấu trường / PvP / giải đấu" (9 màn).
      Có một đường đi được: bản gốc ship sẵn `KDBGameTournamentRobotConfig`
      (`ConfigManager:updateTournamentRobotConfig`) — tức đối thủ **máy** có
      số liệu thật trong cấu hình, nên đấu trường một người chơi là làm được
      mà không phải bịa đối thủ. Quốc chiến thì cần nhiều người chơi thật

## 6. Âm thanh

- [ ] **Chưa làm gì.** Bản gốc gọi 93 lần `PlaySoundEffect`, 12 lần
      `PlayBackgroundMusic`; hiện `G_SoundManager` vẫn là bóng.
- [ ] Âm thanh nằm trong bank FMOD (`assets/banks`) — cần bộ đọc riêng

## 7. Đóng gói

- [ ] Chạy trên Android / iOS (hiện chỉ chạy trên máy bàn)
- [ ] Màn tải, cập nhật tài nguyên
- [ ] Máy chủ thật (Nakama đã có phần luật trận + chống gian lận)

---

## 8. Việc tiếp theo, xếp theo giá trị

1. **Handler offline cho nhóm đông nhất.** Nhưng đọc mã trước khi chọn nhóm —
   xem cảnh báo ở mục 4. Nhóm gọn và chắc chắn cần dữ liệu thật: **bang hội**
   (10 màn) và **ải vô tận / Epic** (11 màn).
   Mẹo đã dùng được hai lần: bảng nào client tự khai `InitData()` thì lấy hình
   dạng từ đó; luật nào server giữ thì tìm SỐ trong bảng cấu hình trước khi kết
   luận là mất.
2. **Chốt đốm xanh ở Main** bằng máy ảo Android — một lần chạy là xong, và
   máy ảo còn dùng lại được để đo tiếp 9,3% tag còn thiếu.
3. **Âm thanh.** Chưa có gì; game câm thì cảm giác vẫn chưa phải game.
4. **Bỏ mấy chỗ ĐẶT trong trận** — chỗ đứng, tốc độ, hồi thống soái — bằng
   cách đọc tiếp `libgame.so` hoặc đo trong máy ảo.

Việc 1 là việc nhiều nhất và ít rủi ro nhất. Việc 2 rẻ và mở đường cho việc 4.
