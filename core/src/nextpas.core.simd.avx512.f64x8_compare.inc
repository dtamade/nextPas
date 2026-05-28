// === F64x8 Comparison Operations ===

function AVX512CmpEqF64x8(const a, b: TVecF64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovupd zmm0, [rdx]
    vcmppd  k1, zmm0, [rcx], 0    // imm8=0: EQ
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpLtF64x8(const a, b: TVecF64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovupd zmm0, [rdx]
    vcmppd  k1, zmm0, [rcx], 1    // imm8=1: LT
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpLeF64x8(const a, b: TVecF64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovupd zmm0, [rdx]
    vcmppd  k1, zmm0, [rcx], 2    // imm8=2: LE
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpGtF64x8(const a, b: TVecF64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovupd zmm0, [rdx]
    vcmppd  k1, zmm0, [rcx], 14   // imm8=14: GT (NLE)
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpGeF64x8(const a, b: TVecF64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovupd zmm0, [rdx]
    vcmppd  k1, zmm0, [rcx], 13   // imm8=13: GE (NLT)
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

function AVX512CmpNeF64x8(const a, b: TVecF64x8): TMask8;
var
  pa, pb: Pointer;
  mask: Byte;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovupd zmm0, [rdx]
    vcmppd  k1, zmm0, [rcx], 4    // imm8=4: NEQ
    kmovb   mask, k1
    vzeroupper
  end;

  Result := TMask8(mask);
end;

