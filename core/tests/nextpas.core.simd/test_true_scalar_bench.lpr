{
  True Scalar vs SIMD Benchmark

  验证 SIMD 相对于真正标量代码的加速比。
  使用 volatile 变量阻止 FPC 自动向量化。
}

{$mode ObjFPC}{$H+}

uses
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.scalar,
  nextpas.core.time.stopwatch;

var
  g_VolatileBarrier: Single;  // 阻止自动向量化

function TrueScalarAddF32x4(const a, b: TVecF32x4): TVecF32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
  begin
    Result.f[i] := a.f[i] + b.f[i];
    g_VolatileBarrier := Result.f[i];  // 阻止向量化
  end;
end;

function TrueScalarMulF32x4(const a, b: TVecF32x4): TVecF32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
  begin
    Result.f[i] := a.f[i] * b.f[i];
    g_VolatileBarrier := Result.f[i];  // 阻止向量化
  end;
end;

const
  ITERATIONS = 10000000;

var
  a, b, r1, r2: TVecF32x4;
  i: Integer;
  sw: TStopwatch;
  scalarTime, simdTime: Int64;
  speedup: Double;
begin
  WriteLn('=== True Scalar vs SIMD Benchmark ===');
  WriteLn;

  // 初始化数据
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 5.0; b.f[1] := 6.0; b.f[2] := 7.0; b.f[3] := 8.0;

  // 测试 Add
  WriteLn('VecF32x4Add:');
  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    r1 := TrueScalarAddF32x4(a, b);
  scalarTime := sw.ElapsedMilliseconds;

  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    r2 := VecF32x4Add(a, b);
  simdTime := sw.ElapsedMilliseconds;

  if simdTime > 0 then
    speedup := scalarTime / simdTime
  else
    speedup := 0;

  WriteLn('  True Scalar: ', scalarTime, ' us');
  WriteLn('  SIMD:        ', simdTime, ' us');
  WriteLn('  Speedup:     ', speedup:0:2, 'x');
  WriteLn;

  // 测试 Mul
  WriteLn('VecF32x4Mul:');
  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    r1 := TrueScalarMulF32x4(a, b);
  scalarTime := sw.ElapsedMilliseconds;

  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    r2 := VecF32x4Mul(a, b);
  simdTime := sw.ElapsedMilliseconds;

  if simdTime > 0 then
    speedup := scalarTime / simdTime
  else
    speedup := 0;

  WriteLn('  True Scalar: ', scalarTime, ' us');
  WriteLn('  SIMD:        ', simdTime, ' us');
  WriteLn('  Speedup:     ', speedup:0:2, 'x');
  WriteLn;

  // 防止优化
  if r1.f[0] > 0 then;
  if r2.f[0] > 0 then;

  WriteLn('Done.');
end.
