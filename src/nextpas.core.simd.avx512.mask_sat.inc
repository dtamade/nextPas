// === TMask16 Operations (AVX-512 Optimized) ===

function AVX512Mask16All(mask: TMask16): Boolean; assembler; nostackframe;
// RDI = mask (16-bit)
asm
  cmp     di, $FFFF
  sete    al
end;

function AVX512Mask16Any(mask: TMask16): Boolean; assembler; nostackframe;
asm
  test    di, di
  setne   al
end;

function AVX512Mask16None(mask: TMask16): Boolean; assembler; nostackframe;
asm
  test    di, di
  sete    al
end;

function AVX512Mask16PopCount(mask: TMask16): Integer; assembler; nostackframe;
asm
  movzx   eax, di
  popcnt  eax, eax
end;

function AVX512Mask16FirstSet(mask: TMask16): Integer; assembler; nostackframe;
asm
  movzx   eax, di
  test    eax, eax
  jz      @none
  bsf     eax, eax
  ret
@none:
  mov     eax, -1
end;

// === ✅ P2: Saturating Arithmetic (EVEX-encoded 128-bit) ===
// 使用 EVEX 编码的 128-bit 指令，保持 API 一致性

// I8x16 有符号饱和加法 (VPADDSB)
function AVX512I8x16SatAdd(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // SysV ABI: a -> RDI, b -> RSI, Result -> RAX
  vmovdqu xmm0, [rdi]
  vmovdqu xmm1, [rsi]
  vpaddsb xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ELSE}
  // Win64 ABI: a -> RCX, b -> RDX, Result -> RAX
  vmovdqu xmm0, [rcx]
  vmovdqu xmm1, [rdx]
  vpaddsb xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ENDIF}
end;

// I8x16 有符号饱和减法 (VPSUBSB)
function AVX512I8x16SatSub(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovdqu xmm0, [rdi]
  vmovdqu xmm1, [rsi]
  vpsubsb xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ELSE}
  vmovdqu xmm0, [rcx]
  vmovdqu xmm1, [rdx]
  vpsubsb xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ENDIF}
end;

// I16x8 有符号饱和加法 (VPADDSW)
function AVX512I16x8SatAdd(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovdqu xmm0, [rdi]
  vmovdqu xmm1, [rsi]
  vpaddsw xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ELSE}
  vmovdqu xmm0, [rcx]
  vmovdqu xmm1, [rdx]
  vpaddsw xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ENDIF}
end;

// I16x8 有符号饱和减法 (VPSUBSW)
function AVX512I16x8SatSub(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovdqu xmm0, [rdi]
  vmovdqu xmm1, [rsi]
  vpsubsw xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ELSE}
  vmovdqu xmm0, [rcx]
  vmovdqu xmm1, [rdx]
  vpsubsw xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ENDIF}
end;

// U8x16 无符号饱和加法 (VPADDUSB)
function AVX512U8x16SatAdd(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovdqu xmm0, [rdi]
  vmovdqu xmm1, [rsi]
  vpaddusb xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ELSE}
  vmovdqu xmm0, [rcx]
  vmovdqu xmm1, [rdx]
  vpaddusb xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ENDIF}
end;

// U8x16 无符号饱和减法 (VPSUBUSB)
function AVX512U8x16SatSub(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovdqu xmm0, [rdi]
  vmovdqu xmm1, [rsi]
  vpsubusb xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ELSE}
  vmovdqu xmm0, [rcx]
  vmovdqu xmm1, [rdx]
  vpsubusb xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ENDIF}
end;

// U16x8 无符号饱和加法 (VPADDUSW)
function AVX512U16x8SatAdd(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovdqu xmm0, [rdi]
  vmovdqu xmm1, [rsi]
  vpaddusw xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ELSE}
  vmovdqu xmm0, [rcx]
  vmovdqu xmm1, [rdx]
  vpaddusw xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ENDIF}
end;

// U16x8 无符号饱和减法 (VPSUBUSW)
function AVX512U16x8SatSub(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  vmovdqu xmm0, [rdi]
  vmovdqu xmm1, [rsi]
  vpsubusw xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ELSE}
  vmovdqu xmm0, [rcx]
  vmovdqu xmm1, [rdx]
  vpsubusw xmm0, xmm0, xmm1
  vmovdqu [rax], xmm0
  vzeroupper
  {$ENDIF}
end;

