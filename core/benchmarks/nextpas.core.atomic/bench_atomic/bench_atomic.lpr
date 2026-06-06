program bench_atomic;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.atomic,
  nextpas.core.time.base,
  nextpas.core.platform.info;

const
  ITERS = 1000000;

var
  GSink32: Int32;
  GSinkUInt32: UInt32;

function BenchmarkPlatformName: string;
begin
  Result := OSName + ' ' + CPUName;
end;

procedure PrintBenchmarkEnvelope;
begin
  WriteLn('Platform: ', BenchmarkPlatformName);
  WriteLn('Compiler flags: -MObjFPC -Sh -O2');
  WriteLn('Input size: ITERS=1000000; scenarios=plain baseline, AtomicLoad/Store32, AtomicFetchAdd32, AtomicCompareExchange32, TAtomicUInt32');
  WriteLn('Baselines: plain local variable operations for single-thread overhead context; compare_rust/main.rs external Rust source (not auto-run)');
  WriteLn;
end;

procedure PrintResult(const AName: string; const AElapsedNs: Int64; const AOperations: Int64);
var
  LElapsedNs: Int64;
begin
  LElapsedNs := AElapsedNs;
  if LElapsedNs <= 0 then
    LElapsedNs := 1;
  WriteLn(Format('  %-34s %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [AName,
     LElapsedNs / 1000000.0,
     AOperations / (LElapsedNs / 1000000000.0) / 1000000.0,
     LElapsedNs / Double(AOperations)]));
end;

procedure BenchPlainBaseline;
var
  LI: Integer;
  LValue: Int32;
  LStart: TInstant;
  LNs: Int64;
begin
  LValue := 0;
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
    Inc(LValue);
  LNs := LStart.Elapsed.AsNanoseconds;
  GSink32 := LValue;
  PrintResult('Plain local increment 1M', LNs, ITERS);
end;

procedure BenchAtomicLoadStore32;
var
  LI: Integer;
  LValue: Int32;
  LStart: TInstant;
  LNs: Int64;
begin
  LValue := 0;
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
  begin
    AtomicStore32(LValue, LI, moRelaxed);
    GSink32 := AtomicLoad32(LValue, moRelaxed);
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  PrintResult('AtomicLoad/Store32 2M', LNs, ITERS * 2);
end;

procedure BenchAtomicFetchAdd32;
var
  LI: Integer;
  LValue: Int32;
  LStart: TInstant;
  LNs: Int64;
begin
  LValue := 0;
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
    AtomicFetchAdd32(LValue, 1, moRelaxed);
  LNs := LStart.Elapsed.AsNanoseconds;
  GSink32 := LValue;
  PrintResult('AtomicFetchAdd32 1M', LNs, ITERS);
end;

procedure BenchAtomicCompareExchange32;
var
  LI: Integer;
  LValue: Int32;
  LExpected: Int32;
  LStart: TInstant;
  LNs: Int64;
begin
  LValue := 0;
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
  begin
    LExpected := LI - 1;
    GSink32 := AtomicCompareExchange32(LValue, LExpected, LI, moSeqCst);
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  GSink32 := LValue;
  PrintResult('AtomicCompareExchange32 1M', LNs, ITERS);
end;

procedure BenchTypedAtomicUInt32;
var
  LI: Integer;
  LAtomic: TAtomicUInt32;
  LStart: TInstant;
  LNs: Int64;
begin
  LAtomic := TAtomicUInt32.Create(0);
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
    LAtomic.FetchAdd(1, moRelaxed);
  LNs := LStart.Elapsed.AsNanoseconds;
  GSinkUInt32 := LAtomic.Load(moRelaxed);
  PrintResult('TAtomicUInt32 FetchAdd 1M', LNs, ITERS);
end;

begin
  WriteLn('=== nextpas.core.atomic benchmarks (1M iterations) ===');
  PrintBenchmarkEnvelope;
  BenchPlainBaseline;
  BenchAtomicLoadStore32;
  BenchAtomicFetchAdd32;
  BenchAtomicCompareExchange32;
  BenchTypedAtomicUInt32;
  WriteLn;
  WriteLn(Format('Sink: %d/%d', [GSink32, GSinkUInt32]));
  WriteLn('Done.');
end.
