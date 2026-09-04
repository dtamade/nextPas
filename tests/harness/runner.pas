program nextpas_test_harness_runner;

{$mode objfpc}{$H+}

uses
  Classes, Process, SysUtils, nextpas.core.platform.which, snapshot_support;

type
  THarnessGroup = (
    hgCompilerPass,
    hgCompilerFail,
    hgDiagnostics,
    hgLexer,
    hgParser,
    hgSemantic,
    hgToolchain,
    hgRTL,
    hgCRT,
    hgMir,
    hgRegression
  );

const
  ExitSuccessCode = 0;
  ExitFailureCode = 1;
  BaselineTargetName = 'linux-x86_64';
  LinuxX8664DefaultInterpreter = '/lib64/ld-linux-x86-64.so.2';
  LinuxX8664FallbackLoader = '/lib64/ld-linux-x86-64.so.2';
  HarnessTempRoot = 'build/harness/work';
  DefaultStage0Executable = 'build/stage0-bootstrap/nextpas';
  HostCompilerExecutable = 'fpc';
  ProcessReadBufferSize = 4096;
  ProcessPollIntervalMs = 50;

type
  TCompilerMode = (
    cmStage0BuildRun,
    cmStage0BuildValidate,
    cmHostFpcBuildValidate,
    cmHostFpcBuildRun
  );

  TGroupConfig = record
    Name: string;
    Directory: string;
    Expectation: string;
    Suffixes: string;
    UsesSnapshot: Boolean;
    CompilerMode: TCompilerMode;
  end;

  TFixtureExecution = record
    FixturePath: string;
    ToolName: string;
    OutputPath: string;
    RunOutputPath: string;
    ArtifactPath: string;
    SnapshotPath: string;
    SnapshotDiffPath: string;
    SnapshotStatus: string;
    FailureKind: string;
    ResultValue: string;
    ExitCode: LongInt;
    Executed: Boolean;
    Passed: Boolean;
  end;

const
  HARNESS_GROUPS: array[THarnessGroup] of TGroupConfig = (
    (Name: 'compiler-pass'; Directory: 'tests/compiler/pass';
     Expectation: 'compile-success'; Suffixes: '_pass.pas';
     UsesSnapshot: False; CompilerMode: cmStage0BuildRun),
    (Name: 'compiler-fail'; Directory: 'tests/compiler/fail';
     Expectation: 'expected-compile-failure'; Suffixes: '_fail.pas';
     UsesSnapshot: True; CompilerMode: cmStage0BuildValidate),
    (Name: 'diagnostics'; Directory: 'tests/diagnostics';
     Expectation: 'diagnostic-snapshot'; Suffixes: '';
     UsesSnapshot: True; CompilerMode: cmHostFpcBuildValidate),
    (Name: 'lexer'; Directory: 'tests/lexer';
     Expectation: 'lexer-tokenization'; Suffixes: '_pass.pas';
     UsesSnapshot: False; CompilerMode: cmStage0BuildRun),
    (Name: 'parser'; Directory: 'tests/parser';
     Expectation: 'parse-success'; Suffixes: '_pass.pas';
     UsesSnapshot: False; CompilerMode: cmStage0BuildRun),
    (Name: 'semantic'; Directory: 'tests/semantic';
     Expectation: 'semantic-analysis'; Suffixes: '_pass.pas;_fail.pas';
     UsesSnapshot: False; CompilerMode: cmStage0BuildRun),
    (Name: 'toolchain'; Directory: 'tests/toolchain';
     Expectation: 'toolchain-contract'; Suffixes: '_smoke.pas';
     UsesSnapshot: False; CompilerMode: cmHostFpcBuildRun),
    (Name: 'rtl'; Directory: 'tests/rtl';
     Expectation: 'rtl-smoke'; Suffixes: '_smoke.pas';
     UsesSnapshot: False; CompilerMode: cmHostFpcBuildRun),
    (Name: 'crt'; Directory: 'tests/crt';
     Expectation: 'crt-smoke'; Suffixes: '_smoke.pas';
     UsesSnapshot: False; CompilerMode: cmHostFpcBuildRun),
    (Name: 'mir'; Directory: 'tests/mir';
     Expectation: 'mir-optimization'; Suffixes: '_pass.pas';
     UsesSnapshot: False; CompilerMode: cmStage0BuildRun),
    (Name: 'regression'; Directory: 'tests/regression';
     Expectation: 'regression-guard'; Suffixes: '_regression.pas';
     UsesSnapshot: False; CompilerMode: cmHostFpcBuildRun)
  );

type
  TGroupRunSummary = record
    FixtureCount: SizeInt;
    ExecutedCount: SizeInt;
    PassedCount: SizeInt;
    FailedCount: SizeInt;
    SnapshotCount: SizeInt;
    MissingSnapshotCount: SizeInt;
    UnstableSnapshotCount: SizeInt;
    SnapshotStatus: string;
    StatusValue: string;
    ResultValue: string;
    HumanSummary: string;
  end;

function JsonEscape(const Value: string): string;
var
  Index: SizeInt;
  Ch: Char;
begin
  Result := '';
  for Index := 1 to Length(Value) do
  begin
    Ch := Value[Index];
    case Ch of
      '\':
        Result := Result + '\\';
      '"':
        Result := Result + '\"';
      #8:
        Result := Result + '\b';
      #9:
        Result := Result + '\t';
      #10:
        Result := Result + '\n';
      #11:
        Result := Result + '\u000b';
      #12:
        Result := Result + '\f';
      #13:
        Result := Result + '\r';
    else
      if (Ord(Ch) < 32) then
        Result := Result + '\u' + LowerCase(
          IntToHex(Ord(Ch), 4)
        )
      else
        Result := Result + Ch;
    end;
  end;
end;

function JsonString(const Value: string): string;
begin
  Result := '"' + JsonEscape(Value) + '"';
end;

procedure AppendJsonField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
begin
  if AFields <> '' then
    AFields := AFields + ',';
  AFields := AFields + JsonString(AName) + ':' + AValue;
end;

procedure AppendJsonStringField(
  var AFields: string;
  const AName: string;
  const AValue: string
);
begin
  if AValue = '' then
    Exit;

  AppendJsonField(AFields, AName, JsonString(AValue));
end;

procedure AppendJsonIntegerField(
  var AFields: string;
  const AName: string;
  const AValue: LongInt;
  const AEnabled: Boolean
);
begin
  if not AEnabled then
    Exit;

  AppendJsonField(AFields, AName, IntToStr(AValue));
end;

function BuildCommandEnvelopeJson(
  const AExitCode: LongInt;
  const AResultFields: string;
  const AHumanSummary: string
): string;
var
  EnvelopeFields: string;
begin
  EnvelopeFields := '';
  AppendJsonField(EnvelopeFields, 'command', JsonString('test'));
  AppendJsonField(EnvelopeFields, 'exitCode', IntToStr(AExitCode));
  if AResultFields <> '' then
    AppendJsonField(EnvelopeFields, 'result', '{' + AResultFields + '}');
  AppendJsonField(EnvelopeFields, 'diagnostics', '[]');
  AppendJsonField(EnvelopeFields, 'buildTraceRef', 'null');
  AppendJsonField(EnvelopeFields, 'humanSummary', JsonString(AHumanSummary));
  Result := '{' + EnvelopeFields + '}';
end;

procedure PrintCommandEnvelope(
  const AExitCode: LongInt;
  const AResultFields: string;
  const AHumanSummary: string;
  const AUseStdErr: Boolean
);
var
  EnvelopeJson: string;
begin
  EnvelopeJson := BuildCommandEnvelopeJson(
    AExitCode,
    AResultFields,
    AHumanSummary
  );
  if AUseStdErr then
    WriteLn(StdErr, 'command-envelope=', EnvelopeJson)
  else
    WriteLn('command-envelope=', EnvelopeJson);
end;

function GroupUsesDiagnosticsSnapshot(const AGroup: THarnessGroup): Boolean; forward;

function BuildGroupResultFields(
  const AGroup: THarnessGroup;
  const AFixtureCount: SizeInt;
  const AExecutedFixtureCount: SizeInt;
  const AFailedFixtureCount: SizeInt;
  const AStatusValue: string;
  const AResultValue: string;
  const ASnapshotCount: SizeInt;
  const ASnapshotStatus: string
): string;
begin
  Result := '';
  AppendJsonStringField(Result, 'selector', 'group');
  AppendJsonStringField(Result, 'target', BaselineTargetName);
  AppendJsonStringField(Result, 'group', HARNESS_GROUPS[AGroup].Name);
  AppendJsonStringField(Result, 'path', HARNESS_GROUPS[AGroup].Directory);
  AppendJsonIntegerField(Result, 'fixtures', LongInt(AFixtureCount), True);
  AppendJsonIntegerField(
    Result,
    'executedFixtures',
    LongInt(AExecutedFixtureCount),
    True
  );
  AppendJsonIntegerField(
    Result,
    'failedFixtures',
    LongInt(AFailedFixtureCount),
    True
  );
  AppendJsonStringField(Result, 'expectation', HARNESS_GROUPS[AGroup].Expectation);
  AppendJsonStringField(Result, 'status', AStatusValue);
  AppendJsonStringField(Result, 'result', AResultValue);
  if GroupUsesDiagnosticsSnapshot(AGroup) then
  begin
    AppendJsonStringField(Result, 'snapshotRoot', SnapshotRoot);
    AppendJsonIntegerField(Result, 'snapshotCount', LongInt(ASnapshotCount), True);
    AppendJsonStringField(Result, 'snapshotStatus', ASnapshotStatus);
  end;
end;

function BuildSmokeResultFields(
  const AStatusValue: string;
  const AResultValue: string;
  const AFailedGroupCount: SizeInt;
  const AMissingFixtureCount: SizeInt;
  const AMissingSnapshotCount: SizeInt;
  const AUnstableSnapshotCount: SizeInt
): string;
begin
  Result := '';
  AppendJsonStringField(Result, 'selector', 'smoke');
  AppendJsonStringField(Result, 'target', BaselineTargetName);
  AppendJsonStringField(Result, 'status', AStatusValue);
  AppendJsonStringField(Result, 'result', AResultValue);
  AppendJsonIntegerField(
    Result,
    'groupCount',
    LongInt(Ord(High(THarnessGroup)) - Ord(Low(THarnessGroup)) + 1),
    True
  );
  AppendJsonIntegerField(
    Result,
    'failedGroups',
    LongInt(AFailedGroupCount),
    True
  );
  AppendJsonIntegerField(
    Result,
    'missingFixtures',
    LongInt(AMissingFixtureCount),
    True
  );
  AppendJsonIntegerField(
    Result,
    'missingSnapshots',
    LongInt(AMissingSnapshotCount),
    True
  );
  AppendJsonIntegerField(
    Result,
    'unstableSnapshots',
    LongInt(AUnstableSnapshotCount),
    True
  );
end;

function BuildFailureResultFields(
  const ASelector: string;
  const ARequestedFilter: string;
  const AFailureKind: string
): string;
begin
  Result := '';
  AppendJsonStringField(Result, 'selector', ASelector);
  AppendJsonStringField(Result, 'target', BaselineTargetName);
  AppendJsonStringField(Result, 'requestedFilter', ARequestedFilter);
  AppendJsonStringField(Result, 'status', 'failure');
  AppendJsonStringField(Result, 'result', 'failure');
  AppendJsonStringField(Result, 'failureKind', AFailureKind);
end;

procedure PrintUsage;
var
  Group: THarnessGroup;
begin
  WriteLn('Usage:');
  WriteLn('  ./tests/run_all_tests.sh --list-groups');
  WriteLn('  ./tests/run_all_tests.sh --filter <group>');
  WriteLn;
  WriteLn('Supported groups:');
  for Group := Low(THarnessGroup) to High(THarnessGroup) do
    WriteLn('  ', HARNESS_GROUPS[Group].Name, '    ', HARNESS_GROUPS[Group].Expectation);
  WriteLn;
  WriteLn('Special filter:');
  WriteLn('  smoke            run all groups as baseline check');
end;

procedure PrintUsageError;
begin
  WriteLn(StdErr, 'Usage:');
  WriteLn(StdErr, '  ./tests/run_all_tests.sh --list-groups');
  WriteLn(StdErr, '  ./tests/run_all_tests.sh --filter <group>');
  WriteLn(StdErr);
  WriteLn(StdErr, 'Run with --help for full group list.');
end;

function TryFindGroup(const AName: string; out AGroup: THarnessGroup): Boolean;
var
  Group: THarnessGroup;
begin
  for Group := Low(THarnessGroup) to High(THarnessGroup) do
    if HARNESS_GROUPS[Group].Name = AName then
    begin
      AGroup := Group;
      Exit(True);
    end;

  Result := False;
end;

procedure PrintKnownGroups;
var
  Group: THarnessGroup;
begin
  for Group := Low(THarnessGroup) to High(THarnessGroup) do
    WriteLn(HARNESS_GROUPS[Group].Name);
end;

function EndsWithText(const AValue: string; const ASuffix: string): Boolean;
begin
  Result :=
    (Length(AValue) >= Length(ASuffix)) and
    (CompareText(
      Copy(AValue, Length(AValue) - Length(ASuffix) + 1, Length(ASuffix)),
      ASuffix
    ) = 0);
end;

function Stage0ExecutablePath: string;
begin
  Result := GetEnvironmentVariable('NEXTPAS_STAGE0');
  if Result = '' then
    Result := DefaultStage0Executable;
end;

function WorkspaceRootPath: string;
begin
  Result := GetEnvironmentVariable('NEXTPAS_WORKSPACE_ROOT');
  if Result = '' then
    Result := GetCurrentDir;
end;

function FixtureToken(
  const AGroup: THarnessGroup;
  const AFixturePath: string
): string;
var
  RelativeName: string;
begin
  RelativeName := ChangeFileExt(
    RelativeFixtureName(HARNESS_GROUPS[AGroup].Directory, AFixturePath),
    ''
  );
  RelativeName := StringReplace(
    RelativeName,
    PathDelim,
    '-',
    [rfReplaceAll]
  );
  Result := HARNESS_GROUPS[AGroup].Name + '-' + RelativeName;
end;

function FixtureTempDirectory(
  const AGroup: THarnessGroup;
  const AFixturePath: string
): string;
begin
  Result :=
    IncludeTrailingPathDelimiter(HarnessTempRoot) +
    FixtureToken(AGroup, AFixturePath);
  ForceDirectories(Result);
end;

function FixtureOutputPath(
  const AGroup: THarnessGroup;
  const AFixturePath: string
): string;
begin
  Result :=
    IncludeTrailingPathDelimiter(FixtureTempDirectory(AGroup, AFixturePath)) +
    'build-output.txt';
end;

function FixtureRunOutputPath(
  const AGroup: THarnessGroup;
  const AFixturePath: string
): string;
begin
  Result :=
    IncludeTrailingPathDelimiter(FixtureTempDirectory(AGroup, AFixturePath)) +
    'run-output.txt';
end;

function FixtureBinaryDirectory(
  const AGroup: THarnessGroup;
  const AFixturePath: string
): string;
begin
  Result :=
    IncludeTrailingPathDelimiter(FixtureTempDirectory(AGroup, AFixturePath)) +
    'bin';
  ForceDirectories(Result);
end;

function FixtureBinaryPath(
  const AGroup: THarnessGroup;
  const AFixturePath: string
): string;
begin
  Result :=
    IncludeTrailingPathDelimiter(FixtureBinaryDirectory(AGroup, AFixturePath)) +
    ChangeFileExt(ExtractFileName(AFixturePath), '');
end;

procedure DeleteIfExists(const APath: string);
begin
  if (APath <> '') and FileExists(APath) then
    DeleteFile(APath);
end;

procedure ClearStage0FixtureArtifacts(
  const AGroup: THarnessGroup;
  const AFixturePath: string
);
begin
  DeleteIfExists(FixtureBinaryPath(AGroup, AFixturePath));
end;

function GroupFixtureMatches(
  const AGroup: THarnessGroup;
  const AFixturePath: string
): Boolean;
var
  FileName: string;
  Suffixes: string;
  SemicolonPos: SizeInt;
begin
  if CompareText(ExtractFileExt(AFixturePath), '.pas') <> 0 then
    Exit(False);

  Suffixes := HARNESS_GROUPS[AGroup].Suffixes;
  if Suffixes = '' then
    Exit(True);

  FileName := LowerCase(ExtractFileName(AFixturePath));
  Result := False;
  while Suffixes <> '' do
  begin
    SemicolonPos := Pos(';', Suffixes);
    if SemicolonPos > 0 then
    begin
      if EndsWithText(FileName, Copy(Suffixes, 1, SemicolonPos - 1)) then
        Exit(True);
      Delete(Suffixes, 1, SemicolonPos);
    end
    else
    begin
      Result := EndsWithText(FileName, Suffixes);
      Exit;
    end;
  end;
end;

procedure CollectFilesRecursive(
  const AGroup: THarnessGroup;
  const APath: string;
  AFiles: TStrings
);
var
  SearchRec: TSearchRec;
  ChildPath: string;
begin
  if not DirectoryExists(APath) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, SearchRec) <> 0 then
    Exit;

  try
    repeat
      if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
        Continue;

      ChildPath := IncludeTrailingPathDelimiter(APath) + SearchRec.Name;
      if (SearchRec.Attr and faDirectory) <> 0 then
        CollectFilesRecursive(AGroup, ChildPath, AFiles)
      else if GroupFixtureMatches(AGroup, ChildPath) then
        AFiles.Add(ChildPath);
    until FindNext(SearchRec) <> 0;
  finally
    FindClose(SearchRec);
  end;
end;

procedure CollectGroupFixtures(const AGroup: THarnessGroup; AFiles: TStrings);
begin
  CollectFilesRecursive(AGroup, HARNESS_GROUPS[AGroup].Directory, AFiles);
  if AFiles is TStringList then
    TStringList(AFiles).Sort;
end;

function GroupUsesDiagnosticsSnapshot(const AGroup: THarnessGroup): Boolean;
begin
  Result := HARNESS_GROUPS[AGroup].UsesSnapshot;
end;

function RunProcessCapture(
  const AExecutable: string;
  const AWorkingDirectory: string;
  const AParameters: TStrings;
  out AOutput: string;
  ATimeoutMs: LongInt = 120000
): LongInt;
var
  Proc: TProcess;
  Buffer: array[0..ProcessReadBufferSize - 1] of Byte;
  BytesRead: LongInt;
  Chunk: RawByteString;
  Index: Integer;
  ElapsedMs: LongInt;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExecutable;
    Proc.Options := [poUsePipes, poStderrToOutPut];
    if AWorkingDirectory <> '' then
      Proc.CurrentDirectory := AWorkingDirectory;
    for Index := 0 to AParameters.Count - 1 do
      Proc.Parameters.Add(AParameters[Index]);
    Proc.Execute;
    AOutput := '';
    ElapsedMs := 0;
    repeat
      while Proc.Output.NumBytesAvailable > 0 do
      begin
        BytesRead := Proc.Output.Read(Buffer, SizeOf(Buffer));
        if BytesRead <= 0 then
          Break;
        SetString(Chunk, PAnsiChar(@Buffer[0]), BytesRead);
        AOutput := AOutput + string(Chunk);
      end;
      if Proc.Running then
      begin
        if (ATimeoutMs > 0) and (ElapsedMs >= ATimeoutMs) then
        begin
          Proc.Terminate(9);
          AOutput := AOutput + LineEnding +
            'harness: process killed after ' + IntToStr(ATimeoutMs) + 'ms timeout';
          Result := ExitFailureCode;
          Exit;
        end;
        Sleep(ProcessPollIntervalMs);
        Inc(ElapsedMs, ProcessPollIntervalMs);
      end;
    until not Proc.Running;
    while Proc.Output.NumBytesAvailable > 0 do
    begin
      BytesRead := Proc.Output.Read(Buffer, SizeOf(Buffer));
      if BytesRead <= 0 then
        Break;
      SetString(Chunk, PAnsiChar(@Buffer[0]), BytesRead);
      AOutput := AOutput + string(Chunk);
    end;
    Result := Proc.ExitCode;
  finally
    Proc.Free;
  end;
end;

function HostPathIsExecutable(const APath: string): Boolean;
begin
  Result := (APath <> '') and platform_is_executable(PAnsiChar(APath));
end;

function ShouldUseLinuxX8664LoaderFallback: Boolean;
begin
  Result :=
    (BaselineTargetName = 'linux-x86_64') and
    (not FileExists(LinuxX8664DefaultInterpreter)) and
    HostPathIsExecutable(LinuxX8664FallbackLoader);
end;

function RunTargetArtifactCapture(
  const AArtifactPath: string;
  const AWorkingDirectory: string;
  const AParameters: TStrings;
  out AOutput: string
): LongInt;
var
  LoaderParameters: TStringList;
  Index: Integer;
begin
  if not ShouldUseLinuxX8664LoaderFallback then
    Exit(RunProcessCapture(
      ExpandFileName(AArtifactPath),
      AWorkingDirectory,
      AParameters,
      AOutput
    ));

  LoaderParameters := TStringList.Create;
  try
    LoaderParameters.Add(ExpandFileName(AArtifactPath));
    for Index := 0 to AParameters.Count - 1 do
      LoaderParameters.Add(AParameters[Index]);
    Result := RunProcessCapture(
      LinuxX8664FallbackLoader,
      AWorkingDirectory,
      LoaderParameters,
      AOutput
    );
  finally
    LoaderParameters.Free;
  end;
end;

function SafeRunProcessCapture(
  const AExecutable: string;
  const AWorkingDirectory: string;
  const AParameters: TStrings;
  out AOutput: string;
  var AExitCode: LongInt;
  const AFailureKind: string;
  var AExecution: TFixtureExecution
): Boolean;
begin
  try
    AExitCode := RunProcessCapture(
      AExecutable, AWorkingDirectory, AParameters, AOutput
    );
    Result := True;
  except
    on E: Exception do
    begin
      AOutput := E.Message + LineEnding;
      AExitCode := ExitFailureCode;
      AExecution.FailureKind := AFailureKind;
      Result := False;
    end;
  end;
end;

function SafeRunTargetArtifactCapture(
  const AArtifactPath: string;
  out AOutput: string;
  var AExitCode: LongInt;
  var AExecution: TFixtureExecution
): Boolean;
var
  EmptyParams: TStringList;
begin
  EmptyParams := TStringList.Create;
  try
    AExitCode := RunTargetArtifactCapture(
      AArtifactPath, '', EmptyParams, AOutput
    );
    Result := True;
  except
    on E: Exception do
    begin
      AOutput := E.Message + LineEnding;
      AExitCode := ExitFailureCode;
      AExecution.FailureKind := 'fixture-runtime-failed';
      Result := False;
    end;
  end;
  EmptyParams.Free;
end;

function ExtractProjectionValue(
  const AOutput: string;
  const APrefix: string
): string;
var
  Lines: TStringList;
  Index: Integer;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := NormalizeSnapshotText(AOutput);
    for Index := 0 to Lines.Count - 1 do
      if Pos(APrefix, Lines[Index]) = 1 then
        Exit(Copy(Lines[Index], Length(APrefix) + 1, Length(Lines[Index])));
  finally
    Lines.Free;
  end;
end;

function ExtractCompilerMessage(const AOutput: string): string;
var
  Lines: TStringList;
  Index: Integer;
  Line: string;
  MarkerPosition: SizeInt;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := NormalizeSnapshotText(AOutput);
    for Index := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[Index]);
      if Line = '' then
        Continue;

      MarkerPosition := Pos(' Fatal: ', Line);
      if MarkerPosition > 0 then
        Exit(Copy(Line, MarkerPosition + Length(' Fatal: '), MaxInt));

      MarkerPosition := Pos(' Error: ', Line);
      if MarkerPosition > 0 then
        Exit(Copy(Line, MarkerPosition + Length(' Error: '), MaxInt));

      if Pos('Fatal: ', Line) = 1 then
        Exit(Copy(Line, Length('Fatal: ') + 1, MaxInt));

      if Pos('Error: ', Line) = 1 then
        Exit(Copy(Line, Length('Error: ') + 1, MaxInt));
    end;
  finally
    Lines.Free;
  end;
end;

function CanonicalParserSummary(const ADiagnosticMessage: string): string;
begin
  if Pos('";" expected but "BEGIN" found', ADiagnosticMessage) > 0 then
    Exit('expected ";" before BEGIN');

  if Pos('Unexpected end of file', ADiagnosticMessage) > 0 then
    Exit('unexpected end of file; expected END');

  Result := ADiagnosticMessage;
end;

function CanonicalFailureSummary(
  const AGroup: THarnessGroup;
  const AOutput: string
): string;
var
  DiagnosticCode: string;
  DiagnosticMessage: string;
  FailureKind: string;
  CompilerMessage: string;
begin
  DiagnosticCode := ExtractProjectionValue(AOutput, 'diagnostic-code=');
  DiagnosticMessage := ExtractProjectionValue(AOutput, 'diagnostic-message=');
  FailureKind := ExtractProjectionValue(AOutput, 'failure-kind=');
  CompilerMessage := ExtractCompilerMessage(AOutput);

  if DiagnosticCode = 'parser.syntax-error' then
    Exit(CanonicalParserSummary(DiagnosticMessage));

  if DiagnosticCode = 'resolver.unit-not-found' then
    Exit('unit not found');

  if DiagnosticCode = 'resolver.ambiguous-unit-source' then
    Exit('ambiguous unit source');

  if DiagnosticCode = 'resolver.unit-cycle-detected' then
    Exit('unit cycle detected');

  if DiagnosticCode = 'resolver.unit-name-mismatch' then
    Exit('unit name mismatch');

  if DiagnosticCode = 'sema.duplicate-declaration' then
    Exit('duplicate unit import');

  if DiagnosticCode = 'sema.missing-external-symbol-name' then
    Exit('missing external symbol name');

  if DiagnosticCode = 'sema.wrong-argument-count' then
    Exit('wrong argument count');

  if (AGroup = hgDiagnostics) and (CompilerMessage <> '') then
  begin
    if Pos('Unexpected end of file', CompilerMessage) > 0 then
      Exit('unexpected end of file; expected END');
    Exit(CompilerMessage);
  end;

  if CompilerMessage <> '' then
    Exit(CompilerMessage);

  if FailureKind <> '' then
    Exit(FailureKind);

  if ExtractProjectionValue(AOutput, 'status=') = 'success' then
    Exit('unexpected command success');

  Result := 'execution result unavailable';
end;

function BuildSnapshotActualText(
  const AGroup: THarnessGroup;
  const AFixturePath: string;
  const AOutput: string
): string;
var
  Classification: string;
begin
  if AGroup = hgDiagnostics then
    Classification := 'parser-diagnostic'
  else
    Classification := 'expected-compile-failure';

  Result :=
    'error: ' + CanonicalFailureSummary(AGroup, AOutput) + LineEnding +
    'fixture: ' + AFixturePath + LineEnding +
    'classification: ' + Classification + LineEnding;
end;

function BuildSnapshotMismatchText(
  const ASnapshotPath: string;
  const AExpectedText: string;
  const AActualText: string
): string;
begin
  Result :=
    'snapshot mismatch' + LineEnding +
    'snapshot: ' + ASnapshotPath + LineEnding +
    '--- expected ---' + LineEnding +
    AExpectedText + LineEnding +
    '--- actual ---' + LineEnding +
    AActualText + LineEnding;
end;

procedure ClearSnapshotDiff(const ADiffPath: string);
begin
  if FileExists(ADiffPath) then
    DeleteFile(ADiffPath);
end;

procedure ApplySnapshotValidation(
  const AGroup: THarnessGroup;
  const AFixturePath: string;
  const AActualText: string;
  var AExecution: TFixtureExecution
);
var
  ExpectedText: string;
begin
  AExecution.SnapshotPath := SnapshotPathForFixture(
    HARNESS_GROUPS[AGroup].Name,
    HARNESS_GROUPS[AGroup].Directory,
    AFixturePath
  );
  AExecution.SnapshotDiffPath := SnapshotDiffPathForFixture(
    HARNESS_GROUPS[AGroup].Name,
    HARNESS_GROUPS[AGroup].Directory,
    AFixturePath
  );

  if not FileExists(AExecution.SnapshotPath) then
  begin
    AExecution.SnapshotStatus := 'missing';
    WriteTextFile(
      AExecution.SnapshotDiffPath,
      'missing snapshot baseline' + LineEnding +
      'fixture: ' + AFixturePath + LineEnding +
      'expected: ' + AExecution.SnapshotPath + LineEnding +
      '--- actual ---' + LineEnding +
      AActualText + LineEnding
    );
    AExecution.Passed := False;
    if AExecution.FailureKind = '' then
      AExecution.FailureKind := 'missing-snapshot';
    Exit;
  end;

  ExpectedText := NormalizeSnapshotText(ReadTextFile(AExecution.SnapshotPath));
  if ExpectedText <> NormalizeSnapshotText(AActualText) then
  begin
    AExecution.SnapshotStatus := 'unstable';
    WriteTextFile(
      AExecution.SnapshotDiffPath,
      BuildSnapshotMismatchText(
        AExecution.SnapshotPath,
        ExpectedText,
        NormalizeSnapshotText(AActualText)
      )
    );
    AExecution.Passed := False;
    if AExecution.FailureKind = '' then
      AExecution.FailureKind := 'snapshot-mismatch';
    Exit;
  end;

  AExecution.SnapshotStatus := 'ready';
  ClearSnapshotDiff(AExecution.SnapshotDiffPath);
end;

procedure PrintSnapshotEntry(
  const AGroup: THarnessGroup;
  const AExecution: TFixtureExecution
);
begin
  WriteLn(
    'snapshot-entry=',
    SnapshotKeyForFixture(
      HARNESS_GROUPS[AGroup].Name,
      HARNESS_GROUPS[AGroup].Directory,
      AExecution.FixturePath
    ),
    ' fixture=',
    AExecution.FixturePath,
    ' status=',
    AExecution.SnapshotStatus,
    ' path=',
    AExecution.SnapshotPath,
    ' diff=',
    AExecution.SnapshotDiffPath
  );
end;

procedure PrintFixtureResult(const AExecution: TFixtureExecution);
begin
  Write(
    'fixture-result=',
    AExecution.FixturePath,
    ' tool=',
    AExecution.ToolName,
    ' executed=1',
    ' exit-code=',
    AExecution.ExitCode,
    ' result=',
    AExecution.ResultValue
  );
  if AExecution.FailureKind <> '' then
    Write(' failure-kind=', AExecution.FailureKind);
  if AExecution.ArtifactPath <> '' then
    Write(' artifact=', AExecution.ArtifactPath);
  if AExecution.OutputPath <> '' then
    Write(' output=', AExecution.OutputPath);
  if AExecution.RunOutputPath <> '' then
    Write(' run-output=', AExecution.RunOutputPath);
  if AExecution.SnapshotStatus <> '' then
    Write(' snapshot=', AExecution.SnapshotStatus);
  WriteLn;
end;

procedure InitGroupRunSummary(var ASummary: TGroupRunSummary);
begin
  ASummary.FixtureCount := 0;
  ASummary.ExecutedCount := 0;
  ASummary.PassedCount := 0;
  ASummary.FailedCount := 0;
  ASummary.SnapshotCount := 0;
  ASummary.MissingSnapshotCount := 0;
  ASummary.UnstableSnapshotCount := 0;
  ASummary.SnapshotStatus := 'none';
  ASummary.StatusValue := 'deferred';
  ASummary.ResultValue := 'deferred';
  ASummary.HumanSummary := '';
end;

procedure FinalizeGroupRunSummary(
  const AGroup: THarnessGroup;
  var ASummary: TGroupRunSummary
);
begin
  if GroupUsesDiagnosticsSnapshot(AGroup) then
  begin
    if ASummary.MissingSnapshotCount > 0 then
      ASummary.SnapshotStatus := 'missing'
    else if ASummary.UnstableSnapshotCount > 0 then
      ASummary.SnapshotStatus := 'unstable'
    else
      ASummary.SnapshotStatus := 'ready';
  end;

  if ASummary.FixtureCount = 0 then
  begin
    ASummary.StatusValue := 'skeleton';
    ASummary.ResultValue := 'missing-fixtures';
    ASummary.HumanSummary :=
      'group ' + HARNESS_GROUPS[AGroup].Name + ' missing fixtures';
    Exit;
  end;

  if ASummary.MissingSnapshotCount > 0 then
  begin
    ASummary.StatusValue := 'snapshot-missing';
    ASummary.ResultValue := 'missing-snapshots';
    ASummary.HumanSummary :=
      'group ' + HARNESS_GROUPS[AGroup].Name + ' missing snapshot baselines';
    Exit;
  end;

  if ASummary.UnstableSnapshotCount > 0 then
  begin
    ASummary.StatusValue := 'snapshot-unstable';
    ASummary.ResultValue := 'unstable-snapshots';
    ASummary.HumanSummary :=
      'group ' + HARNESS_GROUPS[AGroup].Name + ' snapshot mismatch detected';
    Exit;
  end;

  if ASummary.FailedCount > 0 then
  begin
    ASummary.StatusValue := 'failure';
    ASummary.ResultValue := 'fixture-failures';
    ASummary.HumanSummary :=
      'group ' + HARNESS_GROUPS[AGroup].Name + ' has failing fixtures';
    Exit;
  end;

  ASummary.StatusValue := 'ready';
  ASummary.ResultValue := 'pass';
  ASummary.HumanSummary := 'group ' + HARNESS_GROUPS[AGroup].Name + ' passed';
end;

procedure ExecuteStage0BuildRunFixture(
  const AGroup: THarnessGroup;
  const AFixturePath: string;
  const ASupportsFailSuffix: Boolean;
  var AExecution: TFixtureExecution
);
var
  Params: TStringList;
  BuildOutput: string;
  RunOutput: string;
  ArtifactPath: string;
begin
  AExecution.ToolName := 'stage0-build-run';
  ClearStage0FixtureArtifacts(AGroup, AFixturePath);

  { Build step }
  Params := TStringList.Create;
  try
    Params.Add('build');
    Params.Add(AFixturePath);
    Params.Add('--target');
    Params.Add(BaselineTargetName);
    Params.Add('--workspace');
    Params.Add(WorkspaceRootPath);
    Params.Add('--out-dir');
    Params.Add(FixtureBinaryDirectory(AGroup, AFixturePath));
    SafeRunProcessCapture(
      Stage0ExecutablePath, '', Params, BuildOutput,
      AExecution.ExitCode, 'fixture-exec-failed', AExecution
    );
  finally
    Params.Free;
  end;

  WriteTextFile(AExecution.OutputPath, BuildOutput);
  ArtifactPath := ExtractProjectionValue(BuildOutput, 'artifact=');
  if ArtifactPath = '' then
    ArtifactPath := FixtureBinaryPath(AGroup, AFixturePath);
  AExecution.ArtifactPath := ArtifactPath;

  if (AExecution.FailureKind = '') and (AExecution.ExitCode <> 0) then
    AExecution.FailureKind := ExtractProjectionValue(
      BuildOutput, 'failure-kind='
    );
  if AExecution.FailureKind = '' then
    AExecution.FailureKind := 'unexpected-build-failure';

  if AExecution.ExitCode <> 0 then
    Exit;

  { Run step }
  AExecution.RunOutputPath := FixtureRunOutputPath(AGroup, AFixturePath);
  SafeRunTargetArtifactCapture(
    ArtifactPath, RunOutput, AExecution.ExitCode, AExecution
  );
  WriteTextFile(AExecution.RunOutputPath, RunOutput);

  if ASupportsFailSuffix and
     EndsWithText(LowerCase(ExtractFileName(AFixturePath)), '_fail.pas') then
  begin
    { _fail.pas: runtime failure is expected → pass; runtime success → fail }
    if AExecution.ExitCode = 0 then
    begin
      AExecution.FailureKind := 'unexpected-semantic-pass';
      AExecution.ResultValue := 'failure';
    end
    else
    begin
      AExecution.ResultValue := 'pass';
      AExecution.FailureKind := '';
      AExecution.Passed := True;
    end;
  end
  else if AExecution.ExitCode = 0 then
  begin
    AExecution.ResultValue := 'pass';
    AExecution.FailureKind := '';
    AExecution.Passed := True;
  end
  else
  begin
    AExecution.ResultValue := 'failure';
    if AExecution.FailureKind = '' then
      AExecution.FailureKind := 'fixture-runtime-failed';
  end;

  ClearStage0FixtureArtifacts(AGroup, AFixturePath);
end;

procedure ApplyCompilerBuildResult(
  AExitCode: LongInt;
  var AExecution: TFixtureExecution
);
begin
  if AExitCode = 0 then
  begin
    AExecution.FailureKind := 'unexpected-build-success';
    AExecution.ResultValue := 'failure';
  end
  else
  begin
    AExecution.FailureKind := '';
    AExecution.ResultValue := 'pass';
    AExecution.Passed := True;
  end;
end;

procedure ExecuteCompilerBuildValidateFixture(
  const AGroup: THarnessGroup;
  const AFixturePath: string;
  const ACompilerExecutable: string;
  const AToolName: string;
  var AExecution: TFixtureExecution
);
var
  Params: TStringList;
  BuildOutput: string;
begin
  AExecution.ToolName := AToolName;
  if ACompilerExecutable = Stage0ExecutablePath then
    ClearStage0FixtureArtifacts(AGroup, AFixturePath);

  Params := TStringList.Create;
  try
    if ACompilerExecutable = HostCompilerExecutable then
    begin
      Params.Add('-FE' + FixtureTempDirectory(AGroup, AFixturePath));
      Params.Add('-FU' + FixtureTempDirectory(AGroup, AFixturePath));
    end
    else
    begin
      Params.Add('build');
      Params.Add(AFixturePath);
      Params.Add('--target');
      Params.Add(BaselineTargetName);
      Params.Add('--workspace');
      Params.Add(WorkspaceRootPath);
      Params.Add('--out-dir');
      Params.Add(FixtureBinaryDirectory(AGroup, AFixturePath));
    end;
    if ACompilerExecutable = HostCompilerExecutable then
      Params.Add(AFixturePath);
    SafeRunProcessCapture(
      ACompilerExecutable, '', Params, BuildOutput,
      AExecution.ExitCode, 'fixture-exec-failed', AExecution
    );
  finally
    Params.Free;
  end;

  WriteTextFile(AExecution.OutputPath, BuildOutput);
  if ACompilerExecutable = Stage0ExecutablePath then
    ClearStage0FixtureArtifacts(AGroup, AFixturePath);

  ApplyCompilerBuildResult(
    AExecution.ExitCode, AExecution
  );

  ApplySnapshotValidation(
    AGroup, AFixturePath,
    BuildSnapshotActualText(AGroup, AFixturePath, BuildOutput),
    AExecution
  );
end;

procedure ExecuteHostFpcBuildRunFixture(
  const AGroup: THarnessGroup;
  const AFixturePath: string;
  var AExecution: TFixtureExecution
);
var
  Params: TStringList;
  BuildOutput: string;
  RunOutput: string;
  TempBinaryPath: string;
begin
  AExecution.ToolName := 'host-fpc-build-run';
  TempBinaryPath := FixtureBinaryPath(AGroup, AFixturePath);

  { Build step }
  Params := TStringList.Create;
  try
    Params.Add('-FE' + FixtureBinaryDirectory(AGroup, AFixturePath));
    Params.Add('-FU' + FixtureTempDirectory(AGroup, AFixturePath));
    if AGroup = hgToolchain then
    begin
      Params.Add('-Furtl/core/base');
      Params.Add('-Furtl/core/text');
      Params.Add('-Fucompiler/sema');
      Params.Add('-Fucompiler/backend');
      Params.Add('-Fucompiler/diagnostics');
      Params.Add('-Fucompiler/frontend');
      Params.Add('-Fucompiler/ir');
      Params.Add('-Fucompiler/syntax');
      Params.Add('-Fucompiler/toolchain');
      Params.Add('-Fucompiler/targets');
      Params.Add('-Fucompiler/src');
      Params.Add('-Fucompiler/lower');
      Params.Add('-Futools/stage0');
      Params.Add('-Fucore/src');
      Params.Add('-Ficore/src');
    end
    else if AGroup = hgRTL then
    begin
      Params.Add('-Furtl/core/base');
      Params.Add('-Furtl/core/text');
      Params.Add('-Fucore/src');
      Params.Add('-Ficore/src');
    end
    else if AGroup = hgCRT then
    begin
      Params.Add('-Fucore/src');
      Params.Add('-Ficore/src');
    end;
    Params.Add(AFixturePath);
    SafeRunProcessCapture(
      HostCompilerExecutable, '', Params, BuildOutput,
      AExecution.ExitCode, 'fixture-exec-failed', AExecution
    );
  finally
    Params.Free;
  end;

  WriteTextFile(AExecution.OutputPath, BuildOutput);
  AExecution.ArtifactPath := TempBinaryPath;
  if AExecution.ExitCode <> 0 then
  begin
    AExecution.ResultValue := 'failure';
    if AExecution.FailureKind = '' then
      AExecution.FailureKind := 'host-compile-failed';
    Exit;
  end;

  { Run step }
  AExecution.RunOutputPath := FixtureRunOutputPath(AGroup, AFixturePath);
  SafeRunTargetArtifactCapture(
    TempBinaryPath, RunOutput, AExecution.ExitCode, AExecution
  );
  WriteTextFile(AExecution.RunOutputPath, RunOutput);
  if AExecution.ExitCode = 0 then
  begin
    AExecution.ResultValue := 'pass';
    AExecution.FailureKind := '';
    AExecution.Passed := True;
  end
  else
  begin
    AExecution.ResultValue := 'failure';
    if AExecution.FailureKind = '' then
      AExecution.FailureKind := 'fixture-runtime-failed';
  end;
end;

function ExecuteFixture(
  const AGroup: THarnessGroup;
  const AFixturePath: string;
  out AExecution: TFixtureExecution
): Boolean;
begin
  AExecution.FixturePath := AFixturePath;
  AExecution.ToolName := '';
  AExecution.OutputPath := FixtureOutputPath(AGroup, AFixturePath);
  AExecution.RunOutputPath := '';
  AExecution.ArtifactPath := '';
  AExecution.SnapshotPath := '';
  AExecution.SnapshotDiffPath := '';
  AExecution.SnapshotStatus := 'none';
  AExecution.FailureKind := '';
  AExecution.ResultValue := 'failure';
  AExecution.ExitCode := 0;
  AExecution.Executed := True;
  AExecution.Passed := False;

  case HARNESS_GROUPS[AGroup].CompilerMode of
    cmStage0BuildRun:
      ExecuteStage0BuildRunFixture(AGroup, AFixturePath, AGroup = hgSemantic, AExecution);
    cmStage0BuildValidate:
      ExecuteCompilerBuildValidateFixture(
        AGroup, AFixturePath, Stage0ExecutablePath, 'stage0-build', AExecution);
    cmHostFpcBuildValidate:
      ExecuteCompilerBuildValidateFixture(
        AGroup, AFixturePath, HostCompilerExecutable, 'host-fpc-diagnostic', AExecution);
    cmHostFpcBuildRun:
      ExecuteHostFpcBuildRunFixture(AGroup, AFixturePath, AExecution);
  end;

  Result := AExecution.Passed;
end;

procedure ExecuteGroupFixtures(
  const AGroup: THarnessGroup;
  const AFixturePaths: TStrings;
  const APrintDetails: Boolean;
  out ASummary: TGroupRunSummary
);
var
  Index: Integer;
  Execution: TFixtureExecution;
begin
  InitGroupRunSummary(ASummary);
  ASummary.FixtureCount := AFixturePaths.Count;
  if GroupUsesDiagnosticsSnapshot(AGroup) then
    ASummary.SnapshotCount := AFixturePaths.Count;

  for Index := 0 to AFixturePaths.Count - 1 do
  begin
    ExecuteFixture(AGroup, AFixturePaths[Index], Execution);
    Inc(ASummary.ExecutedCount);
    if Execution.Passed then
      Inc(ASummary.PassedCount)
    else
      Inc(ASummary.FailedCount);

    if GroupUsesDiagnosticsSnapshot(AGroup) then
    begin
      if Execution.SnapshotStatus = 'missing' then
        Inc(ASummary.MissingSnapshotCount)
      else if Execution.SnapshotStatus = 'unstable' then
        Inc(ASummary.UnstableSnapshotCount);
      if APrintDetails then
        PrintSnapshotEntry(AGroup, Execution);
    end;

    if APrintDetails then
      PrintFixtureResult(Execution);
  end;

  FinalizeGroupRunSummary(AGroup, ASummary);
end;

procedure PrintFailureProjection(
  const ASelector: string;
  const ARequestedFilter: string;
  const AFailureKind: string;
  const AHumanSummary: string;
  const AMessage: string
);
var
  ResultFields: string;
begin
  ResultFields := BuildFailureResultFields(
    ASelector,
    ARequestedFilter,
    AFailureKind
  );
  WriteLn(StdErr, 'command=test');
  WriteLn(StdErr, 'selector=', ASelector);
  WriteLn(StdErr, 'target=', BaselineTargetName);
  if ARequestedFilter <> '' then
    WriteLn(StdErr, 'requested-filter=', ARequestedFilter);
  WriteLn(StdErr, 'status=failure');
  WriteLn(StdErr, 'result=failure');
  WriteLn(StdErr, 'failure-kind=', AFailureKind);
  WriteLn(StdErr, 'command-outcome=failure');
  PrintCommandEnvelope(ExitFailureCode, ResultFields, AHumanSummary, True);
  WriteLn(StdErr, 'human-summary=', AHumanSummary);
  WriteLn(StdErr, AMessage);
end;

procedure PrintOutcomeBlock(
  ASucceeded: Boolean;
  const AResultFields: string;
  const AHumanSummary: string;
  AUseStdErr: Boolean
);
var
  ExitCode: LongInt;
begin
  if ASucceeded then
  begin
    WriteLn('command-outcome=success');
    ExitCode := ExitSuccessCode;
  end
  else
  begin
    WriteLn('command-outcome=failure');
    ExitCode := ExitFailureCode;
  end;
  PrintCommandEnvelope(ExitCode, AResultFields, AHumanSummary, AUseStdErr);
end;

function RunGroup(const AGroup: THarnessGroup): Boolean;
var
  FixturePaths: TStringList;
  Summary: TGroupRunSummary;
  ResultFields: string;
begin
  FixturePaths := TStringList.Create;
  try
    CollectGroupFixtures(AGroup, FixturePaths);
    WriteLn('mode=group');
    WriteLn('command=test');
    WriteLn('selector=group');
    WriteLn('target=', BaselineTargetName);
    WriteLn('group=', HARNESS_GROUPS[AGroup].Name);
    WriteLn('path=', HARNESS_GROUPS[AGroup].Directory);
    WriteLn('fixtures=', FixturePaths.Count);
    WriteLn('expectation=', HARNESS_GROUPS[AGroup].Expectation);
    if GroupUsesDiagnosticsSnapshot(AGroup) then
    begin
      WriteLn('snapshot-root=', SnapshotRoot);
      WriteLn('snapshot-count=', FixturePaths.Count);
    end;

    ExecuteGroupFixtures(AGroup, FixturePaths, True, Summary);

    WriteLn('executed-fixture-count=', Summary.ExecutedCount);
    WriteLn('passed-fixture-count=', Summary.PassedCount);
    WriteLn('failed-fixture-count=', Summary.FailedCount);
    if GroupUsesDiagnosticsSnapshot(AGroup) then
      WriteLn('snapshot-status=', Summary.SnapshotStatus);
    WriteLn('status=', Summary.StatusValue);
    WriteLn('result=', Summary.ResultValue);
    ResultFields := BuildGroupResultFields(
      AGroup,
      Summary.FixtureCount,
      Summary.ExecutedCount,
      Summary.FailedCount,
      Summary.StatusValue,
      Summary.ResultValue,
      Summary.SnapshotCount,
      Summary.SnapshotStatus
    );
    Result := Summary.ResultValue = 'pass';
    PrintOutcomeBlock(Result, ResultFields, Summary.HumanSummary, False);
    WriteLn('human-summary=', Summary.HumanSummary);
    if not Result then
      WriteLn(StdErr, 'group-failed: ', HARNESS_GROUPS[AGroup].Name);
  finally
    FixturePaths.Free;
  end;
end;

function RunSmoke: Boolean;
var
  Group: THarnessGroup;
  FixturePaths: TStringList;
  Summary: TGroupRunSummary;
  MissingFixtureCount: SizeInt;
  FailedGroupCount: SizeInt;
  MissingSnapshotCount: SizeInt;
  UnstableSnapshotCount: SizeInt;
  ResultFields: string;
  StatusValue: string;
  ResultValue: string;
  HumanSummary: string;
  SnapshotFieldValue: string;
begin
  MissingFixtureCount := 0;
  FailedGroupCount := 0;
  MissingSnapshotCount := 0;
  UnstableSnapshotCount := 0;

  WriteLn('mode=smoke');
  WriteLn('command=test');
  WriteLn('selector=smoke');
  WriteLn('target=', BaselineTargetName);

  FixturePaths := TStringList.Create;
  try
    for Group := Low(THarnessGroup) to High(THarnessGroup) do
    begin
      FixturePaths.Clear;
      CollectGroupFixtures(Group, FixturePaths);
      ExecuteGroupFixtures(Group, FixturePaths, False, Summary);
      if Summary.FixtureCount = 0 then
        Inc(MissingFixtureCount);
      if Summary.ResultValue <> 'pass' then
        Inc(FailedGroupCount);
      Inc(MissingSnapshotCount, Summary.MissingSnapshotCount);
      Inc(UnstableSnapshotCount, Summary.UnstableSnapshotCount);

      if GroupUsesDiagnosticsSnapshot(Group) then
        SnapshotFieldValue := Summary.SnapshotStatus
      else
        SnapshotFieldValue := 'none';
      WriteLn(
        'smoke-group=', HARNESS_GROUPS[Group].Name,
        ' result=', Summary.ResultValue,
        ' expectation=', HARNESS_GROUPS[Group].Expectation,
        ' fixtures=', Summary.FixtureCount,
        ' executed=', Summary.ExecutedCount,
        ' snapshot=', SnapshotFieldValue
      );
    end;
  finally
    FixturePaths.Free;
  end;

  if MissingFixtureCount > 0 then
  begin
    StatusValue := 'not-ready';
    ResultValue := 'missing-fixtures';
    HumanSummary := 'smoke baseline missing fixtures';
  end
  else if MissingSnapshotCount > 0 then
  begin
    StatusValue := 'not-ready';
    ResultValue := 'missing-snapshots';
    HumanSummary := 'smoke baseline missing snapshot baselines';
  end
  else if UnstableSnapshotCount > 0 then
  begin
    StatusValue := 'not-ready';
    ResultValue := 'unstable-snapshots';
    HumanSummary := 'smoke baseline snapshot mismatch detected';
  end
  else if FailedGroupCount > 0 then
  begin
    StatusValue := 'failure';
    ResultValue := 'group-failures';
    HumanSummary := 'smoke run detected failing groups';
  end
  else
  begin
    StatusValue := 'ready';
    ResultValue := 'pass';
    HumanSummary := 'smoke baseline ready';
  end;

  WriteLn('status=', StatusValue);
  WriteLn('result=', ResultValue);
  WriteLn('smoke-status=', StatusValue);
  WriteLn('smoke-result=', ResultValue);
  ResultFields := BuildSmokeResultFields(
    StatusValue,
    ResultValue,
    FailedGroupCount,
    MissingFixtureCount,
    MissingSnapshotCount,
    UnstableSnapshotCount
  );
  Result := ResultValue = 'pass';
  PrintOutcomeBlock(Result, ResultFields, HumanSummary, False);
  WriteLn('human-summary=', HumanSummary);
  if not Result then
  begin
    if ResultValue = 'missing-fixtures' then
      WriteLn(StdErr, 'smoke-not-ready: expected seeded fixtures for all groups')
    else if ResultValue = 'missing-snapshots' then
      WriteLn(StdErr, 'smoke-not-ready: expected snapshot baselines for snapshot-bearing groups')
    else if ResultValue = 'unstable-snapshots' then
      WriteLn(StdErr, 'smoke-not-ready: snapshot baselines diverged from execution results')
    else
      WriteLn(StdErr, 'smoke-failed: one or more groups did not pass');
  end;
end;

procedure RunFilter(const ASelector: string);
var
  Group: THarnessGroup;
begin
  if ASelector = 'smoke' then
  begin
    if RunSmoke then
      Halt(ExitSuccessCode)
    else
      Halt(ExitFailureCode);
  end;

  if TryFindGroup(ASelector, Group) then
  begin
    if RunGroup(Group) then
      Halt(ExitSuccessCode)
    else
      Halt(ExitFailureCode);
  end;

  PrintFailureProjection(
    'group',
    ASelector,
    'unknown-group',
    'unknown group: ' + ASelector,
    'unknown-group: ' + ASelector
  );
  Halt(ExitFailureCode);
end;

begin
  if ParamCount = 1 then
  begin
    if ParamStr(1) = '--list-groups' then
    begin
      PrintKnownGroups;
      Halt(ExitSuccessCode);
    end;

    if (ParamStr(1) = '--help') or (ParamStr(1) = '-h') then
    begin
      PrintUsage;
      Halt(ExitSuccessCode);
    end;
  end;

  if ParamCount = 2 then
  begin
    if ParamStr(1) = '--filter' then
      RunFilter(ParamStr(2));
  end;

  PrintFailureProjection(
    'cli',
    '',
    'invalid-arguments',
    'invalid arguments',
    'invalid-arguments'
  );
  PrintUsageError;
  Halt(ExitFailureCode);
end.
