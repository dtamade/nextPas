// === I32x16 Bitwise Operations ===

function AVX512AndI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a, rdx=@b
    vmovdqu64 zmm0, [rsi]
    vpandd  zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a, r8=@b
    vmovdqu64 zmm0, [rdx]
    vpandd  zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512OrI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovdqu64 zmm0, [rsi]
    vpord   zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    vmovdqu64 zmm0, [rdx]
    vpord   zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512XorI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    vmovdqu64 zmm0, [rsi]
    vpxord  zmm0, zmm0, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    vmovdqu64 zmm0, [rdx]
    vpxord  zmm0, zmm0, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512NotI32x16(const a: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a
    vmovdqu64 zmm0, [rsi]
    vpternlogd zmm0, zmm0, zmm0, $55   // NOT A = ~A
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a
    vmovdqu64 zmm0, [rdx]
    vpternlogd zmm0, zmm0, zmm0, $55   // NOT A = ~A
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512AndNotI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=@a, rdx=@b
    vmovdqu64 zmm0, [rsi]
    vpandnd zmm0, zmm0, [rdx]   // (NOT a) AND b
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=@a, r8=@b
    vmovdqu64 zmm0, [rdx]
    vpandnd zmm0, zmm0, [r8]   // (NOT a) AND b
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
