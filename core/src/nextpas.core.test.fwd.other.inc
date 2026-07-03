{ ── Forward to test.base (stack trace) ───────────────────────────────────── }

function GetLastTestTrace: string;
begin Result := nextpas.core.test.base.GetLastTestTrace; end;

function FormatTestLocation(APrefix: string): string;
begin Result := nextpas.core.test.base.FormatTestLocation(APrefix); end;

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
