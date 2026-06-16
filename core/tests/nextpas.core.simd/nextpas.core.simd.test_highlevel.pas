program nextpas.core.simd.test_highlevel;

{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.pipeline,
  nextpas.core.simd.dispatch;

var
  g_Checks: Integer = 0;
  g_Fails: Integer = 0;

procedure Check(const aName: string; aExpected, aActual: Single; aTol: Single = 1e-5);
begin
  Inc(g_Checks);
  if System.Abs(aExpected - aActual) > aTol * Max(System.Abs(aExpected), 1e-7) then
  begin
    WriteLn('[FAIL] ', aName, ': expected ', aExpected:0:6, ' got ', aActual:0:6);
    Inc(g_Fails);
  end;
end;

procedure TestAlloc;
var p: Pointer;
begin
  p := SimdAlloc(1024);
  Check('Alloc not nil', 1, Ord(p <> nil));
  Check('Alloc aligned 32', 0, PtrUInt(p) mod 32);
  SimdFree(p);

  p := SimdAlloc(256, sa64);
  Check('Alloc64 aligned', 0, PtrUInt(p) mod 64);
  SimdFree(p);
  WriteLn('  SimdAlloc: OK');
end;

procedure TestArray;
var
  A, B, C: TSimdF32Array;
  i: Integer;
begin
  A := TSimdF32Array.Zeros(1024);
  Check('Zeros[0]', 0, A.Data[0]);
  Check('Zeros sum', 0, A.Sum);
  A.Free;

  A := TSimdF32Array.Ones(100);
  Check('Ones sum', 100, A.Sum);
  Check('Ones mean', 1, A.Mean);
  A.Free;

  A := TSimdF32Array.Create(64);

  for i := 0 to 63 do A.Data[i] := i;
  Check('Sum 0..63', 2016, A.Sum);
  Check('Min', 0, A.Min);
  Check('Max', 63, A.Max);

  B := A.Slice(10, 10);
  Check('Slice sum', 145, B.Sum);

  C := A * 2.0;
  Check('Mul scalar', 126, C.Data[63]);
  C.Free;
  A.Free;
  WriteLn('  TSimdF32Array: OK');
end;

procedure TestStride;
var
  raw: array[0..99] of Single;
  A: TSimdF32Array;
  i: Integer;
begin
  for i := 0 to 99 do raw[i] := i;

  A := TSimdF32Array.WrapStrided(@raw[0], 50, 2);
  Check('Stride count', 50, A.Count);
  Check('Stride[0]', 0, A.Data[0]);
  Check('Stride elem 1', 2, A.Data[2]);
  Check('Stride sum', 2450, A.Sum);
  WriteLn('  Stride: OK');
end;

procedure TestPipeline;
var
  src, dst: array[0..63] of Single;
  i: Integer;
  pipe: TSimdF32Pipeline;
  R: TSimdF32Array;
begin
  for i := 0 to 63 do src[i] := i - 32;

  // Test: dst = src * 2 + 1 (should fuse to Linear)
  pipe := TSimdF32Pipeline.From(@src[0], 64);
  pipe := pipe.MulScalar(2.0).AddScalar(1.0);
  pipe.Into(@dst[0]);
  Check('Pipeline Linear[0]', -63, dst[0]);
  Check('Pipeline Linear[32]', 1, dst[32]);
  Check('Pipeline Linear[63]', 63, dst[63]);

  // Test: Eval returns new array
  for i := 0 to 63 do src[i] := i;
  R := TSimdF32Pipeline.From(@src[0], 64).MulScalar(0.5).Eval;
  Check('Pipeline Eval[10]', 5, R.Data[10]);
  R.Free;

  // Test: ReLU
  for i := 0 to 63 do src[i] := i - 32;
  TSimdF32Pipeline.From(@src[0], 64).ReLU.Into(@dst[0]);
  Check('Pipeline ReLU[-1]', 0, dst[31]);
  Check('Pipeline ReLU[1]', 1, dst[33]);

  WriteLn('  Pipeline: OK');
end;

begin
  WriteLn('[High-Level SIMD API Test]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestAlloc;
  TestArray;
  TestStride;
  TestPipeline;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_Checks, g_Fails]));
  if g_Fails > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
