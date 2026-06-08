program test_poller_windows_runtime_smoke;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.io.poller
  , nextpas.core.io.reactor.iocp
  , nextpas.core.platform.windows.base
  , nextpas.core.platform.windows.ffi
  {$ENDIF}
  ;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}
var
  GCallbackCount: Int32;
  GLastResult: Int32;
  GLastUserData: UInt64;

procedure OnComplete(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GCallbackCount);
  GLastResult := AResult;
  GLastUserData := AUserData;
end;

function TempSmokePath: UnicodeString;
var
  LBuf: array[0..MAX_PATH - 1] of WideChar;
  LLen: DWORD;
begin
  LLen := GetTempPathW(MAX_PATH, @LBuf[0]);
  Check((LLen > 0) and (LLen < MAX_PATH), 'GetTempPathW');
  SetString(Result, PWideChar(@LBuf[0]), LLen);
  Result := Result + 'nextpas-iocp-runtime-smoke-' +
    UnicodeString(IntToStr(GetCurrentProcessId)) + '.tmp';
end;

procedure DrainOneCompletion(var AReactor: TIocpReactor; const APhase: string);
var
  LSpin: Int32;
begin
  LSpin := 0;
  while (GCallbackCount = 0) and (LSpin < 100000) do
  begin
    AReactor.PollOne;
    Inc(LSpin);
  end;
  CheckEqual(Int64(1), Int64(GCallbackCount), APhase + ' callback once');
end;

procedure DrainOnePollerCompletion(var APoller: TPoller; const APhase: string);
var
  LSpin: Int32;
begin
  LSpin := 0;
  while (GCallbackCount = 0) and (LSpin < 100000) do
  begin
    APoller.PollOne;
    Inc(LSpin);
  end;
  CheckEqual(Int64(1), Int64(GCallbackCount), APhase + ' callback once');
end;

procedure TestIocpFileReadWriteRuntimeSmoke;
var
  LPath: UnicodeString;
  LHandle: HANDLE;
  LReactor: TIocpReactor;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf: array[0..3] of Byte;
begin
  LPath := TempSmokePath;
  LHandle := CreateFileW(PWideChar(LPath),
    GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil,
    CREATE_ALWAYS,
    FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_OVERLAPPED or FILE_FLAG_DELETE_ON_CLOSE,
    nil);
  Check(LHandle <> HANDLE(PtrInt(INVALID_HANDLE_VALUE)), 'CreateFileW overlapped');

  LReactor := TIocpReactor.Create(8);
  try
    Check(LReactor.IsValid, 'IOCP reactor valid');

    LWriteBuf[0] := $4E;
    LWriteBuf[1] := $50;
    LWriteBuf[2] := $43;
    LWriteBuf[3] := $50;
    GCallbackCount := 0;
    GLastResult := 0;
    GLastUserData := 0;
    Check(LReactor.AsyncWrite(PtrInt(LHandle), @LWriteBuf[0], 4, 0,
      @OnComplete, nil), 'AsyncWrite submit');
    DrainOneCompletion(LReactor, 'write');
    CheckEqual(Int64(4), Int64(GLastResult), 'write byte count');
    Check(GLastUserData <> 0, 'write userdata assigned');

    FillChar(LReadBuf, SizeOf(LReadBuf), 0);
    GCallbackCount := 0;
    GLastResult := 0;
    GLastUserData := 0;
    Check(LReactor.AsyncRead(PtrInt(LHandle), @LReadBuf[0], 4, 0,
      @OnComplete, nil), 'AsyncRead submit');
    DrainOneCompletion(LReactor, 'read');
    CheckEqual(Int64(4), Int64(GLastResult), 'read byte count');
    Check((LReadBuf[0] = $4E) and (LReadBuf[1] = $50) and
      (LReadBuf[2] = $43) and (LReadBuf[3] = $50), 'read data matches');
    Check(GLastUserData <> 0, 'read userdata assigned');
  finally
    LReactor.Close;
    CloseHandle(LHandle);
    DeleteFileW(PWideChar(LPath));
  end;
end;

procedure TestPollerFileReadWriteRuntimeSmoke;
var
  LPath: UnicodeString;
  LHandle: HANDLE;
  LPoller: TPoller;
  LWriteBuf: array[0..3] of Byte;
  LReadBuf: array[0..3] of Byte;
begin
  LPath := TempSmokePath;
  LHandle := CreateFileW(PWideChar(LPath),
    GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil,
    CREATE_ALWAYS,
    FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_OVERLAPPED or FILE_FLAG_DELETE_ON_CLOSE,
    nil);
  Check(LHandle <> HANDLE(PtrInt(INVALID_HANDLE_VALUE)), 'CreateFileW poller overlapped');

  LPoller := TPoller.Create(8);
  try
    Check(LPoller.IsValid, 'poller valid');
    Check(LPoller.Backend = pbIocp, 'poller uses IOCP backend on Windows');

    LWriteBuf[0] := $50;
    LWriteBuf[1] := $4F;
    LWriteBuf[2] := $4C;
    LWriteBuf[3] := $4C;
    GCallbackCount := 0;
    GLastResult := 0;
    GLastUserData := 0;
    Check(LPoller.AsyncWrite(PtrInt(LHandle), @LWriteBuf[0], 4, 0,
      @OnComplete, nil), 'poller AsyncWrite submit');
    DrainOnePollerCompletion(LPoller, 'poller write');
    CheckEqual(Int64(4), Int64(GLastResult), 'poller write byte count');
    Check(GLastUserData <> 0, 'poller write userdata assigned');

    FillChar(LReadBuf, SizeOf(LReadBuf), 0);
    GCallbackCount := 0;
    GLastResult := 0;
    GLastUserData := 0;
    Check(LPoller.AsyncRead(PtrInt(LHandle), @LReadBuf[0], 4, 0,
      @OnComplete, nil), 'poller AsyncRead submit');
    DrainOnePollerCompletion(LPoller, 'poller read');
    CheckEqual(Int64(4), Int64(GLastResult), 'poller read byte count');
    Check((LReadBuf[0] = $50) and (LReadBuf[1] = $4F) and
      (LReadBuf[2] = $4C) and (LReadBuf[3] = $4C), 'poller read data matches');
    Check(GLastUserData <> 0, 'poller read userdata assigned');
  finally
    LPoller.Close;
    CloseHandle(LHandle);
    DeleteFileW(PWideChar(LPath));
  end;
end;
{$ELSE}
procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.io.poller.windows_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('IOCP file AsyncRead/AsyncWrite runtime smoke',
    @TestIocpFileReadWriteRuntimeSmoke);
  T.Run('poller file AsyncRead/AsyncWrite runtime smoke',
    @TestPollerFileReadWriteRuntimeSmoke);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.
