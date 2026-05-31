program test_epoll_reactor;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi,
  nextpas.core.io.reactor.epoll;

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

procedure TestCreateClose;
var
  LR: TEpollReactor;
begin
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'reactor valid');
  LR.Close;
end;

procedure TestAsyncReadWrite;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LWriteBuf: array[0..7] of Byte;
  LReadBuf: array[0..7] of Byte;
  LCount: Int32;
begin
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');

  { Create a pipe for testing }
  Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe2');

  { Write some data to the pipe first (synchronously) so read has data }
  LWriteBuf[0] := $CA; LWriteBuf[1] := $FE;
  Check(nextpas.core.platform.posix.ffi.write(LPipe[1], @LWriteBuf[0], 2) = 2, 'sync write');

  { Async read from pipe read-end }
  FillChar(LReadBuf, 8, 0);
  GCallbackCount := 0;
  Check(LR.AsyncRead(LPipe[0], @LReadBuf[0], 2, -1, @OnComplete, nil), 'read queued');

  LCount := 0;
  while (GCallbackCount = 0) and (LCount < 100) do
  begin
    LR.PollOne;
    Inc(LCount);
  end;

  Check(GCallbackCount >= 1, 'read callback fired');
  Check(GLastResult = 2, 'read 2 bytes');
  Check((LReadBuf[0] = $CA) and (LReadBuf[1] = $FE), 'data matches');

  { Async write to pipe write-end }
  LWriteBuf[0] := $DE; LWriteBuf[1] := $AD;
  GCallbackCount := 0;
  Check(LR.AsyncWrite(LPipe[1], @LWriteBuf[0], 2, -1, @OnComplete, nil), 'write queued');

  LCount := 0;
  while (GCallbackCount = 0) and (LCount < 100) do
  begin
    LR.PollOne;
    Inc(LCount);
  end;

  Check(GCallbackCount >= 1, 'write callback fired');
  Check(GLastResult = 2, 'wrote 2 bytes');

  nextpas.core.platform.posix.ffi.close(LPipe[0]);
  nextpas.core.platform.posix.ffi.close(LPipe[1]);
  LR.Close;
end;

procedure TestMultipleAsync;
var
  LR: TEpollReactor;
  LPipes: array[0..7, 0..1] of Int32;
  LBufs: array[0..7] of Byte;
  LReadBufs: array[0..7] of Byte;
  LI, LCount: Int32;
begin
  GCallbackCount := 0;
  LR := TEpollReactor.Create(32);

  { Create 8 pipes, write 1 byte to each, then async read all }
  for LI := 0 to 7 do
  begin
    Check(pipe2(@LPipes[LI][0], O_CLOEXEC) = 0, 'pipe ' + IntToStr(LI));
    LBufs[LI] := Byte(LI + 10);
    Check(nextpas.core.platform.posix.ffi.write(LPipes[LI][1], @LBufs[LI], 1) = 1,
      'write pipe ' + IntToStr(LI));
  end;

  FillChar(LReadBufs, 8, 0);
  for LI := 0 to 7 do
    Check(LR.AsyncRead(LPipes[LI][0], @LReadBufs[LI], 1, -1, @OnComplete, nil),
      'async read ' + IntToStr(LI));

  LCount := 0;
  while (GCallbackCount < 8) and (LCount < 200) do
  begin
    LR.Poll;
    Inc(LCount);
  end;

  CheckEqual(Int64(8), Int64(GCallbackCount), '8 callbacks');

  for LI := 0 to 7 do
  begin
    Check(LReadBufs[LI] = Byte(LI + 10), 'data[' + IntToStr(LI) + ']');
    nextpas.core.platform.posix.ffi.close(LPipes[LI][0]);
    nextpas.core.platform.posix.ffi.close(LPipes[LI][1]);
  end;

  LR.Close;
end;

procedure TestPollBatch;
var
  LR: TEpollReactor;
  LPipes: array[0..2, 0..1] of Int32;
  LBufs: array[0..2] of Byte;
  LReadBufs: array[0..2] of Byte;
  LI, LCount, LTotal: Int32;
begin
  GCallbackCount := 0;
  LR := TEpollReactor.Create(16);

  for LI := 0 to 2 do
  begin
    Check(pipe2(@LPipes[LI][0], O_CLOEXEC) = 0, 'pipe');
    LBufs[LI] := Byte(LI + 20);
    nextpas.core.platform.posix.ffi.write(LPipes[LI][1], @LBufs[LI], 1);
  end;

  FillChar(LReadBufs, 3, 0);
  for LI := 0 to 2 do
    LR.AsyncRead(LPipes[LI][0], @LReadBufs[LI], 1, -1, @OnComplete, nil);

  LCount := 0;
  LTotal := 0;
  while (GCallbackCount < 3) and (LCount < 100) do
  begin
    LTotal := LTotal + LR.Poll;
    Inc(LCount);
  end;

  CheckEqual(Int64(3), Int64(GCallbackCount), '3 via poll batch');

  for LI := 0 to 2 do
  begin
    nextpas.core.platform.posix.ffi.close(LPipes[LI][0]);
    nextpas.core.platform.posix.ffi.close(LPipes[LI][1]);
  end;
  LR.Close;
end;

procedure TestContext;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LBuf: Byte;
  LCtx: Int32;
  LCount: Int32;
begin
  LCtx := 0;
  LR := TEpollReactor.Create(16);

  Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe');
  LBuf := $FF;
  nextpas.core.platform.posix.ffi.write(LPipe[1], @LBuf, 1);

  LR.AsyncRead(LPipe[0], @LBuf, 1, -1,
    procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer)
    begin
      PInt32(AContext)^ := 42;
    end, @LCtx);

  LCount := 0;
  while (LCtx = 0) and (LCount < 100) do
  begin
    LR.PollOne;
    Inc(LCount);
  end;

  CheckEqual(Int64(42), Int64(LCtx), 'context passed');

  nextpas.core.platform.posix.ffi.close(LPipe[0]);
  nextpas.core.platform.posix.ffi.close(LPipe[1]);
  LR.Close;
end;

procedure TestEntryRecycling;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LWriteBuf, LReadBuf: Byte;
  LI, LCount: Int32;
begin
  GCallbackCount := 0;
  LR := TEpollReactor.Create(16);

  { Submit and complete 50 operations with recycling }
  for LI := 1 to 50 do
  begin
    Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe ' + IntToStr(LI));
    LWriteBuf := Byte(LI);
    nextpas.core.platform.posix.ffi.write(LPipe[1], @LWriteBuf, 1);

    LReadBuf := 0;
    Check(LR.AsyncRead(LPipe[0], @LReadBuf, 1, -1, @OnComplete, nil),
      'async ' + IntToStr(LI));

    LCount := 0;
    while not LR.PollOne do
    begin
      Inc(LCount);
      if LCount > 100 then Break;
    end;

    nextpas.core.platform.posix.ffi.close(LPipe[0]);
    nextpas.core.platform.posix.ffi.close(LPipe[1]);
  end;

  CheckEqual(Int64(50), Int64(GCallbackCount), '50 callbacks');
  Check(True, 'entry recycling works (no OOM)');
  LR.Close;
end;

begin
  T := TTestRunner.Create('nextpas.core.io.reactor.epoll');
  T.Run('Create/Close', @TestCreateClose);
  T.Run('Async Read/Write', @TestAsyncReadWrite);
  T.Run('Multiple async', @TestMultipleAsync);
  T.Run('Poll batch', @TestPollBatch);
  T.Run('Context passing', @TestContext);
  T.Run('Entry recycling', @TestEntryRecycling);
  T.Summary;
end.