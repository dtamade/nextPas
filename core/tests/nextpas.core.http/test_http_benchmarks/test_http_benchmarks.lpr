program test_http_benchmarks;

{$I nextpas.core.settings.inc}

uses
  Classes,
  Process,
  SysUtils,
  nextpas.core.testing;

var
  T: TTestRunner;

const
  BenchServerRelativeDir = 'benchmarks/nextpas.core.http/bench_server';
  BenchRouterRelativeDir = 'benchmarks/nextpas.core.http/bench_router';
  BenchH1WriterRelativeDir = 'benchmarks/nextpas.core.http/bench_h1writer';
  BenchH1OutboundRelativeDir = 'benchmarks/nextpas.core.http/bench_h1outbound';
  BenchFullchainRelativeDir = 'benchmarks/nextpas.core.http/bench_fullchain';
  H1ParserBenchRelativeDir = 'benchmarks/nextpas.core.http/bench_h1parser';
  ServerComparisonRelativeDir = 'benchmarks/nextpas.core.http';
  ServerComparisonRunnerRelativePath =
    'benchmarks/nextpas.core.http/run_server_comparison.sh';
  ServerSnapshotRunnerRelativePath =
    'benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh';
  H1FlagMatrixRunnerRelativePath =
    'benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh';
  HeaderUnitPath = 'src/nextpas.core.http.headers.pas';
  HttpMessageUnitPath = 'src/nextpas.core.http.message.pas';
  H1ServerUnitPath = 'src/nextpas.core.http.impl.h1.pas';
  H1OutboundUnitPath = 'src/nextpas.core.http.impl.h1.outbound.pas';
  CompareGoRelativeDir = 'benchmarks/nextpas.core.http/compare_go';
  CompareRustRelativeDir = 'benchmarks/nextpas.core.http/compare_rust';
  HttpUnitPath = 'src/nextpas.core.http.pas';
  LlhttpRootEnvName = 'NEXTPAS_LLHTTP_ROOT';
  BenchMaxItersEnvName = 'NEXTPAS_BENCH_MAX_ITERS';
  BenchFilterEnvName = 'NEXTPAS_BENCH_FILTER';
  BenchMaxItersSmokeValue = '2000';
  FullchainSmokeIterations = '128';

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

function TryResolveCoreRootFrom(const AStartDir, ARelativeDir: string;
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
      DirectoryExists(PathJoin(LDir, ARelativeDir)) then
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

function ResolveCoreRoot(const ARelativeDir: string): string;
begin
  if TryResolveCoreRootFrom(GetCurrentDir, ARelativeDir, Result) then
    Exit;
  if TryResolveCoreRootFrom(ExtractFileDir(ExpandFileName(ParamStr(0))),
    ARelativeDir, Result) then
    Exit;
  Fail('unable to resolve core root from current directory or executable path');
end;

function ResolveMakeExecutable: string;
begin
  Result := Trim(GetEnvironmentVariable('MAKE'));
  if Result = '' then
    Result := 'make';
end;

procedure RunProcessAndCaptureWithEnv(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir: string;
  const AEnvironment: array of string; out AExitCode: Integer;
  out AOutput: string); forward;

procedure RunProcessAndCapture(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir: string;
  out AExitCode: Integer; out AOutput: string);
begin
  RunProcessAndCaptureWithEnv(AExecutable, AArguments, AWorkingDir, [],
    AExitCode, AOutput);
end;

procedure RunProcessAndCaptureWithEnv(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir: string;
  const AEnvironment: array of string; out AExitCode: Integer;
  out AOutput: string);
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
    for I := Low(AEnvironment) to High(AEnvironment) do
      LProcess.Environment.Add(AEnvironment[I]);
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
      AOutput := E.ClassName + ': ' + E.Message;
    end;
  end;
  LProcess.Free;
end;

procedure CheckContains(const AOutput, AFragment, ALabel: string);
begin
  Check(Pos(AFragment, AOutput) > 0,
    ALabel + ' missing from output: ' + AFragment + LineEnding + AOutput);
end;

procedure CheckNotContains(const AOutput, AFragment, ALabel: string);
begin
  Check(Pos(AFragment, AOutput) = 0,
    ALabel + ' unexpectedly present in output: ' + AFragment + LineEnding +
    AOutput);
end;

procedure CheckBenchmarkRunRow(const AOutput, ARowName, ALabel: string);
var
  LLines: TStringList;
  LLine: string;
  LFound: Boolean;
  I: Integer;
begin
  LFound := False;
  LLines := TStringList.Create;
  try
    LLines.Text := AOutput;
    for I := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[I];
      if (Pos(ARowName, LLine) > 0) and (Pos(' iters', LLine) > 0) then
      begin
        LFound := True;
        Break;
      end;
    end;
  finally
    LLines.Free;
  end;
  Check(LFound, ALabel + ' missing benchmark run row: ' + ARowName +
    LineEnding + AOutput);
end;

function ResolveBenchServerBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_server/bench_http_server');
end;

function ResolveBenchRouterBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_router/bench_router');
end;

function ResolveBenchH1WriterBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_h1writer/bench_h1writer');
end;

function ResolveBenchH1OutboundBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_h1outbound/bench_h1outbound');
end;

function ResolveBenchFullchainBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_fullchain/bench_fullchain');
end;

function ResolveBenchmarkTestBuildDir(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/test_http_benchmarks');
end;

function ResolveH1ParserBenchBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_h1parser/bench_h1parser');
end;

function ResolveCllhttpComparatorBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_h1parser/compare_c/bench_llhttp_c');
end;

function ResolveGoComparatorBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ResolveBenchmarkTestBuildDir(ARootDir),
    'bench_http_server_go');
end;

function ResolveRustComparatorBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ResolveBenchmarkTestBuildDir(ARootDir),
    'bench_http_server_rust');
end;

function ResolveServerComparisonRunnerPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir, ServerComparisonRunnerRelativePath);
end;

function ResolveServerSnapshotRunnerPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir, ServerSnapshotRunnerRelativePath);
end;

function ResolveH1FlagMatrixRunnerPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir, H1FlagMatrixRunnerRelativePath);
end;

procedure CheckServerBenchmarkOutput(const AOutput, AImplementation: string;
  const AIterations, AThreads: string; const AWorkload: string = 'no_url');
begin
  CheckContains(AOutput, 'operation=http.server.keepalive', 'operation marker');
  CheckContains(AOutput, 'workload=' + AWorkload, 'workload marker');
  CheckContains(AOutput, 'impl=' + AImplementation, 'implementation marker');
  CheckContains(AOutput, 'iterations=' + AIterations, 'iterations marker');
  CheckContains(AOutput, 'threads=' + AThreads, 'threads marker');
  CheckContains(AOutput, 'completed=' + AIterations, 'completed marker');
  CheckContains(AOutput, 'ns/op=', 'ns/op marker');
  CheckContains(AOutput, 'req/s=', 'req/s marker');
  if AImplementation = 'nextpas' then
    CheckContains(AOutput, 'nextpas_h1_path=', 'nextPas H1 path marker');
end;

procedure CheckRouterDispatchBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.router.dispatch',
    'router dispatch operation marker');
  CheckContains(AOutput, 'handler dispatch (match + no-op handler)',
    'router dispatch benchmark row');
  CheckContains(AOutput, 'bench_filter=handler dispatch',
    'router dispatch filter marker');
  CheckContains(AOutput, 'ns/op', 'router dispatch ns/op marker');
  CheckContains(AOutput, 'ops/s', 'router dispatch ops/s marker');
end;

procedure CheckH1WriterSerializeBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.h1writer.serialize',
    'H1 writer serialize operation marker');
  CheckBenchmarkRunRow(AOutput, 'fixed 200 13B',
    'H1 writer fixed response benchmark row');
  CheckContains(AOutput, 'bench_filter=fixed 200 13B',
    'H1 writer filter marker');
  CheckContains(AOutput, 'ns/op', 'H1 writer ns/op marker');
  CheckContains(AOutput, 'ops/s', 'H1 writer ops/s marker');
end;

procedure CheckH1WriterHeadersOnlyBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.h1writer.serialize',
    'H1 writer headers-only operation marker');
  CheckBenchmarkRunRow(AOutput, 'headers only 200',
    'H1 writer headers-only benchmark row');
  CheckContains(AOutput, 'bench_filter=headers only 200',
    'H1 writer headers-only filter marker');
  CheckContains(AOutput, 'ns/op', 'H1 writer headers-only ns/op marker');
  CheckContains(AOutput, 'ops/s', 'H1 writer headers-only ops/s marker');
end;

procedure CheckH1OutboundDrainBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.h1outbound.drain',
    'H1 outbound drain operation marker');
  CheckContains(AOutput, 'buffer write+drain 1KB',
    'H1 outbound drain benchmark row');
  CheckContains(AOutput, 'bench_filter=buffer write+drain 1KB',
    'H1 outbound filter marker');
  CheckContains(AOutput, 'ns/op', 'H1 outbound ns/op marker');
  CheckContains(AOutput, 'ops/s', 'H1 outbound ops/s marker');
end;

procedure CheckFullchainBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.fullchain.keepalive',
    'fullchain operation marker');
  CheckContains(AOutput, 'client_read_mode=buffered',
    'fullchain client read mode marker');
  CheckContains(AOutput, 'workload=plaintext',
    'fullchain workload marker');
  CheckContains(AOutput, 'iterations=' + FullchainSmokeIterations,
    'fullchain iterations marker');
  CheckContains(AOutput, 'completed=' + FullchainSmokeIterations,
    'fullchain completed marker');
  CheckContains(AOutput, 'elapsed_ns=', 'fullchain elapsed marker');
  CheckContains(AOutput, 'ns/op=', 'fullchain ns/op marker');
  CheckContains(AOutput, 'req/s=', 'fullchain req/s marker');
  CheckContains(AOutput, 'bench_filter=plaintext',
    'fullchain filter marker');
end;

function LoadTextFile(const APath: string): string;
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(APath);
    Result := LText.Text;
  finally
    LText.Free;
  end;
end;

procedure TestBenchServerSmallSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(BenchServerRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchServerRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode), 'bench_server build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchServerBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_server binary exists');

  RunProcessAndCapture(LBinaryPath, ['--requests', '32', '--threads', '2'],
    LBenchDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode), 'bench_server smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '32', '2');
end;

procedure TestBenchServerUrlPathSmallSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(BenchServerRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchServerRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_server url_path build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchServerBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_server url_path binary exists');

  RunProcessAndCapture(LBinaryPath,
    ['--requests', '32', '--threads', '2', '--workload', 'url_path'],
    LBenchDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_server url_path smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'workload=url_path',
    'bench_server url_path workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '32', '2', 'url_path');
end;

procedure TestBenchRouterHandlerDispatchSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(BenchRouterRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchRouterRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_router build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchRouterBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_router binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=handler dispatch'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_router handler dispatch smoke exit code: ' + LOutput);
  CheckRouterDispatchBenchmarkOutput(LOutput);
end;

procedure TestBenchH1WriterSerializeSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(BenchH1WriterRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchH1WriterRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1writer build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchH1WriterBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_h1writer binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=fixed 200 13B'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1writer serialize smoke exit code: ' + LOutput);
  CheckH1WriterSerializeBenchmarkOutput(LOutput);

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=headers only 200'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1writer headers-only smoke exit code: ' + LOutput);
  CheckH1WriterHeadersOnlyBenchmarkOutput(LOutput);
end;

procedure TestBenchH1OutboundDrainSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(BenchH1OutboundRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchH1OutboundRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1outbound build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchH1OutboundBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_h1outbound binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=buffer write+drain 1KB'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1outbound drain smoke exit code: ' + LOutput);
  CheckH1OutboundDrainBenchmarkOutput(LOutput);
end;

procedure TestH1OutboundHotHelpersInlineSourceContract;
var
  LRootDir: string;
  LSource: string;
begin
  LRootDir := ResolveCoreRoot(BenchH1OutboundRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1OutboundUnitPath));

  CheckContains(LSource, 'procedure Advance(const ACount: SizeUInt); inline;',
    'H1 outbound Advance inline declaration');
  CheckContains(LSource, 'function PendingBytes: SizeUInt; inline;',
    'H1 outbound PendingBytes inline declaration');
  CheckContains(LSource, 'function IsEmpty: Boolean; inline;',
    'H1 outbound IsEmpty inline declaration');
  CheckContains(LSource,
    'procedure TH1OutboundBuffer.Advance(const ACount: SizeUInt); inline;',
    'H1 outbound Advance inline implementation');
  CheckContains(LSource,
    'function TH1OutboundBuffer.PendingBytes: SizeUInt; inline;',
    'H1 outbound PendingBytes inline implementation');
  CheckContains(LSource,
    'function TH1OutboundBuffer.IsEmpty: Boolean; inline;',
    'H1 outbound IsEmpty inline implementation');
end;

procedure TestH1ServerPolicyHotHelpersInlineSourceContract;
var
  LRootDir: string;
  LSource: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1ServerUnitPath));

  CheckContains(LSource,
    'function ShouldKeepAlive(const AParser: IH1Parser): Boolean; inline;',
    'H1 server ShouldKeepAlive inline implementation');
  CheckContains(LSource,
    'function ParserErrorStatus(const AParser: IH1Parser): THttpStatus; inline;',
    'H1 server ParserErrorStatus inline implementation');
  CheckContains(LSource,
    'const AHeadersDone, AContinueSent: Boolean): Boolean; inline;',
    'H1 server ShouldSendContinueResponse inline implementation');
end;

procedure TestHttpHeadersLookupHotHelpersInlineSourceContract;
var
  LRootDir: string;
  LSource: string;
begin
  LRootDir := ResolveCoreRoot(BenchRouterRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, HeaderUnitPath));

  CheckContains(LSource,
    'function FindFirst(const AName: string): Int32; inline;',
    'THttpHeaders FindFirst inline declaration');
  CheckContains(LSource,
    'class function NeedsNormalize(const AName: string): Boolean; static; inline;',
    'THttpHeaders NeedsNormalize inline declaration');
  CheckContains(LSource,
    'class function NormalizeIfNeeded(const AName: string): string; static; inline;',
    'THttpHeaders NormalizeIfNeeded inline declaration');
  CheckContains(LSource,
    'function THttpHeaders.FindFirst(const AName: string): Int32; inline;',
    'THttpHeaders FindFirst inline implementation');
  CheckContains(LSource,
    'class function THttpHeaders.NeedsNormalize(const AName: string): Boolean; inline;',
    'THttpHeaders NeedsNormalize inline implementation');
  CheckContains(LSource,
    'class function THttpHeaders.NormalizeIfNeeded(const AName: string): string; inline;',
    'THttpHeaders NormalizeIfNeeded inline implementation');
end;

procedure TestH1ServerResponseDrainAvoidsGenericBufferedWriterSourceContract;
var
  LRootDir: string;
  LSource: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1ServerUnitPath));

  CheckNotContains(LSource,
    'CreateBufferedWriter(LOutbound as IWriter, 4096)',
    'H1 server response path should write directly into IH1OutboundBuffer');
end;

procedure TestHttpRequestDirectPathProjectionSourceContract;
var
  LRootDir: string;
  LSource: string;
begin
  LRootDir := ResolveCoreRoot(BenchRouterRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, HttpMessageUnitPath));

  CheckContains(LSource, 'procedure EnsureRequestTargetParts;',
    'THttpRequest request-target projection helper declaration');
  CheckContains(LSource, 'procedure THttpRequest.EnsureRequestTargetParts;',
    'THttpRequest request-target projection helper implementation');
  CheckNotContains(LSource,
    'function THttpRequest.GetPath: string;' + LineEnding + 'begin' +
    LineEnding + '  EnsureUrlParsed;',
    'THttpRequest.GetPath should not force full Url materialization');
  CheckNotContains(LSource,
    'function THttpRequest.GetRawQuery: string;' + LineEnding + 'begin' +
    LineEnding + '  EnsureUrlParsed;',
    'THttpRequest.GetRawQuery should not force full Url materialization');
end;

procedure TestBenchFullchainPlaintextSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchFullchainRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=plaintext'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain plaintext smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput);
end;

procedure TestGoServerComparatorSmallSmoke;
var
  LRootDir: string;
  LCompareDir: string;
  LBuildDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(CompareGoRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareGoRelativeDir);
  LBuildDir := ResolveBenchmarkTestBuildDir(LRootDir);
  ForceDirectories(LBuildDir);
  LBinaryPath := ResolveGoComparatorBinaryPath(LRootDir);

  RunProcessAndCapture('go', ['build', '-o', LBinaryPath, 'main.go'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode), 'go comparator build exit code: ' + LOutput);
  Check(FileExists(LBinaryPath), 'go comparator binary exists');

  RunProcessAndCapture(LBinaryPath, ['--requests', '32', '--threads', '2'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode), 'go comparator smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'go', '32', '2');
end;

procedure TestGoServerComparatorUrlPathSmallSmoke;
var
  LRootDir: string;
  LCompareDir: string;
  LBuildDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(CompareGoRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareGoRelativeDir);
  LBuildDir := ResolveBenchmarkTestBuildDir(LRootDir);
  ForceDirectories(LBuildDir);
  LBinaryPath := ResolveGoComparatorBinaryPath(LRootDir);

  RunProcessAndCapture('go', ['build', '-o', LBinaryPath, 'main.go'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'go comparator url_path build exit code: ' + LOutput);
  Check(FileExists(LBinaryPath), 'go comparator url_path binary exists');

  RunProcessAndCapture(LBinaryPath,
    ['--requests', '32', '--threads', '2', '--workload', 'url_path'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'go comparator url_path smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'workload=url_path',
    'go comparator url_path workload marker');
  CheckServerBenchmarkOutput(LOutput, 'go', '32', '2', 'url_path');
end;

procedure TestRustServerComparatorSmallSmoke;
var
  LRootDir: string;
  LCompareDir: string;
  LBuildDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(CompareRustRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareRustRelativeDir);
  LBuildDir := ResolveBenchmarkTestBuildDir(LRootDir);
  ForceDirectories(LBuildDir);
  LBinaryPath := ResolveRustComparatorBinaryPath(LRootDir);

  RunProcessAndCapture('rustc', ['-O', '-o', LBinaryPath, 'main.rs'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode), 'rust comparator build exit code: ' + LOutput);
  Check(FileExists(LBinaryPath), 'rust comparator binary exists');

  RunProcessAndCapture(LBinaryPath, ['--requests', '32', '--threads', '2'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode), 'rust comparator smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'rust', '32', '2');
end;

procedure TestRustServerComparatorUrlPathSmallSmoke;
var
  LRootDir: string;
  LCompareDir: string;
  LBuildDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(CompareRustRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareRustRelativeDir);
  LBuildDir := ResolveBenchmarkTestBuildDir(LRootDir);
  ForceDirectories(LBuildDir);
  LBinaryPath := ResolveRustComparatorBinaryPath(LRootDir);

  RunProcessAndCapture('rustc', ['-O', '-o', LBinaryPath, 'main.rs'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'rust comparator url_path build exit code: ' + LOutput);
  Check(FileExists(LBinaryPath), 'rust comparator url_path binary exists');

  RunProcessAndCapture(LBinaryPath,
    ['--requests', '32', '--threads', '2', '--workload', 'url_path'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'rust comparator url_path smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'workload=url_path',
    'rust comparator url_path workload marker');
  CheckServerBenchmarkOutput(LOutput, 'rust', '32', '2', 'url_path');
end;

procedure TestServerComparisonRunnerSmallSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison runner exists');
  LReportPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--output', LReportPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'comparison marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1');
  CheckServerBenchmarkOutput(LOutput, 'rust', '8', '1');

  Check(FileExists(LReportPath), 'server comparison report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'report comparison marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1');
  CheckServerBenchmarkOutput(LReport, 'rust', '8', '1');
end;

procedure TestServerComparisonRunnerUrlPathSmallSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison url_path runner exists');
  LReportPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_url_path_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'url_path', '--output', LReportPath], LRootDir, LExitCode,
    LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison url_path runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'url_path comparison marker');
  CheckContains(LOutput, 'workload=url_path',
    'url_path comparison workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LOutput, 'rust', '8', '1', 'url_path');

  Check(FileExists(LReportPath), 'server comparison url_path report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'url_path report comparison marker');
  CheckContains(LReport, 'workload=url_path',
    'url_path report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LReport, 'rust', '8', '1', 'url_path');
end;

procedure TestServerComparisonRunnerAdapterNoUrlSmallSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison adapter_no_url runner exists');
  LReportPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_adapter_no_url_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'adapter_no_url', '--output', LReportPath], LRootDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison adapter_no_url runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'adapter_no_url comparison marker');
  CheckContains(LOutput, 'workload=adapter_no_url',
    'adapter_no_url comparison workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'adapter_no_url');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'adapter_no_url');
  CheckServerBenchmarkOutput(LOutput, 'rust', '8', '1', 'adapter_no_url');

  Check(FileExists(LReportPath), 'server comparison adapter_no_url report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'adapter_no_url report comparison marker');
  CheckContains(LReport, 'workload=adapter_no_url',
    'adapter_no_url report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'adapter_no_url');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'adapter_no_url');
  CheckServerBenchmarkOutput(LReport, 'rust', '8', '1', 'adapter_no_url');
end;

procedure TestServerComparisonRunnerResponse1KSmallSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison response_1k runner exists');
  LReportPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_response_1k_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'response_1k', '--output', LReportPath], LRootDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison response_1k runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'response_1k comparison marker');
  CheckContains(LOutput, 'workload=response_1k',
    'response_1k comparison workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LOutput, 'rust', '8', '1', 'response_1k');

  Check(FileExists(LReportPath), 'server comparison response_1k report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'response_1k report comparison marker');
  CheckContains(LReport, 'workload=response_1k',
    'response_1k report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LReport, 'rust', '8', '1', 'response_1k');
end;

procedure TestServerComparisonRunnerRunsSummarySmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison runs runner exists');
  LReportPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_runs_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'no_url', '--runs', '2', '--output', LReportPath],
    LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison runs runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'runs comparison marker');
  CheckContains(LOutput, 'runs=2', 'runs count marker');
  CheckContains(LOutput, 'run=1', 'first run marker');
  CheckContains(LOutput, 'run=2', 'second run marker');
  CheckContains(LOutput, 'summary=http.server.keepalive',
    'summary marker');
  CheckContains(LOutput, 'summary_impl=nextpas',
    'nextpas summary marker');
  CheckContains(LOutput, 'summary_impl=go', 'go summary marker');
  CheckContains(LOutput, 'summary_impl=rust', 'rust summary marker');
  CheckContains(LOutput, 'median_ns/op=', 'median ns/op marker');
  CheckContains(LOutput, 'median_req/s=', 'median req/s marker');
  CheckContains(LOutput, 'median_completed=8',
    'median completed marker');

  Check(FileExists(LReportPath), 'server comparison runs report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'runs=2', 'runs report count marker');
  CheckContains(LReport, 'summary=http.server.keepalive',
    'runs report summary marker');
  CheckContains(LReport, 'summary_impl=nextpas',
    'runs report nextpas summary marker');
  CheckContains(LReport, 'summary_impl=go',
    'runs report go summary marker');
  CheckContains(LReport, 'summary_impl=rust',
    'runs report rust summary marker');
  CheckContains(LReport, 'median_completed=8',
    'runs report median completed marker');
end;

procedure TestServerComparisonSnapshotSmallSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LSnapshotPath: string;
  LSnapshot: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison snapshot runner exists');
  LSnapshotPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_snapshot_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--output', LSnapshotPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath), 'server comparison snapshot exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, '# nextpas.core.http Server Benchmark Snapshot',
    'snapshot title');
  CheckContains(LSnapshot, '## Environment', 'environment heading');
  CheckContains(LSnapshot, 'git_head=', 'git head marker');
  CheckContains(LSnapshot, 'fpc_version=', 'fpc version marker');
  CheckContains(LSnapshot, 'go_version=', 'go version marker');
  CheckContains(LSnapshot, 'rustc_version=', 'rustc version marker');
  CheckContains(LSnapshot, '## Raw Comparison Output',
    'raw comparison heading');
  CheckContains(LSnapshot, 'comparison=http.server.keepalive',
    'snapshot comparison marker');
  CheckNotContains(LSnapshot, ' Warning:', 'snapshot compiler warning');
  CheckNotContains(LSnapshot, ' Note:', 'snapshot compiler note');
  CheckServerBenchmarkOutput(LSnapshot, 'nextpas', '8', '1');
  CheckServerBenchmarkOutput(LSnapshot, 'go', '8', '1');
  CheckServerBenchmarkOutput(LSnapshot, 'rust', '8', '1');
end;

procedure TestServerComparisonSnapshotRunsSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LSnapshotPath: string;
  LSnapshot: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison snapshot runs runner exists');
  LSnapshotPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_snapshot_runs_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--runs', '2', '--output', LSnapshotPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot runs exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath), 'server comparison snapshot runs exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'runs=2', 'snapshot runs marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --runs 2',
    'snapshot runs command marker');
  CheckContains(LSnapshot, 'summary=http.server.keepalive',
    'snapshot runs summary marker');
  CheckContains(LSnapshot, 'summary_impl=nextpas',
    'snapshot runs nextpas summary marker');
  CheckContains(LSnapshot, 'summary_impl=go',
    'snapshot runs go summary marker');
  CheckContains(LSnapshot, 'summary_impl=rust',
    'snapshot runs rust summary marker');
end;

procedure TestCllhttpComparatorRequiresRoot;
var
  LRootDir: string;
  LBenchDir: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['run-c'], LBenchDir,
    LExitCode, LOutput);
  Check(LExitCode <> 0, 'C llhttp comparator without root should fail');
  CheckContains(LOutput, 'LLHTTP_ROOT is required',
    'C llhttp comparator missing-root diagnostic');
end;

procedure TestH1ParserBenchmarkMaxItersEnv;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser benchmark build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'H1 parser benchmark binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser benchmark max-iters smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_max_iters=' + BenchMaxItersSmokeValue,
    'H1 parser benchmark max-iters marker');
  CheckContains(LOutput, 'raw llhttp: simple GET',
    'H1 parser benchmark raw row');
  CheckContains(LOutput, 'adapter cost: span append 10 headers',
    'H1 parser benchmark span append breakdown row');
  CheckContains(LOutput, 'adapter cost: header add 10 headers',
    'H1 parser benchmark header add breakdown row');
  CheckContains(LOutput, 'adapter cost: header span add 10 headers',
    'H1 parser benchmark header span add breakdown row');
  CheckContains(LOutput, 'adapter cost: body copy 1KB',
    'H1 parser benchmark body copy breakdown row');
  CheckContains(LOutput, 'adapter cost: url parse generic origin-form',
    'H1 parser benchmark generic URL parse breakdown row');
  CheckContains(LOutput, 'adapter cost: url parse request-target origin-form',
    'H1 parser benchmark request-target URL parse breakdown row');
  CheckContains(LOutput, 'adapter cost: request create eager url parse',
    'H1 parser benchmark eager request create breakdown row');
  CheckContains(LOutput, 'adapter cost: request create lazy target',
    'H1 parser benchmark lazy request create breakdown row');
  CheckContains(LOutput, 'adapter cost: request lazy Url.Path access',
    'H1 parser benchmark lazy Url.Path access breakdown row');
  CheckContains(LOutput, 'adapter cost: request direct Path access',
    'H1 parser benchmark direct Path access breakdown row');
  CheckContains(LOutput, 'adapter cost: request direct RawQuery access',
    'H1 parser benchmark direct RawQuery access breakdown row');
  CheckContains(LOutput, 'adapter cost: request direct Path+RawQuery access',
    'H1 parser benchmark direct Path+RawQuery access breakdown row');
  CheckContains(LOutput, 'adapter cost: request metadata legacy expect+cl',
    'H1 parser benchmark legacy request metadata breakdown row');
  CheckContains(LOutput, 'adapter cost: request metadata cached expect+cl',
    'H1 parser benchmark cached request metadata breakdown row');
end;

procedure TestH1ParserBenchmarkFilterEnv;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser benchmark filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'H1 parser benchmark filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=raw llhttp: 10 headers'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser benchmark filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=raw llhttp: 10 headers',
    'H1 parser benchmark filter marker');
  CheckContains(LOutput, 'raw llhttp: 10 headers',
    'H1 parser benchmark filtered raw row');
  CheckNotContains(LOutput, 'adapter cost: span append 10 headers',
    'H1 parser benchmark filter skips unrelated adapter row');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=adapter no-url'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser benchmark adapter no-url filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=adapter no-url',
    'H1 parser benchmark adapter no-url filter marker');
  CheckContains(LOutput, 'adapter no-url: fast reject + llhttp',
    'H1 parser benchmark adapter no-url double-parse row');
  CheckContains(LOutput, 'adapter no-url: llhttp direct only',
    'H1 parser benchmark adapter no-url direct llhttp row');
  CheckContains(LOutput, 'adapter no-url: fast parse only',
    'H1 parser benchmark adapter no-url fast parse row');
  CheckContains(LOutput, 'adapter no-url: metadata 3 headers',
    'H1 parser benchmark adapter no-url metadata row');
end;

procedure TestCllhttpComparatorSmallSmokeWhenConfigured;
var
  LRootDir: string;
  LBenchDir: string;
  LLhttpRoot: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LLhttpRoot := Trim(GetEnvironmentVariable(LlhttpRootEnvName));
  if LLhttpRoot = '' then
    Exit;

  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable,
    ['run-c', 'LLHTTP_ROOT=' + LLhttpRoot], LBenchDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'C llhttp comparator smoke exit code: ' + LOutput);
  CheckContains(LOutput, '=== C llhttp H1 parser comparator ===',
    'C llhttp comparator title');
  CheckContains(LOutput, 'llhttp version: 9.4.1',
    'C llhttp comparator version');
  CheckContains(LOutput, 'C raw llhttp: 10 headers',
    'C llhttp raw row');
  CheckContains(LOutput, 'C noop cb: pipeline',
    'C llhttp noop pipeline row');
end;

procedure TestCllhttpComparatorMaxItersEnvWhenConfigured;
var
  LRootDir: string;
  LCompareDir: string;
  LLhttpRoot: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LLhttpRoot := Trim(GetEnvironmentVariable(LlhttpRootEnvName));
  if LLhttpRoot = '' then
    Exit;

  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LCompareDir := PathJoin(LRootDir, H1ParserBenchRelativeDir + '/compare_c');

  RunProcessAndCapture(ResolveMakeExecutable,
    ['build', 'LLHTTP_ROOT=' + LLhttpRoot], LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'C llhttp comparator max-iters build exit code: ' + LOutput);

  LBinaryPath := ResolveCllhttpComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'C llhttp comparator binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LCompareDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'C llhttp comparator max-iters smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_max_iters=' + BenchMaxItersSmokeValue,
    'C llhttp comparator max-iters marker');
  CheckContains(LOutput, 'C raw llhttp: simple GET',
    'C llhttp comparator raw row');
end;

procedure TestCllhttpComparatorFilterEnvWhenConfigured;
var
  LRootDir: string;
  LCompareDir: string;
  LLhttpRoot: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LLhttpRoot := Trim(GetEnvironmentVariable(LlhttpRootEnvName));
  if LLhttpRoot = '' then
    Exit;

  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LCompareDir := PathJoin(LRootDir, H1ParserBenchRelativeDir + '/compare_c');

  RunProcessAndCapture(ResolveMakeExecutable,
    ['build', 'LLHTTP_ROOT=' + LLhttpRoot], LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'C llhttp comparator filter build exit code: ' + LOutput);

  LBinaryPath := ResolveCllhttpComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'C llhttp comparator filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LCompareDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=C raw llhttp: 10 headers'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'C llhttp comparator filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=C raw llhttp: 10 headers',
    'C llhttp comparator filter marker');
  CheckContains(LOutput, 'C raw llhttp: 10 headers',
    'C llhttp comparator filtered raw row');
  CheckNotContains(LOutput, 'C noop cb: pipeline',
    'C llhttp comparator filter skips unrelated noop row');
end;

procedure TestH1ParserFlagMatrixSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LRunnerPath: string;
  LOutputDir: string;
  LResultsPath: string;
  LEnvPath: string;
  LLhttpRoot: string;
  LExitCode: Integer;
  LOutput: string;
  LResults: string;
  LEnv: string;
  LEnvVars: array of string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);
  LRunnerPath := ResolveH1FlagMatrixRunnerPath(LRootDir);
  LOutputDir := PathJoin(LRootDir,
    'build/projects/nextpas.core.http/bench_h1parser/flag_matrix/smoke');
  LResultsPath := PathJoin(LOutputDir, 'results.tsv');
  LEnvPath := PathJoin(LOutputDir, 'env.txt');
  LLhttpRoot := Trim(GetEnvironmentVariable(LlhttpRootEnvName));

  if LLhttpRoot <> '' then
  begin
    SetLength(LEnvVars, 5);
    LEnvVars[0] := BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue;
    LEnvVars[1] := BenchFilterEnvName + '=raw llhttp: 10 headers';
    LEnvVars[2] := 'LLHTTP_ROOT=' + LLhttpRoot;
    LEnvVars[3] := 'PATH=' + GetEnvironmentVariable('PATH');
    LEnvVars[4] := 'HOME=' + GetEnvironmentVariable('HOME');
  end
  else
  begin
    SetLength(LEnvVars, 4);
    LEnvVars[0] := BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue;
    LEnvVars[1] := BenchFilterEnvName + '=raw llhttp: 10 headers';
    LEnvVars[2] := 'PATH=' + GetEnvironmentVariable('PATH');
    LEnvVars[3] := 'HOME=' + GetEnvironmentVariable('HOME');
  end;

  RunProcessAndCaptureWithEnv(LRunnerPath, ['--smoke', '--no-perf'],
    LBenchDir, LEnvVars, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser flag matrix smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'flag_matrix_output=' + LOutputDir,
    'H1 parser flag matrix output marker');
  Check(FileExists(LResultsPath), 'H1 parser flag matrix results.tsv exists');
  Check(FileExists(LEnvPath), 'H1 parser flag matrix env.txt exists');

  LResults := LoadTextFile(LResultsPath);
  CheckContains(LResults, 'variant' + #9 + 'impl' + #9 + 'benchmark',
    'H1 parser flag matrix results header');
  CheckContains(LResults, 'pascal-default',
    'H1 parser flag matrix Pascal variant');
  CheckContains(LResults, 'raw llhttp: 10 headers',
    'H1 parser flag matrix Pascal filtered row');
  if LLhttpRoot <> '' then
    CheckContains(LResults, 'c-default',
      'H1 parser flag matrix C variant');

  LEnv := LoadTextFile(LEnvPath);
  CheckContains(LEnv, 'git_head=', 'H1 parser flag matrix git marker');
  CheckContains(LEnv, 'bench_filter=raw llhttp: 10 headers',
    'H1 parser flag matrix filter marker');
  CheckContains(LEnv, 'perf_requested=0',
    'H1 parser flag matrix no-perf marker');
end;

procedure TestH1ParserFlagMatrixPerfGracefulSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LRunnerPath: string;
  LOutputDir: string;
  LResultsPath: string;
  LEnvPath: string;
  LLhttpRoot: string;
  LExitCode: Integer;
  LOutput: string;
  LResults: string;
  LEnv: string;
  LEnvVars: array of string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);
  LRunnerPath := ResolveH1FlagMatrixRunnerPath(LRootDir);
  LOutputDir := PathJoin(LRootDir,
    'build/projects/nextpas.core.http/bench_h1parser/flag_matrix/smoke');
  LResultsPath := PathJoin(LOutputDir, 'results.tsv');
  LEnvPath := PathJoin(LOutputDir, 'env.txt');
  LLhttpRoot := Trim(GetEnvironmentVariable(LlhttpRootEnvName));

  if LLhttpRoot <> '' then
  begin
    SetLength(LEnvVars, 5);
    LEnvVars[0] := BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue;
    LEnvVars[1] := BenchFilterEnvName + '=raw llhttp: 10 headers';
    LEnvVars[2] := 'LLHTTP_ROOT=' + LLhttpRoot;
    LEnvVars[3] := 'PATH=' + GetEnvironmentVariable('PATH');
    LEnvVars[4] := 'HOME=' + GetEnvironmentVariable('HOME');
  end
  else
  begin
    SetLength(LEnvVars, 4);
    LEnvVars[0] := BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue;
    LEnvVars[1] := BenchFilterEnvName + '=raw llhttp: 10 headers';
    LEnvVars[2] := 'PATH=' + GetEnvironmentVariable('PATH');
    LEnvVars[3] := 'HOME=' + GetEnvironmentVariable('HOME');
  end;

  RunProcessAndCaptureWithEnv(LRunnerPath, ['--smoke', '--perf'],
    LBenchDir, LEnvVars, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser flag matrix perf smoke exit code: ' + LOutput);
  Check(FileExists(LResultsPath), 'H1 parser flag matrix perf results.tsv exists');
  Check(FileExists(LEnvPath), 'H1 parser flag matrix perf env.txt exists');

  LResults := LoadTextFile(LResultsPath);
  CheckContains(LResults, 'pascal-default',
    'H1 parser flag matrix perf Pascal variant');

  LEnv := LoadTextFile(LEnvPath);
  CheckContains(LEnv, 'perf_requested=1',
    'H1 parser flag matrix perf requested marker');
  CheckContains(LEnv, 'perf_usable=',
    'H1 parser flag matrix perf usability marker');
end;

procedure TestH1ParserFlagMatrixRunsSummarySmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LRunnerPath: string;
  LOutputDir: string;
  LResultsPath: string;
  LSummaryPath: string;
  LEnvPath: string;
  LLhttpRoot: string;
  LExitCode: Integer;
  LOutput: string;
  LSummary: string;
  LEnv: string;
  LEnvVars: array of string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);
  LRunnerPath := ResolveH1FlagMatrixRunnerPath(LRootDir);
  LOutputDir := PathJoin(LRootDir,
    'build/projects/nextpas.core.http/bench_h1parser/flag_matrix/smoke');
  LResultsPath := PathJoin(LOutputDir, 'results.tsv');
  LSummaryPath := PathJoin(LOutputDir, 'summary.tsv');
  LEnvPath := PathJoin(LOutputDir, 'env.txt');
  LLhttpRoot := Trim(GetEnvironmentVariable(LlhttpRootEnvName));

  if LLhttpRoot <> '' then
  begin
    SetLength(LEnvVars, 5);
    LEnvVars[0] := BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue;
    LEnvVars[1] := BenchFilterEnvName + '=raw llhttp: 10 headers';
    LEnvVars[2] := 'LLHTTP_ROOT=' + LLhttpRoot;
    LEnvVars[3] := 'PATH=' + GetEnvironmentVariable('PATH');
    LEnvVars[4] := 'HOME=' + GetEnvironmentVariable('HOME');
  end
  else
  begin
    SetLength(LEnvVars, 4);
    LEnvVars[0] := BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue;
    LEnvVars[1] := BenchFilterEnvName + '=raw llhttp: 10 headers';
    LEnvVars[2] := 'PATH=' + GetEnvironmentVariable('PATH');
    LEnvVars[3] := 'HOME=' + GetEnvironmentVariable('HOME');
  end;

  RunProcessAndCaptureWithEnv(LRunnerPath, ['--smoke', '--no-perf', '--runs', '2'],
    LBenchDir, LEnvVars, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser flag matrix runs smoke exit code: ' + LOutput);
  Check(FileExists(LResultsPath),
    'H1 parser flag matrix runs results.tsv exists');
  Check(FileExists(LSummaryPath),
    'H1 parser flag matrix runs summary.tsv exists');
  Check(FileExists(LEnvPath), 'H1 parser flag matrix runs env.txt exists');

  LSummary := LoadTextFile(LSummaryPath);
  CheckContains(LSummary,
    'variant' + #9 + 'impl' + #9 + 'benchmark' + #9 + 'runs',
    'H1 parser flag matrix summary header');
  CheckContains(LSummary, 'pascal-default',
    'H1 parser flag matrix summary Pascal variant');
  CheckContains(LSummary, 'raw llhttp: 10 headers',
    'H1 parser flag matrix summary filtered row');
  CheckContains(LSummary, #9 + '2' + #9,
    'H1 parser flag matrix summary run count');
  if LLhttpRoot <> '' then
    CheckContains(LSummary, 'c-default',
      'H1 parser flag matrix summary C variant');

  LEnv := LoadTextFile(LEnvPath);
  CheckContains(LEnv, 'runs=2',
    'H1 parser flag matrix runs marker');
end;

begin
  T := TTestRunner.Create('http benchmarks');
  T.Run('bench_server small smoke', @TestBenchServerSmallSmoke);
  T.Run('bench_server url_path small smoke',
    @TestBenchServerUrlPathSmallSmoke);
  T.Run('bench_router handler dispatch smoke',
    @TestBenchRouterHandlerDispatchSmoke);
  T.Run('bench_h1writer response serialization smoke',
    @TestBenchH1WriterSerializeSmoke);
  T.Run('H1 outbound hot helpers inline source contract',
    @TestH1OutboundHotHelpersInlineSourceContract);
  T.Run('H1 server policy hot helpers inline source contract',
    @TestH1ServerPolicyHotHelpersInlineSourceContract);
  T.Run('HTTP headers lookup hot helpers inline source contract',
    @TestHttpHeadersLookupHotHelpersInlineSourceContract);
  T.Run('H1 server response drain avoids generic buffered writer source contract',
    @TestH1ServerResponseDrainAvoidsGenericBufferedWriterSourceContract);
  T.Run('HTTP request direct path projection source contract',
    @TestHttpRequestDirectPathProjectionSourceContract);
  T.Run('bench_h1outbound drain smoke',
    @TestBenchH1OutboundDrainSmoke);
  T.Run('bench_fullchain plaintext smoke',
    @TestBenchFullchainPlaintextSmoke);
  T.Run('go server comparator small smoke', @TestGoServerComparatorSmallSmoke);
  T.Run('go server comparator url_path small smoke',
    @TestGoServerComparatorUrlPathSmallSmoke);
  T.Run('rust server comparator small smoke', @TestRustServerComparatorSmallSmoke);
  T.Run('rust server comparator url_path small smoke',
    @TestRustServerComparatorUrlPathSmallSmoke);
  T.Run('server comparison runner small smoke',
    @TestServerComparisonRunnerSmallSmoke);
  T.Run('server comparison runner url_path small smoke',
    @TestServerComparisonRunnerUrlPathSmallSmoke);
  T.Run('server comparison runner adapter_no_url small smoke',
    @TestServerComparisonRunnerAdapterNoUrlSmallSmoke);
  T.Run('server comparison runner response_1k small smoke',
    @TestServerComparisonRunnerResponse1KSmallSmoke);
  T.Run('server comparison runner runs summary smoke',
    @TestServerComparisonRunnerRunsSummarySmoke);
  T.Run('server comparison snapshot small smoke',
    @TestServerComparisonSnapshotSmallSmoke);
  T.Run('server comparison snapshot runs smoke',
    @TestServerComparisonSnapshotRunsSmoke);
  T.Run('C llhttp comparator requires LLHTTP_ROOT',
    @TestCllhttpComparatorRequiresRoot);
  T.Run('H1 parser benchmark max iterations env',
    @TestH1ParserBenchmarkMaxItersEnv);
  T.Run('H1 parser benchmark filter env',
    @TestH1ParserBenchmarkFilterEnv);
  T.Run('C llhttp comparator small smoke when configured',
    @TestCllhttpComparatorSmallSmokeWhenConfigured);
  T.Run('C llhttp comparator max iterations env when configured',
    @TestCllhttpComparatorMaxItersEnvWhenConfigured);
  T.Run('C llhttp comparator filter env when configured',
    @TestCllhttpComparatorFilterEnvWhenConfigured);
  T.Run('H1 parser flag matrix smoke',
    @TestH1ParserFlagMatrixSmoke);
  T.Run('H1 parser flag matrix perf graceful smoke',
    @TestH1ParserFlagMatrixPerfGracefulSmoke);
  T.Run('H1 parser flag matrix runs summary smoke',
    @TestH1ParserFlagMatrixRunsSummarySmoke);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
