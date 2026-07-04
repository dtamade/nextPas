program bench_async;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.platform.pipe, nextpas.core.platform.posix.ffi,
  nextpas.core.async.base, nextpas.core.async.timer,
  nextpas.core.async.loop, nextpas.core.io.poller;
const TIMER_COUNT = 10000; POST_COUNT = 10000;
var GSink: UInt64 = 0;
procedure DummyCallback(AContext: Pointer); begin Inc(GSink); end;
procedure BenchTimerSchedule(const ACtx: IBenchContext);
var LHeap: TTimerHeap; LI: Int32; LH: TAsyncTimerHandle;
begin
  LHeap := TTimerHeap.Create;
  for LI := 1 to TIMER_COUNT do begin LH := LHeap.ScheduleAfter(TDuration.FromSeconds(60), nil, nil); GSink := GSink xor LH.FId; end;
  LHeap.Free;
end;
procedure BenchTimerFire(const ACtx: IBenchContext);
var LHeap: TTimerHeap; LI: Int32; LH: TAsyncTimerHandle;
begin
  LHeap := TTimerHeap.Create;
  for LI := 1 to TIMER_COUNT do LH := LHeap.ScheduleAfter(TDuration.FromNanoseconds(1), @DummyCallback, nil);
  LHeap.FireExpired; LHeap.Free;
end;
procedure BenchTimerCancel(const ACtx: IBenchContext);
var LHeap: TTimerHeap; LI: Int32; LH: TAsyncTimerHandle;
begin
  LHeap := TTimerHeap.Create;
  for LI := 1 to TIMER_COUNT do begin LH := LHeap.ScheduleAfter(TDuration.FromSeconds(60), nil, nil); LHeap.Cancel(LH); end;
  LHeap.Free;
end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('async');
  LSuite.Add('TimerSchedule', @BenchTimerSchedule).Add('TimerFire', @BenchTimerFire).Add('TimerCancel', @BenchTimerCancel);
  WriteLn(LSuite.Run.PrintToConsole);
end.
