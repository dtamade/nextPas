// === F64x8 Math Functions ===

function AVX512AbsF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a
  mov     rcx, $7FFFFFFFFFFFFFFF
  vpbroadcastq zmm1, rcx
  vmovupd zmm0, [rsi]
  vpandq  zmm0, zmm0, zmm1
  vmovupd [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a
  mov     rax, $7FFFFFFFFFFFFFFF
  vpbroadcastq zmm1, rax
  vmovupd zmm0, [rdx]
  vpandq  zmm0, zmm0, zmm1
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512SqrtF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a
  vmovupd zmm0, [rsi]
  vsqrtpd zmm0, zmm0
  vmovupd [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a
  vmovupd zmm0, [rdx]
  vsqrtpd zmm0, zmm0
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512MinF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovupd zmm0, [rsi]
  vminpd  zmm0, zmm0, [rdx]
  vmovupd [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovupd zmm0, [rdx]
  vminpd  zmm0, zmm0, [r8]
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512MaxF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovupd zmm0, [rsi]
  vmaxpd  zmm0, zmm0, [rdx]
  vmovupd [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovupd zmm0, [rdx]
  vmaxpd  zmm0, zmm0, [r8]
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512ClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@minVal, rcx=@maxVal
  vmovupd zmm0, [rsi]
  vmaxpd  zmm0, zmm0, [rdx]    // max(a, minVal)
  vminpd  zmm0, zmm0, [rcx]    // min(result, maxVal)
  vmovupd [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@minVal, r9=@maxVal
  vmovupd zmm0, [rdx]
  vmaxpd  zmm0, zmm0, [r8]     // max(a, minVal)
  vminpd  zmm0, zmm0, [r9]     // min(result, maxVal)
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;
