{
  This file is extracted from scalar.pas (non-shift functions)
  Maintained by simdgen integration process
}

function ScalarAddI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] + b.i[i];
end;

function ScalarSubI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] - b.i[i];
end;

function ScalarMulI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] * b.i[i];
end;

function ScalarAndI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] and b.i[i];
end;

function ScalarOrI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] or b.i[i];
end;

function ScalarXorI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] xor b.i[i];
end;

function ScalarNotI32x16(const a: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := not a.i[i];
end;

function ScalarAndNotI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 15 do
    Result.i[i] := (not a.i[i]) and b.i[i];
end;

function ScalarCmpEqI32x16(const a, b: TVecI32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] = b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtI32x16(const a, b: TVecI32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] < b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtI32x16(const a, b: TVecI32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] > b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeI32x16(const a, b: TVecI32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] <= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeI32x16(const a, b: TVecI32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] >= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeI32x16(const a, b: TVecI32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] <> b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] < b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

function ScalarMaxI32x16(const a, b: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] > b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

function ScalarAddI64x8(const a, b: TVecI64x8): TVecI64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] + b.i[i];
end;

function ScalarSubI64x8(const a, b: TVecI64x8): TVecI64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] - b.i[i];
end;

function ScalarAndI64x8(const a, b: TVecI64x8): TVecI64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] and b.i[i];
end;

function ScalarOrI64x8(const a, b: TVecI64x8): TVecI64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] or b.i[i];
end;

function ScalarXorI64x8(const a, b: TVecI64x8): TVecI64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] xor b.i[i];
end;

function ScalarNotI64x8(const a: TVecI64x8): TVecI64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := not a.i[i];
end;

function ScalarCmpEqI64x8(const a, b: TVecI64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] = b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtI64x8(const a, b: TVecI64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] < b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtI64x8(const a, b: TVecI64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] > b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeI64x8(const a, b: TVecI64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] <= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeI64x8(const a, b: TVecI64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] >= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeI64x8(const a, b: TVecI64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] <> b.i[i] then
      Result := Result or (1 shl i);
end;
