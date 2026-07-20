{*
 * nextpas.core.bench - Performance Tuning Example
 *
 * 展示性能调优技巧：测量偏差避免、缓存预热、分支预测优化。
 *}

program bench_performance_tuning;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.text.format,
  nextpas.core.bench.base;

{*
 * 1. 避免测量偏差：使用 ResetTimer/StopTimer
 *}
var
  GSetupData: array of Integer;

procedure SetupLargeData;
var
  I: Integer;
begin
  SetLength(GSetupData, 1000000);
  for I := 0 to High(GSetupData) do
    GSetupData[I] := Random(1000000);
end;

{*
 * 差示例：Setup 时间被计入基准
 *}
procedure BenchSortWithSetupInTimer(const ACtx: IBenchContext);
var
  LData: array of Integer;
  I: Integer;
begin
  { Setup（应该在计时器外） }
  SetLength(LData, 100000);
  for I := 0 to High(LData) do
    LData[I] := Random(1000000);

  { 实际基准 }
  // SortArray(LData);
end;

{*
 * 好示例：使用 ResetTimer 排除 Setup 时间
 *}
procedure BenchSortWithResetTimer(const ACtx: IBenchContext);
var
  LData: array of Integer;
  I: Integer;
begin
  { Setup（计时器内） }
  SetLength(LData, 100000);
  for I := 0 to High(LData) do
    LData[I] := Random(1000000);

  { 重置计时器，排除 Setup 时间 }
  ACtx.ResetTimer;

  { 实际基准 }
  // SortArray(LData);
end;

{*
 * 好示例：使用 AddWithSetup 分离 Setup
 *}
function SortSetup: Pointer;
var
  I: Integer;
begin
  SetLength(GSetupData, 100000);
  for I := 0 to High(GSetupData) do
    GSetupData[I] := Random(1000000);
  Result := nil;
end;

procedure BenchSortWithSetupTeardown(const ACtx: IBenchContext);
begin
  { 只测量排序时间 }
  // SortArray(GSetupData);
end;

{*
 * 2. 缓存预热：避免冷启动偏差
 *}
procedure BenchCacheWarmup;
var
  LResults: IBenchResults;
begin
  WriteLn('=== Cache Warmup ===');

  { 冷启动：首次运行可能较慢 }
  LResults := TBenchSuite.Create('CacheCold')
    .SetMinDuration(TDuration.FromSeconds(1))
    .SetWarmupIters(0)  { 不预热 }
    .Add('Sort/Cold', @BenchSortWithSetupTeardown)
    .Run;

  WriteLn(TextFormat('  Cold: %.2f ns/op', [LResults.GetByName('Sort/Cold').NsPerOp]));

  { 热启动：预热后稳定 }
  LResults := TBenchSuite.Create('CacheWarm')
    .SetMinDuration(TDuration.FromSeconds(1))
    .SetWarmupIters(100)  { 预热 100 次 }
    .Add('Sort/Warm', @BenchSortWithSetupTeardown)
    .Run;

  WriteLn(TextFormat('  Warm: %.2f ns/op', [LResults.GetByName('Sort/Warm').NsPerOp]));
  WriteLn;
end;

{*
 * 3. 分支预测优化
 *}
var
  GBranchData: array of Boolean;

procedure SetupBranchData(APercentTrue: Double);
var
  I: Integer;
begin
  SetLength(GBranchData, 10000);
  for I := 0 to High(GBranchData) do
    GBranchData[I] := Random < APercentTrue;
end;

procedure BenchBranchPrediction(const ACtx: IBenchContext);
var
  LSum: Integer;
  I: Integer;
begin
  LSum := 0;
  for I := 0 to High(GBranchData) do
  begin
    if GBranchData[I] then  { 分支预测友好的模式 }
      Inc(LSum);
  end;

  BenchBlackBoxInt64(LSum);
end;

procedure BenchBranchMisprediction(const ACtx: IBenchContext);
var
  LSum: Integer;
  I: Integer;
begin
  LSum := 0;
  for I := 0 to High(GBranchData) do
  begin
    if GBranchData[I] then  { 分支预测不友好的模式 }
      Inc(LSum);
  end;

  BenchBlackBoxInt64(LSum);
end;

{*
 * 4. 内存访问模式
 *}
procedure BenchSequentialAccess(const ACtx: IBenchContext);
var
  LData: array of Integer;
  LSum: Int64;
  I: Integer;
begin
  SetLength(LData, 100000);
  for I := 0 to High(LData) do
    LData[I] := I;

  LSum := 0;
  for I := 0 to High(LData) do
    Inc(LSum, LData[I]);

  BenchBlackBoxInt64(LSum);
end;

procedure BenchRandomAccess(const ACtx: IBenchContext);
var
  LData: array of Integer;
  LIndices: array of Integer;
  LSum: Int64;
  I: Integer;
begin
  SetLength(LData, 100000);
  SetLength(LIndices, 100000);

  for I := 0 to High(LData) do
    LData[I] := I;

  for I := 0 to High(LIndices) do
    LIndices[I] := Random(100000);

  LSum := 0;
  for I := 0 to High(LIndices) do
    Inc(LSum, LData[LIndices[I]]);

  BenchBlackBoxInt64(LSum);
end;

{*
 * 主程序：演示性能调优技巧
 *}
var
  LResults: IBenchResults;
begin
  WriteLn('=== nextpas.core.bench Performance Tuning ===');
  WriteLn;

  { 1. 测量偏差 }
  WriteLn('1. Measurement Bias:');
  LResults := TBenchSuite.Create('Bias')
    .SetMinDuration(TDuration.FromSeconds(1))
    .Add('SortWithSetupInTimer', @BenchSortWithSetupInTimer)
    .Add('SortWithResetTimer', @BenchSortWithResetTimer)
    .AddWithSetup('SortWithSetupTeardown', @BenchSortWithSetupTeardown,
      @SortSetup, nil)
    .Run;

  WriteLn(LResults.PrintToConsole);
  WriteLn;

  { 2. 缓存预热 }
  WriteLn('2. Cache Warmup:');
  BenchCacheWarmup;

  { 3. 分支预测 }
  WriteLn('3. Branch Prediction:');
  SetupBranchData(0.5);  { 50% true，难以预测 }
  LResults := TBenchSuite.Create('Branch')
    .SetMinDuration(TDuration.FromSeconds(1))
    .Add('Branch50', @BenchBranchPrediction)
    .Run;

  WriteLn(TextFormat('  50%% true: %.2f ns/op', [LResults.GetByName('Branch50').NsPerOp]));

  SetupBranchData(0.01);  { 1% true，容易预测 }
  LResults := TBenchSuite.Create('Branch')
    .SetMinDuration(TDuration.FromSeconds(1))
    .Add('Branch1', @BenchBranchMisprediction)
    .Run;

  WriteLn(TextFormat('  1%% true: %.2f ns/op', [LResults.GetByName('Branch1').NsPerOp]));
  WriteLn;

  { 4. 内存访问模式 }
  WriteLn('4. Memory Access Patterns:');
  LResults := TBenchSuite.Create('Memory')
    .SetMinDuration(TDuration.FromSeconds(1))
    .Add('Sequential', @BenchSequentialAccess)
    .Add('Random', @BenchRandomAccess)
    .Run;

  WriteLn(LResults.PrintToConsole);
  WriteLn;

  WriteLn('=== Performance Tuning Complete ===');
end.
