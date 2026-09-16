# Lộ trình dựng lại Búa Tạ

Danh sách mọi phần cần làm để ra được game, kèm chỗ đang đứng. Cập nhật
2026-09-15.

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
| Bộ kiểm | **27**, xanh hết | `tools/check.py` |

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
- [ ] Còn thiếu ở `Main`: `sngFixInfoReflash`
- [ ] Lớp phủ hướng dẫn `g_CGuideLogical`

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

### Lớp giả lập: những gì đã làm thêm trong lượt này

| API | chỗ gọi | làm gì | cơ sở |
|---|---|---|---|
| `getColor` / `setEffectColor` / `getEffectColor` | 1.281 mỗi cái | màu chữ + màu viền, lưu/trả được | `CUIPublic:SetLableGray` (`:390-431`) lưu `getColor()` **(3 số)** và `getEffectColor()` **(4 số)** rồi trả lại — trước đây `getColor()` ra `nil` nên `c.r or 255` ghi ra màu gần như trong suốt |
| `setGray` / `isGray` | 683 / 214 | **trạng thái** xám (chưa làm phần HÌNH) | trước đây `isGray()` ra `nil`, mà `nil` không bằng `false` lẫn `true`, nên cả hai lối viết (`if btn:isGray() == false` và `if not btn:isGray()`) đi sai hướng trong im lặng |
| `setCascadeOpacityEnabled` | 56 | no-op **đúng nghĩa** | 56 chỗ đều truyền `true`; Godot cho `modulate` lan xuống cây **luôn**, tức đã làm sẵn đúng điều được xin |
| `refreshChildArray` | 45 | no-op **đúng nghĩa** | ở đây không có mảng con nào để dựng lại: `getChildByTag` quét thẳng con của Godot |
| `setHorizontalAlignment` | 8 | căn chữ | thứ tự enum y `alignH` của `.xgg`, và Godot dùng **đúng ba số 0/1/2** ấy (`ui/xgg_layout.gd:229-233`) |
| `getFontSize` | 7 | cỡ chữ đang dùng | `CUINewHandPrivilege.lua:184` lấy cỡ chữ nhãn cha truyền xuống `RichLabel` |
| `removeAllChildrenAndArray` | 37 | bỏ hết con + huỷ | cùng nghĩa `removeAllChildrenWithCleanup`; khác `removeChildByTag`, ở đây **không** có kho nào nhận lại node |
| `_lua_getAnimationTime` / `_lua_setAnimationRate` / `_lua_stop` / `_lua_setOpacity` | 97 / 26 / 24 / 2 | 4 lệnh armature | thêm 3 method vào `rig/sng_rig.gd`: `thoi_luong` (giây — **thiếu thì trả 0**, mà 0 giây = đi tiếp ngay), `dat_toc_do`, `dung` (giữ nguyên tư thế: Cocos `stopAnimation` **không** đưa về khung 0) |

Ba thứ **cố ý KHÔNG làm**, ghi rõ để lần sau không đoán:

* **`setPercentage` (139 lượt, 325 node, 83 file)** — đo rồi mới quyết: quét cả
  325 bản ghi `CCProgressTimer` ở **mọi** offset 4 byte **không** tìm ra cặp float
  nào khớp midpoint `(0.5,0.5)` hay barChangeRate `(1.0,0.0)` ngoài hai trường đã
  biết (scale/rot ở `+0x88`, neo ở `+0x90`). Mà bản gốc **không hề gọi**
  `setType`/`setMidpoint`/`setBarChangeRate` (**0 chỗ gọi** trong 973 file) — nên
  kiểu thanh hay vòng, và chiều chạy, là **mặc định C++ của engine**, chưa giải
  được. Chốt bằng máy ảo (`work/emu_dom.py`) hoặc đọc binding trong `libgame.so`.
  **Đoán là sai kiểu `AchieveType`.**
* **`getLimitShowCount` / `getLetterEx` (48)** — đây là chế độ **tách từng chữ
  thành sprite** của `RichLabel` (`sc/user/Public/RichLabel.lua:550-554`), nằm
  trong lớp C++ `Label`. Trả 0 thì `spriteArray` rỗng và chữ vẫn hiện bình
  thường, nhưng đó là **đoán** một con số của engine — không làm.
* **`IsEnableGradualColor` (10) / `enableGradual` (1)** — **không phải lỗ hổng**:
  `GradualColor` xuất hiện **0 lần** trong toàn bộ `layout_ref/`, tức mọi nhãn
  đều không phải nhãn chuyển màu, và `nil` của ta cho ra **đúng nhánh** mà bản gốc
  đi.


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
   > ra**. Cùng lý do, `check.py` ở đây ghi **24/24** — nay là **27/27**. Giữ
   > nguyên các số cũ vì chúng là bản ghi của từng lượt; muốn đối chiếu ngang thì
   > chạy lại `emu_tags.py` / `emu_join.py` rồi đo bằng thước mới.

3. ~~**Âm thanh**~~ — **xong**, xem mục 6. Mục này để nguyên chữ "chưa có gì"
   lâu hơn thực tế: `game/am_thanh.gd` đã nối `playSoundEffect` /
   `playBackgroundMusic` / `loadEffectBank` vào `AudioStreamPlayer`, `verify_am.gd`
   **88 đạt / 0 hỏng**, và ba việc không khôi phục được của FMOD đã ghi rõ trong mã.
4. **Bỏ mấy chỗ ĐẶT trong trận** — chỗ đứng, tốc độ, hồi thống soái — bằng
   cách đọc tiếp `libgame.so` hoặc đo trong máy ảo.
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
   **27/27**. Dải `264–265` ấy cũng là **thước đo cũ** (chưa nhả khung): cùng
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
8. **`setPercentage`** — 139 lượt gọi, 325 node, 83 file, và là thứ **duy nhất
   trong bảng còn phải đo bằng máy ảo hoặc `libgame.so`**. Đã đo phần chắc chắn
   đo được: bản ghi `CCProgressTimer` **không** chứa midpoint/barChangeRate ở bất
   kỳ offset 4 byte nào (quét cả 325 bản ghi), và bản gốc **không hề gọi**
   `setType`/`setMidpoint`/`setBarChangeRate` (**0 chỗ** trong 973 file) — nên
   kiểu thanh hay vòng, và chiều chạy, là mặc định C++ chưa giải. **Không đoán.**
9. **Nhóm armature còn thiếu** — `sngFixInfoReflash` (27), `_lua_addChildToPlugIn`
   (2 lúc quét, **33 chỗ gọi** trong mã), `_lua_clearPlugIn` (6 lúc quét / 10),
   `_lua_getPlugInPositionInNode` (5). `sngFixInfoReflash` nằm trong danh sách
   thiếu của **cảnh `Main`** từ lâu (CLAUDE.md, mục "(7) còn thiếu ở Main").
10. **`RichLabel` tách từng chữ** — `getLimitShowCount` (48) và `getLetterEx`.
    Nằm trong lớp C++ `Label` của engine (`RichLabel.lua:550-554` tạo bằng
    `Label:new()` rồi `createWithTTF`). Trả một con số đoán ra ở đây là đổi cách
    hiện chữ, nên **để nguyên cho tới khi đọc được binding**.

Việc 2(b) rẻ và mở đường cho việc 4. **Việc 7 vừa xong, và nó đổi thứ tự ưu
tiên**: nó là một lỗi im lặng **trong chính lớp giả lập**, đúng loại đã gặp ở
`setGray` — nên câu hỏi đúng không phải "còn thiếu API nào" mà là "**còn tên nào
được gọi mà chưa từng được viết**". Bảng "API CHUA LAM" của `quet_show.gd` trả lời
được câu đó, và `reorderChild` là ca đầu tiên nó bắt đúng. Sau đó là việc 4 (bỏ
ĐẶT trong trận), rồi việc 8 và việc 10 — hai chỗ duy nhất phải đo bằng máy ảo
hoặc đọc `libgame.so` mới đi tiếp được.
