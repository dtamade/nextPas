// Scalar fallback implementation of vec64 primitives (64 bytes)

function Vec64CmpEq(AData: PByte; AValue: Byte): TMask64; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 63 do
    if AData[i] = AValue then
      Result := Result or TMask64(QWord(1) shl i);
end;

function Vec64CmpEq2(AData, APattern: PByte): TMask64; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 63 do
    if AData[i] = APattern[i] then
      Result := Result or TMask64(QWord(1) shl i);
end;

function Vec64CmpLtU(AData: PByte; AThreshold: Byte): TMask64; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 63 do
    if AData[i] < AThreshold then
      Result := Result or TMask64(QWord(1) shl i);
end;

function Vec64CmpGtU(AData: PByte; AThreshold: Byte): TMask64; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 63 do
    if AData[i] > AThreshold then
      Result := Result or TMask64(QWord(1) shl i);
end;

function Vec64CmpRange(AData: PByte; ALo, AHi: Byte): TMask64; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 63 do
    if (AData[i] >= ALo) and (AData[i] <= AHi) then
      Result := Result or TMask64(QWord(1) shl i);
end;

function Vec64Ctz(AMask: TMask64): Int32; inline;
var
  i: Integer;
begin
  if AMask = 0 then Exit(-1);
  for i := 0 to 63 do
    if (AMask and (QWord(1) shl i)) <> 0 then Exit(i);
  Result := -1;
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
