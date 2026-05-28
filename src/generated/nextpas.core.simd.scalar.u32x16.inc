{
  This file is extracted from scalar.pas (non-shift functions)
  Maintained by simdgen integration process
}

function ScalarAddU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarMulU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] * b.u[i];
end;

function ScalarAndU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU32x16(const a: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarCmpEqU32x16(const a, b: TVecU32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU32x16(const a, b: TVecU32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU32x16(const a, b: TVecU32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeU32x16(const a, b: TVecU32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU32x16(const a, b: TVecU32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU32x16(const a, b: TVecU32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU32x16(const a, b: TVecU32x16): TVecU32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;
