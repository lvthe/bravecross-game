# bravecross-game

Project Godot 4.7 để làm game mới, dùng lại **bộ xương và hoạt ảnh** đã giải
được từ bản gốc (xem repo `brave-cross`).

Phần đã xong ở đây là **bộ nạp nhân vật**: đọc thẳng dữ liệu do
`work/export.py` xuất ra và dựng thành cây `Node2D` + `AnimationPlayer` chạy
được ngay — không phải dựng tay 397 scene.

## Chạy thử

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

## Bản quyền

`assets_ref/` là art lấy từ bản gốc, **có bản quyền**. Nó bị `.gitignore` và
chỉ dùng làm placeholder trong lúc dev. Phải thay hết bằng art tự làm trước
khi phát hành. Tạo lại bằng:

```bash
python work/export.py --all --out <thư mục>
```

rồi chép các thư mục nhân vật cần dùng vào `assets_ref/`.
