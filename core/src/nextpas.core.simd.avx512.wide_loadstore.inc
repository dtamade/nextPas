// === 512-bit Load/Store/Splat/Zero/Select ===

// F32x16
function AVX512LoadF32x16(p: PSingle): TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=p
    vmovups zmm0, [rsi]
    vmovups [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=p
    vmovups zmm0, [rdx]
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

procedure AVX512StoreF32x16(p: PSingle; const a: TVecF32x16); assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=p, rsi=@a
    vmovups zmm0, [rsi]
    vmovups [rdi], zmm0
{$ELSE}
    // Win64: rcx=p, rdx=@a
    vmovups zmm0, [rdx]
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512SplatF32x16(value: Single): TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, xmm0=value
    vbroadcastss zmm0, xmm0
    vmovups [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, xmm1=value
    vbroadcastss zmm0, xmm1
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512ZeroF32x16: TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result
    vxorps  zmm0, zmm0, zmm0
    vmovups [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result
    vxorps  zmm0, zmm0, zmm0
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512SelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, esi=mask, rdx=@a, rcx=@b
    kmovw   k1, esi
    vmovups zmm0, [rcx]
    vmovups zmm0 {k1}, [rdx]
    vmovups [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, edx=mask, r8=@a, r9=@b
    kmovw   k1, edx
    vmovups zmm0, [r9]
    vmovups zmm0 {k1}, [r8]
    vmovups [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

// F64x8
function AVX512LoadF64x8(p: PDouble): TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, rsi=p
    vmovupd zmm0, [rsi]
    vmovupd [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, rdx=p
    vmovupd zmm0, [rdx]
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

procedure AVX512StoreF64x8(p: PDouble; const a: TVecF64x8); assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=p, rsi=@a
    vmovupd zmm0, [rsi]
    vmovupd [rdi], zmm0
{$ELSE}
    // Win64: rcx=p, rdx=@a
    vmovupd zmm0, [rdx]
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512SplatF64x8(value: Double): TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, xmm0=value
    vbroadcastsd zmm0, xmm0
    vmovupd [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, xmm1=value
    vbroadcastsd zmm0, xmm1
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512ZeroF64x8: TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result
    vxorpd  zmm0, zmm0, zmm0
    vmovupd [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result
    vxorpd  zmm0, zmm0, zmm0
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;

function AVX512SelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
{$IFDEF UNIX}
    // SysV: rdi=@Result, esi=mask, rdx=@a, rcx=@b
    kmovb   k1, esi
    vmovupd zmm0, [rcx]
    vmovupd zmm0 {k1}, [rdx]
    vmovupd [rdi], zmm0
{$ELSE}
    // Win64: rcx=@Result, edx=mask, r8=@a, r9=@b
    kmovb   k1, edx
    vmovupd zmm0, [r9]
    vmovupd zmm0 {k1}, [r8]
    vmovupd [rcx], zmm0
{$ENDIF}
    vzeroupper
end;
