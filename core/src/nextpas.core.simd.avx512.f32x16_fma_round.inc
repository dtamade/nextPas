// === F32x16 FMA and Rounding Operations ===

function AVX512FmaF32x16(const a, b, c: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a, rdx=@b, rcx=@c
    vmovups zmm0, [rsi]
    vmovups zmm1, [rdx]
    vmovups zmm2, [rcx]
    vfmadd213ps zmm0, zmm1, zmm2   // a*b+c
    vmovups [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a, r8=@b, r9=@c
    vmovups zmm0, [rdx]
    vmovups zmm1, [r8]
    vmovups zmm2, [r9]
    vfmadd213ps zmm0, zmm1, zmm2   // a*b+c
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512FloorF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a
    vmovups zmm0, [rsi]
    vrndscaleps zmm0, zmm0, 1    // imm8=1: floor (round toward -inf)
    vmovups [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a
    vmovups zmm0, [rdx]
    vrndscaleps zmm0, zmm0, 1
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512CeilF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovups zmm0, [rsi]
    vrndscaleps zmm0, zmm0, 2    // imm8=2: ceil (round toward +inf)
    vmovups [rdi], zmm0
{$ELSE}
    vmovups zmm0, [rdx]
    vrndscaleps zmm0, zmm0, 2
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512RoundF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovups zmm0, [rsi]
    vrndscaleps zmm0, zmm0, 0    // imm8=0: round to nearest even
    vmovups [rdi], zmm0
{$ELSE}
    vmovups zmm0, [rdx]
    vrndscaleps zmm0, zmm0, 0
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512TruncF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovups zmm0, [rsi]
    vrndscaleps zmm0, zmm0, 3    // imm8=3: truncate (round toward zero)
    vmovups [rdi], zmm0
{$ELSE}
    vmovups zmm0, [rdx]
    vrndscaleps zmm0, zmm0, 3
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
