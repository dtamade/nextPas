// === F64x8 FMA and Rounding Operations ===

function AVX512FmaF64x8(const a, b, c: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a, rdx=@b, rcx=@c
    vmovupd zmm0, [rsi]
    vmovupd zmm1, [rdx]
    vmovupd zmm2, [rcx]
    vfmadd213pd zmm0, zmm1, zmm2
    vmovupd [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a, r8=@b, r9=@c
    vmovupd zmm0, [rdx]
    vmovupd zmm1, [r8]
    vmovupd zmm2, [r9]
    vfmadd213pd zmm0, zmm1, zmm2
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512FloorF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a
    vmovupd zmm0, [rsi]
    vrndscalepd zmm0, zmm0, 1
    vmovupd [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a
    vmovupd zmm0, [rdx]
    vrndscalepd zmm0, zmm0, 1
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512CeilF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovupd zmm0, [rsi]
    vrndscalepd zmm0, zmm0, 2
    vmovupd [rdi], zmm0
{$ELSE}
    vmovupd zmm0, [rdx]
    vrndscalepd zmm0, zmm0, 2
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512RoundF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovupd zmm0, [rsi]
    vrndscalepd zmm0, zmm0, 0
    vmovupd [rdi], zmm0
{$ELSE}
    vmovupd zmm0, [rdx]
    vrndscalepd zmm0, zmm0, 0
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512TruncF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovupd zmm0, [rsi]
    vrndscalepd zmm0, zmm0, 3
    vmovupd [rdi], zmm0
{$ELSE}
    vmovupd zmm0, [rdx]
    vrndscalepd zmm0, zmm0, 3
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
