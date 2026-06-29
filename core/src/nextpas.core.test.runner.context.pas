{ nextpas.core.test.runner.context — TTestContext + TTestResultAppender (subtest execution)
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.output }

unit nextpas.core.test.runner.context;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,          { Exception, EAbort, EAssertionFailed — FPC built-in }
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
    constructor Create(const ATestName: string; const AConfig: TTestConfig);
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
    procedure ExecuteSubtests;
    procedure RunCleanups;
  end;

implementation

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
  LCap := LOldLen;
  if LCap < 8 then LCap := 8
  else if LOldLen >= LCap then LCap := LCap * 2;
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
  LOldLen, LCap: Integer;
begin
  LProc := AProc;
  LOldLen := Length(FCleanups);
  LCap := LOldLen;
  if LCap < 4 then LCap := 4
  else if LOldLen >= LCap then LCap := LCap * 2;
  if LCap <> LOldLen then SetLength(FCleanups, LCap);
  FCleanups[LOldLen] := procedure
  begin
    LProc;
  end;
  SetLength(FCleanups, LOldLen + 1);
end;

procedure TTestContext.OnCleanup(AProc: TTestClosure);
var
  LOldLen, LCap: Integer;
begin
  LOldLen := Length(FCleanups);
  LCap := LOldLen;
  if LCap < 4 then LCap := 4
  else if LOldLen >= LCap then LCap := LCap * 2;
  if LCap <> LOldLen then SetLength(FCleanups, LCap);
  FCleanups[LOldLen] := AProc;
  SetLength(FCleanups, LOldLen + 1);
end;

procedure TTestContext.ClearLog;
begin
  FLogLines := nil;
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
begin
  SetLength(ANames, Length(ANames) + 1);
  ANames[High(ANames)] := AName;
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
  K: Integer;
  J: Integer;
begin
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
        LStatus := tsSkipped;
        LMsg    := LEntry.SkipReason;
        WriteSubtestStatus(tsSkipped, LEntry.Name, '', LEntry.SkipReason,
          '', ResolveOutSink(FConfig), FConfig);
        Inc(FSubSkip);
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
        PTestCaseProc(LEntry.TableProc)^(PTestCase(LEntry.TableCase)^);
        WriteSubtestStatus(tsPassed, LEntry.Name, '', '', '',
          ResolveOutSink(FConfig), FConfig);
        Inc(FSubPass);
      end
      else if LEntry.Kind = ekShouldFail then
      begin
        try
          if Assigned(LEntry.Closure) then
            LEntry.Closure()
          else
            LEntry.Proc;
          LStatus := tsFailed;
          if LEntry.ShouldFailMsg <> '' then
            LMsg := 'Expected failure (' + LEntry.ShouldFailMsg +
              ') but test passed'
          else
            LMsg := 'Expected failure but test passed';
          WriteSubtestStatus(tsFailed, LEntry.Name, LMsg, '', '',
            ResolveOutSink(FConfig), FConfig);
          Inc(FSubFail);
          AppendFailedName(FFailedNames, LEntry.Name);
        except
          on E: ETestSkipped do
          begin
            LStatus := tsSkipped;
            LMsg := E.Message;
            WriteSubtestStatus(tsSkipped, LEntry.Name, '', '', '',
              ResolveOutSink(FConfig), FConfig);
            Inc(FSubSkip);
          end;
          on E: Exception do
          begin
            { Expected failure — subtest passes }
            LStatus := tsPassed;
            WriteSubtestStatus(tsPassed, LEntry.Name, '', '', '',
              ResolveOutSink(FConfig), FConfig);
            Inc(FSubPass);
          end;
        end;
      end
      else
      begin
        if Assigned(LEntry.Closure) then
          LEntry.Closure()
        else
          LEntry.Proc;
        WriteSubtestStatus(tsPassed, LEntry.Name, '', '', '',
          ResolveOutSink(FConfig), FConfig);
        Inc(FSubPass);
      end;
    except
      on E: ETestSkipped do
      begin
        LStatus := tsSkipped;
        LMsg    := E.Message;
        WriteSubtestStatus(tsSkipped, LEntry.Name, '', '', '',
          ResolveOutSink(FConfig), FConfig);
        Inc(FSubSkip);
      end;
      on E: EAssertionFailed do
      begin
        LStatus := tsFailed;
        LMsg    := AppendTestTrace(E.Message);
        WriteSubtestStatus(tsFailed, LEntry.Name, LMsg, '', '',
          ResolveOutSink(FConfig), FConfig);
        OutputCapturedLog(FLogLines, ResolveOutSink(FConfig), FConfig);
        Inc(FSubFail);
        AppendFailedName(FFailedNames, LEntry.Name);
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LMsg    := AppendTestTrace(FormatExceptionMsg(E));
        WriteSubtestStatus(tsError, LEntry.Name, E.Message, '',
          E.ClassName, ResolveOutSink(FConfig), FConfig);
        OutputCapturedLog(FLogLines, ResolveOutSink(FConfig), FConfig);
        Inc(FSubFail);
        AppendFailedName(FFailedNames, LEntry.Name);
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
    LNames := '';
    for K := 0 to High(FFailedNames) do
    begin
      if K > 0 then LNames := LNames + ', ';
      LNames := LNames + FFailedNames[K];
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
