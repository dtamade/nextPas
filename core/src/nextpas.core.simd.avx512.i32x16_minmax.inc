// === I32x16 Min/Max Operations ===

function AVX512MinI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a, rdx=@b
    vmovdqu64 zmm0, [rsi]
    vpminsd zmm0, zmm0, [rdx]   // Signed min
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a, r8=@b
    vmovdqu64 zmm0, [rdx]
    vpminsd zmm0, zmm0, [r8]   // Signed min
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512MaxI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovdqu64 zmm0, [rsi]
    vpmaxsd zmm0, zmm0, [rdx]   // Signed max
    vmovdqu64 [rdi], zmm0
{$ELSE}
    vmovdqu64 zmm0, [rdx]
    vpmaxsd zmm0, zmm0, [r8]   // Signed max
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
