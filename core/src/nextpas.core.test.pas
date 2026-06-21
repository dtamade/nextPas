{ nextpas.core.test — Advanced Pascal Unit Testing Framework (facade)
  =========================================================
  Re-exports all public API from sub-modules:
    test.types, test.check, test.expect, test.output, test.runner
  Dual API: procedural Check* + fluent IExpectation chain.
  Parallel execution, subtests, ANSI output, leak detection. }

unit nextpas.core.test;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.test.types,
  nextpas.core.test.check,
  nextpas.core.test.expect,
  nextpas.core.test.output,
  nextpas.core.test.runner;

{ ── Re-exported types from test.types ─────────────────────────────────────── }

type
  ExceptClass = nextpas.core.test.types.ExceptClass;
  TTestProc = nextpas.core.test.types.TTestProc;
  ITestContext = nextpas.core.test.types.ITestContext;
  TSubtestProc = nextpas.core.test.types.TSubtestProc;
  TTestCase = nextpas.core.test.types.TTestCase;
  TTestCaseProc = nextpas.core.test.types.TTestCaseProc;
  TTestStatus = nextpas.core.test.types.TTestStatus;
  TTestResult = nextpas.core.test.types.TTestResult;
  TTestRunResult = nextpas.core.test.types.TTestRunResult;
  ETestSkipped = nextpas.core.test.types.ETestSkipped;
  TTestEntryKind = nextpas.core.test.types.TTestEntryKind;
  TTestEntry = nextpas.core.test.types.TTestEntry;

const
  tsPassed  = nextpas.core.test.types.tsPassed;
  tsFailed  = nextpas.core.test.types.tsFailed;
  tsSkipped = nextpas.core.test.types.tsSkipped;
  tsError   = nextpas.core.test.types.tsError;
  ekTest    = nextpas.core.test.types.ekTest;
  ekSubtest = nextpas.core.test.types.ekSubtest;
  ekSkipped = nextpas.core.test.types.ekSkipped;
  ekTableTest = nextpas.core.test.types.ekTableTest;

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
  TTestResults = nextpas.core.test.types.TTestResults;

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

end.
