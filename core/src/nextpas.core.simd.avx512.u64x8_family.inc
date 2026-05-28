// === U64x8 Arithmetic/Bitwise/Shift/Comparison (512-bit) ===

function AVX512AddU64x8(const a, b: TVecU64x8): TVecU64x8;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpaddq  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SubU64x8(const a, b: TVecU64x8): TVecU64x8;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpsubq  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512AndU64x8(const a, b: TVecU64x8): TVecU64x8;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpandq  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512OrU64x8(const a, b: TVecU64x8): TVecU64x8;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vporq   zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512XorU64x8(const a, b: TVecU64x8): TVecU64x8;
var
  LPa, LPb, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;
  LPb := @b;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpxorq  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512NotU64x8(const a: TVecU64x8): TVecU64x8;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vpternlogq zmm0, zmm0, zmm0, $55
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ShiftLeftU64x8(const a: TVecU64x8; count: Integer): TVecU64x8;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  if (count < 0) or (count >= 64) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpsllq  zmm0, zmm0, xmm1
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ShiftRightU64x8(const a: TVecU64x8; count: Integer): TVecU64x8;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  if (count < 0) or (count >= 64) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpsrlq  zmm0, zmm0, xmm1
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512CmpEqU64x8(const a, b: TVecU64x8): TMask8;
var
  LPa, LPb: Pointer;
  LMask: Byte;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpeqq k1, zmm0, [rcx]
    kmovb   LMask, k1
    vzeroupper
  end;

  Result := TMask8(LMask);
end;

function AVX512CmpLtU64x8(const a, b: TVecU64x8): TMask8;
var
  LPa, LPb: Pointer;
  LMask: Byte;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpuq k1, zmm0, [rcx], 1
    kmovb   LMask, k1
    vzeroupper
  end;

  Result := TMask8(LMask);
end;

function AVX512CmpGtU64x8(const a, b: TVecU64x8): TMask8;
var
  LPa, LPb: Pointer;
  LMask: Byte;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpuq k1, zmm0, [rcx], 6
    kmovb   LMask, k1
    vzeroupper
  end;

  Result := TMask8(LMask);
end;

function AVX512CmpLeU64x8(const a, b: TVecU64x8): TMask8;
var
  LPa, LPb: Pointer;
  LMask: Byte;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpuq k1, zmm0, [rcx], 2
    kmovb   LMask, k1
    vzeroupper
  end;

  Result := TMask8(LMask);
end;

function AVX512CmpGeU64x8(const a, b: TVecU64x8): TMask8;
var
  LPa, LPb: Pointer;
  LMask: Byte;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpuq k1, zmm0, [rcx], 5
    kmovb   LMask, k1
    vzeroupper
  end;

  Result := TMask8(LMask);
end;

function AVX512CmpNeU64x8(const a, b: TVecU64x8): TMask8;
var
  LPa, LPb: Pointer;
  LMask: Byte;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpuq k1, zmm0, [rcx], 4
    kmovb   LMask, k1
    vzeroupper
  end;

  Result := TMask8(LMask);
end;

