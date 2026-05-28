// === I64x8 Comparison Operations ===

function AVX512CmpEqI64x8(const a, b: TVecI64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpeqq k1, zmm0, [rcx]
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpLtI64x8(const a, b: TVecI64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  // a < b is equivalent to b > a
  asm
    mov     rdx, pb
    mov     rcx, pa
    vmovdqu64 zmm0, [rdx]
    vpcmpgtq k1, zmm0, [rcx]    // b > a
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpGtI64x8(const a, b: TVecI64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpgtq k1, zmm0, [rcx]
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpLeI64x8(const a, b: TVecI64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  // vpcmpq with imm8=2 means LE
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpq  k1, zmm0, [rcx], 2    // imm8=2: LE
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpGeI64x8(const a, b: TVecI64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  // vpcmpq with imm8=5 means GE (NLT)
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpq  k1, zmm0, [rcx], 5    // imm8=5: GE
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpNeI64x8(const a, b: TVecI64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  // vpcmpq with imm8=4 means NE
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpq  k1, zmm0, [rcx], 4    // imm8=4: NE
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

