// Hieu ung sang mot node ve — DUNG chuong trinh shader cua ban goc.
//
// Nguon: libgame.so, chuong trinh so 2. `setGlow(b)` goi
// vfunc_0x158("ShaderPositionTextureColor_Glow") khi bat, va tra ve chuong trinh
// THUONG khi tat. Ten do tra ra chi so 2 trong bang 18 chuong trinh, va chi so 2
// dung nguon manh `.rodata 0x7cccd4` (doc bang
// `brave-cross/work/shaderghep.py --bang` va `--nguon 17`). Ban goc viet:
//
//   varying vec4 v_fragmentColor;
//   varying vec2 v_texCoord;
//   uniform sampler2D CC_Texture0;
//   void main() {
//       float factor = 1.5;
//       vec4 texColor = texture2D(CC_Texture0, v_texCoord);
//       texColor[0] = texColor[0] * factor;
//       texColor[1] = texColor[1] * factor;
//       texColor[2] = texColor[2] * factor;
//       gl_FragColor = v_fragmentColor * texColor;
//   }
//
// Ba dieu rut ra tu chinh doan do — ca ba deu DO duoc bang `tools/do_sang.gd`
// chu khong phai suy tu doc ma:
//
//   * rgb nhan 1,5 (khong phai cong them mot luong sang, cung khong phai doi do
//     mo). Anh thu (60,120,30) ra (90,180,45) — dung 1,50 o ca ba kenh; va kenh
//     nao tran thi bi chan: anh (100,200,50) ra (150,255,75) chu khong phai
//     (150,300,75). Cong thuc ghi ra la 1,5; cho chan 255 la cua dich 8 bit,
//     dung nhu ban goc chay tren GLES that.
//   * alpha KHONG nhan: than ham chi sua ba kenh 0/1/2, con `texColor[3]` giu
//     nguyen — nen do mo cua ANH di thang ra, khong nhan 1,5.
//   * mau node VAN nhan vao: `v_fragmentColor` duoc dung that o day, khac
//     `setGray` (shader do khai bao `v_fragmentColor` roi bo khong dung). Nghia
//     la `setColor` / `setOpacity`, va ca mau thua ke tu node cha, deu con tac
//     dung nhu thuong.
//
// Vi sao than ham duoi day ngan hon nguyen van: trong Godot, `COLOR` dau vao cua
// fragment DA la `anh x modulate` (do duoc o `tools/do_xam.gd` phan A, va do lai
// tren dung hai loai node ma vat lieu nay duoc gan vao — `TextureRect` va
// `NinePatchRect` — o `tools/do_sang.gd` phan A). Nen
// `v_fragmentColor * texture2D(CC_Texture0, ...)` chinh la `COLOR` dau vao, va
// viec con lai chi la nhan ba kenh rgb len 1,5.
//
// Ghi chu ve do chinh xac: ban goc khai `precision lowp float`, Godot khong co
// tuong duong — phep tinh o day la phep tinh LY TUONG hon ban goc chay tren phan
// cung GLES that (co the lech vai don vi cuoi).
shader_type canvas_item;

const float HE_SANG = 1.5;

void fragment() {
	COLOR = vec4(COLOR.rgb * HE_SANG, COLOR.a);
}
