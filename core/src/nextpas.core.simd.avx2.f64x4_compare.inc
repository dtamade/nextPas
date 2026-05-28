// === F64x4 Comparison Operations (256-bit AVX) ===

function AVX2CmpEqF64x4(const a, b: TVecF64x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovupd  ymm0, [rax]
    // vcmppd ymm0, ymm0, [rdx], 0  (imm8=0: EQ_OQ)
    db $C5, $FD, $C2, $02, $00
    vmovmskpd eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask4(mask);
end;

function AVX2CmpLtF64x4(const a, b: TVecF64x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovupd  ymm0, [rax]
    // vcmppd ymm0, ymm0, [rdx], 1  (imm8=1: LT_OS)
    db $C5, $FD, $C2, $02, $01
    vmovmskpd eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask4(mask);
end;

function AVX2CmpLeF64x4(const a, b: TVecF64x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovupd  ymm0, [rax]
    // vcmppd ymm0, ymm0, [rdx], 2  (imm8=2: LE_OS)
    db $C5, $FD, $C2, $02, $02
    vmovmskpd eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask4(mask);
end;

function AVX2CmpGtF64x4(const a, b: TVecF64x4): TMask4;
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
    vmovupd  ymm0, [rax]
    // vcmppd ymm0, ymm0, [rdx], 1  (imm8=1: LT_OS)
    db $C5, $FD, $C2, $02, $01
    vmovmskpd eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask4(mask);
end;

function AVX2CmpGeF64x4(const a, b: TVecF64x4): TMask4;
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
    vmovupd  ymm0, [rax]
    // vcmppd ymm0, ymm0, [rdx], 2  (imm8=2: LE_OS)
    db $C5, $FD, $C2, $02, $02
    vmovmskpd eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask4(mask);
end;

function AVX2CmpNeF64x4(const a, b: TVecF64x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovupd  ymm0, [rax]
    // vcmppd ymm0, ymm0, [rdx], 4  (imm8=4: NEQ_UQ)
    db $C5, $FD, $C2, $02, $04
    vmovmskpd eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := TMask4(mask);
end;

