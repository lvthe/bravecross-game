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

**Đã có (6 handler / 12 hàm):**

- [x] `login` — đăng nhập, người chơi mới tinh (từ mục `*Reset` của cấu hình)
- [x] `chapter` — chiến dịch: bắt đầu ải, thắng, thua, lên cấp, mở ải sau
- [x] `achieve` — thành tựu
- [x] `statewar` — quốc chiến (chặn, để không nuốt cú bấm)
- [x] `mysterious` — cửa hàng bí ẩn
- [x] `lottery` — chiêu mộ tướng
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
- [ ] Hang / ma khu (1 màn)
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
- [~] Chỗ đứng và tốc độ quân — **của ta**, không phải của bản gốc
- [~] Cách hồi thống soái — ĐẶT
- [~] Hiệu ứng kỹ năng thức tỉnh — ĐẶT; luật thật nằm trong `CDFSpriteFight*Wake`
- [~] Ánh xạ trường sang bên đánh/chịu — ĐẶT, chưa kiểm byte-exact
- [~] `SetCameraScale`, đường đi điện ảnh — ĐẶT
- [ ] Minimap
- [ ] Trận PvP, đấu trường, quốc chiến (cần mục 4)

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
