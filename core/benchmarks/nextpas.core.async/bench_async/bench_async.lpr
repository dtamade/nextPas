program bench_async;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.pipe,
  nextpas.core.platform.posix.ffi,
  nextpas.core.async.base,
  nextpas.core.async.timer,
  nextpas.core.async.loop,
  nextpas.core.io.poller;

const
  TIMER_COUNT = 10000;
  POST_COUNT = 10000;
  IO_ITERATIONS = 1000;

var
  GSink: UInt64 = 0;

procedure ReportMetric(const AName: string; const AIterations: UInt32; const AElapsedNs: Int64);
begin
  WriteLn(AName, '-iterations=', AIterations);
  WriteLn(AName, '-elapsed-ns=', AElapsedNs);
  if AIterations > 0 then
    WriteLn(AName, '-ns-per-op=', AElapsedNs div Int64(AIterations));
end;

{ --- Bench 1: Schedule 10000 timers --- }

procedure BenchTimerSchedule;
var
  LHeap: TTimerHeap;
  LStart: TInstant;
  LI: Int32;
  LH: TAsyncTimerHandle;
begin
  LHeap := TTimerHeap.Create;
  LStart := TInstant.Now;
  for LI := 1 to TIMER_COUNT do
  begin
    LH := LHeap.ScheduleAfter(TDuration.FromSeconds(60), nil, nil);
    GSink := GSink xor LH.FId;
  end;
  ReportMetric('timer-schedule', TIMER_COUNT, LStart.Elapsed.AsNanoseconds);
end;

{ --- Bench 2: Fire 10000 expired timers --- }

procedure DummyCallback(AContext: Pointer);
begin
  Inc(GSink);
end;

procedure BenchTimerFire;
var
  LHeap: TTimerHeap;
  LStart: TInstant;
  LI: Int32;
  LFired: UInt32;
begin
  LHeap := TTimerHeap.Create;
  { Schedule all timers as already expired }
  for LI := 1 to TIMER_COUNT do
    LHeap.Schedule(TDeadline.Expired, @DummyCallback, nil);
  { Measure fire time }
  LStart := TInstant.Now;
  LFired := LHeap.FireExpired;
  ReportMetric('timer-fire', LFired, LStart.Elapsed.AsNanoseconds);
end;

{ --- Bench 3: Schedule + Cancel 10000 timers --- }

procedure BenchTimerCancel;
var
  LHeap: TTimerHeap;
  LHandles: array[0..TIMER_COUNT - 1] of TAsyncTimerHandle;
  LStart: TInstant;
  LI: Int32;
begin
  LHeap := TTimerHeap.Create;
  { Schedule all }
  for LI := 0 to TIMER_COUNT - 1 do
    LHandles[LI] := LHeap.ScheduleAfter(TDuration.FromSeconds(60), @DummyCallback, nil);
  { Measure cancel time }
  LStart := TInstant.Now;
  for LI := 0 to TIMER_COUNT - 1 do
    LHeap.Cancel(LHandles[LI]);
  ReportMetric('timer-cancel', TIMER_COUNT, LStart.Elapsed.AsNanoseconds);
end;

{ --- Bench 4: Post 10000 callbacks (same thread) --- }

var
  GPostCount: Int32 = 0;

procedure PostCallback(AContext: Pointer);
begin
  Inc(GPostCount);
end;

procedure StopAfterDrain(AContext: Pointer);
begin
  TAsyncLoop(AContext^).Stop;
end;

procedure BenchPost;
var
  LLoop: TAsyncLoop;
  LStart: TInstant;
  LI: Int32;
begin
  LLoop := TAsyncLoop.Create;
  GPostCount := 0;
  LStart := TInstant.Now;
  for LI := 1 to POST_COUNT do
    LLoop.Post(@PostCallback, nil);
  { Post a final callback to stop the loop }
  LLoop.Post(@StopAfterDrain, @LLoop);
  LLoop.Run;
  ReportMetric('post-callback', POST_COUNT, LStart.Elapsed.AsNanoseconds);
  LLoop.Close;
end;

{ --- Bench 5: Poll with nothing pending --- }

procedure BenchPollEmpty;
var
  LLoop: TAsyncLoop;
  LStart: TInstant;
  LI: Int32;
const
  POLL_ITERS = 10000;
begin
  LLoop := TAsyncLoop.Create;
  LStart := TInstant.Now;
  for LI := 1 to POLL_ITERS do
    LLoop.Poll;
  ReportMetric('poll-empty', POLL_ITERS, LStart.Elapsed.AsNanoseconds);
  LLoop.Close;
end;

{ --- Bench 6: Async pipe read/write throughput --- }

var
  GIoCompleted: Int32 = 0;
  GIoBytes: Int64 = 0;

procedure IoReadCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  if AResult > 0 then
    Inc(GIoBytes, AResult);
  Inc(GIoCompleted);
end;

procedure BenchAsyncReadWrite;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteBuf: array[0..4095] of Byte;
  LReadBuf: array[0..4095] of Byte;
  LStart: TInstant;
  LI: Int32;
  LWritten: Int64;
begin
  LLoop := TAsyncLoop.Create;
  if not LLoop.IsValid then
  begin
    WriteLn('async-read-write-status=skip (loop not valid)');
    LLoop.Close;
    Exit;
  end;

  if platform_pipe_create(LPipe) <> 0 then
  begin
    WriteLn('async-read-write-status=skip (pipe failed)');
    LLoop.Close;
    Exit;
  end;

  FillChar(LWriteBuf[0], SizeOf(LWriteBuf), $AA);
  GIoCompleted := 0;
  GIoBytes := 0;

  LStart := TInstant.Now;
  for LI := 1 to IO_ITERATIONS do
  begin
    { Synchronous write to pipe }
    LWritten := nextpas.core.platform.posix.ffi.write(LPipe.WriteFd, @LWriteBuf[0], 4096);
    if LWritten <= 0 then
      Break;
    { Async read from pipe }
    LLoop.AsyncRead(LPipe.ReadFd, @LReadBuf[0], 4096, -1, @IoReadCallback, nil);
    LLoop.Poll;
  end;
  { Drain remaining }
  while GIoCompleted < IO_ITERATIONS do
    LLoop.Poll;

  ReportMetric('async-read-write', UInt32(IO_ITERATIONS), LStart.Elapsed.AsNanoseconds);
  WriteLn('async-read-write-bytes=', GIoBytes);

  platform_pipe_close(LPipe);
  LLoop.Close;
end;

begin
  WriteLn('bench-async=running');
  WriteLn;
  BenchTimerSchedule;
  WriteLn;
  BenchTimerFire;
  WriteLn;
  BenchTimerCancel;
  WriteLn;
  BenchPost;
  WriteLn;
  BenchPollEmpty;
  WriteLn;
  BenchAsyncReadWrite;
  WriteLn;
  WriteLn('bench-async-sink=', GSink);
  WriteLn('bench-async-status=pass');
end.
