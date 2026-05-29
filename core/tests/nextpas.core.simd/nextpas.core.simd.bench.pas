unit nextpas.core.simd.bench;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.memutils;

type
  TBenchResult = record
    Name: string;
    Size: SizeUInt;          // Data size in bytes (0 for vector ops)
    BaselineLabel: string;
    CandidateLabel: string;
    ScalarOpsPerSec: Double;
    ActiveOpsPerSec: Double;
    Speedup: Double;
  end;

  TBenchResults = array of TBenchResult;

// Try to activate a specific backend for benchmarking.
// Returns False with a human-readable skip reason when the backend is only
// CPU-supported but not actually dispatchable/active in this binary.
function TryActivateBenchmarkBackend(aBackend: TSimdBackend; out aSkipReason: string): Boolean;

// Run all benchmarks, returns results array
function RunAllBenchmarks: TBenchResults;

// Print benchmark results to console
procedure PrintBenchResults(const Results: TBenchResults);

// Individual benchmark categories
function BenchMemOps: TBenchResults;
function BenchArrayF32Ops: TBenchResults;
function BenchVectorOps: TBenchResults;

implementation

uses
  nextpas.core.time.stopwatch;

const
  // Benchmark parameters
  WARMUP_ITERATIONS = 100;
  MIN_ITERATIONS = 1000;
  TARGET_TIME_MS = 500;  // Target at least 500ms per benchmark
  TARGET_TIME_NS = TARGET_TIME_MS * 1000000;
  
  // Data sizes
  MEM_SIZE = 4096;  // 4KB for memory benchmarks
  ARRAY_F32_COUNT = 4096;
  ARRAY_F32_BYTES = ARRAY_F32_COUNT * SizeOf(Single);
  PUBLIC_ABI_HOT_SIZE = 32;  // Small hot-path payload to expose call overhead
  PUBLIC_ABI_HOT_INNER = 256;  // Amplify public-ABI hot-loop call-pattern signal
  NARROW_ANDNOT_INNER = 256;  // Amplify tiny vector-op differences
  WIDE_VECTOR_INNER = 256;    // Amplify wide-vector benchmark signal

type
  TBenchFunc = function: Int64;

function TryActivateBenchmarkBackend(aBackend: TSimdBackend; out aSkipReason: string): Boolean;
var
  LActiveBackend: TSimdBackend;
begin
  aSkipReason := '';

  if not IsBackendAvailableOnCPU(aBackend) then
  begin
    aSkipReason := GetBackendInfo(aBackend).Name + ' backend is not available on this CPU';
    Exit(False);
  end;

  if not IsBackendDispatchable(aBackend) then
  begin
    aSkipReason := GetBackendInfo(aBackend).Name +
      ' backend is CPU-supported but not dispatchable in this binary';
    Exit(False);
  end;

  if not TrySetActiveBackend(aBackend) then
  begin
    aSkipReason := GetBackendInfo(aBackend).Name + ' backend activation was rejected by dispatch';
    Exit(False);
  end;

  LActiveBackend := GetActiveBackend;
  if LActiveBackend <> aBackend then
  begin
    aSkipReason := GetBackendInfo(aBackend).Name + ' backend activation fell back to ' +
      GetBackendInfo(LActiveBackend).Name;
    Exit(False);
  end;

  Result := True;
end;

function MeasureOpsPerSec(Func: TBenchFunc; var TotalOps: Int64): Double;
var
  Iterations, i: Integer;
  ElapsedNs: Int64;
  LStopwatch: TStopwatch;
  LMeasuredOps: Int64;
begin
  // Warmup
  for i := 1 to WARMUP_ITERATIONS do
    Func();
  
  // Determine iteration count for target time
  Iterations := MIN_ITERATIONS;
  LStopwatch := TStopwatch.StartNew;
  for i := 1 to MIN_ITERATIONS do
    Func();
  LStopwatch.Stop;
  ElapsedNs := LStopwatch.Elapsed.AsNanoseconds;
  
  if ElapsedNs > 0 then
    Iterations := Trunc((Int64(MIN_ITERATIONS) * TARGET_TIME_NS) / ElapsedNs)
  else
    Iterations := MIN_ITERATIONS * 10;
  
  if Iterations < MIN_ITERATIONS then
    Iterations := MIN_ITERATIONS;
  
  // Actual measurement
  LStopwatch := TStopwatch.StartNew;
  LMeasuredOps := 0;
  for i := 1 to Iterations do
    Inc(LMeasuredOps, Func());
  LStopwatch.Stop;
  
  TotalOps := LMeasuredOps;
  ElapsedNs := LStopwatch.Elapsed.AsNanoseconds;
  if ElapsedNs = 0 then
    ElapsedNs := 1;
  Result := (LMeasuredOps * 1000000000.0) / ElapsedNs;
end;

procedure InitBenchResult(var aResult: TBenchResult; const aName: string; aSize: SizeUInt;
  const aBaselineLabel, aCandidateLabel: string; aBaselineOps, aCandidateOps: Double);
begin
  aResult.Name := aName;
  aResult.Size := aSize;
  aResult.BaselineLabel := aBaselineLabel;
  aResult.CandidateLabel := aCandidateLabel;
  aResult.ScalarOpsPerSec := aBaselineOps;
  aResult.ActiveOpsPerSec := aCandidateOps;
  if aBaselineOps > 0 then
    aResult.Speedup := aCandidateOps / aBaselineOps
  else
    aResult.Speedup := 0;
end;

procedure MeasureRotatedPublicAbiTriplet(aCacheFunc, aGetterFunc, aDispatchFunc: TBenchFunc;
  var aTotalOps: Int64; out aCacheOps, aGetterOps, aDispatchOps: Double);
begin
  aCacheOps := 0.0;
  aGetterOps := 0.0;
  aDispatchOps := 0.0;

  // Rotate measurement order so each call pattern sees early/mid/late positions once.
  aCacheOps := aCacheOps + MeasureOpsPerSec(aCacheFunc, aTotalOps);
  aGetterOps := aGetterOps + MeasureOpsPerSec(aGetterFunc, aTotalOps);
  aDispatchOps := aDispatchOps + MeasureOpsPerSec(aDispatchFunc, aTotalOps);

  aGetterOps := aGetterOps + MeasureOpsPerSec(aGetterFunc, aTotalOps);
  aDispatchOps := aDispatchOps + MeasureOpsPerSec(aDispatchFunc, aTotalOps);
  aCacheOps := aCacheOps + MeasureOpsPerSec(aCacheFunc, aTotalOps);

  aDispatchOps := aDispatchOps + MeasureOpsPerSec(aDispatchFunc, aTotalOps);
  aCacheOps := aCacheOps + MeasureOpsPerSec(aCacheFunc, aTotalOps);
  aGetterOps := aGetterOps + MeasureOpsPerSec(aGetterFunc, aTotalOps);

  aCacheOps := aCacheOps / 3.0;
  aGetterOps := aGetterOps / 3.0;
  aDispatchOps := aDispatchOps / 3.0;
end;

// === Memory Operation Benchmarks ===

var
  g_MemBuf1, g_MemBuf2: array[0..MEM_SIZE-1] of Byte;
  g_MemDummy: LongBool;
  g_MemDummyIdx: PtrInt;
  g_MemDummySum: UInt64;
  g_MemDummyCount: SizeUInt;

procedure InitMemBufs;
var i: Integer;
begin
  for i := 0 to MEM_SIZE - 1 do
  begin
    g_MemBuf1[i] := Byte(i mod 256);
    g_MemBuf2[i] := Byte(i mod 256);
  end;
end;

function BenchMemEqual_Scalar: Int64;
begin
  g_MemDummy := MemEqual_Scalar(@g_MemBuf1[0], @g_MemBuf2[0], MEM_SIZE);
  Result := 1;
end;

function BenchMemEqual_Active: Int64;
begin
  g_MemDummy := MemEqual(@g_MemBuf1[0], @g_MemBuf2[0], MEM_SIZE);
  Result := 1;
end;

function BenchMemFindByte_Scalar: Int64;
begin
  g_MemDummyIdx := MemFindByte_Scalar(@g_MemBuf1[0], MEM_SIZE, 255);
  Result := 1;
end;

function BenchMemFindByte_Active: Int64;
begin
  g_MemDummyIdx := MemFindByte(@g_MemBuf1[0], MEM_SIZE, 255);
  Result := 1;
end;

function BenchSumBytes_Scalar: Int64;
begin
  g_MemDummySum := SumBytes_Scalar(@g_MemBuf1[0], MEM_SIZE);
  Result := 1;
end;

function BenchSumBytes_Active: Int64;
begin
  g_MemDummySum := SumBytes(@g_MemBuf1[0], MEM_SIZE);
  Result := 1;
end;

function BenchCountByte_Scalar: Int64;
begin
  g_MemDummyCount := CountByte_Scalar(@g_MemBuf1[0], MEM_SIZE, $AA);
  Result := 1;
end;

function BenchCountByte_Active: Int64;
begin
  g_MemDummyCount := CountByte(@g_MemBuf1[0], MEM_SIZE, $AA);
  Result := 1;
end;

function BenchBitsetPopCount_Scalar: Int64;
begin
  g_MemDummyCount := BitsetPopCount_Scalar(@g_MemBuf1[0], MEM_SIZE);
  Result := 1;
end;

function BenchBitsetPopCount_Active: Int64;
begin
  g_MemDummyCount := BitsetPopCount(@g_MemBuf1[0], MEM_SIZE);
  Result := 1;
end;

function BenchMemOps: TBenchResults;
var
  OpsScalar, OpsActive: Double;
  TotalOps: Int64;
begin
  InitMemBufs;
  Result := nil;
  SetLength(Result, 5);
  TotalOps := 0;
  
  // MemEqual
  OpsScalar := MeasureOpsPerSec(@BenchMemEqual_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchMemEqual_Active, TotalOps);
  Result[0].Name := 'MemEqual';
  Result[0].Size := MEM_SIZE;
  Result[0].ScalarOpsPerSec := OpsScalar;
  Result[0].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[0].Speedup := OpsActive / OpsScalar else Result[0].Speedup := 0;
  
  // MemFindByte
  OpsScalar := MeasureOpsPerSec(@BenchMemFindByte_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchMemFindByte_Active, TotalOps);
  Result[1].Name := 'MemFindByte';
  Result[1].Size := MEM_SIZE;
  Result[1].ScalarOpsPerSec := OpsScalar;
  Result[1].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[1].Speedup := OpsActive / OpsScalar else Result[1].Speedup := 0;
  
  // SumBytes
  OpsScalar := MeasureOpsPerSec(@BenchSumBytes_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchSumBytes_Active, TotalOps);
  Result[2].Name := 'SumBytes';
  Result[2].Size := MEM_SIZE;
  Result[2].ScalarOpsPerSec := OpsScalar;
  Result[2].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[2].Speedup := OpsActive / OpsScalar else Result[2].Speedup := 0;
  
  // CountByte
  OpsScalar := MeasureOpsPerSec(@BenchCountByte_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchCountByte_Active, TotalOps);
  Result[3].Name := 'CountByte';
  Result[3].Size := MEM_SIZE;
  Result[3].ScalarOpsPerSec := OpsScalar;
  Result[3].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[3].Speedup := OpsActive / OpsScalar else Result[3].Speedup := 0;
  
  // BitsetPopCount
  OpsScalar := MeasureOpsPerSec(@BenchBitsetPopCount_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchBitsetPopCount_Active, TotalOps);
  Result[4].Name := 'BitsetPopCount';
  Result[4].Size := MEM_SIZE;
  Result[4].ScalarOpsPerSec := OpsScalar;
  Result[4].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[4].Speedup := OpsActive / OpsScalar else Result[4].Speedup := 0;
  
  // Suppress unused warnings
  if g_MemDummy then;
  if g_MemDummyIdx > 0 then;
  if g_MemDummySum > 0 then;
  if g_MemDummyCount > 0 then;
end;

// === ArrayF32 Batch Benchmarks ===

var
  g_ArrayF32A, g_ArrayF32B, g_ArrayF32Dst: array[0..ARRAY_F32_COUNT - 1] of Single;
  g_ArrayF32Dummy: Single;
  g_ArrayF32Dispatch: PSimdDispatchTable;

procedure InitArrayF32Bufs;
var
  LIndex: Integer;
begin
  g_ArrayF32Dispatch := GetDispatchTable;
  for LIndex := 0 to ARRAY_F32_COUNT - 1 do
  begin
    g_ArrayF32A[LIndex] := (LIndex mod 257) * 0.25 + 1.0;
    g_ArrayF32B[LIndex] := (LIndex mod 131) * 0.5 - 3.0;
    g_ArrayF32Dst[LIndex] := 0.0;
  end;
end;

function BenchArrayAddF32_Scalar: Int64;
begin
  ScalarArrayAddF32(@g_ArrayF32A[0], @g_ArrayF32B[0], @g_ArrayF32Dst[0], ARRAY_F32_COUNT);
  g_ArrayF32Dummy := g_ArrayF32Dst[ARRAY_F32_COUNT - 1];
  Result := ARRAY_F32_COUNT;
end;

function BenchArrayAddF32_Active: Int64;
begin
  g_ArrayF32Dispatch^.ArrayAddF32(@g_ArrayF32A[0], @g_ArrayF32B[0], @g_ArrayF32Dst[0], ARRAY_F32_COUNT);
  g_ArrayF32Dummy := g_ArrayF32Dst[ARRAY_F32_COUNT - 1];
  Result := ARRAY_F32_COUNT;
end;

function BenchArrayMulF32_Scalar: Int64;
begin
  ScalarArrayMulF32(@g_ArrayF32A[0], @g_ArrayF32B[0], @g_ArrayF32Dst[0], ARRAY_F32_COUNT);
  g_ArrayF32Dummy := g_ArrayF32Dst[ARRAY_F32_COUNT - 1];
  Result := ARRAY_F32_COUNT;
end;

function BenchArrayMulF32_Active: Int64;
begin
  g_ArrayF32Dispatch^.ArrayMulF32(@g_ArrayF32A[0], @g_ArrayF32B[0], @g_ArrayF32Dst[0], ARRAY_F32_COUNT);
  g_ArrayF32Dummy := g_ArrayF32Dst[ARRAY_F32_COUNT - 1];
  Result := ARRAY_F32_COUNT;
end;

function BenchArrayMulScalarF32_Scalar: Int64;
begin
  ScalarArrayMulScalarF32(@g_ArrayF32A[0], @g_ArrayF32Dst[0], ARRAY_F32_COUNT, -1.25);
  g_ArrayF32Dummy := g_ArrayF32Dst[ARRAY_F32_COUNT - 1];
  Result := ARRAY_F32_COUNT;
end;

function BenchArrayMulScalarF32_Active: Int64;
begin
  g_ArrayF32Dispatch^.ArrayMulScalarF32(@g_ArrayF32A[0], @g_ArrayF32Dst[0], ARRAY_F32_COUNT, -1.25);
  g_ArrayF32Dummy := g_ArrayF32Dst[ARRAY_F32_COUNT - 1];
  Result := ARRAY_F32_COUNT;
end;

function BenchArrayAxpyF32_Scalar: Int64;
begin
  ScalarArrayAxpyF32(1.75, @g_ArrayF32A[0], @g_ArrayF32B[0], @g_ArrayF32Dst[0], ARRAY_F32_COUNT);
  g_ArrayF32Dummy := g_ArrayF32Dst[ARRAY_F32_COUNT - 1];
  Result := ARRAY_F32_COUNT;
end;

function BenchArrayAxpyF32_Active: Int64;
begin
  g_ArrayF32Dispatch^.ArrayAxpyF32(1.75, @g_ArrayF32A[0], @g_ArrayF32B[0], @g_ArrayF32Dst[0], ARRAY_F32_COUNT);
  g_ArrayF32Dummy := g_ArrayF32Dst[ARRAY_F32_COUNT - 1];
  Result := ARRAY_F32_COUNT;
end;

function BenchArrayF32Ops: TBenchResults;
var
  OpsScalar, OpsActive: Double;
  TotalOps: Int64;
begin
  InitArrayF32Bufs;
  Result := nil;
  SetLength(Result, 4);
  TotalOps := 0;

  OpsScalar := MeasureOpsPerSec(@BenchArrayAddF32_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchArrayAddF32_Active, TotalOps);
  InitBenchResult(Result[0], 'ArrayAddF32', ARRAY_F32_BYTES, 'Scalar', 'Dispatch', OpsScalar, OpsActive);

  OpsScalar := MeasureOpsPerSec(@BenchArrayMulF32_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchArrayMulF32_Active, TotalOps);
  InitBenchResult(Result[1], 'ArrayMulF32', ARRAY_F32_BYTES, 'Scalar', 'Dispatch', OpsScalar, OpsActive);

  OpsScalar := MeasureOpsPerSec(@BenchArrayMulScalarF32_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchArrayMulScalarF32_Active, TotalOps);
  InitBenchResult(Result[2], 'ArrayMulScalarF32', ARRAY_F32_BYTES, 'Scalar', 'Dispatch', OpsScalar, OpsActive);

  OpsScalar := MeasureOpsPerSec(@BenchArrayAxpyF32_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchArrayAxpyF32_Active, TotalOps);
  InitBenchResult(Result[3], 'ArrayAxpyF32', ARRAY_F32_BYTES, 'Scalar', 'Dispatch', OpsScalar, OpsActive);

  if g_ArrayF32Dummy <> 0.0 then;
end;

// === Vector Operation Benchmarks ===

var
  g_VecA, g_VecB, g_VecR: TVecF32x4;
  g_VecIA, g_VecIB, g_VecIR: TVecI32x4;
  g_VecI16x32A, g_VecI16x32B, g_VecI16x32R: TVecI16x32;
  g_VecI8A, g_VecI8B, g_VecI8R: TVecI8x16;
  g_VecU32x16A, g_VecU32x16B, g_VecU32x16R: TVecU32x16;
  g_VecU64x8A, g_VecU64x8B, g_VecU64x8R: TVecU64x8;
  g_VecU16A, g_VecU16B, g_VecU16R: TVecU16x8;
  g_VecU8x64A, g_VecU8x64B, g_VecU8x64R: TVecU8x64;
  g_VecU8A, g_VecU8B, g_VecU8R: TVecU8x16;
  g_ScalarR: Single;
  g_VecDispatch: PSimdDispatchTable;

procedure InitVecData;
var
  LIndex: Integer;
begin
  g_VecA := VecF32x4Splat(1.5);
  g_VecB := VecF32x4Splat(2.5);

  // No VecI32x4Splat available, initialize manually
  for LIndex := 0 to 3 do
  begin
    g_VecIA.i[LIndex] := 100;
    g_VecIB.i[LIndex] := 200;
  end;

  for LIndex := 0 to 15 do
  begin
    g_VecI8A.i[LIndex] := ShortInt((LIndex * 7) - 64);
    g_VecI8B.i[LIndex] := ShortInt($5A xor LIndex);
    g_VecU32x16A.u[LIndex] := DWord((LIndex + 1) * 1234567);
    g_VecU32x16B.u[LIndex] := DWord((17 - LIndex) * 76543);
    g_VecU8A.u[LIndex] := Byte((LIndex * 13) and $FF);
    g_VecU8B.u[LIndex] := Byte($F0 xor (LIndex * 3));
  end;

  for LIndex := 0 to 7 do
  begin
    g_VecI16x32A.i[LIndex] := SmallInt((LIndex * 37) - 400);
    g_VecI16x32B.i[LIndex] := SmallInt(450 - (LIndex * 29));
    g_VecI16x32A.i[LIndex + 8] := SmallInt(((LIndex + 8) * 37) - 400);
    g_VecI16x32B.i[LIndex + 8] := SmallInt(450 - ((LIndex + 8) * 29));
    g_VecI16x32A.i[LIndex + 16] := SmallInt(((LIndex + 16) * 37) - 400);
    g_VecI16x32B.i[LIndex + 16] := SmallInt(450 - ((LIndex + 16) * 29));
    g_VecI16x32A.i[LIndex + 24] := SmallInt(((LIndex + 24) * 37) - 400);
    g_VecI16x32B.i[LIndex + 24] := SmallInt(450 - ((LIndex + 24) * 29));

    g_VecU64x8A.u[LIndex] := QWord((LIndex + 1) * 1000003) shl (LIndex mod 13);
    g_VecU64x8B.u[LIndex] := QWord((9 - LIndex) * 700001) shl ((LIndex + 3) mod 11);
    g_VecU16A.u[LIndex] := Word((LIndex * 257) and $FFFF);
    g_VecU16B.u[LIndex] := Word($FF00 xor (LIndex * 73));
  end;

  for LIndex := 0 to 63 do
  begin
    g_VecU8x64A.u[LIndex] := Byte((LIndex * 19) and $FF);
    g_VecU8x64B.u[LIndex] := Byte((255 - (LIndex * 7)) and $FF);
  end;
end;

// === Public ABI Call Pattern Benchmarks ===

var
  g_PublicAbiBuf1, g_PublicAbiBuf2: array[0..PUBLIC_ABI_HOT_SIZE - 1] of Byte;
  g_PublicAbiDummyEq: LongBool;
  g_PublicAbiDummySum: UInt64;

procedure InitPublicAbiBufs;
var
  LIndex: Integer;
begin
  for LIndex := 0 to PUBLIC_ABI_HOT_SIZE - 1 do
  begin
    g_PublicAbiBuf1[LIndex] := Byte((LIndex * 13) and $FF);
    g_PublicAbiBuf2[LIndex] := g_PublicAbiBuf1[LIndex];
  end;
end;

function BenchHotMemEqual_Facade: Int64;
var
  LIndex: Integer;
begin
  for LIndex := 1 to PUBLIC_ABI_HOT_INNER do
    g_PublicAbiDummyEq := MemEqual(@g_PublicAbiBuf1[0], @g_PublicAbiBuf2[0], PUBLIC_ABI_HOT_SIZE);
  Result := PUBLIC_ABI_HOT_INNER;
end;

function BenchHotMemEqual_PublicCached: Int64;
var
  LApi: PNextPasSimdPublicApi;
  LIndex: Integer;
begin
  LApi := GetSimdPublicApi;
  for LIndex := 1 to PUBLIC_ABI_HOT_INNER do
    g_PublicAbiDummyEq := LApi^.MemEqual(@g_PublicAbiBuf1[0], @g_PublicAbiBuf2[0], PUBLIC_ABI_HOT_SIZE);
  Result := PUBLIC_ABI_HOT_INNER;
end;

function BenchHotMemEqual_PublicGetter: Int64;
var
  LIndex: Integer;
begin
  for LIndex := 1 to PUBLIC_ABI_HOT_INNER do
    g_PublicAbiDummyEq := GetSimdPublicApi^.MemEqual(@g_PublicAbiBuf1[0], @g_PublicAbiBuf2[0], PUBLIC_ABI_HOT_SIZE);
  Result := PUBLIC_ABI_HOT_INNER;
end;

function BenchHotMemEqual_DispatchGetter: Int64;
var
  LIndex: Integer;
begin
  for LIndex := 1 to PUBLIC_ABI_HOT_INNER do
    g_PublicAbiDummyEq := GetDispatchTable^.MemEqual(@g_PublicAbiBuf1[0], @g_PublicAbiBuf2[0], PUBLIC_ABI_HOT_SIZE);
  Result := PUBLIC_ABI_HOT_INNER;
end;

function BenchHotSumBytes_Facade: Int64;
var
  LIndex: Integer;
begin
  for LIndex := 1 to PUBLIC_ABI_HOT_INNER do
    g_PublicAbiDummySum := SumBytes(@g_PublicAbiBuf1[0], PUBLIC_ABI_HOT_SIZE);
  Result := PUBLIC_ABI_HOT_INNER;
end;

function BenchHotSumBytes_PublicCached: Int64;
var
  LApi: PNextPasSimdPublicApi;
  LIndex: Integer;
begin
  LApi := GetSimdPublicApi;
  for LIndex := 1 to PUBLIC_ABI_HOT_INNER do
    g_PublicAbiDummySum := LApi^.SumBytes(@g_PublicAbiBuf1[0], PUBLIC_ABI_HOT_SIZE);
  Result := PUBLIC_ABI_HOT_INNER;
end;

function BenchHotSumBytes_PublicGetter: Int64;
var
  LIndex: Integer;
begin
  for LIndex := 1 to PUBLIC_ABI_HOT_INNER do
    g_PublicAbiDummySum := GetSimdPublicApi^.SumBytes(@g_PublicAbiBuf1[0], PUBLIC_ABI_HOT_SIZE);
  Result := PUBLIC_ABI_HOT_INNER;
end;

function BenchHotSumBytes_DispatchGetter: Int64;
var
  LIndex: Integer;
begin
  for LIndex := 1 to PUBLIC_ABI_HOT_INNER do
    g_PublicAbiDummySum := GetDispatchTable^.SumBytes(@g_PublicAbiBuf1[0], PUBLIC_ABI_HOT_SIZE);
  Result := PUBLIC_ABI_HOT_INNER;
end;

function BenchPublicAbiCallPatterns: TBenchResults;
var
  LMemFacadeOps: Double;
  LMemCacheOps: Double;
  LMemGetterOps: Double;
  LMemDispatchOps: Double;
  LSumFacadeOps: Double;
  LSumCacheOps: Double;
  LSumGetterOps: Double;
  LSumDispatchOps: Double;
  LTotalOps: Int64;
begin
  InitPublicAbiBufs;
  Result := nil;
  SetLength(Result, 6);
  LTotalOps := 0;

  LMemFacadeOps := MeasureOpsPerSec(@BenchHotMemEqual_Facade, LTotalOps);
  MeasureRotatedPublicAbiTriplet(@BenchHotMemEqual_PublicCached, @BenchHotMemEqual_PublicGetter,
    @BenchHotMemEqual_DispatchGetter, LTotalOps, LMemCacheOps, LMemGetterOps, LMemDispatchOps);
  InitBenchResult(Result[0], 'HotMemEqPubCache', PUBLIC_ABI_HOT_SIZE,
    'Facade', 'PubCache', LMemFacadeOps, LMemCacheOps);
  InitBenchResult(Result[1], 'HotMemEqPubGet', PUBLIC_ABI_HOT_SIZE,
    'Facade', 'PubGet', LMemFacadeOps, LMemGetterOps);
  InitBenchResult(Result[2], 'HotMemEqDispGet', PUBLIC_ABI_HOT_SIZE,
    'Facade', 'DispGet', LMemFacadeOps, LMemDispatchOps);

  LSumFacadeOps := MeasureOpsPerSec(@BenchHotSumBytes_Facade, LTotalOps);
  MeasureRotatedPublicAbiTriplet(@BenchHotSumBytes_PublicCached, @BenchHotSumBytes_PublicGetter,
    @BenchHotSumBytes_DispatchGetter, LTotalOps, LSumCacheOps, LSumGetterOps, LSumDispatchOps);
  InitBenchResult(Result[3], 'HotSumPubCache', PUBLIC_ABI_HOT_SIZE,
    'Facade', 'PubCache', LSumFacadeOps, LSumCacheOps);
  InitBenchResult(Result[4], 'HotSumPubGet', PUBLIC_ABI_HOT_SIZE,
    'Facade', 'PubGet', LSumFacadeOps, LSumGetterOps);
  InitBenchResult(Result[5], 'HotSumDispGet', PUBLIC_ABI_HOT_SIZE,
    'Facade', 'DispGet', LSumFacadeOps, LSumDispatchOps);

  if g_PublicAbiDummyEq then;
  if g_PublicAbiDummySum > 0 then;
end;

function BenchVecF32x4Add_Scalar: Int64;
begin
  g_VecR := ScalarAddF32x4(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecF32x4Add_Active: Int64;
begin
  g_VecR := VecF32x4Add(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecF32x4Add_RawActive: Int64;
begin
  g_VecR := g_VecDispatch^.AddF32x4(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecF32x4Mul_Scalar: Int64;
begin
  g_VecR := ScalarMulF32x4(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecF32x4Mul_Active: Int64;
begin
  g_VecR := VecF32x4Mul(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecF32x4Div_Scalar: Int64;
begin
  g_VecR := ScalarDivF32x4(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecF32x4Div_Active: Int64;
begin
  g_VecR := VecF32x4Div(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecI32x4Add_Scalar: Int64;
begin
  g_VecIR := ScalarAddI32x4(g_VecIA, g_VecIB);
  Result := 1;
end;

function BenchVecI32x4Add_Active: Int64;
begin
  g_VecIR := VecI32x4Add(g_VecIA, g_VecIB);
  Result := 1;
end;

function BenchVecI16x32Add_Scalar: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecI16x32R := ScalarAddI16x32(g_VecI16x32A, g_VecI16x32B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecI16x32Add_Active: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecI16x32R := VecI16x32Add(g_VecI16x32A, g_VecI16x32B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecI16x32Add_RawActive: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecI16x32R := g_VecDispatch^.AddI16x32(g_VecI16x32A, g_VecI16x32B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecF32x4Dot_Scalar: Int64;
begin
  g_ScalarR := ScalarDotF32x4(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecF32x4Dot_Active: Int64;
begin
  g_ScalarR := VecF32x4Dot(g_VecA, g_VecB);
  Result := 1;
end;

function BenchVecI8x16AndNot_Scalar: Int64;
var
  LNotA: TVecI8x16;
  LRepeat: Integer;
begin
  for LRepeat := 1 to NARROW_ANDNOT_INNER do
  begin
    LNotA := VecI8x16Not(g_VecI8A);
    g_VecI8R := VecI8x16And(LNotA, g_VecI8B);
  end;
  Result := 1;
end;

function BenchVecI8x16AndNot_Active: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to NARROW_ANDNOT_INNER do
    g_VecI8R := VecI8x16AndNot(g_VecI8A, g_VecI8B);
  Result := 1;
end;

function BenchVecU16x8AndNot_Scalar: Int64;
var
  LNotA: TVecU16x8;
  LRepeat: Integer;
begin
  for LRepeat := 1 to NARROW_ANDNOT_INNER do
  begin
    LNotA := VecU16x8Not(g_VecU16A);
    g_VecU16R := VecU16x8And(LNotA, g_VecU16B);
  end;
  Result := 1;
end;

function BenchVecU16x8AndNot_Active: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to NARROW_ANDNOT_INNER do
    g_VecU16R := VecU16x8AndNot(g_VecU16A, g_VecU16B);
  Result := 1;
end;

function BenchVecU8x16AndNot_Scalar: Int64;
var
  LNotA: TVecU8x16;
  LRepeat: Integer;
begin
  for LRepeat := 1 to NARROW_ANDNOT_INNER do
  begin
    LNotA := VecU8x16Not(g_VecU8A);
    g_VecU8R := VecU8x16And(LNotA, g_VecU8B);
  end;
  Result := 1;
end;

function BenchVecU8x16AndNot_Active: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to NARROW_ANDNOT_INNER do
    g_VecU8R := VecU8x16AndNot(g_VecU8A, g_VecU8B);
  Result := 1;
end;

function BenchVecU32x16Mul_Scalar: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU32x16R := ScalarMulU32x16(g_VecU32x16A, g_VecU32x16B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecU32x16Mul_Active: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU32x16R := VecU32x16Mul(g_VecU32x16A, g_VecU32x16B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecU32x16Mul_RawActive: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU32x16R := g_VecDispatch^.MulU32x16(g_VecU32x16A, g_VecU32x16B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecU64x8Add_Scalar: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU64x8R := ScalarAddU64x8(g_VecU64x8A, g_VecU64x8B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecU64x8Add_Active: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU64x8R := VecU64x8Add(g_VecU64x8A, g_VecU64x8B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecU64x8Add_RawActive: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU64x8R := g_VecDispatch^.AddU64x8(g_VecU64x8A, g_VecU64x8B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecU8x64Max_Scalar: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU8x64R := ScalarMaxU8x64(g_VecU8x64A, g_VecU8x64B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecU8x64Max_Active: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU8x64R := VecU8x64Max(g_VecU8x64A, g_VecU8x64B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVecU8x64Max_RawActive: Int64;
var
  LRepeat: Integer;
begin
  for LRepeat := 1 to WIDE_VECTOR_INNER do
    g_VecU8x64R := g_VecDispatch^.MaxU8x64(g_VecU8x64A, g_VecU8x64B);
  Result := WIDE_VECTOR_INNER;
end;

function BenchVectorOps: TBenchResults;
var
  OpsScalar, OpsActive: Double;
  TotalOps: Int64;
begin
  InitVecData;
  g_VecDispatch := GetDispatchTable;
  Result := nil;
  SetLength(Result, 17);
  TotalOps := 0;

  // VecF32x4Add
  OpsScalar := MeasureOpsPerSec(@BenchVecF32x4Add_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecF32x4Add_Active, TotalOps);
  Result[0].Name := 'VecF32x4Add';
  Result[0].Size := 0;
  Result[0].ScalarOpsPerSec := OpsScalar;
  Result[0].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[0].Speedup := OpsActive / OpsScalar else Result[0].Speedup := 0;

  // VecF32x4AddRaw
  OpsScalar := MeasureOpsPerSec(@BenchVecF32x4Add_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecF32x4Add_RawActive, TotalOps);
  Result[1].Name := 'VecF32x4AddRaw';
  Result[1].Size := 0;
  Result[1].ScalarOpsPerSec := OpsScalar;
  Result[1].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[1].Speedup := OpsActive / OpsScalar else Result[1].Speedup := 0;

  // VecF32x4Mul
  OpsScalar := MeasureOpsPerSec(@BenchVecF32x4Mul_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecF32x4Mul_Active, TotalOps);
  Result[2].Name := 'VecF32x4Mul';
  Result[2].Size := 0;
  Result[2].ScalarOpsPerSec := OpsScalar;
  Result[2].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[2].Speedup := OpsActive / OpsScalar else Result[2].Speedup := 0;

  // VecF32x4Div
  OpsScalar := MeasureOpsPerSec(@BenchVecF32x4Div_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecF32x4Div_Active, TotalOps);
  Result[3].Name := 'VecF32x4Div';
  Result[3].Size := 0;
  Result[3].ScalarOpsPerSec := OpsScalar;
  Result[3].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[3].Speedup := OpsActive / OpsScalar else Result[3].Speedup := 0;

  // VecI32x4Add
  OpsScalar := MeasureOpsPerSec(@BenchVecI32x4Add_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecI32x4Add_Active, TotalOps);
  Result[4].Name := 'VecI32x4Add';
  Result[4].Size := 0;
  Result[4].ScalarOpsPerSec := OpsScalar;
  Result[4].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[4].Speedup := OpsActive / OpsScalar else Result[4].Speedup := 0;

  // VecI16x32Add
  OpsScalar := MeasureOpsPerSec(@BenchVecI16x32Add_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecI16x32Add_Active, TotalOps);
  Result[5].Name := 'VecI16x32Add';
  Result[5].Size := 0;
  Result[5].ScalarOpsPerSec := OpsScalar;
  Result[5].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[5].Speedup := OpsActive / OpsScalar else Result[5].Speedup := 0;

  // VecI16x32AddRaw
  OpsScalar := MeasureOpsPerSec(@BenchVecI16x32Add_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecI16x32Add_RawActive, TotalOps);
  Result[6].Name := 'VecI16x32AddRaw';
  Result[6].Size := 0;
  Result[6].ScalarOpsPerSec := OpsScalar;
  Result[6].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[6].Speedup := OpsActive / OpsScalar else Result[6].Speedup := 0;

  // VecF32x4Dot
  OpsScalar := MeasureOpsPerSec(@BenchVecF32x4Dot_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecF32x4Dot_Active, TotalOps);
  Result[7].Name := 'VecF32x4Dot';
  Result[7].Size := 0;
  Result[7].ScalarOpsPerSec := OpsScalar;
  Result[7].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[7].Speedup := OpsActive / OpsScalar else Result[7].Speedup := 0;

  // VecI8x16AndNot
  OpsScalar := MeasureOpsPerSec(@BenchVecI8x16AndNot_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecI8x16AndNot_Active, TotalOps);
  Result[8].Name := 'VecI8x16AndNot';
  Result[8].Size := 0;
  Result[8].ScalarOpsPerSec := OpsScalar;
  Result[8].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[8].Speedup := OpsActive / OpsScalar else Result[8].Speedup := 0;

  // VecU16x8AndNot
  OpsScalar := MeasureOpsPerSec(@BenchVecU16x8AndNot_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecU16x8AndNot_Active, TotalOps);
  Result[9].Name := 'VecU16x8AndNot';
  Result[9].Size := 0;
  Result[9].ScalarOpsPerSec := OpsScalar;
  Result[9].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[9].Speedup := OpsActive / OpsScalar else Result[9].Speedup := 0;

  // VecU8x16AndNot
  OpsScalar := MeasureOpsPerSec(@BenchVecU8x16AndNot_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecU8x16AndNot_Active, TotalOps);
  Result[10].Name := 'VecU8x16AndNot';
  Result[10].Size := 0;
  Result[10].ScalarOpsPerSec := OpsScalar;
  Result[10].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[10].Speedup := OpsActive / OpsScalar else Result[10].Speedup := 0;

  // VecU32x16Mul
  OpsScalar := MeasureOpsPerSec(@BenchVecU32x16Mul_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecU32x16Mul_Active, TotalOps);
  Result[11].Name := 'VecU32x16Mul';
  Result[11].Size := 0;
  Result[11].ScalarOpsPerSec := OpsScalar;
  Result[11].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[11].Speedup := OpsActive / OpsScalar else Result[11].Speedup := 0;

  // VecU32x16MulRaw
  OpsScalar := MeasureOpsPerSec(@BenchVecU32x16Mul_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecU32x16Mul_RawActive, TotalOps);
  Result[12].Name := 'VecU32x16MulRaw';
  Result[12].Size := 0;
  Result[12].ScalarOpsPerSec := OpsScalar;
  Result[12].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[12].Speedup := OpsActive / OpsScalar else Result[12].Speedup := 0;

  // VecU64x8Add
  OpsScalar := MeasureOpsPerSec(@BenchVecU64x8Add_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecU64x8Add_Active, TotalOps);
  Result[13].Name := 'VecU64x8Add';
  Result[13].Size := 0;
  Result[13].ScalarOpsPerSec := OpsScalar;
  Result[13].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[13].Speedup := OpsActive / OpsScalar else Result[13].Speedup := 0;

  // VecU64x8AddRaw
  OpsScalar := MeasureOpsPerSec(@BenchVecU64x8Add_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecU64x8Add_RawActive, TotalOps);
  Result[14].Name := 'VecU64x8AddRaw';
  Result[14].Size := 0;
  Result[14].ScalarOpsPerSec := OpsScalar;
  Result[14].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[14].Speedup := OpsActive / OpsScalar else Result[14].Speedup := 0;

  // VecU8x64Max
  OpsScalar := MeasureOpsPerSec(@BenchVecU8x64Max_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecU8x64Max_Active, TotalOps);
  Result[15].Name := 'VecU8x64Max';
  Result[15].Size := 0;
  Result[15].ScalarOpsPerSec := OpsScalar;
  Result[15].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[15].Speedup := OpsActive / OpsScalar else Result[15].Speedup := 0;

  // VecU8x64MaxRaw
  OpsScalar := MeasureOpsPerSec(@BenchVecU8x64Max_Scalar, TotalOps);
  OpsActive := MeasureOpsPerSec(@BenchVecU8x64Max_RawActive, TotalOps);
  Result[16].Name := 'VecU8x64MaxRaw';
  Result[16].Size := 0;
  Result[16].ScalarOpsPerSec := OpsScalar;
  Result[16].ActiveOpsPerSec := OpsActive;
  if OpsScalar > 0 then Result[16].Speedup := OpsActive / OpsScalar else Result[16].Speedup := 0;

  // Suppress unused warnings
  if g_VecR.f[0] > 0 then;
  if g_VecIR.i[0] > 0 then;
  if g_VecI16x32R.i[0] > 0 then;
  if g_VecI8R.i[0] > 0 then;
  if g_VecU32x16R.u[0] > 0 then;
  if g_VecU64x8R.u[0] > 0 then;
  if g_VecU16R.u[0] > 0 then;
  if g_VecU8x64R.u[0] > 0 then;
  if g_VecU8R.u[0] > 0 then;
  if g_ScalarR > 0 then;
end;
// === Public API ===

function RunAllBenchmarks: TBenchResults;
var
  LMemResults: TBenchResults;
  LArrayF32Results: TBenchResults;
  LVecResults: TBenchResults;
  LPublicAbiResults: TBenchResults;
  LIndex: Integer;
  LOffset: Integer;
begin
  Result := nil;
  LMemResults := BenchMemOps;
  LArrayF32Results := BenchArrayF32Ops;
  LVecResults := BenchVectorOps;
  LPublicAbiResults := BenchPublicAbiCallPatterns;
  
  SetLength(Result, Length(LMemResults) + Length(LArrayF32Results) +
    Length(LVecResults) + Length(LPublicAbiResults));
  
  for LIndex := 0 to High(LMemResults) do
    Result[LIndex] := LMemResults[LIndex];
  
  LOffset := Length(LMemResults);
  for LIndex := 0 to High(LArrayF32Results) do
    Result[LOffset + LIndex] := LArrayF32Results[LIndex];

  Inc(LOffset, Length(LArrayF32Results));
  for LIndex := 0 to High(LVecResults) do
    Result[LOffset + LIndex] := LVecResults[LIndex];

  Inc(LOffset, Length(LVecResults));
  for LIndex := 0 to High(LPublicAbiResults) do
    Result[LOffset + LIndex] := LPublicAbiResults[LIndex];
end;

function FormatOps(Ops: Double): string;
begin
  if Ops >= 1e9 then
    Result := Format('%.2f G', [Ops / 1e9])
  else if Ops >= 1e6 then
    Result := Format('%.2f M', [Ops / 1e6])
  else if Ops >= 1e3 then
    Result := Format('%.2f K', [Ops / 1e3])
  else
    Result := Format('%.0f  ', [Ops]);
end;

function GetArchName: string;
begin
  {$IF defined(CPUX86_64)}
  Result := 'x86_64';
  {$ELSEIF defined(CPUI386)}
  Result := 'i386';
  {$ELSEIF defined(CPUAARCH64)}
  Result := 'arm64';
  {$ELSEIF defined(CPURISCV64)}
  Result := 'riscv64';
  {$ELSEIF defined(CPURISCV32)}
  Result := 'riscv32';
  {$ELSE}
  Result := 'unknown';
  {$ENDIF}
end;

procedure PrintBenchResults(const Results: TBenchResults);
var
  LIndex: Integer;
  LSizeStr: string;
  LBaselineLabel: string;
  LCandidateLabel: string;
  LCompareStr: string;
begin
  WriteLn;
  WriteLn('=== SIMD Benchmark (', GetArchName, '/', GetBackendInfo(GetActiveBackend).Name, ') ===');
  WriteLn;
  WriteLn('Operation              Size     Compare            Base ops/s   Candidate ops/s   Speedup');
  WriteLn('--------------------------------------------------------------------------------------------');
  
  for LIndex := 0 to High(Results) do
  begin
    if Results[LIndex].Size > 0 then
      LSizeStr := Format('%4d B', [Results[LIndex].Size])
    else
      LSizeStr := '     -';

    LBaselineLabel := Results[LIndex].BaselineLabel;
    if LBaselineLabel = '' then
      LBaselineLabel := 'Scalar';
    LCandidateLabel := Results[LIndex].CandidateLabel;
    if LCandidateLabel = '' then
      LCandidateLabel := 'Active';
    LCompareStr := LBaselineLabel + '->' + LCandidateLabel;
    
    WriteLn(Format('%-21s  %s  %-16s  %12s  %15s  %6.2fx', [
      Results[LIndex].Name,
      LSizeStr,
      LCompareStr,
      FormatOps(Results[LIndex].ScalarOpsPerSec),
      FormatOps(Results[LIndex].ActiveOpsPerSec),
      Results[LIndex].Speedup
    ]));
  end;
  
  WriteLn;
end;

end.
