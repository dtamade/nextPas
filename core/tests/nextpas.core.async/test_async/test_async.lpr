program test_async;

{$I nextpas.core.settings.inc}

uses
  Classes,
  StrUtils,
  SysUtils,
  nextpas.core.testing,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.time.cpu,
  nextpas.core.platform.pipe,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.socket,
  nextpas.core.async,
  nextpas.core.io.poller,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

procedure CheckSourceContains(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, ASource) > 0, AMessage);
end;

procedure CheckSourceNotContains(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, ASource) = 0, AMessage);
end;

procedure CheckSourceOrder(const ASource, AFirstNeedle, ASecondNeedle,
  AMessage: string);
var
  LFirst: SizeInt;
  LSecond: SizeInt;
begin
  LFirst := Pos(AFirstNeedle, ASource);
  LSecond := PosEx(ASecondNeedle, ASource, LFirst + Length(AFirstNeedle));
  Check((LFirst > 0) and (LSecond > LFirst), AMessage);
end;

function ExtractSourceRange(const ASource, AStartNeedle, AEndNeedle,
  AMessage: string): string;
var
  LStart: SizeInt;
  LEnd: SizeInt;
begin
  LStart := Pos(AStartNeedle, ASource);
  Check(LStart > 0, AMessage + ' start marker');
  LEnd := PosEx(AEndNeedle, ASource, LStart + Length(AStartNeedle));
  Check(LEnd > LStart, AMessage + ' end marker');
  Result := Copy(ASource, LStart, LEnd - LStart);
end;

{ === Timer Heap Tests === }

var
  GCallCount: Int32 = 0;
  GCallOrder: array[0..15] of Int32;

type
  PPollCancelCtx = ^TPollCancelCtx;
  TPollCancelCtx = record
    Loop: ^TAsyncLoop;
    Handle: TAsyncTimerHandle;
    PostedCount: Int32;
    TimerCount: Int32;
  end;

procedure ResetCallState;
var
  LI: Integer;
begin
  GCallCount := 0;
  for LI := 0 to High(GCallOrder) do
    GCallOrder[LI] := 0;
end;

procedure IncrementCallback(AContext: Pointer);
begin
  Inc(GCallCount);
end;

procedure PollTimerCallback(AContext: Pointer);
var
  LCtx: PPollCancelCtx;
begin
  LCtx := PPollCancelCtx(AContext);
  Inc(LCtx^.TimerCount);
end;

procedure PollCancelTimerCallback(AContext: Pointer);
var
  LCtx: PPollCancelCtx;
begin
  LCtx := PPollCancelCtx(AContext);
  Inc(LCtx^.PostedCount);
  Check(LCtx^.Loop^.CancelTimer(LCtx^.Handle),
    'posted callback cancels expired timer before Poll fires timers');
end;

procedure PostStopCallback(AContext: Pointer);
var
  LCtx: PPollCancelCtx;
begin
  LCtx := PPollCancelCtx(AContext);
  Inc(LCtx^.PostedCount);
  LCtx^.Loop^.Stop;
end;

procedure OrderCallback(AContext: Pointer);
var
  LVal: Int32;
begin
  LVal := Int32(PtrUInt(AContext));
  GCallOrder[GCallCount] := LVal;
  Inc(GCallCount);
end;

procedure TestTimerHeapBasic;
var
  LHeap: TTimerHeap;
  LH: TAsyncTimerHandle;
  LFired: UInt32;
begin
  ResetCallState;
  LHeap := TTimerHeap.Create;
  { Schedule a timer that expires immediately }
  LH := LHeap.Schedule(TDeadline.Expired, @IncrementCallback, nil);
  Check(LH.IsValid, 'handle valid');
  CheckEqual(Int64(1), Int64(LHeap.Count), 'count=1');
  LFired := LHeap.FireExpired;
  CheckEqual(Int64(1), Int64(LFired), 'fired=1');
  CheckEqual(Int64(1), Int64(GCallCount), 'callback called');
  CheckEqual(Int64(0), Int64(LHeap.Count), 'count=0 after fire');
end;

procedure TestTimerHeapOrder;
var
  LHeap: TTimerHeap;
  LFired: UInt32;
begin
  ResetCallState;
  LHeap := TTimerHeap.Create;
  { Schedule 3 timers with different deadlines, all expired }
  { Use Expired deadline so they all fire immediately, but order by context value }
  LHeap.Schedule(TDeadline.Expired, @OrderCallback, Pointer(PtrUInt(3)));
  LHeap.Schedule(TDeadline.Expired, @OrderCallback, Pointer(PtrUInt(1)));
  LHeap.Schedule(TDeadline.Expired, @OrderCallback, Pointer(PtrUInt(2)));
  LFired := LHeap.FireExpired;
  CheckEqual(Int64(3), Int64(LFired), 'all 3 fired');
  CheckEqual(Int64(3), Int64(GCallCount), 'all callbacks called');
end;

procedure TestTimerHeapOrderByDeadline;
var
  LHeap: TTimerHeap;
  LNow: TInstant;
  LFired: UInt32;
begin
  ResetCallState;
  LHeap := TTimerHeap.Create;
  LNow := TInstant.Now;
  { Schedule timers with deadlines in the past but ordered: 3rd, 1st, 2nd }
  LHeap.Schedule(TDeadline.At(LNow.Sub(TDuration.FromMilliseconds(10))),
    @OrderCallback, Pointer(PtrUInt(3)));
  LHeap.Schedule(TDeadline.At(LNow.Sub(TDuration.FromMilliseconds(30))),
    @OrderCallback, Pointer(PtrUInt(1)));
  LHeap.Schedule(TDeadline.At(LNow.Sub(TDuration.FromMilliseconds(20))),
    @OrderCallback, Pointer(PtrUInt(2)));
  LFired := LHeap.FireExpired;
  CheckEqual(Int64(3), Int64(LFired), 'all fired');
  { Should fire in deadline order: earliest first }
  CheckEqual(Int64(1), Int64(GCallOrder[0]), 'first=1');
  CheckEqual(Int64(2), Int64(GCallOrder[1]), 'second=2');
  CheckEqual(Int64(3), Int64(GCallOrder[2]), 'third=3');
end;

procedure TestTimerCancel;
var
  LHeap: TTimerHeap;
  LH1: TAsyncTimerHandle;
  LFired: UInt32;
  LOk: Boolean;
begin
  ResetCallState;
  LHeap := TTimerHeap.Create;
  LH1 := LHeap.Schedule(TDeadline.Expired, @IncrementCallback, nil);
  LHeap.Schedule(TDeadline.Expired, @IncrementCallback, nil);
  LOk := LHeap.Cancel(LH1);
  Check(LOk, 'cancel succeeded');
  LFired := LHeap.FireExpired;
  CheckEqual(Int64(1), Int64(LFired), 'only 1 fired');
  CheckEqual(Int64(1), Int64(GCallCount), 'only 1 callback');
  { Double cancel returns false }
  LOk := LHeap.Cancel(LH1);
  Check(not LOk, 'double cancel fails');
end;

procedure TestTimerCancelAfterFireIsStale;
var
  LHeap: TTimerHeap;
  LH: TAsyncTimerHandle;
  LFired: UInt32;
begin
  ResetCallState;
  LHeap := TTimerHeap.Create;
  LH := LHeap.Schedule(TDeadline.Expired, @IncrementCallback, nil);
  LFired := LHeap.FireExpired;

  CheckEqual(Int64(1), Int64(LFired), 'timer fired');
  CheckEqual(Int64(1), Int64(GCallCount), 'callback fired once');
  Check(not LHeap.Cancel(LH), 'fired timer handle is stale no-op');
end;

procedure TestTimerCancelClearsOwnerRefsSourceContract;
var
  LSource: string;
  LBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.timer.pas');
  LBody := ExtractSourceRange(LSource, 'function ttimerheap.cancel(',
    'function ttimerheap.nextdeadline', 'timer heap Cancel implementation');

  CheckSourceOrder(LBody, 'fentries[ahandle.fid].cancelled := true;',
    'fentries[ahandle.fid].callback := nil;',
    'successful timer cancel clears callback ownership immediately');
  CheckSourceOrder(LBody, 'fentries[ahandle.fid].cancelled := true;',
    'fentries[ahandle.fid].context := nil;',
    'successful timer cancel clears context ownership immediately');
end;

procedure TestTimerCloseClearsOwnerRefsSourceContract;
var
  LSource: string;
  LBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.timer.pas');
  LBody := ExtractSourceRange(LSource, 'procedure ttimerheap.close;',
    'function ttimerheap.schedule', 'timer heap Close implementation');

  CheckSourceOrder(LBody, 'for li := 0 to fentrycount - 1 do',
    'setlength(fentries, 0);',
    'Close scans live timer entries before releasing storage');
  CheckSourceOrder(LBody, 'if fentrycount > 0 then',
    'for li := 0 to fentrycount - 1 do',
    'Close guards the UInt32 scan against empty-heap underflow');
  CheckSourceOrder(LBody, 'fentries[li].callback := nil;',
    'setlength(fentries, 0);',
    'Close releases callback owner references before shrinking entries');
  CheckSourceOrder(LBody, 'fentries[li].context := nil;',
    'setlength(fentries, 0);',
    'Close releases context owner references before shrinking entries');
end;

procedure TestTimerNextDeadline;
var
  LHeap: TTimerHeap;
  LDl: TDeadline;
begin
  LHeap := TTimerHeap.Create;
  { Empty heap returns Infinite }
  LDl := LHeap.NextDeadline;
  Check(LDl.IsInfinite, 'empty=infinite');
  { Add a timer }
  LHeap.Schedule(TDeadline.After(TDuration.FromSeconds(10)), @IncrementCallback, nil);
  LDl := LHeap.NextDeadline;
  Check(not LDl.IsInfinite, 'not infinite');
  Check(not LDl.IsExpired, 'not expired');
end;

procedure TestTimerHandleNone;
var
  LH: TAsyncTimerHandle;
begin
  LH := TAsyncTimerHandle.None;
  Check(not LH.IsValid, 'None is not valid');
end;

{ === Async Loop Tests === }

var
  GLoopRef: ^TAsyncLoop;

procedure LoopStopCallback(AContext: Pointer);
begin
  Inc(GCallCount);
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestAsyncLoopCreate;
var
  LLoop: TAsyncLoop;
begin
  LLoop := TAsyncLoop.Create(32);
  Check(LLoop.IsValid, 'loop valid');
  LLoop.Close;
end;

procedure TestAsyncLoopTimer;
var
  LLoop: TAsyncLoop;
begin
  ResetCallState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  { Schedule timer that fires immediately and stops the loop }
  LLoop.Schedule(TDuration.Zero, @LoopStopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GCallCount), 'timer fired');
  GLoopRef := nil;
  LLoop.Close;
end;

procedure TestAsyncLoopMultiTimer;
var
  LLoop: TAsyncLoop;
begin
  ResetCallState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  { Schedule multiple timers; last one stops the loop }
  LLoop.Schedule(TDuration.Zero, @OrderCallback, Pointer(PtrUInt(1)));
  LLoop.Schedule(TDuration.FromMilliseconds(5), @OrderCallback, Pointer(PtrUInt(2)));
  LLoop.Schedule(TDuration.FromMilliseconds(10), @LoopStopCallback, nil);
  LLoop.Run;
  { First two order callbacks should have fired }
  Check(GCallCount >= 3, 'at least 3 callbacks');
  CheckEqual(Int64(1), Int64(GCallOrder[0]), 'first=1');
  CheckEqual(Int64(2), Int64(GCallOrder[1]), 'second=2');
  GLoopRef := nil;
  LLoop.Close;
end;

procedure TestAsyncLoopStop;
var
  LLoop: TAsyncLoop;
begin
  ResetCallState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  { Stop from within a timer callback }
  LLoop.Schedule(TDuration.Zero, @LoopStopCallback, nil);
  { Schedule another timer that should NOT fire because loop stops }
  LLoop.Schedule(TDuration.FromMilliseconds(50), @IncrementCallback, nil);
  LLoop.Run;
  { Only the stop callback should have fired }
  CheckEqual(Int64(1), Int64(GCallCount), 'only stop callback fired');
  GLoopRef := nil;
  LLoop.Close;
end;

procedure TestAsyncLoopStopWakesPlatformPollerSourceContract;
var
  LSource: string;
  LStopBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.loop.pas');
  LStopBody := ExtractSourceRange(LSource, 'procedure tasyncloop.stop;',
    'function tasyncloop.asyncsleep', 'async loop Stop implementation');

  CheckSourceContains(LStopBody, 'atomicstore32(frunning, 0, morelease);',
    'Stop clears the running flag');
  CheckSourceContains(LStopBody, 'wake;',
    'Stop wakes the platform poller seam for cross-thread callers');
  CheckSourceOrder(LStopBody, 'atomicstore32(frunning, 0, morelease);',
    'wake;', 'Stop publishes not-running before waking waiters');
end;

procedure TestAsyncLoopIdleWaitUsesWakeDrivenTimeoutSourceContract;
var
  LSource: string;
  LRunBody: string;
  LRunOnceBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.loop.pas');
  LRunBody := ExtractSourceRange(LSource, 'procedure tasyncloop.run;',
    'procedure tasyncloop.runonce;', 'async loop Run implementation');
  LRunOnceBody := ExtractSourceRange(LSource, 'procedure tasyncloop.runonce;',
    'procedure tasyncloop.stop;', 'async loop RunOnce implementation');

  CheckSourceContains(LSource,
    'function asyncwaketimeoutms(const adeadline: tdeadline): int32;',
    'async loop has one deadline-to-wake-timeout conversion helper');
  CheckSourceContains(LSource, 'if adeadline.isinfinite then',
    'async loop maps empty timer heap to an indefinite platform wait');
  CheckSourceContains(LSource, 'exit(-1);',
    'async loop uses platform indefinite wait instead of short polling');
  CheckSourceContains(LSource, 'async_pending_io_idle_poll_ms',
    'async loop keeps bounded wake waits while I/O remains pending');
  CheckSourceContains(LSource, 'apoller.haspending',
    'async loop distinguishes pure idle from pending I/O before indefinite waits');
  CheckSourceContains(LSource,
    'if apoller.haspending and' + LineEnding +
    '     ((result < 0) or (result > async_pending_io_idle_poll_ms)) then',
    'pending I/O caps wake-only waits even when a later timer exists');
  CheckSourceNotContains(LRunBody, 'if ltimeoutms > 10 then',
    'Run must not cap idle sleeps to a short polling interval');
  CheckSourceNotContains(LRunOnceBody, 'if ltimeoutms > 10 then',
    'RunOnce must not cap idle sleeps to a short polling interval');
  CheckSourceContains(LRunBody, 'waitforwake(asyncidlewaketimeoutms(fpoller, lnext));',
    'Run waits through the unified wake-driven timeout helper');
  CheckSourceContains(LRunOnceBody, 'waitforwake(asyncidlewaketimeoutms(fpoller, lnext));',
    'RunOnce waits through the unified wake-driven timeout helper');
end;

procedure TestAsyncLoopPendingQueueMutexSourceContract;
var
  LSource: string;
  LCloseBody: string;
  LPostBody: string;
  LDrainBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.loop.pas');
  LCloseBody := ExtractSourceRange(LSource, 'procedure tasyncloop.close;',
    'function tasyncloop.isvalid', 'async loop Close implementation');
  LPostBody := ExtractSourceRange(LSource, 'procedure tasyncloop.post(',
    'procedure tasyncloop.drainwake', 'async loop Post implementation');
  LDrainBody := ExtractSourceRange(LSource, 'procedure tasyncloop.drainpending;',
    'function tasyncloop.schedule', 'async loop DrainPending implementation');

  CheckSourceOrder(LCloseBody, 'fwakeready := false;',
    'platform_mutex_destroy(fpendinglock);',
    'Close publishes closed state before destroying pending queue mutex');
  CheckSourceContains(LCloseBody, 'lpendingwasready',
    'Close tracks pending queue mutex ownership separately from wake readiness');
  CheckSourceOrder(LCloseBody, 'lpendingwasready := fpendingready;',
    'fpendingready := false;',
    'Close captures pending queue ownership before publishing pending teardown state');
  CheckSourceOrder(LCloseBody, 'atomicstore32(frunning, 0, morelease);',
    'fpoller.close;',
    'Close publishes stopped state before poller teardown callbacks');
  CheckSourceOrder(LCloseBody, 'fwakeready := false;',
    'fpoller.close;',
    'Close publishes closed state before poller teardown callbacks');
  CheckSourceOrder(LCloseBody, 'if lpendingwasready then',
    'platform_mutex_destroy(fpendinglock);',
    'Close destroys pending queue mutex only when async loop owns it');
  CheckSourceOrder(LCloseBody, 'clearpendingqueue;',
    'platform_mutex_destroy(fpendinglock);',
    'Close clears pending callback owner references before destroying the mutex');
  CheckSourceOrder(LCloseBody, 'fpendingqueue[li].callback := nil;',
    'setlength(fpendingqueue, 0);',
    'Close releases pending callback owner references before shrinking queue storage');
  CheckSourceOrder(LCloseBody, 'fpendingqueue[li].context := nil;',
    'setlength(fpendingqueue, 0);',
    'Close releases pending context owner references before shrinking queue storage');
  CheckSourceOrder(LPostBody, 'if not isvalid then',
    'platform_mutex_lock(fpendinglock);',
    'Post rejects invalid loops before locking pending queue mutex');
  CheckSourceOrder(LPostBody, 'platform_mutex_lock(fpendinglock);',
    'try', 'Post protects pending queue mutex with try/finally');
  CheckSourceOrder(LPostBody, 'try', 'finally',
    'Post has a finally block for mutex unlock');
  CheckSourceOrder(LPostBody, 'finally',
    'platform_mutex_unlock(fpendinglock);',
    'Post unlocks pending queue mutex in finally');
  CheckSourceOrder(LPostBody, 'platform_mutex_unlock(fpendinglock);',
    'wake;', 'Post wakes only after releasing pending queue mutex');

  CheckSourceOrder(LDrainBody, 'platform_mutex_lock(fpendinglock);',
    'try', 'DrainPending protects pending queue mutex with try/finally');
  CheckSourceOrder(LDrainBody, 'try', 'finally',
    'DrainPending has a finally block for mutex unlock');
  CheckSourceOrder(LDrainBody, 'finally',
    'platform_mutex_unlock(fpendinglock);',
    'DrainPending unlocks pending queue mutex in finally');
end;

procedure TestAsyncLoopIoSubmissionClosedStateSourceContract;
var
  LSource: string;
  LBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.loop.pas');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncread(',
    'function tasyncloop.asyncwrite', 'async loop AsyncRead implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'fpoller.asyncread(', 'AsyncRead rejects closed loops before touching poller');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncwrite(',
    'function tasyncloop.asyncaccept', 'async loop AsyncWrite implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'fpoller.asyncwrite(', 'AsyncWrite rejects closed loops before touching poller');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncaccept(',
    'function tasyncloop.asyncrecv', 'async loop AsyncAccept implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'fpoller.asyncaccept(', 'AsyncAccept rejects closed loops before touching poller');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncrecv(',
    'function tasyncloop.asyncsend', 'async loop AsyncRecv implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'fpoller.asyncrecv(', 'AsyncRecv rejects closed loops before touching poller');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncsend(',
    'function tasyncloop.poll', 'async loop AsyncSend implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'fpoller.asyncsend(', 'AsyncSend rejects closed loops before touching poller');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncreadtimeout(',
    'function tasyncloop.asyncwritetimeout',
    'async loop AsyncReadTimeout implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'timeoutctxcreate(', 'AsyncReadTimeout rejects closed loops before allocating timeout context');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncwritetimeout(',
    'function tasyncloop.asyncrecvtimeout',
    'async loop AsyncWriteTimeout implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'timeoutctxcreate(', 'AsyncWriteTimeout rejects closed loops before allocating timeout context');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncrecvtimeout(',
    'function tasyncloop.asyncsendtimeout',
    'async loop AsyncRecvTimeout implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'timeoutctxcreate(', 'AsyncRecvTimeout rejects closed loops before allocating timeout context');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncsendtimeout(',
    'end.', 'async loop AsyncSendTimeout implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'timeoutctxcreate(', 'AsyncSendTimeout rejects closed loops before allocating timeout context');
end;

procedure TestAsyncLoopExecutionClosedStateSourceContract;
var
  LSource: string;
  LBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.loop.pas');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.poll:',
    'procedure tasyncloop.run;', 'async loop Poll implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'ftimers.fireexpired', 'Poll rejects closed loops before touching timers');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'fpoller.flush', 'Poll rejects closed loops before touching poller');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'drainpending', 'Poll rejects closed loops before touching pending queue');

  LBody := ExtractSourceRange(LSource, 'procedure tasyncloop.run;',
    'procedure tasyncloop.runonce;', 'async loop Run implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'atomicstore32(frunning, 1', 'Run rejects closed loops before publishing running state');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'drainpending', 'Run rejects closed loops before touching pending queue');
  CheckSourceOrder(LBody, 'lfired := ftimers.fireexpired;',
    'if atomicload32(frunning, moacquire) = 0 then',
    'Run honors Stop after firing expired timers');
  CheckSourceOrder(LBody, 'if atomicload32(frunning, moacquire) = 0 then',
    'fpoller.flush',
    'Run honors Stop before polling I/O');

  LBody := ExtractSourceRange(LSource, 'procedure tasyncloop.runonce;',
    'procedure tasyncloop.stop;', 'async loop RunOnce implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'drainpending', 'RunOnce rejects closed loops before touching pending queue');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'fpoller.flush', 'RunOnce rejects closed loops before touching poller');
  CheckSourceOrder(LBody, 'atomicstore32(frunning, 1',
    'drainpending', 'RunOnce publishes running state before posted callbacks');
  CheckSourceOrder(LBody, 'lfired := ftimers.fireexpired;',
    'if atomicload32(frunning, moacquire) = 0 then',
    'RunOnce honors Stop after firing already-expired timers');
  CheckSourceOrder(LBody, 'if atomicload32(frunning, moacquire) = 0 then',
    'fpoller.flush', 'RunOnce skips I/O after Stop from posted callback');
end;

procedure TestAsyncLoopRunOncePostWakeTimersBeforeIoSourceContract;
var
  LSource: string;
  LRunOnceBody: string;
  LPostWakeBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.loop.pas');
  LRunOnceBody := ExtractSourceRange(LSource, 'procedure tasyncloop.runonce;',
    'procedure tasyncloop.stop;', 'async loop RunOnce implementation');
  LPostWakeBody := ExtractSourceRange(LRunOnceBody,
    'waitforwake(asyncidlewaketimeoutms(fpoller, lnext));',
    'end;', 'async loop RunOnce post-wake batch');

  CheckSourceOrder(LPostWakeBody, 'drainwake;',
    'drainpending;',
    'RunOnce drains wake before pending callbacks after sleep');
  CheckSourceOrder(LPostWakeBody, 'drainpending;',
    'ftimers.fireexpired;',
    'RunOnce preserves timer-before-I/O ordering after sleep');
  CheckSourceOrder(LPostWakeBody, 'ftimers.fireexpired;',
    'fpoller.flush;',
    'RunOnce flushes I/O only after post-wake expired timers');
  CheckSourceOrder(LPostWakeBody, 'fpoller.flush;',
    'fpoller.poll;',
    'RunOnce polls I/O after flushing the poller');
end;

procedure TestAsyncLoopTimerReadinessGuardSourceContract;
var
  LSource: string;
  LBody: string;
begin
  LSource := LoadSourceText('src/nextpas.core.async.loop.pas');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.schedule(',
    'function tasyncloop.scheduleat', 'async loop Schedule implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'ftimers.scheduleafter', 'Schedule rejects invalid loops before touching timers');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.scheduleat(',
    'function tasyncloop.canceltimer', 'async loop ScheduleAt implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'ftimers.schedule(', 'ScheduleAt rejects invalid loops before touching timers');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.canceltimer(',
    'function tasyncloop.asyncread', 'async loop CancelTimer implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'ftimers.cancel', 'CancelTimer rejects invalid loops before touching timers');

  LBody := ExtractSourceRange(LSource, 'function tasyncloop.asyncsleep(',
    'function tasyncloop.asyncreadtimeout', 'async loop AsyncSleep implementation');
  CheckSourceOrder(LBody, 'if not isvalid then',
    'ftimers.scheduleafter', 'AsyncSleep rejects invalid loops before touching timers');
end;

procedure TestAsyncStressUsesCthreadsSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('tests/nextpas.core.async/test_async_stress/test_async_stress.lpr');
  CheckSourceContains(LSource, 'platform_thread_create',
    'stress test should exercise platform threads');
  CheckSourceOrder(LSource, 'cthreads',
    'nextpas.core.platform.thread',
    'Unix stress test enables the FPC pthread RTL before platform thread wrappers');
end;

procedure TestAsyncReadmeTruthMatrixSourceContract;
var
  LReadme: string;
  LPollerSource: string;
begin
  LReadme := LoadSourceText('docs/async/README.md');
  LPollerSource := LoadSourceText('src/nextpas.core.io.poller.pas');

  CheckSourceContains(LReadme, 'linux runtime truth',
    'async README must separate Linux runtime truth');
  CheckSourceContains(LReadme, 'windows compile truth',
    'async README must separate Windows compile truth');
  CheckSourceContains(LReadme, 'source-contract + forced compile',
    'async README must name Windows source-contract and forced compile limits');
  CheckSourceContains(LReadme, 'not windows runtime ready',
    'async README must not claim Windows runtime readiness without runtime proof');
  CheckSourceContains(LReadme, 'no `pbkqueue` backend',
    'async README must state current poller has no kqueue backend');
  CheckSourceContains(LReadme, '`pbunsupported`',
    'async README must document the unsupported backend truth');
  CheckSourceContains(LReadme, '`test_async_timeout` enforces heaptrc',
    'async README leak proof must name the gate that enforces heaptrc');
  CheckSourceContains(LReadme, 'poller, wake poller, and pending queue mutex',
    'async README IsValid truth must include every loop-owned readiness bit');
  CheckSourceContains(LReadme, 'pure idle waits may block indefinitely',
    'async README must document pure idle platform-wake waits');
  CheckSourceContains(LReadme, 'pending i/o caps wake-only waits',
    'async README must document pending I/O wake timeout cap');
  CheckSourceContains(LReadme, '`pbiouring` and `pbiocp` are `pbmcompletionqueue`',
    'async README must document completion-queue backend models');
  CheckSourceContains(LReadme, '`pbepoll` is `pbmreadiness`',
    'async README must document epoll as readiness fallback');
  CheckSourceContains(LReadme, 'platform wake is not the iocp owner',
    'async README must keep platform wake separate from IOCP completion ownership');
  CheckSourceNotContains(LReadme, 'eventfd',
    'async README must describe wake through the platform poller seam');
  CheckSourceNotContains(LReadme, 'poll()` with timeout capped at 10ms',
    'async README must not keep the old fixed polling cap model');
  CheckSourceNotContains(LReadme, 'production-quality',
    'async README must not overstate production quality');
  CheckSourceNotContains(LReadme, 'kqueue/iocp backends are stubs',
    'async README must not collapse kqueue and IOCP truth');

  CheckSourceContains(LPollerSource,
    'tpollerbackend = (pbiouring, pbepoll, pbiocp, pbunsupported);',
    'poller backend enum must expose current backend truth');
  CheckSourceContains(LPollerSource,
    'tpollerbackendmodel = (pbmcompletionqueue, pbmreadiness, pbmunsupported);',
    'poller backend model enum must classify readiness vs completion truth');
  CheckSourceContains(LPollerSource, 'pbiocp: result := pbmcompletionqueue;',
    'IOCP poller model must remain completion-queue truth');
  CheckSourceContains(LPollerSource, 'pbepoll: result := pbmreadiness;',
    'epoll poller model must remain readiness truth');
  CheckSourceNotContains(LPollerSource, 'pbkqueue',
    'poller backend enum must not imply a kqueue backend');
end;

procedure TestAsyncFacadeExportsTaskStateMachine;
var
  LTask: TAsyncTask;
  LStatus: TAsyncTaskStatus;
  LStateAlias: TAsyncTaskState;
  LBaseSource: string;
  LTaskSource: string;
  LFacadeSource: string;
begin
  LBaseSource := LoadSourceText('src/nextpas.core.async.base.pas');
  LTaskSource := LoadSourceText('src/nextpas.core.async.task.pas');
  LFacadeSource := LoadSourceText('src/nextpas.core.async.pas');

  CheckSourceContains(LBaseSource,
    'tasynctaskstate = (atsidle, atspending, atscompleted, atsfailed, atstimedout, atscancelled);',
    'async.base must own the canonical six-state task enum');
  CheckSourceContains(LBaseSource, 'tasynctaskstatus = tasynctaskstate;',
    'async.base must expose the status compatibility alias from the canonical enum');
  CheckSourceNotContains(LTaskSource, 'tasynctaskstatus = (',
    'async.task must not define a second task state enum');
  CheckSourceContains(LTaskSource,
    'tasynctaskstatus = nextpas.core.async.base.tasynctaskstatus;',
    'async.task must consume the base canonical task status type');
  CheckSourceContains(LFacadeSource,
    'tasynctaskstatus = nextpas.core.async.base.tasynctaskstatus;',
    'async facade must re-export task status from base');
  CheckSourceContains(LFacadeSource,
    'tasynctaskstate = nextpas.core.async.base.tasynctaskstate;',
    'async facade must re-export task state from base');

  LTask := TAsyncTask.Create;
  LStatus := LTask.Status;
  LStateAlias := LTask.Status;
  CheckEqual(Int64(Ord(atsIdle)), Int64(Ord(LStatus)),
    'facade exports task status enum');
  CheckEqual(Int64(Ord(atsIdle)), Int64(Ord(LStateAlias)),
    'facade task state alias follows task status enum');

  LTask.Complete(17);
  CheckEqual(Int64(Ord(atsCompleted)), Int64(Ord(LTask.Status)),
    'facade exports completed state');
  CheckEqual(Int64(17), Int64(LTask.GetResult),
    'facade exports task state machine API');
end;

procedure TestAsyncLoopTimerCancel;
var
  LLoop: TAsyncLoop;
  LH: TAsyncTimerHandle;
begin
  ResetCallState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  { Schedule a timer then cancel it }
  LH := LLoop.Schedule(TDuration.Zero, @IncrementCallback, nil);
  LLoop.CancelTimer(LH);
  { Schedule stop timer }
  LLoop.Schedule(TDuration.FromMilliseconds(5), @LoopStopCallback, nil);
  LLoop.Run;
  { The cancelled timer should not have fired; only stop callback }
  CheckEqual(Int64(1), Int64(GCallCount), 'cancelled timer did not fire');
  GLoopRef := nil;
  LLoop.Close;
end;

var
  GIoReadDone: Boolean = False;
  GIoReadResult: Int32 = 0;

procedure IoWriteDone(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  { Write completed }
end;

procedure IoReadDone(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GIoReadDone := True;
  GIoReadResult := AResult;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestAsyncLoopIO;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf: array[0..3] of Byte;
begin
  GIoReadDone := False;
  GIoReadResult := 0;
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);
  LWriteBuf[0] := $DE; LWriteBuf[1] := $AD;
  LWriteBuf[2] := $BE; LWriteBuf[3] := $EF;

  { Create a pipe }
  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Write to pipe }
  LLoop.AsyncWrite(LPipe.WriteFd, @LWriteBuf[0], 4, 0, @IoWriteDone, nil);
  { Read from pipe }
  LLoop.AsyncRead(LPipe.ReadFd, @LReadBuf[0], 4, 0, @IoReadDone, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @LoopStopCallback, nil);

  LLoop.Run;

  Check(GIoReadDone, 'read completed');
  Check(GIoReadResult >= 4, 'read 4 bytes');
  CheckEqual(Int64($DE), Int64(LReadBuf[0]), 'byte 0');
  CheckEqual(Int64($AD), Int64(LReadBuf[1]), 'byte 1');
  CheckEqual(Int64($BE), Int64(LReadBuf[2]), 'byte 2');
  CheckEqual(Int64($EF), Int64(LReadBuf[3]), 'byte 3');

  GLoopRef := nil;
  LLoop.Close;
  platform_pipe_close(LPipe);
end;

procedure TestAsyncLoopPoll;
var
  LLoop: TAsyncLoop;
  LResult: Int32;
begin
  ResetCallState;
  LLoop := TAsyncLoop.Create(32);
  { Schedule expired timer }
  LLoop.Schedule(TDuration.Zero, @IncrementCallback, nil);
  { Poll should fire it }
  LResult := LLoop.Poll;
  Check(LResult >= 1, 'poll returned events');
  CheckEqual(Int64(1), Int64(GCallCount), 'callback fired via poll');
  LLoop.Close;
end;

procedure TestAsyncLoopPollDrainsPostBeforeExpiredTimer;
var
  LLoop: TAsyncLoop;
  LCtx: TPollCancelCtx;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  LLoop := TAsyncLoop.Create(32);
  LCtx.Loop := @LLoop;
  LCtx.Handle := LLoop.Schedule(TDuration.Zero, @PollTimerCallback, @LCtx);
  Check(LCtx.Handle.IsValid, 'timer handle valid');
  LLoop.Post(@PollCancelTimerCallback, @LCtx);

  LLoop.Poll;

  CheckEqual(Int64(1), Int64(LCtx.PostedCount),
    'Poll drains posted callbacks before expired timers');
  CheckEqual(Int64(0), Int64(LCtx.TimerCount),
    'posted cancellation prevents expired timer callback');
  LLoop.Close;
end;

procedure TestAsyncLoopRunStopFromPostStillFiresExpiredTimers;
var
  LLoop: TAsyncLoop;
  LCtx: TPollCancelCtx;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  LLoop := TAsyncLoop.Create(32);
  try
    LCtx.Loop := @LLoop;
    LLoop.Schedule(TDuration.Zero, @PollTimerCallback, @LCtx);
    LLoop.Post(@PostStopCallback, @LCtx);

    LLoop.Run;

    CheckEqual(Int64(1), Int64(LCtx.PostedCount),
      'Run drains posted stop callback');
    CheckEqual(Int64(1), Int64(LCtx.TimerCount),
      'Run fires already-expired timers before honoring Stop from posted callback');
  finally
    LLoop.Close;
  end;
end;

var
  GRunOnceIoCount: Int32 = 0;

procedure RunOnceIoCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GRunOnceIoCount);
end;

procedure TestAsyncLoopRunOnceStopFromPostSkipsIoPoll;
var
  LLoop: TAsyncLoop;
  LCtx: TPollCancelCtx;
  LPipe: TPlatformPipe;
  LPipeReady: Boolean;
  LReadBuf: array[0..3] of Byte;
  LWriteBuf: array[0..3] of Byte;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);
  LWriteBuf[0] := 1;
  LWriteBuf[1] := 2;
  LWriteBuf[2] := 3;
  LWriteBuf[3] := 4;
  GRunOnceIoCount := 0;
  LPipeReady := False;

  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;

  try
    LPipeReady := True;
    if write(LPipe.WriteFd, @LWriteBuf[0], SizeOf(LWriteBuf)) <> SizeOf(LWriteBuf) then
    begin
      Fail('pipe write failed');
      Exit;
    end;

    LLoop := TAsyncLoop.Create(32);
    try
      LCtx.Loop := @LLoop;
      LLoop.Schedule(TDuration.Zero, @PollTimerCallback, @LCtx);
      Check(LLoop.AsyncRead(LPipe.ReadFd, @LReadBuf[0], SizeOf(LReadBuf), -1,
        @RunOnceIoCallback, nil), 'read queued before RunOnce');
      LLoop.Post(@PostStopCallback, @LCtx);

      LLoop.RunOnce;

      CheckEqual(Int64(1), Int64(LCtx.PostedCount),
        'RunOnce drains posted stop callback');
      CheckEqual(Int64(1), Int64(LCtx.TimerCount),
        'RunOnce fires already-expired timers before honoring Stop');
      CheckEqual(Int64(0), Int64(GRunOnceIoCount),
        'RunOnce skips I/O poll after Stop from posted callback');
    finally
      LLoop.Close;
    end;
  finally
    if LPipeReady then
      platform_pipe_close(LPipe);
  end;
end;

{ === ScheduleAt: absolute deadline scheduling === }

var
  GScheduleAtFired: Boolean = False;

procedure ScheduleAtCallback(AContext: Pointer);
begin
  GScheduleAtFired := True;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestAsyncLoopScheduleAt;
var
  LLoop: TAsyncLoop;
  LDeadline: TDeadline;
begin
  GScheduleAtFired := False;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Schedule at an absolute time ~50ms from now }
  LDeadline := TDeadline.After(TDuration.FromMilliseconds(50));
  LLoop.ScheduleAt(LDeadline, @ScheduleAtCallback, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @LoopStopCallback, nil);
  LLoop.Run;

  Check(GScheduleAtFired, 'ScheduleAt callback fired');
  GLoopRef := nil;
  LLoop.Close;
end;

{ === AsyncRecv/AsyncSend via TCP loopback === }

var
  GSockIoDone: Boolean = False;
  GSockIoResult: Int32 = 0;

procedure SocketIoCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GSockIoDone := True;
  GSockIoResult := AResult;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestAsyncLoopAsyncRecvSend;
var
  LLoop: TAsyncLoop;
  LListener: ITcpListener;
  LClient: ITcpStream;
  LServer: ITcpStream;
  LSendBuf: array[0..3] of Byte;
  LRecvBuf: array[0..3] of Byte;
  LClientFd, LServerFd: PtrInt;
  LListenerFd: PtrInt;
begin
  GSockIoDone := False;
  GSockIoResult := 0;
  FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
  LSendBuf[0] := $AA; LSendBuf[1] := $BB;
  LSendBuf[2] := $CC; LSendBuf[3] := $DD;

  { Create TCP loopback pair }
  LListener := NetTcpListen('127.0.0.1', 0);
  LClient := NetTcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LServer := LListener.Accept;

  { Set client to non-blocking for async send }
  (LClient as ITcpSocketRuntime).SetBlocking(False);
  LClientFd := PtrInt((LClient as ITcpSocketRuntime).NativeSocketHandle);

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { AsyncSend data from client }
  Check(LLoop.AsyncSend(LClientFd, @LSendBuf[0], 4, 0, @SocketIoCallback, nil),
    'AsyncSend accepted');

  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @LoopStopCallback, nil);
  LLoop.Run;

  Check(GSockIoDone, 'send completed');
  Check(GSockIoResult >= 4, 'sent >= 4 bytes');

  { Now read from server side (blocking is fine) }
  LServer.Read(LRecvBuf[0], 4);
  CheckEqual(Int64($AA), Int64(LRecvBuf[0]), 'byte 0');
  CheckEqual(Int64($BB), Int64(LRecvBuf[1]), 'byte 1');
  CheckEqual(Int64($CC), Int64(LRecvBuf[2]), 'byte 2');
  CheckEqual(Int64($DD), Int64(LRecvBuf[3]), 'byte 3');

  GLoopRef := nil;
  LLoop.Close;
end;

{ === AsyncRecv via TCP loopback === }

var
  GRecvDone: Boolean = False;
  GRecvResult: Int32 = 0;

procedure RecvIoCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GRecvDone := True;
  GRecvResult := AResult;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestAsyncLoopAsyncRecv;
var
  LLoop: TAsyncLoop;
  LListener: ITcpListener;
  LClient: ITcpStream;
  LServer: ITcpStream;
  LSendBuf: array[0..3] of Byte;
  LRecvBuf: array[0..3] of Byte;
  LServerFd: PtrInt;
  LSent: SizeUInt;
begin
  GRecvDone := False;
  GRecvResult := 0;
  FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
  LSendBuf[0] := $11; LSendBuf[1] := $22;
  LSendBuf[2] := $33; LSendBuf[3] := $44;

  LListener := NetTcpListen('127.0.0.1', 0);
  LClient := NetTcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LServer := LListener.Accept;

  { Write data synchronously from client first }
  LSent := LClient.Write(LSendBuf[0], 4);
  Check(LSent >= 4, 'wrote 4 bytes synchronously');

  { Set server side to non-blocking for async recv }
  (LServer as ITcpSocketRuntime).SetBlocking(False);
  LServerFd := PtrInt((LServer as ITcpSocketRuntime).NativeSocketHandle);

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { AsyncRecv on server side }
  Check(LLoop.AsyncRecv(LServerFd, @LRecvBuf[0], 4, 0, @RecvIoCallback, nil),
    'AsyncRecv accepted');
  LLoop.Schedule(TDuration.FromMilliseconds(500), @LoopStopCallback, nil);
  LLoop.Run;

  Check(GRecvDone, 'recv completed');
  Check(GRecvResult >= 4, 'recv >= 4 bytes');
  CheckEqual(Int64($11), Int64(LRecvBuf[0]), 'byte 0');
  CheckEqual(Int64($22), Int64(LRecvBuf[1]), 'byte 1');
  CheckEqual(Int64($33), Int64(LRecvBuf[2]), 'byte 2');
  CheckEqual(Int64($44), Int64(LRecvBuf[3]), 'byte 3');

  GLoopRef := nil;
  LLoop.Close;
end;

{ === AsyncAccept on TCP listener === }

var
  GAcceptDone: Boolean = False;
  GAcceptResult: Int32 = 0;

procedure AcceptCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GAcceptDone := True;
  GAcceptResult := AResult;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestAsyncLoopAsyncAccept;
var
  LLoop: TAsyncLoop;
  LListener: ITcpListener;
  LClient: ITcpStream;
  LListenerFd: PtrInt;
  LSa: sockaddr_in;
  LSaLen: socklen_t;
  LAcceptedFd: TPlatformSocket;
begin
  GAcceptDone := False;
  GAcceptResult := 0;

  LListener := NetTcpListen('127.0.0.1', 0);
  (LListener as ITcpSocketRuntime).SetBlocking(False);
  LListenerFd := PtrInt((LListener as ITcpSocketRuntime).NativeSocketHandle);

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Post async accept first }
  LSaLen := SizeOf(LSa);
  FillChar(LSa, SizeOf(LSa), 0);
  Check(LLoop.AsyncAccept(LListenerFd, @LSa, @LSaLen, 0, @AcceptCallback, nil),
    'AsyncAccept accepted');

  { Connect from client side }
  LClient := NetTcpConnect('127.0.0.1', LListener.LocalAddr.Port);

  LLoop.Schedule(TDuration.FromMilliseconds(500), @LoopStopCallback, nil);
  LLoop.Run;

  Check(GAcceptDone, 'accept completed');
  Check(GAcceptResult >= 0, 'accept result OK (fd >= 0)');
  { Clean up the accepted fd }
  if GAcceptResult >= 0 then
  begin
    LAcceptedFd.Value := cint(GAcceptResult);
    platform_socket_close(LAcceptedFd);
  end;

  GLoopRef := nil;
  LLoop.Close;
end;

{ === AsyncRecvTimeout success === }

var
  GTimeoutIoDone: Boolean = False;
  GTimeoutIoResult: Int32 = 0;

procedure RecvTimeoutCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GTimeoutIoDone := True;
  GTimeoutIoResult := AResult;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestAsyncLoopAsyncRecvTimeoutSuccess;
var
  LLoop: TAsyncLoop;
  LListener: ITcpListener;
  LClient: ITcpStream;
  LServer: ITcpStream;
  LSendBuf: array[0..3] of Byte;
  LRecvBuf: array[0..3] of Byte;
  LServerFd: PtrInt;
  LSent: SizeUInt;
begin
  GTimeoutIoDone := False;
  GTimeoutIoResult := 0;
  FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
  LSendBuf[0] := $DE; LSendBuf[1] := $AD;
  LSendBuf[2] := $BE; LSendBuf[3] := $EF;

  LListener := NetTcpListen('127.0.0.1', 0);
  LClient := NetTcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LServer := LListener.Accept;

  { Write data synchronously }
  LSent := LClient.Write(LSendBuf[0], 4);
  Check(LSent >= 4, 'wrote 4 bytes');

  { Set server non-blocking for async recv }
  (LServer as ITcpSocketRuntime).SetBlocking(False);
  LServerFd := PtrInt((LServer as ITcpSocketRuntime).NativeSocketHandle);

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { AsyncRecvTimeout with generous deadline — should succeed }
  Check(LLoop.AsyncRecvTimeout(LServerFd, @LRecvBuf[0], 4, 0,
    TDeadline.After(TDuration.FromSeconds(5)),
    @RecvTimeoutCallback, nil), 'AsyncRecvTimeout accepted');

  LLoop.Schedule(TDuration.FromMilliseconds(500), @LoopStopCallback, nil);
  LLoop.Run;

  Check(GTimeoutIoDone, 'recv completed');
  Check(GTimeoutIoResult >= 4, 'recv >= 4 bytes');
  CheckEqual(Int64($DE), Int64(LRecvBuf[0]), 'byte 0');
  CheckEqual(Int64($AD), Int64(LRecvBuf[1]), 'byte 1');
  CheckEqual(Int64($BE), Int64(LRecvBuf[2]), 'byte 2');
  CheckEqual(Int64($EF), Int64(LRecvBuf[3]), 'byte 3');

  GLoopRef := nil;
  LLoop.Close;
end;

{ === AsyncRecvTimeout expired (no data arrives, deadline passes) === }

procedure TestAsyncLoopAsyncRecvTimeoutExpired;
var
  LLoop: TAsyncLoop;
  LListener: ITcpListener;
  LClient: ITcpStream;
  LServer: ITcpStream;
  LRecvBuf: array[0..3] of Byte;
  LServerFd: PtrInt;
begin
  GTimeoutIoDone := False;
  GTimeoutIoResult := 0;
  FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);

  LListener := NetTcpListen('127.0.0.1', 0);
  LClient := NetTcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LServer := LListener.Accept;

  { Set server non-blocking }
  (LServer as ITcpSocketRuntime).SetBlocking(False);
  LServerFd := PtrInt((LServer as ITcpSocketRuntime).NativeSocketHandle);

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { AsyncRecvTimeout with very short deadline — no data will arrive }
  Check(LLoop.AsyncRecvTimeout(LServerFd, @LRecvBuf[0], 4, 0,
    TDeadline.After(TDuration.FromMilliseconds(50)),
    @RecvTimeoutCallback, nil), 'AsyncRecvTimeout accepted');

  LLoop.Schedule(TDuration.FromMilliseconds(500), @LoopStopCallback, nil);
  LLoop.Run;

  Check(GTimeoutIoDone, 'timeout callback fired');
  Check(GTimeoutIoResult < 0, 'result negative = timeout/cancel');

  GLoopRef := nil;
  LLoop.Close;
end;

{ === TPoller direct API tests === }

procedure TestPollerDirectCreateAndBackend;
var
  LPoller: TPoller;
  LDetected: TPollerBackend;
begin
  LPoller := TPoller.Create(32);
  Check(LPoller.IsValid, 'poller is valid after create');
  Check(LPoller.Backend <> pbUnsupported, 'backend is not unsupported');
  LDetected := PollerDetectBackend;
  Check(LPoller.Backend = LDetected, 'poller backend matches PollerDetectBackend');
  { PollerSupportsPositionedFileIO should not crash for any backend }
  PollerSupportsPositionedFileIO(LPoller.Backend);
  LPoller.Close;
end;

begin
  T := TTestRunner.Create('nextpas.core.async');

  T.Run('TimerHeapBasic', @TestTimerHeapBasic);
  T.Run('TimerHeapOrder', @TestTimerHeapOrder);
  T.Run('TimerHeapOrderByDeadline', @TestTimerHeapOrderByDeadline);
  T.Run('TimerCancel', @TestTimerCancel);
  T.Run('TimerCancelAfterFireIsStale', @TestTimerCancelAfterFireIsStale);
  T.Run('TimerCancelClearsOwnerRefsSourceContract',
    @TestTimerCancelClearsOwnerRefsSourceContract);
  T.Run('TimerCloseClearsOwnerRefsSourceContract',
    @TestTimerCloseClearsOwnerRefsSourceContract);
  T.Run('TimerNextDeadline', @TestTimerNextDeadline);
  T.Run('TimerHandleNone', @TestTimerHandleNone);
  T.Run('AsyncLoopCreate', @TestAsyncLoopCreate);
  T.Run('AsyncLoopTimer', @TestAsyncLoopTimer);
  T.Run('AsyncLoopMultiTimer', @TestAsyncLoopMultiTimer);
  T.Run('AsyncLoopStop', @TestAsyncLoopStop);
  T.Run('AsyncLoopStopWakesPlatformPollerSourceContract',
    @TestAsyncLoopStopWakesPlatformPollerSourceContract);
  T.Run('AsyncLoopIdleWaitUsesWakeDrivenTimeoutSourceContract',
    @TestAsyncLoopIdleWaitUsesWakeDrivenTimeoutSourceContract);
  T.Run('AsyncLoopPendingQueueMutexSourceContract',
    @TestAsyncLoopPendingQueueMutexSourceContract);
  T.Run('AsyncLoopIoSubmissionClosedStateSourceContract',
    @TestAsyncLoopIoSubmissionClosedStateSourceContract);
  T.Run('AsyncLoopExecutionClosedStateSourceContract',
    @TestAsyncLoopExecutionClosedStateSourceContract);
  T.Run('AsyncLoopRunOncePostWakeTimersBeforeIoSourceContract',
    @TestAsyncLoopRunOncePostWakeTimersBeforeIoSourceContract);
  T.Run('AsyncLoopTimerReadinessGuardSourceContract',
    @TestAsyncLoopTimerReadinessGuardSourceContract);
  T.Run('AsyncStressUsesCthreadsSourceContract',
    @TestAsyncStressUsesCthreadsSourceContract);
  T.Run('AsyncReadmeTruthMatrixSourceContract',
    @TestAsyncReadmeTruthMatrixSourceContract);
  T.Run('AsyncFacadeExportsTaskStateMachine',
    @TestAsyncFacadeExportsTaskStateMachine);
  T.Run('AsyncLoopTimerCancel', @TestAsyncLoopTimerCancel);
  T.Run('AsyncLoopIO', @TestAsyncLoopIO);
  T.Run('AsyncLoopPoll', @TestAsyncLoopPoll);
  T.Run('AsyncLoopPollDrainsPostBeforeExpiredTimer',
    @TestAsyncLoopPollDrainsPostBeforeExpiredTimer);
  T.Run('AsyncLoopRunStopFromPostStillFiresExpiredTimers',
    @TestAsyncLoopRunStopFromPostStillFiresExpiredTimers);
  T.Run('AsyncLoopRunOnceStopFromPostSkipsIoPoll',
    @TestAsyncLoopRunOnceStopFromPostSkipsIoPoll);
  T.Run('AsyncLoopScheduleAt', @TestAsyncLoopScheduleAt);
  T.Run('AsyncLoopAsyncRecvSend', @TestAsyncLoopAsyncRecvSend);
  T.Run('AsyncLoopAsyncRecv', @TestAsyncLoopAsyncRecv);
  T.Run('AsyncLoopAsyncAccept', @TestAsyncLoopAsyncAccept);
  T.Run('AsyncLoopAsyncRecvTimeoutSuccess',
    @TestAsyncLoopAsyncRecvTimeoutSuccess);
  T.Run('AsyncLoopAsyncRecvTimeoutExpired',
    @TestAsyncLoopAsyncRecvTimeoutExpired);
  T.Run('PollerDirectCreateAndBackend', @TestPollerDirectCreateAndBackend);

  T.Summary;
end.
