// === Dispatch Table Accessor Tests ===
// Deep coverage for all 8 accessor types

unit test_dispatch_accessors;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  nextpas.core.test,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

{$M+}
type
  TTestDispatchAccessors = class(TTestFixture)
  published
    procedure TestF32x4Accessor;
    procedure TestF64x2Accessor;
    procedure TestMemoryAccessor;
    procedure TestBatchF32Accessor;
    procedure TestBatchF64Accessor;
    procedure TestI32x4Accessor;
    procedure TestMaskAccessor;
    procedure TestBatchIntegerAccessor;
  end;

implementation

const
  EPS_F32 = 1E-5;
  EPS_F64 = 1E-12;

// --- F32x4 ---

procedure TTestDispatchAccessors.TestF32x4Accessor;
var
  LAcc: TF32x4Accessor;
  a, b, c, d: TVecF32x4;
  LMask: TMask4;
  v: Single;
  buf: array[0..3] of Single;
  i: Integer;
begin
  LAcc := GetF32x4Accessor;

  // Arithmetic with multi-lane verification
  a := LAcc.Make(1.0, 2.0, 3.0, 4.0);
  b := LAcc.Make(5.0, 6.0, 7.0, 8.0);

  c := LAcc.Add(a, b);
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i) - Single(i + 1 + i + 5)) < EPS_F32, 'F32x4 Add');

  c := LAcc.Sub(b, a);
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i) - 4.0) < EPS_F32, 'F32x4 Sub');

  c := LAcc.Mul(a, b);
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i) - Single(i + 1) * Single(i + 5)) < EPS_F32, 'F32x4 Mul');

  c := LAcc.Divide(b, a);
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i) - Single(i + 5) / Single(i + 1)) < EPS_F32, 'F32x4 Divide');

  // Neg
  c := LAcc.Neg(a);
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i) + Single(i + 1)) < EPS_F32, 'F32x4 Neg');

  // Abs
  c := LAcc.Abs(LAcc.Make(-1.0, -2.0, 3.0, -4.0));
  CheckTrue(Abs(LAcc.Extract(c, 0) - 1.0) < EPS_F32, 'F32x4 Abs 0');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 2.0) < EPS_F32, 'F32x4 Abs 1');
  CheckTrue(Abs(LAcc.Extract(c, 2) - 3.0) < EPS_F32, 'F32x4 Abs 2');
  CheckTrue(Abs(LAcc.Extract(c, 3) - 4.0) < EPS_F32, 'F32x4 Abs 3');

  // Sqrt
  c := LAcc.Sqrt(LAcc.Make(1.0, 4.0, 9.0, 16.0));
  CheckTrue(Abs(LAcc.Extract(c, 0) - 1.0) < EPS_F32, 'F32x4 Sqrt 0');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 2.0) < EPS_F32, 'F32x4 Sqrt 1');
  CheckTrue(Abs(LAcc.Extract(c, 2) - 3.0) < EPS_F32, 'F32x4 Sqrt 2');
  CheckTrue(Abs(LAcc.Extract(c, 3) - 4.0) < EPS_F32, 'F32x4 Sqrt 3');

  // Min/Max
  c := LAcc.Min(a, b);
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i) - Single(i + 1)) < EPS_F32, 'F32x4 Min');

  c := LAcc.Max(a, b);
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i) - Single(i + 5)) < EPS_F32, 'F32x4 Max');

  // Clamp
  c := LAcc.Clamp(LAcc.Make(0.5, 1.5, 3.5, 10.0), LAcc.Splat(1.0), LAcc.Splat(3.0));
  CheckTrue(Abs(LAcc.Extract(c, 0) - 1.0) < EPS_F32, 'F32x4 Clamp lo');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 1.5) < EPS_F32, 'F32x4 Clamp mid');
  CheckTrue(Abs(LAcc.Extract(c, 2) - 3.0) < EPS_F32, 'F32x4 Clamp hi');
  CheckTrue(Abs(LAcc.Extract(c, 3) - 3.0) < EPS_F32, 'F32x4 Clamp hi2');

  // Fma: a*b + c
  a := LAcc.Make(2.0, 3.0, 4.0, 5.0);
  b := LAcc.Make(1.0, 2.0, 3.0, 4.0);
  c := LAcc.Make(10.0, 20.0, 30.0, 40.0);
  d := LAcc.Fma(a, b, c);
  CheckTrue(Abs(LAcc.Extract(d, 0) - 12.0) < EPS_F32, 'F32x4 Fma 0');
  CheckTrue(Abs(LAcc.Extract(d, 1) - 26.0) < EPS_F32, 'F32x4 Fma 1');
  CheckTrue(Abs(LAcc.Extract(d, 2) - 42.0) < EPS_F32, 'F32x4 Fma 2');
  CheckTrue(Abs(LAcc.Extract(d, 3) - 60.0) < EPS_F32, 'F32x4 Fma 3');

  // Floor/Ceil/Round/Trunc
  a := LAcc.Make(1.3, 2.7, -1.5, -2.5);
  c := LAcc.Floor(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 1.0) < EPS_F32, 'F32x4 Floor +');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 2.0) < EPS_F32, 'F32x4 Floor +2');
  CheckTrue(Abs(LAcc.Extract(c, 2) - (-2.0)) < EPS_F32, 'F32x4 Floor -');
  CheckTrue(Abs(LAcc.Extract(c, 3) - (-3.0)) < EPS_F32, 'F32x4 Floor -2');

  c := LAcc.Ceil(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 2.0) < EPS_F32, 'F32x4 Ceil +');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 3.0) < EPS_F32, 'F32x4 Ceil +2');
  CheckTrue(Abs(LAcc.Extract(c, 2) - (-1.0)) < EPS_F32, 'F32x4 Ceil -');
  CheckTrue(Abs(LAcc.Extract(c, 3) - (-2.0)) < EPS_F32, 'F32x4 Ceil -2');

  c := LAcc.Trunc(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 1.0) < EPS_F32, 'F32x4 Trunc +');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 2.0) < EPS_F32, 'F32x4 Trunc +2');
  CheckTrue(Abs(LAcc.Extract(c, 2) - (-1.0)) < EPS_F32, 'F32x4 Trunc -');
  CheckTrue(Abs(LAcc.Extract(c, 3) - (-2.0)) < EPS_F32, 'F32x4 Trunc -2');

  // Rcp/Rsqrt (approximate)
  a := LAcc.Make(2.0, 4.0, 5.0, 10.0);
  c := LAcc.Rcp(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 0.5) < 0.01, 'F32x4 Rcp 0');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 0.25) < 0.01, 'F32x4 Rcp 1');

  c := LAcc.Rsqrt(LAcc.Make(4.0, 9.0, 16.0, 25.0));
  CheckTrue(Abs(LAcc.Extract(c, 0) - 0.5) < 0.01, 'F32x4 Rsqrt 0');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 1.0 / 3.0) < 0.01, 'F32x4 Rsqrt 1');

  // All 6 comparisons
  a := LAcc.Make(1.0, 2.0, 3.0, 4.0);
  b := LAcc.Make(1.0, 3.0, 2.0, 4.0);

  LMask := LAcc.CmpEq(a, b);
  CheckTrue(LMask and $1 <> 0, 'F32x4 CmpEq T');
  CheckTrue(LMask and $2 = 0, 'F32x4 CmpEq F');
  CheckTrue(LMask and $8 <> 0, 'F32x4 CmpEq T2');

  LMask := LAcc.CmpLt(a, b);
  CheckTrue(LMask and $1 = 0, 'F32x4 CmpLt F');
  CheckTrue(LMask and $2 <> 0, 'F32x4 CmpLt T');
  CheckTrue(LMask and $4 = 0, 'F32x4 CmpLt F2');

  LMask := LAcc.CmpLe(a, b);
  CheckTrue(LMask and $1 <> 0, 'F32x4 CmpLe T');
  CheckTrue(LMask and $2 <> 0, 'F32x4 CmpLe T2');
  CheckTrue(LMask and $4 = 0, 'F32x4 CmpLe F');

  LMask := LAcc.CmpGt(a, b);
  CheckTrue(LMask and $4 <> 0, 'F32x4 CmpGt T');
  CheckTrue(LMask and $2 = 0, 'F32x4 CmpGt F');

  LMask := LAcc.CmpGe(a, b);
  CheckTrue(LMask and $1 <> 0, 'F32x4 CmpGe T');
  CheckTrue(LMask and $4 <> 0, 'F32x4 CmpGe T2');
  CheckTrue(LMask and $2 = 0, 'F32x4 CmpGe F');

  LMask := LAcc.CmpNe(a, b);
  CheckTrue(LMask and $1 = 0, 'F32x4 CmpNe F');
  CheckTrue(LMask and $2 <> 0, 'F32x4 CmpNe T');
  CheckTrue(LMask and $4 <> 0, 'F32x4 CmpNe T2');

  // Select
  LMask := $5; // lanes 0,2 from a
  a := LAcc.Make(10.0, 20.0, 30.0, 40.0);
  b := LAcc.Make(100.0, 200.0, 300.0, 400.0);
  c := LAcc.Select(LMask, a, b);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 10.0) < EPS_F32, 'F32x4 Select a');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 200.0) < EPS_F32, 'F32x4 Select b');
  CheckTrue(Abs(LAcc.Extract(c, 2) - 30.0) < EPS_F32, 'F32x4 Select a2');
  CheckTrue(Abs(LAcc.Extract(c, 3) - 400.0) < EPS_F32, 'F32x4 Select b2');

  // Dot4/Dot3/Cross3
  a := LAcc.Make(1.0, 0.0, 0.0, 0.0);
  b := LAcc.Make(0.0, 1.0, 0.0, 0.0);
  v := LAcc.Dot4(a, b);
  CheckTrue(Abs(v) < EPS_F32, 'F32x4 Dot4 ortho');

  a := LAcc.Make(1.0, 2.0, 3.0, 4.0);
  b := LAcc.Make(5.0, 6.0, 7.0, 8.0);
  v := LAcc.Dot4(a, b);
  CheckTrue(Abs(v - 70.0) < EPS_F32, 'F32x4 Dot4'); // 5+12+21+32

  v := LAcc.Dot3(a, b);
  CheckTrue(Abs(v - 38.0) < EPS_F32, 'F32x4 Dot3'); // 5+12+21

  // Cross3: (1,0,0) x (0,1,0) = (0,0,1)
  a := LAcc.Make(1.0, 0.0, 0.0, 0.0);
  b := LAcc.Make(0.0, 1.0, 0.0, 0.0);
  c := LAcc.Cross3(a, b);
  CheckTrue(Abs(LAcc.Extract(c, 0)) < EPS_F32, 'F32x4 Cross3 x');
  CheckTrue(Abs(LAcc.Extract(c, 1)) < EPS_F32, 'F32x4 Cross3 y');
  CheckTrue(Abs(LAcc.Extract(c, 2) - 1.0) < EPS_F32, 'F32x4 Cross3 z');

  // Length4/Length3
  a := LAcc.Make(3.0, 4.0, 0.0, 0.0);
  v := LAcc.Length4(a);
  CheckTrue(Abs(v - 5.0) < EPS_F32, 'F32x4 Length4');
  v := LAcc.Length3(a);
  CheckTrue(Abs(v - 5.0) < EPS_F32, 'F32x4 Length3');

  // Normalize4
  a := LAcc.Make(3.0, 4.0, 0.0, 0.0);
  c := LAcc.Normalize4(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 0.6) < EPS_F32, 'F32x4 Norm4 x');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 0.8) < EPS_F32, 'F32x4 Norm4 y');

  // ReduceAdd/Min/Max/Mul
  a := LAcc.Make(2.0, 3.0, 4.0, 5.0);
  CheckTrue(Abs(LAcc.ReduceAdd(a) - 14.0) < EPS_F32, 'F32x4 ReduceAdd');
  CheckTrue(Abs(LAcc.ReduceMin(a) - 2.0) < EPS_F32, 'F32x4 ReduceMin');
  CheckTrue(Abs(LAcc.ReduceMax(a) - 5.0) < EPS_F32, 'F32x4 ReduceMax');
  CheckTrue(Abs(LAcc.ReduceMul(a) - 120.0) < EPS_F32, 'F32x4 ReduceMul');

  // Zero
  c := LAcc.Zero;
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i)) < EPS_F32, 'F32x4 Zero');

  // Insert
  c := LAcc.Zero;
  c := LAcc.Insert(c, 42.0, 2);
  CheckTrue(Abs(LAcc.Extract(c, 2) - 42.0) < EPS_F32, 'F32x4 Insert');
  CheckTrue(Abs(LAcc.Extract(c, 0)) < EPS_F32, 'F32x4 Insert other');

  // Load/Store
  buf[0] := 10.0; buf[1] := 20.0; buf[2] := 30.0; buf[3] := 40.0;
  c := LAcc.Load(@buf);
  for i := 0 to 3 do
    CheckTrue(Abs(LAcc.Extract(c, i) - buf[i]) < EPS_F32, 'F32x4 Load');

  a := LAcc.Make(1.0, 2.0, 3.0, 4.0);
  LAcc.Store(@buf, a);
  for i := 0 to 3 do
    CheckTrue(Abs(buf[i] - Single(i + 1)) < EPS_F32, 'F32x4 Store');
end;

// --- F64x2 ---

procedure TTestDispatchAccessors.TestF64x2Accessor;
var
  LAcc: TF64x2Accessor;
  a, b, c, d: TVecF64x2;
  LMask: TMask2;
  v: Double;
  buf: array[0..1] of Double;
begin
  LAcc := GetF64x2Accessor;

  a := LAcc.Make(2.0, 3.0);
  b := LAcc.Make(5.0, 7.0);

  c := LAcc.Add(a, b);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 7.0) < EPS_F64, 'F64x2 Add');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 10.0) < EPS_F64, 'F64x2 Add');

  c := LAcc.Sub(b, a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 3.0) < EPS_F64, 'F64x2 Sub');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 4.0) < EPS_F64, 'F64x2 Sub');

  c := LAcc.Mul(a, b);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 10.0) < EPS_F64, 'F64x2 Mul');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 21.0) < EPS_F64, 'F64x2 Mul');

  c := LAcc.Divide(b, a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 2.5) < EPS_F64, 'F64x2 Div');
  // Use runtime values to compute expected: b.d[1]/a.d[1] = 7.0/3.0
  // FPC constant-folds 7.0/3.0 with ~7-digit precision at compile time
  v := b.d[1] / a.d[1];
  CheckTrue(Abs(LAcc.Extract(c, 1) - v) < EPS_F64, 'F64x2 Div');

  c := LAcc.Neg(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) + 2.0) < EPS_F64, 'F64x2 Neg');
  CheckTrue(Abs(LAcc.Extract(c, 1) + 3.0) < EPS_F64, 'F64x2 Neg');

  c := LAcc.Abs(LAcc.Make(-5.0, 7.0));
  CheckTrue(Abs(LAcc.Extract(c, 0) - 5.0) < EPS_F64, 'F64x2 Abs');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 7.0) < EPS_F64, 'F64x2 Abs');

  c := LAcc.Sqrt(LAcc.Make(9.0, 16.0));
  CheckTrue(Abs(LAcc.Extract(c, 0) - 3.0) < EPS_F64, 'F64x2 Sqrt');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 4.0) < EPS_F64, 'F64x2 Sqrt');

  c := LAcc.Min(a, b);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 2.0) < EPS_F64, 'F64x2 Min');
  c := LAcc.Max(a, b);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 5.0) < EPS_F64, 'F64x2 Max');

  c := LAcc.Clamp(LAcc.Make(0.5, 10.0), LAcc.Splat(1.0), LAcc.Splat(5.0));
  CheckTrue(Abs(LAcc.Extract(c, 0) - 1.0) < EPS_F64, 'F64x2 Clamp lo');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 5.0) < EPS_F64, 'F64x2 Clamp hi');

  a := LAcc.Make(2.0, 3.0);
  b := LAcc.Make(4.0, 5.0);
  c := LAcc.Make(10.0, 20.0);
  d := LAcc.Fma(a, b, c);
  CheckTrue(Abs(LAcc.Extract(d, 0) - 18.0) < EPS_F64, 'F64x2 Fma');
  CheckTrue(Abs(LAcc.Extract(d, 1) - 35.0) < EPS_F64, 'F64x2 Fma');

  a := LAcc.Make(1.7, -2.3);
  c := LAcc.Floor(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 1.0) < EPS_F64, 'F64x2 Floor');
  CheckTrue(Abs(LAcc.Extract(c, 1) - (-3.0)) < EPS_F64, 'F64x2 Floor');

  c := LAcc.Ceil(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 2.0) < EPS_F64, 'F64x2 Ceil');
  CheckTrue(Abs(LAcc.Extract(c, 1) - (-2.0)) < EPS_F64, 'F64x2 Ceil');

  c := LAcc.Trunc(a);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 1.0) < EPS_F64, 'F64x2 Trunc');
  CheckTrue(Abs(LAcc.Extract(c, 1) - (-2.0)) < EPS_F64, 'F64x2 Trunc');

  a := LAcc.Make(1.0, 3.0);
  b := LAcc.Make(1.0, 2.0);

  LMask := LAcc.CmpEq(a, b);
  CheckTrue(LMask and $1 <> 0, 'F64x2 CmpEq T');
  CheckTrue(LMask and $2 = 0, 'F64x2 CmpEq F');

  LMask := LAcc.CmpLt(a, b);
  CheckTrue(LMask and $2 = 0, 'F64x2 CmpLt F');
  LMask := LAcc.CmpGt(a, b);
  CheckTrue(LMask and $2 <> 0, 'F64x2 CmpGt T');

  LMask := $1; // lane 0 from a
  a := LAcc.Make(10.0, 20.0);
  b := LAcc.Make(100.0, 200.0);
  c := LAcc.Select(LMask, a, b);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 10.0) < EPS_F64, 'F64x2 Select a');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 200.0) < EPS_F64, 'F64x2 Select b');

  a := LAcc.Make(3.0, 4.0);
  b := LAcc.Make(5.0, 6.0);
  v := LAcc.Dot(a, b);
  CheckTrue(Abs(v - 39.0) < EPS_F64, 'F64x2 Dot'); // 15+24

  a := LAcc.Make(3.0, 4.0);
  v := Sqrt(3.0 * 3.0 + 4.0 * 4.0);
  CheckTrue(Abs(v - 5.0) < EPS_F64, 'F64x2 Length');

  // Norm = a / |a|, |a| = 5.0 for (3,4)
  v := 5.0; // avoid FPC constant-folding precision loss
  c := LAcc.Make(a.d[0] / v, a.d[1] / v);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 0.6) < EPS_F64, 'F64x2 Norm x');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 0.8) < EPS_F64, 'F64x2 Norm y');

  a := LAcc.Make(3.0, 5.0);
  CheckTrue(Abs(LAcc.ReduceAdd(a) - 8.0) < EPS_F64, 'F64x2 ReduceAdd');
  CheckTrue(Abs(LAcc.ReduceMin(a) - 3.0) < EPS_F64, 'F64x2 ReduceMin');
  CheckTrue(Abs(LAcc.ReduceMax(a) - 5.0) < EPS_F64, 'F64x2 ReduceMax');
  CheckTrue(Abs(LAcc.ReduceMul(a) - 15.0) < EPS_F64, 'F64x2 ReduceMul');

  c := LAcc.Zero;
  CheckTrue(Abs(LAcc.Extract(c, 0)) < EPS_F64, 'F64x2 Zero');

  c := LAcc.Insert(LAcc.Zero, 42.0, 1);
  CheckTrue(Abs(LAcc.Extract(c, 1) - 42.0) < EPS_F64, 'F64x2 Insert');

  buf[0] := 10.0; buf[1] := 20.0;
  c := LAcc.Load(@buf);
  CheckTrue(Abs(LAcc.Extract(c, 0) - 10.0) < EPS_F64, 'F64x2 Load');
  CheckTrue(Abs(LAcc.Extract(c, 1) - 20.0) < EPS_F64, 'F64x2 Load');

  LAcc.Store(@buf, c);
  CheckTrue(Abs(buf[0] - 10.0) < EPS_F64, 'F64x2 Store');
  CheckTrue(Abs(buf[1] - 20.0) < EPS_F64, 'F64x2 Store');
end;

// --- Memory ---

procedure TTestDispatchAccessors.TestMemoryAccessor;
var
  LAcc: TMemoryAccessor;
  a, b: array[0..15] of Byte;
  LUtf8: array[0..4] of Byte;
  LUtf8_2: array[0..3] of Byte;
  LUtf8Bad: array[0..2] of Byte;
  LHi1, LHi2: array[0..2] of Byte;
  LUpper, LLower: array[0..4] of Byte;
  LHay: array[0..9] of Byte;
  LNeedle: array[0..2] of Byte;
  LBits: array[0..3] of Byte;
  LMin, LMax: Byte;
  firstDiff, lastDiff: SizeUInt;
  i: Integer;
begin
  LAcc := GetMemoryAccessor;

  // DiffRange: identical
  for i := 0 to 15 do begin a[i] := i; b[i] := i; end;
  CheckFalse(LAcc.DiffRange(@a, @b, 16, firstDiff, lastDiff), 'MemDiffRange same');

  // DiffRange: different
  b[3] := 99; b[10] := 88;
  CheckTrue(LAcc.DiffRange(@a, @b, 16, firstDiff, lastDiff), 'MemDiffRange diff');
  CheckEqual(firstDiff, 3, 'MemDiffRange first');
  CheckEqual(lastDiff, 10, 'MemDiffRange last');

  // Reverse
  for i := 0 to 5 do a[i] := i;
  LAcc.Reverse(@a, 6);
  CheckEqual(a[0], 5, 'MemReverse 0');
  CheckEqual(a[1], 4, 'MemReverse 1');
  CheckEqual(a[5], 0, 'MemReverse 5');

  // SumBytes
  for i := 0 to 3 do a[i] := i + 1; // 1+2+3+4 = 10
  CheckTrue(LAcc.SumBytes(@a, 4) = 10, 'MemSumBytes');

  // MinMaxBytes
  a[0] := 5; a[1] := 1; a[2] := 9; a[3] := 3;
  LAcc.MinMaxBytes(@a, 4, LMin, LMax);
  CheckEqual(LMin, 1, 'MemMinMax min');
  CheckEqual(LMax, 9, 'MemMinMax max');

  // CountByte
  a[0] := 42; a[1] := 7; a[2] := 42; a[3] := 3; a[4] := 42;
  CheckEqual(LAcc.CountByte(@a, 5, 42), 3, 'MemCountByte');

  // Utf8Validate: valid ASCII
  LUtf8[0] := Ord('H'); LUtf8[1] := Ord('e'); LUtf8[2] := Ord('l');
  LUtf8[3] := Ord('l'); LUtf8[4] := Ord('o');
  CheckTrue(LAcc.Utf8Validate(@LUtf8, 5), 'MemUtf8 valid ASCII');

  // Utf8Validate: valid 2-byte
  LUtf8_2[0] := $C3; LUtf8_2[1] := $A9;
  LUtf8_2[2] := $C3; LUtf8_2[3] := $A8;
  CheckTrue(LAcc.Utf8Validate(@LUtf8_2, 4), 'MemUtf8 valid 2-byte');

  // Utf8Validate: invalid
  LUtf8Bad[0] := $FF; LUtf8Bad[1] := $FE; LUtf8Bad[2] := $80;
  CheckFalse(LAcc.Utf8Validate(@LUtf8Bad, 3), 'MemUtf8 invalid');

  // AsciiIEqual
  LHi1[0] := Ord('H'); LHi1[1] := Ord('I'); LHi1[2] := Ord('!');
  LHi2[0] := Ord('h'); LHi2[1] := Ord('i'); LHi2[2] := Ord('!');
  CheckTrue(LAcc.AsciiIEqual(@LHi1, @LHi2, 3), 'MemAsciiIEqual true');
  LHi2[2] := Ord('?');
  CheckFalse(LAcc.AsciiIEqual(@LHi1, @LHi2, 3), 'MemAsciiIEqual false');

  // ToLowerAscii
  LUpper[0] := Ord('H'); LUpper[1] := Ord('E'); LUpper[2] := Ord('L');
  LUpper[3] := Ord('L'); LUpper[4] := Ord('O');
  LAcc.ToLowerAscii(@LUpper, 5);
  CheckEqual(LUpper[0], Ord('h'), 'MemToLower');
  CheckEqual(LUpper[4], Ord('o'), 'MemToLower');

  // ToUpperAscii
  LLower[0] := Ord('h'); LLower[1] := Ord('e'); LLower[2] := Ord('l');
  LLower[3] := Ord('l'); LLower[4] := Ord('o');
  LAcc.ToUpperAscii(@LLower, 5);
  CheckEqual(LLower[0], Ord('H'), 'MemToUpper');
  CheckEqual(LLower[4], Ord('O'), 'MemToUpper');

  // BytesIndexOf
  for i := 0 to 9 do LHay[i] := Ord('a') + i;
  LNeedle[0] := Ord('d'); LNeedle[1] := Ord('e'); LNeedle[2] := Ord('f');
  CheckEqual(LAcc.BytesIndexOf(@LHay, 10, @LNeedle, 3), 3, 'MemBytesIndexOf found');
  LNeedle[0] := Ord('x');
  CheckEqual(LAcc.BytesIndexOf(@LHay, 10, @LNeedle, 3), -1, 'MemBytesIndexOf not found');

  // BitsetPopCount
  LBits[0] := $FF; LBits[1] := $0F; LBits[2] := $00; LBits[3] := $01;
  CheckEqual(LAcc.BitsetPopCount(@LBits, 4), 13, 'MemBitsetPopCount'); // 8+4+0+1
end;

// --- BatchF32 ---

procedure TTestDispatchAccessors.TestBatchF32Accessor;
var
  LAcc: TBatchF32Accessor;
  a, b, c, d: array[0..3] of Single;
  i: Integer;
begin
  LAcc := GetBatchF32Accessor;

  for i := 0 to 3 do begin a[i] := Single(i + 1); b[i] := Single(i + 5); end;

  LAcc.ArraySub(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - (-4.0)) < EPS_F32, 'BatchF32 Sub');

  LAcc.ArrayDiv(@b, @a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Single(i + 5) / Single(i + 1)) < EPS_F32, 'BatchF32 Div');

  LAcc.ArrayMin(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Single(i + 1)) < EPS_F32, 'BatchF32 Min');

  LAcc.ArrayMax(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Single(i + 5)) < EPS_F32, 'BatchF32 Max');

  for i := 0 to 3 do a[i] := Single(i + 1) - 2.5; // -1.5, -0.5, 0.5, 1.5
  LAcc.ArrayAbs(@a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Abs(a[i])) < EPS_F32, 'BatchF32 Abs');

  LAcc.ArrayNeg(@a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] + a[i]) < EPS_F32, 'BatchF32 Neg');

  for i := 0 to 3 do a[i] := Single((i + 1) * (i + 1));
  LAcc.ArraySqrt(@a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Single(i + 1)) < EPS_F32, 'BatchF32 Sqrt');

  for i := 0 to 3 do a[i] := Single(i + 1);
  LAcc.ArrayAddScalar(@a, @c, 4, 10.0);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Single(i + 11)) < EPS_F32, 'BatchF32 AddScalar');

  LAcc.ArrayMulScalar(@a, @c, 4, 3.0);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Single((i + 1) * 3)) < EPS_F32, 'BatchF32 MulScalar');

  for i := 0 to 3 do a[i] := Single(i) * 2.5; // 0, 2.5, 5, 7.5
  LAcc.ArrayClamp(@a, @c, 4, 1.0, 5.0);
  CheckTrue(Abs(c[0] - 1.0) < EPS_F32, 'BatchF32 Clamp lo');
  CheckTrue(Abs(c[1] - 2.5) < EPS_F32, 'BatchF32 Clamp mid');
  CheckTrue(Abs(c[2] - 5.0) < EPS_F32, 'BatchF32 Clamp hi');
  CheckTrue(Abs(c[3] - 5.0) < EPS_F32, 'BatchF32 Clamp hi2');

  for i := 0 to 3 do begin a[i] := 2.0; b[i] := Single(i + 1); c[i] := 10.0; end;
  LAcc.ArrayFma(@a, @b, @c, @d, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(d[i] - (2.0 * Single(i + 1) + 10.0)) < EPS_F32, 'BatchF32 Fma');

  for i := 0 to 3 do begin b[i] := Single(i + 1); c[i] := 100.0; end;
  LAcc.ArrayAxpy(3.0, @b, @c, @d, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(d[i] - (3.0 * Single(i + 1) + 100.0)) < EPS_F32, 'BatchF32 Axpy');

  for i := 0 to 3 do begin a[i] := 2.0; b[i] := 3.0; end;
  CheckTrue(Abs(LAcc.ReduceDot(@a, @b, 4) - 24.0) < EPS_F32, 'BatchF32 ReduceDot');

  a[0] := 5.0; a[1] := 1.0; a[2] := 9.0; a[3] := 3.0;
  CheckTrue(Abs(LAcc.ReduceMin(@a, 4) - 1.0) < EPS_F32, 'BatchF32 ReduceMin');
  CheckTrue(Abs(LAcc.ReduceMax(@a, 4) - 9.0) < EPS_F32, 'BatchF32 ReduceMax');

  for i := 0 to 3 do a[i] := Single(i + 1) * 2.0;
  LAcc.ArrayRcp(@a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - 1.0 / a[i]) < 0.01, 'BatchF32 Rcp');

  for i := 0 to 3 do a[i] := Single((i + 1) * (i + 1));
  LAcc.ArrayRsqrt(@a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - 1.0 / Single(i + 1)) < 0.01, 'BatchF32 Rsqrt');

  a[0] := 1.3; a[1] := 2.7; a[2] := -1.5; a[3] := -2.5;
  LAcc.ArrayFloor(@a, @c, 4);
  CheckTrue(Abs(c[0] - 1.0) < EPS_F32, 'BatchF32 Floor');
  CheckTrue(Abs(c[1] - 2.0) < EPS_F32, 'BatchF32 Floor');
  CheckTrue(Abs(c[2] - (-2.0)) < EPS_F32, 'BatchF32 Floor');

  LAcc.ArrayCeil(@a, @c, 4);
  CheckTrue(Abs(c[0] - 2.0) < EPS_F32, 'BatchF32 Ceil');
  CheckTrue(Abs(c[1] - 3.0) < EPS_F32, 'BatchF32 Ceil');
  CheckTrue(Abs(c[2] - (-1.0)) < EPS_F32, 'BatchF32 Ceil');

  LAcc.ArrayTrunc(@a, @c, 4);
  CheckTrue(Abs(c[0] - 1.0) < EPS_F32, 'BatchF32 Trunc');
  CheckTrue(Abs(c[1] - 2.0) < EPS_F32, 'BatchF32 Trunc');
  CheckTrue(Abs(c[2] - (-1.0)) < EPS_F32, 'BatchF32 Trunc');

  for i := 0 to 3 do a[i] := Single(i + 1) - 2.5;
  LAcc.ArrayReLU(@a, @c, 4);
  CheckTrue(Abs(c[0]) < EPS_F32, 'BatchF32 ReLU neg');
  CheckTrue(Abs(c[1]) < EPS_F32, 'BatchF32 ReLU neg');
  CheckTrue(Abs(c[2] - 0.5) < EPS_F32, 'BatchF32 ReLU pos');
  CheckTrue(Abs(c[3] - 1.5) < EPS_F32, 'BatchF32 ReLU pos');
end;

// --- BatchF64 ---

procedure TTestDispatchAccessors.TestBatchF64Accessor;
var
  LAcc: TBatchF64Accessor;
  a, b, c: array[0..3] of Double;
  i: Integer;
begin
  LAcc := GetBatchF64Accessor;

  for i := 0 to 3 do begin a[i] := Double(i + 1); b[i] := Double(i + 5); end;

  LAcc.ArraySub(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - (-4.0)) < EPS_F64, 'BatchF64 Sub');

  LAcc.ArrayDiv(@b, @a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Double(i + 5) / Double(i + 1)) < EPS_F64, 'BatchF64 Div');

  LAcc.ArrayMin(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Double(i + 1)) < EPS_F64, 'BatchF64 Min');

  LAcc.ArrayMax(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Double(i + 5)) < EPS_F64, 'BatchF64 Max');

  for i := 0 to 3 do a[i] := Double(i + 1) - 2.5;
  LAcc.ArrayAbs(@a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Abs(a[i])) < EPS_F64, 'BatchF64 Abs');

  LAcc.ArrayNeg(@a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] + a[i]) < EPS_F64, 'BatchF64 Neg');

  for i := 0 to 3 do a[i] := Double((i + 1) * (i + 1));
  LAcc.ArraySqrt(@a, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Double(i + 1)) < EPS_F64, 'BatchF64 Sqrt');

  for i := 0 to 3 do a[i] := Double(i + 1);
  CheckTrue(Abs(LAcc.ReduceSum(@a, 4) - 10.0) < EPS_F64, 'BatchF64 ReduceSum');

  for i := 0 to 3 do begin a[i] := 2.0; b[i] := 3.0; end;
  CheckTrue(Abs(LAcc.ReduceDot(@a, @b, 4) - 24.0) < EPS_F64, 'BatchF64 ReduceDot');

  a[0] := 5.0; a[1] := 1.0; a[2] := 9.0; a[3] := 3.0;
  CheckTrue(Abs(LAcc.ReduceMin(@a, 4) - 1.0) < EPS_F64, 'BatchF64 ReduceMin');
  CheckTrue(Abs(LAcc.ReduceMax(@a, 4) - 9.0) < EPS_F64, 'BatchF64 ReduceMax');

  for i := 0 to 3 do a[i] := Double(i + 1);
  LAcc.ArrayAddScalar(@a, @c, 4, 10.0);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Double(i + 11)) < EPS_F64, 'BatchF64 AddScalar');

  LAcc.ArrayMulScalar(@a, @c, 4, 3.0);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - Double((i + 1) * 3)) < EPS_F64, 'BatchF64 MulScalar');
end;

// --- I32x4 ---

procedure TTestDispatchAccessors.TestI32x4Accessor;
var
  LAcc: TI32x4Accessor;
  a, b, c: TVecI32x4;
  LMask: TMask4;
  buf: array[0..3] of Int32;
  i: Integer;
begin
  LAcc := GetI32x4Accessor;

  // Make/Extract
  a := LAcc.Make(10, 20, 30, 40);
  CheckEqual(LAcc.Extract(a, 0), 10, 'I32x4 Make 0');
  CheckEqual(LAcc.Extract(a, 1), 20, 'I32x4 Make 1');
  CheckEqual(LAcc.Extract(a, 2), 30, 'I32x4 Make 2');
  CheckEqual(LAcc.Extract(a, 3), 40, 'I32x4 Make 3');

  // Splat/Zero
  b := LAcc.Splat(7);
  for i := 0 to 3 do
    CheckEqual(LAcc.Extract(b, i), 7, 'I32x4 Splat');

  c := LAcc.Zero;
  for i := 0 to 3 do
    CheckEqual(LAcc.Extract(c, i), 0, 'I32x4 Zero');

  // Add
  a := LAcc.Make(1, 2, 3, 4);
  b := LAcc.Make(10, 20, 30, 40);
  c := LAcc.Add(a, b);
  CheckEqual(LAcc.Extract(c, 0), 11, 'I32x4 Add 0');
  CheckEqual(LAcc.Extract(c, 1), 22, 'I32x4 Add 1');
  CheckEqual(LAcc.Extract(c, 2), 33, 'I32x4 Add 2');
  CheckEqual(LAcc.Extract(c, 3), 44, 'I32x4 Add 3');

  // Sub
  c := LAcc.Sub(b, a);
  CheckEqual(LAcc.Extract(c, 0), 9, 'I32x4 Sub 0');
  CheckEqual(LAcc.Extract(c, 3), 36, 'I32x4 Sub 3');

  // Mul
  a := LAcc.Make(2, 3, 4, 5);
  b := LAcc.Make(10, 20, 30, 40);
  c := LAcc.Mul(a, b);
  CheckEqual(LAcc.Extract(c, 0), 20, 'I32x4 Mul 0');
  CheckEqual(LAcc.Extract(c, 1), 60, 'I32x4 Mul 1');
  CheckEqual(LAcc.Extract(c, 2), 120, 'I32x4 Mul 2');
  CheckEqual(LAcc.Extract(c, 3), 200, 'I32x4 Mul 3');

  // Neg
  a := LAcc.Make(5, -3, 0, 100);
  c := LAcc.Neg(a);
  CheckEqual(LAcc.Extract(c, 0), -5, 'I32x4 Neg 0');
  CheckEqual(LAcc.Extract(c, 1), 3, 'I32x4 Neg 1');
  CheckEqual(LAcc.Extract(c, 2), 0, 'I32x4 Neg 2');
  CheckEqual(LAcc.Extract(c, 3), -100, 'I32x4 Neg 3');

  // BitAnd/BitOr/BitXor/BitNot/BitAndNot
  a := LAcc.Make($FF00, $0FF0, $00FF, $FFFF);
  b := LAcc.Make($F0F0, $0F0F, $0F0F, $0000);

  c := LAcc.BitAnd(a, b);
  CheckEqual(LAcc.Extract(c, 0), $F000, 'I32x4 And 0');
  CheckEqual(LAcc.Extract(c, 1), $0F00, 'I32x4 And 1');

  c := LAcc.BitOr(a, b);
  CheckEqual(LAcc.Extract(c, 0), $FFF0, 'I32x4 Or 0');
  CheckEqual(LAcc.Extract(c, 1), $0FFF, 'I32x4 Or 1');

  c := LAcc.BitXor(a, b);
  CheckEqual(LAcc.Extract(c, 0), $0FF0, 'I32x4 Xor 0');

  c := LAcc.BitNot(LAcc.Make(0, -1, $FF, -$1));
  CheckEqual(LAcc.Extract(c, 0), -1, 'I32x4 Not 0');
  CheckEqual(LAcc.Extract(c, 1), 0, 'I32x4 Not 1');

  c := LAcc.BitAndNot(a, b); // NOT(a) AND b (SSE2 pandn semantics)
  CheckEqual(LAcc.Extract(c, 0), $00F0, 'I32x4 AndNot 0');

  // ShiftLeft/ShiftRight
  a := LAcc.Make(1, 4, 256, 1024);
  c := LAcc.ShiftLeft(a, 2);
  CheckEqual(LAcc.Extract(c, 0), 4, 'I32x4 Shl 0');
  CheckEqual(LAcc.Extract(c, 1), 16, 'I32x4 Shl 1');
  CheckEqual(LAcc.Extract(c, 2), 1024, 'I32x4 Shl 2');

  c := LAcc.ShiftRight(a, 1);
  CheckEqual(LAcc.Extract(c, 1), 2, 'I32x4 Shr 1');
  CheckEqual(LAcc.Extract(c, 2), 128, 'I32x4 Shr 2');

  // ShiftRightArith (sign-extending)
  a := LAcc.Make(-8, -16, 8, 16);
  c := LAcc.ShiftRightArith(a, 1);
  CheckEqual(LAcc.Extract(c, 0), -4, 'I32x4 Sar 0');
  CheckEqual(LAcc.Extract(c, 1), -8, 'I32x4 Sar 1');
  CheckEqual(LAcc.Extract(c, 2), 4, 'I32x4 Sar 2');

  // Min/Max
  a := LAcc.Make(5, 1, 9, 3);
  b := LAcc.Make(2, 8, 4, 6);
  c := LAcc.Min(a, b);
  CheckEqual(LAcc.Extract(c, 0), 2, 'I32x4 Min 0');
  CheckEqual(LAcc.Extract(c, 1), 1, 'I32x4 Min 1');
  c := LAcc.Max(a, b);
  CheckEqual(LAcc.Extract(c, 0), 5, 'I32x4 Max 0');
  CheckEqual(LAcc.Extract(c, 1), 8, 'I32x4 Max 1');

  // Comparisons
  a := LAcc.Make(1, 5, 3, 7);
  b := LAcc.Make(1, 3, 5, 7);

  LMask := LAcc.CmpEq(a, b);
  CheckTrue(LMask and $1 <> 0, 'I32x4 CmpEq T');
  CheckTrue(LMask and $2 = 0, 'I32x4 CmpEq F');
  CheckTrue(LMask and $8 <> 0, 'I32x4 CmpEq T2');

  LMask := LAcc.CmpLt(a, b);
  CheckTrue(LMask and $4 <> 0, 'I32x4 CmpLt T');
  CheckTrue(LMask and $2 = 0, 'I32x4 CmpLt F');

  LMask := LAcc.CmpGt(a, b);
  CheckTrue(LMask and $2 <> 0, 'I32x4 CmpGt T');
  CheckTrue(LMask and $4 = 0, 'I32x4 CmpGt F');

  // Select
  LMask := $5; // lanes 0,2 from a
  a := LAcc.Make(10, 20, 30, 40);
  b := LAcc.Make(100, 200, 300, 400);
  c := LAcc.Select(LMask, a, b);
  CheckEqual(LAcc.Extract(c, 0), 10, 'I32x4 Select a');
  CheckEqual(LAcc.Extract(c, 1), 200, 'I32x4 Select b');
  CheckEqual(LAcc.Extract(c, 2), 30, 'I32x4 Select a2');
  CheckEqual(LAcc.Extract(c, 3), 400, 'I32x4 Select b2');

  // Insert
  c := LAcc.Zero;
  c := LAcc.Insert(c, 42, 2);
  CheckEqual(LAcc.Extract(c, 2), 42, 'I32x4 Insert');
  CheckEqual(LAcc.Extract(c, 0), 0, 'I32x4 Insert other');

  // Load/Store
  buf[0] := 11; buf[1] := 22; buf[2] := 33; buf[3] := 44;
  c := LAcc.Load(@buf[0]);
  for i := 0 to 3 do
    CheckEqual(LAcc.Extract(c, i), buf[i], 'I32x4 Load');

  a := LAcc.Make(1, 2, 3, 4);
  LAcc.Store(@buf[0], a);
  for i := 0 to 3 do
    CheckEqual(buf[i], i + 1, 'I32x4 Store');
end;

// --- Mask ---

procedure TTestDispatchAccessors.TestMaskAccessor;
var
  LAcc: TMaskAccessor;
begin
  LAcc := GetMaskAccessor;

  // Mask2
  CheckTrue(LAcc.Mask2All($3), 'Mask2 All true');
  CheckFalse(LAcc.Mask2All($1), 'Mask2 All false');
  CheckTrue(LAcc.Mask2Any($1), 'Mask2 Any true');
  CheckFalse(LAcc.Mask2Any($0), 'Mask2 Any false');
  CheckTrue(LAcc.Mask2None($0), 'Mask2 None true');
  CheckFalse(LAcc.Mask2None($2), 'Mask2 None false');
  CheckEqual(LAcc.Mask2PopCount($3), 2, 'Mask2 PopCount 2');
  CheckEqual(LAcc.Mask2PopCount($1), 1, 'Mask2 PopCount 1');
  CheckEqual(LAcc.Mask2PopCount($0), 0, 'Mask2 PopCount 0');
  CheckEqual(LAcc.Mask2FirstSet($2), 1, 'Mask2 FirstSet 1');
  CheckEqual(LAcc.Mask2FirstSet($1), 0, 'Mask2 FirstSet 0');
  CheckEqual(LAcc.Mask2FirstSet($0), -1, 'Mask2 FirstSet none');

  // Mask4
  CheckTrue(LAcc.Mask4All($F), 'Mask4 All true');
  CheckFalse(LAcc.Mask4All($7), 'Mask4 All false');
  CheckTrue(LAcc.Mask4Any($8), 'Mask4 Any true');
  CheckFalse(LAcc.Mask4Any($0), 'Mask4 Any false');
  CheckTrue(LAcc.Mask4None($0), 'Mask4 None true');
  CheckFalse(LAcc.Mask4None($4), 'Mask4 None false');
  CheckEqual(LAcc.Mask4PopCount($F), 4, 'Mask4 PopCount 4');
  CheckEqual(LAcc.Mask4PopCount($5), 2, 'Mask4 PopCount 2');
  CheckEqual(LAcc.Mask4PopCount($0), 0, 'Mask4 PopCount 0');
  CheckEqual(LAcc.Mask4FirstSet($4), 2, 'Mask4 FirstSet 2');
  CheckEqual(LAcc.Mask4FirstSet($1), 0, 'Mask4 FirstSet 0');
  CheckEqual(LAcc.Mask4FirstSet($0), -1, 'Mask4 FirstSet none');

  // Mask8
  CheckTrue(LAcc.Mask8All($FF), 'Mask8 All true');
  CheckFalse(LAcc.Mask8All($7F), 'Mask8 All false');
  CheckTrue(LAcc.Mask8Any($80), 'Mask8 Any true');
  CheckFalse(LAcc.Mask8Any($00), 'Mask8 Any false');
  CheckTrue(LAcc.Mask8None($00), 'Mask8 None true');
  CheckFalse(LAcc.Mask8None($01), 'Mask8 None false');
  CheckEqual(LAcc.Mask8PopCount($FF), 8, 'Mask8 PopCount 8');
  CheckEqual(LAcc.Mask8PopCount($A5), 4, 'Mask8 PopCount 4');
  CheckEqual(LAcc.Mask8FirstSet($20), 5, 'Mask8 FirstSet 5');
  CheckEqual(LAcc.Mask8FirstSet($00), -1, 'Mask8 FirstSet none');

  // Mask16
  CheckTrue(LAcc.Mask16All($FFFF), 'Mask16 All true');
  CheckFalse(LAcc.Mask16All($7FFF), 'Mask16 All false');
  CheckTrue(LAcc.Mask16Any($8000), 'Mask16 Any true');
  CheckFalse(LAcc.Mask16Any($0000), 'Mask16 Any false');
  CheckTrue(LAcc.Mask16None($0000), 'Mask16 None true');
  CheckFalse(LAcc.Mask16None($0001), 'Mask16 None false');
  CheckEqual(LAcc.Mask16PopCount($FFFF), 16, 'Mask16 PopCount 16');
  CheckEqual(LAcc.Mask16PopCount($F0F0), 8, 'Mask16 PopCount 8');
  CheckEqual(LAcc.Mask16FirstSet($0100), 8, 'Mask16 FirstSet 8');
  CheckEqual(LAcc.Mask16FirstSet($0000), -1, 'Mask16 FirstSet none');
end;

// --- BatchInteger ---

procedure TTestDispatchAccessors.TestBatchIntegerAccessor;
var
  LAcc: TBatchIntegerAccessor;
  a32, b32, c32: array[0..3] of Int32;
  a16, b16, c16: array[0..3] of Int16;
  aF32: array[0..3] of Single;
  cF32: array[0..3] of Single;
  i: Integer;
begin
  LAcc := GetBatchIntegerAccessor;

  // I32 Add/Sub
  for i := 0 to 3 do begin a32[i] := i * 10; b32[i] := i; end;
  LAcc.ArrayAddI32(@a32, @b32, @c32, 4);
  for i := 0 to 3 do
    CheckEqual(c32[i], i * 10 + i, 'BatchI AddI32');

  LAcc.ArraySubI32(@a32, @b32, @c32, 4);
  for i := 0 to 3 do
    CheckEqual(c32[i], i * 10 - i, 'BatchI SubI32');

  // I32 bitwise
  for i := 0 to 3 do begin a32[i] := $FF00; b32[i] := $0FF0; end;
  LAcc.ArrayAndI32(@a32, @b32, @c32, 4);
  CheckEqual(c32[0], $FF00 and $0FF0, 'BatchI AndI32');

  LAcc.ArrayOrI32(@a32, @b32, @c32, 4);
  CheckEqual(c32[0], $FF00 or $0FF0, 'BatchI OrI32');

  LAcc.ArrayXorI32(@a32, @b32, @c32, 4);
  CheckEqual(c32[0], $FF00 xor $0FF0, 'BatchI XorI32');

  // I32 shift
  for i := 0 to 3 do a32[i] := 1;
  LAcc.ArrayShlI32(@a32, @c32, 4, 3);
  for i := 0 to 3 do
    CheckEqual(c32[i], 8, 'BatchI ShlI32');

  for i := 0 to 3 do a32[i] := 16;
  LAcc.ArrayShrI32(@a32, @c32, 4, 2);
  for i := 0 to 3 do
    CheckEqual(c32[i], 4, 'BatchI ShrI32');

  // I16 Mul (only Mul has scalar implementation)
  for i := 0 to 3 do begin a16[i] := Int16(i + 1); b16[i] := Int16(i + 5); end;
  LAcc.ArrayMulI16(@a16, @b16, @c16, 4);
  for i := 0 to 3 do
    CheckEqual(c16[i], Int16((i + 1) * (i + 5)), 'BatchI MulI16');

  // F32 <-> I32 conversion
  aF32[0] := 1.9; aF32[1] := -2.5; aF32[2] := 3.1; aF32[3] := 0.0;
  LAcc.ArrayF32toI32(@aF32, @c32, 4);
  CheckEqual(c32[0], 2, 'BatchI F32toI32 0');  // Round(1.9)=2
  CheckEqual(c32[1], -3, 'BatchI F32toI32 1'); // Round(-2.5)=-3 in FPC
  CheckEqual(c32[2], 3, 'BatchI F32toI32 2');  // Round(3.1)=3
  CheckEqual(c32[3], 0, 'BatchI F32toI32 3');  // Round(0.0)=0

  a32[0] := 10; a32[1] := -20; a32[2] := 30; a32[3] := 0;
  LAcc.ArrayI32toF32(@a32, @cF32, 4);
  CheckTrue(Abs(cF32[0] - 10.0) < EPS_F32, 'BatchI I32toF32 0');
  CheckTrue(Abs(cF32[1] - (-20.0)) < EPS_F32, 'BatchI I32toF32 1');
  CheckTrue(Abs(cF32[2] - 30.0) < EPS_F32, 'BatchI I32toF32 2');
  CheckTrue(Abs(cF32[3]) < EPS_F32, 'BatchI I32toF32 3');

  // PackSat I32->I16
  a32[0] := 100; a32[1] := 40000; a32[2] := -40000; a32[3] := -100;
  LAcc.ArrayPackSatI32toI16(@a32, @c16, 4);
  CheckEqual(c16[0], 100, 'BatchI PackSat normal');
  CheckEqual(c16[1], 32767, 'BatchI PackSat hi clamp');
  CheckEqual(c16[2], -32768, 'BatchI PackSat lo clamp');
  CheckEqual(c16[3], -100, 'BatchI PackSat neg');
end;

end.
