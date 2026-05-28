// === F32x16 Comparison Operations ===

function AVX512CmpEqF32x16(const a, b: TVecF32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vcmpps with imm8=0 means EQ
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovups zmm0, [rdx]
    vcmpps  k1, zmm0, [rcx], 0    // imm8=0: EQ
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpLtF32x16(const a, b: TVecF32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vcmpps with imm8=1 means LT
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovups zmm0, [rdx]
    vcmpps  k1, zmm0, [rcx], 1    // imm8=1: LT
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpLeF32x16(const a, b: TVecF32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vcmpps with imm8=2 means LE
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovups zmm0, [rdx]
    vcmpps  k1, zmm0, [rcx], 2    // imm8=2: LE
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpGtF32x16(const a, b: TVecF32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vcmpps with imm8=14 means GT (NLE)
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovups zmm0, [rdx]
    vcmpps  k1, zmm0, [rcx], 14   // imm8=14: GT (NLE)
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpGeF32x16(const a, b: TVecF32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vcmpps with imm8=13 means GE (NLT)
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovups zmm0, [rdx]
    vcmpps  k1, zmm0, [rcx], 13   // imm8=13: GE (NLT)
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

function AVX512CmpNeF32x16(const a, b: TVecF32x16): TMask16;
var
  pa, pb: Pointer;
  mask: Word;
begin
  pa := @a;
  pb := @b;

  // vcmpps with imm8=4 means NE (unordered)
  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovups zmm0, [rdx]
    vcmpps  k1, zmm0, [rcx], 4    // imm8=4: NEQ
    kmovw   mask, k1
    vzeroupper
  end;

  Result := TMask16(mask);
end;

