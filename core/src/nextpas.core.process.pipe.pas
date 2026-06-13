unit nextpas.core.process.pipe;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf;

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

procedure DrainPipePair(const AStdout, AStderr: IReader; const ATimeout: Int32;
  var AStdoutText, AStderrText: string; var AStdoutClosed, AStderrClosed: Boolean);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.platform.error,
  nextpas.core.text.conv,
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.unix.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.signal
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi
  {$ENDIF}
  ;

{$IFDEF NEXTPAS_UNIX}
var
  GSigPipeIgnorePid: pid_t = 0;
{$ENDIF}

const
  PIPE_DRAIN_BUF_SIZE = 65536;

procedure AppendPipeChunk(var ATarget: string; var ACount: Integer;
  const ABuf; const AChunkSize: SizeInt);
begin
  if AChunkSize <= 0 then
    Exit;
  SetLength(ATarget, ACount + Integer(AChunkSize));
  Move(ABuf, ATarget[ACount + 1], AChunkSize);
  Inc(ACount, Integer(AChunkSize));
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
  Result := PipeSystemError(AOperation, platform_get_errno);
end;

procedure EnsureSigPipeIgnored;
var
  LErr: Int32;
  LPid: pid_t;
begin
  {$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  LPid := getpid;
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
  {$IFDEF NEXTPAS_UNIX}LRead: ssize_t;{$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}LRead: DWORD;{$ENDIF}
begin
  if FClosed then
    raise PipeClosedError('TPipeReader.Read');
  if ACount = 0 then Exit(0);
  {$IFDEF NEXTPAS_UNIX}
  repeat
    LRead := nextpas.core.platform.posix.ffi.read(FFd, @ABuf, ACount);
    if LRead > 0 then
      Exit(SizeUInt(LRead));
    if LRead = 0 then
      Exit(0);
    if platform_get_errno = ESysEINTR then
      Continue;
    raise PipeSyscallError('TPipeReader.Read');
  until False;
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
begin
  if FClosed then Exit;
  LCloseError := nil;
  {$IFDEF NEXTPAS_UNIX}
  if nextpas.core.platform.posix.ffi.close(FFd) <> 0 then
    LCloseError := PipeSyscallError('TPipeReader.Close');
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  if not CloseHandle(HANDLE(FFd)) then
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
  {$IFDEF NEXTPAS_UNIX}LWritten: ssize_t;{$ENDIF}
  {$IFDEF NEXTPAS_UNIX}LTotal: SizeUInt;{$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}LWritten: DWORD;{$ENDIF}
begin
  if FClosed then
    raise PipeClosedError('TPipeWriter.Write');
  if ACount = 0 then Exit(0);
  {$IFDEF NEXTPAS_UNIX}
  EnsureSigPipeIgnored;
  LTotal := 0;
  repeat
    LWritten := nextpas.core.platform.posix.ffi.write(FFd,
      Pointer(PtrUInt(@ABuf) + LTotal), ACount - LTotal);
    if LWritten > 0 then
    begin
      Inc(LTotal, SizeUInt(LWritten));
      if LTotal = ACount then
        Exit(LTotal);
      Continue;
    end;
    if LWritten = 0 then
      raise EIOError.Create('TPipeWriter.Write failed (zero progress)');
    if platform_get_errno = ESysEINTR then
      Continue;
    raise PipeSyscallError('TPipeWriter.Write');
  until False;
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
begin
  if FClosed then Exit;
  LCloseError := nil;
  {$IFDEF NEXTPAS_UNIX}
  if nextpas.core.platform.posix.ffi.close(FFd) <> 0 then
    LCloseError := PipeSyscallError('TPipeWriter.Close');
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  if not CloseHandle(HANDLE(FFd)) then
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
  var ACount: Integer): Boolean;
var
  LBuf: array[0..PIPE_DRAIN_BUF_SIZE - 1] of Byte;
  LRead: ssize_t;
  LErr: Int32;
begin
  repeat
    LRead := nextpas.core.platform.posix.ffi.read(AHandle, @LBuf[0], SizeOf(LBuf));
    if LRead > 0 then
    begin
      AppendPipeChunk(ATarget, ACount, LBuf[0], LRead);
      Exit(False);
    end;
    if LRead = 0 then
      Exit(True);
    LErr := platform_get_errno;
    if LErr = ESysEINTR then
      Continue;
    if LErr = ESysEAGAIN then
      Exit(False);
    raise PipeSystemError('DrainPipePair.read', LErr);
  until False;
end;

procedure DrainWithPoll(const AStdout, AStderr: IPipeDrainReader;
  const ATimeout: Int32; var AStdoutText, AStderrText: string;
  var AStdoutClosed, AStderrClosed: Boolean);
var
  LPollFds: array[0..1] of TPollFd;
  LPollCount: Integer;
  LPollResult: Int32;
  LStdoutLen, LStderrLen: Integer;
  LStdoutIndex, LStderrIndex: Integer;
begin
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

  repeat
    LPollResult := poll(@LPollFds[0], LPollCount, ATimeout);
    if LPollResult >= 0 then
      Break;
    if platform_get_errno = ESysEINTR then
      Continue;
    raise PipeSyscallError('DrainPipePair.poll');
  until False;

  if LPollResult = 0 then
    Exit;

  if (AStdout <> nil) and (not AStdoutClosed) then
  begin
    LStdoutIndex := DrainReaderIndex(LPollFds, LPollCount, AStdout.NativeHandle);
    if (LStdoutIndex >= 0) and
      ((LPollFds[LStdoutIndex].revents and (POLLIN or POLLHUP or POLLERR or POLLNVAL)) <> 0) then
      AStdoutClosed := DrainReadHandle(AStdout.NativeHandle, AStdoutText, LStdoutLen);
  end;

  if (AStderr <> nil) and (not AStderrClosed) then
  begin
    LStderrIndex := DrainReaderIndex(LPollFds, LPollCount, AStderr.NativeHandle);
    if (LStderrIndex >= 0) and
      ((LPollFds[LStderrIndex].revents and (POLLIN or POLLHUP or POLLERR or POLLNVAL)) <> 0) then
      AStderrClosed := DrainReadHandle(AStderr.NativeHandle, AStderrText, LStderrLen);
  end;
end;
{$ENDIF}

procedure DrainPipePair(const AStdout, AStderr: IReader; const ATimeout: Int32;
  var AStdoutText, AStderrText: string; var AStdoutClosed, AStderrClosed: Boolean);
var
  LStdoutDrain: IPipeDrainReader;
  LStderrDrain: IPipeDrainReader;
  LStdoutBuf: array[0..PIPE_DRAIN_BUF_SIZE - 1] of Byte;
  LStderrBuf: array[0..PIPE_DRAIN_BUF_SIZE - 1] of Byte;
  LRead: SizeUInt;
  LStdoutLen, LStderrLen: Integer;
begin
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
      AStdoutClosed, AStderrClosed);
    Exit;
  end;
  {$ENDIF}

  LStdoutLen := Length(AStdoutText);
  if (AStdout <> nil) and (not AStdoutClosed) then
  repeat
    LRead := AStdout.Read(LStdoutBuf[0], SizeOf(LStdoutBuf));
    if LRead > 0 then
      AppendPipeChunk(AStdoutText, LStdoutLen, LStdoutBuf[0], LRead);
  until LRead = 0;
  AStdoutClosed := (AStdout = nil) or AStdoutClosed or (LRead = 0);

  LStderrLen := Length(AStderrText);
  if (AStderr <> nil) and (not AStderrClosed) then
  repeat
    LRead := AStderr.Read(LStderrBuf[0], SizeOf(LStderrBuf));
    if LRead > 0 then
      AppendPipeChunk(AStderrText, LStderrLen, LStderrBuf[0], LRead);
  until LRead = 0;
  AStderrClosed := (AStderr = nil) or AStderrClosed or (LRead = 0);
end;

end.
