unit nextpas.core.process.pipe;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.platform.posix.errno;

type
  IPipeDrainReader = interface(IReadCloser)
    ['{F1A2B3C4-D5E6-7890-ABCD-100000000060}']
    function NativeHandle: PtrInt;
  end;

  { TPipeReader — IReader 包装一个管道 fd (Unix) 或 HANDLE (Windows) }
  TPipeReader = class(TInterfacedObject, IReader, IReadCloser, IPipeDrainReader)
  private
    FFd: PtrInt;
    FClosed: Boolean;
  public
    constructor Create(const AFd: PtrInt);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Fd: PtrInt read FFd;
    function NativeHandle: PtrInt;
  end;

  { TPipeWriter — IWriter 包装一个管道 fd }
  TPipeWriter = class(TInterfacedObject, IWriter, IWriteCloser)
  private
    FFd: PtrInt;
    FClosed: Boolean;
  public
    constructor Create(const AFd: PtrInt);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Fd: PtrInt read FFd;
  end;

{** AMaxTotal: stdout+stderr 累计上限（字节），<=0 不限制；超限置 ALimited=True *}
procedure DrainPipePair(const AStdout, AStderr: IReader; const ATimeout: Int32;
  var AStdoutText, AStderrText: string; var AStdoutClosed, AStderrClosed: Boolean;
  const AMaxTotal: Int64; var ALimited: Boolean);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.platform.error,
  nextpas.core.text.conv,
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.process,
  nextpas.core.platform.signal
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi
  {$ENDIF}
  ;

{$IFDEF NEXTPAS_UNIX}
var
  GSigPipeIgnorePid: Int32 = 0;
{$ENDIF}

const
  PIPE_DRAIN_BUF_SIZE = 65536;

{** Append up to AChunkSize bytes; respects AMaxTotal across ACount+ASiblingCount.
 *  Returns False if ALimited became True (caller should stop draining). *}
function AppendPipeChunk(var ATarget: string; var ACount: Integer;
  const ABuf; const AChunkSize: SizeInt; const AMaxTotal: Int64;
  const ASiblingCount: Integer; var ALimited: Boolean): Boolean;
var
  LTake: SizeInt;
  LRemain: Int64;
begin
  Result := True;
  if AChunkSize <= 0 then
    Exit;
  LTake := AChunkSize;
  if AMaxTotal > 0 then
  begin
    LRemain := AMaxTotal - Int64(ACount) - Int64(ASiblingCount);
    if LRemain <= 0 then
    begin
      ALimited := True;
      Exit(False);
    end;
    if Int64(LTake) > LRemain then
    begin
      LTake := SizeInt(LRemain);
      ALimited := True;
      Result := False;
    end;
  end;
  SetLength(ATarget, ACount + Integer(LTake));
  Move(ABuf, ATarget[ACount + 1], LTake);
  Inc(ACount, Integer(LTake));
end;

function PipeSystemError(const AOperation: string; const ACode: Int32): EIOError;
var
  LBuf: array[0..255] of AnsiChar;
  LMsg: string;
begin
  LMsg := '';
  if platform_error_message(ACode, @LBuf[0], SizeOf(LBuf)) > 0 then
    LMsg := ': ' + string(PAnsiChar(@LBuf[0]));
  Result := EIOError.Create(AOperation + ' failed (' + IntToStr(ACode) +
    LMsg + ')');
end;

function PipeClosedError(const AOperation: string): EIOError;
begin
  Result := EIOError.Create(AOperation + ' failed (pipe closed)');
end;

{$IFDEF NEXTPAS_UNIX}
function PipeSyscallError(const AOperation: string): EIOError;
begin
  Result := PipeSystemError(AOperation, platform_get_last_error);
end;

function PipeFdAsFileHandle(const AFd: PtrInt): TPlatformFileHandle; inline;
begin
  Result.Value := cint(AFd);
end;

{ platform_file_read/write do not retry EINTR; pipe I/O matches former
  platform_io_* EINTR loop + partial-write accumulation. }
function PipeFileRead(const AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt;
  out ABytesRead: PtrUInt): Int32;
var
  LHandle: TPlatformFileHandle;
begin
  ABytesRead := 0;
  if (AFd < 0) or (ABuf = nil) then
    Exit(PLATFORM_ERR_INVALID);
  if ACount = 0 then
    Exit(0);
  LHandle := PipeFdAsFileHandle(AFd);
  repeat
    Result := platform_file_read(LHandle, ABuf, PtrUInt(ACount), ABytesRead);
    if Result <> PLATFORM_ERR_INTR then
      Exit;
  until False;
end;

function PipeFileWrite(const AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt;
  out ABytesWritten: PtrUInt): Int32;
var
  LHandle: TPlatformFileHandle;
  LTotal: SizeUInt;
  LChunk: PtrUInt;
  LErr: Int32;
begin
  ABytesWritten := 0;
  if (AFd < 0) or (ABuf = nil) then
    Exit(PLATFORM_ERR_INVALID);
  if ACount = 0 then
    Exit(0);
  LHandle := PipeFdAsFileHandle(AFd);
  LTotal := 0;
  while LTotal < ACount do
  begin
    LErr := platform_file_write(LHandle,
      Pointer(PtrUInt(ABuf) + LTotal), PtrUInt(ACount - LTotal), LChunk);
    if LErr = PLATFORM_ERR_INTR then
      Continue;
    if LErr <> 0 then
      Exit(LErr);
    if LChunk = 0 then
      Exit(PLATFORM_ERR_IO);
    Inc(LTotal, LChunk);
  end;
  ABytesWritten := LTotal;
  Result := 0;
end;

function PipeFileClose(const AFd: PtrInt): Int32;
var
  LHandle: TPlatformFileHandle;
begin
  { Invalid sentinel fds fail closed (platform.files BADF), not silent success. }
  if AFd < 0 then
    Exit(PLATFORM_ERR_BADF);
  LHandle := PipeFdAsFileHandle(AFd);
  Result := platform_file_close(LHandle);
end;

{ Multi-fd drain poll: host poll via platform.posix.ffi with EINTR retry.
  Avoids transitional platform_io_poll dual-API (F5 complete). }
function PipePoll(AFds: Pointer; ACount: Int32; ATimeoutMs: Int32): Int32;
var
  LPollResult: Int32;
begin
  if (AFds = nil) or (ACount <= 0) then
    Exit(-1);
  repeat
    LPollResult := poll(AFds, cuint(ACount), ATimeoutMs);
    if LPollResult >= 0 then
      Exit(LPollResult);
    if platform_get_errno = PLATFORM_ERR_INTR then
      Continue;
    Exit(-1);
  until False;
end;

procedure EnsureSigPipeIgnored;
var
  LErr: Int32;
  LPid: Int32;
begin
  {$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  LPid := platform_getpid;
  if GSigPipeIgnorePid = LPid then
    Exit;
  LErr := platform_signal_ignore(PLATFORM_SIGPIPE);
  if LErr <> 0 then
    raise PipeSystemError('platform_signal_ignore(SIGPIPE)', LErr);
  GSigPipeIgnorePid := LPid;
  {$ENDIF}
end;
{$ENDIF}

{ TPipeReader }

constructor TPipeReader.Create(const AFd: PtrInt);
begin
  inherited Create;
  FFd := AFd;
  FClosed := False;
end;

destructor TPipeReader.Destroy;
begin
  if not FClosed then
  begin
    try
      Close;
    except
      { Explicit Close reports failures; destructor cleanup is best effort. }
    end;
  end;
  inherited;
end;

function TPipeReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  {$IFDEF NEXTPAS_UNIX}
  LRead: PtrUInt;
  LErr: Int32;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}LRead: DWORD;{$ENDIF}
begin
  if FClosed then
    raise PipeClosedError('TPipeReader.Read');
  if ACount = 0 then Exit(0);
  {$IFDEF NEXTPAS_UNIX}
  LErr := PipeFileRead(FFd, @ABuf, ACount, LRead);
  if LErr = 0 then
    Exit(LRead);
  raise PipeSystemError('TPipeReader.Read', LErr);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LRead := 0;
  if not ReadFile(HANDLE(FFd), @ABuf, DWORD(ACount), @LRead, nil) then
  begin
    LRead := GetLastError;
    if (LRead = ERROR_BROKEN_PIPE) or (LRead = ERROR_HANDLE_EOF) then
      Exit(0);
    raise PipeSystemError('TPipeReader.Read', Int32(LRead));
  end;
  Result := SizeUInt(LRead);
  {$ENDIF}
end;

procedure TPipeReader.Close;
var
  LCloseError: EIOError;
  {$IFDEF NEXTPAS_UNIX}LErr: Int32;{$ENDIF}
begin
  if FClosed then Exit;
  LCloseError := nil;
  {$IFDEF NEXTPAS_UNIX}
  LErr := PipeFileClose(FFd);
  if LErr <> 0 then
    LCloseError := PipeSystemError('TPipeReader.Close', LErr);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  if FFd < 0 then
    LCloseError := PipeSystemError('TPipeReader.Close', PLATFORM_ERR_BADF)
  else if not CloseHandle(HANDLE(FFd)) then
    LCloseError := PipeSystemError('TPipeReader.Close', Int32(GetLastError));
  {$ENDIF}
  FClosed := True;
  if LCloseError <> nil then
    raise LCloseError;
end;

function TPipeReader.NativeHandle: PtrInt;
begin
  Result := FFd;
end;

{ TPipeWriter }

constructor TPipeWriter.Create(const AFd: PtrInt);
begin
  inherited Create;
  FFd := AFd;
  FClosed := False;
end;

destructor TPipeWriter.Destroy;
begin
  if not FClosed then
  begin
    try
      Close;
    except
      { Explicit Close reports failures; destructor cleanup is best effort. }
    end;
  end;
  inherited;
end;

function TPipeWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  {$IFDEF NEXTPAS_UNIX}
  LWritten: PtrUInt;
  LErr: Int32;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}LWritten: DWORD;{$ENDIF}
begin
  if FClosed then
    raise PipeClosedError('TPipeWriter.Write');
  if ACount = 0 then Exit(0);
  {$IFDEF NEXTPAS_UNIX}
  EnsureSigPipeIgnored;
  LErr := PipeFileWrite(FFd, @ABuf, ACount, LWritten);
  if LErr <> 0 then
    raise PipeSystemError('TPipeWriter.Write', LErr);
  Result := LWritten;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LWritten := 0;
  if not WriteFile(HANDLE(FFd), @ABuf, DWORD(ACount), @LWritten, nil) then
    raise PipeSystemError('TPipeWriter.Write', Int32(GetLastError));
  Result := SizeUInt(LWritten);
  {$ENDIF}
end;

procedure TPipeWriter.Close;
var
  LCloseError: EIOError;
  {$IFDEF NEXTPAS_UNIX}LErr: Int32;{$ENDIF}
begin
  if FClosed then Exit;
  LCloseError := nil;
  {$IFDEF NEXTPAS_UNIX}
  LErr := PipeFileClose(FFd);
  if LErr <> 0 then
    LCloseError := PipeSystemError('TPipeWriter.Close', LErr);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  if FFd < 0 then
    LCloseError := PipeSystemError('TPipeWriter.Close', PLATFORM_ERR_BADF)
  else if not CloseHandle(HANDLE(FFd)) then
    LCloseError := PipeSystemError('TPipeWriter.Close', Int32(GetLastError));
  {$ENDIF}
  FClosed := True;
  if LCloseError <> nil then
    raise LCloseError;
end;

{$IFDEF NEXTPAS_UNIX}
function DrainReaderIndex(const APollFds: array of TPollFd; const ACount: Integer;
  const AHandle: PtrInt): Integer;
var
  I: Integer;
begin
  for I := 0 to ACount - 1 do
    if APollFds[I].fd = AHandle then
      Exit(I);
  Result := -1;
end;

function DrainReadHandle(const AHandle: PtrInt; var ATarget: string;
  var ACount: Integer; const AMaxTotal: Int64; const ASiblingCount: Integer;
  var ALimited: Boolean): Boolean;
var
  LBuf: array[0..PIPE_DRAIN_BUF_SIZE - 1] of Byte;
  LRead: PtrUInt;
  LErr: Int32;
begin
  { Parent pipe ends are blocking. After poll reports readability, one
    read is safe; looping until EAGAIN hangs while the child still holds
    the write end open. Callers re-enter via poll for remaining data. }
  if (AMaxTotal > 0) and (Int64(ACount) + Int64(ASiblingCount) >= AMaxTotal) then
  begin
    ALimited := True;
    Exit(False);
  end;
  LErr := PipeFileRead(AHandle, @LBuf[0], SizeOf(LBuf), LRead);
  if (LErr = 0) and (LRead > 0) then
  begin
    AppendPipeChunk(ATarget, ACount, LBuf[0], SizeInt(LRead), AMaxTotal,
      ASiblingCount, ALimited);
    Exit(False);
  end;
  if (LErr = 0) and (LRead = 0) then
    Exit(True); { EOF / peer closed write end }
  Exit(False); { error or transient; caller may retry }
end;

procedure DrainWithPoll(const AStdout, AStderr: IPipeDrainReader;
  const ATimeout: Int32; var AStdoutText, AStderrText: string;
  var AStdoutClosed, AStderrClosed: Boolean; const AMaxTotal: Int64;
  var ALimited: Boolean);
var
  LPollFds: array[0..1] of TPollFd;
  LPollCount: Integer;
  LPollResult: Int32;
  LStdoutLen, LStderrLen: Integer;
  LStdoutIndex, LStderrIndex: Integer;
begin
  if ALimited then
    Exit;
  LStdoutLen := Length(AStdoutText);
  LStderrLen := Length(AStderrText);
  LPollCount := 0;
  if (AStdout <> nil) and (not AStdoutClosed) then
  begin
    LPollFds[LPollCount].fd := AStdout.NativeHandle;
    LPollFds[LPollCount].events := POLLIN or POLLHUP;
    LPollFds[LPollCount].revents := 0;
    Inc(LPollCount);
  end;
  if (AStderr <> nil) and (not AStderrClosed) then
  begin
    LPollFds[LPollCount].fd := AStderr.NativeHandle;
    LPollFds[LPollCount].events := POLLIN or POLLHUP;
    LPollFds[LPollCount].revents := 0;
    Inc(LPollCount);
  end;
  if LPollCount = 0 then
    Exit;

  LPollResult := PipePoll(@LPollFds[0], LPollCount, ATimeout);
  if LPollResult < 0 then
    raise PipeSyscallError('DrainPipePair.poll');

  if LPollResult = 0 then
    Exit;

  if (AStdout <> nil) and (not AStdoutClosed) then
  begin
    LStdoutIndex := DrainReaderIndex(LPollFds, LPollCount, AStdout.NativeHandle);
    if (LStdoutIndex >= 0) and
      ((LPollFds[LStdoutIndex].revents and (POLLIN or POLLHUP or POLLERR or POLLNVAL)) <> 0) then
      AStdoutClosed := DrainReadHandle(AStdout.NativeHandle, AStdoutText, LStdoutLen,
        AMaxTotal, LStderrLen, ALimited);
  end;

  if ALimited then
    Exit;

  if (AStderr <> nil) and (not AStderrClosed) then
  begin
    LStderrIndex := DrainReaderIndex(LPollFds, LPollCount, AStderr.NativeHandle);
    if (LStderrIndex >= 0) and
      ((LPollFds[LStderrIndex].revents and (POLLIN or POLLHUP or POLLERR or POLLNVAL)) <> 0) then
      AStderrClosed := DrainReadHandle(AStderr.NativeHandle, AStderrText, LStderrLen,
        AMaxTotal, LStdoutLen, ALimited);
  end;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function DrainReadHandleWin(const AHandle: PtrInt; var ATarget: string;
  var ACount: Integer; const AMaxTotal: Int64; const ASiblingCount: Integer;
  var ALimited: Boolean): Boolean;
var
  LBuf: array[0..PIPE_DRAIN_BUF_SIZE - 1] of Byte;
  LAvail, LRead: DWORD;
  LOk: WINBOOL;
begin
  { Returns True when the stream is closed (EOF / broken pipe). }
  if (AMaxTotal > 0) and (Int64(ACount) + Int64(ASiblingCount) >= AMaxTotal) then
  begin
    ALimited := True;
    Exit(False);
  end;
  LAvail := 0;
  LOk := PeekNamedPipe(HANDLE(PtrUInt(AHandle)), nil, 0, nil, @LAvail, nil);
  if not LOk then
  begin
    LRead := GetLastError;
    if (LRead = ERROR_BROKEN_PIPE) or (LRead = ERROR_HANDLE_EOF) then
      Exit(True);
    Exit(False);
  end;
  if LAvail = 0 then
    Exit(False);
  LRead := 0;
  if not ReadFile(HANDLE(PtrUInt(AHandle)), @LBuf[0],
    DWORD(SizeOf(LBuf)), @LRead, nil) then
  begin
    LRead := GetLastError;
    if (LRead = ERROR_BROKEN_PIPE) or (LRead = ERROR_HANDLE_EOF) then
      Exit(True);
    Exit(False);
  end;
  if LRead = 0 then
    Exit(True);
  AppendPipeChunk(ATarget, ACount, LBuf[0], SizeInt(LRead), AMaxTotal,
    ASiblingCount, ALimited);
  Result := False;
end;

procedure DrainWithPeek(const AStdout, AStderr: IPipeDrainReader;
  var AStdoutText, AStderrText: string;
  var AStdoutClosed, AStderrClosed: Boolean; const AMaxTotal: Int64;
  var ALimited: Boolean);
var
  LStdoutLen, LStderrLen: Integer;
begin
  if ALimited then
    Exit;
  LStdoutLen := Length(AStdoutText);
  LStderrLen := Length(AStderrText);
  if (AStdout <> nil) and (not AStdoutClosed) then
    AStdoutClosed := DrainReadHandleWin(AStdout.NativeHandle, AStdoutText,
      LStdoutLen, AMaxTotal, LStderrLen, ALimited);
  if ALimited then
    Exit;
  LStdoutLen := Length(AStdoutText);
  LStderrLen := Length(AStderrText);
  if (AStderr <> nil) and (not AStderrClosed) then
    AStderrClosed := DrainReadHandleWin(AStderr.NativeHandle, AStderrText,
      LStderrLen, AMaxTotal, LStdoutLen, ALimited);
end;
{$ENDIF}

procedure DrainPipePair(const AStdout, AStderr: IReader; const ATimeout: Int32;
  var AStdoutText, AStderrText: string; var AStdoutClosed, AStderrClosed: Boolean;
  const AMaxTotal: Int64; var ALimited: Boolean);
var
  LStdoutDrain: IPipeDrainReader;
  LStderrDrain: IPipeDrainReader;
  LStdoutBuf: array[0..PIPE_DRAIN_BUF_SIZE - 1] of Byte;
  LStderrBuf: array[0..PIPE_DRAIN_BUF_SIZE - 1] of Byte;
  LRead: SizeUInt;
  LStdoutLen, LStderrLen: Integer;
begin
  LRead := 0;
  if ALimited then
    Exit;

  LStdoutDrain := nil;
  LStderrDrain := nil;

  if (AStdout <> nil) and (not AStdoutClosed) then
    nextpas.core.base.utils.Supports(AStdout, IPipeDrainReader, LStdoutDrain);
  if (AStderr <> nil) and (not AStderrClosed) then
    nextpas.core.base.utils.Supports(AStderr, IPipeDrainReader, LStderrDrain);

  {$IFDEF NEXTPAS_UNIX}
  if (LStdoutDrain <> nil) or (LStderrDrain <> nil) then
  begin
    DrainWithPoll(LStdoutDrain, LStderrDrain, ATimeout, AStdoutText, AStderrText,
      AStdoutClosed, AStderrClosed, AMaxTotal, ALimited);
    Exit;
  end;
  {$ENDIF}

  {$IFDEF NEXTPAS_WINDOWS}
  if (LStdoutDrain <> nil) or (LStderrDrain <> nil) then
  begin
    DrainWithPeek(LStdoutDrain, LStderrDrain, AStdoutText, AStderrText,
      AStdoutClosed, AStderrClosed, AMaxTotal, ALimited);
    Exit;
  end;
  {$ENDIF}

  LStdoutLen := Length(AStdoutText);
  if (AStdout <> nil) and (not AStdoutClosed) and (not ALimited) then
  repeat
    LRead := AStdout.Read(LStdoutBuf[0], SizeOf(LStdoutBuf));
    if LRead > 0 then
      if not AppendPipeChunk(AStdoutText, LStdoutLen, LStdoutBuf[0], LRead,
        AMaxTotal, Length(AStderrText), ALimited) then
        Break;
  until (LRead = 0) or ALimited;
  AStdoutClosed := (AStdout = nil) or AStdoutClosed or (LRead = 0) or ALimited;

  LStderrLen := Length(AStderrText);
  if (AStderr <> nil) and (not AStderrClosed) and (not ALimited) then
  repeat
    LRead := AStderr.Read(LStderrBuf[0], SizeOf(LStderrBuf));
    if LRead > 0 then
      if not AppendPipeChunk(AStderrText, LStderrLen, LStderrBuf[0], LRead,
        AMaxTotal, Length(AStdoutText), ALimited) then
        Break;
  until (LRead = 0) or ALimited;
  AStderrClosed := (AStderr = nil) or AStderrClosed or (LRead = 0) or ALimited;
end;

end.
