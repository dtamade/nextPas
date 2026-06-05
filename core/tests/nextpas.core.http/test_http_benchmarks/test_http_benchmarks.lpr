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
  CompareGoRelativeDir = 'benchmarks/nextpas.core.http/compare_go';
  CompareRustRelativeDir = 'benchmarks/nextpas.core.http/compare_rust';
  HttpUnitPath = 'src/nextpas.core.http.pas';
  LlhttpRootEnvName = 'NEXTPAS_LLHTTP_ROOT';

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

procedure CheckServerBenchmarkOutput(const AOutput, AImplementation: string;
  const AIterations, AThreads: string);
begin
  CheckContains(AOutput, 'operation=http.server.keepalive', 'operation marker');
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

begin
  T := TTestRunner.Create('http benchmarks');
  T.Run('bench_server small smoke', @TestBenchServerSmallSmoke);
  T.Run('go server comparator small smoke', @TestGoServerComparatorSmallSmoke);
  T.Run('rust server comparator small smoke', @TestRustServerComparatorSmallSmoke);
  T.Run('server comparison runner small smoke',
    @TestServerComparisonRunnerSmallSmoke);
  T.Run('server comparison snapshot small smoke',
    @TestServerComparisonSnapshotSmallSmoke);
  T.Run('C llhttp comparator requires LLHTTP_ROOT',
    @TestCllhttpComparatorRequiresRoot);
  T.Run('C llhttp comparator small smoke when configured',
    @TestCllhttpComparatorSmallSmokeWhenConfigured);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
