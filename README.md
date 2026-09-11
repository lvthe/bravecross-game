# bravecross-game

Project Godot 4.7 để làm game mới, dùng lại **bộ xương và hoạt ảnh** đã giải
được từ bản gốc (xem repo `brave-cross`).

Phần đã xong ở đây là **bộ nạp nhân vật**: đọc thẳng dữ liệu do
`work/export.py` xuất ra và dựng thành cây `Node2D` + `AnimationPlayer` chạy
được ngay — không phải dựng tay 397 scene.

## Lần đầu trên một máy mới

Sáu bước, làm đúng một lần. Bỏ bước nào cũng ra lỗi khó đoán.

```bash
# 1. Art nhân vật — gitignore vì có bản quyền, phải tự sinh từ repo brave-cross
python ../brave-cross/work/export.py --all --out assets_ref

# 2. Ảnh giao diện và bố cục màn hình — cũng gitignore, cùng lý do
python ../brave-cross/work/uiart.py --out ui_ref
python ../brave-cross/work/layout.py --all --out layout_ref

# 3. Bảng số liệu cho máy chủ — cũng gitignore, cùng lý do
python sim/export_stats.py --all

# 4. Mã nguồn Lua của bản gốc — cũng gitignore, cùng lý do
python tools/import_lua.py

# 5. Máy ảo Lua (addon ~200 MB, tải chứ không commit)
python tools/fetch_addons.py

# 6. Nạp project một lần để Godot sinh .godot/
godot --headless --path . --import
```

**Bước 3 phải có `--all`.** Không có cờ này, `export_stats.py` chỉ giữ tướng và
quân chủng có art trong `assets_ref/` — nên bảng số đổi theo máy: thiếu art là
thiếu tướng (`XiaoQiao` biến mất), và thành phần quân của từng chương đổi theo,
đội hình đang thắng thành thua sạch. Có `--all` thì bảng số giống nhau trên mọi
máy (92 tướng, 80 quân chủng) — đó là bảng mà bộ test viết theo. Đã gặp cả hai:
không có cờ thì `test_server_lua.py` hỏng 3 và bỏ qua gần nửa số kiểm; có cờ thì
270 kiểm, không hỏng.

Các script bên `brave-cross/work` trước đây tìm dữ liệu gốc **theo thư mục đang
đứng**, nên gọi từ `bravecross-game/` là không thấy gì — và `export.py` còn báo
"cho tên nhân vật", nghe như gõ sai lệnh. Nay chúng tìm theo chỗ đặt script, gọi
từ đâu cũng được.

Bước 4 là bước dễ quên nhất. Tên lớp toàn cục (`class_name`) nằm trong
`.godot/global_script_class_cache.cfg`, mà `.godot/` thì gitignore. Chưa import
thì `SngRig`, `UiTheme`, `PlayerSession` đều báo **"not declared in the current
scope"** và không script nào biên dịch nổi — nhìn y như code hỏng nặng, trong
khi thật ra chỉ thiếu cache. Và phải nạp lại **sau mỗi lần pull** có lớp mới
(`Equipment`, `XggLayout`...). `tools/check.py` giờ tự làm bước này trước khi
chạy các bộ Godot.

Nếu `godot` gọi không được sau khi `winget install`: winget **không tạo được
alias khi cài không có quyền admin** — nó vẫn báo cài thành công. File exe nằm ở
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.*\Godot_v*_win64.exe`.
`tools/check.py` tự dò được chỗ đó, còn gọi tay thì trỏ thẳng đường dẫn, hoặc
đặt biến môi trường `GODOT`.

Máy chủ cần Docker Desktop **đang chạy**, không chỉ cài. CLI `docker` có sẵn
ngay cả khi engine chưa bật, nên `docker --version` chạy được không có nghĩa là
dùng được.

## Chạy thử

Chơi:

```bash
godot --path . battle/battle.tscn
```

Chạy hết kiểm tra, một lệnh:

```bash
python tools/check.py
```

Bộ nào cần máy chủ mà không nối được thì báo **BỎ QUA** chứ không báo hỏng — để
còn phân biệt "chưa bật Nakama" với "code hỏng".

Riêng luật máy chủ (chương, chống nhảy cóc, kiểm đội hình) chạy được **không
cần Docker**: `tools/test_server_lua.py` nạp chính `server/modules/battle.lua`
bằng `lupa` với một bản `nakama` giả, rồi gọi thẳng các RPC.

```bash
python tools/test_server_lua.py
```

Nó **không thay thế** `verify_rpc.gd`: bản giả không có phân quyền của Nakama,
nên phần "client không ghi được bản lưu" vẫn phải chạy với máy chủ thật.

## Chạy từng phần

```bash
godot --path . --script tools/verify.gd
```

Kiểm tra bộ nạp mà không cần mở cửa sổ: dựng mọi nhân vật trong `assets_ref/`
rồi đối chiếu ngược với chính file JSON — đủ bộ phận chưa, đủ động tác chưa,
độ dài và cờ lặp có đúng không, có bộ phận nào được chỉ định ảnh mà không dựng
được không.

Mở màn xem thử (mũi tên trái/phải đổi động tác, lên/xuống đổi trang phục,
`[` `]` đổi nhân vật, `space` tạm dừng):

```bash
godot --path .
```

Chụp một khung rồi thoát, dùng để soi nhanh:

```bash
godot --path . -- --shot=D:/tmp/x.png --char=CaoCao --anim=Standby --zoom=3
```

Bày cả một chu kỳ trên một ảnh:

```bash
godot --path . -- --shot=D:/tmp/walk.png --char=Archer --strip=1 --anim=Walk --n=6
```

## Dùng trong code

```gdscript
var rig := SngRig.build("res://assets_ref/Archer")
add_child(rig)
rig.play("Walk")

rig.variants()    # ["Archer_WeaponWake", ..., "Archer"]  trang phục / vũ khí
rig.animations()  # ["Fight", "Critical", ..., "DefendBack"]
rig.bones         # tên bộ phận -> Node2D, để gắn hitbox hay hiệu ứng
```

`SngRig.build(dir, variant)` chọn một biến thể cụ thể; bỏ trống thì lấy biến
thể nhiều động tác nhất.

## Bộ nạp làm những gì

| Việc | Nguồn |
|---|---|
| Thứ tự vẽ | thứ tự trong `parts.children`, phần tử đầu nằm sau lưng |
| Ảnh cho từng bộ phận | bảng liên kết xương→ảnh trong `.xml` (**không đoán theo tên**) |
| Vị trí, góc xoay, tỉ lệ | keyframe, một khoá mỗi khung |
| Độ dài, cờ lặp | trường `duration` / `loop` |
| Ẩn bộ phận không tham gia | so với danh sách xương của từng động tác |
| Rig lồng nhau | dựng đệ quy — đầu và thân của các tướng là rig riêng |

**Rig lồng nhau** là chỗ dễ vấp: `CaoCao/Head` không trỏ tới một ảnh mà trỏ
tới `CaoCao_mc_Head`, một biến thể khác nằm trong chính file đó. Bỏ qua thì
tướng hiện ra không đầu không thân. `_make()` gọi lại chính nó, `_chain` chặn
gọi vòng.

## Ba quy ước hệ toạ độ

Ở đầu `rig/sng_rig.gd`, sửa được nếu thấy sai:

* `FLIP_Y = false` — Cocos2d dùng trục Y hướng lên nên tưởng phải đổi dấu,
  nhưng dựng thử thì nhân vật lộn ngược. Toạ độ trong `.xml` đã ở hệ Y hướng
  xuống sẵn, giống Godot.
* `NEGATE_ROT = false` — góc xoay đi theo trục Y.
* `CHILDREN_BACK_TO_FRONT = true`.

## Chỗ chưa chắc

* **`FPS = 24` là phỏng đoán.** Bản gốc không lưu số khung/giây ở đâu trong
  `.xml` — đã quét cả 5 trường chưa giải của bản ghi động tác. Đổi hằng số này
  nếu hoạt ảnh chạy nhanh hay chậm hơn bản gốc.
* **Đường đổi ảnh theo khung chưa giải được.** Một bộ phận có thể trỏ tới
  nhiều ảnh (`Archer/Head` có 5 nét mặt, `Effect` có 6 khung) và bản gốc đổi
  ảnh theo diễn biến trận đấu. Bộ nạp lấy ảnh đầu tiên, nên mặt nhân vật không
  đổi biểu cảm.
* **136/7995 động tác có `duration` lớn hơn số keyframe** (ví dụ `Archer/Hang`:
  2 khoá trên 10 khung). Ở đây khoá cuối được *giữ nguyên* cho hết độ dài;
  chưa xác nhận bản gốc giữ hay nội suy trải đều.
* Độ chính xác tư thế **chưa đối chiếu được với bản gốc** — mới xác nhận là
  dựng ra hình người hợp lý, chưa so từng pixel với game thật.

## Mô phỏng trận (`sim/`) — bước 1

Trả lời câu hỏi đắt nhất trước khi tốn đồng nào cho art: *bảng 92 tướng này có
thú vị không, hay một tướng đè hết?*

```bash
python sim/run.py                        # 5 tướng, 10.000 trận
python sim/run.py --all --battles 50000  # cả 92 tướng
python sim/run.py --all --sensitivity    # chạy lại với các công thức khác
python sim/run.py --duel GanNing LiuBei  # kể từng đòn một trận
python sim/test_sim.py                   # 23 kiểm tra
```

### Kết quả

Vòng tròn cả 92 tướng, 46.046 trận: **MaChao 98,6% — ZhuGeLiangYoung 0,4%,
khoảng cách 98,2 điểm.** Chạy lại với bốn công thức khác nhau: khoảng cách
97,3–99,2, MaChao đứng đầu ở cả bốn. Kết luận không phụ thuộc công thức.

Gom theo độ hiếm cho ra điều bất ngờ hơn:

| độ hiếm | số tướng | tỉ lệ thắng |
|---|---|---|
| thường (0) | 56 | 51,9% |
| hiếm (1) | 21 | **48,2%** |
| cực hiếm (2) | 15 | 76,4% |

Tướng **hiếm yếu hơn tướng thường**. Nên khối chỉ số gốc không phải một thang
sức mạnh mạch lạc — cân bằng của bản gốc phải đến từ các lớp chồng lên trên
(`BondTogetherConfig` 105 tổ hợp, thăng phẩm chất, trang bị, tinh hồn, quân
lính), chứ không từ chỉ số tướng.

**Ý nghĩa cho game mới:** nếu làm game đánh tay đôi bằng đúng bộ số này thì nó
sập. Hoặc dựng đủ các lớp phụ trợ, hoặc chỉnh lại bảng số.

### Công thức là tôi tự đặt, không phải của bản gốc

Không cột nào trong 46 cột của bảng tướng xuất hiện trong 973 file Lua của
client — chiến đấu tính hoàn toàn ở server, mà server thì không có trong tay.
Mô hình ở `sim/battle.py` chỉ dùng **số thật**, còn cách ghép chúng là tự đặt.
Ba chỗ tựa được vào dữ liệu:

* `AttackCapability` / `Viability` là **bậc** 2–8, không phải chỉ số tuyệt đối.
  Chỉ số tuyệt đối nằm ở khối dùng chung: HpBase 1000, ApBase 30–120, DpBase 30.
* Mọi cột `*Rates` là **cộng thêm**, không phải nhân: 72/91 quân chủng có
  `InjuryRates = 0`, mà quân chủng gây 0 sát thương thì vô lý.
* `QualityFactor` bằng 1 ở cả 92 tướng nên bỏ qua; `TypeFactor` trùng khít
  `HeroJobType`, là cùng một cột.

### Điểm mù đã biết

Mô hình **không có vị trí và tầm đánh**, nên nghề 3 (26,8%) và nghề 5 (30,9%)
— tướng đánh xa và hỗ trợ — bị đánh giá thấp một cách có hệ thống. Trận trung
bình 10,5 đòn; ngắn hơn nữa thì kỹ năng và chiến thuật không còn chỗ.

## Màn trận (`battle/`) — bước 2

Hai đội xông vào nhau, có thanh máu, dùng luôn art thật thay vì ảnh vuông màu.

```bash
godot --path . battle/battle.tscn
```

`R` đánh lại, `N` bốc đội hình mới, `space` tạm dừng, `1`/`2`/`3` đổi tốc độ.
Thanh xanh là máu đội trái, đỏ là đội phải, vạch vàng mỏng bên dưới là nộ —
đầy thì đòn sau là kỹ năng.

### Số liệu không chép tay sang GDScript

`sim/export_stats.py` sinh `data_ref/battle_data.json` từ bảng gốc, trong đó
nhúng sẵn **kết quả tham chiếu** của bản mô phỏng Python. `battle/combat.gd`
đọc file đó; `tools/verify_battle.gd` đánh lại đúng các cặp ấy bằng GDScript
rồi đối chiếu:

| cặp | GDScript | Python | lệch |
|---|---|---|---|
| MaChao vs ZhuGeLiangYoung | 100,0% | 100,0% | 0,0 |
| LvBu vs LvBuGod | 0,8% | 0,8% | 0,1 |
| GuYong vs JiaXu | 59,5% | 59,6% | 0,1 |
| CaoCao vs DengAi | 14,3% | 14,8% | 0,6 |

Hai bản cài đặt độc lập khớp nhau trong 0,6 điểm. Sửa công thức một bên mà
quên bên kia là test báo ngay.

```bash
godot --headless --path . --script tools/verify_battle.gd
```

### Sân không được thiên vị bên nào

```bash
godot --headless --path . battle/battle.tscn -- --sim=300 --mirror
```

Cho hai đội **đội hình giống hệt nhau** rồi đánh 300 trận. Nếu lệch quá ngưỡng
sai số thì lệnh trả mã lỗi.

Đây là một lỗi thật đã bắt được: bản đầu cập nhật một pha — duyệt đội 0 rồi
đội 1 — và **đội phải thắng 76%**. Lý do: đội 0 di chuyển trước, nên khi đội 1
tính khoảng cách thì đối thủ đã tiến lại gần, đội 1 vào tầm trước và ra đòn
trước. Sửa thành hai pha (mọi đơn vị đọc vị trí từ cùng một bản chụp, rồi trừ
máu đồng loạt) → 47,7% / 50,0% / 2,3% hoà.

### Vì sao đi theo làn

Ban đầu mỗi đơn vị chạy thẳng tới đối thủ gần nhất, kết quả là cả tám dồn về
một điểm giữa sân và chồng lên nhau thành một đống, không nhìn ra ai đánh ai.
Nay mỗi đơn vị chạy theo trục x là chính, đổi làn chậm hơn nhiều, và khi chọn
mục tiêu thì khoảng cách theo trục y bị phạt nặng — nên trận thành mấy cặp
đánh nhau theo hàng.

## Máy chủ (`server/`, `net/`) — bước 3

Hai API, đúng như README gốc yêu cầu: **đăng nhập** và **lưu dữ liệu người
chơi**. Không phải viết module server nào — Nakama có sẵn cả hai.

```gdscript
var net := NakamaClient.new()
add_child(net)
var r := await net.login()
if r.ok:
    await net.save({"level": 7, "gold": 1200})
    var s := await net.load_save()
    print(s.data)
```

Không dùng SDK Nakama cho Godot, chỉ gọi REST bằng `HTTPRequest` — ba điểm
cuối, tra từ tài liệu chính thức:

| việc | phương thức | đường dẫn | xác thực |
|---|---|---|---|
| đăng nhập | POST | `/v2/account/authenticate/device?create=true` | `Basic <khoá máy chủ>` |
| ghi | PUT | `/v2/storage` | `Bearer <token>` |
| đọc | POST | `/v2/storage` | `Bearer <token>` |
| lấy mã người chơi (dự phòng) | GET | `/v2/account` | `Bearer <token>` |

### Đã chạy với Nakama thật

```bash
cd server && docker compose up -d
```

```bash
godot --headless --path . --script tools/verify_net.gd -- --url=http://127.0.0.1:7350
```

Trang quản trị ở `http://127.0.0.1:7351` (admin/password). Không có Docker thì
chạy máy giả — cùng bộ test, chỉ đổi cổng:

```bash
python tools/fake_nakama.py --port 7399
```

24/24 đạt: đăng nhập, chưa lưu thì nạp ra rỗng (không phải lỗi), lưu rồi nạp
lại giữ nguyên số nguyên / số thập phân / mảng / `true` / chữ có dấu, ghi đè
thay cả bản lưu, đăng nhập lại bằng cùng mã thiết bị vẫn là người chơi cũ và
thấy được dữ liệu đã lưu, khoá máy chủ sai bị trả 401, chưa đăng nhập thì
không lưu được.

**24/24 với Nakama thật**, và 24/24 với máy giả. Cùng một bộ test, chỉ đổi
`--url`.

### Máy giả từng nói dối, và Nakama thật vạch ra

Lần đầu chạy với Nakama thật: **9/24 hỏng**. Máy giả đã sai ở đúng hai chỗ, cả
hai đều theo kiểu "tự giúp cho" khiến client sai mà vẫn xanh:

1. **Lệnh đăng nhập trả về `user_id`.** Nakama thật *không* — nó trả đúng ba
   trường `created`, `token`, `refresh_token`. Mã người chơi nằm trong chính
   token, ở claim `uid` (tên ở `usn`). Client đọc nhầm chỗ nên `user_id` rỗng.
2. **Khi đọc kho, tự thay `user_id` rỗng bằng người đang đăng nhập.** Nakama
   thật coi chuỗi rỗng là một chủ sở hữu *khác*, nên mọi lệnh đọc trả về rỗng —
   **không báo lỗi gì**, chỉ là dữ liệu biến mất.

Hai lỗi đó chồng lên nhau nên máy giả xanh hoàn toàn. Nay máy giả trả đúng ba
trường như thật, cấp token dạng JWT mang claim `uid`, và không vá `user_id`
rỗng nữa.

Một cái bẫy thứ ba nằm trong chính bộ test: phép so `r2.userId == c.user_id`
vẫn *đạt* khi cả hai cùng rỗng. Nay phải khác rỗng mới tính.

Bài học: máy giả chỉ chứng minh client gọi đúng dạng. Nó **không** chứng minh
Nakama chấp nhận, và nó có thể che mất lỗi thật nếu nó dễ tính hơn bản thật.

### Trước khi phát hành

`defaultkey` là khoá máy chủ mặc định của Nakama — ai biết cũng tạo được tài
khoản trên máy chủ của bạn. Đổi nó (`--socket.server_key`) và đổi luôn
`NakamaClient.DEFAULT_SERVER_KEY`.

## Ghép lại: màn trận nối máy chủ

`net/player_session.gd` đứng giữa. Màn trận không nói chuyện trực tiếp với máy
chủ — nó hỏi lớp này, và lớp này lo đăng nhập, nạp bản lưu, cộng sổ, đẩy lên.

```bash
godot --path . battle/battle.tscn
```

Đội **bên trái là đội của bạn**, lấy từ bản lưu trên máy chủ; đội địch bốc ngẫu
nhiên. Xong trận là cộng vào sổ rồi đẩy lên. `N` đổi đội của bạn và lưu luôn.
Dòng cuối trên màn hình cho biết đang là ai và thành tích bao nhiêu.

Đánh vài trận rồi thoát, không cần mở cửa sổ:

```bash
godot --headless --path . battle/battle.tscn -- --play=3
```

Chạy hai lần liên tiếp, hai tiến trình khác nhau:

```
LAN 1   trang thai : RSYixXJSRS · 17 tran: 11 thang / 3 thua / 3 hoa
        (3 tran)
        trang thai : RSYixXJSRS · 20 tran: 14 thang / 3 thua / 3 hoa
LAN 2   trang thai : RSYixXJSRS · 20 tran: 14 thang / 3 thua / 3 hoa
        (2 tran)
        trang thai : RSYixXJSRS · 22 tran: 16 thang / 3 thua / 3 hoa
```

Lần 2 bắt đầu đúng con số tiến trình trước để lại, và đội hình giữ nguyên.

### Mất mạng không được chặn người chơi

Không đăng nhập được thì `start()` vẫn trả về ok, `online` = false, và game
chạy bình thường — chỉ là không lưu. `flush()` lúc đó **báo lỗi rõ** chứ không
im lặng coi như xong. Thêm `--offline` để bỏ hẳn phần mạng.

```bash
godot --headless --path . --script tools/verify_session.gd -- --url=http://127.0.0.1:7350
```

26/26, gồm cả nhánh ngoại tuyến và nhánh bản lưu hỏng (thiếu trường, sai kiểu,
không phải từ điển).

### Hai lỗi bắt được khi ghép

**Đếm đôi.** `--play` tự bước trận trong vòng lặp riêng, nhưng `_process` vẫn
chạy song song và bước thêm một lần mỗi khung — 3 trận thành 6, sổ nhảy 12→18
thay vì 15. Nay có cờ `scripted` chặn `_process` khi một chế độ kịch bản đang
tự lái.

**Bộ test không cô lập.** `verify_session.gd` sinh mã thiết bị mới mỗi lần chạy
nhưng **không dùng** — `login()` đọc mã đã lưu ở `user://device_id`, nên mọi
lần chạy đều vào cùng một tài khoản và số liệu cộng dồn. `start()` nay nhận
tham số `device`.

## Khung giao diện

`game/ui_theme.gd` dựng một `Theme` từ art của bản gốc rồi áp cho cả cây node,
nên mọi màn theo cùng một kiểu:

| chỗ | ảnh gốc |
|---|---|
| nút | `ui_background134` — khung gỗ, nền giấy |
| bảng | `ui_background62` — cuộn giấy |
| nền menu | `ui_background135` — bản đồ thế giới có khung |
| hình nhỏ mỗi chương | `ui_background_chapter_*` — 16 bản đồ chương |

Viết bằng **mã chứ không phải `.tres`**: theme này chỉ là phép nối giữa tên
control của Godot và tên file art, viết ra mã thì đọc và sửa được ngay.

Chưa xuất art thì `UiTheme.build()` trả về `null` và game dùng giao diện mặc
định của Godot — không hỏng, chỉ là xấu.

Hai chỗ phải mò bằng cách nhìn ảnh thật, không đoán được:

* **Biên 9-patch.** Ảnh gốc là ảnh một miếng, không có sẵn thông tin biên. Đặt
  tay: khung gỗ của nút dày ~14 px, hai trục cuộn giấy thì to hơn nhiều.
* **Chọn đúng ảnh.** Lần đầu tôi lấy `ui_background188` vì tên và tỉ lệ 399×60
  trông như một cái nút — hoá ra chỉ là một dải xám mờ, kéo ra thành vạch mỏng.
  `work/contact.py` dán cả thư mục thành một tấm để nhìn một lần là biết.

Nút phải cao hơn tổng hai biên (14+14), không thì khung bị bẹp — đó là lý do
các nút để `custom_minimum_size.y = 50`.

## Nền cảnh

Mỗi chương một nền, lấy từ bản gốc (`work/scenes.py` xuất ra 24 ảnh trên 9
cảnh). Khung hình để **960×640** — đúng cỡ thiết kế của bản gốc, biết được từ
tên file bố cục của nó: `BattleField_<cảnh>_960_640.xgg`.

Bản gốc còn ghép thêm ~45 mảnh trang trí lên nền, mô tả trong chính file bố cục
đó. **Chưa dựng lại được**: texture của atlas `Scene_<cảnh>.plist` không có
trong APK lẫn OBB — nó được tải về lúc chạy từ máy chủ vá.

## Kỹ năng riêng từng tướng

Bản gốc **có** dữ liệu ai mang kỹ năng nào: `KDBGameHeroTalentSkill.xgg`, 280
dòng `(HeroID, HeroQuality) → tên kỹ năng`, 97 tên khác nhau. Lấy dòng phẩm
chất thấp nhất mỗi tướng = kỹ năng gốc.

Nhưng nó **chỉ lưu tên**. Hiệu ứng nằm ở server, không có trong tay — y hệt
chuyện công thức sát thương. Nên bảng dưới là **thiết kế của tôi**, dựa trên
nghĩa của cái tên:

| tên | nghĩa | hiệu ứng |
|---|---|---|
| `NuQi` | nộ khí | nộ đầy nhanh ×1,6 → kỹ năng nổ sớm |
| `GongSu` | công tốc | nhịp đánh ×0,8 |
| `ShengMing` | sinh mệnh | máu ×1,3 |
| `TieBi` | thiết bích | chịu sát thương ×0,8 |
| `BaoJi` | bạo kích | chí mạng +15% |
| `PoJia` | phá giáp | bỏ qua 50% giáp |
| `FangYu` | phòng ngự | giáp ×2 |
| `GongJi` | công kích | sát thương ×1,2 |
| `ShiXue` | thị huyết | hút 15% sát thương thành máu |

Kỹ năng không có trong bảng thì **không có hiệu ứng**, và màn đội hình ghi tên
trần (`ShenJi`) chứ không bịa nghĩa cho nó.

Cài ở cả ba bản — Python, GDScript, Lua — và phải khớp từng số.

### Kỹ năng làm lộ một lỗi ẩn lâu nay

`GongSu` là thứ đầu tiên khiến hai bên có **nhịp đánh khác nhau**. Ngay lập tức
phép đối chiếu Lua↔Python báo lệch **12,65 điểm**.

Chỉ số quy đổi của hai bản giống hệt nhau, nên lỗi nằm ở vòng lặp. Và đúng
vậy: `sim/battle.py` để `ta = tb = a.interval` — **cả hai bên đánh theo nhịp
của bên A**. GDScript và Lua đều đúng; chỉ bản Python sai.

Lỗi này ẩn suốt vì mọi tướng đều có `AttackInterval = 2.5`. Không có kỹ năng
thì không bao giờ lộ. `sim/test_sim.py` nay có test chặn nó.

## Cấp và nâng cấp

Bảng tướng có **`AddGrowthFactor` khác nhau từng tướng** (0 → 2,0) và
`GameHeroMaxLevelConfig` cho cấp tối đa 40 ở phẩm chất 1. Đó là dữ liệu thật,
nên hệ cấp dựng thẳng trên nó:

```
hệ số = (GrowthFactor + AddGrowthFactor × (cấp − 1)) / GrowthFactor
```

Chia lại cho `GrowthFactor` để **cấp 1 luôn bằng 1.00** — nhờ vậy mọi con số
tham chiếu cũ giữ nguyên khi thêm hệ cấp vào.

Các tướng lên cấp khác hẳn nhau, và đó là một cửa chọn đội hình thật:

| tướng | cấp 20 | cấp 40 |
|---|---|---|
| LvBuGod | ×10,5 | ×20,5 |
| MaChao | ×8,1 | ×15,6 |
| GuYong | ×3,9 | ×6,9 |

Vàng: qua **chương mới** được `60 × chương`; thắng lại chương **đã qua** được
25% chỗ đó. Nâng một cấp tốn `40 × cấp hiện tại`.

### Hai lỗi thiết kế đã sửa, đều là bế tắc thật

**Chương 1 bốc trúng tướng mạnh nhất.** Đội địch ban đầu bốc ngẫu nhiên từ cả
bảng, nên chương 1 gặp ngay LvBuGod. Kết quả: hoà 2-2, mà trận thì gần như tất
định nên đánh lại bao nhiêu lần cũng hoà, và không có vàng để nâng cấp —
**kẹt cứng ngay chương đầu**. Nay đội địch lấy từ một cửa sổ trượt trên danh
sách xếp theo sức mạnh: chương 1 gặp nhóm yếu nhất, chương 12 gặp nhóm mạnh
nhất.

**Kẹt ở một chương là hết đường kiếm vàng.** Ban đầu chỉ chương mới mới thưởng.
Ai kẹt thì thu nhập bằng 0 → không nâng cấp được → không qua nổi. Nay thắng
chương cũ vẫn được 25%.

## Máy chủ tự xử trận (`server/modules/battle.lua`)

Trước đây client đánh xong rồi tự ghi thành tích. Nay **máy chủ quyết định**:
nó bốc đội địch, mô phỏng, cộng sổ, và ghi bản lưu. Client không khai gì.

| RPC | việc |
|---|---|
| `bx.set_roster` | đổi đội hình, máy chủ kiểm tên |
| `bx.fight` | đánh một trận xếp hạng |
| `bx.selftest` | đối chiếu mô hình Lua với mô hình Python |

Trong màn trận: `F` xin trận xếp hạng, `R` đánh lại tại chỗ không tính điểm,
`N` đổi đội hình.

### Ba bản cài đặt, một nguồn số liệu

`sim/battle.py` (Python) · `battle/combat.gd` (client) · `server/modules/battle.lua`
(máy chủ). `sim/export_stats.py` sinh cả `data_ref/battle_data.json` lẫn
`server/modules/hero_data.lua`, và nhúng sẵn kết quả tham chiếu của bản Python.
`bx.selftest` đánh lại đúng các cặp đó bằng Lua:

| cặp | Lua | Python | lệch |
|---|---|---|---|
| MaChao vs ZhuGeLiangYoung | 100,00% | 100,00% | 0,00 |
| LvBu vs LvBuGod | 1,83% | 0,85% | 0,97 |
| GuYong vs JiaXu | 59,27% | 59,62% | 0,34 |
| CaoCao vs DengAi | 15,20% | 14,82% | 0,38 |

### Lỗ hổng bắt được, và vì sao RPC thôi thì chưa đủ

Đặt `permission_write = 0` trên bản lưu chặn được **ghi đè**, nhưng không chặn
**tạo mới**. Đã thử thật:

```
1. client tự tạo bản lưu với wins=999999, battles=999999   ->  HTTP 200
2. rồi gọi bx.fight                                        ->  1000000 trận,
                                                               1000000 thắng
```

Máy chủ đọc đúng con số bịa đó rồi cộng thêm. Bản lưu phải thuộc về máy chủ
**từ trước khi client kịp chạm vào** — nay có hook chạy sau mỗi lần đăng nhập,
tạo sẵn bản lưu rỗng do máy chủ sở hữu. Thử lại trên thiết bị mới toanh:

```
1. client tự tạo bản lưu bịa   ->  "Storage write rejected - permission denied."
2. bx.fight                    ->  1 trận, 0 thắng
```

Chính kịch bản tấn công đó nằm trong `tools/verify_rpc.gd` làm test hồi quy.

```bash
godot --headless --path . --script tools/verify_rpc.gd -- --url=http://127.0.0.1:7350
```

30/30, gồm cả bước tấn công.

### Bản diễn ở client ĐÚNG LÀ trận máy chủ đã xử

*(Mục này từng ghi ngược lại: máy chủ ghép từng cặp đấu tay đôi, client diễn
một trận khác, và màn hình phải ghi "bản diễn ra khác" khi hai bên lệch nhau.
Nay máy chủ chạy đúng mô hình có vị trí, ba bản dùng chung một bộ sinh số và
một bước thời gian cố định, nên bản diễn là bản **phát lại**.)*

Xem mục "Màn trận phát lại đúng trận máy chủ đã xử" ở dưới. Nếu hai bên còn
lệch thì đó là lỗi thật, và màn hình báo ra chứ không giấu.

### Chỗ chưa làm

Khoá máy chủ vẫn là `defaultkey`. Trận đấu chưa có người thật đối đầu — đội
địch do máy chủ bốc từ bảng tướng, không phải đội của người chơi khác.

## Trận dàn trận: quân lính, hàng, và trọng tài xử đúng cái đang chiếu

Trước đây máy chủ ghép từng cặp tướng đánh tay đôi, trong khi màn trận bên client đã là hai đội quân dàn
theo ba hàng. **Hai bên xử hai trò chơi khác nhau** — con số trên màn hình không còn nghĩa gì. Nay cả ba bản
cài đặt chạy cùng một mô hình có toạ độ, tầm đánh, tốc độ và hàng trước/giữa/sau.

Số liệu lấy từ `KDBGameArmyConfig.xgg`:

| cột | ý nghĩa |
| --- | --- |
| `MaxUnit` | 2–4 — mỗi quân chủng là một **tốp** lính, không phải một người |
| `Location` | 1 hàng trước, 2 hàng giữa, 3 hàng sau |
| `MaxAttackDistance` | 30 cận chiến, 300–500 bắn xa, 700–800 công thành |
| `MinAttackDistance` | 30/80 ở vài loại — không đánh được mục tiêu quá gần |

### Công thức giảm thương: chia, không phải trừ

Bảng gốc tự nó bác bỏ cách đọc kiểu trừ: quân chủng có `DpBase` 110–200 trong khi `MaxApBase` của chúng chỉ
5–100. Đọc kiểu trừ thì **ngay ở cấp 1** một tốp `DefenderN` (giáp 110) đã miễn nhiễm với mọi đơn vị trong
game — bản gốc không thể chạy như thế. Nên công thức của nó phải là kiểu tỉ lệ:

```
sát thương = công × k / (k + giáp)        k = 100
```

Đo bằng `sim/field.py`:

| công thức | quân cấp 1 → 12 | hoà | trận trung bình |
| --- | --- | --- | --- |
| trừ | 1 → 12 | 18% → 53% | 190 → 380 giây |
| chia | 1 → 18 | 0–2% | 53 → 118 giây |

Đổi công thức không động gì tới cân bằng giữa các tướng (tỉ lệ thắng vẫn trải 3%–94% y như cũ), vì mọi tướng
đều dùng chung `DpBase` = 30 — với chúng thì giáp gần như một hằng số.

Đo lại trên client, đội hình gương:

| | trái | phải | hoà | trận trung bình |
| --- | --- | --- | --- | --- |
| trước (300 trận) | 36,3% | 42,8% | 21,0% | 192,5 giây |
| sau (300 trận) | 50,7% | 49,3% | **0,0%** | **91,9 giây** |
| sau, đo lại (200 trận) | 55,0% | 45,0% | **0,0%** | **89,7 giây** |

Hàng thứ hai đo trước khi đổi bộ sinh số sang Park-Miller, hàng thứ ba là sau —
nên hai hàng không so trực tiếp với nhau được. Cả hai đều qua phép kiểm thiên vị
(lệch 10,0 điểm trên 200 trận, cho phép 10,6 — khoảng 1,4 lần độ lệch chuẩn).

### Quân lính có cấp

Ở cấp 1 quân lính yếu hơn tướng cả chục lần (công 5–100 so với 180–720). Bảng gốc có sẵn cột tăng mỗi cấp
(`HpGrowthValue`, `MinApGrowthValue`, …); dùng chung để kéo quân lính về cùng thang với tướng. Cấp gốc là 6,
chương sau thì quân cứng thêm.

## Thế trận (`KDBGameFormationConfig.xgg`)

Đây là một trong số ít hệ thống của bản gốc **còn nguyên cả số liệu**. Kỹ năng riêng của tướng thì bảng gốc
chỉ lưu cái *tên* (hiệu ứng nằm ở server của nó, không có trong tay) — còn ở đây mỗi cấp của mỗi thế trận ghi
rõ tăng cái gì, tăng bao nhiêu, cho **chỗ đứng** nào.

12 thế trận, mỗi cái một số cấp: `jichu` (cơ bản), `wuxing`, `zhenwuqijie`, `ershibaxingxiu` tới cấp 20;
`bagua`, `tiangang`, `beidou` tới cấp 30; `heyi`, `yanyue`, `fangyuan`, `zhuixing`, `yulin` tới cấp 50.

`PlacementType` 1/2/3 **chính là** `Location` 1/2/3 của bảng quân chủng — hàng trước/giữa/sau. Nghĩa là thế
trận buff **theo hàng**, khớp đúng với cách dàn quân. Và tên buff đều bắt đầu bằng `AllHero`, nên chúng áp cho
**tướng**, theo chỗ người chơi đặt tướng đó.

Bốn kiểu trị số, đọc từ chính số liệu:

| trường | nghĩa |
| --- | --- |
| `Promote` | cộng thẳng (HP +200 mỗi cấp ở `jichu`) |
| `PromotePercent` | hệ số kiểu 1.003 → tăng 0,3% |
| `PromotePercentZero` | phần từ 0: 0.003 → tăng 0,3% |
| `PromoteRates` | điểm phần trăm: 5 → tăng 5% |

Chín loại buff đổi được sang mô hình này: máu (cộng và %), công, giáp (cộng và %), sát thương %, giảm
thương %, hút máu, phản đòn. Ba loại **chưa** dùng tới, và không đoán bừa: `AllHeroReducingControl` (mô hình
này không có hiệu ứng khống chế) và nhóm `Melee`/`Arrow`/`Magic` (chưa chia loại sát thương). Chúng vẫn được
xuất ra để sau này làm tiếp.

### Thế trận đổi được kết quả thật

Hai bên **cùng một đội hình tướng**, chỉ khác thế trận và chỗ đứng, 120 trận mỗi ô:

| đội trái có gì | thắng | thua |
| --- | --- | --- |
| không thế trận | 54% | 45% |
| `jichu` cấp 1 | 59% | 40% |
| `jichu` cấp 10 | 88% | 11% |
| `jichu` cấp 20 | 91% | 8% |
| `jichu` cấp 10, cả bốn hàng trước | 88% | 11% |
| `jichu` cấp 10, cả bốn hàng sau | 83% | 16% |

(54% chứ không phải 50% vì hai bên vẫn bốc quân lính khác nhau — đó là mốc gốc chung cho cả bảng.)

Nâng thế trận là một đường mạnh lên rõ rệt. Chỗ đứng thì nhạt hơn với `jichu` vì nó buff gần đều cả ba hàng;
các thế trận chỉ buff một hàng (`yanyue` dồn hết vào hàng trước) làm lựa chọn này sắc hơn nhiều.

### Chỗ đứng là một lựa chọn thật

Chỗ đứng quyết cả hai thứ: đứng ở đâu trên sân (hàng sau thì lâu bị đánh hơn) và ăn buff nào của thế trận.
Đổi ở màn **Thế trận**, máy chủ giữ trong bản lưu.

### Giá thì đổi, buff thì không

Giá thế trận của bản gốc tính bằng trăm nghìn tới hàng triệu vàng, còn nền kinh tế ở đây mỗi chương cho 60
vàng. Nên giá chia cho 1000 — giữ nguyên **tỉ lệ** giữa các thế trận, để cái mạnh vẫn đắt: `jichu` 100 vàng
một cấp, `yanyue` 7500 vàng mới mở. Giá đó tự nó là cửa khoá, không cần khoá riêng.

Trị số buff thì giữ **nguyên số của bản gốc**: chúng đều là phần trăm hoặc cộng vào chỉ số gốc, mà chỉ số gốc
ở đây cũng là chỉ số gốc của bản gốc (`HpBase` 1000), nên dùng thẳng được.

## Bộ sinh số phải giống nhau ở cả ba nơi

Bộ LCG cũ nhân với 1103515245 làm tích chạm 2,4e18 — **quá 2^53**. Runtime Lua của Nakama (gopher-lua) giữ
mọi số dưới dạng float64, chỉ biểu diễn chính xác số nguyên tới 2^53, nên cùng một seed sẽ cho hai chuỗi khác
nhau giữa Lua, Python và GDScript. Đổi sang Park-Miller (hệ số 16807) giữ tích dưới 3,6e13 nên cả ba tính ra
đúng cùng một số.

Nhờ vậy thêm được phép đối chiếu chặt hơn hẳn: `bx.fieldtest` so **từng trận** — kết quả, số người còn sống,
số giây — chứ không chỉ so tỉ lệ thắng trên nhiều trận như `bx.selftest`.

Và bài kiểm đó phải chạy với **Nakama thật**:

```bash
python tools/verify_field_live.py
```

`tools/test_server_lua.py` chạy module qua `lupa`, mà lupa nhúng một bản Lua có **số nguyên 64 bit** — nó sẽ
không bao giờ phát hiện ra sai khác kiểu này. Đây đúng là loại lỗi mà máy giả từng che mất một lần rồi.

## `sim/field.py` — bản chuẩn và cũng là cái thước

Trận dàn trận có ba bản cài đặt: `sim/field.py` (Python), `battle/` (client) và `server/modules/battle.lua`
(máy chủ). Bản Python là bản chuẩn, và nó chạy 400 trận trong vài giây thay vì mười phút qua Godot — nên mọi
con số cân, cấp quân lính, công thức giảm thương đều đo ở đây trước.

```bash
python sim/field.py --sim 400 --mirror
python sim/field.py --sweep          # quét công thức giảm thương × cấp quân lính
```

## Màn trận phát lại đúng trận máy chủ đã xử

Trước đây màn trận diễn **một trận khác** rồi ghi đè phán quyết của máy chủ lên trên, nên có lúc nhìn thấy
thắng mà bảng điểm ghi thua. Nay cái chiếu trên màn đúng là trận máy chủ vừa xử — cùng người chết, cùng thứ
tự, cùng số giây.

Muốn thế thì bốn thứ phải khớp:

| | |
| --- | --- |
| cùng mô hình | cả ba bản đều là trận dàn trận có toạ độ, tầm đánh, hàng |
| cùng bộ sinh số | Park-Miller, `Combat.Rng` = `Rng` (Lua) = `Lcg` (Python) |
| cùng bước thời gian | `STEP = 0.033` cố định, không theo `delta` của khung hình |
| cùng seed | máy chủ trả về chính cái seed nó đã dùng, trong `seed` |

Kiểm bằng:

```bash
godot --headless --path . battle/battle.tscn -- --replaycheck --url=http://127.0.0.1:7350
```

`bx.fieldtest` cho máy chủ đánh mấy trận với seed định sẵn rồi trả về kết quả, số người còn sống và số giây;
màn trận dùng **chính đường đánh của nó** — `_spawn()` rồi `_step()` — để đánh lại từng trận đó và đối chiếu.
Phải chạy với Nakama thật.

Tốc độ 1x/2x/4x vẫn chạy được: `Engine.time_scale` làm `delta` lớn hơn nên mỗi khung chạy nhiều **bước** hơn,
chứ bước thì không đổi.

### Hai lỗi phải sửa mới phát lại được

**`randf_range` gọi nhầm hàm toàn cục.** `Combat.Rng` ban đầu đặt tên hai hàm là `randf()` và `randf_range()`.
GDScript có sẵn hai hàm toàn cục tên y hệt, và `rng.randf_range(a, b)` lại gọi trúng hàm toàn cục đó — dùng bộ
sinh số chung, không gieo seed. Nghĩa là **cú đánh lấy số ở chỗ khác**, mỗi lần chạy ra một trận khác.

Cái làm lộ ra: bộ sinh số của ta vẫn nhích **đúng một bước** mỗi đòn, trong khi `strike()` phải rút hai số
(một cho lực đánh, một cho chí mạng). `randf()` thì gọi đúng hàm của mình, chỉ `randf_range` là không. Đổi tên
thành `roll()` / `roll_range()` là hết.

**`Vector2` chỉ có 32 bit.** Máy chủ (Lua) và `sim/field.py` (Python) đều tính bằng float 64 bit, còn
`Node2D.position` là `Vector2` — trong Godot là float **32 bit**. Sai số đó dồn lại qua hàng nghìn bước, đủ để
một đơn vị chọn mục tiêu khác và cả trận đi theo hướng khác.

Nay mô phỏng chạy trên `BattleUnit.sx` / `sy` kiểu float 64 bit, còn `position` chỉ để **vẽ**.

Thứ tự phép tính cũng phải khớp, không chỉ công thức. `d / dist * (BODY - dist) * 0.5` và
`d * ((BODY - dist) * 0.5 / dist)` bằng nhau trên giấy nhưng làm tròn khác nhau, và sai khác đó cũng dồn lên.
Cả ba bản nay đều tính hệ số trước rồi mới nhân vào toạ độ.

## Thành tựu và nhiệm vụ ngày (`bx.tasks`)

Luật lấy từ `AchieveLogic.lua` / `AchieveCheckLogic.lua` của bản gốc — đọc và
ghi lại ở `brave-cross/work/GAMEPLAY.md`, mục "Thành tựu và nhiệm vụ ngày".

Mỗi loại là một chuỗi bước. Người chơi giữ `{bước đang làm, trạng thái}` cho mỗi
loại, trạng thái đúng số của bản gốc: 1 đang làm, 2 đã đạt, 3 đã nhận hết. Nhận
xong thì sang bước sau. Nhiệm vụ ngày nhận xong còn cộng điểm năng động; đủ điểm
mở rương. Cả hai xoá sạch mỗi ngày, cắt theo giờ Việt Nam (UTC+7).

| RPC | |
|---|---|
| `bx.tasks` | thành tựu + nhiệm vụ ngày + rương, kèm tiến độ |
| `bx.claim_task {type}` | nhận thưởng một bước — máy chủ **kiểm lại** điều kiện |
| `bx.claim_liveness` | mở rương năng động trong ngày |

**7 chuỗi thành tựu (93 bước)** — những loại game mới đo được tiến độ: qua
chương, cấp tướng, phẩm chất và cấp trang bị theo ô. Loại cần đấu trường, hang
động, bang hội, cấp tài khoản… chưa đưa vào: đưa vào mà không đo được thì nó nằm
mãi ở "đang làm".

**6 nhiệm vụ ngày**: 2 của bản gốc (thắng 10 trận, luyện tướng) và 4 của game mới
(cường hoá ×3, tinh luyện, phân giải, ghép đồ — loại 151–154). Mười một loại gốc
còn lại cần hệ thống chưa có, và chỉ với 2 loại thì rương 5 điểm không bao giờ mở
được. Loại 151 dùng biến đếm thật của bản gốc (`IntensifyEquipmentCountDaily`);
phần thưởng cả bốn là đúng `PrizeID` nhiệm vụ ngày gốc — chỉ số lần là tự đặt.

Phần thưởng giữ nguyên số của bản gốc. Vàng không chia: hệ trang bị đã dùng
thẳng thang vàng gốc. Thứ không có chỗ chứa (kim cương, kinh nghiệm tài khoản,
thể lực) hiện là "chưa trao" — không đổi bừa sang thứ khác. "Cấp người chơi"
(vàng theo cấp, bậc rương) dùng cấp tướng cao nhất, vì game mới chưa có cấp tài
khoản.

Màn hình `ui/tasks.tscn` (nút **Nhiem vu** ở màn chính) dựng theo đúng kích thước
và ảnh của dòng mẫu gốc (`lAchieveTemplate`, `lDailyTaskTemplate`), nhưng
**không** nhân bản dòng mẫu bằng `XggLayout`: cây cha–con của hai file `.xgg` này
dựng lại sai — cả khung màn hình lọt vào bên trong dòng mẫu.

```bash
python tools/test_server_lua.py                     # mục 11: luật, không cần Docker
godot --headless --path . tools/verify_tasks.tscn   # màn hình, dữ liệu giả
```

## Bản quyền

Bốn thư mục dưới đây đều lấy từ bản gốc, **có bản quyền**, đều bị
`.gitignore` và chỉ dùng làm placeholder trong lúc dev. Phải thay hết bằng art
tự làm trước khi phát hành:

| Thư mục | Nội dung | Cỡ |
|---|---|---:|
| `ui_ref/` | 12 491 ảnh giao diện giải từ `.pkm` | 408 MB |
| `assets_ref/` | art nhân vật và nền cảnh | 332 MB |
| `layout_ref/` | 296 bố cục màn hình trích từ `.xgg` | 16 MB |
| `data_ref/` | bảng số chiến đấu | 232 KB |

Không đẩy lên repo, nhưng **sinh lại được hết** từ APK — thứ đáng giữ trong
lịch sử là công cụ, không phải sản phẩm của nó. Máy mới thì chạy hết các lệnh
dưới đây, nếu không thì `SngRig` báo thiếu art, `XggLayout` không dựng được
màn nào, và bộ kiểm sẽ đỏ.

**Chạy từ `brave-cross/work`**, không phải từ thư mục game: các công cụ này
mặc định tìm `vn/decrypted/assets` theo thư mục hiện hành.

Art nhân vật:

```bash
python export.py --all --out <thư mục>
```

rồi chép các thư mục nhân vật cần dùng vào `assets_ref/`. Nền cảnh:

```bash
python scenes.py --all --out <bravecross-game>/assets_ref/scenes
```

Art khung và nút cho `UiTheme` (khác với `ui_ref/` bên dưới — cái này lấy từ
`assets/png/background`, tấm rời, không phải atlas):

```bash
python scenes.py --raw <...>/assets/png/background --out <bravecross-game>/assets_ref/ui
```


Bố cục màn hình (cần cho mọi màn dựng bằng `XggLayout` — màn trang bị, HUD).
296 màn, 33 472 node:

```bash
python layout.py --all --out <bravecross-game>/layout_ref
```

Ảnh giao diện, 6248 tấm (cần cho `UiFrames`). Chạy khá lâu; đứt thì chạy lại,
nó dùng tiếp những ảnh đã giải:

```bash
python uiart.py --out <bravecross-game>/ui_ref
```

Và sinh lại bảng số — lệnh này chạy từ **thư mục game**:

```bash
python sim/export_stats.py --battles 4000
```

Riêng `data_ref/equipment_ref.json` (bộ ca đối chiếu trang bị) thì
`tools/check.py` tự sinh khi thiếu — nó là công thức thuần, không dùng bảng số
nào của bản gốc.
