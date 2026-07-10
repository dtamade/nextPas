{**
 * @desc TBenchRun 线程安全执行器测试
 *}
program test_bench_run;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.runner,
  nextpas.core.bench.run,
  nextpas.core.bench.test_helpers,
  nextpas.core.time.base;

{ --------------------------------------------------------------------- }
{  Test Helpers }
{ --------------------------------------------------------------------- }

{ MakeBenchEntry, NoOpBench, BusyBench 现在来自 nextpas.core.bench.test_helpers }

{ --------------------------------------------------------------------- }
{  AllocBenchResult / FreeBenchResult }
{ --------------------------------------------------------------------- }

procedure Test_AllocBenchResult_Basic;
var
  LSrc: TBenchResult;
  LPtr: PBenchRunResult;
begin
  LSrc := Default(TBenchResult);
  LSrc.Name := 'TestAlloc';
  LSrc.NsPerOp := 42.5;
  LSrc.Executed := True;
  LSrc.Iterations := 1000;

  LPtr := AllocBenchResult(LSrc);
  try
    Check(LPtr <> nil, 'AllocBenchResult returns non-nil');
    Check(LPtr^.Name = 'TestAlloc', 'Name preserved');
    Check(Abs(LPtr^.NsPerOp - 42.5) < 0.001, 'NsPerOp preserved');
    Check(LPtr^.Executed, 'Executed preserved');
    Check(LPtr^.Iterations = 1000, 'Iterations preserved');
  finally
    FreeBenchResult(LPtr);
  end;
end;

procedure Test_AllocBenchResult_ManagedTypes;
var
  LSrc: TBenchResult;
  LPtr: PBenchRunResult;
begin
  LSrc := Default(TBenchResult);
  LSrc.Name := 'ManagedTest';
  SetLength(LSrc.RawSamples, 3);
  LSrc.RawSamples[0] := 1.0;
  LSrc.RawSamples[1] := 2.0;
  LSrc.RawSamples[2] := 3.0;
  SetLength(LSrc.CustomMetrics, 1);
  LSrc.CustomMetrics[0].Name := 'throughput';
  LSrc.CustomMetrics[0].Value := 99.9;

  LPtr := AllocBenchResult(LSrc);
  try
    Check(LPtr^.Name = 'ManagedTest', 'Name preserved');
    Check(Length(LPtr^.RawSamples) = 3, 'RawSamples length');
    Check(Abs(LPtr^.RawSamples[1] - 2.0) < 0.001, 'RawSamples value');
    Check(Length(LPtr^.CustomMetrics) = 1, 'CustomMetrics length');
    Check(LPtr^.CustomMetrics[0].Name = 'throughput', 'CustomMetric name');
    Check(Abs(LPtr^.CustomMetrics[0].Value - 99.9) < 0.001, 'CustomMetric value');
  finally
    FreeBenchResult(LPtr);
  end;
end;

procedure Test_FreeBenchResult_Nil;
begin
  FreeBenchResult(nil);
  Check(True, 'FreeBenchResult(nil) does not crash');
end;

{ --------------------------------------------------------------------- }
{  TBenchRun — Create / Destroy }
{ --------------------------------------------------------------------- }

procedure Test_Create_Destroy;
var
  LRun: TBenchRun;
begin
  LRun := TBenchRun.Create;
  try
    Check(LRun.Count = 0, 'New TBenchRun has Count=0');
  finally
    LRun.Free;
  end;
end;

procedure Test_CreateWithConfig;
var
  LRun: TBenchRun;
  LConfig: TBenchConfig;
begin
  LConfig := Default(TBenchConfig);
  LConfig.MinSamples := 50;
  LConfig.Quiet := True;
  LRun := TBenchRun.Create(LConfig);
  try
    Check(LRun.Config.MinSamples = 50, 'Config.MinSamples');
    Check(LRun.Config.Quiet, 'Config.Quiet');
  finally
    LRun.Free;
  end;
end;

{ --------------------------------------------------------------------- }
{  TBenchRun — SubmitResult }
{ --------------------------------------------------------------------- }

procedure Test_SubmitResult_Single;
var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
  LSrc: TBenchResult;
begin
  LRun := TBenchRun.Create;
  try
    LSrc := Default(TBenchResult);
    LSrc.Name := 'Submit1';
    LSrc.NsPerOp := 10.0;
    LSrc.Executed := True;
    LRun.SubmitResult(AllocBenchResult(LSrc));

    Check(LRun.Count = 1, 'Count=1 after submit');
    Check(LRun.CollectResults(LResults) = 1, 'CollectResults returns 1');
    Check(LResults[0].Name = 'Submit1', 'Result name');
    Check(Abs(LResults[0].NsPerOp - 10.0) < 0.001, 'Result NsPerOp');
  finally
    LRun.Free;
  end;
end;

procedure Test_SubmitResult_Multiple;
var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
  LSrc: TBenchResult;
  I: Integer;
begin
  LRun := TBenchRun.Create;
  try
    for I := 0 to 9 do
    begin
      LSrc := Default(TBenchResult);
      LSrc.Name := 'Bench' + IntToStr(I);
      LSrc.NsPerOp := I * 1.5;
      LSrc.Executed := True;
      LRun.SubmitResult(AllocBenchResult(LSrc));
    end;

    Check(LRun.Count = 10, 'Count=10 after 10 submits');
    Check(LRun.CollectResults(LResults) = 10, 'CollectResults returns 10');
    for I := 0 to 9 do
    begin
      Check(LResults[I].Name = 'Bench' + IntToStr(I), 'Result[' + IntToStr(I) + '] name');
      Check(Abs(LResults[I].NsPerOp - I * 1.5) < 0.001, 'Result[' + IntToStr(I) + '] NsPerOp');
    end;
  finally
    LRun.Free;
  end;
end;

{ --------------------------------------------------------------------- }
{  TBenchRun — RunAll }
{ --------------------------------------------------------------------- }

procedure Test_RunAll_Empty;
var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
begin
  LRun := TBenchRun.Create;
  try
    LResults := LRun.RunAll([], 2);
    Check(Length(LResults) = 0, 'RunAll empty returns empty array');
  finally
    LRun.Free;
  end;
end;

procedure Test_RunAll_SingleEntry;
var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
  LConfig: TBenchConfig;
begin
  LConfig := Default(TBenchConfig);
  LConfig.Quiet := True;
  LConfig.MinSamples := 3;
  LConfig.MinDurationNs := 100000;
  LRun := TBenchRun.Create(LConfig);
  try
    LResults := LRun.RunAll([MakeBenchEntry('Single', @NoOpBench)], 1);
    Check(Length(LResults) = 1, 'RunAll returns 1 result');
    Check(LResults[0].Executed, 'Single entry executed');
    Check(LResults[0].Name = 'Single', 'Single entry name');
  finally
    LRun.Free;
  end;
end;

procedure Test_RunAll_MultipleEntries;
var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
  LConfig: TBenchConfig;
  I, LFound: Integer;
begin
  LConfig := Default(TBenchConfig);
  LConfig.Quiet := True;
  LConfig.MinSamples := 3;
  LConfig.MinDurationNs := 100000;
  LRun := TBenchRun.Create(LConfig);
  try
    LResults := LRun.RunAll([
      MakeBenchEntry('Bench_A', @NoOpBench),
      MakeBenchEntry('Bench_B', @BusyBench),
      MakeBenchEntry('Bench_C', @NoOpBench)
    ], 2);

    Check(Length(LResults) = 3, 'RunAll returns 3 results');
    LFound := 0;
    for I := 0 to 2 do
    begin
      if LResults[I].Executed then
        Inc(LFound);
    end;
    Check(LFound = 3, 'All 3 entries executed');
  finally
    LRun.Free;
  end;
end;

procedure Test_RunAll_ThreadSafety;
var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
  LConfig: TBenchConfig;
  LEntries: array of TBenchEntry;
  I: Integer;
begin
  LConfig := Default(TBenchConfig);
  LConfig.Quiet := True;
  LConfig.MinSamples := 2;
  LConfig.MinDurationNs := 50000;
  LRun := TBenchRun.Create(LConfig);
  try
    SetLength(LEntries, 8);
    for I := 0 to 7 do
      LEntries[I] := MakeBenchEntry('Thread_' + IntToStr(I), @NoOpBench);

    LResults := LRun.RunAll(LEntries, 4);
    Check(Length(LResults) = 8, '8 entries with 4 threads returns 8 results');
    for I := 0 to 7 do
      Check(LResults[I].Executed, 'Entry ' + IntToStr(I) + ' executed');
  finally
    LRun.Free;
  end;
end;

procedure Test_RunAll_EntriesExceedThreadCount;
var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
  LConfig: TBenchConfig;
begin
  LConfig := Default(TBenchConfig);
  LConfig.Quiet := True;
  LConfig.MinSamples := 2;
  LConfig.MinDurationNs := 50000;
  LRun := TBenchRun.Create(LConfig);
  try
    LResults := LRun.RunAll([
      MakeBenchEntry('Over1', @NoOpBench),
      MakeBenchEntry('Over2', @NoOpBench)
    ], 8);
    Check(Length(LResults) = 2, '2 entries with 8 threads returns 2 results');
  finally
    LRun.Free;
  end;
end;

procedure Test_RunAll_WithBusyBench;
var
  LRun: TBenchRun;
  LResults: TBenchResultArray;
  LConfig: TBenchConfig;
begin
  LConfig := DefaultBenchConfig;
  LConfig.Quiet := True;
  LConfig.MinSamples := 5;
  LConfig.MinDurationNs := 10000000; { 10ms }
  LRun := TBenchRun.Create(LConfig);
  try
    LResults := LRun.RunAll([MakeBenchEntry('Busy', @BusyBench)], 1);
    Check(Length(LResults) = 1, '1 result');
    Check(LResults[0].Executed, 'Executed');
    Check(LResults[0].NsPerOp > 0, 'NsPerOp > 0');
    Check(LResults[0].SampleCount > 0, 'SampleCount > 0');
  finally
    LRun.Free;
  end;
end;

{ --------------------------------------------------------------------- }
{  Main }
{ --------------------------------------------------------------------- }

var
  T: TTestSuite;
  LRunPassed: Boolean;
begin
  T := TTestSuite.Create('nextpas.core.bench.run');

  { AllocBenchResult / FreeBenchResult }
  T.Test('AllocBenchResult.Basic', @Test_AllocBenchResult_Basic);
  T.Test('AllocBenchResult.ManagedTypes', @Test_AllocBenchResult_ManagedTypes);
  T.Test('FreeBenchResult.Nil', @Test_FreeBenchResult_Nil);

  { Create / Destroy }
  T.Test('Create.Destroy', @Test_Create_Destroy);
  T.Test('Create.WithConfig', @Test_CreateWithConfig);

  { SubmitResult }
  T.Test('SubmitResult.Single', @Test_SubmitResult_Single);
  T.Test('SubmitResult.Multiple', @Test_SubmitResult_Multiple);

  { RunAll }
  T.Test('RunAll.Empty', @Test_RunAll_Empty);
  T.Test('RunAll.SingleEntry', @Test_RunAll_SingleEntry);
  T.Test('RunAll.MultipleEntries', @Test_RunAll_MultipleEntries);
  T.Test('RunAll.ThreadSafety', @Test_RunAll_ThreadSafety);
  T.Test('RunAll.EntriesExceedThreadCount', @Test_RunAll_EntriesExceedThreadCount);
  T.Test('RunAll.WithBusyBench', @Test_RunAll_WithBusyBench);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
