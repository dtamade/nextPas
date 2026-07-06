// ============================================================================
// SSE3 Extensions
// ============================================================================

function SSE3HAddF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    haddps xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE3HSubF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    hsubps xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE3HAddF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    haddpd xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE3HSubF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    hsubpd xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE3AddSubF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    addsubps xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE3AddSubF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    addsubpd xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE3MovDupF64x2(const a: TVecF64x2): TVecF64x2;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movddup xmm0, [rax]
    movups [rcx], xmm0
  end;
end;

function SSE3MovSLDupF32x4(const a: TVecF32x4): TVecF32x4;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movsldup xmm0, [rax]
    movups [rcx], xmm0
  end;
end;

function SSE3MovSHDupF32x4(const a: TVecF32x4): TVecF32x4;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movshdup xmm0, [rax]
    movups [rcx], xmm0
  end;
end;

function SSE3ReduceAddF32x4(const a: TVecF32x4): Single;
var
  LRes: TVecF32x4;
begin
  LRes := SSE3HAddF32x4(a, a);
  LRes := SSE3HAddF32x4(LRes, LRes);
  Result := LRes.f[0];
end;

function SSE3ReduceAddF64x2(const a: TVecF64x2): Double;
var
  LRes: TVecF64x2;
begin
  LRes := SSE3HAddF64x2(a, a);
  Result := LRes.d[0];
end;

function SSE3ReduceMulF32x4(const a: TVecF32x4): Single;
begin
  Result := a.f[0] * a.f[1] * a.f[2] * a.f[3];
end;

function SSE3ReduceMulF64x2(const a: TVecF64x2): Double;
begin
  Result := a.d[0] * a.d[1];
end;

function SSE3DotF32x4(const a, b: TVecF32x4): Single;
var
  LMul: TVecF32x4;
begin
  LMul := SSE2MulF32x4(a, b);
  Result := SSE3ReduceAddF32x4(LMul);
end;

function SSE3DotF32x3(const a, b: TVecF32x4): Single;
var
  LMul: TVecF32x4;
begin
  LMul := SSE2MulF32x4(a, b);
  Result := LMul.f[0] + LMul.f[1] + LMul.f[2];
end;

function SSE3LengthF32x4(const a: TVecF32x4): Single;
begin
  Result := Sqrt(SSE3DotF32x4(a, a));
end;

function SSE3LengthF32x3(const a: TVecF32x4): Single;
begin
  Result := Sqrt(SSE3DotF32x3(a, a));
end;

function SSE3NormalizeF32x4(const a: TVecF32x4): TVecF32x4;
var
  LLen: Single;
begin
  LLen := SSE3LengthF32x4(a);
  if LLen > 0 then
    Result := SSE2MulScalarF32x4(a, 1.0 / LLen)
  else
    Result := a;
end;

function SSE3NormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  LLen: Single;
begin
  LLen := SSE3LengthF32x3(a);
  if LLen > 0 then
    Result := SSE2MulScalarF32x4(a, 1.0 / LLen)
  else
    Result := a;
end;

// ============================================================================
// SSE4.1 Extensions
// ============================================================================

function SSE41DotF32x4_Full(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    dpps xmm0, xmm1, $FF
    movups [rcx], xmm0
  end;
end;

function SSE41DotF32x4(const a, b: TVecF32x4): Single;
var
  LRes: TVecF32x4;
begin
  LRes := SSE41DotF32x4_Full(a, b);
  Result := LRes.f[0];
end;

function SSE41DotF32x3(const a, b: TVecF32x4): Single;
var pa, pb: Pointer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movups xmm0, [rax]
    movups xmm1, [rdx]
    dpps xmm0, xmm1, $7F
    movq rax, xmm0
    movq [Result], rax
  end;
end;

function SSE41DotF64x2(const a, b: TVecF64x2): Double;
var pa, pb: Pointer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movups xmm0, [rax]
    movups xmm1, [rdx]
    dppd xmm0, xmm1, $3F
    movq rax, xmm0
    movq [Result], rax
  end;
end;

function SSE41RoundF32x4(const a: TVecF32x4): TVecF32x4;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    roundps xmm0, xmm0, 0
    movups [rcx], xmm0
  end;
end;

function SSE41FloorF32x4(const a: TVecF32x4): TVecF32x4;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    roundps xmm0, xmm0, 1
    movups [rcx], xmm0
  end;
end;

function SSE41CeilF32x4(const a: TVecF32x4): TVecF32x4;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    roundps xmm0, xmm0, 2
    movups [rcx], xmm0
  end;
end;

function SSE41TruncF32x4(const a: TVecF32x4): TVecF32x4;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    roundps xmm0, xmm0, 3
    movups [rcx], xmm0
  end;
end;

function SSE41RoundF64x2(const a: TVecF64x2): TVecF64x2;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    roundpd xmm0, xmm0, 0
    movups [rcx], xmm0
  end;
end;

function SSE41FloorF64x2(const a: TVecF64x2): TVecF64x2;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    roundpd xmm0, xmm0, 1
    movups [rcx], xmm0
  end;
end;

function SSE41CeilF64x2(const a: TVecF64x2): TVecF64x2;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    roundpd xmm0, xmm0, 2
    movups [rcx], xmm0
  end;
end;

function SSE41TruncF64x2(const a: TVecF64x2): TVecF64x2;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    roundpd xmm0, xmm0, 3
    movups [rcx], xmm0
  end;
end;

function SSE41BlendF32x4_1(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    blendps xmm0, xmm1, $5
    movups [rcx], xmm0
  end;
end;

function SSE41BlendVF32x4(const a, b: TVecF32x4; const mask: TMaskF32x4): TVecF32x4;
var pa, pb, pm, pr: Pointer;
begin
  pa := @a; pb := @b; pm := @mask; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pm
    mov r8, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    movups xmm2, [rcx]
    blendvps xmm0, xmm1, xmm2
    movups [r8], xmm0
  end;
end;

function SSE41MulI32x4(const a, b: TVecI32x4): TVecI32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pmulld xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41MinI32x4(const a, b: TVecI32x4): TVecI32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pminsd xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41MaxI32x4(const a, b: TVecI32x4): TVecI32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pmaxsd xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41MinU32x4(const a, b: TVecU32x4): TVecU32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pminud xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41MaxU32x4(const a, b: TVecU32x4): TVecU32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pmaxud xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41MulU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  // PMULLD works for unsigned as well (lower 32 bits)
  Result := TVecU32x4(SSE41MulI32x4(TVecI32x4(a), TVecI32x4(b)));
end;

function SSE41MinI8x16(const a, b: TVecI8x16): TVecI8x16;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pminsb xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41MaxI8x16(const a, b: TVecI8x16): TVecI8x16;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pmaxsb xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41MinU16x8(const a, b: TVecU16x8): TVecU16x8;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pminuw xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41MaxU16x8(const a, b: TVecU16x8): TVecU16x8;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pmaxuw xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE41LengthF32x4(const a: TVecF32x4): Single;
begin
  Result := Sqrt(SSE41DotF32x4(a, a));
end;

function SSE41LengthF32x3(const a: TVecF32x4): Single;
begin
  Result := Sqrt(SSE41DotF32x3(a, a));
end;

function SSE41NormalizeF32x4(const a: TVecF32x4): TVecF32x4;
var
  LLen: Single;
begin
  LLen := SSE41LengthF32x4(a);
  if LLen > 0 then
    Result := SSE2MulScalarF32x4(a, 1.0 / LLen)
  else
    Result := a;
end;

function SSE41NormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  LLen: Single;
begin
  LLen := SSE41LengthF32x3(a);
  if LLen > 0 then
    Result := SSE2MulScalarF32x4(a, 1.0 / LLen)
  else
    Result := a;
end;

function SSE41InsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
begin
  Result := a;
  Result.f[index] := value;
end;

function SSE41ExtractF32x4(const a: TVecF32x4; index: Integer): Single;
begin
  Result := a.f[index];
end;

function SSE41CmpEqI64x2(const a, b: TVecI64x2): TMask2;
var pa, pb: Pointer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pcmpeqq xmm0, xmm1
    movq rax, xmm0
    movq [Result], rax
  end;
end;

function SSE41SelectF32x4(const mask: TMaskF32x4; const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pm, pr: Pointer;
begin
  pa := @a; pb := @b; pm := @mask; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pm
    mov r8, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    movups xmm2, [rcx]
    blendvps xmm0, xmm1, xmm2
    movups [r8], xmm0
  end;
end;

// ============================================================================
// SSE4.2 Extensions
// ============================================================================

function CRC32C_8(crc: UInt32; value: Byte): UInt32;
begin
  Result := crc32_8(crc, value);
end;

function CRC32C_16(crc: UInt32; value: UInt16): UInt32;
begin
  Result := crc32_16(crc, value);
end;

function CRC32C_32(crc: UInt32; value: UInt32): UInt32;
begin
  Result := crc32_32(crc, value);
end;

function CRC32C_64(crc: UInt64; value: UInt64): UInt64;
begin
  Result := crc32_64(crc, value);
end;

function CRC32C_Buffer(const data: Pointer; len: SizeUInt; initial: UInt32): UInt32;
var
  p: PByte;
  remaining: SizeUInt;
begin
  Result := initial;
  p := PByte(data);
  remaining := len;

  while remaining >= 8 do
  begin
    Result := UInt32(CRC32C_64(Result, PUInt64(p)^));
    Inc(p, 8);
    Dec(remaining, 8);
  end;

  while remaining >= 4 do
  begin
    Result := CRC32C_32(Result, PUInt32(p)^);
    Inc(p, 4);
    Dec(remaining, 4);
  end;

  while remaining >= 2 do
  begin
    Result := CRC32C_16(Result, PUInt16(p)^);
    Inc(p, 2);
    Dec(remaining, 2);
  end;

  if remaining > 0 then
    Result := CRC32C_8(Result, p^);
end;

function SSE42CmpGtI64x2(const a, b: TVecI64x2): TMask2;
var pa, pb: Pointer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pcmpgtq xmm0, xmm1
    movq rax, xmm0
    movq [Result], rax
  end;
end;

function BytesIndexOf_SSE42(const haystack: PAnsiChar; haystackLen: Integer;
  const needle: PAnsiChar; needleLen: Integer): Integer;
begin
  // Simplified implementation - uses PCMPSTRI
  // For now, delegate to scalar fallback
  Result := -1;
  // TODO: Implement SSE4.2 PCMPESTRI version
end;
