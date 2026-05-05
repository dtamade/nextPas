program nextpas_test_harness_runner;

{$mode objfpc}{$H+}

uses
  Classes, Process, SysUtils, snapshot_support;

type
  THarnessGroup = (
    hgCompilerPass,
    hgCompilerFail,
    hgDiagnostics,
    hgLexer,
    hgParser,
    hgRTL,
    hgCRT,
    hgRegression
  );

const
  ExitSuccessCode = 0;
  ExitFailureCode = 1;
  BaselineTargetName = 'linux-x86_64';
  HarnessTempRoot = '.sisyphus/tmp/harness';
  DefaultStage0Executable = '.sisyphus/tmp/stage0-bootstrap/nextpas';
  HostCompilerExecutable = 'fpc';

  HARNESS_GROUP_NAMES: array[THarnessGroup] of string = (
    'compiler-pass',
    'compiler-fail',
    'diagnostics',
    'lexer',
    'parser',
    'rtl',
    'crt',
    'regression'
  );

  HARNESS_GROUP_DIRECTORIES: array[THarnessGroup] of string = (
    'tests/compiler/pass',
    'tests/compiler/fail',
    'tests/diagnostics',
    'tests/lexer',
    'tests/parser',
    'tests/rtl',
    'tests/crt',
    'tests/regression'
  );

  HARNESS_GROUP_EXPECTATIONS: array[THarnessGroup] of string = (
    'compile-success',
    'expected-compile-failure',
    'diagnostic-snapshot',
    'lexer-tokenization',
    'parse-success',
    'rtl-smoke',
    'crt-smoke',
    'regression-guard'
  );

type
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

function GroupUsesDiagnosticsSnapshot(const AGroup: THarnessGroup): Boolean; forward;

function JsonEscape(const Value: string): string;
var
  Index: SizeInt;
begin
  Result := '';
  for Index := 1 to Length(Value) do
    case Value[Index] of
      '\':
        Result := Result + '\\';
      '"':
        Result := Result + '\"';
      #10:
        Result := Result + '\n';
      #13:
        Result := Result + '\r';
      #9:
        Result := Result + '\t';
    else
      Result := Result + Value[Index];
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
  AppendJsonStringField(Result, 'group', HARNESS_GROUP_NAMES[AGroup]);
  AppendJsonStringField(Result, 'path', HARNESS_GROUP_DIRECTORIES[AGroup]);
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
  AppendJsonStringField(Result, 'expectation', HARNESS_GROUP_EXPECTATIONS[AGroup]);
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
begin
  WriteLn('Usage:');
  WriteLn('  ./tests/run_all_tests.sh --list-groups');
  WriteLn('  ./tests/run_all_tests.sh --filter <group>');
  WriteLn;
  WriteLn('Supported groups:');
  WriteLn('  compiler-pass');
  WriteLn('  compiler-fail');
  WriteLn('  diagnostics');
  WriteLn('  rtl');
  WriteLn('  crt');
  WriteLn('  regression');
  WriteLn;
  WriteLn('Special filter:');
  WriteLn('  smoke');
end;

procedure PrintUsageError;
begin
  WriteLn(StdErr, 'Usage:');
  WriteLn(StdErr, '  ./tests/run_all_tests.sh --list-groups');
  WriteLn(StdErr, '  ./tests/run_all_tests.sh --filter <group>');
  WriteLn(StdErr);
  WriteLn(StdErr, 'Supported groups:');
  WriteLn(StdErr, '  compiler-pass');
  WriteLn(StdErr, '  compiler-fail');
  WriteLn(StdErr, '  diagnostics');
  WriteLn(StdErr, '  rtl');
  WriteLn(StdErr, '  crt');
  WriteLn(StdErr, '  regression');
  WriteLn(StdErr);
  WriteLn(StdErr, 'Special filter:');
  WriteLn(StdErr, '  smoke');
end;

function TryFindGroup(const AName: string; out AGroup: THarnessGroup): Boolean;
var
  Group: THarnessGroup;
begin
  for Group := Low(THarnessGroup) to High(THarnessGroup) do
    if HARNESS_GROUP_NAMES[Group] = AName then
    begin
      AGroup := Group;
      Exit(True);
    end;

  Result := False;
end;

function IsSmokeSelector(const AName: string): Boolean;
begin
  Result := AName = 'smoke';
end;

procedure PrintKnownGroups;
var
  Group: THarnessGroup;
begin
  for Group := Low(THarnessGroup) to High(THarnessGroup) do
    WriteLn(HARNESS_GROUP_NAMES[Group]);
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

function RelativeFixturePath(const AGroupRoot: string; const AFixturePath: string): string;
var
  ExpandedGroupRoot: string;
  ExpandedFixturePath: string;
begin
  ExpandedGroupRoot := IncludeTrailingPathDelimiter(ExpandFileName(AGroupRoot));
  ExpandedFixturePath := ExpandFileName(AFixturePath);
  if Pos(ExpandedGroupRoot, ExpandedFixturePath) = 1 then
    Result := Copy(
      ExpandedFixturePath,
      Length(ExpandedGroupRoot) + 1,
      Length(ExpandedFixturePath) - Length(ExpandedGroupRoot)
    )
  else
    Result := ExtractFileName(AFixturePath);
end;

function FixtureToken(
  const AGroup: THarnessGroup;
  const AFixturePath: string
): string;
var
  RelativeName: string;
begin
  RelativeName := ChangeFileExt(
    RelativeFixturePath(HARNESS_GROUP_DIRECTORIES[AGroup], AFixturePath),
    ''
  );
  RelativeName := StringReplace(
    RelativeName,
    PathDelim,
    '-',
    [rfReplaceAll]
  );
  Result := HARNESS_GROUP_NAMES[AGroup] + '-' + RelativeName;
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
begin
  if CompareText(ExtractFileExt(AFixturePath), '.pas') <> 0 then
    Exit(False);

  FileName := LowerCase(ExtractFileName(AFixturePath));
  case AGroup of
    hgCompilerPass:
      Result := EndsWithText(FileName, '_pass.pas');
    hgCompilerFail:
      Result := EndsWithText(FileName, '_fail.pas');
    hgDiagnostics:
      Result := True;
    hgRTL, hgCRT:
      Result := EndsWithText(FileName, '_smoke.pas');
    hgLexer:
      Result := EndsWithText(FileName, '_pass.pas');
    hgParser:
      Result := EndsWithText(FileName, '_pass.pas');
    hgRegression:
      Result := EndsWithText(FileName, '_regression.pas');
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
  CollectFilesRecursive(AGroup, HARNESS_GROUP_DIRECTORIES[AGroup], AFiles);
  if AFiles is TStringList then
    TStringList(AFiles).Sort;
end;

function GroupUsesDiagnosticsSnapshot(const AGroup: THarnessGroup): Boolean;
begin
  Result := GroupUsesSnapshot(HARNESS_GROUP_NAMES[AGroup]);
end;

function RunProcessCapture(
  const AExecutable: string;
  const AWorkingDirectory: string;
  const AParameters: TStrings;
  out AOutput: string
): LongInt;
var
  Proc: TProcess;
  Buffer: array[0..4095] of Byte;
  BytesRead: LongInt;
  Chunk: RawByteString;
  Index: Integer;
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
        Sleep(10);
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

  if Pos('status=success', AOutput) > 0 then
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
    HARNESS_GROUP_NAMES[AGroup],
    HARNESS_GROUP_DIRECTORIES[AGroup],
    AFixturePath
  );
  AExecution.SnapshotDiffPath := SnapshotDiffPathForFixture(
    HARNESS_GROUP_NAMES[AGroup],
    HARNESS_GROUP_DIRECTORIES[AGroup],
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
      HARNESS_GROUP_NAMES[AGroup],
      HARNESS_GROUP_DIRECTORIES[AGroup],
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
      'group ' + HARNESS_GROUP_NAMES[AGroup] + ' missing fixtures';
    Exit;
  end;

  if ASummary.MissingSnapshotCount > 0 then
  begin
    ASummary.StatusValue := 'snapshot-missing';
    ASummary.ResultValue := 'missing-snapshots';
    ASummary.HumanSummary :=
      'group ' + HARNESS_GROUP_NAMES[AGroup] + ' missing snapshot baselines';
    Exit;
  end;

  if ASummary.UnstableSnapshotCount > 0 then
  begin
    ASummary.StatusValue := 'snapshot-unstable';
    ASummary.ResultValue := 'unstable-snapshots';
    ASummary.HumanSummary :=
      'group ' + HARNESS_GROUP_NAMES[AGroup] + ' snapshot mismatch detected';
    Exit;
  end;

  if ASummary.FailedCount > 0 then
  begin
    ASummary.StatusValue := 'failure';
    ASummary.ResultValue := 'fixture-failures';
    ASummary.HumanSummary :=
      'group ' + HARNESS_GROUP_NAMES[AGroup] + ' has failing fixtures';
    Exit;
  end;

  ASummary.StatusValue := 'ready';
  ASummary.ResultValue := 'pass';
  ASummary.HumanSummary := 'group ' + HARNESS_GROUP_NAMES[AGroup] + ' passed';
end;

function ExecuteFixture(
  const AGroup: THarnessGroup;
  const AFixturePath: string;
  out AExecution: TFixtureExecution
): Boolean;
var
  Params: TStringList;
  BuildOutput: string;
  RunOutput: string;
  ArtifactPath: string;
  TempBinaryPath: string;
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

  Params := TStringList.Create;
  try
    case AGroup of
      hgCompilerPass:
        begin
            AExecution.ToolName := 'stage0-build-run';
          ClearStage0FixtureArtifacts(AGroup, AFixturePath);
          Params.Add('build');
          Params.Add(AFixturePath);
          Params.Add('--target');
          Params.Add(BaselineTargetName);
          Params.Add('--workspace');
          Params.Add(WorkspaceRootPath);
          Params.Add('--out-dir');
          Params.Add(FixtureBinaryDirectory(AGroup, AFixturePath));
          try
            AExecution.ExitCode := RunProcessCapture(
              Stage0ExecutablePath,
              '',
              Params,
              BuildOutput
            );
          except
            on E: Exception do
            begin
              BuildOutput := E.Message + LineEnding;
              AExecution.ExitCode := ExitFailureCode;
              AExecution.FailureKind := 'fixture-exec-failed';
            end;
          end;
          WriteTextFile(AExecution.OutputPath, BuildOutput);
          ArtifactPath := ExtractProjectionValue(BuildOutput, 'artifact=');
          if ArtifactPath = '' then
            ArtifactPath := FixtureBinaryPath(AGroup, AFixturePath);
          AExecution.ArtifactPath := ArtifactPath;

          if (AExecution.FailureKind = '') and (AExecution.ExitCode <> 0) then
            AExecution.FailureKind := ExtractProjectionValue(
              BuildOutput,
              'failure-kind='
            );
          if AExecution.FailureKind = '' then
            AExecution.FailureKind := 'unexpected-build-failure';

          if AExecution.ExitCode = 0 then
          begin
            Params.Clear;
            AExecution.RunOutputPath := FixtureRunOutputPath(AGroup, AFixturePath);
            try
              AExecution.ExitCode := RunProcessCapture(
                ExpandFileName(ArtifactPath),
                '',
                Params,
                RunOutput
              );
            except
              on E: Exception do
              begin
                RunOutput := E.Message + LineEnding;
                AExecution.ExitCode := ExitFailureCode;
                AExecution.FailureKind := 'fixture-runtime-failed';
              end;
            end;
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
          ClearStage0FixtureArtifacts(AGroup, AFixturePath);
        end;

      hgCompilerFail:
        begin
          AExecution.ToolName := 'stage0-build';
          ClearStage0FixtureArtifacts(AGroup, AFixturePath);
          Params.Add('build');
          Params.Add(AFixturePath);
          Params.Add('--target');
          Params.Add(BaselineTargetName);
          Params.Add('--workspace');
          Params.Add(WorkspaceRootPath);
          Params.Add('--out-dir');
          Params.Add(FixtureBinaryDirectory(AGroup, AFixturePath));
          try
            AExecution.ExitCode := RunProcessCapture(
              Stage0ExecutablePath,
              '',
              Params,
              BuildOutput
            );
          except
            on E: Exception do
            begin
              BuildOutput := E.Message + LineEnding;
              AExecution.ExitCode := ExitFailureCode;
              AExecution.FailureKind := 'fixture-exec-failed';
            end;
          end;
          WriteTextFile(AExecution.OutputPath, BuildOutput);
          ClearStage0FixtureArtifacts(AGroup, AFixturePath);
          if AExecution.ExitCode = 0 then
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
          ApplySnapshotValidation(
            AGroup,
            AFixturePath,
            BuildSnapshotActualText(AGroup, AFixturePath, BuildOutput),
            AExecution
          );
        end;

      hgDiagnostics:
        begin
          AExecution.ToolName := 'host-fpc-diagnostic';
          Params.Add('-FE' + FixtureTempDirectory(AGroup, AFixturePath));
          Params.Add('-FU' + FixtureTempDirectory(AGroup, AFixturePath));
          Params.Add(AFixturePath);
          try
            AExecution.ExitCode := RunProcessCapture(
              HostCompilerExecutable,
              '',
              Params,
              BuildOutput
            );
          except
            on E: Exception do
            begin
              BuildOutput := E.Message + LineEnding;
              AExecution.ExitCode := ExitFailureCode;
              AExecution.FailureKind := 'fixture-exec-failed';
            end;
          end;
          WriteTextFile(AExecution.OutputPath, BuildOutput);
          if AExecution.ExitCode = 0 then
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
          ApplySnapshotValidation(
            AGroup,
            AFixturePath,
            BuildSnapshotActualText(AGroup, AFixturePath, BuildOutput),
            AExecution
          );
        end;

      hgLexer:
        begin
          AExecution.ToolName := 'stage0-build-run';
          ClearStage0FixtureArtifacts(AGroup, AFixturePath);
          Params.Add('build');
          Params.Add(AFixturePath);
          Params.Add('--target');
          Params.Add(BaselineTargetName);
          Params.Add('--workspace');
          Params.Add(WorkspaceRootPath);
          Params.Add('--out-dir');
          Params.Add(FixtureBinaryDirectory(AGroup, AFixturePath));
          try
            AExecution.ExitCode := RunProcessCapture(
              Stage0ExecutablePath,
              '',
              Params,
              BuildOutput
            );
          except
            on E: Exception do
            begin
              BuildOutput := E.Message + LineEnding;
              AExecution.ExitCode := ExitFailureCode;
              AExecution.FailureKind := 'fixture-exec-failed';
            end;
          end;
          WriteTextFile(AExecution.OutputPath, BuildOutput);
          ArtifactPath := ExtractProjectionValue(BuildOutput, 'artifact=');
          if ArtifactPath = '' then
            ArtifactPath := FixtureBinaryPath(AGroup, AFixturePath);
          AExecution.ArtifactPath := ArtifactPath;

          if (AExecution.FailureKind = '') and (AExecution.ExitCode <> 0) then
            AExecution.FailureKind := ExtractProjectionValue(
              BuildOutput,
              'failure-kind='
            );
          if AExecution.FailureKind = '' then
            AExecution.FailureKind := 'unexpected-build-failure';

          if AExecution.ExitCode = 0 then
          begin
            Params.Clear;
            AExecution.RunOutputPath := FixtureRunOutputPath(AGroup, AFixturePath);
            try
              AExecution.ExitCode := RunProcessCapture(
                ExpandFileName(ArtifactPath),
                '',
                Params,
                RunOutput
              );
            except
              on E: Exception do
              begin
                RunOutput := E.Message + LineEnding;
                AExecution.ExitCode := ExitFailureCode;
                AExecution.FailureKind := 'fixture-runtime-failed';
              end;
            end;
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
          ClearStage0FixtureArtifacts(AGroup, AFixturePath);
        end;

      hgParser:
        begin
          AExecution.ToolName := 'stage0-build-run';
          ClearStage0FixtureArtifacts(AGroup, AFixturePath);
          Params.Add('build');
          Params.Add(AFixturePath);
          Params.Add('--target');
          Params.Add(BaselineTargetName);
          Params.Add('--workspace');
          Params.Add(WorkspaceRootPath);
          Params.Add('--out-dir');
          Params.Add(FixtureBinaryDirectory(AGroup, AFixturePath));
          try
            AExecution.ExitCode := RunProcessCapture(
              Stage0ExecutablePath,
              '',
              Params,
              BuildOutput
            );
          except
            on E: Exception do
            begin
              BuildOutput := E.Message + LineEnding;
              AExecution.ExitCode := ExitFailureCode;
              AExecution.FailureKind := 'fixture-exec-failed';
            end;
          end;
          WriteTextFile(AExecution.OutputPath, BuildOutput);
          ArtifactPath := ExtractProjectionValue(BuildOutput, 'artifact=');
          if ArtifactPath = '' then
            ArtifactPath := FixtureBinaryPath(AGroup, AFixturePath);
          AExecution.ArtifactPath := ArtifactPath;

          if (AExecution.FailureKind = '') and (AExecution.ExitCode <> 0) then
            AExecution.FailureKind := ExtractProjectionValue(
              BuildOutput,
              'failure-kind='
            );
          if AExecution.FailureKind = '' then
            AExecution.FailureKind := 'unexpected-build-failure';

          if AExecution.ExitCode = 0 then
          begin
            Params.Clear;
            AExecution.RunOutputPath := FixtureRunOutputPath(AGroup, AFixturePath);
            try
              AExecution.ExitCode := RunProcessCapture(
                ExpandFileName(ArtifactPath),
                '',
                Params,
                RunOutput
              );
            except
              on E: Exception do
              begin
                RunOutput := E.Message + LineEnding;
                AExecution.ExitCode := ExitFailureCode;
                AExecution.FailureKind := 'fixture-runtime-failed';
              end;
            end;
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
          ClearStage0FixtureArtifacts(AGroup, AFixturePath);
        end;

      hgRTL, hgCRT, hgRegression:
        begin
          AExecution.ToolName := 'host-fpc-build-run';
          TempBinaryPath := FixtureBinaryPath(AGroup, AFixturePath);
          Params.Add('-FE' + FixtureBinaryDirectory(AGroup, AFixturePath));
          Params.Add('-FU' + FixtureTempDirectory(AGroup, AFixturePath));
          if AGroup = hgRTL then
          begin
            Params.Add('-Furtl/core/base');
            Params.Add('-Furtl/core/text');
          end;
          Params.Add(AFixturePath);
          try
            AExecution.ExitCode := RunProcessCapture(
              HostCompilerExecutable,
              '',
              Params,
              BuildOutput
            );
          except
            on E: Exception do
            begin
              BuildOutput := E.Message + LineEnding;
              AExecution.ExitCode := ExitFailureCode;
              AExecution.FailureKind := 'fixture-exec-failed';
            end;
          end;
          WriteTextFile(AExecution.OutputPath, BuildOutput);
          AExecution.ArtifactPath := TempBinaryPath;
          if AExecution.ExitCode <> 0 then
          begin
            AExecution.ResultValue := 'failure';
            if AExecution.FailureKind = '' then
              AExecution.FailureKind := 'host-compile-failed';
          end
          else
          begin
            Params.Clear;
            AExecution.RunOutputPath := FixtureRunOutputPath(AGroup, AFixturePath);
            try
              AExecution.ExitCode := RunProcessCapture(
                ExpandFileName(TempBinaryPath),
                '',
                Params,
                RunOutput
              );
            except
              on E: Exception do
              begin
                RunOutput := E.Message + LineEnding;
                AExecution.ExitCode := ExitFailureCode;
                AExecution.FailureKind := 'fixture-runtime-failed';
              end;
            end;
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
        end;
    end;
  finally
    Params.Free;
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
    WriteLn('group=', HARNESS_GROUP_NAMES[AGroup]);
    WriteLn('path=', HARNESS_GROUP_DIRECTORIES[AGroup]);
    WriteLn('fixtures=', FixturePaths.Count);
    WriteLn('expectation=', HARNESS_GROUP_EXPECTATIONS[AGroup]);
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
    if Result then
      WriteLn('command-outcome=success')
    else
      WriteLn('command-outcome=failure');
    if Result then
      PrintCommandEnvelope(
        ExitSuccessCode,
        ResultFields,
        Summary.HumanSummary,
        False
      )
    else
      PrintCommandEnvelope(
        ExitFailureCode,
        ResultFields,
        Summary.HumanSummary,
        False
      );
    WriteLn('human-summary=', Summary.HumanSummary);
    if not Result then
      WriteLn(StdErr, 'group-failed: ', HARNESS_GROUP_NAMES[AGroup]);
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
      begin
        WriteLn(
          'smoke-group=', HARNESS_GROUP_NAMES[Group],
          ' result=', Summary.ResultValue,
          ' expectation=', HARNESS_GROUP_EXPECTATIONS[Group],
          ' fixtures=', Summary.FixtureCount,
          ' executed=', Summary.ExecutedCount,
          ' snapshot=', Summary.SnapshotStatus
        );
      end
      else
        WriteLn(
          'smoke-group=', HARNESS_GROUP_NAMES[Group],
          ' result=', Summary.ResultValue,
          ' expectation=', HARNESS_GROUP_EXPECTATIONS[Group],
          ' fixtures=', Summary.FixtureCount,
          ' executed=', Summary.ExecutedCount,
          ' snapshot=none'
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
  if Result then
    WriteLn('command-outcome=success')
  else
    WriteLn('command-outcome=failure');
  if Result then
    PrintCommandEnvelope(
      ExitSuccessCode,
      ResultFields,
      HumanSummary,
      False
    )
  else
    PrintCommandEnvelope(
      ExitFailureCode,
      ResultFields,
      HumanSummary,
      False
    );
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
  if IsSmokeSelector(ASelector) then
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
