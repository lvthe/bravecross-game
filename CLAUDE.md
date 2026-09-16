# Ghi chú cho Claude

Dự án dựng lại game di động cũ **Búa Tạ** (`com.cmn.buatanew`) bằng Godot 4.7,
từ bản đã dịch ngược. Hai repo, nằm cạnh nhau:

* `brave-cross/` — công cụ dịch ngược (Python). Giải `.xgg`, `.pkm`, bảng cấu
  hình, đo tag từ máy ảo Android.
* `bravecross-game/` — game Godot. **Thư mục làm việc chính.**

## Nguyên tắc

1. **Giữ đúng luật và con số của bản gốc.** Chỗ nào dữ liệu gốc không khôi phục
   được thì **nói ra**, đừng bịa cho có. Đã có lần bịa `AchieveType = 101..106`
   và `Award = {1..6}` — cả hai sai kiểu, và chỉ không lộ vì lúc đó thiếu module
   nên mã gốc đi nhánh khác.
2. **Chạy mã gốc, đừng chép tay.** Màn hình mới thì đi đường
   `<quản lý>:Show(<tên>)` (xem README, mục "Chạy thẳng mã Lua của bản gốc"),
   không dựng lại bằng GDScript.
3. **Đo, đừng đoán.** Mọi khẳng định về định dạng `.xgg` hay hành vi bản gốc
   phải có cách kiểm chứng độc lập — đối chiếu với hằng số viết trong mã Lua,
   với bảng sprite trong chính file đó, hoặc với bản gốc chạy trong máy ảo.
   Đã bác bỏ hai giả thuyết kiểu này ("`0xA4` là tag", "cây node dựng theo BFS").
4. **Đừng sửa `sc/`.** Đó là mã gốc bê vào, `tools/import_lua.py` ghi đè mỗi
   lần chạy. Cần vá vết dịch ngược thì vá trong `import_lua.py` bằng một luật
   hẹp (hiện có đúng một luật, dính 1 chỗ trên 973 file).

## Trước khi làm gì

```bash
python tools/check.py          # 33 bộ, phải xanh hết
```

Kéo `brave-cross` mới về thì dựng lại `ui_ref` + `layout_ref` + tag (README,
bước 2 và 2b) trước khi tin kết quả kiểm: dữ liệu cũ hỏng **lặng lẽ**.

**Bẫy đã mắc một lần, ghi lại vì nó im lặng:** `layout.py` **ghi đè** và **xoá
hết tag** đã đo — chạy nó xong mà quên `emu_join.py --ghi` thì `layout_ref` về
**0/33.472 tag** (đo được), và triệu chứng không phải một bộ kiểm đỏ mà là
**9 bộ đỏ cùng lúc**, tất cả ở những suite đi qua chuỗi Login → `Main`:
`CUIBuyDialog.lua:199: attempt to index local 'lLaodingBG' (a nil value)` —
mã gốc trỏ node bằng tag, thiếu tag thì node ra `nil`. Chạy lại `--ghi` thì về
đúng **27.887/33.472 (83,3%)** như cũ và cả 9 bộ xanh lại. Sửa `layout.py`
(cần cho việc mới) thì **luôn** chạy lại bước 2b ngay sau đó.

Sau khi `git pull` mà thấy `class_name` báo "not declared":

```bash
godot --headless --path . --import
```

Máy này Godot không có trong PATH:
`C:\Users\lvthe\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`

## Quy ước viết

* Chú thích trong mã: **tiếng Việt không dấu** (file `.gd`, `.lua`, `.py`).
  README và tài liệu thì tiếng Việt có dấu.
* Chú thích nói **tại sao**, kèm **số đo** khi có. Không nói lại cái mà dòng mã
  đã nói.
* Tên hàm/biến mới trong lớp giả lập: tiếng Việt không dấu
  (`sap_xep_theo_z`, `ghep_vao`, `la_lop`) — trừ chỗ phải khớp tên API của
  Cocos hay của bản gốc.
* Thông điệp commit: một dòng tiêu đề nói **kết quả**, rồi thân bài nói cách
  kiểm chứng và con số. Không dùng tiền tố kiểu `feat:`.

## Đang làm dở

Danh sách đầy đủ mọi phần cần làm và chỗ đang đứng: **`ROADMAP.md`**.
Mục dưới đây là chi tiết kỹ thuật của những phần đã đụng tới.

Xem README mục "Chạy thẳng mã Lua của bản gốc" → "Việc tiếp theo, theo thứ tự".
Tóm tắt: (1) nối chạm — **xong**, (2) dựng cảnh `Main` — phần engine xong,
(3) trạng thái người chơi mới — **xong** (từ mục `*Reset` của bảng cấu hình
gốc, giao qua lớp offline; `tools/vao_main.gd` chạy cả chuỗi Login → `Main`),
(4) 40 nút `lMainToolbarRightTop` — **xong** bằng đối chiếu nhãn
(`brave-cross/work/tags_nhan.json`, tag đánh dấu `tagFrom: "nhan"`, KHÁC tag đo),
(5) tag node con bên trong nút — **xong** bằng suy cấu trúc (`do_tin:
"cau-truc"`, có đối chiếu với nút cùng kiểu đã đo); cả chuỗi Login → `Main`
chạy trọn và `g_MainUIScene` lên màn hình,
(6) vẽ `Main` — **xong phần chính**: trời (dải màu `.xgg`), thành phố, nhà
(armature qua `SngRig`), dải nút trên cùng, biển tên nhà (chữ nhãn đọc từ
`+0x138`, căn chữ `+0x100`/`+0x104`), số của người chơi. Chụp:
`godot --path . --script tools/vao_main.gd -- --chup=main.png`; mở cửa sổ
để bấm tay: `... -- --xem` (bấm tới trận được — khoá bằng `tools/bam_that.gd`;
lớp phủ nào nuốt cú bấm thì bộ đó chỉ ra node và vết gọi),
(7) **còn thiếu ở Main**: `sngFixInfoReflash` — **luật và tám số nó đọc nay đã
đo xong** (số nằm ngay trong `.xgg` ở `+0x38`..`+0x54`, `+0x38` là kiểu **y**
TRƯỚC rồi mới tới kiểu x; kiểu 1/3 dùng hộp đã co giãn còn kiểu 2 dùng hộp chưa
co giãn; luật đầy đủ, cách kiểm lại và năm bước cài vào port ghi ở `ROADMAP.md`,
mục 9 của "Bảng hàm thiếu" — trong đó bước đổi `stretch/aspect` sang `expand` là
điều kiện để bốn bước kia có tác dụng, vì `keep` thì canvas luôn đúng 960×640);
kéo cuộn lớp thành phố —
**xong** (`lua/cuon.lua`, lớp `CCScrollLayer` của engine: 315 node trong 296
bố cục, đo bằng `tools/verify_cuon.gd`); (hiệu ứng
sáng vẽ thành đốm xanh — **xong**, xem mục "Đốm xanh ở Main"),
(8) **chiến dịch chạy trọn**: Main → chọn ải → bố trí quân → trận → màn kết
thúc, qua handler offline `handlers/chapter.lua` (gọi luật server có sẵn trong
`sc/share/share_ChapterLogic.lua`) và `g_BattleField` giả (`lua/san_tran.lua`
+ `battle/tran_goc.gd`, có hình: `battle/san_tran_ve.gd` — `BattleUnit` +
`SngRig` trên nền trận của bản gốc). Trận đánh bằng chỉ số THẬT luật gốc gửi
vào, nhưng công thức sát thương, chỗ đứng và tốc độ là CỦA TA. Đưa lính ra
trận đã có (nút binh chủng `btnBattlefieldArmy` + thống soái trong
`lua/san_tran.lua`; cách hồi thống soái là ĐẶT). Thức tỉnh: dòng điều khiển
nút theo bản gốc (`InitSkillButton`, `SetSkillButton*`, `NoticeCastSkill`),
còn hiệu ứng kỹ năng: SỐ lấy từ cấu hình gốc qua `WakeRef`, luật ghép vẫn ở
các lớp C++ `CDFSpriteFight*Wake` (xem mục "Thức tỉnh" bên dưới). Chỗ đứng theo số thật (1 ô = 100 px, `PosX`
tính theo ô, làn theo `Location` — xem mục "Chỗ đứng quân" bên dưới), camera
bám quân với hằng số của `map/global_config.xml` và nền trôi theo hệ số
parallax `+0x30` của bản ghi node (cách bám là ĐẶT). Minimap: XONG.
Sát thương trận có hình dùng CÔNG THỨC THẬT của bản gốc (`battle/harm.gd`:
cấu trúc hàm C++ `0x380c94` + hằng số `<formula>` của `global_config.xml`;
bật bằng `rules['harm_real']`, chỉ trận có hình). Mô hình đối chiếu ba bên
(`combat.gd` mặc định / `sim` / `server`) GIỮ NGUYÊN. Ánh xạ trường sang bên
đánh/chịu ĐÃ ĐO, không còn ĐẶT — xem mục riêng bên dưới. Chưa có:
Đo và khoá: `tools/do_chien_dich.gd`

(9) **thanh / vòng tiến độ** (`CCProgressTimer`) — **xong**, xem mục "Thanh
tiến độ" bên dưới. Trước đó **cả 325 node** bị coi là sprite và **vẽ đầy đặc ở
mọi phần trăm**: thanh máu HUD luôn đầy, thanh nạp game không bao giờ chạy.
Vẽ được rồi vẫn chưa chạy: **hai action** đẩy phần trăm (`S_CCProgressTo` 49
chỗ gọi, `S_CCProgressFromTo` 14) là **bóng** cho tới lượt này — xem mục
"Thanh tiến độ", đoạn cuối.

Kịch bản trận (`sc/plot/drama_*.lua`) chạy bằng `lua/kich_ban.lua`
(`DFDramaScriptSystem` giả, chạy coroutine + điều kiện đi tiếp). Bật bằng cờ
`G_KICHBAN` (mặc định TẮT để `--kiem` giữ 22/22); đo: `do_chien_dich.gd
--kichban`; và `--xem`/`--chup` cũng bật `G_KICHBAN` nên chơi tay diễn trọn
hướng dẫn và thắng được ải 1. (`--kiem` KHÔNG bật.) Đồng minh kịch bản NHẬP TRẬN thật
(`TakeUnitJoinBattle` -> `san_tran_ve.dua_dong_minh`, chỉ số từ
`GetNpcConfigWithNpcId`), boss bị rút (`MakeUnitToPlotSprite` ->
`xoa_theo_hinh` khớp tên armature) — nhờ đó **ải 1 thắng được** đúng cách bản
gốc (không chỉnh số). Tuyệt chiêu kịch bản (`SetRoleChangeFight` "Wake" ->
`tuyet_chieu` AoE, sát thương THẬT, số đòn ĐẶT), quân vào trận từ mép, camera
lia (`CameraMoveBy` -> `lia_camera`), khớp boss chính-xác-trước cũng đã làm.
Toàn bộ 60/60 lệnh `g_DramaSystem` đã có (xem mục "Canh điện ảnh").
Còn ghi-lại: lớp phủ `g_CGuideLogical`.
(`--kiem`; chụp giữa trận: `--chup=tran.png`, thêm `--cam=2500` để thấy nền
trôi; chơi thử một trận: `--xem`; hai chế độ sau chạy KHÔNG `--headless`).
Armature đổi ảnh theo khung: `+0x2C` (chỉ số ảnh, −1 ẩn) và `+0x40` (số khung
giữ) của bản ghi khung, `anim.py` ghi thành `d` / `dur`; `SngRig` làm theo.
Sửa `anim.py` thì xuất lại JSON: `python ../brave-cross/work/export.py --all
--json-only --out assets_ref` (không cắt lại PNG).

Điểm neo: CCLayer và CCScene **bỏ qua neo khi đặt chỗ** (góc dưới-trái nằm
tại x, y — `XggLayout.bo_qua_neo`), nhưng neo vẫn giữ trong meta `cocos` vì mã
gốc đọc `getAnchorPoint()` (vd `CUIHelper:fixListViewPosition`). Bằng chứng:
chuỗi `ignoreAnchorPointForPosition` trong `libgame.so`, bản sao Thần Tài đặt
ở (−w/2, −h/2), và nút thức tỉnh chỉ ra đúng chỗ khi theo luật này.
CCLayerColorRoundRect **chưa đo**, vẫn áp neo.

Tag trong bố cục có ba nguồn, đừng trộn: đo từ máy ảo (`tags_that.json`), đối
chiếu nhãn và suy cấu trúc (`tags_nhan.json`, đánh dấu `tagFrom: "nhan"`).

Rơi đồ: luật sinh của server không được ship, nhưng SỐ thì có đủ trong cấu
hình gốc — `KDBGameNpcConfig[NpcID].DropData` (mỗi mục có `DropValue` +
`PrizeData`) và `TotalDropValue` (mẫu số 100 hoặc 10000). Mã đơn vị
`"<nhóm>-<lính>-<bản sao>"` do SÂN TRẬN đặt (bản gốc: engine C++), client chỉ
gom rồi gửi lại — nên chỉ cần `battle/tran_goc.gd` và `offline/handlers/
chapter.lua` khớp nhau. Dạng mã đọc ra từ ví dụ trong chú thích đầu
`CUIGameFinish.lua` ("1-1-1", "1-1-2", "1-1-3", "1-2-1") đối chiếu với
`ChapterInfo.Groups`. **ĐẶT**: mỗi mục quay riêng với xác suất
`DropValue/TotalDropValue` — căn cứ là 167/331 NPC có tổng `DropValue` vượt
mẫu số nên không thể là một lần quay chọn một món. Lưu ý: chính client chèn
thêm khoá `DropList` vào bảng `Drop`, và màn kết thúc bỏ qua nó
(`CUIGameFinish.lua:1885`) — phép đo cũng phải bỏ qua.

Phần thưởng vào đâu: `SetDataWithPrizeData` rẽ theo `PrizeResType` —
`Prop` (2) gọi `AddItem` (cộng vào `ItemCount` của mục sẵn có và bật cờ
`IsExist`, nên **số mục không đổi**), `Resource` (3) cộng thẳng vào vàng /
kim cương / binh hồn (`CurrencyType` 4 = `ArmySoul`, chiếm 272/311 mục) chứ
không tạo mục nào. Nên ĐỪNG đo bằng cách đếm mục trong túi — đã thử và bỏ:
người chơi mới còn có sẵn trang bị khởi đầu nên số nền không phải 0, và
phép đo theo chênh lệch thì phụ thuộc lần quay. Phép kiểm đang dùng là loại
XÁC ĐỊNH: thử phát từng mục rơi có thể có của ải 1 (40 mục) và đòi tất cả
đều trả `true` (`do_chien_dich --kiem`). **Còn treo**: đo theo chênh lệch túi
thỉnh thoảng ra 0 trong khi có mục vật phẩm rơi — chưa truy ra, nhưng phát
thưởng từng mục thì luôn thành công, nên nghi ở chỗ đo chứ không ở đường
phát.

Bảng người chơi: kho offline giữ 37 bảng. Bốn bảng cuối (`GameUserGuildData`,
`GameUserCloudShop`, `GameUserStateWar`, `GameUserRankTitle`) client hỏi tới
bằng **chuỗi** chứ không qua `EventManagerTableName` nên trước đó lọt lưới —
tìm ra bằng cách quét mọi `GetUserDataWithName("...")` trong 973 file rồi trừ
đi danh sách đang có. Thiếu một bảng thì **không báo gì**:
`GetUserDataWithName` rơi xuống `initUserDataFromDB` và trả mã lỗi, người gọi
`goto Exit0` lặng lẽ — đó là lý do `CUIGuildControl:onInit` không chạy tiếp.

Bang hội là tính năng NHIỀU NGƯỜI CHƠI. Offline chỉ có một người và không có
kho bang hội, nên `ClientGetGuildInfo` trả đúng mã `GuildNotExist` (3501) của
bản gốc chứ không dựng một cái bang giả. `GuildId ~= 0` là phép thử "có bang"
mà chính client dùng. Tạo bang / xin vào / quyên góp / chiến bang đều cần
người chơi khác — nếu làm thì thuộc về máy chủ thật, không phải lớp offline.

Tốc độ di chuyển: **đừng dùng `MovingSpeed`** của bảng chỉ số trận. Nó không
hề có trong `libgame.so` — quét bảng tên chỉ số của engine (quanh `0x7b42f0`)
thì có `AttackInterval`, `InjuryRates`, `MaxAttackDistance`, `NpcSize`,
`ClosePressing`, `Jump`… mà không có nó; client cũng chỉ dùng nó làm chỉ số
hiển thị (`PropertyType.MovingSpeed = 21`). Tốc độ thật: mỗi sprite có
`<sMove>` trỏ tới một khối `<move>` trong `map/*_config.xml`, khối đó ghi
`<ptVector>` (đi) và `<ptRunVector>` (chạy), đơn vị **ô**, 1 ô = 100 px
("单位:格 100pix"). Bê ra bằng `work/move_speed.py` → `data_ref/move_ref.json`,
tra bằng `MoveRef.di()` / `MoveRef.chay()`. ĐẶT: ta lấy tốc độ ĐI; engine chọn
đi hay chạy lúc nào thì do "brain" bên C++.

`SetCameraScale(giây, tham2, tỉ lệ, x, y)` — ĐÃ GIẢI HẾT bằng hàm engine
`0x366c7c` (tìm qua bảng bind Lua `.data:0x939704` → `0x467fb4`). Tỉ lệ ở tham
số **3**, điểm tâm ở (4, 5). Tham số **1 là thời gian chạy**: `0x366c9a` so nó
với hằng **0.001** — dưới ngưỡng thì đặt tỉ lệ NGAY, trên thì `CCScaleTo` chạy
dần. Cả bốn chỗ gọi (`plot/drama_L_XSGK.lua`) đều truyền **0.5 giây**, nên bản
gốc chạy dần; `dat_thu_phong` nay nội suy trong chính bước khung của sân trận
(KHÔNG dùng `Tween`: node sân trận nằm ngoài cây cảnh, `Tween` đòi node trong
cây — bộ đo headless chỉ ra điều này). Tham số **2 cũng là một khoảng thời
gian**: nó đi vào `0x4a9040`, hàm đó ghi tham số vào `+0x24` và thay 0 bằng
`0x34000000` = `FLT_EPSILON` — đúng thân `CCActionInterval::initWithDuration`
của Cocos2d-x; cả bốn chỗ gọi đều truyền 0 nên không đổi hành vi.
Lý do cũ "thu phóng làm lệch toạ độ chạm" **không còn đúng**
— `LuaRuntime._bien_doi` đi trọn chuỗi biến đổi rồi nghịch đảo nên node cha bị
phóng to vẫn chạm đúng (khoá bằng `verify_cham.gd`).

Sát thương — ánh xạ trường sang bên đánh / bên chịu: ĐÃ ĐO, đọc thẳng từ **chỗ
điền struct** (`0x41ab82..0x41ad08`) chứ không suy theo nghĩa của tên.
`0x380c94` nhận một struct 0x4c byte; chỗ điền lấy từng ô từ hai đối tượng:
`r5` = bên đánh (CÓ THỂ NULL — `cmp r5,#0; beq` nhảy thẳng tới chỗ gọi),
`r6` = bên chịu. Bảng đối chiếu đầy đủ nằm ở đầu `battle/harm.gd`. Cả bốn giả
định cũ đều đúng. Ba chỗ đã sửa theo số đo: `fDamageMultiples` có **ba** ô
(`0x3d49d4`: `AtHero` khi mục tiêu là tướng, `AtBoss` khi `NpcType == 5`, còn
lại `AtDogface` — `NpcType 5` = boss theo `CUIChapterInfo.lua:1182`); hệ số bỏ
qua giáp **chỉ nhân khi `nDp > 0`** (`0x380cde`); `FinalHarm` (`0x380c00`) đã
giải hết thứ tự, chặn dưới thật là `-(0.5 + r6[0x59c])` chứ không phải `-1`
(vẫn giữ −1 vì chưa đọc được giá trị mặc định). Tên trường lấy từ bộ dựng
`0x3808d8` (strcmp), khoá bằng 5 phép kiểm trong `tools/verify_battle.gd`.

Hồi thống soái: `LeaderShipResume` là **số giây để hồi 1 điểm**, chứng minh
bằng chính mã gốc — `SkillLogic:CommandReviveAccelerate`
(`sc/share/SkillLogic.lua:579`) làm `addtionPerSec = 1/LeaderShipResume` rồi
ghi ngược `LeaderShipResume = 1/addtionPerSec`. Còn ĐẶT: vào trận thì đầy
thống soái.

Chỗ đứng quân: LÀN là số thật. `Location` (1..3) của bản ghi sprite quyết
định làn (Defender 1, Archer 3; 0 = không có làn riêng). Khoảng cách lấy từ
`map/global_config.xml`: `fLaneWidth = 0.4` ô = 40 px, `fLaneOffset = 0.1` ô
= 10 px, khoảng cách hai quân cùng làn `fArmySpace = 1.1` ô = 110 px. ĐẶT:
đơn vị của hai hằng làn là ô (suy từ chính file đó — mọi hằng khác trong nó
đều tính bằng ô), và thứ tự xếp khi `Location = 0`.

`ptLayout`: ĐỪNG đoán tiếp, HAI giả thuyết đã bị bác bỏ bằng số đo — "đội hình
của toán lính" (tích `x*y` khớp `MaxUnit` ở 0/6 binh chủng) và "kích thước
chiếm chỗ" (không tương quan `NpcSize`: nhóm `{3,3}` trung bình 0.83 < nhóm
`{1,1}` 1.02). Chỉ 67 sprite đặt nó, 42 trong số đó là `{1,1}`. Lưu ý phép đo:
phải bóc theo ĐÚNG khối `<item>`; regex "từ `<sName>` tới `<ptLayout>` gần
nhất" cho kết quả SAI (lần trước ra "Archer {1,3}, Defender {1,2}" trong khi
hai sprite đó không hề có `ptLayout`). Bộ đọc cấu hình (`0x35cff8..0x35d026`)
ghi nó vào `+0x460`, nhưng trong `.text` không có chỗ nào đọc `+0x460` trực
tiếp (engine đọc qua bảng tên) — nên không khôi phục được nếu không chạy bản
gốc. `InWhichCell` (`0x35ec4c`) nhận điểm tính bằng PX, loại điểm âm và điểm
vượt *cỡ ô × số ô*, rồi chia lấy chỉ số ô.

Thức tỉnh: số liệu lấy từ CẤU HÌNH GỐC, không còn con số nào của ta.
`work/wake_ref.py` → `data_ref/wake_ref.json` (247 khối `<fight>` tên
`fight_<Sprite>Wake`), tra bằng `WakeRef`. **Số đòn** = 1 + số trường
`fSectionIntervalWake_F<n>`, chặn trên bởi `nAttackSectionLimitWake` — Triệu
Vân 1, Quan Vũ 6, Tào Thực 3. `nSplitWake` là **số mục tiêu chia đều sát
thương**, KHÔNG phải số đòn: `global_config.xml` ghi `<nSplitNumForAOE>6` ngay
dưới chú thích "群攻分摊个数". ĐẶT: cách ghép (`dmg * (1 + fDamageBonusWake)`,
hệ số chia `clamp(nSplitWake/n, fSplitFloorWake, 1)`) và việc đánh KHẮP địch —
luật thật ở ~80 lớp C++ `CDFSpriteFight*Wake`.

Lỗi đã sửa, đáng nhớ: `SetRoleChangeFight` bị ta coi là AoE ở MỌI lần gọi, kể
cả khi nó chỉ đổi tư thế (`Fight`, `Fight20`). Ở ải 1 là 2 Triệu Vân × 3 lần
gọi = 6 lần AoE không có thật — chính nó (chứ không phải số đòn) là thứ giữ
cho ải 1 thắng. Nay chỉ `Wake*` / `Talent*` mới gây sát thương.

Canh điện ảnh: đối chiếu 56 file `sc/plot/drama_*.lua` với `lua/kich_ban.lua`
cho danh sách lệnh còn thiếu — trước là 35/60, nay **60/60**. Chữ ký đọc từ
chính chỗ gọi (đếm số tham số ở mọi lần gọi). `MoveThenDoAction` và
`PlayEffectInMap` tính toạ độ bằng Ô. `AddPhiz` là bong bóng biểu cảm: biến
thể `Face_*` của armature `Face`, động tác `PluginPlay`. Động tác `Death` /
`Disappear` RÚT hình khỏi sân — kịch bản dùng nó để hạ boss. Nhóm lệnh trạng
thái (`SetArmyWaiting`, `SetStateImmunity`, `AddPlugin`, `RelateWakeButton`…)
chỉ ghi nhật ký.

Minimap: bản gốc KHÔNG vẽ nó trong Lua — client chỉ trả về nút
(`CUIGame:getMinimap()` → `ChapterBattle:GetMinimapObj()`, tag 107 → con tag
104), engine C++ vẽ chấm. Đo lúc chạy: dải 510×40, đang hiện. Ta vẽ chấm vào
đúng nút đó (`san_tran_ve.dat_minimap`). ĐẶT: hình dạng chấm, màu, khung ngắm.

Đốm xanh ở Main (hiệu ứng sáng) — **XONG**. Nó là armature `UITongYong`
(UI通用), xương `sad`, các ảnh `UITongYong_Res-lizi*` (粒子 = hạt), vẽ bằng
`SngRig` ngay trên hai nút `spFirstPayGiftBg` / `新手特权` của
`lMainToolbarRightTop`.

**Cách trộn nằm trong TỪNG KHUNG, không phải một chế độ của cả armature.**
Bản ghi khung (`anim.py`, 80 byte) có ở `+0x38` một cặp `(str_off, str_len)`
trỏ tới một **tên cách trộn** trong pool chuỗi. Hàm phân nhánh của engine ở
`libgame.so` `0x25d476..0x25d4ce` (Thumb-2; `findstr` giải được hai chuỗi nó
đem so: `0x25d496` → `"screen"`, `0x25d4ac` → `"multiply"`), đọc ra đúng cặp
hệ số:

| tên trong khung | `+0x78` | `+0x7c` (nguồn) | `+0x80` (đích) | GL |
|---|---|---|---|---|
| rỗng, hoặc tên lạ | 0 | 1 | `0x303` | `GL_ONE, GL_ONE_MINUS_SRC_ALPHA` (mặc định Cocos) |
| `'screen'` | 1 | `0x302` | 1 | `GL_SRC_ALPHA, GL_ONE` — **trộn CỘNG** |
| `'multiply'` | 2 | `0x306` | `0x303` | `GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA` |

Thứ tự hai hệ số chốt được nhờ cặp `multiply`. Tên lạ rơi vào nhánh mặc định
(`0x25d4c6`) — nên **trả về `null` (vẽ thường) mới là theo bản gốc**, không
phải đoán.

Từ vựng đo trên **418 file `.xml` / 644.623 khung**: `'normal'` 462.413, rỗng
157.033, `'screen'` 22.083, `'undefined'` 3, `'overlay'` 3, `'lighten'` 1,
cộng vài chỗ rác ở `BingYing.xml` / `XSJiYouHeTiJi.xml`. **`'multiply'` không
xuất hiện lần nào** — nên chưa viết shader cho nó, chỉ `push_warning` một lần
thay vì vẽ im lặng sai.

Đối chiếu hai đường độc lập, khớp nhau:

* **Đo trên máy ảo** (`work/emu_dom.py`, bản gốc chạy trên nền trời sáng,
  9/9 biến thể đúng như dữ liệu nói): `UITongYong_ItemLight` có 32/32 khung
  `'screen'` và đo ra **sáng lên ở MỌI kênh** — nền `(100,245,248)` → có hiệu
  ứng `(164,251,251)`, đỉnh `(255,255,255)`, Δ kênh r = `+64`. Trộn thường cần
  `src_r ≥ 164` trong khi ảnh nguồn chỉ `78,7` — bất khả; trộn cộng cho
  `a_eff = 64/78,7 = 0,81`, dự đoán Δg = 102 / Δb = 201, cả hai bão hoà 255
  (đo 251). Hình tượng `DaQuZhanShi` (0 khung `screen`) ngược lại: r −16, g −94,
  b −84 — **trộn cộng không bao giờ làm tối một kênh nào**, nên nó vẽ thường.
* **Đọc mã** như bảng trên.

**Bẫy đã mắc, đáng nhớ.** `SngRig` lần đầu gắn `CanvasItemMaterial` lên **node
xương** (`Node2D`) — phép thử trong `verify.gd` vẫn xanh (nó cũng đọc node
xương) mà ảnh `Main` **không đổi một điểm ảnh nào**. Đo bằng điểm ảnh thật
(`tools/do_tron.gd`) mới ra: **vật liệu của node CHA không truyền xuống
`Sprite2D` con trong Godot 4** — nền 0,235 + ảnh xám 0,392: không vật liệu
0,3882, vật liệu ở node cha 0,3882 (y hệt), vật liệu ở chính `Sprite2D` 0,6235.
Nay `_dat_tron()` gắn lên **từng `Sprite2D`**, và phép thử đọc `Sprite2D`.
Bẫy thứ hai: **đường phương thức của `AnimationPlayer` không chạy khi gọi
`advance()`/`seek()`**, kể cả với `ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE` —
phải để khung thật chạy qua (`await process_frame`), nên rig phải nằm trong cây
và phép thử phải là hàm chờ.

Kết quả: A/B trên ảnh `Main` (`--chup` hai lượt, một lượt để `BLEND_CONG` thành
chuỗi không khớp) đổi **6.493 điểm ảnh**, lệch lớn nhất 239, gọn trong vùng hai
nút (x 261..471, y 39..142) — đúng chỗ đốm xanh. Vệt sáng nay ra **cung trắng**
chứ không còn khối xanh đặc. `tools/verify.gd`: 3142 đạt / 0 hỏng.

Godot không có chế độ tương ứng `(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA)` của
`'multiply'` (`BLEND_MODE_MUL` là `dst*src`, khác hẳn) — gặp thật thì phải viết
shader riêng. Còn `'screen'` thì khớp sẵn: `CanvasItemMaterial.BLEND_MODE_ADD`
= `GL_SRC_ALPHA, GL_ONE`.

Ô chữ của nhãn: `getContentSize` **không phải** kích thước node. Bản gốc giữ ba
trường riêng — ô (`+0x2c4/+0x2c8`, `getDimensions` đọc), cặp trả lời
(`+0x5c/+0x60`), cờ autoFix (`+0x21c`) — và cờ "bẩn" `+0x20d` bật **vô điều
kiện** trong `setString` nhưng **không** bị `setContentSize` xoá. Nhãn tạo lúc
chạy có ô `(0, 0)`. Luật đầy đủ + số đo + hai lỗi im lặng đã bắt được:
`ROADMAP.md` mục 3, "Ô chữ của nhãn"; khoá bằng `tools/verify_dimensions.gd`.

Lớp offline (thay máy chủ) nằm ở `../brave-cross/work/offline`, test bằng
`python run_tests.py` ở đó. Sửa nó xong phải chạy lại `tools/import_lua.py`.

Thanh tiến độ: kiểu thanh/vòng **KHÔNG phải mặc định của engine** — nó nằm
trong bản ghi `.xgg`, ở ba trường mà ghi chép cũ ở `ROADMAP` §8 từng nói là
không có (phép quét cũ chỉ tìm `midpoint`/`barChangeRate` của Cocos2d-x gốc).
Bản ghi `CCProgressTimer` **luôn đúng 256 byte** (đo cả 325 node / 73 bố cục):
`+0xF4` uint32 = kiểu (`0 cw`, `1 ccw`, `2 lr`, `3 rl`, `4 bt`, `5 tb` — thứ tự
lấy từ bảng phương thức `setType` của engine), `+0xF8` float = phần trăm,
`+0xFC` byte 0/1 **chưa rõ nghĩa** (ghi lại, không dùng để vẽ). Tên ảnh nằm ở
`+0xE4` **chỉ với đúng 1 node** (`ptLoadingGamePercent`), còn `+0xEC` với 323
node — không đọc `+0xE4` thì node ấy ra sprite trắng. Ba điều dễ sai:

* **Vẽ là CẮT, không phải PHÓNG TO** — đo bằng so từng điểm ảnh giữa hai lượt
  chạy chỉ khác `setPercentage`: mép neo đứng yên, **vùng ảnh lấy ra ngắn lại**
  theo phần trăm. Nên `TienDo.o_thanh` cắt **cả hai phía** theo cùng một tỉ lệ.
* **Ô của node lấy theo BẢN GHI, không theo ảnh** — ảnh của hoạ sĩ lệch 1–2 px
  (`v6/ui_blood_23.png` 362×14 cho ô 360×15; 13×13 cho ô 77×13), đó cũng là vì
  sao 314/325 tên ảnh là `guess`. `UiFrames.set_frame` vì thế **không** đổi ô
  của `TienDo`.
* **`C.raw(self)` chứ không phải lớp bọc** — `C.wrap` chốt `__index` về bảng
  `Node`, nên gọi `node:dat_pct(...)` trên lớp bọc **im lặng không làm gì**
  (đo được: không lỗi, `pct` vẫn 100). `lua/tien_do.lua` đi qua `C.raw`.

**Vẽ được rồi vẫn CHƯA CHẠY: hai action đẩy phần trăm là BÓNG.** Bản gốc gọi
`S_CCProgressTo:create` **49 chỗ** (`CPublic` 8, `CUIGameFinishAction` 8,
`CUIHeroUpgradeLevel` 6, `CUIGameFinish` 6, `CUILoad` 5, `CUIQuestRewardGet` 4,
`CUIGame` 3, `CUIHeroInfoUseExpUI` 3, `FBCog`/`FBContest`/`FBNewGuildWar` 2 …)
và `S_CCProgressFromTo:create` **14** (`CUIDamageStatistic` 2,
`CUIGuildCopyFinish` 2, `CUIDownload` 2, `CUIJFZYBattleFinish` 2,
`CUISeaBossFinish`/`CUIArmyGroupCampsite`/`CUIArmyGroupCampsiteChatting`/
`CUIChatting`/`CUIFriendsChatting`/`CUISBAnimRefine` 1 …), tổng **63** chỗ —
đếm bằng `grep` trên `sc/`, không phải ước lượng. Cả 63 chỗ đều **im lặng
không làm gì** vì `system/engine.lua:82-83` chỉ tạo
`CCProgressTo:new()` từ một lớp **không tồn tại**, nên `create` trả về bảng
không có `tien` và `M.runAction` bỏ qua nó **không một lỗi nào**. Nghĩa của hai
action lấy từ chính mã gốc: `CCProgressTo::startWithTarget` lấy `m_fFrom` =
phần trăm **đang có** rồi `update(p)` đặt `m_fFrom + (m_fTo − m_fFrom)·p`;
`CCProgressFromTo::startWithTarget` đặt luôn phần trăm về `m_fFrom` **trước**
khi chạy — khác nhau đúng ở chỗ lấy điểm đầu. Đặt qua node Godot chứ **không**
qua lớp bọc (cùng lý do `C.raw` ở trên). `CUIDownload.lua:62-70` là chỗ **duy
nhất** trong toàn bộ mã gốc gọi `setType`, và nó chạy
`ProgressFromTo(0.8, 0, 100)` + `setType "cw"` rồi `ProgressFromTo(0.8, 100, 0)`
+ `setType "ccw"` trong một `RepeatForever` — nên vòng nạp game đổi **chiều
quét** mỗi nửa vòng. Đo trước/sau bằng chính bộ kiểm: **44 đạt / 8 hỏng** →
**54 đạt / 0 hỏng** (`tools/verify_lua_actions.gd`).

**Bảng mã kiểu đã được dữ liệu xác nhận, không chỉ bảng phương thức.** Quét cả
325 node và đối chiếu mã kiểu với **tỉ lệ ô**: kiểu `0` (`cw`) — **12 node, 11
vuông**, tỉ lệ dài/ngắn **1,00..1,05**, cả 12 là vòng đếm ngược / vòng nạp; kiểu
`2` (`lr`) — 262 node, **1,00..61,43**; kiểu `3` (`rl`) — 49 node, **8,57..24,00**;
kiểu `4` (`bt`) — 2 node, **1,00..4,18**; `ccw (1)` và `tb (5)` **không node nào**.
Tức **vòng thì ô vuông, thanh thì ô dài** — khớp bảng `setType` của engine
(ccw=1, cw=0, lr=2, rl=3, bt=4, tb=5) mà bản dựng đang dùng.

**Và câu hỏi "bán kính lấy theo ô hay theo ảnh" không đặt ra được:** 12 node vòng
có ảnh **đúng bằng** ô (7 node) hoặc lệch **đúng 1 px** (5 node: 27×27 cho ô 28×28;
21×22 cho ô 22×23), **0 node lệch hơn**. Hai luật chỉ khác nhau nửa điểm ảnh.

**Góc bắt đầu / chiều quay của vòng: VẪN KHÔNG ĐO ĐƯỢC, và đã ghi lý do đo được**
(11 lượt `work/emu_pt.py --kieu`): node vòng thật duy nhất nhìn thấy được nằm
**dưới** lớp UI của cảnh Main (đổi `setPercentage` → **0 điểm ảnh**);
`ptLeaderShipTimer` — node vòng có tên thứ hai — có `vis = False` **trong bản ghi**;
10 node còn lại **không có tên** nên không gọi được từ Lua; và đổi `setType`
**khác họ** (thanh → vòng) cho ra **hình rác**, không phải hình quạt — đo trên
`g_ptWarSoulTBar` (ô 71×297, `bt`): `cw` ở 25/50/75% ra **cùng 7820 điểm ảnh trên
cùng khung**, `ccw` ra **0 điểm**; trong khi đổi **cùng họ** thì đúng (`bt`→`tb`
chuyển dải đáy thành dải đỉnh). Mã gốc cũng **chỉ** gọi `setType` trong cùng một
họ (chỗ gọi duy nhất của cả kho: `CUIDownload.lua:62-70`). Bản dựng vì thế vẫn
**đặt** 0° = 12 giờ và chiều dương = kim đồng hồ, ghi rõ là ĐẶT.

**Chiều dài đầy KHÔNG tỉ lệ với phần trăm, và cơ chế thật CHƯA tìm ra** — hai
thanh cho hai luật khác nhau (`L = 1,508p − 23,7`, bằng 0 ở 15,7% trên HUD;
`H = 2,617p − 8,35` trên thanh thống soái). Bản dựng vẽ tỉ lệ thuận và **ghi
lại khoảng lệch** (tối đa ~11 px ở khoảng giữa thanh HUD) thay vì chỉnh số cho
vừa mắt. Cùng loại: `setOrange` (12 chỗ gọi) **cố ý không đặt tên** trong lớp
giả lập để nó còn rơi vào bộ đếm `M.missing` — chưa đo được nó làm gì thì đừng
làm cho nó im. Số đo đầy đủ: `ROADMAP.md` §8 việc 8; khoá bằng
`tools/verify_tien_do.gd` (113 đạt / 0 hỏng).

Bấm được: `lua/cocos.lua` (`M.cham`) + `LuaRuntime.touch_at`, kiểm bằng
`tools/verify_cham.gd`. Số màn mở được: xem bảng đầu `ROADMAP.md` (đo bằng
`tools/quet_show.gd`, con số dao động ±3 giữa các lần chạy). Phần lớn màn hỏng
là vì thiếu dữ liệu người chơi, không phải thiếu engine.
