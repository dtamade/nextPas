// === F32x8 Math Operations (256-bit AVX) ===

function AVX2AbsF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a
  vmovups  ymm0, [rsi]
  vpcmpeqd ymm1, ymm1, ymm1  // all 1s
  vpsrld   ymm1, ymm1, 1     // shift right 1 = 0x7FFFFFFF
  vandps   ymm0, ymm0, ymm1
  vmovups  [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a
  vmovups  ymm0, [rdx]
  vpcmpeqd ymm1, ymm1, ymm1
  vpsrld   ymm1, ymm1, 1
  vandps   ymm0, ymm0, ymm1
  vmovups  [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2SqrtF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a
  vmovups ymm0, [rsi]
  vsqrtps ymm0, ymm0
  vmovups [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a
  vmovups ymm0, [rdx]
  vsqrtps ymm0, ymm0
  vmovups [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2MinF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovups ymm0, [rsi]
  vminps  ymm0, ymm0, [rdx]
  vmovups [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovups ymm0, [rdx]
  vminps  ymm0, ymm0, [r8]
  vmovups [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2MaxF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovups ymm0, [rsi]
  vmaxps  ymm0, ymm0, [rdx]
  vmovups [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovups ymm0, [rdx]
  vmaxps  ymm0, ymm0, [r8]
  vmovups [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2ClampF32x8(const a, minVal, maxVal: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@minVal, rcx=@maxVal
  vmovups ymm0, [rsi]
  vmaxps  ymm0, ymm0, [rdx]   // clamp to min
  vminps  ymm0, ymm0, [rcx]   // clamp to max
  vmovups [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@minVal, r9=@maxVal
  vmovups ymm0, [rdx]
  vmaxps  ymm0, ymm0, [r8]    // clamp to min
  vminps  ymm0, ymm0, [r9]    // clamp to max
  vmovups [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;
