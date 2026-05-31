program test_async;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.time.cpu,
  nextpas.core.platform.pipe,
  nextpas.core.platform.posix.ffi,
  nextpas.core.async.base,
  nextpas.core.async.timer,
  nextpas.core.async.loop,
  nextpas.core.io.poller;

var
  T: TTestRunner;

{ === Timer Heap Tests === }

var
  GCallCount: Int32 = 0;
  GCallOrder: array[0..15] of Int32;

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

begin
  T := TTestRunner.Create('nextpas.core.async');

  T.Run('TimerHeapBasic', @TestTimerHeapBasic);
  T.Run('TimerHeapOrder', @TestTimerHeapOrder);
  T.Run('TimerHeapOrderByDeadline', @TestTimerHeapOrderByDeadline);
  T.Run('TimerCancel', @TestTimerCancel);
  T.Run('TimerNextDeadline', @TestTimerNextDeadline);
  T.Run('TimerHandleNone', @TestTimerHandleNone);
  T.Run('AsyncLoopCreate', @TestAsyncLoopCreate);
  T.Run('AsyncLoopTimer', @TestAsyncLoopTimer);
  T.Run('AsyncLoopMultiTimer', @TestAsyncLoopMultiTimer);
  T.Run('AsyncLoopStop', @TestAsyncLoopStop);
  T.Run('AsyncLoopTimerCancel', @TestAsyncLoopTimerCancel);
  T.Run('AsyncLoopIO', @TestAsyncLoopIO);
  T.Run('AsyncLoopPoll', @TestAsyncLoopPoll);

  T.Summary;
end.
