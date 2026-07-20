program bench_platform;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.platform.time, nextpas.core.platform.sync, nextpas.core.platform.files, nextpas.core.platform.files.base;
var GSink: UInt64 = 0;
procedure BenchTimerResolution(const ACtx: IBenchContext);
begin GSink := GSink xor platform_monotonic_ns; end;
procedure BenchMutexThroughput(const ACtx: IBenchContext);
var LM: TPlatformMutex;
begin
  if platform_mutex_init(LM, PLATFORM_MUTEX_NORMAL) <> 0 then
  begin
    ACtx.Skip('platform_mutex_init failed');
    Exit;
  end;
  platform_mutex_lock(LM); platform_mutex_unlock(LM);
  platform_mutex_destroy(LM);
end;
procedure BenchFileOpenClose(const ACtx: IBenchContext);
var LH: TPlatformFileHandle;
begin
  if platform_file_open('/dev/null', fomReadOnly, fcmOpenExisting, LH) = 0 then
    platform_file_close(LH);
end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('platform');
  LSuite.Add('TimerResolution', @BenchTimerResolution)
    .Add('Mutex/Throughput', @BenchMutexThroughput)
    .Add('File/OpenClose', @BenchFileOpenClose);
  WriteLn(LSuite.Run.PrintToConsole);
end.
