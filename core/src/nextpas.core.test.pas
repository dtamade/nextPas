{ nextpas.core.test — Advanced Pascal Unit Testing Framework (facade)
  =========================================================
  Re-exports all public API from sub-modules:
    test.base, test.check, test.config, test.expect, test.output,
    test.output.tap, test.output.json, test.runner, test.discovery,
    test.mock, test.helpers
  White-box modules (not re-exported — import directly for internals):
    test.runner.context, test.runner.parallel
  Dual API: procedural Check* + fluent IExpectation chain.
  Parallel execution, subtests, ANSI output, leak detection,
  RTTI discovery, retry, TAP/JSON/JUnit output, mock framework. }

unit nextpas.core.test;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.config,
  nextpas.core.test.expect,
  nextpas.core.test.output,
  nextpas.core.test.output.tap,
  nextpas.core.test.output.json,
  nextpas.core.test.runner,
  nextpas.core.test.discovery,
  nextpas.core.test.mock,
  nextpas.core.test.helpers;

{ ── Re-exported types from test.base ─────────────────────────────────────── }

type
  ExceptClass = nextpas.core.test.base.ExceptClass;
  Exception = nextpas.core.system.Exception;
  EAbort = nextpas.core.system.EAbort;
  EAssertionFailed = nextpas.core.system.EAssertionFailed;
  EConvertError = nextpas.core.system.EConvertError;
  TTestProc = nextpas.core.test.base.TTestProc;
  TTestClosure = nextpas.core.test.base.TTestClosure;
  ITestContext = nextpas.core.test.base.ITestContext;
  TSubtestProc = nextpas.core.test.base.TSubtestProc;
  TTestCase = nextpas.core.test.base.TTestCase;
  TTestCaseProc = nextpas.core.test.base.TTestCaseProc;
  TTestStatus = nextpas.core.test.base.TTestStatus;
  TTestResult = nextpas.core.test.base.TTestResult;
  TTestRunResult = nextpas.core.test.base.TTestRunResult;
  ETestSkipped = nextpas.core.test.base.ETestSkipped;
  TTestEntryKind = nextpas.core.test.base.TTestEntryKind;
  TTestEntry = nextpas.core.test.base.TTestEntry;
  TBenchProc = nextpas.core.test.base.TBenchProc;
  TBenchContext = nextpas.core.test.base.TBenchContext;
  PBenchContext = nextpas.core.test.base.PBenchContext;
  TBenchResult = nextpas.core.test.base.TBenchResult;
  TBenchResults = nextpas.core.test.base.TBenchResults;
  TAnsiMode = nextpas.core.test.config.TAnsiMode;
  TConfigKey = nextpas.core.test.config.TConfigKey;
  TConfigKeys = nextpas.core.test.config.TConfigKeys;
  IOutputSink = nextpas.core.test.config.IOutputSink;
  TStringLines = nextpas.core.test.config.TStringLines;
  TStdoutSink = nextpas.core.test.config.TStdoutSink;
  TStderrSink = nextpas.core.test.config.TStderrSink;
  TBufferSink = nextpas.core.test.config.TBufferSink;
  TTestConfig = nextpas.core.test.config.TTestConfig;

const
  tsPassed  = nextpas.core.test.base.tsPassed;
  tsFailed  = nextpas.core.test.base.tsFailed;
  tsSkipped = nextpas.core.test.base.tsSkipped;
  tsError   = nextpas.core.test.base.tsError;
  ekTest    = nextpas.core.test.base.ekTest;
  ekSubtest = nextpas.core.test.base.ekSubtest;
  ekSkipped = nextpas.core.test.base.ekSkipped;
  ekTableTest = nextpas.core.test.base.ekTableTest;
  ekShouldFail = nextpas.core.test.base.ekShouldFail;
  ekBench    = nextpas.core.test.base.ekBench;
  amAuto = nextpas.core.test.config.amAuto;
  amOn = nextpas.core.test.config.amOn;
  amOff = nextpas.core.test.config.amOff;
  mvUnset  = nextpas.core.test.mock.mvUnset;
  mvString = nextpas.core.test.mock.mvString;
  mvInt64  = nextpas.core.test.mock.mvInt64;
  mvBool   = nextpas.core.test.mock.mvBool;
  mvDouble = nextpas.core.test.mock.mvDouble;

{ ── Re-exported types from test.expect ────────────────────────────────────── }

type
  IExpectation = nextpas.core.test.expect.IExpectation;

{ ── Re-exported types from test.runner ────────────────────────────────────── }

type
  TTestSuite = nextpas.core.test.runner.TTestSuite;
  TTestRunner = nextpas.core.test.runner.TTestRunner;

{ ── Re-exported functions from test.expect ────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
function ExpectInt(const AValue: Int64): IExpectation;
function ExpectBool(AValue: Boolean): IExpectation;
function ExpectDouble(const AValue: Double): IExpectation;
function ExpectPtr(const AValue: Pointer): IExpectation;
function ExpectProc(AProc: TTestProc): IExpectation;

{ ── Re-exported functions from test.check ─────────────────────────────────── }

procedure Check(ACondition: Boolean; const AMessage: string = '');
procedure CheckEqual(const AExpected, AActual: string); overload;
procedure CheckEqual(const AExpected, AActual: Int64); overload;
procedure CheckEqual(const AExpected, AActual: Boolean); overload;
procedure CheckEqual(const AExpected, AActual: Pointer); overload;
procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
procedure CheckNotEqual(const AExpected, AActual: string); overload;
procedure CheckNotEqual(const AExpected, AActual: Int64); overload;
procedure CheckNotEqual(const AExpected, AActual: Boolean); overload;
procedure CheckNotEqual(const AExpected, AActual: Pointer); overload;
procedure CheckNotEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
procedure CheckTrue(AValue: Boolean; const AMessage: string = '');
procedure CheckFalse(AValue: Boolean; const AMessage: string = '');
procedure CheckNil(AValue: Pointer; const AMessage: string = '');
procedure CheckNotNil(AValue: Pointer; const AMessage: string = '');
procedure CheckContains(const AHaystack, ANeedle: string);
procedure CheckNotContains(const AHaystack, ANeedle: string);
procedure CheckStartsWith(const AStr, APrefix: string);
procedure CheckEndsWith(const AStr, ASuffix: string);
procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string = '');
procedure CheckInRange(const AValue, ALow, AHigh: Int64);
procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckGreaterThan(const AValue, AExpected: Int64);
procedure CheckLessThan(const AValue, AExpected: Int64);
procedure CheckGreaterOrEqual(const AValue, AExpected: Int64);
procedure CheckLessOrEqual(const AValue, AExpected: Int64);
procedure CheckGreaterThanD(const AValue, AExpected: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckLessThanD(const AValue, AExpected: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckGreaterOrEqualD(const AValue, AExpected: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckLessOrEqualD(const AValue, AExpected: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckContainsCI(const AHaystack, ANeedle: string);
procedure CheckNotContainsCI(const AHaystack, ANeedle: string);
procedure CheckStartsWithCI(const AStr, APrefix: string);
procedure CheckEndsWithCI(const AStr, ASuffix: string);
procedure CheckNotStartsWith(const AStr, APrefix: string);
procedure CheckNotEndsWith(const AStr, ASuffix: string);
procedure CheckLength(const AExpected, AActual: NativeInt);
procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string = '');
procedure CheckNoRaise(AProc: TTestProc; const AMessage: string = '');
procedure CheckNear(const AExpected, AActual: Double;
  const AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure CheckNotNear(const AExpected, AActual: Double;
  const AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure Fail(const AMessage: string);
procedure FailUnexpected(const E: Exception);
procedure Skip(const AReason: string = '');
procedure SleepMs(AMilliseconds: Integer);

{ ── Re-exported from test.base (stack trace) ─────────────────────────────── }

function  GetLastTestTrace: string;
function  FormatTestLocation(APrefix: string = ''): string;

{ ── Re-exported functions from test.output ────────────────────────────────── }

function AnsiBold(const S: string): string;
function AnsiGreen(const S: string): string;
function AnsiRed(const S: string): string;
function AnsiYellow(const S: string): string;
function AnsiCyan(const S: string): string;
function AnsiDim(const S: string): string;
procedure SetAnsiEnabled(AEnabled: Boolean);
function  StatusDot(AStatus: TTestStatus): string;
procedure FailTest(const AMsg: string);
procedure PassTest(const AMsg: string);
procedure SectionHeader(const ATitle: string);
procedure SetTestFilter(const APattern: string);
function  GetTestFilter: string;
function  MatchesFilter(const AName: string): Boolean;
function  MatchesFilter(const AName: string; const AConfig: TTestConfig): Boolean;
procedure SetTagFilter(const APattern: string);
function  GetTagFilter: string;
procedure SetRunPattern(const APattern: string);
function  GetRunPattern: string;
procedure SetTestTimeout(AMillis: Integer);
function  GetTestTimeout: Integer;
procedure ReportLeakIfAny(AStatus: TTestStatus);
function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string = ''): string;
function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string = ''): Boolean;
function DefaultConfig: TTestConfig;
procedure ResetDefaultConfig;
procedure SetDefaultErrSink(const ASink: IOutputSink);
procedure SetDefaultOutSink(const ASink: IOutputSink);
procedure SetDefaultRetryCount(ARetryCount: Integer);
procedure SetDefaultMaxParallelWorkers(AMaxWorkers: Integer);
procedure SetDefaultRepeatAllCount(ARepeatCount: Integer);
procedure SetDefaultSlowTestCount(ACount: Integer);
procedure SetDefaultShuffleSeed(ASeed: Integer);
procedure SetDefaultFailFast(AFailFast: Boolean);
procedure SetDefaultListMode(AListMode: Boolean);
procedure SetDefaultShortMode(AShortMode: Boolean);
procedure SetDefaultShowProgress(AShowProgress: Boolean);
procedure SetDefaultMaxFailures(AMaxFailures: Integer);
procedure SetDefaultJsonOutput(AJsonOutput: Boolean);
procedure SetDefaultVerboseMode(AVerbose: Boolean);
procedure SetDefaultRunTimeoutSec(ATimeoutSec: Integer);
procedure SetDefaultBenchEnabled(AEnabled: Boolean);
procedure SetDefaultBenchTimeMs(ATimeMs: Integer);
procedure SetDefaultBenchMem(ABenchMem: Boolean);
function  GetRepeatAllCount(const AConfig: TTestConfig): Integer;
function  GetSlowTestCount(const AConfig: TTestConfig): Integer;
function  GetShuffleSeed(const AConfig: TTestConfig): Integer;
function  GetFailFast(const AConfig: TTestConfig): Boolean;
function  GetListMode(const AConfig: TTestConfig): Boolean;
function  GetShortMode(const AConfig: TTestConfig): Boolean;
function  GetShowProgress(const AConfig: TTestConfig): Boolean;
function  GetMaxFailures(const AConfig: TTestConfig): Integer;
function  GetJsonOutput(const AConfig: TTestConfig): Boolean;
function  GetVerboseMode(const AConfig: TTestConfig): Boolean;
function  GetRunTimeoutSec(const AConfig: TTestConfig): Integer;
function  GetBenchEnabled(const AConfig: TTestConfig): Boolean;
function  GetBenchTimeMs(const AConfig: TTestConfig): Integer;
function  GetBenchMem(const AConfig: TTestConfig): Boolean;
function  FormatDuration(AMillis: Int64): string;
function  GetTopSlowest(const AResults: TTestResults;
  ACount: Integer): TTestResults;
function  MakeTestResult(const AName: string; AStatus: TTestStatus;
  const AMessage: string; ADuration: Int64): TTestResult;
procedure ShuffleEntries(var AEntries: specialize TArray<TTestEntry>;
  ASeed: Integer);

type
  TTestResults = nextpas.core.test.base.TTestResults;

{ ── Re-exported types from test.discovery ──────────────────────────────────── }

type
  TTestFixture = nextpas.core.test.discovery.TTestFixture;
  TTestFixtureClass = nextpas.core.test.discovery.TTestFixtureClass;

function DiscoverTests(AFixture: TTestFixture;
  const ASuiteName: string = ''): TTestSuite;

{ ── Re-exported from test.output.tap ──────────────────────────────────────── }

function TAPReport(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string = ''): string;

{ ── Re-exported from test.output.json ─────────────────────────────────────── }

function JSONReport(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string = ''): string;

{ ── Re-exported types from test.mock ──────────────────────────────────────── }

type
  TMockValueKind = nextpas.core.test.mock.TMockValueKind;
  TMockCall = nextpas.core.test.mock.TMockCall;
  TMock = nextpas.core.test.mock.TMock;
  TMockState = nextpas.core.test.mock.TMockState;
  TMockValue = nextpas.core.test.mock.TMockValue;
  TMockCalls = nextpas.core.test.mock.TMockCalls;
  IMockSetup = nextpas.core.test.mock.IMockSetup;
  IMockVerify = nextpas.core.test.mock.IMockVerify;

function MockStr(const AValue: string): TMockValue;
function MockInt(const AValue: Int64): TMockValue;
function MockBool(AValue: Boolean): TMockValue;
function MockDouble(const AValue: Double): TMockValue;

{ ── Re-exported types from test.helpers ─────────────────────────────────── }

type
  TMockProc = nextpas.core.test.helpers.TMockProc;

{ ── Re-exported functions from test.helpers ─────────────────────────────── }

procedure ExpectFail(AProc: TTestClosure;
  const AContains: string = '');
procedure WithMock(AProc: TMockProc);
procedure ExpectFailWithMock(AProc: TMockProc;
  const AContains: string = '');
function MakeBufferConfig(out ASink: TBufferSink): TTestConfig;

implementation

{ ── Forward to test.expect ────────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
begin Result := nextpas.core.test.expect.Expect(AValue); end;

function ExpectInt(const AValue: Int64): IExpectation;
begin Result := nextpas.core.test.expect.ExpectInt(AValue); end;

function ExpectBool(AValue: Boolean): IExpectation;
begin Result := nextpas.core.test.expect.ExpectBool(AValue); end;

function ExpectDouble(const AValue: Double): IExpectation;
begin Result := nextpas.core.test.expect.ExpectDouble(AValue); end;

function ExpectPtr(const AValue: Pointer): IExpectation;
begin Result := nextpas.core.test.expect.ExpectPtr(AValue); end;

function ExpectProc(AProc: TTestProc): IExpectation;
begin Result := nextpas.core.test.expect.ExpectProc(AProc); end;

{ ── Forward to test.check ─────────────────────────────────────────────────── }

procedure Check(ACondition: Boolean; const AMessage: string);
begin nextpas.core.test.check.Check(ACondition, AMessage); end;

procedure CheckEqual(const AExpected, AActual: string);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: Int64);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: Boolean);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: Pointer);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual, AEpsilon); end;

procedure CheckNotEqual(const AExpected, AActual: string);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: Int64);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: Boolean);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: Pointer);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: Double;
  AEpsilon: Double);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual, AEpsilon); end;

procedure CheckTrue(AValue: Boolean; const AMessage: string);
begin nextpas.core.test.check.CheckTrue(AValue, AMessage); end;

procedure CheckFalse(AValue: Boolean; const AMessage: string);
begin nextpas.core.test.check.CheckFalse(AValue, AMessage); end;

procedure CheckNil(AValue: Pointer; const AMessage: string);
begin nextpas.core.test.check.CheckNil(AValue, AMessage); end;

procedure CheckNotNil(AValue: Pointer; const AMessage: string);
begin nextpas.core.test.check.CheckNotNil(AValue, AMessage); end;

procedure CheckContains(const AHaystack, ANeedle: string);
begin nextpas.core.test.check.CheckContains(AHaystack, ANeedle); end;

procedure CheckNotContains(const AHaystack, ANeedle: string);
begin nextpas.core.test.check.CheckNotContains(AHaystack, ANeedle); end;

procedure CheckStartsWith(const AStr, APrefix: string);
begin nextpas.core.test.check.CheckStartsWith(AStr, APrefix); end;

procedure CheckEndsWith(const AStr, ASuffix: string);
begin nextpas.core.test.check.CheckEndsWith(AStr, ASuffix); end;

procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string);
begin nextpas.core.test.check.CheckSame(AExpected, AActual, AMessage); end;

procedure CheckInRange(const AValue, ALow, AHigh: Int64);
begin nextpas.core.test.check.CheckInRange(AValue, ALow, AHigh); end;

procedure CheckGreaterThan(const AValue, AExpected: Int64);
begin nextpas.core.test.check.CheckGreaterThan(AValue, AExpected); end;

procedure CheckLessThan(const AValue, AExpected: Int64);
begin nextpas.core.test.check.CheckLessThan(AValue, AExpected); end;

procedure CheckGreaterOrEqual(const AValue, AExpected: Int64);
begin nextpas.core.test.check.CheckGreaterOrEqual(AValue, AExpected); end;

procedure CheckLessOrEqual(const AValue, AExpected: Int64);
begin nextpas.core.test.check.CheckLessOrEqual(AValue, AExpected); end;

procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckInRangeD(AValue, ALow, AHigh, AEpsilon); end;

procedure CheckGreaterThanD(const AValue, AExpected: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckGreaterThanD(AValue, AExpected, AEpsilon); end;

procedure CheckLessThanD(const AValue, AExpected: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckLessThanD(AValue, AExpected, AEpsilon); end;

procedure CheckGreaterOrEqualD(const AValue, AExpected: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckGreaterOrEqualD(AValue, AExpected, AEpsilon); end;

procedure CheckLessOrEqualD(const AValue, AExpected: Double;
  const AEpsilon: Double);
begin nextpas.core.test.check.CheckLessOrEqualD(AValue, AExpected, AEpsilon); end;

procedure CheckContainsCI(const AHaystack, ANeedle: string);
begin nextpas.core.test.check.CheckContainsCI(AHaystack, ANeedle); end;

procedure CheckNotContainsCI(const AHaystack, ANeedle: string);
begin nextpas.core.test.check.CheckNotContainsCI(AHaystack, ANeedle); end;

procedure CheckStartsWithCI(const AStr, APrefix: string);
begin nextpas.core.test.check.CheckStartsWithCI(AStr, APrefix); end;

procedure CheckEndsWithCI(const AStr, ASuffix: string);
begin nextpas.core.test.check.CheckEndsWithCI(AStr, ASuffix); end;

procedure CheckNotStartsWith(const AStr, APrefix: string);
begin nextpas.core.test.check.CheckNotStartsWith(AStr, APrefix); end;

procedure CheckNotEndsWith(const AStr, ASuffix: string);
begin nextpas.core.test.check.CheckNotEndsWith(AStr, ASuffix); end;

procedure CheckLength(const AExpected, AActual: NativeInt);
begin nextpas.core.test.check.CheckLength(AExpected, AActual); end;

procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string);
begin nextpas.core.test.check.CheckRaises(AExceptionClass, AProc, AMessage); end;

procedure CheckNoRaise(AProc: TTestProc; const AMessage: string);
begin nextpas.core.test.check.CheckNoRaise(AProc, AMessage); end;

procedure CheckNear(const AExpected, AActual: Double;
  const AEpsilon: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNear(AExpected, AActual, AEpsilon, AMessage); end;

procedure CheckNotNear(const AExpected, AActual: Double;
  const AEpsilon: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNotNear(AExpected, AActual, AEpsilon, AMessage); end;

procedure Fail(const AMessage: string);
begin nextpas.core.test.check.Fail(AMessage); end;

procedure FailUnexpected(const E: Exception);
begin nextpas.core.test.check.FailUnexpected(E); end;

procedure Skip(const AReason: string);
begin nextpas.core.test.check.Skip(AReason); end;

procedure SleepMs(AMilliseconds: Integer);
begin nextpas.core.test.base.SleepMs(AMilliseconds); end;

{ ── Forward to test.base (stack trace) ───────────────────────────────────── }

function GetLastTestTrace: string;
begin Result := nextpas.core.test.base.GetLastTestTrace; end;

function FormatTestLocation(APrefix: string): string;
begin Result := nextpas.core.test.base.FormatTestLocation(APrefix); end;

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

function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
begin Result := nextpas.core.test.output.JUnitXML(AResults, ASuiteName); end;

function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string): Boolean;
begin Result := nextpas.core.test.output.WriteJUnitXML(AResults, AFileName, ASuiteName); end;

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

{ ── Forward to test.discovery ──────────────────────────────────────────────── }

function DiscoverTests(AFixture: TTestFixture;
  const ASuiteName: string): TTestSuite;
begin Result := nextpas.core.test.discovery.DiscoverTests(AFixture, ASuiteName); end;

{ ── Forward to test.output.tap ─────────────────────────────────────────────── }

function TAPReport(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
begin Result := nextpas.core.test.output.tap.TAPReport(AResults, ASuiteName); end;

{ ── Forward to test.output.json ────────────────────────────────────────────── }

function JSONReport(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
begin Result := nextpas.core.test.output.json.JSONReport(AResults, ASuiteName); end;

{ ── Forward to test.mock (helper functions) ────────────────────────────────── }

function MockStr(const AValue: string): TMockValue;
begin Result := nextpas.core.test.mock.MockStr(AValue); end;

function MockInt(const AValue: Int64): TMockValue;
begin Result := nextpas.core.test.mock.MockInt(AValue); end;

function MockBool(AValue: Boolean): TMockValue;
begin Result := nextpas.core.test.mock.MockBool(AValue); end;

function MockDouble(const AValue: Double): TMockValue;
begin Result := nextpas.core.test.mock.MockDouble(AValue); end;

{ ── Forward to test.helpers ──────────────────────────────────────────────── }

procedure ExpectFail(AProc: TTestClosure;
  const AContains: string);
begin nextpas.core.test.helpers.ExpectFail(AProc, AContains); end;

procedure WithMock(AProc: TMockProc);
begin nextpas.core.test.helpers.WithMock(AProc); end;

procedure ExpectFailWithMock(AProc: TMockProc;
  const AContains: string);
begin nextpas.core.test.helpers.ExpectFailWithMock(AProc, AContains); end;

function MakeBufferConfig(out ASink: TBufferSink): TTestConfig;
begin Result := nextpas.core.test.helpers.MakeBufferConfig(ASink); end;

end.
