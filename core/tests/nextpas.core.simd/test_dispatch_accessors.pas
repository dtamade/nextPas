// === Dispatch Table Accessor Tests ===
// Tests for the new modular accessor pattern

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
  end;

implementation

procedure TTestDispatchAccessors.TestF32x4Accessor;
var
  LAccessor: TF32x4Accessor;
  a, b, c: TVecF32x4;
  LMask: TMask4;
  LValue: Single;
begin
  LAccessor := GetF32x4Accessor;

  // Test basic arithmetic
  a := LAccessor.Splat(2.0);
  b := LAccessor.Splat(3.0);
  c := LAccessor.Add(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 5.0) < 0.001, 'F32x4 Add');

  c := LAccessor.Sub(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - (-1.0)) < 0.001, 'F32x4 Sub');

  c := LAccessor.Mul(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 6.0) < 0.001, 'F32x4 Mul');

  c := LAccessor.Divide(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - (2.0/3.0)) < 0.001, 'F32x4 Divide');

  // Test comparison
  LMask := LAccessor.CmpEq(a, b);
  CheckFalse(LAccessor.ReduceAdd(LAccessor.Select(LMask, LAccessor.Splat(1.0), LAccessor.Splat(0.0))) > 0, 'F32x4 CmpEq false');

  LMask := LAccessor.CmpLt(a, b);
  CheckTrue(LAccessor.ReduceAdd(LAccessor.Select(LMask, LAccessor.Splat(1.0), LAccessor.Splat(0.0))) > 0, 'F32x4 CmpLt true');

  // Test math functions
  c := LAccessor.Abs(LAccessor.Splat(-5.0));
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 5.0) < 0.001, 'F32x4 Abs');

  c := LAccessor.Sqrt(LAccessor.Splat(16.0));
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 4.0) < 0.001, 'F32x4 Sqrt');

  // Test min/max
  c := LAccessor.Min(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 2.0) < 0.001, 'F32x4 Min');

  c := LAccessor.Max(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 3.0) < 0.001, 'F32x4 Max');
end;

procedure TTestDispatchAccessors.TestF64x2Accessor;
var
  LAccessor: TF64x2Accessor;
  a, b, c: TVecF64x2;
  LValue: Double;
begin
  LAccessor := GetF64x2Accessor;

  // Test basic arithmetic
  a := LAccessor.Splat(2.0);
  b := LAccessor.Splat(3.0);
  c := LAccessor.Add(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 5.0) < 0.001, 'F64x2 Add');

  c := LAccessor.Sub(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - (-1.0)) < 0.001, 'F64x2 Sub');

  c := LAccessor.Mul(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 6.0) < 0.001, 'F64x2 Mul');

  c := LAccessor.Divide(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - (2.0/3.0)) < 0.001, 'F64x2 Divide');

  // Test math functions
  c := LAccessor.Abs(LAccessor.Splat(-5.0));
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 5.0) < 0.001, 'F64x2 Abs');

  c := LAccessor.Sqrt(LAccessor.Splat(16.0));
  LValue := LAccessor.Extract(c, 0);
  CheckTrue(Abs(LValue - 4.0) < 0.001, 'F64x2 Sqrt');
end;

procedure TTestDispatchAccessors.TestMemoryAccessor;
var
  LAccessor: TMemoryAccessor;
  a, b: array[0..15] of Byte;
  i: Integer;
begin
  LAccessor := GetMemoryAccessor;

  // Test MemEqual
  for i := 0 to 15 do
  begin
    a[i] := i;
    b[i] := i;
  end;
  CheckTrue(LAccessor.Equal(@a, @b, 16), 'MemEqual true');

  b[5] := 99;
  CheckFalse(LAccessor.Equal(@a, @b, 16), 'MemEqual false');

  // Test MemFindByte
  CheckEqual(5, LAccessor.FindByte(@a, 16, 5), 'MemFindByte found');
  CheckEqual(-1, LAccessor.FindByte(@a, 16, 99), 'MemFindByte not found');

  // Test MemCopy
  LAccessor.Copy(@a, @b, 16);
  CheckTrue(LAccessor.Equal(@a, @b, 16), 'MemCopy');

  // Test MemFill
  LAccessor.Fill(@b, 16, 42);
  for i := 0 to 15 do
    CheckEqual(42, b[i], 'MemFill');
end;

procedure TTestDispatchAccessors.TestBatchF32Accessor;
var
  LAccessor: TBatchF32Accessor;
  a, b, c: array[0..3] of Single;
  i: Integer;
begin
  LAccessor := GetBatchF32Accessor;

  // Test ArrayAdd
  for i := 0 to 3 do
  begin
    a[i] := i * 1.0;
    b[i] := i * 2.0;
  end;
  LAccessor.ArrayAdd(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - i * 3.0) < 0.001, 'BatchF32 ArrayAdd');

  // Test ArrayMul
  LAccessor.ArrayMul(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - i * i * 2.0) < 0.001, 'BatchF32 ArrayMul');

  // Test ReduceSum
  CheckTrue(Abs(LAccessor.ReduceSum(@a, 4) - 6.0) < 0.001, 'BatchF32 ReduceSum');
end;

procedure TTestDispatchAccessors.TestBatchF64Accessor;
var
  LAccessor: TBatchF64Accessor;
  a, b, c: array[0..3] of Double;
  i: Integer;
begin
  LAccessor := GetBatchF64Accessor;

  // Test ArrayAdd
  for i := 0 to 3 do
  begin
    a[i] := i * 1.0;
    b[i] := i * 2.0;
  end;
  LAccessor.ArrayAdd(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - i * 3.0) < 0.001, 'BatchF64 ArrayAdd');

  // Test ArrayMul
  LAccessor.ArrayMul(@a, @b, @c, 4);
  for i := 0 to 3 do
    CheckTrue(Abs(c[i] - i * i * 2.0) < 0.001, 'BatchF64 ArrayMul');

  // Test ReduceSum
  CheckTrue(Abs(LAccessor.ReduceSum(@a, 4) - 6.0) < 0.001, 'BatchF64 ReduceSum');
end;

end.
