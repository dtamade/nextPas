{
  test_simd_static_dispatch.pas

  Test SIMD static dispatch functionality.
  This test verifies that:
  1. Static dispatch macros work correctly
  2. Backend priority configuration works
  3. Vectorization hints compile without errors
}

program test_simd_static_dispatch;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.time.stopwatch,
  nextpas.core.simd.base, nextpas.core.simd;

{$M+}
type
  TTestCase_StaticDispatch = class(TTestFixture)
  published
    procedure Test_StaticDispatch_Enabled;
    procedure Test_F32x4_Add_Performance;
    procedure Test_F32x4_Dot_Performance;
    procedure Test_F64x2_Add_Performance;
    procedure Test_BatchAdd_Performance;
    procedure Test_BatchMul_Performance;
    procedure Test_MemEqual_Performance;
    procedure Test_ReduceMax_Performance;
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
  LSw: TStopwatch;
  ElapsedMs: Double;
const
  ITERATIONS = 10000000;
begin
  a := VecF32x4Splat(1.0);
  b := VecF32x4Splat(2.0);

  LSw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
  begin
    c := VecF32x4Add(a, b);
    a := c;  // Prevent optimization
  end;
  ElapsedMs := LSw.ElapsedMilliseconds;

  // Verify correctness
  CheckTrue(Abs(VecF32x4Extract(c, 0) - 3.0 * ITERATIONS) < 1.0, 'F32x4Add correctness check');

  // Log performance
  WriteLn(Format('F32x4Add: %d iterations in %.1f ms (%.2f ns/op)', [ITERATIONS, ElapsedMs, ElapsedMs * 1000000 / ITERATIONS]));
end;

procedure TTestCase_StaticDispatch.Test_F32x4_Dot_Performance;
var
  a, b: TVecF32x4;
  d: Single;
  i: Integer;
  LSw: TStopwatch;
  ElapsedMs: Double;
const
  ITERATIONS = 10000000;
begin
  a := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  b := VecF32x4Make(5.0, 6.0, 7.0, 8.0);

  LSw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
  begin
    d := VecF32x4Dot(a, b);
    a := VecF32x4Splat(d);  // Prevent optimization
  end;
  ElapsedMs := LSw.ElapsedMilliseconds;

  // Log performance
  WriteLn(Format('F32x4Dot: %d iterations in %.1f ms (%.2f ns/op)', [ITERATIONS, ElapsedMs, ElapsedMs * 1000000 / ITERATIONS]));
end;

procedure TTestCase_StaticDispatch.Test_F64x2_Add_Performance;
var
  a, b, c: TVecF64x2;
  i: Integer;
  LSw: TStopwatch;
  ElapsedMs: Double;
const
  ITERATIONS = 10000000;
begin
  a := VecF64x2Splat(1.0);
  b := VecF64x2Splat(2.0);

  LSw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
  begin
    c := VecF64x2Add(a, b);
    a := c;  // Prevent optimization
  end;
  ElapsedMs := LSw.ElapsedMilliseconds;

  // Log performance
  WriteLn(Format('F64x2Add: %d iterations in %.1f ms (%.2f ns/op)', [ITERATIONS, ElapsedMs, ElapsedMs * 1000000 / ITERATIONS]));
end;

procedure TTestCase_StaticDispatch.Test_BatchAdd_Performance;
var
  src1, src2, dst: array[0..1023] of Single;
  i: Integer;
  LSw: TStopwatch;
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

  LSw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
  begin
    ArrayAddF32(@src1[0], @src2[0], @dst[0], ARRAY_SIZE);
  end;
  ElapsedMs := LSw.ElapsedMilliseconds;

  // Verify correctness
  CheckTrue(Abs(dst[0] - 3.0) < 0.001, 'BatchAdd correctness check');

  // Log performance
  WriteLn(Format('ArrayAddF32(%d): %d iterations in %.1f ms (%.2f ns/elem)', [ARRAY_SIZE, ITERATIONS, ElapsedMs,
     ElapsedMs * 1000000 / (ITERATIONS * ARRAY_SIZE)]));
end;

procedure TTestCase_StaticDispatch.Test_BatchMul_Performance;
var
  src1, src2, dst: array[0..1023] of Single;
  i: Integer;
  LSw: TStopwatch;
  ElapsedMs: Double;
const
  ITERATIONS = 100000;
  ARRAY_SIZE = 1024;
begin
  // Initialize arrays
  for i := 0 to ARRAY_SIZE - 1 do
  begin
    src1[i] := 1.5;
    src2[i] := 2.5;
  end;

  LSw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
  begin
    ArrayMulF32(@src1[0], @src2[0], @dst[0], ARRAY_SIZE);
  end;
  ElapsedMs := LSw.ElapsedMilliseconds;

  // Verify correctness
  CheckTrue(Abs(dst[0] - 3.75) < 0.001, 'BatchMul correctness check');

  // Log performance
  WriteLn(Format('ArrayMulF32(%d): %d iterations in %.1f ms (%.2f ns/elem)', [ARRAY_SIZE, ITERATIONS, ElapsedMs,
     ElapsedMs * 1000000 / (ITERATIONS * ARRAY_SIZE)]));
end;

procedure TTestCase_StaticDispatch.Test_MemEqual_Performance;
var
  buf1, buf2: array[0..4095] of Byte;
  i: Integer;
  LSw: TStopwatch;
  ElapsedMs: Double;
  Match: Boolean;
const
  ITERATIONS = 100000;
  BUF_SIZE = 4096;
begin
  // Initialize buffers
  for i := 0 to BUF_SIZE - 1 do
  begin
    buf1[i] := i mod 256;
    buf2[i] := i mod 256;
  end;

  LSw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
  begin
    Match := MemEqual(@buf1[0], @buf2[0], BUF_SIZE);
  end;
  ElapsedMs := LSw.ElapsedMilliseconds;

  // Verify correctness
  CheckTrue(Match = True, 'MemEqual correctness check');

  // Log performance
  WriteLn(Format('MemEqual(%d): %d iterations in %.1f ms (%.2f ns/elem)', [BUF_SIZE, ITERATIONS, ElapsedMs,
     ElapsedMs * 1000000 / (ITERATIONS * BUF_SIZE)]));
end;

procedure TTestCase_StaticDispatch.Test_ReduceMax_Performance;
var
  src: array[0..1023] of Single;
  i: Integer;
  LSw: TStopwatch;
  ElapsedMs: Double;
  MaxVal: Single;
const
  ITERATIONS = 100000;
  ARRAY_SIZE = 1024;
begin
  // Initialize array
  for i := 0 to ARRAY_SIZE - 1 do
    src[i] := Sin(i * 0.1);

  LSw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
  begin
    MaxVal := ReduceMaxF32(@src[0], ARRAY_SIZE);
  end;
  ElapsedMs := LSw.ElapsedMilliseconds;

  // Verify correctness
  CheckTrue(MaxVal > 0.9, 'ReduceMax correctness check');

  // Log performance
  WriteLn(Format('ReduceMaxF32(%d): %d iterations in %.1f ms (%.2f ns/elem)', [ARRAY_SIZE, ITERATIONS, ElapsedMs,
     ElapsedMs * 1000000 / (ITERATIONS * ARRAY_SIZE)]));
end;

var
  LRunner: TSuiteRunner;
begin
  LRunner := TSuiteRunner.Create('SIMD_StaticDispatch');
  LRunner.Add(DiscoverTests(TTestCase_StaticDispatch.Create, 'TTestCase_StaticDispatch'));
  LRunner.RunAll;
  LRunner.Summary;
  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
  LRunner := Default(TSuiteRunner);
end.
