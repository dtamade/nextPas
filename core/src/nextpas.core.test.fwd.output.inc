{ ── Forward to test.output ────────────────────────────────────────────────── }

function AnsiBold(const S: string): string;
begin Result := nextpas.core.test.output.AnsiBold(S); end;

function AnsiGreen(const S: string): string;
begin Result := nextpas.core.test.output.AnsiGreen(S); end;

function AnsiRed(const S: string): string;
begin Result := nextpas.core.test.output.AnsiRed(S); end;

function AnsiYellow(const S: string): string;
begin Result := nextpas.core.test.output.AnsiYellow(S); end;

function AnsiCyan(const S: string): string;
begin Result := nextpas.core.test.output.AnsiCyan(S); end;

function AnsiDim(const S: string): string;
begin Result := nextpas.core.test.output.AnsiDim(S); end;

procedure SetAnsiEnabled(AEnabled: Boolean);
begin nextpas.core.test.output.SetAnsiEnabled(AEnabled); end;

function StatusDot(AStatus: TTestStatus): string;
begin Result := nextpas.core.test.output.StatusDot(AStatus); end;

procedure FailTest(const AMsg: string);
begin nextpas.core.test.output.FailTest(AMsg); end;

procedure PassTest(const AMsg: string);
begin nextpas.core.test.output.PassTest(AMsg); end;

procedure SectionHeader(const ATitle: string);
begin nextpas.core.test.output.SectionHeader(ATitle); end;

procedure SetTestFilter(const APattern: string);
begin nextpas.core.test.output.SetTestFilter(APattern); end;

function GetTestFilter: string;
begin Result := nextpas.core.test.output.GetTestFilter; end;

function MatchesFilter(const AName: string): Boolean;
begin Result := nextpas.core.test.output.MatchesFilter(AName); end;

function MatchesFilter(const AName: string; const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.output.MatchesFilter(AName, AConfig); end;

procedure SetTagFilter(const APattern: string);
begin nextpas.core.test.output.SetTagFilter(APattern); end;

function GetTagFilter: string;
begin Result := nextpas.core.test.output.GetTagFilter; end;

procedure SetRunPattern(const APattern: string);
begin nextpas.core.test.config.SetDefaultRunPattern(APattern); end;

function GetRunPattern: string;
begin Result := nextpas.core.test.config.GetRunPattern(nextpas.core.test.config.DefaultConfig); end;

procedure SetTestTimeout(AMillis: Integer);
begin nextpas.core.test.output.SetTestTimeout(AMillis); end;

function GetTestTimeout: Integer;
begin Result := nextpas.core.test.output.GetTestTimeout; end;

procedure ReportLeakIfAny(AStatus: TTestStatus);
begin nextpas.core.test.output.ReportLeakIfAny(AStatus); end;

procedure SetHeapProbe(AProbe: THeapProbeFunc);
begin nextpas.core.test.output.SetHeapProbe(AProbe); end;

function GetHeapProbe: THeapProbeFunc;
begin Result := nextpas.core.test.output.GetHeapProbe; end;

procedure NoteHeapBaseline;
begin nextpas.core.test.output.NoteHeapBaseline; end;

function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
begin Result := nextpas.core.test.output.JUnitXML(AResults, ASuiteName); end;

function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string): Boolean;
begin Result := nextpas.core.test.output.WriteJUnitXML(AResults, AFileName, ASuiteName); end;

{ ── Forward to test.config ────────────────────────────────────────────────── }

function DefaultConfig: TTestConfig;
begin Result := nextpas.core.test.config.DefaultConfig; end;

procedure ResetDefaultConfig;
begin nextpas.core.test.config.ResetDefaultConfig; end;

procedure SetDefaultErrSink(const ASink: IOutputSink);
begin nextpas.core.test.config.SetDefaultErrSink(ASink); end;

procedure SetDefaultOutSink(const ASink: IOutputSink);
begin nextpas.core.test.config.SetDefaultOutSink(ASink); end;

procedure SetDefaultRetryCount(ARetryCount: Integer);
begin nextpas.core.test.config.SetDefaultRetryCount(ARetryCount); end;

procedure SetDefaultMaxParallelWorkers(AMaxWorkers: Integer);
begin nextpas.core.test.config.SetDefaultMaxParallelWorkers(AMaxWorkers); end;

procedure SetDefaultRepeatAllCount(ARepeatCount: Integer);
begin nextpas.core.test.config.SetDefaultRepeatAllCount(ARepeatCount); end;

procedure SetDefaultSlowTestCount(ACount: Integer);
begin nextpas.core.test.config.SetDefaultSlowTestCount(ACount); end;

function GetRepeatAllCount(const AConfig: TTestConfig): Integer;
begin Result := nextpas.core.test.config.GetRepeatAllCount(AConfig); end;

function GetSlowTestCount(const AConfig: TTestConfig): Integer;
begin Result := nextpas.core.test.config.GetSlowTestCount(AConfig); end;

function GetShuffleSeed(const AConfig: TTestConfig): Integer;
begin Result := nextpas.core.test.config.GetShuffleSeed(AConfig); end;

function GetFailFast(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetFailFast(AConfig); end;

function GetListMode(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetListMode(AConfig); end;

procedure SetDefaultShuffleSeed(ASeed: Integer);
begin nextpas.core.test.config.SetDefaultShuffleSeed(ASeed); end;

procedure SetDefaultFailFast(AFailFast: Boolean);
begin nextpas.core.test.config.SetDefaultFailFast(AFailFast); end;

procedure SetDefaultListMode(AListMode: Boolean);
begin nextpas.core.test.config.SetDefaultListMode(AListMode); end;

procedure SetDefaultShortMode(AShortMode: Boolean);
begin nextpas.core.test.config.SetDefaultShortMode(AShortMode); end;

procedure SetDefaultShowProgress(AShowProgress: Boolean);
begin nextpas.core.test.config.SetDefaultShowProgress(AShowProgress); end;

procedure SetDefaultMaxFailures(AMaxFailures: Integer);
begin nextpas.core.test.config.SetDefaultMaxFailures(AMaxFailures); end;

procedure SetDefaultJsonOutput(AJsonOutput: Boolean);
begin nextpas.core.test.config.SetDefaultJsonOutput(AJsonOutput); end;

procedure SetDefaultVerboseMode(AVerbose: Boolean);
begin nextpas.core.test.config.SetDefaultVerboseMode(AVerbose); end;

procedure SetDefaultRunTimeoutSec(ATimeoutSec: Integer);
begin nextpas.core.test.config.SetDefaultRunTimeoutSec(ATimeoutSec); end;

procedure SetDefaultBenchEnabled(AEnabled: Boolean);
begin nextpas.core.test.config.SetDefaultBenchEnabled(AEnabled); end;

procedure SetDefaultBenchTimeMs(ATimeMs: Integer);
begin nextpas.core.test.config.SetDefaultBenchTimeMs(ATimeMs); end;

procedure SetDefaultBenchMem(ABenchMem: Boolean);
begin nextpas.core.test.config.SetDefaultBenchMem(ABenchMem); end;

function GetShortMode(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetShortMode(AConfig); end;

function GetShowProgress(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetShowProgress(AConfig); end;

function GetMaxFailures(const AConfig: TTestConfig): Integer;
begin Result := nextpas.core.test.config.GetMaxFailures(AConfig); end;

function GetJsonOutput(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetJsonOutput(AConfig); end;

function GetVerboseMode(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetVerboseMode(AConfig); end;

function GetRunTimeoutSec(const AConfig: TTestConfig): Integer;
begin Result := nextpas.core.test.config.GetRunTimeoutSec(AConfig); end;

function GetBenchEnabled(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetBenchEnabled(AConfig); end;

function GetBenchTimeMs(const AConfig: TTestConfig): Integer;
begin Result := nextpas.core.test.config.GetBenchTimeMs(AConfig); end;

function GetBenchMem(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetBenchMem(AConfig); end;

procedure SetDefaultCacheEnabled(AEnabled: Boolean);
begin nextpas.core.test.config.SetDefaultCacheEnabled(AEnabled); end;

procedure SetDefaultCacheDir(const ADir: string);
begin nextpas.core.test.config.SetDefaultCacheDir(ADir); end;

function GetCacheEnabled(const AConfig: TTestConfig): Boolean;
begin Result := nextpas.core.test.config.GetCacheEnabled(AConfig); end;

function GetCacheDir(const AConfig: TTestConfig): string;
begin Result := nextpas.core.test.config.GetCacheDir(AConfig); end;

function GetConfigVersion(const AConfig: TTestConfig): Integer;
begin Result := nextpas.core.test.config.GetConfigVersion(AConfig); end;

function FormatDuration(AMillis: Int64): string;
begin Result := nextpas.core.test.output.FormatDuration(AMillis); end;

function GetTopSlowest(const AResults: TTestResults;
  ACount: Integer): TTestResults;
begin Result := nextpas.core.test.base.GetTopSlowest(AResults, ACount); end;

function MakeTestResult(const AName: string; AStatus: TTestStatus;
  const AMessage: string; ADuration: Int64): TTestResult;
begin Result := nextpas.core.test.base.MakeTestResult(AName, AStatus, AMessage, ADuration); end;

procedure ShuffleEntries(var AEntries: specialize TArray<TTestEntry>;
  ASeed: Integer);
begin nextpas.core.test.base.ShuffleEntries(AEntries, ASeed); end;
