// AVX2 implementation of vec32 primitives (ymm, 32 bytes)

function Vec32CmpEq(AData: PByte; AValue: Byte): TMask32; inline;
begin
  Result := 0;
  asm
    movzx eax, AValue
    vmovd xmm0, eax
    vpbroadcastb ymm0, xmm0
    mov rax, AData
    vmovdqu ymm1, [rax]
    vpcmpeqb ymm1, ymm1, ymm0
    vpmovmskb eax, ymm1
    mov Result, eax
    vzeroupper
  end;
end;

function Vec32CmpEq2(AData, APattern: PByte): TMask32; inline;
begin
  Result := 0;
  asm
    mov rax, AData
    mov rdx, APattern
    vmovdqu ymm0, [rax]
    vmovdqu ymm1, [rdx]
    vpcmpeqb ymm0, ymm0, ymm1
    vpmovmskb eax, ymm0
    mov Result, eax
    vzeroupper
  end;
end;

function Vec32CmpLtU(AData: PByte; AThreshold: Byte): TMask32; inline;
begin
  Result := 0;
  asm
    mov rax, AData
    vmovdqu ymm1, [rax]       // ymm1 = data
    // data < threshold: use vpmaxub(data, threshold) != data
    movzx edx, AThreshold
    vmovd xmm0, edx
    vpbroadcastb ymm0, xmm0   // ymm0 = broadcast(threshold)
    vpmaxub ymm2, ymm1, ymm0  // max(data, threshold)
    vpcmpeqb ymm2, ymm2, ymm1 // max == data means data >= threshold
    vpcmpeqb ymm3, ymm3, ymm3 // all ones
    vpxor ymm2, ymm2, ymm3    // invert: data < threshold
    vpmovmskb eax, ymm2
    mov Result, eax
    vzeroupper
  end;
end;

function Vec32CmpGtU(AData: PByte; AThreshold: Byte): TMask32; inline;
begin
  Result := 0;
  asm
    movzx eax, AThreshold
    vmovd xmm0, eax
    vpbroadcastb ymm0, xmm0   // ymm0 = broadcast(threshold)
    mov rax, AData
    vmovdqu ymm1, [rax]       // ymm1 = data
    // data > threshold: use vpmaxub(data, threshold) != threshold
    vpmaxub ymm2, ymm1, ymm0  // max(data, threshold)
    vpcmpeqb ymm2, ymm2, ymm0 // max == threshold means data <= threshold
    // invert: we want data > threshold
    vpcmpeqb ymm3, ymm3, ymm3 // all ones
    vpxor ymm2, ymm2, ymm3    // invert
    vpmovmskb eax, ymm2
    mov Result, eax
    vzeroupper
  end;
end;

function Vec32CmpRange(AData: PByte; ALo, AHi: Byte): TMask32; inline;
begin
  if ALo > AHi then begin Result := 0; Exit; end;
  Result := 0;
  asm
    mov rax, AData
    vmovdqu ymm0, [rax]
    // range: (data - ALo) <= (AHi - ALo) unsigned
    movzx edx, ALo
    vmovd xmm1, edx
    vpbroadcastb ymm1, xmm1   // ymm1 = broadcast(ALo)
    vpsubb ymm2, ymm0, ymm1   // ymm2 = data - ALo (wrapping)
    movzx edx, AHi
    movzx ecx, ALo
    sub edx, ecx              // edx = AHi - ALo
    vmovd xmm3, edx
    vpbroadcastb ymm3, xmm3   // ymm3 = broadcast(AHi - ALo)
    vpminub ymm4, ymm2, ymm3  // min(data-ALo, limit)
    vpcmpeqb ymm4, ymm4, ymm2 // min == data-ALo means in range
    vpmovmskb eax, ymm4
    mov Result, eax
    vzeroupper
  end;
end;

function Vec32Ctz(AMask: TMask32): Int32; inline;
begin
  if AMask = 0 then
    Result := -1
  else
  begin
    Result := 0;
    asm
      mov eax, AMask
      bsf eax, eax
      mov Result, eax
    end;
  end;
end;

function Vec32FirstSet(AMask: TMask32): Int32; inline;
begin
  Result := Vec32Ctz(AMask);
end;

function Vec32Popcnt(AMask: TMask32): Int32; inline;
var
  m: DWord;
begin
  m := DWord(AMask);
  m := m - ((m shr 1) and DWord($55555555));
  m := (m and DWord($33333333)) + ((m shr 2) and DWord($33333333));
  m := (m + (m shr 4)) and DWord($0F0F0F0F);
  m := m + (m shr 8);
  m := m + (m shr 16);
  Result := Int32(m and $3F);
end;

procedure Vec32AddWhere(AData: PByte; AMask: TMask32; ADelta: Byte); inline;
var
  i: Integer;
begin
  {$PUSH}{$R-}{$Q-}
  for i := 0 to 31 do
    if (AMask and (DWord(1) shl i)) <> 0 then
      AData[i] := AData[i] + ADelta;
  {$POP}
end;

procedure Vec32SubWhere(AData: PByte; AMask: TMask32; ADelta: Byte); inline;
var
  i: Integer;
begin
  {$PUSH}{$R-}{$Q-}
  for i := 0 to 31 do
    if (AMask and (DWord(1) shl i)) <> 0 then
      AData[i] := AData[i] - ADelta;
  {$POP}
end;
