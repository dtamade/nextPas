{ nextpas.core.test.runner.multi — TSuiteRunner multi-suite orchestration
  =========================================================
  Depends on: nextpas.core.test.runner (TTestSuite), nextpas.core.test.base,
              nextpas.core.test.config, nextpas.core.test.output,
              nextpas.core.test.runner.cli }

unit nextpas.core.test.runner.multi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.test.base,
  nextpas.core.test.config,
  nextpas.core.test.runner,
  nextpas.core.thread.intf,
  nextpas.core.collections.base;

{ ── Test Runner (multi-suite) ─────────────────────────────────────────────── }

type
  TSuiteRunner = record
    Name     : string;
    Suites   : specialize TArray<TTestSuite>;
    TotalPass: Integer;
    TotalFail: Integer;
    TotalSkip: Integer;
    TotalDuration: Int64;  { total execution time in milliseconds }
    HasRun   : Boolean;
    LastResults: specialize TArray<TTestRunResult>;
      { Stored by RunAllIterLoop for failure summary in Summary. }

    class function Create(const AName: string): TSuiteRunner; static;
    procedure Add(const ASuite: TTestSuite);
    function  RunAll: Boolean;
    function  RunAllWithResult(
      out AResults: specialize TArray<TTestRunResult>): Boolean;
    function  RunAllParallel(APool: IThreadPool): Boolean;
    function  RunAllParallelWithResult(APool: IThreadPool;
      out AResults: specialize TArray<TTestRunResult>): Boolean;
    procedure Summary;
    function  AllPassed: Boolean;
  private
    function RunAllIterLoop(
      out AResults: specialize TArray<TTestRunResult>;
      AIsParallel: Boolean; APool: IThreadPool): Boolean;
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.test.output,
  nextpas.core.test.output.json,
  nextpas.core.test.runner.cli,
  nextpas.core.time;

{ Runner-level config: reads from the first suite's config.
  In practice all suites share the same DefaultConfig, so reading Suites[0]
  is correct. Per-suite config differences are handled by each suite's
  own RunWithResult/RunParallelWithResult via ResolveConfig. }
function RunnerConfig(const ARunner: TSuiteRunner): TTestConfig;
begin
  if Length(ARunner.Suites) > 0 then
    Result := ResolveConfig(ARunner.Suites[0].Config)
  else
    Result := ResolveConfig(DefaultConfig);
end;

function WriteListMode(const ASuites: specialize TArray<TTestSuite>;
  const AConfig: TTestConfig; out AResults: specialize TArray<TTestRunResult>): Boolean;
{ Print test names grouped by suite without running. Returns True to indicate
  the caller should use the result directly (always True = no failures). }
var
  I, J: Integer;
  LOutSink: IOutputSink;
  LSuffix: string;
begin
  LOutSink := ResolveOutSink(AConfig);
  for I := 0 to High(ASuites) do
  begin
    LOutSink.WriteLn(ASuites[I].Name + ':');
    for J := 0 to High(ASuites[I].Tests) do
    begin
      LSuffix := '';
      case ASuites[I].Tests[J].Kind of
        ekSkipped:    LSuffix := ' (skipped)';
        ekShouldFail: LSuffix := ' (should-fail)';
      else if ASuites[I].Tests[J].ShortSkip then
        LSuffix := ' (short-skip)';
      end;
      LOutSink.WriteLn('  ' + GetDisplayName(ASuites[I].Tests[J]) + LSuffix);
    end;
  end;
  SetLength(AResults, 0);
  Result := True;
end;

procedure WriteRunnerBanner(const AName: string; const AConfig: TTestConfig;
  const ASink: IOutputSink; AIsParallel: Boolean);
var
  LRepeatAll, LMaxFailures: Integer;
  LLabel: string;
begin
  if AIsParallel then LLabel := ' (parallel)' else LLabel := '';
  ASink.WriteLn(
    AnsiBold('=== ', AConfig) +
    AnsiBold(AName, AConfig) +
    AnsiBold(LLabel + ' ===', AConfig));
  LRepeatAll := GetRepeatAllCount(AConfig);
  if LRepeatAll > 1 then
    ASink.WriteLn(AnsiDim(
      '  Running all tests ' + IntToStr(LRepeatAll) + ' times (--count=' +
      IntToStr(LRepeatAll) + ')', AConfig));
  if GetFailFast(AConfig) then
    ASink.WriteLn(AnsiDim('  FailFast enabled', AConfig));
  LMaxFailures := GetMaxFailures(AConfig);
  if LMaxFailures > 0 then
    ASink.WriteLn(AnsiDim(
      '  Failures max: ' + IntToStr(LMaxFailures) + ' (--failures-max)',
      AConfig));
  if GetShortMode(AConfig) then
    ASink.WriteLn(AnsiDim('  Short mode enabled (--short)', AConfig));
  if GetVerboseMode(AConfig) then
    ASink.WriteLn(AnsiDim('  Verbose mode (--verbose)', AConfig));
  if GetRunTimeoutSec(AConfig) > 0 then
    ASink.WriteLn(AnsiDim(
      '  Run timeout: ' + IntToStr(GetRunTimeoutSec(AConfig)) + 's (--timeout)',
      AConfig));
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TSuiteRunner                                                                  }
{ ═════════════════════════════════════════════════════════════════════════════ }

class function TSuiteRunner.Create(const AName: string): TSuiteRunner;
begin
  Result.Name      := AName;
  Result.Suites    := nil;
  Result.TotalPass := 0;
  Result.TotalFail := 0;
  Result.TotalSkip := 0;
  Result.TotalDuration := 0;
  Result.HasRun    := False;
  Result.LastResults := nil;
end;

procedure TSuiteRunner.Add(const ASuite: TTestSuite);
var
  LIdx, I: Integer;
  LPCase: PTestCase;
  LPProc: PTestCaseProc;
begin
  LIdx := Length(Suites);
  SetLength(Suites, GrowCapacity(LIdx, 4));
  Suites[LIdx] := ASuite;
  Suites[LIdx].Tests := Copy(ASuite.Tests, 0, Length(ASuite.Tests));
  Suites[LIdx].EachCleanups := Copy(ASuite.EachCleanups, 0, Length(ASuite.EachCleanups));
  { Deep copy table payloads — original and runner must own independent copies
    so CleanupTableAllocations on the runner doesn't leave the original with
    dangling pointers (P0 fix: raw-owner aliasing). }
  for I := 0 to High(Suites[LIdx].Tests) do
  begin
    if Suites[LIdx].Tests[I].Kind = ekTableTest then
    begin
      if Suites[LIdx].Tests[I].TableCase <> nil then
      begin
        New(LPCase);
        LPCase^ := Default(TTestCase);
        LPCase^ := PTestCase(Suites[LIdx].Tests[I].TableCase)^;
        Suites[LIdx].Tests[I].TableCase := LPCase;
      end;
      if Suites[LIdx].Tests[I].TableProc <> nil then
      begin
        New(LPProc);
        LPProc^ := PTestCaseProc(Suites[LIdx].Tests[I].TableProc)^;
        Suites[LIdx].Tests[I].TableProc := LPProc;
      end;
    end;
  end;
  SetLength(Suites, LIdx + 1);
end;

function TSuiteRunner.RunAll: Boolean;
var
  LResults: specialize TArray<TTestRunResult>;
begin
  Result := RunAllWithResult(LResults);
end;

function TSuiteRunner.RunAllParallel(APool: IThreadPool): Boolean;
var
  LResults: specialize TArray<TTestRunResult>;
begin
  Result := RunAllParallelWithResult(APool, LResults);
end;

function TSuiteRunner.RunAllIterLoop(
  out AResults: specialize TArray<TTestRunResult>;
  AIsParallel: Boolean; APool: IThreadPool): Boolean;
var
  I, LIter, LRepeatAll: Integer;
  LAllPassed, LIterAllPassed: Boolean;
  LSuiteResult: TTestRunResult;
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
  LStart: TInstant;
  LFailFast: Boolean;
  LMaxFailures: Integer;
  LGrandPass, LGrandFail, LGrandSkip: Integer;
begin
  LConfig := RunnerConfig(Self);
  LOutSink := ResolveOutSink(LConfig);

  if GetListMode(LConfig) then
  begin
    { P2 #17 fix: --list only lists tests, doesn't run them. Don't set HasRun. }
    Exit(WriteListMode(Suites, LConfig, AResults));
  end;

  LRepeatAll := GetRepeatAllCount(LConfig);
  if LRepeatAll <= 0 then LRepeatAll := 1;
  LFailFast := GetFailFast(LConfig);
  LMaxFailures := GetMaxFailures(LConfig);

  WriteRunnerBanner(Name, LConfig, LOutSink, AIsParallel);

  LAllPassed := True;
  LIterAllPassed := True;
  TotalPass := 0;
  TotalFail := 0;
  TotalSkip := 0;
  TotalDuration := 0;
  LGrandPass := 0; LGrandFail := 0; LGrandSkip := 0;
  SetLength(AResults, Length(Suites));

  for LIter := 1 to LRepeatAll do
  begin
    if LRepeatAll > 1 then
    begin
      LOutSink.WriteLn('');
      LOutSink.WriteLn(AnsiBold(
        '--- Iteration ' + IntToStr(LIter) + '/' + IntToStr(LRepeatAll) +
        ' ---', LConfig));
      TotalPass := 0;
      TotalFail := 0;
      TotalSkip := 0;
      LAllPassed := True;
    end;
    LStart := TInstant.Now;
    for I := 0 to High(Suites) do
    begin
      if AIsParallel then
      begin
        if not Suites[I].RunParallelWithResult(APool, LSuiteResult, True) then
          LAllPassed := False;
      end
      else
      begin
        if not Suites[I].RunWithResult(LSuiteResult, True) then
          LAllPassed := False;
      end;
      AResults[I] := LSuiteResult;
      Inc(TotalPass, Suites[I].LastPass);
      Inc(TotalFail, Suites[I].LastFail);
      Inc(TotalSkip, Suites[I].LastSkip);
      Inc(TotalDuration, LSuiteResult.Duration);
      if (not LAllPassed) and LFailFast then
      begin
        LOutSink.WriteLn(AnsiYellow(
          '  FAILFAST: stopping after suite failure', LConfig));
        Break;
      end;
      if (LMaxFailures > 0) and (TotalFail >= LMaxFailures) then
      begin
        LOutSink.WriteLn(AnsiYellow(
          '  stopping after ' + IntToStr(TotalFail) +
          ' total failures (--failures-max)', LConfig));
        Break;
      end;
    end;
    if LRepeatAll > 1 then
      LOutSink.WriteLn(AnsiDim(
        '  Iteration ' + IntToStr(LIter) + ' completed in ' +
        FormatDuration(LStart.Elapsed.AsMilliseconds), LConfig));
    if not LAllPassed then
      LIterAllPassed := False;
    Inc(LGrandPass, TotalPass);
    Inc(LGrandFail, TotalFail);
    Inc(LGrandSkip, TotalSkip);
  end;

  TotalPass := LGrandPass;
  TotalFail := LGrandFail;
  TotalSkip := LGrandSkip;
  for I := 0 to High(Suites) do
    Suites[I].CleanupTableAllocations;

  HasRun := True;
  LastResults := AResults;
  Result := LIterAllPassed;
  if GetJsonOutput(LConfig) then
    LOutSink.WriteLn(JSONReport(AResults, Name));
end;

function TSuiteRunner.RunAllWithResult(
  out AResults: specialize TArray<TTestRunResult>): Boolean;
begin
  ApplyCLIArgs;
  Result := RunAllIterLoop(AResults, False, nil);
end;

function TSuiteRunner.RunAllParallelWithResult(APool: IThreadPool;
  out AResults: specialize TArray<TTestRunResult>): Boolean;
begin
  ApplyCLIArgs;
  Result := RunAllIterLoop(AResults, True, APool);
end;

procedure TSuiteRunner.Summary;
var
  LConfig: TTestConfig;
  LOutSink: IOutputSink;
  LSuite: TTestRunResult;
  LRes: TTestResult;
  I, J, LFailIdx, LTotal: Integer;
  LPassRate: Double;
  LPassRateStr: string;
begin
  LConfig := RunnerConfig(Self);
  LOutSink := ResolveOutSink(LConfig);
  LTotal := TotalPass + TotalFail + TotalSkip;
  LOutSink.WriteLn('');
  LOutSink.WriteLn(AnsiBold('=== Summary ===', LConfig));
  LOutSink.WriteLn('  Suites: ' + IntToStr(Length(Suites)));
  if LTotal > 0 then
  begin
    LPassRate := (TotalPass / LTotal) * 100.0;
    LPassRateStr := FormatFloat('0.0', LPassRate) + '%';
    { Color-coded pass rate: green ≥90%, yellow ≥70%, red <70% }
    if LPassRate >= 90.0 then
      LPassRateStr := AnsiGreen(LPassRateStr, LConfig)
    else if LPassRate >= 70.0 then
      LPassRateStr := AnsiYellow(LPassRateStr, LConfig)
    else
      LPassRateStr := AnsiRed(LPassRateStr, LConfig);
    LOutSink.WriteLn(
      '  Passed: ' + IntToStr(TotalPass) +
      ', Failed: ' + IntToStr(TotalFail) +
      ', Skipped: ' + IntToStr(TotalSkip) +
      ' (' + LPassRateStr + ' pass rate)');
  end
  else
    LOutSink.WriteLn(
      '  Passed: ' + IntToStr(TotalPass) +
      ', Failed: ' + IntToStr(TotalFail) +
      ', Skipped: ' + IntToStr(TotalSkip));
  { Total duration }
  LOutSink.WriteLn('  Duration: ' + FormatDuration(TotalDuration));

  { Failure summary: list all failed/error tests with details }
  if (TotalFail > 0) and (Length(LastResults) > 0) then
  begin
    LOutSink.WriteLn('');
    LOutSink.WriteLn(AnsiBold('=== Failures ===', LConfig));
    LFailIdx := 0;
    for I := 0 to High(LastResults) do
    begin
      LSuite := LastResults[I];
      for J := 0 to High(LSuite.Results) do
      begin
        LRes := LSuite.Results[J];
        if LRes.Status in [tsFailed, tsError] then
        begin
          Inc(LFailIdx);
          LOutSink.WriteLn('');
          LOutSink.WriteLn('  ' + AnsiBold(IntToStr(LFailIdx) + ')', LConfig) +
            ' ' + AnsiCyan(LSuite.SuiteName, LConfig) +
            ' > ' + AnsiRed(LRes.Name, LConfig));
          if LRes.Message <> '' then
            LOutSink.WriteLn('    ' + FormatFailDetail(LRes.Message, LConfig));
        end;
      end;
    end;
    LOutSink.WriteLn('');
    LOutSink.WriteLn(
      AnsiDim('  ' + IntToStr(LFailIdx) + ' failure(s) in ' +
        IntToStr(TotalPass + TotalFail + TotalSkip) + ' tests', LConfig));
  end;
end;

function TSuiteRunner.AllPassed: Boolean;
begin
  if HasRun then
    Result := TotalFail = 0
  else
    Result := RunAll;
end;

end.
