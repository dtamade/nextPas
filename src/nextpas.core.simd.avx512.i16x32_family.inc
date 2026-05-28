// === I16x32 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit) ===

function AVX512AddI16x32(const a, b: TVecI16x32): TVecI16x32;
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
    vpaddw  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SubI16x32(const a, b: TVecI16x32): TVecI16x32;
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
    vpsubw  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512AndI16x32(const a, b: TVecI16x32): TVecI16x32;
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

function AVX512OrI16x32(const a, b: TVecI16x32): TVecI16x32;
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

function AVX512XorI16x32(const a, b: TVecI16x32): TVecI16x32;
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

function AVX512NotI16x32(const a: TVecI16x32): TVecI16x32;
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

function AVX512AndNotI16x32(const a, b: TVecI16x32): TVecI16x32;
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

function AVX512ShiftLeftI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  if (count < 0) or (count >= 16) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpsllw  zmm0, zmm0, xmm1
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ShiftRightI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LPa, LPr: Pointer;
begin
  LPr := @Result;
  LPa := @a;

  if (count < 0) or (count >= 16) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpsrlw  zmm0, zmm0, xmm1
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ShiftRightArithI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var
  LPa, LPr: Pointer;
  LIndex: Integer;
begin
  LPr := @Result;
  LPa := @a;

  if count < 0 then
  begin
    Result := a;
    Exit;
  end;

  if count >= 16 then
  begin
    for LIndex := 0 to 31 do
      if a.i[LIndex] < 0 then
        Result.i[LIndex] := -1
      else
        Result.i[LIndex] := 0;
    Exit;
  end;

  asm
    mov     rax, LPr
    mov     rdx, LPa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpsraw  zmm0, zmm0, xmm1
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512CmpEqI16x32(const a, b: TVecI16x32): TMask32;
var
  LPa, LPb: Pointer;
  LMask: DWord;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpeqw k1, zmm0, [rcx]
    kmovd   LMask, k1
    vzeroupper
  end;

  Result := TMask32(LMask);
end;

function AVX512CmpLtI16x32(const a, b: TVecI16x32): TMask32;
var
  LPa, LPb: Pointer;
  LMask: DWord;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpw  k1, zmm0, [rcx], 1
    kmovd   LMask, k1
    vzeroupper
  end;

  Result := TMask32(LMask);
end;

function AVX512CmpGtI16x32(const a, b: TVecI16x32): TMask32;
var
  LPa, LPb: Pointer;
  LMask: DWord;
begin
  LPa := @a;
  LPb := @b;

  asm
    mov     rdx, LPa
    mov     rcx, LPb
    vmovdqu64 zmm0, [rdx]
    vpcmpw  k1, zmm0, [rcx], 6
    kmovd   LMask, k1
    vzeroupper
  end;

  Result := TMask32(LMask);
end;

function AVX512MinI16x32(const a, b: TVecI16x32): TVecI16x32;
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
    vpminsw zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MaxI16x32(const a, b: TVecI16x32): TVecI16x32;
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
    vpmaxsw zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

