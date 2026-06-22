program bench_overhead;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.time.format,
  nextpas.core.platform.time;

var
  GIterationCount: Integer;

procedure BenchSuiteCreateDestroy(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  I: Integer;
begin
  for I := 1 to 100 do
  begin
    LSuite := TBenchSuite.Create('Test');
    LSuite.Add('Dummy', nil);
    LSuite := nil;
  end;
  ACtx.SetBytes(100 * SizeOf(Pointer));
end;

procedure BenchSuiteAddEntry(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  I: Integer;
begin
  LSuite := TBenchSuite.Create('Test');
  for I := 1 to 1000 do
    LSuite.Add('Entry', nil);
  ACtx.SetBytes(1000 * SizeOf(Pointer));
  LSuite := nil;
end;

procedure BenchSuiteFluentChain(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('Test')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(1000)
    .SetMinSamples(10)
    .SetWarmupIters(1)
    .EnableMemoryTracking
    .CollectRawSamples
    .SetQuiet(True);
  LSuite := nil;
end;

procedure BenchSuiteRunEmpty(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('Empty');
  LSuite.SetQuiet(True);
  LResults := LSuite.Run;
  LResults := nil;
  LSuite := nil;
end;

procedure BenchSuiteRunSingleFast(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('Single');
  LSuite.SetQuiet(True);
  LSuite.SetMinDuration(TDuration.FromMilliseconds(1));
  LSuite.SetMaxIterations(10000);
  LSuite.Add('Fast', procedure(const ACtx2: IBenchContext) begin end);
  LResults := LSuite.Run;
  LResults := nil;
  LSuite := nil;
end;

procedure BenchSuiteRunMultiple(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('Multiple');
  LSuite.SetQuiet(True);
  LSuite.SetMinDuration(TDuration.FromMilliseconds(1));
  LSuite.SetMaxIterations(1000);
  LSuite.Add('A', procedure(const ACtx2: IBenchContext) begin end);
  LSuite.Add('B', procedure(const ACtx2: IBenchContext) begin end);
  LSuite.Add('C', procedure(const ACtx2: IBenchContext) begin end);
  LSuite.Add('D', procedure(const ACtx2: IBenchContext) begin end);
  LSuite.Add('E', procedure(const ACtx2: IBenchContext) begin end);
  LResults := LSuite.Run;
  LResults := nil;
  LSuite := nil;
end;

procedure BenchSuiteRunCycle(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  I: Integer;
begin
  for I := 1 to 100 do
  begin
    LSuite := TBenchSuite.Create('Cycle');
    LSuite.SetQuiet(True);
    LSuite.SetMinDuration(TDuration.FromMilliseconds(1));
    LSuite.SetMaxIterations(100);
    LSuite.Add('Dummy', procedure(const ACtx2: IBenchContext) begin end);
    LResults := LSuite.Run;
    LResults := nil;
    LSuite := nil;
  end;
end;

procedure BenchContextGetElapsed(const ACtx: IBenchContext);
var
  I: Integer;
  LElapsed: TDuration;
begin
  for I := 1 to 10000 do
  begin
    LElapsed := ACtx.GetElapsed;
    if LElapsed.AsNanoseconds < 0 then
      Break;
  end;
end;

procedure RunOverheadBenchmarks;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('=== nextpas.core.bench Overhead Benchmarks ===');
  WriteLn;
  WriteLn('Measuring framework overhead (lower is better):');
  WriteLn;

  LSuite := TBenchSuite.Create('BenchOverhead');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(10));
  LSuite.SetMaxIterations(100000);
  LSuite.SetMinSamples(30);
  LSuite.SetQuiet(False);

  LSuite.Add('SuiteCreateDestroy/100', @BenchSuiteCreateDestroy);
  LSuite.Add('SuiteAddEntry/1000', @BenchSuiteAddEntry);
  LSuite.Add('SuiteFluentChain', @BenchSuiteFluentChain);
  LSuite.Add('SuiteRunEmpty', @BenchSuiteRunEmpty);
  LSuite.Add('SuiteRunSingleFast', @BenchSuiteRunSingleFast);
  LSuite.Add('SuiteRunMultiple', @BenchSuiteRunMultiple);
  LSuite.Add('SuiteRunCycle/100', @BenchSuiteRunCycle);
  LSuite.Add('ContextGetElapsed/10000', @BenchContextGetElapsed);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== JSON Output ===');
  WriteLn(LResults.ToJSON);

  LResults := nil;
  LSuite := nil;
end;

begin
  RunOverheadBenchmarks;
end.
