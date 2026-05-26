program bench_platform_thread_lifecycle;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

const
  TLS_ITERATIONS = 200000;
  YIELD_ITERATIONS = 20000;
  THREAD_ITERATIONS = 1000;

var
  GSink: PtrUInt = 0;

function EmptyThread(AArg: Pointer): Pointer; cdecl;
begin
  Result := AArg;
end;

procedure ReportMetric(const AName: string; const AIterations: Int32; const AElapsedNs: UInt64);
begin
  WriteLn(AName, '-iterations=', AIterations);
  WriteLn(AName, '-elapsed-ns=', AElapsedNs);
  if AIterations > 0 then
    WriteLn(AName, '-ns-per-op=', AElapsedNs div UInt64(AIterations));
end;

procedure BenchTlsSetGet;
var
  LKey: TPlatformTLSKey;
  LStart: UInt64;
  LFinish: UInt64;
  I: Int32;
begin
  if platform_tls_create(LKey) <> 0 then
    Halt(1);

  LStart := platform_monotonic_ns;
  for I := 1 to TLS_ITERATIONS do
  begin
    if platform_tls_set(LKey, Pointer(PtrUInt(I))) <> 0 then
      Halt(1);
    GSink := GSink xor PtrUInt(platform_tls_get(LKey));
  end;
  LFinish := platform_monotonic_ns;

  platform_tls_destroy(LKey);
  if LFinish < LStart then
    Halt(1);
  ReportMetric('platform-thread-tls-set-get', TLS_ITERATIONS, LFinish - LStart);
end;

procedure BenchYield;
var
  LStart: UInt64;
  LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to YIELD_ITERATIONS do
    platform_thread_yield;
  LFinish := platform_monotonic_ns;

  if LFinish < LStart then
    Halt(1);
  ReportMetric('platform-thread-yield', YIELD_ITERATIONS, LFinish - LStart);
end;

procedure BenchCreateJoin;
var
  LStart: UInt64;
  LFinish: UInt64;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to THREAD_ITERATIONS do
  begin
    if platform_thread_create(LHandle, @EmptyThread, Pointer(PtrUInt(I))) <> 0 then
      Halt(1);
    if platform_thread_join(LHandle, LRetVal) <> 0 then
      Halt(1);
    GSink := GSink xor PtrUInt(LRetVal);
  end;
  LFinish := platform_monotonic_ns;

  if LFinish < LStart then
    Halt(1);
  ReportMetric('platform-thread-create-join', THREAD_ITERATIONS, LFinish - LStart);
end;

begin
  WriteLn('platform-thread-bench=running');
  BenchTlsSetGet;
  BenchYield;
  BenchCreateJoin;
  WriteLn('platform-thread-bench-sink=', GSink);
  WriteLn('platform-thread-bench-status=pass');
end.
