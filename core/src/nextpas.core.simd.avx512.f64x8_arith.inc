// === F64x8 Arithmetic Operations (512-bit) ===

function AVX512AddF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV: rdi=@Result, rsi=@a, rdx=@b
  vmovupd zmm0, [rsi]
  vaddpd  zmm0, zmm0, [rdx]
  vmovupd [rdi], zmm0
  {$ELSE}
  // Win64: rcx=@Result, rdx=@a, r8=@b
  vmovupd zmm0, [rdx]
  vaddpd  zmm0, zmm0, [r8]
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512SubF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovupd zmm0, [rsi]
  vsubpd  zmm0, zmm0, [rdx]
  vmovupd [rdi], zmm0
  {$ELSE}
  vmovupd zmm0, [rdx]
  vsubpd  zmm0, zmm0, [r8]
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512MulF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovupd zmm0, [rsi]
  vmulpd  zmm0, zmm0, [rdx]
  vmovupd [rdi], zmm0
  {$ELSE}
  vmovupd zmm0, [rdx]
  vmulpd  zmm0, zmm0, [r8]
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;

function AVX512DivF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovupd zmm0, [rsi]
  vdivpd  zmm0, zmm0, [rdx]
  vmovupd [rdi], zmm0
  {$ELSE}
  vmovupd zmm0, [rdx]
  vdivpd  zmm0, zmm0, [r8]
  vmovupd [rcx], zmm0
  {$ENDIF}
  vzeroupper
end;
