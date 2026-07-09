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
    Result := SSE2MulF32x4(a, SSE2SplatF32x4(1.0 / LLen))
  else
    Result := a;
end;

function SSE3NormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  LLen: Single;
begin
  LLen := SSE3LengthF32x3(a);
  if LLen > 0 then
    Result := SSE2MulF32x4(a, SSE2SplatF32x4(1.0 / LLen))
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
    movss [Result], xmm0
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
    movsd [Result], xmm0
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
    blendvps xmm1, xmm0
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
    Result := SSE2MulF32x4(a, SSE2SplatF32x4(1.0 / LLen))
  else
    Result := a;
end;

function SSE41NormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  LLen: Single;
begin
  LLen := SSE41LengthF32x3(a);
  if LLen > 0 then
    Result := SSE2MulF32x4(a, SSE2SplatF32x4(1.0 / LLen))
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
    pmovmskb eax, xmm0
    mov [Result], al
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
    blendvps xmm1, xmm0
    movups [r8], xmm0
  end;
end;

// ============================================================================
// SSE4.2 Extensions
// ============================================================================

function CRC32C_8(crc: UInt32; value: Byte): UInt32; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  mov eax, edi
  movzx esi, sil
  crc32 eax, sil
  {$ELSE}
  mov eax, ecx
  crc32 eax, dl
  {$ENDIF}
end;

function CRC32C_16(crc: UInt32; value: UInt16): UInt32; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  mov eax, edi
  crc32 eax, si
  {$ELSE}
  mov eax, ecx
  crc32 eax, dx
  {$ENDIF}
end;

function CRC32C_32(crc: UInt32; value: UInt32): UInt32; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  mov eax, edi
  crc32 eax, esi
  {$ELSE}
  mov eax, ecx
  crc32 eax, edx
  {$ENDIF}
end;

function CRC32C_64(crc: UInt64; value: UInt64): UInt64; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  mov rax, rdi
  crc32 rax, rsi
  {$ELSE}
  mov rax, rcx
  crc32 rax, rdx
  {$ENDIF}
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
    pmovmskb eax, xmm0
    mov [Result], al
  end;
end;

function BytesIndexOf_SSE42(const haystack: PAnsiChar; haystackLen: Integer;
  const needle: PAnsiChar; needleLen: Integer): Integer;
var
  LHaystack, LNeedle: Pointer;
  LLen, LNeedleLen: Integer;
  LIdx, LImm8: Integer;
begin
  if (haystackLen <= 0) or (needleLen <= 0) or (haystack = nil) or (needle = nil) then
  begin
    Result := -1;
    Exit;
  end;

  LHaystack := haystack;
  LNeedle := needle;
  LLen := haystackLen;
  LNeedleLen := needleLen;

  // Imm8 for PCMPSTRI:
  // Bit 1:0 = 00 (unsigned bytes)
  // Bit 3:2 = 00 (equal any - find any byte from needle set)
  // Bit 4 = 0 (positive polarity)
  // Bit 5 = 0 (least significant index)
  LImm8 := $00; // EqualAny, unsigned bytes

  asm
    mov rax, LHaystack
    mov rdx, LNeedle
    mov ecx, LNeedleLen

    // Load needle set into xmm1
    // If needleLen < 16, zero-pad
    pxor xmm1, xmm1
    cmp ecx, 16
    jae @load_needle_16
    // Partial load - use movq for up to 8 bytes, then handle remainder
    cmp ecx, 8
    ja @load_needle_gt8
    movq xmm1, [rdx]
    jmp @needle_loaded
  @load_needle_gt8:
    movdqu xmm1, [rdx]  // Load up to 16 bytes (will read past if needleLen > 16 but < 16 is handled)
    jmp @needle_loaded
  @load_needle_16:
    movdqu xmm1, [rdx]
  @needle_loaded:

    // Set up length registers for PCMPSTRI
    // xmm0 = haystack chunk, xmm1 = needle set
    // ecx = needleLen (already set)
    // edx = haystack chunk length (up to 16)

    mov r8, rax           // Current haystack pointer
    mov r9, LLen          // Remaining haystack length

  @search_loop:
    cmp r9, 0
    jle @not_found

    // Load up to 16 bytes from haystack
    mov rdx, r9
    cmp rdx, 16
    jb @partial_haystack
    movdqu xmm0, [r8]
    mov rdx, 16           // Full 16-byte chunk
    jmp @do_compare

  @partial_haystack:
    // For partial load, zero the buffer and copy
    pxor xmm0, xmm0
    // Use movq for small chunks
    cmp rdx, 8
    ja @partial_gt8
    movq xmm0, [r8]
    jmp @do_compare
  @partial_gt8:
    movdqu xmm0, [r8]

  @do_compare:
    // PCMPSTRI: compare xmm0 (haystack) with xmm1 (needle)
    // ecx = needleLen, edx = haystack chunk len (but PCMPSTRI uses xmm0's implicit length via ecx/rax)
    // Actually PCMPSTRI uses xmm0 and xmm1, with eax = haystackLen, edx = needleLen for implicit lengths
    // But for "equal any" mode, we just need the needle set in xmm1

    // Correct setup: eax = haystack chunk len, edx = needle len
    mov eax, edx          // eax = haystack chunk length (16 or less)
    mov edx, ecx          // edx = needle length
    // ecx will be set by PCMPSTRI to the result index

    // Imm8 = $00 for EqualAny, unsigned bytes
    db $66, $0f, $3a, $63, $c1, $00  // pcmpstri xmm1, xmm0, 0x00

    // After PCMPSTRI:
    // ECX = index of first match (or 16 if no match)
    // ZF = 1 if no match found in this chunk
    jz @advance

    // Match found!
    mov rax, r8
    sub rax, LHaystack
    add rax, rcx
    mov LIdx, eax
    jmp @done

  @advance:
    add r8, 16
    sub r9, 16
    jmp @search_loop

  @not_found:
    mov LIdx, -1

  @done:
  end;

  Result := LIdx;
end;

// FindFirstOf: find index of first byte in haystack that is in the needle set
function FindFirstOf_SSE42(const haystack: PAnsiChar; haystackLen: Integer;
  const needle: PAnsiChar; needleLen: Integer): Integer;
var
  i, j: Integer;
begin
  if (haystackLen <= 0) or (needleLen <= 0) or (haystack = nil) or (needle = nil) then
  begin
    Result := -1;
    Exit;
  end;

  for i := 0 to haystackLen - 1 do
    for j := 0 to needleLen - 1 do
      if haystack[i] = needle[j] then
      begin
        Result := i;
        Exit;
      end;
  Result := -1;
end;

// FindFirstNotOf: find index of first byte in haystack that is NOT in the needle set
function FindFirstNotOf_SSE42(const haystack: PAnsiChar; haystackLen: Integer;
  const needle: PAnsiChar; needleLen: Integer): Integer;
var
  i, j: Integer;
  LFound: Boolean;
begin
  if (haystackLen <= 0) then
  begin
    Result := -1;
    Exit;
  end;
  if (needleLen <= 0) or (needle = nil) then
  begin
    Result := 0; // Empty needle set means every byte matches
    Exit;
  end;

  for i := 0 to haystackLen - 1 do
  begin
    LFound := False;
    for j := 0 to needleLen - 1 do
      if haystack[i] = needle[j] then
      begin
        LFound := True;
        Break;
      end;
    if not LFound then
    begin
      Result := i;
      Exit;
    end;
  end;
  Result := -1;
end;
