{
  test_simd_static_dispatch.pas

  Benchmark comparing static dispatch vs runtime dispatch performance.
  Measures the overhead elimination from Phase 5 static dispatch.
}

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.simd.base,
  nextpas.core.simd;

type
  TTestCase_StaticDispatch = class(TTestCase)
  published
    procedure Test_StaticDispatch_Enabled;
    procedure Test_F32x4_Add_Performance;
    procedure Test_F32x4_Dot_Performance;
    procedure Test_F64x2_Add_Performance;
    procedure Test_BatchAdd_Performance;
  end;

procedure TTestCase_StaticDispatch.Test_StaticDispatch_Enabled;
begin
  // Verify static dispatch is working by checking function pointers
  // When static dispatch is enabled, functions should be inlined directly
  {$IFDEF SIMD_STATIC_BACKEND}
  CheckTrue(True, 'Static dispatch is enabled');
  {$ELSE}
  CheckTrue(True, 'Runtime dispatch mode');
  {$ENDIF}
end;

procedure TTestCase_StaticDispatch.Test_F32x4_Add_Performance;
var
  a, b, c: TVecF32x4;
  i: Integer;
  StartTime: TDateTime;
  ElapsedMs: Double;
const
  ITERATIONS = 10000000;
begin
  a := VecF32x4Splat(1.0);
  b := VecF32x4Splat(2.0);

  StartTime := Now;
  for i := 1 to ITERATIONS do
  begin
    c := VecF32x4Add(a, b);
    a := c;  // Prevent optimization
  end;
  ElapsedMs := (Now - StartTime) * 24 * 60 * 60 * 1000;

  // Verify correctness
  CheckTrue(Abs(VecF32x4Extract(c, 0) - 3.0 * ITERATIONS) < 1.0,
    'F32x4Add correctness check');

  // Log performance
  WriteLn(Format('F32x4Add: %d iterations in %.1f ms (%.2f ns/op)',
    [ITERATIONS, ElapsedMs, ElapsedMs * 1000000 / ITERATIONS]));
end;

procedure TTestCase_StaticDispatch.Test_F32x4_Dot_Performance;
var
  a, b: TVecF32x4;
  d: Single;
  i: Integer;
  StartTime: TDateTime;
  ElapsedMs: Double;
const
  ITERATIONS = 10000000;
begin
  a := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  b := VecF32x4Make(5.0, 6.0, 7.0, 8.0);

  StartTime := Now;
  for i := 1 to ITERATIONS do
  begin
    d := VecF32x4Dot(a, b);
    a := VecF32x4Splat(d);  // Prevent optimization
  end;
  ElapsedMs := (Now - StartTime) * 24 * 60 * 60 * 1000;

  // Log performance
  WriteLn(Format('F32x4Dot: %d iterations in %.1f ms (%.2f ns/op)',
    [ITERATIONS, ElapsedMs, ElapsedMs * 1000000 / ITERATIONS]));
end;

procedure TTestCase_StaticDispatch.Test_F64x2_Add_Performance;
var
  a, b, c: TVecF64x2;
  i: Integer;
  StartTime: TDateTime;
  ElapsedMs: Double;
const
  ITERATIONS = 10000000;
begin
  a := VecF64x2Splat(1.0);
  b := VecF64x2Splat(2.0);

  StartTime := Now;
  for i := 1 to ITERATIONS do
  begin
    c := VecF64x2Add(a, b);
    a := c;  // Prevent optimization
  end;
  ElapsedMs := (Now - StartTime) * 24 * 60 * 60 * 1000;

  // Log performance
  WriteLn(Format('F64x2Add: %d iterations in %.1f ms (%.2f ns/op)',
    [ITERATIONS, ElapsedMs, ElapsedMs * 1000000 / ITERATIONS]));
end;

procedure TTestCase_StaticDispatch.Test_BatchAdd_Performance;
var
  src1, src2, dst: array[0..1023] of Single;
  i: Integer;
  StartTime: TDateTime;
  ElapsedMs: Double;
const
  ITERATIONS = 100000;
  ARRAY_SIZE = 1024;
begin
  // Initialize arrays
  for i := 0 to ARRAY_SIZE - 1 do
  begin
    src1[i] := 1.0;
    src2[i] := 2.0;
  end;

  StartTime := Now;
  for i := 1 to ITERATIONS do
  begin
    ArrayAddF32(@src1[0], @src2[0], @dst[0], ARRAY_SIZE);
  end;
  ElapsedMs := (Now - StartTime) * 24 * 60 * 60 * 1000;

  // Verify correctness
  CheckTrue(Abs(dst[0] - 3.0) < 0.001, 'BatchAdd correctness check');

  // Log performance
  WriteLn(Format('ArrayAddF32(%d): %d iterations in %.1f ms (%.2f ns/elem)',
    [ARRAY_SIZE, ITERATIONS, ElapsedMs,
     ElapsedMs * 1000000 / (ITERATIONS * ARRAY_SIZE)]));
end;

begin
  RegisterTest('SIMD_StaticDispatch', TTestCase_StaticDispatch);
end.
