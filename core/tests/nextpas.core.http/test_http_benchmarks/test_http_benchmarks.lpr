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
  ReadmeDocPath = 'docs/http/README.md';
  BenchmarksDocPath = 'docs/http/BENCHMARKS.md';
  ApiCoverageDocPath = 'docs/http/API_COVERAGE.md';
  BenchFullchainUnitPath =
    'benchmarks/nextpas.core.http/bench_fullchain/bench_fullchain.lpr';
  H1ParserBenchMakefilePath =
    'benchmarks/nextpas.core.http/bench_h1parser/Makefile';
  CllhttpMakefilePath =
    'benchmarks/nextpas.core.http/bench_h1parser/compare_c/Makefile';
  CllhttpReadmePath =
    'benchmarks/nextpas.core.http/bench_h1parser/compare_c/README.md';
  CompareGoRelativeDir = 'benchmarks/nextpas.core.http/compare_go';
  CompareRustRelativeDir = 'benchmarks/nextpas.core.http/compare_rust';
  CompareHyperRelativeDir = 'benchmarks/nextpas.core.http/compare_hyper';
  HttpUnitPath = 'src/nextpas.core.http.pas';
  LlhttpRootEnvName = 'NEXTPAS_LLHTTP_ROOT';
  BenchMaxItersEnvName = 'NEXTPAS_BENCH_MAX_ITERS';
  BenchFilterEnvName = 'NEXTPAS_BENCH_FILTER';
  BenchBackendEnvName = 'NEXTPAS_BENCH_BACKEND';
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

procedure CheckLineContains(const AOutput, AExpectedLine, ALabel: string);
var
  LLines: TStringList;
  I: Integer;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := AOutput;
    for I := 0 to LLines.Count - 1 do
      if LLines[I] = AExpectedLine then
        Exit;
  finally
    LLines.Free;
  end;
  Fail(ALabel + ' missing line: ' + AExpectedLine + LineEnding + AOutput);
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

function ResolveServerComparisonOutputDir(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/server_comparison');
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

function CollectTopLevelPascalBenchmarkProjectsWithoutMakefile(
  const ABenchmarksRootDir: string): string;
var
  LSearch: TSearchRec;
  LLprSearch: TSearchRec;
  LProjectDir: string;
  LMissing: TStringList;
begin
  LMissing := TStringList.Create;
  try
    if FindFirst(PathJoin(ABenchmarksRootDir, '*'), faDirectory, LSearch) = 0 then
    begin
      repeat
        if (LSearch.Name = '.') or (LSearch.Name = '..') then
          Continue;
        if (LSearch.Attr and faDirectory) = 0 then
          Continue;

        LProjectDir := PathJoin(ABenchmarksRootDir, LSearch.Name);
        if FindFirst(PathJoin(LProjectDir, '*.lpr'), faAnyFile, LLprSearch) <> 0 then
          Continue;
        FindClose(LLprSearch);

        if FileExists(PathJoin(LProjectDir, 'Makefile')) then
          Continue;

        LMissing.Add(LSearch.Name);
      until FindNext(LSearch) <> 0;
      FindClose(LSearch);
    end;

    Result := Trim(LMissing.Text);
  finally
    LMissing.Free;
  end;
end;

procedure CheckServerBenchmarkOutput(const AOutput, AImplementation: string;
  const AIterations, AThreads: string; const AWorkload: string = 'no_url';
  const ANextpasBackend: string = 'threaded';
  const ANextpasH1Path: string = '');
begin
  CheckLineContains(AOutput, 'operation=http.server.keepalive',
    'operation marker');
  CheckLineContains(AOutput, 'workload=' + AWorkload, 'workload marker');
  CheckLineContains(AOutput, 'impl=' + AImplementation,
    'implementation marker');
  CheckLineContains(AOutput, 'iterations=' + AIterations,
    'iterations marker');
  CheckLineContains(AOutput, 'threads=' + AThreads, 'threads marker');
  CheckLineContains(AOutput, 'completed=' + AIterations,
    'completed marker');
  CheckContains(AOutput, 'ns/op=', 'ns/op marker');
  CheckContains(AOutput, 'req/s=', 'req/s marker');
  if AImplementation = 'nextpas' then
  begin
    CheckLineContains(AOutput, 'backend=' + ANextpasBackend,
      'nextPas backend marker');
    if ANextpasH1Path <> '' then
      CheckLineContains(AOutput, 'nextpas_h1_path=' + ANextpasH1Path,
        'nextPas H1 path marker')
    else
      CheckContains(AOutput, 'nextpas_h1_path=', 'nextPas H1 path marker');
  end;
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

procedure CheckInvalidBackendRejected(const AExecutable: string;
  const AArguments: array of string; const AWorkingDir, ALabel: string);
var
  LExitCode: Integer;
  LOutput: string;
begin
  RunProcessAndCapture(AExecutable, AArguments, AWorkingDir, LExitCode,
    LOutput);
  Check(LExitCode <> 0, ALabel + ' should reject invalid backend: ' +
    LOutput);
  CheckContains(LOutput, 'invalid --backend',
    ALabel + ' invalid backend diagnostic');
  CheckContains(LOutput, 'threaded',
    ALabel + ' valid backend list diagnostic');
  CheckNotContains(LOutput, 'operation=http.server.keepalive',
    ALabel + ' should not emit a benchmark row');
end;

procedure CheckInvalidFullchainBackendRejected(const AExecutable: string;
  const AWorkingDir, ALabel: string);
var
  LExitCode: Integer;
  LOutput: string;
begin
  RunProcessAndCaptureWithEnv(AExecutable, [], AWorkingDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=plaintext',
     BenchBackendEnvName + '=reactor'],
    LExitCode, LOutput);
  Check(LExitCode <> 0, ALabel + ' should reject invalid backend: ' +
    LOutput);
  CheckContains(LOutput, 'invalid ' + BenchBackendEnvName,
    ALabel + ' invalid backend diagnostic');
  CheckContains(LOutput, 'threaded',
    ALabel + ' valid backend list diagnostic');
  CheckNotContains(LOutput, 'operation=http.fullchain.keepalive',
    ALabel + ' should not emit a benchmark row');
end;

procedure CheckInvalidFullchainMaxItersRejected(const AExecutable: string;
  const AWorkingDir, AValue, ALabel: string);
var
  LExitCode: Integer;
  LOutput: string;
begin
  RunProcessAndCaptureWithEnv(AExecutable, [], AWorkingDir,
    [BenchMaxItersEnvName + '=' + AValue,
     BenchFilterEnvName + '=plaintext'],
    LExitCode, LOutput);
  Check(LExitCode <> 0, ALabel + ' should reject invalid max iters: ' +
    LOutput);
  CheckContains(LOutput, 'invalid ' + BenchMaxItersEnvName,
    ALabel + ' invalid max iters diagnostic');
  CheckContains(LOutput, AValue,
    ALabel + ' invalid max iters diagnostic includes value');
  CheckNotContains(LOutput, 'operation=http.fullchain.keepalive',
    ALabel + ' should not emit a benchmark row');
end;

procedure CheckRequestedAndEffectiveThreads(const AOutput,
  ARequestedThreads, AEffectiveThreads, ALabel: string);
begin
  CheckLineContains(AOutput, 'requested_threads=' + ARequestedThreads,
    ALabel + ' requested threads marker');
  CheckLineContains(AOutput, 'effective_threads=' + AEffectiveThreads,
    ALabel + ' effective threads marker');
end;

procedure CheckNextpasBackendHeader(const AOutput, ABackend, ALabel: string);
begin
  CheckLineContains(AOutput, 'nextpas_backend=' + ABackend,
    ALabel + ' nextpas backend header marker');
end;

function ExpectedClientReadMode(const AImplementation: string): string;
begin
  if AImplementation = 'go' then
    Exit('http_client_body_drain');
  Result := 'header_plus_content_length';
end;

procedure CheckResponseReadContract(const AOutput, AImplementation,
  AResponseBodyBytes, ALabel: string);
begin
  CheckLineContains(AOutput,
    'client_read_mode=' + ExpectedClientReadMode(AImplementation),
    ALabel + ' client read mode marker');
  CheckLineContains(AOutput, 'response_body_bytes=' + AResponseBodyBytes,
    ALabel + ' response body bytes marker');
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

procedure CheckRouterDirectCallBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.router.dispatch',
    'router direct-call operation marker');
  CheckContains(AOutput, 'direct call (same request, no router)',
    'router direct-call benchmark row');
  CheckContains(AOutput, 'bench_filter=direct call',
    'router direct-call filter marker');
  CheckContains(AOutput, 'ns/op', 'router direct-call ns/op marker');
  CheckContains(AOutput, 'ops/s', 'router direct-call ops/s marker');
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

procedure CheckH1WriterOutboundDrainBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.h1writer.serialize',
    'H1 writer outbound-drain operation marker');
  CheckBenchmarkRunRow(AOutput, 'outbound fixed 200 1KB',
    'H1 writer outbound-drain benchmark row');
  CheckContains(AOutput, 'bench_filter=outbound fixed 200 1KB',
    'H1 writer outbound-drain filter marker');
  CheckContains(AOutput, 'ns/op', 'H1 writer outbound-drain ns/op marker');
  CheckContains(AOutput, 'ops/s', 'H1 writer outbound-drain ops/s marker');
end;

procedure CheckH1OutboundDrainBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.h1outbound.drain',
    'H1 outbound drain operation marker');
  CheckBenchmarkRunRow(AOutput, 'buffer write+drain 1KB',
    'H1 outbound drain benchmark row');
  CheckContains(AOutput, 'bench_filter=buffer write+drain 1KB',
    'H1 outbound filter marker');
  CheckContains(AOutput, 'ns/op', 'H1 outbound ns/op marker');
  CheckContains(AOutput, 'ops/s', 'H1 outbound ops/s marker');
end;

procedure CheckH1OutboundTryDrainBenchmarkOutput(const AOutput: string);
begin
  CheckContains(AOutput, 'operation=http.h1outbound.drain',
    'H1 outbound trydrain operation marker');
  CheckBenchmarkRunRow(AOutput, 'buffer trydrain runtime 1KB chunk128',
    'H1 outbound trydrain benchmark row');
  CheckContains(AOutput, 'bench_filter=buffer trydrain runtime 1KB chunk128',
    'H1 outbound trydrain filter marker');
  CheckContains(AOutput, 'ns/op', 'H1 outbound trydrain ns/op marker');
  CheckContains(AOutput, 'ops/s', 'H1 outbound trydrain ops/s marker');
end;

procedure CheckFullchainBenchmarkOutput(const AOutput, AWorkload,
  AFilter, ARequestBodyBytes, AResponseBodyBytes: string;
  const ABackend: string = 'threaded';
  const AH1Path: string = 'fast';
  const ADispatchPath: string = 'router';
  const ADirectHandlerHits: string = '0';
  const ARouterHandlerHits: string = '128';
  const AMiddlewareHits: string = '0');
begin
  CheckContains(AOutput, 'operation=http.fullchain.keepalive',
    'fullchain operation marker');
  CheckContains(AOutput, 'client_read_mode=buffered',
    'fullchain client read mode marker');
  CheckContains(AOutput, 'backend=' + ABackend,
    'fullchain backend marker');
  CheckContains(AOutput, 'nextpas_h1_path=' + AH1Path,
    'fullchain H1 path marker');
  CheckContains(AOutput, 'nextpas_dispatch_path=' + ADispatchPath,
    'fullchain dispatch path marker');
  CheckContains(AOutput, 'observed_direct_handler_hits=' + ADirectHandlerHits,
    'fullchain observed direct-handler hits marker');
  CheckContains(AOutput, 'observed_router_handler_hits=' + ARouterHandlerHits,
    'fullchain observed router-handler hits marker');
  CheckContains(AOutput, 'observed_middleware_hits=' + AMiddlewareHits,
    'fullchain observed middleware hits marker');
  CheckContains(AOutput, 'workload=' + AWorkload,
    'fullchain workload marker');
  CheckContains(AOutput,
    'response_validation=strict_status_content_length_body_bytes',
    'fullchain strict response validation marker');
  CheckContains(AOutput, 'request_body_bytes=' + ARequestBodyBytes,
    'fullchain request-body-bytes marker');
  CheckContains(AOutput, 'response_body_bytes=' + AResponseBodyBytes,
    'fullchain response-body-bytes marker');
  CheckContains(AOutput, 'iterations=' + FullchainSmokeIterations,
    'fullchain iterations marker');
  CheckContains(AOutput, 'completed=' + FullchainSmokeIterations,
    'fullchain completed marker');
  CheckContains(AOutput, 'validation_failures=0',
    'fullchain validation-failures marker');
  CheckContains(AOutput, 'elapsed_ns=', 'fullchain elapsed marker');
  CheckContains(AOutput, 'ns/op=', 'fullchain ns/op marker');
  CheckContains(AOutput, 'req/s=', 'fullchain req/s marker');
  CheckContains(AOutput, 'bench_filter=' + AFilter,
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

procedure TestBenchServerRejectsInvalidBackend;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
begin
  LRootDir := ResolveCoreRoot(BenchServerRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchServerRelativeDir);
  LBinaryPath := ResolveBenchServerBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_server invalid backend binary exists');

  CheckInvalidBackendRejected(LBinaryPath,
    ['--requests', '1', '--threads', '1', '--backend', 'reactor'],
    LBenchDir, 'bench_server');
end;

procedure TestBenchServerEpollSmallSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(BenchServerRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchServerRelativeDir);
  LBinaryPath := ResolveBenchServerBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_server epoll binary exists');

  RunProcessAndCapture(LBinaryPath,
    ['--requests', '4', '--threads', '1', '--backend', 'epoll'],
    LBenchDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_server epoll smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '4', '1', 'no_url', 'epoll');
end;

procedure TestServerComparatorsReportRequestedAndEffectiveThreads;
var
  LRootDir: string;
  LBenchDir: string;
  LCompareDir: string;
  LBuildDir: string;
  LTargetDir: string;
  LManifestPath: string;
  LBenchServerPath: string;
  LGoBinaryPath: string;
  LRustBinaryPath: string;
  LHyperBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LBuildDir := ResolveBenchmarkTestBuildDir(LRootDir);
  ForceDirectories(LBuildDir);

  LBenchDir := PathJoin(LRootDir, BenchServerRelativeDir);
  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_server thread-clamp build exit code: ' + LOutput);
  LBenchServerPath := ResolveBenchServerBinaryPath(LRootDir);
  Check(FileExists(LBenchServerPath),
    'bench_server thread-clamp binary exists');

  LCompareDir := PathJoin(LRootDir, CompareGoRelativeDir);
  LGoBinaryPath := ResolveGoComparatorBinaryPath(LRootDir);
  RunProcessAndCapture('go', ['build', '-o', LGoBinaryPath, 'main.go'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'go comparator thread-clamp build exit code: ' + LOutput);
  Check(FileExists(LGoBinaryPath), 'go comparator thread-clamp binary exists');

  LCompareDir := PathJoin(LRootDir, CompareRustRelativeDir);
  LRustBinaryPath := ResolveRustComparatorBinaryPath(LRootDir);
  RunProcessAndCapture('rustc', ['-O', '-o', LRustBinaryPath, 'main.rs'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'rust comparator thread-clamp build exit code: ' + LOutput);
  Check(FileExists(LRustBinaryPath),
    'rust comparator thread-clamp binary exists');

  LCompareDir := PathJoin(LRootDir, CompareHyperRelativeDir);
  LTargetDir := PathJoin(LBuildDir, 'cargo-target');
  LManifestPath := PathJoin(LCompareDir, 'Cargo.toml');
  LHyperBinaryPath := ResolveHyperComparatorBinaryPath(LRootDir);
  RunProcessAndCapture('cargo',
    ['build', '--release', '--manifest-path', LManifestPath,
     '--target-dir', LTargetDir],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'hyper comparator thread-clamp build exit code: ' + LOutput);
  Check(FileExists(LHyperBinaryPath),
    'hyper comparator thread-clamp binary exists');

  RunProcessAndCapture(LBenchServerPath,
    ['--requests', '3', '--threads', '5'], LBenchDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_server thread-clamp smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '3', '3');
  CheckRequestedAndEffectiveThreads(LOutput, '5', '3', 'bench_server');

  LCompareDir := PathJoin(LRootDir, CompareGoRelativeDir);
  RunProcessAndCapture(LGoBinaryPath,
    ['--requests', '3', '--threads', '5'], LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'go comparator thread-clamp smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'go', '3', '3');
  CheckRequestedAndEffectiveThreads(LOutput, '5', '3', 'go comparator');

  LCompareDir := PathJoin(LRootDir, CompareRustRelativeDir);
  RunProcessAndCapture(LRustBinaryPath,
    ['--requests', '3', '--threads', '5'], LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'rust comparator thread-clamp smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '3', '3');
  CheckRequestedAndEffectiveThreads(LOutput, '5', '3', 'rust comparator');

  LCompareDir := PathJoin(LRootDir, CompareHyperRelativeDir);
  RunProcessAndCapture(LHyperBinaryPath,
    ['--requests', '3', '--threads', '5'], LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'hyper comparator thread-clamp smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'rust_hyper', '3', '3');
  CheckRequestedAndEffectiveThreads(LOutput, '5', '3', 'hyper comparator');
end;

procedure TestServerComparatorsReportResponseReadContract;
var
  LRootDir: string;
  LBenchDir: string;
  LCompareDir: string;
  LBuildDir: string;
  LTargetDir: string;
  LManifestPath: string;
  LBenchServerPath: string;
  LGoBinaryPath: string;
  LRustBinaryPath: string;
  LHyperBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LBuildDir := ResolveBenchmarkTestBuildDir(LRootDir);
  ForceDirectories(LBuildDir);

  LBenchDir := PathJoin(LRootDir, BenchServerRelativeDir);
  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_server response-read build exit code: ' + LOutput);
  LBenchServerPath := ResolveBenchServerBinaryPath(LRootDir);
  Check(FileExists(LBenchServerPath),
    'bench_server response-read binary exists');

  LCompareDir := PathJoin(LRootDir, CompareGoRelativeDir);
  LGoBinaryPath := ResolveGoComparatorBinaryPath(LRootDir);
  RunProcessAndCapture('go', ['build', '-o', LGoBinaryPath, 'main.go'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'go comparator response-read build exit code: ' + LOutput);
  Check(FileExists(LGoBinaryPath),
    'go comparator response-read binary exists');

  LCompareDir := PathJoin(LRootDir, CompareRustRelativeDir);
  LRustBinaryPath := ResolveRustComparatorBinaryPath(LRootDir);
  RunProcessAndCapture('rustc', ['-O', '-o', LRustBinaryPath, 'main.rs'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'rust comparator response-read build exit code: ' + LOutput);
  Check(FileExists(LRustBinaryPath),
    'rust comparator response-read binary exists');

  LCompareDir := PathJoin(LRootDir, CompareHyperRelativeDir);
  LTargetDir := PathJoin(LBuildDir, 'cargo-target');
  LManifestPath := PathJoin(LCompareDir, 'Cargo.toml');
  LHyperBinaryPath := ResolveHyperComparatorBinaryPath(LRootDir);
  RunProcessAndCapture('cargo',
    ['build', '--release', '--manifest-path', LManifestPath,
     '--target-dir', LTargetDir],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'hyper comparator response-read build exit code: ' + LOutput);
  Check(FileExists(LHyperBinaryPath),
    'hyper comparator response-read binary exists');

  RunProcessAndCapture(LBenchServerPath,
    ['--requests', '4', '--threads', '1', '--workload', 'response_1k'],
    LBenchDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_server response-read smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '4', '1', 'response_1k');
  CheckResponseReadContract(LOutput, 'nextpas', '1024', 'bench_server');

  LCompareDir := PathJoin(LRootDir, CompareGoRelativeDir);
  RunProcessAndCapture(LGoBinaryPath,
    ['--requests', '4', '--threads', '1', '--workload', 'response_1k'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'go comparator response-read smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'go', '4', '1', 'response_1k');
  CheckResponseReadContract(LOutput, 'go', '1024', 'go comparator');

  LCompareDir := PathJoin(LRootDir, CompareRustRelativeDir);
  RunProcessAndCapture(LRustBinaryPath,
    ['--requests', '4', '--threads', '1', '--workload', 'response_1k'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'rust comparator response-read smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '4', '1', 'response_1k');
  CheckResponseReadContract(LOutput, 'rust_std', '1024', 'rust comparator');

  LCompareDir := PathJoin(LRootDir, CompareHyperRelativeDir);
  RunProcessAndCapture(LHyperBinaryPath,
    ['--requests', '4', '--threads', '1', '--workload', 'response_1k'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'hyper comparator response-read smoke exit code: ' + LOutput);
  CheckServerBenchmarkOutput(LOutput, 'rust_hyper', '4', '1', 'response_1k');
  CheckResponseReadContract(LOutput, 'rust_hyper', '1024', 'hyper comparator');
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
  CheckNotContains(LOutput, 'direct call (same request, no router)',
    'bench_router handler dispatch filter must not match direct baseline');
end;

procedure TestBenchRouterDirectCallSmoke;
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
    'bench_router direct call build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchRouterBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_router direct call binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=direct call'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_router direct call smoke exit code: ' + LOutput);
  CheckRouterDirectCallBenchmarkOutput(LOutput);
  CheckNotContains(LOutput, 'handler dispatch (match + no-op handler)',
    'bench_router direct call filter must not match routed row');
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

procedure TestBenchHeadersRejectsNoMatchFilter;
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
    'bench_headers no-match build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchHeadersBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_headers no-match binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=not_a_headers_benchmark_row'],
    LExitCode, LOutput);
  Check(LExitCode <> 0,
    'bench_headers no-match filter should fail: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=not_a_headers_benchmark_row',
    'bench_headers no-match filter marker');
  CheckContains(LOutput, 'No matching benchmark rows.',
    'bench_headers no-match diagnostic');
  CheckNotContains(LOutput, ' iters',
    'bench_headers no-match must not emit benchmark row');
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

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=outbound fixed 200 1KB'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1writer outbound-drain smoke exit code: ' + LOutput);
  CheckH1WriterOutboundDrainBenchmarkOutput(LOutput);
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

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=buffer trydrain runtime 1KB chunk128'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_h1outbound trydrain smoke exit code: ' + LOutput);
  CheckH1OutboundTryDrainBenchmarkOutput(LOutput);
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
  CheckContains(LSource, 'procedure UpdateConnectionMetadataFromCapturedValue',
    'H1 parser metadata connection token-list span helper');
  CheckContains(LSource, 'function CapturedHeaderValueTrimmedToInt64',
    'H1 parser metadata content-length span helper');
  CheckContains(LSource, 'procedure UpdateExpectMetadataFromCapturedValue',
    'H1 parser metadata expect span helper');
  CheckContains(LUpdateBody, 'CapturedHeaderValueIsNonEmpty(',
    'H1 parser Host metadata should avoid value string materialization');
  CheckContains(LUpdateBody, 'UpdateConnectionMetadataFromCapturedValue(',
    'H1 parser Connection metadata should scan spans directly');
  CheckContains(LUpdateBody, 'CapturedHeaderValueTrimmedToInt64(',
    'H1 parser Content-Length metadata should parse spans directly');
  CheckContains(LUpdateBody, 'UpdateExpectMetadataFromCapturedValue(',
    'H1 parser Expect metadata should scan spans directly');
end;

procedure TestH1FastLazyHeadersSourceContract;
var
  LRootDir: string;
  LSource: string;
  LMaterializeBody: string;
  LRawFirstBody: string;
  LGetAllRawBody: string;
  LCountRawBody: string;
  LGetBody: string;
  LGetAllBody: string;
  LHasBody: string;
  LCountBody: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, H1FastUnitPath));
  LMaterializeBody := ExtractSourceBlock(LSource,
    'procedure TFastLazyHeaders.EnsureMaterialized;',
    'function TFastLazyHeaders.FindRawFirstValue',
    'TFastLazyHeaders.EnsureMaterialized body');
  LRawFirstBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.FindRawFirstValue',
    'function TFastLazyHeaders.GetAllRawValues',
    'TFastLazyHeaders.FindRawFirstValue body');
  LGetAllRawBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.GetAllRawValues',
    'function TFastLazyHeaders.CountRawHeaders',
    'TFastLazyHeaders.GetAllRawValues body');
  LCountRawBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.CountRawHeaders',
    'procedure TFastLazyHeaders.SetHeader',
    'TFastLazyHeaders.CountRawHeaders body');
  LGetBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.Get(const AName: string): string;',
    'function TFastLazyHeaders.GetAll',
    'TFastLazyHeaders.Get body');
  LGetAllBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.GetAll(const AName: string): TStringArray;',
    'function TFastLazyHeaders.Has',
    'TFastLazyHeaders.GetAll body');
  LHasBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.Has(const AName: string): Boolean;',
    'procedure TFastLazyHeaders.Remove',
    'TFastLazyHeaders.Has body');
  LCountBody := ExtractSourceBlock(LSource,
    'function TFastLazyHeaders.Count: Int32;',
    'procedure TFastLazyHeaders.ForEach',
    'TFastLazyHeaders.Count body');

  CheckContains(LSource, 'function TFastLazyHeaders.FindRawFirstValue',
    'TFastLazyHeaders raw first-value lookup helper');
  CheckContains(LSource, 'function TFastLazyHeaders.CountRawHeaders: Int32',
    'TFastLazyHeaders raw count helper');
  CheckContains(LSource, 'function TFastLazyHeaders.GetAllRawValues',
    'TFastLazyHeaders raw multi-value lookup helper');
  CheckContains(LSource, 'function TFastLazyHeaders.NextRawHeader',
    'TFastLazyHeaders shared raw header iterator');
  CheckContains(LMaterializeBody, 'NextRawHeader(LLineStart, LSpan)',
    'TFastLazyHeaders.EnsureMaterialized should use shared raw iterator');
  CheckContains(LMaterializeBody, 'AddParsedSpans(',
    'TFastLazyHeaders.EnsureMaterialized should use parser-trusted span insertion');
  CheckNotContains(LMaterializeBody, 'FHeaders.Add(',
    'TFastLazyHeaders.EnsureMaterialized should not use public header Add path');
  CheckContains(LRawFirstBody, 'NextRawHeader(LLineStart, LSpan)',
    'TFastLazyHeaders.FindRawFirstValue should use shared raw iterator');
  CheckContains(LGetAllRawBody, 'NextRawHeader(LLineStart, LSpan)',
    'TFastLazyHeaders.GetAllRawValues should use shared raw iterator');
  CheckContains(LCountRawBody, 'NextRawHeader(LLineStart, LSpan)',
    'TFastLazyHeaders.CountRawHeaders should use shared raw iterator');
  CheckContains(LGetBody, 'LName := ValidateLookupHeaderNameFast(AName);',
    'TFastLazyHeaders.Get should validate lookup name before raw lookup');
  CheckContains(LGetBody, 'FindRawFirstValue(LName, Result)',
    'TFastLazyHeaders.Get should use raw first-value lookup');
  CheckNotContains(LGetBody, 'EnsureMaterialized;',
    'TFastLazyHeaders.Get should not materialize the full header block');
  CheckContains(LGetAllBody, 'LName := ValidateLookupHeaderNameFast(AName);',
    'TFastLazyHeaders.GetAll should validate lookup name before raw lookup');
  CheckContains(LGetAllBody, 'GetAllRawValues(LName)',
    'TFastLazyHeaders.GetAll should use raw multi-value lookup');
  CheckNotContains(LGetAllBody, 'EnsureMaterialized;',
    'TFastLazyHeaders.GetAll should not materialize the full header block');
  CheckContains(LHasBody, 'LName := ValidateLookupHeaderNameFast(AName);',
    'TFastLazyHeaders.Has should validate lookup name before raw lookup');
  CheckContains(LHasBody, 'HasRawHeader(LName)',
    'TFastLazyHeaders.Has should use raw presence lookup');
  CheckNotContains(LHasBody, 'FindRawFirstValue(LName, LValue)',
    'TFastLazyHeaders.Has should not materialize a temporary header value');
  CheckNotContains(LHasBody, 'EnsureMaterialized;',
    'TFastLazyHeaders.Has should not materialize the full header block');
  CheckContains(LCountBody, 'CountRawHeaders;',
    'TFastLazyHeaders.Count should use raw count lookup');
  CheckNotContains(LCountBody, 'EnsureMaterialized;',
    'TFastLazyHeaders.Count should not materialize the full header block');
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

procedure TestH1WriterOutboundDrainSourceContract;
var
  LRootDir: string;
  LSource: string;
  LBody: string;
begin
  LRootDir := ResolveCoreRoot(BenchH1WriterRelativeDir);
  LSource := LoadTextFile(PathJoin(
    PathJoin(LRootDir, BenchH1WriterRelativeDir),
    'bench_h1writer.lpr'));
  LBody := ExtractSourceBlock(LSource,
    'procedure BenchOutboundFixed200_1KB',
    'begin' + LineEnding + '  InitBody1K;',
    'H1 writer outbound-drain benchmark body');

  CheckContains(LBody, 'LOutbound := NewH1OutboundBuffer;',
    'H1 writer outbound-drain row should allocate an outbound buffer');
  CheckContains(LBody, 'TH1ResponseWriter.Create(LOutbound as IWriter)',
    'H1 writer outbound-drain row should serialize through TH1ResponseWriter');
  CheckContains(LBody, 'LOutbound.DrainAllTo(LSinkWriter);',
    'H1 writer outbound-drain row should drain the outbound buffer');
end;

procedure TestBenchFullchainDirectDispatchSourceContract;
var
  LRootDir: string;
  LSource: string;
  LDispatchBody: string;
  LDirectHostBranch: string;
  LScenarioBlock: string;
begin
  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, BenchFullchainUnitPath));
  LDispatchBody := ExtractSourceBlock(LSource,
    'function ExpectedDispatchPathForWorkload',
    'function ShouldRunScenario',
    'bench_fullchain dispatch path mapper');
  LDirectHostBranch := ExtractSourceBlock(LSource,
    'if AReq.Headers.Get(''host'') = DIRECT_HOST then',
    'LRouterHandler.ServeHTTP(AReq, AW);',
    'bench_fullchain direct host branch');
  LScenarioBlock := ExtractSourceBlock(LSource,
    '{ Scenario 1: Plaintext without router dispatch }',
    '{ Scenario 1: Plaintext }',
    'bench_fullchain direct scenario block');

  CheckContains(LSource, 'GDirectHandlerHits: Int64;',
    'bench_fullchain should track observed direct-handler hits');
  CheckContains(LSource, 'DIRECT_1K_HOST = ''direct-1k'';',
    'bench_fullchain should define explicit direct 1k host');
  CheckContains(LSource, 'GRouterHandlerHits: Int64;',
    'bench_fullchain should track observed router-handler hits');
  CheckContains(LSource, 'Inc(GDirectHandlerHits);',
    'bench_fullchain direct host branch should increment observed hits');
  CheckContains(LSource, 'Inc(GRouterHandlerHits);',
    'bench_fullchain router branch should increment observed hits');
  CheckContains(LSource, 'GDirectHandlerHits := 0;',
    'bench_fullchain should reset observed direct hits after warmup');
  CheckContains(LSource, 'GRouterHandlerHits := 0;',
    'bench_fullchain should reset observed router hits after warmup');
  CheckContains(LSource, 'observed_direct_handler_hits=',
    'bench_fullchain output should expose observed direct-handler hits');
  CheckContains(LSource, 'observed_router_handler_hits=',
    'bench_fullchain output should expose observed router-handler hits');
  CheckContains(LDispatchBody, 'AWorkload = ''direct_root''',
    'bench_fullchain dispatch mapper should mark direct_root');
  CheckContains(LDispatchBody, 'AWorkload = ''direct_1k''',
    'bench_fullchain dispatch mapper should mark direct_1k');
  CheckContains(LDispatchBody, 'Exit(''direct_handler'')',
    'bench_fullchain direct workloads should map to direct_handler');
  CheckNotContains(LDispatchBody, 'AWorkload = ''plaintext''',
    'bench_fullchain plaintext should not map to direct_handler');

  CheckNotContains(LDirectHostBranch, 'AReq.Path',
    'bench_fullchain direct root branch should not project request path');
  CheckContains(LDirectHostBranch, 'WritePlaintextResponse(AW);' + LineEnding +
    '        Exit;',
    'bench_fullchain direct root should exit before router dispatch');
  CheckNotContains(LDirectHostBranch, 'LRouterHandler.ServeHTTP',
    'bench_fullchain direct host branch should not call router');
  CheckContains(LSource, 'if AReq.Headers.Get(''host'') = DIRECT_1K_HOST then',
    'bench_fullchain direct 1k should have an explicit host branch');
  CheckContains(LSource, 'WriteBody1KResponse(AW, LBody1K);' + LineEnding +
    '        Exit;',
    'bench_fullchain direct 1k should exit before router dispatch');

  CheckContains(LScenarioBlock, 'Host: '' + DIRECT_HOST',
    'bench_fullchain direct scenarios should use direct host');
  CheckContains(LScenarioBlock, 'Host: '' + DIRECT_1K_HOST',
    'bench_fullchain direct 1k scenario should use direct 1k host');
  CheckContains(LScenarioBlock, '''GET / HTTP/1.1''',
    'bench_fullchain direct_root should use root request');
  CheckNotContains(LScenarioBlock, 'Host: '' + ROUTER_HOST',
    'bench_fullchain direct scenarios should not use router host');
end;

procedure TestBenchFullchainMiddlewareDispatchSourceContract;
var
  LRootDir: string;
  LSource: string;
  LDispatchBody: string;
  LMiddlewareBranch: string;
  LScenarioBlock: string;
begin
  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, BenchFullchainUnitPath));
  LDispatchBody := ExtractSourceBlock(LSource,
    'function ExpectedDispatchPathForWorkload',
    'function ShouldRunScenario',
    'bench_fullchain dispatch path mapper');
  LMiddlewareBranch := ExtractSourceBlock(LSource,
    'if AReq.Headers.Get(''host'') = MIDDLEWARE_HOST then',
    'Inc(GRouterHandlerHits);' + LineEnding +
    '      LRouterHandler.ServeHTTP(AReq, AW);',
    'bench_fullchain middleware host branch');
  LScenarioBlock := ExtractSourceBlock(LSource,
    '{ Scenario 1c: Plaintext with no-op middleware }',
    '{ Scenario 1: Plaintext }',
    'bench_fullchain middleware scenario block');

  CheckContains(LSource, 'MIDDLEWARE_HOST = ''middleware'';',
    'bench_fullchain should define explicit middleware host');
  CheckContains(LSource, 'GMiddlewareHits: Int64;',
    'bench_fullchain should track observed middleware hits');
  CheckContains(LSource, 'LMiddlewareRouter.Use(MiddlewareFunc',
    'bench_fullchain should install a no-op middleware chain');
  CheckContains(LSource, 'Inc(GMiddlewareHits);',
    'bench_fullchain middleware should increment observed hits');
  CheckContains(LSource, 'GMiddlewareHits := 0;',
    'bench_fullchain should reset observed middleware hits after warmup');
  CheckContains(LSource, 'observed_middleware_hits=',
    'bench_fullchain output should expose observed middleware hits');
  CheckContains(LDispatchBody, 'AWorkload = ''middleware_noop''',
    'bench_fullchain dispatch mapper should mark middleware_noop');
  CheckContains(LDispatchBody, 'Exit(''middleware_router'')',
    'bench_fullchain middleware workload should map to middleware_router');
  CheckNotContains(LDispatchBody, 'AWorkload = ''plaintext''',
    'bench_fullchain plaintext should not map to middleware_router');
  CheckContains(LMiddlewareBranch, 'Inc(GRouterHandlerHits);',
    'bench_fullchain middleware branch should count router dispatch');
  CheckContains(LMiddlewareBranch, 'LMiddlewareHandler.ServeHTTP(AReq, AW);' +
    LineEnding + '        Exit;',
    'bench_fullchain middleware branch should run middleware router and exit');
  CheckNotContains(LMiddlewareBranch, 'LRouterHandler.ServeHTTP',
    'bench_fullchain middleware branch should use the middleware router');
  CheckContains(LScenarioBlock, 'MIDDLEWARE_HOST + #13#10',
    'bench_fullchain middleware scenario should use middleware host');
  CheckContains(LScenarioBlock, '''GET / HTTP/1.1''',
    'bench_fullchain middleware scenario should use root request');
  CheckNotContains(LScenarioBlock, 'Host: '' + ROUTER_HOST',
    'bench_fullchain middleware scenario should not use plain router host');
end;

procedure TestBenchFullchainServerThreadLifecycleSourceContract;
var
  LRootDir: string;
  LSource: string;
  LSetupBody: string;
  LStopBody: string;
  LMainBody: string;
begin
  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, BenchFullchainUnitPath));
  LSetupBody := ExtractSourceBlock(LSource,
    'procedure SetupServer;',
    '{ Read one full HTTP response from a keep-alive connection }',
    'bench_fullchain SetupServer lifecycle body');
  LStopBody := ExtractSourceBlock(LSource,
    'procedure StopServer;',
    'procedure SetupServer;',
    'bench_fullchain StopServer lifecycle body');
  LMainBody := ExtractSourceBlock(LSource,
    'begin' + LineEnding + '  GIterations := ConfiguredIterations;',
    'end.',
    'bench_fullchain main lifecycle body');

  CheckContains(LSource, 'GServerThreadHandle: TPlatformThreadHandle;',
    'bench_fullchain should retain server thread handle globally');
  CheckContains(LSource, 'GServerThreadStarted: Boolean;',
    'bench_fullchain should track whether server thread was created');
  CheckContains(LSetupBody,
    'GServerThreadStarted := platform_thread_create(GServerThreadHandle, @ServerThread, nil) = 0;',
    'bench_fullchain should retain successful server thread creation');
  CheckNotContains(LSetupBody, 'LHandle: TPlatformThreadHandle;',
    'bench_fullchain should not hide server thread handle in SetupServer');
  CheckContains(LSetupBody, 'if not GServerThreadStarted then' + LineEnding +
    '  begin' + LineEnding + '    StopServer;',
    'bench_fullchain should free server when thread creation fails');
  CheckContains(LSource, 'BENCH_SERVER_READY_TIMEOUT_MS = 5000;',
    'bench_fullchain should define a bounded server readiness timeout');
  CheckContains(LSource, 'function WaitForServerReady: Boolean;',
    'bench_fullchain should isolate bounded server readiness waiting');
  CheckContains(LSetupBody, 'if not WaitForServerReady then',
    'bench_fullchain SetupServer should not wait forever for readiness');
  CheckContains(LSetupBody, 'bench_fullchain server did not become ready',
    'bench_fullchain should diagnose readiness timeout');
  CheckContains(LSetupBody, 'if not WaitForServerReady then' + LineEnding +
    '  begin' + LineEnding + '    StopServer;',
    'bench_fullchain should teardown on readiness timeout');
  CheckNotContains(LSetupBody, 'while not GServer.IsRunning do',
    'bench_fullchain should avoid unbounded IsRunning polling');
  CheckContains(LSource, 'procedure StopServer;',
    'bench_fullchain should centralize shutdown/join/free');
  CheckContains(LStopBody, 'platform_thread_join(GServerThreadHandle, LThreadResult);',
    'bench_fullchain should join server thread before freeing server');
  CheckContains(LStopBody, 'platform_thread_join(GServerThreadHandle, LThreadResult);' +
    LineEnding + '    GServerThreadStarted := False;',
    'bench_fullchain should clear thread state after join');
  CheckContains(LStopBody, 'platform_thread_join(GServerThreadHandle, LThreadResult);' +
    LineEnding + '    GServerThreadStarted := False;' + LineEnding +
    '    GServerThreadHandle := nil;' + LineEnding + '  end;' + LineEnding +
    '  if GServer <> nil then',
    'bench_fullchain should join before checking server free');
  CheckContains(LMainBody, 'SetupServer;' + LineEnding + '  try',
    'bench_fullchain main should guard scenarios with try/finally');
  CheckContains(LMainBody, 'LNoMatch := LScenariosRun = 0;',
    'bench_fullchain should record no-match before teardown');
  CheckContains(LMainBody, 'if LNoMatch then' + LineEnding +
    '      WriteLn(''  No matching full-chain scenarios.'')',
    'bench_fullchain should report no-match inside guarded scenario block');
  CheckContains(LMainBody, 'finally' + LineEnding + '    StopServer;' +
    LineEnding + '  end;',
    'bench_fullchain main should always stop server after scenarios');
  CheckContains(LMainBody, 'if LNoMatch then' + LineEnding + '    Halt(2);',
    'bench_fullchain should exit no-match only after teardown');
  CheckNotContains(LMainBody, 'GServer.Free;',
    'bench_fullchain main should not free server outside StopServer');
  CheckNotContains(LMainBody, 'GServer.Shutdown;',
    'bench_fullchain main should not shutdown server outside StopServer');
end;

procedure TestBenchFullchainStrictResponseValidationSourceContract;
var
  LRootDir: string;
  LSource: string;
  LRunBody: string;
begin
  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, BenchFullchainUnitPath));
  LRunBody := ExtractSourceBlock(LSource,
    'function RunScenario',
    'var' + LineEnding + '  LDirectPlaintextReq',
    'bench_fullchain RunScenario response validation body');

  CheckContains(LSource, 'TFullchainResponseRead = record',
    'bench_fullchain should return structured response read truth');
  CheckContains(LSource, 'StatusCode: Int32;',
    'bench_fullchain response truth should include status');
  CheckContains(LSource, 'ContentLength: Int64;',
    'bench_fullchain response truth should include parsed content length');
  CheckContains(LSource, 'BodyBytes: SizeUInt;',
    'bench_fullchain response truth should include measured body bytes');
  CheckContains(LSource, 'Complete: Boolean;',
    'bench_fullchain response truth should include completeness');
  CheckContains(LSource, 'function ResponseMatchesScenario',
    'bench_fullchain should isolate strict response validation');
  CheckContains(LRunBody, 'LResponse := ReadResponse(LConn);',
    'bench_fullchain should read structured response truth per iteration');
  CheckContains(LRunBody,
    'if ResponseMatchesScenario(LResponse, AResponseBodyBytes) then',
    'bench_fullchain completed count should use strict response validation');
  CheckContains(LRunBody, 'Inc(Result.ValidationFailures);',
    'bench_fullchain should count strict response validation failures');
  CheckContains(LRunBody, 'validation_failures=',
    'bench_fullchain should expose strict response validation failures');
  CheckContains(LRunBody, 'if AResult.ValidationFailures <> 0 then',
    'bench_fullchain should fail rows that have validation failures');
  CheckContains(LSource, 'procedure RecordScenarioResult',
    'bench_fullchain should centralize scenario result accounting');
  CheckContains(LSource, 'AValidationFailure := True;',
    'bench_fullchain should retain validation-failure state after scenarios');
  CheckContains(LSource, 'Halt(3);',
    'bench_fullchain should exit non-zero after response validation failure');
  CheckContains(LRunBody,
    'WriteLn(''response_validation=strict_status_content_length_body_bytes'');',
    'bench_fullchain output should disclose strict validation mode');
  CheckNotContains(LRunBody, 'LBytesRead >= AExpectMin',
    'bench_fullchain must not count minimum response bytes as completion');
  CheckNotContains(LSource, 'AExpectMin',
    'bench_fullchain should not carry minimum-byte completion input');
end;

procedure TestBenchmarkDocsAdapterNoUrlFastPathSourceContract;
var
  LRootDir: string;
  LSource: string;
  LAdapterBlock: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, BenchmarksDocPath));
  LAdapterBlock := ExtractSourceBlock(LSource,
    '## Full-Chain Correlation: Explicit Keep-Alive No-URL Workload',
    '## Full-Chain Correlation: 1 KiB Response Workload',
    'BENCHMARKS adapter_no_url section');

  CheckContains(LAdapterBlock, '`Connection: keep-alive`',
    'adapter_no_url docs should identify the explicit keep-alive request');
  CheckContains(LAdapterBlock, '`nextpas_h1_path=fast`',
    'adapter_no_url docs should record current nextPas H1 path marker');
  CheckNotContains(LAdapterBlock, 'forced-adapter',
    'adapter_no_url docs should not call current keep-alive row forced-adapter');
  CheckNotContains(LAdapterBlock, 'forces `TryUseFastRequestParser`',
    'adapter_no_url docs should not claim keep-alive rejects the fast path');
  CheckNotContains(LAdapterBlock, '`HasConnection`',
    'adapter_no_url docs should not cite old HasConnection rejection');
end;

procedure TestBenchmarkDocsFullchainStableMarkersSourceContract;
var
  LRootDir: string;
  LSource: string;
  LMarkersBlock: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, BenchmarksDocPath));
  LMarkersBlock := ExtractSourceBlock(LSource,
    'markers:',
    'The narrowest full-chain workloads now split router dispatch',
    'BENCHMARKS fullchain stable markers block');

  CheckContains(LMarkersBlock,
    '`response_validation=strict_status_content_length_body_bytes`',
    'BENCHMARKS fullchain stable markers should document strict response validation');
  CheckContains(LMarkersBlock, '`validation_failures`',
    'BENCHMARKS fullchain stable markers should document validation failures');
  CheckContains(LMarkersBlock, '`bench_max_iters=<iterations>`',
    'BENCHMARKS fullchain stable markers should document max iterations');
  CheckContains(LMarkersBlock, '`bench_filter=<filter when set>`',
    'BENCHMARKS fullchain stable markers should document filtered run marker');
end;

procedure TestReadmeFullchainBenchmarkTruthSourceContract;
var
  LRootDir: string;
  LSource: string;
  LFullchainBlock: string;
begin
  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, ReadmeDocPath));
  LFullchainBlock := ExtractSourceBlock(LSource,
    'Run the filtered full-chain keep-alive benchmark:',
    'Run the focused comparator smoke from the test harness:',
    'README fullchain benchmark quickstart');

  CheckContains(LFullchainBlock, 'operation=http.fullchain.keepalive',
    'README fullchain quickstart should name the fullchain operation');
  CheckContains(LFullchainBlock, '`workload=plaintext`',
    'README fullchain quickstart should name the filtered workload marker');
  CheckContains(LFullchainBlock, '`workload=middleware_noop`',
    'README fullchain quickstart should name the middleware workload marker');
  CheckContains(LFullchainBlock, '`request_body_bytes`',
    'README fullchain quickstart should document request body marker');
  CheckContains(LFullchainBlock, '`response_body_bytes`',
    'README fullchain quickstart should document response body marker');
  CheckContains(LFullchainBlock, '`backend`',
    'README fullchain quickstart should document backend marker');
  CheckContains(LFullchainBlock, '`nextpas_h1_path`',
    'README fullchain quickstart should document H1 parser path marker');
  CheckContains(LFullchainBlock, '`nextpas_dispatch_path`',
    'README fullchain quickstart should document dispatch path marker');
  CheckContains(LFullchainBlock, '`nextpas_dispatch_path=middleware_router`',
    'README fullchain quickstart should document middleware dispatch marker');
  CheckContains(LFullchainBlock, '`observed_direct_handler_hits`',
    'README fullchain quickstart should document direct handler hit marker');
  CheckContains(LFullchainBlock, '`observed_router_handler_hits`',
    'README fullchain quickstart should document router handler hit marker');
  CheckContains(LFullchainBlock, '`observed_middleware_hits`',
    'README fullchain quickstart should document middleware hit marker');
  CheckContains(LFullchainBlock, '`client_read_mode=buffered`',
    'README fullchain quickstart should document buffered client read mode');
  CheckContains(LFullchainBlock, '`NEXTPAS_BENCH_FILTER` matches no scenario',
    'README fullchain quickstart should document no-match filter behavior');
  CheckContains(LFullchainBlock, 'exits non-zero',
    'README fullchain quickstart should document no-match exit status');
end;

procedure TestApiCoverageBenchmarkEvidenceSummarySourceContract;
var
  LRootDir: string;
  LSource: string;
  LBlock: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LSource := LoadTextFile(PathJoin(LRootDir, ApiCoverageDocPath));
  LBlock := ExtractSourceBlock(LSource,
    '- `bench_http_server` benchmark evidence summary:',
    '- `test_http_benchmarks` 现在还用 source-contract smoke 锁住 H1 server policy',
    'API_COVERAGE benchmark evidence summary block');

  CheckContains(LBlock, '`BENCHMARKS.md`',
    'API coverage benchmark summary should point to BENCHMARKS.md');
  CheckContains(LBlock, 'middleware_noop',
    'API coverage benchmark summary should mention middleware fullchain row');
  CheckContains(LBlock, 'observed_middleware_hits',
    'API coverage benchmark summary should mention middleware hit marker');
  CheckContains(LBlock, '`impl=rust_std`',
    'API coverage benchmark summary should preserve rust std marker');
  CheckContains(LBlock, '`rust_profile=std_only`',
    'API coverage benchmark summary should preserve rust std profile marker');
  CheckContains(LBlock, '`impl=rust_hyper`',
    'API coverage benchmark summary should preserve hyper marker');
  CheckContains(LBlock, '`rust_profile=hyper_tokio`',
    'API coverage benchmark summary should preserve hyper profile marker');
  CheckContains(LBlock, 'not a permanent ranking',
    'API coverage benchmark summary should avoid ranking claims');
  CheckNotContains(LBlock, '`--requests 8 --threads 1 --output ...`',
    'API coverage benchmark summary should not duplicate runner command matrix');
  CheckNotContains(LBlock, '`--workload url_path`、`--workload adapter_no_url`、`--workload response_1k`',
    'API coverage benchmark summary should not enumerate workload smoke matrix');
  CheckNotContains(LBlock, '逐次 `run=...`',
    'API coverage benchmark summary should not duplicate multi-run details');
  CheckNotContains(LBlock, '自定义 `NEXTPAS_FLAG_MATRIX_OUTPUT_DIR`',
    'API coverage benchmark summary should not duplicate H1 flag matrix details');
end;

procedure TestH1ParserLlhttpRootAliasSourceContract;
var
  LRootDir: string;
  LParentMakefile: string;
  LCompareMakefile: string;
  LRunnerScript: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LParentMakefile := LoadTextFile(PathJoin(LRootDir,
    H1ParserBenchMakefilePath));
  LCompareMakefile := LoadTextFile(PathJoin(LRootDir,
    CllhttpMakefilePath));
  LRunnerScript := LoadTextFile(ResolveH1FlagMatrixRunnerPath(LRootDir));

  CheckContains(LRunnerScript,
    'LLHTTP_ROOT_VALUE="${LLHTTP_ROOT:-${NEXTPAS_LLHTTP_ROOT:-}}"',
    'flag matrix should prefer LLHTTP_ROOT and fall back to NEXTPAS_LLHTTP_ROOT');
  CheckContains(LRunnerScript, 'llhttp_root=$LLHTTP_ROOT_VALUE',
    'flag matrix should record the effective llhttp root in env.txt');
  CheckContains(LRunnerScript, 'LLHTTP_ROOT="$LLHTTP_ROOT_VALUE"',
    'flag matrix should pass the effective root to the C comparator build');

  CheckContains(LParentMakefile,
    'EFFECTIVE_LLHTTP_ROOT := $(if $(LLHTTP_ROOT),$(LLHTTP_ROOT),$(NEXTPAS_LLHTTP_ROOT))',
    'parent H1 parser Makefile should compute an effective llhttp root');
  CheckContains(LParentMakefile,
    'LLHTTP_ROOT="$(EFFECTIVE_LLHTTP_ROOT)"',
    'parent H1 parser run-c should pass the effective llhttp root');

  CheckContains(LCompareMakefile,
    'EFFECTIVE_LLHTTP_ROOT := $(if $(LLHTTP_ROOT),$(LLHTTP_ROOT),$(NEXTPAS_LLHTTP_ROOT))',
    'C llhttp Makefile should compute an effective llhttp root');
  CheckContains(LCompareMakefile, 'NEXTPAS_LLHTTP_ROOT',
    'C llhttp Makefile diagnostic should mention the fallback env alias');
  CheckContains(LCompareMakefile, '$(EFFECTIVE_LLHTTP_ROOT)/include/llhttp.h',
    'C llhttp Makefile should use the effective root for modern layout');
  CheckContains(LCompareMakefile, '$(EFFECTIVE_LLHTTP_ROOT)/build',
    'C llhttp Makefile should use the effective root for generated layout');
end;

procedure TestBenchmarkDocsH1ParserRunnerTruthSourceContract;
var
  LRootDir: string;
  LReadme: string;
  LBenchmarks: string;
  LCReadme: string;
  LReadmeBlock: string;
  LFlagMatrixBlock: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LReadme := LoadTextFile(PathJoin(LRootDir, ReadmeDocPath));
  LBenchmarks := LoadTextFile(PathJoin(LRootDir, BenchmarksDocPath));
  LCReadme := LoadTextFile(PathJoin(LRootDir, CllhttpReadmePath));

  LReadmeBlock := ExtractSourceBlock(LReadme,
    'For narrowed `Pascal raw llhttp vs C llhttp` work, use the H1 parser flag',
    'See [BENCHMARKS.md](BENCHMARKS.md)',
    'README H1 parser flag matrix block');
  LFlagMatrixBlock := ExtractSourceBlock(LBenchmarks,
    '`bench_h1parser/run_flag_matrix.sh` now provides a repeatable smoke/full matrix',
    'Do not run multiple `clean run` jobs against the same `bench_h1parser` build',
    'BENCHMARKS H1 parser flag matrix block');

  CheckContains(LReadmeBlock, 'case-insensitive substring',
    'README should define benchmark filter matching semantics');
  CheckContains(LReadmeBlock, '`LLHTTP_ROOT` takes' + LineEnding +
    'precedence',
    'README should document LLHTTP_ROOT priority');
  CheckContains(LReadmeBlock, 'NEXTPAS_LLHTTP_ROOT',
    'README should document the llhttp root fallback alias');
  CheckContains(LReadmeBlock,
    'build/projects/nextpas.core.http/bench_h1parser/flag_matrix',
    'README should document flag-matrix output root');
  CheckContains(LReadmeBlock, 'Do not commit',
    'README should document benchmark artifact hygiene');

  CheckContains(LFlagMatrixBlock, 'case-insensitive',
    'BENCHMARKS should define case-insensitive benchmark filters');
  CheckContains(LFlagMatrixBlock, 'substring matching',
    'BENCHMARKS should define substring benchmark filters');
  CheckContains(LFlagMatrixBlock, 'no-match exits non-zero',
    'BENCHMARKS should document no-match filter exit semantics');
  CheckContains(LFlagMatrixBlock, '`LLHTTP_ROOT` takes' + LineEnding +
    'precedence',
    'BENCHMARKS should document LLHTTP_ROOT priority');
  CheckContains(LFlagMatrixBlock, 'NEXTPAS_LLHTTP_ROOT',
    'BENCHMARKS should document the llhttp root fallback alias');
  CheckContains(LFlagMatrixBlock, '.raw',
    'BENCHMARKS should document transient raw artifact hygiene');
  CheckContains(LFlagMatrixBlock, '`env.txt`',
    'BENCHMARKS should document flag-matrix env artifact');
  CheckContains(LFlagMatrixBlock, '`bench_filter=`',
    'BENCHMARKS should document flag-matrix Pascal filter marker');
  CheckContains(LFlagMatrixBlock, '`c_bench_filter=`',
    'BENCHMARKS should document flag-matrix C filter marker');
  CheckContains(LFlagMatrixBlock, '`perf_requested=`',
    'BENCHMARKS should document flag-matrix perf request marker');
  CheckContains(LFlagMatrixBlock, '`perf_usable=`',
    'BENCHMARKS should document flag-matrix perf usability marker');
  CheckContains(LFlagMatrixBlock, '`results.tsv` columns:',
    'BENCHMARKS should document flag-matrix results columns');
  CheckContains(LFlagMatrixBlock, '`summary.tsv` columns:',
    'BENCHMARKS should document flag-matrix summary columns');

  CheckContains(LCReadme, 'case-insensitive substring',
    'C comparator README should document shared filter semantics');
  CheckContains(LCReadme, '`LLHTTP_ROOT` takes precedence',
    'C comparator README should document LLHTTP_ROOT priority');
  CheckContains(LCReadme, 'NEXTPAS_LLHTTP_ROOT',
    'C comparator README should document the llhttp root fallback alias');
  CheckContains(LCReadme, '.raw',
    'C comparator README should document transient raw artifact hygiene');
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
  CheckFullchainBenchmarkOutput(LOutput, 'plaintext', 'plaintext', '0', '13');
  CheckNotContains(LOutput, 'workload=direct_root',
    'bench_fullchain plaintext filter must not match direct_root');
end;

procedure TestBenchFullchainDirectPlaintextSmoke;
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
    'bench_fullchain direct plaintext build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain direct plaintext binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=direct_root'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain direct plaintext smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'direct_root', 'direct_root', '0',
    '13', 'threaded', 'fast', 'direct_handler', '128', '0');
  CheckNotContains(LOutput, 'workload=direct_1k',
    'bench_fullchain direct_root filter must not match direct_1k');
end;

procedure TestBenchFullchainDirect1KSmoke;
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
    'bench_fullchain direct 1k build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain direct 1k binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=direct_1k'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain direct 1k smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'direct_1k', 'direct_1k', '0',
    '1024', 'threaded', 'fast', 'direct_handler', '128', '0');
end;

procedure TestBenchFullchainMiddlewareNoopSmoke;
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
    'bench_fullchain middleware build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain middleware binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=middleware_noop'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain middleware smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'middleware_noop',
    'middleware_noop', '0', '13', 'threaded', 'fast',
    'middleware_router', '0', '128', '128');
  CheckNotContains(LOutput, 'workload=plaintext',
    'bench_fullchain middleware filter must not match plaintext');
end;

procedure TestBenchFullchainEcho1KSmoke;
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
    'bench_fullchain echo 1k build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain echo 1k binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=echo_1k'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain echo 1k smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'echo_1k', 'echo_1k', '1024', '1024',
    'threaded', 'llhttp');
end;

procedure TestBenchFullchainJsonSmoke;
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
    'bench_fullchain json build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain json binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=json'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain json smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'json', 'json', '0', '27');
  CheckNotContains(LOutput, 'workload=plaintext',
    'bench_fullchain json filter must not match plaintext');
end;

procedure TestBenchFullchainParamRouteSmoke;
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
    'bench_fullchain param route build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain param route binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=param_route'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain param route smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'param_route', 'param_route', '0',
    '10');
end;

procedure TestBenchFullchainSink16KSmoke;
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
    'bench_fullchain sink 16k build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain sink 16k binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=sink_16k'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain sink 16k smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'sink_16k', 'sink_16k', '16384', '0',
    'threaded', 'llhttp');
end;

procedure TestBenchFullchainRejectsInvalidBackend;
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
    'bench_fullchain invalid backend build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain invalid backend binary exists');

  CheckInvalidFullchainBackendRejected(LBinaryPath, LBenchDir,
    'bench_fullchain');
end;

procedure TestBenchFullchainRejectsInvalidMaxIters;
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
    'bench_fullchain invalid max-iters build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain invalid max-iters binary exists');

  CheckInvalidFullchainMaxItersRejected(LBinaryPath, LBenchDir, '0',
    'bench_fullchain zero max iters');
  CheckInvalidFullchainMaxItersRejected(LBinaryPath, LBenchDir, 'not_an_int',
    'bench_fullchain non-integer max iters');
end;

procedure TestBenchFullchainEpollDirectPlaintextSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchFullchainRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain epoll build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain epoll binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=direct_root',
     BenchBackendEnvName + '=epoll'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain epoll smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'direct_root', 'direct_root', '0',
    '13',
    'epoll', 'fast', 'direct_handler', '128', '0');
end;

procedure TestBenchFullchainEpollDirect1KSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchFullchainRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain epoll direct 1k build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain epoll direct 1k binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=direct_1k',
     BenchBackendEnvName + '=epoll'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain epoll direct 1k smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'direct_1k', 'direct_1k', '0',
    '1024', 'epoll', 'fast', 'direct_handler', '128', '0');
end;

procedure TestBenchFullchainEpollEcho1KSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchFullchainRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain epoll echo 1k build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain epoll echo 1k binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=echo_1k',
     BenchBackendEnvName + '=epoll'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain epoll echo 1k smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'echo_1k', 'echo_1k', '1024', '1024',
    'epoll', 'llhttp');
end;

procedure TestBenchFullchainEpollSink16KSmoke;
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(BenchFullchainRelativeDir);
  LBenchDir := PathJoin(LRootDir, BenchFullchainRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain epoll sink 16k build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain epoll sink 16k binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=sink_16k',
     BenchBackendEnvName + '=epoll'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'bench_fullchain epoll sink 16k smoke exit code: ' + LOutput);
  CheckFullchainBenchmarkOutput(LOutput, 'sink_16k', 'sink_16k', '16384', '0',
    'epoll', 'llhttp');
end;

procedure TestBenchFullchainRejectsNoMatchFilter;
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
    'bench_fullchain no-match build exit code: ' + LOutput);

  LBinaryPath := ResolveBenchFullchainBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'bench_fullchain no-match binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + FullchainSmokeIterations,
     BenchFilterEnvName + '=not_a_fullchain_scenario'],
    LExitCode, LOutput);
  Check(LExitCode <> 0,
    'bench_fullchain no-match filter should fail: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=not_a_fullchain_scenario',
    'fullchain no-match filter marker');
  CheckContains(LOutput, 'No matching full-chain scenarios.',
    'fullchain no-match diagnostic');
  CheckNotContains(LOutput, 'workload=plaintext',
    'fullchain no-match must not emit benchmark row');
end;

procedure TestHttpTopLevelPascalBenchmarkProjectsHaveMakefiles;
var
  LRootDir: string;
  LMissing: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LMissing := CollectTopLevelPascalBenchmarkProjectsWithoutMakefile(
    PathJoin(LRootDir, 'benchmarks/nextpas.core.http'));
  CheckEqual('', LMissing,
    'top-level HTTP Pascal benchmark projects missing Makefile');
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

procedure TestHyperTokioServerComparatorUrlPathSmallSmoke;
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
    'hyper comparator url_path build exit code: ' + LOutput);
  Check(FileExists(LBinaryPath), 'hyper comparator url_path binary exists');

  RunProcessAndCapture(LBinaryPath,
    ['--requests', '32', '--threads', '2', '--workload', 'url_path'],
    LCompareDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'hyper comparator url_path smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'workload=url_path',
    'hyper comparator url_path workload marker');
  CheckServerBenchmarkOutput(LOutput, 'rust_hyper', '32', '2', 'url_path');
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
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--output', LReportPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'comparison marker');
  CheckNextpasBackendHeader(LOutput, 'threaded', 'comparison');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1');

  Check(FileExists(LReportPath), 'server comparison report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'report comparison marker');
  CheckNextpasBackendHeader(LReport, 'threaded', 'report');
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
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'adapter_no_url',
    'threaded', 'fast');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'adapter_no_url');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'adapter_no_url');

  Check(FileExists(LReportPath), 'server comparison adapter_no_url report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'adapter_no_url report comparison marker');
  CheckContains(LReport, 'workload=adapter_no_url',
    'adapter_no_url report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'adapter_no_url',
    'threaded', 'fast');
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
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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
  CheckContains(LOutput, 'client_read_mode=header_plus_content_length',
    'response_1k comparison direct-read marker');
  CheckContains(LOutput, 'client_read_mode=http_client_body_drain',
    'response_1k comparison Go read marker');
  CheckContains(LOutput, 'response_body_bytes=1024',
    'response_1k comparison body-bytes marker');

  Check(FileExists(LReportPath), 'server comparison response_1k report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'response_1k report comparison marker');
  CheckContains(LReport, 'workload=response_1k',
    'response_1k report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LReport, 'rust_std', '8', '1', 'response_1k');
  CheckContains(LReport, 'client_read_mode=header_plus_content_length',
    'response_1k report direct-read marker');
  CheckContains(LReport, 'client_read_mode=http_client_body_drain',
    'response_1k report Go read marker');
  CheckContains(LReport, 'response_body_bytes=1024',
    'response_1k report body-bytes marker');
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
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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
  CheckContains(LOutput, 'summary_rust_profile=std_only',
    'rust std summary profile marker');
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
  CheckContains(LReport, 'summary_rust_profile=std_only',
    'runs report rust std summary profile marker');
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
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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
  CheckContains(LOutput, 'summary_rust_profile=std_only',
    'include-hyper rust_std summary profile marker');
  CheckContains(LOutput, 'summary_rust_profile=hyper_tokio',
    'include-hyper rust_hyper summary profile marker');

  Check(FileExists(LReportPath), 'server comparison include-hyper report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'include-hyper report comparison marker');
  CheckContains(LReport, 'include_hyper=1',
    'include-hyper report marker');
  CheckServerBenchmarkOutput(LReport, 'rust_hyper', '8', '1');
  CheckContains(LReport, 'summary_impl=rust_hyper',
    'include-hyper report rust_hyper summary marker');
  CheckContains(LReport, 'summary_rust_profile=std_only',
    'include-hyper report rust_std summary profile marker');
  CheckContains(LReport, 'summary_rust_profile=hyper_tokio',
    'include-hyper report rust_hyper summary profile marker');
end;

procedure TestServerComparisonRunnerIncludeHyperUrlPathSmoke;
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
  Check(FileExists(LRunnerPath),
    'server comparison include-hyper url_path runner exists');
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_include_hyper_url_path_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'url_path', '--include-hyper', '--output', LReportPath],
    LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison include-hyper url_path runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'include-hyper url_path comparison marker');
  CheckContains(LOutput, 'include_hyper=1',
    'include-hyper url_path runner marker');
  CheckContains(LOutput, 'workload=url_path',
    'include-hyper url_path workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LOutput, 'rust_hyper', '8', '1', 'url_path');
  CheckContains(LOutput, 'rust_profile=hyper_tokio',
    'include-hyper url_path hyper profile marker');
  CheckContains(LOutput, 'summary_impl=rust_hyper',
    'include-hyper url_path rust_hyper summary marker');

  Check(FileExists(LReportPath),
    'server comparison include-hyper url_path report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'include-hyper url_path report comparison marker');
  CheckContains(LReport, 'include_hyper=1',
    'include-hyper url_path report marker');
  CheckContains(LReport, 'workload=url_path',
    'include-hyper url_path report workload marker');
  CheckServerBenchmarkOutput(LReport, 'rust_hyper', '8', '1', 'url_path');
  CheckContains(LReport, 'rust_profile=hyper_tokio',
    'include-hyper url_path report hyper profile marker');
  CheckContains(LReport, 'summary_impl=rust_hyper',
    'include-hyper url_path report rust_hyper summary marker');
end;

procedure TestServerComparisonRunnerIncludeHyperResponse1KSmoke;
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
  Check(FileExists(LRunnerPath),
    'server comparison include-hyper response_1k runner exists');
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_include_hyper_response_1k_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'response_1k', '--include-hyper', '--output', LReportPath],
    LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison include-hyper response_1k runner exit code: ' + LOutput);
  CheckContains(LOutput, 'comparison=http.server.keepalive',
    'include-hyper response_1k comparison marker');
  CheckContains(LOutput, 'include_hyper=1',
    'include-hyper response_1k runner marker');
  CheckContains(LOutput, 'workload=response_1k',
    'include-hyper response_1k workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LOutput, 'rust_hyper', '8', '1', 'response_1k');
  CheckResponseReadContract(LOutput, 'rust_hyper', '1024',
    'include-hyper response_1k hyper row');
  CheckContains(LOutput, 'rust_profile=hyper_tokio',
    'include-hyper response_1k hyper profile marker');
  CheckContains(LOutput, 'summary_impl=rust_hyper',
    'include-hyper response_1k rust_hyper summary marker');
  CheckContains(LOutput, 'summary_rust_profile=std_only',
    'include-hyper response_1k rust_std summary profile marker');
  CheckContains(LOutput, 'summary_rust_profile=hyper_tokio',
    'include-hyper response_1k rust_hyper summary profile marker');

  Check(FileExists(LReportPath),
    'server comparison include-hyper response_1k report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'comparison=http.server.keepalive',
    'include-hyper response_1k report comparison marker');
  CheckContains(LReport, 'include_hyper=1',
    'include-hyper response_1k report marker');
  CheckContains(LReport, 'workload=response_1k',
    'include-hyper response_1k report workload marker');
  CheckServerBenchmarkOutput(LReport, 'rust_hyper', '8', '1', 'response_1k');
  CheckResponseReadContract(LReport, 'rust_hyper', '1024',
    'include-hyper response_1k report hyper row');
  CheckContains(LReport, 'rust_profile=hyper_tokio',
    'include-hyper response_1k report hyper profile marker');
  CheckContains(LReport, 'summary_impl=rust_hyper',
    'include-hyper response_1k report rust_hyper summary marker');
  CheckContains(LReport, 'summary_rust_profile=std_only',
    'include-hyper response_1k report rust_std summary profile marker');
  CheckContains(LReport, 'summary_rust_profile=hyper_tokio',
    'include-hyper response_1k report rust_hyper summary profile marker');
end;

procedure TestServerComparisonRunnerConcurrencyLockSourceContract;
var
  LRootDir: string;
  LSource: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LSource := LoadTextFile(ResolveServerComparisonRunnerPath(LRootDir));

  CheckContains(LSource, 'COMPARISON_LOCK_DIR=',
    'server comparison lock dir marker');
  CheckContains(LSource, 'COMPARISON_LOCK_HELD=0',
    'server comparison lock held marker');
  CheckContains(LSource, 'acquire_comparison_lock()',
    'server comparison acquire lock helper');
  CheckContains(LSource, 'release_comparison_lock()',
    'server comparison release lock helper');
  CheckContains(LSource, 'COMPARISON_LOCK_TIMEOUT_SECONDS=',
    'server comparison lock timeout marker');
  CheckContains(LSource, 'timed out waiting for comparison lock',
    'server comparison lock timeout diagnostic');
  CheckNotContains(LSource,
    'while ! mkdir "${COMPARISON_LOCK_DIR}" 2>/dev/null; do',
    'server comparison lock wait must be bounded');
  CheckContains(LSource, 'acquire_comparison_lock',
    'server comparison acquire lock usage');
  CheckContains(LSource, 'release_comparison_lock',
    'server comparison release lock usage');
end;

procedure TestServerComparisonSummaryKeepsReadModeMetadataSourceContract;
var
  LRootDir: string;
  LSource: string;
  LDocs: string;
  LDocsBlock: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LSource := LoadTextFile(ResolveServerComparisonRunnerPath(LRootDir));
  LDocs := LoadTextFile(PathJoin(LRootDir, BenchmarksDocPath));
  LDocsBlock := ExtractSourceBlock(LDocs,
    '## Benchmark Tooling: Multi-Run Server Comparison',
    'Each raw nextPas row for the current no-body H1 workloads',
    'BENCHMARKS multi-run server comparison summary block');

  CheckContains(LSource, 'client_read_mode="$(printf',
    'server comparison parses client read mode from raw row');
  CheckContains(LSource, 'response_body_bytes="$(printf',
    'server comparison parses response body bytes from raw row');
  CheckContains(LSource, 'read_mode_values[impl, count[impl]] = $6',
    'server comparison summary stores client read mode column');
  CheckContains(LSource, 'body_bytes_values[impl, count[impl]] = $7',
    'server comparison summary stores response body bytes column');
  CheckContains(LSource, 'summary_client_read_mode=%s',
    'server comparison summary prints client read mode');
  CheckContains(LSource, 'summary_response_body_bytes=%s',
    'server comparison summary prints response body bytes');
  CheckContains(LSource, 'summary_operation=%s',
    'server comparison summary prints operation marker');
  CheckContains(LSource, 'summary_workload=%s',
    'server comparison summary prints workload marker');
  CheckContains(LDocsBlock, '`summary_client_read_mode=...`',
    'BENCHMARKS should document summary client read mode marker');
  CheckContains(LDocsBlock, '`summary_response_body_bytes=...`',
    'BENCHMARKS should document summary response body bytes marker');
  CheckContains(LDocsBlock, '`summary_rust_profile=...`',
    'BENCHMARKS should document summary Rust profile marker');
  CheckContains(LDocsBlock, '`summary_requested_threads=...`',
    'BENCHMARKS should document summary requested threads marker');
  CheckContains(LDocsBlock, '`summary_effective_threads=...`',
    'BENCHMARKS should document summary effective threads marker');
  CheckContains(LDocsBlock, '`summary_operation=...`',
    'BENCHMARKS should document summary operation marker');
  CheckContains(LDocsBlock, '`summary_workload=...`',
    'BENCHMARKS should document summary workload marker');
end;

procedure TestServerComparisonPreservesRequestedThreadsSourceContract;
var
  LRootDir: string;
  LSource: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LSource := LoadTextFile(ResolveServerComparisonRunnerPath(LRootDir));

  CheckContains(LSource, 'REQUESTED_THREADS=',
    'server comparison stores caller-requested threads');
  CheckContains(LSource, 'EFFECTIVE_THREADS=',
    'server comparison stores effective threads');
  CheckContains(LSource, 'requested_threads="$(printf',
    'server comparison parses requested threads from raw row');
  CheckContains(LSource, 'effective_threads="$(printf',
    'server comparison parses effective threads from raw row');
  CheckContains(LSource, 'requested_thread_values[impl, count[impl]] = $9',
    'server comparison summary stores requested threads column');
  CheckContains(LSource, 'effective_thread_values[impl, count[impl]] = $10',
    'server comparison summary stores effective threads column');
  CheckContains(LSource, 'summary_requested_threads=%s',
    'server comparison summary prints requested threads');
  CheckContains(LSource, 'summary_effective_threads=%s',
    'server comparison summary prints effective threads');
end;

procedure TestServerComparisonRunnerValidatesRawMarkersSourceContract;
var
  LRootDir: string;
  LSource: string;
  LDocs: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LSource := LoadTextFile(ResolveServerComparisonRunnerPath(LRootDir));
  LDocs := LoadTextFile(PathJoin(LRootDir, BenchmarksDocPath));

  CheckContains(LSource, 'operation="$(printf',
    'server comparison parses operation from raw row');
  CheckContains(LSource, 'workload="$(printf',
    'server comparison parses workload from raw row');
  CheckContains(LSource, 'expected operation=http.server.keepalive',
    'server comparison documents expected raw operation');
  CheckContains(LSource, 'operation/workload marker mismatch',
    'server comparison rejects raw operation/workload mismatch');
  CheckContains(LSource, 'operation_values[impl, count[impl]] = $11',
    'server comparison summary stores operation column');
  CheckContains(LSource, 'workload_values[impl, count[impl]] = $12',
    'server comparison summary stores workload column');
  CheckContains(LDocs,
    'Raw row `operation` and `workload` markers must match the runner request',
    'BENCHMARKS should document raw operation/workload guard');
end;

procedure TestServerComparisonRunnerPreservesRequestedThreads;
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
  Check(FileExists(LRunnerPath),
    'server comparison requested threads runner exists');
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_requested_threads_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '3', '--threads', '5',
    '--runs', '2', '--output', LReportPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison requested threads runner exit code: ' + LOutput);
  CheckContains(LOutput, 'requests=3',
    'requested threads comparison requests marker');
  CheckLineContains(LOutput, 'threads=3',
    'requested threads comparison legacy effective threads header');
  CheckRequestedAndEffectiveThreads(LOutput, '5', '3',
    'requested threads comparison raw row');
  CheckContains(LOutput, 'summary_requested_threads=5',
    'requested threads comparison summary requested marker');
  CheckContains(LOutput, 'summary_effective_threads=3',
    'requested threads comparison summary effective marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '3', '3');
  CheckServerBenchmarkOutput(LOutput, 'go', '3', '3');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '3', '3');

  Check(FileExists(LReportPath),
    'server comparison requested threads report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'requests=3',
    'requested threads report requests marker');
  CheckLineContains(LReport, 'threads=3',
    'requested threads report legacy effective threads header');
  CheckRequestedAndEffectiveThreads(LReport, '5', '3',
    'requested threads report raw row');
  CheckContains(LReport, 'summary_requested_threads=5',
    'requested threads report summary requested marker');
  CheckContains(LReport, 'summary_effective_threads=3',
    'requested threads report summary effective marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '3', '3');
  CheckServerBenchmarkOutput(LReport, 'go', '3', '3');
  CheckServerBenchmarkOutput(LReport, 'rust_std', '3', '3');
end;

procedure TestServerComparisonRunnerRejectsInvalidNextpasBackend;
var
  LRootDir: string;
  LRunnerPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison invalid nextpas backend runner exists');

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--nextpas-backend', 'reactor'], LRootDir, LExitCode, LOutput);
  Check(LExitCode <> 0,
    'server comparison runner should reject invalid nextpas backend: ' +
    LOutput);
  CheckContains(LOutput, 'invalid --nextpas-backend',
    'server comparison invalid nextpas backend diagnostic');
  CheckNotContains(LOutput, 'comparison=http.server.keepalive',
    'server comparison invalid nextpas backend should not emit header');
end;

procedure TestServerComparisonRunnerRejectsUnsafeOutputPath;
var
  LRootDir: string;
  LRunnerPath: string;
  LUnsafePath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison unsafe output runner exists');
  LUnsafePath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_unsafe.txt');
  DeleteFile(LUnsafePath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '1', '--threads', '1',
    '--output', LUnsafePath], LRootDir, LExitCode, LOutput);
  Check(LExitCode <> 0,
    'server comparison unsafe output path should fail: ' + LOutput);
  CheckContains(LOutput, 'unsafe output path',
    'server comparison unsafe output diagnostic');
  Check(not FileExists(LUnsafePath),
    'server comparison unsafe output path should not create a report');
end;

procedure TestServerComparisonRunnerEpollSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath), 'server comparison epoll runner exists');
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_epoll_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--nextpas-backend', 'epoll', '--output', LReportPath], LRootDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison epoll runner exit code: ' + LOutput);
  CheckNextpasBackendHeader(LOutput, 'epoll', 'comparison epoll');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'no_url', 'epoll');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1');

  Check(FileExists(LReportPath), 'server comparison epoll report exists');
  LReport := LoadTextFile(LReportPath);
  CheckNextpasBackendHeader(LReport, 'epoll', 'report epoll');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'no_url', 'epoll');
end;

procedure TestServerComparisonRunnerEpollUrlPathSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison epoll url_path runner exists');
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_epoll_url_path_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'url_path', '--nextpas-backend', 'epoll',
    '--output', LReportPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison epoll url_path runner exit code: ' + LOutput);
  CheckNextpasBackendHeader(LOutput, 'epoll', 'comparison epoll url_path');
  CheckContains(LOutput, 'workload=url_path',
    'comparison epoll url_path workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'url_path', 'epoll');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'url_path');

  Check(FileExists(LReportPath), 'server comparison epoll url_path report exists');
  LReport := LoadTextFile(LReportPath);
  CheckNextpasBackendHeader(LReport, 'epoll', 'report epoll url_path');
  CheckContains(LReport, 'workload=url_path',
    'report epoll url_path workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'url_path', 'epoll');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LReport, 'rust_std', '8', '1', 'url_path');
end;

procedure TestServerComparisonRunnerEpollResponse1KSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison epoll response_1k runner exists');
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_epoll_response_1k_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'response_1k', '--nextpas-backend', 'epoll',
    '--output', LReportPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison epoll response_1k runner exit code: ' + LOutput);
  CheckNextpasBackendHeader(LOutput, 'epoll', 'comparison epoll response_1k');
  CheckContains(LOutput, 'workload=response_1k',
    'comparison epoll response_1k workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'response_1k',
    'epoll');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'response_1k');
  CheckContains(LOutput, 'client_read_mode=header_plus_content_length',
    'comparison epoll response_1k direct-read marker');
  CheckContains(LOutput, 'client_read_mode=http_client_body_drain',
    'comparison epoll response_1k Go read marker');
  CheckContains(LOutput, 'response_body_bytes=1024',
    'comparison epoll response_1k body-bytes marker');

  Check(FileExists(LReportPath),
    'server comparison epoll response_1k report exists');
  LReport := LoadTextFile(LReportPath);
  CheckNextpasBackendHeader(LReport, 'epoll', 'report epoll response_1k');
  CheckContains(LReport, 'workload=response_1k',
    'report epoll response_1k workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'response_1k',
    'epoll');
  CheckServerBenchmarkOutput(LReport, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LReport, 'rust_std', '8', '1', 'response_1k');
  CheckContains(LReport, 'client_read_mode=header_plus_content_length',
    'report epoll response_1k direct-read marker');
  CheckContains(LReport, 'client_read_mode=http_client_body_drain',
    'report epoll response_1k Go read marker');
  CheckContains(LReport, 'response_body_bytes=1024',
    'report epoll response_1k body-bytes marker');
end;

procedure TestServerComparisonRunnerIncludeHyperEpollResponse1KSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LReportPath: string;
  LReport: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerComparisonRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison include-hyper epoll response_1k runner exists');
  LReportPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_include_hyper_epoll_response_1k_smoke.txt');
  DeleteFile(LReportPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'response_1k', '--include-hyper', '--nextpas-backend',
    'epoll', '--output', LReportPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison include-hyper epoll response_1k runner exit code: ' +
    LOutput);
  CheckContains(LOutput, 'include_hyper=1',
    'include-hyper epoll response_1k runner marker');
  CheckNextpasBackendHeader(LOutput, 'epoll',
    'comparison include-hyper epoll response_1k');
  CheckContains(LOutput, 'workload=response_1k',
    'include-hyper epoll response_1k workload marker');
  CheckServerBenchmarkOutput(LOutput, 'nextpas', '8', '1', 'response_1k',
    'epoll');
  CheckServerBenchmarkOutput(LOutput, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LOutput, 'rust_std', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LOutput, 'rust_hyper', '8', '1', 'response_1k');
  CheckResponseReadContract(LOutput, 'rust_hyper', '1024',
    'include-hyper epoll response_1k hyper row');
  CheckContains(LOutput, 'rust_profile=hyper_tokio',
    'include-hyper epoll response_1k hyper profile marker');
  CheckContains(LOutput, 'summary_impl=rust_hyper',
    'include-hyper epoll response_1k rust_hyper summary marker');

  Check(FileExists(LReportPath),
    'server comparison include-hyper epoll response_1k report exists');
  LReport := LoadTextFile(LReportPath);
  CheckContains(LReport, 'include_hyper=1',
    'include-hyper epoll response_1k report marker');
  CheckNextpasBackendHeader(LReport, 'epoll',
    'report include-hyper epoll response_1k');
  CheckContains(LReport, 'workload=response_1k',
    'include-hyper epoll response_1k report workload marker');
  CheckServerBenchmarkOutput(LReport, 'nextpas', '8', '1', 'response_1k',
    'epoll');
  CheckServerBenchmarkOutput(LReport, 'rust_hyper', '8', '1', 'response_1k');
  CheckResponseReadContract(LReport, 'rust_hyper', '1024',
    'include-hyper epoll response_1k report hyper row');
  CheckContains(LReport, 'rust_profile=hyper_tokio',
    'include-hyper epoll response_1k report hyper profile marker');
  CheckContains(LReport, 'summary_impl=rust_hyper',
    'include-hyper epoll response_1k report rust_hyper summary marker');
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
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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
  CheckContains(LSnapshot, 'nextpas_backend=threaded',
    'snapshot nextpas backend marker');
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
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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

procedure TestServerComparisonSnapshotPreservesRequestedThreads;
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
    'server comparison snapshot thread clamp runner exists');
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_snapshot_thread_clamp_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '3', '--threads', '5',
    '--output', LSnapshotPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot thread clamp exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath),
    'server comparison snapshot thread clamp exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'requests=3',
    'snapshot thread clamp requests marker');
  CheckContains(LSnapshot, 'threads=5',
    'snapshot thread clamp requested threads marker');
  CheckContains(LSnapshot, 'requested_threads=5',
    'snapshot thread clamp explicit requested threads marker');
  CheckContains(LSnapshot, 'effective_threads=3',
    'snapshot thread clamp effective threads marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 3 --threads 5 --runs 1',
    'snapshot thread clamp command marker');
  CheckServerBenchmarkOutput(LSnapshot, 'nextpas', '3', '3');
  CheckRequestedAndEffectiveThreads(LSnapshot, '5', '3',
    'snapshot thread clamp raw row');
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
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
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

procedure TestServerComparisonSnapshotIncludeHyperUrlPathSmoke;
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
    'server comparison snapshot include-hyper url_path runner exists');
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_snapshot_include_hyper_url_path_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'url_path', '--include-hyper', '--output', LSnapshotPath],
    LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot include-hyper url_path exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath),
    'server comparison snapshot include-hyper url_path exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'workload=url_path',
    'snapshot include-hyper url_path workload marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --workload url_path --runs 1 --include-hyper',
    'snapshot include-hyper url_path command marker');
  CheckContains(LSnapshot, 'cargo_version=',
    'snapshot include-hyper url_path cargo version marker');
  CheckContains(LSnapshot, 'hyper_cargo_lock_sha256=',
    'snapshot include-hyper url_path Cargo.lock marker');
  CheckServerBenchmarkOutput(LSnapshot, 'rust_hyper', '8', '1', 'url_path');
  CheckContains(LSnapshot, 'rust_profile=hyper_tokio',
    'snapshot include-hyper url_path hyper profile marker');
  CheckContains(LSnapshot, 'summary_impl=rust_hyper',
    'snapshot include-hyper url_path summary marker');
end;

procedure TestServerComparisonSnapshotIncludeHyperResponse1KSmoke;
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
    'server comparison snapshot include-hyper response_1k runner exists');
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_snapshot_include_hyper_response_1k_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'response_1k', '--include-hyper', '--output', LSnapshotPath],
    LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot include-hyper response_1k exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath),
    'server comparison snapshot include-hyper response_1k exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'workload=response_1k',
    'snapshot include-hyper response_1k workload marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --workload response_1k --runs 1 --include-hyper',
    'snapshot include-hyper response_1k command marker');
  CheckContains(LSnapshot, 'cargo_version=',
    'snapshot include-hyper response_1k cargo version marker');
  CheckContains(LSnapshot, 'hyper_cargo_lock_sha256=',
    'snapshot include-hyper response_1k Cargo.lock marker');
  CheckServerBenchmarkOutput(LSnapshot, 'rust_hyper', '8', '1', 'response_1k');
  CheckContains(LSnapshot, 'rust_profile=hyper_tokio',
    'snapshot include-hyper response_1k hyper profile marker');
  CheckContains(LSnapshot, 'response_body_bytes=1024',
    'snapshot include-hyper response_1k body-bytes marker');
  CheckContains(LSnapshot, 'summary_impl=rust_hyper',
    'snapshot include-hyper response_1k summary marker');
end;

procedure TestServerComparisonSnapshotEpollUrlPathSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LSnapshotPath: string;
  LSnapshot: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison snapshot epoll url_path runner exists');
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_snapshot_epoll_url_path_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'url_path', '--nextpas-backend', 'epoll',
    '--output', LSnapshotPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot epoll url_path exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath),
    'server comparison snapshot epoll url_path exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'nextpas_backend=epoll',
    'snapshot epoll url_path backend marker');
  CheckContains(LSnapshot, 'workload=url_path',
    'snapshot epoll url_path workload marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --workload url_path --runs 1 --nextpas-backend epoll',
    'snapshot epoll url_path command marker');
  CheckServerBenchmarkOutput(LSnapshot, 'nextpas', '8', '1', 'url_path', 'epoll');
  CheckServerBenchmarkOutput(LSnapshot, 'go', '8', '1', 'url_path');
  CheckServerBenchmarkOutput(LSnapshot, 'rust_std', '8', '1', 'url_path');
end;

procedure TestServerComparisonSnapshotEpollResponse1KSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LSnapshotPath: string;
  LSnapshot: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison snapshot epoll response_1k runner exists');
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_snapshot_epoll_response_1k_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'response_1k', '--nextpas-backend', 'epoll',
    '--output', LSnapshotPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot epoll response_1k exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath),
    'server comparison snapshot epoll response_1k exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'nextpas_backend=epoll',
    'snapshot epoll response_1k backend marker');
  CheckContains(LSnapshot, 'workload=response_1k',
    'snapshot epoll response_1k workload marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --workload response_1k --runs 1 --nextpas-backend epoll',
    'snapshot epoll response_1k command marker');
  CheckServerBenchmarkOutput(LSnapshot, 'nextpas', '8', '1', 'response_1k',
    'epoll');
  CheckServerBenchmarkOutput(LSnapshot, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LSnapshot, 'rust_std', '8', '1', 'response_1k');
  CheckContains(LSnapshot, 'client_read_mode=header_plus_content_length',
    'snapshot epoll response_1k direct-read marker');
  CheckContains(LSnapshot, 'client_read_mode=http_client_body_drain',
    'snapshot epoll response_1k Go read marker');
  CheckContains(LSnapshot, 'response_body_bytes=1024',
    'snapshot epoll response_1k body-bytes marker');
end;

procedure TestServerComparisonSnapshotIncludeHyperEpollResponse1KSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LSnapshotPath: string;
  LSnapshot: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison snapshot include-hyper epoll response_1k runner exists');
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_snapshot_include_hyper_epoll_response_1k_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--workload', 'response_1k', '--include-hyper', '--nextpas-backend',
    'epoll', '--output', LSnapshotPath], LRootDir, LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot include-hyper epoll response_1k exit code: ' +
    LOutput);

  Check(FileExists(LSnapshotPath),
    'server comparison snapshot include-hyper epoll response_1k exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'include_hyper=1',
    'snapshot include-hyper epoll response_1k marker');
  CheckContains(LSnapshot, 'nextpas_backend=epoll',
    'snapshot include-hyper epoll response_1k backend marker');
  CheckContains(LSnapshot, 'workload=response_1k',
    'snapshot include-hyper epoll response_1k workload marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --workload response_1k --runs 1 --include-hyper --nextpas-backend epoll',
    'snapshot include-hyper epoll response_1k command marker');
  CheckContains(LSnapshot, 'cargo_version=',
    'snapshot include-hyper epoll response_1k cargo version marker');
  CheckContains(LSnapshot, 'hyper_cargo_lock_sha256=',
    'snapshot include-hyper epoll response_1k Cargo.lock marker');
  CheckServerBenchmarkOutput(LSnapshot, 'nextpas', '8', '1', 'response_1k',
    'epoll');
  CheckServerBenchmarkOutput(LSnapshot, 'go', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LSnapshot, 'rust_std', '8', '1', 'response_1k');
  CheckServerBenchmarkOutput(LSnapshot, 'rust_hyper', '8', '1', 'response_1k');
  CheckContains(LSnapshot, 'rust_profile=hyper_tokio',
    'snapshot include-hyper epoll response_1k hyper profile marker');
  CheckContains(LSnapshot, 'client_read_mode=header_plus_content_length',
    'snapshot include-hyper epoll response_1k direct-read marker');
  CheckContains(LSnapshot, 'response_body_bytes=1024',
    'snapshot include-hyper epoll response_1k body-bytes marker');
  CheckContains(LSnapshot, 'summary_impl=rust_hyper',
    'snapshot include-hyper epoll response_1k summary marker');
end;

procedure TestServerComparisonSnapshotRejectsInvalidNextpasBackend;
var
  LRootDir: string;
  LRunnerPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison snapshot invalid nextpas backend runner exists');

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--nextpas-backend', 'reactor'], LRootDir, LExitCode, LOutput);
  Check(LExitCode <> 0,
    'server comparison snapshot should reject invalid nextpas backend: ' +
    LOutput);
  CheckContains(LOutput, 'invalid --nextpas-backend',
    'server comparison snapshot invalid nextpas backend diagnostic');
end;

procedure TestServerComparisonSnapshotRejectsUnsafeOutputPath;
var
  LRootDir: string;
  LRunnerPath: string;
  LUnsafePath: string;
  LRawPath: string;
  LExitCode: Integer;
  LOutput: string;
begin
  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison snapshot unsafe output runner exists');
  LUnsafePath := PathJoin(ResolveBenchmarkTestBuildDir(LRootDir),
    'server_comparison_snapshot_unsafe.md');
  LRawPath := LUnsafePath + '.raw';
  DeleteFile(LUnsafePath);
  DeleteFile(LRawPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '1', '--threads', '1',
    '--output', LUnsafePath], LRootDir, LExitCode, LOutput);
  Check(LExitCode <> 0,
    'server comparison snapshot unsafe output path should fail: ' + LOutput);
  CheckContains(LOutput, 'unsafe output path',
    'server comparison snapshot unsafe output diagnostic');
  Check(not FileExists(LUnsafePath),
    'server comparison snapshot unsafe output path should not create snapshot');
  Check(not FileExists(LRawPath),
    'server comparison snapshot unsafe output path should not create raw temp file');
end;

procedure TestServerComparisonSnapshotEpollSmoke;
var
  LRootDir: string;
  LRunnerPath: string;
  LSnapshotPath: string;
  LSnapshot: string;
  LExitCode: Integer;
  LOutput: string;
begin
  {$IFNDEF LINUX}
  Exit;
  {$ENDIF}

  LRootDir := ResolveCoreRoot(ServerComparisonRelativeDir);
  LRunnerPath := ResolveServerSnapshotRunnerPath(LRootDir);
  Check(FileExists(LRunnerPath),
    'server comparison snapshot epoll runner exists');
  LSnapshotPath := PathJoin(ResolveServerComparisonOutputDir(LRootDir),
    'server_comparison_snapshot_epoll_smoke.md');
  DeleteFile(LSnapshotPath);

  RunProcessAndCapture(LRunnerPath, ['--requests', '8', '--threads', '1',
    '--nextpas-backend', 'epoll', '--output', LSnapshotPath], LRootDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'server comparison snapshot epoll exit code: ' + LOutput);

  Check(FileExists(LSnapshotPath), 'server comparison snapshot epoll exists');
  LSnapshot := LoadTextFile(LSnapshotPath);
  CheckContains(LSnapshot, 'nextpas_backend=epoll',
    'snapshot epoll backend marker');
  CheckContains(LSnapshot,
    'run_server_comparison.sh --requests 8 --threads 1 --runs 1 --nextpas-backend epoll',
    'snapshot epoll command marker');
  CheckServerBenchmarkOutput(LSnapshot, 'nextpas', '8', '1', 'no_url',
    'epoll');
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

  RunProcessAndCapture(ResolveMakeExecutable,
    ['run-c', 'LLHTTP_ROOT=', LlhttpRootEnvName + '='], LBenchDir, LExitCode,
    LOutput);
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
  CheckContains(LOutput, 'operation=http.h1parser',
    'H1 parser benchmark operation marker');
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
  CheckContains(LOutput, 'adapter cost: fast headers count all',
    'H1 parser benchmark fast lazy header Count row');
  CheckContains(LOutput, 'adapter cost: fast headers has accept',
    'H1 parser benchmark fast lazy header Has row');
  CheckContains(LOutput, 'adapter cost: fast headers get all accept',
    'H1 parser benchmark fast lazy header GetAll row');
  CheckContains(LOutput, 'adapter cost: fast headers foreach all',
    'H1 parser benchmark fast lazy header ForEach row');
end;

procedure CheckH1ParserBenchmarkInvalidMaxItersRejected(
  const AExecutable, AWorkingDir, AValue, ALabel: string);
var
  LExitCode: Integer;
  LOutput: string;
begin
  RunProcessAndCaptureWithEnv(AExecutable, [], AWorkingDir,
    [BenchMaxItersEnvName + '=' + AValue], LExitCode, LOutput);
  Check(LExitCode <> 0, ALabel + ' should reject invalid max iters: ' +
    LOutput);
  CheckContains(LOutput, 'invalid ' + BenchMaxItersEnvName,
    ALabel + ' invalid max-iters diagnostic');
  CheckContains(LOutput, AValue,
    ALabel + ' invalid max-iters diagnostic includes value');
  CheckNotContains(LOutput, ' iters',
    ALabel + ' should not emit benchmark rows');
end;

procedure TestH1ParserBenchmarkRejectsInvalidMaxIters;
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
    'H1 parser benchmark invalid max-iters build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'H1 parser benchmark invalid max-iters binary exists');

  CheckH1ParserBenchmarkInvalidMaxItersRejected(LBinaryPath, LBenchDir, 'abc',
    'H1 parser benchmark non-integer max iters');
  CheckH1ParserBenchmarkInvalidMaxItersRejected(LBinaryPath, LBenchDir, '99',
    'H1 parser benchmark too-small max iters');
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
  CheckContains(LOutput,
    'adapter no-url: legacy double parse explicit keep-alive',
    'H1 parser benchmark adapter no-url legacy double-parse row');
  CheckNotContains(LOutput, 'adapter no-url: fast reject + llhttp',
    'H1 parser benchmark adapter no-url should not use stale reject label');
  CheckContains(LOutput, 'adapter no-url: llhttp direct only',
    'H1 parser benchmark adapter no-url direct llhttp row');
  CheckContains(LOutput, 'adapter no-url: fast parse only',
    'H1 parser benchmark adapter no-url fast parse row');
  CheckContains(LOutput, 'adapter no-url: metadata 3 headers',
    'H1 parser benchmark adapter no-url metadata row');
end;

procedure TestH1ParserBenchmarkRejectsNoMatchFilter;
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
    'H1 parser no-match filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), 'H1 parser no-match filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=not_a_h1parser_row'],
    LExitCode, LOutput);
  Check(LExitCode <> 0,
    'H1 parser no-match filter should fail: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=not_a_h1parser_row',
    'H1 parser no-match filter marker');
  CheckContains(LOutput, 'No matching benchmark rows.',
    'H1 parser no-match diagnostic');
  CheckNotContains(LOutput, ' iters',
    'H1 parser no-match must not emit benchmark row');
end;

procedure RunH1ParserFilterSmoke(const AFilter, AExpectedRow,
  ALabel: string; const AUnexpectedRows: array of string);
var
  LRootDir: string;
  LBenchDir: string;
  LBinaryPath: string;
  LExitCode: Integer;
  LOutput: string;
  I: Integer;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);

  RunProcessAndCapture(ResolveMakeExecutable, ['build'], LBenchDir,
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    ALabel + ' filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath), ALabel + ' filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=' + AFilter],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    ALabel + ' filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=' + AFilter,
    ALabel + ' filter marker');
  CheckContains(LOutput, AExpectedRow, ALabel + ' filtered row');
  for I := Low(AUnexpectedRows) to High(AUnexpectedRows) do
    CheckNotContains(LOutput, AUnexpectedRows[I],
      ALabel + ' filter skips unexpected row');
end;

procedure TestH1ParserBenchmarkHeaderSpanAddFilterEnv;
begin
  RunH1ParserFilterSmoke('header span add 10 headers',
    'adapter cost: header span add 10 headers',
    'H1 parser header-span-add',
    ['adapter cost: span append 10 headers',
     'adapter cost: header add 10 headers',
     'adapter cost: body copy 1KB',
     'adapter cost: request metadata cached expect+cl']);
end;

procedure TestH1ParserBenchmarkMetadataCacheFilterEnv;
begin
  RunH1ParserFilterSmoke('request metadata cached',
    'adapter cost: request metadata cached expect+cl',
    'H1 parser metadata cache',
    ['adapter cost: request metadata legacy expect+cl',
     'adapter cost: fast headers get host only']);
end;

procedure TestH1ParserBenchmarkRequestPathFilterEnv;
begin
  RunH1ParserFilterSmoke('request direct Path access',
    'adapter cost: request direct Path access',
    'H1 parser request-path',
    ['adapter cost: request lazy Url.Path access',
     'adapter cost: request direct RawQuery access',
     'adapter cost: request metadata cached expect+cl']);
end;

procedure TestH1ParserBenchmarkRequestRawQueryFilterEnv;
begin
  RunH1ParserFilterSmoke('request direct RawQuery access',
    'adapter cost: request direct RawQuery access',
    'H1 parser request-rawquery',
    ['adapter cost: request lazy Url.Path access',
     'adapter cost: request direct Path access',
     'adapter cost: request metadata cached expect+cl']);
end;

procedure TestH1ParserBenchmarkRequestPathAndRawQueryFilterEnv;
begin
  RunH1ParserFilterSmoke('request direct Path+RawQuery access',
    'adapter cost: request direct Path+RawQuery access',
    'H1 parser request-path+rawquery',
    ['adapter cost: request direct Path access',
     'adapter cost: request direct RawQuery access',
     'adapter cost: request metadata cached expect+cl']);
end;

procedure TestH1ParserBenchmarkUrlParseRequestTargetFilterEnv;
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
    'H1 parser url-parse request-target filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'H1 parser url-parse request-target filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=url parse request-target origin-form'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser url-parse request-target filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=url parse request-target origin-form',
    'H1 parser url-parse request-target filter marker');
  CheckContains(LOutput, 'adapter cost: url parse request-target origin-form',
    'H1 parser url-parse request-target filtered row');
  CheckNotContains(LOutput, 'adapter cost: url parse generic origin-form',
    'H1 parser url-parse request-target filter skips generic row');
  CheckNotContains(LOutput, 'adapter cost: request direct Path access',
    'H1 parser url-parse request-target filter skips request projection row');
  CheckNotContains(LOutput, 'adapter cost: request metadata cached expect+cl',
    'H1 parser url-parse request-target filter skips unrelated metadata row');
end;

procedure TestH1ParserBenchmarkUrlParseGenericFilterEnv;
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
    'H1 parser url-parse generic filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'H1 parser url-parse generic filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=url parse generic origin-form'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser url-parse generic filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=url parse generic origin-form',
    'H1 parser url-parse generic filter marker');
  CheckContains(LOutput, 'adapter cost: url parse generic origin-form',
    'H1 parser url-parse generic filtered row');
  CheckNotContains(LOutput, 'adapter cost: url parse request-target origin-form',
    'H1 parser url-parse generic filter skips request-target row');
  CheckNotContains(LOutput, 'adapter cost: request direct Path access',
    'H1 parser url-parse generic filter skips request projection row');
  CheckNotContains(LOutput, 'adapter cost: request metadata cached expect+cl',
    'H1 parser url-parse generic filter skips unrelated metadata row');
end;

procedure TestH1ParserBenchmarkFastHeadersFilterEnv;
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
    'H1 parser fast-headers filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'H1 parser fast-headers filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=fast headers get host only'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser fast-headers filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=fast headers get host only',
    'H1 parser fast-headers filter marker');
  CheckContains(LOutput, 'adapter cost: fast headers get host only',
    'H1 parser fast-headers filtered row');
  CheckNotContains(LOutput, 'adapter cost: fast headers count all',
    'H1 parser fast-headers filter skips count row');
  CheckNotContains(LOutput, 'adapter cost: fast headers foreach all',
    'H1 parser fast-headers filter skips foreach row');
  CheckNotContains(LOutput, 'adapter cost: request metadata cached expect+cl',
    'H1 parser fast-headers filter skips unrelated metadata row');
end;

procedure TestH1ParserBenchmarkFastHeadersGetAllFilterEnv;
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
    'H1 parser fast-headers get-all filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'H1 parser fast-headers get-all filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=fast headers get all accept'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser fast-headers get-all filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=fast headers get all accept',
    'H1 parser fast-headers get-all filter marker');
  CheckContains(LOutput, 'adapter cost: fast headers get all accept',
    'H1 parser fast-headers get-all filtered row');
  CheckNotContains(LOutput, 'adapter cost: fast headers get host only',
    'H1 parser fast-headers get-all filter skips single-value row');
  CheckNotContains(LOutput, 'adapter cost: fast headers foreach all',
    'H1 parser fast-headers get-all filter skips foreach row');
  CheckNotContains(LOutput, 'adapter cost: request metadata cached expect+cl',
    'H1 parser fast-headers get-all filter skips unrelated metadata row');
end;

procedure TestH1ParserBenchmarkFastHeadersHasFilterEnv;
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
    'H1 parser fast-headers has filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'H1 parser fast-headers has filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=fast headers has accept'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser fast-headers has filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=fast headers has accept',
    'H1 parser fast-headers has filter marker');
  CheckContains(LOutput, 'adapter cost: fast headers has accept',
    'H1 parser fast-headers has filtered row');
  CheckNotContains(LOutput, 'adapter cost: fast headers get host only',
    'H1 parser fast-headers has filter skips single-value row');
  CheckNotContains(LOutput, 'adapter cost: fast headers get all accept',
    'H1 parser fast-headers has filter skips multi-value row');
  CheckNotContains(LOutput, 'adapter cost: request metadata cached expect+cl',
    'H1 parser fast-headers has filter skips unrelated metadata row');
end;

procedure TestH1ParserBenchmarkFastHeadersCountFilterEnv;
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
    'H1 parser fast-headers count filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'H1 parser fast-headers count filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=fast headers count all'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser fast-headers count filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=fast headers count all',
    'H1 parser fast-headers count filter marker');
  CheckContains(LOutput, 'adapter cost: fast headers count all',
    'H1 parser fast-headers count filtered row');
  CheckNotContains(LOutput, 'adapter cost: fast headers get host only',
    'H1 parser fast-headers count filter skips single-value row');
  CheckNotContains(LOutput, 'adapter cost: fast headers foreach all',
    'H1 parser fast-headers count filter skips foreach row');
  CheckNotContains(LOutput, 'adapter cost: request metadata cached expect+cl',
    'H1 parser fast-headers count filter skips unrelated metadata row');
end;

procedure TestH1ParserBenchmarkFastHeadersForEachFilterEnv;
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
    'H1 parser fast-headers foreach filter build exit code: ' + LOutput);

  LBinaryPath := ResolveH1ParserBenchBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'H1 parser fast-headers foreach filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LBenchDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=fast headers foreach all'],
    LExitCode, LOutput);
  CheckEqual(Int64(0), Int64(LExitCode),
    'H1 parser fast-headers foreach filter smoke exit code: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=fast headers foreach all',
    'H1 parser fast-headers foreach filter marker');
  CheckContains(LOutput, 'adapter cost: fast headers foreach all',
    'H1 parser fast-headers foreach filtered row');
  CheckNotContains(LOutput, 'adapter cost: fast headers get host only',
    'H1 parser fast-headers foreach filter skips single-value row');
  CheckNotContains(LOutput, 'adapter cost: fast headers get all accept',
    'H1 parser fast-headers foreach filter skips multi-value row');
  CheckNotContains(LOutput, 'adapter cost: request metadata cached expect+cl',
    'H1 parser fast-headers foreach filter skips unrelated metadata row');
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
  CheckContains(LOutput, 'operation=http.h1parser.c_llhttp',
    'C llhttp comparator operation marker');
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

procedure TestCllhttpComparatorRejectsNoMatchFilterWhenConfigured;
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
    'C llhttp comparator no-match build exit code: ' + LOutput);

  LBinaryPath := ResolveCllhttpComparatorBinaryPath(LRootDir);
  Check(FileExists(LBinaryPath),
    'C llhttp comparator no-match filter binary exists');

  RunProcessAndCaptureWithEnv(LBinaryPath, [], LCompareDir,
    [BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue,
     BenchFilterEnvName + '=not_a_c_llhttp_row'],
    LExitCode, LOutput);
  Check(LExitCode <> 0,
    'C llhttp comparator no-match filter should fail: ' + LOutput);
  CheckContains(LOutput, 'bench_filter=not_a_c_llhttp_row',
    'C llhttp comparator no-match filter marker');
  CheckContains(LOutput, 'No matching C llhttp benchmark rows.',
    'C llhttp comparator no-match diagnostic');
  CheckNotContains(LOutput, ' iters',
    'C llhttp comparator no-match must not emit benchmark row');
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

procedure TestH1ParserFlagMatrixRejectsUnsafeOutputDir;
var
  LRootDir: string;
  LBenchDir: string;
  LRunnerPath: string;
  LUnsafeOutputDir: string;
  LLhttpRoot: string;
  LExitCode: Integer;
  LOutput: string;
  LEnvVars: array of string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LBenchDir := PathJoin(LRootDir, H1ParserBenchRelativeDir);
  LRunnerPath := ResolveH1FlagMatrixRunnerPath(LRootDir);
  LUnsafeOutputDir := PathJoin(LRootDir,
    'build/projects/nextpas.core.http/flag_matrix_unsafe_smoke');
  LLhttpRoot := Trim(GetEnvironmentVariable(LlhttpRootEnvName));

  if LLhttpRoot <> '' then
  begin
    SetLength(LEnvVars, 6);
    LEnvVars[0] := BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue;
    LEnvVars[1] := BenchFilterEnvName + '=raw llhttp: 10 headers';
    LEnvVars[2] := 'LLHTTP_ROOT=' + LLhttpRoot;
    LEnvVars[3] := 'NEXTPAS_FLAG_MATRIX_OUTPUT_DIR=' + LUnsafeOutputDir;
    LEnvVars[4] := 'PATH=' + GetEnvironmentVariable('PATH');
    LEnvVars[5] := 'HOME=' + GetEnvironmentVariable('HOME');
  end
  else
  begin
    SetLength(LEnvVars, 5);
    LEnvVars[0] := BenchMaxItersEnvName + '=' + BenchMaxItersSmokeValue;
    LEnvVars[1] := BenchFilterEnvName + '=raw llhttp: 10 headers';
    LEnvVars[2] := 'NEXTPAS_FLAG_MATRIX_OUTPUT_DIR=' + LUnsafeOutputDir;
    LEnvVars[3] := 'PATH=' + GetEnvironmentVariable('PATH');
    LEnvVars[4] := 'HOME=' + GetEnvironmentVariable('HOME');
  end;

  RunProcessAndCaptureWithEnv(LRunnerPath, ['--smoke', '--no-perf'],
    LBenchDir, LEnvVars, LExitCode, LOutput);
  Check(LExitCode <> 0,
    'H1 parser flag matrix unsafe output dir should fail: ' + LOutput);
  CheckContains(LOutput, 'unsafe output dir',
    'H1 parser flag matrix unsafe output dir diagnostic');
end;

procedure TestH1ParserFlagMatrixRequiresParsedRowsSourceContract;
var
  LRootDir: string;
  LRunnerPath: string;
  LScript: string;
begin
  LRootDir := ResolveCoreRoot(H1ParserBenchRelativeDir);
  LRunnerPath := ResolveH1FlagMatrixRunnerPath(LRootDir);
  LScript := LoadTextFile(LRunnerPath);

  CheckContains(LScript, 'local parsed_rows=0',
    'H1 parser flag matrix should count parsed rows per run');
  CheckContains(LScript, 'parsed_rows=$((parsed_rows + 1))',
    'H1 parser flag matrix should increment parsed-row count');
  CheckContains(LScript, 'if [ "$parsed_rows" -eq 0 ]; then',
    'H1 parser flag matrix should reject header-only artifacts');
  CheckContains(LScript, 'no benchmark rows parsed for $variant run $run_index',
    'H1 parser flag matrix should name variant/run on parse failure');
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
  T.Run('bench_server rejects invalid backend',
    @TestBenchServerRejectsInvalidBackend);
  T.Run('bench_server epoll small smoke',
    @TestBenchServerEpollSmallSmoke);
  T.Run('server comparators report requested/effective threads',
    @TestServerComparatorsReportRequestedAndEffectiveThreads);
  T.Run('server comparators report response read contract',
    @TestServerComparatorsReportResponseReadContract);
  T.Run('bench_router handler dispatch smoke',
    @TestBenchRouterHandlerDispatchSmoke);
  T.Run('bench_router direct call smoke',
    @TestBenchRouterDirectCallSmoke);
  T.Run('bench_headers lookup smoke',
    @TestBenchHeadersLookupSmoke);
  T.Run('bench_headers rejects no-match filter',
    @TestBenchHeadersRejectsNoMatchFilter);
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
  T.Run('H1 writer outbound drain source contract',
    @TestH1WriterOutboundDrainSourceContract);
  T.Run('bench_fullchain direct dispatch source contract',
    @TestBenchFullchainDirectDispatchSourceContract);
  T.Run('bench_fullchain middleware dispatch source contract',
    @TestBenchFullchainMiddlewareDispatchSourceContract);
  T.Run('bench_fullchain server thread lifecycle source contract',
    @TestBenchFullchainServerThreadLifecycleSourceContract);
  T.Run('bench_fullchain strict response validation source contract',
    @TestBenchFullchainStrictResponseValidationSourceContract);
  T.Run('benchmark docs adapter_no_url fast-path source contract',
    @TestBenchmarkDocsAdapterNoUrlFastPathSourceContract);
  T.Run('benchmark docs fullchain stable markers source contract',
    @TestBenchmarkDocsFullchainStableMarkersSourceContract);
  T.Run('README fullchain benchmark truth source contract',
    @TestReadmeFullchainBenchmarkTruthSourceContract);
  T.Run('API coverage benchmark evidence summary source contract',
    @TestApiCoverageBenchmarkEvidenceSummarySourceContract);
  T.Run('H1 parser llhttp root alias source contract',
    @TestH1ParserLlhttpRootAliasSourceContract);
  T.Run('benchmark docs H1 parser runner truth source contract',
    @TestBenchmarkDocsH1ParserRunnerTruthSourceContract);
  T.Run('bench_h1outbound drain smoke',
    @TestBenchH1OutboundDrainSmoke);
  T.Run('bench_fullchain plaintext smoke',
    @TestBenchFullchainPlaintextSmoke);
  T.Run('bench_fullchain direct plaintext smoke',
    @TestBenchFullchainDirectPlaintextSmoke);
  T.Run('bench_fullchain direct 1k smoke',
    @TestBenchFullchainDirect1KSmoke);
  T.Run('bench_fullchain middleware noop smoke',
    @TestBenchFullchainMiddlewareNoopSmoke);
  T.Run('bench_fullchain echo 1k smoke',
    @TestBenchFullchainEcho1KSmoke);
  T.Run('bench_fullchain json smoke',
    @TestBenchFullchainJsonSmoke);
  T.Run('bench_fullchain param route smoke',
    @TestBenchFullchainParamRouteSmoke);
  T.Run('bench_fullchain sink 16k smoke',
    @TestBenchFullchainSink16KSmoke);
  T.Run('bench_fullchain rejects invalid backend',
    @TestBenchFullchainRejectsInvalidBackend);
  T.Run('bench_fullchain rejects invalid max iters',
    @TestBenchFullchainRejectsInvalidMaxIters);
  T.Run('bench_fullchain epoll direct plaintext smoke',
    @TestBenchFullchainEpollDirectPlaintextSmoke);
  T.Run('bench_fullchain epoll direct 1k smoke',
    @TestBenchFullchainEpollDirect1KSmoke);
  T.Run('bench_fullchain epoll echo 1k smoke',
    @TestBenchFullchainEpollEcho1KSmoke);
  T.Run('bench_fullchain epoll sink 16k smoke',
    @TestBenchFullchainEpollSink16KSmoke);
  T.Run('bench_fullchain rejects no-match filter',
    @TestBenchFullchainRejectsNoMatchFilter);
  T.Run('HTTP top-level Pascal benchmark projects have Makefiles',
    @TestHttpTopLevelPascalBenchmarkProjectsHaveMakefiles);
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
  T.Run('hyper/tokio server comparator url_path small smoke',
    @TestHyperTokioServerComparatorUrlPathSmallSmoke);
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
  T.Run('server comparison runner include hyper url_path smoke',
    @TestServerComparisonRunnerIncludeHyperUrlPathSmoke);
  T.Run('server comparison runner include hyper response_1k smoke',
    @TestServerComparisonRunnerIncludeHyperResponse1KSmoke);
  T.Run('server comparison runner concurrency lock source contract',
    @TestServerComparisonRunnerConcurrencyLockSourceContract);
  T.Run('server comparison summary keeps read-mode metadata source contract',
    @TestServerComparisonSummaryKeepsReadModeMetadataSourceContract);
  T.Run('server comparison preserves requested threads source contract',
    @TestServerComparisonPreservesRequestedThreadsSourceContract);
  T.Run('server comparison runner validates raw markers source contract',
    @TestServerComparisonRunnerValidatesRawMarkersSourceContract);
  T.Run('server comparison runner preserves requested threads',
    @TestServerComparisonRunnerPreservesRequestedThreads);
  T.Run('server comparison runner rejects invalid nextpas backend',
    @TestServerComparisonRunnerRejectsInvalidNextpasBackend);
  T.Run('server comparison runner rejects unsafe output path',
    @TestServerComparisonRunnerRejectsUnsafeOutputPath);
  T.Run('server comparison runner epoll smoke',
    @TestServerComparisonRunnerEpollSmoke);
  T.Run('server comparison runner epoll url_path smoke',
    @TestServerComparisonRunnerEpollUrlPathSmoke);
  T.Run('server comparison runner epoll response_1k smoke',
    @TestServerComparisonRunnerEpollResponse1KSmoke);
  T.Run('server comparison runner include hyper epoll response_1k smoke',
    @TestServerComparisonRunnerIncludeHyperEpollResponse1KSmoke);
  T.Run('server comparison snapshot small smoke',
    @TestServerComparisonSnapshotSmallSmoke);
  T.Run('server comparison snapshot url_path smoke',
    @TestServerComparisonSnapshotUrlPathSmoke);
  T.Run('server comparison snapshot runs smoke',
    @TestServerComparisonSnapshotRunsSmoke);
  T.Run('server comparison snapshot preserves requested threads',
    @TestServerComparisonSnapshotPreservesRequestedThreads);
  T.Run('server comparison snapshot include hyper smoke',
    @TestServerComparisonSnapshotIncludeHyperSmoke);
  T.Run('server comparison snapshot include hyper url_path smoke',
    @TestServerComparisonSnapshotIncludeHyperUrlPathSmoke);
  T.Run('server comparison snapshot include hyper response_1k smoke',
    @TestServerComparisonSnapshotIncludeHyperResponse1KSmoke);
  T.Run('server comparison snapshot epoll url_path smoke',
    @TestServerComparisonSnapshotEpollUrlPathSmoke);
  T.Run('server comparison snapshot epoll response_1k smoke',
    @TestServerComparisonSnapshotEpollResponse1KSmoke);
  T.Run('server comparison snapshot include hyper epoll response_1k smoke',
    @TestServerComparisonSnapshotIncludeHyperEpollResponse1KSmoke);
  T.Run('server comparison snapshot rejects invalid nextpas backend',
    @TestServerComparisonSnapshotRejectsInvalidNextpasBackend);
  T.Run('server comparison snapshot rejects unsafe output path',
    @TestServerComparisonSnapshotRejectsUnsafeOutputPath);
  T.Run('server comparison snapshot epoll smoke',
    @TestServerComparisonSnapshotEpollSmoke);
  T.Run('C llhttp comparator requires LLHTTP_ROOT',
    @TestCllhttpComparatorRequiresRoot);
  T.Run('H1 parser benchmark max iterations env',
    @TestH1ParserBenchmarkMaxItersEnv);
  T.Run('H1 parser benchmark rejects invalid max iterations env',
    @TestH1ParserBenchmarkRejectsInvalidMaxIters);
  T.Run('H1 parser benchmark filter env',
    @TestH1ParserBenchmarkFilterEnv);
  T.Run('H1 parser benchmark rejects no-match filter',
    @TestH1ParserBenchmarkRejectsNoMatchFilter);
  T.Run('H1 parser benchmark header-span-add filter env',
    @TestH1ParserBenchmarkHeaderSpanAddFilterEnv);
  T.Run('H1 parser benchmark metadata cache filter env',
    @TestH1ParserBenchmarkMetadataCacheFilterEnv);
  T.Run('H1 parser benchmark request-path filter env',
    @TestH1ParserBenchmarkRequestPathFilterEnv);
  T.Run('H1 parser benchmark request-rawquery filter env',
    @TestH1ParserBenchmarkRequestRawQueryFilterEnv);
  T.Run('H1 parser benchmark request-path+rawquery filter env',
    @TestH1ParserBenchmarkRequestPathAndRawQueryFilterEnv);
  T.Run('H1 parser benchmark url-parse request-target filter env',
    @TestH1ParserBenchmarkUrlParseRequestTargetFilterEnv);
  T.Run('H1 parser benchmark url-parse generic filter env',
    @TestH1ParserBenchmarkUrlParseGenericFilterEnv);
  T.Run('H1 parser benchmark fast-headers filter env',
    @TestH1ParserBenchmarkFastHeadersFilterEnv);
  T.Run('H1 parser benchmark fast-headers get-all filter env',
    @TestH1ParserBenchmarkFastHeadersGetAllFilterEnv);
  T.Run('H1 parser benchmark fast-headers has filter env',
    @TestH1ParserBenchmarkFastHeadersHasFilterEnv);
  T.Run('H1 parser benchmark fast-headers count filter env',
    @TestH1ParserBenchmarkFastHeadersCountFilterEnv);
  T.Run('H1 parser benchmark fast-headers foreach filter env',
    @TestH1ParserBenchmarkFastHeadersForEachFilterEnv);
  T.Run('C llhttp comparator small smoke when configured',
    @TestCllhttpComparatorSmallSmokeWhenConfigured);
  T.Run('C llhttp comparator max iterations env when configured',
    @TestCllhttpComparatorMaxItersEnvWhenConfigured);
  T.Run('C llhttp comparator filter env when configured',
    @TestCllhttpComparatorFilterEnvWhenConfigured);
  T.Run('C llhttp comparator rejects no-match filter when configured',
    @TestCllhttpComparatorRejectsNoMatchFilterWhenConfigured);
  T.Run('H1 parser flag matrix smoke',
    @TestH1ParserFlagMatrixSmoke);
  T.Run('H1 parser flag matrix perf graceful smoke',
    @TestH1ParserFlagMatrixPerfGracefulSmoke);
  T.Run('H1 parser flag matrix runs summary smoke',
    @TestH1ParserFlagMatrixRunsSummarySmoke);
  T.Run('H1 parser flag matrix rejects unsafe output dir',
    @TestH1ParserFlagMatrixRejectsUnsafeOutputDir);
  T.Run('H1 parser flag matrix requires parsed rows source contract',
    @TestH1ParserFlagMatrixRequiresParsedRowsSourceContract);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
