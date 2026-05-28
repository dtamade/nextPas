// === U32x16 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit) ===

function AVX512AddU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpaddd  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SubU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpsubd  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MulU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpmulld zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512AndU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpandd  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512OrU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpord   zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512XorU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpxord  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512NotU32x16(const a: TVecU32x16): TVecU32x16;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vpternlogd zmm0, zmm0, zmm0, $55
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512AndNotU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpandnd zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ShiftLeftU32x16(const a: TVecU32x16; count: Integer): TVecU32x16;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  if (count < 0) or (count >= 32) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpslld  zmm0, zmm0, xmm1
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ShiftRightU32x16(const a: TVecU32x16; count: Integer): TVecU32x16;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  if (count < 0) or (count >= 32) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpsrld  zmm0, zmm0, xmm1
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512CmpEqU32x16(const a, b: TVecU32x16): TMask16;
var
  LPa, LPb: Pointer;
  LMask: Word;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpeqd k1, zmm0, [rcx]
    kmovw   LMask, k1
    vzeroupper
  end;

  Result := TMask16(LMask);
end;

function AVX512CmpLtU32x16(const a, b: TVecU32x16): TMask16;
var
  LPa, LPb: Pointer;
  LMask: Word;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpud k1, zmm0, [rcx], 1
    kmovw   LMask, k1
    vzeroupper
  end;

  Result := TMask16(LMask);
end;

function AVX512CmpGtU32x16(const a, b: TVecU32x16): TMask16;
var
  LPa, LPb: Pointer;
  LMask: Word;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpud k1, zmm0, [rcx], 6
    kmovw   LMask, k1
    vzeroupper
  end;

  Result := TMask16(LMask);
end;

function AVX512CmpLeU32x16(const a, b: TVecU32x16): TMask16;
var
  LPa, LPb: Pointer;
  LMask: Word;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpud k1, zmm0, [rcx], 2
    kmovw   LMask, k1
    vzeroupper
  end;

  Result := TMask16(LMask);
end;

function AVX512CmpGeU32x16(const a, b: TVecU32x16): TMask16;
var
  LPa, LPb: Pointer;
  LMask: Word;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpud k1, zmm0, [rcx], 5
    kmovw   LMask, k1
    vzeroupper
  end;

  Result := TMask16(LMask);
end;

function AVX512CmpNeU32x16(const a, b: TVecU32x16): TMask16;
var
  LPa, LPb: Pointer;
  LMask: Word;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpud k1, zmm0, [rcx], 4
    kmovw   LMask, k1
    vzeroupper
  end;

  Result := TMask16(LMask);
end;

function AVX512MinU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpminud zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MaxU32x16(const a, b: TVecU32x16): TVecU32x16;
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
    vpmaxud zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

