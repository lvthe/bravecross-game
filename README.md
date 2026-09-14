# bravecross-game

> Đang ở đâu, còn phải làm gì: xem **[ROADMAP.md](ROADMAP.md)**.

Project Godot 4.7 để làm game mới, dùng lại **bộ xương và hoạt ảnh** đã giải
được từ bản gốc (xem repo `brave-cross`).

Phần đã xong ở đây là **bộ nạp nhân vật**: đọc thẳng dữ liệu do
`work/export.py` xuất ra và dựng thành cây `Node2D` + `AnimationPlayer` chạy
được ngay — không phải dựng tay 397 scene.

## Lần đầu trên một máy mới

Bảy bước, làm đúng một lần. Bỏ bước nào cũng ra lỗi khó đoán.

```bash
# 1. Art nhân vật — gitignore vì có bản quyền, phải tự sinh từ repo brave-cross
python ../brave-cross/work/export.py --all --out assets_ref

# 2. Ảnh giao diện và bố cục màn hình — cũng gitignore, cùng lý do
python ../brave-cross/work/uiart.py --out ui_ref
python ../brave-cross/work/layout.py --all --out layout_ref
# 2b. Nhét tag thật vào bố cục. BẮT BUỘC, và phải chạy SAU layout.py vì
#     layout.py ghi đè. Tag không nằm trong .xgg — nó đo được từ chính engine
#     bản gốc chạy trong máy ảo, và mã Lua gốc trỏ tới node gần như chỉ bằng
#     nó (getChildByTag: 9.529 lần). Dữ liệu đo sẵn nằm trong repo brave-cross
#     nên bước này chỉ ghép, không cần máy ảo.
python ../brave-cross/work/emu_join.py --ghi
# 2c. Bảng chữ tiếng Việt và 104 bảng cấu hình của bản gốc — mã gốc đọc
#     chúng lúc chạy, thiếu là màn hình trống chữ và trống phần thưởng.
python ../brave-cross/work/text_table.py
python ../brave-cross/work/config_tables.py
# 2d. Tốc độ di chuyển của từng sprite (map/*_config.xml). Thiếu nó thì màn
#     trận rơi về cách tính cũ — quân đi chậm hơn bản gốc.
python ../brave-cross/work/move_speed.py
# 2e. Số liệu kỹ năng thức tỉnh (khối `<fight>` tên `fight_<Sprite>Wake`).
#     Thiếu nó thì tuyệt chiêu kịch bản rơi về 1 đòn cho mọi tướng.
python ../brave-cross/work/wake_ref.py

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

## Chạy thẳng mã Lua của bản gốc

Đây là hướng chính hiện nay, và nó thay cho việc chép tay từng màn sang
GDScript. Lý do: bản gốc có sẵn 952 file Lua / 518.585 dòng, riêng phần giao
diện đã ~324.000 dòng. Chép tay thì không bao giờ xong và không bao giờ giống.
Nên ta **nạp chính mã đó** và chỉ viết phần engine bên dưới nó.

```bash
godot --path . tools/xem_man.tscn                    # bảng chọn 352 màn
godot --path . tools/xem_man.tscn -- --mo=Backpack   # mở thẳng một màn
```

Bấm một cái là gọi đúng một dòng của bản gốc — `<quản lý>:Show(<tên>)` — còn
lại là mã của nó: nạp bố cục, `onInit`, hoạt cảnh mở, `onShow`,
`setDialogVisible`, `onVisible`, `Reflesh`. Tab ẩn/hiện bảng chọn, Esc đóng màn.

### Đang ở đâu

| | |
|---|---|
| module của bản gốc nạp được | **875/876** |
| màn đăng ký | 353 |
| màn mở được | **246** |
| màn "im" (đòi tham số, không phải hỏng) | 22 |
| màn hỏng | 85 — phần lớn là **thiếu dữ liệu người chơi** |

Bộ hẹn giờ thật, `S_CCSprite` và phép đổi toạ độ mở thêm `ArenaMain`,
`CUIFirstPayGift`, `CUIWCSShop` (243 → 246).

Quét không hoàn toàn tất định: giữa hai lần chạy, vài màn đổi qua lại giữa "im"
và "hỏng" (vd `ArenaSummary`, `ThreeButtonDialog`) vì màn trước để lại trạng
thái. Số tổng thì giữ nguyên — kể cả khi bỏ phần chạm đi (đã đo đối chứng).

Đo lại bất cứ lúc nào:

```bash
godot --headless --path . --script tools/quet_show.gd
```

**Bấm được.** Tên chạm và đối tượng nhận chạm nằm ngay trong bản ghi node của
`.xgg` (+0x0C tên chạm, +0x14 tên biến toàn cục của đối tượng): 2.005 node,
1.204 cặp khác nhau, 1.021 cặp khớp đúng lớp có hàm xử lý. Cộng với
`setLuaTouchName` / `setCallbackLuaObject` lúc chạy (318 / 325 chỗ), engine giả
gọi `<đối tượng>:onTouchBegin_/Move_/End_<tên>` theo đúng khuôn tên có trong
`libgame.so` (`onTouchEnd_%s` ở 0x7b10fd). Trong `xem_man`, bấm chuột vào màn
là mã gốc chạy; dòng trạng thái ghi hàm vừa gọi và lỗi nếu có.

```bash
godot --headless --path . --script tools/verify_cham.gd
```

Bộ kiểm mở màn thành tựu bằng `Show` của bản gốc, bấm nút nhận thưởng, và
`CUIAchieve:onTouchEnd_OnAhchieveButtonClick` chạy không lỗi.

### Ba mảnh của tầng dưới

* **`game/lua_runtime.gd`** — máy ảo Lua (lua-gdextension, LuaJIT = Lua 5.1,
  đúng bản Cocos2d-x dùng) + `require` tự viết đọc qua `FileAccess`, vì `sc/`
  có `.gdignore`. Kèm mấy cầu nối sang Godot: đọc file cấu hình, gán ảnh theo
  tên khung, nhân bản node, **nạp `.xgg`** (`loadLevelFile`), xếp lại thứ tự vẽ.
* **`lua/cocos.lua`** — lớp giả lập Cocos2d-x 1.x. Node là **userdata** (bản
  gốc gọi `KDebug.ProcessNotUserdata` 3.786 lần nên node phải đúng kiểu đó).
  Kèm `lua/actions.lua` (hệ action viết tay, không dùng Tween của Godot vì
  ngữ nghĩa khác) và `lua/json.lua`.
* **`lua/bootstrap.lua`** — khởi động khung sườn, và **bóng**: mỗi biến toàn
  cục chưa làm được thay bằng một đối tượng ghi lại mọi lượt gọi. Bóng **làm
  sai hành vi** — nó là dụng cụ ĐO xem còn thiếu gì, không phải giải pháp.

### `boot_goc()` — nạp theo bản kê khai của chính bản gốc

```lua
local boot = require('bootstrap')
boot.install_cocos()   -- đặt S_CC*, bảng chữ, cấu hình, loadLevelFile, ProtoRPC
boot.install()         -- bật bóng cho mọi biến còn lại
boot.boot_goc()        -- nạp 876 module theo sc/game.lua:174-183
boot.init_config()     -- 104 bảng cấu hình
```

**Đừng tự chọn danh sách module ngắn.** Đó từng là gốc rễ của gần hết "màn
hỏng": cái gì không nạp thì là bóng, mà bóng gọi ra **một** giá trị, nên
`local bRet, data = G_XLogic:GetY()` cho `data = nil` — và màn hình chết ở dòng
sau với thông báo trông y hệt thiếu dữ liệu máy chủ. Nạp đủ thì 164 màn đăng ký
thành 353, và 105 màn mở được thành 244.

`boot_goc()` cài lại lớp giả lập **sau từng bản kê khai**, vì
`system/engine.lua` là bề mặt ràng buộc C++ (70 biến `S_CC*`) — nạp nó vào là
đè bóng lên hết những thứ ta làm thật, kể cả `screenWidth`.

### Những chỗ đã mất công tìm ra, đừng tìm lại

* **`+0xA4` trong `.xgg` là `zOrder`**, không phải tag. Kiểm được vì
  `CUIManager.lua` đặt zOrder cho từng lớp che bằng hằng số viết rõ trong mã:
  `lNormalDlgMask` 20, lớp chạm 21, `lSubDialogMask` 100, `lSystemMask` 4000,
  `lNetWorkMask` 6000, `lDebugBoxMask` 9000 — 10/12 trùng khít. Godot chỉ nhận
  `z_index` trong ±4096 mà bản gốc dùng tới 9000, nên phải **xếp lại anh em**
  chứ không đặt `z_index`.
* **Tag thật không nằm trong `.xgg`** — engine sinh lúc nạp. Đo từ chính bản
  gốc chạy trong máy ảo Android (`work/emu_tags.py`), ghép vào bằng
  `emu_join.py --ghi`. Phủ 90,7% số cặp (node, tag) mà mã gốc thật sự hỏi.
* **`CCLayer` bỏ qua điểm neo khi đặt chỗ** (`ignoreAnchorPointForPosition` của
  cocos2d-x 2.x — chuỗi này có trong `libgame.so`, còn `RelativeAnchorPoint`
  của 1.x thì không) — chính chú thích của bản gốc nói thế
  (`CUIAssist.lua:454`): *"用左下角是为了支持layer, 因为layer会忽略anchor"*. Cần
  đúng chỗ này vì hoạt cảnh mở gọi `setAnchorPoint(0.5,0.5)` rồi không trả lại.
  Bộ nạp `.xgg` cũng theo luật này (`XggLayout.bo_qua_neo`, cho `CCLayer` và
  `CCScene`), nhưng vẫn giữ neo thật trong meta vì mã gốc đọc
  `getAnchorPoint()` rồi tự trừ đi: `CUIHelper:fixListViewPosition` xếp nút
  thức tỉnh vào `lBattleSkill` (520×140, neo 0,5, tại 270,75). Áp neo cho lớp
  thì nút đầu tiên ra x = −250, ngoài màn; theo luật thì ra x = 10, khít mép
  trái khung. `CCLayerColorRoundRect` **chưa đo** nên vẫn áp neo — phần lớn là
  lớp che đặt giữa cha (`lSubDialogMask` 960×640 tại 480,320).
* **Tên ảnh trần tra trong `sngSplitData/`**, lấy bản nông nhất. Đó là không
  gian tên của `S_CCSpriteFrameCache`: ảnh giao diện không nằm trong atlas, mỗi
  ảnh là một `.pkm` riêng. Chấm bằng chính bảng sprite của `.xgg`: luật cũ
  15/183 đúng, luật mới 180/183.
* **`class(<bóng>)` chạy mãi** — `class()` đi ngược chuỗi cha bằng
  `while typeSuper ~= nil`. Ba lớp dính lỗi này có lớp cha **không tồn tại**
  trong 973 file đã ship, tức bản gốc chạy `class(nil)` bình thường.
  `bootstrap` bọc lại `class` để trả về đúng hành vi đó.
* **`ProtoRPC`** — đối tượng RPC bên C++, nay là cái ống không nối đi đâu.
  Phải có thật chứ không được để là bóng: `rpc.lua` ném số thứ tự vào
  `convertTo32UintString` rồi so với `0x100000000`.
* **Bản gốc luôn ở trong một cảnh.** `g_CSceneManager.CurrentScene` là `nil`
  thì `CLevelLoader` không bắn tin `OnLoadXGG` và `onInit` của màn hình không
  bao giờ chạy. `xem_man` và các bộ kiểm màn vẫn đặt `"Test"`; đường vào cảnh
  thật thì xem `tools/vao_main.gd`.
* **Đổi cảnh là một coroutine chạy bằng bộ hẹn giờ.** `CSceneManager` nhường
  từng bước bằng `S_CCSchedule:scheduleOnce(self, "sngLoadingNext")`, nên
  không có hẹn giờ thật thì nó đứng yên ở lần `yield` đầu tiên. Gọi lại phải
  để **khung sau** (kể cả `loadLevelFileAsync`): gọi ngay là resume chính
  coroutine đang chạy, Lua báo *cannot resume non-suspended coroutine*. Ngữ
  nghĩa hẹn giờ lấy từ chú thích của chính bản gốc, `CTimerManager.lua:102-117`.
* **`S_CCSprite` là một thể hiện dùng làm nhà máy** (`system/engine.lua:41`:
  `S_CCSprite = CCSprite:new()`), rồi mã gốc gọi `S_CCSprite:new()` 61 lần.
  Để nguyên thì `:new()` rơi vào stub, ra `nil`, và coroutine đổi cảnh chết.
* **Engine nới lớp phủ màn theo tỉ lệ cửa sổ** (1366 → 1429 trên máy ảo) và
  giữ con ở đúng tỉ lệ trong cha. `emu_join` nay so thêm theo tỉ lệ cỡ cha:
  +182 node có tag (17.830 → 18.012), không sinh tag trùng, và
  `lCommonLoadingDialog:getChildByTag(4)` — chỗ cảnh `Main` từng chết — ra
  đúng `lLoadingDialog`.
* **Màn "im" phần lớn là đòi tham số.** `Show(tên, data, kiểu)` truyền `data`
  xuống `onShow`; màn nào đòi thêm tham số thì thoát ngay dòng đầu. Đo bằng
  `debug.getinfo(ui.onShow, 'u').nparams`.
* **Quét liên tiếp phải dọn tay hai chỗ** bản gốc không tự dọn: `IsUILock`
  (`CloseImmediately` không đặt lại) và hàng đợi hoạt cảnh (`InsertAnimation`
  chỉ chạy ngay khi hàng đợi đang rỗng).

* **Chạm: `EndEx` không đi sau `End`.** 33/66 hàm `onTouchEndEx_*` tự gọi lại
  `onTouchEnd_*(node, false)` của chính nó (vd `CUIAchieve.lua:597`) — engine mà
  gọi cả hai thì `End` chạy hai lần. Nên `EndEx` là lối ra khi chạm bị cướp
  (danh sách cuộn), và chưa gọi vì chưa có cuộn bằng chạm. Giá trị trả về của
  `Begin` cũng **không** quyết định có nhận chạm: `End` tự kiểm lại đúng điều
  kiện của `Begin`, và 42 lớp chỉ có `Begin`. Hai điều này **suy từ mã Lua,
  chưa đo trên engine** — đọc hàm phát chạm trong `libgame.so` cần
  `work/armdis.py`, mà nó cần `capstone` + `pyelftools`.
* **Kéo `brave-cross` mới thì dựng lại `ui_ref` và `layout_ref`** (bước 2 và
  2b ở đầu README). Dữ liệu cũ không báo lỗi mà hỏng lặng lẽ: trên một máy
  mới, `layout_ref` dựng trước khi `layout.py` ghi `zOrder` làm 4 bộ kiểm đỏ,
  và `emu_join` chỉ ghép được tag cho 9.901 node thay vì 17.830.

### Việc tiếp theo, theo thứ tự

1. ~~**Nối chạm**~~ — xong (xem trên). Còn lại của phần chạm: cuộn danh sách
   bằng chạm (kèm `onTouchEndEx`), và đo hàm phát chạm trong `libgame.so` để
   thay hai điều đang suy bằng số đo.
2. ~~**Dựng cảnh `Main`**~~ — phần engine xong. Chạy đúng dòng của bản gốc,
   `g_CSceneManager:RepaleceScene("Main")` (`ClientActivitiesLogic.lua:104`),
   và coroutine đổi cảnh đi hết: nạp `UI_Main_960_640` lên sân khấu, khung hộp
   thoại vào `g_MainUIScene`, 13 file chung của `CUIMain:sngPreLoad`,
   `onEnter`, khung chat. `InitUI` giờ dừng ở `CUIMain.lua:201` vì
   `G_UserLogic:GetLevel()` ra `nil` — **thiếu dữ liệu người chơi**, không còn
   là thiếu engine. Đo bằng `tools/vao_main.gd`, khoá bằng
   `tools/verify_main.gd`.
3. ~~**Trạng thái người chơi mới tinh**~~ — xong. Giá trị lấy từ **chính bảng
   cấu hình của bản gốc**: `KDBGameCommonConfig` có mục `<bảng>Reset` cho
   10/33 bảng người chơi (tướng 25 cùng 6 món, 50.000 vàng, 0 kim cương, thống
   soái 6, thể lực 120…), và mã server dùng chung nạp người chơi đúng kiểu đó
   (`LotteryLogic:Reset`, `UserLogic:Reset`). Giao qua **lớp offline** của
   `brave-cross/work/offline` (thay máy chủ, `import_lua.py` chép vào
   `sc/offline`). `tools/vao_main.gd` chạy **cả chuỗi của bản gốc**: cảnh Login
   → `G_Login:Login` → chọn máy chủ → `onTouchEnd_OnEnterGame` → `StartRPC` →
   `Handshake` → `EnterGame` → `OnGetAcvitityList` → `RepaleceScene("Main")`.
   Ba cú bấm của người chơi làm thay bằng đúng hàm nút gọi; còn lại là mã gốc.
4. ~~**Tag con của `lMainToolbarRightTop`**~~ (40 nút góc phải trên của
   `Main`) — máy ảo chưa bao giờ đo tới, nay gán bằng **đối chiếu nhãn**:
   `brave-cross/work/tags_nhan.json`, `emu_join.py` áp sau tag đo được và
   đánh dấu `tagFrom: "nhan"`. Ba nguồn độc lập: nhãn chú thích
   `-- <tính năng> begin` ngay trên `getChildByTag(n)` (và nhãn của
   `iosApproveHelper`), tên pinyin của từng tag trong cấu hình
   `GameMainTopConfig`, và tên lớp của nút trong `.xgg`. 40 nút đánh số đúng
   1..40, mỗi tag một nút; 40/40 gán được, 0 xung đột. Duy nhất tag 11
   (`虎符争夺`) là **loại trừ** — nút cuối cùng còn lại.
5. ~~**Tag của node CON bên trong từng nút**~~ — không có nhãn, gán bằng **suy
   cấu trúc** (`do_tin: "cau-truc"` trong `tags_nhan.json`; chọn node theo
   loại + "có con loại X", cha chỉ bằng đường tag như `lMainToolbarRightTop/18`,
   phải khớp ĐÚNG MỘT node). Nút 18: `CUICOGEntry.lua:272-273` lấy con tag 2
   rồi con tag 1 của nó và `setString` lên đó. Kiểm bằng số đo: nút cùng kiểu
   `lArmyGroup_COGButton` — mã gốc dùng y hệt (`:310-311`) — ĐO ĐƯỢC trên máy
   ảo là `CCScale9Sprite` tag 2 chứa `CCLabelTTF` tag 1, và nút 18 chỉ có đúng
   một con như thế. Với hai tag này, `InitUI` chạy hết và `replaceScene` đưa
   **`g_MainUIScene` lên màn hình** — lần đầu cả chuỗi Login → `Main` của bản
   gốc chạy trọn. Chụp: `godot --path . --script tools/vao_main.gd -- --chup=main.png`.
6. ~~**Vẽ cảnh `Main` cho đủ**~~ — trời, thành phố, nhà, dải nút trên cùng,
   biển tên nhà và số của người chơi đã lên màn. Những chỗ đã sửa, mỗi chỗ
   có số đo:
   * **Cửa sổ của engine cao cố định 768**, rộng theo tỉ lệ màn: máy ảo đo ca
     13 `CCScene` là 1429×768 tại (0,0). `LuaRuntime.cua_so_engine`; cảnh đặt ở
     gốc cửa sổ (file ghi (1,−1), neo 0,5 — `CCScene` bỏ qua neo).
   * **Bố cục nạp vào một cha khác** (khung hộp thoại vào `g_MainUIScene` cao
     768) và **`addChild`** giữ nguyên toạ độ Cocos, đổi theo chiều cao thật
     của cha. Trước đó `UIRootLayer` lệch 128 và dải nút trên cùng bị cắt;
     nhà (armature) rơi thấp ~480 px.
   * **Trời** là dải chuyển màu `CCLayerGradientEx`: bản ghi 312 byte, mảng
     cố định 7 ô (RGB, alpha, vị trí) — giải đúng cả 18 node của mọi file.
   * **Nhà** là armature (`getUIAnimFromSpriteCatch`, 216+31 lời gọi;
     `_Lua_playAnimation` 440) — phát bằng `SngRig` trên chính armature gốc;
     tên dạng biến thể (`UITongYong_ItemLight`, `Player004M03F`) tìm theo tiền tố.
   * **Chữ của nhãn** ở `+0x138` của bản ghi `CCLabelTTF` (`#Khoá` tra bảng chữ
     tiếng Việt, không `#` là chữ viết thẳng): 4.237 khoá, 4.228 có trong bảng.
     Trước đó mọi nhãn tĩnh trên mọi màn đều trống. **Căn chữ** ở `+0x100` /
     `+0x104` (thứ tự enum Cocos 0/1/2). **Nhãn ô CAO (đoạn văn, cao ≥ 45)
     xuống dòng theo bề rộng ô** (`AUTOWRAP_WORD_SMART` + `clip_text`) — bản gốc
     `CCLabelTTF` tạo kèm kích thước thì tự ngắt; thiếu thì chữ dài tràn ngang
     cắt qua cả màn (màn kết thúc trận: ba mục kiến nghị `#FinishUI_*Tip` 195×70
     dính vào nhau). Nhãn một dòng (cao ~30) giữ nguyên để khỏi ngắt nhầm.
   * **Số vàng / kim cương / thể lực**: tag 1 (nhãn số) và 2 (biểu tượng) của
     ba thanh tài nguyên — suy cấu trúc từ `setNum` / `rollNum`, không có số
     đo đối chiếu. Giờ hiện đúng 50.000 vàng, 0 kim cương, 120/120 thể lực
     của `GameUserBaseInfoReset`.
7. **Còn thiếu ở `Main`:** hiệu ứng sáng `UITongYong_ItemLight` vẽ thành đốm
   xanh (có lẽ thiếu hoà màu cộng); `sngFixInfoReflash` (sắp lại con khi đổi
   cỡ) chưa làm; nhà ở nửa phải lớp cuộn chưa xem được vì chưa có kéo cuộn.
8. ~~**Chiến dịch: từ Main vào trận rồi về màn kết thúc**~~ — chạy trọn bằng
   đúng đường của bản gốc. Xem mục "Chiến dịch và sân trận" ngay dưới.

#### Chiến dịch và sân trận

```bash
godot --headless --path . --script tools/do_chien_dich.gd            # đo từng bước
godot --headless --path . --script tools/do_chien_dich.gd -- --kiem  # tự kiểm (check.py)
```

Công cụ gọi đúng hàm mà từng nút gọi: nút tấn công ở Main
(`CUIMain:onTouchEnd_btnMainExtraUIAttack`) → chọn ải → "Đi" (`OnGo`) →
bố trí quân → tấn công → `ClientChapterBegin` → `RepaleceScene("Battle")` →
`CUIGame:StartBattle` → `g_BattleField:_Lua_StartGame` → hết trận →
`ClientChapterCompleteSuccess/Faild` → `CUIGameFinish`. Sau mỗi bước in ra
lời gọi máy chủ, lời gọi lớp offline còn thiếu, và lỗi của mã gốc.

**Máy chủ (lớp offline, `brave-cross/work/offline/.../handlers/chapter.lua`).**
Luật server của chiến dịch NẰM SẴN trong `sc/share/share_ChapterLogic.lua`
(`saveChapterBeginStatus`, `chapterCompleteSuccess` → `chapterVictoryHandle`,
`chapterCompleteFaild`), và client có chúng trên `G_ChapterLogic`. Handler chỉ
gọi luật đó rồi chép `G_DataManager.userData` về kho. Đo được trên
`L_N_01_01`: vào ải trừ 1/6 thể lực (120 → 119); thắng thì cộng 200 vàng
(`ResourceCount`), kinh nghiệm, trừ nốt 5/6 thể lực, chiến báo
`BattleStatus 3`; thua thì giữ vàng, chiến báo `BattleStatus 2`. Hai chỗ
không có trong tay, nói rõ trong file: danh sách rơi đồ do server gốc sinh
(gửi rỗng, đúng hình `{DropConfig, Drop}`), và `CheckActivityIsDoublePrize` —
hàm chỉ server có; ở đây hỏi đúng hoạt động mà luật gốc hỏi, offline không có
hoạt động nên không nhân đôi. `ClientCheck` (chống gian lận) bỏ qua.

**Sân trận (`lua/san_tran.lua`, `battle/tran_goc.gd`).** Trận của bản gốc
đánh trong C++ (`libgame.so`); Lua chỉ đưa dữ liệu qua `setSendTroops` /
`setLevelData` rồi nghe gọi ngược. `g_BattleField` là node CCLayer trong
`BattleField_<cảnh>_960_640.xgg`; `cocos.lua` gắn bộ hàm riêng cho nó theo tên
(`lop_rieng`). Tên hàm của nó và tên các hàm engine gọi ngược vào `g_CUIGame`
(`troopResidue`, `npcResidue`, `TotalHpResidue`, `onLevelComplete`,
`onLevelOver`…) lấy từ chuỗi của `libgame.so`, không đoán. Trận đánh bằng CHỈ
SỐ THẬT trong dữ liệu đó (HP, MinAp/MaxAp, DP, AttackInterval… do luật gốc tính
theo cấp), nhưng **cách gộp thành sát thương là của ta**
(`Combat.Fighter.strike`).

**Trận có hình** (`battle/san_tran_ve.gd`): quân là `BattleUnit` (đi theo làn,
chọn mục tiêu, nhịp đánh, thanh máu, động tác `SngRig` từ `assets_ref`) đặt lên
chính node `g_BattleField`, trên nền trận của bản gốc. Tên armature lấy từ
`Name` / `SpriteName` trong dữ liệu gốc, tìm theo tiền tố như `_tao_rig`
(`Player000M03W` → `Player000`, biến thể `Player000M03W`); cỡ theo `NpcSize`.
Trận bước theo bộ hẹn giờ của Lua, không theo `_process` — nên chạy được cả khi
không có cửa sổ — và kết quả là trận người chơi nhìn thấy. Chế độ tính nhanh của
bản gốc (`setQuickResult`) và `quickGameFinish` vẫn đánh tức thì
(`battle/tran_goc.gd`). ĐẶT, không phải bản gốc: mặt đất = giữa node
`g_MapZero`; tốc độ và tầm đánh tối thiểu của `BattleUnit`; cách camera bám quân.

**Chỗ đứng và camera — số thật.** 1 ô (格) = 100 px: chú thích của bản gốc
trong `map/hero_config.xml` ghi *"单位:格 100pix"*, khớp với `MaxAttackDistance`
tính bằng px (30 cận chiến, 300–500 bắn xa) và với `CUIGame:FitBattleArmyPos`
(căn giữa đấu trường ở ô 6,83 = nửa màn 1366). `PosX` của dữ liệu ải tính theo
ô từ `g_MapZero`: ở L_N_01_01 tướng ta đứng ô 7, ba nhóm địch ô 12 / 18 / 24 —
sân dài hơn một màn, nên camera chạy theo quân.

* **Parallax:** `g_BattleFieldLayer` là một `CCParallaxNode` (trong
  `Game_UI_960_640`), mã gốc nạp cả file sân vào nó. Hệ số của từng con nằm ở
  `+0x30` / `+0x34` của bản ghi node (`xgg.py`, `layout.py` ghi thành
  `parallax` khi khác 1). Đo trên 18 file sân: lớp nền `gb<tầng>_<ô>` ra 1,4
  (`gb0`, tiền cảnh) / 1,0 (`gb1`, mặt đất) rồi giảm dần theo tầng, mọi ô của
  một tầng cùng một số; `g_BattleField` luôn 1,0; trời 0,001 (đứng yên — khớp
  với việc nó chỉ rộng 2000). Bề dài sân = mép phải của mặt đất (Snow: 4096).
* **Hằng số camera** từ mục `<camera>` của `map/global_config.xml` (giải mã ở
  `brave-cross/work/vn/decrypted`): ngưỡng 0,8, tốc độ 1,8 ô/giây, chậm dần
  trong 2 ô, tăng tốc trong 0,7 giây, đuổi nhanh khi lệch quá 5 ô. **Cách** dùng
  các số đó là ĐẶT — luật thật nằm trong lớp C++ `CDFCamera`, chưa giải: giữ
  quân ta đi đầu ở 0,8 bề ngang màn. `g_BattleField:StopCamera()` (kịch bản)
  dừng camera thật.
**Công thức sát thương thật** (chỉ trận có hình — `battle/harm.gd`). Cấu trúc
giải từ hàm C++ `0x380c94` và hằng số `<formula>` của `global_config.xml`
(chi tiết ở `brave-cross/work/README.md`). Thay chỗ trừ giáp thẳng của mô hình
ta bằng luật chia của bản gốc:

```
avoid = DP / (DP + 1500)         (chặn trên 1)
dmg   = elem + atk×(1−avoid) + xuyên; ×(1+DamageAddition/3000);
        −ReducingDamage; ×(1+FinalHarm); × DamageMultiples(theo loại mục tiêu)
```

Nhờ chia thay vì trừ, tướng ta không còn bị giáp cao nuốt sạch đòn: ap 78 vào
Lữ Bố (DP 500) ra **58,5** thay vì **1** (78−500 kẹp về 1); và hệ số nhân thật
của địch phát huy — lính Defender NPC có `DamageMultiplesAtDogface = 5` nên
đánh lính ta 75 thay vì 15. **Mô hình đối chiếu ba bên (`combat.gd` mặc định,
`sim/battle.py`, `server/battle.lua`) KHÔNG đổi** — `harm_real` chỉ bật trên
bản `rules` riêng của trận có hình.

ĐẶT (chưa kiểm byte-exact, cần máy ảo): ánh xạ trường struct sang bên đánh /
bên chịu theo nghĩa tên trường, và ghép bốn tham số `FinalHarm`. `combat.gd`
giữ nguyên đường cũ khi `harm_real` tắt.

Cùng `<formula>` còn nhiều hằng số khác (`RoleGrowthBase` 2, `CriticalResistBase`
3000, `StateResistBase` 2000) cho các hàm con đã giải — dùng khi port đủ.

Kiểm: `do_chien_dich.gd --kiem` cho camera bám một quân đầu giả ở x = 3000
trong 20 giây, rồi đòi camera dừng đúng đích (2078 = 3000 − 0,8 × 1152) và
**mọi** lớp trôi đúng hệ số × camera (gb6 0,4 → 831, gb0 1,4 → 2910). Chụp
cảnh camera đã trôi: `... -- --chup=tran.png --cam=2500 --khung=30`.

**Chơi thử một trận** (có cửa sổ, không `--headless`): tự đi Main → chọn ải
→ "Đi" → xếp tướng → tấn công, rồi giao cửa sổ cho người chơi — bấm nút binh
chủng (dưới giữa) để đưa lính ra, nút thức tỉnh (dưới trái) khi nó sáng, xem
camera chạy và màn kết thúc. Lỗi Lua mới in ra ngay.

```bash
godot --path . --script tools/do_chien_dich.gd -- --xem
```

Đã chạy 10.000 khung liền (qua hết trận L_N_01_01) không lỗi Lua nào.

**Đi từ `Main` vào trận bằng cú bấm thật** — `tools/bam_that.gd` (bộ
`bam that Main -> tran` của `check.py`). Mỗi bước tìm node đang hiện mang tên
chạm của nút (`btnMainExtraUIAttack` → `OnSelectLevel` → `OnGo` →
`OnChapterListAttack`), bấm vào tâm nó qua `touch_at` — đúng đường chuột của
`--xem` — rồi đòi màn kế tiếp mở. In ra node NÀO thật sự nhận cú bấm, nên lớp
phủ nuốt cú bấm lộ ngay. Nó đã lộ hai chỗ, đều là **yêu cầu máy chủ không ai
trả**: yêu cầu phát `OnWaitingForRequest` → `CUIMain:OnWaitingForRequest` bật
lớp "đang tải" (`lCommonLoadingDialog`, tên chạm `ClickBackground`), và chỉ
`OnReceiveResponse` mới tắt — lớp đó nằm đè cả `Main`. Tìm bằng vết gọi của
`g_buyLoadingDialog:Show` (móc trong `bam_that.gd`):

* **Quốc chiến** — `CUIMain:onEnter` hỏi giờ mở (`ClientStateWarBeginTime`,
  hàm sinh bởi `CUIAssist.bindRpcToEvent`; vết `CUIAssist.lua:356 <
  StateWarLogic.lua:27 < CUIMain.lua:533`). Lớp offline trả `(0, "")` — chưa
  có lịch (`handlers/statewar.lua`).
* **Cửa hàng bí ẩn** — `OnMainShowUI` gọi `ClientRefresh` khi hàng đã quá mốc
  làm mới (9 / 12 / 18 / 21 giờ), nên **lúc được lúc không theo đồng hồ**: một
  lần dò qua, lần sau sang mốc mới thì kẹt. Client không có hàm nhận riêng; lớp
  offline trả qua đường chung của bản gốc
  `g_CUIGameRPCManager:OnReciveResponse("", "", 0, {})` — phát
  `OnReceiveResponse`, không đổi dữ liệu (`handlers/mysterious.lua`). Luật
  sinh danh sách hàng chỉ server gốc có: offline **không** làm mới hàng.

`handlers/achieve.lua` (đạt / nhận thưởng thành tựu, gọi luật gốc
`AchieveLogic`) viết lúc đang đoán kịch bản hướng dẫn tân thủ là thủ phạm —
đoán sai, và đoạn đó chưa chạy tới trong lần dò nào, nên nó **chưa được kiểm
bằng đường thật**.

Lớp offline cố ý KHÔNG trả lời API chưa có handler (test `khong tra loi bua`),
nên yêu cầu nào khác phụ thuộc giờ mà chưa có handler vẫn có thể làm kẹt `Main`
vào lúc khác — `bam_that.gd` sẽ chỉ ra. Bấm tay trong `vao_main.gd --xem` giờ
đi được tới trận.

```bash
godot --path . --script tools/do_chien_dich.gd -- --chup=tran.png   # chụp giữa trận
```

**Kịch bản trận** (`sc/plot/drama_*.lua`) chạy được — `lua/kich_ban.lua` là
`DFDramaScriptSystem` giả. Kịch bản gốc là một **coroutine**: đăng ký bằng
`AddMoitor`/`SetGameStartMoitor`, thân hàm gọi `g_DramaSystem:...` rồi
`coroutine.yield()` chờ. Bộ điều khiển của ta chạy coroutine đó và đánh thức
lại theo điều kiện "đi tiếp": hết giờ chờ (`DelayTimeThenGoNext`), qua thoại
(`ShowDialogue`), gặp quân (`EncounterArmyBegin`), nhận thông báo trận
(`Notification_*`), tướng thức tỉnh xong (`HeroWakeEnd`). Ghi lại chuỗi thoại
và mọi lời gọi. Chạy bằng cờ `G_KICHBAN` (mặc định TẮT để `--kiem` giữ 22/22);
đo bằng `do_chien_dich.gd --kichban` — nạp `drama_L_N_01_01.lua` và diễn trọn
20 câu thoại hướng dẫn tân thủ (giới thiệu → mở khoá đao binh → Lăng Thống →
Lữ Bố → Triệu Vân) không lỗi.

**Đồng minh của kịch bản NHẬP TRẬN thật, và ải 1 thắng được.** Kịch bản gốc
cho quân tiếp viện vào trận (`CreateNpcAndMoveTo`/`CreateNpcWithAppear` tạo,
`TakeUnitJoinBattle` cho đánh) và kéo boss ra khỏi giao tranh
(`MakeUnitToPlotSprite`). Lớp giả nay làm THẬT các lời gọi đó:
- `CreateNpc*` ghi đặc tả (armature, phe, `dataKey` "NpcID-Level");
- `TakeUnitJoinBattle` lấy **chỉ số thật** từ `G_ConfigManager:GetNpcConfigWithNpcId`
  rồi thêm đơn vị vào trận có hình (`san_tran_ve.dua_dong_minh`);
- `MakeUnitToPlotSprite` rút đơn vị khớp tên armature khỏi trận
  (`xoa_theo_hinh`) — Lữ Bố bị kéo ra như bản gốc cho hắn bỏ chạy.

Kết quả đo (`do_chien_dich.gd --kichban`): Đao Binh, Lăng Thống, Triệu Vân
nhập trận; Lữ Bố bị rút; người chơi đưa lính ra — **ải 1 thắng** (`thang=true`,
dọn sạch địch). Đúng cách bản gốc, KHÔNG chỉnh số liệu.

**Tuyệt chiêu kịch bản, vào-trận-từ-mép, camera lia** — cũng làm thật:
- `SetRoleChangeFight(sprite, phe, form, "Wake"/"Talent")` → `tuyet_chieu`: tìm
  đơn vị khớp armature, phát động tác, và nếu là tuyệt chiêu BÊN TA thì đánh
  AoE lên mọi địch (Triệu Vân "thất tiến thất xuất"). **Sát thương mỗi đòn dùng
  chỉ số + công thức THẬT** (`Fighter.strike` qua `Harm`); chỉ *số đòn* (3) và
  việc đánh khắp là ĐẶT (hiệu ứng thật trong C++ `CDFSpriteFight*Wake`).
- Quân tiếp viện vào trận từ MÉP (đồng minh từ trái, địch từ phải) rồi tự tiến
  vào — đúng ý `CreateNpcAndMoveTo` "đi vào".
- `CameraMoveBy(hướng, giây)` → `lia_camera`: dừng bám quân rồi lia camera nửa
  màn (cảnh điện ảnh); `StartGame` cho bám lại. Biên độ là ĐẶT.
- Khớp boss: `MakeUnitToPlotSprite` khớp **chính xác tên armature trước**, không
  có mới đến chứa-chuỗi — tránh "LvBu" trùng "LvBuEvil".

ĐẶT, không phải bản gốc: `SetCameraScale` (thu phóng) vẫn ghi-lại vì đổi tỉ lệ
làm lệch toạ độ chạm; di chuyển/đường đi NPC trong cảnh và các hiệu ứng điện
ảnh (điện ảnh thanh, hố đen…) chỉ ghi lại; lớp phủ hướng dẫn `g_CGuideLogical`
bịt no-op; thoại tự đi tiếp sau 0,4 s.

**Chơi thật thì kịch bản CHẠY.** `--xem` (và `--chup`) bật cờ `G_KICHBAN`, nên
chơi tay là diễn trọn hướng dẫn tân thủ: mở khoá binh chủng, đồng minh đi vào,
Lữ Bố bị rút, và ải 1 thắng được. `--kiem` KHÔNG bật (giữ 22/22, vì kịch bản ẩn
nút / dừng trận, đè lên phép kiểm đưa lính).

`OnKillEnemy` (`szId`): với **ải thường** đây là no-op — `ChapterBattle` (màn
thường) không có `OnKill`; danh sách giết (`KillIdList`) chỉ dùng ở chế độ vô
tận (SCS) và Hoàng Cân xâm lược (HJRQ), chưa chạy. Nên không cần cho vòng chơi
hiện tại.

Chưa có: minimap, camera lia tới địch (`fLoaferFocus*`), chậm hình khi qua ải
(`fTimeScaleForStageClear`), `SetCameraScale`, và đường đi/hiệu ứng điện ảnh
của dàn cảnh.

**Đưa lính ra trận.** Nút binh chủng `btnBattlefieldArmy` là lớp C++ mang tên
node (`libgame.so` có `setDispatchID` / `setLeaderShipForBuild` / `dispatch` /
`attachedDispatch` cạnh nhau); trong `.xgg` nó KHÔNG có tên chạm — bản gốc để
engine bắt chạm trên nút. `lua/san_tran.lua` gắn bộ hàm riêng cho nó (bản sao
của `createArmyIcons` giữ tên node vì `_copy` chép meta) và tên chạm `DuaLinh`
khi engine nhận `setDispatchID`. Bấm nút hay `CUIGame:TouchArrmy(n)` (đường tự
đánh / hướng dẫn) đều vào `dispatch`: đủ thống soái thì trừ, thả một toán
`MaxUnit` người dựng từ chỉ số thật của `Troop_<n>`, báo `NoticeDispatch` /
`updateLeaderShip`; thống soái hồi theo `runLeaderShipTimer` /
`updateLeaderShip` / `updateMaxLeaderShip` (tên đo trong `libgame.so`). Số lấy
từ dữ liệu bản gốc: `L_N_01_01` có thống soái 6, `LeaderShipResume` 5;
`Troop_1` (`DefenderN`, HP 1.000) tốn 3, mỗi toán 4 người. ĐẶT, chưa đo: vào
trận đầy thống soái; hồi 1 điểm sau mỗi `LeaderShipResume` giây; toán lính
xuất hiện ở mép trái sân. "Binh lực 20/20" chưa làm — không có số trong dữ
liệu. Kiểm (`--kiem`): hai lần `TouchArrmy(1)` thả 2 × 4 người (quân 11 → 19),
thống soái 6 → 0, lần ba bị từ chối; bấm THẬT vào tâm nút (qua `touch_at`) sau
khi hồi đủ 3 thì thêm 4 người, trừ 3.

**Kỹ năng thức tỉnh.** Luật của từng kỹ năng nằm trong C++ (`libgame.so` có
hàng loạt lớp hành vi `CDFSpriteFight*Wake`, nút là `CDFWakeButton`); dữ liệu
chỉ mang `WakeSkill`, `AngerRecovery`, `AttackAwakening`, `GethitAwakening` và
`Skills` (với `Hero_25`: `JiJiaoZhiShi`, `SkillInjuryRates` 1,4). Phần làm
theo đúng bản gốc là DÒNG ĐIỀU KHIỂN: nút là bản sao của `spBattleFieldHeroItem`
(`CUIGame:SetSkillIcons`), không có tên chạm trong `.xgg` — engine bắt chạm;
`lua/san_tran.lua` gọi `InitSkillButton` cho từng tướng, đổi trạng thái nút
bằng `SetSkillButtonLighten` (đầy nộ) / `SetSkillButtonNormal` /
`SetSkillButtonGray` (tên đo trong `libgame.so`, là hàm Lua của `CUIGame`), gắn
tên chạm `ThucTinh`, báo `NoticeCastSkill`; `setWaking()` (nút `btnWake` cũ)
và `setAutoWake` (tự đánh) cũng vào đó. ĐẶT: nộ tích theo mô hình của ta
(`AngerRecovery` mỗi đòn, đầy ở 100); bấm nút thì đòn KẾ TIẾP của tướng là đòn
kỹ năng (công × `SkillInjuryRates`) và armature phát động tác `Wake`
(`Combat.Fighter.giu_no` / `ep_no`, mặc định tắt nên mô hình cũ và `sim/`
không đổi — `verify_battle.gd` 12/12). Ở `L_N_01_01`, với mô hình này, tướng ta
chết trước khi đủ 4 đòn để đầy nộ, nên `--kiem` đặt nộ bằng móc
`_dat_no` (chỉ để kiểm) lúc tướng còn sống rồi bấm THẬT vào nút: thấy đủ chuỗi
`InitSkillButton → SetSkillButtonGray → SetSkillButtonLighten → NoticeCastSkill
→ đòn kỹ năng → SetSkillButtonNormal → SetSkillButtonGray`.

**Đổi ảnh theo khung (armature).** Bản ghi khung 80 byte của `.xml` có hai
trường trước đây ghi nhầm là "luôn 0" (`brave-cross/work/anim.py`):
`+0x2C` là **chỉ số ảnh** đang hiện của xương (vị trí trong bảng xương → ảnh,
−1 = ẩn), `+0x40` là **số khung** keyframe đó giữ. Đo trên 418 file / 641.538
keyframe: chỉ số nằm trong [−1, số ảnh − 1] ở 641.525 keyframe (số ảnh lấy
từ bảng riêng, không phải từ khung); tổng số khung giữ = độ dài động tác ở
95.416 / 95.431 xương. Mọi chỗ lệch nằm ở `BingYing.xml` và
`XSJiYouHeTiJi.xml` (bố cục khung khác, chưa giải) — ở đó `SngRig` giữ cách
cũ. `SngRig` nay dựng mỗi xương thành một khung chứa MỌI ảnh / rig lồng của
nó, đổi ảnh bằng một đường gọi `_doi_anh` cho mỗi xương, và đặt keyframe theo
số khung giữ (trước đây mỗi keyframe cách đúng 1 khung). Kiểm:
`tools/verify.gd` (3.138 đạt), trong đó `eff010` của `Player000M03W/Fight`
phải ẩn → hiện ảnh 0 ở khung 8 → ẩn ở khung 12, đúng số trong file.

**Trang phục dùng động tác của nhóm gốc.** `Defender_VampirE`,
`Archer_VampirE` là BỘ ẢNH cho cùng bộ xương, không có nhóm động tác riêng;
`SngRig` trước đây trả nhóm rỗng, nên lính trang phục trên sân không có động
tác nào và mọi xương — cả xương hiệu ứng — đứng im ở ảnh đầu (thành một mảng
vuốt đỏ bám theo cả trận). Nay lấy nhóm có tên là tiền tố dài nhất. Đo trên
cả `assets_ref`: 76 bộ phận cấp cao không có nhóm riêng, 75 có nhóm gốc là
tiền tố, xương trùng trung vị 100%.

Hai chỗ tìm ra khi dựng hình:
* **Cảnh 40×40.** `g_GameUIScene` (cảnh Battle) ghi cỡ 40×40 trong file; con
  trực tiếp của cảnh đặt theo chiều cao đó, nên `g_BattleFieldLayer` đứng ở MÉP
  TRÊN và cả sân trận nằm ngoài khung. `_load_xgg` nay đặt lại con của cảnh theo
  chiều cao thật (Cocos đặt con theo góc dưới-trái của cha).
* **Lớp đen `g_BlackEffectLayer`** (2000×1000, đen, độ mờ 255, đang hiện) phủ
  kín màn. Lua của bản gốc không bao giờ tắt nó (dòng tắt duy nhất,
  `CUIGame.lua:1148`, nằm trong khối đã chú thích bỏ); tên nó có trong
  `libgame.so` và `g_BattleField` có `SetLayerDark` — nên SUY RA là việc của
  engine: sân dựng thì tắt, `SetLayerDark(b)` bật/tắt.
* `addChild(con, z)` từng đặt `z_index` — bản gốc truyền tới 99999, Godot chỉ
  nhận ±4096. Nay xếp lại anh em như `setZOrder`.

**Những chỗ đã mất công tìm ra:**
* **Tag ghép nhầm khi anh em trùng khít.** Năm con của `lSmallBackgroup`
  (`UI_MessageBox`) cùng ở (230, 155) 500×330; `emu_join.py` so vị trí nên
  gán nhầm `lMessageBox` tag 4 thay vì 1, và MỌI hộp thoại hỏi chết ở
  `CMessageBox.lua:79`. Nay phân xử bằng cây con đo được (`diem_cay_con`).
* **`CCCallFunc` nuốt lỗi** (`actions.lua`): hoạt cảnh mở hộp thoại kết thúc
  bằng `CCCallFunc(OnShowAnimationFinish)`, và hàm đó chỉ `PopAnimation` ở cuối.
  Lỗi ở giữa bị nuốt thì hàng đợi hoạt cảnh kẹt mãi — mọi `Show` sau im lặng
  không mở. Nay lỗi ghi vào `loi_hen`.
* **`G_DEBUG_TEST_MODE`** (`game.lua:363`) chưa được chạy lại nên thành bóng
  (đúng): `CUIGame.lua:1276` hẹn `GameFinish(true)` sau 2 giây và trận nào
  cũng thắng. Nay `khoi_dong_game` chạy lại dòng đó.
* Hàm/lớp engine thêm vào, đều có tên trong `libgame.so`:
  `spriteWithSpriteFrameName`, `LGG_GetUtf8WordLen` (cách đếm của bản gốc CHƯA
  giải — đếm ký tự UTF-8, chỉ ảnh hưởng tỉ lệ thu nhỏ tên dài), `CCLayer`,
  `CCLayerColorRoundRect` (thứ tự đối số theo `CCLayerColor` của Cocos, suy từ
  tên), `TableView:cellAtIndex`.
* Còn thiếu, không chặn: `toAnimationName` (có trong `libgame.so`, dùng lập
  danh sách armature nạp trước; cách đổi tên chưa rõ), `ClientReachAchieve`,
  `G_MysteriousStoreLogic.ClientRefresh`.

#### Trạng thái người chơi — những chỗ đã mất công tìm ra

* **Bóng khác `nil`, nên mọi `if X == nil` đi nhánh sai.** Ba lớp sửa:
  * biến mã gốc **đã từng gán** (kể cả gán `nil`) thì vắng mặt là `nil` —
    `AchieveCheckLogic.lua:1010` quên `local` rồi kiểm `nCount == nil`;
  * **144 biến chắc chắn `nil`**: mã gốc kiểm nil nhưng không ai đặt được
    (không trong Lua, không trong `libgame.so` lẫn `classes.dex`) —
    `import_lua.py` đo lại mỗi lần, ghi `data_ref/bien_nil.json`. Gồm
    `ISSERVER` (mã dùng chung đi nhánh **máy chủ**), `G_DataCenterManager`,
    và tên node `.xgg` (nil tới khi nạp bố cục);
  * tên **có** trong `libgame.so` thì engine đăng ký thật — phải làm thật
    (`sngUtil_getIDFV`, `sngHttpRequestWithData`), không ép nil được.
* **`sc/game.lua` chạy 13 bước khởi tạo sau `G_ConfigManager:Init`** mà ta
  không chạy file đó — `bootstrap.khoi_dong_game()` làm lại đúng thứ tự
  (`XGEvent:Init` là nơi duy nhất đặt `XGEvent.m_GameParams`…). Bỏ qua âm
  thanh, tải xuống, HTTP và cảnh Logo.
* **LuaXML có hai nửa.** Nửa Lua là `sc/system/xml.lua` của bản gốc; nửa C
  (`load`, `eval`, `encode`, `_save`) là `lua/luaxml.lua`, phải đặt thành
  `xml` **trước** khi nạp bản kê khai để `module("xml")` dùng lại bảng đó.
* **Tên trường phải lấy từ chỗ client ĐỌC**, không đoán: tên nhân vật là
  `CharacterName`; phản hồi đăng nhập là `uid` / `session` viết thường; danh
  sách máy chủ là `RecomendList`; hàm nhận danh sách hoạt động tên sai chính
  tả `OnGetAcvitityList`.
* **`io.open` của LuaJIT trên Windows không mở được đường dẫn ngoài ASCII** —
  `user://` của dự án có dấu gạch dài. Bọc lại, đi qua `FileAccess` khi cần.
* **Người chơi mới tinh thật ra vào ải hướng dẫn**, không vào `Main`
  (`CUILogin2.lua:3714`). `vao_main` bật công tắc có sẵn của bản gốc
  (`CloseGuide`, `game.lua:457`) để vào thẳng `Main`.

## Khung giao diện (các màn viết tay)

Mục này nói về mấy màn **viết tay bằng GDScript** (`ui/equip.tscn`,
`ui/tasks.tscn`, `battle/`) — làm trước khi có hướng chạy thẳng mã Lua ở trên.
Chúng vẫn chạy và vẫn có bộ kiểm riêng, nhưng màn mới thì không đi đường này
nữa.

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
