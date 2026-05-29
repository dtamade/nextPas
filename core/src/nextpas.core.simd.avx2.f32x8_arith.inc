// === F32x8 Operations (native 256-bit AVX) ===

function AVX2AddF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV ABI: rdi=@Result, rsi=@a, rdx=@b
  vmovups ymm0, [rsi]
  vaddps  ymm0, ymm0, [rdx]
  vmovups [rdi], ymm0
  {$ELSE}
  // Win64 ABI: rcx=@Result, rdx=@a, r8=@b
  vmovups ymm0, [rdx]
  vaddps  ymm0, ymm0, [r8]
  vmovups [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2SubF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovups ymm0, [rsi]
  vsubps  ymm0, ymm0, [rdx]
  vmovups [rdi], ymm0
  {$ELSE}
  vmovups ymm0, [rdx]
  vsubps  ymm0, ymm0, [r8]
  vmovups [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2MulF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovups ymm0, [rsi]
  vmulps  ymm0, ymm0, [rdx]
  vmovups [rdi], ymm0
  {$ELSE}
  vmovups ymm0, [rdx]
  vmulps  ymm0, ymm0, [r8]
  vmovups [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2DivF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovups ymm0, [rsi]
  vdivps  ymm0, ymm0, [rdx]
  vmovups [rdi], ymm0
  {$ELSE}
  vmovups ymm0, [rdx]
  vdivps  ymm0, ymm0, [r8]
  vmovups [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

