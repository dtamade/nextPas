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
  if ALo > AHi then begin Result := 0; Exit; end;
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
  lo, hi: DWord;
begin
  lo := DWord(QWord(AMask));
  hi := DWord(QWord(AMask) shr 32);
  lo := lo - ((lo shr 1) and DWord($55555555));
  lo := (lo and DWord($33333333)) + ((lo shr 2) and DWord($33333333));
  lo := (lo + (lo shr 4)) and DWord($0F0F0F0F);
  lo := lo + (lo shr 8);
  lo := lo + (lo shr 16);
  hi := hi - ((hi shr 1) and DWord($55555555));
  hi := (hi and DWord($33333333)) + ((hi shr 2) and DWord($33333333));
  hi := (hi + (hi shr 4)) and DWord($0F0F0F0F);
  hi := hi + (hi shr 8);
  hi := hi + (hi shr 16);
  Result := Int32((lo and $3F) + (hi and $3F));
end;

procedure Vec64AddWhere(AData: PByte; AMask: TMask64; ADelta: Byte); inline;
var
  i: Integer;
begin
  {$PUSH}{$R-}{$Q-}
  for i := 0 to 63 do
    if (AMask and (QWord(1) shl i)) <> 0 then
      AData[i] := AData[i] + ADelta;
  {$POP}
end;

procedure Vec64SubWhere(AData: PByte; AMask: TMask64; ADelta: Byte); inline;
var
  i: Integer;
begin
  {$PUSH}{$R-}{$Q-}
  for i := 0 to 63 do
    if (AMask and (QWord(1) shl i)) <> 0 then
      AData[i] := AData[i] - ADelta;
  {$POP}
end;
