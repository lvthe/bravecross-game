---
name: chay-game
description: "Cách chạy game và bộ kiểm của repo bravecross-game: tìm đúng file Godot 4.7.2 (không có trên PATH), khi nào dùng --headless khi nào phải có cửa sổ, chạy `python tools/check.py` và đọc 57 dòng kết quả, cùng sáu cái bẫy đo sai đã trả giá. Dùng trước khi chạy bất cứ lệnh Godot nào trong repo này."
argument-hint: "[bo-kiem | mot-bo | tim-godot]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
model: sonnet
---

# Chạy game

Mọi thứ dưới đây là **số đo của repo này**, không phải hướng dẫn chung của Godot.
Đọc hết phần bẫy (Phase 5) trước khi tin một con số vừa đo được.

---

## Phase 1 — Tìm Godot

**Godot KHÔNG có trên PATH.** `tools/check.py:276-314` đi tìm theo thứ tự:

| # | Chỗ tìm |
|---|---------|
| 1 | `godot` trên PATH |
| 2 | `godot_console` trên PATH |
| 3 | `%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe` |
| 4 | quét `%LOCALAPPDATA%\Microsoft\WinGet\Packages` — thư mục có chữ `Godot`, file `Godot_v*.exe` |
| 5 | biến môi trường `GODOT`, rồi `GODOT4` |
| 6 | không thấy → `None` |

Ở bước 4 nó sắp **hai lần** (`check.py:306-307`): bản **mới nhất** thắng trước, rồi
trong cùng bản thì `_console` thắng — vì trên Windows chỉ bản `_console` mới chắc
chắn đẩy stdout về cho tiến trình gọi.

Trên máy này (`CLAUDE.md:92-93`), đường dẫn thật là:

```
C:\Users\lvthe\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe
```

**Vì sao phải biết:** `winget` cài **không có quyền admin** in ra "Successfully
installed" nhưng **không tạo** symlink trong `WinGet\Links`. Nên `godot` trên PATH
là chuyện may rủi — đừng kết luận "máy chưa cài Godot" chỉ vì `which godot` trắng.

---

## Phase 2 — `--headless` hay có cửa sổ

Đây là chỗ sai tốn thời gian nhất, vì cả hai kiểu đều **chạy và thoát sạch** —
chỉ khác là kiểu sai **không vẽ gì** nên mọi phép đo điểm ảnh ra 0.

| Việc | Cờ | Vì sao |
|---|---|---|
| `tools/check.py` và mọi bộ `verify_*.gd` | **`--headless`** | không cần vẽ; chạy nhanh |
| Mọi thứ **chụp ảnh** (`--chup=`, `--shot=`) | **KHÔNG** `--headless` | headless không vẽ (`tools/do_tron.gd:1-10`) |
| Nhập dự án lần đầu | `--headless --import` | `check.py:442-447` tự chạy trước mọi bộ Godot |

Ba công cụ ghi rõ trong đầu tệp rằng **phải** chạy có cửa sổ:
`tools/do_man_lua.gd:5`, `tools/do_thanh_cong_cu.gd:7-8`, `tools/do_chien_dich.gd:6-10`.

---

## Phase 3 — Chạy trọn bộ kiểm

```bash
python tools/check.py
```

**Phải ra 57 dòng kết quả** (52 bộ trong `SUITES` + 5 bộ Python) và dòng cuối
`Tat ca xanh.` Cờ duy nhất nó nhận là `--url` (mặc định `http://127.0.0.1:7350`).

Đếm đúng:

```bash
grep -cE '[0-9]+ dat, [0-9]+ hong|  dat$' <tệp kết quả>
```

**Đừng đếm bằng `dat N, hong M`** — dòng `check.py` **in ra** đặt số **trước**
chữ `dat` (`31 dat, 0 hong`), còn `SCORE` (`check.py:285`) là mẫu cho **đầu ra thô**
của bộ kiểm. Đếm theo `dat N` ra **0**; đếm theo `N dat, M hong` ra **thiếu đúng
một dòng** vì bộ `thien vi san` không in số — và trông y như một bộ không chạy.

Hai điều dễ đọc sai:

* **Dòng `thien vi san   dat`** (thiếu hẳn phần số) **không phải lỗi**. `check.py:376-377`
  trả `'dat'` khi bộ kiểm in ra `san khong thien vi` — đó là phép kiểm **đúng/sai**,
  không đếm. Đừng đi truy một hồi quy không tồn tại.
* **`BO QUA` khác `HONG`.** Bộ cần máy chủ Nakama thật sẽ báo `BO QUA (can may chu)`
  khi máy chủ chưa bật — đó là thiết kế (`check.py:7-8`), không phải bộ hỏng.

---

## Phase 4 — Chạy một bộ lẻ

Hai hình dạng argv (`check.py:341-348`):

```bash
# kind = script
<godot> --headless --path <ROOT> --script tools/verify_x.gd -- [extra…]

# kind = scene  (cần autoload / theme trên root)
<godot> --headless --path <ROOT> tools/verify_x.tscn -- [extra…]
```

Mọi thứ **sau `--`** là cờ của bộ kiểm (`OS.get_cmdline_user_args()`), không phải
của Godot. `<ROOT>` là gốc repo — `check.py:15-16`, và chính là thứ được truyền
vào `--path`.

Các bộ `scene` hiện có: `tools/verify_equip.tscn`, `tools/verify_tasks.tscn`,
`battle/battle.tscn` (hai lần, với `--sim=300 --mirror` và `--replaycheck`),
`tools/verify_man_tran.tscn`, `tools/verify_vao_game.tscn`.

---

## Phase 5 — Sáu cái bẫy đã trả giá

Đọc trước khi tin bất cứ con số nào vừa đo.

### 1. Khung hình ĐÓNG BĂNG ngay sau khi vào Main

Chuỗi Login → Main **dừng ngay khi Main lên sân khấu**. Nhưng cửa sổ mở khoá nút
chức năng là một **hoạt cảnh TREO**: `CUIMain.lua:251` xếp
`S_CCSequence(DelayTime(0), CCCallFunc(postOnMainShowBeginEvent))` trên `g_MainUIScene`,
và chỉ `postOnMainShowBeginEvent` mới POST `OnDialogShowBegin`.

Nên đọc trạng thái **ngay sau `chay()`** là đọc một khung đóng băng. Số đo thật
(`tools/verify_nut_chien_dich.gd:25-28`):

| đọc lúc | nhãn khoá 5000 | `_getBuildingStatus` | bấm |
|---|---|---|---|
| ngay sau `chay()` | `hien = true` | `1` (đóng) | không mở gì |
| sau khi **nhả 5 khung** | `false` | `2` (mở) | mở màn thật |

**Cách nhả khung: gọi `lua.tick()` từ GDScript, KHÔNG `C.tick` từ trong Lua**
(`tools/verify_nut_chien_dich.gd:185-188`):

```gdscript
func _nha(so: int) -> void:
	for i in so:
		_lua.tick(1.0 / 30.0)
```

`CHO := 30` khung là đủ cho hoạt cảnh `DelayTime(0)` và cho `CGameFuncOpeningManager`.

### 2. `_G.C` là BÓNG

`lua/bootstrap.lua` thay **mọi** biến toàn cục không tồn tại bằng một bảng ma
(`make_ghost`). Nên `C.tick` **im lặng không làm gì** — không lỗi, không cảnh báo.

Module thật tới bằng **THAM SỐ**: `lua/actions.lua` kết thúc `return function(C) … end`.
Lấy cocos thật qua `package.loaded['cocos']`.

Đây chính là lý do phải nhả khung bằng `lua.tick()` từ GDScript — vòng lặp viết
trong Lua sẽ quay vô ích.

### 3. `onVisible` của mọi màn cũng bị hoãn

`CUIManager` chỉ gọi `onVisible()` từ `OnShowAnimationFinish`, mà cái đó lại xếp
qua `S_CCSequence(S_CCDelayTime, S_CCCallFunc)` trên `rootUI`
(`CUIDialogAnimation.lua:86-95`).

Số đo (`tools/quet_show.gd:118-131`): `CUIQuest` không nhả khung → `hoi=71 hut=0,
IsUiVisible=false`; nhả `30 × 0.05 s` → `hoi=819 hut=35, IsUiVisible=true`.

Bẫy này từng làm bộ quét báo "mở được **246 → 292** màn" trong khi **không màn nào
mới mở** (`README.md:558-566`) — con số chỉ đổi vì đã nhả khung.

### 4. `await process_frame` trong `_init` là TREO

Dưới `--script`, `SceneTree.root` **chưa tồn tại** lúc `_init`. `await
get_tree().process_frame` ở đó treo im lặng — đo được: hết **120 s** không in gì.

Vòng lặp khung **phải** nằm trong `_process` (`tools/do_tieng.gd:20-21`,
`tools/do_nhieu.gd:15-16`, `tools/do_co_gian.gd:55`).

### 5. Đổi màn cũng bị hoãn

`CSceneManager` nhường qua `S_CCSchedule:scheduleOnce(...)`, nên vào lại một màn
phải hoãn sang **khung kế tiếp** (kể cả `loadLevelFileAsync`). Gọi ngay thì Lua báo
`cannot resume non-suspended coroutine` (`README.md:818-823`).

### 6. Hàm Lua trả HAI giá trị — đọc nhầm ô thì ra `true`

`G_UserLogic:GetLevel()` **không** trả một con số. Chuỗi của nó:
`UserLogic:GetLevel()` (`sc/share/UserLogic.lua:748`) →
`UserLogicDataManager:GetLevel()` (`:269`) → `GetValue("Level")` (`:473`), mà
`GetValue` trả **`(bResult, oResult)`**.

Nên `local n = G_UserLogic:GetLevel()` cho ra **`true`**, không phải `1`. Nó trông
y hệt "gọi được nhưng giá trị lạ", và tôi đã có lúc in ra `cap do: true -> true`
rồi suýt kết luận cấp người chơi là `true`. Đọc đúng:

```lua
local b, n = G_UserLogic:GetLevel()      -- hoặc
local n = select(2, G_UserLogic:GetLevel())
```

**Cách tra nhanh:** mã gốc là chỗ trả lời. `CUIActivityMode.lua:1433` và `:1579`
đều viết `local bRetCode, nUserLevel = G_UserLogic:GetLevel()` rồi
`KDebug.ProcessError(bRetCode)`. Thấy một hàm được gọi cùng `KDebug.ProcessError`
thì nó trả nhiều giá trị — mở `sc/` xem chỗ gọi, đừng đoán theo tên hàm.

---

## Phase 6 — Ghi tệp và bàn giao

Skill này **chỉ đọc và chạy**; `allowed-tools` không có `Write`/`Edit`. Nếu một
phép đo cần tệp nháp (ví dụ một đoạn Lua để `--lua=`) hoặc cần sửa mã, **hỏi trước
khi ghi**: "May I write this to [đường dẫn]?" — kèm bản nháp và con số sẽ đo.

Kết luận một lượt chạy bằng đúng một trong: **PASS** (bộ kiểm xanh, số đo khớp) ·
**FAIL** (có hồi quy, kèm `dat N, hong M` trước/sau) · **BLOCKED** (thiếu máy chủ
Nakama, thiếu `assets_ref/`, hoặc thiếu Godot).

**Bước kế:**

* Cần đo bằng **điểm ảnh** → dùng skill `do-diem-anh` (đừng tự nghĩ lại công thức).
* Cần biết một màn hình có gì → `godot --path . --script tools/do_man_lua.gd -- --lua=<nháp> --ra=<dump.txt> --chup=<png> --khung=45`.
* Sửa xong mã → `/skill-test static chay-game` để kiểm cấu trúc skill này.
