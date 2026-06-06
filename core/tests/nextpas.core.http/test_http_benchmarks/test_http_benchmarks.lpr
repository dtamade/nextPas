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
  BenchHeadersRelativeDir = 'benchmarks/nextpas.core.http/bench_headers';
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
  H1ParserUnitPath = 'src/nextpas.core.http.impl.h1.parser.pas';
  H1FastUnitPath = 'src/nextpas.core.http.impl.h1.fast.pas';
  H1OutboundUnitPath = 'src/nextpas.core.http.impl.h1.outbound.pas';
  H1WriterUnitPath = 'src/nextpas.core.http.impl.h1.writer.pas';
  CompareGoRelativeDir = 'benchmarks/nextpas.core.http/compare_go';
  CompareRustRelativeDir = 'benchmarks/nextpas.core.http/compare_rust';
  CompareHyperRelativeDir = 'benchmarks/nextpas.core.http/compare_hyper';
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

function ResolveBenchHeadersBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_headers/bench_headers');
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

function ResolveHyperComparatorBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ResolveBenchmarkTestBuildDir(ARootDir),
    'cargo-target/release/bench_http_server_hyper');
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
  if AImplementation = 'rust_std' then
    CheckContains(AOutput, 'rust_profile=std_only',
      'Rust std-only profile marker');
  if AImplementation = 'rust_hyper' then
    CheckContains(AOutput, 'rust_profile=hyper_tokio',
      'Rust Hyper/Tokio profile marker');
end;

procedure CheckInvalidWorkloadRejected(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir, ALabel: string);
var
  LExitCode: Integer;
  LOutput: string;
begin
  RunProcessAndCapture(AExecutable, AArguments, AWorkingDir, LExitCode,
    LOutput);
  Check(LExitCode <> 0, ALabel + ' should reject invalid workload: ' +
    LOutput);
  CheckContains(LOutput, 'invalid --workload',
    ALabel + ' invalid workload diagnostic');
  CheckContains(LOutput, 'no_url',
    ALabel + ' valid workload list diagnostic');
  CheckNotContains(LOutput, 'workload=no_url',
    ALabel + ' should not silently fall back to no_url');
end;

procedure CheckInvalidScaleRejected(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir, AOptionName,
  ALabel: string);
var
  LExitCode: Integer;
  LOutput: string;
begin
  RunProcessAndCapture(AExecutable, AArguments, AWorkingDir, LExitCode,
    LOutput);
  Check(LExitCode <> 0, ALabel + ' should reject invalid scale: ' +
    LOutput);
  CheckContains(LOutput, 'invalid ' + AOptionName,
    ALabel + ' invalid scale diagnostic');
  CheckNotContains(LOutput, 'operation=http.server.keepalive',
    ALabel + ' should not emit a benchmark row');
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

procedure CheckHeadersLookupBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.headers',
    'headers benchmark operation marker');
  CheckBenchmarkRunRow(AOutput, 'Get hit (5 headers, last)',
    'headers lowercase get-hit benchmark row');
  CheckBenchmarkRunRow(AOutput, 'Get hit uppercase (5 headers, last)',
    'headers uppercase get-hit benchmark row');
  CheckContains(AOutput, 'bench_filter=Get hit',
    'headers benchmark filter marker');
  CheckContains(AOutput, 'ns/op', 'headers benchmark ns/op marker');
  CheckContains(AOutput, 'ops/s', 'headers benchmark ops/s marker');
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

procedure CheckH1WriterHeaderBlockBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.h1writer.serialize',
    'H1 writer header-block operation marker');
  CheckBenchmarkRunRow(AOutput, 'headers block 200 6 headers',
    'H1 writer header-block benchmark row');
  CheckContains(AOutput, 'bench_filter=headers block 200 6 headers',
    'H1 writer header-block filter marker');
  CheckContains(AOutput, 'ns/op', 'H1 writer header-block ns/op marker');
  CheckContains(AOutput, 'ops/s', 'H1 writer header-block ops/s marker');
end;

procedure CheckH1WriterKnownStatusLinesBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.h1writer.serialize',
    'H1 writer known-status operation marker');
  CheckBenchmarkRunRow(AOutput, 'status lines common errors',
    'H1 writer known-status benchmark row');
  CheckContains(AOutput, 'bench_filter=status lines common errors',
    'H1 writer known-status filter marker');
  CheckContains(AOutput, 'ns/op', 'H1 writer known-status ns/op marker');
  CheckContains(AOutput, 'ops/s', 'H1 writer known-status ops/s marker');
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

function ExtractSourceBlock(const ASource, AStartMarker, AEndMarker,
  ALabel: string): string;
var
  LStart: SizeInt;
  LEnd: SizeInt;
  LTail: string;
begin
  LStart := Pos(AStartMarker, ASource);
  Check(LStart > 0, ALabel + ' start marker missing: ' + AStartMarker);
  LTail := Copy(ASource, LStart, MaxInt);
  LEnd := Pos(AEndMarker, LTail);
  Check(LEnd > 0, ALabel + ' end marker missing: ' + AEndMarker);
  Result := Copy(LTail, 1, LEnd - 1);
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

procedure TestBenchServerRejectsInvalidWorkload;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(BenchServerRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchServerRelativeDir);
  LBinaryPath := ResolveBenchServerBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_server invalid workload binary exists');

  CheckInvalidWorkloadRejected(LBinaryPath,
    ['--requests', '1', '--threads', '1', '--workload', 'not_a_workload'],
    LBenchDir, 'bench_server');
end;

procedure TestBenchServerRejectsInvalidScale;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(BenchServerRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchServerRelativeDir);
  LBinaryPath := ResolveBenchServerBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_server invalid scale binary exists');

  CheckInvalidScaleRejected(LBinaryPath,
    ['--requests', '0', '--threads', '1'], LBenchDir, '--requests',
    'bench_server');
  CheckInvalidScaleRejected(LBinaryPath,
    ['--requests', '1', '--threads', '0'], LBenchDir, '--threads',
    'bench_server');
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

procedure TestBenchHeadersLookupSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(BenchHeadersRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchHeadersRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_headers build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchHeadersBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_headers binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=Get hit'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_headers lookup smoke exit code: ' + LOutput);
  CheckHeadersLookupBenchmarkOutput(LOutput);
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

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=headers block 200 6 headers'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1writer header-block smoke exit code: ' + LOutput);
  CheckH1WriterHeaderBlockBenchmarkOutput(LOutput);

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=status lines common errors'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1writer known-status smoke exit code: ' + LOutput);
  CheckH1WriterKnownStatusLinesBenchmarkOutput(LOutput);
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

procedure TestH1ParserRequestMetadataCacheSourceContract;
var
  LRootDir: string;
  LSource: string;
  LBuildBody: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1ParserUnitPath));
  LBuildBody := ExtractSourceBlock(LSource,
    'function TH1Parser.BuildRequestMetadata(',
    'procedure TH1Parser.UpdateRequestMetadataFromHeader',
    'H1 parser BuildRequestMetadata body');

  CheckContains(LSource, 'procedure TH1Parser.UpdateRequestMetadataFromHeader',
    'H1 parser parse-time request metadata helper');
  CheckContains(LSource, 'LSelf.UpdateRequestMetadataFromHeader(LSelf.FCurrentField',
    'H1 parser parse-time request metadata callback hook');
  CheckNotContains(LBuildBody, 'LHeaders := FHeaders;',
    'H1 parser request metadata should not rescan header store');
  CheckNotContains(LBuildBody, 'LHeaders.Get(''host'')',
    'H1 parser request metadata should cache Host during parse');
  CheckNotContains(LBuildBody, 'LHeaders.Get(''connection'')',
    'H1 parser request metadata should cache Connection during parse');
  CheckNotContains(LBuildBody, 'LHeaders.Get(''content-length'')',
    'H1 parser request metadata should cache Content-Length during parse');
  CheckNotContains(LBuildBody, 'LHeaders.GetAll(''expect'')',
    'H1 parser request metadata should cache Expect during parse');
  CheckNotContains(LBuildBody, 'LHeaders.GetAll(''transfer-encoding'')',
    'H1 parser request metadata should cache Transfer-Encoding during parse');
end;

procedure TestH1ParserRequestMetadataSpanFastPathSourceContract;
var
  LRootDir: string;
  LSource: string;
  LUpdateBody: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1ParserUnitPath));
  LUpdateBody := ExtractSourceBlock(LSource,
    'procedure TH1Parser.UpdateRequestMetadataFromHeader',
    'procedure TH1Parser.EnsureBodyCapacity',
    'H1 parser UpdateRequestMetadataFromHeader body');

  CheckContains(LSource, 'function CapturedHeaderValueIsNonEmpty',
    'H1 parser metadata host span helper');
  CheckContains(LSource, 'function CapturedHeaderValueEquals',
    'H1 parser metadata connection span helper');
  CheckContains(LSource, 'function CapturedHeaderValueTrimmedToInt64',
    'H1 parser metadata content-length span helper');
  CheckContains(LSource, 'procedure UpdateExpectMetadataFromCapturedValue',
    'H1 parser metadata expect span helper');
  CheckContains(LUpdateBody, 'CapturedHeaderValueIsNonEmpty(',
    'H1 parser Host metadata should avoid value string materialization');
  CheckContains(LUpdateBody, 'CapturedHeaderValueEquals(',
    'H1 parser Connection metadata should compare spans directly');
  CheckContains(LUpdateBody, 'CapturedHeaderValueTrimmedToInt64(',
    'H1 parser Content-Length metadata should parse spans directly');
  CheckContains(LUpdateBody, 'UpdateExpectMetadataFromCapturedValue(',
    'H1 parser Expect metadata should scan spans directly');
end;

procedure TestH1FastLazyHeadersSourceContract;
var
  LRootDir: string;
  LSource: string;
  LGetBody: string;
  LHasBody: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1FastUnitPath));
  LGetBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.Get(const AName: string): string;',
    'function TFastLazyHeaders.GetAll',
    'TFastLazyHeaders.Get body');
  LHasBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.Has(const AName: string): Boolean;',
    'procedure TFastLazyHeaders.Del',
    'TFastLazyHeaders.Has body');

  CheckContains(LSource, 'function TFastLazyHeaders.FindRawFirstValue',
    'TFastLazyHeaders raw first-value lookup helper');
  CheckContains(LGetBody, 'FindRawFirstValue(AName, Result)',
    'TFastLazyHeaders.Get should use raw first-value lookup');
  CheckNotContains(LGetBody, 'EnsureMaterialized;',
    'TFastLazyHeaders.Get should not materialize the full header block');
  CheckContains(LHasBody, 'FindRawFirstValue(AName, LValue)',
    'TFastLazyHeaders.Has should use raw first-value lookup');
  CheckNotContains(LHasBody, 'EnsureMaterialized;',
    'TFastLazyHeaders.Has should not materialize the full header block');
end;

procedure TestH1WriterCompactHeaderBlockSourceContract;
var
  LRootDir: string;
  LSource: string;
  LWriteHeaderBody: string;
begin
  LRootDir := ResolveCoreRoot(BenchH1WriterRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1WriterUnitPath));
  LWriteHeaderBody := ExtractSourceBlock(LSource,
    'procedure TH1ResponseWriter.WriteHeader(const AStatus: THttpStatus);',
    'function TH1ResponseWriter.GetHeaders: IHttpHeaders;',
    'TH1ResponseWriter.WriteHeader body');

  CheckContains(LSource, 'function TryWriteSmallHeaderBlock: Boolean;',
    'H1 writer compact header-block helper declaration');
  CheckContains(LSource,
    'function TH1ResponseWriter.TryWriteSmallHeaderBlock: Boolean;',
    'H1 writer compact header-block helper implementation');
  CheckContains(LSource, 'procedure TH1ResponseWriter.WriteHeaderBlock;',
    'H1 writer header-block dispatcher implementation');
  CheckContains(LSource, 'if not TryWriteSmallHeaderBlock then',
    'H1 writer header-block dispatcher should try compact path first');
  CheckContains(LWriteHeaderBody, 'WriteHeaderBlock;',
    'TH1ResponseWriter.WriteHeader should use header-block dispatcher');
  CheckNotContains(LWriteHeaderBody,
    'WriteAllHeaders;' + LineEnding + '  WriteCRLF;',
    'TH1ResponseWriter.WriteHeader should not split small header block CRLF');
end;

procedure TestH1WriterKnownStatusLineSourceContract;
var
  LRootDir: string;
  LSource: string;
  LWriteStatusLineBody: string;
begin
  LRootDir := ResolveCoreRoot(BenchH1WriterRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1WriterUnitPath));
  LWriteStatusLineBody := ExtractSourceBlock(LSource,
    'procedure TH1ResponseWriter.WriteStatusLine;',
    'procedure TH1ResponseWriter.WriteInformationalHeader',
    'TH1ResponseWriter.WriteStatusLine body');

  CheckContains(LSource, 'function TryWriteKnownStatusLine: Boolean;',
    'H1 writer known status-line helper declaration');
  CheckContains(LSource,
    'function TH1ResponseWriter.TryWriteKnownStatusLine: Boolean;',
    'H1 writer known status-line helper implementation');
  CheckContains(LWriteStatusLineBody, 'if TryWriteKnownStatusLine then',
    'TH1ResponseWriter.WriteStatusLine should try known status fast path first');
  CheckContains(LSource, '''HTTP/1.1 400 Bad Request''#13#10',
    'H1 writer should have fixed 400 status line');
  CheckContains(LSource, '''HTTP/1.1 500 Internal Server Error''#13#10',
    'H1 writer should have fixed 500 status line');
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

procedure TestGoServerComparatorRejectsInvalidWorkload;
var
  LRootDir: string;
  LCompareDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(CompareGoRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareGoRelativeDir);
  LBinaryPath := ResolveGoComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'go comparator invalid workload binary exists');

  CheckInvalidWorkloadRejected(LBinaryPath,
    ['--requests', '1', '--threads', '1', '--workload', 'not_a_workload'],
    LCompareDir, 'go comparator');
end;

procedure TestGoServerComparatorRejectsInvalidScale;
var
  LRootDir: string;
  LCompareDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(CompareGoRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareGoRelativeDir);
  LBinaryPath := ResolveGoComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'go comparator invalid scale binary exists');

  CheckInvalidScaleRejected(LBinaryPath,
    ['--requests', '0', '--threads', '1'], LCompareDir, '--requests',
    'go comparator');
  CheckInvalidScaleRejected(LBinaryPath,
    ['--requests', '1', '--threads', '0'], LCompareDir, '--threads',
    'go comparator');
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
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '32', '2');
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
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '32', '2', 'url_path');
end;

procedure TestRustServerComparatorRejectsInvalidWorkload;
var
  LRootDir: string;
  LCompareDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(CompareRustRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareRustRelativeDir);
  LBinaryPath := ResolveRustComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'rust comparator invalid workload binary exists');

  CheckInvalidWorkloadRejected(LBinaryPath,
    ['--requests', '1', '--threads', '1', '--workload', 'not_a_workload'],
    LCompareDir, 'rust comparator');
end;

procedure TestRustServerComparatorRejectsInvalidScale;
var
  LRootDir: string;
  LCompareDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(CompareRustRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareRustRelativeDir);
  LBinaryPath := ResolveRustComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'rust comparator invalid scale binary exists');

  CheckInvalidScaleRejected(LBinaryPath,
    ['--requests', '0', '--threads', '1'], LCompareDir, '--requests',
    'rust comparator');
  CheckInvalidScaleRejected(LBinaryPath,
    ['--requests', '1', '--threads', '0'], LCompareDir, '--threads',
    'rust comparator');
end;

procedure TestHyperTokioServerComparatorSmallSmoke;
var
  LRootDir: string;
  LCompareDir: string;
  LBuildDir: string;
  LTargetDir: string;
  LBinaryPath: string;
  LManifestPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(CompareHyperRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareHyperRelativeDir);
  LBuildDir := ResolveBenchmarkTestBuildDir(LRootDir);
  LTargetDir := PathJoin(LBuildDir, 'cargo-target');
  ForceDirectories(LBuildDir);
  LBinaryPath := ResolveHyperComparatorBinaryPath(LRootDir);
  LManifestPath := PathJoin(LCompareDir, 'Cargo.toml');

  RunProcessAndCapture('cargo',
    ['build', '--release', '--manifest-path', LManifestPath,
     '--target-dir', LTargetDir],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'hyper comparator build exit code: ' + LOutput);
  Check(FileExists(LBinaryPath), 'hyper comparator binary exists');

  RunProcessAndCapture(LBinaryPath, ['--requests', '32', '--threads', '2'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'hyper comparator smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'rust_hyper', '32', '2');
end;

procedure TestHyperTokioServerComparatorRejectsInvalidWorkload;
var
  LRootDir: string;
  LCompareDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(CompareHyperRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareHyperRelativeDir);
  LBinaryPath := ResolveHyperComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'hyper comparator invalid workload binary exists');

  CheckInvalidWorkloadRejected(LBinaryPath,
    ['--requests', '1', '--threads', '1', '--workload', 'not_a_workload'],
    LCompareDir, 'hyper comparator');
end;

procedure TestHyperTokioServerComparatorRejectsInvalidScale;
var
  LRootDir: string;
  LCompareDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(CompareHyperRelativeDir);
  LCompareDir := PathJoin(LRootDir, CompareHyperRelativeDir);
  LBinaryPath := ResolveHyperComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'hyper comparator invalid scale binary exists');

  CheckInvalidScaleRejected(LBinaryPath,
    ['--requests', '0', '--threads', '1'], LCompareDir, '--requests',
    'hyper comparator');
  CheckInvalidScaleRejected(LBinaryPath,
    ['--requests', '1', '--threads', '0'], LCompareDir, '--threads',
    'hyper comparator');
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
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1');

  Check(FileExists(LReportPath), 'server comparison report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'report comparison marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1');
  CheckServerBenchmarkOutput(LReport, 'rust_std', '8', '1');
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
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'url_path');

  Check(FileExists(LReportPath), 'server comparison url_path report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'url_path report comparison marker');
  CheckContains(LReport, 'workload=url_path',
    'url_path report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LReport, 'rust_std', '8', '1', 'url_path');
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
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'adapter_no_url');

  Check(FileExists(LReportPath), 'server comparison adapter_no_url report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'adapter_no_url report comparison marker');
  CheckContains(LReport, 'workload=adapter_no_url',
    'adapter_no_url report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'adapter_no_url');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'adapter_no_url');
  CheckServerBenchmarkOutput(LReport, 'rust_std', '8', '1', 'adapter_no_url');
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
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'response_1k');

  Check(FileExists(LReportPath), 'server comparison response_1k report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'response_1k report comparison marker');
  CheckContains(LReport, 'workload=response_1k',
    'response_1k report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LReport, 'rust_std', '8', '1', 'response_1k');
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
  CheckContains(LOutput, 'summary_impl=rust_std', 'rust std summary marker');
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
  CheckContains(LReport, 'summary_impl=rust_std',
    'runs report rust std summary marker');
  CheckContains(LReport, 'median_completed=8',
    'runs report median completed marker');
end;

procedure TestServerComparisonRunnerIncludeHyperSmoke;
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
  Check(FileExists(LRunnerPath), 'server comparison include-hyper runner exists');
  LReportPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_include_hyper_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--include-hyper', '--output', LReportPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison include-hyper runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'include-hyper comparison marker');
  CheckContains(LOutput, 'include_hyper=1',
    'include-hyper runner marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1');
  CheckServerBenchmarkOutput(LOutput, 'rust_hyper', '8', '1');
  CheckContains(LOutput, 'summary_impl=rust_hyper',
    'include-hyper rust_hyper summary marker');

  Check(FileExists(LReportPath), 'server comparison include-hyper report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'include-hyper report comparison marker');
  CheckContains(LReport, 'include_hyper=1',
    'include-hyper report marker');
  CheckServerBenchmarkOutput(LReport, 'rust_hyper', '8', '1');
  CheckContains(LReport, 'summary_impl=rust_hyper',
    'include-hyper report rust_hyper summary marker');
end;

procedure TestServerComparisonSnapshotSmallSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LSnapshotPath: string;
  LRawPath: string;
  LSnapshot: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison snapshot runner exists');
  LSnapshotPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_snapshot_smoke.md');
  LRawPath := LSnapshotPath + '.raw';
  DeleteFile(LSnapshotPath);
  DeleteFile(LRawPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--output', LSnapshotPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath), 'server comparison snapshot exists');
  Check(not FileExists(LRawPath),
    'server comparison snapshot raw temp file should be removed');
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
  CheckServerBenchmarkOutput(LSnapshot, 'rust_std', '8', '1');
end;

procedure TestServerComparisonSnapshotUrlPathSmoke;
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
  Check(FileExists(LRunnerPath),
    'server comparison snapshot url_path runner exists');
  LSnapshotPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_snapshot_url_path_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'url_path', '--output', LSnapshotPath], LRootDir, LExitCode,
    LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot url_path exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath), 'server comparison snapshot url_path exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'workload=url_path',
    'snapshot url_path workload marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --workload url_path --runs 1',
    'snapshot url_path command marker');
  CheckServerBenchmarkOutput(LSnapshot, 'nextpas', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LSnapshot, 'go', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LSnapshot, 'rust_std', '8', '1', 'url_path');
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
  CheckContains(LSnapshot, 'summary_impl=rust_std',
    'snapshot runs rust std summary marker');
end;

procedure TestServerComparisonSnapshotIncludeHyperSmoke;
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
  Check(FileExists(LRunnerPath), 'server comparison snapshot include-hyper runner exists');
  LSnapshotPath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_snapshot_include_hyper_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--include-hyper', '--output', LSnapshotPath], LRootDir, LExitCode,
    LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot include-hyper exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath),
    'server comparison snapshot include-hyper exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --runs 1 --include-hyper',
    'snapshot include-hyper command marker');
  CheckContains(LSnapshot, 'cargo_version=',
    'snapshot include-hyper cargo version marker');
  CheckContains(LSnapshot, 'hyper_cargo_lock_sha256=',
    'snapshot include-hyper Cargo.lock marker');
  CheckServerBenchmarkOutput(LSnapshot, 'rust_hyper', '8', '1');
  CheckContains(LSnapshot, 'summary_impl=rust_hyper',
    'snapshot include-hyper summary marker');
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
  CheckContains(LOutput, 'adapter cost: fast headers get host only',
    'H1 parser benchmark fast lazy header Get row');
  CheckContains(LOutput, 'adapter cost: fast headers foreach all',
    'H1 parser benchmark fast lazy header ForEach row');
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
  T.Run('bench_server rejects invalid workload',
    @TestBenchServerRejectsInvalidWorkload);
  T.Run('bench_server rejects invalid scale',
    @TestBenchServerRejectsInvalidScale);
  T.Run('bench_router handler dispatch smoke',
    @TestBenchRouterHandlerDispatchSmoke);
  T.Run('bench_headers lookup smoke',
    @TestBenchHeadersLookupSmoke);
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
  T.Run('H1 parser request metadata cache source contract',
    @TestH1ParserRequestMetadataCacheSourceContract);
  T.Run('H1 parser request metadata span fast path source contract',
    @TestH1ParserRequestMetadataSpanFastPathSourceContract);
  T.Run('H1 fast lazy headers source contract',
    @TestH1FastLazyHeadersSourceContract);
  T.Run('H1 writer compact header block source contract',
    @TestH1WriterCompactHeaderBlockSourceContract);
  T.Run('H1 writer known status line source contract',
    @TestH1WriterKnownStatusLineSourceContract);
  T.Run('bench_h1outbound drain smoke',
    @TestBenchH1OutboundDrainSmoke);
  T.Run('bench_fullchain plaintext smoke',
    @TestBenchFullchainPlaintextSmoke);
  T.Run('go server comparator small smoke', @TestGoServerComparatorSmallSmoke);
  T.Run('go server comparator url_path small smoke',
    @TestGoServerComparatorUrlPathSmallSmoke);
  T.Run('go server comparator rejects invalid workload',
    @TestGoServerComparatorRejectsInvalidWorkload);
  T.Run('go server comparator rejects invalid scale',
    @TestGoServerComparatorRejectsInvalidScale);
  T.Run('rust server comparator small smoke', @TestRustServerComparatorSmallSmoke);
  T.Run('rust server comparator url_path small smoke',
    @TestRustServerComparatorUrlPathSmallSmoke);
  T.Run('rust server comparator rejects invalid workload',
    @TestRustServerComparatorRejectsInvalidWorkload);
  T.Run('rust server comparator rejects invalid scale',
    @TestRustServerComparatorRejectsInvalidScale);
  T.Run('hyper/tokio server comparator small smoke',
    @TestHyperTokioServerComparatorSmallSmoke);
  T.Run('hyper/tokio server comparator rejects invalid workload',
    @TestHyperTokioServerComparatorRejectsInvalidWorkload);
  T.Run('hyper/tokio server comparator rejects invalid scale',
    @TestHyperTokioServerComparatorRejectsInvalidScale);
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
  T.Run('server comparison runner include hyper smoke',
    @TestServerComparisonRunnerIncludeHyperSmoke);
  T.Run('server comparison snapshot small smoke',
    @TestServerComparisonSnapshotSmallSmoke);
  T.Run('server comparison snapshot url_path smoke',
    @TestServerComparisonSnapshotUrlPathSmoke);
  T.Run('server comparison snapshot runs smoke',
    @TestServerComparisonSnapshotRunsSmoke);
  T.Run('server comparison snapshot include hyper smoke',
    @TestServerComparisonSnapshotIncludeHyperSmoke);
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
