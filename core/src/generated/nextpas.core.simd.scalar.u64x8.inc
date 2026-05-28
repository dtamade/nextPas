{
  This file is extracted from scalar.pas (non-shift functions)
  Maintained by simdgen integration process
}

function ScalarAddU64x8(const a, b: TVecU64x8): TVecU64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU64x8(const a, b: TVecU64x8): TVecU64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarAndU64x8(const a, b: TVecU64x8): TVecU64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU64x8(const a, b: TVecU64x8): TVecU64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU64x8(const a, b: TVecU64x8): TVecU64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU64x8(const a: TVecU64x8): TVecU64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := not a.u[i];
end;

function ScalarCmpEqU64x8(const a, b: TVecU64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU64x8(const a, b: TVecU64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU64x8(const a, b: TVecU64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeU64x8(const a, b: TVecU64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU64x8(const a, b: TVecU64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU64x8(const a, b: TVecU64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;
