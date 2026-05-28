// === Vector Math Operations ===

function NEONDotF32x4(const a, b: TVecF32x4): Single;
begin
  Result := ScalarDotF32x4(a, b);
end;

function NEONDotF32x3(const a, b: TVecF32x4): Single;
begin
  Result := ScalarDotF32x3(a, b);
end;

function NEONCrossF32x3(const a, b: TVecF32x4): TVecF32x4;
begin
  Result := ScalarCrossF32x3(a, b);
end;

function NEONLengthF32x4(const a: TVecF32x4): Single;
begin
  Result := ScalarLengthF32x4(a);
end;

function NEONLengthF32x3(const a: TVecF32x4): Single;
begin
  Result := ScalarLengthF32x3(a);
end;

function NEONNormalizeF32x4(const a: TVecF32x4): TVecF32x4;
begin
  Result := ScalarNormalizeF32x4(a);
end;

function NEONNormalizeF32x3(const a: TVecF32x4): TVecF32x4;
begin
  Result := ScalarNormalizeF32x3(a);
end;
