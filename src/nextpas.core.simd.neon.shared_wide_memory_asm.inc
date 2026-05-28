// AArch64 asm-only helpers that remain backend-owned when compiler-ready NEON
// asm is enabled. These slots are referenced directly by the shared register
// table and cannot stay stranded in an unreferenced scalar-only include.

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
