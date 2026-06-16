// === P1 Missing Functions: Integer Abs ===

function VecI32x4Abs(const a: TVecI32x4): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if a.i[i] < 0 then
      Result.i[i] := -a.i[i]
    else
      Result.i[i] := a.i[i];
end;

function VecI16x8Abs(const a: TVecI16x8): TVecI16x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if a.i[i] < 0 then
      Result.i[i] := -a.i[i]
    else
      Result.i[i] := a.i[i];
end;

function VecI8x16Abs(const a: TVecI8x16): TVecI8x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] < 0 then
      Result.i[i] := -a.i[i]
    else
      Result.i[i] := a.i[i];
end;

// === P1 Missing Functions: I32x4 Splat/Zero/Load/Store ===

function VecI32x4Splat(value: Int32): TVecI32x4;
begin
  Result.i[0] := value;
  Result.i[1] := value;
  Result.i[2] := value;
  Result.i[3] := value;
end;

function VecI32x4Zero: TVecI32x4;
begin
  Result.i[0] := 0;
  Result.i[1] := 0;
  Result.i[2] := 0;
  Result.i[3] := 0;
end;

function VecI32x4Load(p: PInt32): TVecI32x4;
begin
  Result.i[0] := p[0];
  Result.i[1] := p[1];
  Result.i[2] := p[2];
  Result.i[3] := p[3];
end;

procedure VecI32x4Store(p: PInt32; const a: TVecI32x4);
begin
  p[0] := a.i[0];
  p[1] := a.i[1];
  p[2] := a.i[2];
  p[3] := a.i[3];
end;

// === P1 Missing Functions: Integer Clamp ===

function VecI32x4Clamp(const a, minVal, maxVal: TVecI32x4): TVecI32x4;
var i: Integer;
    v: Int32;
begin
  for i := 0 to 3 do
  begin
    v := a.i[i];
    if v < minVal.i[i] then v := minVal.i[i];
    if v > maxVal.i[i] then v := maxVal.i[i];
    Result.i[i] := v;
  end;
end;

// === P1 Missing Functions: Integer Reduce ===

function VecI32x4ReduceAdd(const a: TVecI32x4): Int32;
begin
  Result := a.i[0] + a.i[1] + a.i[2] + a.i[3];
end;

function VecI32x4ReduceMin(const a: TVecI32x4): Int32;
begin
  Result := a.i[0];
  if a.i[1] < Result then Result := a.i[1];
  if a.i[2] < Result then Result := a.i[2];
  if a.i[3] < Result then Result := a.i[3];
end;

function VecI32x4ReduceMax(const a: TVecI32x4): Int32;
begin
  Result := a.i[0];
  if a.i[1] > Result then Result := a.i[1];
  if a.i[2] > Result then Result := a.i[2];
  if a.i[3] > Result then Result := a.i[3];
end;

// === P1 Missing Functions: VecF32x4Lerp ===

function VecF32x4Lerp(const a, b: TVecF32x4; t: Single): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := a.f[i] + t * (b.f[i] - a.f[i]);
end;

// === P1 Missing Functions: VecU32x4CmpNe ===

function VecU32x4CmpNe(const a, b: TVecU32x4): TMask4;
begin
  Result := 0;
  if a.u[0] <> b.u[0] then Result := Result or 1;
  if a.u[1] <> b.u[1] then Result := Result or 2;
  if a.u[2] <> b.u[2] then Result := Result or 4;
  if a.u[3] <> b.u[3] then Result := Result or 8;
end;

// === P1 Missing Functions: Make functions ===

function VecF64x2Make(x, y: Double): TVecF64x2;
begin
  Result.d[0] := x;
  Result.d[1] := y;
end;

function VecI32x4Make(a, b, c, d: Int32): TVecI32x4;
begin
  Result.i[0] := a;
  Result.i[1] := b;
  Result.i[2] := c;
  Result.i[3] := d;
end;

function VecF32x8Make(a, b, c, d, e, f, g, h: Single): TVecF32x8;
begin
  Result.f[0] := a;
  Result.f[1] := b;
  Result.f[2] := c;
  Result.f[3] := d;
  Result.f[4] := e;
  Result.f[5] := f;
  Result.f[6] := g;
  Result.f[7] := h;
end;

// === P2 Completeness: Batch Array F64 Extensions (inline facade) ===

procedure ArrayFmaF64(aSrc1, aSrc2, aSrc3, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] * aSrc2[i] + aSrc3[i];
end;

procedure ArrayMinF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    if aSrc1[i] < aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;

procedure ArrayMaxF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    if aSrc1[i] > aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;

procedure ArrayExpF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := System.Exp(aSrc[i]);
end;

procedure ArrayLogF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := System.Ln(aSrc[i]);
end;

procedure ArraySinF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := System.Sin(aSrc[i]);
end;

procedure ArrayCosF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := System.Cos(aSrc[i]);
end;
