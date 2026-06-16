program test_process_pipe_contract;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.process.pipe
  {$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.base,
    nextpas.core.platform.posix.ffi,
    nextpas.core.platform.posix.math
    {$IFDEF NEXTPAS_LINUX}
    , nextpas.core.platform.linux.base,
      nextpas.core.platform.linux.ffi
    {$ENDIF}
  {$ENDIF}
  ;

var
  T: TTestRunner;
  GPipeTestByte: Byte = 1;

{$IFDEF NEXTPAS_LINUX}
function pthread_kill(thread: pthread_t; sig: cint): cint; cdecl; external 'pthread' name 'pthread_kill';

var
  GSignalCount: Int32;

type
  TTestSignalHandler = procedure(ASignal: Int32); cdecl;

  TLibcSigSet = record
    Bits: array[0..15] of QWord;
  end;

  TLibcSigAction = record
    sa_handler: Pointer;
    sa_mask: TLibcSigSet;
    sa_flags: Int32;
    sa_restorer: Pointer;
  end;

procedure TestSignalHandler(ASignal: Int32); cdecl;
begin
  Inc(GSignalCount);
end;

procedure InstallSigUsr1NoRestart;
var
  LAct: TLibcSigAction;
begin
  GSignalCount := 0;
  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := Pointer(TTestSignalHandler(@TestSignalHandler));
  Check(sigaction(SIGUSR1, @LAct, nil) = 0, 'install SIGUSR1 handler without SA_RESTART');
end;

procedure ResetSigUsr1Handler;
var
  LAct: TLibcSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  Check(sigaction(SIGUSR1, @LAct, nil) = 0, 'reset SIGUSR1 handler');
end;

procedure ResetSigPipeDefault;
var
  LAct: TLibcSigAction;
begin
  FillChar(LAct, SizeOf(LAct), 0);
  Check(sigaction(SIGPIPE, @LAct, nil) = 0, 'reset SIGPIPE default');
end;

procedure WaitForFlag(var AFlag: Int32; const AName: string);
var
  LDeadline: QWord;
begin
  LDeadline := GetTickCount64 + 2000;
  while InterlockedCompareExchange(AFlag, 0, 0) = 0 do
  begin
    if GetTickCount64 > LDeadline then
      Fail(AName + ' timed out');
    Sleep(1);
  end;
end;

procedure SetNonBlocking(const AFd: Int32; const AEnabled: Boolean);
var
  LFlags: Int32;
begin
  LFlags := fcntl(AFd, F_GETFL, 0);
  Check(LFlags >= 0, 'fcntl(F_GETFL) succeeds');
  if AEnabled then
    LFlags := LFlags or O_NONBLOCK
  else
    LFlags := LFlags and (not O_NONBLOCK);
  Check(fcntl(AFd, F_SETFL, LFlags) = 0, 'fcntl(F_SETFL) succeeds');
end;

function FillPipeUntilWouldBlock(const AFd: Int32): SizeUInt;
var
  LBuf: array[0..4095] of Byte;
  LWritten: ssize_t;
begin
  FillChar(LBuf, SizeOf(LBuf), $5A);
  Result := 0;
  repeat
    LWritten := nextpas.core.platform.posix.ffi.write(AFd, @LBuf[0], SizeOf(LBuf));
    if LWritten > 0 then
    begin
      Inc(Result, SizeUInt(LWritten));
      Continue;
    end;
    Check(LWritten < 0, 'full pipe reports error instead of zero progress');
    CheckEqual(Int64(ESysEAGAIN), Int64(platform_get_errno),
      'full pipe reports EAGAIN');
    Exit;
  until False;
end;

function PipeUnreadBytes(const AFd: Int32): SizeUInt;
var
  LAvail: Int32;
begin
  LAvail := 0;
  Check(ioctl(AFd, FIONREAD, @LAvail) = 0, 'ioctl(FIONREAD) succeeds');
  Check(LAvail >= 0, 'ioctl(FIONREAD) returns non-negative byte count');
  Result := SizeUInt(LAvail);
end;

procedure WaitForPipeUnreadBytes(const AFd: Int32; const AExpected: SizeUInt;
  const AName: string);
var
  LDeadline: QWord;
begin
  LDeadline := GetTickCount64 + 2000;
  while PipeUnreadBytes(AFd) < AExpected do
  begin
    if GetTickCount64 > LDeadline then
      Fail(AName + ' timed out');
    Sleep(1);
  end;
end;

procedure DrainPipeExact(const AFd: Int32; const ACount: SizeUInt);
var
  LBuf: array[0..4095] of Byte;
  LRemaining: SizeUInt;
  LWant: SizeUInt;
  LRead: ssize_t;
begin
  LRemaining := ACount;
  while LRemaining > 0 do
  begin
    LWant := LRemaining;
    if LWant > SizeOf(LBuf) then
      LWant := SizeOf(LBuf);
    LRead := nextpas.core.platform.posix.ffi.read(AFd, @LBuf[0], LWant);
    Check(LRead > 0, 'drain exact makes progress');
    Dec(LRemaining, SizeUInt(LRead));
  end;
end;

procedure DrainUntilDone(const AFd: Int32; var ATotal: SizeUInt;
  const ADone: PInt32);
var
  LBuf: array[0..4095] of Byte;
  LRead: ssize_t;
begin
  repeat
    LRead := nextpas.core.platform.posix.ffi.read(AFd, @LBuf[0], SizeOf(LBuf));
    if LRead > 0 then
    begin
      Inc(ATotal, SizeUInt(LRead));
      Continue;
    end;
    if (LRead < 0) and (platform_get_errno = ESysEAGAIN) then
    begin
      if InterlockedCompareExchange(ADone^, 0, 0) <> 0 then
        Exit;
      Sleep(1);
      Continue;
    end;
    Check(LRead = 0, 'drain should not hit EOF before writer close');
    Exit;
  until False;
end;
{$ENDIF}

procedure TestPipeReaderInvalidFdRaises;
var
  LReader: TPipeReader;
  LByte: Byte;
  LGot: Boolean;
begin
  LReader := TPipeReader.Create(-1);
  try
    LGot := False;
    try
      LReader.Read(LByte, 1);
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'invalid reader fd raises EIOError');
  finally
    LReader.Free;
  end;
end;

procedure TestPipeWriterInvalidFdRaises;
var
  LWriter: TPipeWriter;
  LGot: Boolean;
begin
  LWriter := TPipeWriter.Create(-1);
  try
    LGot := False;
    try
      LWriter.Write(GPipeTestByte, 1);
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'invalid writer fd raises EIOError');
  finally
    LWriter.Free;
  end;
end;

procedure TestPipeReaderCloseInvalidFdRaises;
var
  LReader: TPipeReader;
  LGot: Boolean;
begin
  LReader := TPipeReader.Create(-1);
  try
    LGot := False;
    try
      LReader.Close;
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'invalid reader close raises EIOError');
  finally
    LReader.Free;
  end;
end;

procedure TestPipeWriterCloseInvalidFdRaises;
var
  LWriter: TPipeWriter;
  LGot: Boolean;
begin
  LWriter := TPipeWriter.Create(-1);
  try
    LGot := False;
    try
      LWriter.Close;
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'invalid writer close raises EIOError');
  finally
    LWriter.Free;
  end;
end;

procedure TestPipeReaderExposesReadCloseContract;
var
  LPipe: array[0..1] of Int32;
  LReader: IReader;
  LReadCloser: IReadCloser;
  LDrainReader: IPipeDrainReader;
  LByte: Byte;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  Check(write(LPipe[1], @GPipeTestByte, 1) = 1, 'write test byte');
  Check(close(LPipe[1]) = 0, 'writer end closed');
  LReader := TPipeReader.Create(LPipe[0]) as IReader;
  Check(Supports(LReader, IReadCloser, LReadCloser),
    'reader supports IReadCloser');
  Check(Supports(LReader, IPipeDrainReader, LDrainReader),
    'reader supports IPipeDrainReader');
  CheckEqual(Int64(LPipe[0]), Int64(LDrainReader.NativeHandle),
    'native handle matches constructor fd');
  CheckEqual(Int64(1), Int64(LReadCloser.Read(LByte, 1)),
    'read closer reads one byte');
  CheckEqual(Int64(GPipeTestByte), Int64(LByte),
    'read closer byte matches payload');
  LReadCloser.Close;
  LDrainReader := nil;
  LReadCloser := nil;
  LReader := nil;
end;

procedure TestPipeWriterExposesWriteCloseContract;
var
  LPipe: array[0..1] of Int32;
  LWriter: IWriter;
  LWriteCloser: IWriteCloser;
  LReadByte: Byte;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  LWriter := TPipeWriter.Create(LPipe[1]) as IWriter;
  Check(Supports(LWriter, IWriteCloser, LWriteCloser),
    'writer supports IWriteCloser');
  CheckEqual(Int64(1), Int64(LWriteCloser.Write(GPipeTestByte, 1)),
    'write closer writes one byte');
  LWriteCloser.Close;
  CheckEqual(Int64(1), Int64(read(LPipe[0], @LReadByte, 1)),
    'reader receives one byte');
  CheckEqual(Int64(GPipeTestByte), Int64(LReadByte),
    'reader byte matches payload');
  LWriteCloser := nil;
  LWriter := nil;
  Check(close(LPipe[0]) = 0, 'reader end closed');
end;

{$IFDEF NEXTPAS_UNIX}
procedure TestPipeReaderZeroCountReturnsZero;
var
  LPipe: array[0..1] of Int32;
  LReader: TPipeReader;
  LByte: Byte;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  LReader := TPipeReader.Create(LPipe[0]);
  try
    CheckEqual(Int64(0), Int64(LReader.Read(LByte, 0)),
      'zero-count read returns 0');
  finally
    LReader.Free;
    Check(close(LPipe[1]) = 0, 'writer end closed');
  end;
end;

procedure TestPipeWriterZeroCountReturnsZero;
var
  LPipe: array[0..1] of Int32;
  LWriter: TPipeWriter;
  LByte: Byte;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  LWriter := TPipeWriter.Create(LPipe[1]);
  try
    LByte := 7;
    CheckEqual(Int64(0), Int64(LWriter.Write(LByte, 0)),
      'zero-count write returns 0');
  finally
    LWriter.Free;
    Check(close(LPipe[0]) = 0, 'reader end closed');
  end;
end;

procedure TestPipeReaderEofReturnsZero;
var
  LPipe: array[0..1] of Int32;
  LReader: TPipeReader;
  LByte: Byte;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  Check(close(LPipe[1]) = 0, 'writer end closed');
  LReader := TPipeReader.Create(LPipe[0]);
  try
    CheckEqual(Int64(0), Int64(LReader.Read(LByte, 1)), 'EOF returns 0');
  finally
    LReader.Free;
  end;
end;

procedure TestPipeReaderClosedWrapperRaises;
var
  LPipe: array[0..1] of Int32;
  LReader: TPipeReader;
  LByte: Byte;
  LGot: Boolean;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  LReader := TPipeReader.Create(LPipe[0]);
  try
    LReader.Close;
    LGot := False;
    try
      LReader.Read(LByte, 1);
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'closed reader wrapper raises EIOError');
  finally
    LReader.Free;
    Check(close(LPipe[1]) = 0, 'writer end closed');
  end;
end;

procedure TestPipeWriterClosedWrapperRaises;
var
  LPipe: array[0..1] of Int32;
  LWriter: TPipeWriter;
  LGot: Boolean;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  LWriter := TPipeWriter.Create(LPipe[1]);
  try
    LWriter.Close;
    LGot := False;
    try
      LWriter.Write(GPipeTestByte, 1);
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'closed writer wrapper raises EIOError');
  finally
    LWriter.Free;
    Check(close(LPipe[0]) = 0, 'reader end closed');
  end;
end;
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
procedure TestPipeReaderNonBlockingEagainRaises;
var
  LPipe: array[0..1] of Int32;
  LReader: TPipeReader;
  LByte: Byte;
  LGot: Boolean;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  SetNonBlocking(LPipe[0], True);
  LReader := TPipeReader.Create(LPipe[0]);
  try
    LGot := False;
    try
      LReader.Read(LByte, 1);
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'nonblocking empty pipe raises EIOError');
  finally
    LReader.Free;
    Check(close(LPipe[1]) = 0, 'writer end closed');
  end;
end;

procedure TestPipeWriterNonBlockingEagainRaises;
var
  LPipe: array[0..1] of Int32;
  LWriter: TPipeWriter;
  LByte: Byte;
  LGot: Boolean;
begin
  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  SetNonBlocking(LPipe[1], True);
  FillPipeUntilWouldBlock(LPipe[1]);
  LWriter := TPipeWriter.Create(LPipe[1]);
  try
    LGot := False;
    LByte := 9;
    try
      LWriter.Write(LByte, 1);
    except
      on E: EIOError do
        LGot := True;
    end;
    Check(LGot, 'nonblocking full pipe raises EIOError');
  finally
    LWriter.Free;
    Check(close(LPipe[0]) = 0, 'reader end closed');
  end;
end;

procedure TestPipeReaderRetriesEintr;
var
  LPipe: array[0..1] of Int32;
  LReader: TPipeReader;
  LReaderThread: TThread;
  LSignalThread: TThread;
  LReady: Int32;
  LDone: Int32;
  LThreadId: pthread_t;
  LReadCount: SizeUInt;
  LReadByte: Byte;
  LWriteByte: Byte;
  LErrorText: string;
begin
  InstallSigUsr1NoRestart;
  LReaderThread := nil;
  LSignalThread := nil;
  LReader := nil;
  LReady := 0;
  LDone := 0;
  LThreadId := 0;
  LReadCount := 0;
  LReadByte := 0;
  LErrorText := '';
  try
    Check(pipe(@LPipe[0]) = 0, 'pipe created');
    LReader := TPipeReader.Create(LPipe[0]);
    LReaderThread := TThread.CreateAnonymousThread(procedure
    begin
      LThreadId := pthread_self;
      InterlockedExchange(LReady, 1);
      try
        LReadCount := LReader.Read(LReadByte, 1);
      except
        on E: Exception do
          LErrorText := E.ClassName + ': ' + E.Message;
      end;
      InterlockedExchange(LDone, 1);
    end);
    LReaderThread.FreeOnTerminate := False;
    LReaderThread.Start;
    WaitForFlag(LReady, 'reader thread ready');

    LSignalThread := TThread.CreateAnonymousThread(procedure
    begin
      while InterlockedCompareExchange(LDone, 0, 0) = 0 do
      begin
        pthread_kill(LThreadId, SIGUSR1);
        Sleep(2);
      end;
    end);
    LSignalThread.FreeOnTerminate := False;
    LSignalThread.Start;

    Sleep(50);
    LWriteByte := $4D;
    CheckEqual(Int64(1), Int64(write(LPipe[1], @LWriteByte, 1)),
      'main thread writes unblock byte');

    LReaderThread.WaitFor;
    LSignalThread.WaitFor;

    CheckEqual('', LErrorText, 'reader thread error');
    Check(GSignalCount > 0, 'SIGUSR1 delivered while read pending');
    CheckEqual(Int64(1), Int64(LReadCount), 'reader retries after EINTR');
    CheckEqual(Int64(LWriteByte), Int64(LReadByte), 'reader receives written byte');
  finally
    if LSignalThread <> nil then
      LSignalThread.Free;
    if LReaderThread <> nil then
      LReaderThread.Free;
    if LReader <> nil then
      LReader.Free;
    Check(close(LPipe[1]) = 0, 'writer end closed');
    ResetSigUsr1Handler;
  end;
end;

procedure TestPipeWriterRetriesEintr;
var
  LPipe: array[0..1] of Int32;
  LWriter: TPipeWriter;
  LWriterThread: TThread;
  LSignalThread: TThread;
  LDrainThread: TThread;
  LReady: Int32;
  LDone: Int32;
  LThreadId: pthread_t;
  LWriteCount: SizeUInt;
  LFilled: SizeUInt;
  LDrained: SizeUInt;
  LWriteByte: Byte;
  LErrorText: string;
begin
  InstallSigUsr1NoRestart;
  LWriterThread := nil;
  LSignalThread := nil;
  LDrainThread := nil;
  LWriter := nil;
  LReady := 0;
  LDone := 0;
  LThreadId := 0;
  LWriteCount := 0;
  LFilled := 0;
  LDrained := 0;
  LWriteByte := $33;
  LErrorText := '';
  try
    Check(pipe(@LPipe[0]) = 0, 'pipe created');
    SetNonBlocking(LPipe[1], True);
    SetNonBlocking(LPipe[0], True);
    LFilled := FillPipeUntilWouldBlock(LPipe[1]);
    SetNonBlocking(LPipe[1], False);

    LWriter := TPipeWriter.Create(LPipe[1]);
    LWriterThread := TThread.CreateAnonymousThread(procedure
    begin
      LThreadId := pthread_self;
      InterlockedExchange(LReady, 1);
      try
        LWriteCount := LWriter.Write(LWriteByte, 1);
      except
        on E: Exception do
          LErrorText := E.ClassName + ': ' + E.Message;
      end;
      InterlockedExchange(LDone, 1);
    end);
    LWriterThread.FreeOnTerminate := False;
    LWriterThread.Start;
    WaitForFlag(LReady, 'writer thread ready');

    LSignalThread := TThread.CreateAnonymousThread(procedure
    begin
      while InterlockedCompareExchange(LDone, 0, 0) = 0 do
      begin
        pthread_kill(LThreadId, SIGUSR1);
        Sleep(2);
      end;
    end);
    LSignalThread.FreeOnTerminate := False;
    LSignalThread.Start;

    WaitForFlag(GSignalCount, 'writer EINTR signal');

    LDrainThread := TThread.CreateAnonymousThread(procedure
    begin
      DrainUntilDone(LPipe[0], LDrained, @LDone);
    end);
    LDrainThread.FreeOnTerminate := False;
    LDrainThread.Start;

    LWriterThread.WaitFor;
    LSignalThread.WaitFor;
    LDrainThread.WaitFor;

    CheckEqual('', LErrorText, 'writer thread error');
    Check(GSignalCount > 0, 'SIGUSR1 delivered while write pending');
    CheckEqual(Int64(1), Int64(LWriteCount), 'writer retries after EINTR');

    LWriter.Free;
    LWriter := nil;
    CheckEqual(Int64(LFilled + 1), Int64(LDrained),
      'pipe retains filled bytes plus retried write');
  finally
    if LSignalThread <> nil then
      LSignalThread.Free;
    if LDrainThread <> nil then
      LDrainThread.Free;
    if LWriterThread <> nil then
      LWriterThread.Free;
    if LWriter <> nil then
      LWriter.Free;
    Check(close(LPipe[0]) = 0, 'reader end closed');
    ResetSigUsr1Handler;
  end;
end;

procedure TestPipeWriterCompletesAfterPositiveShortWrite;
const
  CDrainWindow = 4096;
  CWriteCount = 16384;
var
  LPipe: array[0..1] of Int32;
  LWriter: TPipeWriter;
  LWriterThread: TThread;
  LDrainThread: TThread;
  LReady: Int32;
  LDone: Int32;
  LThreadId: pthread_t;
  LFilled: SizeUInt;
  LDrained: SizeUInt;
  LWriteCount: SizeUInt;
  LPayload: array of Byte;
  LErrorText: string;
  LI: SizeInt;
  LWriterOwnsFd: Boolean;
  LWriterThreadStarted: Boolean;
  LDrainThreadStarted: Boolean;
begin
  InstallSigUsr1NoRestart;
  LPipe[0] := -1;
  LPipe[1] := -1;
  LWriter := nil;
  LWriterThread := nil;
  LDrainThread := nil;
  LReady := 0;
  LDone := 0;
  LThreadId := 0;
  LDrained := 0;
  LWriteCount := 0;
  LErrorText := '';
  LWriterOwnsFd := False;
  LWriterThreadStarted := False;
  LDrainThreadStarted := False;
  SetLength(LPayload, CWriteCount);
  for LI := 0 to High(LPayload) do
    LPayload[LI] := Byte(LI and $FF);
  try
    Check(pipe(@LPipe[0]) = 0, 'pipe created');
    SetNonBlocking(LPipe[1], True);
    SetNonBlocking(LPipe[0], True);
    LFilled := FillPipeUntilWouldBlock(LPipe[1]);
    Check(LFilled >= CDrainWindow,
      'pipe capacity is large enough for short-write window');
    DrainPipeExact(LPipe[0], CDrainWindow);
    SetNonBlocking(LPipe[1], False);

    LWriter := TPipeWriter.Create(LPipe[1]);
    LWriterOwnsFd := True;
    LPipe[1] := -1;
    LWriterThread := TThread.CreateAnonymousThread(procedure
    begin
      LThreadId := pthread_self;
      InterlockedExchange(LReady, 1);
      try
        LWriteCount := LWriter.Write(LPayload[0], Length(LPayload));
      except
        on E: Exception do
          LErrorText := E.ClassName + ': ' + E.Message;
      end;
      InterlockedExchange(LDone, 1);
    end);
    LWriterThread.FreeOnTerminate := False;
    LWriterThread.Start;
    LWriterThreadStarted := True;
    WaitForFlag(LReady, 'writer thread ready');
    WaitForPipeUnreadBytes(LPipe[0], LFilled, 'writer fills drained window');

    CheckEqual(Int64(0), Int64(pthread_kill(LThreadId, SIGUSR1)),
      'interrupt writer after positive partial write');
    WaitForFlag(GSignalCount, 'writer positive short-write signal');

    LDrainThread := TThread.CreateAnonymousThread(procedure
    begin
      DrainUntilDone(LPipe[0], LDrained, @LDone);
    end);
    LDrainThread.FreeOnTerminate := False;
    LDrainThread.Start;
    LDrainThreadStarted := True;

    LWriterThread.WaitFor;
    LDrainThread.WaitFor;

    CheckEqual('', LErrorText, 'writer thread error');
    CheckEqual(Int64(CWriteCount), Int64(LWriteCount),
      'writer completes full payload after positive short write');
    CheckEqual(Int64(LFilled + CWriteCount - CDrainWindow), Int64(LDrained),
      'pipe receives original bytes plus full payload');
  finally
    if (LDrainThread = nil) and LWriterThreadStarted and
      (InterlockedCompareExchange(LDone, 0, 0) = 0) and (LPipe[0] >= 0) then
    begin
      LDrainThread := TThread.CreateAnonymousThread(procedure
      begin
        DrainUntilDone(LPipe[0], LDrained, @LDone);
      end);
      LDrainThread.FreeOnTerminate := False;
      LDrainThread.Start;
      LDrainThreadStarted := True;
    end;
    if LWriterThreadStarted then
      LWriterThread.WaitFor;
    if LDrainThreadStarted then
      LDrainThread.WaitFor;
    if LDrainThread <> nil then
      LDrainThread.Free;
    if LWriterThread <> nil then
      LWriterThread.Free;
    if LWriter <> nil then
      LWriter.Free;
    if (not LWriterOwnsFd) and (LPipe[1] >= 0) then
      nextpas.core.platform.posix.ffi.close(LPipe[1]);
    if LPipe[0] >= 0 then
      nextpas.core.platform.posix.ffi.close(LPipe[0]);
    ResetSigUsr1Handler;
  end;
end;

procedure TestPipeWriterBrokenPipeRaisesInsteadOfSigPipe;
var
  LWarmPipe: array[0..1] of Int32;
  LPipe: array[0..1] of Int32;
  LPid: pid_t;
  LStatus: Int32;
  LWarmWriter: TPipeWriter;
  LWriter: TPipeWriter;
  LWarmByte: Byte;
  LByte: Byte;
  LGotEIO: Boolean;
begin
  Check(pipe(@LWarmPipe[0]) = 0, 'warm pipe created');
  LWarmWriter := TPipeWriter.Create(LWarmPipe[1]);
  LWarmByte := $51;
  try
    CheckEqual(Int64(1), Int64(LWarmWriter.Write(LWarmByte, 1)),
      'parent warm write succeeds');
  finally
    LWarmWriter.Free;
    Check(close(LWarmPipe[0]) = 0, 'warm reader closed');
  end;

  Check(pipe(@LPipe[0]) = 0, 'pipe created');
  LPid := fork;
  Check(LPid >= 0, 'fork succeeds');

  if LPid = 0 then
  begin
    close(LPipe[0]);
    ResetSigPipeDefault;
    LWriter := TPipeWriter.Create(LPipe[1]);
    LGotEIO := False;
    LByte := $7A;
    try
      try
        LWriter.Write(LByte, 1);
      except
        on E: EIOError do
          LGotEIO := True;
      end;
      if LGotEIO then
        posix_exit(0)
      else
        posix_exit(2);
    finally
      LWriter.Free;
    end;
  end;

  Check(close(LPipe[0]) = 0, 'parent closes reader end');
  Check(close(LPipe[1]) = 0, 'parent closes writer end');

  repeat
    Check(waitpid(LPid, @LStatus, 0) = LPid, 'wait child');
  until not platform_posix_wait_if_stopped(LStatus);

  Check(platform_posix_wait_if_exited(LStatus), 'child exits instead of SIGPIPE');
  if platform_posix_wait_if_exited(LStatus) then
    CheckEqual(Int64(0), Int64(platform_posix_wait_exit_status(LStatus)),
      'broken pipe raises EIOError in child')
  else if platform_posix_wait_if_signaled(LStatus) then
    CheckEqual(Int64(SIGPIPE), Int64(platform_posix_wait_term_signal(LStatus)),
      'old implementation is terminated by SIGPIPE');
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.process.pipe_contract');
  T.Run('invalid reader fd raises', @TestPipeReaderInvalidFdRaises);
  T.Run('invalid writer fd raises', @TestPipeWriterInvalidFdRaises);
  T.Run('invalid reader close raises', @TestPipeReaderCloseInvalidFdRaises);
  T.Run('invalid writer close raises', @TestPipeWriterCloseInvalidFdRaises);
  T.Run('reader exposes read-close and drain contracts',
    @TestPipeReaderExposesReadCloseContract);
  T.Run('writer exposes write-close contract',
    @TestPipeWriterExposesWriteCloseContract);
  {$IFDEF NEXTPAS_UNIX}
  T.Run('reader zero-count returns 0', @TestPipeReaderZeroCountReturnsZero);
  T.Run('writer zero-count returns 0', @TestPipeWriterZeroCountReturnsZero);
  T.Run('reader EOF returns 0', @TestPipeReaderEofReturnsZero);
  T.Run('closed reader wrapper raises', @TestPipeReaderClosedWrapperRaises);
  T.Run('closed writer wrapper raises', @TestPipeWriterClosedWrapperRaises);
  {$IFDEF NEXTPAS_LINUX}
  T.Run('reader nonblocking EAGAIN raises', @TestPipeReaderNonBlockingEagainRaises);
  T.Run('writer nonblocking EAGAIN raises', @TestPipeWriterNonBlockingEagainRaises);
  T.Run('reader retries EINTR', @TestPipeReaderRetriesEintr);
  T.Run('writer retries EINTR', @TestPipeWriterRetriesEintr);
  T.Run('writer completes after positive short write',
    @TestPipeWriterCompletesAfterPositiveShortWrite);
  T.Run('writer broken pipe raises EIOError',
    @TestPipeWriterBrokenPipeRaisesInsteadOfSigPipe);
  {$ENDIF}
  {$ENDIF}
  T.Summary;
end.
