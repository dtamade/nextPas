// === Math Functions ===

function ScalarAbsF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Abs(a.f[i]);
end;

function ScalarSqrtF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Sqrt(a.f[i]);
end;

function ScalarMinF32x4(const a, b: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdMin(a.f[i], b.f[i]);
end;

function ScalarMaxF32x4(const a, b: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdMax(a.f[i], b.f[i]);
end;

// === Extended Math Functions ===

function ScalarFmaF32x4(const a, b, c: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := a.f[i] * b.f[i] + c.f[i];
end;

function ScalarRcpF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := 1.0 / a.f[i];
end;

function ScalarRsqrtF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := 1.0 / Sqrt(a.f[i]);
end;

function ScalarFloorF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := SimdFloor(a.f[i]);
  end;
end;

function ScalarCeilF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := SimdCeil(a.f[i]);
  end;
end;

function ScalarRoundF32x4(const a: TVecF32x4): TVecF32x4;
var
  i: Integer;
  LRounded: Single;
begin
  for i := 0 to 3 do
  begin
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LRounded := SimdRound(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LRounded);
    end;
  end;
end;

function ScalarTruncF32x4(const a: TVecF32x4): TVecF32x4;
var
  i: Integer;
  LTrunced: Single;
begin
  for i := 0 to 3 do
  begin
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LTrunced := SimdTruncFloat(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LTrunced);
    end;
  end;
end;

function ScalarClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdMax(minVal.f[i], SimdMin(a.f[i], maxVal.f[i]));
end;

// === Wide Vector Math Functions ===

// F64x2 Math
function ScalarAbsF64x2(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := Abs(a.d[0]);
  Result.d[1] := Abs(a.d[1]);
end;

function ScalarSqrtF64x2(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := Sqrt(a.d[0]);
  Result.d[1] := Sqrt(a.d[1]);
end;

function ScalarMinF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := SimdMin(a.d[0], b.d[0]);
  Result.d[1] := SimdMin(a.d[1], b.d[1]);
end;

function ScalarMaxF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := SimdMax(a.d[0], b.d[0]);
  Result.d[1] := SimdMax(a.d[1], b.d[1]);
end;

function ScalarClampF64x2(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := SimdMax(minVal.d[0], SimdMin(a.d[0], maxVal.d[0]));
  Result.d[1] := SimdMax(minVal.d[1], SimdMin(a.d[1], maxVal.d[1]));
end;

// F32x8 Math
function ScalarAbsF32x8(const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := Abs(a.f[i]);
end;

function ScalarSqrtF32x8(const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := Sqrt(a.f[i]);
end;

function ScalarMinF32x8(const a, b: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := SimdMin(a.f[i], b.f[i]);
end;

function ScalarMaxF32x8(const a, b: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := SimdMax(a.f[i], b.f[i]);
end;

function ScalarClampF32x8(const a, minVal, maxVal: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := SimdMax(minVal.f[i], SimdMin(a.f[i], maxVal.f[i]));
end;

// F64x4 Math
function ScalarAbsF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := Abs(a.d[i]);
end;

function ScalarSqrtF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := Sqrt(a.d[i]);
end;

function ScalarMinF64x4(const a, b: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := SimdMin(a.d[i], b.d[i]);
end;

function ScalarMaxF64x4(const a, b: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := SimdMax(a.d[i], b.d[i]);
end;

function ScalarClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := SimdMax(minVal.d[i], SimdMin(a.d[i], maxVal.d[i]));
end;

// F32x16 (512-bit)
function ScalarAbsF32x16(const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := Abs(a.f[i]);
end;

function ScalarSqrtF32x16(const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := Sqrt(a.f[i]);
end;

function ScalarMinF32x16(const a, b: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := SimdMin(a.f[i], b.f[i]);
end;

function ScalarMaxF32x16(const a, b: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := SimdMax(a.f[i], b.f[i]);
end;

function ScalarClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := SimdMax(minVal.f[i], SimdMin(a.f[i], maxVal.f[i]));
end;

// F64x8 (512-bit)
function ScalarAbsF64x8(const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := Abs(a.d[i]);
end;

function ScalarSqrtF64x8(const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := Sqrt(a.d[i]);
end;

function ScalarMinF64x8(const a, b: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := SimdMin(a.d[i], b.d[i]);
end;

function ScalarMaxF64x8(const a, b: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := SimdMax(a.d[i], b.d[i]);
end;

function ScalarClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := SimdMax(minVal.d[i], SimdMin(a.d[i], maxVal.d[i]));
end;

// === Wide Vector Extended Math Functions ===

// F64x2 (128-bit)
function ScalarFmaF64x2(const a, b, c: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := a.d[0] * b.d[0] + c.d[0];
  Result.d[1] := a.d[1] * b.d[1] + c.d[1];
end;

function ScalarFloorF64x2(const a: TVecF64x2): TVecF64x2;
begin
  if SimdIsNaN(a.d[0]) or SimdIsInfinite(a.d[0]) then
    Result.d[0] := a.d[0]
  else
    Result.d[0] := SimdFloor(a.d[0]);

  if SimdIsNaN(a.d[1]) or SimdIsInfinite(a.d[1]) then
    Result.d[1] := a.d[1]
  else
    Result.d[1] := SimdFloor(a.d[1]);
end;

function ScalarCeilF64x2(const a: TVecF64x2): TVecF64x2;
begin
  if SimdIsNaN(a.d[0]) or SimdIsInfinite(a.d[0]) then
    Result.d[0] := a.d[0]
  else
    Result.d[0] := SimdCeil(a.d[0]);

  if SimdIsNaN(a.d[1]) or SimdIsInfinite(a.d[1]) then
    Result.d[1] := a.d[1]
  else
    Result.d[1] := SimdCeil(a.d[1]);
end;

function ScalarRoundF64x2(const a: TVecF64x2): TVecF64x2;
var
  LRounded: Double;
begin
  if SimdIsNaN(a.d[0]) or SimdIsInfinite(a.d[0]) then
    Result.d[0] := a.d[0]
  else
  begin
    LRounded := SimdRound(a.d[0]);
    Result.d[0] := ScalarNormalizeSignedZeroDouble(a.d[0], LRounded);
  end;

  if SimdIsNaN(a.d[1]) or SimdIsInfinite(a.d[1]) then
    Result.d[1] := a.d[1]
  else
  begin
    LRounded := SimdRound(a.d[1]);
    Result.d[1] := ScalarNormalizeSignedZeroDouble(a.d[1], LRounded);
  end;
end;

function ScalarTruncF64x2(const a: TVecF64x2): TVecF64x2;
var
  LTrunced: Double;
begin
  if SimdIsNaN(a.d[0]) or SimdIsInfinite(a.d[0]) then
    Result.d[0] := a.d[0]
  else
  begin
    LTrunced := SimdTruncFloat(a.d[0]);
    Result.d[0] := ScalarNormalizeSignedZeroDouble(a.d[0], LTrunced);
  end;

  if SimdIsNaN(a.d[1]) or SimdIsInfinite(a.d[1]) then
    Result.d[1] := a.d[1]
  else
  begin
    LTrunced := SimdTruncFloat(a.d[1]);
    Result.d[1] := ScalarNormalizeSignedZeroDouble(a.d[1], LTrunced);
  end;
end;

// F32x8 (256-bit)
function ScalarFmaF32x8(const a, b, c: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := a.f[i] * b.f[i] + c.f[i];
end;

function ScalarFloorF32x8(const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := SimdFloor(a.f[i]);
end;

function ScalarCeilF32x8(const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := SimdCeil(a.f[i]);
end;

function ScalarRoundF32x8(const a: TVecF32x8): TVecF32x8;
var
  i: Integer;
  LRounded: Single;
begin
  for i := 0 to 7 do
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LRounded := SimdRound(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LRounded);
    end;
end;

function ScalarTruncF32x8(const a: TVecF32x8): TVecF32x8;
var
  i: Integer;
  LTrunced: Single;
begin
  for i := 0 to 7 do
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LTrunced := SimdTruncFloat(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LTrunced);
    end;
end;

// F64x4 (256-bit)
function ScalarFmaF64x4(const a, b, c: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := a.d[i] * b.d[i] + c.d[i];
end;

function ScalarFloorF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if SimdIsNaN(a.d[i]) or SimdIsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := SimdFloor(a.d[i]);
end;

function ScalarCeilF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if SimdIsNaN(a.d[i]) or SimdIsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := SimdCeil(a.d[i]);
end;

function ScalarRoundF64x4(const a: TVecF64x4): TVecF64x4;
var
  i: Integer;
  LRounded: Double;
begin
  for i := 0 to 3 do
    if SimdIsNaN(a.d[i]) or SimdIsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
    begin
      LRounded := SimdRound(a.d[i]);
      Result.d[i] := ScalarNormalizeSignedZeroDouble(a.d[i], LRounded);
    end;
end;

function ScalarTruncF64x4(const a: TVecF64x4): TVecF64x4;
var
  i: Integer;
  LTrunced: Double;
begin
  for i := 0 to 3 do
    if SimdIsNaN(a.d[i]) or SimdIsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
    begin
      LTrunced := SimdTruncFloat(a.d[i]);
      Result.d[i] := ScalarNormalizeSignedZeroDouble(a.d[i], LTrunced);
    end;
end;

function ScalarRcpF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := 1.0 / a.d[i];
end;

// F32x16 (512-bit)
function ScalarFmaF32x16(const a, b, c: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := a.f[i] * b.f[i] + c.f[i];
end;

function ScalarFloorF32x16(const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := SimdFloor(a.f[i]);
end;

function ScalarCeilF32x16(const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := SimdCeil(a.f[i]);
end;

function ScalarRoundF32x16(const a: TVecF32x16): TVecF32x16;
var
  i: Integer;
  LRounded: Single;
begin
  for i := 0 to 15 do
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LRounded := SimdRound(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LRounded);
    end;
end;

function ScalarTruncF32x16(const a: TVecF32x16): TVecF32x16;
var
  i: Integer;
  LTrunced: Single;
begin
  for i := 0 to 15 do
    if SimdIsNaN(a.f[i]) or SimdIsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LTrunced := SimdTruncFloat(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LTrunced);
    end;
end;

// F64x8 (512-bit)
function ScalarFmaF64x8(const a, b, c: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := a.d[i] * b.d[i] + c.d[i];
end;

function ScalarFloorF64x8(const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if SimdIsNaN(a.d[i]) or SimdIsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := SimdFloor(a.d[i]);
end;

function ScalarCeilF64x8(const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if SimdIsNaN(a.d[i]) or SimdIsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := SimdCeil(a.d[i]);
end;

function ScalarRoundF64x8(const a: TVecF64x8): TVecF64x8;
var
  i: Integer;
  LRounded: Double;
begin
  for i := 0 to 7 do
    if SimdIsNaN(a.d[i]) or SimdIsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
    begin
      LRounded := SimdRound(a.d[i]);
      Result.d[i] := ScalarNormalizeSignedZeroDouble(a.d[i], LRounded);
    end;
end;

function ScalarTruncF64x8(const a: TVecF64x8): TVecF64x8;
var
  i: Integer;
  LTrunced: Double;
begin
  for i := 0 to 7 do
    if SimdIsNaN(a.d[i]) or SimdIsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
    begin
      LTrunced := SimdTruncFloat(a.d[i]);
      Result.d[i] := ScalarNormalizeSignedZeroDouble(a.d[i], LTrunced);
    end;
end;

// === 3D/4D Vector Math ===

function ScalarDotF32x4(const a, b: TVecF32x4): Single;
begin
  Result := a.f[0] * b.f[0] + a.f[1] * b.f[1] + a.f[2] * b.f[2] + a.f[3] * b.f[3];
end;

function ScalarDotF32x3(const a, b: TVecF32x4): Single;
begin
  Result := a.f[0] * b.f[0] + a.f[1] * b.f[1] + a.f[2] * b.f[2];
end;

function ScalarCrossF32x3(const a, b: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := a.f[1] * b.f[2] - a.f[2] * b.f[1];
  Result.f[1] := a.f[2] * b.f[0] - a.f[0] * b.f[2];
  Result.f[2] := a.f[0] * b.f[1] - a.f[1] * b.f[0];
  Result.f[3] := 0.0;
end;

function ScalarLengthF32x4(const a: TVecF32x4): Single;
begin
  Result := Sqrt(a.f[0] * a.f[0] + a.f[1] * a.f[1] + a.f[2] * a.f[2] + a.f[3] * a.f[3]);
end;

function ScalarLengthF32x3(const a: TVecF32x4): Single;
begin
  Result := Sqrt(a.f[0] * a.f[0] + a.f[1] * a.f[1] + a.f[2] * a.f[2]);
end;

function ScalarNormalizeF32x4(const a: TVecF32x4): TVecF32x4;
var
  len: Single;
  invLen: Single;
  i: Integer;
begin
  len := ScalarLengthF32x4(a);
  if len > 0.0 then
  begin
    invLen := 1.0 / len;
    for i := 0 to 3 do
      Result.f[i] := a.f[i] * invLen;
  end
  else
    Result := a;
end;

function ScalarNormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  len: Single;
  invLen: Single;
begin
  len := ScalarLengthF32x3(a);
  if len > 0.0 then
  begin
    invLen := 1.0 / len;
    Result.f[0] := a.f[0] * invLen;
    Result.f[1] := a.f[1] * invLen;
    Result.f[2] := a.f[2] * invLen;
    Result.f[3] := 0.0;
  end
  else
  begin
    Result := a;
    Result.f[3] := 0.0;
  end;
end;

// FMA-optimized Dot Product Functions (Scalar Reference)

function ScalarDotF32x8(const a, b: TVecF32x8): Single;
var
  i: Integer;
begin
  Result := 0.0;
  for i := 0 to 7 do
    Result := Result + a.f[i] * b.f[i];
end;

function ScalarDotF64x2(const a, b: TVecF64x2): Double;
begin
  Result := a.d[0] * b.d[0] + a.d[1] * b.d[1];
end;

function ScalarDotF64x4(const a, b: TVecF64x4): Double;
var
  i: Integer;
begin
  Result := 0.0;
  for i := 0 to 3 do
    Result := Result + a.d[i] * b.d[i];
end;

