// === 512-bit Load/Store/Splat/Zero/Select ===

// F32x16
function AVX512LoadF32x16(p: PSingle): TVecF32x16;
var
  pp, pr: Pointer;
begin
  pr := @Result;
  pp := p;

  asm
    mov     rax, pr
    mov     rdx, pp
    vmovups zmm0, [rdx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

procedure AVX512StoreF32x16(p: PSingle; const a: TVecF32x16);
var
  pp, pa: Pointer;
begin
  pp := p;
  pa := @a;

  asm
    mov     rax, pp
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SplatF32x16(value: Single): TVecF32x16;
var
  pr: Pointer;
  v: Single;
begin
  pr := @Result;
  v := value;

  asm
    mov     rax, pr
    vbroadcastss zmm0, v
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ZeroF32x16: TVecF32x16;
var
  pr: Pointer;
begin
  pr := @Result;

  asm
    mov     rax, pr
    vxorps  zmm0, zmm0, zmm0
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
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
    vmovups zmm0, [rcx]
    vmovups zmm0 {k1}, [rdx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

// F64x8
function AVX512LoadF64x8(p: PDouble): TVecF64x8;
var
  pp, pr: Pointer;
begin
  pr := @Result;
  pp := p;

  asm
    mov     rax, pr
    mov     rdx, pp
    vmovupd zmm0, [rdx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

procedure AVX512StoreF64x8(p: PDouble; const a: TVecF64x8);
var
  pp, pa: Pointer;
begin
  pp := p;
  pa := @a;

  asm
    mov     rax, pp
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SplatF64x8(value: Double): TVecF64x8;
var
  pr: Pointer;
  v: Double;
begin
  pr := @Result;
  v := value;

  asm
    mov     rax, pr
    vbroadcastsd zmm0, v
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ZeroF64x8: TVecF64x8;
var
  pr: Pointer;
begin
  pr := @Result;

  asm
    mov     rax, pr
    vxorpd  zmm0, zmm0, zmm0
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
var
  pa, pb, pr: Pointer;
  m: Byte;
begin
  pr := @Result;
  pa := @a;
  pb := @b;
  m := Byte(mask);

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    kmovb   k1, m
    vmovupd zmm0, [rcx]
    vmovupd zmm0 {k1}, [rdx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

