{*
 * nextpas.core.bench - Object Pool Example
 *
 * 展示对象池功能：零分配基准测试路径。
 *}

program bench_object_pool;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base;

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
  if LSum < 0 then
    WriteLn('Impossible');
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
  LStart := GetTickCount64;

  LResults := TBenchSuite.Create('NoPool')
    .SetMinDuration(TDuration.FromMilliseconds(500))
    .SetMinSamples(20)
    .Add('Benchmark', @BenchIntegerSum)
    .Run;

  LEnd := GetTickCount64;
  WriteLn(Format('    Time: %d ms', [LEnd - LStart]));
  WriteLn(Format('    Result: %.2f ns/op', [LResults.GetByName('Benchmark').NsPerOp]));

  { 使用对象池 }
  WriteLn('  With Object Pool:');
  LStart := GetTickCount64;

  LResults := TBenchSuite.Create('WithPool')
    .SetMinDuration(TDuration.FromMilliseconds(500))
    .SetMinSamples(20)
    .EnableObjectPool
    .Add('Benchmark', @BenchIntegerSum)
    .Run;

  LEnd := GetTickCount64;
  WriteLn(Format('    Time: %d ms', [LEnd - LStart]));
  WriteLn(Format('    Result: %.2f ns/op', [LResults.GetByName('Benchmark').NsPerOp]));

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
