// === F64x4 Operations (native 256-bit AVX) ===

function AVX2AddF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovupd ymm0, [rsi]
  vaddpd  ymm0, ymm0, [rdx]
  vmovupd [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovupd ymm0, [rdx]
  vaddpd  ymm0, ymm0, [r8]
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2SubF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovupd ymm0, [rsi]
  vsubpd  ymm0, ymm0, [rdx]
  vmovupd [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovupd ymm0, [rdx]
  vsubpd  ymm0, ymm0, [r8]
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2MulF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovupd ymm0, [rsi]
  vmulpd  ymm0, ymm0, [rdx]
  vmovupd [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovupd ymm0, [rdx]
  vmulpd  ymm0, ymm0, [r8]
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2DivF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovupd ymm0, [rsi]
  vdivpd  ymm0, ymm0, [rdx]
  vmovupd [rdi], ymm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovupd ymm0, [rdx]
  vdivpd  ymm0, ymm0, [r8]
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;
