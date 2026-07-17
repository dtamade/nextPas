{
  SIMD Dispatch Overhead Benchmark

  测量 SIMD 分派器开销。
}

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar,
  nextpas.core.time.stopwatch;

const
  ITERATIONS = 10000000;

var
  a, b, r1, r2, r3: TVecF32x4;
  i: Integer;
  sw: TStopwatch;
  time1, time2, time3: Int64;
  dispatch: PSimdDispatchTable;
begin
  WriteLn('=== SIMD Dispatch Overhead Benchmark ===');
  WriteLn;

  // 初始化数据
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 5.0; b.f[1] := 6.0; b.f[2] := 7.0; b.f[3] := 8.0;

  dispatch := GetDispatchTable;

  // 测试 1: Scalar
  WriteLn('ScalarAddF32x4:');
  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    r1 := ScalarAddF32x4(a, b);
  time1 := sw.ElapsedMilliseconds;
  WriteLn('  Time: ', time1, ' ms');

  // 测试 2: Facade (VecF32x4Add)
  WriteLn('VecF32x4Add (facade):');
  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    r2 := VecF32x4Add(a, b);
  time2 := sw.ElapsedMilliseconds;
  WriteLn('  Time: ', time2, ' ms');

  // 测试 3: Direct dispatch
  WriteLn('Direct dispatch (dispatch^.CoreVectors.AddF32x4):');
  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    r3 := dispatch^.CoreVectors.AddF32x4(a, b);
  time3 := sw.ElapsedMilliseconds;
  WriteLn('  Time: ', time3, ' ms');

  WriteLn;
  WriteLn('Overhead analysis:');
  WriteLn('  Facade vs Scalar:   +', time2 - time1, ' ms (', ((time2 / time1) - 1) * 100:0:1, '%)');
  WriteLn('  Direct vs Scalar:   +', time3 - time1, ' ms (', ((time3 / time1) - 1) * 100:0:1, '%)');
  WriteLn('  Facade vs Direct:   +', time2 - time3, ' ms');

  // 防止优化
  if r1.f[0] > 0 then;
  if r2.f[0] > 0 then;
  if r3.f[0] > 0 then;

  WriteLn;
  WriteLn('Done.');
end.
