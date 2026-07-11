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
    procedure TestI32x4Accessor;
    procedure TestMaskAccessor;
    procedure TestBatchIntegerAccessor;
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

procedure TTestDispatchAccessors.TestI32x4Accessor;
var
  LAccessor: TI32x4Accessor;
  a, b, c: TVecI32x4;
  LValue: Int32;
begin
  LAccessor := GetI32x4Accessor;

  // Test basic arithmetic
  a := LAccessor.Splat(10);
  b := LAccessor.Splat(20);
  c := LAccessor.Add(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckEqual(LValue, 30, 'I32x4 Add');

  c := LAccessor.Sub(b, a);
  LValue := LAccessor.Extract(c, 0);
  CheckEqual(LValue, 10, 'I32x4 Sub');

  c := LAccessor.Mul(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckEqual(LValue, 200, 'I32x4 Mul');

  // Test bitwise operations
  c := LAccessor.BitAnd(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckEqual(LValue, 0, 'I32x4 BitAnd');

  c := LAccessor.BitOr(a, b);
  LValue := LAccessor.Extract(c, 0);
  CheckEqual(LValue, 30, 'I32x4 BitOr');

  // Test Make/Extract
  c := LAccessor.Make(1, 2, 3, 4);
  LValue := LAccessor.Extract(c, 2);
  CheckEqual(LValue, 3, 'I32x4 Make/Extract');
end;

procedure TTestDispatchAccessors.TestMaskAccessor;
var
  LAccessor: TMaskAccessor;
  LMask4: TMask4;
begin
  LAccessor := GetMaskAccessor;

  // Test all set
  LMask4 := $F;
  CheckTrue(LAccessor.Mask4All(LMask4), 'Mask4 All');
  CheckTrue(LAccessor.Mask4Any(LMask4), 'Mask4 Any');
  CheckFalse(LAccessor.Mask4None(LMask4), 'Mask4 None');
  CheckEqual(LAccessor.Mask4PopCount(LMask4), 4, 'Mask4 PopCount');
  CheckEqual(LAccessor.Mask4FirstSet(LMask4), 0, 'Mask4 FirstSet');

  // Test partial set
  LMask4 := $5;
  CheckFalse(LAccessor.Mask4All(LMask4), 'Mask4 All partial');
  CheckTrue(LAccessor.Mask4Any(LMask4), 'Mask4 Any partial');
  CheckFalse(LAccessor.Mask4None(LMask4), 'Mask4 None partial');
  CheckEqual(LAccessor.Mask4PopCount(LMask4), 2, 'Mask4 PopCount partial');
  CheckEqual(LAccessor.Mask4FirstSet(LMask4), 0, 'Mask4 FirstSet partial');
end;

procedure TTestDispatchAccessors.TestBatchIntegerAccessor;
var
  LAccessor: TBatchIntegerAccessor;
  LSrc1, LSrc2, LDst: array[0..3] of Int32;
  i: Integer;
begin
  LAccessor := GetBatchIntegerAccessor;

  // Test ArrayAddI32
  for i := 0 to 3 do
  begin
    LSrc1[i] := i + 1;
    LSrc2[i] := (i + 1) * 10;
    LDst[i] := 0;
  end;
  LAccessor.ArrayAddI32(@LSrc1[0], @LSrc2[0], @LDst[0], 4);
  for i := 0 to 3 do
    CheckEqual(LDst[i], LSrc1[i] + LSrc2[i], 'BatchI32 ArrayAdd');

  // Test ArraySubI32
  LAccessor.ArraySubI32(@LSrc2[0], @LSrc1[0], @LDst[0], 4);
  for i := 0 to 3 do
    CheckEqual(LDst[i], LSrc2[i] - LSrc1[i], 'BatchI32 ArraySub');
end;

end.
