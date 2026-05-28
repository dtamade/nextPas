// === Utility Operations ===

function NEONSplatF32x4(value: Single): TVecF32x4; assembler; nostackframe;
asm
  // value in s0
  fmov  w2, s0
  dup   v0.4s, w2

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONZeroF32x4: TVecF32x4; assembler; nostackframe;
asm
  mov   x0, xzr
  mov   x1, xzr
end;

function NEONExtractF32x4(const a: TVecF32x4; index: Integer): Single; assembler; nostackframe;
asm
  // ABI: a in x0..x1, index in w2
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  // Clamp index to [0..3] (saturating semantics)
  cmp   w2, #0
  b.ge  .Lext_clamp_hi_check
  mov   w2, #0
  b     .Lext_clamp_done
.Lext_clamp_hi_check:
  cmp   w2, #3
  b.le  .Lext_clamp_done
  mov   w2, #3
.Lext_clamp_done:

  cbz   w2, .L0
  cmp   w2, #1
  b.eq  .L1
  cmp   w2, #2
  b.eq  .L2
  mov   s0, v0.s[3]
  ret
.L0:
  // s0 already holds v0.s[0]
  ret
.L1:
  mov   s0, v0.s[1]
  ret
.L2:
  mov   s0, v0.s[2]
end;

