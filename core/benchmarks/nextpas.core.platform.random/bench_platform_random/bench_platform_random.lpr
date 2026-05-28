program bench_platform_random;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.random;

const
  ITERATIONS = 100000;

procedure ReportMetric(const AName: string; const AElapsedNs: UInt64; ABytes: Int64);
begin
  WriteLn(AName, '-iterations=', ITERATIONS);
  WriteLn(AName, '-elapsed-ns=', AElapsedNs);
  if ITERATIONS > 0 then
    WriteLn(AName, '-ns-per-op=', AElapsedNs div ITERATIONS);
  if ABytes > 0 then
    WriteLn(AName, '-MB-per-sec=', (ABytes * 1000) div Int64(AElapsedNs));
end;

procedure BenchRandom32;
var
  Buf: array[0..31] of Byte;
  LStart, LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    platform_random_bytes(@Buf[0], 32);
  LFinish := platform_monotonic_ns;
  ReportMetric('random-32B', LFinish - LStart, Int64(ITERATIONS) * 32);
end;

procedure BenchRandom4K;
var
  Buf: array[0..4095] of Byte;
  LStart, LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    platform_random_bytes(@Buf[0], 4096);
  LFinish := platform_monotonic_ns;
  ReportMetric('random-4KB', LFinish - LStart, Int64(ITERATIONS) * 4096);
end;

begin
  BenchRandom32;
  BenchRandom4K;
end.
