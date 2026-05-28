// === F32x8 Comparison Operations (256-bit AVX) ===

function AVX2CmpEqF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovups  ymm0, [rax]
    // vcmpps ymm0, ymm0, [rdx], 0  (imm8=0: EQ_OQ)
    db $C5, $FC, $C2, $02, $00
    vmovmskps eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask8(mask);
end;

function AVX2CmpLtF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovups  ymm0, [rax]
    // vcmpps ymm0, ymm0, [rdx], 1  (imm8=1: LT_OS)
    db $C5, $FC, $C2, $02, $01
    vmovmskps eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask8(mask);
end;

function AVX2CmpLeF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovups  ymm0, [rax]
    // vcmpps ymm0, ymm0, [rdx], 2  (imm8=2: LE_OS)
    db $C5, $FC, $C2, $02, $02
    vmovmskps eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask8(mask);
end;

function AVX2CmpGtF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  // GT = swap operands and use LT (b < a)
  pa := @b;
  pb := @a;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovups  ymm0, [rax]
    // vcmpps ymm0, ymm0, [rdx], 1  (imm8=1: LT_OS)
    db $C5, $FC, $C2, $02, $01
    vmovmskps eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask8(mask);
end;

function AVX2CmpGeF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  // GE = swap operands and use LE (b <= a)
  pa := @b;
  pb := @a;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovups  ymm0, [rax]
    // vcmpps ymm0, ymm0, [rdx], 2  (imm8=2: LE_OS)
    db $C5, $FC, $C2, $02, $02
    vmovmskps eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask8(mask);
end;

function AVX2CmpNeF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovups  ymm0, [rax]
    // vcmpps ymm0, ymm0, [rdx], 4  (imm8=4: NEQ_UQ)
    db $C5, $FC, $C2, $02, $04
    vmovmskps eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask8(mask);
end;

