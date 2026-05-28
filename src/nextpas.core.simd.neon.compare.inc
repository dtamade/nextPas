// === Comparison Operations (with mask extraction) ===

function NEONCmpEqF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  fcmeq v0.4s, v0.4s, v1.4s

  // Extract sign bits to build 4-bit mask
  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

function NEONCmpLtF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  // a < b  <=>  b > a
  fcmgt v0.4s, v1.4s, v0.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

function NEONCmpLeF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  // a <= b  <=>  b >= a
  fcmge v0.4s, v1.4s, v0.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

function NEONCmpGtF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  fcmgt v0.4s, v0.4s, v1.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

function NEONCmpGeF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  fcmge v0.4s, v0.4s, v1.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

function NEONCmpNeF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  fcmeq v0.4s, v0.4s, v1.4s
  mvn   v0.16b, v0.16b

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// === Saturating Arithmetic Operations (NEON) ===
// NEON 使用 sqadd/sqsub (有符号) 和 uqadd/uqsub (无符号) 指令

// I8x16 有符号饱和加法 (sqadd v.16b)
function NEONI8x16SatAdd(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  // ABI: a in x0..x1, b in x2..x3, return in x0..x1
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sqadd v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I8x16 有符号饱和减法 (sqsub v.16b)
function NEONI8x16SatSub(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sqsub v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 有符号饱和加法 (sqadd v.8h)
function NEONI16x8SatAdd(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sqadd v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 有符号饱和减法 (sqsub v.8h)
function NEONI16x8SatSub(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sqsub v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U8x16 无符号饱和加法 (uqadd v.16b)
function NEONU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  uqadd v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U8x16 无符号饱和减法 (uqsub v.16b)
function NEONU8x16SatSub(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  uqsub v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 无符号饱和加法 (uqadd v.8h)
function NEONU16x8SatAdd(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  uqadd v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 无符号饱和减法 (uqsub v.8h)
function NEONU16x8SatSub(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  uqsub v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === Narrow Integer Types (I16x8, I8x16, U16x8, U8x16) ===
// NEON 使用 add/sub/mul v.8h/.16b 和 smin/smax/umin/umax 指令

// --- I16x8 Operations (8×Int16) ---

// I16x8 加法 (add v.8h)
function NEONAddI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  add   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 减法 (sub v.8h)
function NEONSubI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 乘法 (mul v.8h)
function NEONMulI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  mul   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 位与 (and v.16b)
function NEONAndI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 位或 (orr v.16b)
function NEONOrI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 位异或 (eor v.16b)
function NEONXorI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 位非 (mvn v.16b)
function NEONNotI16x8(const a: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 与非 (bic v.16b = a AND NOT b)
function NEONAndNotI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  bic   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 有符号最小值 (smin v.8h)
function NEONMinI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  smin  v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I16x8 有符号最大值 (smax v.8h)
function NEONMaxI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  smax  v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// --- I8x16 Operations (16×Int8) ---

// I8x16 加法 (add v.16b)
function NEONAddI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  add   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I8x16 减法 (sub v.16b)
function NEONSubI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I8x16 位与 (and v.16b)
function NEONAndI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I8x16 位或 (orr v.16b)
function NEONOrI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I8x16 位异或 (eor v.16b)
function NEONXorI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I8x16 位非 (mvn v.16b)
function NEONNotI8x16(const a: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONAndNotI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := NEONAndI8x16(NEONNotI8x16(a), b);
end;

// I8x16 有符号最小值 (smin v.16b)
function NEONMinI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  smin  v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I8x16 有符号最大值 (smax v.16b)
function NEONMaxI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  smax  v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// --- U16x8 Operations (8×UInt16) ---

// U16x8 加法 (add v.8h) - 与 I16x8 相同
function NEONAddU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  add   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 减法 (sub v.8h)
function NEONSubU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 乘法 (mul v.8h)
function NEONMulU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  mul   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 位与 (and v.16b)
function NEONAndU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 位或 (orr v.16b)
function NEONOrU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 位异或 (eor v.16b)
function NEONXorU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 位非 (mvn v.16b)
function NEONNotU16x8(const a: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONAndNotU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := NEONAndU16x8(NEONNotU16x8(a), b);
end;

// U16x8 无符号最小值 (umin v.8h)
function NEONMinU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  umin  v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U16x8 无符号最大值 (umax v.8h)
function NEONMaxU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  umax  v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// --- U8x16 Operations (16×UInt8) ---

// U8x16 加法 (add v.16b)
function NEONAddU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  add   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U8x16 减法 (sub v.16b)
function NEONSubU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U8x16 位与 (and v.16b)
function NEONAndU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U8x16 位或 (orr v.16b)
function NEONOrU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U8x16 位异或 (eor v.16b)
function NEONXorU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U8x16 位非 (mvn v.16b)
function NEONNotU8x16(const a: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONAndNotU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := NEONAndU8x16(NEONNotU8x16(a), b);
end;

// U8x16 无符号最小值 (umin v.16b)
function NEONMinU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  umin  v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U8x16 无符号最大值 (umax v.16b)
function NEONMaxU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  umax  v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === U32x4/U32x8/U64x4 Operations (NEON ASM) ===
// 无符号整数操作从 Scalar 回调转换为真正的 NEON ASM

// --- U32x4 Operations (4×UInt32) ---

// U32x4 加法 (add v.4s)
function NEONAddU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  add   v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U32x4 减法 (sub v.4s)
function NEONSubU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U32x4 位与 (and v.16b)
function NEONAndU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U32x4 位或 (orr v.16b)
function NEONOrU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U32x4 位异或 (eor v.16b)
function NEONXorU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U32x4 位非 (mvn v.16b)
function NEONNotU32x4(const a: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U32x4 位与非 (bic v.16b - bitwise clear)
function NEONAndNotU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  bic   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U32x4 无符号最小值 (umin v.4s)
function NEONMinU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  umin  v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// U32x4 无符号最大值 (umax v.4s)
function NEONMaxU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  umax  v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// --- U32x8 Operations (8×UInt32, 2×128-bit) ---
//
// ABI note (AArch64/FPC as exercised by the current NEON native evidence):
// - TVecU32x8 is lowered here as four 64-bit chunks by value:
//   a.lo -> x0..x1, b.lo -> x2..x3, a.hi -> x4..x5, b.hi -> x6..x7.
// - The 256-bit result is returned as two packed 128-bit halves split across
//   x0..x1 (lo) and x2..x3 (hi).
// Keep the load/compute/store order symmetric; "simplifying" this to the
// hidden-result-pointer shape used by some signed wide records would silently
// break lane order/return shape for this family.

// U32x8 加法 (2×add v.4s)
function NEONAddU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  // Load a.lo (x0..x1) into v0
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  // Load b.lo (x2..x3) into v1
  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  // Add lo: v0 = a.lo + b.lo
  add   v0.4s, v0.4s, v1.4s

  // Load a.hi (x4..x5) into v2
  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  // Load b.hi (x6..x7) into v3
  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  // Add hi: v2 = a.hi + b.hi
  add   v2.4s, v2.4s, v3.4s

  // Return: lo in x0..x1, hi in x2..x3
  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U32x8 减法 (2×sub v.4s)
function NEONSubU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.4s, v0.4s, v1.4s

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  sub   v2.4s, v2.4s, v3.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U32x8 位与 (2×and v.16b)
function NEONAndU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  and   v2.16b, v2.16b, v3.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U32x8 位或 (2×orr v.16b)
function NEONOrU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  orr   v2.16b, v2.16b, v3.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U32x8 位异或 (2×eor v.16b)
function NEONXorU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  eor   v2.16b, v2.16b, v3.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U32x8 位非 (2×mvn v.16b)
function NEONNotU32x8(const a: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  fmov  d2, x2
  fmov  d4, x3
  ins   v2.d[1], v4.d[0]

  mvn   v2.16b, v2.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U32x8 位与非 (2×bic v.16b)
function NEONAndNotU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  bic   v0.16b, v0.16b, v1.16b

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  bic   v2.16b, v2.16b, v3.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U32x8 无符号最小值 (2×umin v.4s)
function NEONMinU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  umin  v0.4s, v0.4s, v1.4s

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  umin  v2.4s, v2.4s, v3.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U32x8 无符号最大值 (2×umax v.4s)
function NEONMaxU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  umax  v0.4s, v0.4s, v1.4s

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  umax  v2.4s, v2.4s, v3.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// --- U64x4 Operations (4×UInt64, 2×128-bit) ---
//
// ABI note: this family follows the same by-value split-return pattern as
// U32x8 above, but each 128-bit half contains 2×UInt64 lanes (v?.2d).
// The first half is packed/unpacked through x0..x3, the second half through
// x4..x7 on input, and the result comes back in x0..x3. Preserve that half
// pairing exactly; the current dataplane/direct-dispatch probes depend on it.

// U64x4 加法 (2×add v.2d)
function NEONAddU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  add   v0.2d, v0.2d, v1.2d

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  add   v2.2d, v2.2d, v3.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U64x4 减法 (2×sub v.2d)
function NEONSubU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.2d, v0.2d, v1.2d

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  sub   v2.2d, v2.2d, v3.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U64x4 位与 (2×and v.16b)
function NEONAndU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  and   v2.16b, v2.16b, v3.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U64x4 位或 (2×orr v.16b)
function NEONOrU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  orr   v2.16b, v2.16b, v3.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U64x4 位异或 (2×eor v.16b)
function NEONXorU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  fmov  d2, x4
  fmov  d4, x5
  ins   v2.d[1], v4.d[0]

  fmov  d3, x6
  fmov  d4, x7
  ins   v3.d[1], v4.d[0]

  eor   v2.16b, v2.16b, v3.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// U64x4 位非 (2×mvn v.16b)
function NEONNotU64x4(const a: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  fmov  d2, x2
  fmov  d4, x3
  ins   v2.d[1], v4.d[0]

  mvn   v2.16b, v2.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v2.d[0]
  umov  x3, v2.d[1]
end;

// === I64x2 Arithmetic, Bitwise, and Comparison Operations (NEON) ===
// NEON 使用 add/sub v.2d 和 and/orr/eor v.16b 指令

// I64x2 加法 (add v.2d)
function NEONAddI64x2(const a, b: TVecI64x2): TVecI64x2; assembler; nostackframe;
asm
  // ABI: a in x0..x1, b in x2..x3, return in x0..x1
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  add   v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I64x2 减法 (sub v.2d)
function NEONSubI64x2(const a, b: TVecI64x2): TVecI64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I64x2 位与 (and v.16b)
function NEONAndI64x2(const a, b: TVecI64x2): TVecI64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I64x2 位或 (orr v.16b)
function NEONOrI64x2(const a, b: TVecI64x2): TVecI64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I64x2 位异或 (eor v.16b)
function NEONXorI64x2(const a, b: TVecI64x2): TVecI64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I64x2 位非 (mvn v.16b)
function NEONNotI64x2(const a: TVecI64x2): TVecI64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// I64x2 相等比较 (cmeq v.2d) -> TMask2
function NEONCmpEqI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.2d, v0.2d, v1.2d

  // 提取掩码: 每个 64-bit lane 的最高位
  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63
  orr   w0, w2, w3, lsl #1
end;

// I64x2 大于比较 (cmgt v.2d) -> TMask2
function NEONCmpGtI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmgt  v0.2d, v0.2d, v1.2d

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63
  orr   w0, w2, w3, lsl #1
end;

// I64x2 小于比较 (a < b = b > a)
function NEONCmpLtI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  // 交换 a 和 b，然后用 cmgt
  fmov  d0, x2        // b
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0        // a
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmgt  v0.2d, v0.2d, v1.2d  // b > a

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63
  orr   w0, w2, w3, lsl #1
end;

// I64x2 小于等于 (a <= b = NOT(a > b))
function NEONCmpLeI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmgt  v0.2d, v0.2d, v1.2d  // a > b
  mvn   v0.16b, v0.16b       // NOT

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63
  orr   w0, w2, w3, lsl #1
end;

// I64x2 大于等于 (a >= b = NOT(b > a))
function NEONCmpGeI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  // 交换 a 和 b，然后用 cmgt，然后取反
  fmov  d0, x2        // b
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0        // a
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmgt  v0.2d, v0.2d, v1.2d  // b > a = a < b
  mvn   v0.16b, v0.16b       // NOT

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63
  orr   w0, w2, w3, lsl #1
end;

// I64x2 不等比较 (a != b = NOT(a == b))
function NEONCmpNeI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.2d, v0.2d, v1.2d  // a == b
  mvn   v0.16b, v0.16b       // NOT

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63
  orr   w0, w2, w3, lsl #1
end;

// ============================================================================
// === I32x4 Comparison Operations (NEON) ===
// ============================================================================

// I32x4 相等比较 (cmeq v.4s) -> TMask4
function NEONCmpEqI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.4s, v0.4s, v1.4s

  // 提取掩码
  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// I32x4 大于比较 (cmgt v.4s) -> TMask4
function NEONCmpGtI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmgt  v0.4s, v0.4s, v1.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// I32x4 小于比较 (a < b = b > a)
function NEONCmpLtI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  // 交换 a 和 b
  fmov  d0, x2        // b
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0        // a
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmgt  v0.4s, v0.4s, v1.4s  // b > a

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// I32x4 小于等于 (a <= b = NOT(a > b))
function NEONCmpLeI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmgt  v0.4s, v0.4s, v1.4s  // a > b
  mvn   v0.16b, v0.16b       // NOT

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// I32x4 大于等于 (a >= b = NOT(b > a))
function NEONCmpGeI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  // 交换 a 和 b
  fmov  d0, x2        // b
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0        // a
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmgt  v0.4s, v0.4s, v1.4s  // b > a
  mvn   v0.16b, v0.16b       // NOT

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// I32x4 不等比较 (a != b = NOT(a == b))
function NEONCmpNeI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.4s, v0.4s, v1.4s
  mvn   v0.16b, v0.16b

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// ============================================================================
// === I16x8 Comparison Operations (NEON) ===
// ============================================================================

// I16x8 相等比较 (cmeq v.8h) -> TMask8
function NEONCmpEqI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.8h, v0.8h, v1.8h

  // 提取 8 个 16-bit lane 的掩码
  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// I16x8 大于比较 (cmgt v.8h) -> TMask8
function NEONCmpGtI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmgt  v0.8h, v0.8h, v1.8h

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// I16x8 小于比较
function NEONCmpLtI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmgt  v0.8h, v0.8h, v1.8h

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// I16x8 小于等于比较
function NEONCmpLeI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmgt  v0.8h, v0.8h, v1.8h
  mvn   v0.16b, v0.16b

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// I16x8 大于等于比较
function NEONCmpGeI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmgt  v0.8h, v0.8h, v1.8h
  mvn   v0.16b, v0.16b

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// I16x8 不等比较
function NEONCmpNeI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.8h, v0.8h, v1.8h
  mvn   v0.16b, v0.16b

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// ============================================================================
// === I8x16 Comparison Operations (NEON) ===
// ============================================================================

// I8x16 相等比较 (cmeq v.16b) -> TMask16
function NEONCmpEqI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.16b, v0.16b, v1.16b

  // 提取 16 个字节的掩码
  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// I8x16 大于比较 (cmgt v.16b) -> TMask16
function NEONCmpGtI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmgt  v0.16b, v0.16b, v1.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// I8x16 小于比较
function NEONCmpLtI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmgt  v0.16b, v0.16b, v1.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// I8x16 小于等于比较
function NEONCmpLeI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmgt  v0.16b, v0.16b, v1.16b
  mvn   v0.16b, v0.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// I8x16 大于等于比较
function NEONCmpGeI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmgt  v0.16b, v0.16b, v1.16b
  mvn   v0.16b, v0.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// I8x16 不等比较
function NEONCmpNeI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.16b, v0.16b, v1.16b
  mvn   v0.16b, v0.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// ============================================================================
// === U32x4 Comparison Operations (NEON) ===
// ============================================================================
// 无符号比较使用 cmhi (无符号大于) 和 cmhs (无符号大于等于)

// U32x4 相等比较 (cmeq v.4s) -> TMask4
function NEONCmpEqU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.4s, v0.4s, v1.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// U32x4 大于比较 (cmhi v.4s - unsigned higher than) -> TMask4
function NEONCmpGtU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhi  v0.4s, v0.4s, v1.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// U32x4 小于比较 (a < b = b > a)
function NEONCmpLtU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmhi  v0.4s, v0.4s, v1.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// U32x4 小于等于 (a <= b = NOT(a > b))
function NEONCmpLeU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhi  v0.4s, v0.4s, v1.4s
  mvn   v0.16b, v0.16b

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// U32x4 大于等于 (a >= b = cmhs - unsigned higher or same)
function NEONCmpGeU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhs  v0.4s, v0.4s, v1.4s

  umov  w1, v0.s[0]
  lsr   w1, w1, #31
  umov  w2, v0.s[1]
  lsr   w2, w2, #31
  umov  w3, v0.s[2]
  lsr   w3, w3, #31
  umov  w4, v0.s[3]
  lsr   w4, w4, #31

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3
end;

// ============================================================================
// === U32x4 Reduction Operations (NEON) ===
// ============================================================================

// ============================================================================
// === U16x8 Comparison Operations (NEON) ===
// ============================================================================

// U16x8 相等比较 (cmeq v.8h) -> TMask8
function NEONCmpEqU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.8h, v0.8h, v1.8h

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// U16x8 大于比较 (cmhi v.8h) -> TMask8
function NEONCmpGtU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhi  v0.8h, v0.8h, v1.8h

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// U16x8 小于比较
function NEONCmpLtU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmhi  v0.8h, v0.8h, v1.8h

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// U16x8 小于等于比较
function NEONCmpLeU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhi  v0.8h, v0.8h, v1.8h
  mvn   v0.16b, v0.16b

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// U16x8 大于等于比较
function NEONCmpGeU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhs  v0.8h, v0.8h, v1.8h

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// U16x8 不等比较
function NEONCmpNeU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.8h, v0.8h, v1.8h
  mvn   v0.16b, v0.16b

  umov  w1, v0.h[0]
  lsr   w1, w1, #15
  umov  w2, v0.h[1]
  lsr   w2, w2, #15
  umov  w3, v0.h[2]
  lsr   w3, w3, #15
  umov  w4, v0.h[3]
  lsr   w4, w4, #15

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.h[4]
  lsr   w1, w1, #15
  umov  w2, v0.h[5]
  lsr   w2, w2, #15
  umov  w3, v0.h[6]
  lsr   w3, w3, #15
  umov  w4, v0.h[7]
  lsr   w4, w4, #15

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7
end;

// ============================================================================
// === U8x16 Comparison Operations (NEON) ===
// ============================================================================

// U8x16 相等比较 (cmeq v.16b) -> TMask16
function NEONCmpEqU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.16b, v0.16b, v1.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// U8x16 大于比较 (cmhi v.16b) -> TMask16
function NEONCmpGtU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhi  v0.16b, v0.16b, v1.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// U8x16 小于比较
function NEONCmpLtU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x2
  fmov  d2, x3
  ins   v0.d[1], v2.d[0]

  fmov  d1, x0
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  cmhi  v0.16b, v0.16b, v1.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// U8x16 小于等于比较
function NEONCmpLeU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhi  v0.16b, v0.16b, v1.16b
  mvn   v0.16b, v0.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// U8x16 大于等于比较
function NEONCmpGeU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmhs  v0.16b, v0.16b, v1.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;

// U8x16 不等比较
function NEONCmpNeU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  cmeq  v0.16b, v0.16b, v1.16b
  mvn   v0.16b, v0.16b

  umov  w1, v0.b[0]
  lsr   w1, w1, #7
  umov  w2, v0.b[1]
  lsr   w2, w2, #7
  umov  w3, v0.b[2]
  lsr   w3, w3, #7
  umov  w4, v0.b[3]
  lsr   w4, w4, #7

  orr   w0, w1, w2, lsl #1
  orr   w0, w0, w3, lsl #2
  orr   w0, w0, w4, lsl #3

  umov  w1, v0.b[4]
  lsr   w1, w1, #7
  umov  w2, v0.b[5]
  lsr   w2, w2, #7
  umov  w3, v0.b[6]
  lsr   w3, w3, #7
  umov  w4, v0.b[7]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #4
  orr   w0, w0, w2, lsl #5
  orr   w0, w0, w3, lsl #6
  orr   w0, w0, w4, lsl #7

  umov  w1, v0.b[8]
  lsr   w1, w1, #7
  umov  w2, v0.b[9]
  lsr   w2, w2, #7
  umov  w3, v0.b[10]
  lsr   w3, w3, #7
  umov  w4, v0.b[11]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #8
  orr   w0, w0, w2, lsl #9
  orr   w0, w0, w3, lsl #10
  orr   w0, w0, w4, lsl #11

  umov  w1, v0.b[12]
  lsr   w1, w1, #7
  umov  w2, v0.b[13]
  lsr   w2, w2, #7
  umov  w3, v0.b[14]
  lsr   w3, w3, #7
  umov  w4, v0.b[15]
  lsr   w4, w4, #7

  orr   w0, w0, w1, lsl #12
  orr   w0, w0, w2, lsl #13
  orr   w0, w0, w3, lsl #14
  orr   w0, w0, w4, lsl #15
end;
