program test_io_reactor;

{$I nextpas.core.settings.inc}

uses
  SysUtils, BaseUnix,
  nextpas.core.testing,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.modern,
  nextpas.core.io.uring,
  nextpas.core.io.reactor;

var
  T: TTestRunner;
  GCallbackCount: Int32;
  GLastResult: Int32;
  GLastUserData: UInt64;

procedure OnComplete(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GCallbackCount);
  GLastResult := AResult;
  GLastUserData := AUserData;
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

begin
  T := TTestRunner.Create('nextpas.core.io.reactor');
  T.Run('Create/Close', @TestReactorCreateClose);
  T.Run('Async NOP', @TestAsyncNop);
  T.Run('Async Read/Write', @TestAsyncReadWrite);
  T.Run('Multiple async', @TestMultipleAsync);
  T.Run('Poll batch', @TestPoll);
  T.Run('Context passing', @TestContext);
  T.Summary;
end.
