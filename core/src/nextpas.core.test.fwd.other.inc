{ ── Forward to test.base (stack trace) ───────────────────────────────────── }

function GetLastTestTrace: string;
begin Result := nextpas.core.test.base.GetLastTestTrace; end;

function FormatTestLocation(APrefix: string): string;
begin Result := nextpas.core.test.base.FormatTestLocation(APrefix); end;

{ ── Forward to test.runner (timeout leak monitoring) ───────────────────────── }

function GetTimeoutWorkerLeakCount: Integer;
begin Result := nextpas.core.test.runner.GetTimeoutWorkerLeakCount; end;

procedure ResetTimeoutWorkerLeakCount;
begin nextpas.core.test.runner.ResetTimeoutWorkerLeakCount; end;

{ ── Forward to test.discovery ──────────────────────────────────────────────── }

function DiscoverTests(AFixture: TTestFixture;
  const ASuiteName: string): TTestSuite;
begin Result := nextpas.core.test.discovery.DiscoverTests(AFixture, ASuiteName); end;

function CreateFpcVmtDiscoveryBackend: ITestDiscoveryBackend;
begin Result := nextpas.core.test.discovery.CreateFpcVmtDiscoveryBackend; end;

function GetDiscoveryBackend: ITestDiscoveryBackend;
begin Result := nextpas.core.test.discovery.GetDiscoveryBackend; end;

procedure SetDiscoveryBackend(const ABackend: ITestDiscoveryBackend);
begin nextpas.core.test.discovery.SetDiscoveryBackend(ABackend); end;

procedure ResetDiscoveryBackend;
begin nextpas.core.test.discovery.ResetDiscoveryBackend; end;

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

procedure ExpectFailWith(AProc: TTestClosure;
  AExceptionClass: ExceptClass;
  const AContains: string);
begin nextpas.core.test.helpers.ExpectFailWith(AProc, AExceptionClass, AContains); end;

procedure WithMock(AProc: TMockProc);
begin nextpas.core.test.helpers.WithMock(AProc); end;

procedure ExpectFailWithMock(AProc: TMockProc;
  const AContains: string);
begin nextpas.core.test.helpers.ExpectFailWithMock(AProc, AContains); end;

function MakeBufferConfig(out ASink: TBufferSink): TTestConfig;
begin Result := nextpas.core.test.helpers.MakeBufferConfig(ASink); end;

procedure WithTempDir(AProc: TTempDirProc);
begin nextpas.core.test.helpers.WithTempDir(AProc); end;

function IntOverflowCheck(AValue: Int64; const AOp: string;
  AOperand: Int64): Boolean;
begin
  Result := nextpas.core.test.helpers.IntOverflowCheck(AValue, AOp, AOperand);
end;

{ ── Forward to test.prop ──────────────────────────────────────────────────── }

function GenString(AMinLen, AMaxLen: Integer): IStringGenerator;
begin Result := nextpas.core.test.prop.gen.GenString(AMinLen, AMaxLen); end;

function GenString(AMaxLen: Integer): IStringGenerator;
begin Result := nextpas.core.test.prop.gen.GenString(AMaxLen); end;

function GenInt(AMin, AMax: Int64): IIntGenerator;
begin Result := nextpas.core.test.prop.gen.GenInt(AMin, AMax); end;

function GenInt(AMax: Int64): IIntGenerator;
begin Result := nextpas.core.test.prop.gen.GenInt(AMax); end;

function GenBytes(AMinLen, AMaxLen: Integer): IBytesGenerator;
begin Result := nextpas.core.test.prop.gen.GenBytes(AMinLen, AMaxLen); end;

function GenBytes(AMaxLen: Integer): IBytesGenerator;
begin Result := nextpas.core.test.prop.gen.GenBytes(AMaxLen); end;

function GenBool: IBoolGenerator;
begin Result := nextpas.core.test.prop.gen.GenBool; end;

function MapIntToStr(AGen: IIntGenerator; AMap: TIntToString): IStringGenerator;
begin Result := nextpas.core.test.prop.gen.MapIntToStr(AGen, AMap); end;

function FilterInt(AGen: IIntGenerator; APred: TIntPred): IIntGenerator;
begin Result := nextpas.core.test.prop.gen.FilterInt(AGen, APred); end;

function FilterString(AGen: IStringGenerator; APred: TStringPred): IStringGenerator;
begin Result := nextpas.core.test.prop.gen.FilterString(AGen, APred); end;

function FilterBytes(AGen: IBytesGenerator; APred: TBytesPred): IBytesGenerator;
begin Result := nextpas.core.test.prop.gen.FilterBytes(AGen, APred); end;

function GenChoiceInt(const AValues: array of Int64): IIntGenerator;
begin Result := nextpas.core.test.prop.gen.GenChoiceInt(AValues); end;

function GenChoiceString(const AValues: array of string): IStringGenerator;
begin Result := nextpas.core.test.prop.gen.GenChoiceString(AValues); end;

function GenChoiceBool(const AValues: array of Boolean): IBoolGenerator;
begin Result := nextpas.core.test.prop.gen.GenChoiceBool(AValues); end;

function GenOneOfInt(const AGens: array of IIntGenerator): IIntGenerator;
begin Result := nextpas.core.test.prop.gen.GenOneOfInt(AGens); end;

function GenOneOfString(const AGens: array of IStringGenerator): IStringGenerator;
begin Result := nextpas.core.test.prop.gen.GenOneOfString(AGens); end;

procedure PropFail(const AMsg: string);
begin nextpas.core.test.prop.PropFail(AMsg); end;

function PropWithResult(const AName: string; ATest: TIntTest;
  AGen: IIntGenerator; ARuns: Integer; AShrink: Boolean): string;
begin Result := nextpas.core.test.prop.PropWithResult(AName, ATest, AGen, ARuns, AShrink); end;

function GenArray(AGen: IIntGenerator; AMaxLen: Integer): IArrayGenerator;
begin Result := nextpas.core.test.prop.gen.GenArray(AGen, AMaxLen); end;

function GenArray(AGen: IIntGenerator; AMinLen, AMaxLen: Integer): IArrayGenerator;
begin Result := nextpas.core.test.prop.gen.GenArray(AGen, AMinLen, AMaxLen); end;

function GenTuple(AGen1: IIntGenerator; AGen2: IStringGenerator): ITupleGenerator;
begin Result := nextpas.core.test.prop.gen.GenTuple(AGen1, AGen2); end;

function BindInt(AGen: IIntGenerator; AFn: TIntToGenerator): IIntGenerator;
begin Result := nextpas.core.test.prop.gen.BindInt(AGen, AFn); end;

procedure PropArray(const AName: string; ATest: TIntArrayTest;
  AGen: IArrayGenerator; ARuns: Integer; AShrink: Boolean);
begin nextpas.core.test.prop.PropArray(AName, ATest, AGen, ARuns, AShrink); end;

procedure PropTuple(const AName: string; ATest: TTupleTest;
  AGen: ITupleGenerator; ARuns: Integer);
begin nextpas.core.test.prop.PropTuple(AName, ATest, AGen, ARuns); end;

procedure Fuzz(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AMaxIterations: Integer);
begin nextpas.core.test.fuzz.Fuzz(AName, ATest, ACorpus, AMaxIterations); end;

procedure FuzzString(const AName: string; ATest: TFuzzStringTest;
  const ACorpus: array of string; AMaxIterations: Integer);
begin nextpas.core.test.fuzz.FuzzString(AName, ATest, ACorpus, AMaxIterations); end;

function FuzzGenBytes(ALen: Integer): TBytes;
begin Result := nextpas.core.test.fuzz.FuzzGenBytes(ALen); end;

function FuzzGenString(ALen: Integer): string;
begin Result := nextpas.core.test.fuzz.FuzzGenString(ALen); end;

function FuzzMinimize(const AData: TBytes; ATest: TFuzzBytesTest): TBytes;
begin Result := nextpas.core.test.fuzz.FuzzMinimize(AData, ATest); end;

procedure FuzzWithCorpus(const AName: string; ATest: TFuzzBytesTest;
  const ACorpusDir: string; AMaxIterations: Integer);
begin nextpas.core.test.fuzz.FuzzWithCorpus(AName, ATest, ACorpusDir, AMaxIterations); end;

procedure FuzzStringWithCorpus(const AName: string; ATest: TFuzzStringTest;
  const ACorpusDir: string; AMaxIterations: Integer);
begin nextpas.core.test.fuzz.FuzzStringWithCorpus(AName, ATest, ACorpusDir, AMaxIterations); end;

function CreateCoverageTracker: ICoverageTracker;
begin Result := nextpas.core.test.fuzz.CreateCoverageTracker; end;

procedure FuzzStructured(const AName: string; ATest: TFuzzStructuredIntTest;
  AGen: IIntGenerator; ACorpus: ICoverageTracker; AMaxIterations: Integer);
begin nextpas.core.test.fuzz.FuzzStructured(AName, ATest, AGen, ACorpus, AMaxIterations); end;

procedure FuzzStructured(const AName: string; ATest: TFuzzStructuredStringTest;
  AGen: IStringGenerator; ACorpus: ICoverageTracker; AMaxIterations: Integer);
begin nextpas.core.test.fuzz.FuzzStructured(AName, ATest, AGen, ACorpus, AMaxIterations); end;

procedure FuzzMultiStrategy(const AName: string; ATest: TFuzzBytesTest;
  const ACorpus: array of TBytes; AWorkers: Integer; AIterationsPerWorker: Integer);
begin nextpas.core.test.fuzz.FuzzMultiStrategy(AName, ATest, ACorpus, AWorkers, AIterationsPerWorker); end;
