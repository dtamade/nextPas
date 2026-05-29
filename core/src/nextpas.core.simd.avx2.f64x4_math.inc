// === F64x4 Math Operations (256-bit AVX) ===

function AVX2AbsF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  // Generate AbsMask dynamically (PIC-safe): 0x7FFFFFFFFFFFFFFF for each lane
  {$IFDEF UNIX}
  vmovupd  ymm0, [rsi]
  vpcmpeqd ymm1, ymm1, ymm1  // all 1s
  vpsrlq   ymm1, ymm1, 1     // shift right 1 = 0x7FFFFFFFFFFFFFFF
  vandpd   ymm0, ymm0, ymm1
  vmovupd  [rdi], ymm0
  {$ELSE}
  vmovupd  ymm0, [rdx]
  vpcmpeqd ymm1, ymm1, ymm1
  vpsrlq   ymm1, ymm1, 1
  vandpd   ymm0, ymm0, ymm1
  vmovupd  [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2SqrtF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovupd ymm0, [rsi]
  vsqrtpd ymm0, ymm0
  vmovupd [rdi], ymm0
  {$ELSE}
  vmovupd ymm0, [rdx]
  vsqrtpd ymm0, ymm0
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2MinF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovupd ymm0, [rsi]
  vminpd  ymm0, ymm0, [rdx]
  vmovupd [rdi], ymm0
  {$ELSE}
  vmovupd ymm0, [rdx]
  vminpd  ymm0, ymm0, [r8]
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2MaxF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovupd ymm0, [rsi]
  vmaxpd  ymm0, ymm0, [rdx]
  vmovupd [rdi], ymm0
  {$ELSE}
  vmovupd ymm0, [rdx]
  vmaxpd  ymm0, ymm0, [r8]
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

function AVX2ClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovupd ymm0, [rsi]
  vmaxpd  ymm0, ymm0, [rdx]   // clamp to min
  vminpd  ymm0, ymm0, [rcx]   // clamp to max
  vmovupd [rdi], ymm0
  {$ELSE}
  vmovupd ymm0, [rdx]
  vmaxpd  ymm0, ymm0, [r8]    // clamp to min
  vminpd  ymm0, ymm0, [r9]    // clamp to max
  vmovupd [rcx], ymm0
  {$ENDIF}
  vzeroupper
end;

