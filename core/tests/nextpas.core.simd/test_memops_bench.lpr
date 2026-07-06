{
  Memory Operations Benchmark

  测量 MemCopy/MemSet/MemEqual 性能。
}

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.scalar,
  nextpas.core.time.stopwatch;

const
  ITERATIONS = 1000000;
  SIZE = 4096;  // 4KB

var
  src, dst: array[0..SIZE-1] of Byte;
  i: Integer;
  sw: TStopwatch;
  time1, time2: Int64;
  speedup: Double;
begin
  WriteLn('=== Memory Operations Benchmark ===');
  WriteLn('Size: ', SIZE, ' bytes');
  WriteLn('Iterations: ', ITERATIONS);
  WriteLn;

  // 初始化数据
  for i := 0 to SIZE - 1 do
    src[i] := Byte(i and $FF);

  // 测试 MemCopy
  WriteLn('MemCopy:');
  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    Move(src[0], dst[0], SIZE);
  time1 := sw.ElapsedMilliseconds;

  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    MemCopy(@src[0], @dst[0], SIZE);
  time2 := sw.ElapsedMilliseconds;

  if time1 > 0 then
    speedup := time1 / time2
  else
    speedup := 0;

  WriteLn('  Move (FPC):   ', time1, ' ms');
  WriteLn('  MemCopy (SIMD): ', time2, ' ms');
  WriteLn('  Speedup:      ', speedup:0:2, 'x');
  WriteLn;

  // 测试 MemSet
  WriteLn('MemSet:');
  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    FillChar(dst[0], SIZE, $AA);
  time1 := sw.ElapsedMilliseconds;

  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    MemSet(@dst[0], SIZE, $AA);
  time2 := sw.ElapsedMilliseconds;

  if time1 > 0 then
    speedup := time1 / time2
  else
    speedup := 0;

  WriteLn('  FillChar (FPC): ', time1, ' ms');
  WriteLn('  MemSet (SIMD):  ', time2, ' ms');
  WriteLn('  Speedup:        ', speedup:0:2, 'x');
  WriteLn;

  // 测试 MemEqual
  WriteLn('MemEqual:');
  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    CompareByte(src[0], dst[0], SIZE);
  time1 := sw.ElapsedMilliseconds;

  sw := TStopwatch.StartNew;
  for i := 1 to ITERATIONS do
    MemEqual(@src[0], @dst[0], SIZE);
  time2 := sw.ElapsedMilliseconds;

  if time1 > 0 then
    speedup := time1 / time2
  else
    speedup := 0;

  WriteLn('  CompareByte (FPC): ', time1, ' ms');
  WriteLn('  MemEqual (SIMD):   ', time2, ' ms');
  WriteLn('  Speedup:           ', speedup:0:2, 'x');
  WriteLn;

  // 防止优化
  if dst[0] > 0 then;

  WriteLn('Done.');
end.
