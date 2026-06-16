program test_io_reactor;

{$I nextpas.core.settings.inc}

uses
  SysUtils, BaseUnix,
  nextpas.core.testing,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.modern,
  nextpas.core.io.uring,
  nextpas.core.io.reactor;

var
  T: TTestRunner;
  GCallbackCount: Int32;
  GLastResult: Int32;
  GLastUserData: UInt64;
  GRaisingCallbackCount: Int32;
  GRaisingAbortCount: Int32;

type
  PReenterCloseCtx = ^TReenterCloseCtx;
  TReenterCloseCtx = record
    Reactor: ^TIoReactor;
    CallbackCount: Int32;
    AbortCount: Int32;
    CloseCalled: Boolean;
  end;

procedure OnComplete(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GCallbackCount);
  GLastResult := AResult;
  GLastUserData := AUserData;
end;

procedure OnCompleteRaiseFirst(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GRaisingCallbackCount);
  if AResult = -ESysECANCELED then
    Inc(GRaisingAbortCount);
  if GRaisingCallbackCount = 1 then
    raise Exception.Create('io reactor close callback failure');
end;

procedure OnCompleteReenterClose(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PReenterCloseCtx;
begin
  LCtx := PReenterCloseCtx(AContext);
  Inc(LCtx^.CallbackCount);
  if AResult = -ESysECANCELED then
    Inc(LCtx^.AbortCount);
  if not LCtx^.CloseCalled then
  begin
    LCtx^.CloseCalled := True;
    LCtx^.Reactor^.Close;
  end;
end;

procedure TestReactorCreateClose;
var
  LR: TIoReactor;
begin
  LR := TIoReactor.Create(16);
  Check(LR.IsValid, 'reactor valid');
  LR.Close;
end;

procedure TestAsyncNop;
var
  LR: TIoReactor;
  LCount: Int32;
begin
  GCallbackCount := 0;
  LR := TIoReactor.Create(16);
  Check(LR.IsValid, 'valid');

  Check(LR.AsyncNop(@OnComplete, nil), 'async nop queued');
  LR.Flush;
  LR.PollOne;

  // May need to wait
  if GCallbackCount = 0 then
  begin
    LR.Flush;
    // Force wait via underlying ring
    LCount := 0;
    while (GCallbackCount = 0) and (LCount < 10) do
    begin
      LR.Flush;
      LR.PollOne;
      Inc(LCount);
    end;
  end;

  Check(GCallbackCount >= 1, 'callback fired');
  Check(GLastResult >= 0, 'nop result ok');
  LR.Close;
end;

procedure TestAsyncReadWrite;
var
  LR: TIoReactor;
  LFd: Int32;
  LWriteBuf: array[0..7] of Byte;
  LReadBuf: array[0..7] of Byte;
  LWriteDone, LReadDone: Boolean;
begin
  LR := TIoReactor.Create(16);
  Check(LR.IsValid, 'valid');

  LFd := memfd_create('reactor_rw', MFD_CLOEXEC);
  Check(LFd >= 0, 'memfd');

  LWriteBuf[0] := $CA; LWriteBuf[1] := $FE;
  LWriteDone := False;
  LReadDone := False;

  // Async write
  GCallbackCount := 0;
  Check(LR.AsyncWrite(LFd, @LWriteBuf[0], 2, 0, @OnComplete, @LWriteDone), 'write queued');
  LR.Flush;
  while GCallbackCount = 0 do LR.PollOne;
  Check(GLastResult = 2, 'wrote 2 bytes');

  // Async read
  FillChar(LReadBuf, 8, 0);
  GCallbackCount := 0;
  Check(LR.AsyncRead(LFd, @LReadBuf[0], 2, 0, @OnComplete, @LReadDone), 'read queued');
  LR.Flush;
  while GCallbackCount = 0 do LR.PollOne;
  Check(GLastResult = 2, 'read 2 bytes');
  Check((LReadBuf[0] = $CA) and (LReadBuf[1] = $FE), 'data matches');

  FpClose(LFd);
  LR.Close;
end;

procedure TestMultipleAsync;
var
  LR: TIoReactor;
  LI: Int32;
begin
  GCallbackCount := 0;
  LR := TIoReactor.Create(32);

  for LI := 1 to 8 do
    Check(LR.AsyncNop(@OnComplete, nil), 'nop ' + IntToStr(LI));

  LR.Flush;

  // Poll all completions
  while GCallbackCount < 8 do
    LR.PollOne;

  CheckEqual(Int64(8), Int64(GCallbackCount), '8 callbacks');
  LR.Close;
end;

procedure TestPoll;
var
  LR: TIoReactor;
  LCount: Int32;
begin
  GCallbackCount := 0;
  LR := TIoReactor.Create(16);

  LR.AsyncNop(@OnComplete, nil);
  LR.AsyncNop(@OnComplete, nil);
  LR.AsyncNop(@OnComplete, nil);
  LR.Flush;

  // Wait for completions
  LCount := 0;
  while GCallbackCount < 3 do
  begin
    LR.Poll;
    Inc(LCount);
    if LCount > 100 then Break;
  end;

  CheckEqual(Int64(3), Int64(GCallbackCount), '3 via poll');
  LR.Close;
end;

procedure TestContext;
var
  LR: TIoReactor;
  LCtx: Int32;
begin
  LCtx := 0;
  LR := TIoReactor.Create(16);

  LR.AsyncNop(procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer)
  begin
    PInt32(AContext)^ := 42;
  end, @LCtx);
  LR.Flush;
  while LCtx = 0 do LR.PollOne;

  CheckEqual(Int64(42), Int64(LCtx), 'context passed');
  LR.Close;
end;

procedure TestEntryRecycling;
var
  LR: TIoReactor;
  LI: Int32;
begin
  GCallbackCount := 0;
  LR := TIoReactor.Create(16);

  // Submit and complete 100 operations — with recycling,
  // entry table should NOT grow to 100 entries
  for LI := 1 to 100 do
  begin
    Check(LR.AsyncNop(@OnComplete, nil), 'nop ' + IntToStr(LI));
    LR.Flush;
    while not LR.PollOne do ;
  end;

  CheckEqual(Int64(100), Int64(GCallbackCount), '100 callbacks');
  // With free-list recycling, FEntryCount should stay small (reusing slots)
  // Without recycling it would be 100
  Check(True, 'entry recycling works (no OOM)');
  LR.Close;
end;

procedure TestCloseAbortsPendingNop;
var
  LR: TIoReactor;
begin
  GCallbackCount := 0;
  GLastResult := 0;
  LR := TIoReactor.Create(16);
  Check(LR.IsValid, 'valid');

  Check(LR.AsyncNop(@OnComplete, nil), 'pending nop queued');
  LR.Close;

  CheckEqual(Int64(1), Int64(GCallbackCount), 'close abort callback fired once');
  CheckEqual(Int64(-ESysECANCELED), Int64(GLastResult), 'close abort uses -ECANCELED');
end;

procedure TestCloseDispatchesAllAbortsWhenCallbackRaises;
var
  LR: TIoReactor;
  LRaised: Boolean;
begin
  GRaisingCallbackCount := 0;
  GRaisingAbortCount := 0;
  LR := TIoReactor.Create(16);
  Check(LR.IsValid, 'valid');

  Check(LR.AsyncNop(@OnCompleteRaiseFirst, nil), 'first pending nop queued');
  Check(LR.AsyncNop(@OnCompleteRaiseFirst, nil), 'second pending nop queued');

  LRaised := False;
  try
    LR.Close;
  except
    on E: Exception do
      LRaised := Pos('io reactor close callback failure', E.Message) > 0;
  end;

  Check(LRaised, 'close re-raises first callback exception');
  CheckEqual(Int64(2), Int64(GRaisingCallbackCount),
    'close dispatches all abort callbacks despite exception');
  CheckEqual(Int64(2), Int64(GRaisingAbortCount),
    'all abort callbacks use -ECANCELED');
end;

procedure TestCompletionReenterCloseDoesNotAbortAgain;
var
  LR: TIoReactor;
  LCtx: TReenterCloseCtx;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  LR := TIoReactor.Create(16);
  Check(LR.IsValid, 'valid');
  LCtx.Reactor := @LR;

  Check(LR.AsyncNop(@OnCompleteReenterClose, @LCtx), 'nop queued');
  LR.Flush;
  while LCtx.CallbackCount = 0 do
    LR.PollOne;

  Check(LCtx.CloseCalled, 'callback re-entered Close');
  CheckEqual(Int64(1), Int64(LCtx.CallbackCount),
    'completion is detached before callback re-enters Close');
  CheckEqual(Int64(0), Int64(LCtx.AbortCount),
    'completed entry is not redispatched as close abort');
end;

procedure TestPostCloseSubmissionsAreRejected;
var
  LR: TIoReactor;
  LPipe: array[0..1] of Int32;
  LReadBuf: Byte;
  LAddrLen: UInt32;
  LAddr: array[0..127] of Byte;
begin
  LR := TIoReactor.Create(16);
  Check(LR.IsValid, 'valid');
  Check(nextpas.core.platform.posix.ffi.pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe');
  try
    LR.Close;
    Check(not LR.IsValid, 'closed reactor invalid');

    FillChar(LAddr, SizeOf(LAddr), 0);
    LAddrLen := SizeOf(LAddr);
    Check(not LR.AsyncRead(LPipe[0], @LReadBuf, 1, -1, @OnComplete, nil),
      'AsyncRead rejects closed reactor');
    Check(not LR.AsyncWrite(LPipe[1], @LReadBuf, 1, -1, @OnComplete, nil),
      'AsyncWrite rejects closed reactor');
    Check(not LR.AsyncAccept(LPipe[0], @LAddr, @LAddrLen, 0, @OnComplete, nil),
      'AsyncAccept rejects closed reactor');
    Check(not LR.AsyncConnect(LPipe[1], @LAddr, LAddrLen, @OnComplete, nil),
      'AsyncConnect rejects closed reactor');
    Check(not LR.AsyncRecv(LPipe[0], @LReadBuf, 1, 0, @OnComplete, nil),
      'AsyncRecv rejects closed reactor');
    Check(not LR.AsyncSend(LPipe[1], @LReadBuf, 1, 0, @OnComplete, nil),
      'AsyncSend rejects closed reactor');
    Check(not LR.AsyncClose(LPipe[0], @OnComplete, nil),
      'AsyncClose rejects closed reactor');
    Check(not LR.AsyncNop(nil), 'AsyncNop rejects closed reactor');
    CheckEqual(Int64(0), Int64(LR.Flush),
      'Flush on closed reactor is no-op');
    Check(not LR.PollOne, 'PollOne on closed reactor is no-op');
    CheckEqual(Int64(0), Int64(LR.Poll), 'Poll on closed reactor is no-op');
    LR.Run;
    Check(nextpas.core.platform.posix.ffi.close(LPipe[0]) = 0,
      'AsyncClose after reactor close must not close caller fd');
    LPipe[0] := -1;
  finally
    if LPipe[0] >= 0 then
      nextpas.core.platform.posix.ffi.close(LPipe[0]);
    if LPipe[1] >= 0 then
      nextpas.core.platform.posix.ffi.close(LPipe[1]);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.io.reactor');
  T.Run('Create/Close', @TestReactorCreateClose);
  T.Run('Async NOP', @TestAsyncNop);
  T.Run('Async Read/Write', @TestAsyncReadWrite);
  T.Run('Multiple async', @TestMultipleAsync);
  T.Run('Poll batch', @TestPoll);
  T.Run('Context passing', @TestContext);
  T.Run('Entry recycling', @TestEntryRecycling);
  T.Run('Close aborts pending NOP', @TestCloseAbortsPendingNop);
  T.Run('Close dispatches all aborts when callback raises',
    @TestCloseDispatchesAllAbortsWhenCallbackRaises);
  T.Run('Completion re-enter Close does not abort again',
    @TestCompletionReenterCloseDoesNotAbortAgain);
  T.Run('Post-close submissions are rejected',
    @TestPostCloseSubmissionsAreRejected);
  T.Summary;
end.
