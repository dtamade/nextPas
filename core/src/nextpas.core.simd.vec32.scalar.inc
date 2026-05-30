// Scalar fallback implementation of vec32 primitives (32 bytes)

function Vec32CmpEq(AData: PByte; AValue: Byte): TMask32; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 31 do
    if AData[i] = AValue then
      Result := Result or TMask32(DWord(1) shl i);
end;

function Vec32CmpEq2(AData, APattern: PByte): TMask32; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 31 do
    if AData[i] = APattern[i] then
      Result := Result or TMask32(DWord(1) shl i);
end;

function Vec32CmpLtU(AData: PByte; AThreshold: Byte): TMask32; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 31 do
    if AData[i] < AThreshold then
      Result := Result or TMask32(DWord(1) shl i);
end;

function Vec32CmpGtU(AData: PByte; AThreshold: Byte): TMask32; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 31 do
    if AData[i] > AThreshold then
      Result := Result or TMask32(DWord(1) shl i);
end;

function Vec32CmpRange(AData: PByte; ALo, AHi: Byte): TMask32; inline;
var
  i: Integer;
begin
  if ALo > AHi then begin Result := 0; Exit; end;
  Result := 0;
  for i := 0 to 31 do
    if (AData[i] >= ALo) and (AData[i] <= AHi) then
      Result := Result or TMask32(DWord(1) shl i);
end;

function Vec32Ctz(AMask: TMask32): Int32; inline;
var
  i: Integer;
begin
  if AMask = 0 then Exit(-1);
  for i := 0 to 31 do
    if (AMask and (DWord(1) shl i)) <> 0 then Exit(i);
  Result := -1;
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
