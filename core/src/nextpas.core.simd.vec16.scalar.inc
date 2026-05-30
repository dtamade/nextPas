// Scalar fallback implementation of vec16 primitives
// Used on platforms without specialized SIMD support

function Vec16CmpEq(AData: PByte; AValue: Byte): TMask16; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if AData[i] = AValue then
      Result := Result or TMask16(1 shl i);
end;

function Vec16CmpEq2(AData, APattern: PByte): TMask16; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if AData[i] = APattern[i] then
      Result := Result or TMask16(1 shl i);
end;

function Vec16CmpLtU(AData: PByte; AThreshold: Byte): TMask16; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if AData[i] < AThreshold then
      Result := Result or TMask16(1 shl i);
end;

function Vec16CmpGtU(AData: PByte; AThreshold: Byte): TMask16; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if AData[i] > AThreshold then
      Result := Result or TMask16(1 shl i);
end;

function Vec16CmpRange(AData: PByte; ALo, AHi: Byte): TMask16; inline;
var
  i: Integer;
begin
  if ALo > AHi then begin Result := 0; Exit; end;
  Result := 0;
  for i := 0 to 15 do
    if (AData[i] >= ALo) and (AData[i] <= AHi) then
      Result := Result or TMask16(1 shl i);
end;

function Vec16Ctz(AMask: TMask16): Int32; inline;
var
  i: Integer;
begin
  if AMask = 0 then Exit(-1);
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then Exit(i);
  Result := -1;
end;

function Vec16FirstSet(AMask: TMask16): Int32; inline;
begin
  Result := Vec16Ctz(AMask);
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
  {$PUSH}{$R-}{$Q-}
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then
      AData[i] := AData[i] + ADelta;
  {$POP}
end;

procedure Vec16SubWhere(AData: PByte; AMask: TMask16; ADelta: Byte); inline;
var
  i: Integer;
begin
  {$PUSH}{$R-}{$Q-}
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then
      AData[i] := AData[i] - ADelta;
  {$POP}
end;

procedure Vec16ProbeGroup(AData: PByte; AH2: Byte; out AMatchMask, AEmptyMask: TMask16); inline;
var i: Integer;
begin
  AMatchMask := 0;
  AEmptyMask := 0;
  for i := 0 to 15 do
  begin
    if AData[i] = AH2 then AMatchMask := AMatchMask or TMask16(1 shl i);
    if AData[i] = $FF then AEmptyMask := AEmptyMask or TMask16(1 shl i);
  end;
end;
