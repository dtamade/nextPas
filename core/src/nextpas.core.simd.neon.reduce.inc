// === Reduction Operations ===

function NEONReduceAddF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  // a: x0..x1
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  // Keep compatibility with toolchains that reject `faddp`.
  mov   s1, v0.s[1]
  mov   s2, v0.s[2]
  mov   s3, v0.s[3]
  fadd  s0, s0, s1
  fadd  s0, s0, s2
  fadd  s0, s0, s3
end;

function NEONReduceMinF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fminp v0.4s, v0.4s, v0.4s
  fminp s0, v0.2s
end;

function NEONReduceMaxF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmaxp v0.4s, v0.4s, v0.4s
  fmaxp s0, v0.2s
end;

function NEONReduceMulF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  // Extract and multiply: no native instruction, do manually
  mov   s1, v0.s[1]
  mov   s2, v0.s[2]
  mov   s3, v0.s[3]
  fmul  s0, s0, s1
  fmul  s0, s0, s2
  fmul  s0, s0, s3
end;

