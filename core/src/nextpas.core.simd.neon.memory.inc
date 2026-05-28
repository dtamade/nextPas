// === Memory Operations ===

function NEONLoadF32x4(p: PSingle): TVecF32x4; assembler; nostackframe;
asm
  // p in x0, return in x0..x1
  ldr   q0, [x0]
  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONLoadF32x4Aligned(p: PSingle): TVecF32x4; assembler; nostackframe;
asm
  ldr   q0, [x0]
  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

procedure NEONStoreF32x4(p: PSingle; const a: TVecF32x4); assembler; nostackframe;
asm
  // p: x0, a: x1..x2
  fmov  d0, x1
  fmov  d1, x2
  ins   v0.d[1], v1.d[0]
  str   q0, [x0]
end;

procedure NEONStoreF32x4Aligned(p: PSingle; const a: TVecF32x4); assembler; nostackframe;
asm
  fmov  d0, x1
  fmov  d1, x2
  ins   v0.d[1], v1.d[0]
  str   q0, [x0]
end;

