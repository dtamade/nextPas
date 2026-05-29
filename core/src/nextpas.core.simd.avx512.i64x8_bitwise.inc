// === I64x8 Bitwise Operations ===

function AVX512AndI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a, rdx=@b
    vmovdqu64 zmm0, [rsi]
    vpandq  zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a, r8=@b
    vmovdqu64 zmm0, [rdx]
    vpandq  zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512OrI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovdqu64 zmm0, [rsi]
    vporq   zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    vmovdqu64 zmm0, [rdx]
    vporq   zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512XorI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovdqu64 zmm0, [rsi]
    vpxorq  zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    vmovdqu64 zmm0, [rdx]
    vpxorq  zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512NotI64x8(const a: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a
    vmovdqu64 zmm0, [rsi]
    vpternlogq zmm0, zmm0, zmm0, $55   // NOT A
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a
    vmovdqu64 zmm0, [rdx]
    vpternlogq zmm0, zmm0, zmm0, $55   // NOT A
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
