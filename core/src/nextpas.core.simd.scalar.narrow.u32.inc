// ============================================================================
// U32x4 Operations (17 functions)
// ============================================================================

function ScalarAddU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarMulU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] * b.u[i];
end;

function ScalarAndU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU32x4(const a: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
var
  i: Integer;
begin
  if count >= 32 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shl count;
  end
  else
    Result := a;
end;

function ScalarShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
var
  i: Integer;
begin
  if count >= 32 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shr count;
  end
  else
    Result := a;
end;

function ScalarCmpEqU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU32x4(const a, b: TVecU32x4): TMask4;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to 3 do
    if a.u[LIndex] <> b.u[LIndex] then
      Result := Result or (1 shl LIndex);
end;

function ScalarMinU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

// ============================================================================
// U32x8 Operations (256-bit, 8x32-bit unsigned)
// ============================================================================

function ScalarAddU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarMulU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] * b.u[i];
end;

function ScalarAndU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU32x8(const a: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 7 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
var i: Integer;
begin
  if count >= 32 then
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

function ScalarShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
var i: Integer;
begin
  if count >= 32 then
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

function ScalarCmpEqU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;
