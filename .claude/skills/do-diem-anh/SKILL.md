---
name: do-diem-anh
description: "Đo bằng điểm ảnh cho repo bravecross-game: ghim --fixed-fps 30 ở cả hai lượt, cờ --chup=/--khung= của từng công cụ, cặp --shot=/--at= của autoload Game, cách so hai ảnh bằng tools/lech_anh.py (--giong/--doi/--cat=), cách đếm [KHONG GAN] và đếm màu. Dùng khi câu hỏi là 'màn này trông có đúng không' — thứ check.py headless không trả lời được."
argument-hint: "[chup | so | dem-node | dem-mau]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write
model: sonnet
---

# Đo bằng điểm ảnh

`python tools/check.py` chạy **headless** nên không vẽ gì. Câu hỏi "màn này trông
có đúng không" **chỉ** điểm ảnh trả lời được. Skill này là công thức của repo.

Đọc Phase 5 trước khi tin bất cứ con số nào.

---

## Phase 1 — Luật số một: ghim `--fixed-fps 30` ở CẢ HAI lượt

```
--fixed-fps 30
```

Thiếu nó ở **một trong hai** lượt là pha hoạt ảnh lệch nhau, và phép so trở nên
**vô nghĩa** — không phải "hơi nhiễu", mà là so hai thời điểm khác nhau của cùng
một hoạt ảnh. Ghi ở `README.md:525-527`, `tools/do_vao_game.gd:31-33`, và
`.claude/docs/technical-preferences.md`.

---

## Phase 2 — Chụp

Mọi công cụ chụp ảnh phải chạy **có cửa sổ** (đừng thêm `--headless`).

### Cặp `--chup=` / `--khung=`

| Công cụ | Cờ nhận |
|---|---|
| `tools/do_man_lua.gd` | `--lua=<file.lua>`, `--ra=<txt>`, `--chup=<png>`, `--khung=N` (mặc định **45**) |
| `tools/do_doanh_trai.gd` | `--man=<tên màn>`, `--ra=<txt>`, `--chup=<png>`, `--khung=N` |
| `tools/do_chien_dich.gd` | `--chup=<png>`, `--khung=N`, `--xem`, `--thoat=N`, `--ai=KEY`, `--giu`, `--chieu-mo=N`, `--cam=` |
| `tools/do_vao_game.gd` | `--chup=<png>`, `--theme=`, `--cay=<txt>`, `--an=`, `--tim=`, `--sau=`, `--diem=x,y` — khung **ghim cứng 45** (`KHUNG_CHUP`) |

Lệnh mẫu (lấy từ `CLAUDE.md:618`):

```bash
godot --path . --script tools/do_doanh_trai.gd -- --ra=<dump> --chup=<png> --khung=45
```

### Bấm-rồi-chụp: `--ra=<tiền tố>`

`tools/do_thanh_cong_cu.gd` không nhận `--chup=`. Nó nhận `--ra=<tiền tố>` và tự
ghi **hai** ảnh: `<ra>-thu.png` (lúc đóng) và `<ra>-mo.png` (sau khi bấm). Đây là
khuôn để đo một nút: chụp trước, bấm, chụp sau.

### `--shot=` / `--at=` — không cần công cụ nào

Autoload `Game` tự chụp cho **mọi** màn (`game/game.gd:163-202`):

```bash
godot --path . -- --shot=D:/tmp/main.png            # 6 s sau khi vào Main
godot --path . -- --shot=D:/tmp/main.png --at=20    # bắt hoạt ảnh muộn hơn
```

`--at` tính **từ sau khi chuỗi Login → Main chạy xong**, KHÔNG phải từ lúc mở cửa
sổ (`game/game.gd:168-170`). Đó là chủ ý: nếu tính từ lúc mở cửa sổ thì ảnh chụp
rơi vào lúc màn còn đang mờ dần, và **im lặng** cho ra một tấm ảnh nửa vời.
Lúc chụp nó cũng tắt nhận GUI (`game/game.gd:183`).

---

## Phase 3 — So hai ảnh

```bash
python tools/lech_anh.py a.png b.png [--giong|--doi] [--cat=y0:y1]
```

| cờ | nghĩa |
|---|---|
| `--giong` | đòi **giống hệt**; khác một điểm là **lỗi** (exit 1) |
| `--doi` | đòi **phải khác**; ra 0 điểm khác thì in `PHEP KIEM KHONG CO LUC` và exit 1 |
| `--cat=y0:y1` | cắt dải `y` trước khi so |

Nó in ra: tổng điểm khác · số khác **> 8 mức** · **mức lệch lớn nhất** · và **hộp
bao của vùng khác MẠNH**. Hộp bao lấy trên vùng khác mạnh chứ không phải vùng lệch
1 mức — vùng lệch 1 mức thường trùm cả khung và không chỉ được gì
(`tools/lech_anh.py:69-73`).

Ngưỡng `NGUONG_KE = 8` = 1/32 của 0..255: lệch ≤ 8 coi là **nhiễu làm tròn của
trình vẽ**, thường chỉ 1-2 mức (`tools/lech_anh.py:18-20`).

Công thức đầy đủ, có lượt đối chứng ngược (`README.md:519-540`):

```bash
godot --path . --fixed-fps 30 --script tools/vao_main.gd -- --chup=D:/tmp/a.png
godot --path . --fixed-fps 30 tools/do_vao_game.tscn -- --chup=D:/tmp/b.png
godot --path . --fixed-fps 30 tools/do_vao_game.tscn -- --chup=D:/tmp/c.png --theme=san
python tools/lech_anh.py D:/tmp/a.png D:/tmp/b.png --cat=150:640 --giong
python tools/lech_anh.py D:/tmp/b.png D:/tmp/c.png --cat=150:640 --doi
```

`--cat=150:640` ở đây là **bỏ một dải nhiễu** (hạt trời `UITongYong`), KHÔNG phải
để tô hồng con số — `tools/do_vao_game.gd:20-24` nói rõ như vậy. Cắt ở đâu thì
phải nói được vì sao.

---

## Phase 4 — Hai phép đếm khác

### Đếm `[KHONG GAN]` — node có ảnh nhưng ảnh bị bỏ im lặng

Node có thể mang meta `img` mà ảnh **không hề được gắn**. Chỉ đếm theo
`img_applied` mới lộ ra. `tools/do_man_lua.gd:123` và `tools/do_doanh_trai.gd:163`
in đúng biểu thức này:

```gdscript
" [da gan]" if n.get_meta("img_applied", false) else " [KHONG GAN]"
```

Nghĩa là: `--ra=<dump.txt>` rồi `grep -c '\[KHONG GAN\]'` trên dump. Đây là phép
đếm **theo số lượng**, không theo thuộc tính — xem `CLAUDE.md:610-618`.

### Đếm màu

**Repo chưa có script cho việc này.** PIL có sẵn (`tools/lech_anh.py:15` dùng
`from PIL import Image, ImageChops`), nên:

```bash
python -c "from PIL import Image; im=Image.open('a.png').convert('RGB'); c=im.getcolors(maxcolors=1<<24); print(len(c), sorted(c, reverse=True)[:5])"
```

Hai số đã đo để so (`ROADMAP.md:3815-3817`): màn scaffold `ui/menu.tscn` chỉ
**846 màu** với màu trội `(26,27,30)` — dấu hiệu của "nền phẳng, không art"; màn
Main thật **66.657 màu**. Đếm màu là cách rẻ nhất để phân biệt "màn có art" với
"màn chữ trắng trên nền trơn".

---

## Phase 5 — Đọc kết quả cho đúng

Hai cái bẫy đã ghi ngay trong đầu `tools/lech_anh.py:7-12`:

1. **Khác biệt về THUỘC TÍNH có thể đổi 0 điểm ảnh.** Theme, thứ tự layer, có sân
   khấu hay không — sửa xong mà ảnh giống hệt thì phép đo **không** chứng minh được
   gì. Đó là lý do phải làm lượt `--doi` đối chứng ngược.
2. **Đổi một điểm ảnh có thể do PHA HOẠT ẢNH** chứ không do cái vừa sửa.

**Nên:** luôn đọc hộp bao và mức lệch lớn nhất, không đọc mỗi một con số. Lệch còn
lại phải quy được về **một nguyên nhân gọi tên được** (pha hoạt ảnh, rig trong cây,
âm thanh hoãn sang khung đầu) trước khi đổi gì tiếp.

**Phép kiểm chứng ngược phải KHÁC 0.** Nếu lượt `--doi` mà cũng ra 0 thì phép kiểm
**không có lực** — nói thẳng ra, đừng gọi là thành công.

Và nhớ Phase 5 của skill `chay-game`: đọc trạng thái **ngay sau `chay()`** là đọc
một khung **đóng băng** (hoạt cảnh mở khoá nút bị TREO). Muốn chụp đúng thì phải
nhả khung trước.

---

## Phase 6 — Ghi tệp và bàn giao

Skill này có `Write` trong `allowed-tools`, nên **hỏi trước mọi lần ghi**: "May I
write this to [đường dẫn]?" — kể cả tệp nháp Lua/Python. Đường dẫn nháp nên nằm
ngoài repo (`C:/tmp/…`) để không làm bẩn `git status`.

Kết luận một lượt đo bằng đúng một trong: **PASS** (0 điểm khác ở lượt `--giong`,
và lượt `--doi` khác 0) · **FAIL** (có điểm khác, kèm hộp bao và mức lệch lớn nhất)
· **BLOCKED** (chưa chạy có cửa sổ, hoặc thiếu `--fixed-fps 30` ở một lượt).

**Bước kế:**

* Không biết lệnh Godot nào để chạy → skill `chay-game`.
* Cần biết màn hình có node gì trước khi đo → `--chup=` kèm `--ra=<dump>` để có cả
  ảnh lẫn cây node.
* Sửa xong mã → `python tools/check.py` (57 dòng phải xanh) rồi mới `/skill-test static do-diem-anh`.
