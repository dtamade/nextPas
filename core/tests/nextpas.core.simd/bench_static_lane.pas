program bench_static_lane;

{$I ../../src/nextpas.core.settings.inc}
{$INLINE ON}

uses
  SysUtils,
  nextpas.core.simd.base,
  nextpas.core.simd,
  nextpas.core.simd.static.avx2;

const
  ITERATIONS = 10000000;

var
  a, b, c: TVecF32x4;
  i: Integer;
  t1, t2: Int64;

function ReadTSC: Int64; assembler; nostackframe;
asm
  rdtsc
  shl rdx, 32
  or rax, rdx
end;

procedure BenchDynamic;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 0.5; b.f[1] := 0.5; b.f[2] := 0.5; b.f[3] := 0.5;

  t1 := ReadTSC;
  for i := 1 to ITERATIONS do
    c := nextpas.core.simd.VecF32x4Add(a, b);
  t2 := ReadTSC;

  WriteLn('  Dynamic dispatch: ', (t2 - t1) div ITERATIONS, ' cycles/call');
end;

procedure BenchStatic;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 0.5; b.f[1] := 0.5; b.f[2] := 0.5; b.f[3] := 0.5;

  t1 := ReadTSC;
  for i := 1 to ITERATIONS do
    c := nextpas.core.simd.static.avx2.VecF32x4Add(a, b);
  t2 := ReadTSC;

  WriteLn('  Static AVX2:      ', (t2 - t1) div ITERATIONS, ' cycles/call');
end;

begin
  WriteLn('=== Static vs Dynamic Dispatch Benchmark ===');
  WriteLn('  Iterations: ', ITERATIONS);
  WriteLn;
  BenchDynamic;
  BenchStatic;
  WriteLn;
  WriteLn('  Result check: c[0]=', c.f[0]:0:2);
end.
