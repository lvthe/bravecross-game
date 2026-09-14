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
python tools/check.py          # 24 bộ, phải xanh hết
```

Kéo `brave-cross` mới về thì dựng lại `ui_ref` + `layout_ref` + tag (README,
bước 2 và 2b) trước khi tin kết quả kiểm: dữ liệu cũ hỏng **lặng lẽ**.

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
(7) **còn thiếu ở Main**: hiệu ứng sáng vẽ thành đốm xanh, `sngFixInfoReflash`,
kéo cuộn lớp thành phố,
(8) **chiến dịch chạy trọn**: Main → chọn ải → bố trí quân → trận → màn kết
thúc, qua handler offline `handlers/chapter.lua` (gọi luật server có sẵn trong
`sc/share/share_ChapterLogic.lua`) và `g_BattleField` giả (`lua/san_tran.lua`
+ `battle/tran_goc.gd`, có hình: `battle/san_tran_ve.gd` — `BattleUnit` +
`SngRig` trên nền trận của bản gốc). Trận đánh bằng chỉ số THẬT luật gốc gửi
vào, nhưng công thức sát thương, chỗ đứng và tốc độ là CỦA TA. Đưa lính ra
trận đã có (nút binh chủng `btnBattlefieldArmy` + thống soái trong
`lua/san_tran.lua`; cách hồi thống soái là ĐẶT). Thức tỉnh: dòng điều khiển
nút theo bản gốc (`InitSkillButton`, `SetSkillButton*`, `NoticeCastSkill`),
còn hiệu ứng kỹ năng là ĐẶT (đòn kế tiếp là đòn kỹ năng) — luật thật nằm
trong các lớp C++ `CDFSpriteFight*Wake`. Chỗ đứng theo số thật (1 ô = 100 px,
`PosX` tính theo ô), camera bám quân với hằng số của `map/global_config.xml`
và nền trôi theo hệ số parallax `+0x30` của bản ghi node (cách bám là ĐẶT).
Sát thương trận có hình dùng CÔNG THỨC THẬT của bản gốc (`battle/harm.gd`:
cấu trúc hàm C++ `0x380c94` + hằng số `<formula>` của `global_config.xml`;
bật bằng `rules['harm_real']`, chỉ trận có hình). Mô hình đối chiếu ba bên
(`combat.gd` mặc định / `sim` / `server`) GIỮ NGUYÊN. Ánh xạ trường sang bên
đánh/chịu là ĐẶT (chưa kiểm byte-exact, cần máy ảo). Chưa có: kịch bản,
minimap (nhưng có kịch bản). Đo và khoá: `tools/do_chien_dich.gd`

Kịch bản trận (`sc/plot/drama_*.lua`) chạy bằng `lua/kich_ban.lua`
(`DFDramaScriptSystem` giả, chạy coroutine + điều kiện đi tiếp). Bật bằng cờ
`G_KICHBAN` (mặc định TẮT để `--kiem` giữ 16/16); đo: `do_chien_dich.gd
--kichban`; và `--xem`/`--chup` cũng bật `G_KICHBAN` nên chơi tay diễn trọn
hướng dẫn và thắng được ải 1. (`--kiem` KHÔNG bật.) Đồng minh kịch bản NHẬP TRẬN thật
(`TakeUnitJoinBattle` -> `san_tran_ve.dua_dong_minh`, chỉ số từ
`GetNpcConfigWithNpcId`), boss bị rút (`MakeUnitToPlotSprite` ->
`xoa_theo_hinh` khớp tên armature) — nhờ đó **ải 1 thắng được** đúng cách bản
gốc (không chỉnh số). Tuyệt chiêu kịch bản (`SetRoleChangeFight` "Wake" ->
`tuyet_chieu` AoE, sát thương THẬT, số đòn ĐẶT), quân vào trận từ mép, camera
lia (`CameraMoveBy` -> `lia_camera`), khớp boss chính-xác-trước cũng đã làm.
Còn ĐẶT/ghi-lại: `SetCameraScale` (thu phóng lệch toạ độ chạm), đường đi/hiệu
ứng điện ảnh, lớp phủ `g_CGuideLogical`.
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

Đốm xanh ở Main (hiệu ứng sáng) — ĐÃ KHOANH VÙNG, CHƯA GIẢI. Nó là armature
`UITongYong` (UI通用), xương `sad`, các ảnh `UITongYong_Res-lizi*`
(粒子 = hạt), vẽ bằng `SngRig` ngay trên hai nút `spFirstPayGiftBg` /
`新手特权` của `lMainToolbarRightTop`. Đã đo:

  * Ảnh nguồn ĐÚNG: 128×128 RGBA, alpha thật (81% pixel trong), màu phần hiện
    là xanh (60,100,238). Không phải lỗi giải `.pkm`.
  * Bản ghi armature KHÔNG có cờ trộn màu: quét 418 file `.xml` / 13.543 bản
    ghi sprite — `+0x18` và `+0x1C` luôn bằng 0; byte cờ trong bản ghi REF
    (`+0x10`) chia ~50/50 ở CẢ hai nhóm (hạt và bộ phận thường) nên không phải
    cờ đánh dấu hạt.
  * Game CÓ lưu cách trộn màu, nhưng ở chỗ khác: các `.plist` HẠT THẬT của
    Cocos (`beachfirebig.plist`…) có `blendFuncSource` / `blendFuncDestination`.
    Armature thì không.

Nên rất có thể bản gốc vẽ mấy ảnh này theo kiểu CỘNG (additive) — xanh cộng
vào nền trời ra ánh sáng, còn vẽ thường thì ra khối xanh đặc như hiện nay.
NHƯNG chưa chứng minh được, và `libgame.so` có `setBlendFunc`, `glBlendFunc`,
`sngShaderFlashBlend` nên câu trả lời nằm bên C++.

Hai cách giải dứt điểm, chưa làm: (1) chụp màn `Main` của BẢN GỐC trong máy ảo
Android — cách đã dùng để đo tag, một lần chạy là xong; (2) đọc chỗ vẽ armature
trong `libgame.so` xem có gọi `setBlendFunc` không (`armdis.py`, `xref.py`).

ĐỪNG đặt đại additive khi chưa có một trong hai — sẽ thành một chỗ "đẹp hơn
nhưng không biết có đúng không", và đó là kiểu sai khó gỡ nhất.

Lớp offline (thay máy chủ) nằm ở `../brave-cross/work/offline`, test bằng
`python run_tests.py` ở đó. Sửa nó xong phải chạy lại `tools/import_lua.py`.

Bấm được: `lua/cocos.lua` (`M.cham`) + `LuaRuntime.touch_at`, kiểm bằng
`tools/verify_cham.gd`. 243/353 màn mở được; phần lớn 88 màn hỏng là vì thiếu
dữ liệu người chơi, không phải thiếu engine.
