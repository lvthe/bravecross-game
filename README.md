# bravecross-game

Project Godot 4.7 để làm game mới, dùng lại **bộ xương và hoạt ảnh** đã giải
được từ bản gốc (xem repo `brave-cross`).

Phần đã xong ở đây là **bộ nạp nhân vật**: đọc thẳng dữ liệu do
`work/export.py` xuất ra và dựng thành cây `Node2D` + `AnimationPlayer` chạy
được ngay — không phải dựng tay 397 scene.

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

## Nền cảnh

Mỗi chương một nền, lấy từ bản gốc (`work/scenes.py` xuất ra 24 ảnh trên 9
cảnh). Khung hình để **960×640** — đúng cỡ thiết kế của bản gốc, biết được từ
tên file bố cục của nó: `BattleField_<cảnh>_960_640.xgg`.

Bản gốc còn ghép thêm ~45 mảnh trang trí lên nền, mô tả trong chính file bố cục
đó. **Chưa dựng lại được**: texture của atlas `Scene_<cảnh>.plist` không có
trong APK lẫn OBB — nó được tải về lúc chạy từ máy chủ vá.

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

### Bản diễn ở client KHÔNG phải mô hình của máy chủ

Máy chủ ghép từng cặp theo hàng rồi đấu tay đôi. Màn trận ở client có di
chuyển, chọn mục tiêu, tính theo thời gian thực. Hai mô hình khác nhau, nên
**bản diễn có thể cho ra kết quả khác với phán xử của máy chủ** — khi đó màn
hình ghi rõ "bản diễn ra khác". Cái được ghi vào sổ luôn là của máy chủ.

Muốn khớp hẳn thì phải cho máy chủ chạy đúng mô hình có vị trí, và hai bên dùng
chung một bộ sinh số — chưa làm.

### Chỗ chưa làm

Khoá máy chủ vẫn là `defaultkey`. Trận đấu chưa có người thật đối đầu — đội
địch do máy chủ bốc từ bảng tướng, không phải đội của người chơi khác.

## Bản quyền

`assets_ref/` (art) và `data_ref/` (bảng số) đều lấy từ bản gốc, **có bản
quyền**. Cả hai bị `.gitignore` và chỉ dùng làm placeholder trong lúc dev. Phải thay hết bằng art tự làm trước
khi phát hành. Tạo lại bằng:

```bash
python work/export.py --all --out <thư mục>
```

rồi chép các thư mục nhân vật cần dùng vào `assets_ref/`. Nền cảnh:

```bash
python work/scenes.py --all --out <bravecross-game>/assets_ref/scenes
```

Và sinh lại bảng số:

```bash
python sim/export_stats.py --battles 4000
```
