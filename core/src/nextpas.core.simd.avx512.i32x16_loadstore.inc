// === I32x16 Load/Store/Splat/Zero/Select Operations ===

function AVX512LoadI32x16(p: PInt32): TVecI32x16;
var
  pp, pr: Pointer;
begin
  pr := @Result;
  pp := p;

  asm
    mov     rax, pr
    mov     rdx, pp
    vmovdqu64 zmm0, [rdx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

procedure AVX512StoreI32x16(p: PInt32; const a: TVecI32x16);
var
  pp, pa: Pointer;
begin
  pp := p;
  pa := @a;

  asm
    mov     rax, pp
    mov     rdx, pa
    vmovdqu64 zmm0, [rdx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SplatI32x16(value: Int32): TVecI32x16;
var
  pr: Pointer;
begin
  pr := @Result;

  asm
    mov     rax, pr
    vpbroadcastd zmm0, value
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ZeroI32x16: TVecI32x16;
var
  pr: Pointer;
begin
  pr := @Result;

  asm
    mov     rax, pr
    vpxord  zmm0, zmm0, zmm0
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SelectI32x16(const mask: TMask16; const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
  m: Word;
begin
  pr := @Result;
  pa := @a;
  pb := @b;
  m := Word(mask);

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    kmovw   k1, m
    vmovdqu64 zmm0, [rcx]
    vmovdqu64 zmm0 {k1}, [rdx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

