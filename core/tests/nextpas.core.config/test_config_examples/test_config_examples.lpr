program test_config_examples;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  Process,
  nextpas.core.testing;

var
  T: TTestRunner;
  GExampleRan: Boolean = False;
  GExampleExitCode: Integer = -1;
  GExampleOutput: string = '';
  GExampleDir: string = '';

const
  ExampleRelativeDir =
    'examples/nextpas.core.config/config_startup_patterns';
  ConfigUnitPath = 'src/nextpas.core.config.pas';

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

function TryResolveCoreRootFrom(const AStartDir: string; out ARootDir: string): Boolean;
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
    if FileExists(PathJoin(LDir, ConfigUnitPath)) and
      DirectoryExists(PathJoin(LDir, ExampleRelativeDir)) then
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

function ResolveCoreRoot: string;
begin
  if TryResolveCoreRootFrom(GetCurrentDir, Result) then
    Exit;
  if TryResolveCoreRootFrom(ExtractFileDir(ExpandFileName(ParamStr(0))), Result) then
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

procedure EnsureExampleRun;
var
  LCoreRoot: string;
begin
  if GExampleRan then
    Exit;

  LCoreRoot := ResolveCoreRoot;
  GExampleDir := PathJoin(LCoreRoot, ExampleRelativeDir);
  Check(DirectoryExists(GExampleDir), 'example directory exists');
  RunProcessAndCapture(ResolveMakeExecutable, ['run'], GExampleDir,
    GExampleExitCode, GExampleOutput);
  GExampleRan := True;
end;

procedure TestStartupPatternsExampleRunPasses;
begin
  EnsureExampleRun;
  CheckEqual(Int64(0), Int64(GExampleExitCode), 'example exit code');
  CheckContains(GExampleOutput, 'config-startup-patterns-status=pass',
    'pass marker');
end;

procedure TestStartupPatternsExampleReportsKeyPhase3Markers;
begin
  EnsureExampleRun;
  CheckContains(GExampleOutput, 'snapshot-host=127.0.0.1', 'snapshot host');
  CheckContains(GExampleOutput, 'snapshot-port=8080', 'snapshot port');
  CheckContains(GExampleOutput, 'snapshot-url=http://127.0.0.1:8080',
    'snapshot url');
  CheckContains(GExampleOutput, 'configload-host=127.0.0.1',
    'ConfigLoad host');
  CheckContains(GExampleOutput, 'trybuild-valid=pass', 'TryBuild valid');
  CheckContains(GExampleOutput, 'trybuild-invalid=pass', 'TryBuild invalid');
  CheckContains(GExampleOutput, 'mutable-port=9090', 'mutable config marker');
  CheckContains(GExampleOutput, 'snapshot-still-port=8080',
    'snapshot immutability marker');
end;

begin
  T := TTestRunner.Create('config startup examples');
  T.Run('startup example run passes', @TestStartupPatternsExampleRunPasses);
  T.Run('startup example reports key phase3 markers',
    @TestStartupPatternsExampleReportsKeyPhase3Markers);
  T.Summary;
end.
