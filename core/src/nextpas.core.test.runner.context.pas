{ nextpas.core.test.runner.context — TTestContext + TTestResultAppender (subtest execution)
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.output }

unit nextpas.core.test.runner.context;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.test.base,
  nextpas.core.test.config,
  nextpas.core.test.output;

{ ── Subtest result callback type ───────────────────────────────────────────── }

type
  TOnSubtestResult = procedure(const AResult: TTestResult) of object;

{ ── TTestResultAppender (for subtest result collection) ────────────────────── }

type
  TTestResultAppender = class
  private
    FResults: specialize TArray<TTestResult>;
    function GetResults: specialize TArray<TTestResult>;
  public
    procedure Append(const AResult: TTestResult);
    property Results: specialize TArray<TTestResult> read GetResults;
  end;

{ ── TTestContext (for subtest execution) ───────────────────────────────────── }

type
  TEnvBackup = record
    Name     : string;
    OldValue : string;
    HadValue : Boolean;
  end;

  TTestContext = class(TInterfacedObject, ITestContext)
  public
    FTestName : string;
    FConfig   : TTestConfig;
    FSubtests : specialize TArray<TTestEntry>;
    FSubPass  : Integer;
    FSubFail  : Integer;
    FSubSkip  : Integer;
    FOnResult : TOnSubtestResult;
    FFailedNames: specialize TArray<string>;
    FLogLines : specialize TArray<string>;
    FCleanups : specialize TArray<TTestClosure>;
    FTempDir  : string;  { lazy-created temp directory, auto-cleaned }
    FEnvBackups: specialize TArray<TEnvBackup>;  { saved env vars for restore }
    constructor Create(const ATestName: string; const AConfig: TTestConfig);
    destructor Destroy; override;
    procedure Run(const AName: string; AProc: TTestProc);
    procedure Run(const AName: string; AProc: TTestClosure);
    procedure RunNested(const AName: string; AProc: Pointer);
    procedure Fail(const AMessage: string);
    procedure Skip(const AReason: string = '');
    function  GetTestName: string;
    procedure Log(const AMessage: string);
    procedure LogF(const AFormat: string; const AArgs: array of const);
    procedure OnCleanup(AProc: TTestProc);
    procedure OnCleanup(AProc: TTestClosure);
    procedure ClearLog;
    property  LogLines: specialize TArray<string> read FLogLines;
    { TempDir: lazy-created temporary directory for this test.
      Created on first access, auto-cleaned when the test context is destroyed.
      Each test gets its own isolated directory. }
    function  GetTempDir: string;
    property  TempDir: string read GetTempDir;
    { Environment variable isolation }
    procedure SetEnv(const AName, AValue: string);
    procedure UnsetEnv(const AName: string);
    procedure ExecuteSubtests;
    procedure RunCleanups;
    procedure RestoreEnvVars;
  end;

implementation

uses
  SysUtils,
  nextpas.core.platform.env,
  nextpas.core.fs;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestResultAppender                                                          }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure TTestResultAppender.Append(const AResult: TTestResult);
begin
  AppendResult(FResults, AResult);
end;

function TTestResultAppender.GetResults: specialize TArray<TTestResult>;
begin
  Result := FResults;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestContext                                                                  }
{ ═════════════════════════════════════════════════════════════════════════════ }

constructor TTestContext.Create(const ATestName: string;
  const AConfig: TTestConfig);
begin
  inherited Create;
  FTestName := ATestName;
  FConfig   := ResolveConfig(AConfig);
  FSubPass  := 0;
  FSubFail  := 0;
  FSubSkip  := 0;
  FOnResult := nil;
end;

destructor TTestContext.Destroy;
var
  I: Integer;
begin
  { Explicitly release closures — FPC may not finalize managed fields
    in classes destroyed via reference counting. }
  for I := 0 to High(FSubtests) do
  begin
    FSubtests[I].Closure := nil;
    FSubtests[I].SubtestProc := nil;
  end;
  FSubtests := nil;
  for I := 0 to High(FCleanups) do
    FCleanups[I] := nil;
  FCleanups := nil;
  FOnResult := nil;
  FFailedNames := nil;
  FLogLines := nil;
  { Restore environment variables before cleanup }
  RestoreEnvVars;
  FEnvBackups := nil;
  { Safety net: remove temp dir if RunCleanups wasn't called }
  if FTempDir <> '' then
  begin
    RemoveAll(FTempDir);
    FTempDir := '';
  end;
  inherited Destroy;
end;

procedure TTestContext.Run(const AName: string; AProc: TTestProc);
var
  LEntry: TTestEntry;
begin
  ClearEntry(LEntry);
  LEntry.Name := FTestName + '/' + AName;
  LEntry.Proc := AProc;
  RegisterEntry(FSubtests, LEntry);
end;

procedure TTestContext.Run(const AName: string; AProc: TTestClosure);
var
  LEntry: TTestEntry;
begin
  ClearEntry(LEntry);
  LEntry.Name    := FTestName + '/' + AName;
  LEntry.Closure := AProc;
  RegisterEntry(FSubtests, LEntry);
end;

procedure TTestContext.RunNested(const AName: string; AProc: Pointer);
var
  LEntry: TTestEntry;
begin
  ClearEntry(LEntry);
  LEntry.Name        := FTestName + '/' + AName;
  LEntry.SubtestProc := TSubtestProc(AProc);
  LEntry.Kind        := ekSubtest;
  RegisterEntry(FSubtests, LEntry);
end;

procedure TTestContext.Fail(const AMessage: string);
begin
  InternalFail(AMessage);
end;

procedure TTestContext.Skip(const AReason: string);
begin
  InternalSkip(AReason);
end;

function TTestContext.GetTestName: string;
begin
  Result := FTestName;
end;

procedure TTestContext.Log(const AMessage: string);
var
  LOldLen, LCap: Integer;
begin
  LOldLen := Length(FLogLines);
  LCap := GrowCapacity(LOldLen, 8);
  if LCap <> LOldLen then SetLength(FLogLines, LCap);
  FLogLines[LOldLen] := AMessage;
  SetLength(FLogLines, LOldLen + 1);
end;

procedure TTestContext.LogF(const AFormat: string; const AArgs: array of const);
begin
  Log(TextFormat(AFormat, AArgs));
end;

procedure TTestContext.OnCleanup(AProc: TTestProc);
var
  LProc: TTestProc;
  LIdx: Integer;
begin
  LProc := AProc;
  LIdx := GrowCleanups(FCleanups);
  FCleanups[LIdx] := procedure
  begin
    LProc;
  end;
  SetLength(FCleanups, LIdx + 1);
end;

procedure TTestContext.OnCleanup(AProc: TTestClosure);
var
  LIdx: Integer;
begin
  LIdx := GrowCleanups(FCleanups);
  FCleanups[LIdx] := AProc;
  SetLength(FCleanups, LIdx + 1);
end;

procedure TTestContext.ClearLog;
begin
  FLogLines := nil;
end;

function TTestContext.GetTempDir: string;
var
  LBaseDir: string;
begin
  if FTempDir = '' then
  begin
    { Create under system temp dir with test name sanitised for filesystem }
    LBaseDir := platform_env_get_str('TMPDIR');
    if LBaseDir = '' then
      LBaseDir := '/tmp';
    LBaseDir := IncludeTrailingPathDelimiter(LBaseDir);
    FTempDir := LBaseDir + 'nextpas_test_' +
      StringReplace(FTestName, '/', '_', [rfReplaceAll]) + '_' +
      IntToStr(Int64(Pointer(Self)));  { unique per instance }
    ForceDirectories(FTempDir);
    { Register cleanup to remove temp dir after test }
    OnCleanup(procedure
    begin
      if FTempDir <> '' then
      begin
        RemoveAll(FTempDir);
        FTempDir := '';
      end;
    end);
  end;
  Result := FTempDir;
end;

procedure TTestContext.SetEnv(const AName, AValue: string);
var
  LBackup: TEnvBackup;
  LExisting: AnsiString;
begin
  { Save current value for restore }
  LBackup.Name := AName;
  LExisting := platform_env_get_str(AnsiString(AName));
  LBackup.HadValue := LExisting <> '';
  LBackup.OldValue := string(LExisting);
  SetLength(FEnvBackups, Length(FEnvBackups) + 1);
  FEnvBackups[High(FEnvBackups)] := LBackup;
  { Set new value }
  platform_env_set(PAnsiChar(AnsiString(AName)), PAnsiChar(AnsiString(AValue)));
end;

procedure TTestContext.UnsetEnv(const AName: string);
var
  LBackup: TEnvBackup;
  LExisting: AnsiString;
begin
  { Save current value for restore }
  LBackup.Name := AName;
  LExisting := platform_env_get_str(AnsiString(AName));
  LBackup.HadValue := LExisting <> '';
  LBackup.OldValue := string(LExisting);
  SetLength(FEnvBackups, Length(FEnvBackups) + 1);
  FEnvBackups[High(FEnvBackups)] := LBackup;
  { Unset }
  platform_env_unset(PAnsiChar(AnsiString(AName)));
end;

procedure TTestContext.RestoreEnvVars;
var
  I: Integer;
  LBackup: TEnvBackup;
begin
  for I := High(FEnvBackups) downto 0 do
  begin
    LBackup := FEnvBackups[I];
    if LBackup.HadValue then
      platform_env_set(PAnsiChar(AnsiString(LBackup.Name)),
        PAnsiChar(AnsiString(LBackup.OldValue)))
    else
      platform_env_unset(PAnsiChar(AnsiString(LBackup.Name)));
  end;
end;

{ ── Internal helpers ────────────────────────────────────────────────────────── }

procedure WriteSubtestStatus(AStatus: TTestStatus; const AName, AFailMsg,
  ASkipReason, AClassName: string; const ASink: IOutputSink;
  const AConfig: TTestConfig);
begin
  case AStatus of
    tsPassed:
      ASink.WriteLn('    ' + FormatStatusLine(tsPassed, AName, AConfig));
    tsFailed:
      begin
        ASink.WriteLn('    ' + FormatStatusLine(tsFailed, AName, AConfig));
        ASink.WriteLn('      ' + FormatFailDetail(AFailMsg, AConfig));
      end;
    tsSkipped:
      begin
        if ASkipReason <> '' then
          ASink.WriteLn('    ' + FormatStatusLine(tsSkipped, AName, ASkipReason, AConfig))
        else
          ASink.WriteLn('    ' + FormatStatusLine(tsSkipped, AName, AConfig));
      end;
    tsError:
      begin
        if AClassName <> '' then
          ASink.WriteLn('    ' + FormatStatusLine(tsError, AName, AConfig) +
            ' [' + AClassName + ']')
        else
          ASink.WriteLn('    ' + FormatStatusLine(tsError, AName, AConfig) +
            ' [unexpected exception]');
        if AFailMsg <> '' then
          ASink.WriteLn('      ' + AnsiDim(AFailMsg, AConfig));
      end;
  end;
end;

procedure OutputCapturedLog(const ALines: specialize TArray<string>;
  const ASink: IOutputSink; const AConfig: TTestConfig);
var
  J: Integer;
begin
  for J := 0 to High(ALines) do
    ASink.WriteLn('        ' + AnsiDim(ALines[J], AConfig));
end;

procedure AppendFailedName(var ANames: specialize TArray<string>;
  const AName: string);
var
  LOldLen, LCap: Integer;
begin
  LOldLen := Length(ANames);
  LCap := GrowCapacity(LOldLen, 4);
  if LCap <> LOldLen then SetLength(ANames, LCap);
  ANames[LOldLen] := AName;
  SetLength(ANames, LOldLen + 1);
end;

procedure RecordSubtestFailure(AStatus: TTestStatus;
  const AName, AFailMsg, AClassName: string;
  ALogCaptured: Boolean;
  const ASink: IOutputSink; const AConfig: TTestConfig;
  var ASubFail: Integer; var AFailedNames: specialize TArray<string>;
  const ALogLines: specialize TArray<string>);
{ Shared handler for subtest failure/error results.
  WriteSubtestStatus + optional captured log + Inc(SubFail) + AppendFailedName. }
begin
  WriteSubtestStatus(AStatus, AName, AFailMsg, '', AClassName, ASink, AConfig);
  if ALogCaptured then
    OutputCapturedLog(ALogLines, ASink, AConfig);
  Inc(ASubFail);
  AppendFailedName(AFailedNames, AName);
end;

procedure HandleSubtestSkipped(const AName, ASkipReason: string;
  const ASink: IOutputSink; const AConfig: TTestConfig;
  out AStatus: TTestStatus; out AMsg: string;
  var ASkipCount: Integer);
{ Shared handler for subtest ETestSkipped paths.
  Sets status/msg, writes output, increments skip counter. }
begin
  AStatus := tsSkipped;
  AMsg    := ASkipReason;
  WriteSubtestStatus(tsSkipped, AName, '', ASkipReason, '', ASink, AConfig);
  Inc(ASkipCount);
end;

procedure TTestContext.ExecuteSubtests;
var
  I: Integer;
  LEntry: TTestEntry;
  LStatus: TTestStatus;
  LMsg: string;
  LSubCtx: TTestContext;
  LSubCtxI: ITestContext;
  LTestResult: TTestResult;
  LNames: string;
  LOutSink: IOutputSink;
  K: Integer;
  J: Integer;
  LTotal, LPos: Integer;
begin
  LOutSink := ResolveOutSink(FConfig);
  for I := 0 to High(FSubtests) do
  begin
    LEntry := FSubtests[I];
    LStatus := tsPassed;
    LMsg    := '';
    ClearLog;
    SetTestContext(GExecState^.SuiteName, LEntry.Name);
    try
      if LEntry.Kind = ekSkipped then
      begin
        HandleSubtestSkipped(LEntry.Name, LEntry.SkipReason,
          LOutSink, FConfig, LStatus, LMsg, FSubSkip);
      end
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name, FConfig);
        LSubCtx.FOnResult := FOnResult; { propagate result callback }
        LSubCtxI := LSubCtx;
        LEntry.SubtestProc(LSubCtxI);
        LSubCtx.ExecuteSubtests;
        { Aggregate nested subtest counts into parent }
        Inc(FSubPass, LSubCtx.FSubPass);
        Inc(FSubFail, LSubCtx.FSubFail);
        Inc(FSubSkip, LSubCtx.FSubSkip);
        { Propagate nested failed names to parent }
        for J := 0 to High(LSubCtx.FFailedNames) do
          AppendFailedName(FFailedNames, LSubCtx.FFailedNames[J]);
        LSubCtxI := nil;
        LSubCtx := nil;
      end
      else if LEntry.Kind = ekTableTest then
      begin
        { Nil guard: --count=N re-runs the suite after CleanupTableAllocations
          has disposed TableCase/TableProc. Skip gracefully on re-run. }
        if (LEntry.TableCase = nil) or (LEntry.TableProc = nil) then
        begin
          LStatus := tsSkipped;
          LMsg := 'table data already disposed (--count re-run)';
          WriteSubtestStatus(tsSkipped, LEntry.Name, '', LMsg, '',
            LOutSink, FConfig);
          Inc(FSubSkip);
        end
        else
        begin
          PTestCaseProc(LEntry.TableProc)^(PTestCase(LEntry.TableCase)^);
          WriteSubtestStatus(tsPassed, LEntry.Name, '', '', '',
            LOutSink, FConfig);
          Inc(FSubPass);
        end;
      end
      else if LEntry.Kind = ekShouldFail then
      begin
        RunShouldFailEntry(LEntry, LStatus, LMsg);
        if LStatus = tsSkipped then
          HandleSubtestSkipped(LEntry.Name, LMsg,
            LOutSink, FConfig, LStatus, LMsg, FSubSkip)
        else if LStatus = tsFailed then
          RecordSubtestFailure(tsFailed, LEntry.Name, LMsg, '', False,
            LOutSink, FConfig, FSubFail, FFailedNames, FLogLines)
        else
        begin
          WriteSubtestStatus(tsPassed, LEntry.Name, '', '', '',
            LOutSink, FConfig);
          Inc(FSubPass);
        end;
      end
      else
      begin
        if Assigned(LEntry.Closure) then
          LEntry.Closure()
        else
          LEntry.Proc;
        WriteSubtestStatus(tsPassed, LEntry.Name, '', '', '',
          LOutSink, FConfig);
        Inc(FSubPass);
      end;
    except
      on E: ETestSkipped do
        HandleSubtestSkipped(LEntry.Name, E.Message,
          LOutSink, FConfig, LStatus, LMsg, FSubSkip);
      on E: EAssertionFailed do
      begin
        LStatus := tsFailed;
        LMsg    := AppendTestTrace(E.Message);
        RecordSubtestFailure(tsFailed, LEntry.Name, LMsg, '', True,
          LOutSink, FConfig, FSubFail, FFailedNames, FLogLines);
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LMsg    := AppendTestTrace(FormatExceptionMsg(E));
        RecordSubtestFailure(tsError, LEntry.Name, E.Message, E.ClassName, True,
          LOutSink, FConfig, FSubFail, FFailedNames, FLogLines);
      end;
    end;
    ReportLeakIfAny(LStatus, FConfig);
    { Collect subtest result via callback if caller requested it }
    if (LEntry.Kind <> ekSubtest) and Assigned(FOnResult) then
    begin
      LTestResult := MakeTestResult(LEntry.Name, LStatus, LMsg, 0);
      { Copy captured log lines on failure/error }
      if (LStatus in [tsFailed, tsError]) and (Length(FLogLines) > 0) then
        LTestResult.CapturedLog := Copy(FLogLines, 0, Length(FLogLines));
      FOnResult(LTestResult);
    end;
  end;
  { Execute cleanup callbacks in reverse order before propagating failures }
  RunCleanups;
  { Clear subtests to break reference cycles: subtest closures may capture
    the ITestContext that owns this FSubtests array. }
  FSubtests := nil;
  { Propagate subtest failures to parent }
  if FSubFail > 0 then
  begin
    { Build comma-separated list: pre-compute total length to avoid O(n²) concat }
    LTotal := 0;
    for K := 0 to High(FFailedNames) do
      Inc(LTotal, Length(FFailedNames[K]));
    if Length(FFailedNames) > 1 then
      Inc(LTotal, 2 * (Length(FFailedNames) - 1)); { ', ' separators }
    SetLength(LNames, LTotal);
    LPos := 1;
    for K := 0 to High(FFailedNames) do
    begin
      if K > 0 then
      begin
        LNames[LPos] := ',';
        LNames[LPos + 1] := ' ';
        Inc(LPos, 2);
      end;
      if Length(FFailedNames[K]) > 0 then
      begin
        Move(FFailedNames[K][1], LNames[LPos], Length(FFailedNames[K]));
        Inc(LPos, Length(FFailedNames[K]));
      end;
    end;
    InternalFail(IntToStr(FSubFail) + ' subtest(s) failed in ' + FTestName + ': ' + LNames);
  end;
end;

procedure TTestContext.RunCleanups;
var
  LIdx: Integer;
begin
  for LIdx := High(FCleanups) downto 0 do
  begin
    try
      FCleanups[LIdx]();
    except
      on E: Exception do
        ResolveErrSink(FConfig).WriteLn(
          '    ' + AnsiYellow('WARNING cleanup error: ', FConfig) + E.Message);
    end;
  end;
  FCleanups := nil;
end;

end.
