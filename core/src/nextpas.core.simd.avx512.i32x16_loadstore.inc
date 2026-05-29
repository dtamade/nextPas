// === I32x16 Load/Store/Splat/Zero/Select Operations ===

function AVX512LoadI32x16(p: PInt32): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=p
    vmovdqu64 zmm0, [rsi]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=p
    vmovdqu64 zmm0, [rdx]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

procedure AVX512StoreI32x16(p: PInt32; const a: TVecI32x16); assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=p, rsi=@a
    vmovdqu64 zmm0, [rsi]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=p, rdx=@a
    vmovdqu64 zmm0, [rdx]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512SplatI32x16(value: Int32): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, esi=value
    vmovd   xmm0, esi
    vpbroadcastd zmm0, xmm0
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, edx=value
    vmovd   xmm0, edx
    vpbroadcastd zmm0, xmm0
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512ZeroI32x16: TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result
    vpxord  zmm0, zmm0, zmm0
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result
    vpxord  zmm0, zmm0, zmm0
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512SelectI32x16(const mask: TMask16; const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, esi=mask, rdx=@a, rcx=@b
    kmovw   k1, esi
    vmovdqu64 zmm0, [rcx]
    vmovdqu64 zmm0 {k1}, [rdx]
    vmovdqu64 [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, edx=mask, r8=@a, r9=@b
    kmovw   k1, edx
    vmovdqu64 zmm0, [r9]
    vmovdqu64 zmm0 {k1}, [r8]
    vmovdqu64 [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
