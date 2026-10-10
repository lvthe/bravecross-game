# Ghi chú cho Claude

Dự án dựng lại game di động cũ **Búa Tạ** (`com.cmn.buatanew`) bằng Godot 4.7,
từ bản đã dịch ngược. Hai repo, nằm cạnh nhau:

* `brave-cross/` — công cụ dịch ngược (Python). Giải `.xgg`, `.pkm`, bảng cấu
  hình, đo tag từ máy ảo Android.
* `bravecross-game/` — game Godot. **Thư mục làm việc chính.**

> **GHI CHÚ 11/10 — câu "Hai repo" LỖI THỜI.** Workspace `D:\PROJECT\ProjectOut\game` nay gom
> **sáu** thư mục anh em (xem `../CLAUDE.md`): thêm **`bravecross-ax/`** — client dựng lại trên
> **Axmol + LuaJIT**, và nay là **repo chính** của dự án (đường Lua chạy mã gốc ra tới HUD); và
> **`bravecross-server/`** — máy chủ riêng Node + TypeScript + Postgres; cùng `decompiler/`,
> `bravecross-source/`, `error-test/`. Nhánh Godot trong thư mục này **ngủ đông từ 18/09/2026**
> (commit cuối) — nên câu "thư mục làm việc chính" là của lúc viết, không còn đúng.

## Cửa vào

`godot --path .` chạy `run/main_scene = res://ui/vao_game.tscn` — màn cửa vào
dựng **chuỗi Login → Main của lớp Lua** trong một màn thật (có autoload `Game`,
có theme, chạm được). Ba điều phải nhớ:

* Lần đầu chờ **~5 giây** (`_NAP` 1,3 s + chuỗi 4 chặng 3,5 s) và trong lúc ấy
  màn hình chỉ có "Đang vào game…". Không phải treo. Ba lần chạy máy rảnh:
  `nap` **1312/1482/1293 ms**, chuỗi **3630/3957/3499 ms**. **Con số "~15 giây"
  ghi trước đây là SAI — nó đo lúc máy ảo Android (`swiftshader_indirect`)
  đang chạy nền**; cùng lúc ấy `nap` — đường **không vẽ gì cả** — cũng phình
  lên 1738–4509 ms, và chính chỗ ấy tố cáo thủ phạm là cái máy chứ không phải
  chuỗi khởi động. Chạy nền máy ảo thì chuỗi lên 7–15 giây.
* Runtime Lua sống trong autoload `Game` (`Game.lua`, `Game.lop_lua`) nên nó
  **không** bị `change_scene_to_file` hạ xuống: `Game.MENU` chính là màn cửa
  vào, nên bấm Back từ battle/equip/formation/roster/tasks về Main **tức thì**
  (đo **5 ms** so với ~5.000 ms nạp lại).
* `Game.lop_lua` là `CanvasLayer` với `layer = -1` — sân khấu Lua **luôn ở dưới**
  mọi màn, và nó **tự ẩn** khi rời màn cửa vào (`ui/vao_game.gd:_exit_tree`).
  Thiếu phép ẩn ấy thì lớp Lua vẫn hit-test cú chạm và bấm xuyên qua màn trên.

`ui/menu.tscn` (màn chữ scaffold) **vẫn còn trên đĩa** nhưng không còn là cửa
vào — nó là chỗ **duy nhất** trỏ tới roster/formation/equip/tasks, nên vào bằng
`godot --path . ui/menu.tscn`.

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
python tools/check.py          # 57 dòng kết quả (52 bộ trong SUITES + 5 bộ Python), phải xanh hết
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

> **GHI CHÚ 11/10 — câu này THẮNG khi lệch với file mẫu.** `.claude/docs/coding-standards.md:8`
> bắt dùng **Conventional Commits** (`feat:` / `fix:` / …) — **ngược hẳn** câu trên. Xử theo
> **lịch sử git của chính repo**: mọi commit đều là câu tiếng Việt **không tiền tố**. Nên
> `coding-standards.md` là **file mẫu chưa bản địa hoá**, không phải quy ước của dự án; nó đã
> được ghi chú lại cho khớp (cùng ngày).

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
`godot --path . -- --shot=main.png` (màn Main thật nay LÀ cửa vào mặc
định — xem mục "Cửa vào" ở đầu; `--at` đếm từ lúc **vào được** Main nên mặc
định 6 giây đã đủ, muốn bắt hoạt ảnh xa hơn thì thêm `--at=20`); đường cũ `godot
--path . --script
tools/vao_main.gd -- --chup=main.png` vẫn chạy; mở cửa sổ
để bấm tay: `... -- --xem` (bấm tới trận được — khoá bằng `tools/bam_that.gd`;
lớp phủ nào nuốt cú bấm thì bộ đó chỉ ra node và vết gọi),
(7) **`sngFixInfoReflash` — XONG.** Số nằm ngay trong `.xgg` ở `+0x38`..`+0x54`,
`+0x38` là kiểu **y** TRƯỚC rồi mới tới kiểu x; kiểu 1/3 dùng hộp đã co giãn còn
kiểu 2 dùng hộp chưa co giãn. Nó nay là **phương thức thật** trong
`lua/cocos.lua` (bản gốc: phương thức C++ `N7cocos2d16sngCCNodeFixInfoE`, **không
file Lua nào định nghĩa** — thiếu nó thì **không một lỗi nào**, nên phải **đếm**
mới biết nó chạy: `LuaRuntime.fix_reflash`). Do **chính bốn đường gọi của bản
gốc** kéo chạy (đầy đủ ở `ROADMAP.md` mục 9) chứ **không** reflash cả cây lúc
dựng bố cục — cách cũ ấy đẩy gốc hộp thoại `CUINormalDlg` từ `110,30` thành
`60,35`. Đo trên Login → `Main`: **gọi 5 lần, đổi chỗ 3 node** (`UIRootLayer` về
`(96,64)` vì `fix = [2,2,...]`, `lMainToolbarTop` `x` `0 → 30`). Công thức trùng
số đã lưu ở **99,0%** trong 48.089 trục — con số "~47%" ghi trước kia là **sai**,
do đọc nhầm thứ tự hai byte kiểu; kiểm lại bằng `brave-cross/work/fix_info.py
--lech`. **Chính sách co giãn đã xong cả năm việc**: `stretch/aspect = "expand"`,
đúng bằng công thức hai nhánh của chính bản gốc
(`CSceneManager:SetWHScaleToWinSize`, `sc/user/Public/CSceneManager.lua:305-326`:
giữ chiều dài của 960×640 rồi nở chiều còn lại — 16:9 ra **1137,8×640**, 4:3 ra
**960×720**). Không phải "thấy giống": `tools/verify_co_gian.gd` chép công thức ấy
từ `sc/` rồi so với cách Godot tính `expand` trên **301 tỉ lệ 1,0→2,5, lệch
0,000000000 điểm**. `keep` mà trước đây để mặc định thì không chỉ có viền đen: nó
khiến `SetWHScaleToWinSize` dùng tỉ lệ **cửa sổ** (1,7778, đo được) trong khi khung
vẽ ra tỉ lệ 1,5, tức đặt cỡ lớp Main thành 1137,78 trong khung rộng 960. Không đổi
gì ở 960×640 và ở `--headless`. **Một chỗ chưa khớp, ghi rõ:** `GetLiuHaiWidth()`
trừ tai thỏ chỉ trên **iOS** và chỉ khi tỉ lệ **> 2,0** (`:287-299`; Android và
`fRate <= 2.0` đều trả `0`), nên 1137,8×640 đo trên máy ảo là đường không khuyết —
`expand` tái tạo đúng đường ấy, còn iOS tỉ lệ > 2,0 thì bản gốc thu hẹp mà port
chưa làm;
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
các lớp C++ `CDFSpriteFight*Wake` — và **HÌNH thì nay cũng đã vẽ** (24 trường
chuỗi `s*` của `WakeRef`, xem "(2) hiệu ứng thức tỉnh" bên dưới). Chỗ đứng theo số thật (1 ô = 100 px, `PosX`
tính theo ô, làn theo `Location` — xem mục "Chỗ đứng quân" bên dưới), camera
bám quân với hằng số của `map/global_config.xml` và nền trôi theo hệ số
parallax `+0x30` của bản ghi node (cách bám là ĐẶT). Minimap: XONG.
Sát thương trận có hình dùng CÔNG THỨC THẬT của bản gốc (`battle/harm.gd`:
cấu trúc hàm C++ `0x380c94` + hằng số `<formula>` của `global_config.xml`;
bật bằng `rules['harm_real']`, chỉ trận có hình). Mô hình đối chiếu ba bên
(`combat.gd` mặc định / `sim` / `server`) GIỮ NGUYÊN. Ánh xạ trường sang bên
đánh/chịu ĐÃ ĐO, không còn ĐẶT — xem mục riêng bên dưới. Bộ đo và khoá:
`tools/do_chien_dich.gd` (`--kiem` 32/0, `--kichban` 18/0).
**Cập nhật 2026-09-21 — bốn lời phàn nàn của người dùng về trận trong ải.** Ba
điều đã vá và đã kiểm: (a) **sàn đấu hẹp** — `_trai`/`_phai` lấy theo Control
ngoài cùng (bề ngang **khung nhìn** 1152 px) trong khi sàn thật là bốn dải
`gb1_0..3` trải **4096 px = 40,96 ô**, tức con số cũ hẹp hơn sàn thật **3,56
lần**; (b) **bộ parallax đọc `get_meta(t, null)`** — Godot 4.7.2 báo lỗi **y hệt**
`get_meta(t)` khi giá trị mặc định là `null`, 5/34 node sinh một dòng lỗi mỗi lần
vào trận; (c) **đường trận nay gọi đường gắn đồ** (`dua_dong_minh` → `_gan_do` →
`rig.dat_do`) và **báo số gắn được ra nhật ký** (`do N/M ok` / `truot: ...`) —
đo được `do 0/1, truot: equip_8_6`, và cú trượt ấy **đúng dữ liệu**. Bảng hiệu
ứng trúng đòn **8 khoá `<kit>_0_0`** nay được đọc và **đã đếm**: 107 đòn → **77
hiệu ứng vẽ được, 30 im**; cả 30 im đều vì armature không có mục trong
`trung_don["danh"]` (dữ liệu gốc thiếu), **0** vì thiếu art.
**Hai chỗ còn treo, đã đo — nay CẢ HAI ĐÃ XONG (2026-09-21):** **số sát thương nổi** —
`work/nhan_ref.py` → `data_ref/nhan_ref.json` → `ui/nhan_ref.gd` (`NhanRef`) →
`battle/nhan_sat_thuong.gd` (`NhanSatThuong`) → nối vào
`san_tran_ve.gd:_phat_trung_don`. Sáu loại, hệ số nổi và trần số nhãn là **số
thật** của `global_config.xml` khối `<label>` (Foe 0,825/30; Troop 1,000/50;
Critical 1,000/40; Increase 0,710/100; Bonus 0,700/30; Shield 0,700/50); **bảng
ghép loại → phông là ĐẶT** (xref chết — xem `ROADMAP.md` §5, `ImpactBlue` bỏ
trống). Phông xuất bằng `work/fontart.py` ra `assets_ref/fonts/`: **11 tệp `.fnt`**
(**không phải 7** như ghi trước) nhưng **chỉ 10 trang PNG**, vì
`RedBackgroundWriteBorder.fnt` là bản sao y nguyên của `ReduceBloodFont.fnt`
(md5 `cee13dd7c268`). **Đo trên trận THẬT** (`do_chien_dich --kiem`): 107 đòn →
**107 nhãn vẽ được, 0 bị từ chối**, `theo_loai` Foe 56 / Troop 43 / Critical 8.
Khoá bằng `tools/verify_nhan.gd` (87 đạt / 0 hỏng). **Câu SAI cần bỏ:** "thiếu
phông nên chữ trên màn Main sai màu" — 38/38 nhãn của `UI_Main_960_640` trỏ khoá
`#FONT_TTF`, mà phông ở đây chỉ có chữ số.
(2) **hiệu ứng thức tỉnh** — **nay ĐÃ XONG 2026-09-21.** Art vốn **có sẵn**
trong kho (**43/53** tên trong các trường `s*` của `wake_ref.json` là **biến thể
đúng tên của rig ĐÃ xuất**, **172/172** biến thể chứa chuỗi `Wake` đều vẽ được);
việc còn thiếu chỉ là **đọc 24 trường chuỗi `s*` ấy**. Nay đã đọc, và **24
trường tách làm HAI nhóm theo GIÁ TRỊ** (chỗ nối thật nằm trong ~80 lớp C++
`CDFSpriteFight*Wake`, không đọc được — nên đây là ĐẶT, nhưng **cả hai đầu mút
đều đo**): **14 trường SINH HIÊN** (giá trị là một armature RIÊNG phải vẽ: 37
cặp → 23 tên, 22 tra ra thư mục, 18 dựng được rig, 16 chạy `PluginPlay`) và
**10 trường TỰ THÂN** (giá trị là biến thể của **chính** rig người niệm: 74 cặp
→ 40 tên, 35 tên chứa `Weapon`, **0** có `PluginPlay` — sinh ra là vẽ **một bản
sao thứ hai của tướng**). Một ngoại lệ **có tên** và được assert:
`SiMaYi_WakeEffect` nằm trong `sWeaponWake` nhưng đúng là hiệu ứng (13 tầng,
động tác `Wake`/`WakeLoop`/`WakeEnd`) → **không** sinh.
**Hai lỗi thật lộ ra khi nối, cả hai đều im lặng:** (a) `_richest_variant()`
chọn nhóm nhiều động tác nhất, mà với tên là **chính thư mục** (`CaiWenJiCircle`)
nó chọn `Born/Death/Standby` — **không `PluginPlay`**, nên vòng hiệu ứng **đứng
im**; nay có `SngRig.bien_the_hieu_ung(dir)` + **một** đường tra dùng chung.
(b) **Đường thức tỉnh bằng NÚT — đường người chơi dùng — chưa bao giờ sinh hiệu
ứng**: `_mot_buoc` làm `_play_lai("Wake")` mà không gọi hiệu ứng. Đó đúng là cái
người dùng báo ("hoạt hóa vẫn không đúng").
**Một lỗ hổng DỮ LIỆU, nay có TÊN:** trên ải `L_N_01_01` nhân vật chính mang
`Player000M03W`, mà VN 1.26 **không có khối `fight_<X>Wake` nào** cho tên ấy
(đối chiếu cả bốn `*config*.xml`) → `ve 0, im 1` với lý do
`khong-co-bang:Player000M03W`. Luật: mọi hiệu ứng không vẽ được phải **đếm kèm
lý do** (`dem_thuc_tinh` trả `{ve, im, im_vi_sao}`), không bao giờ im.
Đo: `tools/verify_thuc_tinh.gd` **33/0**; `--kiem` **32/0**; `--kichban`
**18/0**. Chi tiết + số đo đầy đủ + **chỗ còn treo** (cổng `_xong` nuốt hiệu ứng
biến thân của **cảnh kết** — trận kết ở giây 22, lệnh `Wake` của kịch bản tới ở
30,7; **chưa đo** bản gốc có vẽ hay không nên **không** sửa): `ROADMAP.md` §5,
mục "Hiệu ứng thức tỉnh — XONG 2026-09-21".

(9) **thanh / vòng tiến độ** (`CCProgressTimer`) — **xong**, xem mục "Thanh
tiến độ" bên dưới. Trước đó **cả 325 node** bị coi là sprite và **vẽ đầy đặc ở
mọi phần trăm**: thanh máu HUD luôn đầy, thanh nạp game không bao giờ chạy.
Vẽ được rồi vẫn chưa chạy: **hai action** đẩy phần trăm (`S_CCProgressTo` 49
chỗ gọi, `S_CCProgressFromTo` 14) là **bóng** cho tới lượt này — xem mục
"Thanh tiến độ", đoạn cuối.

(10) **bốn nhóm API còn lại — xong**: đổi ô hiển của xương
(`_lua_changeTextureDisplay` / `_lua_changeArmtureDisplay` — hai hàm, `idx` là
**THAY** chứ không phải THÊM), cánh (`_Lua_changeWingAnimation` — màn gắn cánh đi
qua `setGear`, hàm ấy **đã làm**, nên nó trả `true` ngay khi có màn nào gắn; xem
`ROADMAP.md` mục "Bốn nhóm API của lớp giả lập"), tiếng chạm
(`setSoundStrArr`), vùng chạm
(`setIsOpenDetection` + `pushDetectionAreaInPatentSpace` — bốn số là **hai góc
đối nhau trong hệ node CHA**). Khoá bằng `tools/verify_o_hien.gd` (93 đạt /
0 hỏng). **Ba bẫy im lặng** đo được cùng lượt, đừng quên: bảng Lua đưa vào
`set_meta` **bị bỏ đi không một lời**; gọi phương thức Godot trên node đã **bọc**
(`c.wrap`) thì **im lặng không làm gì** (phải `c.raw`); biến toàn cục của Lua đọc
ngược ra qua cầu là **bảng "bóng"**, không phải số. Chữ ký hàm chạm: `goi_pha`
gọi `pcall(f, obj, sender, ...)` — **node là tham số THỨ HAI**. Chi tiết:
`ROADMAP.md`, mục "Bốn nhóm API của lớp giả lập".

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
Bước "chờ người chơi **đặt quân**" (`EnableGoNextWhenPutSoldiers`,
`drama_L_N_01_01.lua:208`) **không phải chờ đồng hồ**: bản gốc cho chờ vô hạn cho
tới khi người chơi bấm nút binh chủng (`tArmyIcons[1]`). Nay `san_tran.lua:dua_linh`
báo `dat_linh_xong` khi **thật sự đưa được quân**, và `kich_ban.lua` ghi vết kèm
**giờ trận** cho cả hai đường thoát (`dat linh xong @…` / `qua gio dat_linh @…`) —
đo được trong `--kichban`: **`dua Troop_1 @8,2 > dat linh xong @8,2`**, tức đường
SỰ KIỆN nay được dùng thật; phép kiểm `kich ban tran (Lua)` khoá điều đáng khoá là
**không còn đường thoát nào im lặng** (11/0).
Hai lỗi thật đã lộ ra khi truy cho tới cùng (2026-09-18), cả hai đã vá:
1. **`dua_linh` gác oan theo cờ TẠM DỨNG.** `T.dung` là cờ `_Lua_PauseGame` của
   bản gốc (xem `nhan('dung')` trong `san_tran.lua`), mà đoạn phim mở đầu ải
   hướng dẫn **tạm dừng trận rồi mới đòi người chơi đặt quân**
   (`drama_L_N_01_01.lua:96` dừng, `:208` đòi, `:257` chạy lại). Gác theo cờ ấy
   làm **chạm vào tượng linh trong cửa sổ chỉ dẫn không ra quân** — đúng cái mà
   kịch bản đang chờ. Đo: trong cửa sổ, gọi thẳng `dispatch` trả `false` suốt
   (`ld = 6`, `T.dang = true`, `T.tran ~= nil`, `T.dung = true`) trong khi
   `tran_nut:dua_linh('Troop_1')` trả **4 ngay từ khung 0**. Đó là lời giải cho
   câu "vì sao bộ đo không bấm kịp" mà bản ghi trước để là *chưa đo*.
2. **Đồng hồ trận tắt thì kịch bản chết theo.** `dung_tran` gọi `T.hen:stop()`,
   mà chính `hen:buoc` là chỗ **bước kịch bản** (`kb:buoc`) — nên thắng sớm là
   kịch bản đứng giữa đường (đo: nhật ký kết ở `ChangeFight LvBuEvil Fight`,
   thiếu hẳn `MoveThenDo`/`SetArmyWaiting`, 4 phép kiểm đỏ). Nay `dung_tran` chỉ
   đặt `T.ket`; `hen:buoc` thôi bước trận nhưng vẫn bước kịch bản cho tới khi
   kịch bản diễn xong rồi mới tắt đồng hồ.
Bộ đo cũng đã đổi cho giống người thật (`do_chien_dich.gd`): **lần chạm đầu chờ
đúng lúc kịch bản chỉ** (`UnlockArmyByPlugin XSJieSuoBingZhong` cho nút hiện,
`:193`, rồi `EnableGoNextWhenPutSoldiers(true)`), và **không chạm khi kịch bản
đang cấm nút** (`SeDispatchButtonDisable` — bản thân cổng game chưa gác cờ này,
xem `ROADMAP.md` mục 8b). Trước đó bộ đo bấm từ khung 15 (0,5 giây, lúc nút còn
ẩn): không ai chơi vậy, và chính cái bấm sớm ấy làm ta thắng trước khi kịch bản
diễn hết.
Còn ghi-lại: lớp phủ `g_CGuideLogical`.
(`--kiem`; chụp giữa trận: `--chup=tran.png`, thêm `--cam=2500` để thấy nền
trôi; chơi thử một trận: `--xem`; hai chế độ sau chạy KHÔNG `--headless`).

**Hai lỗi làm màn trận không chơi được, đã vá 2026-09-18** — cả hai đều **im
lặng**, và cả hai chỉ lộ ra khi mở một trận THẬT (không bộ kiểm nào bắt được;
chi tiết + số đo ở `ROADMAP.md` §5). (a) `g_BlackEffectLayer` của bố cục HUD gốc
là tấm đen **đục** 2000×1000 phủ kín sàn: dựng nguyên trạng thái trong file thì
khung hình ra **đúng một màu** `(0,0,0)`. Bản gốc tắt nó bằng cờ
`bShowBattleBlackEffectLayer` (ải thường đặt `false`), mà cờ ấy **chỉ được gán,
không file Lua nào đọc** — engine C++ tìm node theo **tên**. Đường chiến dịch đã
tắt sẵn ở phía Lua (`san_tran.lua:481`); `battle.tscn` là màn trận đứng riêng
nên không được hưởng, nay tắt trong `_build_hud()`. (b) `SpriteName` trong bảng
quân chủng là tên **loại quân**, không phải tên armature (`Archer(new)`,
`Stakes`, `witch doctor`) — **62/80** tên không có armature nào, kể cả trong kho
atlas của bản gốc, nên mỗi đơn vị sinh một dòng `SngRig: khong thay ...`. Đơn vị
thiếu art **vẫn đánh**, chỉ vô hình (`battle.gd:co_art()` — **chỉ nhận đúng thư
mục trùng tên**; luật tiền tố của kho "cứu" được 32/62 tên nhưng 0/80 tên là biến
thể thật sự, nên áp luật ấy là gán `Archer(new)` vào hình `Archer` cũ). Bộ kiểm
mới `tools/verify_man_tran.tscn` khoá cả hai, và **kiểm chứng ngược cả ba** (cho
cờ đen về `true`, cho `co_art` luôn trả `true`, và đổi `co_art` sang luật tiền tố)
đều ra đỏ.

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

> **GHI CHÚ 11/10 — "máy chủ thật" nay ĐÃ CÓ.** Câu trên vẫn đúng cho **lớp offline trong repo
> này**; nhưng workspace đã có repo **`bravecross-server`** (Node + TypeScript + Postgres, JSON
> qua WebSocket) và ở đó **nhóm GUILD đã được port** (Mốc 4 `bang_hoi` · Mốc 23 `bang_chuong`).
> Nên đây không còn là chuyện "thuộc về tương lai" nữa.

Tốc độ di chuyển: **đừng dùng `MovingSpeed`** của bảng chỉ số trận. Nó không
hề có trong `libgame.so` — quét bảng tên chỉ số của engine (quanh `0x7b42f0`)
thì có `AttackInterval`, `InjuryRates`, `MaxAttackDistance`, `NpcSize`,
`ClosePressing`, `Jump`… mà không có nó; client cũng chỉ dùng nó làm chỉ số
hiển thị (`PropertyType.MovingSpeed = 21`). Tốc độ thật: mỗi sprite có
`<sMove>` trỏ tới một khối `<move>` trong `map/*_config.xml`, khối đó ghi
`<ptVector>` (đi) và `<ptRunVector>` (chạy), đơn vị **ô**, 1 ô = 100 px
("单位:格 100pix"). Bê ra bằng `work/move_speed.py` → `data_ref/move_ref.json`,
tra bằng `MoveRef.di()` / `MoveRef.chay()`. Công tắc đi/chạy của engine: một
byte cờ ở `+0x295` của lớp move — **bật** khi lệch hoành độ tới mục tiêu
(`self+0x17c`) `≥ 4 × W` (`0x413c4c`, chỉ trục X), chỗ dùng trao `&ptRunVector`
vào slot ảo `+0x2E8` rồi **xoá cờ** (`0x415b18`); `W` **đã chốt**
(2026-09-18) = **bề ngang ô bản đồ tmx = 100 px** → **ngưỡng 400 px = 4 ô**.
Chốt bằng RTTI chứ không bằng suy đoán: `0x35e73a` = `add.w r0,r0,#0x180; bx
lr` là **stub duy nhất** kiểu `this+0x180` trong cả file, và quét
`.data.rel.ro` thì **đúng hai** vtable có nó ở ô `+0x270` — `CDFTMXTiledMap`
(`0x895ac8`) và `cocos2d::CCTMXTiledMap` (`0x921780`) — nên vật ở
`[sàn trận + 0x1b8]` chắc chắn là bản đồ. **ĐÃ NỐI**: `battle/unit.gd`
(`NGUONG_CHAY`, `nen_chay()`, `speed_chay`, động tác `Run`). CHƯA đo: nhánh
chạy đẩy một bước **cứng 3,8 ô** rồi để armature chạy hết quãng ấy — bản dựng
đi liên tục nên dùng thẳng `<ptRunVector>`. Phép đo đầy đủ + ba bẫy quét:
`ROADMAP.md` §5 "Tốc độ quân".

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

Chỗ đứng quân: LÀN là số thật, và **đơn vị của hai hằng làn nay đã ĐO** (trước
là ĐẶT). `Location` (1..3) của bản ghi sprite quyết định làn (Defender 1, Archer
3; 0 = không có làn riêng). Khoảng cách lấy từ `map/global_config.xml`:
`fLaneWidth = 0.4` ô = 40 px, `fLaneOffset = 0.1` ô = 10 px, khoảng cách hai
quân cùng làn `fArmySpace = 1.1` ô = 110 px. Bốn đường độc lập cho đơn vị ô:
chính file cấu hình ghi chú `<!-- 道宽 格 -->` ngay trên hai hằng; engine nhân
với cỡ ô px ở `0x35f43e` (`vldr` `+0x14`/`+0x18` rồi `vmul.f32` với slot
`+0x270` = `this+0x180`, cặp cỡ ô); cỡ ô = 100 px (engine viết cứng `100*(4-idx)`,
`InWhichCell` chặn theo "cỡ ô × số ô", và `map_1.tmx` khai `tilewidth=100`); và
công thức xếp làn `0x35f0a4` → làn 1/2/3 lệch 10/50/90 px, gọn trong 90 < 100 px
một ô. Số làn cũng là số đo: `Location` của 91 mục trong `KDBGameArmyConfig.xgg`
chỉ nhận 0..3. Nay `fArmySpace` có bản anh em `fArmySpaceInArena` (1.2) cho đấu
trường, engine có hai hàm đọc riêng (`0x38193c` / `0x388240`). Đường đo +
`tran_ref.json` + `tools/verify_lan.gd`; hàm `san_tran_ve.gd:lan_lech_y()` là chỗ
duy nhất tính làn ra toạ độ. **Chỗ đặt toán lính đưa ra — ĐÃ ĐO (2026-09-18) và
vẫn là ĐẶT (ô 0).** Đã tưởng chốt được: `dispatch()` của engine
**không tính toạ độ nào** (`.so` **bản vn**: `0x45eda4` → `0x466220` chỉ đánh dấu
quân `+0x5a4 = 0x44` rồi nối vào danh sách của sàn `+0x39c`), nên quân đưa ra đứng
đúng chỗ của toán, và chỗ ấy là `Sprite.Troop.PosX` (`CUIGame:FitBattleArmyPos` đặt
3,83 ô, `FightLogic:GetSelfFightDataBody` mặc định 7). **Đo trong trận thật**
(`L_N_01_01`, `do_chien_dich --kiem`): `PosX = 7` ô = **700 px**. Đổi
`dua_linh` sang dùng mốc ấy (2026-09-17) thì `do_chien_dich --kichban` **tụt từ
9 đạt / 0 hỏng xuống 6/3**; đặt từ **mép** sàn cũng ra 6/3. **Nguyên nhân của cú
tụt ấy hoá ra là hai lỗi THẬT của bản dựng, đã vá cùng lượt sau** — `dua_linh`
gác oan theo cờ TẠM DỨNG (`T.dung` = `_Lua_PauseGame`) và `dung_tran` tắt đồng hồ
đang bước kịch bản (`T.hen:stop()`; xem mục "chờ người chơi đặt quân" ở trên).
**Nên đã ĐO LẠI:** đặt ngay mốc nay ra **11/0 y hệt** lượt đặt ô 0 — cùng nhật ký
kịch bản, cùng **1379 khung**; khác biệt duy nhất là trận xong sớm hơn theo **giờ
trận** (`song 0 giay 18` so với `giay 57`). Vì hai chỗ đặt **không phân biệt được
bằng bộ đo** và `dispatch()` không tính toạ độ (nên cả hai đều là SUY RA), ta
**giữ nguyên ô 0** — đổi là đổi hành vi mà không có bằng chứng nào đổi theo. Phần
**đo được** vẫn giữ: một chỗ định nghĩa duy nhất `tran_goc.moc_toan(sprite)` cho
`doc_quan` (hành vi y hệt mã cũ — ải 1 vẫn 9/0), khoá bằng
`tools/verify_dat_linh.gd` (17 đạt / 0 hỏng) và một phép kiểm **hai đường đọc độc
lập** trong `do_chien_dich --kiem` (Lua `cjson` đọc lại chuỗi JSON so với số của
màn trận, `dat 27, hong 0`). Câu cũ "phải dựng lại trên máy ảo bằng cờ
`bDirectBattle`" **đã đo và SAI**: đường ấy tới `bDirectBattle = true` rồi SIGSEGV
trong `RepaleceScene` (`work/emu_dom.py`). **Lượt này bác bỏ thêm một giả thuyết bằng
phép đo:** `SeDispatchButtonDisable` / `SetWakeButtonDisable` **không phải** lệnh
ghi nhật ký — chúng ghi **cờ bật nút** của lớp drama (vn `0x468b54` / `0x468b78`:
`eor r0,r0,#1; strb.w r0,[drama+0x390]` / `+0x391` tại `0x468b6a` / `0x468b8e`;
đọc lại ở vn `0x45d554` / `0x462308`, trả 0 trừ khi `[drama+0x37c] == 1`; bản apk
là `0x46af20` / `0x46af44` / `0x45f8b4` / `0x4646d4`). Bản gốc **gác ở C++**
(`CUIGame:TouchArrmy` gọi thẳng `dispatch()`); nay `lua/kich_ban.lua` giữ cờ thật
và `lua/san_tran.lua` **đếm** số lần bấm trong lúc cấm — đo được **0 lần** (lệnh
cấm nằm gần cuối kịch bản, sau khi quân đã ra hết), nên lời giải thích cũ "bộ đo
bấm nút kể cả trong cửa sổ bị cấm" **sai**. **Còn CHƯA rõ, ghi rõ:** người đầu
tiên đứng ngay mốc hay lệch nửa toán (`0x41b538` có `vsub.f32` = `X ∓ fArmyLength ×
0.5 × cỡ ô` = 200 px, **dấu** do `0x414912` quyết định — nó lật bit dấu khi cờ
`[obj+0x308]` khác 1; bản dựng cho đứng ngay mốc), và nhịp cách giữa các **toán**
đưa ra (bản dựng lấy `fArmySpace` = 110 px). Cùng lượt, hai sự thật mới của `.so`
(đều bản vn): `0x382670` = `fArmySpace × fArmyLength × cỡ ô px` = 440 px (ví dụ thứ
ba của lối "hằng số tính bằng ô × cỡ ô"); và tên khoá JSON (`PosX` ở `0x7bc0b7`,
`Soldiers`, `NpcID`…) **không truy được bằng xref** — không một word 4 byte nào
trong cả file trỏ vào `0x7bc000–0x7bd000`, nên đường engine → parse JSON không lần
tĩnh được. Thứ tự xếp khi `Location = 0` vẫn là của ta.

**Địa chỉ `.so` phải nói rõ BẢN NÀO.** Trong `brave-cross/work/` có **hai** bản
`libgame.so` khác nhau về bố cục mã: `apk/…` (10.231.498 byte, 25-10-2017) và
`vn/apk/…` (10.213.832 byte, 28-12-2017). **Không có đoạn byte nào giống nhau
giữa hai bản** (đo), nên địa chỉ **không dùng chung được**: cùng chuỗi
`DispatchButtonDisable` nằm ở `0x7c57f8` (apk) và `0x7c1bb6` (vn). **Mọi địa chỉ
trong tài liệu này là của bản `vn`** — bản tham chiếu, vì `sc/` và `data_ref` của
bản dựng lấy từ `work/vn/decrypted/assets` — trừ chỗ nào ghi rõ `(apk)`. Đã mắc
một lần: đọc bản apk rồi tưởng các địa chỉ cũ trong tài liệu sai và định xoá đi;
thực ra chúng **đúng ở không gian vn**. Trước khi bác bỏ một địa chỉ, phải biết nó
thuộc bản nào.

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
cho ải 1 thắng.

**Thẩm quyền nay là tham số 3 (`form`), không phải tên động tác.** Đo cả 17
chỗ gọi trong `sc/plot/drama_*.lua`: form 1 ⟺ `Fight`/`Fight3`/`Fight20` (5
chỗ, đổi tư thế), form 2 ⟺ `Wake`×7 / `Super4`×2 / `Super`×1 (10 chỗ, biến
thân / tuyệt chiêu), form 4 ⟺ `Talent` (1 chỗ, kích thiên phú) — **17/17**. Ý
nghĩa đọc từ chính chú thích bản gốc: `--吕布变身` đi với form 2 + `Wake`,
`--赵云触发龙胆` đi với form 4 + `Talent`. Trên **đúng 17 chỗ ấy hai luật cho ra
cùng kết quả**, nên lượt này **không đổi kết quả trận nào** — đổi là để tên
động tác thôi làm thẩm quyền (3 chỗ `Super`/`Super4` đều là `doi = 1`, mà
nhánh AoE vốn đã bỏ qua lời gọi của bên địch). `form = 0` (không truyền) thì
lùi về phép thử theo tên, tức đường cũ. Khoá bằng 5 phép kiểm trong
`do_chien_dich --kichban` (11 → **16 đạt / 0 hỏng**); bắt buộc phải **đọc lại
vết `tuyet_chieu` thu được** (`san_tran_ve.vet_tuyet_chieu`) chứ không thể đòi
"không thấy lỗi" — `goi_tran` của `lua/kich_ban.lua` bọc lời gọi trong `pcall`
nên lệch số tham số **im lặng, không một dòng lỗi**. Phép kiểm có lực: bỏ lại
tham số thứ 5 thì 4 phép đỏ (`12 đạt / 4 hỏng`).

Còn **chưa** đo được: chỗ nào trong 17 lời gọi ấy là **bên ta** mà tên động tác
không bắt đầu bằng `Wake`/`Talent` — hiện **không có chỗ nào**, nên luật theo
tên chưa từng sai trên dữ liệu đang có. `Evil` không thiếu armature: bốn tên
mà `sc/plot/*.lua` gọi (`LvBuEvil`, `DongZhuoEvil`, `ZhangJiaoEvil`,
`ZhangLiangEvil`) đều có trong `assets_ref`; `ZhaoYunEvil` **chỉ là chân dung**
(`string_gb.lua:16` → `png/half_hero/Head_ZhaoYunEvil.png`, `--龙胆赵云`) và
không lời gọi nào coi nó là armature.

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

**Tấm nền của nhãn — ĐÃ SỬA 2026-09-18.** Tấm vàng trong ảnh gốc **không phải**
chuyện của chữ: nó là ảnh nền `buildingname_16.png` (144×34, viền vàng trên/dưới)
mà `CCLabelTTF` mang **cùng lúc** với `text`. `xgg_layout.gd` có gọi
`UiFrames.set_frame(node, img)` cho cả nhãn, nhưng `ui_frames.gd:set_frame` chỉ
nhận `TienDo` / `UiONhap` / `NinePatchRect` / `TextureRect` và **trả `false` cho
`Label`** — node vẫn có meta `img` mà không có `img_applied`, nên **im lặng** mất
tấm. **202 nhãn** trong 11 bố cục dính; nhiều nhất là `ui_background018.png`
(150) và `buildingname_16.png` (28). Sửa bằng ô theme `normal` của `Label` (nó
vẽ nền ngay dưới chữ của chính nó), **không** bọc thêm node cha — `ui/equip.gd`
quét `c is Label` trên cây nên bọc lại là vô hiệu nó. Cũng **không** đặt ô theo
ảnh như đường chung: ô của nhãn là ô **chữ**, ảnh nền chỉ kéo giãn cho vừa.

Kho có **16** tấm `buildingname_*` chứ không một: `01..15` là **34×133** (bảng
**dọc** treo trên toà nhà), chỉ `16` là **144×34**. Nên phép khớp kích thước của
`imgFrom: size` chọn đúng, không mơ hồ — đo trên Main: **14/14** nhãn gác được
tấm, tất cả đều `buildingname_16.png`. Gác bằng `tools/verify_layout.gd` khối 6b
(đếm theo `img_applied`, vì theo `img` thì không thấy gì).

Câu cũ ở đây — "ô của nhãn và tấm **khớp 1:1 ở mọi trường hợp**" — **SAI**, đã đo
lại trên **cả 296 bố cục** (không phải chỉ Main) và đếm đủ **202** nhãn: **196 gác
được, 6 không**. Con số 1:1 chỉ đúng cho **190/196**: `ui_background018.png` 50×30 ↔
50×30 (**146**), `buildingname_16.png` 144×34 ↔ 144×34 (**26**),
`ui_background112.png` 30×30 ↔ 30×30 (10), `ui_background762.png` 94×94 ↔ 94×94
(4), `ui_button12.png` 127×51 ↔ 127×51 (2), `ui_button27.png` 143×61 (1),
`ui_background240.png` 35×35 (1).

**Năm cái còn lại KÉO THEO TRỤC DÀI**: `ui_background018.png` 50×30 vào ô **79×30**
(2 cái) và vào ô **71×30** (1), `buildingname_16.png` 144×34 vào ô **166×34** (2) —
tức dài ra **21–29 điểm ảnh**, đúng trục mà viền vàng chạy dọc theo nên **không
bóp viền**, nhưng **không phải 1:1**. Vì thế câu "không cần 9-slice" chỉ còn đúng
ở dạng: kéo giãn thẳng **không làm hỏng viền** (viền nằm trên trục dài); muốn biết
bản gốc có kéo 21–29 điểm ấy hay vẽ tấm ở cỡ gốc rồi canh giữa thì **phải đo bản
gốc** — chưa đo. Bản ghi `.xgg` chỉ nói `imgFrom: size`, tức là phép khớp **theo
kích thước**, nên nó không trả lời được câu ấy.

**Sáu cái KHÔNG gác được nay là một lời TỪ CHỐI có tên, không còn là một lỗ
hổng giấu mặt**: cả 6 là `@v6/ui_words357.png` trong `UI_ActivityMode_Finish_960_640`,
gác ra tấm **176×64** còn ô chữ **152×68** — **cạnh ngắn lệch 4 điểm** (64 so với
68), kéo thì bóp viền. Trước khi `key_of` biết hậu tố ngôn ngữ thì 6 nhãn này được
đếm vào "thiếu dữ liệu" (tên `ui_words357` **không có** trong `ui_ref/index.json`
vì bản gốc ship bản `_vi`); nay chúng được `tools/verify_layout.gd` khối 6b **in ra
theo tên**. Còn **1** nhãn `ui_background018.png` đo ra ô **50×29** mà vẫn
`gac=true` — lúc gác ô là 50×30 rồi bị đổi đi 1 điểm sau đó; **chưa truy** nguyên
nhân, ghi lại làm việc còn treo.

**Hai lỗi bố cục của màn Doanh Trại — ĐÃ SỬA 2026-09-18.** Người dùng chụp màn
`CUIBarracksMain` rồi báo "layout chưa đúng". Truy ra **hai** nguyên nhân độc lập,
cả hai đều **im lặng**, và cả hai đều là lỗi chung chứ không riêng màn ấy.

**(A) Khung xương vẽ lệch 640 điểm ảnh.** `CUIBarracksMain.lua:1059` gọi
`parent:addChild(pArmature, 1, index*10)` — **không** `setPosition`. Khung xương là
một `Control` do `_new_node` sinh lúc chạy, mà `_new_node`
(`game/lua_runtime.gd:522`) đặt cho **mọi** node như thế `parent_h = 640.0` — một
con số **BIA**, vì node chưa có cha thật. `Node:addChild` bên `lua/cocos.lua` khi
ấy hỏi `to_cocos(c)` để quy vị trí hiện tại về hệ Cocos, `to_cocos` lấy chiều cao
trong meta `parent_h` → ra cocos y = **640**, rồi `to_godot` với chiều cao cha
**thật** 40 cho ra y = 40 − 640 = **−600**. Đo được: `g=(304.91,−334.00)`.
Sửa: node `Control` **chưa từng được đặt chỗ** (`Node:setPosition` nay ghi meta
`dat_cho`) và **chưa có cha** thì lấy thẳng toạ độ từ meta `cocos`. Sau khi sửa:
`g=(304.91,306.00)` = mép dưới của ô cha (304.91, 266.00) + 40 — tức nhân vật
**đứng trên ô chọn quân**. Đo trên cả cây: **92 dòng** có `g=(304.91,−334.00)` →
**0**; 7 dòng y âm còn lại là **của chính hộp thoại** (`lBarracksMainUI` ở
`g=(160,−64)`, cố ý tràn ra ngoài màn) và **không đổi** trước/sau.

**(B) Ảnh có tiền tố `@` không bao giờ tra ra.** `@` trong tên ảnh của `.xgg`
**không phải ký tự rác** — nó đánh dấu tên **theo NGÔN NGỮ**. Đo trên 296 bố cục /
13.667 node có ảnh: **562 node** (145 tên, 130 bố cục) mang `@`, và **482 node /
128 tên CHỈ ra ảnh khi thêm hậu tố `_vi`**; 72 node ra cả hai đường (và đường `_vi`
mới đúng theo thư mục bố cục ghi); 8 node không ra đường nào (thiếu tài nguyên
thật); 2 node **chỉ** ra khi **không** thêm hậu tố (`@v6/ui_background941/942.png`)
— nên bước lùi về tên gốc là **bắt buộc**, không phải tuỳ tiện. Hậu tố phải chèn
**trước phần mở rộng** (`@v6/ui_words86.png` → `@v6/ui_words86_vi.png`), không
phải nối vào cuối chuỗi — nối sai thì ra `@v6/ui_words86.png_vi`, tra trượt, và
tưởng nhầm là `_vi` không cứu được tên nào (**0/145** thay vì **128/145**). Nguồn
sự thật của giá trị `_vi` là `DEFAULT_LANGUAGE = 'vi'`
(`lua/bootstrap.lua:317`), không phải một lựa chọn của ta — `tools/verify_lua_actions.gd`
đọc giá trị ấy **từ chính file Lua** rồi đối chiếu với `UiFrames.HAU_TO_NGON_NGU`.
Trên màn Doanh Trại: **12 → 0** dòng `[KHONG GAN]`, và 12 dòng ấy đúng là
6×`@v6/ui_words94.png` (`CanUnlock`, `CUIBarracksMain.lua:1074`) + 6×`@v6/ui_words93.png`
(`CanUpgrade`, `:1073`); số ảnh gác được **43 → 55**. Nhìn thấy được: chữ **"Mở
Khóa"** hiện trên các ô quân chưa mở.

Ảnh A/B dựng bằng chính bộ đo, cùng cỡ cửa sổ 960×640 nên từng điểm ảnh so được:
`godot --path . --script tools/do_doanh_trai.gd -- --ra=<dump> --chup=<png> --khung=45`
(chế độ chụp mới của bộ đo; `--khung=` là số khung chờ trước khi chụp). Ảnh:
`../error-test/doanh-trai-truoc.png` / `doanh-trai-sau.png`; cả cây node ra
`279` dòng **y hệt nhau** ở hai lượt — chỉ **ảnh gác** và **vị trí khung xương**
đổi, tức cây không hề khác hình dạng.

**Một lỗi ghi lại, KHÔNG sửa:** meta `cocos` **cũ đi** ngay khi `setPosition` chạy
sau `setAnchorPoint`, mà `UiFrames.set_frame` (`ui/ui_frames.gd:312-316`) **đặt lại
vị trí node từ meta ấy** mỗi lần gác ảnh — nên một sprite bị dời đi rồi mới được
gác ảnh sẽ **nhảy về** toạ độ bố cục. Ghi (x, y) vào meta trong `setPosition` là
sửa được, nhưng đổi hành vi cho **mọi** sprite như thế nên cần A/B riêng.

**Cửa vào của mọi tấm nền — ĐÃ SỬA 2026-09-18, và là chỗ nặng nhất từ trước tới
nay.** Người dùng báo "các nút như ma đồng", "không có background", "nút trên Main
phải hiện rõ nền". Truy ra **ba** lỗi xếp tầng, cả ba đều **im lặng**; sửa xong
số node gác được ảnh đi từ **13.673 → 17.280** trên cả 296 bố cục.

**(A) `work/xgg.py` thiếu hẳn cỡ bản ghi 248.** `IMG_FIELD` có 244/256/260/324 mà
**không có 248** — mà 248 **chính là** `CCScale9Sprite` (đo trên 580 file), tức
toàn bộ tấm nền 9 phần của cả game rơi xuống đường dự phòng `_anh_theo_co` (khớp
ảnh theo kích thước). Đường ấy gần như luôn trượt với 9 phần vì **ô của node là
ảnh gốc bị KÉO**, nên cỡ không bao giờ bằng. Trường thật là **`+0xF0`**: quét mọi
cặp `(off, len)` của bản ghi 248 byte rồi nhóm theo số lần ra `.png` thì `+0xF0`
thắng một mình — **4.126** lần. Cặp `+0xE0` mà tài liệu cũ nhắc chỉ có **19 node**
và **toàn bộ** là `../png/guide/ui_guide_background.png`, một trường khác.

Câu cũ *"cỡ 248 → +0xF0 chỉ 4% khớp, không dùng được, bỏ hẳn"* là **một phép đo
sai**: 4% ấy (đo lại: **16,4%**) chính là phép tự kiểm `_xac_nhan` so **ô của
node** với **cỡ ảnh gốc ở section C** — với 9 phần thì phép ấy **không thể** đúng,
nên tỉ lệ thấp là **điều phải thấy**, không phải bằng chứng chống lại trường.
Đối chiếu: `CCSprite` 244 → **99,9%**, `CCButton` 260 → **99,9%**.

Chứng minh **độc lập, không dùng offset nào**: pool chuỗi ghi các khối liền nhau
nên đoạn ngay sau tên node là tài nguyên của nó. Kiểm trên **cả 4.126** node bản
ghi 248 byte có cả tên lẫn ứng viên ảnh: ứng viên nằm **sau** tên trong pool —
**2.676** liền ngay, **1.450** trong vòng 400 byte, **0 ngoại lệ**; và
**4.126/4.126** đều kết thúc bằng `.png`.

**(B) Luật `guess` của `ui/xgg_layout.gd` loại luôn tên đọc từ bản ghi.** Tên ở
`+0xF0` đọc thẳng ra, nhưng phép kiểm cỡ (không thể đúng, xem (A)) gắn cho nó nhãn
`guess`, mà `guess` **mặc định bị bỏ**. Đo: **3.449** node `CCScale9Sprite` rơi
vào đúng cái bẫy ấy — **161 tên khác nhau, TẤT CẢ đều là ảnh giao diện thật**
(`ui_background002.png` 465, `green/ui_green_05.png` 347, `ui_background041.png`
308, `ui_blood_14.png` 115…). Đây là **chỗ thứ ba cùng một lý do** với
`CCProgressTimer` (314 node) và `CCEditBox` (37 node) vốn đã được miễn — nên miễn
luôn cho `kind == "scale9"`. `guess` của `CCSprite` (**9** node) và `CCButton`
(**1** node) thì **vẫn bị loại**: hai lớp ấy khớp cỡ 99,9%, nên trượt là bất
thường thật.

**(C) `UiFrames.set_frame` kéo ô của node về cỡ ẢNH — sai với 9 phần.** Bật ảnh
cho 3.449 node xong thì `bam that Main -> tran` **tụt từ 5 đạt / 0 hỏng xuống 0
đạt / 5 hỏng**: cú bấm vào nút tấn công `lMainExtraUIAttack` ở `(888, 576)` bị
`btnBackpackUI` **nuốt**, vì tấm 9 phần ấy bị đổi kích thước. `CCScale9Sprite` của
bản gốc **giữ nguyên `contentSize` rồi kéo 9 phần vào đó**, đúng như
`NinePatchRect` của Godot — nên `set_frame` nay **đặt ảnh rồi thôi** với
`NinePatchRect`, cùng lý do đã có sẵn cho `TienDo` và `UiONhap`. 677 node có ô
**đúng bằng** cỡ ảnh thì không đổi gì (kéo vào ô bằng chính nó).

Hệ quả nhìn thấy được: **44 node trên Main** từ chỗ không có ảnh nay có — và
**toàn bộ là nút**: `btnOK`, `okButton`, `btnUse`, `btnGetAllPrize`,
`btnDeployIntoBarracks`, `btnHeroInfoUIUseExp`, `返回按钮`… đều ra
`ui_button01.png` (nền nút gỗ) hoặc `ui_button14/03/09.png`; trong bộ kiểm là
`action + anh (Lua)` **67 đạt / 0 hỏng**. Đúng cái người dùng hỏi: "khi bấm các
nút trên main cần hiển thị rõ các nút background".

Chữ trên Main: **vàng + viền đen** so với **trắng, không viền** — **CHƯA SỬA,
chưa biết nguồn**. Đo được, ở mức phóng 6×: bản gốc `Võ Hội` vàng `(≈255,200,60)`
viền đen, ta trắng xám không viền. Nhưng **không phải mọi nhãn bản gốc đều
vàng**: trên cùng ảnh ấy, tên người chơi `Eromanga-Sensei` và các số tiền
`999/120`, `42646306` là **trắng không viền**. Vậy nó **theo từng nhãn**, không
phải một kiểu chung.

Bốn đường đã **loại**:

* **Không phải phông khác nhau.** Cả 38 nhãn của `UI_Main_960_640` trỏ **cùng
  một** khoá phông `+0x130 = '#FONT_TTF'` (đếm: 38/38). `FONT_TTF` chỉ là tên
  phông mặc định (`GetStringWithKey("FONT_TTF")`, 13 file dùng), không mang màu.
  Nên **không** phải chuyện phông bitmap vàng.
* **Không nằm trong `.xgg`.** So **trực tiếp** một nhãn vàng với một nhãn trắng ở
  hai file khác nhau — `#MainBuilding_Name7` (`UI_Main_960_640`) với `+9999999`
  và `999999` (`UI_Main_ControlPanel_960_640`): chúng khác nhau **đúng hai float
  và một byte**, và đó là **độ lệch bóng/viền**, không phải màu —
  `+0xE4..+0xE7` = `2.0` (vàng) so với `0.0` (trắng), `+0xE8..+0xEB` = `-2.0` so
  với `-3.0`. Quét cả 352 byte của cả hai bản ghi tìm nhóm 4 byte kiểu RGBA có
  alpha 255: **không có nhóm nào**. Byte `+0xE7 = 64` mà tôi tưởng là màu bám
  theo **cỡ ô** (`h=34` ra 64, `h=30` ra 0) — và nó **không** phải cờ "có tấm":
  đo trên 38 nhãn Main, `h=34` có **14 có tấm + 7 không**, nên `+0xE7` không phân
  biệt được. Bảy nhãn `h=34` không tấm là `#MainBuilding_Name9/10/12/14` (bề rộng
  **150/160/170** chứ không 144 — phép khớp kích thước trượt), `#ContestUI_Champion`
  (`w=0`) và hai chuỗi CJK thử `a名字四个字`, `应用宝`. **Chưa đo**: bản gốc có kéo
  giãn tấm vàng cho bốn tên toà nhà rộng 150/160/170 đó không — nếu có thì phải
  dùng 9-slice, và đó là việc còn lại.
* **Không nằm trong `CUIMainBuildingManager.lua`.** Nhãn tên toà nhà là tag
  `5001`; file đó chỉ đọc tag `5000` (`pUnlockText`) và `8384` (`pRedPoint`),
  **không** đụng `5001`.
* **Không nằm trong 13 file gọi `enableOutline` của `sc/`.** Liệt kê hết: toàn
  viền **đen** `(0,0,0,255)` cho phụ đề / tab / cá cảnh / nhãn phụ, hoặc màu lấy
  từ bảng cấu hình của chính màn đó. Không chỗ nào chạm nhãn thành phố màn Main.
  Mặc định của bản gốc vẫn là **trắng** (`lua/cocos.lua:1609`), đúng như các số
  tiền.

Nghi vấn còn lại: một lượt trang trí **của engine** đi qua `CCLabelTTF` sau khi
nạp bố cục — dữ liệu không có, Lua không có, nên chỉ còn engine. Đường đúng để
trả lời là **móc bản gốc lúc chạy** (`work/emu_*.py` đã có sẵn cách móc hàm C++)
và xem `setColor`/`enableOutline` bị gọi trên node nào — **không đoán**.

Cùng ảnh ấy còn hai lệch nữa chưa sửa: bản gốc có **chấm đỏ** báo việc ở góc
phải trên tấm tên (tag `8384`, Lua tạo), ta không có; và nhãn **lệch theo trục
x** khoảng **+25 điểm ảnh** ở 960×640.

Hộp chạm của armature (`_lua_CollisionSize`) — **XONG**, và nó là một CẶP số
(rộng, cao) chứ không phải một số: `W = w·sx·|cos rot1| + h·sy·|sin rot1|`,
`H = h·sy·|cos rot2| + w·sx·|sin rot2|`, với `(sx,sy,rot1,rot2)` là khoá 0 của
xương `Collision`.
`|cos|` vì `rot2 = 180` là **cờ lật**, để nguyên dấu thì bề cao ra ÂM.

`(w,h)` là **`sourceSize` của bản ghi `.plist`** (cặp float 12, 13 của bản ghi
60 byte, ở `+0x34`) — **KHÔNG phải** bản ghi sprite trong `.xml`. Tài liệu này
từng khẳng định `.xml`, kèm lập luận "`Hoplite_res-44` là 3×3 trong `.xml`, 1×1
trong plist, mà bản gốc trả 3 × 54,52" — **lập luận ấy không phân biệt được gì**,
vì `.plist` khai **ba** cặp cỡ chứ không phải một: `f2,f3` là khung ĐÃ CẮT,
`f9,f10` **lặp lại y hệt** `f2,f3` (đo 13.634/13.634 khung), còn `f11,f12` mới là
`sourceSize`; và `sourceSize` của `Hoplite_res-44` **cũng** là 3×3. Ba phép đo
trên máy ảo mới tách được hai nguồn, cả ba đều nói `sourceSize`: `BatFlight`
**145,00999450684 × 120** (`.xml` đòi ra 290,02 × 240), `DragonFlight` **175 × 145**
(`.xml` 350 × 290), `DragonFlight` `Head` **64 × 64** (`.xml` 65 × 64) — ba rig
chưa từng được đo lần nào. Quét cả **590** biến thể: chỉ ba giá trị góc tồn tại
(`0` 577, `180` 12, ba rig góc nhỏ), nên **587/590 khớp máy ảo từng bit**;
3/590 còn lại lệch ≤ 2,2e-4 điểm ảnh và **chưa rõ nguyên nhân**.
Bảng có **590** dòng chứ không phải 592 vì hai biến thể `LvBuZhanShi_A2` /
`LvBuZhanShi_Weapon1` dùng ảnh `LvBuZhanShi_res-44` mà `sourceSize` của ảnh ấy là
`0 × 0` (hai biến thể ấy không đo được trên máy ảo — `getSpriteFromSpriteCatch`
trả `nil` — nên `0 × 0` của chúng là **suy theo cùng một luật**).
Ghi chú đầy đủ + số đo: `ROADMAP.md`, mục "Hộp chạm của armature";
khoá bằng `tools/verify_cham_size.gd` (46 đạt / 0 hỏng).

**Cùng lượt ấy lộ ra một lỗi chọn biến thể đã sửa:** `_richest_variant()` chọn
nhóm nhiều động tác nhất, khi bằng nhau thì lấy nhóm **đầu tiên** — mà biến thể
**mang tên file nằm CUỐI** danh sách nhóm ở **297/304** file, nên cách chọn ấy tuỳ
tiện với **45** rig. Máy ảo nói thẳng bản gốc dựng biến thể nào: `DaQiao` →
**85 × 135** (nhóm `DaQiao`; `DaQiaoReplica` không có `Collision` nên "nhiều động
tác nhất" sẽ ra `(0,0)`), và `CaiWenJiCircle` → **875,12 × 523,8** trong khi nhóm
**đầu** là `_Top` — hai phép đo bác bỏ **cả hai** cách chọn kia. Luật đúng là khớp
**TÊN**, như `getSpriteFromSpriteCatch(<tên>)`; nay là `SngRig._bien_the_cho()`,
vẫn lui về nhóm nhiều động tác nhất khi tên thư mục không phải một biến thể
(`PlayerM.xml` chỉ có `PlayerM03W`…). **12** rig đổi kết quả.

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
vừa mắt. Số đo đầy đủ: `ROADMAP.md` §8 việc 8; khoá bằng
`tools/verify_tien_do.gd` (120 đạt / 0 hỏng).

`setOrange` thì **đã đo xong** và **không phải chỗ còn thiếu**: nó đổi chương
trình shader của sprite trong sang `..._Orange` (`r×0,9; g×2,9; b×0`, nguồn ở
`.rodata 0x7cd0c1`) hoặc trả về bản thường, **chỉ đổi màu chứ không đổi hình**.
Cả 6 chỗ gọi đều hỏi `GetLanguageName()=="en"`, mà bản dựng không bao giờ ra
`"en"` (`IS_OPEN_LANGUAGE = false`), nên nhánh chạy được là `false` — và ba lượt
trên máy ảo cho thấy `setOrange(false)` khác *không gọi gì* **0 / 921.600 điểm
ảnh**. Đã đặt tên phương thức (`lua/tien_do.lua`, hệ số `HE_ORANGE` ở
`ui/tien_do.gd`).

`setIsSwallowInBegan` — cái cuối cùng của đường Login → Main — cũng **đã làm, và
là chỗ DUY NHẤT trong hai cái đổi hành vi thật**. Đo từ file game: nó chỉ có trên
**một** lớp trong 132 bảng (`CCLayerColorRoundRect`, Thumb `0x2b4e98`), thân hàm
là `self[+0x276] = tobool(arg, mặc định 1)`, **ba** hàm dựng của lớp đều ghi `1`
→ **mặc định là NUỐT**, và người đọc byte đó (`0x2b4d30`, cùng lớp) chỉ đánh dấu
byte "đã nuốt" khi cờ khác 0. Cả **8 chỗ gọi** trong mã gốc (6 file) đều đặt
`false` và đều gọi **trần**, nên 8 node đó buộc phải thuộc lớp ấy — kiểm độc lập
được từ `layout_ref`: 6 node theo **tên**, 2 node của `CUIFriendsChatting` theo
**tag** (`rootPanel:getChildByTag(1)` → `getChildByTag(2)`/`(5)`), **8/8** đều
`CCLayerColorRoundRect`; node **cùng lớp, cùng cha, ngay cạnh** (tag 4,
`lFriendsChattingInvalidTouch`) mà mã gốc **không** gọi thì giữ mặc định nuốt —
tức **lớp không quyết định, chính lời gọi `false` mới đổi hành vi**. Ý nghĩa đọc
từ chính mã gốc: bốn 阻隔层 của `CUIChatting` là lớp phủ **rộng hơn** khung bên
trong, hàm `onTouchBegin_` của chúng đo toạ độ điểm chạm với khung trong rồi ẩn
khung đi nếu chạm ra **ngoài** — nuốt thì cú chạm-vào-ra-ngoài đó cũng bấm luôn
vào nút nằm dưới lớp. Bản dựng vì thế chạy hàm rồi **trả `false`** để cú chạm đi
tiếp xuống node dưới (`M.cham` chỉ nhường pha **Begin**, đúng chỗ duy nhất mã gốc
đọc byte ấy). Đường Login → Main vì thế **không còn API nào chưa làm**.

Hai hàm xương của armature — `_lua_getBonePosInNode` / `_lua_getBoneRectInNode`
— là **ngoại lệ của cả danh sách "API chưa làm"**: mọi API thiếu khác đều im
lặng, còn hai hàm này thì chỗ gọi **gác** bằng `if spHero._lua_getBonePosInNode
~= nil then` — mà `__index` của lớp giả lập trả về một hàm cho **mọi** tên, nên
phép gác ấy luôn đúng, rồi hai giá trị trả về là `nil` và `facePosX = headBoneX
+ offsetX` ném **lỗi Lua thật**. Đúng **hai** lượt gọi, một file:
`sc/user/UI/CUIHeroInfoFightSoulUI.lua:3105-3106` (hoạt ảnh thất bại khi nâng cấp
võ hồn). Cặp số là cặp `+0x08` của bản ghi khung với **y đảo dấu** —
`(v2, −v3)` — đo trên năm rig và đọc lại được độc lập từ chính file `.json`; nó
là dữ liệu **từng khung**, đổi node đích là một phép **đổi không gian** thật
(dời node đích `+(140, 43)` theo cocos thì kết quả đổi đúng `−(140, 43)`), và
`_lua_getBoneRectInNode` **chính là** công thức `hop()` của `cham_ref.py` với
`(w, h)` = `sourceSize` của ảnh mà xương ấy vẽ. Cùng lượt ấy lộ ra hai lỗi xuất:
hộp của các sprite `_res-44` (ô 0×0 trong atlas nên `spriteFiles` là `null`) **thiếu
hẳn** — đo được **2.112/32.395** cặp xương→ảnh (6,52%) ở **171/397** rig — nay có
bản đồ `sourceSize` cho mọi tên sprite; và `json.dump` ghi `NaN`
làm Godot **từ chối cả file** JSON của một rig (`XSJiYouHeTiJi`), nay số không
hữu hạn bị thay bằng `0.0` và **đếm lại**. Chỗ từng ghi là **CHƯA KHỚP** — hệ số
**1,02** — nay **đã đo xong**: chủ nhân là **chính đối tượng
`getSpriteFromSpriteCatch` trả về** (`CDFSpriteRole`, tức cây armature), nó mang
sẵn tỉ lệ 1,02; node Cocos **thường** thì tỉ lệ 1. Đo trên máy ảo
(`brave-cross/work/emu_ti_le.py`, 2026-09-18) với bốn armature khác nhau: **điểm**
thì bị **chia** tỉ lệ của **chính node đích** (nên đích là armature ra
`140/1,02 = 137,25499`, đích là node thường ra `−(140, 43)`), còn **hộp** là một
**kích thước** nên bị **nhân** tỉ lệ của **nguồn** rồi chia tỉ lệ của **đích**
(nguồn là armature, đích là node thường → `175 × 1,02 = 178,5`; đích cũng là
armature → hai hệ số triệt tiêu → đúng `175 × 227,5`). Tương quan cũ "hai chiều
ngược nhau nên 1,02 không thể nằm trên node đích" là **đọc lệch phép đo**: con số
`178,5` vốn đo với node đích **thường**. Nay bản dựng mang sẵn tỉ lệ ấy
(`TI_LE_BAT` trong `game/lua_runtime.gd`, đặt ở **hộp** để một lệnh `setScale` của
Lua vẫn thay được nó, đúng như `CCNode::setScale`).
Chi tiết đầy đủ + số đo: `ROADMAP.md`, mục "Hai hàm xương"; khoá bằng
`tools/verify_xuong.gd` (63 đạt / 0 hỏng, **khẳng định** cả bốn phép đo trên).

Ba hàm **điểm gắn** (`_lua_getPlugInPositionInNode` / `_lua_addChildToPlugIn` /
`_lua_clearPlugIn`, 48 chỗ gọi) dính **đúng hệ số ấy** và đã đo riêng
(`brave-cross/work/emu_plug.py`, 2026-09-18): cùng một cặp xương điểm gắn đọc qua
đích là **chính nguồn** ra hiệu `(1, 37)`, đọc qua đích là **node thường** ra
`(1,02002, 37,74)` — **tỉ số đúng 1,02**, và tỉ số ấy *chính là* tỉ lệ của nguồn
(đích là chính nguồn thì hệ số của nó triệt tiêu). Phép đo này **không phụ thuộc
tư thế**, nên nó đứng vững kể cả khi động tác chưa áp. `tools/verify_plug.gd`
trước đây so thẳng với file nên **tụt 8/4** khi bản dựng mang hệ số; nay nó
**khẳng định** hệ số (`TI_LE_BAT` trong chính bộ kiểm ấy) và xanh trở lại.

Hiệu ứng sao của tướng (`_Lua_addStarLevelEffect`) — **XONG**. Khoá cấu hình
`lsStarLevelEffect_<cấp>` của khối `<star>` (`map/global_config.xml`) quyết
định, không phải tên tài nguyên: cấp 2 → `_2Up`, cấp 3..7 → `_<cấp>Up` +
`_<cấp>Down`, **cấp 1 không có gì** (đúng lý do `NumberUtils.Range(..., 1, 7)`
trả 1 thì không thấy hiệu ứng). Bảng dữ liệu: `brave-cross/work/star_ref.py` →
`data_ref/star_ref.json` → `ui/star_ref.gd` (`StarRef`); chỗ chạy:
`LuaRuntime._hieu_ung_sao` + `Node:_Lua_addStarLevelEffect` trong `lua/cocos.lua`.
Bốn chỗ gọi của bản gốc (`ClientPaperDoll.lua:271,288` → 5 màn, `CUIGame.lua:953`
→ sân trận) đều **gác bằng `if ... then`**, mà `__index` của lớp giả lập trả hàm
cho **mọi** tên — nên thiếu API này thì **không một dòng lỗi**, hiệu ứng chỉ đơn
giản là không bao giờ hiện. `tools/verify_sao.gd` (151 đạt / 0 hỏng) khoá bốn
tầng, tầng D đi **chính mã gốc**.

**Bẫy đã mắc, đáng nhớ (một loại im lặng mới).** `_tao_rig` gọi
`SngRig.build(..., true)` — bật bộ lọc xương tên `Layer*` đặt ra cho **nhân vật**.
Nhưng xương của armature **hiệu ứng** đều tên `Layer*`: 100% xương tầng ngoài
cùng của **cả 11** biến thể hiệu ứng sao, nên lọc là ra rig **0 xương** — mà rig
0 xương **vẫn `play()` được** (trả `true`) và vẫn có tên động tác, nên "chạy không
lỗi" không thấy gì; **chỉ phép đếm xương** mới bắt được. Đo rộng: **1319/2935**
biến thể trong `assets_ref` có toàn bộ xương tầng ngoài cùng tên `Layer*` (gần hết
là armature hiệu ứng). `LuaRuntime.rig_rong` đếm mọi rig dựng ra rỗng.

**Đã sửa 2026-09-18** bằng cách bỏ bộ lọc khỏi **đường Lua** (`_tao_rig` gọi
`SngRig.build(..., false)`; tham số `giu_layer` không còn, vì cả đường chỉ có một
luật). Bộ lọc **vẫn còn** cho **màn trận** — ba chỗ gọi `SngRig.build(..., true)`
đều nằm trong `battle/`, và đó là chỗ duy nhất nó từng được đo. Lý do bỏ: `Layer*`
ở đường Lua không phải vết tích Photoshop mà là **chính đối tượng** — toà nhà Võ
Hội (`UIJianZhuWuDaoHui`) chỉ có hai xương, `PlugIn_1` (ảnh 4×4 rỗng, đúng bị luật
marker bỏ) và `LayerName000`, mà `LayerName000` mới là toà nhà (ô hiện của nó là
các rig lồng nhau `_Base_Main*`). Đo trên màn Main: rig ấy **0 → 17** node có ảnh,
**5 đang hiện**, kéo theo cả chợ, chùa, rương và đảo nổi.

Màn trận **không đổi** — nhưng **không phải vì phép đo điểm ảnh**, mà vì ba chỗ gọi
đó truyền `true` tường minh và lượt này không đụng tới chúng. Phép đo điểm ảnh ở
đây **không có lực**: hiệu trước/sau 63.827 điểm (10,3885%) so với 66.068 điểm
(10,7533%) giữa hai lần chạy **cùng cấu hình** — mà nhìn ảnh khác thì thấy nhiễu ấy
là **đơn vị đứng ở chỗ khác nhau**, tức RNG của trận, không phải nhiễu vẽ. Hai con
số đều đang đo "hai trận khác nhau", nên so chúng không nói được gì về một thay đổi
nhỏ ở tầng rig. Muốn đo màn trận thì phải ghim được hạt RNG (in ra ở dòng nhật ký
trên màn, vd `RDYmADaDCy`).

Còn **chưa đo**: rig **nhân vật** hiện trong giao diện (chân dung tướng, paper
doll) nay cũng không lọc, nên lớp `Layer*` của nhân vật — thứ bản gốc chỉ loé vài
khung rồi tắt — có thể hiện thường trực ở đó. Sửa cho đúng thì phải đo lại luật
theo **từng khung**.

Đọc nhầm đã sửa, ghi lại: file `StarLevelEffect.xml` có **23** biến thể, không
phải 11 — **11** của cấu hình (động tác `PluginPlay`) + **12** tên
`StarLevelEffect_mc_*` là **rig lồng nhau** (động tác `Play`); và **cả 11** biến
thể hiệu ứng đều có rig lồng nhau, không phải hai cái như tài liệu cũ nói.

Bấm được: `lua/cocos.lua` (`M.cham`) + `LuaRuntime.touch_at`, kiểm bằng
`tools/verify_cham.gd`. Số màn mở được: xem bảng đầu `ROADMAP.md` (đo bằng
`tools/quet_show.gd`, con số dao động ±3 giữa các lần chạy). Phần lớn màn hỏng
là vì thiếu dữ liệu người chơi, không phải thiếu engine.

<!-- BEGIN StudioForge -->
# StudioForge -- Game Studio Agent Architecture + Asset Production

Indie game development managed through 49 coordinated Claude Code subagents,
with a working AI asset-generation pipeline attached. Each agent owns a specific
domain, enforcing separation of concerns and quality.

Base framework: [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios).
Asset generation: the `asset-gen` skill from [godogen](https://github.com/htdt/godogen).
See `docs/STUDIOFORGE.md` for what was merged and why.

## Technology Stack

- **Engine**: Godot **4.7.2** (GL Compatibility) — đã chốt sẵn, xem `project.godot:11`
- **Language**: GDScript, cộng **Lua** (mã bản gốc chạy trong `game/lua_runtime.gd`)
- **Version Control**: Git with trunk-based development
- **Build System**: không có bước build riêng — chạy thẳng `godot --path .`
- **Asset Pipeline**: `/asset-spec` → `/asset-produce` → `/asset-audit` (engine-agnostic; outputs PNG / GLB / sprite sheets into `assets/`)

## Asset Production

Visual assets are generated, not hand-drawn, unless the art director says otherwise:

| Step | Skill | Produces |
|------|-------|----------|
| 1 | `/art-bible` | shape language, color system, asset standards |
| 2 | `/asset-spec` | per-asset specs + art-bible-anchored generation prompts |
| 3 | `/asset-produce` | **real files** via Gemini / Grok / Tripo3D — gated on cost approval |
| 4 | `/asset-audit` | validates delivered files against their specs |

`/asset-gen` is the low-level tool reference (flags, costs, pitfalls). Prefer
`/asset-produce` — it reads the specs and manifest for you. Reach for `/asset-gen`
directly only for one-off generation outside the spec flow.

**These are paid APIs.** `/asset-produce` requires explicit cost approval before every
batch and that approval never carries between runs. Setup and cost control:
`docs/asset-pipeline-setup.md`.

`design/assets/asset-manifest.md` is the single source of truth for asset state —
never track assets in `README.md`.

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **Repo này KHÔNG phải dự án mới.** Engine đã chốt (Godot 4.7.2) và game đã có
> mã, nên **đừng chạy `/start`** — nó sẽ hỏi lại từ đầu. Đọc `ROADMAP.md` để biết
> đang làm dở gì, và `CLAUDE.md` mục "Quy ước viết" trước khi sửa dòng nào.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
<!-- END StudioForge -->
