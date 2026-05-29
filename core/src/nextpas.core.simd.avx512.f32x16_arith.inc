// === F32x16 Arithmetic Operations (512-bit) ===

function AVX512AddF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovups zmm0, [rsi]
  vaddps  zmm0, zmm0, [rdx]
  vmovups [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovups zmm0, [rdx]
  vaddps  zmm0, zmm0, [r8]
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512SubF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovups zmm0, [rsi]
  vsubps  zmm0, zmm0, [rdx]
  vmovups [rdi], zmm0
  {$ELSE}
  vmovups zmm0, [rdx]
  vsubps  zmm0, zmm0, [r8]
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512MulF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovups zmm0, [rsi]
  vmulps  zmm0, zmm0, [rdx]
  vmovups [rdi], zmm0
  {$ELSE}
  vmovups zmm0, [rdx]
  vmulps  zmm0, zmm0, [r8]
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512DivF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovups zmm0, [rsi]
  vdivps  zmm0, zmm0, [rdx]
  vmovups [rdi], zmm0
  {$ELSE}
  vmovups zmm0, [rdx]
  vdivps  zmm0, zmm0, [r8]
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;
