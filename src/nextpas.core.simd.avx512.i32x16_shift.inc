// === I32x16 Shift Operations ===

function AVX512ShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  if (count < 0) or (count >= 32) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpslld  zmm0, zmm0, xmm1
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  if (count < 0) or (count >= 32) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpsrld  zmm0, zmm0, xmm1    // Logical right shift
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var
  pa, pr: Pointer;
  i: Integer;
begin
  pr := @Result;
  pa := @a;

  if count < 0 then
  begin
    Result := a;
    Exit;
  end;

  if count >= 32 then
  begin
    // Arithmetic shift >= 32: result is all 0s or all 1s depending on sign
    for i := 0 to 15 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
    Exit;
  end;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovdqu64 zmm0, [rdx]
    vmovd   xmm1, count
    vpsrad  zmm0, zmm0, xmm1    // Arithmetic right shift
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

