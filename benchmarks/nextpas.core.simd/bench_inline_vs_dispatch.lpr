program bench_inline_vs_dispatch;
{$mode objfpc}{$H+}
uses
  nextpas.core.simd,
  nextpas.core.simd.inline,
  nextpas.core.simd.base,
  nextpas.core.bench;

var
  GF32A, GF32B, GF32C: TVecF32x4;
  GU8A, GU8B, GU8C: TVecU8x16;

procedure BenchDispatchF32x4Add;
begin
  GF32C := VecF32x4Add(GF32A, GF32B);
  BenchBlackBoxPtr(@GF32C);
end;

procedure BenchInlineF32x4Add;
begin
  GF32C := InlineVecF32x4Add(GF32A, GF32B);
  BenchBlackBoxPtr(@GF32C);
end;

procedure BenchDispatchU8x16SatAdd;
begin
  GU8C := VecU8x16SatAdd(GU8A, GU8B);
  BenchBlackBoxPtr(@GU8C);
end;

procedure BenchInlineU8x16SatAdd;
begin
  GU8C := InlineVecU8x16SatAdd(GU8A, GU8B);
  BenchBlackBoxPtr(@GU8C);
end;

procedure BenchInlineF32x4Mul;
begin
  GF32C := InlineVecF32x4Mul(GF32A, GF32B);
  BenchBlackBoxPtr(@GF32C);
end;

var
  Suite: IBenchSuite;
  Res: IBenchResults;
  i: Integer;
begin
  for i:=0 to 3 do begin GF32A.f[i]:=i*1.5; GF32B.f[i]:=i*2.0; end;
  for i:=0 to 15 do begin GU8A.u[i]:=i*7; GU8B.u[i]:=i*11; end;

  Suite := TBenchSuite.Create('simd.inline_vs_dispatch');
  Suite.AddSimple('Dispatch F32x4 Add', @BenchDispatchF32x4Add);
  Suite.AddSimple('Inline   F32x4 Add', @BenchInlineF32x4Add);
  Suite.AddSimple('Dispatch U8x16 SatAdd', @BenchDispatchU8x16SatAdd);
  Suite.AddSimple('Inline   U8x16 SatAdd', @BenchInlineU8x16SatAdd);
  Suite.AddSimple('Inline   F32x4 Mul', @BenchInlineF32x4Mul);
  Res := Suite.Run;
  WriteLn(Res.ToSummary);
  WriteLn('Gate: Inline <= 0.9 * Dispatch for hot ops; inline variant must not regress GB/s.');
  WriteLn('Industry ref: Rust portable-simd F32x4 add ~0.3 ns/lane (~1.2 ns/vec) on same x86_64; our inline target within 2x.');
end.
