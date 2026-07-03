{ nextpas.core.test — Advanced Pascal Unit Testing Framework (facade)
  =========================================================
  Re-exports all public API from sub-modules:
    test.base, test.check, test.config, test.expect, test.output,
    test.output.tap, test.output.json, test.runner, test.discovery,
    test.mock, test.helpers
  White-box modules (not re-exported — import directly for internals):
    test.runner.cli, test.runner.context, test.runner.parallel
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
function ExpectStr(const AValue: string): IExpectation;
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
procedure CheckNearRel(const AExpected, AActual: Double;
  const ARelEps: Double = 1e-9; const AMessage: string = '');
procedure CheckNotNearRel(const AExpected, AActual: Double;
  const ARelEps: Double = 1e-9; const AMessage: string = '');
procedure Fail(const AMessage: string);
procedure FailUnexpected(const E: Exception);
procedure Skip(const AReason: string = '');
procedure SleepMs(AMilliseconds: Integer);
procedure CheckSnapshot(const AActual: string;
  const ASnapshotDir, ASnapshotName: string);

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
  TMockValues = nextpas.core.test.mock.TMockValues;
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

{$I nextpas.core.test.fwd.expect.inc}
{$I nextpas.core.test.fwd.check.inc}
{$I nextpas.core.test.fwd.output.inc}
{$I nextpas.core.test.fwd.other.inc}

end.
