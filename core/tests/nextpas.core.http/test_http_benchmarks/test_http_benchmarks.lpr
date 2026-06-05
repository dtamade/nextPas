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
  H1ParserBenchRelativeDir = 'benchmarks/nextpas.core.http/bench_h1parser';
  ServerComparisonRelativeDir = 'benchmarks/nextpas.core.http';
  ServerComparisonRunnerRelativePath =
    'benchmarks/nextpas.core.http/run_server_comparison.sh';
  ServerSnapshotRunnerRelativePath =
    'benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh';
  H1FlagMatrixRunnerRelativePath =
    'benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh';
  CompareGoRelativeDir = 'benchmarks/nextpas.core.http/compare_go';
  CompareRustRelativeDir = 'benchmarks/nextpas.core.http/compare_rust';
  HttpUnitPath = 'src/nextpas.core.http.pas';
  LlhttpRootEnvName = 'NEXTPAS_LLHTTP_ROOT';
  BenchMaxItersEnvName = 'NEXTPAS_BENCH_MAX_ITERS';
  BenchFilterEnvName = 'NEXTPAS_BENCH_FILTER';
  BenchMaxItersSmokeValue = '2000';

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

function ResolveBenchServerBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_server/bench_http_server');
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
  CheckContains(AOutput, 'ns/op=', 'ns/op marker');
  CheckContains(AOutput, 'req/s=', 'req/s marker');
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

begin
  T := TTestRunner.Create('http benchmarks');
  T.Run('bench_server small smoke', @TestBenchServerSmallSmoke);
  T.Run('bench_server url_path small smoke',
    @TestBenchServerUrlPathSmallSmoke);
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
  T.Run('server comparison snapshot small smoke',
    @TestServerComparisonSnapshotSmallSmoke);
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
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
