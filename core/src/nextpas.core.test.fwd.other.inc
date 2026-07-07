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

{ ── Forward to test.prop ──────────────────────────────────────────────────── }

function GenString(AMinLen, AMaxLen: Integer): IStringGenerator;
begin Result := nextpas.core.test.prop.GenString(AMinLen, AMaxLen); end;

function GenString(AMaxLen: Integer): IStringGenerator;
begin Result := nextpas.core.test.prop.GenString(AMaxLen); end;

function GenInt(AMin, AMax: Int64): IIntGenerator;
begin Result := nextpas.core.test.prop.GenInt(AMin, AMax); end;

function GenInt(AMax: Int64): IIntGenerator;
begin Result := nextpas.core.test.prop.GenInt(AMax); end;

function GenBytes(AMinLen, AMaxLen: Integer): IBytesGenerator;
begin Result := nextpas.core.test.prop.GenBytes(AMinLen, AMaxLen); end;

function GenBytes(AMaxLen: Integer): IBytesGenerator;
begin Result := nextpas.core.test.prop.GenBytes(AMaxLen); end;

function GenBool: IBoolGenerator;
begin Result := nextpas.core.test.prop.GenBool; end;

function MapIntToStr(AGen: IIntGenerator; AMap: TIntToString): IStringGenerator;
begin Result := nextpas.core.test.prop.MapIntToStr(AGen, AMap); end;

function FilterInt(AGen: IIntGenerator; APred: TIntPred): IIntGenerator;
begin Result := nextpas.core.test.prop.FilterInt(AGen, APred); end;

function FilterString(AGen: IStringGenerator; APred: TStringPred): IStringGenerator;
begin Result := nextpas.core.test.prop.FilterString(AGen, APred); end;

function FilterBytes(AGen: IBytesGenerator; APred: TBytesPred): IBytesGenerator;
begin Result := nextpas.core.test.prop.FilterBytes(AGen, APred); end;

function GenChoiceInt(const AValues: array of Int64): IIntGenerator;
begin Result := nextpas.core.test.prop.GenChoiceInt(AValues); end;

function GenChoiceString(const AValues: array of string): IStringGenerator;
begin Result := nextpas.core.test.prop.GenChoiceString(AValues); end;

function GenChoiceBool(const AValues: array of Boolean): IBoolGenerator;
begin Result := nextpas.core.test.prop.GenChoiceBool(AValues); end;

function GenOneOfInt(const AGens: array of IIntGenerator): IIntGenerator;
begin Result := nextpas.core.test.prop.GenOneOfInt(AGens); end;

function GenOneOfString(const AGens: array of IStringGenerator): IStringGenerator;
begin Result := nextpas.core.test.prop.GenOneOfString(AGens); end;

procedure PropFail(const AMsg: string);
begin nextpas.core.test.prop.PropFail(AMsg); end;

function PropWithResult(const AName: string; ATest: TIntTest;
  AGen: IIntGenerator; ARuns: Integer; AShrink: Boolean): string;
begin Result := nextpas.core.test.prop.PropWithResult(AName, ATest, AGen, ARuns, AShrink); end;

procedure Fuzz(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AMaxIterations: Integer);
begin nextpas.core.test.prop.Fuzz(AName, ATest, ACorpus, AMaxIterations); end;

procedure FuzzString(const AName: string; ATest: TFuzzStringTest;
  const ACorpus: array of string; AMaxIterations: Integer);
begin nextpas.core.test.prop.FuzzString(AName, ATest, ACorpus, AMaxIterations); end;

function FuzzGenBytes(ALen: Integer): TBytes;
begin Result := nextpas.core.test.prop.FuzzGenBytes(ALen); end;

function FuzzGenString(ALen: Integer): string;
begin Result := nextpas.core.test.prop.FuzzGenString(ALen); end;

procedure FuzzWithCorpus(const AName: string; ATest: TFuzzBytesTest;
  const ACorpusDir: string; AMaxIterations: Integer);
begin nextpas.core.test.prop.FuzzWithCorpus(AName, ATest, ACorpusDir, AMaxIterations); end;

procedure FuzzStringWithCorpus(const AName: string; ATest: TFuzzStringTest;
  const ACorpusDir: string; AMaxIterations: Integer);
begin nextpas.core.test.prop.FuzzStringWithCorpus(AName, ATest, ACorpusDir, AMaxIterations); end;
