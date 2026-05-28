// === Reduction Operations ===

function NEONReduceAddF32x4(const a: TVecF32x4): Single;
begin
  Result := ScalarReduceAddF32x4(a);
end;

function NEONReduceMinF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 3 do
    if a.f[i] < Result then
      Result := a.f[i];
end;

function NEONReduceMaxF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 3 do
    if a.f[i] > Result then
      Result := a.f[i];
end;

function NEONReduceMulF32x4(const a: TVecF32x4): Single;
begin
  Result := ScalarReduceMulF32x4(a);
end;

// I32x4/U32x4 reduction dead residue removed: no register/facade/runtime consumer.
