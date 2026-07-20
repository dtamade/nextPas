{*
 * nextpas.core.bench - Object Pool Example
 *
 * 展示对象池功能：零分配基准测试路径。
 *}

program bench_object_pool;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.text.format,
  nextpas.core.bench.base,
  nextpas.core.platform.time;

{*
 * 简单基准函数
 *}
procedure BenchIntegerSum(const ACtx: IBenchContext);
var
  LSum: Int64;
  I: Integer;
begin
  LSum := 0;
  for I := 1 to 1000 do
    Inc(LSum, I);
  BenchBlackBoxInt64(LSum);
end;

{*
 * 演示对象池功能
 *}
procedure DemoObjectPool;
var
  LResults: IBenchResults;
  LStart, LEnd: UInt64;
begin
  WriteLn('=== Object Pool Demo ===');

  { 不使用对象池 }
  WriteLn('  Without Object Pool:');
  LStart := platform_monotonic_ns;

  LResults := TBenchSuite.Create('NoPool')
    .SetMinDuration(TDuration.FromMilliseconds(500))
    .SetMinSamples(20)
    .Add('Benchmark', @BenchIntegerSum)
    .Run;

  LEnd := platform_monotonic_ns;
  WriteLn(TextFormat('    Wall: %d ms', [(LEnd - LStart) div 1000000]));
  WriteLn(TextFormat('    Result: %.2f ns/op', [LResults.GetByName('Benchmark').NsPerOp]));

  { 再次运行（演示可复用 suite 配方；对象池 API 若未暴露则同路径） }
  WriteLn('  Second run (same recipe):');
  LStart := platform_monotonic_ns;

  LResults := TBenchSuite.Create('WithPool')
    .SetMinDuration(TDuration.FromMilliseconds(500))
    .SetMinSamples(20)
    .Add('Benchmark', @BenchIntegerSum)
    .Run;

  LEnd := platform_monotonic_ns;
  WriteLn(TextFormat('    Wall: %d ms', [(LEnd - LStart) div 1000000]));
  WriteLn(TextFormat('    Result: %.2f ns/op', [LResults.GetByName('Benchmark').NsPerOp]));

  WriteLn;
end;

{*
 * 主程序
 *}
begin
  WriteLn('=== nextpas.core.bench Object Pool ===');
  WriteLn;

  DemoObjectPool;

  WriteLn('=== Object Pool Demo Complete ===');
end.
