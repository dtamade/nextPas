program test_epoll_reactor;

{$I nextpas.core.settings.inc}

uses
  Classes,
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
  GCloseCallbackCount: Int32;
  GLastCloseResult: Int32;
  GRaisingCallbackCount: Int32;
  GRaisingAbortCount: Int32;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandFileName('../../../' + ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

procedure CheckSourceContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckSourceAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

type
  PReenterCloseCtx = ^TReenterCloseCtx;
  TReenterCloseCtx = record
    Reactor: ^TEpollReactor;
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

procedure OnCloseComplete(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GCloseCallbackCount);
  GLastCloseResult := AResult;
end;

procedure OnCompleteRaiseFirst(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GRaisingCallbackCount);
  if AResult = -ESysECANCELED then
    Inc(GRaisingAbortCount);
  if GRaisingCallbackCount = 1 then
    raise Exception.Create('epoll reactor close callback failure');
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

procedure TestRejectsPositionedOffsets;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LPipeReady: Boolean;
  LWriteBuf: Byte;
  LReadBuf: Byte;
begin
  GCallbackCount := 0;
  LPipeReady := False;
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');
  try
    Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe');
    LPipeReady := True;

    LWriteBuf := $31;
    LReadBuf := 0;
    Check(not LR.AsyncRead(LPipe[0], @LReadBuf, 1, 0, @OnComplete, nil),
      'epoll readiness reactor rejects positioned reads');
    Check(not LR.AsyncWrite(LPipe[1], @LWriteBuf, 1, 0, @OnComplete, nil),
      'epoll readiness reactor rejects positioned writes');
    Check(not LR.HasPending, 'rejected positioned operations are not pending');
    CheckEqual(Int64(0), Int64(GCallbackCount),
      'rejected positioned operations do not call back');
  finally
    if LPipeReady then
    begin
      nextpas.core.platform.posix.ffi.close(LPipe[0]);
      nextpas.core.platform.posix.ffi.close(LPipe[1]);
    end;
    LR.Close;
  end;
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

procedure TestCloseAbortsPendingRead;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LReadBuf: Byte;
begin
  GCallbackCount := 0;
  GLastResult := 0;
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');
  Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe2');

  LReadBuf := 0;
  Check(LR.AsyncRead(LPipe[0], @LReadBuf, 1, -1, @OnComplete, nil),
    'pending read queued');
  LR.Close;

  CheckEqual(Int64(1), Int64(GCallbackCount), 'close abort callback fired once');
  CheckEqual(Int64(-ESysECANCELED), Int64(GLastResult), 'close abort uses -ECANCELED');

  nextpas.core.platform.posix.ffi.close(LPipe[0]);
  nextpas.core.platform.posix.ffi.close(LPipe[1]);
end;

procedure TestHasPending;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LPipeReady: Boolean;
  LWriteBuf: Byte;
  LReadBuf: Byte;
  LCount: Int32;
begin
  GCallbackCount := 0;
  GLastResult := 0;
  LPipeReady := False;
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');
  Check(not LR.HasPending, 'new reactor has no pending operations');
  try
    Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe');
    LPipeReady := True;

    LReadBuf := 0;
    Check(LR.AsyncRead(LPipe[0], @LReadBuf, 1, -1, @OnComplete, nil),
      'pending read queued');
    Check(LR.HasPending, 'queued read marks pending');

    LWriteBuf := $5A;
    Check(nextpas.core.platform.posix.ffi.write(LPipe[1], @LWriteBuf, 1) = 1,
      'sync write');
    LCount := 0;
    while (GCallbackCount = 0) and (LCount < 100) do
    begin
      LR.PollOne;
      Inc(LCount);
    end;

    CheckEqual(Int64(1), Int64(GCallbackCount), 'pending read completed');
    CheckEqual(Int64(1), Int64(GLastResult), 'read result');
    Check(not LR.HasPending, 'completed read clears pending state');

    GCallbackCount := 0;
    Check(LR.AsyncRead(LPipe[0], @LReadBuf, 1, -1, @OnComplete, nil),
      'second pending read queued');
    Check(LR.HasPending, 'second queued read marks pending');
    LR.Close;
    CheckEqual(Int64(1), Int64(GCallbackCount), 'close abort callback fired');
    CheckEqual(Int64(-ESysECANCELED), Int64(GLastResult),
      'close abort uses -ECANCELED');
    Check(not LR.HasPending, 'close clears pending state');
  finally
    if LPipeReady then
    begin
      nextpas.core.platform.posix.ffi.close(LPipe[0]);
      nextpas.core.platform.posix.ffi.close(LPipe[1]);
    end;
    LR.Close;
  end;
end;

procedure TestAsyncCloseCancelsPendingReadForSameFd;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LPipeReady: Boolean;
  LReadFdOpen: Boolean;
  LWriteFdOpen: Boolean;
  LReadBuf: Byte;
begin
  GCallbackCount := 0;
  GLastResult := 0;
  GCloseCallbackCount := 0;
  GLastCloseResult := -1;
  LPipeReady := False;
  LReadFdOpen := False;
  LWriteFdOpen := False;
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');
  try
    Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe');
    LPipeReady := True;
    LReadFdOpen := True;
    LWriteFdOpen := True;

    LReadBuf := 0;
    Check(LR.AsyncRead(LPipe[0], @LReadBuf, 1, -1, @OnComplete, nil),
      'pending read queued');
    Check(LR.HasPending, 'read marks pending before AsyncClose');

    Check(LR.AsyncClose(LPipe[0], @OnCloseComplete, nil),
      'AsyncClose succeeds');
    LReadFdOpen := False;

    CheckEqual(Int64(1), Int64(GCallbackCount),
      'AsyncClose aborts pending read once');
    CheckEqual(Int64(-ESysECANCELED), Int64(GLastResult),
      'AsyncClose abort uses -ECANCELED');
    CheckEqual(Int64(1), Int64(GCloseCallbackCount),
      'AsyncClose close callback fired once');
    CheckEqual(Int64(0), Int64(GLastCloseResult),
      'AsyncClose close succeeds');
    Check(not LR.HasPending, 'AsyncClose clears same-fd pending state');
  finally
    if LPipeReady then
    begin
      if LReadFdOpen then
        nextpas.core.platform.posix.ffi.close(LPipe[0]);
      if LWriteFdOpen then
        nextpas.core.platform.posix.ffi.close(LPipe[1]);
    end;
    LR.Close;
  end;
end;

procedure TestAsyncCloseInvalidFdReturnsErrno;
var
  LR: TEpollReactor;
begin
  GCloseCallbackCount := 0;
  GLastCloseResult := 0;
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');
  try
    Check(LR.AsyncClose(-1, @OnCloseComplete, nil),
      'AsyncClose invalid fd still completes through callback');

    CheckEqual(Int64(1), Int64(GCloseCallbackCount),
      'AsyncClose invalid fd callback fired once');
    CheckEqual(Int64(-ESysEBADF), Int64(GLastCloseResult),
      'AsyncClose invalid fd returns -EBADF');
    Check(not LR.HasPending, 'AsyncClose invalid fd leaves no pending state');
  finally
    LR.Close;
  end;
end;

procedure TestEpollSyscallErrorModelSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.io.reactor.epoll.pas');

  CheckSourceContains(LSource, 'function epollresultfromsyscall',
    'epoll reactor must centralize syscall-to-completion result mapping');
  CheckSourceContains(LSource, 'result := -platform_get_errno;',
    'failed epoll fallback syscalls must report -errno');
  CheckSourceContains(LSource, 'lres32 := epollresultfromsyscall(lres);',
    'event-dispatched syscalls must capture errno before cleanup');
  CheckSourceContains(LSource,
    'lres := epollresultfromsyscall(nextpas.core.platform.posix.ffi.close(afd));',
    'AsyncClose must normalize close errors to -errno');
  CheckSourceContains(LSource, 'if lreleasecount > 0 then',
    'AsyncClose must not underflow an empty same-fd abort list');
  CheckSourceAbsent(LSource, 'int32(lres), lcontext',
    'epoll callbacks must not expose raw -1 syscall failures');
  CheckSourceContains(LSource,
    'lres := getsockopt(fops[aidx].fd, sol_socket, so_error',
    'connect completion must inspect getsockopt return value');
  CheckSourceContains(LSource, 'lres32 := epollresultfromsyscall(lres)',
    'connect getsockopt failure must report -errno');
end;

procedure TestCloseDispatchesAllAbortsWhenCallbackRaises;
var
  LR: TEpollReactor;
  LPipe1: array[0..1] of Int32;
  LPipe2: array[0..1] of Int32;
  LPipe1Ready: Boolean;
  LPipe2Ready: Boolean;
  LReadBuf1: Byte;
  LReadBuf2: Byte;
  LRaised: Boolean;
begin
  GRaisingCallbackCount := 0;
  GRaisingAbortCount := 0;
  LPipe1Ready := False;
  LPipe2Ready := False;
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');
  try
    Check(pipe2(@LPipe1[0], O_CLOEXEC) = 0, 'pipe1');
    LPipe1Ready := True;
    Check(pipe2(@LPipe2[0], O_CLOEXEC) = 0, 'pipe2');
    LPipe2Ready := True;

    LReadBuf1 := 0;
    LReadBuf2 := 0;
    Check(LR.AsyncRead(LPipe1[0], @LReadBuf1, 1, -1,
      @OnCompleteRaiseFirst, nil), 'first pending read queued');
    Check(LR.AsyncRead(LPipe2[0], @LReadBuf2, 1, -1,
      @OnCompleteRaiseFirst, nil), 'second pending read queued');

    LRaised := False;
    try
      LR.Close;
    except
      on E: Exception do
        LRaised := Pos('epoll reactor close callback failure', E.Message) > 0;
    end;

    Check(LRaised, 'close re-raises first callback exception');
    CheckEqual(Int64(2), Int64(GRaisingCallbackCount),
      'close dispatches all abort callbacks despite exception');
    CheckEqual(Int64(2), Int64(GRaisingAbortCount),
      'all abort callbacks use -ECANCELED');
  finally
    if LPipe2Ready then
    begin
      nextpas.core.platform.posix.ffi.close(LPipe2[0]);
      nextpas.core.platform.posix.ffi.close(LPipe2[1]);
    end;
    if LPipe1Ready then
    begin
      nextpas.core.platform.posix.ffi.close(LPipe1[0]);
      nextpas.core.platform.posix.ffi.close(LPipe1[1]);
    end;
  end;
end;

procedure TestCompletionReenterCloseDoesNotAbortAgain;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LPipeReady: Boolean;
  LCtx: TReenterCloseCtx;
  LWriteBuf: Byte;
  LReadBuf: Byte;
  LCount: Int32;
begin
  FillChar(LCtx, SizeOf(LCtx), 0);
  LPipeReady := False;
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');
  try
    Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe');
    LPipeReady := True;
    LCtx.Reactor := @LR;
    LWriteBuf := $7A;
    LReadBuf := 0;
    Check(nextpas.core.platform.posix.ffi.write(LPipe[1], @LWriteBuf, 1) = 1,
      'sync write');
    Check(LR.AsyncRead(LPipe[0], @LReadBuf, 1, -1,
      @OnCompleteReenterClose, @LCtx), 'read queued');

    LCount := 0;
    while (LCtx.CallbackCount = 0) and (LCount < 100) do
    begin
      LR.PollOne;
      Inc(LCount);
    end;

    Check(LCtx.CloseCalled, 'callback re-entered Close');
    CheckEqual(Int64(1), Int64(LCtx.CallbackCount),
      'completion is detached before callback re-enters Close');
    CheckEqual(Int64(0), Int64(LCtx.AbortCount),
      'completed op is not redispatched as close abort');
  finally
    if LPipeReady then
    begin
      nextpas.core.platform.posix.ffi.close(LPipe[0]);
      nextpas.core.platform.posix.ffi.close(LPipe[1]);
    end;
  end;
end;

procedure TestPostCloseSubmissionsAreRejected;
var
  LR: TEpollReactor;
  LPipe: array[0..1] of Int32;
  LPipeReady: Boolean;
  LReadBuf: Byte;
  LAddr: sockaddr_in;
  LAddrLen: UInt32;
begin
  GCallbackCount := 0;
  LPipeReady := False;
  LR := TEpollReactor.Create(16);
  Check(LR.IsValid, 'valid');
  Check(pipe2(@LPipe[0], O_CLOEXEC) = 0, 'pipe');
  LPipeReady := True;
  try
    LR.Close;
    Check(not LR.IsValid, 'closed reactor invalid');

    LReadBuf := 0;
    Check(not LR.AsyncRead(LPipe[0], @LReadBuf, 1, -1, @OnComplete, nil),
      'AsyncRead rejects closed reactor');
    Check(not LR.AsyncWrite(LPipe[1], @LReadBuf, 1, -1, @OnComplete, nil),
      'AsyncWrite rejects closed reactor');
    FillChar(LAddr, SizeOf(LAddr), 0);
    LAddrLen := SizeOf(LAddr);
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

    CheckEqual(Int64(0), Int64(GCallbackCount),
      'closed reactor rejects submits without callback');
    Check(fcntl(LPipe[0], F_GETFL, 0) >= 0,
      'AsyncClose after reactor close must not close caller fd');
    Check(not LR.PollOne, 'PollOne on closed reactor is no-op');
    CheckEqual(Int64(0), Int64(LR.Poll), 'Poll on closed reactor is no-op');
  finally
    if LPipeReady then
    begin
      nextpas.core.platform.posix.ffi.close(LPipe[0]);
      nextpas.core.platform.posix.ffi.close(LPipe[1]);
    end;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.io.reactor.epoll');
  T.Run('Create/Close', @TestCreateClose);
  T.Run('Async Read/Write', @TestAsyncReadWrite);
  T.Run('Rejects positioned offsets', @TestRejectsPositionedOffsets);
  T.Run('Multiple async', @TestMultipleAsync);
  T.Run('Poll batch', @TestPollBatch);
  T.Run('Context passing', @TestContext);
  T.Run('Entry recycling', @TestEntryRecycling);
  T.Run('Close aborts pending read', @TestCloseAbortsPendingRead);
  T.Run('HasPending', @TestHasPending);
  T.Run('AsyncClose cancels pending read for same fd',
    @TestAsyncCloseCancelsPendingReadForSameFd);
  T.Run('AsyncClose invalid fd returns errno',
    @TestAsyncCloseInvalidFdReturnsErrno);
  T.Run('epoll syscall error model source contract',
    @TestEpollSyscallErrorModelSourceContract);
  T.Run('Close dispatches all aborts when callback raises',
    @TestCloseDispatchesAllAbortsWhenCallbackRaises);
  T.Run('Completion re-enter Close does not abort again',
    @TestCompletionReenterCloseDoesNotAbortAgain);
  T.Run('Post-close submissions are rejected',
    @TestPostCloseSubmissionsAreRejected);
  T.Summary;
end.
