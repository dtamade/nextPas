// === F32x16 Math Functions ===

function AVX512AbsF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a
  mov     ecx, $7FFFFFFF
  vpbroadcastd zmm1, ecx
  vmovups zmm0, [rsi]
  vpandd  zmm0, zmm0, zmm1
  vmovups [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a
  mov     eax, $7FFFFFFF
  vpbroadcastd zmm1, eax
  vmovups zmm0, [rdx]
  vpandd  zmm0, zmm0, zmm1
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512SqrtF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a
  vmovups zmm0, [rsi]
  vsqrtps zmm0, zmm0
  vmovups [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a
  vmovups zmm0, [rdx]
  vsqrtps zmm0, zmm0
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512MinF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovups zmm0, [rsi]
  vminps  zmm0, zmm0, [rdx]
  vmovups [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovups zmm0, [rdx]
  vminps  zmm0, zmm0, [r8]
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512MaxF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovups zmm0, [rsi]
  vmaxps  zmm0, zmm0, [rdx]
  vmovups [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovups zmm0, [rdx]
  vmaxps  zmm0, zmm0, [r8]
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512ClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@minVal, rcx=@maxVal
  vmovups zmm0, [rsi]
  vmaxps  zmm0, zmm0, [rdx]    // max(a, minVal)
  vminps  zmm0, zmm0, [rcx]    // min(result, maxVal)
  vmovups [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@minVal, r9=@maxVal
  vmovups zmm0, [rdx]
  vmaxps  zmm0, zmm0, [r8]     // max(a, minVal)
  vminps  zmm0, zmm0, [r9]     // min(result, maxVal)
  vmovups [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;
