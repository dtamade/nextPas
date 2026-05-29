// x86-64 SSE2 implementation of vec16 primitives

function Vec16CmpEq(AData: PByte; AValue: Byte): TMask16; inline;
begin
  Result := 0;
  asm
    movzx eax, AValue
    movd xmm0, eax
    punpcklbw xmm0, xmm0
    pshuflw xmm0, xmm0, 0
    punpcklqdq xmm0, xmm0
    mov rax, AData
    movdqu xmm1, [rax]
    pcmpeqb xmm1, xmm0
    pmovmskb eax, xmm1
    mov Result, ax
  end;
end;

function Vec16CmpEq2(AData, APattern: PByte): TMask16; inline;
begin
  Result := 0;
  asm
    mov rax, AData
    mov rdx, APattern
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pcmpeqb xmm0, xmm1
    pmovmskb eax, xmm0
    mov Result, ax
  end;
end;

function Vec16CmpLtU(AData: PByte; AThreshold: Byte): TMask16; inline;
begin
  Result := 0;
  asm
    movzx eax, AThreshold
    movd xmm0, eax
    punpcklbw xmm0, xmm0
    pshuflw xmm0, xmm0, 0
    punpcklqdq xmm0, xmm0
    mov rax, AData
    movdqu xmm1, [rax]
    // unsigned lt: data < threshold ≡ maxu(threshold, data) != data
    // simpler: subtract 128 from both, then signed compare
    // SSE2 has no unsigned compare; use: (data XOR 0x80) < (threshold XOR 0x80) via pcmpgtb
    movdqa xmm2, xmm0       // xmm2 = threshold broadcast
    movdqa xmm3, xmm1       // xmm3 = data
    // flip sign bits for unsigned comparison
    pcmpeqd xmm4, xmm4      // xmm4 = all 1s
    psllw xmm4, 7
    packsswb xmm4, xmm4     // xmm4 = 0x80 broadcast
    pxor xmm2, xmm4         // threshold ^ 0x80
    pxor xmm3, xmm4         // data ^ 0x80
    pcmpgtb xmm2, xmm3      // (threshold^0x80) > (data^0x80) ≡ data < threshold (unsigned)
    pmovmskb eax, xmm2
    mov Result, ax
  end;
end;

function Vec16CmpGtU(AData: PByte; AThreshold: Byte): TMask16; inline;
begin
  Result := 0;
  asm
    movzx eax, AThreshold
    movd xmm0, eax
    punpcklbw xmm0, xmm0
    pshuflw xmm0, xmm0, 0
    punpcklqdq xmm0, xmm0
    mov rax, AData
    movdqu xmm1, [rax]
    // data > threshold (unsigned): flip sign bits, then signed gt
    pcmpeqd xmm4, xmm4
    psllw xmm4, 7
    packsswb xmm4, xmm4     // xmm4 = 0x80
    movdqa xmm2, xmm1       // data
    pxor xmm2, xmm4         // data ^ 0x80
    pxor xmm0, xmm4         // threshold ^ 0x80
    pcmpgtb xmm2, xmm0      // (data^0x80) > (threshold^0x80)
    pmovmskb eax, xmm2
    mov Result, ax
  end;
end;

function Vec16CmpRange(AData: PByte; ALo, AHi: Byte): TMask16; inline;
begin
  Result := 0;
  asm
    mov rax, AData
    movdqu xmm0, [rax]
    // range check: (data - ALo) <= (AHi - ALo) unsigned
    movzx edx, ALo
    movd xmm1, edx
    punpcklbw xmm1, xmm1
    pshuflw xmm1, xmm1, 0
    punpcklqdq xmm1, xmm1   // xmm1 = broadcast(ALo)
    movdqa xmm2, xmm0
    psubb xmm2, xmm1        // xmm2 = data - ALo (wrapping)
    // broadcast (AHi - ALo)
    movzx edx, AHi
    movzx ecx, ALo
    sub edx, ecx             // edx = AHi - ALo
    movd xmm3, edx
    punpcklbw xmm3, xmm3
    pshuflw xmm3, xmm3, 0
    punpcklqdq xmm3, xmm3   // xmm3 = broadcast(AHi - ALo)
    // unsigned (data-ALo) <= (AHi-ALo): pminub(data-ALo, limit) == data-ALo
    movdqa xmm4, xmm2       // copy data-ALo
    pminub xmm4, xmm3       // min(data-ALo, limit)
    pcmpeqb xmm4, xmm2      // min == data-ALo means data-ALo <= limit
    pmovmskb eax, xmm4
    mov Result, ax
  end;
end;

function Vec16Ctz(AMask: TMask16): Int32; inline;
begin
  if AMask = 0 then
    Result := -1
  else
  begin
    Result := 0;
    asm
      movzx eax, AMask
      bsf eax, eax
      mov Result, eax
    end;
  end;
end;

function Vec16Popcnt(AMask: TMask16): Int32; inline;
var
  m: UInt32;
begin
  m := AMask;
  m := m - ((m shr 1) and $5555);
  m := (m and $3333) + ((m shr 2) and $3333);
  m := (m + (m shr 4)) and $0F0F;
  Result := Int32((m + (m shr 8)) and $FF);
end;

procedure Vec16AddWhere(AData: PByte; AMask: TMask16; ADelta: Byte); inline;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then
      AData[i] := AData[i] + ADelta;
end;

procedure Vec16SubWhere(AData: PByte; AMask: TMask16; ADelta: Byte); inline;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then
      AData[i] := AData[i] - ADelta;
end;
