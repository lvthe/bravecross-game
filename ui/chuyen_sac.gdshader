// Chuyen sac chu cua mot nhan — DUNG chuong trinh shader cua ban goc.
//
// Nguon: libgame.so, chuong trinh so 8, ten `ShaderLabel_Gradual`, nguon manh
// `.rodata 0x7cbcac`, 909 byte (doc bang `brave-cross/work/shaderghep.py --bang`
// va `--nguon 11`). Ban goc viet nguyen van:
//
//   varying vec4 v_fragmentColor;
//   varying vec2 v_texCoord;
//   uniform sampler2D CC_Texture0;
//   uniform vec4 v_textColor;
//   uniform vec2 v_coordYRange;
//   uniform vec4 v_colorBegin;
//   uniform vec4 v_colorEnd;
//   void main() {
//       vec4 resultColor;
//       vec4 texColor = texture2D(CC_Texture0, v_texCoord);
//       float a = abs(v_texCoord.y - v_coordYRange.x) / abs(v_coordYRange.y - v_coordYRange.x);
//       float b = abs(1.0 - a);
//       resultColor.r = v_colorBegin.r*a + v_colorEnd.r*b;
//       resultColor.g = v_colorBegin.g*a + v_colorEnd.g*b;
//       resultColor.b = v_colorBegin.b*a + v_colorEnd.b*b;
//       resultColor.a = texColor.a;
//       gl_FragColor = v_fragmentColor*resultColor;
//   }
//
// Bon dieu rut ra tu chinh doan do, ca bon deu DO duoc chu khong suy tu doc ma:
//
//   * `a` chay tu 0 den 1 theo chieu DOC cua o, va `b = 1 - a` nen day la phep
//     TRON hai mau: `a = 0` ra `v_colorEnd`, `a = 1` ra `v_colorBegin`. Vi tri
//     lay tu `v_coordYRange`, ma cho nap no do duoc o `0x4f708a..0x4f70d4`:
//     `glUniform2f(prog, this[+0x3a4], quad+0x14, quad+0x5c)` — hai o do dung
//     la `tl.texCoords.v` va `br.texCoords.v` cua `V3F_C4B_T2F_Quad`
//     (`tl` o +0x14, `br` = 3*24+0x14 = +0x5c). Nhan `Label` ve ca khuon anh cua
//     no nen hai so do la 0 va 1.
//   * Nhu vay: `a = 0` o DAU o, `a = 1` o CUOI o (v cua Cocos tang xuong duoi).
//     Tuc **tren = bo ba THU HAI (`v_colorEnd`), duoi = bo ba THU NHAT
//     (`v_colorBegin`)** — day la cho de lam nguoc nhat, va no khong phai phep
//     suy dien: `v_colorBegin` / `v_colorEnd` duoc gan ten o ngay trong than ham
//     `enableGradual` (0x4f7ff0: `glGetUniformLocation` bon lan roi `memcpy` 16
//     byte, doi so 1 vao `+0x380` = colorBegin, doi so 2 vao `+0x390` =
//     colorEnd).
//   * `texColor.rgb` KHONG duoc dung: ba kenh rgb cua ket qua chi den tu dai
//     chuyen sac. Chu trong anh cua ban goc la anh ALPHA (rgb trang), nen bo no
//     la dung — va Godot cung vay: `tools/do_sang.gd` do duoc rgb cua atlas chu
//     la trang ben trong net chu.
//   * `resultColor.a = texColor.a` roi `v_fragmentColor` nhan CA HAI: do phu
//     cua net chu di thang ra (khong bi doi), con mau node thi nhan vao `rgb`
//     lan `alpha` — nen `setColor` / `setOpacity` van tac dung y nhu thuong.
//
// Vi sao than ham duoi day ngan hon nguyen van, va vi sao lai co `vertex()`:
// trong Godot 4.7 `MODULATE` KHONG phai bien dung san cua `canvas_item` (do
// duoc: "SHADER ERROR: Unknown identifier in expression: 'MODULATE'" — o ca
// `fragment()` lan `vertex()`), con `COLOR_TEXTURE` cung khong. Nhung:
//
//   * `COLOR.rgb` trong `vertex()` DUNG BANG `modulate` cua node (do duoc bang
//     trinh ve that: modulate 0,5 -> 0,5020 — sai so la phep luong tu 8 bit),
//     nen `v_mau_node` chinh la `v_fragmentColor.rgb`;
//   * `COLOR.a` dau vao cua `fragment()` DA la `do phu net chu x modulate.a`
//     (do duoc: modulate.a = 0,5 tren nen den ra dung mot nua), tuc chinh
//     `v_fragmentColor.a * texColor.a`.
//
// Nen `COLOR = vec4(mau * v_mau_node, COLOR.a)` la dung bang
// `v_fragmentColor * resultColor` cua ban goc.
//
// `chieu_cao` la mau so cho vi tri DOC TRONG O NODE — thay cho
// `|v_coordYRange.y - v_coordYRange.x|` cua ban goc. Ban goc khong bao gio chia
// cho 0 (o cua nhan luon co chieu cao that), nhung o day gia tri do la mot tham
// so nap tu ngoai nen co the cu di sau khi nhan doi o; `clamp` chi de sai so luc
// do la mot mau PHANG chu khong phai mau ngoai dai (ban goc khong the ra ngoai
// [0,1] vi v nam trong chinh khuon anh cua no).
//
// `v_y_cuc_bo` — VI SAO PHAI DI QUA `vertex()`: trong Godot 4.7, `VERTEX` doc
// trong `fragment()` KHONG phai toa do cua node ma la toa do THE GIOI (khung ve
// cua canvas). Do duoc bang `tools/do_chuyen_sac.gd`: nhan cao 55 diem anh dat o
// y = 8, net chu nam o hang 22..47 cua khung, va kenh do ra dung
// `y_khung / 55` (lech <= 0,008 tren ca 26 hang) chu khong phai
// `(y_khung - 8) / 55` — tuc phep chia da an ca vi tri cua node. Ban goc lay vi
// tri tu `v_texCoord`, la toa do TRONG KHUON ANH cua chinh sprite, nen o day
// phai lay `VERTEX.y` luc con o khong gian cuc bo, tuc trong `vertex()`.
// Do la loi IM LANG: dai van ra, chi la ra lech theo cho node dung.
shader_type canvas_item;

uniform float chieu_cao = 1.0;
uniform vec4 mau_dau = vec4(1.0);
uniform vec4 mau_cuoi = vec4(1.0);

varying vec3 v_mau_node;
varying float v_y_cuc_bo;

void vertex() {
	v_mau_node = COLOR.rgb;
	v_y_cuc_bo = VERTEX.y;
}

void fragment() {
	float a = clamp(v_y_cuc_bo / max(chieu_cao, 0.0001), 0.0, 1.0);
	vec3 mau = mix(mau_cuoi.rgb, mau_dau.rgb, a);
	COLOR = vec4(mau * v_mau_node, COLOR.a);
}
