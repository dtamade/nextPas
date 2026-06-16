// === Narrow Integer Operations ===

// ============================================================================
// I16x8 Operations (16 functions)
// ============================================================================

function ScalarAddI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] + b.i[i];
end;

function ScalarSubI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] - b.i[i];
end;

function ScalarMulI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] * b.i[i];
end;

function ScalarAndI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] and b.i[i];
end;

function ScalarOrI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] or b.i[i];
end;

function ScalarXorI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] xor b.i[i];
end;

function ScalarNotI16x8(const a: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := not a.i[i];
end;

function ScalarAndNotI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 7 do
    Result.i[i] := (not a.i[i]) and b.i[i];
end;

function ScalarShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      Result.i[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] shl count;
  end
  else
    Result := a;
end;

function ScalarShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      Result.i[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.i[i] := Int16(UInt16(a.i[i]) shr count);
  end
  else
    Result := a;
end;

function ScalarShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] shr count;
  end
  else
    Result := a;
end;

function ScalarCmpEqI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] = b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] < b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] > b.i[i] then
      Result := Result or (1 shl i);
end;

// CmpLe/CmpGe/CmpNe for I16x8
function ScalarCmpLeI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] <= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] >= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] <> b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.i[i] < b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

function ScalarMaxI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.i[i] > b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

// ============================================================================
// I8x16 Operations (12 functions)
// ============================================================================

function ScalarAddI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] + b.i[i];
end;

function ScalarSubI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] - b.i[i];
end;

function ScalarAndI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] and b.i[i];
end;

function ScalarOrI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] or b.i[i];
end;

function ScalarXorI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] xor b.i[i];
end;

function ScalarNotI8x16(const a: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := not a.i[i];
end;

function ScalarAndNotI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 15 do
    Result.i[i] := (not a.i[i]) and b.i[i];
end;

function ScalarCmpEqI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] = b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] < b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] > b.i[i] then
      Result := Result or (1 shl i);
end;

// CmpLe/CmpGe/CmpNe for I8x16
function ScalarCmpLeI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] <= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] >= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] <> b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] < b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

function ScalarMaxI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] > b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;
