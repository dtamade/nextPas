// === I32x16 Comparison Operations ===

function AVX512CmpEqI32x16(const a, b: TVecI32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpeqd k1, zmm0, [rcx]
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpLtI32x16(const a, b: TVecI32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // a < b is equivalent to b > a
  asm
    mov     rdx, pb
    mov     rcx, pa
    vmovdqu64 zmm0, [rdx]
    vpcmpgtd k1, zmm0, [rcx]    // b > a
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpGtI32x16(const a, b: TVecI32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpgtd k1, zmm0, [rcx]
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

// ✅ P0-1: 补充缺失的比较函数
function AVX512CmpLeI32x16(const a, b: TVecI32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vpcmpd with imm8=2 means LE (less than or equal)
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpd  k1, zmm0, [rcx], 2    // imm8=2: LE
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpGeI32x16(const a, b: TVecI32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vpcmpd with imm8=5 means NLT (not less than) = GE
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpd  k1, zmm0, [rcx], 5    // imm8=5: GE (NLT)
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpNeI32x16(const a, b: TVecI32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vpcmpd with imm8=4 means NE (not equal)
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu64 zmm0, [rdx]
    vpcmpd  k1, zmm0, [rcx], 4    // imm8=4: NE
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

