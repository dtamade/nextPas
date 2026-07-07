{*
 * nextpas.core.bench - Quick Start Example
 *
 * 5 分钟入门基准测试框架。
 * 展示：Fluent Builder API、统计输出、基线对比。
 *}

program bench_quick_start;

{$mode ObjFPC}{$H+}
{$modeswitch anonymousfunctions}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base;

{*
 * 简单基准：测量整数求和性能
 *}
procedure BenchIntegerSum(const ACtx: IBenchContext);
var
  LSum: Int64;
  I: Integer;
begin
  LSum := 0;
  for I := 1 to 10000 do
    Inc(LSum, I);
  { 防止编译器优化掉计算结果 }
  if LSum < 0 then
    WriteLn('Impossible');
end;

{*
 * 带 Setup/Teardown 的基准：测量数组排序
 *}
var
  GSortData: array of Integer;

function SetupSortData: Pointer;
var
  I: Integer;
begin
  SetLength(GSortData, 10000);
  for I := 0 to High(GSortData) do
    GSortData[I] := Random(100000);
  Result := nil;
end;

procedure BenchArraySort(const ACtx: IBenchContext);
begin
  { 简单冒泡排序（仅作演示，实际应使用 IntroSort） }
  // SortArray(GSortData);  // 假设已导入排序函数
end;

{*
 * 并行基准：测量原子操作性能
 *}
var
  GCounter: Int64 = 0;

procedure BenchAtomicIncrement(const ACtx: IBenchContext);
begin
  InterlockedIncrement64(GCounter);
end;

{*
 * 使用 lambda 的基准（需要 {$modeswitch anonymousfunctions}）
 *}
procedure BenchLambdaExample;
var
  LResults: IBenchResults;
begin
  LResults := TBenchSuite.Create('LambdaDemo')
    .Add('StringConcat', procedure(const ACtx: IBenchContext)
      var
        S: string;
        I: Integer;
      begin
        S := '';
        for I := 1 to 100 do
          S := S + 'x';
      end)
    .Run;

  WriteLn(LResults.PrintToConsole);
end;

{*
 * 主程序：演示各种基准测试场景
 *}
var
  LResults: IBenchResults;
begin
  WriteLn('=== nextpas.core.bench Quick Start ===');
  WriteLn;

  { 1. 最简单的基准 }
  WriteLn('1. Simple Benchmark:');
  LResults := TBenchSuite.Create('QuickStart')
    .SetMinDuration(TDuration.FromSeconds(1))
    .SetMinSamples(10)
    .Add('IntegerSum/10000', @BenchIntegerSum)
    .Run;

  WriteLn(LResults.PrintToConsole);
  WriteLn;

  { 2. 带 Setup 的基准 }
  WriteLn('2. Benchmark with Setup:');
  LResults := TBenchSuite.Create('SortDemo')
    .SetMinDuration(TDuration.FromSeconds(1))
    .AddWithSetup('ArraySort/10000', @BenchArraySort,
      @SetupSortData, nil)
    .Run;

  WriteLn(LResults.PrintToConsole);
  WriteLn;

  { 3. 并行基准 }
  WriteLn('3. Parallel Benchmark:');
  LResults := TBenchSuite.Create('ParallelDemo')
    .SetMinDuration(TDuration.FromSeconds(1))
    .AddParallel('AtomicIncrement', @BenchAtomicIncrement, 4)
    .Run;

  WriteLn(LResults.PrintToConsole);
  WriteLn;

  { 4. Lambda 基准 }
  WriteLn('4. Lambda Benchmark:');
  BenchLambdaExample;

  { 5. 保存结果到文件 }
  WriteLn('5. Saving Results:');
  LResults.SaveToJSON('bench-results.json');
  LResults.SaveToHTML('bench-results.html');
  WriteLn('   Saved to bench-results.json and bench-results.html');

  WriteLn;
  WriteLn('=== Quick Start Complete ===');
end.
