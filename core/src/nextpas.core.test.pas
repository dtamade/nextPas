{ nextpas.core.test — Advanced Pascal Unit Testing Framework (facade)
  =========================================================
  Re-exports all public API from sub-modules:
    test.base, test.check, test.config, test.expect, test.output,
    test.output.tap, test.output.json, test.runner, test.runner.multi,
    test.discovery, test.mock, test.helpers, test.prop.gen, test.prop,
    test.fuzz
  White-box / optional (import directly when needed):
    test.runner.cli, test.runner.context, test.runner.parallel,
    test.bench (bench integration — optional side unit, F-04),
    test.diff, test.snapshot (shared L0/L1 internals)
  Dual API: procedural Check* + fluent IExpectation chain.
  Parallel execution, subtests, ANSI output, optional leak probe,
  RTTI discovery, retry, TAP/JSON/JUnit output, mock framework,
  property-based testing.
  Note: FuzzParallel is deprecated alias of sequential FuzzMultiStrategy (F-07). }

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
  nextpas.core.test.runner.multi,
  nextpas.core.test.discovery,
  nextpas.core.test.mock,
  nextpas.core.test.helpers,
  nextpas.core.test.prop.gen,
  nextpas.core.test.prop,
  nextpas.core.test.fuzz;

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
  TBenchContext = nextpas.core.test.base.TBenchContext;
  TBenchResult = nextpas.core.test.base.TBenchResult;
  TAnsiMode = nextpas.core.test.config.TAnsiMode;
  TConfigKey = nextpas.core.test.config.TConfigKey;
  TConfigKeys = nextpas.core.test.config.TConfigKeys;
  IOutputSink = nextpas.core.test.config.IOutputSink;
  TStringLines = nextpas.core.test.config.TStringLines;
  TStdoutSink = nextpas.core.test.config.TStdoutSink;
  TStderrSink = nextpas.core.test.config.TStderrSink;
  TBufferSink = nextpas.core.test.config.TBufferSink;
  TTestConfig = nextpas.core.test.config.TTestConfig;
  TTestConfigBuilder = nextpas.core.test.config.TTestConfigBuilder;
  TCacheEntry = nextpas.core.test.config.TCacheEntry;
  TTestCache = nextpas.core.test.config.TTestCache;
  { Optional host heap probe (F-05) }
  THeapProbeFunc = nextpas.core.test.output.THeapProbeFunc;

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
  TSuiteRunner = nextpas.core.test.runner.multi.TSuiteRunner;

{ v8.25: timeout-worker leak counter (parallel/serial timeout path). }
function GetTimeoutWorkerLeakCount: Integer;
procedure ResetTimeoutWorkerLeakCount;

{ ── Re-exported functions from test.expect ────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
function ExpectStr(const AValue: string): IExpectation;
function ExpectInt(const AValue: Int64): IExpectation;
function ExpectBool(AValue: Boolean): IExpectation;
function ExpectDouble(const AValue: Double): IExpectation;
function ExpectPtr(const AValue: Pointer): IExpectation;
function ExpectObj(const AValue: TObject): IExpectation;
function ExpectProc(AProc: TTestProc): IExpectation;
function ExpectBytes(const AValue: TBytes): IExpectation;
function ExpectArrayOfInt(const AValues: array of Int64): IExpectation;
function ExpectArrayOfStr(const AValues: array of string): IExpectation;

{ ── Re-exported functions from test.check ─────────────────────────────────── }

procedure Check(ACondition: Boolean; const AMessage: string = '');
procedure CheckEqual(const AExpected, AActual: string); overload;
procedure CheckEqual(const AExpected, AActual: Int64); overload;
procedure CheckEqual(const AExpected, AActual: Boolean); overload;
procedure CheckEqual(const AExpected, AActual: Pointer); overload;
procedure CheckEqual(const AExpected, AActual: UInt64); overload;
procedure CheckEqual(const AExpected, AActual: TBytes); overload;
procedure CheckEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
{ 3-arg overloads: prepend AMessage on failure (backward compat). }
procedure CheckEqual(const AExpected, AActual: string;
  const AMessage: string); overload;
procedure CheckEqual(const AExpected, AActual: Int64;
  const AMessage: string); overload;
procedure CheckEqual(const AExpected, AActual: Boolean;
  const AMessage: string); overload;
procedure CheckNotEqual(const AExpected, AActual: string); overload;
procedure CheckNotEqual(const AExpected, AActual: string;
  const AMessage: string); overload;
procedure CheckNotEqual(const AExpected, AActual: Int64); overload;
procedure CheckNotEqual(const AExpected, AActual: Int64;
  const AMessage: string); overload;
procedure CheckNotEqual(const AExpected, AActual: Boolean); overload;
procedure CheckNotEqual(const AExpected, AActual: Boolean;
  const AMessage: string); overload;
procedure CheckNotEqual(const AExpected, AActual: Pointer); overload;
procedure CheckNotEqual(const AExpected, AActual: UInt64); overload;
procedure CheckNotEqual(const AExpected, AActual: TBytes); overload;
procedure CheckNotEqual(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10); overload;
procedure CheckTrue(AValue: Boolean; const AMessage: string = '');
procedure CheckFalse(AValue: Boolean; const AMessage: string = '');
procedure CheckNil(AValue: Pointer; const AMessage: string = '');
procedure CheckNotNil(AValue: Pointer; const AMessage: string = '');
procedure CheckContains(const AHaystack, ANeedle: string);
procedure CheckContains(const AHaystack, ANeedle: string;
  const AMessage: string); overload;
procedure CheckNotContains(const AHaystack, ANeedle: string);
procedure CheckNotContains(const AHaystack, ANeedle: string;
  const AMessage: string); overload;
procedure CheckStartsWith(const AStr, APrefix: string);
procedure CheckStartsWith(const AStr, APrefix: string;
  const AMessage: string); overload;
procedure CheckEndsWith(const AStr, ASuffix: string);
procedure CheckEndsWith(const AStr, ASuffix: string;
  const AMessage: string); overload;
procedure CheckSame(const AExpected, AActual: Pointer; const AMessage: string = '');
procedure CheckInRange(const AValue, ALow, AHigh: Int64);
procedure CheckInRange(const AValue, ALow, AHigh: Int64;
  const AMessage: string); overload;
procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckInRangeD(const AValue, ALow, AHigh: Double;
  const AEpsilon: Double; const AMessage: string); overload;
procedure CheckGreaterThan(const AValue, AThreshold: Int64);
procedure CheckGreaterThan(const AValue, AThreshold: Int64;
  const AMessage: string); overload;
procedure CheckLessThan(const AValue, AThreshold: Int64);
procedure CheckLessThan(const AValue, AThreshold: Int64;
  const AMessage: string); overload;
procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64);
procedure CheckGreaterOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string); overload;
procedure CheckLessOrEqual(const AValue, AThreshold: Int64);
procedure CheckLessOrEqual(const AValue, AThreshold: Int64;
  const AMessage: string); overload;
procedure CheckGreaterThanD(const AValue, AThreshold: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckLessThanD(const AValue, AThreshold: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckGreaterOrEqualD(const AValue, AThreshold: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckLessOrEqualD(const AValue, AThreshold: Double;
  const AEpsilon: Double = 1e-10);
procedure CheckContainsCI(const AHaystack, ANeedle: string);
procedure CheckContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string); overload;
procedure CheckNotContainsCI(const AHaystack, ANeedle: string);
procedure CheckNotContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string); overload;
procedure CheckStartsWithCI(const AStr, APrefix: string);
procedure CheckStartsWithCI(const AStr, APrefix: string;
  const AMessage: string); overload;
procedure CheckEndsWithCI(const AStr, ASuffix: string);
procedure CheckEndsWithCI(const AStr, ASuffix: string;
  const AMessage: string); overload;
procedure CheckNotStartsWith(const AStr, APrefix: string);
procedure CheckNotStartsWith(const AStr, APrefix: string;
  const AMessage: string); overload;
procedure CheckNotEndsWith(const AStr, ASuffix: string);
procedure CheckNotEndsWith(const AStr, ASuffix: string;
  const AMessage: string); overload;
procedure CheckLength(const AExpected, AActual: NativeInt);
procedure CheckLength(const AExpected, AActual: NativeInt;
  const AMessage: string); overload;
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
procedure CheckNaN(const AValue: Double; const AMessage: string = '');
procedure CheckNotNaN(const AValue: Double; const AMessage: string = '');
procedure CheckInf(const AValue: Double; const AMessage: string = '');
procedure CheckNotInf(const AValue: Double; const AMessage: string = '');
procedure CheckFinite(const AValue: Double; const AMessage: string = '');

{ ── Regex Matching ──────────────────────────────────────────────────────────── }
procedure CheckMatch(const APattern, AStr: string); overload;
procedure CheckMatch(const APattern, AStr: string;
  const AMessage: string); overload;
procedure CheckNotMatch(const APattern, AStr: string); overload;
procedure CheckNotMatch(const APattern, AStr: string;
  const AMessage: string); overload;

procedure Fail(const AMessage: string);
procedure FailUnexpected(const E: Exception);
{ SoftFail (Go t.Error): record failure without aborting. Check*/Fail stay Fatal. }
procedure SoftFail(const AMessage: string);
procedure SoftCheckTrue(ACondition: Boolean; const AMessage: string = '');
procedure SoftCheckFalse(ACondition: Boolean; const AMessage: string = '');
procedure SoftCheckEqual(const AExpected, AActual: Int64;
  const AMessage: string = ''); overload;
procedure SoftCheckEqual(const AExpected, AActual: string;
  const AMessage: string = ''); overload;
procedure SoftCheckEqual(const AExpected, AActual: Boolean;
  const AMessage: string = ''); overload;
procedure SoftCheckEqual(const AExpected, AActual: TBytes;
  const AMessage: string = ''); overload;
procedure SoftCheckNear(const AExpected, AActual: Double;
  AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure SoftCheckContains(const AHaystack, ANeedle: string;
  const AMessage: string = '');
procedure SoftCheckNil(AValue: Pointer; const AMessage: string = '');
procedure SoftCheckNotNil(AValue: Pointer; const AMessage: string = '');
procedure SoftCheckEmpty(const AValue: string; const AMessage: string = '');
procedure SoftCheckContainsCI(const AHaystack, ANeedle: string;
  const AMessage: string = '');
procedure Skip(const AReason: string = '');
procedure SleepMs(AMilliseconds: Integer);

type
  TReadFileStatus = nextpas.core.test.check.TReadFileStatus;

procedure CheckSnapshot(const AActual: string;
  const ASnapshotDir, ASnapshotName: string);
function ReadFileContents(const APath: string; out AContents: string;
  out AStatus: TReadFileStatus): Boolean; overload;
function ReadFileContents(const APath: string; out AContents: string): Boolean; overload;
procedure WriteFileContents(const APath, AContents: string);

{ ── Array Comparison (v8.0c) ──────────────────────────────────────────────── }
procedure CheckArrayEqual(const AExpected, AActual: array of Int64); overload;
procedure CheckArrayEqual(const AExpected, AActual: array of Int64;
  const AMessage: string); overload;
procedure CheckArrayEqual(const AExpected, AActual: array of string); overload;
procedure CheckArrayEqual(const AExpected, AActual: array of string;
  const AMessage: string); overload;

{ ── Array Containment ──────────────────────────────────────────────────────── }
procedure CheckArrayContains(const AArray: array of string;
  const AValue: string); overload;
procedure CheckArrayContains(const AArray: array of string;
  const AValue: string; const AMessage: string); overload;
procedure CheckArrayContains(const AArray: array of Int64;
  const AValue: Int64); overload;
procedure CheckArrayContains(const AArray: array of Int64;
  const AValue: Int64; const AMessage: string); overload;
procedure CheckArrayContains(const AArray: array of Byte;
  AValue: Byte); overload;
procedure CheckArrayContains(const AArray: array of Byte;
  AValue: Byte; const AMessage: string); overload;
procedure CheckArrayNotContains(const AArray: array of string;
  const AValue: string); overload;
procedure CheckArrayNotContains(const AArray: array of string;
  const AValue: string; const AMessage: string); overload;
procedure CheckArrayNotContains(const AArray: array of Int64;
  const AValue: Int64); overload;
procedure CheckArrayNotContains(const AArray: array of Int64;
  const AValue: Int64; const AMessage: string); overload;
procedure CheckArrayNotContains(const AArray: array of Byte;
  AValue: Byte); overload;
procedure CheckArrayNotContains(const AArray: array of Byte;
  AValue: Byte; const AMessage: string); overload;

{ ── Array Sorted Checks ───────────────────────────────────────────────────── }
procedure CheckSorted(const AArray: array of Int64); overload;
procedure CheckSorted(const AArray: array of Int64;
  const AMessage: string); overload;
procedure CheckSorted(const AArray: array of string); overload;
procedure CheckSorted(const AArray: array of string;
  const AMessage: string); overload;

{ ── Interface Nil Checks (v8.0c) ──────────────────────────────────────────── }
procedure CheckIsNil(const AValue: IInterface; const AMessage: string = '');
procedure CheckIsNotNil(const AValue: IInterface; const AMessage: string = '');

{ ── Emptiness Checks (v8.3) ───────────────────────────────────────────────── }
procedure CheckEmpty(const AValue: string); overload;
procedure CheckEmpty(const AValue: string;
  const AMessage: string); overload;
procedure CheckNotEmpty(const AValue: string); overload;
procedure CheckNotEmpty(const AValue: string;
  const AMessage: string); overload;
procedure CheckEmpty(const AValue: TBytes); overload;
procedure CheckEmpty(const AValue: TBytes;
  const AMessage: string); overload;
procedure CheckNotEmpty(const AValue: TBytes); overload;
procedure CheckNotEmpty(const AValue: TBytes;
  const AMessage: string); overload;

{ ── Set Membership (v8.7) ────────────────────────────────────────────────────── }
procedure CheckOneOf(const AValue: string;
  const AValues: array of string); overload;
procedure CheckOneOf(const AValue: string;
  const AValues: array of string; const AMessage: string); overload;
procedure CheckOneOfInt(const AValue: Int64;
  const AValues: array of Int64); overload;
procedure CheckOneOfInt(const AValue: Int64;
  const AValues: array of Int64; const AMessage: string); overload;
procedure CheckOneOfBool(AValue: Boolean;
  const AValues: array of Boolean); overload;
procedure CheckOneOfBool(AValue: Boolean;
  const AValues: array of Boolean; const AMessage: string); overload;

{ ── Instance Type Check (v8.7) ──────────────────────────────────────────────── }
procedure CheckInstanceOf(AObject: TObject; AClass: TClass); overload;
procedure CheckInstanceOf(AObject: TObject; AClass: TClass;
  const AMessage: string); overload;

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
procedure SetHeapProbe(AProbe: THeapProbeFunc);
function GetHeapProbe: THeapProbeFunc;
procedure NoteHeapBaseline;
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
procedure SetDefaultCacheEnabled(AEnabled: Boolean);
procedure SetDefaultCacheDir(const ADir: string);
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
function  GetCacheEnabled(const AConfig: TTestConfig): Boolean;
function  GetCacheDir(const AConfig: TTestConfig): string;
function  GetConfigVersion(const AConfig: TTestConfig): Integer;
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
  TDiscoveredMethod = nextpas.core.test.discovery.TDiscoveredMethod;
  TDiscoveredMethods = nextpas.core.test.discovery.TDiscoveredMethods;
  ITestDiscoveryBackend = nextpas.core.test.discovery.ITestDiscoveryBackend;

function DiscoverTests(AFixture: TTestFixture;
  const ASuiteName: string = ''): TTestSuite;
function CreateFpcVmtDiscoveryBackend: ITestDiscoveryBackend;
function GetDiscoveryBackend: ITestDiscoveryBackend;
procedure SetDiscoveryBackend(const ABackend: ITestDiscoveryBackend);
procedure ResetDiscoveryBackend;

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
  TMockCaptor = nextpas.core.test.mock.TMockCaptor;
  IMockSetup = nextpas.core.test.mock.IMockSetup;
  IMockWhen = nextpas.core.test.mock.IMockWhen;
  IMockVerify = nextpas.core.test.mock.IMockVerify;

function MockStr(const AValue: string): TMockValue;
function MockInt(const AValue: Int64): TMockValue;
function MockBool(AValue: Boolean): TMockValue;
function MockDouble(const AValue: Double): TMockValue;

{ ── Re-exported types from test.helpers ─────────────────────────────────── }

type
  TMockProc = nextpas.core.test.helpers.TMockProc;
  TTempDirProc = nextpas.core.test.helpers.TTempDirProc;

{ ── Re-exported functions from test.helpers ─────────────────────────────── }

procedure ExpectFail(AProc: TTestClosure;
  const AContains: string = '');
procedure ExpectFailWith(AProc: TTestClosure;
  AExceptionClass: ExceptClass;
  const AContains: string = '');
procedure WithMock(AProc: TMockProc);
procedure ExpectFailWithMock(AProc: TMockProc;
  const AContains: string = '');
function MakeBufferConfig(out ASink: TBufferSink): TTestConfig;
procedure WithTempDir(AProc: TTempDirProc);
{ Returns True if AValue op AOperand would overflow Int64.
  AOp: '+'/'-'/'*' or 'add'/'sub'/'mul'. Utility guard, not an assertion. }
function IntOverflowCheck(AValue: Int64; const AOp: string;
  AOperand: Int64): Boolean;

{ ── Re-exported types from test.prop ───────────────────────────────────────── }

type
  TStringTest = nextpas.core.test.prop.TStringTest;
  TIntTest = nextpas.core.test.prop.TIntTest;
  TBoolTest = nextpas.core.test.prop.TBoolTest;
  TBytesTest = nextpas.core.test.prop.TBytesTest;
  IStringGenerator = nextpas.core.test.prop.gen.IStringGenerator;
  IIntGenerator = nextpas.core.test.prop.gen.IIntGenerator;
  IBoolGenerator = nextpas.core.test.prop.gen.IBoolGenerator;
  IBytesGenerator = nextpas.core.test.prop.gen.IBytesGenerator;
  TIntToString = nextpas.core.test.prop.gen.TIntToString;
  TIntPred = nextpas.core.test.prop.gen.TIntPred;
  TStringPred = nextpas.core.test.prop.gen.TStringPred;
  TBytesPred = nextpas.core.test.prop.gen.TBytesPred;

function GenString(AMinLen, AMaxLen: Integer): IStringGenerator; overload;
function GenString(AMaxLen: Integer = 256): IStringGenerator; overload;
function GenInt(AMin, AMax: Int64): IIntGenerator; overload;
function GenInt(AMax: Int64 = MaxInt): IIntGenerator; overload;
function GenBytes(AMinLen, AMaxLen: Integer): IBytesGenerator; overload;
function GenBytes(AMaxLen: Integer = 256): IBytesGenerator; overload;
function GenBool: IBoolGenerator;
function MapIntToStr(AGen: IIntGenerator; AMap: TIntToString): IStringGenerator;
function FilterInt(AGen: IIntGenerator; APred: TIntPred): IIntGenerator;
function FilterString(AGen: IStringGenerator; APred: TStringPred): IStringGenerator;
function FilterBytes(AGen: IBytesGenerator; APred: TBytesPred): IBytesGenerator;
function GenChoiceInt(const AValues: array of Int64): IIntGenerator;
function GenChoiceString(const AValues: array of string): IStringGenerator;
function GenChoiceBool(const AValues: array of Boolean): IBoolGenerator;
function GenOneOfInt(const AGens: array of IIntGenerator): IIntGenerator;
function GenOneOfString(const AGens: array of IStringGenerator): IStringGenerator;
procedure PropFail(const AMsg: string);
function PropWithResult(const AName: string; ATest: TIntTest;
  AGen: IIntGenerator; ARuns: Integer = 100; AShrink: Boolean = True): string;

{ ── Re-exported structured generators from test.prop (v8.0a) ──────────────── }

type
  TIntArrayTest = nextpas.core.test.prop.TIntArrayTest;
  TTupleTest = nextpas.core.test.prop.TTupleTest;
  IArrayGenerator = nextpas.core.test.prop.gen.IArrayGenerator;
  ITupleGenerator = nextpas.core.test.prop.gen.ITupleGenerator;
  TIntToGenerator = nextpas.core.test.prop.gen.TIntToGenerator;

function GenArray(AGen: IIntGenerator; AMaxLen: Integer = 100): IArrayGenerator; overload;
function GenArray(AGen: IIntGenerator; AMinLen, AMaxLen: Integer): IArrayGenerator; overload;
function GenTuple(AGen1: IIntGenerator; AGen2: IStringGenerator): ITupleGenerator;
function BindInt(AGen: IIntGenerator; AFn: TIntToGenerator): IIntGenerator;
procedure PropArray(const AName: string; ATest: TIntArrayTest;
  AGen: IArrayGenerator; ARuns: Integer = 100; AShrink: Boolean = True);
procedure PropTuple(const AName: string; ATest: TTupleTest;
  AGen: ITupleGenerator; ARuns: Integer = 100);

{ ── Re-exported fuzzing from test.prop (v7.2a) ───────────────────────────── }

type
  TFuzzBytesTest = nextpas.core.test.fuzz.TFuzzBytesTest;
  TFuzzStringTest = nextpas.core.test.fuzz.TFuzzStringTest;

procedure Fuzz(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AMaxIterations: Integer = 10000);
procedure FuzzString(const AName: string; ATest: TFuzzStringTest;
  const ACorpus: array of string; AMaxIterations: Integer = 10000);
function FuzzGenBytes(ALen: Integer): TBytes;
function FuzzGenString(ALen: Integer): string;
function FuzzMinimize(const AData: TBytes; ATest: TFuzzBytesTest): TBytes;

{ ── Re-exported corpus management from test.prop (v7.3a) ─────────────────── }

type
  TFuzzCorpus = nextpas.core.test.fuzz.TFuzzCorpus;

procedure FuzzWithCorpus(const AName: string; ATest: TFuzzBytesTest;
  const ACorpusDir: string; AMaxIterations: Integer = 10000);
procedure FuzzStringWithCorpus(const AName: string; ATest: TFuzzStringTest;
  const ACorpusDir: string; AMaxIterations: Integer = 10000);

{ ── Re-exported coverage tracking from test.prop (v8.0b) ──────────────────── }

type
  ICoverageTracker = nextpas.core.test.fuzz.ICoverageTracker;
  TFuzzStructuredIntTest = nextpas.core.test.fuzz.TFuzzStructuredIntTest;
  TFuzzStructuredStringTest = nextpas.core.test.fuzz.TFuzzStructuredStringTest;
  TFuzzStrategy = nextpas.core.test.fuzz.TFuzzStrategy;

function CreateCoverageTracker: ICoverageTracker;

procedure FuzzStructured(const AName: string; ATest: TFuzzStructuredIntTest;
  AGen: IIntGenerator; ACorpus: ICoverageTracker = nil;
  AMaxIterations: Integer = 10000); overload;
procedure FuzzStructured(const AName: string; ATest: TFuzzStructuredStringTest;
  AGen: IStringGenerator; ACorpus: ICoverageTracker = nil;
  AMaxIterations: Integer = 10000); overload;

procedure FuzzMultiStrategy(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AWorkers: Integer = 4;
  AIterationsPerWorker: Integer = 2500);

implementation

{$I nextpas.core.test.fwd.expect.inc}
{$I nextpas.core.test.fwd.check.inc}
{$I nextpas.core.test.fwd.output.inc}
{$I nextpas.core.test.fwd.other.inc}

end.
