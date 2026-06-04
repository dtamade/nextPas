program test_http_examples;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads, BaseUnix,{$ENDIF}
  Classes,
  Process,
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.net,
  nextpas.core.http;

var
  T: TTestRunner;
  GBuildRan: Boolean = False;
  GBuildExitCode: Integer = -1;
  GBuildOutput: string = '';
  GExampleDir: string = '';
  GExampleBinaryPath: string = '';

const
  ExampleRelativeDir =
    'examples/nextpas.core.http/http_server_options_demo';
  HttpUnitPath = 'src/nextpas.core.http.pas';

procedure AppendAvailableProcessOutput(AProcess: TProcess; var AOutput: string);
var
  LBuffer: array[0..2047] of Byte;
  LBytesRead: LongInt;
  LChunk: RawByteString;
begin
  while AProcess.Output.NumBytesAvailable > 0 do
  begin
    LBytesRead := AProcess.Output.Read(LBuffer, SizeOf(LBuffer));
    if LBytesRead <= 0 then
      Break;
    SetString(LChunk, PAnsiChar(@LBuffer[0]), LBytesRead);
    AOutput := AOutput + string(LChunk);
  end;
end;

function PathJoin(const ALeft, ARight: string): string;
begin
  if ALeft = '' then
    Exit(ARight);
  Result := IncludeTrailingPathDelimiter(ALeft) + ARight;
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
  Result := Trim(GetEnvironmentVariable('MAKE'));
  if Result = '' then
    Result := 'make';
end;

procedure RunProcessAndCapture(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir: string;
  out AExitCode: Integer; out AOutput: string);
var
  LProcess: TProcess;
  I: Integer;
begin
  AExitCode := -1;
  AOutput := '';
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := AExecutable;
    LProcess.CurrentDirectory := AWorkingDir;
    for I := Low(AArguments) to High(AArguments) do
      LProcess.Parameters.Add(AArguments[I]);
    LProcess.Options := [poUsePipes, poStderrToOutPut];
    LProcess.Execute;
    while LProcess.Running do
    begin
      AppendAvailableProcessOutput(LProcess, AOutput);
      Sleep(10);
    end;
    AppendAvailableProcessOutput(LProcess, AOutput);
    LProcess.WaitOnExit;
    AExitCode := LProcess.ExitCode;
  except
    on E: Exception do
    begin
      AExitCode := -1;
      AOutput := Format('%s: %s', [E.ClassName, E.Message]);
    end;
  end;
  LProcess.Free;
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

procedure StopExampleServer(var AProcess: TProcess; var AOutput: string);
var
  LWait: Integer;
begin
  if AProcess = nil then
    Exit;

  if AProcess.Running then
  begin
    {$IFDEF UNIX}
    fpKill(AProcess.ProcessID, SIGTERM);
    {$ELSE}
    AProcess.Terminate(0);
    {$ENDIF}

    for LWait := 0 to 99 do
    begin
      AppendAvailableProcessOutput(AProcess, AOutput);
      if not AProcess.Running then
        Break;
      Sleep(10);
    end;

    if AProcess.Running then
    begin
      {$IFDEF UNIX}
      fpKill(AProcess.ProcessID, SIGKILL);
      {$ELSE}
      AProcess.Terminate(1);
      {$ENDIF}
      for LWait := 0 to 99 do
      begin
        AppendAvailableProcessOutput(AProcess, AOutput);
        if not AProcess.Running then
          Break;
        Sleep(10);
      end;
    end;
  end;

  AppendAvailableProcessOutput(AProcess, AOutput);
  if not AProcess.Running then
    AProcess.WaitOnExit;
  AProcess.Free;
  AProcess := nil;
end;

procedure StartExampleServer(const APort: UInt16; out AProcess: TProcess;
  out AOutput: string);
var
  LReadyMarker: string;
  LPortMarker: string;
  LWait: Integer;
begin
  EnsureExampleBuilt;
  CheckEqual(Int64(0), Int64(GBuildExitCode), 'example build exit code');
  Check(FileExists(GExampleBinaryPath), 'example binary exists after build');

  LReadyMarker := 'http-server-options-demo=ready';
  LPortMarker := 'listen=127.0.0.1:' + IntToStr(Int64(APort));
  AProcess := TProcess.Create(nil);
  AOutput := '';
  try
    AProcess.Executable := GExampleBinaryPath;
    AProcess.CurrentDirectory := GExampleDir;
    AProcess.Parameters.Add('threaded');
    AProcess.Parameters.Add(IntToStr(Int64(APort)));
    AProcess.Options := [poUsePipes, poStderrToOutPut];
    AProcess.Execute;

    for LWait := 0 to 399 do
    begin
      AppendAvailableProcessOutput(AProcess, AOutput);
      if (Pos(LReadyMarker, AOutput) > 0) and (Pos(LPortMarker, AOutput) > 0) then
        Exit;
      if not AProcess.Running then
        Break;
      Sleep(10);
    end;
  except
    on E: Exception do
    begin
      StopExampleServer(AProcess, AOutput);
      Fail('unable to start example server: ' + E.ClassName + ': ' + E.Message);
    end;
  end;

  StopExampleServer(AProcess, AOutput);
  Fail('example server did not reach ready state' + LineEnding + AOutput);
end;

function MakeUrl(const APort: UInt16; const APath: string): string;
begin
  Result := 'http://127.0.0.1:' + IntToStr(Int64(APort)) + APath;
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
  LProcess: TProcess;
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

    LResp := LClient.Post(MakeUrl(LPort, '/echo'), 'text/plain',
      StringBodyReader('hello'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'echo status 200');
    LBody := ReadBodyStr(LResp);
    CheckContains(LBody, 'bytes=5', 'echo byte count marker');
    CheckContains(LBody, 'body=hello', 'echo body marker');
    CheckContains(LBody, 'max-body-size=64', 'echo limit marker');

    LResp := LClient.Post(MakeUrl(LPort, '/echo'), 'text/plain',
      StringBodyReader(StringOfChar('x', 65)));
    CheckEqual(Int64(413), Int64(LResp.StatusCode), 'oversize payload rejected');
    LBody := ReadBodyStr(LResp);
    Check(Pos('bytes=', LBody) = 0,
      'oversize rejection should not come from echo handler body');
  finally
    StopExampleServer(LProcess, LStartupOutput);
  end;
end;

begin
  T := TTestRunner.Create('http examples');
  T.Run('server options demo builds', @TestServerOptionsDemoBuilds);
  T.Run('server options demo serves documented endpoints',
    @TestServerOptionsDemoServesDocumentedEndpoints);
  T.Summary;
end.
