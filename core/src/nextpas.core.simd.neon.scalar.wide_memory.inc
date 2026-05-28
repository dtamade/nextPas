// === 256-bit & 512-bit Memory Operations (NEON ASM) ===

// --- F32x8 Memory Ops (256-bit = 2 × F32x4) ---

function NEONLoadF32x8_ASM(p: PSingle): TVecF32x8; assembler; nostackframe;
asm
  // p in x0, return TVecF32x8 in x0..x3
  // Load 256-bit (2 × 128-bit)
  ldp   q0, q1, [x0]

  // Extract lo (v0) to x0..x1
  umov  x0, v0.d[0]
  umov  x1, v0.d[1]

  // Extract hi (v1) to x2..x3
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
end;

procedure NEONStoreF32x8_ASM(p: PSingle; const a: TVecF32x8); assembler; nostackframe;
asm
  // p in x0, a in x1..x4 (lo: x1..x2, hi: x3..x4)
  // Build lo in v0
  fmov  d0, x1
  fmov  d2, x2
  ins   v0.d[1], v2.d[0]

  // Build hi in v1
  fmov  d1, x3
  fmov  d3, x4
  ins   v1.d[1], v3.d[0]

  // Store 256-bit
  stp   q0, q1, [x0]
end;

function NEONSplatF32x8_ASM(value: Single): TVecF32x8; assembler; nostackframe;
asm
  // value in s0
  fmov  w4, s0
  dup   v0.4s, w4
  dup   v1.4s, w4

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
end;

function NEONZeroF32x8_ASM: TVecF32x8; assembler; nostackframe;
asm
  mov   x0, xzr
  mov   x1, xzr
  mov   x2, xzr
  mov   x3, xzr
end;

// --- F64x4 Memory Ops (256-bit = 2 × F64x2) ---

function NEONLoadF64x4_ASM(p: PDouble): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
end;

procedure NEONStoreF64x4_ASM(p: PDouble; const a: TVecF64x4); assembler; nostackframe;
asm
  fmov  d0, x1
  fmov  d2, x2
  ins   v0.d[1], v2.d[0]

  fmov  d1, x3
  fmov  d3, x4
  ins   v1.d[1], v3.d[0]

  stp   q0, q1, [x0]
end;

function NEONSplatF64x4_ASM(value: Double): TVecF64x4; assembler; nostackframe;
asm
  // value in d0
  dup   v0.2d, v0.d[0]
  dup   v1.2d, v0.d[0]

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
end;

function NEONZeroF64x4_ASM: TVecF64x4; assembler; nostackframe;
asm
  mov   x0, xzr
  mov   x1, xzr
  mov   x2, xzr
  mov   x3, xzr
end;

// --- F32x16 Memory Ops (512-bit = 4 × F32x4) ---

function NEONLoadF32x16_ASM(p: PSingle): TVecF32x16; assembler; nostackframe;
asm
  // p in x0, return TVecF32x16 in x0..x7
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
  umov  x4, v2.d[0]
  umov  x5, v2.d[1]
  umov  x6, v3.d[0]
  umov  x7, v3.d[1]
end;

procedure NEONStoreF32x16_ASM(p: PSingle; const a: TVecF32x16); assembler; nostackframe;
asm
  // p in x0, a in x1..x8 (stack: x8 is passed in [sp])
  // Build v0..v3
  fmov  d0, x1
  fmov  d4, x2
  ins   v0.d[1], v4.d[0]

  fmov  d1, x3
  fmov  d5, x4
  ins   v1.d[1], v5.d[0]

  fmov  d2, x5
  fmov  d6, x6
  ins   v2.d[1], v6.d[0]

  fmov  d3, x7
  ldr   x9, [sp]
  fmov  d7, x9
  ins   v3.d[1], v7.d[0]

  stp   q0, q1, [x0]
  stp   q2, q3, [x0, #32]
end;

function NEONSplatF32x16_ASM(value: Single): TVecF32x16; assembler; nostackframe;
asm
  fmov  w4, s0
  dup   v0.4s, w4
  dup   v1.4s, w4
  dup   v2.4s, w4
  dup   v3.4s, w4

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
  umov  x4, v2.d[0]
  umov  x5, v2.d[1]
  umov  x6, v3.d[0]
  umov  x7, v3.d[1]
end;

function NEONZeroF32x16_ASM: TVecF32x16; assembler; nostackframe;
asm
  mov   x0, xzr
  mov   x1, xzr
  mov   x2, xzr
  mov   x3, xzr
  mov   x4, xzr
  mov   x5, xzr
  mov   x6, xzr
  mov   x7, xzr
end;

// --- F64x8 Memory Ops (512-bit = 4 × F64x2) ---

function NEONLoadF64x8_ASM(p: PDouble): TVecF64x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
  umov  x4, v2.d[0]
  umov  x5, v2.d[1]
  umov  x6, v3.d[0]
  umov  x7, v3.d[1]
end;

procedure NEONStoreF64x8_ASM(p: PDouble; const a: TVecF64x8); assembler; nostackframe;
asm
  fmov  d0, x1
  fmov  d4, x2
  ins   v0.d[1], v4.d[0]

  fmov  d1, x3
  fmov  d5, x4
  ins   v1.d[1], v5.d[0]

  fmov  d2, x5
  fmov  d6, x6
  ins   v2.d[1], v6.d[0]

  fmov  d3, x7
  ldr   x9, [sp]
  fmov  d7, x9
  ins   v3.d[1], v7.d[0]

  stp   q0, q1, [x0]
  stp   q2, q3, [x0, #32]
end;

function NEONSplatF64x8_ASM(value: Double): TVecF64x8; assembler; nostackframe;
asm
  dup   v0.2d, v0.d[0]
  dup   v1.2d, v0.d[0]
  dup   v2.2d, v0.d[0]
  dup   v3.2d, v0.d[0]

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
  umov  x4, v2.d[0]
  umov  x5, v2.d[1]
  umov  x6, v3.d[0]
  umov  x7, v3.d[1]
end;

function NEONZeroF64x8_ASM: TVecF64x8; assembler; nostackframe;
asm
  mov   x0, xzr
  mov   x1, xzr
  mov   x2, xzr
  mov   x3, xzr
  mov   x4, xzr
  mov   x5, xzr
  mov   x6, xzr
  mov   x7, xzr
end;

// --- I64x4 Memory Ops (256-bit = 2 × I64x2) ---

function NEONLoadI64x4_ASM(p: PInt64): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
end;

procedure NEONStoreI64x4_ASM(p: PInt64; const a: TVecI64x4); assembler; nostackframe;
asm
  fmov  d0, x1
  fmov  d2, x2
  ins   v0.d[1], v2.d[0]

  fmov  d1, x3
  fmov  d3, x4
  ins   v1.d[1], v3.d[0]

  stp   q0, q1, [x0]
end;

function NEONSplatI64x4_ASM(value: Int64): TVecI64x4; assembler; nostackframe;
asm
  // value in x0
  dup   v0.2d, x0
  dup   v1.2d, x0

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
  umov  x2, v1.d[0]
  umov  x3, v1.d[1]
end;

function NEONZeroI64x4_ASM: TVecI64x4; assembler; nostackframe;
asm
  mov   x0, xzr
  mov   x1, xzr
  mov   x2, xzr
  mov   x3, xzr
end;

