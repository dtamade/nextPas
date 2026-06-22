{ bench_assertions — Microbenchmarks for nextpas.core.test assertion paths
  =========================================================
  Measures per-operation cost of Check*, CheckEqual, ExpectInt fluent, and
  suite-level RunWithResult throughput. }

program bench_assertions;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.test;

var
  B: TBenchRunner;
  GSink: Boolean;

{ ── Assertion benchmarks ─────────────────────────────────────────────────── }

procedure BenchCheckTrue(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    Check(True);
end;

procedure BenchCheckEqualInt64(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    CheckEqual(Int64(42), Int64(42));
end;

procedure BenchCheckEqualString(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    CheckEqual('hello', 'hello');
end;

procedure BenchExpectIntFluent(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    ExpectInt(42).ToEqualInt(42);
end;

procedure BenchCheckNear(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    CheckNear(3.14, 3.1400000001, 1e-6);
end;

procedure BenchExpectDoubleNear(aIters: Int64);
var
  LIt: Int64;
begin
  for LIt := 1 to aIters do
    ExpectDouble(3.14).ToBeNear(3.1400000001, 1e-6);
end;

{ ── Suite run benchmarks ─────────────────────────────────────────────────── }

procedure NoopTest;
begin
  { intentionally empty -- measures suite overhead, not assertion cost }
end;

procedure BenchSuiteRun100(aIters: Int64);
var
  LIt, LIdx: Int64;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LSaveOut: Text;
begin
  { Redirect stdout to /dev/null to suppress per-test output during benchmarking }
  LSaveOut := Output;
  Assign(Output, '/dev/null');
  Rewrite(Output);
  try
    for LIt := 1 to aIters do
    begin
      LSuite := TTestSuite.Create('overhead');
      for LIdx := 1 to 100 do
        LSuite.Test(IntToStr(LIdx), @NoopTest);
      GSink := LSuite.RunWithResult(LResult);
    end;
  finally
    Output := LSaveOut;
  end;
end;

{ ── Main ─────────────────────────────────────────────────────────────────── }

begin
  B := TBenchRunner.Create;
  try
    WriteLn('nextpas.core.test assertion benchmarks');
    WriteLn(StringOfChar('-', 76));

    B.Run('Check(True)',                  @BenchCheckTrue);
    B.Run('CheckEqual(Int64)',            @BenchCheckEqualInt64);
    B.Run('CheckEqual(string)',           @BenchCheckEqualString);
    B.Run('CheckNear(Double)',            @BenchCheckNear);
    B.Run('ExpectInt.ToEqualInt',         @BenchExpectIntFluent);
    B.Run('ExpectDouble.ToBeNear',        @BenchExpectDoubleNear);
    B.Run('Suite RunWithResult (100)',    @BenchSuiteRun100);

    B.Summary;
  finally
    B.Free;
  end;
end.
