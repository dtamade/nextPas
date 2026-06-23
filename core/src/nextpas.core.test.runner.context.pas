{ nextpas.core.test.runner.context — TTestContext + TTestResultAppender (subtest execution)
  =========================================================
  Depends on: nextpas.core.test.base, nextpas.core.test.output }

unit nextpas.core.test.runner.context;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,          { Exception, EAbort, EAssertionFailed — FPC built-in }
  nextpas.core.text.conv,
  nextpas.core.test.base,
  nextpas.core.test.output;

{ ── Subtest result callback type ───────────────────────────────────────────── }

type
  TOnSubtestResult = procedure(const AResult: TTestResult) of object;

{ ── TTestResultAppender (for subtest result collection) ────────────────────── }

type
  TTestResultAppender = class
  private
    FResults: specialize TArray<TTestResult>;
  public
    procedure Append(const AResult: TTestResult);
    property Results: specialize TArray<TTestResult> read FResults;
  end;

{ ── TTestContext (for subtest execution) ───────────────────────────────────── }

type
  TTestContext = class(TInterfacedObject, ITestContext)
  public
    FTestName : string;
    FSubtests : specialize TArray<TTestEntry>;
    FSubPass  : Integer;
    FSubFail  : Integer;
    FSubSkip  : Integer;
    FOnResult : TOnSubtestResult;
    FFailedNames: specialize TArray<string>;
    constructor Create(const ATestName: string);
    procedure Run(const AName: string; AProc: TTestProc);
    procedure RunNested(const AName: string; AProc: Pointer);
    procedure Fail(const AMessage: string);
    procedure Skip(const AReason: string = '');
    function  GetTestName: string;
    procedure ExecuteSubtests;
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

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestContext                                                                  }
{ ═════════════════════════════════════════════════════════════════════════════ }

constructor TTestContext.Create(const ATestName: string);
begin
  inherited Create;
  FTestName := ATestName;
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
  LEntry.SubtestProc := nil;
  LEntry.Kind        := ekTest;
  LEntry.SkipReason  := '';
  SetLength(FSubtests, Length(FSubtests) + 1);
  FSubtests[High(FSubtests)] := LEntry;
end;

procedure TTestContext.RunNested(const AName: string; AProc: Pointer);
var
  LEntry: TTestEntry;
begin
  LEntry.Name        := FTestName + '/' + AName;
  LEntry.Proc        := nil;
  LEntry.SubtestProc := TSubtestProc(AProc);
  LEntry.Kind        := ekSubtest;
  LEntry.SkipReason  := '';
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
    SetTestContext(GExecState^.SuiteName, LEntry.Name);
    try
      if LEntry.Kind = ekSkipped then
      begin
        LStatus := tsSkipped;
        LMsg    := LEntry.SkipReason;
        WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name),
          ' -- ', LEntry.SkipReason);
        Inc(FSubSkip);
      end
      else if LEntry.Kind = ekSubtest then
      begin
        LSubCtx := TTestContext.Create(LEntry.Name);
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
      end
      else if LEntry.Kind = ekTableTest then
      begin
        PTestCaseProc(LEntry.TableProc)^(PTestCase(LEntry.TableCase)^);
        WriteLn('    ', StatusDot(tsPassed), ' ', LEntry.Name);
        Inc(FSubPass);
      end
      else
      begin
        LEntry.Proc;
        WriteLn('    ', StatusDot(tsPassed), ' ', LEntry.Name);
        Inc(FSubPass);
      end;
    except
      on E: ETestSkipped do
      begin
        LStatus := tsSkipped;
        LMsg    := E.Message;
        WriteLn('    ', StatusDot(tsSkipped), ' ', AnsiDim(LEntry.Name));
        Inc(FSubSkip);
      end;
      on E: EAssertionFailed do
      begin
        LStatus := tsFailed;
        LMsg    := E.Message;
        WriteLn('    ', StatusDot(tsFailed), ' ', AnsiRed(LEntry.Name));
        WriteLn('      ', AnsiDim(E.Message));
        Inc(FSubFail);
        SetLength(FFailedNames, Length(FFailedNames) + 1);
        FFailedNames[High(FFailedNames)] := LEntry.Name;
      end;
      on E: Exception do
      begin
        LStatus := tsError;
        LMsg    := E.ClassName + ': ' + E.Message;
        WriteLn('    ', StatusDot(tsError), ' ', AnsiRed(LEntry.Name),
          ' [', E.ClassName, ']');
        WriteLn('      ', AnsiDim(E.Message));
        Inc(FSubFail);
        SetLength(FFailedNames, Length(FFailedNames) + 1);
        FFailedNames[High(FFailedNames)] := LEntry.Name;
      end;
    end;
    ReportLeakIfAny(LStatus);
    { Collect subtest result via callback if caller requested it }
    if (LEntry.Kind <> ekSubtest) and Assigned(FOnResult) then
    begin
      LTestResult.Name    := LEntry.Name;
      LTestResult.Status  := LStatus;
      LTestResult.Message := LMsg;
      FOnResult(LTestResult);
    end;
  end;
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

end.
