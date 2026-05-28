// ============================================================================
// 512-bit 向量的 SSE2 渐进降级实现 (2026-02-05)
// Performance tier — provides 4×128-bit emulation when AVX2/AVX-512 unavailable.
// 策略: 使用 2×256-bit 操作 (利用已有的 F32x8/F64x4/I32x8)
// NOTE: Performance tier — provides 4×128-bit emulation when AVX2 unavailable.
//       Not dead code; coexists with AVX2 wide_emulation (2×256) and scalar.
// ============================================================================

// === F32x16 操作 (16×Float32) - 使用 2×F32x8 ===

// 4×128-bit SSE2 ASM 实现 (Add)
function SSE2AddF32x16(const a, b: TVecF32x16): TVecF32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    // Load 4 chunks of 128-bit from a
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    // Load 4 chunks of 128-bit from b
    movups xmm4, [rdx]
    movups xmm5, [rdx+16]
    movups xmm6, [rdx+32]
    movups xmm7, [rdx+48]
    // Add
    addps  xmm0, xmm4
    addps  xmm1, xmm5
    addps  xmm2, xmm6
    addps  xmm3, xmm7
    // Store result
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (Sub)
function SSE2SubF32x16(const a, b: TVecF32x16): TVecF32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    movups xmm4, [rdx]
    movups xmm5, [rdx+16]
    movups xmm6, [rdx+32]
    movups xmm7, [rdx+48]
    // Subtract
    subps  xmm0, xmm4
    subps  xmm1, xmm5
    subps  xmm2, xmm6
    subps  xmm3, xmm7
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (Mul)
function SSE2MulF32x16(const a, b: TVecF32x16): TVecF32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    movups xmm4, [rdx]
    movups xmm5, [rdx+16]
    movups xmm6, [rdx+32]
    movups xmm7, [rdx+48]
    // Multiply
    mulps  xmm0, xmm4
    mulps  xmm1, xmm5
    mulps  xmm2, xmm6
    mulps  xmm3, xmm7
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (Div)
function SSE2DivF32x16(const a, b: TVecF32x16): TVecF32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    movups xmm4, [rdx]
    movups xmm5, [rdx+16]
    movups xmm6, [rdx+32]
    movups xmm7, [rdx+48]
    // Divide
    divps  xmm0, xmm4
    divps  xmm1, xmm5
    divps  xmm2, xmm6
    divps  xmm3, xmm7
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (Abs)
function SSE2AbsF32x16(const a: TVecF32x16): TVecF32x16;
const
  AbsMask: array[0..3] of UInt32 = ($7FFFFFFF, $7FFFFFFF, $7FFFFFFF, $7FFFFFFF);
var
  pa, pr, pmask: Pointer;
begin
  pa := @a;
  pr := @Result;
  pmask := @AbsMask;
  asm
    mov    rax, pa
    mov    rcx, pr
    mov    rdx, pmask
    // Load abs mask (clears sign bit)
    movups xmm4, [rdx]
    // Load 4 chunks
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    // Apply abs mask (bitwise AND)
    andps  xmm0, xmm4
    andps  xmm1, xmm4
    andps  xmm2, xmm4
    andps  xmm3, xmm4
    // Store result
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (Sqrt)
function SSE2SqrtF32x16(const a: TVecF32x16): TVecF32x16;
var
  pa, pr: Pointer;
begin
  pa := @a;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    // Square root
    sqrtps xmm0, xmm0
    sqrtps xmm1, xmm1
    sqrtps xmm2, xmm2
    sqrtps xmm3, xmm3
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (Min)
function SSE2MinF32x16(const a, b: TVecF32x16): TVecF32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    movups xmm4, [rdx]
    movups xmm5, [rdx+16]
    movups xmm6, [rdx+32]
    movups xmm7, [rdx+48]
    // Min
    minps  xmm0, xmm4
    minps  xmm1, xmm5
    minps  xmm2, xmm6
    minps  xmm3, xmm7
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (Max)
function SSE2MaxF32x16(const a, b: TVecF32x16): TVecF32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    movups xmm4, [rdx]
    movups xmm5, [rdx+16]
    movups xmm6, [rdx+32]
    movups xmm7, [rdx+48]
    // Max
    maxps  xmm0, xmm4
    maxps  xmm1, xmm5
    maxps  xmm2, xmm6
    maxps  xmm3, xmm7
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (FMA: a*b+c)
function SSE2FmaF32x16(const a, b, c: TVecF32x16): TVecF32x16;
var
  pa, pb, pc, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pc := @c;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    r8,  pc
    mov    rcx, pr
    // Load a (4×128-bit)
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    // Load b (4×128-bit)
    movups xmm4, [rdx]
    movups xmm5, [rdx+16]
    movups xmm6, [rdx+32]
    movups xmm7, [rdx+48]
    // Multiply a * b
    mulps  xmm0, xmm4
    mulps  xmm1, xmm5
    mulps  xmm2, xmm6
    mulps  xmm3, xmm7
    // Load c (4×128-bit)
    movups xmm4, [r8]
    movups xmm5, [r8+16]
    movups xmm6, [r8+32]
    movups xmm7, [r8+48]
    // Add c
    addps  xmm0, xmm4
    addps  xmm1, xmm5
    addps  xmm2, xmm6
    addps  xmm3, xmm7
    // Store result
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

function SSE2FloorF32x16(const a: TVecF32x16): TVecF32x16;
begin
  Result.lo := SSE2FloorF32x8(a.lo);
  Result.hi := SSE2FloorF32x8(a.hi);
end;

function SSE2CeilF32x16(const a: TVecF32x16): TVecF32x16;
begin
  Result.lo := SSE2CeilF32x8(a.lo);
  Result.hi := SSE2CeilF32x8(a.hi);
end;

function SSE2RoundF32x16(const a: TVecF32x16): TVecF32x16;
begin
  Result.lo := SSE2RoundF32x8(a.lo);
  Result.hi := SSE2RoundF32x8(a.hi);
end;

function SSE2TruncF32x16(const a: TVecF32x16): TVecF32x16;
begin
  Result.lo := SSE2TruncF32x8(a.lo);
  Result.hi := SSE2TruncF32x8(a.hi);
end;

// 4×128-bit SSE2 ASM 实现 (Clamp: 限制在 [minVal, maxVal] 范围)
function SSE2ClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
var
  pa, pmin, pmax, pr: Pointer;
begin
  pa := @a;
  pmin := @minVal;
  pmax := @maxVal;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pmin
    mov    r8,  pmax
    mov    rcx, pr
    // Load a (4×128-bit)
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rax+32]
    movups xmm3, [rax+48]
    // Load minVal (4×128-bit)
    movups xmm4, [rdx]
    movups xmm5, [rdx+16]
    movups xmm6, [rdx+32]
    movups xmm7, [rdx+48]
    // Max with minVal
    maxps  xmm0, xmm4
    maxps  xmm1, xmm5
    maxps  xmm2, xmm6
    maxps  xmm3, xmm7
    // Load maxVal (4×128-bit)
    movups xmm4, [r8]
    movups xmm5, [r8+16]
    movups xmm6, [r8+32]
    movups xmm7, [r8+48]
    // Min with maxVal
    minps  xmm0, xmm4
    minps  xmm1, xmm5
    minps  xmm2, xmm6
    minps  xmm3, xmm7
    // Store results
    movups [rcx], xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
  end;
end;

function SSE2ReduceAddF32x16(const a: TVecF32x16): Single;
begin
  Result := SSE2ReduceAddF32x8(a.lo) + SSE2ReduceAddF32x8(a.hi);
end;

function SSE2ReduceMinF32x16(const a: TVecF32x16): Single;
var
  minLo, minHi: Single;
begin
  minLo := SSE2ReduceMinF32x8(a.lo);
  minHi := SSE2ReduceMinF32x8(a.hi);
  if minLo < minHi then
    Result := minLo
  else
    Result := minHi;
end;

function SSE2ReduceMaxF32x16(const a: TVecF32x16): Single;
var
  maxLo, maxHi: Single;
begin
  maxLo := SSE2ReduceMaxF32x8(a.lo);
  maxHi := SSE2ReduceMaxF32x8(a.hi);
  if maxLo > maxHi then
    Result := maxLo
  else
    Result := maxHi;
end;

function SSE2ReduceMulF32x16(const a: TVecF32x16): Single;
begin
  Result := SSE2ReduceMulF32x8(a.lo) * SSE2ReduceMulF32x8(a.hi);
end;

function SSE2LoadF32x16(p: PSingle): TVecF32x16;
begin
  Result.lo := SSE2LoadF32x8(p);
  Result.hi := SSE2LoadF32x8(p + 8);
end;

procedure SSE2StoreF32x16(p: PSingle; const a: TVecF32x16);
begin
  SSE2StoreF32x8(p, a.lo);
  SSE2StoreF32x8(p + 8, a.hi);
end;

function SSE2SplatF32x16(value: Single): TVecF32x16;
begin
  Result.lo := SSE2SplatF32x8(value);
  Result.hi := SSE2SplatF32x8(value);
end;

function SSE2ZeroF32x16: TVecF32x16;
begin
  Result.lo := SSE2ZeroF32x8;
  Result.hi := SSE2ZeroF32x8;
end;

function SSE2CmpEqF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] = b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpLtF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] < b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpLeF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] <= b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpGtF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] > b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpGeF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] >= b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpNeF32x16(const a, b: TVecF32x16): TMask16;
var
  i: Integer;
  mask: Word;
begin
  mask := 0;
  for i := 0 to 15 do
  begin
    if a.f[i] <> b.f[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2SelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
  begin
    if (mask and (1 shl i)) <> 0 then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := b.f[i];
  end;
end;

// === F64x8 操作 (8×Float64) - 使用 2×F64x4 ===

// 4×128-bit SSE2 ASM 实现 (F64x8 Add)
function SSE2AddF64x8(const a, b: TVecF64x8): TVecF64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    // Load 4 chunks of 128-bit from a (each holds 2 doubles)
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    // Load 4 chunks of 128-bit from b
    movupd xmm4, [rdx]
    movupd xmm5, [rdx+16]
    movupd xmm6, [rdx+32]
    movupd xmm7, [rdx+48]
    // Add (packed double)
    addpd  xmm0, xmm4
    addpd  xmm1, xmm5
    addpd  xmm2, xmm6
    addpd  xmm3, xmm7
    // Store result
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 Sub)
function SSE2SubF64x8(const a, b: TVecF64x8): TVecF64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    movupd xmm4, [rdx]
    movupd xmm5, [rdx+16]
    movupd xmm6, [rdx+32]
    movupd xmm7, [rdx+48]
    // Subtract
    subpd  xmm0, xmm4
    subpd  xmm1, xmm5
    subpd  xmm2, xmm6
    subpd  xmm3, xmm7
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 Mul)
function SSE2MulF64x8(const a, b: TVecF64x8): TVecF64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    movupd xmm4, [rdx]
    movupd xmm5, [rdx+16]
    movupd xmm6, [rdx+32]
    movupd xmm7, [rdx+48]
    // Multiply
    mulpd  xmm0, xmm4
    mulpd  xmm1, xmm5
    mulpd  xmm2, xmm6
    mulpd  xmm3, xmm7
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 Div)
function SSE2DivF64x8(const a, b: TVecF64x8): TVecF64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    movupd xmm4, [rdx]
    movupd xmm5, [rdx+16]
    movupd xmm6, [rdx+32]
    movupd xmm7, [rdx+48]
    // Divide
    divpd  xmm0, xmm4
    divpd  xmm1, xmm5
    divpd  xmm2, xmm6
    divpd  xmm3, xmm7
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 Abs)
function SSE2AbsF64x8(const a: TVecF64x8): TVecF64x8;
const
  AbsMask: array[0..1] of UInt64 = ($7FFFFFFFFFFFFFFF, $7FFFFFFFFFFFFFFF);
var
  pa, pr, pmask: Pointer;
begin
  pa := @a;
  pr := @Result;
  pmask := @AbsMask;
  asm
    mov    rax, pa
    mov    rcx, pr
    mov    rdx, pmask
    // Load abs mask (clears sign bit for double)
    movupd xmm4, [rdx]
    // Load 4 chunks
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    // Apply abs mask (bitwise AND)
    andpd  xmm0, xmm4
    andpd  xmm1, xmm4
    andpd  xmm2, xmm4
    andpd  xmm3, xmm4
    // Store result
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 Sqrt)
function SSE2SqrtF64x8(const a: TVecF64x8): TVecF64x8;
var
  pa, pr: Pointer;
begin
  pa := @a;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    // Square root
    sqrtpd xmm0, xmm0
    sqrtpd xmm1, xmm1
    sqrtpd xmm2, xmm2
    sqrtpd xmm3, xmm3
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 Min)
function SSE2MinF64x8(const a, b: TVecF64x8): TVecF64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    movupd xmm4, [rdx]
    movupd xmm5, [rdx+16]
    movupd xmm6, [rdx+32]
    movupd xmm7, [rdx+48]
    // Min
    minpd  xmm0, xmm4
    minpd  xmm1, xmm5
    minpd  xmm2, xmm6
    minpd  xmm3, xmm7
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 Max)
function SSE2MaxF64x8(const a, b: TVecF64x8): TVecF64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    movupd xmm4, [rdx]
    movupd xmm5, [rdx+16]
    movupd xmm6, [rdx+32]
    movupd xmm7, [rdx+48]
    // Max
    maxpd  xmm0, xmm4
    maxpd  xmm1, xmm5
    maxpd  xmm2, xmm6
    maxpd  xmm3, xmm7
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 FMA: a*b+c)
function SSE2FmaF64x8(const a, b, c: TVecF64x8): TVecF64x8;
var
  pa, pb, pc, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pc := @c;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    r8,  pc
    mov    rcx, pr
    // Load a (4×128-bit, each holds 2 doubles)
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    // Load b (4×128-bit)
    movupd xmm4, [rdx]
    movupd xmm5, [rdx+16]
    movupd xmm6, [rdx+32]
    movupd xmm7, [rdx+48]
    // Multiply a * b
    mulpd  xmm0, xmm4
    mulpd  xmm1, xmm5
    mulpd  xmm2, xmm6
    mulpd  xmm3, xmm7
    // Load c (4×128-bit)
    movupd xmm4, [r8]
    movupd xmm5, [r8+16]
    movupd xmm6, [r8+32]
    movupd xmm7, [r8+48]
    // Add c
    addpd  xmm0, xmm4
    addpd  xmm1, xmm5
    addpd  xmm2, xmm6
    addpd  xmm3, xmm7
    // Store results
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

function SSE2FloorF64x8(const a: TVecF64x8): TVecF64x8;
begin
  Result.lo := SSE2FloorF64x4(a.lo);
  Result.hi := SSE2FloorF64x4(a.hi);
end;

function SSE2CeilF64x8(const a: TVecF64x8): TVecF64x8;
begin
  Result.lo := SSE2CeilF64x4(a.lo);
  Result.hi := SSE2CeilF64x4(a.hi);
end;

function SSE2RoundF64x8(const a: TVecF64x8): TVecF64x8;
begin
  Result.lo := SSE2RoundF64x4(a.lo);
  Result.hi := SSE2RoundF64x4(a.hi);
end;

function SSE2TruncF64x8(const a: TVecF64x8): TVecF64x8;
begin
  Result.lo := SSE2TruncF64x4(a.lo);
  Result.hi := SSE2TruncF64x4(a.hi);
end;

// 4×128-bit SSE2 ASM 实现 (F64x8 Clamp: 限制在 [minVal, maxVal] 范围)
function SSE2ClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
var
  pa, pmin, pmax, pr: Pointer;
begin
  pa := @a;
  pmin := @minVal;
  pmax := @maxVal;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pmin
    mov    r8,  pmax
    mov    rcx, pr
    // Load a (4×128-bit)
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rax+32]
    movupd xmm3, [rax+48]
    // Load minVal (4×128-bit)
    movupd xmm4, [rdx]
    movupd xmm5, [rdx+16]
    movupd xmm6, [rdx+32]
    movupd xmm7, [rdx+48]
    // Max with minVal
    maxpd  xmm0, xmm4
    maxpd  xmm1, xmm5
    maxpd  xmm2, xmm6
    maxpd  xmm3, xmm7
    // Load maxVal (4×128-bit)
    movupd xmm4, [r8]
    movupd xmm5, [r8+16]
    movupd xmm6, [r8+32]
    movupd xmm7, [r8+48]
    // Min with maxVal
    minpd  xmm0, xmm4
    minpd  xmm1, xmm5
    minpd  xmm2, xmm6
    minpd  xmm3, xmm7
    // Store results
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
    movupd [rcx+32], xmm2
    movupd [rcx+48], xmm3
  end;
end;

function SSE2ReduceAddF64x8(const a: TVecF64x8): Double;
begin
  Result := SSE2ReduceAddF64x4(a.lo) + SSE2ReduceAddF64x4(a.hi);
end;

function SSE2ReduceMinF64x8(const a: TVecF64x8): Double;
var
  minLo, minHi: Double;
begin
  minLo := SSE2ReduceMinF64x4(a.lo);
  minHi := SSE2ReduceMinF64x4(a.hi);
  if minLo < minHi then
    Result := minLo
  else
    Result := minHi;
end;

function SSE2ReduceMaxF64x8(const a: TVecF64x8): Double;
var
  maxLo, maxHi: Double;
begin
  maxLo := SSE2ReduceMaxF64x4(a.lo);
  maxHi := SSE2ReduceMaxF64x4(a.hi);
  if maxLo > maxHi then
    Result := maxLo
  else
    Result := maxHi;
end;

function SSE2ReduceMulF64x8(const a: TVecF64x8): Double;
begin
  Result := SSE2ReduceMulF64x4(a.lo) * SSE2ReduceMulF64x4(a.hi);
end;

function SSE2LoadF64x8(p: PDouble): TVecF64x8;
begin
  Result.lo := SSE2LoadF64x4(p);
  Result.hi := SSE2LoadF64x4(p + 4);
end;

procedure SSE2StoreF64x8(p: PDouble; const a: TVecF64x8);
begin
  SSE2StoreF64x4(p, a.lo);
  SSE2StoreF64x4(p + 4, a.hi);
end;

function SSE2SplatF64x8(value: Double): TVecF64x8;
begin
  Result.lo := SSE2SplatF64x4(value);
  Result.hi := SSE2SplatF64x4(value);
end;

function SSE2ZeroF64x8: TVecF64x8;
begin
  Result.lo := SSE2ZeroF64x4;
  Result.hi := SSE2ZeroF64x4;
end;

function SSE2CmpEqF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] = b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpLtF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] < b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpLeF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] <= b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpGtF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] > b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpGeF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] >= b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2CmpNeF64x8(const a, b: TVecF64x8): TMask8;
var
  i: Integer;
  mask: Byte;
begin
  mask := 0;
  for i := 0 to 7 do
  begin
    if a.d[i] <> b.d[i] then
      mask := mask or (1 shl i);
  end;
  Result := mask;
end;

function SSE2SelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    if (mask and (1 shl i)) <> 0 then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := b.d[i];
  end;
end;

// 缺失的 Select 操作实现
// SelectI32x4: 使用 PAND + PANDN + POR 实现
// Result = (a AND mask) OR (b AND NOT mask)
function SSE2SelectI32x4(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
var
  pMask, pA, pB, pR: Pointer;
begin
  pMask := @mask;
  pA := @a;
  pB := @b;
  pR := @Result;
  asm
    mov    rax, pMask
    mov    rdx, pA
    mov    rcx, pB
    mov    r8,  pR

    movdqu xmm2, [rax]      // xmm2 = mask
    movdqu xmm0, [rdx]      // xmm0 = a
    movdqu xmm1, [rcx]      // xmm1 = b

    // Result = (a AND mask) OR (b AND NOT mask)
    pand   xmm0, xmm2       // xmm0 = a AND mask
    pandn  xmm2, xmm1       // xmm2 = (NOT mask) AND b
    por    xmm0, xmm2       // xmm0 = combine

    movdqu [r8], xmm0       // store result
  end;
end;

// SelectF32x8: 使用 2×128-bit SSE2 操作
function SSE2SelectF32x8(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
var
  pMaskLo, pMaskHi, pALo, pAHi, pBLo, pBHi, pRLo, pRHi: Pointer;
begin
  pMaskLo := @mask.lo;
  pMaskHi := @mask.hi;
  pALo := @a.lo;
  pAHi := @a.hi;
  pBLo := @b.lo;
  pBHi := @b.hi;
  pRLo := @Result.lo;
  pRHi := @Result.hi;

  // Low 128-bits
  asm
    mov    rax, pMaskLo
    mov    rdx, pALo
    mov    rcx, pBLo
    mov    r8,  pRLo

    movdqu xmm2, [rax]      // xmm2 = mask.lo
    movups xmm0, [rdx]      // xmm0 = a.lo
    movups xmm1, [rcx]      // xmm1 = b.lo

    // 使用整数逻辑指令处理浮点数据
    pand   xmm0, xmm2       // xmm0 = a.lo AND mask.lo
    pandn  xmm2, xmm1       // xmm2 = (NOT mask.lo) AND b.lo
    por    xmm0, xmm2       // combine

    movups [r8], xmm0       // store result.lo
  end;

  // High 128-bits
  asm
    mov    rax, pMaskHi
    mov    rdx, pAHi
    mov    rcx, pBHi
    mov    r8,  pRHi

    movdqu xmm2, [rax]      // xmm2 = mask.hi
    movups xmm0, [rdx]      // xmm0 = a.hi
    movups xmm1, [rcx]      // xmm1 = b.hi

    pand   xmm0, xmm2       // xmm0 = a.hi AND mask.hi
    pandn  xmm2, xmm1       // xmm2 = (NOT mask.hi) AND b.hi
    por    xmm0, xmm2       // combine

    movups [r8], xmm0       // store result.hi
  end;
end;

// SelectF64x4: 使用 2×128-bit SSE2 操作
function SSE2SelectF64x4(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;
var
  pMaskLo, pMaskHi, pALo, pAHi, pBLo, pBHi, pRLo, pRHi: Pointer;
begin
  pMaskLo := @mask.lo;
  pMaskHi := @mask.hi;
  pALo := @a.lo;
  pAHi := @a.hi;
  pBLo := @b.lo;
  pBHi := @b.hi;
  pRLo := @Result.lo;
  pRHi := @Result.hi;

  // Low 128-bits
  asm
    mov    rax, pMaskLo
    mov    rdx, pALo
    mov    rcx, pBLo
    mov    r8,  pRLo

    movdqu xmm2, [rax]      // xmm2 = mask.lo
    movupd xmm0, [rdx]      // xmm0 = a.lo
    movupd xmm1, [rcx]      // xmm1 = b.lo

    // 使用整数逻辑指令处理浮点数据
    pand   xmm0, xmm2       // xmm0 = a.lo AND mask.lo
    pandn  xmm2, xmm1       // xmm2 = (NOT mask.lo) AND b.lo
    por    xmm0, xmm2       // combine

    movupd [r8], xmm0       // store result.lo
  end;

  // High 128-bits
  asm
    mov    rax, pMaskHi
    mov    rdx, pAHi
    mov    rcx, pBHi
    mov    r8,  pRHi

    movdqu xmm2, [rax]      // xmm2 = mask.hi
    movupd xmm0, [rdx]      // xmm0 = a.hi
    movupd xmm1, [rcx]      // xmm1 = b.hi

    pand   xmm0, xmm2       // xmm0 = a.hi AND mask.hi
    pandn  xmm2, xmm1       // xmm2 = (NOT mask.hi) AND b.hi
    por    xmm0, xmm2       // combine

    movupd [r8], xmm0       // store result.hi
  end;
end;

// === I32x16 操作 (16×Int32) - 使用 2×I32x8 ===

// 4×128-bit SSE2 ASM 实现 (I32x16 Add)
function SSE2AddI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    // Load 4×128-bit from a
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    // Load 4×128-bit from b
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Add (packed dword)
    paddd   xmm0, xmm4
    paddd   xmm1, xmm5
    paddd   xmm2, xmm6
    paddd   xmm3, xmm7
    // Store result
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 Sub)
function SSE2SubI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Subtract (packed dword)
    psubd   xmm0, xmm4
    psubd   xmm1, xmm5
    psubd   xmm2, xmm6
    psubd   xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 Mul - 使用标量回退，因为 SSE2 无 pmulld)
function SSE2MulI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  i: Integer;
begin
  // SSE2 没有 32-bit 整数乘法，使用标量循环
  for i := 0 to 15 do
    Result.i[i] := a.i[i] * b.i[i];
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 And)
function SSE2AndI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Bitwise AND
    pand    xmm0, xmm4
    pand    xmm1, xmm5
    pand    xmm2, xmm6
    pand    xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 Or)
function SSE2OrI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Bitwise OR
    por     xmm0, xmm4
    por     xmm1, xmm5
    por     xmm2, xmm6
    por     xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 Xor)
function SSE2XorI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Bitwise XOR
    pxor    xmm0, xmm4
    pxor    xmm1, xmm5
    pxor    xmm2, xmm6
    pxor    xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 Not)
function SSE2NotI32x16(const a: TVecI32x16): TVecI32x16;
var
  pa, pr: Pointer;
const
  AllOnes: array[0..15] of UInt32 = (
    $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF,
    $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF,
    $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF,
    $FFFFFFFF, $FFFFFFFF, $FFFFFFFF, $FFFFFFFF
  );
begin
  pa := @a;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rcx, pr
    lea     rdx, [rip + AllOnes]
    // Load 4×128-bit from a
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    // Load 4×128-bit all-ones
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // XOR with all-ones = NOT
    pxor    xmm0, xmm4
    pxor    xmm1, xmm5
    pxor    xmm2, xmm6
    pxor    xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 AndNot)
function SSE2AndNotI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // PANDN: dest = (NOT a) AND b
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // AndNot: (NOT a) AND b
    pandn   xmm0, xmm4
    pandn   xmm1, xmm5
    pandn   xmm2, xmm6
    pandn   xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit helper composition (I32x16 ShiftLeft)
function SSE2ShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  SSE2ShiftLeftDwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftLeftDwordVecRaw(@a.raw[16], @Result.raw[16], count);
  SSE2ShiftLeftDwordVecRaw(@a.raw[32], @Result.raw[32], count);
  SSE2ShiftLeftDwordVecRaw(@a.raw[48], @Result.raw[48], count);
end;

// 4×128-bit helper composition (I32x16 ShiftRight - logical)
function SSE2ShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  SSE2ShiftRightDwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftRightDwordVecRaw(@a.raw[16], @Result.raw[16], count);
  SSE2ShiftRightDwordVecRaw(@a.raw[32], @Result.raw[32], count);
  SSE2ShiftRightDwordVecRaw(@a.raw[48], @Result.raw[48], count);
end;

// 4×128-bit helper composition (I32x16 ShiftRightArith - arithmetic)
function SSE2ShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  SSE2ShiftRightArithDwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftRightArithDwordVecRaw(@a.raw[16], @Result.raw[16], count);
  SSE2ShiftRightArithDwordVecRaw(@a.raw[32], @Result.raw[32], count);
  SSE2ShiftRightArithDwordVecRaw(@a.raw[48], @Result.raw[48], count);
end;

function SSE2CmpEqI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := (SSE2CmpEqI32x8(a.lo, b.lo) and $FF) or ((SSE2CmpEqI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function SSE2CmpLtI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := (SSE2CmpLtI32x8(a.lo, b.lo) and $FF) or ((SSE2CmpLtI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function SSE2CmpGtI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := (SSE2CmpGtI32x8(a.lo, b.lo) and $FF) or ((SSE2CmpGtI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function SSE2CmpLeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := (SSE2CmpLeI32x8(a.lo, b.lo) and $FF) or ((SSE2CmpLeI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function SSE2CmpGeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := (SSE2CmpGeI32x8(a.lo, b.lo) and $FF) or ((SSE2CmpGeI32x8(a.hi, b.hi) and $FF) shl 8);
end;

function SSE2CmpNeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := (SSE2CmpNeI32x8(a.lo, b.lo) and $FF) or ((SSE2CmpNeI32x8(a.hi, b.hi) and $FF) shl 8);
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 Min - emulated)
function SSE2MinI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // min(a,b) = (a < b) ? a : b = blend(b, a, a < b)
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr

    // Process first 128-bit chunk
    movdqu  xmm0, [rax]         // a0
    movdqu  xmm4, [rdx]         // b0
    movdqa  xmm8, xmm4          // copy b0
    pcmpgtd xmm8, xmm0          // b0 > a0 (i.e., a0 < b0)
    movdqa  xmm9, xmm0          // copy a0
    pand    xmm9, xmm8          // a0 & mask
    pandn   xmm8, xmm4          // b0 & ~mask
    por     xmm9, xmm8          // combine
    movdqu  [rcx], xmm9

    // Process second 128-bit chunk
    movdqu  xmm1, [rax+16]
    movdqu  xmm5, [rdx+16]
    movdqa  xmm8, xmm5
    pcmpgtd xmm8, xmm1
    movdqa  xmm9, xmm1
    pand    xmm9, xmm8
    pandn   xmm8, xmm5
    por     xmm9, xmm8
    movdqu  [rcx+16], xmm9

    // Process third 128-bit chunk
    movdqu  xmm2, [rax+32]
    movdqu  xmm6, [rdx+32]
    movdqa  xmm8, xmm6
    pcmpgtd xmm8, xmm2
    movdqa  xmm9, xmm2
    pand    xmm9, xmm8
    pandn   xmm8, xmm6
    por     xmm9, xmm8
    movdqu  [rcx+32], xmm9

    // Process fourth 128-bit chunk
    movdqu  xmm3, [rax+48]
    movdqu  xmm7, [rdx+48]
    movdqa  xmm8, xmm7
    pcmpgtd xmm8, xmm3
    movdqa  xmm9, xmm3
    pand    xmm9, xmm8
    pandn   xmm8, xmm7
    por     xmm9, xmm8
    movdqu  [rcx+48], xmm9
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I32x16 Max - emulated)
function SSE2MaxI32x16(const a, b: TVecI32x16): TVecI32x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // max(a,b) = (a > b) ? a : b = blend(b, a, a > b)
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr

    // Process first 128-bit chunk
    movdqu  xmm0, [rax]         // a0
    movdqu  xmm4, [rdx]         // b0
    movdqa  xmm8, xmm0          // copy a0
    pcmpgtd xmm8, xmm4          // a0 > b0
    movdqa  xmm9, xmm0          // copy a0
    pand    xmm9, xmm8          // a0 & mask
    pandn   xmm8, xmm4          // b0 & ~mask
    por     xmm9, xmm8          // combine
    movdqu  [rcx], xmm9

    // Process second 128-bit chunk
    movdqu  xmm1, [rax+16]
    movdqu  xmm5, [rdx+16]
    movdqa  xmm8, xmm1
    pcmpgtd xmm8, xmm5
    movdqa  xmm9, xmm1
    pand    xmm9, xmm8
    pandn   xmm8, xmm5
    por     xmm9, xmm8
    movdqu  [rcx+16], xmm9

    // Process third 128-bit chunk
    movdqu  xmm2, [rax+32]
    movdqu  xmm6, [rdx+32]
    movdqa  xmm8, xmm2
    pcmpgtd xmm8, xmm6
    movdqa  xmm9, xmm2
    pand    xmm9, xmm8
    pandn   xmm8, xmm6
    por     xmm9, xmm8
    movdqu  [rcx+32], xmm9

    // Process fourth 128-bit chunk
    movdqu  xmm3, [rax+48]
    movdqu  xmm7, [rdx+48]
    movdqa  xmm8, xmm3
    pcmpgtd xmm8, xmm7
    movdqa  xmm9, xmm3
    pand    xmm9, xmm8
    pandn   xmm8, xmm7
    por     xmm9, xmm8
    movdqu  [rcx+48], xmm9
  end;
end;

// ============================================================================
// I64x4 操作实现 (256-bit，使用 2×I64x2 仿真)
// ============================================================================

function SSE2AddI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result.lo := SSE2AddI64x2(a.lo, b.lo);
  Result.hi := SSE2AddI64x2(a.hi, b.hi);
end;

function SSE2SubI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result.lo := SSE2SubI64x2(a.lo, b.lo);
  Result.hi := SSE2SubI64x2(a.hi, b.hi);
end;

function SSE2AndI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result.lo := SSE2AndI64x2(a.lo, b.lo);
  Result.hi := SSE2AndI64x2(a.hi, b.hi);
end;

function SSE2OrI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result.lo := SSE2OrI64x2(a.lo, b.lo);
  Result.hi := SSE2OrI64x2(a.hi, b.hi);
end;

function SSE2XorI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result.lo := SSE2XorI64x2(a.lo, b.lo);
  Result.hi := SSE2XorI64x2(a.hi, b.hi);
end;

function SSE2NotI64x4(const a: TVecI64x4): TVecI64x4;
begin
  Result.lo := SSE2NotI64x2(a.lo);
  Result.hi := SSE2NotI64x2(a.hi);
end;

function SSE2AndNotI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  // AndNot = (NOT a) AND b
  Result.lo.i[0] := (not a.lo.i[0]) and b.lo.i[0];
  Result.lo.i[1] := (not a.lo.i[1]) and b.lo.i[1];
  Result.hi.i[0] := (not a.hi.i[0]) and b.hi.i[0];
  Result.hi.i[1] := (not a.hi.i[1]) and b.hi.i[1];
end;

function SSE2ShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
{$IFDEF CPUX64}
begin
  SSE2ShiftLeftQwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftLeftQwordVecRaw(@a.raw[16], @Result.raw[16], count);
{$ELSE}
begin
  if count >= 64 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Result.i[2] := 0;
    Result.i[3] := 0;
  end
  else if count > 0 then
  begin
    Result.i[0] := a.i[0] shl count;
    Result.i[1] := a.i[1] shl count;
    Result.i[2] := a.i[2] shl count;
    Result.i[3] := a.i[3] shl count;
  end
  else
    Result := a;
{$ENDIF}
end;

function SSE2ShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
{$IFDEF CPUX64}
begin
  SSE2ShiftRightQwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftRightQwordVecRaw(@a.raw[16], @Result.raw[16], count);
{$ELSE}
begin
  // Logical shift right (unsigned semantics)
  if count >= 64 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Result.i[2] := 0;
    Result.i[3] := 0;
  end
  else if count > 0 then
  begin
    Result.i[0] := Int64(UInt64(a.i[0]) shr count);
    Result.i[1] := Int64(UInt64(a.i[1]) shr count);
    Result.i[2] := Int64(UInt64(a.i[2]) shr count);
    Result.i[3] := Int64(UInt64(a.i[3]) shr count);
  end
  else
    Result := a;
{$ENDIF}
end;

function SSE2CmpEqI64x4(const a, b: TVecI64x4): TMask4;
var
  mLo, mHi: TMask2;
begin
  mLo := SSE2CmpEqI64x2(a.lo, b.lo);
  mHi := SSE2CmpEqI64x2(a.hi, b.hi);
  Result := (mLo and $3) or ((mHi and $3) shl 2);
end;

function SSE2CmpLtI64x4(const a, b: TVecI64x4): TMask4;
var
  mLo, mHi: TMask2;
begin
  mLo := SSE2CmpLtI64x2(a.lo, b.lo);
  mHi := SSE2CmpLtI64x2(a.hi, b.hi);
  Result := (mLo and $3) or ((mHi and $3) shl 2);
end;

function SSE2CmpGtI64x4(const a, b: TVecI64x4): TMask4;
var
  mLo, mHi: TMask2;
begin
  mLo := SSE2CmpGtI64x2(a.lo, b.lo);
  mHi := SSE2CmpGtI64x2(a.hi, b.hi);
  Result := (mLo and $3) or ((mHi and $3) shl 2);
end;

function SSE2CmpLeI64x4(const a, b: TVecI64x4): TMask4;
var
  mLo, mHi: TMask2;
begin
  mLo := SSE2CmpLeI64x2(a.lo, b.lo);
  mHi := SSE2CmpLeI64x2(a.hi, b.hi);
  Result := (mLo and $3) or ((mHi and $3) shl 2);
end;

function SSE2CmpGeI64x4(const a, b: TVecI64x4): TMask4;
var
  mLo, mHi: TMask2;
begin
  mLo := SSE2CmpGeI64x2(a.lo, b.lo);
  mHi := SSE2CmpGeI64x2(a.hi, b.hi);
  Result := (mLo and $3) or ((mHi and $3) shl 2);
end;

function SSE2CmpNeI64x4(const a, b: TVecI64x4): TMask4;
var
  mLo, mHi: TMask2;
begin
  mLo := SSE2CmpNeI64x2(a.lo, b.lo);
  mHi := SSE2CmpNeI64x2(a.hi, b.hi);
  Result := (mLo and $3) or ((mHi and $3) shl 2);
end;

function SSE2LoadI64x4(p: PInt64): TVecI64x4;
begin
  Result.i[0] := p[0];
  Result.i[1] := p[1];
  Result.i[2] := p[2];
  Result.i[3] := p[3];
end;

procedure SSE2StoreI64x4(p: PInt64; const a: TVecI64x4);
begin
  p[0] := a.i[0];
  p[1] := a.i[1];
  p[2] := a.i[2];
  p[3] := a.i[3];
end;

function SSE2SplatI64x4(value: Int64): TVecI64x4;
begin
  Result.i[0] := value;
  Result.i[1] := value;
  Result.i[2] := value;
  Result.i[3] := value;
end;

function SSE2ZeroI64x4: TVecI64x4;
begin
  Result.i[0] := 0;
  Result.i[1] := 0;
  Result.i[2] := 0;
  Result.i[3] := 0;
end;

// ============================================================================
// U32x8 操作实现 (256-bit，使用 2×U32x4 仿真)
// ============================================================================

function SSE2AddU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2AddU32x4(a.lo, b.lo);
  Result.hi := SSE2AddU32x4(a.hi, b.hi);
end;

function SSE2SubU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2SubU32x4(a.lo, b.lo);
  Result.hi := SSE2SubU32x4(a.hi, b.hi);
end;

function SSE2MulU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2MulU32x4(a.lo, b.lo);
  Result.hi := SSE2MulU32x4(a.hi, b.hi);
end;

function SSE2AndU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2AndU32x4(a.lo, b.lo);
  Result.hi := SSE2AndU32x4(a.hi, b.hi);
end;

function SSE2OrU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2OrU32x4(a.lo, b.lo);
  Result.hi := SSE2OrU32x4(a.hi, b.hi);
end;

function SSE2XorU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2XorU32x4(a.lo, b.lo);
  Result.hi := SSE2XorU32x4(a.hi, b.hi);
end;

function SSE2NotU32x8(const a: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2NotU32x4(a.lo);
  Result.hi := SSE2NotU32x4(a.hi);
end;

function SSE2AndNotU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2AndNotU32x4(a.lo, b.lo);
  Result.hi := SSE2AndNotU32x4(a.hi, b.hi);
end;

function SSE2ShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
begin
  Result.lo := SSE2ShiftLeftU32x4(a.lo, count);
  Result.hi := SSE2ShiftLeftU32x4(a.hi, count);
end;

function SSE2ShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
begin
  Result.lo := SSE2ShiftRightU32x4(a.lo, count);
  Result.hi := SSE2ShiftRightU32x4(a.hi, count);
end;

function SSE2CmpEqU32x8(const a, b: TVecU32x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpEqU32x4(a.lo, b.lo);
  mHi := SSE2CmpEqU32x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpLtU32x8(const a, b: TVecU32x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpLtU32x4(a.lo, b.lo);
  mHi := SSE2CmpLtU32x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpGtU32x8(const a, b: TVecU32x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpGtU32x4(a.lo, b.lo);
  mHi := SSE2CmpGtU32x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpLeU32x8(const a, b: TVecU32x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpLeU32x4(a.lo, b.lo);
  mHi := SSE2CmpLeU32x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpGeU32x8(const a, b: TVecU32x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpGeU32x4(a.lo, b.lo);
  mHi := SSE2CmpGeU32x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpNeU32x8(const a, b: TVecU32x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpNeU32x4(a.lo, b.lo);
  mHi := SSE2CmpNeU32x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2MinU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2MinU32x4(a.lo, b.lo);
  Result.hi := SSE2MinU32x4(a.hi, b.hi);
end;

function SSE2MaxU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result.lo := SSE2MaxU32x4(a.lo, b.lo);
  Result.hi := SSE2MaxU32x4(a.hi, b.hi);
end;

function SSE2SplatU32x8(value: UInt32): TVecU32x8;
begin
  Result.u[0] := value;
  Result.u[1] := value;
  Result.u[2] := value;
  Result.u[3] := value;
  Result.u[4] := value;
  Result.u[5] := value;
  Result.u[6] := value;
  Result.u[7] := value;
end;

// ============================================================================
// U64x4 操作实现 (256-bit，使用 2×U64x2 仿真)
// ============================================================================

function SSE2AddU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  // U64 加法与 I64 相同（位级操作）
  Result.u[0] := a.u[0] + b.u[0];
  Result.u[1] := a.u[1] + b.u[1];
  Result.u[2] := a.u[2] + b.u[2];
  Result.u[3] := a.u[3] + b.u[3];
end;

function SSE2SubU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result.u[0] := a.u[0] - b.u[0];
  Result.u[1] := a.u[1] - b.u[1];
  Result.u[2] := a.u[2] - b.u[2];
  Result.u[3] := a.u[3] - b.u[3];
end;

function SSE2AndU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result.u[0] := a.u[0] and b.u[0];
  Result.u[1] := a.u[1] and b.u[1];
  Result.u[2] := a.u[2] and b.u[2];
  Result.u[3] := a.u[3] and b.u[3];
end;

function SSE2OrU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result.u[0] := a.u[0] or b.u[0];
  Result.u[1] := a.u[1] or b.u[1];
  Result.u[2] := a.u[2] or b.u[2];
  Result.u[3] := a.u[3] or b.u[3];
end;

function SSE2XorU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result.u[0] := a.u[0] xor b.u[0];
  Result.u[1] := a.u[1] xor b.u[1];
  Result.u[2] := a.u[2] xor b.u[2];
  Result.u[3] := a.u[3] xor b.u[3];
end;

function SSE2NotU64x4(const a: TVecU64x4): TVecU64x4;
begin
  Result.u[0] := not a.u[0];
  Result.u[1] := not a.u[1];
  Result.u[2] := not a.u[2];
  Result.u[3] := not a.u[3];
end;

function SSE2ShiftLeftU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
{$IFDEF CPUX64}
begin
  SSE2ShiftLeftQwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftLeftQwordVecRaw(@a.raw[16], @Result.raw[16], count);
{$ELSE}
begin
  if count >= 64 then
  begin
    Result.u[0] := 0;
    Result.u[1] := 0;
    Result.u[2] := 0;
    Result.u[3] := 0;
  end
  else if count > 0 then
  begin
    Result.u[0] := a.u[0] shl count;
    Result.u[1] := a.u[1] shl count;
    Result.u[2] := a.u[2] shl count;
    Result.u[3] := a.u[3] shl count;
  end
  else
    Result := a;
{$ENDIF}
end;

function SSE2ShiftRightU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
{$IFDEF CPUX64}
begin
  SSE2ShiftRightQwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftRightQwordVecRaw(@a.raw[16], @Result.raw[16], count);
{$ELSE}
begin
  if count >= 64 then
  begin
    Result.u[0] := 0;
    Result.u[1] := 0;
    Result.u[2] := 0;
    Result.u[3] := 0;
  end
  else if count > 0 then
  begin
    Result.u[0] := a.u[0] shr count;
    Result.u[1] := a.u[1] shr count;
    Result.u[2] := a.u[2] shr count;
    Result.u[3] := a.u[3] shr count;
  end
  else
    Result := a;
{$ENDIF}
end;

function SSE2CmpEqU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := 0;
  if a.u[0] = b.u[0] then Result := Result or 1;
  if a.u[1] = b.u[1] then Result := Result or 2;
  if a.u[2] = b.u[2] then Result := Result or 4;
  if a.u[3] = b.u[3] then Result := Result or 8;
end;

function SSE2CmpLtU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := 0;
  if a.u[0] < b.u[0] then Result := Result or 1;
  if a.u[1] < b.u[1] then Result := Result or 2;
  if a.u[2] < b.u[2] then Result := Result or 4;
  if a.u[3] < b.u[3] then Result := Result or 8;
end;

function SSE2CmpGtU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := 0;
  if a.u[0] > b.u[0] then Result := Result or 1;
  if a.u[1] > b.u[1] then Result := Result or 2;
  if a.u[2] > b.u[2] then Result := Result or 4;
  if a.u[3] > b.u[3] then Result := Result or 8;
end;

function SSE2CmpLeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := 0;
  if a.u[0] <= b.u[0] then Result := Result or 1;
  if a.u[1] <= b.u[1] then Result := Result or 2;
  if a.u[2] <= b.u[2] then Result := Result or 4;
  if a.u[3] <= b.u[3] then Result := Result or 8;
end;

function SSE2CmpGeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := 0;
  if a.u[0] >= b.u[0] then Result := Result or 1;
  if a.u[1] >= b.u[1] then Result := Result or 2;
  if a.u[2] >= b.u[2] then Result := Result or 4;
  if a.u[3] >= b.u[3] then Result := Result or 8;
end;

function SSE2CmpNeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := 0;
  if a.u[0] <> b.u[0] then Result := Result or 1;
  if a.u[1] <> b.u[1] then Result := Result or 2;
  if a.u[2] <> b.u[2] then Result := Result or 4;
  if a.u[3] <> b.u[3] then Result := Result or 8;
end;

// ============================================================================
// I64x8 操作实现 (512-bit，使用 2×I64x4 仿真)
// ============================================================================

// 4×128-bit SSE2 ASM 实现 (I64x8 Add)
function SSE2AddI64x8(const a, b: TVecI64x8): TVecI64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    // Load 4×128-bit from a (each holds 2 qwords)
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    // Load 4×128-bit from b
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Add (packed qword)
    paddq   xmm0, xmm4
    paddq   xmm1, xmm5
    paddq   xmm2, xmm6
    paddq   xmm3, xmm7
    // Store result
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I64x8 Sub)
function SSE2SubI64x8(const a, b: TVecI64x8): TVecI64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Subtract (packed qword)
    psubq   xmm0, xmm4
    psubq   xmm1, xmm5
    psubq   xmm2, xmm6
    psubq   xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I64x8 And)
function SSE2AndI64x8(const a, b: TVecI64x8): TVecI64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Bitwise AND
    pand    xmm0, xmm4
    pand    xmm1, xmm5
    pand    xmm2, xmm6
    pand    xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I64x8 Or)
function SSE2OrI64x8(const a, b: TVecI64x8): TVecI64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Bitwise OR
    por     xmm0, xmm4
    por     xmm1, xmm5
    por     xmm2, xmm6
    por     xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I64x8 Xor)
function SSE2XorI64x8(const a, b: TVecI64x8): TVecI64x8;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // Bitwise XOR
    pxor    xmm0, xmm4
    pxor    xmm1, xmm5
    pxor    xmm2, xmm6
    pxor    xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit SSE2 ASM 实现 (I64x8 Not)
function SSE2NotI64x8(const a: TVecI64x8): TVecI64x8;
var
  pa, pr: Pointer;
const
  AllOnes: array[0..7] of UInt64 = (
    UInt64($FFFFFFFFFFFFFFFF), UInt64($FFFFFFFFFFFFFFFF),
    UInt64($FFFFFFFFFFFFFFFF), UInt64($FFFFFFFFFFFFFFFF),
    UInt64($FFFFFFFFFFFFFFFF), UInt64($FFFFFFFFFFFFFFFF),
    UInt64($FFFFFFFFFFFFFFFF), UInt64($FFFFFFFFFFFFFFFF)
  );
begin
  pa := @a;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rcx, pr
    lea     rdx, [rip + AllOnes]
    // Load 4×128-bit from a
    movdqu  xmm0, [rax]
    movdqu  xmm1, [rax+16]
    movdqu  xmm2, [rax+32]
    movdqu  xmm3, [rax+48]
    // Load 4×128-bit all-ones
    movdqu  xmm4, [rdx]
    movdqu  xmm5, [rdx+16]
    movdqu  xmm6, [rdx+32]
    movdqu  xmm7, [rdx+48]
    // XOR with all-ones = NOT
    pxor    xmm0, xmm4
    pxor    xmm1, xmm5
    pxor    xmm2, xmm6
    pxor    xmm3, xmm7
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
    movdqu  [rcx+32], xmm2
    movdqu  [rcx+48], xmm3
  end;
end;

// 4×128-bit helper composition (I64x8 ShiftLeft)
function SSE2ShiftLeftI64x8(const a: TVecI64x8; count: Integer): TVecI64x8;
begin
  SSE2ShiftLeftQwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftLeftQwordVecRaw(@a.raw[16], @Result.raw[16], count);
  SSE2ShiftLeftQwordVecRaw(@a.raw[32], @Result.raw[32], count);
  SSE2ShiftLeftQwordVecRaw(@a.raw[48], @Result.raw[48], count);
end;

// 4×128-bit helper composition (I64x8 ShiftRight - logical)
function SSE2ShiftRightI64x8(const a: TVecI64x8; count: Integer): TVecI64x8;
begin
  SSE2ShiftRightQwordVecRaw(@a.raw[0], @Result.raw[0], count);
  SSE2ShiftRightQwordVecRaw(@a.raw[16], @Result.raw[16], count);
  SSE2ShiftRightQwordVecRaw(@a.raw[32], @Result.raw[32], count);
  SSE2ShiftRightQwordVecRaw(@a.raw[48], @Result.raw[48], count);
end;

function SSE2CmpEqI64x8(const a, b: TVecI64x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpEqI64x4(a.lo, b.lo);
  mHi := SSE2CmpEqI64x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpLtI64x8(const a, b: TVecI64x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpLtI64x4(a.lo, b.lo);
  mHi := SSE2CmpLtI64x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpGtI64x8(const a, b: TVecI64x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpGtI64x4(a.lo, b.lo);
  mHi := SSE2CmpGtI64x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpLeI64x8(const a, b: TVecI64x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpLeI64x4(a.lo, b.lo);
  mHi := SSE2CmpLeI64x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpGeI64x8(const a, b: TVecI64x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpGeI64x4(a.lo, b.lo);
  mHi := SSE2CmpGeI64x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2CmpNeI64x8(const a, b: TVecI64x8): TMask8;
var
  mLo, mHi: TMask4;
begin
  mLo := SSE2CmpNeI64x4(a.lo, b.lo);
  mHi := SSE2CmpNeI64x4(a.hi, b.hi);
  Result := (mLo and $F) or ((mHi and $F) shl 4);
end;

function SSE2LoadI64x8(p: PInt64): TVecI64x8;
begin
  Result.i[0] := p[0];
  Result.i[1] := p[1];
  Result.i[2] := p[2];
  Result.i[3] := p[3];
  Result.i[4] := p[4];
  Result.i[5] := p[5];
  Result.i[6] := p[6];
  Result.i[7] := p[7];
end;

procedure SSE2StoreI64x8(p: PInt64; const a: TVecI64x8);
begin
  p[0] := a.i[0];
  p[1] := a.i[1];
  p[2] := a.i[2];
  p[3] := a.i[3];
  p[4] := a.i[4];
  p[5] := a.i[5];
  p[6] := a.i[6];
  p[7] := a.i[7];
end;

function SSE2SplatI64x8(value: Int64): TVecI64x8;
begin
  Result.i[0] := value;
  Result.i[1] := value;
  Result.i[2] := value;
  Result.i[3] := value;
  Result.i[4] := value;
  Result.i[5] := value;
  Result.i[6] := value;
  Result.i[7] := value;
end;

function SSE2ZeroI64x8: TVecI64x8;
begin
  Result.i[0] := 0;
  Result.i[1] := 0;
  Result.i[2] := 0;
  Result.i[3] := 0;
  Result.i[4] := 0;
  Result.i[5] := 0;
  Result.i[6] := 0;
  Result.i[7] := 0;
end;

// ============================================================================
// Extract/Insert operations reuse scalar boundary semantics while keeping the
// SSE2-owned dispatch slots.
// ============================================================================

function SSE2ExtractF64x2(const a: TVecF64x2; index: Integer): Double;
begin
  Result := ScalarExtractF64x2(a, index);
end;

function SSE2InsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
begin
  Result := ScalarInsertF64x2(a, value, index);
end;

function SSE2ExtractI32x4(const a: TVecI32x4; index: Integer): Int32;
begin
  Result := ScalarExtractI32x4(a, index);
end;

function SSE2InsertI32x4(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
begin
  Result := ScalarInsertI32x4(a, value, index);
end;

function SSE2ExtractI64x2(const a: TVecI64x2; index: Integer): Int64;
begin
  Result := ScalarExtractI64x2(a, index);
end;

function SSE2InsertI64x2(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
begin
  Result := ScalarInsertI64x2(a, value, index);
end;

function SSE2ExtractF32x8(const a: TVecF32x8; index: Integer): Single;
begin
  Result := ScalarExtractF32x8(a, index);
end;

function SSE2InsertF32x8(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
begin
  Result := ScalarInsertF32x8(a, value, index);
end;

function SSE2ExtractF64x4(const a: TVecF64x4; index: Integer): Double;
begin
  Result := ScalarExtractF64x4(a, index);
end;

function SSE2InsertF64x4(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
begin
  Result := ScalarInsertF64x4(a, value, index);
end;

function SSE2ExtractI32x8(const a: TVecI32x8; index: Integer): Int32;
begin
  Result := ScalarExtractI32x8(a, index);
end;

function SSE2InsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
begin
  Result := ScalarInsertI32x8(a, value, index);
end;

function SSE2ExtractI64x4(const a: TVecI64x4; index: Integer): Int64;
begin
  Result := ScalarExtractI64x4(a, index);
end;

function SSE2InsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
begin
  Result := ScalarInsertI64x4(a, value, index);
end;

function SSE2ExtractF32x16(const a: TVecF32x16; index: Integer): Single;
begin
  Result := ScalarExtractF32x16(a, index);
end;

function SSE2InsertF32x16(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
begin
  Result := ScalarInsertF32x16(a, value, index);
end;

function SSE2ExtractI32x16(const a: TVecI32x16; index: Integer): Int32;
begin
  Result := ScalarExtractI32x16(a, index);
end;

function SSE2InsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
begin
  Result := ScalarInsertI32x16(a, value, index);
end;

// ============================================================================
// Facade 函数实现 (高级内存和文本操作)
// ============================================================================

function MemDiffRange_SSE2(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
var
  i: SizeUInt;
  pA, pB: PByte;
begin
  // 简单标量实现 (可后续优化为 SIMD)
  pA := PByte(a);
  pB := PByte(b);
  firstDiff := 0;
  lastDiff := 0;
  Result := False;

  // 找第一个不同位置
  for i := 0 to len - 1 do
  begin
    if pA[i] <> pB[i] then
    begin
      firstDiff := i;
      Result := True;
      Break;
    end;
  end;

  if not Result then
    Exit;

  // 找最后一个不同位置
  lastDiff := firstDiff;
  for i := len - 1 downto firstDiff + 1 do
  begin
    if pA[i] <> pB[i] then
    begin
      lastDiff := i;
      Break;
    end;
  end;
end;

procedure MemReverse_SSE2(p: Pointer; len: SizeUInt);
var
  pB: PByte;
  i, j: SizeUInt;
  tmp: Byte;
begin
  pB := PByte(p);
  i := 0;
  j := len - 1;
  while i < j do
  begin
    tmp := pB[i];
    pB[i] := pB[j];
    pB[j] := tmp;
    Inc(i);
    Dec(j);
  end;
end;

procedure ToLowerAscii_SSE2(p: Pointer; len: SizeUInt);
var
  pB: PByte;
  i: SizeUInt;
  c: Byte;
begin
  pB := PByte(p);
  for i := 0 to len - 1 do
  begin
    c := pB[i];
    if (c >= Ord('A')) and (c <= Ord('Z')) then
      pB[i] := c + 32;
  end;
end;

procedure ToUpperAscii_SSE2(p: Pointer; len: SizeUInt);
var
  pB: PByte;
  i: SizeUInt;
  c: Byte;
begin
  pB := PByte(p);
  for i := 0 to len - 1 do
  begin
    c := pB[i];
    if (c >= Ord('a')) and (c <= Ord('z')) then
      pB[i] := c - 32;
  end;
end;

function AsciiIEqual_SSE2(a, b: Pointer; len: SizeUInt): Boolean;
var
  pA, pB: PByte;
  i: SizeUInt;
  cA, cB: Byte;
begin
  pA := PByte(a);
  pB := PByte(b);
  for i := 0 to len - 1 do
  begin
    cA := pA[i];
    cB := pB[i];
    // 转换为小写后比较
    if (cA >= Ord('A')) and (cA <= Ord('Z')) then
      cA := cA + 32;
    if (cB >= Ord('A')) and (cB <= Ord('Z')) then
      cB := cB + 32;
    if cA <> cB then
      Exit(False);
  end;
  Result := True;
end;

function BytesIndexOf_SSE2(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
var
  pHay, pNeedle: PByte;
  i, j: SizeUInt;
  firstByte: Byte;
  found: Boolean;
begin
  if (needleLen = 0) or (needleLen > haystackLen) then
    Exit(-1);

  pHay := PByte(haystack);
  pNeedle := PByte(needle);
  firstByte := pNeedle[0];

  for i := 0 to haystackLen - needleLen do
  begin
    if pHay[i] = firstByte then
    begin
      found := True;
      for j := 1 to needleLen - 1 do
      begin
        if pHay[i + j] <> pNeedle[j] then
        begin
          found := False;
          Break;
        end;
      end;
      if found then
        Exit(i);
    end;
  end;
  Result := -1;
end;

function Utf8Validate_SSE2(p: Pointer; len: SizeUInt): Boolean;
var
  pB: PByte;
  i: SizeUInt;
  b: Byte;
begin
  // 简单的 UTF-8 验证 (可后续优化为 SIMD)
  pB := PByte(p);
  i := 0;
  while i < len do
  begin
    b := pB[i];
    if b < $80 then
    begin
      // ASCII: 单字节
      Inc(i);
    end
    else if (b and $E0) = $C0 then
    begin
      // 2 字节序列
      if i + 1 >= len then Exit(False);
      if (pB[i + 1] and $C0) <> $80 then Exit(False);
      Inc(i, 2);
    end
    else if (b and $F0) = $E0 then
    begin
      // 3 字节序列
      if i + 2 >= len then Exit(False);
      if (pB[i + 1] and $C0) <> $80 then Exit(False);
      if (pB[i + 2] and $C0) <> $80 then Exit(False);
      Inc(i, 3);
    end
    else if (b and $F8) = $F0 then
    begin
      // 4 字节序列
      if i + 3 >= len then Exit(False);
      if (pB[i + 1] and $C0) <> $80 then Exit(False);
      if (pB[i + 2] and $C0) <> $80 then Exit(False);
      if (pB[i + 3] and $C0) <> $80 then Exit(False);
      Inc(i, 4);
    end
    else
    begin
      // 无效的 UTF-8 首字节
      Exit(False);
    end;
  end;
  Result := True;
end;
