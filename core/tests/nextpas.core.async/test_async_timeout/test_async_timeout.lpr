program test_async_timeout;

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
  nextpas.core.async.task,
  nextpas.core.async.timer,
  nextpas.core.async.loop,
  nextpas.core.io.poller;

var
  T: TTestRunner;

{ === Shared state === }

var
  GLoopRef: ^TAsyncLoop;
  GCallCount: Int32 = 0;
  GIoResult: Int32 = 0;
  GIoDone: Boolean = False;
  GTaskCallbackFired: Boolean = False;

procedure ResetState;
begin
  GCallCount := 0;
  GIoResult := 0;
  GIoDone := False;
  GTaskCallbackFired := False;
end;

procedure StopLoopCallback(AContext: Pointer);
begin
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure IoCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GCallCount);
  GIoResult := AResult;
  GIoDone := True;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

{ === Test 1: AsyncSleep === }

var
  GSleepFired: Boolean = False;

procedure SleepCallback(AContext: Pointer);
begin
  GSleepFired := True;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestAsyncSleep;
var
  LLoop: TAsyncLoop;
begin
  GSleepFired := False;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  LLoop.AsyncSleep(TDuration.FromMilliseconds(20), @SleepCallback, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopLoopCallback, nil);
  LLoop.Run;

  Check(GSleepFired, 'sleep callback fired');
  GLoopRef := nil;
  LLoop.Close;
end;

{ === Test 2: ReadSuccess === }

procedure TestReadSuccess;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf: array[0..3] of Byte;
begin
  ResetState;
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);
  LWriteBuf[0] := $CA; LWriteBuf[1] := $FE;
  LWriteBuf[2] := $BA; LWriteBuf[3] := $BE;

  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Write data first }
  LLoop.AsyncWrite(LPipe.WriteFd, @LWriteBuf[0], 4, -1, nil, nil);
  { Read with long deadline — should succeed }
  LLoop.AsyncReadTimeout(LPipe.ReadFd, @LReadBuf[0], 4, -1,
    TDeadline.After(TDuration.FromSeconds(5)), @IoCallback, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopLoopCallback, nil);
  LLoop.Run;

  Check(GIoDone, 'read completed');
  Check(GIoResult > 0, 'read returned positive bytes');
  CheckEqual(Int64($CA), Int64(LReadBuf[0]), 'byte 0');
  CheckEqual(Int64($FE), Int64(LReadBuf[1]), 'byte 1');
  CheckEqual(Int64($BA), Int64(LReadBuf[2]), 'byte 2');
  CheckEqual(Int64($BE), Int64(LReadBuf[3]), 'byte 3');

  GLoopRef := nil;
  LLoop.Close;
  platform_pipe_close(LPipe);
end;

{ === Test 3: ReadTimeout === }

procedure TestReadTimeout;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LReadBuf: array[0..63] of Byte;
begin
  ResetState;
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);

  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Read on empty pipe with 50ms deadline — should timeout }
  LLoop.AsyncReadTimeout(LPipe.ReadFd, @LReadBuf[0], 64, -1,
    TDeadline.After(TDuration.FromMilliseconds(50)), @IoCallback, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopLoopCallback, nil);
  LLoop.Run;

  Check(GIoDone, 'callback fired');
  CheckEqual(Int64(-110), Int64(GIoResult), 'result is -ETIMEDOUT');

  { Close write end to unblock pending read, then drain to free TTimeoutCtx }
  platform_pipe_close_write(LPipe);
  LLoop.Poll;

  GLoopRef := nil;
  LLoop.Close;
  platform_pipe_close(LPipe);
end;

{ === Test 4: WriteSuccess === }

var
  GWriteResult: Int32 = 0;
  GWriteDone: Boolean = False;

procedure WriteCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GWriteResult := AResult;
  GWriteDone := True;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestWriteSuccess;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteBuf: array[0..3] of Byte;
begin
  GWriteResult := 0;
  GWriteDone := False;
  LWriteBuf[0] := $11; LWriteBuf[1] := $22;
  LWriteBuf[2] := $33; LWriteBuf[3] := $44;

  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Write with long deadline — pipe is writable so should succeed }
  LLoop.AsyncWriteTimeout(LPipe.WriteFd, @LWriteBuf[0], 4, -1,
    TDeadline.After(TDuration.FromSeconds(5)), @WriteCallback, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopLoopCallback, nil);
  LLoop.Run;

  Check(GWriteDone, 'write completed');
  Check(GWriteResult > 0, 'write returned positive bytes');
  CheckEqual(Int64(4), Int64(GWriteResult), 'wrote 4 bytes');

  GLoopRef := nil;
  LLoop.Close;
  platform_pipe_close(LPipe);
end;

{ === Test 5: NoDoubleFire === }

var
  GDoubleFireCount: Int32 = 0;

procedure DoubleFireCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GDoubleFireCount);
end;

procedure TestNoDoubleFire;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf: array[0..3] of Byte;
begin
  GDoubleFireCount := 0;
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);
  LWriteBuf[0] := $AA; LWriteBuf[1] := $BB;
  LWriteBuf[2] := $CC; LWriteBuf[3] := $DD;

  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Write data so read completes fast }
  LLoop.AsyncWrite(LPipe.WriteFd, @LWriteBuf[0], 4, -1, nil, nil);
  { Read with 200ms deadline — I/O should complete well before timeout }
  LLoop.AsyncReadTimeout(LPipe.ReadFd, @LReadBuf[0], 4, -1,
    TDeadline.After(TDuration.FromMilliseconds(200)), @DoubleFireCallback, nil);
  { Run loop for 300ms total to ensure timer doesn't fire after I/O }
  LLoop.Schedule(TDuration.FromMilliseconds(300), @StopLoopCallback, nil);
  LLoop.Run;

  CheckEqual(Int64(1), Int64(GDoubleFireCount), 'callback fired exactly once');

  GLoopRef := nil;
  LLoop.Close;
  platform_pipe_close(LPipe);
end;

{ === Test 6: InfiniteDeadline === }

procedure TestInfiniteDeadline;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf: array[0..3] of Byte;
begin
  ResetState;
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);
  LWriteBuf[0] := $01; LWriteBuf[1] := $02;
  LWriteBuf[2] := $03; LWriteBuf[3] := $04;

  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Write data }
  LLoop.AsyncWrite(LPipe.WriteFd, @LWriteBuf[0], 4, -1, nil, nil);
  { Read with Infinite deadline — bypasses timeout mechanism entirely }
  LLoop.AsyncReadTimeout(LPipe.ReadFd, @LReadBuf[0], 4, -1,
    TDeadline.Infinite, @IoCallback, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopLoopCallback, nil);
  LLoop.Run;

  Check(GIoDone, 'read completed with infinite deadline');
  Check(GIoResult > 0, 'read returned positive bytes');
  CheckEqual(Int64($01), Int64(LReadBuf[0]), 'byte 0');

  GLoopRef := nil;
  LLoop.Close;
  platform_pipe_close(LPipe);
end;

{ === Test 7: MultipleTimeouts === }

var
  GMultiResults: array[0..2] of Int32;
  GMultiDone: array[0..2] of Boolean;

procedure MultiCallback0(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GMultiResults[0] := AResult;
  GMultiDone[0] := True;
end;

procedure MultiCallback1(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GMultiResults[1] := AResult;
  GMultiDone[1] := True;
end;

procedure MultiCallback2(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GMultiResults[2] := AResult;
  GMultiDone[2] := True;
end;

procedure TestMultipleTimeouts;
var
  LLoop: TAsyncLoop;
  LPipe0, LPipe1, LPipe2: TPlatformPipe;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf0, LReadBuf1, LReadBuf2: array[0..3] of Byte;
begin
  GMultiResults[0] := 0; GMultiResults[1] := 0; GMultiResults[2] := 0;
  GMultiDone[0] := False; GMultiDone[1] := False; GMultiDone[2] := False;
  FillChar(LReadBuf0, SizeOf(LReadBuf0), 0);
  FillChar(LReadBuf1, SizeOf(LReadBuf1), 0);
  FillChar(LReadBuf2, SizeOf(LReadBuf2), 0);
  LWriteBuf[0] := $FF; LWriteBuf[1] := $EE;
  LWriteBuf[2] := $DD; LWriteBuf[3] := $CC;

  if platform_pipe_create(LPipe0) <> 0 then begin Fail('pipe0 failed'); Exit; end;
  if platform_pipe_create(LPipe1) <> 0 then begin platform_pipe_close(LPipe0); Fail('pipe1 failed'); Exit; end;
  if platform_pipe_create(LPipe2) <> 0 then begin platform_pipe_close(LPipe0); platform_pipe_close(LPipe1); Fail('pipe2 failed'); Exit; end;

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Pipe0: has data — should succeed }
  LLoop.AsyncWrite(LPipe0.WriteFd, @LWriteBuf[0], 4, -1, nil, nil);
  LLoop.AsyncReadTimeout(LPipe0.ReadFd, @LReadBuf0[0], 4, -1,
    TDeadline.After(TDuration.FromMilliseconds(200)), @MultiCallback0, nil);

  { Pipe1: no data, 50ms timeout }
  LLoop.AsyncReadTimeout(LPipe1.ReadFd, @LReadBuf1[0], 4, -1,
    TDeadline.After(TDuration.FromMilliseconds(50)), @MultiCallback1, nil);

  { Pipe2: no data, 100ms timeout }
  LLoop.AsyncReadTimeout(LPipe2.ReadFd, @LReadBuf2[0], 4, -1,
    TDeadline.After(TDuration.FromMilliseconds(100)), @MultiCallback2, nil);

  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopLoopCallback, nil);
  LLoop.Run;

  Check(GMultiDone[0], 'pipe0 callback fired');
  Check(GMultiResults[0] > 0, 'pipe0 read succeeded');
  Check(GMultiDone[1], 'pipe1 callback fired');
  CheckEqual(Int64(-110), Int64(GMultiResults[1]), 'pipe1 timed out');
  Check(GMultiDone[2], 'pipe2 callback fired');
  CheckEqual(Int64(-110), Int64(GMultiResults[2]), 'pipe2 timed out');

  { Close write ends to unblock pending reads, then drain to free TTimeoutCtx }
  platform_pipe_close_write(LPipe1);
  platform_pipe_close_write(LPipe2);
  LLoop.Poll;

  GLoopRef := nil;
  LLoop.Close;
  platform_pipe_close(LPipe0);
  platform_pipe_close(LPipe1);
  platform_pipe_close(LPipe2);
end;

{ === Test 8: ZeroTimeout === }

procedure TestZeroTimeout;
var
  LLoop: TAsyncLoop;
  LPipe: TPlatformPipe;
  LReadBuf: array[0..63] of Byte;
begin
  ResetState;
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);

  if platform_pipe_create(LPipe) <> 0 then
  begin
    Fail('pipe creation failed');
    Exit;
  end;

  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;

  { Read with zero timeout — should timeout immediately }
  LLoop.AsyncReadTimeout(LPipe.ReadFd, @LReadBuf[0], 64, -1,
    TDeadline.After(TDuration.Zero), @IoCallback, nil);
  { Safety timeout }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopLoopCallback, nil);
  LLoop.Run;

  Check(GIoDone, 'callback fired');
  CheckEqual(Int64(-110), Int64(GIoResult), 'zero timeout gives -ETIMEDOUT');

  { Close write end to unblock pending read, then drain to free TTimeoutCtx }
  platform_pipe_close_write(LPipe);
  LLoop.Poll;

  GLoopRef := nil;
  LLoop.Close;
  platform_pipe_close(LPipe);
end;

{ === Test 9: TaskStatus === }

procedure TestTaskStatus;
var
  LTask: TAsyncTask;
begin
  LTask := TAsyncTask.Create;
  CheckEqual(Int64(Ord(atsIdle)), Int64(Ord(LTask.Status)), 'initial status is Idle');
  Check(not LTask.IsDone, 'not done initially');

  LTask.Complete(42);
  CheckEqual(Int64(Ord(atsCompleted)), Int64(Ord(LTask.Status)), 'status is Completed');
  Check(LTask.IsCompleted, 'IsCompleted true');
  Check(LTask.IsDone, 'IsDone true');
  CheckEqual(Int64(42), Int64(LTask.GetResult), 'result is 42');

  { Double complete should be ignored }
  LTask.Complete(99);
  CheckEqual(Int64(42), Int64(LTask.GetResult), 'result unchanged after double complete');

  { Test Fail }
  LTask := TAsyncTask.Create;
  LTask.Fail(-1);
  CheckEqual(Int64(Ord(atsFailed)), Int64(Ord(LTask.Status)), 'status is Failed');
  Check(LTask.IsDone, 'IsDone after fail');
  CheckEqual(Int64(-1), Int64(LTask.GetResult), 'fail result');

  { Test Timeout }
  LTask := TAsyncTask.Create;
  LTask.Timeout;
  CheckEqual(Int64(Ord(atsTimedOut)), Int64(Ord(LTask.Status)), 'status is TimedOut');
  CheckEqual(Int64(-110), Int64(LTask.GetResult), 'timeout result is -110');

  { Test Cancel }
  LTask := TAsyncTask.Create;
  LTask.Cancel;
  CheckEqual(Int64(Ord(atsCancelled)), Int64(Ord(LTask.Status)), 'status is Cancelled');
  Check(LTask.IsDone, 'IsDone after cancel');
end;

{ === Test 10: TaskCallback === }

procedure TaskOnCompleteCallback(AContext: Pointer);
begin
  GTaskCallbackFired := True;
end;

procedure TestTaskCallback;
var
  LTask: TAsyncTask;
begin
  GTaskCallbackFired := False;
  LTask := TAsyncTask.Create;
  LTask.OnComplete(@TaskOnCompleteCallback, nil);
  Check(not GTaskCallbackFired, 'callback not fired before complete');

  LTask.Complete(7);
  Check(GTaskCallbackFired, 'callback fired on complete');

  { Verify callback does not fire again on redundant complete }
  GTaskCallbackFired := False;
  LTask.Complete(8);
  Check(not GTaskCallbackFired, 'callback not fired on redundant complete');
end;

{ === Main === }

begin
  T := TTestRunner.Create('nextpas.core.async.timeout');

  T.Run('AsyncSleep', @TestAsyncSleep);
  T.Run('ReadSuccess', @TestReadSuccess);
  T.Run('ReadTimeout', @TestReadTimeout);
  T.Run('WriteSuccess', @TestWriteSuccess);
  T.Run('NoDoubleFire', @TestNoDoubleFire);
  T.Run('InfiniteDeadline', @TestInfiniteDeadline);
  T.Run('MultipleTimeouts', @TestMultipleTimeouts);
  T.Run('ZeroTimeout', @TestZeroTimeout);
  T.Run('TaskStatus', @TestTaskStatus);
  T.Run('TaskCallback', @TestTaskCallback);

  T.Summary;
end.
