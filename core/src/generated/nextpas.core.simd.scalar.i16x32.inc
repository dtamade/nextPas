{
  This file is extracted from scalar.pas (non-shift functions)
  Maintained by simdgen integration process
}

function ScalarAddI16x32(const a, b: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    Result.i[i] := a.i[i] + b.i[i];
end;

function ScalarSubI16x32(const a, b: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    Result.i[i] := a.i[i] - b.i[i];
end;

function ScalarAndI16x32(const a, b: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    Result.i[i] := a.i[i] and b.i[i];
end;

function ScalarOrI16x32(const a, b: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    Result.i[i] := a.i[i] or b.i[i];
end;

function ScalarXorI16x32(const a, b: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    Result.i[i] := a.i[i] xor b.i[i];
end;

function ScalarNotI16x32(const a: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    Result.i[i] := not a.i[i];
end;

function ScalarAndNotI16x32(const a, b: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    Result.i[i] := (not a.i[i]) and b.i[i];
end;

function ScalarCmpEqI16x32(const a, b: TVecI16x32): TMask32;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 31 do
    if a.i[i] = b.i[i] then
      Result := Result or TMask32(DWord(1) shl i);
end;

function ScalarCmpLtI16x32(const a, b: TVecI16x32): TMask32;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 31 do
    if a.i[i] < b.i[i] then
      Result := Result or TMask32(DWord(1) shl i);
end;

function ScalarCmpGtI16x32(const a, b: TVecI16x32): TMask32;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 31 do
    if a.i[i] > b.i[i] then
      Result := Result or TMask32(DWord(1) shl i);
end;

function ScalarMinI16x32(const a, b: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    if a.i[i] < b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

function ScalarMaxI16x32(const a, b: TVecI16x32): TVecI16x32;
var i: Integer;
begin
  for i := 0 to 31 do
    if a.i[i] > b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;
