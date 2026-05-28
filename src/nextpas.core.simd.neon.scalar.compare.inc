// === Comparison Operations ===

function NEONCmpEqF32x4(const a, b: TVecF32x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.f[i] = b.f[i] then
      Result := Result or (1 shl i);
end;

function NEONCmpLtF32x4(const a, b: TVecF32x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.f[i] < b.f[i] then
      Result := Result or (1 shl i);
end;

function NEONCmpLeF32x4(const a, b: TVecF32x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.f[i] <= b.f[i] then
      Result := Result or (1 shl i);
end;

function NEONCmpGtF32x4(const a, b: TVecF32x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.f[i] > b.f[i] then
      Result := Result or (1 shl i);
end;

function NEONCmpGeF32x4(const a, b: TVecF32x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.f[i] >= b.f[i] then
      Result := Result or (1 shl i);
end;

function NEONCmpNeF32x4(const a, b: TVecF32x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.f[i] <> b.f[i] then
      Result := Result or (1 shl i);
end;

