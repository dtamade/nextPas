// === I64x8 Arithmetic Operations (512-bit) ===

function AVX512AddI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a, rdx=@b
    vmovdqu64 zmm0, [rsi]
    vpaddq  zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a, r8=@b
    vmovdqu64 zmm0, [rdx]
    vpaddq  zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512SubI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovdqu64 zmm0, [rsi]
    vpsubq  zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    vmovdqu64 zmm0, [rdx]
    vpsubq  zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
