program demo_basic;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base;

{ 示例基准函数：字符串拼接 }
procedure BenchStringConcat(const ACtx: IBenchContext);
var
  i: Integer;
  LStr: string;
begin
  LStr := '';
  for i := 1 to 1000 do
    LStr := LStr + IntToStr(i) + ',';
  if ACtx <> nil then
    ACtx.SetBytes(Length(LStr));
end;

{ 示例基准函数：数组求和 }
procedure BenchArraySum(const ACtx: IBenchContext);
var
  LArr: array[0..999] of Integer;
  i: Integer;
  LSum: Int64;
begin
  for i := 0 to 999 do
    LArr[i] := i;
  LSum := 0;
  for i := 0 to 999 do
    LSum := LSum + LArr[i];
end;

{ 示例基准函数：数学计算 }
procedure BenchMathOperations(const ACtx: IBenchContext);
var
  i: Integer;
  LResult: Double;
begin
  LResult := 0.0;
  for i := 1 to 10000 do
    LResult := LResult + Sin(i * 0.001) * Cos(i * 0.002);
end;

{ 示例基准函数：内存分配 }
procedure BenchMemoryAlloc(const ACtx: IBenchContext);
var
  i: Integer;
  LArr: array of Byte;
begin
  for i := 1 to 100 do
  begin
    SetLength(LArr, 1024);
    LArr[0] := 1;
  end;
  if ACtx <> nil then
    ACtx.SetAllocs(100);
end;

{ 示例基准函数：快速操作 }
procedure BenchFastOperation(const ACtx: IBenchContext);
var
  i: Integer;
begin
  for i := 1 to 100 do
    ;
end;

begin
  WriteLn('=== nextpas.core.bench Demo ===');
  WriteLn;
  WriteLn('This demo shows how to use the benchmark framework.');
  WriteLn;

  { 示例 1: 基础用法 }
  WriteLn('--- Example 1: Basic Usage ---');
  TBenchSuite.Create('BasicDemo')
    .Add('StringConcat', @BenchStringConcat)
    .Add('ArraySum', @BenchArraySum)
    .Add('MathOperations', @BenchMathOperations)
    .Run
    .ToConsole;

  WriteLn;
  WriteLn('--- Example 2: With Configuration ---');
  TBenchSuite.Create('ConfigDemo')
    .Add('FastOperation', @BenchFastOperation)
    .SetMinDuration(TDuration.FromMilliseconds(500))
    .SetMaxIterations(100000)
    .SetMinSamples(10)
    .SetWarmupIters(3)
    .Run
    .ToConsole;

  WriteLn;
  WriteLn('--- Example 3: With Baseline Comparison ---');
  TBenchSuite.Create('BaselineDemo')
    .Add('StringConcat', @BenchStringConcat)
    .Add('ArraySum', @BenchArraySum)
    .AddBaseline('StringConcat', 100.0)  // 基线：100 ns/op
    .AddBaseline('ArraySum', 50.0)        // 基线：50 ns/op
    .Run
    .ToConsole;

  WriteLn;
  WriteLn('--- Example 4: With Filter ---');
  TBenchSuite.Create('FilterDemo')
    .Add('StringConcat', @BenchStringConcat)
    .Add('ArraySum', @BenchArraySum)
    .Add('MathOperations', @BenchMathOperations)
    .SetFilter('String')
    .Run
    .ToConsole;

  WriteLn;
  WriteLn('--- Example 5: With Memory Tracking ---');
  TBenchSuite.Create('MemoryDemo')
    .Add('MemoryAlloc', @BenchMemoryAlloc)
    .EnableMemoryTracking
    .Run
    .ToConsole;

  WriteLn;
  WriteLn('--- Example 6: Generate JSON Report ---');
  TBenchSuite.Create('JSONDemo')
    .Add('StringConcat', @BenchStringConcat)
    .Add('ArraySum', @BenchArraySum)
    .Run
    .SaveToJSON('benchmark_results.json');

  WriteLn;
  WriteLn('JSON report saved to: benchmark_results.json');

  WriteLn;
  WriteLn('--- Example 7: Generate HTML Report ---');
  TBenchSuite.Create('HTMLDemo')
    .Add('StringConcat', @BenchStringConcat)
    .Add('ArraySum', @BenchArraySum)
    .Add('MathOperations', @BenchMathOperations)
    .Run
    .SaveToHTML('benchmark_results.html');

  WriteLn;
  WriteLn('HTML report saved to: benchmark_results.html');

  WriteLn;
  WriteLn('=== Demo Complete ===');
  WriteLn;
  WriteLn('Key Features Demonstrated:');
  WriteLn('  1. Fluent Builder API');
  WriteLn('  2. Multiple benchmark functions');
  WriteLn('  3. Configuration options');
  WriteLn('  4. Baseline comparison');
  WriteLn('  5. Benchmark filtering');
  WriteLn('  6. Memory tracking');
  WriteLn('  7. JSON export');
  WriteLn('  8. HTML report with charts');
  WriteLn;
  WriteLn('Next Steps:');
  WriteLn('  - Try different benchmark functions');
  WriteLn('  - Add more baselines for comparison');
  WriteLn('  - Generate reports in different formats');
  WriteLn('  - Integrate with CI/CD pipelines');
end.
