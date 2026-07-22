{*
 * nextpas.core.bench - Recipe Reuse Example
 *
 * 原名 object_pool：B19 TBenchResultPool 已删除。
 * 本示例改为「同一配方连跑两次 + BlackBox」，演示可复现的最小微基准。
 *}

program bench_recipe_reuse;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.text.format,
  nextpas.core.platform.time;

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

procedure DemoRecipeReuse;
var
  LResults: IBenchResults;
  LStart, LEnd: UInt64;
  LNs1, LNs2: Double;
begin
  WriteLn('=== Recipe Reuse Demo (ex object_pool) ===');

  WriteLn('  Run 1:');
  LStart := platform_monotonic_ns;
  LResults := TBenchSuite.Create('Recipe1')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Sum/1k', @BenchIntegerSum)
    .Run;
  LEnd := platform_monotonic_ns;
  LNs1 := LResults.GetByName('Sum/1k').NsPerOp;
  WriteLn(TextFormat('    Wall: %d ms  ns/op: %.2f',
    [(LEnd - LStart) div 1000000, LNs1]));

  WriteLn('  Run 2 (same recipe):');
  LStart := platform_monotonic_ns;
  LResults := TBenchSuite.Create('Recipe2')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMinSamples(5)
    .Add('Sum/1k', @BenchIntegerSum)
    .Run;
  LEnd := platform_monotonic_ns;
  LNs2 := LResults.GetByName('Sum/1k').NsPerOp;
  WriteLn(TextFormat('    Wall: %d ms  ns/op: %.2f',
    [(LEnd - LStart) div 1000000, LNs2]));

  WriteLn(TextFormat('  Ratio run2/run1: %.3f', [LNs2 / LNs1]));
  WriteLn;
end;

begin
  WriteLn('=== nextpas.core.bench recipe reuse ===');
  WriteLn;
  DemoRecipeReuse;
  WriteLn('=== Done ===');
end.
