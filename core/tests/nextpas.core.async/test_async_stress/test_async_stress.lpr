program test_async_stress;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.time.cpu,
  nextpas.core.platform.pipe,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.thread,
  nextpas.core.atomic,
  nextpas.core.async.base,
  nextpas.core.async.timer,
  nextpas.core.async.loop,
  nextpas.core.io.poller;

var
  T: TTestSuite;

{ === Shared state === }

var
  GCallCount: Int32 = 0;
  GLoopRef: ^TAsyncLoop;

procedure ResetState;
begin
  GCallCount := 0;
  GLoopRef := nil;
end;

procedure IncrementCallback(AContext: Pointer);
begin
  Inc(GCallCount);
end;

procedure StopCallback(AContext: Pointer);
begin
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure IncrementAndMaybeStop(AContext: Pointer);
var
  LTarget: Int32;
begin
  Inc(GCallCount);
  LTarget := Int32(PtrUInt(AContext));
  if GCallCount >= LTarget then
  begin
    if GLoopRef <> nil then
      GLoopRef^.Stop;
  end;
end;

{ === Test 1: PostFromSameThread === }

procedure TestPostFromSameThread;
var
  LLoop: TAsyncLoop;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LLoop.Post(@IncrementCallback, nil);
  LLoop.Schedule(TDuration.FromMilliseconds(100), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GCallCount), 'post callback fired');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 2: PostFromOtherThread === }

type
  PPostThreadArg = ^TPostThreadArg;
  TPostThreadArg = record
    Loop: ^TAsyncLoop;
    Count: Int32;
  end;

function PostThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LArg: PPostThreadArg;
  LI: Int32;
begin
  LArg := PPostThreadArg(AArg);
  platform_thread_sleep_ns(1000000);
  for LI := 1 to LArg^.Count do
    LArg^.Loop^.Post(@IncrementCallback, nil);
  platform_thread_sleep_ns(5000000);
  LArg^.Loop^.Post(@StopCallback, nil);
  Result := nil;
end;

procedure TestPostFromOtherThread;
var
  LLoop: TAsyncLoop;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LArg: TPostThreadArg;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LArg.Loop := @LLoop;
  LArg.Count := 5;
  platform_thread_create(LHandle, @PostThreadProc, @LArg);
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
  LLoop.Run;
  platform_thread_join(LHandle, LRetVal);
  Check(GCallCount >= 5, 'all posts from other thread fired');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 3: Wake === }

function WakeThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LLoop: ^TAsyncLoop;
begin
  LLoop := AArg;
  platform_thread_sleep_ns(5000000);
  LLoop^.Wake;
  Result := nil;
end;

procedure TestWake;
var
  LLoop: TAsyncLoop;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LLoop.Schedule(TDuration.FromMilliseconds(50), @StopCallback, nil);
  platform_thread_create(LHandle, @WakeThreadProc, @LLoop);
  LLoop.Run;
  platform_thread_join(LHandle, LRetVal);
  Check(True, 'wake did not hang');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 4: ManyTimers === }

var
  GTimerOrder: array[0..1023] of Int32;
  GTimerIdx: Int32 = 0;

procedure TimerOrderCallback(AContext: Pointer);
var
  LVal: Int32;
begin
  LVal := Int32(PtrUInt(AContext));
  if GTimerIdx < 1024 then
  begin
    GTimerOrder[GTimerIdx] := LVal;
    Inc(GTimerIdx);
  end;
  if GTimerIdx >= 1000 then
  begin
    if GLoopRef <> nil then
      GLoopRef^.Stop;
  end;
end;

procedure TestManyTimers;
var
  LLoop: TAsyncLoop;
  LI: Int32;
  LOrdered: Boolean;
begin
  ResetState;
  GTimerIdx := 0;
  FillChar(GTimerOrder, SizeOf(GTimerOrder), 0);
  LLoop := TAsyncLoop.Create(64);
  GLoopRef := @LLoop;
  for LI := 0 to 999 do
    LLoop.Schedule(TDuration.FromMicroseconds(LI * 10),
      @TimerOrderCallback, Pointer(PtrUInt(LI)));
  LLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1000), Int64(GTimerIdx), '1000 timers fired');
  LOrdered := True;
  for LI := 1 to 999 do
  begin
    if GTimerOrder[LI] < GTimerOrder[LI - 1] then
    begin
      LOrdered := False;
      Break;
    end;
  end;
  Check(LOrdered, 'timers fired in order');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 5: RapidScheduleCancel === }

procedure TestRapidScheduleCancel;
var
  LLoop: TAsyncLoop;
  LH: TAsyncTimerHandle;
  LI: Int32;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(64);
  GLoopRef := @LLoop;
  for LI := 0 to 999 do
  begin
    LH := LLoop.Schedule(TDuration.FromMilliseconds(100),
      @IncrementCallback, nil);
    LLoop.CancelTimer(LH);
  end;
  { Schedule a timer to verify loop still works }
  LLoop.Schedule(TDuration.FromMilliseconds(5), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(0), Int64(GCallCount), 'no cancelled timers fired');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 6: CancelTimerAfterCloseIsStaleNoOp === }

procedure TestCancelTimerAfterCloseIsStaleNoOp;
var
  LLoop: TAsyncLoop;
  LH: TAsyncTimerHandle;
  LRaised: Boolean;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  LH := LLoop.Schedule(TDuration.FromMilliseconds(100), @IncrementCallback, nil);
  Check(LH.IsValid, 'pre-close timer handle valid');
  LLoop.Free;
  Check(not LLoop.IsValid, 'loop invalid after close');
  LRaised := False;
  try
    LLoop.CancelTimer(LH);
  except
    LRaised := True;
  end;
  Check(LRaised, 'cancel after close raises EInvalidOperationError');
end;

{ === Test 7: PostStress === }

const
  POST_STRESS_THREADS = 4;
  POST_STRESS_PER_THREAD = 100;
  POST_STRESS_TOTAL = POST_STRESS_THREADS * POST_STRESS_PER_THREAD;

type
  PStressThreadArg = ^TStressThreadArg;
  TStressThreadArg = record
    Loop: ^TAsyncLoop;
    Count: Int32;
  end;

function StressPostThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LArg: PStressThreadArg;
  LI: Int32;
begin
  LArg := PStressThreadArg(AArg);
  platform_thread_sleep_ns(1000000);
  for LI := 1 to LArg^.Count do
    LArg^.Loop^.Post(@IncrementCallback, nil);
  Result := nil;
end;

procedure TestPostStress;
var
  LLoop: TAsyncLoop;
  LHandles: array[0..POST_STRESS_THREADS - 1] of TPlatformThreadHandle;
  LArgs: array[0..POST_STRESS_THREADS - 1] of TStressThreadArg;
  LRetVal: Pointer;
  LI: Int32;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(64);
  GLoopRef := @LLoop;
  for LI := 0 to POST_STRESS_THREADS - 1 do
  begin
    LArgs[LI].Loop := @LLoop;
    LArgs[LI].Count := POST_STRESS_PER_THREAD;
    platform_thread_create(LHandles[LI], @StressPostThreadProc, @LArgs[LI]);
  end;
  { Safety timeout + stop when all posts arrive }
  LLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCallback, nil);
  LLoop.Run;
  for LI := 0 to POST_STRESS_THREADS - 1 do
    platform_thread_join(LHandles[LI], LRetVal);
  Check(GCallCount >= POST_STRESS_TOTAL,
    'all stress posts fired: got ' + IntToStr(GCallCount));
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 8: TimerPlusIO === }

var
  GTimerFired: Boolean = False;
  GIoFired: Boolean = False;

procedure TimerPlusIoTimerCb(AContext: Pointer);
begin
  GTimerFired := True;
end;

procedure TimerPlusIoIoCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GIoFired := True;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestTimerPlusIO;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf: array[0..3] of Byte;
begin
  GTimerFired := False;
  GIoFired := False;
  ResetState;
  LWriteBuf[0] := $CA; LWriteBuf[1] := $FE;
  LWriteBuf[2] := $BA; LWriteBuf[3] := $BE;
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);
  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  { Schedule a timer }
  LLoop.Schedule(TDuration.Zero, @TimerPlusIoTimerCb, nil);
  { Write then read via I/O }
  LLoop.AsyncWrite(LPipe.WriteFd, @LWriteBuf[0], 4, 0, nil, nil);
  LLoop.AsyncRead(LPipe.ReadFd, @LReadBuf[0], 4, 0, @TimerPlusIoIoCb, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
  LLoop.Run;
  Check(GTimerFired, 'timer fired in mixed test');
  Check(GIoFired, 'io fired in mixed test');
  CheckEqual(Int64($CA), Int64(LReadBuf[0]), 'io byte 0');
  GLoopRef := nil;
  LLoop.Free;
  platform_pipe_close(LPipe);
end;

{ === Test 9: StopFromPost === }

procedure PostStopCallback(AContext: Pointer);
begin
  Inc(GCallCount);
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestStopFromPost;
var
  LLoop: TAsyncLoop;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LLoop.Post(@PostStopCallback, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(100), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GCallCount), 'stop from post worked');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 10: PingPongWakeLatency === }
{ Lost-wakeup detector: each round posts exactly one item while the loop is
  (very likely) blocked in WaitForWake with only a distant safety timer.
  A wake-coalescing bug that drops a wakeup stalls the round until the
  safety timer, so the final ack count comes up short. }

const
  PING_PONG_ROUNDS = 200;

var
  GAckCount: Int32 = 0;

procedure PingAckCallback(AContext: Pointer);
begin
  atomic_fetch_add(GAckCount, 1, mo_acq_rel);
end;

function PingPongThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LLoop: ^TAsyncLoop;
  LRound: Int32;
  LDeadline: TDeadline;
begin
  LLoop := AArg;
  LDeadline := TDeadline.After(TDuration.FromSeconds(10));
  for LRound := 1 to PING_PONG_ROUNDS do
  begin
    LLoop^.Post(@PingAckCallback, nil);
    while (atomic_load(GAckCount, mo_acquire) < LRound) and
          (not LDeadline.IsExpired) do
      platform_thread_sleep_ns(50000);
    if LDeadline.IsExpired then
      Break;
  end;
  LLoop^.Post(@StopCallback, nil);
  Result := nil;
end;

procedure TestPingPongWakeLatency;
var
  LLoop: TAsyncLoop;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
begin
  ResetState;
  atomic_store(GAckCount, 0, mo_release);
  LLoop := TAsyncLoop.Create(64);
  GLoopRef := @LLoop;
  platform_thread_create(LHandle, @PingPongThreadProc, @LLoop);
  { Safety net: bounded exit even if a wakeup is lost }
  LLoop.Schedule(TDuration.FromMilliseconds(12000), @StopCallback, nil);
  LLoop.Run;
  platform_thread_join(LHandle, LRetVal);
  CheckEqual(Int64(PING_PONG_ROUNDS), Int64(atomic_load(GAckCount, mo_acquire)),
    'every post against a sleeping loop woke it');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 11: PollOnlyCrossThreadDrain === }
{ Poll (non-blocking pump) must observe cross-thread posts through the MPSC
  queue alone — no reliance on the wake fd. }

const
  POLL_DRAIN_TOTAL = 10000;

function PollDrainThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LLoop: ^TAsyncLoop;
  LI: Int32;
begin
  LLoop := AArg;
  for LI := 1 to POLL_DRAIN_TOTAL do
    LLoop^.Post(@IncrementCallback, nil);
  Result := nil;
end;

procedure TestPollOnlyCrossThreadDrain;
var
  LLoop: TAsyncLoop;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LDeadline: TDeadline;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(64);
  GLoopRef := @LLoop;
  platform_thread_create(LHandle, @PollDrainThreadProc, @LLoop);
  LDeadline := TDeadline.After(TDuration.FromSeconds(10));
  while (GCallCount < POLL_DRAIN_TOTAL) and (not LDeadline.IsExpired) do
    LLoop.Poll;
  platform_thread_join(LHandle, LRetVal);
  CheckEqual(Int64(POLL_DRAIN_TOTAL), Int64(GCallCount),
    'poll-only consumer drained all cross-thread posts');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 12: StopDuringDeepSleep === }
{ Loop sleeping with only a distant safety timer must exit promptly on a
  cross-thread Stop (stop wake must not be coalesced away). }

function DeepSleepStopThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LLoop: ^TAsyncLoop;
begin
  LLoop := AArg;
  platform_thread_sleep_ns(30000000);
  LLoop^.Stop;
  Result := nil;
end;

procedure TestStopDuringDeepSleep;
var
  LLoop: TAsyncLoop;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LStart: TInstant;
  LElapsedMs: Int64;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  { Distant safety timer bounds the test if the stop wake is lost }
  LLoop.Schedule(TDuration.FromMilliseconds(10000), @StopCallback, nil);
  platform_thread_create(LHandle, @DeepSleepStopThreadProc, @LLoop);
  LStart := TInstant.Now;
  LLoop.Run;
  LElapsedMs := TInstant.Now.DurationSince(LStart).AsMilliseconds;
  platform_thread_join(LHandle, LRetVal);
  Check(LElapsedMs < 5000,
    'stop during deep sleep exited promptly: ' + IntToStr(LElapsedMs) + 'ms');
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Main === }

begin
  T := TTestSuite.Create('nextpas.core.async.stress');

  T.Test('PostFromSameThread', @TestPostFromSameThread);
  T.Test('PostFromOtherThread', @TestPostFromOtherThread);
  T.Test('Wake', @TestWake);
  T.Test('ManyTimers', @TestManyTimers);
  T.Test('RapidScheduleCancel', @TestRapidScheduleCancel);
  T.Test('CancelTimerAfterCloseIsStaleNoOp', @TestCancelTimerAfterCloseIsStaleNoOp);
  T.Test('PostStress', @TestPostStress);
  T.Test('TimerPlusIO', @TestTimerPlusIO);
  T.Test('StopFromPost', @TestStopFromPost);
  T.Test('PingPongWakeLatency', @TestPingPongWakeLatency);
  T.Test('PollOnlyCrossThreadDrain', @TestPollOnlyCrossThreadDrain);
  T.Test('StopDuringDeepSleep', @TestStopDuringDeepSleep);

  if not T.Run then Halt(1);
end.
