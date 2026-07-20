{*
 * nextpas.core.bench - Parallel Benchmark Example
 *
 * 展示并行基准测试：多线程性能测量、线程安全验证。
 *}

program bench_parallel_example;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.atomic.types,
  nextpas.core.text.format;

{*
 * 共享计数器（用于演示原子操作）
 *}
var
  GAtomicCounter: TAtomicInt64;

procedure SetupAtomicCounter;
begin
  GAtomicCounter := TAtomicInt64.Create(0);
end;

{*
 * 原子递增基准
 *}
procedure BenchAtomicIncrement(const ACtx: IBenchContext);
begin
  GAtomicCounter.Increment;
end;

{*
 * 演示不同线程数的性能扩展
 *}
procedure DemoScalability;
var
  LResults: IBenchResults;
  LThreadCounts: array[0..3] of Integer;
  I: Integer;
begin
  WriteLn('=== Scalability Test ===');

  LThreadCounts[0] := 1;
  LThreadCounts[1] := 2;
  LThreadCounts[2] := 4;
  LThreadCounts[3] := 8;

  for I := 0 to 3 do
  begin
    SetupAtomicCounter;

    LResults := TBenchSuite.Create(TextFormat('Scalability/T=%d', [LThreadCounts[I]]))
      .SetMinDuration(TDuration.FromSeconds(2))
      .SetMinSamples(20)
      .AddParallel('AtomicIncrement', @BenchAtomicIncrement, LThreadCounts[I])
      .Run;

    WriteLn(TextFormat('  Threads=%d: %.2f ns/op',
      [LThreadCounts[I], LResults.GetByName('AtomicIncrement').NsPerOp]));
  end;

  WriteLn;
end;

{*
 * 演示线程安全验证
 *}
procedure DemoThreadSafety;
var
  LResults: IBenchResults;
  LExpectedValue: Int64;
begin
  WriteLn('=== Thread Safety Verification ===');

  { 重置计数器 }
  SetupAtomicCounter;

  { 运行并行基准 }
  LResults := TBenchSuite.Create('ThreadSafety')
    .SetMinDuration(TDuration.FromSeconds(1))
    .AddParallel('AtomicIncrement', @BenchAtomicIncrement, 8)
    .Run;

  { 验证最终值 }
  LExpectedValue := LResults.GetByName('AtomicIncrement').Iterations;
  WriteLn(TextFormat('  Expected iterations: %d', [LExpectedValue]));
  WriteLn(TextFormat('  Actual counter value: %d', [GAtomicCounter.Load]));
  WriteLn(TextFormat('  Thread safe: %s',
    [BoolToStr(GAtomicCounter.Load = LExpectedValue, 'YES', 'NO')]));
  WriteLn;
end;

{*
 * 主程序
 *}
begin
  WriteLn('=== nextpas.core.bench Parallel Examples ===');
  WriteLn;

  DemoScalability;
  DemoThreadSafety;

  WriteLn('=== Parallel Examples Complete ===');
end.
