program bench_platform_path;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.platform.path;

const
  ITERATIONS = 500000;

procedure ReportMetric(const AName: string; const AElapsedNs: UInt64);
begin
  WriteLn(AName, '-iterations=', ITERATIONS);
  WriteLn(AName, '-elapsed-ns=', AElapsedNs);
  if ITERATIONS > 0 then
    WriteLn(AName, '-ns-per-op=', AElapsedNs div ITERATIONS);
end;

procedure BenchJoin;
var
  Buf: array[0..255] of AnsiChar;
  LStart, LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    platform_path_join('/home/user/projects', 'nextpas/core/src/file.pas', @Buf[0], 256);
  LFinish := platform_monotonic_ns;
  ReportMetric('path-join', LFinish - LStart);
end;

procedure BenchNormalize;
var
  Buf: array[0..255] of AnsiChar;
  LStart, LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    platform_path_normalize('/home/user/../user/projects/./nextpas/../nextpas/core', @Buf[0], 256);
  LFinish := platform_monotonic_ns;
  ReportMetric('path-normalize', LFinish - LStart);
end;

procedure BenchBasename;
var
  Buf: array[0..255] of AnsiChar;
  LStart, LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    platform_path_basename('/home/user/projects/nextpas/core/src/nextpas.core.platform.path.pas', @Buf[0], 256);
  LFinish := platform_monotonic_ns;
  ReportMetric('path-basename', LFinish - LStart);
end;

procedure BenchExtension;
var
  Buf: array[0..31] of AnsiChar;
  LStart, LFinish: UInt64;
  I: Int32;
begin
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    platform_path_extension('nextpas.core.platform.path.pas', @Buf[0], 32);
  LFinish := platform_monotonic_ns;
  ReportMetric('path-extension', LFinish - LStart);
end;

begin
  BenchJoin;
  BenchNormalize;
  BenchBasename;
  BenchExtension;
end.
