// ============================================================================
// U16x8 Operations (15 functions)
// ============================================================================

function ScalarAddU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarMulU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] * b.u[i];
end;

function ScalarAndU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU16x8(const a: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 7 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shl count;
  end
  else
    Result := a;
end;

function ScalarShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shr count;
  end
  else
    Result := a;
end;

function ScalarCmpEqU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

// CmpLe/CmpGe/CmpNe for U16x8
function ScalarCmpLeU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

// ============================================================================
// U8x16 Operations (12 functions)
// ============================================================================

function ScalarAddU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarAndU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU8x16(const a: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 15 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarCmpEqU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

// CmpLe/CmpGe/CmpNe for U8x16
function ScalarCmpLeU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

{$POP}
