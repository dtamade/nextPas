program test_http_examples;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.net,
  nextpas.core.http,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.time.sleep,
  nextpas.core.path,
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.process,
  nextpas.core.process.base,
  nextpas.core.process.pipe,
  nextpas.core.text.conv,
  nextpas.core.text.format;

var
  T: TTestSuite;
  GBuildRan: Boolean = False;
  GBuildExitCode: Integer = -1;
  GBuildOutput: string = '';
  GExampleDir: string = '';
  GExampleBinaryPath: string = '';

const
  ExampleRelativeDir =
    'examples/nextpas.core.http/http_server_options_demo';
  GetClientExampleRelativeDir =
    'examples/nextpas.core.http/http_get_client';
  HelloExampleRelativeDir =
    'examples/nextpas.core.http/http_hello_server';
  WebSocketExampleRelativeDir =
    'examples/nextpas.core.http/http_websocket_echo_demo';
  VfsDemoRelativeDir =
    'examples/nextpas.core.http/http_static_vfs_demo';
  HttpUnitPath = 'src/nextpas.core.http.pas';
  { POSIX signal numbers — same values as platform.signal, avoided as direct use. }
  SIGTERM_NUM = 15;
  SIGKILL_NUM = 9;

type
  { Long-running example server handle (IChild + drained stdout/stderr pipes). }
  TExampleChild = class
  private
    FChild: IChild;
    FStdout: IReader;
    FStderr: IReader;
    FStdoutClosed: Boolean;
    FStderrClosed: Boolean;
    FExited: Boolean;
    FExitCode: Integer;
  public
    constructor Create(const AChild: IChild);
    destructor Destroy; override;
    procedure AppendAvailableOutput(var AOutput: string);
    function Running: Boolean;
    procedure SignalTerm;
    procedure KillHard;
    procedure WaitDone(var AOutput: string);
    property ExitCode: Integer read FExitCode;
  end;

constructor TExampleChild.Create(const AChild: IChild);
begin
  inherited Create;
  FChild := AChild;
  FStdout := AChild.TakeStdout;
  FStderr := AChild.TakeStderr;
  FStdoutClosed := FStdout = nil;
  FStderrClosed := FStderr = nil;
  FExited := False;
  FExitCode := -1;
end;

destructor TExampleChild.Destroy;
begin
  if (FChild <> nil) and (not FExited) then
  begin
    try
      FChild.Kill;
    except
    end;
    try
      FChild.Wait;
    except
    end;
  end;
  FStdout := nil;
  FStderr := nil;
  FChild := nil;
  inherited;
end;

procedure TExampleChild.AppendAvailableOutput(var AOutput: string);
var
  LOut, LErr: string;
  LLimited: Boolean;
begin
  LOut := '';
  LErr := '';
  LLimited := False;
  { AMaxTotal=0: unlimited — this helper polls in a loop and appends per call }
  DrainPipePair(FStdout, FStderr, 10, LOut, LErr, FStdoutClosed, FStderrClosed,
    0, LLimited);
  if LOut <> '' then
    AOutput := AOutput + LOut;
  if LErr <> '' then
    AOutput := AOutput + LErr;
end;

function TExampleChild.Running: Boolean;
var
  LOut: TProcessOutput;
begin
  if FExited then
    Exit(False);
  if FChild.TryWait(LOut) then
  begin
    FExited := True;
    FExitCode := LOut.ExitCode;
    Exit(False);
  end;
  Result := True;
end;

procedure TExampleChild.SignalTerm;
begin
  if (FChild = nil) or FExited then
    Exit;
  FChild.Signal(SIGTERM_NUM);
end;

procedure TExampleChild.KillHard;
begin
  if (FChild = nil) or FExited then
    Exit;
  FChild.Kill;
end;

procedure TExampleChild.WaitDone(var AOutput: string);
var
  LOut: TProcessOutput;
begin
  AppendAvailableOutput(AOutput);
  if FExited then
    Exit;
  LOut := FChild.Wait;
  FExited := True;
  FExitCode := LOut.ExitCode;
  AppendAvailableOutput(AOutput);
end;

function PathJoin(const ALeft, ARight: string): string;
begin
  if ALeft = '' then
    Exit(ARight);
  Result := IncludeTrailingPathDelimiter(ALeft) + ARight;
end;

function RepeatChar(const ACh: Char; const ACount: Integer): string;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  for I := 1 to ACount do
    Result[I] := ACh;
end;

function TryResolveCoreRootFrom(const AStartDir, AExampleRelativeDir: string;
  out ARootDir: string): Boolean;
var
  LDir: string;
  LParent: string;
  I: Integer;
begin
  Result := False;
  LDir := ExcludeTrailingPathDelimiter(ExpandFileName(AStartDir));
  if LDir = '' then
    Exit;

  for I := 0 to 8 do
  begin
    if FileExists(PathJoin(LDir, HttpUnitPath)) and
      DirectoryExists(PathJoin(LDir, AExampleRelativeDir)) then
    begin
      ARootDir := LDir;
      Exit(True);
    end;

    LParent := ExtractFileDir(LDir);
    if LParent = LDir then
      Break;
    LDir := LParent;
  end;
end;

function ResolveCoreRoot(const AExampleRelativeDir: string): string;
begin
  if TryResolveCoreRootFrom(GetCurrentDir, AExampleRelativeDir, Result) then
    Exit;
  if TryResolveCoreRootFrom(ExtractFileDir(ExpandFileName(ParamStr(0))),
    AExampleRelativeDir, Result) then
    Exit;
  Fail('unable to resolve core root from current directory or executable path');
end;

function ResolveMakeExecutable: string;
begin
  Result := Trim(GetEnv('MAKE'));
  if Result = '' then
    Result := 'make';
end;

procedure ApplyEnvPairs(const ACmd: ICommand;
  const AEnvironment: array of string);
var
  I, LEq: Integer;
  LPair, LKey, LValue: string;
begin
  for I := Low(AEnvironment) to High(AEnvironment) do
  begin
    LPair := AEnvironment[I];
    LEq := Pos('=', LPair);
    if LEq <= 1 then
      Continue;
    LKey := Copy(LPair, 1, LEq - 1);
    LValue := Copy(LPair, LEq + 1, Length(LPair) - LEq);
    ACmd.EnvAdd(LKey, LValue);
  end;
end;

procedure RunProcessAndCaptureWithEnv(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir: string;
  const AEnvironment: array of string; out AExitCode: Integer;
  out AOutput: string);
var
  LCmd: ICommand;
  LOut: TProcessOutput;
begin
  AExitCode := -1;
  AOutput := '';
  try
    LCmd := Command(AExecutable)
      .Args(AArguments)
      .Dir(AWorkingDir)
      .Stdout(stPiped)
      .Stderr(stPiped);
    ApplyEnvPairs(LCmd, AEnvironment);
    LOut := LCmd.Spawn.WaitWithOutput;
    AExitCode := LOut.ExitCode;
    AOutput := LOut.StdOut + LOut.StdErr;
  except
    on E: Exception do
    begin
      AExitCode := -1;
      AOutput := TextFormat('%s: %s', [E.ClassName, E.Message]);
    end;
  end;
end;

procedure RunProcessAndCapture(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir: string;
  out AExitCode: Integer; out AOutput: string);
begin
  RunProcessAndCaptureWithEnv(AExecutable, AArguments, AWorkingDir, [],
    AExitCode, AOutput);
end;

procedure CheckContains(const AOutput, AFragment, ALabel: string);
begin
  Check(Pos(AFragment, AOutput) > 0,
    ALabel + ' missing from output: ' + AFragment + LineEnding + AOutput);
end;

function ResolveExampleBinaryPath(const AExampleDir: string): string;
begin
  Result := PathJoin(ResolveCoreRoot(ExampleRelativeDir),
    'build/projects/nextpas.core.http/http_server_options_demo/http_server_options_demo');
end;

procedure EnsureExampleBuilt;
begin
  if GBuildRan then
    Exit;

  GExampleDir := PathJoin(ResolveCoreRoot(ExampleRelativeDir), ExampleRelativeDir);
  Check(DirectoryExists(GExampleDir), 'example directory exists');
  RunProcessAndCapture(ResolveMakeExecutable, ['build'], GExampleDir,
    GBuildExitCode, GBuildOutput);
  GBuildRan := True;
  GExampleBinaryPath := ResolveExampleBinaryPath(GExampleDir);
end;

function ReserveLoopbackPort: UInt16;
var
  LListener: ITcpListener;
begin
  LListener := TcpListen('127.0.0.1', 0);
  Result := LListener.LocalAddr.Port;
  LListener := nil;
  Check(Result > 0, 'reserved loopback port');
end;

function ReadReaderStr(const AReader: IReader): string;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  if AReader = nil then
    Exit;
  repeat
    LN := AReader.Read(LBuf[0], 4096);
    if LN > 0 then
    begin
      SetLength(Result, Length(Result) + Int32(LN));
      Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
    end;
  until LN = 0;
end;

function ReadBodyStr(const AResp: IHttpResponse): string;
begin
  if AResp.Body = nil then
    Exit('');
  Result := ReadReaderStr(AResp.Body);
end;

function StringBodyReader(const AValue: string): IReader;
var
  LData: TBytes;
begin
  SetLength(LData, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], LData[0], Length(AValue));
  Result := CreateBytesStreamFrom(LData) as IReader;
end;

function BuildMaskedTextFrame(const AData: string): string;
var
  LMaskKey: array[0..3] of Byte;
  LPayloadLen: SizeUInt;
  I: SizeUInt;
begin
  LMaskKey[0] := $12;
  LMaskKey[1] := $34;
  LMaskKey[2] := $56;
  LMaskKey[3] := $78;

  LPayloadLen := SizeUInt(Length(AData));
  Check(LPayloadLen < 126, 'example websocket smoke uses short frames');
  SetLength(Result, 6);
  Result[1] := Chr($81);
  Result[2] := Chr($80 or Byte(LPayloadLen));
  Result[3] := Chr(LMaskKey[0]);
  Result[4] := Chr(LMaskKey[1]);
  Result[5] := Chr(LMaskKey[2]);
  Result[6] := Chr(LMaskKey[3]);

  for I := 1 to LPayloadLen do
    Result := Result + Chr(Ord(AData[I]) xor LMaskKey[(I - 1) mod 4]);
end;

function ReadTcpUntilContains(const AConn: ITcpStream; const AMarker: string): string;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  repeat
    LN := AConn.Read(LBuf[0], 4096);
    if LN > 0 then
    begin
      SetLength(Result, Length(Result) + Int32(LN));
      Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
    end;
  until (Pos(AMarker, Result) > 0) or (LN = 0);
end;

function ReadServerTextFramePayload(const AConn: ITcpStream): string;
var
  LBuf: array[0..4095] of Byte;
  LResp: string;
  LN: SizeUInt;
  LPayloadLen: Byte;
begin
  LResp := '';
  repeat
    LN := AConn.Read(LBuf[0], 4096);
    if LN > 0 then
    begin
      SetLength(LResp, Length(LResp) + Int32(LN));
      Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
    end;
  until (Length(LResp) >= 2) or (LN = 0);

  Check(Length(LResp) >= 2, 'websocket echo demo returned a frame header');
  Check(Ord(LResp[1]) = $81, 'websocket echo demo returned text frame');
  LPayloadLen := Ord(LResp[2]) and $7F;
  Check(LPayloadLen < 126, 'websocket echo demo returned short text frame');
  while Length(LResp) < 2 + LPayloadLen do
  begin
    LN := AConn.Read(LBuf[0], 4096);
    if LN = 0 then
      Break;
    SetLength(LResp, Length(LResp) + Int32(LN));
    Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
  end;
  Check(Length(LResp) >= 2 + LPayloadLen,
    'websocket echo demo returned full text frame payload');
  Result := Copy(LResp, 3, LPayloadLen);
end;

procedure StopExampleServer(var AProcess: TExampleChild; var AOutput: string);
var
  LWait: Integer;
begin
  if AProcess = nil then
    Exit;

  if AProcess.Running then
  begin
    AProcess.SignalTerm;

    for LWait := 0 to 99 do
    begin
      AProcess.AppendAvailableOutput(AOutput);
      if not AProcess.Running then
        Break;
      TSleep.ForDuration(TDuration.FromMilliseconds(10));
    end;

    if AProcess.Running then
    begin
      AProcess.KillHard;
      for LWait := 0 to 99 do
      begin
        AProcess.AppendAvailableOutput(AOutput);
        if not AProcess.Running then
          Break;
        TSleep.ForDuration(TDuration.FromMilliseconds(10));
      end;
    end;
  end;

  AProcess.WaitDone(AOutput);
  AProcess.Free;
  AProcess := nil;
end;

function SpawnExampleChild(const ABinaryPath, AExampleDir: string;
  const AArguments: array of string): TExampleChild;
var
  LChild: IChild;
begin
  LChild := Command(ABinaryPath)
    .Args(AArguments)
    .Dir(AExampleDir)
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn;
  Result := TExampleChild.Create(LChild);
end;

function MakeUrl(const APort: UInt16; const APath: string): string;
begin
  Result := 'http://127.0.0.1:' + IntToStr(Int64(APort)) + APath;
end;

procedure WaitForReadyMarkers(AProcess: TExampleChild; var AOutput: string;
  const AReadyMarker, APortMarker, AFailLabel: string);
var
  LWait: Integer;
begin
  for LWait := 0 to 399 do
  begin
    AProcess.AppendAvailableOutput(AOutput);
    if (Pos(AReadyMarker, AOutput) > 0) and (Pos(APortMarker, AOutput) > 0) then
      Exit;
    if not AProcess.Running then
      Break;
    TSleep.ForDuration(TDuration.FromMilliseconds(10));
  end;
  StopExampleServer(AProcess, AOutput);
  Fail(AFailLabel + LineEnding + AOutput);
end;

{ Examples print ready markers before ListenAndServe binds. Poll with a real
  HTTP GET so readiness means "serving", not only "TCP accept works". }
procedure WaitUntilHttpReady(const APort: UInt16; const APath: string;
  AProcess: TExampleChild; var AOutput: string; const AFailLabel: string);
var
  LWait: Integer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LClient := NewHttpClient;
  for LWait := 0 to 399 do
  begin
    AProcess.AppendAvailableOutput(AOutput);
    if not AProcess.Running then
      Break;
    try
      LResp := LClient.Get(MakeUrl(APort, APath));
      if (LResp <> nil) and (LResp.StatusCode > 0) and (LResp.StatusCode < 500) then
        Exit;
    except
      on E: Exception do
        { keep polling until listen/handler is ready }
        ;
    end;
    TSleep.ForDuration(TDuration.FromMilliseconds(10));
  end;
  StopExampleServer(AProcess, AOutput);
  Fail(AFailLabel + LineEnding + AOutput);
end;

procedure StartExampleServer(const APort: UInt16; out AProcess: TExampleChild;
  out AOutput: string);
var
  LReadyMarker: string;
  LPortMarker: string;
begin
  EnsureExampleBuilt;
  CheckEqual(Int64(0), Int64(GBuildExitCode), 'example build exit code');
  Check(FileExists(GExampleBinaryPath), 'example binary exists after build');

  LReadyMarker := 'http-server-options-demo=ready';
  LPortMarker := 'listen=127.0.0.1:' + IntToStr(Int64(APort));
  AOutput := '';
  AProcess := nil;
  try
    AProcess := SpawnExampleChild(GExampleBinaryPath, GExampleDir,
      ['threaded', IntToStr(Int64(APort))]);
  except
    on E: Exception do
      Fail('unable to start example server: ' + E.ClassName + ': ' + E.Message);
  end;
  WaitForReadyMarkers(AProcess, AOutput, LReadyMarker, LPortMarker,
    'example server did not reach ready state');
  WaitUntilHttpReady(APort, '/health', AProcess, AOutput,
    'example server did not serve HTTP after ready markers');
end;

procedure TestServerOptionsDemoBuilds;
begin
  EnsureExampleBuilt;
  CheckEqual(Int64(0), Int64(GBuildExitCode), 'example build exit code');
  Check(FileExists(GExampleBinaryPath), 'example binary exists');
end;

procedure TestServerOptionsDemoServesDocumentedEndpoints;
var
  LPort: UInt16;
  LProcess: TExampleChild;
  LStartupOutput: string;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LProcess := nil;
  LStartupOutput := '';
  LPort := ReserveLoopbackPort;
  StartExampleServer(LPort, LProcess, LStartupOutput);
  try
    CheckContains(LStartupOutput, 'backend=threaded', 'startup backend marker');
    CheckContains(LStartupOutput, 'max-body-size=64', 'startup max-body-size marker');

    LClient := NewHttpClient;

    LResp := LClient.Get(MakeUrl(LPort, '/health'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'health status 200');
    LBody := ReadBodyStr(LResp);
    CheckContains(LBody, 'backend=threaded', 'health backend marker');
    CheckContains(LBody, 'write-timeout-ms=5000', 'health timeout marker');
    CheckContains(LBody, 'max-header-size=1024', 'health header limit marker');
    CheckContains(LBody, 'max-body-size=64', 'health body limit marker');

    LResp := LClient.Get(MakeUrl(LPort, '/hello/world'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'hello status 200');
    LBody := ReadBodyStr(LResp);
    CheckContains(LBody, 'hello=world', 'hello body marker');
    CheckContains(LBody, 'backend=threaded', 'hello backend marker');

    LResp := LClient.Post(MakeUrl(LPort, '/echo'), 'text/plain', 'hello');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'echo status 200');
    LBody := ReadBodyStr(LResp);
    CheckContains(LBody, 'bytes=5', 'echo byte count marker');
    CheckContains(LBody, 'body=hello', 'echo body marker');
    CheckContains(LBody, 'max-body-size=64', 'echo limit marker');

    LResp := LClient.Post(MakeUrl(LPort, '/echo'), 'text/plain',
      RepeatChar('x', 65));
    CheckEqual(Int64(413), Int64(LResp.StatusCode), 'oversize payload rejected');
    LBody := ReadBodyStr(LResp);
    Check(Pos('bytes=', LBody) = 0,
      'oversize rejection should not come from echo handler body');
  finally
    StopExampleServer(LProcess, LStartupOutput);
  end;
end;

function ResolveWebSocketExampleBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/http_websocket_echo_demo/http_websocket_echo_demo');
end;

function ResolveHelloExampleBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/http_hello_server/hello_http_server');
end;

function ResolveGetClientExampleBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/http_get_client/http_get_client');
end;

procedure BuildHelloExample(out ABinaryPath: string; out AExampleDir: string);
var
  LRootDir: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(HelloExampleRelativeDir);
  AExampleDir := PathJoin(LRootDir, HelloExampleRelativeDir);
  Check(DirectoryExists(AExampleDir), 'hello example directory exists');
  RunProcessAndCapture(ResolveMakeExecutable, ['build'], AExampleDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'hello example build exit code: ' + LOutput);
  ABinaryPath := ResolveHelloExampleBinaryPath(LRootDir);
  Check(FileExists(ABinaryPath), 'hello example binary exists');
end;

procedure BuildGetClientExample(out ABinaryPath: string; out AExampleDir: string);
var
  LRootDir: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(GetClientExampleRelativeDir);
  AExampleDir := PathJoin(LRootDir, GetClientExampleRelativeDir);
  Check(DirectoryExists(AExampleDir), 'get client example directory exists');
  RunProcessAndCapture(ResolveMakeExecutable, ['build'], AExampleDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'get client example build exit code: ' + LOutput);
  ABinaryPath := ResolveGetClientExampleBinaryPath(LRootDir);
  Check(FileExists(ABinaryPath), 'get client example binary exists');
end;

procedure StartHelloExampleServer(const ABinaryPath, AExampleDir: string;
  const APort: UInt16; out AProcess: TExampleChild; out AOutput: string);
var
  LReadyMarker: string;
  LPortMarker: string;
begin
  LReadyMarker := 'http-hello-server=ready';
  LPortMarker := 'listen=127.0.0.1:' + IntToStr(Int64(APort));
  AOutput := '';
  AProcess := nil;
  try
    AProcess := SpawnExampleChild(ABinaryPath, AExampleDir,
      [IntToStr(Int64(APort))]);
  except
    on E: Exception do
      Fail('unable to start hello example: ' + E.ClassName + ': ' + E.Message);
  end;
  WaitForReadyMarkers(AProcess, AOutput, LReadyMarker, LPortMarker,
    'hello example did not reach ready state');
  WaitUntilHttpReady(APort, '/hello/world?page=2', AProcess, AOutput,
    'hello example did not serve HTTP after ready markers');
end;

procedure TestHelloServerExampleServesDocumentedEndpoint;
var
  LBinaryPath: string;
  LExampleDir: string;
  LPort: UInt16;
  LProcess: TExampleChild;
  LStartupOutput: string;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LProcess := nil;
  LStartupOutput := '';
  BuildHelloExample(LBinaryPath, LExampleDir);
  LPort := ReserveLoopbackPort;
  StartHelloExampleServer(LBinaryPath, LExampleDir, LPort, LProcess,
    LStartupOutput);
  try
    CheckContains(LStartupOutput,
      'example=http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/hello/world?page=2',
      'hello example startup URL');
    LClient := NewHttpClient;
    LResp := LClient.Get(MakeUrl(LPort, '/hello/world?page=2'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'hello example status 200');
    LBody := ReadBodyStr(LResp);
    CheckContains(LBody, 'hello=world', 'hello example path param marker');
    CheckContains(LBody, 'page=2', 'hello example query marker');
    CheckContains(LBody, 'path=/hello/world', 'hello example path marker');
  finally
    StopExampleServer(LProcess, LStartupOutput);
  end;
end;

procedure TestGetClientExampleUsesEnvUrlWithoutFixedPort;
var
  LHelloBinaryPath: string;
  LHelloExampleDir: string;
  LClientBinaryPath: string;
  LClientExampleDir: string;
  LPort: UInt16;
  LProcess: TExampleChild;
  LStartupOutput: string;
  LExitCode: Integer;
  LOutput: string;
  LUrl: string;
begin
  LProcess := nil;
  LStartupOutput := '';
  BuildHelloExample(LHelloBinaryPath, LHelloExampleDir);
  BuildGetClientExample(LClientBinaryPath, LClientExampleDir);
  LPort := ReserveLoopbackPort;
  StartHelloExampleServer(LHelloBinaryPath, LHelloExampleDir, LPort, LProcess,
    LStartupOutput);
  try
    LUrl := MakeUrl(LPort, '/hello/world?page=3');
    RunProcessAndCaptureWithEnv(LClientBinaryPath, [], LClientExampleDir,
      ['NEXTPAS_HTTP_GET_URL=' + LUrl], LExitCode, LOutput);
    CheckEqual(Int64(0), Int64(LExitCode),
      'get client env URL smoke exit code: ' + LOutput);
    CheckContains(LOutput, 'url=' + LUrl, 'get client env URL marker');
    CheckContains(LOutput, 'status-code=200', 'get client status marker');
    CheckContains(LOutput, 'hello=world', 'get client body path marker');
    CheckContains(LOutput, 'page=3', 'get client body query marker');
  finally
    StopExampleServer(LProcess, LStartupOutput);
  end;
end;

procedure BuildWebSocketExample(out ABinaryPath: string; out AExampleDir: string);
var
  LRootDir: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(WebSocketExampleRelativeDir);
  AExampleDir := PathJoin(LRootDir, WebSocketExampleRelativeDir);
  Check(DirectoryExists(AExampleDir), 'websocket example directory exists');
  RunProcessAndCapture(ResolveMakeExecutable, ['build'], AExampleDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'websocket example build exit code: ' + LOutput);
  ABinaryPath := ResolveWebSocketExampleBinaryPath(LRootDir);
  Check(FileExists(ABinaryPath), 'websocket example binary exists');
end;

procedure StartWebSocketExampleServer(const ABinaryPath, AExampleDir: string;
  const APort: UInt16; out AProcess: TExampleChild; out AOutput: string);
var
  LReadyMarker: string;
  LPortMarker: string;
begin
  LReadyMarker := 'http-websocket-echo-demo=ready';
  LPortMarker := 'listen=127.0.0.1:' + IntToStr(Int64(APort));
  AOutput := '';
  AProcess := nil;
  try
    AProcess := SpawnExampleChild(ABinaryPath, AExampleDir,
      [IntToStr(Int64(APort))]);
  except
    on E: Exception do
      Fail('unable to start websocket example: ' + E.ClassName + ': ' + E.Message);
  end;
  WaitForReadyMarkers(AProcess, AOutput, LReadyMarker, LPortMarker,
    'websocket example did not reach ready state');
  WaitUntilHttpReady(APort, '/health', AProcess, AOutput,
    'websocket example did not serve HTTP after ready markers');
end;

procedure TestWebSocketEchoDemoServesDocumentedEndpoint;
var
  LBinaryPath: string;
  LExampleDir: string;
  LPort: UInt16;
  LProcess: TExampleChild;
  LStartupOutput: string;
  LConn: ITcpStream;
  LReq: string;
  LHandshakeResp: string;
  LFrame: string;
  LPayload: string;
begin
  LProcess := nil;
  LStartupOutput := '';
  BuildWebSocketExample(LBinaryPath, LExampleDir);
  LPort := ReserveLoopbackPort;
  StartWebSocketExampleServer(LBinaryPath, LExampleDir, LPort, LProcess,
    LStartupOutput);
  try
    CheckContains(LStartupOutput, 'try-websocket=', 'startup websocket marker');
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    try
      LReq := 'GET /ws HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Upgrade: websocket'#13#10 +
        'Connection: Upgrade'#13#10 +
        'Origin: http://127.0.0.1'#13#10 +
        'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=='#13#10 +
        'Sec-WebSocket-Version: 13'#13#10 +
        #13#10;
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LHandshakeResp := ReadTcpUntilContains(LConn, #13#10#13#10);
      CheckContains(LHandshakeResp, 'HTTP/1.1 101',
        'websocket echo demo handshake');

      LFrame := BuildMaskedTextFrame('hello');
      LConn.Write(LFrame[1], SizeUInt(Length(LFrame)));
      LPayload := ReadServerTextFramePayload(LConn);
      CheckEqual('echo=hello', LPayload, 'websocket echo demo payload');
    finally
      LConn.Close;
    end;
  finally
    StopExampleServer(LProcess, LStartupOutput);
  end;
end;

{ 嵌入资源端到端 demo：make run 自含构建（rp_pack 生成 .inc）+ 起真 server
  自检 200/304/206/404/目录 404 后自行退出，断言退出码与自检标记即可。 }
procedure TestVfsStaticDemoEndToEndSelfCheck;
var
  LExampleDir: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LExampleDir := PathJoin(ResolveCoreRoot(ExampleRelativeDir), VfsDemoRelativeDir);
  Check(DirectoryExists(LExampleDir), 'vfs static demo directory exists');
  RunProcessAndCapture(ResolveMakeExecutable, ['run'], LExampleDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'vfs static demo self-check exit code: ' + LOutput);
  CheckContains(LOutput, 'backend: embedded', 'embedded backend selected');
  CheckContains(LOutput, 'self-check: all requests OK',
    'end-to-end asset serving verified');
end;

begin
  T := TTestSuite.Create('http examples');
  T.Test('server options demo builds', @TestServerOptionsDemoBuilds);
  T.Test('server options demo serves documented endpoints',
    @TestServerOptionsDemoServesDocumentedEndpoints);
  T.Test('hello server example serves documented endpoint',
    @TestHelloServerExampleServesDocumentedEndpoint);
  T.Test('get client example uses env URL without fixed port',
    @TestGetClientExampleUsesEnvUrlWithoutFixedPort);
  T.Test('websocket echo demo serves documented endpoint',
    @TestWebSocketEchoDemoServesDocumentedEndpoint);
  T.Test('vfs static demo end-to-end self-check',
    @TestVfsStaticDemoEndToEndSelfCheck);
  if not T.Run then Halt(1);
end.
