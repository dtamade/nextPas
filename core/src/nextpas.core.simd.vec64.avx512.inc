// AVX-512 implementation of vec64 primitives (zmm, 64 bytes)

function Vec64CmpEq(AData: PByte; AValue: Byte): TMask64; inline;
begin
  Result := 0;
  asm
    movzx eax, AValue
    vpbroadcastb zmm0, eax
    mov rax, AData
    vmovdqu8 zmm1, [rax]
    vpcmpeqb k1, zmm1, zmm0
    kmovq Result, k1
    vzeroupper
  end;
end;

function Vec64CmpEq2(AData, APattern: PByte): TMask64; inline;
begin
  Result := 0;
  asm
    mov rax, AData
    mov rdx, APattern
    vmovdqu8 zmm0, [rax]
    vmovdqu8 zmm1, [rdx]
    vpcmpeqb k1, zmm0, zmm1
    kmovq Result, k1
    vzeroupper
  end;
end;

function Vec64CmpLtU(AData: PByte; AThreshold: Byte): TMask64; inline;
begin
  Result := 0;
  asm
    movzx eax, AThreshold
    vpbroadcastb zmm0, eax     // zmm0 = broadcast(threshold)
    mov rax, AData
    vmovdqu8 zmm1, [rax]      // zmm1 = data
    vpcmpub k1, zmm1, zmm0, 1 // k1 = data < threshold (unsigned lt = predicate 1)
    kmovq Result, k1
    vzeroupper
  end;
end;

function Vec64CmpGtU(AData: PByte; AThreshold: Byte): TMask64; inline;
begin
  Result := 0;
  asm
    movzx eax, AThreshold
    vpbroadcastb zmm0, eax
    mov rax, AData
    vmovdqu8 zmm1, [rax]
    vpcmpub k1, zmm1, zmm0, 6 // k1 = data > threshold (unsigned gt = predicate 6)
    kmovq Result, k1
    vzeroupper
  end;
end;

function Vec64CmpRange(AData: PByte; ALo, AHi: Byte): TMask64; inline;
begin
  Result := 0;
  asm
    mov rax, AData
    vmovdqu8 zmm0, [rax]
    movzx edx, ALo
    vpbroadcastb zmm1, edx     // zmm1 = broadcast(ALo)
    vpsubb zmm2, zmm0, zmm1   // zmm2 = data - ALo (wrapping)
    movzx edx, AHi
    movzx ecx, ALo
    sub edx, ecx              // edx = AHi - ALo
    vpbroadcastb zmm3, edx    // zmm3 = broadcast(limit)
    vpcmpub k1, zmm2, zmm3, 2 // k1 = (data-ALo) <= limit (unsigned le = predicate 2)
    kmovq Result, k1
    vzeroupper
  end;
end;

function Vec64Ctz(AMask: TMask64): Int32; inline;
begin
  if AMask = 0 then
    Result := -1
  else
  begin
    Result := 0;
    asm
      mov rax, AMask
      bsf rax, rax
      mov Result, eax
    end;
  end;
end;

function Vec64Popcnt(AMask: TMask64): Int32; inline;
var
  m: QWord;
begin
  m := AMask;
  m := m - ((m shr 1) and QWord($5555555555555555));
  m := (m and QWord($3333333333333333)) + ((m shr 2) and QWord($3333333333333333));
  m := (m + (m shr 4)) and QWord($0F0F0F0F0F0F0F0F);
  Result := Int32((m * QWord($0101010101010101)) shr 56);
end;

procedure Vec64AddWhere(AData: PByte; AMask: TMask64; ADelta: Byte); inline;
var
  i: Integer;
begin
  for i := 0 to 63 do
    if (AMask and (QWord(1) shl i)) <> 0 then
      AData[i] := AData[i] + ADelta;
end;

procedure Vec64SubWhere(AData: PByte; AMask: TMask64; ADelta: Byte); inline;
var
  i: Integer;
begin
  for i := 0 to 63 do
    if (AMask and (QWord(1) shl i)) <> 0 then
      AData[i] := AData[i] - ADelta;
end;
