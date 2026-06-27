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
  SetLength(FResults, Length(FResults) + 1);
  FResults[High(FResults)] := AResult;
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
  LEntry.Name        := FTestName + '/' + AName;
  LEntry.Proc        := AProc;
  LEntry.Closure     := nil;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason  := '';
  LEntry.RetryCount  := 0;
  LEntry.DisplayName := '';
  LEntry.Tags        := nil;
  LEntry.RepeatCount := 0;
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
end;

procedure TTestContext.Run(const AName: string; AProc: TTestClosure);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := FTestName + '/' + AName;
  LEntry.Proc        := nil;
  LEntry.Closure     := AProc;
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason  := '';
  LEntry.RetryCount  := 0;
  LEntry.DisplayName := '';
  LEntry.Tags        := nil;
  LEntry.RepeatCount := 0;
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
end;

procedure TTestContext.RunNested(const AName: string; AProc: Pointer);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := FTestName + '/' + AName;
  LEntry.Proc        := nil;
  LEntry.Closure     := nil;
  LEntry.SubtestProc := TSubtestProc(AProc);
  LEntry.Kind        := ekSubtest;
  LEntry.SkipReason  := '';
  LEntry.RetryCount  := 0;
  LEntry.DisplayName := '';
  LEntry.Tags        := nil;
  LEntry.RepeatCount := 0;
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
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
begin
  SetLength(FLogLines, Length(FLogLines) + 1);
  FLogLines[High(FLogLines)] := AMessage;
end;

procedure TTestContext.LogF(const AFormat: string; const AArgs: array of const);
begin
  Log(TextFormat(AFormat, AArgs));
end;

procedure TTestContext.OnCleanup(AProc: TTestProc);
var
  LProc: TTestProc;
begin
  LProc := AProc;
  SetLength(FCleanups, Length(FCleanups) + 1);
  FCleanups[High(FCleanups)] := procedure
  begin
    LProc;
  end;
end;

procedure TTestContext.OnCleanup(AProc: TTestClosure);
begin
  SetLength(FCleanups, Length(FCleanups) + 1);
  FCleanups[High(FCleanups)] := AProc;
end;

procedure TTestContext.ClearLog;
begin
  FLogLines := nil;
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
        ResolveOutSink(FConfig).WriteLn(
          '    ' + StatusDot(tsSkipped, FConfig) + ' ' +
          AnsiDim(LEntry.Name, FConfig) + ' -- ' + LEntry.SkipReason);
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
        begin
          SetLength(FFailedNames, Length(FFailedNames) + 1);
          FFailedNames[High(FFailedNames)] := LSubCtx.FFailedNames[J];
        end;
        LSubCtxI := nil;
        LSubCtx := nil;
      end
      else if LEntry.Kind = ekTableTest then
      begin
        PTestCaseProc(LEntry.TableProc)^(PTestCase(LEntry.TableCase)^);
        ResolveOutSink(FConfig).WriteLn(
          '    ' + StatusDot(tsPassed, FConfig) + ' ' + LEntry.Name);
        Inc(FSubPass);
      end
      else
      begin
        if Assigned(LEntry.Closure) then
          LEntry.Closure()
        else
          LEntry.Proc;
        ResolveOutSink(FConfig).WriteLn(
          '    ' + StatusDot(tsPassed, FConfig) + ' ' + LEntry.Name);
        Inc(FSubPass);
      end;
    except
      on E: ETestSkipped do
      begin
        LStatus := tsSkipped;
        LMsg    := E.Message;
        ResolveOutSink(FConfig).WriteLn(
          '    ' + StatusDot(tsSkipped, FConfig) + ' ' +
          AnsiDim(LEntry.Name, FConfig));
        Inc(FSubSkip);
      end;
      on E: EAssertionFailed do
      begin
        LStatus := tsFailed;
        LMsg    := E.Message;
        { Append file:line from stack trace if available }
        if GLastTestTrace <> '' then
          LMsg := LMsg + ' [' + GLastTestTrace + ']';
        ResolveOutSink(FConfig).WriteLn(
          '    ' + StatusDot(tsFailed, FConfig) + ' ' +
          AnsiRed(LEntry.Name, FConfig));
        ResolveOutSink(FConfig).WriteLn(
          '      ' + AnsiDim(LMsg, FConfig));
        { Output captured log lines on failure }
        for J := 0 to High(FLogLines) do
          ResolveOutSink(FConfig).WriteLn(
            '        ' + AnsiDim(FLogLines[J], FConfig));
        Inc(FSubFail);
        SetLength(FFailedNames, Length(FFailedNames) + 1);
        FFailedNames[High(FFailedNames)] := LEntry.Name;
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LMsg    := E.ClassName + ': ' + E.Message;
        { Append file:line from stack trace if available }
        if GLastTestTrace <> '' then
          LMsg := LMsg + ' [' + GLastTestTrace + ']';
        ResolveOutSink(FConfig).WriteLn(
          '    ' + StatusDot(tsError, FConfig) + ' ' +
          AnsiRed(LEntry.Name, FConfig) + ' [' + E.ClassName + ']');
        ResolveOutSink(FConfig).WriteLn(
          '      ' + AnsiDim(E.Message, FConfig));
        { Output captured log lines on error }
        for J := 0 to High(FLogLines) do
          ResolveOutSink(FConfig).WriteLn(
            '        ' + AnsiDim(FLogLines[J], FConfig));
        Inc(FSubFail);
        SetLength(FFailedNames, Length(FFailedNames) + 1);
        FFailedNames[High(FFailedNames)] := LEntry.Name;
      end;
    end;
    ReportLeakIfAny(LStatus, FConfig);
    { Collect subtest result via callback if caller requested it }
    if (LEntry.Kind <> ekSubtest) and Assigned(FOnResult) then
    begin
      LTestResult.Name    := LEntry.Name;
      LTestResult.Status  := LStatus;
      LTestResult.Message := LMsg;
      { Copy captured log lines on failure/error }
      if (LStatus in [tsFailed, tsError]) and (Length(FLogLines) > 0) then
        LTestResult.CapturedLog := Copy(FLogLines, 0, Length(FLogLines))
      else
        LTestResult.CapturedLog := nil;
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
