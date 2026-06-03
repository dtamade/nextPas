program test_config_examples;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  Process,
  nextpas.core.testing;

var
  T: TTestRunner;
  GStartupExampleRan: Boolean = False;
  GStartupExampleExitCode: Integer = -1;
  GStartupExampleOutput: string = '';
  GStartupExampleDir: string = '';
  GExportExampleRan: Boolean = False;
  GExportExampleExitCode: Integer = -1;
  GExportExampleOutput: string = '';
  GExportExampleDir: string = '';
  GMutationExampleRan: Boolean = False;
  GMutationExampleExitCode: Integer = -1;
  GMutationExampleOutput: string = '';
  GMutationExampleDir: string = '';

const
  StartupExampleRelativeDir =
    'examples/nextpas.core.config/config_startup_patterns';
  ExportExampleRelativeDir =
    'examples/nextpas.core.config/config_export_patterns';
  MutationExampleRelativeDir =
    'examples/nextpas.core.config/config_mutation_patterns';
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
    if FileExists(PathJoin(LDir, ConfigUnitPath)) and
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

procedure EnsureExampleRun(const AExampleRelativeDir: string; var ARan: Boolean;
  var AExitCode: Integer; var AOutput, AExampleDir: string);
var
  LCoreRoot: string;
begin
  if ARan then
    Exit;

  LCoreRoot := ResolveCoreRoot(AExampleRelativeDir);
  AExampleDir := PathJoin(LCoreRoot, AExampleRelativeDir);
  Check(DirectoryExists(AExampleDir), 'example directory exists');
  RunProcessAndCapture(ResolveMakeExecutable, ['run'], AExampleDir,
    AExitCode, AOutput);
  ARan := True;
end;

procedure TestStartupPatternsExampleRunPasses;
begin
  EnsureExampleRun(StartupExampleRelativeDir, GStartupExampleRan,
    GStartupExampleExitCode, GStartupExampleOutput, GStartupExampleDir);
  CheckEqual(Int64(0), Int64(GStartupExampleExitCode), 'example exit code');
  CheckContains(GStartupExampleOutput, 'config-startup-patterns-status=pass',
    'pass marker');
end;

procedure TestStartupPatternsExampleReportsKeyPhase3Markers;
begin
  EnsureExampleRun(StartupExampleRelativeDir, GStartupExampleRan,
    GStartupExampleExitCode, GStartupExampleOutput, GStartupExampleDir);
  CheckContains(GStartupExampleOutput, 'snapshot-host=127.0.0.1', 'snapshot host');
  CheckContains(GStartupExampleOutput, 'snapshot-port=8080', 'snapshot port');
  CheckContains(GStartupExampleOutput, 'snapshot-url=http://127.0.0.1:8080',
    'snapshot url');
  CheckContains(GStartupExampleOutput, 'configload-host=127.0.0.1',
    'ConfigLoad host');
  CheckContains(GStartupExampleOutput, 'loadfromfile-host=127.0.0.1',
    'LoadFromFile host');
  CheckContains(GStartupExampleOutput, 'trybuild-valid=pass', 'TryBuild valid');
  CheckContains(GStartupExampleOutput, 'trybuild-invalid=pass', 'TryBuild invalid');
  CheckContains(GStartupExampleOutput, 'mutable-port=9090', 'mutable config marker');
  CheckContains(GStartupExampleOutput, 'snapshot-still-port=8080',
    'snapshot immutability marker');
end;

procedure TestExportPatternsExampleRunPasses;
begin
  EnsureExampleRun(ExportExampleRelativeDir, GExportExampleRan,
    GExportExampleExitCode, GExportExampleOutput, GExportExampleDir);
  CheckEqual(Int64(0), Int64(GExportExampleExitCode), 'export example exit code');
  CheckContains(GExportExampleOutput, 'config-export-patterns-status=pass',
    'export pass marker');
end;

procedure TestExportPatternsExampleReportsWriteMarkers;
begin
  EnsureExampleRun(ExportExampleRelativeDir, GExportExampleRan,
    GExportExampleExitCode, GExportExampleOutput, GExportExampleDir);
  CheckContains(GExportExampleOutput, 'ini-save-reload=pass', 'ini reload');
  CheckContains(GExportExampleOutput, 'json-save-reload=pass', 'json reload');
  CheckContains(GExportExampleOutput, 'yaml-save-reload=pass', 'yaml reload');
  CheckContains(GExportExampleOutput, 'toml-save-reload=pass', 'toml reload');
  CheckContains(GExportExampleOutput, 'snapshot-ini-export=pass',
    'snapshot ini export');
  CheckContains(GExportExampleOutput, 'ini-leading-space-reject=pass',
    'ini rejection marker');
end;

procedure TestMutationPatternsExampleRunPasses;
begin
  EnsureExampleRun(MutationExampleRelativeDir, GMutationExampleRan,
    GMutationExampleExitCode, GMutationExampleOutput, GMutationExampleDir);
  CheckEqual(Int64(0), Int64(GMutationExampleExitCode),
    'mutation example exit code');
  CheckContains(GMutationExampleOutput, 'config-mutation-patterns-status=pass',
    'mutation pass marker');
end;

procedure TestMutationPatternsExampleReportsWriteMarkers;
begin
  EnsureExampleRun(MutationExampleRelativeDir, GMutationExampleRan,
    GMutationExampleExitCode, GMutationExampleOutput, GMutationExampleDir);
  CheckContains(GMutationExampleOutput, 'service-url=http://127.0.0.1:8080',
    'interpolated write');
  CheckContains(GMutationExampleOutput,
    'raw-service-url=http://${server.host}:${server.port}', 'raw write');
  CheckContains(GMutationExampleOutput, 'feature-enabled=pass', 'bool write');
  CheckContains(GMutationExampleOutput, 'tags-count=2', 'array write');
  CheckContains(GMutationExampleOutput, 'deletekey-removed=pass',
    'delete key marker');
  CheckContains(GMutationExampleOutput, 'deletesection-removed=pass',
    'delete section marker');
  CheckContains(GMutationExampleOutput, 'replacefrom-host=worker.local',
    'replacefrom marker');
  CheckContains(GMutationExampleOutput, 'clear-count=0', 'clear marker');
end;

begin
  T := TTestRunner.Create('config startup examples');
  T.Run('startup example run passes', @TestStartupPatternsExampleRunPasses);
  T.Run('startup example reports key phase3 markers',
    @TestStartupPatternsExampleReportsKeyPhase3Markers);
  T.Run('export example run passes', @TestExportPatternsExampleRunPasses);
  T.Run('export example reports write markers',
    @TestExportPatternsExampleReportsWriteMarkers);
  T.Run('mutation example run passes', @TestMutationPatternsExampleRunPasses);
  T.Run('mutation example reports write markers',
    @TestMutationPatternsExampleReportsWriteMarkers);
  T.Summary;
end.
