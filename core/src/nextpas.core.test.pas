{ nextpas.core.test — Advanced Pascal Unit Testing Framework (facade)
  =========================================================
  Re-exports all public API from sub-modules:
    test.base, test.check, test.expect, test.output, test.runner,
    test.output.tap, test.output.json, test.discovery, test.mock
  Dual API: procedural Check* + fluent IExpectation chain.
  Parallel execution, subtests, ANSI output, leak detection,
  RTTI discovery, retry, TAP/JSON output, mock framework. }

unit nextpas.core.test;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.expect,
  nextpas.core.test.output,
  nextpas.core.test.output.tap,
  nextpas.core.test.output.json,
  nextpas.core.test.runner,
  nextpas.core.test.discovery,
  nextpas.core.test.mock;

{ ── Re-exported types from test.base ─────────────────────────────────────── }

type
  ExceptClass = nextpas.core.test.base.ExceptClass;
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

const
  tsPassed  = nextpas.core.test.base.tsPassed;
  tsFailed  = nextpas.core.test.base.tsFailed;
  tsSkipped = nextpas.core.test.base.tsSkipped;
  tsError   = nextpas.core.test.base.tsError;
  ekTest    = nextpas.core.test.base.ekTest;
  ekSubtest = nextpas.core.test.base.ekSubtest;
  ekSkipped = nextpas.core.test.base.ekSkipped;
  ekTableTest = nextpas.core.test.base.ekTableTest;

{ ── Re-exported types from test.expect ────────────────────────────────────── }

type
  IExpectation = nextpas.core.test.expect.IExpectation;

{ ── Re-exported types from test.runner ────────────────────────────────────── }

type
  TTestSuite = nextpas.core.test.runner.TTestSuite;
  TTestRunner = nextpas.core.test.runner.TTestRunner;

{ ── Re-exported functions from test.expect ────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
function ExpectInt(AValue: Int64): IExpectation;
function ExpectBool(AValue: Boolean): IExpectation;
function ExpectDouble(AValue: Double): IExpectation;
function ExpectPtr(AValue: Pointer): IExpectation;
function ExpectProc(AProc: TTestProc): IExpectation;

{ ── Re-exported functions from test.check ─────────────────────────────────── }

procedure Check(ACondition: Boolean; const AMessage: string = '');
procedure CheckEqual(const AExpected, AActual: string); overload;
procedure CheckEqual(AExpected, AActual: Int64); overload;
procedure CheckEqual(AExpected, AActual: Boolean); overload;
procedure CheckEqual(AExpected, AActual: Pointer); overload;
procedure CheckNotEqual(const AExpected, AActual: string); overload;
procedure CheckNotEqual(AExpected, AActual: Int64); overload;
procedure CheckNotEqual(AExpected, AActual: Boolean); overload;
procedure CheckNotEqual(AExpected, AActual: Pointer); overload;
procedure CheckTrue(AValue: Boolean; const AMessage: string = '');
procedure CheckFalse(AValue: Boolean; const AMessage: string = '');
procedure CheckNil(AValue: Pointer; const AMessage: string = '');
procedure CheckNotNil(AValue: Pointer; const AMessage: string = '');
procedure CheckContains(const AHaystack, ANeedle: string);
procedure CheckStartsWith(const AStr, APrefix: string);
procedure CheckEndsWith(const AStr, ASuffix: string);
procedure CheckSame(AExpected, AActual: Pointer; const AMessage: string = '');
procedure CheckInRange(AValue, ALow, AHigh: Int64);
procedure CheckGreaterThan(AValue, AExpected: Int64);
procedure CheckLessThan(AValue, AExpected: Int64);
procedure CheckLength(AExpected, AActual: NativeInt);
procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string = '');
procedure CheckNoRaise(AProc: TTestProc; const AMessage: string = '');
procedure CheckNear(AExpected, AActual: Double;
  AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure CheckNotNear(AExpected, AActual: Double;
  AEpsilon: Double = 1e-10; const AMessage: string = '');
procedure Fail(const AMessage: string);
procedure Skip(const AReason: string = '');

{ ── Re-exported functions from test.output ────────────────────────────────── }

function AnsiBold(const S: string): string;
function AnsiGreen(const S: string): string;
function AnsiRed(const S: string): string;
function AnsiYellow(const S: string): string;
function AnsiCyan(const S: string): string;
function AnsiDim(const S: string): string;
procedure SetAnsiEnabled(AEnabled: Boolean);
procedure SetTestFilter(const APattern: string);
function  GetTestFilter: string;
procedure SetTestTimeout(AMillis: Integer);
function  GetTestTimeout: Integer;
function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string = ''): string;
function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string = ''): Boolean;

type
  TTestResults = nextpas.core.test.base.TTestResults;

{ ── Re-exported types from test.discovery ──────────────────────────────────── }

type
  TTestFixture = nextpas.core.test.discovery.TTestFixture;

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
  TMock = nextpas.core.test.mock.TMock;
  TMockState = nextpas.core.test.mock.TMockState;
  IMockSetup = nextpas.core.test.mock.IMockSetup;
  IMockVerify = nextpas.core.test.mock.IMockVerify;

implementation

{ ── Forward to test.expect ────────────────────────────────────────────────── }

function Expect(const AValue: string): IExpectation;
begin Result := nextpas.core.test.expect.Expect(AValue); end;

function ExpectInt(AValue: Int64): IExpectation;
begin Result := nextpas.core.test.expect.ExpectInt(AValue); end;

function ExpectBool(AValue: Boolean): IExpectation;
begin Result := nextpas.core.test.expect.ExpectBool(AValue); end;

function ExpectDouble(AValue: Double): IExpectation;
begin Result := nextpas.core.test.expect.ExpectDouble(AValue); end;

function ExpectPtr(AValue: Pointer): IExpectation;
begin Result := nextpas.core.test.expect.ExpectPtr(AValue); end;

function ExpectProc(AProc: TTestProc): IExpectation;
begin Result := nextpas.core.test.expect.ExpectProc(AProc); end;

{ ── Forward to test.check ─────────────────────────────────────────────────── }

procedure Check(ACondition: Boolean; const AMessage: string);
begin nextpas.core.test.check.Check(ACondition, AMessage); end;

procedure CheckEqual(const AExpected, AActual: string);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(AExpected, AActual: Int64);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(AExpected, AActual: Boolean);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckEqual(AExpected, AActual: Pointer);
begin nextpas.core.test.check.CheckEqual(AExpected, AActual); end;

procedure CheckNotEqual(const AExpected, AActual: string);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(AExpected, AActual: Int64);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(AExpected, AActual: Boolean);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

procedure CheckNotEqual(AExpected, AActual: Pointer);
begin nextpas.core.test.check.CheckNotEqual(AExpected, AActual); end;

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

procedure CheckStartsWith(const AStr, APrefix: string);
begin nextpas.core.test.check.CheckStartsWith(AStr, APrefix); end;

procedure CheckEndsWith(const AStr, ASuffix: string);
begin nextpas.core.test.check.CheckEndsWith(AStr, ASuffix); end;

procedure CheckSame(AExpected, AActual: Pointer; const AMessage: string);
begin nextpas.core.test.check.CheckSame(AExpected, AActual, AMessage); end;

procedure CheckInRange(AValue, ALow, AHigh: Int64);
begin nextpas.core.test.check.CheckInRange(AValue, ALow, AHigh); end;

procedure CheckGreaterThan(AValue, AExpected: Int64);
begin nextpas.core.test.check.CheckGreaterThan(AValue, AExpected); end;

procedure CheckLessThan(AValue, AExpected: Int64);
begin nextpas.core.test.check.CheckLessThan(AValue, AExpected); end;

procedure CheckLength(AExpected, AActual: NativeInt);
begin nextpas.core.test.check.CheckLength(AExpected, AActual); end;

procedure CheckRaises(AExceptionClass: ExceptClass; AProc: TTestProc;
  const AMessage: string);
begin nextpas.core.test.check.CheckRaises(AExceptionClass, AProc, AMessage); end;

procedure CheckNoRaise(AProc: TTestProc; const AMessage: string);
begin nextpas.core.test.check.CheckNoRaise(AProc, AMessage); end;

procedure CheckNear(AExpected, AActual: Double;
  AEpsilon: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNear(AExpected, AActual, AEpsilon, AMessage); end;

procedure CheckNotNear(AExpected, AActual: Double;
  AEpsilon: Double; const AMessage: string);
begin nextpas.core.test.check.CheckNotNear(AExpected, AActual, AEpsilon, AMessage); end;

procedure Fail(const AMessage: string);
begin nextpas.core.test.check.Fail(AMessage); end;

procedure Skip(const AReason: string);
begin nextpas.core.test.check.Skip(AReason); end;

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

procedure SetTestFilter(const APattern: string);
begin nextpas.core.test.output.SetTestFilter(APattern); end;

function GetTestFilter: string;
begin Result := nextpas.core.test.output.GetTestFilter; end;

procedure SetTestTimeout(AMillis: Integer);
begin nextpas.core.test.output.SetTestTimeout(AMillis); end;

function GetTestTimeout: Integer;
begin Result := nextpas.core.test.output.GetTestTimeout; end;

function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
begin Result := nextpas.core.test.output.JUnitXML(AResults, ASuiteName); end;

function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string): Boolean;
begin Result := nextpas.core.test.output.WriteJUnitXML(AResults, AFileName, ASuiteName); end;

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

end.
