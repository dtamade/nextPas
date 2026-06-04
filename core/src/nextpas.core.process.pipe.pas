unit nextpas.core.process.pipe;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf;

type
  { TPipeReader — IReader 包装一个管道 fd (Unix) 或 HANDLE (Windows) }
  TPipeReader = class(TInterfacedObject, IReader)
  private
    FFd: PtrInt;
    FClosed: Boolean;
  public
    constructor Create(const AFd: PtrInt);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Fd: PtrInt read FFd;
  end;

  { TPipeWriter — IWriter 包装一个管道 fd }
  TPipeWriter = class(TInterfacedObject, IWriter)
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

implementation

uses
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

end.
