program bench_dispatch_overhead;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.dataplane,
  nextpas.core.time.stopwatch,
  nextpas.core.text.conv;

function MyBoolToStr(aValue: Boolean; const aTrueStr, aFalseStr: string): string;
begin
  if aValue then Result := aTrueStr else Result := aFalseStr;
end;

function MyFloatToStr(aVal: Double): string;
begin
  Str(aVal:0:2, Result);
end;

function MyFloatToStr0(aVal: Double): string;
begin
  Str(aVal:0:0, Result);
end;

function FormatNsPerCall(const aName: string; aNs: Double): string;
begin
  Result := '  ' + aName + ' ' + MyFloatToStr(aNs) + ' ns/call';
end;

function FormatNsPerCallTarget(const aName: string; aNs: Double; aTarget: Double): string;
begin
  Result := '  ' + aName + ' ' + MyFloatToStr(aNs) + ' ns/call  [TARGET: <' +
    MyFloatToStr0(aTarget) + ' ns] ' + MyBoolToStr(aNs < aTarget, 'PASS', 'FAIL');
end;

function FormatNsOverhead(const aName: string; aNs, aOverhead: Double): string;
begin
  Result := '  ' + aName + ' ' + MyFloatToStr(aNs) + ' ns/call  (overhead: ' +
    MyFloatToStr(aOverhead) + ' ns)';
end;

const
  WARMUP_ITERATIONS = 1000;
  MIN_ITERATIONS = 10000;
  TARGET_TIME_NS = 500 * 1000000;
  DISPATCH_TARGET_NS = 8.0;

// Pre-constructed operands to isolate dispatch overhead from construction cost
var
  g_OpA: TVecF32x4;
  g_OpB: TVecF32x4;
  g_OpNeg: TVecF32x4;
  g_OpSqrt: TVecF32x4;
  g_DummyF32: Single;
  g_DummyVec: TVecF32x4;

function BenchEmptyLoop: Int64;
begin
  Result := 1;
end;

function BenchSplatBaseline: Int64;
begin
  // Measure Splat alone as a reference
  g_OpA := VecF32x4Splat(1.0);
  g_OpB := VecF32x4Splat(2.0);
  Result := 2;
end;

function BenchDirectScalarCall: Int64;
begin
  g_DummyVec := ScalarAddF32x4(g_OpA, g_OpB);
  Result := 1;
end;

function BenchFullDispatchCall: Int64;
begin
  g_DummyVec := VecF32x4Add(g_OpA, g_OpB);
  Result := 1;
end;

function BenchDispatchSubF32x4: Int64;
begin
  g_DummyVec := VecF32x4Sub(g_OpA, g_OpB);
  Result := 1;
end;

function BenchDispatchMulF32x4: Int64;
begin
  g_DummyVec := VecF32x4Mul(g_OpA, g_OpB);
  Result := 1;
end;

function BenchDispatchAbsF32x4: Int64;
begin
  g_DummyVec := VecF32x4Abs(g_OpNeg);
  Result := 1;
end;

function BenchDispatchSqrtF32x4: Int64;
begin
  g_DummyVec := VecF32x4Sqrt(g_OpSqrt);
  Result := 1;
end;

function BenchDispatchDotF32x4: Int64;
begin
  g_DummyF32 := VecF32x4Dot(g_OpA, g_OpB);
  Result := 1;
end;

var
  g_CachedDispatch: PSimdDispatchTable = nil;

function BenchDispatchTableFetch: Int64;
begin
  g_CachedDispatch := GetDispatchTable;
  Result := 1;
end;

var
  g_CachedDataPlane: PSimdDataPlane = nil;

function BenchDataPlaneFetch: Int64;
begin
  g_CachedDataPlane := GetCurrentSimdDataPlane;
  Result := 1;
end;

function BenchCachedDispatchCall: Int64;
begin
  if g_CachedDispatch <> nil then
    g_DummyVec := g_CachedDispatch^.AddF32x4(g_OpA, g_OpB);
  Result := 1;
end;

// Direct function pointer call (bypass dispatch table entirely)
var
  g_DirectFuncPtr: function(const a, b: TVecF32x4): TVecF32x4 = nil;

function BenchDirectFuncPtrCall: Int64;
begin
  if g_DirectFuncPtr <> nil then
    g_DummyVec := g_DirectFuncPtr(g_OpA, g_OpB);
  Result := 1;
end;

type
  TBenchFunc = function: Int64;

  TDispatchBenchResult = record
    Name: string;
    NsPerCall: Double;
    OverheadNs: Double;
  end;

function MeasureNsPerCall(Func: TBenchFunc; out aTotalCalls: Int64): Double;
var
  LIterations, i: Integer;
  LElapsedNs: Int64;
  LStopwatch: TStopwatch;
begin
  for i := 1 to WARMUP_ITERATIONS do
    Func();

  LStopwatch := TStopwatch.StartNew;
  for i := 1 to MIN_ITERATIONS do
    Func();
  LStopwatch.Stop;
  LElapsedNs := LStopwatch.Elapsed.AsNanoseconds;

  if LElapsedNs > 0 then
    LIterations := Trunc((Int64(MIN_ITERATIONS) * TARGET_TIME_NS) / LElapsedNs)
  else
    LIterations := MIN_ITERATIONS * 10;

  if LIterations < MIN_ITERATIONS then
    LIterations := MIN_ITERATIONS;

  LStopwatch := TStopwatch.StartNew;
  for i := 1 to LIterations do
    Func();
  LStopwatch.Stop;

  aTotalCalls := LIterations;
  LElapsedNs := LStopwatch.Elapsed.AsNanoseconds;
  if LElapsedNs = 0 then
    LElapsedNs := 1;

  Result := LElapsedNs / LIterations;
end;

procedure PrintHeader(const aTitle: string);
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('  ', aTitle);
  WriteLn('========================================');
end;

procedure PrintResult(const aResult: TDispatchBenchResult; const aIsTarget: Boolean);
begin
  if aIsTarget then
    WriteLn(FormatNsPerCallTarget(aResult.Name, aResult.NsPerCall, DISPATCH_TARGET_NS))
  else
    WriteLn(FormatNsOverhead(aResult.Name, aResult.NsPerCall, aResult.OverheadNs));
end;

var
  LBackendInfo: TSimdBackendInfo;
  LTotalCalls: Int64;
  LBaselineNs, LOverheadNs: Double;
  LResult: TDispatchBenchResult;
  LBackend: TSimdBackend;
  LStr: string;

begin
  WriteLn('=== G17 Dispatch Overhead Benchmark ===');
  WriteLn;

  LBackend := GetActiveBackend;
  LBackendInfo := GetBackendInfo(LBackend);
  WriteLn('Active Backend: ', LBackendInfo.Name);
  WriteLn('Target: < ', DISPATCH_TARGET_NS:0:0, ' ns per dispatch call');
  WriteLn;

  // Pre-construct operands
  g_OpA := VecF32x4Splat(1.0);
  g_OpB := VecF32x4Splat(2.0);
  g_OpNeg := VecF32x4Splat(-1.0);
  g_OpSqrt := VecF32x4Splat(4.0);

  PrintHeader('Phase 1: Baseline Measurements');
  LResult.Name := 'Empty loop (no-op)';
  LResult.NsPerCall := MeasureNsPerCall(@BenchEmptyLoop, LTotalCalls);
  LResult.OverheadNs := 0.0;
  PrintResult(LResult, False);
  LBaselineNs := LResult.NsPerCall;
  Str(LBaselineNs:0:2, LStr);
  WriteLn('  -> Empty loop baseline: ', LStr, ' ns');

  LResult.Name := 'Splat construction (2x)';
  LResult.NsPerCall := MeasureNsPerCall(@BenchSplatBaseline, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  PrintHeader('Phase 2: Direct Call vs Dispatch (pre-constructed args)');
  LResult.Name := 'Direct scalar AddF32x4 call';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDirectScalarCall, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  LResult.Name := 'Full dispatch VecF32x4Add (target)';
  LResult.NsPerCall := MeasureNsPerCall(@BenchFullDispatchCall, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, True);

  PrintHeader('Phase 3: Dispatch Path Decomposition');
  LResult.Name := 'GetDispatchTable fetch only';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDispatchTableFetch, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  LResult.Name := 'GetCurrentSimdDataPlane fetch only';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDataPlaneFetch, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  g_CachedDispatch := GetDispatchTable;
  LResult.Name := 'Cached dispatch table + indirect call';
  LResult.NsPerCall := MeasureNsPerCall(@BenchCachedDispatchCall, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  g_DirectFuncPtr := @ScalarAddF32x4;
  LResult.Name := 'Direct function pointer call';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDirectFuncPtrCall, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  PrintHeader('Phase 4: Different Operations (dispatch)');
  LResult.Name := 'VecF32x4Sub (dispatch)';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDispatchSubF32x4, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  LResult.Name := 'VecF32x4Mul (dispatch)';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDispatchMulF32x4, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  LResult.Name := 'VecF32x4Abs (dispatch)';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDispatchAbsF32x4, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  LResult.Name := 'VecF32x4Sqrt (dispatch)';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDispatchSqrtF32x4, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  LResult.Name := 'VecF32x4Dot (dispatch)';
  LResult.NsPerCall := MeasureNsPerCall(@BenchDispatchDotF32x4, LTotalCalls);
  LResult.OverheadNs := LResult.NsPerCall - LBaselineNs;
  PrintResult(LResult, False);

  PrintHeader('Summary');
  LResult.NsPerCall := MeasureNsPerCall(@BenchFullDispatchCall, LTotalCalls);
  LOverheadNs := LResult.NsPerCall - LBaselineNs;

  Str(LOverheadNs:0:2, LStr);
  WriteLn('  dispatch_overhead: ', LStr, ' ns/call (target: <8 ns)');
  Str(LResult.NsPerCall:0:2, LStr);
  WriteLn('  raw_total: ', LStr, ' ns/call');
  Str(LBaselineNs:0:2, LStr);
  WriteLn('  empty_loop_baseline: ', LStr, ' ns/call');

  if LOverheadNs < DISPATCH_TARGET_NS then
    WriteLn('  STATUS: PASS - dispatch overhead within target')
  else
  begin
    Str(LOverheadNs - DISPATCH_TARGET_NS:0:2, LStr);
    WriteLn('  STATUS: GAP ', LStr, ' ns - dispatch overhead exceeds target');
  end;

  WriteLn;
  WriteLn('=== Benchmark Complete ===');
end.
