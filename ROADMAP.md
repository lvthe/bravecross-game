# Lộ trình dựng lại Búa Tạ

Danh sách mọi phần cần làm để ra được game, kèm chỗ đang đứng. Cập nhật
2026-09-16.

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
| Màn hình mở được | **291–292 / 353** | `tools/quet_show.gd` |
| Hàm máy chủ `Client*` đã có bản offline | **13 / 411** | đếm `sc/` vs `offline/handlers` |
| Lệnh kịch bản `g_DramaSystem` đã có | **60 / 60** | đối chiếu `sc/plot/drama_*.lua` |
| Định nghĩa hạt đã dịch | **33 / 33** (87 node, 7 định nghĩa được dùng) | `tools/verify_hat.gd` |
| Bộ kiểm | **33**, xanh hết | `tools/check.py` |

> Con số màn hình **dao động ±3 giữa các lần chạy** (đo 3 lần trong ngày:
> 258, 259, 260; hôm sau: 258, 257; hôm nay, **sáu lần chạy cùng một mã**:
> mở được 255, 256, 257, 257, 258, 258 — hỏng 75, 74, 73, 74, 73, 72). Bộ quét
> mở 353 hộp thoại liên tiếp trong một máy ảo dùng chung trạng thái, nên đừng
> đọc chênh lệch một vài màn là tiến bộ — muốn biết một sửa đổi có ăn thua
> không thì **so danh sách tên màn, không so con số tổng**. Hai lần đã gặp đúng
> bẫy này: (1) một sửa đổi làm số tổng đổi ±3 mà **chỉ một** trong ba màn đổi
> chỗ là nhờ nó; (2) lần gỡ `scrollTo`, số hỏng đứng yên ở 73 ở cả hai bản
> nhưng **một màn ra, một màn vào** — màn vào (`MoreGoldDialog`) thiếu `data`
> của người gọi và có mặt ở cả hai bản.
>
> Lần gần nhất con số **vượt hẳn dải dao động**, nên đọc được như tiến bộ thật:
> **264–265 / 23 / 65–66** (353 màn) sau khi ghép đường chỉ số con, sửa `xoay`
> và đo thẳng các neo bị chặn — so với dải 255–258 ở trên là +6 đến +10, và
> **cả ba lượt đều kiểm bằng danh sách tên màn** chứ không chỉ bằng tổng: lượt
> ghép đổi 5 màn và cả 5 **mở được ở cả hai lần chạy lại**; lượt `xoay` không
> nhằm vào màn nào đang hỏng (xem mục 8, việc 2); lượt `--neo` nhắm đúng
> `CUIBarracksMain` và đo **theo từng màn** mới thấy (`Show` lỗi → `Show: ok`).
>
> Bẫy này gặp lần thứ ba khi sửa `getChildByStringTag` (xem mục 4): tổng chỉ đổi
> 1 màn (258→259), nhưng **danh sách tên** đổi 5 chỗ — và **hai lần chạy cùng bản
> đã sửa đã khác nhau 2 màn**, cho thấy 4 trong 5 chỗ đó chỉ là dao động. Nếu chỉ
> nhìn tổng thì đã không phân biệt nổi cái nào là công của mình.
>
> Lần đo gần nhất (2026-09-16), **ba lần chạy cùng một bản**: mở được **269, 270,
> 268** — im **23** ở cả ba (con số này đòi tham số nên không dao động), hỏng
> **61, 60, 62**. So danh sách TÊN thì ba lượt chỉ khác nhau đúng ba màn
> (`CUICharacterDress`, `MoreGoldDialog`, `EquipmentInfoDialog`) — đều là màn đã
> biết dao động, `MoreGoldDialog` đã ghi ở trên. Nên đọc là **268–270 / 23 /
> 60–62**, và dải này **vượt hẳn** 264–265 ghi trước đó. Không dám nhận trọn
> phần chênh là công của lượt nào: giữa hai lần đo có nhiều thay đổi, và lần đo
> cũ **không chạy lại được** trên bản hiện tại để đối chiếu.
>
> Cùng ngày, `quet_show.gd` đã **chết hẳn bằng signal 11** (segfault) ở một lượt
> chạy — xem mục 6, chỗ `AmThanh._thu_lai`. Nay cùng lệnh đó chạy trọn, exit 0.

> **Và đây là lần thứ tư con số nhảy vì THƯỚC ĐO đổi, không phải vì tiến bộ —
> lần này là +23 màn.** Bộ quét cũ không **nhả khung** giữa các màn, nên
> `onVisible` không bao giờ chạy: `CUIManager` chỉ gọi nó từ
> `OnShowAnimationFinish`, mà cái đó được xếp qua một
> `S_CCSequence(S_CCDelayTime, S_CCCallFunc)` chạy trên `rootUI`
> (`CUIDialogAnimation.lua:86-95`). Đo thẳng trên `CUIQuest`: không nhả khung ra
> `hoi=71 hut=0, IsUiVisible=false`; nhả **30 × 0,05 giây** ra `hoi=819 hut=35,
> IsUiVisible=true`. Nghĩa là màn **có mở**, chỉ là phép đếm cũ đọc cờ trước khi
> cờ được đặt. Nay `_MOT` nhả khung trước khi đọc cờ:
> **im 23 → 0, mở được 268–270 → 291–292** — chênh đúng bằng số màn bị xếp nhầm
> vào "im". **Không màn nào mới mở ra; chỉ là chúng thôi bị gọi là im.**
>
> Cùng lượt sửa thước đo ấy, `quet_show.gd` in thêm **bảng "API Cocos CHUA LAM"**
> cho trọn 353 màn, **trừ đi phần dùng lúc đăng nhập** (đọc bộ đếm hai lần rồi
> trừ nhau) — đây là danh sách việc thật của lớp giả lập, thay cho các con số
> vụn vặt đo được ở từng màn một trước đó.

Con số 13/411 là thước đo thật của phần còn lại: **giao diện gần xong, máy
chủ mới làm được phần đi chiến dịch.** Đếm theo "có hành vi thật", nên 10 RPC
của ải vô tận **không** được tính: chúng đăng ký để client khỏi treo ở lớp
"đang tải" và ghi lý do chưa làm, chứ không đổi trạng thái nào.

---

## 1. Lấy dữ liệu ra khỏi bản gốc

- [x] Giải mã `.xgg` (bố cục màn hình) — 296 màn, 33.472 node
- [x] Giải `.pkm` → PNG (ETC1 + kênh alpha nửa dưới) — 7.262 ảnh giao diện
- [x] Bộ xương + hoạt ảnh (`sngXml`) — 397 atlas, 7.999 động tác
- [x] 104 bảng cấu hình, 16.894 dòng chữ tiếng Việt
- [x] Mã nguồn Lua — 973 file / 518.585 dòng, quy về UTF-8
- [x] Tag node đo từ bản gốc chạy trong máy ảo Android — **27.887/33.472 node
      (83,3%) có tag**; xét theo lượt hỏi lúc chạy thì 9.786/11.448 lượt
      `getChildByTag` trả về node (85,5%). Hai số khác nhau và đều đúng: số đầu
      là độ phủ trên bố cục, số sau là tỉ lệ trúng lúc chạy (màn mở được càng
      nhiều thì mã đi càng sâu, mẫu số càng lớn). Đếm độc lập bằng
      `work/kiem_tag.py`. Số cuối này gồm **ba lượt**: áp đường ghép theo CHỈ SỐ
      CON (58,1% → 78,6%), sửa `xoay` và hợp ba nhánh đo lại 6 màn còn neo chưa
      tới (78,6% → 83,3%), rồi đo thẳng các neo bị chặn bằng `--neo` (→ 83,3%,
      +11 node nhưng **mở được một màn đang hỏng**) — xem mục 2 dưới
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
- [x] **Widget bảng** (`G_CTableViewMgr` của `lua/cocos.lua`): dựng ô, cắt phần
      tràn, `reloadData`, `cellAtIndex`, và **`scrollTo`** — thứ làm
      `CUIInfiniteLevelFirstPassRewards.lua:75` vỡ. Tỉ lệ cuộn tính theo
      **quãng cuộn được** (`cao nội dung − cao khung`), 0 là mép trên — đúng
      như chú thích của chính bản gốc (`CUISign.lua:905`) và khớp số học của
      `CUIAssist.scrollToItem` (`CUIAssist.lua:1455`). Đối số thứ hai là **có
      chạy hiệu ứng hay không**, không phải "có cuộn hay không"
      (`CUIGuildTableView:ScrollTo` truyền `false` mà vẫn là hàm để nhảy tới
      một mục — `CUISBHeroList.lua:119`); lớp giả lập đặt thẳng vì chưa có hệ
      chạy hiệu ứng, trạng thái cuối y hệt. **Đo** (đặt tiến độ giả
      `BestProsees = 25`, 20 tầng đầu đã nhận → tỉ lệ 20/250 = 0.08): 250 ô,
      nội dung cao 23.750, khung cao 440 → lệch 1.864,8 pixel, và ô 21 (tầng
      chưa nhận thưởng đầu tiên — đúng chỗ `skipToLastUnGet` nhắm tới) nằm ở
      y = 35,2 trong khung. Phép đo này **bắt được một lỗi của chính bản vá**:
      lần đầu tôi lưu thẳng `percent` vào chỗ đáng ra là số pixel, ra lệch
      0,08 thay vì 1.864,8 — nhìn "không crash" thì không thấy được
- [x] Bóng: mọi biến toàn cục chưa làm đều ghi lại lượt gọi
- [?] `CCLayerColorRoundRect` có bỏ qua neo không — chưa đo
- [x] Cách trộn màu của armature (đốm xanh ở Main) — **xong**: cách trộn nằm
      trong **từng khung**, tên gọi ở `+0x38` của bản ghi khung; `'screen'` =
      trộn CỘNG, `'multiply'` = `GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA`, còn lại
      (kể cả tên lạ) = trộn thường. Giải bằng cả hai đường: đo trên máy ảo
      (`work/emu_dom.py`, 9/9 biến thể) và đọc hàm phân nhánh trong `libgame.so`
      ở `0x25d476..0x25d4ce`. `SngRig` nay đặt `BLEND_MODE_ADD` theo khung;
      A/B trên ảnh `Main` đổi 6.493 điểm ảnh (trước là 0)

## 3. Giao diện

- [x] Chuỗi Login → chọn máy chủ → vào game → cảnh `Main`
- [x] Vẽ `Main`: trời, thành phố, nhà (armature), dải nút, biển tên, số người chơi
- [x] Mở màn hình bằng đúng đường của bản gốc: `<quản lý>:Show(<tên>)`
- [x] Công cụ xem màn: `tools/xem_man.tscn`
- [ ] **94 màn chưa mở được** — 71 hỏng (xem mục 4), 23 đòi tham số
- [x] Kéo cuộn lớp thành phố ở `Main` (`lua/cuon.lua` — lớp `CCScrollLayer` của
      engine; số đo ở mục 8) — nhờ đó với tới được `btnMainEvilCastle` (ải vô tận)
- [x] `sngFixInfoReflash` — **xong**: công thức + tám số đã đo (mục 9 của "Bảng
      hàm thiếu"), dữ liệu xuất vào meta `fix`, và nó chạy do **chính bốn đường
      gọi của bản gốc** (`SetWHScaleToWinSize` ← `PreLoadFinish`/`OnLoadNextScene`,
      `CUIPublic:onInit`, `FBHeroPK`, `CUITimeHero`) chứ không reflash cả cây lúc
      dựng bố cục. Đo trên Login → `Main`: **gọi 5 lần, đổi chỗ 3 node**. Còn
      **một** việc con: đổi `stretch/aspect` sang `expand` (mục 9) — đến lúc ấy
      node neo phải trong `lMainBtnLayer` / `lDialogControlPanel` mới chạy ra mép
      trên cửa sổ khác tỉ lệ
- [ ] Lớp phủ hướng dẫn `g_CGuideLogical`

### Ô chữ của nhãn: ba trường riêng, không phải kích thước node

`Label` của bản gốc giữ **ba thứ khác nhau**, và lẫn chúng là lỗi im lặng — màn
vẫn mở, chỉ có chữ đứng sai chỗ hoặc nhãn biến mất:

| trường | ai ghi | ai đọc |
|---|---|---|
| **ô** `+0x2c4/+0x2c8` (số nguyên; bản float `+0x2bc/+0x2c0`) | `setDimensions` (`0x2caab5` → `0x4f6750`) và bộ nạp `.xgg` | `getDimensions` |
| **cặp trả lời** `+0x5c/+0x60` | `setContentSize` (`0x49bdcd`, qua slot vtable `+0xb0`) và lần bố cục lại | `getContentSize` |
| **cờ autoFix** `+0x21c` | chỉ `autoFixSize` | `autoFixSize` lần sau |

Cờ "bẩn" `+0x20d` có **đúng ba** chỗ ghi, đọc từ mã máy (`binder.py` +
`findstr.dis_all`), và cả ba đều khác nhau:

* `setString` (`0x2cae04` → thợ `0x4f77f4`): `strb.w r3(=1),[r4,#0x20d]` ở
  `0x4f783a`, **không có so sánh nào trước đó** — bật vô điều kiện.
* `setDimensions` (thợ `0x4f6750`): thoát sớm (`cmp` + `bx lr`) khi ô **không
  đổi**; còn lại ghi ô, bản float, `+0x268/+0x26c` rồi mới bật cờ. **Không hề
  chạm `+0x21c`** — nên cờ autoFix **sống qua** một lần `setDimensions` sau đó.
* `setContentSize`: **không** bật cờ, và **không** xoá cờ.

Luật đã cài trong `lua/cocos.lua`, đo từ bản gốc chạy trên máy ảo
(`brave-cross/work/emu_nhan.py`, bốn lượt, đọc qua logcat):

* `x` = **bề rộng ô** khi ô rộng > 0 và chữ không rộng hơn; ngược lại là bề rộng
  chữ. `y` = **chiều cao ô** khi ô cao > 0 **và chữ khác rỗng**; ngược lại là
  chiều cao chữ. Chữ **rỗng** trong ô 250×40 → `(250, 0)` (đo: `250,0`).
* Nhãn **tạo lúc chạy** (`Label:new()` + `createWithTTF`) có **ô = (0, 0)** —
  `getDimensions` trả `0,0` nhưng `getContentSize` trả `1128,24`. Lấy kích thước
  node làm ô ở đây là sai (đó là số **cũ**, không phải ô).
* `autoFixSize`: `scale = min(tỉ lệ ngang, tỉ lệ doc)`, mỗi tỉ lệ = `1.0` khi vừa
  ô. Ô cao **0** ⇒ tỉ lệ dọc 0 ⇒ `scale = 0` ⇒ **nhãn biến mất** — quirk thật của
  bản gốc (đo `0` ba lần), không phải lỗi của ta.
* Chiều cao một dòng của bản gốc = **1,2 × cỡ chữ** (20 → 24; đo cả 12 và 40).

Hai lỗi thật đã bắt được nhờ mô hình này, cả hai đều **im lặng**:

1. Cờ "bẩn" của ta cũng bị gác theo `gd.size`, nên `setDimensions(w, 0)` rồi
   `setString` trả **số cũ** (nhãn 200×0 đọc ra cao của chữ **trước đó**). Bản
   gốc bật cờ vô điều kiện trong `setString`, nên bỏ hẳn phép gác.
2. `setContentSize` của ta xoá cờ "bẩn", nên lần đọc **đầu** trả cặp vừa ghi;
   bản gốc **không** xoá, nên lần đọc đầu vẫn bố cục lại (`CUIAnniversaryHeaven.lua:277-284`
   gọi `setString("")` rồi `setContentSize(0, 0)` — đo được `250,0` chứ không
   phải `0,0`; lần thứ hai, khi đã sạch, mới ra `0,0`).

Chỗ dùng thật đã đối chiếu: `CUIGuildWar.lua:612-617` (đọc `getContentSize` rồi
lấy bề rộng đó làm ô cho đoạn sau — trả **ô** thì là điểm bất động, trả dòng dài
nhất thì thắt dần), `CUIToolTips.lua:200-220`, `CUIChatting.lua:798-800`.

**Khác bản gốc, ghi rõ chứ không giả vờ giống:** font của ta không phải tahoma
(cùng cỡ 20: câu dài của ta **1211×28**, bản gốc **1128×24**; `"ngan"`: ta
**49**, gốc **44**; 34 chữ `'A'`: ta **450**, gốc **408**), nên chỉ **luật** so
được, không so điểm ảnh. Và bộ nạp `.xgg` của ta chỉ bật tự xuống dòng khi ô cao
≥ 45, còn bộ ngắt dòng của bản gốc có thể để một dòng **dài hơn ô 3 %**
(đo `103` trong ô `100`) — Godot không bao giờ để dòng vượt ô, nên chỗ này ta ra
`100` và bộ kiểm ghi nhận khác biệt thay vì đòi bằng nhau.

Khoá lại bằng `tools/verify_dimensions.gd` (**25 phép kiểm**, chạy đúng chuỗi
bước của `emu_nhan.py`, số mong đợi tính **thẳng từ API font của Godot** chứ
không qua `cocos.lua`). Bộ này đã qua **phép thử phá**: bỏ hai luật rơi-về-chữ
trong `tinh_o_chu` thì nó báo **10 hỏng** đúng ở các bước liên quan, rồi khôi
phục mã là xanh lại — nên nó không phải bộ kiểm rỗng.

## 4. Máy chủ offline — phần dài nhất còn lại

Máy chủ cũ đã chết. Mỗi tính năng cần một handler đọc luật có sẵn trong
`sc/share/` rồi trả kết quả về, không bịa số.

**Đã có (8 handler):**

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
- [~] `endless` — Ải vô tận: **hai màn hết vỡ vì dữ liệu** (xem mục "Chưa có"
      ngay dưới), và bảng xếp hạng trả lời trung thực là **rỗng** — offline chỉ
      có một người chơi, cùng loại với `ClientGetGuildInfo`. 10 RPC còn lại của
      họ này **đăng ký nhưng cố ý không làm gì** ngoài dọn lớp "đang tải" và ghi
      lý do: nửa máy chủ của tính năng **không được ship** (`EndlessChapterLogic`
      557 dòng chỉ có hàm ĐỌC, không hàm nào đổi trạng thái người chơi). Mỗi lý do
      ghi tại chỗ trong `handlers/endless.lua`
- [x] Bảng người chơi không có mục `<bảng>Reset` thì lấy hình dạng từ
      `InitData()` của chính client (`GamePet`, `GameUserStarSoul`) — trước đây
      để `{}` rỗng, và rỗng làm client chết ở dòng sau chứ không báo gì
- [x] `OfflineStore.TU_DUNG` — danh sách bảng mà client **tự dựng** hình dạng,
      nhưng chỉ khi bảng là `nil`. Có những bảng `{}` **không** vô hại mà còn
      độc: `CavernDataManager:GetUserCavern` và
      `EndlessChapterLogic:GetUserEndlessChapterData` đều kiểm `== nil` rồi mới
      gọi hàm dựng của mình, nên `{}` làm chúng bỏ qua bước dựng và màn hình
      chết vì số học trên `nil` (`CUICavern.lua:971`,
      `CUIInfiniteLevelMain.lua:619`). Danh sách này là **một nguồn duy nhất**;
      `init.lua` và `bootstrap.lua` đều đọc lại nó, và cả hai vòng lặp trong
      `bootstrap.lua` phải **bỏ qua** bảng thuộc `TU_DUNG` — nhét `{}` vào là
      bịt mất đúng đường vừa mở
- [x] Phiên bản định dạng file lưu (`OfflineStore.PHIEN_BAN`) — cần vì lỗi
      `{}` ở trên **đã kịp ghi ra file lưu** của những bản build trước. Bản lưu
      ấy có khoá **có mặt** nhưng dữ liệu hỏng, nên sửa `TU_DUNG` không cứu được
      (client thấy khác `nil` là bỏ qua hàm dựng). Đo được trên file lưu thật:
      bảng chỉ có đúng 5 trường mà `GetUserEndlessChapterData` vá được
      (`:133-152`) và **thiếu cả 5 bộ đếm**. Lệch phiên bản thì **bỏ** các bảng
      `TU_DUNG` để client dựng lại — không đoán trường nào còn thiếu, vì đoán
      danh sách trường là bịa. Khoá phiên bản nằm trong file nhưng **không** nằm
      trong `OfflineStore.data`, vì `all()` đưa nguyên khối đó cho
      `G_DataManager:Init`
      * **Giới hạn đã biết**: bản build trung gian (đã sửa `TU_DUNG` nhưng chưa
        có khoá phiên bản) cũng ghi file **không** khoá, nên **không phân biệt
        được** với bản lỗi — chúng bị bỏ như nhau. Mất mát thật chỉ có thể là
        tiến trình Ma Khu (handler `cavern` chạy được thật); tiến trình ải vô tận
        thì không, vì chưa có RPC nào đẩy nó lên được. Bản build đó chỉ tồn tại
        trên máy dev, chưa từng phát đi, và nhật ký ghi rõ đã bỏ bảng nào
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

**Đã phân loại hết 72 màn hỏng (2026-09-15).** Cách làm: với từng dòng hỏng, đọc
**hàm chứa nó**, rồi đọc **chỗ gọi hàm đó** trong `sc/` — không suy theo tên file
như bảng nhóm ở dưới. Danh sách lấy từ `quet_show.gd` chạy trên cây `sc/` đã đồng
bộ (`import_lua.py` rồi `check.py` xanh). **Soát lại lần hai** bằng chỗ gọi cho
**24 chỗ hỏng lồng nhau (30 màn)**: bảng dưới đây là bản đã sửa theo lần soát đó,
và **hai chỗ phân loại sai đã được gỡ** — xem "Đã sửa so với bản đầu".

| nhóm | số | nghĩa |
|---|---|---|
| **A. người gọi thiếu tham số** | **41** | Màn **chạy tốt trong game thật**; chỉ bộ quét gọi `Show(tên)` trần. Không có lỗ hổng nào để vá |
| **B. thiếu dữ liệu người chơi / máy chủ** | **15** | Lỗ hổng thật; 6 trong đó là tính năng nhiều người chơi |
| **C. thiếu bố cục / tag / tài sản** | **16** | 3 màn thiếu hẳn file `.xgg`. Trong số từng ghi là "thiếu tag con", đo lại thì **cả 3 màn đều KHÔNG thiếu tag**: hai màn (tag đã đo được từ trước) bị chặn ở khâu **áp** dữ liệu, còn `CUIBarracksMain` bị chặn ở **trần đo** — và trần ấy đã phá được bằng `--neo`, tag `getChildByTag(1)` của `snsMainToolArmySoul` **có thật trong bản gốc**, màn nay `Show: ok` |

Ghi chú từng nhóm:

* **A** — 15 màn kiểm chắc nhất: đã đọc thẳng **chỗ gọi** trong `sc/` và thấy nó
  **luôn truyền tham số** (`CMessageBox.lua:244` gọi
  `g_CUITipsDlg:Show("MessageBox", {Title=…, Content=…})`; `CUIHero.lua:1645` gọi
  `g_CUISubDialog:Show("CDlgHeroDropOut", self, hero)`; `CUISubDialog.lua:1556` gọi
  `…:Show(g_CDlgVipTipsBox:GetUIName(), self, {Level=6})`; và hai màn ở "Đã sửa").
  26 màn còn lại suy từ
  **chữ ký hàm chứa dòng hỏng** (`onShow(lastUIName, data)` rồi `data.X`) — mạnh,
  nhưng chưa đọc hết chỗ gọi. Trong A có **cả nhóm hộp thoại `CMessageBox`** (5
  màn) và **3 màn Thú cưng** — những thứ *trông* như nhóm đông nhất
* **B** — 15 màn, và **6 trong đó là nhiều người chơi**: 3 màn APR (`APRData:
  setRecordList` dựng từ gói tin máy chủ), 1 COG, 1 bang hội, 1 quốc chiến. **Ba
  màn cấu hình hoạt động** (`TimeLimitedHeroUI`, `SevenDaysEventsRewardView`,
  `ActivityAdventure`) hỏng vì `G_ActivityLogic:GetActivityConfigWithType` trả
  `nil` — `login.lua` trả `OnGetAcvitityList({}, {})` — nhưng **không lấy lại được
  từ dữ liệu ship**: `WeeklyFunDef.KeyTable` có `Plan` / `NewCommonConfig` và
  chính mã gốc ghi "原来从配置文件中读，现在改成从Plan中组装", còn GodHero thì
  hình dạng chỉ nằm trong một chú thích (`ActivityGodHeroLogic.lua:53`) mà **số
  thì không bảng nào có**. Bịa là sai kiểu `AchieveType` — xem nguyên tắc 1.

  **Ba màn còn lại ghi ở đây, nay đã tra từng màn — không màn nào là việc làm
  được, và cả ba đều KHÔNG phải lỗ hổng của lớp giả lập:**

  * `CUIQuestInfo` — **nay mở được**. Nó không còn mặt trong bảng hỏng ở cả ba
    lượt quét gần nhất (`/tmp/quet_a.txt`, `quet_moi.txt`, `quet_b.txt`), và
    353 = 292 mở + 0 im + 61 hỏng nên chắc chắn nó nằm trong phần mở được.
  * `CUITreasureHunt` — chết ở `CUITreasureHunt.lua:245`
    (`tLeftData.PrizeData.nCurItemCount >= tLeftData.Count`), **và bản gốc cũng
    chết đúng ở đó khi không có dữ liệu máy chủ**. Danh sách đổi thưởng do
    `ClientGodSecret:GetExchangeList` (`sc/user/Logical/ClientGodSecret.lua:159`)
    dựng: ba mục mặc định có `PrizeData = {}`, `Count = 0`, rồi vòng lặp **ghi
    đè** từ `tData.ExchangeStateList`. Không có `ExchangeStateList` thì
    `PrizeData` ở lại `{}` — mà `{}` thì `nCurItemCount` là `nil` → `nil >= 0`
    nổ. Đã tra `KDBGameCommonConfig` (113 mục): **không có `GameGodSecretReset`**
    (chỉ 10 mục `*Reset`), nên kho offline seed `{}` cho bảng này, và
    `GodSecret.lua:105` có phép thử `if tUserGodSecret == {} then` — so sánh
    **tham chiếu**, không bao giờ đúng trong Lua, nên `{}` vẫn đi tiếp như dữ
    liệu thật. Danh sách đổi thưởng do máy chủ sinh từ `tConfig.ExchangeList`
    (`sc/share/Activities/GodSecret.lua:24-36`) — phần sinh ấy **không được
    ship**. Bịa ba mục đổi thưởng là sai kiểu nguyên tắc 1.
  * `lEpicBattleChestMain` — chết ở `CUIEpicBattleChestMain.lua:292`
    (`self.PanelPosX[nUIType][1]`), mà nguyên nhân là `getType()` trả `NONE` (0)
    và `PanelPosX` **không có khoá 0** (`:26-34`, chỉ 1..5). Vào `NONE` vì
    `getOpenedCount()` (`:78-98`) trả `999, 999` khi thiếu
    `GameUserEpicChapter.TodayChapterInfo.LevelList` → `nRemainFreeCount` và
    `nRemainPayCount` cùng **âm**. Đây là số **theo NGÀY của từng tài khoản**,
    không suy ra được từ bảng cấu hình. Lối vào thật của màn là
    `ShowBy(level, boxId, countryIdx)` (`CUIEpicChapter.lua:697`), nên nó thuộc
    nhóm A (thiếu tham số người gọi) **cộng thêm** thiếu dữ liệu ngày.
  Cộng thêm **3 màn
  quét nhanh** vừa chuyển từ nhóm D sang (xem "Đã sửa") — nhưng chúng chỉ mở khi
  người chơi **đã có** món thừa, nên offline không với tới mà cũng đừng bịa món
* **C** — thiếu `.xgg` đối chiếu với **296 bố cục giải được**. Con số **ba màn**
  ghi ở đây trước là **ĐẾM THIẾU**; đo lại toàn bộ `ResourceXggList` của `sc/`
  (396 lượt trỏ, so từng tên file với `layout_ref/`) thì ra **6 file**, và **cả 6
  đều vắng mặt trong `conf/` của APK gốc** — tức không phải lỗi bóc thiếu của ta
  mà là bản ship không có (bản gốc tải lúc chạy từ máy chủ vá):

  | file `.xgg` thiếu | màn khai nó |
  |---|---|
  | `UI_CharacterDressInfo_960_640` | `CUICharacterDress` |
  | `UI_VIPRight_960_640` | `CUIVIPRight` |
  | `UI_Store_UI_960_640` | `CUIShop` |
  | `UI_GainHero_960_640` | `CUIGainHeroAnimation` |
  | `UI_Research_UI_960_640` | `CUIResearch` |
  | `UI_Hero_Dialog_960_640` | `CUIHeroGrowthFactor`, `CUIHeroUpgradeLevel`, `CUIHeroUpgradeMaxLevel`, `CUIHeroUpgradeQuality` (cùng khai `RootUIName = lHeroUIDialog`); `CUIDestiny` và `CUIHero` chỉ kể nó như file phụ |

  Cùng loại với ~45 mảnh `Scene_*.plist` ở mục 1. **Không sửa được, đừng tính vào
  việc còn lại.** Nhưng **cách chúng hỏng thì sửa được, và đã ghi lại** — xem
  khối "`lVIPRightUI` là BÓNG chứ không phải `nil`" bên dưới. Ba màn nữa (`CUIXingHun`,
  `RedPacketMainDlg`, `XingHunBook`) cùng chết ở một chỗ: `CUIAssist.switchTab`
  (`CUIAssist.lua:817`) gọi `node:getChildByTag(2)` mà nút ấy **thiếu tag con**.
  Đúng loại "tag còn thiếu" ấy còn **ba màn nữa, và node thì có mặt** —
  `CUIFriendsChatting` (3 tag con), `CUIArmyGroupCampsite` (**9 tag** ở hai tầng),
  `CUIBarracksMain` (node nằm ở HUD Main dùng chung) — xem khối "nay là thiếu TAG
  CON" bên dưới. Tag là thứ **chỉ đo được bằng máy ảo**, nên đây chính là chỗ việc
  2 của mục 8 trả công — và khi làm xong thì hoá ra **hai trong ba màn ấy không hề
  thiếu tag**, còn màn thứ ba (`CUIBarracksMain`) vẫn vướng trần đo, nhưng nay đã
  **khu trú được vào khối neo #38–#42** (xem mục 8, việc 2). `CUITurnplate` khác hẳn:
  `initTurnplate` **không tồn tại** ở đâu trong `sc/` (grep: chỉ có ở
  `CUIActivityLoginTurnplate:52` và `CUIActivityTurnplate:77`, không phải lớp cha)
  — tính năng chết trong chính bản gốc, không phải lỗi của ta
* **D — nhóm này nay đã bỏ.** Ba màn "quét nhanh" (`CUIContestShopQuickSell`,
  `CUIWCSShopQuickSell`, `CUIMysteriousStoreQuickSell`) **không** tự vỡ trong bản
  gốc: cả ba đều có chốt `hasItemToSell()` trước khi mở
  (`CUIContestShopQuickSell.lua:28`, `CUIWCSShopQuickSell.lua:28`, và người gọi
  `CUIMysteriousStore.lua:34-35`), nên game thật **không bao giờ** mở chúng khi
  danh sách rỗng — chỉ bộ quét mở trần. Chúng thuộc **B**: thiếu dữ liệu người
  chơi (món thừa / món có `ItemCount > 0`), không phải lỗi của mã gốc. Câu cũ
  "bản gốc vỡ y hệt khi người chơi không có món thừa nào" là **sai**.

**Đã sửa so với bản phân loại đầu (hai chỗ, đều là ghi vào B rồi hoá ra là A):**

* `CUITourMerchantConfirm` — `CUITourMerchant.lua:398` đặt
  `self.tViewData = tUserData`, tức **chính tham số của người gọi**, và chỗ gọi
  thật `:342` (`g_CUIMultiLayerDialog:Show(…, tData)`) có truyền. Dòng hỏng `:444`
  chỉ là bộ quét gọi trần.
* `HeroCombDetail` — `CUIHeroCombItem.lua:73` gọi
  `g_CUIHeroCombDetail:show(tag)` với `tag = obj:getStringTag()` (`:70`), nên
  `_szCombName` do người gọi đặt. Đã đối chiếu thêm: `FightPropertyAddtion` **có**
  trong bảng ship (`data_ref/config/share/KDBGameCommonConfig.xgg`) và hai chỗ đọc
  khác đều chặn y hệt, nên đây không phải lỗ hổng cấu hình.

Ghi hai màn ấy vào B là sai kiểu "đi viết handler không cần thiết" — đúng thứ mà
khối cảnh báo ở đầu mục này dặn.

**Ba màn từng ghi là "thiếu node" — nay đo ra HAI nguyên nhân khác nhau, và hai
trong ba KHÔNG phải thiếu tag** (tag không nằm trong `.xgg` — engine sinh lúc nạp,
ta đo từ máy ảo, xem `ui/xgg_layout.gd:306-312`):

* `CUIFriendsChatting.lua:143` — `lFriendsChattingEmoticonClose =
  blockPanel:getChildByTag(5)`, mà `blockPanel` (`cls=聊天隔挡层`, tag 1) có 5 con
  và ba con đầu **không tag nào**, nên `getChildByTag(2)/(4)/(5)` đều `nil`.
  **Tag KHÔNG thiếu**: `tags_cay.json` có `lFriendChattingUI/1` với năm con mang
  tag **2, 5, 4, 1, 3** — đúng từng dòng so với `:139-143`. Ba con ấy trùng khít
  nhau (1429×768 @ −234,5, −64) nên **đường ghép theo VỊ TRÍ** không phân biệt
  nổi, còn **đường ghép theo CHỈ SỐ CON** thì được — mà đường ấy **chưa từng được
  áp** vào `layout_ref`. Áp vào: `hoi=19 hut=0`, `Show` ok.
* `CUIArmyGroupCampsite.lua:533` — `ttfCampCountdownTree` (bố cục `/1/3/2/31`) cùng
  ba con và sáu `CCLabelTTF` cháu: trước `tag=None` cả hai tầng (9 tag). **Cũng
  KHÔNG thiếu tag**: `tags_cay.json` có sẵn `ndArmyGroupCampsiteShot/3/2/31`
  (tag 0, 40×40) với `/3/2/31/1` = 2 và `/3/2/31/2` = 3 — đúng đường chỉ số con
  mà khâu ghép bỏ qua. Sau khi áp: `hoi=12 hut=0`, màn đi **qua** `:533` và nay
  chết ở `:2748` `addNightEffect` (`<bong NightEffectLayer.new().create()>` trả
  bảng, `cocos.lua:391` đòi số) — thiếu **hàm engine**, không phải thiếu tag.
* `CUIBarracksMain.lua:203` — `snsMainToolArmySoul` **có** trong
  `UI_Main_ControlPanel_960_640.xgg`, ở đường chỉ số con `/14/1/snsMainToolArmySoul`,
  nhưng `tag` vẫn `None`. Trước đây ghi "thiếu tag THẬT" kèm lý do "màn đó chưa đo
  được node nào" — **lý do ấy nay sai**: đo lại thì màn ấy có **207 node** trong
  `tags_cay.json`. Cái thật sự chặn là **trần đo**: `snsMainToolArmySoul` là **neo
  thứ 41/75** của màn, mà đầu dò chỉ với tới neo **1..21** (xem mục "trần thật của
  phép đo" ở trên). Nó **không hề có** trong `tags_cay.json` (0 chỗ) nên chưa từng
  được mở tới. Vậy chưa đủ căn cứ để gọi đây là "thiếu tag thật": phải phá được
  trần neo rồi mới biết. Nhánh đối chứng `traideu` đang chạy gồm chính màn này —
  nếu nó tới được neo 41 thì tag sẽ có, và kết luận "thiếu tag" phải rút lại.

**Lỗi của lớp giả lập, đã sửa: `getChildByStringTag` khớp sai trường.** Hàm này
không có trong `sc/` (nó là hàm engine), nên ta tự viết trong `lua/cocos.lua` — và
đã viết sai: khớp `cls`. Đo trên 296 bố cục, với 267 chuỗi mà `sc/` hỏi bằng hàm
này: **15 chuỗi CHỈ có ở `res`** và **0 chuỗi chỉ có ở `cls`**. Nghĩa là phép khớp
theo `cls` làm 15 chuỗi ấy (và mọi chỗ gọi chúng) **không bao giờ tìm thấy**, trên
bản gốc đã ship — lỗi của lớp giả lập, không phải lỗ hổng của game. Hai ví dụ đo
được: `petslist` có `res="list"`, `cls="petslist"`; `selectTab` có
`res="selectTab"`, `cls="切换标签"` (chú thích của hoạ sĩ). Nay khớp `res` trước,
`cls` sau — giữ `cls` vì `setStringTag` ghi vào đó lúc chạy.

Kết quả đo (`quet_show.gd`, so **tên màn** chứ không so tổng). **Hai con số tổng
dưới đây là của RIÊNG lượt sửa này** — lúc đó đường ghép theo chỉ số con còn chưa
được chạy, nên chúng không phải tình trạng hiện tại; tình trạng hiện tại ở bảng
"trước / sau" của lượt ghép, phía dưới (`260 / 22 / 71` → `263 / 23 / 67`), rồi
lượt sửa `xoay` đưa tiếp lên **`264 / 22 / 67`**, và lượt `--neo` lên
**`264–265 / 23 / 65–66`**. Cả bốn số ấy đo bằng **thước đo CŨ** (chưa nhả khung
giữa các màn, nên "im" còn 22–23); thước mới đọc cùng bản mã đó ra `291–292 / 0 /
61–62` — xem ghi chú ở mục 0.

| | trước | sau |
|---|---|---|
| mở được / im / hỏng | 258 / 23 / 72 | 259 / 23 / 71 |
| `g_CUISubDialog/AnniversaryRankReward` | hỏng (`:47`, `selectTab` nil) | **mở được** |

`AnniversaryRankReward` là màn **duy nhất** thật sự đổi chỗ *trong lượt sửa này*
(lượt ghép theo chỉ số con về sau còn sửa thêm 5 màn khác — xem bảng dưới): nó **hỏng** ở lần chạy
trước khi sửa và **mở được ở cả hai** lần chạy sau — nhất quán, không phải may. Nút
`selectTab` (`res="selectTab"`) có đủ 3 con
mang tag 1/2/3, nên sửa xong `__initUI` chạy trọn vòng lặp và đi tiếp tới `:59`.
Sáu tên còn lại đổi chỗ ở một trong hai lần so (`XingHunMsgDlg`, `EquipmentInfoDialog`,
`MoreGoldDialog`, `MoreDiamondDialog`, `CUIGuildInfoDonate`, `GuildScienceDlg`) đều
nằm trong **tập dao động** — và lần này đo được thêm một điều: ba trong số đó
(`MoreDiamondDialog`, `GuildScienceDlg`, `CUIGuildInfoDonate`) nhảy **giữa mở-được
và im**, tức **nhóm "im" cũng nằm trong phần dao động**, không chỉ hỏng↔im. Cách
kiểm: hai lần chạy **cùng bản đã sửa** đã khác nhau 2 màn. `check.py` vẫn 24/24
xanh, gồm cả hai bộ chạm.

`PetIllustration` **không** mở được, nhưng đi xa hơn hẳn: hỏng cũ ở `:74` là vì
`getChildByStringTag("list")` trả nil; nay `list` tìm thấy và màn chết ở chỗ khác —
`cocos.lua:391: diem neo khong phai so … cua <bong LuaTableView_create()>`. Tức
`CUITableViewZ:init` (`CUITableViewZ.lua:180`) gọi một hàm engine **chưa làm**:
`LuaTableView_create` không có trong `lua/` lẫn file `.gd` nào. Muốn màn này mở thì
phải làm binding đó — việc engine, không phải việc dữ liệu.

Một hệ quả nữa của cơ chế bong, ghi lại để đừng đi nhầm: `spStoreUITag_1` của
`CUIShop` là **bong** (đọc qua `_G`), nên nó **truthy**, `CUITab:RegItem` chạy trọn
rồi `tonumber(bong)` ra nil ở `:129`. Chỗ hỏng thật là **thiếu file
`UI_Store_UI_960_640.xgg`**, không phải dòng 129.

### `lVIPRightUI` là BÓNG chứ không phải `nil`

Cơ chế, đo được chứ không suy: `M.install()` (`lua/bootstrap.lua:672-684`) đặt
metatable cho `_G`; `__index` trả `make_ghost(tostring(k))` cho mọi tên **chưa gán**
và **không** nằm trong `never`/`da_gan`. `make_ghost` (`:78-110`) dựng một bảng có
`__bong = true`, `__index`/`__call` trả bóng tiếp, `__tostring` ra `<bong tên>`, và
có **trần** (`CUT_SO` / `CUT_SAU`) để không nổ số bóng.

Vì sao cần: `boot_goc()` nạp **876 module** và mã gốc gọi chéo rất nhiều thứ chỉ
tồn tại lúc chạy. Nếu `_G.x` là `nil` thì `_G.x:PhươngThức()` ném lỗi **ngay dòng
đó**, và cả 353 màn thành "hỏng ở dòng đầu" — mất luôn khả năng phân loại. Bóng cho
đi tiếp và **đếm được**; nhờ nó mới có bảng 72 màn chia theo nguyên nhân ở trên.

Cái giá, và đây là chỗ dễ đi nhầm: **bóng phá các phép KIỂM TRA TỒN TẠI viết bằng
`if x == nil`**. `CUIPublic:GetRootUI` (`sc/user/Public/CUIPublic.lua:322-350`) có
đúng phép kiểm đó — `if rootUI == nil then KDebug.PrintWarning(...) end` — nhưng
`rootUI = _G[self.RootUIName]` là **bóng**, nên nhánh cảnh báo **không bao giờ
chạy**, hàm trả về bóng, và bóng chảy tiếp vào
`CPublic:SaveUIOriginalState` (`:1221-1240`) thành
`OriginalState.ScaleX = <bong lVIPRightUI.getScaleX()>`. Tới
`CUIDialogAnimation.lua:242` thì nó *cộng* giá trị ấy:
`S_CCScaleTo:create(nDelayTime, ox*1.1, oy*1.1)` → `attempt to perform arithmetic
on local 'ox' (a table value)`.

Đo bằng `tools/chay_lua.gd` — hỏi thẳng `_G[<tên>]` trong phiên đã đăng nhập
(Login → Main), in ra `type`, `tostring`, và `getmetatable(x).__bong`:

```
lVIPRightUI              type=table val=<bong lVIPRightUI>              la_bong=true
lStoreUI                 type=table val=<bong lStoreUI>                 la_bong=true
lCharacterDressInfoUI    type=table val=<bong lCharacterDressInfoUI>    la_bong=true
lHeroUIDialog            type=table val=<bong lHeroUIDialog>            la_bong=true
```

Bốn tên ấy là đúng bốn gốc bố cục của **6 file `.xgg`** trong bảng ở nhóm C phía
trên, và 6 file ấy **vắng cả trong `conf/` của APK gốc** — nên đây không phải lỗi
bóc thiếu của ta. Triệu chứng đo được trong `quet_show.gd`: 2 màn chết ở
`CUIDialogAnimation.lua:242` (`CUIVIPRight`, `CUICharacterDress`) — cùng một dòng
lỗi, cùng một cơ chế.

**Vì sao KHÔNG lật bóng thành `nil` cho riêng nhóm này** (đã cân nhắc và bác bỏ):
`nil` thì `GetRootUI` trả `nil`, `CUIPublic:onShow` thoát sớm **sau khi đã đặt
`IsUiShow = true`** — màn được tính là "mở được" mà **không vẽ gì cả**. Phép đếm
sẽ tăng thêm mấy màn bằng một lời nói dối, còn người chơi vẫn thấy màn trắng. Màn
vẫn hỏng thật, chỉ là hỏng **im lặng**. Nên: ghi lại, không sửa. Muốn sửa cho thật
thì phải có 6 bố cục ấy — chúng nằm ngoài bản ship.

### Tên mà **chính Lua bản gốc gán** thì không được làm bóng

Đây là mặt trái của cơ chế trên, và là lỗi **im lặng** đúng nghĩa: bóng là
`truthy`, nên tên nào mã gốc **đọc trước lần gán đầu tiên** sẽ đi nhánh khác hẳn
bản gốc. Bản gốc đọc ra `nil`; ta đọc ra một bảng.

Đo được một chỗ thật, và nó là cả một tính năng: `RichLabel.lua` gán `failed` ở
`:672` (khi gặp thẻ sai) rồi đọc ở `:710`. Lần gọi **đầu tiên** `failed` là `nil`,
nên bản gốc **tách** chuỗi `[fontColor=0000FF]chu[/fontColor]` thành từng đoạn;
ta đọc ra bóng nên `parseString_` trả cả chuỗi làm **một** đoạn — mọi chuỗi có thẻ
màu đều hiện nguyên thẻ ra màn hình, và mọi phép đặt chỗ theo từng đoạn đều sai.

**Luật:** tên nào có một **câu lệnh gán ở mức câu** trong `sc/` thì `__index` trả
`nil` (và đếm riêng vào `M.thieu_bien_lua`, đọc được để biết module nào chưa nạp).

**Bộ quét phải theo token, không theo dòng.** `quet_gan()` trong
`tools/import_lua.py` đi theo độ sâu ngoặc và ranh giới câu lệnh. Bản đầu quét
theo dòng và ra **10.594** tên, trong đó có `A`, `Add`, `Count`, `Color`,
`Content`, `Class` — toàn **khoá của bảng** (`Label = 1,`) bị đọc nhầm thành biến
của Lua. Bản đúng ra **6.901** tên.

**Vì sao không dùng phép thử "có trong `libgame.so`/`classes.dex`" như `bien_nil`:**
chiều này nó miễn **nhầm** quá nhiều. `failed` là chữ tiếng Anh bình thường, có
mặt ở cả hai file — luật ấy sẽ để nguyên lỗi bóng ở `RichLabel`. Luật đang dùng
hẹp hơn: tìm **tên có gói** (`\0failed\0`, đúng chuỗi mà bảng tên của engine
dùng) — `LGG_Device_UUID` ra 1, `data` ra 2, `failed` ra **0**. Nhờ vậy giữ bóng
cho **161** tên là tên engine thật, trong đó có `LGG_Device_UUID`.

**161 tên ấy giữ bóng là ĐÚNG, không phải nhân nhượng.** `Device.lua:249-251`
**đọc** `LGG_Device_UUID` để cất vào `pRawFunc_LGG_Device_UUID` **rồi mới** gán
bản bọc của Lua — một tên vừa là hàm engine vừa bị Lua gán. Ép `nil` thì
`pRawFunc_...` thành `nil` và `:251` ném
`attempt to call upvalue 'pRawFunc_LGG_Device_UUID' (a nil value)` — đo được, và
đó là lý do luật `\0tên\0` ra đời.

**Một hệ quả bắt buộc phải theo:** `sngAsyncDLMgr` nay chỉ tồn tại sau khi module
tải được nạp. Bản gốc nạp nó **vô điều kiện** (`game.lua:242-247`,
`if true or SDK_Mgr.bIsUseUpdateV2`) nên `boot_goc` cũng phải nạp
(`bootstrap.lua`, bước *mo-dun tai*). Bỏ qua thì
`CUILogin2.lua:1834: attempt to index global 'sngAsyncDLMgr' (a nil value)`.

**Hệ quả thứ hai — và đây là lỗi im lặng thứ hai của cùng luật này, to hơn cái
thứ nhất.** Luật `bien_lua` gây hại theo **hai** chiều, không một:

* **Chiều đã biết:** tên do Lua gán thì phải đọc ra `nil` — đó là ý định.
* **Chiều mới đo được:** một tên **engine** (Lua không gán) mà ta **chưa làm** thì
  là **bóng**, và bóng **so sánh với chuỗi luôn ra "khác"**. Nên mọi chỗ viết
  `if <hàm engine>() == "..."` đều đi **nhánh sai**, im lặng.

Chỗ đo được: `LGG_GetPlatformString` chưa từng được viết. `KDebug.lua:181` là
`if not ISSERVER and LGG_GetPlatformString() ~= "windows" then` — bóng khác
`"windows"`, nên ta đi vào nhánh **chỉ dành cho Android/iOS** và gọi
`sngDownload:getCurResVersion()`. Mà `sngDownload` do **chính Lua gán**
(`sngDownload.lua:52`) và chỉ được nạp từ `game.lua:243` — **không** nằm trong
bốn bản kê khai `boot_goc` đọc — nên theo luật `bien_lua` nó ra **`nil`**, và
**mỗi dòng lỗi in ra** đều ném
`KDebug.lua:185: attempt to index global 'sngDownload' (a nil value)`. Hậu quả
đo được: `CUIAchieve:Reflesh` dừng ngay ở `KDebug.ProcessError` đầu tiên, nên
`AchieveDataList` **không hề được đặt** (đo: `nil`, không phải rỗng) và danh
sách ra **0 dòng** — trước đó là 6 mục / 5 dòng.

**Cách chữa KHÔNG phải nới luật `bien_lua`.** Bản gốc **có** bản Windows thật:
`GameOS.lua:8-13` khai `OS_TYPE = { WINDOWS = "windows", ANDROID = "android",
IOS = "ios" }` và **24 chỗ** trong `sc/` đem chuỗi ấy ra so
(`engine.lua:13`/`:289`, `KDebug.lua:181`, `rpc.lua:249`/`:497`, `Device.lua:43`,
`game.lua:189`/`:510`, `CUIMainTopTool.lua:538`/`:546`…). Ta **chạy trên
Windows**, nên `install_cocos()` nay trả đúng `"windows"`. Đo lại:
`verify_lua_screen.gd` **18 đạt / 0 hỏng** (trước 16/2), `DataList = 6`, 5 dòng
dùng được. Nghĩa là **việc chưa làm `LGG_GetPlatformString` mới là gốc**, còn
luật `bien_lua` chỉ là thứ làm nó **lộ ra** thay vì bị bóng che.

**Bẫy đo đã mắc, ghi lại vì mất gần một lượt:** `M.thieu_bien_lua` là **bảng đếm
theo tên** (`ten -> số lần`), nên `#M.thieu_bien_lua` **luôn là 0** — `#` chỉ đếm
phần mảng. Tôi đọc con số 0 ấy thành "luật không hề chạy" rồi đi tìm nguyên nhân
ở chỗ khác, trong khi luật chạy đúng. Nay có `M.so_thieu()` đếm bằng `pairs`, và
`M.danh_dau()` ghi **danh sách** những tên đọc-ra-`nil` sau mốc (in ra ở
`verify_lua_screen.gd`).

**Kiểm chứng không hồi quy:** `tools/vao_main.gd` chạy trước và sau khi đổi
(`git stash` để lấy bản trước), so từng khối lỗi — **giống hệt** sau khi chuẩn hoá
số dòng, và `tag hut 94/3233`, `CurrentScene Main`, `IsEnterGame true`,
`so loi goc 13` đều khớp.

**Hệ quả cho mục 8, và nó đổi việc tiếp theo:** "nhóm đông nhất" **không phải một
tính năng nào cả**. Nhóm đông nhất là A, và A không cần gì. **32 trong 72 màn
không thuộc nhóm tính năng nào** (hộp thoại dùng chung), và 21 trong số đó là A.
Sau khi trừ nhiều người chơi (APR/COG/bang hội/quốc chiến) và ba màn cấu hình hoạt
động không lấy lại được, **phần B còn làm được chỉ còn 3 màn rời rạc**
(`lEpicBattleChestMain`, `CUIQuestInfo`, `CUITreasureHunt`) — không còn "nhóm đông"
nào để việc 1 nhắm vào, nên **việc 1 coi như đã cạn**. **Ba màn ấy rồi cũng đã tra
từng màn: không màn nào làm được** — `CUIQuestInfo` nay mở được, hai màn kia chết
trong **chính nhánh mặc định của bản gốc khi thiếu dữ liệu máy chủ** (chi tiết và
chỗ dẫn chứng ở mục 4, nhóm B). Tức việc 1 không chỉ "đã cạn" mà **cạn hẳn**.

**Việc 2 (máy ảo Android) lên làm trước — và lần soát này đo được vì sao.** Tag
**không nằm trong `.xgg`**: engine sinh ra lúc nạp, ta đo từ máy ảo
(`ui/xgg_layout.gd:306-312`, `work/emu_tags.py`), nên chỗ nào máy ảo chưa trả về thì
ta **không có cách nào suy ra** — chỉ đo được. Và nay biết tag thiếu là nguyên nhân
của **6 trong 16 màn C**: `CUIFriendsChatting` (3 tag), `CUIArmyGroupCampsite`
(9 tag ở hai tầng), `CUIBarracksMain`, và ba màn chết chung ở
`CUIAssist.switchTab` (`CUIXingHun`, `RedPacketMainDlg`, `XingHunBook`). Đo bằng
máy ảo là cách duy nhất điền chúng mà không bịa — và cùng lần chạy đó chốt luôn đốm
xanh ở Main.

**Con số "6 màn, một nguyên nhân" ấy SAI, và sai vì chưa đo tới nơi.** Làm xong
việc 2 mới tách được **bốn nguyên nhân**, trong đó nguyên nhân lớn nhất **không
phải thiếu tag** mà là **tag đã đo rồi mà chưa ghép**:

| màn | nguyên nhân thật | cách kiểm |
|---|---|---|
| `CUIFriendsChatting` | **ghép thiếu** — tag 2/5/4/1/3 có sẵn trong `tags_cay.json` | `do_mot_man.gd`: `hoi=19 hut=0`, `Show` ok |
| `RedPacketMainDlg` | **ghép thiếu** — `switchTab` gọi `getChildByTag(2)` rồi `(1)` | `hoi=12 hut=0`, `Show` ok |
| `CUIArmyGroupCampsite` | **ghép thiếu** — 9 tag có sẵn ở `ndArmyGroupCampsiteShot/3/2/31` | `hoi=12 hut=0`, nay chết ở hàm engine `NightEffectLayer` |
| `CUIBarracksMain` | **KHÔNG thiếu tag — trần đo, và trần ĐÃ PHÁ** — `do_mot_man.gd` đòi `getChildByTag(1)` trên `snsMainToolArmySoul`; đo thẳng neo ấy bằng `--neo` thì nó ra **tag 2** và bốn con ra tag **2, 1, 0, 0** — vậy tag ấy **có thật trong bản gốc**, chỉ là đầu dò chưa từng tới (neo 41/75, thuộc khối #38–#42). Nay `hoi=88 hut=17`, **`Show: ok`** (trước là `:203 attempt to index a nil value`). 17 chỗ hụt còn lại là lớp khác: `lSelectedUnit` hỏi tag 10/20/30/40 mà con nó mang tag 1..4 | `tools/do_mot_man.gd` + `--neo` |
| `CUIXingHun` | **KHÔNG phải `switchTab`** — chết ở `CUIZhanXing.lua:232` (`getChildByTag(0)` trên `hunWeiN`) | `quet_show.gd` |
| `XingHunBook` | **KHÔNG phải `switchTab`** — chết ở `CUIXingHunBook.lua:132` `CUITableViewZ:new():init` | trùng với việc 5 (`LuaTableView_create`) |

Nghĩa là **"chỉ máy ảo mới điền được"** không còn đúng cho màn nào theo nghĩa ban
đầu: **ba** màn (`CUIFriendsChatting`, `CUIArmyGroupCampsite`, `RedPacketMainDlg`)
đã có dữ liệu đo từ trước, thứ chặn chúng là khâu **áp**; **hai** màn
(`CUIXingHun`, `XingHunBook`) chặn vì lý do khác hẳn, không liên quan tới tag;
còn `CUIBarracksMain` chặn ở **trần đo** — và trần ấy **đã phá được** bằng cách đo
thẳng neo bị chặn (`--neo`), nên tag nó cần **có thật trong bản gốc**. Nói cách
khác: **không màn nào trong nhóm này thiếu tag thật.** Ba màn nhóm đầu bị chặn ở khâu **áp** dữ liệu vào
`layout_ref`: `emu_join.py --ghi` có **hai đường**, đường theo VỊ TRÍ (dự phòng,
dò hình học) và đường theo **CHỈ SỐ CON** (đường chính, khớp chỉ số của bản gốc),
chạy nối tiếp đường sau đè đường trước — và đường chỉ số con **chưa từng được
chạy** trên kho `tags_cay.json` hiện có. Chạy nó (đo bằng `work/kiem_tag.py`, đếm
từ chính bố cục, và `tools/quet_show.gd`):

| | trước | sau ghép | sau khi sửa `xoay` | sau `--neo` |
|---|---|---|---|---|
| node có tag trong `layout_ref` | 19.456 / 33.472 (58,1%) | **26.315 / 33.472 (78,6%)** | **27.876 / 33.472 (83,3%)** | **27.887 / 33.472 (83,3%)** |
| màn mở được / im / hỏng | 260 / 22 / 71 | **263 / 23 / 67** | **264 / 22 / 67** | **264–265 / 23 / 65–66** |

> Bốn cột này đo bằng **thước đo CŨ** (chưa nhả khung), nên cột "im" còn 22–23.
> Giữ nguyên vì chúng là bản ghi của bốn lượt đo ngày hôm đó; muốn so với hiện
> tại thì phải đọc lại bằng thước mới — xem ghi chú ở mục 0.

Sửa được **5 màn, và sửa được ở CẢ HAI lần chạy lại** (đây là phép kiểm, vì
`quet_show.gd` dao động): `CUIFriendsChatting`, `CUIContest`, `RedPacketMainDlg`,
`CUICOGCityInfo`, `TimeHeroUI`. Không màn nào đang mở bị hỏng thêm: hai lần chạy
sau khi ghép lệch nhau đúng **một** màn (`MoreGoldDialog`), và nó nằm trong nhóm
dao động đã ghi. `check.py` 24/24 xanh (gồm `verify.gd` 3.142 đạt / 0 hỏng).

### Hai nhóm "hụt tag" lớn nhất sau khi ghép: một là CỐ Ý, một là lỗi của TA

Sau khi ghép xong, `quet_show.gd` còn **2.008 lượt hụt / 32.661 lượt hỏi
(93,9% trúng)** — số của lượt quét mới nhất, sau khi sửa cả hai nhóm dưới đây
(lượt trước khi sửa: 2.132 / 31.628, 93,3%). Nhóm theo **từng tag**
(`cocos.lua` đếm ở `M.tag_miss_theo_tag`, `quet_show.gd` in ra) mới tách được
hai thứ hoàn toàn khác nhau, **và lượt quét mới xác nhận cả hai đã tách sạch**:
bảng "hụt theo TỪNG TAG" nay là `4 ×519`, `5 ×475`, `2514 ×224`, `3 ×206`,
`2 ×142`, `1 ×35`, rồi tới các tag `1003..1010` — **không còn một tag lẻ nào**
(`3.5`, `4.5`, `2.5`, `5.5` đã biến mất hẳn), và `2514` vẫn đứng nguyên ở 224
đúng như kết luận "cố ý":

* **`tag 2514` × 224 — đây là phép THỬ CÓ MẶT của chính mã gốc, không phải lỗi.**
  `CUIPublic:AddHeroFaction` (`sc/user/Public/CUIPublic.lua:555-605`) làm
  `if item:getChildByTag(g_CUIPublic.nFactionTag) then
  item:removeChildByTag(g_CUIPublic.nFactionTag) end`, với
  `nFactionTag = 2514` (`:73`) — tức "có thì gỡ, chưa có thì thôi". Chỗ gọi:
  `CUIHeroListEx.lua:854/858` (`fillHeroBaseCommonData`). Đo bằng cách móc
  `getChildByTag` rồi `debug.traceback`: 183 lượt hụt đầu tiên đều ra từ đúng
  cặp hàm ấy. **Không có gì để sửa** — bản gốc cũng hụt y hệt.
* **Tag LẺ (`3.5` ×72, `4.5` ×72, `2.5` ×42, `5.5` ×42 = 228 lượt, 10,7%) — lỗi
  của lớp giả lập, và ĐÃ SỬA.** `CUIStar.lua:236-249` tính
  `local nOffsetStar = delta/2` rồi `idx = i + nOffsetStar`; Lua 5.1 luôn cho
  `/` ra số thực (không có phép chia nguyên), nên bản gốc gọi
  `getChildByTag(3.5)`. Khai báo binding của Cocos là `int`, tolua ép bằng
  `(int)tolua_tonumber(...)` — **cắt về phía 0** — nên bản gốc tìm ra tag **3**.
  Bằng chứng độc lập: nếu thật sự trượt thì `pOneStar:setIsVisible(true)` không
  bao giờ chạy, tức **bản gốc không bao giờ hiện một ngôi sao nào** — vô lý với
  màn hiện sao chất lượng tướng (`CUIHeroQualityPictureFrame.lua:304`
  `SetHeroStarUI`). Nay `Node:getChildByTag` và `Node:getChildByTagInAllChildren`
  cắt y hệt tolua (âm thì `ceil`, dương thì `floor`).

Cùng lượt ấy phát hiện `removeChildByTag` **chưa hề được làm** (36 lượt gọi lúc
chạy, **100 chỗ gọi** trong `sc/`), nên mọi chỗ gốc gỡ node đều im lặng không gỡ
gì. Đã làm — nhưng **không** gọi `queue_free()`: `removeChildByTag(tag, cleanup)`
của Cocos với `cleanup = true` chỉ **dừng action và schedule** rồi bỏ node khỏi
mảng con, **không huỷ đối tượng**; `CElementPond:delParent`
(`sc/user/Public/CElementPond.lua:282-284`) gỡ rồi **gắn lại chính node ấy** (nó
là kho gom ô danh sách). `queue_free()` ở đây là giết cả kho.

### Lỗi im lặng thứ hai của lớp giả lập: `_godot_zsort` không hề tồn tại

Bảng "API Cocos CHUA LAM" của lượt quét mới cho `reorderChild` **1.200 lượt** —
đứng đầu toàn bảng, gấp gần 9 lần cái thứ hai. Truy ra thì đây **không phải một
API còn thiếu**: nó là dấu hiệu của một hàm đã bị gọi mà **chưa từng được viết**.

`lua/cocos.lua` gọi `_godot_zsort(cha)` ở **hai** chỗ (`addChild` khi có `z`, và
`setZOrder`) nhưng **không định nghĩa nó ở đâu cả**. Tên ấy rơi vào `_G` giả lập →
trả về một **bóng** → bóng **gọi được** (trả bóng) → nên `setZOrder` và
`addChild(c, z)` chỉ **ghi meta `zorder` rồi thôi, không xếp lại gì**. Không có
lỗi nào được ném ra, không bộ đếm nào bắt được — **đúng cùng kiểu với `setGray`**
đã ghi ở trên, nhưng lần này nằm **trong chính lớp giả lập**, không phải trong mã
gốc.

Phạm vi cho đúng, kẻo nói quá: **lúc NẠP bố cục thì thứ tự vẫn đúng** —
`XggLayout.sap_xep_theo_z` (`ui/xgg_layout.gd:375-392`) đã xếp từ trước và vẫn
chạy. Cái mất là **thứ tự đặt LÚC CHẠY**, tức đúng những chỗ mã gốc điều khiển
bằng tay: `addChild(c, z)` và `setZOrder`. Chỗ đáng kể nhất là `SetOpenZorder` của
hộp thoại — `setZOrder(50)` để hộp thoại nằm **trên lớp che (20) và dưới thanh
Back (60)**. Hàm mới viết theo **đúng luật của `sap_xep_theo_z`** (cùng cách phá
thế bằng nhau: giữ thứ tự cũ), nên hai đường không lệch nhau.

Đã viết `_godot_zsort`: xếp lại **mảng con thật** theo `(zorder, thứ tự thêm)`
tăng dần, bằng một lượt `move_child` tăng dần (khi bước `k` thì `k-1` phần tử đầu
đã đúng chỗ, nên chỉ các phần tử **chưa xếp** bị dịch — tiền tố giữ nguyên).
**Không dùng `z_index`**: bản gốc truyền tới 99999
(`CUISubtitle:AddToParent`) còn Godot chỉ nhận ±4096. Kèm theo,
`Node:reorderChild(child, z)` (`CCNode::reorderChild` — đổi zOrder của **một con**
rồi xếp lại; 1 chỗ gọi trong mã, `CUIArmyGroupCampsite.lua:3583`, nhưng nằm trong
vòng lặp qua toàn bộ con nên đo ra 1.200 lượt).

**Một cái bẫy nữa của chính bộ đếm, ghi lại để đừng đọc sai bảng ấy:**
`__index` của bảng `Node` trả về **một hàm rỗng** cho mọi tên chưa làm, nên phép
thử tồn tại của bản gốc — `if pProgressTimer.setOrange then`
(`sc/user/Public/CUIPublic.lua:523`) — **luôn đúng** ở đây, trong khi ở bản gốc nó
phụ thuộc lớp C++ có method ấy hay không. Tức bảng "API chưa làm" **trộn hai thứ**:
lượt gọi thật, và lượt **dò** xem method có tồn tại không. `setOrange ×5` là loại
thứ hai.

**Nay đo được đúng ca này** (bảng bind `libgame.so` — xem mục "setGray" và
`brave-cross/work/binder.py`): `setOrange` chỉ có trên **một** lớp duy nhất là
`CCProgressTimer`, và **cả 6 chỗ gọi** `setOrange` trong mã gốc đều nhắm vào
progress timer (`pPtExp` CUIGameFinish.lua:1429, `pProgressTimer`
CUIPublic.lua:524, `pExp` CUIHeroInfoMainUI.lua:1513, `uiExPt`
CUIHeroListEx.lua:1312, `pMainUIHeroExp` CUIMain.lua:1522, `pExp`
CUIExpShop.lua:148). Nên ở **đúng ca này** phép thử của bản gốc cũng **đúng** —
lớp giả lập trùng với bản gốc. Đó là một sự trùng hợp, nhưng là trùng hợp **đã
đo**; cái bẫy `if node.method then` vẫn còn nguyên với mọi tên khác.

Đếm lại theo **lượt gọi** (không phải theo chỗ): **12 lượt, 6 chỗ**, và **cả 6
chỗ đều là một cặp `true` rồi `false`** quanh một đoạn — `CUIGameFinish.lua:1431`
và `:1433`, `CUIPublic.lua:527`/`:529`, `CUIHeroInfoMainUI.lua:1515`/`:1517`,
`CUIHeroListEx.lua:1314`/`:1316`, `CUIMain.lua:1524`/`:1526`,
`CUIExpShop.lua:150`/`:152`. Tức nó là **một trạng thái bật rồi tắt**, không phải
một phép đổi màu lâu dài — nên nếu sau này có làm thì phải làm **đúng một cờ**
chứ không phải hai lần gọi rời. `setOrange ×5` ở trên là số của **một bộ quét
theo màn**, không phải số chỗ gọi; hai con số không mâu thuẫn, chỉ khác thước.

### Lớp giả lập: những gì đã làm thêm trong lượt này

| API | chỗ gọi | làm gì | cơ sở |
|---|---|---|---|
| `getColor` / `setEffectColor` / `getEffectColor` | 1.281 mỗi cái | màu chữ + màu viền, lưu/trả được | `CUIPublic:SetLableGray` (`:390-431`) lưu `getColor()` **(3 số)** và `getEffectColor()` **(4 số)** rồi trả lại — trước đây `getColor()` ra `nil` nên `c.r or 255` ghi ra màu gần như trong suốt |
| `setGray` / `isGray` | 683 / 214 | **trạng thái** xám + **hình** xám cho node VẼ (shader số 1 của bản gốc) | trước đây `isGray()` ra `nil`, mà `nil` không bằng `false` lẫn `true`, nên cả hai lối viết (`if btn:isGray() == false` và `if not btn:isGray()`) đi sai hướng trong im lặng. Phần hình: xem mục "setGray" bên dưới |
| `setCascadeOpacityEnabled` | 56 | no-op **đúng nghĩa** | 56 chỗ đều truyền `true`; Godot cho `modulate` lan xuống cây **luôn**, tức đã làm sẵn đúng điều được xin |
| `refreshChildArray` | 45 | no-op **đúng nghĩa** | ở đây không có mảng con nào để dựng lại: `getChildByTag` quét thẳng con của Godot |
| `setHorizontalAlignment` | 8 | căn chữ | thứ tự enum y `alignH` của `.xgg`, và Godot dùng **đúng ba số 0/1/2** ấy (`ui/xgg_layout.gd:229-233`) |
| `getFontSize` | 7 | cỡ chữ đang dùng | `CUINewHandPrivilege.lua:184` lấy cỡ chữ nhãn cha truyền xuống `RichLabel` |
| `removeAllChildrenAndArray` | 37 | bỏ hết con + huỷ | cùng nghĩa `removeAllChildrenWithCleanup`; khác `removeChildByTag`, ở đây **không** có kho nào nhận lại node |
| `_lua_getAnimationTime` / `_lua_setAnimationRate` / `_lua_stop` / `_lua_setOpacity` | 97 / 26 / 24 / 2 | 4 lệnh armature | thêm 3 method vào `rig/sng_rig.gd`: `thoi_luong` (giây — **thiếu thì trả 0**, mà 0 giây = đi tiếp ngay), `dat_toc_do`, `dung` (giữ nguyên tư thế: Cocos `stopAnimation` **không** đưa về khung 0) |
| `_lua_addChildToPlugIn` / `_lua_clearPlugIn` / `_lua_getPlugInPositionInNode` | 33 / 10 / 5 | treo một node Lua lên **điểm gắn** trong bộ xương | số trong tên plug là **số chứ**, đo trên 418 file `.xml` / 587 biến thể, và khoá bằng một ca không thể trùng (`Gashapon` có đúng `PlugIn_4_Hero`/`_5_Word`/`_6_Light`/`_7_HeroName`, còn `CUIUnlockHeroAnimation.lua:166-169` gọi `_lua_clearPlugIn` đúng bốn số 4, 5, 6, 7); `tools/verify_plug.gd` — 12 đạt / 0 hỏng |
| `pauseActions` / `resumeActions` | 2 (`CPublic`) | tạm dừng / chạy lại action **và** hẹn giờ của node | `CCNode::pauseActions` của bản gốc gọi `pauseSchedulerAndActions`, tức **cả hai** bộ. Đo trong `libgame.so` (`work/binder.py --nut`): `+0xdc` là bộ quản lý action (5 hàm action đều đọc đúng ô này), `+0xd8` là bộ thứ hai mà **không hàm action nào** đọc, `+0xe0` là `m_bRunning` — nhận ra nhờ `eor r3,r3,#1` (= `!m_bRunning`) nằm đúng chỗ đối số, đúng chữ ký `CCNode::runAction`/`schedule`; `pauseActions` (`0x4aeb88`) và `resumeActions` (`0x4aeacc`) đọc **cả `+0xd8` lẫn `+0xdc`**. Quét cả 132 bảng lớp **không** có hàm nào riêng cho bộ hẹn giờ (`pause`/`resume` 2 lớp; `schedule`/`scheduleOnce`/`scheduleUpdate` chỉ ở lớp `CCSchedule`), nên đây là đường **duy nhất**. Khung hình tạm dừng **không** cộng dồn thời gian, nên chạy lại không nhảy một bước; `tools/verify_lua_actions.gd` — 54 đạt / 0 hỏng |
| `CCProgressTo` / `CCProgressFromTo` | 49 + 14 = **63** lượt | chạy phần trăm của thanh tiến độ theo thời gian | Nghĩa của Cocos2d-x đọc từ chính mã gốc: `CCProgressTo::startWithTarget` lấy `m_fFrom` = phần trăm **đang có** rồi `update(p)` đặt `m_fFrom + (m_fTo − m_fFrom)·p`; `CCProgressFromTo::startWithTarget` đặt luôn phần trăm về `m_fFrom` **trước** khi chạy — hai cái khác nhau đúng ở chỗ lấy điểm đầu. Đặt qua node Godot chứ **không** qua lớp bọc: lớp bọc đã chốt `__index` về bảng `Node` (`cocos.lua:86`) nên `n:setPercentage(...)` ở đây sẽ rơi vào bộ đếm `M.missing` mà **im lặng**. Trước khi làm, hai thực thể này là **bóng**: `system/engine.lua:82-83` chỉ tạo `CCProgressTo:new()` từ một lớp không có, `create` trả về bảng không có `tien`, và `M.runAction` bỏ qua nó **không một lỗi nào** — mọi thanh tiến độ đứng yên. Đo trước/sau bằng chính bộ kiểm: **44 đạt / 8 hỏng** → **54 đạt / 0 hỏng**. Một chỗ đáng nhớ: `ptLoadingGamePercent` (nút **duy nhất** của cả cây vừa vuông vừa to — 81×81 — và là nút duy nhất ghi tên ảnh ở `+0xE4`) là thanh mà **chính mã gốc** quay bằng đúng cặp này: `CUIDownload.lua:62-70` chạy `ProgressFromTo(0.8, 0, 100)` + `setType "cw"` rồi `ProgressFromTo(0.8, 100, 0)` + `setType "ccw"` |

Ba thứ **cố ý KHÔNG làm**, ghi rõ để lần sau không đoán:
* **`setPercentage`** — ~~cố ý không làm~~ **đã làm xong ở lượt sau**, xem mục 8
  việc 8. Giữ lại đoạn này vì nó là **bản ghi của một kết luận SAI**, và sai ở
  chỗ nào thì đáng nhớ hơn cả kết luận đúng: ghi cũ ở đây nói "quét cả 325 bản
  ghi ở **mọi** offset 4 byte **không** tìm ra cặp float nào khớp midpoint
  `(0.5,0.5)` hay barChangeRate `(1.0,0.0)" — phép quét ấy **đúng**, nhưng nó
  chỉ đi tìm **hai trường của Cocos2d-x gốc**, mà lớp `CCProgressTimer` của
  engine này **không dùng** hai trường ấy: nó có ba trường của riêng nó ở
  `+0xF4`/`+0xF8`/`+0xFC` (kiểu, phần trăm, cờ), và kiểu thì **chỉ có một số
  nguyên**, không có cặp float nào để tìm. Đường thứ hai ghi ở đây — "đọc thẳng
  `layout_ref/*.json` thì cả 325 node chỉ mang đúng bộ trường chung" — cũng
  **đúng khi đọc, và sai khi suy**: `layout.py` khi ấy **chưa được bảo mang ba
  trường ấy ra** (`KEEP_TIMER`), nên cái không thấy là do **bộ trích của ta**,
  không phải do bản ghi. Bài học: **"tôi quét mà không thấy" chỉ mạnh bằng danh
  sách những thứ tôi đã bảo bộ quét đi tìm.**

  **Câu cũ ngay trên đây — "bản gốc không hề gọi `setType` (0 chỗ)" — đã SAI, nay
  sửa.** Bản gốc CÓ gọi, **đúng một chỗ**: `sc/user/UI/CUIDownload.lua:65` và
  `:67`, qua `S_CCCallFunc:create(ptLoadingGamePercent, "setType", "cw")` rồi
  `"ccw"`. Phép grep `:setType(` **không bao giờ thấy** nó, vì tên method được
  truyền dưới dạng **chuỗi** cho `CCCallFunc` — nên đây là một cái bẫy của phép
  đếm, ghi lại để lần sau đừng lặp: **grep tên method bỏ sót lối gọi theo chuỗi.**

  Đọc thẳng thân hàm (thunk bind `0x2bd438` → thân thật `0x2bd2d8`) thì `setType`
  nhận **chuỗi**, và engine nhận **đúng sáu tên** — `ccw`, `cw`, `lr`, `rl`, `bt`,
  `tb` — đọc ra từ sáu ô hằng số PC-tương-đối (`0x2bd420` → `ccw` `0x7aceca`, `cw`
  `0x7acece`, `lr` `0x7aced1`, `rl` `0x7aced4`, `tb` `0x7aced7`; còn `bt`
  `0x7a7a78` nằm khác vùng chuỗi). Sáu tên chia làm hai lối:

  * `ccw` / `cw` **không** đặt hình dạng gì, chỉ gọi `0x4c9030` với **1** / **0**.
    Hai con số ấy đọc ra được nhờ **thanh ghi**: nhánh `ccw` nhảy thẳng tới lệnh
    `bl`, **bỏ qua** lệnh `mov r1, r5`, nên `r1` vẫn là **1** đặt từ trước; nhánh
    `cw` đi qua lệnh đó nên `r1 = 0`.
  * `lr` / `rl` / `bt` / `tb` truyền **0**, rồi đặt thêm **hai** method nhận một
    cặp float, ở **vtable `+0x280`** và **`+0x288`**:

    | tên | `+0x280` | `+0x288` |
    |---|---|---|
    | `lr` | (0, 0) | (1.0, 0) |
    | `rl` | (1.0, 0) | (1.0, 0) |
    | `bt` | (0, 0) | (0, 1.0) |
    | `tb` | (0, 1.0) | (0, 1.0) |

    Cột `+0x288` là **trục**: `(1,0)` cho hai tên ngang, `(0,1)` cho hai tên dọc —
    khớp `barChangeRate` của Cocos2d-x. Cột `+0x280` là **điểm mốc**, chỗ thanh
    mọc ra. **Đây là suy luận có cơ sở, KHÔNG phải phép đo**: hai slot
    `+0x280`/`+0x288` **không có bản ghi bind nào** trong cả 132 bảng lớp — không
    hề lộ ra cho Lua, nên **tên** của chúng không đọc được từ bảng bind (khác
    `setGray` ở `+0x290` và `setOrange` ở `+0x298`, cả hai đều **có** bản ghi).
    Con số thì đo được; tên thì không, và đã ghi rõ là không.

  **Có HAI lớp progress timer, không phải một** — danh sách cũ chỉ nói tới
  `CCProgressTimer`. `setPercentage` / `getPercentage` / `setType` xuất hiện
  trong **đúng 2** bảng lớp: `CCProgressTimer` (lớp 20) và `CCProgressWithClock`
  (lớp 125), **cả hai đều 71 bản ghi**, và cả hai **dùng chung** địa chỉ mã
  (`getPercentage` `0x2bccb5`, `setPercentage` `0x2bd095`, `setType` `0x2bd439`).
  Khác nhau ở chỗ: lớp 125 có thêm `setClock` (`0x2bd98b`) / `stopClock`
  (`0x2bda11`), còn `setGray` `+0x290` và `setOrange` `+0x298` thì **chỉ** lớp 20
  có. Nên dựng `ProgressTimer` ở đây là phải dựng **hai** loại. Thêm một dữ kiện
  cho câu hỏi "thanh hay vòng": engine tách hẳn một lớp riêng tên **mặt đồng hồ**
  ra khỏi lớp chung — ghi lại, chưa suy ra gì từ đó.

  Điều này **không** giải được mặc định — mặc định mới là thứ chi phối 325 node
  kia — nhưng chốt được **từ vựng** và chốt được rằng `CUIDownload` là chỗ **duy
  nhất** đặt kiểu bằng tay. Thêm một suy luận nữa (ghi rõ là suy luận, **chưa**
  đưa vào mã): vì `ccw`/`cw` không đặt hình dạng gì, mặc định của engine **hợp
  với kiểu vòng** — nếu mặc định là thanh thì hai tên ấy đã phải đặt cặp float.
* **`getLimitShowCount` / `getLetterEx` (48)** — đây là chế độ **tách từng chữ
  thành sprite** của `RichLabel` (`sc/user/Public/RichLabel.lua:550-554`), nằm
  trong lớp C++ `Label`. Trả 0 thì `spriteArray` rỗng và chữ vẫn hiện bình
  thường, nhưng đó là **đoán** một con số của engine — không làm.
* **`IsEnableGradualColor` (10) / `enableGradual` (1)** — ~~không phải lỗ hổng~~,
  **đã làm xong** (xem mục "Chuyển sắc chữ" ngay dưới). Hai con số trong cột
  "chỗ gọi" là số lần bộ quét **chạy** bắt gặp lúc mở màn hình; đếm **tĩnh**
  trên `sc/` thì `enableGradual` có **8 chỗ gọi thật** ở 5 file và
  `IsEnableGradualColor` có **1** (hai chỗ nữa bị chính bản gốc comment lại).
  Câu cũ ở đây — "`GradualColor` xuất hiện **0 lần** trong toàn bộ `layout_ref/`,
  tức mọi nhãn đều không phải nhãn chuyển màu, và `nil` của ta cho ra **đúng
  nhánh** mà bản gốc đi" — là **một kết luận SAI**, giữ lại vì chỗ sai đáng nhớ:
  phép quét ấy **đúng**, nhưng nó trả lời câu "trong **bố cục** có nhãn chuyển
  màu sẵn không", trong khi câu phải hỏi là "**mã gốc có gọi không**". Nhãn
  chuyển màu do **mã** bật lúc chạy, nên "bố cục không có" **không** suy ra được
  "không cần làm".

### Chuyển sắc chữ (`enableGradual` / `disableGradual` / `getEnableGradualColor` / `IsEnableGradualColor`)

Bốn hàm này **chỉ** có ở lớp 12 `Label`: quét cả 132 bảng lớp của `libgame.so`
chỉ ra đúng bốn bản ghi, tất cả ở lớp 12 (`enableGradual` `0x002cab6d`,
`disableGradual` `0x002ca8f3`, `getEnableGradualColor` `0x002ca6e5`,
`IsEnableGradualColor` `0x002ca5c1`); `CCLabelTTF` (89 bản ghi) và
`CCLabelBMFont` (101) **không** có hàm nào trong bốn, cũng không có
`setDimensions` / `autoFixSize`. Nhưng phép kiểm "node nào" **không thể** là
`type_name == 'Label'`: **đo được** rằng node `.xgg` mang `typeName` là
`CCLabelTTF` lại **là lớp 12 lúc chạy** — `brave-cross/work/emu_nhan.py` gọi
được `setDimensions` / `getDimensions` / `autoFixSize` (ba API chỉ lớp 12 mới có)
lên node `ttfPopDialogContent` của `conf/Pop_Dialog_UI_960_640.xgg`, còn
`layout_ref` (33.472 node) **không có node nào** mang `typeName` là `Label`. Nên
cổng nhận node là "**mọi nhãn của bản port, trừ `CCLabelBMFont` / `CCRichLabel` /
`CCEditBox`**".

Thân hàm thật (`0x4f7ff0`) đọc ra: hai phép kiểm `LabelType` (`+0x218`) và
`LabelEffect` (`+0x2ec`) **chỉ ghi log** rồi đi tiếp; `+0x3a0 = 1`; đổi shader
sang `ShaderLabel_Gradual`; bốn `glGetUniformLocation` → `v_coordYRange` =
`+0x3a4`, `v_colorBegin` = `+0x3a8`, `v_colorEnd` = `+0x3ac`, `v_textColor` =
`+0x308`; hai `memcpy` 16 byte (đối số 1 → `+0x380` = **begin**, đối số 2 →
`+0x390` = **end**). Hàm bọc `0x2cab6c` **đòi đúng 6 đối số** (`cmp r0,#6; bne`
in `enableGradual Error!` rồi **không làm gì**) và chia mỗi số cho 255; bốn ô
alpha được điền sẵn 1,0. Cờ khởi tạo **0** (hàm dựng `Label` `0x4f8a24` ghi
`+0x3a0 = 0`), `enableGradual` ghi 1, `disableGradual` (`0x4f8136`) ghi 0 rồi trả
node về chương trình thường. `getEnableGradualColor` (`0x2ca6e4`) đọc **sáu** số
theo thứ tự (begin rồi end), nhân 255, và **không bao giờ đọc alpha**;
`IsEnableGradualColor` (`0x2ca5c0`) đẩy cờ ra dạng boolean.

**Chiều — chỗ dễ làm ngược nhất.** Chương trình số 8, nguồn ở `.rodata 0x7cbcac`
(909 byte):

```glsl
float a = abs(v_texCoord.y - v_coordYRange.x) / abs(v_coordYRange.y - v_coordYRange.x);
resultColor.rgb = v_colorBegin.rgb*a + v_colorEnd.rgb*(1-a);
resultColor.a = texColor.a;
gl_FragColor = v_fragmentColor*resultColor;
```

`v_coordYRange` được nạp bằng `glUniform2f(prog, +0x3a4, quad+0x14, quad+0x5c)`
(`0x4f708a..0x4f70d4`), đúng là `tl.texCoords.v` và `br.texCoords.v` của
`V3F_C4B_T2F_Quad` (`tl` ở `+0x14`, `br` = `3*24+0x14` = `+0x5c`) — và v của
Cocos **tăng xuống dưới**. Nên `a = 0` ở **đầu** ô ⇒ đầu ô = `v_colorEnd` = bộ ba
**thứ hai**, cuối ô = bộ ba **thứ nhất**.

**Một cái bẫy của Godot đã mắc và đã sửa — `VERTEX` trong `fragment()` là toạ độ
KHUNG VẼ, không phải toạ độ node.** Bản port viết
`a = VERTEX.y / chieu_cao` trong `fragment()`, và `tools/do_chuyen_sac.gd` bắt
được: nhãn cao 55 điểm ảnh đặt ở `y = 8`, nét chữ ở hàng 22..50 của khung, kênh đỏ
ra **đúng `y_khung / 55`** (lệch nhất 1,1807 trên hàng 47) chứ không phải
`(y_khung − 8) / 55` — tức phép chia đã **ăn cả vị trí của node**. Sửa bằng cách
ghi `VERTEX.y` (lúc còn ở không gian cục bộ, trong `vertex()`) ra một biến varying
rồi dùng nó trong `fragment()`. Sau khi sửa: **29/29 hàng** khớp công thức với
**lệch 0,0000**, và lượt chụp thứ hai (dời node thêm 16 điểm ảnh) ra nét chữ dời
đúng 16 còn **màu thì y nguyên**. Đây là lỗi **im lặng**: dải vẫn ra, chỉ ra lệch
theo chỗ node đứng — và nó chỉ hiện ra ở màn hình thật, nơi nhãn không nằm ở gốc
khung vẽ.

**Đường của màn hình.** Không màn nào gọi thẳng `enableGradual` để tô xám: mã gốc
gọi `g_CUIPublic:SetEnableGradualLableGray(btnText, bGray, szBtnText)`
(`sc/user/Public/CUIPublic.lua:438`), hàm này **có cổng riêng**
(`if btnText.IsEnableGradualColor == nil or not(btnText:IsEnableGradualColor())
then goto Exit0 end`, `:441` — nên nhãn chưa từng bật thì nó **bỏ qua**, không
đụng tới màu riêng của nhãn), nhánh xám gọi `enableGradual(192,192,192,192,192,192)`
+ `setEffectColor(0,0,0,125)`, còn nhánh **trả lại** gọi
`enableGradual(c.r2, c.g2, c.b2, c.r2, c.g2, c.b2)` (`:474`) — **LÀM PHẲNG** dải
bằng chính bộ ba **thứ hai**, chứ không trả lại dải gốc. Đó là quy của mã gốc, và
bộ kiểm khoá luôn **thứ tự** sáu giá trị: trả ngược hai bộ ba thì chỗ này ra
`(255,210,100)` thay vì `(255,255,190)`.

Tám chỗ gọi `enableGradual` trong `sc/` (5 file) — `CUIContestBattleInfo.lua:414`,
`CUIContestSchAnimation.lua:51`, `CUIUserInfo.lua:769` và `:772`,
`CUIWCSBattleInfo.lua:441`, `CUIWCSSchAnimation.lua:51`, cộng hai chỗ trong
`CUIPublic.lua` ở trên. Bản port: `ui/chuyen_sac.gdshader` (nguyên văn công thức,
kèm đoạn mã gốc trong chú thích), `ui/chuyen_sac.gd` (vật liệu **của từng node** —
hai màu là **tham số**, nên không dùng chung được như `ui/xam.gd` / `ui/sang.gd`,
và vật liệu được nhớ trong meta của node để `go()` biết cái nào là của ta),
`lua/cocos.lua` (bốn phương thức + bảng trạng thái **khoá theo `get_instance_id()`**,
vì `boxed` giữ userdata bằng tham chiếu **yếu**: khoá theo userdata thì nó có thể
bị thu gom giữa hai lần gọi và cờ "đang bật" biến mất **im lặng**, làm cổng
`IsEnableGradualColor` ở `CUIPublic.lua:441` chặn hết mọi nhãn).

**Khoá:** `tools/verify_chuyen_sac.gd` (51 đạt / 0 hỏng — đọc thẳng file
`.gdshader` để bắt phép trộn ngược chiều, kiểm phần nối dây và **chạy đúng đường
của màn hình**, tức `g_CUIPublic:SetEnableGradualLableGray` thật) và
`tools/do_chuyen_sac.gd` (15 đạt / 0 hỏng — đo trên điểm ảnh thật, cần trình vẽ
nên **không** nằm trong `check.py`, cùng lối `do_xam.gd` / `do_sang.gd` /
`do_tron.gd`). Một chỗ **lệch đã biết**: `getEnableGradualColor` của bản gốc trả
`255 × float32(r/255)` (đi qua `vmul.f32`), bản port trả **đúng con số đã truyền
vào** — khác nhau ở chữ số cuối của float.

### Hệ hạt (particle): bố cục CÓ ghi tệp hạt — lỗi ở bộ đọc của ta, đã sửa

Lượt này đo cho hết câu "`stopSystem` / `resetSystem` / `pauseActions` thiếu thì
hỏng cái gì", và sửa luôn một kết luận **sai** của lượt trước. Số đo, không suy:

* `layout_ref/` có **87** node `CCParticleSystemQuad` (`type` = **5**) trên **23**
  màn hình, trong **15** giá trị `cls` khác nhau; **78** node để `visible = false`,
  **9** để hiện; **11** node mang tag (`99` **×9**, `3` ×1, `1` ×1). Tag `99` khớp
  đúng lối mã gốc tìm hạt: `CUIFriend2.lua:470-471` gọi `btn:getChildByTag(99)`
  rồi `(100)`. — Lượt trước ghi `99` ×8 và `1` ×2: **sai**, đếm lại ra 9/1/1.
* Về `w`/`h`: **81** node là 0×0, còn **6** node là **40×40** — và 6 node có cỡ ấy
  đúng là 6 node mà mã gốc **điều khiển bằng tên** (`cpCampsFireSmall`,
  `cpCampsFireBig`, `particleDestinyStar1..4`), tất cả đều `visible = false`. Lượt
  trước ghi "đều 0": **sai** với đúng 6 node này.
* **Câu cũ — "Bố cục KHÔNG nói hạt nào" — SAI, đã sửa.** Bản ghi `.xgg` CÓ ghi
  tệp hạt, ngay sau hai chuỗi tên. Đọc thẳng byte của
  `vn/decrypted/assets/conf/UI_ArmyGroup_Campsite_Info_960_640.xgg` tại `0x955b`:

  ```
  cpCampsFireSmall cpCampsFireSmall ../map/beachfiresmall.plist
  ```

* Vì sao bộ đọc của ta ra rỗng — đo được, và là một cái bẫy đáng nhớ: bản ghi node
  của hạt dài **232 byte**, và 232 là kích thước **dành riêng** cho hạt (quét cả
  `assets/conf`: **85/85** bản ghi 232 byte đều là `CCParticleSystemQuad`). Ở bản
  ghi 232 byte, ô `res` quen thuộc (`+0x70`/`+0x74`) có **độ dài bằng 0** cho
  **cả 87** node, nên `xgg.py` trả chuỗi rỗng và `layout_ref` ghi lại chuỗi rỗng.
  **Nhưng địa chỉ ở `+0x70` vẫn đúng**: nó trỏ vào đúng chỗ chứa đường dẫn tệp hạt
  trong kho chuỗi — đo: `+0x70` của **cả 87** node **trùng khít** địa chỉ `+0xE0`.
  Độ dài thật nằm ở **`+0xE4`**.
* Đã kiểm `+0xE0` là ô **duy nhất**: quét mọi cặp `(địa chỉ, độ dài)` thẳng hàng 4
  byte trong cả bản ghi 232 byte → **85/85** node (cây `decrypted`; 87/87 trên cây
  `vn/decrypted`) có **đúng một** ô cho ra chuỗi `.plist`, và ô đó là `+0xE0`;
  không node nào có hai.
* Đọc ra **khớp nghĩa**, không phải trùng số: `cpCampsFireSmall` →
  `../map/beachfiresmall.plist`, `cpCampsFireBig` → `../map/beachfirebig.plist`,
  `particleDestinyStar1..4` → `../png/particle/StarTrail.plist`,
  `g_mail*Particle*` → `../map/finishfirework.plist`. **7** tệp khác nhau, và **cả
  7 đều có thật** trong `assets/` (giải tương đối theo `assets/conf/`). Một tên có
  **dấu cách lạc** trong chính bản gốc — `../map/buttonbling .plist` (74 node) — và
  tệp trên đĩa cũng mang đúng dấu cách ấy; chép nguyên văn, không sửa.
* **Một luật tổng quát đã bị BỎ, ghi lại để lần sau đừng thử lại.** Luật ấy là
  "nếu `+0x74` bằng 0 thì tìm trong bản ghi một cặp `(địa chỉ, độ dài)` có địa chỉ
  bằng `+0x70`". Nó **đúng** cho hạt nhưng **sai** ở bản ghi 320/352 byte: ô
  `+0xDC` ở đó tình cờ mang đúng giá trị địa chỉ ấy rồi giải ra chuỗi `'2'`/`'1'`
  (cỡ chữ của `CCLabelTTF`) — **8.328 node** trùng số chứ không trùng nghĩa (đo
  lại cả cây `vn/decrypted/assets/conf`: bản ghi 320 byte **299**, 352 byte
  **8.029**, trong đó **7.726** ra chuỗi ngắn ≤ 2 ký tự). Nên luật phải **theo
  kích thước bản ghi**, cùng lối với bảng `IMG_FIELD` đã có trong
  `xgg.py`. Sửa vào `xgg.py`: `RES_FIELD = {232: 0xE0}`. Hai con số ghi ở các
  lượt trước — **8.176** (trong `xgg.py`) và **8.968** (ở đây) — **không phải**
  kết quả của phép đo này (`8.968` là tổng số `CCLabelTTF` của cả cây), nay sửa
  lại cả hai. Kiểm không làm đổi thứ khác: đối chiếu cách đọc cũ với cách đọc mới
  trên **33.472 node** — đúng **87**
  node đổi, tất cả đều là hạt.
* Bản gốc có **33** `.plist` chứa `maxParticles` (định nghĩa hạt thật) trong cây
  `assets/` — đo bằng `plistlib` trên **cả cây** chứ không bằng `grep` (lượt trước
  ghi 32 vì `grep -l` chạy trên danh sách do shell mở rộng, thiếu một tệp). Con số
  đúng của **cả cây** là **534** `.plist`, phần lớn là atlas khung hình. Cả 33 tệp
  hạt đều có **đủ 51 khoá** của lược đồ Cocos 2.x (không tệp nào thiếu khoá). Bảy
  tệp được bố cục dùng đều nằm trong 33 tệp ấy, và mỗi tệp khai cả `maxParticles`,
  `particleLifespan` lẫn `textureFileName`: `beachfiresmall` 20 hạt / 0,2 s /
  `firefog.png`; `beachfirebig` 80 / 0,8 / `firefog.png`; `buttonbling ` 36 /
  0,511 / `buttonbling.png`; `finishfirework` 100 / 0 / `finishfirework.png`;
  `StarTrail` 20 / 0 / `StarTrail.png`; `NewYearSnow` 95 / 10 / `NewYearSnow.png`;
  `ChristmasSnow` 188 / 10 / `ChristmasSnow.png`.
* **Sáu ảnh hạt ấy đã nằm sẵn trong `ui_ref/` của bản port** (`.pkm` → PNG do
  `uiart.py` giải, kèm `.import`), và engine **có** bộ đọc plist hạt
  (`maxParticles`, `particleLifespan`, `textureFileName` đều có trong
  `libgame.so`). Nên **không thiếu gì** cho việc dựng hạt: bố cục → `.plist` →
  khoá + ảnh → `.pkm` mà bản port đã giải được từ trước.

Ngoài lề nhưng cùng phép đo, ghi lại làm **manh mối**: chính khối đuôi ấy còn giữ
**tên hiệu ứng âm thanh** ở ô `+0xC0` của bản ghi 216/244/248/260 byte — **2.095**
node, **2.095/2.095** đều là chuỗi bắt đầu bằng `event:` (10 tên khác nhau, nhiều
nhất là `event:/UI/UI_Click` 1.455 node). Khớp với mã gốc:
`CUIEpicChapter.lua:282` và `CUISelectLevel.lua:1687` gọi
`setSoundStrArr({"event:/UI/UI_Click"})` — **đúng chuỗi ấy**. Chưa đo node nào ứng
với âm nào, nên **không kết luận**; đây là chỗ để tra tiếp cho `setSoundStrArr`.

### Hệ hạt: đã dịch xong sang `GPUParticles2D` (33 định nghĩa, 87 node)

Các lượt trên chỉ đo được **chỗ tắc** (node hạt rơi vào `"layer"` rồi thành
`Control` rỗng 0×0, `stopSystem`/`resetSystem` là no-op có đếm trong `M.missing`).
Lượt này dịch hết, và khoá lại bằng một bộ kiểm.

Đường đi: bố cục → trường `res` → `.plist` → `hat_ref/*.json` →
`ui/hat.gd` dựng `GPUParticles2D`. Bộ bóc là `brave-cross/work/hatref.py`, nhận
diện tệp hạt bằng khoá `maxParticles` — cần vậy vì cả cây `assets/` có **534**
`.plist` mà phần lớn là atlas khung hình. Lớp Lua `lua/hat.lua` nối ba hàm
(`stopSystem` **13** chỗ gọi, `resetSystem` **9**, `isActive` **0** — lượt trước
ghi `resetSystem` 17, **đếm lại bằng `grep -rho "[:.]resetSystem(" sc/` ra 9**;
`setTotalParticles` và `setDuration` thật sự là 0) và đăng ký
trong `bootstrap.lua`, đúng chỗ ba cái tên ấy từng rơi vào `__index` của `Node`
rồi trả về một hàm đếm lại (bóng — gọi được, không báo lỗi, không tắt gì).

Bốn chỗ Cocos và Godot làm khác nhau, và cách khớp. Mỗi dòng dưới đây truy về một
lệnh trong chuỗi shader của `ParticleProcessMaterial` — chuỗi ấy nằm **nguyên
trong** `Godot_v4.7.2-stable_win64.exe` (vùng ~`0x7309000`–`0x730c400`), nên đọc
được thay vì đoán:

| chỗ khác | Cocos | Godot | cách khớp |
|---|---|---|---|
| thời gian sống | hai phía, `[L−v, L+v]` | **một** phía: `params.lifetime = (1.0 − lifetime_randomness·rand)` (`0x730b0e`) → `[T(1−r), T]` | `T = L+v`, `r = 2v/(L+v)` chặn ở 1 — khớp **đúng**; khi `v ≥ L` thì ra `[0, L+v]`, **cũng** là dải có hiệu lực của Cocos vì hạt thời gian sống âm chết ngay. Đối chiếu chéo: `process_orbit_displacement(..., params.lifetime * LIFETIME)` — tức `LIFETIME` là nền, tham số kia là hệ số rút |
| trục y của lực | `gravityy` hướng xuống | `force = gravity` (`0x730be92`) rồi `USERDATA1.xyz += force * DELTA`, đơn vị pixel/giây² | lật dấu: `gravity = (gx, −gy)`. Cùng thứ nguyên nên **không** phải đổi đơn vị |
| gốc của góc | ngược chiều kim đồng hồ, y hướng lên | y hướng xuống | `direction = (cos(−a), sin(−a))`, `spread = angleVariance` (Godot cũng nhận **nửa góc**, `angle1_rad = rand_m1_p1()·spread_rad + atan2(...)`) — cùng luật `rot` của bố cục |
| hệ toạ độ | hạt sống trong hệ **của node** | `local_coords` mặc định `false` | `local_coords = true` — đúng tính chất mà `CPublic:playButtonParticleSystem` dựa vào để hạt bay theo action của nút |

Phần dịch còn lại, cũng theo số đo: `scale_curve` **NHÂN** vào `scale`
(`parameters.scale *= texture(scale_curve, …)`), nên đường cong là `1,0 →
finish/start`; `scale_min/max` chia **bề rộng ảnh** vì kích thước trong `.plist`
tính bằng pixel của ảnh gốc còn Godot phóng theo tỉ lệ — và **cả 6 ảnh hạt đều
vuông** (firefog 256×256, năm ảnh còn lại 64×64) nên một trục là đủ **và đúng**;
hộp phát là phân bố đều trong `±sourcePositionVariance` (`pos = vec3(rand·2−1, …) *
emission_box_extents`); `amount = maxParticles` (nhịp phát hiệu lực là
`amount/lifetime`, theo tài liệu `GPUParticles2D.amount` — nên `amount` **không**
phải nhịp phát); `fixed_fps = 60` vì bản gốc cộng vận tốc theo **từng khung vẽ**;
`visibility_rect` mở rộng theo **chính định nghĩa** — `(tốc độ + phương sai)·T +
biên độ phát + ½·|gy|·T²`, cộng 64 — vì mặc định của Godot chỉ `±100` quanh gốc,
hạt bay xa hơn sẽ biến mất khi node ra khỏi màn, còn bản gốc vẽ vô điều kiện.

Phép trộn: **31/33 định nghĩa khớp ĐÚNG** một chế độ của `CanvasItemMaterial` —
`(770,1)` → ADD **25**, `(1,771)` → PREMULT_ALPHA **5**, `(770,771)` → MIX **1**
(cặp thứ ba này lượt trước đếm sót — đã đếm lại, nên số định nghĩa khớp đúng là 31
chứ không phải 30). Hai cặp còn lại không có phép tương ứng trong Godot:
`(772,1)` (`map/finishfirework`, **đang được dùng**) và `(775,1)`
(`map/LvBuFireP`) → dùng ADD và ghi rõ là **xấp xỉ**.

Bốn khẳng định trong chú thích `ui/hat.gd` nay là **phép kiểm**, không còn là câu
chữ — vì mỗi cái là một nhánh mã **không dựng**, hoặc một phép chia cho 0:
`duration < 0` ×**33** (nên **không** dựng cửa sổ phát hữu hạn: dựng thì không có gì
để kiểm; riêng `map/finishfirework` là `−0,55` chứ không phải hằng số
`kCCParticleDurationInfinity = −1`, nên đó là một **cách đọc** chứ không phải số đo,
và cách đọc ngược lại sẽ làm quả pháo hoa ấy không bao giờ phát hạt nào dù nó được
đặt ở 5 chỗ), `rotationEnd == rotationStart` ×**33** (nên `angular_velocity = 0` là
**đúng**, không phải xấp xỉ), `L+v > 0` ×**33** (nhỏ nhất `png/particle/StarTrail`
`0 + 1,0`), và không kênh màu nào bằng 0 kèm phương sai. Định nghĩa nào sau này phá
một trong bốn cái đó thì bộ kiểm **báo**, và `ui/hat.gd` cũng `push_warning` lúc chạy.

Cái **KHÔNG** dịch được, ghi ra chứ không làm mờ đi:

* **`sourcePositionx/y` bỏ qua có chủ ý**, trên cơ sở hai phản ví dụ trong chính dữ
  liệu: `spMainUITheme_christmas`/`_newYear` ngồi ở `y = 602,2` trên màn cao 640 mà
  `ChristmasSnow` có `sourcePositiony = 320,6` → tuyết sinh ở `y = 922`, **ngoài
  màn**; còn `buttonbling` có `sourcePosition = (194,1; 185,8)` trong khi node ở
  `(5, 55)`. Bỏ nó đi thì cả hai ra đúng. Phần **phương sai vẫn dùng** (dải tuyết
  rộng ±557 chính là chỗ làm tuyết phủ hết bề ngang). Chưa đo được Cocos có trừ
  `sourcePosition` trong đường vẽ hay không: các khoá ấy **không được mã nào trong
  `libgame.so` tham chiếu trực tiếp**.
* **Phương sai màu lúc CHẾT** (`finishColorVariance*`) và **phương sai cỡ lúc chết**
  (`finishParticleSizeVariance`) — Cocos rút ngẫu nhiên **hai lần độc lập** (lúc
  sinh và lúc chết), Godot rút **một** lần rồi đi theo đường cong tất định. Lúc sinh
  khớp **đúng từng kênh** (kể cả phần chặn ở 1,0 — màu hạt của Cocos đi vào vertex
  colour dạng byte nên cũng bị chặn), lúc chết lấy giá trị trung bình.
* **Các kênh màu biến thiên ĐỘC LẬP** — một tham số gradient chạy cho cả ba kênh
  cùng lúc; lệch này chỉ lộ ở `map/finishfirework` (đỏ ±0,51 / lam ±0,30).
* **Dấu của `tangentialAcceleration`** — hai hệ lật trục y nhau nên chiều trên màn
  hình ngược nhau, và cả 33 định nghĩa đều bằng **0** trừ hai cái không màn nào
  dùng, nên **không đo được**. (`radialAcceleration` thì cùng dấu và khớp thẳng.)
* **Chế độ bán kính** (`maxRadius`/`minRadius`/`rotatePerSecond`) — cả 33 định nghĩa
  đều `emitterType = 0`, tức **không có gì để dựng**, không phải bỏ sót.

`tools/verify_hat.gd` (**bộ thứ 30**) kiểm bốn tầng. **A. Dữ liệu**: 33 định nghĩa,
87 node, 7 định nghĩa được dùng, mọi `res` tra ra định nghĩa — kể cả tên có **dấu
cách thật** `'../map/buttonbling .plist'` (74/87 node dùng nó; khoá **giữ nguyên**
dấu cách, còn khoá ảnh thì không có, đúng như dữ liệu gốc — không tự sửa). **B. Phép
dịch**: **tính lại từng tham số ở chính bộ kiểm**, từ file JSON, bằng công thức viết
độc lập rồi đối chiếu với vật liệu mà `ui/hat.gd` đặt ra — hai đường khác nhau phải
ra cùng số; đây cũng là chỗ bốn khẳng định trên thành phép kiểm. **C. Bố cục thật**:
node trong `UI_ArmyGroup_Campsite_Info` (`cpCampsFireSmall`/`cpCampsFireBig`) và màn
dùng `buttonbling` phải là `HatNode` có con vẽ, neo đúng gốc Cocos, và **không** node
hạt nào bị bỏ lại thành `Control` rỗng. **D. Lớp Lua**: `stopSystem`/`resetSystem`/
`isActive` phải đổi đúng cờ `emitting` của node **thật** (node lấy từ cây bố cục đã
dựng, nên lớp được chọn theo meta `type_name` mà chính `XggLayout._make` đặt), theo
**đúng thứ tự** của `CPublic:playButtonParticleSystem`. **154 đạt / 0 hỏng.**

Một cái bẫy của chính Godot, **đo bằng script thử rồi mới viết mã** (và là lý do
`ui/hat.gd` đặt tham số theo một thứ tự nhất định): **Godot kẹp hai đầu của mọi cặp
min/max vào nhau** — đặt `angle_min = 30` rồi `angle_max = -30` thì ra `(-30, -30)`
(đầu `max` kéo đầu `min` xuống), đặt ngược lại thì ra `(30, 30)`; `scale_min = 2`
rồi `scale_max = 1` cũng ra `(1, 1)`. Nên **đầu thấp phải đặt trước**; đã kiểm lại
thì mọi cặp đang dùng đều đã đúng thứ tự ấy, trừ cặp góc — nay đặt `angle_min`
trước `angle_max`, và bộ kiểm đọc theo đúng thứ tự đó.

### `setGray`: đã giải xong, bằng hai đường độc lập

`setGray(b)` đổi **chương trình shader** của node sang chương trình số 1 của bản
gốc. Ba tầng đã nối được với nhau, không còn chỗ nào là suy đoán:

1. **Tên → chỉ số.** `setGray` gọi `vfunc_0x158("ShaderPositionTextureColor_Gray")`.
   Hàm đăng ký ở `.text 0x4d97ec` dựng **một khối 0x34 byte cho mỗi tên** (nạp
   chuỗi bằng `ldr r1,[pc,#imm]` + `add r1, pc`, dựng `std::string`, rồi
   `movs r2, #<chỉ số>` + `bl 0x4d8e1c`). Gray = **chỉ số 1**.
2. **Chỉ số → nguồn.** Hàm dựng chương trình ở `0x4d8e1c` là một `switch` 18
   nhánh (`cmp r2, #0x11` rồi `tbh`, bảng nhảy ở `0x4d8e2e`). Mỗi nhánh nạp hai
   con trỏ **qua GOT** (gốc `0x92ba60`, tính từ `ldr r5,[pc,#0x388]` + `add r5, pc`
   dùng PC **chưa cắt** — instr+4 — mới ra các ô GOT chia hết cho 4), và ô GOT
   trỏ tới một **phần tử của bảng nguồn** `.data 0x93caec`; phải `ldr` thêm một
   lần nữa mới ra chuỗi nguồn. Chỉ số 1 dùng nguồn đỉnh `N[8] = 0x7ca769` và
   nguồn mạnh `N[18] = 0x7ccf00`.
3. **Nội dung nguồn mạnh** (nguyên văn): `float alpha = texture2D(CC_Texture0,
   v_texCoord).a;`, `float grey = dot(texture2D(CC_Texture0, v_texCoord).rgb,
   vec3(0.299, 0.587, 0.114));`, `gl_FragColor = vec4(grey, grey, grey, alpha);`

Vì sao mọi phép **quét con trỏ** đều cho kết quả âm — và vì sao kết luận cũ
"địa chỉ dựng bằng `movw`/`movt`" là **sai**: địa chỉ chuỗi được dựng bằng
**PC-tương-đối**, ô hằng số giữ `đích − pc`, nên trong file **không hề có** 4 byte
nào bằng địa chỉ chuỗi. `work/shaderghep.py --bang` in ra cả bảng 18 dòng; mỗi
dòng **đều khớp nghĩa với tên của nó** (đối chiếu độc lập: `PositionColor` ra
`gl_FragColor = v_fragmentColor;`, `PositionTextureA8Color` ra
`vec4(v_fragmentColor.rgb, …)`, cả nhóm `Label_*` dùng chung nguồn đỉnh `N[10]`…).

**Bốn tính chất của shader, đo bằng điểm ảnh thật** (`tools/do_xam.gd`, **11/11
đạt** — ảnh thử `(100,200,50)`, nền đen, đọc điểm giữa ảnh):

| | điều đo được | số |
|---|---|---|
| (1) | hệ số Rec.601 ra `153/255 = 0,6000`; Rec.709 cho `0,6585` | cách nhau `0,0585`, gấp 4 lần dung sai `0,01` |
| (2) | `setColor(255,0,0)` rồi xám → **vẫn xám** | `0,6000` — `v_fragmentColor` khai báo mà không dùng |
| (3) | `setOpacity(128)` rồi xám → **vẫn đặc** | `0,6000` — alpha lấy từ **ảnh**, không từ node |
| (4) | node **cha** `modulate 0,5` rồi xám con → **mất luôn phần thừa kế** | `0,6000` chứ không `0,3000` |

(2), (3), (4) là quirks thật của bản gốc, không phải lỗi của ta — và chúng **khớp
sẵn** với Godot, đo chứ không suy: `COLOR` đầu vào của fragment là `ảnh ×
modulate`, và kết quả ghi ra **không** bị nhân thêm lần nào nữa (A1..A3), nên
**ghi đè `COLOR` là bỏ luôn cả `modulate` của chính node lẫn của cha** — đúng bằng
hành vi trên. Shader bỏ thẳng vào được, không phải bù trừ gì. (4) có cơ sở đọc mã:
nguồn đỉnh `N[8]` chỉ có `v_fragmentColor = a_color`, mà `a_color` của cocos2d-x
là màu **hiển thị** — đã gồm màu/độ mờ của cha (`_displayedColor`).

**Đã dựng**: `ui/xam.gdshader` (shader **đầu tiên** của dự án) + `ui/xam.gd`
(`UiXam.dat` — một `ShaderMaterial` **dùng chung**, gắn lên **chính node vẽ**, vì
vật liệu của node cha **không** truyền xuống `Sprite2D` con trong Godot 4 — đo ở
`tools/do_tron.gd`), bắc qua `_godot_dat_xam` trong `game/lua_runtime.gd`, gọi từ
`lua/cocos.lua:setGray`. Khoá bằng `tools/verify_xam.gd` (**28 đạt / 0 hỏng**).

**Chỉ node VẼ có ảnh** mới đi đường shader — từng loại một, đo chứ không đoán:

* `TextureRect` / `NinePatchRect` (`CCSprite` / `CCScale9Sprite`): **có**. Đây là
  loại mà 674 chỗ gọi `setGray` nhắm tới — quét 120 node bố cục trong `_G` thì
  **cả 30 node có `setGray` đều là sprite**.
* `Label`: **không**. Bản gốc tô chữ bằng đường **Lua** (`CUIPublic:SetLableGray`
  — lưu `getColor()`/`getEffectColor()` gốc rồi đặt `setColor(50,50,50)` +
  `setEffectColor(190,190,190)`): đếm được **132 dòng gọi**, trong khi đường
  `setGray` tự đi xuống con (`CPublic:SetObjGray`) chỉ có **3 chỗ**. Thêm nữa,
  shader xám đọc **ảnh chữ** mà atlas chữ thì màu **trắng** — chữ sẽ ra **trắng**
  chứ không ra xám, lại còn mất đường viền. Chính vì vậy trong mã gốc có nhiều
  dòng `setGray` trên biến nhãn **đã bị comment sẵn** (`--pBtnText:setGray(true)`).
* **Đây là kết quả ĐO, không phải suy luận.** Đọc bảng bind của `libgame.so`
  (`brave-cross/work/binder.py`; 132 lớp, 3.523 bản ghi method, và **131/132**
  bảng kết thúc bằng đúng bản ghi 12 byte toàn số 0 — nên mốc chặn là thật, không
  phải chỗ đọc tràn): `setGray` có **đúng 5 lớp** — `CCSprite`, `CCScale9Sprite`,
  `CCButton`, `Label`, `CCProgressTimer` — và **`CCLabelTTF` thì KHÔNG có**. Nên
  với **nhãn chữ thường** (`CCLabelTTF`) thì lời gọi `setGray` ở bản gốc **không
  thể** chạy: nó ném lỗi Lua thật ("attempt to call method 'setGray'").
  Cùng phép đo ấy: `CCLayerColorRoundRect` cũng **không** có `setGray`, còn
  `setOrange` chỉ có trên **một** lớp duy nhất là `CCProgressTimer` — khớp đúng
  **6 chỗ gọi** `setOrange` trong mã gốc, cả 6 đều là progress timer. Và
  `setIsSwallowInBegan` cũng **chỉ có một lớp duy nhất** là
  `CCLayerColorRoundRect`, khớp đúng **8 chỗ gọi** trong mã gốc — cả 8 gọi
  **trần** (không có `if X.setIsSwallowInBegan then`), nên 8 node ấy buộc phải
  thuộc lớp đó; kiểm được **8/8** từ `layout_ref` (6 theo tên, 2 theo tag vì
  chúng không có tên) — xem §8 việc (d).
  Một chi tiết nữa, cũng đo được: `setGray` **không phải một hàm duy nhất** —
  `CCSprite` và `CCButton` dùng **chung** một địa chỉ mã (`0x49d70d`),
  `CCScale9Sprite` riêng (`0x2d2839`), `Label` riêng (`0x2cb1c9`), còn
  `CCProgressTimer` thì đi qua **slot** `+0x290`. Bốn đường, không phải một.
* **Nhưng đừng vì thế mà bảo mọi dòng `setGray` bị comment là vì thiếu method —
  đã kiểm và KHÔNG đúng.** Các dòng bị comment nằm **liền với** một lời gọi
  `SetLableGray` ngay trên nó (`CUIHeroInfoMainUI.lua:190-191` và `:200-201`:
  `g_CUIPublic:SetLableGray(pBtnText, false)` rồi `--pBtnText:setGray(false)`),
  tức đó là một lần **đổi đường** chứ không phải một lời gọi sai. Và người nhận
  không chỉ toàn nhãn chữ: có cả **nút** (`buyButton` CUIActivityFund.lua:246,
  `replayButton` CUIArenaRecord.lua:186, `btn` CUIHeroInfoFightSoulUI.lua:697) mà
  `CCButton` thì **có** `setGray` — ở những chỗ đó, comment là **lựa chọn**, không
  phải bắt buộc. Chưa đo được **từng dòng một** (tên biến khác nhau theo từng màn
  hình, không suy từ tên), nên ở đây không kết luận thay.
* `ColorRect` (`CCLayerColorRoundRect`): **CHƯA LÀM, và không đoán bừa.** Trong
  mã gốc có đúng **12 chỗ** gọi `setGray` nhắn vào năm biến tên kiểu lớp/nền.
  Đã tra tận nơi **từng chỗ một** bằng bố cục gốc (`layout_ref/*.json`, đi theo
  `getChildByTag`), và đối chiếu **hai chiều với tên biến** — tên trong mã gốc
  mách loại node (`Sp`, `ttf`, `Bg`), nên đọc ra loại nào thì phải khớp tên đó:

  | chỗ gọi | loại đo được | nguồn |
  |---|---|---|
  | `lItemBackground` ×2<br>(CUIActivityLoginTurnplate.lua:204/211) | **CCSprite** | dòng 186 gọi `setDisplayFrame` trên chính nó |
  | `bgview` ×2<br>(CUISign.lua:1006/1020) | **CCScale9Sprite** | `view:getChildByTag(1)`, `tvTemplate = lLuxurySignTemp` (CUISign.lua:727); trong `UI_SignInReward_960_640` node đó là scale9, và các con khớp từng tag `_initCell` đọc: tag 6 = `CCLabelTTF` (`ttfSignTimes`), tag 5 = `CCScale9Sprite` (`unRewardBgSp`), tag 2 = `CCButton` (`rewardBtn`) |
  | `pOrdinaryBg` + con tag 4/5 ×3<br>(CUIActivityLoginRewards.lua:328/329/330) | **CCScale9Sprite**<br>+ 2 × **CCSprite** | trong `UI_RotatingActivity_UI_960_640`, tag 1 của `lActivityLoginRewardsItemTemplate` là scale9, hai con tag 4/5 là sprite; khớp: tag 3 là `CCLabelTTF` mà mã gốc gọi `setString` lên nó, còn tag 4/5 thì `SetTitleCloseAlignment` (`CPublic.lua:2321`) đặt hai bên tiêu đề |
  | `upgradeLayer`/`completeLayer` ×5<br>(CUIResearch.lua:419/430/443/461/489) | **chưa xác định được** | `conf/UI_Research_UI_960_640.xgg` **không có** trong APK gốc — nằm trong danh sách **6 bố cục thiếu `.xgg`** ở mục 4, nên không có bố cục nào để tra |

  Vậy **7 chỗ là node VẼ có ảnh** — đã đi đường `TextureRect`/`NinePatchRect` ở
  trên rồi, không rơi vào trường hợp này. **5 chỗ còn lại ghi là CHƯA BIẾT**,
  không suy diễn.

  Lý do không làm: lớp màu **không có ảnh**, mà chương trình xám của bản gốc thì
  đọc `CC_Texture0` — với lớp màu thì texture đó **không được gắn**, nên kết quả
  là rác của GL chứ không phải một màu nào suy ra được. Gắn shader đọc ảnh ở đây
  thì Godot lấy ảnh **trắng** mặc định và lớp màu biến thành **trắng** — sai rõ
  ràng; còn tự tính luma của màu nền thì là **suy đoán ý tác giả**, không phải
  phép đo. Muốn biết thật phải mở bản gốc, gọi `setGray` lên **đúng node đang
  được vẽ**, rồi đổi điểm ảnh.

  Ghi chú về số 6 bố cục thiếu `.xgg`: phép đếm trên đối chiếu với `layout_ref/`,
  còn lượt này đối chiếu thẳng với `conf/*.xgg` của APK (307 file) và
  `grep` nội dung cả 307 file — **cùng ra đúng 6 file đó**, nên con số đã được
  kiểm bằng hai nguồn độc lập.
* Node khác (Control rỗng, node mang armature): **không**. Bản gốc chỉ đổi chương
  trình của **chính** node, mà node đó không tự vẽ gì; armature vẽ ở các node
  **con** của nó nên vẫn giữ màu — và gắn vật liệu lên node cha trong Godot cũng
  không có tác dụng gì, tức hai bên khớp nhau.

**Còn lại của phép đo trên máy ảo** (`work/emu_xam.py`): bộ đó **không** dùng để
đo nữa, nhưng giữ lại vì nó là **bản ghi giới hạn của máy ảo**, còn dùng cho mọi
phép đo sau: `getChildren()` và `isVisible()` làm **SIGSEGV** translator (nên
không chạy được `CPublic:SetObjGray` ở đó), `getType()` **cũng chết y như vậy**
(đo 2026-09-16: in xong `KI|nut|ptLoadingGamePercent|userdata` rồi SIGSEGV ngay,
fault addr `0x64041ef1`, `GLThread`; còn `setType` và `setPercentage` thì chạy
bình thường — nên phép đo theo kiểu **không** hỏi lại kiểu mà đo bằng hình vẽ),
`scheduleOnce` báo thành công mà
**không bao giờ chạy**, **một lỗi Lua giết cả tiến trình kể cả trong `pcall`**,
đọc trường metatable **không** dùng được làm phép thử có-mặt với `CDFSpriteRole`
(khác hẳn với việc *gọi* method), và `_G.btnMainStore` **không phải** node đang
được vẽ (đổi chỗ `-3000,-3000` → **0 điểm ảnh**).


### Ô nhập chữ (`CCEditBox`) — 40 ô trong 22 bố cục

Trước lượt này `ui/xgg_layout.gd` xếp `"CCEditBox"` vào `kind "label"`: cả 40 ô
nhập là **nhãn chữ** — không gõ được, và **năm** phương thức của mã gốc rơi vào bộ
đếm `M.missing` mà **không một lỗi nào**. Nay chúng là `ui/o_nhap.gd` (lớp
`UiONhap`), dựng từ `lua/o_nhap.lua`.

**Bảng lớp bind nói rõ năm phương thức ấy thuộc về ai** (đây là chỗ một ghi chú
cũ ghi sai — nó coi `setText` là API **của nhãn** bị thiếu):

| tên | có ở `Node`? | có ở `CCEditBox`? |
|---|---|---|
| `setText`, `getText`, `getTextWithLen`, `setMaxLength`, `setLuaCallbackObjAndFunc` | **không** (`rawget` ra `nil` thật) | **có**, cả năm |
| `setHorizontalAlignment`, `setVerticalAlignment` | **có** (`lua/cocos.lua:1277`, `:1307`) | có, nhưng thừa |

Phép thử phải dùng `rawget` chứ không phải `Node.getText`: bảng `Node` có
metatable trả **hàm đếm** cho mọi tên lạ (đó là cách `M.missing` hoạt động), nên
`Node.getText` **không bao giờ** `nil` — nó là bóng. Phép kiểm trong
`tools/verify_o_nhap.gd` đo đúng chỗ ấy: gọi `setText` trên một **nhãn** thì bộ đếm
`M.missing` tăng đúng 1 và chữ của nhãn **không đổi**; gọi trên ô nhập thì bộ đếm
đứng yên.

**Dữ liệu, đo lại trên `layout_ref`:** 40 node trong **22** file (UI_Login 6,
UI_AccountLogin 8, Test_UI 3, UI_Binding_User 3, Main_Dialog_UI 2, UI_ArmyGroup 2,
16 file × 1). Bản ghi có **hai** hình dạng: **19** trường (**15** node) và **20**
trường khi có `fix` (**25** node); hợp lại đúng **20** tên. Trong 40 bản ghi
**không** có `text`, `alignH`, `alignV`, `touch` hay `touchObj` — nên ô nhập luôn
bắt đầu **rỗng** và **không** có tên chạm nào là đúng dữ liệu, không phải thiếu
sót của bộ đọc.

**Ảnh nền bị CO GIÃN theo ô, không phải ô theo ảnh** — đo bằng cách đối chiếu ô
của từng node với cỡ thật của ảnh (`ui_ref/index.json`):

| ảnh | cỡ thật | số ô | các cỡ ô |
|---|---|---|---|
| `ui_background189.png` | 30×30 | 12 | 150×30 ×6, 204×35 ×2, 260×60 ×2, 200×90, 410×45 |
| `v6/login/ui_background402.png` | 59×59 | 7 | 275×45 ×5, 220×59, 100×50 |
| `ui_button01.png` | 143×61 | 3 | 143×61 ×3 |

Ô nhỏ nhất dùng ảnh 30×30 là **150×30** — rộng gấp **5** lần ảnh. Nên
`UiFrames.set_frame` có nhánh riêng cho `UiONhap` (như đã có cho `TienDo`): đặt
ảnh, **không** đổi ô của node. Hàng cuối là ca đối chứng: `ui_button01.png` (ảnh
**bằng** ô) là cả ba ô được bộ đọc `.xgg` đánh dấu `imgFrom: verified` — tức
`verified` nghĩa là "có ảnh khớp ô", không phải "đoán đúng tên ảnh".

**Lớp `UiONhap` cố ý KHÔNG kế thừa `LineEdit`**, và đây là quyết định **đo được**
chứ không phải sở thích: ba hàm của `lua/cocos.lua` (`la_nhan_chuyen_sac`,
`setString`, `setHorizontalAlignment`) đều hỏi `gd.text == nil` để biết node có
phải **nhãn** không. Một `LineEdit` ở lớp ngoài trả `text` khác `nil`, nên ô nhập
sẽ bị coi là nhãn: bị tô màu chữ theo dải và bị `setString` ghi đè. `UiONhap` giữ
`text` là `nil`, còn chữ thật nằm trong `LineEdit` **con**.

**Bốn sự kiện của bản gốc, và nhịp của chúng khác bản gốc đúng một chỗ.** Bốn tên
`began` / `changed` / `ended` / `return` đọc từ `.rodata 0x7a6a30..0x7a6a90`; mã
gốc chỉ dùng `changed` (`CUIBuyDialogEx.lua:84`) và `return`
(`CUIUserInfoNickName.lua:142`), hai tên kia vẫn bắn ra cho đủ bộ. `self` của hàm
xử lý là **đối tượng tra theo tên toàn cục**, không phải node
(`CUIBuyDialogEx.lua:113-114` đăng ký `("g_CUIBuyDialogEx",
"editboxEventHandler")`). Đo trên `LineEdit` của Godot 4.7.2:

* `began` / `ended` (tiêu điểm) và `return` (Enter) bắn **ngay** trong khung đó;
* `changed` **đời sang khung sau** (`text_changed_dirty` trong `line_edit.cpp`), và
  nhiều lần sửa trong **cùng** một khung **gộp** thành **một** lần bắn, mang chữ
  cuối (gõ `x` rồi `a` trong cùng khung → đúng **một** sự kiện, chữ `xa`);
* đặt chữ bằng mã (`o_chu.text = ...`) **không bao giờ** bắn, kể cả sau một khung.

Bản gốc bắn `changed` ngay trong hàm xử lý phím, mỗi lần một. Một khung trễ và
việc gộp lại là khác biệt **có thật** và **không sửa được** nếu không tự viết lại
phần gõ phím của `LineEdit` — ghi lại ở đầu `ui/o_nhap.gd` để người đọc sau biết
mà đối chiếu. Hệ quả cho phép kiểm: phải gõ **từng phím một** và **chờ qua khung**
(`tools/verify_o_nhap.gd`, hàm `_go`), nếu không thì đếm ra thiếu sự kiện.

**Căn chữ: `setVerticalAlignment` đang thiếu thật, và trên ô nhập thì không vẽ
được.** LineEdit của Godot 4.7 **không có** căn dọc nào — đo cả danh sách thuộc
tính lẫn danh sách phương thức, không một tên nào chứa `vertical`; còn thuộc tính
căn ngang tên là `alignment` và hàm đặt tên là `set_horizontal_alignment` (đo cả
hai danh sách). Ba số của enum khớp nhau (0 trái, 1 giữa, 2 phải) nên ghi thẳng.
Căn dọc **chỉ ghi lại** vào meta, vì tự thu nhỏ ô chữ rồi đổi chỗ là một luật
**khác hẳn** luật gốc (bản gốc đẩy xuống vtable `+0x68` của widget trong). Bốn chỗ
gọi căn dọc của mã gốc đều trên **nhãn** (`CUIBarracks.lua:260,273`,
`CUIResearch.lua:170,211`) và đều chạy được: `CCLabelTTF` là lớp duy nhất trong
bốn lớp có căn ngang mà **không** có căn dọc, nên trên nó lời gọi **không làm gì**
— đúng như đo được, không phải như suy đoán.

**Ba thứ KHÔNG khôi phục được, ghi lại chứ không đoán:**

* **Chế độ mật khẩu / chữ gợi ý** — bản ghi `.xgg` không có trường nào; hợp 20 tên
  trường của 40 bản ghi không có mục nào tương ứng, và cả 973 file mã gốc **không**
  gọi phương thức nào của ô nhập để bật chúng.
* **Đơn vị đếm của `setMaxLength`** — thân hàm (0x2d1bcd) cắt thành số nguyên bằng
  `vcvt.s32.f64` (cắt về phía 0: 3,7 → 3) rồi đẩy xuống widget trong. Giá trị ấy
  **không có hàm đọc nào**, và cả 973 file mã gốc **không gọi `setMaxLength` lần
  nào** (0 chỗ), nên đơn vị đếm của widget trong không khôi phục được. Vì vậy
  `UiONhap.dat_dai_toi_da` **chỉ ghi lại** số đã cắt, **không** tự cắt chuỗi — cắt
  theo một luật khác luật gốc thì còn tệ hơn không cắt.
* **Căn chữ đọc từ `.xgg`** — bộ đọc của ta không trích `alignH`/`alignV` cho
  `CCEditBox`; nhưng vì **không bản ghi nào** có hai trường ấy (cả 40), đây là
  chỗ chưa cần chứ không phải chỗ thiếu.

**Và một lỗ hổng của lớp offline, đo được nhân dịp này.** Bốn hàm `LGG_*` của
engine — `LGG_CheckNickName`, `LGG_CheckNickNameByLanguage`,
`LGG_CheckNickNameIncludeVI`, `LGG_CheckStringLegal` — **không có mã Lua nào định
nghĩa** (quét cả `sc/`: **0** chỗ gán), nên chúng là **bóng**, và bóng thì
**truthy**: `nicknameIsTrue(...) == false` và `if not bLegal` **không bao giờ**
đúng, tức phép kiểm **định dạng** tên không chặn được ai
(`CheckNickName('@@@', 1, nil)` trả `true`). Luật **quá dài** thì **chạy đúng**,
và đo được bằng cách **chạy chính mã gốc**: `getNickNameMaxLength(nil)` = **16**
(nhánh VI — `GetLanguageName()` trả `'vi'` qua `DEFAULT_LANGUAGE` của
`share/Setting.lua:14`), `getNickNameMaxLength(9)` = 9, tám chữ có dấu
(`'ăâđêôơưĐ'`) = **16** đơn vị — **vừa đúng trần**, còn chín chữ = 18 là quá; và
`CheckNickName(rep('a',20), 20, nil)` trả `false` với lỗi `Register_createNicknameToLong`.
Chuỗi nạp tối thiểu để chạy được chính mã ấy: `install_cocos()`, `install()`,
`boot({})`, rồi `require` bốn module (`share.Setting`,
`user.Globals.user_global`, `user.Public.set`, `user.UI.CUILogin`) — đo **53 ms, 0
lỗi Lua**. **Hai cái bẫy của chuỗi này, đều đã mắc:** thiếu `boot` thì `class` là
bóng nên `CUIRegisterVerification` cũng là bóng (`getNickNameMaxLength()` trả về
`<bong ...>` chứ không lỗi), và `KDebug` cũng là bóng — mà
`KDebug.ArgIsNumber` chính là thứ `nicknameFindGM` hỏi, nên thiếu `boot` thì
`nicknameFindGM` trả **true với mọi tên**. Cả hai đều là **tạo tác của chuỗi nạp
thiếu**, không phải lỗi của bản port; phép kiểm vì thế chạy trên chuỗi đầy đủ và
đòi **0 lỗi Lua**.

**Kiểm bằng gì:** `tools/verify_o_nhap.gd` — **67 đạt / 0 hỏng**, `check.py` bộ thứ
**33** (con số "34" ghi ở đây trước kia là **sai một đơn vị**; đếm lại trên `HEAD`:
lúc thêm nó `SUITES` có **33** mục và nó là mục cuối), bốn tầng: (1) dữ liệu `.xgg` ở trên; (2) năm phương thức của `CCEditBox`
đối chiếu với lớp `Node`, thêm bảng trọng số 134 mục của `getTextWithLen` và phép
đối chiếu với chính `CheckNickName` của bản gốc; (3) **đường người chơi** — chạm
vào ô (đúng lượt đi cây, `touch_at`), gõ phím **thật** qua `push_input`, rồi đòi
bốn sự kiện `began` / `changed` / `ended` / `return` bắn ra hàm Lua đã đăng ký,
kể cả hai ca **không** bắn: cặp `('','')` và tên đối tượng không tồn tại; (4) thứ
tự **trên–dưới** giữa ô nhập và node có tên chạm (ô nhập **không** có tên chạm
trong dữ liệu, nên phải đo bằng cây giả có đổi `z_index`).

Một chi tiết **dữ liệu thật** mà phép kiểm bắt được, đáng ghi vì nó dễ bị coi là
lỗi: ba tầng `lCreate` / `lRegister` / `lLogin` của UI_Login **chồng khít** nhau
(cả ba 344×400 ở cùng chỗ) và bản ghi **không** ghi `vis`, nên khi
`respect_visible = false` thì cả sáu ô cùng hiện — đo được `ebRegisterPassword2`
(y=160,5) **phủ lên** `ebUserLoginPassword` (y=150), cả hai 150×30, nên cú chạm
vào ô đăng nhập thuộc về ô của tầng đăng ký. Bản gốc chỉ hiện **một** tầng, nên
phép kiểm tắt hai tầng kia trước khi đo đường gõ — và đòi ô nhập **trên cùng** tại
điểm chạm đúng là ô đang đo.


### Bóng của armature (`_ShowShadow` / `_SetSyncShadowPosY` / `_UpdateShadowPosY`)

Ba tên này có **23 chỗ gọi** trong mã gốc (**20 / 3 / 0**) và trước lượt này
**không hề tồn tại** ở lớp giả lập: tên không có trong bảng `Node` nên rơi vào
`__index`, trả về một hàm đếm rồi trả `nil` — không một lỗi nào, chỉ là bóng không
bao giờ hiện. Cùng loại với `_godot_zsort` và ba hàm điểm gắn.

**Bản ghi cũ xếp việc này là "rẻ — chỉ là bật/tắt bóng", và chỗ ấy SAI.** Đọc mã
máy của `libgame.so` (Thumb) ra ba khẳng định khác hẳn, và cả ba đều thành phép
kiểm được:

* `_ShowShadow` (`0x419f74`) mở đầu bằng `movs r1, #1 ; bl 0x23c17c` — đúng hàm
  `tobool(co, mặc định 1)` mà `setIsSwallowInBegan` đã dùng. Nhánh thật gọi
  `0x419de6(self, 1)`; nhánh giả gọi `0x417e14(self)`.
* `0x419de6` gọi **trước tiên** `0x419668` (tạo bóng), rồi `cmp r0,#0 ; beq` —
  vẫn `nil` thì về luôn; sau đó chỉ khi `self visible` **và** bóng đang ẩn mới:
  sắp bóng về `zOrder −10`, đặt chỗ theo `x` của armature và `Y` mặt đất
  (`self+0x49c`), rồi `setVisible(true)`. Tức **bóng chỉ TỒN TẠI khi có ai đó gọi
  `true`** — không hề được dựng sẵn lúc nạp sprite, và armature đang ẩn thì bóng
  vẫn được tạo nhưng ở lại trạng thái ẩn.
* `0x417e14` là `removeFromParentAndCleanup(true)` + `release()` +
  `self[0xa04] = 0` — **XOÁ HẲN**, không phải làm mờ đi. Lần `true` sau đó tạo lại
  từ đầu, tức là một **đối tượng mới**.

Ba chi tiết còn lại của đường vẽ, cũng đọc từ mã máy:

| thứ | đo được |
|---|---|
| hàm dựng bóng `0x3ca9a8` | một `CCSprite` 0x1c0 byte, `setAnchorPoint(0.5, 0.5)` (hai hằng `0x3f000000`), giữ tham chiếu ngược tới armature ở `+0x17c` |
| tên ảnh | chuỗi hằng `"Shadow.png"` ở `0x7beccd` — **một ảnh dùng chung**, không theo tên sprite |
| `_UpdateShadowPosY` (`0x417ddc` → `0x417d9e`) | truyền float `−1.0` (`0xbf800000`) làm dấu "lấy Y của chính armature" (`*(float*)(self->vtbl[0x78]() + 4)`), rồi đi **đệ quy** xuống con (`0x3c93c0`). **0 chỗ gọi bằng Lua** — vẫn làm cho đủ bảng bind |
| `_SetSyncShadowPosY` (`0x417df9` → `0x417dec`) | `shadow[0x1a6] = tobool(co, 1)`. Trong `.text` **không có chỗ nào đọc** `+0x1a6`, và chỗ gọi `false` duy nhất (`CUIArmyGroupCampsite.lua:738`) đi kèm `_ShowShadow(false)` ngay trên — nên ca "hai cờ khác nhau" **không quan sát được ở bản gốc**. Cách hiểu của bản port vì thế là **ĐẶT**, ghi rõ trong `rig/sng_rig.gd` |

**Số thì có sẵn trong cấu hình gốc, không phải bịa:**

* `map/global_config.xml`, khối `<stage>` dưới chú thích `阴影`: `fShadowScaleRate`
  **0,9** (ngay trên nó là chú thích "mặc định 0.9"), `fSmallShadowScale` 0,6,
  `fBigShadowScale` 1,5.
* Sáu file `map/{hero,heroex,player,sprite,boss,evil}_config.xml`: **19** khối ghi
  số bóng. `fShadowScaleRate` **7** chỗ (0,7 ×3 Hoplite / FengYaoJi / BaiHuZi;
  0,8 ×2 ZhangLiangBao / DongZhuoEvil; 0,76 MaYuanYi; 1,0 ElephantSoldier),
  `fShadowOpacity` **2** (DragonFlight, BatFlight — đều 0,8; chú thích trong
  `evil_config.xml` ghi `阴影不透明度`), `fShadowOffsetRate` **8**, `nShadowSize`
  **7** (cả 7 đều là `2`).
* `sShadow` — tên tài nguyên bóng riêng — có ở **120** khối `<limbs>` (hero 6,
  heroex 1, player 113), tên khối là `limbs_<Tướng>` và giá trị **119/120** đúng
  dạng `<Tướng>Shadow`. Một mẫu lệ: `DaQiao` → `DaQiaoReplica`. Chính mẫu lệ ấy là
  phép thử phân biệt "đọc bảng" với "ghép chuỗi `<Tướng>Shadow`".

**Một bẫy về cây XML đã làm hỏng lượt trích đầu tiên, ghi lại vì nó im lặng.**
`hero_config.xml` **không** có "một `<item>` bọc hết một tướng": `<sprites>` (còn
`heroex_config.xml` thì `<exclusive>`) chứa một **danh sách phẳng các khối anh
em** — đo được **801** khối cấp 1 cho **119** `item` (`fight` 224, `weapon` 109,
`silk` 72, `adapt` 67, `pause` 65, `limbs` 51, `move` 35, `prop` 34…). Nên
`<item>(.*?)</item>` **đứt** ở `</item>` lồng bên trong `<lsAdapt>`, và gộp
`<item>` với `<limbs>` thì **gán sai chủ**. Bộ đọc trong
`brave-cross/work/bong_ref.py` vì thế dựng cây thật rồi lấy khối theo luật **độc
lập với tên phần tử chứa**: một phần tử **có `<sName>` và có ít nhất một khoá
bóng**. Đúng loại bẫy đã mắc với `ptLayout` (xem `CLAUDE.md`).

**Ảnh bóng đã đo, và nó KHÔNG phải gradient mềm.** `png/ribbon/Shadow.pkm`
(ETC1, nửa trên màu — nửa dưới lấy kênh đỏ làm alpha, đúng thủ thuật `sprites.py`
đang dùng) ra **164×22**, và đo trên chính file PNG xuất ra: alpha giữa
**112/255 = 0,439**, bốn góc **0**, và alpha **PHẲNG** trong lòng hình (cả ảnh
không điểm nào quá **115/255**) — tức một **elip đặc viền cứng nội tiếp trong ô**:
bề ngang hàng giữa **164** (chạm cả hai mép), hàng đầu **66** = hàng cuối **66**,
hẹp dần đều ra hai đầu. Ghi chú cũ ở lượt trước gọi nó là "elip mờ dần" là **sai**;
số đo nói nó đặc. Hệ quả cho bản port: **độ đậm nằm ở chính ảnh**, còn
`fShadowOpacity` **nhân thêm** lên trên (`Sprite2D.modulate.a` nhân vào alpha của
texture) — nên `modulate.a = do_mo(tên)` là đúng chỗ.

**Không khôi phục được (ghi ra, không bịa):**

* `nShadowSize` ánh xạ sang tỉ lệ nào — cả 7 chỗ trong dữ liệu đều là `2`, mà bộ
  đọc cấu hình của engine tra khoá bằng **chỉ số tên** chứ không bằng địa chỉ
  chuỗi (quét cả file không có chỗ nào trỏ tới địa chỉ của chuỗi `nShadowSize`),
  nên không lần ra được bằng tính. Bản port vì thế **không dùng** `nShadowSize`,
  và cũng không dùng `fSmallShadowScale` / `fBigShadowScale` — hai số ấy đi với
  việc phân loại nhỏ/lớn mà **không biết tiêu chí**.
* `fShadowOffsetRate` **nhân với cái gì**. 8 sprite ghi (0,017…0,235); bản port
  giữ trong bảng để đối chiếu chứ **không áp**.
* **Tài nguyên `sShadow`** — tra thì tra, nhưng **không được ship**: không file
  `.xml` nào tên đó, không plist nào chứa nó. Đường dựng bóng của engine cũng chỉ
  dùng **một** ảnh chung `Shadow.png`, nên bản port vẽ bằng chính ảnh ấy.

**Chỗ ĐẶT duy nhất của phần này:** bóng nằm tại **gốc rig**. Bản gốc đặt `y` theo
`self+0x49c` — ô đó được ghi lúc đặt armature xuống mặt đất, và **không có hằng số
nào** để đối chiếu ngược, nên đây là điểm suy luận, không phải điểm đo.

**Bản port.** `rig/sng_rig.gd` thêm `bong` + `hien_bong` / `dong_bo_bong_y` /
`cap_nhat_bong_y`; bóng **chỉ được tạo khi có người hỏi** (đúng như bản gốc, nhờ
vậy 20 chỗ gọi không làm đổi một màn nào đang chạy), `false` thì `queue_free` và
quên con trỏ, `z_index = −10`, ảnh lấy qua `BongRef` (`battle/bong_ref.gd` +
`data_ref/bong_ref.json`), tỉ lệ `BongRef.ti_le(tên)` (không khai thì **0,9** của
chính cấu hình), độ đậm `BongRef.do_mo(tên)`. `lua/cocos.lua` thêm ba phương thức
cho lớp `Node`, thiếu tham số thì **BẬT** (đúng `movs r1, #1` của bản gốc —
`0`/`''` của Lua là truthy, khớp `tobool` mặc định 1), và **im lặng bỏ qua** khi
node không có rig, vì bản gốc cũng có thể trỏ nhầm. Sinh bảng + ảnh:
`python ../brave-cross/work/bong_ref.py --json data_ref/bong_ref.json --anh
assets_ref/bong` (bảng và ảnh **không** commit — `data_ref/`, `assets_ref/` nằm
trong `.gitignore`).

**Kiểm bằng gì:** `tools/verify_bong.gd` — **62 đạt / 0 hỏng**, `check.py` bộ thứ
**34**, ba tầng: (A) bảng và ảnh đối chiếu với **phép đếm thô trên chuỗi** của sáu
file cấu hình (19 / 120 / 7 / 2, đúng bảy tên sprite ghi tỉ lệ), ảnh kiểm bằng
chính file PNG (164×22, alpha giữa 0,439, elip đặc, đối xứng trên–dưới); (B)
`SngRig` — rig vừa dựng **không** có bóng, `true` tạo với `z = −10` và tỉ lệ 0,7
của Hoplite, `false` **xoá hẳn**, lần `true` sau cho **`instance_id` khác**,
armature đang ẩn thì bóng có mà không hiện, và **một** lần gọi trên rig cha của
CaoCao kéo **cả 15** bóng (14 rig lồng nhau) về gốc — phép đo cho đệ quy
`0x3c93c0`; (C) đường Lua thật: `getSpriteFromSpriteCatch('Hoplite')` +
`_ShowShadow`, gọi **trần** (không tham số) phải BẬT, gọi trên node không phải rig
phải **không lỗi**, và ba tên ấy **không** được nằm trong bộ đếm `M.missing`.


- [~] Ải vô tận / Epic / SB / COG (11 màn) — **con số 11 sai, và sai kiểu đã
      cảnh báo ở trên**: nó đếm theo đường dẫn file ném lỗi nên gộp **bốn họ
      riêng** (InfiniteLevel 7 màn đăng ký, Epic 6, SB 6, COG 22) với **hai
      nguyên nhân khác hẳn nhau**. Đọc mã ra:
      * **Đúng 2 màn** hỏng vì dữ liệu máy chủ — `CUIInfiniteLevelMain.lua:619`
        và `CUIInfiniteLevelFirstPassRewards.lua:211`. **Cả hai đã hết**, và đo
        được bằng cách gỡ tạm `TU_DUNG` rồi quét lại: trước 255 mở / 75 hỏng,
        sau 258 / 72. Nhưng trong mức ±3 đó **chỉ một màn thật sự đổi chỗ**
        (`InfiniteLevelUI`); hai màn khác chỉ chuyển qua lại giữa các nhóm —
        đúng lý do phải mở thẳng màn mà xem chứ đừng đọc số tổng.
        `FirstPassRewards` **chỉ tiến thêm được**: `:211` nằm trong `initUI`
        (gọi ở `:47`) mà nay tới được `:75` (ở `:49`), tức `initUI` chạy trọn.
        `:75` **đã gỡ xong** — xem mục "widget bảng" bên dưới. Đo lần cuối:
        `InfiniteLevelFirstPassRewards` **có mặt trong nhóm hỏng ở cả 3 lần chạy
        bản chưa sửa**, và **vắng mặt ở mọi lần chạy bản đã sửa**; cùng lúc
        `MoreGoldDialog` có mặt ở **cả hai** bản nên không phải do sửa đổi này
        (nó thiếu `data` của người gọi — đúng loại lỗi của 6 màn kia)
      * **6 màn** còn lại (`CUISBMain`, `CUISBWayToGet`, `CUISBDegrade`,
        `CUICOGCityInfo`, `CUIEpicBattleLevelUp`, `CUIEpicBattleReward`) hỏng
        **chỉ vì bộ quét gọi `Show(tên)` trần** — chúng lấy `data` từ người gọi,
        **không cần handler nào**
      * SB không phải "SeaBoss" mà là **MagicWeapon** (`sc/user/UI/sb/`); COG là
        **giải đấu liên máy chủ** (`sc/share/COGDef.lua`) — phần nhiều người chơi
        nằm ngoài phạm vi, cùng loại với bang hội
- [~] Bang hội / quân đoàn — handler `guild` đã có, và `GuildControlMain` mở
      được. Nhưng nhóm này **không phải 10 màn**: đọc mã ra thì 4 màn chỉ dùng
      chung widget `CUIGuildTableViewList` (thật ra là APR/Activity), 2 màn đòi
      đối số của người gọi, 1 màn hỏng vì thiếu **tag** chứ không thiếu dữ liệu.
      Phần còn lại (tạo bang, xin vào, chiến bang) cần người chơi khác — việc
      của máy chủ thật, không phải lớp offline
- [ ] Hoạt động, sự kiện, điểm danh, nạp tích luỹ — **đo ra 8 màn, không phải 9:
      3 A / 3 B / 2 C**; sau khi sửa `res`/`cls` thì còn **7 màn: 3 A / 3 B / 1 C**
      (`AnniversaryRankReward` đã mở được). Ba màn B là cấu hình hoạt động, và
      **không lấy lại được** (xem ghi chú B ở trên); màn C còn lại là `CUITurnplate`
      — tính năng chết trong chính bản gốc
- [ ] Đấu trường / PvP / giải đấu — **đo ra 11 màn, không phải 9: 6 A / 3 B / 2 C.**
      Cả 3 màn B đều là APR (`APRData` dựng từ gói tin máy chủ) — nhiều người chơi
- [ ] Thú cưng — **đo ra 5 màn: 4 A / 1 C. Không có lỗ hổng dữ liệu nào** — bốn
      màn kia chỉ thiếu tham số của người gọi. Màn C là `PetIllustration`: sau khi
      sửa `res`/`cls` nó **không còn** hỏng vì tra chuỗi nữa mà vì thiếu hàm engine
      `LuaTableView_create` (xem mục "Lỗi của lớp giả lập")
- [ ] Võ tướng, doanh trại, hồn tướng, cánh, thời trang — **đo ra 6 màn:
      2 A / 0 B / 4 C** (`HeroCombDetail` là A, không phải B — xem "Đã sửa"); bốn
      màn C là `ArmyGroupCampsite` (**ghép thiếu** 9 tag con ở node
      `ttfCampCountdownTree` — tag đã đo được từ trước, không phải thiếu),
      `CUIBarracksMain` (node `snsMainToolArmySoul` nằm ở HUD Main, là neo 41/75
      của màn đó, trong khối neo #38–#42 chưa tới được — **trần đo**, đã khu trú;
      sau khi sửa `xoay` màn tới 68/75 neo nhưng vẫn chưa tới khối ấy),
      `XingHunBook` (thiếu hàm engine `LuaTableView_create`, không phải `switchTab`)
      và `CUICharacterDress` (thiếu `.xgg`)
- [ ] Cửa hàng, nạp, VIP — **đo ra 5 màn: 2 A / 1 B / 2 C**; hai màn C là thiếu
      `.xgg` (`Shop`, `CUIVIPRight` — đừng lẫn với `UI_VipStore_UI_960_640.json`,
      file ấy **có**). Màn B là `MysteriousStoreQuickSell` (nhóm D cũ, xem "Đã sửa")
- [ ] Nhiệm vụ, thương nhân, bạn bè, chat — **đo ra 5 màn: 3 A / 1 B / 1 C**
      (`TourMerchantConfirm` là A, không phải B — xem "Đã sửa")
- [~] Hang / ma khu (1 màn) — mở được + handler `cavern` (xem mục "Đã có"); còn
      làm mới hàng cửa hàng và quét nhanh

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
      **"Vào trận thì đầy" không còn là ĐẶT** (đo xong 2026-09-17). Bốn bằng
      chứng, đọc từ dữ liệu ship và từ mã gốc:
      (a) `Chapter.LeaderShip` do **chính mã gốc** đặt: `FightLogic.lua:225` và
      `ClientLogic.lua:127` đều gán `Chapter.LeaderShip =
      G_UserLogic:GetLeaderShip()`, tức `GameUserBaseInfoReset.LeaderShip + (Level
      - 1)`; bản ghi ấy ghi `LeaderShip: 6, Level: 1` → 6.
      (b) **Bảng chương không có số ấy để mà chép**: `KDBGameChapterConfig`
      461/461 bản ghi đều có `LeaderShipResume`, và **0/461 có khoá
      `LeaderShip`**. Nên con số tối đa chỉ có **đúng một** nguồn: bản ghi người
      chơi, qua công thức trên — không có gì để bịa.
      (c) Bản ghi người chơi (`GameUserBaseInfoReset`, ~30 trường) có **đúng
      một** trường thống soái và **không có mốc thời gian** nào cho nó — trong
      khi tài nguyên tiêu hao thật thì có (`FatigueValue: 120` đi kèm
      `FatigueUpdateTime`). Tức đây không phải con số tiêu hao được lưu lại.
      (d) Quét cả `sc/`: mọi lần `LeaderShip` đứng bên trái dấu `=` đều là
      `Chapter.LeaderShip = GetLeaderShip()` (chiều đọc ra), **không chỗ nào
      ghi ngược** vào bản ghi người chơi.
      Khoá bằng 2 phép kiểm trong `do_chien_dich --kiem`: lúc ĐẶT vào trận,
      `ld_max` (đọc từ chuỗi JSON mà chính mã gốc gửi xuống) **bằng**
      `GetLeaderShip()` **và** bằng trường `Chapter.LeaderShip` trong chuỗi ấy
      (đo được `6 / 5 / 6 / 6 / 5` = ld_max / ld_hoi / công thức / JSON / JSON),
      rồi **nhịp hồi** đo được bằng chính vòng lặp chờ hồi đủ 3 điểm để bấm nút:
      ba nhịp liên tiếp cách nhau **151, 151 khung** (`ld1@85 ld2@236 ld3@387`).
      151 chứ không phải 150 vì `hoi_thong_soai` cộng dồn từng khung mà 1/30
      không biểu diễn được chính xác bằng số thực — lệch 0,03 giây mỗi nhịp,
      phép kiểm cho phép ±2 khung.
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
      này. Đo lại (2026-09-15) thì nhóm "Đấu trường / PvP / giải đấu" là **11 màn,
      trong đó 6 màn chỉ thiếu tham số của người gọi**; chỉ 3 màn thật sự cần dữ
      liệu máy chủ, và cả 3 là APR. Có một đường đi được: bản gốc ship sẵn
      `KDBGameTournamentRobotConfig` (`ConfigManager:updateTournamentRobotConfig`)
      — tức đối thủ **máy** có số liệu thật trong cấu hình, nên đấu trường một
      người chơi là làm được mà không phải bịa đối thủ. Quốc chiến thì cần nhiều
      người chơi thật

## 6. Âm thanh

- [x] **Có tiếng.** `game/am_thanh.gd` (`AmThanh`) nối `playSoundEffect` /
      `playBackgroundMusic` / `loadEffectBank` của engine C++ vào
      `AudioStreamPlayer`. Dữ liệu: **1498 file `.ogg` bóc từ 361 bank** của bản
      gốc, bảng tra `event:/…` → file ở `data_ref/event_ref.json`, tra tiếp theo
      TÊN ở `bank_ref.json` cho những tên client tự ghép lúc chạy
      (`string.format("event:/Vo-Usual/Vo_%s_Usual", heroSprite)`).
- [x] **Hai bảng tiếng động chỉ engine C++ đọc** — `sound_config.xml` (276
      armature, 685 tiếng, 7 `loop="1"`) và `hit_config.xml` (83 armature
      `danh`, 226 đòn, 131 `reuseArmatures`, 38 sự kiện). Không file Lua nào
      trong 973 đọc chúng; bóc ra `data_ref/trigger_ref.json`, lớp giả lập ở
      `game/tieng_dong.gd`.
- [ ] **Ba thứ của FMOD KHÔNG khôi phục được, và đã ghi rõ trong mã** (xem đầu
      `game/am_thanh.gd`): chọn biến thể (`_01`..`_04`) — nay chọn ngẫu nhiên;
      cờ loop của nhạc nền — `MasterBank` không có mẫu âm thanh nào nên không
      đọc ra, nên ĐẶT `loop = true`; trộn 3D / bus / hiệu ứng.
- [ ] **Quy tắc nạp bank theo armature** nằm trong `bank_config.xml` và do
      engine C++ làm lúc tạo sprite — không đo được trên bản gốc, nên không
      chặn tiếng theo bank (chặn thì mọi tiếng của tướng câm hết). Chỉ **ghi
      lại** để biết phủ được bao nhiêu (`ghi_chu_bank`).
- [ ] Đã đo phần **im lặng còn lại** của một trận có hình: 145 đòn / 51 có
      tiếng / **94 im, TẤT CẢ đều `khong-co-danh`** — `Archer_VampirE` 89 +
      `Player000W03W` 5. Không phải lỗi của ta: `giap` có 40 tên biến thể
      (`*_VampirE`, `*_Dong`, `*_Boss`, `*_Skeleton`) và **0/40** có mặt trong
      `sound_config` lẫn `danh` (tên GỐC thì có: 36/40 và 20/40). Muốn có tiếng
      thì phải bịa một luật đổi tên mà engine C++ chưa lộ ra.
- [ ] **Nhạc nền chưa phát lại được đúng chỗ FMOD phát lại** — ta đặt
      `loop = true` cho MỌI bài (lý do ở trên), nên bài nào bản gốc để chạy một
      lần rồi thôi thì ở đây lặp mãi.
- [x] Bộ đo: `tools/verify_am.gd` — **88 đạt / 0 hỏng**, đi đúng đường Lua như
      `SoundManager.lua` đi. Bảng chia im theo nguyên nhân:
      `tools/do_chien_dich.gd -- --kiem` in ra `tieng trung don`.
- [x] **Lỗi đã sửa, đáng nhớ: `AmThanh._thu_lai` từng làm Godot segfault.**
      Tiếng xin lúc `_init` phải hẹn tới khung đầu (chưa có cây), và kênh là con
      của `_cha` — một màn hình vừa đóng là kênh bị giải phóng. Bản cũ **xếp lại
      hàng vô hạn** những kênh đã chết, nên chuỗi `call_deferred` quay mãi; thêm
      nữa `var p: AudioStreamPlayer = m[0]` gán một instance đã giải phóng vào
      biến CÓ KIỂU, tự nó là một lỗi. `tools/quet_show.gd` (mở 353 màn liên
      tiếp) chết bằng `CrashHandlerException: Program crashed with signal 11`,
      vết GDScript trỏ đúng vào dòng đó. Nay: đọc `m[0]` bằng biến KHÔNG kiểu,
      bỏ kênh không còn hợp lệ, và chặn trên `SO_LAN_THU = 3`. Cùng lệnh đó chạy
      trọn, exit 0, ba lượt ra 269/270/268.

## 7. Đóng gói

- [ ] Chạy trên Android / iOS (hiện chỉ chạy trên máy bàn)
- [ ] Màn tải, cập nhật tài nguyên
- [ ] Máy chủ thật (Nakama đã có phần luật trận + chống gian lận)

---

## 8. Việc tiếp theo, xếp theo giá trị

1. ~~**Handler offline cho nhóm đông nhất**~~ — **đã cạn, và cách nó cạn đáng
   ghi lại.** Hai nhóm §8 từng nhắm vào đều xong: ải vô tận có handler
   (`handlers/endless.lua`) và bang hội có handler `guild` từ trước. Nhưng khi
   **phân loại hết 72 màn hỏng** (bảng ở mục 4) thì lộ ra nhóm đông nhất
   **không phải một tính năng**: 41 màn chỉ thiếu tham số của người gọi — màn
   chạy tốt trong game thật, bộ quét gọi `Show(tên)` trần. Trừ tiếp nhiều người
   chơi và ba màn cấu hình hoạt động không lấy lại được từ dữ liệu ship, phần
   dữ liệu người chơi/máy chủ còn làm được chỉ còn **3 màn rời rạc**
   (`lEpicBattleChestMain`, `CUIQuestInfo`, `CUITreasureHunt`) — và lượt soát sau
   đã tra từng màn: `CUIQuestInfo` **nay mở được**, còn hai màn kia chết trong
   chính nhánh mặc định của bản gốc khi thiếu dữ liệu máy chủ, nên **không màn
   nào là việc làm được** (mục 4, nhóm B). Mẹo đã dùng được
   bốn lần, giữ lại để lần sau: bảng nào client tự khai `InitData()` thì lấy hình
   dạng từ đó; luật nào server giữ thì **tìm SỐ trong bảng cấu hình trước khi
   kết luận là mất**; và **đọc chỗ gọi hàm, không chỉ đọc hàm** — bài học đắt
   nhất của mục này (lần thứ tư: hai màn ghi nhầm vào B hoá ra là A, tức suýt
   nữa thì đi viết handler không cần thiết)
2. ~~**Chốt đốm xanh ở Main + đo nốt tag còn thiếu**~~ — **xong cả hai nửa**,
   và nửa (b) hoá ra không phải việc đo. Nửa (a): cách trộn nằm trong **từng
   khung** của armature (`+0x38` của bản ghi khung), `'screen'` = trộn CỘNG
   (`GL_SRC_ALPHA, GL_ONE`), và `SngRig` nay đặt `BLEND_MODE_ADD` theo khung.
   Chốt bằng **cả hai** đường đã vạch ra chứ không đoán: máy ảo
   (`work/emu_dom.py`, 9/9 biến thể) **và** đọc mã (`libgame.so`
   `0x25d476..0x25d4ce`). A/B trên ảnh `Main`: 6.493 điểm ảnh đổi, trước là 0.
   Chi tiết và hai cái bẫy Godot đã mắc: CLAUDE.md mục "Đốm xanh ở Main".
   **Nửa (b) — XONG, và câu trả lời bác bỏ chính câu hỏi.** Hỏi "9,3% tag còn
   thiếu" thì đo ra: **phần lớn trong đó chưa bao giờ là thiếu ĐO — nó là thiếu
   KHÂU ÁP.** `tags_cay.json` (đường CHỈ SỐ CON, đo từ lâu) đã có sẵn tag của
   gần hết chỗ được ghi là "thiếu", nhưng `emu_join.py --ghi` **chưa từng chạy
   đường ấy**. Chạy nó: node có tag **19.456/33.472 (58,1%) → 26.315/33.472
   (78,6%)**, `quet_show.gd` **71 màn hỏng → 67**, và 5 màn mở được ở **cả hai**
   lần chạy lại (`CUIFriendsChatting`, `CUIContest`, `RedPacketMainDlg`,
   `CUICOGCityInfo`, `TimeHeroUI`). `check.py` 24/24 xanh. Bảng đầy đủ ở mục 4.

   **Lượt thứ hai của nửa (b): phá trần đo bằng cách sửa `xoay`.** Phần thiếu
   còn lại không phải khâu áp mà là **trần đo** — chỉ **6 trong 287 màn** còn neo
   chưa tới được, nên đối chứng chỉ chạy trên 6 màn ấy (cùng mã, cùng trần 16
   lượt, **cả hai nhánh khởi đầu `bo` rỗng**, biến duy nhất khác là `xoay`):
   **`UI_Hero` 73 → 147/168 neo**, **`UI_Main_ControlPanel` 2 → 66/75**,
   `UI_Destiny` 7 → 34/42, `UI_Friends` 28 → 30/33; `UI_ArmyGroup_Campsite_Info`
   (9/22) và `UI_Mail` (1/7) không nhích. Hợp ba nhánh rồi ghép lại: node có tag
   **26.315 → 27.876/33.472 (83,3%)**, `quet_show.gd` **`264 / 22 / 67`**,
   `getChildByTag` **9.563/11.225 (85,2%)**, `check.py` 24/24 xanh. Neo chưa tới
   được trên toàn kho: **243 (8,7%) → 86 (3,1%)**.
   **Một dự đoán của tôi trong lượt này đã SAI và được ghi lại:** nhìn số đo của
   nhánh `--khong-xoay` (16/16 đường chết của `UI_Main_ControlPanel` tụm trong
   neo #2) tôi kết luận trần do "cụm đường chết trong một neo" nên **quay cũng
   không phá được** — sai, vì suy từ **một** màn ra **sáu** màn; đo mới thấy quay
   trải đều phủ được phần đuôi (2 → 66). Chi tiết ở README, mục "Quay neo".

   **Lượt thứ ba của nửa (b): đo thẳng neo bị chặn.** Trần đo còn lại phá nốt
   bằng một đường khác hẳn, không cần thêm lượt: vì neo là thứ **đã biết tên**,
   nên bỏ hẳn phần đầu danh sách đi mà đo phần đuôi — thêm cờ `--neo` cho
   `emu_tags.py` (nhận danh sách neo theo **đúng thứ tự người gọi đưa vào**, tên
   gõ sai thì **cảnh báo** chứ không im lặng bỏ qua). Bỏ phần đầu thì những đường
   làm chết tiến trình ở phần đầu cũng không còn được chạy, nên neo cuối tới được
   ngay. Đo `UI_Main_ControlPanel`: **68 → 73/75** neo, neo `snsMainToolArmySoul`
   (41/75) ra **tag 2** và bốn con ra tag **2, 1, 0, 0**. Toàn kho: node có tag
   **27.876 → 27.887 (83,3%)**, neo chưa tới **86 (3,1%) → 81 (2,9%)**,
   `quet_show.gd` **`264–265 / 23 / 65–66`**, `getChildByTag`
   **9.786/11.448 (85,5%)**, `check.py` 24/24 xanh.
   Chỉ **35 neo** còn chưa tới trên các màn đo được (46 neo còn lại thuộc 4 màn
   không ra dữ liệu, xem mục dưới).

   **"6 màn, một nguyên nhân" SAI — đo tới nơi thì ra BỐN nguyên nhân, và KHÔNG
   màn nào là "thiếu tag thật" theo nghĩa ban đầu:** `CUIFriendsChatting` và
   `CUIArmyGroupCampsite` là
   ghép thiếu (tag 2/5/4/1/3 và chín tag dưới `ndArmyGroupCampsiteShot/3/2/31`
   đã có sẵn trong file đo); `RedPacketMainDlg` cũng ghép thiếu; còn
   `CUIXingHun` **không hề chết ở `switchTab`** — nó chết ở `CUIZhanXing.lua:232`
   (`getChildByTag(0)` trên `hunWeiN`, bố cục bị lệch chỉ số), và `XingHunBook`
   chết vì thiếu hàm engine `LuaTableView_create` (việc 5). **`CUIBarracksMain`
   thì KHÔNG thiếu tag — nó chặn ở trần đo, và trần ấy đã phá.** `do_mot_man.gd`
   trên màn ấy đòi `getChildByTag(1)` trên node **`snsMainToolArmySoul`**, mà cả
   node đó lẫn 4 con của nó đều **không có tag nào** trong `layout_ref` — vì nó là
   **neo 41/75** của `UI_Main_ControlPanel` và neo ấy chưa từng tới được (sau lượt
   sửa `xoay` màn tới **68/75**, còn khối #38–#42 thì chưa; `lMainToolbarTop` #40
   là **cha** của nó). Đo thẳng neo ấy bằng `--neo`: `snsMainToolArmySoul` ra
   **tag 2**, bốn con ra **2, 1, 0, 0** — tức `getChildByTag(1)` **có thật trong
   bản gốc**. Kiểm lại theo **từng màn** (không dùng con số tổng):
   `hoi=88 hut=17`, **`Show: ok`**, trước đó là `CUIBarracksMain.lua:203: attempt
   to index a nil value`. Vậy **cả 3 màn từng bị ghi là "thiếu tag con" đều
   KHÔNG thiếu tag** — thứ chặn chúng là khâu áp (2 màn) và trần đo (1 màn).

   Chẩn đoán cũ về chỗ tắc vì thế cũng phải sửa hai lần. Bản đầu nói "không tên
   màn nào trong 6 màn trên khớp tên file `.xgg` nào" — **sai hẳn**: ánh xạ ấy
   do chính mã Lua khai (`self.ResourceXggList` / `self.RootUIName`) và bộ quét
   in ra ở mọi màn. Bản thứ hai nói chỗ tắc nằm ở khâu ghép theo VỊ TRÍ — đúng,
   nhưng **chưa đủ**: đường ghép khớp-khít-theo-hình chỉ là đường DỰ PHÒNG, còn
   đường CHÍNH (chỉ số con, đo được 65/65 và 172/172 đường không trượt) **có
   dữ liệu mà chưa từng được chạy**. Bài học ghi lại: **thêm một đường đo mới
   thì phải chạy nó rồi mới được kết luận là thiếu dữ liệu.**

   **Còn một trần thật của phép đo, đo được luôn:** `PROBE_CAY` đi lần lượt
   từng neo, mà bản dịch ARM chết giữa đường nên neo sau chỗ chết không được đi
   — chết cả tiến trình, nên vòng lặp neo bị cắt ngang. Đếm trên 287 màn /
   **2.778 neo**: sau lượt sửa `xoay` và lượt đo thẳng `--neo` còn **81 neo chưa
   từng được mở tới (2,9%)** — trước hai lượt đó là **243 (8,7%)**. Chỗ thiếu ấy
   gồm **hai loại khác hẳn nhau**: **4 màn không ra dữ liệu nào** (46 neo,
   550/33.472 node — cả 4 không được `sc/` nhắc tới ở đâu, hai trong đó trông là
   bố cục thử, lý do chết sớm **chưa truy**) và **6 màn đo được nhưng còn neo chưa
   tới** — nay chỉ còn **35 neo** (trước là 197): `UI_Hero` 163/168,
   `UI_Main_ControlPanel` 73/75, `UI_Destiny` 34/42, `UI_Friends` 32/33,
   `UI_Mail` 1/7, `UI_ArmyGroup_Campsite_Info` 9/22. Hai neo còn lại của
   `UI_Main_ControlPanel` là hoạ tiết theo mùa (`spMainUITheme_newYear_0`,
   `spMainUITheme_christmas_0`). Cả 6 màn đều **không `DOTREO`**, **không
   `DOCUT`** — phần còn thiếu không phải do tên hay cây hỏng. Nghĩa là **83,3%
   vẫn là CẬN DƯỚI**, không phải số cuối.
   Hình dạng tập neo còn là **phép kiểm cho `xoay`**: trước lượt sửa cả 6 màn đều
   ra một **tiền tố liền mạch từ vị trí 1** (kể cả khi đã dùng hết 16 lượt); nay
   **4/6 màn có LỖ** và trải tới cuối danh sách — đúng như đã tuyên bố trước khi
   đo. Bản đầu của `xoay` làm `k = xoay % len(names)` với `xoay` chỉ chạy 0..15
   nên **với màn nhiều neo thì vị trí mở đầu chỉ nhích trong 16 chỗ đầu** — đó
   chính là vì sao số đo cũ vẫn ra tiền tố. Nay bước nhảy là `len(names)/16`.
   **Cách phá trần cho từng neo, khi cần:** `--neo` đo thẳng những neo được kể
   tên (xem mục 4, bảng `layout_ref`) — không cần thêm lượt, vì bỏ phần đầu danh
   sách thì những đường làm chết tiến trình ở phần đầu cũng không còn chạy.

   > **Đọc các số `quet_show.gd` trong mục 2 này cho đúng: chúng đo bằng THƯỚC ĐO
   > CŨ.** Lúc đó bộ quét chưa **nhả khung** giữa các màn, nên `onVisible` không
   > chạy và màn mở rồi vẫn bị tính là `im`. Vì thế `264–265 / 23 / 65–66` ở đây
   > **không so ngang được** với bảng đầu ROADMAP (`292 / 0 / 61`). Đường đi từ
   > 264–265 tới 292 gồm **hai đoạn khác hẳn nhau, đừng gộp**: 264–265 → 268–270
   > là **việc thật** làm sau mục này (vẫn trên thước cũ, xem khối ngay trên), còn
   > 268–270 → 291–292 và `im 23 → 0` là **thước đo đổi**, **không màn nào mới mở
   > ra**. Cùng lý do, `check.py` ở đây ghi **24/24** — nay là **27/27**, và
   > **29/29** ở lượt sau (con số hiện hành: bảng ở mục 0). Giữ
   > nguyên các số cũ vì chúng là bản ghi của từng lượt; muốn đối chiếu ngang thì
   > chạy lại `emu_tags.py` / `emu_join.py` rồi đo bằng thước mới.

3. ~~**Âm thanh**~~ — **xong**, xem mục 6. Mục này để nguyên chữ "chưa có gì"
   lâu hơn thực tế: `game/am_thanh.gd` đã nối `playSoundEffect` /
   `playBackgroundMusic` / `loadEffectBank` vào `AudioStreamPlayer`, `verify_am.gd`
   **88 đạt / 0 hỏng**, và ba việc không khôi phục được của FMOD đã ghi rõ trong mã.
4. **Bỏ mấy chỗ ĐẶT trong trận** — chỗ đứng, tốc độ, hồi thống soái — bằng
   cách đọc tiếp `libgame.so` hoặc đo trong máy ảo.
   **(c) hồi thống soái đã XONG** (2026-09-17): "vào trận thì đầy" nay có bằng
   chứng chứ không còn là ĐẶT — bốn bằng chứng và hai phép kiểm ở §5 mục
   "Cách hồi thống soái" (đo được `ld_max / ld_hoi / công thức / JSON / JSON` =
   `6 / 5 / 6 / 6 / 5`, và nhịp hồi ba lần liên tiếp cách nhau `151, 151` khung).
   Còn lại **(a) chỗ đứng** (chỗ đặt toán lính đầu tiên ở mép trái ô 0, và đơn
   vị của `fLaneWidth` / `fLaneOffset`) và **(b) tốc độ** (mới có tốc độ ĐI;
   tốc độ CHẠY — bộ binh 300, cung 250, kỵ binh 350 — và bộ "não" C++ chọn
   đi hay chạy thì chưa nối).
5. ~~**Làm binding engine `LuaTableView_create`**~~ — **xong**
   (`lua/bang.lua`, gắn ở `bootstrap.lua:228`), cùng lượt ấy làm luôn
   `LuaTableViewCell_create`. Trước đó `tv` là bong nên màn nào chạm vào nó thì
   chết: `PetIllustration` chết đúng ở đó
   (`cocos.lua:391: diem neo khong phai so … cua <bong LuaTableView_create()>`).
   Mục này đòi "làm rồi đo bằng `quet_show.gd`" — phép đo ấy đã có số: xem bảng
   "màn mở được" ở mục 0 và mục 4.
6. ~~**Lớp cuộn `CCScrollLayer`**~~ — **xong**, và đây là chìa khoá vào ải vô
   tận: `btnMainEvilCastle` nằm ở x = 1582,9 trong khi sân khấu rộng 1152, nên
   **không cuộn thì không có điểm màn hình nào chạm tới nó được**.
   Vì sao phải làm ở tầng engine: cả **bốn** hàm `CUIMain` đăng ký cho lớp thành
   phố (`CUIMain.lua:1682-1695`) đều là **bóng rỗng**, chỉ có một dòng chú thích
   — Lua chỉ bảo engine *bật* cuộn (`setMarginSpace(-50)`, `setIsElastic(true)`,
   `setLuaCallbackForDrag`), còn việc cuộn nằm hẳn trong C++.
   Số đo lấy từ bảng đăng ký phương thức của engine, `.data 0x93386c` (32 mục,
   12 byte/mục, con trỏ hàm mang **bit Thumb**, phải `& ~1` trước khi dịch) trên
   `vn/apk/.../libgame.so` (md5 `245edda2…`): `+0x1bc` lề, `+0x1b0` cắt hình,
   `+0x1af` trục dọc, `+0x1b4` neo berth, `+0x1dc` lớp nội dung, `+0x245` cổng
   tính bề rộng cuộn; `resetContentLayerPos` = `core(self, gettop>0 ?
   checknumber : 0)`; **158** chỗ gọi nó, **73** chỗ gọi `enableScroll`
   (39 bật / 34 tắt), và **0** chỗ gọi cho cả hệ berth.
   Phép đo: `tools/verify_cuon.gd` — **24 đạt / 0 hỏng**, ba lần chạy đều như
   nhau, và đã vào `check.py`. Trên cảnh `Main` thật: kéo −200 thì lệch đúng
   −200; `resetContentLayerPos()` về 0; kéo −2000 rồi thả thì nhả về biên
   **−784** (con số **tính lại độc lập** trong bộ đo từ kích thước đọc ra từ cây
   Godot, không lấy hằng số của `cuon.lua`), và `btnMainEvilCastle` từ
   **ngoài khung** (tâm 1582,9) vào **trong khung** (tâm 798,9) rồi **bấm được**
   — kiểm bằng chính bộ lọc chạm của engine, không phải bằng mắt.
   Chống hồi quy: `quet_show.gd` — so **danh sách TÊN màn hỏng** giữa hai lượt
   cùng mức (65 hỏng): **giống hệt nhau**; các lượt còn lại nằm trong dải đã ghi
   (`264–265 / 23 / 65–66`, dao động ±3). `check.py` **25/25** lúc đó, nay
   **27/27** — và **29/29** ở lượt sau (con số hiện hành: bảng ở mục 0). Dải
   `264–265` ấy cũng là **thước đo cũ** (chưa nhả khung): cùng
   phép đo này chạy trên thước mới ra **291–292 / 0 / 61–62** — xem khối
   "thước đo đổi" ở đầu ROADMAP.
   Ba chỗ **ĐẶT**, ghi rõ trong `cuon.lua`: ngưỡng phân biệt bấm-với-kéo **12 px**
   (ranh giới ấy nằm trong C++, không có trong bảng phương thức), thời gian nhả
   về biên **0,2 giây** (hằng số ở `0x2c0d34`/`0x2c18da` chưa giải), và **trục
   mặc định là ngang**. `setIsCropDraw` **mới ghi cờ, chưa cắt hình** — bật
   `clip_contents` sẽ đổi luôn bộ lọc chạm của 12 màn, phải đo riêng.
   Một lỗi tự bắt được trước khi chốt, đáng nhớ: `goc_cua` tự chỉnh gốc khi vị
   trí lệch khỏi `gốc + lệch`, mà `day_lech` lại truyền **độ lệch mới** — nên
   mỗi lần kẹp biên hay nhả về biên là gốc **trôi**, và lần kẹp sau sai tiếp.
   Nay `day_lech(gd, t, mới)` đọc gốc theo độ lệch **đang áp** rồi mới ghi.

7. ~~**Đường vẽ theo `zOrder`**~~ — **xong, và đây là việc lộ ra muộn nhất mà
   đáng giá nhất.** `lua/cocos.lua` gọi `_godot_zsort` ở hai chỗ nhưng **chưa
   từng viết hàm ấy**: tên rơi vào `_G` giả lập → trả **bóng** → bóng gọi được →
   nên `setZOrder` và `addChild(c, z)` chỉ ghi meta rồi thôi. **Mọi thứ bản gốc
   đẩy lên bằng zOrder đều không được đẩy**, kể cả `SetOpenZorder` của hộp thoại
   (50, trên lớp che 20, dưới thanh Back 60). Không lỗi nào được ném ra nên 27 bộ
   kiểm xanh suốt thời gian ấy — **cùng kiểu lỗi im lặng với `setGray`**. Nay xếp
   lại mảng con thật theo `(zorder, thứ tự thêm)`; kèm `Node:reorderChild`
   (1.200 lượt gọi, đứng đầu bảng "API chưa làm" và **không phải một API thiếu**
   mà là dấu vết của một hàm chưa viết). Chi tiết và cái bẫy `if node.method then`
   của chính bộ đếm: mục 4.
8. ~~**`setPercentage`**~~ — **xong, và câu trả lời khoá được bằng SỐ trong
   chính bản ghi `.xgg`, không cần máy ảo.** Ghi cũ ở đây nói "bản ghi
   `CCProgressTimer` **không** chứa trường riêng cho kiểu thanh hay chiều chạy,
   nên kiểu là mặc định C++ chưa giải" — **sai**, và sai vì phép quét cũ chỉ tìm
   *midpoint* / *barChangeRate* (hai trường của Cocos2d-x bản gốc) chứ không đọc
   **ba trường mà lớp `CCProgressTimer` của engine này thật sự có**. Đọc lại bản
   ghi theo từng byte thì chúng nằm ngay đó.

   **Bản ghi LUÔN đúng 256 byte** — đo trên **cả 325 node của 73 file bố cục,
   không một ngoại lệ** — và mang sẵn ba trường:

   | offset | kiểu | nghĩa | đo được |
   |---|---|---|---|
   | `+0xF4` | uint32 | **kiểu** thanh/vòng | 2 → 262, 3 → 49, 0 → 12, 4 → 2; **không** có 1 và 5 |
   | `+0xF8` | float | **phần trăm** đang đặt | 100 → 309, 0 → 10, 30 → 3, 50 → 3 |
   | `+0xFC` | byte | cờ 0/1 rồi `cd cd cd` (rác gỡ lỗi MSVC) | 1 → 307, 0 → 18 — **nghĩa chưa rõ**, chỉ ghi lại, **không dùng để vẽ** |

   Tên ảnh trong cùng bản ghi nằm ở **hai** chỗ, và thứ tự ưu tiên đo được chứ
   không đoán: `+0xE4` (cặp `str_off`/`str_len`) **chỉ khác rỗng ở ĐÚNG MỘT
   node** — `ptLoadingGamePercent` của `UI_LoadingGame` — còn `+0xEC` khác rỗng ở
   **323** node; **1 node không có tên ảnh ở cả hai chỗ** (`CCProgressTimer`
   40×40, hệ số `CD`). Không đọc `+0xE4` thì node ấy ra sprite trắng.

   **Đối chiếu với từ vựng `setType` đã chốt ở mục 4** — sáu tên theo đúng thứ tự
   trong bảng phương thức của engine — thì mã đọc ra là: **0 `cw`, 1 `ccw`,
   2 `lr`, 3 `rl`, 4 `bt`, 5 `tb`**. Hai đường **độc lập** xác nhận cách đọc ấy:

   * **Neo đo trên bản gốc chạy trong máy ảo:** `pMainUIHeroExp` (`+0xF4` = **2**)
     đầy dần sang phải, **mép trái đứng yên**; `g_ptWarSoulTBar` (`+0xF4` = **4**)
     đầy từ **dưới lên** (`+181` đáy → `+0`). Tức 2 phải là `lr` và 4 phải là
     `bt` — đúng như bảng.
   * **Hình dạng node, một chữ ký hoàn toàn khác:** **12 node kiểu 0 đều là hình
     VUÔNG** (28×28 ×4, 22×23 `ptLeaderShipTimer`, 95×95 ×3, 45×45 ×3, 81×81
     `ptLoadingGamePercent`), còn node kiểu 2 **đều dài** (78×13 ×114, 120×28 ×17,
     350×13 ×16…). Vòng thì vuông, thanh thì dài — nên **0/1 là vòng, 2..5 là
     thanh**, và không node vòng nào bị vẽ thành thanh. (Số đo lại lượt này trên
     cả 325 node, đầy đủ ở mục 8 việc 8: kiểu 0 có tỉ lệ dài/ngắn **1,00..1,05**,
     kiểu 2 **1,00..61,43**, kiểu 3 **8,57..24,00**, kiểu 4 **1,00..4,18**.)

   **Vẽ là CẮT, không phải PHÓNG TO** — đo bằng cách so từng điểm ảnh giữa hai lượt
   chạy chỉ khác nhau ở `setPercentage`: mép neo đứng yên ở mọi mức, mép kia chạy,
   và vùng ảnh lấy ra **ngắn lại** theo phần trăm (phóng to thì vùng ảnh luôn là cả
   tấm). Nên `TienDo.o_thanh` cắt **cả hai phía** theo cùng một tỉ lệ: `src` là
   `t` phần của **ảnh**, `dst` là `t` phần của **ô**.

   **Và đây là chỗ KHÔNG khôi phục được, ghi thẳng ra thay vì lấp:** chiều dài
   đầy **không** tỉ lệ với phần trăm. Đo trên thanh máu HUD (ô 126×21 trên màn):

   | p | 10 | 15 | 20 | 25 | 30 | 50 | 75 | 90 | 100 |
   |---|---|---|---|---|---|---|---|---|---|
   | px đầy | 0 | 0 | 7 | 14 | 22 | 52 | 90 | 112 | 126 |

   Bình phương nhỏ nhất ra `L = 1,508p − 23,7` — **bằng 0 ở 15,7%**, tức tỉ lệ
   thuận bị **bác bỏ**. Thanh thống soái (ô 54×251) thì gần tỉ lệ thuận
   (`H = 2,617p − 8,35`: p = 10 → 16, 30 → 70, 60 → 153, 100 → 251). **Hai thanh
   cho hai luật khác nhau**, nên cơ chế thật **chưa tìm ra** — nghi ở chỗ chia
   theo `barChangeRate`/`midpoint` mà engine giữ trong C++, nhưng chưa có đường
   đọc. Bản dựng vẽ **tỉ lệ thuận** (đúng ở 0% và 100%, thấp hơn tối đa ~11 px ở
   khoảng giữa của thanh HUD) và **ghi lại khoảng lệch ấy** thay vì chỉnh số cho
   vừa mắt.

   Cùng chỗ ấy lộ ra **vì sao 314/325 tên ảnh của node thanh là `guess`**: ảnh nền
   mà hoạ sĩ dùng **lệch 1–2 px** so với ô trong bố cục — `v6/ui_blood_23.png`
   **362×14** cho ô **360×15**, `v6/ui_blood_26.png` 27×9 cho ô 222×10,
   `v6/ui_blood_12.png` 13×13 cho ô 77×13. Tức tên ảnh là **trường ghi thẳng
   trong bản ghi**, không phải suy từ kích thước — nên chấp nhận `guess` cho
   riêng loại node này là **có đo**, không phải nới lỏng. Và ô của node thanh lấy
   theo **bản ghi**, không theo ảnh: `getContentSize()` của bản gốc chạy trong máy
   ảo trả về **178** cho node 178×28 (hệ số phóng của các tổ tiên bằng đúng 1,0;
   riêng `ptLoadingGamePercent` có một tổ tiên 0,66). Lấy ảnh làm ô thì thanh HUD
   ngắn đi đúng 2 px, còn ô 77×13 với ảnh 13×13 thì ngắn đi **64 px**.

   **Đã làm trong bản dựng:** `xgg.py` đọc ba trường + tên ảnh `+0xE4`, `layout.py`
   mang chúng vào `layout_ref` (`KEEP_TIMER`), `ui/xgg_layout.gd` xếp
   `CCProgressTimer` vào kind **`progress`** (trước đó nó rơi vào `layer`, mà
   `layer` có ảnh thì thành `sprite` — nên **cả 325 node bị vẽ đầy đặc ở mọi phần
   trăm**: thanh máu HUD luôn đầy, thanh nạp game không bao giờ chạy),
   `ui/tien_do.gd` vẽ thanh và vòng, `ui/ui_frames.gd` **không** đổi ô của node
   thanh theo ảnh, `lua/tien_do.lua` mở `setPercentage`/`getPercentage`/`setType`/
   `getType` qua **`C.raw(self)`** (lớp bọc chốt `__index` về bảng `Node`, nên gọi
   `node:dat_pct(...)` trên lớp bọc **im lặng không làm gì** — đã đo), và
   `tools/verify_tien_do.gd` khoá lại: **120 đạt / 0 hỏng**, đã vào `check.py`.

   **Còn lại, KHÔNG đoán:** (a) công thức chiều dài đầy ở trên; (b) **góc bắt đầu
   và chiều của vòng** — bản ghi có **12 node kiểu vòng** (`ptType = 0` = `cw`),
   nhưng chỉ **một** trong đó được mã gốc quay thật
   (`ptLoadingGamePercent`, tự nó đảo `cw` ↔ `ccw` trong `CUIDownload.lua:57-69`),
   nên chiều sai thì không lộ ra; ta đặt 0° = 12 giờ, chiều dương = kim đồng hồ.

   **(c) `setOrange` — XONG lượt này, và kết quả là nhánh bản dựng đi qua KHÔNG
   ĐỔI GÌ.** Đo từ file game: `CCProgressTimer::setOrange` ở `0x2bd1d0` (slot
   vtable `+0x298`; `setGray` `0x2bd218` slot `+0x290`, hai thân hàm giống hệt).
   Thân hàm thoát sớm nếu `*(uint8*)(self+0x1cc) == 0`, không thì lấy
   `inner = *(CCSprite**)(*(self+0x1c8)+0x1d8)` rồi gọi `inner->vfunc_0x158(b ?
   "ShaderPositionTextureColor_Orange" : "ShaderPositionTextureColor")` — **cả
   hai setter của lớp này đều KHÔNG ghi `b` vào một byte cờ nào**, khác
   `CCSprite::setGray` (`0x49d6d4`, có `strb.w r1,[r0,#0x23b]`). Nguồn mảnh
   Orange ở `.rodata 0x7cd0c1` (283 byte):
   `gl_FragColor = texture2D(u_texture, v_texCoord) * v_fragmentColor;` rồi
   `r *= 0.9; g *= 2.9; b *= 0.0`. Bảng chỉ số chương trình
   (`work/shaderghep.py --bang`, đối chiếu mã đăng ký ở `0x4d97ec`): 0 Orange,
   1 Gray, 9 = bản thường. Cả **6 chỗ gọi** (12 dòng, mỗi chỗ một cặp
   `true`/`false`) đều có dạng `if X.setOrange then if GetLanguageName()=="en"
   then true else false end end`, mà bản dựng **không bao giờ ra "en"**
   (`IS_OPEN_LANGUAGE = false` ở `sc/share/Setting.lua:13` khoá danh sách ngôn
   ngữ còn **một** mục, cộng `DEFAULT_LANGUAGE = 'vi'`) — nên chỉ nhánh `false`
   chạy được.

   **Ba lượt trên máy ảo** (`work/emu_pt.py --cam`, node `pMainUIHeroExp` của
   `UI_Main_ControlPanel_960_640`): *không gọi gì* / `setOrange(true)` /
   `setOrange(false)` cho ra — *không gọi* vs *`false`*: **0 / 921.600 điểm ảnh
   khác** (lệch tới 0); *`false`* vs *`true`*: **2.486 điểm khác, TẤT CẢ trong
   (270,139)-(395,159)** = đúng ô thanh đang vẽ, **0 điểm khác ở ngoài**. Tức
   chương trình mặc định **đã là** `ShaderPositionTextureColor`, đúng cái mà
   nhánh `false` đặt vào — bỏ qua nó không sai hình, và đặt tên nó cũng không
   làm hình đổi. Phép kiểm chương trình Orange trên 2.486 điểm ấy (hệ số lấy từ
   nguồn shader, ảnh chỉ được phép **bác bỏ**): phép trộn mặc định
   `GL_ONE`/`GL_ONE_MINUS_SRC_ALPHA` cho điểm màn hình `= S + D*(1-a)`, nên
   shader đổi `Δ = S*(T-1)`; suy ngược `S` từ `Δ` rồi kiểm ba tầng — **0 điểm
   sai dấu**, **0 điểm cho `S` ra ngoài `[0,255]`**, và `S` ra **một** màu đỏ
   nhất quán `(170, 29, 29)` với tỉ số đo được `Δg/Δb = −1,903` so với `−1,9`
   mà nguồn nói. Công thức cũ "điểm mới = điểm cũ × T" chỉ khớp 1.100/2.486 **vì
   nó bỏ qua số hạng nền `D*(1-a)`** — con số đó là sai, không phải shader sai.
   Bản dựng đặt tên phương thức ở `lua/tien_do.lua` (nhánh `false` = không đổi
   gì, nhánh `true` viết theo đúng nguồn nhưng **không thể chạy ở bản này** nên
   chưa kiểm được bằng ảnh trong Godot), hệ số ở `ui/tien_do.gd`
   (`HE_ORANGE`), và `tools/verify_tien_do.gd` khoá lại — **120 đạt / 0 hỏng**,
   đã vào `check.py`.

   **(d) `setIsSwallowInBegan` — XONG lượt này. Đây là cái DUY NHẤT trong hai
   cái đổi hành vi thật.** Đo từ file game: phương thức chỉ có trên **một** lớp
   trong 132 bảng bind — `CCLayerColorRoundRect` (Thumb `0x2b4e98`, bản ghi
   `A=0x2b4e99 kind B=0`). Thân hàm:

   ```
   push {r4,lr}; r4 = r0; r0 = r1; r1 = 1; bl 0x274ca8   -- tobool(arg, 1)
   strb.w r0,[r4,#0x276]; r0 = 0; pop {r4,pc}
   ```

   tức `self[+0x276] = tobool(arg, mặc định 1)` — đối số **vắng** ra `1`, và mọi
   giá trị khác đi qua **truthiness của Lua** (nên `0` và `''` là BẬT, không
   phải `b ~= false`). **Mặc định là NUỐT**: **ba** hàm dựng của lớp
   (`0x2b5f64`, `0x2b5ff6`, `0x2b6092` — cả ba gọi init `0x2b4eac` rồi đặt
   vtable) đều ghi `1` vào `+0x276`, và không chỗ nào khác ghi `0`. Người **đọc**
   byte đó là `0x2b4d30` (cùng lớp): `ldrb.w r3,[r4,#0x276]; cbz r3 -> thoát;
   movs r3,#1; strb.w r3,[r6,#0x38]` — chỉ khi cờ khác 0 mới đánh dấu byte "đã
   nuốt" (`+0x38`) của **đối tượng chạm**. Bốn chỗ khác trong `.text` cũng dùng
   offset `+0x276` (`0x3d7c7e`, `0x3d7aaa`, `0x3d8426`) nhưng thuộc **lớp khác**,
   ở đó `+0x276` là bộ đếm cho `20,0` — trùng offset là **trùng ngẫu nhiên**,
   không phải cùng trường.

   **Ý nghĩa đọc ra từ chính mã gốc, không suy:** bốn 阻隔层 của `CUIChatting`
   (comment của bản gốc ghi rõ "表情阻隔层" / "等级阻隔层" / "添加好友阻隔层" /
   "语音文字阻隔层", `CUIChatting.lua:352-362`) là lớp phủ **rộng hơn** khung
   bên trong; hàm `onTouchBegin_` của chúng đo toạ độ điểm chạm với khung trong
   rồi ẩn khung đi nếu chạm ra **ngoài** (`:1203`, `:1335`, `:1649`, `:1875`).
   Nếu lớp đó nuốt cú chạm thì cú chạm-vào-ra-ngoài ấy **cũng bấm luôn vào nút
   nằm dưới lớp** — nên phải là `false`.

   **8 chỗ gọi** trong mã gốc, 6 file, **tất cả** `false`, **tất cả** là lớp
   chặn: `CUIArmyGroupCampsiteChatting.lua:91,94`; `CUIChatting.lua:353,356,
   359,362`; `CUIFriendsChatting.lua:100,103`. Cả 8 gọi **trần** (không có
   `if X.setIsSwallowInBegan then`) nên 8 node đó **bắt buộc** thuộc lớp ấy —
   và kiểm độc lập được **8/8** từ `layout_ref`: 6 node theo **tên**
   (`lLevelNotice`, `lChattingVoiceTextClose`, `lChattingAddFriendClose`,
   `lChattingEmoticonClose`, `lCampsiteChattingEmoticonClose`,
   `lCampsiteChattingVoiceTextClose`), 2 node của `CUIFriendsChatting` theo
   **tag** vì chúng **không có tên** — mã gốc lấy bằng
   `rootPanel:getChildByTag(1)` rồi `:getChildByTag(2)` / `:getChildByTag(5)`
   (`:140`, `:143`); cả 8 đều `type 4 / CCLayerColorRoundRect`. Thêm một phép
   kiểm **đối chứng**: node **cùng lớp, cùng cha, ngay cạnh** đó (tag 4,
   `lFriendsChattingInvalidTouch`) mà mã gốc **không** gọi thì giữ **mặc định
   nuốt** — tức **lớp không quyết định**, chính lời gọi `false` mới đổi hành vi.

   Bản dựng: `Node:setIsSwallowInBegan` ở `lua/cocos.lua` (đặt trên `Node` chứ
   không trên một lớp riêng, vì bản này đã bỏ lớp C++ đi — `CCLayerColorRoundRect`
   không có trong `KIND_OF_TYPE`, `ui/xgg_layout.gd:73-88`), cờ lưu vào meta của
   chính node Godot, và `M.cham` **chạy hàm rồi trả `false`** khi cờ là `false`
   — cú chạm đi tiếp xuống node dưới, đúng như mã gốc. Chỉ nhường pha **Begin**
   (chỗ duy nhất mã gốc đọc byte ấy; `Move`/`End` đã đi theo node thắng Begin).
   Mặc định **không đổi**: node không gọi setter vẫn nuốt, nên luật đã đo của
   `verify_cham.gd` phần 2 và lớp phủ modal `lNormalDlgTouchMask` giữ nguyên.
   `tools/verify_cham.gd` khoá lại — **33 đạt / 0 hỏng**, đã vào `check.py`.
   Bộ đếm `M.missing` trên đường Login → Main từ **2 loại** xuống **1 loại**
   (`setIsSwallowInBegan ×6`), rồi lượt này xuống **0 loại**.

   **Lượt này có đo lại (b) bằng máy ảo và VẪN không lấy được góc — lý do là đo
   được, không phải vì không thử** (`work/emu_pt.py --kieu`, 11 lượt):
   (i) node vòng thật duy nhất nhìn thấy được nằm **dưới** lớp UI của cảnh Main
   (đo ở lượt trước: đổi `setPercentage` cho ra **0 điểm ảnh**);
   (ii) `ptLeaderShipTimer` — node vòng **có tên** thứ hai — có `vis = False`
   **ngay trong bản ghi**, cả nó lẫn cha `lBattlefieldArmy`;
   (iii) 10 node vòng còn lại **không có tên** nên không gọi được từ Lua (máy ảo
   chết khi duyệt con: `getChildren`/`getChildrenCount` SIGSEGV, và `getType`
   cũng vậy);
   (iv) đổi `setType` **khác họ** (thanh → vòng) trên một node thanh cho ra hình
   **rác**, không phải hình quạt. Số đo trên `g_ptWarSoulTBar` (ô 71×297,
   `bt`): `cw` ở **25 / 50 / 75%** cho ra **cùng đúng 7820 điểm ảnh trên cùng
   khung** 303,200..356,450 (quạt thì ba phần trăm phải khác nhau), còn `ccw` cho
   ra **0 điểm**; trong khi đổi **cùng họ** thì đúng — `bt` → `tb` chuyển dải đáy
   334,394..356,450 thành dải đỉnh 303,200..356,256, khớp 25% của chiều cao. Nên
   mã gốc **chỉ** gọi `setType` trong cùng một họ (vòng ↔ vòng), đúng như chỗ gọi
   **duy nhất** của cả kho (`CUIDownload.lua:62-70`), và lấy node thanh ra đo vòng
   là đo ngoài vùng dùng được. Thêm một cái bẫy của chính phép đo: mặt nạ hiệu
   hai ảnh trộn **hình dạng đa giác** với **vùng đục của chính tấm ảnh**, nên
   "khung bao" không đọc ra bán kính.
   **Nhưng bảng mã kiểu thì nay đã có bằng chứng từ chính DỮ LIỆU** (không cần
   máy ảo) — quét cả 325 node, đối chiếu mã kiểu với **tỉ lệ ô** và **kích thước
   ảnh**:
   * `cw (0)`: **12** node, **11 vuông** (95², 81², 45², 28²; node thứ 12 là
     22×23), tỉ lệ dài/ngắn **1,00..1,05**; cả 12 là vòng đếm ngược / vòng nạp
     (`ui_time01`, `ui_shijiandaojishi`, `ui_background205`, `ui_background084`,
     `loading_2`)
   * `lr (2)`: **262** node, chỉ **3 vuông**, tỉ lệ **1,00..61,43**
   * `rl (3)`: **49** node, **0 vuông**, tỉ lệ **8,57..24,00**
   * `bt (4)`: **2** node, 1 vuông, tỉ lệ **1,00..4,18**
   * `ccw (1)` và `tb (5)`: **không node nào** — khớp bảng đếm {12, 262, 49, 2}
   Tức **vòng thì ô phải vuông, thanh thì ô dài** — khớp bảng mã `setType` của
   engine (ccw=1, cw=0, lr=2, rl=3, bt=4, tb=5) mà bản dựng đang dùng, và nay
   khớp với **dữ liệu**, không chỉ khớp với phép đọc bảng phương thức.
   Và câu hỏi "bán kính lấy theo **ô** hay theo **ảnh**" hoá ra **không đặt ra
   được** với dữ liệu thật: **7/12** node vòng có ảnh **đúng bằng** ô (95² cho
   `ui_background084`, 81² cho `loading_2`, 45² cho `ui_background205` bản
   `sngSplitData/v6/`), **5/12** lệch **đúng 1 px** (27×27 cho ô 28×28 — 4 node;
   21×22 cho ô 22×23 — `ptLeaderShipTimer`), và **0/12** lệch hơn 1 px. Hai luật
   chỉ khác nhau nửa điểm ảnh bán kính. (Con số 413×476 lúc đầu là do **tra nhầm
   bản trùng tên** `ui_background205.png` — đúng cái bẫy đã ghi ở mục "gán ảnh"
   của `tools/verify_lua_actions.gd`.)
9. ~~**Nhóm armature: ba hàm điểm gắn**~~ — **xong.** `_lua_addChildToPlugIn`
   (2 lúc quét, **33 chỗ gọi** trong mã), `_lua_clearPlugIn` (6 lúc quét / 10),
   `_lua_getPlugInPositionInNode` (5) **chưa từng tồn tại** ở lớp giả lập: tên
   không có trong bảng `Node` nên rơi vào `__index`, trả **bóng**, bóng gọi được
   → không lỗi nào được ném ra. **Cùng kiểu lỗi im lặng với `_godot_zsort` và
   `setGray`**, và đây là ca thứ ba.
   Đoạn khó không phải "gọi được" mà là **số trong tên plug là số thứ tự hay số
   chứ** — đoán sai thì mọi thứ vẫn chạy, chỉ là nhãn chữ treo vào sai xương, và
   **không có lỗi nào để đọc ra**. Đo trên 418 file `.xml` / 587 biến thể có
   plug (`PlugIn_1` 558, `_2` 513, `_3` 512, rồi `_30` 130, `_31` 50, `_11` 48,
   `_40` 21, `_5` 16, `_60` 16, `_6` 8, `_32` 7, `_4` 5, `_20` 3, `_50` 2,
   `_102` 1, `_7` 1), và khoá bằng ca không thể trùng ghi ở bảng trên.
   `tools/verify_plug.gd`
   (đã vào `check.py`) so **vị trí đọc lúc chạy** với **vị trí ghi trong chính
   file armature** `Gashapon` — dòng `Star1` có đúng bốn điểm gắn, mỗi điểm **một
   khoá duy nhất** nên vị trí là hằng số suốt động tác: lệch **0,000 px** cả bốn,
   hiệu ba cặp khớp `(-1,51 −114,11) / (49,97 −251,80) / (3,50 172,82)`, node
   treo lên đọc lại **đúng số người gọi đã viết**, và vị trí **toàn cục** của nó
   bằng gốc điểm gắn cộng đúng độ lệch **0,000 px**.
   Hai lỗi tự bắt được khi chạy phép đo lần đầu, đáng nhớ: (a) `pp.get_global_transform()`
   viết bằng `.` — binding của Godot báo lỗi ngay, và **cả `affine_inverse()` trên
   `Transform2D` cũng vậy**: mọi phương thức, kể cả của kiểu giá trị, phải gọi
   bằng `:`; (b) node treo lên điểm gắn **giữ nguyên `parent_h` của cha cũ**, nên
   `getPosition()` đọc lại lệch đúng bằng chiều cao ấy (640) dù node nằm đúng
   chỗ — đường `addChild` thường cũng đặt lại `parent_h`, nhưng nó chỉ làm khi
   cha **mới** là `Control`, còn ở đây cha là `Marker2D`.
   Còn lại của nhóm: `sngFixInfoReflash` (27 lúc quét, nằm trong danh sách thiếu
   của **cảnh `Main`** từ lâu) — **XONG**: luật đã đo, dữ liệu đã xuất, và nó nay
   là một phương thức thật do **chính bốn đường gọi của bản gốc** kéo chạy (đo
   được: gọi **5 lần**, đổi chỗ **3 node** trên đường Login → `Main`). Chi tiết,
   và việc duy nhất còn lại (`stretch/aspect` sang `expand`), ở mục sau.

   **`sngFixInfoReflash` — luật đã đo xong.** Tên lớp lấy
   từ chính `.so`: typeinfo `N7cocos2d16sngCCNodeFixInfoE` (chuỗi @ `.rodata`
   `0x7D2B37`, typeinfo @ `0x8793B0`, vtable @ `0x879370`). Hàm bind Lua là một
   shim **10 byte** @ `0x49C07E` → `0x4AEF96`, **duy nhất trong `.text`**, và cả
   **45 bảng lớp** đều trỏ vào cùng shim ấy — nên đây là phương thức của lớp node
   cơ sở, không phải của riêng lớp nào.

   Nó **đi khắp cây con** (bản thân `self` rồi mọi con cháu, qua `getChildren`)
   và với **mỗi node có bản ghi fix-info** (`+0x1C` khác 0) **và có cha** thì
   tính lại vị trí rồi `setPosition` (slot `+0x74`). Con cháu cũng được tính lại,
   **mỗi cấp dùng `contentSize` của cha nó** — đo được: cháu
   `g_EquipForgeUIEffectSmaillIconBg` từ `(-777, -888)` về `(39,5; 39,5)`.

   **Tám số ấy nằm ngay trong `.xgg`.** Chỗ tắc cũ ("quét .xgg không thấy") là vì
   đi tìm sai chỗ: bản ghi node mang **8 số int32 liền nhau ở `+0x38`**, thứ tự
   `+0x38` = kiểu **y**, `+0x3C` = kiểu **x**, rồi `+0x40 o40`, `+0x44 o44`,
   `+0x48 o48`, `+0x4C o4C`, `+0x50 o50`, `+0x54 o54`. Nghĩa là
   `struct.unpack_from('<8i', data, a+0x38)` ra **kiểu y TRƯỚC** — đọc nhầm thứ tự
   ấy sinh ra đúng hai con số đếm sai (2.622 và 2.302) đã ghi ở các lượt trước.

       pw, ph = cha->getContentSize()            ; slot +0xB4
       w, h   = node->getContentSize()           ; +0xB4
       sx, sy = node->getScaleX() / getScaleY()  ; +0x60 / +0x68
       ax, ay = node->getAnchorPointInPoints()   ; +0xAC
       axs, ays = ax*sx, ay*sy ;  ws, hs = w*sx, h*sy

       x: 0 -> để yên   1 -> o40 + axs
                         2 -> (pw - w)*0,5 + ax + o50    ; hộp CHƯA co giãn
                         3 -> pw - (ws - axs) - o44
       y: 0 -> để yên   1 -> ph - (hs - ays) - o48
                         2 -> (ph - h)*0,5 + ay + o54    ; hộp CHƯA co giãn
                         3 -> o4C + ays

   Đọc theo mép thì: kiểu 1 ghim mép **trái** ở `o40` và mép **trên** ở
   `ph - o48`; kiểu 2 ghim **tâm** hộp ở `pw/2 + o50` / `ph/2 + o54`; kiểu 3 ghim
   mép **phải** ở `pw - o44` và mép **dưới** ở `o4C`. Cặp trái/trên với phải/dưới
   đúng như một trình sửa gốc toạ độ góc trên-trái.

   **`x,y` trong bản ghi KHÔNG phải giá trị của trình sửa — nó chính là kết quả
   công thức.** Con số "chỉ ~47% khớp" ghi ở đây trước kia là **sai**, và sai vì
   đọc nhầm thứ tự hai byte kiểu (`+0x38` là **y** trước, `+0x3C` mới là **x**).
   Đọc đúng thứ tự rồi tính lại ở **cỡ cha lúc thiết kế**: khớp **47.605/48.089
   trục = 99,0%**, lệch **484**. Chương trình kiểm là `brave-cross/work/
   fix_info.py --lech` (thêm `<tên file>` để xem từng node) — nó không chạy gì,
   chỉ tự tính lại từ `.xgg` rồi đối chiếu với số đã lưu, nên đây là đường đo
   **độc lập** với `emu_pt.py`.

   484 trục lệch ấy không phải lỗi công thức mà là **chỗ người làm bố cục chỉnh
   tay sau khi đặt xong**, và chúng tụ lại thành nhóm: `x k=(1,2)` 57,
   `x k=(1,3)` 42, `y k=(1,3)` 41, `x k=(3,2)` 38, `x k=(3,3)` 34, `y k=(3,3)` 34.
   Theo file: `UI_Main_960_640` **0**, `Main_Dialog_UI_960_640` **0**,
   `UI_NormalDlg_960_640` **0**, `UI_Main_ControlPanel_960_640` **1** —
   `lMainToolbarTop` lưu `x = 0` trong khi công thức ra `30` — và
   `UI_AccountLogin_960_640` **8 trục, cả 8 đều `k=(2,3)`**: tám nút ấy lưu
   `x = 480` (giữa) trong khi công thức ra 328/632/330/630, kể cả `snsQuickEnter`
   `480 -> 328`. Tức cả một họ nút bị **kéo về giữa bằng tay** sau khi đặt theo
   luật — đúng loại việc mà một trình sửa bố cục vẫn làm.

   Ghi chú: bảng giải mã tĩnh ở lượt trước
   ghi **số hiệu hai nhánh y đổi chỗ cho nhau** (nó gọi `info[+0x2C] + ay*sy` là
   "y 1"); phép đo dưới đây nói nhánh cộng ấy là **y 3**, còn sáu nhánh kia thì
   hai bên khớp nhau. Bản đo thắng, vì nó chạy chính file `.so` ấy.

   **Kiểu 1 và 3 dùng hộp ĐÃ co giãn; kiểu 2 dùng hộp CHƯA co giãn.** Bất đối
   xứng này là chỗ dễ viết sai nhất, và nó bị ghim bằng ba phép đo: `lCUICOGMap`
   (`scale 0,8`) đo được `(-945,0; -797,5)` ở `960x640` và `(-875,0; -737,5)` ở
   `1100x760`, tức `(P-2850)/2` và `(P-2235)/2` — cách đọc "kiểu 2 cũng co giãn"
   lệch **285 điểm**; `g_UpgradeQualityActionMaterialItem` (`x = 250`) cần neo
   **chưa** nhân (`39,5`, không phải `31,6`); `lHeroInfoUIDetails` (`y = 75` ở
   `ph = 700`) là `(700-550)/2` chưa nhân, không phải `(700-539)/2 = 80,5`.

   Trục nào **không** thuộc 1..3 thì **giữ nguyên**: bộ đệm toạ độ được khởi đầu
   bằng chính `getPosition()` hiện tại (copy ở `0x4AF6B2`) rồi mỗi trục ghi đè
   phần của mình — nên kiểu 0 là "không đụng tới", không phải "về 0". Đo được:
   `btnEquipForgeUINavigation2/3` đứng yên ở `x = -777` trong khi `y` được tính
   lại thành `753,4`.

   Đúng chỗ gọi: `SetWHScaleToWinSize` **kéo lớp theo tỉ lệ màn hình**
   (`setContentSize(LogicWinSizeH*realW/realH, LogicWinSizeH)`, hoặc nhánh kia
   `(LogicWinSizeW, LogicWinSizeW*realH/realW)`) rồi reflash — tức các node neo
   phải/giữa trong lớp đó **phải chạy ra mép mới**. `CUITimeHero.lua:49` cũng
   vậy: đặt lại cỡ cho con tag 2 bằng cỡ của `lMainBtnLayer` rồi reflash.

   **Số đã đo được** (mỗi số đọc thẳng từ `.xgg`, không suy ra): `o40 = 25`
   (`btnEquipForgeUINavigation1`, `x = 25 + 39,5*0,8 = 56,6`); `o44 = 20`
   (`btnLoginOpenProtocol`, `ttfLoginUISceneVer`) và `28`
   (`btnHeroEquipUIToRight`, `x = 880 = 880 - (-56 + 28) - 28`); `o48 = 15`
   (`nav1`, `ttfLoginUISceneVer`), `20` (`btnEquipUpgradeQualityCompoundNav2/3`),
   `49` (`g_UpgradeQualityActionBeginLayer`); `o4C = 20` (`snsQuickEnter`,
   `y = 59,5` ở cả hai cỡ cha), `50` (`g_ServerNodesLayer`, `y = 50`), `100`
   (`btnLoginOpenProtocol`); `o50 = -152` (`snsQuickEnter`, đo ở hai bề rộng
   cha); `o54 = -25` (`lHeroInfoUI`/`lStarSoulMain`, ba chiều cao) và `+25`
   (`lQQCoinsGift`, hai chiều cao) — tức `o50`/`o54` là **số cộng có dấu**,
   không phải độ lệch luôn dương.

   **Cách kiểm lại:** `brave-cross/work/emu_pt.py` là chương trình ĐO (chạy bản
   gốc trong máy giả lập rồi đọc vị trí ra), `brave-cross/work/fix_info.py` là
   chương trình KIỂM (không chạy gì, tự tính lại từ log thô `_pt/*.log` cộng
   chính file `.xgg`). Hai đường tính khác nhau; `fix_info.py --kiem` ra **khớp
   81, lệch 0**. Chương trình kiểm ấy bắt được **hai lỗi công thức** mà chương
   trình đo đã ship: nhánh y-1 dùng `h` chưa nhân scale (`487,6` thay vì
   `503,4`), và nhánh kiểu 2 dùng hộp đã nhân scale (lệch 285 điểm ở
   `lCUICOGMap`) — nên nó giữ luôn hàm `cong_thuc_scaled()` để in ra cách đọc sai
   ấy cạnh số đo.

   **Còn đúng một chỗ CHƯA đo được, và không đoán:** số hạng neo của kiểu 2 có
   nhân scale hay không. Cả kho **296 file `.xgg` / 33.472 node** chỉ có **đúng
   1 node** phân biệt được hai cách đọc, và node ấy **không tên**, cha cũng không
   tên, `scaleX = 0` (`fix_info.py --dem` in ra con số ấy). Cách đọc "chưa nhân"
   được chọn vì ba phép đo ở trên, không vì node ấy.

   **Chính sách co giãn của bản port — (a)-(e) XONG hết.**
   `project.godot` đặt `viewport 960x640`, `stretch/mode = "canvas_items"` và
   `stretch/aspect = "expand"`. Bản gốc lấp kín màn hình — trên 16:9 vùng thiết kế
   nhìn thấy là **1137,8×640** — nên `expand` mới đúng, `keep` (mặc định của
   Godot) thì canvas luôn đúng 960×640 và hai bên có viền đen.

   Bốn việc đầu nay đã làm, và **khác bản ghi cũ ở chỗ (c)+(d) không cần tự
   gọi**: (a) `work/xgg.py` xuất tám số ấy với khoá `fix`; (b) `ui/xgg_layout.gd:
   507-511` giữ chúng làm meta `fix` của node; (c) `XggLayout.reflash()` là công
   thức — **đệ quy, mỗi cấp dùng `contentSize` của cha nó, kiểu 2 theo dạng
   KHÔNG co giãn**, và nó trả về **số node đã đổi chỗ**; (d) **không gọi lúc dựng
   bố cục** — thay vào đó `Node:sngFixInfoReflash` là một phương thức trong
   `lua/cocos.lua`, nên **chính bốn đường gọi của bản gốc** kéo nó chạy. Cách này
   là cách của bản gốc, và nó đã sửa một lỗi thật: bản port trước đây reflash **cả
   cây** lúc dựng, đẩy gốc hộp thoại `CUINormalDlg` (KHÔNG có cờ
   `IsFullScreenAdaptation`) từ `110,30` thành `60,35`.

   **Việc (e) — đổi `stretch/aspect` sang `expand` — XONG lượt này.**
   Làm được vì đọc ra **công thức của chính bản gốc**, không phải vì "thấy giống":
   `CSceneManager:SetWHScaleToWinSize` (`sc/user/Public/CSceneManager.lua:305-326`,
   với `LogicWinSizeW/H = 960/640` khai ở `:73-74`) có **hai nhánh**:

       if realW/realH > 960/640 then  setContentSize(640 * realW/realH, 640)
       else                           setContentSize(960, 960 * realH/realW)

   tức **giữ chiều DÀI của 960×640 rồi nở chiều còn lại** — rộng hơn 1,5 thì cao
   đúng 640 và rộng ra; hẹp hơn 1,5 thì rộng đúng 960 và cao ra. Đó **đúng bằng**
   cách Godot tính `expand` (hệ số phóng `min(W/960, H/640)`), và hai đường tính
   ấy đã đối chiếu chứ không tin nhau: `tools/verify_co_gian.gd` chép lại công
   thức hai nhánh từ `sc/` rồi so với công thức `expand` trên **301 tỉ lệ từ 1,0
   đến 2,5** — **lệch lớn nhất 0,000000000 điểm**, tức hai đường tính là **một**.

   **Đo bằng cửa sổ thật** (`tools/do_co_gian.gd`, 5 đạt / 0 hỏng ở cả ba cỡ):

       960x640   -> canvas  960x640    (tỉ lệ 1,5 -> min(1,1) = 1, y như cũ)
       1920x1080 -> canvas 1137x640    (nở ra; 1137,78 bị Godot làm tròn còn 1137)
       1024x768  -> canvas  960x720    (nhánh thứ hai, co lại)

   Hai điều đáng ghi trong phép đo ấy. **Một**, Godot làm tròn `visible_rect` về
   **số nguyên**, nên 1920×1080 cho canvas **1137** chứ không phải 1137,78 — đúng
   số đã đo trên máy ảo (1137,8) sai khác dưới 1 điểm, và phép kiểm vì thế phải
   cho phép **1 điểm** chứ không phải 0,5 (lần đầu tôi đặt 0,5 và nó báo hỏng —
   bản thân ngưỡng sai, không phải hình học sai). **Hai**, phép kiểm "tỉ lệ của
   `Window.size` bằng tỉ lệ canvas" phải tính từ **tỉ lệ cửa sổ** rồi mới so, chứ
   lấy tỉ lệ canvas làm đầu vào thì phép kiểm thành vòng tròn (đo chính cái đang
   kiểm); sai số cho phép lấy từ chính phép làm tròn, `1/cao` = 1/640.

   Và (e) **không chỉ là chuyện thẩm mỹ** — nó sửa một chỗ lệch thật đã có sẵn:
   `lua_runtime.gd:166-178` đổ `Window.size` vào `screenWidth/screenHeight`, mà
   `Window.size` là **kích thước CỬA SỔ tính bằng điểm ảnh** (đo được: cửa sổ
   1920×1080 -> `Window.size` = 1920×1080, tỉ lệ 1,7778). Với `keep` thì canvas
   vẫn 960×640 (tỉ lệ 1,5), nên `SetWHScaleToWinSize` **dùng một tỉ lệ khác với
   khung đang vẽ ra** và đặt cỡ lớp Main thành 1137,78 trong một khung rộng 960 —
   tức đẩy chúng ra ngoài khung. Với `expand` thì cửa sổ **không còn viền đen**,
   hai tỉ lệ bằng nhau (sai khác chỉ còn phép làm tròn số nguyên ở trên).

   **Không đổi gì ở 960×640** và **không đổi gì khi chạy `--headless`**: ở đó
   `screenWidth/Height` lấy từ `Window.size` = 100×100, tỉ lệ 1,0, hai bên y hệt
   nhau trước và sau — nên 33 bộ của `check.py` vẫn xanh. Các bộ `tools/*` cũng
   không đổi, vì chúng tự đặt `cua_so_engine` = 1152×768 (tỉ lệ 1,5) chứ không
   lấy cửa sổ thật; và **chưa cảnh sản phẩm nào đặt `set_touch_root`** — hiện chỉ
   `tools/*` gọi nó.

   **Một chỗ `expand` KHÔNG khớp bản gốc, ghi ra chứ không im lặng bỏ qua:**
   `GetLiuHaiWidth()` (`:287-299`) **trừ bớt bề ngang tai thỏ** khỏi `realW` trước
   khi tính tỉ lệ, nhưng chỉ trên **iOS** và chỉ khi **tỉ lệ > 2,0** (dòng đầu trả
   `0` khi `LGG_GetPlatformString() == "android"`, dòng sau trả `0` khi
   `fRate <= 2.0`). Nên 1137,8×640 đo được trên máy ảo **là đường không khuyết**,
   và `expand` tái tạo đúng đường ấy; còn máy iOS tỉ lệ > 2,0 thì bản gốc **thu
   hẹp** vùng thiết kế để chừa tai thỏ, `expand` thì không. Muốn khớp thì phải
   thêm phép trừ ấy, **hiện chưa làm** (máy tính và Android đều không đi vào nhánh
   đó).

   Hai bộ giữ việc này: `tools/verify_co_gian.gd` (**15 đạt / 0 hỏng**, trong
   `check.py`) kiểm cài đặt dự án là `expand`, công thức hai nhánh **vẫn còn
   nguyên trong `sc/`** (neo vào mã gốc chứ không vào trí nhớ người viết), hai
   dòng `GetLiuHaiWidth` trả 0, và hai đường tính bằng nhau trên 301 tỉ lệ; còn
   `tools/do_co_gian.gd` (cửa sổ thật, **5 đạt / 0 hỏng** ở cả ba cỡ) đo các con
   số mà chế độ `--headless` không đo được vì nó dùng trình điều khiển hiển thị
   giả nên `--resolution` không có tác dụng.

   **Bốn đường gọi ấy, đầy đủ (grep trên `sc/`, không còn đường nào khác):**
   1. `CSceneManager.lua:304` `SetWHScaleToWinSize` — đặt `setContentSize` rồi
      gọi `uiObj:sngFixInfoReflash()` ở `:326`. Người gọi nó:
      - `PreLoadFinish` (`:331`) — **chỉ có nhánh cho cảnh `"Main"`**
        (`lMainBtnLayer`, `lDialogControlPanel`) và cảnh `"Battle"` (18 lớp, kể
        cả `g_GameUILayer`, `lUITopLayer`, `lUIDrama`, `lGameUIWakeSkill`,
        `lUIGameLogic`, `lUINormal`, `clBattlePause`); **không nhánh nào cho cảnh
        khác** — nên đừng trông nó chạy ở màn khác.
      - `OnLoadNextScene` (`:556`) — `UIRootLayer`, mỗi lần đổi cảnh.
   2. `CUIPublic:onInit` (`CUIPublic.lua:203`) — chỉ với **27 màn** có
      `IsFullScreenAdaptation = true`.
   3. `FBHeroPK.lua:38`. 4. `CUITimeHero.lua:49`.
   `CUILottery.lua:1034` bị comment; `CMessageBox.lua` có 6 chỗ comment.
   `sngFixInfoReflash` là **phương thức C++** của bản gốc (`N7cocos2d16sngCCNode
   FixInfoE`, shim `0x49C07E` → `0x4AEF96`) — **không file Lua nào định nghĩa
   nó**, nên thiếu nó thì **không một lỗi nào**, chỉ là mọi node neo đứng yên.
   Vì vậy phải **đếm** mới biết nó có chạy (`LuaRuntime.fix_reflash`).

   **Đo trên đường Login → `Main`** (`tools/vao_main.gd`):

       sngFixInfoReflash: ma goc goi 5 lan, doi cho 3 node
           UIRootLayer (31.573, 63.819) -> (96.0, 64.0)      ×2 (hai bản mỗi cảnh)
           lMainToolbarTop (0.0, 0.0) -> (30.0, 0.0)

   `UIRootLayer` mang `fix = [2,2,0,0,0,0,0,0]` — **cả hai trục kiểu 2, lệch 0**,
   tức "canh giữa ta trong cha"; mà cha nó là **cảnh 1152×768** còn nó thì
   `960×640`, nên ra đúng `(96, 64)`. `lMainToolbarTop` thì lưu `x = 0` mà công
   thức ra `30` — **đúng bằng dòng `UI_Main_ControlPanel_960_640` của
   `fix_info.py --lech`**, tức phép đo trong game và phép đo trong Python gặp
   nhau ở cùng một node.

   **Cửa sổ đo được** (đặt trong `tools/vao_main.gd`, không lấy từ `root.size`
   vì lúc `_init` cửa sổ chưa về cỡ thật):

       win=1152x768   UIRoot=960x640   fScale=1.2   MainScroll=1366x768

   Tỉ lệ cửa sổ **đúng 1,5**, nên `GetLiuHaiWidth()` trả `0` và `fRate <= 2.0`;
   hệ quả là `SetWHScaleToWinSize` chỉ đặt `setContentSize(960, 640)` — **không
   đổi gì** — và **chỉ riêng reflash có tác dụng**. (Cửa sổ của máy ảo thì khác:
   đo được cả **13 CCScene là 1429×768**, tỉ lệ 1,86 — trên máy thật nhánh co giãn
   ấy *sẽ* chạy; đó là việc (e), **nay đã làm** — xem ở trên.) Ghi chú riêng, cùng
   họ: `MainScroll` là **1366×768** trong bản ghi, khác cỡ cảnh 1152×768 của port
   — một việc **khác**, chưa đụng tới.

   Một chi tiết dễ sai khi đo: ngưỡng "đổi chỗ" phải là **0,01 điểm**, không phải
   `is_equal_approx` — đường Cocos → Godot → Cocos đi qua một lần làm tròn nên
   node **đứng yên** vẫn lệch lại ~2e-5 (đo được `lMainToolbarRight -1,599976 ->
   -1,599999`). Không có ngưỡng thì con số "đổi chỗ mấy node" đếm cả node không
   hề nhúc nhích.

   Cách đọc bảng "slot vtable → tên": shim của mỗi phương thức là một chuỗi
   `ldr rX,[r0]; ldr rX,[rX,#off]; blx rX`, nên quét 690 tên trong bảng bind
   (`.data` `0x92C000`.., bản ghi 12 byte `{trỏ tên, trỏ hàm, 0}`) là dựng được
   **bảng đối chiếu offset ↔ tên** cho từng lớp — 65 slot đọc ra tên. Đó là cách
   biết `+0x100` là `getChildren`, `+0x108` là `getParent`, `+0xB4` là
   `getContentSize`. Riêng `+0xAC` không tên nào ánh xạ tới; đọc nó là
   `getAnchorPointInPoints()` vì (a) bảng lớp ấy ánh xạ `getAnchorPoint` sang
   **`+0xA8`**, khác slot, và (b) công thức mode 3 chỉ đúng đơn vị nếu `+0xAC`
   là toạ độ **điểm ảnh**, không phải tỉ lệ 0..1.
10. ~~**`RichLabel` tách từng chữ**~~ — **xong.** `getLimitShowCount` (48 lượt gọi)
    và `getLetterEx` nằm trong lớp C++ `Label` của engine
    (`RichLabel.lua:550-554` tạo bằng `Label:new()` rồi `createWithTTF`).
    Lượt trước ghi "trả một con số đoán ra ở đây là đổi cách hiện chữ, nên để
    nguyên" — câu ấy **không còn đúng**, vì câu hỏi đã đổi:
    `getLimitShowCount` là **số ký tự của chính chuỗi đang có** (`gd.text`), không
    phải một con số của engine; thứ duy nhất phải chọn là **đơn vị đếm**, và đơn
    vị ấy đo được — chuỗi ở đây là UTF-8 nên đếm **byte** thì một chữ 2 byte bị cắt
    đôi. Đếm **điểm mã** (một chuỗi tiếng Việt có dấu), và
    `tools/verify_richlabel.gd` đòi số node chữ **bằng** số ký tự.

    Đo được **trước** khi làm (`tools/chay_lua.gd`, đoạn dò `RichLabel`): khi hai
    hàm ấy còn trả `0` / `nil` thì `_spriteArray` rỗng, nên `adjustPosition_` chỉ
    đặt chỗ cho ảnh — **mọi đoạn chữ nằm im ở `(0,0)` của `_containLayer`**, chữ
    của các đoạn chồng lên nhau. Bản gốc không như vậy: `createSprite_`
    (`:550-557`) lấy **từng ký tự** ra làm sprite rồi xếp lại.

    Đoạn khó không phải chuyện tách chữ mà là **chiều cao của cha**: node tạo lúc
    chạy mang sẵn `parent_h = 640` (`_new_node`), còn nhãn đoạn chữ chỉ cao ~23.
    A/B trên cùng một chuỗi: giữ 640 thì sau `adjustPosition_` mọi ký tự ra
    **y = 617** (đúng `640 − 23` — vì `to_godot` cộng thêm `parent_h`), tức rơi ra
    ngoài khung 617 px; đặt lại bằng `gd.size.y` thì ra **y = 0**, đúng bằng chiều
    cao lớp. Nên ký tự là **con của nhãn đoạn** (để `parent_h` đi theo), và nhãn
    đoạn bị **ẩn** — nếu không thì mỗi đoạn chữ hiện **hai lần**, một lần tại chỗ
    cũ và một lần tại chỗ `adjustPosition_` xếp. Chỗ "ẩn" là **suy ra từ cấu trúc**
    (`_containLayer` chỉ `addChild` nhãn đoạn mà **không đặt chỗ** cho nó,
    `:548` so với `:550-557`), **không** phải đọc từ engine — ghi lại đúng như vậy.
    Một chỗ nữa **không có gì để khôi phục**: `fAdvance` bản gốc lấy từ số đo font
    của engine, ta lấy bề rộng hiện ra của chính chữ ấy — hai số không thể bằng
    nhau từng byte, và phép kiểm chỉ đòi nó **dương**.

    `getLetterEx` có **hai** kiểu gọi, cả hai đều thật: theo **chỉ số** (0..n−1,
    `RichLabel.lua:552`) và theo **ký tự** (`CGuideLogical.lua:221`, `:315`). Kiểu
    theo ký tự **chỉ tra trong số chữ đã tách ra**, không tự cắt: `CGuideLogical`
    truyền vào một nhãn của bố cục mà nó không hề xếp lại từng chữ, nên cắt ở đó
    thì mọi chữ đổ lên một chỗ; trả `nil` thì `:315` (`if pLetter then`) tự bỏ qua
    — đúng như trước. Kèm `Node:boundingBox()` (trả đủ **bốn** số): bản gốc chỉ
    đọc hai số cuối (`:280`) nhưng `:282` so `w < fAdvance`, thiếu số thì ném
    `attempt to compare nil with number` — lỗi đã gặp thật.

    `tools/verify_richlabel.gd` — **20 đạt / 0 hỏng** (đã vào `check.py`, bộ thứ
    **31**): `[fontColor=0000FF]Vu khi[/fontColor] dep` ra **2 đoạn** (trước là 1),
    đoạn đầu mang màu của thẻ và chữ **không** còn thẻ, ghép các node chữ lại ra
    đúng `Vu khi dep`, mỗi node đúng **một** ký tự, không ký tự nào ra ngoài khung
    lớp, đổi chuỗi thì số node đổi theo và con của chuỗi cũ bị bỏ **hết**.
    Một lỗi tự bắt được khi viết phép kiểm, đáng nhớ: tôi viết "node chữ là con
    của **lớp**" và nó **hỏng** — `getParent()` trả về **nhãn đoạn**; chính phép
    kiểm ấy là thứ xác nhận lại kết luận `parent_h` ở trên.

11. ~~**Ô chữ của nhãn — `setDimensions` / `autoFixSize` / `setContentSize`**~~ —
    **xong**, và đây là lần nữa cùng loại với việc 7 và việc 10: ba API ấy bị gọi
    trong im lặng (`quet_show.gd` đếm được **`setDimensions` ×10, `autoFixSize`
    ×38** ở bảng "API Cocos CHUA LAM") chứ không ném lỗi. Luật đầy đủ, số đo và
    hai lỗi im lặng bắt được: **mục 3, "Ô chữ của nhãn"**. Tóm lại: bản gốc giữ
    **ba** trường (ô, cặp trả lời, cờ autoFix), `getContentSize` không phải kích
    thước node, và cờ "bẩn" `+0x20d` được bật **vô điều kiện** trong `setString`
    nhưng **không** được `setContentSize` xoá — nên lần đọc đầu sau
    `setString("")` + `setContentSize(0, 0)` vẫn bố cục lại (`CUIAnniversaryHeaven.lua:277-284`).
    Khoá bằng `tools/verify_dimensions.gd` (**25 đạt / 0 hỏng**, `check.py` bộ thứ
    **32**), chạy đúng chuỗi bước của `emu_nhan.py` và đã qua **phép thử phá**
    (bỏ luật ⇒ 10 hỏng đúng chỗ).

    **Đo hồi quy của riêng việc này** (so **tên màn**, không so tổng): dựng lại
    đúng bản trước khi sửa bằng `git show <commit cũ>:lua/cocos.lua`, quét, rồi trả
    lại và `git status --short lua/cocos.lua` phải rỗng. Kết quả: **danh sách tên
    màn hỏng giống hệt nhau** giữa bản trước và **cả hai** lượt sau (`diff` rỗng,
    62 tên), tổng đều `291 mở / 0 im / 62 hỏng`, và bảng "API Cocos CHUA LAM"
    **16 loại → 15 loại**, mất đúng `setDimensions ×10` như dự đoán. Một lượt sau
    duy nhất ra `290 / 63` với `g_CUISubDialog/UIFuctionOpen` hỏng thêm — chứng
    minh là **dao động**, không phải hồi quy: tên ấy **cũng có** trong bản quét cũ
    trước khi sửa, và hai lượt sau còn lại đều cho `291 / 62` với tên ấy mở được.
    (Đó cũng là lý do luật của dự án cấm so tổng: ±1 màn ở đây là nhiễu.)

Việc 2(b) rẻ và mở đường cho việc 4. **Việc 7 vừa xong, và nó đổi thứ tự ưu
tiên**: nó là một lỗi im lặng **trong chính lớp giả lập**, đúng loại đã gặp ở
`setGray` — nên câu hỏi đúng không phải "còn thiếu API nào" mà là "**còn tên nào
được gọi mà chưa từng được viết**". Bảng "API CHUA LAM" của `quet_show.gd` trả lời
được câu đó, và `reorderChild` là ca đầu tiên nó bắt đúng. Sau đó là việc 4 (bỏ
ĐẶT trong trận); việc 9, việc 10 và việc 11 nay **đã xong**, nên chỗ còn phải đo
bằng máy ảo hoặc đọc `libgame.so` chỉ còn **việc 8** (`setPercentage`).

**Việc 8 nay cũng xong** — và nó xong **mà không cần máy ảo**: ba trường cần thiết
nằm ngay trong bản ghi `.xgg` (`+0xF4` kiểu, `+0xF8` phần trăm, `+0xEC`/`+0xE4`
tên ảnh). Xem mục 8 việc 8 cho số đo đầy đủ và cho **hai chỗ còn lại đã ghi rõ là
chưa khôi phục được**: công thức chiều dài đầy (hai thanh cho hai luật khác nhau,
nên cơ chế thật chưa tìm ra) và góc/chiều của vòng (bản ghi có **12 node vòng**,
nhưng chỉ **một** trong đó được mã gốc quay thật — lượt đo bằng máy ảo lần này
**vẫn không lấy được góc**, và lý do đã ghi rõ là lý do đo được: node vòng thật
nằm dưới lớp UI, node vòng thứ hai có tên thì `vis = False`, mười node còn lại
không tên, và đổi `setType` khác họ trên node thanh cho ra hình rác — xem mục 8
việc 8). Đây là lần thứ hai trong dự án một việc bị xếp vào loại "phải có máy
ảo" hoá ra **đo được bằng dữ liệu đã có** — lần trước là `setGray`. Nên trước khi
kết luận "phải chạy bản gốc", hãy đọc lại bản ghi theo **từng byte** và tự hỏi bộ
trích của mình có đang mang trường ấy ra không.

12. ~~**Chuyển sắc chữ** (`enableGradual` / `disableGradual` /
    `getEnableGradualColor` / `IsEnableGradualColor`)~~ — **xong**, và nó là món
    to nhất còn lại của bảng "API Cocos CHUA LAM". Chi tiết + số đo: mục "Chuyển
    sắc chữ" trong phần "Lớp giả lập" ở trên. Hai điều đáng nhớ:
    (a) câu cũ "bố cục không có nhãn chuyển màu nên không cần làm" là **kết luận
    sai** — nhãn ấy do **mã** bật lúc chạy, và `sc/` có **8 chỗ gọi thật**;
    (b) `VERTEX` đọc trong `fragment()` của Godot 4.7 là toạ độ **khung vẽ**, nên
    dải chuyển sắc lệch theo chỗ node đứng — lỗi **im lặng**, bắt được bằng phép
    đo điểm ảnh (`tools/do_chuyen_sac.gd`, 15 đạt / 0 hỏng), và mục "đừng tìm
    lại" của `README.md` nay ghi lại.

Ba món của lượt này (việc 10, 11, 12) đều thuộc **cùng một loại**: API mà `sc/`
gọi tới nhưng lớp giả lập **chưa từng viết**, nên tên rơi vào bảng `Node` và trả
`nil` — không lỗi, không cảnh báo. Bảng "API Cocos CHUA LAM" của `quet_show.gd`
vẫn là chỗ để đọc tiếp. Đếm **tĩnh** trên `sc/` (số lần **xuất hiện** của tên, to
hơn số lần bộ quét **chạy** bắt gặp vì phần lớn nằm ở màn chưa mở được):

| tên | lần | ghi chú đã kiểm |
|---|---|---|
| `initWithSpriteFrameName` / `initWithSpriteFrame` | 66 / 9 | đặt khung hình cho sprite — bản port đặt ảnh bằng đường khác |
| `setText` | 38 | **đã xong** — cả 38 chỗ đều là `CCEditBox`, xem mục "Ô nhập chữ" |
| `_ShowShadow` | 20 | **đã xong** — cả 20 đều gọi trên node armature (`getSpriteFromSpriteCatch` → `SngRig`), chỗ làm là `rig/sng_rig.gd`. Kèm theo `_SetSyncShadowPosY` (3 chỗ) và `_UpdateShadowPosY` (0 chỗ) — xem mục "Bóng của armature" |
| `_lua_CollisionSize` | 6 | cùng họ `_lua_*` của armature |
| `_Lua_addStarLevelEffect` | 4 | |
| `setLuaCallbackObjAndFunc` | 3 | **đã xong** — nối ô nhập chữ với hàm Lua, cùng lượt với `setText` |
| `setSoundStrArr` | 2 | |

Món đáng làm trước nay là **`_ShowShadow`** — và **đã xong**, cùng lượt với
`_SetSyncShadowPosY` / `_UpdateShadowPosY`. Ghi chú cũ ở đây gọi nó là "rẻ — chỉ
là bật/tắt bóng": **sai**, xem mục "Bóng của armature" (nó **tạo** bóng khi `true`
và **xoá hẳn** khi `false`, bóng là một `Shadow.png` dùng chung ở `zOrder −10`, và
phần `y` mặt đất đi theo một ô của armature). Hai món `setLuaCallbackObjAndFunc`
(3) và `setText` (38) **đã xong cùng lượt với ô nhập chữ** — xem mục "Ô nhập chữ"
ở phần "Lớp giả lập" phía trên.
