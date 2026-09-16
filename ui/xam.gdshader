// To xam mot node ve — DUNG shader cua ban goc, khong phai mot cong thuc tu nghi ra.
//
// Nguon: libgame.so, chuong trinh so 1. `setGray(b)` goi
// vfunc_0x158("ShaderPositionTextureColor_Gray"); ten do tra ra chi so 1 trong
// bang 18 chuong trinh, va chi so 1 dung nguon manh `.rodata 0x7ccf00`
// (doc bang `brave-cross/work/shaderghep.py --bang`). Ban goc viet:
//
//   uniform sampler2D CC_Texture0;
//   void main() {
//       float alpha = texture2D(CC_Texture0, v_texCoord).a;
//       float grey  = dot(texture2D(CC_Texture0, v_texCoord).rgb,
//                         vec3(0.299, 0.587, 0.114));
//       gl_FragColor = vec4(grey, grey, grey, alpha);
//   }
//
// Bon dieu dang chu y — ca bon deu DO duoc bang `tools/do_xam.gd` (11/11 dat),
// khong phai suy tu doc ma:
//
//   * He so la Rec.601 (0.299 / 0.587 / 0.114), KHONG phai Rec.709. Anh thu
//     (100,200,50) cho Rec.601 ra 153 va Rec.709 ra 168; do ra dung 0,6000 va
//     cach 0,6585 mot khoang 0,0585 (gap bon lan sai so cho phep).
//   * `v_fragmentColor` duoc khai bao nhung KHONG dung o dau trong than ham.
//     Nghia la mau node va do mo cua node BI BO khi to xam. Godot lam y het
//     neu ghi de `COLOR`: `COLOR` dau vao la `anh x modulate`, va ket qua ghi
//     ra khong bi nhan them lan nao nua — do duoc (A1..A3), chu khong phai
//     muon la duoc. Nho vay shader nay bo thang vao, khong phai bu tru gi.
//   * Mau THUA KE tu node cha cung bi bo: nguon dinh N[8] (`.rodata 0x7ca769`)
//     chi co `v_fragmentColor = a_color`, ma trong cocos2d-x `a_color` la mau
//     HIEN THI cua node — da gom san mau/do mo cua cha (`_displayedColor`).
//     Do tren Godot: cha modulate 0,5 -> con van ra 0,6000 chu khong 0,3000.
//   * Alpha lay tu ANH (`texture2D(...).a`), khong tu node — nen setOpacity
//     khong lam mo anh xam.
//
// Ghi chu ve do chinh xac: ban goc khai `precision lowp float`, Godot khong co
// tuong duong. Nen phep tinh o day la phep tinh LY TUONG hon ban goc chay tren
// phan cung GLES that (co the lech vai don vi cuoi). Ban dung lai bam theo ly
// thuyet cua chinh cong thuc do.
shader_type canvas_item;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float grey = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(grey, grey, grey, t.a);
}
