{*
 * nextpas.core.bench - Custom Metrics Example
 *
 * 展示自定义统计指标：扩展统计计算、领域特定指标。
 *}

program bench_custom_metrics;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base;

{*
 * 计算吞吐量（ops/sec）
 *}
function Throughput(ANsPerOp: Double): Double;
begin
  if ANsPerOp = 0 then
    Exit(0);

  Result := 1e9 / ANsPerOp;  { ns/op → ops/sec }
end;

{*
 * 计算带宽（MB/s）
 *}
function Bandwidth(ANsPerOp: Double; ABytesPerOp: Double): Double;
begin
  if ANsPerOp = 0 then
    Exit(0);

  { ns/op → MB/s }
  Result := (ABytesPerOp * 1e9) / (ANsPerOp * 1e6);
end;

{*
 * 简单基准函数
 *}
procedure BenchMemcpy(const ACtx: IBenchContext);
var
  Src, Dst: array[0..1023] of Byte;
  I: Integer;
begin
  for I := 0 to 1023 do
    Src[I] := Byte(I);
  Dst := Src;
end;

{*
 * 演示带宽指标
 *}
procedure DemoBandwidthMetrics;
var
  LResults: IBenchResults;
  LResult: TBenchResult;
  LBytesPerOp: Double;
begin
  WriteLn('=== Bandwidth Metrics ===');

  LResults := TBenchSuite.Create('Bandwidth')
    .SetMinDuration(TDuration.FromSeconds(1))
    .Add('Memcpy/1KB', @BenchMemcpy)
    .Run;

  LBytesPerOp := 1024;  { 每操作 1KB }

  LResult := LResults.GetByName('Memcpy/1KB');

  WriteLn(Format('  %s:', [LResult.Name]));
  WriteLn(Format('    Time:       %.2f ns/op', [LResult.NsPerOp]));
  WriteLn(Format('    Throughput: %.2f ops/sec', [Throughput(LResult.NsPerOp)]));
  WriteLn(Format('    Bandwidth:  %.2f MB/s',
    [Bandwidth(LResult.NsPerOp, LBytesPerOp)]));

  WriteLn;
end;

{*
 * 主程序
 *}
begin
  WriteLn('=== nextpas.core.bench Custom Metrics ===');
  WriteLn;

  DemoBandwidthMetrics;

  WriteLn('=== Custom Metrics Complete ===');
end.
