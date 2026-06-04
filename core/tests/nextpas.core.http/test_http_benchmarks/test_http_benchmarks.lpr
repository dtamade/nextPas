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

function ResolveBenchServerBinaryPath(const ARootDir: string): string;
begin
  Result := PathJoin(ARootDir,
    'build/projects/nextpas.core.http/bench_server/bench_http_server');
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
  CheckContains(LOutput, 'operation=http.server.keepalive', 'operation marker');
  CheckContains(LOutput, 'iterations=32', 'iterations marker');
  CheckContains(LOutput, 'threads=2', 'threads marker');
  CheckContains(LOutput, 'ns/op=', 'ns/op marker');
  CheckContains(LOutput, 'req/s=', 'req/s marker');
end;

begin
  T := TTestRunner.Create('http benchmarks');
  T.Run('bench_server small smoke', @TestBenchServerSmallSmoke);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
