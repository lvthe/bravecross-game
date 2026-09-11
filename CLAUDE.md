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
python tools/check.py          # 19 bộ, phải xanh hết
```

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

Xem README mục "Chạy thẳng mã Lua của bản gốc" → "Việc tiếp theo, theo thứ tự".
Tóm tắt: (1) nối chạm, (2) dựng cảnh `Main`, (3) trạng thái người chơi mới.

Hiện **chưa bấm được gì** — mọi màn là ảnh tĩnh. 244/353 màn mở được; 82 màn
hỏng vì thiếu dữ liệu người chơi, không phải thiếu engine.
