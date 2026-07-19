program bench_overhead;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{**
 * 框架注册/运行开销基准。
 * 外层与内层采样均压到「分钟级内可跑完」；不测产品吞吐上限。
 *}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.platform.time;

procedure NoOpBench(const ACtx: IBenchContext);
begin
end;

{ 内层 suite：只跑通路径，不追求统计稳定 }
procedure ConfigureTiny(const ASuite: IBenchSuite);
begin
  ASuite.SetQuiet(True);
  ASuite.SetMinDuration(TDuration.FromMilliseconds(1));
  ASuite.SetMaxIterations(1);
  ASuite.SetMinSamples(1);
  ASuite.SetWarmupIters(0);
end;

procedure BenchSuiteCreateDestroy(const ACtx: IBenchContext);
var
  LSuite: IBenchSuite;
  I: Integer;
begin
  for I := 1 to 100 do
  begin
    LSuite := TBenchSuite.Create('Test');
    LSuite.Add('Dummy', @NoOpBench);
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
    LSuite.Add('Entry', @NoOpBench);
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
  ConfigureTiny(LSuite);
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
  ConfigureTiny(LSuite);
  LSuite.Add('Fast', @NoOpBench);
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
  ConfigureTiny(LSuite);
  LSuite.Add('A', @NoOpBench);
  LSuite.Add('B', @NoOpBench);
  LSuite.Add('C', @NoOpBench);
  LSuite.Add('D', @NoOpBench);
  LSuite.Add('E', @NoOpBench);
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
  { 10 次 create+run 周期；原先 100 次嵌套在外层采样下会挂死 }
  for I := 1 to 10 do
  begin
    LSuite := TBenchSuite.Create('Cycle');
    ConfigureTiny(LSuite);
    LSuite.Add('Dummy', @NoOpBench);
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
  { 外层：短时、少样本，保证 harness 可在约 1–2 分钟内结束 }
  LSuite.SetMinDuration(TDuration.FromMilliseconds(50));
  LSuite.SetMaxIterations(200);
  LSuite.SetMinSamples(5);
  LSuite.SetWarmupIters(1);
  LSuite.SetQuiet(False);

  LSuite.Add('SuiteCreateDestroy/100', @BenchSuiteCreateDestroy);
  LSuite.Add('SuiteAddEntry/1000', @BenchSuiteAddEntry);
  LSuite.Add('SuiteFluentChain', @BenchSuiteFluentChain);
  LSuite.Add('SuiteRunEmpty', @BenchSuiteRunEmpty);
  LSuite.Add('SuiteRunSingleFast', @BenchSuiteRunSingleFast);
  LSuite.Add('SuiteRunMultiple', @BenchSuiteRunMultiple);
  LSuite.Add('SuiteRunCycle/10', @BenchSuiteRunCycle);
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
