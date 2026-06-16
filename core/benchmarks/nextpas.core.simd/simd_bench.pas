program simd_bench;

{$mode objfpc}{$H+}
{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.time.cpu,
  nextpas.core.simd,
  nextpas.core.simd.alloc;

const
  ARRAY_SIZE = 1024 * 1024;  // 1M elements
  WARMUP_ITERS = 3;
  BENCH_ITERS = 10;
  INNER_REPS = 20;  // repeat within each timing window

var
  GA, GB, GC: PSingle;
  GDA, GDB: PDouble;

function GetTimeMs: Int64;
begin
  Result := GetTickCount64;
end;

type
  TBenchResult = record
    Name: string;
    OpsPerSec: Double;
    BytesPerSec: Double;
    MedianMs: Double;
  end;

var
  GResults: array[0..31] of TBenchResult;
  GResultCount: Integer = 0;

procedure RecordResult(const aName: string; aMedianMs: Double; aElementCount: SizeUInt; aBytesPerElement: Integer);
begin
  if GResultCount > High(GResults) then Exit;
  GResults[GResultCount].Name := aName;
  GResults[GResultCount].MedianMs := aMedianMs;
  if aMedianMs > 0 then
  begin
    GResults[GResultCount].OpsPerSec := (aElementCount / aMedianMs) * 1000.0;
    GResults[GResultCount].BytesPerSec := (aElementCount * aBytesPerElement / aMedianMs) * 1000.0;
  end;
  Inc(GResultCount);
end;

function MedianOf(const aTimes: array of Int64; aCount: Integer): Double;
var
  i, j: Integer;
  LTmp: Int64;
  LSorted: array[0..31] of Int64;
begin
  for i := 0 to aCount - 1 do LSorted[i] := aTimes[i];
  for i := 0 to aCount - 2 do
    for j := i + 1 to aCount - 1 do
      if LSorted[j] < LSorted[i] then
      begin LTmp := LSorted[i]; LSorted[i] := LSorted[j]; LSorted[j] := LTmp; end;
  Result := LSorted[aCount div 2];
end;

procedure BenchArrayAddF32;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
begin
  for i := 0 to WARMUP_ITERS - 1 do ArrayAddF32(GA, GB, GC, ARRAY_SIZE);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      ArrayAddF32(GA, GB, GC, ARRAY_SIZE);
    LTimes[i] := GetTimeMs - t0;
  end;
  RecordResult('ArrayAddF32', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 4);
end;

procedure BenchArrayMulF32;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
begin
  for i := 0 to WARMUP_ITERS - 1 do ArrayMulF32(GA, GB, GC, ARRAY_SIZE);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      ArrayMulF32(GA, GB, GC, ARRAY_SIZE);
    LTimes[i] := GetTimeMs - t0;
  end;
  RecordResult('ArrayMulF32', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 4);
end;

procedure BenchArrayMulScalarF32;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
begin
  for i := 0 to WARMUP_ITERS - 1 do ArrayMulScalarF32(GA, GC, ARRAY_SIZE, 2.5);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      ArrayMulScalarF32(GA, GC, ARRAY_SIZE, 2.5);
    LTimes[i] := GetTimeMs - t0;
  end;
  RecordResult('ArrayMulScalarF32', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 4);
end;

procedure BenchReduceSumF32;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64; LDummy: Single;
begin
  for i := 0 to WARMUP_ITERS - 1 do LDummy := ReduceSumF32(GA, ARRAY_SIZE);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      LDummy := ReduceSumF32(GA, ARRAY_SIZE);
    LTimes[i] := GetTimeMs - t0;
  end;
  if LDummy = -999999 then ;
  RecordResult('ReduceSumF32', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 4);
end;

procedure BenchReduceDotF32;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64; LDummy: Single;
begin
  for i := 0 to WARMUP_ITERS - 1 do LDummy := ReduceDotF32(GA, GB, ARRAY_SIZE);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      LDummy := ReduceDotF32(GA, GB, ARRAY_SIZE);
    LTimes[i] := GetTimeMs - t0;
  end;
  if LDummy = -999999 then ;
  RecordResult('ReduceDotF32', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 4);
end;

procedure BenchReduceMinF32;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64; LDummy: Single;
begin
  for i := 0 to WARMUP_ITERS - 1 do LDummy := ReduceMinF32(GA, ARRAY_SIZE);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      LDummy := ReduceMinF32(GA, ARRAY_SIZE);
    LTimes[i] := GetTimeMs - t0;
  end;
  if LDummy = -999999 then ;
  RecordResult('ReduceMinF32', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 4);
end;

procedure BenchReduceMaxF32;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64; LDummy: Single;
begin
  for i := 0 to WARMUP_ITERS - 1 do LDummy := ReduceMaxF32(GA, ARRAY_SIZE);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      LDummy := ReduceMaxF32(GA, ARRAY_SIZE);
    LTimes[i] := GetTimeMs - t0;
  end;
  if LDummy = -999999 then ;
  RecordResult('ReduceMaxF32', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 4);
end;

procedure BenchArrayAddF64;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
    LDC: PDouble;
begin
  LDC := PDouble(SimdAlloc(ARRAY_SIZE * SizeOf(Double)));
  for i := 0 to WARMUP_ITERS - 1 do ArrayAddF64(GDA, GDB, LDC, ARRAY_SIZE);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      ArrayAddF64(GDA, GDB, LDC, ARRAY_SIZE);
    LTimes[i] := GetTimeMs - t0;
  end;
  RecordResult('ArrayAddF64', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 8);
  SimdFree(LDC);
end;

procedure BenchReduceSumF64;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64; LDummy: Double;
begin
  for i := 0 to WARMUP_ITERS - 1 do LDummy := ReduceSumF64(GDA, ARRAY_SIZE);
  for i := 0 to BENCH_ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to INNER_REPS - 1 do
      LDummy := ReduceSumF64(GDA, ARRAY_SIZE);
    LTimes[i] := GetTimeMs - t0;
  end;
  if LDummy = -999999 then ;
  RecordResult('ReduceSumF64', MedianOf(LTimes, BENCH_ITERS) / INNER_REPS, ARRAY_SIZE, 8);
end;

procedure PrintResults;
var i: Integer;
begin
  WriteLn('{"backend":"', GetCurrentBackendInfo.Name, '","array_size":', ARRAY_SIZE,
    ',"iters":', BENCH_ITERS, ',"results":[');
  for i := 0 to GResultCount - 1 do
  begin
    Write('  {"name":"', GResults[i].Name, '"');
    Write(',"median_ms":', GResults[i].MedianMs:0:2);
    Write(',"ops_per_sec":', GResults[i].OpsPerSec:0:0);
    Write(',"bytes_per_sec":', GResults[i].BytesPerSec:0:0);
    Write('}');
    if i < GResultCount - 1 then WriteLn(',') else WriteLn;
  end;
  WriteLn(']}');
end;

procedure PrintHuman;
var i: Integer;
begin
  WriteLn('SIMD Benchmark — Backend: ', GetCurrentBackendInfo.Name);
  WriteLn('Array size: ', ARRAY_SIZE, ' elements, ', BENCH_ITERS, ' iterations');
  WriteLn(StringOfChar('-', 70));
  WriteLn(Format('%-22s %8s %12s %12s', ['Operation', 'ms', 'Mops/s', 'GB/s']));
  WriteLn(StringOfChar('-', 70));
  for i := 0 to GResultCount - 1 do
    WriteLn(Format('%-22s %8.2f %12.1f %12.2f', [
      GResults[i].Name,
      GResults[i].MedianMs,
      GResults[i].OpsPerSec / 1e6,
      GResults[i].BytesPerSec / 1e9
    ]));
  WriteLn(StringOfChar('-', 70));
end;

var
  i: Integer;
  LJsonMode: Boolean;
begin
  LJsonMode := (ParamCount >= 1) and (ParamStr(1) = '--json');

  GA := PSingle(SimdAlloc(ARRAY_SIZE * SizeOf(Single)));
  GB := PSingle(SimdAlloc(ARRAY_SIZE * SizeOf(Single)));
  GC := PSingle(SimdAlloc(ARRAY_SIZE * SizeOf(Single)));
  GDA := PDouble(SimdAlloc(ARRAY_SIZE * SizeOf(Double)));
  GDB := PDouble(SimdAlloc(ARRAY_SIZE * SizeOf(Double)));

  for i := 0 to ARRAY_SIZE - 1 do
  begin
    GA[i] := 1.0 + (i mod 100) * 0.01;
    GB[i] := 2.0 - (i mod 100) * 0.01;
    GDA[i] := 1.0 + (i mod 100) * 0.001;
    GDB[i] := 2.0 - (i mod 100) * 0.001;
  end;

  BenchArrayAddF32;
  BenchArrayMulF32;
  BenchArrayMulScalarF32;
  BenchReduceSumF32;
  BenchReduceDotF32;
  BenchReduceMinF32;
  BenchReduceMaxF32;
  BenchArrayAddF64;
  BenchReduceSumF64;

  if LJsonMode then
    PrintResults
  else
    PrintHuman;

  SimdFree(GA);
  SimdFree(GB);
  SimdFree(GC);
  SimdFree(GDA);
  SimdFree(GDB);
end.
