// === Reduction Operations ===

function ScalarReduceAddF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 3 do
    Result := Result + a.f[i];
end;

function ScalarReduceMinF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 3 do
    Result := SimdMin(Result, a.f[i]);
end;

function ScalarReduceMaxF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 3 do
    Result := SimdMax(Result, a.f[i]);
end;

function ScalarReduceMulF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 3 do
    Result := Result * a.f[i];
end;

// === Wide Vector Reduction Operations ===

// F64x2 Reduction
function ScalarReduceAddF64x2(const a: TVecF64x2): Double;
begin
  Result := a.d[0] + a.d[1];
end;

function ScalarReduceMinF64x2(const a: TVecF64x2): Double;
begin
  Result := SimdMin(a.d[0], a.d[1]);
end;

function ScalarReduceMaxF64x2(const a: TVecF64x2): Double;
begin
  Result := SimdMax(a.d[0], a.d[1]);
end;

function ScalarReduceMulF64x2(const a: TVecF64x2): Double;
begin
  Result := a.d[0] * a.d[1];
end;

// F32x8 Reduction
function ScalarReduceAddF32x8(const a: TVecF32x8): Single;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 7 do
    Result := Result + a.f[i];
end;

function ScalarReduceMinF32x8(const a: TVecF32x8): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 7 do
    Result := SimdMin(Result, a.f[i]);
end;

function ScalarReduceMaxF32x8(const a: TVecF32x8): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 7 do
    Result := SimdMax(Result, a.f[i]);
end;

function ScalarReduceMulF32x8(const a: TVecF32x8): Single;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 7 do
    Result := Result * a.f[i];
end;

// F64x4 Reduction
function ScalarReduceAddF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 3 do
    Result := Result + a.d[i];
end;

function ScalarReduceMinF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 3 do
    Result := SimdMin(Result, a.d[i]);
end;

function ScalarReduceMaxF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 3 do
    Result := SimdMax(Result, a.d[i]);
end;

function ScalarReduceMulF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 3 do
    Result := Result * a.d[i];
end;

// F32x16 (512-bit)
function ScalarReduceAddF32x16(const a: TVecF32x16): Single;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 15 do
    Result := Result + a.f[i];
end;

function ScalarReduceMinF32x16(const a: TVecF32x16): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 15 do
    Result := SimdMin(Result, a.f[i]);
end;

function ScalarReduceMaxF32x16(const a: TVecF32x16): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 15 do
    Result := SimdMax(Result, a.f[i]);
end;

function ScalarReduceMulF32x16(const a: TVecF32x16): Single;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 15 do
    Result := Result * a.f[i];
end;

// F64x8 (512-bit)
function ScalarReduceAddF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 7 do
    Result := Result + a.d[i];
end;

function ScalarReduceMinF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 7 do
    Result := SimdMin(Result, a.d[i]);
end;

function ScalarReduceMaxF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 7 do
    Result := SimdMax(Result, a.d[i]);
end;

function ScalarReduceMulF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 7 do
    Result := Result * a.d[i];
end;

