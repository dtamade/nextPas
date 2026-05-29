// === I32x16 Arithmetic Operations (512-bit) ===

function AVX512AddI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a, rdx=@b
    vmovdqu64 zmm0, [rsi]
    vpaddd  zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a, r8=@b
    vmovdqu64 zmm0, [rdx]
    vpaddd  zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512SubI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovdqu64 zmm0, [rsi]
    vpsubd  zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    vmovdqu64 zmm0, [rdx]
    vpsubd  zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512MulI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovdqu64 zmm0, [rsi]
    vpmulld zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    vmovdqu64 zmm0, [rdx]
    vpmulld zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
