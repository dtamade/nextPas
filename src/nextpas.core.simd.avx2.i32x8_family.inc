// === AVX2 256-bit Dword Shared Kernels ===
// These operations have the same bit-pattern contract for I32x8 and U32x8.

procedure AVX2AddDwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpaddd  ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2SubDwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpsubd  ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2MulDwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpmulld ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2AndDwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpand   ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2OrDwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpor    ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2XorDwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpxor   ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2NotDwordVecRaw256(const aValuePtr, aResultPtr: Pointer);
var
  LValuePtr, LResultPtr: Pointer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;

  asm
    mov      rax, LValuePtr
    mov      rdx, LResultPtr
    vpcmpeqd ymm1, ymm1, ymm1
    vmovdqu  ymm0, [rax]
    vpxor    ymm0, ymm0, ymm1
    vmovdqu  [rdx], ymm0
    vzeroupper
  end;
end;

procedure AVX2AndNotDwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpandn  ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2ShiftLeftDwordVecRaw256(const aValuePtr, aResultPtr: Pointer; aCount: Integer);
var
  LValuePtr, LResultPtr: Pointer;
  LCount: Integer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;
  LCount := aCount;

  if (LCount < 0) or (LCount >= 32) then
  begin
    FillChar(PByte(LResultPtr)^, SizeOf(TVecI32x8), 0);
    Exit;
  end;

  asm
    mov     rax, LValuePtr
    mov     rdx, LResultPtr
    vmovdqu ymm0, [rax]
    mov     ecx, LCount
    vmovd   xmm1, ecx
    vpslld  ymm0, ymm0, xmm1
    vmovdqu [rdx], ymm0
    vzeroupper
  end;
end;

procedure AVX2ShiftRightDwordVecRaw256(const aValuePtr, aResultPtr: Pointer; aCount: Integer);
var
  LValuePtr, LResultPtr: Pointer;
  LCount: Integer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;
  LCount := aCount;

  if (LCount < 0) or (LCount >= 32) then
  begin
    FillChar(PByte(LResultPtr)^, SizeOf(TVecI32x8), 0);
    Exit;
  end;

  asm
    mov     rax, LValuePtr
    mov     rdx, LResultPtr
    vmovdqu ymm0, [rax]
    mov     ecx, LCount
    vmovd   xmm1, ecx
    vpsrld  ymm0, ymm0, xmm1
    vmovdqu [rdx], ymm0
    vzeroupper
  end;
end;

procedure AVX2AddQwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpaddq  ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2SubQwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpsubq  ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2AndQwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpand   ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2OrQwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpor    ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2XorQwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpxor   ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2NotQwordVecRaw256(const aValuePtr, aResultPtr: Pointer);
var
  LValuePtr, LResultPtr: Pointer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;

  asm
    mov      rax, LValuePtr
    mov      rdx, LResultPtr
    vpcmpeqd ymm1, ymm1, ymm1
    vmovdqu  ymm0, [rax]
    vpxor    ymm0, ymm0, ymm1
    vmovdqu  [rdx], ymm0
    vzeroupper
  end;
end;

procedure AVX2AndNotQwordVecRaw256(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;

  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu ymm0, [rax]
    vpandn  ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vzeroupper
  end;
end;

procedure AVX2ShiftLeftQwordVecRaw256(const aValuePtr, aResultPtr: Pointer; aCount: Integer);
var
  LValuePtr, LResultPtr: Pointer;
  LCount: Integer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;
  LCount := aCount;

  if (LCount < 0) or (LCount >= 64) then
  begin
    FillChar(PByte(LResultPtr)^, SizeOf(TVecI64x4), 0);
    Exit;
  end;

  asm
    mov     rax, LValuePtr
    mov     rdx, LResultPtr
    vmovdqu ymm0, [rax]
    mov     ecx, LCount
    vmovd   xmm1, ecx
    vpsllq  ymm0, ymm0, xmm1
    vmovdqu [rdx], ymm0
    vzeroupper
  end;
end;

procedure AVX2ShiftRightQwordVecRaw256(const aValuePtr, aResultPtr: Pointer; aCount: Integer);
var
  LValuePtr, LResultPtr: Pointer;
  LCount: Integer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;
  LCount := aCount;

  if (LCount < 0) or (LCount >= 64) then
  begin
    FillChar(PByte(LResultPtr)^, SizeOf(TVecI64x4), 0);
    Exit;
  end;

  asm
    mov     rax, LValuePtr
    mov     rdx, LResultPtr
    vmovdqu ymm0, [rax]
    mov     ecx, LCount
    vmovd   xmm1, ecx
    vpsrlq  ymm0, ymm0, xmm1
    vmovdqu [rdx], ymm0
    vzeroupper
  end;
end;

// === I32x8 Operations (native 256-bit AVX2) ===

function AVX2AddI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  AVX2AddDwordVecRaw256(@a, @b, @Result);
end;

function AVX2SubI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  AVX2SubDwordVecRaw256(@a, @b, @Result);
end;

function AVX2MulI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  AVX2MulDwordVecRaw256(@a, @b, @Result);
end;

// I32x8 Bitwise Operations

function AVX2AndI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  AVX2AndDwordVecRaw256(@a, @b, @Result);
end;

function AVX2OrI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  AVX2OrDwordVecRaw256(@a, @b, @Result);
end;

function AVX2XorI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  AVX2XorDwordVecRaw256(@a, @b, @Result);
end;

function AVX2NotI32x8(const a: TVecI32x8): TVecI32x8;
begin
  AVX2NotDwordVecRaw256(@a, @Result);
end;

function AVX2AndNotI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  AVX2AndNotDwordVecRaw256(@a, @b, @Result);
end;

// I32x8 Shift Operations

function AVX2ShiftLeftI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  AVX2ShiftLeftDwordVecRaw256(@a, @Result, count);
end;

function AVX2ShiftRightI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  AVX2ShiftRightDwordVecRaw256(@a, @Result, count);
end;

function AVX2ShiftRightArithI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
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
    for i := 0 to 7 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
    Exit;
  end;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovdqu ymm0, [rdx]
    mov     ecx, count
    vmovd   xmm1, ecx
    vpsrad  ymm0, ymm0, xmm1    // Arithmetic right shift
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;

// I32x8 Comparison Operations

function AVX2CmpGtI32x8(const a, b: TVecI32x8): TMask8; forward;

function AVX2CmpEqI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := TMask8(AVX2CmpEqDwordMaskRaw256(@a, @b));
end;

function AVX2CmpLtI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := AVX2CmpGtI32x8(b, a);
end;

function AVX2CmpGtI32x8(const a, b: TVecI32x8): TMask8;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vpcmpgtd ymm0, ymm0, [rcx]
    vmovmskps eax, ymm0
    mov     mask, eax
    vzeroupper
  end;

  Result := TMask8(mask);
end;

// ✅ P0-2: 补充缺失的比较函数
function AVX2CmpLeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpGtI32x8(a, b));
end;

function AVX2CmpGeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpGtI32x8(b, a));
end;

function AVX2CmpNeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpEqDwordMaskRaw256(@a, @b));
end;

// I32x8 Min/Max Operations

function AVX2MinI32x8(const a, b: TVecI32x8): TVecI32x8;
var
  pa, pb, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  pb := @b;

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vpminsd ymm0, ymm0, [rcx]   // Signed min
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;

function AVX2MaxI32x8(const a, b: TVecI32x8): TVecI32x8;
var
  pa, pb, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  pb := @b;

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vpmaxsd ymm0, ymm0, [rcx]   // Signed max
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;
