// === Extended Math Operations ===

function NEONFloorF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdFloor(a.f[i]);
end;

function NEONCeilF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdCeil(a.f[i]);
end;

function NEONRoundF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdRound(a.f[i]);
end;

function NEONTruncF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdTruncFloat(a.f[i]);
end;

function NEONClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    if a.f[i] < minVal.f[i] then
      Result.f[i] := minVal.f[i]
    else if a.f[i] > maxVal.f[i] then
      Result.f[i] := maxVal.f[i]
    else
      Result.f[i] := a.f[i];
  end;
end;
