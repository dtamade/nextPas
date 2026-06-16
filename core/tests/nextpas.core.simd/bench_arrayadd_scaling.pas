program bench_arrayadd_scaling;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads, BaseUnix, Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  nextpas.core.text.conv, Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.scalar,
  nextpas.core.simd.dispatch;

const
  WARMUP = 100;
  ITERS = 5000;

type
  TElementSizes = array of SizeUInt;

var
  g_ElementSizes: TElementSizes = (16, 64, 256, 1024, 4096, 16384, 65536);

// === F32 ===
var
  F32A, F32B, F32Dst: array of Single;

// === F64 ===
var
  F64A, F64B, F64Dst: array of Double;

// === I32 ===
var
  I32A, I32B, I32Dst: array of Int32;

var
  g_MaxSize: SizeUInt;
  g_Dispatch: PSimdDispatchTable;
  g_ScalarF32Dummy: Single;
  g_ScalarF64Dummy: Double;
  g_ScalarI32Dummy: Int32;

// Global state for benchmarks
var
  g_BenchCount: SizeUInt;

function GetNanoTime: Int64;
{$IFDEF UNIX}
var tv: TTimeVal;
begin
  fpgettimeofday(@tv, nil);
  Result := Int64(tv.tv_sec) * 1000000000 + Int64(tv.tv_usec) * 1000;
end;
{$ELSE}
var f, c: Int64;
begin
  QueryPerformanceFrequency(f);
  QueryPerformanceCounter(c);
  Result := c * 1000000000 div f;
end;
{$ENDIF}

function BenchArray(aProc: TProcedure): Double;
var
  t0, t1: Int64;
  j, warm: Integer;
begin
  if g_BenchCount = 0 then
    Exit(0.0);

  for warm := 0 to WARMUP - 1 do
    aProc();
  t0 := GetNanoTime;
  for j := 0 to ITERS - 1 do
    aProc();
  t1 := GetNanoTime;
  Result := (t1 - t0) / ITERS / g_BenchCount;
end;

// MB/s: 3x streams (2 reads + 1 write)
function MBps(aCount, aElemSize: SizeUInt; aNsPerElem: Double): Double;
begin
  if aNsPerElem <= 0 then
    Result := 0
  else
    Result := (aCount * aElemSize * 3) / (aNsPerElem * 1e9) * 1e6;
end;

procedure FillF32(aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
  begin
    F32A[i] := Sin(i * 0.7) * 50.0;
    F32B[i] := Cos(i * 1.1) * 30.0 + 1.0;
    F32Dst[i] := 0.0;
  end;
end;

procedure FillF64(aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
  begin
    F64A[i] := Sin(i * 0.7) * 50.0;
    F64B[i] := Cos(i * 1.1) * 30.0 + 1.0;
    F64Dst[i] := 0.0;
  end;
end;

procedure FillI32(aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
  begin
    I32A[i] := Int32((i * 17) xor $5A5A5A5A);
    I32B[i] := Int32((i * 31) xor $A5A5A5A5);
    I32Dst[i] := 0;
  end;
end;

// Bench procedures use global state to avoid nested proc issues
procedure BenchF32ScalarAdd;
begin
  ScalarArrayAddF32(@F32A[0], @F32B[0], @F32Dst[0], g_BenchCount);
  g_ScalarF32Dummy := F32Dst[g_BenchCount - 1];
end;

procedure BenchF32SimdAdd;
begin
  g_Dispatch^.ArrayAddF32(@F32A[0], @F32B[0], @F32Dst[0], g_BenchCount);
  g_ScalarF32Dummy := F32Dst[g_BenchCount - 1];
end;

procedure BenchF64ScalarAdd;
begin
  ScalarArrayAddF64(@F64A[0], @F64B[0], @F64Dst[0], g_BenchCount);
  g_ScalarF64Dummy := F64Dst[g_BenchCount - 1];
end;

procedure BenchF64SimdAdd;
begin
  g_Dispatch^.ArrayAddF64(@F64A[0], @F64B[0], @F64Dst[0], g_BenchCount);
  g_ScalarF64Dummy := F64Dst[g_BenchCount - 1];
end;

procedure BenchI32ScalarAdd;
begin
  ScalarArrayAddI32(@I32A[0], @I32B[0], @I32Dst[0], g_BenchCount);
  g_ScalarI32Dummy := I32Dst[g_BenchCount - 1];
end;

procedure BenchI32SimdAdd;
begin
  g_Dispatch^.ArrayAddI32(@I32A[0], @I32B[0], @I32Dst[0], g_BenchCount);
  g_ScalarI32Dummy := I32Dst[g_BenchCount - 1];
end;

procedure RunF32Bench(const aName: string; aCount: SizeUInt);
var
  tScalar, tSimd: Double;
  mbpsScalar, mbpsSimd, speedup: Double;
begin
  FillF32(aCount);
  g_BenchCount := aCount;

  tScalar := BenchArray(@BenchF32ScalarAdd);
  tSimd := BenchArray(@BenchF32SimdAdd);

  mbpsScalar := MBps(aCount, SizeOf(Single), tScalar);
  mbpsSimd := MBps(aCount, SizeOf(Single), tSimd);
  if tSimd > 0 then
    speedup := tScalar / tSimd
  else
    speedup := 0;

  WriteLn(Format('  %-10s  F32     %6d  %8.2f ns/el  %8.0f MB/s  |  %8.2f ns/el  %8.0f MB/s  |  %5.2fx',
    [aName, aCount, tScalar, mbpsScalar, tSimd, mbpsSimd, speedup]));
end;

procedure RunF64Bench(const aName: string; aCount: SizeUInt);
var
  tScalar, tSimd: Double;
  mbpsScalar, mbpsSimd, speedup: Double;
begin
  FillF64(aCount);
  g_BenchCount := aCount;

  tScalar := BenchArray(@BenchF64ScalarAdd);
  tSimd := BenchArray(@BenchF64SimdAdd);

  mbpsScalar := MBps(aCount, SizeOf(Double), tScalar);
  mbpsSimd := MBps(aCount, SizeOf(Double), tSimd);
  if tSimd > 0 then
    speedup := tScalar / tSimd
  else
    speedup := 0;

  WriteLn(Format('  %-10s  F64     %6d  %8.2f ns/el  %8.0f MB/s  |  %8.2f ns/el  %8.0f MB/s  |  %5.2fx',
    [aName, aCount, tScalar, mbpsScalar, tSimd, mbpsSimd, speedup]));
end;

procedure RunI32Bench(const aName: string; aCount: SizeUInt);
var
  tScalar, tSimd: Double;
  mbpsScalar, mbpsSimd, speedup: Double;
begin
  FillI32(aCount);
  g_BenchCount := aCount;

  tScalar := BenchArray(@BenchI32ScalarAdd);
  tSimd := BenchArray(@BenchI32SimdAdd);

  mbpsScalar := MBps(aCount, SizeOf(Int32), tScalar);
  mbpsSimd := MBps(aCount, SizeOf(Int32), tSimd);
  if tSimd > 0 then
    speedup := tScalar / tSimd
  else
    speedup := 0;

  WriteLn(Format('  %-10s  I32     %6d  %8.2f ns/el  %8.0f MB/s  |  %8.2f ns/el  %8.0f MB/s  |  %5.2fx',
    [aName, aCount, tScalar, mbpsScalar, tSimd, mbpsSimd, speedup]));
end;

var
  i: Integer;
  N: SizeUInt;
  BackendName: string;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);

  g_Dispatch := GetDispatchTable;
  if g_Dispatch = nil then
  begin
    WriteLn('ERROR: Dispatch table is nil');
    Halt(1);
  end;

  BackendName := GetBackendInfo(GetActiveBackend).Name;

  WriteLn('=== ArrayAdd Scaling Benchmark ===');
  WriteLn('  Backend: ', BackendName);
  WriteLn('  Warmup: ', WARMUP, '  Iters: ', ITERS);
  WriteLn('  MB/s = 3x streams (2 reads + 1 write)');
  WriteLn('');

  // Find max size
  g_MaxSize := g_ElementSizes[High(g_ElementSizes)];
  SetLength(F32A, g_MaxSize);
  SetLength(F32B, g_MaxSize);
  SetLength(F32Dst, g_MaxSize);
  SetLength(F64A, g_MaxSize);
  SetLength(F64B, g_MaxSize);
  SetLength(F64Dst, g_MaxSize);
  SetLength(I32A, g_MaxSize);
  SetLength(I32B, g_MaxSize);
  SetLength(I32Dst, g_MaxSize);

  // Header
  WriteLn(Format('  %-10s  %-6s  %6s  %18s  |  %18s  |  %6s',
    ['Test', 'Type', 'Size', 'Scalar', 'SIMD', 'Speedup']));
  WriteLn(Format('  %-10s  %-6s  %6s  %8s %8s  |  %8s %8s  |  %6s',
    ['', '', '', 'ns/elem', 'MB/s', 'ns/elem', 'MB/s', '']));
  WriteLn('  -----------------------------------------------------------------');

  for i := 0 to High(g_ElementSizes) do
  begin
    N := g_ElementSizes[i];
    RunF32Bench('ArrayAdd', N);
  end;

  WriteLn('');

  for i := 0 to High(g_ElementSizes) do
  begin
    N := g_ElementSizes[i];
    RunF64Bench('ArrayAdd', N);
  end;

  WriteLn('');

  for i := 0 to High(g_ElementSizes) do
  begin
    N := g_ElementSizes[i];
    RunI32Bench('ArrayAdd', N);
  end;

  WriteLn('');
  WriteLn('[DONE]');

  // Suppress unused warnings
  if g_ScalarF32Dummy <> 0.0 then;
  if g_ScalarF64Dummy <> 0.0 then;
  if g_ScalarI32Dummy <> 0 then;
end.
